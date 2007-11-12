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

use Test::More tests => 12;
use DBI;
use English qw(-no_match_vars);

require "../TableChecksum.pm";
require "../VersionParser.pm";

my $c = new TableChecksum();
my $vp = new VersionParser();

sub load_file {
   my ($file) = @_;
   open my $fh, "<", $file or die $!;
   my $contents = do { local $/ = undef; <$fh> };
   close $fh;
   return $contents;
}

sub throws_ok {
   my ( $code, $re, $msg ) = @_;
   eval { $code->(); };
   like ( $EVAL_ERROR, $re, $msg );
}

throws_ok (
   sub { $c->best_algorithm( algorithm => 'foo', ) },
   qr/Invalid checksum algorithm/,
   'Algorithm=foo',
);

# Inject the VersionParser with some bogus versions.  Later I'll just pass the
# string version number instead of a real DBH, so the version parsing will
# return the value I want.
foreach my $ver( qw(4.0.0 4.1.1) ) {
   $vp->{$ver} = $vp->parse($ver);
}

is (
   $c->best_algorithm(
      algorithm => 'CHECKSUM',
      vp        => $vp,
      dbh       => '4.1.1',
   ),
   'CHECKSUM',
   'Prefers CHECKSUM',
);

is (
   $c->best_algorithm(
      vp        => $vp,
      dbh       => '4.1.1',
   ),
   'CHECKSUM',
   'Default is CHECKSUM',
);

is (
   $c->best_algorithm(
      algorithm => 'CHECKSUM',
      vp        => $vp,
      dbh       => '4.1.1',
      where     => 1,
   ),
   'ACCUM',
   'CHECKSUM eliminated by where',
);

is (
   $c->best_algorithm(
      algorithm => 'CHECKSUM',
      vp        => $vp,
      dbh       => '4.1.1',
      chunk     => 1,
   ),
   'ACCUM',
   'CHECKSUM eliminated by chunk',
);

is (
   $c->best_algorithm(
      algorithm => 'CHECKSUM',
      vp        => $vp,
      dbh       => '4.1.1',
      replicate => 1,
   ),
   'ACCUM',
   'CHECKSUM eliminated by replicate',
);

is (
   $c->best_algorithm(
      vp        => $vp,
      dbh       => '4.1.1',
      count     => 1,
   ),
   'ACCUM',
   'Default CHECKSUM eliminated by count',
);

is (
   $c->best_algorithm(
      algorithm => 'CHECKSUM',
      vp        => $vp,
      dbh       => '4.1.1',
      count     => 1,
   ),
   'CHECKSUM',
   'Explicit CHECKSUM not eliminated by count',
);

is (
   $c->best_algorithm(
      algorithm => 'CHECKSUM',
      vp        => $vp,
      dbh       => '4.0.0',
   ),
   'ACCUM',
   'CHECKSUM eliminated by version',
);

is (
   $c->best_algorithm(
      algorithm => 'BIT_XOR',
      vp        => $vp,
      dbh       => '4.1.1',
   ),
   'BIT_XOR',
   'BIT_XOR as requested',
);

is (
   $c->best_algorithm(
      algorithm => 'BIT_XOR',
      vp        => $vp,
      dbh       => '4.0.0',
   ),
   'ACCUM',
   'BIT_XOR eliminated by version',
);

is (
   $c->best_algorithm(
      algorithm => 'ACCUM',
      vp        => $vp,
      dbh       => '4.1.1',
   ),
   'ACCUM',
   'ACCUM as requested',
);
