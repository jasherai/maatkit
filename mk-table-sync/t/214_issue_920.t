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
require "$trunk/mk-table-sync/mk-table-sync";

my $dp = new DSNParser(opts=>$dsn_opts);
my $sb = new Sandbox(basedir => '/tmp', DSNParser => $dp);
my $dbh = $sb->get_dbh_for('master');

plan skip_all => 'Pending solution';

if ( !$dbh ) {
   plan skip_all => 'Cannot connect to sandbox master';
}
else {
   plan tests => 3;
}

# #############################################################################
# Issue 920: mk-table-sync fails silently with non-primary UNIQUE KEY
# conflict when using Chunk or Nibble.
# #############################################################################
$sb->wipe_clean($dbh);
$sb->load_file('master', 'mk-table-sync/t/samples/issue_920.sql');

mk_table_sync::main(qw(--execute -F /tmp/12345/my.sandbox.cnf),
   'D=issue_920,t=PK_UK_test', 'D=issue_920,t=PK_UK_test_2');

is_deeply(
   $dbh->selectall_arrayref('select * from issue_920.PK_UK_test_2 order by id'),
   [[1,200],[2,100]],
   'Synced 2nd table'
);

$dbh->do('update issue_920.PK_UK_test set id2 = 2 WHERE id = 2');
$dbh->do('update issue_920.PK_UK_test set id2 = 100 WHERE id = 1');
$dbh->do('update issue_920.PK_UK_test set id2 = 200 WHERE id = 2');

is_deeply(
   $dbh->selectall_arrayref('select * from issue_920.PK_UK_test order by id'),
   [[1,100],[2,200]],
   'Flipped 1st table'
);

mk_table_sync::main(qw(--execute -F /tmp/12345/my.sandbox.cnf),
   'D=issue_920,t=PK_UK_test', 'D=issue_920,t=PK_UK_test_2');


is_deeply(
   $dbh->selectall_arrayref('select * from issue_920.PK_UK_test_2 order by id'),
   [[1,100],[2,200]],
   'Flipped 2nd table'
);

# #############################################################################
# Done.
# #############################################################################
$sb->wipe_clean($dbh);
exit;
