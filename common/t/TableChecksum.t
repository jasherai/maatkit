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

my ($tests, $skipped);
BEGIN {
   $tests = 50;
   $skipped = 7;
}

use Test::More tests => $tests;
use DBI;
use English qw(-no_match_vars);

require "../TableChecksum.pm";
require "../VersionParser.pm";
require "../TableParser.pm";
require "../Quoter.pm";

my $c = new TableChecksum();
my $vp = new VersionParser();
my $tp = new TableParser();
my $q  = new Quoter();
my $t;

my %args = map { $_ => undef }
   qw(dbname tblname table quoter algorithm func crc_wid crc_type opt_slice);

sub load_file {
   my ($file) = @_;
   open my $fh, "<", $file or die $!;
   my $contents = do { local $/ = undef; <$fh> };
   close $fh;
   return $contents;
}

sub throws_ok {
   my ( $code, $re, $msg ) = @_;
   eval { $code->(); };
   like ( $EVAL_ERROR, $re, $msg );
}

throws_ok (
   sub { $c->best_algorithm( %args, algorithm => 'foo', ) },
   qr/Invalid checksum algorithm/,
   'Algorithm=foo',
);

# Inject the VersionParser with some bogus versions.  Later I'll just pass the
# string version number instead of a real DBH, so the version parsing will
# return the value I want.
foreach my $ver( qw(4.0.0 4.1.1) ) {
   $vp->{$ver} = $vp->parse($ver);
}

is (
   $c->best_algorithm(
      algorithm => 'CHECKSUM',
      vp        => $vp,
      dbh       => '4.1.1',
   ),
   'CHECKSUM',
   'Prefers CHECKSUM',
);

is (
   $c->best_algorithm(
      vp        => $vp,
      dbh       => '4.1.1',
   ),
   'CHECKSUM',
   'Default is CHECKSUM',
);

is (
   $c->best_algorithm(
      algorithm => 'CHECKSUM',
      vp        => $vp,
      dbh       => '4.1.1',
      where     => 1,
   ),
   'BIT_XOR',
   'CHECKSUM eliminated by where',
);

is (
   $c->best_algorithm(
      algorithm => 'CHECKSUM',
      vp        => $vp,
      dbh       => '4.1.1',
      chunk     => 1,
   ),
   'BIT_XOR',
   'CHECKSUM eliminated by chunk',
);

is (
   $c->best_algorithm(
      algorithm => 'CHECKSUM',
      vp        => $vp,
      dbh       => '4.1.1',
      replicate => 1,
   ),
   'BIT_XOR',
   'CHECKSUM eliminated by replicate',
);

is (
   $c->best_algorithm(
      vp        => $vp,
      dbh       => '4.1.1',
      count     => 1,
   ),
   'BIT_XOR',
   'Default CHECKSUM eliminated by count',
);

is (
   $c->best_algorithm(
      algorithm => 'CHECKSUM',
      vp        => $vp,
      dbh       => '4.1.1',
      count     => 1,
   ),
   'CHECKSUM',
   'Explicit CHECKSUM not eliminated by count',
);

is (
   $c->best_algorithm(
      algorithm => 'CHECKSUM',
      vp        => $vp,
      dbh       => '4.0.0',
   ),
   'ACCUM',
   'CHECKSUM and BIT_XOR eliminated by version',
);

is (
   $c->best_algorithm(
      algorithm => 'BIT_XOR',
      vp        => $vp,
      dbh       => '4.1.1',
   ),
   'BIT_XOR',
   'BIT_XOR as requested',
);

is (
   $c->best_algorithm(
      algorithm => 'BIT_XOR',
      vp        => $vp,
      dbh       => '4.0.0',
   ),
   'ACCUM',
   'BIT_XOR eliminated by version',
);

is (
   $c->best_algorithm(
      algorithm => 'ACCUM',
      vp        => $vp,
      dbh       => '4.1.1',
   ),
   'ACCUM',
   'ACCUM as requested',
);

