#!/usr/bin/perl

use strict;
use warnings FATAL => 'all';

use Test::More tests => 3;
use English qw(-no_match_vars);

require "../mk-log-parser";

my $p = new LogParser;
my @e;
my $i;
my $events;
my $file;

sub simple_callback {
   my ( $event ) = @_;
   push @e, $event;
}

# Check that I can parse a simple log with defaults (the general query log
# format).
$events = [
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
];

@e = ();
open $file, "<", 'samples/log001.txt' or die $OS_ERROR;
1 while ( $p->parse_event($file, \&simple_callback) );
close $file;
is_deeply(
   \@e,
   $events,
   "Got events from the simple log file",
);

# Check that I can parse a slow log in the default slow log format.
$events = [
   {
      ts  => '071015 21:43:52',
      cmd => 'Init DB',
      user => 'root',
      host => 'localhost',
      ip   => '',
      arg => 'test',
      query_time => 2,
      lock_time => 0,
      rows_sent => 1,
      rows_exam => 0,
   },
   {
      ts  => '071015 21:43:52',
      cmd => 'Query',
      user => 'root',
      host => 'localhost',
      ip   => '',
      arg => 'select sleep(2) from n',
      query_time => 2,
      lock_time => 0,
      rows_sent => 1,
      rows_exam => 0,
   },
   {
      ts  => '071015 21:45:10',
      cmd => 'Init DB',
      user => 'root',
      host => 'localhost',
      ip   => '',
      arg => 'sakila',
      query_time => 2,
      lock_time => 0,
      rows_sent => 1,
      rows_exam => 0,
   },
   {
      ts  => '071015 21:45:10',
      cmd => 'Query',
      user => 'root',
      host => 'localhost',
      ip   => '',
      arg => 'select sleep(2) from test.n',
      query_time => 2,
      lock_time => 0,
      rows_sent => 1,
      rows_exam => 0,
   },
];

open $file, "<", 'samples/slow001.txt' or die $OS_ERROR;
@e = ();
1 while ( $p->parse_event($file, \&simple_callback) );
close $file;
is_deeply(
   \@e,
   $events,
   "Got events from the slow log",
);

# Check that I can parse a slow log in the micro-second slow log format.
$events = [
   {
      ts  => '071015 21:43:52',
      cmd => 'Query',
      user => 'root',
      host => 'localhost',
      ip   => '',
      arg => "SELECT id FROM users WHERE name='baouong'",
      query_time => '0.000652',
      lock_time => '0.000109',
      rows_sent => 1,
      rows_exam => 1,
   },
   {
      ts  => '071015 21:43:52',
      cmd => 'Query',
      user => 'root',
      host => 'localhost',
      ip   => '',
      arg => "INSERT IGNORE INTO articles (id, body,)VALUES(3558268,'sample text')",
      query_time => '0.001943',
      lock_time => '0.000145',
      rows_sent => 0,
      rows_exam => 0,
   },
];

open $file, "<", 'samples/microslow001.txt' or die $OS_ERROR;
@e = ();
1 while ( $p->parse_event($file, \&simple_callback) );
close $file;
is_deeply(
   \@e,
   $events,
   "Got events from the micro slow log",
);
