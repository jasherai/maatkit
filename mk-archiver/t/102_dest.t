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
require "$trunk/mk-archiver/mk-archiver";

my $dp  = new DSNParser(opts=>$dsn_opts);
my $sb  = new Sandbox(basedir => '/tmp', DSNParser => $dp);
my $dbh = $sb->get_dbh_for('master');

if ( !$dbh ) {
   plan skip_all => 'Cannot connect to sandbox master';
}
else {
   plan tests => 13;
}

my $output;
my $rows;
my $cnf = "/tmp/12345/my.sandbox.cnf";
my $cmd = "$trunk/mk-archiver/mk-archiver";

# Make sure load works.
$sb->create_dbs($dbh, ['test']);
$sb->load_file('master', 'mk-archiver/t/samples/tables1-4.sql');

# Archive to another table.
$output = output(
   sub { mk_archiver::main(qw(--where 1=1), "--source", "D=test,t=table_1,F=$cnf", qw(--dest t=table_2)) },
);
is($output, '', 'No output for archiving to another table');
$output = `mysql --defaults-file=$cnf -N -e "select count(*) from test.table_1"`;
is($output + 0, 0, 'Purged all rows ok');
$output = `mysql --defaults-file=$cnf -N -e "select count(*) from test.table_2"`;
is($output + 0, 4, 'Found rows in new table OK when archiving to another table');

# Archive only some columns to another table.
$sb->load_file('master', 'mk-archiver/t/samples/tables1-4.sql');
$output = output(
   sub { mk_archiver::main("-c", "b,c", qw(--where 1=1), "--source", "D=test,t=table_1,F=$cnf", qw(--dest t=table_2)) },
);
is($output, '', 'No output for archiving only some cols to another table');
$rows = $dbh->selectall_arrayref("select * from test.table_1");
ok(scalar @$rows == 0, 'Purged all rows ok');
# This test has been changed. I manually examined the tables before
# and after the archive operation and I am convinced that the original
# expected output was incorrect.
$rows = $dbh->selectall_arrayref("select * from test.table_2", { Slice => {}});
is_deeply(
   $rows,
   [  {  a => '1', b => '2',   c => '3', d => undef },
      {  a => '2', b => undef, c => '3', d => undef },
      {  a => '3', b => '2',   c => '3', d => undef },
      {  a => '4', b => '2',   c => '3', d => undef },
   ],
   'Found rows in new table OK when archiving only some columns to another table');


# Archive to another table with autocommit
$sb->load_file('master', 'mk-archiver/t/samples/tables1-4.sql');
$output = output(
   sub { mk_archiver::main(qw(--where 1=1 --txn-size 0), "--source", "D=test,t=table_1,F=$cnf", qw(--dest t=table_2)) },
);
is($output, '', 'Commit every 0 rows worked OK');
$output = `mysql --defaults-file=$cnf -N -e "select count(*) from test.table_1"`;
is($output + 0, 0, 'Purged all rows ok');
$output = `mysql --defaults-file=$cnf -N -e "select count(*) from test.table_2"`;
is($output + 0, 4, 'Found rows in new table OK when archiving to another table with autocommit');

# Archive to another table with commit every 2 rows
$sb->load_file('master', 'mk-archiver/t/samples/tables1-4.sql');
$output = output(
   sub { mk_archiver::main(qw(--where 1=1 --txn-size 2), "--source", "D=test,t=table_1,F=$cnf", qw(--dest t=table_2)) },
);
is($output, '', 'Commit every 2 rows worked OK');
$output = `mysql --defaults-file=$cnf -N -e "select count(*) from test.table_1"`;
is($output + 0, 0, 'Purged all rows ok');
$output = `mysql --defaults-file=$cnf -N -e "select count(*) from test.table_2"`;
is($output + 0, 4, 'Found rows in new table OK when archiving to another table with commit every 2 rows');

# Test that table with many rows can be archived to table with few
$sb->load_file('master', 'mk-archiver/t/samples/tables1-4.sql');
$output = output(
   sub { mk_archiver::main(qw(--where 1=1 --dest t=table_4 --no-check-columns), "--source", "D=test,t=table_1,F=$cnf") },
);
$output = `mysql --defaults-file=$cnf -N -e "select sum(a) from test.table_4"`;
is($output + 0, 10, 'Rows got archived');

# #############################################################################
# Done.
# #############################################################################
$sb->wipe_clean($dbh);
exit;
