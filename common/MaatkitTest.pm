# This program is copyright 2009-@CURRENTYEAR@ Percona Inc.
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
# MaatkitTest package $Revision$
# ###########################################################################
package MaatkitTest;

# These are common subs used in Maatkit test scripts.

BEGIN {
   die "The MAATKIT_TRUNK environment variable is not set.  See http://code.google.com/p/maatkit/wiki/Testing"
      unless $ENV{MAATKIT_TRUNK} && -d $ENV{MAATKIT_TRUNK};
   unshift @INC, "$ENV{MAATKIT_TRUNK}/common";
};
our $trunk = $ENV{MAATKIT_TRUNK};

use strict;
use warnings FATAL => 'all';
use English qw(-no_match_vars);
use Test::More;
use Time::HiRes qw(usleep);
use POSIX qw(signal_h);
use Data::Dumper;
$Data::Dumper::Indent    = 1;
$Data::Dumper::Sortkeys  = 1;
$Data::Dumper::Quotekeys = 0;

require Exporter;
our @ISA         = qw(Exporter);
our %EXPORT_TAGS = ();
our @EXPORT      = qw(
   load_data
   load_file
   parse_file
   wait_until
   wait_for
   test_log_parser
   test_protocol_parser
   test_packet_parser
   no_diff
   $trunk
);
our @EXPORT_OK   = qw(output);

use constant MKDEBUG => $ENV{MKDEBUG} || 0;


# This sub doesn't work yet because "mk_upgrade::main" needs to be ref somehow.
sub output {
   my $output = '';
   open my $output_fh, '>', \$output
      or die "Cannot capture output to variable: $OS_ERROR";
   select $output_fh;
   eval { mk_upgrade::main(@_); };
   close $output_fh;
   select STDOUT;
   return $EVAL_ERROR ? $EVAL_ERROR : $output;
}

# Load data from file and removes spaces.  Used to load tcpdump dumps.
sub load_data {
   my ( $file ) = @_;
   $file = "$trunk/$file";
   open my $fh, '<', $file or die "Cannot open $file: $OS_ERROR";
   my $contents = do { local $/ = undef; <$fh> };
   close $fh;
   (my $data = join('', $contents =~ m/(.*)/g)) =~ s/\s+//g;
   return $data;
}

# Slurp file and return its entire contents.
sub load_file {
   my ( $file, %args ) = @_;
   $file = "$trunk/$file";
   open my $fh, "<", $file or die "Cannot open $file: $OS_ERROR";
   my $contents = do { local $/ = undef; <$fh> };
   close $fh;
   chomp $contents if $args{chomp_contents};
   return $contents;
}

sub parse_file {
   my ( $file, $p, $ea ) = @_;
   $file = "$trunk/$file";
   my @e;
   eval {
      open my $fh, "<", $file or die "Cannot open $file: $OS_ERROR";
      my %args = (
         next_event => sub { return <$fh>;    },
         tell       => sub { return tell $fh; },
         fh         => $fh,
      );
      while ( my $e = $p->parse_event(%args) ) {
         push @e, $e;
         $ea->aggregate($e) if $ea;
      }
      close $fh;
   };
   die $EVAL_ERROR if $EVAL_ERROR;
   return \@e;
}

# Wait until code returns true.
sub wait_until {
   my ( $code, $t, $max_t ) = @_;
   my $slept     = 0;
   my $sleep_int = $t || .5;
   $t     ||= .5;
   $max_t ||= 5;
   $t *= 1_000_000;
   while ( $slept <= $max_t ) {
      return if $code->();
      usleep($t);
      $slept += $sleep_int;
   }
   return;
}

# Wait t seconds for code to return.
sub wait_for {
   my ( $code, $t ) = @_;
   $t ||= 0;
   my $mask   = POSIX::SigSet->new(&POSIX::SIGALRM);
   my $action = POSIX::SigAction->new(
      sub { die },
      $mask,
   );
   my $oldaction = POSIX::SigAction->new();
   sigaction(&POSIX::SIGALRM, $action, $oldaction);
   eval {
      alarm $t;
      $code->();
      alarm 0;
   };
   if ( $EVAL_ERROR ) {
      # alarm was raised
      return 1;
   }
   return 0;
}

sub _read {
   my ( $fh ) = @_;
   return <$fh>;
}

