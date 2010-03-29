# This program is copyright 2010 Percona Inc.
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
# ###########################################################################
# PodParser package $Revision$
# ###########################################################################
package PodParser;

use strict;
use warnings FATAL => 'all';
use English qw(-no_match_vars);

# This package subclasses Pod::Parser.
use Pod::Parser;
our @ISA = qw(Pod::Parser);

use constant MKDEBUG => $ENV{MKDEBUG} || 0;

# List =item from these head1 sections will be parsed into a hash
# with the item's name as the key and its paragraphs parsed as
# another hash of attribute-value pairs.  The first para is usually
# a single line of attrib: value; ..., but this is optional.  The
# other paras are the item's description, saved under the desc key.
my %parse_items_from = (
   'OPTIONS'     => 1,
   'DSN OPTIONS' => 1,
   'RULES'       => 1,
);

# Pattern to match and capture the item's name after "=item ".
my %item_pattern_for = (
   'OPTIONS'     => qr/--(.*)/,
   'DSN OPTIONS' => qr/\* (.)/,
   'RULES'       => qr/(.*)/,
);

# True if the head1 section's paragraphs before its first =item
# define rules, one per para/line.  These rules are saved in an
# arrayref under the rules key.
my %section_has_rules = (
   'OPTIONS'     => 1,
   'DSN OPTIONS' => 0,
   'RULES'       => 0,
);

sub new {
   my ( $class, %args ) = @_;
   my $self = {
      current_section => '',
      current_item    => '',
      in_list         => 0,
      items           => {},
   };
   return bless $self, $class;
}

sub get_items {
   my ( $self, $section ) = @_;
   return $section ? $self->{items}->{$section} : $self->{items};
}

# Commands like =head1, =over, =item and =back.  Paragraphs following
# these command are passed to textblock().
sub command {
   my ( $self, $cmd, $name, $lineno ) = @_;
   
   $name =~ s/\s+\Z//m;  # Remove \n and blank line after name.
   
   if  ( $cmd eq 'head1' && $parse_items_from{$name} ) {
      MKDEBUG && _d('In section', $name);
      $self->{current_section} = $name;
      $self->{items}->{$name}  = {};
   }
   elsif ( $cmd eq 'over' ) {
      MKDEBUG && _d('Start items in', $self->{current_section},
         'at line', $lineno);
      $self->{in_list} = 1;
   }
   elsif ( $cmd eq 'item' ) {
      my $pat = $item_pattern_for{ $self->{current_section} };
      my ($item) = $name =~ m/$pat/;
      if ( $item ) {
         MKDEBUG && _d($self->{current_section}, 'item:', $item);
         $self->{items}->{ $self->{current_section} }->{$item} = {
            desc => '',  # every item should have a desc
         };
         $self->{current_item} = $item;
      }
      else {
         warn "Item $name does not match $pat";
      }
   }
   elsif ( $cmd eq '=back' ) {
      MKDEBUG && _d('End items');
      $self->{in_list} = 0;
   }
   else {
      $self->{current_section} = '';
      $self->{in_list}         = 0;
   }
   
   return;
}

# Paragraphs after a command.
sub textblock {
   my ( $self, $para, $lineno ) = @_;

   return unless $self->{current_section} && $self->{current_item};

   my $section = $self->{current_section};
   my $item    = $self->{items}->{$section}->{ $self->{current_item} };

   $para =~ s/\s+\Z//;

   if ( $para =~ m/\b\w+: / ) {
      MKDEBUG && _d('Item attributes:', $para);
      map {
         my ($attrib, $val) = split(/: /, $_);
         $item->{$attrib} = defined $val ? $val : 1;
      } split(/; /, $para);
   }
   else {
      MKDEBUG && _d('Item desc:', substr($para, 0, 40),
         length($para) > 40 ? '...' : '');
      $para =~ s/\n+/ /g;
      $item->{desc} .= $para;
   }

   return;
}

# Indented blocks of text, e.g. SYNOPSIS examples.  We don't
# do anything with these yet.
sub verbatim {
   my ( $self, $para, $lineno ) = @_;
   return;
}

sub _d {
   my ($package, undef, $line) = caller 0;
   @_ = map { (my $temp = $_) =~ s/\n/\n# /g; $temp; }
        map { defined $_ ? $_ : 'undef' }
        @_;
   print STDERR "# $package:$line $PID ", join(' ', @_), "\n";
}

1;

# ###########################################################################
# End PodParser package
# ###########################################################################
