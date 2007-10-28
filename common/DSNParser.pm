# ###########################################################################
# DSNParser package $Revision$
# ###########################################################################
use strict;
use warnings FATAL => 'all';

package DSNParser;

# Defaults are built-in, but you can add/replace items by passing them as hashrefs
# of {key, desc, copy, dsn}.  The desc and dsn items are optional.  You can set
# properties with the prop() function.  Don't set the 'opts' property.
sub new {
   my ( $class, @opts ) = @_;
   my $self = {
      opts => {
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
      },
   };
   foreach my $opt ( @opts ) {
      $self->{opts}->{$opt->{key}} = { desc => $opt->{desc}, copy => $opt->{copy} };
   }
   return bless $self, $class;
}

# Recognized properties:
# * autokey:   which key to treat a bareword as (typically h=host).
# * dbidriver: which DBI driver to use; assumes mysql, supports Pg.
# * required:  which parts are required (hashref).
sub prop {
   my ( $self, $prop, $value ) = @_;
   if ( @_ > 2 ) {
      $self->{$prop} = $value;
   }
   return $self->{$prop};
}

sub parse {
   my ( $self, $dsn, $prev, $defaults ) = @_;
   return unless $dsn;
   $prev     ||= {};
   $defaults ||= {};
   my %vals;
   my %opts = %{$self->{opts}};
   if ( $dsn !~ m/=/ && $self->prop('autokey') ) {
      $vals{ $self->prop('autokey') } = $dsn;
   }
   else {
      my %hash = map { m/^(.)=(.*)$/g } split(/,/, $dsn);
      foreach my $key ( keys %opts ) {
         $vals{$key} = $hash{$key};
         if ( !defined $vals{$key} && defined $prev->{$key} && $opts{$key}->{copy} ) {
            $vals{$key} = $prev->{$key};
         }
         if ( !defined $vals{$key} ) {
            $vals{$key} = $defaults->{$key};
         }
      }
   }
   if ( (my $required = $self->prop('required')) ) {
      foreach my $key ( keys %$required ) {
         die "Missing '$key' part in '$dsn'" unless $vals{$key};
      }
   }
   return \%vals;
}

sub usage {
   my ( $self ) = @_;
   my $usage
      = "  DSN syntax: key=value[,key=value...] Allowable DSN keys:\n"
      . "  KEY  COPY  MEANING\n"
      . "  ===  ====  =============================================\n";
   my %opts = %{$self->{opts}};
   foreach my $key ( sort keys %opts ) {
      $usage .= "  $key    "
             .  ($opts{$key}->{copy} ? 'yes   ' : 'no    ')
             .  ($opts{$key}->{desc} || '[No description]')
             . "\n";
   }
   if ( (my $key = $self->prop('autokey')) ) {
      $usage .= "  If the DSN is a bareword, the word is treated as the '$key' key.\n";
   }
   return $usage;
}

# Supports PostgreSQL via the dbidriver element of $info, but assumes MySQL by
# default.
sub get_cxn_params {
   my ( $self, $info ) = @_;
   my $dsn;
   my %opts = %{$self->{opts}};
   my $driver = $self->prop('dbidriver') || '';
   if ( $driver eq 'Pg' ) {
      $dsn = 'DBI:Pg:dbname=' . ( $info->{D} || '' ) . ';'
         . join(';', map  { "$opts{$_}->{dsn}=$info->{$_}" }
                     grep { defined $info->{$_} }
                     qw(h P));
   }
   else {
      $dsn = 'DBI:mysql:' . ( $info->{D} || '' ) . ';'
         . join(';', map  { "$opts{$_}->{dsn}=$info->{$_}" }
                     grep { defined $info->{$_} }
                     qw(F h P S))
         . ';mysql_read_default_group=mysql';
   }
   return ($dsn, $info->{u}, $info->{p});
}

1;

# ###########################################################################
# End DSNParser package
# ###########################################################################
