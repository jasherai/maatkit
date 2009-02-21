# This program is copyright 2008-@CURRENTYEAR@ Percona Inc.
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
# QueryReview package $Revision$
# ###########################################################################

package QueryReview;

# This module is an interface to a "query review table" in which certain
# historical information about unique queries is stored. This review
# information is primarily used by mk-log-parser to do a "query review"
# which allows you to keep track of old/known queries running on the
# server and easily discover when new queries appear on the server.
#
# The main work of this module is updating the query review table.
# The minimal review table has the following columns:
#    first_seen
#    last_seen
#    reviewed_by
#    reviewed_on
#    comments
# The QueryReview module keeps these (and potentially other) columns
# updated for each unique query (also called "events"). The module is
# given events by calling cache_event() which adds the event to the
# review table if it's new, then updates a local cache of the event's
# review information (last_seen, etc.). A cached is used to avoid
# thousands of little updates every second. Calling flush_event_cache()
# causes the review table to be updated for all the events in the
# cache which have changed since the last save.
#
# Events in the query review table are identified by a checksum. The
# checksum is part of an MD5 hash of the query's group-by value (usually the
# fingerprint of the $event->{arg}).

# TODO: we need to use prepared statements for SQL in this class.

use strict;
use warnings FATAL => 'all';
use English qw(-no_match_vars);
Transformers->import(qw(make_checksum parse_timestamp));

use Data::Dumper;

use constant MKDEBUG => $ENV{MKDEBUG};

# Required args:
# group_by      The name of the attribute in the event by which events will be
#               grouped into a class.  See EventAggregator.pm for more on this.  The
#               value is used to generate a GUID-ish value that we can use as
#               the primary key in a database table.
# dbh           A dbh to the server with the query review table.
# db_tbl        Full db.tbl name of the query review table.
#               Make sure the table exists! It's not checked here;
#               check it before instantiating an object.
# tbl_struct    Return val from TableParser::parse() for db_tbl.
#               This is used to discover what columns db_tbl has.
#
# Optional args:
# where         SQL clause to limit pre-loaded fingerprints that
#               comes after 'FROM db_tbl'.  It can be a WHERE clause
#               and/or LIMIT.
# ts_default    SQL expression to use when inserting a new row into
#               the review table.  If nothing else is specified, NOW()
#               is the default.
sub new {
   my ( $class, %args ) = @_;
   foreach my $arg ( qw(dbh db_tbl tbl_struct group_by) ) {
      die "I need a $arg argument" unless $args{$arg};
   }

   my @basic_cols
      = qw(checksum fingerprint sample first_seen last_seen
           reviewed_by reviewed_on comments);
   foreach my $col ( @basic_cols ) {
      die "Query review table $args{db_tbl} does not have a $col column"
         unless $args{tbl_struct}->{is_col}->{$col};
   }
   my %basic_cols = map { $_ => 1 } @basic_cols;
   my @extra_cols = grep { !$basic_cols{$_} } @{$args{tbl_struct}->{cols}};

   # Pre-load cache of fingerprint-checksums from the query review table.
   my $sql = "SELECT fingerprint, CONV(checksum, 10, 16) as checksum_hex, "
           . "first_seen, last_seen "
           . "FROM $args{db_tbl} "
           . ($args{where} ? $args{where} : '');
   my %cache = map {
      $_->{fingerprint} => {
         checksum => $_->{checksum_hex},
         dirty    => 0,
         cols     => {
            first_seen => $_->{first_seen},
            last_seen  => $_->{last_seen},
         }
      }
   }
   @{ $args{dbh}->selectall_arrayref($sql, { Slice => {} }) };

   my $now = defined $args{ts_default} ? $args{ts_default} : 'NOW()';
   $sql =
         'INSERT IGNORE INTO ' . $args{db_tbl}
         . '(checksum, fingerprint, sample, first_seen, last_seen) VALUES( '
         . "CONV(?, 16, 10), ?, ?, COALESCE(?, $now), COALESCE(?, $now))";
   MKDEBUG && _d("SQL to insert into review table:", $sql);
   my $insert_new_sth = $args{dbh}->prepare($sql);

   my $self = {
      dbh            => $args{dbh},
      db_tbl         => $args{db_tbl},
      cache          => \%cache,
      insert_new_sth => $insert_new_sth,
      group_by       => $args{group_by},
      basic_cols     => \@basic_cols,
      extra_cols     => \@extra_cols,
      ts_default     => $now,
   };
   MKDEBUG && _d("new QueryReview obj: " . Dumper($self));
   return bless $self, $class;
}

my $review_sth;
my @review_cols;

