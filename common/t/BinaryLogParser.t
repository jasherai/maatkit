#!/usr/bin/perl

use strict;
use warnings FATAL => 'all';
use English qw(-no_match_vars);
use Test::More tests => 2;

use Data::Dumper;
$Data::Dumper::Indent    = 1;
$Data::Dumper::Sortkeys  = 1;
$Data::Dumper::Quotekeys = 0;

require "../BinaryLogParser.pm";

my $p = new BinaryLogParser();

sub run_test {
   my ( $def ) = @_;
   map     { die "What is $_ for?" }
      grep { $_ !~ m/^(?:misc|file|result|num_events)$/ }
      keys %$def;
   my @e;
   my $num_events = 0;
   eval {
      open my $fh, "<", $def->{file} or die $OS_ERROR;
      $num_events++ while $p->parse_event($fh, $def->{misc}, sub { push @e, @_ });
      close $fh;
   };
   is($EVAL_ERROR, '', "No error on $def->{file}");
   if ( defined $def->{result} ) {
      is_deeply(\@e, $def->{result}, $def->{file})
         or print "Got: ", Dumper(\@e);
   }
   if ( defined $def->{num_events} ) {
      is($num_events, $def->{num_events}, "$def->{file} num_events");
   }
}


run_test({
   file => 'samples/binlog001.txt',
   result => [
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
   ]
});

# #############################################################################
# Done.
# #############################################################################
exit;
