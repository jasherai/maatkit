# This program is copyright 2007-2009 Baron Schwartz.
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
# OptionParser package $Revision$
# ###########################################################################
package OptionParser;

use strict;
use warnings FATAL => 'all';

use Getopt::Long;
use List::Util qw(max);
use English qw(-no_match_vars);

use constant MKDEBUG => $ENV{MKDEBUG};

my $POD_link_re = '[LC]<"?([^">]+)"?>';

sub new {
   my ( $class, %args ) = @_;
   foreach my $arg ( qw(description) ) {
      die "I need a $arg argument" unless $args{$arg};
   }
   my $self = {
      description  => $args{description},
      prompt       => $args{prompt} || '<options>',
      dsn          => $args{dsn},
      opts         => {},
      short_opts   => {},
      defaults     => {},
      rules        => [],
      mutex        => [],
      atleast1     => [],
      groups       => [],
      disables     => {},
      copyfrom     => {},
      errors       => [],
      strict       => 1,
   };
   return bless $self, $class;
}

# Read and parse POD OPTIONS in file or current script if
# no file is given. This sub must be called before get_opts();
sub get_specs {
   my ( $self, $file ) = @_;
   my @specs = $self->_pod_to_specs($file);
   _parse_specs(@specs);
   return;
}

# Parse command line options from the OPTIONS section of the POD in the
# given file. If no file is given, the currently running program's POD
# is parsed.
# Returns an array of hashrefs which is usually passed to _parse_specs().
# Each hashref in the array corresponds to one command line option from
# the POD. Each hashref has the structure:
#    {
#       spec  => GetOpt::Long specification,
#       desc  => short description for --help
#       group => option group (if specified)
#    }
sub _pod_to_spec {
   my ( $self, $file ) = @_;
   $file ||= __FILE__;
   open my $fh, '<', $file or die "Cannot open $file: $OS_ERROR";

   my %types = (
      string => 's', # standard Getopt type
      'int'  => 'i', # standard Getopt type
      float  => 'f', # standard Getopt type
      Hash   => 'H', # hash, formed from a comma-separated list
      hash   => 'h', # hash as above, but only if a value is given
      Array  => 'A', # array, similar to Hash
      array  => 'a', # array, similar to hash
      DSN    => 'd', # DSN, as provided by a DSNParser which is in $self->{dsn}
      size   => 'z', # size with kMG suffix (powers of 2^10)
      'time' => 'm', # time, with an optional suffix of s/h/m/d
   );
   my @specs = ();
   my @rules = ();
   my $para;

   # Read a paragraph at a time from the file.  Skip everything until options
   # are reached...
   local $INPUT_RECORD_SEPARATOR = '';
   while ( $para = <$fh> ) {
      next unless $para =~ m/^=head1 OPTIONS/;
      last;
   }

   # ... then read any option rules...
   while ( $para = <$fh> ) {
      last if $para =~ m/^=over/;
      chomp $para;
      $para =~ s/\s+/ /g;
      $para =~ s/$POD_link_re/$1/go;
      MKDEBUG && _d('Option rule:', $para);
      push @rules, $para;
   }

   # ... then start reading options.
   do {
      if ( my ($option) = $para =~ m/^=item --(.*)/ ) {
         MKDEBUG && _d($para);
         my %attribs;

         $para = <$fh>; # read next paragraph, possibly attributes

         if ( $para =~ m/: / ) { # attributes
            $para =~ s/\s+\Z//g;
            %attribs = map { split(/: /, $_) } split(/; /, $para);
            if ( $attribs{'short form'} ) {
               $attribs{'short form'} =~ s/-//;
            }
            $para = <$fh>; # read next paragraph, probably short help desc
         }
         else {
            MKDEBUG && _d('Option has no attributes');
         }

         # Remove extra spaces and POD formatting (L<"">).
         $para =~ s/\s+\Z//g;
         $para =~ s/\s+/ /g;
         $para =~ s/$POD_link_re/$1/go;

         # Take the first period-terminated sentence as the
         # option's short help description. TODO: is this correct?
         if ( $para =~ m/^[^.]+\.$/ ) {
            $para =~ s/\.$//;
            MKDEBUG && _d('Short help:', $para);
         }
         else {
            die "No description found for option $option at paragraph $para!\n";
         };

         # Change [no]foo to foo and set negatable attrib. See issue 140.
         if ( my ($base_option) =  $option =~ m/^\[no\](.*)/ ) {
            $option = $base_option;
            $attribs{'negatable'} = 1;
         }

         push @specs, {
            spec => $option
               . ($attribs{'short form'} ? '|' . $attribs{'short form'} : '' )
               . ($attribs{'negatable'}  ? '!'                          : '' )
               . ($attribs{'cumulative'} ? '+'                          : '' )
               . ($attribs{'type'}       ? '=' . $types{$attribs{type}} : '' ),
            desc => $para
               . ($attribs{default} ? " (default $attribs{default})" : ''),
         };
      }
      while ( $para = <$fh> ) {
         last unless $para;

         # Look for rules in the option's full description.
         # TODO: I hacked this in here but I don't like it. Fishing around
         # in the full description is dangerous.
         if ( $option ) {
            if ( my ($line)
                  = $para =~ m/(allowed with --$option[:]?.*?)\./ ) {
               1 while ( $line =~ s/$POD_link_re/$1/go );
               push @rules, $line;
            }
         }

         if ( $para =~ m/^=head1/ ) {
            $para = undef; # Can't 'last' out of a do {} block.
            last;
         }
         last if $para =~ m/^=item --/;
      }
   } while ( $para );

   close $fh;
   return @specs, @rules;
}

