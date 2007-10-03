# ###########################################################################
# TableParser package
# ###########################################################################
use strict;
use warnings FATAL => 'all';

package TableParser;

sub new {
   bless {}, shift;
}

sub parse {
   my ( $self, $ddl, $opts ) = @_;

   my @defs = $ddl =~ m/^(\s+`.*?),?$/gm;
   my @cols = map { $_ =~ m/`([^`]+)`/g } @defs;
   if ( $opts->{ignorecols} ) { # Eliminate columns the user said to ignore
      @cols = grep { exists($opts->{ignorecols}->{$_}) } @cols;
   }

   my @nums = map  { $_ =~ m/`([^`]+)`/g }
              grep { $_ =~ m/`[^`]+` (?:(?:tiny|big|medium|small)?int|float|double|decimal)/ } @defs;
   my @null = map { $_ =~ m/`([^`]+)`/g } grep { $_ !~ m/NOT NULL/ } @defs;
   my %is_nullable = map { $_ => 1 } @null;

   my %keys;
   foreach my $key ( $ddl =~ m/^  ((?:[A-Z]+ )?KEY .*)$/gm ) {
      my ($name) = $key =~ m/(PRIMARY|`[^`]*`)/;
      my ($cols) = $key =~ m/\((.+)\),?$/;
      my $unique = $key =~ m/PRIMARY|UNIQUE/ ? 1 : 0;
      my @cols   = grep { m/[^,]/ } split('`', $cols);
      $name      =~ s/`//g;
      $keys{$name} = {
         colnames    => $cols,
         cols        => \@cols,
         unique      => $unique,
         is_col      => { map { $_ => 1 } @cols },
         is_nullable => scalar(grep { $is_nullable{$_} } @cols),
      };
   }

   # Save the column definitions *exactly*
   my %alldefs;
   @alldefs{@cols} = @defs;

   return {
      cols           => \@cols,
      is_col         => { map { $_ => 1 } @cols },
      null_cols      => \@null,
      is_nullable    => \%is_nullable,
      keys           => \%keys,
      defs           => \%alldefs,
      numeric_cols   => \@nums,
      is_numeric     => { map { $_ => 1 } @nums },
   };
}

1;

# ###########################################################################
# End TableParser package
# ###########################################################################

