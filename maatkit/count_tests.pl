#!/usr/bin/env perl

# This script, count_tests.pl, is used to count the number of Test::More
# tests in a properly formatted test file. A properly formatted test file
# is described at http://code.google.com/p/maatkit/wiki/CodingStandards

use strict;
use warnings FATAL => 'all';
use English qw(-no_match_vars);

my $test_script = $ARGV[0];

if ( !$test_script ) {
   print "No test script file given.\n"
       . "Usage: verify_test.pl FILE\n";
       exit;
}
elsif ( !-f $test_script ) {
   print "The file $test_script does not exist.\n";
   exit;
}

open my $fh, '<', $test_script
   or die "Cannot open $test_script: $OS_ERROR";

my %tests = (
   is_deeply => 0,
   ok        => 0,
   cmp_ok    => 0,
   is        => 0,
   isa_ok    => 0,
   like      => 0,
   unlike    => 0,
);
my $test_keywords = join '|', keys %tests;
my $total_tests   = 0;
my $use_test_line = undef;

while ( my $line = <$fh> ) {
   if ( my ($test, $spaces) = $line =~ m/^\s*($test_keywords)(\s*)\(/o ) {
      $tests{$test}++;
      $total_tests++;
      if ( $spaces ) {
         print "Spaces between sub and opening ( at line $NR: $line\n";
      }
   }
   elsif ( $line =~ m/^use Test::More tests => \d+/ ) {
      chomp $line;
      $use_test_line = "\n$line (at line $INPUT_LINE_NUMBER)\n";
   } 
};

close $fh;

foreach my $test ( keys %tests ) {
   print "$test tests: $tests{$test}\n";
};
print $use_test_line if $use_test_line;
print "\nTOTAL tests: $total_tests\n";

exit;
