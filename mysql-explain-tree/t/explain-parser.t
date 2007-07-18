#!/usr/bin/perl

use strict;
use warnings FATAL => 'all';

use Test::More tests => 1;

require "../mysql-explain-tree";

# Test that I can load 'explain' files and get an array of hashrefs from them.
my $p = new ExplainParser;
is_deeply(
    $p->parse( load_file('samples/full_scan_sakila_film.sql') ),
    [{
        id            => 1,
        select_type   => 'SIMPLE',
        table         => 'film',
        type          => 'ALL',
        possible_keys => undef,
        key           => undef,
        key_len       => undef,
        'ref'         => undef,
        rows          => 935,
        Extra         => '',
    }],
    'Loaded and parsed file correctly'
);

sub load_file {
    my ($file) = @_;
    open my $fh, "<", $file or die $!;
    my $contents = do { local $/ = undef; <$fh> };
    close $fh;
    return $contents;
}
