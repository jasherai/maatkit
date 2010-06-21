#!/usr/bin/perl

BEGIN {
   die "The MAATKIT_TRUNK environment variable is not set.  See http://code.google.com/p/maatkit/wiki/Testing"
      unless $ENV{MAATKIT_TRUNK} && -d $ENV{MAATKIT_TRUNK};
   unshift @INC, "$ENV{MAATKIT_TRUNK}/common";
};

use strict;
use warnings FATAL => 'all';
use English qw(-no_match_vars);
use Test::More;

# TableSyncer and its required modules:
use TableSyncer;
use MasterSlave;
use Quoter;
use TableChecksum;
use VersionParser;
# The sync plugins:
use TableSyncChunk;
use TableSyncNibble;
use TableSyncGroupBy;
use TableSyncStream;
# Helper modules for the sync plugins:
use TableChunker;
use TableNibbler;
# Modules for sync():
use ChangeHandler;
use RowDiff;
# And other modules:
use MySQLDump;
use TableParser;
use DSNParser;
use Sandbox;
use MaatkitTest;

use constant MKDEBUG => $ENV{MKDEBUG} || 0;

my $dp = new DSNParser(opts=>$dsn_opts);
my $sb = new Sandbox(basedir => '/tmp', DSNParser => $dp);
my $dbh      = $sb->get_dbh_for('master');
my $src_dbh  = $sb->get_dbh_for('master');
my $dst_dbh  = $sb->get_dbh_for('slave1');

if ( !$src_dbh || !$dbh ) {
   plan skip_all => 'Cannot connect to sandbox master';
}
elsif ( !$dst_dbh ) {
   plan skip_all => 'Cannot connect to sandbox slave';
}
else {
   plan tests => 52;
}

$sb->create_dbs($dbh, ['test']);
my $mysql = $sb->_use_for('master');
$sb->load_file('master', 'common/t/samples/before-TableSyncChunk.sql');

my $q  = new Quoter();
my $tp = new TableParser(Quoter=>$q);
my $du = new MySQLDump( cache => 0 );
my ($rows, $cnt);

# ###########################################################################
# Make a TableSyncer object.
# ###########################################################################
throws_ok(
   sub { new TableSyncer() },
   qr/I need a MasterSlave/,
   'MasterSlave required'
);
throws_ok(
   sub { new TableSyncer(MasterSlave=>1) },
   qr/I need a Quoter/,
   'Quoter required'
);
throws_ok(
   sub { new TableSyncer(MasterSlave=>1, Quoter=>1) },
   qr/I need a VersionParser/,
   'VersionParser required'
);
throws_ok(
   sub { new TableSyncer(MasterSlave=>1, Quoter=>1, VersionParser=>1) },
   qr/I need a TableChecksum/,
   'TableChecksum required'
);

my $rd       = new RowDiff(dbh=>$src_dbh);
my $ms       = new MasterSlave();
my $vp       = new VersionParser();
my $checksum = new TableChecksum(
   Quoter         => $q,
   VersionParser => $vp,
);
my $syncer = new TableSyncer(
   MasterSlave   => $ms,
   Quoter        => $q,
   TableChecksum => $checksum,
   VersionParser => $vp,
);
isa_ok($syncer, 'TableSyncer');

# ###########################################################################
# Make TableSync* objects.
# ###########################################################################
my $chunker = new TableChunker( Quoter => $q, MySQLDump => $du );
my $nibbler = new TableNibbler( TableParser => $tp, Quoter => $q );

my ($sync_chunk, $sync_nibble, $sync_groupby, $sync_stream);
my $plugins = [];

# Call this func to re-make/reset the plugins.

sub make_plugins {
   $sync_chunk = new TableSyncChunk(
      TableChunker => $chunker,
      Quoter       => $q,
   );
   $sync_nibble = new TableSyncNibble(
      TableNibbler  => $nibbler,
      TableChunker  => $chunker,
      TableParser   => $tp,
      Quoter        => $q,
   );
   $sync_groupby = new TableSyncGroupBy( Quoter => $q );
   $sync_stream  = new TableSyncStream( Quoter => $q );

   $plugins = [$sync_chunk, $sync_nibble, $sync_groupby, $sync_stream];

   return;
}

make_plugins();

