#!/usr/bin/perl

use strict;
use warnings FATAL => 'all';

use Test::More tests => 85;

my $opt_file = shift || "~/.my.cnf";
diag("Testing with $opt_file");
$ENV{PERL5LIB} .= ':t/';

my $output;

# Make sure load works.
`mysql --defaults-file=$opt_file < before.sql`;
$output = `mysql --defaults-file=$opt_file -N -e "select count(*) from test.table_1"`;
is($output + 0, 4, 'Test data loaded ok');

# Test --forupdate
$output = `perl ../mk-archiver -W 1=1 -t --source D=test,t=table_1,F=$opt_file --forupdate --purge 2>&1`;
like($output, qr/SELECT .*? FOR UPDATE/, 'forupdate works');

# Test --sharelock
$output = `perl ../mk-archiver -W 1=1 -t --source D=test,t=table_1,F=$opt_file --sharelock --purge 2>&1`;
like($output, qr/SELECT .*? LOCK IN SHARE MODE/, 'sharelock works');

# Test --quickdel
$output = `perl ../mk-archiver -W 1=1 -t --source D=test,t=table_1,F=$opt_file --quickdel --purge 2>&1`;
like($output, qr/DELETE QUICK/, 'quickdel works');

# Test --lpdel
$output = `perl ../mk-archiver -W 1=1 -t --source D=test,t=table_1,F=$opt_file --lpdel --purge 2>&1`;
like($output, qr/DELETE LOW_PRIORITY/, 'lpdel works');

# Test --lpins
$output = `perl ../mk-archiver -W 1=1 -t -d t=table_2 --source D=test,t=table_1,F=$opt_file --lpins 2>&1`;
like($output, qr/INSERT LOW_PRIORITY/, 'lpins works');

# Test --delayedins
$output = `perl ../mk-archiver -W 1=1 -t -d t=table_2 --source D=test,t=table_1,F=$opt_file --delayedins 2>&1`;
like($output, qr/INSERT DELAYED/, 'delayedins works');

# Test --replace
$output = `perl ../mk-archiver -W 1=1 -t -d t=table_2 --source D=test,t=table_1,F=$opt_file --replace 2>&1`;
like($output, qr/REPLACE/, 'replace works');

# Test --hpselect
$output = `perl ../mk-archiver -W 1=1 --hpselect -t -d t=table_2 --source D=test,t=table_1,F=$opt_file --replace 2>&1`;
like($output, qr/SELECT HIGH_PRIORITY/, 'hpselect works');

# Test basic functionality with defaults
$output = `perl ../mk-archiver -W 1=1 --source D=test,t=table_1,F=$opt_file --purge 2>&1`;
is($output, '', 'Basic test run did not die');
$output = `mysql --defaults-file=$opt_file -N -e "select count(*) from test.table_1"`;
is($output + 0, 0, 'Purged ok');

# Test basic functionality with --commit-each
`mysql --defaults-file=$opt_file < before.sql`;
$output = `perl ../mk-archiver -W 1=1 --source D=test,t=table_1,F=$opt_file --commit-each --limit 1 --purge 2>&1`;
is($output, '', 'Commit-each did not die');
$output = `mysql --defaults-file=$opt_file -N -e "select count(*) from test.table_1"`;
is($output + 0, 0, 'Purged ok with --commit-each');

# Test basic functionality with OPTIMIZE
`mysql --defaults-file=$opt_file < before.sql`;
$output = `perl ../mk-archiver -W 1=1 -O ds --source D=test,t=table_1,F=$opt_file --purge 2>&1`;
is($output, '', 'OPTIMIZE did not fail');

# Test an empty table
`mysql --defaults-file=$opt_file < before.sql`;
$output = `mysql --defaults-file=$opt_file -N -e "delete from test.table_1"`;
$output = `perl ../mk-archiver -W 1=1 --source D=test,t=table_1,F=$opt_file --purge 2>&1`;
is($output, "", 'Empty table OK');

