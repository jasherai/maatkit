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
# MySQLConfigComparer package $Revision$
# ###########################################################################
package MySQLConfigComparer;

use strict;
use warnings FATAL => 'all';
use English qw(-no_match_vars);

use constant MKDEBUG => $ENV{MKDEBUG};

# Alternate values because offline/config my-var=ON is shown
# online as var_var=TRUE.
my %alt_val_for = (
   ON    => 1,
   YES   => 1,
   TRUE  => 1,
   OFF   => 0,
   NO    => 0,
   FALSE => 0,
   ''    => 0,
);

# These vars don't interest us so we ignore them.
my %ignore_vars = (
   date_format     => 1,
   datetime_format => 1,
   time_format     => 1,
);

# Special equality tests for certain vars that have varying
# values that are actually equal, like ON==1, ''=OFF, etc.
my %eq_for = (
   ft_stopword_file          => sub { return _veq(@_, '(built-in)', 0); },

   basedir                   => sub { return _patheq(@_);               },
   language                  => sub { return _patheq(@_);               },

   log_bin                   => sub { return _eqifon(@_);               },
   log_slow_queries          => sub { return _eqifon(@_);               },

   general_log_file          => sub { return _eqifnoconf(@_);           },
   innodb_data_file_path     => sub { return _eqifnoconf(@_);           },
   innodb_log_group_home_dir => sub { return _eqifnoconf(@_);           },
   log_error                 => sub { return _eqifnoconf(@_);           },
   open_files_limit          => sub { return _eqifnoconf(@_);           },
   slow_query_log_file       => sub { return _eqifnoconf(@_);           },
   tmpdir                    => sub { return _eqifnoconf(@_);           },

   long_query_time           => sub { return $_[0] == $_[1] ? 1 : 0;    },
);

sub new {
   my ( $class, %args ) = @_;
   my $self = {
   };
   return bless $self, $class;
}

# Returns an arrayref of hashrefs for each variable whose online
# value is different from it's config/offline value.
sub get_stale_variables {
   my ( $self, $config ) = @_;
   return unless $config;

   my @stale;
   my $offline = $config->get_config(offline=>1);
   my $online  = $config->get_config();

   if ( !keys %$online ) {
      MKDEBUG && _d("Cannot check for stale vars without online config");
      return;
   }

   foreach my $var ( keys %$offline  ) {
      next if exists $ignore_vars{$var};
      next unless exists $online->{$var};
      MKDEBUG && _d('var:', $var);

      my $online_val  = $config->get($var);
      my $offline_val = $config->get($var, offline=>1);
      my $stale       = 0;
      MKDEBUG && _d('real val online:', $online_val, 'offline:', $offline_val);

      # Normalize values: ON|YES|TRUE==1, OFF|NO|FALSE==0.
      $online_val  = $alt_val_for{$online_val}
         if exists $alt_val_for{$online_val};
      $offline_val = $alt_val_for{$offline_val}
         if exists $alt_val_for{$offline_val};
      MKDEBUG && _d('alt val online:', $online_val, 'offline:', $offline_val);

      # Caller should eval us and catch this because although we try
      # to handle special cases for all sys vars, there's a lot of
      # sys vars and you may encounter one we've not dealt with before.
      die "Offline value for $var is undefined" unless defined $offline_val;
      die "Online value for $var is undefined"  unless defined $online_val;

      # Var is stale if the two values are not equal.  First try straight
      # string equality comparison.  If the vals are equal, stop.  If not,
      # try a special eq_for comparison if possible.
      if ( $offline_val ne $online_val ) {
         if ( !$eq_for{$var} || !$eq_for{$var}->($offline_val, $online_val) ) {
            MKDEBUG && _d('stale:', $var);
            $stale = 1;
         }
      }

      if ( $stale ) {
         push @stale, {
            var         => $var,
            online_val  => $config->get($var),
            offline_val => $config->get($var, offline=>1),
         }
      }
   }

   return \@stale;
}

# True if x is val1 or val2 and y is val1 or val2.
sub _veq { 
   my ( $x, $y, $val1, $val2 ) = @_;
   return 1 if ( ($x eq $val1 || $x eq $val2) && ($y eq $val1 || $y eq $val2) );
   return 0;
}

# True if paths are equal; adds trailing / to x or y if missing.
sub _patheq {
   my ( $x, $y ) = @_;
   $x .= '/' if $x !~ m/\/$/;
   $y .= '/' if $y !~ m/\/$/;
   return $x eq $y;
}

# True if x=1 (alt val for "ON") and y is true (any value), or vice-versa.
# This is for cases like log-bin=file (offline) == log_bin=ON (offline).
sub _eqifon { 
   my ( $x, $y ) = @_;
   return 1 if ( ($x && $x eq '1' ) && $y );
   return 1 if ( ($y && $y eq '1' ) && $x );
   return 0;
}

# True if offline value not set/configured (so online vals is
# some built-in default).
sub _eqifnoconf {
   my ( $conf_val, $online_val ) = @_;
   return $conf_val == 0 ? 1 : 0;
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
# End MySQLConfigComparer package
# ###########################################################################
