#!/usr/bin/perl

use strict;
use warnings FATAL => 'all';
use English qw(-no_match_vars);
use Test::More tests => 43;

# TableSyncer and its required modules:
require "../TableSyncer.pm";
require "../MasterSlave.pm";
require "../Quoter.pm";
require "../TableChecksum.pm";
require "../VersionParser.pm";
# The sync plugins:
require "../TableSyncChunk.pm";
require "../TableSyncNibble.pm";
require "../TableSyncGroupBy.pm";
require "../TableSyncStream.pm";
# Helper modules for the sync plugins:
require "../TableChunker.pm";
require "../TableNibbler.pm";
# Modules for sync():
require "../ChangeHandler.pm";
require "../RowDiff.pm";
# And other modules:
require "../MySQLDump.pm";
require "../TableParser.pm";
require '../DSNParser.pm';
require '../Sandbox.pm';
my $dp = new DSNParser();
my $sb = new Sandbox(basedir => '/tmp', DSNParser => $dp);
my $src_dbh  = $sb->get_dbh_for('master')
   or BAIL_OUT('Cannot connect to sandbox master');
my $dst_dbh  = $sb->get_dbh_for('slave1')
   or BAIL_OUT('Cannot connect to sandbox slave');
my $dbh      = $sb->get_dbh_for('master')
   or BAIL_OUT('Cannot connect to sandbox master');

use Data::Dumper;
$Data::Dumper::Indent    = 1;
$Data::Dumper::Sortkeys  = 1;
$Data::Dumper::Quotekeys = 0;

$sb->create_dbs($dbh, ['test']);
my $mysql = $sb->_use_for('master');
$sb->load_file('master', 'samples/before-TableSyncChunk.sql');

sub throws_ok {
   my ( $code, $pat, $msg ) = @_;
   eval { $code->(); };
   like( $EVAL_ERROR, $pat, $msg );
}

my $tp = new TableParser();
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
my $q        = new Quoter();
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
   [ $sync_nibble, { chunk_index => 'a', key_cols => [qw(a)], } ],
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
   "INSERT INTO `test`.`test2`(`a`, `b`) VALUES (1, 'en')",
   "INSERT INTO `test`.`test2`(`a`, `b`) VALUES (2, 'ca')",
   "INSERT INTO `test`.`test2`(`a`, `b`) VALUES (3, 'ab')",
   "INSERT INTO `test`.`test2`(`a`, `b`) VALUES (4, 'bz')",
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
   return new ChangeHandler(
      Quoter  => $q,
      src_db  => $src->{db},
      src_tbl => $src->{tbl},
      dst_db  => $dst->{db},
      dst_tbl => $dst->{tbl},
      actions => [ sub { push @rows, @_; $dst_dbh->do(@_); } ],
      replace => 0,
      queue   => 1,
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

$sb->load_file('master', 'samples/before-TableSyncGroupBy.sql');
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

$sb->load_file('master', 'samples/issue_96.sql');
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
      'SHA1(CONCAT_WS(\'#\', `package_id`, `location`, `from_city`, CONCAT(ISNULL(`package_id`), ISNULL(`location`), ISNULL(`from_city`))))',
   ],
   'make_checksum_queries() does not pass replicate arg'
);

# #############################################################################
# Done.
# #############################################################################
$sb->wipe_clean($dbh);
exit;
