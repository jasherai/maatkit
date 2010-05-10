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
use DSNParser;

my $dp = new DSNParser(opts=>$dsn_opts);
my $sb = new Sandbox(basedir => '/tmp', DSNParser => $dp);
my $dbh = $sb->get_dbh_for('master');

if ( !$dbh ) {
   plan skip_all => 'Cannot connect to sandbox master';
}
else {
   plan tests => 1;
}

my $run_with = "$trunk/mk-index-usage/mk-index-usage --host localhost";
my $output;
my $cmd;

ok(
   no_diff(
      $run_with . " $trunk/common/t/samples/slow044.txt",
      "mk-index-usage/t/samples/slow044-report.txt"),
   'A simple query that does not use any indexes',
);

# #############################################################################
# Done.
# #############################################################################
exit;
