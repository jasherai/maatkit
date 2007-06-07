#!/usr/bin/perl

use strict;
use warnings FATAL => 'all';

use Test::More tests => 52;

my $opt_file = shift or die "Specify an option file.\n";
diag("Testing with $opt_file");

my $output;

# Make sure load works.
`mysql --defaults-file=$opt_file < before.sql`;
$output = `mysql --defaults-file=$opt_file -N -e "select count(*) from test.table_1"`;
is($output + 0, 4, 'Test data loaded ok');

# Test --forupdate
$output = `perl ../mysql-archiver -W 1=1 -t --source D=test,t=table_1,F=$opt_file --forupdate --purge 2>&1`;
like($output, qr/SELECT .*? FOR UPDATE/, 'forupdate works');

# Test --sharelock
$output = `perl ../mysql-archiver -W 1=1 -t --source D=test,t=table_1,F=$opt_file --sharelock --purge 2>&1`;
like($output, qr/SELECT .*? LOCK IN SHARE MODE/, 'sharelock works');

# Test --quickdel
$output = `perl ../mysql-archiver -W 1=1 -t --source D=test,t=table_1,F=$opt_file --quickdel --purge 2>&1`;
like($output, qr/DELETE QUICK/, 'quickdel works');

# Test --lpdel
$output = `perl ../mysql-archiver -W 1=1 -t --source D=test,t=table_1,F=$opt_file --lpdel --purge 2>&1`;
like($output, qr/DELETE LOW_PRIORITY/, 'lpdel works');

# Test --lpins
$output = `perl ../mysql-archiver -W 1=1 -t -d t=table_2 --source D=test,t=table_1,F=$opt_file --lpins 2>&1`;
like($output, qr/INSERT LOW_PRIORITY/, 'lpins works');

# Test --delayedins
$output = `perl ../mysql-archiver -W 1=1 -t -d t=table_2 --source D=test,t=table_1,F=$opt_file --delayedins 2>&1`;
like($output, qr/INSERT DELAYED/, 'delayedins works');

# Test --replace
$output = `perl ../mysql-archiver -W 1=1 -t -d t=table_2 --source D=test,t=table_1,F=$opt_file --replace 2>&1`;
like($output, qr/REPLACE/, 'replace works');

# Test --hpselect
$output = `perl ../mysql-archiver -W 1=1 --hpselect -t -d t=table_2 --source D=test,t=table_1,F=$opt_file --replace 2>&1`;
like($output, qr/SELECT HIGH_PRIORITY/, 'hpselect works');

# Test basic functionality with defaults
$output = `perl ../mysql-archiver -W 1=1 --source D=test,t=table_1,F=$opt_file --purge 2>&1`;
is($output, '', 'Basic test run did not die');
$output = `mysql --defaults-file=$opt_file -N -e "select count(*) from test.table_1"`;
is($output + 0, 0, 'Purged ok');

# Test basic functionality with --commit-each
`mysql --defaults-file=$opt_file < before.sql`;
$output = `perl ../mysql-archiver -W 1=1 --source D=test,t=table_1,F=$opt_file --commit-each --limit 1 --purge 2>&1`;
is($output, '', 'Commit-each did not die');
$output = `mysql --defaults-file=$opt_file -N -e "select count(*) from test.table_1"`;
is($output + 0, 0, 'Purged ok with --commit-each');

# Test basic functionality with OPTIMIZE
`mysql --defaults-file=$opt_file < before.sql`;
$output = `perl ../mysql-archiver -W 1=1 -O ds --source D=test,t=table_1,F=$opt_file --purge 2>&1`;
is($output, '', 'OPTIMIZE did not fail');

# Test an empty table
`mysql --defaults-file=$opt_file < before.sql`;
$output = `mysql --defaults-file=$opt_file -N -e "delete from test.table_1"`;
$output = `perl ../mysql-archiver -W 1=1 --source D=test,t=table_1,F=$opt_file --purge 2>&1`;
is($output, "", 'Empty table OK');

