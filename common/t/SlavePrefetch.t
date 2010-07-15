#!/usr/bin/perl

BEGIN {
   die "The MAATKIT_WORKING_COPY environment variable is not set.  See http://code.google.com/p/maatkit/wiki/Testing"
      unless $ENV{MAATKIT_WORKING_COPY} && -d $ENV{MAATKIT_WORKING_COPY};
   unshift @INC, "$ENV{MAATKIT_WORKING_COPY}/common";
};

use strict;
use warnings FATAL => 'all';
use English qw(-no_match_vars);
use Test::More tests => 72;

use SlavePrefetch;
use QueryRewriter;
use BinaryLogParser;
use DSNParser;
use Sandbox;
use TableParser;
use Quoter;
use QueryParser;
use MaatkitTest;

my $dp = new DSNParser(opts=>$dsn_opts);
my $sb = new Sandbox(basedir => '/tmp', DSNParser => $dp);

use constant MKDEBUG => $ENV{MKDEBUG} || 0;

my $qp          = new QueryParser();
my $qr          = new QueryRewriter(QueryParser=>$qp);
my $dbh         = 1;  # we don't need to connect yet
my $oktorun     = 1;
my $more_events = 1;

sub oktorun {
   return $oktorun;
}
sub more_events { 
   $more_events = $_[0];
}

my $spf = new SlavePrefetch(
   dbh             => $dbh,
   oktorun         => \&oktorun,
   chk_int         => 4,
   chk_min         => 1,
   chk_max         => 8,
   QueryRewriter   => $qr,
   have_subqueries => 1,
   stats           => { events => 0 },
);
isa_ok($spf, 'SlavePrefetch');

# ###########################################################################
# Test the pipeline pos.
# ###########################################################################
is_deeply(
   [ $spf->get_pipeline_pos() ],
   [ 0, 0, 0 ],
   'Initial pipeline pos'
);

$spf->set_pipeline_pos(5, 3, 1);
is_deeply(
   [ $spf->get_pipeline_pos() ],
   [ 5, 3, 1 ],
   'Set pipeline pos'
);

$spf->reset_pipeline_pos();
is_deeply(
   [ $spf->get_pipeline_pos() ],
   [ 0, 0, 0 ],
   'Reset pipeline pos'
);

# ###########################################################################
# Test opening and closing a relay log.
# ###########################################################################
my $tmp_file = '/tmp/SlavePrefetch.txt';
diag(`rm -rf $tmp_file 2>/dev/null`);
open my $tmp_fh, '>', $tmp_file;

my $fh;
eval {
   $fh = $spf->open_relay_log(
      relay_log => "$trunk/common/t/samples/relay-binlog001",
      start_pos => 1708,
   );
};
is(
   $EVAL_ERROR,
   '',
   'No error opening relay binlog'
);
ok(
   $fh,
   'Got a filehandle for the relay binglog'
);

is(
   $spf->_mysqlbinlog_cmd(
      tmpdir    => '/dev/null',
      relay_log => "$trunk/common/t/samples/relay-binlog001",
      start_pos => 1708,
   ),
   "mysqlbinlog --local-load=/dev/null --start-pos=1708 $trunk/common/t/samples/relay-binlog001",
   'mysqlbinlog cmd'
);

SKIP: {
   skip "Cannot open $tmp_file for writing", 1 unless $tmp_fh;
   print $tmp_fh $_ while ( <$fh> );
   close $tmp_fh;
   my $output = `cat $tmp_file 2>&1`;
   like(
      $output,
      qr/090910\s+\d+:26:23\s+server\s+id\s+12345\s+end_log_pos\s+1925/,
      'Opened relay binlog'
   );
   diag(`rm -rf $tmp_file 2>/dev/null`);
};

eval {
   $spf->close_relay_log($fh);
};
is(
   $EVAL_ERROR,
   '',
   'No error closing relay binlog'
);

# ###########################################################################
# Test that we can fake SHOW SLAVE STATUS with a callback.
# ###########################################################################

