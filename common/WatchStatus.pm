# This program is copyright 2009 Percona Inc.
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
# WatchStatus package $Revision$
# ###########################################################################
package WatchStatus;

use strict;
use warnings FATAL => 'all';

use English qw(-no_match_vars);

use constant MKDEBUG => $ENV{MKDEBUG} || 0;

sub new {
   my ( $class, %args ) = @_;
   foreach my $arg ( qw(params) ) {
      die "I need a $arg argument" unless $args{$arg};
   }

   my $check_sub;
   my %extra_args;
   eval {
      ($check_sub, %extra_args) = parse_params($args{params});
   };
   die "Error parsing parameters $args{params}: $EVAL_ERROR" if $EVAL_ERROR;

   my $self = {
      %extra_args,
      %args,
      check_sub => $check_sub,
      callbacks => {
         show_status        => \&_show_status,
         show_innodb_status => \&_show_innodb_status,
         show_slave_status  => \&_show_slave_status,
      },
   };
   return bless $self, $class;
}

sub parse_params {
   my ( $params ) = @_;
   my ( $stats, $var, $cmp, $thresh ) = split(':', $params);
   $stats = lc $stats;
   MKDEBUG && _d('Parsed', $params, 'as', $stats, $var, $cmp, $thresh);
   die "No stats parameter; expected status, innodb or slave" unless $stats;
   die "Invalid stats: $stats; expected status, innodb or slave"
      unless $stats eq 'status' || $stats eq 'innodb' || $stats eq 'slave';
   die "No var parameter" unless $var;
   die "No comparison parameter; expected >, < or =" unless $cmp;
   die "Invalid comparison: $cmp; expected >, < or ="
      unless $cmp eq '<' || $cmp eq '>' || $cmp eq '=';
   die "No threshold value (N)" unless defined $thresh;

   # User probably doesn't care that = and == mean different things
   # in a programming language; just do what they expect.
   $cmp = '==' if $cmp eq '=';

   my @lines = (
      'sub {',
      '   my ( $self, %args ) = @_;',
      "   my \$val = \$self->_get_val_from_$stats('$var', %args);",
      "   MKDEBUG && _d('Current $stats:$var =', \$val);",
      "   \$self->_save_last_check(\$val, '$cmp', '$thresh');",
      "   return \$val $cmp $thresh ? 1 : 0;",
      '}',
   );

   # Make the subroutine.
   my $code = join("\n", @lines);
   MKDEBUG && _d('OK sub:', @lines);
   my $check_sub = eval $code
      or die "Error compiling subroutine code:\n$code\n$EVAL_ERROR";

   # If getting InnoDB stats, we will need an InnoDBStatusParser obj.
   # For this to work the InnoDBStatusParser module needs to be in the
   # same file as this module.  Since this module is created generically,
   # caller (mk-loadavg) doesn't know what extra args/modules we need,
   # so we create them ourself.
   my %args;
   my $innodb_status_parser;
   if ( $stats eq 'innodb' ) {
      eval {
         $innodb_status_parser = new InnoDBStatusParser();
      };
      MKDEBUG && $EVAL_ERROR && _d('Cannot create an InnoDBStatusParser object:', $EVAL_ERROR);
      $args{InnoDBStatusParser} = $innodb_status_parser;
   }

   return $check_sub, %args;
}

sub uses_dbh {
   return 1;
}

sub set_dbh {
   my ( $self, $dbh ) = @_;
   $self->{dbh} = $dbh;
}

sub set_callbacks {
   my ( $self, %callbacks ) = @_;
   foreach my $func ( keys %callbacks ) {
      die "Callback $func does not exist"
         unless exists $self->{callbacks}->{$func};
      $self->{callbacks}->{$func} = $callbacks{$func};
      MKDEBUG && _d('Set new callback for', $func);
   }
   return;
}

sub check {
   my ( $self, %args ) = @_;
   return $self->{check_sub}->(@_);
}