# Parse an array of option specs and rules (usually the return value of
# _pod_to_spec()). Each option spec is parsed and the following attributes
# pairs are added to its hashref:
#    short         => the option's short key (-A for --charset)
#    is_cumulative => true if the option is cumulative
#    is_negatable  => true if the option is negatable
#    is_required   => true if the option is required
#    type          => the option's type (see %types in _pod_to_spec() above)
#    got           => true if the option was given explicitly on the cmd line
#    value         => the option's value
#
sub _parse_specs {
   my ( $self, @specs ) = @_;
   my %disables; # special rule that requires deferred checking

   foreach my $opt ( shift @specs ) {
      if ( ref $opt ) { # It's an option spec, not a rule.
         my ( $long, $short ) = $opt->{spec} =~ m/^([\w-]+)(?:\|([^!+=]*))?/;
         if ( !$long ) {
            # This shouldn't happen.
            die "Cannot parse long option from spec $opt->{spec}";
         }

         die "Duplicate long option --$long" if exists $self->{opts}->{$long};
         $self->{opts}->{$long} = $opt;

         if ( $short ) {
            die "Duplicate short option -$short"
               if exists $self->short_opts{$short};
            $self->short_opts{$short} = $long;
            $opt->{short} = $short;
         }
         else {
            $opt->{short} = undef;
         }

         $opt->{is_negatable}  = $opt->{spec} =~ m/!/;
         $opt->{is_cumulative} = $opt->{spec} =~ m/\+/;
         $opt->{is_required}   = $opt->{desc} =~ m/required/;

         # TODO: group 

         my ( $type ) = $opts->{spec} =~ m/=(.)/;
         $opt->{type} = $type;
         MKDEBUG && _d('Option', $long, 'type:', $type);
         if ( $type =~ m/=([HhAadzm])/) ) {
            # Option has a non-Getopt type: HhAadzm (see %types in
            # _pod_to_spec() above). For these, use Getopt type 's'.
            $opt->{type} = $type;
            $opt->{spec} =~ s/=./=s/;
         }

         # Option has a default value if its desc says 'default' or 'default X'.
         if ( (my ($def) = $opt->{desc} =~ m/default\b(?: ([^)]+))?/) ) {
            $self->{defaults}->{$long} = defined $def ? $def : 1;
            MKDEBUG && _d('Option', $long, 'default:', $def);
         }

         # Option disable another option if its desc says 'disable'.
         if ( (my ($dis) = $opt->{desc} =~ m/(disables .*)/) ) {
            # Defer checking till later because of possible forward references.
            $disables{$long} = $dis;
            MKDEBUG && _d('Deferring check of disables rule for', $opt, $dis);
         }
      }
      else { # It's an option rule, not a spec.
         push @{$self->{rules}}, $opt;
         my @participants = $self->_get_participants($opt);
         if ( $opt =~ m/mutually exclusive|one and only one/ ) {
            push @{$self->{mutex}}, \@participants;
            MKDEBUG && _d(@participants, 'are mutually exclusive');
         }
         elsif ( $opt =~ m/at least one|one and only one/ ) {
            push @{$self->{atleast1}}, \@participants;
            MKDEBUG && _d(@participants, 'require at least one');
         }
         elsif ( $opt =~ m/default to/ ) {
            # Example: "DSN values in L<"--dest"> default to values
            # from L<"--source">."
            $self->{copyfrom}->{$participants[0]} = $participants[1];
            MKDEBUG && _d(@participants, 'copy from each other');
         }
         # TODO: 'allowed with' is only used in mk-table-checksum.
         # Groups need to be used instead.
         else {
            die "Unrecognized option rule: $opt";
         }
      }
   }

   # Check forward references in 'disables' rules.
   foreach my $dis ( keys %disables ) {
MKDEBUG && _d('Option', $long, 'disables', $dis);
      $self->{disables}->{$dis} = [
         map {
            die "No such option '$_' while processing $dis"
               unless exists $self->{opts}->{$long};
         } @{$disables{$dis}}
      ];
   }

   return; 
}

