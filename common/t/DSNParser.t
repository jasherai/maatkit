#!/usr/bin/perl

use strict;
use warnings FATAL => 'all';

use Test::More tests => 5;
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
   'Basic DSN works'
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
   'DSN works with an extra option'
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
   'DSN works with defaults'
);

is ($p->usage(),
<<EOF
  DSN syntax: key=value[,key=value...] Allowable DSN keys:
  KEY  MEANING
  ===  =============================================
  D    Database to use
  F    Only read default options from the given file
  P    Port number to use for connection
  S    Socket file to use for connection
  h    Connect to host
  p    Password to use when connecting
  t    [No description]
  u    User for login if not current user
EOF
, 'Usage is OK');

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
   'Got connection arguments OK',
);
