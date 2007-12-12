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
# QueryRewriter package $Revision$
# ###########################################################################
use strict;
use warnings FATAL => 'all';

package QueryRewriter;

my $quote_re = qr/"(?:(?!(?<!\\)").)*"|'(?:(?!(?<!\\)').)*'/;
my $bal;
$bal         = qr/
                  \(
                  (?:
                     (?> [^()]+ )    # Non-parens without backtracking
                     |
                     (??{ $bal })    # Group with matching parens
                  )*
                  \)
                 /x;


sub new {
   my ( $class ) = @_;
   bless {}, $class;
}

# Normalizes variable queries to "query prototypes".  See
# http://dev.mysql.com/doc/refman/5.0/en/literals.html
sub norm {
   my ( $self, $query ) = @_;
   $query = lc $query;
   $query =~ s/^\s*(?:--|#).*//gm;              # One-line comments
   $query =~ s{
              (?<![\w.+-])
              [+-]?
              (?:
                \d+
                (?:[.]\d*)?
                |[.]\d+
              )
              (?:e[+-]?\d+)?
              \b
             }
             {N}gx;                             # Float/real into N
   $query =~ s/\b0(?:x[0-9a-f]+|b[01]+)\b/N/g;  # Hex/bin into N
   $query =~ s/[xb]'N'/N/g;                     # Hex/bin into N
   $query =~ s/$quote_re/S/gx;                  # Turn quoted strings into S
   $query =~ s/\A\s+//;                         # Chop off leading whitespace
   $query =~ s/\s{2,}/ /g;                      # Collapse all whitespace
   $query =~ s/[\n\r\f]+/ /g;                   # Collapse newlines etc
   $query =~ s{
               \b(in|values)\s*\(\s*([NS])\s*,[^\)]*\)
              }
              {$1($2+)}gx;      # Collapse IN() and VALUES() lists
   # Table names that end with one or two groups of digits
   $query =~ s/(?<=\w_)\d+(_\d+)?\b/$1 ? "N_N" : "N"/eg;
   return $query;
}

sub convert {
   my ( $self, $query ) = @_;
   return unless $query;
   $query =~ s{
                 \A.*?
                 update\s+(.*?)
                 \s+set\b(.*?)
                 (?:\s+where\b(.*?))?
                 (limit\s*\d+(?:\s*,\s*\d+)?)?
                 \Z
              }
              {__update_to_select($1, $2, $3, $4)}exsi;
   $query =~ s{
                 \A.*?
                 (?:insert|replace)\s+
                 into(.*?)\(([^\)]+)\)\s*
                 values\s*(\(.*?\))\s*
                 (?:\blimit\b|on\s*duplicate\s*key.*)?\s*
                 \Z
              }
              {__insert_to_select($1, $2, $3)}exsi;
   $query =~ s{
                 \A.*?
                 delete\s+(.*?)
                 from(.*)
                 \Z
              }
              {select * from $2}xsi;
   $query =~ s/\s*on\s+duplicate\s+key\s+update.*\Z//si;
   $query =~ s/\A.*?(?=\bSELECT\s*\b)//ism;
   return $query;
}

sub __insert_to_select {
   my ( $tbl, $cols, $vals ) = @_;
   $ENV{MKDEBUG} && _d('Args: ', @_);
   my @cols = split(/,/, $cols);
   $ENV{MKDEBUG} && _d('Cols: ', @cols);
   $vals =~ s/^\(|\)$//g; # Strip leading/trailing parens
   my @vals = $vals =~ m/($quote_re|[^,]*${bal}[^,]*|[^,]+)/g;
   $ENV{MKDEBUG} && _d('Vals: ', @vals);
   if ( @cols == @vals ) {
      return "select * from $tbl where "
         . join(' and ', map { "$cols[$_]=$vals[$_]" } (0..$#cols));
   }
   else {
      return "select * from $tbl limit 1";
   }
}

sub __update_to_select {
   my ( $from, $set, $where, $limit ) = @_;
   return "select $set from $from "
      . ( $where ? "where $where" : '' )
      . ( $limit ? " $limit "      : '' );
}

sub wrap {
   my ( $self, $query ) = @_;
   return unless $query;
   return $query =~ m/\A\s*select/i
      ? "select 1 from ($query) as x limit 1"
      : $query;
}

sub _d {
   my ( $line ) = (caller(0))[2];
   print "# QueryRewriter:$line ", @_, "\n";
}

1;

# ###########################################################################
# End QueryRewriter package
# ###########################################################################
