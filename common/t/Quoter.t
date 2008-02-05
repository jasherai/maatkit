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
use English qw(-no_match_vars);

require "../Quoter.pm";

my $q = new Quoter;

is(
   $q->quote('a'),
   '`a`',
   'Simple quote OK',
);

is(
   $q->quote('a','b'),
   '`a`.`b`',
   'multi value',
);

is(
   $q->quote('`a`'),
   '```a```',
   'already quoted',
);

is(
   $q->quote('a`b'),
   '`a``b`',
   'internal quote',
);

is( $q->quote_val(1), "1", 'number' );
is( $q->quote_val('001'), "'001'", 'number with leading zero' );
is( $q->quote_val(qw(1 2 3)), '1, 2, 3', 'three numbers');
is( $q->quote_val(qw(a)), "'a'", 'letter');
is( $q->quote_val("a'"), "'a\\''", 'letter with quotes');
is( $q->quote_val(undef), 'NULL', 'NULL');
is( $q->quote_val(''), "''", 'Empty string');
is( $q->quote_val('\\\''), "'\\\\\\\''", 'embedded backslash');
