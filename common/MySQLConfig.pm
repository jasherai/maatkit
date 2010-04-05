# This program is copyright 2010-@CURRENTYEAR@ Percona Inc.
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
# MySQLConfig package $Revision$
# ###########################################################################
package MySQLConfig;

use strict;
use warnings FATAL => 'all';
use English qw(-no_match_vars);
use File::Temp;

use constant MKDEBUG => $ENV{MKDEBUG} || 0;

my $option_pattern = '([^\s=]+)(?:=(\S+))?';

my %alias_for = (
   ON   => 'TRUE',
   OFF  => 'FALSE',
   YES  => '1',
   NO   => '0',
);

my %undef_for = (
   'log'                         => 'OFF',
   log_bin                       => 'OFF',
   log_slow_queries              => 'OFF',
   log_slave_updates             => 'ON',
   log_queries_not_using_indexes => 'ON',
   log_update                    => 'OFF',
   skip_bdb                      => 0,
   skip_external_locking         => 'ON',
   skip_name_resolve             => 'ON',
);

my %ignore_vars = (
   date_format     => 1,
   datetime_format => 1,
   time_format     => 1,
);

my %eq_for = (
   ft_stopword_file          => sub { return _veq(@_, '(built-in)', ''); },
   query_cache_type          => sub { return _veq(@_, 'ON', '1');        },
   ssl                       => sub { return _veq(@_, '1', 'TRUE');      },
   sql_mode                  => sub { return _veq(@_, '', 'OFF');        },

   basedir                   => sub { return _patheq(@_);                },
   language                  => sub { return _patheq(@_);                },

   log_bin                   => sub { return _eqifon(@_);                },
   log_slow_queries          => sub { return _eqifon(@_);                },

   general_log_file          => sub { return _eqifconfundef(@_);         },
   innodb_data_file_path     => sub { return _eqifconfundef(@_);         },
   innodb_log_group_home_dir => sub { return _eqifconfundef(@_);         },
   log_error                 => sub { return _eqifconfundef(@_);         },
   open_files_limit          => sub { return _eqifconfundef(@_);         },
   slow_query_log_file       => sub { return _eqifconfundef(@_);         },
   tmpdir                    => sub { return _eqifconfundef(@_);         },

   long_query_time           => sub { return _numericeq(@_);             },
);

my %can_be_duplicate = (
   replicate_wild_do_table     => 1,
   replicate_wild_ignore_table => 1,
   replicate_rewrite_db        => 1,
   replicate_ignore_table      => 1,
   replicate_ignore_db         => 1,
   replicate_do_table          => 1,
   replicate_do_db             => 1,
);

sub new {
   my ( $class, %args ) = @_;

   my $self = {
      # defaults
      defaults_file => undef, 
      commands      => {
         mysqld            => "mysqld",
         my_print_defaults => "my_print_defaults",
         show_variables    => "SHOW /*!40103 GLOBAL*/ VARIABLES",
      },

      # override defaults
      %args,

      # private
      default_defaults_files => [],
      duplicate_vars         => {},
      config                 => {
         offline => {},  # vars as set by defaults files
         online  => {},  # vars as currently set on running server
      },
   };

   return bless $self, $class;
}

# Returns true if the MySQL config has the given system variable.
sub has {
   my ( $self, $var ) = @_;
   return exists $self->{config}->{offline}->{$var}
       || exists $self->{config}->{online}->{$var};
}

# Returns the value for the given system variable.  Returns its
# online/effective value by default.
sub get {
   my ( $self, $var, %args ) = @_;
   return unless $var;
   return $args{offline} ? $self->{config}->{offline}->{$var}
      :                    $self->{config}->{online}->{$var};
}

# Returns the whole online (default) or offline hashref of config vals.
sub get_config {
   my ( $self, %args ) = @_;
   return $args{offline} ? $self->{config}->{offline}
      :                    $self->{config}->{online};
}

sub get_duplicate_variables {
   my ( $self ) = @_;
   return $self->{duplicate_vars};
}

