#!/usr/bin/perl

BEGIN {
   die "The MAATKIT_TRUNK environment variable is not set.  See http://code.google.com/p/maatkit/wiki/Testing"
      unless $ENV{MAATKIT_TRUNK} && -d $ENV{MAATKIT_TRUNK};
   unshift @INC, "$ENV{MAATKIT_TRUNK}/common";
};

use strict;
use warnings FATAL => 'all';
use English qw(-no_match_vars);
use Test::More tests => 1;

use MaatkitTest;
use PodParser;

use Data::Dumper;
$Data::Dumper::Indent    = 1;
$Data::Dumper::Sortkeys  = 1;
$Data::Dumper::Quotekeys = 0;

my $p = new PodParser();

$p->parse_from_file("$trunk/common/t/samples/pod/pod_sample_mqa.txt");

is_deeply(
   $p->get_items(),
   {
      OPTIONS => {
         define => {
            desc => 'Define these check IDs.  If L<"--verbose"> is zero (i.e. not specified) then a terse definition is given.  If one then a fuller definition is given.  If two then the complete definition is given.',
            type => 'array',
         },
         'ignore-checks' => {
            desc => 'Ignore these L<"CHECKS">.',
            type => 'array',
         },
         verbose => {
            cumulative => 1,
            default    => '0',
            desc       => 'Print more information.',
         },
      },
   },
   'Parse pod_sample_mqa.txt'
);

# #############################################################################
# Done.
# #############################################################################
exit;
