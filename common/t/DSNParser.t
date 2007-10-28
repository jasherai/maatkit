#!/usr/bin/perl

use strict;
use warnings FATAL => 'all';

use Test::More tests => 9;
use English qw(-no_match_vars);

require "../DSNParser.pm";

sub throws_ok {
   my ( $code, $pat, $msg ) = @_;
   eval { $code->(); };
   like ( $EVAL_ERROR, $pat, $msg );
}

my $p = new DSNParser;

is_deeply(
   $p->parse('u=a,p=b'),
   {  u => 'a',
      p => 'b',
      S => undef,
      h => undef,
      P => undef,
      F => undef,
      D => undef,
   },
   'Basic DSN'
);

$p = new DSNParser(
   { key => 't', copy => 0 }
   );

is_deeply(
   $p->parse('u=a,p=b'),
   {  u => 'a',
      p => 'b',
      S => undef,
      h => undef,
      P => undef,
      F => undef,
      D => undef,
      t => undef,
   },
   'DSN with an extra option'
);

is_deeply(
   $p->parse('u=a,p=b', { D => 'foo', h => 'me' }, { S => 'bar', h => 'host' } ),
   {  D => 'foo',
      F => undef,
      h => 'me',
      p => 'b',
      P => undef,
      S => 'bar',
      t => undef,
      u => 'a',
   },
   'DSN with defaults'
);

is ($p->usage(),
<<EOF
  DSN syntax: key=value[,key=value...] Allowable DSN keys:
  KEY  COPY  MEANING
  ===  ====  =============================================
  D    yes   Database to use
  F    yes   Only read default options from the given file
  P    yes   Port number to use for connection
  S    yes   Socket file to use for connection
  h    yes   Connect to host
  p    yes   Password to use when connecting
  t    no    [No description]
  u    yes   User for login if not current user
EOF
, 'Usage');

$p->prop('autokey', 'h');
is_deeply(
   $p->parse('automatic'),
   {  h => 'automatic',
   },
   'DSN with autokey'
);

is ($p->usage(),
<<EOF
  DSN syntax: key=value[,key=value...] Allowable DSN keys:
  KEY  COPY  MEANING
  ===  ====  =============================================
  D    yes   Database to use
  F    yes   Only read default options from the given file
  P    yes   Port number to use for connection
  S    yes   Socket file to use for connection
  h    yes   Connect to host
  p    yes   Password to use when connecting
  t    no    [No description]
  u    yes   User for login if not current user
  If the DSN is a bareword, the word is treated as the 'h' key.
EOF
, 'Usage');

is_deeply (
   [
      $p->get_cxn_params(
         $p->parse(
            'u=a,p=b',
            { D => 'foo', h => 'me' },
            { S => 'bar', h => 'host' } ))
   ],
   [
      'DBI:mysql:foo;host=me;mysql_socket=bar;mysql_read_default_group=mysql',
      'a',
      'b',
   ],
   'Got connection arguments',
);

$p->prop('dbidriver', 'Pg');
is_deeply (
   [
      $p->get_cxn_params(
         {
            u => 'a',
            p => 'b',
            h => 'me',
            D => 'foo',
         },
      )
   ],
   [
      'DBI:Pg:dbname=foo;host=me',
      'a',
      'b',
   ],
   'Got connection arguments for PostgreSQL',
);

$p->prop('required', { h => 1 } );
throws_ok (
   sub { $p->parse('a=b') },
   qr/Missing DSN part 'h' in 'a=b'/,
   'Missing host part',
);