# Arguments:
#   * from    scalar: one of mysqld, my_print_defaults, or show_variables
#   when from=mysqld or my_print_defaults:
#     * cmd     scalar: cmd to run for from for output, or
#     * file    scalar: file for from for output, or
#     * fh      scalar: fh for from for output
#   when from=show_variables:
#     * dbh     obj: dbh to get SHOW VARIABLES
#     * rows    arrayref: vals from SHOW VARIABLES
# Sets the offline or online config values from the given source.
# Returns nothing.
sub set_config {
   my ( $self, %args ) = @_;
   foreach my $arg ( qw(from) ) {
      die "I need a $arg argument" unless $args{$arg};
   }
   my $from = $args{from};

   if ( $from eq 'mysqld' || $from eq 'my_print_defaults' ) {
      die "Setting the MySQL config from $from requires a "
            . "cmd, file, or fh argument"
         unless $args{cmd} || $args{file} || $args{fh};

      my $output;
      my $fh = $args{fh};
      if ( $args{cmd} ) {
         my $cmd_sub = "_get_${from}_output";
         $output = $self->$cmd_sub();
      }
      if ( $args{file} ) {
         open $fh, '<', $args{file}
            or die "Cannot open $args{file}: $OS_ERROR";
      }
      if ( $fh ) {
         $output = do { local $/ = undef; <$fh> };
      }

      my $parse_sub = "parse_$from";
      $self->$parse_sub($output);
   }
   elsif ( $args{from} eq 'show_variables' ) {
      die "Setting the MySQL config from $from requires a "
            . "dbh or rows argument"
         unless $args{dbh} || $args{rows};

      my $rows = $args{rows};
      if ( $args{dbh} ) {
         my $sql = $self->{commands}->{show_variables};
         MKDEBUG && _d($args{dbh}, $sql);
         $rows = $args{dbh}->selectall_arrayref($sql);
      }
      $self->set_online_config($rows);
   }
   else {
      die "I don't know how to set the MySQL config from $from";
   }
   return;
}

# Parse "mysqld --help --verbose" output which lists the default
# defaults files and the offline system var values according to
# whatever defaults file it was given explicitly with --defaults-file
# or implicitily from one of the default defaults files.
# Returns nothing.
sub parse_mysqld {
   my ( $self, $output ) = @_;
   return unless $output;

   # First look for the list of default defaults files like
   #   Default options are read from the following files in the given order:
   #   /etc/my.cnf /usr/local/mysql/etc/my.cnf ~/.my.cnf 
   if ( $output =~ m/^Default options are read.+\n/mg ) {
      my ($ddf) = $output =~ m/\G^(.+)\n/m;
      my %seen;
      my @ddf = grep { !$seen{$_} } split(' ', $ddf);
      MKDEBUG && _d('Default defaults files:', @ddf);
      $self->{default_defaults_files} = \@ddf;
   }
   else {
      MKDEBUG && _d("mysqld help output doesn't list default defaults files");
   }

   # The list of sys vars and their default vals begins like:
   #   Variables (--variable-name=value)
   #   and boolean options {FALSE|TRUE}  Value (after reading options)
   #   --------------------------------- -----------------------------
   #   help                              TRUE
   #   abort-slave-event-count           0
   # So we search for that line of hypens.
   if ( $output !~ m/^-+ -+$/mg ) {
      MKDEBUG && _d("mysqld help output doesn't list vars and vals");
      return;
   }

   # Cut off everything before the list of vars and vals.
   my $varvals = substr($output, (pos $output) + 1, length $output);

   # Parse the "var  val" lines.  2nd retval is duplicates but there
   # shouldn't be any with mysqld.
   my ($config, undef) = $self->_parse_varvals($varvals =~ m/\G^(\S+)(.*)\n/mg);

   # Merge these var-vals into the offline config.
   @{$self->{config}->{offline}}{keys %$config} = values %$config;

   return; 
}

# Parse "my_print_defaults" output.
# Returns nothing.
sub parse_my_print_defaults {
   my ( $self, $output ) = @_;
   return unless $output;

   # Parse the "--var=val" lines.
   my ($config, $duplicates) = $self->_parse_varvals(
      map { $_ =~ m/^--([^=]+)(?:=(.*))?$/ } split("\n", $output) );

   # Merge these var-vals into the offline config.
   @{$self->{config}->{offline}}{keys %$config} = values %$config;

   # Save the duplicates.  Unlike mysqld, my_print_defaults prints duplicates.
   $self->{duplicate_vars} = $duplicates;

   return; 
}

sub set_online_config {
   my ( $self, $rows ) = @_;
   return unless $rows;
   my %config = map { @$_ } @$rows;
   $self->{config}->{online} = \%config;
   return;
}

