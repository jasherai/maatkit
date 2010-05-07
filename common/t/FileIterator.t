#!/usr/bin/perl

BEGIN {
   die "The MAATKIT_TRUNK environment variable is not set.  See http://code.google.com/p/maatkit/wiki/Testing"
      unless $ENV{MAATKIT_TRUNK} && -d $ENV{MAATKIT_TRUNK};
   unshift @INC, "$ENV{MAATKIT_TRUNK}/common";
};

use strict;
use warnings FATAL => 'all';
use English qw(-no_match_vars);
use Test::More tests => 11;

use FileIterator;
use MaatkitTest;

use constant MKDEBUG => $ENV{MKDEBUG} || 0;

use Data::Dumper;
$Data::Dumper::Indent    = 1;
$Data::Dumper::Sortkeys  = 1;
$Data::Dumper::Quotekeys = 0;

my ($next_fh, $fh, $name, $size);
my $fi = new FileIterator();
isa_ok($fi, 'FileIterator');

# #############################################################################
# Empty list of filenames.
# #############################################################################
$next_fh = $fi->get_file_itr(qw());
is( ref $next_fh, 'CODE', 'get_file_itr() returns a subref' );
( $fh, $name, $size ) = $next_fh->();
is( "$fh", '*main::STDIN', 'Got STDIN for empty list' );
is( $name, undef, 'STDIN has no name' );
is( $size, undef, 'STDIN has no size' );

# #############################################################################
# Magical '-' filename.
# #############################################################################
$next_fh = $fi->get_file_itr(qw(-));
( $fh, $name, $size ) = $next_fh->();
is( "$fh", '*main::STDIN', 'Got STDIN for "-"' );

# #############################################################################
# Real filenames.
# #############################################################################
$next_fh = $fi->get_file_itr(qw(samples/memc_tcpdump009.txt samples/empty));
( $fh, $name, $size ) = $next_fh->();
is( ref $fh, 'GLOB', 'Open filehandle' );
is( $name, 'samples/memc_tcpdump009.txt', "Got filename for $name");
is( $size, 587, "Got size for $name");
( $fh, $name, $size ) = $next_fh->();
is( $name, 'samples/empty', "Got filename for $name");
is( $size, 0, "Got size for $name");

# #############################################################################
# Done.
# #############################################################################
exit;
