#!/usr/bin/env perl

BEGIN {
   die "The MAATKIT_WORKING_COPY environment variable is not set.  See http://code.google.com/p/maatkit/wiki/Testing"
      unless $ENV{MAATKIT_WORKING_COPY} && -d $ENV{MAATKIT_WORKING_COPY};
   unshift @INC, "$ENV{MAATKIT_WORKING_COPY}/common";
};

use strict;
use warnings FATAL => 'all';
use English qw(-no_match_vars);
use Test::More tests => 14;

use MaatkitTest;
require "$trunk/mk-error-log/mk-error-log";

my $output;
my $sample = "$trunk/common/t/samples/errlogs/";

# trf => 'sort' because mk-error-log sorts its output by the
# events' count and the events come from a hash so events with
# the same count are printed together but in random order.
# So the output isn't what the user would normally see; e.g.
# the first header line appears at the bottom.

my $resume_file = '/tmp/mk-error-log-resume.txt';
my $sample_file = '/tmp/errlog008.txt';

diag(`rm -rf $resume_file >/dev/null`);
diag(`rm -rf $sample_file >/dev/null`);
diag(`cp $sample/errlog008.txt $sample_file`);

my $inode = (stat($sample_file))[1];
my $size  = -s $sample_file;
my $pos   = 0;

ok(
   no_diff(
      sub { mk_error_log::main($sample_file, '--resume', $resume_file) },
      "mk-error-log/t/samples/errlog008-report-resume-pos-0.txt",
      trf => 'sort'
   ),
   'First run'
);

ok(
   -f $resume_file,
   'Created resume file'
);

$output = `cat $resume_file`;
is(
   $output,
"file:$sample_file
inode:$inode
pos:$size
size:$size
",
   "Resume file contents"
);

# Add more data to sample file beyond where we just left off.

diag(`echo "091205 04:49:10  mysqld took a nap" >> $sample_file`);
$pos  = $size;
$size = -s $sample_file;

is(
   output(
      sub { mk_error_log::main($sample_file, '--resume', $resume_file) },
   ),
"Resuming $sample_file at position $pos
Count Level   Message
===== ======= =================
    1 unknown mysqld took a nap
",
   'Second run'
);

$output = `cat $resume_file`;
is(
   $output,
"file:$sample_file
inode:$inode
pos:$size
size:$size
",
   "Updated resume file contents"
);

# And again for good measure.

diag(`echo "091205 04:49:10  mysqld fell asleep" >> $sample_file`);
$pos  = $size;
$size = -s $sample_file;

is(
   output(
      sub { mk_error_log::main($sample_file, '--resume', $resume_file) },
   ),
"Resuming $sample_file at position $pos
Count Level   Message
===== ======= ==================
    1 unknown mysqld fell asleep
",
   'Third run'
);

$output = `cat $resume_file`;
is(
   $output,
"file:$sample_file
inode:$inode
pos:$size
size:$size
",
   "Updated resume file contents again"
);


# Try to trick it by reducing the file.  It should resume
# from pos 0.

diag(`cp $sample/errlog008.txt $sample_file`);

$inode = (stat($sample_file))[1];
$size  = -s $sample_file;

{
   my $output = '';
   local *STDERR;
   open STDERR, '>', \$output;

   ok(
      no_diff(
         sub { mk_error_log::main($sample_file, '--resume', $resume_file) },
         "mk-error-log/t/samples/errlog008-report-resume-pos-0.txt",
         trf => 'sort',
      ),
      'Forth run'
   );

   like(
      $output,
      qr/is less than current file size/,
      "Warns that resume size < current file size"
   );
}

$output = `cat $resume_file`;
is(
   $output,
"file:$sample_file
inode:$inode
pos:$size
size:$size
",
   "Restored resume file contents"
);

# Now fake like the log has been rotated.

diag(`cp $sample_file $sample_file-1 ; rm $sample_file ; mv $sample_file-1 $sample_file`);
my $inode2 = (stat($sample_file))[1];

cmp_ok(
   $inode,
   '!=',
   $inode2,
   'Different inodes'
);

ok(
   no_diff(
      sub { mk_error_log::main($sample_file, '--resume', $resume_file) },
      "mk-error-log/t/samples/errlog008-report-resume-pos-0.txt",
      trf => 'sort'
   ),
   'Fifth run, different inode'
);

$output = `cat $resume_file`;
is(
   $output,
"file:$sample_file
inode:$inode2
pos:$size
size:$size
",
   "Resume file contents updated for different inode"
);


$output = `cat $resume_file-$inode`;
is(
   $output,
"file:$sample_file
inode:$inode
pos:$size
size:$size
",
   "Saved old resume file contents"
);

# #############################################################################
# Done.
# #############################################################################
diag(`rm -rf $resume_file $resume_file-$inode $sample_file >/dev/null`);
exit;
