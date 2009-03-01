#!/usr/bin/perl

use strict;
use warnings FATAL => 'all';

use English qw('-no_match_vars);
use Test::More tests => 7;

require '../../common/DSNParser.pm';
require '../../common/Sandbox.pm';
my $dp = new DSNParser();
my $sb = new Sandbox(basedir => '/tmp', DSNParser => $dp);
my $dbh = $sb->get_dbh_for('master')
   or BAIL_OUT('Cannot connect to sandbox master');

my $cnf = '/tmp/12345/my.sandbox.cnf';
my $cmd = "perl ../mk-duplicate-key-checker -F $cnf";

my $output = `$cmd -d mysql -t columns_priv -v`;
like($output,
   qr/PRIMARY \(`Host`,`Db`,`User`,`Table_name`,`Column_name`\)/,
   'Finds mysql.columns_priv PK'
);

$sb->wipe_clean($dbh);
is(`$cmd -d test --nosummary`, '', 'No dupes on clean sandbox');

$sb->create_dbs($dbh, ['test']);
$sb->load_file('master', '../../common/t/samples/dupe_key.sql', 'test');

$output = `$cmd -d test | diff samples/basic_output.txt -`;
is($output, '', 'Default output');

$output = `$cmd -d test --nosql | diff samples/nosql_output.txt -`;
is($output, '', '--nosql');

$output = `$cmd -d test --nosummary | diff samples/nosummary_output.txt -`;
is($output, '', '--nosummary');


$sb->load_file('master', '../../common/t/samples/issue_269-1.sql', 'test');
$output = `$cmd -d test -t a | diff samples/issue_269.txt -`;
is($output, '', 'No dupes for issue 269');

# Test for issue 298.
$output = `$cmd -d mysql -t columns_priv 2>&1`;
unlike($output, qr/Use of uninitialized var/, 'Does not crash on undef var');

$sb->wipe_clean($dbh);
exit;
