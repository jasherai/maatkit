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
require "$trunk/mk-archiver/mk-archiver";

my $dp   = new DSNParser(opts=>$dsn_opts);
my $sb   = new Sandbox(basedir => '/tmp', DSNParser => $dp);
my $dbh  = $sb->get_dbh_for('master');
my $dbh2 = $sb->get_dbh_for('slave1');

if ( !$dbh ) {
   plan skip_all => 'Cannot connect to sandbox master';
}
else {
   plan tests => 6;
}

my $output;
my $cnf = "/tmp/12345/my.sandbox.cnf";
my $cmd = "$trunk/mk-archiver/mk-archiver";

$sb->create_dbs($dbh, [qw(test)]);

SKIP: {
   skip 'Sandbox master does not have the sakila database', 1
      unless @{$dbh->selectcol_arrayref('SHOW DATABASES LIKE "sakila"')};

   $output = `$cmd --source F=$cnf,h=127.1,D=sakila,t=film  --where "film_id < 100" --purge --dry-run --port 12345 | diff $trunk/mk-archiver/t/samples/issue-248.txt -`;
   is(
      $output,
      '',
      'DSNs inherit from standard connection options (issue 248)'
   );
};


# Test with a sentinel file
$sb->load_file('master', 'mk-archiver/t/samples/table1.sql');
diag(`touch sentinel`);
$output = `$cmd --where 1=1 --why-quit --sentinel sentinel --source D=test,t=table_1,F=$cnf --purge 2>&1`;
like($output, qr/because sentinel/, 'Exits because of sentinel');
$output = `mysql --defaults-file=$cnf -N -e "select count(*) from test.table_1"`;
is($output + 0, 4, 'No rows were deleted');
`rm sentinel`;

# Test --stop, which sets the sentinel
$output = `$cmd --sentinel sentinel --stop`;
like($output, qr/Successfully created file sentinel/, 'Created the sentinel OK');
diag(`rm -f sentinel >/dev/null`);

# #############################################################################
# Issue 391: Add --pid option to mk-table-sync
# #############################################################################
`touch /tmp/mk-archiver.pid`;
$output = `$cmd --where 1=1 --source F=$cnf,D=test,t=issue_131_src --statistics --dest t=issue_131_dst --pid /tmp/mk-archiver.pid 2>&1`;
like(
   $output,
   qr{PID file /tmp/mk-archiver.pid already exists},
   'Dies if PID file already exists (issue 391)'
);

`rm -rf /tmp/mk-archiver.pid`;

# #############################################################################
# Issue 460: mk-archiver does not inherit DSN as documented 
# #############################################################################
SKIP: {
   skip 'Cannot connect to sandbox slave1', 1 unless $dbh2;

   # This test will achive rows from dbh:test.table_1 to dbh2:test.table_2.
   $sb->load_file('master', 'mk-archiver/t/samples/tables1-4.sql');

   # Change passwords so defaults files won't work.
   $dbh->do('SET PASSWORD FOR msandbox = PASSWORD("foo")');
   $dbh2->do('SET PASSWORD FOR msandbox = PASSWORD("foo")');

   $dbh2->do('TRUNCATE TABLE test.table_2');

   $output = `MKDEBUG=1 $trunk/mk-archiver/mk-archiver --where 1=1 --source h=127.1,P=12345,D=test,t=table_1,u=msandbox,p=foo --dest P=12346,t=table_2 --statistics 2>&1`;
   my $r = $dbh2->selectall_arrayref('SELECT * FROM test.table_2');
   is(
      scalar @$r,
      4,
      '--dest inherited from --source'
   );

   # Set the passwords back.  If this fails we should bail out because
   # nothing else is going to work.
   eval {
      $dbh->do("SET PASSWORD FOR msandbox = PASSWORD('msandbox')");
      $dbh2->do("SET PASSWORD FOR msandbox = PASSWORD('msandbox')");
   };
   if ( $EVAL_ERROR ) {
      BAIL_OUT('Failed to reset the msandbox password on the master or slave '
         . 'sandbox.  Check the Maatkit test environment with "mk-test-env '
         . 'status" and restart with "mk-test-env restart".  The error was: '
         . $EVAL_ERROR);
   }

};

# #############################################################################
# Done.
# #############################################################################
$sb->wipe_clean($dbh);
$sb->wipe_clean($dbh2) if $dbh2;
exit;
