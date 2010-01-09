#!/usr/bin/env perl

# This script splits ip.port sessions from a tcpdump file.

# ###########################################################################
# OptionParser package 4245
# ###########################################################################
package OptionParser;

use strict;
use warnings FATAL => 'all';

use Getopt::Long;
use List::Util qw(max);
use English qw(-no_match_vars);

use constant MKDEBUG => $ENV{MKDEBUG};

my $POD_link_re = '[LC]<"?([^">]+)"?>';

my %attributes = (
   'type'       => 1,
   'short form' => 1,
   'group'      => 1,
   'default'    => 1,
   'cumulative' => 1,
   'negatable'  => 1,
);

sub new {
   my ( $class, %args ) = @_;
   foreach my $arg ( qw(description) ) {
      die "I need a $arg argument" unless $args{$arg};
   }
   my ($program_name) = $PROGRAM_NAME =~ m/([.A-Za-z-]+)$/;
   $program_name ||= $PROGRAM_NAME;
   my $home = $ENV{HOME} || $ENV{HOMEPATH} || $ENV{USERPROFILE} || '.';

   my $self = {
      description    => $args{description},
      prompt         => $args{prompt} || '<options>',
      strict         => (exists $args{strict} ? $args{strict} : 1),
      dp             => $args{dp}     || undef,
      program_name   => $program_name,
      opts           => {},
      got_opts       => 0,
      short_opts     => {},
      defaults       => {},
      groups         => {},
      allowed_groups => {},
      errors         => [],
      rules          => [],  # desc of rules for --help
      mutex          => [],  # rule: opts are mutually exclusive
      atleast1       => [],  # rule: at least one opt is required
      disables       => {},  # rule: opt disables other opts 
      defaults_to    => {},  # rule: opt defaults to value of other opt
      default_files  => [
         "/etc/maatkit/maatkit.conf",
         "/etc/maatkit/$program_name.conf",
         "$home/.maatkit.conf",
         "$home/.$program_name.conf",
      ],
   };
   return bless $self, $class;
}

sub get_specs {
   my ( $self, $file ) = @_;
   my @specs = $self->_pod_to_specs($file);
   $self->_parse_specs(@specs);
   return;
}

sub get_defaults_files {
   my ( $self ) = @_;
   return @{$self->{default_files}};
}

sub _pod_to_specs {
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
      DSN    => 'd', # DSN, as provided by a DSNParser which is in $self->{dp}
      size   => 'z', # size with kMG suffix (powers of 2^10)
      'time' => 'm', # time, with an optional suffix of s/h/m/d
   );
   my @specs = ();
   my @rules = ();
   my $para;

   local $INPUT_RECORD_SEPARATOR = '';
   while ( $para = <$fh> ) {
      next unless $para =~ m/^=head1 OPTIONS/;
      last;
   }

   while ( $para = <$fh> ) {
      last if $para =~ m/^=over/;
      chomp $para;
      $para =~ s/\s+/ /g;
      $para =~ s/$POD_link_re/$1/go;
      MKDEBUG && _d('Option rule:', $para);
      push @rules, $para;
   }

   die 'POD has no OPTIONS section' unless $para;

   do {
      if ( my ($option) = $para =~ m/^=item --(.*)/ ) {
         chomp $para;
         MKDEBUG && _d($para);
         my %attribs;

         $para = <$fh>; # read next paragraph, possibly attributes

         if ( $para =~ m/: / ) { # attributes
            $para =~ s/\s+\Z//g;
            %attribs = map {
                  my ( $attrib, $val) = split(/: /, $_);
                  die "Unrecognized attribute for --$option: $attrib"
                     unless $attributes{$attrib};
                  ($attrib, $val);
               } split(/; /, $para);
            if ( $attribs{'short form'} ) {
               $attribs{'short form'} =~ s/-//;
            }
            $para = <$fh>; # read next paragraph, probably short help desc
         }
         else {
            MKDEBUG && _d('Option has no attributes');
         }

         $para =~ s/\s+\Z//g;
         $para =~ s/\s+/ /g;
         $para =~ s/$POD_link_re/$1/go;

         $para =~ s/\.(?:\n.*| [A-Z].*|\Z)//s;
         MKDEBUG && _d('Short help:', $para);

         die "No description after option spec $option" if $para =~ m/^=item/;

         if ( my ($base_option) =  $option =~ m/^\[no\](.*)/ ) {
            $option = $base_option;
            $attribs{'negatable'} = 1;
         }

         push @specs, {
            spec  => $option
               . ($attribs{'short form'} ? '|' . $attribs{'short form'} : '' )
               . ($attribs{'negatable'}  ? '!'                          : '' )
               . ($attribs{'cumulative'} ? '+'                          : '' )
               . ($attribs{'type'}       ? '=' . $types{$attribs{type}} : '' ),
            desc  => $para
               . ($attribs{default} ? " (default $attribs{default})" : ''),
            group => ($attribs{'group'} ? $attribs{'group'} : 'default'),
         };
      }
      while ( $para = <$fh> ) {
         last unless $para;


         if ( $para =~ m/^=head1/ ) {
            $para = undef; # Can't 'last' out of a do {} block.
            last;
         }
         last if $para =~ m/^=item --/;
      }
   } while ( $para );

   die 'No valid specs in POD OPTIONS' unless @specs;

   close $fh;
   return @specs, @rules;
}