# Remember to lowercase all the keys!
my $slave_status = {
   slave_io_state        => 'Waiting for master to send event',
   master_host           => '127.0.0.1',
   master_user           => 'msandbox',
   master_port           => 12345,
   connect_retry         => 60,
   master_log_file       => 'mysql-bin.000001',
   read_master_log_pos   => 1925,
   relay_log_file        => 'mysql-relay-bin.000003',
   relay_log_pos         => 2062,
   relay_master_log_file => 'mysql-bin.000001',
   slave_io_running      => 'Yes',
   slave_sql_running     => 'Yes',
   replicate_do_db       => undef,
   replicate_ignore_db   => undef,
   replicate_do_table    => undef,
   last_errno            => 0,
   last_error            => undef,
   skip_counter          => 0,
   exec_master_log_pos   => 1925,
   relay_log_space       => 2062,
   until_condition       => 'None',
   until_log_file        => undef,
   until_log_pos         => 0,
   seconds_behind_master => 0,
};
sub show_slave_status {
   return $slave_status;
}

eval {
   $spf->set_callbacks( show_slave_status => \&show_slave_status );
};
is(
   $EVAL_ERROR,
   '',
   'No error setting show_slave_status callback'
);

is_deeply(
   $spf->get_slave_status(),
   {
      running  => 1,
      file     => 'mysql-relay-bin.000003',
      pos      => 2062,
      lag      => 0,
      mfile    => 'mysql-bin.000001',
      mpos     => 1925,
   },
   'Fake SHOW SLAVE STATUS with callback'
);

# Now that we have slave stats, this should be true.
is(
   $spf->slave_is_running(),
   1,
   'Slave is running'
);

# ###########################################################################
# Quick test that we can get the current "interval" and last check.
# ###########################################################################

# We haven't pipelined any events yet so these should be zero.
is_deeply(
   [ $spf->get_interval() ],
   [ 0, 0 ],
   'Get interval and last check'
);

# ###########################################################################
# Test window stuff.
# ###########################################################################

# We didn't pass and offset or window arg to new() so these are defaults.
is_deeply(
   [ $spf->get_window() ],
   [ 128, 4_096 ],
   'Get window (defaults)'
);

$spf->set_window(25, 1_024);  # offset, window
is_deeply(
   [ $spf->get_window() ],
   [ 25, 1_024 ],
   'Set window'
);

# The following tests are sensitive to pos, slave stats and the window
# which we vary to test the subs.  Before each test the curren vals are
# restated so the scenario being tested is clear.

$spf->set_pipeline_pos(100, 150);
$slave_status->{relay_log_pos} = 700;
$spf->_get_slave_status();

# pos:       100
# slave pos: 700
# offset:    25
# window:    1024
is(
   $spf->_far_enough_ahead(),
   0,
   "Far enough ahead: way behind slave"
);

$spf->set_pipeline_pos(700, 750);

# pos:       700
# slave pos: 700
# offset:    25
# window:    1024
is(
   $spf->_far_enough_ahead(),
   0,
   "Far enough ahead: same pos as slave"
);

$spf->set_pipeline_pos(725, 750);

# pos:       725
# slave pos: 700
# offset:    25
# window:    1024
is(
   $spf->_far_enough_ahead(),
   1,
   "Far enough ahead: ahead of slave, right at offset"
);

$spf->set_pipeline_pos(726, 750);

# pos:       726
# slave pos: 700
# offset:    25
# window:    1024
is(
   $spf->_far_enough_ahead(),
   1,
   "Far enough ahead: first byte ahead of slave"
);

$spf->set_pipeline_pos(500, 550);

# pos:       500
# slave pos: 700
# offset:    25
# window:    1024
is(
   $spf->_too_far_ahead(),
   0,
   "Too far ahead: behind slave"
);

$spf->set_pipeline_pos(1500, 1550);

# pos:       1500
# slave pos: 700
# offset:    25
# window:    1024
is(
   $spf->_too_far_ahead(),
   0,
   "Too far ahead: in window"
);

$spf->set_pipeline_pos(1749, 1850);

# pos:       1749
# slave pos: 700
# offset:    25
# window:    1024
is(
   $spf->_too_far_ahead(),
   0,
   "Too far ahead: at last byte in window"
);

$spf->set_pipeline_pos(1750, 1850);

# pos:       1750
# slave pos: 700
# offset:    25
# window:    1024
is(
   $spf->_too_far_ahead(),
   1,
   "Too far ahead: first byte past window"
);

# TODO: test _too_close_to_io().

