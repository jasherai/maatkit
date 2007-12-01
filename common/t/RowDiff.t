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

# A package to mock up a syncer
package MockSync;

sub new {
   return bless [], shift;
}

sub same_row {
   my ( $self, $lr, $rr ) = @_;
   push @$self, 'same';
}

sub not_in_right {
   my ( $self, $lr ) = @_;
   push @$self, [ 'not in right', $lr];
}

sub not_in_left {
   my ( $self, $rr ) = @_;
   push @$self, [ 'not in left', $rr];
}

sub done_with_rows {
   my ( $self ) = @_;
   push @$self, 'done';
}

sub key_cols {
   return [qw(a)];
}

package main;

my $tests;
BEGIN {
   $tests = 18;
}

use Test::More tests => $tests;
use English qw(-no_match_vars);
use DBI;

require "../RowDiff.pm";
require "../MockSth.pm";

sub throws_ok {
   my ( $code, $pat, $msg ) = @_;
   eval { $code->(); };
   like ( $EVAL_ERROR, $pat, $msg );
}

my ( $d, $s );

throws_ok( sub { new RowDiff() }, qr/I need a dbh/, 'DBH required' );
$d = new RowDiff(dbh => 1);

is(
   $d->key_cmp( { a => 1 }, { a => 1 }, [qw(a)], {},),
   0,
   'Equal keys',
);

is(
   $d->key_cmp( undef, { a => 1 }, [qw(a)], {},),
   -1,
   'Left key missing',
);

is(
   $d->key_cmp( { a => 1 }, undef, [qw(a)], {},),
   1,
   'Right key missing',
);

is(
   $d->key_cmp( { a => 2 }, { a => 1 }, [qw(a)], {},),
   1,
   'Right key smaller',
);

is(
   $d->key_cmp( { a => 2 }, { a => 3 }, [qw(a)], {},),
   -1,
   'Right key larger',
);

is(
   $d->key_cmp( { a => 1, b => 2, }, { a => 1, b => 1 }, [qw(a b)], {},),
   1,
   'Right two-part key smaller',
);

is(
   $d->key_cmp( { a => 1, b => 0, }, { a => 1, b => 1 }, [qw(a b)], {},),
   -1,
   'Right two-part key larger',
);

is(
   $d->key_cmp( { a => 1, b => undef, }, { a => 1, b => 1 }, [qw(a b)], {},),
   -1,
   'Right two-part key larger because of null',
);

is(
   $d->key_cmp( { a => 1, b => 0, }, { a => 1, b => undef }, [qw(a b)], {},),
   1,
   'Left two-part key larger because of null',
);

is(
   $d->key_cmp( { a => 1, b => 0, }, { a => undef, b => 1 }, [qw(a b)], {},),
   1,
   'Left two-part key larger because of null in first key part',
);

$s = new MockSync();
$d->compare_sets(
   left => new MockSth(
   ),
   right => new MockSth(
   ),
   syncer => $s,
   tbl => {},
);
is_deeply(
   $s,
   [
      'done',
   ],
   'no rows',
);

$s = new MockSync();
$d->compare_sets(
   left => new MockSth(
   ),
   right => new MockSth(
      { a => 1, b => 2, c => 3 },
   ),
   syncer => $s,
   tbl => {},
);
is_deeply(
   $s,
   [
      [ 'not in left', { a => 1, b => 2, c => 3 },],
      'done',
   ],
   'right only',
);

$s = new MockSync();
$d->compare_sets(
   left => new MockSth(
      { a => 1, b => 2, c => 3 },
   ),
   right => new MockSth(
   ),
   syncer => $s,
   tbl => {},
);
is_deeply(
   $s,
   [
      [ 'not in right', { a => 1, b => 2, c => 3 },],
      'done',
   ],
   'left only',
);

$s = new MockSync();
$d->compare_sets(
   left => new MockSth(
      { a => 1, b => 2, c => 3 },
   ),
   right => new MockSth(
      { a => 1, b => 2, c => 3 },
   ),
   syncer => $s,
   tbl => {},
);
is_deeply(
   $s,
   [
      'same',
      'done',
   ],
   'one identical row',
);

$s = new MockSync();
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
   syncer => $s,
   tbl => {},
);
is_deeply(
   $s,
   [
      [ 'not in right',  { a => 1, b => 2, c => 3 }, ],
      'same',
      'same',
      [ 'not in left', { a => 4, b => 2, c => 3 }, ],
      'done',
   ],
   'differences in basic set of rows',
);

$s = new MockSync();
$d->compare_sets(
   left => new MockSth(
      { a => 1, b => 2, c => 3 },
   ),
   right => new MockSth(
      { a => 1, b => 2, c => 3 },
   ),
   syncer => $s,
   tbl => { is_numeric => { a => 1 } },
);
is_deeply(
   $s,
   [
      'same',
      'done',
   ],
   'Identical with numeric columns',
);

# Open a connection to MySQL, or skip the rest of the tests.
my $dbh;
eval {
   $dbh = DBI->connect(
   "DBI:mysql:;mysql_read_default_group=mysql", undef, undef,
   { PrintError => 0, RaiseError => 1 })
};
SKIP: {
   skip 'Cannot connect to MySQL', 1 if $EVAL_ERROR;

   $d = new RowDiff(dbh => $dbh);
   $s = new MockSync();
   $d->compare_sets(
      left => new MockSth(
         { a => 'A', b => 2, c => 3 },
      ),
      right => new MockSth(
         # The difference is the lowercase 'a', which in a _ci collation will
         # sort the same.  So the rows are really identical, from MySQL's point
         # of view.
         { a => 'a', b => 2, c => 3 },
      ),
      syncer => $s,
      tbl => { collation_for => { a => 'utf8_general_ci' } },
   );
   is_deeply(
      $s,
      [
         'same',
         'done',
      ],
      'Identical with utf8 columns',
   );
};
