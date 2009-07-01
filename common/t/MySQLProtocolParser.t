#!/usr/bin/perl

use strict;
use warnings FATAL => 'all';

use Test::More tests => 29;
use English qw(-no_match_vars);

require "../MySQLProtocolParser.pm";
require "../TcpdumpParser.pm";

use Data::Dumper;
$Data::Dumper::Quotekeys = 0;
$Data::Dumper::Sortkeys  = 1;
$Data::Dumper::Indent    = 1;

my $tcpdump  = new TcpdumpParser();
my $protocol; # Create a new MySQLProtocolParser for each test.

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
$protocol = new MySQLProtocolParser();
run_test({
   file   => 'samples/tcpdump001.txt',
   result => [
      {  ts            => '090412 09:50:16.805123',
         db            => undef,
         user          => undef,
         Thread_id     => undef,
         host          => '127.0.0.1',
         ip            => '127.0.0.1',
         port          => '42167',
         arg           => 'select "hello world" as greeting',
         Query_time    => sprintf('%.6f', .805123 - .804849),
         pos_in_log    => 0,
         bytes         => length('select "hello world" as greeting'),
         cmd           => 'Query',
         Error_no      => 'none',
         Rows_affected => 0,
         Warning_count      => 0,
         No_good_index_used => 'No',
         No_index_used      => 'No',
      },
   ],
});

# A more complex session with a complete login/logout cycle.
$protocol = new MySQLProtocolParser();
run_test({
   file   => 'samples/tcpdump002.txt',
   result => [
      {  ts         => "090412 11:00:13.118191",
         db         => 'mysql',
         user       => 'msandbox',
         host       => '127.0.0.1',
         ip         => '127.0.0.1',
         port       => '57890',
         arg        => 'administrator command: Connect',
         Query_time => '0.011152',
         Thread_id  => 8,
         pos_in_log => 1470,
         bytes      => length('administrator command: Connect'),
         cmd        => 'Admin',
         Error_no   => 'none',
         Rows_affected => 0,
         Warning_count      => 0,
         No_good_index_used => 'No',
         No_index_used      => 'No',
      },
      {  Query_time => '0.000265',
         Thread_id  => 8,
         arg        => 'select @@version_comment limit 1',
         bytes      => length('select @@version_comment limit 1'),
         cmd        => 'Query',
         db         => 'mysql',
         host       => '127.0.0.1',
         ip         => '127.0.0.1',
         port       => '57890',
         pos_in_log => 2449,
         ts         => '090412 11:00:13.118643',
         user       => 'msandbox',
         Error_no   => 'none',
         Rows_affected => 0,
         Warning_count      => 0,
         No_good_index_used => 'No',
         No_index_used      => 'No',
      },
      {  Query_time => '0.000167',
         Thread_id  => 8,
         arg        => 'select "paris in the the spring" as trick',
         bytes      => length('select "paris in the the spring" as trick'),
         cmd        => 'Query',
         db         => 'mysql',
         host       => '127.0.0.1',
         ip         => '127.0.0.1',
         port       => '57890',
         pos_in_log => 3298,
         ts         => '090412 11:00:13.119079',
         user       => 'msandbox',
         Error_no   => 'none',
         Rows_affected => 0,
         Warning_count      => 0,
         No_good_index_used => 'No',
         No_index_used      => 'No',
      },
      {  Query_time => '0.000000',
         Thread_id  => 8,
         arg        => 'administrator command: Quit',
         bytes      => 27,
         cmd        => 'Admin',
         db         => 'mysql',
         host       => '127.0.0.1',
         ip         => '127.0.0.1',
         port       => '57890',
         pos_in_log => '4186',
         ts         => '090412 11:00:13.119487',
         user       => 'msandbox',
         Error_no   => 'none',
         Rows_affected => 0,
         Warning_count      => 0,
         No_good_index_used => 'No',
         No_index_used      => 'No',
      },
   ],
});

# A session that has an error during login.
$protocol = new MySQLProtocolParser();
run_test({
   file   => 'samples/tcpdump003.txt',
   result => [
      {  ts         => "090412 12:41:46.357853",
         db         => '',
         user       => 'msandbox',
         host       => '127.0.0.1',
         ip         => '127.0.0.1',
         port       => '44488',
         arg        => 'administrator command: Connect',
         Query_time => '0.010753',
         Thread_id  => 9,
         pos_in_log => 1455,
         bytes      => length('administrator command: Connect'),
         cmd        => 'Admin',
         Error_no   => "#1045",
         Rows_affected => 0,
         Warning_count      => 0,
         No_good_index_used => 'No',
         No_index_used      => 'No',
      },
   ],
});

