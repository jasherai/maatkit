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
require "$trunk/mk-deadlock-logger/mk-deadlock-logger";

my $dp   = new DSNParser();
my $sb   = new Sandbox(basedir => '/tmp', DSNParser => $dp);
my $dbh1 = $sb->get_dbh_for('master');

if ( !$dbh1 ) {
   plan skip_all => 'Cannot connect to sandbox master';
}
else {
   plan tests => 3;
}

my $output;
my $cnf = "/tmp/12345/my.sandbox.cnf";
my $cmd = "$trunk/mk-deadlock-logger/mk-deadlock-logger -F $cnf h=127.1";

$sb->wipe_clean($dbh1);
$sb->create_dbs($dbh1, ['test']);

# #############################################################################
# Test --clear-deadlocks
# #############################################################################

# The clear-deadlocks table comes and goes quickly so we can really
# only search the debug output for evidence that it was created.
$output = `MKDEBUG=1 $trunk/mk-deadlock-logger/mk-deadlock-logger F=$cnf,D=test --clear-deadlocks test.make_deadlock 2>&1`;
like(
   $output,
   qr/INSERT INTO test.make_deadlock/,
   'Create --clear-deadlocks table (output)'
);
like(
   $output,
   qr/CREATE TABLE test.make_deadlock/,
   'Create --clear-deadlocks table (debug)'
);


# #############################################################################
# Issue 942: mk-deadlock-logger --clear-deadlocks doesn't work with --interval
# #############################################################################
$output = `MKDEBUG=1 $trunk/mk-deadlock-logger/mk-deadlock-logger F=$cnf,D=test --clear-deadlocks test.make_deadlock2 --interval 1 --run-time 1 2>&1`;
like(
   $output,
   qr/CREATE TABLE test.make_deadlock2/,
   '--clear-deadlocks with --interval (isue 942)'
);

# #############################################################################
# Done.
# #############################################################################
$sb->wipe_clean($dbh1);
exit;
