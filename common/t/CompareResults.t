#!/usr/bin/perl

use strict;
use warnings FATAL => 'all';
use English qw(-no_match_vars);
use Test::More tests => 40;

require '../Quoter.pm';
require '../MySQLDump.pm';
require '../TableParser.pm';
require '../DSNParser.pm';
require '../QueryParser.pm';
require '../TableSyncer.pm';
require '../TableChecksum.pm';
require '../VersionParser.pm';
require '../TableSyncGroupBy.pm';
require '../MockSyncStream.pm';
require '../MockSth.pm';
require '../Outfile.pm';
require '../RowDiff.pm';
require '../ChangeHandler.pm';
require '../ReportFormatter.pm';
require '../Transformers.pm';
require '../MaatkitTest.pm';
require '../Sandbox.pm';
require '../CompareResults.pm';

use Data::Dumper;
$Data::Dumper::Indent    = 1;
$Data::Dumper::Sortkeys  = 1;
$Data::Dumper::Quotekeys = 0;

my $dp  = new DSNParser();
my $sb  = new Sandbox(basedir => '/tmp', DSNParser => $dp);
my $dbh1 = $sb->get_dbh_for('master')
   or BAIL_OUT('Cannot connect to sandbox master');
my $dbh2 = $sb->get_dbh_for('slave1')
   or BAIL_OUT('Cannot connect to sandbox slave1');

$sb->create_dbs($dbh1, ['test']);

Transformers->import(qw(make_checksum));

my $vp = new VersionParser();
my $q  = new Quoter();
my $qp = new QueryParser();
my $du = new MySQLDump(cache => 0);
my $tp = new TableParser(Quoter => $q);
my $tc = new TableChecksum(Quoter => $q, VersionParser => $vp);
my $of = new Outfile();
my $ts = new TableSyncer(
   Quoter        => $q,
   VersionParser => $vp,
   TableChecksum => $tc,
   MasterSlave   => 1,
);
my %modules = (
   VersionParser => $vp,
   Quoter        => $q,
   TableParser   => $tp,
   TableSyncer   => $ts,
   QueryParser   => $qp,
   MySQLDump     => $du,
   Outfile       => $of,
);

my $plugin = new TableSyncGroupBy(Quoter => $q);

my $cr;
my $i;
my $report;
my @events;
my $hosts = [
   { dbh => $dbh1, name => 'master' },
   { dbh => $dbh2, name => 'slave'  },
];

sub proc {
   my ( $when, %args ) = @_;
   die "I don't know when $when is"
      unless $when eq 'before_execute'
          || $when eq 'execute'
          || $when eq 'after_execute';
   for my $i ( 0..$#events ) {
      $events[$i] = $cr->$when(
         event    => $events[$i],
         dbh      => $hosts->[$i]->{dbh},
         %args,
      );
   }
};

sub get_id {
   return make_checksum(@_);
}

# #############################################################################
# Test the checksum method.
# #############################################################################

diag(`/tmp/12345/use < samples/compare-results.sql`);

$cr = new CompareResults(
   method     => 'checksum',
   'base-dir' => '/dev/null',  # not used with checksum method
   plugins    => [$plugin],
   get_id     => \&get_id,
   %modules,
);

isa_ok($cr, 'CompareResults');

@events = (
   {
      arg         => 'select * from test.t where i>0',
      fingerprint => 'select * from test.t where i>?',
      sampleno    => 1,
   },
   {
      arg         => 'select * from test.t where i>0',
      fingerprint => 'select * from test.t where i>?',
      sampleno    => 1,
   },
);

$i = 0;
MaatkitTest::wait_until(
   sub {
      my $r;
      eval {
         $r = $dbh1->selectrow_arrayref('SHOW TABLES FROM test LIKE "dropme"');
      };
      return 1 if ($r->[0] || '') eq 'dropme';
      diag('Waiting for CREATE TABLE...') unless $i++;
      return 0;
   },
   0.5,
   30,
);

is_deeply(
   $dbh1->selectrow_arrayref('SHOW TABLES FROM test LIKE "dropme"'),
   ['dropme'],
   'checksum: temp table exists'
);

proc('before_execute', db=>'test', 'temp-table'=>'dropme');

