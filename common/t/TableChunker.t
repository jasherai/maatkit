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

use TableParser;
use TableChunker;
use MySQLDump;
use Quoter;
use DSNParser;
use Sandbox;
use MaatkitTest;

my $dp = new DSNParser();
my $sb = new Sandbox(basedir => '/tmp', DSNParser => $dp);
my $dbh = $sb->get_dbh_for('master');

if ( !$dbh ) {
   plan skip_all => 'Cannot connect to sandbox master';
}
else {
   plan tests => 38;
}

$sb->create_dbs($dbh, ['test']);

my $q  = new Quoter();
my $p  = new TableParser(Quoter => $q);
my $du = new MySQLDump();
my $c  = new TableChunker(Quoter => $q, MySQLDump => $du);
my $t;

$t = $p->parse( load_file('common/t/samples/sakila.film.sql') );
is_deeply(
   [ $c->find_chunk_columns(tbl_struct=>$t) ],
   [ 0,
     { column => 'film_id', index => 'PRIMARY' },
     { column => 'language_id', index => 'idx_fk_language_id' },
     { column => 'original_language_id',
       index => 'idx_fk_original_language_id' },
   ],
   'Found chunkable columns on sakila.film',
);

is_deeply(
   [ $c->find_chunk_columns(tbl_struct=>$t, exact => 1) ],
   [ 1, { column => 'film_id', index => 'PRIMARY' } ],
   'Found exact chunkable columns on sakila.film',
);

# This test was removed because possible_keys was only used (vaguely)
# by mk-table-sync/TableSync* but this functionality is now handled
# in TableSync*::can_sync() with the optional args col and index.
# In other words: it's someone else's job to get/check the preferred index.
#is_deeply(
#   [ $c->find_chunk_columns($t, { possible_keys => [qw(idx_fk_language_id)] }) ],
#   [ 0,
#     [
#        { column => 'language_id', index => 'idx_fk_language_id' },
#        { column => 'original_language_id',
#             index => 'idx_fk_original_language_id' },
#        { column => 'film_id', index => 'PRIMARY' },
#     ]
#   ],
#   'Found preferred chunkable columns on sakila.film',
#);

$t = $p->parse( load_file('common/t/samples/pk_not_first.sql') );
is_deeply(
   [ $c->find_chunk_columns(tbl_struct=>$t) ],
   [ 0,
     { column => 'film_id', index => 'PRIMARY' },
     { column => 'language_id', index => 'idx_fk_language_id' },
     { column => 'original_language_id',
        index => 'idx_fk_original_language_id' },
   ],
   'PK column is first',
);

is(
   $c->inject_chunks(
      query     => 'SELECT /*PROGRESS_COMMENT*//*CHUNK_NUM*/ FOO FROM 1/*WHERE*/',
      database  => 'sakila',
      table     => 'film',
      chunks    => [ '1=1', 'a=b' ],
      chunk_num => 1,
      where     => ['FOO=BAR'],
   ),
   'SELECT /*sakila.film:2/2*/ 1 AS chunk_num, FOO FROM 1 WHERE (a=b) AND ((FOO=BAR))',
   'Replaces chunk info into query',
);

is(
   $c->inject_chunks(
      query     => 'SELECT /*PROGRESS_COMMENT*//*CHUNK_NUM*/ FOO FROM 1/*WHERE*/',
      database  => 'sakila',
      table     => 'film',
      chunks    => [ '1=1', 'a=b' ],
      chunk_num => 1,
      where     => ['FOO=BAR', undef],
   ),
   'SELECT /*sakila.film:2/2*/ 1 AS chunk_num, FOO FROM 1 WHERE (a=b) AND ((FOO=BAR))',
   'Inject WHERE clause with undef item',
);

