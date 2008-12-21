#!/usr/bin/perl

use strict;
use warnings FATAL => 'all';

use Test::More tests => 2;
use English qw(-no_match_vars);
use Data::Dumper;
$Data::Dumper::Indent=1;
require '../DSNParser.pm';
require '../Sandbox.pm';

my $dp  = new DSNParser();
my $sb  = new Sandbox(basedir => '/tmp', DSNParser => $dp);
my $dbh = $sb->get_dbh_for('master')
   or BAIL_OUT('Cannot connect to sandbox master');
$sb->create_dbs($dbh, ['test']);
$sb->load_file('master', 'samples/query_review.sql');

require '../QueryReview.pm';
require '../QueryRewriter.pm';
require '../MySQLDump.pm';
require '../TableParser.pm';
require '../Quoter.pm';
require '../LogParser.pm';
my $qr = new QueryRewriter();
my $lp = new LogParser;
my $q  = new Quoter();
my $tp = new TableParser();
my $du = new MySQLDump();
my $tbl_struct = $tp->parse($du->dump($dbh, $q, 'test', 'query_review', 'table'));
my $qv = new QueryReview(
   dbh        => $dbh,
   qv_tbl     => 'test.query_review',
   tbl_struct => $tbl_struct,
);

isa_ok($qv, 'QueryReview');

my $fingerprints = {
   'select col from bar_tbl' => {
      checksum => '15334040482108055940',
      sample => 'SELECT col FROM bar_tbl'
   },
   'select col from foo_tbl' => {
      checksum => '11676753765851784517',
      sample => 'SELECT col FROM foo_tbl'
   }
};

is_deeply(
   $qv->{fingerprints},
   $fingerprints,
   'Preloads fingerprints, checksums and samples'
);

my $callback = sub {
   my ( $event ) = @_;
   my $fingerprint = $qr->fingerprint($event->{arg});
   $qv->store_event($fingerprint, $event);
};

my $log;
open $log, '<', 'samples/slow006.txt' or bail_out($OS_ERROR);
1 while ( $lp->parse_event($log, $callback) );
close $log;

# TODO:finish test...

$sb->wipe_clean($dbh);
exit;