# To fully test _in_window() we'll need to set a wait_for_master callback.
# For the offline tests, it will simulate MASTER_POS_WAIT() by setting
# the slave stats given an array of stats.  Each call shifts and sets
# global $slave_status to the next stats in the array.  Then when
# _get_slave_status() is called after wait_for_master(), the faux stats
# get set.
my @slave_stats;
my $n_events = 1;
sub wait_for_master {
   if ( @slave_stats ) {
      $slave_status = shift @slave_stats;
   }
   return $n_events;
}

eval {
   $spf->set_callbacks( wait_for_master => \&wait_for_master );
};
is(
   $EVAL_ERROR,
   '',
   'No error setting wait_for_master callback'
);

# _in_window() should return immediately if we're not far enough ahead.
# So do like befor and make it seem like we're way behind the slave.
$spf->set_pipeline_pos(100, 150);

# pos:       100
# slave pos: 700
# offset:    25
# window:    1024
is(
   $spf->_in_window(),
   0,
   "In window: way behind slave"
);

# _in_window() will wait_for_master if we're too far ahead or too close
# to io (and if it's oktorun).  It should let the slave catch up just
# until we're back in the window, then return 1.

# First let's test that oktorun will early-terminate the loop and cause
# _in_window() to return 1 even though we're out of the window.
$oktorun = 0;

$spf->set_pipeline_pos(5000, 5050);

# pos:       5000
# slave pos: 700
# offset:    25
# window:    1024
is(
   $spf->_in_window(),
   0,
   "In window: past window but oktorun caused early return"
);

# Now we're oktorun but too far ahead, so wait_for_master() should
# get called and it's going to wait until the next window.  So let's
# test all this.
$oktorun = 1;

$spf->set_window(50, 100);
$spf->set_pipeline_pos(800, 900);
$slave_status->{exec_master_log_pos} = 100;
$slave_status->{relay_log_pos}       = 200;
$spf->_get_slave_status();

# offset       50
# window       100

# pos   mysql  mk   
# ----+------------
# mst | 100    700
# slv | 200    800

# +100 difference between master and slave pos

# in terms of master pos (for MASTER_POS_WAIT()):
#   in window    150-250
#   past window  450
#   next window  650-750
# in terms of slave pos (for _too_*()):
#   next window  750-850

# Window lower/upper, past and next are in terms of the master pos
# because MASTER_POS_WAIT() uses this (exec_master_log_pos), not
# the slave pos (relay_log_pos).
is(
   $spf->next_window(),
   650,  # in terms of master pos
   'Next window'
);

# Make some faux slave stats that simulate replication progress.
@slave_stats = ();
push @slave_stats,
   {
      # Read 400 bytes
      exec_master_log_pos   => 500,
      relay_log_pos         => 600,
      slave_sql_running     => 'Yes',
      master_log_file       => 'mysql-bin.000001',
      relay_master_log_file => 'mysql-bin.000001',
      relay_log_file        => 'mysql-relay-bin.000003',
      read_master_log_pos   => 1925,
   },
   {
      # Read 100 bytes--in window now
      exec_master_log_pos   => 600,
      relay_log_pos         => 700,
      slave_sql_running     => 'Yes',
      master_log_file       => 'mysql-bin.000001',
      relay_master_log_file => 'mysql-bin.000001',
      relay_log_file        => 'mysql-relay-bin.000003',
      read_master_log_pos   => 1925,
   },
   {
      # Read 50 bytes--shouldn't be used; see below
      exec_master_log_pos   => 650,
      relay_log_pos         => 750,
      slave_sql_running     => 'Yes',
      master_log_file       => 'mysql-bin.000001',
      relay_master_log_file => 'mysql-bin.000001',
      relay_log_file        => 'mysql-relay-bin.000003',
      read_master_log_pos   => 1925,
   };

is(
   $spf->_in_window(),
   1,
   "In window: slave caught up"
);
is_deeply(
   \@slave_stats,
   [
      {
         # Read 50 bytes--shouldn't be used; that's why it's still here
         exec_master_log_pos   => 650,
         relay_log_pos         => 750,
         slave_sql_running     => 'Yes',
         master_log_file       => 'mysql-bin.000001',
         relay_master_log_file => 'mysql-bin.000001',
         relay_log_file        => 'mysql-relay-bin.000003',
         read_master_log_pos   => 1925,
      },
   ],
   'In window: stopped waiting once slave was in window'
);

# #############################################################################
# Test query_is_allowed().
# #############################################################################

# query_is_allowed() expects that the query is already stripped of comments.

