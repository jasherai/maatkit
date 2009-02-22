#!/usr/bin/perl

use strict;
use warnings FATAL => 'all';

use Test::More tests => 47;
use English qw(-no_match_vars);
use constant MKDEBUG => $ENV{MKDEBUG};

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

my $run_with = '../mk-query-digest --noheader --limit 10 ../../common/t/samples/';
my $run_notop = '../mk-query-digest --noheader ../../common/t/samples/';
my $run_header = '../mk-query-digest ../../common/t/samples/';

ok(
   no_diff($run_with.'empty', 'samples/empty_report.txt'),
   'Analysis for empty log'
);

ok(
   no_diff($run_with.'slow001.txt --expectedrange 2,10', 'samples/slow001_report.txt'),
   'Analysis for slow001 with --expectedrange'
);

ok(
   no_diff($run_with.'slow001.txt --groupby tables --report tables',
      'samples/slow001_tablesreport.txt'),
   'Analysis for slow001 with --groupby tables'
);

ok(
   no_diff($run_with.'slow001.txt --report distill',
      'samples/slow001_distillreport.txt'),
   'Analysis for slow001 with distill'
);

ok(
   no_diff($run_with.'slow002.txt --timeline distill',
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
   no_diff($run_with.'slow002.txt --orderby Query_time:cnt --limit 2',
      'samples/slow002_orderbyreport.txt'),
   'Analysis for slow002 --orderby --limit'
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
         . 'slow010.txt --embeddedattr \' -- .*\' --embeddedattrcapt '
         . '\'(\w+): ([^,]+)\' --report file',
      'samples/slow010_reportbyfile.txt'),
   'Analysis for slow010'
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
   no_diff($run_with.'slow013.txt --groupby user --report user',
      'samples/slow013_report_user.txt'),
   'Analysis for slow013 with --groupby user'
);

ok(
   no_diff($run_header.'slow013.txt --norusage --orderby Query_time:sum,Query_time:sum --groupby fingerprint,user --report fingerprint,user',
      'samples/slow013_report_fingerprint_user.txt'),
   'Analysis for slow013 with --groupby fingerprint,user'
);