# Returns an array of long option names in str. This is used to
# find the "participants" of option rules (i.e. the options to
# which a rule applies).
sub _get_participants {
   my ( $self, $str ) = @_;
   my @participants;
   while ( my ($long) = $str =m/\b--(?:\[no\])?([\w-]+)\b/g ) {
      die "Option --$long does not exist while processing rule $str"
         unless exists $self->{opts}->{$long};
      push @participants, $long;
   }
   MKDEBUG && _d('Participants for', $str, ':', @participants);
   return @participants;
}

# Get options on the command line (ARGV) according to the option specs
# and enforce option rules. Option values are saved internally in
# $self->{opts} and accessed later by get(), got() and set().
sub get_opts {
   my ( $self, %defaults ) = @_;
   my @specs = @{$self->{specs}};
   my %factor_for = (k => 1_024, M => 1_048_576, G => 1_073_741_824);
   my %opt_seen;
   my %vals = %{$self->{defaults}};
   # Defaults passed as arg override defaults from descriptions.
   @vals{keys %defaults} = values %defaults;
   foreach my $spec ( @specs ) {
      $vals{$spec->{k}} = undef unless defined $vals{$spec->{k}};
      $opt_seen{$spec->{k}} = 1;
   }

   foreach my $key ( keys %defaults ) {
      die "Cannot set default for non-existent option '$key'\n"
         unless $opt_seen{$key};
   }

   $self->{given} = {}; # in case options are re-parsed

   Getopt::Long::Configure('no_ignore_case', 'bundling');
   GetOptions(
      map {
         my $spec = $_;
         $spec->{s} => sub {
                          my ( $opt, $val ) = @_;
                          if ( $spec->{c} ) {
                             # Repeatable/cumulative option like -v -v
                             $vals{$spec->{k}}++
                          }
                          else {
                             $vals{$spec->{k}} = $val;
                          }
                          MKDEBUG && _d('Given option:',
                             $opt, '(',$spec->{k},') =', $val);
                          $self->{given}->{$spec->{k}} = $vals{$spec->{k}};
                       }
      } @specs
   ) or $self->error('Error parsing options');

   if ( $vals{version} ) {
      my $prog = $self->prog;
      printf("%s  Ver %s Distrib %s Changeset %s\n",
         $prog, $main::VERSION, $main::DISTRIB, $main::SVN_REV)
         or die "Cannot print: $OS_ERROR";
      exit(0);
   }

   if ( @ARGV && $self->{strict} ) {
      $self->error("Unrecognized command-line options @ARGV");
   }

   # Disable options as specified.
   foreach my $dis ( grep { defined $vals{$_} } keys %{$self->{disables}} ) {
      my @disses = map { $self->{key_for}->{$_} } @{$self->{disables}->{$dis}};
      MKDEBUG && _d('Unsetting options:', @disses);
      @vals{@disses} = map { undef } @disses;
   }

   # Check required options (oxymoron?)
   foreach my $spec ( grep { $_->{r} } @specs ) {
      if ( !defined $vals{$spec->{k}} ) {
         $self->error("Required option --$spec->{l} must be specified");
      }
   }

   # Check mutex options
   foreach my $mutex ( @{$self->{mutex}} ) {
      my @set = grep { defined $vals{$self->{key_for}->{$_}} } @$mutex;
      if ( @set > 1 ) {
         my $note = join(', ',
            map { "--$self->{long_for}->{$_}" }
                @{$mutex}[ 0 .. scalar(@$mutex) - 2] );
         $note .= " and --$self->{long_for}->{$mutex->[-1]}"
               . " are mutually exclusive.";
         $self->error($note);
      }
   }

   # Check mutually required options
   foreach my $required ( @{$self->{atleast1}} ) {
      my @set = grep { defined $vals{$self->{key_for}->{$_}} } @$required;
      if ( !@set ) {
         my $note = join(', ',
            map { "--$self->{long_for}->{$_}" }
                @{$required}[ 0 .. scalar(@$required) - 2] );
         $note .= " or --$self->{long_for}->{$required->[-1]}";
         $self->error("Specify at least one of $note");
      }
   }

   # Validate typed arguments.
   foreach my $spec ( grep { $_->{y} && defined $vals{$_->{k}} } @specs ) {
      my $val = $vals{$spec->{k}};
      if ( $spec->{y} eq 'm' ) {
         my ( $num, $suffix ) = $val =~ m/(\d+)([a-z])?$/;
         # The suffix defaults to 's' unless otherwise specified.
         if ( !$suffix ) {
            my ( $s ) = $spec->{d} =~ m/\(suffix (.)\)/;
            $suffix = $s || 's';
            MKDEBUG && _d('No suffix given; using', $suffix, 'for',
               $spec->{k}, '(value:', $val, ')');
         }
         if ( $suffix =~ m/[smhd]/ ) {
            $val = $suffix eq 's' ? $num            # Seconds
                 : $suffix eq 'm' ? $num * 60       # Minutes
                 : $suffix eq 'h' ? $num * 3600     # Hours
                 :                  $num * 86400;   # Days
            $vals{$spec->{k}} = $val;
            MKDEBUG && _d('Setting option', $spec->{k}, 'to', $val);
         }
         else {
            $self->error("Invalid --$spec->{l} argument");
         }
      }
      elsif ( $spec->{y} eq 'd' ) {
         MKDEBUG && _d('Parsing option', $spec->{y}, 'as a DSN');
         my $from_key = $self->{copyfrom}->{$spec->{k}};
         my $default = {};
         if ( $from_key ) {
            MKDEBUG && _d('Option', $spec->{y}, 'DSN copies from option',
               $from_key);
            $default = $self->{dsn}->parse($self->{dsn}->as_string($vals{$from_key}));
         }
         $vals{$spec->{k}} = $self->{dsn}->parse($val, $default);
      }
      elsif ( $spec->{y} eq 'z' ) {
         my ($pre, $num, $factor) = $val =~ m/^([+-])?(\d+)([kMG])?$/;
         if ( defined $num ) {
            if ( $factor ) {
               $num *= $factor_for{$factor};
               MKDEBUG && _d('Setting option', $spec->{y},
                  'to num', $num, '* factor', $factor);
            }
            $vals{$spec->{k}} = ($pre || '') . $num;
         }
         else {
            $self->error("Invalid --$spec->{l} argument");
         }
      }
   }

   # Process list arguments
   foreach my $spec ( grep { $_->{y} } @specs ) {
      MKDEBUG && _d('Treating option', $spec->{k}, 'as a list');
      my $val = $vals{$spec->{k}};
      if ( $spec->{y} eq 'H' || (defined $val && $spec->{y} eq 'h') ) {
         $vals{$spec->{k}} = { map { $_ => 1 } split(',', ($val || '')) };
      }
      elsif ( $spec->{y} eq 'A' || (defined $val && $spec->{y} eq 'a') ) {
         $vals{$spec->{k}} = [ split(',', ($val || '')) ];
      }
   }

   # Check allowed options
   # TODO: do this with groups
   foreach my $allowed_opts ( @{ $self->{allowed_with} } ) {
      # First element is opt with which the other ops are allowed
      my $opt = $allowed_opts->[0];
      next unless $vals{$opt};
      # This process could be more terse but by doing it this way we
      # can see what opts were defined (by either being given on the
      # cmd line or having default values) and therefore which of
      # those get unset due to not being allowed.
      my %defined_opts = map { $_ => 1 } grep { defined $vals{$_} } keys %vals;
      delete @defined_opts{ @$allowed_opts };
      # TODO: do error() when there's defined_opts still. Problem with
      # this: default values. Can't tell if an opt was actually
      # given on the cmd line or just given its default val. This may
      # not even be possible unless we somehow look at @ARGV and that
      # seems like a hack.
      foreach my $defined_opt ( keys %defined_opts ) {
         MKDEBUG
            && _d('Unsetting option', $defined_opt,
               '; it is not allowed with option', $opt);
         $vals{$defined_opt} = undef;
      }
   }

   return %vals;
}