# Test with a sentinel file
`mysql --defaults-file=$opt_file < before.sql`;
`touch sentinel`;
$output = `perl ../mk-archiver -W 1=1 -q --sentinel sentinel --source D=test,t=table_1,F=$opt_file --purge 2>&1`;
like($output, qr/because sentinel/, 'Exits because of sentinel');
$output = `mysql --defaults-file=$opt_file -N -e "select count(*) from test.table_1"`;
is($output + 0, 4, 'No rows were deleted');
`rm sentinel`;

# Test --stop, which sets the sentinel
$output = `perl ../mk-archiver --sentinel sentinel --stop`;
like($output, qr/Successfully created file sentinel/, 'Created the sentinel OK');
`rm sentinel`;

# Test ascending index; it should ascend the primary key
`mysql --defaults-file=$opt_file < before.sql`;
$output = `perl ../mk-archiver -t -W 1=1 --source D=test,t=table_3,F=$opt_file --purge 2>&1`;
like($output, qr/FORCE INDEX\(`PRIMARY`\)/, 'Uses PRIMARY index');
$output = `perl ../mk-archiver -W 1=1 --source D=test,t=table_3,F=$opt_file --purge 2>&1`;
is($output, '', 'Does not die with ascending index');
$output = `mysql --defaults-file=$opt_file -N -e "select count(*) from test.table_3"`;
is($output + 0, 0, 'Ascended key OK');

# Test specifying a wrong index.
`mysql --defaults-file=$opt_file < before.sql`;
$output = `perl ../mk-archiver -W 1=1 --source i=foo,D=test,t=table_3,F=$opt_file --purge 2>&1`;
like($output, qr/Index 'foo' does not exist in table/, 'Got bad-index error OK');

# Test specifying a NULLable index.
`mysql --defaults-file=$opt_file < before.sql`;
$output = `perl ../mk-archiver -W 1=1 --source i=b,D=test,t=table_1,F=$opt_file --purge 2>&1`;
is($output, "", 'Got no error with a NULLable index');

# Test table without a primary key
`mysql --defaults-file=$opt_file < before.sql`;
$output = `perl ../mk-archiver -W 1=1 --source D=test,t=table_4,F=$opt_file --purge 2>&1`;
like($output, qr/Cannot find an ascendable index/, 'Got need-PK-error OK');

# Test ascending index explicitly
`mysql --defaults-file=$opt_file < before.sql`;
$output = `perl ../mk-archiver -W 1=1 --source D=test,t=table_3,F=$opt_file,i=PRIMARY --purge 2>&1`;
is($output, '', 'No output');
$output = `mysql --defaults-file=$opt_file -N -e "select count(*) from test.table_3"`;
is($output + 0, 0, 'Ascended explicit key OK');

# Test that mk-archiver gets column ordinals and such right when building the
# ascending-index queries.
`mysql --defaults-file=$opt_file < before.sql`;
$output = `perl ../mk-archiver -l 2 -W 1=1 --source D=test,t=table_11,F=$opt_file --purge 2>&1`;
is($output, '', 'No output while dealing with out-of-order PK');
$output = `mysql --defaults-file=$opt_file -N -e "select count(*) from test.table_11"`;
is($output + 0, 0, 'Ascended out-of-order PK OK');

# Archive only part of the table
`mysql --defaults-file=$opt_file < before.sql`;
$output = `perl ../mk-archiver -W 1=1 --source D=test,t=table_1,F=$opt_file --where 'a<4' --purge 2>&1`;
is($output, '', 'No output');
$output = `mysql --defaults-file=$opt_file -N -e "select count(*) from test.table_1"`;
is($output + 0, 1, 'Purged some rows ok');

# Archive to a file.
`mysql --defaults-file=$opt_file < before.sql`;
`rm -f archive.test.table_1`;
$output = `perl ../mk-archiver -W 1=1 --source D=test,t=table_1,F=$opt_file --file 'archive.%D.%t' 2>&1`;
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

