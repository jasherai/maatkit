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

# #############################################################################
# Issue 703: mk-parallel-restore cannot create tables with constraints
# #############################################################################
`$cmd samples/fast_index/ -D test -t store --no-foreign-key-checks 2>&1`;
is_deeply(
   $dbh->selectall_arrayref("show tables from `test` like 'store'"),
   [['store']],
   'Restore table with foreign key constraints (issue 703)'
);


# #############################################################################
# Done.
# #############################################################################
$sb->wipe_clean($dbh);
exit;
