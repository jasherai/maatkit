#!/usr/bin/perl

BEGIN {
   die "The MAATKIT_TRUNK environment variable is not set.  See http://code.google.com/p/maatkit/wiki/Testing"
      unless $ENV{MAATKIT_TRUNK} && -d $ENV{MAATKIT_TRUNK};
   unshift @INC, "$ENV{MAATKIT_TRUNK}/common";
};

use strict;
use warnings FATAL => 'all';

use Test::More tests => 7;
use English qw(-no_match_vars);

use MaatkitTest;
use SQLParser;

my $sp = new SQLParser();

my @cases = (

   # ########################################################################
   # DELETE
   # ########################################################################
   {  name   => 'DELETE FROM',
      query  => 'DELETE FROM tbl',
      struct => {
         type    => 'delete',
         clauses => { from => 'tbl', },
         from    => [ { name => 'tbl', } ],
         unknown => '',
      },
   },
   {  name   => 'DELETE FROM WHERE',
      query  => 'DELETE FROM tbl WHERE id=1',
      struct => {
         type    => 'delete',
         clauses => { 
            from  => 'tbl',
            where => 'id=1',
         },
         from    => [ { name => 'tbl', } ],
         where   => 'id=1',
         unknown => '',
      },
   },
   {  name   => 'DELETE FROM LIMIT',
      query  => 'DELETE FROM tbl LIMIT 5',
      struct => {
         type    => 'delete',
         clauses => {
            from  => 'tbl',
            limit => '5',
         },
         from    => [ { name => 'tbl', } ],
         limit   => {
            row_count => 5,
         },
         unknown => '',
      },
   },
   {  name   => 'DELETE FROM ORDER BY',
      query  => 'DELETE FROM tbl ORDER BY foo',
      struct => {
         type    => 'delete',
         clauses => {
            from  => 'tbl',
            order => 'BY foo',
         },
         from    => [ { name => 'tbl', } ],
         order   => [qw(foo)],
         unknown => '',
      },
   },
   {  name   => 'DELETE FROM WHERE LIMIT',
      query  => 'DELETE FROM tbl WHERE id=1 LIMIT 3',
      struct => {
         type    => 'delete',
         clauses => { 
            from  => 'tbl',
            where => 'id=1',
            limit => '3',
         },
         from    => [ { name => 'tbl', } ],
         where   => 'id=1',
         limit   => {
            row_count => 3,
         },
         unknown => '',
      },
   },
   {  name   => 'DELETE FROM WHERE ORDER BY',
      query  => 'DELETE FROM tbl WHERE id=1 ORDER BY id',
      struct => {
         type    => 'delete',
         clauses => { 
            from  => 'tbl',
            where => 'id=1',
            order => 'BY id',
         },
         from    => [ { name => 'tbl', } ],
         where   => 'id=1',
         order   => [qw(id)],
         unknown => '',
      },
   },
   {  name   => 'DELETE FROM WHERE ORDER BY LIMIT',
      query  => 'DELETE FROM tbl WHERE id=1 ORDER BY id LIMIT 1',
      struct => {
         type    => 'delete',
         clauses => { 
            from  => 'tbl',
            where => 'id=1',
            order => 'BY id',
            limit => '1',
         },
         from    => [ { name => 'tbl', } ],
         where   => 'id=1',
         order   => [qw(id)],
         limit   => {
            row_count => 1,
         },
         unknown => '',
      },
   },

   # ########################################################################
   # INSERT
   # ########################################################################

   # ########################################################################
   # REPLACE
   # ########################################################################

   # ########################################################################
   # SELECT
   # ########################################################################
   
   # ########################################################################
   # TRUNCATE
   # ########################################################################

   # ########################################################################
   # UPDATE
   # ########################################################################
);

foreach my $test ( @cases ) {
   my $struct = $sp->parse($test->{query});
   is_deeply(
      $struct,
      $test->{struct},
      $test->{name},
   );
}

# #############################################################################
# Done.
# #############################################################################
exit;
