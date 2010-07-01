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
   plan tests => 2;
}

my $cnf     = '/tmp/12345/my.sandbox.cnf';
my $cmd     = "$trunk/mk-parallel-restore/mk-parallel-restore -F $cnf ";
my $mysql   = $sb->_use_for('master');
my $output;

# #############################################################################
# Issue 625: mk-parallel-restore throws errors for files restored by some
# versions of mysqldump
# #############################################################################
$output = `$cmd --create-databases $trunk/mk-parallel-restore/t/samples/issue_625`;

like(
   $output,
   qr/0\s+failures,/,
   'Restore older mysqldump, no failure (issue 625)'
);
is_deeply(
   $dbh->selectall_arrayref('select * from issue_625.t'),
   [[1],[2],[3]],
   'Restore older mysqldump, data restored (issue 625)'
);


# #############################################################################
# Done.
# #############################################################################
$sb->wipe_clean($dbh);
exit;
