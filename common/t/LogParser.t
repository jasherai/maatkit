#!/usr/bin/perl

use strict;
use warnings FATAL => 'all';

use Test::More tests => 7;
use English qw(-no_match_vars);

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
      arg  => "INSERT IGNORE INTO articles (id, body,)VALUES(3558268,'sample text')",
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

# Parse binlog output.
$events = [
   { arg => '/*!40019 SET @@session.max_insert_delayed_threads=0*/' },
   { arg => '/*!50003 SET @OLD_COMPLETION_TYPE=@@COMPLETION_TYPE,COMPLETION_TYPE=0*/' },
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

open $file, "<", 'samples/binlog.txt' or die $OS_ERROR;
@e = ();
1 while ( $p->parse_binlog_event( $file, \&simple_callback ) );
close $file;

is_deeply( \@e, $events, "Got events from the binary log", );

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
      NR             => 8,
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
      Host           => '[SQL_SLAVE]',
      Rows_sent      => '0',
      Lock_time      => '0.000091',
      NR             => 19,
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
      Host                  => '[SQL_SLAVE]',
      NR                    => 30,
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
      Host                  => '[SQL_SLAVE]',
      NR                    => 41,
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
      Host                  => '[SQL_SLAVE]',
      NR                    => 52,
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
      Host                  => '[SQL_SLAVE]',
      NR                    => 62,
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
      Host                  => '[SQL_SLAVE]',
      NR                    => 74,
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
      Host                  => '[SQL_SLAVE]',
      NR                    => 83,
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
is($EVAL_ERROR, '', 'Blank entry did not crash');

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
   },
];

open $file, "<", 'samples/slow005.txt' or die $OS_ERROR;
@e = ();
1 while ( $p->parse_event( $file, \&simple_callback ) );
close $file;

is_deeply( \@e, $events, "microslow log with tabs", );

