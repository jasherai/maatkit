#!/usr/bin/perl

use strict;
use warnings FATAL => 'all';
use English qw(-no_match_vars);
use Test::More tests => 23;

require '../../common/DSNParser.pm';
require '../../common/Sandbox.pm';
my $dp  = new DSNParser();
my $sb  = new Sandbox(basedir => '/tmp', DSNParser => $dp);
my $dbh = $sb->get_dbh_for('master')
   or BAIL_OUT('Cannot connect to sandbox master');

$sb->create_dbs($dbh, ['test']);

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

my $mysql = $sb->_use_for('master');

diag(`$mysql < samples/before-TableSyncNibble.sql`);

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

my $t;

# Test with FNV_64 just to make sure there are no errors
eval { $dbh->do('select fnv_64(1)') };
SKIP: {
   skip 'No FNV_64 function installed', 1 if $EVAL_ERROR;

   $t = new TableSyncNibble(
      handler  => $ch,
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
      func          => 'FNV_64',
      trim          => 0,
   );

   is (
      $t->get_sql(
         quoter   => $q,
         where    => 'foo=1',
         database => 'test',
         table    => 'test1',
      ),
      q{SELECT /*test.test1:1/1*/ 0 AS chunk_num, COUNT(*) AS }
      . q{cnt, LOWER(CONV(BIT_XOR(CAST(FNV_64(`a`, `b`, `c`) AS UNSIGNED)), }
      . q{10, 16)) AS crc FROM `test`.`test1`  WHERE (((`a` < 1) OR (`a` = 1 }
      . q{AND `b` <= 'en'))) AND ((foo=1))},
      'First nibble SQL with FNV_64',
   );
}

$t = new TableSyncNibble(
   handler  => $ch,
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
   func          => 'SHA1',
   trim          => 0,
);

is(
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
   . q{`b`, `c`)), 33, 8), 16, 10) AS UNSIGNED)), 10, 16), 8, '0'))) AS crc FROM }
   . q{`test`.`test1`  WHERE (((`a` < 1) OR (`a` = 1 AND `b` <= 'en'))) AND ((foo=1))},
   'First nibble SQL',
);

is(
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
   . q{`b`, `c`)), 33, 8), 16, 10) AS UNSIGNED)), 10, 16), 8, '0'))) AS crc FROM }
   . q{`test`.`test1`  WHERE (((`a` < 1) OR (`a` = 1 AND `b` <= 'en'))) AND ((foo=1))},
   'First nibble SQL, again',
);

$t->{nibble} = 1;
delete $t->{cached_boundaries};

is(
   $t->get_sql(
      quoter   => $q,
      where    => '(foo=1)',
      database => 'test',
      table    => 'test1',
   ),
   q{SELECT /*test.test1:1/1*/ 0 AS chunk_num, COUNT(*) AS cnt, }
   . q{LOWER(CONCAT(LPAD(CONV(BIT_XOR(CAST(CONV(SUBSTRING(@crc, 1, 16), 16, }
   . q{10) AS UNSIGNED)), 10, 16), 16, '0'), LPAD(CONV(BIT_XOR(CAST(CONV(}
   . q{SUBSTRING(@crc, 17, 16), 16, 10) AS UNSIGNED)), 10, 16), 16, '0'), }
   . q{LPAD(CONV(BIT_XOR(CAST(CONV(SUBSTRING(@crc := SHA1(CONCAT_WS('#', `a`, }
   . q{`b`, `c`)), 33, 8), 16, 10) AS UNSIGNED)), 10, 16), 8, '0'))) AS crc FROM }
   . q{`test`.`test1`  WHERE ((((`a` > 1) OR (`a` = 1 AND `b` > 'en')) AND }
   . q{((`a` < 2) OR (`a` = 2 AND `b` <= 'ca')))) AND (((foo=1)))},
   'Second nibble SQL',
);

# Bump the nibble boundaries ahead until we run off the end of the table.
$t->done_with_rows();
$t->get_sql(
      quoter   => $q,
      where    => 'foo=1',
      database => 'test',
      table    => 'test1',
   );
$t->done_with_rows();
$t->get_sql(
      quoter   => $q,
      where    => 'foo=1',
      database => 'test',
      table    => 'test1',
   );
$t->done_with_rows();
$t->get_sql(
      quoter   => $q,
      where    => 'foo=1',
      database => 'test',
      table    => 'test1',
   );

is(
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
   . q{`b`, `c`)), 33, 8), 16, 10) AS UNSIGNED)), 10, 16), 8, '0'))) AS crc FROM }
   . q{`test`.`test1`  WHERE ((((`a` > 4) OR (`a` = 4 AND `b` > 'bz')) AND }
   . q{1=1)) AND ((foo=1))},
   'End-of-table nibble SQL',
);

$t->done_with_rows();
ok($t->done(), 'Now done');

