# This program is copyright (c) 2008 Baron Schwartz.
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
# SchemaFindText package $Revision$
# ###########################################################################
use strict;
use warnings FATAL => 'all';

package SchemaFindText;

use English qw(-no_match_vars);

use constant MKDEBUG => $ENV{MKDEBUG};

# Arguments:
# * fh => filehandle
sub new {
   my ( $class, %args ) = @_;
   bless \%args, $class;
}

sub next_db {
   my ( $self ) = @_;
   local $RS = "";
   my $fh = $self->{fh};
   while ( defined (my $text = <$fh>) ) {
      my ($db) = $text =~ m/^USE `([^`]+)`/;
      return $db if $db;
   }
}

sub next_tbl {
   my ( $self ) = @_;
   local $RS = "";
   my $fh = $self->{fh};
   while ( defined (my $text = <$fh>) ) {
      return undef if $text =~ m/^USE `[^`]+`/;
      my ($ddl) = $text =~ m/^(CREATE TABLE.*?^\)[^\n]*);\n/sm;
      if ( $ddl ) {
         $self->{last_tbl_ddl} = $ddl;
         my ( $tbl ) = $ddl =~ m/CREATE TABLE `([^`]+)`/;
         return $tbl;
      }
   }
}

sub last_tbl_ddl {
   my ( $self ) = @_;
   return $self->{last_tbl_ddl};
}

1;

# ###########################################################################
# End SchemaFindText package
# ###########################################################################
