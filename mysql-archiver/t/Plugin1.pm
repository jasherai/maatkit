package Plugin1;

sub new {
   my ( $class, %args ) = @_;
   return bless(\%args, $class);
}

sub is_archivable {} # Take no action
sub before_delete {} # Take no action
sub before_insert {} # Take no action

1;

