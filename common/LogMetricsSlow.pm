# This program is copyright 2008-@CURRENTYEAR@ Percona Inc.
# Feedback and improvements are welcome.
#
# THIS PROGRAM IS PROVIDED "AS IS" AND WITHOUT ANY EXPRESS OR IMPLIED
# WARRANTIES, INCLUDING, WITHOUT LIMITATION, THE IMPLIED WARRANTIES OF
# MERCHANTIBILITY AND FITNESS FOR A PARTICULAR PURPOSE.
#
# This program is free software; you can redistribute it and/or modify it under
# the terms of the GNU General Public License as published by the Free Software
# Foundation, version 2; OR the Perl Artistic License.  On UNIX and similar
# systems, you can issue `man perlgpl' or `man perlartistic' to read these
# licenses.
#
# You should have received a copy of the GNU General Public License along with
# this program; if not, write to the Free Software Foundation, Inc., 59 Temple
# Place, Suite 330, Boston, MA  02111-1307  USA.

# ###########################################################################
# LogMetricsSlow package $Revision$
# ###########################################################################
package LogMetricsSlow;

# All slow query log metric handlers:
#    metric name (identical to its name in the slow log)
#       metric type (string or number)
#       special handler options (e.g. [ all_events => 0, ] )
# For most numeric metrics, the default options are sufficient. Some
# string metrics, however, do not need to have all_events saved, etc.
my $slow_handlers = {
   'User' => {
      type => 'string',
      ops  => [
         all_events => 0,
      ],
   }, 
   'Host' => {
      type => 'string',
      ops  => [
         all_events => 0,
      ],
   }, 
   'Thread_id' => {
      type => 'string',
      ops => [
         all_events => 0,
      ],
   },
   'Schema' => {
      type => 'string',
      ops  => [
         all_events => 0,
      ],
   }, 
   'Query_time' => {
      type => 'number',
   }, 
   'Lock_time' => {
      type => 'number',
   }, 
   'Rows_sent' => {
      type => 'number',
   }, 
   'Rows_examined' => {
      type => 'number',
   }, 
   'Rows_affected' => {
      type => 'number',
   }, 
   'Rows_read' => {
      type => 'number',
   },
   'InnoDB_IO_r_ops' => {
      type => 'number',
   }, 
   'InnoDB_IO_r_bytes' => {
      type => 'number',
   }, 
   'InnoDB_IO_r_wait' => {
      type => 'number',
   }, 
   'InnoDB_rec_lock_wait' => {
      type => 'number',
   }, 
   'InnoDB_queue_wait' => {
      type => 'number',
   },
   'InnoDB_pages_distinct' => {
      type => 'number',
   },
   'QC_Hit' => {
      type => 'number',
      ops  => [
         min         => 0,
         max         => 0,
         avg         => 0,
         all_vals    => 0,
         all_events  => 0,
      ],
   },
   'Full_scan' => {
      type => 'number',
      ops  => [
         min         => 0,
         max         => 0,
         avg         => 0,
         all_vals    => 0,
         all_events  => 0,
      ],
   },
   'Full_join' => {
      type => 'number',
      ops  => [
         min         => 0,
         max         => 0,
         avg         => 0,
         all_vals    => 0,
         all_events  => 0,
      ],
   },
   'Tmp_table' => {
      type => 'number',
      ops  => [
         min         => 0,
         max         => 0,
         avg         => 0,
         all_vals    => 0,
         all_events  => 0,
      ],
   },
   'Tmp_table_on_disk' => {
      type => 'number',
      ops  => [
         min         => 0,
         max         => 0,
         avg         => 0,
         all_vals    => 0,
         all_events  => 0,
      ],
   },
   'Filesort' => {
      type => 'number',
      ops  => [
         min         => 0,
         max         => 0,
         avg         => 0,
         all_vals    => 0,
         all_events  => 0,
      ],
   },
   'Filesort_on_disk' => {
      type => 'number',
      ops  => [
         min         => 0,
         max         => 0,
         avg         => 0,
         all_vals    => 0,
         all_events  => 0,
      ],
   },
   'Merge_passes' => {
      type => 'number',
   },
};

sub new {
   my ( $class ) = @_;
   bless {}, $class;
}

sub get_all_metrics {
   my ( $self ) = @_;
   return keys %$slow_handlers;
}

sub get_handlers_for {
   my ( $self, @metrics ) = @_;
   my @handlers;
   foreach my $metric ( @metrics ) {
      next if !exists $slow_handlers->{$metric};
      push @handlers, SQLMetrics::make_handler_for($metric,
         $slow_handlers->{$metric}->{type},
         @{$slow_handlers->{$metric}->{ops}});
   }
   return @handlers;
}

1;
# ###########################################################################
# End LogMetricsSlow package
# ###########################################################################
