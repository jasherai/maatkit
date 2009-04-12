#!/usr/bin/perl

use strict;
use warnings FATAL => 'all';

use Test::More tests => 4;
use English qw(-no_match_vars);

require "../SlowLogParser.pm";
require "../SlowLogWriter.pm";

my $p = new SlowLogParser;
my $w = new SlowLogWriter;

sub run_test {
   my ( $filename ) = @_;
   my $original;
   my $buffer;
   open my $fh2, ">", \$buffer or die $OS_ERROR;
   eval {
      # Parse the original file and write the results back to $buffer.
      open my $fh, "<", $filename or die $OS_ERROR;
      1 while $p->parse_event($fh, undef, sub { $w->write($fh2, @_) });
      close $fh;

      # Read the original into RAM; clean up the header lines from $original.
      open $fh, "<", $filename or die $OS_ERROR;
      local $INPUT_RECORD_SEPARATOR = undef;
      $original = <$fh>;
      $original =~ s{
         ^(?:
         Tcp\sport:.*
         |/\S+/mysqld.*
         |Time\s+Id\s+Command.*
         )\n
      }{}gxm;
      close $fh;
      close $fh2;
   };

   # Compare the contents of the two files.
   is($EVAL_ERROR, '', "No error on $filename");
   is($buffer, $original, "Correct output for $filename");
}

# Check that I can write a slow log in the default slow log format.
run_test('samples/slow001.txt');
