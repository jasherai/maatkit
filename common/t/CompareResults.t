#!/usr/bin/perl

use strict;
use warnings FATAL => 'all';
use English qw(-no_match_vars);
use Test::More tests => 31;

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
require '../Outfile.pm';
require '../RowDiff.pm';
require '../CompareResults.pm';
require '../MaatkitTest.pm';
require '../Sandbox.pm';

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
my @events;
my $i;

# #############################################################################
# Test the checksum method.
# #############################################################################

diag(`/tmp/12345/use < samples/compare-results.sql`);

$cr = new CompareResults(
   method     => 'checksum',
   'base-dir' => '/dev/null',  # not used with checksum method
   plugins    => [$plugin],
   %modules,
);

isa_ok($cr, 'CompareResults');

@events = (
   {
      arg => 'select * from test.t',
   },
   {
      arg       => $events[0]->{arg},
      row_count => 3,
      checksum  => 251493421,
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

$events[0] = $cr->before_execute(
   event    => $events[0],
   dbh      => $dbh1,
   tmp_tbl  => 'test.dropme',
);

is(
   $events[0]->{arg},
   'CREATE TEMPORARY TABLE test.dropme AS select * from test.t',
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

$events[0] = $cr->execute(
   event => $events[0],
   dbh   => $dbh1,
);

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
   'CREATE TEMPORARY TABLE test.dropme AS select * from test.t',
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

$events[0] = $cr->after_execute(
   event => $events[0],
   dbh   => $dbh1,
);

is(
   $events[0]->{arg},
   'select * from test.t',
   'checksum: after_execute() unwrapped query'
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

is_deeply(
   $dbh1->selectall_arrayref('SHOW TABLES FROM test LIKE "dropme"'),
   [],
   'checksum: after_execute() drops temp table'
);

is_deeply(
   [ $cr->compare(
      events => \@events,
   ) ],
   [
      checksum_diffs  => 0,
      row_count_diffs => 0,
   ],
   'checksum: compare, no differences'
);

$events[1]->{row_count} = 1;

is_deeply(
   [ $cr->compare(
      events => \@events,
   ) ],
   [
      checksum_diffs  => 0,
      row_count_diffs => 1,
   ],
   'checksum: compare, different row counts'
);

$events[1]->{checksum} = 251493420;

is_deeply(
   [ $cr->compare(
      events => \@events,
   ) ],
   [
      checksum_diffs  => 1,
      row_count_diffs => 1,
   ],
   'checksum: compare, different checksums'
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
   %modules,
);

isa_ok($cr, 'CompareResults');

@events = (
   {
      arg => 'select * from test.t',
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

$events[0] = $cr->before_execute(
   event    => $events[0],
   dbh      => $dbh1,
   tmp_tbl  => 'test.dropme',
);

is(
   $events[0]->{arg},
   'select * from test.t',
   'rows: before_execute() does not wrap query'
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

$events[0] = $cr->execute(
   event => $events[0],
   dbh   => $dbh1,
);

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

# Table test.t should have already replicated to the slave.
$events[1] = {
   arg => $events[0]->{arg},
};
$events[1] = $cr->execute(
   event    => $events[1],
   dbh      => $dbh2,
);

is_deeply(
   [ $cr->compare(
      events => \@events,
      hosts  => [
         { dbh => $dbh1 },
         { dbh => $dbh2 },
      ],
   ) ],
   [
      row_data_diffs  => 0,
      row_count_diffs => 0,
   ],
   'rows: compare, no differences'
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