sub _parse_specs {
   my ( $self, @specs ) = @_;
   my %disables; # special rule that requires deferred checking

   foreach my $opt ( @specs ) {
      if ( ref $opt ) { # It's an option spec, not a rule.
         MKDEBUG && _d('Parsing opt spec:',
            map { ($_, '=>', $opt->{$_}) } keys %$opt);

         my ( $long, $short ) = $opt->{spec} =~ m/^([\w-]+)(?:\|([^!+=]*))?/;
         if ( !$long ) {
            die "Cannot parse long option from spec $opt->{spec}";
         }
         $opt->{long} = $long;

         die "Duplicate long option --$long" if exists $self->{opts}->{$long};
         $self->{opts}->{$long} = $opt;

         if ( length $long == 1 ) {
            MKDEBUG && _d('Long opt', $long, 'looks like short opt');
            $self->{short_opts}->{$long} = $long;
         }

         if ( $short ) {
            die "Duplicate short option -$short"
               if exists $self->{short_opts}->{$short};
            $self->{short_opts}->{$short} = $long;
            $opt->{short} = $short;
         }
         else {
            $opt->{short} = undef;
         }

         $opt->{is_negatable}  = $opt->{spec} =~ m/!/        ? 1 : 0;
         $opt->{is_cumulative} = $opt->{spec} =~ m/\+/       ? 1 : 0;
         $opt->{is_required}   = $opt->{desc} =~ m/required/ ? 1 : 0;

         $opt->{group} ||= 'default';
         $self->{groups}->{ $opt->{group} }->{$long} = 1;

         $opt->{value} = undef;
         $opt->{got}   = 0;

         my ( $type ) = $opt->{spec} =~ m/=(.)/;
         $opt->{type} = $type;
         MKDEBUG && _d($long, 'type:', $type);

         if ( $type && $type eq 'd' && !$self->{dp} ) {
            die "$opt->{long} is type DSN (d) but no dp argument "
               . "was given when this OptionParser object was created";
         }

         $opt->{spec} =~ s/=./=s/ if ( $type && $type =~ m/[HhAadzm]/ );

         if ( (my ($def) = $opt->{desc} =~ m/default\b(?: ([^)]+))?/) ) {
            if ( $opt->{is_negatable} ) {
               $def = $def eq 'yes' ? 1
                    : $def eq 'no'  ? 0
                    : $def;
            }
            $self->{defaults}->{$long} = defined $def ? $def : 1;
            MKDEBUG && _d($long, 'default:', $def);
         }

         if ( $long eq 'config' ) {
            $self->{defaults}->{$long} = join(',', $self->get_defaults_files());
         }

         if ( (my ($dis) = $opt->{desc} =~ m/(disables .*)/) ) {
            $disables{$long} = $dis;
            MKDEBUG && _d('Deferring check of disables rule for', $opt, $dis);
         }

         $self->{opts}->{$long} = $opt;
      }
      else { # It's an option rule, not a spec.
         MKDEBUG && _d('Parsing rule:', $opt); 
         push @{$self->{rules}}, $opt;
         my @participants = $self->_get_participants($opt);
         my $rule_ok = 0;

         if ( $opt =~ m/mutually exclusive|one and only one/ ) {
            $rule_ok = 1;
            push @{$self->{mutex}}, \@participants;
            MKDEBUG && _d(@participants, 'are mutually exclusive');
         }
         if ( $opt =~ m/at least one|one and only one/ ) {
            $rule_ok = 1;
            push @{$self->{atleast1}}, \@participants;
            MKDEBUG && _d(@participants, 'require at least one');
         }
         if ( $opt =~ m/default to/ ) {
            $rule_ok = 1;
            $self->{defaults_to}->{$participants[0]} = $participants[1];
            MKDEBUG && _d($participants[0], 'defaults to', $participants[1]);
         }
         if ( $opt =~ m/restricted to option groups/ ) {
            $rule_ok = 1;
            my ($groups) = $opt =~ m/groups ([\w\s\,]+)/;
            my @groups = split(',', $groups);
            %{$self->{allowed_groups}->{$participants[0]}} = map {
               s/\s+//;
               $_ => 1;
            } @groups;
         }

         die "Unrecognized option rule: $opt" unless $rule_ok;
      }
   }

   foreach my $long ( keys %disables ) {
      my @participants = $self->_get_participants($disables{$long});
      $self->{disables}->{$long} = \@participants;
      MKDEBUG && _d('Option', $long, 'disables', @participants);
   }

   return; 
}

