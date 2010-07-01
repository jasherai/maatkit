#!/usr/bin/env perl

BEGIN {
   die "The MAATKIT_WORKING_COPY environment variable is not set.  See http://code.google.com/p/maatkit/wiki/Testing"
      unless $ENV{MAATKIT_WORKING_COPY} && -d $ENV{MAATKIT_WORKING_COPY};
   unshift @INC, "$ENV{MAATKIT_WORKING_COPY}/common";
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
   plan tests => 4;
}

my $cnf     = '/tmp/12345/my.sandbox.cnf';
my $cmd     = "$trunk/mk-parallel-restore/mk-parallel-restore -F $cnf ";
my $mysql   = $sb->_use_for('master');
my $basedir = '/tmp/dump/';
my $output;

diag(`rm -rf $basedir`);

# #############################################################################
# Issue 300: restore only to empty databases
# #############################################################################

`$cmd --create-databases $trunk/mk-parallel-restore/t/samples/issue_625`;

$dbh->do('truncate table issue_625.t');
$output = `$cmd --only-empty-databases $trunk/mk-parallel-restore/t/samples/issue_625`;

is_deeply(
   $dbh->selectall_arrayref('select * from issue_625.t'),
   [],
   'Did not restore non-empty database (issue 300)',
);
like(
   $output,
   qr/database issue_625 is not empty/,
   'Says file was skipped because database is not empty (issue 300)'
);
like(
   $output,
   qr/0\s+files/,
   'Zero files restored (issue 300)'
);

$dbh->do('drop database if exists issue_625');
$output = `$cmd --create-databases --only-empty-databases $trunk/mk-parallel-restore/t/samples/issue_625`;

is_deeply(
   $dbh->selectall_arrayref('select * from issue_625.t'),
   [[1],[2],[3]],
   '--create-databases --only-empty-databases (issue 300)',
);

# #############################################################################
# Done.
# #############################################################################
$sb->wipe_clean($dbh);
exit;