# Get an option's value. The option can be either a
# short or long name (e.g. -A or --charset).
sub get {
   my ( $self, $opt ) = @_;
   my $opt_key = ($opt =~ m/./ ? $self->short_opts{$opt} : $opt);
   MKDEBUG && _d('Opt key for', $opt, 'is', $opt_key);
   if ( !exists $self->opts{$opt_key} ) {
      die "Option --$opt does not exist";
   }
   return $self->opts{$opt_key}->{value};
}

# Returns true if the option was given explicitly on the
# command line; returns false if not. The option can be
# either short or long name (e.g. -A or --charset).
sub got {
   my ( $self, $opt ) = @_;
   my $opt_key = ($opt =~ m/./ ? $self->short_opts{$opt} : $opt);
   MKDEBUG && _d('Opt key for', $opt, 'is', $opt_key);
   if ( !exists $self->opts{$opt_key} ) {
      die "Option --$opt does not exist";
   }
   return $self->opts{$opt_key}->{got};
}

# Set an option's value. The option can be either a
# short or long name (e.g. -A or --charset). The value
# can be any scalar, ref, or undef. No type checking
# is done so becareful to not set, for example, an integer
# option with a DSN.
sub set {
   my ( $self, $opt, $val ) = @_;
   my $opt_key = ($opt =~ m/./ ? $self->short_opts{$opt} : $opt);
   MKDEBUG && _d('Opt key for', $opt, 'is', $opt_key);
   if ( !exists $self->opts{$opt_key} ) {
      die "Option --$opt does not exist";
   }
   $self->opts{$opt_key}->{value} = $val;
   return;
}

