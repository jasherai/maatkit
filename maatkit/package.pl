#!/usr/bin/perl

use strict;
use warnings FATAL => 'all';

use English qw(-no_match_vars);
use Data::Dumper;
use File::Basename;
use Pod::Html;

print `svn up ../../`;

# Don't release if there are any uncommitted changes in the source.
chomp ( my $svnst = `svn st ../../` );
if ( $svnst =~ m/\S/ ) {
   print "Not releasing; you have uncommitted changes:\n$svnst\n";
   exit(1);
}

# Find list of packages
my $base     = '..';
my @packages = qw(
   mk-archiver mk-deadlock-logger mk-duplicate-key-checker mk-find
   mk-finger mk-heartbeat mk-log-parser mk-parallel-dump mk-slave-prefetch
   mk-parallel-restore mk-query-profiler mk-show-grants mk-slave-delay
   mk-slave-restart mk-table-checksum mk-table-sync mk-visual-explain
   mk-slave-find mk-slave-move);

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
print `mkdir -p html cache $dist/bin $dist/lib $dist/udf`;

# Copy the executables and their Changelog files into the $dist dir, and set the
# $VERSION variable correctly
foreach my $p ( sort keys %versions ) {
   print `for a in $base/$p/mk-*; do b=\`basename \$a\`; cp \$a $dist/bin; sed -i -e 's/\@VERSION\@/$versions{$p}/' $dist/bin/\$b; done`;
   print `echo "" >> $dist/Changelog`;
   print `cat $base/$p/Changelog >> $dist/Changelog`;
}

# Write maatkit.pod
print `cat maatkit.head.pod packlist maatkit.mid.pod > $dist/lib/maatkit.pm`;
open my $file, ">> $dist/lib/maatkit.pm" or die $OS_ERROR;
foreach my $program ( <$dist/bin/mk-*> ) {
   my $line = `grep -A 6 head1.NAME $program | tail -n 5`;
   my @parts = split(/\n\n/, $line);
   $line = $parts[0];
   my ( $prog, $rest ) = $line =~ m/^([\w-]+) - (.+)/ms;
   die "Can't parse $line\n" unless $rest;
   print $file "\n\n=item $prog\n\n$rest See L<$prog>.";
}
close $file;
print `cat maatkit.tail.pod >> $dist/lib/maatkit.pm`;
print `cat maatkitdsn.pod >> $dist/lib/maatkitdsn.pm`;

# Copy other files
foreach my $file ( qw(README Makefile.PL COPYING INSTALL maatkit.spec) ) {
   print `cp $file $dist`;
}
print `cp ../udf/fnv_udf.cc $dist/udf`;

# Set the DISTRIB variable
print `grep DISTRIB -rl $dist | xargs sed -i -e 's/\@DISTRIB\@/$rev/'`;

# Write the MANIFEST
print `find $dist -type f -print | sed -e 's~$dist.~~' > $dist/MANIFEST`;
print `echo MANIFEST >> $dist/MANIFEST`;

# Do it!!!!
print `cd release && tar zcf $distbase.tar.gz $distbase`;
print `cd release && zip -qr $distbase.zip    $distbase`;

# Make the documentation.  Requires two passes.
my @module_files = map { basename $_ } <$dist/bin/mk-*>;
my @doc_files    = qw(maatkit maatkitdsn);
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
   foreach my $doc ( @doc_files ) {
      pod2html(
         "--backlink=Top",
         "--cachedir=cache",
         "--htmldir=html",
         "--infile=$dist/lib/$doc.pm",
         "--outfile=html/$doc.html",
         "--libpods=perlfunc:perlguts:perlvar:perlrun:perlop",
         "--podpath=bin:lib",
         "--podroot=$dist",
         "--css=http://search.cpan.org/s/style.css",
      );
   }
}
# Wow, Pod::HTML is a pain in the butt.  Fix links now.
my $img = '<a href="http://sourceforge.net/projects/maatkit/"><img '
   . 'alt="SourceForge.net Logo" height="62" width="210" '
   . 'src="http://sflogo.sourceforge.net/sflogo.php?group_id=189154\&amp;type=5" '
   . 'style="float:right"/>';
print `for a in html/*; do sed -i -e 's~bin/~~g' \$a; done`;
print `for a in html/*; do sed -i -e 's~lib/~~g' \$a; done`;
print `for a in html/*; do sed -i -e 's~body>~body>$img~' \$a; done`;
print `for a in html/*; do sed -i -e 's~\`\`~"~g' \$a; done`;
print `for a in html/*; do sed -i -e "s~\\\`~\\\'~g" \$a; done`;
# And fix stupid links to "the X manpage" to just "X".
print `for a in html/*; do sed -i -e 's~the ([^ ]*) manpage~\\1~g' \$a; done`;

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
