#!/usr/bin/perl

use strict;
use warnings FATAL => 'all';

use Test::More tests => 1;
use English qw(-no_match_vars);

require "../mysql-log-parser";

my $p = new LogParser;
my $e;

sub simple_callback {
   my ( $event ) = @_;
   $e = $event;
}

# Check that I can parse a simple event with defaults (the general query log
# format).
open my $file, "<", 'samples/log001.txt' or die $OS_ERROR;
$p->parse_event($file, \&simple_callback);
is_deeply(
   $e,
   {
      ts  => '071002  7:11:56',
      id  => 7,
      cmd => 'Quit',
      arg => '',
   },
   'Got the first event from the file',
);
