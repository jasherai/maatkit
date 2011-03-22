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
# MySQLConfigComparer package $Revision$
# ###########################################################################
package MySQLConfigComparer;

use strict;
use warnings FATAL => 'all';
use English qw(-no_match_vars);
use Data::Dumper;
$Data::Dumper::Indent    = 1;
$Data::Dumper::Sortkeys  = 1;
$Data::Dumper::Quotekeys = 0;

use constant MKDEBUG => $ENV{MKDEBUG} || 0;

# Alternate values because a config file can have var=ON and then be shown
# in SHOW VARS as var=TRUE.  I.e. there's several synonyms for basic
# true (1) and false (0), so we normalize them to make comparisons easier.
my %alt_val_for = (
   ON    => 1,
   YES   => 1,
   TRUE  => 1,
   OFF   => 0,
   NO    => 0,
   FALSE => 0,
#   ''    => 0,
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

   log_bin                   => sub { return _eqifon(@_);               },
   log_slow_queries          => sub { return _eqifon(@_);               },

   general_log_file          => sub { return _optvaleq(@_);             },
   innodb_data_file_path     => sub { return _optvaleq(@_);             },
   innodb_log_group_home_dir => sub { return _optvaleq(@_);             },
   log_error                 => sub { return _optvaleq(@_);             },
   slow_query_log_file       => sub { return _optvaleq(@_);             },
   tmpdir                    => sub { return _optvaleq(@_);             },
   binlog_format             => sub { return _optvaleq(@_);             },

   long_query_time           => sub { return $_[0] == $_[1] ? 1 : 0;    },

   datadir                   => sub { return _eqdatadir(@_);            },
);

# The value of these vars are relative to some base-path.  In config files
# just a filename can be given, but in SHOW VARS the full /base/path/filename
# is shown.  So we have to qualify the config value with the correct base-path.
my %relative_path = (
   language  => 'basedir',
   log_error => 'datadir',
);

sub new {
   my ( $class, %args ) = @_;
   my $self = {
   };
   return bless $self, $class;
}

# Takes an arrayref of MySQLConfig objects and compares the first to the others.
# Returns an arrayref of hashrefs of variables that differ, like:
#   {
#      var  => max_connections,
#      vals => [ 100, 50 ],
#   },
# The value for each differing var is an arrayref of values corresponding
# to the given configs.  So $configs[N] = $differing_var->[N].  Only vars
# in the first config are compared, so if $configs[0] has var "foo" but
# $configs[1] does not, then the var is skipped.  Similarly, if $configs[1]
# has var "bar" but $configs[0] does not, then the var is not compared.
# Called missing() to discover which vars are missing in the configs.
sub diff {
   my ( $self, %args ) = @_;
   my @required_args = qw(configs);
   foreach my $arg( @required_args ) {
      die "I need a $arg argument" unless $args{$arg};
   }
   my ($config_objs) = @args{@required_args};

   my $diffs = {};
   return $diffs if @$config_objs < 2;  # nothing to compare
   MKDEBUG && _d('diff configs:', Dumper($config_objs));

   my $vars     = [ map { $_->get_variables() }     @$config_objs ];
   my $versions = [ map { $_->get_mysql_version() } @$config_objs ];

   # Get list of vars that exist in all configs (intersection of their keys).
   my @vars = grep { !$ignore_vars{$_} } $self->key_intersect($vars);

   # Make a list of values from each config for all the common vars.  So,
   #   %vals = {
   #     var1 => [ config0-var1-val, config1-var1-val ],
   #     var2 => [ config0-var2-val, config1-var2-val ],
   #   }
   my %vals = map {
      my $var = $_;

      # Var specifies a directory path if it ends in "dir" or is "language".
      # (language is an exception; hopefully there won't be any more.) 
      my $is_dir   = $var =~ m/dir$/ || $var eq 'language';
      my $rel_path = $relative_path{$var};

      my $vals = [
         map {
            my $config = $_;
            my $val    = defined $config->{$var} ? $config->{$var} : '';
            $val       = $alt_val_for{$val} if exists $alt_val_for{$val};

            if ( $val ) {
               if ( $is_dir ) {
                  $val .= '/' unless $val =~ m/\/$/;
               }
               if ( $rel_path && $val !~ m/^\// ) {
                  my $base_path = $config->{ $relative_path{$var} } || "";
                  $val =~ s/^\.?(.+)/$base_path\/$1/;  # prepend base-path
                  $val =~ s/\/{2,}/\//g;  # make redundant // single /
               }
            }

            $val;
         } @$vars
      ];
      $var => $vals;
   } @vars;

   VAR:
   foreach my $var ( sort keys %vals ) {
      my $vals     = $vals{$var};
      my $last_val = scalar @$vals - 1;

      eval {
         # Compare config0 val to other configs' val.
         # Stop when a difference is found.
         VAL:
         for my $i ( 1..$last_val ) {
            # First try straight string equality comparison.  If the vals
            # are equal, stop.  If not, try a special eq_for comparison.
            if ( $vals->[0] ne $vals->[$i] ) {
               if (    !$eq_for{$var}
                    || !$eq_for{$var}->($vals->[0], $vals->[$i], $versions) ) {
                  $diffs->{$var} = [
                     map { $_->{$var} } @$vars  # original vals
                  ];
                  last VAL;
               }
            }
         } # VAL
      };
      if ( $EVAL_ERROR ) {
         my $vals = join(', ', map { defined $_ ? $_ : 'undef' } @$vals);
         warn "Comparing $var values ($vals) caused an error: $EVAL_ERROR";
      }
   } # VAR

   return $diffs;
}

