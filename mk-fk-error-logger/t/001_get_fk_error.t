#!/usr/bin/env perl

BEGIN {
   die "The MAATKIT_WORKING_COPY environment variable is not set.  See http://code.google.com/p/maatkit/wiki/Testing"
      unless $ENV{MAATKIT_WORKING_COPY} && -d $ENV{MAATKIT_WORKING_COPY};
   unshift @INC, "$ENV{MAATKIT_WORKING_COPY}/common";
};

use strict;
use warnings FATAL => 'all';
use English qw(-no_match_vars);
use Test::More tests => 10;

use MaatkitTest;
require "$trunk/mk-fk-error-logger/mk-fk-error-logger";

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

# #############################################################################
# Done.
# #############################################################################
exit;
