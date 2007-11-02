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

use Test::More tests => 2;
use English qw(-no_match_vars);

require "../MySQLFind.pm";

my @found;
sub callback {
   my ( $item ) = @_;
   push @found, $item;
}

MySQLFind::_db_filter (
   dbs   => [qw( foo bar )],
   tests => {},
   code  => \&callback,
);
is_deeply(
   [ @found ],
   [
      {type => 'database', name => 'foo'},
      {type => 'database', name => 'bar'},
   ],
   'List of dbs',
);

@found = ();
MySQLFind::_db_filter (
   dbs   => [qw( foo bar INFORMATION_SCHEMA lost+found )],
   tests => {},
   code  => \&callback,
);
is_deeply(
   [ @found ],
   [
      {type => 'database', name => 'foo'},
      {type => 'database', name => 'bar'},
   ],
   'List of dbs skipping I_S and lost+found',
);

# verify that information_schema|lost\+found are skipped
# apply LIKE
# apply dbregex
# apply list-o-databases
# apply ignore-these-dbs

# Find a list of tables
# apply LIKE
# apply tblregex
# apply list-o-tables
# apply ignore-these-tables
# skip views
# apply list-o-engines
# apply ignore-these-engines
