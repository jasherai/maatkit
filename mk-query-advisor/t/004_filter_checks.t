#!/usr/bin/env perl

BEGIN {
   die "The MAATKIT_TRUNK environment variable is not set.  See http://code.google.com/p/maatkit/wiki/Testing"
      unless $ENV{MAATKIT_TRUNK} && -d $ENV{MAATKIT_TRUNK};
   unshift @INC, "$ENV{MAATKIT_TRUNK}/common";
};

use strict;
use warnings FATAL => 'all';
use English qw(-no_match_vars);
use Test::More tests => 5;

use MaatkitTest;
require "$trunk/mk-query-advisor/mk-query-advisor";

my $para;
my $check;
my $ignore;

$para  = "id: FOO.001
level: warn
rules: query matches ^select
desc: I'm a check.  This is my description.
";
$check  = mk_query_advisor::parse_check($para);

is_deeply(
   mk_query_advisor::filter_checks($check, undef),
   $check,
   'Check passes when none ignored'
);

$ignore = { 'BAR.002' => 1 };
is_deeply(
   mk_query_advisor::filter_checks($check, $ignore),
   $check,
   'Check ID passes'
);

$ignore = { 'FOO.001' => 1 };
is(
   mk_query_advisor::filter_checks($check, $ignore),
   undef,
   'Check ID filtered'
);

$ignore = { 'crit' => 1 };
is(
   mk_query_advisor::filter_checks($check, $ignore),
   $check,
   'Check level passes'
);

$ignore = { 'warn' => 1 };
is(
   mk_query_advisor::filter_checks($check, $ignore),
   undef,
   'Check level filtered'
);
# #############################################################################
# Done.
# #############################################################################
exit;