# Fetch information from the database about a query that's been reviewed.
sub get_review_info {
   my ( $self, $q, $id, $db_tbl ) = @_;
   if ( !$review_sth ) {
      @review_cols = grep { $_ !~ m/^(?:fingerprint|sample|checksum)$/ }
                     ( @{$self->{basic_cols}}, @{$self->{extra_cols}} );
      my $sql = "SELECT "
              . join(', ', map { $q->quote($_) } @review_cols)
              . ", CONV(checksum, 10, 16) AS checksum_conv FROM "
              . $q->quote($db_tbl->{D}, $db_tbl->{t})
              . " WHERE checksum=CONV(?, 16, 10)";
       MKDEBUG && _d("select for review vals: $sql");
       $review_sth = $self->{dbh}->prepare($sql);
   }
   $review_sth->execute($id);
   my $review_vals = $review_sth->fetchall_arrayref({});
   if ( $review_vals && @$review_vals == 1 ) {
      $review_vals = $review_vals->[0];
      delete $review_vals->{checksum};
      return $review_vals;
   }
}

# Return the columns we'll be using from the review table.
sub review_cols {
   my ( $self ) = @_;
   if ( !@review_cols ) {
      @review_cols = grep { $_ !~ m/^(?:fingerprint|sample|checksum)$/ }
                     ( @{$self->{basic_cols}}, @{$self->{extra_cols}} );
   }
   return @review_cols;
}

sub cache_event {
   my ( $self, $event ) = @_;
   my $checksum;

   # Skip events which do not have the group_by attribute.
   my $group_by =  $event->{ $self->{group_by} };
   return unless defined $group_by;

   # Update the event in cache if it's an old event (either in cache or
   # in the query review table). Else, add the new event to the query
   # review table and the cache.
   if ( exists $self->{cache}->{$group_by} ) {
      my $fp_ds = $self->{cache}->{$group_by};
      $checksum = $fp_ds->{checksum};
      $fp_ds->{dirty} = 1;  # group_by in cache differs from query review tbl
      # Update first_seen and last_seen. Timestamps may not always increase.
      # They can decrease, for example, if the user parses an old log.
      if ( $event->{ts} && ( my $ts = parse_timestamp($event->{ts}) ) ) {
         my $cols = $fp_ds->{cols};
         $cols->{first_seen}
            = $ts if !$cols->{first_seen} || $ts le $cols->{first_seen};
         $cols->{last_seen}
            = $ts if !$cols->{last_seen}  || $ts ge $cols->{last_seen};
      }
   }
   else {
      $checksum = make_checksum($group_by);
      if ( $self->event_is_stored($checksum) ) {
         # Event not cached but stored in the db_tbl.
         my $review_info = $self->{dbh}->selectall_hashref(
            'SELECT CONV(checksum,10,16) AS checksum_conv, '
            . join(', ', @{$self->{basic_cols}})
            . ' FROM ' . $self->{db_tbl}
            . " WHERE checksum=CONV('$checksum',16,10)",
            'checksum_conv',);
         $self->{cache}->{$group_by} = {
            checksum => $checksum,
            dirty    => 1,
            cols     => {
               first_seen => $review_info->{$checksum}->{first_seen} || '',
               last_seen  => $review_info->{$checksum}->{last_seen}  || '',
            },
         };
      }
      else {
         # New event.
         # The primary key value (checksum column) is generated by checksumming
         # the query and then converting part of the checksum into a bigint.
         my $ts = $event->{ts} ? parse_timestamp($event->{ts}) : undef;

         $self->{insert_new_sth}->execute(
            $checksum,
            $group_by,
            $event->{arg},
            $ts,
            $ts);
         MKDEBUG && _d("Stored new event: ", $checksum, $group_by, $ts);

         $self->{cache}->{$group_by} = {
            checksum => $checksum,
            dirty    => 0,
            cols     => {
               first_seen => $ts,
               last_seen  => $ts,
            },
         };
      }
   }

   # Add event's checksum to itself as a pseudo-attribute.
   $event->{checksum} = $checksum;
}

sub event_is_stored {
   my ( $self, $checksum ) = @_;
   return 1 if $self->{seen}->{$checksum};
   my $sql = "SELECT checksum FROM $self->{db_tbl} "
           . "WHERE checksum=CONV('$checksum',16,10)";
   MKDEBUG && _d($sql);
   my ($is_there) = $self->{dbh}->selectrow_array($sql);
   $self->{seen}->{$checksum} = $is_there;
   return scalar $is_there ? 1 : 0;
}

# Update query review table according to new values in cache.
sub flush_event_cache {
   my ( $self ) = @_;

   CLASS:
   foreach my $class ( keys %{$self->{cache}} ) {
      my $fp_ds = $self->{cache}->{$class};
      next CLASS unless $fp_ds->{dirty};
      my $sql = "UPDATE $self->{db_tbl} SET "
              . join(', ',
                   map {
                      # Special case for timestamp columns
                      # TODO: column names need to be run through a Quoter!
                      $_ =~ m/first_seen|last_seen/
                         ? "$_=COALESCE(?, $self->{ts_default})"
                         : "$_=?"
                   } keys %{$fp_ds->{cols}}
                )
              . " WHERE checksum=CONV(?, 16, 10)";
      MKDEBUG && _d("update sql for cached event: $sql");
      my $sth = $self->{dbh}->prepare($sql);
      $sth->execute(values %{$fp_ds->{cols}}, $fp_ds->{checksum});
   }
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
# End QueryReview package
# ###########################################################################