# ###########################################################################
# Test get_best_plugin() (formerly best_algorithm()).
# ###########################################################################
my $tbl_struct = $tp->parse($du->get_create_table($src_dbh, $q,'test','test5'));
is_deeply(
   [
      $syncer->get_best_plugin(
         plugins     => $plugins,
         tbl_struct  => $tbl_struct,
      )
   ],
   [ $sync_groupby ],
   'Best plugin GroupBy'
);

$tbl_struct = $tp->parse($du->get_create_table($src_dbh, $q,'test','test3'));
my ($plugin, %plugin_args) = $syncer->get_best_plugin(
   plugins     => $plugins,
   tbl_struct  => $tbl_struct,
);
is_deeply(
   [ $plugin, \%plugin_args, ],
   [ $sync_chunk, { chunk_index => 'PRIMARY', chunk_col => 'a', } ],
   'Best plugin Chunk'
);

$tbl_struct = $tp->parse($du->get_create_table($src_dbh, $q,'test','test6'));
($plugin, %plugin_args) = $syncer->get_best_plugin(
   plugins     => $plugins,
   tbl_struct  => $tbl_struct,
);
is_deeply(
   [ $plugin, \%plugin_args, ],
   [ $sync_nibble,{ chunk_index => 'a', key_cols => [qw(a)], small_table=>0 } ],
   'Best plugin Nibble'
);

# ###########################################################################
# Test sync_table() for each plugin with a basic, 4 row data set.
# ###########################################################################

# REMEMBER: call new_ch() before each sync to reset the number of actions.

# Redo this in case any tests above change $tbl_struct.
$tbl_struct = $tp->parse($du->get_create_table($src_dbh, $q,'test','test1'));

# test1 has 4 rows and test2, which is the same struct, is empty.
# So after sync, test2 should have the same 4 rows as test1.
my $test1_rows = [
 [qw(1 en)],
 [qw(2 ca)],
 [qw(3 ab)],
 [qw(4 bz)],
];
my $inserts = [
   "INSERT INTO `test`.`test2`(`a`, `b`) VALUES ('1', 'en')",
   "INSERT INTO `test`.`test2`(`a`, `b`) VALUES ('2', 'ca')",
   "INSERT INTO `test`.`test2`(`a`, `b`) VALUES ('3', 'ab')",
   "INSERT INTO `test`.`test2`(`a`, `b`) VALUES ('4', 'bz')",
];
my $src = {
   dbh      => $src_dbh,
   misc_dbh => $dbh,
   db       => 'test',
   tbl      => 'test1',
};
my $dst = {
   dbh => $dst_dbh,
   db  => 'test',
   tbl => 'test2',
};
my %args = (
   plugins        => $plugins,
   src            => $src,
   dst            => $dst,
   tbl_struct     => $tbl_struct,
   cols           => $tbl_struct->{cols},
   chunk_size     => 2,
   RowDiff        => $rd,
   ChangeHandler  => undef,  # call new_ch()
   function       => 'SHA1',
);

my @rows;
sub new_ch {
   my ( $dbh, $queue ) = @_;
   return new ChangeHandler(
      Quoter    => $q,
      left_db   => $src->{db},
      left_tbl  => $src->{tbl},
      right_db  => $dst->{db},
      right_tbl => $dst->{tbl},
      actions => [
         sub {
            my ( $sql, $change_dbh ) = @_;
            push @rows, $sql;
            if ( $change_dbh ) {
               # dbh passed through change() or process_rows()
               $change_dbh->do($sql);
            }
            elsif ( $dbh ) {
               # dbh passed to this sub
               $dbh->do($sql);
            }
            else {
               # default dst dbh for this test script
               $dst_dbh->do($sql);
            }
         }
      ],
      replace => 0,
      queue   => defined $queue ? $queue : 1,
   );
}

# First, do a dry run sync, so nothing should happen.
$dst_dbh->do('TRUNCATE TABLE test.test2');
@rows = ();
$args{ChangeHandler} = new_ch();

is_deeply(
   { $syncer->sync_table(%args, dry_run => 1) },
   {
      DELETE    => 0,
      INSERT    => 0,
      REPLACE   => 0,
      UPDATE    => 0,
      ALGORITHM => 'Chunk',
   },
   'Dry run, no changes, Chunk plugin'
);