sub _parse_varvals {
   my ( $self, @varvals ) = @_;

   # Config built from parsing the given varvals.
   my %config;

   # Discover duplicate vars.  
   my $duplicate_var = 0;
   my %duplicates;

   # Keep track if item is var or val because each needs special modifications.
   my $var      = 1;
   my $last_var = undef;

   foreach my $item ( @varvals ) {
      if ( $var ) {
         # Variable names via config files are like "log-bin" but
         # via SHOW VARIABLES they're like "log_bin".
         $item =~ s/-/_/g;

         # If this var exists in the offline config already, then
         # its a duplicate.  Its original value will be saved before
         # being overwritten with the new value.
         $duplicate_var = 1 if exists $config{$item};

         $var      = 0;  # next item should be the val for this var
         $last_var = $item;
      }
      else {
         if ( $item ) {
            $item =~ s/^\s+//;

            if ( my ($num, $factor) = $item =~ m/(\d+)([kmgt])/i ) {
               my %factor_for = (
                  k => 1_024,
                  m => 1_048_576,
                  g => 1_073_741_824,
                  t => 1_099_511_627_776,
               );
               $item = $num * $factor_for{lc $factor};
            }
            elsif ( $item =~ m/No default/ ) {
               $item = undef;
            }
         }

         $item = $undef_for{$last_var} || '' unless defined $item;

         if ( $duplicate_var ) {
            # Save var's original value before overwritng with this new value.
            push @{$duplicates{$last_var}}, $config{$last_var};
            $duplicate_var = 0;
         }

         # Save this var-val.
         $config{$last_var} = $item;

         $var = 1;  # next item should be a var
      }
   }

   return \%config, \%duplicates;
}

# Everything below here is legacy from mk-audit.
# It will be updated or removed.

sub _defaults_file_op {
   my ( $self, $ddf )   = @_;  # ddf = default defaults file (optional)
   my $defaults_file_op = '';
   my $tmp_file         = undef;
   my $defaults_file    = defined $ddf ? $ddf
                        : $self->{cmd_line_ops}->{defaults_file};

   if ( $defaults_file && -f $defaults_file ) {
      $tmp_file = File::Temp->new();
      my $cp_cmd = "cp $defaults_file "
                 . $tmp_file->filename;
      `$cp_cmd`;
      $defaults_file_op = "--defaults-file=" . $tmp_file->filename;

      MKDEBUG && _d('Tmp file for defaults file', $defaults_file, ':',
         $tmp_file->filename);
   }
   else {
      MKDEBUG && _d('Defaults file does not exist:', $defaults_file);
   }

   return ( $defaults_file_op, $tmp_file );
}

sub overriden_sys_vars {
   my ( $self ) = @_;
   my %overriden_vars;
   foreach my $var_val ( @{ $self->{defaults_file_sys_vars} } ) {
      my ( $var, $val ) = ( $var_val->[0], $var_val->[1] );
      if ( !defined $var || !defined $val ) {
         MKDEBUG && _d('Undefined var or val:', Dumper($var_val));
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

sub out_of_sync_sys_vars {
   my ( $self ) = @_;
   my %out_of_sync_vars;

   VAR:
   foreach my $var ( keys %{ $self->{conf_sys_vars} } ) {
      next VAR if exists $ignore_vars{$var};
      next VAR unless exists $self->{online_sys_vars}->{$var};

      my $conf_val        = $self->{conf_sys_vars}->{$var};
      my $online_val      = $self->{online_sys_vars}->{$var};
      my $var_out_of_sync = 0;


      if ( ($conf_val || $online_val) && ($conf_val ne $online_val) ) {
         $var_out_of_sync = 1;

         if ( exists $eq_for{$var} ) {
            $var_out_of_sync = !$eq_for{$var}->($conf_val, $online_val);
         }
         if ( exists $alias_for{$online_val} ) {
            $var_out_of_sync = 0 if $conf_val eq $alias_for{$online_val};
         }
      }

      if ( $var_out_of_sync ) {
         $out_of_sync_vars{$var} = { online=>$online_val, config=>$conf_val };
      }
   }

   return \%out_of_sync_vars;
}

sub get_eq_for {
   my ( $var ) = @_;
   if ( exists $eq_for{$var} ) {
      return $eq_for{$var};
   }
   return;
}

sub _veq { 
   my ( $x, $y, $val1, $val2 ) = @_;
   return 1 if ( ($x eq $val1 || $x eq $val2) && ($y eq $val1 || $y eq $val2) );
   return 0;
}

sub _patheq {
   my ( $x, $y ) = @_;
   $x .= '/' if $x !~ m/\/$/;
   $y .= '/' if $y !~ m/\/$/;
   return $x eq $y;
}

sub _eqifon { 
   my ( $x, $y ) = @_;
   return 1 if ( $x && $x eq 'ON' && $y );
   return 1 if ( $y && $y eq 'ON' && $x );
   return 0;
}

sub _eqifconfundef {
   my ( $conf_val, $online_val ) = @_;
   return ($conf_val eq '' ? 1 : 0);
}

sub _numericeq {
   my ( $x, $y ) = @_;
   return ($x == $y ? 1 : 0);
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
# End MySQLConfig package
# ###########################################################################
