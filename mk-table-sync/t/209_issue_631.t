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
   plan tests => 2;
}

$sb->wipe_clean($master_dbh);
$sb->create_dbs($master_dbh, [qw(test)]);

# #############################################################################
# Issue 631: mk-table-sync GroupBy and Stream fail
# #############################################################################
diag(`/tmp/12345/use < $trunk/mk-table-sync/t/samples/issue_631.sql`);

$output = `$trunk/mk-table-sync/mk-table-sync h=127.1,P=12345,u=msandbox,p=msandbox,D=d1,t=t h=127.1,P=12345,D=d2,t=t h=127.1,P=12345,D=d3,t=t --print -v --algorithms GroupBy`;
is(
   $output,
"# Syncing D=d2,P=12345,h=127.1,p=...,t=t,u=msandbox
# DELETE REPLACE INSERT UPDATE ALGORITHM EXIT DATABASE.TABLE
INSERT INTO `d2`.`t`(`x`) VALUES ('1');
#      0       0      1      0 GroupBy   2    d1.t
# Syncing D=d3,P=12345,h=127.1,p=...,t=t,u=msandbox
# DELETE REPLACE INSERT UPDATE ALGORITHM EXIT DATABASE.TABLE
INSERT INTO `d3`.`t`(`x`) VALUES ('1');
INSERT INTO `d3`.`t`(`x`) VALUES ('2');
#      0       0      2      0 GroupBy   2    d1.t
",
   'GroupBy can sync issue 631'
);

$output = `$trunk/mk-table-sync/mk-table-sync h=127.1,P=12345,u=msandbox,p=msandbox,D=d1,t=t h=127.1,P=12345,D=d2,t=t h=127.1,P=12345,D=d3,t=t --print -v --algorithms Stream`;
is(
   $output,
"# Syncing D=d2,P=12345,h=127.1,p=...,t=t,u=msandbox
# DELETE REPLACE INSERT UPDATE ALGORITHM EXIT DATABASE.TABLE
INSERT INTO `d2`.`t`(`x`) VALUES ('1');
#      0       0      1      0 Stream    2    d1.t
# Syncing D=d3,P=12345,h=127.1,p=...,t=t,u=msandbox
# DELETE REPLACE INSERT UPDATE ALGORITHM EXIT DATABASE.TABLE
INSERT INTO `d3`.`t`(`x`) VALUES ('1');
INSERT INTO `d3`.`t`(`x`) VALUES ('2');
#      0       0      2      0 Stream    2    d1.t
",
   'Stream can sync issue 631'
);

# #############################################################################
# Done.
# #############################################################################
$sb->wipe_clean($master_dbh);
exit;
