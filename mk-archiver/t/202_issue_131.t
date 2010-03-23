#!/usr/bin/env perl

BEGIN {
   die "The MAATKIT_TRUNK environment variable is not set.  See http://code.google.com/p/maatkit/wiki/Testing"
      unless $ENV{MAATKIT_TRUNK} && -d $ENV{MAATKIT_TRUNK};
   unshift @INC, "$ENV{MAATKIT_TRUNK}/common";
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
my $cmd = "$trunk/mk-archiver/mk-archiver";

$sb->create_dbs($dbh, ['test']);

# #############################################################################
# Issue 131: mk-archiver fails to insert records if destination table columns
# in different order than source table
# #############################################################################
$sb->load_file('master', 'mk-archiver/t/samples/issue_131.sql');
$output = `$cmd --where 1=1 --source F=$cnf,D=test,t=issue_131_src --statistics --dest t=issue_131_dst 2>&1`;
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
