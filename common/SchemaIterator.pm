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
# SchemaIterator package $Revision$
# ###########################################################################
package SchemaIterator;

use strict;
use warnings FATAL => 'all';

use English qw(-no_match_vars);
use Data::Dumper;
$Data::Dumper::Indent    = 1;
$Data::Dumper::Sortkeys  = 1;
$Data::Dumper::Quotekeys = 0;

use constant MKDEBUG => $ENV{MKDEBUG};

sub new {
   my ( $class, %args ) = @_;
   foreach my $arg ( qw(Quoter) ) {
      die "I need a $arg argument" unless $args{$arg};
   }
   my $self = {
      %args,
      filter => undef,
   };
   return bless $self, $class;
}

# Required args:
#   * o  obj: OptionParser module
# Returns: subref
# Can die: yes
# make_filter() uses an OptionParser obj and the following standard filter
# options to make a filter sub suitable for set_filter():
#   --databases -d      List of allowed databases
#   --tables    -t      List of allowed tables
#   --engines   -e      List of allowed engines
#   --ignore-databases  List of databases to ignore
#   --ignore-tables     List of tables to ignore
#   --ignore-engines    List of engines to ignore 
sub make_filter {
   my ( $self, $o ) = @_;
   return;
}

# Required args:
#   * filter_sub  subref: Filter sub, usually from make_filter()
# Returns: undef
# Can die: no
# set_filter() sets the filter sub that get_db_itr() and get_tbl_itr()
# use to filter the schema objects they find.  If no filter sub is set
# then every possible schema object is returned by the iterators.
sub set_filter {
   my ( $self, $filter_sub ) = @_;
   $self->{filter} = $filter_sub;
   MKDEBUG && _d('Set filter sub');
   return;
}


# Required args:
#   * dbh  dbh: an active dbh
# Returns: itr
# Can die: no
# get_db_itr() returns an iterator which returns the next db found,
# according to any set filters, when called successively.
sub get_db_itr {
   my ( $self, $dbh ) = @_;
   return;
}

# Required args:
#   * dbh  dbh: an active dbh
#   * db   scalar: database name
# Returns: itr
# Can die: no
# get_tbl_itr() returns an iterator which returns the next table found,
# in the given db, according to any set filters, when called successively.
sub get_tbl_itr {
   my ( $self, $dbh, $db ) = @_;
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
# End SchemaIterator package
# ###########################################################################
