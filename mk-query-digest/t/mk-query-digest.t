#!/usr/bin/perl

use strict;
use warnings FATAL => 'all';
use English qw(-no_match_vars);
use Test::More tests => 102;

use constant MKDEBUG => $ENV{MKDEBUG};

require '../../common/DSNParser.pm';
require '../../common/Sandbox.pm';
use Data::Dumper;
$Data::Dumper::Indent=1;
my $dp  = new DSNParser();
my $sb  = new Sandbox(basedir => '/tmp', DSNParser => $dp);
my $dbh1 = $sb->get_dbh_for('master');
my $dbh2 = $sb->get_dbh_for('slave1');

if ( $dbh1 ) {
   $sb->create_dbs($dbh1, ['test']);
   $sb->load_file('master', 'samples/query_review.sql');
}

# #############################################################################
# First, some basic input-output diffs to make sure that
# the analysis reports are correct.
# #############################################################################

# Returns true (1) if there's no difference between the
# cmd's output and the expected output.
sub no_diff {
   my ( $cmd, $expected_output ) = @_;
   MKDEBUG && diag($cmd);
   `$cmd > /tmp/mk-query-digest_test`;
   # Uncomment this line to update the $expected_output files when there is a
   # fix.
   # `cat /tmp/mk-query-digest_test > $expected_output`;
   my $retval = system("diff /tmp/mk-query-digest_test $expected_output");
   `rm -rf /tmp/mk-query-digest_test`;
   $retval = $retval >> 8; 
   return !$retval;
}

my $run_with = '../mk-query-digest --report-format=query_report --limit 10 ../../common/t/samples/';
my $run_notop = '../mk-query-digest --report-format=query_report ../../common/t/samples/';


ok(
   no_diff($run_with.'empty', 'samples/empty_report.txt'),
   'Analysis for empty log'
);

ok(
   no_diff($run_with.'slow001.txt --expected-range 2,10', 'samples/slow001_report.txt'),
   'Analysis for slow001 with --expected-range'
);

ok(
   no_diff($run_with.'slow001.txt --group-by tables',
      'samples/slow001_tablesreport.txt'),
   'Analysis for slow001 with --group-by tables'
);

ok(
   no_diff($run_with.'slow001.txt --group-by distill',
      'samples/slow001_distillreport.txt'),
   'Analysis for slow001 with distill'
);

ok(
   no_diff($run_with.'slow002.txt --group-by distill --timeline --no-report',
      'samples/slow002_distilltimeline.txt'),
   'Timeline for slow002 with distill'
);

ok(
   no_diff($run_with.'slow001.txt --select Query_time',
      'samples/slow001_select_report.txt'),
   'Analysis for slow001 --select'
);

ok(
   no_diff($run_with.'slow002.txt', 'samples/slow002_report.txt'),
   'Analysis for slow002'
);

ok(
   no_diff($run_with.'slow002.txt --filter \'$event->{arg} =~ m/fill/\'',
   'samples/slow002_report_filtered.txt'),
   'Analysis for slow002 with --filter'
);

ok(
   no_diff($run_with.'slow002.txt --order-by Query_time:cnt --limit 2',
      'samples/slow002_orderbyreport.txt'),
   'Analysis for slow002 --order-by --limit'
);

ok(
   no_diff($run_with.'slow003.txt', 'samples/slow003_report.txt'),
   'Analysis for slow003'
);

ok(
   no_diff($run_with.'slow004.txt', 'samples/slow004_report.txt'),
   'Analysis for slow004'
);

ok(
   no_diff($run_with.'slow006.txt', 'samples/slow006_report.txt'),
   'Analysis for slow006'
);

ok(
   no_diff($run_with.'slow008.txt', 'samples/slow008_report.txt'),
   'Analysis for slow008'
);

ok(
   no_diff(
      $run_with
         . 'slow010.txt --embedded-attributes \' -- .*\',\'(\w+): ([^\,]+)\' '
         . '--group-by file',
      'samples/slow010_reportbyfile.txt'),
   'Analysis for slow010 --group-by some --embedded-attributes'
);

ok(
   no_diff($run_with.'slow011.txt', 'samples/slow011_report.txt'),
   'Analysis for slow011'
);

ok(
   no_diff($run_with.'slow013.txt', 'samples/slow013_report.txt'),
   'Analysis for slow013'
);

