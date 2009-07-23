#!/usr/bin/perl

use strict;
use warnings FATAL => 'all';
use English qw(-no_match_vars);
use Test::More tests => 4;

require "../MaatkitTest.pm";
require "../SlowLogParser.pm";
require "../SlowLogWriter.pm";

MaatkitTest->import(qw(load_file));

my $p = new SlowLogParser;
my $w = new SlowLogWriter;

sub run_test {
   my ( $filename, $expected ) = @_;
   my $original;
   my $buffer = '';
   open my $fh2, ">", \$buffer or die $OS_ERROR;
   eval {
      # Parse the original file and write the results back to $buffer.
      open my $fh, "<", $filename or die $OS_ERROR;
      1 while $p->parse_event($fh, undef, sub { $w->write($fh2, @_) });
      close $fh;

      if ( $expected ) {
         $original = load_file($expected);
      }
      else {
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
         # Remove SET statements because SlowLogParser will have made these
         # into event attribs, but we can't from here which attribs were SETs.
         $original =~ s/^SET\s+.+?;\n//mg;
      }

      close $fh2;
      close $fh;
   };

   # Compare the contents of the two files.
   is($EVAL_ERROR, '', "No error on $filename");
   is($buffer, $original, "Correct output for $filename");
}

# Check that I can write a slow log in the default slow log format.
run_test('samples/slow001.txt');

# Test writing a Percona-patched slow log with Thread_id and hi-res Query_time.
run_test('samples/slow032.txt', 'samples/slow032-rewritten.txt');

# #############################################################################
# Done.
# #############################################################################
exit;
