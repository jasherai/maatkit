#!/usr/bin/env perl

use strict;
use warnings FATAL => 'all';
use English qw(-no_match_vars);
use Test::More tests => 1;

use constant MKDEBUG => $ENV{MKDEBUG};

require '../../common/MaatkitTest.pm';
MaatkitTest->import(qw(no_diff));

my $run_with = '../mk-query-digest --report-format=query_report --type http --limit 10 ../../common/t/samples/';

ok(
   no_diff($run_with.'http_tcpdump002.txt', 'samples/http_tcpdump002.txt'),
   'Analysis for http_tcpdump002.txt'
);

# #############################################################################
# Done.
# #############################################################################
exit;