is(
   $c->inject_chunks(
      query     => 'SELECT /*PROGRESS_COMMENT*//*CHUNK_NUM*/ FOO FROM 1/*WHERE*/',
      database  => 'sakila',
      table     => 'film',
      chunks    => [ '1=1', 'a=b' ],
      chunk_num => 1,
      where     => ['FOO=BAR', 'BAZ=BAT'],
   ),
   'SELECT /*sakila.film:2/2*/ 1 AS chunk_num, FOO FROM 1 WHERE (a=b) '
      . 'AND ((FOO=BAR) AND (BAZ=BAT))',
   'Inject WHERE with defined item',
);

# #############################################################################
# Sandbox tests.
# #############################################################################
SKIP: {
   skip 'Sandbox master does not have the sakila database', 21
      unless @{$dbh->selectcol_arrayref('SHOW DATABASES LIKE "sakila"')};

   my @chunks;

   @chunks = $c->calculate_chunks(
      tbl_struct    => $t,
      chunk_col     => 'film_id',
      min           => 0,
      max           => 99,
      rows_in_range => 100,
      chunk_size    => 30,
      dbh           => $dbh,
   );
   is_deeply(
      \@chunks,
      [
         '`film_id` < 30',
         '`film_id` >= 30 AND `film_id` < 60',
         '`film_id` >= 60 AND `film_id` < 90',
         '`film_id` >= 90',
      ],
      'Got the right chunks from dividing 100 rows into 30-row chunks',
   );

   @chunks = $c->calculate_chunks(
      tbl_struct    => $t,
      chunk_col     => 'film_id',
      min           => 0,
      max           => 99,
      rows_in_range => 100,
      chunk_size    => 300,
      dbh           => $dbh,
   );
   is_deeply(
      \@chunks,
      [
         '1=1',
      ],
      'Got the right chunks from dividing 100 rows into 300-row chunks',
   );

   @chunks = $c->calculate_chunks(
      tbl_struct    => $t,
      chunk_col     => 'film_id',
      min           => 0,
      max           => 0,
      rows_in_range => 100,
      chunk_size    => 300,
      dbh           => $dbh,
   );
   is_deeply(
      \@chunks,
      [
         '1=1',
      ],
      'No rows, so one chunk',
   );

   @chunks = $c->calculate_chunks(
      tbl_struct    => $t,
      chunk_col     => 'original_language_id',
      min           => 0,
      max           => 99,
      rows_in_range => 100,
      chunk_size    => 50,
      dbh           => $dbh,
   );
   is_deeply(
      \@chunks,
      [
         '`original_language_id` < 50',
         '`original_language_id` >= 50',
         '`original_language_id` IS NULL',
      ],
      'Nullable column adds IS NULL chunk',
   );

   $t = $p->parse( load_file('common/t/samples/daycol.sql') );

   @chunks = $c->calculate_chunks(
      tbl_struct    => $t,
      chunk_col     => 'a',
      min           => '2001-01-01',
      max           => '2002-01-01',
      rows_in_range => 365,
      chunk_size    => 90,
      dbh           => $dbh,
   );
   is_deeply(
      \@chunks,
      [
         '`a` < "2001-04-01"',
         '`a` >= "2001-04-01" AND `a` < "2001-06-30"',
         '`a` >= "2001-06-30" AND `a` < "2001-09-28"',
         '`a` >= "2001-09-28" AND `a` < "2001-12-27"',
         '`a` >= "2001-12-27"',
      ],
      'Date column chunks OK',
   );

   $t = $p->parse( load_file('common/t/samples/date.sql') );
   @chunks = $c->calculate_chunks(
      tbl_struct    => $t,
      chunk_col     => 'a',
      min           => '2000-01-01',
      max           => '2005-11-26',
      rows_in_range => 3,
      chunk_size    => 1,
      dbh           => $dbh,
   );
   is_deeply(
      \@chunks,
      [
         '`a` < "2001-12-20"',
         '`a` >= "2001-12-20" AND `a` < "2003-12-09"',
         '`a` >= "2003-12-09"',
      ],
      'Date column chunks OK',
   );

   @chunks = $c->calculate_chunks(
      tbl_struct    => $t,
      chunk_col     => 'a',
      min           => '0000-00-00',
      max           => '2005-11-26',
      rows_in_range => 3,
      chunk_size    => 1,
      dbh           => $dbh,
   );
   is_deeply(
      \@chunks,
      [
         '`a` < "0668-08-20"',
         '`a` >= "0668-08-20" AND `a` < "1337-04-09"',
         '`a` >= "1337-04-09"',
      ],
      'Date column where min date is 0000-00-00',
   );

   $t = $p->parse( load_file('common/t/samples/datetime.sql') );
   @chunks = $c->calculate_chunks(
      tbl_struct    => $t,
      chunk_col     => 'a',
      min           => '1922-01-14 05:18:23',
      max           => '2005-11-26 00:59:19',
      rows_in_range => 3,
      chunk_size    => 1,
      dbh           => $dbh,
   );
   is_deeply(
      \@chunks,
      [
         '`a` < "1949-12-28 19:52:02"',
         '`a` >= "1949-12-28 19:52:02" AND `a` < "1977-12-12 10:25:41"',
         '`a` >= "1977-12-12 10:25:41"',
      ],
      'Datetime column chunks OK',
   );

   @chunks = $c->calculate_chunks(
      tbl_struct    => $t,
      chunk_col     => 'a',
      min           => '0000-00-00 00:00:00',
      max           => '2005-11-26 00:59:19',
      rows_in_range => 3,
      chunk_size    => 1,
      dbh           => $dbh,
   );
   is_deeply(
      \@chunks,
      [
         '`a` < "0668-08-19 16:19:47"',
         '`a` >= "0668-08-19 16:19:47" AND `a` < "1337-04-08 08:39:34"',
         '`a` >= "1337-04-08 08:39:34"',
      ],
      'Datetime where min is 0000-00-00 00:00:00',
   );

   $t = $p->parse( load_file('common/t/samples/timecol.sql') );
   @chunks = $c->calculate_chunks(
      tbl_struct    => $t,
      chunk_col     => 'a',
      min           => '00:59:19',
      max           => '09:03:15',
      rows_in_range => 3,
      chunk_size    => 1,
      dbh           => $dbh,
   );
   is_deeply(
      \@chunks,
      [
         '`a` < "03:40:38"',
         '`a` >= "03:40:38" AND `a` < "06:21:57"',
         '`a` >= "06:21:57"',
      ],
      'Time column chunks OK',
   );

   $t = $p->parse( load_file('common/t/samples/doublecol.sql') );
   @chunks = $c->calculate_chunks(
      tbl_struct    => $t,
      chunk_col     => 'a',
      min           => '1',
      max           => '99.999',
      rows_in_range => 3,
      chunk_size    => 1,
      dbh           => $dbh,
   );
   is_deeply(
      \@chunks,
      [
         '`a` < 33.99966',
         '`a` >= 33.99966 AND `a` < 66.99933',
         '`a` >= 66.99933',
      ],
      'Double column chunks OK',
   );

   @chunks = $c->calculate_chunks(
      tbl_struct    => $t,
      chunk_col     => 'a',
      min           => '1',
      max           => '2',
      rows_in_range => 5,
      chunk_size    => 3,
      dbh           => $dbh,
   );
   is_deeply(
      \@chunks,
      [
         '`a` < 1.6',
         '`a` >= 1.6',
      ],
      'Double column chunks OK with smaller-than-int values',
   );

   eval {
      @chunks = $c->calculate_chunks(
         tbl_struct    => $t,
         chunk_col     => 'a',
         min           => '1',
         max           => '2',
         rows_in_range => 50000000,
         chunk_size    => 3,
         dbh           => $dbh,
      );
   };
   is(
      $EVAL_ERROR,
      "Chunk size is too small: 1.00000 !> 1\n",
      'Throws OK when too many chunks',
   );

   $t = $p->parse( load_file('common/t/samples/floatcol.sql') );
   @chunks = $c->calculate_chunks(
      tbl_struct    => $t,
      chunk_col     => 'a',
      min           => '1',
      max           => '99.999',
      rows_in_range => 3,
      chunk_size    => 1,
      dbh           => $dbh,
   );
   is_deeply(
      \@chunks,
      [
         '`a` < 33.99966',
         '`a` >= 33.99966 AND `a` < 66.99933',
         '`a` >= 66.99933',
      ],
      'Float column chunks OK',
   );

   $t = $p->parse( load_file('common/t/samples/decimalcol.sql') );
   @chunks = $c->calculate_chunks(
      tbl_struct    => $t,
      chunk_col     => 'a',
      min           => '1',
      max           => '99.999',
      rows_in_range => 3,
      chunk_size    => 1,
      dbh           => $dbh,
   );
   is_deeply(
      \@chunks,
      [
         '`a` < 33.99966',
         '`a` >= 33.99966 AND `a` < 66.99933',
         '`a` >= 66.99933',
      ],
      'Decimal column chunks OK',
   );

   throws_ok(
      sub { $c->get_range_statistics(
            dbh       => $dbh,
            db        => 'sakila',
            tbl       => 'film',
            chunk_col => 'film_id',
            where     => 'film_id>'
         )
      },
      qr/WHERE clause: /,
      'shows full SQL on error',
   );

   throws_ok(
      sub { $c->size_to_rows(
            dbh        => $dbh,
            db         => 'sakila',
            tbl        => 'film',
            chunk_size => 'foo'
         )
      },
      qr/Invalid chunk size/,
      'Rejects chunk size',
   );

   is(
      $c->size_to_rows(
         dbh        => $dbh,
         db         => 'sakila',
         tbl        => 'film',
         chunk_size => '5'
      ),
      5,
      'Numeric size'
   );
   my $size = $c->size_to_rows(
      dbh        => $dbh,
      db         => 'sakila',
      tbl        => 'film',
      chunk_size => '5k'
   );
   ok($size >= 20 && $size <= 30, 'Convert bytes to rows');

   my $avg;
   ($size, $avg) = $c->size_to_rows(
      dbh        => $dbh,
      db         => 'sakila',
      tbl        => 'film',
      chunk_size => '5k'
   );
   # This may fail because Rows and Avg_row_length can vary
   # slightly for InnoDB tables.
   ok(
      $avg >= 173 && $avg <= 206,
      "size_to_rows() returns avg row len in list context (173<=$avg<=206)"
   );

   ($size, $avg) = $c->size_to_rows(
      dbh            => $dbh,
      db             => 'sakila',
      tbl            => 'film',
      chunk_size     => 5,
      avg_row_length => 1,
   );
   ok(
      $size == 5 && ($avg >= 173 && $avg <= 206),
      'size_to_rows() gets avg row length if asked'
   );
};

