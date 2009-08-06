#!/usr/bin/perl

use strict;
use warnings FATAL => 'all';
use English qw(-no_match_vars);
use Test::More tests => 29;

require "../DuplicateKeyFinder.pm";
require "../Quoter.pm";
require "../TableParser.pm";
use Data::Dumper;
$Data::Dumper::Indent=1;

my $dk = new DuplicateKeyFinder();
my $q  = new Quoter();
my $tp = new TableParser();

sub load_file {
   my ($file) = @_;
   open my $fh, "<", $file or die $!;
   my $contents = do { local $/ = undef; <$fh> };
   close $fh;
   return $contents;
}

my $dupes;
my $callback = sub {
   push @$dupes, $_[0];
};

my $opt = { version => '004001000' };
my $ddl;
my $tbl;

isa_ok($dk, 'DuplicateKeyFinder');

$ddl   = load_file('samples/one_key.sql');
$dupes = [];
my ($keys, $ck) = $tp->get_keys($ddl, $opt);
$dk->get_duplicate_keys(
   $keys,
   clustered_key => $ck,
   callback => $callback);
is_deeply(
   $dupes,
   [
   ],
   'One key, no dupes'
);

$ddl   = load_file('samples/dupe_key.sql');
$dupes = [];
($keys, $ck) = $tp->get_keys($ddl, $opt);
$dk->get_duplicate_keys(
   $keys,
   clustered_key => $ck,
   callback => $callback);
is_deeply(
   $dupes,
   [
      {
         'key'          => 'a',
         'cols'         => '`a`',
         'duplicate_of' => 'a_2',
         'duplicate_of_cols' => '`a`,`b`',
         'reason'       => 'a is a left-prefix of a_2',
         dupe_type      => 'prefix',
      }
   ],
   'Two dupe keys on table dupe_key'
);

$ddl   = load_file('samples/dupe_key_reversed.sql');
$dupes = [];
($keys, $ck) = $tp->get_keys($ddl, $opt);
$dk->get_duplicate_keys(
   $keys,
   clustered_key => $ck,
   callback => $callback);
is_deeply(
   $dupes,
   [
      {
         'key'          => 'a',
         'cols'         => '`a`',
         'duplicate_of' => 'a_2',
         'duplicate_of_cols' => '`a`,`b`',
         'reason'       => 'a is a left-prefix of a_2',
         dupe_type      => 'prefix',
      }
   ],
   'Two dupe keys on table dupe_key in reverse'
);

# This test might fail if your system sorts a_3 before a_2, because the
# keys are sorted by columns, not name. If this happens, then a_3 will
# duplicate a_2.
$ddl   = load_file('samples/dupe_keys_thrice.sql');
$dupes = [];
($keys, $ck) = $tp->get_keys($ddl, $opt);
$dk->get_duplicate_keys(
   $keys,
   clustered_key => $ck,
   callback => $callback);
is_deeply(
   $dupes,
   [
      {
         'key'          => 'a_3',
         'cols'         => '`a`,`b`',
         'duplicate_of' => 'a_2',
         'duplicate_of_cols' => '`a`,`b`',
         'reason'       => 'a_3 is a duplicate of a_2',
         dupe_type      => 'exact',
      },
      {
         'key'          => 'a',
         'cols'         => '`a`',
         'duplicate_of' => 'a_2',
         'duplicate_of_cols' => '`a`,`b`',
         'reason'       => 'a is a left-prefix of a_2',
         dupe_type      => 'prefix',
      },
   ],
   'Dupe keys only output once (may fail due to different sort order)'
);

$ddl   = load_file('samples/nondupe_fulltext.sql');
$dupes = [];
($keys, $ck) = $tp->get_keys($ddl, $opt);
$dk->get_duplicate_keys(
   $keys,
   clustered_key => $ck,
   callback => $callback);
is_deeply(
   $dupes,
   [],
   'No dupe keys b/c of fulltext'
);
$dupes = [];
($keys, $ck) = $tp->get_keys($ddl, $opt);
$dk->get_duplicate_keys(
   $keys,
   clustered_key => $ck,
   ignore_structure => 1,
   callback         => $callback);
is_deeply(
   $dupes,
   [
      {
         'key'          => 'a',
         'cols'         => '`a`',
         'duplicate_of' => 'a_2',
         'duplicate_of_cols' => '`a`,`b`',
         'reason'       => 'a is a left-prefix of a_2',
         dupe_type      => 'prefix',
      },
   ],
   'Dupe keys when ignoring structure'
);

