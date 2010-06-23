#!/usr/bin/env perl

BEGIN {
   die "The MAATKIT_TRUNK environment variable is not set.  See http://code.google.
com/p/maatkit/wiki/Testing"
      unless $ENV{MAATKIT_TRUNK} && -d $ENV{MAATKIT_TRUNK};
   unshift @INC, "$ENV{MAATKIT_TRUNK}/common";

};

use strict;
use warnings FATAL => 'all';
use English qw( -no_match_vars );
use Test::More;

use DSNParser;
use SlaveRestart;
use MaatkitTest; 
use Sandbox;

my $dp  = new DSNParser ( opts => $dsn_opts );
my $sb  = new Sandbox ( basedir => '/tmp', DSNParser => $dp );
my $dbh = $sb->get_dbh_for( 'slave1' );
my $status;

if ( !$dbh ) {
   plan skip_all => 'Cannot connect to MySQL slave.';
}
elsif ( !@{$dbh->selectcol_arrayref('SHOW DATABASES LIKE "sakila"')} ) {
   plan skip_all => 'sakila db not loaded';
}
else {
   plan tests => 4;
}

my $restart = new SlaveRestart(
   dbh              => $dbh,
   connect_to_slave => \sub { $sb->get_dbh_for( 'slave1' ) }, 
   onfail           => 1,    # Simulate that the reconnect option is used.
   retries          => 3,
   delay            => 5,
);

isa_ok( $restart, 'SlaveRestart' );

# ###########################################################################
# Test checking the status of the slave database. 
# ###########################################################################
my ($rows) = $restart->_check_slave_status( dbh => $dbh );
ok( $rows->{Master_Port} == '12345', 'Check and show slave status correctly.' );

# ###########################################################################
# Test to see if it cannot connect to a slave database.
# ###########################################################################
die( 'Cannot stop MySQL slave.' ) if system( '/tmp/12346/stop && sleep 2' );
($dbh)  = $restart->reconnect();
ok( $dbh == 0, 'Unable to connect to slave.' );

# ###########################################################################
# Test reconnecting to a slave database.
# ###########################################################################
die( 'Cannot start MySQL slave.' ) if system( 'sleep 1 && /tmp/12346/start &' );
($dbh)  = $restart->reconnect();
$status = $dbh->selectrow_hashref("SHOW SLAVE STATUS"); 
ok( $status->{Master_Port} == '12345', 'Reconnect to lost slave db.' );
