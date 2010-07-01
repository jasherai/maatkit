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
   plan tests => 2;
}

my $cnf     = '/tmp/12345/my.sandbox.cnf';
my $cmd     = "$trunk/mk-parallel-restore/mk-parallel-restore -F $cnf ";
my $mysql   = $sb->_use_for('master');
my $basedir = '/tmp/dump/';
my $output;

diag(`rm -rf $basedir`);
$sb->create_dbs($dbh, ['test']);
`$mysql < $trunk/mk-parallel-restore/t/samples/issue_30.sql`;

# #############################################################################
# Issue 406: Use of uninitialized value in concatenation (.) or string at
# ./mk-parallel-restore line 1808
# #############################################################################

`$trunk/mk-parallel-dump/mk-parallel-dump -F $cnf --base-dir $basedir -d test -t issue_30 --chunk-size 25 --no-zero-chunk`;

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