# Remember to increase tests (line 6) if you add more types.
my @ok_types = qw(use insert update delete replace);
my @not_ok_types = qw(select create drop alter);

foreach my $ok_type ( @ok_types ) {
   is(
      $spf->query_is_allowed("$ok_type from blah blah etc."),
      1,
      "$ok_type is allowed"
   );
}

foreach my $not_ok_type ( @not_ok_types ) {
   is(
      $spf->query_is_allowed("$not_ok_type from blah blah etc."),
      0,
      "$not_ok_type is NOT allowed"
   );
}

is(
   $spf->query_is_allowed("SET timestamp=1197996507"),
   1,
   "SET timestamp is allowed"
);
is(
   $spf->query_is_allowed('SET @var=1'),
   1,
   'SET @var is allowed'
);
is(
   $spf->query_is_allowed("SET insert_id=34484549"),
   0,
   "SET insert_id is NOT allowed"
);


# #############################################################################
# Test that we skip already-seen timestamps.
# #############################################################################

# No interface for this, so we hack it in.
$spf->{last_ts} = '12345';

is(
   $spf->prepare_query('SET timestamp=12345'),
   undef,
   'Skip already-seen timestamps'
);
is(
   $spf->prepare_query('SET timestamp=44485'),
   'set timestamp=?',
   'Does not skip new timestamp'
);

# #############################################################################
# Test general cases for prepare_query().
# #############################################################################
is_deeply(
   [ $spf->prepare_query('INSERT INTO foo (a,b) VALUES (1,2)') ],
   [
      'select 1 from  foo  where a=1 and b=2',
      'select * from foo where a=? and b=?',
   ],
   'Prepare INSERT'
);

is_deeply(
   [ $spf->prepare_query('UPDATE foo SET bar=1 WHERE id=9') ],
   [
      'select isnull(coalesce(  bar=1 )) from foo where  id=9',
      'select bar=? from foo where id=?'
   ],
   'Prepare UPDATE'
);

is_deeply(
   [ $spf->prepare_query('DELETE FROM foo WHERE id=9') ],
   [
      'select 1 from  foo WHERE id=9',
      'select * from foo where id=?',
   ],
   'Prepare DELETE'
);

is_deeply(
   [ $spf->prepare_query('/* comment */ DELETE FROM foo WHERE id=9; -- foo') ],
   [
      'select 1 from  foo WHERE id=9; ',
      'select * from foo where id=?; ',
   ],
   'Prepare DELETE with comments'
);

is_deeply(
   [ $spf->prepare_query('USE db') ],
   [ 'USE db', 'use ?' ],
   'Prepare USE'
);

is_deeply(
   [ $spf->prepare_query('replace into foo select * from bar') ],
   [ 'select 1 from bar', 'select * from bar' ],
   'Prepare REPLACE INTO'
);

# #############################################################################
# Test that slow queries are skipped, wait_skip_query().
# #############################################################################

# Like the _in_window() test before, we need to simulate all the pos.
# The slow query is at our pos, 100, so we'll need to wait until the
# slave passes this pos.

$spf->set_window(50, 500);
$spf->set_pipeline_pos(100, 200);
$slave_status->{exec_master_log_pos} = 50;
$slave_status->{relay_log_pos}       = 50;
$spf->_get_slave_status();

@slave_stats = ();
push @slave_stats,
   {
      # 20 bytes before slow query...
      exec_master_log_pos   => 80,
      relay_log_pos         => 80,
      slave_sql_running     => 'Yes',
      master_log_file       => 'mysql-bin.000001',
      relay_master_log_file => 'mysql-bin.000001',
      relay_log_file        => 'mysql-relay-bin.000003',
      read_master_log_pos   => 1925,
   },
   {
      # At slow query...
      exec_master_log_pos   => 100,
      relay_log_pos         => 100,
      slave_sql_running     => 'Yes',
      master_log_file       => 'mysql-bin.000001',
      relay_master_log_file => 'mysql-bin.000001',
      relay_log_file        => 'mysql-relay-bin.000003',
      read_master_log_pos   => 1925,
   },
   {
      # Past slow query and done waiting.
      exec_master_log_pos   => 150,
      relay_log_pos         => 150,
      slave_sql_running     => 'Yes',
      master_log_file       => 'mysql-bin.000001',
      relay_master_log_file => 'mysql-bin.000001',
      relay_log_file        => 'mysql-relay-bin.000003',
      read_master_log_pos   => 1925,
   },
   {
      _wait_skip_query => "should stop before here",
   };

