# This program is copyright 2008-2009 Percona Inc.
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
# InstanceReporter package $Revision$
# ###########################################################################
package InstanceReporter;

use strict;
use warnings FATAL => 'all';
use English qw(-no_match_vars);

Transformers->import(qw());

use constant MKDEBUG     => $ENV{MKDEBUG};
use constant LINE_LENGTH => 74;

sub new {
   my ( $class, %args ) = @_;
   my $self = {};
   return bless $self, $class;
}

sub report {
   my ( $self, %args ) = @_;
   foreach my $arg ( qw(mi n ps schema ma o) ) {
      die "I need a $arg argument" unless $args{$arg};
   }
   my $mi     = $args{mi};
   my $n      = $args{n};
   my $ps     = $args{ps};
   my $schema = $args{schema};
   my $ma     = $args{ma};
   my $o      = $args{o};

format MYSQL_INSTANCE_1 =

____________________________________________________________ MySQL Instance @>>
$n
   Version:  @<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<< Architecture: @<-bit
$mi->{online_sys_vars}->{version}, $mi->{regsize}
   Uptime:   @<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<
secs_to_time($mi->{status_vals}->{Uptime})
   ps vals:  user @<<<<<<< cpu% @<<<<< rss @<<<<<< vsz @<<<<<< syslog: @<<
$ps->{user}, $ps->{pcpu}, shorten($ps->{rss} * 1024), shorten($ps->{vsz} * 1024), $ps->{syslog}
   Bin:      @<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<
$mi->{mysqld_binary}
   Data dir: @<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<
$mi->{online_sys_vars}->{datadir}
   PID file: @<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<
$mi->{online_sys_vars}->{pid_file}
   Socket:   @<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<
$mi->{online_sys_vars}->{'socket'}
   Port:     @<<<<<<
$mi->{online_sys_vars}->{port}
   Log locations:
      Error:  @<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<
$mi->{conf_sys_vars}->{log_error} || ''
      Relay:  @<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<
$mi->{conf_sys_vars}->{relay_log} || ''
      Slow:   @<<<<<< @<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<
micro_t($mi->{online_sys_vars}->{long_query_time}), $mi->{conf_sys_vars}->{log_slow_queries} || 'OFF'
   Config file location: @<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<
$mi->{cmd_line_ops}->{defaults_file}

   SCHEMA ________________________________________________________________
      #DATABASES   #TABLES   #ROWS     #INDEXES   SIZE DATA   SIZE INDEXES
      @<<<<<<      @<<<<<<   @<<<<<<   @<<<<<<    @<<<<<<     @<<<<<<
$schema->{counts}->{TOTAL}->{dbs}, $schema->{counts}->{TOTAL}->{tables}, shorten($schema->{counts}->{TOTAL}->{rows}, d=>1000), $schema->{counts}->{TOTAL}->{indexes} || 'NA', shorten($schema->{counts}->{TOTAL}->{data_size}), shorten($schema->{counts}->{TOTAL}->{index_size})

      Key buffer size        : @<<<<<<
shorten($mi->{online_sys_vars}->{key_buffer_size})
      InnoDB buffer pool size: @<<<<<<
exists $mi->{online_sys_vars}->{innodb_buffer_pool_size} ? shorten($mi->{online_sys_vars}->{innodb_buffer_pool_size}) : ''

.
   # Print the above format
   $FORMAT_NAME = 'MYSQL_INSTANCE_1';
   write;

   dbs_size_summary($schema, $o);
   tables_size_summary($schema, $o);
   engines_summary($schema, $o);
   tre_summary($schema, $o);

   print "\n   PROBLEMS ______________________________________________________________\n";

   my $duplicates = $mi->duplicate_sys_vars();
   if ( scalar @{ $duplicates } ) {
      print "\tDuplicate system variables in config file:\n";
      print "\tVARIABLE\n";
      foreach my $var ( @{ $duplicates } ) {
         print "\t$var\n";
      }
      print "\n";
   }

   my $three_cols = "\t%-20.20s  %-24.24s  %-24.24s\n";

   my $overridens = $mi->overriden_sys_vars();
   if ( scalar keys %{ $overridens } ) {
      print "\tOverridden system variables "
         . "(cmd line value overrides config value):\n";
      printf($three_cols, 'VARIABLE', 'CMD LINE VALUE', 'CONFIG VALUE');
      foreach my $var ( keys %{ $overridens } ) {
         printf($three_cols,
                $var,
                $overridens->{$var}->[0],
                $overridens->{$var}->[1]);
      }
      print "\n";
   }

   my $oos = $mi->out_of_sync_sys_vars();
   if ( scalar keys %{ $oos } ) {
      print "\tOut of sync system variables "
         . "(online value differs from config value):\n";
      printf($three_cols, 'VARIABLE', 'ONLINE VALUE', 'CONFIG VALUE');
      foreach my $var ( keys %{ $oos } ) {
         printf($three_cols,
                $var,
                $oos->{$var}->{online},
                $oos->{$var}->{config});
      }
      print "\n";
   }

   my $failed_checks = $ma->run_checks();
   if ( scalar keys %{ $failed_checks } ) {
      print "\tThings to Note:\n";
      foreach my $check_name ( keys %{ $failed_checks } ) {
         print "\t\t- $failed_checks->{$check_name}\n";
      }
   }

   return;
}

