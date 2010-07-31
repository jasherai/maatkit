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
};

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
