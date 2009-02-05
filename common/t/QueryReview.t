#!/usr/bin/perl

use strict;
use warnings FATAL => 'all';

use Test::More tests => 11;
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
   group_by    => 'fingerprint',
   dbh        => $dbh,
   db_tbl     => 'test.query_review',
   tbl_struct => $tbl_struct,
   ts_default => '"2009-01-01"',
);

isa_ok($qv, 'QueryReview');
is_deeply(
   $qv->{cache},
   {
      'select col from bar_tbl' => {
         checksum => 'D4CD74934382A184',
         dirty    => 0,
         cols     => {
            first_seen => '2005-12-19 16:56:31',
            last_seen  => '2006-12-20 11:48:57',
         }
      },
      'select col from foo_tbl' => {
         checksum => 'A20C29AF174CE545',
         dirty    => 0,
         cols     => {
            first_seen => '2007-12-18 11:48:27', 
            last_seen  => '2007-12-18 11:48:27',
         }
      },
   },
   'Preloads fingerprints, checksums, first_seen and last_seen'
);

my @basic_cols = sort @{$qv->{basic_cols}};
is_deeply(
   \@basic_cols,
   [qw(checksum comments fingerprint first_seen last_seen reviewed_by reviewed_on sample)],
   'Has list of basic columns'
);
is_deeply(
   $qv->{extra_cols},
   [],
   'Has no extra columns'
);

use Data::Dumper;
$Data::Dumper::Indent=1;

my $callback = sub {
   my ( $event ) = @_;
   $event->{fingerprint} = $qr->fingerprint($event->{arg});
   $qv->cache_event($event);
};

my $log;
open $log, '<', 'samples/slow006.txt' or bail_out($OS_ERROR);
1 while ( $lp->parse_event($log, $callback) );
close $log;
open $log, '<', 'samples/slow021.txt' or bail_out($OS_ERROR);
1 while ( $lp->parse_event($log, $callback) );
close $log;
$qv->flush_event_cache();

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
$event->{fingerprint} = $fp;
my $checksum = Transformers::make_checksum($fp);
$qv->cache_event($event);
is($event->{checksum}, $checksum, 'Adds checksum to event');

$res = $dbh->selectall_arrayref("SELECT CONV(checksum,10,16), fingerprint,
sample, first_seen, last_seen, reviewed_by, reviewed_on, comments
FROM query_review
WHERE checksum=CONV('$checksum',16,10)");
is_deeply(
   $res,
   [
      [
         $checksum,
         $fp,
         "UPDATE foo SET bar='nada' WHERE 1",
         '2008-12-22 13:13:13',
         '2008-12-22 13:13:13',
         undef,undef,undef
      ]
   ],
   'Stores a new event with default values'
);
is($qv->{cache}->{$fp}->{checksum}, $checksum, 'Caches new checksum');

# Test that it will query the table to see that the event is not new and
# therefore update it instead of trying to add it again.
$qv = new QueryReview(
   group_by    => 'fingerprint',
   dbh        => $dbh,
   db_tbl     => 'test.query_review',
   tbl_struct => $tbl_struct,
   ts_default => '"2009-01-01"',
);

$event->{ts} = '081222 17:17:17';
$qv->cache_event($event);
$qv->flush_event_cache();
$res = $dbh->selectall_arrayref(
   "SELECT first_seen, last_seen FROM test.query_review "
      . "WHERE checksum=CONV('$checksum',16,10)",
   { Slice => {} });
is_deeply(
   $res,
   [
      {  first_seen => '2008-12-22 13:13:13',
         last_seen  => '2008-12-22 17:17:17',
      },
   ],
   'Updates old, non-cached event'
);
is($qv->{cache}->{$fp}->{checksum}, $checksum, 'Adds old event\'s checksum to cache');

# Test that it will query the table to see that the event is not new and
# therefore update it instead of trying to add it again.
$dbh->do('truncate table test.query_review');
$qv = new QueryReview(
   group_by    => 'fingerprint',
   dbh        => $dbh,
   db_tbl     => 'test.query_review',
   tbl_struct => $tbl_struct,
   ts_default => '"2009-01-01"',
);

$event->{ts} = undef;
eval {
   $qv->cache_event($event);
   $qv->cache_event($event);
   $qv->flush_event_cache();
   $qv->cache_event($event);
   $qv->flush_event_cache();
};
is($EVAL_ERROR, '', 'No error on undef ts');

$sb->wipe_clean($dbh);
