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

use Test::More tests => 8;
use English qw(-no_match_vars);

require "../QueryRewriter.pm";

my $q = new QueryRewriter();

is(
   $q->norm('SELECT * from foo where a = 5'),
   'select * from foo where a = N',
   'Lowercases, replaces integer',
);

is(
   $q->norm('select 0e0, +6e-30, -6.00 from foo where a = 5.5 or b=0.5 or c=.5'),
   'select N, N, N from foo where a = N or b=N or c=N',
   'Floats',
);

is(
   $q->norm("select 0x0, x'123', 0b1010, b'10101' from foo"),
   'select N, N, N, N from foo',
   'Hex/bit',
);

is(
   $q->norm(" select  * from\nfoo where a = 5"),
   'select * from foo where a = N',
   'Collapses whitespace',
);

is(
   $q->norm("select * from foo where a in (5) and b in (5, 8,9 ,9 , 10)"),
   'select * from foo where a in (N) and b in(N+)',
   'IN lists',
);

is(
   $q->norm("select foo_1 from foo_2_3"),
   'select foo_N from foo_N_N',
   'Numeric table names',
);

is(
   $q->norm("insert into abtemp.coxed select foo.bar from foo"),
   'insert into abtemp.coxed select foo.bar from foo',
   'A string that needs no changes',
);

is(
   $q->norm('insert into foo(a, b, c) values(2, 4, 5)'),
   'insert into foo(a, b, c) values(N+)',
   'VALUES lists',
);
