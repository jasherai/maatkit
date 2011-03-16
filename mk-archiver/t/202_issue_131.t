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
   plan tests => 1;
}

my $output;
my $rows;
my $cnf = "/tmp/12345/my.sandbox.cnf";

$sb->create_dbs($dbh, ['test']);

# #############################################################################
# Issue 131: mk-archiver fails to insert records if destination table columns
# in different order than source table
# #############################################################################
$sb->load_file('master', 'mk-archiver/t/samples/issue_131.sql');
$output = output(
   sub { mk_archiver::main(qw(--where 1=1), "--source", "F=$cnf,D=test,t=issue_131_src", qw(--statistics --dest t=issue_131_dst)) },
);
$rows = $dbh->selectall_arrayref('SELECT * FROM test.issue_131_dst');
is_deeply(
   $rows,
   [
      ['aaa','1'],
      ['bbb','2'],
   ],
   'Dest table has different column order (issue 131)'
);

# #############################################################################
# Done.
# #############################################################################
$sb->wipe_clean($dbh);
exit;
