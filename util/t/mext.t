#!/usr/bin/perl

use strict;
use warnings FATAL => 'all';
use English qw(-no_match_vars);
use Test::More tests => 2;
require "../../common/MaatkitTest.pm";
MaatkitTest->import(qw(no_diff));

use Data::Dumper;
$Data::Dumper::Indent    = 1;
$Data::Dumper::Sortkeys  = 1;
$Data::Dumper::Quotekeys = 0;

sub test {
   my ( $command, $result_file, $test_name ) = @_;
   my $ok = no_diff($command, $result_file);
   ok($ok, $test_name);
}

# #############################################################################
# Begin.
# #############################################################################

test('../mext -- cat samples/mext-001.txt',
   'samples/mext-001-result.txt', 'Basic output');

test('../mext -r -- cat samples/mext-002.txt',
   'samples/mext-002-result.txt', 'Basic output');

test('../mext2 -- cat samples/mext-001.txt',
   'samples/mext-001-result.txt', 'Basic output');

test('../mext2 -r -- cat samples/mext-002.txt',
   'samples/mext-002-result.txt', 'Basic output');

# #############################################################################
# Done.
# #############################################################################
exit;
