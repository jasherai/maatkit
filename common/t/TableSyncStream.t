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

use Test::More tests => 4;
use English qw(-no_match_vars);

require "../TableSyncStream.pm";
require "../Quoter.pm";
require "../MockSth.pm";
require "../RowDiff.pm";
require "../ChangeHandler.pm";

sub throws_ok {
   my ( $code, $pat, $msg ) = @_;
   eval { $code->(); };
   like( $EVAL_ERROR, $pat, $msg );
}

my ($t);
my @rows;

throws_ok(
   sub { new TableSyncStream() },
   qr/I need a handler/,
   'ChangeHandler required'
);

my $ch = new ChangeHandler(
   quoter    => new Quoter(),
   database  => 'test',
   table     => 'foo',
   sdatabase => 'test',
   stable    => 'foo',
   replace   => 0,
   actions   => [ sub { push @rows, @_ }, ],
   queue     => 0,
);
$t = new TableSyncStream(
   handler => $ch,
   cols    => [qw(a b c)],
);

is($t->get_sql(
      quoter   => new Quoter(),
      where    => 'foo=1',
      database => 'test',
      table    => 'foo',
   ),
   'SELECT `a`, `b`, `c` FROM `test`.`foo` WHERE foo=1',
   'Got SQL OK',
);

is( $t->done, undef, 'Not done yet' );

my $d = new RowDiff( dbh => 1 );
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
   tbl    => {},
);

is_deeply(
   \@rows,
   [
   'INSERT INTO `test`.`foo`(`a`, `b`, `c`) VALUES (1, 2, 3)',
   'DELETE FROM `test`.`foo` WHERE `a`=4 AND `b`=2 AND `c`=3 LIMIT 1',
   ],
   'rows from handler',
);
