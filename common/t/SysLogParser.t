#!/usr/bin/perl

BEGIN {
   die "The MAATKIT_TRUNK environment variable is not set.  See http://code.google.com/p/maatkit/wiki/Testing"
      unless $ENV{MAATKIT_TRUNK} && -d $ENV{MAATKIT_TRUNK};
   unshift @INC, "$ENV{MAATKIT_TRUNK}/common";
};

use strict;
use warnings FATAL => 'all';
use English qw(-no_match_vars);
use Test::More tests => 14;

use SysLogParser;
use MaatkitTest;

my $p = new SysLogParser;

# The final line is broken across two lines in the actual log, but it's one
# logical event.
test_log_parser(
   parser => $p,
   file   => 'common/t/samples/pg-syslog-005.txt',
   result => [
      '2010-02-10 09:03:26.918 EST c=4b72bcae.d01,u=[unknown],D=[unknown] LOG:  connection received: host=[local]',
      '2010-02-10 09:03:26.922 EST c=4b72bcae.d01,u=fred,D=fred LOG:  connection authorized: user=fred database=fred',
      '2010-02-10 09:03:36.645 EST c=4b72bcae.d01,u=fred,D=fred LOG:  duration: 0.627 ms  statement: select 1;',
      '2010-02-10 09:03:39.075 EST c=4b72bcae.d01,u=fred,D=fred LOG:  disconnection: session time: 0:00:12.159 user=fred database=fred host=[local]',
   ],
);

# This test case examines $tell and sees whether it's correct or not.  It also
# tests whether we can correctly pass in a callback that lets the caller
# override the rules about when a new event is seen.  In this example, we want
# to break the last event up into two parts, even though they are the same event
# in the syslog entry.
{
   my $file = "$ENV{MAATKIT_TRUNK}/common/t/samples/pg-syslog-002.txt";
   eval {
      open my $fh, "<", $file or die "Cannot open $file: $OS_ERROR";
      my %parser_args = (
         next_event => sub { return <$fh>; },
         tell       => sub { return tell($fh);  },
         fh         => $fh,
         misc       => {
            new_event_test => sub {
               # A simplified PgLogParser::$log_line_regex
               defined $_[0] && $_[0] =~ m/STATEMENT/;
            },
         }
      );
      my ( $next_event, $tell, $is_syslog )
         = $p->generate_wrappers(%parser_args);

      is ($tell->(),
         0,
         '$tell 0 ok');
      is ($next_event->(),
         '2010-02-08 09:52:41.526 EST c=4b701056.1dc6,u=fred,D=fred LOG: '
         . ' statement: select * from pg_stat_bgwriter;',
         '$next_event 0 ok');

      is ($tell->(),
         153,
         '$tell 1 ok');
      is ($next_event->(),
         '2010-02-08 09:52:41.533 EST c=4b701056.1dc6,u=fred,D=fred LOG:  '
         . 'duration: 8.309 ms',
         '$next_event 1 ok');

      is ($tell->(),
         282,
         '$tell 2 ok');
      is ($next_event->(),
         '2010-02-08 09:52:57.807 EST c=4b701056.1dc6,u=fred,D=fred LOG:  '
         . 'statement: create index ix_a on foo (a);',
         '$next_event 2 ok');

      is ($tell->(),
         433,
         '$tell 3 ok');
      is ($next_event->(),
         '2010-02-08 09:52:57.864 EST c=4b701056.1dc6,u=fred,D=fred ERROR:  '
         . 'relation "ix_a" already exists',
         '$next_event 3 ok');

      is ($tell->(),
         576,
         '$tell 4 ok');
      is ($next_event->(),
         '2010-02-08 09:52:57.864 EST c=4b701056.1dc6,u=fred,D=fred STATEMENT:  '
         . 'create index ix_a on foo (a);',
         '$next_event 4 ok');

      close $fh;
   };
   is(
      $EVAL_ERROR,
      '',
      "No error on samples/pg-syslog-002.txt",
   );

}

# #############################################################################
# Done.
# #############################################################################
my $output = '';
{
   local *STDERR;
   open STDERR, '>', \$output;
   $p->_d('Complete test coverage');
}
like(
   $output,
   qr/Complete test coverage/,
   '_d() works'
);
exit;
