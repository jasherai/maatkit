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
   plan tests => 1;
}

my $cnf     = '/tmp/12345/my.sandbox.cnf';
my $cmd     = "perl ../mk-parallel-restore -F $cnf ";
my $mysql   = $sb->_use_for('master');
my $basedir = '/tmp/dump/';
my $output;

diag(`rm -rf $basedir`);
$sb->create_dbs($dbh, ['test']);
`$mysql < samples/issue_30.sql`;

# #############################################################################
# Issue 221: mk-parallel-restore resume functionality broken
# #############################################################################

# Test that resume does not die if the table isn't present.
`../../mk-parallel-dump/mk-parallel-dump -F $cnf --base-dir $basedir -d test -t issue_30 --chunk-size 25`;
`$mysql -D test -e 'DROP TABLE issue_30'`;
$output = `MKDEBUG=1 $cmd -D test $basedir/test/ 2>&1 | grep Restoring`;
like($output, qr/Restoring from chunk 0 because table `test`.`issue_30` does not exist/, 'Resume does not die when table is not present (issue 221)');

# #############################################################################
# Done.
# #############################################################################
diag(`rm -rf $basedir`);
$sb->wipe_clean($dbh);
exit;
