#!/usr/bin/perl

# This program is copyright (c) 2007 Baron Schwartz.
# Feedback and improvements are welcome.
#
# THIS PROGRAM IS PROVIDED "AS IS" AND WITHOUT ANY EXPRESS OR IMPLIED
# WARRANTIES, INCLUDING, WITHOUT LIMITATION, THE IMPLIED WARRANTIES OF
# MERCHANTIBILITY AND FITNESS FOR A PARTICULAR PURPOSE.
#
# This program is free software; you can redistribute it and/or modify it under
# the terms of the GNU General Public License as published by the Free Software
# Foundation, version 2; OR the Perl Artistic License.  On UNIX and similar
# systems, you can issue `man perlgpl' or `man perlartistic' to read these
# licenses.
#
# You should have received a copy of the GNU General Public License along with
# this program; if not, write to the Free Software Foundation, Inc., 59 Temple
# Place, Suite 330, Boston, MA  02111-1307  USA.
use strict;
use warnings FATAL => 'all';

use Test::More tests => 13;
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

is(
   $p->as_string(
      $p->parse('u=a,p=b', { D => 'foo', h => 'me' }, { S => 'bar', h => 'host' } )
   ),
   'D=foo,S=bar,h=me,p=b,u=a',
   'DSN stringified when it gets DSN as arg'
);

is(
   $p->as_string(
      'D=foo,S=bar,h=me,p=b,u=a',
   ),
   'D=foo,S=bar,h=me,p=b,u=a',
   'DSN stringified when it gets a string as arg'
);

is ($p->usage(),
<<EOF
DSN syntax is key=value[,key=value...]  Allowable DSN keys:
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
   {  D => undef,
      F => undef,
      h => 'automatic',
      p => undef,
      P => undef,
      S => undef,
      t => undef,
      u => undef,
   },
   'DSN with autokey'
);

is_deeply(
   $p->parse('automatic',
      { D => 'foo', h => 'me', p => 'b' },
      { S => 'bar', h => 'host', u => 'a' } ),
   {  D => 'foo',
      F => undef,
      h => 'automatic',
      p => 'b',
      P => undef,
      S => 'bar',
      t => undef,
      u => 'a',
   },
   'DSN with defaults and an autokey'
);

is ($p->usage(),
<<EOF
DSN syntax is key=value[,key=value...]  Allowable DSN keys:
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
   sub { $p->parse('u=b') },
   qr/Missing DSN part 'h' in 'u=b'/,
   'Missing host part',
);

throws_ok (
   sub { $p->parse('h=foo,Z=moo') },
   qr/Unrecognized DSN part 'Z' in 'h=foo,Z=moo'/,
   'Extra key',
);
