#!/usr/bin/perl

use strict;
use warnings FATAL => 'all';
use English qw(-no_match_vars);
use Test::More tests => 2;

require "../InnoDBStatusParser.pm";

use Data::Dumper;
$Data::Dumper::Indent    = 1;
$Data::Dumper::Sortkeys  = 1;
$Data::Dumper::Quotekeys = 0;

sub load_file {
   my ($file) = @_;
   open my $fh, "<", $file or die $!;
   my $contents = do { local $/ = undef; <$fh> };
   close $fh;
   return $contents;
};

my $is = new InnoDBStatusParser();
isa_ok($is, 'InnoDBStatusParser');

# Very basic status on quiet sandbox server.
is_deeply(
   $is->parse_status_text(load_file('samples/is001.txt'), 0, {}, 0),
   {
        got_all => 1,
        last_secs => '37',
        sections => {
          bp => {
            add_pool_alloc => '675584',
            awe_mem_alloc => 0,
            buf_free => '333',
            buf_pool_hit_rate => '1000 / 1000',
            buf_pool_hits => '1000',
            buf_pool_reads => '1000',
            buf_pool_size => '512',
            complete => 1,
            dict_mem_alloc => 0,
            page_creates_sec => '0.00',
            page_reads_sec => '0.00',
            page_writes_sec => '0.43',
            pages_created => '178',
            pages_modified => '0',
            pages_read => '0',
            pages_total => '178',
            pages_written => '189',
            reads_pending => '0',
            total_mem_alloc => '20634452',
            writes_pending => '0',
            writes_pending_flush_list => 0,
            writes_pending_lru => 0,
            writes_pending_single_page => 0
          },
          ib => {
            bufs_in_node_heap => '1',
            complete => 1,
            free_list_len => '0',
            hash_searches_s => '0.00',
            hash_table_size => '17393',
            inserts => '0',
            merged_recs => '0',
            merges => '0',
            non_hash_searches_s => '0.00',
            seg_size => '2',
            size => '1',
            used_cells => '0'
          },
          io => {
            avg_bytes_s => '0',
            complete => 1,
            flush_type => 'fsync',
            fsyncs_s => '0.08',
            os_file_reads => '0',
            os_file_writes => '38',
            os_fsyncs => '16',
            pending_aio_writes => '0',
            pending_buffer_pool_flushes => '0',
            pending_ibuf_aio_reads => '0',
            pending_log_flushes => '0',
            pending_log_ios => '0',
            pending_normal_aio_reads => '0',
            pending_preads => 0,
            pending_pwrites => 0,
            pending_sync_ios => '0',
            reads_s => '0.00',
            threads => {
              '0' => {
                event_set => 0,
                purpose => 'insert buffer thread',
                state => 'waiting for i/o request',
                thread => '0'
              },
              '1' => {
                event_set => 0,
                purpose => 'log thread',
                state => 'waiting for i/o request',
                thread => '1'
              },
              '2' => {
                event_set => 0,
                purpose => 'read thread',
                state => 'waiting for i/o request',
                thread => '2'
              },
              '3' => {
                event_set => 0,
                purpose => 'write thread',
                state => 'waiting for i/o request',
                thread => '3'
              }
            },
            writes_s => '0.14'
          },
          lg => {
            complete => 1,
            last_chkp => '0 43655',
            log_flushed_to => '0 43655',
            log_ios_done => '11',
            log_ios_s => '0.03',
            log_seq_no => '0 43655',
            pending_chkp_writes => '0',
            pending_log_writes => '0'
          },
          ro => {
            complete => 1,
            del_sec => '0.00',
            ins_sec => '0.00',
            main_thread_id => '140284306659664',
            main_thread_proc_no => '4257',
            main_thread_state => 'waiting for server activity',
            n_reserved_extents => 0,
            num_rows_del => '0',
            num_rows_ins => '0',
            num_rows_read => '0',
            num_rows_upd => '0',
            queries_in_queue => '0',
            queries_inside => '0',
            read_sec => '0.00',
            read_views_open => '1',
            upd_sec => '0.00'
          },
          sm => {
            complete => 1,
            mutex_os_waits => '0',
            mutex_spin_rounds => '2',
            mutex_spin_waits => '0',
            reservation_count => '7',
            rw_excl_os_waits => '0',
            rw_excl_spins => '0',
            rw_shared_os_waits => '7',
            rw_shared_spins => '14',
            signal_count => '7',
            wait_array_size => 0,
            waits => []
          },
          tx => {
            complete => 1,
            history_list_len => 0,
            is_truncated => 0,
            num_lock_structs => '0',
            purge_done_for => '0 0',
            purge_undo_for => '0 0',
            transactions => [
              {
                active_secs => 0,
                has_read_view => 0,
                heap_size => 0,
                hostname => 'localhost',
                ip => '',
                lock_structs => 0,
                lock_wait_status => '',
                lock_wait_time => 0,
                mysql_thread_id => '3',
                os_thread_id => '140284242860368',
                proc_no => '4257',
                query_id => '11',
                query_status => '',
                query_text => 'show innodb status',
                row_locks => 0,
                tables_in_use => 0,
                tables_locked => 0,
                thread_decl_inside => 0,
                thread_status => '',
                txn_doesnt_see_ge => '',
                txn_id => '0 0',
                txn_sees_lt => '',
                txn_status => 'not started',
                undo_log_entries => 0,
                user => 'msandbox'
              }
            ],
            trx_id_counter => '0 769'
          }
        },
        timestring => '2009-07-07 13:18:38',
        ts => [
          2009,
          '07',
          '07',
          13,
          18,
          38
        ]
   },
   'Basic InnoDB status'
);

# #############################################################################
# Done.
# #############################################################################
exit;
