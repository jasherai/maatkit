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

use Test::More tests => 40;
use English qw(-no_match_vars);
use List::Util qw(max);
use DBI;

require "../MySQLFind.pm";
require "../Quoter.pm";
require "../TableParser.pm";
require "../MySQLDump.pm";
require "../DSNParser.pm";
require "../Sandbox.pm";

my $f;
my %found;
my $q  = new Quoter();
my $p  = new TableParser();
my $d  = new MySQLDump();
my $dp = new DSNParser();

my $sb  = new Sandbox(basedir => '/tmp', DSNParser => $dp);
my $dbh = $sb->get_dbh_for('master');

$sb->create_dbs($dbh,
   [qw(lost+found test_mysql_finder_1 test_mysql_finder_2)],
   drop => 1, repl => 0);

$f = new MySQLFind(
   quoter    => $q,
   dumper    => $d,
);

%found = map { lc($_) => 1 } $f->find_databases($dbh);
ok($found{mysql}, 'mysql database default');
ok($found{test_mysql_finder_1}, 'test_mysql_finder_1 database default');
ok($found{test_mysql_finder_2}, 'test_mysql_finder_2 database default');
ok(!$found{information_schema}, 'I_S filtered out default');
ok(!$found{'lost+found'}, 'lost+found filtered out default');

$f = new MySQLFind(
   quoter    => $q,
   dumper    => $d,
   databases => {
      permit => { test_mysql_finder_1 => 1 },
   },
);

%found = map { lc($_) => 1 } $f->find_databases($dbh);
ok(!$found{mysql}, 'mysql database permit');
ok($found{test_mysql_finder_1}, 'test_mysql_finder_1 database permit');
ok(!$found{test_mysql_finder_2}, 'test_mysql_finder_2 database permit');

$f = new MySQLFind(
   quoter    => $q,
   dumper    => $d,
   databases => {
      reject => { test_mysql_finder_1 => 1 },
   },
);

%found = map { lc($_) => 1 } $f->find_databases($dbh);
ok($found{mysql}, 'mysql database reject');
ok(!$found{test_mysql_finder_1}, 'test_mysql_finder_1 database reject');
ok($found{test_mysql_finder_2}, 'test_mysql_finder_2 database reject');

$f = new MySQLFind(
   quoter    => $q,
   dumper    => $d,
   databases => {
      regexp => 'finder',
   },
);

%found = map { lc($_) => 1 } $f->find_databases($dbh);
ok(!$found{mysql}, 'mysql database regex');
ok($found{test_mysql_finder_1}, 'test_mysql_finder_1 database regex');
ok($found{test_mysql_finder_2}, 'test_mysql_finder_2 database regex');

$f = new MySQLFind(
   quoter    => $q,
   dumper    => $d,
   databases => {
      like   => 'test\\_%',
   },
);

%found = map { lc($_) => 1 } $f->find_databases($dbh);
ok(!$found{mysql}, 'mysql database like');
ok($found{test_mysql_finder_1}, 'test_mysql_finder_1 database like');
ok($found{test_mysql_finder_2}, 'test_mysql_finder_2 database like');

# #####################################################################
# TABLES.
# #####################################################################

foreach my $tbl ( { n => 'a', e => 'MyISAM' },
                  { n => 'b', e => 'MyISAM' },
                  { n => 'c', e => 'MyISAM' },
                  { n => 'aa', e => 'InnoDB' }, ) {
   $dbh->do("create table if not exists 
      test_mysql_finder_1.$tbl->{n}(a int) engine=$tbl->{e}");
   $dbh->do("create table if not exists 
      test_mysql_finder_2.$tbl->{n}(a int) engine=$tbl->{e}");
}
$dbh->do("create or replace view test_mysql_finder_1.vw_1 as select 1");
$dbh->do("create or replace view test_mysql_finder_2.vw_1 as select 1");

$f = new MySQLFind(
   quoter => $q,
   dumper => $d,
   tables => { },
);

%found = map { $_ => 1 }
   $f->find_tables($dbh, database => 'test_mysql_finder_1');
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

%found = map { $_ => 1 }
   $f->find_views($dbh, database => 'test_mysql_finder_1');
is_deeply(
   \%found,
   {
      vw_1 => 1,
   },
   'views default',
);

$f = new MySQLFind(
   quoter => $q,
   dumper => $d,
   tables => {
      permit => { a => 1 },
   },
);

%found = map { $_ => 1 }
   $f->find_tables($dbh, database => 'test_mysql_finder_1');
is_deeply(
   \%found,
   {
      a => 1,
   },
   'table permit',
);

$f = new MySQLFind(
   quoter => $q,
   dumper => $d,
   tables => {
      permit => { 'test_mysql_finder_1.a' => 1 },
   },
);

%found = map { $_ => 1 }
   $f->find_tables($dbh, database => 'test_mysql_finder_1');
is_deeply(
   \%found,
   {
      a => 1,
   },
   'table permit fully qualified',
);

%found = map { $_ => 1 }
   $f->find_tables($dbh, database => 'test_mysql_finder_2');
is_deeply(
   \%found,
   {
   },
   'table not fully qualified in wrong DB',
);

$f = new MySQLFind(
   quoter => $q,
   dumper => $d,
   tables => {
      reject => { a => 1 },
   },
);

%found = map { $_ => 1 }
   $f->find_tables($dbh, database => 'test_mysql_finder_1');
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
   quoter => $q,
   dumper => $d,
   tables => {
      reject => { 'test_mysql_finder_1.a' => 1 },
   },
);

%found = map { $_ => 1 }
   $f->find_tables($dbh, database => 'test_mysql_finder_1');
is_deeply(
   \%found,
   {
      b => 1,
      c => 1,
      aa => 1,
   vw_1 => 1,
   },
   'table reject fully qualified',
);

%found = map { $_ => 1 }
   $f->find_tables($dbh, database => 'test_mysql_finder_2');
is_deeply(
   \%found,
   {
      a => 1,
      b => 1,
      c => 1,
      aa => 1,
      vw_1 => 1,
   },
   'table reject fully qualified permits in other DB',
);

$f = new MySQLFind(
   quoter => $q,
   dumper => $d,
   tables => {
      regexp => 'a|b',
   },
);

%found = map { $_ => 1 }
   $f->find_tables($dbh, database => 'test_mysql_finder_1');
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
   quoter => $q,
   dumper => $d,
   tables => {
      like => 'a%',
   },
);