sub missing {
   my ( $self, %args ) = @_;
   my @required_args = qw(configs);
   foreach my $arg( @required_args ) {
      die "I need a $arg argument" unless $args{$arg};
   }
   my ($config_objs) = @args{@required_args};

   my $missing = {};
   return $missing if @$config_objs < 2;  # nothing to compare
   MKDEBUG && _d('missing configs:', Dumper(\@$config_objs));

   my @configs = map { $_->get_variables() } @$config_objs;

   # Get all unique vars and how many times each exists.
   my %vars;
   map { $vars{$_}++ } map { keys %{$configs[$_]} } 0..$#configs;

   # If a var exists less than the number of configs then it is
   # missing from at least one of the configs.
   my $n_configs = scalar @configs;
   foreach my $var ( keys %vars ) {
      if ( $vars{$var} < $n_configs ) {
         $missing->{$var} = [ map { exists $_->{$var} ? 0 : 1 } @configs ];
      }
   }

   return $missing;
}

# True if x is val1 or val2 and y is val1 or val2.
sub _veq { 
   my ( $x, $y, $versions, $val1, $val2 ) = @_;
   return 1 if ( ($x eq $val1 || $x eq $val2) && ($y eq $val1 || $y eq $val2) );
   return 0;
}

sub _eqdatadir {
   my ( $x, $y, $versions ) = @_;
   if ( ($versions->[0] || '') gt '5.1.0' && (($y || '') eq '.') ) {
      MKDEBUG && _d("MySQL 5.1 datadir conf val bug:", $x, $y);
      return 1;
   }
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

# Optional value equality.  Equal if one val doesn't specify so other
# value uses a default/built-in.  Or, if both specify something, standard
# equality test.  This essentially a string version of _eqifon().
sub _optvaleq {
   my ( $x, $y ) = @_;  
   if (    (!$x &&  $y)   # x=, y=default val
        || ( $x && !$y) ) # x=default val, y=
   {
      return 1;
   }
   
   # Both x and y specify a value.  Are they the same?
   return $x eq $y ? 1 : 0;
}

# Given an arrayref of hashes, returns an array of keys that
# are the intersection of all the hashes' keys.  Example:
#   my $foo = { foo=>1, nit=>1   };
#   my $bar = { bar=>2, bla=>'', };
#   my $zap = { zap=>3, foo=>2,  };
#   my @a   = ( $foo, $bar, $zap );
# key_intersect(\@a) return ['foo'].
sub key_intersect {
   my ( $self, $hashes ) = @_;
   my %keys  = map { $_ => 1 } keys %{$hashes->[0]};
   my $n_hashes = (scalar @$hashes) - 1;
   my @isect = grep { $keys{$_} } map { keys %{$hashes->[$_]} } 1..$n_hashes;
   return @isect;
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
