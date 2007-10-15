# ###########################################################################
# TableParser package
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

   if ( $ddl !~ m/CREATE TABLE `/ ) {
      die "Cannot parse table definition; is ANSI quoting enabled or SQL_QUOTE_SHOW_CREATE disabled?";
   }

   my ( $engine ) = $ddl =~ m/\) (?:ENGINE|TYPE)=(\w+)/;

   my @defs = $ddl =~ m/^(\s+`.*?),?$/gm;
   my @cols = map { $_ =~ m/`([^`]+)`/g } @defs;

   # Save the column definitions *exactly*
   my %def_for;
   @def_for{@cols} = @defs;

   my @nums =
      map  { $_ =~ m/`([^`]+)`/g }
      grep { $_ =~ m/`[^`]+` (?:(?:tiny|big|medium|small)?int|float|double|decimal|year)/ } @defs;
   my %is_numeric = map { $_ => 1 } @nums;

   # Find column types.
   my %type_for;
   foreach my $col ( @cols ) {
      my $def = $def_for{$col};
      my ( $type ) = $def =~ m/`[^`]+`\s([a-z]+)/;
      die "Can't determine column type for $def" unless $type;
      $type_for{$col} = $type;
   }

   my @null;
   foreach my $col ( @cols ) {
      my $def = $def_for{$col};
      next if $def =~ m/NOT NULL/ || $def =~ m/text$/;
      push @null, $col;
   }
   my %is_nullable = map { $_ => 1 } @null;

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
      is_col         => { map { $_ => 1 } @cols },
      null_cols      => \@null,
      is_nullable    => \%is_nullable,
      keys           => \%keys,
      defs           => \%def_for,
      numeric_cols   => \@nums,
      is_numeric     => \%is_numeric,
      engine         => $engine,
      type_for       => \%type_for,
   };
}

sub get_ddl {
   my ( $self, $dbh, $db, $tbl ) = @_;
   $dbh->do('/*!40101 SET @OLD_SQL_MODE := @@SQL_MODE, '
      . '@@SQL_MODE := REPLACE(REPLACE(@@SQL_MODE, "ANSI_QUOTES", ""), ",,", ","), '
      . '@OLD_QUOTE := @@SQL_QUOTE_SHOW_CREATE, '
      . '@@SQL_QUOTE_SHOW_CREATE := 1 */');
   my $href = $dbh->selectrow_hashref("SHOW CREATE TABLE `$db`.`$tbl`");
   $dbh->do('/*!40101 SET @@SQL_MODE := @OLD_SQL_MODE, '
      . '@@SQL_QUOTE_SHOW_CREATE := @OLD_QUOTE */');
   my ($key) = grep { m/create table/i } keys %$href;
   return $href->{$key};
}

1;

# ###########################################################################
# End TableParser package
# ###########################################################################
