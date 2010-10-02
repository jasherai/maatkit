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
# See http://code.google.com/p/maatkit/wiki/Testing
shift @INC;  # MaatkitTest's unshift
require "$trunk/mk-index-usage/mk-index-usage";

use Sandbox;
my $dp  = new DSNParser(opts=>$dsn_opts);
my $sb  = new Sandbox(basedir => '/tmp', DSNParser => $dp);
my $dbh = $sb->get_dbh_for('master');

if ( !$dbh ) {
   plan skip_all => 'Cannot connect to sandbox master';
}
if ( !@{ $dbh->selectall_arrayref('show databases like "sakila"') } ) {
   plan skip_all => "Sakila database is not loaded";
}
else {
   plan tests => 2;
}

my $cnf     = '/tmp/12345/my.sandbox.cnf';
my @args    = ('-F', $cnf, '--save-results-database', 'D=mk');
my $samples = "mk-index-usage/t/samples/";
my $output;

$sb->wipe_clean($dbh);

mk_index_usage::main(@args, "$trunk/common/t/samples/empty",
   "--create-save-results-database", "--no-report");

my $rows = $dbh->selectcol_arrayref("show databases");
my $ok   = grep { $_ eq "mk" } @$rows;
ok(
   $ok,
   "--create-save-results-databse"
);

$rows = $dbh->selectcol_arrayref("show tables from `mk`");
is_deeply(
   $rows,
   [qw(index_alternatives index_usage indexes queries tables)],
   "Create tables"
);

# #############################################################################
# Done.
# #############################################################################
$sb->wipe_clean($dbh);
exit;
