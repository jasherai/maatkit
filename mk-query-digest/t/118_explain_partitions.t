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
use DSNParser;
use VersionParser;
use Sandbox;

my $dp = new DSNParser(opts=>$dsn_opts);
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
diag(`/tmp/12345/use < $trunk/mk-query-digest/t/samples/issue_611.sql`);

my $output = `$trunk/mk-query-digest/mk-query-digest $trunk/mk-query-digest/t/samples/slow-issue-611.txt --explain h=127.1,P=12345,u=msandbox,p=msandbox 2>&1`;
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
