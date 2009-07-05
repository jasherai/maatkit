#!/usr/bin/perl

use strict;
use warnings FATAL => 'all';

use Test::More tests => 29;
use English qw(-no_match_vars);

require "../MemcachedProtocolParser.pm";
require "../TcpdumpParser.pm";

use Data::Dumper;
$Data::Dumper::Quotekeys = 0;
$Data::Dumper::Sortkeys  = 1;
$Data::Dumper::Indent    = 1;

my $tcpdump  = new TcpdumpParser();
my $protocol; # Create a new MemcachedProtocolParser for each test.

sub load_data {
   my ( $file ) = @_;
   open my $fh, '<', $file or BAIL_OUT("Cannot open $file: $OS_ERROR");
   my $contents = do { local $/ = undef; <$fh> };
   close $fh;
   (my $data = join('', $contents =~ m/(.*)/g)) =~ s/\s+//g;
   return $data;
}

sub run_test {
   my ( $def ) = @_;
   map     { die "What is $_ for?" }
      grep { $_ !~ m/^(?:misc|file|result|num_events|desc)$/ }
      keys %$def;
   my @e;
   my $num_events = 0;

   my @callbacks;
   push @callbacks, sub {
      my ( $packet ) = @_;
      return $protocol->parse_packet($packet, undef);
   };
   push @callbacks, sub {
      push @e, @_;
   };

   eval {
      open my $fh, "<", $def->{file}
         or BAIL_OUT("Cannot open $def->{file}: $OS_ERROR");
      $num_events++ while $tcpdump->parse_event($fh, undef, @callbacks);
      close $fh;
   };
   is($EVAL_ERROR, '', "No error on $def->{file}");
   if ( defined $def->{result} ) {
      is_deeply(
         \@e,
         $def->{result},
         $def->{file} . ($def->{desc} ? ": $def->{desc}" : '')
      ) or print "Got: ", Dumper(\@e);
   }
   if ( defined $def->{num_events} ) {
      is($num_events, $def->{num_events}, "$def->{file} num_events");
   }

   # Uncomment this if you're hacking the unknown.
   # print "Events for $def->{file}: ", Dumper(\@e);

   return;
}

# Check that I can parse a really simple session.
$protocol = new MemcachedProtocolParser();
run_test({
   file   => 'samples/memc_tcpdump001.txt',
   result => [
      {  ts            => '2009-07-04 21:33:39.229179',
         host          => '127.0.0.1',
         arg           => 'set my_key',
         flags         => '0',
         exptime       => '0',
         bytes         => '10',
         res           => 'STORED',
         Query_time    => sprintf('%.6f', .229299 - .229179),
         pos_in_log    => 0,
      },
   ],
});

# #############################################################################
# Done.
# #############################################################################
exit;
