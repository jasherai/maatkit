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
my $dbh = $sb->get_dbh_for('master');

if ( !$dbh ) {
   plan skip_all => 'Cannot connect to sandbox master';
}
else {
   plan tests => 2;
}

my $cnf     = '/tmp/12345/my.sandbox.cnf';
my $cmd     = "$trunk/mk-parallel-restore/mk-parallel-restore -F $cnf ";
my $mysql   = $sb->_use_for('master');
my $basedir = '/tmp/dump/';
my $output;

diag(`rm -rf $basedir`);

# #############################################################################
# Issue 507: Does D DSN part require special handling in mk-parallel-restore?
# #############################################################################

# I thought that no special handling was needed but I was wrong.
# The db might not exists (user might be using --create-databases)
# in which case DSN D might try to use an as-of-yet nonexistent db.
`$mysql < $trunk/mk-parallel-restore/t/samples/issue_506.sql`;
`$cmd $trunk/mk-parallel-restore/t/samples/issue_624/ --create-databases -D issue_624 -d d2`;
`$trunk/mk-parallel-dump/mk-parallel-dump -F $cnf --base-dir $basedir -d issue_506`;
$dbh->do('DROP TABLE IF EXISTS issue_506.t');
$dbh->do('DROP TABLE IF EXISTS issue_624.t');

`$cmd -D issue_624 $basedir/issue_506 2>&1`;

is_deeply(
   $dbh->selectall_arrayref('show tables from issue_624'),
   [['t'],['t2']],
   'Table was restored into -D database'
);

is_deeply(
   $dbh->selectall_arrayref('show tables from issue_506'),
   [],
   'Table was not restored into DSN D database'
);

# #############################################################################
# Done.
# #############################################################################
$sb->wipe_clean($dbh);
exit;
