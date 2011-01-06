#!/usr/bin/perl

use strict;
use warnings FATAL => 'all';

use English qw(-no_match_vars);
use Data::Dumper;
use File::Basename;

print `svn up ../../`;

# Don't release if there are any uncommitted changes in the source.
chomp ( my $svnst = `svn st ../` );
if ( $svnst =~ m/\S/ ) {
   print "Not releasing; you have uncommitted changes:\n$svnst\n";
   exit(1);
}

# Don't release if we use the construct $#{@$array} anywhere
chomp ( my $bad = `grep -r '#{' ../mk-*/mk-*` );
if ( $bad ) {
   print "Not releaseing; you have used a nonportable array index technique:\n"
      . $bad . "\n";
   exit(1);
}

# Find list of packages.
my $base     = '..';
my @packages = sort split(/\n/, `cat packages`);

# Don't release if any tool is missing a test
foreach my $p ( @packages ) {
   die "$p doesn't have a test"
      unless -d "$base/$p/t";
   # And complain if the tool doesn't run OK with MKDEBUG=1, or a variety of
   # other woes
   foreach my $tool ( <$base/$p/mk-*> ) {
      my $output = `MKDEBUG=1 $tool --help 2>&1`;
      die "$tool has unused/undefined command-line options"
         if $output =~ m/The following command-line options/;
      $output = `svn proplist $tool`;
      foreach my $prop ( qw(svn:executable svn:keywords) ) {
         die "$tool doesn't have $prop set" unless $output =~ m/$prop/;
      }
      $output = `svn propget svn:keywords $tool`;
      chomp $output;
      die "$tool doesn't have svn:keywords set to Revision"
         unless $output eq 'Revision';
   }
}

# Don't release if any module is missing the correct SVN keywords
foreach my $mod ( <$base/common/*.pm> ) {
   my $output = `svn propget svn:keywords $mod`;
   chomp $output;
   die "$mod doesn't have svn:keywords set to Revision"
      unless $output eq 'Revision';
}

my %versions;

# Find latest of each package
foreach my $p ( @packages ) {
   ($p) = $p =~ m/(mk-.*)/;
   if ( -f "$base/$p/Changelog" ) {
      $versions{$p} = get_version_or_quit("$base/$p/Changelog");
   }
}

# Commit the list of files and get the resulting version number.
print `svn up packlist`;
open my $packlist, "> packlist" or die $!;
print $packlist '   $Revision$', "\n", map { "$_ $versions{$_}\n" } sort keys %versions;
close $packlist;
print `svn ci -m 'Bump version' packlist`;
print `rm packlist`;
print `svn revert packlist`; # Just in case there were no changes
my $rev = `head -n 1 packlist | awk '{print \$2}'` + 0;

# make the dist directory
my $distbase = "maatkit-$rev";
my $dist = "release/$distbase";
print `rm -rf release html cache`;
print `mkdir -p html cache $dist/bin $dist/lib $dist/udf $dist/init`;

# Copy the executables and their Changelog files into the $dist dir, and set the
# $VERSION variable correctly
foreach my $p ( sort keys %versions ) {
   print `for a in $base/$p/mk-*; do b=\`basename \$a\`; cp \$a $dist/bin; sed -i -e 's/\@VERSION\@/$versions{$p}/' $dist/bin/\$b; done`;
   print `echo "" >> $dist/Changelog`;
   print `cat $base/$p/Changelog >> $dist/Changelog`;
}

# Write maatkit.pod
print `cat maatkit.head.pod packlist maatkit.mid.pod > $dist/maatkit.pod`;
open my $file, ">> $dist/maatkit.pod" or die $OS_ERROR;
foreach my $program ( <$dist/bin/mk-*> ) {
   my $line = `grep -A 6 head1.NAME $program | tail -n 5`;
   my @parts = split(/\n\n/, $line);
   $line = $parts[0];
   my ( $prog, $rest ) = $line =~ m/^([\w-]+) - (.+)/ms;
   die "Can't parse $line\n" unless $rest;
   print $file "\n\n=item $prog\n\n$rest See L<$prog>.";
}
close $file;
print `cat maatkit.tail.pod >> $dist/maatkit.pod`;

# Copy other files
foreach my $file ( qw(README Makefile.PL COPYING INSTALL ../spec/maatkit.spec) ) {
   print `cp $file $dist`;
}
print `cp ../udf/murmur_udf.cc ../udf/fnv_udf.cc $dist/udf`;
print `cp ../init/maatkit $dist/init`;

# Set the DISTRIB variable
print `grep DISTRIB -rl $dist | xargs sed -i -e 's/\@DISTRIB\@/$rev/'`;

# Set the CURRENTYEAR variable (for copyright notices)
my @t = localtime;
my $current_year = $t[5] + 1900;
# The 2nd sed removes single year "spans" like "2008-2008"
print `grep CURRENTYEAR -rl $dist | xargs sed -i -e 's/\@CURRENTYEAR\@/$current_year/' -e 's/$current_year-$current_year/$current_year/'`;

# Write the MANIFEST
print `find $dist -type f -print | sed -e 's~$dist.~~' > $dist/MANIFEST`;
print `echo MANIFEST >> $dist/MANIFEST`;

# Do it!!!!
print `cd release && tar zcf $distbase.tar.gz $distbase`;
print `cd release && zip -qr $distbase.zip    $distbase`;

# Cleanup temporary directories
print `rm -rf cache $dist`;

sub get_version_or_quit {
   my ( $file ) = @_;
   my $ver;
   open my $fh, "<", $file or die $OS_ERROR;
   while ( <$fh> ) {
      die "$file doesn't have a version set\n"
         if m/^   \*/;
      next unless m/version/;
      $ver = sprintf('%s', m/version ([0-9\.]+)/);
      last;
   }
   # Now look for the next version, and make sure it is smaller, and that the
   # version increased only by 1 in the first (maj/min/rev) part that increased.
   my $ver2;
   while ( <$fh> ) {
      next unless m/version/;
      $ver2 = sprintf('%s', m/version ([0-9\.]+)/);
      last;
   }
   if ( $ver2 ) {
      my @old_ver = $ver2 =~ m/(\d+)/g;
      my @new_ver = $ver  =~ m/(\d+)/g;
      my $old_ver = sprintf('%03d%03d%03d', @old_ver);
      my $new_ver = sprintf('%03d%03d%03d', @new_ver);
      if ( $old_ver ge $new_ver ) {
         die "Old version $ver2 is not older than new version $ver in $file!";
      }
      foreach my $i ( 0 .. $#old_ver ) {
         if ( $new_ver[$i] > $old_ver[$i] ) {
            if ( $new_ver[$i] > $old_ver[$i] + 1 ) {
               die "New version $new_ver increased too much from $old_ver in $file";
            }
            last;
         }
      }
   }
   close $fh;
   return $ver;
}
