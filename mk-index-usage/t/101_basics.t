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
# See http://code.google.com/p/maatkit/wiki/Testing
shift @INC;  # MaatkitTest's unshift
require "$trunk/mk-index-usage/mk-index-usage";

use Sandbox;

my $dp = new DSNParser(opts=>$dsn_opts);
my $sb = new Sandbox(basedir => '/tmp', DSNParser => $dp);
my $dbh = $sb->get_dbh_for('master');

if ( !$dbh ) {
   plan skip_all => 'Cannot connect to sandbox master';
}
else {
   plan tests => 2;
}

my $cnf  = '/tmp/12345/my.sandbox.cnf';
my @args = ('-F', $cnf);
my $output;

ok(
   no_diff(
      sub {
          mk_index_usage::main(@args, "$trunk/common/t/samples/slow044.txt");
      },
      "mk-index-usage/t/samples/slow044-report.txt"),
   'A simple query that does not use any indexes',
);

# Capture errors, and ensure that statement blacklisting works OK
$output = output(
   sub {
      mk_index_usage::main(@args, "$trunk/common/t/samples/slow045.txt")
   },
   undef,
   stderr => 1,
);
my @errs = $output =~ m/DBD::mysql::db selectall_arrayref failed/g;
is(scalar @errs, 1, 'failing statement was blacklisted OK');

# #############################################################################
# Done.
# #############################################################################
exit;
