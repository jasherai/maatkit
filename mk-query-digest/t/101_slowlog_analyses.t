#!/usr/bin/env perl

BEGIN {
   die "The MAATKIT_TRUNK environment variable is not set.  See http://code.google.com/p/maatkit/wiki/Testing"
      unless $ENV{MAATKIT_TRUNK} && -d $ENV{MAATKIT_TRUNK};
   unshift @INC, "$ENV{MAATKIT_TRUNK}/common";
};

use strict;
use warnings FATAL => 'all';
use English qw(-no_match_vars);
use Test::More tests => 35;

use MaatkitTest;

# Normally we want $trunk/common in @INC so we can "use MaakitTest" and
# other modules path-independently.  However, mk-query-digest uses
# HTMLProtocolParser which is a subclass of ProtocolParser, so the former
# must "use base 'ProtocolParser'" which causes Perl to load ProtocolParser
# from @INC.  This causes errors about ProtocolParser::new() being redefined:
# once in mk-query-digest's copy of the module and again from the actual
# module in $trunk/common.  We remove $trunk/common from @INC so Perl won't
# find/load it again.  See http://code.google.com/p/maatkit/wiki/Testing
shift @INC;  # our unshift (above)
shift @INC;  # MaatkitTest's unshift

require "$trunk/mk-query-digest/mk-query-digest";

# #############################################################################
# First, some basic input-output diffs to make sure that
# the analysis reports are correct.
# #############################################################################

my @args   = qw(--report-format=query_report --limit 10);
my $sample = "$trunk/common/t/samples/";

ok(
   no_diff(
      sub { mk_query_digest::main(@args, $sample.'empty') },
      "mk-query-digest/t/samples/empty_report.txt",
   ),
   'Analysis for empty log'
);

ok(
   no_diff(
      sub { mk_query_digest::main(@args, $sample.'slow001.txt', '--expected-range', '2,10') },
      "mk-query-digest/t/samples/slow001_report.txt"
   ),
   'Analysis for slow001 with --expected-range'
);

ok(
   no_diff(
      sub { mk_query_digest::main(@args, $sample.'slow001.txt', qw(--group-by tables)) },
      "mk-query-digest/t/samples/slow001_tablesreport.txt"
   ),
   'Analysis for slow001 with --group-by tables'
);

ok(
   no_diff(
      sub { mk_query_digest::main(@args, $sample.'slow001.txt', qw(--group-by distill)) },
      "mk-query-digest/t/samples/slow001_distillreport.txt"
   ),
   'Analysis for slow001 with distill'
);

ok(
   no_diff(
      sub { mk_query_digest::main(@args, $sample.'slow002.txt',
            qw(--group-by distill --timeline --no-report)) },
      "mk-query-digest/t/samples/slow002_distilltimeline.txt"
   ),
   'Timeline for slow002 with distill'
);

ok(
   no_diff(
      sub { mk_query_digest::main(@args, $sample.'slow001.txt', qw(--select Query_time)) },
      "mk-query-digest/t/samples/slow001_select_report.txt"
   ),
   'Analysis for slow001 --select'
);

ok(
   no_diff(
      sub { mk_query_digest::main(@args, $sample.'slow002.txt') },
      "mk-query-digest/t/samples/slow002_report.txt"
   ),
   'Analysis for slow002'
);

ok(
   no_diff(
      sub { mk_query_digest::main(@args, $sample.'slow002.txt',
               '--filter', '$event->{arg} =~ m/fill/') },
      "mk-query-digest/t/samples/slow002_report_filtered.txt"
   ),
   'Analysis for slow002 with --filter'
);

ok(
   no_diff(
      sub { mk_query_digest::main(@args, $sample.'slow002.txt',
               qw(--order-by Query_time:cnt --limit 2)) },
      "mk-query-digest/t/samples/slow002_orderbyreport.txt"
   ),
   'Analysis for slow002 --order-by --limit'
);

ok(
   no_diff(
      sub { mk_query_digest::main(@args, $sample.'slow003.txt') },
      "mk-query-digest/t/samples/slow003_report.txt"
   ),
   'Analysis for slow003'
);

ok(
   no_diff(
      sub { mk_query_digest::main(@args, $sample.'slow004.txt') },
      "mk-query-digest/t/samples/slow004_report.txt"
   ),
   'Analysis for slow004'
);

ok(
   no_diff(
      sub { mk_query_digest::main(@args, $sample.'slow006.txt') },
      "mk-query-digest/t/samples/slow006_report.txt"
   ),
   'Analysis for slow006'
);

ok(
   no_diff(
      sub { mk_query_digest::main(@args, $sample.'slow008.txt') },
      "mk-query-digest/t/samples/slow008_report.txt"
   ),
   'Analysis for slow008'
);

ok(
   no_diff(
      sub { mk_query_digest::main(@args, $sample.'slow010.txt',
            '--embedded-attributes', ' -- .*,(\w+): ([^\,]+)',
            qw(--group-by file)) },
      "mk-query-digest/t/samples/slow010_reportbyfile.txt"
   ),
   'Analysis for slow010 --group-by some --embedded-attributes'
);

ok(
   no_diff(
       sub { mk_query_digest::main(@args, $sample.'slow011.txt') },
       "mk-query-digest/t/samples/slow011_report.txt"
   ),
   'Analysis for slow011'
);

