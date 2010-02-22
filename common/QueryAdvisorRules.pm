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

# These are our builtin mk-query-advisor rules.  Returned by get_rules().
my @rules = (
   {
      id   => 'LIT.001',
      code => sub {
         my ( %args ) = @_;
         my $query = $args{query};
         return $query =~ m/['"]\d{1,3}\.\d{1,3}\.\d{1,3}\.\d{1,3}/;
      },
   },
   {
      id   => 'LIT.002',
      code => sub {
         my ( %args ) = @_;
         my $query = $args{query};
         return $query =~ m/[^'"](?:\d{2,4}-\d{1,2}-\d{1,2}|\d{4,6})/;
      },
   },
   {
      id   => 'GEN.001',
      code => sub {
         my ( %args ) = @_;

         my $type = $args{query_struct}->{type};
         return unless $type && $type eq 'select';

         my $cols = $args{query_struct}->{columns};
         return unless $cols;

         foreach my $col ( @$cols ) {
            return 1 if $col eq '*';
         }
         return 0;
      },
   },
   {
      id   => 'ALI.001',
      code => sub {
         my ( %args ) = @_;
         my $cols = $args{query_struct}->{columns};
         return unless $cols;
         foreach my $col ( @$cols ) {
            my @words = $col =~ m/(\S+)\s+(\S+)/;
            return 1 if @words && @words > 1 && $words[1] !~ m/AS/i;
         }
         return 0;
      },
   },
);

# Maps rules by ID to their array index in @rules.  Initialized
# in new(), used in load_rule_info() to check that a rule exists
# for the loaded info (i.e. so POD doesn't list rules for which
# there's no code).
my %rule_index_for;

# ID, severity, description, etc. for each rule.  Initialized in
# load_rule_info(), used in get_rule_info().
my %rule_info;

sub new {
   my ( $class, %args ) = @_;
   foreach my $arg ( qw(PodParser) ) {
      die "I need a $arg argument" unless $args{$arg};
   }

   my $self = {
      %args,
   };

   # Intialize %rule_index_for.
   my $i = 0;
   map { $rule_index_for{ $_->{id} } = $i++ } @rules;

   return bless $self, $class;
}

sub get_rules {
   return @rules;
}

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
            unless defined $rule_index_for{ $rule_info->{id} };

         my $id = $rule_info->{id};
         if ( exists $rule_info{$id} ) {
            die "Info for rule $rule_info->{id} already exists "
               . "and cannot be redefined"
         }

         $rule_info{$id} = $rule_info;

         return;
      },
   );

   # Check that rule info was gotten for each requested rule.
   foreach my $rule ( @$rules ) {
      die "There is no info for rule $rule->{id}"
         unless $rule_info{ $rule->{id} };
   }

   return;
}

sub get_rule_info {
   my ( $self, $id ) = @_;
   return unless $id;
   return $rule_info{$id};
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
   %rule_info = ();
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
