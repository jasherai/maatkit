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


my $vp = new VersionParser();
my $dp = new DSNParser(opts=>$dsn_opts);
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

my $output;
my @args = ('h=127.1,P=12345,u=test_907,p=msandbox', 'P=12346,u=msandbox', qw(--print --no-check-slave -d issue_907));

# #############################################################################
# Issue 907: Add --[no]check-privileges 
# #############################################################################

#1) get the script to create the underprivileged user  

$master_dbh->do('drop database if exists issue_907');
$master_dbh->do('create database issue_907');
$master_dbh->do('create table issue_907.t (i int)');
$slave_dbh->do('drop database if exists issue_907');
$slave_dbh->do('create database issue_907');
$slave_dbh->do('create table issue_907.t (i int)');
$slave_dbh->do('insert into issue_907.t values (1)');

`/tmp/12345/use -uroot -e "GRANT SELECT, SHOW DATABASES ON *.* TO 'test_907'\@'localhost' IDENTIFIED BY 'msandbox'"`;

#2) run and get output to see what it's like when it's broken,  
$output = output(
   sub { mk_table_sync::main(@args) },
   undef,
   stderr => 1,
);
like(
   $output,
   qr/User does not have all necessary privileges/,
   "Can't --print without all privs"
);

#3) run again (outside of test) to see what output is like when it works 
# done, output is :

#check if its ok with no privleges option
$output = output(
   sub { mk_table_sync::main(@args, '--no-check-privileges') },
   undef,
   stderr => 1,
);
is(
   $output,
   "DELETE FROM `issue_907`.`t` WHERE `i`=1 LIMIT 1;
",
   "Can --print without all privs and --no-check-privileges"
);

#+ clean up user
$master_dbh->do('DROP USER \'test_907\'@\'localhost\'');

# #############################################################################
# Done.
# #############################################################################
$sb->wipe_clean($master_dbh);
$sb->wipe_clean($slave_dbh);
exit;
