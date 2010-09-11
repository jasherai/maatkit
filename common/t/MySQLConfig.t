#!/usr/bin/perl

BEGIN {
   die "The MAATKIT_WORKING_COPY environment variable is not set.  See http://code.google.com/p/maatkit/wiki/Testing"
      unless $ENV{MAATKIT_WORKING_COPY} && -d $ENV{MAATKIT_WORKING_COPY};
   unshift @INC, "$ENV{MAATKIT_WORKING_COPY}/common";
};

use strict;
use warnings FATAL => 'all';
use English qw(-no_match_vars);
use Test::More tests => 13;

use MySQLConfig;
use DSNParser;
use Sandbox;
use MaatkitTest;

my $dp  = new DSNParser(opts=>$dsn_opts);
my $sb  = new Sandbox(basedir => '/tmp', DSNParser => $dp);
my $dbh = $sb->get_dbh_for('master');

use Data::Dumper;
$Data::Dumper::Indent    = 1;
$Data::Dumper::Sortkeys  = 1;
$Data::Dumper::Quotekeys = 0;

my $config = new MySQLConfig();

my $output;
my $sample = "common/t/samples/configs/";

throws_ok(
   sub {
      $config->set_config(from=>'mysqld', file=>"fooz");
   },
   qr/Cannot open /,
   'set_config() dies if the file cannot be opened'
);

# #############################################################################
# Config from mysqld --help --verbose
# #############################################################################

