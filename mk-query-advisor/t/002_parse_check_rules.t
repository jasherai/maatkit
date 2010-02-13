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

my $rules;

$rules = mk_query_advisor::parse_check_rules(
   'query matches ^foo',
   'query does not match bar$'
);
is_deeply(
   $rules,
   [
      { obj=>'query', positive_match=>1, pattern=>qr/^foo/, },
      { obj=>'query', positive_match=>0, pattern=>qr/bar$/, },
   ],
   'Basic query matches'
);

# #############################################################################
# Done.
# #############################################################################
exit;
