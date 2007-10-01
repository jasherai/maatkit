#!/usr/bin/perl

# This is a skeleton file for a Perl script that uses MySQL.  You are welcome
# to base your own scripts on it.
#
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

use strict;
use warnings FATAL => 'all';

use DBI;
use English qw(-no_match_vars);
use Getopt::Long;
use List::Util qw(max);
use Term::ReadKey;

our $VERSION = '@VERSION@';
our $DISTRIB = '@DISTRIB@';
our $SVN_REV = sprintf("%d", q$Revision$ =~ m/(\d+)/g || 0);

# ############################################################################
# Get configuration information.
# ############################################################################

# Define cmdline args; each is GetOpt::Long spec, whether required,
# human-readable description.  Add more hash entries as needed.
my @opt_spec = (
   { s => 'askpass',           d => 'Prompt for password for connections' },
   { s => 'database|D=s',      d => 'Database to use' },
   { s => 'defaults-file|F=s', d => 'Only read default options from the given file' },
   { s => 'host|h=s',          d => 'Connect to host' },
   { s => 'help',              d => 'Show this help message' },
   { s => 'password|p=s',      d => 'Password to use when connecting' },
   { s => 'port|P=i',          d => 'Port number to use for connection' },
   { s => 'socket|S=s',        d => 'Socket file to use for connection' },
   { s => 'user|u=s',          d => 'User for login if not current user' },
   { s => 'version',           d => 'Output version information and exit' },
);

# This is the container for the command-line options' values to be stored in
# after processing.  Initial values are defaults.
my %opts;
# Post-process...
my %opt_seen;
foreach my $spec ( @opt_spec ) {
   my ( $long, $short ) = $spec->{s} =~ m/^([\w-]+)(?:\|([^!+=]*))?/;
   $spec->{k} = $short || $long;
   $spec->{l} = $long;
   $spec->{t} = $short;
   $spec->{n} = $spec->{s} =~ m/!/;
   $opts{$spec->{k}} = undef unless defined $opts{$spec->{k}};
   die "Duplicate option $spec->{k}" if $opt_seen{$spec->{k}}++;
}

Getopt::Long::Configure('no_ignore_case', 'bundling');
GetOptions( map { $_->{s} => \$opts{$_->{k}} } @opt_spec) or $opts{help} = 1;

if ( $opts{version} ) {
   print "$PROGRAM_NAME  Ver $VERSION Distrib $DISTRIB Changeset $SVN_REV\n";
   exit(0);
}

# If a filename or other argument(s) is required after the other arguments,
# add "|| !@ARGV" inside the parens on the next line.
if ( $opts{help} ) {
   print "Usage: $PROGRAM_NAME <options> batch-file\n\n";
   my $maxw = max(map { length($_->{l}) + ($_->{n} ? 4 : 0)} @opt_spec);
   foreach my $spec ( sort { $a->{l} cmp $b->{l} } @opt_spec ) {
      my $long  = $spec->{n} ? "[no]$spec->{l}" : $spec->{l};
      my $short = $spec->{t} ? "-$spec->{t}" : '';
      printf("  --%-${maxw}s %-4s %s\n", $long, $short, $spec->{d});
   }
   (my $usage = <<"   USAGE") =~ s/^      //gm;

      $PROGRAM_NAME does something or other.

      If possible, database options are read from your .my.cnf file.
      For more details, please read the documentation:

         perldoc $PROGRAM_NAME

   USAGE
   print $usage;
   exit(0);
}

# ############################################################################
# Get ready to do the main work.
# ############################################################################
my %conn = (
   F => 'mysql_read_default_file',
   h => 'host',
   P => 'port',
   S => 'mysql_socket'
);

# Connect to the database
if ( !$opts{p} && $opts{askpass} ) {
   print "Enter password: ";
   ReadMode('noecho');
   chomp($opts{p} = <STDIN>);
   ReadMode('normal');
   print "\n";
}

my $dsn = 'DBI:mysql:' . ( $opts{D} || '' ) . ';'
   . join(';', map  { "$conn{$_}=$opts{$_}" } grep { defined $opts{$_} } qw(F h P S))
   . ';mysql_read_default_group=mysql';
my $dbh = DBI->connect($dsn, @opts{qw(u p)}, { AutoCommit => 1, RaiseError => 1, PrintError => 0 } );