# Archive to a file, but specify only some columns.
`mysql --defaults-file=$opt_file < before.sql`;
`rm -f archive.test.table_1`;
$output = `perl ../mk-archiver -c b,c -W 1=1 -h --source D=test,t=table_1,F=$opt_file --file 'archive.%D.%t' 2>&1`;
$output = `cat archive.test.table_1`;
is($output, <<EOF
b\tc
2\t3
\\N\t3
2\t3
2\t3
EOF
, 'File has the right stuff with only some columns');
`rm -f archive.test.table_1`;

# Archive to another table.
`mysql --defaults-file=$opt_file < before.sql`;
$output = `perl ../mk-archiver -W 1=1 --source D=test,t=table_1,F=$opt_file --dest t=table_2 2>&1`;
is($output, '', 'No output');
$output = `mysql --defaults-file=$opt_file -N -e "select count(*) from test.table_1"`;
is($output + 0, 0, 'Purged all rows ok');
$output = `mysql --defaults-file=$opt_file -N -e "select count(*) from test.table_2"`;
is($output + 0, 4, 'Found rows in new table OK');

# Archive only some columns to another table.
`mysql --defaults-file=$opt_file < before.sql`;
$output = `perl ../mk-archiver -c b,c -W 1=1 --source D=test,t=table_1,F=$opt_file --dest t=table_2 2>&1`;
is($output, '', 'No output');
$output = `mysql --defaults-file=$opt_file -N -e "select count(*) from test.table_1"`;
is($output + 0, 0, 'Purged all rows ok');
$output = `mysql --defaults-file=$opt_file -t -e "select * from test.table_2"`;
is($output, <<EOF
+---+------+---+------+
| a | b    | c | d    |
+---+------+---+------+
| 1 |    3 | 1 | NULL | 
| 2 |    3 | 2 | NULL | 
| 3 |    3 | 3 | NULL | 
| 4 |    3 | 4 | NULL | 
+---+------+---+------+
EOF
, 'Found rows in new table OK');

# Test the output
`mysql --defaults-file=$opt_file < before.sql`;
$output = `perl ../mk-archiver -W 1=1 --source D=test,t=table_1,F=$opt_file --purge --progress 2 2>&1 | awk '{print \$3}'`;
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
$output = `perl ../mk-archiver -W 1=1 -z 0 --source D=test,t=table_1,F=$opt_file --dest t=table_2 2>&1`;
is($output, '', 'Commit every 0 rows worked OK');
$output = `mysql --defaults-file=$opt_file -N -e "select count(*) from test.table_1"`;
is($output + 0, 0, 'Purged all rows ok');
$output = `mysql --defaults-file=$opt_file -N -e "select count(*) from test.table_2"`;
is($output + 0, 4, 'Found rows in new table OK');

# Archive to another table with commit every 2 rows
`mysql --defaults-file=$opt_file < before.sql`;
$output = `perl ../mk-archiver -W 1=1 -z 2 --source D=test,t=table_1,F=$opt_file --dest t=table_2 2>&1`;
is($output, '', 'Commit every 2 rows worked OK');
$output = `mysql --defaults-file=$opt_file -N -e "select count(*) from test.table_1"`;
is($output + 0, 0, 'Purged all rows ok');
$output = `mysql --defaults-file=$opt_file -N -e "select count(*) from test.table_2"`;
is($output + 0, 4, 'Found rows in new table OK');

# Test --columns
$output = `perl ../mk-archiver -W 1=1 -t --source D=test,t=table_1,F=$opt_file --columns=a,b --purge 2>&1`;
like($output, qr{SELECT /\*!40001 SQL_NO_CACHE \*/ `a`,`b` FROM}, 'Only got specified columns');

# Test --pkonly
$output = `perl ../mk-archiver -W 1=1 -t --source D=test,t=table_1,F=$opt_file --pkonly --purge 2>&1`;
like($output, qr{SELECT /\*!40001 SQL_NO_CACHE \*/ `a` FROM}, '--pkonly works');

# Test that tables must have same columns
$output = `perl ../mk-archiver -W 1=1 -t --dest t=table_4 --source D=test,t=table_1,F=$opt_file --purge 2>&1`;
like($output, qr/The following columns exist in --source /, 'Column check throws error');
$output = `perl ../mk-archiver -W 1=1 -t --nochkcols --dest t=table_4 --source D=test,t=table_1,F=$opt_file --purge 2>&1`;
like($output, qr/SELECT/, 'I can disable the check OK');

