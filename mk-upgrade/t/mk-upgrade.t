#!/usr/bin/perl

use strict;
use warnings FATAL => 'all';
use English qw(-no_match_vars);
use Test::More tests => 1;

#require '../../common/DSNParser.pm';
#require '../../common/Sandbox.pm';
#my $dp = new DSNParser();
#my $sb = new Sandbox(basedir => '/tmp', DSNParser => $dp);

my $output = `../mk-upgrade --help`;
like(
   $output,
   qr/--ask-pass/,
   'It runs'
);

# #############################################################################
# Done.
# #############################################################################
exit;