# Throw away and start anew, because it's off the end of the table
$t->{nibble} = 0;
delete $t->{cached_boundaries};
delete $t->{cached_nibble};
delete $t->{cached_row};

is_deeply($t->key_cols(), [qw(chunk_num)], 'Key cols in state 0');
$t->get_sql(
      quoter   => $q,
      where    => 'foo=1',
      database => 'test',
      table    => 'test1',
   );
$t->done_with_rows();

is($t->done(), '', 'Not done, because not reached end-of-table');

throws_ok(
   sub { $t->not_in_left() },
   qr/in state 0/,
   'not_in_(side) illegal in state 0',
);

# Now "find some bad chunks," as it were.

# "find a bad row"
$t->same_row(
   { chunk_num => 0, cnt => 0, crc => 'abc' },
   { chunk_num => 0, cnt => 1, crc => 'abc' },
);
ok($t->pending_changes(), 'Pending changes found');
is($t->{state}, 1, 'Working inside nibble');
$t->done_with_rows();
is($t->{state}, 2, 'Now in state to fetch individual rows');
ok($t->pending_changes(), 'Pending changes not done yet');
is($t->get_sql(database => 'test', table => 'test1'),
   q{SELECT /*rows in nibble*/ `a`, `b`, SHA1(CONCAT_WS('#', `a`, `b`, `c`)) AS __crc FROM }
   . q{`test`.`test1` WHERE ((((`a` > 1) OR (`a` = 1 AND `b` > 'en')) }
   . q{AND ((`a` < 2) OR (`a` = 2 AND `b` <= 'ca'))))},
   'SQL now working inside nibble'
);
ok($t->{state}, 'Still working inside nibble');
is(scalar(@rows), 0, 'No bad row triggered');

$t->not_in_left({a => 1, b => 'en'});

is_deeply(\@rows,
   ["DELETE FROM `test`.`test1` WHERE `a`=1 AND `b`='en' LIMIT 1"],
   'Working inside nibble, got a bad row',
);

# Shouldn't cause anything to happen
$t->same_row(
   {a => 1, b => 'en', __crc => 'foo'},
   {a => 1, b => 'en', __crc => 'foo'} );

is_deeply(\@rows,
   ["DELETE FROM `test`.`test1` WHERE `a`=1 AND `b`='en' LIMIT 1"],
   'No more rows added',
);

$t->same_row(
   {a => 1, b => 'en', __crc => 'foo'},
   {a => 1, b => 'en', __crc => 'bar'} );

is_deeply(\@rows,
   [
      "DELETE FROM `test`.`test1` WHERE `a`=1 AND `b`='en' LIMIT 1",
      "UPDATE `test`.`test1` SET `c`='a' WHERE `a`=1 AND `b`='en' LIMIT 1",
   ],
   'Row added to update differing row',
);

$t->done_with_rows();
is($t->{state}, 0, 'Now not working inside nibble');
is($t->pending_changes(), 0, 'No pending changes');

# Now test that SQL_BUFFER_RESULT is in the queries OK
$t = new TableSyncNibble(
   handler  => $ch,
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
   func          => 'SHA1',
   trim          => 0,
   bufferinmysql => 1,
);

like(
   $t->get_sql(
      quoter   => $q,
      where    => 'foo=1',
      database => 'test',
      table    => 'test1',
   ),
   qr/SELECT SQL_BUFFER_RESULT/,
   'Buffering in first nibble',
);

# "find a bad row"
$t->same_row(
   { chunk_num => 0, cnt => 0, crc => 'abc' },
   { chunk_num => 0, cnt => 1, crc => 'abc' },
);

like(
   $t->get_sql(
      quoter   => $q,
      where    => 'foo=1',
      database => 'test',
      table    => 'test1',
   ),
   qr/SELECT ..rows in nibble.. SQL_BUFFER_RESULT/,
   'Buffering in next nibble',
);

# #############################################################################
# Issue 96: mk-table-sync: Nibbler infinite loop
# #############################################################################

# This stuff isn't used yet...

$sb->load_file('master', 'samples/issue_96.sql');
$tbl_struct = $tp->parse($du->get_create_table($dbh, $q, 'issue_96', 't'));
$t = new TableSyncNibble(
   handler  => $ch,
   cols     => $tbl_struct->{cols},
   dbh      => $dbh,
   database => 'issue_96',
   table    => 't',
   chunker  => $chunker,
   nibbler  => $nibbler,
   parser   => $tp,
   struct   => $tbl_struct,
   checksum => $checksum,
   vp       => $vp,
   quoter   => $q,
   chunksize => 2,
   where     => '',
   possible_keys => [],
   versionparser => $vp,
   func          => '',
   trim          => 0,
);

# #############################################################################
# Done.
# #############################################################################
#$sb->wipe_clean($dbh);
exit;
