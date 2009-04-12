#!/usr/bin/perl

use strict;
use warnings FATAL => 'all';

use Test::More tests => 44;
use English qw(-no_match_vars);
use Data::Dumper;
$Data::Dumper::Quotekeys = 0;
$Data::Dumper::Sortkeys  = 1;
$Data::Dumper::Indent    = 1;

require "../TcpdumpParser.pm";

my $p = new TcpdumpParser;

sub run_test {
   my ( $def ) = @_;
   map     { die "What is $_ for?" }
      grep { $_ !~ m/^(?:misc|file|result|num_events)$/ }
      keys %$def;
   my @e;
   my $num_events = 0;
   eval {
      open my $fh, "<", $def->{file} or die $OS_ERROR;
      $num_events++ while $p->parse_event($fh, $def->{misc}, sub { push @e, @_ });
      close $fh;
   };
   is($EVAL_ERROR, '', "No error on $def->{file}");
   if ( defined $def->{result} ) {
      is_deeply(\@e, $def->{result}, $def->{file})
         or print "Got: ", Dumper(\@e);
   }
   if ( defined $def->{num_events} ) {
      is($num_events, $def->{num_events}, "$def->{file} num_events");
   }
}

# Check that I can parse a really simple session.
run_test({
   file   => 'samples/tcpdump002.txt',
   misc   => { watching => '127.0.0.1.3306' },
   result => [
      {  ts            => '090411 20:52:55.696357',
         db            => undef,
         user          => 'msandbox',
         host          => '127.0.0.1',
         ip            => '127.0.0.1',
         port          => '50321',
         arg           => 'administrator command: Connect',
         Query_time    => 0.010625999988406,
         pos_in_log    => 1229,
         bytes         => length('administrator command: Connect'),
         cmd           => 'Admin',
      },
   ],
});
