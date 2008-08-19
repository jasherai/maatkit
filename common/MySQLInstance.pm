# This program is copyright 2008 Percona Inc.
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
# MySQLInstance package $Revision$
# ###########################################################################

# MySQLInstance - Config and status values for an instance of mysqld
package MySQLInstance;

use strict;
use warnings FATAL => 'all';

use English qw(-no_match_vars);
use File::Temp ();
use Carp;
use Data::Dumper;

use constant MKDEBUG => $ENV{MKDEBUG};

my $option_pattern = '([^\s=]+)(?:=(\S+))?';

# SHOW GLOBAL VARIABLES dialect => mysqld --help --verbose dialect
my %alias_for = (
   ON   => 'TRUE',
   OFF  => 'FALSE',
   YES  => '1',
   NO   => '0',
);

my %undef_for = (
   bdb_home                      => '',
   bdb_logdir                    => '',
   bdb_tmpdir                    => '',
   date_format                   => '',
   datetime_format               => '',
   ft_stopword_file              => '',
   init_connect                  => '',
   init_file                     => '',
   init_slave                    => '',
   innodb_data_home_dir          => '',
   innodb_flush_method           => '',
   innodb_log_arch_dir           => '',
   innodb_log_group_home_dir     => '',
   'log'                         => 'OFF',
   log_bin                       => 'OFF',
   log_error                     => '',
   log_slow_queries              => 'OFF',
   log_slave_updates             => 'ON',
   log_queries_not_using_indexes => 'ON',
   log_update                    => 'OFF',
   ndb_connectstring             => '',
   relay_log_index               => '',
   secure_file_priv              => '',
   skip_external_locking         => 'ON',
   skip_name_resolve             => 'ON',
   ssl_ca                        => '',
   ssl_capath                    => '',
   ssl_cert                      => '',
   ssl_cipher                    => '',
   ssl_key                       => '',
   time_format                   => '',
   tmpdir                        => '',
);

sub new {
   my ( $class, $cmd ) = @_;
   my $self = {};
   ($self->{mysqld_binary}) = $cmd =~ m/(\S+mysqld)\b/;
   $self->{'64bit'} = `file $self->{mysqld_binary}` =~ m/64-bit/ ? 'Yes' : 'No';
   %{ $self->{cmd_line_ops} }
      = map {
           my ( $var, $val ) = m/$option_pattern/o;
           $var =~ s/-/_/go;
           if ( !defined $val && exists $undef_for{$var} ) {
              $val = $undef_for{$var};
           }
           $var => $val;
        } ($cmd =~ m/--(\S+)/g);
   $self->{cmd_line_ops}->{defaults_file} ||= '';
   return bless $self, $class;
}

