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
our $ident = qr/(?:`[^`]+`|\w+)(?:\s*\.\s*(?:`[^`]+`|\w+))?/; # db.tbl identifier

sub new {
   my ( $class ) = @_;
   bless {}, $class;
}

sub get_table_ref {
   my ( $self, $query ) = @_;
   return unless $query;
   my $table_ref;

   if ( $query =~ m/FROM\s+(.+?)\b(?:WHERE|ORDER|LIMIT|HAVING)+.+/is ) {
      $table_ref = $1;
   }
   elsif ( $query =~ m/FROM\s+(.+?);?$/is ) {
      # This handles queries like "SELECT COUNT(id) FROM table;"
      chomp($table_ref = $1);
   }

   MKDEBUG && _d($table_ref ? "table ref: $table_ref"
                            : "Failed to parse table ref");

   return $table_ref;
}

sub parse_table_aliases {
   my ( $self, $table_ref ) = @_;
   my $table_aliases = {};
   return $table_aliases if !defined $table_ref || !$table_ref;
   my @tables;

   $table_ref =~ s/\n/ /g;
   $table_ref =~ s/`//g; # Graves break database discovery

   if( $table_ref =~ m/ (:?straight_)?join /i ) {
      $table_ref =~ s/ join /,/ig;
      1 while ($table_ref =~ s/ (?:inner|outer|cross|left|right|natural),/,/ig);
      $table_ref =~ s/ using\s*\(.+?\)//ig;
      $table_ref =~ s/ on \([\w\s=.,]+\),?/,/ig;
      $table_ref =~ s/ on [\w\s=.]+,?/,/ig;
      $table_ref =~ s/ straight_join /,/ig;
   }

   @tables = split /,/, $table_ref;

   my @alias_patterns = (
      qr/\s*(\S+)\s+AS\s+(\S+)\s*/i,
      qr/^\s*(\S+)\s+(\S+)\s*$/,
      qr/^\s*(\S+)+\s*$/, # Not an alias but we save it anyway to be complete
   );

   TABLE:
   foreach my $table ( @tables ) {
      my ( $db_tbl, $alias );

      # Ignore "tables" that are really subqueries.
      if ( $table =~ m/\(\s*SELECT\s+/i ) {
         MKDEBUG && _d("Ignoring subquery table: $table");
         next TABLE;
      }

      ALIAS_PATTERN:
      foreach my $alias_pattern ( @alias_patterns ) {
         if ( ( $db_tbl, $alias ) = $table =~ m/$alias_pattern/ ) {
            MKDEBUG && _d("$table matches $alias_pattern");
            last ALIAS_PATTERN;
         }
      }

      if ( defined $db_tbl && $db_tbl ) {
         my ( $db, $tbl ) = $db_tbl =~ m/^(?:(\S+)\.)?(\S+)/;

         $table_aliases->{$alias || $tbl} = $tbl;
         $table_aliases->{DATABASE}->{$tbl} = $db if defined $db && $db;
      }
      elsif ( MKDEBUG ) {
         _d("Failed to parse table alias for $table");
      }
   }

   MKDEBUG && _d('table aliases: ' . Dumper($table_aliases));

   return $table_aliases;
}

# Returns an array of tables to which the query refers.
# XXX If you change this code, also change QueryRewriter::distill().
sub get_tables {
   my ( $self, $query ) = @_;
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
   return @tables;
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
