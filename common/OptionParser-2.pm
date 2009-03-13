# This program is copyright 2007-@CURRENTYEAR@ Baron Schwartz.
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

# Parse command line options from the OPTIONS section of the POD in the
# given file. If no file is given, the currently running program's POD
# is parsed.
# Returns an array of hashrefs which is usually passed to OptionParser::new().
# Each hashref in the array corresponds to one command line option from
# the POD. Each hashref has the structure:
#    {
#       s => GetOpt::Long specification,
#       d => --help output (see HELP_DESCRIPTION below)
#       g => Optional grouping (default is "o => Options")
#    }
sub pod_to_spec {
   my ( $self, $file ) = @_;
   $file ||= __FILE__;
   open my $fh, '<', $file or die "Can't open $file: $OS_ERROR";

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
   my $option;

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
      MKDEBUG && _d('First option rules: '. $para);
      push @rules, $para;
   }

   # ... then start reading options.
   do {
      if ( ($option) = $para =~ m/^=item --(.*)/ ) {
         MKDEBUG && _d($para);
         my %props;
         $para = <$fh>;
         if ( $para =~ m/: / ) {
            $para =~ s/\s+\Z//g;
            %props = map { split(/: /, $_) } split(/; /, $para);
            if ( $props{'short form'} ) {
               $props{'short form'} =~ s/-//;
            }
            $para = <$fh>;
         }
         $para =~ s/\s+\Z//g;
         $para =~ s/\s+/ /g;
         $para =~ s/$POD_link_re/$1/go;
         if ( $para =~ m/^[^.]+\.$/ ) {
            $para =~ s/\.$//;
         }

         # Change [no]foo to foo and set negatable prop. See issue 140.
         if ( my ($base_option) =  $option =~ m/^\[no\](.*)/ ) {
            $option = $base_option;
            $props{'negatable'} = 1;
         }

         push @specs, {
            s => $option
               . ( $props{'short form'} ? '|' . $props{'short form'} : '' )
               . ( $props{'negatable'}  ? '!'                        : '' )
               . ( $props{'cumulative'} ? '+'                        : '' )
               . ( $props{type}         ? '=' . $types{$props{type}} : '' ),
            d => $para
               . (defined $props{default} ? " (default $props{default})" : ''),
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
# pod_to_spec()). Each option spec is parsed and the following key: value
# pairs are added to its hashref:
#    k: the option's key (usually the option's short form)
#    l: the option's long name
#    t: the option's short name
#    c: whether the option is cumulative
#    n: whether the option is negatable
#    r: whether the option is required
#    y: option's type (see %types in pod_to_spec() above)
sub new {
   my ( $class, @opts ) = @_;
   my %key_seen;
   my %long_seen;
   my %key_for;
   my %defaults;
   my @mutex;
   my @atleast1;
   my %long_for;
   my %disables;
   my %copyfrom;
   my @allowed_with;

   # Add these standard options automagically.
   unshift @opts,
      { s => 'help',    d => 'Show this help message' },
      { s => 'version', d => 'Output version information and exit' };

   foreach my $opt ( @opts ) {
      if ( ref $opt ) { # It's an option spec, not a rule.
         my ( $long, $short ) = $opt->{s} =~ m/^([\w-]+)(?:\|([^!+=]*))?/;
         $opt->{k} = $short || $long;
         $key_for{$long} = $opt->{k};
         $long_for{$opt->{k}} = $long;
         $long_for{$long} = $long;
         $opt->{l} = $long;
         die "Duplicate option $opt->{k}" if $key_seen{$opt->{k}}++;
         die "Duplicate long option $opt->{l}" if $long_seen{$opt->{l}}++;
         $opt->{t} = $short;
         $opt->{n} = $opt->{s} =~ m/!/;
         $opt->{c} = $opt->{s} =~ m/\+/;
         $opt->{g} ||= 'o';
         # Option has a type
         if ( (my ($y) = $opt->{s} =~ m/=([mdHhAaz])/) ) {
            MKDEBUG && _d("Option $opt->{k} type: $y");
            $opt->{y} = $y;
            $opt->{s} =~ s/=./=s/;
         }
         # Option is required if it contains the word 'required'
         if ( $opt->{d} =~ m/required/ ) {
            $opt->{r} = 1;
            MKDEBUG && _d("Option $opt->{k} is required");
         }
         # Option has a default value if it says 'default' or 'default X'
         if ( (my ($def) = $opt->{d} =~ m/default\b(?: ([^)]+))?/) ) {
            $defaults{$opt->{k}} = defined $def ? $def : 1;
            MKDEBUG && _d("Option $opt->{k} has a default");
         }
         if ( (my ($dis) = $opt->{d} =~ m/(disables .*)/) ) {
            # Defer checking till later because of possible forward references
            $disables{$opt->{k}} = [ $class->get_participants($dis) ];
            MKDEBUG && _d("Option $opt->{k} $dis");
         }
      }
      else { # It's an option rule, not a spec.
         if ( $opt =~ m/at least one|mutually exclusive|one and only one/ ) {
            my @participants = map {
                  die "No such option '$_' in $opt" unless $long_for{$_};
                  $long_for{$_};
               } $class->get_participants($opt);
            if ( $opt =~ m/mutually exclusive|one and only one/ ) {
               push @mutex, \@participants;
               MKDEBUG && _d(@participants, ' are mutually exclusive');
            }
            if ( $opt =~ m/at least one|one and only one/ ) {
               push @atleast1, \@participants;
               MKDEBUG && _d(@participants, ' require at least one');
            }
         }
         elsif ( $opt =~ m/default to/ ) {
            # It's an --x defaults to --y option.
            my @participants = map {
                  die "No such option '$_' in $opt" unless $long_for{$_};
                  $key_for{$_};
               } $class->get_participants($opt);
            $copyfrom{$participants[0]} = $participants[1];
            MKDEBUG && _d(@participants, ' copy from each other');
         }
         elsif ( $opt  =~ m/allowed with/ ) {
            my @participants = map {
                  die "No such option '$_' while processing $opt"
                     unless $long_for{$_};
                  $key_for{$_};
               } $class->get_participants($opt);
            push @allowed_with, \@participants;
         }
      }
   }

   # Check forward references (and convert to long options) in 'disables' rules.
   foreach my $dis ( keys %disables ) {
      $disables{$dis} = [
            map {
               if ( !defined $long_for{$_} ) {
                  die "No such option '$_' while processing $dis";
               }
               $long_for{$_};
            } @{$disables{$dis}}
      ];
   }

   my $self = {
      specs        => [ grep { ref $_ } @opts ],
      errors       => [],
      instr        => [ grep { !ref $_ } @opts ],
      mutex        => \@mutex,
      defaults     => \%defaults,
      long_for     => \%long_for,
      atleast1     => \@atleast1,
      disables     => \%disables,
      key_for      => \%key_for,
      copyfrom     => \%copyfrom,
      strict       => 1,
      groups       => [ { k => 'o', d => 'Options' } ],
      allowed_with => \@allowed_with,
      given        => {},
   };

   return bless $self, $class;
}

sub get_participants {
   my ( $self, $str ) = @_;
   my @participants;
   foreach my $thing ( $str =~ m/(--?[\w-]+)/g ) {
      if ( (my ($long) = $thing =~ m/--(.+)/) ) {
         push @participants, $long;
      }
      else {
         foreach my $short ( $thing =~ m/([^-])/g ) {
            push @participants, $short;
         }
      }
   }
   MKDEBUG && _d("Participants for $str: ", @participants);
   return @participants;
}

# Parse options on the command line (ARGV) according to the option specs
# and enforce option rules.
# Returns a hash of all options and their final values. An option's final
# value depends on many factors: it's default value, it's value given on
# the command line, whether it is subject to a rule, etc.
sub parse {
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
                          MKDEBUG && _d("Given option: $opt ($spec->{k}) "
                             . " = $val");
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
      MKDEBUG && _d("Unsetting options: ", @disses);
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
            MKDEBUG && _d("No suffix given; using $suffix for $spec->{k} "
               . "(value: '$val')");
         }
         if ( $suffix =~ m/[smhd]/ ) {
            $val = $suffix eq 's' ? $num            # Seconds
                 : $suffix eq 'm' ? $num * 60       # Minutes
                 : $suffix eq 'h' ? $num * 3600     # Hours
                 :                  $num * 86400;   # Days
            $vals{$spec->{k}} = $val;
            MKDEBUG && _d("Setting option $spec->{k} to $val");
         }
         else {
            $self->error("Invalid --$spec->{l} argument");
         }
      }
      elsif ( $spec->{y} eq 'd' ) {
         MKDEBUG && _d("Parsing option $spec->{y} as a DSN");
         my $from_key = $self->{copyfrom}->{$spec->{k}};
         my $default = {};
         if ( $from_key ) {
            MKDEBUG && _d("Option $spec->{y} DSN copies from option $from_key");
            $default = $self->{dsn}->parse($self->{dsn}->as_string($vals{$from_key}));
         }
         $vals{$spec->{k}} = $self->{dsn}->parse($val, $default);
      }
      elsif ( $spec->{y} eq 'z' ) {
         my ($pre, $num, $factor) = $val =~ m/^([+-])?(\d+)([kMG])?$/;
         if ( defined $num ) {
            if ( $factor ) {
               $num *= $factor_for{$factor};
               MKDEBUG && _d("Setting option $spec->{y} to num * factor");
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
      MKDEBUG && _d("Treating option $spec->{k} as a list");
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
            && _d("Unsetting options: $defined_opt (not allowed with $opt)");
         $vals{$defined_opt} = undef;
      }
   }

   return %vals;
}

sub error {
   my ( $self, $note ) = @_;
   $self->{__error__} = 1;
   push @{$self->{errors}}, $note;
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
   elsif ( $self->{__error__} ) {
      print $self->errors()
         or die "Cannot print: $OS_ERROR";
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
   # Use $$ instead of $PID in case the package
   # does not use English.
   print "# $package:$line $$ ", @_, "\n";
}

1;

# ###########################################################################
# End OptionParser2 package
# ###########################################################################