sub dbs_size_summary {
   my ( $schema, $o ) = @_;
   my %dbs = %{ $schema->{counts}->{dbs} }; # copy we can chop
   my $top = $o->get('top');
   my @sorted;
   my ( $db, $size );
   print   "      Top $top largest databases:\n"
         . "         DATABASE             SIZE DATA\n";
format DB_LINE =
         @<<<<<<<<<<<<<<<<<   @<<<<<<<<<<<<<<<<<<<<<<<<<<<
$db, $size
.
   @sorted = sort { $dbs{$b}->{data_size} <=> $dbs{$a}->{data_size} } keys %dbs;
   $FORMAT_NAME = 'DB_LINE';
   foreach $db ( @sorted ) {
      $size = shorten($dbs{$db}->{data_size});
      write;
      delete $dbs{$db};
      last if !--$top;
   }
   my $n_remaining = 0;
   my $r_size      = 0;
   my $r_avg       = 0;
   foreach my $db ( keys %dbs ) {
      $n_remaining++;
      $r_size += $dbs{$db}->{data_size};
   }
   if($n_remaining) {
      $r_avg = shorten($r_size / $n_remaining);
      $r_size = shorten($r_size);
      $db   = "Remaining $n_remaining";
      $size = "$r_size ($r_avg average)";
      write;
   }
   return;
}

sub tables_size_summary {
   my ( $schema, $o ) = @_;
   my %dbs_tbls;
   my $dbs = $schema->{dbs};
   my $top = $o->get('top');
   my @sorted;
   my ( $db_tbl, $size_data, $size_index, $n_rows, $engine );
   print   "      Top $top largest tables:\n"
         . "         DB.TBL              SIZE DATA  SIZE INDEX  #ROWS    ENGINE\n";
format TBL_LINE =
         @<<<<<<<<<<<<<<<<   @<<<<<<<<  @<<<<<<<<<  @<<<<<<  @<<<<<
$db_tbl, $size_data, $size_index, $n_rows, $engine
.
   # Build a schema-wide list of db.table => size
   foreach my $db ( keys %$dbs ) {
      foreach my $tbl ( keys %{$dbs->{$db}} ) {
         $dbs_tbls{"$db.$tbl"} = $dbs->{$db}->{$tbl}->{data_length};
      }
   }
   @sorted = sort { $dbs_tbls{$b} <=> $dbs_tbls{$a} } keys %dbs_tbls;
   $FORMAT_NAME = 'TBL_LINE';
   foreach $db_tbl ( @sorted ) {
      my ( $db, $tbl ) = split '\.', $db_tbl;
      $size_data  = shorten($dbs_tbls{$db_tbl});
      $size_index = shorten($dbs->{$db}->{$tbl}->{index_length});
      $n_rows     = shorten($dbs->{$db}->{$tbl}->{rows}, d=>1000);
      $engine     = $dbs->{$db}->{$tbl}->{engine};
      write;
      delete $dbs_tbls{$db_tbl};
      last if !--$top;
   }
   my $n_remaining = 0;
   my $r_size      = 0;
   my $r_avg       = 0;
   foreach my $db_tbl ( keys %dbs_tbls ) {
      $n_remaining++;
      $r_size += $dbs_tbls{$db_tbl};
   }
   if($n_remaining) {
      $r_avg  = shorten($r_size / $n_remaining);
      $r_size = shorten($r_size);
      print "         Remaining $n_remaining        $r_size ($r_avg average)\n";
   }
   return;
}

