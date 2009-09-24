#!/usr/bin/perl

use strict;
use warnings FATAL => 'all';
use English qw(-no_match_vars);
use Test::More tests => 19;

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
my $chunker    = new TableChunker( Quoter => $q, MySQLDump => $du );
my $sync_chunk = new TableSyncChunk(
   TableChunker => $chunker,
   Quoter       => $q,
);

my $nibbler     = new TableNibbler( TableParser => $tp, Quoter => $q );
my $sync_nibble = new TableSyncNibble(
   TableNibbler  => $nibbler,
   TableChunker  => $chunker,
   TableParser   => $tp,
   Quoter        => $q,
);

# TODO:
my $sync_groupby = new TableSyncGroupBy( Quoter => $q );
my $sync_stream  = new TableSyncStream( Quoter => $q );

my $plugins = [$sync_chunk, $sync_nibble, $sync_groupby, $sync_stream];

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
   [ $sync_groupby, 1 ],
   'Got GroupBy algorithm',
);

$tbl_struct = $tp->parse($du->get_create_table($src_dbh, $q,'test','test3'));
is_deeply(
   [
      $syncer->get_best_plugin(
         plugins     => $plugins,
         tbl_struct  => $tbl_struct,
      )
   ],
   [ $sync_chunk, { chunk_col => 'a', chunk_index => 'PRIMARY' } ],
   'Got Chunk algorithm',
);

# ###########################################################################
# Test sync_table().
# ###########################################################################

# Redo this in case any tests above change $tbl_struct.
$tbl_struct = $tp->parse($du->get_create_table($src_dbh, $q,'test','test3'));

my $src = {
   dbh      => $src_dbh,
   misc_dbh => $dbh,
   db       => 'test',
   tbl      => 'test3',
};
my $dst = {
   dbh => $dst_dbh,
   db  => 'test',
   tbl => 'test3',
};
my $rd = new RowDiff(dbh=>$src_dbh);
my @rows;
my $ch = new ChangeHandler(
   Quoter  => $q,
   src_db  => $src->{db},
   src_tbl => $src->{tbl},
   dst_db  => $dst->{db},
   dst_tbl => $dst->{tbl},
   actions => [ sub { push @rows, @_ } ],
   replace => 0,
   queue   => 0,
);
my %args = (
   plugins        => $plugins,
   src            => $src,
   dst            => $dst,
   tbl_struct     => $tbl_struct,
   cols           => $tbl_struct->{cols},
   chunk_size     => 2,
   RowDiff        => $rd,
   ChangeHandler  => $ch,
   function       => 'SHA1',
);

# Add a row to dst.test.test3 to make it differ.
$dst_dbh->do('INSERT INTO test.test3 VALUES (3,3)');

# Do a dry run sync, so nothing should happen.
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

my $src_rows = $src_dbh->selectrow_arrayref('select count(*) from test.test3');
my $dst_rows = $dst_dbh->selectrow_arrayref('select count(*) from test.test3');
ok(
   $src_rows->[0] == 2 && $dst_rows->[0] == 3,
   'Nothing happened, src and dst still out of sync'
);

# Now do a real run so the tables are synced.
is_deeply(
   { $syncer->sync_table(%args) },
   {
      DELETE    => 1,
      INSERT    => 0,
      REPLACE   => 0,
      UPDATE    => 0,
      ALGORITHM => 'Chunk',
   },
   'Synced tables with 1 DELETE',
);

is_deeply(
   \@rows,
   [ 'DELETE FROM `test`.`test3` WHERE `a`=3 LIMIT 1' ],
   'ChangeHandler made the DELETE statement'
);

$src_rows = $src_dbh->selectrow_arrayref('select count(*) from test.test3');
$dst_rows = $dst_dbh->selectrow_arrayref('select count(*) from test.test3');
ok(
   $src_rows->[0] == 2 && $dst_rows->[0] == 3,
   'Nothing happened because no action executed the DELETE statement'
);

exit;
diag(`$mysql < samples/before-TableSyncChunk.sql`);

# This should be OK because it ought to convert the size to rows.
$syncer->sync_table(
   %args,
   chunksize     => '1k',
   algorithm     => 'Chunk',
   dst_db        => 'test',
   dst_tbl       => 'test2',
   src_db        => 'test',
   src_tbl       => 'test1',
);

diag(`$mysql < samples/before-TableSyncChunk.sql`);

$syncer->sync_table(
   %args,
   algorithm     => 'Stream',
   dst_db        => 'test',
   dst_tbl       => 'test2',
   src_db        => 'test',
   src_tbl       => 'test1',
);

$cnt = $dbh->selectall_arrayref('select count(*) from test.test2')->[0]->[0];
is( $cnt, 4, 'Four rows in destination after Stream' );

diag(`$mysql < samples/before-TableSyncChunk.sql`);

$syncer->sync_table(
   %args,
   algorithm     => 'GroupBy',
   dst_db        => 'test',
   dst_tbl       => 'test2',
   src_db        => 'test',
   src_tbl       => 'test1',
);

$cnt = $dbh->selectall_arrayref('select count(*) from test.test2')->[0]->[0];
is( $cnt, 4, 'Four rows in destination after GroupBy' );

diag(`$mysql < samples/before-TableSyncGroupBy.sql`);

my $ddl2        = $du->get_create_table( $src_dbh, $q, 'test', 'test1' );
my $tbl_struct2 = $tp->parse($ddl2);