ok(
   no_diff($run_with.'slow013.txt --groupby user --report user --outliers Query_time:.0000001:1',
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
   '--zeroadmin works'
);

ok(
   no_diff($run_with.'slow019.txt --nozeroadmin', 'samples/slow019_report_noza.txt'),
   '--nozeroadmin works'
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

# #############################################################################
# Test cmd line op sanity.
# #############################################################################
my $output = `../mk-query-digest --review h=127.1,P=12345`;
like($output, qr/--review DSN requires a D/, 'Dies if no D part in --review DSN');
$output = `../mk-query-digest --review h=127.1,P=12345,D=test`;
like($output, qr/--review DSN requires a D/, 'Dies if no t part in --review DSN');

# #############################################################################
# Test that --report cascades to --groupby which cascades to --orderby.
# #############################################################################
$output = `../mk-query-digest --report foo,bar --groupby bar --help`;
like($output, qr/--groupby\s+bar,foo/, '--report cascades to --groupby');
like($output, qr/--orderby\s+Query_time:sum,Query_time:sum/,
   '--groupby cascades to --orderby');

# #############################################################################
# Daemonizing and pid creation
# #############################################################################
# Start one daemonized instance to update it
`../mk-query-digest --daemonize --pid /tmp/mk-query-digest.pid --processlist localhost`;
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
unlink '/tmp/mk-query-digest.pid' or die $OS_ERROR;

# #############################################################################
# Tests for query reviewing and other stuff that requires a DB server.
# #############################################################################
require '../../common/DSNParser.pm';
require '../../common/Sandbox.pm';
use Data::Dumper;
$Data::Dumper::Indent=1;
my $dp  = new DSNParser();
my $sb  = new Sandbox(basedir => '/tmp', DSNParser => $dp);
my $dbh1 = $sb->get_dbh_for('master');
my $dbh2 = $sb->get_dbh_for('slave1');
SKIP: {
   skip 'Cannot connect to sandbox master', 14 if !$dbh1;

   $sb->create_dbs($dbh1, ['test']);
   $sb->load_file('master', 'samples/query_review.sql');

   # Test --explain.  Because the file says 'use sakila' only the first one will
   # succeed.
   ok(
      no_diff($run_with.'slow001.txt --explain h=127.1,P=12345',
         'samples/slow001_explainreport.txt'),
      'Analysis for slow001 with --explain',
   );

   $output = 'foo'; # clear previous test results
   my $cmd = "${run_with}slow006.txt --review h=127.1,P=12345,D=test,t=query_review"; 
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

   # Make sure a missing Time property does not cause a crash.
   $output = 'foo'; # clear previous test results
   $cmd = "${run_with}slow021.txt --review h=127.1,P=12345,D=test,t=query_review"; 
   $output = `$cmd`;
   # Don't test data in table, because it varies based on when you run the test.
   unlike($output, qr/Use of uninitialized value/, 'didnt crash due to undef ts');

   # Make sure a really ugly Time property that doesn't parser does not cause a crash.
   $output = 'foo'; # clear previous test results
   $cmd = "${run_with}slow022.txt --review h=127.1,P=12345,D=test,t=query_review"; 
   $output = `$cmd`;
   # Don't test data in table, because it varies based on when you run the test.
   unlike($output, qr/Use of uninitialized value/, 'no crash due to totally missing ts');

   # This time we'll run with --report and since none of the queries
   # have been reviewed, the report should include both of them with
   # their respective query review info added to the report.
   ok(
      no_diff($run_with.'slow006.txt -R h=127.1,P=12345,D=test,t=query_review', 'samples/slow006_AR_1.txt'),
      'Analyze-review pass 1 reports not-reviewed queries'
   );

   # Mark a query as reviewed and run --report again and that query should
   # not be reported.
   $dbh1->do('UPDATE test.query_review
      SET reviewed_by="daniel", reviewed_on="2008-12-24 12:00:00", comments="foo_tbl is ok, so are cranberries"
      WHERE checksum=11676753765851784517');
   ok(
      no_diff($run_with.'slow006.txt -R h=127.1,P=12345,D=test,t=query_review', 'samples/slow006_AR_2.txt'),
      'Analyze-review pass 2 does not report the reviewed query'
   );

   # And a 4th pass with --reportall which should cause the reviewed query
   # to re-appear in the report with the reviewed_by, reviewed_on and comments
   # info included.
   ok(
      no_diff($run_with.'slow006.txt -R h=127.1,P=12345,D=test,t=query_review   --reportall', 'samples/slow006_AR_4.txt'),
      'Analyze-review pass 4 with --reportall reports reviewed query'
   );

   # Test that reported review info gets all meta-columns dynamically.
   $dbh1->do('ALTER TABLE test.query_review ADD COLUMN foo INT');
   $dbh1->do('UPDATE test.query_review
      SET foo=42 WHERE checksum=15334040482108055940');
   ok(
      no_diff($run_with.'slow006.txt -R h=127.1,P=12345,D=test,t=query_review', 'samples/slow006_AR_5.txt'),
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
   `$cmd > /tmp/read_only.txt &`;
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
      sleep 1;
      $output = `ps -eaf | grep mk-query-diges[t]`;
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
   # # main:3622 6897 read_only wrong for --execute, getting a dbh from processlist
   # # main:3619 6897 read_only on processlist for --processlist: 1 (want 0)
   # # main:3622 6897 read_only wrong for --processlist, getting a dbh from execute
   # # main:3619 6897 read_only on processlist for --execute: 1 (want 1)
   # # main:3619 6897 read_only on execute for --processlist: 0 (want 0)
   like($output, qr/wrong for --execute, getting a dbh from processlist/,
       'switching --processlist works');
   like($output, qr/wrong for --processlist, getting a dbh from execute/,
       'switching --execute works');

   $sb->wipe_clean($dbh1);
};

exit;
