# This program is copyright 2009-@CURRENTYEAR@ Percona Inc.
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
# DuplicateKeyFinder package $Revision$
# ###########################################################################
package DuplicateKeyFinder;

use strict;
use warnings FATAL => 'all';
use English qw(-no_match_vars);

use List::Util qw(min);

use constant MKDEBUG => $ENV{MKDEBUG};

sub new {
   my ( $class ) = @_;
   return bless {}, $class;
}

# $ddl is a SHOW CREATE TABLE returned from MySQLDumper::get_create_table().
# The general format of a key is
# [FOREIGN|UNIQUE|PRIMARY|FULLTEXT|SPATIAL] KEY `name` [USING BTREE|HASH] (`cols`).
sub get_keys {
   my ( $self, $ddl, $opts ) = @_;

   # Find and filter the indexes.
   my @indexes =
      grep { $_ !~ m/FOREIGN/ }
      $ddl =~ m/((?:\w+ )?KEY .+\))/mg;

   # Make allowances for HASH bugs in SHOW CREATE TABLE.  A non-MEMORY table
   # will report its index as USING HASH even when this is not supported.  The
   # true type should be BTREE.  See http://bugs.mysql.com/bug.php?id=22632
   my $engine = $self->get_engine($ddl);
   if ( $engine !~ m/MEMORY|HEAP/ ) {
      @indexes = map { $_ =~ s/USING HASH/USING BTREE/; $_; } @indexes;
   }

   my @keys = map {
      my ( $unique, $struct, $cols )
         = $_ =~ m/(?:(\w+) )?KEY.+(?:USING (\w+))? \((.+)\)/;
      my ( $special ) = $_ =~ m/(FULLTEXT|SPATIAL)/;
      $struct = $struct || $special || 'BTREE';
      my ( $name ) = $_ =~ m/KEY `(.*?)` \(/;

      # MySQL pre-4.1 supports only HASH indexes.
      if ( $opts->{version} lt '004001000' && $engine =~ m/HEAP|MEMORY/i ) {
         $struct = 'HASH';
      }

      {
         struct   => $struct,
         cols     => $cols,
         name     => $name || 'PRIMARY',
         unique   => $unique && $unique =~ m/(UNIQUE|PRIMARY)/ ? 1 : 0,
      }
   } @indexes;

   return \@keys;
}

sub get_fks {
   my ( $self, $ddl, $opts ) = @_;

   my @fks = $ddl =~ m/CONSTRAINT .* FOREIGN KEY .* REFERENCES [^\)]*\)/mg;

   my @result = map {
      my ( $name ) = $_ =~ m/CONSTRAINT `(.*?)`/;
      my ( $fkcols ) = $_ =~ m/\(([^\)]+)\)/;
      my ( $cols )   = $_ =~ m/REFERENCES.*?\(([^\)]+)\)/;
      my ( $parent ) = $_ =~ m/REFERENCES (\S+) /;
      if ( $parent !~ m/\./ && $opts->{database} ) {
         $parent = "`$opts->{database}`.$parent";
      }

      {
         name   => $name,
         parent => $parent,
         cols   => $cols,
         fkcols => $fkcols,
      };
   } @fks;
   return \@result;
}

