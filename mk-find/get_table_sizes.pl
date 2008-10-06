#!/usr/bin/perl

use strict;
use warnings FATAL => 'all';
use DBI;

# Connect to the server with the list of hosts to check
my $dbh = DBI->connect('DBI:mysql:;host=localhost;', undef, undef, {RaiseError => 1});
my $hosts = $dbh->selectall_arrayref('select * from test.hosts_to_check', { Slice => {} } );

# How to connect to the server that will store the data
my $dsn = "h=127.0.0.1,u=msandbox,p=msandbox,P=5123";

# iterate through the hosts and store their data in $dsn
foreach my $host ( @$hosts ) {
   my $cmd = "mk-find --engine '.' --noquote -h $host->{host} -P $host->{port} -u '$host->{user}' -p "
      . "'$host->{password}' --exec_dsn $dsn --exec 'replace into test.table_size"
      . "(day, host, port, db, tbl, engine, rows, datasize, idxsize) values"
      . qq{(current_date, "$host->{host}", $host->{port}, "%D", "%N", "%E", %S}
      . ", %d, %I)'";
   print `$cmd`;
}
