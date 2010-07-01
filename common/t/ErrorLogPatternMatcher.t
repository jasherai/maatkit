#!/usr/bin/perl

BEGIN {
   die "The MAATKIT_WORKING_COPY environment variable is not set.  See http://code.google.com/p/maatkit/wiki/Testing"
      unless $ENV{MAATKIT_WORKING_COPY} && -d $ENV{MAATKIT_WORKING_COPY};
   unshift @INC, "$ENV{MAATKIT_WORKING_COPY}/common";
};

use strict;
use warnings FATAL => 'all';
use English qw(-no_match_vars);
use Test::More tests => 11;

use QueryRewriter;
use ErrorLogPatternMatcher;
use ErrorLogParser;
use MaatkitTest;

my $qr = new QueryRewriter();
my $p  = new ErrorLogParser();
my $m  = new ErrorLogPatternMatcher();

isa_ok($m, 'ErrorLogPatternMatcher');

my $output;

sub parse {
   my ( $file ) = @_;
   $file = "$trunk/$file";
   my @e;
   my @m;
   open my $fh, "<", $file or die $OS_ERROR;
   my %args = (
      fh      => $fh,
   );
   while ( my $e = $p->parse_event(%args) ) {
      next unless $e;
      push @m, $m->match(
         event       => $e,
      );
   }
   close $fh;
   return \@m;
}

