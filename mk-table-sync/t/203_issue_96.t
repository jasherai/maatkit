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
my $dp = new DSNParser(opts=>$dsn_opts);
my $sb = new Sandbox(basedir => '/tmp', DSNParser => $dp);
my $master_dbh = $sb->get_dbh_for('master');

if ( !$master_dbh ) {
   plan skip_all => 'Cannot connect to sandbox master';
}
else {
   plan tests => 1;
}

$sb->wipe_clean($master_dbh);
$sb->create_dbs($master_dbh, [qw(test)]);

# #############################################################################
# Issue 96: mk-table-sync: Nibbler infinite loop
# #############################################################################
diag(`/tmp/12345/use -D test < $trunk/common/t/samples/issue_96.sql`);
sleep 1;
$output = `$trunk/mk-table-sync/mk-table-sync h=127.1,P=12345,u=msandbox,p=msandbox,D=issue_96,t=t h=127.1,P=12345,D=issue_96,t=t2 --algorithms Nibble --chunk-size 2 --print`;
chomp $output;
is(
   $output,
   "UPDATE `issue_96`.`t2` SET `from_city`='ta' WHERE `package_id`='4' AND `location`='CPR' LIMIT 1;",
   'Sync nibbler infinite loop (issue 96)'
);

# #############################################################################
# Done.
# #############################################################################
$sb->wipe_clean($master_dbh);
exit;