# A session that has an error executing a query
$protocol = new MySQLProtocolParser();
run_test({
   file   => 'samples/tcpdump004.txt',
   result => [
      {  ts         => "090412 12:58:02.036002",
         db         => undef,
         user       => undef,
         host       => '127.0.0.1',
         ip         => '127.0.0.1',
         port       => '60439',
         arg        => 'select 5 from foo',
         Query_time => '0.000251',
         Thread_id  => undef,
         pos_in_log => 0,
         bytes      => length('select 5 from foo'),
         cmd        => 'Query',
         Error_no   => "#1046",
         Rows_affected => 0,
         Warning_count      => 0,
         No_good_index_used => 'No',
         No_index_used      => 'No',
      },
   ],
});

# A session that has a single-row insert and a multi-row insert
$protocol = new MySQLProtocolParser();
run_test({
   file   => 'samples/tcpdump005.txt',
   result => [
      {  Error_no   => 'none',
         Rows_affected => 1,
         Query_time => '0.000435',
         Thread_id  => undef,
         arg        => 'insert into test.t values(1)',
         bytes      => 28,
         cmd        => 'Query',
         db         => undef,
         host       => '127.0.0.1',
         ip         => '127.0.0.1',
         port       => '55300',
         pos_in_log => '0',
         ts         => '090412 16:46:02.978340',
         user       => undef,
         Warning_count      => 0,
         No_good_index_used => 'No',
         No_index_used      => 'No',
      },
      {  Error_no   => 'none',
         Rows_affected => 2,
         Query_time => '0.000565',
         Thread_id  => undef,
         arg        => 'insert into test.t values(1),(2)',
         bytes      => 32,
         cmd        => 'Query',
         db         => undef,
         host       => '127.0.0.1',
         ip         => '127.0.0.1',
         port       => '55300',
         pos_in_log => '1033',
         ts         => '090412 16:46:20.245088',
         user       => undef,
         Warning_count      => 0,
         No_good_index_used => 'No',
         No_index_used      => 'No',
      },
   ],
});

# A session that causes a slow query because it doesn't use an index.
$protocol = new MySQLProtocolParser();
run_test({
   file   => 'samples/tcpdump006.txt',
   result => [
      {  ts         => '100412 20:46:10.776899',
         db         => undef,
         user       => undef,
         host       => '127.0.0.1',
         ip         => '127.0.0.1',
         port       => '48259',
         arg        => 'select * from t',
         Query_time => '0.000205',
         Thread_id  => undef,
         pos_in_log => 0,
         bytes      => length('select * from t'),
         cmd        => 'Query',
         Error_no   => 'none',
         Rows_affected      => 0,
         Warning_count      => 0,
         No_good_index_used => 'No',
         No_index_used      => 'Yes',
      },
   ],
});

# A session that truncates an insert.
$protocol = new MySQLProtocolParser();
run_test({
   file   => 'samples/tcpdump007.txt',
   result => [
      {  ts         => '090412 20:57:22.798296',
         db         => undef,
         user       => undef,
         host       => '127.0.0.1',
         ip         => '127.0.0.1',
         port       => '38381',
         arg        => 'insert into t values(current_date)',
         Query_time => '0.000020',
         Thread_id  => undef,
         pos_in_log => 0,
         bytes      => length('insert into t values(current_date)'),
         cmd        => 'Query',
         Error_no   => 'none',
         Rows_affected      => 1,
         Warning_count      => 1,
         No_good_index_used => 'No',
         No_index_used      => 'No',
      },
   ],
});

# #############################################################################
# Check the individual packet parsing subs.
# #############################################################################
MySQLProtocolParser->import(qw(
   parse_error_packet
   parse_ok_packet
   parse_server_handshake_packet
   parse_client_handshake_packet
   parse_com_packet
));
 
is_deeply(
   parse_error_packet(load_data('samples/mysql_proto_001.txt')),
   {
      errno    => '1046',
      sqlstate => '#3D000',
      message  => 'No database selected',
   },
   'Parse error packet'
);

