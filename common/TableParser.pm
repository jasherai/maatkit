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
# ###########################################################################
# TableParser package $Revision$
# ###########################################################################
use strict;
use warnings FATAL => 'all';

package TableParser;

sub new {
   bless {}, shift;
}

# $ddl:  the output of SHOW CREATE TABLE
# $opts: hashref of options
#        mysql_version: MySQL version, zero-padded so 4.1.0 => 004001000
sub parse {
   my ( $self, $ddl, $opts ) = @_;

   if ( $ddl !~ m/CREATE (?:TEMPORARY )?TABLE `/ ) {
      die "Cannot parse table definition; is ANSI quoting enabled or SQL_QUOTE_SHOW_CREATE disabled?";
   }

   my ( $engine ) = $ddl =~ m/\) (?:ENGINE|TYPE)=(\w+)/;

   my @defs = $ddl =~ m/^(\s+`.*?),?$/gm;
   my @cols = map { $_ =~ m/`([^`]+)`/g } @defs;

   # Save the column definitions *exactly*
   my %def_for;
   @def_for{@cols} = @defs;

   # Find column types, whether numeric, whether nullable, whether
   # auto-increment.
   my (@nums, @null);
   my (%type_for, %is_nullable, %is_numeric, %is_autoinc);
   foreach my $col ( @cols ) {
      my $def = $def_for{$col};
      my ( $type ) = $def =~ m/`[^`]+`\s([a-z]+)/;
      die "Can't determine column type for $def" unless $type;
      $type_for{$col} = $type;
      if ( $type =~ m/(?:(?:tiny|big|medium|small)?int|float|double|decimal|year)/ ) {
         push @nums, $col;
         $is_numeric{$col} = 1;
      }
      if ( $def !~ m/NOT NULL/ && $def !~ m/text$/ ) {
         push @null, $col;
         $is_nullable{$col} = 1;
      }
      $is_autoinc{$col} = $def =~ m/AUTO_INCREMENT/i ? 1 : 0;
   }

   my %keys;
   foreach my $key ( $ddl =~ m/^  ((?:[A-Z]+ )?KEY .*)$/gm ) {

      # Make allowances for HASH bugs in SHOW CREATE TABLE.  A non-MEMORY table
      # will report its index as USING HASH even when this is not supported.  The
      # true type should be BTREE.  See http://bugs.mysql.com/bug.php?id=22632
      if ( $engine !~ m/MEMORY|HEAP/ ) {
         $key =~ s/USING HASH/USING BTREE/;
      }

      # Determine index type
      my ( $type, $cols ) = $key =~ m/(?:USING (\w+))? \((.+)\)/;
      my ( $special ) = $key =~ m/(FULLTEXT|SPATIAL)/;
      $type = $type || $special || 'BTREE';
      if ( $opts->{mysql_version} && $opts->{mysql_version} lt '004001000'
         && $engine =~ m/HEAP|MEMORY/i )
      {
         $type = 'HASH'; # MySQL pre-4.1 supports only HASH indexes on HEAP
      }

      my ($name) = $key =~ m/(PRIMARY|`[^`]*`)/;
      my $unique = $key =~ m/PRIMARY|UNIQUE/ ? 1 : 0;
      my @cols   = grep { m/[^,]/ } split('`', $cols);
      $name      =~ s/`//g;

      $keys{$name} = {
         colnames    => $cols,
         cols        => \@cols,
         unique      => $unique,
         is_col      => { map { $_ => 1 } @cols },
         is_nullable => scalar(grep { $is_nullable{$_} } @cols),
         type        => $type,
      };
   }

   return {
      cols           => \@cols,
      col_posn       => { map { $cols[$_] => $_ } 0..$#cols },
      is_col         => { map { $_ => 1 } @cols },
      null_cols      => \@null,
      is_nullable    => \%is_nullable,
      is_autoinc     => \%is_autoinc,
      keys           => \%keys,
      defs           => \%def_for,
      numeric_cols   => \@nums,
      is_numeric     => \%is_numeric,
      engine         => $engine,
      type_for       => \%type_for,
   };
}

1;

# ###########################################################################
# End TableParser package
# ###########################################################################
