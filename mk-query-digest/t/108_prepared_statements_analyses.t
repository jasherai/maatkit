#!/usr/bin/env perl

BEGIN {
   die "The MAATKIT_WORKING_COPY environment variable is not set.  See http://code.google.com/p/maatkit/wiki/Testing"
      unless $ENV{MAATKIT_WORKING_COPY} && -d $ENV{MAATKIT_WORKING_COPY};
   unshift @INC, "$ENV{MAATKIT_WORKING_COPY}/common";
};

use strict;
use warnings FATAL => 'all';
use English qw(-no_match_vars);
use Test::More tests => 6;

use MaatkitTest;

# See 101_slowlog_analyses.t or http://code.google.com/p/maatkit/wiki/Testing
shift @INC;  # our unshift (above)
shift @INC;  # MaatkitTest's unshift

require "$trunk/mk-query-digest/mk-query-digest";

my @args   = qw(--type tcpdump --report-format=query_report --limit 10 --watch-server 127.0.0.1:12345);
my $sample = "$trunk/common/t/samples/tcpdump/";

# #############################################################################
# Issue 740: Handle prepared statements
# #############################################################################
ok(
   no_diff(
      sub { mk_query_digest::main(@args, $sample.'tcpdump021.txt') },
      "mk-query-digest/t/samples/tcpdump021.txt"
   ),
   'Analysis for tcpdump021 with prepared statements'
);
ok(
   no_diff(
      sub { mk_query_digest::main(@args, $sample.'tcpdump022.txt') },
      "mk-query-digest/t/samples/tcpdump022.txt"
   ),
   'Analysis for tcpdump022 with prepared statements'
);
ok(
   no_diff(
      sub { mk_query_digest::main(@args, $sample.'tcpdump023.txt') },
      "mk-query-digest/t/samples/tcpdump023.txt"
   ),
   'Analysis for tcpdump023 with prepared statements'
);
ok(
   no_diff(
      sub { mk_query_digest::main(@args, $sample.'tcpdump024.txt') },
      "mk-query-digest/t/samples/tcpdump024.txt"
   ),
   'Analysis for tcpdump024 with prepared statements'
);
ok(
   no_diff(
      sub { mk_query_digest::main(@args, $sample.'tcpdump025.txt') },
      "mk-query-digest/t/samples/tcpdump025.txt"
   ),
   'Analysis for tcpdump025 with prepared statements'
);
ok(
   no_diff(
      sub { mk_query_digest::main(@args, $sample.'tcpdump033.txt',
         '--report-format', 'header,query_report,profile,prepared') },
      "mk-query-digest/t/samples/tcpdump033.txt"
   ),
   'Analysis for tcpdump033 with prepared statements report'
);

# #############################################################################
# Done.
# #############################################################################
exit;
