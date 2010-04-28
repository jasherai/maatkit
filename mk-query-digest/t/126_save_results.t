#!/usr/bin/env perl

BEGIN {
   die "The MAATKIT_TRUNK environment variable is not set.  See http://code.google.com/p/maatkit/wiki/Testing"
      unless $ENV{MAATKIT_TRUNK} && -d $ENV{MAATKIT_TRUNK};
   unshift @INC, "$ENV{MAATKIT_TRUNK}/common";
};

use strict;
use warnings FATAL => 'all';
use English qw(-no_match_vars);
use Test::More tests => 3;

use MaatkitTest;
shift @INC;  # our unshift (above)
shift @INC;  # MaatkitTest's unshift
require "$trunk/mk-query-digest/mk-query-digest";

my @args      = (qw(--no-report --no-gzip));
my $sample    = "$trunk/common/t/samples/";
my $ressample = "$trunk/mk-query-digest/t/samples/save-results/";
my $resdir    = "/tmp/mqd-res/";
my $diff      = "";

# Default results (95%).  From slow002 that's 1 query.
diag(`rm -rf $resdir ; mkdir $resdir`);
mk_query_digest::main(@args, '--save-results', "$resdir/r1",
   $sample.'slow002.txt');
ok(
   -f "$resdir/r1",
   "Saved results to file"
);

$diff = `diff $ressample/slow002.txt $resdir/r1 2>&1`;
is(
   $diff,
   '',
   "slow002.txt saved results"
);

# Change --limit to save more queries.
diag(`rm -rf $resdir/*`);
mk_query_digest::main(@args, '--save-results', "$resdir/r1",
   qw(--limit 3), $sample.'slow002.txt');
$diff = `diff $ressample/slow002-limit-3.txt $resdir/r1 2>&1`;
is(
   $diff,
   '',
   "slow002.txt --limit 3 saved results"
);

# #############################################################################
# Done.
# #############################################################################
diag(`rm -rf $resdir`);
exit;