is_deeply(
   parse('common/t/samples/errlogs/errlog001.txt', $p),
   [
      {
        Level        => 'unknown',
        New_pattern  => 'Yes',
        Pattern_no   => 0,
        Pattern      => 'mysqld started',
        arg          => 'mysqld started',
        pos_in_log   => 0,
        ts           => '080721 03:03:57'
      },
      {
        New_pattern  => 'Yes',
        Level        => 'warning',
        Pattern_no   => 1,
        Pattern      => '\[Warning\] option \'log_slow_rate_limit\': unsigned value \d+ adjusted to \d+',
        arg          => '[Warning] option \'log_slow_rate_limit\': unsigned value 0 adjusted to 1',
        pos_in_log   => 32,
        ts           => '080721  3:04:00'
      },
      {
        New_pattern  => 'Yes',
        Pattern_no   => 2,
        Pattern      => '\[ERROR\] /usr/sbin/mysqld: unknown variable \'ssl-key=/opt/mysql\.pdns/\.cert/server-key\.pem\'',
        Level        => 'error',
        arg          => '[ERROR] /usr/sbin/mysqld: unknown variable \'ssl-key=/opt/mysql.pdns/.cert/server-key.pem\'',
        pos_in_log   => 119,
        ts           => '080721  3:04:01'
      },
      {
        New_pattern  => 'Yes',
        Level        => 'unknown',
        Pattern_no   => 3,
        Pattern      => 'mysqld ended',
        arg          => 'mysqld ended',
        pos_in_log   => 225,
        ts           => '080721 03:04:01'
      },
      {
        New_pattern  => 'No',
        Level        => 'unknown',
        Pattern_no   => 0,
        Pattern      => 'mysqld started',
        arg          => 'mysqld started',
        pos_in_log   => 255,
        ts           => '080721 03:10:57'
      },
      {
        New_pattern  => 'Yes',
        Level        => 'warning',
        Pattern_no   => 4,
        Pattern      => '\[Warning\] No argument was provided to --log-bin, and --log-bin-index was not used; so replication may break when this MySQL server acts as a master and has his hostname changed!! Please use \'--log-bin=/var/run/mysqld/mysqld-bin\' to avoid this problem\.',
        arg          => '[Warning] No argument was provided to --log-bin, and --log-bin-index was not used; so replication may break when this MySQL server acts as a master and has his hostname changed!! Please use \'--log-bin=/var/run/mysqld/mysqld-bin\' to avoid this problem.',
        pos_in_log   => 288,
        ts           => '080721  3:10:58'
      },
      {
        New_pattern  => 'Yes',
        Level        => 'unknown',
        Pattern_no   => 5,
        Pattern      => 'InnoDB: Started; log sequence number \d+ \d+',
        arg          => 'InnoDB: Started; log sequence number 1 3703096531',
        pos_in_log   => 556,
        ts           => '080721  3:11:08'
      },
      {
        New_pattern  => 'Yes',
        Level        => 'warning',
        Pattern_no   => 6,
        Pattern      => '\[Warning\] Neither --relay-log nor --relay-log-index were used; so replication may break when this MySQL server acts as a slave and has his hostname changed!! Please use \'--relay-log=/var/run/mysqld/mysqld-relay-bin\' to avoid this problem\.',
        arg          => '[Warning] Neither --relay-log nor --relay-log-index were used; so replication may break when this MySQL server acts as a slave and has his hostname changed!! Please use \'--relay-log=/var/run/mysqld/mysqld-relay-bin\' to avoid this problem.',
        pos_in_log   => 878,
        ts           => '080721  3:11:12'
      },
      {
        New_pattern  => 'Yes',
        Pattern_no   => 7,
        Pattern      => '\[ERROR\] Failed to open the relay log \'\./srv-relay-bin\.\d+\' \(relay_log_pos \d+\)',
        Level        => 'error',
        arg          => '[ERROR] Failed to open the relay log \'./srv-relay-bin.000001\' (relay_log_pos 4)',
        pos_in_log   => 878,
        ts           => '080721  3:11:12'
      },
      {
        New_pattern  => 'Yes',
        Pattern_no   => 8,
        Pattern      => '\[ERROR\] Could not find target log during relay log initialization',
        Level        => 'error',
        arg          => '[ERROR] Could not find target log during relay log initialization',
        pos_in_log   => 974,
        ts           => '080721  3:11:12'
      },
      {
        New_pattern  => 'Yes',
        Pattern_no   => 9,
        Pattern      => '\[ERROR\] Failed to initialize the master info structure',
        Level        => 'error',
        arg          => '[ERROR] Failed to initialize the master info structure',
        pos_in_log   => 1056,
        ts           => '080721  3:11:12'
      },
      {
        New_pattern  => 'Yes',
        Level        => 'info',
        Pattern_no   => 10,
        Pattern      => '\[Note\] /usr/libexec/mysqld: ready for connections\.',
        arg          => '[Note] /usr/libexec/mysqld: ready for connections.',
        pos_in_log   => 1127,
        ts           => '080721  3:11:12'
      },
      {
        New_pattern  => 'Yes',
        Level        => 'unknown',
        Pattern_no   => 11,
        Pattern      => 'Version: \'\d+\.\d+\.\d+-log\' socket: \'/mnt/data/mysql/mysql\.sock\'  port: \d+  Source distribution',
        arg          => 'Version: \'5.0.45-log\' socket: \'/mnt/data/mysql/mysql.sock\'  port: 3306  Source distribution',
        pos_in_log   => 1194
      },
      {
        New_pattern  => 'Yes',
        Level        => 'info',
        Pattern_no   => 12,
        Pattern      => '\[Note\] /usr/libexec/mysqld: Normal shutdown',
        arg          => '[Note] /usr/libexec/mysqld: Normal shutdown',
        pos_in_log   => 1287,
        ts           => '080721  9:22:14'
      },
      {
        New_pattern  => 'Yes',
        Level        => 'unknown',
        Pattern_no   => 13,
        Pattern      => 'InnoDB: Starting shutdown\.\.\.',
        arg          => 'InnoDB: Starting shutdown...',
        pos_in_log   => 1347,
        ts           => '080721  9:22:17'
      },
      {
        New_pattern  => 'Yes',
        Level        => 'unknown',
        Pattern_no   => 14,
        Pattern      => 'InnoDB: Shutdown completed; log sequence number \d+ \d+',
        arg          => 'InnoDB: Shutdown completed; log sequence number 1 3703096531',
        pos_in_log   => 1472,
        ts           => '080721  9:22:20'
      },
      {
        New_pattern  => 'Yes',
        Level        => 'info',
        Pattern_no   => 15,
        Pattern      => '\[Note\] /usr/libexec/mysqld: Shutdown complete',
        arg          => '[Note] /usr/libexec/mysqld: Shutdown complete',
        pos_in_log   => 1534,
        ts           => '080721  9:22:20'
      },
      {
        New_pattern  => 'No',
        Level        => 'unknown',
        Pattern_no   => 3,
        Pattern      => 'mysqld ended',
        arg          => 'mysqld ended',
        pos_in_log   => 1534,
        ts           => '080721 09:22:22'
      },
      {
        New_pattern  => 'No',
        Level        => 'unknown',
        Pattern_no   => 0,
        Pattern      => 'mysqld started',
        arg          => 'mysqld started',
        pos_in_log   => 1565,
        ts           => '080721 09:22:31'
      },
      {
        New_pattern  => 'No',
        Level        => 'unknown',
        Pattern_no   => 11,
        Pattern      => 'Version: \'\d+\.\d+\.\d+-log\' socket: \'/mnt/data/mysql/mysql\.sock\'  port: \d+  Source distribution',
        arg          => 'Version: \'5.0.45-log\' socket: \'/mnt/data/mysql/mysql.sock\'  port: 3306  Source distribution',
        pos_in_log   => 1598
      },
      {
        New_pattern  => 'Yes',
        Pattern_no   => 16,
        Pattern      => '\[ERROR\] bdb: log_archive: DB_ARCH_ABS: DB_NOTFOUND: No matching key/data pair found',
        Level        => 'error',
        arg          => '[ERROR] bdb: log_archive: DB_ARCH_ABS: DB_NOTFOUND: No matching key/data pair found',
        pos_in_log   => 1691,
        ts           => '080721  9:34:22'
      },
      {
        New_pattern  => 'No',
        Level        => 'unknown',
        Pattern_no   => 0,
        Pattern      => 'mysqld started',
        arg          => 'mysqld started',
        pos_in_log   => 1792,
        ts           => '080721 09:39:09'
      },
      {
        New_pattern  => 'No',
        Level        => 'unknown',
        Pattern_no   => 5,
        Pattern      => 'InnoDB: Started; log sequence number \d+ \d+',
        arg          => 'InnoDB: Started; log sequence number 1 3703096531',
        pos_in_log   => 1825,
        ts           => '080721  9:39:14'
      },
      { # 23
        New_pattern  => 'No',
        Level        => 'unknown',
        Pattern_no   => 0,
        Pattern      => 'mysqld started',
        arg          => 'mysqld started',
        pos_in_log   => 1924,
        ts           => '080821 19:14:12'
      },
      {
        New_pattern  => 'Yes',
        Level        => 'unknown',
        Pattern_no   => 17,
        Pattern      => 'InnoDB: Database was not shut down normally! Starting crash recovery\. Reading tablespace information from the \.ibd files\.\.\. Restoring possible half-written data pages from the doublewrite buffer\.\.\.',
        arg          => 'InnoDB: Database was not shut down normally! Starting crash recovery. Reading tablespace information from the .ibd files... Restoring possible half-written data pages from the doublewrite buffer...',
        pos_in_log   => 1924,
        ts           => '080821 19:14:12'
      },
      {
        New_pattern  => 'Yes',
        Level        => 'unknown',
        Pattern_no   => 18,
        Pattern      => 'InnoDB: Starting log scan based on checkpoint at log sequence number \d+ \d+\. Doing recovery: scanned up to log sequence number \d+ \d+ Last MySQL binlog file position \d+ \d+, file name \./srv-bin\.\d+',
        arg          => 'InnoDB: Starting log scan based on checkpoint at log sequence number 1 3703467071. Doing recovery: scanned up to log sequence number 1 3703467081 Last MySQL binlog file position 0 804759240, file name ./srv-bin.000012',
        pos_in_log   => 2237,
        ts           => '080821 19:14:13'
      },
      {
        New_pattern  => 'No',
        Level        => 'unknown',
        Pattern_no   => 5,
        Pattern      => 'InnoDB: Started; log sequence number \d+ \d+',
        arg          => 'InnoDB: Started; log sequence number 1 3703467081',
        pos_in_log   => 2497,
        ts           => '080821 19:14:13'
      },
      {
        New_pattern  => 'Yes',
        Level        => 'info',
        Pattern_no   => 19,
        Pattern      => '\[Note\] Recovering after a crash using srv-bin',
        arg          => '[Note] Recovering after a crash using srv-bin',
        pos_in_log   => 2559,
        ts           => '080821 19:14:13'
      },
      {
        New_pattern  => 'Yes',
        Level        => 'info',
        Pattern_no   => 20,
        Pattern      => '\[Note\] Starting crash recovery\.\.\.',
        arg          => '[Note] Starting crash recovery...',
        pos_in_log   => 2559,
        ts           => '080821 19:14:23'
      },
      {
        New_pattern  => 'Yes',
        Level        => 'info',
        Pattern_no   => 21,
        Pattern      => '\[Note\] Crash recovery finished\.',
        arg          => '[Note] Crash recovery finished.',
        pos_in_log   => 2609,
        ts           => '080821 19:14:23'
      },
      {
        New_pattern  => 'No',
        Level        => 'unknown',
        Pattern_no   => 11,
        Pattern      => 'Version: \'\d+\.\d+\.\d+-log\' socket: \'/mnt/data/mysql/mysql\.sock\'  port: \d+  Source distribution',
        arg          => 'Version: \'5.0.45-log\' socket: \'/mnt/data/mysql/mysql.sock\'  port: 3306  Source distribution',
        pos_in_log   => 2657
      },
      {
        New_pattern  => 'Yes',
        Level        => 'info',
        Pattern_no   => 22,
        Pattern      => '\[Note\] Found \d+ of \d+ rows when repairing \'\./test/a3\'',
        arg          => '[Note] Found 5 of 0 rows when repairing \'./test/a3\'',
        pos_in_log   => 2750,
        ts           => '080911 18:04:40'
      },
      {
        New_pattern  => 'No',
        Level        => 'info',
        Pattern_no   => 10,
        Pattern      => '\[Note\] /usr/libexec/mysqld: ready for connections\.',
        arg          => '[Note] /usr/libexec/mysqld: ready for connections.',
        pos_in_log   => 2818,
        ts           => '081101  9:17:53'
      },
      {
        New_pattern  => 'No',
        Level        => 'unknown',
        Pattern_no   => 11,
        Pattern      => 'Version: \'\d+\.\d+\.\d+-log\' socket: \'/mnt/data/mysql/mysql\.sock\'  port: \d+  Source distribution',
        arg          => 'Version: \'5.0.45-log\' socket: \'/mnt/data/mysql/mysql.sock\'  port: 3306  Source distribution',
        pos_in_log   => 2886
      },
      { # 34
        New_pattern  => 'Yes',
        Level        => 'unknown',
        Pattern_no   => 23,
        Pattern      => 'Number of processes running now: \d+',
        arg          => 'Number of processes running now: 0',
        pos_in_log   => 2979
      },
      {
        New_pattern  => 'Yes',
        Level        => 'unknown',
        Pattern_no   => 24,
        Pattern      => 'mysqld restarted',
        arg          => 'mysqld restarted',
        pos_in_log   => 3015,
        ts           => '081117 16:15:07'
      },
      {
        New_pattern  => 'Yes',
        Pattern_no   => 25,
        Level        => 'error',
        Pattern      => 'InnoDB: Error: cannot allocate \d+ bytes of memory with malloc! Total allocated memory by InnoDB \d+ bytes\. Operating system errno: \d+ Check if you should increase the swap file or ulimits of your operating system\. On FreeBSD check you have compiled the OS with a big enough maximum process size\. Note that in most \d+-bit computers the process memory space is limited to \d+ GB or \d+ GB\. We keep retrying the allocation for \d+ seconds\.\.\. Fatal error: cannot allocate the memory for the buffer pool',
        arg          => 'InnoDB: Error: cannot allocate 268451840 bytes of memory with malloc! Total allocated memory by InnoDB 8074720 bytes. Operating system errno: 12 Check if you should increase the swap file or ulimits of your operating system. On FreeBSD check you have compiled the OS with a big enough maximum process size. Note that in most 32-bit computers the process memory space is limited to 2 GB or 4 GB. We keep retrying the allocation for 60 seconds... Fatal error: cannot allocate the memory for the buffer pool',
        pos_in_log   => 3049,
        ts           => '081117 16:15:16'
      },
      {
        New_pattern  => 'No',
        Level        => 'info',
        Pattern_no   => 10,
        Pattern      => '\[Note\] /usr/libexec/mysqld: ready for connections\.',
        arg          => '[Note] /usr/libexec/mysqld: ready for connections.',
        pos_in_log   => 3718,
        ts           => '081117 16:32:55'
      },
   ],
   'errlog001.txt'
);