# #############################################################################
# Issue 47: TableChunker::range_num broken for very large bigint
# #############################################################################
$sb->load_file('master', 'common/t/samples/issue_47.sql');
$t = $p->parse( $du->get_create_table($dbh, $q, 'test', 'issue_47') );
my %params = $c->get_range_statistics(
   dbh       => $dbh,
   db        => 'test',
   tbl       => 'issue_47',
   chunk_col => 'userid'
);
my @chunks;
eval {
   @chunks = $c->calculate_chunks(
      dbh        => $dbh,
      tbl_struct => $t,
      chunk_col  => 'userid',
      chunk_size => '4',
      %params,
   );
};
unlike($EVAL_ERROR, qr/Chunk size is too small/, 'Does not die chunking unsigned bitint (issue 47)');

# #############################################################################
# Issue 8: Add --force-index parameter to mk-table-checksum and mk-table-sync
# #############################################################################
is(
   $c->inject_chunks(
      query       => 'SELECT /*CHUNK_NUM*/ FROM /*DB_TBL*//*INDEX_HINT*//*WHERE*/',
      database    => 'test',
      table       => 'issue_8',
      chunks      => [ '1=1', 'a=b' ],
      chunk_num   => 1,
      where       => [],
      index_hint  => 'USE INDEX (`idx_a`)',
   ),
   'SELECT  1 AS chunk_num, FROM `test`.`issue_8` USE INDEX (`idx_a`) WHERE (a=b)',
   'Adds USE INDEX (issue 8)'
);

