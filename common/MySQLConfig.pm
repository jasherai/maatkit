# This program is copyright 2010-2011 Percona Inc.
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

# This package encapsulates a MySQL config (i.e. its system variables)
# from different sources: SHOW VARIABLES, mysqld --help --verbose, etc.
# (See set_config() for full list of valid input.)  It basically just
# parses the config into a common data struct, then MySQLConfig objects
# are passed to other modules like MySQLConfigComparer.

use strict;
use warnings FATAL => 'all';
use English qw(-no_match_vars);
use Data::Dumper;
$Data::Dumper::Indent    = 1;
$Data::Dumper::Sortkeys  = 1;
$Data::Dumper::Quotekeys = 0;

use constant MKDEBUG => $ENV{MKDEBUG} || 0;

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
   my @required_args = qw(source TextResultSetParser);
   foreach my $arg ( @required_args ) {
      die "I need a $arg arugment" unless $args{$arg};
   }

   my %config_data = parse_config(%args);

   my $self = {
      %args,
      %config_data,
   };

   return bless $self, $class;
}

sub parse_config {
   my ( %args ) = @_;
   my @required_args = qw(source TextResultSetParser);
   foreach my $arg ( @required_args ) {
      die "I need a $arg arugment" unless $args{$arg};
   }
   my ($source) = @args{@required_args};

   my %config_data;
   if ( -f $source ) {
      %config_data = parse_config_from_file(%args);
   }
   elsif ( ref $source && ref $source eq 'ARRAY' ) {
      $config_data{type} = 'show_variables';
      $config_data{vars} = { map { @$_ } @$source };
   }
   elsif ( ref $source && (ref $source) =~ m/DBI/i ) {
      $config_data{type} = 'show_variables';
      my $sql = "SHOW /*!40103 GLOBAL*/ VARIABLES";
      MKDEBUG && _d($source, $sql);
      my $rows = $source->selectall_arrayref($sql);
      $config_data{vars} = { map { @$_ } @$rows };
      $config_data{mysql_version} = _get_version($source);
   }
   else {
      die "Unknown or invalid source: $source";
   }

   return %config_data;
}

sub parse_config_from_file {
   my ( %args ) = @_;
   my @required_args = qw(source TextResultSetParser);
   foreach my $arg ( @required_args ) {
      die "I need a $arg arugment" unless $args{$arg};
   }
   my ($source) = @args{@required_args};

   my $type = $args{type} || detect_source_type(%args);
   if ( !$type ) {
      die "Cannot auto-detect the type of MySQL config data in $source"
   }

   my $vars;      # variables hashref
   my $dupes;     # duplicate vars hashref
   my $opt_files; # option files arrayref
   if ( $type eq 'show_variables' ) {
      $vars = parse_show_variables(%args);
   }
   elsif ( $type eq 'mysqld' ) {
      ($vars, $opt_files) = parse_mysqld(%args);
   }
   elsif ( $type eq 'my_print_defaults' ) {
      ($vars, $dupes) = parse_my_print_defaults(%args);
   }
   elsif ( $type eq 'option_file' ) {
      ($vars, $dupes) = parse_option_file(%args);
   }
   else {
      die "Invalid type of MySQL config data in $source: $type"
   }

   die "Failed to parse MySQL config data from $source"
      unless $vars && keys %$vars;

   return (
      type           => $type,
      vars           => $vars,
      option_files   => $opt_files,
      duplicate_vars => $dupes,
   );
}

sub detect_source_type {
   my ( %args ) = @_;
   my @required_args = qw(source);
   foreach my $arg ( @required_args ) {
      die "I need a $arg arugment" unless $args{$arg};
   }
   my ($source) = @args{@required_args};

   MKDEBUG && _d("Detecting type of output in", $source);
   open my $fh, '<', $source or die "Cannot open $source: $OS_ERROR";
   my $type;
   while ( defined(my $line = <$fh>) ) {
      MKDEBUG && _d($line);
      if (    $line =~ m/\|\s+\w+\s+\|\s+.+?\|/
           || $line =~ m/\*+ \d/
           || $line =~ m/Variable_name:\s+\w+/ )
      {
         MKDEBUG && _d('show variables config line');
         $type = 'show_variables';
         last;
      }
      elsif ( $line =~ m/^--\w+/ ) {
         MKDEBUG && _d('my_print_defaults config line');
         $type = 'my_print_defaults';
         last;
      }
      elsif ( $line =~ m/^\s*\[[a-zA-Z]+\]\s*$/ ) {
         MKDEBUG && _d('option file config line');
         $type = 'option_file',
         last;
      }
      elsif (    $line =~ m/Starts the MySQL database server/
              || $line =~ m/Default options are read from /
              || $line =~ m/^help\s+TRUE / )
      {
         MKDEBUG && _d('mysqld config line');
         $type = 'mysqld';
         last;
      }
   }
   close $fh;
   return $type;
}

sub parse_show_variables {
   my ( %args ) = @_;
   my @required_args = qw(source TextResultSetParser);
   foreach my $arg ( @required_args ) {
      die "I need a $arg arugment" unless $args{$arg};
   }
   my ($source, $trp) = @args{@required_args};
   my $output         = _slurp_file($source);
   return unless $output;

   my %config = map {
      $_->{Variable_name} => $_->{Value}
   } @{ $trp->parse($output) };

   return \%config;
}

