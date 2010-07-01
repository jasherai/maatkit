#!/usr/bin/perl

BEGIN {
   die "The MAATKIT_WORKING_COPY environment variable is not set.  See http://code.google.com/p/maatkit/wiki/Testing"
      unless $ENV{MAATKIT_WORKING_COPY} && -d $ENV{MAATKIT_WORKING_COPY};
   unshift @INC, "$ENV{MAATKIT_WORKING_COPY}/common";
};

use strict;
use warnings FATAL => 'all';
use English qw(-no_match_vars);
use Test::More tests => 18;

use ErrorLogParser;
use MaatkitTest;

my $p = new ErrorLogParser();

my $oktorun = 1;

test_log_parser(
   parser  => $p,
   file    => 'common/t/samples/errlogs/errlog001.txt',
   oktorun => sub { $oktorun = $_[0]; },
   result  => [
      {
       arg        => 'mysqld started',
       pos_in_log => 0,
       ts         => '080721 03:03:57',
       Level      => 'unknown',
      },
      {
       Level      => 'warning',
       arg        => '[Warning] option \'log_slow_rate_limit\': unsigned value 0 adjusted to 1',
       pos_in_log => 32,
       ts         => '080721  3:04:00',
      },
      {
       Level      => 'error',
       arg        => '[ERROR] /usr/sbin/mysqld: unknown variable \'ssl-key=/opt/mysql.pdns/.cert/server-key.pem\'',
       pos_in_log => 119,
       ts         => '080721  3:04:01',
      },
      {
       arg        => 'mysqld ended',
       pos_in_log => 225,
       ts         => '080721 03:04:01',
       Level      => 'unknown',
      },
      {
       arg        => 'mysqld started',
       pos_in_log => 255,
       ts         => '080721 03:10:57',
       Level      => 'unknown',
      },
      {
       Level      => 'warning',
       arg        => '[Warning] No argument was provided to --log-bin, and --log-bin-index was not used; so replication may break when this MySQL server acts as a master and has his hostname changed!! Please use \'--log-bin=/var/run/mysqld/mysqld-bin\' to avoid this problem.',
       pos_in_log => 288,
       ts         => '080721  3:10:58',
      },
      {
       arg        => 'InnoDB: Started; log sequence number 1 3703096531',
       pos_in_log => 556,
       ts         => '080721  3:11:08',
       Level      => 'unknown',
      },
      {
       Level      => 'warning',
       arg        => '[Warning] Neither --relay-log nor --relay-log-index were used; so replication may break when this MySQL server acts as a slave and has his hostname changed!! Please use \'--relay-log=/var/run/mysqld/mysqld-relay-bin\' to avoid this problem.',
       pos_in_log => 878,
       ts         => '080721  3:11:12',
      },
      {
       Level      => 'error',
       arg        => '[ERROR] Failed to open the relay log \'./srv-relay-bin.000001\' (relay_log_pos 4)',
       pos_in_log => 878,
       ts         => '080721  3:11:12',
      },
      {
       Level      => 'error',
       arg        => '[ERROR] Could not find target log during relay log initialization',
       pos_in_log => 974,
       ts         => '080721  3:11:12',
      },
      {
       Level      => 'error',
       arg        => '[ERROR] Failed to initialize the master info structure',
       pos_in_log => 1056,
       ts         => '080721  3:11:12',
      },
      {
       Level      => 'info',
       arg        => '[Note] /usr/libexec/mysqld: ready for connections.',
       pos_in_log => 1127,
       ts         => '080721  3:11:12',
      },
      {
       arg        => 'Version: \'5.0.45-log\' socket: \'/mnt/data/mysql/mysql.sock\'  port: 3306  Source distribution',
       pos_in_log => 1194,
       Level      => 'unknown',
      },
      {
       Level      => 'info',
       arg        => '[Note] /usr/libexec/mysqld: Normal shutdown',
       pos_in_log => 1287,
       ts         => '080721  9:22:14',
      },
      {
       arg        => 'InnoDB: Starting shutdown...',
       pos_in_log => 1347,
       ts         => '080721  9:22:17',
       Level      => 'unknown',
      },
      {
       arg        => 'InnoDB: Shutdown completed; log sequence number 1 3703096531',
       pos_in_log => 1472,
       ts         => '080721  9:22:20',
       Level      => 'unknown',
      },
      {
       Level      => 'info',
       arg        => '[Note] /usr/libexec/mysqld: Shutdown complete',
       pos_in_log => 1534,
       ts         => '080721  9:22:20',
      },
      {
       arg        => 'mysqld ended',
       pos_in_log => 1534,
       ts         => '080721 09:22:22',
       Level      => 'unknown',
      },
      {
       arg        => 'mysqld started',
       pos_in_log => 1565,
       ts         => '080721 09:22:31',
      Level      => 'unknown',
      },
      {
       arg        => 'Version: \'5.0.45-log\' socket: \'/mnt/data/mysql/mysql.sock\'  port: 3306  Source distribution',
       pos_in_log => 1598,
       Level      => 'unknown',
      },
      {
       Level      => 'error',
       arg        => '[ERROR] bdb: log_archive: DB_ARCH_ABS: DB_NOTFOUND: No matching key/data pair found',
       pos_in_log => 1691,
       ts         => '080721  9:34:22',
      },
      {
       arg        => 'mysqld started',
       pos_in_log => 1792,
       ts         => '080721 09:39:09',
       Level      => 'unknown',
      },
      {
       arg        => 'InnoDB: Started; log sequence number 1 3703096531',
       pos_in_log => 1825,
       ts         => '080721  9:39:14',
       Level      => 'unknown',
      },
      {
       arg        => 'mysqld started',
       pos_in_log => 1924,
       ts         => '080821 19:14:12',
       Level      => 'unknown',
      },
      {
       pos_in_log => 1924,
       ts         => '080821 19:14:12',
       arg        => 'InnoDB: Database was not shut down normally! Starting crash recovery. Reading tablespace information from the .ibd files... Restoring possible half-written data pages from the doublewrite buffer...',
       Level      => 'unknown',
      },
      {
       pos_in_log => 2237,
       ts         => '080821 19:14:13',
       arg        => 'InnoDB: Starting log scan based on checkpoint at log sequence number 1 3703467071. Doing recovery: scanned up to log sequence number 1 3703467081 Last MySQL binlog file position 0 804759240, file name ./srv-bin.000012',
       Level      => 'unknown',
      },
      {
       arg        => 'InnoDB: Started; log sequence number 1 3703467081',
       pos_in_log => 2497,
       ts         => '080821 19:14:13',
       Level      => 'unknown',
      },
      {
       Level      => 'info',
       arg        => '[Note] Recovering after a crash using srv-bin',
       pos_in_log => 2559,
       ts         => '080821 19:14:13',
      },
      {
       Level      => 'info',
       arg        => '[Note] Starting crash recovery...',
       pos_in_log => 2559,
       ts         => '080821 19:14:23',
      },
      {
       Level      => 'info',
       arg        => '[Note] Crash recovery finished.',
       pos_in_log => 2609,
       ts         => '080821 19:14:23',
      },
      {
       arg        => 'Version: \'5.0.45-log\' socket: \'/mnt/data/mysql/mysql.sock\'  port: 3306  Source distribution',
       pos_in_log => 2657,
       Level      => 'unknown',
      },
      {
       Level      => 'info',
       arg        => '[Note] Found 5 of 0 rows when repairing \'./test/a3\'',
       pos_in_log => 2750,
       ts         => '080911 18:04:40',
      },
      {
       Level      => 'info',
       arg        => '[Note] /usr/libexec/mysqld: ready for connections.',
       pos_in_log => 2818,
       ts         => '081101  9:17:53',
      },
      {
       arg        => 'Version: \'5.0.45-log\' socket: \'/mnt/data/mysql/mysql.sock\'  port: 3306  Source distribution',
       pos_in_log => 2886,
       Level      => 'unknown',
      },
      {
       arg        => 'Number of processes running now: 0',
       pos_in_log => 2979,
       Level      => 'unknown',
      },
      {
       arg        => 'mysqld restarted',
       pos_in_log => 3015,
       ts         => '081117 16:15:07',
       Level      => 'unknown',
      },
      {
       pos_in_log => 3049,
       ts         => '081117 16:15:16',
       Level      => 'error',
       arg        => 'InnoDB: Error: cannot allocate 268451840 bytes of memory with malloc! Total allocated memory by InnoDB 8074720 bytes. Operating system errno: 12 Check if you should increase the swap file or ulimits of your operating system. On FreeBSD check you have compiled the OS with a big enough maximum process size. Note that in most 32-bit computers the process memory space is limited to 2 GB or 4 GB. We keep retrying the allocation for 60 seconds... Fatal error: cannot allocate the memory for the buffer pool',
      },
      {
       Level      => 'info',
       arg        => '[Note] /usr/libexec/mysqld: ready for connections.',
       pos_in_log => 3718,
       ts         => '081117 16:32:55',
      },
   ],
);

test_log_parser(
   parser => $p,
   file   => 'common/t/samples/errlogs/errlog003.txt',
   result => [
      {
         Level       => 'error',
         arg         => '[ERROR] /usr/sbin/mysqld: Incorrect key file for table \'./bugs_eventum/eventum_note.MYI\'; try to repair it',
         pos_in_log  => 0,
         ts          => '090902 10:43:55',
      },
      {
         Level       => 'error',
         pos_in_log  => 123,
         ts          => '090902 10:43:55',
         arg         => '[ERROR] Slave SQL: Error \'Incorrect key file for table \'./bugs_eventum/eventum_note.MYI\'; try to repair it\' on query. Default database: \'bugs_eventum\'. Query: \'DELETE FROM                    bugs_eventum.eventum_note                 WHERE                    not_iss_id IN (384, 385, 101056, 101057, 101058, 101067, 101070, 101156, 101163, 101164, 101175, 101232, 101309, 101433, 101434, 101435, 101436, 101437, 101454, 101476, 101488, 101490, 101506, 101507, 101530, 101531, 101573, 101574, 101575, 101583, 101586, 101587, 101588, 101589, 101590, 101729, 101730, 101791, 101865, 102382)\', Error_code: 126',
      },
      {
         Level       => 'warning',
         arg         => '[Warning] Slave: Incorrect key file for table \'./bugs_eventum/eventum_note.MYI\'; try to repair it Error_code: 126',
         pos_in_log  => 747,
         ts          => '090902 10:43:55'
      },
   ]
);

my $big_arg = <<'EOF';
mysqld got signal 6 ;
This could be because you hit a bug. It is also possible that this binary
or one of the libraries it was linked against is corrupt, improperly built,
or misconfigured. This error can also be caused by malfunctioning hardware.
We will try our best to scrape up some info that will hopefully help diagnose
the problem, but since we have already crashed, something is definitely wrong
and this may fail.

key_buffer_size=67108864
read_buffer_size=131072
max_used_connections=2
max_threads=128
threads_connected=2
It is possible that mysqld could use up to 
key_buffer_size + (read_buffer_size + sort_buffer_size)*max_threads = 345366 K
bytes of memory
Hope that's ok; if not, decrease some variables in the equation.

thd: 0xf95a8a0
Attempting backtrace. You can use the following information to find out
where mysqld died. If you see no messages after this, something went
terribly wrong...
stack_bottom = 0x4e3b0f20 thread_stack 0x40000
/usr/sbin/mysqld(my_print_stacktrace+0x35)[0x83bd65]
/usr/sbin/mysqld(handle_segfault+0x31d)[0x58dd4d]
/lib64/libpthread.so.0[0x2b869c7984c0]
/lib64/libc.so.6(gsignal+0x35)[0x2b869d2ad215]
/lib64/libc.so.6(abort+0x110)[0x2b869d2aecc0]
/usr/sbin/mysqld[0x741e55]
/usr/sbin/mysqld[0x742078]
/usr/sbin/mysqld[0x744b65]
/usr/sbin/mysqld[0x7300a9]
/usr/sbin/mysqld[0x728337]
/usr/sbin/mysqld[0x7d135e]
/usr/sbin/mysqld[0x7d1439]
/usr/sbin/mysqld[0x7d1b18]
/usr/sbin/mysqld[0x732e45]
/usr/sbin/mysqld[0x73690b]
/usr/sbin/mysqld[0x70b9b8]
/usr/sbin/mysqld(_ZN7handler7ha_openEP8st_tablePKcii+0x3e)[0x66a50e]
/usr/sbin/mysqld(_Z21open_table_from_shareP3THDP14st_table_sharePKcjjjP8st_tableb+0x597)[0x5e6cb7]
/usr/sbin/mysqld[0x5db6fe]
/usr/sbin/mysqld(_Z10open_tableP3THDP10TABLE_LISTP11st_mem_rootPbj+0x59c)[0x5dd0ac]
/usr/sbin/mysqld(_Z11open_tablesP3THDPP10TABLE_LISTPjj+0x4cf)[0x5dddcf]
/usr/sbin/mysqld(_Z28open_and_lock_tables_derivedP3THDP10TABLE_LISTb+0x67)[0x5de087]
/usr/sbin/mysqld[0x684cef]
/usr/sbin/mysqld(_Z17mysql_check_tableP3THDP10TABLE_LISTP15st_ha_check_opt+0x5e)[0x685cce]
/usr/sbin/mysqld(_Z21mysql_execute_commandP3THD+0x28d8)[0x59d4e8]
/usr/sbin/mysqld(_Z11mysql_parseP3THDPKcjPS2_+0x1dc)[0x5a07bc]
/usr/sbin/mysqld(_Z16dispatch_command19enum_server_commandP3THDPcj+0xf98)[0x5a1778]
/usr/sbin/mysqld(_Z10do_commandP3THD+0xe7)[0x5a1cd7]
/usr/sbin/mysqld(handle_one_connection+0x592)[0x594c62]
/lib64/libpthread.so.0[0x2b869c790367]
/lib64/libc.so.6(clone+0x6d)[0x2b869d34ff7d]
Trying to get some variables.
Some pointers may be invalid and cause the dump to abort...
thd->query at 0xf9b1670 = CHECK TABLE `rates`  FOR UPGRADE
thd->thread_id=15
thd->killed=NOT_KILLED
The manual page at http://dev.mysql.com/doc/mysql/en/crashing.html contains
information that should help you find out what is causing the crash.
EOF
chomp $big_arg;
$big_arg =~ s/\n+/ /g;

test_log_parser(
   parser => $p,
   file   => 'common/t/samples/errlogs/errlog004.txt',
   result => [
      {
         Level       => 'error',
         arg         => '[ERROR] Error running query, slave SQL thread aborted. Fix the problem, and restart the slave SQL thread with "SLAVE START". We stopped at log \'mpb-bin.000534\' position 47010998',
         pos_in_log  => 0,
         ts          => '090902 10:43:55',
      },
      {
         arg         => 'InnoDB: Unable to lock ./timer2/rates.ibd, error: 37',
         pos_in_log  => 194,
         Level       => 'unknown',
      },
      {
         arg         => 'InnoDB: Assertion failure in thread 1312495936 in file fil/fil0fil.c line 752 Failing assertion: ret We intentionally generate a memory trap. Submit a detailed bug report to http://bugs.mysql.com. If you get repeated assertion failures or crashes, even immediately after the mysqld startup, there may be corruption in the InnoDB tablespace. Please refer to http://dev.mysql.com/doc/refman/5.1/en/forcing-recovery.html about forcing recovery.',
         pos_in_log  => 342,
         ts          => '090902 11:08:43',
         Level       => 'unknown',
      },
      {
         pos_in_log  => 810,
         ts          => '090902 11:08:43',
         arg         => $big_arg,
         Level       => 'unknown',
      },
      {
         arg         => 'mysqld_safe Number of processes running now: 0',
         pos_in_log  => 3636,
         ts          => '090902 11:08:43',
         Level       => 'unknown',
      },
   ]
);

$big_arg = <<'EOF';
Status information:
Current dir: /var/lib/mysql/
Running threads: 16  Stack size: 262144
Current locks:
lock: 0x29a90d0:
lock: 0x26fb910:
lock: 0x28f2ae0:
lock: 0x2921e10:
lock: 0x22ea900:
lock: 0x272b840:
lock: 0x2337f80:
lock: 0x42ff310:
lock: 0x26b35f0:
lock: 0x23861f0:
lock: 0x26a5ee0:
lock: 0x2b02f60:
lock: 0x29d37e0:
lock: 0x29d2f80:
lock: 0x2706e90:
lock: 0x22ee350:
lock: 0x39bd8b0:
lock: 0x28ec500:
lock: 0x2a5e8a0:
lock: 0x271fd60:
lock: 0x39f2c80:
lock: 0x29c2730:
lock: 0x25227f0:
lock: 0x41b6dc0:
lock: 0x4207cd0:
lock: 0x24a0360:
lock: 0x22edcd0:
lock: 0x29cd590:
lock: 0x29c0140:
lock: 0x3a75bf0:
lock: 0x390f530:
lock: 0x390fd00:
lock: 0x3921110:
lock: 0x41d6cd0:
lock: 0x2346100:
lock: 0x22ec870:
lock: 0x23a8ea0:
lock: 0x26fec60:
lock: 0x23878d0:
lock: 0x2652ca0:
lock: 0x3fe7240:
lock: 0x24f5b80:
lock: 0x2614a60:
lock: 0x41b6550:
lock: 0x4199a30:
lock: 0x41ba150:
lock: 0x4192430:
lock: 0x418fcc0:
lock: 0x236a480:
lock: 0x25bf440:
lock: 0x25bbd00:
lock: 0x28207b0:
lock: 0x2ee33b0:
lock: 0x2e1ab50:
lock: 0x442f6f0:
lock: 0x3ed6fe0:
lock: 0x3ed69f0:
lock: 0x25c2100:
lock: 0x25d3840:
lock: 0x3a7c920:
lock: 0x3a7d8d0:
lock: 0x258f080:
lock: 0x2e81d00:
lock: 0x3ef3380:
lock: 0x408e610:
lock: 0x41e1aa0:
lock: 0x2561980:
lock: 0x41c9c50:
lock: 0x3f64c70:
lock: 0x252b2f0:
lock: 0x252dca0:
lock: 0x2e043c0:
lock: 0x3fb2e60:
lock: 0x3eead10:
lock: 0x41a30f0:
lock: 0x4155b50:
lock: 0x41978f0:
lock: 0x28408a0:
lock: 0x429bd80:
lock: 0x4078490:
lock: 0x4195df0:
lock: 0x3ac61a0:
lock: 0x4172470:
lock: 0x3ac4100:
lock: 0x41811d0:
lock: 0x417ea00:
lock: 0x4177730:
lock: 0x4175220:
lock: 0x416dd20:
lock: 0x3a88440:
lock: 0x416b3f0:
lock: 0x4169e40:
lock: 0x4163520:
lock: 0x4162200:
lock: 0x415f540:
lock: 0x4157b60:
lock: 0x4156e60:
lock: 0x40f9970:
lock: 0x3a85800:
lock: 0x28c4b00:
Key caches:
default
Buffer_size:      67108864
Block_size:           1024
Division_limit:        100
Age_limit:             300
blocks used:         53585
not flushed:             0
w_requests:       18891286
writes:            1329532
r_requests:      173889204
reads:              462708
handler status:
read_key:     31268733
read_next:  2781246802
read_rnd      37994506
read_first:     377959
write:       292954339
delete          128239
update:       34140006
Table status:
Opened tables:       2427
Open tables:         1024
Open files:          1630
Open streams:           0
Alarm status:
Active alarms:   16
Max used alarms: 46
Next alarm time: 28699
EOF
chomp $big_arg;
$big_arg =~ s/\n+/ /g;

test_log_parser(
   parser => $p,
   file   => 'common/t/samples/errlogs/errlog005.txt',
   result => [
      {
         pos_in_log  => 0,
         arg         => '[Note] /usr/sbin/mysqld: ready for connections.',
         ts          => '080517  4:20:13',
         Level       => 'info',
      },
      {
         pos_in_log  => 64,
         arg         => 'Version: \'5.0.58-enterprise-gpl-mpb-log\' socket: \'/var/lib/mysql/mysql.sock\'  port: 3306  MySQL Enterprise Server (MPB ed.) (GPL)',
         Level       => 'unknown',
      },
      {
         pos_in_log  => 195,
         Level       => 'unknown',
         arg         => $big_arg,
      },
      {
         pos_in_log  => 2873,
         arg         => '[Warning] \'db\' entry \'test nagios@4fa060606e2d579a\' ignored in --skip-name-resolve mode.',
         ts          => '080522  8:41:31',
         Level       => 'warning',
      },
   ],
);