is(
   $events[0]->{arg},
   'CREATE TEMPORARY TABLE `test`.`dropme` AS select * from test.t where i>0',
   'checksum: before_execute() wraps query in CREATE TEMPORARY TABLE'
);

is_deeply(
   $dbh1->selectall_arrayref('SHOW TABLES FROM test LIKE "dropme"'),
   [],
   'checksum: before_execute() drops temp table'
);

ok(
   !exists $events[0]->{Query_time},
   "checksum: Query_time doesn't exist before execute()"
);

proc('execute');

ok(
   exists $events[0]->{Query_time},
   "checksum: Query_time exists after exectue()"
);

like(
   $events[0]->{Query_time},
   qr/^[\d.]+$/,
   "checksum: Query_time is a number ($events[0]->{Query_time})"
);

is(
   $events[0]->{arg},
   'CREATE TEMPORARY TABLE `test`.`dropme` AS select * from test.t where i>0',
   "checksum: execute() doesn't unwrap query"
);

is_deeply(
   $dbh1->selectall_arrayref('select * from test.dropme'),
   [[1],[2],[3]],
   'checksum: Result set selected into the temp table'
);

ok(
   !exists $events[0]->{row_count},
   "checksum: row_count doesn't exist before after_execute()"
);

ok(
   !exists $events[0]->{checksum},
   "checksum: checksum doesn't exist before after_execute()"
);

proc('after_execute');

is(
   $events[0]->{arg},
   'select * from test.t where i>0',
   'checksum: after_execute() unwrapped query'
);

is_deeply(
   $dbh1->selectall_arrayref('SHOW TABLES FROM test LIKE "dropme"'),
   [],
   'checksum: after_execute() drops temp table'
);

is_deeply(
   [ $cr->compare(
      events => \@events,
      hosts  => $hosts,
   ) ],
   [
      different_row_counts    => 0,
      different_checksums     => 0,
      different_column_counts => 0,
      different_column_types  => 0,
   ],
   'checksum: compare, no differences'
);

is(
   $events[0]->{row_count},
   3,
   "checksum: correct row_count after after_execute()"
);

is(
   $events[0]->{checksum},
   '251493421',
   "checksum: correct checksum after after_execute()"
);

# Make checksums differ.
$dbh2->do('update test.t set i = 99 where i=1');

proc('before_execute', db=>'test', 'temp-table'=>'dropme');
proc('execute');
proc('after_execute');

is_deeply(
   [ $cr->compare(
      events => \@events,
      hosts  => $hosts,
   ) ],
   [
      different_row_counts    => 0,
      different_checksums     => 1,
      different_column_counts => 0,
      different_column_types  => 0,
   ],
   'checksum: compare, different checksums' 
);

# Make row counts differ, too.
$dbh2->do('insert into test.t values (4)');

proc('before_execute', db=>'test', 'temp-table'=>'dropme');
proc('execute');
proc('after_execute');

is_deeply(
   [ $cr->compare(
      events => \@events,
      hosts  => $hosts,
   ) ],
   [
      different_row_counts    => 1,
      different_checksums     => 1,
      different_column_counts => 0,
      different_column_types  => 0,
   ],
   'checksum: compare, different checksums and row counts'
);

$report = <<EOF;
# Checksum differences
# Query ID           master    slave     
# ================== ========= ==========
# D2D386B840D3BEEA-1 $events[0]->{checksum} $events[1]->{checksum}
EOF

is(
   $cr->report(hosts => $hosts),
   $report,
   'checksum: report'
);

my %samples = $cr->samples($events[0]->{fingerprint});
is_deeply(
   \%samples,
   {
      1 => 'select * from test.t where i>0',
   },
   'checksum: samples'
);

# #############################################################################
# Test the rows method.
# #############################################################################

my $tmpdir = '/tmp/mk-upgrade-res';

diag(`/tmp/12345/use < samples/compare-results.sql`);
diag(`rm -rf $tmpdir; mkdir $tmpdir`);

$cr = new CompareResults(
   method     => 'rows',
   'base-dir' => $tmpdir,
   plugins    => [$plugin],
   get_id     => \&get_id,
   %modules,
);

isa_ok($cr, 'CompareResults');

@events = (
   {
      arg => 'select * from test.t',
      db  => 'test',
   },
   {
      arg => 'select * from test.t',
      db  => 'test',
   },
);