ok($c->is_hash_algorithm('ACCUM'), 'ACCUM is hash');
ok($c->is_hash_algorithm('BIT_XOR'), 'BIT_XOR is hash');
ok(!$c->is_hash_algorithm('CHECKSUM'), 'CHECKSUM is not hash');

is (
   $c->make_xor_slices(
      query   => 'FOO',
      crc_wid => 1,
   ),
   "LPAD(CONV(BIT_XOR(CAST(CONV(SUBSTRING(FOO, 1, 1), 16, 10) "
      . "AS UNSIGNED)), 10, 16), 1, '0')",
   'FOO XOR slices 1 wide',
);

is (
   $c->make_xor_slices(
      query   => 'FOO',
      crc_wid => 16,
   ),
   "LPAD(CONV(BIT_XOR(CAST(CONV(SUBSTRING(FOO, 1, 16), 16, 10) "
      . "AS UNSIGNED)), 10, 16), 16, '0')",
   'FOO XOR slices 16 wide',
);

is (
   $c->make_xor_slices(
      query   => 'FOO',
      crc_wid => 17,
   ),
   "LPAD(CONV(BIT_XOR(CAST(CONV(SUBSTRING(FOO, 1, 16), 16, 10) "
      . "AS UNSIGNED)), 10, 16), 16, '0'), "
      . "LPAD(CONV(BIT_XOR(CAST(CONV(SUBSTRING(FOO, 17, 1), 16, 10) "
      . "AS UNSIGNED)), 10, 16), 1, '0')",
   'FOO XOR slices 17 wide',
);

is (
   $c->make_xor_slices(
      query   => 'FOO',
      crc_wid => 32,
   ),
   "LPAD(CONV(BIT_XOR(CAST(CONV(SUBSTRING(FOO, 1, 16), 16, 10) "
      . "AS UNSIGNED)), 10, 16), 16, '0'), "
      . "LPAD(CONV(BIT_XOR(CAST(CONV(SUBSTRING(FOO, 17, 16), 16, 10) "
      . "AS UNSIGNED)), 10, 16), 16, '0')",
   'FOO XOR slices 32 wide',
);

is (
   $c->make_xor_slices(
      query     => 'FOO',
      crc_wid   => 32,
      opt_slice => 0,
   ),
   "LPAD(CONV(BIT_XOR(CAST(CONV(SUBSTRING(\@crc := FOO, 1, 16), 16, 10) "
      . "AS UNSIGNED)), 10, 16), 16, '0'), "
      . "LPAD(CONV(BIT_XOR(CAST(CONV(SUBSTRING(\@crc, 17, 16), 16, 10) "
      . "AS UNSIGNED)), 10, 16), 16, '0')",
   'XOR slice optimized in slice 0',
);

is (
   $c->make_xor_slices(
      query     => 'FOO',
      crc_wid   => 32,
      opt_slice => 1,
   ),
   "LPAD(CONV(BIT_XOR(CAST(CONV(SUBSTRING(\@crc, 1, 16), 16, 10) "
      . "AS UNSIGNED)), 10, 16), 16, '0'), "
      . "LPAD(CONV(BIT_XOR(CAST(CONV(SUBSTRING(\@crc := FOO, 17, 16), 16, 10) "
      . "AS UNSIGNED)), 10, 16), 16, '0')",
   'XOR slice optimized in slice 1',
);

$t = $tp->parse(load_file('samples/sakila.film.sql'));

is (
   $c->make_row_checksum(
      func      => 'SHA1',
      table     => $t,
      quoter    => $q,
   ),
   q{SHA1(CONCAT_WS('#', }
   . q{`film_id`, `title`, `description`, `release_year`, `language_id`, }
   . q{`original_language_id`, `rental_duration`, `rental_rate`, `length`, }
   . q{`replacement_cost`, `rating`, `special_features`, `last_update` + 0, }
   . q{CONCAT(ISNULL(`description`), ISNULL(`release_year`), }
   . q{ISNULL(`original_language_id`), ISNULL(`length`), }
   . q{ISNULL(`rating`), ISNULL(`special_features`))))},
   'SHA1 query for sakila.film',
);

