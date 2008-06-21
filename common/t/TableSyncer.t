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
my ( $src_dbh, $dst_dbh, $dbh );
eval {
   $src_dbh = DBI->connect( "DBI:mysql:;mysql_read_default_group=mysql",
      undef, undef, { PrintError => 0, RaiseError => 1 } );
   $dst_dbh = DBI->connect( "DBI:mysql:;mysql_read_default_group=mysql",
      undef, undef, { PrintError => 0, RaiseError => 1 } );
   $dbh = DBI->connect( "DBI:mysql:;mysql_read_default_group=mysql",
      undef, undef, { PrintError => 0, RaiseError => 1 } );
};
if ($src_dbh) {
   plan tests => 16;
}
else {
   plan skip_all => 'Cannot connect to MySQL';
}

require "../ChangeHandler.pm";
require "../MySQLDump.pm";
require "../Quoter.pm";
require "../RowDiff.pm";
require "../TableChecksum.pm";
require "../TableChunker.pm";
require "../TableNibbler.pm";
require "../TableParser.pm";
require "../TableSyncChunk.pm";
require "../TableSyncer.pm";
require "../TableSyncStream.pm";
require "../TableSyncGroupBy.pm";
require "../TableSyncNibble.pm";
require "../VersionParser.pm";
require "../MasterSlave.pm";

sub throws_ok {
   my ( $code, $pat, $msg ) = @_;
   eval { $code->(); };
   like( $EVAL_ERROR, $pat, $msg );
}

`mysql < samples/before-TableSyncChunk.sql`;

my $ts         = new TableSyncer();
my $tp         = new TableParser();
my $du         = new MySQLDump();
my $q          = new Quoter();
my $vp         = new VersionParser();
my $ddl        = $du->get_create_table( $src_dbh, $q, 'test', 'test1' );
my $tbl_struct = $tp->parse($ddl);
my $chunker    = new TableChunker( quoter => $q );
my $checksum   = new TableChecksum();
my $nibbler    = new TableNibbler();
my $ms         = new MasterSlave();
my ( $rows, $cnt );

my $algo = $ts->best_algorithm(
   tbl_struct  => $tbl_struct,
   nibbler     => $nibbler,
   chunker     => $chunker,
   parser      => $tp,
);

ok( $algo, 'Found an algorithm' );

is($ts->best_algorithm(
      tbl_struct  => $tp->parse(
                     $du->get_create_table( $src_dbh, $q, 'test', 'test5' )),
      nibbler     => $nibbler,
      chunker     => $chunker,
      parser      => $tp,
   ),
   'GroupBy',
   'Got GroupBy algorithm',
);

my %args = (
   buffer        => 0,
   checksum      => $checksum,
   chunker       => $chunker,
   chunksize     => 2,
   dst_dbh       => $dst_dbh,
   dumper        => $du,
   execute       => 1,
   lock          => 0,
   misc_dbh      => $src_dbh,
   print         => 0,
   quoter        => $q,
   replace       => 0,
   replicate     => 0,
   src_dbh       => $src_dbh,
   tbl_struct    => $tbl_struct,
   timeoutok     => 0,
   transaction   => 0,
   versionparser => $vp,
   wait          => 0,
   where         => '',
   possible_keys => [],
   cols          => $tbl_struct->{cols},
   test          => 0,
   nibbler       => $nibbler,
   parser        => $tp,
   master_slave  => $ms,
   func          => 'SHA1',
   trim          => 0,
);

# This should die because of a bad algorithm.
throws_ok (
   sub { $ts->sync_table(
      %args,
      algorithm     => 'fibble',
      dst_db        => 'test',
      dst_tbl       => 'test2',
      src_db        => 'test',
      src_tbl       => 'test1',
   ) },
   qr/No such algorithm/,
   'Unknown algorithm',
);

# This should be OK even though the algorithm is in the wrong lettercase.
$ts->sync_table(
   %args,
   algorithm     => 'ChUnK',
   dst_db        => 'test',
   dst_tbl       => 'test2',
   src_db        => 'test',
   src_tbl       => 'test1',
   test          => 1,
);

# This should be OK because it ought to choose an algorithm automatically.
$ts->sync_table(
   %args,
   # NOTE: no algorithm
   dst_db        => 'test',
   dst_tbl       => 'test2',
   src_db        => 'test',
   src_tbl       => 'test1',
   test          => 1,
);

# Nothing should happen because I gave the 'test' argument.
$cnt = $dbh->selectall_arrayref('select count(*) from test.test2')
   ->[0]->[0];
is( $cnt, 0, 'Nothing happened' );

$ts->sync_table(
   %args,
   algorithm     => 'Chunk',
   dst_db        => 'test',
   dst_tbl       => 'test2',
   src_db        => 'test',
   src_tbl       => 'test1',
);

$cnt = $dbh->selectall_arrayref('select count(*) from test.test2')
   ->[0]->[0];
is( $cnt, 4, 'Four rows in destination after Chunk' );

`mysql < samples/before-TableSyncChunk.sql`;

# This should be OK because it ought to convert the size to rows.
$ts->sync_table(
   %args,
   chunksize     => '1k',
   algorithm     => 'Chunk',
   dst_db        => 'test',
   dst_tbl       => 'test2',
   src_db        => 'test',
   src_tbl       => 'test1',
);

`mysql < samples/before-TableSyncChunk.sql`;

$ts->sync_table(
   %args,
   algorithm     => 'Stream',
   dst_db        => 'test',
   dst_tbl       => 'test2',
   src_db        => 'test',
   src_tbl       => 'test1',
);

$cnt = $dbh->selectall_arrayref('select count(*) from test.test2')->[0]->[0];
is( $cnt, 4, 'Four rows in destination after Stream' );

`mysql < samples/before-TableSyncChunk.sql`;

$ts->sync_table(
   %args,
   algorithm     => 'GroupBy',
   dst_db        => 'test',
   dst_tbl       => 'test2',
   src_db        => 'test',
   src_tbl       => 'test1',
);

$cnt = $dbh->selectall_arrayref('select count(*) from test.test2')->[0]->[0];
is( $cnt, 4, 'Four rows in destination after GroupBy' );

print `mysql < samples/before-TableSyncGroupBy.sql`;

$ts->sync_table(
   %args,
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

`mysql < samples/before-TableSyncChunk.sql`;

$ts->sync_table(
   %args,
   algorithm     => 'Nibble',
   dst_db        => 'test',
   dst_tbl       => 'test2',
   src_db        => 'test',
   src_tbl       => 'test1',
);

$cnt = $dbh->selectall_arrayref('select count(*) from test.test2')->[0]->[0];
is( $cnt, 4, 'Four rows in destination after Nibble' );

`mysql < samples/before-TableSyncChunk.sql`;

$ts->sync_table(
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

`mysql < samples/before-TableSyncChunk.sql`;

$ts->sync_table(
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

`mysql < samples/before-TableSyncChunk.sql`;

$ts->sync_table(
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

$ts->sync_table(
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

$ts->sync_table(
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
   $ts->lock_and_wait(
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

# kill the DBHs, but do it in the right order... there's a connection waiting on
# a lock.
$src_dbh->disconnect;
$dst_dbh->disconnect;
$dbh->disconnect;

`mysql < samples/after-TableSyncChunk.sql`;