is_deeply(
   \@rows,
   [],
   'Dry run, no SQL statements made'
);

is_deeply(
   $dst_dbh->selectall_arrayref('SELECT * FROM test.test2 ORDER BY a, b'),
   [],
   'Dry run, no rows changed'
);

# Now do the real syncs that should insert 4 rows into test2.

# Sync with Chunk.
is_deeply(
   { $syncer->sync_table(%args) },
   {
      DELETE    => 0,
      INSERT    => 4,
      REPLACE   => 0,
      UPDATE    => 0,
      ALGORITHM => 'Chunk',
   },
   'Sync with Chunk, 4 INSERTs'
);

is_deeply(
   \@rows,
   $inserts,
   'Sync with Chunk, ChangeHandler made INSERT statements'
);

is_deeply(
   $dst_dbh->selectall_arrayref('SELECT * FROM test.test2 ORDER BY a, b'),
   $test1_rows,
   'Sync with Chunk, dst rows match src rows'
);

# Sync with Chunk again, but use chunk_size = 1k which should be converted.
$dst_dbh->do('TRUNCATE TABLE test.test2');
@rows = ();
$args{ChangeHandler} = new_ch();

is_deeply(
   { $syncer->sync_table(%args) },
   {
      DELETE    => 0,
      INSERT    => 4,
      REPLACE   => 0,
      UPDATE    => 0,
      ALGORITHM => 'Chunk',
   },
   'Sync with Chunk chunk size 1k, 4 INSERTs'
);

is_deeply(
   \@rows,
   $inserts,
   'Sync with Chunk chunk size 1k, ChangeHandler made INSERT statements'
);

is_deeply(
   $dst_dbh->selectall_arrayref('SELECT * FROM test.test2 ORDER BY a, b'),
   $test1_rows,
   'Sync with Chunk chunk size 1k, dst rows match src rows'
);

# Sync with Nibble.
$dst_dbh->do('TRUNCATE TABLE test.test2');
@rows = ();
$args{ChangeHandler} = new_ch();

is_deeply(
   { $syncer->sync_table(%args, plugins => [$sync_nibble]) },
   {
      DELETE    => 0,
      INSERT    => 4,
      REPLACE   => 0,
      UPDATE    => 0,
      ALGORITHM => 'Nibble',
   },
   'Sync with Nibble, 4 INSERTs'
);

is_deeply(
   \@rows,
   $inserts,
   'Sync with Nibble, ChangeHandler made INSERT statements'
);

is_deeply(
   $dst_dbh->selectall_arrayref('SELECT * FROM test.test2 ORDER BY a, b'),
   $test1_rows,
   'Sync with Nibble, dst rows match src rows'
);

# Sync with GroupBy.
$dst_dbh->do('TRUNCATE TABLE test.test2');
@rows = ();
$args{ChangeHandler} = new_ch();

is_deeply(
   { $syncer->sync_table(%args, plugins => [$sync_groupby]) },
   {
      DELETE    => 0,
      INSERT    => 4,
      REPLACE   => 0,
      UPDATE    => 0,
      ALGORITHM => 'GroupBy',
   },
   'Sync with GroupBy, 4 INSERTs'
);

is_deeply(
   \@rows,
   $inserts,
   'Sync with GroupBy, ChangeHandler made INSERT statements'
);

is_deeply(
   $dst_dbh->selectall_arrayref('SELECT * FROM test.test2 ORDER BY a, b'),
   $test1_rows,
   'Sync with GroupBy, dst rows match src rows'
);

# Sync with Stream.
$dst_dbh->do('TRUNCATE TABLE test.test2');
@rows = ();
$args{ChangeHandler} = new_ch();

is_deeply(
   { $syncer->sync_table(%args, plugins => [$sync_stream]) },
   {
      DELETE    => 0,
      INSERT    => 4,
      REPLACE   => 0,
      UPDATE    => 0,
      ALGORITHM => 'Stream',
   },
   'Sync with Stream, 4 INSERTs'
);

is_deeply(
   \@rows,
   $inserts,
   'Sync with Stream, ChangeHandler made INSERT statements'
);

is_deeply(
   $dst_dbh->selectall_arrayref('SELECT * FROM test.test2 ORDER BY a, b'),
   $test1_rows,
   'Sync with Stream, dst rows match src rows'
);

