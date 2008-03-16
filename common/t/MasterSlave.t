#!/usr/bin/perl

# This program is copyright (c) 2007 Baron Schwartz.
# Feedback and improvements are welcome.
#
# THIS PROGRAM IS PROVIDED "AS IS" AND WITHOUT ANY EXPRESS OR IMPLIED
# WARRANTIES, INCLUDING, WITHOUT LIMITATION, THE IMPLIED WARRANTIES OF
# MERCHANTIBILITY AND FITNESS FOR A PARTICULAR PURPOSE.
#
# This program is free software; you can redistribute it and/or modify it under
# the terms of the GNU General Public License as published by the Free Software
# Foundation, version 2; OR the Perl Artistic License.  On UNIX and similar
# systems, you can issue `man perlgpl' or `man perlartistic' to read these
# licenses.
#
# You should have received a copy of the GNU General Public License along with
# this program; if not, write to the Free Software Foundation, Inc., 59 Temple
# Place, Suite 330, Boston, MA  02111-1307  USA.
use strict;
use warnings FATAL => 'all';

use Test::More tests => 28;
use English qw(-no_match_vars);

require "../MasterSlave.pm";
require "../DSNParser.pm";

`./make_repl_sandbox`;

my $dbh;
my @slaves;
my @sldsns;
my $ms = new MasterSlave();
my $dp = new DSNParser();

my $dsn = $dp->parse("h=127.0.0.1,P=12345");
$dbh    = $dp->get_dbh($dp->get_cxn_params($dsn), { AutoCommit => 1 });

my $callback = sub {
   my ( $dsn, $dbh, $level, $parent ) = @_;
   return unless $level;
   ok($dsn, "Connected to one slave "
      . ($dp->as_string($dsn) || '<none>')
      . " from $dsn->{source}");
   push @slaves, $dbh;
   push @sldsns, $dsn;
};

my $skip_callback = sub {
   my ( $dsn, $dbh, $level ) = @_;
   return unless $level;
   ok($dsn, "Skipped one slave "
      . ($dp->as_string($dsn) || '<none>')
      . " from $dsn->{source}");
};

$ms->recurse_to_slaves(
   {  dsn_parser    => $dp,
      dbh           => $dbh,
      dsn           => $dsn,
      recurse       => 2,
      callback      => $callback,
      skip_callback => $skip_callback,
   });

is_deeply(
   $ms->get_master_dsn( $slaves[0], undef, $dp ),
   {  h => '127.0.0.1',
      u => undef,
      P => '12345',
      S => undef,
      F => undef,
      p => undef,
      D => undef,
      C => undef,
   },
   'Got master DSN',
);

# The picture:
# 127.0.0.1:12345
# +- 127.0.0.1:12346
# |  +- 127.0.0.1:12347
# +- 127.0.0.1:12348
is($ms->get_slave_status($slaves[0])->{master_port}, 12345, 'slave 1 port');
is($ms->get_slave_status($slaves[1])->{master_port}, 12346, 'slave 2 port');
is($ms->get_slave_status($slaves[2])->{master_port}, 12345, 'slave 3 port');

map { $ms->stop_slave($_) } @slaves;
map { $ms->start_slave($_) } @slaves;

my $res;
$res = $ms->wait_for_master($dbh, $slaves[0], 1, 0);
ok(defined $res && $res >= 0, 'Wait was successful');

$ms->stop_slave($slaves[0]);
$dbh->do('drop database if exists test'); # Any stmt will do
`(sleep 1; echo "start slave" | /tmp/12346/use)&`;
eval {
   $res = $ms->wait_for_master($dbh, $slaves[0], 1, 0);
};
ok($res, 'Waited for some events');

$ms->stop_slave($slaves[0]);
$dbh->do('drop database if exists test'); # Any stmt will do
eval {
   $res = $ms->catchup_to_master($slaves[0], $dbh, 10);
};
diag $EVAL_ERROR if $EVAL_ERROR;
ok(!$EVAL_ERROR, 'No eval error catching up');
my $master_stat = $ms->get_master_status($dbh);
my $slave_stat = $ms->get_slave_status($slaves[0]);
is_deeply(
   $ms->repl_posn($master_stat),
   $ms->repl_posn($slave_stat),
   'Caught up');

eval {
   $ms->make_sibling_of_master($slaves[1], $sldsns[1], $dp, 100);
};
diag $EVAL_ERROR if $EVAL_ERROR;
ok(!$EVAL_ERROR, 'Made slave sibling of master');

# The picture now:
# 127.0.0.1:12345
# +- 127.0.0.1:12346
# +- 127.0.0.1:12347
# +- 127.0.0.1:12348
is($ms->get_slave_status($slaves[0])->{master_port}, 12345, 'slave 1 port');
is($ms->get_slave_status($slaves[1])->{master_port}, 12345, 'slave 2 port');
is($ms->get_slave_status($slaves[2])->{master_port}, 12345, 'slave 3 port');

eval {
   $ms->make_slave_of_sibling(
      $slaves[0], $sldsns[0],
      $slaves[0], $sldsns[0], $dp, 100);
};
like($EVAL_ERROR, qr/slave of itself/, 'Cannot make slave slave of itself');

eval {
   $ms->make_slave_of_sibling(
      $slaves[0], $sldsns[0],
      $slaves[1], $sldsns[1], $dp, 100);
};
diag $EVAL_ERROR if $EVAL_ERROR;
ok(!$EVAL_ERROR, 'Made slave of sibling');

# The picture now:
# 127.0.0.1:12345
# +- 127.0.0.1:12347
# |  +- 127.0.0.1:12346
# +- 127.0.0.1:12348
is($ms->get_slave_status($slaves[0])->{master_port}, 12347, 'slave 1 port');
is($ms->get_slave_status($slaves[1])->{master_port}, 12345, 'slave 2 port');
is($ms->get_slave_status($slaves[2])->{master_port}, 12345, 'slave 3 port');

eval {
   $ms->make_slave_of_uncle(
      $slaves[0], $sldsns[0],
      $slaves[2], $sldsns[2], $dp, 100);
};
diag $EVAL_ERROR if $EVAL_ERROR;
ok(!$EVAL_ERROR, 'Made slave of uncle');

# The picture now:
# 127.0.0.1:12345
# +- 127.0.0.1:12347
# +- 127.0.0.1:12348
#    +- 127.0.0.1:12346
is($ms->get_slave_status($slaves[0])->{master_port}, 12348, 'slave 1 port');
is($ms->get_slave_status($slaves[1])->{master_port}, 12345, 'slave 2 port');
is($ms->get_slave_status($slaves[2])->{master_port}, 12345, 'slave 3 port');

eval {
   $ms->detach_slave($slaves[0]);
};
diag $EVAL_ERROR if $EVAL_ERROR;
ok(!$EVAL_ERROR, 'Detached slave');

# The picture now:
# 127.0.0.1:12345
# +- 127.0.0.1:12347
# +- 127.0.0.1:12348
is($ms->get_slave_status($slaves[0]), 0, 'slave 1 detached');
is($ms->get_slave_status($slaves[1])->{master_port}, 12345, 'slave 2 port');
is($ms->get_slave_status($slaves[2])->{master_port}, 12345, 'slave 3 port');