$i = 0;
MaatkitTest::wait_until(
   sub {
      my $r;
      eval {
         $r = $dbh1->selectrow_arrayref('SHOW TABLES FROM test LIKE "dropme"');
      };
      return 1 if ($r->[0] || '') eq 'dropme';
      diag('Waiting for CREATE TABLE...') unless $i++;
      return 0;
   },
   0.5,
   30,
);

is_deeply(
   $dbh1->selectrow_arrayref('SHOW TABLES FROM test LIKE "dropme"'),
   ['dropme'],
   'rows: temp table exists'
);

proc('before_execute');

is(
   $events[0]->{arg},
   'select * from test.t',
   "rows: before_execute() doesn't wrap query and doesn't require tmp table"
);

is_deeply(
   $dbh1->selectrow_arrayref('SHOW TABLES FROM test LIKE "dropme"'),
   ['dropme'],
   "rows: before_execute() doesn't drop temp table"
);

ok(
   !exists $events[0]->{Query_time},
   "rows: Query_time doesn't exist before execute()"
);

ok(
   !exists $events[0]->{results_sth},
   "rows: results_sth doesn't exist before execute()"
);

proc('execute');

ok(
   exists $events[0]->{Query_time},
   "rows: query_time exists after exectue()"
);

ok(
   exists $events[0]->{results_sth},
   "rows: results_sth exists after exectue()"
);

like(
   $events[0]->{Query_time},
   qr/^[\d.]+$/,
   "rows: Query_time is a number ($events[0]->{Query_time})"
);

ok(
   !exists $events[0]->{row_count},
   "rows: row_count doesn't exist before after_execute()"
);

is_deeply(
   $cr->after_execute(event=>$events[0]),
   $events[0],
   "rows: after_execute() doesn't modify the event"
);

is_deeply(
   [ $cr->compare(
      events => \@events,
      hosts  => $hosts,
   ) ],
   [
      different_row_counts    => 0,
      different_column_values => 0,
      different_column_counts => 0,
      different_column_types  => 0,
   ],
   'rows: compare, no differences'
);

is(
   $events[0]->{row_count},
   3,
   "rows: compare() sets row_count"
);

is(
   $events[1]->{row_count},
   3,
   "rows: compare() sets row_count"
);

# Make the result set differ.
$dbh2->do('insert into test.t values (5)');

proc('before_execute');
proc('execute');

is_deeply(
   [ $cr->compare(
      events => \@events,
      hosts  => $hosts,
   ) ],
   [
      different_row_counts    => 1,
      different_column_values => 0,
      different_column_counts => 0,
      different_column_types  => 0,
   ],
   'rows: compare, different row counts'
);

# Use test.t2 and make a column value differ.
@events = (
   {
      arg         => 'select * from test.t2',
      db          => 'test',
      fingerprint => 'select * from test.t2',
      sampleno    => 3,
   },
   {
      arg         => 'select * from test.t2',
      db          => 'test',
      fingerprint => 'select * from test.t2',
      sampleno    => 3,
   },
);

$dbh2->do('update test.t2 set c="should be c" where i=3');

is_deeply(
   $dbh2->selectrow_arrayref('select c from test.t2 where i=3'),
   ['should be c'],
   'rows: column value is different'
);

proc('before_execute');
proc('execute');

is_deeply(
   [ $cr->compare(
      events => \@events,
      hosts  => $hosts,
   ) ],
   [
      different_row_counts    => 0,
      different_column_values => 1,
      different_column_counts => 0,
      different_column_types  => 0,
   ],
   'rows: compare, different column values'
);

$report = <<EOF;
# Column value differences
# Query ID           Column master slave      
# ================== ====== ====== ===========
# CFC309761E9131C5-3 c      c      should be c
EOF

is(
   $cr->report(hosts => $hosts),
   $report,
   'rows: report'
);

%samples = $cr->samples($events[0]->{fingerprint});
is_deeply(
   \%samples,
   {
      3 => 'select * from test.t2'
   },
   'rows: samples'
);

# #############################################################################
# Done.
# #############################################################################
my $output = '';
{
   local *STDERR;
   open STDERR, '>', \$output;
   $cr->_d('Complete test coverage');
}
like(
   $output,
   qr/Complete test coverage/,
   '_d() works'
);
$sb->wipe_clean($dbh1);
exit;