sub get_duplicate_keys {
   my ( $self, %args ) = @_;
   die "I need a keys argument" unless $args{keys};
   my $primary_key;
   my @unique_keys;
   my @keys;
   my @fulltext_keys;
   my %pass_args = %args;
   delete $pass_args{keys};

   ALL_KEYS:
   foreach my $key ( @{$args{keys}} ) {
      $key->{real_cols} = $key->{cols}; 
      $key->{len_cols}  = length $key->{cols};

      # The PRIMARY KEY is treated specially. It is effectively never a
      # duplicate, so it is never removed. It is compared to all other
      # keys, and in any case of duplication, the PRIMARY is always kept
      # and the other key removed.
      if ( $key->{name} eq 'PRIMARY' ) {
         $primary_key = $key;
         next ALL_KEYS;
      }

      my $is_fulltext = $key->{struct} eq 'FULLTEXT' ? 1 : 0;

      # Key column order matters for all keys except FULLTEXT, so we only
      # sort if --ignoreorder or FULLTEXT. 
      if ( $args{ignore_order} || $is_fulltext  ) {
         my $ordered_cols = join(',', sort(split(/,/, $key->{cols})));
         MKDEBUG && _d("Reordered $key->{name} cols "
            . "from ($key->{cols}) to ($ordered_cols)"); 
         $key->{cols} = $ordered_cols;
      }

      # By default --allstruct is false, so keys of different structs
      # (BTREE, HASH, FULLTEXT, SPATIAL) are kept and compared separately.
      # UNIQUE keys are also separated just to make comparisons easier.
      my $push_to = $key->{unique} ? \@unique_keys : \@keys;
      if ( !$args{ignore_type} ) {
         $push_to = \@fulltext_keys if $is_fulltext;
         # TODO:
         # $push_to = \@hash_keys     if $is_hash;
         # $push_to = \@spatial_keys  if $is_spatial;
      }
      push @$push_to, $key; 
   }

   my $good_keys;
   my $dupe_keys;
   my @dupes;

   if ( $primary_key ) {
      MKDEBUG && _d('Start comparing PRIMARY KEY to UNIQUE keys');
      $self->remove_prefix_duplicates(
            keys           => [$primary_key],
            remove_keys    => \@unique_keys,
            duplicate_keys => \@dupes,
            %pass_args);

      MKDEBUG && _d('Start comparing PRIMARY KEY to regular keys');
      $self->remove_prefix_duplicates(
            keys           => [$primary_key],
            remove_keys    => \@keys,
            duplicate_keys => \@dupes,
            %pass_args);
   }

   MKDEBUG && _d('Start comparing UNIQUE keys');
   $self->remove_prefix_duplicates(
         keys           => \@unique_keys,
         duplicate_keys => \@dupes,
         %pass_args);

   MKDEBUG && _d('Start comparing regular keys');
   $self->remove_prefix_duplicates(
         keys           => \@keys,
         duplicate_keys => \@dupes,
         %pass_args);

   MKDEBUG && _d('Start comparing UNIQUE keys to regular keys');
   $self->remove_prefix_duplicates(
         keys           => \@unique_keys,
         remove_keys    => \@keys,
         duplicate_keys => \@dupes,
         %pass_args);

   MKDEBUG && _d('Start removing unnecessary constraints');
   KEY:
   foreach my $key ( @keys ) {
      my @constrainers;
      foreach my $unique_key ( $primary_key, @unique_keys ) {
         next unless $unique_key;
         if (    substr($unique_key->{cols}, 0, $unique_key->{len_cols})
              eq substr($key->{cols}, 0, $unique_key->{len_cols}) ) {
            MKDEBUG && _d("$unique_key->{name} constrains $key->{name}");
            push @constrainers, $unique_key;
         }
      }
      next KEY unless @constrainers;

      @constrainers = sort { $a->{len_cols}<=>$b->{len_cols} } @constrainers;
      my $min_constrainer = shift @constrainers;
      MKDEBUG && _d("$key->{name} min constrainer: $min_constrainer->{name}");

      foreach my $constrainer ( @constrainers ) {
         for my $i ( 0..$#unique_keys ) {
            if ( $unique_keys[$i]->{name} eq $constrainer->{name} ) {
               my $dupe = {
                  key               => $constrainer->{name},
                  cols              => $constrainer->{real_cols},
                  duplicate_of      => $min_constrainer->{name},
                  duplicate_of_cols => $min_constrainer->{real_cols},
                  reason            =>
                       "$constrainer->{name} ($constrainer->{cols}) "
                     . 'is an unnecessary UNIQUE constraint for '
                     . "$key->{name} ($key->{cols}) because "
                     . "$min_constrainer->{name} ($min_constrainer->{cols}) "
                     . 'alone preserves key column uniqueness'
               };
               push @dupes, $dupe;
               delete $unique_keys[$i];
               $args{callback}->($dupe, %pass_args) if $args{callback};
            }
         }
      }
   }

   # If --allstruct, then these special struct keys (FULLTEXT, HASH, etc.)
   # will have already been put in and handled by @keys.
   MKDEBUG && _d('Start comparing FULLTEXT keys');
   $self->remove_prefix_duplicates(
         keys             => \@fulltext_keys,
         exact_duplicates => 1,
         %pass_args);

   # TODO: other structs

   # For engines with clustered indexes, if a key ends with a prefix
   # of the primary key, it's a duplicate. Example:
   #    PRIMARY KEY (a)
   #    KEY foo (b, a)
   # Key foo is a duplicate of PRIMARY.
   if ( $primary_key
        && $args{clustered}
        && $args{engine} =~ m/^(?:InnoDB|solidDB)$/ ) {

      MKDEBUG && _d('Start removing clustered UNIQUE key dupes');
      $self->remove_clustered_duplicates(
            primary_key => $primary_key,
            keys        => \@unique_keys,
            %pass_args);

      MKDEBUG && _d('Start removing clustered regular key dupes');
      $self->remove_clustered_duplicates(
            primary_key => $primary_key,
            keys        => \@keys,
            %pass_args);
   }

   return \@dupes;
}

