#!/usr/bin/perl

use strict;
use warnings FATAL => 'all';

use Test::More tests => 27;
use English qw(-no_match_vars);
use Data::Dumper;

require "../LogParser.pm";

my $p = new LogParser;
my @e;
my $i;
my $events;
my $file;

sub simple_callback {
   my ($event) = @_;
   push @e, $event;
}

# ###########################################################################
# Code that tries to handle all log formats at once.
# ###########################################################################

# Check that I can parse a simple log with defaults (the general query log
# format).
$events = [
   {  ts  => '071002  7:11:56',
      id  => 7,
      cmd => 'Quit',
      arg => '',
      NR  => 4,
   },
   {  ts  => '071002  8:08:13',
      id  => 8,
      cmd => 'Connect',
      arg => 'baron@localhost on ',
      NR  => 5,
   },
   {  ts  => '',
      id  => 8,
      cmd => 'Query',
      arg => 'select @@version_comment limit 1',
      NR  => 7,
   },
   {  ts  => '071002  8:08:23',
      id  => 8,
      cmd => 'Quit',
      arg => '',
      NR  => 7,
   },
   {  ts  => '071002  8:08:25',
      id  => 9,
      cmd => 'Connect',
      arg => 'baron@localhost on test',
      NR  => 8,
   },
   {  ts  => '',
      id  => 9,
      cmd => 'Query',
      arg => 'show databases',
      NR  => 10,
   },
   {  ts  => '',
      id  => 9,
      cmd => 'Query',
      arg => 'show tables',
      NR  => 11,
   },
   {  ts  => '',
      id  => 9,
      cmd => 'Field List',
      arg => 'transport_backup ',
      NR  => 11,
   },
   {  ts  => '',
      id  => 9,
      cmd => 'Init DB',
      arg => 'test',
      NR  => 12,
   },
   {  ts  => '',
      id  => 9,
      cmd => 'Query',
      arg => 'CREATE TABLE `t1` (
  `a` int(11) default NULL
) ENGINE=MyISAM DEFAULT CHARSET=latin1',
      NR => 16,
   },
   {  ts  => '071002  8:08:53',
      id  => 9,
      cmd => 'Quit',
      arg => '',
      NR  => 16,
   },
];

@e = ();
open $file, "<", 'samples/log001.txt' or die $OS_ERROR;
1 while ( $p->parse_event( $file, \&simple_callback ) );
close $file;
is_deeply( \@e, $events, "Got events from the simple log file", );

# Check that I can parse a slow log in the default slow log format.
$events = [
   {  ts            => '071015 21:43:52',
      cmd           => 'Query',
      user          => 'root',
      host          => 'localhost',
      ip            => '',
      db            => 'test',
      arg           => 'select sleep(2) from n',
      Query_time    => 2,
      Lock_time     => 0,
      Rows_sent     => 1,
      Rows_examined => 0,
      NR            => 9,
   },
   {  ts            => '071015 21:45:10',
      db            => 'sakila',
      cmd           => 'Query',
      user          => 'root',
      host          => 'localhost',
      ip            => '',
      arg           => 'select sleep(2) from test.n',
      Query_time    => 2,
      Lock_time     => 0,
      Rows_sent     => 1,
      Rows_examined => 0,
      NR            => 13,
   },
];

open $file, "<", 'samples/slow001.txt' or die $OS_ERROR;
@e = ();
1 while ( $p->parse_event( $file, \&simple_callback ) );
close $file;
is_deeply( \@e, $events, "Got events from the slow log", );

# Check that I can parse a slow log in the micro-second slow log format.
$events = [
   {  ts            => '071015 21:43:52',
      cmd           => 'Query',
      user          => 'root',
      host          => 'localhost',
      ip            => '',
      arg           => "SELECT id FROM users WHERE name='baouong'",
      Query_time    => '0.000652',
      Lock_time     => '0.000109',
      Rows_sent     => 1,
      Rows_examined => 1,
      NR            => 5,
   },
   {  ts   => '071015 21:43:52',
      cmd  => 'Query',
      user => 'root',
      host => 'localhost',
      ip   => '',
      arg =>
         "INSERT IGNORE INTO articles (id, body,)VALUES(3558268,'sample text')",
      Query_time    => '0.001943',
      Lock_time     => '0.000145',
      Rows_sent     => 0,
      Rows_examined => 0,
      NR            => 8,
   },
];

open $file, "<", 'samples/microslow001.txt' or die $OS_ERROR;
@e = ();
1 while ( $p->parse_event( $file, \&simple_callback ) );
close $file;
is_deeply( \@e, $events, "Got events from the micro slow log", );

