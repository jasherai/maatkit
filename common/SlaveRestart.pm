# ###########################################################################
# SlaveRestart package $Revision: 0000 $
# ###########################################################################

package SlaveRestart;

use strict;
use warnings FATAL => 'all';
use POSIX qw(setsid);
use English qw(-no_match_vars);

use constant MKDEBUG => $ENV{MKDEBUG} || 0;

# Arguments:
#   * dbh                dbh: contains the original slave info.
#   * slave              coderef: tries to connect to the slave.
#   * onfail             scalar: whether it will attempt to reconnect or not.
#   * filter             not used. 
#   * retries            scalar: number of reconnect attempts.
#   * delay              coderef: returns the amount of time between each reconnect

sub new {
   my ($class, %args) = @_;
   foreach my $arg ( qw(dbh slave) ) {
      die "I need a $arg argument" unless $args{$arg};
   }

   my $self = {
      show_slave_status => sub {
         my ($dbh) = @_;
         return $dbh->selectrow_hashref("SHOW SLAVE STATUS");
      },
      filter            => [],
      retries           => 1,
      delay             => \sub { return 5 },

      # Override defaults
      %args,
   };
   return bless $self, $class;
}

sub retry {
   my ($self, $args) = @_;
   my ($status, $slave) = $self->_check_slave_status($self->{dbh});

   if ( !$status && $self->{onfail} ) {
      my ($counter, $reconnect_attempt) = (0, 0);
      print "Attempting to reconnect to the slave.\n";

      RETRY:
      while ( $counter != 1 ) {
         my $sleep_time = ${ $self->{delay} }->();
         ($status, $slave) = $self->_check_slave_status();

         print "Successfully reconnected to the slave.\n"
            if ( $status->{master_host} && $reconnect_attempt <= $self->{retries} );
         last RETRY if ( $status->{master_host} || 
                         $reconnect_attempt > $self->{retries} );

         sleep $sleep_time;
         $reconnect_attempt++;
         MKDEBUG && _d("Reconnect attempt: $reconnect_attempt");
         MKDEBUG && _d("Reconnect time: $sleep_time");
         next RETRY;
      }
   }  
   return $status, $slave;
};

sub _check_slave_status {
   my ($self, $args) = @_;

   # If there is no argument, it will use the original slave info.
   # Otherwise, it will attempt to connect to the slave database.
   my $slave ||= $args;

   my $show_slave_status = $self->{show_slave_status};
   my $status;

   eval{
      $slave  = ${ $self->{slave} }->();
      $status = $show_slave_status->($slave);
   };
   return $EVAL_ERROR ? undef : $status, $slave;
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
