#!/usr/bin/perl

use strict;
use warnings FATAL => 'all';
use English qw(-no_match_vars);
use Test::More tests => 25;

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

my $hosts = [ { dbh=>$dbh1 }, { dbh=>$dbh2 } ];
my @pre;
my @post;
my @results;
my $output;

# #############################################################################
# Test basic functionality and results.
# #############################################################################
@post = (
   sub { $qe->get_warnings(@_);   },
);
@results = $qe->exec(
   query => 'SELECT * FROM test.issue_47',
   hosts => $hosts,
   pre_exec_callbacks  => \@pre,
   post_exec_callbacks => \@post,
);

like(
   $results[0]->{Query_time}->{Query_time},
   qr/[\d\.]+/,
   "host1 Query_time ($results[0]->{Query_time}->{Query_time})",
);
like(
   $results[1]->{Query_time}->{Query_time},
   qr/[\d\.]+/,
   "host2 Query_time ($results[1]->{Query_time}->{Query_time})",
);
is_deeply(
   $results[0]->{warnings}->{codes},
   {},
   'No warnings on host1'
);
is_deeply(
   $results[1]->{warnings}->{codes},
   {},
   'No warnings on host2'
);
is(
   $results[0]->{warnings}->{count},
   0,
   'Zero warning count on host1'
);
is(
   $results[1]->{warnings}->{count},
   0,
   'Zero warning count on host2'
);

# #############################################################################
# Test warnings.
# #############################################################################
@results = $qe->exec(
   query => 'INSERT INTO test.issue_47 VALUES (-1)',
   hosts => $hosts,
   pre_exec_callbacks  => \@pre,
   post_exec_callbacks => \@post,
);
like(
   $results[0]->{warnings}->{codes}->{1264}->{Message},
   qr/Out of range value/,
   'Warning text from SHOW WARNINGS'
);
is(
   $results[0]->{warnings}->{count},
   1,
   'Warning count'
);

# #############################################################################
# Test pre and post-exec queries.
# #############################################################################
$dbh1->do('SET @a = "foo"');
push @pre, sub {
   my ( %args ) = @_;
   $args{dbh}->do('SET @a = "before"');
   return 'name', {error=>undef};
};
@post = ();
@results = $qe->exec(
   query => 'SELECT * FROM test.issue_47',
   hosts  => $hosts,
   pre_exec_callbacks  => \@pre,
   post_exec_callbacks => \@post,
);
my $var = $dbh1->selectall_arrayref('SELECT @a');
is_deeply(
   $var,
   [['before']],
   'pre-exec callbacks'
);

$dbh1->do('SET @a = "foo"');
@pre = ();
push @post, sub {
   my ( %args ) = @_;
   $args{dbh}->do('SET @a = "after"');
   return 'name', {error=>undef};
};
@results = $qe->exec(
   query => 'SELECT * FROM test.issue_47',
   hosts  => $hosts,
   pre_exec_callbacks  => \@pre,
   post_exec_callbacks => \@post,
);
$var = $dbh1->selectall_arrayref('SELECT @a');
is_deeply(
   $var,
   [['after']],
   'post-exec callbacks'
);

$dbh1->do('SET @a = 0');
@pre = (sub {
   my ( %args ) = @_;
   $args{dbh}->do('SET @a = 1');
   return 'name', {error=>undef};
});
@post = (sub {
   my ( %args ) = @_;
   $args{dbh}->do('SET @a = @a + 1');
   return 'name', {error=>undef};
});

@results = $qe->exec(
   query => 'SELECT * FROM test.issue_47',
   hosts  => $hosts,
   pre_exec_callbacks  => \@pre,
   post_exec_callbacks => \@post,
);
$var = $dbh1->selectall_arrayref('SELECT @a');
is_deeply(
   $var,
   [['2']],
   'pre- and post-exec callbacks'
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

my $tmp_table = 'QueryExecutor';

# The test that execs "INSERT INTO test.issue_47 VALUES (-1)" makes host2
# get an extra row because it's slave to host1 so it's effectively ran twice.
# Therefore, the checksums and the row counts shouldn't match.
@pre = (sub {
   return $qe->pre_checksum_results(@_, database=>'test', tmp_table=>$tmp_table, %modules);
});
@post = (sub {
   return $qe->checksum_results(@_, database=>'test', tmp_table=>$tmp_table, %modules);
});
@results = $qe->exec(
   query => "CREATE TEMPORARY TABLE test.$tmp_table AS SELECT * FROM test.issue_47",
   hosts => $hosts,
   pre_exec_callbacks  => \@pre,
   post_exec_callbacks => \@post,
);
is(
   $results[0]->{checksum_results}->{n_rows},
   10,
   'results n_rows on host1'
);
is(
   $results[1]->{checksum_results}->{n_rows},
   11,
   'results n_rows on host1'
);
ok(
    $results[0]->{checksum_results}->{checksum},  
   'Got table checksum'
);
cmp_ok(
   $results[0]->{checksum_results}->{checksum},
   'ne',
   $results[1]->{checksum_results}->{checksum},
   'results checksums host1 != host2'
);

# Make host1 and host2 identical again.
$dbh1->do('DELETE FROM test.issue_47 WHERE userid = 0');
@results = $qe->exec(
   query => "CREATE TEMPORARY TABLE test.$tmp_table AS SELECT * FROM test.issue_47",
   hosts => $hosts,
   pre_exec_callbacks  => \@pre,
   post_exec_callbacks => \@post,
);
ok(
    $results[0]->{checksum_results}->{checksum},  
   'Got table checksum'
);
is(
   $results[0]->{checksum_results}->{checksum},
   $results[1]->{checksum_results}->{checksum},
   'results checksums host1 == host2'
);

# #############################################################################
# Test that _check_results() enforces good operation results.
# #############################################################################
eval {
   QueryExecutor::_check_results(
      undef, { error => undef, }, 'host', [ {} ]
   );
};
ok(
   $EVAL_ERROR,
   'Dies if op result has no name'
);

eval {
   QueryExecutor::_check_results(
      'name', undef, 'host', [ {} ]
   );
};
ok(
   $EVAL_ERROR,
   'Dies if op result has no results'
);

eval {
   QueryExecutor::_check_results(
      'name', { }, 'host', [ {} ]
   );
};
ok(
   $EVAL_ERROR,
   'Dies if op result has no error'
);

eval {
   QueryExecutor::_check_results(
      'name', { error => '', }, 'host', [ {} ]
   );
};
ok(
   $EVAL_ERROR,
   'Dies if op result error is blank'
);

eval {
   QueryExecutor::_check_results(
      'name', { error=>'foo', errors=>'bar' }, 'host', [ {} ]
   );
};
ok(
   $EVAL_ERROR,
   'Dies if op result errors is not arrayref'
);

eval {
   QueryExecutor::_check_results(
      'name', { error=>'foo', errors=>['bar'] }, 'host', [ {} ]
   );
};
is(
   $EVAL_ERROR,
   '',
   'Does not die if op result is ok'
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
