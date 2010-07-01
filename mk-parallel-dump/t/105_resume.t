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
   plan skip_all => 'Cannot connect to MySQL';
}
elsif ( !@{$dbh->selectcol_arrayref('SHOW DATABASES LIKE "sakila"')} ) {
   plan skip_all => 'sakila db not loaded';
}
else {
   plan tests => 2;
}

my $output;
my $basedir = '/tmp/dump/';
my $cnf     = '/tmp/12345/my.sandbox.cnf';
my $cmd     = "$trunk/mk-parallel-dump/mk-parallel-dump -F $cnf ";

diag(`rm -rf $basedir`);

# #########################################################################
# Issue 495: mk-parallel-dump: permit to disable resuming behavior
# #########################################################################
diag(`$cmd --base-dir $basedir -d sakila -t film,actor >/dev/null`);
$output = `$cmd --base-dir $basedir -d sakila -t film,actor --no-resume -v 2>&1`;
like(
   $output,
   qr/all\s+\S+\s+0\s+0\s+\-/,
   '--no-resume (no chunks)'
);

diag(`rm -rf $basedir`);
diag(`$cmd --base-dir $basedir -d sakila -t film,actor --chunk-size 100 >/dev/null`);
$output = `$cmd --base-dir $basedir -d sakila -t film,actor --no-resume -v --chunk-size 100 2>&1`;
like(
   $output,
   qr/all\s+\S+\s+0\s+0\s+\-/,
   '--no-resume (with chunks)'
);

# #############################################################################
# Done.
# #############################################################################
exit;