$big_arg = <<'EOF';
Memory status:
Non-mmapped space allocated from system: 94777344
Number of free chunks:			 1359
Number of fastbin blocks:		 0
Number of mmapped regions:		 17
Space in mmapped regions:		 276152320
Maximum total allocated space:		 0
Space available in freed fastbin blocks: 0
Total allocated space:			 41663312
Total free space:			 53114032
Top-most, releasable space:		 19783856
Estimated memory (with thread stack):    375123968
Status information:
Current dir: /var/lib/mysql/
Running threads: 18  Stack size: 262144
Current locks:
lock: 0x2892460:
lock: 0x3a053a0:
lock: 0x2534210:
lock: 0x27d49e0:
lock: 0x2300950:
lock: 0x2b5f070:
lock: 0x284c2c0:
lock: 0x2607f30:
lock: 0x28827c0:
lock: 0x4388c80:
lock: 0x39c2820:
lock: 0x2b6c2d0:
lock: 0x2d06870:
lock: 0x24f1240:
lock: 0x29ef700:
lock: 0x2b709a0:
lock: 0x3a746b0:
lock: 0x2c21eb0:
lock: 0x29de5a0:
lock: 0x23af7f0:
lock: 0x2e76160:
lock: 0x3fde000:
lock: 0x3a05c20:
lock: 0x286a1f0:
lock: 0x273a660:
lock: 0x26d7250:
lock: 0x24510a0:
lock: 0xe2cdb0:
lock: 0x2304710:
lock: 0x265af50:
lock: 0x30050c0:
lock: 0x265a310:
lock: 0x25ac7b0:
lock: 0x25ab1b0:
lock: 0x2a512f0:
lock: 0x29a65a0:
lock: 0x29460e0:
lock: 0x27f0150:
lock: 0x2cb0490:
lock: 0x41b6e60:
lock: 0x41b5da0:
lock: 0x303c530:
lock: 0x303bc70:
lock: 0x23ba210:
lock: 0x2d85210:
lock: 0x413c6f0:
lock: 0x41fa6e0:
lock: 0x2face70:
lock: 0x2408eb0:
lock: 0x3fd7b30:
lock: 0x41457e0:
lock: 0x2aaad00deb50:
lock: 0x2aaad00da840:
lock: 0x2aaad00f1060:
lock: 0x2aaad0147a10:
lock: 0x2aaad00f26b0:
lock: 0x3fd3940:
lock: 0x3fd13f0:
lock: 0x2d6a370:
lock: 0x24f4270:
lock: 0x4201700:
lock: 0x26a5180:
lock: 0x2406c90:
lock: 0x2d83be0:
lock: 0x2d83320:
lock: 0x3eb7570:
lock: 0x3eb5960:
lock: 0x24f1b00:
lock: 0x2f28220:
lock: 0x2dcbdf0:
lock: 0x2d8f880:
lock: 0x2d8d380:
lock: 0x3eb8b10:
lock: 0x2a13550:
lock: 0x2a10ef0:
lock: 0x4285460:
lock: 0x2a0b050:
lock: 0x3ec41f0:
lock: 0x3ec18c0:
lock: 0x3ebeb00:
lock: 0x3ebc540:
lock: 0x2a07530:
lock: 0x2a04500:
lock: 0x2a00790:
lock: 0x4058050:
lock: 0x4054f80:
lock: 0x4051dd0:
lock: 0x404da00:
lock: 0x404b5f0:
lock: 0x4049270:
lock: 0x4046400:
lock: 0x4042a00:
lock: 0x403ff50:
lock: 0x403cd30:
lock: 0x4294aa0:
lock: 0x4292650:
lock: 0x4290280:
lock: 0x428d770:
lock: 0x4289d50:
lock: 0x42879a0:
Key caches:
default
Buffer_size:      67108864
Block_size:           1024
Division_limit:        100
Age_limit:             300
blocks used:         53585
not flushed:             0
w_requests:        2297322
writes:             214388
r_requests:       22639665
reads:               88496
handler status:
read_key:     37803208
read_next:  3381798717
read_rnd      43876818
read_first:     446022
write:       351416153
delete          149508
update:       39126089
Table status:
Opened tables:       3712
Open tables:         1024
Open files:          1711
Open streams:           0
Alarm status:
Active alarms:   15
Max used alarms: 46
Next alarm time: 28515
Thread database.table_name          Locked/Waiting        Lock_type
341759  mpb_wordpress.wp_TABLE_STATILocked - write        Highest priority write lock
Memory status:
Non-mmapped space allocated from system: 94777344
Number of free chunks:			 369
Number of fastbin blocks:		 0
Number of mmapped regions:		 17
Space in mmapped regions:		 276152320
Maximum total allocated space:		 0
Space available in freed fastbin blocks: 0
Total allocated space:			 40545216
Total free space:			 54232128
Top-most, releasable space:		 27398512
Estimated memory (with thread stack):    375648256
Status information:
Current dir: /var/lib/mysql/
Running threads: 17  Stack size: 262144
Current locks:
lock: 0x41c6080:
lock: 0x2a7ab10:
lock: 0x29f5ba0:
lock: 0x2c56ed0:
lock: 0x2d32a00:
lock: 0x2810980:
lock: 0x22f7980:
lock: 0x2892460:
lock: 0x3a053a0:
lock: 0x2534210:
lock: 0x27d49e0:
lock: 0x2300950:
lock: 0x2b5f070:
lock: 0x284c2c0:
lock: 0x2607f30:
lock: 0x28827c0:
lock: 0x4388c80:
lock: 0x39c2820:
lock: 0x2b6c2d0:
lock: 0x2d06870:
lock: 0x24f1240:
lock: 0x29ef700:
lock: 0x2b709a0:
lock: 0x3a746b0:
lock: 0x2c21eb0:
lock: 0x29de5a0:
lock: 0x23af7f0:
lock: 0x2e76160:
lock: 0x3fde000:
lock: 0x3a05c20:
lock: 0x286a1f0:
lock: 0x273a660:
lock: 0x26d7250:
lock: 0x24510a0:
lock: 0xe2cdb0:
lock: 0x2304710:
lock: 0x265af50:
lock: 0x30050c0:
lock: 0x265a310:
lock: 0x25ac7b0:
lock: 0x25ab1b0:
lock: 0x2a512f0:
lock: 0x29a65a0:
lock: 0x29460e0:
lock: 0x27f0150:
lock: 0x2cb0490:
lock: 0x41b6e60:
lock: 0x41b5da0:
lock: 0x303c530:
lock: 0x303bc70:
lock: 0x23ba210:
lock: 0x2d85210:
lock: 0x413c6f0:
lock: 0x41fa6e0:
lock: 0x2face70:
lock: 0x2408eb0:
lock: 0x3fd7b30:
lock: 0x41457e0:
lock: 0x2aaad00deb50:
lock: 0x2aaad00da840:
lock: 0x2aaad00f1060:
lock: 0x2aaad0147a10:
lock: 0x2aaad00f26b0:
lock: 0x3fd3940:
lock: 0x3fd13f0:
lock: 0x2d6a370:
lock: 0x24f4270:
lock: 0x4201700:
lock: 0x26a5180:
lock: 0x2406c90:
lock: 0x2d83be0:
lock: 0x2d83320:
lock: 0x3eb7570:
lock: 0x3eb5960:
lock: 0x24f1b00:
lock: 0x2f28220:
lock: 0x2dcbdf0:
lock: 0x2d8f880:
lock: 0x2d8d380:
lock: 0x3eb8b10:
lock: 0x2a13550:
lock: 0x2a10ef0:
lock: 0x4285460:
lock: 0x2a0b050:
lock: 0x3ec41f0:
lock: 0x3ec18c0:
lock: 0x3ebeb00:
lock: 0x3ebc540:
lock: 0x2a07530:
lock: 0x2a04500:
lock: 0x2a00790:
lock: 0x4058050:
lock: 0x4054f80:
lock: 0x4051dd0:
lock: 0x404da00:
lock: 0x404b5f0:
lock: 0x4049270:
lock: 0x4046400:
lock: 0x4042a00:
lock: 0x403ff50:
Key caches:
default
Buffer_size:      67108864
Block_size:           1024
Division_limit:        100
Age_limit:             300
blocks used:         53585
not flushed:             0
w_requests:        2300317
writes:             216679
r_requests:       22692159
reads:               88527
handler status:
read_key:     37853941
read_next:  3387042343
read_rnd      43886662
read_first:     446721
write:       351827374
delete          149708
update:       39127779
Table status:
Opened tables:       3720
Open tables:         1024
Open files:          1725
Open streams:           0
Alarm status:
Active alarms:   17
Max used alarms: 46
Next alarm time: 28463
EOF
chomp $big_arg;
$big_arg =~ s/\n+/ /g;

test_log_parser(
   parser => $p,
   file   => 'common/t/samples/errlogs/errlog009.txt',
   result => [
      {
         Level       => 'warning',
         pos_in_log  => '0',
         arg         => '[Warning] \'db\' entry \'test nagios@4fa060606e2d579a\' ignored in --skip-name-resolve mode.',
         ts          => '080523  7:26:27',
      },
      {
         pos_in_log  => '105',
         arg         => $big_arg,
         Level       => 'unknown',
      },
      {
         Level       => 'warning',
         pos_in_log  => '6424',
         arg         => '[Warning] \'db\' entry \'test nagios@4fa060606e2d579a\' ignored in --skip-name-resolve mode.',
         ts          => '080523  7:26:27',
      },
   ],
);

test_log_parser(
   parser => $p,
   file   => 'common/t/samples/errlogs/errlog006.txt',
   result => [
         {  Level => 'unknown',
            ts    => '091119 22:27:11',
            arg =>
               'InnoDB: Warning: cannot find a free slot for an '
               . 'undo log. Do you have too many active transactions running '
               . 'concurrently?',
            pos_in_log => '0'
         },
         {  Level => 'unknown',
            ts    => '091119 22:27:11',
            arg =>
               'InnoDB: Warning: cannot find a free slot for an '
               . 'undo log. Do you have too many active transactions running '
               . 'concurrently?',
            pos_in_log => '233'
         },
   ],
);

