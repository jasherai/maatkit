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

# A list of verbs that can appear in queries.  I know this is incomplete -- it
# does not have CREATE, DROP, ALTER, TRUNCATE for example.  But I don't need
# those for my client yet.  Other verbs: KILL, LOCK, UNLOCK
our $verbs   = qr{^SHOW|^FLUSH|^COMMIT|^ROLLBACK|^BEGIN|SELECT|INSERT
                  |UPDATE|DELETE|REPLACE|^SET|UNION|^START}xi;
our $ident   = qr/(?:`[^`]+`|\w+)(?:\s*\.\s*(?:`[^`]+`|\w+))?/; # db.tbl identifier
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

# The one-line comment pattern is quite crude.  This is intentional for
# performance.  The multi-line pattern does not match version-comments.
my $olc_re = qr/(?:--|#)[^'"\r\n]*(?=[\r\n]|\Z)/;  # One-line comments
my $mlc_re = qr#/\*[^!].*?\*/#sm;                  # But not /*!version */

sub new {
   my ( $class ) = @_;
   bless {}, $class;
}

# Strips comments out of queries.
sub strip_comments {
   my ( $self, $query ) = @_;
   $query =~ s/$olc_re//go;
   $query =~ s/$mlc_re//go;
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

   # First, we start with a bunch of special cases that we can optimize because
   # they are special behavior or because they are really big and we want to
   # throw them away as early as possible.
   $query =~ m#\ASELECT /\*!40001 SQL_NO_CACHE \*/ \* FROM `# # mysqldump query
      && return 'mysqldump';
   # Matches queries like REPLACE /*foo.bar:3/3*/ INTO checksum.checksum
   $query =~ m#/\*\w+\.\w+:\d/\d\*/#     # mk-table-checksum, etc query
      && return 'maatkit';
   # Administrator commands appear to be a comment, so return them as-is
   $query =~ m/\A# administrator command: /
      && return $query;
   # Special-case for stored procedures.
   $query =~ m/\A\s*(call\s+\S+)\(/i
      && return lc($1); # Warning! $1 used, be careful.
   # mysqldump's INSERT statements will have long values() lists, don't waste
   # time on them... they also tend to segfault Perl on some machines when you
   # get to the "# Collapse IN() and VALUES() lists" regex below!
   if ( my ($beginning) = $query =~ m/\A(INSERT INTO \S+ VALUES \(.*?\)),\(/ ) {
      $query = $beginning; # Shorten multi-value INSERT statements ASAP
   }

   $query =~ s/$olc_re//go;
   $query =~ s/$mlc_re//go;
   $query =~ s/\Ause \S+\Z/use ?/i       # Abstract the DB in USE
      && return $query;

   $query =~ s/\\["']//g;                # quoted strings
   $query =~ s/".*?"/?/sg;               # quoted strings
   $query =~ s/'.*?'/?/sg;               # quoted strings

   # This regex is extremely broad in its definition of what looks like a
   # number.  That is for speed.
   $query =~ s{                          # Anything vaguely resembling numbers
      (?<=[^0-9+-])
      [0-9+-].*?
      (?=[^0-9a-f.xb+-]|\Z)
      }{?}gx;
   $query =~ s/[xb.+-]\?/?/g;            # Clean up leftovers
   $query =~ s/\A\s+//;                  # Chop off leading whitespace
   chomp $query;                         # Kill trailing whitespace
   $query =~ tr[ \n\t\r\f][ ]s;          # Collapse whitespace
   $query = lc $query;
   $query =~ s/\bnull\b/?/g;             # Get rid of NULLs
   $query =~ s{
               \b(in|values?)(?:[\s,]*\([\s?,]*\))+
              }
              {$1(?+)}gx;      # Collapse IN() and VALUES() lists
   $query =~ s{
               \b(select\s.*?)(?:(\sunion(?:\sall)?)\s\1)+
              }
              {$1 /*repeat$2*/}xg; # UNION
   $query =~ s/\blimit \?(?:, ?\?| offset \?)?/limit ?/; # LIMIT
   # The following are disabled because of speed issues.  Should we try to
   # normalize whitespace between and around operators?  My gut feeling is no.
   # $query =~ s/ , | ,|, /,/g;    # Normalize commas
   # $query =~ s/ = | =|= /=/g;       # Normalize equals
   # $query =~ s# [,=+*/-] ?|[,=+*/-] #+#g;    # Normalize operators
   return $query;
}

# This is kind of like fingerprinting, but it super-fingerprints to something
# that shows the query type and the tables/objects it accesses.
sub distill {
   my ( $self, $query ) = @_;

   # Special cases.
   $query =~ m/\A\s*call\s+(\S+)\(/i
      && return "CALL $1"; # Warning! $1 used, be careful.
   $query =~ m/\A# administrator/
      && return "ADMIN";
   $query =~ m/\A\s*use\s+/
      && return "USE";

   # First, get the query type -- just extract all the verbs and collapse them
   # together.
   my @verbs = $query =~ m/\b($verbs)\b/gio;
   @verbs    = do {
      my $last = '';
      grep { my $pass = $_ ne $last; $last = $_; $pass } map { uc } @verbs;
   };
   my $verbs = join(q{ }, @verbs);
   $verbs =~ s/( UNION SELECT)+/ UNION/g;

   # Now get the objects in the query.  XXX This code is taken from
   # QueryParser::get_tables() so please keep it in sync with that code.
   my @tables;
   foreach my $tbls (
      $query =~ m{
         \b(?:FROM|JOIN|UPDATE|INTO) # Words that precede table names
         \b\s*
         # Capture the identifier and any number of comma-join identifiers that
         # follow it, optionally with aliases with or without the AS keyword
         ($ident
            (?:\s*(?:(?:AS\s*)?\w*)?,\s*$ident)*
         )
      }xgio)
   {
      # Remove [AS] foo aliases
      $tbls =~ s/($ident)\s+(?:as\s+\w+|\w+)/$1/gi;
      push @tables, $tbls =~ m/($ident)/g;
   }

   # "Fingerprint" the tables.
   @tables = map {
      $_ =~ s/`//g;
      $_ =~ s/(_?)\d+/$1?/g;
      $_;
   } @tables;

   # Collapse the table list
   @tables = do {
      my $last = '';
      grep { my $pass = $_ ne $last; $last = $_; $pass } @tables;
   };

   $query = join(q{ }, $verbs, @tables);
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
   my ($package, undef, $line) = caller 0;
   @_ = map { (my $temp = $_) =~ s/\n/\n# /g; $temp; }
        map { defined $_ ? $_ : 'undef' }
        @_;
   # Use $$ instead of $PID in case the package
   # does not use English.
   print "# $package:$line $$ ", @_, "\n";
}

1;

# ###########################################################################
# End QueryRewriter package
# ###########################################################################
