#!/usr/bin/env perl

BEGIN {
   die "The MAATKIT_WORKING_COPY environment variable is not set.  See http://code.google.com/p/maatkit/wiki/Testing"
      unless $ENV{MAATKIT_WORKING_COPY} && -d $ENV{MAATKIT_WORKING_COPY};
   unshift @INC, "$ENV{MAATKIT_WORKING_COPY}/common";
};

use strict;
use warnings FATAL => 'all';
use English qw(-no_match_vars);
use Test::More tests => 9;

use MaatkitTest;

my ($output, $output2);
my $cmd = "$trunk/mk-table-checksum/mk-checksum-filter";

$output = `$cmd $trunk/mk-table-checksum/t/samples/sample_1`;
chomp $output;
is($output, '', 'No output from single file');
is($CHILD_ERROR >> 8, 0, 'Exit status is 0');

$output = `$cmd $trunk/mk-table-checksum/t/samples/sample_1 --equal-databases sakila,sakila2`;
chomp $output;
like($output, qr/sakila2.*actor/, 'sakila2.actor is different with --equal-databases');
is($CHILD_ERROR >> 8, 1, 'Exit status is 1');

$output = `$cmd $trunk/mk-table-checksum/t/samples/sample_1 --ignore-databases`;
chomp $output;
like($output, qr/sakila2.*actor/, 'sakila2.actor is different with --ignore-databases');
is($CHILD_ERROR >> 8, 1, 'Exit status is 1');

$output = `$cmd $trunk/mk-table-checksum/t/samples/sample_2 --unique host`;
chomp $output;
is($output, "127.0.0.1\nlocalhost", "Unique hostnames differ");

$output = `$cmd $trunk/mk-table-checksum/t/samples/sample_2 --unique db`;
chomp $output;
is($output, "sakila", "Unique dbs differ");

$output = `$cmd $trunk/mk-table-checksum/t/samples/sample_2 --unique table`;
chomp $output;
is($output, "actor", "Unique tables differ");

exit;
