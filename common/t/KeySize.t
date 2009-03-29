#!/usr/bin/perl

use strict;
use warnings FATAL => 'all';
use English qw(-no_match_vars);
use Test::More tests => 6;

require '../KeySize.pm';
require '../TableParser.pm';
require '../Quoter.pm';
require '../DSNParser.pm';
require '../Sandbox.pm';

use Data::Dumper;
$Data::Dumper::Indent=1;

my $dp  = new DSNParser();
my $sb  = new Sandbox(basedir => '/tmp', DSNParser => $dp);
my $dbh = $sb->get_dbh_for('master')
   or BAIL_OUT('Cannot connect to sandbox master');
my $q  = new Quoter();
my $tp = new TableParser();
my $ks = new KeySize();

my $tbl;
my $struct;
my %key;
my ($size, $chosen_key); 

sub load_file {
   my ($file) = @_;
   open my $fh, "<", $file or die $!;
   my $contents = do { local $/ = undef; <$fh> };
   close $fh;
   return $contents;
}

sub key_info {
   my ( $file, $db, $tbl, $key, $cols ) = @_;
   $sb->load_file('master', $file, $db);
   my $tbl_name = $q->quote($db, $tbl);
   my $struct   = $tp->parse( load_file($file) );
   return (
      name       => $key,
      cols       => $cols || $struct->{keys}->{$key}->{cols},
      tbl_name   => $tbl_name,
      tbl_struct => $struct,
      dbh        => $dbh,
   );
}

$sb->create_dbs($dbh, ['test']);

isa_ok($ks, 'KeySize');

# With an empty table, the WHERE is impossible, so MySQL should optimize
# away the query, and key_len and rows will be NULL in EXPLAIN.
%key = key_info('samples/dupe_key.sql', 'test', 'dupe_key', 'a');
is(
   $ks->get_key_size(%key),
   '0',
   'empty table, impossible where'
);

# Populate the table to make the WHERE possible.
$dbh->do('INSERT INTO test.dupe_key VALUE (1,2,3),(4,5,6),(7,8,9),(0,0,0)');
is(
   $ks->get_key_size(%key),
   '20',
   'single column int key'
);

$key{name} = 'a_2';
is(
   $ks->get_key_size(%key),
   '40',
   'two column int key'
);

$sb->load_file('master', 'samples/issue_331-parent.sql', 'test');
%key = key_info('samples/issue_331.sql', 'test', 'issue_331_t2', 'fk_1', ['id']);
($size, $chosen_key) = $ks->get_key_size(%key);
is(
   $size,
   8,
   'foreign key size'
);
is(
   $chosen_key,
   'PRIMARY',
   'PRIMARY key chosen for foreign key'
);

$sb->wipe_clean($dbh);
exit;