# Returns all of SHOW STATUS or just the status for var if given.
sub _show_status {
   my ( $dbh, $var, %args ) = @_;
   if ( $var ) {
      my (undef, $val)
         = $dbh->selectrow_array("SHOW /*!50002 GLOBAL*/ STATUS LIKE '$var'");
      return $val;
   }
   else {
      return $dbh->selectall_hashref("SHOW /*!50002 GLOBAL*/ STATUS", 'Variable_name');
   }
}

# Returns the value for var from SHOW STATUS.
sub _get_val_from_status {
   my ( $self, $var, %args ) = @_;
   die "I need a var argument" unless $var;
   return $self->{callbacks}->{show_status}->($self->{dbh}, $var, %args);

#   if ( $args{incstatus} ) {
#      sleep(1);
#      my (undef, $status2)
#         = $dbh->selectrow_array("SHOW /*!50002 GLOBAL*/ STATUS LIKE '$args{metric}'");
#      return $status2 - $status1;
#   }
#   else {
#      return $status1;
#   }

}

sub _show_innodb_status {
   my ( $dbh, %args ) = @_;
   # TODO: http://code.google.com/p/maatkit/issues/detail?id=789
   my @text = $dbh->selectrow_array("SHOW /*!40100 ENGINE*/ INNODB STATUS");
   return $text[2] || $text[0];
}

# Returns the highest value for var from SHOW INNODB STATUS.
sub _get_val_from_innodb {
   my ( $self, $var, %args ) = @_;
   die "I need a var argument" unless $var;
   my $is = $self->{InnoDBStatusParser};
   die "No InnoDBStatusParser object" unless $is;

   my $status_text = $self->{callbacks}->{show_innodb_status}->($self->{dbh}, %args);
   my $idb_stats   = $is->parse($status_text);

   my $val = 0;
   SECTION:
   foreach my $section ( keys %$idb_stats ) {
      next SECTION unless exists $idb_stats->{$section}->[0]->{$var};
      MKDEBUG && _d('Found', $var, 'in section', $section);

      # Each section should be an arrayref.  Go through each set of vars
      # and find the highest var that we're checking.
      foreach my $vars ( @{$idb_stats->{$section}} ) {
         MKDEBUG && _d($var, '=', $vars->{$var});
         $val = $vars->{$var} && $vars->{$var} > $val ? $vars->{$var} : $val;
      }
      MKDEBUG && _d('Highest', $var, '=', $val);
      last SECTION;
   }
   return $val;
}

sub _show_slave_status {
   my ( $dbh, $var, %args ) = @_;
   return $dbh->selectrow_hashref("SHOW SLAVE STATUS")->{$var};
}

# Returns the value for var from SHOW SLAVE STATUS.
sub _get_val_from_slave {
   my ( $self, $var, %args ) = @_;
   die "I need a var argument" unless $var;
   return $self->{callbacks}->{show_slave_status}->($self->{dbh}, $var, %args);
}

# Calculates average query time by the Trevor Price method.
sub trevorprice {
   my ( $self, $dbh, %args ) = @_;
   die "I need a dbh argument" unless $dbh;
   my $num_samples = $args{samples} || 100;
   my $num_running = 0;
   my $start = time();
   my (undef, $status1)
      = $dbh->selectrow_array('SHOW /*!50002 GLOBAL*/ STATUS LIKE "Questions"');
   for ( 1 .. $num_samples ) {
      my $pl = $dbh->selectall_arrayref('SHOW PROCESSLIST', { Slice => {} });
      my $running = grep { ($_->{Command} || '') eq 'Query' } @$pl;
      $num_running += $running - 1;
   }
   my $time = time() - $start;
   return 0 unless $time;
   my (undef, $status2)
      = $dbh->selectrow_array('SHOW /*!50002 GLOBAL*/ STATUS LIKE "Questions"');
   my $qps = ($status2 - $status1) / $time;
   return 0 unless $qps;
   return ($num_running / $num_samples) / $qps;
}

sub _save_last_check {
   my ( $self, @args ) = @_;
   $self->{last_check} = [ @args ];
   return;
}

sub get_last_check {
   my ( $self ) = @_;
   return @{ $self->{last_check} };
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
# End WatchStatus package
# ###########################################################################
