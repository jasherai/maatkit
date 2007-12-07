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
   $tests = 10;
}

use Test::More tests => $tests;
use English qw(-no_match_vars);
use DBI;

require "../MySQLDump.pm";
require "../Quoter.pm";

# TODO: get_create_table() seems to return an arrayref sometimes!

my $q = new Quoter();

# Open a connection to MySQL, or skip the rest of the tests.
my $dbh;
eval {
   $dbh = DBI->connect(
   "DBI:mysql:;mysql_read_default_group=mysql", undef, undef,
   { PrintError => 0, RaiseError => 1 })
};
SKIP: {
   skip 'Cannot connect to MySQL', $tests if $EVAL_ERROR;

   skip "Can't find sakila database", $tests
      unless grep { m/sakila/ } @{$dbh->selectcol_arrayref('show databases')};

   my $d = new MySQLDump();

   my $dump = $d->dump($dbh, $q, 'sakila', 'film', 'table');
   like($dump, qr/language_id/, 'Dump sakila.film');

   $dump = $d->dump($dbh, $q, 'sakila', 'film', 'triggers');
   like($dump, qr/'root'\@'localhost'/, 'Triggers were defined by root');
   like($dump, qr/AFTER INSERT/, 'dump triggers');

   $dump = $d->dump($dbh, $q, 'sakila', 'customer_list', 'table');
   like($dump, qr/CREATE TABLE/, 'Temp table def for view/table');
   like($dump, qr/DROP TABLE/, 'Drop temp table def for view/table');
   like($dump, qr/DROP VIEW/, 'Drop view def for view/table');
   unlike($dump, qr/ALGORITHM/, 'No view def');

   $dump = $d->dump($dbh, $q, 'sakila', 'customer_list', 'view');
   like($dump, qr/DROP TABLE/, 'Drop temp table def for view');
   like($dump, qr/DROP VIEW/, 'Drop view def for view');
   like($dump, qr/ALGORITHM/, 'View def');
}
