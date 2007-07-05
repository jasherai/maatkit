#!/usr/bin/perl

use strict;
use warnings FATAL => 'all';

use English qw(-no_match_vars);
use Data::Dumper;
use File::Basename;
use Pod::Html;

# Find list of packages
my $base     = '../../tags';
my @packages = map { basename $_ } (split(/\s+/, `ls -d $base/mysql-*`));

# Find latest of each package
foreach my $p ( @packages ) {
   my @vers = map { basename $_ } (split(/\s+/, `ls -d $base/$p/mysql-*`));
   @vers = reverse sort { x($a) cmp x($b) } @vers;
   my $rev = $vers[0];
   print `./make-individual-package $p $rev`;
}

sub x {
   my ($name) = @_;
   sprintf('%03d%03d%03d', $name =~ m/(\d+)/g);
}
