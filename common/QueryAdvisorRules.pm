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
# QueryAdvisorRules package $Revision$
# ###########################################################################
package QueryAdvisorRules;
use base 'AdvisorRules';

use strict;
use warnings FATAL => 'all';
use English qw(-no_match_vars);
use constant MKDEBUG => $ENV{MKDEBUG} || 0;

sub new {
   my ( $class, %args ) = @_;
   my $self = $class->SUPER::new(%args);
   @{$self->{rules}} = $self->get_rules();
   MKDEBUG && _d(scalar @{$self->{rules}}, "rules");
   return $self;
}

# Each rules is a hashref with two keys:
#   * id       Unique PREFIX.NUMBER for the rule.  The prefix is three chars
#              which hints to the nature of the rule.  See example below.
#   * code     Coderef to check rule, returns undef if rule does not match,
#              else returns the string pos near where the rule matches or 0
#              to indicate it doesn't know the pos.  The code is passed a\
#              single arg: a hashref event.
sub get_rules {
   return
   {
      id   => 'ALI.001',      # Implicit alias
      code => sub {
         my ( %args ) = @_;
         my $event  = $args{event};
         my $struct = $event->{query_struct};
         my $tbls   = $struct->{from} || $struct->{into} || $struct->{tables};
         return unless $tbls;
         foreach my $tbl ( @$tbls ) {
            return 0 if $tbl->{alias} && !$tbl->{explicit_alias};
         }
         my $cols = $struct->{columns};
         return unless $cols;
         foreach my $col ( @$cols ) {
            return 0 if $col->{alias} && !$col->{explicit_alias};
         }
         return;
      },
   },
   {
      id   => 'ALI.002',      # tbl.* alias
      code => sub {
         my ( %args ) = @_;
         my $event = $args{event};
         my $cols  = $event->{query_struct}->{columns};
         return unless $cols;
         foreach my $col ( @$cols ) {
            return 0 if $col->{db} && $col->{name } eq '*' &&  $col->{alias};
         }
         return;
      },
   },
   {
      id   => 'ALI.003',      # tbl AS tbl
      code => sub {
         my ( %args ) = @_;
         my $event  = $args{event};
         my $struct = $event->{query_struct};
         my $tbls   = $struct->{from} || $struct->{into} || $struct->{tables};
         return unless $tbls;
         foreach my $tbl ( @$tbls ) {
            return 0 if $tbl->{alias} && $tbl->{alias} eq $tbl->{name};
         }
         my $cols = $struct->{columns};
         return unless $cols;
         foreach my $col ( @$cols ) {
            return 0 if $col->{alias} && $col->{alias} eq $col->{name};
         }
         return;
      },
   },
   {
      id   => 'ARG.001',      # col = '%foo'
      code => sub {
         my ( %args ) = @_;
         my $event = $args{event};
         return 0 if $event->{arg} =~ m/[\'\"][\%\_]./;
         return;
      },
   },
   {
      id   => 'ARG.002',      # LIKE w/o wildcard
      code => sub {
         my ( %args ) = @_;
         my $event = $args{event};        
         # TODO: this pattern doesn't handle spaces.
         my @like_args = $event->{arg} =~ m/\bLIKE\s+(\S+)/gi;
         foreach my $arg ( @like_args ) {
            return 0 if $arg !~ m/[%_]/;
         }
         return;
      },
   },
   {
      id   => 'CLA.001',      # SELECT w/o WHERE
      code => sub {
         my ( %args ) = @_;
         my $event = $args{event};
         return unless ($event->{query_struct}->{type} || '') eq 'select';
         return unless $event->{query_struct}->{from};
         return 0 unless $event->{query_struct}->{where};
         return;
      },
   },
   {
      id   => 'CLA.002',      # ORDER BY RAND()
      code => sub {
         my ( %args ) = @_;
         my $event   = $args{event};
         my $orderby = $event->{query_struct}->{order_by};
         return unless $orderby;
         foreach my $col ( @$orderby ) {
            return 0 if $col =~ m/RAND\([^\)]*\)/i;
         }
         return;
      },
   },
   {
      id   => 'CLA.003',      # LIMIT w/ OFFSET
      code => sub {
         my ( %args ) = @_;
         my $event = $args{event};
         return unless $event->{query_struct}->{limit};
         return unless defined $event->{query_struct}->{limit}->{offset};
         return 0;
      },
   },
   {
      id   => 'CLA.004',      # GROUP BY <number>
      code => sub {
         my ( %args ) = @_;
         my $event   = $args{event};
         my $groupby = $event->{query_struct}->{group_by};
         return unless $groupby;
         foreach my $col ( @{$groupby->{columns}} ) {
            return 0 if $col =~ m/^\d+\b/;
         }
         return;
      },
   },
   {
      id   => 'CLA.005',      # ORDER BY col where col=<constant>
      code => sub {
         my ( %args ) = @_;
         my $event   = $args{event};
         my $orderby = $event->{query_struct}->{order_by};
         return unless $orderby;
         my $where   = $event->{query_struct}->{where};
         return unless $where;
         my %orderby_col = map {
            my ($col) = lc $_;
            $col =~ s/\s+(?:asc|desc)$//;
            $col => 1;
         } @$orderby;
         foreach my $pred ( @$where ) {
            my $val = $pred->{value};
            next unless $val;
            return 0 if $val =~ m/^\d+$/ && $orderby_col{lc $pred->{column}};
         }
         return;
      },
   },
   {
      id   => 'COL.001',      # SELECT *
      code => sub {
         my ( %args ) = @_;
         my $event = $args{event};
         return unless ($event->{query_struct}->{type} || '') eq 'select';
         my $cols = $event->{query_struct}->{columns};
         return unless $cols;
         foreach my $col ( @$cols ) {
            return 0 if $col->{name} eq '*';
         }
         return;
      },
   },
   {
      id   => 'COL.002',      # INSERT w/o (cols) def
      code => sub {
         my ( %args ) = @_;
         my $event = $args{event};
         my $type  = $event->{query_struct}->{type} || '';
         return unless $type eq 'insert' || $type eq 'replace';
         return 0 unless $event->{query_struct}->{columns};
         return;
      },
   },
   {
      id   => 'LIT.001',      # IP as string
      code => sub {
         my ( %args ) = @_;
         my $event = $args{event};
         if ( $event->{arg} =~ m/['"]\d{1,3}\.\d{1,3}\.\d{1,3}\.\d{1,3}/gc ) {
            return (pos $event->{arg}) || 0;
         }
         return;
      },
   },
   {
      id   => 'LIT.002',      # Date not quoted
      code => sub {
         my ( %args ) = @_;
         my $event = $args{event};
         # YYYY-MM-DD
         if ( $event->{arg} =~ m/(?<!['"\w-])\d{4}-\d{1,2}-\d{1,2}\b/gc ) {
            return (pos $event->{arg}) || 0;
         }
         # YY-MM-DD
         if ( $event->{arg} =~ m/(?<!['"\w\d-])\d{2}-\d{1,2}-\d{1,2}\b/gc ) {
            return (pos $event->{arg}) || 0;
         }
         return;
      },
   },
   {
      id   => 'KWR.001',      # SQL_CALC_FOUND_ROWS
      code => sub {
         my ( %args ) = @_;
         my $event = $args{event};
         return 0 if $event->{query_struct}->{keywords}->{sql_calc_found_rows};
         return;
      },
   },
   {
      id   => 'JOI.001',      # comma and ansi joins
      code => sub {
         my ( %args ) = @_;
         my $event  = $args{event};
         my $struct = $event->{query_struct};
         my $tbls   = $struct->{from} || $struct->{into} || $struct->{tables};
         return unless $tbls;
         my $comma_join = 0;
         my $ansi_join  = 0;
         foreach my $tbl ( @$tbls ) {
            if ( $tbl->{join} ) {
               if ( $tbl->{join}->{ansi} ) {
                  $ansi_join = 1;
               }
               else {
                  $comma_join = 1;
               }
            }
            return 0 if $comma_join && $ansi_join;
         }
         return;
      },
   },
   {
      id   => 'RES.001',      # non-deterministic GROUP BY
      code => sub {
         my ( %args ) = @_;
         my $event = $args{event};
         return unless ($event->{query_struct}->{type} || '') eq 'select';
         my $groupby = $event->{query_struct}->{group_by};
         return unless $groupby;
         # Only check GROUP BY column names, not numbers.  GROUP BY number
         # is handled in CLA.004.
         my %groupby_col = map { $_ => 1 }
                           grep { m/^[^\d]+\b/ }
                           @{$groupby->{columns}};
         return unless scalar %groupby_col;
         my $cols = $event->{query_struct}->{columns};
         # All SELECT cols must be in GROUP BY cols clause.
         # E.g. select a, b, c from tbl group by a; -- non-deterministic
         foreach my $col ( @$cols ) {
            return 0 unless $groupby_col{ $col->{name} };
         }
         return;
      },
   },
   {
      id   => 'RES.002',      # non-deterministic LIMIT w/o ORDER BY
      code => sub {
         my ( %args ) = @_;
         my $event = $args{event};
         return unless $event->{query_struct}->{limit};
         # If query doesn't use tables then this check isn't applicable.
         return unless    $event->{query_struct}->{from}
                         || $event->{query_struct}->{into}
                         || $event->{query_struct}->{tables};
         return 0 unless $event->{query_struct}->{order_by};
         return;
      },
   },
   {
      id   => 'STA.001',      # != instead of <>
      code => sub {
         my ( %args ) = @_;
         my $event = $args{event};
         return 0 if $event->{arg} =~ m/!=/;
         return;
      },
   },
   {
      id   => 'SUB.001',      # IN(<subquery>)
      code => sub {
         my ( %args ) = @_;
         my $event = $args{event};
         if ( $event->{arg} =~ m/\bIN\s*\(\s*SELECT\b/gi ) {
            return pos $event->{arg};
         }
         return;
      },
   },
   {
      id   => 'JOI.002',      # table joined more than once, but not self-join
      code => sub {
         my ( %args ) = @_;
         my $event  = $args{event};
         my $struct = $event->{query_struct};
         return unless $struct;
         my $tbls   = $struct->{from} || $struct->{into} || $struct->{tables};
         return unless $tbls;
         my %tbl_cnt;
         my $n_tbls = scalar @$tbls;

         # To detect this rule we look for tables joined more than once
         # (if cnt > 1) and via both an ansi and comma join.  This captures
         # "t AS a JOIN t AS b a.foo=b.bar, t" but not the simple self-join
         # "t AS a JOIN t AS b a.foo=b.bar" or cases where a table is joined
         # to many other tables all via ansi joins or the implicit self-join
         # (which we really can't detect) "t AS a, t AS b WHERE a.foo=b.bar".
         # When a table shows up multiple times in ansi joins and then again
         # in a comma join, the comma join is usually culprit of this rule.
         for my $i ( 0..($n_tbls-1) ) {
            my $tbl      = $tbls->[$i];
            my $tbl_name = lc $tbl->{name};

            $tbl_cnt{$tbl_name}->{cnt}++;
            $tbl_cnt{$tbl_name}->{ansi_join}++
               if $tbl->{join} && $tbl->{join}->{ansi};
            $tbl_cnt{$tbl_name}->{comma_join}++
               if $tbl->{join} && !$tbl->{join}->{ansi};

            if ( $tbl_cnt{$tbl_name}->{cnt} > 1 ) {
               return 0
                  if    $tbl_cnt{$tbl_name}->{ansi_join}
                     && $tbl_cnt{$tbl_name}->{comma_join};
            }
         }
         return;
      },
   },
   {
      id   => 'JOI.003',  # OUTER JOIN converted to INNER JOIN
      code => sub {
         my ( %args ) = @_;
         my $event  = $args{event};
         my $struct = $event->{query_struct};
         return unless $struct;
         my $tbls   = $struct->{from} || $struct->{into} || $struct->{tables};
         return unless $tbls;
         my $where  = $struct->{where};
         return unless $where;

         # Good LEFT OUTER JOIN:
         #   select * from L left join R using(c) where L.a=5;
         # Converts to INNER JOIN when:
         #   select * from L left join R using(c) where L.a=5 and R.b=10;
         # To detect this condition we need to see if there's an OUTER
         # join then see if there's a column from the outer table in the
         # WHERE clause that is anything but "IS NULL".  So in the example
         # above, R.b=10 is this culprit.
         # http://code.google.com/p/maatkit/issues/detail?id=950
         my %outer_tbls = map { $_->{name} => 1 } get_outer_tables($tbls);
         MKDEBUG && _d("Outer tables:", keys %outer_tbls);
         return unless %outer_tbls;

         foreach my $pred ( @$where ) {
            next unless $pred->{column};  # skip constants like 1 in "WHERE 1"
            my ($tbl, $col) = split /\./, $pred->{column};
            if ( $tbl && $col && $outer_tbls{$tbl} ) {
               # Only outer_tbl.col IS NULL is permissible.
               if ( $pred->{operator} ne 'is' || $pred->{value} !~ m/null/i ) {
                  MKDEBUG && _d("Predicate prevents OUTER JOIN:",
                     map { $pred->{$_} } qw(column operator value));
                  return 0;
               }
            }
         }

         return;
      }
   },
   {
      id   => 'JOI.004',  # broken exclusion join
      code => sub {
         my ( %args ) = @_;
         my $event  = $args{event};
         my $struct = $event->{query_struct};
         return unless $struct;
         my $tbls   = $struct->{from} || $struct->{into} || $struct->{tables};
         return unless $tbls;
         my $where  = $struct->{where};
         return unless $where;

         # For joins like "a LEFT JOIN b ON foo=bar" we need table info
         # to determine to which tables foo and bar belong.  Table info
         # isn't needed if at least one column is table-qualified.
         my $dbh           = $args{dbh};
         my $db            = $args{database};
         my $tbl_structs   = $args{tbl_structs};
         my $have_tbl_info = ($dbh && $db) || $tbl_structs ? 1 : 0;

         my %outer_tbls;
         my %outer_tbl_join_cols;
         foreach my $outer_tbl ( get_outer_tables($tbls) ) {
            $outer_tbls{$outer_tbl->{name}} = 1;

            # For "L LEFT JOIN R" R is the outer table and since it follows
            # L its table struct will have the join struct with the join
            # condition.  But for "L RIGHT JOIN R" L is the outer table and
            # will not have the join struct because it precedes R.  This
            # is due to how parse_from() works.  So if the outer table doesn't
            # have the join struct, we need to get it from the inner table.
            my $join = $outer_tbl->{join};
            if ( !$join ) {
               my ($inner_tbl) = grep { 
                  exists $_->{join} 
                  && $_->{join}->{to} eq $outer_tbl->{name}
               } @$tbls;
               $join = $inner_tbl->{join}; 
               die "Cannot find join structure for $outer_tbl->{name}"
                  unless $join;
            }

            # Get the outer table columns used in the jon condition.
            if ( $join->{condition} eq 'using' ) {
               %outer_tbl_join_cols = map { $_ => 1 } @{$join->{columns}};
            }
            else {
               my $where = $join->{where};
               die "Join structure for ON condition has no where structure"
                  unless $where;
               my @join_cols;
               foreach my $pred ( @$where ) {
                  next unless $pred->{operator} eq '=';
                  # Assume all equality comparisons are like tbl1.col=tbl2.col.
                  # Thus join conditions like tbl1.col<tbl2.col aren't handled.
                  push @join_cols, $pred->{column}, $pred->{value};
               }
               MKDEBUG && _d("Join columns:", @join_cols);
               foreach my $join_col ( @join_cols ) {
                  my ($tbl, $col) = split /\./, $join_col;
                  if ( !$col ) {
                     $col = $tbl;
                     $tbl = determine_table_for_column(
                        %args,
                        column => $col,
                     );
                  }
                  if ( !$tbl ) {
                     MKDEBUG && _d("Cannot determine the table for join column",
                        $col);
                     return;
                  }
                  $outer_tbl_join_cols{$col} = 1 if $tbl eq $outer_tbl->{name};
               }
            }
         }
         MKDEBUG && _d("Outer table join columns:", keys %outer_tbl_join_cols);
         return unless keys %outer_tbl_join_cols;

         # Here's a problem query:
         #   select c from L left join R on L.a=R.b where L.a=5 and R.c is null
         # The problem is "R.c is null" will not allow one to determine if
         # a null row from the outer table is null due to not matching the
         # inner table or due to R.c actually having a null value.  So we
         # need to check every outer table column in the WHERE clause for
         # ones that are 1) not in the JOIN expression and 2) "IS NULL'.
         # http://code.google.com/p/maatkit/issues/detail?id=950
         foreach my $pred ( @$where ) {
            next unless $pred->{column};  # skip constants like 1 in "WHERE 1"
            my ($tbl, $col) = split /\./, $pred->{column};
            if ( !$col ) {
               # A col in the WHERE clause isn't table-qualified.  Try to
               # determine its table.  If we can, great, if not "return 0 if"
               # below will immediately fail because $tbl will be undef still.
               # That's ok; it just means this test tries as best it can and
               # gets skipped silently when we can't tbl-qualify cols.
               $col = $tbl;
               $tbl = determine_table_for_column(
                  %args,
                  column => $col,
               );
            }
            return 0 if                       # This rule matches if
               $tbl                           # we know the table and
               && $outer_tbls{$tbl}           # it's an outer table but
               && !$outer_tbl_join_cols{$col} # the col isn't in the join and
               && $pred->{operator} eq 'is'   # the col IS NULL
               && $pred->{value} =~ m/NULL/i;
         }

         return;  # rule does not match, as best as we can determine
      }
   },
};


# Sub: get_outer_tables
#   Get the outer tables in joins.
#
# Parameters:
#   $tbls - Arrayref of hashrefs with table info
#
# Returns:
#   Array of hashref to the outer tables
sub get_outer_tables {
   my ( $tbls ) = @_;
   return unless $tbls;
   my @outer_tbls;
   my $n_tbls = scalar @$tbls;
   for my $i( 0..($n_tbls-1) ) {
      my $tbl = $tbls->[$i];
      next unless $tbl->{join} && $tbl->{join}->{type} =~ m/left|right/i;
      push @outer_tbls,
         $tbl->{join}->{type} =~ m/left/i ? $tbl
                                          : $tbls->[$i - 1];
   }
   return @outer_tbls;
}


# Sub: determine_table_for_column
#   Determine which table a column belongs to.
#
# Parameters:
#   %args - Arguments
#
# Required Arguments:
#   column - column name, not quoted
#
# Optional Arguments:
#   dbh         - dbh used if a db and TableParser arg are also given
#   db          - database name used if a dbh and TableParser arg are also given
#   TableParser - <TableParser> object used if a dbh and db arg are also given
#   tbl_structs - arrayref of tbl_struct hashrefs returned by
#                 <TableParser::parse()>, used if no dbh, db and TableParser
#                 args are given
#
# Returns:
#   Table name, not quoted
sub determine_table_for_column {
   my ( %args ) = @_;
   my ($col, $dbh, $db, $tp, $tbl_structs)
      = @args{qw(column dbh db TableParser tbl_structs)};
   die "I need a column argument" unless $col;

   my $tbl;
   if ( $tbl_structs ) {
      foreach my $tbl_struct ( @{$tbl_structs} ) {
         if ( $tbl_struct->{is_col}->{$col} ) {
            $tbl = $tbl_struct->{name};
            last;
         }
      }
   }
   elsif ( $dbh && $db && $tp ) {
      # TODO
   }

   MKDEBUG && _d($col, "column belongs to table", $tbl);
   return $tbl;
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
# End QueryAdvisorRules package
# ###########################################################################
