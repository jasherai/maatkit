#!/usr/bin/perl

use strict;
use warnings FATAL => 'all';
use English qw(-no_match_vars);
use Test::More tests => 18;

require '../mk-fk-error-logger';
require '../../common/MaatkitTest.pm';
require '../../common/Sandbox.pm';
my $dp = new DSNParser();
my $sb = new Sandbox(basedir => '/tmp', DSNParser => $dp);

my $dbh = $sb->get_dbh_for('master');
$sb->create_dbs($dbh, ['test']) if $dbh;

MaatkitTest->import(qw(load_file));

sub output {
   my $output = '';
   open my $output_fh, '>', \$output
      or BAIL_OUT("Cannot capture output to variable: $OS_ERROR");
   select $output_fh;
   eval { mk_fk_error_logger::main(@_); };
   close $output_fh;
   select STDOUT;
   return $EVAL_ERROR ? $EVAL_ERROR : $output;
}

# #############################################################################
# Test get_fk_error().
# #############################################################################
sub test_get_fk_error {
   my ( $file, $expected_ts, $expected_fke_file ) = @_;
   my $contents = load_file('mk-fk-error-logger/t/'.$file);
   chomp $contents;
   my ($ts, $fke) = mk_fk_error_logger::get_fk_error($contents);
   is(
      $ts,
      $expected_ts,
      "$file timestamp"
   );
   my $expected_fke = load_file('mk-fk-error-logger/t/'.$expected_fke_file);
   chomp $expected_fke;
   is(
      $fke,
      $expected_fke,
      "$file foreign key error text"
   );
   return;
}

test_get_fk_error(
   'samples/is001.txt',
   '070913 11:06:03',
   'samples/is001-fke.txt'
);

test_get_fk_error(
   'samples/is002.txt',
   '070915 15:10:24',
   'samples/is002-fke.txt'
);

test_get_fk_error(
   'samples/is003.txt',
   '070915 16:15:55',
   'samples/is003-fke.txt'
);

test_get_fk_error(
   'samples/is004.txt',
   '070915 16:23:09',
   'samples/is004-fke.txt'
);

test_get_fk_error(
   'samples/is005.txt',
   '070915 16:31:46',
   'samples/is005-fke.txt'
);

SKIP: {
   skip 'Cannot connect to sandbox master', 1 unless $dbh;

   `/tmp/12345/use -D test < samples/fke_tbl.sql`;

   # #########################################################################
   # Test saving foreign key errors to --dest.
   # #########################################################################

   # First, create a foreign key error.
   `/tmp/12345/use -D test < samples/fke.sql 1>/dev/null 2>/dev/null`;

   # Then get and save that fke.
   output('h=127.1,P=12345,u=msandbox,p=msandbox', '--dest', 'h=127.1,P=12345,D=test,t=foreign_key_errors');

   # And then test that it was actually saved.
   my $today = $dbh->selectall_arrayref('SELECT NOW()')->[0]->[0];
   ($today) = $today =~ m/(\d{4}-\d\d-\d\d)/;  # Just today's date.

   my $fke = $dbh->selectall_arrayref('SELECT * FROM test.foreign_key_errors');
   like(
      $fke->[0]->[0],  # Timestamp
      qr/$today/,
      'Saved foreign key error timestamp'
   );
   like(
      $fke->[0]->[1],  # Error
      qr/INSERT INTO child VALUES \(1, 9\)/,
      'Saved foreign key error'
   );

   # Check again to make sure that the same fke isn't saved twice.
   my $first_ts = $fke->[0]->[0];
   output('h=127.1,P=12345,u=msandbox,p=msandbox', '--dest', 'h=127.1,P=12345,D=test,t=foreign_key_errors');
   $fke = $dbh->selectall_arrayref('SELECT * FROM test.foreign_key_errors');
   is(
      $fke->[0]->[0],  # Timestamp
      $first_ts,
      "Doesn't save same error twice",
   );
   is(
      scalar @$fke,
      1,
      "Still only 1 saved error"
   );

   # Make another fk error which should be saved.
   sleep 1;
   $dbh->do('USE test');
   $dbh->do('INSERT INTO child VALUES (1, 2)');
   eval {
      $dbh->do('DELETE FROM parent WHERE id = 2');  # Causes foreign key error.
   };
   output('h=127.1,P=12345,u=msandbox,p=msandbox', '--dest', 'h=127.1,P=12345,D=test,t=foreign_key_errors');
   $fke = $dbh->selectall_arrayref('SELECT * FROM test.foreign_key_errors');
   like(
      $fke->[1]->[1],  # Error
      qr/DELETE FROM parent WHERE id = 2/,
      'Second foreign key error'
   );
   is(
      scalar @$fke,
      2,
      "Now 2 saved errors"
   );

   # ##########################################################################
   # Test printing the errors.
   # ##########################################################################
   sleep 1;
   $dbh->do('USE test');
   eval {
      $dbh->do('DELETE FROM parent WHERE id = 2');  # Causes foreign key error.
   };
   like(
      output('h=127.1,P=12345,u=msandbox,p=msandbox'),
      qr/DELETE FROM parent WHERE id = 2/,
      'Print foreign key error'
   );


   # Drop these manually because $sb->wipe_clean() may not do them in the
   # correct order causing a foreign key error that the next run of this
   # test will see.
   $dbh->do('DROP TABLE test.child');
   $dbh->do('DROP TABLE test.parent');


   # #########################################################################
   # Issue 391: Add --pid option to all scripts
   # #########################################################################
   `touch /tmp/mk-script.pid`;
   my $output = `../mk-fk-error-logger h=127.1,P=12345,u=msandbox,p=msandbox --print --pid /tmp/mk-script.pid 2>&1`;
   like(
      $output,
      qr{PID file /tmp/mk-script.pid already exists},
      'Dies if PID file already exists (--pid without --daemonize) (issue 391)'
   );
   `rm -rf /tmp/mk-script.pid`;

   $sb->wipe_clean($dbh);
   $dbh->disconnect();
};

# #############################################################################
# Done.
# #############################################################################
exit;
