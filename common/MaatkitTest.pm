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

use strict;
use warnings FATAL => 'all';
use English qw(-no_match_vars);
use Test::More;
use Time::HiRes qw(usleep);

require Exporter;
our @ISA         = qw(Exporter);
our %EXPORT_TAGS = ();
our @EXPORT      = qw();
our @EXPORT_OK   = qw(
   output
   load_data
   load_file
   wait_until
   test_log_parser
   test_protocol_parser
   no_diff
);

use constant MKDEBUG => $ENV{MKDEBUG} || 0;

# This sub doesn't work yet because "mk_upgrade::main" needs to be ref somehow.
sub output {
   my $output = '';
   open my $output_fh, '>', \$output
      or BAIL_OUT("Cannot capture output to variable: $OS_ERROR");
   select $output_fh;
   eval { mk_upgrade::main(@_); };
   close $output_fh;
   select STDOUT;
   return $EVAL_ERROR ? $EVAL_ERROR : $output;
}

# Load data from file and removes spaces.
sub load_data {
   my ( $file ) = @_;
   open my $fh, '<', $file or BAIL_OUT("Cannot open $file: $OS_ERROR");
   my $contents = do { local $/ = undef; <$fh> };
   close $fh;
   (my $data = join('', $contents =~ m/(.*)/g)) =~ s/\s+//g;
   return $data;
}

sub load_file {
   my ( $file, %args ) = @_;
   open my $fh, "<", $file or die "Cannot open $file: $OS_ERROR";
   my $contents = do { local $/ = undef; <$fh> };
   close $fh;
   chomp $contents if $args{chomp_contents};
   return $contents;
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


sub _read {
   my ( $fh ) = @_;
   return <$fh>;
}

sub test_log_parser {
   my ( %args ) = @_;
   foreach my $arg ( qw(parser file) ) {
      BAIL_OUT("I need a $arg argument") unless $args{$arg};
   }
   my $p = $args{parser};

   # Make sure caller isn't giving us something we don't understand.
   # We could ignore it, but then caller might not get the results
   # they expected.
   map  { BAIL_OUT("What is $_ for?") }
   grep { $_ !~ m/^(?:parser|misc|file|result|num_events|oktorun)$/ }
   keys %args;

   my @e;
   eval {
      open my $fh, "<", $args{file}
         or BAIL_OUT("Cannot open $args{file}: $OS_ERROR");
      my %parser_args = (
         next_event => sub { return _read($fh); },
         tell       => sub { return tell($fh);  },
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
      BAIL_OUT("I need a $arg argument") unless $args{$arg};
   }
   my $parser   = $args{parser};
   my $protocol = $args{protocol};

   # Make sure caller isn't giving us something we don't understand.
   # We could ignore it, but then caller might not get the results
   # they expected.
   map { BAIL_OUT("What is $_ for?") }
   grep { $_ !~ m/^(?:parser|protocol|misc|file|result|num_events|desc)$/ }
   keys %args;

   my @e;
   eval {
      open my $fh, "<", $args{file}
         or BAIL_OUT("Cannot open $args{file}: $OS_ERROR");
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
