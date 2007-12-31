#!/usr/bin/perl

use strict;
use warnings FATAL => 'all';

use English qw('-no_match_vars);
use Test::More tests => 4;

my $output = `perl ../mk-parallel-restore foo --test`;
like(
   $output,
   qr{mysql foo < '.*?foo/bar.sql'},
   'Found the file',
);
like(
   $output,
   qr{1 tables,\s+1 files,\s+1 successes},
   'Counted the work to be done',
);

$output = `perl ../mk-parallel-restore -n bar foo --test`;
unlike( $output, qr/bar/, '--ignoretbl filtered out bar');

$output = `perl ../mk-parallel-restore -n foo.bar foo --test`;
unlike( $output, qr/bar/, '--ignoretbl filtered out bar again');
