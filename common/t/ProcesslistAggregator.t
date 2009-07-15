#!/usr/bin/perl

use strict;
use warnings FATAL => 'all';
use English qw(-no_match_vars);
use Test::More tests => 5;

require '../ProcesslistAggregator.pm';
require '../TextResultSetParser.pm';
require '../DSNParser.pm';
require '../MySQLDump.pm';
require '../Quoter.pm';
require '../TableParser.pm';

use Data::Dumper;
$Data::Dumper::Indent    = 1;
$Data::Dumper::Quotekeys = 0;

my $r   = new TextResultSetParser();
my $apl = new ProcesslistAggregator();

isa_ok($apl, 'ProcesslistAggregator');

sub load_file {
   my ($file) = @_;
   open my $fh, "<", $file or die $!;
   my $contents = do { local $/ = undef; <$fh> };
   close $fh;
   return $contents;
}

sub test_aggregate {
   my ($file, $expected, $msg) = @_;
   my $proclist = $r->parse( load_file($file) );
   is_deeply(
      $apl->aggregate($proclist),
      $expected,
      $msg
   );
   return;
}

test_aggregate(
   'samples/recset001.txt',
   {
      command => { query     => { time => 0, count => 1 } },
      db      => { ''        => { time => 0, count => 1 } },
      user    => { msandbox  => { time => 0, count => 1 } },
      state   => { ''        => { time => 0, count => 1 } },
      host    => { localhost => { time => 0, count => 1 } },
   },
   'Aggregate basic processlist'
);

test_aggregate(
   'samples/recset004.txt',
   {
      db => {
         NULL   => { count => 1,  time => 0 },
         forest => { count => 50, time => 529 }
      },
      user => {
         user1 => { count => 50, time => 529 },
         root  => { count => 1,  time => 0 }
      },
      host => {
         '0.1.2.11' => { count => 21, time => 183 },
         '0.1.2.12' => { count => 25, time => 331 },
         '0.1.2.21' => { count => 4,  time => 15 },
         localhost  => { count => 1,  time => 0 }
      },
      state => {
         locked    => { count => 24, time => 84 },
         preparing => { count => 26, time => 445 },
         null      => { count => 1,  time => 0 }
      },
      command => { query => { count => 51, time => 529 } }
   },
   'Sample with 51 processes',
);

my $aggregate = $apl->aggregate($r->parse(load_file('samples/recset003.txt')));
cmp_ok(
   $aggregate->{db}->{NULL}->{count},
   '==',
   3,
   '113 proc sample: 3 NULL db'
);
cmp_ok(
   $aggregate->{db}->{happy}->{count},
   '==',
   110,
   '113 proc sample: 110 happy db'
);

exit;
