#!/usr/bin/perl

use strict;
use warnings FATAL => 'all';
use English qw(-no_match_vars);
use Test::More tests => 14;

require '../mk-duplicate-key-checker';
require '../../common/Sandbox.pm';

my $dp = new DSNParser();
my $sb = new Sandbox(basedir => '/tmp', DSNParser => $dp);
my $dbh = $sb->get_dbh_for('master')
   or BAIL_OUT('Cannot connect to sandbox master');

my $cnf = '/tmp/12345/my.sandbox.cnf'; # TODO: use $sb
my $cmd = "perl ../mk-duplicate-key-checker -F $cnf";


# Returns true (1) if there's no difference between the
# cmd's output and the expected output.
sub no_diff {
   my ( $cmd, $expected_output ) = @_;
   `$cmd > /tmp/mk-output.txt`;
   # Uncomment this line to update the $expected_output files when there is a
   # fix.
   # `cat /tmp/mk-output.txt > $expected_output`;
   my $retval = system("diff /tmp/mk-output.txt $expected_output");
   `rm -rf /tmp/mk-output.txt`;
   $retval = $retval >> 8; 
   return !$retval;
}

my $output = `$cmd -d mysql -t columns_priv -v`;
like($output,
   qr/PRIMARY \(`Host`,`Db`,`User`,`Table_name`,`Column_name`\)/,
   'Finds mysql.columns_priv PK'
);

$sb->wipe_clean($dbh);
is(`$cmd -d test --nosummary`, '', 'No dupes on clean sandbox');

$sb->create_dbs($dbh, ['test']);
$sb->load_file('master', 'common/t/samples/dupe_key.sql', 'test');

ok(
   no_diff("$cmd -d test", 'samples/basic_output.txt'),
   'Default output'
);

ok(
   no_diff("$cmd -d test --nosql", 'samples/nosql_output.txt'),
   '--nosql'
);

ok(
   no_diff("$cmd -d test --nosummary", 'samples/nosummary_output.txt'),
   '--nosummary'
);

$sb->load_file('master', 'common/t/samples/uppercase_names.sql', 'test');

ok(
   no_diff("$cmd -d test -t UPPER_TEST", 'samples/uppercase_names.txt'),
   'Issue 306 crash on uppercase column names'
);

$sb->load_file('master', 'common/t/samples/issue_269-1.sql', 'test');

ok(
   no_diff("$cmd -d test -t a", 'samples/issue_269.txt'),
   'No dupes for issue 269'
);

$sb->wipe_clean($dbh);

ok(
   no_diff("$cmd -d test", 'samples/nonexistent_db.txt'),
   'No results for nonexistent db'
);

# #############################################################################
# Issue 298: mk-duplicate-key-checker crashes
# #############################################################################
$output = `$cmd -d mysql -t columns_priv 2>&1`;
unlike($output, qr/Use of uninitialized var/, 'Does not crash on undef var');

# #############################################################################
# Issue 331: mk-duplicate-key-checker crashes getting size of foreign keys
# #############################################################################
$sb->create_dbs($dbh, ['test']);
$sb->load_file('master', 'mk-duplicate-key-checker/t/samples/issue_331.sql', 'test');
ok(
   no_diff("$cmd -d issue_331", 'samples/issue_331.txt'),
   'Issue 331 crash on fks'
);

# #############################################################################
# Issue 295: Enhance rules for clustered keys in mk-duplicate-key-checker
# #############################################################################
$sb->load_file('master', 'mk-duplicate-key-checker/t/samples/issue_295.sql', 'test');
ok(
   no_diff("$cmd -d issue_295", 'samples/issue_295.txt'),
   "Shorten, not remove, clustered dupes"
);

# #########################################################################
# Issue 391: Add --pid option to all scripts
# #########################################################################
`touch /tmp/mk-script.pid`;
$output = `$cmd -d issue_295 --pid /tmp/mk-script.pid 2>&1`;
like(
   $output,
   qr{PID file /tmp/mk-script.pid already exists},
   'Dies if PID file already exists (issue 391)'
);
`rm -rf /tmp/mk-script.pid`;

# #############################################################################
# Issue 663: Index length prefix gives uninitialized value
# #############################################################################
`/tmp/12345/use < samples/issue_663.sql`;
$output = `$cmd -d issue_663`;
like(
   $output,
   qr/`xmlerror` text/,
   'Prints dupe key with prefixed column (issue 663)'
);

# #############################################################################
# Done.
# #############################################################################
$output = '';
{
   local *STDERR;
   open STDERR, '>', \$output;
   mk_duplicate_key_checker::_d('Complete test coverage');
}
like(
   $output,
   qr/Complete test coverage/,
   '_d() works'
);
$sb->wipe_clean($dbh);
exit;
