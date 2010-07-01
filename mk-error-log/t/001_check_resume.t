#!/usr/bin/env perl

BEGIN {
   die "The MAATKIT_WORKING_COPY environment variable is not set.  See http://code.google.com/p/maatkit/wiki/Testing"
      unless $ENV{MAATKIT_WORKING_COPY} && -d $ENV{MAATKIT_WORKING_COPY};
   unshift @INC, "$ENV{MAATKIT_WORKING_COPY}/common";
};

use strict;
use warnings FATAL => 'all';
use English qw(-no_match_vars);
use Test::More tests => 12;

use MaatkitTest;
require "$trunk/mk-error-log/mk-error-log";

my $dir = '/tmp/mk-error-log';
diag(`rm -rf $dir ; mkdir $dir`);

my $resume_file = "$dir/mk-error-log-resume.txt";
my $resume      = {
   resume_file => $resume_file,
   file        => '',
   inode       => 0,
   pos         => 123,
};


is_deeply(
   mk_error_log::check_resume($resume, 'file_does_not_exists_18928218218'),
   $resume,
   "Returns same resume info if file doesn't exist"
);

my $file = "$dir/test-err-log.txt";
diag(`rm -rf $file >/dev/null`);
diag(`echo "091205 04:49:10  mysqld restarted" > $file`);
my $inode = (stat($file))[1];
$resume->{file}  = $file;
$resume->{inode} = $inode;
diag(`rm -rf $resume_file-$inode >/dev/null`);

is_deeply(
   mk_error_log::check_resume($resume, $file),
   $resume,
   "Returns same resume info if file is the same"
);

ok(
   !-f "$resume_file-$inode",
   "Didn't create backup resume file"
);


# Change the error log file name.

my $new_file = "$dir/test-err-log.txt-NEW";
diag(`rm -rf $new_file >/dev/null`);
diag(`echo "091205 04:49:10  mysqld restarted" > $new_file`);
my $new_inode = (stat($new_file))[1];

is_deeply(
   mk_error_log::check_resume($resume, "$file-NEW"),
   {
      resume_file => $resume_file,
      file  => $new_file,
      inode => $new_inode,
      pos   => 0,
      size  => 34,
   },
   "Created new resume info for new file name"
);

ok(
   -f "$resume_file-$inode",
   "Created backup resume file"
);

is(
   `cat "$resume_file-$inode"`,
"file:$file
inode:$inode
pos:123
size:34
",
   "Backup resume file contents"
);

# Change the error log inode.  Some file systems reuse inodes so
# this will insure we get a new inode with the same filename.

diag(`cp $file $file-2 ; rm $file ; mv $file-2 $file`);
my $inode2 = (stat($file))[1];

# Reset $resume.
$resume->{file}  = $file;
$resume->{inode} = $inode;
$resume->{pos}   = 456;

cmp_ok(
   $inode,
   '!=',
   $inode2,
   "Same file, different inodes"
);

is_deeply(
   mk_error_log::check_resume($resume, $file),
   {
      resume_file => $resume_file,
      file  => $file,
      inode => $inode2,
      pos   => 0,
      size  => 34,
   },
   "Created new resume info for new file inode"
);

ok(
   -f "$resume_file-$inode",
   "Created backup resume file"
);

is(
   `cat "$resume_file-$inode"`,
"file:$file
inode:$inode
pos:456
size:34
",
   "Backup resume file contents"
);

# Make new file smaller than resume info.

diag(`rm -rf $file >/dev/null`);
diag(`echo "091205 04:49:10  mysqld restarted" > $file`);
$inode = (stat($file))[1];

$resume->{file}  = $file;
$resume->{inode} = $inode;
$resume->{pos}   = 10000;
$resume->{size}  = 10000;

{
   my $output = '';
   local *STDERR;
   open STDERR, '>', \$output;

   is_deeply(
      mk_error_log::check_resume($resume, $file),
      {
         resume_file => $resume_file,
         file  => $file,
         inode => $inode,
         size  => -s $file,
         pos   => 0,
      },
      "Reset pos=0 when file is smaller"
   );

   like(
      $output,
      qr/is less than current file size/,
      "Warns that resume size < current file size"
   );
}

# #############################################################################
# Done.
# #############################################################################
diag(`rm -rf $dir >/dev/null`);
exit;