$big_arg = <<'EOF';
InnoDB: Warning: cannot find a free slot for an undo log. Do you have too
many active transactions running concurrently?
Warning: a long semaphore wait:
--Thread 1808345440 has waited at btr0sea.c line 1127 for 242.00 seconds the semaphore:
S-lock on RW-latch at 0x2a96d920b8 created in file btr0sea.c line 139
a writer (thread id 1799514464) has reserved it in mode  wait exclusive
number of readers 0, waiters flag 1
Last time read locked in file btr0sea.c line 746
Last time write locked in file btr0cur.c line 2184
Warning: a long semaphore wait:
--Thread 1799514464 has waited at btr0sea.c line 489 for 242.00 seconds the semaphore:
X-lock on RW-latch at 0x2a96d920b8 created in file btr0sea.c line 139
a writer (thread id 1799514464) has reserved it in mode  wait exclusive
number of readers 0, waiters flag 1
Last time read locked in file btr0sea.c line 746
Last time write locked in file btr0cur.c line 2184
Warning: a long semaphore wait:
--Thread 1536391520 has waited at lock0lock.c line 3093 for 242.00 seconds the semaphore:
Mutex at 0x2a96d8f2b8 created file srv0srv.c line 872, lock var 1
waiters flag 1
Warning: a long semaphore wait:
--Thread 1829017952 has waited at btr0sea.c line 1127 for 242.00 seconds the semaphore:
S-lock on RW-latch at 0x2a96d920b8 created in file btr0sea.c line 139
a writer (thread id 1799514464) has reserved it in mode  wait exclusive
number of readers 0, waiters flag 1
Last time read locked in file btr0sea.c line 746
Last time write locked in file btr0cur.c line 2184
Warning: a long semaphore wait:
--Thread 1598609760 has waited at btr0sea.c line 746 for 242.00 seconds the semaphore:
S-lock on RW-latch at 0x2a96d920b8 created in file btr0sea.c line 139
a writer (thread id 1799514464) has reserved it in mode  wait exclusive
number of readers 0, waiters flag 1
Last time read locked in file btr0sea.c line 746
Last time write locked in file btr0cur.c line 2184
Warning: a long semaphore wait:
--Thread 1515411808 has waited at srv0srv.c line 1952 for 242.00 seconds the semaphore:
Mutex at 0x2a96d8f2b8 created file srv0srv.c line 872, lock var 1
waiters flag 1
Warning: a long semaphore wait:
--Thread 1564289376 has waited at btr0sea.c line 1127 for 242.00 seconds the semaphore:
S-lock on RW-latch at 0x2a96d920b8 created in file btr0sea.c line 139
a writer (thread id 1799514464) has reserved it in mode  wait exclusive
number of readers 0, waiters flag 1
Last time read locked in file btr0sea.c line 746
Last time write locked in file btr0cur.c line 2184
Warning: a long semaphore wait:
--Thread 1597606240 has waited at btr0sea.c line 1383 for 242.00 seconds the semaphore:
X-lock on RW-latch at 0x2a96d920b8 created in file btr0sea.c line 139
a writer (thread id 1799514464) has reserved it in mode  wait exclusive
number of readers 0, waiters flag 1
Last time read locked in file btr0sea.c line 746
Last time write locked in file btr0cur.c line 2184
Warning: a long semaphore wait:
--Thread 1628715360 has waited at btr0sea.c line 1127 for 242.00 seconds the semaphore:
S-lock on RW-latch at 0x2a96d920b8 created in file btr0sea.c line 139
a writer (thread id 1799514464) has reserved it in mode  wait exclusive
number of readers 0, waiters flag 1
Last time read locked in file btr0sea.c line 746
Last time write locked in file btr0cur.c line 2184
Warning: a long semaphore wait:
--Thread 1539602784 has waited at btr0sea.c line 916 for 242.00 seconds the semaphore:
S-lock on RW-latch at 0x2a96d920b8 created in file btr0sea.c line 139
a writer (thread id 1799514464) has reserved it in mode  wait exclusive
number of readers 0, waiters flag 1
Last time read locked in file btr0sea.c line 746
Last time write locked in file btr0cur.c line 2184
Warning: a long semaphore wait:
--Thread 1598810464 has waited at btr0sea.c line 746 for 242.00 seconds the semaphore:
S-lock on RW-latch at 0x2a96d920b8 created in file btr0sea.c line 139
a writer (thread id 1799514464) has reserved it in mode  wait exclusive
number of readers 0, waiters flag 1
Last time read locked in file btr0sea.c line 746
Last time write locked in file btr0cur.c line 2184
Warning: a long semaphore wait:
--Thread 1795098976 has waited at btr0sea.c line 1127 for 242.00 seconds the semaphore:
S-lock on RW-latch at 0x2a96d920b8 created in file btr0sea.c line 139
a writer (thread id 1799514464) has reserved it in mode  wait exclusive
number of readers 0, waiters flag 1
Last time read locked in file btr0sea.c line 746
Last time write locked in file btr0cur.c line 2184
Warning: a long semaphore wait:
--Thread 1565895008 has waited at btr0sea.c line 916 for 242.00 seconds the semaphore:
S-lock on RW-latch at 0x2a96d920b8 created in file btr0sea.c line 139
a writer (thread id 1799514464) has reserved it in mode  wait exclusive
number of readers 0, waiters flag 1
Last time read locked in file btr0sea.c line 746
Last time write locked in file btr0cur.c line 2184
Warning: a long semaphore wait:
--Thread 1634335072 has waited at row0sel.c line 3326 for 242.00 seconds the semaphore:
S-lock on RW-latch at 0x2a96d920b8 created in file btr0sea.c line 139
a writer (thread id 1799514464) has reserved it in mode  wait exclusive
number of readers 0, waiters flag 1
Last time read locked in file btr0sea.c line 746
Last time write locked in file btr0cur.c line 2184
Warning: a long semaphore wait:
--Thread 1582954848 has waited at btr0sea.c line 1127 for 242.00 seconds the semaphore:
S-lock on RW-latch at 0x2a96d920b8 created in file btr0sea.c line 139
a writer (thread id 1799514464) has reserved it in mode  wait exclusive
number of readers 0, waiters flag 1
Last time read locked in file btr0sea.c line 746
Last time write locked in file btr0cur.c line 2184
Warning: a long semaphore wait:
--Thread 1548433760 has waited at btr0sea.c line 746 for 242.00 seconds the semaphore:
S-lock on RW-latch at 0x2a96d920b8 created in file btr0sea.c line 139
a writer (thread id 1799514464) has reserved it in mode  wait exclusive
number of readers 0, waiters flag 1
Last time read locked in file btr0sea.c line 746
Last time write locked in file btr0cur.c line 2184
Warning: a long semaphore wait:
--Thread 1640958304 has waited at btr0sea.c line 916 for 242.00 seconds the semaphore:
S-lock on RW-latch at 0x2a96d920b8 created in file btr0sea.c line 139
a writer (thread id 1799514464) has reserved it in mode  wait exclusive
number of readers 0, waiters flag 1
Last time read locked in file btr0sea.c line 746
Last time write locked in file btr0cur.c line 2184
Warning: a long semaphore wait:
--Thread 1642764640 has waited at trx0trx.c line 715 for 242.00 seconds the semaphore:
Mutex at 0x2a96d8f2b8 created file srv0srv.c line 872, lock var 1
waiters flag 1
Warning: a long semaphore wait:
--Thread 1602824544 has waited at trx0trx.c line 371 for 242.00 seconds the semaphore:
Mutex at 0x2a96d8f2b8 created file srv0srv.c line 872, lock var 1
waiters flag 1
Warning: a long semaphore wait:
--Thread 1643567456 has waited at trx0trx.c line 1609 for 242.00 seconds the semaphore:
Mutex at 0x2a96d8f2b8 created file srv0srv.c line 872, lock var 1
waiters flag 1
Warning: a long semaphore wait:
--Thread 1628916064 has waited at btr0sea.c line 1127 for 242.00 seconds the semaphore:
S-lock on RW-latch at 0x2a96d920b8 created in file btr0sea.c line 139
a writer (thread id 1799514464) has reserved it in mode  wait exclusive
number of readers 0, waiters flag 1
Last time read locked in file btr0sea.c line 746
Last time write locked in file btr0cur.c line 2184
###### Starts InnoDB Monitor for 30 secs to print diagnostic info:
Pending preads 0, pwrites 0
###### Diagnostic info printed to the standard error stream
Warning: a long semaphore wait:
--Thread 1808345440 has waited at btr0sea.c line 1127 for 274.00 seconds the semaphore:
S-lock on RW-latch at 0x2a96d920b8 created in file btr0sea.c line 139
a writer (thread id 1799514464) has reserved it in mode  wait exclusive
number of readers 0, waiters flag 1
Last time read locked in file btr0sea.c line 746
Last time write locked in file btr0cur.c line 2184
Warning: a long semaphore wait:
--Thread 1799514464 has waited at btr0sea.c line 489 for 274.00 seconds the semaphore:
X-lock on RW-latch at 0x2a96d920b8 created in file btr0sea.c line 139
a writer (thread id 1799514464) has reserved it in mode  wait exclusive
number of readers 0, waiters flag 1
Last time read locked in file btr0sea.c line 746
Last time write locked in file btr0cur.c line 2184
Warning: a long semaphore wait:
--Thread 1536391520 has waited at lock0lock.c line 3093 for 274.00 seconds the semaphore:
Mutex at 0x2a96d8f2b8 created file srv0srv.c line 872, lock var 1
waiters flag 1
Warning: a long semaphore wait:
--Thread 1829017952 has waited at btr0sea.c line 1127 for 274.00 seconds the semaphore:
S-lock on RW-latch at 0x2a96d920b8 created in file btr0sea.c line 139
a writer (thread id 1799514464) has reserved it in mode  wait exclusive
number of readers 0, waiters flag 1
Last time read locked in file btr0sea.c line 746
Last time write locked in file btr0cur.c line 2184
Warning: a long semaphore wait:
--Thread 1598609760 has waited at btr0sea.c line 746 for 274.00 seconds the semaphore:
S-lock on RW-latch at 0x2a96d920b8 created in file btr0sea.c line 139
a writer (thread id 1799514464) has reserved it in mode  wait exclusive
number of readers 0, waiters flag 1
Last time read locked in file btr0sea.c line 746
Last time write locked in file btr0cur.c line 2184
Warning: a long semaphore wait:
--Thread 1515411808 has waited at srv0srv.c line 1952 for 274.00 seconds the semaphore:
Mutex at 0x2a96d8f2b8 created file srv0srv.c line 872, lock var 1
waiters flag 1
Warning: a long semaphore wait:
--Thread 1564289376 has waited at btr0sea.c line 1127 for 274.00 seconds the semaphore:
S-lock on RW-latch at 0x2a96d920b8 created in file btr0sea.c line 139
a writer (thread id 1799514464) has reserved it in mode  wait exclusive
number of readers 0, waiters flag 1
Last time read locked in file btr0sea.c line 746
Last time write locked in file btr0cur.c line 2184
Warning: a long semaphore wait:
--Thread 1597606240 has waited at btr0sea.c line 1383 for 274.00 seconds the semaphore:
X-lock on RW-latch at 0x2a96d920b8 created in file btr0sea.c line 139
a writer (thread id 1799514464) has reserved it in mode  wait exclusive
number of readers 0, waiters flag 1
Last time read locked in file btr0sea.c line 746
Last time write locked in file btr0cur.c line 2184
Warning: a long semaphore wait:
--Thread 1628715360 has waited at btr0sea.c line 1127 for 274.00 seconds the semaphore:
S-lock on RW-latch at 0x2a96d920b8 created in file btr0sea.c line 139
a writer (thread id 1799514464) has reserved it in mode  wait exclusive
number of readers 0, waiters flag 1
Last time read locked in file btr0sea.c line 746
Last time write locked in file btr0cur.c line 2184
Warning: a long semaphore wait:
--Thread 1539602784 has waited at btr0sea.c line 916 for 274.00 seconds the semaphore:
S-lock on RW-latch at 0x2a96d920b8 created in file btr0sea.c line 139
a writer (thread id 1799514464) has reserved it in mode  wait exclusive
number of readers 0, waiters flag 1
Last time read locked in file btr0sea.c line 746
Last time write locked in file btr0cur.c line 2184
Warning: a long semaphore wait:
--Thread 1598810464 has waited at btr0sea.c line 746 for 274.00 seconds the semaphore:
S-lock on RW-latch at 0x2a96d920b8 created in file btr0sea.c line 139
a writer (thread id 1799514464) has reserved it in mode  wait exclusive
number of readers 0, waiters flag 1
Last time read locked in file btr0sea.c line 746
Last time write locked in file btr0cur.c line 2184
Warning: a long semaphore wait:
--Thread 1795098976 has waited at btr0sea.c line 1127 for 274.00 seconds the semaphore:
S-lock on RW-latch at 0x2a96d920b8 created in file btr0sea.c line 139
a writer (thread id 1799514464) has reserved it in mode  wait exclusive
number of readers 0, waiters flag 1
Last time read locked in file btr0sea.c line 746
Last time write locked in file btr0cur.c line 2184
Warning: a long semaphore wait:
--Thread 1565895008 has waited at btr0sea.c line 916 for 274.00 seconds the semaphore:
S-lock on RW-latch at 0x2a96d920b8 created in file btr0sea.c line 139
a writer (thread id 1799514464) has reserved it in mode  wait exclusive
number of readers 0, waiters flag 1
Last time read locked in file btr0sea.c line 746
Last time write locked in file btr0cur.c line 2184
Warning: a long semaphore wait:
--Thread 1634335072 has waited at row0sel.c line 3326 for 274.00 seconds the semaphore:
S-lock on RW-latch at 0x2a96d920b8 created in file btr0sea.c line 139
a writer (thread id 1799514464) has reserved it in mode  wait exclusive
number of readers 0, waiters flag 1
Last time read locked in file btr0sea.c line 746
Last time write locked in file btr0cur.c line 2184
Warning: a long semaphore wait:
--Thread 1582954848 has waited at btr0sea.c line 1127 for 274.00 seconds the semaphore:
S-lock on RW-latch at 0x2a96d920b8 created in file btr0sea.c line 139
a writer (thread id 1799514464) has reserved it in mode  wait exclusive
number of readers 0, waiters flag 1
Last time read locked in file btr0sea.c line 746
Last time write locked in file btr0cur.c line 2184
Warning: a long semaphore wait:
--Thread 1548433760 has waited at btr0sea.c line 746 for 274.00 seconds the semaphore:
S-lock on RW-latch at 0x2a96d920b8 created in file btr0sea.c line 139
a writer (thread id 1799514464) has reserved it in mode  wait exclusive
number of readers 0, waiters flag 1
Last time read locked in file btr0sea.c line 746
Last time write locked in file btr0cur.c line 2184
Warning: a long semaphore wait:
--Thread 1640958304 has waited at btr0sea.c line 916 for 274.00 seconds the semaphore:
S-lock on RW-latch at 0x2a96d920b8 created in file btr0sea.c line 139
a writer (thread id 1799514464) has reserved it in mode  wait exclusive
number of readers 0, waiters flag 1
Last time read locked in file btr0sea.c line 746
Last time write locked in file btr0cur.c line 2184
Warning: a long semaphore wait:
--Thread 1642764640 has waited at trx0trx.c line 715 for 274.00 seconds the semaphore:
Mutex at 0x2a96d8f2b8 created file srv0srv.c line 872, lock var 1
waiters flag 1
Warning: a long semaphore wait:
--Thread 1602824544 has waited at trx0trx.c line 371 for 274.00 seconds the semaphore:
Mutex at 0x2a96d8f2b8 created file srv0srv.c line 872, lock var 1
waiters flag 1
Warning: a long semaphore wait:
--Thread 1643567456 has waited at trx0trx.c line 1609 for 274.00 seconds the semaphore:
Mutex at 0x2a96d8f2b8 created file srv0srv.c line 872, lock var 1
waiters flag 1
Warning: a long semaphore wait:
--Thread 1628916064 has waited at btr0sea.c line 1127 for 274.00 seconds the semaphore:
S-lock on RW-latch at 0x2a96d920b8 created in file btr0sea.c line 139
a writer (thread id 1799514464) has reserved it in mode  wait exclusive
number of readers 0, waiters flag 1
Last time read locked in file btr0sea.c line 746
Last time write locked in file btr0cur.c line 2184
###### Starts InnoDB Monitor for 30 secs to print diagnostic info:
Pending preads 0, pwrites 0
###### Diagnostic info printed to the standard error stream
Warning: a long semaphore wait:
--Thread 1808345440 has waited at btr0sea.c line 1127 for 306.00 seconds the semaphore:
S-lock on RW-latch at 0x2a96d920b8 created in file btr0sea.c line 139
a writer (thread id 1799514464) has reserved it in mode  wait exclusive
number of readers 0, waiters flag 1
Last time read locked in file btr0sea.c line 746
Last time write locked in file btr0cur.c line 2184
Warning: a long semaphore wait:
--Thread 1799514464 has waited at btr0sea.c line 489 for 306.00 seconds the semaphore:
X-lock on RW-latch at 0x2a96d920b8 created in file btr0sea.c line 139
a writer (thread id 1799514464) has reserved it in mode  wait exclusive
number of readers 0, waiters flag 1
Last time read locked in file btr0sea.c line 746
Last time write locked in file btr0cur.c line 2184
Warning: a long semaphore wait:
--Thread 1536391520 has waited at lock0lock.c line 3093 for 306.00 seconds the semaphore:
Mutex at 0x2a96d8f2b8 created file srv0srv.c line 872, lock var 1
waiters flag 1
Warning: a long semaphore wait:
--Thread 1829017952 has waited at btr0sea.c line 1127 for 306.00 seconds the semaphore:
S-lock on RW-latch at 0x2a96d920b8 created in file btr0sea.c line 139
a writer (thread id 1799514464) has reserved it in mode  wait exclusive
number of readers 0, waiters flag 1
Last time read locked in file btr0sea.c line 746
Last time write locked in file btr0cur.c line 2184
Warning: a long semaphore wait:
--Thread 1598609760 has waited at btr0sea.c line 746 for 306.00 seconds the semaphore:
S-lock on RW-latch at 0x2a96d920b8 created in file btr0sea.c line 139
a writer (thread id 1799514464) has reserved it in mode  wait exclusive
number of readers 0, waiters flag 1
Last time read locked in file btr0sea.c line 746
Last time write locked in file btr0cur.c line 2184
Warning: a long semaphore wait:
--Thread 1515411808 has waited at srv0srv.c line 1952 for 306.00 seconds the semaphore:
Mutex at 0x2a96d8f2b8 created file srv0srv.c line 872, lock var 1
waiters flag 1
Warning: a long semaphore wait:
--Thread 1564289376 has waited at btr0sea.c line 1127 for 306.00 seconds the semaphore:
S-lock on RW-latch at 0x2a96d920b8 created in file btr0sea.c line 139
a writer (thread id 1799514464) has reserved it in mode  wait exclusive
number of readers 0, waiters flag 1
Last time read locked in file btr0sea.c line 746
Last time write locked in file btr0cur.c line 2184
Warning: a long semaphore wait:
--Thread 1597606240 has waited at btr0sea.c line 1383 for 306.00 seconds the semaphore:
X-lock on RW-latch at 0x2a96d920b8 created in file btr0sea.c line 139
a writer (thread id 1799514464) has reserved it in mode  wait exclusive
number of readers 0, waiters flag 1
Last time read locked in file btr0sea.c line 746
Last time write locked in file btr0cur.c line 2184
Warning: a long semaphore wait:
--Thread 1628715360 has waited at btr0sea.c line 1127 for 306.00 seconds the semaphore:
S-lock on RW-latch at 0x2a96d920b8 created in file btr0sea.c line 139
a writer (thread id 1799514464) has reserved it in mode  wait exclusive
number of readers 0, waiters flag 1
Last time read locked in file btr0sea.c line 746
Last time write locked in file btr0cur.c line 2184
Warning: a long semaphore wait:
--Thread 1539602784 has waited at btr0sea.c line 916 for 306.00 seconds the semaphore:
S-lock on RW-latch at 0x2a96d920b8 created in file btr0sea.c line 139
a writer (thread id 1799514464) has reserved it in mode  wait exclusive
number of readers 0, waiters flag 1
Last time read locked in file btr0sea.c line 746
Last time write locked in file btr0cur.c line 2184
Warning: a long semaphore wait:
--Thread 1598810464 has waited at btr0sea.c line 746 for 306.00 seconds the semaphore:
S-lock on RW-latch at 0x2a96d920b8 created in file btr0sea.c line 139
a writer (thread id 1799514464) has reserved it in mode  wait exclusive
number of readers 0, waiters flag 1
Last time read locked in file btr0sea.c line 746
Last time write locked in file btr0cur.c line 2184
Warning: a long semaphore wait:
--Thread 1795098976 has waited at btr0sea.c line 1127 for 306.00 seconds the semaphore:
S-lock on RW-latch at 0x2a96d920b8 created in file btr0sea.c line 139
a writer (thread id 1799514464) has reserved it in mode  wait exclusive
number of readers 0, waiters flag 1
Last time read locked in file btr0sea.c line 746
Last time write locked in file btr0cur.c line 2184
Warning: a long semaphore wait:
--Thread 1565895008 has waited at btr0sea.c line 916 for 306.00 seconds the semaphore:
S-lock on RW-latch at 0x2a96d920b8 created in file btr0sea.c line 139
a writer (thread id 1799514464) has reserved it in mode  wait exclusive
number of readers 0, waiters flag 1
Last time read locked in file btr0sea.c line 746
Last time write locked in file btr0cur.c line 2184
Warning: a long semaphore wait:
--Thread 1634335072 has waited at row0sel.c line 3326 for 306.00 seconds the semaphore:
S-lock on RW-latch at 0x2a96d920b8 created in file btr0sea.c line 139
a writer (thread id 1799514464) has reserved it in mode  wait exclusive
number of readers 0, waiters flag 1
Last time read locked in file btr0sea.c line 746
Last time write locked in file btr0cur.c line 2184
Warning: a long semaphore wait:
--Thread 1582954848 has waited at btr0sea.c line 1127 for 306.00 seconds the semaphore:
S-lock on RW-latch at 0x2a96d920b8 created in file btr0sea.c line 139
a writer (thread id 1799514464) has reserved it in mode  wait exclusive
number of readers 0, waiters flag 1
Last time read locked in file btr0sea.c line 746
Last time write locked in file btr0cur.c line 2184
Warning: a long semaphore wait:
--Thread 1548433760 has waited at btr0sea.c line 746 for 306.00 seconds the semaphore:
S-lock on RW-latch at 0x2a96d920b8 created in file btr0sea.c line 139
a writer (thread id 1799514464) has reserved it in mode  wait exclusive
number of readers 0, waiters flag 1
Last time read locked in file btr0sea.c line 746
Last time write locked in file btr0cur.c line 2184
Warning: a long semaphore wait:
--Thread 1640958304 has waited at btr0sea.c line 916 for 306.00 seconds the semaphore:
S-lock on RW-latch at 0x2a96d920b8 created in file btr0sea.c line 139
a writer (thread id 1799514464) has reserved it in mode  wait exclusive
number of readers 0, waiters flag 1
Last time read locked in file btr0sea.c line 746
Last time write locked in file btr0cur.c line 2184
Warning: a long semaphore wait:
--Thread 1642764640 has waited at trx0trx.c line 715 for 306.00 seconds the semaphore:
Mutex at 0x2a96d8f2b8 created file srv0srv.c line 872, lock var 1
waiters flag 1
Warning: a long semaphore wait:
--Thread 1602824544 has waited at trx0trx.c line 371 for 306.00 seconds the semaphore:
Mutex at 0x2a96d8f2b8 created file srv0srv.c line 872, lock var 1
waiters flag 1
Warning: a long semaphore wait:
--Thread 1643567456 has waited at trx0trx.c line 1609 for 306.00 seconds the semaphore:
Mutex at 0x2a96d8f2b8 created file srv0srv.c line 872, lock var 1
waiters flag 1
Warning: a long semaphore wait:
--Thread 1628916064 has waited at btr0sea.c line 1127 for 306.00 seconds the semaphore:
S-lock on RW-latch at 0x2a96d920b8 created in file btr0sea.c line 139
a writer (thread id 1799514464) has reserved it in mode  wait exclusive
number of readers 0, waiters flag 1
Last time read locked in file btr0sea.c line 746
Last time write locked in file btr0cur.c line 2184
###### Starts InnoDB Monitor for 30 secs to print diagnostic info:
Pending preads 0, pwrites 0
###### Diagnostic info printed to the standard error stream
Warning: a long semaphore wait:
--Thread 1808345440 has waited at btr0sea.c line 1127 for 338.00 seconds the semaphore:
S-lock on RW-latch at 0x2a96d920b8 created in file btr0sea.c line 139
a writer (thread id 1799514464) has reserved it in mode  wait exclusive
number of readers 0, waiters flag 1
Last time read locked in file btr0sea.c line 746
Last time write locked in file btr0cur.c line 2184
Warning: a long semaphore wait:
--Thread 1799514464 has waited at btr0sea.c line 489 for 338.00 seconds the semaphore:
X-lock on RW-latch at 0x2a96d920b8 created in file btr0sea.c line 139
a writer (thread id 1799514464) has reserved it in mode  wait exclusive
number of readers 0, waiters flag 1
Last time read locked in file btr0sea.c line 746
Last time write locked in file btr0cur.c line 2184
Warning: a long semaphore wait:
--Thread 1536391520 has waited at lock0lock.c line 3093 for 338.00 seconds the semaphore:
Mutex at 0x2a96d8f2b8 created file srv0srv.c line 872, lock var 1
waiters flag 1
Warning: a long semaphore wait:
--Thread 1829017952 has waited at btr0sea.c line 1127 for 338.00 seconds the semaphore:
S-lock on RW-latch at 0x2a96d920b8 created in file btr0sea.c line 139
a writer (thread id 1799514464) has reserved it in mode  wait exclusive
number of readers 0, waiters flag 1
Last time read locked in file btr0sea.c line 746
Last time write locked in file btr0cur.c line 2184
Warning: a long semaphore wait:
--Thread 1598609760 has waited at btr0sea.c line 746 for 338.00 seconds the semaphore:
S-lock on RW-latch at 0x2a96d920b8 created in file btr0sea.c line 139
a writer (thread id 1799514464) has reserved it in mode  wait exclusive
number of readers 0, waiters flag 1
Last time read locked in file btr0sea.c line 746
Last time write locked in file btr0cur.c line 2184
Warning: a long semaphore wait:
--Thread 1515411808 has waited at srv0srv.c line 1952 for 338.00 seconds the semaphore:
Mutex at 0x2a96d8f2b8 created file srv0srv.c line 872, lock var 1
waiters flag 1
Warning: a long semaphore wait:
--Thread 1564289376 has waited at btr0sea.c line 1127 for 338.00 seconds the semaphore:
S-lock on RW-latch at 0x2a96d920b8 created in file btr0sea.c line 139
a writer (thread id 1799514464) has reserved it in mode  wait exclusive
number of readers 0, waiters flag 1
Last time read locked in file btr0sea.c line 746
Last time write locked in file btr0cur.c line 2184
Warning: a long semaphore wait:
--Thread 1597606240 has waited at btr0sea.c line 1383 for 338.00 seconds the semaphore:
X-lock on RW-latch at 0x2a96d920b8 created in file btr0sea.c line 139
a writer (thread id 1799514464) has reserved it in mode  wait exclusive
number of readers 0, waiters flag 1
Last time read locked in file btr0sea.c line 746
Last time write locked in file btr0cur.c line 2184
Warning: a long semaphore wait:
--Thread 1628715360 has waited at btr0sea.c line 1127 for 338.00 seconds the semaphore:
S-lock on RW-latch at 0x2a96d920b8 created in file btr0sea.c line 139
a writer (thread id 1799514464) has reserved it in mode  wait exclusive
number of readers 0, waiters flag 1
Last time read locked in file btr0sea.c line 746
Last time write locked in file btr0cur.c line 2184
Warning: a long semaphore wait:
--Thread 1539602784 has waited at btr0sea.c line 916 for 338.00 seconds the semaphore:
S-lock on RW-latch at 0x2a96d920b8 created in file btr0sea.c line 139
a writer (thread id 1799514464) has reserved it in mode  wait exclusive
number of readers 0, waiters flag 1
Last time read locked in file btr0sea.c line 746
Last time write locked in file btr0cur.c line 2184
Warning: a long semaphore wait:
--Thread 1598810464 has waited at btr0sea.c line 746 for 338.00 seconds the semaphore:
S-lock on RW-latch at 0x2a96d920b8 created in file btr0sea.c line 139
a writer (thread id 1799514464) has reserved it in mode  wait exclusive
number of readers 0, waiters flag 1
Last time read locked in file btr0sea.c line 746
Last time write locked in file btr0cur.c line 2184
Warning: a long semaphore wait:
--Thread 1795098976 has waited at btr0sea.c line 1127 for 338.00 seconds the semaphore:
S-lock on RW-latch at 0x2a96d920b8 created in file btr0sea.c line 139
a writer (thread id 1799514464) has reserved it in mode  wait exclusive
number of readers 0, waiters flag 1
Last time read locked in file btr0sea.c line 746
Last time write locked in file btr0cur.c line 2184
Warning: a long semaphore wait:
--Thread 1565895008 has waited at btr0sea.c line 916 for 338.00 seconds the semaphore:
S-lock on RW-latch at 0x2a96d920b8 created in file btr0sea.c line 139
a writer (thread id 1799514464) has reserved it in mode  wait exclusive
number of readers 0, waiters flag 1
Last time read locked in file btr0sea.c line 746
Last time write locked in file btr0cur.c line 2184
Warning: a long semaphore wait:
--Thread 1634335072 has waited at row0sel.c line 3326 for 338.00 seconds the semaphore:
S-lock on RW-latch at 0x2a96d920b8 created in file btr0sea.c line 139
a writer (thread id 1799514464) has reserved it in mode  wait exclusive
number of readers 0, waiters flag 1
Last time read locked in file btr0sea.c line 746
Last time write locked in file btr0cur.c line 2184
Warning: a long semaphore wait:
--Thread 1582954848 has waited at btr0sea.c line 1127 for 338.00 seconds the semaphore:
S-lock on RW-latch at 0x2a96d920b8 created in file btr0sea.c line 139
a writer (thread id 1799514464) has reserved it in mode  wait exclusive
number of readers 0, waiters flag 1
Last time read locked in file btr0sea.c line 746
Last time write locked in file btr0cur.c line 2184
Warning: a long semaphore wait:
--Thread 1548433760 has waited at btr0sea.c line 746 for 338.00 seconds the semaphore:
S-lock on RW-latch at 0x2a96d920b8 created in file btr0sea.c line 139
a writer (thread id 1799514464) has reserved it in mode  wait exclusive
number of readers 0, waiters flag 1
Last time read locked in file btr0sea.c line 746
Last time write locked in file btr0cur.c line 2184
Warning: a long semaphore wait:
--Thread 1640958304 has waited at btr0sea.c line 916 for 338.00 seconds the semaphore:
S-lock on RW-latch at 0x2a96d920b8 created in file btr0sea.c line 139
a writer (thread id 1799514464) has reserved it in mode  wait exclusive
number of readers 0, waiters flag 1
Last time read locked in file btr0sea.c line 746
Last time write locked in file btr0cur.c line 2184
Warning: a long semaphore wait:
--Thread 1642764640 has waited at trx0trx.c line 715 for 338.00 seconds the semaphore:
Mutex at 0x2a96d8f2b8 created file srv0srv.c line 872, lock var 1
waiters flag 1
Warning: a long semaphore wait:
--Thread 1602824544 has waited at trx0trx.c line 371 for 338.00 seconds the semaphore:
Mutex at 0x2a96d8f2b8 created file srv0srv.c line 872, lock var 1
waiters flag 1
Warning: a long semaphore wait:
--Thread 1643567456 has waited at trx0trx.c line 1609 for 338.00 seconds the semaphore:
Mutex at 0x2a96d8f2b8 created file srv0srv.c line 872, lock var 1
waiters flag 1
Warning: a long semaphore wait:
--Thread 1628916064 has waited at btr0sea.c line 1127 for 338.00 seconds the semaphore:
S-lock on RW-latch at 0x2a96d920b8 created in file btr0sea.c line 139
a writer (thread id 1799514464) has reserved it in mode  wait exclusive
number of readers 0, waiters flag 1
Last time read locked in file btr0sea.c line 746
Last time write locked in file btr0cur.c line 2184
###### Starts InnoDB Monitor for 30 secs to print diagnostic info:
Pending preads 0, pwrites 0
###### Diagnostic info printed to the standard error stream
Warning: a long semaphore wait:
--Thread 1808345440 has waited at btr0sea.c line 1127 for 370.00 seconds the semaphore:
S-lock on RW-latch at 0x2a96d920b8 created in file btr0sea.c line 139
a writer (thread id 1799514464) has reserved it in mode  wait exclusive
number of readers 0, waiters flag 1
Last time read locked in file btr0sea.c line 746
Last time write locked in file btr0cur.c line 2184
Warning: a long semaphore wait:
--Thread 1799514464 has waited at btr0sea.c line 489 for 370.00 seconds the semaphore:
X-lock on RW-latch at 0x2a96d920b8 created in file btr0sea.c line 139
a writer (thread id 1799514464) has reserved it in mode  wait exclusive
number of readers 0, waiters flag 1
Last time read locked in file btr0sea.c line 746
Last time write locked in file btr0cur.c line 2184
Warning: a long semaphore wait:
--Thread 1536391520 has waited at lock0lock.c line 3093 for 370.00 seconds the semaphore:
Mutex at 0x2a96d8f2b8 created file srv0srv.c line 872, lock var 1
waiters flag 1
Warning: a long semaphore wait:
--Thread 1829017952 has waited at btr0sea.c line 1127 for 370.00 seconds the semaphore:
S-lock on RW-latch at 0x2a96d920b8 created in file btr0sea.c line 139
a writer (thread id 1799514464) has reserved it in mode  wait exclusive
number of readers 0, waiters flag 1
Last time read locked in file btr0sea.c line 746
Last time write locked in file btr0cur.c line 2184
Warning: a long semaphore wait:
--Thread 1598609760 has waited at btr0sea.c line 746 for 370.00 seconds the semaphore:
S-lock on RW-latch at 0x2a96d920b8 created in file btr0sea.c line 139
a writer (thread id 1799514464) has reserved it in mode  wait exclusive
number of readers 0, waiters flag 1
Last time read locked in file btr0sea.c line 746
Last time write locked in file btr0cur.c line 2184
Warning: a long semaphore wait:
--Thread 1515411808 has waited at srv0srv.c line 1952 for 370.00 seconds the semaphore:
Mutex at 0x2a96d8f2b8 created file srv0srv.c line 872, lock var 1
waiters flag 1
Warning: a long semaphore wait:
--Thread 1564289376 has waited at btr0sea.c line 1127 for 370.00 seconds the semaphore:
S-lock on RW-latch at 0x2a96d920b8 created in file btr0sea.c line 139
a writer (thread id 1799514464) has reserved it in mode  wait exclusive
number of readers 0, waiters flag 1
Last time read locked in file btr0sea.c line 746
Last time write locked in file btr0cur.c line 2184
Warning: a long semaphore wait:
--Thread 1597606240 has waited at btr0sea.c line 1383 for 370.00 seconds the semaphore:
X-lock on RW-latch at 0x2a96d920b8 created in file btr0sea.c line 139
a writer (thread id 1799514464) has reserved it in mode  wait exclusive
number of readers 0, waiters flag 1
Last time read locked in file btr0sea.c line 746
Last time write locked in file btr0cur.c line 2184
Warning: a long semaphore wait:
--Thread 1628715360 has waited at btr0sea.c line 1127 for 370.00 seconds the semaphore:
S-lock on RW-latch at 0x2a96d920b8 created in file btr0sea.c line 139
a writer (thread id 1799514464) has reserved it in mode  wait exclusive
number of readers 0, waiters flag 1
Last time read locked in file btr0sea.c line 746
Last time write locked in file btr0cur.c line 2184
Warning: a long semaphore wait:
--Thread 1539602784 has waited at btr0sea.c line 916 for 370.00 seconds the semaphore:
S-lock on RW-latch at 0x2a96d920b8 created in file btr0sea.c line 139
a writer (thread id 1799514464) has reserved it in mode  wait exclusive
number of readers 0, waiters flag 1
Last time read locked in file btr0sea.c line 746
Last time write locked in file btr0cur.c line 2184
Warning: a long semaphore wait:
--Thread 1598810464 has waited at btr0sea.c line 746 for 370.00 seconds the semaphore:
S-lock on RW-latch at 0x2a96d920b8 created in file btr0sea.c line 139
a writer (thread id 1799514464) has reserved it in mode  wait exclusive
number of readers 0, waiters flag 1
Last time read locked in file btr0sea.c line 746
Last time write locked in file btr0cur.c line 2184
Warning: a long semaphore wait:
--Thread 1795098976 has waited at btr0sea.c line 1127 for 370.00 seconds the semaphore:
S-lock on RW-latch at 0x2a96d920b8 created in file btr0sea.c line 139
a writer (thread id 1799514464) has reserved it in mode  wait exclusive
number of readers 0, waiters flag 1
Last time read locked in file btr0sea.c line 746
Last time write locked in file btr0cur.c line 2184
Warning: a long semaphore wait:
--Thread 1565895008 has waited at btr0sea.c line 916 for 370.00 seconds the semaphore:
S-lock on RW-latch at 0x2a96d920b8 created in file btr0sea.c line 139
a writer (thread id 1799514464) has reserved it in mode  wait exclusive
number of readers 0, waiters flag 1
Last time read locked in file btr0sea.c line 746
Last time write locked in file btr0cur.c line 2184
Warning: a long semaphore wait:
--Thread 1634335072 has waited at row0sel.c line 3326 for 370.00 seconds the semaphore:
S-lock on RW-latch at 0x2a96d920b8 created in file btr0sea.c line 139
a writer (thread id 1799514464) has reserved it in mode  wait exclusive
number of readers 0, waiters flag 1
Last time read locked in file btr0sea.c line 746
Last time write locked in file btr0cur.c line 2184
Warning: a long semaphore wait:
--Thread 1582954848 has waited at btr0sea.c line 1127 for 370.00 seconds the semaphore:
S-lock on RW-latch at 0x2a96d920b8 created in file btr0sea.c line 139
a writer (thread id 1799514464) has reserved it in mode  wait exclusive
number of readers 0, waiters flag 1
Last time read locked in file btr0sea.c line 746
Last time write locked in file btr0cur.c line 2184
Warning: a long semaphore wait:
--Thread 1548433760 has waited at btr0sea.c line 746 for 370.00 seconds the semaphore:
S-lock on RW-latch at 0x2a96d920b8 created in file btr0sea.c line 139
a writer (thread id 1799514464) has reserved it in mode  wait exclusive
number of readers 0, waiters flag 1
Last time read locked in file btr0sea.c line 746
Last time write locked in file btr0cur.c line 2184
Warning: a long semaphore wait:
--Thread 1640958304 has waited at btr0sea.c line 916 for 370.00 seconds the semaphore:
S-lock on RW-latch at 0x2a96d920b8 created in file btr0sea.c line 139
a writer (thread id 1799514464) has reserved it in mode  wait exclusive
number of readers 0, waiters flag 1
Last time read locked in file btr0sea.c line 746
Last time write locked in file btr0cur.c line 2184
Warning: a long semaphore wait:
--Thread 1642764640 has waited at trx0trx.c line 715 for 370.00 seconds the semaphore:
Mutex at 0x2a96d8f2b8 created file srv0srv.c line 872, lock var 1
waiters flag 1
Warning: a long semaphore wait:
--Thread 1602824544 has waited at trx0trx.c line 371 for 370.00 seconds the semaphore:
Mutex at 0x2a96d8f2b8 created file srv0srv.c line 872, lock var 1
waiters flag 1
Warning: a long semaphore wait:
--Thread 1643567456 has waited at trx0trx.c line 1609 for 370.00 seconds the semaphore:
Mutex at 0x2a96d8f2b8 created file srv0srv.c line 872, lock var 1
waiters flag 1
Warning: a long semaphore wait:
--Thread 1628916064 has waited at btr0sea.c line 1127 for 370.00 seconds the semaphore:
S-lock on RW-latch at 0x2a96d920b8 created in file btr0sea.c line 139
a writer (thread id 1799514464) has reserved it in mode  wait exclusive
number of readers 0, waiters flag 1
Last time read locked in file btr0sea.c line 746
Last time write locked in file btr0cur.c line 2184
###### Starts InnoDB Monitor for 30 secs to print diagnostic info:
Pending preads 0, pwrites 0
###### Diagnostic info printed to the standard error stream
Warning: a long semaphore wait:
--Thread 1808345440 has waited at btr0sea.c line 1127 for 402.00 seconds the semaphore:
S-lock on RW-latch at 0x2a96d920b8 created in file btr0sea.c line 139
a writer (thread id 1799514464) has reserved it in mode  wait exclusive
number of readers 0, waiters flag 1
Last time read locked in file btr0sea.c line 746
Last time write locked in file btr0cur.c line 2184
Warning: a long semaphore wait:
--Thread 1799514464 has waited at btr0sea.c line 489 for 402.00 seconds the semaphore:
X-lock on RW-latch at 0x2a96d920b8 created in file btr0sea.c line 139
a writer (thread id 1799514464) has reserved it in mode  wait exclusive
number of readers 0, waiters flag 1
Last time read locked in file btr0sea.c line 746
Last time write locked in file btr0cur.c line 2184
Warning: a long semaphore wait:
--Thread 1536391520 has waited at lock0lock.c line 3093 for 402.00 seconds the semaphore:
Mutex at 0x2a96d8f2b8 created file srv0srv.c line 872, lock var 1
waiters flag 1
Warning: a long semaphore wait:
--Thread 1829017952 has waited at btr0sea.c line 1127 for 402.00 seconds the semaphore:
S-lock on RW-latch at 0x2a96d920b8 created in file btr0sea.c line 139
a writer (thread id 1799514464) has reserved it in mode  wait exclusive
number of readers 0, waiters flag 1
Last time read locked in file btr0sea.c line 746
Last time write locked in file btr0cur.c line 2184
Warning: a long semaphore wait:
--Thread 1598609760 has waited at btr0sea.c line 746 for 402.00 seconds the semaphore:
S-lock on RW-latch at 0x2a96d920b8 created in file btr0sea.c line 139
a writer (thread id 1799514464) has reserved it in mode  wait exclusive
number of readers 0, waiters flag 1
Last time read locked in file btr0sea.c line 746
Last time write locked in file btr0cur.c line 2184
Warning: a long semaphore wait:
--Thread 1515411808 has waited at srv0srv.c line 1952 for 402.00 seconds the semaphore:
Mutex at 0x2a96d8f2b8 created file srv0srv.c line 872, lock var 1
waiters flag 1
Warning: a long semaphore wait:
--Thread 1564289376 has waited at btr0sea.c line 1127 for 402.00 seconds the semaphore:
S-lock on RW-latch at 0x2a96d920b8 created in file btr0sea.c line 139
a writer (thread id 1799514464) has reserved it in mode  wait exclusive
number of readers 0, waiters flag 1
Last time read locked in file btr0sea.c line 746
Last time write locked in file btr0cur.c line 2184
Warning: a long semaphore wait:
--Thread 1597606240 has waited at btr0sea.c line 1383 for 402.00 seconds the semaphore:
X-lock on RW-latch at 0x2a96d920b8 created in file btr0sea.c line 139
a writer (thread id 1799514464) has reserved it in mode  wait exclusive
number of readers 0, waiters flag 1
Last time read locked in file btr0sea.c line 746
Last time write locked in file btr0cur.c line 2184
Warning: a long semaphore wait:
--Thread 1628715360 has waited at btr0sea.c line 1127 for 402.00 seconds the semaphore:
S-lock on RW-latch at 0x2a96d920b8 created in file btr0sea.c line 139
a writer (thread id 1799514464) has reserved it in mode  wait exclusive
number of readers 0, waiters flag 1
Last time read locked in file btr0sea.c line 746
Last time write locked in file btr0cur.c line 2184
Warning: a long semaphore wait:
--Thread 1539602784 has waited at btr0sea.c line 916 for 402.00 seconds the semaphore:
S-lock on RW-latch at 0x2a96d920b8 created in file btr0sea.c line 139
a writer (thread id 1799514464) has reserved it in mode  wait exclusive
number of readers 0, waiters flag 1
Last time read locked in file btr0sea.c line 746
Last time write locked in file btr0cur.c line 2184
Warning: a long semaphore wait:
--Thread 1598810464 has waited at btr0sea.c line 746 for 402.00 seconds the semaphore:
S-lock on RW-latch at 0x2a96d920b8 created in file btr0sea.c line 139
a writer (thread id 1799514464) has reserved it in mode  wait exclusive
number of readers 0, waiters flag 1
Last time read locked in file btr0sea.c line 746
Last time write locked in file btr0cur.c line 2184
Warning: a long semaphore wait:
--Thread 1795098976 has waited at btr0sea.c line 1127 for 402.00 seconds the semaphore:
S-lock on RW-latch at 0x2a96d920b8 created in file btr0sea.c line 139
a writer (thread id 1799514464) has reserved it in mode  wait exclusive
number of readers 0, waiters flag 1
Last time read locked in file btr0sea.c line 746
Last time write locked in file btr0cur.c line 2184
Warning: a long semaphore wait:
--Thread 1565895008 has waited at btr0sea.c line 916 for 402.00 seconds the semaphore:
S-lock on RW-latch at 0x2a96d920b8 created in file btr0sea.c line 139
a writer (thread id 1799514464) has reserved it in mode  wait exclusive
number of readers 0, waiters flag 1
Last time read locked in file btr0sea.c line 746
Last time write locked in file btr0cur.c line 2184
Warning: a long semaphore wait:
--Thread 1634335072 has waited at row0sel.c line 3326 for 402.00 seconds the semaphore:
S-lock on RW-latch at 0x2a96d920b8 created in file btr0sea.c line 139
a writer (thread id 1799514464) has reserved it in mode  wait exclusive
number of readers 0, waiters flag 1
Last time read locked in file btr0sea.c line 746
Last time write locked in file btr0cur.c line 2184
Warning: a long semaphore wait:
--Thread 1582954848 has waited at btr0sea.c line 1127 for 402.00 seconds the semaphore:
S-lock on RW-latch at 0x2a96d920b8 created in file btr0sea.c line 139
a writer (thread id 1799514464) has reserved it in mode  wait exclusive
number of readers 0, waiters flag 1
Last time read locked in file btr0sea.c line 746
Last time write locked in file btr0cur.c line 2184
Warning: a long semaphore wait:
--Thread 1548433760 has waited at btr0sea.c line 746 for 402.00 seconds the semaphore:
S-lock on RW-latch at 0x2a96d920b8 created in file btr0sea.c line 139
a writer (thread id 1799514464) has reserved it in mode  wait exclusive
number of readers 0, waiters flag 1
Last time read locked in file btr0sea.c line 746
Last time write locked in file btr0cur.c line 2184
Warning: a long semaphore wait:
--Thread 1640958304 has waited at btr0sea.c line 916 for 402.00 seconds the semaphore:
S-lock on RW-latch at 0x2a96d920b8 created in file btr0sea.c line 139
a writer (thread id 1799514464) has reserved it in mode  wait exclusive
number of readers 0, waiters flag 1
Last time read locked in file btr0sea.c line 746
Last time write locked in file btr0cur.c line 2184
Warning: a long semaphore wait:
--Thread 1642764640 has waited at trx0trx.c line 715 for 402.00 seconds the semaphore:
Mutex at 0x2a96d8f2b8 created file srv0srv.c line 872, lock var 1
waiters flag 1
Warning: a long semaphore wait:
--Thread 1602824544 has waited at trx0trx.c line 371 for 402.00 seconds the semaphore:
Mutex at 0x2a96d8f2b8 created file srv0srv.c line 872, lock var 1
waiters flag 1
Warning: a long semaphore wait:
--Thread 1643567456 has waited at trx0trx.c line 1609 for 402.00 seconds the semaphore:
Mutex at 0x2a96d8f2b8 created file srv0srv.c line 872, lock var 1
waiters flag 1
Warning: a long semaphore wait:
--Thread 1628916064 has waited at btr0sea.c line 1127 for 402.00 seconds the semaphore:
S-lock on RW-latch at 0x2a96d920b8 created in file btr0sea.c line 139
a writer (thread id 1799514464) has reserved it in mode  wait exclusive
number of readers 0, waiters flag 1
Last time read locked in file btr0sea.c line 746
Last time write locked in file btr0cur.c line 2184
###### Starts InnoDB Monitor for 30 secs to print diagnostic info:
Pending preads 0, pwrites 0
###### Diagnostic info printed to the standard error stream
Warning: a long semaphore wait:
--Thread 1808345440 has waited at btr0sea.c line 1127 for 434.00 seconds the semaphore:
S-lock on RW-latch at 0x2a96d920b8 created in file btr0sea.c line 139
a writer (thread id 1799514464) has reserved it in mode  wait exclusive
number of readers 0, waiters flag 1
Last time read locked in file btr0sea.c line 746
Last time write locked in file btr0cur.c line 2184
Warning: a long semaphore wait:
--Thread 1799514464 has waited at btr0sea.c line 489 for 434.00 seconds the semaphore:
X-lock on RW-latch at 0x2a96d920b8 created in file btr0sea.c line 139
a writer (thread id 1799514464) has reserved it in mode  wait exclusive
number of readers 0, waiters flag 1
Last time read locked in file btr0sea.c line 746
Last time write locked in file btr0cur.c line 2184
Warning: a long semaphore wait:
--Thread 1536391520 has waited at lock0lock.c line 3093 for 434.00 seconds the semaphore:
Mutex at 0x2a96d8f2b8 created file srv0srv.c line 872, lock var 1
waiters flag 1
Warning: a long semaphore wait:
--Thread 1829017952 has waited at btr0sea.c line 1127 for 434.00 seconds the semaphore:
S-lock on RW-latch at 0x2a96d920b8 created in file btr0sea.c line 139
a writer (thread id 1799514464) has reserved it in mode  wait exclusive
number of readers 0, waiters flag 1
Last time read locked in file btr0sea.c line 746
Last time write locked in file btr0cur.c line 2184
Warning: a long semaphore wait:
--Thread 1598609760 has waited at btr0sea.c line 746 for 434.00 seconds the semaphore:
S-lock on RW-latch at 0x2a96d920b8 created in file btr0sea.c line 139
a writer (thread id 1799514464) has reserved it in mode  wait exclusive
number of readers 0, waiters flag 1
Last time read locked in file btr0sea.c line 746
Last time write locked in file btr0cur.c line 2184
Warning: a long semaphore wait:
--Thread 1515411808 has waited at srv0srv.c line 1952 for 434.00 seconds the semaphore:
Mutex at 0x2a96d8f2b8 created file srv0srv.c line 872, lock var 1
waiters flag 1
Warning: a long semaphore wait:
--Thread 1564289376 has waited at btr0sea.c line 1127 for 434.00 seconds the semaphore:
S-lock on RW-latch at 0x2a96d920b8 created in file btr0sea.c line 139
a writer (thread id 1799514464) has reserved it in mode  wait exclusive
number of readers 0, waiters flag 1
Last time read locked in file btr0sea.c line 746
Last time write locked in file btr0cur.c line 2184
Warning: a long semaphore wait:
--Thread 1597606240 has waited at btr0sea.c line 1383 for 434.00 seconds the semaphore:
X-lock on RW-latch at 0x2a96d920b8 created in file btr0sea.c line 139
a writer (thread id 1799514464) has reserved it in mode  wait exclusive
number of readers 0, waiters flag 1
Last time read locked in file btr0sea.c line 746
Last time write locked in file btr0cur.c line 2184
Warning: a long semaphore wait:
--Thread 1628715360 has waited at btr0sea.c line 1127 for 434.00 seconds the semaphore:
S-lock on RW-latch at 0x2a96d920b8 created in file btr0sea.c line 139
a writer (thread id 1799514464) has reserved it in mode  wait exclusive
number of readers 0, waiters flag 1
Last time read locked in file btr0sea.c line 746
Last time write locked in file btr0cur.c line 2184
Warning: a long semaphore wait:
--Thread 1539602784 has waited at btr0sea.c line 916 for 434.00 seconds the semaphore:
S-lock on RW-latch at 0x2a96d920b8 created in file btr0sea.c line 139
a writer (thread id 1799514464) has reserved it in mode  wait exclusive
number of readers 0, waiters flag 1
Last time read locked in file btr0sea.c line 746
Last time write locked in file btr0cur.c line 2184
Warning: a long semaphore wait:
--Thread 1598810464 has waited at btr0sea.c line 746 for 434.00 seconds the semaphore:
S-lock on RW-latch at 0x2a96d920b8 created in file btr0sea.c line 139
a writer (thread id 1799514464) has reserved it in mode  wait exclusive
number of readers 0, waiters flag 1
Last time read locked in file btr0sea.c line 746
Last time write locked in file btr0cur.c line 2184
Warning: a long semaphore wait:
--Thread 1795098976 has waited at btr0sea.c line 1127 for 434.00 seconds the semaphore:
S-lock on RW-latch at 0x2a96d920b8 created in file btr0sea.c line 139
a writer (thread id 1799514464) has reserved it in mode  wait exclusive
number of readers 0, waiters flag 1
Last time read locked in file btr0sea.c line 746
Last time write locked in file btr0cur.c line 2184
Warning: a long semaphore wait:
--Thread 1565895008 has waited at btr0sea.c line 916 for 434.00 seconds the semaphore:
S-lock on RW-latch at 0x2a96d920b8 created in file btr0sea.c line 139
a writer (thread id 1799514464) has reserved it in mode  wait exclusive
number of readers 0, waiters flag 1
Last time read locked in file btr0sea.c line 746
Last time write locked in file btr0cur.c line 2184
Warning: a long semaphore wait:
--Thread 1634335072 has waited at row0sel.c line 3326 for 434.00 seconds the semaphore:
S-lock on RW-latch at 0x2a96d920b8 created in file btr0sea.c line 139
a writer (thread id 1799514464) has reserved it in mode  wait exclusive
number of readers 0, waiters flag 1
Last time read locked in file btr0sea.c line 746
Last time write locked in file btr0cur.c line 2184
Warning: a long semaphore wait:
--Thread 1582954848 has waited at btr0sea.c line 1127 for 434.00 seconds the semaphore:
S-lock on RW-latch at 0x2a96d920b8 created in file btr0sea.c line 139
a writer (thread id 1799514464) has reserved it in mode  wait exclusive
number of readers 0, waiters flag 1
Last time read locked in file btr0sea.c line 746
Last time write locked in file btr0cur.c line 2184
Warning: a long semaphore wait:
--Thread 1548433760 has waited at btr0sea.c line 746 for 434.00 seconds the semaphore:
S-lock on RW-latch at 0x2a96d920b8 created in file btr0sea.c line 139
a writer (thread id 1799514464) has reserved it in mode  wait exclusive
number of readers 0, waiters flag 1
Last time read locked in file btr0sea.c line 746
Last time write locked in file btr0cur.c line 2184
Warning: a long semaphore wait:
--Thread 1640958304 has waited at btr0sea.c line 916 for 434.00 seconds the semaphore:
S-lock on RW-latch at 0x2a96d920b8 created in file btr0sea.c line 139
a writer (thread id 1799514464) has reserved it in mode  wait exclusive
number of readers 0, waiters flag 1
Last time read locked in file btr0sea.c line 746
Last time write locked in file btr0cur.c line 2184
Warning: a long semaphore wait:
--Thread 1642764640 has waited at trx0trx.c line 715 for 434.00 seconds the semaphore:
Mutex at 0x2a96d8f2b8 created file srv0srv.c line 872, lock var 1
waiters flag 1
Warning: a long semaphore wait:
--Thread 1602824544 has waited at trx0trx.c line 371 for 434.00 seconds the semaphore:
Mutex at 0x2a96d8f2b8 created file srv0srv.c line 872, lock var 1
waiters flag 1
Warning: a long semaphore wait:
--Thread 1643567456 has waited at trx0trx.c line 1609 for 434.00 seconds the semaphore:
Mutex at 0x2a96d8f2b8 created file srv0srv.c line 872, lock var 1
waiters flag 1
Warning: a long semaphore wait:
--Thread 1628916064 has waited at btr0sea.c line 1127 for 434.00 seconds the semaphore:
S-lock on RW-latch at 0x2a96d920b8 created in file btr0sea.c line 139
a writer (thread id 1799514464) has reserved it in mode  wait exclusive
number of readers 0, waiters flag 1
Last time read locked in file btr0sea.c line 746
Last time write locked in file btr0cur.c line 2184
###### Starts InnoDB Monitor for 30 secs to print diagnostic info:
Pending preads 0, pwrites 0
###### Diagnostic info printed to the standard error stream
Warning: a long semaphore wait:
--Thread 1808345440 has waited at btr0sea.c line 1127 for 466.00 seconds the semaphore:
S-lock on RW-latch at 0x2a96d920b8 created in file btr0sea.c line 139
a writer (thread id 1799514464) has reserved it in mode  wait exclusive
number of readers 0, waiters flag 1
Last time read locked in file btr0sea.c line 746
Last time write locked in file btr0cur.c line 2184
Warning: a long semaphore wait:
--Thread 1799514464 has waited at btr0sea.c line 489 for 466.00 seconds the semaphore:
X-lock on RW-latch at 0x2a96d920b8 created in file btr0sea.c line 139
a writer (thread id 1799514464) has reserved it in mode  wait exclusive
number of readers 0, waiters flag 1
Last time read locked in file btr0sea.c line 746
Last time write locked in file btr0cur.c line 2184
Warning: a long semaphore wait:
--Thread 1536391520 has waited at lock0lock.c line 3093 for 466.00 seconds the semaphore:
Mutex at 0x2a96d8f2b8 created file srv0srv.c line 872, lock var 1
waiters flag 1
Warning: a long semaphore wait:
--Thread 1829017952 has waited at btr0sea.c line 1127 for 466.00 seconds the semaphore:
S-lock on RW-latch at 0x2a96d920b8 created in file btr0sea.c line 139
a writer (thread id 1799514464) has reserved it in mode  wait exclusive
number of readers 0, waiters flag 1
Last time read locked in file btr0sea.c line 746
Last time write locked in file btr0cur.c line 2184
Warning: a long semaphore wait:
--Thread 1598609760 has waited at btr0sea.c line 746 for 466.00 seconds the semaphore:
S-lock on RW-latch at 0x2a96d920b8 created in file btr0sea.c line 139
a writer (thread id 1799514464) has reserved it in mode  wait exclusive
number of readers 0, waiters flag 1
Last time read locked in file btr0sea.c line 746
Last time write locked in file btr0cur.c line 2184
Warning: a long semaphore wait:
--Thread 1515411808 has waited at srv0srv.c line 1952 for 466.00 seconds the semaphore:
Mutex at 0x2a96d8f2b8 created file srv0srv.c line 872, lock var 1
waiters flag 1
Warning: a long semaphore wait:
--Thread 1564289376 has waited at btr0sea.c line 1127 for 466.00 seconds the semaphore:
S-lock on RW-latch at 0x2a96d920b8 created in file btr0sea.c line 139
a writer (thread id 1799514464) has reserved it in mode  wait exclusive
number of readers 0, waiters flag 1
Last time read locked in file btr0sea.c line 746
Last time write locked in file btr0cur.c line 2184
Warning: a long semaphore wait:
--Thread 1597606240 has waited at btr0sea.c line 1383 for 466.00 seconds the semaphore:
X-lock on RW-latch at 0x2a96d920b8 created in file btr0sea.c line 139
a writer (thread id 1799514464) has reserved it in mode  wait exclusive
number of readers 0, waiters flag 1
Last time read locked in file btr0sea.c line 746
Last time write locked in file btr0cur.c line 2184
Warning: a long semaphore wait:
--Thread 1628715360 has waited at btr0sea.c line 1127 for 466.00 seconds the semaphore:
S-lock on RW-latch at 0x2a96d920b8 created in file btr0sea.c line 139
a writer (thread id 1799514464) has reserved it in mode  wait exclusive
number of readers 0, waiters flag 1
Last time read locked in file btr0sea.c line 746
Last time write locked in file btr0cur.c line 2184
Warning: a long semaphore wait:
--Thread 1539602784 has waited at btr0sea.c line 916 for 466.00 seconds the semaphore:
S-lock on RW-latch at 0x2a96d920b8 created in file btr0sea.c line 139
a writer (thread id 1799514464) has reserved it in mode  wait exclusive
number of readers 0, waiters flag 1
Last time read locked in file btr0sea.c line 746
Last time write locked in file btr0cur.c line 2184
Warning: a long semaphore wait:
--Thread 1598810464 has waited at btr0sea.c line 746 for 466.00 seconds the semaphore:
S-lock on RW-latch at 0x2a96d920b8 created in file btr0sea.c line 139
a writer (thread id 1799514464) has reserved it in mode  wait exclusive
number of readers 0, waiters flag 1
Last time read locked in file btr0sea.c line 746
Last time write locked in file btr0cur.c line 2184
Warning: a long semaphore wait:
--Thread 1795098976 has waited at btr0sea.c line 1127 for 466.00 seconds the semaphore:
S-lock on RW-latch at 0x2a96d920b8 created in file btr0sea.c line 139
a writer (thread id 1799514464) has reserved it in mode  wait exclusive
number of readers 0, waiters flag 1
Last time read locked in file btr0sea.c line 746
Last time write locked in file btr0cur.c line 2184
Warning: a long semaphore wait:
--Thread 1565895008 has waited at btr0sea.c line 916 for 466.00 seconds the semaphore:
S-lock on RW-latch at 0x2a96d920b8 created in file btr0sea.c line 139
a writer (thread id 1799514464) has reserved it in mode  wait exclusive
number of readers 0, waiters flag 1
Last time read locked in file btr0sea.c line 746
Last time write locked in file btr0cur.c line 2184
Warning: a long semaphore wait:
--Thread 1634335072 has waited at row0sel.c line 3326 for 466.00 seconds the semaphore:
S-lock on RW-latch at 0x2a96d920b8 created in file btr0sea.c line 139
a writer (thread id 1799514464) has reserved it in mode  wait exclusive
number of readers 0, waiters flag 1
Last time read locked in file btr0sea.c line 746
Last time write locked in file btr0cur.c line 2184
Warning: a long semaphore wait:
--Thread 1582954848 has waited at btr0sea.c line 1127 for 466.00 seconds the semaphore:
S-lock on RW-latch at 0x2a96d920b8 created in file btr0sea.c line 139
a writer (thread id 1799514464) has reserved it in mode  wait exclusive
number of readers 0, waiters flag 1
Last time read locked in file btr0sea.c line 746
Last time write locked in file btr0cur.c line 2184
Warning: a long semaphore wait:
--Thread 1548433760 has waited at btr0sea.c line 746 for 466.00 seconds the semaphore:
S-lock on RW-latch at 0x2a96d920b8 created in file btr0sea.c line 139
a writer (thread id 1799514464) has reserved it in mode  wait exclusive
number of readers 0, waiters flag 1
Last time read locked in file btr0sea.c line 746
Last time write locked in file btr0cur.c line 2184
Warning: a long semaphore wait:
--Thread 1640958304 has waited at btr0sea.c line 916 for 466.00 seconds the semaphore:
S-lock on RW-latch at 0x2a96d920b8 created in file btr0sea.c line 139
a writer (thread id 1799514464) has reserved it in mode  wait exclusive
number of readers 0, waiters flag 1
Last time read locked in file btr0sea.c line 746
Last time write locked in file btr0cur.c line 2184
Warning: a long semaphore wait:
--Thread 1642764640 has waited at trx0trx.c line 715 for 466.00 seconds the semaphore:
Mutex at 0x2a96d8f2b8 created file srv0srv.c line 872, lock var 1
waiters flag 1
Warning: a long semaphore wait:
--Thread 1602824544 has waited at trx0trx.c line 371 for 466.00 seconds the semaphore:
Mutex at 0x2a96d8f2b8 created file srv0srv.c line 872, lock var 1
waiters flag 1
Warning: a long semaphore wait:
--Thread 1643567456 has waited at trx0trx.c line 1609 for 466.00 seconds the semaphore:
Mutex at 0x2a96d8f2b8 created file srv0srv.c line 872, lock var 1
waiters flag 1
Warning: a long semaphore wait:
--Thread 1628916064 has waited at btr0sea.c line 1127 for 466.00 seconds the semaphore:
S-lock on RW-latch at 0x2a96d920b8 created in file btr0sea.c line 139
a writer (thread id 1799514464) has reserved it in mode  wait exclusive
number of readers 0, waiters flag 1
Last time read locked in file btr0sea.c line 746
Last time write locked in file btr0cur.c line 2184
###### Starts InnoDB Monitor for 30 secs to print diagnostic info:
Pending preads 0, pwrites 0
###### Diagnostic info printed to the standard error stream
Warning: a long semaphore wait:
--Thread 1808345440 has waited at btr0sea.c line 1127 for 498.00 seconds the semaphore:
S-lock on RW-latch at 0x2a96d920b8 created in file btr0sea.c line 139
a writer (thread id 1799514464) has reserved it in mode  wait exclusive
number of readers 0, waiters flag 1
Last time read locked in file btr0sea.c line 746
Last time write locked in file btr0cur.c line 2184
Warning: a long semaphore wait:
--Thread 1799514464 has waited at btr0sea.c line 489 for 498.00 seconds the semaphore:
X-lock on RW-latch at 0x2a96d920b8 created in file btr0sea.c line 139
a writer (thread id 1799514464) has reserved it in mode  wait exclusive
number of readers 0, waiters flag 1
Last time read locked in file btr0sea.c line 746
Last time write locked in file btr0cur.c line 2184
Warning: a long semaphore wait:
--Thread 1536391520 has waited at lock0lock.c line 3093 for 498.00 seconds the semaphore:
Mutex at 0x2a96d8f2b8 created file srv0srv.c line 872, lock var 1
waiters flag 1
Warning: a long semaphore wait:
--Thread 1829017952 has waited at btr0sea.c line 1127 for 498.00 seconds the semaphore:
S-lock on RW-latch at 0x2a96d920b8 created in file btr0sea.c line 139
a writer (thread id 1799514464) has reserved it in mode  wait exclusive
number of readers 0, waiters flag 1
Last time read locked in file btr0sea.c line 746
Last time write locked in file btr0cur.c line 2184
Warning: a long semaphore wait:
--Thread 1598609760 has waited at btr0sea.c line 746 for 498.00 seconds the semaphore:
S-lock on RW-latch at 0x2a96d920b8 created in file btr0sea.c line 139
a writer (thread id 1799514464) has reserved it in mode  wait exclusive
number of readers 0, waiters flag 1
Last time read locked in file btr0sea.c line 746
Last time write locked in file btr0cur.c line 2184
Warning: a long semaphore wait:
--Thread 1515411808 has waited at srv0srv.c line 1952 for 498.00 seconds the semaphore:
Mutex at 0x2a96d8f2b8 created file srv0srv.c line 872, lock var 1
waiters flag 1
Warning: a long semaphore wait:
--Thread 1564289376 has waited at btr0sea.c line 1127 for 498.00 seconds the semaphore:
S-lock on RW-latch at 0x2a96d920b8 created in file btr0sea.c line 139
a writer (thread id 1799514464) has reserved it in mode  wait exclusive
number of readers 0, waiters flag 1
Last time read locked in file btr0sea.c line 746
Last time write locked in file btr0cur.c line 2184
Warning: a long semaphore wait:
--Thread 1597606240 has waited at btr0sea.c line 1383 for 498.00 seconds the semaphore:
X-lock on RW-latch at 0x2a96d920b8 created in file btr0sea.c line 139
a writer (thread id 1799514464) has reserved it in mode  wait exclusive
number of readers 0, waiters flag 1
Last time read locked in file btr0sea.c line 746
Last time write locked in file btr0cur.c line 2184
Warning: a long semaphore wait:
--Thread 1628715360 has waited at btr0sea.c line 1127 for 498.00 seconds the semaphore:
S-lock on RW-latch at 0x2a96d920b8 created in file btr0sea.c line 139
a writer (thread id 1799514464) has reserved it in mode  wait exclusive
number of readers 0, waiters flag 1
Last time read locked in file btr0sea.c line 746
Last time write locked in file btr0cur.c line 2184
Warning: a long semaphore wait:
--Thread 1539602784 has waited at btr0sea.c line 916 for 498.00 seconds the semaphore:
S-lock on RW-latch at 0x2a96d920b8 created in file btr0sea.c line 139
a writer (thread id 1799514464) has reserved it in mode  wait exclusive
number of readers 0, waiters flag 1
Last time read locked in file btr0sea.c line 746
Last time write locked in file btr0cur.c line 2184
Warning: a long semaphore wait:
--Thread 1598810464 has waited at btr0sea.c line 746 for 498.00 seconds the semaphore:
S-lock on RW-latch at 0x2a96d920b8 created in file btr0sea.c line 139
a writer (thread id 1799514464) has reserved it in mode  wait exclusive
number of readers 0, waiters flag 1
Last time read locked in file btr0sea.c line 746
Last time write locked in file btr0cur.c line 2184
Warning: a long semaphore wait:
--Thread 1795098976 has waited at btr0sea.c line 1127 for 498.00 seconds the semaphore:
S-lock on RW-latch at 0x2a96d920b8 created in file btr0sea.c line 139
a writer (thread id 1799514464) has reserved it in mode  wait exclusive
number of readers 0, waiters flag 1
Last time read locked in file btr0sea.c line 746
Last time write locked in file btr0cur.c line 2184
Warning: a long semaphore wait:
--Thread 1565895008 has waited at btr0sea.c line 916 for 498.00 seconds the semaphore:
S-lock on RW-latch at 0x2a96d920b8 created in file btr0sea.c line 139
a writer (thread id 1799514464) has reserved it in mode  wait exclusive
number of readers 0, waiters flag 1
Last time read locked in file btr0sea.c line 746
Last time write locked in file btr0cur.c line 2184
Warning: a long semaphore wait:
--Thread 1634335072 has waited at row0sel.c line 3326 for 498.00 seconds the semaphore:
S-lock on RW-latch at 0x2a96d920b8 created in file btr0sea.c line 139
a writer (thread id 1799514464) has reserved it in mode  wait exclusive
number of readers 0, waiters flag 1
Last time read locked in file btr0sea.c line 746
Last time write locked in file btr0cur.c line 2184
Warning: a long semaphore wait:
--Thread 1582954848 has waited at btr0sea.c line 1127 for 498.00 seconds the semaphore:
S-lock on RW-latch at 0x2a96d920b8 created in file btr0sea.c line 139
a writer (thread id 1799514464) has reserved it in mode  wait exclusive
number of readers 0, waiters flag 1
Last time read locked in file btr0sea.c line 746
Last time write locked in file btr0cur.c line 2184
Warning: a long semaphore wait:
--Thread 1548433760 has waited at btr0sea.c line 746 for 498.00 seconds the semaphore:
S-lock on RW-latch at 0x2a96d920b8 created in file btr0sea.c line 139
a writer (thread id 1799514464) has reserved it in mode  wait exclusive
number of readers 0, waiters flag 1
Last time read locked in file btr0sea.c line 746
Last time write locked in file btr0cur.c line 2184
Warning: a long semaphore wait:
--Thread 1640958304 has waited at btr0sea.c line 916 for 498.00 seconds the semaphore:
S-lock on RW-latch at 0x2a96d920b8 created in file btr0sea.c line 139
a writer (thread id 1799514464) has reserved it in mode  wait exclusive
number of readers 0, waiters flag 1
Last time read locked in file btr0sea.c line 746
Last time write locked in file btr0cur.c line 2184
Warning: a long semaphore wait:
--Thread 1642764640 has waited at trx0trx.c line 715 for 498.00 seconds the semaphore:
Mutex at 0x2a96d8f2b8 created file srv0srv.c line 872, lock var 1
waiters flag 1
Warning: a long semaphore wait:
--Thread 1602824544 has waited at trx0trx.c line 371 for 498.00 seconds the semaphore:
Mutex at 0x2a96d8f2b8 created file srv0srv.c line 872, lock var 1
waiters flag 1
Warning: a long semaphore wait:
--Thread 1643567456 has waited at trx0trx.c line 1609 for 498.00 seconds the semaphore:
Mutex at 0x2a96d8f2b8 created file srv0srv.c line 872, lock var 1
waiters flag 1
Warning: a long semaphore wait:
--Thread 1628916064 has waited at btr0sea.c line 1127 for 498.00 seconds the semaphore:
S-lock on RW-latch at 0x2a96d920b8 created in file btr0sea.c line 139
a writer (thread id 1799514464) has reserved it in mode  wait exclusive
number of readers 0, waiters flag 1
Last time read locked in file btr0sea.c line 746
Last time write locked in file btr0cur.c line 2184
###### Starts InnoDB Monitor for 30 secs to print diagnostic info:
Pending preads 0, pwrites 0
###### Diagnostic info printed to the standard error stream
Warning: a long semaphore wait:
--Thread 1808345440 has waited at btr0sea.c line 1127 for 530.00 seconds the semaphore:
S-lock on RW-latch at 0x2a96d920b8 created in file btr0sea.c line 139
a writer (thread id 1799514464) has reserved it in mode  wait exclusive
number of readers 0, waiters flag 1
Last time read locked in file btr0sea.c line 746
Last time write locked in file btr0cur.c line 2184
Warning: a long semaphore wait:
--Thread 1799514464 has waited at btr0sea.c line 489 for 530.00 seconds the semaphore:
X-lock on RW-latch at 0x2a96d920b8 created in file btr0sea.c line 139
a writer (thread id 1799514464) has reserved it in mode  wait exclusive
number of readers 0, waiters flag 1
Last time read locked in file btr0sea.c line 746
Last time write locked in file btr0cur.c line 2184
Warning: a long semaphore wait:
--Thread 1536391520 has waited at lock0lock.c line 3093 for 530.00 seconds the semaphore:
Mutex at 0x2a96d8f2b8 created file srv0srv.c line 872, lock var 1
waiters flag 1
Warning: a long semaphore wait:
--Thread 1829017952 has waited at btr0sea.c line 1127 for 530.00 seconds the semaphore:
S-lock on RW-latch at 0x2a96d920b8 created in file btr0sea.c line 139
a writer (thread id 1799514464) has reserved it in mode  wait exclusive
number of readers 0, waiters flag 1
Last time read locked in file btr0sea.c line 746
Last time write locked in file btr0cur.c line 2184
Warning: a long semaphore wait:
--Thread 1598609760 has waited at btr0sea.c line 746 for 530.00 seconds the semaphore:
S-lock on RW-latch at 0x2a96d920b8 created in file btr0sea.c line 139
a writer (thread id 1799514464) has reserved it in mode  wait exclusive
number of readers 0, waiters flag 1
Last time read locked in file btr0sea.c line 746
Last time write locked in file btr0cur.c line 2184
Warning: a long semaphore wait:
--Thread 1515411808 has waited at srv0srv.c line 1952 for 530.00 seconds the semaphore:
Mutex at 0x2a96d8f2b8 created file srv0srv.c line 872, lock var 1
waiters flag 1
Warning: a long semaphore wait:
--Thread 1564289376 has waited at btr0sea.c line 1127 for 530.00 seconds the semaphore:
S-lock on RW-latch at 0x2a96d920b8 created in file btr0sea.c line 139
a writer (thread id 1799514464) has reserved it in mode  wait exclusive
number of readers 0, waiters flag 1
Last time read locked in file btr0sea.c line 746
Last time write locked in file btr0cur.c line 2184
Warning: a long semaphore wait:
--Thread 1597606240 has waited at btr0sea.c line 1383 for 530.00 seconds the semaphore:
X-lock on RW-latch at 0x2a96d920b8 created in file btr0sea.c line 139
a writer (thread id 1799514464) has reserved it in mode  wait exclusive
number of readers 0, waiters flag 1
Last time read locked in file btr0sea.c line 746
Last time write locked in file btr0cur.c line 2184
Warning: a long semaphore wait:
--Thread 1628715360 has waited at btr0sea.c line 1127 for 530.00 seconds the semaphore:
S-lock on RW-latch at 0x2a96d920b8 created in file btr0sea.c line 139
a writer (thread id 1799514464) has reserved it in mode  wait exclusive
number of readers 0, waiters flag 1
Last time read locked in file btr0sea.c line 746
Last time write locked in file btr0cur.c line 2184
Warning: a long semaphore wait:
--Thread 1539602784 has waited at btr0sea.c line 916 for 530.00 seconds the semaphore:
S-lock on RW-latch at 0x2a96d920b8 created in file btr0sea.c line 139
a writer (thread id 1799514464) has reserved it in mode  wait exclusive
number of readers 0, waiters flag 1
Last time read locked in file btr0sea.c line 746
Last time write locked in file btr0cur.c line 2184
Warning: a long semaphore wait:
--Thread 1598810464 has waited at btr0sea.c line 746 for 530.00 seconds the semaphore:
S-lock on RW-latch at 0x2a96d920b8 created in file btr0sea.c line 139
a writer (thread id 1799514464) has reserved it in mode  wait exclusive
number of readers 0, waiters flag 1
Last time read locked in file btr0sea.c line 746
Last time write locked in file btr0cur.c line 2184
Warning: a long semaphore wait:
--Thread 1795098976 has waited at btr0sea.c line 1127 for 530.00 seconds the semaphore:
S-lock on RW-latch at 0x2a96d920b8 created in file btr0sea.c line 139
a writer (thread id 1799514464) has reserved it in mode  wait exclusive
number of readers 0, waiters flag 1
Last time read locked in file btr0sea.c line 746
Last time write locked in file btr0cur.c line 2184
Warning: a long semaphore wait:
--Thread 1565895008 has waited at btr0sea.c line 916 for 530.00 seconds the semaphore:
S-lock on RW-latch at 0x2a96d920b8 created in file btr0sea.c line 139
a writer (thread id 1799514464) has reserved it in mode  wait exclusive
number of readers 0, waiters flag 1
Last time read locked in file btr0sea.c line 746
Last time write locked in file btr0cur.c line 2184
Warning: a long semaphore wait:
--Thread 1634335072 has waited at row0sel.c line 3326 for 530.00 seconds the semaphore:
S-lock on RW-latch at 0x2a96d920b8 created in file btr0sea.c line 139
a writer (thread id 1799514464) has reserved it in mode  wait exclusive
number of readers 0, waiters flag 1
Last time read locked in file btr0sea.c line 746
Last time write locked in file btr0cur.c line 2184
Warning: a long semaphore wait:
--Thread 1582954848 has waited at btr0sea.c line 1127 for 530.00 seconds the semaphore:
S-lock on RW-latch at 0x2a96d920b8 created in file btr0sea.c line 139
a writer (thread id 1799514464) has reserved it in mode  wait exclusive
number of readers 0, waiters flag 1
Last time read locked in file btr0sea.c line 746
Last time write locked in file btr0cur.c line 2184
Warning: a long semaphore wait:
--Thread 1548433760 has waited at btr0sea.c line 746 for 530.00 seconds the semaphore:
S-lock on RW-latch at 0x2a96d920b8 created in file btr0sea.c line 139
a writer (thread id 1799514464) has reserved it in mode  wait exclusive
number of readers 0, waiters flag 1
Last time read locked in file btr0sea.c line 746
Last time write locked in file btr0cur.c line 2184
Warning: a long semaphore wait:
--Thread 1640958304 has waited at btr0sea.c line 916 for 530.00 seconds the semaphore:
S-lock on RW-latch at 0x2a96d920b8 created in file btr0sea.c line 139
a writer (thread id 1799514464) has reserved it in mode  wait exclusive
number of readers 0, waiters flag 1
Last time read locked in file btr0sea.c line 746
Last time write locked in file btr0cur.c line 2184
Warning: a long semaphore wait:
--Thread 1642764640 has waited at trx0trx.c line 715 for 530.00 seconds the semaphore:
Mutex at 0x2a96d8f2b8 created file srv0srv.c line 872, lock var 1
waiters flag 1
Warning: a long semaphore wait:
--Thread 1602824544 has waited at trx0trx.c line 371 for 530.00 seconds the semaphore:
Mutex at 0x2a96d8f2b8 created file srv0srv.c line 872, lock var 1
waiters flag 1
Warning: a long semaphore wait:
--Thread 1643567456 has waited at trx0trx.c line 1609 for 530.00 seconds the semaphore:
Mutex at 0x2a96d8f2b8 created file srv0srv.c line 872, lock var 1
waiters flag 1
Warning: a long semaphore wait:
--Thread 1628916064 has waited at btr0sea.c line 1127 for 530.00 seconds the semaphore:
S-lock on RW-latch at 0x2a96d920b8 created in file btr0sea.c line 139
a writer (thread id 1799514464) has reserved it in mode  wait exclusive
number of readers 0, waiters flag 1
Last time read locked in file btr0sea.c line 746
Last time write locked in file btr0cur.c line 2184
###### Starts InnoDB Monitor for 30 secs to print diagnostic info:
Pending preads 0, pwrites 0
###### Diagnostic info printed to the standard error stream
Warning: a long semaphore wait:
--Thread 1808345440 has waited at btr0sea.c line 1127 for 562.00 seconds the semaphore:
S-lock on RW-latch at 0x2a96d920b8 created in file btr0sea.c line 139
a writer (thread id 1799514464) has reserved it in mode  wait exclusive
number of readers 0, waiters flag 1
Last time read locked in file btr0sea.c line 746
Last time write locked in file btr0cur.c line 2184
Warning: a long semaphore wait:
--Thread 1799514464 has waited at btr0sea.c line 489 for 562.00 seconds the semaphore:
X-lock on RW-latch at 0x2a96d920b8 created in file btr0sea.c line 139
a writer (thread id 1799514464) has reserved it in mode  wait exclusive
number of readers 0, waiters flag 1
Last time read locked in file btr0sea.c line 746
Last time write locked in file btr0cur.c line 2184
Warning: a long semaphore wait:
--Thread 1536391520 has waited at lock0lock.c line 3093 for 562.00 seconds the semaphore:
Mutex at 0x2a96d8f2b8 created file srv0srv.c line 872, lock var 1
waiters flag 1
Warning: a long semaphore wait:
--Thread 1829017952 has waited at btr0sea.c line 1127 for 562.00 seconds the semaphore:
S-lock on RW-latch at 0x2a96d920b8 created in file btr0sea.c line 139
a writer (thread id 1799514464) has reserved it in mode  wait exclusive
number of readers 0, waiters flag 1
Last time read locked in file btr0sea.c line 746
Last time write locked in file btr0cur.c line 2184
Warning: a long semaphore wait:
--Thread 1598609760 has waited at btr0sea.c line 746 for 562.00 seconds the semaphore:
S-lock on RW-latch at 0x2a96d920b8 created in file btr0sea.c line 139
a writer (thread id 1799514464) has reserved it in mode  wait exclusive
number of readers 0, waiters flag 1
Last time read locked in file btr0sea.c line 746
Last time write locked in file btr0cur.c line 2184
Warning: a long semaphore wait:
--Thread 1515411808 has waited at srv0srv.c line 1952 for 562.00 seconds the semaphore:
Mutex at 0x2a96d8f2b8 created file srv0srv.c line 872, lock var 1
waiters flag 1
Warning: a long semaphore wait:
--Thread 1564289376 has waited at btr0sea.c line 1127 for 562.00 seconds the semaphore:
S-lock on RW-latch at 0x2a96d920b8 created in file btr0sea.c line 139
a writer (thread id 1799514464) has reserved it in mode  wait exclusive
number of readers 0, waiters flag 1
Last time read locked in file btr0sea.c line 746
Last time write locked in file btr0cur.c line 2184
Warning: a long semaphore wait:
--Thread 1597606240 has waited at btr0sea.c line 1383 for 562.00 seconds the semaphore:
X-lock on RW-latch at 0x2a96d920b8 created in file btr0sea.c line 139
a writer (thread id 1799514464) has reserved it in mode  wait exclusive
number of readers 0, waiters flag 1
Last time read locked in file btr0sea.c line 746
Last time write locked in file btr0cur.c line 2184
Warning: a long semaphore wait:
--Thread 1628715360 has waited at btr0sea.c line 1127 for 562.00 seconds the semaphore:
S-lock on RW-latch at 0x2a96d920b8 created in file btr0sea.c line 139
a writer (thread id 1799514464) has reserved it in mode  wait exclusive
number of readers 0, waiters flag 1
Last time read locked in file btr0sea.c line 746
Last time write locked in file btr0cur.c line 2184
Warning: a long semaphore wait:
--Thread 1539602784 has waited at btr0sea.c line 916 for 562.00 seconds the semaphore:
S-lock on RW-latch at 0x2a96d920b8 created in file btr0sea.c line 139
a writer (thread id 1799514464) has reserved it in mode  wait exclusive
number of readers 0, waiters flag 1
Last time read locked in file btr0sea.c line 746
Last time write locked in file btr0cur.c line 2184
Warning: a long semaphore wait:
--Thread 1598810464 has waited at btr0sea.c line 746 for 562.00 seconds the semaphore:
S-lock on RW-latch at 0x2a96d920b8 created in file btr0sea.c line 139
a writer (thread id 1799514464) has reserved it in mode  wait exclusive
number of readers 0, waiters flag 1
Last time read locked in file btr0sea.c line 746
Last time write locked in file btr0cur.c line 2184
Warning: a long semaphore wait:
--Thread 1795098976 has waited at btr0sea.c line 1127 for 562.00 seconds the semaphore:
S-lock on RW-latch at 0x2a96d920b8 created in file btr0sea.c line 139
a writer (thread id 1799514464) has reserved it in mode  wait exclusive
number of readers 0, waiters flag 1
Last time read locked in file btr0sea.c line 746
Last time write locked in file btr0cur.c line 2184
Warning: a long semaphore wait:
--Thread 1565895008 has waited at btr0sea.c line 916 for 562.00 seconds the semaphore:
S-lock on RW-latch at 0x2a96d920b8 created in file btr0sea.c line 139
a writer (thread id 1799514464) has reserved it in mode  wait exclusive
number of readers 0, waiters flag 1
Last time read locked in file btr0sea.c line 746
Last time write locked in file btr0cur.c line 2184
Warning: a long semaphore wait:
--Thread 1634335072 has waited at row0sel.c line 3326 for 562.00 seconds the semaphore:
S-lock on RW-latch at 0x2a96d920b8 created in file btr0sea.c line 139
a writer (thread id 1799514464) has reserved it in mode  wait exclusive
number of readers 0, waiters flag 1
Last time read locked in file btr0sea.c line 746
Last time write locked in file btr0cur.c line 2184
Warning: a long semaphore wait:
--Thread 1582954848 has waited at btr0sea.c line 1127 for 562.00 seconds the semaphore:
S-lock on RW-latch at 0x2a96d920b8 created in file btr0sea.c line 139
a writer (thread id 1799514464) has reserved it in mode  wait exclusive
number of readers 0, waiters flag 1
Last time read locked in file btr0sea.c line 746
Last time write locked in file btr0cur.c line 2184
Warning: a long semaphore wait:
--Thread 1548433760 has waited at btr0sea.c line 746 for 562.00 seconds the semaphore:
S-lock on RW-latch at 0x2a96d920b8 created in file btr0sea.c line 139
a writer (thread id 1799514464) has reserved it in mode  wait exclusive
number of readers 0, waiters flag 1
Last time read locked in file btr0sea.c line 746
Last time write locked in file btr0cur.c line 2184
Warning: a long semaphore wait:
--Thread 1640958304 has waited at btr0sea.c line 916 for 562.00 seconds the semaphore:
S-lock on RW-latch at 0x2a96d920b8 created in file btr0sea.c line 139
a writer (thread id 1799514464) has reserved it in mode  wait exclusive
number of readers 0, waiters flag 1
Last time read locked in file btr0sea.c line 746
Last time write locked in file btr0cur.c line 2184
Warning: a long semaphore wait:
--Thread 1642764640 has waited at trx0trx.c line 715 for 562.00 seconds the semaphore:
Mutex at 0x2a96d8f2b8 created file srv0srv.c line 872, lock var 1
waiters flag 1
Warning: a long semaphore wait:
--Thread 1602824544 has waited at trx0trx.c line 371 for 562.00 seconds the semaphore:
Mutex at 0x2a96d8f2b8 created file srv0srv.c line 872, lock var 1
waiters flag 1
Warning: a long semaphore wait:
--Thread 1643567456 has waited at trx0trx.c line 1609 for 562.00 seconds the semaphore:
Mutex at 0x2a96d8f2b8 created file srv0srv.c line 872, lock var 1
waiters flag 1
Warning: a long semaphore wait:
--Thread 1628916064 has waited at btr0sea.c line 1127 for 562.00 seconds the semaphore:
S-lock on RW-latch at 0x2a96d920b8 created in file btr0sea.c line 139
a writer (thread id 1799514464) has reserved it in mode  wait exclusive
number of readers 0, waiters flag 1
Last time read locked in file btr0sea.c line 746
Last time write locked in file btr0cur.c line 2184
###### Starts InnoDB Monitor for 30 secs to print diagnostic info:
Pending preads 0, pwrites 0
###### Diagnostic info printed to the standard error stream
Warning: a long semaphore wait:
--Thread 1808345440 has waited at btr0sea.c line 1127 for 594.00 seconds the semaphore:
S-lock on RW-latch at 0x2a96d920b8 created in file btr0sea.c line 139
a writer (thread id 1799514464) has reserved it in mode  wait exclusive
number of readers 0, waiters flag 1
Last time read locked in file btr0sea.c line 746
Last time write locked in file btr0cur.c line 2184
Warning: a long semaphore wait:
--Thread 1799514464 has waited at btr0sea.c line 489 for 594.00 seconds the semaphore:
X-lock on RW-latch at 0x2a96d920b8 created in file btr0sea.c line 139
a writer (thread id 1799514464) has reserved it in mode  wait exclusive
number of readers 0, waiters flag 1
Last time read locked in file btr0sea.c line 746
Last time write locked in file btr0cur.c line 2184
Warning: a long semaphore wait:
--Thread 1536391520 has waited at lock0lock.c line 3093 for 594.00 seconds the semaphore:
Mutex at 0x2a96d8f2b8 created file srv0srv.c line 872, lock var 1
waiters flag 1
Warning: a long semaphore wait:
--Thread 1829017952 has waited at btr0sea.c line 1127 for 594.00 seconds the semaphore:
S-lock on RW-latch at 0x2a96d920b8 created in file btr0sea.c line 139
a writer (thread id 1799514464) has reserved it in mode  wait exclusive
number of readers 0, waiters flag 1
Last time read locked in file btr0sea.c line 746
Last time write locked in file btr0cur.c line 2184
Warning: a long semaphore wait:
--Thread 1598609760 has waited at btr0sea.c line 746 for 594.00 seconds the semaphore:
S-lock on RW-latch at 0x2a96d920b8 created in file btr0sea.c line 139
a writer (thread id 1799514464) has reserved it in mode  wait exclusive
number of readers 0, waiters flag 1
Last time read locked in file btr0sea.c line 746
Last time write locked in file btr0cur.c line 2184
Warning: a long semaphore wait:
--Thread 1515411808 has waited at srv0srv.c line 1952 for 594.00 seconds the semaphore:
Mutex at 0x2a96d8f2b8 created file srv0srv.c line 872, lock var 1
waiters flag 1
Warning: a long semaphore wait:
--Thread 1564289376 has waited at btr0sea.c line 1127 for 594.00 seconds the semaphore:
S-lock on RW-latch at 0x2a96d920b8 created in file btr0sea.c line 139
a writer (thread id 1799514464) has reserved it in mode  wait exclusive
number of readers 0, waiters flag 1
Last time read locked in file btr0sea.c line 746
Last time write locked in file btr0cur.c line 2184
Warning: a long semaphore wait:
--Thread 1597606240 has waited at btr0sea.c line 1383 for 594.00 seconds the semaphore:
X-lock on RW-latch at 0x2a96d920b8 created in file btr0sea.c line 139
a writer (thread id 1799514464) has reserved it in mode  wait exclusive
number of readers 0, waiters flag 1
Last time read locked in file btr0sea.c line 746
Last time write locked in file btr0cur.c line 2184
Warning: a long semaphore wait:
--Thread 1628715360 has waited at btr0sea.c line 1127 for 594.00 seconds the semaphore:
S-lock on RW-latch at 0x2a96d920b8 created in file btr0sea.c line 139
a writer (thread id 1799514464) has reserved it in mode  wait exclusive
number of readers 0, waiters flag 1
Last time read locked in file btr0sea.c line 746
Last time write locked in file btr0cur.c line 2184
Warning: a long semaphore wait:
--Thread 1539602784 has waited at btr0sea.c line 916 for 594.00 seconds the semaphore:
S-lock on RW-latch at 0x2a96d920b8 created in file btr0sea.c line 139
a writer (thread id 1799514464) has reserved it in mode  wait exclusive
number of readers 0, waiters flag 1
Last time read locked in file btr0sea.c line 746
Last time write locked in file btr0cur.c line 2184
Warning: a long semaphore wait:
--Thread 1598810464 has waited at btr0sea.c line 746 for 594.00 seconds the semaphore:
S-lock on RW-latch at 0x2a96d920b8 created in file btr0sea.c line 139
a writer (thread id 1799514464) has reserved it in mode  wait exclusive
number of readers 0, waiters flag 1
Last time read locked in file btr0sea.c line 746
Last time write locked in file btr0cur.c line 2184
Warning: a long semaphore wait:
--Thread 1795098976 has waited at btr0sea.c line 1127 for 594.00 seconds the semaphore:
S-lock on RW-latch at 0x2a96d920b8 created in file btr0sea.c line 139
a writer (thread id 1799514464) has reserved it in mode  wait exclusive
number of readers 0, waiters flag 1
Last time read locked in file btr0sea.c line 746
Last time write locked in file btr0cur.c line 2184
Warning: a long semaphore wait:
--Thread 1565895008 has waited at btr0sea.c line 916 for 594.00 seconds the semaphore:
S-lock on RW-latch at 0x2a96d920b8 created in file btr0sea.c line 139
a writer (thread id 1799514464) has reserved it in mode  wait exclusive
number of readers 0, waiters flag 1
Last time read locked in file btr0sea.c line 746
Last time write locked in file btr0cur.c line 2184
Warning: a long semaphore wait:
--Thread 1634335072 has waited at row0sel.c line 3326 for 594.00 seconds the semaphore:
S-lock on RW-latch at 0x2a96d920b8 created in file btr0sea.c line 139
a writer (thread id 1799514464) has reserved it in mode  wait exclusive
number of readers 0, waiters flag 1
Last time read locked in file btr0sea.c line 746
Last time write locked in file btr0cur.c line 2184
Warning: a long semaphore wait:
--Thread 1582954848 has waited at btr0sea.c line 1127 for 594.00 seconds the semaphore:
S-lock on RW-latch at 0x2a96d920b8 created in file btr0sea.c line 139
a writer (thread id 1799514464) has reserved it in mode  wait exclusive
number of readers 0, waiters flag 1
Last time read locked in file btr0sea.c line 746
Last time write locked in file btr0cur.c line 2184
Warning: a long semaphore wait:
--Thread 1548433760 has waited at btr0sea.c line 746 for 594.00 seconds the semaphore:
S-lock on RW-latch at 0x2a96d920b8 created in file btr0sea.c line 139
a writer (thread id 1799514464) has reserved it in mode  wait exclusive
number of readers 0, waiters flag 1
Last time read locked in file btr0sea.c line 746
Last time write locked in file btr0cur.c line 2184
Warning: a long semaphore wait:
--Thread 1640958304 has waited at btr0sea.c line 916 for 594.00 seconds the semaphore:
S-lock on RW-latch at 0x2a96d920b8 created in file btr0sea.c line 139
a writer (thread id 1799514464) has reserved it in mode  wait exclusive
number of readers 0, waiters flag 1
Last time read locked in file btr0sea.c line 746
Last time write locked in file btr0cur.c line 2184
Warning: a long semaphore wait:
--Thread 1642764640 has waited at trx0trx.c line 715 for 594.00 seconds the semaphore:
Mutex at 0x2a96d8f2b8 created file srv0srv.c line 872, lock var 1
waiters flag 1
Warning: a long semaphore wait:
--Thread 1602824544 has waited at trx0trx.c line 371 for 594.00 seconds the semaphore:
Mutex at 0x2a96d8f2b8 created file srv0srv.c line 872, lock var 1
waiters flag 1
Warning: a long semaphore wait:
--Thread 1643567456 has waited at trx0trx.c line 1609 for 594.00 seconds the semaphore:
Mutex at 0x2a96d8f2b8 created file srv0srv.c line 872, lock var 1
waiters flag 1
Warning: a long semaphore wait:
--Thread 1628916064 has waited at btr0sea.c line 1127 for 594.00 seconds the semaphore:
S-lock on RW-latch at 0x2a96d920b8 created in file btr0sea.c line 139
a writer (thread id 1799514464) has reserved it in mode  wait exclusive
number of readers 0, waiters flag 1
Last time read locked in file btr0sea.c line 746
Last time write locked in file btr0cur.c line 2184
###### Starts InnoDB Monitor for 30 secs to print diagnostic info:
Pending preads 0, pwrites 0
###### Diagnostic info printed to the standard error stream
Warning: a long semaphore wait:
--Thread 1808345440 has waited at btr0sea.c line 1127 for 626.00 seconds the semaphore:
S-lock on RW-latch at 0x2a96d920b8 created in file btr0sea.c line 139
a writer (thread id 1799514464) has reserved it in mode  wait exclusive
number of readers 0, waiters flag 1
Last time read locked in file btr0sea.c line 746
Last time write locked in file btr0cur.c line 2184
Warning: a long semaphore wait:
--Thread 1799514464 has waited at btr0sea.c line 489 for 626.00 seconds the semaphore:
X-lock on RW-latch at 0x2a96d920b8 created in file btr0sea.c line 139
a writer (thread id 1799514464) has reserved it in mode  wait exclusive
number of readers 0, waiters flag 1
Last time read locked in file btr0sea.c line 746
Last time write locked in file btr0cur.c line 2184
Warning: a long semaphore wait:
--Thread 1536391520 has waited at lock0lock.c line 3093 for 626.00 seconds the semaphore:
Mutex at 0x2a96d8f2b8 created file srv0srv.c line 872, lock var 1
waiters flag 1
Warning: a long semaphore wait:
--Thread 1829017952 has waited at btr0sea.c line 1127 for 626.00 seconds the semaphore:
S-lock on RW-latch at 0x2a96d920b8 created in file btr0sea.c line 139
a writer (thread id 1799514464) has reserved it in mode  wait exclusive
number of readers 0, waiters flag 1
Last time read locked in file btr0sea.c line 746
Last time write locked in file btr0cur.c line 2184
Warning: a long semaphore wait:
--Thread 1598609760 has waited at btr0sea.c line 746 for 626.00 seconds the semaphore:
S-lock on RW-latch at 0x2a96d920b8 created in file btr0sea.c line 139
a writer (thread id 1799514464) has reserved it in mode  wait exclusive
number of readers 0, waiters flag 1
Last time read locked in file btr0sea.c line 746
Last time write locked in file btr0cur.c line 2184
Warning: a long semaphore wait:
--Thread 1515411808 has waited at srv0srv.c line 1952 for 626.00 seconds the semaphore:
Mutex at 0x2a96d8f2b8 created file srv0srv.c line 872, lock var 1
waiters flag 1
Warning: a long semaphore wait:
--Thread 1564289376 has waited at btr0sea.c line 1127 for 626.00 seconds the semaphore:
S-lock on RW-latch at 0x2a96d920b8 created in file btr0sea.c line 139
a writer (thread id 1799514464) has reserved it in mode  wait exclusive
number of readers 0, waiters flag 1
Last time read locked in file btr0sea.c line 746
Last time write locked in file btr0cur.c line 2184
Warning: a long semaphore wait:
--Thread 1597606240 has waited at btr0sea.c line 1383 for 626.00 seconds the semaphore:
X-lock on RW-latch at 0x2a96d920b8 created in file btr0sea.c line 139
a writer (thread id 1799514464) has reserved it in mode  wait exclusive
number of readers 0, waiters flag 1
Last time read locked in file btr0sea.c line 746
Last time write locked in file btr0cur.c line 2184
Warning: a long semaphore wait:
--Thread 1628715360 has waited at btr0sea.c line 1127 for 626.00 seconds the semaphore:
S-lock on RW-latch at 0x2a96d920b8 created in file btr0sea.c line 139
a writer (thread id 1799514464) has reserved it in mode  wait exclusive
number of readers 0, waiters flag 1
Last time read locked in file btr0sea.c line 746
Last time write locked in file btr0cur.c line 2184
Warning: a long semaphore wait:
--Thread 1539602784 has waited at btr0sea.c line 916 for 626.00 seconds the semaphore:
S-lock on RW-latch at 0x2a96d920b8 created in file btr0sea.c line 139
a writer (thread id 1799514464) has reserved it in mode  wait exclusive
number of readers 0, waiters flag 1
Last time read locked in file btr0sea.c line 746
Last time write locked in file btr0cur.c line 2184
Warning: a long semaphore wait:
--Thread 1598810464 has waited at btr0sea.c line 746 for 626.00 seconds the semaphore:
S-lock on RW-latch at 0x2a96d920b8 created in file btr0sea.c line 139
a writer (thread id 1799514464) has reserved it in mode  wait exclusive
number of readers 0, waiters flag 1
Last time read locked in file btr0sea.c line 746
Last time write locked in file btr0cur.c line 2184
Warning: a long semaphore wait:
--Thread 1795098976 has waited at btr0sea.c line 1127 for 626.00 seconds the semaphore:
S-lock on RW-latch at 0x2a96d920b8 created in file btr0sea.c line 139
a writer (thread id 1799514464) has reserved it in mode  wait exclusive
number of readers 0, waiters flag 1
Last time read locked in file btr0sea.c line 746
Last time write locked in file btr0cur.c line 2184
Warning: a long semaphore wait:
--Thread 1565895008 has waited at btr0sea.c line 916 for 626.00 seconds the semaphore:
S-lock on RW-latch at 0x2a96d920b8 created in file btr0sea.c line 139
a writer (thread id 1799514464) has reserved it in mode  wait exclusive
number of readers 0, waiters flag 1
Last time read locked in file btr0sea.c line 746
Last time write locked in file btr0cur.c line 2184
Warning: a long semaphore wait:
--Thread 1634335072 has waited at row0sel.c line 3326 for 626.00 seconds the semaphore:
S-lock on RW-latch at 0x2a96d920b8 created in file btr0sea.c line 139
a writer (thread id 1799514464) has reserved it in mode  wait exclusive
number of readers 0, waiters flag 1
Last time read locked in file btr0sea.c line 746
Last time write locked in file btr0cur.c line 2184
Warning: a long semaphore wait:
--Thread 1582954848 has waited at btr0sea.c line 1127 for 626.00 seconds the semaphore:
S-lock on RW-latch at 0x2a96d920b8 created in file btr0sea.c line 139
a writer (thread id 1799514464) has reserved it in mode  wait exclusive
number of readers 0, waiters flag 1
Last time read locked in file btr0sea.c line 746
Last time write locked in file btr0cur.c line 2184
Warning: a long semaphore wait:
--Thread 1548433760 has waited at btr0sea.c line 746 for 626.00 seconds the semaphore:
S-lock on RW-latch at 0x2a96d920b8 created in file btr0sea.c line 139
a writer (thread id 1799514464) has reserved it in mode  wait exclusive
number of readers 0, waiters flag 1
Last time read locked in file btr0sea.c line 746
Last time write locked in file btr0cur.c line 2184
Warning: a long semaphore wait:
--Thread 1640958304 has waited at btr0sea.c line 916 for 626.00 seconds the semaphore:
S-lock on RW-latch at 0x2a96d920b8 created in file btr0sea.c line 139
a writer (thread id 1799514464) has reserved it in mode  wait exclusive
number of readers 0, waiters flag 1
Last time read locked in file btr0sea.c line 746
Last time write locked in file btr0cur.c line 2184
Warning: a long semaphore wait:
--Thread 1642764640 has waited at trx0trx.c line 715 for 626.00 seconds the semaphore:
Mutex at 0x2a96d8f2b8 created file srv0srv.c line 872, lock var 1
waiters flag 1
Warning: a long semaphore wait:
--Thread 1602824544 has waited at trx0trx.c line 371 for 626.00 seconds the semaphore:
Mutex at 0x2a96d8f2b8 created file srv0srv.c line 872, lock var 1
waiters flag 1
Warning: a long semaphore wait:
--Thread 1643567456 has waited at trx0trx.c line 1609 for 626.00 seconds the semaphore:
Mutex at 0x2a96d8f2b8 created file srv0srv.c line 872, lock var 1
waiters flag 1
Warning: a long semaphore wait:
--Thread 1628916064 has waited at btr0sea.c line 1127 for 626.00 seconds the semaphore:
S-lock on RW-latch at 0x2a96d920b8 created in file btr0sea.c line 139
a writer (thread id 1799514464) has reserved it in mode  wait exclusive
number of readers 0, waiters flag 1
Last time read locked in file btr0sea.c line 746
Last time write locked in file btr0cur.c line 2184
###### Starts InnoDB Monitor for 30 secs to print diagnostic info:
Pending preads 0, pwrites 0
###### Diagnostic info printed to the standard error stream
Warning: a long semaphore wait:
--Thread 1808345440 has waited at btr0sea.c line 1127 for 661.00 seconds the semaphore:
S-lock on RW-latch at 0x2a96d920b8 created in file btr0sea.c line 139
a writer (thread id 1799514464) has reserved it in mode  wait exclusive
number of readers 0, waiters flag 1
Last time read locked in file btr0sea.c line 746
Last time write locked in file btr0cur.c line 2184
Warning: a long semaphore wait:
--Thread 1799514464 has waited at btr0sea.c line 489 for 661.00 seconds the semaphore:
X-lock on RW-latch at 0x2a96d920b8 created in file btr0sea.c line 139
a writer (thread id 1799514464) has reserved it in mode  wait exclusive
number of readers 0, waiters flag 1
Last time read locked in file btr0sea.c line 746
Last time write locked in file btr0cur.c line 2184
Warning: a long semaphore wait:
--Thread 1536391520 has waited at lock0lock.c line 3093 for 661.00 seconds the semaphore:
Mutex at 0x2a96d8f2b8 created file srv0srv.c line 872, lock var 1
waiters flag 1
Warning: a long semaphore wait:
--Thread 1829017952 has waited at btr0sea.c line 1127 for 661.00 seconds the semaphore:
S-lock on RW-latch at 0x2a96d920b8 created in file btr0sea.c line 139
a writer (thread id 1799514464) has reserved it in mode  wait exclusive
number of readers 0, waiters flag 1
Last time read locked in file btr0sea.c line 746
Last time write locked in file btr0cur.c line 2184
Warning: a long semaphore wait:
--Thread 1598609760 has waited at btr0sea.c line 746 for 661.00 seconds the semaphore:
S-lock on RW-latch at 0x2a96d920b8 created in file btr0sea.c line 139
a writer (thread id 1799514464) has reserved it in mode  wait exclusive
number of readers 0, waiters flag 1
Last time read locked in file btr0sea.c line 746
Last time write locked in file btr0cur.c line 2184
Warning: a long semaphore wait:
--Thread 1515411808 has waited at srv0srv.c line 1952 for 661.00 seconds the semaphore:
Mutex at 0x2a96d8f2b8 created file srv0srv.c line 872, lock var 1
waiters flag 1
Warning: a long semaphore wait:
--Thread 1564289376 has waited at btr0sea.c line 1127 for 661.00 seconds the semaphore:
S-lock on RW-latch at 0x2a96d920b8 created in file btr0sea.c line 139
a writer (thread id 1799514464) has reserved it in mode  wait exclusive
number of readers 0, waiters flag 1
Last time read locked in file btr0sea.c line 746
Last time write locked in file btr0cur.c line 2184
Warning: a long semaphore wait:
--Thread 1597606240 has waited at btr0sea.c line 1383 for 661.00 seconds the semaphore:
X-lock on RW-latch at 0x2a96d920b8 created in file btr0sea.c line 139
a writer (thread id 1799514464) has reserved it in mode  wait exclusive
number of readers 0, waiters flag 1
Last time read locked in file btr0sea.c line 746
Last time write locked in file btr0cur.c line 2184
Warning: a long semaphore wait:
--Thread 1628715360 has waited at btr0sea.c line 1127 for 661.00 seconds the semaphore:
S-lock on RW-latch at 0x2a96d920b8 created in file btr0sea.c line 139
a writer (thread id 1799514464) has reserved it in mode  wait exclusive
number of readers 0, waiters flag 1
Last time read locked in file btr0sea.c line 746
Last time write locked in file btr0cur.c line 2184
Warning: a long semaphore wait:
--Thread 1539602784 has waited at btr0sea.c line 916 for 661.00 seconds the semaphore:
S-lock on RW-latch at 0x2a96d920b8 created in file btr0sea.c line 139
a writer (thread id 1799514464) has reserved it in mode  wait exclusive
number of readers 0, waiters flag 1
Last time read locked in file btr0sea.c line 746
Last time write locked in file btr0cur.c line 2184
Warning: a long semaphore wait:
--Thread 1598810464 has waited at btr0sea.c line 746 for 661.00 seconds the semaphore:
S-lock on RW-latch at 0x2a96d920b8 created in file btr0sea.c line 139
a writer (thread id 1799514464) has reserved it in mode  wait exclusive
number of readers 0, waiters flag 1
Last time read locked in file btr0sea.c line 746
Last time write locked in file btr0cur.c line 2184
Warning: a long semaphore wait:
--Thread 1795098976 has waited at btr0sea.c line 1127 for 661.00 seconds the semaphore:
S-lock on RW-latch at 0x2a96d920b8 created in file btr0sea.c line 139
a writer (thread id 1799514464) has reserved it in mode  wait exclusive
number of readers 0, waiters flag 1
Last time read locked in file btr0sea.c line 746
Last time write locked in file btr0cur.c line 2184
Warning: a long semaphore wait:
--Thread 1565895008 has waited at btr0sea.c line 916 for 661.00 seconds the semaphore:
S-lock on RW-latch at 0x2a96d920b8 created in file btr0sea.c line 139
a writer (thread id 1799514464) has reserved it in mode  wait exclusive
number of readers 0, waiters flag 1
Last time read locked in file btr0sea.c line 746
Last time write locked in file btr0cur.c line 2184
Warning: a long semaphore wait:
--Thread 1634335072 has waited at row0sel.c line 3326 for 661.00 seconds the semaphore:
S-lock on RW-latch at 0x2a96d920b8 created in file btr0sea.c line 139
a writer (thread id 1799514464) has reserved it in mode  wait exclusive
number of readers 0, waiters flag 1
Last time read locked in file btr0sea.c line 746
Last time write locked in file btr0cur.c line 2184
Warning: a long semaphore wait:
--Thread 1582954848 has waited at btr0sea.c line 1127 for 661.00 seconds the semaphore:
S-lock on RW-latch at 0x2a96d920b8 created in file btr0sea.c line 139
a writer (thread id 1799514464) has reserved it in mode  wait exclusive
number of readers 0, waiters flag 1
Last time read locked in file btr0sea.c line 746
Last time write locked in file btr0cur.c line 2184
Warning: a long semaphore wait:
--Thread 1548433760 has waited at btr0sea.c line 746 for 661.00 seconds the semaphore:
S-lock on RW-latch at 0x2a96d920b8 created in file btr0sea.c line 139
a writer (thread id 1799514464) has reserved it in mode  wait exclusive
number of readers 0, waiters flag 1
Last time read locked in file btr0sea.c line 746
Last time write locked in file btr0cur.c line 2184
Warning: a long semaphore wait:
--Thread 1640958304 has waited at btr0sea.c line 916 for 661.00 seconds the semaphore:
S-lock on RW-latch at 0x2a96d920b8 created in file btr0sea.c line 139
a writer (thread id 1799514464) has reserved it in mode  wait exclusive
number of readers 0, waiters flag 1
Last time read locked in file btr0sea.c line 746
Last time write locked in file btr0cur.c line 2184
Warning: a long semaphore wait:
--Thread 1642764640 has waited at trx0trx.c line 715 for 661.00 seconds the semaphore:
Mutex at 0x2a96d8f2b8 created file srv0srv.c line 872, lock var 1
waiters flag 1
Warning: a long semaphore wait:
--Thread 1602824544 has waited at trx0trx.c line 371 for 661.00 seconds the semaphore:
Mutex at 0x2a96d8f2b8 created file srv0srv.c line 872, lock var 1
waiters flag 1
Warning: a long semaphore wait:
--Thread 1643567456 has waited at trx0trx.c line 1609 for 661.00 seconds the semaphore:
Mutex at 0x2a96d8f2b8 created file srv0srv.c line 872, lock var 1
waiters flag 1
Warning: a long semaphore wait:
--Thread 1628916064 has waited at btr0sea.c line 1127 for 661.00 seconds the semaphore:
S-lock on RW-latch at 0x2a96d920b8 created in file btr0sea.c line 139
a writer (thread id 1799514464) has reserved it in mode  wait exclusive
number of readers 0, waiters flag 1
Last time read locked in file btr0sea.c line 746
Last time write locked in file btr0cur.c line 2184
###### Starts InnoDB Monitor for 30 secs to print diagnostic info:
Pending preads 0, pwrites 0
###### Diagnostic info printed to the standard error stream
Warning: a long semaphore wait:
--Thread 1808345440 has waited at btr0sea.c line 1127 for 693.00 seconds the semaphore:
S-lock on RW-latch at 0x2a96d920b8 created in file btr0sea.c line 139
a writer (thread id 1799514464) has reserved it in mode  wait exclusive
number of readers 0, waiters flag 1
Last time read locked in file btr0sea.c line 746
Last time write locked in file btr0cur.c line 2184
Warning: a long semaphore wait:
--Thread 1799514464 has waited at btr0sea.c line 489 for 693.00 seconds the semaphore:
X-lock on RW-latch at 0x2a96d920b8 created in file btr0sea.c line 139
a writer (thread id 1799514464) has reserved it in mode  wait exclusive
number of readers 0, waiters flag 1
Last time read locked in file btr0sea.c line 746
Last time write locked in file btr0cur.c line 2184
Warning: a long semaphore wait:
--Thread 1536391520 has waited at lock0lock.c line 3093 for 693.00 seconds the semaphore:
Mutex at 0x2a96d8f2b8 created file srv0srv.c line 872, lock var 1
waiters flag 1
Warning: a long semaphore wait:
--Thread 1829017952 has waited at btr0sea.c line 1127 for 693.00 seconds the semaphore:
S-lock on RW-latch at 0x2a96d920b8 created in file btr0sea.c line 139
a writer (thread id 1799514464) has reserved it in mode  wait exclusive
number of readers 0, waiters flag 1
Last time read locked in file btr0sea.c line 746
Last time write locked in file btr0cur.c line 2184
Warning: a long semaphore wait:
--Thread 1598609760 has waited at btr0sea.c line 746 for 693.00 seconds the semaphore:
S-lock on RW-latch at 0x2a96d920b8 created in file btr0sea.c line 139
a writer (thread id 1799514464) has reserved it in mode  wait exclusive
number of readers 0, waiters flag 1
Last time read locked in file btr0sea.c line 746
Last time write locked in file btr0cur.c line 2184
Warning: a long semaphore wait:
--Thread 1515411808 has waited at srv0srv.c line 1952 for 693.00 seconds the semaphore:
Mutex at 0x2a96d8f2b8 created file srv0srv.c line 872, lock var 1
waiters flag 1
Warning: a long semaphore wait:
--Thread 1564289376 has waited at btr0sea.c line 1127 for 693.00 seconds the semaphore:
S-lock on RW-latch at 0x2a96d920b8 created in file btr0sea.c line 139
a writer (thread id 1799514464) has reserved it in mode  wait exclusive
number of readers 0, waiters flag 1
Last time read locked in file btr0sea.c line 746
Last time write locked in file btr0cur.c line 2184
Warning: a long semaphore wait:
--Thread 1597606240 has waited at btr0sea.c line 1383 for 693.00 seconds the semaphore:
X-lock on RW-latch at 0x2a96d920b8 created in file btr0sea.c line 139
a writer (thread id 1799514464) has reserved it in mode  wait exclusive
number of readers 0, waiters flag 1
Last time read locked in file btr0sea.c line 746
Last time write locked in file btr0cur.c line 2184
Warning: a long semaphore wait:
--Thread 1628715360 has waited at btr0sea.c line 1127 for 693.00 seconds the semaphore:
S-lock on RW-latch at 0x2a96d920b8 created in file btr0sea.c line 139
a writer (thread id 1799514464) has reserved it in mode  wait exclusive
number of readers 0, waiters flag 1
Last time read locked in file btr0sea.c line 746
Last time write locked in file btr0cur.c line 2184
Warning: a long semaphore wait:
--Thread 1539602784 has waited at btr0sea.c line 916 for 693.00 seconds the semaphore:
S-lock on RW-latch at 0x2a96d920b8 created in file btr0sea.c line 139
a writer (thread id 1799514464) has reserved it in mode  wait exclusive
number of readers 0, waiters flag 1
Last time read locked in file btr0sea.c line 746
Last time write locked in file btr0cur.c line 2184
Warning: a long semaphore wait:
--Thread 1598810464 has waited at btr0sea.c line 746 for 693.00 seconds the semaphore:
S-lock on RW-latch at 0x2a96d920b8 created in file btr0sea.c line 139
a writer (thread id 1799514464) has reserved it in mode  wait exclusive
number of readers 0, waiters flag 1
Last time read locked in file btr0sea.c line 746
Last time write locked in file btr0cur.c line 2184
Warning: a long semaphore wait:
--Thread 1795098976 has waited at btr0sea.c line 1127 for 693.00 seconds the semaphore:
S-lock on RW-latch at 0x2a96d920b8 created in file btr0sea.c line 139
a writer (thread id 1799514464) has reserved it in mode  wait exclusive
number of readers 0, waiters flag 1
Last time read locked in file btr0sea.c line 746
Last time write locked in file btr0cur.c line 2184
Warning: a long semaphore wait:
--Thread 1565895008 has waited at btr0sea.c line 916 for 693.00 seconds the semaphore:
S-lock on RW-latch at 0x2a96d920b8 created in file btr0sea.c line 139
a writer (thread id 1799514464) has reserved it in mode  wait exclusive
number of readers 0, waiters flag 1
Last time read locked in file btr0sea.c line 746
Last time write locked in file btr0cur.c line 2184
Warning: a long semaphore wait:
--Thread 1634335072 has waited at row0sel.c line 3326 for 693.00 seconds the semaphore:
S-lock on RW-latch at 0x2a96d920b8 created in file btr0sea.c line 139
a writer (thread id 1799514464) has reserved it in mode  wait exclusive
number of readers 0, waiters flag 1
Last time read locked in file btr0sea.c line 746
Last time write locked in file btr0cur.c line 2184
Warning: a long semaphore wait:
--Thread 1582954848 has waited at btr0sea.c line 1127 for 693.00 seconds the semaphore:
S-lock on RW-latch at 0x2a96d920b8 created in file btr0sea.c line 139
a writer (thread id 1799514464) has reserved it in mode  wait exclusive
number of readers 0, waiters flag 1
Last time read locked in file btr0sea.c line 746
Last time write locked in file btr0cur.c line 2184
Warning: a long semaphore wait:
--Thread 1548433760 has waited at btr0sea.c line 746 for 693.00 seconds the semaphore:
S-lock on RW-latch at 0x2a96d920b8 created in file btr0sea.c line 139
a writer (thread id 1799514464) has reserved it in mode  wait exclusive
number of readers 0, waiters flag 1
Last time read locked in file btr0sea.c line 746
Last time write locked in file btr0cur.c line 2184
Warning: a long semaphore wait:
--Thread 1640958304 has waited at btr0sea.c line 916 for 693.00 seconds the semaphore:
S-lock on RW-latch at 0x2a96d920b8 created in file btr0sea.c line 139
a writer (thread id 1799514464) has reserved it in mode  wait exclusive
number of readers 0, waiters flag 1
Last time read locked in file btr0sea.c line 746
Last time write locked in file btr0cur.c line 2184
Warning: a long semaphore wait:
--Thread 1642764640 has waited at trx0trx.c line 715 for 693.00 seconds the semaphore:
Mutex at 0x2a96d8f2b8 created file srv0srv.c line 872, lock var 1
waiters flag 1
Warning: a long semaphore wait:
--Thread 1602824544 has waited at trx0trx.c line 371 for 693.00 seconds the semaphore:
Mutex at 0x2a96d8f2b8 created file srv0srv.c line 872, lock var 1
waiters flag 1
Warning: a long semaphore wait:
--Thread 1643567456 has waited at trx0trx.c line 1609 for 693.00 seconds the semaphore:
Mutex at 0x2a96d8f2b8 created file srv0srv.c line 872, lock var 1
waiters flag 1
Warning: a long semaphore wait:
--Thread 1628916064 has waited at btr0sea.c line 1127 for 693.00 seconds the semaphore:
S-lock on RW-latch at 0x2a96d920b8 created in file btr0sea.c line 139
a writer (thread id 1799514464) has reserved it in mode  wait exclusive
number of readers 0, waiters flag 1
Last time read locked in file btr0sea.c line 746
Last time write locked in file btr0cur.c line 2184
###### Starts InnoDB Monitor for 30 secs to print diagnostic info:
Pending preads 0, pwrites 0
###### Diagnostic info printed to the standard error stream
Warning: a long semaphore wait:
--Thread 1808345440 has waited at btr0sea.c line 1127 for 725.00 seconds the semaphore:
S-lock on RW-latch at 0x2a96d920b8 created in file btr0sea.c line 139
a writer (thread id 1799514464) has reserved it in mode  wait exclusive
number of readers 0, waiters flag 1
Last time read locked in file btr0sea.c line 746
Last time write locked in file btr0cur.c line 2184
Warning: a long semaphore wait:
--Thread 1799514464 has waited at btr0sea.c line 489 for 725.00 seconds the semaphore:
X-lock on RW-latch at 0x2a96d920b8 created in file btr0sea.c line 139
a writer (thread id 1799514464) has reserved it in mode  wait exclusive
number of readers 0, waiters flag 1
Last time read locked in file btr0sea.c line 746
Last time write locked in file btr0cur.c line 2184
Warning: a long semaphore wait:
--Thread 1536391520 has waited at lock0lock.c line 3093 for 725.00 seconds the semaphore:
Mutex at 0x2a96d8f2b8 created file srv0srv.c line 872, lock var 1
waiters flag 1
Warning: a long semaphore wait:
--Thread 1829017952 has waited at btr0sea.c line 1127 for 725.00 seconds the semaphore:
S-lock on RW-latch at 0x2a96d920b8 created in file btr0sea.c line 139
a writer (thread id 1799514464) has reserved it in mode  wait exclusive
number of readers 0, waiters flag 1
Last time read locked in file btr0sea.c line 746
Last time write locked in file btr0cur.c line 2184
Warning: a long semaphore wait:
--Thread 1598609760 has waited at btr0sea.c line 746 for 725.00 seconds the semaphore:
S-lock on RW-latch at 0x2a96d920b8 created in file btr0sea.c line 139
a writer (thread id 1799514464) has reserved it in mode  wait exclusive
number of readers 0, waiters flag 1
Last time read locked in file btr0sea.c line 746
Last time write locked in file btr0cur.c line 2184
Warning: a long semaphore wait:
--Thread 1515411808 has waited at srv0srv.c line 1952 for 725.00 seconds the semaphore:
Mutex at 0x2a96d8f2b8 created file srv0srv.c line 872, lock var 1
waiters flag 1
Warning: a long semaphore wait:
--Thread 1564289376 has waited at btr0sea.c line 1127 for 725.00 seconds the semaphore:
S-lock on RW-latch at 0x2a96d920b8 created in file btr0sea.c line 139
a writer (thread id 1799514464) has reserved it in mode  wait exclusive
number of readers 0, waiters flag 1
Last time read locked in file btr0sea.c line 746
Last time write locked in file btr0cur.c line 2184
Warning: a long semaphore wait:
--Thread 1597606240 has waited at btr0sea.c line 1383 for 725.00 seconds the semaphore:
X-lock on RW-latch at 0x2a96d920b8 created in file btr0sea.c line 139
a writer (thread id 1799514464) has reserved it in mode  wait exclusive
number of readers 0, waiters flag 1
Last time read locked in file btr0sea.c line 746
Last time write locked in file btr0cur.c line 2184
Warning: a long semaphore wait:
--Thread 1628715360 has waited at btr0sea.c line 1127 for 725.00 seconds the semaphore:
S-lock on RW-latch at 0x2a96d920b8 created in file btr0sea.c line 139
a writer (thread id 1799514464) has reserved it in mode  wait exclusive
number of readers 0, waiters flag 1
Last time read locked in file btr0sea.c line 746
Last time write locked in file btr0cur.c line 2184
Warning: a long semaphore wait:
--Thread 1539602784 has waited at btr0sea.c line 916 for 725.00 seconds the semaphore:
S-lock on RW-latch at 0x2a96d920b8 created in file btr0sea.c line 139
a writer (thread id 1799514464) has reserved it in mode  wait exclusive
number of readers 0, waiters flag 1
Last time read locked in file btr0sea.c line 746
Last time write locked in file btr0cur.c line 2184
Warning: a long semaphore wait:
--Thread 1598810464 has waited at btr0sea.c line 746 for 725.00 seconds the semaphore:
S-lock on RW-latch at 0x2a96d920b8 created in file btr0sea.c line 139
a writer (thread id 1799514464) has reserved it in mode  wait exclusive
number of readers 0, waiters flag 1
Last time read locked in file btr0sea.c line 746
Last time write locked in file btr0cur.c line 2184
Warning: a long semaphore wait:
--Thread 1795098976 has waited at btr0sea.c line 1127 for 725.00 seconds the semaphore:
S-lock on RW-latch at 0x2a96d920b8 created in file btr0sea.c line 139
a writer (thread id 1799514464) has reserved it in mode  wait exclusive
number of readers 0, waiters flag 1
Last time read locked in file btr0sea.c line 746
Last time write locked in file btr0cur.c line 2184
Warning: a long semaphore wait:
--Thread 1565895008 has waited at btr0sea.c line 916 for 725.00 seconds the semaphore:
S-lock on RW-latch at 0x2a96d920b8 created in file btr0sea.c line 139
a writer (thread id 1799514464) has reserved it in mode  wait exclusive
number of readers 0, waiters flag 1
Last time read locked in file btr0sea.c line 746
Last time write locked in file btr0cur.c line 2184
Warning: a long semaphore wait:
--Thread 1634335072 has waited at row0sel.c line 3326 for 725.00 seconds the semaphore:
S-lock on RW-latch at 0x2a96d920b8 created in file btr0sea.c line 139
a writer (thread id 1799514464) has reserved it in mode  wait exclusive
number of readers 0, waiters flag 1
Last time read locked in file btr0sea.c line 746
Last time write locked in file btr0cur.c line 2184
Warning: a long semaphore wait:
--Thread 1582954848 has waited at btr0sea.c line 1127 for 725.00 seconds the semaphore:
S-lock on RW-latch at 0x2a96d920b8 created in file btr0sea.c line 139
a writer (thread id 1799514464) has reserved it in mode  wait exclusive
number of readers 0, waiters flag 1
Last time read locked in file btr0sea.c line 746
Last time write locked in file btr0cur.c line 2184
Warning: a long semaphore wait:
--Thread 1548433760 has waited at btr0sea.c line 746 for 725.00 seconds the semaphore:
S-lock on RW-latch at 0x2a96d920b8 created in file btr0sea.c line 139
a writer (thread id 1799514464) has reserved it in mode  wait exclusive
number of readers 0, waiters flag 1
Last time read locked in file btr0sea.c line 746
Last time write locked in file btr0cur.c line 2184
Warning: a long semaphore wait:
--Thread 1640958304 has waited at btr0sea.c line 916 for 725.00 seconds the semaphore:
S-lock on RW-latch at 0x2a96d920b8 created in file btr0sea.c line 139
a writer (thread id 1799514464) has reserved it in mode  wait exclusive
number of readers 0, waiters flag 1
Last time read locked in file btr0sea.c line 746
Last time write locked in file btr0cur.c line 2184
Warning: a long semaphore wait:
--Thread 1642764640 has waited at trx0trx.c line 715 for 725.00 seconds the semaphore:
Mutex at 0x2a96d8f2b8 created file srv0srv.c line 872, lock var 1
waiters flag 1
Warning: a long semaphore wait:
--Thread 1602824544 has waited at trx0trx.c line 371 for 725.00 seconds the semaphore:
Mutex at 0x2a96d8f2b8 created file srv0srv.c line 872, lock var 1
waiters flag 1
Warning: a long semaphore wait:
--Thread 1643567456 has waited at trx0trx.c line 1609 for 725.00 seconds the semaphore:
Mutex at 0x2a96d8f2b8 created file srv0srv.c line 872, lock var 1
waiters flag 1
Warning: a long semaphore wait:
--Thread 1628916064 has waited at btr0sea.c line 1127 for 725.00 seconds the semaphore:
S-lock on RW-latch at 0x2a96d920b8 created in file btr0sea.c line 139
a writer (thread id 1799514464) has reserved it in mode  wait exclusive
number of readers 0, waiters flag 1
Last time read locked in file btr0sea.c line 746
Last time write locked in file btr0cur.c line 2184
###### Starts InnoDB Monitor for 30 secs to print diagnostic info:
Pending preads 0, pwrites 0
###### Diagnostic info printed to the standard error stream
Warning: a long semaphore wait:
--Thread 1808345440 has waited at btr0sea.c line 1127 for 757.00 seconds the semaphore:
S-lock on RW-latch at 0x2a96d920b8 created in file btr0sea.c line 139
a writer (thread id 1799514464) has reserved it in mode  wait exclusive
number of readers 0, waiters flag 1
Last time read locked in file btr0sea.c line 746
Last time write locked in file btr0cur.c line 2184
Warning: a long semaphore wait:
--Thread 1799514464 has waited at btr0sea.c line 489 for 757.00 seconds the semaphore:
X-lock on RW-latch at 0x2a96d920b8 created in file btr0sea.c line 139
a writer (thread id 1799514464) has reserved it in mode  wait exclusive
number of readers 0, waiters flag 1
Last time read locked in file btr0sea.c line 746
Last time write locked in file btr0cur.c line 2184
Warning: a long semaphore wait:
--Thread 1536391520 has waited at lock0lock.c line 3093 for 757.00 seconds the semaphore:
Mutex at 0x2a96d8f2b8 created file srv0srv.c line 872, lock var 1
waiters flag 1
Warning: a long semaphore wait:
--Thread 1829017952 has waited at btr0sea.c line 1127 for 757.00 seconds the semaphore:
S-lock on RW-latch at 0x2a96d920b8 created in file btr0sea.c line 139
a writer (thread id 1799514464) has reserved it in mode  wait exclusive
number of readers 0, waiters flag 1
Last time read locked in file btr0sea.c line 746
Last time write locked in file btr0cur.c line 2184
Warning: a long semaphore wait:
--Thread 1598609760 has waited at btr0sea.c line 746 for 757.00 seconds the semaphore:
S-lock on RW-latch at 0x2a96d920b8 created in file btr0sea.c line 139
a writer (thread id 1799514464) has reserved it in mode  wait exclusive
number of readers 0, waiters flag 1
Last time read locked in file btr0sea.c line 746
Last time write locked in file btr0cur.c line 2184
Warning: a long semaphore wait:
--Thread 1515411808 has waited at srv0srv.c line 1952 for 757.00 seconds the semaphore:
Mutex at 0x2a96d8f2b8 created file srv0srv.c line 872, lock var 1
waiters flag 1
Warning: a long semaphore wait:
--Thread 1564289376 has waited at btr0sea.c line 1127 for 757.00 seconds the semaphore:
S-lock on RW-latch at 0x2a96d920b8 created in file btr0sea.c line 139
a writer (thread id 1799514464) has reserved it in mode  wait exclusive
number of readers 0, waiters flag 1
Last time read locked in file btr0sea.c line 746
Last time write locked in file btr0cur.c line 2184
Warning: a long semaphore wait:
--Thread 1597606240 has waited at btr0sea.c line 1383 for 757.00 seconds the semaphore:
X-lock on RW-latch at 0x2a96d920b8 created in file btr0sea.c line 139
a writer (thread id 1799514464) has reserved it in mode  wait exclusive
number of readers 0, waiters flag 1
Last time read locked in file btr0sea.c line 746
Last time write locked in file btr0cur.c line 2184
Warning: a long semaphore wait:
--Thread 1628715360 has waited at btr0sea.c line 1127 for 757.00 seconds the semaphore:
S-lock on RW-latch at 0x2a96d920b8 created in file btr0sea.c line 139
a writer (thread id 1799514464) has reserved it in mode  wait exclusive
number of readers 0, waiters flag 1
Last time read locked in file btr0sea.c line 746
Last time write locked in file btr0cur.c line 2184
Warning: a long semaphore wait:
--Thread 1539602784 has waited at btr0sea.c line 916 for 757.00 seconds the semaphore:
S-lock on RW-latch at 0x2a96d920b8 created in file btr0sea.c line 139
a writer (thread id 1799514464) has reserved it in mode  wait exclusive
number of readers 0, waiters flag 1
Last time read locked in file btr0sea.c line 746
Last time write locked in file btr0cur.c line 2184
Warning: a long semaphore wait:
--Thread 1598810464 has waited at btr0sea.c line 746 for 757.00 seconds the semaphore:
S-lock on RW-latch at 0x2a96d920b8 created in file btr0sea.c line 139
a writer (thread id 1799514464) has reserved it in mode  wait exclusive
number of readers 0, waiters flag 1
Last time read locked in file btr0sea.c line 746
Last time write locked in file btr0cur.c line 2184
Warning: a long semaphore wait:
--Thread 1795098976 has waited at btr0sea.c line 1127 for 757.00 seconds the semaphore:
S-lock on RW-latch at 0x2a96d920b8 created in file btr0sea.c line 139
a writer (thread id 1799514464) has reserved it in mode  wait exclusive
number of readers 0, waiters flag 1
Last time read locked in file btr0sea.c line 746
Last time write locked in file btr0cur.c line 2184
Warning: a long semaphore wait:
--Thread 1565895008 has waited at btr0sea.c line 916 for 757.00 seconds the semaphore:
S-lock on RW-latch at 0x2a96d920b8 created in file btr0sea.c line 139
a writer (thread id 1799514464) has reserved it in mode  wait exclusive
number of readers 0, waiters flag 1
Last time read locked in file btr0sea.c line 746
Last time write locked in file btr0cur.c line 2184
Warning: a long semaphore wait:
--Thread 1634335072 has waited at row0sel.c line 3326 for 757.00 seconds the semaphore:
S-lock on RW-latch at 0x2a96d920b8 created in file btr0sea.c line 139
a writer (thread id 1799514464) has reserved it in mode  wait exclusive
number of readers 0, waiters flag 1
Last time read locked in file btr0sea.c line 746
Last time write locked in file btr0cur.c line 2184
Warning: a long semaphore wait:
--Thread 1582954848 has waited at btr0sea.c line 1127 for 757.00 seconds the semaphore:
S-lock on RW-latch at 0x2a96d920b8 created in file btr0sea.c line 139
a writer (thread id 1799514464) has reserved it in mode  wait exclusive
number of readers 0, waiters flag 1
Last time read locked in file btr0sea.c line 746
Last time write locked in file btr0cur.c line 2184
Warning: a long semaphore wait:
--Thread 1548433760 has waited at btr0sea.c line 746 for 757.00 seconds the semaphore:
S-lock on RW-latch at 0x2a96d920b8 created in file btr0sea.c line 139
a writer (thread id 1799514464) has reserved it in mode  wait exclusive
number of readers 0, waiters flag 1
Last time read locked in file btr0sea.c line 746
Last time write locked in file btr0cur.c line 2184
Warning: a long semaphore wait:
--Thread 1640958304 has waited at btr0sea.c line 916 for 757.00 seconds the semaphore:
S-lock on RW-latch at 0x2a96d920b8 created in file btr0sea.c line 139
a writer (thread id 1799514464) has reserved it in mode  wait exclusive
number of readers 0, waiters flag 1
Last time read locked in file btr0sea.c line 746
Last time write locked in file btr0cur.c line 2184
Warning: a long semaphore wait:
--Thread 1642764640 has waited at trx0trx.c line 715 for 757.00 seconds the semaphore:
Mutex at 0x2a96d8f2b8 created file srv0srv.c line 872, lock var 1
waiters flag 1
Warning: a long semaphore wait:
--Thread 1602824544 has waited at trx0trx.c line 371 for 757.00 seconds the semaphore:
Mutex at 0x2a96d8f2b8 created file srv0srv.c line 872, lock var 1
waiters flag 1
Warning: a long semaphore wait:
--Thread 1643567456 has waited at trx0trx.c line 1609 for 757.00 seconds the semaphore:
Mutex at 0x2a96d8f2b8 created file srv0srv.c line 872, lock var 1
waiters flag 1
Warning: a long semaphore wait:
--Thread 1628916064 has waited at btr0sea.c line 1127 for 757.00 seconds the semaphore:
S-lock on RW-latch at 0x2a96d920b8 created in file btr0sea.c line 139
a writer (thread id 1799514464) has reserved it in mode  wait exclusive
number of readers 0, waiters flag 1
Last time read locked in file btr0sea.c line 746
Last time write locked in file btr0cur.c line 2184
###### Starts InnoDB Monitor for 30 secs to print diagnostic info:
Pending preads 0, pwrites 0
###### Diagnostic info printed to the standard error stream
Warning: a long semaphore wait:
--Thread 1808345440 has waited at btr0sea.c line 1127 for 789.00 seconds the semaphore:
S-lock on RW-latch at 0x2a96d920b8 created in file btr0sea.c line 139
a writer (thread id 1799514464) has reserved it in mode  wait exclusive
number of readers 0, waiters flag 1
Last time read locked in file btr0sea.c line 746
Last time write locked in file btr0cur.c line 2184
Warning: a long semaphore wait:
--Thread 1799514464 has waited at btr0sea.c line 489 for 789.00 seconds the semaphore:
X-lock on RW-latch at 0x2a96d920b8 created in file btr0sea.c line 139
a writer (thread id 1799514464) has reserved it in mode  wait exclusive
number of readers 0, waiters flag 1
Last time read locked in file btr0sea.c line 746
Last time write locked in file btr0cur.c line 2184
Warning: a long semaphore wait:
--Thread 1536391520 has waited at lock0lock.c line 3093 for 789.00 seconds the semaphore:
Mutex at 0x2a96d8f2b8 created file srv0srv.c line 872, lock var 1
waiters flag 1
Warning: a long semaphore wait:
--Thread 1829017952 has waited at btr0sea.c line 1127 for 789.00 seconds the semaphore:
S-lock on RW-latch at 0x2a96d920b8 created in file btr0sea.c line 139
a writer (thread id 1799514464) has reserved it in mode  wait exclusive
number of readers 0, waiters flag 1
Last time read locked in file btr0sea.c line 746
Last time write locked in file btr0cur.c line 2184
Warning: a long semaphore wait:
--Thread 1598609760 has waited at btr0sea.c line 746 for 789.00 seconds the semaphore:
S-lock on RW-latch at 0x2a96d920b8 created in file btr0sea.c line 139
a writer (thread id 1799514464) has reserved it in mode  wait exclusive
number of readers 0, waiters flag 1
Last time read locked in file btr0sea.c line 746
Last time write locked in file btr0cur.c line 2184
Warning: a long semaphore wait:
--Thread 1515411808 has waited at srv0srv.c line 1952 for 789.00 seconds the semaphore:
Mutex at 0x2a96d8f2b8 created file srv0srv.c line 872, lock var 1
waiters flag 1
Warning: a long semaphore wait:
--Thread 1564289376 has waited at btr0sea.c line 1127 for 789.00 seconds the semaphore:
S-lock on RW-latch at 0x2a96d920b8 created in file btr0sea.c line 139
a writer (thread id 1799514464) has reserved it in mode  wait exclusive
number of readers 0, waiters flag 1
Last time read locked in file btr0sea.c line 746
Last time write locked in file btr0cur.c line 2184
Warning: a long semaphore wait:
--Thread 1597606240 has waited at btr0sea.c line 1383 for 789.00 seconds the semaphore:
X-lock on RW-latch at 0x2a96d920b8 created in file btr0sea.c line 139
a writer (thread id 1799514464) has reserved it in mode  wait exclusive
number of readers 0, waiters flag 1
Last time read locked in file btr0sea.c line 746
Last time write locked in file btr0cur.c line 2184
Warning: a long semaphore wait:
--Thread 1628715360 has waited at btr0sea.c line 1127 for 789.00 seconds the semaphore:
S-lock on RW-latch at 0x2a96d920b8 created in file btr0sea.c line 139
a writer (thread id 1799514464) has reserved it in mode  wait exclusive
number of readers 0, waiters flag 1
Last time read locked in file btr0sea.c line 746
Last time write locked in file btr0cur.c line 2184
Warning: a long semaphore wait:
--Thread 1539602784 has waited at btr0sea.c line 916 for 789.00 seconds the semaphore:
S-lock on RW-latch at 0x2a96d920b8 created in file btr0sea.c line 139
a writer (thread id 1799514464) has reserved it in mode  wait exclusive
number of readers 0, waiters flag 1
Last time read locked in file btr0sea.c line 746
Last time write locked in file btr0cur.c line 2184
Warning: a long semaphore wait:
--Thread 1598810464 has waited at btr0sea.c line 746 for 789.00 seconds the semaphore:
S-lock on RW-latch at 0x2a96d920b8 created in file btr0sea.c line 139
a writer (thread id 1799514464) has reserved it in mode  wait exclusive
number of readers 0, waiters flag 1
Last time read locked in file btr0sea.c line 746
Last time write locked in file btr0cur.c line 2184
Warning: a long semaphore wait:
--Thread 1795098976 has waited at btr0sea.c line 1127 for 789.00 seconds the semaphore:
S-lock on RW-latch at 0x2a96d920b8 created in file btr0sea.c line 139
a writer (thread id 1799514464) has reserved it in mode  wait exclusive
number of readers 0, waiters flag 1
Last time read locked in file btr0sea.c line 746
Last time write locked in file btr0cur.c line 2184
Warning: a long semaphore wait:
--Thread 1565895008 has waited at btr0sea.c line 916 for 789.00 seconds the semaphore:
S-lock on RW-latch at 0x2a96d920b8 created in file btr0sea.c line 139
a writer (thread id 1799514464) has reserved it in mode  wait exclusive
number of readers 0, waiters flag 1
Last time read locked in file btr0sea.c line 746
Last time write locked in file btr0cur.c line 2184
Warning: a long semaphore wait:
--Thread 1634335072 has waited at row0sel.c line 3326 for 789.00 seconds the semaphore:
S-lock on RW-latch at 0x2a96d920b8 created in file btr0sea.c line 139
a writer (thread id 1799514464) has reserved it in mode  wait exclusive
number of readers 0, waiters flag 1
Last time read locked in file btr0sea.c line 746
Last time write locked in file btr0cur.c line 2184
Warning: a long semaphore wait:
--Thread 1582954848 has waited at btr0sea.c line 1127 for 789.00 seconds the semaphore:
S-lock on RW-latch at 0x2a96d920b8 created in file btr0sea.c line 139
a writer (thread id 1799514464) has reserved it in mode  wait exclusive
number of readers 0, waiters flag 1
Last time read locked in file btr0sea.c line 746
Last time write locked in file btr0cur.c line 2184
Warning: a long semaphore wait:
--Thread 1548433760 has waited at btr0sea.c line 746 for 789.00 seconds the semaphore:
S-lock on RW-latch at 0x2a96d920b8 created in file btr0sea.c line 139
a writer (thread id 1799514464) has reserved it in mode  wait exclusive
number of readers 0, waiters flag 1
Last time read locked in file btr0sea.c line 746
Last time write locked in file btr0cur.c line 2184
Warning: a long semaphore wait:
--Thread 1640958304 has waited at btr0sea.c line 916 for 789.00 seconds the semaphore:
S-lock on RW-latch at 0x2a96d920b8 created in file btr0sea.c line 139
a writer (thread id 1799514464) has reserved it in mode  wait exclusive
number of readers 0, waiters flag 1
Last time read locked in file btr0sea.c line 746
Last time write locked in file btr0cur.c line 2184
Warning: a long semaphore wait:
--Thread 1642764640 has waited at trx0trx.c line 715 for 789.00 seconds the semaphore:
Mutex at 0x2a96d8f2b8 created file srv0srv.c line 872, lock var 1
waiters flag 1
Warning: a long semaphore wait:
--Thread 1602824544 has waited at trx0trx.c line 371 for 789.00 seconds the semaphore:
Mutex at 0x2a96d8f2b8 created file srv0srv.c line 872, lock var 1
waiters flag 1
Warning: a long semaphore wait:
--Thread 1643567456 has waited at trx0trx.c line 1609 for 789.00 seconds the semaphore:
Mutex at 0x2a96d8f2b8 created file srv0srv.c line 872, lock var 1
waiters flag 1
Warning: a long semaphore wait:
--Thread 1628916064 has waited at btr0sea.c line 1127 for 789.00 seconds the semaphore:
S-lock on RW-latch at 0x2a96d920b8 created in file btr0sea.c line 139
a writer (thread id 1799514464) has reserved it in mode  wait exclusive
number of readers 0, waiters flag 1
Last time read locked in file btr0sea.c line 746
Last time write locked in file btr0cur.c line 2184
###### Starts InnoDB Monitor for 30 secs to print diagnostic info:
Pending preads 0, pwrites 0
###### Diagnostic info printed to the standard error stream
Error: semaphore wait has lasted > 600 seconds
We intentionally crash the server, because it appears to be hung.
EOF
chomp $big_arg;
$big_arg =~ s/\n+/ /g;

