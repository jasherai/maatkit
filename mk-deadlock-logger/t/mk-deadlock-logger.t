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

use Test::More tests => 6;
use English qw(-no_match_vars);
use DBI;

# Open a connection to MySQL, or skip the rest of the tests.
my ($dbh1, $dbh2);
eval {
   $dbh1 = DBI->connect(
      "DBI:mysql:;mysql_read_default_group=mysql", undef, undef,
      { PrintError => 0, RaiseError => 1, AutoCommit => 0 });
   $dbh2 = DBI->connect(
      "DBI:mysql:;mysql_read_default_group=mysql", undef, undef,
      { PrintError => 0, RaiseError => 1, AutoCommit => 0 });
};
SKIP: {
   skip 'Cannot connect to MySQL', 2 if $EVAL_ERROR;

   # Set up the table for creating a deadlock.
   $dbh1->do("drop table if exists test.dl");
   $dbh1->do("create table test.dl(a int) engine=innodb");
   $dbh1->do("insert into test.dl(a) values(0), (1)");
   $dbh1->commit;
   $dbh1->{InactiveDestroy} = 1;
   $dbh2->{InactiveDestroy} = 1;

   # Fork off two children to deadlock against each other.
   my %children;
   foreach my $child ( 0..1 ) {
      my $pid = fork();
      if ( defined($pid) && $pid == 0 ) { # I am a child
         eval {
            my $dbh = ($dbh1, $dbh2)[$child];
            my @stmts = (
               "set transaction isolation level serializable",
               "begin",
               "select * from test.dl where a = $child",
               "update test.dl set a = $child where a <> $child",
            );
            foreach my $stmt (@stmts[0..2]) {
               $dbh->do($stmt);
            }
            sleep(1 + $child);
            $dbh->do($stmts[-1]);
         };
         if ( $EVAL_ERROR ) {
            if ( $EVAL_ERROR !~ m/Deadlock found/ ) {
               die $EVAL_ERROR;
            }
         }
         exit(0);
      }
      elsif ( !defined($pid) ) {
         die("Unable to fork for clearing deadlocks!\n");
      }
      # I already exited if I'm a child, so I'm the parent.
      $children{$child} = $pid;
   }

   # Wait for the children to exit.
   foreach my $child ( keys %children ) {
      my $pid = waitpid($children{$child}, 0);
   }

   # Test that there is a deadlock
   my ($stat) = $dbh1->selectrow_array('show innodb status');
   like($stat, qr/WE ROLL BACK/, 'There was a deadlock');

   my $output = `perl ../mk-deadlock-logger --print --source localhost`;
   like($output, qr/GEN_CLUST_INDEX/, 'Deadlock logger prints the output');
   $dbh1->do('drop table test.dl');
}

# Check daemonization
my $deadlocks_tbl = `cat deadlocks_tbl.sql`;
$dbh1->do('USE test');
$dbh1->do('DROP TABLE IF EXISTS deadlocks');
$dbh1->do("$deadlocks_tbl");

my $cmd = '../mk-deadlock-logger -d h=localhost,D=test,t=deadlocks -s h=localhost --daemonize -m 4h -i 30s --pid /tmp/mk-deadlock-logger.pid';
`$cmd`;

my $output = `ps -eaf | grep 'mk-deadlock-logger \-d'`;
like($output, qr/$cmd/, 'It lives daemonized');

ok(-f '/tmp/mk-deadlock-logger.pid', 'PID file created');
my ($pid) = $output =~ /\s+(\d+)\s+/;
$output = `cat /tmp/mk-deadlock-logger.pid`;
is($output, $pid, 'PID file has correct PID');

# Kill it
`kill $pid`;
sleep 1;
ok(! -f '/tmp/mk-deadlock-logger.pid', 'PID file removed');

exit;