sub _get_participants {
   my ( $self, $str ) = @_;
   my @participants;
   foreach my $long ( $str =~ m/--(?:\[no\])?([\w-]+)/g ) {
      die "Option --$long does not exist while processing rule $str"
         unless exists $self->{opts}->{$long};
      push @participants, $long;
   }
   MKDEBUG && _d('Participants for', $str, ':', @participants);
   return @participants;
}

sub opts {
   my ( $self ) = @_;
   my %opts = %{$self->{opts}};
   return %opts;
}

sub opt_values {
   my ( $self ) = @_;
   my %opts = map {
      my $opt = $self->{opts}->{$_}->{short} ? $self->{opts}->{$_}->{short}
              : $_;
      $opt => $self->{opts}->{$_}->{value}
   } keys %{$self->{opts}};
   return %opts;
}

sub short_opts {
   my ( $self ) = @_;
   my %short_opts = %{$self->{short_opts}};
   return %short_opts;
}

sub set_defaults {
   my ( $self, %defaults ) = @_;
   $self->{defaults} = {};
   foreach my $long ( keys %defaults ) {
      die "Cannot set default for nonexistent option $long"
         unless exists $self->{opts}->{$long};
      $self->{defaults}->{$long} = $defaults{$long};
      MKDEBUG && _d('Default val for', $long, ':', $defaults{$long});
   }
   return;
}

sub get_defaults {
   my ( $self ) = @_;
   return $self->{defaults};
}

sub get_groups {
   my ( $self ) = @_;
   return $self->{groups};
}

sub _set_option {
   my ( $self, $opt, $val ) = @_;
   my $long = exists $self->{opts}->{$opt}       ? $opt
            : exists $self->{short_opts}->{$opt} ? $self->{short_opts}->{$opt}
            : die "Getopt::Long gave a nonexistent option: $opt";

   $opt = $self->{opts}->{$long};
   if ( $opt->{is_cumulative} ) {
      $opt->{value}++;
   }
   else {
      $opt->{value} = $val;
   }
   $opt->{got} = 1;
   MKDEBUG && _d('Got option', $long, '=', $val);
}

