#!/usr/bin/perl

use strict;
use warnings FATAL => 'all';
use English qw(-no_match_vars);
use Test::More tests => 8;

require "../ChangeHandler.pm";
require "../Quoter.pm";
require '../DSNParser.pm';
require '../Sandbox.pm';
my $dp = new DSNParser();
my $sb = new Sandbox(basedir => '/tmp', DSNParser => $dp);

my $dbh = $sb->get_dbh_for('master');

sub throws_ok {
   my ( $code, $pat, $msg ) = @_;
   eval { $code->(); };
   like ( $EVAL_ERROR, $pat, $msg );
}

throws_ok(
   sub { new ChangeHandler() },
   qr/I need a Quoter/,
   'Needs a Quoter',
);

my @rows;
my $ch = new ChangeHandler(
   Quoter  => new Quoter(),
   dst_db  => 'test',
   dst_tbl => 'foo',
   src_db  => 'test',
   src_tbl => 'test1',
   actions => [ sub { push @rows, @_ } ],
   replace => 0,
   queue   => 0,
);

$ch->change('INSERT', { a => 1, b => 2 }, [qw(a)] );

is_deeply(\@rows,
   ['INSERT INTO `test`.`foo`(`a`, `b`) VALUES (1, 2)',],
   'First row',
);

$ch->{queue} = 1;

$ch->change('DELETE', { a => 1, b => 2 }, [qw(a)] );

is_deeply(\@rows,
   ['INSERT INTO `test`.`foo`(`a`, `b`) VALUES (1, 2)',],
   'Second row not there yet',
);

$ch->process_rows(1);

is_deeply(\@rows,
   [
   'INSERT INTO `test`.`foo`(`a`, `b`) VALUES (1, 2)',
   'DELETE FROM `test`.`foo` WHERE `a`=1 LIMIT 1',
   ],
   'Second row there',
);
$ch->{queue} = 2;

$ch->change('UPDATE', { a => 1, b => 2 }, [qw(a)] );
$ch->process_rows(1);

is_deeply(\@rows,
   [
   'INSERT INTO `test`.`foo`(`a`, `b`) VALUES (1, 2)',
   'DELETE FROM `test`.`foo` WHERE `a`=1 LIMIT 1',
   ],
   'Third row not there',
);

$ch->process_rows();

is_deeply(\@rows,
   [
   'INSERT INTO `test`.`foo`(`a`, `b`) VALUES (1, 2)',
   'DELETE FROM `test`.`foo` WHERE `a`=1 LIMIT 1',
   'UPDATE `test`.`foo` SET `b`=2 WHERE `a`=1 LIMIT 1',
   ],
   'All rows',
);

is_deeply(
   { $ch->get_changes() },
   { REPLACE => 0, DELETE => 1, INSERT => 1, UPDATE => 1 },
   'Changes were recorded',
);

SKIP: {
   skip 'Cannot connect to sandbox master', 1 unless $dbh;

   $dbh->do('CREATE DATABASE IF NOT EXISTS test');

   @rows = ();
   $ch->{queue} = 0;
   $ch->fetch_back($dbh);
   `/tmp/12345/use < samples/before-TableSyncChunk.sql`;
   # This should cause it to fetch the row from test.test1 where a=1
   $ch->change('UPDATE', { a => 1, __foo => 'bar' }, [qw(a)] );
   $ch->change('DELETE', { a => 1, __foo => 'bar' }, [qw(a)] );
   $ch->change('INSERT', { a => 1, __foo => 'bar' }, [qw(a)] );
   is_deeply(
      \@rows,
      [
         "UPDATE `test`.`foo` SET `b`='en' WHERE `a`=1 LIMIT 1",
         "DELETE FROM `test`.`foo` WHERE `a`=1 LIMIT 1",
         "INSERT INTO `test`.`foo`(`a`, `b`) VALUES (1, 'en')",
      ],
      'Fetch-back',
   );
}

# #############################################################################
# Done.
# #############################################################################
$sb->wipe_clean($dbh);
exit;
