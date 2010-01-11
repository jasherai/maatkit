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
require "$trunk/mk-table-checksum/mk-table-checksum";

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

my $cnf='/tmp/12345/my.sandbox.cnf';
my ($output, $output2);
my $cmd = "$trunk/mk-table-checksum/mk-table-checksum -F $cnf -d test -t checksum_test 127.0.0.1";

$sb->create_dbs($master_dbh, [qw(test)]);
$sb->load_file('master', 'mk-table-checksum/t/samples/before.sql');

# Test DSN value inheritance
$output = `../mk-table-checksum h=127.1 h=127.2,P=12346 --port 12345 --explain-hosts`;
like(
   $output,
   qr/^Server 127.1:\s+P=12345,h=127.1\s+Server 127.2:\s+P=12346,h=127.2/,
   'DSNs inherit values from --port, etc. (issue 248)'
);

# #########################################################################
# Issue 391: Add --pid option to all scripts
# #########################################################################
`touch /tmp/mk-script.pid`;
$output = `../mk-table-checksum h=127.1,P=12345,u=msandbox,p=msandbox -d test -t issue_122,issue_94 --pid /tmp/mk-script.pid 2>&1`;
like(
   $output,
   qr{PID file /tmp/mk-script.pid already exists},
   'Dies if PID file already exists (issue 391)'
);
`rm -rf /tmp/mk-script.pid`;

# #############################################################################
# Done.
# #############################################################################
$sb->wipe_clean($master_dbh);
$sb->wipe_clean($slave_dbh);
exit;