sub get_opts {
   my ( $self ) = @_; 

   foreach my $long ( keys %{$self->{opts}} ) {
      $self->{opts}->{$long}->{got} = 0;
      $self->{opts}->{$long}->{value}
         = exists $self->{defaults}->{$long}       ? $self->{defaults}->{$long}
         : $self->{opts}->{$long}->{is_cumulative} ? 0
         : undef;
   }
   $self->{got_opts} = 0;

   $self->{errors} = [];

   if ( @ARGV && $ARGV[0] eq "--config" ) {
      shift @ARGV;
      $self->_set_option('config', shift @ARGV);
   }
   if ( $self->has('config') ) {
      my @extra_args;
      foreach my $filename ( split(',', $self->get('config')) ) {
         eval {
            push @ARGV, $self->_read_config_file($filename);
         };
         if ( $EVAL_ERROR ) {
            if ( $self->got('config') ) {
               die $EVAL_ERROR;
            }
            elsif ( MKDEBUG ) {
               _d($EVAL_ERROR);
            }
         }
      }
      unshift @ARGV, @extra_args;
   }

   Getopt::Long::Configure('no_ignore_case', 'bundling');
   GetOptions(
      map    { $_->{spec} => sub { $self->_set_option(@_); } }
      grep   { $_->{long} ne 'config' } # --config is handled specially above.
      values %{$self->{opts}}
   ) or $self->save_error('Error parsing options');

   if ( exists $self->{opts}->{version} && $self->{opts}->{version}->{got} ) {
      printf("%s  Ver %s Distrib %s Changeset %s\n",
         $self->{program_name}, $main::VERSION, $main::DISTRIB, $main::SVN_REV)
            or die "Cannot print: $OS_ERROR";
      exit 0;
   }

   if ( @ARGV && $self->{strict} ) {
      $self->save_error("Unrecognized command-line options @ARGV");
   }

   foreach my $mutex ( @{$self->{mutex}} ) {
      my @set = grep { $self->{opts}->{$_}->{got} } @$mutex;
      if ( @set > 1 ) {
         my $err = join(', ', map { "--$self->{opts}->{$_}->{long}" }
                      @{$mutex}[ 0 .. scalar(@$mutex) - 2] )
                 . ' and --'.$self->{opts}->{$mutex->[-1]}->{long}
                 . ' are mutually exclusive.';
         $self->save_error($err);
      }
   }

   foreach my $required ( @{$self->{atleast1}} ) {
      my @set = grep { $self->{opts}->{$_}->{got} } @$required;
      if ( @set == 0 ) {
         my $err = join(', ', map { "--$self->{opts}->{$_}->{long}" }
                      @{$required}[ 0 .. scalar(@$required) - 2] )
                 .' or --'.$self->{opts}->{$required->[-1]}->{long};
         $self->save_error("Specify at least one of $err");
      }
   }

   foreach my $long ( keys %{$self->{opts}} ) {
      my $opt = $self->{opts}->{$long};
      if ( $opt->{got} ) {
         if ( exists $self->{disables}->{$long} ) {
            my @disable_opts = @{$self->{disables}->{$long}};
            map { $self->{opts}->{$_}->{value} = undef; } @disable_opts;
            MKDEBUG && _d('Unset options', @disable_opts,
               'because', $long,'disables them');
         }

         if ( exists $self->{allowed_groups}->{$long} ) {

            my @restricted_groups = grep {
               !exists $self->{allowed_groups}->{$long}->{$_}
            } keys %{$self->{groups}};

            my @restricted_opts;
            foreach my $restricted_group ( @restricted_groups ) {
               RESTRICTED_OPT:
               foreach my $restricted_opt (
                  keys %{$self->{groups}->{$restricted_group}} )
               {
                  next RESTRICTED_OPT if $restricted_opt eq $long;
                  push @restricted_opts, $restricted_opt
                     if $self->{opts}->{$restricted_opt}->{got};
               }
            }

            if ( @restricted_opts ) {
               my $err;
               if ( @restricted_opts == 1 ) {
                  $err = "--$restricted_opts[0]";
               }
               else {
                  $err = join(', ',
                            map { "--$self->{opts}->{$_}->{long}" }
                            grep { $_ } 
                            @restricted_opts[0..scalar(@restricted_opts) - 2]
                         )
                       . ' or --'.$self->{opts}->{$restricted_opts[-1]}->{long};
               }
               $self->save_error("--$long is not allowed with $err");
            }
         }

      }
      elsif ( $opt->{is_required} ) { 
         $self->save_error("Required option --$long must be specified");
      }

      $self->_validate_type($opt);
   }

   $self->{got_opts} = 1;
   return;
}

