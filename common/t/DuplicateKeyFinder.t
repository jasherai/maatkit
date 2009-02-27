#!/usr/bin/perl

use strict;
use warnings FATAL => 'all';

use Test::More tests => 28;
use English qw(-no_match_vars);

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
$dk->get_duplicate_keys(
   keys     => $tp->get_keys($ddl, $opt),
   callback => $callback);
is_deeply(
   $dupes,
   [
   ],
   'One key, no dupes'
);

$ddl   = load_file('samples/dupe_key.sql');
$dupes = [];
$dk->get_duplicate_keys(
   keys     => $tp->get_keys($ddl, $opt),
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
      }
   ],
   'Two dupe keys on table dupe_key'
);

$ddl   = load_file('samples/dupe_key_reversed.sql');
$dupes = [];
$dk->get_duplicate_keys(
   keys     => $tp->get_keys($ddl, $opt),
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
      }
   ],
   'Two dupe keys on table dupe_key in reverse'
);

# This test might fail if your system sorts a_3 before a_2, because the
# keys are sorted by columns, not name. If this happens, then a_3 will
# duplicate a_2.
$ddl   = load_file('samples/dupe_keys_thrice.sql');
$dupes = [];
$dk->get_duplicate_keys(
   keys     => $tp->get_keys($ddl, $opt),
   callback => $callback);
is_deeply(
   $dupes,
   [
      {
         'key'          => 'a',
         'cols'         => '`a`',
         'duplicate_of' => 'a_3',
         'duplicate_of_cols' => '`a`,`b`',
         'reason'       => 'a is a left-prefix of a_3',
      },
      {
         'key'          => 'a_3',
         'cols'         => '`a`,`b`',
         'duplicate_of' => 'a_2',
         'duplicate_of_cols' => '`a`,`b`',
         'reason'       => 'a_3 is a duplicate of a_2',
      }
   ],
   'Dupe keys only output once (may fail due to different sort order)'
);

$ddl   = load_file('samples/nondupe_fulltext.sql');
$dupes = [];
$dk->get_duplicate_keys(
   keys     => $tp->get_keys($ddl, $opt),
   callback => $callback);
is_deeply(
   $dupes,
   [],
   'No dupe keys b/c of fulltext'
);
$dupes = [];
$dk->get_duplicate_keys(
   ignore_type => 1,
   keys        => $tp->get_keys($ddl, $opt),
   callback    => $callback);
is_deeply(
   $dupes,
   [
      {
         'key'          => 'a',
         'cols'         => '`a`',
         'duplicate_of' => 'a_2',
         'duplicate_of_cols' => '`a`,`b`',
         'reason'       => 'a is a left-prefix of a_2',
      },
   ],
   'Dupe keys when ignoring type'
);

$ddl   = load_file('samples/nondupe_fulltext_not_exact.sql');
$dupes = [];
$dk->get_duplicate_keys(
   keys     => $tp->get_keys($ddl, $opt),
   callback => $callback);
is_deeply(
   $dupes,
   [],
   'No dupe keys b/c fulltext requires exact match (issue 10)'
);

$ddl   = load_file('samples/dupe_fulltext_exact.sql');
$dupes = [];
$dk->get_duplicate_keys(
   keys     => $tp->get_keys($ddl, $opt),
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
      }
   ],
   'Dupe exact fulltext keys (issue 10)'
);

$ddl   = load_file('samples/dupe_fulltext_reverse_order.sql');
$dupes = [];
$dk->get_duplicate_keys(
   keys     => $tp->get_keys($ddl, $opt),
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
      }
   ],
   'Dupe reverse order fulltext keys (issue 10)'
);

$ddl   = load_file('samples/dupe_key_unordered.sql');
$dupes = [];
$dk->get_duplicate_keys(
   keys     => $tp->get_keys($ddl, $opt),
   callback => $callback);
is_deeply(
   $dupes,
   [],
   'No dupe keys because of order'
);
$dupes = [];
$dk->get_duplicate_keys(
   ignore_order => 1,
   keys         => $tp->get_keys($ddl, $opt),
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
      }
   ],
   'Two dupe keys when ignoring order'
);

# #############################################################################
# Clustered key tests.
# #############################################################################
$ddl   = load_file('samples/innodb_dupe.sql');
$dupes = [];
$dk->get_duplicate_keys(
   keys     => $tp->get_keys($ddl, $opt),
   callback => $callback);

is_deeply(
   $dupes,
   [],
   'No duplicate keys with ordinary options'
);
$dupes = [];
$dk->get_duplicate_keys(
   clustered => 1,
   engine    => 'InnoDB',
   keys      => $tp->get_keys($ddl, $opt),
   callback  => $callback);
