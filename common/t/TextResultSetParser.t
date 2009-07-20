#!/usr/bin/perl

use strict;
use warnings FATAL => 'all';
use English qw(-no_match_vars);
use Test::More tests => 6;

require '../TextResultSetParser.pm';
require '../MaatkitTest.pm';

MaatkitTest->import(qw(load_file));

use Data::Dumper;
$Data::Dumper::Indent    = 1;
$Data::Dumper::Quotekeys = 0;

my $r = new TextResultSetParser();
isa_ok($r, 'TextResultSetParser');

is_deeply(
   $r->parse( load_file('samples/recset001.txt') ),
   [
      {
         Time     => '0',
         Command  => 'Query',
         db       => '',
         Id       => '9',
         Info     => 'show processlist',
         User     => 'msandbox',
         State    => '',
         Host     => 'localhost'
      },
   ],
   'Basic tablular processlist'
);

is_deeply(
   $r->parse( load_file('samples/recset002.txt') ),
   [
      {
         Time     => '4',
         Command  => 'Query',
         db       => 'foo',
         Id       => '1',
         Info     => 'select * from foo1;',
         User     => 'user1',
         State    => 'Locked',
         Host     => '1.2.3.4:3333'
      },
      {
         Time     => '5',
         Command  => 'Query',
         db       => 'foo',
         Id       => '2',
         Info     => 'select * from foo2;',
         User     => 'user1',
         State    => 'Locked',
         Host     => '1.2.3.4:5455'
      },
   ],
   '2 row vertical processlist'
);

my $recset = $r->parse ( load_file('samples/recset003.txt') );
cmp_ok(
   scalar @$recset,
   '==',
   113,
   '113 row vertical processlist'
);

$recset = $r->parse( load_file('samples/recset004.txt') );
cmp_ok(
   scalar @$recset,
   '==',
   51,
   '51 row vertical processlist'
);

is_deeply(
   $r->parse( load_file('samples/recset005.txt') ),
   [
      {
         Id    => '29392005',
         User  => 'remote',
         Host  => '1.2.3.148:49718',
         db    => 'happy',
         Command => 'Sleep',
         Time  => '17',
         State => undef,
         Info  => 'NULL',
      }
   ],
   '1 vertical row, No State value'
);

# #############################################################################
# Done.
# #############################################################################
exit;
