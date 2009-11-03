#!/usr/bin/perl

use strict;
use warnings FATAL => 'all';
use English qw(-no_match_vars);
use Test::More tests => 16;

require '../CompareResults.pm';
require '../Quoter.pm';
require '../MySQLDump.pm';
require '../TableParser.pm';
require '../DSNParser.pm';
require '../QueryParser.pm';
require '../TableSyncer.pm';
require '../TableChecksum.pm';
require '../VersionParser.pm';
require '../TableSyncGroupBy.pm';
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
);

my $plugin = new TableSyncGroupBy(Quoter => $q);

my $cr;
my $event;
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

$event = {
   arg => 'select * from test.t',
};

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
   'Temp table exists'
);

$event = $cr->before_execute(
   event    => $event,
   dbh      => $dbh1,
   tmp_tbl  => 'test.dropme',
);

is(
   $event->{arg},
   'CREATE TEMPORARY TABLE test.dropme AS select * from test.t',
   'before_execute() wraps query in CREATE TEMPORARY TABLE'
);

is_deeply(
   $dbh1->selectall_arrayref('SHOW TABLES FROM test LIKE "dropme"'),
   [],
   'before_execute() drops temp table'
);

ok(
   !exists $event->{Query_time},
   "Query_time doesn't exist before execute()"
);

$event = $cr->execute(
   event => $event,
   dbh   => $dbh1,
);

ok(
   exists $event->{Query_time},
   "Query_time exists after exectue()"
);

like(
   $event->{Query_time},
   qr/^[\d.]+$/,
   "Query_time is a number ($event->{Query_time})"
);

is(
   $event->{arg},
   'CREATE TEMPORARY TABLE test.dropme AS select * from test.t',
   "execute() doesn't unwrap query"
);

is_deeply(
   $dbh1->selectall_arrayref('select * from test.dropme'),
   [[1],[2],[3]],
   'Result set selected into the temp table'
);

ok(
   !exists $event->{row_count},
   "row_count doesn't exist before after_execute()"
);

ok(
   !exists $event->{checksum},
   "checksum doesn't exist before after_execute()"
);

$event = $cr->after_execute(
   event => $event,
   dbh   => $dbh1,
);

is(
   $event->{arg},
   'select * from test.t',
   'after_execute() unwrapped query'
);

is(
   $event->{row_count},
   3,
   "Correct row_count after after_execute()"
);

is(
   $event->{checksum},
   '251493421',
   "Correct checksum after after_execute()"
);

is_deeply(
   $dbh1->selectall_arrayref('SHOW TABLES FROM test LIKE "dropme"'),
   [],
   'after_execute() drops temp table'
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
