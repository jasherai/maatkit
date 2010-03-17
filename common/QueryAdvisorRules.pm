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
      rules          => \@rules,
      rule_index_for => {},
      rule_info      => {},
   };

   my $i = 0;
   map { $self->{rule_index_for}->{ $_->{id} } = $i++ } @rules;

   return bless $self, $class;
}

# Each rules is a hashref with two keys:
#   * id       Unique PREFIX.NUMBER for the rule.  The prefix is three chars
#              which hints to the nature of the rule.  See example below.
#   * code     Coderef to check rule, returns true if rule matches, else
#              returns false.  The code is passed a single arg: a hashref
#              event.
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
            return 1 if $tbl->{alias} && !$tbl->{explicit_alias};
         }
         my $cols = $struct->{columns};
         return unless $cols;
         foreach my $col ( @$cols ) {
            return 1 if $col->{alias} && !$col->{explicit_alias};
         }
         return 0;
      },
   },
   {
      id   => 'ALI.002',      # tbl.* alias
      code => sub {
         my ( $event ) = @_;
         my $cols = $event->{query_struct}->{columns};
         return unless $cols;
         foreach my $col ( @$cols ) {
            return 1 if $col->{db} && $col->{name } eq '*' &&  $col->{alias};
         }
         return 0;
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
            return 1 if $tbl->{alias} && $tbl->{alias} eq $tbl->{name};
         }
         my $cols = $struct->{columns};
         return unless $cols;
         foreach my $col ( @$cols ) {
            return 1 if $col->{alias} && $col->{alias} eq $col->{name};
         }
         return 0;
      },
   },
   {
      id   => 'ARG.001',      # col = '%foo'
      code => sub {
         my ( $event ) = @_;
         return 1 if $event->{arg} =~ m/[\'\"][\%\_]./;
         return 0;
      },
   },
   {
      id   => 'ARG.002',      # LIKE w/o wildcard
      code => sub {
         my ( $event ) = @_;
         return 0;
      },
   },
   {
      id   => 'CLA.001',      # SELECT w/o WHERE
      code => sub {
         my ( $event ) = @_;
         return 0 unless ($event->{query_struct}->{type} || '') eq 'select';
         return 0 unless $event->{query_struct}->{from};
         return 1 unless $event->{query_struct}->{where};
         return 0;
      },
   },
   {
      id   => 'CLA.002',      # ORDER BY RAND()
      code => sub {
         my ( $event ) = @_;
         my $orderby = $event->{query_struct}->{order_by};
         return unless $orderby;
         foreach my $col ( @$orderby ) {
            return 1 if $col =~ m/RAND\([^\)]*\)/i;
         }
         return 0;
      },
   },
   {
      id   => 'CLA.003',      # LIMIT w/ OFFSET
      code => sub {
         my ( $event ) = @_;
         return 0 unless $event->{query_struct}->{limit};
         return 0 unless defined $event->{query_struct}->{limit}->{offset};
         return 1;
      },
   },
   {
      id   => 'CLA.004',      # GROUP BY <number>
      code => sub {
         my ( $event ) = @_;
         my $groupby = $event->{query_struct}->{group_by};
         return unless $groupby;
         foreach my $col ( @{$groupby->{columns}} ) {
            return 1 if $col =~ m/^\d+\b/;
         }
         return 0;
      },
   },
   {
      id   => 'COL.001',      # SELECT *
      code => sub {
         my ( $event ) = @_;
         return 0 unless ($event->{query_struct}->{type} || '') eq 'select';
         my $cols = $event->{query_struct}->{columns};
         return unless $cols;
         foreach my $col ( @$cols ) {
            return 1 if $col->{name} eq '*';
         }
         return 0;
      },
   },
   {
      id   => 'COL.002',      # INSERT w/o (cols) def
      code => sub {
         my ( $event ) = @_;
         my $type = $event->{query_struct}->{type} || '';
         return 0 unless $type eq 'insert' || $type eq 'replace';
         return 1 unless $event->{query_struct}->{columns};
         return 0;
      },
   },
   {
      id   => 'LIT.001',      # IP as string
      code => sub {
         my ( $event ) = @_;
         return $event->{arg} =~ m/['"]\d{1,3}\.\d{1,3}\.\d{1,3}\.\d{1,3}/;
      },
   },
   {
      id   => 'LIT.002',      # Date not quoted
      code => sub {
         my ( $event ) = @_;
         # YYYY-MM-DD
         return 1 if $event->{arg} =~ m/(?<!['"])\d{4}-\d{1,2}-\d{1,2}\b/;
         # YY-MM-DD
         return 1 if $event->{arg} =~ m/(?<!['"\d])\d{2}-\d{1,2}-\d{1,2}\b/;
         return 0;
      },
   },
   {
      id   => 'KWR.001',      # SQL_CALC_FOUND_ROWS
      code => sub {
         my ( $event ) = @_;
         return 1 if $event->{query_struct}->{keywords}->{sql_calc_found_rows};
         return 0;
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
            return 1 if $comma_join && $ansi_join;
         }
         return 0;
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
            return 1 unless $groupby_col{ $col->{name} };
         }
         return 0;
      },
   },
   {
      id   => 'RES.002',      # non-deterministic LIMIT w/o ORDER BY
      code => sub {
         my ( $event ) = @_;
         return 0 unless $event->{query_struct}->{limit};
         # If query doesn't use tables then this check isn't applicable.
         return 0 unless    $event->{query_struct}->{from}
                         || $event->{query_struct}->{into}
                         || $event->{query_struct}->{tables};
         return 1 unless $event->{query_struct}->{order_by};
         return 0;
      },
   },
   {
      id   => 'STA.001',      # != instead of <>
      code => sub {
         my ( $event ) = @_;
         return 1 if $event->{arg} =~ m/!=/;
         return 0;
      },
   },
};

# Arguments:
#   * rules      arrayref: rules for which info is required
#   * file       scalar: file name with POD to parse rules from
#   * section    scalar: head1 seciton name in file/POD
#   * subsection scalar: (optional) head2 section name in section
# Parses rules from the POD section/subsection in file, adding rule
# info found therein to %rule_info.  Then checks that rule info
# was gotten for all the required rules.
sub load_rule_info {
   my ( $self, %args ) = @_;
   foreach my $arg ( qw(rules file section) ) {
      die "I need a $arg argument" unless $args{$arg};
   }
   my $rules = $args{rules};  # requested/required rules
   my $p     = $self->{PodParser};

   # Parse rules and their info from the file's POD, saving
   # values to %rule_info.  Our trf sub returns nothing so
   # parse_section() returns nothing.
   $p->parse_section(
      %args,
      trf  => sub {
         my ( $para ) = @_;
         chomp $para;
         my $rule_info = _parse_rule_info($para);
         return unless $rule_info;

         die "Rule info does not specify an ID:\n$para"
            unless $rule_info->{id};
         die "Rule info does not specify a severity:\n$para"
            unless $rule_info->{severity};
         die "Rule info does not specify a description:\n$para",
            unless $rule_info->{description};
         die "Rule $rule_info->{id} is not defined"
            unless defined $self->{rule_index_for}->{ $rule_info->{id} };

         my $id = $rule_info->{id};
         if ( exists $self->{rule_info}->{$id} ) {
            die "Info for rule $rule_info->{id} already exists "
               . "and cannot be redefined"
         }

         $self->{rule_info}->{$id} = $rule_info;

         return;
      },
   );

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

# Called by load_rule_info() to parse a rule paragraph from the POD.
sub _parse_rule_info {
   my ( $para ) = @_;
   return unless $para =~ m/^id:/i;
   my $rule_info = {};
   my @lines = split("\n", $para);
   my $line;

   # First 2 lines should be id and severity.
   for ( 1..2 ) {
      $line = shift @lines;
      MKDEBUG && _d($line);
      $line =~ m/(\w+):\s*(.+)/;
      $rule_info->{lc $1} = uc $2;
   }

   # First line of desc.
   $line = shift @lines;
   MKDEBUG && _d($line);
   $line =~ m/(\w+):\s*(.+)/;
   my $desc        = lc $1;
   $rule_info->{$desc} = $2;
   # Rest of desc.
   while ( my $d = shift @lines ) {
      $rule_info->{$desc} .= $d;
   }
   $rule_info->{$desc} =~ s/\s+/ /g;
   $rule_info->{$desc} =~ s/\s+$//;

   MKDEBUG && _d('Parsed rule info:', Dumper($rule_info));
   return $rule_info;
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