ok(
   no_diff($run_with.'slow013.txt --group-by user',
      'samples/slow013_report_user.txt'),
   'Analysis for slow013 with --group-by user'
);

ok(
   no_diff($run_with.'slow013.txt --limit 1 --report-format header,query_report  --group-by fingerprint,user',
      'samples/slow013_report_fingerprint_user.txt'),
   'Analysis for slow013 with --group-by fingerprint,user'
);

ok(
   no_diff($run_with.'slow013.txt --report-format profile --limit 3',
      'samples/slow013_report_profile.txt'),
   'Analysis for slow013 with profile',
);

ok(
   no_diff($run_with.'slow013.txt --group-by user --outliers Query_time:.0000001:1',
      'samples/slow013_report_outliers.txt'),
   'Analysis for slow013 with --outliers'
);

ok(
   no_diff($run_with.'slow013.txt --limit 100%:1',
      'samples/slow013_report_limit.txt'),
   'Analysis for slow013 with --limit'
);

ok(
   no_diff($run_with.'slow014.txt', 'samples/slow014_report.txt'),
   'Analysis for slow014'
);

ok(
   no_diff($run_with.'slow018.txt', 'samples/slow018_report.txt'),
   'Analysis for slow018'
);

ok(
   no_diff($run_with.'slow019.txt', 'samples/slow019_report.txt'),
   '--zero-admin works'
);

ok(
   no_diff($run_with.'slow019.txt --nozero-admin', 'samples/slow019_report_noza.txt'),
   '--nozero-admin works'
);

# This was fixed at some point by checking the fingerprint to see if the
# query needed to be converted to a SELECT.
ok(
   no_diff($run_with.'slow023.txt', 'samples/slow023.txt'),
   'Queries that start with a comment are not converted for EXPLAIN',
);

ok(
   no_diff($run_with.'slow024.txt', 'samples/slow024.txt'),
   'Long inserts/replaces are truncated (issue 216)',
);

# Issue 244, no output when --order-by doesn't exist
ok(
   no_diff($run_with . 'slow002.txt --order-by Rows_read:sum',
      'samples/slow002-orderbynonexistent.txt'),
   'Order by non-existent falls back to default',
);

# Issue 337, duplicate table names
ok(
   no_diff($run_with . 'slow028.txt',
      'samples/slow028.txt'),
   'No duplicate table names',
);

# Issue 458, Use of uninitialized value in division (/) 
ok(
   no_diff($run_with . 'slow035.txt --report-format header,query_report,profile', 'samples/slow035.txt'),
   'Pathological all attribs, minimal attribs, all zero values (slow035)',
);

# Issue 563, Lock tables is not distilled
ok(
   no_diff($run_with . 'slow037.txt --group-by distill --report-format=query_report,profile',
      'samples/slow037_report.txt'),
   'Distill UNLOCK and LOCK TABLES'
);

# #############################################################################
# Issue 228: parse tcpdump.
# #############################################################################
{ # Isolate $run_with locally
   my $run_with = 'perl ../mk-query-digest --report-format=query_report --limit 100 '
      . '--type tcpdump ../../common/t/samples';
   ok(
      no_diff("$run_with/tcpdump002.txt", 'samples/tcpdump002_report.txt'),
      'Analysis for tcpdump002',
   );
}

# #############################################################################
# Issue 476: parse binary logs.
# #############################################################################
{ # Isolate $run_with locally
   # We want the profile report so we can check that queries like
   # CREATE DATABASE are distilled correctly.
   my $run_with = 'perl ../mk-query-digest --report-format header,query_report,profile --type binlog ../../common/t/samples';

   ok(
      no_diff("$run_with/binlog001.txt", 'samples/binlog001.txt'),
      'Analysis for binlog001',
   );

   ok(
      no_diff("$run_with/binlog002.txt", 'samples/binlog002.txt'),
      'Analysis for binlog002',
   );
}

# #############################################################################
# Test cmd line op sanity.
# #############################################################################
my $output = `../mk-query-digest --review h=127.1,P=12345`;
like($output, qr/--review DSN requires a D/, 'Dies if no D part in --review DSN');
$output = `../mk-query-digest --review h=127.1,P=12345,D=test`;
like($output, qr/--review DSN requires a D/, 'Dies if no t part in --review DSN');

