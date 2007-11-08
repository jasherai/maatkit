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
   $tests = 3;
}

use Test::More tests => $tests;
use English qw(-no_match_vars);
use DBI;

require "../MySQLDump.pm";
require "../Quoter.pm";

my $q = new Quoter();

# Open a connection to MySQL, or skip the rest of the tests.
my $dbh;
eval {
   $dbh = DBI->connect(
   "DBI:mysql:;mysql_read_default_group=mysql", undef, undef,
   { PrintError => 0, RaiseError => 1 })
};
SKIP: {
   skip $EVAL_ERROR, $tests if $EVAL_ERROR;

   skip "Can't find sakila database", $tests
      unless grep { m/sakila/ } @{$dbh->selectcol_arrayref('show databases')};

   my $d = new MySQLDump();

   my $dump = $d->dump($dbh, $q, 'sakila', 'film', 'table');
   like($dump, qr/language_id/, 'Dump sakila.film');

   $dump = $d->dump($dbh, $q, 'sakila', 'film', 'triggers');
   like($dump, qr/'root'\@'localhost'/, 'Triggers were defined by root');
   like($dump, qr/AFTER INSERT/, 'dump triggers');
}
