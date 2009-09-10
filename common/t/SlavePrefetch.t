#!/usr/bin/perl

use strict;
use warnings FATAL => 'all';
use English qw(-no_match_vars);
use Test::More tests => 19;

require '../SlavePrefetch.pm';
require '../QueryRewriter.pm';

use Data::Dumper;
$Data::Dumper::Indent    = 1;
$Data::Dumper::Sortkeys  = 1;
$Data::Dumper::Quotekeys = 0;

my $qr      = new QueryRewriter();
my $dbh     = 1;  # we don't need to connect yet
my $oktorun = 1;
my @queries;

sub oktorun {
   return $oktorun;
}

sub save_query {
   print @queries, [ @_ ];
   return;
}

my $spf = new SlavePrefetch(
   dbh             => $dbh,
   oktorun         => \&oktorun,
   callbacks       => [ \&save_queries ],
   chk_int         => 4,
   chk_min         => 1,
   chk_max         => 8,
   datadir         => '/tmp/12346/data',
   QueryRewriter   => $qr,
   have_subqueries => 1,
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
      tmpdir    => '/dev/null',
      datadir   => '../../common/t/samples',
      start_pos => 1708,
      file      => 'relay-binlog001',
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

SKIP: {
   skip "Cannot open $tmp_file for writing", 1 unless $tmp_fh;
   print $tmp_fh $_ while ( <$fh> );
   close $tmp_fh;
   my $output = `diff $tmp_file ./samples/relay-binlog001-at-1708.txt 2>&1`;
   is(
      $output,
      '',
      'Opened relay binlog at correct pos'
   );
   diag(`rm -rf $tmp_file 2>/dev/null`);
};

# TODO: this doesn't seem to work?
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

# We don't have slave stats yet, so this should be undefined.
is(
   $spf->slave_is_running(),
   undef,
   'Slave is not running'
);

$spf->_get_slave_status(\&show_slave_status);
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
# offset:    256
# window:    1024
is(
   $spf->_far_enough_ahead(),
   0,
   "Far enough ahead: way behind slave"
);

$spf->set_pipeline_pos(700, 750);

# pos:       700
# slave pos: 700
# offset:    256
# window:    1024
is(
   $spf->_far_enough_ahead(),
   0,
   "Far enough ahead: same pos as slave"
);

$spf->set_pipeline_pos(725, 750);

# pos:       725
# slave pos: 700
# offset:    256
# window:    1024
is(
   $spf->_far_enough_ahead(),
   1,
   "Far enough ahead: ahead of slave, right at offset"
);

$spf->set_pipeline_pos(726, 750);

# pos:       726
# slave pos: 700
# offset:    256
# window:    1024
is(
   $spf->_far_enough_ahead(),
   1,
   "Far enough ahead: first byte ahead of slave"
);

# #############################################################################
# Done.
# #############################################################################
exit;