# #############################################################################
# Check that the plugins can resolve unique key violations.
# #############################################################################

make_plugins();

$tbl_struct = $tp->parse($du->get_create_table($src_dbh, $q,'test','test3'));

$args{tbl_struct} = $tbl_struct;
$args{cols}       = $tbl_struct->{cols};
$src->{tbl} = 'test3';
$dst->{tbl} = 'test4';

@rows = ();
$args{ChangeHandler} = new_ch();

$syncer->sync_table(%args, plugins => [$sync_stream]);

is_deeply(
   $dst_dbh->selectall_arrayref('select * from test.test4 order by a', { Slice => {}} ),
   [ { a => 1, b => 2 }, { a => 2, b => 1 } ],
   'Resolves unique key violations with Stream'
);


@rows = ();
$args{ChangeHandler} = new_ch();

$syncer->sync_table(%args, plugins => [$sync_chunk]);

is_deeply(
   $dst_dbh->selectall_arrayref('select * from test.test4 order by a', { Slice => {}} ),
   [ { a => 1, b => 2 }, { a => 2, b => 1 } ],
   'Resolves unique key violations with Chunk' );

# ###########################################################################
# Test locking.
# ###########################################################################

make_plugins();

$syncer->sync_table(%args, lock => 1);

# The locks should be released.
ok($src_dbh->do('select * from test.test4'), 'Cycle locks released');

$syncer->sync_table(%args, lock => 2);

# The locks should be released.
ok($src_dbh->do('select * from test.test4'), 'Table locks released');

$syncer->sync_table(%args, lock => 3);

ok(
   $dbh->do('replace into test.test3 select * from test.test3 limit 0'),
   'Does not lock in level 3 locking'
);

eval {
   $syncer->lock_and_wait(
      %args,
      lock        => 3,
      lock_level  => 3,
      replicate   => 0,
      timeout_ok  => 1,
      transaction => 0,
      wait        => 60,
   );
};
is($EVAL_ERROR, '', 'Locks in level 3');

# See DBI man page.
use POSIX ':signal_h';
my $mask = POSIX::SigSet->new(SIGALRM);    # signals to mask in the handler
my $action = POSIX::SigAction->new( sub { die "maatkit timeout" }, $mask, );
my $oldaction = POSIX::SigAction->new();
sigaction( SIGALRM, $action, $oldaction );

throws_ok (
   sub {
      alarm 1;
      $dbh->do('replace into test.test3 select * from test.test3 limit 0');
   },
   qr/maatkit timeout/,
   "Level 3 lock NOT released",
);

# Kill the DBHs it in the right order: there's a connection waiting on
# a lock.
$src_dbh->disconnect();
$dst_dbh->disconnect();
$src_dbh = $sb->get_dbh_for('master');
$dst_dbh = $sb->get_dbh_for('slave1');

$src->{dbh} = $src_dbh;
$dst->{dbh} = $dst_dbh;

# ###########################################################################
# Test TableSyncGroupBy.
# ###########################################################################

$sb->load_file('master', 'common/t/samples/before-TableSyncGroupBy.sql');
sleep 1;
$tbl_struct = $tp->parse($du->get_create_table($src_dbh, $q,'test','test1'));

$args{tbl_struct} = $tbl_struct;
$args{cols}       = $tbl_struct->{cols};
$src->{tbl} = 'test1';
$dst->{tbl} = 'test2';

@rows = ();
$args{ChangeHandler} = new_ch();

$syncer->sync_table(%args, plugins => [$sync_groupby]);

is_deeply(
   $dst_dbh->selectall_arrayref('select * from test.test2 order by a, b, c', { Slice => {}} ),
   [
      { a => 1, b => 2, c => 3 },
      { a => 1, b => 2, c => 3 },
      { a => 1, b => 2, c => 3 },
      { a => 1, b => 2, c => 3 },
      { a => 2, b => 2, c => 3 },
      { a => 2, b => 2, c => 3 },
      { a => 2, b => 2, c => 3 },
      { a => 2, b => 2, c => 3 },
      { a => 3, b => 2, c => 3 },
      { a => 3, b => 2, c => 3 },
   ],
   'Table synced with GroupBy',
);

# #############################################################################
# Issue 96: mk-table-sync: Nibbler infinite loop
# #############################################################################

