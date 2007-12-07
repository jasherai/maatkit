#!/usr/bin/perl

use strict;
use warnings FATAL => 'all';

use English qw('no_match_vars);
use DBI;
use Test::More tests => 1;

# Open a connection to MySQL, or skip the rest of the tests.
my $dbh;
eval {
   $dbh = DBI->connect(
   "DBI:mysql:;mysql_read_default_group=mysql", undef, undef,
   { PrintError => 0, RaiseError => 1 })
};
SKIP: {
   skip 'Cannot connect to MySQL', 1 unless $dbh;

   $dbh->do(q{CREATE TABLE test.heartbeat (
                id int NOT NULL PRIMARY KEY,
                ts datetime NOT NULL
             )});
   $dbh->do('INSERT INTO test.heartbeat(id) VALUES(1)');

   # Start one daemonized instance to update it
   my $output = `perl ../mk-heartbeat -D test -t heartbeat --update -m 10s`;
   like($output, qr/`mysql`.`columns_priv`/, 'Found mysql.columns_priv');
