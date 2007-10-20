# ###########################################################################
# VersionParser package
# ###########################################################################
use strict;
use warnings FATAL => 'all';

package VersionParser;

sub new {
   my ( $class ) = @_;
   bless {}, $class;
}

sub parse {
   my ( $self, $str ) = @_;
   return sprintf('%03d%03d%03d', $str =~ m/(\d+)/g);
}

# Compares versions like 5.0.27 and 4.1.15-standard-log.  Caches version number
# for each DBH for later use.
sub version_ge {
   my ( $self, $dbh, $target ) = @_;
   $self->{$dbh} ||= $self->parse(
      $dbh->selectrow_array('SELECT VERSION()'));
   return $self->{$dbh} ge $self->parse($target);
}

1;

# ###########################################################################
# End VersionParser package
# ###########################################################################
