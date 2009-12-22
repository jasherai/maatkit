#!/usr/bin/perl

use strict;
use warnings FATAL => 'all';
use English qw(-no_match_vars);
use Test::More tests => 3;

use Data::Dumper;
$Data::Dumper::Indent    = 1;
$Data::Dumper::Sortkeys  = 1;
$Data::Dumper::Quotekeys = 0;

require "../GeneralLogParser.pm";
require "../MaatkitTest.pm";

MaatkitTest->import(qw(test_log_parser));

my $p = new GeneralLogParser();

my $oktorun = 1;

test_log_parser(
   parser  => $p,
   file    => 'samples/genlog001.txt',
   oktorun => sub { $oktorun = $_[0]; },
   result  => [
      {  ts         => '051007 21:55:24',
         Thread_id  => '42',
         arg        => 'administrator command: Connect',
         bytes      => 30,
         cmd        => 'Admin',
         db         => 'db1',
         host       => 'localhost',
         pos_in_log => 0,
         user       => 'root',
         Query_time => 0,
      },
      {  ts         => undef,
         Thread_id  => '42',
         arg        => 'SELECT foo 
                         FROM tbl
                         WHERE col=12345
                         ORDER BY col',
         bytes      => 124,
         cmd        => 'Query',
         pos_in_log => 58,
         Query_time => 0,
         db         => 'db1',
      },
      {  ts         => undef,
         Thread_id  => '42',
         arg        => 'administrator command: Quit',
         bytes      => 27,
         cmd        => 'Admin',
         pos_in_log => 244,
         Query_time => 0,
      },
      {  ts         => '061226 15:42:36',
         Thread_id  => '11',
         arg        => 'administrator command: Connect',
         bytes      => 30,
         cmd        => 'Admin',
         host       => 'localhost',
         pos_in_log => 244,
         user       => 'root',
         Query_time => 0,
      },
      {  ts         => undef,
         Thread_id  => '11',
         arg        => 'administrator command: Init DB',
         bytes      => 30,
         cmd        => 'Admin',
         db         => 'my_webstats',
         pos_in_log => 300,
         Query_time => 0,
      },
      {  ts         => undef,
         Thread_id  => '11',
         arg        => 'SELECT DISTINCT col FROM tbl WHERE foo=20061219',
         bytes      => 47,
         cmd        => 'Query',
         pos_in_log => 346,
         Query_time => 0,
         db         => 'my_webstats',
      },
      {  ts         => '061226 16:44:48',
         Thread_id  => '11',
         arg        => 'administrator command: Quit',
         bytes      => 27,
         cmd        => 'Admin',
         pos_in_log => 464,
         Query_time => 0,
      },
   ]
);

is(
   $oktorun,
   0,
   'Sets oktorun'
);

# #############################################################################
# Done.
# #############################################################################
exit;
