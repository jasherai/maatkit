# This program is copyright 2008-2009 Percona Inc.
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
# KeySize package $Revision$
# ###########################################################################
package KeySize;

use strict;
use warnings FATAL => 'all';
use English qw(-no_match_vars);

use constant MKDEBUG => $ENV{MKDEBUG};

sub new {
   my ( $class, %args ) = @_;
   my $self = {};
   return bless $self, $class;
}

# The tbl arg is an already quoted db-qualified table name, like `db`.`tbl`.
# The key arg is a hashref to something like a value from the keys hash
# in TableParser::parse(). It must contain at least a name and cols key.
# The size of the key is return.
sub get_key_size {
   my ( $self, %args ) = @_;
   foreach my $arg ( qw(tbl key dbh) ) {
      die "I need a $arg argument" unless $args{$arg};
   }
   my $key = $args{key};
   foreach my $req_key ( qw(name cols) ) {
      die "The key hashref argument does not have a $req_key key"
         unless exists $key->{$req_key};
   }

   # Construct a SQL statement with WHERE conditions on all key
   # cols that will get EXPLAIN to tell us 1) the full length of
   # the key and 2) the total number of rows in the table.
   # For 1), all key cols must be used because key_len in EXPLAIN only
   # only covers the portion of the key needed to satisfy the query.
   # For 2), we have to break normal index usage which normally
   # allows MySQL to access only the limited number of rows needed
   # to satisify the query because we want to know total table rows.
   my $sql = 'EXPLAIN SELECT ' . join(', ', @{$key->{cols}})
           . ' FROM ' . $args{tbl}
           . " FORCE INDEX (`$key->{name}`)"
           . ' WHERE ';
   my @where_cols;
   foreach my $col ( @{$key->{cols}} ) {
      push @where_cols, "$col=1";
   }
   # For single column indexes we have to trick MySQL into scanning
   # the whole index by giving it two irreducible condtions. Otherwise,
   # EXPLAIN rows will report only the rows that satisfy the query
   # using the key, but this is not what we want. We want total table rows.
   # In other words, we need an EXPLAIN type index, not ref or range.
   if ( scalar @{$key->{cols}} == 1 ) {
      push @where_cols, "$key->{cols}->[0]<>1";
   }
   $sql .= join(' OR ', @where_cols);
   MKDEBUG && _d('Key size sql:', $sql);

   my $explain = $args{dbh}->selectall_hashref($sql, 'id');
   my $key_len = $explain->{1}->{key_len};
   my $rows    = $explain->{1}->{rows};

   my $key_size = 0;
   if ( defined $key_len && defined $rows ) {
      $key_size = $key_len * $rows;
   }
   elsif ( MKDEBUG ) {
      _d("key_len or rows NULL in EXPLAIN:\n",
         join("\n",
            map { "$_: ".($explain->{1}->{$_} ? $explain->{1}->{$_} : 'NULL') }
            keys %{$explain->{1}}));
   }

   return $key_size;
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
# End KeySize package
# ###########################################################################
