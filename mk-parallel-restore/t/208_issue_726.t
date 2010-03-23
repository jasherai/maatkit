#!/usr/bin/env perl

BEGIN {
   die "The MAATKIT_TRUNK environment variable is not set.  See http://code.google.com/p/maatkit/wiki/Testing"
      unless $ENV{MAATKIT_TRUNK} && -d $ENV{MAATKIT_TRUNK};
   unshift @INC, "$ENV{MAATKIT_TRUNK}/common";
};

use strict;
use warnings FATAL => 'all';
use English qw(-no_match_vars);
use Test::More;

use MaatkitTest;
use Sandbox;
require "$trunk/mk-parallel-restore/mk-parallel-restore";

my $dp = new DSNParser(opts=>$dsn_opts);
my $sb = new Sandbox(basedir => '/tmp', DSNParser => $dp);
my $dbh       = $sb->get_dbh_for('master');
my $slave_dbh = $sb->get_dbh_for('slave1');

if ( !$dbh ) {
   plan skip_all => 'Cannot connect to sandbox master';
}
elsif ( !$slave_dbh ) {
   plan skip_all => 'Cannot connect to sandbox slave';
}
else {
   plan tests => 6;
}

my $cnf     = '/tmp/12345/my.sandbox.cnf';
my $cmd     = "$trunk/mk-parallel-restore/mk-parallel-restore -F $cnf ";
my $mysql   = $sb->_use_for('master');
my $basedir = '/tmp/dump/';
my $output;

diag(`rm -rf $basedir`);

# #############################################################################
# Issue 726: mk-parallel-restore replicates DELETE statements even with
# --no-bin-log
# #############################################################################
$sb->create_dbs($dbh, ['test']);
$sb->load_file('master', 'mk-parallel-restore/t/samples/issue_30.sql');
`$trunk/mk-parallel-dump/mk-parallel-dump -F $cnf --base-dir $basedir -d test -t issue_30 --chunk-size 25`;
# The above makes the following chunks:
#
# #   WHERE                         SIZE  FILE
# -----------------------------------------------------------
# 0:  `id` < 254                    790   issue_30.000000.sql
# 1:  `id` >= 254 AND `id` < 502    619   issue_30.000001.sql
# 2:  `id` >= 502 AND `id` < 750    661   issue_30.000002.sql
# 3:  `id` >= 750                   601   issue_30.000003.sql

`$mysql -D test -e 'SET SQL_LOG_BIN=0; DELETE FROM issue_30 WHERE id > 505; SET SQL_LOG_BIN=1;'`;

is_deeply(
   $dbh->selectrow_arrayref('select count(*) from test.issue_30'),
   [50],
   'Rows deleted on master (issue 726)'
);

# These values should not be deleted on the slave after restoring
# the table on the master with --no-bin-log.
$slave_dbh->do('insert into test.issue_30 values (403), (503)');

is_deeply(
   $slave_dbh->selectall_arrayref('select * from test.issue_30 where id in (403, 503)'),
   [[403],[503]],
   'Special rows on slave (issue 726)'
);

is_deeply(
   $slave_dbh->selectrow_arrayref('select count(*) from test.issue_30'),
   [102],
   'Rows not deleted on slave (issue 726)'
);

`$cmd --no-bin-log --no-atomic-resume $basedir`;

is_deeply(
   $dbh->selectrow_arrayref('select count(*) from test.issue_30'),
   [100],
   'Rows restored on master (issue 726)'
);

is_deeply(
   $slave_dbh->selectrow_arrayref('select count(*) from test.issue_30'),
   [102],
   'Rows not deleted on slave (issue 726)'
);

is_deeply(
   $slave_dbh->selectall_arrayref('select * from test.issue_30 where id in (403, 503)'),
   [[403],[503]],
   'Special rows not deleted on slave (issue 726)'
);

# #############################################################################
# Done.
# #############################################################################
$sb->wipe_clean($dbh);
exit;
