# ###########################################################################
# Quoter package
# ###########################################################################
use strict;
use warnings FATAL => 'all';

package Quoter;

sub new {
   my ( $class ) = @_;
   bless {}, $class;
}

sub quote {
   my ( $self, @vals ) = @_;
   foreach my $val ( @vals ) {
      $val =~ s/`/``/g;
   }
   map { '`' . $_ . '`' } @vals;
}

1;

# ###########################################################################
# End Quoter package
# ###########################################################################
