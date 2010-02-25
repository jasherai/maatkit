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
# SQLParser package $Revision$
# ###########################################################################
package SQLParser;

use strict;
use warnings FATAL => 'all';
use English qw(-no_match_vars);

use Data::Dumper;
$Data::Dumper::Indent    = 1;
$Data::Dumper::Sortkeys  = 1;
$Data::Dumper::Quotekeys = 0;

use constant MKDEBUG => $ENV{MKDEBUG} || 0;

# Only these types of statements are parsed.
my $allowed_types = qr/(?:
    DELETE
   |INSERT
   |REPLACE
   |SELECT
   |TRUNCATE
   |UPDATE
)/xi;

sub new {
   my ( $class, %args ) = @_;
   my $self = {
   };
   return bless $self, $class;
}

# Parse the query and return a hashref struct of its parts (keywords,
# clauses, subqueries, etc.).  Only queries of $allowed_types are
# parsed.  The struct is roughly:
# 
#   * type       => '',     # one of $allowed_types
#   * clauses    => {},     # raw, unparsed text of clauses
#   * <clause>   => struct  # parsed clause struct, e.g. from => [<tables>]
#   * keywords   => {},     # LOW_PRIORITY, DISTINCT, SQL_CACHE, etc.
#   * functions  => {},     # MAX(), SUM(), NOW(), etc.
#   * subqueries => [],     # pointers to subquery structs
#
# It varies, of course, depending on the query.  If something is missing
# it means the query doesn't have that part.  E.g. TRUNCATE has no clauses
# or keywords, etc.  Each clause struct is different; see their respective
# parse_CLAUSE subs.
sub parse {
   my ( $self, $query ) = @_;
   return unless $query;

   # Flatten and clean query.
   $query = $self->clean_query($query);

   # Remove first word, should be the statement type.  The parse_TYPE subs
   # expect that this is already removed.
   my $type;
   if ( $query =~ s/^(\w+)\s+// ) {
      $type = lc $1;
      MKDEBUG && _d('Query type:', $type);
      if ( $type !~ m/$allowed_types/i ) {
         return;
      }
   }
   else {
      MKDEBUG && _d('No first word/type');
      return;
   }

   # Parse raw text parts from query.  The parse_TYPE subs only do half
   # the work: parsing raw text parts of clauses, tables, functions, etc.
   # Since these parts are invariant (e.g. a LIMIT clause is same for any
   # type of SQL statement) they are parsed later via other parse_CLAUSE
   # subs, instead of parsing them individually in each parse_TYPE sub.
   my $parse_func = "parse_$type";
   my $struct     = $self->$parse_func($query);
   if ( !$struct ) {
      MKDEBUG && _d($parse_func, 'failed to parse query');
      return;
   }
   $struct->{type} = $type;
   $self->_parse_clauses($struct);
   # TODO: parse functions

   MKDEBUG && _d('Query struct:', Dumper($struct));
   return $struct;
}

sub _parse_clauses {
   my ( $self, $struct ) = @_;
   # Parse raw text of clauses and functions.
   foreach my $clause ( keys %{$struct->{clauses}} ) {
      # Rename/remove clauses with space in their names, like ORDER BY.
      if ( $clause =~ m/ / ) {
         (my $clause_no_space = $clause) =~ s/ /_/g;
         $struct->{clauses}->{$clause_no_space} = $struct->{clauses}->{$clause};
         delete $struct->{clauses}->{$clause};
         $clause = $clause_no_space;
      }

      my $parse_func     = "parse_$clause";
      $struct->{$clause} = $self->$parse_func($struct->{clauses}->{$clause});

      if ( $clause eq 'select' ) {
         MKDEBUG && _d('Parsing subquery clauses');
         $self->_parse_clauses($struct->{select});
      }
   }
   return;
}