$sb->load_file('master', 'common/t/samples/issue_8.sql');
$t = $p->parse( $du->get_create_table($dbh, $q, 'test', 'issue_8') );
my @candidates = $c->find_chunk_columns(tbl_struct=>$t);
is_deeply(
   \@candidates,
   [
      0,
      { column => 'id',    index => 'PRIMARY'  },
      { column => 'foo',   index => 'uidx_foo' },
   ],
   'find_chunk_columns() returns col and idx candidates'
);

# #############################################################################
# Issue 941: mk-table-checksum chunking should treat zero dates similar to NULL
# #############################################################################
use Data::Dumper;
$Data::Dumper::Indent    = 1;
$Data::Dumper::Sortkeys  = 1;
$Data::Dumper::Quotekeys = 0;

# These tables have rows like: 0, 100, 101, 102, etc.  Without the
# zero-row option, the result is like:
#   range stats:
#     min           => '0',
#     max           => '107',
#     rows_in_range => '9'
#   chunks:
#     '`i` < 24',
#     '`i` >= 24 AND `i` < 48',
#     '`i` >= 48 AND `i` < 72',
#     '`i` >= 72 AND `i` < 96',
#     '`i` >= 96'
# Problem is that the last chunk does all the work.  If the zero row
# is ignored then the chunks are much better and the first chunk will
# cover the zero row.

