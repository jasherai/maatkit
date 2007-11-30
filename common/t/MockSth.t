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
   $tests = 6;
}

use Test::More tests => $tests;
use English qw(-no_match_vars);
use DBI;

require "../MockSth.pm";

sub throws_ok {
   my ( $code, $pat, $msg ) = @_;
   eval { $code->(); };
   like ( $EVAL_ERROR, $pat, $msg );
}

my $m;

$m = new MockSth();

isnt($m->{Active}, 'Empty is not active');
is(undef, $m->fetchrow_hashref(), 'Cannot fetch from empty');

$m = new MockSth(
   { a => 1 },
);
ok($m->{Active}, 'Has rows, is active');
is_deeply($m->fetchrow_hashref(), { a => 1 }, 'Got the row');
isnt($m->{Active}, 'not active after fetching');
is(undef, $m->fetchrow_hashref(), 'Cannot fetch from empty');