$sb->load_file('master', 'common/t/samples/issue_96.sql');
sleep 1;
$tbl_struct = $tp->parse($du->get_create_table($src_dbh, $q,'issue_96','t'));

$args{tbl_struct} = $tbl_struct;
$args{cols}       = $tbl_struct->{cols};
$src->{db} = $dst->{db} = 'issue_96';
$src->{tbl} = 't';
$dst->{tbl} = 't2';

@rows = ();
$args{ChangeHandler} = new_ch();

# Make paranoid-sure that the tables differ.
my $r1 = $src_dbh->selectall_arrayref('SELECT from_city FROM issue_96.t WHERE package_id=4');
my $r2 = $dst_dbh->selectall_arrayref('SELECT from_city FROM issue_96.t2 WHERE package_id=4');
is_deeply(
   [ $r1->[0]->[0], $r2->[0]->[0] ],
   [ 'ta',          'zz'          ],
   'Infinite loop table differs (issue 96)'
);

$syncer->sync_table(%args, chunk_size => 2, plugins => [$sync_nibble]);

$r1 = $src_dbh->selectall_arrayref('SELECT from_city FROM issue_96.t WHERE package_id=4');
$r2 = $dst_dbh->selectall_arrayref('SELECT from_city FROM issue_96.t2 WHERE package_id=4');
is(
   $r1->[0]->[0],
   $r2->[0]->[0],
   'Sync infinite loop table (issue 96)'
);

# #############################################################################
# Test check_permissions().
# #############################################################################

# Re-using issue_96.t from above.
is(
   $syncer->have_all_privs($src->{dbh}, 'issue_96', 't'),
   1,
   'Have all privs'
);

diag(`/tmp/12345/use -u root -e "CREATE USER 'bob'\@'\%' IDENTIFIED BY 'bob'"`);
diag(`/tmp/12345/use -u root -e "GRANT select ON issue_96.t TO 'bob'\@'\%'"`);
my $bob_dbh = DBI->connect(
   "DBI:mysql:;host=127.0.0.1;port=12345", 'bob', 'bob',
      { PrintError => 0, RaiseError => 1 });

is(
   $syncer->have_all_privs($bob_dbh, 'issue_96', 't'),
   0,
   "Don't have all privs, just select"
);

diag(`/tmp/12345/use -u root -e "GRANT insert ON issue_96.t TO 'bob'\@'\%'"`);
is(
   $syncer->have_all_privs($bob_dbh, 'issue_96', 't'),
   0,
   "Don't have all privs, just select and insert"
);

diag(`/tmp/12345/use -u root -e "GRANT update ON issue_96.t TO 'bob'\@'\%'"`);
is(
   $syncer->have_all_privs($bob_dbh, 'issue_96', 't'),
   0,
   "Don't have all privs, just select, insert and update"
);

diag(`/tmp/12345/use -u root -e "GRANT delete ON issue_96.t TO 'bob'\@'\%'"`);
is(
   $syncer->have_all_privs($bob_dbh, 'issue_96', 't'),
   1,
   "Bob got his privs"
);

diag(`/tmp/12345/use -u root -e "DROP USER 'bob'"`);

# ###########################################################################
# Test that the calback gives us the src and dst sql.
# ###########################################################################

# Re-using issue_96.t from above.  The tables are already in sync so there
# should only be 1 sync cycle.
@rows = ();
$args{ChangeHandler} = new_ch();
my @sqls;
$syncer->sync_table(%args, chunk_size => 1000, plugins => [$sync_nibble],
   callback => sub { push @sqls, @_; } );
