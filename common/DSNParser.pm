# ###########################################################################
# DSNParser package
# ###########################################################################
use strict;
use warnings FATAL => 'all';

package DSNParser;

# Defaults are built-in, but you can add more items by passing them as hashrefs
# of {key, desc, copy}.  The 'desc' item is optional.
sub new {
   my ( $class, @opts ) = @_;
   my $self = {
      D => {
         desc => 'Database to use',
         dsn  => 'database',
         copy => 1,
      },
      F => {
         desc => 'Only read default options from the given file',
         dsn  => 'mysql_read_default_file',
         copy => 1,
      },
      h => {
         desc => 'Connect to host',
         dsn  => 'host',
         copy => 1,
      },
      p => {
         desc => 'Password to use when connecting',
         dsn  => 'password',
         copy => 1,
      },
      P => {
         desc => 'Port number to use for connection',
         dsn  => 'port',
         copy => 1,
      },
      S => {
         desc => 'Socket file to use for connection',
         dsn  => 'mysql_socket',
         copy => 1,
      },
      u => {
         desc => 'User for login if not current user',
         dsn  => 'user',
         copy => 1,
      },
   };
   foreach my $opt ( @opts ) {
      $self->{$opt->{key}} = { desc => $opt->{desc}, copy => $opt->{copy} };
   }
   return bless $self, $class;
}

sub parse {
   my ( $self, $dsn, $prev, $defaults ) = @_;
   return unless $dsn;
   $prev     ||= {};
   $defaults ||= {};
   my %hash    = map { m/^(.)=(.*)$/g } split(/,/, $dsn);
   my %vals;
   foreach my $key ( keys %$self ) {
      $vals{$key} = $hash{$key};
      if ( !defined $vals{$key} && defined $prev->{$key} && $self->{$key}->{copy} ) {
         $vals{$key} = $prev->{$key};
      }
      if ( !defined $vals{$key} ) {
         $vals{$key} = $defaults->{$key};
      }
   }
   return \%vals;
}

sub usage {
   my ( $self ) = @_;
   my $usage
      = "  DSN syntax: key=value[,key=value...] Allowable DSN keys:\n"
      . "  KEY  MEANING\n"
      . "  ===  =============================================\n";
   foreach my $key ( sort keys %$self ) {
      $usage .= "  $key    "
             .  ($self->{$key}->{desc} || '[No description]')
             . "\n";
   }
   return $usage;
}

sub get_cxn_params {
   my ( $self, $info ) = @_;
   my $dsn
      = 'DBI:mysql:' . ( $info->{D} || '' ) . ';'
      . join(';', map  { "$self->{$_}->{dsn}=$info->{$_}" }
                  grep { defined $info->{$_} }
                  qw(F h P S))
      . ';mysql_read_default_group=mysql';
   return ($dsn, $info->{u}, $info->{p});
}

1;

# ###########################################################################
# End DSNParser package
# ###########################################################################
