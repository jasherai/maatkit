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

my $output;
my $dp = new DSNParser(opts=>$dsn_opts);
my $sb = new Sandbox(basedir => '/tmp', DSNParser => $dp);
my $master_dbh = $sb->get_dbh_for('master');
my $slave_dbh  = $sb->get_dbh_for('slave1');

if ( !$master_dbh ) {
   plan skip_all => 'Cannot connect to sandbox master';
}
elsif ( !$slave_dbh ) {
   plan skip_all => 'Cannot connect to sandbox slave';
}
else {
   plan tests => 17;
}

$sb->wipe_clean($master_dbh);
$sb->wipe_clean($slave_dbh);
$sb->create_dbs($master_dbh, [qw(test)]);

sub query_slave {
   return $slave_dbh->selectall_arrayref(@_, {Slice => {}});
}

sub run {
   my ($src, $dst, $other) = @_;
   my $output;
   my $cmd = "$trunk/mk-table-sync/mk-table-sync --print --execute h=127.1,P=12345,u=msandbox,p=msandbox,D=test,t=$src h=127.1,P=12346,D=test,t=$dst $other 2>&1";
   chomp($output=`$cmd`);
   return $output;
}

# #############################################################################
# Test basic master-slave syncing
# #############################################################################
$sb->load_file('master', 'mk-table-sync/t/samples/before.sql');
$output = run('test1', 'test2', '');
like($output, qr/Can't make changes/, 'It dislikes changing a slave');

$output = run('test1', 'test2', '--no-bin-log');
is($output, "INSERT INTO `test`.`test2`(`a`, `b`) VALUES ('1', 'en');
INSERT INTO `test`.`test2`(`a`, `b`) VALUES ('2', 'ca');", 'No alg sync');
is_deeply(
   query_slave('select * from test.test2'),
   [ {   a => 1, b => 'en' }, { a => 2, b => 'ca' } ],
   'Synced OK with no alg'
);

$sb->load_file('master', 'mk-table-sync/t/samples/before.sql');
$output = run('test1', 'test2', '--algorithms Stream --no-bin-log');
is($output, "INSERT INTO `test`.`test2`(`a`, `b`) VALUES ('1', 'en');
INSERT INTO `test`.`test2`(`a`, `b`) VALUES ('2', 'ca');", 'Basic Stream sync');
is_deeply(
   query_slave('select * from test.test2'),
   [ {   a => 1, b => 'en' }, { a => 2, b => 'ca' } ],
   'Synced OK with Stream'
);

$sb->load_file('master', 'mk-table-sync/t/samples/before.sql');
$output = run('test1', 'test2', '--algorithms GroupBy --no-bin-log');
is($output, "INSERT INTO `test`.`test2`(`a`, `b`) VALUES ('1', 'en');
INSERT INTO `test`.`test2`(`a`, `b`) VALUES ('2', 'ca');", 'Basic GroupBy sync');
is_deeply(
   query_slave('select * from test.test2'),
   [ {   a => 1, b => 'en' }, { a => 2, b => 'ca' } ],
   'Synced OK with GroupBy'
);

$sb->load_file('master', 'mk-table-sync/t/samples/before.sql');
$output = run('test1', 'test2', '--algorithms Chunk,GroupBy --no-bin-log');
is($output, "INSERT INTO `test`.`test2`(`a`, `b`) VALUES ('1', 'en');
INSERT INTO `test`.`test2`(`a`, `b`) VALUES ('2', 'ca');", 'Basic Chunk sync');
is_deeply(
   query_slave('select * from test.test2'),
   [ {   a => 1, b => 'en' }, { a => 2, b => 'ca' } ],
   'Synced OK with Chunk'
);

$sb->load_file('master', 'mk-table-sync/t/samples/before.sql');
$output = run('test1', 'test2', '--algorithms Nibble --no-bin-log');
is($output, "INSERT INTO `test`.`test2`(`a`, `b`) VALUES ('1', 'en');
INSERT INTO `test`.`test2`(`a`, `b`) VALUES ('2', 'ca');", 'Basic Nibble sync');
is_deeply(
   query_slave('select * from test.test2'),
   [ {   a => 1, b => 'en' }, { a => 2, b => 'ca' } ],
   'Synced OK with Nibble'
);

# Save original MKDEBUG env because we modify it below.
my $dbg = $ENV{MKDEBUG};

$sb->load_file('master', 'mk-table-sync/t/samples/before.sql');
$ENV{MKDEBUG} = 1;
$output = run('test1', 'test2', '--algorithms Nibble --no-bin-log --chunk-size 1 --transaction --lock 1');
delete $ENV{MKDEBUG};
like(
   $output,
   qr/Executing statement on source/,
   'Nibble with transactions and locking'
);
is_deeply(
   query_slave('select * from test.test2'),
   [ {   a => 1, b => 'en' }, { a => 2, b => 'ca' } ],
   'Synced OK with Nibble'
);

# Sync tables that have values with leading zeroes
$ENV{MKDEBUG} = 1;
$output = run('test3', 'test4', '--print --no-bin-log --verbose --function MD5');
delete $ENV{MKDEBUG};
like(
   $output,
   qr/UPDATE `test`.`test4`.*51707/,
   'Found the first row',
);
like(
   $output,
   qr/UPDATE `test`.`test4`.*'001'/,
   'Found the second row',
);
like(
   $output,
   qr/2 Chunk\s+2\s+test.test3/,
   'Right number of rows to update',
);

# Sync a table with Nibble and a chunksize in data size, not number of rows
$output = run('test3', 'test4', '--algorithms Nibble --chunk-size 1k --print --verbose --function MD5');
# If it lived, it's OK.
ok($output, 'Synced with Nibble and data-size chunksize');

# Restore MKDEBUG env.
$ENV{MKDEBUG} = $dbg || 0;


# #############################################################################
# Done.
# #############################################################################
$sb->wipe_clean($master_dbh);
$sb->wipe_clean($slave_dbh);
exit;