$config->set_config(from=>'mysqld', file=>"$trunk/$sample/mysqldhelp001.txt");
is_deeply(
   $config->get_config(offline=>1),
   {
      abort_slave_event_count => '0',
      allow_suspicious_udfs => 'FALSE',
      auto_increment_increment => '1',
      auto_increment_offset => '1',
      automatic_sp_privileges => 'TRUE',
      back_log => '50',
      basedir => '/home/daniel/mysql_binaries/mysql-5.0.82-linux-x86_64-glibc23',
      bdb => 'FALSE',
      bind_address => '',
      binlog_cache_size => '32768',
      bulk_insert_buffer_size => '8388608',
      character_set_client_handshake => 'TRUE',
      character_set_filesystem => 'binary',
      character_set_server => 'latin1',
      character_sets_dir => '/home/daniel/mysql_binaries/mysql-5.0.82-linux-x86_64-glibc23/share/mysql/charsets/',
      chroot => '',
      collation_server => 'latin1_swedish_ci',
      completion_type => '0',
      concurrent_insert => '1',
      connect_timeout => '10',
      console => 'FALSE',
      datadir => '/tmp/12345/data/',
      date_format => '',
      datetime_format => '',
      default_character_set => 'latin1',
      default_collation => 'latin1_swedish_ci',
      default_time_zone => '',
      default_week_format => '0',
      delayed_insert_limit => '100',
      delayed_insert_timeout => '300',
      delayed_queue_size => '1000',
      des_key_file => '',
      disconnect_slave_event_count => '0',
      div_precision_increment => '4',
      enable_locking => 'FALSE',
      enable_pstack => 'FALSE',
      engine_condition_pushdown => 'FALSE',
      expire_logs_days => '0',
      external_locking => 'FALSE',
      federated => 'TRUE',
      flush_time => '0',
      ft_max_word_len => '84',
      ft_min_word_len => '4',
      ft_query_expansion_limit => '20',
      ft_stopword_file => '',
      gdb => 'FALSE',
      group_concat_max_len => '1024',
      help => 'TRUE',
      init_connect => '',
      init_file => '',
      init_slave => '',
      innodb => 'TRUE',
      innodb_adaptive_hash_index => 'TRUE',
      innodb_additional_mem_pool_size => '1048576',
      innodb_autoextend_increment => '8',
      innodb_buffer_pool_awe_mem_mb => '0',
      innodb_buffer_pool_size => '16777216',
      innodb_checksums => 'TRUE',
      innodb_commit_concurrency => '0',
      innodb_concurrency_tickets => '500',
      innodb_data_home_dir => '/tmp/12345/data',
      innodb_doublewrite => 'TRUE',
      innodb_fast_shutdown => '1',
      innodb_file_io_threads => '4',
      innodb_file_per_table => 'FALSE',
      innodb_flush_log_at_trx_commit => '1',
      innodb_flush_method => '',
      innodb_force_recovery => '0',
      innodb_lock_wait_timeout => '3',
      innodb_locks_unsafe_for_binlog => 'FALSE',
      innodb_log_arch_dir => '',
      innodb_log_buffer_size => '1048576',
      innodb_log_file_size => '5242880',
      innodb_log_files_in_group => '2',
      innodb_log_group_home_dir => '/tmp/12345/data',
      innodb_max_dirty_pages_pct => '90',
      innodb_max_purge_lag => '0',
      innodb_mirrored_log_groups => '1',
      innodb_open_files => '300',
      innodb_rollback_on_timeout => 'FALSE',
      innodb_status_file => 'FALSE',
      innodb_support_xa => 'TRUE',
      innodb_sync_spin_loops => '20',
      innodb_table_locks => 'TRUE',
      innodb_thread_concurrency => '8',
      innodb_thread_sleep_delay => '10000',
      innodb_use_legacy_cardinality_algorithm => 'TRUE',
      interactive_timeout => '28800',
      isam => 'FALSE',
      join_buffer_size => '131072',
      keep_files_on_create => 'FALSE',
      key_buffer_size => '16777216',
      key_cache_age_threshold => '300',
      key_cache_block_size => '1024',
      key_cache_division_limit => '100',
      language => '/home/daniel/mysql_binaries/mysql-5.0.82-linux-x86_64-glibc23/share/mysql/english/',
      large_pages => 'FALSE',
      lc_time_names => 'en_US',
      local_infile => 'TRUE',
      log => 'OFF',
      log_bin => 'mysql-bin',
      log_bin_index => '',
      log_bin_trust_function_creators => 'FALSE',
      log_bin_trust_routine_creators => 'FALSE',
      log_error => '',
      log_isam => 'myisam.log',
      log_queries_not_using_indexes => 'FALSE',
      log_short_format => 'FALSE',
      log_slave_updates => 'TRUE',
      log_slow_admin_statements => 'FALSE',
      log_slow_queries => 'OFF',
      log_tc => 'tc.log',
      log_tc_size => '24576',
      log_update => 'OFF',
      log_warnings => '1',
      long_query_time => '10',
      low_priority_updates => 'FALSE',
      lower_case_table_names => '0',
      master_connect_retry => '60',
      master_host => '',
      master_info_file => 'master.info',
      master_password => '',
      master_port => '3306',
      master_retry_count => '86400',
      master_ssl => 'FALSE',
      master_ssl_ca => '',
      master_ssl_capath => '',
      master_ssl_cert => '',
      master_ssl_cipher => '',
      master_ssl_key => '',
      master_user => 'test',
      max_allowed_packet => '1048576',
      max_binlog_cache_size => '18446744073709547520',
      max_binlog_dump_events => '0',
      max_binlog_size => '1073741824',
      max_connect_errors => '10',
      max_connections => '100',
      max_delayed_threads => '20',
      max_error_count => '64',
      max_heap_table_size => '16777216',
      max_join_size => '18446744073709551615',
      max_length_for_sort_data => '1024',
      max_prepared_stmt_count => '16382',
      max_relay_log_size => '0',
      max_seeks_for_key => '18446744073709551615',
      max_sort_length => '1024',
      max_sp_recursion_depth => '0',
      max_tmp_tables => '32',
      max_user_connections => '0',
      max_write_lock_count => '18446744073709551615',
      memlock => 'FALSE',
      merge => 'TRUE',
      multi_range_count => '256',
      myisam_block_size => '1024',
      myisam_data_pointer_size => '6',
      myisam_max_extra_sort_file_size => '2147483648',
      myisam_max_sort_file_size => '9223372036853727232',
      myisam_recover => 'OFF',
      myisam_repair_threads => '1',
      myisam_sort_buffer_size => '8388608',
      myisam_stats_method => 'nulls_unequal',
      ndb_autoincrement_prefetch_sz => '1',
      ndb_cache_check_time => '0',
      ndb_connectstring => '',
      ndb_force_send => 'TRUE',
      ndb_mgmd_host => '',
      ndb_nodeid => '0',
      ndb_optimized_node_selection => 'TRUE',
      ndb_shm => 'FALSE',
      ndb_use_exact_count => 'TRUE',
      ndb_use_transactions => 'TRUE',
      ndbcluster => 'FALSE',
      net_buffer_length => '16384',
      net_read_timeout => '30',
      net_retry_count => '10',
      net_write_timeout => '60',
      new => 'FALSE',
      old_passwords => 'FALSE',
      old_style_user_limits => 'FALSE',
      open_files_limit => '0',
      optimizer_prune_level => '1',
      optimizer_search_depth => '62',
      pid_file => '/tmp/12345/data/mysql_sandbox12345.pid',
      plugin_dir => '',
      port => '12345',
      port_open_timeout => '0',
      preload_buffer_size => '32768',
      profiling_history_size => '15',
      query_alloc_block_size => '8192',
      query_cache_limit => '1048576',
      query_cache_min_res_unit => '4096',
      query_cache_size => '0',
      query_cache_type => '1',
      query_cache_wlock_invalidate => 'FALSE',
      query_prealloc_size => '8192',
      range_alloc_block_size => '4096',
      read_buffer_size => '131072',
      read_only => 'FALSE',
      read_rnd_buffer_size => '262144',
      record_buffer => '131072',
      relay_log => 'mysql-relay-bin',
      relay_log_index => '',
      relay_log_info_file => 'relay-log.info',
      relay_log_purge => 'TRUE',
      relay_log_space_limit => '0',
      replicate_same_server_id => 'FALSE',
      report_host => '127.0.0.1',
      report_password => '',
      report_port => '12345',
      report_user => '',
      rpl_recovery_rank => '0',
      safe_user_create => 'FALSE',
      secure_auth => 'FALSE',
      secure_file_priv => '',
      server_id => '12345',
      show_slave_auth_info => 'FALSE',
      skip_grant_tables => 'FALSE',
      skip_slave_start => 'FALSE',
      slave_compressed_protocol => 'FALSE',
      slave_load_tmpdir => '/tmp/',
      slave_net_timeout => '3600',
      slave_transaction_retries => '10',
      slow_launch_time => '2',
      socket => '/tmp/12345/mysql_sandbox12345.sock',
      sort_buffer_size => '2097144',
      sporadic_binlog_dump_fail => 'FALSE',
      sql_mode => 'OFF',
      ssl => 'FALSE',
      ssl_ca => '',
      ssl_capath => '',
      ssl_cert => '',
      ssl_cipher => '',
      ssl_key => '',
      symbolic_links => 'TRUE',
      sync_binlog => '0',
      sync_frm => 'TRUE',
      sysdate_is_now => 'FALSE',
      table_cache => '64',
      table_lock_wait_timeout => '50',
      tc_heuristic_recover => '',
      temp_pool => 'TRUE',
      thread_cache_size => '0',
      thread_concurrency => '10',
      thread_stack => '262144',
      time_format => '',
      timed_mutexes => 'FALSE',
      tmp_table_size => '33554432',
      tmpdir => '',
      transaction_alloc_block_size => '8192',
      transaction_prealloc_size => '4096',
      updatable_views_with_limit => '1',
      use_symbolic_links => 'TRUE',
      verbose => 'TRUE',
      wait_timeout => '28800',
      warnings => '1'
   },
   'set_config(from=>mysqld, file=>mysqldhelp001.txt)'
);