sub get_duplicate_fks {
   my ( $self, %args ) = @_;
   die "I need a keys argument" unless $args{keys};
   my $fks = $args{keys};
   my @fks = @$fks;
   my @dupes;
   foreach my $i ( 0..$#fks - 1 ) {
      next unless $fks[$i];
      foreach my $j ( $i+1..$#fks ) {
         next unless $fks[$j];
         # A foreign key is a duplicate no matter what order the
         # columns are in, so re-order them alphabetically so they
         # can be compared.
         my $i_cols = join(', ',
            map { "`$_`" } sort($fks[$i]->{cols} =~ m/`([^`]+)`/g));
         my $j_cols = join(', ',
            map { "`$_`" } sort($fks[$j]->{cols} =~ m/`([^`]+)`/g));
         my $i_fkcols = join(', ',
            map { "`$_`" } sort($fks[$i]->{fkcols} =~ m/`([^`]+)`/g));
         my $j_fkcols = join(', ',
            map { "`$_`" } sort($fks[$j]->{fkcols} =~ m/`([^`]+)`/g));

         if ( $fks[$i]->{parent} eq $fks[$j]->{parent}
              && $i_cols   eq $j_cols
              && $i_fkcols eq $j_fkcols ) {
            my $dupe = {
               key               => $fks[$j]->{name},
               cols              => $fks[$j]->{cols},
               duplicate_of      => $fks[$i]->{name},
               duplicate_of_cols => $fks[$i]->{cols},
               reason       =>
                    "FOREIGN KEY $fks->[$j]->{name} ($fks->[$j]->{cols}) "
                  . "REFERENCES $fks->[$j]->{parent} ($fks->[$j]->{fkcols}) "                     .  'is a duplicate of '
                  . "FOREIGN KEY $fks->[$i]->{name} ($fks->[$i]->{cols}) "
                  . "REFERENCES $fks->[$i]->{parent} ($fks->[$i]->{fkcols})"
            };
            push @dupes, $dupe;
            delete $fks[$j];
            $args{callback}->($dupe, %args) if $args{callback};
         }
      }
   }
   return \@dupes;
}

