# This program is copyright 2009-@CURRENTYEAR@ Percona Inc.
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
# CompareWarnings package $Revision$
# ###########################################################################
package CompareWarnings;

use strict;
use warnings FATAL => 'all';
use English qw(-no_match_vars);

use constant MKDEBUG => $ENV{MKDEBUG};

sub new {
   my ( $class, %args ) = @_;
   my @required_args = qw();
   foreach my $arg ( @required_args ) {
      die "I need a $arg argument" unless $args{$arg};
   }
   my $self = {
      %args,
   };
   return bless $self, $class;
}

sub before_execute {
   my ( $self, %args ) = @_;
   my @required_args = qw();
   foreach my $arg ( @required_args ) {
      die "I need a $arg argument" unless $args{$arg};
   }
   my $dbh     = $args{dbh};
   my $query   = $args{query};
   my $qparser = $args{QueryParser};
   my $error   = undef;
   my $name    = 'clear_warnings';
   MKDEBUG && _d($name);

   # On some systems, MySQL doesn't always clear the warnings list
   # after a good query.  This causes good queries to show warnings
   # from previous bad queries.  A work-around/hack is to
   # SELECT * FROM table LIMIT 0 which seems to always clear warnings.
   my @tables = $qparser->get_tables($query);
   if ( @tables ) {
      MKDEBUG && _d('tables:', @tables);
      my $sql = "SELECT * FROM $tables[0] LIMIT 0";
      MKDEBUG && _d($sql);
      eval {
         $dbh->do($sql);
      };
      if ( $EVAL_ERROR ) {
         MKDEBUG && _d('Error clearning warnings:', $EVAL_ERROR);
         $error = $EVAL_ERROR;
      }
   }
   else {
      $error = "Cannot clear warnings because the tables for this query cannot "
         . "be parsed.";
   }
}

sub execute {
   my ( $self, %args ) = @_;
   return;
}

sub after_execute {
   my ( $self, %args ) = @_;
   my @required_args = qw();
   foreach my $arg ( @required_args ) {
      die "I need a $arg argument" unless $args{$arg};
   }
   my ($host, $vp) = @args{@required_args};
   my $dbh         = $args{host}->{dbh};
   MKDEBUG && _d($name);

   my $warnings;
   my $warning_count;
   eval {
      $warnings      = $dbh->selectall_hashref('SHOW WARNINGS', 'Code');
      $warning_count = $dbh->selectall_arrayref('SELECT @@warning_count',
         { Slice => {} });
   };
   if ( $EVAL_ERROR ) {
      MKDEBUG && _d('Error getting warnings:', $EVAL_ERROR);
      $error = $EVAL_ERROR;
   }

   my $results = {
      error => $error,
      codes => $warnings,
      count => $warning_count->[0]->{'@@warning_count'} || 0,
   };
}

sub compare {
   my ( $warnings1, $warnings2 ) = @_;
   die "I need a warnings1 argument" unless defined $warnings1;
   die "I need a warnings2 argument" unless defined $warnings2;

   my %new_warnings;
   my $rank_inc = 0;
   my @reasons;

   foreach my $code ( keys %$warnings1 ) {
      if ( exists $warnings2->{$code} ) {
         if ( $warnings2->{$code}->{Level} ne $warnings1->{$code}->{Level} ) {
            $rank_inc += 2;
            push @reasons, "Error $code changes level: "
               . $warnings1->{$code}->{Level} . " on host1, "
               . $warnings2->{$code}->{Level} . " on host2 (rank+2)";
         }
      }
      else {
         MKDEBUG && _d('New warning on host1:', $code);
         push @reasons, "Error $code on host1 is new (rank+3)";
         %{ $new_warnings{$code} } = %{ $warnings1->{$code} };
      }
   }

   foreach my $code ( keys %$warnings2 ) {
      if ( !exists $warnings1->{$code} && !exists $new_warnings{$code} ) {
         MKDEBUG && _d('New warning on host2:', $code);
         push @reasons, "Error $code on host2 is new (rank+3)";
         %{ $new_warnings{$code} } = %{ $warnings2->{$code} };
      }
   }

   $rank_inc += 3 * scalar keys %new_warnings;

   # TODO: if we ever want to see the new warnings, we'll just have to
   #       modify this sub a litte.  %new_warnings is a placeholder for now.

   return $rank_inc, @reasons;
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
# End CompareWarnings package
# ###########################################################################