sub enable_strict_mode {
   my ( $self ) = @_;
   $self->{strict} = 1;
   return;
}

sub disable_strict_mode {
   my ( $self ) = @_;
   $self->{strict} = 0;
   return;
}

# Save an error message to be reported later by calling usage_or_errors().
sub error {
   my ( $self, $error ) = @_;
   push @{$self->{errors}}, $error;
}

sub prog {
   (my $prog) = $PROGRAM_NAME =~ m/([.A-Za-z-]+)$/;
   return $prog || $PROGRAM_NAME;
}

sub prompt {
   my ( $self ) = @_;
   my $prog   = $self->prog;
   my $prompt = $self->{prompt} || '<options>';
   return "Usage: $prog $prompt\n";
}

sub descr {
   my ( $self ) = @_;
   my $prog = $self->prog;
   my $descr  = $prog . ' ' . ($self->{descr} || '')
          . "  For more details, please use the --help option, "
          . "or try 'perldoc $prog' for complete documentation.";
   $descr = join("\n", $descr =~ m/(.{0,80})(?:\s+|$)/g);
   $descr =~ s/ +$//mg;
   return $descr;
}

sub usage_or_errors {
   my ( $self, %opts ) = @_;
   if ( $opts{help} ) {
      print $self->usage(%opts)
         or die "Cannot print: $OS_ERROR";
      exit(0);
   }
   elsif ( scalar @{$self->{errors}} ) {
      print $self->errors() or die "Cannot print: $OS_ERROR";
      exit(0);
   }
}

