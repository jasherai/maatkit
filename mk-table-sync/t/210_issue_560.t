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
   plan tests => 2;
}

$sb->wipe_clean($master_dbh);
$sb->wipe_clean($slave_dbh);
$sb->create_dbs($master_dbh, [qw(test)]);

# #############################################################################
# Issue 560: mk-table-sync generates impossible WHERE
# #############################################################################
diag(`/tmp/12345/use < $trunk/mk-table-sync/t/samples/issue_560.sql`);
sleep 1;

# Make slave differ.
$slave_dbh->do('UPDATE issue_560.buddy_list SET buddy_id=0 WHERE player_id IN (333,334)');
$slave_dbh->do('UPDATE issue_560.buddy_list SET buddy_id=0 WHERE player_id=486');

diag(`$trunk/mk-table-checksum/mk-table-checksum --replicate issue_560.checksum h=127.1,P=12345,u=msandbox,p=msandbox  -d issue_560 --chunk-size 50 > /dev/null`);
sleep 1;
$output = `$trunk/mk-table-checksum/mk-table-checksum --replicate issue_560.checksum h=127.1,P=12345,u=msandbox,p=msandbox  -d issue_560 --replicate-check 1 --chunk-size 50`;
is(
   $output,
"Differences on P=12346,h=127.0.0.1
DB        TBL        CHUNK CNT_DIFF CRC_DIFF BOUNDARIES
issue_560 buddy_list     6        0        1 `player_id` >= '301' AND `player_id` < '351'
issue_560 buddy_list     9        0        1 `player_id` >= '451'

",
   'Found checksum differences (issue 560)'
);