is_deeply(
   $dupes,
   [
      {
         'key'          => 'b',
         'cols'         => '`b`,`a`',
         'duplicate_of' => 'PRIMARY',
         'duplicate_of_cols' => '`a`',
         'reason'       => 'Clustered key b is a duplicate of PRIMARY',
      }
   ],
   'Duplicate keys with cluster options'
);

$ddl = load_file('samples/dupe_if_it_were_innodb.sql');
$dupes = [];
$dk->get_duplicate_keys(
   clustered => 1,
   engine    => 'MyISAM',
   keys      => $tp->get_keys($ddl, $opt),
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
$dk->get_duplicate_keys(
   clustered => 1,
   engine    => 'InnoDB',
   keys      => $tp->get_keys($ddl, $opt),
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
   keys     => $tp->get_fks($ddl, {database => 'test'}),
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
      }
   ],
   'Two duplicate foreign keys'
);

$ddl   = load_file('samples/sakila_film.sql');
$dupes = [];
$dk->get_duplicate_fks(
   keys     => $tp->get_fks($ddl, {database => 'sakila'}),
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
$dk->get_duplicate_keys(
   keys     => $tp->get_keys($ddl, $opt),
   callback => $callback);
is_deeply(
   $dupes,
   [],
   'Unique and non-unique keys with common prefix not dupes (issue 9)'
);

$ddl   = load_file('samples/issue_9-2.sql');
$dupes = [];
$dk->get_duplicate_keys(
   keys     => $tp->get_keys($ddl, $opt),
   callback => $callback);
is_deeply(
   $dupes,
   [],
   'PRIMARY and non-unique keys with common prefix not dupes (issue 9)'
);

$ddl   = load_file('samples/issue_9-3.sql');
$dupes = [];
$dk->get_duplicate_keys(
   keys     => $tp->get_keys($ddl, $opt),
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
      }
   ],
   'Non-unique key dupes unique key with same col cover (issue 9)'
);

$ddl   = load_file('samples/issue_9-4.sql');
$dupes = [];
$dk->get_duplicate_keys(
   keys     => $tp->get_keys($ddl, $opt),
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
      }
   ],
   'Non-unique key dupes PRIMARY key same col cover (issue 9)'
);

$ddl   = load_file('samples/issue_9-5.sql');
$dupes = [];
$dk->get_duplicate_keys(
   keys     => $tp->get_keys($ddl, $opt),
   callback => $callback);
is_deeply(
   $dupes,
   [],
   'Two unique keys with common prefix are not dupes'
);

is_deeply(
   $dk->{keys}->{i}->{constraining_key}->{cols},
   [qw(a)],
   'Found redundantly unique key',
);

$ddl   = load_file('samples/issue_9-7.sql');
$dupes = [];
$dk->get_duplicate_keys(
   keys     => $tp->get_keys($ddl, $opt),
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
      },
   ],
   'Redundantly unique key dupes normal key after unconstraining'
);

$ddl   = load_file('samples/issue_9-6.sql');
$dupes = [];
$dk->get_duplicate_keys(
   keys     => $tp->get_keys($ddl, $opt),
   callback => $callback);
is_deeply(
   $dupes,
   [
      {
       'duplicate_of' => 'PRIMARY',
       'reason' => 'a is a left-prefix of PRIMARY',
       'duplicate_of_cols' => '`a`,`b`',
       'cols' => '`a`',
       'key' => 'a'
      },
      {
       'duplicate_of' => 'PRIMARY',
       'reason' => 'a_b is a duplicate of PRIMARY',
       'duplicate_of_cols' => '`a`,`b`',
       'cols' => '`a`,`b`',
       'key' => 'a_b'
      },
      {
       'duplicate_of' => 'PRIMARY',
       'reason' => "Uniqueness of ua_b ignored because ua is a stronger constraint\nua_b is a duplicate of PRIMARY",
       'duplicate_of_cols' => '`a`,`b`',
       'cols' => '`a`,`b`',
       'key' => 'ua_b'
      },
      {
       'duplicate_of' => 'PRIMARY',
       'reason' => "Uniqueness of ua_b2 ignored because ua is a stronger constraint\nua_b2 is a duplicate of PRIMARY",
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
$dk->get_duplicate_keys(
   keys     => $tp->get_keys($ddl, $opt),
   callback => $callback);
is_deeply(
   $dupes,
   [
   ],
   'Keep stronger unique constraint that is prefix'
);
is(
   $dk->{keys}->{id_name}->{unconstrained},
   '1',
   'Unconstrained weaker unique set to normal key'
);

exit;