is(
   $config->get('wait_timeout', offline=>1),
   28800,
   'get() from mysqld'
);

ok(
   $config->has('wait_timeout'),
   'has() from mysqld'
);

ok(
  !$config->has('foo'),
  "has(), doesn't have it"
);

# #############################################################################
# Config from SHOW VARIABLES
# #############################################################################

$config->set_config(from=>'show_variables', rows=>[ [qw(foo bar)], [qw(a z)] ]);
is_deeply(
   $config->get_config(),
   {
      foo => 'bar',
      a   => 'z',
   },
   'set_config(from=>show_variables, rows=>...)'
);

is(
   $config->get('foo'),
   'bar',
   'get() from show variables'
);

ok(
   $config->has('foo'),
   'has() from show variables'
);

# #############################################################################
# Config from my_print_defaults
# #############################################################################

$config->set_config(from=>'my_print_defaults',
   file=>"$trunk/$sample/myprintdef001.txt");

is(
   $config->get('port', offline=>1),
   '12349',
   "Duplicate var's last value used"
);

is(
   $config->get('innodb_buffer_pool_size', offline=>1),
   '16777216',
   'Converted size char to int'
);

is_deeply(
   $config->get_duplicate_variables(),
   {
      'port' => [12345],
   },
   'get_duplicate_variables()'
);

# #############################################################################
# Online tests.
# #############################################################################
SKIP: {
   skip 'Cannot connect to sandbox master', 2 unless $dbh;

   $config = new MySQLConfig();
   $config->set_config(from=>'show_variables', dbh=>$dbh);
   is(
      $config->get('datadir'),
      '/tmp/12345/data/',
      'set_config(from=>show_variables, dbh=>...)'
   );

   $config  = new MySQLConfig();
   my $rows = $dbh->selectall_arrayref('show variables');
   $config->set_config(from=>'show_variables', rows=>$rows);
   is(
      $config->get('datadir'),
      '/tmp/12345/data/',
      'set_config(from=>show_variables, rows=>...)'
   );
}

# #############################################################################
# Done.
# #############################################################################
exit;
