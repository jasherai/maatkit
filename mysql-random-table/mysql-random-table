#!/usr/bin/perl

# This is a test for mysql-table-sync.  It depends on mysql-table-checksum.
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
my %opts = ( t => 1, s => 500 );
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

my @types = qw(tinyint int smallint mediumint bigint date datetime timestamp);

my $i = 0;
while ( $i++ < $opts{t} ) {
   my ( $tbl, $pk, $cols ) = generate_random_table();
   map { $dbh->do("drop table if exists test$_") } 1..3;
   $dbh->do($tbl);
   insert_data($pk, $cols);
   $dbh->do("create table test2 like test1");
   $dbh->do("insert into test2 select * from test1");
   $dbh->do("create table test3 like test1");
   $dbh->do("insert into test3 select * from test1");
   random_perturb($pk, $cols);
   `mysql-table-checksum -t test1,test2,test3 localhost`;
   #`mysql-table-sync test2 test3 -a $opts{a} -x`;
   my $lines = `mysql-table-checksum -t test1,test2,test3 localhost`;
   print $lines;
}

sub random_perturb {
   my ( $pk, $cols ) = @_;
   foreach ( @$pk ) {
      shift @$cols;
   }

   if ( rand() < .3) {
      # do some deletes
      $dbh->do("delete from test3 order by rand() limit " .
      int(rand()*$opts{s}/100));
   }
   if ( rand() < .67 ) {
      my $col = $cols->[int(rand() * @$cols)];
      $dbh->do("update test3 set $col->{name} = $col->{name} + 1 order by rand() limit 1");
   }
}


sub insert_data {
   my ( $pk, $cols ) = @_;
   foreach my $i ( 0 .. $opts{s} ) {
      my $sql = "insert ignore into test1("
         . join(",", map{$_->{name}}@$cols)
         . ") values ("
         . join(",", map{generate_val($_->{type})} @$cols)
         . ")";
      $dbh->do($sql);
   }
}

sub generate_val {
   my $type = shift;
   my $val = $type =~ m/int/ ? rand_int($type)
           : $type =~ m/date|time/ ? rand_date($type)
           : die($type . ' is not a type I know');
   return $dbh->quote($val);
}

sub rand_int {
   my ( $type ) = @_;
   my $limit = $type eq 'tinyint' ? 255
             : $type eq 'int'     ? 2147483647
             : $type eq 'smallint' ? 32767
             : $type eq 'mediumint' ? 8388607
             :                        922337203685;
   return int(rand() * $limit);
}

sub rand_date {
   my $type = shift;
   my $fmt = $type =~ m/time/ ? '%4d-%02d-%02d %02d:%02d:%02d' : '%4d-%02d-%02d';
   my $year = 1900 + rand() * 200;
   my $mon = 1 + rand() * 12;
   my $day = 1 + rand() * 28;
   if ( $type !~ m/time/ ) {
      return sprintf($fmt,$year,$mon, $day);
   }
   my $hr = rand() * 24;
   my $min = rand() * 60;
   my $sec = rand() * 60;
   return sprintf($fmt,$year,$mon, $day,$hr,$min,$sec);
}

sub generate_random_table {
   my $num_cols = int(5 + rand() * 20);
   my $pk = 1 + int(rand() * 3);
   my @cols;
   foreach my $i ( 1 .. $num_cols ) {
      my $col = generate_coldef($i, $i <= $pk);
      push @cols, $col;
   }
   my $sql = "create table test1(" . join(",", map { $_->{def} }@cols)
      . ", primary key(" . join(",", map { $_->{name} }@cols[0..$pk])
      . "))engine=innodb";
   return ($sql, [ @cols[0..$pk] ], [ @cols ]);
}

sub generate_coldef {
   my ( $i, $notnull ) = @_;
   my $type = $types[int(rand() * @types)];
   $notnull = $notnull || rand() > .5 ? 'not null' : '';
   return {
      name => "col$i",
      type => $type,
      def => "col$i $type $notnull",
   };
}
