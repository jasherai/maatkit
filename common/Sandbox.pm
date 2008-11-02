# This program is copyright 2008 Percona Inc.
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
# Sandbox package $Revision$
# ###########################################################################
package Sandbox;

use strict;
use warnings FATAL => 'all';
use English qw(-no_match_vars);

use constant MKDEBUG => $ENV{MKDEBUG};

my %port_for = (
   master => 12345,
   slave1 => 12346,
   slave2 => 12347,
);

sub new {
   my ( $class, %args ) = @_;
   foreach my $arg ( qw(basedir DSNParser) ) {
      die "I need a $arg argument" unless defined $args{$arg};
   }

   if ( !-d $args{basedir} ) {
      die "$args{basedir} is not a directory";
   }

   return bless { %args }, $class;
}

sub create_dbs {
   my ( $self, $dbh, $dbs, %args ) = @_;
   die 'I need a dbh' if !$dbh;
   return if ( !ref $dbs || scalar @$dbs == 0 );

   foreach my $db ( @$dbs ) {
      if ( exists $args{no_repl} && $args{no_repl} ) {
         $dbh->do('SET SQL_LOG_BIN=0');
      }
      if ( exists $args{drop_if_exists} && $args{drop_if_exists} ) {
         $dbh->do("DROP DATABASE IF EXISTS `$db`");
      }

      my $sql = "CREATE DATABASE `$db`";
      eval {
         $dbh->do($sql);
      };
      die $EVAL_ERROR if $EVAL_ERROR;

      if ( exists $args{no_repl} && $args{no_repl} ) {
         $dbh->do('SET SQL_LOG_BIN=1');
      }

      $self->_record_action(undef, $dbh, $sql, "DROP DATABASE `$db`");
   }
   return;
}
   
sub get_dbh_for {
   my ( $self, $server ) = @_;
   _check_server($server);
   MKDEBUG && _d("Dbh for $server on port $port_for{$server}");
   my $dp = $self->{DSNParser};
   my $dsn = $dp->parse('h=127.0.0.1,P=' . $port_for{$server});
   return $dp->get_dbh($dp->get_cxn_params($dsn), { AutoCommit => 1 });
}

sub exec_file_on {
   my ( $self, $file, $server ) = @_;
   _check_server($server);
   if ( !-f $file ) {
      die "$file is not a file";
   }

   MKDEBUG && _d("Executing $file on $server");
   my $use = $self->_use_for($server);
   eval {
      `$use < $file`;
   };
   if ( $EVAL_ERROR ) {
      die "Failed to execute $file on $server: $EVAL_ERROR";
   }

   return;
}

sub _use_for {
   my ( $self, $server ) = @_;
   return "$self->{basedir}/$port_for{$server}/use";
}

sub _check_server {
   my ( $server ) = @_;
   if ( !exists $port_for{$server} ) {
      die "Unknown server $server";
   }
   return;
}

sub _record_action {
   my ( $self, $server, $dbh, $action, $undo ) = @_;
   push @{ $self->{actions} },
      {
         server => $server,
         dbh    => $dbh,
         action => $action,
         undo   => $undo,
      };
   return;
}

sub restore_sandbox {
   my ( $self ) = @_;
   foreach my $action ( @{ $self->{actions} } ) {
      next if !defined $action->{undo};
      if ( defined $action->{dbh} ) {
         MKDEBUG && _d("Undoing $action->{action} by doing $action->{undo}");
         eval {
            $action->{dbh}->do($action->{undo});
         };
         if ( $EVAL_ERROR && MKDEBUG ) {
            _d("Undo failed: $EVAL_ERROR");
         }
      }
   }
   @{ $self->{actions} } = ();
   return;
}

sub _d {
   my ( $line ) = (caller(0))[2];
   print "# Sandbox:$line $PID ", @_, "\n";
}

1;

# ###########################################################################
# End Sandbox package
# ###########################################################################
