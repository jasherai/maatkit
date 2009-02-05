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

use Data::Dumper;
$Data::Dumper::Indent = 1;

use constant MKDEBUG => $ENV{MKDEBUG};
our $tbl_ref_pattern = qr/(?:`[^`]+`|\w+)(?:\.(?:`[^`]+`|\w+))?/;

sub new {
   my ( $class ) = @_;
   bless {}, $class;
}

sub get_tables {
   my ( $self, $query ) = @_;
   return unless $query;
   my @tables = ();
   # Remove [AS] foo aliases
   # $tbls =~ s/($tbl_ref_pattern)\s+(?:as\s+\w+|\w+)/$1/gi;
   $self->_get_table_refs($query);
   return @tables;
}

sub get_table_aliases {
   my ( $self, $query ) = @_;
   return unless $query;
   my $aliases = {};
   #   my ( $db, $tbl ) = $db_tbl =~ m/^(?:(\S+)\.)?(\S+)/;
   #   $aliases->{$alias || $tbl} = $tbl;
   #   $aliases->{DATABASE}->{$tbl} = $db if $db;
   $self->_get_table_refs($query);
   return $aliases;
}
 
# Returns an array of tables to which the query refers.
# XXX If you change this code, also change QueryRewriter::distill().
sub _get_table_refs {
   my ( $self, $query ) = @_;
   return unless $query;
   my @tbl_refs;

   MKDEBUG && _d("original query: $query");

   # Since these keywords may appear between UPDATE and the table refs,
   # they need to be removed so they do not get mistaken as tables.
   $query =~ s/ (?:LOW_PRIORITY|IGNORE)//g;

   # Get the table references clause and the keyword that starts the clause.
   # See the next comments below for why we need this starting keyword.
   my ($tbl_refs, $from) = $query =~ m/((FROM|INTO|UPDATE)\b\s*.+?)\b\s*(?:WHERE|ORDER|LIMIT|HAVING|SET|VALUES|\z)/is;

   die "Failed to parse table references from $query"
      unless $tbl_refs && $from;

   # The keyword that beings the table refs clause must be included so
   # that the first table will match. We could not include it and make
   # the before_tbl keywords match optionally, but then queries like:
   #    FROM t1 a JOIN t2 b ON a.col1=b.col2
   # will have col2 match as a tbl because no specific before_tbl keywords
   # were required so after matching 't2 b', Perl will ignore everything
   # until col2 which matches the 2nd line in the regex in foreach below.
   my $before_tbl = qr/(?:$from|,|JOIN|\s)+/;

   # These keywords signal the end of one table ref and the start of another,
   # or the start the ON|USING part of a JOIN clause (which we want to skip
   # over), or the end of the string (\z). We need these ending keywords so
   # that they are not mistaken as an implicit alias name for a preceding tbl.
   my $after_tbl  = qr/(?:,|JOIN|ON|USING|\z)/;

   # This is required for cases like:
   #    FROM t1 JOIN t2 ON t1.col1=t2.col2 JOIN t3 ON t2.col3 = t3.col4
   # Because spaces may precede a tbl and a tbl may end with \z, then
   # t3.col4 will match as a table. However, t2.col3=t3.col4 will not match.
   $tbl_refs =~ s/ = /=/g;

   MKDEBUG && _d("table refs: $tbl_refs");

   foreach my $tbl_ref (
      $tbl_refs =~ m{
         $before_tbl\b\s*
            ($tbl_ref_pattern (?:\s+ (?:AS\s+)?\w+)?)
         \s*$after_tbl
      }xgi)
   {
      push @tbl_refs, $tbl_ref;
      MKDEBUG && _d("tbl ref match: '$tbl_ref'");
   }
   return @tbl_refs;
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
