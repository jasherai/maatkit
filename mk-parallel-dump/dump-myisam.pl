#!/usr/bin/perl
# TODO: add an option to dump tables afte rlock released if not changed recently

use strict;
use warnings;

use DBI;
use Data::Dumper;


my $dbh = DBI->connect('DBI:mysql:;host=localhost;', undef, undef, # 'markus', 'n59034xM', 
   { RaiseError => 1, AutoCommit => 0 });

my @tables;

my @dbs = grep { $_ !~ m/information_schema/ } @{$dbh->selectcol_arrayref('show databases')};

my @tbls;
foreach my $db ( @dbs ) {
   my $tbls = $dbh->selectall_arrayref('show table status from ' . $db, { Slice
   => {} } );
   push @tbls, map {
      { db => $db,
      tbl => $_->{Name},
      e => $_->{Engine},
      }
   } @$tbls;
}

my @innodb = grep { $_->{e} eq 'InnoDB' } @tbls;
my @others = grep { $_->{e} ne 'InnoDB' } @tbls;

$dbh->do('flush tables with read lock');
$dbh->commit;
$dbh->do('start transaction with consistent snapshot');
# TODO: verify that innodb status shows for my connection_id() this:
# ---TRANSACTION 0 916744, ACTIVE 42 sec, process no 5373, OS thread id
# 1144695120
# MySQL thread id 15, query id 534 localhost baron
# Trx read view will not see trx with id >= 0 916745, sees < 0 916745
# TODO: no need to do this.
my $master_status = $dbh->selectall_arrayref('show master status');
print Dumper($master_status);
my @to_lock = map { "$_->{db}.$_->{tbl} READ" } @others;
my $sql = "LOCK TABLES " . join(", ", @to_lock);
$dbh->do($sql);

use File::Spec;
my $curdir = File::Spec->rel2abs('.');

foreach my $tbl ( @others ) {
   my $db = $tbl->{db};
   my $tbl = $tbl->{tbl};
   if ( !-d $db ) {
      mkdir $db or die "Can't make $db: $!";
      chmod 0777, $db or die "Can't chmod $db: $!";
   }
    # todo: $tbl is a string now
   my $sql = "SELECT /*$tbl->{e}*/ * INTO OUTFILE '$curdir/$db/$tbl.txt' FROM $db.$tbl";
   print $sql, "\n";
   $dbh->do($sql);
}

$dbh->do('unlock tables');

# TODO verify still have txn open
#


foreach my $tbl ( @innodb ) {
   my $db = $tbl->{db};
   my $tbl = $tbl->{tbl};
   if ( !-d $db ) {
      mkdir $db or die "Can't make $db: $!";
      chmod 0777, $db or die "Can't chmod $db: $!";
   }
   my $sql = "SELECT /*$tbl->{e}*/ * INTO OUTFILE '$curdir/$db/$tbl.txt' FROM $db.$tbl";
   print $sql, "\n";
   $dbh->do($sql);
}

print "done!\n";

$dbh->disconnect;
