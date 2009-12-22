#!/usr/bin/perl

use strict;
use warnings FATAL => 'all';
use English qw(-no_match_vars);
use Test::More tests => 4;

require "../SlowLogParser.pm";
require "../SlowLogWriter.pm";

my $p = new SlowLogParser;
my $w = new SlowLogWriter;

sub no_diff {
   my ( $filename, $expected ) = @_;
   
   # Parse and rewrite the original file.
   my $tmp_file = '/tmp/SlowLogWriter-test.txt';
   open my $rewritten_fh, '>', $tmp_file or BAIL_OUT($EVAL_ERROR);
   open my $fh, "<", $filename or BAIL_OUT($OS_ERROR);
   my %args = (
      next_event => sub { return <$fh>;    },
      tell       => sub { return tell $fh; },
   );
   while ( my $e = $p->parse_event(%args) ) {
      $w->write($rewritten_fh, $e);
   }
   close $fh;
   close $rewritten_fh;

   # Compare the contents of the two files.
   my $retval = system("diff $tmp_file $expected");
   `rm -rf $tmp_file`;
   $retval = $retval >> 8;
   return !$retval;
}

sub write_event {
   my ( $event, $expected_output ) = @_;
   my $tmp_file = '/tmp/SlowLogWriter-output.txt';
   open my $fh, '>', $tmp_file or die "Cannot open $tmp_file: $OS_ERROR";
   $w->write($fh, $event);
   close $fh;
   my $retval = system("diff $tmp_file $expected_output");
   `rm -rf $tmp_file`;
   $retval = $retval >> 8;
   return !$retval;
}

# Check that I can write a slow log in the default slow log format.
ok(
   no_diff('samples/slow001.txt', 'samples/slow001-rewritten.txt'),
   'slow001.txt rewritten'
);

# Test writing a Percona-patched slow log with Thread_id and hi-res Query_time.
ok(
   no_diff('samples/slow032.txt', 'samples/slow032-rewritten.txt'),
   'slow032.txt rewritten'
);

ok(
   write_event(
      {
         Query_time => '1',
         arg        => 'select * from foo',
         ip         => '127.0.0.1',
         port       => '12345',
      },
      'samples/slowlogwriter001.txt',
   ),
   'Writes Client attrib from tcpdump',
);

ok(
   write_event(
      {
         Query_time => '1.123456',
         Lock_time  => '0.000001',
         arg        => 'select * from foo',
      },
      'samples/slowlogwriter002.txt',
   ),
   'Writes microsecond times'
);

# #############################################################################
# Done.
# #############################################################################
diag(`rm -rf SlowLogWriter-test.txt >/dev/null 2>&1`);
exit;
