#!/usr/bin/env perl

BEGIN {
   die "The MAATKIT_TRUNK environment variable is not set.  See http://code.google.com/p/maatkit/wiki/Testing"
      unless $ENV{MAATKIT_TRUNK} && -d $ENV{MAATKIT_TRUNK};
   unshift @INC, "$ENV{MAATKIT_TRUNK}/common";
};

use strict;
use warnings FATAL => 'all';
use English qw(-no_match_vars);
use Test::More tests => 1;

use MaatkitTest;
require "$trunk/mk-query-advisor/mk-query-advisor";

my $para;
my $check;

$para  = "id: FOO.001
level: warn
rules: query matches ^select
desc: I'm a check.  This is my description.
";
$check = mk_query_advisor::parse_check($para);
is_deeply(
   $check,
   {
      id    => 'FOO.001',
      level => 'warn',
      desc  => "I'm a check. This is my description.",
      rules => [
         {
            pattern        => qr/^select/,
            positive_match => 1,
            obj            => 'query',
         },
      ]
   },
   'Basic check'
);

# #############################################################################
# Done.
# #############################################################################
exit;
