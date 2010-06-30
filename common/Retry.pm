# ###########################################################################
# SlaveRestart package $Revision: 0000 $
# ###########################################################################

package SlaveRestart;

use strict;
use warnings FATAL => 'all';
use English qw(-no_match_vars);

use constant MKDEBUG => $ENV{MKDEBUG} || 0;

# Arguments:
#   * dbh                dbh: contains the original slave info.
#   * connect_to_slave   coderef: tries to connect to the slave.
#   * onfail             scalar: whether it will attempt to reconnect or not.
#   * retries            scalar: number of reconnect attempts.
#   * delay              coderef: returns the amount of time between each reconnect

sub new {
   my ($class, %args) = @_;
   foreach my $arg ( qw(dbh connect_to_slave) ) {
      die "I need a $arg argument" unless $args{$arg};
   }

   my $self = {
      show_slave_status => sub {
         my ($dbh) = @_;
         return $dbh->selectrow_hashref("SHOW SLAVE STATUS");
      },
      retries           => 3,
      delay             => 5,

      # Override defaults
      %args,
   };
   return bless $self, $class;
}

sub reconnect {
   my ($self) = @_;
   my $reconnect_attempt = 1;
   my ($slave, $status);
  
   return if $self->{dbh} && $self->{dbh}->ping;
   warn "Attempting to reconnect to the slave.\n";
   while ( !$status && $reconnect_attempt <= $self->{retries} ) {
      my $sleep_time = $self->{delay};
      MKDEBUG && _d("Reconnect attempt: ", $reconnect_attempt);
      
      eval {
         my $connect_to_slave = $self->{connect_to_slave};
         $slave = $$connect_to_slave->();
      };

      if ( $EVAL_ERROR || !$slave ) {
         MKDEBUG && _d($EVAL_ERROR);
         MKDEBUG && _d("Reconnect time: ", $sleep_time);
         sleep $sleep_time;
         $reconnect_attempt++;
      }
      else {
         $status = $self->_check_slave_status( dbh => $slave );
         if ( $status && %$status ) {
            MKDEBUG && _d("Successfully reconnected to the slave.");
         }
      }
   }
   return $slave;
};

sub _check_slave_status {
   my ($self, %args) = @_;
   my $dbh = $args{dbh};
   my $show_slave_status = $self->{show_slave_status};
   my $status;

   eval{
      $status = $show_slave_status->($dbh);
   };

   if ( $EVAL_ERROR ) {
      MKDEBUG && _d($EVAL_ERROR);
   }
   return $status;
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
# End SlaveRestart package
# ###########################################################################
