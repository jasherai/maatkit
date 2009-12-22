#!/usr/bin/env perl

use strict;
use warnings FATAL => 'all';
use English qw(-no_match_vars);
use Test::More tests => 11;

use constant MKDEBUG => $ENV{MKDEBUG};

require '../../common/MaatkitTest.pm';

MaatkitTest->import(qw(no_diff));

my $run_with = '../mk-query-digest --report-format=query_report --limit 10 ../../common/t/samples/';

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
# Done.
# #############################################################################
exit;
