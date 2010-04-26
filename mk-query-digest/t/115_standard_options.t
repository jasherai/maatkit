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

my $output;

# #############################################################################
# Issue 248: Add --user, --pass, --host, etc to all tools
# #############################################################################

# This is a poor test because sometimes it will catch queries on the proclist
# and other times it won't.
$output = `$trunk/mk-query-digest/mk-query-digest --processlist 127.1,P=12345,u=msandbox,p=msandbox --run-time 1 --port 12345`;
like(
   $output,
   qr/(?:Rank\s+Query ID|No events processed)/,
   'DSN opts inherit from --host, --port, etc. (issue 248)'
);

# #############################################################################
# Done.
# #############################################################################
$sb->wipe_clean($dbh);
exit;