# Parse "mysqld --help --verbose" and return a hashref of variable=>values
# and an arrayref of default defaults files if possible.  The "default
# defaults files" are the defaults file that mysqld reads by default if no
# defaults file is explicitly given by --default-file.
sub parse_mysqld {
   my ( %args ) = @_;
   my @required_args = qw(source);
   foreach my $arg ( @required_args ) {
      die "I need a $arg arugment" unless $args{$arg};
   }
   my ($source) = @args{@required_args};
   my $output   = _slurp_file($source);
   return unless $output;

   # First look for the list of option files like
   #   Default options are read from the following files in the given order:
   #   /etc/my.cnf /usr/local/mysql/etc/my.cnf ~/.my.cnf 
   my @opt_files;
   if ( $output =~ m/^Default options are read.+\n/mg ) {
      my ($opt_files) = $output =~ m/\G^(.+)\n/m;
      my %seen;
      my @opt_files = grep { !$seen{$_} } split(' ', $opt_files);
      MKDEBUG && _d('Option files:', @opt_files);
   }
   else {
      MKDEBUG && _d("mysqld help output doesn't list option files");
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
   my ($config, undef) = _parse_varvals($varvals =~ m/\G^(\S+)(.*)\n/mg);

   return $config, \@opt_files;
}

# Parse "my_print_defaults" output and return a hashref of variable=>values
# and a hashref of any duplicated variables.
sub parse_my_print_defaults {
   my ( %args ) = @_;
   my @required_args = qw(source);
   foreach my $arg ( @required_args ) {
      die "I need a $arg arugment" unless $args{$arg};
   }
   my ($source) = @args{@required_args};
   my $output   = _slurp_file($source);
   return unless $output;

   # Parse the "--var=val" lines.
   my ($config, $dupes) = _parse_varvals(
      map { $_ =~ m/^--([^=]+)(?:=(.*))?$/ } split("\n", $output)
   );

   return $config, $dupes;
}

# Parse the [mysqld] section of an option file and return a hashref of
# variable=>values and a hashref of any duplicated variables.
sub parse_option_file {
   my ( %args ) = @_;
   my @required_args = qw(source);
   foreach my $arg ( @required_args ) {
      die "I need a $arg arugment" unless $args{$arg};
   }
   my ($source) = @args{@required_args};
   my $output   = _slurp_file($source);
   return unless $output;

   my ($mysqld_section) = $output =~ m/\[mysqld\](.+?)(?:^\s*\[\w+\]|\Z)/xms;
   die "Failed to parse the [mysqld] section from $source"
      unless $mysqld_section;

   # Parse the "var=val" lines.
   my ($config, $dupes) = _parse_varvals(
      map  { $_ =~ m/^([^=]+)(?:=(.*))?$/ }
      grep { $_ !~ m/^\s*#/ }  # no # comment lines
      split("\n", $mysqld_section)
   );

   return $config, $dupes;
}

# Parses a list of variables and their values ("varvals"), returns two
# hashrefs: one with normalized variable=>value, the other with duplicate
# vars.  The varvals list should start with a var at index 0 and its value
# at index 1 then repeat for the next var-val pair.  
sub _parse_varvals {
   my ( @varvals ) = @_;

   # Config built from parsing the given varvals.
   my %config;

   # Discover duplicate vars.  
   my $duplicate_var = 0;
   my %duplicates;

   # Keep track if item is var or val because each needs special modifications.
   my $var      = 1;
   my $last_var = undef;
   foreach my $item ( @varvals ) {
      if ( $item ) {
         $item =~ s/^\s+//;  # strip leading whitespace
         $item =~ s/\s+$//;  # strip trailing whitespace
      }

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
               # mysqld --help --verbose lists "(No default value)" for vars
               # that aren't set.  For most vars, this means that the var's
               # value is undefined, but for vars starting with the words in
               # in regex below, it means that they're OFF.  See the same
               # regext below.
               $item = $last_var =~ m/^(?:log|skip|ignore)/ ? 'OFF' : undef;
            }
         }

         if ( !defined $item ) {
            # Like mysqld --help --verbose above, some sources like option
            # files (my.cnf) may contain a var without a value, like "log-bin".
            # These vars are ON when simply given even without a value.  A
            # value for them is usually optional; when not specified, mysqld
            # uses some default value.
            $item = 'ON' if $last_var =~ m/^(?:log|skip|ignore)/;
         } 

         # To help MySQLConfigComparer avoid crashing on undef comparisons,
         # we let a blank string equal an undefined value.
         $item = '' unless defined $item;

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

sub _slurp_file {
   my ( $file ) = @_;
   die "I need a file argument" unless $file;
   open my $fh, '<', $file or die "Cannot open $file: $OS_ERROR";
   my $contents = do { local $/ = undef; <$fh> };
   close $fh;
   return $contents;
}

sub _get_version {
   my ( $dbh ) = @_;
   return unless $dbh;
   my $version = $dbh->selectrow_arrayref('SELECT VERSION()')->[0];
   $version =~ s/(\d\.\d{1,2}.\d{1,2})/$1/;
   MKDEBUG && _d('MySQL version', $version);
   return $version;
}

# #############################################################################
# Accessor methods.
# #############################################################################

# Returns true if this MySQLConfig obj has the given variable.
sub has {
   my ( $self, $var ) = @_;
   return exists $self->{vars}->{$var};
}

# Returns the value for the given variable.
sub get {
   my ( $self, $var ) = @_;
   return unless $var;
   return $self->{vars}->{$var};
}

# Returns all variables-values.
sub get_variables {
   my ( $self, %args ) = @_;
   return $self->{vars};
}

sub get_duplicate_variables {
   my ( $self ) = @_;
   return $self->{duplicate_vars};
}

sub get_option_files {
   my ( $self ) = @_;
   return $self->{option_files};
}

sub get_mysql_version {
   my ( $self ) = @_;
   return $self->{mysql_version};
}

sub get_type {
   my ( $self ) = @_;
   return $self->{type};
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
