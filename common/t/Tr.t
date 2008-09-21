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

use Test::More tests => 5;
use English qw(-no_match_vars);

BEGIN {
   require '../Tr.pm';
   Tr->import( qw(micro_t shorten) );
};

my $WIN = ($^O eq 'MSWin32' ? 1 : 0);
my $u   = chr(($WIN ? 230 : 181));

is(micro_t('0.000001'), "1 $u", 'Formats 1 microsecond');
is(micro_t('0.001000'), '1 ms', 'Formats 1 milliseconds');
is(micro_t('1.000000'), '1 s',  'Formats 1 second');

is(shorten('1024.00'), '1.00k', 'Shortens 1024.00 to 1.00k');
is(shorten('100'),     '100',   'Keeps 100 as 100');

exit;
