# This program is copyright (c) 2007 Baron Schwartz.
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
# QueryNormalizer package $Revision$
# ###########################################################################
use strict;
use warnings FATAL => 'all';

package QueryNormalizer;

my $num_regex = qr/[+-]?(?=\d|\.)\d*(?:\.\d+)?(?:e[+-]?\d+|)/;

sub new {
   my ( $class ) = @_;
   bless {}, $class;
}

# Normalizes variable queries to "query prototypes".  See
# http://dev.mysql.com/doc/refman/5.0/en/literals.html: support for hex
# notation isn't working right.  There's an unfinished test for this too.  The
# float/real regex gobbles part of hex notation.
sub norm {
   my ( $self, $query ) = @_;
   $query = lc $query;
   $query =~ s{
              (?!<[xb0-9.+-])
              [+-]?
              (?=\d|[.])
              \d*
              (?:\.\d{0,})?
              (?i:e[+-]?\d+|)
              (?![exb0-9.+-])
             }
             {N}gx;                              # Float/real into N
   # $query =~ s/\b0(?:x[0-9a-f]+|b[01]+)\b/N/g;   # Hex/bin into N
   # $query =~ s/\b(?:x'[0-9a-f]+|b'[01]+)'\b/N/g; # Hex/bin into N
   $query =~ s/\b\d+\b/N/g;                      # Int into N
   $query =~ s{
               ("(?:(?!(?<!\\)").)*"
               |'(?:(?!(?<!\\)').)*')
              }
              {S}gx;            # Turn quoted strings into S
   $query =~ s/\A\s+//;         # Chop off leading whitespace
   $query =~ s/(?<=\b\s)\s+//g; # Collapse all whitespace
   $query =~ s/[\n\r\f]+/ /g;   # Collapse newlines etc
   $query =~ s{
               \bin\s*\(\s*([NS])\s*,[^\)]*\)
              }
              {in($1+)}gx;      # Collapse IN() lists
   # Table names that end with one or two groups of digits
   $query =~ s/(?<=\w_)\d+(_\d+)?\b/$1 ? "N_N" : "N"/eg;
   return $query;
}

1;

# ###########################################################################
# End QueryNormalizer package
# ###########################################################################
