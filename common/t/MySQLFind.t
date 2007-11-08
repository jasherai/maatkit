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
   $tests = 31;
}

use Test::More tests => $tests;
use English qw(-no_match_vars);
use DBI;

require "../MySQLFind.pm";
require "../Quoter.pm";
require "../TableParser.pm";
require "../MySQLDump.pm";

my $f;
my $q = new Quoter();
my $p = new TableParser();
my $d = new MySQLDump();
my %found;
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
   skip $EVAL_ERROR, $tests if $EVAL_ERROR;

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

   %found = map { lc($_) => 1 } $f->find_databases();
   ok($found{mysql}, 'mysql database default');
   ok($found{test_mysql_finder_1}, 'test_mysql_finder_1 database default');
   ok($found{test_mysql_finder_2}, 'test_mysql_finder_2 database default');
   ok(!$found{information_schema}, 'I_S filtered out default');
   ok(!$found{'lost+found'}, 'lost+found filtered out default');

   $f = new MySQLFind(
      dbh       => $dbh,
      databases => {
         permit => { test_mysql_finder_1 => 1 },
      },
   );

   %found = map { lc($_) => 1 } $f->find_databases();
   ok(!$found{mysql}, 'mysql database permit');
   ok($found{test_mysql_finder_1}, 'test_mysql_finder_1 database permit');
   ok(!$found{test_mysql_finder_2}, 'test_mysql_finder_2 database permit');

   $f = new MySQLFind(
      dbh       => $dbh,
      databases => {
         reject => { test_mysql_finder_1 => 1 },
      },
   );

   %found = map { lc($_) => 1 } $f->find_databases();
   ok($found{mysql}, 'mysql database reject');
   ok(!$found{test_mysql_finder_1}, 'test_mysql_finder_1 database reject');
   ok($found{test_mysql_finder_2}, 'test_mysql_finder_2 database reject');

   $f = new MySQLFind(
      dbh       => $dbh,
      databases => {
         regexp => 'finder',
      },
   );

   %found = map { lc($_) => 1 } $f->find_databases();
   ok(!$found{mysql}, 'mysql database regex');
   ok($found{test_mysql_finder_1}, 'test_mysql_finder_1 database regex');
   ok($found{test_mysql_finder_2}, 'test_mysql_finder_2 database regex');

   $f = new MySQLFind(
      dbh       => $dbh,
      databases => {
         like   => 'test\\_%',
      },
   );

   %found = map { lc($_) => 1 } $f->find_databases();
   ok(!$found{mysql}, 'mysql database like');
   ok($found{test_mysql_finder_1}, 'test_mysql_finder_1 database like');
   ok($found{test_mysql_finder_2}, 'test_mysql_finder_2 database like');

   # #####################################################################
   # TABLES.  All in the test_mysql_finder_1 database.
   # #####################################################################

   foreach my $tbl ( 
      { n => 'a', e => 'MyISAM' },
      { n => 'b', e => 'MyISAM' },
      { n => 'c', e => 'MyISAM' },
      { n => 'aa', e => 'InnoDB' }, ) {
      $dbh->do("create table if not exists 
         test_mysql_finder_1.$tbl->{n}(a int) engine=$tbl->{e}");
   }
   $dbh->do("create or replace view test_mysql_finder_1.vw_1 as select 1");

   $f = new MySQLFind(
      dbh    => $dbh,
      quoter => $q,
      tables => {
      },
   );

   %found = map { $_ => 1 } $f->find_tables(database => 'test_mysql_finder_1');
   is_deeply(
      \%found,
      {
         a => 1,
         b => 1,
         c => 1,
         aa => 1,
         vw_1 => 1,
      },
      'table default',
   );

   $f = new MySQLFind(
      dbh    => $dbh,
      quoter => $q,
      tables => {
         permit => { a => 1 },
      },
   );

   %found = map { $_ => 1 } $f->find_tables(database => 'test_mysql_finder_1');
   is_deeply(
      \%found,
      {
         a => 1,
      },
      'table permit',
   );

   $f = new MySQLFind(
      dbh    => $dbh,
      quoter => $q,
      tables => {
         reject => { a => 1 },
      },
   );

   %found = map { $_ => 1 } $f->find_tables(database => 'test_mysql_finder_1');
   is_deeply(
      \%found,
      {
         b => 1,
         c => 1,
         aa => 1,
         vw_1 => 1,
      },
      'table reject',
   );

   $f = new MySQLFind(
      dbh    => $dbh,
      quoter => $q,
      tables => {
         regexp => 'a|b',
      },
   );

   %found = map { $_ => 1 } $f->find_tables(database => 'test_mysql_finder_1');
   is_deeply(
      \%found,
      {
         a => 1,
         b => 1,
         aa => 1,
      },
      'table regexp',
   );

   $f = new MySQLFind(
      dbh    => $dbh,
      quoter => $q,
      tables => {
         like => 'a%',
      },
   );

   %found = map { $_ => 1 } $f->find_tables(database => 'test_mysql_finder_1');
   is_deeply(
      \%found,
      {
         a => 1,
         aa => 1,
      },
      'table like',
   );

   $f = new MySQLFind(
      dbh    => $dbh,
      quoter => $q,
      tables => {
      },
      engines => {
         views => 0,
      }
   );

   %found = map { $_ => 1 } $f->find_tables(database => 'test_mysql_finder_1');
   is_deeply(
      \%found,
      {
         a => 1,
         b => 1,
         c => 1,
         aa => 1,
      },
      'engine no views',
   );

   $f = new MySQLFind(
      dbh    => $dbh,
      quoter => $q,
      tables => {
      },
      engines => {
         permit => { MyISAM => 1 },
      }
   );

   %found = map { $_ => 1 } $f->find_tables(database => 'test_mysql_finder_1');
   is_deeply(
      \%found,
      {
         a => 1,
         b => 1,
         c => 1,
      },
      'engine permit',
   );

   $f = new MySQLFind(
      dbh    => $dbh,
      quoter => $q,
      tables => {
      },
      engines => {
         reject => { MyISAM => 1 },
      }
   );

   %found = map { $_ => 1 } $f->find_tables(database => 'test_mysql_finder_1');
   is_deeply(
      \%found,
      {
         aa => 1,
         vw_1 => 1,
      },
      'engine reject',
   );

   # Test that preferring DDL over SHOW TABLE STATUS wants a TableParser.
   eval {
      $f = new MySQLFind(
         dbh    => $dbh,
         useddl => 1,
         quoter => $q,
         tables => {
         },
         engines => {
            reject => { MyISAM => 1 },
            views  => 0,
         }
      );
   };
   like($EVAL_ERROR, qr/parser and dumper/, 'wants a TableParser');

   # Test that the cache gets populated
   $f = new MySQLFind(
      dbh    => $dbh,
      useddl => 1,
      parser => $p,
      dumper => $d,
      quoter => $q,
      tables => {
      },
      engines => {
         reject => { MyISAM => 1 },
         views  => 0,
      }
   );

   is_deeply(
      [$f->find_tables(database => 'test_mysql_finder_1')],
      [qw(aa)],
      'engine reject with useddl',
   );

   map {
      ok($d->{tables}->{test_mysql_finder_1}->{$_}, "$_ in cache")
   } qw(aa a b c);

   foreach my $db ( @setup_dbs ) {
      if (!exists $existing_dbs{$db} ) {
         $dbh->do("drop database " . $q->quote($db));
      }
   }

}

# skip views
# apply list-o-engines
# apply ignore-these-engines
