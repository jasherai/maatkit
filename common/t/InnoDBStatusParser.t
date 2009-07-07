#!/usr/bin/perl

use strict;
use warnings FATAL => 'all';
use English qw(-no_match_vars);
use Test::More tests => 1;

require "../InnoDBStatusParser.pm";

sub load_file {
   my ($file) = @_;
   open my $fh, "<", $file or die $!;
   my $contents = do { local $/ = undef; <$fh> };
   close $fh;
   return $contents;
};

my $is = new InnoDBStatusParser();
isa_ok($is, 'InnoDBStatusParser');


# #############################################################################
# Done.
# #############################################################################
exit;
