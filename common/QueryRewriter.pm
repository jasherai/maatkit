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

use English qw(-no_match_vars);

use constant MKDEBUG => $ENV{MKDEBUG};

my $quote_re = qr/"(?:(?!(?<!\\)").)*"|'(?:(?!(?<!\\)').)*'/; # Costly!
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

# Strips comments out of queries.
sub strip_comments {
   my ( $self, $query ) = @_;
   $query =~ s/[\r\n]+\s*(?:--|#).*//gm; # One-line comments
   $query =~ s#/\*[^!].*?\*/##gsm;   # /*..*/ comments, but not /*!version */
   return $query;
}

# Normalizes variable queries to a "query fingerprint" by abstracting away
# parameters, canonicalizing whitespace, etc.  See
# http://dev.mysql.com/doc/refman/5.0/en/literals.html for literal syntax.
# Note: Any changes to this function must be profiled for speed!  Speed of this
# function is critical for mk-log-parser.  There are known bugs in this, but the
# balance between maybe-you-get-a-bug and speed favors speed.  See past
# revisions of this subroutine for more correct, but slower, regexes.
sub fingerprint {
   my ( $self, $query ) = @_;
   $query =~ s/[\r\n]+\s*(?:--|#).*//gm; # One-line comments
   $query =~ s#/\*[^!].*?\*/##gsm;       # /*..*/ comments
   $query =~ s/\Ause \S+\Z/use ?/i       # Abstract the DB in USE
      && return $query;

   $query =~ s/\\["']//g;                # quoted strings
   $query =~ s/".*?"/?/g;                # quoted strings
   $query =~ s/'.*?'/?/g;                # quoted strings

   # This regex is extremely broad in its definition of what looks like a
   # number.  That is for speed.
   $query =~ s{                          # Anything vaguely resembling numbers
      (?<=[^0-9+-])
      [0-9+-].*?
      (?=[^0-9a-f.xb+-]|\Z)
      }{?}gx;
   $query =~ s/[xb.+-]\?/?/g;            # Clean up leftovers
   $query =~ s/\A\s+//;                  # Chop off leading whitespace
   $query =~ tr[ \n\t\r\f][ ]s;          # Collapse whitespace
   $query = lc $query;
   $query =~ s{
               \b(in|values?)(?:[\s,]*\([\s?,]*\))+
              }
              {$1(?+)}gx;      # Collapse IN() and VALUES() lists
   return $query;
}

sub convert_to_select {
   my ( $self, $query ) = @_;
   return unless $query;
   $query =~ s{
                 \A.*?
                 update\s+(.*?)
                 \s+set\b(.*?)
                 (?:\s*where\b(.*?))?
                 (limit\s*\d+(?:\s*,\s*\d+)?)?
                 \Z
              }
              {__update_to_select($1, $2, $3, $4)}exsi
      || $query =~ s{
                    \A.*?
                    (?:insert|replace)\s+
                    .*?\binto\b(.*?)\(([^\)]+)\)\s*
                    values?\s*(\(.*?\))\s*
                    (?:\blimit\b|on\s*duplicate\s*key.*)?\s*
                    \Z
                 }
                 {__insert_to_select($1, $2, $3)}exsi
      || $query =~ s{
                    \A.*?
                    delete\s+(.*?)
                    \bfrom\b(.*)
                    \Z
                 }
                 {__delete_to_select($1, $2)}exsi;
   $query =~ s/\s*on\s+duplicate\s+key\s+update.*\Z//si;
   $query =~ s/\A.*?(?=\bSELECT\s*\b)//ism;
   return $query;
}

sub convert_select_list {
   my ( $self, $query ) = @_;
   $query =~ s{
               \A\s*select(.*?)\bfrom\b
              }
              {$1 =~ m/\*/ ? "select 1 from" : "select isnull(coalesce($1)) from"}exi;
   return $query;
}

sub __delete_to_select {
   my ( $delete, $join ) = @_;
   if ( $join =~ m/\bjoin\b/ ) {
      return "select 1 from $join";
   }
   return "select * from $join";
}

sub __insert_to_select {
   my ( $tbl, $cols, $vals ) = @_;
   MKDEBUG && _d('Args: ', @_);
   my @cols = split(/,/, $cols);
   MKDEBUG && _d('Cols: ', @cols);
   $vals =~ s/^\(|\)$//g; # Strip leading/trailing parens
   my @vals = $vals =~ m/($quote_re|[^,]*${bal}[^,]*|[^,]+)/g;
   MKDEBUG && _d('Vals: ', @vals);
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

sub wrap_in_derived {
   my ( $self, $query ) = @_;
   return unless $query;
   return $query =~ m/\A\s*select/i
      ? "select 1 from ($query) as x limit 1"
      : $query;
}

sub _d {
   my ( $line ) = (caller(0))[2];
   @_ = map { (my $temp = $_) =~ s/\n/\n# /g; $temp; } @_;
   print "# QueryRewriter:$line $PID ", @_, "\n";
}

1;

# ###########################################################################
# End QueryRewriter package
# ###########################################################################