$output = `$trunk/mk-table-sync/mk-table-sync --sync-to-master h=127.1,P=12346,u=msandbox,p=msandbox -d issue_560 --print -v -v  --chunk-size 50 --replicate issue_560.checksum`;
is(
   $output,
"# Syncing via replication P=12346,h=127.1,p=...,u=msandbox
# DELETE REPLACE INSERT UPDATE ALGORITHM EXIT DATABASE.TABLE
# SELECT /*issue_560.buddy_list:1/1*/ 0 AS chunk_num, COUNT(*) AS cnt, COALESCE(LOWER(CONV(BIT_XOR(CAST(CRC32(CONCAT_WS('#', `player_id`, `buddy_id`)) AS UNSIGNED)), 10, 16)), 0) AS crc FROM `issue_560`.`buddy_list` FORCE INDEX (`PRIMARY`) WHERE (((`player_id` < '350') OR (`player_id` = '350' AND `buddy_id` <= '2454'))) AND ((`player_id` >= '301' AND `player_id` < '351')) FOR UPDATE
# SELECT /*issue_560.buddy_list:1/1*/ 0 AS chunk_num, COUNT(*) AS cnt, COALESCE(LOWER(CONV(BIT_XOR(CAST(CRC32(CONCAT_WS('#', `player_id`, `buddy_id`)) AS UNSIGNED)), 10, 16)), 0) AS crc FROM `issue_560`.`buddy_list` FORCE INDEX (`PRIMARY`) WHERE (((`player_id` < '350') OR (`player_id` = '350' AND `buddy_id` <= '2454'))) AND ((`player_id` >= '301' AND `player_id` < '351')) LOCK IN SHARE MODE
# SELECT /*rows in nibble*/ `player_id`, `buddy_id`, CRC32(CONCAT_WS('#', `player_id`, `buddy_id`)) AS __crc FROM `issue_560`.`buddy_list` FORCE INDEX (`PRIMARY`) WHERE (((`player_id` < '350') OR (`player_id` = '350' AND `buddy_id` <= '2454'))) AND (`player_id` >= '301' AND `player_id` < '351') ORDER BY `player_id`, `buddy_id` FOR UPDATE
# SELECT /*rows in nibble*/ `player_id`, `buddy_id`, CRC32(CONCAT_WS('#', `player_id`, `buddy_id`)) AS __crc FROM `issue_560`.`buddy_list` FORCE INDEX (`PRIMARY`) WHERE (((`player_id` < '350') OR (`player_id` = '350' AND `buddy_id` <= '2454'))) AND (`player_id` >= '301' AND `player_id` < '351') ORDER BY `player_id`, `buddy_id` LOCK IN SHARE MODE
DELETE FROM `issue_560`.`buddy_list` WHERE `player_id`='333' AND `buddy_id`='0' LIMIT 1;
DELETE FROM `issue_560`.`buddy_list` WHERE `player_id`='334' AND `buddy_id`='0' LIMIT 1;
REPLACE INTO `issue_560`.`buddy_list`(`player_id`, `buddy_id`) VALUES ('333', '3414');
REPLACE INTO `issue_560`.`buddy_list`(`player_id`, `buddy_id`) VALUES ('334', '6626');
# SELECT /*issue_560.buddy_list:1/1*/ 0 AS chunk_num, COUNT(*) AS cnt, COALESCE(LOWER(CONV(BIT_XOR(CAST(CRC32(CONCAT_WS('#', `player_id`, `buddy_id`)) AS UNSIGNED)), 10, 16)), 0) AS crc FROM `issue_560`.`buddy_list` FORCE INDEX (`PRIMARY`) WHERE ((((`player_id` > '350') OR (`player_id` = '350' AND `buddy_id` > '2454')) AND 1=1)) AND ((`player_id` >= '301' AND `player_id` < '351')) FOR UPDATE
# SELECT /*issue_560.buddy_list:1/1*/ 0 AS chunk_num, COUNT(*) AS cnt, COALESCE(LOWER(CONV(BIT_XOR(CAST(CRC32(CONCAT_WS('#', `player_id`, `buddy_id`)) AS UNSIGNED)), 10, 16)), 0) AS crc FROM `issue_560`.`buddy_list` FORCE INDEX (`PRIMARY`) WHERE ((((`player_id` > '350') OR (`player_id` = '350' AND `buddy_id` > '2454')) AND 1=1)) AND ((`player_id` >= '301' AND `player_id` < '351')) LOCK IN SHARE MODE
#      2       2      0      0 Nibble    2    issue_560.buddy_list
# SELECT /*issue_560.buddy_list:1/1*/ 0 AS chunk_num, COUNT(*) AS cnt, COALESCE(LOWER(CONV(BIT_XOR(CAST(CRC32(CONCAT_WS('#', `player_id`, `buddy_id`)) AS UNSIGNED)), 10, 16)), 0) AS crc FROM `issue_560`.`buddy_list` FORCE INDEX (`PRIMARY`) WHERE (((`player_id` < '500') OR (`player_id` = '500' AND `buddy_id` <= '4272'))) AND ((`player_id` >= '451')) FOR UPDATE
# SELECT /*issue_560.buddy_list:1/1*/ 0 AS chunk_num, COUNT(*) AS cnt, COALESCE(LOWER(CONV(BIT_XOR(CAST(CRC32(CONCAT_WS('#', `player_id`, `buddy_id`)) AS UNSIGNED)), 10, 16)), 0) AS crc FROM `issue_560`.`buddy_list` FORCE INDEX (`PRIMARY`) WHERE (((`player_id` < '500') OR (`player_id` = '500' AND `buddy_id` <= '4272'))) AND ((`player_id` >= '451')) LOCK IN SHARE MODE
# SELECT /*rows in nibble*/ `player_id`, `buddy_id`, CRC32(CONCAT_WS('#', `player_id`, `buddy_id`)) AS __crc FROM `issue_560`.`buddy_list` FORCE INDEX (`PRIMARY`) WHERE (((`player_id` < '500') OR (`player_id` = '500' AND `buddy_id` <= '4272'))) AND (`player_id` >= '451') ORDER BY `player_id`, `buddy_id` FOR UPDATE
# SELECT /*rows in nibble*/ `player_id`, `buddy_id`, CRC32(CONCAT_WS('#', `player_id`, `buddy_id`)) AS __crc FROM `issue_560`.`buddy_list` FORCE INDEX (`PRIMARY`) WHERE (((`player_id` < '500') OR (`player_id` = '500' AND `buddy_id` <= '4272'))) AND (`player_id` >= '451') ORDER BY `player_id`, `buddy_id` LOCK IN SHARE MODE
DELETE FROM `issue_560`.`buddy_list` WHERE `player_id`='486' AND `buddy_id`='0' LIMIT 1;
REPLACE INTO `issue_560`.`buddy_list`(`player_id`, `buddy_id`) VALUES ('486', '1660');
# SELECT /*issue_560.buddy_list:1/1*/ 0 AS chunk_num, COUNT(*) AS cnt, COALESCE(LOWER(CONV(BIT_XOR(CAST(CRC32(CONCAT_WS('#', `player_id`, `buddy_id`)) AS UNSIGNED)), 10, 16)), 0) AS crc FROM `issue_560`.`buddy_list` FORCE INDEX (`PRIMARY`) WHERE ((((`player_id` > '500') OR (`player_id` = '500' AND `buddy_id` > '4272')) AND 1=1)) AND ((`player_id` >= '451')) FOR UPDATE
# SELECT /*issue_560.buddy_list:1/1*/ 0 AS chunk_num, COUNT(*) AS cnt, COALESCE(LOWER(CONV(BIT_XOR(CAST(CRC32(CONCAT_WS('#', `player_id`, `buddy_id`)) AS UNSIGNED)), 10, 16)), 0) AS crc FROM `issue_560`.`buddy_list` FORCE INDEX (`PRIMARY`) WHERE ((((`player_id` > '500') OR (`player_id` = '500' AND `buddy_id` > '4272')) AND 1=1)) AND ((`player_id` >= '451')) LOCK IN SHARE MODE
#      1       1      0      0 Nibble    2    issue_560.buddy_list
",
   'Sync only --replicate chunks'
);

# #############################################################################
# Done.
# #############################################################################
$sb->wipe_clean($master_dbh);
$sb->wipe_clean($slave_dbh);
exit;
