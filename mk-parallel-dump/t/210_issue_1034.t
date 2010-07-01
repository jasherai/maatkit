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

# #############################################################################
# Issue 1034: Dumping empty database crashes mk-parallel-dump
# #############################################################################
$output = `$cmd --base-dir $basedir --no-gzip --threads 1 --progress -d test`;
like(
   $output,
   qr/all/,
   "Does not crash dumping only an empty db"
);

# #############################################################################
# Done.
# #############################################################################
diag(`rm -rf $basedir`);
$sb->wipe_clean($dbh);
exit;
