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
# Issue 625: mk-parallel-restore throws errors for files restored by some
# versions of mysqldump
# #############################################################################
$output = `$cmd --create-databases samples/issue_625`;

like(
   $output,
   qr/0\s+failures,/,
   'Restore older mysqldump, no failure (issue 625)'
);
is_deeply(
   $dbh->selectall_arrayref('select * from issue_625.t'),
   [[1],[2],[3]],
   'Restore older mysqldump, data restored (issue 625)'
);


# #############################################################################
# Done.
# #############################################################################
$sb->wipe_clean($dbh);
exit;