# No interface for this either so hack it in.
my ($query, $fp) = $spf->prepare_query('INSERT INTO foo (a,b) VALUES (1,2)');
$spf->{query_stats}->{$fp}->{avg} = 3;

is(
   $spf->prepare_query('INSERT INTO foo (a,b) VALUES (1,2)'),
   undef,
   'Does not prepare slow query'
);

is_deeply(
   \@slave_stats,
   [
      {
         _wait_skip_query => "should stop before here",
      },
   ],
   '_wait_skip_query() stopped waiting once query was skipped'
);


# #############################################################################
# Test the big fish: pipeline_event().
# #############################################################################
my $parser = new BinaryLogParser();
my @events;
my @queries;

sub parse_binlog {
   my ( $file ) = @_;
   @events = ();
   open my $fh, '<', $file or die "Cannot open $file: $OS_ERROR";
   my $more_events = 1;
   while ( $more_events ) {
      my $e = $parser->parse_event(
         next_event => sub { return <$fh>;    },
         tell       => sub { return tell $fh; },
         oktorun    => sub { $more_events = $_[0]; },
      );
      push @events, $e if $e;
   }
   close $fh;
   return;
}

my $event;
sub ple {
   $spf->{stats}->{events}++;
   my $e = $spf->in_window(event=>$event, oktorun=>\&more_events);
   return unless $e;
   $e = $spf->rewrite_query($e);
   if ( $e ) {
      push @queries, [ $e->{arg}, $e->{fingerprint} ];
   }
}

parse_binlog("$trunk/common/t/samples/binlogs/binlog003.txt");
# print Dumper(\@events);  # uncomment if you want to see what's going on

$spf->set_window(100, 300);
$spf->reset_pipeline_pos();
$slave_status->{exec_master_log_pos} = 263;
$slave_status->{relay_log_pos}       = 263;
$spf->_get_slave_status();

# Slave is at event 1 (pos 263) and we "read" (shift) event 1,
# so we are *not* in the window because we're not far enough ahead.
# Given the 100 offset, we need to be at least pos 363, which is
# event 3 at pos/offset 434.
$event = shift @events;
ple();
is_deeply(
   \@queries,
   [],
   "Query not pipelined because we're on top of the slave"
);
   
$event = shift @events;
ple();
is_deeply(
   \@queries,
   [],
   "Query not pipelined because we're still not far enough ahead"
);


$event = shift @events;  # event 3, first past offset
ple();
is_deeply(
   \@queries,
   [ [
      'select 1 from  t  where i=1',  # query
      'select * from t where i=?',    # fingerprint
   ] ],
   'Executes first query in the window'
);

# Events 4 and 5 are still in the window because
#     slave pos    263
#   + offset       100
#   + window       300
#   = outer limit  663
# and event 6 begins at 721, past the outer limit.  But event 4
# is going to trigger the interval which is 4,1,8 (args to new()).
# So let's update the slave status as if the slave had caught up
# to event 3.  But this make event 4 too close to the slave because
# slave pos 434 + offset 100 = 535 as minimum pos ahead of slave.
# So event 4 should be skipped and event 5 at pos 606 is next in window.
$slave_status->{exec_master_log_pos} = 434;
$slave_status->{relay_log_pos}       = 434;

@queries = ();  # clear event 3

$event = shift @events;  # event 4, triggers interval check
ple();
is_deeply(
   \@queries,
   [],
   'Query no longer in window after interval check'
);

is(
   $spf->_get_next_chk_int(),
   8,
   'Next check interval longer'
);

$event = shift @events;  # event 5
ple();
is_deeply(
   \@queries,
   [ [
      'select 1 from  t  limit 1',
      'select * from t limit ?',
   ] ],
   'Pipelines first query in updated window/interval'
);

# Now let's pretend like we've made it too far ahead of the slave,
# past the window which ends at 835.  Event 8 at pos 911 is too far.

@queries = ();  # clear event 5

$event = shift @events;  # event 6
ple();
$event = shift @events;  # event 7
ple();
is_deeply(
   \@queries,
   [
      [
         'select 1 from  t where i = 3 or i = 5',
         'select * from t where i = ? or i = ?'
      ],
      [
         'select isnull(coalesce(  i = 11 )) from t where  i = 10',
         'select i = ? from t where i = ?'
      ]
   ],
   'Events 6 and 7'
);