$ddl   = load_file('samples/nondupe_fulltext_not_exact.sql');
$dupes = [];
($keys, $ck) = $tp->get_keys($ddl, $opt);
$dk->get_duplicate_keys(
   $keys,
   clustered_key => $ck,
   callback => $callback);
is_deeply(
   $dupes,
   [],
   'No dupe keys b/c fulltext requires exact match (issue 10)'
);

$ddl   = load_file('samples/dupe_fulltext_exact.sql');
$dupes = [];
($keys, $ck) = $tp->get_keys($ddl, $opt);
$dk->get_duplicate_keys(
   $keys,
   clustered_key => $ck,
   callback => $callback);
is_deeply(
   $dupes,
   [
      {
         'key'          => 'ft_idx_a_b_2',
         'cols'         => '`a`,`b`',
         'duplicate_of' => 'ft_idx_a_b_1',
         'duplicate_of_cols' => '`a`,`b`',
         'reason'       => 'ft_idx_a_b_2 is a duplicate of ft_idx_a_b_1',
         dupe_type      => 'exact',
      }
   ],
   'Dupe exact fulltext keys (issue 10)'
);

$ddl   = load_file('samples/dupe_fulltext_reverse_order.sql');
$dupes = [];
($keys, $ck) = $tp->get_keys($ddl, $opt);
$dk->get_duplicate_keys(
   $keys,
   clustered_key => $ck,
   callback => $callback);
is_deeply(
   $dupes,
   [
      {
         'key'          => 'ft_idx_a_b',
         'cols'         => '`a`,`b`',
         'duplicate_of' => 'ft_idx_b_a',
         'duplicate_of_cols' => '`b`,`a`',
         'reason'       => 'ft_idx_a_b is a duplicate of ft_idx_b_a',
         dupe_type      => 'exact',
      }
   ],
   'Dupe reverse order fulltext keys (issue 10)'
);

$ddl   = load_file('samples/dupe_key_unordered.sql');
$dupes = [];
($keys, $ck) = $tp->get_keys($ddl, $opt);
$dk->get_duplicate_keys(
   $keys,
   clustered_key => $ck,
   callback => $callback);
is_deeply(
   $dupes,
   [],
   'No dupe keys because of order'
);
$dupes = [];
($keys, $ck) = $tp->get_keys($ddl, $opt);
$dk->get_duplicate_keys(
   $keys,
   clustered_key => $ck,
   ignore_order => 1,
   callback     => $callback);
is_deeply(
   $dupes,
   [
      {
         'key'          => 'a',
         'cols'         => '`b`,`a`',
         'duplicate_of' => 'a_2',
         'duplicate_of_cols' => '`a`,`b`',
         'reason'       => 'a is a duplicate of a_2',
         dupe_type      => 'exact',
      }
   ],
   'Two dupe keys when ignoring order'
);

# #############################################################################
# Clustered key tests.
# #############################################################################
$ddl   = load_file('samples/innodb_dupe.sql');
$dupes = [];
($keys, $ck) = $tp->get_keys($ddl, $opt);
$dk->get_duplicate_keys(
   $keys,
   clustered_key => $ck,
   callback => $callback);

is_deeply(
   $dupes,
   [],
   'No duplicate keys with ordinary options'
);
$dupes = [];
($keys, $ck) = $tp->get_keys($ddl, $opt);
$dk->get_duplicate_keys(
   $keys,
   clustered_key => $ck,
   clustered => 1,
   tbl_info  => { engine => 'InnoDB', ddl => $ddl },
   callback  => $callback);
is_deeply(
   $dupes,
   [
      {
         'key'          => 'b',
         'cols'         => '`b`,`a`',
         'duplicate_of' => 'PRIMARY',
         'duplicate_of_cols' => '`a`',
         'reason'       => 'Key b ends with a prefix of the clustered index',
         dupe_type      => 'clustered',
      }
   ],
   'Duplicate keys with cluster option'
);

$ddl = load_file('samples/dupe_if_it_were_innodb.sql');
$dupes = [];
($keys, $ck) = $tp->get_keys($ddl, $opt);
$dk->get_duplicate_keys(
   $keys,
   clustered_key => $ck,
   clustered => 1,
   tbl_info  => {engine    => 'MyISAM', ddl => $ddl},
   callback  => $callback);
is_deeply(
   $dupes,
   [],
   'No cluster-duplicate keys because not InnoDB'
);

