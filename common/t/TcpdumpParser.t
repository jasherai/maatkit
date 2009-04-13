#!/usr/bin/perl

use strict;
use warnings FATAL => 'all';

use Test::More tests => 15;
use English qw(-no_match_vars);
use Data::Dumper;
$Data::Dumper::Quotekeys = 0;
$Data::Dumper::Sortkeys  = 1;
$Data::Dumper::Indent    = 1;

require "../TcpdumpParser.pm";

my $p = new TcpdumpParser;

# First, parse the TCP and IP packet...
my $contents = <<EOF;
2009-04-12 21:18:40.638244 IP 192.168.28.223.56462 > 192.168.28.213.mysql: tcp 301
\t0x0000:  4508 0161 7dc5 4000 4006 00c5 c0a8 1cdf
\t0x0010:  c0a8 1cd5 dc8e 0cea adc4 5111 ad6f 995e
\t0x0020:  8018 005b 0987 0000 0101 080a 62e6 32e7
\t0x0030:  62e4 a103 2901 0000 0353 454c 4543 5420
\t0x0040:  6469 7374 696e 6374 2074 702e 6964 2c20
\t0x0050:  7470 2e70 726f 6475 6374 5f69 6d61 6765
\t0x0060:  5f6c 696e 6b20 6173 2069 6d67 2c20 7470
\t0x0070:  2e69 6e6e 6572 5f76 6572 7365 3220 6173
\t0x0080:  2074 6974 6c65 2c20 7470 2e70 7269 6365
\t0x0090:  2046 524f 4d20 7470 726f 6475 6374 7320
\t0x00a0:  7470 2c20 6667 6966 745f 6c69 6e6b 2065
\t0x00b0:  2057 4845 5245 2074 702e 7072 6f64 7563
\t0x00c0:  745f 6465 7363 203d 2027 6667 6966 7427
\t0x00d0:  2041 4e44 2074 702e 6964 3d65 2e70 726f
\t0x00e0:  6475 6374 5f69 6420 2061 6e64 2074 702e
\t0x00f0:  7072 6f64 7563 745f 7374 6174 7573 3d35
\t0x0100:  2041 4e44 2065 2e63 6174 5f69 6420 696e
\t0x0110:  2028 322c 3131 2c2d 3129 2041 4e44 2074
\t0x0120:  702e 696e 7369 6465 5f69 6d61 6765 203d
\t0x0130:  2027 456e 676c 6973 6827 2020 4f52 4445
\t0x0140:  5220 4259 2074 702e 7072 696e 7461 626c
\t0x0150:  6520 6465 7363 204c 494d 4954 2030 2c20
\t0x0160:  38
EOF

is_deeply(
   $p->parse_packet($contents),
   {  ts   => '2009-04-12 21:18:40.638244',
      from => '192.168.28.223.56462',
      to   => '192.168.28.213.mysql',
      complete => 1,
      data => join('', qw(
         2901 0000 0353 454c 4543 5420
         6469 7374 696e 6374 2074 702e 6964 2c20
         7470 2e70 726f 6475 6374 5f69 6d61 6765
         5f6c 696e 6b20 6173 2069 6d67 2c20 7470
         2e69 6e6e 6572 5f76 6572 7365 3220 6173
         2074 6974 6c65 2c20 7470 2e70 7269 6365
         2046 524f 4d20 7470 726f 6475 6374 7320
         7470 2c20 6667 6966 745f 6c69 6e6b 2065
         2057 4845 5245 2074 702e 7072 6f64 7563
         745f 6465 7363 203d 2027 6667 6966 7427
         2041 4e44 2074 702e 6964 3d65 2e70 726f
         6475 6374 5f69 6420 2061 6e64 2074 702e
         7072 6f64 7563 745f 7374 6174 7573 3d35
         2041 4e44 2065 2e63 6174 5f69 6420 696e
         2028 322c 3131 2c2d 3129 2041 4e44 2074
         702e 696e 7369 6465 5f69 6d61 6765 203d
         2027 456e 676c 6973 6827 2020 4f52 4445
         5220 4259 2074 702e 7072 696e 7461 626c
         6520 6465 7363 204c 494d 4954 2030 2c20
         38)),
   },
   'Parsed packet OK');

sub run_test {
   my ( $def ) = @_;
   map     { die "What is $_ for?" }
      grep { $_ !~ m/^(?:misc|file|result|num_events)$/ }
      keys %$def;
   my @e;
   my $num_events = 0;
   my $p = new TcpdumpParser;
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
   file   => 'samples/tcpdump001.txt',
   misc   => { watching => '127.0.0.1.3306' },
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
   misc   => { watching => '127.0.0.1.3306' },
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
         pos_in_log => 0,
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
         pos_in_log => 2427,
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
         pos_in_log => 3270,
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
         pos_in_log => '4152',
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
   misc   => { watching => '127.0.0.1.3306' },
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
         pos_in_log => 0,
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
   misc   => { watching => '127.0.0.1.3306' },
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
   misc   => { watching => '127.0.0.1.3306' },
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
         pos_in_log => '1035',
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
   misc   => { watching => '127.0.0.1.3306' },
   result => [
      {  ts         => '090412 20:46:10.776899',
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
   misc   => { watching => '127.0.0.1.3306' },
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
