#!/usr/bin/env perl

BEGIN {
   die "The MAATKIT_WORKING_COPY environment variable is not set.  See http://code.google.com/p/maatkit/wiki/Testing"
      unless $ENV{MAATKIT_WORKING_COPY} && -d $ENV{MAATKIT_WORKING_COPY};
   unshift @INC, "$ENV{MAATKIT_WORKING_COPY}/common";
};

use strict;
use warnings FATAL => 'all';
use English qw(-no_match_vars);
use Test::More;

use MaatkitTest;
use Sandbox;
use DSNParser;

my $dp = new DSNParser(opts=>$dsn_opts);
my $sb = new Sandbox(basedir => '/tmp', DSNParser => $dp);
my $dbh = $sb->get_dbh_for('master');

if ( !$dbh ) {
   plan skip_all => 'Cannot connect to sandbox master';
}
else {
   plan tests => 15;
}

my $run_with = "$trunk/mk-query-digest/mk-query-digest --report-format=query_report --limit 10 $trunk/common/t/samples/";
my $output;
my $cmd;

$sb->create_dbs($dbh, ['test']);
$sb->load_file('master', 'mk-query-digest/t/samples/query_review.sql');

# Test --create-review and --create-review-history-table
$output = 'foo'; # clear previous test results
$cmd = "${run_with}slow006.txt --create-review-table --review "
   . "h=127.1,P=12345,u=msandbox,p=msandbox,D=test,t=query_review --create-review-history-table "
   . "--review-history t=query_review_history";
$output = `$cmd >/dev/null 2>&1`;

my ($table) = $dbh->selectrow_array(
   'show tables from test like "query_review"');
is($table, 'query_review', '--create-review');
($table) = $dbh->selectrow_array(
   'show tables from test like "query_review_history"');
is($table, 'query_review_history', '--create-review-history-table');

$output = 'foo'; # clear previous test results
$cmd = "${run_with}slow006.txt --review h=127.1,u=msandbox,p=msandbox,P=12345,D=test,t=query_review "
   . "--review-history t=query_review_history";
$output = `$cmd`;
my $res = $dbh->selectall_arrayref( 'SELECT * FROM test.query_review',
   { Slice => {} } );
is_deeply(
   $res,
   [  {  checksum    => '11676753765851784517',
         reviewed_by => undef,
         reviewed_on => undef,
         last_seen   => '2007-12-18 11:49:30',
         first_seen  => '2007-12-18 11:48:27',
         sample      => 'SELECT col FROM foo_tbl',
         fingerprint => 'select col from foo_tbl',
         comments    => undef,
      },
      {  checksum    => '15334040482108055940',
         reviewed_by => undef,
         reviewed_on => undef,
         last_seen   => '2007-12-18 11:49:07',
         first_seen  => '2007-12-18 11:48:57',
         sample      => 'SELECT col FROM bar_tbl',
         fingerprint => 'select col from bar_tbl',
         comments    => undef,
      },
   ],
   'Adds/updates queries to query review table'
);
$res = $dbh->selectall_arrayref( 'SELECT * FROM test.query_review_history',
   { Slice => {} } );
is_deeply(
   $res,
   [  {  Lock_time_median     => '0',
         Lock_time_stddev     => '0',
         Query_time_sum       => '3.6e-05',
         checksum             => '11676753765851784517',
         Rows_examined_stddev => '0',
         ts_cnt               => '3',
         sample               => 'SELECT col FROM foo_tbl',
         Rows_examined_median => '0',
         Rows_sent_min        => '0',
         Rows_examined_min    => '0',
         Rows_sent_sum        => '0',
         Query_time_min       => '1.2e-05',
         Query_time_pct_95    => '1.2e-05',
         Rows_examined_sum    => '0',
         Rows_sent_stddev     => '0',
         Rows_sent_pct_95     => '0',
         Query_time_max       => '1.2e-05',
         Rows_examined_max    => '0',
         Query_time_stddev    => '0',
         Rows_sent_median     => '0',
         Lock_time_pct_95     => '0',
         ts_min               => '2007-12-18 11:48:27',
         Lock_time_min        => '0',
         Lock_time_max        => '0',
         ts_max               => '2007-12-18 11:49:30',
         Rows_examined_pct_95 => '0',
         Rows_sent_max        => '0',
         Query_time_median    => '1.2e-05',
         Lock_time_sum        => '0'
      },
      {  Lock_time_median     => '0',
         Lock_time_stddev     => '0',
         Query_time_sum       => '3.6e-05',
         checksum             => '15334040482108055940',
         Rows_examined_stddev => '0',
         ts_cnt               => '3',
         sample               => 'SELECT col FROM bar_tbl',
         Rows_examined_median => '0',
         Rows_sent_min        => '0',
         Rows_examined_min    => '0',
         Rows_sent_sum        => '0',
         Query_time_min       => '1.2e-05',
         Query_time_pct_95    => '1.2e-05',
         Rows_examined_sum    => '0',
         Rows_sent_stddev     => '0',
         Rows_sent_pct_95     => '0',
         Query_time_max       => '1.2e-05',
         Rows_examined_max    => '0',
         Query_time_stddev    => '0',
         Rows_sent_median     => '0',
         Lock_time_pct_95     => '0',
         ts_min               => '2007-12-18 11:48:57',
         Lock_time_min        => '0',
         Lock_time_max        => '0',
         ts_max               => '2007-12-18 11:49:07',
         Rows_examined_pct_95 => '0',
         Rows_sent_max        => '0',
         Query_time_median    => '1.2e-05',
         Lock_time_sum        => '0'
      }
   ],
   'Adds/updates queries to query review history table'
);