ok(
   no_diff(
      sub { mk_query_digest::main(@args, $sample.'slow013.txt') },
      "mk-query-digest/t/samples/slow013_report.txt"
   ),
   'Analysis for slow013'
);

ok(
   no_diff(
      sub { mk_query_digest::main(@args, $sample.'slow013.txt', qw(--group-by user)) },
      "mk-query-digest/t/samples/slow013_report_user.txt"
   ),
   'Analysis for slow013 with --group-by user'
);

ok(
   no_diff(
      sub { mk_query_digest::main(@args, $sample.'slow013.txt',
            qw(--limit 1 --report-format), 'header,query_report', '--group-by', 'fingerprint,user') },
      "mk-query-digest/t/samples/slow013_report_fingerprint_user.txt"
   ),
   'Analysis for slow013 with --group-by fingerprint,user'
);

ok(
   no_diff(
      sub { mk_query_digest::main(@args, $sample.'slow013.txt', qw(--report-format profile --limit 3)) },
      "mk-query-digest/t/samples/slow013_report_profile.txt"
   ),
   'Analysis for slow013 with profile',
);

ok(
   no_diff(
      sub { mk_query_digest::main(@args, $sample.'slow013.txt',
            qw(--group-by user --outliers Query_time:.0000001:1)) },
      "mk-query-digest/t/samples/slow013_report_outliers.txt"
   ),
   'Analysis for slow013 with --outliers'
);

ok(
   no_diff(
      sub { mk_query_digest::main(@args, $sample.'slow013.txt', qw(--limit 100%:1)) },
      "mk-query-digest/t/samples/slow013_report_limit.txt"
   ),
   'Analysis for slow013 with --limit'
);

ok(
   no_diff(
      sub { mk_query_digest::main(@args, $sample.'slow014.txt') },
      "mk-query-digest/t/samples/slow014_report.txt"
   ),
   'Analysis for slow014'
);

ok(
   no_diff(
      sub { mk_query_digest::main(@args, $sample.'slow018.txt') },
      "mk-query-digest/t/samples/slow018_report.txt"
   ),
   'Analysis for slow018'
);

ok(
   no_diff(
      sub { mk_query_digest::main(@args, $sample.'slow019.txt') },
      "mk-query-digest/t/samples/slow019_report.txt"
   ),
   '--zero-admin works'
);

ok(
   no_diff(
      sub { mk_query_digest::main(@args, $sample.'slow019.txt', qw(--nozero-admin)) },
      "mk-query-digest/t/samples/slow019_report_noza.txt"
   ),
   '--nozero-admin works'
);

# This was fixed at some point by checking the fingerprint to see if the
# query needed to be converted to a SELECT.
ok(
   no_diff(
      sub { mk_query_digest::main(@args, $sample.'slow023.txt') },
      "mk-query-digest/t/samples/slow023.txt"
   ),
   'Queries that start with a comment are not converted for EXPLAIN',
);

ok(
   no_diff(
      sub { mk_query_digest::main(@args, $sample.'slow024.txt') },
      "mk-query-digest/t/samples/slow024.txt"
   ),
   'Long inserts/replaces are truncated (issue 216)',
);

# Issue 244, no output when --order-by doesn't exist
ok(
   no_diff(
      sub { mk_query_digest::main(@args, $sample.'slow002.txt', qw(--order-by Rows_read:sum)) },
      "mk-query-digest/t/samples/slow002-orderbynonexistent.txt"
   ),
   'Order by non-existent falls back to default',
);

# Issue 337, duplicate table names
ok(
   no_diff(
      sub { mk_query_digest::main(@args, $sample.'slow028.txt') },
      "mk-query-digest/t/samples/slow028.txt"
   ),
   'No duplicate table names',
);

# Issue 458, Use of uninitialized value in division (/) 
ok(
   no_diff(
      sub { mk_query_digest::main(@args, $sample.'slow035.txt',
            '--report-format', 'header,query_report,profile') },
      "mk-query-digest/t/samples/slow035.txt"
   ),
   'Pathological all attribs, minimal attribs, all zero values (slow035)',
);

# Issue 563, Lock tables is not distilled
ok(
   no_diff(
      sub { mk_query_digest::main(@args, $sample.'slow037.txt', qw(--group-by distill),
            '--report-format', 'query_report,profile') },
      "mk-query-digest/t/samples/slow037_report.txt"
   ),
   'Distill UNLOCK and LOCK TABLES'
);

# Test --table-access.
ok(
   no_diff(
      sub { mk_query_digest::main(@args, $sample.'slow020.txt', qw(--no-report --table-access)) },
      "mk-query-digest/t/samples/slow020_table_access.txt"
   ),
   'Analysis for slow020 with --table-access'
);

# This one tests that the list of tables is unique.
ok(
   no_diff(
      sub { mk_query_digest::main(@args, $sample.'slow030.txt', qw(--no-report --table-access)) },
      "mk-query-digest/t/samples/slow030_table_access.txt"
   ),
   'Analysis for slow030 with --table-access'
);

ok(
   no_diff(
      sub { mk_query_digest::main(@args, $sample.'slow034.txt', qw(--order-by Lock_time:sum),
            '--report-format', 'query_report,profile') },
      "mk-query-digest/t/samples/slow034-order-by-Locktime-sum.txt"
   ),
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
my $output = `$trunk/mk-query-digest/mk-query-digest $trunk/common/t/samples/slow041.txt >/dev/null 2>/tmp/mqd-warnings.txt`;
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
