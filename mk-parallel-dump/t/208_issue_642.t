#!/usr/bin/env perl

use strict;
use warnings FATAL => 'all';
use English qw(-no_match_vars);
use Test::More tests => 1;

require '../mk-parallel-dump';
require '../../common/Sandbox.pm';
my $dp  = new DSNParser();
my $sb  = new Sandbox(basedir => '/tmp', DSNParser => $dp);
my $dbh = $sb->get_dbh_for('master');

my $cnf = '/tmp/12345/my.sandbox.cnf';
my $cmd = "perl ../mk-parallel-dump -F $cnf ";

my $basedir = '/tmp/dump/';

# #############################################################################
# Issue 642: mk-parallel-dump --progress is incorrect when using --chunk-size
# #############################################################################
diag(`rm -rf $basedir`);
SKIP: {
   skip 'Sandbox master does not have the sakila database', 1
      unless $dbh && @{$dbh->selectcol_arrayref('SHOW DATABASES LIKE "sakila"')};

   my @lines = `$cmd --base-dir $basedir -v -v -d sakila -t actor --threads 1 --progress --chunk-size 50`;
   shift @lines;  # header
   pop @lines;  # all
   my @progress = map { grep { $_ =~ m/k\// } split(/\s+/, $_) } @lines;

   is_deeply(
      \@progress,
      [
         '3.96k/16.00k',
         '7.91k/16.00k',
         '11.87k/16.00k',
         '15.82k/16.00k',
         '15.82k/16.00k',
         '15.82k/16.00k'
      ],
      '--progress with --chunk-size (issue 642)'
   );
}

# #############################################################################
# Done.
# #############################################################################
diag(`rm -rf $basedir`);
exit;
