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
require "$trunk/mk-parallel-restore/mk-parallel-restore";

my $dp = new DSNParser(opts=>$dsn_opts);
my $sb = new Sandbox(basedir => '/tmp', DSNParser => $dp);
my $dbh = $sb->get_dbh_for('master');

if ( !$dbh ) {
   plan skip_all => 'Cannot connect to sandbox master';
}
else {
   plan tests => 8;
}

my $cnf     = '/tmp/12345/my.sandbox.cnf';
my $cmd     = "$trunk/mk-parallel-restore/mk-parallel-restore -F $cnf ";
my $mysql   = $sb->_use_for('master');
my $basedir = '/tmp/dump/';
my $output;

$sb->create_dbs($dbh, ['test']);
diag(`rm -rf $basedir`);

$output = `$cmd $trunk/mk-parallel-restore/t/mk_parallel_restore_foo --dry-run`;
like(
   $output,
   qr/CREATE TABLE bar\(a int\)/,
   'Found the file',
);
like(
   $output,
   qr{1 tables,\s+1 files,\s+1 successes},
   'Counted the work to be done',
);

$output = `$cmd --ignore-tables bar $trunk/mk-parallel-restore/t/mk_parallel_restore_foo --dry-run`;
unlike( $output, qr/bar/, '--ignore-tables filtered out bar');

$output = `$cmd --ignore-tables mk_parallel_restore_foo.bar $trunk/mk-parallel-restore/t/mk_parallel_restore_foo --dry-run`;
unlike( $output, qr/bar/, '--ignore-tables filtered out bar again');

# Actually load the file, and make sure it succeeds.
`$mysql -e 'DROP DATABASE IF EXISTS mk_parallel_restore_foo'`;
`$mysql -e 'DROP DATABASE IF EXISTS mk_parallel_restore_bar'`;
$output = `$cmd --create-databases $trunk/mk-parallel-restore/t/mk_parallel_restore_foo`;
$output = `$mysql -N -e 'select count(*) from mk_parallel_restore_foo.bar'`;
is($output + 0, 0, 'Loaded mk_parallel_restore_foo.bar');

# Test that the --database parameter doesn't specify the database to use for the
# connection, and that --create-databases creates the database for it (bug #1870415).
`$mysql -e 'DROP DATABASE IF EXISTS mk_parallel_restore_foo'`;
`$mysql -e 'DROP DATABASE IF EXISTS mk_parallel_restore_bar'`;
$output = `$cmd --database mk_parallel_restore_bar --create-databases $trunk/mk-parallel-restore/t/mk_parallel_restore_foo`;
$output = `$mysql -N -e 'select count(*) from mk_parallel_restore_bar.bar'`;
is($output + 0, 0, 'Loaded mk_parallel_restore_bar.bar');

# Test that the --defaults-file parameter works (bug #1886866).
# This is implicit in that $cmd specifies --defaults-file
$output = `$cmd --create-databases $trunk/mk-parallel-restore/t/mk_parallel_restore_foo`;
like($output, qr/1 files,     1 successes,  0 failures/, 'restored');
$output = `$mysql -N -e 'select count(*) from mk_parallel_restore_bar.bar'`;
is($output + 0, 0, 'Loaded mk_parallel_restore_bar.bar');

# #############################################################################
# Done.
# #############################################################################
$sb->wipe_clean($dbh);
exit;
