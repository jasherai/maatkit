#!/usr/bin/env perl

use strict;
use warnings FATAL => 'all';
use English qw(-no_match_vars);
use Test::More tests => 35;

use constant MKDEBUG => $ENV{MKDEBUG};

require '../../common/MaatkitTest.pm';
MaatkitTest->import(qw(no_diff));

# #############################################################################
# First, some basic input-output diffs to make sure that
# the analysis reports are correct.
# #############################################################################

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

# Test --table-access.
ok(
   no_diff($run_with . 'slow020.txt --no-report --table-access',
      'samples/slow020_table_access.txt'),
   'Analysis for slow020 with --table-access'
);

# This one tests that the list of tables is unique.
ok(
   no_diff($run_with . 'slow030.txt --no-report --table-access',
      'samples/slow030_table_access.txt'),
   'Analysis for slow030 with --table-access'
);

ok(
   no_diff($run_with.'slow034.txt --order-by Lock_time:sum --report-format=query_report,profile', 'samples/slow034-order-by-Locktime-sum.txt'),
   'Analysis for slow034 --order-by Lock_time:sum'
);

# #############################################################################
# Test a sample that at one point caused an error (trunk doesn't have the error
# now):
# Use of uninitialized value in join or string at mk-query-digest line 1713.
# or on newer Perl:
# Use of uninitialized value $verbs in join or string at mk-query-digest line
# 1713.
# The code in question is this:
#  else {
#     my ($verbs, $table)  = $self->_distill_verbs($query, %args);
#     my @tables           = $self->_distill_tables($query, $table, %args);
#     $query               = join(q{ }, $verbs, @tables);
#  }
# #############################################################################
my $output = `../mk-query-digest ../../common/t/samples/slow041.txt >/dev/null 2>/tmp/mqd-warnings.txt`;
is(
   -s '/tmp/mqd-warnings.txt',
   0,
   'No warnings on file 041'
);
diag(`rm -rf /tmp/mqd-warnings.txt`);

# #############################################################################
# Done.
# #############################################################################
exit;