is (
   $c->make_row_checksum(
      func      => 'FNV_64',
      table     => $t,
      quoter    => $q,
   ),
   q{FNV_64(}
   . q{`film_id`, `title`, `description`, `release_year`, `language_id`, }
   . q{`original_language_id`, `rental_duration`, `rental_rate`, `length`, }
   . q{`replacement_cost`, `rating`, `special_features`, `last_update` + 0)},
   'FNV_64 query for sakila.film',
);

is (
   $c->make_row_checksum(
      func      => 'SHA1',
      table     => $t,
      quoter    => $q,
      cols      => [qw(film_id)],
   ),
   q{SHA1(`film_id`)},
   'SHA1 query for sakila.film with only one column',
);

is (
   $c->make_row_checksum(
      func      => 'SHA1',
      table     => $t,
      quoter    => $q,
      cols      => [qw(FILM_ID)],
   ),
   q{SHA1(`film_id`)},
   'Column names are case-insensitive',
);

is (
   $c->make_row_checksum(
      func      => 'SHA1',
      table     => $t,
      quoter    => $q,
      cols      => [qw(film_id title)],
      sep       => '%',
   ),
   q{SHA1(CONCAT_WS('%', `film_id`, `title`))},
   'Separator',
);

is (
   $c->make_row_checksum(
      func      => 'SHA1',
      table     => $t,
      quoter    => $q,
      cols      => [qw(film_id title)],
      sep       => "'%'",
   ),
   q{SHA1(CONCAT_WS('%', `film_id`, `title`))},
   'Bad separator',
);

is (
   $c->make_row_checksum(
      func      => 'SHA1',
      table     => $t,
      quoter    => $q,
      cols      => [qw(film_id title)],
      sep       => "'''",
   ),
   q{SHA1(CONCAT_WS('#', `film_id`, `title`))},
   'Really bad separator',
);

$t = $tp->parse(load_file('samples/sakila.rental.float.sql'));
is (
   $c->make_row_checksum(
      func      => 'SHA1',
      table     => $t,
      quoter    => $q,
   ),
   q{SHA1(CONCAT_WS('#', `rental_id`, `foo`))},
   'FLOAT column is like any other',
);

is (
   $c->make_row_checksum(
      func      => 'SHA1',
      table     => $t,
      quoter    => $q,
      precision => 5,
   ),
   q{SHA1(CONCAT_WS('#', `rental_id`, ROUND(`foo`, 5)))},
   'FLOAT column is rounded to 5 places',
);

$t = $tp->parse(load_file('samples/sakila.film.sql'));

like (
   $c->make_row_checksum(
      func      => 'SHA1',
      table     => $t,
      quoter    => $q,
      trim      => 1,
   ),
   qr{TRIM\(`title`\)},
   'VARCHAR column is trimmed',
);

is (
   $c->make_checksum_query(
      %args,
      dbname    => 'sakila',
      tblname   => 'film',
      table     => $t,
      quoter    => $q,
      algorithm => 'CHECKSUM',
      func      => 'SHA1',
      crc_wid   => 40,
      crc_type  => 'varchar',
   ),
   'CHECKSUM TABLE `sakila`.`film`',
   'Sakila.film CHECKSUM',
);

throws_ok (
   sub { $c->make_checksum_query(%args, algorithm => 'CHECKSUM TABLE') },
   qr/missing checksum algorithm/,
   'Complains about bad algorithm',
);