@queries = ();  # clear events 6 and 7

# _in_window() is going to try to wait for the slave which will start
# calling our callback, popping slave_stats, but we won't bother to
# set this, we'll just terminate the loop early.
$oktorun = 0;
$event = shift @events;  # event 8
ple();
is_deeply(
   \@queries,
   [],
   'Event 8 too far ahead of slave'
);

# ###########################################################################
# Online tests.
# ###########################################################################
my $master_dbh = $sb->get_dbh_for('master');
my $slave_dbh  = $sb->get_dbh_for('slave1');

SKIP: {
   skip 'Cannot connect to sandbox master or slave', 6
      unless $master_dbh && $slave_dbh;

   my $spf = new SlavePrefetch(
      dbh             => $slave_dbh,
      oktorun         => \&oktorun,
      chk_int         => 4,
      chk_min         => 1,
      chk_max         => 8,
      QueryRewriter   => $qr,
      have_subqueries => 1,
      stats           => { events => 0 },
   );

   # Test that exec() actually executes the query.
   $slave_dbh->do('SET @a=1');
   $spf->exec(query=>'SET @a=5', fingerprint=>'set @a=?');
   is_deeply(
      $slave_dbh->selectrow_arrayref('SELECT @a'),
      ['5'],
      'exec() executes the query'
   );

   # This causes an error so that stats->{query_error} gets set
   # and we can check later that get_stats() returns the stats.
   $spf->exec(query=>'foo', fingerprint=>'foo');

   # exec() should have stored the query time which we can
   # get from the stats.
   my ($stats, $query_stats, $query_errors) = $spf->get_stats();
   is_deeply(
      $stats,
      {
         events      => 0,
         query_error => 1,
      },
      'Get stats'
   );

   is_deeply(
      $query_errors,
      {
         foo => 1,
      },
      'Get query errors'
   );

   ok(
      exists $query_stats->{'set @a=?'}
      && exists $query_stats->{'set @a=?'}->{avg}
      && exists $query_stats->{'set @a=?'}->{samples},
      'Get query stats'
   );

   # Test wait_for_master().
   my $ms = $master_dbh->selectrow_hashref('SHOW MASTER STATUS');
   my $ss = $slave_dbh->selectrow_hashref('SHOW SLAVE STATUS');
   my $master_pos = $ms->{Position};
   my %wait_args = (
      dbh       => $slave_dbh,
      mfile     => $ss->{Relay_Master_Log_File},
      until_pos => $master_pos + 100,
   );
   is(
      SlavePrefetch::_wait_for_master(%wait_args),
      -1,
      '_wait_for_master() timeout 1s after no events'
   );

   $wait_args{until_pos} = $master_pos;
   is(
      SlavePrefetch::_wait_for_master(%wait_args),
      0,
      '_wait_for_master() return immediately when already at pos'
   );
};

# #############################################################################
# Test that we get a database.
# #############################################################################
my @dbs;
sub save_dbs {
   my ( %args ) = @_;
   push @dbs, $args{db};
}
sub use_db {
   my ( $dbh, $db ) = @_;
   push @dbs, "USE $db";
};

# Tests for carrying the db forward were removed because
# this is now handled by an earlier processes in mk-slave-prefetch.

# #############################################################################
# Rewrite INSERT without columns list.
# #############################################################################
SKIP: {
   skip 'Cannot connect to sandbox slave', 2 unless $slave_dbh;

   my $q  = new Quoter();
   my $tp = new TableParser(Quoter => $q);

   # Load any 'ol table.  This one is like:
   # CREATE TABLE `issue_94` (
   #   a INT NOT NULL,
   #   b INT NOT NULL,
   #   c CHAR(16) NOT NULL,
   #   INDEX idx (a)
   # );
   $sb->create_dbs($slave_dbh, [qw(test)]);
   $sb->load_file('slave1', 'common/t/samples/issue_94.sql');

   my $spf = new SlavePrefetch(
      dbh             => $slave_dbh,
      oktorun         => \&oktorun,
      chk_int         => 4,
      chk_min         => 1,
      chk_max         => 8,
      QueryRewriter   => $qr,
      TableParser     => $tp,
      QueryParser     => $qp,
      Quoter          => $q,
   );
   my $event = $spf->rewrite_query(
      {
         arg => "INSERT INTO test.issue_94 VALUES (1, 2, 'your ad here')",
      }
   );
   is(
      $event->{arg},
      "select 1 from  test.issue_94  where `a`=1 and `b`= 2 and `c`= 'your ad here'",
      'Rewrote INSERT without columns list'
   );

   $event = $spf->rewrite_query(
      {
         arg => "INSERT INTO issue_94 VALUES (1, 2, 'your ad here')",
      },
      default_db => 'test',
   );
   is(
      $event->{arg},
      "select 1 from  issue_94  where `a`=1 and `b`= 2 and `c`= 'your ad here'",
      'Rewrote INSERT without columns list or db-qualified table'
   );

   $sb->wipe_clean($slave_dbh);
}


