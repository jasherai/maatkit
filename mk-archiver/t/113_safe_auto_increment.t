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
   plan tests => 4;
}

my $output;
my $rows;
my $cnf = "/tmp/12345/my.sandbox.cnf";
my $cmd = "$trunk/mk-archiver/mk-archiver";

$sb->create_dbs($dbh, ['test']);

# Safe auto-increment behavior.
$sb->load_file('master', 'mk-archiver/t/samples/table12.sql');
$output = output(
   sub { mk_archiver::main(qw(--purge --where 1=1), "--source", "D=test,t=table_12,F=$cnf") },
);
is($output, '', 'Purge worked OK');
$output = `mysql --defaults-file=$cnf -N -e "select min(a),count(*) from test.table_12"`;
like($output, qr/^3\t1$/, 'Did not touch the max auto_increment');

# Safe auto-increment behavior, disabled.
$sb->load_file('master', 'mk-archiver/t/samples/table12.sql');
$output = output(
   sub { mk_archiver::main(qw(--no-safe-auto-increment --purge --where 1=1), "--source", "D=test,t=table_12,F=$cnf") },
);
is($output, '', 'Disabled safeautoinc worked OK');
$output = `mysql --defaults-file=$cnf -N -e "select count(*) from test.table_12"`;
is($output + 0, 0, "Disabled safeautoinc purged whole table");

# #############################################################################
# Done.
# #############################################################################
$sb->wipe_clean($dbh);
exit;