# Explains what errors were found while processing command-line arguments and
# gives a brief overview so you can get more information.
sub errors {
   my ( $self ) = @_;
   my $usage = $self->prompt() . "\n";
   if ( (my @errors = @{$self->{errors}}) ) {
      $usage .= join("\n  * ", 'Errors in command-line arguments:', @errors) . "\n";
   }
   return $usage . "\n" . $self->descr();
}

# Prints out command-line help.  The format is like this:
# --foo  -F   Description of --foo
# --bars -B   Description of --bar
# --longopt   Description of --longopt
# Note that the short options are aligned along the right edge of their longest
# long option, but long options that don't have a short option are allowed to
# protrude past that.
sub usage {
   my ( $self, %vals ) = @_;
   my @specs = @{$self->{specs}};

   # Find how wide the widest long option is.
   my $maxl = max(map { length($_->{l}) + ($_->{n} ? 4 : 0)} @specs);

   # Find how wide the widest option with a short option is.
   my $maxs = max(0,
      map { length($_->{l}) + ($_->{n} ? 4 : 0)}
      grep { $_->{t} } @specs);

   # Find how wide the 'left column' (long + short opts) is, and therefore how
   # much space to give options and how much to give descriptions.
   my $lcol = max($maxl, ($maxs + 3));
   my $rcol = 80 - $lcol - 6;
   my $rpad = ' ' x ( 80 - $rcol );

   # Adjust the width of the options that have long and short both.
   $maxs = max($lcol - 3, $maxs);

   # Format and return the options.
   my $usage = $self->descr() . "\n" . $self->prompt();
   foreach my $g ( @{$self->{groups}} ) {
      $usage .= "\n$g->{d}:\n";
      foreach my $spec (
         sort { $a->{l} cmp $b->{l} } grep { $_->{g} eq $g->{k} } @specs )
      {
         my $long  = $spec->{n} ? "[no]$spec->{l}" : $spec->{l};
         my $short = $spec->{t};
         my $desc  = $spec->{d};
         # Expand suffix help for time options.
         if ( $spec->{y} && $spec->{y} eq 'm' ) {
            my ($s) = $desc =~ m/\(suffix (.)\)/;
            $s    ||= 's';
            $desc =~ s/\s+\(suffix .\)//;
            $desc .= ".  Optional suffix s=seconds, m=minutes, h=hours, "
                   . "d=days; if no suffix, $s is used.";
         }
         # Wrap long descriptions
         $desc = join("\n$rpad", grep { $_ } $desc =~ m/(.{0,$rcol})(?:\s+|$)/g);
         $desc =~ s/ +$//mg;
         if ( $short ) {
            $usage .= sprintf("  --%-${maxs}s -%s  %s\n", $long, $short, $desc);
         }
         else {
            $usage .= sprintf("  --%-${lcol}s  %s\n", $long, $desc);
         }
      }
   }

   if ( (my @instr = @{$self->{instr}}) ) {
      $usage .= join("\n", map { "  $_" } @instr) . "\n";
   }
   if ( $self->{dsn} ) {
      $usage .= "\n" . $self->{dsn}->usage();
   }
   $usage .= "\nOptions and values after processing arguments:\n";
   foreach my $spec ( sort { $a->{l} cmp $b->{l} } @specs ) {
      my $val   = $vals{$spec->{k}};
      my $type  = $spec->{y} || '';
      my $bool  = $spec->{s} =~ m/^[\w-]+(?:\|[\w-])?!?$/;
      $val      = $bool                     ? ( $val ? 'TRUE' : 'FALSE' )
                : !defined $val             ? '(No value)'
                : $type eq 'd'              ? $self->{dsn}->as_string($val)
                : $type =~ m/H|h/           ? join(',', sort keys %$val)
                : $type =~ m/A|a/           ? join(',', @$val)
                :                             $val;
      $usage .= sprintf("  --%-${lcol}s  %s\n", $spec->{l}, $val);
   }
   return $usage;
}

