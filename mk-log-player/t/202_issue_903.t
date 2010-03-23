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
require "$trunk/mk-log-player/mk-log-player";

my $dp = new DSNParser(opts=>$dsn_opts);
my $sb = new Sandbox(basedir => '/tmp', DSNParser => $dp);
my $dbh = $sb->get_dbh_for('master');

if ( !$dbh ) {
   plan skip_all => 'Cannot connect to sandbox master';
}
else {
   plan tests => 2;
}

# #############################################################################
# Issue 903: mk-log-player --only-select does not handle comments
# #############################################################################

# This should not cause an error because the leading comment
# prevents the query from looking like a SELECT.
my $output;
$output = `$trunk/mk-log-player/mk-log-player --threads 1 --play $trunk/mk-log-player/t/samples/issue_903.txt h=127.1,P=12345,u=msandbox,p=msandbox,D=mysql 2>&1`;
like(
   $output,
   qr/caused an error/,
   'Error without --only-select'
);

# This will cause an error now, too, because the leading comment
# is stripped.
$output = `$trunk/mk-log-player/mk-log-player --threads 1 --play $trunk/mk-log-player/t/samples/issue_903.txt h=127.1,P=12345,u=msandbox,p=msandbox,D=mysql --only-select 2>&1`;
like(
   $output,
   qr/caused an error/,
   'Error with --only-select'
);

# #############################################################################
# Done.
# #############################################################################
diag(`rm -rf ./session-results-*`);
exit;
