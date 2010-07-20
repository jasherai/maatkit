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

use strict;
use warnings FATAL => 'all';
use English qw(-no_match_vars);

use Data::Dumper;
$Data::Dumper::Indent    = 1;
$Data::Dumper::Sortkeys  = 1;
$Data::Dumper::Quotekeys = 0;

use constant MKDEBUG => $ENV{MKDEBUG} || 0;

sub new {
   my ( $class, %args ) = @_;
   foreach my $arg ( qw(PodParser) ) {
      die "I need a $arg argument" unless $args{$arg};
   }

   my @rules = get_rules();
   MKDEBUG && _d(scalar @rules, 'rules');

   my $self = {
      %args,
      rules     => \@rules,
      rule_info => {},
   };

   return bless $self, $class;
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
         my ( $event ) = @_;
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
         my ( $event ) = @_;
         my $cols = $event->{query_struct}->{columns};
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
         my ( $event ) = @_;
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
         my ( $event ) = @_;
         return 0 if $event->{arg} =~ m/[\'\"][\%\_]./;
         return;
      },
   },
   {
      id   => 'ARG.002',      # LIKE w/o wildcard
      code => sub {
         my ( $event ) = @_;
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
         my ( $event ) = @_;
         return unless ($event->{query_struct}->{type} || '') eq 'select';
         return unless $event->{query_struct}->{from};
         return 0 unless $event->{query_struct}->{where};
         return;
      },
   },
   {
      id   => 'CLA.002',      # ORDER BY RAND()
      code => sub {
         my ( $event ) = @_;
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
         my ( $event ) = @_;
         return unless $event->{query_struct}->{limit};
         return unless defined $event->{query_struct}->{limit}->{offset};
         return 0;
      },
   },
   {
      id   => 'CLA.004',      # GROUP BY <number>
      code => sub {
         my ( $event ) = @_;
         my $groupby = $event->{query_struct}->{group_by};
         return unless $groupby;
         foreach my $col ( @{$groupby->{columns}} ) {
            return 0 if $col =~ m/^\d+\b/;
         }
         return;
      },
   },
   {
      id   => 'COL.001',      # SELECT *
      code => sub {
         my ( $event ) = @_;
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
         my ( $event ) = @_;
         my $type = $event->{query_struct}->{type} || '';
         return unless $type eq 'insert' || $type eq 'replace';
         return 0 unless $event->{query_struct}->{columns};
         return;
      },
   },
   {
      id   => 'LIT.001',      # IP as string
      code => sub {
         my ( $event ) = @_;
         if ( $event->{arg} =~ m/['"]\d{1,3}\.\d{1,3}\.\d{1,3}\.\d{1,3}/gc ) {
            return (pos $event->{arg}) || 0;
         }
         return;
      },
   },
   {
      id   => 'LIT.002',      # Date not quoted
      code => sub {
         my ( $event ) = @_;
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
         my ( $event ) = @_;
         return 0 if $event->{query_struct}->{keywords}->{sql_calc_found_rows};
         return;
      },
   },
   {
      id   => 'JOI.001',      # comma and ansi joins
      code => sub {
         my ( $event ) = @_;
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
         my ( $event ) = @_;
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
         my ( $event ) = @_;
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
         my ( $event ) = @_;
         return 0 if $event->{arg} =~ m/!=/;
         return;
      },
   },
   {
      id   => 'SUB.001',      # IN(<subquery>)
      code => sub {
         my ( $event ) = @_;
         if ( $event->{arg} =~ m/\bIN\s*\(\s*SELECT\b/gi ) {
            return pos $event->{arg};
         }
         return;
      },
   },
   {
      id   => 'JOI.002',      # table joined more than once, but not self-join
      code => sub {
         my ( $event ) = @_;
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

# Arguments:
#   * file     scalar: file name with POD to parse rules from
#   * section  scalar: section name for rule items, should be RULES
#   * rules    arrayref: optional list of rules to load info for
# Parses rules from the POD section/subsection in file, adding rule
# info found therein to %rule_info.  Then checks that rule info
# was gotten for all the required rules.
sub load_rule_info {
   my ( $self, %args ) = @_;
   foreach my $arg ( qw(file section ) ) {
      die "I need a $arg argument" unless $args{$arg};
   }
   my $rules = $args{rules} || $self->{rules};
   my $p     = $self->{PodParser};

   # Parse rules and their info from the file's POD, saving
   # values to %rule_info.
   $p->parse_from_file($args{file});
   my $rule_items = $p->get_items($args{section});
   my %seen;
   foreach my $rule_id ( keys %$rule_items ) {
      my $rule = $rule_items->{$rule_id};
      die "Rule $rule_id has no description" unless $rule->{desc};
      die "Rule $rule_id has no severity"    unless $rule->{severity};
      die "Rule $rule_id is already defined"
         if exists $self->{rule_info}->{$rule_id};
      $self->{rule_info}->{$rule_id} = {
         id          => $rule_id,
         severity    => $rule->{severity},
         description => $rule->{desc},
      };
   }

   # Check that rule info was gotten for each requested rule.
   foreach my $rule ( @$rules ) {
      die "There is no info for rule $rule->{id} in $args{file}"
         unless $self->{rule_info}->{ $rule->{id} };
   }

   return;
}

sub get_rule_info {
   my ( $self, $id ) = @_;
   return unless $id;
   return $self->{rule_info}->{$id};
}

# Used for testing.
sub _reset_rule_info {
   my ( $self ) = @_;
   $self->{rule_info} = {};
   return;
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