$m = new ErrorLogPatternMatcher(QueryRewriter => $qr);
is_deeply(
   parse('common/t/samples/errlogs/errlog002.txt', $p),
   [
      {
         New_pattern => 'Yes',
         Level       => 'info',
         Pattern     => '\[Note\] Slave SQL thread initialized, starting replication in log \'mpb-bin\.\d+\' at position \d+, relay log \'\./web-relay-bin\.\d+\' position: \d+',
         Pattern_no  => 0,
         arg         => '[Note] Slave SQL thread initialized, starting replication in log \'mpb-bin.000519\' at position 4, relay log \'./web-relay-bin.000001\' position: 4',
         pos_in_log  => 0,
         ts          => '090902  8:15:00'
      },
      {
         New_pattern => 'Yes',
         Level       => 'warning',
         Pattern     => '\[Warning\] Statement may not be safe to log in statement format\. Statement: insert ignore into fud\?_search_cache \(srch_query, query_type, expiry, msg_id, n_match\) select \?, \?, \?, msg_id, count\(\*\) as word_count from fud\?_search s inner join fud\?_index i on i\.word_id=s\.id where word in\(\?\+\) group by msg_id order by word_count desc limit \?',
         Pattern_no  => 1,
         arg         => '[Warning] Statement may not be safe to log in statement format. Statement: INSERT IGNORE INTO fud26_search_cache (srch_query, query_type, expiry, msg_id, n_match) SELECT \'eb081c4be7a9fd8c5aa647f44e6e6365\', 0, 1250326725, msg_id, count(*) as word_count FROM fud26_search s INNER JOIN fud26_index i ON i.word_id=s.id WHERE word IN(\'ejgkkvqduyhzjqwynkf\') GROUP BY msg_id ORDER BY word_count DESC LIMIT 500',
         pos_in_log  => 160,
         ts          => '090902  8:40:46'
      },
      {
         New_pattern => 'No',
         Level       => 'warning',
         Pattern     => '\[Warning\] Statement may not be safe to log in statement format\. Statement: insert ignore into fud\?_search_cache \(srch_query, query_type, expiry, msg_id, n_match\) select \?, \?, \?, msg_id, count\(\*\) as word_count from fud\?_search s inner join fud\?_index i on i\.word_id=s\.id where word in\(\?\+\) group by msg_id order by word_count desc limit \?',
         Pattern_no  => 1,
         arg         => '[Warning] Statement may not be safe to log in statement format. Statement: INSERT IGNORE INTO fud26_search_cache (srch_query, query_type, expiry, msg_id, n_match) SELECT \'89b76d476dcf711b813a14f8c52df840\', 0, 1250328053, msg_id, count(*) as word_count FROM fud26_search s INNER JOIN fud26_index i ON i.word_id=s.id WHERE word IN(\'heicvrxtljqlth\') GROUP BY msg_id ORDER BY word_count DESC LIMIT 500',
         pos_in_log  => 579,
         ts          => '090902  8:40:52'
      },
      {
       New_pattern   => 'No',
       Level         => 'warning',
       Pattern       => '\[Warning\] Statement may not be safe to log in statement format\. Statement: insert ignore into fud\?_search_cache \(srch_query, query_type, expiry, msg_id, n_match\) select \?, \?, \?, msg_id, count\(\*\) as word_count from fud\?_search s inner join fud\?_index i on i\.word_id=s\.id where word in\(\?\+\) group by msg_id order by word_count desc limit \?',
       Pattern_no    => 1,
       arg           => '[Warning] Statement may not be safe to log in statement format. Statement: INSERT IGNORE INTO fud26_search_cache (srch_query, query_type, expiry, msg_id, n_match) SELECT \'895e2ddda332df8d230a9370f6db2ec4\', 0, 1250333052, msg_id, count(*) as word_count FROM fud26_search s INNER JOIN fud26_index i ON i.word_id=s.id WHERE word IN(\'postgresql\') GROUP BY msg_id ORDER BY word_count DESC LIMIT 500',
       pos_in_log    => 993,
       ts            => '090902  8:41:00'
      },
   ],
   'errlog002.txt - fingerprint Statement: query'
);

