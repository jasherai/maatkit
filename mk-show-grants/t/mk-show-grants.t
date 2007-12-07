#!/usr/bin/perl

use strict;
use warnings FATAL => 'all';

use English qw('no_match_vars);
use Test::More tests => 5;

my $output = `perl ../mk-show-grants -d -f -r -s`;

like(
   $output,
   qr/Grants dumped by/,
   'It lives',
);

like(
   $output,
   qr/REVOKE/,
   'It converted to revokes',
);

like(
   $output,
   qr/FLUSH/,
   'added FLUSH/',
);

like(
   $output,
   qr/DROP/,
   'Added DROP',
);

like(
   $output,
   qr/DELETE/,
   'Added DELETE for older MySQL versions',
);
