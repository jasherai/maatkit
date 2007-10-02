#!/usr/bin/perl

use strict;
use warnings FATAL => 'all';

use Test::More tests => 11;
use English qw(-no_match_vars);

require "../mysql-log-parser";

my $p = new LogParser;
my $e;
my $i;

sub simple_callback {
   my ( $event ) = @_;
   $e = $event;
}

# Check that I can parse a simple log with defaults (the general query log
# format).
open my $file, "<", 'samples/log001.txt' or die $OS_ERROR;
my @events = (
   {
      ts  => '071002  7:11:56',
      id  => 7,
      cmd => 'Quit',
      arg => '',
   },
   {
      ts  => '071002  8:08:13',
      id  => 8,
      cmd => 'Connect',
      arg => 'baron@localhost on ',
   },
   {
      ts  => '',
      id  => 8,
      cmd => 'Query',
      arg => 'select @@version_comment limit 1',
   },
   {
      ts  => '071002  8:08:23',
      id  => 8,
      cmd => 'Quit',
      arg => '',
   },
   {
      ts  => '071002  8:08:25',
      id  => 9,
      cmd => 'Connect',
      arg => 'baron@localhost on test',
   },
   {
      ts  => '',
      id  => 9,
      cmd => 'Query',
      arg => 'show databases',
   },
   {
      ts  => '',
      id  => 9,
      cmd => 'Query',
      arg => 'show tables',
   },
   {
      ts  => '',
      id  => 9,
      cmd => 'Field List',
      arg => 'transport_backup ',
   },
   {
      ts  => '',
      id  => 9,
      cmd => 'Init DB',
      arg => 'test',
   },
   {
      ts  => '',
      id  => 9,
      cmd => 'Query',
      arg => 'CREATE TABLE `t1` (
  `a` int(11) default NULL
) ENGINE=MyISAM DEFAULT CHARSET=latin1',
   },
   {
      ts  => '071002  8:08:53',
      id  => 9,
      cmd => 'Quit',
      arg => '',
   },
);

$i = 0;
foreach my $event(@events) {
   $p->parse_event($file, \&simple_callback);
   is_deeply(
      $e,
      $event,
      "Got event $i from the file",
   );
   $i++;
}
