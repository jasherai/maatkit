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

my $output = '';
my @args   = (qw(--verbose --print --sync-to-master), 'h=127.1,P=12346,u=msandbox,p=msandbox');

# #############################################################################
# Issue 377: Make mk-table-sync print start/end times
# #############################################################################
$output = output(
   sub { mk_table_sync::main(@args, qw(-t mysql.user)) }
);
like(
   $output,
   qr/#\s+0\s+0\s+0\s+0\s+Nibble\s+
   \d{4}-\d\d-\d\d\s\d\d:\d\d:\d\d\s+
   \d{4}-\d\d-\d\d\s\d\d:\d\d:\d\d\s+
   0\s+mysql.user/x,
   "Server time printed with --verbose (issue 377)"
);

# #############################################################################
# Done.
# #############################################################################
$sb->wipe_clean($master_dbh);
$sb->wipe_clean($slave_dbh);
exit;