is_deeply(
   \@sqls,
   [
      'SELECT /*issue_96.t:1/1*/ 0 AS chunk_num, COUNT(*) AS cnt, LOWER(CONCAT(LPAD(CONV(BIT_XOR(CAST(CONV(SUBSTRING(@crc, 1, 16), 16, 10) AS UNSIGNED)), 10, 16), 16, \'0\'), LPAD(CONV(BIT_XOR(CAST(CONV(SUBSTRING(@crc, 17, 16), 16, 10) AS UNSIGNED)), 10, 16), 16, \'0\'), LPAD(CONV(BIT_XOR(CAST(CONV(SUBSTRING(@crc := SHA1(CONCAT_WS(\'#\', `package_id`, `location`, `from_city`, CONCAT(ISNULL(`package_id`), ISNULL(`location`), ISNULL(`from_city`)))), 33, 8), 16, 10) AS UNSIGNED)), 10, 16), 8, \'0\'))) AS crc FROM `issue_96`.`t` FORCE INDEX (`package_id`) WHERE (1=1)',
      'SELECT /*issue_96.t2:1/1*/ 0 AS chunk_num, COUNT(*) AS cnt, LOWER(CONCAT(LPAD(CONV(BIT_XOR(CAST(CONV(SUBSTRING(@crc, 1, 16), 16, 10) AS UNSIGNED)), 10, 16), 16, \'0\'), LPAD(CONV(BIT_XOR(CAST(CONV(SUBSTRING(@crc, 17, 16), 16, 10) AS UNSIGNED)), 10, 16), 16, \'0\'), LPAD(CONV(BIT_XOR(CAST(CONV(SUBSTRING(@crc := SHA1(CONCAT_WS(\'#\', `package_id`, `location`, `from_city`, CONCAT(ISNULL(`package_id`), ISNULL(`location`), ISNULL(`from_city`)))), 33, 8), 16, 10) AS UNSIGNED)), 10, 16), 8, \'0\'))) AS crc FROM `issue_96`.`t2` FORCE INDEX (`package_id`) WHERE (1=1)',
   ],
   'Callback gives src and dst sql'
);


# #############################################################################
# Test that make_checksum_queries() doesn't pass replicate.
# #############################################################################

# Re-using table from above.

my @foo = $syncer->make_checksum_queries(%args, replicate => 'bad');
is_deeply(
   \@foo,
   [
      'SELECT /*PROGRESS_COMMENT*//*CHUNK_NUM*/ COUNT(*) AS cnt, LOWER(CONCAT(LPAD(CONV(BIT_XOR(CAST(CONV(SUBSTRING(@crc, 1, 16), 16, 10) AS UNSIGNED)), 10, 16), 16, \'0\'), LPAD(CONV(BIT_XOR(CAST(CONV(SUBSTRING(@crc, 17, 16), 16, 10) AS UNSIGNED)), 10, 16), 16, \'0\'), LPAD(CONV(BIT_XOR(CAST(CONV(SUBSTRING(@crc := SHA1(CONCAT_WS(\'#\', `package_id`, `location`, `from_city`, CONCAT(ISNULL(`package_id`), ISNULL(`location`), ISNULL(`from_city`)))), 33, 8), 16, 10) AS UNSIGNED)), 10, 16), 8, \'0\'))) AS crc FROM /*DB_TBL*//*INDEX_HINT*//*WHERE*/',
      '`package_id`, `location`, `from_city`, SHA1(CONCAT_WS(\'#\', `package_id`, `location`, `from_city`, CONCAT(ISNULL(`package_id`), ISNULL(`location`), ISNULL(`from_city`))))',
   ],
   'make_checksum_queries() does not pass replicate arg'
);

