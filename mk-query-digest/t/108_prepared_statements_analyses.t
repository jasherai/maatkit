#!/usr/bin/env perl

use strict;
use warnings FATAL => 'all';
use English qw(-no_match_vars);
use Test::More tests => 6;

use constant MKDEBUG => $ENV{MKDEBUG};

require '../../common/MaatkitTest.pm';
MaatkitTest->import(qw(no_diff));

my $run_with = '../mk-query-digest --report-format=query_report --limit 10 ../../common/t/samples/';

# #############################################################################
# Issue 740: Handle prepared statements
# #############################################################################
ok(
   no_diff($run_with.'tcpdump021.txt --type tcpdump --watch-server 127.0.0.1:12345', 'samples/tcpdump021.txt'),
   'Analysis for tcpdump021 with prepared statements'
);
ok(
   no_diff($run_with.'tcpdump022.txt --type tcpdump --watch-server 127.0.0.1:12345', 'samples/tcpdump022.txt'),
   'Analysis for tcpdump022 with prepared statements'
);
ok(
   no_diff($run_with.'tcpdump023.txt --type tcpdump --watch-server 127.0.0.1:12345', 'samples/tcpdump023.txt'),
   'Analysis for tcpdump023 with prepared statements'
);
ok(
   no_diff($run_with.'tcpdump024.txt --type tcpdump --watch-server 127.0.0.1:12345', 'samples/tcpdump024.txt'),
   'Analysis for tcpdump024 with prepared statements'
);
ok(
   no_diff($run_with.'tcpdump025.txt --type tcpdump --watch-server 127.0.0.1:12345', 'samples/tcpdump025.txt'),
   'Analysis for tcpdump025 with prepared statements'
);
ok(
   no_diff($run_with.'tcpdump033.txt --report-format header,query_report,profile,prepared --type tcpdump --watch-server 127.0.0.1:12345', 'samples/tcpdump033.txt'),
   'Analysis for tcpdump033 with prepared statements report'
);

# #############################################################################
# Done.
# #############################################################################
exit;
