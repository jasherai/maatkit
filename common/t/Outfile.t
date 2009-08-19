#!/usr/bin/perl

use strict;
use warnings FATAL => 'all';
use English qw(-no_match_vars);
use Test::More tests => 1;

require "../MaatkitTest.pm";
require "../Outfile.pm";

MaatkitTest->import(qw(load_file));

# This is just for grabbing stuff from fetchrow_arrayref()
# instead of writing test rows by hand.
require '../DSNParser.pm';
require '../Sandbox.pm';
use Data::Dumper;
$Data::Dumper::Indent    = 1;
$Data::Dumper::Sortkeys  = 1;
$Data::Dumper::Quotekeys = 0;
my $dp  = new DSNParser();
my $sb  = new Sandbox(basedir => '/tmp', DSNParser => $dp);
my $dbh = $sb->get_dbh_for('master');
#print Dumper($dbh->selectall_arrayref('SELECT * FROM test.t'));
#exit;

my $outfile = new Outfile();

sub no_diff {
   my ( $rows, $expected_output ) = @_;
   my $tmp_file = '/tmp/Outfile-output.txt';
   open my $fh, '>', $tmp_file or die "Cannot open $tmp_file: $OS_ERROR";
   $outfile->write($fh, $rows);
   close $fh;
   my $retval = system("diff $tmp_file $expected_output");
   `rm -rf $tmp_file`;
   $retval = $retval >> 8;
   return !$retval;
}


ok(
   no_diff(
      [
         [
          '1',
          'a',
          'some text',
          '3.14',
          '5.08',
          'Here\'s more complex text that has "quotes", and maybe a comma.',
          '2009-08-19 08:48:08',
          '2009-08-19 08:48:08'
         ],
         [
          '2',
          '',
          'the char and text are blank, the',
          undef,
          '5.09',
          '',
          '2009-08-19 08:49:17',
          '2009-08-19 08:49:17'
         ]
      ],
      'samples/outfile001.txt',
   ),
   'outfile001.txt'
);

# #############################################################################
# Done.
# #############################################################################
exit;
