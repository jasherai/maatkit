#!/usr/bin/perl

use strict;
use warnings FATAL => 'all';
use English qw(-no_match_vars);
use Test::More tests => 10;

require '../QueryExecutor.pm';
require '../DSNParser.pm';
require '../Sandbox.pm';

my $dp  = new DSNParser();
my $sb  = new Sandbox(basedir => '/tmp', DSNParser => $dp);
my $dbh1 = $sb->get_dbh_for('master')
   or BAIL_OUT('Cannot connect to sandbox master');
my $dbh2 = $sb->get_dbh_for('slave1')
   or BAIL_OUT('Cannot connect to sandbox slave1');

$sb->create_dbs($dbh1, [qw(test)]);
# Reusing this sample because it's short and simple.
$sb->load_file('master', 'samples/issue_47.sql');

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
