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
   D => { s => 'database|D=s', r => 0, d => 'Database to use' },
   h => { s => 'host|h=s',     r => 0, d => 'Connect to host' },
   l => { s => 'help',         r => 0, d => 'Show this help message' },
   P => { s => 'port|P=i',     r => 0, d => 'Database server port' },
   S => { s => 'socket|S=s',   r => 0, d => 'Socket file to use for connection' },
   p => { s => 'pass|p=s',     r => 0, d => 'Database password' },
   u => { s => 'user|u=s',     r => 0, d => 'User for login if not current user' },
);

# Define the order cmdline opts will appear in help output.  Add any extra ones
# defined above.  If it's not in this list, it's not an option to this
# program.  Note that 'h' is host and 'l' is help.
my @opt_keys = qw( D h p P S u l );

# This is the container for the command-line options' values to be stored in
# after processing.  Initial values are defaults.
my %opts = (
   D => undef,
   h => undef,
   P => undef,
   p => undef,
   u => undef,
   S => undef,
);

Getopt::Long::Configure('no_ignore_case', 'bundling');
GetOptions( map { $opt_spec{$_}->{s} => \$opts{$_} }  @opt_keys );

# If a filename or other argument(s) is required after the other arguments,
# add "|| !@ARGV" inside the parens on the next line.
if ( $opts{l} || grep { !$opts{$_} && $opt_spec{$_}->{r} } @opt_keys ) {
   print "Usage: $PROGRAM_NAME <options> batch-file\n\n  Options:\n\n";
   foreach my $key ( @opt_keys ) {
      my ( $long, $short ) = $opt_spec{$key}->{s} =~ m/^(\w+)(?:\|([^!+=]*))?/;
      $long  = "[no]$long" if $opt_spec{$key}->{s} =~ m/!/;
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

# ############################################################################
# Get ready to do the main work.
# ############################################################################
my %conn = ( h => 'host', P => 'port', S => 'socket');

# Connect to the database
my $dsn = 'DBI:mysql:' . ( $opts{D} || '' ) . ';'
   . join(';', map  { "$conn{$_}=$opts{$_}" } grep { defined $opts{$_} } qw(h P S))
   . ';mysql_read_default_group=mysql';
   print $dsn, "\n";
   exit;
my $dbh = DBI->connect($dsn, @opts{qw(u p)}, { AutoCommit => 1, RaiseError => 1, PrintError => 1 } )
   or die("Can't connect to DB: $OS_ERROR");
