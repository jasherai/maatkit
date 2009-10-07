#!/usr/bin/perl

use strict;
use warnings FATAL => 'all';
use English qw(-no_match_vars);
use Test::More tests => 24;

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

# A session with a simple set().
$protocol = new MemcachedProtocolParser();
run_test({
   file   => 'samples/memc_tcpdump001.txt',
   result => [
      {  ts            => '2009-07-04 21:33:39.229179',
         host          => '127.0.0.1',
         cmd           => 'set',
         key           => 'my_key',
         val           => 'Some value',
         flags         => '0',
         exptime       => '0',
         bytes         => '10',
         res           => 'STORED',
         Query_time    => sprintf('%.6f', .229299 - .229179),
         pos_in_log    => 0,
      },
   ],
});

# A session with a simple get().
$protocol = new MemcachedProtocolParser();
run_test({
   file   => 'samples/memc_tcpdump002.txt',
   result => [
      {  Query_time => '0.000067',
         cmd        => 'get',
         key        => 'my_key',
         val        => 'Some value',
         bytes      => 10,
         exptime    => 0,
         flags      => 0,
         host       => '127.0.0.1',
         pos_in_log => '0',
         res        => 'VALUE',
         ts         => '2009-07-04 22:12:06.174390'
      },
   ],
});

# A session with a simple incr() and decr().
$protocol = new MemcachedProtocolParser();
run_test({
   file   => 'samples/memc_tcpdump003.txt',
   result => [
      {  Query_time => '0.000073',
         cmd        => 'incr',
         key        => 'key',
         val        => '8',
         bytes      => 0,
         exptime    => 0,
         flags      => 0,
         host       => '127.0.0.1',
         pos_in_log => '0',
         res        => '',
         ts         => '2009-07-04 22:12:06.175734',
      },
      {  Query_time => '0.000068',
         cmd        => 'decr',
         bytes      => 0,
         exptime    => 0,
         flags      => 0,
         host       => '127.0.0.1',
         key        => 'key',
         pos_in_log => 522,
         res        => '',
         ts         => '2009-07-04 22:12:06.176181',
         val => '7',
      },
   ],
});

# A session with a simple incr() and decr(), but the value doesn't exist.
$protocol = new MemcachedProtocolParser();
run_test({
   file   => 'samples/memc_tcpdump004.txt',
   result => [
      {  Query_time => '0.000131',
         bytes      => 0,
         cmd        => 'incr',
         exptime    => 0,
         flags      => 0,
         host       => '127.0.0.1',
         key        => 'key',
         pos_in_log => 764,
         res        => 'NOT_FOUND',
         ts         => '2009-07-06 10:37:21.668469',
         val        => '',
      },
      {
         Query_time => '0.000055',
         bytes      => 0,
         cmd        => 'decr',
         exptime    => 0,
         flags      => 0,
         host       => '127.0.0.1',
         key        => 'key',
         pos_in_log => 1788,
         res        => 'NOT_FOUND',
         ts         => '2009-07-06 10:37:21.668851',
         val        => '',
      },
   ],
});

# A session with a huge set() that will not fit into a single TCP packet.
$protocol = new MemcachedProtocolParser();
run_test({
   file   => 'samples/memc_tcpdump005.txt',
   result => [
      {  Query_time => '0.003928',
         bytes      => 17946,
         cmd        => 'set',
         exptime    => 0,
         flags      => 0,
         host       => '127.0.0.1',
         key        => 'my_key',
         pos_in_log => 764,
         res        => 'STORED',
         ts         => '2009-07-06 22:07:14.406827',
         val        => ('lorem ipsum dolor sit amet' x 690) . ' fini!',
      },
   ],
});

# A session with a huge get() that will not fit into a single TCP packet.
$protocol = new MemcachedProtocolParser();
run_test({
   file   => 'samples/memc_tcpdump006.txt',
   result => [
      {
         Query_time => '0.000196',
         bytes      => 17946,
         cmd        => 'get',
         exptime    => 0,
         flags      => 0,
         host       => '127.0.0.1',
         key        => 'my_key',
         pos_in_log => 0,
         res        => 'VALUE',
         ts         => '2009-07-06 22:07:14.411331',
         val        => ('lorem ipsum dolor sit amet' x 690) . ' fini!',
      },
   ],
});