is_deeply(
   parse_ok_packet('010002000100'),
   {
      affected_rows => 1,
      insert_id     => 0,
      status        => 2,
      warnings      => 1,
      message       => '',
   },
   'Parse ok packet'
);

is_deeply(
   parse_server_handshake_packet(load_data('samples/mysql_proto_002.txt')),
   {
      thread_id      => '9',
      server_version => '5.0.67-0ubuntu6-log',
      flags          => {
         CLIENT_COMPRESS          => 1,
         CLIENT_CONNECT_WITH_DB   => 1,
         CLIENT_FOUND_ROWS        => 0,
         CLIENT_IGNORE_SIGPIPE    => 0,
         CLIENT_IGNORE_SPACE      => 0,
         CLIENT_INTERACTIVE       => 0,
         CLIENT_LOCAL_FILES       => 0,
         CLIENT_LONG_FLAG         => 1,
         CLIENT_LONG_PASSWORD     => 0,
         CLIENT_MULTI_RESULTS     => 0,
         CLIENT_MULTI_STATEMENTS  => 0,
         CLIENT_NO_SCHEMA         => 0,
         CLIENT_ODBC              => 0,
         CLIENT_PROTOCOL_41       => 1,
         CLIENT_RESERVED          => 0,
         CLIENT_SECURE_CONNECTION => 1,
         CLIENT_SSL               => 0,
         CLIENT_TRANSACTIONS      => 1,
      }
   },
   'Parse server handshake packet'
);

is_deeply(
   parse_client_handshake_packet(load_data('samples/mysql_proto_003.txt')),
   {
      db    => 'mysql',
      user  => 'msandbox',
      flags => {
         CLIENT_COMPRESS          => 0,
         CLIENT_CONNECT_WITH_DB   => 1,
         CLIENT_FOUND_ROWS        => 0,
         CLIENT_IGNORE_SIGPIPE    => 0,
         CLIENT_IGNORE_SPACE      => 0,
         CLIENT_INTERACTIVE       => 0,
         CLIENT_LOCAL_FILES       => 1,
         CLIENT_LONG_FLAG         => 1,
         CLIENT_LONG_PASSWORD     => 1,
         CLIENT_MULTI_RESULTS     => 1,
         CLIENT_MULTI_STATEMENTS  => 1,
         CLIENT_NO_SCHEMA         => 0,
         CLIENT_ODBC              => 0,
         CLIENT_PROTOCOL_41       => 1,
         CLIENT_RESERVED          => 0,
         CLIENT_SECURE_CONNECTION => 1,
         CLIENT_SSL               => 0,
         CLIENT_TRANSACTIONS      => 1,
      },
   },
   'Parse client handshake packet'
);

is_deeply(
   parse_com_packet('0373686f77207761726e696e67738d2dacbc', 14),
   {
      code => '03',
      com  => 'COM_QUERY',
      data => 'show warnings',
   },
   'Parse COM_QUERY packet'
);

# Test that we can parse with a non-standard port etc.
$protocol = new MySQLProtocolParser(
   server => '192.168.1.1:3307',
);
run_test({
   file   => 'samples/tcpdump012.txt',
   result => [
      {  ts            => '090412 09:50:16.805123',
         db            => undef,
         user          => undef,
         Thread_id     => undef,
         host          => '127.0.0.1',
         ip            => '127.0.0.1',
         port          => '42167',
         arg           => 'select "hello world" as greeting',
         Query_time    => sprintf('%.6f', .805123 - .804849),
         pos_in_log    => 0,
         bytes         => length('select "hello world" as greeting'),
         cmd           => 'Query',
         Error_no      => 'none',
         Rows_affected => 0,
         Warning_count      => 0,
         No_good_index_used => 'No',
         No_index_used      => 'No',
      },
   ],
});

# #############################################################################
# Issue 447: MySQLProtocolParser does not handle old password algo or
# compressed packets  
# #############################################################################
$protocol = new MySQLProtocolParser(
   server => '10.55.200.15:3306',
);
run_test({
   file   => 'samples/tcpdump013.txt',
   desc   => 'old password and compression',
   result => [
      {  Error_no => 'none',
         No_good_index_used => 'No',
         No_index_used => 'No',
         Query_time => '0.034355',
         Rows_affected => 0,
         Thread_id => 36947020,
         Warning_count => 0,
         arg => 'administrator command: Connect',
         bytes => 30,
         cmd => 'Admin',
         db => '',
         host => '10.54.212.171',
         ip => '10.54.212.171',
         port => '49663',
         pos_in_log => 1834,
         ts => '090603 10:52:24.578817',
         user => 'luck'
      },
   ],
});