is (
   $c->make_checksum_query(
      %args,
      dbname    => 'sakila',
      tblname   => 'film',
      table     => $t,
      quoter    => $q,
      algorithm => 'BIT_XOR',
      func      => 'SHA1',
      crc_wid   => 40,
      cols      => [qw(film_id)],
      crc_type  => 'varchar',
   ),
   q{SELECT /*PROGRESS_COMMENT*//*CHUNK_NUM*/ COUNT(*) AS cnt, }
   . q{LOWER(CONCAT(LPAD(CONV(BIT_XOR(CAST(CONV(SUBSTRING(SHA1(`film_id`), 1, }
   . q{16), 16, 10) AS UNSIGNED)), 10, 16), 16, '0'), }
   . q{LPAD(CONV(BIT_XOR(CAST(CONV(SUBSTRING(SHA1(`film_id`), 17, 16), 16, }
   . q{10) AS UNSIGNED)), 10, 16), 16, '0'), }
   . q{LPAD(CONV(BIT_XOR(CAST(CONV(SUBSTRING(SHA1(`film_id`), 33, 8), 16, }
   . q{10) AS UNSIGNED)), 10, 16), 8, '0'))) AS crc }
   . q{FROM /*DB_TBL*//*WHERE*/},
   'Sakila.film SHA1 BIT_XOR',
);

is (
   $c->make_checksum_query(
      %args,
      dbname    => 'sakila',
      tblname   => 'film',
      table     => $t,
      quoter    => $q,
      algorithm => 'BIT_XOR',
      func      => 'FNV_64',
      crc_wid   => 99,
      cols      => [qw(film_id)],
      crc_type  => 'bigint',
   ),
   q{SELECT /*PROGRESS_COMMENT*//*CHUNK_NUM*/ COUNT(*) AS cnt, }
   . q{LOWER(CONV(BIT_XOR(CAST(FNV_64(`film_id`) AS UNSIGNED)), 10, 16)) AS crc }
   . q{FROM /*DB_TBL*//*WHERE*/},
   'Sakila.film FNV_64 BIT_XOR',
);

is (
   $c->make_checksum_query(
      %args,
      dbname    => 'sakila',
      tblname   => 'film',
      table     => $t,
      quoter    => $q,
      algorithm => 'BIT_XOR',
      func      => 'FNV_64',
      crc_wid   => 99,
      cols      => [qw(film_id)],
      buffer    => 1,
      crc_type  => 'bigint',
   ),
   q{SELECT SQL_BUFFER_RESULT /*PROGRESS_COMMENT*//*CHUNK_NUM*/ COUNT(*) AS cnt, }
   . q{LOWER(CONV(BIT_XOR(CAST(FNV_64(`film_id`) AS UNSIGNED)), 10, 16)) AS crc }
   . q{FROM /*DB_TBL*//*WHERE*/},
   'Sakila.film FNV_64 BIT_XOR',
);

is (
   $c->make_checksum_query(
      %args,
      dbname    => 'sakila',
      tblname   => 'film',
      table     => $t,
      quoter    => $q,
      algorithm => 'BIT_XOR',
      func      => 'CRC32',
      crc_wid   => 99,
      cols      => [qw(film_id)],
      buffer    => 1,
      crc_type  => 'int',
   ),
   q{SELECT SQL_BUFFER_RESULT /*PROGRESS_COMMENT*//*CHUNK_NUM*/ COUNT(*) AS cnt, }
   . q{LOWER(CONV(BIT_XOR(CAST(CRC32(`film_id`) AS UNSIGNED)), 10, 16)) AS crc }
   . q{FROM /*DB_TBL*//*WHERE*/},
   'Sakila.film CRC32 BIT_XOR',
);

