#!/usr/bin/perl

use strict;
use warnings FATAL => 'all';

use Test::More tests => 6;
use English qw(-no_match_vars);

require "../DSNParser.pm";

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

is_deeply (
   [
      $p->get_cxn_params(
         {
            u => 'a',
            p => 'b',
            h => 'me',
            D => 'foo',
            dbidriver => 'Pg',
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
