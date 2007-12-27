#!/usr/bin/perl

use strict;
use warnings FATAL => 'all';

use Test::More tests => 6;
use DBI;

my $opt_file = shift || "~/.my.cnf";
my ( $output );
my $dbh;

sub query {
   $dbh->selectall_arrayref(@_, {Slice => {}});
}

sub run {
   my ($src, $dst, $other) = @_;
   my $cmd = "perl ../mk-table-sync -px D=test,t=$src t=$dst $other";
   chomp(my $output=`$cmd`);
   return $output;
}

# Open a connection to MySQL, or skip the rest of the tests.
eval {
   $dbh = DBI->connect(
   "DBI:mysql:;mysql_read_default_group=mysql", undef, undef,
   { PrintError => 0, RaiseError => 1 })
};
SKIP: { skip 'Cannot connect to MySQL', 1 unless $dbh;

   `mysql --defaults-file=$opt_file < before.sql`;

   $output = run('test1', 'test2', '-a Stream');
   is($output, "INSERT INTO `test`.`test2`(`a`, `b`) VALUES (1, 'en');
INSERT INTO `test`.`test2`(`a`, `b`) VALUES (2, 'ca');", 'Basic Stream sync');

   is_deeply(
      query('select * from test.test2'),
      [ {   a => 1, b => 'en' }, { a => 2, b => 'ca' } ],
      'Synced OK with Stream'
   );

   `mysql --defaults-file=$opt_file < before.sql`;

   $output = run('test1', 'test2', '-a Chunk');
   is($output, "INSERT INTO `test`.`test2`(`a`, `b`) VALUES (1, 'en');
INSERT INTO `test`.`test2`(`a`, `b`) VALUES (2, 'ca');", 'Basic Chunk sync');

   is_deeply(
      query('select * from test.test2'),
      [ {   a => 1, b => 'en' }, { a => 2, b => 'ca' } ],
      'Synced OK with Chunk'
   );

   `mysql --defaults-file=$opt_file < before.sql`;

   $output = run('test1', 'test2', '-a Nibble');
   is($output, "INSERT INTO `test`.`test2`(`a`, `b`) VALUES (1, 'en');
INSERT INTO `test`.`test2`(`a`, `b`) VALUES (2, 'ca');", 'Basic Nibble sync');

   is_deeply(
      query('select * from test.test2'),
      [ {   a => 1, b => 'en' }, { a => 2, b => 'ca' } ],
      'Synced OK with Nibble'
   );

# TODO: do a test run for all possible combinations of these:
=pod
   my %args = (
      lock => [qw(1 2 3)],
      transaction => [''],
      algorithm => [qw(Stream Chunk)],
      bufferresults => [''],
      columns => [qw(b)],
      replace => [''],
      skipbinlog => [''],
      skipforeignkey => [''],
      skipuniquekey   => [''],
      verbose => [''],
      wait => [''],
      where => [qw('a>0')],
   );
   my @argkeys = sort keys %args;
=cut

# TODO Ensure wacky collations and callbacks to MySQL to compare collations don't
# cause problems.
# my $output = `../mk-table-sync --print -a bottomup D=test,t=test1 t=test2`;
# my $expected = "DELETE FROM `test`.`test2` WHERE (`a` = '2' AND `b` = 'é');\n"
#             . "INSERT INTO `test`.`test2`(`a`,`b`) VALUES('2','ca');\n";
#is($output, $expected, "Funny characters got synced okay");

   `mysql --defaults-file=$opt_file < after.sql`;

}
