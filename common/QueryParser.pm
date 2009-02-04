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

sub get_tables {
   my ( $self, $query ) = @_;
   return unless $query;
   my @tables = ();
   my $callback = sub {
      my ( $tbls ) = @_;
      # Remove [AS] foo aliases
      $tbls =~ s/($ident)\s+(?:as\s+\w+|\w+)/$1/gi;
      push @tables, $tbls =~ m/($ident)/g;
   };
   $self->_get_table_refs($query, $callback);
   return @tables;
}

sub get_table_aliases {
   my ( $self, $query ) = @_;
   return unless $query;
   my $aliases = {};
   my $save_alias = sub {
      my ( $db_tbl, $alias ) = @_;
      my ( $db, $tbl ) = $db_tbl =~ m/^(?:(\S+)\.)?(\S+)/;
      $aliases->{$alias || $tbl} = $tbl;
      $aliases->{DATABASE}->{$tbl} = $db if $db;
      return 1;
   };
   my $callback = sub {
      my ( $tbls ) = @_;
      $tbls =~ s/($ident)(?:\s+(?:as\s+(\w+)|(\w+))*)*/$save_alias->($1,$2)/gie;
   };
   $self->_get_table_refs($query, $callback);
   return $aliases;
}
 
# Returns an array of tables to which the query refers.
# XXX If you change this code, also change QueryRewriter::distill().
sub _get_table_refs {
   my ( $self, $query, $callback ) = @_;
   return unless $query;
   return unless $callback;
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
      MKDEBUG && _d("table ref: $tbls");
      $callback->($tbls);
   }
   return;
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
