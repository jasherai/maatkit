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
$sb->create_dbs($dbh, ['test']);
`$mysql < samples/issue_30.sql`;

# #############################################################################
# Issue 406: Use of uninitialized value in concatenation (.) or string at
# ./mk-parallel-restore line 1808
# #############################################################################

`../../mk-parallel-dump/mk-parallel-dump -F $cnf --base-dir $basedir -d test -t issue_30 --chunk-size 25`;

$output = `$cmd -D test $basedir 2>&1`;

unlike(
   $output,
   qr/uninitialized value/,
   'No error restoring table that already exists (issue 406)'
);
like(
   $output,
   qr/1 tables,\s+5 files,\s+1 successes,\s+0 failures/,
   'Restoring table that already exists (issue 406)'
);

# #############################################################################
# Done.
# #############################################################################
$sb->wipe_clean($dbh);
exit;
