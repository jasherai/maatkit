#!/usr/bin/env perl

BEGIN {
   die "The MAATKIT_TRUNK environment variable is not set.  See http://code.google.com/p/maatkit/wiki/Testing"
      unless $ENV{MAATKIT_TRUNK} && -d $ENV{MAATKIT_TRUNK};
   unshift @INC, "$ENV{MAATKIT_TRUNK}/common";
};

use strict;
use warnings FATAL => 'all';
use English qw(-no_match_vars);
use Test::More;

use MaatkitTest;
use Sandbox;
require "$trunk/mk-table-sync/mk-table-sync";

my $output;
my $vp = new VersionParser();
my $dp = new DSNParser();
my $sb = new Sandbox(basedir => '/tmp', DSNParser => $dp);
my $master_dbh = $sb->get_dbh_for('master');
my $slave_dbh  = $sb->get_dbh_for('slave1');

if ( !$master_dbh ) {
   plan skip_all => 'Cannot connect to sandbox master';
}
elsif ( !$slave_dbh ) {
   plan skip_all => 'Cannot connect to sandbox slave';
}
else {
   plan tests => 2;
}

$sb->wipe_clean($master_dbh);
$sb->wipe_clean($slave_dbh);
$sb->create_dbs($master_dbh, [qw(test)]);

# #############################################################################
# Issue 907: Add --[no]check-privileges 
# #############################################################################

#1) get the script to create the underprivileged user  

$master_dbh->do('CREATE USER \'test_907\'@\'localhost\'');
#2) run and get output to see what it's like when it's broken,  
$output=`$trunk/mk-table-sync/mk-table-sync --no-check-slave --sync-to-master --print h=127.0.0.1,P=12346,u=msandbox,p=msandbox,D=mysql,t=user`;
like($output, qr/Access denied for user/, 'Testing fail even on print with unprivileged user') || diag explain $output;
#3) run again (outside of test) to see what output is like when it works 
# done, output is :
#DBI connect('mysql;host=127.0.0.1;port=12346;mysql_read_default_group=client','test',...) failed: Access denied for user 'test'@'localhost' (using password: NO) at ../mk-table-sync line 1169
#check if its ok with no privleges option
$output=`$trunk/mk-table-sync/mk-table-sync --no-check-privileges --no-check-slave --sync-to-master --print h=127.0.0.1,P=12346,u=test_907,D=mysql,t=user`;
like($output, '', 'Test fail with no check privileges also') || diag explain $output;

#+ clean up user
$master_dbh->do('DROP USER \'test_907\'@\'localhost\'');




# #############################################################################
# Done.
# #############################################################################
$sb->wipe_clean($master_dbh);
$sb->wipe_clean($slave_dbh);
exit;
