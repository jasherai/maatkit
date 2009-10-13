#!/usr/bin/perl

use strict;
use warnings FATAL => 'all';
use English qw(-no_match_vars);
use Test::More tests => 1;

use List::Util qw(max);

require "../SchemaIterator.pm";
require "../Quoter.pm";
require "../DSNParser.pm";
require "../Sandbox.pm";

my $q   = new Quoter();
my $dp  = new DSNParser();
my $sb  = new Sandbox(basedir => '/tmp', DSNParser => $dp);
my $dbh = $sb->get_dbh_for('master')
   or BAIL_OUT('Cannot connect to sandbox master');

$sb->load_file('master', 'samples/SchemaIterator.sql');

my $si = new SchemaIterator(
   Quoter => $q,
);
isa_ok($si, 'SchemaIterator');

# #############################################################################
# Done.
# #############################################################################
$sb->wipe_clean($dbh);
exit;
