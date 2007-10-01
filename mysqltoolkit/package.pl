#!/usr/bin/perl

use strict;
use warnings FATAL => 'all';

use English qw(-no_match_vars);
use Data::Dumper;
use File::Basename;
use Pod::Html;

print `svn up ../../`;

# Find list of packages
my $base     = '../../tags';
my @packages = map { basename $_ } (split(/\s+/, `ls -d $base/mysql-*`));
my %versions;

# Find latest of each package
foreach my $p ( @packages ) {
   my @vers = map { basename $_ } (split(/\s+/, `ls -d $base/$p/mysql-*`));
   @vers = reverse sort { x($a) cmp x($b) } @vers;
   if ( @vers ) {
      $versions{$p} = $vers[0];
   }
   else {
      warn "No version found for $p";
   }
}

# Commit the list of files and get the resulting version number.
print `svn up packlist`;
open my $packlist, "> packlist" or die $!;
print $packlist '   $Revision$', "\n", map { "   $_\n" } sort values %versions;
close $packlist;
print `svn ci -m 'Bump version' packlist`;
print `rm packlist`;
print `svn revert packlist`; # Just in case there were no changes
my $rev = `head -n 1 packlist | awk '{print \$2}'` + 0;

# make the dist directory
my $distbase = "mysqltoolkit-$rev";
my $dist = "release/$distbase";
print `rm -rf release html cache`;
print `mkdir -p html cache $dist/bin $dist/lib`;

# Copy the executables and their Changelog files into the $dist dir, and set the
# $VERSION variable correctly
foreach my $p ( sort keys %versions ) {
   my ($version) = $versions{$p} =~ m/([\d.]+)/;
   print `for a in $base/$p/$versions{$p}/mysql-*; do b=\`basename \$a\`; cp \$a $dist/bin; sed -i -e 's/\@VERSION\@/$version/' $dist/bin/\$b; done`;
   print `echo "" >> $dist/Changelog`;
   print `cat $base/$p/$versions{$p}/Changelog >> $dist/Changelog`;
}
print `cp README $dist/`;

# Write mysqltoolkit.pod
print `cat mysqltoolkit.head.pod packlist mysqltoolkit.mid.pod > $dist/lib/mysqltoolkit.pm`;
open my $file, ">> $dist/lib/mysqltoolkit.pm" or die $OS_ERROR;
foreach my $program ( <$dist/bin/mysql-*> ) {
   my $line = `grep -A 6 head1.NAME $program | tail -n 5`;
   my @parts = split(/\n\n/, $line);
   $line = $parts[0];
   my ( $prog, $rest ) = $line =~ m/^([\w-]+) - (.+)/ms;
   die "Can't parse $line\n" unless $rest;
   print $file "\n\n=item $prog\n\n$rest See L<$prog>.";
}
close $file;
print `cat mysqltoolkit.tail.pod >> $dist/lib/mysqltoolkit.pm`;

# Copy other files
foreach my $file ( qw(Makefile.PL COPYING INSTALL mysqltoolkit.spec) ) {
   print `cp $file $dist`;
}

# Set the DISTRIB variable
print `grep DISTRIB -rl $dist | xargs sed -i -e 's/\@DISTRIB\@/$rev/'`;

# Write the MANIFEST
print `find $dist -type f -print | sed -e 's~$dist.~~' > $dist/MANIFEST`;
print `echo MANIFEST >> $dist/MANIFEST`;

# Do it!!!!
print `cd release && tar zcf $distbase.tar.gz $distbase`;
print `cd release && zip -qr $distbase.zip    $distbase`;

# Make the documentation.  Requires two passes.
my @module_files = map { basename $_ } <$dist/bin/mysql-*>;
for ( 0 .. 1 ) {
   foreach my $module ( @module_files ) {
      pod2html(
         "--backlink=Top",
         "--cachedir=cache",
         "--htmldir=html",
         "--infile=$dist/bin/$module",
         "--outfile=html/$module.html",
         "--libpods=perlfunc:perlguts:perlvar:perlrun:perlop",
         "--podpath=bin:lib",
         "--podroot=$dist",
         "--css=http://search.cpan.org/s/style.css",
      );
   }
   pod2html(
      "--backlink=Top",
      "--cachedir=cache",
      "--htmldir=html",
      "--infile=$dist/lib/mysqltoolkit.pm",
      "--outfile=html/mysqltoolkit.html",
      "--libpods=perlfunc:perlguts:perlvar:perlrun:perlop",
      "--podpath=bin",
      "--podroot=$dist",
      "--css=http://search.cpan.org/s/style.css",
   );
}
# Wow, Pod::HTML is a pain in the butt.  Fix links now.
my $img = '<a href="http://sourceforge.net/projects/mysqltoolkit/"><img '
   . 'alt="SourceForge.net Logo" height="62" width="210" '
   . 'src="http://sflogo.sourceforge.net/sflogo.php?group_id=189154\&amp;type=5" '
   . 'style="float:right"/>';
print `for a in html/*; do sed -i -e 's~bin/~~g' \$a; done`;
print `for a in html/*; do sed -i -e 's~body>~body>$img~' \$a; done`;
print `for a in html/*; do sed -i -e 's~\`\`~"~g' \$a; done`;
print `for a in html/*; do sed -i -e "s~\\\`~\\\'~g" \$a; done`;

# Cleanup temporary directories
print `rm -rf cache $dist`;

# #####################################################################
# Subroutines
# #####################################################################

sub x {
   my ($name) = @_;
   sprintf('%03d%03d%03d', $name =~ m/(\d+)/g);
}