# Caution: undocumented deep magick below.
sub remove_prefix_duplicates {
   my ( $self, %args ) = @_;
   die "I need a keys argument" unless $args{keys};
   my $keys;
   my $remove_keys;
   my @dupes;
   my $keep_index;
   my $remove_index;
   my $last_key;
   my $remove_key_offset;

   $keys  = $args{keys};
   @$keys = sort { $a->{cols} cmp $b->{cols} }
            grep { defined $_; }
            @$keys;

   if ( $args{remove_keys} ) {
      $remove_keys  = $args{remove_keys};
      @$remove_keys = sort { $a->{cols} cmp $b->{cols} }
                      grep { defined $_; }
                      @$remove_keys;

      $remove_index      = 1;
      $keep_index        = 0;
      $last_key          = scalar(@$keys) - 1;
      $remove_key_offset = 0;
   }
   else {
      $remove_keys       = $keys;
      $remove_index      = 0;
      $keep_index        = 1;
      $last_key          = scalar(@$keys) - 2;
      $remove_key_offset = 1;
   }
   my $last_remove_key = scalar(@$remove_keys) - 1;

   I_KEY:
   foreach my $i ( 0..$last_key ) {
      next I_KEY unless defined $keys->[$i];

      J_KEY:
      foreach my $j ( $i+$remove_key_offset..$last_remove_key ) {
         next J_KEY unless defined $remove_keys->[$j];

         my $keep = ($i, $j)[$keep_index];
         my $rm   = ($i, $j)[$remove_index];

         my $keep_name     = $keys->[$keep]->{name};
         my $keep_cols     = $keys->[$keep]->{cols};
         my $keep_len_cols = $keys->[$keep]->{len_cols};
         my $rm_name       = $remove_keys->[$rm]->{name};
         my $rm_cols       = $remove_keys->[$rm]->{cols};
         my $rm_len_cols   = $remove_keys->[$rm]->{len_cols};

         MKDEBUG && _d("Comparing [keep] $keep_name ($keep_cols) "
            . "to [remove if dupe] $rm_name ($rm_cols)");

         # Compare the whole remove key to the keep key, not just
         # the their common minimum length prefix. This is correct
         # because it enables magick that I should document. :-)
         if (    substr($rm_cols, 0, $rm_len_cols)
              eq substr($keep_cols, 0, $rm_len_cols) ) {

            # FULLTEXT keys, for example, are only duplicates if they
            # are exact duplicates.
            if ( $args{exact_duplicates} && ($rm_len_cols < $keep_len_cols) ) {
               MKDEBUG && _d("$rm_name not exact duplicate of $keep_name");
               next J_KEY;
            }

            MKDEBUG && _d("Remove $remove_keys->[$rm]->{name}");
            my $reason = "$remove_keys->[$rm]->{name} "
                       . "($remove_keys->[$rm]->{real_cols}) is a "
                       . ($rm_len_cols < $keep_len_cols ? 'left-prefix of '
                                                        : 'duplicate of ')
                       . "$keys->[$keep]->{name} "
                       . "($keys->[$keep]->{real_cols})";
            my $dupe = {
               key               => $rm_name,
               cols              => $remove_keys->[$rm]->{real_cols},
               duplicate_of      => $keep_name,
               duplicate_of_cols => $keys->[$keep]->{real_cols},
               reason       => $reason,
            };
            push @dupes, $dupe;
            delete $remove_keys->[$rm];

            $args{callback}->($dupe, %args) if $args{callback};

            next I_KEY if $remove_index == 0;
            next J_KEY if $remove_index == 1;
         }
         else {
            MKDEBUG && _d("$rm_name not left-prefix of $keep_name");
            next I_KEY;
         }
      }
   }
   MKDEBUG && _d('No more keys');

   @$keys        = grep { defined $_; } @$keys;
   @$remove_keys = grep { defined $_; } @$remove_keys if $args{remove_keys};
   push @{$args{duplicate_keys}}, @dupes if $args{duplice_keys};

   return;
}

sub remove_clustered_duplicates {
   my ( $self, %args ) = @_;
   die "I need a primary_key argument" unless $args{primary_key};
   die "I need a keys argument"        unless $args{keys};
   my $pkcols = $args{primary_key}->{cols};
   my $keys   = $args{keys};
   my @dupes;
   KEY:
   for my $i ( 0..$#{@$keys} ) {
      my $suffix = $keys->[$i]->{cols};
      SUFFIX:
      while ( $suffix =~ s/`[^`]+`,// ) {
         my $len = min(length($pkcols), length($suffix));
         if ( substr($suffix, 0, $len) eq substr($pkcols, 0, $len) ) {
            my $dupe = {
               key               => $keys->[$i]->{name},
               cols              => $keys->[$i]->{real_cols},
               duplicate_of      => $args{primary_key}->{name},
               duplicate_of_cols => $args{primary_key}->{real_cols},
               reason         =>
                  "Clustered key $keys->[$i]->{name} ($keys->[$i]->{cols}) "
                  . "is a duplicate of PRIMARY ($args{primary_key}->{cols})",
            };
            push @dupes, $dupe;
            delete $keys->[$i];
            $args{callback}->($dupe, %args) if $args{callback};
            last SUFFIX;
         }
      }
   }
   MKDEBUG && _d('No more clustered keys');

   @$keys = grep { defined $_; } @$keys;
   push @{$args{duplicate_keys}}, @dupes if $args{duplice_keys};

   return;
}

sub get_engine {
   my ( $self, $ddl, $opts ) = @_;
   my ( $engine ) = $ddl =~ m/\) (?:ENGINE|TYPE)=(\w+)/;
   return $engine || undef;
}

sub _d {
   my ($package, undef, $line) = caller 0;
   @_ = map { (my $temp = $_) =~ s/\n/\n# /g; $temp; }
        map { defined $_ ? $_ : 'undef' }
        @_;
   # Use $$ instead of $PID in case the package
   # does not use English.
   print "# $package:$line $$ ", @_, "\n";
}

1;

# ###########################################################################
# End DuplicateKeyFinder package
# ###########################################################################