$events = [
   {  cmd            => 'Query',
      arg            => 'BEGIN',
      ts             => '071218 11:48:27',
      Disk_filesort  => 'No',
      Merge_passes   => '0',
      Full_scan      => 'No',
      Full_join      => 'No',
      Thread_id      => '10',
      Tmp_table      => 'No',
      QC_Hit         => 'No',
      Rows_examined  => '0',
      Filesort       => 'No',
      Query_time     => '0.000012',
      Disk_tmp_table => 'No',
      Rows_sent      => '0',
      Lock_time      => '0.000000',
      ip             => '',
      user           => '[SQL_SLAVE]',
      NR             => 8,
      host           => '',
   },
   {  cmd      => 'Query',
      db       => 'db1',
      settings => ['SET timestamp=1197996507'],
      arg      => 'update db2.tuningdetail_21_265507 n
      inner join db1.gonzo a using(gonzo) 
      set n.column1 = a.column1, n.word3 = a.word3',
      Disk_filesort  => 'No',
      Merge_passes   => '0',
      Full_scan      => 'Yes',
      Full_join      => 'No',
      Thread_id      => '10',
      Tmp_table      => 'No',
      QC_Hit         => 'No',
      Rows_examined  => '62951',
      Filesort       => 'No',
      Query_time     => '0.726052',
      Disk_tmp_table => 'No',
      Rows_sent      => '0',
      Lock_time      => '0.000091',
      NR             => 19,
      ip             => '',
      user           => '[SQL_SLAVE]',
      host           => '',
   },
   {  settings => ['SET timestamp=1197996507'],
      arg      => 'INSERT INTO db3.vendor11gonzo (makef, bizzle)
VALUES (\'\', \'Exact\')',
      InnoDB_IO_r_bytes     => '0',
      Merge_passes          => '0',
      Full_join             => 'No',
      InnoDB_pages_distinct => '24',
      Filesort              => 'No',
      InnoDB_queue_wait     => '0.000000',
      Rows_sent             => '0',
      Lock_time             => '0.000077',
      InnoDB_rec_lock_wait  => '0.000000',
      cmd                   => 'Query',
      Full_scan             => 'No',
      Disk_filesort         => 'No',
      Thread_id             => '10',
      Tmp_table             => 'No',
      QC_Hit                => 'No',
      Rows_examined         => '0',
      InnoDB_IO_r_ops       => '0',
      Disk_tmp_table        => 'No',
      Query_time            => '0.000512',
      InnoDB_IO_r_wait      => '0.000000',
      NR                    => 30,
      ip             => '',
      user           => '[SQL_SLAVE]',
      host           => '',
   },
   {  arg => 'UPDATE db4.vab3concept1upload
SET    vab3concept1id = \'91848182522\'
WHERE  vab3concept1upload=\'6994465\'',
      InnoDB_IO_r_bytes     => '0',
      Merge_passes          => '0',
      Full_join             => 'No',
      InnoDB_pages_distinct => '11',
      Filesort              => 'No',
      InnoDB_queue_wait     => '0.000000',
      Rows_sent             => '0',
      Lock_time             => '0.000028',
      InnoDB_rec_lock_wait  => '0.000000',
      cmd                   => 'Query',
      Full_scan             => 'No',
      Disk_filesort         => 'No',
      Thread_id             => '10',
      Tmp_table             => 'No',
      QC_Hit                => 'No',
      Rows_examined         => '0',
      InnoDB_IO_r_ops       => '0',
      Disk_tmp_table        => 'No',
      Query_time            => '0.033384',
      InnoDB_IO_r_wait      => '0.000000',
      NR                    => 41,
      ip             => '',
      user           => '[SQL_SLAVE]',
      host           => '',
   },
   {  settings => ['SET insert_id=34484549,timestamp=1197996507'],
      arg      => 'INSERT INTO db1.conch (word3, vid83)
VALUES (\'211\', \'18\')',
      InnoDB_IO_r_bytes     => '0',
      Merge_passes          => '0',
      Full_join             => 'No',
      InnoDB_pages_distinct => '18',
      Filesort              => 'No',
      InnoDB_queue_wait     => '0.000000',
      Rows_sent             => '0',
      Lock_time             => '0.000027',
      InnoDB_rec_lock_wait  => '0.000000',
      cmd                   => 'Query',
      Full_scan             => 'No',
      Disk_filesort         => 'No',
      Thread_id             => '10',
      Tmp_table             => 'No',
      QC_Hit                => 'No',
      Rows_examined         => '0',
      InnoDB_IO_r_ops       => '0',
      Disk_tmp_table        => 'No',
      Query_time            => '0.000530',
      InnoDB_IO_r_wait      => '0.000000',
      NR                    => 52,
      ip             => '',
      user           => '[SQL_SLAVE]',
      host           => '',
   },
   {  arg => 'UPDATE foo.bar
SET    biz = \'91848182522\'',
      InnoDB_IO_r_bytes     => '0',
      Merge_passes          => '0',
      Full_join             => 'No',
      InnoDB_pages_distinct => '18',
      Filesort              => 'No',
      InnoDB_queue_wait     => '0.000000',
      Rows_sent             => '0',
      Lock_time             => '0.000027',
      InnoDB_rec_lock_wait  => '0.000000',
      cmd                   => 'Query',
      Full_scan             => 'No',
      Disk_filesort         => 'No',
      Thread_id             => '10',
      Tmp_table             => 'No',
      QC_Hit                => 'No',
      Rows_examined         => '0',
      InnoDB_IO_r_ops       => '0',
      Disk_tmp_table        => 'No',
      Query_time            => '0.000530',
      InnoDB_IO_r_wait      => '0.000000',
      NR                    => 62,
      ip             => '',
      user           => '[SQL_SLAVE]',
      host           => '',
   },
   {  arg => 'UPDATE bizzle.bat
SET    boop=\'bop: 899\'
WHERE  fillze=\'899\'',
      settings              => ['SET timestamp=1197996508'],
      InnoDB_IO_r_bytes     => '0',
      Merge_passes          => '0',
      Full_join             => 'No',
      InnoDB_pages_distinct => '18',
      Filesort              => 'No',
      InnoDB_queue_wait     => '0.000000',
      Rows_sent             => '0',
      Lock_time             => '0.000027',
      InnoDB_rec_lock_wait  => '0.000000',
      cmd                   => 'Query',
      Full_scan             => 'No',
      Disk_filesort         => 'No',
      Thread_id             => '10',
      Tmp_table             => 'No',
      QC_Hit                => 'No',
      Rows_examined         => '0',
      InnoDB_IO_r_ops       => '0',
      Disk_tmp_table        => 'No',
      Query_time            => '0.000530',
      InnoDB_IO_r_wait      => '0.000000',
      NR                    => 74,
      ip             => '',
      user           => '[SQL_SLAVE]',
      host           => '',
   },
   {  arg => 'UPDATE foo.bar
SET    biz = \'91848182522\'',
      InnoDB_IO_r_bytes     => '0',
      Merge_passes          => '0',
      Full_join             => 'No',
      InnoDB_pages_distinct => '18',
      Filesort              => 'No',
      InnoDB_queue_wait     => '0.000000',
      Rows_sent             => '0',
      Lock_time             => '0.000027',
      InnoDB_rec_lock_wait  => '0.000000',
      cmd                   => 'Query',
      Full_scan             => 'No',
      Disk_filesort         => 'No',
      Thread_id             => '10',
      Tmp_table             => 'No',
      QC_Hit                => 'No',
      Rows_examined         => '0',
      InnoDB_IO_r_ops       => '0',
      Disk_tmp_table        => 'No',
      Query_time            => '0.000530',
      InnoDB_IO_r_wait      => '0.000000',
      NR                    => 83,
      ip             => '',
      user           => '[SQL_SLAVE]',
      host           => '',
   },
];

open $file, "<", 'samples/slow002.txt' or die $OS_ERROR;
@e = ();
1 while ( $p->parse_event( $file, \&simple_callback ) );
close $file;
is_deeply( \@e, $events, "Got events from the microslow log", );

eval {
   open $file, "<", 'samples/slow003.txt' or die $OS_ERROR;
   1 while ( $p->parse_event( $file, \&simple_callback ) );
   close $file;
};
is( $EVAL_ERROR, '', 'Blank entry did not crash' );

# Check a slow log that has tabs in it.
$events = [
   {  cmd            => 'Query',
      arg            => "foo\nbar\n\t\t\t0 AS counter\nbaz",
      ts             => '071218 11:48:27',
      Disk_filesort  => 'No',
      Merge_passes   => '0',
      Full_scan      => 'No',
      Full_join      => 'No',
      Thread_id      => '10',
      Tmp_table      => 'No',
      QC_Hit         => 'No',
      Rows_examined  => '0',
      Filesort       => 'No',
      Query_time     => '0.000012',
      Disk_tmp_table => 'No',
      Rows_sent      => '0',
      Lock_time      => '0.000000',
      NR             => 10,
      user           => '[SQL_SLAVE]',
      host           => '',
      ip             => '',
   },
];

open $file, "<", 'samples/slow005.txt' or die $OS_ERROR;
@e = ();
1 while ( $p->parse_event( $file, \&simple_callback ) );
close $file;

is_deeply( \@e, $events, "microslow log with tabs", );

@e = ();
open $file, "<", 'samples/slow007.txt' or die $OS_ERROR;
1 while ( $p->parse_event( $file, \&simple_callback ) );
close $file;
$events = [
   {  cmd            => 'Query',
      Schema         => 'food',
      arg            => 'SELECT fruit FROM trees',
      ts             => '071218 11:48:27',
      Disk_filesort  => 'No',
      Merge_passes   => '0',
      Full_scan      => 'No',
      Full_join      => 'No',
      Thread_id      => '3',
      Tmp_table      => 'No',
      QC_Hit         => 'No',
      Rows_examined  => '0',
      Filesort       => 'No',
      Query_time     => '0.000012',
      Disk_tmp_table => 'No',
      Rows_sent      => '0',
      Lock_time      => '0.000000',
      NR             => 7,
      user           => '[SQL_SLAVE]',
      host           => '',
      ip             => '',
   },
];
is_deeply( \@e, $events, 'Parses Schema' );

@e = ();
open $file, "<", 'samples/slow006.txt' or die $OS_ERROR;
1 while ( $p->parse_event( $file, \&simple_callback ) );
close $file;
is( $e[2]->{db}, 'bar', 'Parsing USE is case-insensitive (parse_event)' );
@e = ();
open $file, "<", 'samples/slow006.txt' or die $OS_ERROR;
1 while ( $p->parse_slowlog_event( $file, undef, \&simple_callback ) );
close $file;
is( $e[2]->{db}, 'bar', 'Parsing USE is case-insensitive (parse_slowlog_event)' );

$events = [
   {  'Schema'        => 'db1',
      'cmd'           => 'Admin',
      'ip'            => '1.2.3.8',
      'arg'           => 'Quit',
      'Thread_id'     => '5',
      'host'          => '',
      'Rows_examined' => '0',
      'NR'            => '6',
      'user'          => 'meow',
      'Query_time'    => '0.000002',
      'Lock_time'     => '0.000000',
      'Rows_sent'     => '0',
   },
   {  'Schema'        => 'db2',
      'cmd'           => 'Query',
      'db'            => 'db',
      'ip'            => '1.2.3.8',
      'settings'      => [ 'SET NAMES utf8' ],
      'Thread_id'     => '6',
      'host'          => '',
      'Rows_examined' => '0',
      'NR'            => '12',
      'user'          => 'meow',
      'Query_time'    => '0.000899',
      'Lock_time'     => '0.000000',
      'Rows_sent'     => '0',
   },
   {  'Schema'        => 'db2',
      'cmd'           => 'Query',
      'arg'           => 'SELECT MIN(id),MAX(id) FROM tbl',
      'ip'            => '1.2.3.8',
      'Thread_id'     => '6',
      'host'          => '',
      'Rows_examined' => '0',
      'NR'            => '16',
      'user'          => 'meow',
      'Query_time'    => '0.018799',
      'Lock_time'     => '0.009453',
      'Rows_sent'     => '0'
   },
];
@e = ();
open $file, "<", 'samples/slow008.txt' or die $OS_ERROR;
1 while ( $p->parse_event( $file, \&simple_callback ) );
close $file;
is_deeply( \@e, $events, 'Parses commented event (admin cmd) (parse_event)' );
@e = ();
$events->[0]->{arg} = '# administrator command: Quit';
$events->[1]->{arg} = 'SET NAMES utf8';
delete $events->[1]->{settings};
delete $events->[0]->{NR};
delete $events->[1]->{NR};
delete $events->[2]->{NR};
$events->[0]->{pos_in_log} = 0;
$events->[1]->{pos_in_log} = 221;
$events->[2]->{pos_in_log} = 435;
open $file, "<", 'samples/slow008.txt' or die $OS_ERROR;
1 while ( $p->parse_slowlog_event( $file, undef, \&simple_callback ) );
close $file;
is_deeply( \@e, $events, 'Parses commented event (admin cmd) (parse_slowlog_event)' );

@e = ();
open $file, "<", 'samples/slow011.txt' or die $OS_ERROR;
1 while ( $p->parse_event( $file, \&simple_callback ) );
$events = [
   {  'Schema'        => 'db1',
      'cmd'           => 'Admin',
      'arg'           => 'Quit',
      'ip'            => '1.2.3.8',
      'Thread_id'     => '5',
      'host'          => '',
      'Rows_examined' => '0',
      'NR'            => '6',
      'user'          => 'meow',
      'Query_time'    => '0.000002',
      'Lock_time'     => '0.000000',
      'Rows_sent'     => '0'
   },
   {  'Schema'        => 'db2',
      'db'            => 'db',
      'cmd'           => 'Query',
      'ip'            => '1.2.3.8',
      'settings'      => [ 'SET NAMES utf8' ],
      'Thread_id'     => '6',
      'host'          => '',
      'Rows_examined' => '0',
      'NR'            => '12',
      'user'          => 'meow',
      'Query_time'    => '0.000899',
      'Lock_time'     => '0.000000',
      'Rows_sent'     => '0'
   },
   {  'Schema'        => 'db2',
      'db'            => 'db2',
      'cmd'           => 'Admin',
      'arg'           => 'Quit',
      'ip'            => '1.2.3.8',
      'Thread_id'     => '7',
      'host'          => '',
      'Rows_examined' => '0',
      'NR'            => '18',
      'user'          => 'meow',
      'Query_time'    => '0.018799',
      'Lock_time'     => '0.009453',
      'Rows_sent'     => '0'
   },
   {  'Schema'        => 'db2',
      'db'            => 'db',
      'cmd'           => 'Query',
      'ip'            => '1.2.3.8',
      'settings'      => [ 'SET NAMES utf8' ],
      'Thread_id'     => '9',
      'host'          => '',
      'Rows_examined' => '0',
      'NR'            => '23',
      'user'          => 'meow',
      'Query_time'    => '0.000899',
      'Lock_time'     => '0.000000',
      'Rows_sent'     => '0'
   }
];
is_deeply( \@e, $events, 'Parses commented event lines after type 1 lines' );

# ###########################################################################
# Slow log
# ###########################################################################

# Check basically the same thing with the new code for slow-log parsing
$events = [
   {  ts            => '071015 21:43:52',
      user          => 'root',
      host          => 'localhost',
      ip            => '',
      db            => 'test',
      arg           => 'select sleep(2) from n',
      Query_time    => 2,
      Lock_time     => 0,
      Rows_sent     => 1,
      Rows_examined => 0,
      pos_in_log    => 0,
      cmd           => 'Query',
   },
   {  ts            => '071015 21:45:10',
      db            => 'sakila',
      user          => 'root',
      host          => 'localhost',
      ip            => '',
      arg           => 'select sleep(2) from test.n',
      Query_time    => 2,
      Lock_time     => 0,
      Rows_sent     => 1,
      Rows_examined => 0,
      pos_in_log    => 359,
      cmd           => 'Query',
   },
];

open $file, "<", 'samples/slow001.txt' or die $OS_ERROR;
@e = ();
1 while ( $p->parse_slowlog_event( $file, undef, \&simple_callback ) );
close $file;
is_deeply( \@e, $events, "Got events from the slow log", );

# Same thing, with slow-log code
$events = [
   {  ts            => '071015 21:43:52',
      user          => 'root',
      host          => 'localhost',
      ip            => '',
      arg           => "SELECT id FROM users WHERE name='baouong'",
      Query_time    => '0.000652',
      Lock_time     => '0.000109',
      Rows_sent     => 1,
      Rows_examined => 1,
      pos_in_log    => 0,
      cmd           => 'Query',
   },
   {  ts   => '071015 21:43:52',
      user => 'root',
      host => 'localhost',
      ip   => '',
      arg =>
         "INSERT IGNORE INTO articles (id, body,)VALUES(3558268,'sample text')",
      Query_time    => '0.001943',
      Lock_time     => '0.000145',
      Rows_sent     => 0,
      Rows_examined => 0,
      pos_in_log    => 183,
      cmd           => 'Query',
   },
];

open $file, "<", 'samples/microslow001.txt' or die $OS_ERROR;
@e = ();
1 while ( $p->parse_slowlog_event( $file, undef, \&simple_callback ) );
close $file;
is_deeply( \@e, $events, "Got events from the micro slow log", );

$events = [
   {  arg            => 'BEGIN',
      ts             => '071218 11:48:27',
      Disk_filesort  => 'No',
      Merge_passes   => '0',
      Full_scan      => 'No',
      Full_join      => 'No',
      Thread_id      => '10',
      Tmp_table      => 'No',
      QC_Hit         => 'No',
      Rows_examined  => '0',
      Filesort       => 'No',
      Query_time     => '0.000012',
      Disk_tmp_table => 'No',
      Rows_sent      => '0',
      Lock_time      => '0.000000',
      pos_in_log     => 0,
      cmd            => 'Query',
      user           => '[SQL_SLAVE]',
      host           => '',
      ip             => '',
   },
   {  db        => 'db1',
      timestamp => 1197996507,
      arg       => 'update db2.tuningdetail_21_265507 n
      inner join db1.gonzo a using(gonzo) 
      set n.column1 = a.column1, n.word3 = a.word3',
      Disk_filesort  => 'No',
      Merge_passes   => '0',
      Full_scan      => 'Yes',
      Full_join      => 'No',
      Thread_id      => '10',
      Tmp_table      => 'No',
      QC_Hit         => 'No',
      Rows_examined  => '62951',
      Filesort       => 'No',
      Query_time     => '0.726052',
      Disk_tmp_table => 'No',
      Rows_sent      => '0',
      Lock_time      => '0.000091',
      pos_in_log     => 332,
      cmd            => 'Query',
      user           => '[SQL_SLAVE]',
      host           => '',
      ip             => '',
   },
   {  timestamp => 1197996507,
      arg       => 'INSERT INTO db3.vendor11gonzo (makef, bizzle)
VALUES (\'\', \'Exact\')',
      InnoDB_IO_r_bytes     => '0',
      Merge_passes          => '0',
      Full_join             => 'No',
      InnoDB_pages_distinct => '24',
      Filesort              => 'No',
      InnoDB_queue_wait     => '0.000000',
      Rows_sent             => '0',
      Lock_time             => '0.000077',
      InnoDB_rec_lock_wait  => '0.000000',
      Full_scan             => 'No',
      Disk_filesort         => 'No',
      Thread_id             => '10',
      Tmp_table             => 'No',
      QC_Hit                => 'No',
      Rows_examined         => '0',
      InnoDB_IO_r_ops       => '0',
      Disk_tmp_table        => 'No',
      Query_time            => '0.000512',
      InnoDB_IO_r_wait      => '0.000000',
      pos_in_log            => 803,
      cmd                   => 'Query',
      user           => '[SQL_SLAVE]',
      host           => '',
      ip             => '',
   },
   {  arg => 'UPDATE db4.vab3concept1upload
SET    vab3concept1id = \'91848182522\'
WHERE  vab3concept1upload=\'6994465\'',
      InnoDB_IO_r_bytes     => '0',
      Merge_passes          => '0',
      Full_join             => 'No',
      InnoDB_pages_distinct => '11',
      Filesort              => 'No',
      InnoDB_queue_wait     => '0.000000',
      Rows_sent             => '0',
      Lock_time             => '0.000028',
      InnoDB_rec_lock_wait  => '0.000000',
      Full_scan             => 'No',
      Disk_filesort         => 'No',
      Thread_id             => '10',
      Tmp_table             => 'No',
      QC_Hit                => 'No',
      Rows_examined         => '0',
      InnoDB_IO_r_ops       => '0',
      Disk_tmp_table        => 'No',
      Query_time            => '0.033384',
      InnoDB_IO_r_wait      => '0.000000',
      pos_in_log            => 1316,
      cmd                   => 'Query',
      user           => '[SQL_SLAVE]',
      host           => '',
      ip             => '',
   },
   {  insert_id => 34484549,
      timestamp => 1197996507,
      arg       => 'INSERT INTO db1.conch (word3, vid83)
VALUES (\'211\', \'18\')',
      InnoDB_IO_r_bytes     => '0',
      Merge_passes          => '0',
      Full_join             => 'No',
      InnoDB_pages_distinct => '18',
      Filesort              => 'No',
      InnoDB_queue_wait     => '0.000000',
      Rows_sent             => '0',
      Lock_time             => '0.000027',
      InnoDB_rec_lock_wait  => '0.000000',
      Full_scan             => 'No',
      Disk_filesort         => 'No',
      Thread_id             => '10',
      Tmp_table             => 'No',
      QC_Hit                => 'No',
      Rows_examined         => '0',
      InnoDB_IO_r_ops       => '0',
      Disk_tmp_table        => 'No',
      Query_time            => '0.000530',
      InnoDB_IO_r_wait      => '0.000000',
      pos_in_log            => 1840,
      cmd                   => 'Query',
      user           => '[SQL_SLAVE]',
      host           => '',
      ip             => '',
   },
   {  arg => 'UPDATE foo.bar
SET    biz = \'91848182522\'',
      InnoDB_IO_r_bytes     => '0',
      Merge_passes          => '0',
      Full_join             => 'No',
      InnoDB_pages_distinct => '18',
      Filesort              => 'No',
      InnoDB_queue_wait     => '0.000000',
      Rows_sent             => '0',
      Lock_time             => '0.000027',
      InnoDB_rec_lock_wait  => '0.000000',
      Full_scan             => 'No',
      Disk_filesort         => 'No',
      Thread_id             => '10',
      Tmp_table             => 'No',
      QC_Hit                => 'No',
      Rows_examined         => '0',
      InnoDB_IO_r_ops       => '0',
      Disk_tmp_table        => 'No',
      Query_time            => '0.000530',
      InnoDB_IO_r_wait      => '0.000000',
      pos_in_log            => 2363,
      cmd                   => 'Query',
      user           => '[SQL_SLAVE]',
      host           => '',
      ip             => '',
   },
   {  arg => 'UPDATE bizzle.bat
SET    boop=\'bop: 899\'
WHERE  fillze=\'899\'',
      timestamp             => 1197996508,
      InnoDB_IO_r_bytes     => '0',
      Merge_passes          => '0',
      Full_join             => 'No',
      InnoDB_pages_distinct => '18',
      Filesort              => 'No',
      InnoDB_queue_wait     => '0.000000',
      Rows_sent             => '0',
      Lock_time             => '0.000027',
      InnoDB_rec_lock_wait  => '0.000000',
      Full_scan             => 'No',
      Disk_filesort         => 'No',
      Thread_id             => '10',
      Tmp_table             => 'No',
      QC_Hit                => 'No',
      Rows_examined         => '0',
      InnoDB_IO_r_ops       => '0',
      Disk_tmp_table        => 'No',
      Query_time            => '0.000530',
      InnoDB_IO_r_wait      => '0.000000',
      pos_in_log            => 2825,
      cmd                   => 'Query',
      user           => '[SQL_SLAVE]',
      host           => '',
      ip             => '',
   },
   {  arg => 'UPDATE foo.bar
SET    biz = \'91848182522\'',
      InnoDB_IO_r_bytes     => '0',
      Merge_passes          => '0',
      Full_join             => 'No',
      InnoDB_pages_distinct => '18',
      Filesort              => 'No',
      InnoDB_queue_wait     => '0.000000',
      Rows_sent             => '0',
      Lock_time             => '0.000027',
      InnoDB_rec_lock_wait  => '0.000000',
      Full_scan             => 'No',
      Disk_filesort         => 'No',
      Thread_id             => '10',
      Tmp_table             => 'No',
      QC_Hit                => 'No',
      Rows_examined         => '0',
      InnoDB_IO_r_ops       => '0',
      Disk_tmp_table        => 'No',
      Query_time            => '0.000530',
      InnoDB_IO_r_wait      => '0.000000',
      pos_in_log            => 3332,
      cmd                   => 'Query',
      user           => '[SQL_SLAVE]',
      host           => '',
      ip             => '',
   },
];

open $file, "<", 'samples/slow002.txt' or die $OS_ERROR;
@e = ();
1 while ( $p->parse_slowlog_event( $file, undef, \&simple_callback ) );
close $file;
is_deeply( \@e, $events, "Got events from the microslow log", );

eval {
   open $file, "<", 'samples/slow003.txt' or die $OS_ERROR;
   1 while ( $p->parse_slowlog_event( $file, undef, \&simple_callback ) );
   close $file;
};
is( $EVAL_ERROR, '', 'Blank entry did not crash' );

# Check a slow log that has tabs in it.
$events = [
   {  arg            => "foo\nbar\n\t\t\t0 AS counter\nbaz",
      ts             => '071218 11:48:27',
      Disk_filesort  => 'No',
      Merge_passes   => '0',
      Full_scan      => 'No',
      Full_join      => 'No',
      Thread_id      => '10',
      Tmp_table      => 'No',
      QC_Hit         => 'No',
      Rows_examined  => '0',
      Filesort       => 'No',
      Query_time     => '0.000012',
      Disk_tmp_table => 'No',
      Rows_sent      => '0',
      Lock_time      => '0.000000',
      pos_in_log     => 0,
      cmd            => 'Query',
      user           => '[SQL_SLAVE]',
      host           => '',
      ip             => '',
   },
];

@e = ();
open $file, "<", 'samples/slow005.txt' or die $OS_ERROR;
1 while ( $p->parse_slowlog_event( $file, undef, \&simple_callback ) );
close $file;

is_deeply( \@e, $events, "microslow log with tabs", );

@e = ();
open $file, "<", 'samples/slow007.txt' or die $OS_ERROR;
1 while ( $p->parse_slowlog_event( $file, undef, \&simple_callback ) );
close $file;
$events = [
   {  Schema         => 'food',
      arg            => 'SELECT fruit FROM trees',
      ts             => '071218 11:48:27',
      Disk_filesort  => 'No',
      Merge_passes   => '0',
      Full_scan      => 'No',
      Full_join      => 'No',
      Thread_id      => '3',
      Tmp_table      => 'No',
      QC_Hit         => 'No',
      Rows_examined  => '0',
      Filesort       => 'No',
      Query_time     => '0.000012',
      Disk_tmp_table => 'No',
      Rows_sent      => '0',
      Lock_time      => '0.000000',
      pos_in_log     => 0,
      cmd            => 'Query',
      user           => '[SQL_SLAVE]',
      host           => '',
      ip             => '',
   },
];
is_deeply( \@e, $events, 'Parses Schema' );

$events = [
   {  'Schema'        => 'db1',
      'ip'            => '1.2.3.8',
      'arg'           => '# administrator command: Quit',
      'Thread_id'     => '5',
      'host'          => '',
      'Rows_examined' => '0',
      'user'          => 'meow',
      'Query_time'    => '0.000002',
      'Lock_time'     => '0.000000',
      'Rows_sent'     => '0',
      pos_in_log      => 0,
      cmd             => 'Admin',
   },
   {  'Schema'        => 'db2',
      'db'            => 'db',
      'ip'            => '1.2.3.8',
      arg             => 'SET NAMES utf8',
      'Thread_id'     => '6',
      'host'          => '',
      'Rows_examined' => '0',
      'user'          => 'meow',
      'Query_time'    => '0.000899',
      'Lock_time'     => '0.000000',
      'Rows_sent'     => '0',
      pos_in_log      => 221,
      cmd             => 'Query',
   },
   {  'Schema'        => 'db2',
      'arg'           => 'SELECT MIN(id),MAX(id) FROM tbl',
      'ip'            => '1.2.3.8',
      'Thread_id'     => '6',
      'host'          => '',
      'Rows_examined' => '0',
      'user'          => 'meow',
      'Query_time'    => '0.018799',
      'Lock_time'     => '0.009453',
      'Rows_sent'     => '0',
      pos_in_log      => 435,
      cmd             => 'Query',
   },
];
@e = ();
open $file, "<", 'samples/slow008.txt' or die $OS_ERROR;
1 while ( $p->parse_slowlog_event( $file, undef, \&simple_callback ) );
close $file;
is_deeply( \@e, $events, 'Parses commented event (admin cmd)' );

$events = [
   {  'Schema'        => 'db1',
      'arg'           => '# administrator command: Quit',
      'ip'            => '1.2.3.8',
      'Thread_id'     => '5',
      'host'          => '',
      'Rows_examined' => '0',
      'user'          => 'meow',
      'Query_time'    => '0.000002',
      'Lock_time'     => '0.000000',
      'Rows_sent'     => '0',
      pos_in_log      => 0,
      cmd             => 'Admin',
   },
   {  'Schema'        => 'db2',
      'db'            => 'db',
      'ip'            => '1.2.3.8',
      arg             => 'SET NAMES utf8',
      'Thread_id'     => '6',
      'host'          => '',
      'Rows_examined' => '0',
      'user'          => 'meow',
      'Query_time'    => '0.000899',
      'Lock_time'     => '0.000000',
      'Rows_sent'     => '0',
      pos_in_log      => 221,
      cmd             => 'Query',
   },
   {  'Schema'        => 'db2',
      'db'            => 'db2',
      'arg'           => '# administrator command: Quit',
      'ip'            => '1.2.3.8',
      'Thread_id'     => '7',
      'host'          => '',
      'Rows_examined' => '0',
      'user'          => 'meow',
      'Query_time'    => '0.018799',
      'Lock_time'     => '0.009453',
      'Rows_sent'     => '0',
      pos_in_log      => 435,
      cmd             => 'Admin',
   },
   {  'Schema'        => 'db2',
      'db'            => 'db',
      'ip'            => '1.2.3.8',
      arg             => 'SET NAMES utf8',
      'Thread_id'     => '9',
      'host'          => '',
      'Rows_examined' => '0',
      'user'          => 'meow',
      'Query_time'    => '0.000899',
      'Lock_time'     => '0.000000',
      'Rows_sent'     => '0',
      pos_in_log      => 633,
      cmd             => 'Query',
   }
];
@e = ();
open $file, "<", 'samples/slow011.txt' or die $OS_ERROR;
1 while ( $p->parse_slowlog_event( $file, undef, \&simple_callback ) );
close $file;
is_deeply( \@e, $events,
   'Parses commented event lines after uncommented meta-lines' );

$events = [
   {  'Schema'        => 'sab',
      'arg'           => 'SET autocommit=1',
      'ip'            => '10.1.250.19',
      'Thread_id'     => '39387',
      'host'          => '',
      'Rows_examined' => '0',
      'user'          => 'sabapp',
      'Query_time'    => '0.000018',
      'Lock_time'     => '0.000000',
      'Rows_sent'     => '0',
      pos_in_log      => 0,
      cmd             => 'Query',
   },
   {  'Schema'        => 'sab',
      'arg'           => 'SET autocommit=1',
      'ip'            => '10.1.250.19',
      'Thread_id'     => '39387',
      'host'          => '',
      'Rows_examined' => '0',
      'user'          => 'sabapp',
      'Query_time'    => '0.000018',
      'Lock_time'     => '0.000000',
      'Rows_sent'     => '0',
      pos_in_log      => 172,
      cmd             => 'Query',
   },
];
@e = ();
open $file, "<", 'samples/slow012.txt' or die $OS_ERROR;
1 while ( $p->parse_slowlog_event( $file, undef, \&simple_callback ) );
close $file;
is_deeply( \@e, $events, 'Parses events that might look like meta');

# A pathological test case to be sure a crash doesn't happen
$events = [
   {  'Schema'        => 'abc',
      'cmd'           => 'Query',
      'arg'           => 'SET autocommit=1',
      'ip'            => '10.1.250.19',
      'Thread_id'     => '39796',
      'host'          => '',
      'pos_in_log'    => '0',
      'Rows_examined' => '0',
      'user'          => 'foo_app',
      'Query_time'    => '0.000015',
      'Rows_sent'     => '0',
      'Lock_time'     => '0.000000'
   },
   {  'Schema'        => 'test',
      'db'            => 'test',
      'cmd'           => 'Query',
      'arg'           => 'SHOW STATUS',
      'ip'            => '10.1.12.201',
      'ts'            => '081127  8:51:20',
      'Thread_id'     => '39947',
      'host'          => '',
      'pos_in_log'    => '174',
      'Rows_examined' => '226',
      'Query_time'    => '0.149435',
      'user'          => 'mytopuser',
      'Rows_sent'     => '226',
      'Lock_time'     => '0.000070'
   },
   {  'Schema'        => 'test',
      'cmd'           => 'Admin',
      'arg'           => '# administrator command: Quit',
      'ip'            => '10.1.12.201',
      'ts'            => '081127  8:51:21',
      'Thread_id'     => '39947',
      'host'          => '',
      'pos_in_log'    => '385',
      'Rows_examined' => '0',
      'Query_time'    => '0.000005',
      'user'          => 'mytopuser',
      'Rows_sent'     => '0',
      'Lock_time'     => '0.000000'
   },
   {  'Schema'        => 'abc',
      'db'            => 'abc',
      'cmd'           => 'Query',
      'arg'           => 'SET autocommit=0',
      'ip'            => '10.1.250.19',
      'Thread_id'     => '39796',
      'host'          => '',
      'pos_in_log'    => '600',
      'Rows_examined' => '0',
      'user'          => 'foo_app',
      'Query_time'    => '0.000067',
      'Rows_sent'     => '0',
      'Lock_time'     => '0.000000'
   },
   {  'Schema'        => 'abc',
      'cmd'           => 'Query',
      'arg'           => 'commit',
      'ip'            => '10.1.250.19',
      'Thread_id'     => '39796',
      'host'          => '',
      'pos_in_log'    => '782',
      'Rows_examined' => '0',
      'user'          => 'foo_app',
      'Query_time'    => '0.000015',
      'Rows_sent'     => '0',
      'Lock_time'     => '0.000000'
   }
];
@e = ();
open $file, "<", 'samples/slow013.txt' or die $OS_ERROR;
1 while ( $p->parse_slowlog_event( $file, undef, \&simple_callback ) );
close $file;
is_deeply( \@e, $events, 'Parses events that might look like meta');

# Check that lots of header lines don't cause problems.
$events = [
   {  ts            => '071015 21:43:52',
      cmd           => 'Query',
      user          => 'root',
      host          => 'localhost',
      ip            => '',
      db            => 'test',
      arg           => 'select sleep(2) from n',
      Query_time    => 2,
      Lock_time     => 0,
      Rows_sent     => 1,
      Rows_examined => 0,
      pos_in_log    => 0,
   },
   {  ts            => '071015 21:43:52',
      cmd           => 'Query',
      user          => 'root',
      host          => 'localhost',
      ip            => '',
      db            => 'test',
      arg           => 'select sleep(2) from n',
      Query_time    => 2,
      Lock_time     => 0,
      Rows_sent     => 1,
      Rows_examined => 0,
      pos_in_log    => 1313,
   },
];

open $file, "<", 'samples/slow014.txt' or die $OS_ERROR;
@e = ();
1 while ( $p->parse_slowlog_event( $file, undef, \&simple_callback ) );
close $file;
is_deeply( \@e, $events, "Parsed events with a lot of headers", );

open $file, "<", 'samples/slow015.txt' or die $OS_ERROR;
@e = ();
eval {
   1 while ( $p->parse_slowlog_event( $file, undef, \&simple_callback ) );
};
is($EVAL_ERROR, '', "No error parsing truncated event with no newline");
close $file;

# ###########################################################################
# Binary log
# ###########################################################################

# Parse binlog output.
$events = [
   { arg => '/*!40019 SET @@session.max_insert_delayed_threads=0*/' },
   {  arg =>
         '/*!50003 SET @OLD_COMPLETION_TYPE=@@COMPLETION_TYPE,COMPLETION_TYPE=0*/'
   },
   {  time      => undef,
      arg       => 'SET TIMESTAMP=1197046970/*!*/;',
      ts        => '071207 12:02:50',
      end       => '498006652',
      server_id => '21',
      type      => 'Query',
      id        => undef,
      code      => undef,
      offset    => '498006722',
   },
   {  arg => '
SET @@session.foreign_key_checks=1, @@session.sql_auto_is_null=1, @@session.unique_checks=1'
   },
   {  arg => '
SET @@session.sql_mode=0'
   },
   {  arg => '
/*!\\C latin1 */'
   },
   {  arg => '
SET @@session.character_set_client=8,@@session.collation_connection=8,@@session.collation_server=8'
   },
   {  arg => '
SET @@session.time_zone=\'SYSTEM\''
   },
   {  arg => '
BEGIN'
   },
   {  time      => undef,
      arg       => 'use test1',
      ts        => '071207 12:02:07',
      end       => '278',
      server_id => '21',
      type      => 'Query',
      id        => undef,
      code      => undef,
      offset    => '498006789'
   },
   {  arg => '
SET TIMESTAMP=1197046927'
   },
   {  arg => '
update test3.tblo as o
         inner join test3.tbl2 as e on o.animal = e.animal and o.oid = e.oid
      set e.tblo = o.tblo,
          e.col3 = o.col3
      where e.tblo is null'
   },
   {  time      => undef,
      arg       => 'SET TIMESTAMP=1197046928',
      ts        => '071207 12:02:08',
      end       => '836',
      server_id => '21',
      type      => 'Query',
      id        => undef,
      code      => undef,
      offset    => '498007067'
   },
   {  arg => '
replace into test4.tbl9(tbl5, day, todo, comment)
 select distinct o.tbl5, date(o.col3), \'misc\', right(\'foo\', 50)
      from test3.tblo as o
         inner join test3.tbl2 as e on o.animal = e.animal and o.oid = e.oid
      where e.tblo is not null
         and o.col1 > 0
         and o.tbl2 is null
         and o.col3 >= date_sub(current_date, interval 30 day)'
   },
   {  time      => undef,
      arg       => 'SET TIMESTAMP=1197046970',
      ts        => '071207 12:02:50',
      end       => '1161',
      server_id => '21',
      type      => 'Query',
      id        => undef,
      code      => undef,
      offset    => '498007625'
   },
   {  arg => '
update test3.tblo as o inner join test3.tbl2 as e
 on o.animal = e.animal and o.oid = e.oid
      set o.tbl2 = e.tbl2,
          e.col9 = now()
      where o.tbl2 is null'
   },
   {  server_id => '21',
      arg       => 'COMMIT',
      ts        => '071207 12:02:50',
      xid       => '4584956',
      type      => 'Xid',
      end       => '498007840',
      offset    => '498007950'
   },
   {  time      => undef,
      arg       => 'SET TIMESTAMP=1197046973',
      ts        => '071207 12:02:53',
      end       => '417',
      server_id => '21',
      type      => 'Query',
      id        => undef,
      code      => undef,
      offset    => '498007977'
   },
   {  arg => '
insert into test1.tbl6
      (day, tbl5, misccol9type, misccol9, metric11, metric12, secs)
      values
      (convert_tz(current_timestamp,\'EST5EDT\',\'PST8PDT\'), \'239\', \'foo\', \'bar\', 1, \'1\', \'16.3574378490448\')
      on duplicate key update metric11 = metric11 + 1,
         metric12 = metric12 + values(metric12), secs = secs + values(secs)'
   },
   {  server_id => '21',
      arg       => 'COMMIT',
      ts        => '071207 12:02:53',
      xid       => '4584964',
      type      => 'Xid',
      end       => '498008284',
      offset    => '498008394'
   },
   {  time      => undef,
      arg       => 'SET TIMESTAMP=1197046973',
      ts        => '071207 12:02:53',
      end       => '314',
      server_id => '21',
      type      => 'Query',
      id        => undef,
      code      => undef,
      offset    => '498008421'
   },
   {  arg => '
update test2.tbl8
      set last2metric1 = last1metric1, last2time = last1time,
         last1metric1 = last0metric1, last1time = last0time,
         last0metric1 = ondeckmetric1, last0time = now()
      where tbl8 in (10800712)'
   },
   {  server_id => '21',
      arg       => 'COMMIT',
      ts        => '071207 12:02:53',
      xid       => '4584965',
      type      => 'Xid',
      end       => '498008625',
      offset    => '498008735'
   },
   {  server_id => '21',
      arg       => 'SET INSERT_ID=86547461',
      ts        => '071207 12:02:53',
      type      => 'Intvar',
      end       => '28',
      offset    => '498008762'
   }
];

@e = ();
open $file, "<", 'samples/binlog.txt' or die $OS_ERROR;
1 while ( $p->parse_binlog_event( $file, \&simple_callback ) );
close $file;

is_deeply( \@e, $events, "Got events from the binary log", );

# Test a callback chain.
my $callback1 = sub {
   my ( $event ) = @_;
   return 0 if $i >= 5;
   $event->{foo} = ++$i;
   return 1;
};
my $callback2 = sub {
   my ( $event ) = @_;
   push @e, $event;
   return 1;
};

@e = ();
open $file, "<", 'samples/slow001.txt' or die $OS_ERROR;
$i = 0;
1 while ( $p->parse_slowlog_event( $file, undef, $callback1, $callback2 ) );
close $file;
is($e[1]->{foo}, '2', "Callback chain works", );

open $file, "<", 'samples/slow002.txt' or die $OS_ERROR;
@e = ();
$i = 0;
1 while ( $p->parse_slowlog_event( $file, undef, $callback1, $callback2 ) );
close $file;
is(scalar @e, '5', "Callback chain early termination works", );

exit;