test_log_parser(
   parser => $p,
   file   => 'common/t/samples/errlogs/errlog007.txt',
   result => [
         {  Level => 'unknown',
            ts    => '091121 13:17:58',
            arg   => 'InnoDB: Warning: cannot find a free slot for an '
               . 'undo log. Do you have too many active transactions running '
               . 'concurrently?',
            pos_in_log => '0'
         },
         {  Level      => 'unknown',
            ts         => '091121 13:17:58',
            arg        => $big_arg,
            pos_in_log => '233',
         },
         {  Level => 'unknown',
            arg =>
               'InnoDB: Assertion failure in thread 1525901664 in file srv0srv.c line 2093 We intentionally generate a memory trap. Submit a detailed bug report to http://bugs.mysql.com. If you get repeated assertion failures or crashes, even immediately after the mysqld startup, there may be corruption in the InnoDB tablespace. Please refer to http://dev.mysql.com/doc/refman/5.0/en/forcing-recovery.html about forcing recovery.',
            pos_in_log => '139341',
            ts         => '091205  4:49:04',
         },
      ],
);

$big_arg = <<'EOF';
mysqld got signal 11;
This could be because you hit a bug. It is also possible that this binary
or one of the libraries it was linked against is corrupt, improperly built,
or misconfigured. This error can also be caused by malfunctioning hardware.
We will try our best to scrape up some info that will hopefully help diagnose
the problem, but since we have already crashed, something is definitely wrong
and this may fail.