# Test that table with many rows can be archived to table with few
`mysql --defaults-file=$opt_file < before.sql`;
$output = `perl ../mk-archiver -W 1=1 --dest t=table_4 --nochkcols --source D=test,t=table_1,F=$opt_file 2>&1`;
$output = `mysql --defaults-file=$opt_file -N -e "select sum(a) from test.table_4"`;
is($output + 0, 10, 'Rows got archived');

# Test that ascending index check WHERE clause can't be hijacked
$output = `perl ../mk-archiver -s D=test,t=table_6,F=$opt_file -p -l 2 -W 'c=1'`;
is($output, '', 'No errors purging table_6');
$output = `mysql --defaults-file=$opt_file -N -e "select count(*) from test.table_6"`;
is($output + 0, 1, 'Did not purge last row');

# Test that ascending index check doesn't leave any holes
$output = `perl ../mk-archiver -s D=test,t=table_5,F=$opt_file -p -l 50 -W 'a<current_date - interval 1 day' 2>&1`;
is($output, '', 'No errors in larger table');
$output = `mysql --defaults-file=$opt_file -N -e "select count(*) from test.table_5"`;
is($output + 0, 0, 'Purged completely on multi-column ascending index');

# Make sure ascending index check can be disabled
$output = `perl ../mk-archiver -W 1=1 -t --noascend -s D=test,t=table_5,F=$opt_file -p -l 50 2>&1`;
like ( $output, qr/(^SELECT .*$)\n\1/m, '--noascend makes fetch-first and fetch-next identical' );
`mysql --defaults-file=$opt_file < before.sql`;
$output = `perl ../mk-archiver -W 1=1 --noascend -s D=test,t=table_5,F=$opt_file -p -l 1 2>&1`;
is($output, '', "No output when --noascend");

# Check ascending only first column
$output = `perl ../mk-archiver -W 1=1 -t --ascendfirst -s D=test,t=table_5,F=$opt_file -p -l 50 2>&1`;
like ( $output, qr/WHERE \(1=1\) AND \(\(`a` >= \?\)\) LIMIT/, 'Can ascend just first column');

# Check plugin that does nothing
`mysql --defaults-file=$opt_file < before.sql`;
$output = `perl ../mk-archiver -W 1=1 -s m=Plugin1,D=test,t=table_1,F=$opt_file --dest t=table_2 2>&1`;
is($output, '', 'Loading a blank plugin worked OK');
$output = `mysql --defaults-file=$opt_file -N -e "select count(*) from test.table_1"`;
is($output + 0, 4, 'Purged no rows ok b/c of blank plugin');

# Test that ascending index check doesn't leave any holes on a unique index when
# there is a plugin that always says rows are archivable
$output = `perl ../mk-archiver -s m=Plugin2,D=test,t=table_5,F=$opt_file -p -l 50 -W 'a<current_date - interval 1 day' 2>&1`;
is($output, '', 'No errors with strictly ascending index');
$output = `mysql --defaults-file=$opt_file -N -e "select count(*) from test.table_5"`;
is($output + 0, 0, 'Purged completely with strictly ascending index');

# Check plugin that adds rows to another table (same thing as --dest, but on
# same db handle)
`mysql --defaults-file=$opt_file < before.sql`;
$output = `perl ../mk-archiver -W 1=1 -s m=Plugin3,D=test,t=table_1,F=$opt_file -p 2>&1`;
is($output, '', 'Running with plugin did not die');
$output = `mysql --defaults-file=$opt_file -N -e "select count(*) from test.table_1"`;
is($output + 0, 0, 'Purged all rows ok with plugin');
$output = `mysql --defaults-file=$opt_file -N -e "select count(*) from test.table_2"`;
is($output + 0, 4, 'Plugin archived all rows to table_2 OK');