# ############################################################################
# Load patterns.
# ############################################################################
$m = new ErrorLogPatternMatcher(QueryRewriter => $qr);
my @patterns = $m->patterns;
is_deeply(
   \@patterns,
   [],
   'Does not load known patterns by default'
);

open my $fh, '<', "$trunk/common/t/samples/errlogs/patterns.txt"
   or die "Cannot open $trunk/common/t/samples/errlogs/patterns.txt: $OS_ERROR";
$m->load_patterns_file($fh);
@patterns = $m->patterns;
is_deeply(
   \@patterns,
   [
      '^foo',
      'mysql got signal \d',
   ],
   'Load patterns file'
);

@patterns = $m->names;
is(
   $patterns[0],
   'pattern1',
   'names'
);

@patterns = $m->levels;
is(
   $patterns[0],
   'info',
   'levels'
);

# #############################################################################
# Reset patterns.
# #############################################################################

# This assumes that some patterns have been loaded from above.
$m->reset_patterns();

@patterns = $m->patterns;
is_deeply(
   \@patterns,
   [],
   'Reset patterns'
);

@patterns = $m->names;
is_deeply(
   \@patterns,
   [],
   'Reset names'
);

@patterns = $m->levels;
is_deeply(
   \@patterns,
   [],
   'Reset levels'
);

# #############################################################################
# Done.
# #############################################################################
$output = '';
{
   local *STDERR;
   open STDERR, '>', \$output;
   $m->_d('Complete test coverage');
}
like(
   $output,
   qr/Complete test coverage/,
   '_d() works'
);
exit;
