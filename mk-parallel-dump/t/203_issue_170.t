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
require "$trunk/mk-parallel-dump/mk-parallel-dump";

my $dp = new DSNParser(opts=>$dsn_opts);
my $sb = new Sandbox(basedir => '/tmp', DSNParser => $dp);
my $dbh = $sb->get_dbh_for('master');

if ( !$dbh ) {
   plan skip_all => 'Cannot connect to sandbox master';
}
else {
   plan tests => 1;
}

my $cnf = '/tmp/12345/my.sandbox.cnf';
my $cmd = "$trunk/mk-parallel-dump/mk-parallel-dump -F $cnf ";
my $mysql = $sb->_use_for('master');

$sb->create_dbs($dbh, ['test']);

my $output;
my $basedir = '/tmp/dump/';
diag(`rm -rf $basedir`);

my @tbls;

# #############################################################################
# Issue 170: mk-parallel-dump dies when table-status Data_length is NULL
# #############################################################################
diag(`rm -rf $basedir`);
diag(`cp $trunk/mk-parallel-dump/t/samples/broken_tbl.frm /tmp/12345/data/test/broken_tbl.frm`);
$output = `$cmd --base-dir $basedir -d test 2>&1`;
like(
   $output,
   qr/all\s+\S+\s+1\s+0\s+\-/,
   'Runs but does not die on broken table'
);
diag(`rm -rf /tmp/12345/data/test/broken_tbl.frm`);

# #############################################################################
# Done.
# #############################################################################
diag(`rm -rf $basedir`);
$sb->wipe_clean($dbh);
exit;