# Tries to prompt and read the answer without echoing the answer to the
# terminal.  This isn't really related to this package, but it's too handy not
# to put here.  OK, it's related, it gets config information from the user.
sub prompt_noecho {
   shift @_ if ref $_[0] eq __PACKAGE__;
   my ( $prompt ) = @_;
   local $OUTPUT_AUTOFLUSH = 1;
   print $prompt
      or die "Cannot print: $OS_ERROR";
   my $response;
   eval {
      require Term::ReadKey;
      Term::ReadKey::ReadMode('noecho');
      chomp($response = <STDIN>);
      Term::ReadKey::ReadMode('normal');
      print "\n"
         or die "Cannot print: $OS_ERROR";
   };
   if ( $EVAL_ERROR ) {
      die "Cannot read response; is Term::ReadKey installed? $EVAL_ERROR";
   }
   return $response;
}

sub groups {
   my ( $self, @groups ) = @_;
   push @{$self->{groups}}, @groups;
}

# This is debug code I want to run for all tools, and this is a module I
# certainly include in all tools, but otherwise there's no real reason to put
# it here.
if ( MKDEBUG ) {
   print '# ', $^X, ' ', $], "\n";
   my $uname = `uname -a`;
   if ( $uname ) {
      $uname =~ s/\s+/ /g;
      print "# $uname\n";
   }
   printf("# %s  Ver %s Distrib %s Changeset %s line %d\n",
      $PROGRAM_NAME, ($main::VERSION || ''), ($main::DISTRIB || ''),
      ($main::SVN_REV || ''), __LINE__);
   print('# Arguments: ',
      join(' ', map { my $a = "_[$_]_"; $a =~ s/\n/\n# /g; $a; } @ARGV), "\n");
}

# Reads the next paragraph from the POD after the magical regular expression is
# found in the text.
sub read_para_after {
   my ( $self, $file, $regex ) = @_;
   open my $fh, "<", $file or die "Can't open $file: $OS_ERROR";
   local $INPUT_RECORD_SEPARATOR = '';
   my $para;
   while ( $para = <$fh> ) {
      next unless $para =~ m/^=pod$/m;
      last;
   }
   while ( $para = <$fh> ) {
      next unless $para =~ m/$regex/;
      last;
   }
   $para = <$fh>;
   chomp($para);
   close $fh or die "Can't close $file: $OS_ERROR";
   return $para;
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
# End OptionParser2 package
# ###########################################################################
