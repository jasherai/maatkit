#!/usr/bin/env perl

BEGIN {
   die "The MAATKIT_TRUNK environment variable is not set.  See http://code.google.com/p/maatkit/wiki/Testing"
      unless $ENV{MAATKIT_TRUNK} && -d $ENV{MAATKIT_TRUNK};
   unshift @INC, "$ENV{MAATKIT_TRUNK}/common";
};

use strict;
use warnings FATAL => 'all';
use English qw(-no_match_vars);
use Test::More tests => 6;

$ENV{LABEL_WIDTH} = 9;  

use MaatkitTest;

my $run_with = "$trunk/mk-query-digest/mk-query-digest --report-format=query_report --limit 10 $trunk/common/t/samples/";

# #############################################################################
# Issue 740: Handle prepared statements
# #############################################################################
ok(
   no_diff($run_with.'tcpdump021.txt --type tcpdump --watch-server 127.0.0.1:12345', "mk-query-digest/t/samples/tcpdump021.txt"),
   'Analysis for tcpdump021 with prepared statements'
);
ok(
   no_diff($run_with.'tcpdump022.txt --type tcpdump --watch-server 127.0.0.1:12345', "mk-query-digest/t/samples/tcpdump022.txt"),
   'Analysis for tcpdump022 with prepared statements'
);
ok(
   no_diff($run_with.'tcpdump023.txt --type tcpdump --watch-server 127.0.0.1:12345', "mk-query-digest/t/samples/tcpdump023.txt"),
   'Analysis for tcpdump023 with prepared statements'
);
ok(
   no_diff($run_with.'tcpdump024.txt --type tcpdump --watch-server 127.0.0.1:12345', "mk-query-digest/t/samples/tcpdump024.txt"),
   'Analysis for tcpdump024 with prepared statements'
);
ok(
   no_diff($run_with.'tcpdump025.txt --type tcpdump --watch-server 127.0.0.1:12345', "mk-query-digest/t/samples/tcpdump025.txt"),
   'Analysis for tcpdump025 with prepared statements'
);
ok(
   no_diff($run_with.'tcpdump033.txt --report-format header,query_report,profile,prepared --type tcpdump --watch-server 127.0.0.1:12345', "mk-query-digest/t/samples/tcpdump033.txt"),
   'Analysis for tcpdump033 with prepared statements report'
);

# #############################################################################
# Done.
# #############################################################################
exit;
