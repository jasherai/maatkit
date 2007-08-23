#!/usr/bin/perl

use strict;
use warnings FATAL => 'all';

use WWW::Mechanize;
use Term::ReadKey;
use HTTP::Cookies;

my $package = shift or die "specify a package";
my $sf_id   = `cat ../$package/sf_id`;
die "No sf_id" unless $sf_id =~ m/^\d+$/;

my $cookie = HTTP::Cookies->new(file => '/tmp/cookie',autosave => 1,);
my $mech = WWW::Mechanize->new(
   autocheck => 1,
   cookie_jar => $cookie,
   agent => 'Mozilla/5.0 (X11; U; Linux x86_64; en-US; rv:1.8.1.6)'
            . ' Gecko/20061201 Firefox/2.0.0.6 (Ubuntu-feisty)',
);

my $pw;
print "Enter password: ";
ReadMode('noecho');
chomp($pw = <STDIN>);
ReadMode('normal');
print "\n";

# Find the desired version number and changelog.
my $file;
open($file, "<", "../$package/Changelog")
   or die $!;
my $contents = do { local $/ = undef; <$file>; };
close $file;
my ($ver) = $contents =~ m/version (\d+\.\d+\.\d+)/;
my ($log) = $contents =~ m/^(200.*?)^200/sm;

$mech->get('https://sourceforge.net/project/admin/editpackages.php?group_id=189154');

$mech->submit_form(
   form_name => 'login',
   fields => {
      form_loginname => 'bps7j',
      form_pw => $pw,
   },
);

$mech->follow_link(
   text_regex => qr/Edit Releases/,
   url_regex  => qr/package_id=$sf_id/,
);

die "I'm not logged in"
   if $mech->content =~ m/Log in to SourceForge.net/;

my ($edit_link) = $mech->content
   =~ m/\s$ver\s+<a href="(editreleases.php?package_id=$sf_id.*?)">\s+\[Edit This Release/;
if ( !$edit_link ) { # No package, go create it.
   $mech->back();

   $mech->follow_link(
      text_regex => qr/Add Release/,
      url_regex  => qr/package_id=$sf_id/,
   );

   $mech->submit_form(
      with_fields => {
         release_name => $ver,
      },
   );
}
