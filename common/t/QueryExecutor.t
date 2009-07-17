#!/usr/bin/perl

use strict;
use warnings FATAL => 'all';
use English qw(-no_match_vars);
use Test::More tests => 17;

require '../QueryExecutor.pm';
require '../Quoter.pm';
require '../MySQLDump.pm';
require '../TableParser.pm';
require '../DSNParser.pm';
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

$sb->create_dbs($dbh1, [qw(test)]);
# Reusing this sample because it's short and simple.
$sb->load_file('master', 'samples/issue_47.sql');

$dbh1->do('USE test');
$dbh2->do('USE test');

my $qe = new QueryExecutor();
isa_ok($qe, 'QueryExecutor');

my $results;
my $output;

# #############################################################################
# Test basic functionality and results.
# #############################################################################
$results = $qe->exec(
   query     => 'SELECT * FROM test.issue_47',
   host1_dbh => $dbh1,
   host2_dbh => $dbh2,
);

like(
   $results->{host1}->{Query_time},
   qr/[\d\.]+/,
   "host1 Query_time ($results->{host1}->{Query_time})",
);
like(
   $results->{host2}->{Query_time},
   qr/[\d\.]+/,
   "host2 Query_time ($results->{host1}->{Query_time})",
);
is_deeply(
   $results->{host1}->{warnings},
   {},
   'No warnings on host1'
);
is_deeply(
   $results->{host2}->{warnings},
   {},
   'No warnings on host2'
);
is(
   $results->{host1}->{warning_count},
   0,
   'Zero warning count on host1'
);
is(
   $results->{host2}->{warning_count},
   0,
   'Zero warning count on host2'
);

# #############################################################################
# Test warnings.
# #############################################################################
$results = $qe->exec(
   query     => 'INSERT INTO test.issue_47 VALUES (-1)',
   host1_dbh => $dbh1,
   host2_dbh => $dbh2,
);
like(
   $results->{host1}->{warnings}->{1264}->{Message},
   qr/Out of range value/,
   'Warning text from SHOW WARNINGS'
);
is(
   $results->{host1}->{warning_count},
   1,
   'Warning count'
);

# #############################################################################
# Test pre and post-exec queries.
# #############################################################################
$dbh1->do('SET @a = "foo"');
$results = $qe->exec(
   pre_exec_query  => 'SET @a = "before"',
   query           => 'SELECT * FROM test.issue_47',
   host1_dbh => $dbh1,
   host2_dbh => $dbh2,
);
my $var = $dbh1->selectall_arrayref('SELECT @a');
is_deeply(
   $var,
   [['before']],
   'pre-exec query'
);

$dbh1->do('SET @a = "foo"');
$results = $qe->exec(
   query           => 'SELECT * FROM test.issue_47',
   post_exec_query => 'SET @a = "after"',
   host1_dbh => $dbh1,
   host2_dbh => $dbh2,
);
$var = $dbh1->selectall_arrayref('SELECT @a');
is_deeply(
   $var,
   [['after']],
   'pre-exec query'
);

$dbh1->do('SET @a = 0');
$results = $qe->exec(
   pre_exec_query  => 'SET @a = 1',
   query           => 'SELECT * FROM test.issue_47',
   post_exec_query => 'SET @a = @a + 1',
   host1_dbh => $dbh1,
   host2_dbh => $dbh2,
);
$var = $dbh1->selectall_arrayref('SELECT @a');
is_deeply(
   $var,
   [['2']],
   'pre and post-exec query'
);

# #############################################################################
# Test checksum_results.
# #############################################################################

my $du = new MySQLDump();
my $tp = new TableParser();
my $q  = new Quoter();
my %modules = (
   MySQLDump   => $du,
   TableParser => $tp,
   Quoter      => $q
);

# The test that execs "INSERT INTO test.issue_47 VALUES (-1)" makes host2
# get an extra row because it's slave to host1 so it's effectively ran twice.

$results = $qe->checksum_results(
   query     => 'SELECT * FROM test.issue_47',
   database  => 'test',
   host1_dbh => $dbh1,
   host2_dbh => $dbh2,
   %modules,
);
is(
   $results->{host1}->{n_rows},
   10,
   'compare results n_rows on host1'
);
is(
   $results->{host2}->{n_rows},
   11,
   'compare results n_rows on host1'
);
cmp_ok(
   $results->{host1}->{n_rows},
   '!=',
   $results->{host2}->{n_rows},
   'compare results host1 != host2 checksum'
);

# Make host1 and host2 identical again.
$dbh1->do('DELETE FROM test.issue_47 WHERE userid = 0');
$results = $qe->checksum_results(
   query     => 'SELECT * FROM test.issue_47',
   database  => 'test',
   host1_dbh => $dbh1,
   host2_dbh => $dbh2,
   %modules,
);
is(
   $results->{host1}->{n_rows},
   $results->{host2}->{n_rows},
   'compare results host1 == host2 checksum'
);

# #############################################################################
# Done.
# #############################################################################
$output = '';
{
   local *STDERR;
   open STDERR, '>', \$output;
   $qe->_d('Complete test coverage');
}
like(
   $output,
   qr/Complete test coverage/,
   '_d() works'
);
$sb->wipe_clean($dbh1);
exit;