sub load_sys_vars {
   my ( $self, $dbh ) = @_;
   
   # Sys vars and defaults according to mysqld
   my ( $defaults_file_op, $tmp_file ) = $self->_defaults_file_op();
   my $cmd = "$self->{mysqld_binary} $defaults_file_op --help --verbose";
   if ( my $mysqld_output = `$cmd` ) {
      # Parse from mysqld output the list of sys vars and their default values
      # listed at the end after all the help info.
      my ($sys_vars) = $mysqld_output =~ m/---\n(.*?)\n\n/ms;
      %{ $self->{conf_sys_vars} }
         = map {
              my ( $var, $val ) = m/^(\S+)\s+(?:(\S+))?/;
              $var =~ s/-/_/go;
              if ( $val && $val =~ m/\(No/ ) { # (No default value)
                 $val = undef;
              }
              if ( !defined $val && exists $undef_for{$var} ) {
                 $val = $undef_for{$var};
              }
              $var => $val;
           } split "\n", $sys_vars;
   }

   # Sys vars from SHOW STATUS
   $self->_load_online_sys_vars($dbh);

   # Sys vars from defaults file
   # These are used later by duplicate_values() and overriden_values().
   # These are also necessary for vars like skip-name-resolve which are not
   # shown in either SHOW VARIABLES or mysqld --help --verbose but are need
   # for checks in MySQLAdvisor. 
   $self->{defaults_files_sys_vars}
      = $self->_vars_from_defaults_file($defaults_file_op); 
   foreach my $var_val ( reverse @{ $self->{defaults_file_sys_vars} } ) {
      my ( $var, $val ) = ( $var_val->[0], $var_val->[1] );
      if ( !exists $self->{conf_sys_vars}->{$var} ) {
         $self->{conf_sys_vars}->{$var} = $val;
      }
      if ( !exists $self->{online_sys_vars}->{$var} ) {
         $self->{online_sys_vars}->{$var} = $val;
      }
   }
   return;
}

# Returns a --defaults-file cmd line op suitable for mysqld, my_print_defaults,
# etc., or a blank string if the defaults file is unknown.
sub _defaults_file_op {
   my ( $self ) = @_;
   my $defaults_file_op = '';
   my $tmp_file = undef;
   if ( $self->{cmd_line_ops}->{defaults_file} ) {
      # Copy defaults file to /tmp/ because Debian/Ubuntu mysqld apparently
      # has a bug which prevents it from being read from non-standard locations.
      $tmp_file = File::Temp->new();
      my $cp_cmd = "cp $self->{cmd_line_ops}->{defaults_file} "
                   . $tmp_file->filename;
      `$cp_cmd`;
      $defaults_file_op = "--defaults-file=" . $tmp_file->filename;
   }
   # Must return $tmp_file obj so its reference lasts into the caller because
   # when it's destroyed the actual tmp file is automatically unlinked 
   return ( $defaults_file_op, $tmp_file );
}

# Loads $self->{default_files_sys_vars} with only the sys vars that
# are explicitly set in the defaults file. This is used for detecting
# duplicates and overriden var/vals.
sub _vars_from_defaults_file {
   my ( $self, $defaults_file_op ) = @_;
   my $cmd = "my_print_defaults $defaults_file_op mysqld";
   if ( my $my_print_defaults_output = `$cmd` ) {
      foreach my $var_val ( split "\n", $my_print_defaults_output ) {
         # Make sys vars from conf look like those from SHOW VARIABLES
         # (I.e. log_slow_queries instead of log-slow-queries
         # and 33554432 instead of 32M, etc.)
         my ( $var, $val ) = $var_val =~ m/^--$option_pattern/o;
         $var =~ s/-/_/go;
         # TODO: this can be more compact ( $digits_for{lc $2} ) and shouldn't
         # use $1, $2
         if ( defined $val && $val =~ /(\d+)([kKmMgGtT]?)/) {
            if ( $2 ) {
               my %digits_for = (
                  'k'   => 1_024,
                  'K'   => 1_204,
                  'm'   => 1_048_576,
                  'M'   => 1_048_576,
                  'g'   => 1_073_741_824,
                  'G'   => 1_073_741_824,
                  't'   => 1_099_511_627_776,
                  'T'   => 1_099_511_627_776,
               );
               $val = $1 * $digits_for{$2};
            }
         }
         if ( !defined $val && exists $undef_for{$var} ) {
            $val = $undef_for{$var};
         }
         push @{ $self->{defaults_file_sys_vars} }, [ $var, $val ];
      }
   }
}

sub _load_online_sys_vars {
   my ( $self, $dbh ) = @_;
   %{ $self->{online_sys_vars} }
      = map { $_->{Variable_name} => $_->{Value} }
            @{ $dbh->selectall_arrayref('SHOW /*!40101 GLOBAL*/ VARIABLES',
                                        { Slice => {} })
            };
   return;
}

# Get DSN specific to this MySQL instance (Baron, I didn't find other code
# to do this. Plus, this relies on cmd_line_ops which is "private".)
sub get_DSN {
   my ( $self ) = @_;
   my $port   = $self->{cmd_line_ops}->{port}     || '';
   my $socket = $self->{cmd_line_ops}->{'socket'} || '';
   my $host   = $port ne 3306 ? '127.0.0.1' : 'localhost';
   return {
      P => $port,
      S => $socket,
      h => $host,
   };
}

# duplicate_sys_vars() returns an array ref of sys var names that
# appear more than once in the defaults file
sub duplicate_sys_vars {
   my ( $self ) = @_;
   my @duplicate_vars;
   my %have_seen;
   foreach my $var_val ( @{ $self->{defaults_file_sys_vars} } ) {
      my ( $var, $val ) = ( $var_val->[0], $var_val->[1] );
      push @duplicate_vars, $var if $have_seen{$var}++ == 1;
   }
   return \@duplicate_vars;
}

# overriden_sys_vars() returns a hash ref of overriden sys vars:
#    key   = sys var that is overriden
#    value = array [ val being used, val overriden ]
sub overriden_sys_vars {
   my ( $self ) = @_;
   my %overriden_vars;
   foreach my $var_val ( @{ $self->{defaults_file_sys_vars} } ) {
      my ( $var, $val ) = ( $var_val->[0], $var_val->[1] );
      if ( !defined $var || !defined $val ) {
         my $dump = Dumper($var_val);
         MKDEBUG && _d("Undefined var or val: $dump");
         next;
      }
      if ( exists $self->{cmd_line_ops}->{$var} ) {
         if(    ( !defined $self->{cmd_line_ops}->{$var} && !defined $val)
             || ( $self->{cmd_line_ops}->{$var} ne $val) ) {
            $overriden_vars{$var} = [ $self->{cmd_line_ops}->{$var}, $val ];
         }
      }
   }
   return \%overriden_vars;
}

# out_of_sync_sys_vars() returns a hash ref of sys vars that differ in their
# online vs. config values:
#    key   = sys var that is out of sync
#    value = array [ val online, val config ]
sub out_of_sync_sys_vars {
   my ( $self ) = @_;
   my %out_of_sync_vars;
   foreach my $var ( keys %{ $self->{conf_sys_vars} } ) {
      next if !exists $self->{online_sys_vars}->{$var};
      my $conf_val        = $self->{conf_sys_vars}->{$var};
      my $online_val      = $self->{online_sys_vars}->{$var};
      my $var_out_of_sync = 0;
      # Global %undef_for and the subs that populated conf_sys_vars
      # and online_sys_vars should have taken care of any undefined
      # values. If not, this sub will warn.
      if ( defined $conf_val && defined $online_val ) {
         # TODO: try this on a server with skip_grant_tables set, it crashes on
         # me in a not-friendly way.  Probably ought to use eval {} and catch
         # error.  Also, carp() may not be right here, it gives the wrong
         # impression I think.  (I guess I just am used to seeing die show the
         # real line....)
         if ( $conf_val ne $online_val ) {
            $var_out_of_sync = 1;
            # But handle excepts where SHOW GLOBAL VARIABLES says ON and 
            # mysqld --help --verbose says TRUE
            if ( exists $alias_for{$online_val} ) {
               $var_out_of_sync = 0 if $conf_val eq $alias_for{$online_val};
            }
         }
      }
      else {
         carp "Undefined system variable: $var";
         if ( MKDEBUG ) {
            my $dump_conf   = Dumper($conf_val);
            my $dump_online = Dumper($online_val);
            _d("Undefined val: conf=$dump_conf online=$dump_online");
         }
         next;
      }
      if($var_out_of_sync) {
         $out_of_sync_vars{$var}
            = [ $online_val, $conf_val ];
      }
   }
   return \%out_of_sync_vars;
}

sub load_status_vals {
   my ( $self, $dbh ) = @_;
   %{ $self->{status_vals} }
      = map { $_->{Variable_name} => $_->{Value} }
            @{ $dbh->selectall_arrayref('SHOW /*!50002 GLOBAL */ STATUS',
                                        { Slice => {} })
            };
   return;
}

sub _d {
   my ( $line ) = (caller(0))[2];
   print "# MySQLInstance:$line $PID ", @_, "\n";
}

1;

# ###########################################################################
# End MySQLInstance package
# ###########################################################################
