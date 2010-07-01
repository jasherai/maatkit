#!/usr/bin/env perl

BEGIN {
   die "The MAATKIT_WORKING_COPY environment variable is not set.  See http://code.google.
com/p/maatkit/wiki/Testing"
      unless $ENV{MAATKIT_WORKING_COPY} && -d $ENV{MAATKIT_WORKING_COPY};
   unshift @INC, "$ENV{MAATKIT_WORKING_COPY}/common";

};

use strict;
use warnings FATAL => 'all';
use English qw( -no_match_vars );
use Test::More;

use MaatkitTest; 
use Sandbox;
require "$trunk/mk-slave-delay/mk-slave-delay";

my $dp  = DSNParser->new( opts => $dsn_opts );
my $sb  = Sandbox->new( basedir => '/tmp', DSNParser => $dp );
my $dbh = $sb->get_dbh_for( 'slave1' );

if ( !$dbh ) {
   plan skip_all => 'Cannot connect to MySQL slave.';
}
elsif ( !@{$dbh->selectcol_arrayref('SHOW DATABASES LIKE "sakila"')} ) {
   plan skip_all => 'sakila db not loaded';
}
else {
   plan tests => 1;
}

my $cnf = '/tmp/12346/my.sandbox.cnf';
my $cmd = "$trunk/mk-slave-delay/mk-slave-delay -F $cnf";

# #############################################################################
# Issue 991: Make mk-slave-delay reconnect to db when it loses the dbconnection
# #############################################################################

my $pid = fork();
my $output;

# If this test fails, then it is because reconnect time is too low.
# Try increasing it.
if ($pid) {
   print "Running mk-slave-delay on the background.\n";
   $output = qx( $cmd --interval 1 --run-time 20 --reconnect 5 2>&1 );
   like( $output, qr/Attempting\s.*slave running/s, 
      'Reconnect to lost slave db.' );
}
else {
   sleep 2;
   die( 'Cannot stop MySQL slave.' ) if system( '/tmp/12346/stop' );

   sleep 1;
   die( 'Cannot start MySQL slave.' ) if system( '/tmp/12346/start' );
    
}

waitpid ($pid, 0);
