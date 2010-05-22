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
$sb->create_dbs($master_dbh, ['test']);

# #############################################################################
# Issue 410: mk-table-sync doesn't have --float-precision
# #############################################################################

$master_dbh->do('create table test.fl (id int not null primary key, f float(12,10), d double)');
$master_dbh->do('insert into test.fl values (1, 1.0000012, 2.0000012)');
sleep 1;
$slave_dbh->do('update test.fl set d = 2.0000013 where id = 1');

# The columns really are different at this point so we should
# get a REPLACE without using --float-precision.
$output = `$trunk/mk-table-sync/mk-table-sync --sync-to-master h=127.1,P=12346,u=msandbox,p=msandbox,D=test,t=fl --print 2>&1`;
is(
   $output,
   "REPLACE INTO `test`.`fl`(`id`, `f`, `d`) VALUES ('1', '1.0000011921', '2.0000012');
",
   'No --float-precision so double col diff at high precision (issue 410)'
);

# Now use --float-precision to roundoff the differing columns.
# We have 2.0000012
#     vs. 2.0000013, so if we round at 6 places, they should be the same.
$output = `$trunk/mk-table-sync/mk-table-sync --sync-to-master h=127.1,P=12346,u=msandbox,p=msandbox,D=test,t=fl --print --float-precision 6 2>&1`;
is(
   $output,
   '',
   '--float-precision so no more diff (issue 410)'
);

# #############################################################################
# Done.
# #############################################################################
$sb->wipe_clean($master_dbh);
$sb->wipe_clean($slave_dbh);
exit;
