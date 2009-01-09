#!/usr/bin/perl

use strict;
use warnings FATAL => 'all';

use Test::More tests => 3;
use English qw(-no_match_vars);

# Read _d.pl which is just sub _d { ... }
# and eval it into the current namespace.
open my $fh, '<', '../_d.pl' or die $!;
my $d_file= do { local $/ = undef; <$fh> };
close $fh;
eval $d_file;

# Calls _d() and redirects its output (which by default
# goes to STDOUT) to a file so that we can capture it.
sub d {
   open my $output_file, '>', '_d.output' or die $!;
   select $output_file;
   _d(@_);
   close $output_file;
   my $output = `cat _d.output`;
   `rm -f _d.output`;
   select STDOUT;
   return $output;
}

like(d('alive'), qr/^# main:\d+ \d+ alive\n/, '_d lives');
like(d('val: ', undef), qr/val: undef/, 'Prints undef for undef');
like(d("foo\nbar"), qr/foo\n# bar\n/, 'Breaks \n and adds #');

exit;