sub _validate_type {
   my ( $self, $opt ) = @_;
   return unless $opt && $opt->{type};
   my $val = $opt->{value};

   if ( $val && $opt->{type} eq 'm' ) {
      MKDEBUG && _d('Parsing option', $opt->{long}, 'as a time value');
      my ( $num, $suffix ) = $val =~ m/(\d+)([a-z])?$/;
      if ( !$suffix ) {
         my ( $s ) = $opt->{desc} =~ m/\(suffix (.)\)/;
         $suffix = $s || 's';
         MKDEBUG && _d('No suffix given; using', $suffix, 'for',
            $opt->{long}, '(value:', $val, ')');
      }
      if ( $suffix =~ m/[smhd]/ ) {
         $val = $suffix eq 's' ? $num            # Seconds
              : $suffix eq 'm' ? $num * 60       # Minutes
              : $suffix eq 'h' ? $num * 3600     # Hours
              :                  $num * 86400;   # Days
         $opt->{value} = $val;
         MKDEBUG && _d('Setting option', $opt->{long}, 'to', $val);
      }
      else {
         $self->save_error("Invalid time suffix for --$opt->{long}");
      }
   }
   elsif ( $val && $opt->{type} eq 'd' ) {
      MKDEBUG && _d('Parsing option', $opt->{long}, 'as a DSN');
      my $from_key = $self->{defaults_to}->{ $opt->{long} };
      my $default = {};
      if ( $from_key ) {
         MKDEBUG && _d($opt->{long}, 'DSN copies from', $from_key, 'DSN');
         $default = $self->{dp}->parse(
            $self->{dp}->as_string($self->{opts}->{$from_key}->{value}) );
      }
      $opt->{value} = $self->{dp}->parse($val, $default);
   }
   elsif ( $val && $opt->{type} eq 'z' ) {
      MKDEBUG && _d('Parsing option', $opt->{long}, 'as a size value');
      my %factor_for = (k => 1_024, M => 1_048_576, G => 1_073_741_824);
      my ($pre, $num, $factor) = $val =~ m/^([+-])?(\d+)([kMG])?$/;
      if ( defined $num ) {
         if ( $factor ) {
            $num *= $factor_for{$factor};
            MKDEBUG && _d('Setting option', $opt->{y},
               'to num', $num, '* factor', $factor);
         }
         $opt->{value} = ($pre || '') . $num;
      }
      else {
         $self->save_error("Invalid size for --$opt->{long}");
      }
   }
   elsif ( $opt->{type} eq 'H' || (defined $val && $opt->{type} eq 'h') ) {
      $opt->{value} = { map { $_ => 1 } split(',', ($val || '')) };
   }
   elsif ( $opt->{type} eq 'A' || (defined $val && $opt->{type} eq 'a') ) {
      $opt->{value} = [ split(/(?<!\\),/, ($val || '')) ];
   }
   else {
      MKDEBUG && _d('Nothing to validate for option',
         $opt->{long}, 'type', $opt->{type}, 'value', $val);
   }

   return;
}

sub get {
   my ( $self, $opt ) = @_;
   my $long = (length $opt == 1 ? $self->{short_opts}->{$opt} : $opt);
   die "Option $opt does not exist"
      unless $long && exists $self->{opts}->{$long};
   return $self->{opts}->{$long}->{value};
}

sub got {
   my ( $self, $opt ) = @_;
   my $long = (length $opt == 1 ? $self->{short_opts}->{$opt} : $opt);
   die "Option $opt does not exist"
      unless $long && exists $self->{opts}->{$long};
   return $self->{opts}->{$long}->{got};
}

sub has {
   my ( $self, $opt ) = @_;
   my $long = (length $opt == 1 ? $self->{short_opts}->{$opt} : $opt);
   return defined $long ? exists $self->{opts}->{$long} : 0;
}

sub set {
   my ( $self, $opt, $val ) = @_;
   my $long = (length $opt == 1 ? $self->{short_opts}->{$opt} : $opt);
   die "Option $opt does not exist"
      unless $long && exists $self->{opts}->{$long};
   $self->{opts}->{$long}->{value} = $val;
   return;
}

sub save_error {
   my ( $self, $error ) = @_;
   push @{$self->{errors}}, $error;
}

sub errors {
   my ( $self ) = @_;
   return $self->{errors};
}

sub prompt {
   my ( $self ) = @_;
   return "Usage: $PROGRAM_NAME $self->{prompt}\n";
}

sub descr {
   my ( $self ) = @_;
   my $descr  = $self->{program_name} . ' ' . ($self->{description} || '')
              . "  For more details, please use the --help option, "
              . "or try 'perldoc $PROGRAM_NAME' "
              . "for complete documentation.";
   $descr = join("\n", $descr =~ m/(.{0,80})(?:\s+|$)/g);
   $descr =~ s/ +$//mg;
   return $descr;
}

sub usage_or_errors {
   my ( $self ) = @_;
   if ( $self->{opts}->{help}->{got} ) {
      print $self->print_usage() or die "Cannot print usage: $OS_ERROR";
      exit 0;
   }
   elsif ( scalar @{$self->{errors}} ) {
      print $self->print_errors() or die "Cannot print errors: $OS_ERROR";
      exit 0;
   }
   return;
}