$sb->load_file('master', 'common/t/samples/issue_941.sql');

sub test_zero_row {
   my ( $tbl, $range, $chunks ) = @_;
   $t = $p->parse( $du->get_create_table($dbh, $q, 'issue_941', $tbl) );
   %params = $c->get_range_statistics(
      dbh       => $dbh,
      db        => 'issue_941',
      tbl       => $tbl,
      chunk_col => $tbl,
      zero_row  => 0,
   );
   is_deeply(
      \%params,
      $range,
      "$tbl range without zero row"
   ) or print STDERR "Got ", Dumper(\%params);

   @chunks = $c->calculate_chunks(
      dbh        => $dbh,
      tbl_struct => $t,
      chunk_col  => $tbl,
      chunk_size => '2',
      %params,
   );
   is_deeply(
      \@chunks,
      $chunks,
      "$tbl chunks without zero row"
   ) or print STDERR "Got ", Dumper(\@chunks);

   return;
}

test_zero_row(
   'i',
   { min=>100, max=>107, rows_in_range=>9 },
   [
      '`i` < 102',
      '`i` >= 102 AND `i` < 104',
      '`i` >= 104 AND `i` < 106',
      '`i` >= 106',
   ],
);

test_zero_row(
   'i_null',
   { min=>100, max=>107, rows_in_range=>9 },
   [
      '`i_null` < 102',
      '`i_null` >= 102 AND `i_null` < 104',
      '`i_null` >= 104 AND `i_null` < 106',
      '`i_null` >= 106',
      '`i_null` IS NULL',
   ],
);

test_zero_row(
   'd',
   {
      min => '2010-03-01',
      max => '2010-03-05',
      rows_in_range => '6'
   },
   [
      '`d` < "2010-03-03"',
      '`d` >= "2010-03-03"',
   ],
);

test_zero_row(
   'dt',
   {
      min => '2010-03-01 02:01:00',
      max => '2010-03-05 00:30:00',
      rows_in_range => '6',
   },
   [
      '`dt` < "2010-03-02 09:30:40"',
      '`dt` >= "2010-03-02 09:30:40" AND `dt` < "2010-03-03 17:00:20"',
      '`dt` >= "2010-03-03 17:00:20"',
   ],
);

# #############################################################################
# Done.
# #############################################################################
$sb->wipe_clean($dbh);
exit;
