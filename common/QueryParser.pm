# This program is copyright 2008-@CURRENTYEAR@ Percona Inc.
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
# QueryParser package $Revision$
# ###########################################################################
package QueryParser;

use strict;
use warnings FATAL => 'all';
use English qw(-no_match_vars);

use constant MKDEBUG => $ENV{MKDEBUG};
our $tbl_ident = qr/(?:`[^`]+`|\w+)(?:\.(?:`[^`]+`|\w+))?/;

sub new {
   my ( $class ) = @_;
   bless {}, $class;
}

sub get_tables {
   my ( $self, $query ) = @_;
   return unless $query;

   # Since these keywords may appear between UPDATE or SELECT and
   # the table refs, they need to be removed so they do not get
   # mistaken as tables.
   $query =~ s/ (?:LOW_PRIORITY|IGNORE|STRAIGHT_JOIN)//ig;

   my @tables;
   foreach my $tbls (
      $query =~ m{
         \b(?:\,|FROM|JOIN|UPDATE|INTO) # Words that precede table names
         \b\s*
         # Capture the identifier and any number of comma-join identifiers that
         # follow it, optionally with aliases with or without the AS keyword
         ($tbl_ident
            (?: (?:\s+ (?:AS\s+)? \w+)?, \s*$tbl_ident )*
         )
      }xgio )
   {
      MKDEBUG && _d("match: $tbls");
      foreach my $tbl ( split(',', $tbls) ) {
         # Remove implicit or explicit (AS) alias.
         $tbl =~ s/\s*($tbl_ident)(\s+.*)?/$1/gi;
         push @tables, $tbl;
      }
   }
   return @tables;
}

sub get_aliases {
   my ( $self, $query ) = @_;
   return unless $query;
   my $aliases;

   # Since these keywords may appear between UPDATE or SELECT and
   # the table refs, they need to be removed so they do not get
   # mistaken as tables.
   $query =~ s/ (?:LOW_PRIORITY|IGNORE|STRAIGHT_JOIN)//ig;

   # These keywords may appeart before JOIN which will be mistaken as
   # an implicit alias to the preceding table if they are not removed.
   $query =~ s/ (?:INNER|OUTER|CROSS|LEFT|RIGHT|NATURAL)//ig;

   # Get the table references clause and the keyword that starts the clause.
   # See the next comments below for why we need this starting keyword.
   my ($tbl_refs, $from) = $query =~ m{
      (
         (FROM|INTO|UPDATE)\b\s*   # Keyword before table refs
         .+?                       # Table refs
      )
      (?:\s+|\z)                   # If the query does not end with the table
                                   # refs then there must be at least 1 space
                                   # between the last tbl ref and the next
                                   # keyword
      (?:WHERE|ORDER|LIMIT|HAVING|SET|VALUES|\z) # Keyword after table refs
   }ix;

   # This shouldn't happen, often at least.
   die "Failed to parse table references from $query"
      unless $tbl_refs && $from;

   MKDEBUG && _d("tbl refs: $tbl_refs");

   # The keyword that being the table refs clause must be included so
   # that the first table will match. We could not include it and make
   # the before_tbl keywords match optionally, but then queries like:
   #    FROM t1 a JOIN t2 b ON a.col1=b.col2
   # will have col2 match as a tbl because no specific before_tbl keywords
   # were required so after matching 't2 b', Perl will ignore everything
   # until col2 which matches the 2nd line in the regex in while below.
   my $before_tbl = qr/(?:,|JOIN|\s|$from)+/i;

   # These keywords signal the end of one table ref and the start of another,
   # or the start of an ON|USING part of a JOIN clause (which we want to skip
   # over), or the end of the string (\z). We need these ending keywords so
   # that they are not mistaken as an implicit alias name for the preceding tbl.
   my $after_tbl  = qr/(?:,|JOIN|ON|USING|\z)/i;

   # This is required for cases like:
   #    FROM t1 JOIN t2 ON t1.col1=t2.col2 JOIN t3 ON t2.col3 = t3.col4
   # Because spaces may precede a tbl and a tbl may end with \z, then
   # t3.col4 will match as a table. However, t2.col3=t3.col4 will not match.
   $tbl_refs =~ s/ = /=/g;

   while (
      $tbl_refs =~ m{
         $before_tbl\b\s*
            ( ($tbl_ident) (?:\s+ (?:AS\s+)? (\w+))? )
         \s*$after_tbl
      }xgio )
   {
      my ( $tbl_ref, $db_tbl, $alias ) = ($1, $2, $3);
      MKDEBUG && _d("match: $tbl_ref");

      # Handle subqueries.
      if ( $tbl_ref =~ m/^AS\s+\w+/i ) {
         # According the the manual
         # http://dev.mysql.com/doc/refman/5.0/en/unnamed-views.html:
         # "The [AS] name  clause is mandatory, because every table in a
         # FROM clause must have a name."
         # So if the tbl ref begins with 'AS', then we probably have a
         # subquery.
         MKDEBUG && _d("Subquery $tbl_ref");
         $aliases->{$alias} = undef;
         next;
      }

      my ( $db, $tbl ) = $db_tbl =~ m/^(?:(.*?)\.)?(.*)/;
      $aliases->{$alias || $tbl} = $tbl;
      $aliases->{DATABASE}->{$tbl} = $db if $db;
   }
   return $aliases;
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
# End QueryParser package
# ###########################################################################
