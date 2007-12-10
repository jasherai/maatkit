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

use Test::More tests => 9;
use English qw(-no_match_vars);

require "../QueryNormalizer.pm";

my $q = new QueryNormalizer();

is(
   $q->norm('SELECT * from foo where a = 5'),
   'select * from foo where a = N',
   'Lowercases, replaces integer',
);

is(
   $q->norm('select * from foo where a = 5.5 or b=0.5 or c=.5 or d=0xdeadbeef'),
   'select * from foo where a = N or b=N or c=N or d=N',
   'Floats and hex',
);

is(
   $q->norm(" select  * from\nfoo where a = 5"),
   'select * from foo where a = N',
   'Collapses whitespace',
);
