#!/usr/bin/perl

use strict;
use warnings FATAL => 'all';

use Test::More tests => 14;
use English qw(-no_match_vars);
use Data::Dumper;
$Data::Dumper::Quotekeys = 0;
$Data::Dumper::Sortkeys  = 1;
$Data::Dumper::Indent    = 1;

require "../MySQLProtocolParser.pm";
require "../TcpdumpParser.pm";

my $tcpdump  = new TcpdumpParser();
my $protocol = new MySQLProtocolParser(
   server => '127.0.0.1:3306',
);

sub run_test {
   my ( $def ) = @_;
   map     { die "What is $_ for?" }
      grep { $_ !~ m/^(?:misc|file|result|num_events)$/ }
      keys %$def;
   my @e;
   my $num_events = 0;
   my $callback   = sub {
      my ( $packet ) = @_;
      $protocol->parse_packet($packet, undef, sub { push @e, @_; });
      return $packet;
   };
   eval {
      open my $fh, "<", $def->{file}
         or BAIL_OUT("Cannot open $def->{file}: $OS_ERROR");
      $num_events++ while $tcpdump->parse_packet($fh, undef, $callback);
      close $fh;
   };
   is($EVAL_ERROR, '', "No error on $def->{file}");
   if ( defined $def->{result} ) {
      is_deeply(
         \@e,
         $def->{result},
         $def->{file}
      ) or print "Got: ", Dumper(\@e);
   }
   if ( defined $def->{num_events} ) {
      is($num_events, $def->{num_events}, "$def->{file} num_events");
   }
   return;
}

# Check that I can parse a really simple session.
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
         Error_no      => 0,
         Rows_affected => 0,
         Warning_count      => 0,
         No_good_index_used => 'No',
         No_index_used      => 'No',
      },
   ],
});

# A more complex session with a complete login/logout cycle.
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
         pos_in_log => 1455,
         bytes      => length('administrator command: Connect'),
         cmd        => 'Admin',
         Error_no   => 0,
         Rows_affected => 0,
         Warning_count      => 0,
         No_good_index_used => 'No',
         No_index_used      => 'No',
      },
      {  Query_time => '0.000265',
         Thread_id  => 8,
         arg        => 'select @@version_comment limit 1',
         bytes      => 32,
         cmd        => 'Query',
         db         => 'mysql',
         host       => '127.0.0.1',
         ip         => '127.0.0.1',
         port       => '57890',
         pos_in_log => 2425,
         ts         => '090412 11:00:13.118643',
         user       => 'msandbox',
         Error_no   => 0,
         Rows_affected => 0,
         Warning_count      => 0,
         No_good_index_used => 'No',
         No_index_used      => 'No',
      },
      {  Query_time => '0.000167',
         Thread_id  => 8,
         arg        => 'select "paris in the the spring" as trick',
         bytes      => 41,
         cmd        => 'Query',
         db         => 'mysql',
         host       => '127.0.0.1',
         ip         => '127.0.0.1',
         port       => '57890',
         pos_in_log => 3268,
         ts         => '090412 11:00:13.119079',
         user       => 'msandbox',
         Error_no   => 0,
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
         pos_in_log => '4150',
         ts         => '090412 11:00:13.119487',
         user       => 'msandbox',
         Error_no   => 0,
         Rows_affected => 0,
         Warning_count      => 0,
         No_good_index_used => 'No',
         No_index_used      => 'No',
      },
   ],
});

# A session that has an error during login.
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
         Error_no   => 1045,
         Rows_affected => 0,
         Warning_count      => 0,
         No_good_index_used => 'No',
         No_index_used      => 'No',
      },
   ],
});

# A session that has an error executing a query
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
         Error_no   => 1046,
         Rows_affected => 0,
         Warning_count      => 0,
         No_good_index_used => 'No',
         No_index_used      => 'No',
      },
   ],
});

# A session that has a single-row insert and a multi-row insert
run_test({
   file   => 'samples/tcpdump005.txt',
   result => [
      {  Error_no   => 0,
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
      {  Error_no   => 0,
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
         Error_no   => 0,
         Rows_affected      => 0,
         Warning_count      => 0,
         No_good_index_used => 'No',
         No_index_used      => 'Yes',
      },
   ],
});

# A session that truncates an insert.
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
         Error_no   => 0,
         Rows_affected      => 1,
         Warning_count      => 1,
         No_good_index_used => 'No',
         No_index_used      => 'No',
      },
   ],
});

# #############################################################################
# Done.
# #############################################################################
exit;
