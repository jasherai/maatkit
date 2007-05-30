#!/usr/bin/perl

use strict;
use warnings FATAL => 'all';

use Test::More tests => 18;

my $opt_file = shift or die "Specify an option file.\n";
diag("Testing with $opt_file");

my $output;

# Make sure load works.
`mysql --defaults-file=$opt_file < before.sql`;
$output = `mysql --defaults-file=$opt_file -N -e "select count(*) from test.table_1"`;
is($output + 0, 4, 'Test data loaded ok');

# Test basic functionality with defaults
$output = `perl ../mysql-archiver --source D=test,t=table_1,F=$opt_file --purge 2>&1`;
is($output, '', 'No output');
$output = `mysql --defaults-file=$opt_file -N -e "select count(*) from test.table_1"`;
is($output + 0, 0, 'Purged ok');

# Test an empty table
$output = `perl ../mysql-archiver --source D=test,t=table_1,F=$opt_file --purge 2>&1`;
is($output, "", 'Empty table OK');

# Test ascending index (it should ascend the primary key, but there is
# no way to really know; I just want to make sure it doesn't die)
`mysql --defaults-file=$opt_file < before.sql`;
$output = `perl ../mysql-archiver --source D=test,t=table_3,F=$opt_file --purge 2>&1`;
is($output, '', 'No output');
$output = `mysql --defaults-file=$opt_file -N -e "select count(*) from test.table_3"`;
is($output + 0, 0, 'Ascended key OK');

# Test ascending index explicitly
`mysql --defaults-file=$opt_file < before.sql`;
$output = `perl ../mysql-archiver --source D=test,t=table_3,F=$opt_file,i=PRIMARY --purge 2>&1`;
is($output, '', 'No output');
$output = `mysql --defaults-file=$opt_file -N -e "select count(*) from test.table_3"`;
is($output + 0, 0, 'Ascended explicit key OK');

# Archive only part of the table
`mysql --defaults-file=$opt_file < before.sql`;
$output = `perl ../mysql-archiver --source D=test,t=table_1,F=$opt_file --where 'a<4' --purge 2>&1`;
is($output, '', 'No output');
$output = `mysql --defaults-file=$opt_file -N -e "select count(*) from test.table_1"`;
is($output + 0, 1, 'Purged some rows ok');

# Archive to a file.
`mysql --defaults-file=$opt_file < before.sql`;
`rm -f archive.test.table_1`;
$output = `perl ../mysql-archiver --source D=test,t=table_1,F=$opt_file --file 'archive.%D.%t' 2>&1`;
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
$output = `perl ../mysql-archiver --source D=test,t=table_1,F=$opt_file --dest t=table_2 2>&1`;
is($output, '', 'No output');
$output = `mysql --defaults-file=$opt_file -N -e "select count(*) from test.table_1"`;
is($output + 0, 0, 'Purged all rows ok');
$output = `mysql --defaults-file=$opt_file -N -e "select count(*) from test.table_2"`;
is($output + 0, 4, 'Found rows in new table OK');

# Test the output
`mysql --defaults-file=$opt_file < before.sql`;
$output = `perl ../mysql-archiver --source D=test,t=table_1,F=$opt_file --purge --progress 2 2>&1 | awk '{print \$3}'`;
is($output, <<EOF
COUNT
0
2
4
4
EOF
,'Progress output looks okay');