# #############################################################################
# Test that --group-by cascades to --order-by.
# #############################################################################
$output = `../mk-query-digest --group-by foo,bar --help`;
like($output, qr/--order-by\s+Query_time:sum,Query_time:sum/,
   '--group-by cascades to --order-by');

# #############################################################################
# Tests for query reviewing and other stuff that requires a DB server.
# #############################################################################
my $cmd;
SKIP: {
   skip 'Cannot connect to sandbox master', 22 if !$dbh1;

   # #########################################################################
   # Daemonizing and pid creation
   # #########################################################################
   `../mk-query-digest --daemonize --pid /tmp/mk-query-digest.pid --processlist h=127.1,P=12345 --log /dev/null`;
   $output = `ps -eaf | grep mk-query-digest | grep daemonize`;
   like($output, qr/perl ...mk-query-digest/, 'It is running');
   ok(-f '/tmp/mk-query-digest.pid', 'PID file created');

   my ($pid) = $output =~ /\s+(\d+)\s+/;
   $output = `cat /tmp/mk-query-digest.pid`;
   is($output, $pid, 'PID file has correct PID');

   kill 15, $pid;
   sleep 1;
   $output = `ps -eaf | grep mk-query-digest | grep daemonize`;
   unlike($output, qr/perl ...mk-query-digest/, 'It is not running');
   ok(
      !-f '/tmp/mk-query-digest.pid',
      'Removes its PID file'
   );

   # Test --explain.  Because the file says 'use sakila' only the first one will
   # succeed.
   SKIP: {
      # TODO: change slow001.sql or do something else to make this work
      # with or without the sakila db loaded.
      skip 'Sakila database is loaded which breaks this test', 1
         if @{$dbh1->selectcol_arrayref('SHOW DATABASES LIKE "sakila"')};
      ok(
         no_diff($run_with.'slow001.txt --explain h=127.1,P=12345',
            'samples/slow001_explainreport.txt'),
         'Analysis for slow001 with --explain',
      );
   };

   $sb->load_file('master', 'samples/query_review.sql');

   # Test --create-review and --create-review-history-table
   $output = 'foo'; # clear previous test results
   $cmd = "${run_with}slow006.txt --create-review-table --review "
      . "h=127.1,P=12345,D=test,t=query_review --create-review-history-table "
      . "--review-history t=query_review_history";
   $output = `$cmd >/dev/null 2>&1`;

   my ($table) = $dbh1->selectrow_array(
      'show tables from test like "query_review"');
   is($table, 'query_review', '--create-review');
   ($table) = $dbh1->selectrow_array(
      'show tables from test like "query_review_history"');
   is($table, 'query_review_history', '--create-review-history-table');

   $output = 'foo'; # clear previous test results
   $cmd = "${run_with}slow006.txt --review h=127.1,P=12345,D=test,t=query_review "
      . "--review-history t=query_review_history";
   $output = `$cmd`;
   my $res = $dbh1->selectall_arrayref( 'SELECT * FROM test.query_review',
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
   $res = $dbh1->selectall_arrayref( 'SELECT * FROM test.query_review_history',
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
      no_diff($run_with.'slow006.txt --review h=127.1,P=12345,D=test,t=query_review', 'samples/slow006_AR_1.txt'),
      'Analyze-review pass 1 reports not-reviewed queries'
   );

   # Mark a query as reviewed and run --report again and that query should
   # not be reported.
   $dbh1->do('UPDATE test.query_review
      SET reviewed_by="daniel", reviewed_on="2008-12-24 12:00:00", comments="foo_tbl is ok, so are cranberries"
      WHERE checksum=11676753765851784517');
   ok(
      no_diff($run_with.'slow006.txt --review h=127.1,P=12345,D=test,t=query_review', 'samples/slow006_AR_2.txt'),
      'Analyze-review pass 2 does not report the reviewed query'
   );

   # And a 4th pass with --report-all which should cause the reviewed query
   # to re-appear in the report with the reviewed_by, reviewed_on and comments
   # info included.
   ok(
      no_diff($run_with.'slow006.txt --review h=127.1,P=12345,D=test,t=query_review   --report-all', 'samples/slow006_AR_4.txt'),
      'Analyze-review pass 4 with --report-all reports reviewed query'
   );

   # Test that reported review info gets all meta-columns dynamically.
   $dbh1->do('ALTER TABLE test.query_review ADD COLUMN foo INT');
   $dbh1->do('UPDATE test.query_review
      SET foo=42 WHERE checksum=15334040482108055940');
   ok(
      no_diff($run_with.'slow006.txt --review h=127.1,P=12345,D=test,t=query_review', 'samples/slow006_AR_5.txt'),
      'Analyze-review pass 5 reports new review info column'
   );

   # Make sure that when we run with all-0 timestamps they don't show up in the
   # output because they are useless of course (issue 202).
   $dbh1->do("update test.query_review set first_seen='0000-00-00 00:00:00', "
      . " last_seen='0000-00-00 00:00:00'");
   $output = 'foo'; # clear previous test results
   $cmd = "${run_with}slow022.txt --review h=127.1,P=12345,D=test,t=query_review"; 
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
   $cmd = "${run_with}slow021.txt --review h=127.1,P=12345,D=test,t=query_review"; 
   $output = `$cmd`;
   unlike($output, qr/Use of uninitialized value/, 'didnt crash due to undef ts');

   # Make sure a really ugly Time property that doesn't parse does not cause a
   # crash.  Don't test data in table, because it varies based on when you run
   # the test.
   $output = 'foo'; # clear previous test results
   $cmd = "${run_with}slow022.txt --review h=127.1,P=12345,D=test,t=query_review"; 
   $output = `$cmd`;
   # Don't test data in table, because it varies based on when you run the test.
   unlike($output, qr/Use of uninitialized value/, 'no crash due to totally missing ts');

   # ##########################################################################
   # Tests for swapping --processlist and --execute
   # ##########################################################################
   $dbh1->do('set global read_only=0');
   $dbh2->do('set global read_only=1');
   $cmd  = "perl ../mk-query-digest --processlist h=127.1,P=12345 "
            . "--execute h=127.1,P=12346 --mirror 1 "
            . "--pid foobar";
   # --pid actually does nothing because the script is not daemonizing.
   # I include it for the identifier (foobar) so that we can more easily
   # grep the PID below. Otherwise, a ps | grep mk-query-digest will
   # match this test script and any vi mk-query-digest[.t] that may happen
   # to be running.

   $ENV{MKDEBUG}=1;
   `$cmd > /tmp/read_only.txt 2>&1 &`;
   $ENV{MKDEBUG}=0;
   sleep 5;
   $dbh1->do('select sleep(1)');
   sleep 1;
   $dbh1->do('set global read_only=1');
   $dbh2->do('set global read_only=0');
   $dbh1->do('select sleep(1)');
   sleep 2;
   $output = `ps -eaf | grep mk-query-diges[t] | grep foobar | awk '{print \$2}'`;
   kill 15, $output =~ m/(\d+)/g;
   # Verify that it's dead...
   $output = `ps -eaf | grep mk-query-diges[t] | grep foobar`;
   if ( $output =~ m/digest/ ) {
      $output = `ps -eaf | grep mk-query-diges[t] | grep foobar`;
   }
   unlike($output, qr/mk-query-digest/, 'It is stopped now'); 

   $dbh1->do('set global read_only=0');
   $dbh2->do('set global read_only=1');
   $output = `grep read_only /tmp/read_only.txt`;
   # Sample output:
   # # main:3619 6897 read_only on execute for --execute: 1 (want 1)
   # # main:3619 6897 read_only on processlist for --processlist: 0 (want 0)
   # # main:3619 6897 read_only on processlist for --processlist: 0 (want 0)
   # # main:3619 6897 read_only on processlist for --processlist: 0 (want 0)
   # # main:3619 6897 read_only on processlist for --processlist: 0 (want 0)
   # # main:3619 6897 read_only on processlist for --processlist: 0 (want 0)
   # # main:3619 6897 read_only on processlist for --processlist: 0 (want 0)
   # # main:3619 6897 read_only on execute for --execute: 0 (want 1)
   # # main:3622 6897 read_only wrong for --execute getting a dbh from processlist
   # # main:3619 6897 read_only on processlist for --processlist: 1 (want 0)
   # # main:3622 6897 read_only wrong for --processlist getting a dbh from execute
   # # main:3619 6897 read_only on processlist for --execute: 1 (want 1)
   # # main:3619 6897 read_only on execute for --processlist: 0 (want 0)
   like($output, qr/wrong for --execute getting a dbh from processlist/,
       'switching --processlist works');
   like($output, qr/wrong for --processlist getting a dbh from execute/,
       'switching --execute works');

   diag(`rm -rf /tmp/read_only.txt`);
};

# Test --continue-on-error.
$output = `../mk-query-digest --no-continue-on-error --type tcpdump samples/bad_tcpdump.txt 2>&1`;
unlike(
   $output,
   qr/Query 1/,
   'Does not continue on error with --no-continue-on-error'
);
$output = `../mk-query-digest --type tcpdump samples/bad_tcpdump.txt 2>&1`;
like(
   $output,
   qr/paris in the the spring/,
   'Continues on error by default'
);

# #############################################################################
# Issue 232: mk-query-digest does not properly handle logs with an empty Schema:
# #############################################################################
$output = 'foo'; # clear previous test results
$cmd = "${run_with}slow026.txt";
$output = `MKDEBUG=1 $cmd 2>&1`;
# Changed qr// from matching db to Schema because attribs are auto-detected.
like(
   $output,
   qr/Type for db is string /,
   'Type for empty Schema: is string (issue 232)',
);

unlike(
   $output,
   qr/Argument "" isn't numeric in numeric gt/,
   'No error message in debug output for empty Schema: (issue 232)'
);

# #############################################################################
# Issue 398: Fix mk-query-digest to handle timestamps that have microseconds
# #############################################################################
ok(
   no_diff('../mk-query-digest ../../common/t/samples/tcpdump017.txt --type tcpdump --report-format header,query_report,profile',
      'samples/tcpdump017_report.txt'),
   'Analysis for tcpdump017 with microsecond timestamps (issue 398)'
);

# #############################################################################
# Issue 462: Filter out all but first N of each
# #############################################################################
ok(
   no_diff('../mk-query-digest ../../common/t/samples/slow006.txt '
      . '--no-report --print --sample 2',
      'samples/slow006-first2.txt'),
   'Print only first N unique occurrences with explicit --group-by',
);

# #############################################################################
# Issue 470: mk-query-digest --sample does not work with --report ''
# #############################################################################
ok(
   no_diff('../mk-query-digest ../../common/t/samples/slow006.txt '
      . '--no-report --print --sample 2',
      'samples/slow006-first2.txt'),
   'Print only first N unique occurrences, --no-report',
);

$output = `../mk-query-digest --no-report --help 2>&1`;
like(
   $output,
   qr/--group-by\s+fingerprint/,
   "Default --group-by with --no-report"
);


# #############################################################################
# Issue 514: mk-query-digest does not create handler sub for new auto-detected
# attributes
# #############################################################################
# This issue actually introduced --check-attributes-limit.
$cmd = "${run_with}slow030.txt";
$output = `$cmd --check-attributes-limit 100 2>&1`;
unlike(
   $output,
   qr/IDB IO rb/,
   '--check-attributes-limit (issue 514)'
);

# #############################################################################
# Issue 525: Add memcached support to mk-query-digest
# #############################################################################
ok(
   no_diff($run_with.'memc_tcpdump001.txt --type memcached',
   'samples/memc_tcpdump001.txt'),
   'Analysis for memc_tcpdump001.txt'
);

ok(
   no_diff($run_with.'memc_tcpdump002.txt --type memcached',
   'samples/memc_tcpdump002.txt'),
   'Analysis for memc_tcpdump002.txt'
);

ok(
   no_diff($run_with.'memc_tcpdump003.txt --type memcached',
   'samples/memc_tcpdump003.txt'),
   'Analysis for memc_tcpdump003.txt'
);

ok(
   no_diff($run_with.'memc_tcpdump003.txt --type memcached --group-by key_print',
   'samples/memc_tcpdump003_report_key_print.txt'),
   'Analysis for memc_tcpdump003.txt --group-by key_print'
);

ok(
   no_diff($run_with.'memc_tcpdump004.txt --type memcached',
   'samples/memc_tcpdump004.txt'),
   'Analysis for memc_tcpdump004.txt'
);

ok(
   no_diff($run_with.'memc_tcpdump005.txt --type memcached',
   'samples/memc_tcpdump005.txt'),
   'Analysis for memc_tcpdump005.txt'
);

ok(
   no_diff($run_with.'memc_tcpdump006.txt --type memcached',
   'samples/memc_tcpdump006.txt'),
   'Analysis for memc_tcpdump006.txt'
);

ok(
   no_diff($run_with.'memc_tcpdump007.txt --type memcached',
   'samples/memc_tcpdump007.txt'),
   'Analysis for memc_tcpdump007.txt'
);

ok(
   no_diff($run_with.'memc_tcpdump008.txt --type memcached',
   'samples/memc_tcpdump008.txt'),
   'Analysis for memc_tcpdump008.txt'
);

ok(
   no_diff($run_with.'memc_tcpdump009.txt --type memcached',
   'samples/memc_tcpdump009.txt'),
   'Analysis for memc_tcpdump009.txt'
);

ok(
   no_diff($run_with.'memc_tcpdump010.txt --type memcached',
   'samples/memc_tcpdump010.txt'),
   'Analysis for memc_tcpdump010.txt'
);

# #############################################################################
# Issue 154: Add --since and --until options to mk-query-digest
# #############################################################################

# --since
ok(
   no_diff($run_with.'slow033.txt --since 2009-07-28', 'samples/slow033-since-yyyy-mm-dd.txt'),
   '--since 2009-07-28'
);

ok(
   no_diff($run_with.'slow033.txt --since 090727', 'samples/slow033-since-yymmdd.txt'),
   '--since 090727'
);

# This test will fail come July 2014.
ok(
   no_diff($run_with.'slow033.txt --since 1825d', 'samples/slow033-since-Nd.txt'),
   '--since 1825d (5 years ago)'
);

# --until
ok(
   no_diff($run_with.'slow033.txt --until 2009-07-27', 'samples/slow033-until-date.txt'),
   '--until 2009-07-27'
);

ok(
   no_diff($run_with.'slow033.txt --until 090727', 'samples/slow033-until-date.txt'),
   '--until 090727'
);

# The result file is correct: it's the one that has all quries from slow033.txt.
ok(
   no_diff($run_with.'slow033.txt --until 1d', 'samples/slow033-since-Nd.txt'),
   '--until 1d'
);

# And one very precise --since --until.
ok(
   no_diff($run_with.'slow033.txt --since "2009-07-26 11:19:28" --until "090727 11:30:00"', 'samples/slow033-precise-since-until.txt'),
   '--since "2009-07-26 11:19:28" --until "090727 11:30:00"'
);

SKIP: {
   skip 'Cannot connect to sandbox master', 2 unless $dbh1;


   # The result file is correct: it's the one that has all quries from
   # slow033.txt.
   ok(
      no_diff($run_with.'slow033.txt --aux-dsn h=127.1,P=12345 --since "\'2009-07-08\' - INTERVAL 7 DAY"', 'samples/slow033-since-Nd.txt'),
      '--since "\'2009-07-08\' - INTERVAL 7 DAY"',
   );

   ok(
      no_diff($run_with.'slow033.txt --aux-dsn h=127.1,P=12345 --until "\'2009-07-28\' - INTERVAL 1 DAY"', 'samples/slow033-until-date.txt'),
      '--until "\'2009-07-28\' - INTERVAL 1 DAY"',
   );
};

# #############################################################################
# Issue 256: Test that --report, --group-by, --order-by and --review all work
# properly together.
# #############################################################################

ok(
   no_diff($run_with.'slow034.txt --order-by Lock_time:sum --report-format=query_report,profile', 'samples/slow034-order-by-Locktime-sum.txt'),
   'Analysis for slow034 --order-by Lock_time:sum'
);

SKIP: {
   skip 'Cannot connect to sandbox master', 2 unless $dbh1;
   $sb->load_file('master', 'samples/query_review.sql');
   my $output = `${run_with}slow006.txt --review h=127.1,P=12345,D=test,t=query_review --no-report --create-review-table`;
   my $res = $dbh1->selectall_arrayref('SELECT * FROM test.query_review');
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
};

# #############################################################################
# Issue 479: Make mk-query-digest carry Schema and ts attributes along the
# pipeline
# #############################################################################
ok(
   no_diff($run_with.'slow034.txt --no-report --print', 'samples/slow034-inheritance.txt'),
   'Analysis for slow034 with inheritance'
);

# Make sure we can turn off some default inheritance, 'ts' in this test.
ok(
   no_diff($run_with.'slow034.txt --no-report --print --inherit-attributes db', 'samples/slow034-no-ts-inheritance.txt'),
   'Analysis for slow034 without default ts inheritance'
);

# #############################################################################
# Issue 360: mk-query-digest first_seen and last_seen not automatically
# populated
# #############################################################################
SKIP: {
   skip 'Cannot connect to sandbox master', 2 unless $dbh1;
   $dbh1->do('DROP TABLE IF EXISTS test.query_review');
   `../mk-query-digest --processlist h=127.1,P=12345 --interval 0.01 --create-review-table --review h=127.1,P=12345,D=test,t=query_review --daemonize --log /tmp/mk-query-digest.log --pid /tmp/mk-query-digest.pid --run-time 2`;
   `/tmp/12345/use < ../../mk-archiver/t/before.sql`;
   `rm -rf /tmp/mk-query-digest.log`;
   my @ts = $dbh1->selectrow_array('SELECT first_seen, last_seen FROM test.query_review LIMIT 1');
   ok(
      $ts[0] ne '0000-00-00 00:00:00',
      'first_seen from --processlist is not 0000-00-00 00:00:00'
   );
   ok(
      $ts[1] ne '0000-00-00 00:00:00',
      'last_seen from --processlist is not 0000-00-00 00:00:00'
   );
};

# #############################################################################
# Issue 248: Add --user, --pass, --host, etc to all tools
# #############################################################################
SKIP: {
   skip 'Cannot connect to sandbox master', 1 unless $dbh1;
   $output = `../mk-query-digest --processlist 127.1 --run-time 1 --port 12345`;
   like(
      $output,
      qr/Rank\s+Query ID/,
      'DSN opts inherit from --host, --port, etc. (issue 248)'
   );
};

# #############################################################################
# Issue 361: Add a --runfor (or something) option to mk-query-digest
# #############################################################################
SKIP: {
   skip 'Cannot connect to sandbox master', 2 unless $dbh1;
   `../mk-query-digest --processlist 127.1 --run-time 3 --port 12345 --log /tmp/mk-query-digest.log --pid /tmp/mk-query-digest.pid --daemonize 1>/dev/null 2>/dev/null`;
   chomp(my $pid = `cat /tmp/mk-query-digest.pid`);
   sleep 2;
   my $output = `ps ax | grep $pid | grep processlist | grep -v grep`;
   ok(
      $output,
      'Still running for --run-time (issue 361)'
   );

   sleep 1;
   $output = `ps ax | grep $pid | grep processlist | grep -v grep`;
   ok(
      !$output,
      'No longer running for --run-time (issue 361)'
   );

   diag(`rm -rf /tmp/mk-query-digest.log`);

# #############################################################################
# Issue 173: Make mk-query-digest do collect-and-report cycles
# #############################################################################

   # --run-for is tested above.  This tests --iterations by checking that
   # its value multiplies --run-for.  So if --run-for is 2 and we do 2
   # iterations, we should run for 4 seconds total.
   `../mk-query-digest --processlist 127.1 --run-time 2 --iterations 2 --port 12345 --pid /tmp/mk-query-digest.pid --daemonize 1>/dev/null 2>/dev/null`;
   chomp($pid = `cat /tmp/mk-query-digest.pid`);
   sleep 3;
   $output = `ps ax | grep $pid | grep processlist | grep -v grep`;
   ok(
      $output,
      'Still running for --iterations (issue 173)'
   );

   sleep 2;
   $output = `ps ax | grep $pid | grep processlist | grep -v grep`;
   ok(
      !$output,
      'No longer running for --iterations (issue 173)'
   );

   # Another implicit test of --iterations checks that on the second
   # iteration no queries are reported because the slowlog was read
   # entirely by the first iteration.
   ok(
      no_diff($run_with . 'slow002.txt --iterations 2   --report-format=query_report,profile --limit 1',
      'samples/slow002_iters_2.txt'),
      '--iterations'
   );
};

# #############################################################################
# Issue 565: mk-query-digest isn't compiling filter correctly
# #############################################################################
$output = `../mk-query-digest --type tcpdump --filter '\$event->{No_index_used} || \$event->{No_good_index_used}' --group-by tables  ../../common/t/samples/tcpdump014.txt 2>&1`;
unlike(
   $output,
   qr/Can't use string/,
   '--filter compiles correctly (issue 565)'
);

# #############################################################################
# Done.
# #############################################################################
$sb->wipe_clean($dbh1) if $dbh1;
exit;
