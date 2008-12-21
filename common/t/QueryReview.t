#!/usr/bin/perl

use strict;
use warnings FATAL => 'all';

use Test::More tests => 3;
use English qw(-no_match_vars);

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
   key_attrib => 'arg',
   fingerprint => sub { return $qr->fingerprint(@_); },
   dbh        => $dbh,
   qv_tbl     => 'test.query_review',
   tbl_struct => $tbl_struct,
);

isa_ok($qv, 'QueryReview');

use Data::Dumper;
$Data::Dumper::Indent=1;

my $fingerprints = {
   'select col from bar_tbl' => {
      checksum  => '15334040482108055940',
      sample    => 'SELECT col FROM bar_tbl',
      last_seen => '2006-12-20 11:48:57',
   },
   'select col from foo_tbl' => {
      checksum  => '11676753765851784517',
      sample    => 'SELECT col FROM foo_tbl',
      last_seen => '2007-12-18 11:48:27',
   }
};

is_deeply(
   $qv->{fingerprints},
   $fingerprints,
   'Preloads fingerprints, checksums and samples'
);

my $callback = sub {
   my ( $event ) = @_;
   $qv->store_event($event);
};

my $log;
open $log, '<', 'samples/slow006.txt' or bail_out($OS_ERROR);
1 while ( $lp->parse_event($log, $callback) );
close $log;

my $res = $dbh->selectall_arrayref('SELECT checksum, first_seen, last_seen, cnt FROM query_review');
is_deeply(
   $res,
   [
      [
         '11676753765851784517',
         '2007-12-18 11:48:27',
         '2007-12-18 11:49:30',
         '6',
      ],
      [
         '15334040482108055940',
         '2005-12-19 16:56:31',
         '2007-12-18 11:49:07',
         '6',
      ],
   ],
   'Updates last_seen and cnt correctly'
);

# TODO: more tests...

$sb->wipe_clean($dbh);
exit;
