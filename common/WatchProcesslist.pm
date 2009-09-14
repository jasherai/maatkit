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
# WatchProcesslist package $Revision$
# ###########################################################################
package WatchProcesslist;

use strict;
use warnings FATAL => 'all';

use English qw(-no_match_vars);

use constant MKDEBUG => $ENV{MKDEBUG};

sub new {
   my ( $class, %args ) = @_;
   foreach my $arg ( qw(params dbh) ) {
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
         show_processlist => \&_show_processlist,
      },
   };
   return bless $self, $class;
}

sub parse_params {
   my ( $params ) = @_;
   my ( $col, $val, $agg, $cmp, $thres ) = split(':', $params);
   $col = lc $col;
   $val = lc $val;
   $agg = lc $agg;
   MKDEBUG && _d('Parsed', $params, 'as', $col, $val, $agg, $cmp, $thres);
   die "No column parameter; expected db, user, host, state or command"
      unless $col;
   die "Invalid column parameter: $col; expected db, user, host, state or command"
      unless $col eq 'db' || $col eq 'user' || $col eq 'host' 
          || $col eq 'state' || $col eq 'command';
   die "No value parameter" unless $val;
   die "No aggregate; expected count or time" unless $agg;
   die "Invalid aggregate: $agg; expected count or time"
      unless $agg eq 'count' || $agg eq 'time';
   die "No comparison parameter; expected >, < or =" unless $cmp;
   die "Invalid comparison parameter: $cmp; expected >, < or ="
      unless $cmp eq '<' || $cmp eq '>' || $cmp eq '=';
   die "No threshold value (N)" unless defined $thres;

   # User probably doesn't care that = and == mean different things
   # in a programming language; just do what they expect.
   $cmp = '==' if $cmp eq '=';

   my @lines = (
      'sub {',
      '   my ( $self, %args ) = @_;',
      '   my $proc = $self->{callbacks}->{show_processlist}->($self->{dbh});',
      '   my $apl  = $self->{ProcesslistAggregator}->aggregate($proc);',
      "   my \$val = \$apl->{$col}->{'$val'}->{$agg} || 0;",
      "   MKDEBUG && _d('Current $col $val $agg =', \$val);",
      "   return \$val $cmp $thres ? 1 : 0;",
      '}',
   );

   # Make the subroutine.
   my $code = join("\n", @lines);
   MKDEBUG && _d('OK sub:', @lines);
   my $ok_sub = eval $code
      or die "Error compiling subroutine code:\n$code\n$EVAL_ERROR";

   # We need a ProcesslistAggregator obj.  For this to work the
   # ProcesslistAggregator module needs to be in the same file as this
   # module.  Since this module is created generically, caller (mk-loadavg)
   # doesn't know what extra args/modules we need, so we create them ourself.
   my %args;
   my $pla;
   eval {
      my $pla = new ProcesslistAggregator();
   };
   MKDEBUG && $EVAL_ERROR && _d('Cannot create a ProcesslistAggregator object:',
      $EVAL_ERROR);
   $args{ProcesslistAggregator} = $pla;

   return $ok_sub, %args;
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

sub _show_processlist {
   my ( $dbh, %args ) = @_;
   return $dbh->selectall_arrayref('SHOW PROCESSLIST', { Slice => {} } );
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
# End WatchProcesslist package
# ###########################################################################
