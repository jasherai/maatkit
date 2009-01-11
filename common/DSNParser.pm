# This program is copyright (c) 2007 Baron Schwartz.
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
# DSNParser package $Revision$
# ###########################################################################
use strict;
use warnings FATAL => 'all';

package DSNParser;

use DBI;
use Data::Dumper;
$Data::Dumper::Indent    = 0;
$Data::Dumper::Quotekeys = 0;
use English qw(-no_match_vars);

use constant MKDEBUG => $ENV{MKDEBUG};

# Defaults are built-in, but you can add/replace items by passing them as
# hashrefs of {key, desc, copy, dsn}.  The desc and dsn items are optional.
# You can set properties with the prop() sub.  Don't set the 'opts' property.
sub new {
   my ( $class, @opts ) = @_;
   my $self = {
      opts => {
         A => {
            desc => 'Default character set',
            dsn  => 'charset',
            copy => 1,
         },
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
      MKDEBUG && _d('Adding extra property ' . $opt->{key});
      $self->{opts}->{$opt->{key}} = { desc => $opt->{desc}, copy => $opt->{copy} };
   }
   return bless $self, $class;
}

# Recognized properties:
# * autokey:   which key to treat a bareword as (typically h=host).
# * dbidriver: which DBI driver to use; assumes mysql, supports Pg.
# * required:  which parts are required (hashref).
# * setvars:   a list of variables to set after connecting
sub prop {
   my ( $self, $prop, $value ) = @_;
   if ( @_ > 2 ) {
      MKDEBUG && _d("Setting $prop property");
      $self->{$prop} = $value;
   }
   return $self->{$prop};
}

sub parse {
   my ( $self, $dsn, $prev, $defaults ) = @_;
   if ( !$dsn ) {
      MKDEBUG && _d('No DSN to parse');
      return;
   }
   MKDEBUG && _d("Parsing $dsn");
   $prev     ||= {};
   $defaults ||= {};
   my %given_props;
   my %final_props;
   my %opts = %{$self->{opts}};
   my $prop_autokey = $self->prop('autokey');

   # Parse given props
   foreach my $dsn_part ( split(/,/, $dsn) ) {
      if ( my ($prop_key, $prop_val) = $dsn_part =~  m/^(.)=(.*)$/ ) {
         # Handle the typical DSN parts like h=host, P=3306, etc.
         $given_props{$prop_key} = $prop_val;
      }
      elsif ( $prop_autokey ) {
         # Handle barewords
         MKDEBUG && _d("Interpreting $dsn_part as $prop_autokey=$dsn_part");
         $given_props{$prop_autokey} = $dsn_part;
      }
      else {
         MKDEBUG && _d("Bad DSN part: $dsn_part");
      }
   }

   # Fill in final props from given, previous, and/or default props
   foreach my $key ( keys %opts ) {
      MKDEBUG && _d("Finding value for $key");
      $final_props{$key} = $given_props{$key};
      if (   !defined $final_props{$key}
           && defined $prev->{$key} && $opts{$key}->{copy} )
      {
         $final_props{$key} = $prev->{$key};
         MKDEBUG && _d("Copying value for $key from previous DSN");
      }
      if ( !defined $final_props{$key} ) {
         $final_props{$key} = $defaults->{$key};
         MKDEBUG && _d("Copying value for $key from defaults");
      }
   }

   # Sanity check props
   foreach my $key ( keys %given_props ) {
      die "Unrecognized DSN part '$key' in '$dsn'\n"
         unless exists $opts{$key};
   }
   if ( (my $required = $self->prop('required')) ) {
      foreach my $key ( keys %$required ) {
         die "Missing DSN part '$key' in '$dsn'\n" unless $final_props{$key};
      }
   }

   return \%final_props;
}

sub as_string {
   my ( $self, $dsn ) = @_;
   return $dsn unless ref $dsn;
   return join(',',
      map  { "$_=" . ($_ eq 'p' ? '...' : $dsn->{$_}) }
      grep { defined $dsn->{$_} && $self->{opts}->{$_} }
      sort keys %$dsn );
}

sub usage {
   my ( $self ) = @_;
   my $usage
      = "DSN syntax is key=value[,key=value...]  Allowable DSN keys:\n"
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
                     qw(F h P S A))
         . ';mysql_read_default_group=mysql';
   }
   MKDEBUG && _d($dsn);
   return ($dsn, $info->{u}, $info->{p});
}

