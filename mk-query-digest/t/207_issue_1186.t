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
use DSNParser;

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
# Issue 1186: mk-query-digest --processlist --interval --filter ignores interval
# #############################################################################

my $output = `MKDEBUG=1 $trunk/mk-query-digest/mk-query-digest --processlist h=127.1,P=12345,u=msandbox,p=msandbox --run-time 2 --port 12345 --interval .5 2>&1`;

my @times = $output =~ m/Current time: \S+/g;
ok(
   @times > 4 && @times <= 7,
   "--interval limits number of processlist polls (issue 1186)"
);

$output = `MKDEBUG=1 $trunk/mk-query-digest/mk-query-digest --processlist h=127.1,P=12345,u=msandbox,p=msandbox --run-time 2 --port 12345 --interval .5 --filter '(\$event->{arg} =~ /NEVER HAPPEN/)' 2>&1`;

@times = $output =~ m/Current time: \S+/g;
ok(
   @times > 4 && @times <= 7,
   "--filter doesn't bypass --interval (issue 1186)"
);

# #############################################################################
# Done.
# #############################################################################
exit;
