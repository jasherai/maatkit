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
$sb->create_dbs($master_dbh, [qw(test)]);

# #############################################################################
# Issue 363: lock and rename.
# #############################################################################
$sb->load_file('master', 'mk-table-sync/t/samples/before.sql');

$output = `$trunk/mk-table-sync/mk-table-sync --lock-and-rename h=127.1,P=12345 P=12346 2>&1`;
like($output, qr/requires exactly two/,
   '--lock-and-rename error when DSNs do not specify table');

# It's hard to tell exactly which table is which, and the tables are going to be
# "swapped", so we'll put a marker in each table to test the swapping.
`/tmp/12345/use -e "alter table test.test1 comment='test1'"`;

$output = `$trunk/mk-table-sync/mk-table-sync --execute --lock-and-rename h=127.1,P=12345,u=msandbox,p=msandbox,D=test,t=test1 t=test2 2>&1`;
diag $output if $output;

$output = `/tmp/12345/use -e 'show create table test.test2'`;
like($output, qr/COMMENT='test1'/, '--lock-and-rename worked');

# #############################################################################
# Done.
# #############################################################################
$sb->wipe_clean($master_dbh);
$sb->wipe_clean($slave_dbh);
exit;