is (
   $c->make_checksum_query(
      %args,
      dbname    => 'sakila',
      tblname   => 'film',
      table     => $t,
      quoter    => $q,
      algorithm => 'BIT_XOR',
      func      => 'SHA1',
      crc_wid   => 40,
      cols      => [qw(film_id)],
      replicate => 'test.checksum',
      crc_type  => 'varchar',
   ),
   q{REPLACE /*PROGRESS_COMMENT*/ INTO test.checksum }
   . q{(db, tbl, chunk, boundaries, this_cnt, this_crc) }
   . q{SELECT ?, ?, /*CHUNK_NUM*/ ?, COUNT(*) AS cnt, }
   . q{LOWER(CONCAT(LPAD(CONV(BIT_XOR(CAST(CONV(SUBSTRING(SHA1(`film_id`), 1, }
   . q{16), 16, 10) AS UNSIGNED)), 10, 16), 16, '0'), }
   . q{LPAD(CONV(BIT_XOR(CAST(CONV(SUBSTRING(SHA1(`film_id`), 17, 16), 16, }
   . q{10) AS UNSIGNED)), 10, 16), 16, '0'), }
   . q{LPAD(CONV(BIT_XOR(CAST(CONV(SUBSTRING(SHA1(`film_id`), 33, 8), 16, }
   . q{10) AS UNSIGNED)), 10, 16), 8, '0'))) AS crc }
   . q{FROM /*DB_TBL*//*WHERE*/},
   'Sakila.film SHA1 BIT_XOR with replication',
);

is (
   $c->make_checksum_query(
      %args,
      dbname    => 'sakila',
      tblname   => 'film',
      table     => $t,
      quoter    => $q,
      algorithm => 'ACCUM',
      func      => 'SHA1',
      crc_wid   => 40,
      crc_type  => 'varchar',
   ),
   q{SELECT /*PROGRESS_COMMENT*//*CHUNK_NUM*/ COUNT(*) AS cnt, }
   . q{RIGHT(MAX(@crc := CONCAT(LPAD(@cnt := @cnt + 1, 16, '0'), }
   . q{SHA1(CONCAT(@crc, SHA1(CONCAT_WS('#', }
   . q{`film_id`, `title`, `description`, `release_year`, `language_id`, }
   . q{`original_language_id`, `rental_duration`, `rental_rate`, `length`, }
   . q{`replacement_cost`, `rating`, `special_features`, `last_update` + 0, }
   . q{CONCAT(ISNULL(`description`), ISNULL(`release_year`), }
   . q{ISNULL(`original_language_id`), ISNULL(`length`), }
   . q{ISNULL(`rating`), ISNULL(`special_features`)))))))), 40) AS crc }
   . q{FROM /*DB_TBL*//*WHERE*/},
   'Sakila.film SHA1 ACCUM',
);

is (
   $c->make_checksum_query(
      %args,
      dbname    => 'sakila',
      tblname   => 'film',
      table     => $t,
      quoter    => $q,
      algorithm => 'ACCUM',
      func      => 'FNV_64',
      crc_wid   => 16,
      crc_type  => 'bigint',
   ),
   q{SELECT /*PROGRESS_COMMENT*//*CHUNK_NUM*/ COUNT(*) AS cnt, }
   . q{RIGHT(MAX(@crc := CONCAT(LPAD(@cnt := @cnt + 1, 16, '0'), }
   . q{CONV(CAST(FNV_64(CONCAT(@crc, FNV_64(}
   . q{`film_id`, `title`, `description`, `release_year`, `language_id`, }
   . q{`original_language_id`, `rental_duration`, `rental_rate`, `length`, }
   . q{`replacement_cost`, `rating`, `special_features`, `last_update` + 0}
   . q{))) AS UNSIGNED), 10, 16))), 16) AS crc }
   . q{FROM /*DB_TBL*//*WHERE*/},
   'Sakila.film FNV_64 ACCUM',
);