# This table is a test case for an infinite loop I ran into while writing the
# cluster stuff
$ddl = load_file('samples/mysql_db.sql');
$dupes = [];
($keys, $ck) = $tp->get_keys($ddl, $opt);
$dk->get_duplicate_keys(
   $keys,
   clustered_key => $ck,
   clustered => 1,
   tbl_info  => { engine    => 'InnoDB', ddl => $ddl },
   callback  => $callback);
is_deeply(
   $dupes,
   [],
   'No cluster-duplicate keys in mysql.db'
);

# #############################################################################
# Duplicate FOREIGN KEY tests.
# #############################################################################
$ddl   = load_file('samples/dupe_fk_one.sql');
$dupes = [];
$dk->get_duplicate_fks(
   $tp->get_fks($ddl, {database => 'test'}),
   callback => $callback);
is_deeply(
   $dupes,
   [
      {
         'key'               => 't1_ibfk_1',
         'cols'              => '`a`, `b`',
         'duplicate_of'      => 't1_ibfk_2',
         'duplicate_of_cols' => '`b`, `a`',
         'reason'            => 'FOREIGN KEY t1_ibfk_1 (`a`, `b`) REFERENCES `test`.`t2` (`a`, `b`) is a duplicate of FOREIGN KEY t1_ibfk_2 (`b`, `a`) REFERENCES `test`.`t2` (`b`, `a`)',
         dupe_type      => 'fk',
      }
   ],
   'Two duplicate foreign keys'
);

$ddl   = load_file('samples/sakila_film.sql');
$dupes = [];
$dk->get_duplicate_fks(
   $tp->get_fks($ddl, {database => 'sakila'}),
   callback => $callback);
is_deeply(
   $dupes,
   [],
   'No duplicate foreign keys in sakila_film.sql'
);

# #############################################################################
# Issue 9: mk-duplicate-key-checker should treat unique and FK indexes specially
# #############################################################################

$ddl   = load_file('samples/issue_9-1.sql');
$dupes = [];
($keys, $ck) = $tp->get_keys($ddl, $opt);
$dk->get_duplicate_keys(
   $keys,
   clustered_key => $ck,
   callback => $callback);
is_deeply(
   $dupes,
   [],
   'Unique and non-unique keys with common prefix not dupes (issue 9)'
);

$ddl   = load_file('samples/issue_9-2.sql');
$dupes = [];
($keys, $ck) = $tp->get_keys($ddl, $opt);
$dk->get_duplicate_keys(
   $keys,
   clustered_key => $ck,
   callback => $callback);
is_deeply(
   $dupes,
   [],
   'PRIMARY and non-unique keys with common prefix not dupes (issue 9)'
);

$ddl   = load_file('samples/issue_9-3.sql');
$dupes = [];
($keys, $ck) = $tp->get_keys($ddl, $opt);
$dk->get_duplicate_keys(
   $keys,
   clustered_key => $ck,
   callback => $callback);
is_deeply(
   $dupes,
   [
      {
         'key'          => 'j',
         'cols'         => '`a`,`b`',
         'duplicate_of' => 'i',
         'duplicate_of_cols' => '`a`,`b`',
         'reason'       => 'j is a duplicate of i',
         dupe_type      => 'exact',
      }
   ],
   'Non-unique key dupes unique key with same col cover (issue 9)'
);

$ddl   = load_file('samples/issue_9-4.sql');
$dupes = [];
($keys, $ck) = $tp->get_keys($ddl, $opt);
$dk->get_duplicate_keys(
   $keys,
   clustered_key => $ck,
   callback => $callback);
is_deeply(
   $dupes,
   [
      {
         'key'          => 'j',
         'cols'         => '`a`,`b`',
         'duplicate_of' => 'PRIMARY',
         'duplicate_of_cols' => '`a`,`b`',
         'reason'       => 'j is a duplicate of PRIMARY',
         dupe_type      => 'exact',
      }
   ],
   'Non-unique key dupes PRIMARY key same col cover (issue 9)'
);

$ddl   = load_file('samples/issue_9-5.sql');
$dupes = [];
($keys, $ck) = $tp->get_keys($ddl, $opt);
$dk->get_duplicate_keys(
   $keys,
   clustered_key => $ck,
   callback => $callback);
is_deeply(
   $dupes,
   [],
   'Two unique keys with common prefix are not dupes'
);

$ddl   = load_file('samples/uppercase_names.sql');
$dupes = [];
($keys, $ck) = $tp->get_keys($ddl, $opt);
$dk->get_duplicate_keys(
   $keys,
   clustered_key => $ck,
   callback => $callback);