sub print_errors {
   my ( $self ) = @_;
   my $usage = $self->prompt() . "\n";
   if ( (my @errors = @{$self->{errors}}) ) {
      $usage .= join("\n  * ", 'Errors in command-line arguments:', @errors)
              . "\n";
   }
   return $usage . "\n" . $self->descr();
}

sub print_usage {
   my ( $self ) = @_;
   die "Run get_opts() before print_usage()" unless $self->{got_opts};
   my @opts = values %{$self->{opts}};

   my $maxl = max(
      map { length($_->{long}) + ($_->{is_negatable} ? 4 : 0) }
      @opts);

   my $maxs = max(0,
      map { length($_) + ($self->{opts}->{$_}->{is_negatable} ? 4 : 0) }
      values %{$self->{short_opts}});

   my $lcol = max($maxl, ($maxs + 3));
   my $rcol = 80 - $lcol - 6;
   my $rpad = ' ' x ( 80 - $rcol );

   $maxs = max($lcol - 3, $maxs);

   my $usage = $self->descr() . "\n" . $self->prompt();

   my @groups = reverse sort grep { $_ ne 'default'; } keys %{$self->{groups}};
   push @groups, 'default';

   foreach my $group ( reverse @groups ) {
      $usage .= "\n".($group eq 'default' ? 'Options' : $group).":\n\n";
      foreach my $opt (
         sort { $a->{long} cmp $b->{long} }
         grep { $_->{group} eq $group }
         @opts )
      {
         my $long  = $opt->{is_negatable} ? "[no]$opt->{long}" : $opt->{long};
         my $short = $opt->{short};
         my $desc  = $opt->{desc};
         if ( $opt->{type} && $opt->{type} eq 'm' ) {
            my ($s) = $desc =~ m/\(suffix (.)\)/;
            $s    ||= 's';
            $desc =~ s/\s+\(suffix .\)//;
            $desc .= ".  Optional suffix s=seconds, m=minutes, h=hours, "
                   . "d=days; if no suffix, $s is used.";
         }
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

   if ( (my @rules = @{$self->{rules}}) ) {
      $usage .= "\nRules:\n\n";
      $usage .= join("\n", map { "  $_" } @rules) . "\n";
   }
   if ( $self->{dp} ) {
      $usage .= "\n" . $self->{dp}->usage();
   }
   $usage .= "\nOptions and values after processing arguments:\n\n";
   foreach my $opt ( sort { $a->{long} cmp $b->{long} } @opts ) {
      my $val   = $opt->{value};
      my $type  = $opt->{type} || '';
      my $bool  = $opt->{spec} =~ m/^[\w-]+(?:\|[\w-])?!?$/;
      $val      = $bool                     ? ( $val ? 'TRUE' : 'FALSE' )
                : !defined $val             ? '(No value)'
                : $type eq 'd'              ? $self->{dp}->as_string($val)
                : $type =~ m/H|h/           ? join(',', sort keys %$val)
                : $type =~ m/A|a/           ? join(',', @$val)
                :                             $val;
      $usage .= sprintf("  --%-${lcol}s  %s\n", $opt->{long}, $val);
   }
   return $usage;
}

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

sub _read_config_file {
   my ( $self, $filename ) = @_;
   open my $fh, "<", $filename or die "Cannot open $filename: $OS_ERROR\n";
   my @args;
   my $prefix = '--';
   my $parse  = 1;

   LINE:
   while ( my $line = <$fh> ) {
      chomp $line;
      next LINE if $line =~ m/^\s*(?:\#|\;|$)/;
      $line =~ s/\s+#.*$//g;
      $line =~ s/^\s+|\s+$//g;
      if ( $line eq '--' ) {
         $prefix = '';
         $parse  = 0;
         next LINE;
      }
      if ( $parse
         && (my($opt, $arg) = $line =~ m/^\s*([^=\s]+?)(?:\s*=\s*(.*?)\s*)?$/)
      ) {
         push @args, grep { defined $_ } ("$prefix$opt", $arg);
      }
      elsif ( $line =~ m/./ ) {
         push @args, $line;
      }
      else {
         die "Syntax error in file $filename at line $INPUT_LINE_NUMBER";
      }
   }
   close $fh;
   return @args;
}

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

sub clone {
   my ( $self ) = @_;

   my %clone = map {
      my $hashref  = $self->{$_};
      my $val_copy = {};
      foreach my $key ( keys %$hashref ) {
         my $ref = ref $hashref->{$key};
         $val_copy->{$key} = !$ref           ? $hashref->{$key}
                           : $ref eq 'HASH'  ? { %{$hashref->{$key}} }
                           : $ref eq 'ARRAY' ? [ @{$hashref->{$key}} ]
                           : $hashref->{$key};
      }
      $_ => $val_copy;
   } qw(opts short_opts defaults);

   foreach my $scalar ( qw(got_opts) ) {
      $clone{$scalar} = $self->{$scalar};
   }

   return bless \%clone;     
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
# End OptionParser package
# ###########################################################################

# ###########################################################################
# TcpdumpParser package 5436
# ###########################################################################
package TcpdumpParser;

# This is a parser for tcpdump output.  It expects the output to be formatted a
# certain way.  See the t/samples/tcpdumpxxx.txt files for examples.  Here's a
# sample command on Ubuntu to produce the right formatted output:
# tcpdump -i lo port 3306 -s 1500 -x -n -q -tttt

use strict;
use warnings FATAL => 'all';
use English qw(-no_match_vars);
use Data::Dumper;
$Data::Dumper::Indent   = 1;
$Data::Dumper::Sortkeys = 1;

use constant MKDEBUG => $ENV{MKDEBUG} || 0;

sub new {
   my ( $class, %args ) = @_;
   my $self = {};
   return bless $self, $class;
}

# This method accepts an open filehandle and callback functions.
# It reads packets from the filehandle and calls the callbacks with each packet.
# $misc is some placeholder for the future and for compatibility with other
# query sources.
#
# Each packet is a hashref of attribute => value pairs like:
#
#  my $packet = {
#     ts          => '2009-04-12 21:18:40.638244',
#     src_host    => '192.168.1.5',
#     src_port    => '54321',
#     dst_host    => '192.168.1.1',
#     dst_port    => '3306',
#     complete    => 1|0,    # If this packet is a fragment or not
#     ip_hlen     => 5,      # Number of 32-bit words in IP header
#     tcp_hlen    => 8,      # Number of 32-bit words in TCP header
#     dgram_len   => 140,    # Length of entire datagram, IP+TCP+data, in bytes
#     data_len    => 30      # Length of data in bytes
#     data        => '...',  # TCP data
#     pos_in_log  => 10,     # Position of this packet in the log
#  };
#
# Returns the number of packets parsed.  The sub is called parse_event
# instead of parse_packet because mk-query-digest expects this for its
# modular parser objects.
sub parse_event {
   my ( $self, %args ) = @_;
   my @required_args = qw(next_event tell);
   foreach my $arg ( @required_args ) {
      die "I need a $arg argument" unless $args{$arg};
   }
   my ($next_event, $tell) = @args{@required_args};

   # We read a packet at a time.  Assuming that all packets begin with a
   # timestamp "20.....", we just use that as the separator, and restore it.
   # This will be good until the year 2100.
   local $INPUT_RECORD_SEPARATOR = "\n20";

   my $pos_in_log = $tell->();
   while ( defined(my $raw_packet = $next_event->()) ) {
      next if $raw_packet =~ m/^$/;  # issue 564
      $pos_in_log -= 1 if $pos_in_log;

      # Remove the separator from the packet, and restore it to the front if
      # necessary.
      $raw_packet =~ s/\n20\Z//;
      $raw_packet = "20$raw_packet" unless $raw_packet =~ m/\A20/;

      my $packet = $self->_parse_packet($raw_packet);
      $packet->{pos_in_log} = $pos_in_log;
      $packet->{raw_packet} = $raw_packet;

      return $packet;
   }

   $args{oktorun}->(0) if $args{oktorun};
   return;
}

# Takes a hex description of a TCP/IP packet and returns the interesting bits.
sub _parse_packet {
   my ( $self, $packet ) = @_;
   die "I need a packet" unless $packet;

   my ( $ts, $source, $dest )  = $packet =~ m/\A(\S+ \S+) IP .*?(\S+) > (\S+):/;
   my ( $src_host, $src_port ) = $source =~ m/((?:\d+\.){3}\d+)\.(\w+)/;
   my ( $dst_host, $dst_port ) = $dest   =~ m/((?:\d+\.){3}\d+)\.(\w+)/;

   # Change ports from service name to number.
   $src_port = $self->port_number($src_port);
   $dst_port = $self->port_number($dst_port);
   
   my $hex = qr/[0-9a-f]/;
   (my $data = join('', $packet =~ m/\s+0x$hex+:\s((?:\s$hex{2,4})+)/go)) =~ s/\s+//g; 

   # Find length information in the IPv4 header.  Typically 5 32-bit
   # words.  See http://en.wikipedia.org/wiki/IPv4#Header
   my $ip_hlen = hex(substr($data, 1, 1)); # Num of 32-bit words in header.
   # The total length of the entire datagram, including header.  This is
   # useful because it lets us see whether we got the whole thing.
   my $ip_plen = hex(substr($data, 4, 4)); # Num of BYTES in IPv4 datagram.
   my $complete = length($data) == 2 * $ip_plen ? 1 : 0;

   # Same thing in a different position, with the TCP header.  See
   # http://en.wikipedia.org/wiki/Transmission_Control_Protocol.
   my $tcp_hlen = hex(substr($data, ($ip_hlen + 3) * 8, 1));

   # Get sequence and ack numbers.
   my $seq = hex(substr($data, ($ip_hlen + 1) * 8, 8));
   my $ack = hex(substr($data, ($ip_hlen + 2) * 8, 8));

   my $flags = hex(substr($data, (($ip_hlen + 3) * 8) + 2, 2));

   # Throw away the IP and TCP headers.
   $data = substr($data, ($ip_hlen + $tcp_hlen) * 8);

   my $pkt = {
      ts        => $ts,
      seq       => $seq,
      ack       => $ack,
      fin       => $flags & 0x01,
      syn       => $flags & 0x02,
      rst       => $flags & 0x04,
      src_host  => $src_host,
      src_port  => $src_port,
      dst_host  => $dst_host,
      dst_port  => $dst_port,
      complete  => $complete,
      ip_hlen   => $ip_hlen,
      tcp_hlen  => $tcp_hlen,
      dgram_len => $ip_plen,
      data_len  => $ip_plen - (($ip_hlen + $tcp_hlen) * 4),
      data      => $data ? substr($data, 0, 10).(length $data > 10 ? '...' : '')
                         : '',
   };
   MKDEBUG && _d('packet:', Dumper($pkt));
   $pkt->{data} = $data;
   return $pkt;
}

sub port_number {
   my ( $self, $port ) = @_;
   return unless $port;
   return $port eq 'memcached' ? 11211
        : $port eq 'http'      ? 80
        : $port eq 'mysql'     ? 3306
        :                        $port; 
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
# End TcpdumpParser package
# ###########################################################################

package main;

use English qw(-no_match_vars);
use Time::HiRes qw(time);
use Data::Dumper;
$Data::Dumper::Indent    = 1;
$Data::Dumper::Sortkeys  = 1;
$Data::Dumper::Quotekeys = 0;

use constant MKDEBUG => $ENV{MKDEBUG};

my $o  = new OptionParser(
   strict      => 0,
   prompt      => '[OPTION...] FILE IP.PORT [IP.PORT...]',
   description => q{splits IP.PORT from tcpdump FILE.},
);
$o->get_specs();
$o->get_opts();

$o->usage_or_errors();

my $file = shift @ARGV;
open my $fh, '<', $file or die "Cannot open $file: $OS_ERROR";

my @sessions = map { qr/$_/o } @ARGV;

local $INPUT_RECORD_SEPARATOR = "\n20";

while ( defined(my $raw_packet = <$fh>) ) {
   next if $raw_packet =~ m/^$/;  # issue 564

   $raw_packet =~ s/\n20\Z//;
   $raw_packet = "20$raw_packet" unless $raw_packet =~ m/\A20/;

   foreach my $session ( @sessions ) {
      print "$raw_packet\n" if $raw_packet =~ m/$session/;
   }
}

close $fh;
exit 0;

sub _d {
   my ($package, undef, $line) = caller 0;
   @_ = map { (my $temp = $_) =~ s/\n/\n# /g; $temp; }
        map { defined $_ ? $_ : 'undef' }
        @_;
   print STDERR "# $package:$line $PID ", join(' ', @_), "\n";
}

# #############################################################################
# Documentation.
# #############################################################################

=pod

=head1 NAME

split-tcpdump.pl

=head1 SYNOPSIS

  split-tcpdump.pl tcpdump.txt 1.2.3.4.57028

=head1 OPTIONS

=over

=item --help

Show help and exit.

=back

=head1 AUTHOR

Daniel Nichter

=head1 VERSION

$Revision:$

=cut