# Fills in missing info from a DSN after successfully connecting to the server.
sub fill_in_dsn {
   my ( $self, $dbh, $dsn ) = @_;
   my $vars = $dbh->selectall_hashref('SHOW VARIABLES', 'Variable_name');
   my ($user, $db) = $dbh->selectrow_array('SELECT USER(), DATABASE()');
   $user =~ s/@.*//;
   $dsn->{h} ||= $vars->{hostname}->{Value};
   $dsn->{S} ||= $vars->{'socket'}->{Value};
   $dsn->{P} ||= $vars->{port}->{Value};
   $dsn->{u} ||= $user;
   $dsn->{D} ||= $db;
}

sub get_dbh {
   my ( $self, $cxn_string, $user, $pass, $opts ) = @_;
   $opts ||= {};
   my $defaults = {
      AutoCommit        => 0,
      RaiseError        => 1,
      PrintError        => 0,
      mysql_enable_utf8 => ($cxn_string =~ m/charset=utf8/ ? 1 : 0),
   };
   @{$defaults}{ keys %$opts } = values %$opts;
   MKDEBUG && _d($cxn_string, ' ', $user, ' ', $pass, ' {',
      join(', ', map { "$_=>$defaults->{$_}" } keys %$defaults ), '}');
   my $dbh = DBI->connect($cxn_string, $user, $pass, $defaults);
   # Immediately set character set and binmode on STDOUT.
   if ( my ($charset) = $cxn_string =~ m/charset=(\w+)/ ) {
      my $sql = "/*!40101 SET NAMES $charset*/";
      MKDEBUG && _d("$dbh: $sql");
      $dbh->do($sql);
      MKDEBUG && _d('Enabling charset for STDOUT');
      if ( $charset eq 'utf8' ) {
         binmode(STDOUT, ':utf8')
            or die "Can't binmode(STDOUT, ':utf8'): $OS_ERROR";
      }
      else {
         binmode(STDOUT) or die "Can't binmode(STDOUT): $OS_ERROR";
      }
   }
   # If setvars exists and it's MySQL connection, set them
   my $setvars = $self->prop('setvars');
   if ( $cxn_string =~ m/mysql/i && $setvars ) {
      my $sql = "SET $setvars";
      MKDEBUG && _d("$dbh: $sql");
      $dbh->do($sql);
   }
   MKDEBUG && _d('DBH info: ',
      $dbh,
      Dumper($dbh->selectrow_hashref(
         'SELECT DATABASE(), CONNECTION_ID(), VERSION()/*!50038 , @@hostname*/')),
      ' Connection info: ', ($dbh->{mysql_hostinfo} || 'undef'),
      ' Character set info: ',
      Dumper($dbh->selectall_arrayref(
         'SHOW VARIABLES LIKE "character_set%"', { Slice => {}})),
      ' $DBD::mysql::VERSION: ', $DBD::mysql::VERSION,
      ' $DBI::VERSION: ', $DBI::VERSION,
   );
   return $dbh;
}

# Tries to figure out a hostname for the connection.
sub get_hostname {
   my ( $self, $dbh ) = @_;
   if ( my ($host) = ($dbh->{mysql_hostinfo} || '') =~ m/^(\w+) via/ ) {
      return $host;
   }
   my ( $hostname, $one ) = $dbh->selectrow_array(
      'SELECT /*!50038 @@hostname, */ 1');
   return $hostname;
}

# Disconnects a database handle, but complains verbosely if there are any active
# children.  These are usually $sth handles that haven't been finish()ed.
sub disconnect {
   my ( $self, $dbh ) = @_;
   MKDEBUG && $self->print_active_handles($dbh);
   $dbh->disconnect;
}

sub print_active_handles {
   my ( $self, $thing, $level ) = @_;
   $level ||= 0;
   printf("# Active %sh: %s %s %s\n", ($thing->{Type} || 'undef'), "\t" x $level,
      $thing, (($thing->{Type} || '') eq 'st' ? $thing->{Statement} || '' : ''))
      or die "Cannot print: $OS_ERROR";
   foreach my $handle ( grep {defined} @{ $thing->{ChildHandles} } ) {
      $self->print_active_handles->( $handle, $level + 1 );
   }
}

sub _d {
   my ($package, undef, $line) = caller 0;
   @_ = map { (my $temp = $_) =~ s/\n/\n# /g; $temp; }
        map { defined $_ ? $_ : 'undef' }
        @_;
   # Use $$ instead of $PID in case the package
   # does not use English.
   print "# $package:$line $$ ", @_, "\n";
}

1;

# ###########################################################################
# End DSNParser package
# ###########################################################################