# #############################################################################
# Issue 464: Make mk-table-sync do two-way sync
# #############################################################################
diag(`$trunk/sandbox/start-sandbox master 12347 >/dev/null`);
my $dbh2 = $sb->get_dbh_for('slave2');
SKIP: {
   skip 'Cannot connect to sandbox master', 1 unless $dbh;
   skip 'Cannot connect to second sandbox master', 1 unless $dbh2;

   sub set_bidi_callbacks {
      $sync_chunk->set_callback('same_row', sub {
         my ( %args ) = @_;
         my ($lr, $rr, $syncer) = @args{qw(lr rr syncer)};
         my $ch = $syncer->{ChangeHandler};
         my $change_dbh;
         my $auth_row;

         my $left_ts  = $lr->{ts};
         my $right_ts = $rr->{ts};
         MKDEBUG && TableSyncer::_d("left ts: $left_ts");
         MKDEBUG && TableSyncer::_d("right ts: $right_ts");

         my $cmp = ($left_ts || '') cmp ($right_ts || '');
         if ( $cmp == -1 ) {
            MKDEBUG && TableSyncer::_d("right dbh $dbh2 is newer; update left dbh $src_dbh");
            $ch->set_src('right', $dbh2);
            $auth_row   = $args{rr};
            $change_dbh = $src_dbh;
         }
         elsif ( $cmp == 1 ) {
            MKDEBUG && TableSyncer::_d("left dbh $src_dbh is newer; update right dbh $dbh2");
            $ch->set_src('left', $src_dbh);
            $auth_row  = $args{lr};
            $change_dbh = $dbh2;
         }
         return ('UPDATE', $auth_row, $change_dbh);
      });
      $sync_chunk->set_callback('not_in_right', sub {
         my ( %args ) = @_;
         $args{syncer}->{ChangeHandler}->set_src('left', $src_dbh);
         return 'INSERT', $args{lr}, $dbh2;
      });
      $sync_chunk->set_callback('not_in_left', sub {
         my ( %args ) = @_;
         $args{syncer}->{ChangeHandler}->set_src('right', $dbh2);
         return 'INSERT', $args{rr}, $src_dbh;
      });
   };

   # Proper data on both tables after bidirectional sync.
   my $bidi_data = 
      [
         [1,   'abc',   1,  '2010-02-01 05:45:30'],
         [2,   'def',   2,  '2010-01-31 06:11:11'],
         [3,   'ghi',   5,  '2010-02-01 09:17:52'],
         [4,   'jkl',   6,  '2010-02-01 10:11:33'],
         [5,   undef,   0,  '2010-02-02 05:10:00'],
         [6,   'p',     4,  '2010-01-31 10:17:00'],
         [7,   'qrs',   5,  '2010-02-01 10:11:11'],
         [8,   'tuv',   6,  '2010-01-31 10:17:20'],
         [9,   'wxy',   7,  '2010-02-01 10:17:00'],
         [10,  'z',     8,  '2010-01-31 10:17:08'],
         [11,  '?',     0,  '2010-01-29 11:17:12'],
         [12,  '',      0,  '2010-02-01 11:17:00'],
         [13,  'hmm',   1,  '2010-02-02 12:17:31'],
         [14,  undef,   0,  '2010-01-31 10:17:00'],
         [15,  'gtg',   7,  '2010-02-02 06:01:08'],
         [17,  'good',  1,  '2010-02-02 21:38:03'],
         [20,  'new', 100,  '2010-02-01 04:15:36'],
      ];

   # ########################################################################
   # First bidi test with chunk size=2, roughly 9 chunks.
   # ########################################################################
   # Load "master" data.
   $sb->load_file('master', 'mk-table-sync/t/samples/bidirectional/table.sql');
   $sb->load_file('master', 'mk-table-sync/t/samples/bidirectional/master-data.sql');
   # Load remote data.
   $sb->load_file('slave2', 'mk-table-sync/t/samples/bidirectional/table.sql');
   $sb->load_file('slave2', 'mk-table-sync/t/samples/bidirectional/remote-1.sql');
   make_plugins();
   set_bidi_callbacks();
   $tbl_struct = $tp->parse($du->get_create_table($src_dbh, $q, 'bidi','t'));
   $args{tbl_struct}    = $tbl_struct;
   $args{cols}          = [qw(ts)],  # Compare only ts col when chunks differ.
   $src->{db}           = 'bidi';
   $src->{tbl}          = 't';
   $dst->{db}           = 'bidi';
   $dst->{tbl}          = 't';
   $dst->{dbh}          = $dbh2;            # Must set $dbh2 here and
   $args{ChangeHandler} = new_ch($dbh2, 0); # here to override $dst_dbh.
   @rows                = ();

   $syncer->sync_table(%args, plugins => [$sync_chunk]);

   my $res = $src_dbh->selectall_arrayref('select * from bidi.t order by id');
   is_deeply(
      $res,
      $bidi_data,
      'Bidirectional sync "master" (chunk size 2)'
   );

   $res = $dbh2->selectall_arrayref('select * from bidi.t order by id');
   is_deeply(
      $res,
      $bidi_data,
      'Bidirectional sync remote-1 (chunk size 2)'
   );

   # ########################################################################
   # Test it again with a larger chunk size, roughly half the table.
   # ########################################################################
   $sb->load_file('master', 'mk-table-sync/t/samples/bidirectional/table.sql');
   $sb->load_file('master', 'mk-table-sync/t/samples/bidirectional/master-data.sql');
   $sb->load_file('slave2', 'mk-table-sync/t/samples/bidirectional/table.sql');
   $sb->load_file('slave2', 'mk-table-sync/t/samples/bidirectional/remote-1.sql');
   make_plugins();
   set_bidi_callbacks();
   $args{ChangeHandler} = new_ch($dbh2, 0);
   @rows = ();

   $syncer->sync_table(%args, plugins => [$sync_chunk], chunk_size => 10);

   $res = $src_dbh->selectall_arrayref('select * from bidi.t order by id');
   is_deeply(
      $res,
      $bidi_data,
      'Bidirectional sync "master" (chunk size 10)'
   );

   $res = $dbh2->selectall_arrayref('select * from bidi.t order by id');
   is_deeply(
      $res,
      $bidi_data,
      'Bidirectional sync remote-1 (chunk size 10)'
   );

   # ########################################################################
   # Chunk whole table.
   # ########################################################################
   $sb->load_file('master', 'mk-table-sync/t/samples/bidirectional/table.sql');
   $sb->load_file('master', 'mk-table-sync/t/samples/bidirectional/master-data.sql');
   $sb->load_file('slave2', 'mk-table-sync/t/samples/bidirectional/table.sql');
   $sb->load_file('slave2', 'mk-table-sync/t/samples/bidirectional/remote-1.sql');
   make_plugins();
   set_bidi_callbacks();
   $args{ChangeHandler} = new_ch($dbh2, 0);
   @rows = ();

   $syncer->sync_table(%args, plugins => [$sync_chunk], chunk_size => 100000);

   $res = $src_dbh->selectall_arrayref('select * from bidi.t order by id');
   is_deeply(
      $res,
      $bidi_data,
      'Bidirectional sync "master" (whole table chunk)'
   );

   $res = $dbh2->selectall_arrayref('select * from bidi.t order by id');
   is_deeply(
      $res,
      $bidi_data,
      'Bidirectional sync remote-1 (whole table chunk)'
   );

   # ########################################################################
   # See TableSyncer.pm for why this is so.
   # ######################################################################## 
   $args{ChangeHandler} = new_ch($dbh2, 1);
   throws_ok(
      sub { $syncer->sync_table(%args, bidirectional => 1, plugins => [$sync_chunk]) },
      qr/Queueing does not work with bidirectional syncing/,
      'Queueing does not work with bidirectional syncing'
   );

   $sb->wipe_clean($dbh2);
   diag(`$trunk/sandbox/stop-sandbox remove 12347 >/dev/null &`);
}



