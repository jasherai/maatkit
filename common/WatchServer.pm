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
# WatchServer package $Revision$ 
# ###########################################################################
package WatchServer;

use strict;
use warnings FATAL => 'all';

use English qw(-no_match_vars);

use constant MKDEBUG => $ENV{MKDEBUG};

sub new {
   my ( $class, %args ) = @_;
   foreach my $arg ( qw(params) ) {
      die "I need a $arg argument" unless $args{$arg};
   }

   my $ok_sub;
   my %extra_args;
   eval {
      ($ok_sub, %extra_args) = parse_params($args{params});
   };
   die "Error parsing parameters $args{params}: $EVAL_ERROR" if $EVAL_ERROR;

   my $self = {
      %extra_args,
      %args,
      ok_sub    => $ok_sub,
      callbacks => {
         uptime => \&_uptime,
         vmstat => \&_vmstat,
      },
   };
   return bless $self, $class;
}

sub parse_params {
   my ( $params ) = @_;
   my ( $cmd, $cmd_arg, $cmp, $thresh ) = split(':', $params);
   MKDEBUG && _d('Parsed', $params, 'as', $cmd, $cmd_arg, $cmp, $thresh);
   die "No command parameter" unless $cmd;
   die "Invalid command: $cmd; expected loadavg or uptime"
      unless $cmd eq 'loadavg' || $cmd eq 'vmstat';
   if ( $cmd eq 'loadavg' ) {
      die "Invalid $cmd argument: $cmd_arg; expected 1, 5 or 15"
         unless $cmd_arg eq '1' || $cmd_arg eq '5' || $cmd_arg eq '15';
   }
   elsif ( $cmd eq 'vmstat' ) {
      my @vmstat_args = qw(r b swpd free buff cache si so bi bo in cs us sy id wa);
      die "Invalid $cmd argument: $cmd_arg; expected one of "
         . join(',', @vmstat_args)
         unless grep { $cmd_arg eq $_ } @vmstat_args;
   }
   die "No comparison parameter; expected >, < or =" unless $cmp;
   die "Invalid comparison parameter: $cmp; expected >, < or ="
      unless $cmp eq '<' || $cmp eq '>' || $cmp eq '=';
   die "No threshold value (N)" unless defined $thresh;

   # User probably doesn't care that = and == mean different things
   # in a programming language; just do what they expect.
   $cmp = '==' if $cmp eq '=';

   my @lines = (
      'sub {',
      '   my ( $self, %args ) = @_;',
      "   my \$val = \$self->_get_val_from_$cmd('$cmd_arg', %args);",
      "   MKDEBUG && _d('Current $cmd $cmd_arg =', \$val);",
      "   \$self->_save_last_check(\$val, '$cmp', '$thresh');",
      "   return \$val $cmp $thresh ? 1 : 0;",
      '}',
   );

   # Make the subroutine.
   my $code = join("\n", @lines);
   MKDEBUG && _d('OK sub:', @lines);
   my $ok_sub = eval $code
      or die "Error compiling subroutine code:\n$code\n$EVAL_ERROR";

   return $ok_sub;
}

sub uses_dbh {
   return 0;
}

sub set_dbh {
   return;
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

sub ok {
   my ( $self, %args ) = @_;
   return $self->{ok_sub}->(@_);
}

sub _uptime {
   return `uptime`;
}

sub _get_val_from_loadavg {
   my ( $self, $cmd_arg, %args ) = @_;
   my $uptime = $self->{callbacks}->{uptime}->();
   chomp $uptime;
   return 0 unless $uptime;
   my @loadavgs = $uptime =~ m/load average:\s+(\S+),\s+(\S+),\s+(\S+)/;
   MKDEBUG && _d('Load averages:', @loadavgs);
   my $i = $cmd_arg == 1 ? 0
         : $cmd_arg == 5 ? 1
         :                 2;
   return $loadavgs[$i] || 0;
}

sub _vmstat {
   return `vmstat`;
}

# Parses vmstat output like:
# procs -----------memory---------- ---swap-- -----io---- -system-- ----cpu----
# r  b   swpd   free   buff  cache   si   so    bi    bo   in   cs us sy id wa
# 0  0      0 664668 130452 566588    0    0     8    11  237  351  5  1 93  1
# and returns a hashref with the values like:
#   r    => 0,
#   free => 664668,
#   etc.
sub _parse_vmstat {
   my ( $vmstat_output ) = @_;
   MKDEBUG && _d('vmstat output:', $vmstat_output);
   my @lines =
      map {
         my $line = $_;
         my @vals = split(/\s+/, $line);
         \@vals;
      } split(/\n/, $vmstat_output);
   my %vmstat;
   my $n_vals = scalar @{$lines[1]};
   for my $i ( 0..$n_vals-1 ) {
      next unless $lines[1]->[$i];
      $vmstat{$lines[1]->[$i]} = $lines[-1]->[$i];
   }
   return \%vmstat;
}

sub _get_val_from_vmstat {
   my ( $self, $cmd_arg, %args ) = @_;
   my $vmstat_output = $self->{callbacks}->{vmstat}->();
   return _parse_vmstat($vmstat_output)->{$cmd_arg} || 0;
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
# End WatchServer package
# ###########################################################################