is_deeply(
   $dupes,
   [
      {
         'key'               => 'A',
         'cols'              => '`A`',
         'duplicate_of'      => 'PRIMARY',
         'duplicate_of_cols' => '`A`',
         'reason'            => "A is a duplicate of PRIMARY",
         dupe_type      => 'exact',
      },
   ],
   'Finds duplicates OK on uppercase columns',
);

$ddl   = load_file('samples/issue_9-7.sql');
$dupes = [];
($keys, $ck) = $tp->get_keys($ddl, $opt);
$dk->get_duplicate_keys(
   $keys,
   clustered_key => $ck,
   callback => $callback);
is_deeply(
   $dupes,
   [
      {
         'key'               => 'ua_b',
         'cols'              => '`a`,`b`',
         'duplicate_of'      => 'a_b_c',
         'duplicate_of_cols' => '`a`,`b`,`c`',
         'reason'            => "Uniqueness of ua_b ignored because PRIMARY is a stronger constraint\nua_b is a left-prefix of a_b_c",
         dupe_type      => 'prefix',
      },
   ],
   'Redundantly unique key dupes normal key after unconstraining'
);

$ddl   = load_file('samples/issue_9-6.sql');
$dupes = [];
($keys, $ck) = $tp->get_keys($ddl, $opt);
$dk->get_duplicate_keys(
   $keys,
   clustered_key => $ck,
   callback => $callback);
is_deeply(
   $dupes,
   [
      {
       'duplicate_of' => 'PRIMARY',
       'reason' => 'a is a left-prefix of PRIMARY',
       dupe_type      => 'prefix',
       'duplicate_of_cols' => '`a`,`b`',
       'cols' => '`a`',
       'key' => 'a'
      },
      {
       'duplicate_of' => 'PRIMARY',
       'reason' => 'a_b is a duplicate of PRIMARY',
       dupe_type      => 'exact',
       'duplicate_of_cols' => '`a`,`b`',
       'cols' => '`a`,`b`',
       'key' => 'a_b'
      },
      {
       'duplicate_of' => 'PRIMARY',
       'reason' => "Uniqueness of ua_b ignored because ua is a stronger constraint\nua_b is a duplicate of PRIMARY",
       dupe_type      => 'exact',
       'duplicate_of_cols' => '`a`,`b`',
       'cols' => '`a`,`b`',
       'key' => 'ua_b'
      },
      {
       'duplicate_of' => 'PRIMARY',
       'reason' => "Uniqueness of ua_b2 ignored because ua is a stronger constraint\nua_b2 is a duplicate of PRIMARY",
       dupe_type      => 'exact',
       'duplicate_of_cols' => '`a`,`b`',
       'cols' => '`a`,`b`',
       'key' => 'ua_b2'
      }
   ],
   'Very pathological case',
);

# #############################################################################
# Issue 269: mk-duplicate-key-checker: Wrongly suggesting removing index
# #############################################################################
$ddl   = load_file('samples/issue_269-1.sql');
$dupes = [];
($keys, $ck) = $tp->get_keys($ddl, $opt);
$dk->get_duplicate_keys(
   $keys,
   clustered_key => $ck,
   callback => $callback);
is_deeply(
   $dupes,
   [
   ],
   'Keep stronger unique constraint that is prefix'
);

# #############################################################################
# Issue 331: mk-duplicate-key-checker crashes when printing column types
# #############################################################################
$ddl   = load_file('samples/issue_331.sql');
$dupes = [];
$dk->get_duplicate_fks(
   $tp->get_fks($ddl, {database => 'test'}),
   callback => $callback);
is_deeply(
   $dupes,
   [
      {
         'key'               => 'fk_1',
         'cols'              => '`id`',
         'duplicate_of'      => 'fk_2',
         'duplicate_of_cols' => '`id`',
         'reason'            => 'FOREIGN KEY fk_1 (`id`) REFERENCES `test`.`issue_331_t1` (`t1_id`) is a duplicate of FOREIGN KEY fk_2 (`id`) REFERENCES `test`.`issue_331_t1` (`t1_id`)',
         dupe_type      => 'fk',
      }
   ],
   'fk col not in referencing table (issue 331)'
);

# #############################################################################
# Done.
# #############################################################################
my $output = '';
{
   local *STDERR;
   open STDERR, '>', \$output;
   $dk->_d('Complete test coverage');
}
like(
   $output,
   qr/Complete test coverage/,
   '_d() works'
);
exit;