# Test with a sentinel file
`mysql --defaults-file=$opt_file < before.sql`;
`touch sentinel`;
$output = `perl ../mysql-archiver -W 1=1 -q --sentinel sentinel --source D=test,t=table_1,F=$opt_file --purge 2>&1`;
like($output, qr/because sentinel/, 'Exits because of sentinel');
$output = `mysql --defaults-file=$opt_file -N -e "select count(*) from test.table_1"`;
is($output + 0, 4, 'No rows were deleted');
`rm sentinel`;

# Test --stop, which sets the sentinel
$output = `perl ../mysql-archiver --sentinel sentinel --stop`;
like($output, qr/Successfully created file sentinel/, 'Created the sentinel OK');
`rm sentinel`;

# Test ascending index; it should ascend the primary key
`mysql --defaults-file=$opt_file < before.sql`;
$output = `perl ../mysql-archiver -t -W 1=1 --source D=test,t=table_3,F=$opt_file --purge 2>&1`;
like($output, qr/FORCE INDEX\(`PRIMARY`\)/, 'Uses PRIMARY index');
$output = `perl ../mysql-archiver -W 1=1 --source D=test,t=table_3,F=$opt_file --purge 2>&1`;
is($output, '', 'Does not die with ascending index');
$output = `mysql --defaults-file=$opt_file -N -e "select count(*) from test.table_3"`;
is($output + 0, 0, 'Ascended key OK');

# Test specifying a wrong index.
`mysql --defaults-file=$opt_file < before.sql`;
$output = `perl ../mysql-archiver -W 1=1 --source i=foo,D=test,t=table_3,F=$opt_file --purge 2>&1`;
is($output, "The specified index could not be found, or there is no PRIMARY key.\n", 'Got bad-index error OK');

# Test specifying a NULLable index.
`mysql --defaults-file=$opt_file < before.sql`;
$output = `perl ../mysql-archiver -W 1=1 --source i=b,D=test,t=table_1,F=$opt_file --purge 2>&1`;
is($output, "Some columns in index `b` allow NULL.\n", 'Got NULL-index error');

# Test table without a primary key
`mysql --defaults-file=$opt_file < before.sql`;
$output = `perl ../mysql-archiver -W 1=1 --source D=test,t=table_4,F=$opt_file --purge 2>&1`;
is($output, "The source table does not have a primary key.  Cannot continue.\n", 'Got need-PK-error OK');

# Test ascending index explicitly
`mysql --defaults-file=$opt_file < before.sql`;
$output = `perl ../mysql-archiver -W 1=1 --source D=test,t=table_3,F=$opt_file,i=PRIMARY --purge 2>&1`;
is($output, '', 'No output');
$output = `mysql --defaults-file=$opt_file -N -e "select count(*) from test.table_3"`;
is($output + 0, 0, 'Ascended explicit key OK');

# Archive only part of the table
`mysql --defaults-file=$opt_file < before.sql`;
$output = `perl ../mysql-archiver -W 1=1 --source D=test,t=table_1,F=$opt_file --where 'a<4' --purge 2>&1`;
is($output, '', 'No output');
$output = `mysql --defaults-file=$opt_file -N -e "select count(*) from test.table_1"`;
is($output + 0, 1, 'Purged some rows ok');

# Archive to a file.
`mysql --defaults-file=$opt_file < before.sql`;
`rm -f archive.test.table_1`;
$output = `perl ../mysql-archiver -W 1=1 --source D=test,t=table_1,F=$opt_file --file 'archive.%D.%t' 2>&1`;
is($output, '', 'No output');
$output = `mysql --defaults-file=$opt_file -N -e "select count(*) from test.table_1"`;
is($output + 0, 0, 'Purged all rows ok');
ok(-f 'archive.test.table_1', 'Archive file written OK');
$output = `cat archive.test.table_1`;
is($output, <<EOF
1\t2\t3\t4
2\t\\N\t3\t4
3\t2\t3\t\\\t
4\t2\t3\t\\

EOF
, 'File has the right stuff');
`rm -f archive.test.table_1`;

# Archive to another table.
`mysql --defaults-file=$opt_file < before.sql`;
$output = `perl ../mysql-archiver -W 1=1 --source D=test,t=table_1,F=$opt_file --dest t=table_2 2>&1`;
is($output, '', 'No output');
$output = `mysql --defaults-file=$opt_file -N -e "select count(*) from test.table_1"`;
is($output + 0, 0, 'Purged all rows ok');
$output = `mysql --defaults-file=$opt_file -N -e "select count(*) from test.table_2"`;
is($output + 0, 4, 'Found rows in new table OK');

