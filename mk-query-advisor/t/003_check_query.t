#!/usr/bin/env perl

BEGIN {
   die "The MAATKIT_TRUNK environment variable is not set.  See http://code.google.com/p/maatkit/wiki/Testing"
      unless $ENV{MAATKIT_TRUNK} && -d $ENV{MAATKIT_TRUNK};
   unshift @INC, "$ENV{MAATKIT_TRUNK}/common";
};

use strict;
use warnings FATAL => 'all';
use English qw(-no_match_vars);
use Test::More tests => 10;

use MaatkitTest;
require "$trunk/mk-query-advisor/mk-query-advisor";

my $qs;
my $checks;
my $flags;

$qs = {
   query => [ 'DELETE FROM tbl WHERE 1', ],
   table => [ 'tbl', ],
};
$checks = [
   {
      id    => 'FOO.001',
      level => 'warn',
      rules => undef,  # reset before each call to check_query()
   },
];

# ###########################################################################
# Single rule, same subject (query).
# ###########################################################################
$checks->[0]->{rules} = mk_query_advisor::parse_check_rules(
   'query matches ^DELETE',
);
$flags = mk_query_advisor::check_query(
   query_struct => $qs,
   checks       => $checks,
);
is_deeply(
   $flags,
   $checks,
   'Positive query match, flagged'
);

$checks->[0]->{rules} = mk_query_advisor::parse_check_rules(
   'query matches ^SELECT',
);
$flags = mk_query_advisor::check_query(
   query_struct => $qs,
   checks       => $checks,
);
is_deeply(
   $flags,
   [],
   'Positive query match, not flagged'
);

$checks->[0]->{rules} = mk_query_advisor::parse_check_rules(
   'query does not match ^SELECT',
);
$flags = mk_query_advisor::check_query(
   query_struct => $qs,
   checks       => $checks,
);
is_deeply(
   $flags,
   $checks,
   'Negative query match, flagged'
);

$checks->[0]->{rules} = mk_query_advisor::parse_check_rules(
   'query does not match ^DELETE',
);
$flags = mk_query_advisor::check_query(
   query_struct => $qs,
   checks       => $checks,
);
is_deeply(
   $flags,
   [],
   'Negative query match, not flagged',
);


# #############################################################################
# Two rules, same subject (query).
# #############################################################################
$checks->[0]->{rules} = mk_query_advisor::parse_check_rules(
   'query matches ^DELETE',
   'query does not match LIMIT \d+$'
);
$flags = mk_query_advisor::check_query(
   query_struct => $qs,
   checks       => $checks,
);
is_deeply(
   $flags,
   $checks,
   'Positive and negative query matches, flagged'
);

$checks->[0]->{rules} = mk_query_advisor::parse_check_rules(
   'query matches ^DELETE',
   'query does not match WHERE'
);
$flags = mk_query_advisor::check_query(
   query_struct => $qs,
   checks       => $checks,
);
is_deeply(
   $flags,
   [],
   'Positive and negative query matches, not flagged'
);


# #############################################################################
# Match tables.
# #############################################################################
$checks->[0]->{rules} = mk_query_advisor::parse_check_rules(
   'table matches (?:\w+\.)?tbl'
);
$flags = mk_query_advisor::check_query(
   query_struct => $qs,
   checks       => $checks,
);
is_deeply(
   $flags,
   $checks,
   'Positive table match, flagged'
);

$checks->[0]->{rules} = mk_query_advisor::parse_check_rules(
   'table matches (?:\w+\.)?foo'
);
$flags = mk_query_advisor::check_query(
   query_struct => $qs,
   checks       => $checks,
);
is_deeply(
   $flags,
   [],
   'Positive table match, not flagged'
);

# #############################################################################
# Match two subjects: query and table.
# #############################################################################
$checks->[0]->{rules} = mk_query_advisor::parse_check_rules(
   'query matches DELETE',
   'table matches tbl'
);
$flags = mk_query_advisor::check_query(
   query_struct => $qs,
   checks       => $checks,
);
is_deeply(
   $flags,
   $checks,
   'Positive query and table match both ok, flagged'
);

$checks->[0]->{rules} = mk_query_advisor::parse_check_rules(
   'query matches DELETE',
   'table matches foo'
);
$flags = mk_query_advisor::check_query(
   query_struct => $qs,
   checks       => $checks,
);
is_deeply(
   $flags,
   [],
   'Positive query match ok, positive table match not ok, not flagged'
);

# #############################################################################
# Done.
# #############################################################################
exit;
