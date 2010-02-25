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

use Sandbox;
use MaatkitTest;
use VersionParser;
# See 101_slowlog_analyses.t for why we shift.
shift @INC;  # our unshift (above)
shift @INC;  # MaatkitTest's unshift
shift @INC;  # Sandbox

require "$trunk/mk-query-digest/mk-query-digest";

my $dp  = new DSNParser();
my $vp  = new VersionParser();
my $sb  = new Sandbox(basedir => '/tmp', DSNParser => $dp);
my $dbh = $sb->get_dbh_for('master');

if ( !$dbh ) {
   plan skip_all => 'Cannot connect to sandbox master';
}
else {
   plan tests => 5;
}

my $output = '';
my $cnf    = 'h=127.1,P=12345,u=msandbox,p=msandbox';
my @args   = qw(--report-format=query_report --limit 10 --stat);

$sb->create_dbs($dbh, [qw(test)]);
$dbh->do('use test');
$dbh->do('create table foo (a int, b int, c int)');

is_deeply(
   $dbh->selectall_arrayref('select * from test.foo'),
   [],
   'No rows in table yet'
);

ok(
   no_diff(
      sub { mk_query_digest::main(@args, '--execute', $cnf,
         "$trunk/common/t/samples/slow018.txt") },
      'mk-query-digest/t/samples/slow018_execute_report_1.txt'
   ),
   '--execute without database'
);

is_deeply(
   $dbh->selectall_arrayref('select * from test.foo'),
   [],
   'Still no rows in table'
);

# Provide a default db to make --execute work.
$cnf .= ',D=test';

# We tail -n 18 to get everything from "Exec orig" onward.  The lines
# above have the real execution time will will vary.  The last 18 lines
# are sufficient to see that it actually executed without errors.
ok(
   no_diff(
      sub { mk_query_digest::main(@args, '--execute', $cnf,
         "$trunk/common/t/samples/slow018.txt") },
      'mk-query-digest/t/samples/slow018_execute_report_2.txt',
      trf => 'tail -n 18',
   ),
   '--execute with default database'
);

is_deeply(
   $dbh->selectall_arrayref('select * from test.foo'),
   [[qw(1 2 3)],[qw(4 5 6)]],
   'Rows in table'
);

# #############################################################################
# Done.
# #############################################################################
$sb->wipe_clean($dbh);
exit;
