#!/usr/bin/env perl

BEGIN {
   die "The MAATKIT_WORKING_COPY environment variable is not set.  See http://code.google.com/p/maatkit/wiki/Testing"
      unless $ENV{MAATKIT_WORKING_COPY} && -d $ENV{MAATKIT_WORKING_COPY};
   unshift @INC, "$ENV{MAATKIT_WORKING_COPY}/common";
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
my $slave_dbh  = $sb->get_dbh_for('slave1');

if ( !$master_dbh ) {
   plan skip_all => 'Cannot connect to sandbox master';
}
elsif ( !$slave_dbh ) {
   plan skip_all => 'Cannot connect to sandbox slave';
}
else {
   plan tests => 1;
}

$sb->wipe_clean($master_dbh);
$sb->wipe_clean($slave_dbh);
$sb->create_dbs($master_dbh, [qw(test)]);

# #############################################################################
# Issue 644: Another possible infinite loop with mk-table-sync Nibble
# #############################################################################
diag(`/tmp/12345/use < $trunk/mk-table-sync/t/samples/issue_644.sql`);
sleep 1;
$output = `$trunk/mk-table-sync/mk-table-sync --sync-to-master h=127.1,P=12346,u=msandbox,p=msandbox -d issue_644 --print --chunk-size 2 -v`;
is(
   $output,
"# Syncing P=12346,h=127.1,p=...,u=msandbox
# DELETE REPLACE INSERT UPDATE ALGORITHM EXIT DATABASE.TABLE
#      0       0      0      0 Nibble    0    issue_644.t
",
   'Sync infinite loop (issue 644)'
);

# #############################################################################
# Done.
# #############################################################################
$sb->wipe_clean($master_dbh);
$sb->wipe_clean($slave_dbh);
exit;
