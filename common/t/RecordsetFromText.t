#!/usr/bin/perl

# This program is copyright 2008 Percona Inc.
# Feedback and improvements are welcome.
#
# THIS PROGRAM IS PROVIDED "AS IS" AND WITHOUT ANY EXPRESS OR IMPLIED
# WARRANTIES, INCLUDING, WITHOUT LIMITATION, THE IMPLIED WARRANTIES OF
# MERCHANTIBILITY AND FITNESS FOR A PARTICULAR PURPOSE.
#
# This program is free software; you can redistribute it and/or modify it under
# the terms of the GNU General Public License as published by the Free Software
# Foundation, version 2; OR the Perl Artistic License.  On UNIX and similar
# systems, you can issue `man perlgpl' or `man perlartistic' to read these
# licenses.
#
# You should have received a copy of the GNU General Public License along with
# this program; if not, write to the Free Software Foundation, Inc., 59 Temple
# Place, Suite 330, Boston, MA  02111-1307  USA.

use strict;
use warnings FATAL => 'all';

use Test::More tests => 4;
use English qw(-no_match_vars);

use DBI;

require '../RecordsetFromText.pm';

use Data::Dumper;
$Data::Dumper::Indent    = 1;
$Data::Dumper::Quotekeys = 0;

sub load_file {
   my ($file) = @_;
   open my $fh, "<", $file or die $!;
   my $contents = do { local $/ = undef; <$fh> };
   close $fh;
   return $contents;
}

# my $params = {
#   value_for => {
#      0 => undef,
#   },
# };
my $r = RecordsetFromText->new();
isa_ok($r, 'RecordsetFromText');

my $recset = $r->parse( load_file('samples/RecsetFromTxt-proclist_basic.txt') );
is_deeply(
   $recset,
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

$recset = $r->parse( load_file('samples/RecsetFromTxt-proclist_vertical_02_rows.txt') );
is_deeply(
   $recset,
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

$recset = $r->parse( load_file('samples/RecsetFromTxt-proclist_vertical_51_rows.txt') );
cmp_ok(scalar @{ $recset }, '==', 51, '51 row vertical processlist');

# print Dumper($recset);

exit;
