#!/usr/bin/perl

use strict;
use warnings FATAL => 'all';

use Test::More tests => 4;
use English qw(-no_match_vars);

require "../LogParser.pm";

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

# Parse binlog output.
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
];

$events = [
  {
    arg => '/*!40019 SET @@session.max_insert_delayed_threads=0*/'
  },
  {
    arg => '/*!50003 SET @OLD_COMPLETION_TYPE=@@COMPLETION_TYPE,COMPLETION_TYPE=0*/'
  },
  {
    time => undef,
    arg => 'SET TIMESTAMP=1197046970/*!*/',
    ts => '071207 12:02:50',
    end => '498006652',
    server_id => '21',
    type => 'Query',
    id => undef,
    code => undef,
    offset => '498006722'
  },
  {
    arg => 'SET @@session.foreign_key_checks=1, @@session.sql_auto_is_null=1, @@session.unique_checks=1'
  },
  {
    arg => '
SET @@session.sql_mode=0'
  },
  {
    arg => '
/*!\\C latin1 */'
  },
  {
    arg => '
SET @@session.character_set_client=8,@@session.collation_connection=8,@@session.collation_server=8'
  },
  {
    arg => '
SET @@session.time_zone=\'SYSTEM\''
  },
  {
    arg => '
BEGIN'
  },
  {
    time => undef,
    arg => 'use test1',
    ts => '071207 12:02:07',
    end => '278',
    server_id => '21',
    type => 'Query',
    id => undef,
    code => undef,
    offset => '498006789'
  },
  {
    arg => '
SET TIMESTAMP=1197046927'
  },
  {
    arg => '
update test3.tblo as o
         inner join test3.tbl2 as e on o.animal = e.animal and o.oid = e.oid
      set e.tblo = o.tblo,
          e.col3 = o.col3
      where e.tblo is null'
  },
  {
    time => undef,
    arg => 'SET TIMESTAMP=1197046928',
    ts => '071207 12:02:08',
    end => '836',
    server_id => '21',
    type => 'Query',
    id => undef,
    code => undef,
    offset => '498007067'
  },
  {
    arg => '
replace into test4.tbl9(tbl5, day, todo, comment)
 select distinct o.tbl5, date(o.col3), \'misc\', right(\'foo\', 50)
      from test3.tblo as o
         inner join test3.tbl2 as e on o.animal = e.animal and o.oid = e.oid
      where e.tblo is not null
         and o.col1 > 0
         and o.tbl2 is null
         and o.col3 >= date_sub(current_date, interval 30 day)'
  },
  {
    time => undef,
    arg => 'SET TIMESTAMP=1197046970',
    ts => '071207 12:02:50',
    end => '1161',
    server_id => '21',
    type => 'Query',
    id => undef,
    code => undef,
    offset => '498007625'
  },
  {
    arg => '
update test3.tblo as o inner join test3.tbl2 as e
 on o.animal = e.animal and o.oid = e.oid
      set o.tbl2 = e.tbl2,
          e.col9 = now()
      where o.tbl2 is null'
  },
  {
    server_id => '21',
    arg => 'COMMIT',
    ts => '071207 12:02:50',
    xid => '4584956',
    type => 'Xid',
    end => '498007840',
    offset => '498007950'
  },
  {
    time => undef,
    arg => 'SET TIMESTAMP=1197046973',
    ts => '071207 12:02:53',
    end => '417',
    server_id => '21',
    type => 'Query',
    id => undef,
    code => undef,
    offset => '498007977'
  },
  {
    arg => '
insert into test1.tbl6
      (day, tbl5, misccol9type, misccol9, metric11, metric12, secs)
      values
      (convert_tz(current_timestamp,\'EST5EDT\',\'PST8PDT\'), \'239\', \'foo\', \'bar\', 1, \'1\', \'16.3574378490448\')
      on duplicate key update metric11 = metric11 + 1,
         metric12 = metric12 + values(metric12), secs = secs + values(secs)'
  },
  {
    server_id => '21',
    arg => 'COMMIT',
    ts => '071207 12:02:53',
    xid => '4584964',
    type => 'Xid',
    end => '498008284',
    offset => '498008394'
  },
  {
    time => undef,
    arg => 'SET TIMESTAMP=1197046973',
    ts => '071207 12:02:53',
    end => '314',
    server_id => '21',
    type => 'Query',
    id => undef,
    code => undef,
    offset => '498008421'
  },
  {
    arg => '
update test2.tbl8
      set last2metric1 = last1metric1, last2time = last1time,
         last1metric1 = last0metric1, last1time = last0time,
         last0metric1 = ondeckmetric1, last0time = now()
      where tbl8 in (10800712)'
  },
  {
    server_id => '21',
    arg => 'COMMIT',
    ts => '071207 12:02:53',
    xid => '4584965',
    type => 'Xid',
    end => '498008625',
    offset => '498008735'
  },
  {
    server_id => '21',
    arg => 'SET INSERT_ID=86547461',
    ts => '071207 12:02:53',
    type => 'Intvar',
    end => '28',
    offset => '498008762'
  }
];

open $file, "<", 'samples/binlog.txt' or die $OS_ERROR;
@e = ();
1 while ( $p->parse_binlog_event($file, \&simple_callback) );
close $file;

is_deeply(
   \@e,
   $events,
   "Got events from the binary log",
);
