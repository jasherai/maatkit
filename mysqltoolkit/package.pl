#!/usr/bin/perl

use strict;
use warnings FATAL => 'all';

use Data::Dumper;
use File::Basename;

# Find list of packages
my $base     = '../../tags';
my @packages = map { basename $_ } (split(/\s+/, `ls -d $base/mysql-*`));
my %versions;

# Find latest of each package
foreach my $p ( @packages ) {
   my @vers = map { basename $_ } (split(/\s+/, `ls -d $base/$p/mysql-*`));
   @vers = reverse sort { x($a) cmp x($b) } @vers;
   $versions{$p} = $vers[0];
}

# Commit the list of files and get the resulting version number.
print `svn up packlist`;
open my $packlist, "> packlist" or die $!;
print $packlist '   $Revision$', "\n", map { "   $_\n" } sort values %versions;
close $packlist;
print `svn ci -m 'Bump version' packlist`;
`rm packlist`; `svn revert packlist`; # Just in case there were no changes
my $rev = `head -n 1 packlist | awk '{print \$2}'` + 0;

# make the dist directory
my $dist = "mysqltoolkit-$rev";
`find -type d -name 'mysqltoolkit-*' | xargs rm -rf`;
`mkdir -p $dist/bin $dist/lib`;

# Write mysqltoolkit.pod
# TODO: include the NAME section from each one's POD between the 'mid' and
# 'tail' files
print `cat mysqltoolkit.head.pod packlist mysqltoolkit.mid.pod mysqltoolkit.tail.pod > $dist/lib/mysqltoolkit.pm`;

# Copy the executables and their READMEs into the $dist dir, and set the
# $VERSION variable correctly
foreach my $p ( keys %versions ) {
   my ($version) = $versions{$p} =~ m/([\d.]+)/;
   print `for a in $base/$p/$versions{$p}/mysql-*; do b=\`basename \$a\`; cp \$a $dist/bin; sed -i -e 's/\@VERSION\@/$version/' $dist/bin/\$b; done`;
   `cp $base/$p/$versions{$p}/README $dist/README.$p`;
}

# Copy other files
foreach my $file ( qw(Makefile.PL COPYING INSTALL mysqltoolkit.spec) ) {
   `cp $file $dist`;
}

# Set the DISTRIB variable
`grep DISTRIB -rl $dist | xargs sed -i -e 's/\@DISTRIB\@/$rev/'`;

# Write the MANIFEST
`find $dist -type f -print | sed -e 's/$dist.//' > $dist/MANIFEST`;
`echo MANIFEST >> $dist/MANIFEST`;

# Do it!!!!
print `tar zcf $dist.tar.gz $dist`;
print `zip -r $dist.zip $dist`;

# #####################################################################
# Subroutines
# #####################################################################

sub x {
   my ($name) = @_;
   sprintf('%03d%03d%03d', $name =~ m/(\d+)/g);
}
