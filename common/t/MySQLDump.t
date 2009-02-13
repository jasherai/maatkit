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

use Test::More tests => 10;
use English qw(-no_match_vars);

require "../MySQLDump.pm";
require "../Quoter.pm";
require '../DSNParser.pm';
require '../Sandbox.pm';
my $dp = new DSNParser();
my $sb = new Sandbox(basedir => '/tmp', DSNParser => $dp);

my $dbh = $sb->get_dbh_for('master')
   or BAIL_OUT('Cannot connect to sandbox master');

my $du = new MySQLDump();
my $q  = new Quoter();

my $dump;

use Data::Dumper;
$Data::Dumper::Indent=1;

# TODO: get_create_table() seems to return an arrayref sometimes!

SKIP: {
   skip 'Sandbox master does not have the sakila database', 10
      unless @{$dbh->selectcol_arrayref('SHOW DATABASES LIKE "sakila"')};

   $dump = $du->dump($dbh, $q, 'sakila', 'film', 'table');
   like($dump, qr/language_id/, 'Dump sakila.film');

   $dump = $du->dump($dbh, $q, 'mysql', 'film', 'triggers');
   ok(!defined $dump, 'no triggers in mysql');

   $dump = $du->dump($dbh, $q, 'sakila', 'film', 'triggers');
   like($dump, qr/AFTER INSERT/, 'dump triggers');

   $dump = $du->dump($dbh, $q, 'sakila', 'customer_list', 'table');
   like($dump, qr/CREATE TABLE/, 'Temp table def for view/table');
   like($dump, qr/DROP TABLE/, 'Drop temp table def for view/table');
   like($dump, qr/DROP VIEW/, 'Drop view def for view/table');
   unlike($dump, qr/ALGORITHM/, 'No view def');

   $dump = $du->dump($dbh, $q, 'sakila', 'customer_list', 'view');
   like($dump, qr/DROP TABLE/, 'Drop temp table def for view');
   like($dump, qr/DROP VIEW/, 'Drop view def for view');
   like($dump, qr/ALGORITHM/, 'View def');
}

$sb->wipe_clean($dbh);
exit;
