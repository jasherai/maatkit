#!/usr/bin/perl

use strict;
use warnings FATAL => 'all';
use Test::More tests => 3;
use English qw(-no_match_vars);

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

sub load_file {
   my ($file) = @_;
   open my $fh, "<", $file or die $!;
   my $contents = do { local $/ = undef; <$fh> };
   close $fh;
   return $contents;
}

my $q  = new Quoter();
my $tp = new TableParser();
my $ks = new KeySize();

isa_ok($ks, 'KeySize');

$sb->create_dbs($dbh, ['test']);
$sb->load_file('master', 'samples/dupe_key.sql', 'test');
$dbh->do('INSERT INTO test.dupe_key VALUE (1,2,3),(4,5,6),(7,8,9),(0,0,0)');

my $tbl    = $q->quote('test', 'dupe_key');
my $struct = $tp->parse( load_file('samples/dupe_key.sql') );
is(
   $ks->get_key_size(tbl=>$tbl,key=>$struct->{keys}->{a},dbh=>$dbh),
   '20',
   'dupe_key key a'
);

is(
   $ks->get_key_size(tbl=>$tbl,key=>$struct->{keys}->{a_2},dbh=>$dbh),
   '40',
   'dupe_key key a_2'
);

exit;
$sb->wipe_clean($dbh);
exit;
