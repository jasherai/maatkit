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
shift @INC;
shift @INC;
shift @INC;
require "$trunk/mk-query-digest/mk-query-digest";

use Data::Dumper;
$Data::Dumper::Indent    = 1;
$Data::Dumper::Sortkeys  = 1;
$Data::Dumper::Quotekeys = 0;

my $dp = new DSNParser(opts=>$dsn_opts);
my $sb = new Sandbox(basedir => '/tmp', DSNParser => $dp);
my $dbh = $sb->get_dbh_for('master');

if ( !$dbh ) {
   plan skip_all => 'Cannot connect to sandbox master';
}
else {
   plan tests => 3;
}

my @args = qw(-F /tmp/12345/my.sandbox.cnf --processlist h=127.1 --report-format query_report);

system("/tmp/12345/use -e 'select sleep(3)' >/dev/null 2>&1 &");
system("/tmp/12345/use -e 'select sleep(4)' >/dev/null 2>&1 &");
system("/tmp/12345/use -e 'select sleep(5)' >/dev/null 2>&1 &");

sleep 1;

my $rows = $dbh->selectall_arrayref("show processlist");
my $exec = grep { ($_->[6] || '') eq 'executing' } @$rows;
is(
   $exec,
   3,
   "Three queries are executing"
) or print Dumper($rows);

my $output = output(
   sub { mk_query_digest::main(@args, qw(--run-time 5)); },
);


# #############################################################################
# Done.
# #############################################################################
$sb->wipe_clean($dbh);
exit;