# Check plugin that does ON DUPLICATE KEY UPDATE on insert
`mysql --defaults-file=$opt_file < before.sql`;
$output = `perl ../mk-archiver -W 1=1 -s D=test,t=table_7,F=$opt_file -d m=Plugin4,t=table_8 2>&1`;
is($output, '', 'Loading plugin worked OK');
$output = `mysql --defaults-file=$opt_file -N -e "select count(*) from test.table_7"`;
is($output + 0, 0, 'Purged all rows ok with plugin');
$output = `mysql --defaults-file=$opt_file -N -e "select count(*) from test.table_8"`;
is($output + 0, 2, 'Plugin archived all rows to table_8 OK');
$output = `mysql --defaults-file=$opt_file -N -e "select count(*) from test.table_9"`;
is($output + 0, 1, 'ODKU made one row');
$output = `mysql --defaults-file=$opt_file -N -e "select a, b, c from test.table_9"`;
like($output, qr/1\s+3\s+6/, 'ODKU added rows up');

# Check plugin that sets up and archives a temp table
`mysql --defaults-file=$opt_file < before.sql`;
$output = `perl ../mk-archiver -W 1=1 -s m=Plugin5,D=test,t=tmp_table,F=$opt_file -d t=table_10 2>&1`;
is($output, '', 'Loading plugin worked OK');
$output = `mysql --defaults-file=$opt_file -N -e "select count(*) from test.table_10"`;
is($output + 0, 2, 'Plugin archived all rows to table_10 OK');

# Check plugin that sets up and archives to one or the other table depending
# on even/odd
`mysql --defaults-file=$opt_file < before.sql`;
$output = `perl ../mk-archiver -W 1=1 -s D=test,t=table_13,F=$opt_file -d m=Plugin6,t=table_10 2>&1`;
is($output, '', 'Loading plugin worked OK');
$output = `mysql --defaults-file=$opt_file -N -e "select count(*) from test.table_even"`;
is($output + 0, 1, 'Plugin archived all rows to table_even OK');
$output = `mysql --defaults-file=$opt_file -N -e "select count(*) from test.table_odd"`;
is($output + 0, 2, 'Plugin archived all rows to table_odd OK');

# Statistics
`mysql --defaults-file=$opt_file < before.sql`;
$output = `perl ../mk-archiver --statistics -W 1=1 --source D=test,t=table_1,F=$opt_file --dest t=table_2 2>&1`;
like($output, qr/commit *10/, 'Stats print OK');

# Safe auto-increment behavior.
`mysql --defaults-file=$opt_file < before.sql`;
$output = `perl ../mk-archiver --purge -W 1=1 --source D=test,t=table_12,F=$opt_file 2>&1`;
is($output, '', 'Purge worked OK');
$output = `mysql --defaults-file=$opt_file -N -e "select min(a),count(*) from test.table_12"`;
like($output, qr/^3\t1$/, 'Did not touch the max auto_increment');

# Safe auto-increment behavior, disabled.
`mysql --defaults-file=$opt_file < before.sql`;
$output = `perl ../mk-archiver --nosafeautoinc --purge -W 1=1 --source D=test,t=table_12,F=$opt_file 2>&1`;
is($output, '', 'Disabled safeautoinc worked OK');
$output = `mysql --defaults-file=$opt_file -N -e "select count(*) from test.table_12"`;
is($output + 0, 0, "Disabled safeautoinc purged whole table");

# Test --nodelete.
`mysql --defaults-file=$opt_file < before.sql`;
$output = `perl ../mk-archiver --nodelete --purge -W 1=1 --source D=test,t=table_1,F=$opt_file --test 2>&1`;
like($output, qr/> /, '--nodelete implies strict ascending');
unlike($output, qr/>=/, '--nodelete implies strict ascending');
$output = `perl ../mk-archiver --nodelete --purge -W 1=1 --source D=test,t=table_1,F=$opt_file 2>&1`;
$output = `mysql --defaults-file=$opt_file -N -e "select count(*) from test.table_1"`;
is($output + 0, 4, 'All 4 rows are still there');

# Clean up.
`mysql --defaults-file=$opt_file < after.sql`;