# #############################################################################
# Issue 1075: Check if relay log has changed at interval
# #############################################################################
$oktorun     = 1;
$more_events = 1;
@queries = ();
@events  = (
   {
      arg         => 'update db.tbl set col=1 where id=1',
      offset      => 550,
      end_log_pos => 600,
   },
   {
      arg         => 'update db.tbl set col=1 where id=2',
      offset      => 600,
      end_log_pos => 700,
   },
   {
      arg         => 'update db.tbl set col=1 where id=3',
      offset      => 390,
      end_log_pos => 505,
   },
);

$spf = new SlavePrefetch(
   dbh             => $dbh,
   oktorun         => \&oktorun,
   chk_int         => 2,
   chk_min         => 1,
   chk_max         => 3,
   'io-lag'        => 0,
   QueryRewriter   => $qr,
   have_subqueries => 1,
   stats           => { events => 0 },
);
$spf->set_callbacks( wait_for_master => \&wait_for_master );
$spf->set_callbacks( show_slave_status => \&show_slave_status );

$spf->set_window(50, 500);
$spf->set_pipeline_pos(500, 600);

# Executing near end of bin01.
$slave_status = {
   master_log_file       => 'mysql-bin.000001',
   read_master_log_pos   => 1_000,
   exec_master_log_pos   => 1_000,
   relay_master_log_file => 'mysql-bin.000001',
   relay_log_file        => 'mysql-relay-bin.000001',
   relay_log_pos         => 400,
   slave_io_running      => 'Yes',
   slave_sql_running     => 'Yes',
};
$spf->_get_slave_status();
@queries = ();
$event   = shift @events;
ple();
is_deeply(
   \@queries,
   [[
      'select isnull(coalesce(  col=1 )) from db.tbl where  id=1',
      'select col=? from db.tbl where id=?',
   ]],
   "Exec near end of relay log 1 (issue 1075)"
);

# Relay log changes to bin02.  Interval check will check slave status
# and see that relay log file has changed, resetting the pipeline pos
# to zero which will be behind so it will skip events until it's caught up.
$slave_status = {
   master_log_file       => 'mysql-bin.000002',
   read_master_log_pos   => 300,
   exec_master_log_pos   => 300,
   relay_master_log_file => 'mysql-bin.000002',
   relay_log_file        => 'mysql-relay-bin.000002',
   relay_log_pos         => 200,
   slave_io_running      => 'Yes',
   slave_sql_running     => 'Yes',
};
@queries = ();
$event   = shift @events;
ple();
is_deeply(
   \@queries,
   [],
   "Drop query from old relay log, switch to new relay log (issue 1075)"
);

is(
   $more_events,
   0,
   "No more events when relay log changes"
);

# Should have switch to bin02 by now.
$slave_status = {
   master_log_file       => 'mysql-bin.000002',
   read_master_log_pos   => 400,
   exec_master_log_pos   => 303,
   relay_master_log_file => 'mysql-bin.000002',
   relay_log_file        => 'mysql-relay-bin.000002',
   relay_log_pos         => 301,
   slave_io_running      => 'Yes',
   slave_sql_running     => 'Yes',
};
@queries = ();
$event   = shift @events;
ple();
is_deeply(
   \@queries,
   [[
      'select isnull(coalesce(  col=1 )) from db.tbl where  id=3',
      'select col=? from db.tbl where id=?',
   ]],
   "Excuting from new relay log (issue 1075)"
);

# #############################################################################
# Done.
# #############################################################################
my $output = '';
{
   local *STDERR;
   open STDERR, '>', \$output;
   $spf->_d('Complete test coverage');
}
like(
   $output,
   qr/Complete test coverage/,
   '_d() works'
);
exit;
