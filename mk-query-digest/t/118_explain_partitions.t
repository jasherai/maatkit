#!/usr/bin/env perl

use strict;
use warnings FATAL => 'all';
use English qw(-no_match_vars);
use Test::More;

require '../../common/DSNParser.pm';
require '../../common/VersionParser.pm';
require '../../common/Sandbox.pm';
my $dp = new DSNParser();
my $vp = new VersionParser();
my $sb = new Sandbox(basedir => '/tmp', DSNParser => $dp);
my $dbh = $sb->get_dbh_for('master');

if ( !$dbh ) {
   plan skip_all => 'Cannot connect to sandbox master';
}
elsif ( !$vp->version_ge($dbh, '5.1.0') ) {
   plan skip_all => 'Sandbox master version not >= 5.1';
}
else {
   plan tests => 1;
}

# #############################################################################
# Issue 611: EXPLAIN PARTITIONS in mk-query-digest if partitions are used
# #############################################################################
diag(`/tmp/12345/use < samples/issue_611.sql`);

my $output = `../mk-query-digest samples/slow-issue-611.txt --explain h=127.1,P=12345,u=msandbox,p=msandbox 2>&1`;
like(
   $output,
   qr/partitions: p\d/,
   'EXPLAIN /*!50100 PARTITIONS */ (issue 611)'
);

# #############################################################################
# Done.
# #############################################################################
$sb->wipe_clean($dbh);
exit;
