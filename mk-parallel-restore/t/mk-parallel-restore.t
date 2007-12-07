#!/usr/bin/perl

use strict;
use warnings FATAL => 'all';

use English qw('no_match_vars);
use Test::More tests => 2;

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
