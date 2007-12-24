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

use Test::More;
use English qw(-no_match_vars);
use DBI;

# Open a connection to MySQL, or skip the rest of the tests.
my $dbh;
eval {
   $dbh = DBI->connect(
   "DBI:mysql:;mysql_read_default_group=mysql", undef, undef,
   { PrintError => 0, RaiseError => 1 })
};
if ( $dbh ) {
   plan tests => 1;
}
else {
   plan skip_all => 'Cannot connect to MySQL';
}

require "../TableSyncNibble.pm";
require "../Quoter.pm";
require "../ChangeHandler.pm";
require "../TableChecksum.pm";
require "../TableChunker.pm";
require "../TableNibbler.pm";
require "../TableParser.pm";
require "../MySQLDump.pm";
require "../VersionParser.pm";

sub throws_ok {
   my ( $code, $pat, $msg ) = @_;
   eval { $code->(); };
   like( $EVAL_ERROR, $pat, $msg );
}

`mysql < samples/before-TableSyncChunk.sql`;

my $tp = new TableParser();
my $du = new MySQLDump();
my $q  = new Quoter();
my $vp = new VersionParser();
my $ddl        = $du->get_create_table($dbh, $q, 'test', 'test1');
my $tbl_struct = $tp->parse($ddl);
my $nibbler    = new TableNibbler();
my $checksum   = new TableChecksum();
my $chunker    = new TableChunker( quoter => $q );

my @rows;
my $ch = new ChangeHandler(
   quoter    => new Quoter(),
   database  => 'test',
   table     => 'test1',
   sdatabase => 'test',
   stable    => 'test1',
   replace   => 0,
   actions   => [ sub { push @rows, @_ }, ],
   queue     => 0,
);

my $t = new TableSyncNibble(
   handler  => $ch,
   cols     => [qw(a b c)],
   cols     => $tbl_struct->{cols},
   dbh      => $dbh,
   database => 'test',
   table    => 'test1',
   chunker  => $chunker,
   nibbler  => $nibbler,
   parser   => $tp,
   struct   => $tbl_struct,
   checksum => $checksum,
   vp       => $vp,
   quoter   => $q,
   chunksize => 1,
   where     => 'a>2',
   possible_keys => [],
   versionparser => $vp,
);

is (
   $t->get_sql(
      quoter   => $q,
      where    => 'foo=1',
      database => 'test',
      table    => 'test1',
   ),
   q{SELECT /*test.test1:1/1*/ 0 AS chunk_num, COUNT(*) AS cnt, }
   . q{LOWER(CONCAT(LPAD(CONV(BIT_XOR(CAST(CONV(SUBSTRING(@crc, 1, 16), 16, }
   . q{10) AS UNSIGNED)), 10, 16), 16, '0'), LPAD(CONV(BIT_XOR(CAST(CONV(}
   . q{SUBSTRING(@crc, 17, 16), 16, 10) AS UNSIGNED)), 10, 16), 16, '0'), }
   . q{LPAD(CONV(BIT_XOR(CAST(CONV(SUBSTRING(@crc := SHA1(CONCAT_WS('#', `a`, }
   . q{`b`)), 33, 8), 16, 10) AS UNSIGNED)), 10, 16), 8, '0'))) AS crc FROM }
   . q{`test`.`test1` WHERE (((`a` < 1) OR (`a` = 1 AND `b` <= 'en'))) AND (foo=1)},
   'First nibble SQL',
);

__END__

is_deeply($t->key_cols(), [qw(chunk_num)], 'Key cols in state 0');
$t->done_with_rows();

like ($t->get_sql(
      quoter   => $q,
      where    => 'foo=1',
      database => 'test',
      table    => 'test1',
   ),
   qr/SELECT .*?CONCAT_WS.*?`a` >= 3/,
   'Second chunk SQL',
);

$t->done_with_rows();
ok($t->done(), 'Now done');

# Now start over, and this time "find some bad chunks," as it were.

$t = new TableSyncChunk(
   handler  => $ch,
   cols     => [qw(a b c)],
   cols     => $tbl_struct->{cols},
   dbh      => $dbh,
   database => 'test',
   table    => 'test1',
   chunker  => $chunker,
   struct   => $tbl_struct,
   checksum => $checksum,
   vp       => $vp,
   quoter   => $q,
   chunksize => 2,
   where     => '',
   possible_keys => [],
);

throws_ok(
   sub { $t->not_in_left() },
   qr/in state 0/,
   'not_in_(side) illegal in state 0',
);

# "find a bad row"
$t->same_row(
   { chunk_num => 0, cnt => 0, crc => 'abc' },
   { chunk_num => 0, cnt => 1, crc => 'abc' },
);
ok($t->pending_changes(), 'Pending changes found');
is($t->{state}, 1, 'Working inside chunk');
$t->done_with_rows();
is($t->{state}, 2, 'Now in state to fetch individual rows');
ok($t->pending_changes(), 'Pending changes not done yet');
is($t->get_sql(database => 'test', table => 'test1'),
   "SELECT `a`, SHA1(CONCAT_WS('#', `a`, `b`)) AS __crc FROM "
      . "`test`.`test1` WHERE (`a` < 3)",
   'SQL now working inside chunk'
);
ok($t->{state}, 'Still working inside chunk');
is(scalar(@rows), 0, 'No bad row triggered');

$t->not_in_left({a => 1});

is_deeply(\@rows,
   ['DELETE FROM `test`.`test1` WHERE `a`=1 LIMIT 1'],
   'Working inside chunk, got a bad row',
);

# Should cause it to fetch back from the DB to figure out the right thing to do
$t->not_in_right({a => 1});
is_deeply(\@rows,
   [
   'DELETE FROM `test`.`test1` WHERE `a`=1 LIMIT 1',
   "INSERT INTO `test`.`test1`(`a`, `b`) VALUES (1, 'en')",
   ],
   'Missing row fetched back from DB',
);

# Shouldn't cause anything to happen
$t->same_row( {a => 1, __crc => 'foo'}, {a => 1, __crc => 'foo'} );

is_deeply(\@rows,
   [
   'DELETE FROM `test`.`test1` WHERE `a`=1 LIMIT 1',
   "INSERT INTO `test`.`test1`(`a`, `b`) VALUES (1, 'en')",
   ],
   'No more rows added',
);

$t->same_row( {a => 1, __crc => 'foo'}, {a => 1, __crc => 'bar'} );

is_deeply(\@rows,
   [
      'DELETE FROM `test`.`test1` WHERE `a`=1 LIMIT 1',
      "INSERT INTO `test`.`test1`(`a`, `b`) VALUES (1, 'en')",
      "UPDATE `test`.`test1` SET `b`='en' WHERE `a`=1 LIMIT 1",
   ],
   'Row added to update differing row',
);

$t->done_with_rows();
is($t->{state}, 0, 'Now not working inside chunk');
is($t->pending_changes(), 0, 'No pending changes');
