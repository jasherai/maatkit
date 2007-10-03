#!/usr/bin/perl

use strict;
use warnings FATAL => 'all';

use Test::More tests => 1;
use English qw(-no_match_vars);

require "../TableParser.pm";

my $p = new TableParser();
my $t;

sub load_file {
   my ($file) = @_;
   open my $fh, "<", $file or die $!;
   my $contents = do { local $/ = undef; <$fh> };
   close $fh;
   return $contents;
}

$t = $p->parse( load_file('samples/t1.sql') );
is_deeply(
   $t,
   {  cols         => [qw(a)],
      is_col       => { a => 1 },
      null_cols    => [qw(a)],
      is_nullable  => { a => 1 },
      keys         => {},
      defs         => { a => '  `a` int(11) default NULL' },
      numeric_cols => [qw(a)],
      is_numeric   => { a => 1 },
   },
   'Basic table is OK',
);
