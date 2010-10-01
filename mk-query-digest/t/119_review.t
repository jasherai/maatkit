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
   plan tests => 16;
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
$res = $dbh->selectall_arrayref('SELECT lock_time_median, lock_time_stddev, query_time_sum, checksum, rows_examined_stddev, ts_cnt, sample, rows_examined_median, rows_sent_min, rows_examined_min, rows_sent_sum,  query_time_min, query_time_pct_95, rows_examined_sum, rows_sent_stddev, rows_sent_pct_95, query_time_max, rows_examined_max, query_time_stddev, rows_sent_median, lock_time_pct_95, ts_min, lock_time_min, lock_time_max, ts_max, rows_examined_pct_95 ,rows_sent_max, query_time_median, lock_time_sum FROM test.query_review_history',
   { Slice => {} } );
is_deeply(
   $res,
   [  {  lock_time_median     => '0',
         lock_time_stddev     => '0',
         query_time_sum       => '3.6e-05',
         checksum             => '11676753765851784517',
         rows_examined_stddev => '0',
         ts_cnt               => '3',
         sample               => 'SELECT col FROM foo_tbl',
         rows_examined_median => '0',
         rows_sent_min        => '0',
         rows_examined_min    => '0',
         rows_sent_sum        => '0',
         query_time_min       => '1.2e-05',
         query_time_pct_95    => '1.2e-05',
         rows_examined_sum    => '0',
         rows_sent_stddev     => '0',
         rows_sent_pct_95     => '0',
         query_time_max       => '1.2e-05',
         rows_examined_max    => '0',
         query_time_stddev    => '0',
         rows_sent_median     => '0',
         lock_time_pct_95     => '0',
         ts_min               => '2007-12-18 11:48:27',
         lock_time_min        => '0',
         lock_time_max        => '0',
         ts_max               => '2007-12-18 11:49:30',
         rows_examined_pct_95 => '0',
         rows_sent_max        => '0',
         query_time_median    => '1.2e-05',
         lock_time_sum        => '0'
      },
      {  lock_time_median     => '0',
         lock_time_stddev     => '0',
         query_time_sum       => '3.6e-05',
         checksum             => '15334040482108055940',
         rows_examined_stddev => '0',
         ts_cnt               => '3',
         sample               => 'SELECT col FROM bar_tbl',
         rows_examined_median => '0',
         rows_sent_min        => '0',
         rows_examined_min    => '0',
         rows_sent_sum        => '0',
         query_time_min       => '1.2e-05',
         query_time_pct_95    => '1.2e-05',
         rows_examined_sum    => '0',
         rows_sent_stddev     => '0',
         rows_sent_pct_95     => '0',
         query_time_max       => '1.2e-05',
         rows_examined_max    => '0',
         query_time_stddev    => '0',
         rows_sent_median     => '0',
         lock_time_pct_95     => '0',
         ts_min               => '2007-12-18 11:48:57',
         lock_time_min        => '0',
         lock_time_max        => '0',
         ts_max               => '2007-12-18 11:49:07',
         rows_examined_pct_95 => '0',
         rows_sent_max        => '0',
         query_time_median    => '1.2e-05',
         lock_time_sum        => '0'
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
# Issue 1149: Add Percona attributes to mk-query-digest review table
# #############################################################################
$dbh->do('truncate table test.query_review');
$dbh->do('truncate table test.query_review_history');

`${run_with}slow002.txt --review h=127.1,u=msandbox,p=msandbox,P=12345,D=test,t=query_review --review-history t=query_review_history --no-report --filter '\$event->{arg} =~ m/db2.tuningdetail_21_265507/' > /dev/null`;

$res = $dbh->selectall_arrayref( 'SELECT * FROM test.query_review_history',
   { Slice => {} } );

is_deeply(
   $res,
   [
      {
         sample => 'update db2.tuningdetail_21_265507 n
      inner join db1.gonzo a using(gonzo) 
      set n.column1 = a.column1, n.word3 = a.word3',
         checksum => '7386569538324658825',
         disk_filesort_cnt => '1',
         disk_filesort_sum => '0',
         disk_tmp_table_cnt => '1',
         disk_tmp_table_sum => '0',
         filesort_cnt => '1',
         filesort_sum => '0',
         full_join_cnt => '1',
         full_join_sum => '0',
         full_scan_cnt => '1',
         full_scan_sum => '1',
         innodb_io_r_bytes_max => undef,
         innodb_io_r_bytes_median => undef,
         innodb_io_r_bytes_min => undef,
         innodb_io_r_bytes_pct_95 => undef,
         innodb_io_r_bytes_stddev => undef,
         innodb_io_r_ops_max => undef,
         innodb_io_r_ops_median => undef,
         innodb_io_r_ops_min => undef,
         innodb_io_r_ops_pct_95 => undef,
         innodb_io_r_ops_stddev => undef,
         innodb_io_r_wait_max => undef,
         innodb_io_r_wait_median => undef,
         innodb_io_r_wait_min => undef,
         innodb_io_r_wait_pct_95 => undef,
         innodb_io_r_wait_stddev => undef,
         innodb_pages_distinct_max => undef,
         innodb_pages_distinct_median => undef,
         innodb_pages_distinct_min => undef,
         innodb_pages_distinct_pct_95 => undef,
         innodb_pages_distinct_stddev => undef,
         innodb_queue_wait_max => undef,
         innodb_queue_wait_median => undef,
         innodb_queue_wait_min => undef,
         innodb_queue_wait_pct_95 => undef,
         innodb_queue_wait_stddev => undef,
         innodb_rec_lock_wait_max => undef,
         innodb_rec_lock_wait_median => undef,
         innodb_rec_lock_wait_min => undef,
         innodb_rec_lock_wait_pct_95 => undef,
         innodb_rec_lock_wait_stddev => undef,
         lock_time_max => '9.1e-05',
         lock_time_median => '9.1e-05',
         lock_time_min => '9.1e-05',
         lock_time_pct_95 => '9.1e-05',
         lock_time_stddev => '0',
         lock_time_sum => '9.1e-05',
         merge_passes_max => '0',
         merge_passes_median => '0',
         merge_passes_min => '0',
         merge_passes_pct_95 => '0',
         merge_passes_stddev => '0',
         merge_passes_sum => '0',
         qc_hit_cnt => '1',
         qc_hit_sum => '0',
         query_time_max => '0.726052',
         query_time_median => '0.726052',
         query_time_min => '0.726052',
         query_time_pct_95 => '0.726052',
         query_time_stddev => '0',
         query_time_sum => '0.726052',
         rows_affected_max => undef,
         rows_affected_median => undef,
         rows_affected_min => undef,
         rows_affected_pct_95 => undef,
         rows_affected_stddev => undef,
         rows_affected_sum => undef,
         rows_examined_max => '62951',
         rows_examined_median => '62951',
         rows_examined_min => '62951',
         rows_examined_pct_95 => '62951',
         rows_examined_stddev => '0',
         rows_examined_sum => '62951',
         rows_read_max => undef,
         rows_read_median => undef,
         rows_read_min => undef,
         rows_read_pct_95 => undef,
         rows_read_stddev => undef,
         rows_read_sum => undef,
         rows_sent_max => '0',
         rows_sent_median => '0',
         rows_sent_min => '0',
         rows_sent_pct_95 => '0',
         rows_sent_stddev => '0',
         rows_sent_sum => '0',
         tmp_table_cnt => '1',
         tmp_table_sum => '0',
         ts_cnt => '1',
         ts_max => '2007-12-18 11:48:27',
         ts_min => '2007-12-18 11:48:27',
      },
   ],
   "Review history has Percona extended slowlog attribs (issue 1149)"
);

# #############################################################################
# Done.
# #############################################################################
$sb->wipe_clean($dbh);
exit;
