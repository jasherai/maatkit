#!/usr/bin/perl

use strict;
use warnings FATAL => 'all';

use English qw('no_match_vars);
use DBI;
use Test::More tests => 3;

# Open a connection to MySQL, or skip the rest of the tests.
my $output;
my $dbh;
eval {
   $dbh = DBI->connect(
   "DBI:mysql:;mysql_read_default_group=mysql", undef, undef,
   { PrintError => 0, RaiseError => 1 })
};
SKIP: {
   skip 'Cannot connect to MySQL', 1 unless $dbh;

   $dbh->do('drop table if exists test.heartbeat');
   $dbh->do(q{CREATE TABLE test.heartbeat (
                id int NOT NULL PRIMARY KEY,
                ts datetime NOT NULL
             )});
   $dbh->do('INSERT INTO test.heartbeat(id) VALUES(1)');

   # Start one daemonized instance to update it
   `perl ../mk-heartbeat --daemonize -D test --update -m 5s`;
   $output = `ps -eaf | grep mk-heartbeat | grep daemonize`;
   like($output, qr/perl ...mk-heartbeat/, 'It is running');
   $output = `perl ../mk-heartbeat -D test --monitor -m 1s`;
   chomp ($output);
   is (
      $output,
      '   0s [  0.00s,  0.00s,  0.00s ]',
      'It is being updated',
   );
   sleep(5);
   $output = `ps -eaf | grep mk-heartbeat | grep daemonize`;
   chomp $output;
   unlike($output, qr/perl ...mk-heartbeat/, 'It is not running anymore');
   $dbh->do('drop table if exists test.heartbeat'); # This will kill it
}
