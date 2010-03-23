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
use DSNParser;
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

$sb->create_dbs($dbh, ['test']);

# #############################################################################
# Issue 360: mk-query-digest first_seen and last_seen not automatically
# populated
# #############################################################################
$dbh->do('DROP TABLE IF EXISTS test.query_review');
`$trunk/mk-query-digest/mk-query-digest --processlist h=127.1,P=12345,u=msandbox,p=msandbox --interval 0.01 --create-review-table --review h=127.1,P=12345,u=msandbox,p=msandbox,D=test,t=query_review --daemonize --log /tmp/mk-query-digest.log --pid /tmp/mk-query-digest.pid --run-time 2`;

# Load any file that is slow enough to be caught by mqd --processlist.
`/tmp/12345/use < $trunk/mk-archiver/t/samples/table5.sql`;
`/tmp/12345/use -e 'select sleep(2)'`;

`rm -rf /tmp/mk-query-digest.log`;
my @ts = $dbh->selectrow_array('SELECT first_seen, last_seen FROM test.query_review LIMIT 1');
ok(
   $ts[0] && $ts[0] ne '0000-00-00 00:00:00',
   'first_seen from --processlist is not 0000-00-00 00:00:00'
);
ok(
   $ts[0] && $ts[1] ne '0000-00-00 00:00:00',
   'last_seen from --processlist is not 0000-00-00 00:00:00'
);

# #############################################################################
# Done.
# #############################################################################
$sb->wipe_clean($dbh);
exit;
