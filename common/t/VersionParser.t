#!/usr/bin/perl

use strict;
use warnings FATAL => 'all';

use Test::More tests => 2;
use DBI;
use English qw(-no_match_vars);

require "../VersionParser.pm";

my $p = new VersionParser;

is(
   $p->parse('5.0.38-Ubuntu_0ubuntu1.1-log'),
   '005000038',
   'Parser works on ordinary version',
);

# Open a connection to MySQL, or skip the rest of the tests.
my $dbh;
eval {
   $dbh = DBI->connect(
   "DBI:mysql:;mysql_read_default_group=mysql", undef, undef, { RaiseError => 1 })
};
SKIP: {
   skip $EVAL_ERROR, 1 if $EVAL_ERROR;
   ok($p->version_ge($dbh, '3.23.00'), 'Version is > 3.23');
}
