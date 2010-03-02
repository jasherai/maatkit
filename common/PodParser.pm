# This program is copyright 2010 Percona Inc.
# Feedback and improvements are welcome.
#
# THIS PROGRAM IS PROVIDED "AS IS" AND WITHOUT ANY EXPRESS OR IMPLIED
# WARRANTIES, INCLUDING, WITHOUT LIMITATION, THE IMPLIED WARRANTIES OF
# MERCHANTIBILITY AND FITNESS FOR A PARTICULAR PURPOSE.
#
# This program is free software; you can redistribute it and/or modify it under
# the terms of the GNU General Public License as published by the Free Software
# Foundation, version 2; OR the Perl Artistic License.  On UNIX and similar
# systems, you can issue `man perlgpl' or `man perlartistic' to read these
# licenses.
#
# You should have received a copy of the GNU General Public License along with
# this program; if not, write to the Free Software Foundation, Inc., 59 Temple
# Place, Suite 330, Boston, MA  02111-1307  USA.
# ###########################################################################
# PodParser package $Revision$
# ###########################################################################
package PodParser;

use strict;
use warnings FATAL => 'all';
use English qw(-no_match_vars);

use constant MKDEBUG => $ENV{MKDEBUG} || 0;

sub new {
   my ( $class, %args ) = @_;
   foreach my $arg ( qw() ) {
      die "I need a $arg argument" unless $args{$arg};
   }

   my $self = {
   };
   return bless $self, $class;
}

# Arguments:
#   * file       scalar: file name with POD to parse (default __FILE__)
#   * section    scalar: head1 section name to parse
#   * subsection scalar: (optional) head2 subsection under head1 section
#                        to parse
#   * trf        coderef: callback to transform or reject parsed (sub)section
# Return an array of paragraphs from the (sub)section.  If trf returns
# undef, that paragraph is discarded.
sub parse_section {
   my ( $self, %args ) = @_;
   my ($file, $section, $subsection, $trf)
      = @args{qw(file section subsection trf)};

   $file ||= __FILE__;
   open my $fh, '<', $file or die "Cannot open $file: $OS_ERROR";
   MKDEBUG && _d('Parsing POD section', $section, $subsection, 'from', $file);

   local $INPUT_RECORD_SEPARATOR = '';
   my $POD_link_re = '[LC]<"?([^">]+)"?>';

   my $para;
   while ( $para = <$fh> ) {
      next unless $para =~ m/^=head1 $section/;
      MKDEBUG && _d($para);
      last;
   }
   if ( !$para ) {
      MKDEBUG && _d('Did not find section', $section);
      return;
   }

   if ( $subsection ) {
      while ( $para = <$fh> ) {
         next unless $para =~ m/^=head2 $subsection/;
         last
      }
   }
   if ( !$para ) {
      MKDEBUG && _d('Did not find subsection', $subsection);
      return;
   }

   my @chunks;
   while ( $para = <$fh> ) {
      last if ($subsection ? $para =~ m/^=head[12]/ : $para =~ m/^=head1/);
      next if $para =~ m/=head/;
      chomp $para;
      $para =~ s/$POD_link_re/$1/go;
      if ( $trf ) {
         $para = $trf->($para);
         next unless $para;
      }
      push @chunks, $para;
   }

   return @chunks;
}

sub _d {
   my ($package, undef, $line) = caller 0;
   @_ = map { (my $temp = $_) =~ s/\n/\n# /g; $temp; }
        map { defined $_ ? $_ : 'undef' }
        @_;
   print STDERR "# $package:$line $PID ", join(' ', @_), "\n";
}

1;

# ###########################################################################
# End PodParser package
# ###########################################################################
