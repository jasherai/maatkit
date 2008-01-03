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

use Test::More tests => 3;
use English qw(-no_match_vars);

require "../MasterSlave.pm";
require "../DSNParser.pm";

my $dp = new DSNParser();

sub throws_ok {
   my ( $code, $pat, $msg ) = @_;
   eval { $code->(); };
   like ( $EVAL_ERROR, $pat, $msg );
}

# First, see whether a sandbox server is running.
my $proc = `ps -eaf | grep rsandbox | grep master | grep port`;

# The output might look like this:
# baron    14396 14363  0 14:08 pts/1    00:00:00
# /home/baron/mysql_source/5.0.45/bin/mysqld
# --defaults-file=/home/baron/rsandbox_5_0_45/master/my.sandbox.cnf
# --basedir=/home/baron/mysql_source/5.0.45
# --datadir=/home/baron/rsandbox_5_0_45/master/data
# --pid-file=/home/baron/rsandbox_5_0_45/master/data/mysql_sandbox16045.pid
# --skip-external-locking --port=16045 --socket=/tmp/mysql_sandbox16045.sock

my ($port) = $proc =~ m/--port=(\d+)/;

my $dbh;
my @slaves;
my $ms = new MasterSlave();

SKIP: {
   skip 'No sandbox server running', 3 unless $port;

   # Connect
   my $dsn = $dp->parse("h=127.0.0.1,P=$port");
   $dbh    = $dp->get_dbh($dp->get_cxn_params($dsn), { AutoCommit => 1 });

   my $callback = sub {
      my ( $dsn, $dbh, $level ) = @_;
      return unless $level;
      ok($dsn, "Connected to one slave "
         . ($dp->as_string($dsn) || '<none>')
         . " from $dsn->{source}");
      push @slaves, $dbh;
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
         recurse       => 1,
         callback      => $callback,
         skip_callback => $skip_callback,
      });

   SKIP: {
      skip 'No slaves found', 1 unless @slaves;

      my $res;
      eval {
         $res = $ms->wait_for_master($dbh, $slaves[0], 1, 0);
      };
      ok(defined $res && $res >= 0, 'Got a good result from waiting');
   }

}