# This time we'll run with --report and since none of the queries
# have been reviewed, the report should include both of them with
# their respective query review info added to the report.
ok(
   no_diff($run_with.'slow006.txt --review h=127.1,P=12345,u=msandbox,p=msandbox,D=test,t=query_review', "mk-query-digest/t/samples/slow006_AR_1.txt"),
   'Analyze-review pass 1 reports not-reviewed queries'
);

# Mark a query as reviewed and run --report again and that query should
# not be reported.
$dbh->do('UPDATE test.query_review
   SET reviewed_by="daniel", reviewed_on="2008-12-24 12:00:00", comments="foo_tbl is ok, so are cranberries"
   WHERE checksum=11676753765851784517');
ok(
   no_diff($run_with.'slow006.txt --review h=127.1,P=12345,u=msandbox,p=msandbox,D=test,t=query_review', "mk-query-digest/t/samples/slow006_AR_2.txt"),
   'Analyze-review pass 2 does not report the reviewed query'
);

# And a 4th pass with --report-all which should cause the reviewed query
# to re-appear in the report with the reviewed_by, reviewed_on and comments
# info included.
ok(
   no_diff($run_with.'slow006.txt --review h=127.1,P=12345,u=msandbox,p=msandbox,D=test,t=query_review   --report-all', "mk-query-digest/t/samples/slow006_AR_4.txt"),
   'Analyze-review pass 4 with --report-all reports reviewed query'
);

# Test that reported review info gets all meta-columns dynamically.
$dbh->do('ALTER TABLE test.query_review ADD COLUMN foo INT');
$dbh->do('UPDATE test.query_review
   SET foo=42 WHERE checksum=15334040482108055940');
ok(
   no_diff($run_with.'slow006.txt --review h=127.1,P=12345,u=msandbox,p=msandbox,D=test,t=query_review', "mk-query-digest/t/samples/slow006_AR_5.txt"),
   'Analyze-review pass 5 reports new review info column'
);

# Make sure that when we run with all-0 timestamps they don't show up in the
# output because they are useless of course (issue 202).
$dbh->do("update test.query_review set first_seen='0000-00-00 00:00:00', "
   . " last_seen='0000-00-00 00:00:00'");
$output = 'foo'; # clear previous test results
$cmd = "${run_with}slow022.txt --review h=127.1,P=12345,u=msandbox,p=msandbox,D=test,t=query_review"; 
$output = `$cmd`;
unlike($output, qr/last_seen/, 'no last_seen when 0000 timestamp');
unlike($output, qr/first_seen/, 'no first_seen when 0000 timestamp');
unlike($output, qr/0000-00-00 00:00:00/, 'no 0000-00-00 00:00:00 timestamp');

# ##########################################################################
# XXX The following tests will cause non-deterministic data, so run them
# after anything that wants to check the contents of the --review table.
# ##########################################################################

# Make sure a missing Time property does not cause a crash.  Don't test data
# in table, because it varies based on when you run the test.
$output = 'foo'; # clear previous test results
$cmd = "${run_with}slow021.txt --review h=127.1,P=12345,u=msandbox,p=msandbox,D=test,t=query_review"; 
$output = `$cmd`;
unlike($output, qr/Use of uninitialized value/, 'didnt crash due to undef ts');

# Make sure a really ugly Time property that doesn't parse does not cause a
# crash.  Don't test data in table, because it varies based on when you run
# the test.
$output = 'foo'; # clear previous test results
$cmd = "${run_with}slow022.txt --review h=127.1,P=12345,u=msandbox,p=msandbox,D=test,t=query_review"; 
$output = `$cmd`;
# Don't test data in table, because it varies based on when you run the test.
unlike($output, qr/Use of uninitialized value/, 'no crash due to totally missing ts');

# #############################################################################
# --review --no-report
# #############################################################################
$sb->load_file('master', 'mk-query-digest/t/samples/query_review.sql');
$output = `${run_with}slow006.txt --review h=127.1,P=12345,u=msandbox,p=msandbox,D=test,t=query_review --no-report --create-review-table`;
$res = $dbh->selectall_arrayref('SELECT * FROM test.query_review');
is(
   $res->[0]->[1],
   'select col from foo_tbl',
   "--review works with --no-report"
);
is(
   $output,
   '',
   'No output with --review and --no-report'
);

# #############################################################################
# Done.
# #############################################################################
$sb->wipe_clean($dbh);
exit;
