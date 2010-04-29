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
use Data::Dumper;
$Data::Dumper::Indent    = 1;
$Data::Dumper::Sortkeys  = 1;
$Data::Dumper::Quotekeys = 0;

use constant MKDEBUG => $ENV{MKDEBUG} || 0;

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
      defaults_file  => undef, 
      show_variables => "SHOW /*!40103 GLOBAL*/ VARIABLES",
      version        => '',

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
#     * file    scalar: get output from file, or
#     * fh      scalar: get output from fh
#   when from=show_variables:
#     * dbh     obj: get SHOW VARIABLES from dbh, or
#     * rows    arrayref: get SHOW VARIABLES from rows
# Sets the offline or online config values from the given source.
# Returns nothing.
sub set_config {
   my ( $self, %args ) = @_;
   foreach my $arg ( qw(from) ) {
      die "I need a $arg argument" unless $args{$arg};
   }
   my $from = $args{from};
   MKDEBUG && _d('Set config', Dumper(\%args));

   if ( $from eq 'mysqld' || $from eq 'my_print_defaults' ) {
      die "Setting the MySQL config from $from requires a "
            . "cmd, file, or fh argument"
         unless $args{cmd} || $args{file} || $args{fh};

      my $output;
      my $fh = $args{fh};
      if ( $args{file} ) {
         open $fh, '<', $args{file}
            or die "Cannot open $args{file}: $OS_ERROR";
      }
      if ( $fh ) {
         $output = do { local $/ = undef; <$fh> };
      }

      my ($config, $dupes, $ddf);
      if ( $from eq 'mysqld' ) {
         ($config, $ddf) = $self->parse_mysqld($output);
      }
      elsif ( $from eq 'my_print_defaults' ) {
         ($config, $dupes) = $self->parse_my_print_defaults($output);
      }

      die "Failed to parse MySQL config from $from" unless $config;
      @{$self->{config}->{offline}}{keys %$config} = values %$config;

      $self->{default_defaults_files} = $ddf   if $ddf;
      $self->{duplicate_vars}         = $dupes if $dupes;
   }
   elsif ( $args{from} eq 'show_variables' ) {
      die "Setting the MySQL config from $from requires a "
            . "dbh or rows argument"
         unless $args{dbh} || $args{rows};

      my $rows = $args{rows};
      if ( $args{dbh} ) {
         my $sql = $self->{show_variables};
         MKDEBUG && _d($args{dbh}, $sql);
         $rows = $args{dbh}->selectall_arrayref($sql);

         $self->_set_version($args{dbh}) unless $self->{version};
      }
      $self->set_online_config($rows);
   }
   else {
      die "I don't know how to set the MySQL config from $from";
   }
   return;
}

# Set online config given the arrayref of rows.  This arrayref is
# usually from SHOW VARIABLES.  This sub is usually called via
# set_config().
sub set_online_config {
   my ( $self, $rows ) = @_;
   return unless $rows;
   my %config = map { @$_ } @$rows;
   $self->{config}->{online} = \%config;
   return;
}

# Parse "mysqld --help --verbose" and return a hashref of variable=>values
# and an arrayref of default defaults files if possible.  The "default
# defaults files" are the defaults file that mysqld reads by default if no
# defaults file is explicitly given by --default-file.
sub parse_mysqld {
   my ( $self, $output ) = @_;
   return unless $output;

   # First look for the list of default defaults files like
   #   Default options are read from the following files in the given order:
   #   /etc/my.cnf /usr/local/mysql/etc/my.cnf ~/.my.cnf 
   my @ddf;
   if ( $output =~ m/^Default options are read.+\n/mg ) {
      my ($ddf) = $output =~ m/\G^(.+)\n/m;
      my %seen;
      my @ddf = grep { !$seen{$_} } split(' ', $ddf);
      MKDEBUG && _d('Default defaults files:', @ddf);
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

   return $config, \@ddf;
}

# Parse "my_print_defaults" output and return a hashref of variable=>values
# and a hashref of any duplicated variables.
sub parse_my_print_defaults {
   my ( $self, $output ) = @_;
   return unless $output;

   # Parse the "--var=val" lines.
   my ($config, $dupes) = $self->_parse_varvals(
      map { $_ =~ m/^--([^=]+)(?:=(.*))?$/ } split("\n", $output)
   );

   return $config, $dupes;
}

# Parses a list of variables and their values ("varvals"), returns two
# hashrefs: one with normalized variable=>value, the other with duplicate
# vars.  The varvals list should start with a var at index 0 and its value
# at index 1 then repeat for the next var-val pair.  
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
         if ( exists $config{$item} && !$can_be_duplicate{$item} ) {
            MKDEBUG && _d("Duplicate var:", $item);
            $duplicate_var = 1;
         }

         $var      = 0;  # next item should be the val for this var
         $last_var = $item;
      }
      else {
         if ( $item ) {
            $item =~ s/^\s+//;

            if ( my ($num, $factor) = $item =~ m/(\d+)([kmgt])$/i ) {
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

sub _set_version {
   my ( $self, $dbh ) = @_;
   my $version = $dbh->selectrow_arrayref('SELECT VERSION()')->[0];
   return unless $version;
   $version =~ s/(\d\.\d{1,2}.\d{1,2})/$1/;
   MKDEBUG && _d('MySQL version', $version);
   $self->{version} = $version;
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
# End MySQLConfig package
# ###########################################################################
