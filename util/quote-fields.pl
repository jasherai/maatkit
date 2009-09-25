#!/usr/bin/env perl

=pod

=head1 NAME

quote-field.pl - Quote all fields

=head1 SYNOPSIS

  quote-field.pl file.txt

=head1 AUTHOR

Daniel Nichter

=head1 LICENSE

This software is released to the public domain, with no guarantees whatsoever.

=cut

use strict;
use warnings FATAL => 'all';
use English qw(-no_match_vars);

use constant MKDEBUG => $ENV{MKDEBUG};

my $file = shift @ARGV || '-';
my $fh;
if ( $file eq '-' ) {
   $fh = *STDIN;
}
else {
   open $fh, "<", $file or die "Cannot open $file: $OS_ERROR";
}

while ( my $line = <$fh> ) {
   chomp $line;
   MKDEBUG && _d("Read line:", $line);
   my @fields = split(/,(?!\s)/, $line);
   MKDEBUG && _d("Fields split from line:", @fields);
   my @quoted_fields = map {
      my $field        = $_;
      my $quoted_field = $field;
      if ( $field ne '""'
           && (substr($field, 0, 1) ne '"' && substr($field, -1, 1) ne '"') ) {
         $quoted_field = "\"$field\"";
      }
      MKDEBUG && _d($field, '=', $quoted_field);
      $quoted_field;
   } @fields;

   print join(',', @quoted_fields) . "\n";
}

close $fh or warn "Cannot close $file: $OS_ERROR";

exit;

sub _d {
   my ($package, undef, $line) = caller 0;
   @_ = map { (my $temp = $_) =~ s/\n/\n# /g; $temp; }
        map { defined $_ ? $_ : 'undef' }
        @_;
   print STDERR "# $package:$line $PID ", join(' ', @_), "\n";
}
