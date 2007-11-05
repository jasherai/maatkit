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

use Test::More tests => 17;
use English qw(-no_match_vars);
use DBI;

require "../MySQLFind.pm";
my $f;
my %dbs;
my @setup_dbs = qw(lost+found information_schema
   test_mysql_finder_1 test_mysql_finder_2);
my %existing_dbs;

# Open a connection to MySQL, or skip the rest of the tests.
my $dbh;
eval {
   $dbh = DBI->connect(
   "DBI:mysql:;mysql_read_default_group=mysql", undef, undef,
   { PrintError => 0, RaiseError => 1 })
};
SKIP: {
   skip $EVAL_ERROR, 1 if $EVAL_ERROR;

   # Setup
   %existing_dbs = map { $_ => 1 }
      @{$dbh->selectcol_arrayref('SHOW DATABASES')};
   foreach my $db ( @setup_dbs ) {
      eval {
         $dbh->do("CREATE DATABASE IF NOT EXISTS `$db`");
      };
      die $EVAL_ERROR if $EVAL_ERROR && $EVAL_ERROR !~ m/Access denied/;
   }

   $f = new MySQLFind(
      dbh       => $dbh,
   );

   %dbs = map { lc($_) => 1 } $f->find_databases();
   ok($dbs{mysql}, 'mysql database default');
   ok($dbs{test_mysql_finder_1}, 'test_mysql_finder_1 database default');
   ok($dbs{test_mysql_finder_2}, 'test_mysql_finder_2 database default');
   ok(!$dbs{information_schema}, 'I_S filtered out default');
   ok(!$dbs{'lost+found'}, 'lost+found filtered out default');

   $f = new MySQLFind(
      dbh       => $dbh,
      databases => {
         permit => { test_mysql_finder_1 => 1 },
      },
   );

   %dbs = map { lc($_) => 1 } $f->find_databases();
   ok(!$dbs{mysql}, 'mysql database permit');
   ok($dbs{test_mysql_finder_1}, 'test_mysql_finder_1 database permit');
   ok(!$dbs{test_mysql_finder_2}, 'test_mysql_finder_2 database permit');

   $f = new MySQLFind(
      dbh       => $dbh,
      databases => {
         reject => { test_mysql_finder_1 => 1 },
      },
   );

   %dbs = map { lc($_) => 1 } $f->find_databases();
   ok($dbs{mysql}, 'mysql database reject');
   ok(!$dbs{test_mysql_finder_1}, 'test_mysql_finder_1 database reject');
   ok($dbs{test_mysql_finder_2}, 'test_mysql_finder_2 database reject');

   $f = new MySQLFind(
      dbh       => $dbh,
      databases => {
         like   => 'test\\_%',
      },
   );

   %dbs = map { lc($_) => 1 } $f->find_databases();
   ok(!$dbs{mysql}, 'mysql database like');
   ok($dbs{test_mysql_finder_1}, 'test_mysql_finder_1 database like');
   ok($dbs{test_mysql_finder_2}, 'test_mysql_finder_2 database like');

   $f = new MySQLFind(
      dbh       => $dbh,
      databases => {
         regexp => 'finder',
      },
   );

   %dbs = map { lc($_) => 1 } $f->find_databases();
   ok(!$dbs{mysql}, 'mysql database regex');
   ok($dbs{test_mysql_finder_1}, 'test_mysql_finder_1 database regex');
   ok($dbs{test_mysql_finder_2}, 'test_mysql_finder_2 database regex');

}

__DATA__

      # my @tables = $finder->find_tables(database => $database);

# Find a list of tables
# apply LIKE
# apply tblregex
# apply list-o-tables
# apply ignore-these-tables
# skip views
# apply list-o-engines
# apply ignore-these-engines
   # TODO: tear down databases.
