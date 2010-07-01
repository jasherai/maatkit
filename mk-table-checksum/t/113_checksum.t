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
require "$trunk/mk-table-checksum/mk-table-checksum";

my $dp = new DSNParser(opts=>$dsn_opts);
my $sb = new Sandbox(basedir => '/tmp', DSNParser => $dp);
my $master_dbh = $sb->get_dbh_for('master');

if ( !$master_dbh ) {
   plan skip_all => 'Cannot connect to sandbox master';
}
else {
   plan tests => 2;
}

my $output;
my $cnf='/tmp/12345/my.sandbox.cnf';
my $cmd = "$trunk/mk-table-checksum/mk-table-checksum -F $cnf 127.0.0.1";

$sb->create_dbs($master_dbh, [qw(test)]);
$sb->load_file('master', 'mk-table-checksum/t/samples/before.sql');

$output = `$cmd --checksum --ignore-databases sakila -d test -t checksum_test`;
is(
   $output,
   "3036305396        127.0.0.1.test.checksum_test.0
",
   '--checksum terse output'
);

# #############################################################################
# Issue 103: mk-table-checksum doesn't honor --checksum in --schema mode
# #############################################################################
$output = `$cmd --checksum --schema --ignore-databases sakila -d test -t checksum_test`;
unlike(
   $output,
   qr/DATABASE\s+TABLE/,
   '--checksum in --schema mode prints terse output'
);


# #############################################################################
# Done.
# #############################################################################
$sb->wipe_clean($master_dbh);
exit;