# Test the output
`mysql --defaults-file=$opt_file < before.sql`;
$output = `perl ../mysql-archiver -W 1=1 --source D=test,t=table_1,F=$opt_file --purge --progress 2 2>&1 | awk '{print \$3}'`;
is($output, <<EOF
COUNT
0
2
4
4
EOF
,'Progress output looks okay');

# Archive to another table with autocommit
`mysql --defaults-file=$opt_file < before.sql`;
$output = `perl ../mysql-archiver -W 1=1 -z 0 --source D=test,t=table_1,F=$opt_file --dest t=table_2 2>&1`;
is($output, '', 'Commit every 0 rows worked OK');
$output = `mysql --defaults-file=$opt_file -N -e "select count(*) from test.table_1"`;
is($output + 0, 0, 'Purged all rows ok');
$output = `mysql --defaults-file=$opt_file -N -e "select count(*) from test.table_2"`;
is($output + 0, 4, 'Found rows in new table OK');

# Archive to another table with commit every 2 rows
`mysql --defaults-file=$opt_file < before.sql`;
$output = `perl ../mysql-archiver -W 1=1 -z 2 --source D=test,t=table_1,F=$opt_file --dest t=table_2 2>&1`;
is($output, '', 'Commit every 2 rows worked OK');
$output = `mysql --defaults-file=$opt_file -N -e "select count(*) from test.table_1"`;
is($output + 0, 0, 'Purged all rows ok');
$output = `mysql --defaults-file=$opt_file -N -e "select count(*) from test.table_2"`;
is($output + 0, 4, 'Found rows in new table OK');

# Test --columns
$output = `perl ../mysql-archiver -W 1=1 -t --source D=test,t=table_1,F=$opt_file --columns=a,b --purge 2>&1`;
like($output, qr/SELECT (?:SQL_NO_CACHE)? `a`,`b` FROM/, 'Only got specified columns');

# Test --pkonly
$output = `perl ../mysql-archiver -W 1=1 -t --source D=test,t=table_1,F=$opt_file --pkonly --purge 2>&1`;
like($output, qr/SELECT (?:SQL_NO_CACHE)? `a` FROM/, '--pkonly works');

# Test that tables must have same columns
$output = `perl ../mysql-archiver -W 1=1 -t --dest t=table_4 --source D=test,t=table_1,F=$opt_file --purge 2>&1`;
like($output, qr/The following columns exist in --source /, 'Column check throws error');
$output = `perl ../mysql-archiver -W 1=1 -t --nochkcols --dest t=table_4 --source D=test,t=table_1,F=$opt_file --purge 2>&1`;
like($output, qr/SELECT/, 'I can disable the check OK');

# Test that ascending index check WHERE clause can't be hijacked
$output = `perl ../mysql-archiver -s D=test,t=table_6,F=$opt_file -p -l 2 -W 'c=1'`;
is($output, '', 'No errors purging table_6');
$output = `mysql --defaults-file=$opt_file -N -e "select count(*) from test.table_6"`;
is($output + 0, 1, 'Did not purge last row');

# Test that ascending index check doesn't leave any holes
$output = `perl ../mysql-archiver -s D=test,t=table_5,F=$opt_file -p -l 50 -W 'a<current_date - interval 1 day' 2>&1`;
is($output, '', 'No errors in larger table');
$output = `mysql --defaults-file=$opt_file -N -e "select count(*) from test.table_5"`;
is($output + 0, 0, 'Purged completely');

# Make sure ascending index check can be disabled
$output = `perl ../mysql-archiver -W 1=1 -t --noascend -s D=test,t=table_5,F=$opt_file -p -l 50 2>&1`;
like ( $output, qr/(^SELECT .*$)\n\1/m, '--noascend makes fetch-first and fetch-next identical' );

# Check ascending only first column
$output = `perl ../mysql-archiver -W 1=1 -t --ascendfirst -s D=test,t=table_5,F=$opt_file -p -l 50 2>&1`;
like ( $output, qr/WHERE \(1=1\) AND \(`a` >= \?\) LIMIT/, 'Can ascend just first column');