key_buffer_size=16777216
read_buffer_size=1044480
max_used_connections=2101
max_connections=2100
threads_connected=207
It is possible that mysqld could use up to 
key_buffer_size + (read_buffer_size + sort_buffer_size)*max_connections = 6459167 K
bytes of memory
Hope that's ok; if not, decrease some variables in the equation.

thd=(nil)
Attempting backtrace. You can use the following information to find out
where mysqld died. If you see no messages after this, something went
terribly wrong...
frame pointer is NULL, did you compile with
-fomit-frame-pointer? Aborting backtrace!
The manual page at http://www.mysql.com/doc/en/Crashing.html contains
information that should help you find out what is causing the crash.

Number of processes running now: 0
EOF
chomp $big_arg;
$big_arg =~ s/\n+/ /g;

test_log_parser(
   parser => $p,
   file   => 'common/t/samples/errlogs/errlog008.txt',
   result => [
         {  Level => 'unknown',
            arg =>
               'InnoDB: Assertion failure in thread 1525901664 in file srv0srv.c line 2093 We intentionally generate a memory trap. Submit a detailed bug report to http://bugs.mysql.com. If you get repeated assertion failures or crashes, even immediately after the mysqld startup, there may be corruption in the InnoDB tablespace. Please refer to http://dev.mysql.com/doc/refman/5.0/en/forcing-recovery.html about forcing recovery.',
            pos_in_log => '0',
            ts         => '091205  4:49:04',
         },
         {  Level      => 'unknown',
            ts         => '091205  4:49:04',
            arg        => $big_arg,
            pos_in_log => '527',
         },
         {  Level      => 'unknown',
            arg        => 'mysqld restarted',
            pos_in_log => '1722',
            ts         => '091205 04:49:10'
         },
   ],
);

test_log_parser(
   parser  => $p,
   file    => 'common/t/samples/errlogs/errlog010.txt',
   oktorun => sub { $oktorun = $_[0]; },
   result  => [
      {
       pos_in_log => '0',
       ts         => '080816  7:53:17',
       Level      => 'error',
       arg        => '[ERROR] Cannot find table exampledb/exampletable from the internal data dictionary of InnoDB though the .frm file for the table exists. Maybe you have deleted and recreated InnoDB data files but have forgotten to delete the corresponding .frm files of InnoDB tables, or you have moved .frm files to another database? See http://dev.mysql.com/doc/refman/5.0/en/innodb-troubleshooting.html how you can resolve the problem.',
		},
   ],
);



# #############################################################################
# Done.
# #############################################################################
exit;