# Check in-stream compression detection.
$protocol = new MySQLProtocolParser(
   server => '10.55.200.15:3306',
);
run_test({
   file   => 'samples/tcpdump014.txt',
   desc   => 'in-stream compression detection',
   result => [
      {
         Error_no           => 'none',
         No_good_index_used => 'No',
         No_index_used      => 'No',
         Query_time         => '0.001375',
         Rows_affected      => 0,
         Thread_id          => undef,
         Warning_count      => 0,
         arg                => 'show databases',
         bytes              => 14,
         cmd                => 'Query',
         db                 => undef,
         host               => '10.54.212.171',
         ip                 => '10.54.212.171',
         port               => '49663',
         pos_in_log         => 0,
         ts                 => '090603 10:52:24.587685',
         user               => undef,
      },
   ],
});

# Check data decompression.
$protocol = new MySQLProtocolParser(
   server => '127.0.0.1:12345',
);
run_test({
   file   => 'samples/tcpdump015.txt',
   desc   => 'compressed data',
   result => [
      {
         Error_no => 'none',
         No_good_index_used => 'No',
         No_index_used => 'No',
         Query_time => '0.006415',
         Rows_affected => 0,
         Thread_id => 20,
         Warning_count => 0,
         arg => 'administrator command: Connect',
         bytes => 30,
         cmd => 'Admin',
         db => 'mysql',
         host => '127.0.0.1',
         ip => '127.0.0.1',
         port => '44489',
         pos_in_log => 664,
         ts => '090612 08:39:05.316805',
         user => 'msandbox'
      },
      {
         Error_no => 'none',
         No_good_index_used => 'No',
         No_index_used => 'Yes',
         Query_time => '0.002884',
         Rows_affected => 0,
         Thread_id => 20,
         Warning_count => 0,
         arg => 'select * from help_relation',
         bytes => 27,
         cmd => 'Query',
         db => 'mysql',
         host => '127.0.0.1',
         ip => '127.0.0.1',
         port => '44489',
         pos_in_log => 1637,
         ts => '090612 08:39:08.428913',
         user => 'msandbox'
      },
      {
         Error_no => 'none',
         No_good_index_used => 'No',
         No_index_used => 'No',
         Query_time => '0.000000',
         Rows_affected => 0,
         Thread_id => 20,
         Warning_count => 0,
         arg => 'administrator command: Quit',
         bytes => 27,
         cmd => 'Admin',
         db => 'mysql',
         host => '127.0.0.1',
         ip => '127.0.0.1',
         port => '44489',
         pos_in_log => 15782,
         ts => '090612 08:39:09.145334',
         user => 'msandbox'
      },
   ],
});

# TCP retransmission.
# Check data decompression.
$protocol = new MySQLProtocolParser(
   server => '10.55.200.15:3306',
);
run_test({
   file   => 'samples/tcpdump016.txt',
   desc   => 'TCP retransmission',
   result => [
      {
         Error_no => 'none',
         No_good_index_used => 'No',
         No_index_used => 'No',
         Query_time => '0.001000',
         Rows_affected => 0,
         Thread_id => 38559282,
         Warning_count => 0,
         arg => 'administrator command: Connect',
         bytes => 30,
         cmd => 'Admin',
         db => '',
         host => '10.55.200.31',
         ip => '10.55.200.31',
         port => '64987',
         pos_in_log => 468,
         ts => '090609 16:53:17.112346',
         user => 'ppppadri'
      },
   ],
});

# TODO: this is not easy to test.
# Check that we don't die on false-positive FF error packets.
# This can happen often if we catch a big server response mid-stream.
# We need to ignore everything and just wait until the client
# sends a command.
# $protocol = new MySQLProtocolParser(
#   server => '10.55.200.15:3306',
#);
#run_test({
#   file   => 'samples/tcpdump018.txt',
#   desc   => 'False-positive FF error packet',
#   result => [
#   ],
#});

# #############################################################################
# Done.
# #############################################################################
exit;
