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
   $tests = 26;
   $skipped = 2;
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
   sub { $c->best_algorithm( algorithm => 'foo', ) },
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
   'ACCUM',
   'CHECKSUM eliminated by where',
);

is (
   $c->best_algorithm(
      algorithm => 'CHECKSUM',
      vp        => $vp,
      dbh       => '4.1.1',
      chunk     => 1,
   ),
   'ACCUM',
   'CHECKSUM eliminated by chunk',
);

is (
   $c->best_algorithm(
      algorithm => 'CHECKSUM',
      vp        => $vp,
      dbh       => '4.1.1',
      replicate => 1,
   ),
   'ACCUM',
   'CHECKSUM eliminated by replicate',
);

is (
   $c->best_algorithm(
      vp        => $vp,
      dbh       => '4.1.1',
      count     => 1,
   ),
   'ACCUM',
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
   'CHECKSUM eliminated by version',
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

#TODO
   my $todo = q{SELECT /*sakila.film:1/1*/ COUNT(*) AS cnt, }
   . q{RIGHT(MAX(@crc := CONCAT(LPAD(@cnt := @cnt + 1, 16, '0'), }
   . q{SHA1(CONCAT_WS('#', @crc, SHA1(CONCAT_WS('#', }
   . q{`film_id`, `title`, `description`, `release_year`, `language_id`,}
   . q{`original_language_id`, `rental_duration`, `rental_rate`, `length`,}
   . q{`replacement_cost`, `rating`, `special_features`, `last_update` + 0, }
   . q{CONCAT(ISNULL(`description`), ISNULL(`release_year`), }
   . q{ISNULL(`original_language_id`), ISNULL(`length`), }
   . q{ISNULL(`rating`), ISNULL(`special_features`)))))))), 40) AS crc }
   . q{FROM `sakila`.`film` USE INDEX(PRIMARY) /*WHERE*/};

# Open a connection to MySQL, or skip the rest of the tests.
my $dbh;
eval {
   $dbh = DBI->connect(
   "DBI:mysql:;mysql_read_default_group=mysql", undef, undef,
   { PrintError => 0, RaiseError => 1 })
};
SKIP: {
   skip 'Cannot open a DB connection', $tests-$skipped if $EVAL_ERROR;

   is(
      $c->choose_hash_func(
         dbh => $dbh,
      ),
      'SHA1',
      'SHA1 is default',
   );

   is(
      $c->choose_hash_func(
         dbh => $dbh,
         func => 'SHA99',
      ),
      'SHA1',
      'SHA99 does not exist so I get SHA1',
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

}
