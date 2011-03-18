#!/usr/bin/env perl
# test 'x'
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

# #############################################################################
# Issue 1152: mk-archiver columns option resulting in null archived table data
# #############################################################################

$sb->load_file('master', 'mk-archiver/t/samples/issue_1225.sql');
$dbh->do('set names "utf8"');
my $original_rows = $dbh->selectall_arrayref('select * from issue_1225.t where i in (1, 2)');
is_deeply(
   $original_rows,
   [  [ 1, 'が'],  # Your terminal must be UTF8 to see this Japanese character.
      [ 2, 'が'],
   ],
   "Inserted UTF8 data"
);

throws_ok(
   sub { mk_archiver::main(
      '--source',  'h=127.1,P=12345,D=issue_1225,t=t,u=msandbox,p=msandbox',
      '--dest',    't=a',
      qw(--where 1=1 --purge))
   },
   qr/Character set mismatch/,
   "--check-charset"
);

$output = output(
   sub { mk_archiver::main(
      '--source',  'h=127.1,P=12345,D=issue_1225,t=t,u=msandbox,p=msandbox',
      '--dest',    't=a',
      qw(--no-check-charset --where 1=1 --purge))
   },
);

my $archived_rows = $dbh->selectall_arrayref('select * from issue_1225.a where i in (1, 2)');

ok(
   $original_rows->[0]->[1] ne $archived_rows->[0]->[1],
   "UTF8 characters lost when cxn isn't also UTF8"
);

$sb->load_file('master', 'mk-archiver/t/samples/issue_1225.sql');

$output = output(
   sub { mk_archiver::main(
      '--source',  'h=127.1,P=12345,D=issue_1225,t=t,u=msandbox,p=msandbox',
      '--dest',    't=a',
      qw(--where 1=1 --purge -A utf8)) # -A utf8 makes it work
   },
);

$archived_rows = $dbh->selectall_arrayref('select * from issue_1225.a where i in (1, 2)');

is_deeply(
   $original_rows,
   $archived_rows,
   "UTF8 characters preserved when cxn is also UTF8"
);

# #############################################################################
# Done.
# #############################################################################
$sb->wipe_clean($dbh);
exit;