%found = map { $_ => 1 }
   $f->find_tables($dbh, database => 'test_mysql_finder_1');
is_deeply(
   \%found,
   {
      a => 1,
      aa => 1,
   },
   'table like',
);

$f = new MySQLFind(
   quoter => $q,
   dumper => $d,
   tables => {
   },
   engines => {
      views => 0,
   }
);

%found = map { $_ => 1 }
   $f->find_tables($dbh, database => 'test_mysql_finder_1');
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
   quoter => $q,
   dumper => $d,
   tables => {
   },
   engines => {
      permit => { MyISAM => 1 },
   }
);

%found = map { $_ => 1 }
   $f->find_tables($dbh, database => 'test_mysql_finder_1');
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
   quoter => $q,
   dumper => $d,
   tables => {
   },
   engines => {
      reject => { MyISAM => 1 },
   }
);

%found = map { $_ => 1 }
   $f->find_tables($dbh, database => 'test_mysql_finder_1');
is_deeply(
   \%found,
   {
      aa => 1,
      vw_1 => 1,
   },
   'engine reject',
);

# Test that the cache gets populated
$f = new MySQLFind(
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
   [$f->find_tables($dbh, database => 'test_mysql_finder_1')],
   [qw(aa)],
   'engine reject with useddl',
);

map { ok($d->{tables}->{test_mysql_finder_1}->{$_}, "$_ in cache") }
   qw(aa a b c);

# Sleep until the MyISAM tables age at least one second
my $diff;
do {
   sleep(1);
   my $rows = $dbh->selectall_arrayref(
      'SHOW TABLE STATUS FROM test_mysql_finder_1 like "c"',
      { Slice => {} },
   );
   my ( $age ) = map { $_->{Update_time} } grep { $_->{Update_time} } @$rows;
   ($diff) = $dbh->selectrow_array(
      "SELECT TIMESTAMPDIFF(second, '$age', now())");
} until ( $diff > 1 );

# The old info is cached and needs to be flushed.
$d = new MySQLDump();

# Test aging with the Update_time.
$f = new MySQLFind(
   useddl => 1,
   parser => $p,
   dumper => $d,
   quoter => $q,
   tables => {
      status => [
         { Update_time => '+1' },
      ],
   },
   engines => {
   }
);

is_deeply(
   [$f->find_tables($dbh, database => 'test_mysql_finder_1')],
   [qw(a b c)],
   'age older than 1 sec',
);

# Test aging with the Update_time, but the other direction.
$f = new MySQLFind(
   useddl => 1,
   parser => $p,
   dumper => $d,
   quoter => $q,
   tables => {
      status => [
         { Update_time => '-1' },
      ],
   },
   engines => {
   }
);

is_deeply(
   [$f->find_tables($dbh, database => 'test_mysql_finder_1')],
   [qw()],
   'age newer than 1 sec',
);

ok($f->{timestamp}->{$dbh}->{now}, 'Finder timestamp');

# Test aging with the Update_time with nullpass
$f = new MySQLFind(
   useddl => 1,
   parser => $p,
   dumper => $d,
   quoter => $q,
   nullpass => 1,
   tables => {
      status => [
         { Update_time => '-1' },
      ],
   },
   engines => {
   }
);

is_deeply(
   [$f->find_tables($dbh, database => 'test_mysql_finder_1')],
   [qw(aa vw_1)],
   'age newer than 1 sec with nullpass',
);

# #############################################################################
# Issue 99: mk-table-checksum should push down table filters as early as
#           possible
# Issue 23: Table filtering isn't efficient
# #############################################################################
my $output = `MKDEBUG=1 samples/MySQLFind.pl | grep 'SHOW CREATE' | wc -l`;
chomp $output;
is($output, '1', 'Does SHOW CREATE only for filtered tables');

# skip views
# apply list-o-engines
# apply ignore-these-engines

$sb->wipe_clean($dbh);
exit;