sub test_log_parser {
   my ( %args ) = @_;
   foreach my $arg ( qw(parser file) ) {
      die "I need a $arg argument" unless $args{$arg};
   }
   my $p = $args{parser};

   # Make sure caller isn't giving us something we don't understand.
   # We could ignore it, but then caller might not get the results
   # they expected.
   map  { die "What is $_ for?"; }
   grep { $_ !~ m/^(?:parser|misc|file|result|num_events|oktorun)$/ }
   keys %args;

   my $file = "$trunk/$args{file}";
   my @e;
   eval {
      open my $fh, "<", $file or die "Cannot open $file: $OS_ERROR";
      my %parser_args = (
         next_event => sub { return _read($fh); },
         tell       => sub { return tell($fh);  },
         fh         => $fh,
         misc       => $args{misc},
         oktorun    => $args{oktorun},
      );
      while ( my $e = $p->parse_event(%parser_args) ) {
         push @e, $e;
      }
      close $fh;
   };

   is(
      $EVAL_ERROR,
      '',
      "No error on $args{file}"
   );

   if ( defined $args{result} ) {
      is_deeply(
         \@e,
         $args{result},
         $args{file}
      ) or print "Got: ", Dumper(\@e);
   }

   if ( defined $args{num_events} ) {
      is(
         scalar @e,
         $args{num_events},
         "$args{file} num_events"
      );
   }

   return \@e;
}

sub test_protocol_parser {
   my ( %args ) = @_;
   foreach my $arg ( qw(parser protocol file) ) {
      die "I need a $arg argument" unless $args{$arg};
   }
   my $parser   = $args{parser};
   my $protocol = $args{protocol};

   # Make sure caller isn't giving us something we don't understand.
   # We could ignore it, but then caller might not get the results
   # they expected.
   map { die "What is $_ for?"; }
   grep { $_ !~ m/^(?:parser|protocol|misc|file|result|num_events|desc)$/ }
   keys %args;

   my $file = "$trunk/$args{file}";
   my @e;
   eval {
      open my $fh, "<", $file or die "Cannot open $file: $OS_ERROR";
      my %parser_args = (
         next_event => sub { return _read($fh); },
         tell       => sub { return tell($fh);  },
         misc       => $args{misc},
      );
      while ( my $p = $parser->parse_event(%parser_args) ) {
         my $e = $protocol->parse_event(%parser_args, event => $p);
         push @e, $e if $e;
      }
      close $fh;
   };

   is(
      $EVAL_ERROR,
      '',
      "No error on $args{file}"
   );
   
   if ( defined $args{result} ) {
      is_deeply(
         \@e,
         $args{result},
         $args{file} . ($args{desc} ? ": $args{desc}" : '')
      ) or print "Got: ", Dumper(\@e);
   }

   if ( defined $args{num_events} ) {
      is(
         scalar @e,
         $args{num_events},
         "$args{file} num_events"
      );
   }

   return \@e;
}

sub test_packet_parser {
   my ( %args ) = @_;
   foreach my $arg ( qw(parser file) ) {
      die "I need a $arg argument" unless $args{$arg};
   }
   my $parser   = $args{parser};

   # Make sure caller isn't giving us something we don't understand.
   # We could ignore it, but then caller might not get the results
   # they expected.
   map { die "What is $_ for?"; }
   grep { $_ !~ m/^(?:parser|misc|file|result|desc|oktorun)$/ }
   keys %args;

   my $file = "$trunk/$args{file}";
   my @packets;
   open my $fh, '<', $file or BAIL_OUT("Cannot open $file: $OS_ERROR");
   my %parser_args = (
      next_event => sub { return _read($fh); },
      tell       => sub { return tell($fh);  },
      misc       => $args{misc},
      oktorun    => $args{oktorun},
   );
   while ( my $packet = $parser->parse_event(%parser_args) ) {
      push @packets, $packet;
   }

   # raw_packet is the actual dump text from the file.  It's used
   # in MySQLProtocolParser but I don't think we need to double-check
   # it here.  It will make the results very long.
   foreach my $packet ( @packets ) {
      delete $packet->{raw_packet};
   }

   if ( !is_deeply(
         \@packets,
         $args{result},
         "$args{file}" . ($args{desc} ? ": $args{desc}" : '')
      ) ) {
      print Dumper(\@packets);
   }

   return;
}
# Returns true (1) if there's no difference between the
# cmd's output and the expected output.
sub no_diff {
   my ( $cmd, $expected_output, $update_sample ) = @_;
   MKDEBUG && diag($cmd);
   `$cmd > /tmp/mk-query-digest_test`;
   if ( $ENV{UPDATE_SAMPLES} || $update_sample ) {
      `cat /tmp/mk-query-digest_test > $expected_output`;
      print STDERR "Updated $expected_output\n";
   }
   my $retval = system("diff /tmp/mk-query-digest_test $expected_output");
   `rm -rf /tmp/mk-query-digest_test`;
   $retval = $retval >> 8; 
   return !$retval;
}

1;

# ###########################################################################
# End MaatkitTest package
# ###########################################################################
