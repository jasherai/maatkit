#!/usr/bin/perl

use strict;
use warnings FATAL => 'all';

use Test::More tests => 1;

require "../mysql-visual-explain";

sub load_file {
   my ($file) = @_;
   open my $fh, "<", $file or die $!;
   my $contents = do { local $/ = undef; <$fh> };
   close $fh;
   return $contents;
}
my $e = new ExplainTree;
my $t;
my $o;

$t = $e->parse( load_file('samples/dependent_subquery.sql') );
$o = load_file('samples/dependent_subquery.txt');
is_deeply(
   $e->pretty_print($t),
   $o,
   'Output formats correctly',
);
