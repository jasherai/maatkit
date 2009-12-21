#!/usr/bin/env perl

use strict;
use warnings FATAL => 'all';
use English qw(-no_match_vars);
use Test::More;

require '../../common/DSNParser.pm';
require '../../common/Sandbox.pm';
my $dp = new DSNParser();
my $sb = new Sandbox(basedir => '/tmp', DSNParser => $dp);
my $dbh = $sb->get_dbh_for('master');

if ( !$dbh ) {
   plan skip_all => 'Cannot connect to sandbox master';
}
else {
   plan tests => 2;
}

my $cnf     = '/tmp/12345/my.sandbox.cnf';
my $cmd     = "perl ../mk-parallel-restore -F $cnf ";
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
`$mysql < samples/issue_506.sql`;
`$cmd samples/issue_624/ --create-databases -D issue_624 -d d2`;
`../../mk-parallel-dump/mk-parallel-dump -F $cnf --base-dir $basedir -d issue_506`;
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