sub clean_query {
   my ( $self, $query ) = @_;
   return unless $query;

   # Whitespace and comments.
   $query =~ s/^\s*--.*$//gm;  # -- comments
   $query =~ s/\s+/ /g;        # extra spaces/flatten
   $query =~ s!/\*.*?\*/!!g;   # /* comments */
   $query =~ s/^\s+//;         # leading spaces
   $query =~ s/\s+$//;         # trailing spaces

   # Add spaces between important tokens to help the parse_* subs.
   $query =~ s/\b(VALUE(?:S)?)\(/$1 (/i;
   $query =~ s/\bON\(/on (/gi;
   $query =~ s/\bUSING\(/using (/gi;

   return $query;
}

sub parse_delete {
   my ( $self, $query ) = @_;
   if ( $query =~ s/FROM\s+// ) {
      my $keywords = qr/(LOW_PRIORITY|QUICK|IGNORE)/i;
      my $clauses  = qr/(FROM|WHERE|ORDER BY|LIMIT)/i;
      return $self->_parse_query($query, $keywords, 'from', $clauses);
   }
   else {
      die "DELETE without FROM: $query";
   }
}

sub parse_insert {
   my ( $self, $query ) = @_;
   return unless $query;
   my $struct = {};

   # Save, remove keywords.
   my $keywords   = qr/(LOW_PRIORITY|DELAYED|HIGH_PRIORITY|IGNORE)/i;
   1 while $query =~ s/$keywords\s+/$struct->{keywords}->{lc $1}=1, ''/gie;

   # Parse INTO clause.  Literal "INTO" is optional.
   if ( my @into = ($query =~ m/
            (?:INTO\s+)?            # INTO, optional
            (.+?)\s+                # table ref
            (\([^\)]+\)\s+)?        # column list, optional
            (VALUE.?|SET|SELECT)\s+ # start of next caluse
         /xgci)
   ) {
      my $tbl  = shift @into;  # table ref
      $struct->{clauses}->{into} = $tbl;
      MKDEBUG && _d('Clause: into', $tbl);

      my $cols = shift @into;  # columns, maybe
      if ( $cols ) {
         $cols =~ s/[\(\)]//g;
         $struct->{clauses}->{columns} = $cols;
         MKDEBUG && _d('Clause: columns', $cols);
      }

      my $next_clause = lc(shift @into);  # VALUES, SET or SELECT
      die "INSERT/REPLACE without clause after table: $query"
         unless $next_clause;
      $next_clause = 'values' if $next_clause eq 'value';
      my ($values, $on) = ($query =~ m/\G(.+?)(ON|\Z)/gci);
      die "INSERT/REPLACE without values: $query" unless $values;
      $struct->{clauses}->{$next_clause} = $values;
      MKDEBUG && _d('Clause:', $next_clause, $values);

      # TODO: INSERT ... SELECT

      if ( $on ) {
         ($values) = ($query =~ m/ON DUPLICATE KEY UPDATE (.+)/i);
         die "No values after ON DUPLICATE KEY UPDATE: $query" unless $values;
         $struct->{clauses}->{on_duplicate} = $values;
         MKDEBUG && _d('Clause: on duplicate key update', $values);
      }
   }

   # Save any leftovers.  If there are any, parsing missed something.
   ($struct->{unknown}) = ($query =~ m/\G(.+)/);

   return $struct;
}

{
   # Suppress warnings like "Name "SQLParser::parse_set" used only once:
   # possible typo at SQLParser.pm line 480." caused by the fact that we
   # don't call these aliases directly, they're called indirectly using
   # $parse_func, hence Perl can't see their being called a compile time.
   no warnings;
   # INSERT and REPLACE are so similar that they are both parsed
   # in parse_insert().
   *parse_replace = \&parse_insert;
}

sub _parse_query {
   my ( $self, $query, $keywords, $first_clause, $clauses ) = @_;
   return unless $query;
   my $struct = {};

   # Save, remove keywords.
   1 while $query =~ s/$keywords\s+/$struct->{keywords}->{lc $1}=1, ''/gie;

   # Go clausing.
   my @clause = grep { defined $_ }
      ($query =~ m/\G(.+?)(?:$clauses\s+|\Z)/gci);

   my $clause = $first_clause,
   my $value  = shift @clause;
   $struct->{clauses}->{$clause} = $value;
   MKDEBUG && _d('Clause:', $clause, $value);

   # All other clauses.
   while ( @clause ) {
      $clause = shift @clause;
      $value  = shift @clause;
      $struct->{clauses}->{lc $clause} = $value;
      MKDEBUG && _d('Clause:', $clause, $value);
   }

   ($struct->{unknown}) = ($query =~ m/\G(.+)/);

   return $struct;
}

sub parse_select {
   my $keywords = qr/(
       ALL
      |DISTINCT
      |DISTINCTROW
      |HIGH_PRIORITY
      |STRAIGHT_JOIN
      |SQL_SMALL_RESULT
      |SQL_BIG_RESULT
      |SQL_BUFFER_RESULT
      |SQL_CACHE
      |SQL_NO_CACHE
      |SQL_CALC_FOUND_ROWS
      |FOR\sUPDATE
      |LOCK\sIN\sSHARE\sMODE
   )/xi;
   my $clauses = qr/(
       FROM
      |WHERE
      |GROUP\sBY
      |HAVING
      |ORDER\sBY
      |LIMIT
      |PROCEDURE
      |INTO OUTFILE
   )/xi;
   return _parse_query(@_, $keywords, 'columns', $clauses);
}

sub parse_update {
   my $keywords = qr/(LOW_PRIORITY|IGNORE)/i;
   my $clauses  = qr/(SET|WHERE|ORDER BY|LIMIT)/i;
   return _parse_query(@_, $keywords, 'tables', $clauses);

}

# Parse a FROM clause, a.k.a. the table references.  Returns an arrayref
# of hashrefs, one hashref for each table.  Each hashref is like:
#
#   {
#     name           => 't2',  -- this table's real name
#     alias          => 'b',   -- table's alias, if any
#     explicit_alias => 1,     -- if explicitly aliased with AS
#     join  => {               -- if joined to another table, all but first
#                              -- table are because comma implies INNER JOIN
#       to         => 't1',    -- table name on left side of join  
#       type       => '',      -- right, right, inner, outer, cross, natural
#       condition  => 'using', -- on or using, if applicable
#       predicates => '(id) ', -- stuff after on or using, if applicable
#       ansi       => 1,       -- true of ANSI JOIN, i.e. true if not implicit
#     },                       -- INNER JOIN due to follow a comma
#   },
#
# Tables are listed in the order that they appear.  Currently, subqueries
# and nested joins are not handled.
sub parse_from {
   my ( $self, $from ) = @_;
   return unless $from;
   MKDEBUG && _d('FROM clause:', $from);

   # This method tokenize the FROM clause into "things".  Each thing
   # is one of either a:
   #   * table ref, including alias
   #   * JOIN syntax word
   #   * ON or USING (condition)
   #   * ON|USING predicates text
   # So it is not word-by-word; it's thing-by-thing in one pass.
   # Currently, the ON|USING predicates are not parsed further.

   my @tbls;  # All parsed tables.
   my $tbl;   # This gets pushed to @tbls when it's set.  It may not be
              # all the time if, for example, $pending_tbl is being built.

   # These vars are used when parsing an explicit/ANSI JOIN statement.
   my $pending_tbl;         
   my $state      = undef;  
   my $join       = '';  # JOIN syntax words, without JOIN; becomes type
   my $joinno     = 0;   # join number for debugging
   my $redo       = 0;   # save $pending_tbl, redo loop for new JOIN

   # These vars help detect "comma joins", e.g. "tbl1, tbl2", which are
   # treated by MySQL as implicit INNER JOIN.  See below.
   my $join_back  = 0;
   my $last_thing = '';

   my $join_delim
      = qr/,|INNER|CROSS|STRAIGHT_JOIN|LEFT|RIGHT|OUTER|NATURAL|JOIN|ON|USING/i;
   my $next_tbl
      = qr/,|INNER|CROSS|STRAIGHT_JOIN|LEFT|RIGHT|OUTER|NATURAL|JOIN/i;

   foreach my $thing ( split(/\s*($join_delim)\s+/io, $from) ) {
      next unless $thing;
      MKDEBUG && _d('Table thing:', $thing, 'state:', $state); 

      if ( !$state && $thing !~ m/$join_delim/i ) {
         MKDEBUG && _d('Table factor');
         $tbl = { $self->_parse_tbl_ref($thing) };
         
         # Non-ANSI implicit INNER join to previous table, e.g. "tbl1, tbl2".
         # Manual says: "INNER JOIN and , (comma) are semantically equivalent
         # in the absence of a join condition".
         $join_back = 1 if ($last_thing || '') eq ',';
      }
      else {
         # Should be starting or continuing an explicit JOIN.
         if ( !$state ) {
            $joinno++;
            MKDEBUG && _d('JOIN', $joinno, 'start');
            $join .= ' ' . lc $thing;
            if ( $join =~ m/join$/ ) {
               $join =~ s/ join$//;
               $join =~ s/^\s+//;
               MKDEBUG && _d('JOIN', $joinno, 'type:', $join);
               my $last_tbl = $tbls[-1];
               die "Invalid syntax: $from\n"
                  . "JOIN without preceding table reference" unless $last_tbl;
               $pending_tbl->{join} = {
                  to   => $last_tbl->{name},
                  type => $join,
                  ansi => 1,
               };
               $join    = '';
               $state   = 'join tbl';
            }
         }
         elsif ( $state eq 'join tbl' ) {
            # Table for this join (i.e. tbl to right of JOIN).
            my %tbl_ref = $self->_parse_tbl_ref($thing);
            @{$pending_tbl}{keys %tbl_ref} = values %tbl_ref;
            $state = 'join condition';
         }
         elsif ( $state eq 'join condition' ) {
            if ( $thing =~ m/$next_tbl/io ) {
               MKDEBUG && _d('JOIN', $joinno, 'end');
               $tbl  = $pending_tbl;
               $redo = 1;  # save $pending_tbl then redo this new JOIN
            }
            elsif ( $thing =~ m/ON|USING/i ) {
               MKDEBUG && _d('JOIN', $joinno, 'codition');
               $pending_tbl->{join}->{condition} = lc $thing;
            }
            else {
               MKDEBUG && _d('JOIN', $joinno, 'predicate');
               $pending_tbl->{join}->{predicates} .= "$thing ";
            }
         }
         else {
            die "Unknown state '$state' parsing JOIN syntax: $from";
         }
      }

      $last_thing = $thing;

      if ( $tbl ) {
         if ( $join_back ) {
            my $prev_tbl = $tbls[-1];
            if ( $tbl->{join} ) {
               die "Cannot implicitly join $tbl->{name} to $prev_tbl->{name} "
                  . "because it is already joined to $tbl->{join}->{to}";
            }
            $tbl->{join} = {
               to   => $prev_tbl->{name},
               type => 'inner',
               ansi => 0,
            }
         }
         push @tbls, $tbl;
         $tbl         = undef;
         $state       = undef;
         $pending_tbl = undef;
         $join        = '';
         $join_back   = 0;
      }
      else {
         MKDEBUG && _d('Table pending:', Dumper($pending_tbl));
      }
      if ( $redo ) {
         MKDEBUG && _d("Redoing this thing");
         $redo = 0;
         redo;
      }
   }

   # Save the final JOIN which was end by the end of the FROM clause
   # rather than by the start of a new JOIN.
   if ( $pending_tbl ) {
      push @tbls, $pending_tbl;
   }

   MKDEBUG && _d('Parsed tables:', Dumper(\@tbls));
   return \@tbls;
}

# Parse a table ref like "tbl", "tbl alias" or "tbl AS alias".
sub _parse_tbl_ref {
   my ( $self, $tbl_ref ) = @_;
   my @words = $tbl_ref =~ m/(\S+)/g;
   MKDEBUG && _d('Table ref:', @words);
   my %tbl = (
      name => $words[0]
   );
   if ( $words[2] ) {
      $tbl{alias}          = $words[2];
      $tbl{explicit_alias} = 1;
   }
   elsif ( $words[1] ) {
      $tbl{alias} = $words[1];
   }
   return %tbl;
}
{
   no warnings;  # Why? See same line above.
   *parse_into   = \&parse_from;
   *parse_tables = \&parse_from;
}

sub parse_where {
   my ( $self, $where ) = @_;
   # TODO
   return $where;
}

sub parse_having {
   my ( $self, $having ) = @_;
   # TODO
   return $having;
}

# [ORDER BY {col_name | expr | position} [ASC | DESC], ...]
sub parse_order_by {
   my ( $self, $order_by ) = @_;
   return unless $order_by;
   MKDEBUG && _d('Parse ORDER BY', $order_by);
   # They don't have to be cols, they can be expressions or positions;
   # we call them all cols for simplicity.
   my @cols = map { s/^\s+//; s/\s+$//; $_ } split(',', $order_by);
   return \@cols;
}

# [LIMIT {[offset,] row_count | row_count OFFSET offset}]
sub parse_limit {
   my ( $self, $limit ) = @_;
   return unless $limit;
   my $struct = {
      row_count => undef,
   };
   if ( $limit =~ m/(\S+)\s+OFFSET\s+(\S+)/i ) {
      $struct->{explicit_offset} = 1;
      $struct->{row_count}       = $1;
      $struct->{offset}          = $2;
   }
   else {
      my ($offset, $cnt) = $limit =~ m/(?:(\S+),\s+)?(\S+)/i;
      $struct->{row_count} = $cnt;
      $struct->{offset}    = $offset if defined $offset;
   }
   return $struct;
}

sub parse_values {
   my ( $self, $values ) = @_;
   return unless $values;
   my @vals = ($values =~ m/\([^\)]+\)/g);
   return \@vals;
}

sub parse_csv {
   my ( $self, $vals ) = @_;
   return unless $vals;
   my @vals = map { s/^\s+//; s/\s+$//; $_ } split(',', $vals);
   return \@vals;
}
{
   no warnings;  # Why? See same line above.
   *parse_columns      = \&parse_csv;
   *parse_set          = \&parse_csv;
   *parse_on_duplicate = \&parse_csv;
}

# GROUP BY {col_name | expr | position} [ASC | DESC], ... [WITH ROLLUP]
sub parse_group_by {
   my ( $self, $group_by ) = @_;
   my $with_rollup = $group_by =~ s/\s+WITH ROLLUP\s*//i;
   my $struct = {
      columns => $self->parse_csv($group_by),
   };
   $struct->{with_rollup} = 1 if $with_rollup;
   return $struct;
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
