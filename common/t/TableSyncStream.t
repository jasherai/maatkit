#!/usr/bin/perl

# This program is copyright (c) 2007 Baron Schwartz.
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

my $tests;
BEGIN {
   $tests = 4;
}

use Test::More tests => $tests;
use English qw(-no_match_vars);

require "../TableSyncStream.pm";
require "../Quoter.pm";
require "../MockSth.pm";
require "../RowDiff.pm";
require "../RowSyncer.pm";

sub throws_ok {
   my ( $code, $pat, $msg ) = @_;
   eval { $code->(); };
   like ( $EVAL_ERROR, $pat, $msg );
}

my ( $t );

throws_ok( sub { new TableSyncStream() }, qr/I need a rowsyncer/, 'RowSyncer required' );

my $rs = new RowSyncer();
$t = new TableSyncStream(
   rowsyncer => $rs,
);

is (
   $t->get_sql(
      quoter => new Quoter(),
      cols   => [qw(a b c)],
      where  => 'foo=1',
      database => 'test',
      table    => 'foo',
   ),
   'SELECT `a`, `b`, `c` FROM `test`.`foo` WHERE foo=1',
   'Got SQL OK',
);

isnt($t->done, 'Not done yet');

my $d = new RowDiff(dbh=>1);
$d->compare_sets(
   left => new MockSth(
      { a => 1, b => 2, c => 3 },
      { a => 2, b => 2, c => 3 },
      { a => 3, b => 2, c => 3 },
      # { a => 4, b => 2, c => 3 },
   ),
   right => new MockSth(
      # { a => 1, b => 2, c => 3 },
      { a => 2, b => 2, c => 3 },
      { a => 3, b => 2, c => 3 },
      { a => 4, b => 2, c => 3 },
   ),
   syncer => $t,
   tbl => {},
   key => [qw(a b c)],
);

is_deeply(
   $rs,
   {
      del => [
         { a => 4, b => 2, c => 3 },
      ],
      ins => [
         { a => 1, b => 2, c => 3 },
      ],
   },
   'differences in basic set of rows',
);
