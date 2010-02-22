#!/usr/bin/perl

BEGIN {
   die "The MAATKIT_TRUNK environment variable is not set.  See http://code.google.com/p/maatkit/wiki/Testing"
      unless $ENV{MAATKIT_TRUNK} && -d $ENV{MAATKIT_TRUNK};
   unshift @INC, "$ENV{MAATKIT_TRUNK}/common";
};

use strict;
use warnings FATAL => 'all';
use English qw(-no_match_vars);
use Test::More tests => 2;

use MaatkitTest;
use PodParser;

my $p = new PodParser();

my $trf = sub {
   my ( $para ) = @_;
   return unless $para =~ m/^id:/;
   my $check = {};
   my @lines = split("\n", $para);
   for ( 0..2 ) {
      my $line = shift @lines;
      $line =~ m/(\w+):\s*(.+)/;
      $check->{$1} = $2;
   }
   my $line = shift @lines;
   $line =~ m/(\w+):\s*(.+)/;
   my $desc = $1;
   $check->{$1} = $2;
   while ( my $d = shift @lines ) {
      $check->{$desc} .= $d;
   }
   $check->{$desc} =~ s/\s+/ /g;
   return $check;
};

my @checks = $p->parse_section(
   file        => "$trunk/common/t/samples/pod/pod_sample_mqa.txt",
   section     => 'CHECKS',
   subsection  => undef,
   trf         => $trf
);

is_deeply(
   \@checks,
   [
      {
         desc => 'IP address used as string. The string literal looks like an IP address but is not used inside INET_ATON(). WHERE ip=\'127.0.0.1\' is better as ip=INET_ATON(\'127.0.0.1\') if the column is numeric.',
         id => 'LIT.001',
         level => 'note',
         rule => 'colval matches \\d{1,3}\\.\\d{1,3}\\.\\d{1,3}\\.\\d{1,3}\\.'
      },
      {
         desc => 'Date literal is not quoted. WHERE col<2010-02-12 is valid but wrong; the date should be quoted.',
         id => 'LIT.002',
         level => 'warn',
         rule => 'colval matches (?:\\d{2,4}-\\d{1,2}-\\d{1,2}|\\d{4,6})'
      },
      {
         desc => 'SELECT *. Selecting specific columns is preferable to SELECT *.',
         id => 'TBL.001',
         level => 'note',
         rule => 'tbl matches *'
      },
      {
         desc => 'ORDER BY RAND(). ORDER BY RAND() is not preferred.',
         id => 'CLA.001',
         level => 'note',
         rule => 'query matches ORDER BY RAND'
      },
      {
         desc => 'Blind INSERT. The INSERT does not specify columns. INSERT INTO tbl (col1,col2) VALUES (1,2) is preferred to INSERT INTO tbl VALUES (1,2).',
         id => 'QRY.001',
         level => 'note',
         rule => 'INSERT without columns'
      },
      {
         desc => 'SQL_CALC_FOUND_ROWS does not scale. SQL_CALC_FOUND_ROWS can cause performance problems because it does not scale well.',
         id => 'QRY.002',
         level => 'note',
         rule => 'query matches SQL_CALC_FOUND_ROWS'
      },
   ],
   'parse_section'
);

@checks = $p->parse_section(
   file        => "$trunk/common/t/samples/pod/pod_sample_mqa.txt",
   section     => 'CHECKS',
   subsection  => 'Literals',
   trf         => $trf
);

is_deeply(
   \@checks,
   [
      {
         desc => 'IP address used as string. The string literal looks like an IP address but is not used inside INET_ATON(). WHERE ip=\'127.0.0.1\' is better as ip=INET_ATON(\'127.0.0.1\') if the column is numeric.',
         id => 'LIT.001',
         level => 'note',
         rule => 'colval matches \\d{1,3}\\.\\d{1,3}\\.\\d{1,3}\\.\\d{1,3}\\.'
      },
      {
         desc => 'Date literal is not quoted. WHERE col<2010-02-12 is valid but wrong; the date should be quoted.',
         id => 'LIT.002',
         level => 'warn',
         rule => 'colval matches (?:\\d{2,4}-\\d{1,2}-\\d{1,2}|\\d{4,6})'
      },
   ],
   'parse_section with subsection'
);

# #############################################################################
# Done.
# #############################################################################
exit;