sub engines_summary {
   my ( $schema, $o ) = @_;
   my $engines = $schema->{counts}->{engines};
   my ($engine, $n_tables, $n_indexes, $size_data, $size_indexes);
   print   "      Engines:\n"
         . "         ENGINE      SIZE DATA   SIZE INDEX   #TABLES   #INDEXES\n";
format ENGINE_LINE =
         @<<<<<<<<<  @<<<<<<     @<<<<<<      @<<<<<<   @<<<<<<
$engine, $size_data, $size_indexes, $n_tables, $n_indexes
.
   $FORMAT_NAME = 'ENGINE_LINE';
   foreach $engine ( keys %{ $engines } ) {
      $size_data    = shorten($engines->{$engine}->{data_size});
      $size_indexes = shorten($engines->{$engine}->{index_size});
      $n_tables     = $engines->{$engine}->{tables};
      $n_indexes    = $engines->{$engine}->{indexes} || 'NA';
      write;
   }
   return;
}

sub tre_summary {
   my ( $schema, $o ) = @_;
   my ( $db, $type, $count );
   print   "      Triggers, Routines, Events:\n"
         . "         DATABASE           TYPE      COUNT\n";
format TRE_LINE =
         @<<<<<<<<<<<<<<<<  @<<<<<<   @<<<<<<
$db, $type, $count
.
   if ( exists $schema->{trigs_routines_events} ) {
      if ( defined $schema->{trigs_routines_events} ) {
         $FORMAT_NAME = 'TRE_LINE';
         foreach my $db_type_count ( @{ $schema->{trigs_routines_events} } ) {
            ( $db, $type, $count ) = split ' ', $db_type_count;
            write;
         }
      }
      else {
         print "         No triggers, routines, or events\n";
      }
   }
   else {
      print "         Not supported (MySQL version < 5.0.0)\n";
   }
   return;
}

sub report_aggregated_processlist {
   my ( $ag_pl ) = @_;  # aggregated_processlist
   my ( $value, $count, $total_time); # used by format

   print "\n   Aggregated PROCESSLIST ________________________________________________
      FIELD      VALUE                       COUNT   TOTAL TIME (s)\n";

format VALUE_LINE =
                 @<<<<<<<<<<<<<<<<<<<<<<<<   @<<<<   @<<<<
$value, $count, $total_time
.

   foreach my $field ( keys %{ $ag_pl } ) {
      printf "      %.8s\n", $field;
      $FORMAT_NAME = 'VALUE_LINE';
      foreach $value ( keys %{ $ag_pl->{$field} } ) {
         $count       = $ag_pl->{$field}->{$value}->{count};
         $total_time  = $ag_pl->{$field}->{$value}->{time};
         write;
      }
   }
   return;
}

sub _d {
   my ($package, undef, $line) = caller 0;
   @_ = map { (my $temp = $_) =~ s/\n/\n# /g; $temp; }
        map { defined $_ ? $_ : 'undef' }
        @_;
   print STDERR "# $package:$line $PID ", join(' ', @_), "\n";
}

1;

# ###########################################################################
# End InstanceReporter package
# ###########################################################################
