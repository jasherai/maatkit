#!/usr/bin/perl

# This is a test for mysql-table-sync.  It depends on other tools in the
# toolkit.
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

# Make the file's Perl version the same as its CVS revision number.
# our $VERSION = sprintf "%d.%03d", q$Revision$ =~ /(\d+)/g;
our $VERSION = '@VERSION@';

# ############################################################################
# Get configuration information.
# ############################################################################

# Define cmdline args; each is GetOpt::Long spec, whether required,
# human-readable description.  Add more hash entries as needed.
my @opt_spec = (
   { s => 'database|D=s', d => 'Database to use' },
   { s => 'host|h=s',     d => 'Connect to host' },
   { s => 'help',         d => 'Show this help message' },
   { s => 'password|p=s', d => 'Password to use when connecting' },
   { s => 'port|P=i',     d => 'Port number to use for connection' },
   { s => 'socket|S=s',   d => 'Socket file to use for connection' },
   { s => 'user|u=s',     d => 'User for login if not current user' },
   { s => 'tests|t=i',    d => 'Number of tests to run' },
   { s => 'size|s=i',     d => 'Size of test tables, default 500 rows' },
   { s => 'algorithm|a=s', d => 'Algorithm' },
);

# This is the container for the command-line options' values to be stored in
# after processing.  Initial values are defaults.
my %opts = ( a => 'topdown', t => 1, s => 500 );
# Post-process...
my %opt_seen;
foreach my $spec ( @opt_spec ) {
   my ( $long, $short ) = $spec->{s} =~ m/^(\w+)(?:\|([^!+=]*))?/;
   $spec->{k} = $short || $long;
   $spec->{l} = $long;
   $spec->{t} = $short;
   $spec->{n} = $spec->{s} =~ m/!/;
   $opts{$spec->{k}} = undef unless defined $opts{$spec->{k}};
   die "Duplicate option $spec->{k}" if $opt_seen{$spec->{k}}++;
}

Getopt::Long::Configure('no_ignore_case', 'bundling');
GetOptions( map { $_->{s} => \$opts{$_->{k}} } @opt_spec) or $opts{help} = 1;

# If a filename or other argument(s) is required after the other arguments,
# add "|| !@ARGV" inside the parens on the next line.
if ( $opts{help} ) {
   print "Usage: $PROGRAM_NAME <options> batch-file\n\n";
   foreach my $spec ( sort { $a->{l} cmp $b->{l} } @opt_spec ) {
      my $long  = $spec->{n} ? "[no]$spec->{l}" : $spec->{l};
      my $short = $spec->{t} ? "-$spec->{t}" : '';
      printf("  --%-13s %-4s %s\n", $long, $short, $spec->{d});
   }
   print <<USAGE;

$PROGRAM_NAME tests mysql-table-sync.

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
my $dbh = DBI->connect($dsn, @opts{qw(u p)}, { AutoCommit => 1, RaiseError => 1, PrintError => 1 } )
   or die("Can't connect to DB: $OS_ERROR");

my $i = 0;
while ( $i++ < $opts{t} ) {
   print `mysql-random-table -d -s $opts{s}`;
   map { $dbh->do("drop table if exists test$_") } 2..3;
   $dbh->do("create table test2 like test1");
   $dbh->do("insert into test2 select * from test1");
   $dbh->do("create table test3 like test1");
   $dbh->do("insert into test3 select * from test1");
   random_perturb();
   my $bad = `mysql-table-checksum -t test1,test2,test3 localhost`;
   my @bad = $bad =~ m/([a-f0-9]{32})/g;
   if ( unique(@bad) < 2 ) {
      die "Tables aren't different before starting: $bad.";
   }
   `mysql-table-sync test2 test3 -a $opts{a} -x`;
   my $good = `mysql-table-checksum -t test1,test2,test3 localhost`;
   my @good = $good =~ m/([a-f0-9]{32})/g;
   if ( !$good || unique(@good) > 1 ) {
      die "Tables are different after fixing: $good";
   }
   print "Test $i OK\n";
}

sub unique {
   my %seen;
   grep { !$seen{$_}++ } @_;
}

sub random_perturb {
   my $changes = 0;
   my $goal    = 1 + int(rand() * $opts{s});
   my @cols =
      map  { $_->{Field} }
      grep { !$_->{Key} }
      @{$dbh->selectall_arrayref("DESCRIBE test1", { Slice => {} })};
   while ( $changes < $goal ) {
      if ( rand() < .3) {
         # do some deletes
         $changes += $dbh->do("delete from test3 order by rand() limit " .
         int(rand()*$opts{s}/100));
      }
      else {
         my $col = $cols[int(rand() * @cols)];
         my $query = "update test3 set $col = $col + 1 order by rand(0) limit 1";
         $changes += $dbh->do($query);
      }
   }
}
