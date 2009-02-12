#!/usr/bin/perl

use strict;
use warnings FATAL => 'all';

use English qw('-no_match_vars);
use Test::More tests => 5;

require '../../common/DSNParser.pm';
require '../../common/Sandbox.pm';
my $dp = new DSNParser();
my $sb = new Sandbox(basedir => '/tmp', DSNParser => $dp);
my $dbh = $sb->get_dbh_for('master')
   or BAIL_OUT('Cannot connect to sandbox master');

my $cnf = '/tmp/12345/my.sandbox.cnf';
my $cmd = "perl ../mk-duplicate-key-checker -F $cnf -d test ";

my $output = `$cmd -d mysql -t columns_priv -v`;
like($output,
   qr/PRIMARY \(`Host`,`Db`,`User`,`Table_name`,`Column_name`\)/,
   'Finds mysql.columns_priv PK'
);

$sb->wipe_clean($dbh);
is(`$cmd --nosummary`, '', 'No dupes on clean sandbox');

$sb->create_dbs($dbh, ['test']);
$sb->load_file('master', '../../common/t/samples/dupe_key.sql', 'test');

$output = `$cmd | diff samples/basic_output.txt -`;
is($output, '', 'Default output');

$output = `$cmd --nosql | diff samples/nosql_output.txt -`;
is($output, '', '--nosql');

$output = `$cmd --nosummary | diff samples/nosummary_output.txt -`;
is($output, '', '--nosummary');

$sb->wipe_clean($dbh);
exit;
