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

use Test::More tests => 2;
use English qw(-no_match_vars);

use DBI;

require '../AggregateProcessList.pm';
require '../RecordsetFromText.pm';
require '../DSNParser.pm';
require '../MySQLDump.pm';
require '../Quoter.pm';
require '../TableParser.pm';

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

my $apl = AggregateProcessList->new();
isa_ok($apl, 'AggregateProcessList');

my $r = RecordsetFromText->new();
my $recset = $r->parse( load_file('samples/RecsetFromTxt-proclist_basic.txt') );
is_deeply(
   $apl->aggregate_processlist($recset),
   {
      Command => { Query     => { Time => 0, Count => 1 } },
      db      => { ''        => { Time => 0, Count => 1 } },
      User    => { msandbox  => { Time => 0, Count => 1 } },
      State   => { ''        => { Time => 0, Count => 1 } },
      Host    => { localhost => { Time => 0, Count => 1 } },
   },
   'Aggregate basic processlist'
);

# print Dumper($apl);

exit;
