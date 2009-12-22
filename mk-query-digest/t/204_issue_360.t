#!/usr/bin/env perl

use strict;
use warnings FATAL => 'all';
use English qw(-no_match_vars);
use Test::More;

require '../../common/DSNParser.pm';
require '../../common/Sandbox.pm';
my $dp = new DSNParser();
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
`../mk-query-digest --processlist h=127.1,P=12345,u=msandbox,p=msandbox --interval 0.01 --create-review-table --review h=127.1,P=12345,u=msandbox,p=msandbox,D=test,t=query_review --daemonize --log /tmp/mk-query-digest.log --pid /tmp/mk-query-digest.pid --run-time 2`;
`/tmp/12345/use < ../../mk-archiver/t/before.sql`;
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