is (
   $c->make_checksum_query(
      %args,
      dbname    => 'sakila',
      tblname   => 'film',
      table     => $t,
      quoter    => $q,
      algorithm => 'ACCUM',
      func      => 'CRC32',
      crc_wid   => 16,
      crc_type  => 'int',
      cols      => [qw(film_id)],
   ),
   q{SELECT /*PROGRESS_COMMENT*//*CHUNK_NUM*/ COUNT(*) AS cnt, }
   . q{RIGHT(MAX(@crc := CONCAT(LPAD(@cnt := @cnt + 1, 16, '0'), }
   . q{CONV(CAST(CRC32(CONCAT(@crc, CRC32(`film_id`}
   . q{))) AS UNSIGNED), 10, 16))), 16) AS crc }
   . q{FROM /*DB_TBL*//*WHERE*/},
   'Sakila.film CRC32 ACCUM',
);

is (
   $c->make_checksum_query(
      %args,
      dbname    => 'sakila',
      tblname   => 'film',
      table     => $t,
      quoter    => $q,
      algorithm => 'ACCUM',
      func      => 'SHA1',
      crc_wid   => 40,
      replicate => 'test.checksum',
      crc_type  => 'varchar',
   ),
   q{REPLACE /*PROGRESS_COMMENT*/ INTO test.checksum }
   . q{(db, tbl, chunk, boundaries, this_cnt, this_crc) }
   . q{SELECT ?, ?, /*CHUNK_NUM*/ ?, COUNT(*) AS cnt, }
   . q{RIGHT(MAX(@crc := CONCAT(LPAD(@cnt := @cnt + 1, 16, '0'), }
   . q{SHA1(CONCAT(@crc, SHA1(CONCAT_WS('#', }
   . q{`film_id`, `title`, `description`, `release_year`, `language_id`, }
   . q{`original_language_id`, `rental_duration`, `rental_rate`, `length`, }
   . q{`replacement_cost`, `rating`, `special_features`, `last_update` + 0, }
   . q{CONCAT(ISNULL(`description`), ISNULL(`release_year`), }
   . q{ISNULL(`original_language_id`), ISNULL(`length`), }
   . q{ISNULL(`rating`), ISNULL(`special_features`)))))))), 40) AS crc }
   . q{FROM /*DB_TBL*//*WHERE*/},
   'Sakila.film SHA1 ACCUM with replication',
);

is ( $c->crc32('hello world'), 222957957, 'CRC32 of hello world');

# TODO: use a sandbox instead, and get a $dbh this way:
# my $dp = new DSNParser();
# my $dsn = $dp->parse("h=127.0.0.1,P=12345");
# $dbh    = $dp->get_dbh($dp->get_cxn_params($dsn), { AutoCommit => 1 });

# Open a connection to MySQL, or skip the rest of the tests.
my $dbh;
eval {
   $dbh = DBI->connect(
   "DBI:mysql:;mysql_read_default_group=mysql", undef, undef,
   { PrintError => 0, RaiseError => 1 })
};
SKIP: {
   skip 'Cannot open a DB connection', $tests-$skipped if $EVAL_ERROR;

   like(
      $c->choose_hash_func(
         dbh => $dbh,
      ),
      qr/CRC32|FNV_64|MD5/,
      'CRC32, FNV_64 or MD5 is default',
   );

   like(
      $c->choose_hash_func(
         dbh => $dbh,
         func => 'SHA99',
      ),
      qr/CRC32|FNV_64|MD5/,
      'SHA99 does not exist so I get CRC32 or friends',
   );

   is(
      $c->choose_hash_func(
         dbh => $dbh,
         func => 'MD5',
      ),
      'MD5',
      'MD5 requested and MD5 granted',
   );

   is(
      $c->optimize_xor(
         dbh  => $dbh,
         func => 'SHA1',
      ),
      '2',
      'SHA1 slice is 2',
   );

   is(
      $c->optimize_xor(
         dbh  => $dbh,
         func => 'MD5',
      ),
      '1',
      'MD5 slice is 1',
   );

   is_deeply(
      [$c->get_crc_type($dbh, 'CRC32')],
      [qw(int 10)],
      'Type and length of CRC32'
   );

   is_deeply(
      [$c->get_crc_type($dbh, 'MD5')],
      [qw(varchar 32)],
      'Type and length of MD5'
   );

}