# #############################################################################
# Test with transactions.
# #############################################################################

# Sandbox::get_dbh_for() defaults to AutoCommit=1.  Autocommit must
# be off else commit() will cause an error.
$dbh      = $sb->get_dbh_for('master', {AutoCommit=>0});
$src_dbh  = $sb->get_dbh_for('master', {AutoCommit=>0});
$dst_dbh  = $sb->get_dbh_for('slave1', {AutoCommit=>0});

make_plugins();
$tbl_struct = $tp->parse($du->get_create_table($src_dbh, $q,'test','test1'));
$src = {
   dbh      => $src_dbh,
   misc_dbh => $dbh,
   db       => 'test',
   tbl      => 'test1',
};
$dst = {
   dbh => $dst_dbh,
   db  => 'test',
   tbl => 'test2',
};
%args = (
   plugins       => $plugins,
   src           => $src,
   dst           => $dst,
   tbl_struct    => $tbl_struct,
   cols          => $tbl_struct->{cols},
   chunk_size    => 5,
   RowDiff       => $rd,
   ChangeHandler => undef,  # call new_ch()
   function      => 'SHA1',
   transaction   => 1,
   lock          => 1,
);
$args{ChangeHandler} = new_ch();
@rows = ();

# There are no diffs.  This just tests that the code doesn't crash
# when transaction is true.
$syncer->sync_table(%args);
is_deeply(
   \@rows,
   [],
   "Sync with transaction"
);

# #############################################################################
# Done.
# #############################################################################
my $output = '';
{
   local *STDERR;
   open STDERR, '>', \$output;
   $syncer->_d('Complete test coverage');
}
like(
   $output,
   qr/Complete test coverage/,
   '_d() works'
);
$sb->wipe_clean($src_dbh);
$sb->wipe_clean($dst_dbh);
exit;