# A session with a get() that doesn't exist.
$protocol = new MemcachedProtocolParser();
run_test({
   file   => 'samples/memc_tcpdump007.txt',
   result => [
      {
         Query_time => '0.000016',
         bytes      => 0,
         cmd        => 'get',
         exptime    => 0,
         flags      => 0,
         host       => '127.0.0.1',
         key        => 'comment_v3_482685',
         pos_in_log => 0,
         res        => 'NOT_FOUND',
         ts         => '2009-06-11 21:54:49.059144',
         val        => '',
      },
   ],
});

# A session with a huge get() that will not fit into a single TCP packet, but
# the connection seems to be broken in the middle of the receive and then the
# new client picks up and asks for something different.
$protocol = new MemcachedProtocolParser();
run_test({
   file   => 'samples/memc_tcpdump008.txt',
   result => [
      {
         Query_time => '0.000003',
         bytes      => 17946,
         cmd        => 'get',
         exptime    => 0,
         flags      => 0,
         host       => '127.0.0.1',
         key        => 'my_key',
         pos_in_log => 0,
         res        => 'INTERRUPTED',
         ts         => '2009-07-06 22:07:14.411331',
         val        => '',
      },
      {  Query_time => '0.000001',
         cmd        => 'get',
         key        => 'my_key',
         val        => 'Some value',
         bytes      => 10,
         exptime    => 0,
         flags      => 0,
         host       => '127.0.0.1',
         pos_in_log => 5382,
         res        => 'VALUE',
         ts         => '2009-07-06 22:07:14.411334',
      },
   ],
});

# A session with a delete() that doesn't exist. TODO: delete takes a queue_time.
$protocol = new MemcachedProtocolParser();
run_test({
   file   => 'samples/memc_tcpdump009.txt',
   result => [
      {
         Query_time => '0.000022',
         bytes      => 0,
         cmd        => 'delete',
         exptime    => 0,
         flags      => 0,
         host       => '127.0.0.1',
         key        => 'comment_1873527',
         pos_in_log => 0,
         res        => 'NOT_FOUND',
         ts         => '2009-06-11 21:54:52.244534',
         val        => '',
      },
   ],
});

# A session with a delete() that does exist.
$protocol = new MemcachedProtocolParser();
run_test({
   file   => 'samples/memc_tcpdump010.txt',
   result => [
      {
         Query_time => '0.000120',
         bytes      => 0,
         cmd        => 'delete',
         exptime    => 0,
         flags      => 0,
         host       => '127.0.0.1',
         key        => 'my_key',
         pos_in_log => 0,
         res        => 'DELETED',
         ts         => '2009-07-09 22:00:29.066476',
         val        => '',
      },
   ],
});

# #############################################################################
# Issue 537: MySQLProtocolParser and MemcachedProtocolParser do not handle
# multiple servers.
# #############################################################################
$protocol = new MemcachedProtocolParser();
run_test({
   file   => 'samples/memc_tcpdump011.txt',
   result => [
      {  Query_time => '0.000067',
         cmd        => 'get',
         key        => 'my_key',
         val        => 'Some value',
         bytes      => 10,
         exptime    => 0,
         flags      => 0,
         host       => '127.0.0.8',
         pos_in_log => '0',
         res        => 'VALUE',
         ts         => '2009-07-04 22:12:06.174390'
      },
      {  ts            => '2009-07-04 21:33:39.229179',
         host          => '127.0.0.9',
         cmd           => 'set',
         key           => 'my_key',
         val           => 'Some value',
         flags         => '0',
         exptime       => '0',
         bytes         => '10',
         res           => 'STORED',
         Query_time    => sprintf('%.6f', .229299 - .229179),
         pos_in_log    => 638,
      },
   ],
});

# #############################################################################
# Issue 544: memcached parse error
# #############################################################################
$protocol = new MemcachedProtocolParser();
run_test({
   file   => 'samples/memc_tcpdump014.txt',
   result => [
      {  ts          => '2009-10-06 10:31:56.323538',
         Query_time  => '0.000024',
         bytes       => 0,
         cmd         => 'delete',
         exptime     => 0,
         flags       => 0,
         host        => '10.0.0.5',
         key         => 'ABBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBC',
         pos_in_log  => 0,
         res         => 'NOT_FOUND',
         val         => ''
      },
   ],
});

# #############################################################################
# Done.
# #############################################################################
exit;
