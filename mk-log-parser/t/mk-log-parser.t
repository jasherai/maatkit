#!/usr/bin/perl

use strict;
use warnings FATAL => 'all';

use Test::More;
use English qw(-no_match_vars);

# Each test file is self-contained.  It has the command-line at the top of the
# file and the results below.
my @files = <test_*>;
plan tests => scalar(@files);

foreach my $file ( <test_*> ) {
   my $result = `./run_test $file`;
   chomp $result;
   is($result, '', $file);
}
