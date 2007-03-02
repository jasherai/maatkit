#!/usr/bin/perl

# This is a skeleton file for a Perl script that uses MySQL.  You are welcome
# to base your own scripts on it.
#
# This program is copyright (c) 2007 Baron Schwartz, baron at xaprb dot com.
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

use strict;
use warnings FATAL => 'all';

use DBI;
use English qw(-no_match_vars);
use Getopt::Long;
use Term::ReadLine;

# Make the file's Perl version the same as its CVS revision number.
# our $VERSION = sprintf "%d.%03d", q$Revision$ =~ /(\d+)/g;
our $VERSION = '@VERSION@';

# ############################################################################
# Get configuration information.
# ############################################################################

# Define cmdline args; each is GetOpt::Long spec, whether required,
# human-readable description.  Add more hash entries as needed.
my %opt_spec = (
   d => { s => 'database|d=s', r => 0, d => 'Database' },
   h => { s => 'host|h=s',     r => 0, d => 'Database server hostname' },
   l => { s => 'help',         r => 0, d => 'Show this help message' },
   o => { s => 'port|P=i',     r => 0, d => 'Database server port' },
   p => { s => 'pass|p=s',     r => 0, d => 'Database password' },
   u => { s => 'user|u=s',     r => 0, d => 'Database username' },
);

# Define the order cmdline opts will appear in help output.  Add any extra ones
# defined above.  If it's not in this list, it's not an option to this
# program.  Note that 'h' is host and 'l' is help.
my @opt_keys = qw( h d o u p l );

# This is the container for the command-line options' values to be stored in
# after processing.  Initial values are defaults.
my %opts = (
   d => '',
   h => '',
   o => 3306,
   p => undef,
   u => undef,
);

Getopt::Long::Configure('no_ignore_case', 'bundling');
GetOptions( map { $opt_spec{$_}->{s} => \$opts{$_} }  @opt_keys );

# If a filename or other argument(s) is required after the other arguments,
# add "|| !@ARGV" inside the parens on the next line.
if ( $opts{l} || grep { !$opts{$_} && $opt_spec{$_}->{r} } @opt_keys ) {
   print "Usage: $PROGRAM_NAME <options> batch-file\n\n  Options:\n\n";
   foreach my $key ( @opt_keys ) {
      my ( $long, $short ) = $opt_spec{$key}->{s} =~ m/^(\w+)(?:\|([^=]*))?/;
      $long  = "--$long" . ( $short ? ',' : '' );
      $short = $short ? " -$short" : '';
      printf("  %-13s %-4s %s\n", $long, $short, $opt_spec{$key}->{d});
   }
   print <<USAGE;

$PROGRAM_NAME does something or other.

If possible, database options are read from your .my.cnf file.
For more details, please read the documentation:

   perldoc $PROGRAM_NAME

USAGE
   exit(1);
}

# This will end up containing what's needed to connect to MySQL.
my $conn = {
   h  => $opts{h},
   db => $opts{d},
   u  => $opts{u},
   p  => $opts{p},
   o  => $opts{o},
};

if ( grep { !$conn->{$_} } keys %$conn ) {
   # Try to use the user's .my.cnf file.
   eval {
      my $homedir = $ENV{HOME} || $ENV{HOMEPATH} || $ENV{USERPROFILE};
      open my $conf_file, "<", "$homedir/.my.cnf" or die $OS_ERROR;
      while ( my $line = <$conf_file> ) {
         chomp $line;
         $line =~ s/(^\s*)|(\s*#.*$)//g;
         next unless $line;
         my ( $key, $val ) = split( /\s*=\s*/, $line );
         next unless defined $val;
         if ( $key eq 'host' )     { $conn->{h}  ||= $val; }
         if ( $key eq 'user' )     { $conn->{u}  ||= $val; }
         if ( $key =~ m/^pass/ )   { $conn->{p}  ||= $val; }
         if ( $key eq 'database' ) { $conn->{db} ||= $val; }
         if ( $key eq 'port' )     { $conn->{o}  ||= $val; }
      }
      close $conf_file;
   };
   if ( $EVAL_ERROR && $EVAL_ERROR !~ m/No such file/ ) {
      print "I tried to read your .my.cnf file, but got '$EVAL_ERROR'\n";
   }
}

# Fill in defaults for some things
$conn->{h} ||= 'localhost';
$conn->{u} ||= getlogin() || getpwuid($UID);

my %prompts = (
   o  => "Port number: ",
   h  => "Database host: ",
   u  => "Database user: ",
   p  => "Database password: ",
   db => "Database: ",
);

# If anything remains, prompt the terminal
my $term;
foreach my $thing ( grep { !defined $conn->{$_} } keys %$conn ) {
   $term ||= Term::ReadLine->new('terminal');
   $conn->{$thing} = $term->readline($prompts{$thing});
}

# ############################################################################
# Get ready to do the main work.
# ############################################################################

# Connect to the database
my $dbh = DBI->connect(
   "DBI:mysql:database=$conn->{db};host=$conn->{h};port=$conn->{o}",
   $conn->{u}, $conn->{p}, { AutoCommit => 1, RaiseError => 1, PrintError => 1 } )
   or die("Can't connect to DB: $!");