$syncer->sync_table(
   %args,
   tbl_struct    => $tbl_struct2,
   cols          => [qw(a b c)],
   algorithm     => 'GroupBy',
   dst_db        => 'test',
   dst_tbl       => 'test2',
   src_db        => 'test',
   src_tbl       => 'test1',
);

$rows = $dbh->selectall_arrayref('select * from test.test2 order by a, b, c', { Slice => {}} );
is_deeply($rows,
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

diag(`$mysql < samples/before-TableSyncChunk.sql`);

$syncer->sync_table(
   %args,
   algorithm     => 'Nibble',
   dst_db        => 'test',
   dst_tbl       => 'test2',
   src_db        => 'test',
   src_tbl       => 'test1',
);

$cnt = $dbh->selectall_arrayref('select count(*) from test.test2')->[0]->[0];
is( $cnt, 4, 'Four rows in destination after Nibble' );

diag(`$mysql < samples/before-TableSyncChunk.sql`);

$syncer->sync_table(
   %args,
   algorithm     => 'Stream',
   dst_db        => 'test',
   dst_tbl       => 'test4',
   src_db        => 'test',
   src_tbl       => 'test3',
);

$rows = $dbh->selectall_arrayref(
   'select * from test.test4 order by a', { Slice => {}} );
is_deeply($rows,
   [ { a => 1, b => 2 }, { a => 2, b => 1 } ],
   'Resolves unique key violations with Stream' );

diag(`$mysql < samples/before-TableSyncChunk.sql`);


$syncer->sync_table(
   %args,
   algorithm     => 'Chunk',
   dst_db        => 'test',
   dst_tbl       => 'test4',
   src_db        => 'test',
   src_tbl       => 'test3',
);

$rows = $dbh->selectall_arrayref(
   'select * from test.test4 order by a', { Slice => {}} );
is_deeply($rows,
   [ { a => 1, b => 2 }, { a => 2, b => 1 } ],
   'Resolves unique key violations with Chunk' );

diag(`$mysql < samples/before-TableSyncChunk.sql`);

$syncer->sync_table(
   %args,
   lock          => 1, # !!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!
   algorithm     => 'Chunk',
   dst_db        => 'test',
   dst_tbl       => 'test4',
   src_db        => 'test',
   src_tbl       => 'test3',
);

# The locks should be released.
ok($src_dbh->do('select * from test.test4'), 'cycle locks released');

$syncer->sync_table(
   %args,
   lock          => 2, # !!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!
   algorithm     => 'Chunk',
   dst_db        => 'test',
   dst_tbl       => 'test4',
   src_db        => 'test',
   src_tbl       => 'test3',
);

# The locks should be released.
ok($src_dbh->do('select * from test.test4'), 'table locks released');

$syncer->sync_table(
   %args,
   lock          => 3, # !!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!
   algorithm     => 'Chunk',
   dst_db        => 'test',
   dst_tbl       => 'test4',
   src_db        => 'test',
   src_tbl       => 'test3',
);

ok($dbh->do('replace into test.test3 select * from test.test3 limit 0'),
   'sync_table does not lock in level 3 locking');

eval {
   $syncer->lock_and_wait(
      %args,
      lock          => 3, # !!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!
      algorithm     => 'Chunk',
      dst_db        => 'test',
      dst_tbl       => 'test4',
      src_db        => 'test',
      src_tbl       => 'test3',
      lock_level    => 3
   );
};
is ($EVAL_ERROR, '', 'Locks in level 3');

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
$src_dbh->disconnect;
$dst_dbh->disconnect;
$src_dbh = $sb->get_dbh_for('master');
$dst_dbh = $sb->get_dbh_for('master');
$args{src_dbh} = $src_dbh;
$args{dst_dbh} = $dst_dbh;

# #############################################################################
# Issue 96: mk-table-sync: Nibbler infinite loop
# #############################################################################
$sb->load_file('master', 'samples/issue_96.sql');
$tbl_struct = $tp->parse($du->get_create_table($src_dbh, $q, 'issue_96', 't'));
@args{qw(tbl_struct cols)} = ($tbl_struct, $tbl_struct->{cols});

# Make paranoid-sure that the tables differ.
my $r1 = $dbh->selectall_arrayref('SELECT from_city FROM issue_96.t WHERE package_id=4');
my $r2 = $dbh->selectall_arrayref('SELECT from_city FROM issue_96.t2 WHERE package_id=4');
is_deeply(
   [ $r1->[0]->[0], $r2->[0]->[0] ],
   [ 'ta',          'zz'          ],
   'Infinite loop table differs (issue 96)'
);

$syncer->sync_table(
   %args,
   algorithm     => 'Nibble',
   dst_db        => 'issue_96',
   dst_tbl       => 't2',
   src_db        => 'issue_96',
   src_tbl       => 't',
);

$r1 = $dbh->selectall_arrayref('SELECT from_city FROM issue_96.t WHERE package_id=4');
$r2 = $dbh->selectall_arrayref('SELECT from_city FROM issue_96.t2 WHERE package_id=4');
is(
   $r1->[0]->[0],
   $r2->[0]->[0],
   'Sync infinite loop table (issue 96)'
);

# Remember to reset @args{qw(tbl_struct cols)} for new tests!

# #############################################################################
# Done.
# #############################################################################
$sb->wipe_clean($dbh);
exit;
