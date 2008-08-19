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
# TableParser package $Revision$
# ###########################################################################
use strict;
use warnings FATAL => 'all';

package TableParser;

use English qw(-no_match_vars);

use constant MKDEBUG => $ENV{MKDEBUG};

sub new {
   bless {}, shift;
}

# $ddl:  the output of SHOW CREATE TABLE
# $opts: hashref of options
#        mysql_version: MySQL version, zero-padded so 4.1.0 => 004001000
sub parse {
   my ( $self, $ddl, $opts ) = @_;

   if ( ref $ddl eq 'ARRAY' ) {
      if ( lc $ddl->[0] eq 'table' ) {
         $ddl = $ddl->[1];
      }
      else {
         return {
            engine => 'VIEW',
         };
      }
   }

   if ( $ddl !~ m/CREATE (?:TEMPORARY )?TABLE `/ ) {
      die "Cannot parse table definition; is ANSI quoting "
         . "enabled or SQL_QUOTE_SHOW_CREATE disabled?";
   }

   # Lowercase identifiers to avoid issues with case-sensitivity in Perl.
   # (Bug #1910276).
   $ddl =~ s/(`[^`]+`)/\L$1/g;

   my ( $engine ) = $ddl =~ m/\).*?(?:ENGINE|TYPE)=(\w+)/;
   MKDEBUG && _d('Storage engine: ', $engine);

   my @defs = $ddl =~ m/^(\s+`.*?),?$/gm;
   my @cols = map { $_ =~ m/`([^`]+)`/g } @defs;
   MKDEBUG && _d('Columns: ' . join(', ', @cols));

   # Save the column definitions *exactly*
   my %def_for;
   @def_for{@cols} = @defs;

   # Find column types, whether numeric, whether nullable, whether
   # auto-increment.
   my (@nums, @null);
   my (%type_for, %is_nullable, %is_numeric, %is_autoinc);
   foreach my $col ( @cols ) {
      my $def = $def_for{$col};
      my ( $type ) = $def =~ m/`[^`]+`\s([a-z]+)/;
      die "Can't determine column type for $def" unless $type;
      $type_for{$col} = $type;
      if ( $type =~ m/(?:(?:tiny|big|medium|small)?int|float|double|decimal|year)/ ) {
         push @nums, $col;
         $is_numeric{$col} = 1;
      }
      if ( $def !~ m/NOT NULL/ ) {
         push @null, $col;
         $is_nullable{$col} = 1;
      }
      $is_autoinc{$col} = $def =~ m/AUTO_INCREMENT/i ? 1 : 0;
   }

   my %keys;
   foreach my $key ( $ddl =~ m/^  ((?:[A-Z]+ )?KEY .*)$/gm ) {

      # Make allowances for HASH bugs in SHOW CREATE TABLE.  A non-MEMORY table
      # will report its index as USING HASH even when this is not supported.
      # The true type should be BTREE.  See
      # http://bugs.mysql.com/bug.php?id=22632
      if ( $engine !~ m/MEMORY|HEAP/ ) {
         $key =~ s/USING HASH/USING BTREE/;
      }

      # Determine index type
      my ( $type, $cols ) = $key =~ m/(?:USING (\w+))? \((.+)\)/;
      my ( $special ) = $key =~ m/(FULLTEXT|SPATIAL)/;
      $type = $type || $special || 'BTREE';
      if ( $opts->{mysql_version} && $opts->{mysql_version} lt '004001000'
         && $engine =~ m/HEAP|MEMORY/i )
      {
         $type = 'HASH'; # MySQL pre-4.1 supports only HASH indexes on HEAP
      }

      my ($name) = $key =~ m/(PRIMARY|`[^`]*`)/;
      my $unique = $key =~ m/PRIMARY|UNIQUE/ ? 1 : 0;
      my @cols;
      my @col_prefixes;
      foreach my $col_def ( split(',', $cols) ) {
         # Parse columns of index including potential column prefixes
         # E.g.: `a`,`b`(20)
         my ($name, $prefix) = $col_def =~ m/`(\w+)`(?:\((\d+)\))?/;
         push @cols, $name;
         push @col_prefixes, $prefix;
      }
      $name =~ s/`//g;
      MKDEBUG && _d("Index $name columns: " . join(', ', @cols));

      $keys{$name} = {
         colnames     => $cols,
         cols         => \@cols,
         col_prefixes => \@col_prefixes,
         unique       => $unique,
         is_col       => { map { $_ => 1 } @cols },
         is_nullable  => scalar(grep { $is_nullable{$_} } @cols),
         type         => $type,
         name         => $name,
      };
   }

   return {
      cols           => \@cols,
      col_posn       => { map { $cols[$_] => $_ } 0..$#cols },
      is_col         => { map { $_ => 1 } @cols },
      null_cols      => \@null,
      is_nullable    => \%is_nullable,
      is_autoinc     => \%is_autoinc,
      keys           => \%keys,
      defs           => \%def_for,
      numeric_cols   => \@nums,
      is_numeric     => \%is_numeric,
      engine         => $engine,
      type_for       => \%type_for,
   };
}

# Sorts indexes in this order: PRIMARY, unique, non-nullable, any (shortest
# first, alphabetical).  Only BTREE indexes are considered.  TODO: consider
# length as # of bytes instead of # of columns.
sub sort_indexes {
   my ( $self, $tbl ) = @_;
   my @indexes
      = sort {
         (($a ne 'PRIMARY') <=> ($b ne 'PRIMARY'))
         || ( !$tbl->{keys}->{$a}->{unique} <=> !$tbl->{keys}->{$b}->{unique} )
         || ( $tbl->{keys}->{$a}->{is_nullable} <=> $tbl->{keys}->{$b}->{is_nullable} )
         || ( scalar(@{$tbl->{keys}->{$a}->{cols}}) <=> scalar(@{$tbl->{keys}->{$b}->{cols}}) )
      }
      grep {
         $tbl->{keys}->{$_}->{type} eq 'BTREE'
      }
      sort keys %{$tbl->{keys}};
   MKDEBUG && _d('Indexes sorted best-first: ' . join(', ', @indexes));
   return @indexes;
}

# Finds the 'best' index; if the user specifies one, dies if it's not in the
# table.
sub find_best_index {
   my ( $self, $tbl, $index ) = @_;
   my $best;
   if ( $index ) {
      ($best) = grep { uc $_ eq uc $index } keys %{$tbl->{keys}};
   }
   if ( !$best ) {
      if ( $index ) {
         # The user specified an index, so we can't choose our own.
         die "Index '$index' does not exist in table";
      }
      else {
         # Try to pick the best index.  TODO: eliminate indexes that have column
         # prefixes.
         ($best) = $self->sort_indexes($tbl);
      }
   }
   MKDEBUG && _d("Best index found is " . ($best || 'undef'));
   return $best;
}

# Takes a dbh, database, table, quoter, and WHERE clause, and reports the
# indexes MySQL thinks are best for EXPLAIN SELECT * FROM that table.  If no
# WHERE, just returns an empty list.  If no possible_keys, returns empty list,
# even if 'key' is not null.  Only adds 'key' to the list if it's included in
# possible_keys.
sub find_possible_keys {
   my ( $self, $dbh, $database, $table, $quoter, $where ) = @_;
   return () unless $where;
   my $sql = 'EXPLAIN SELECT * FROM ' . $quoter->quote($database, $table)
      . ' WHERE ' . $where;
   MKDEBUG && _d($sql);
   my $expl = $dbh->selectrow_hashref($sql);
   # Normalize columns to lowercase
   $expl = { map { lc($_) => $expl->{$_} } keys %$expl };
   if ( $expl->{possible_keys} ) {
      MKDEBUG && _d("possible_keys=$expl->{possible_keys}");
      my @candidates = split(',', $expl->{possible_keys});
      my %possible   = map { $_ => 1 } @candidates;
      if ( $expl->{key} ) {
         MKDEBUG && _d("MySQL chose $expl->{key}");
         unshift @candidates, grep { $possible{$_} } split(',', $expl->{key});
         MKDEBUG && _d('Before deduping: ' . join(', ', @candidates));
         my %seen;
         @candidates = grep { !$seen{$_}++ } @candidates;
      }
      MKDEBUG && _d('Final list: ' . join(', ', @candidates));
      return @candidates;
   }
   else {
      MKDEBUG && _d('No keys in possible_keys');
      return ();
   }
}

sub _d {
   my ( $line ) = (caller(0))[2];
   print "# TableParser:$line $PID ", @_, "\n";
}

1;

# ###########################################################################
# End TableParser package
# ###########################################################################
