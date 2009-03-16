#!/usr/bin/perl

use strict;
use warnings FATAL => 'all';
use English qw(-no_match_vars);
use Test::More tests => 5;

use Data::Dumper;
$Data::Dumper::Indent = 1;

# Read _d.pl which is just sub _d { ... }
# and eval it into the current namespace.
open my $fh, '<', '../_d.pl' or die $!;
my $d_file= do { local $/ = undef; <$fh> };
close $fh;
eval $d_file;

# Calls _d() and redirects its output (which by default
# goes to STDERR) to a file so that we can capture it.
sub d {
   open STDERR, '>', '_d.output'
      or die "Cannot capture STDERR to _d.output: $OS_ERROR";
   _d(@_);
   my $output = `cat _d.output`;
   `rm -f _d.output`;
   return $output;
}

like(
   d('alive'),
   qr/^# main:\d+ \d+ alive\n/,
   '_d lives'
);

like(
   d('val:', undef),
   qr/val: undef/,
   'Prints undef for undef'
);

like(
   d("foo\nbar"),
   qr/foo\n# bar\n/,
   'Breaks \n and adds #'
);

like(
   d('hi', 'there'),
   qr/hi there$/,
   'Prints space between args'
);

my %foo = (
   string => 'value',
   array  => [1],
);
like(
   d('Data::Dumper says', Dumper(\%foo)),
   qr/Data::Dumper says \$VAR1 = {\n/,
   'Data::Dumper'
);

exit;
