#!/usr/bin/env perl

BEGIN {
   die "The MAATKIT_WORKING_COPY environment variable is not set.  See http://code.google.com/p/maatkit/wiki/Testing"
      unless $ENV{MAATKIT_WORKING_COPY} && -d $ENV{MAATKIT_WORKING_COPY};
   unshift @INC, "$ENV{MAATKIT_WORKING_COPY}/common";
};

use strict;
use warnings FATAL => 'all';
use English qw(-no_match_vars);
use Test::More tests => 1;

use MaatkitTest;
require "$trunk/mk-visual-explain/mk-visual-explain";

my $e = new ExplainTree;
my $t;
my $o;

$t = $e->parse( load_file('mk-visual-explain/t/samples/dependent_subquery.sql') );
$o = load_file('mk-visual-explain/t/samples/dependent_subquery.txt');
is_deeply(
   $e->pretty_print($t),
   $o,
   'Output formats correctly',
);


# #############################################################################
# Done.
# #############################################################################
exit;
