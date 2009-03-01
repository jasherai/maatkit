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

require '../Transformers.pm';
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
   db_tbl     => '`test`.`query_review`',
   tbl_struct => $tbl_struct,
   ts_default => '"2009-01-01"',
   quoter     => $q,
);

isa_ok($qv, 'QueryReview');

my $callback = sub {
   my ( $event ) = @_;
   my $fp = $qr->fingerprint($event->{arg});
   $qv->set_review_info(
      fingerprint => $fp,
      sample      => $event->{arg},
      first_seen  => $event->{ts},
      last_seen   => $event->{ts},
   );
};

my $log;
open $log, '<', 'samples/slow006.txt' or bail_out($OS_ERROR);
1 while ( $lp->parse_event($log, $callback) );
close $log;
open $log, '<', 'samples/slow021.txt' or bail_out($OS_ERROR);
1 while ( $lp->parse_event($log, $callback) );
close $log;

my $res = $dbh->selectall_arrayref(
   'SELECT checksum, first_seen, last_seen FROM query_review order by checksum',
   { Slice => {} });
is_deeply(
   $res,
   [  {  checksum   => '4222630712410165197',
         last_seen  => '2007-10-15 21:45:10',
         first_seen => '2007-10-15 21:45:10'
      },
      {  checksum   => '9186595214868493422',
         last_seen  => '2009-01-01 00:00:00',
         first_seen => '2009-01-01 00:00:00'
      },
      {  checksum   => '11676753765851784517',
         last_seen  => '2007-12-18 11:49:30',
         first_seen => '2007-12-18 11:48:27'
      },
      {  checksum   => '15334040482108055940',
         last_seen  => '2007-12-18 11:49:07',
         first_seen => '2005-12-19 16:56:31'
      }
   ],
   'Updates last_seen'
);

my $event = {
   arg => "UPDATE foo SET bar='nada' WHERE 1",
   ts  => '081222 13:13:13',
};
my $fp = $qr->fingerprint($event->{arg});
my $checksum = Transformers::make_checksum($fp);
$qv->set_review_info(
   fingerprint => $fp,
   sample      => $event->{arg},
   first_seen  => $event->{ts},
   last_seen   => $event->{ts},
);

$res = $dbh->selectall_arrayref(
   "SELECT CONV(checksum,10,16) as checksum, fingerprint, sample, first_seen, "
   . "last_seen, reviewed_by, reviewed_on, comments FROM test.query_review "
   . "WHERE checksum=CONV('$checksum',16,10)",
   {Slice => {}});

is_deeply(
   $res,
   [{
      checksum    => $checksum,
      fingerprint => $fp,
      sample      => "UPDATE foo SET bar='nada' WHERE 1",
      first_seen  => '2008-12-22 13:13:13',
      last_seen   => '2008-12-22 13:13:13',
      reviewed_by => undef,
      reviewed_on => undef,
      comments    => undef,
   }],
   'Stores a new event with default values'
);

$sb->wipe_clean($dbh);
