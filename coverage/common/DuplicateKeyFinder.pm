---------------------------- ------ ------ ------ ------ ------ ------ ------
File                           stmt   bran   cond    sub    pod   time  total
---------------------------- ------ ------ ------ ------ ------ ------ ------
...mon/DuplicateKeyFinder.pm  100.0   79.2   87.5  100.0    n/a  100.0   94.1
Total                         100.0   79.2   87.5  100.0    n/a  100.0   94.1
---------------------------- ------ ------ ------ ------ ------ ------ ------


Run:          DuplicateKeyFinder.t
Perl version: 118.53.46.49.48.46.48
OS:           linux
Start:        Fri Jul 10 13:20:02 2009
Finish:       Fri Jul 10 13:20:02 2009

/home/daniel/dev/maatkit/common/DuplicateKeyFinder.pm

line  err   stmt   bran   cond    sub    pod   time   code
1                                                     # This program is copyright 2009 Percona Inc.
2                                                     # Feedback and improvements are welcome.
3                                                     #
4                                                     # THIS PROGRAM IS PROVIDED "AS IS" AND WITHOUT ANY EXPRESS OR IMPLIED
5                                                     # WARRANTIES, INCLUDING, WITHOUT LIMITATION, THE IMPLIED WARRANTIES OF
6                                                     # MERCHANTIBILITY AND FITNESS FOR A PARTICULAR PURPOSE.
7                                                     #
8                                                     # This program is free software; you can redistribute it and/or modify it under
9                                                     # the terms of the GNU General Public License as published by the Free Software
10                                                    # Foundation, version 2; OR the Perl Artistic License.  On UNIX and similar
11                                                    # systems, you can issue `man perlgpl' or `man perlartistic' to read these
12                                                    # licenses.
13                                                    #
14                                                    # You should have received a copy of the GNU General Public License along with
15                                                    # this program; if not, write to the Free Software Foundation, Inc., 59 Temple
16                                                    # Place, Suite 330, Boston, MA  02111-1307  USA.
17                                                    # ###########################################################################
18                                                    # DuplicateKeyFinder package $Revision: 3920 $
19                                                    # ###########################################################################
20                                                    package DuplicateKeyFinder;
21                                                    
22             1                    1             9   use strict;
               1                                  2   
               1                                  6   
23             1                    1             6   use warnings FATAL => 'all';
               1                                  2   
               1                                  8   
24             1                    1             6   use English qw(-no_match_vars);
               1                                  3   
               1                                  7   
25                                                    
26             1                    1             7   use List::Util qw(min);
               1                                  2   
               1                                 10   
27                                                    
28             1                    1             7   use constant MKDEBUG => $ENV{MKDEBUG};
               1                                  2   
               1                                 11   
29                                                    
30                                                    sub new {
31             1                    1            24      my ( $class, %args ) = @_;
32             1                                  4      my $self = {};
33             1                                 19      return bless $self, $class;
34                                                    }
35                                                    
36                                                    # %args should contain:
37                                                    #
38                                                    #  *  keys             (req) A hashref from TableParser::get_keys().
39                                                    #  *  tbl_info         { db, tbl, engine, ddl } hashref.
40                                                    #  *  callback         An anonymous subroutine, called for each dupe found.
41                                                    #  *  ignore_order     Order never matters for any type of index (generally
42                                                    #                      order matters except for FULLTEXT).
43                                                    #  *  ignore_structure Compare indexes of different types as if they're the same.
44                                                    #  *  clustered        Perform duplication checks against the clustered  key.
45                                                    #
46                                                    # Returns an arrayref of duplicate key hashrefs.  Each contains
47                                                    #
48                                                    #  *  key               The name of the index that's a duplicate.
49                                                    #  *  cols              The columns in that key (arrayref).
50                                                    #  *  duplicate_of      The name of the index it duplicates.
51                                                    #  *  duplicate_of_cols The columns of the index it duplicates.
52                                                    #  *  reason            A human-readable description of why this is a duplicate.
53                                                    sub get_duplicate_keys {
54            24                   24           138      my ( $self, $keys,  %args ) = @_;
55    ***     24     50                         100      die "I need a keys argument" unless $keys;
56            24                                135      my %keys = %$keys;  # Copy keys because we remove non-duplicates.
57            24                                 65      my $primary_key;
58            24                                 57      my @unique_keys;
59            24                                 51      my @normal_keys;
60            24                                 72      my @fulltext_keys;
61            24                                 62      my @dupes;
62                                                    
63                                                       KEY:
64            24                                 91      foreach my $key ( values %keys ) {
65                                                          # Save real columns before we potentially re-order them.  These are
66                                                          # columns we want to print if the key is a duplicate.
67            59                                322         $key->{real_cols} = $key->{colnames}; 
68                                                    
69                                                          # We use column lengths to compare keys.
70            59                                236         $key->{len_cols}  = length $key->{colnames};
71                                                    
72                                                          # The PRIMARY KEY is treated specially.  It is effectively never a
73                                                          # duplicate, so it is never removed.  It is compared to all other
74                                                          # keys, and in any case of duplication, the PRIMARY is always kept
75                                                          # and the other key removed.
76            59    100                         272         if ( $key->{name} eq 'PRIMARY' ) {
77            10                                 34            $primary_key = $key;
78            10                                 33            next KEY;
79                                                          }
80                                                    
81                                                          # Key column order matters for all keys except FULLTEXT, so unless
82                                                          # ignore_order is specified we only sort FULLTEXT keys.
83            49    100                         203         my $is_fulltext = $key->{type} eq 'FULLTEXT' ? 1 : 0;
84            49    100    100                  379         if ( $args{ignore_order} || $is_fulltext  ) {
85            11                                 84            my $ordered_cols = join(',', sort(split(/,/, $key->{colnames})));
86            11                                 30            MKDEBUG && _d('Reordered', $key->{name}, 'cols from',
87                                                                $key->{colnames}, 'to', $ordered_cols); 
88            11                                 36            $key->{colnames} = $ordered_cols;
89                                                          }
90                                                    
91                                                          # Unless ignore_structure is specified, only keys of the same
92                                                          # structure (btree, fulltext, etc.) are compared to one another.
93                                                          # UNIQUE keys are kept separate to make comparisons easier.
94            49    100                         214         my $push_to = $key->{is_unique} ? \@unique_keys : \@normal_keys;
95            49    100                         212         if ( !$args{ignore_structure} ) {
96            47    100                         179            $push_to = \@fulltext_keys if $is_fulltext;
97                                                             # TODO:
98                                                             # $push_to = \@hash_keys     if $is_hash;
99                                                             # $push_to = \@spatial_keys  if $is_spatial;
100                                                         }
101           49                                184         push @$push_to, $key; 
102                                                      }
103                                                   
104                                                      # Redundantly constrained unique keys are treated as normal keys.
105           24                                135      push @normal_keys, $self->unconstrain_keys($primary_key, \@unique_keys);
106                                                   
107                                                      # Do not check the primary key against uniques before unconstraining
108                                                      # redundantly unique keys.  In cases like
109                                                      #    PRIMARY KEY (a, b)
110                                                      #    UNIQUE KEY  (a)
111                                                      # the unique key will be wrongly removed.  It is needed to keep
112                                                      # column a unique.  The process of unconstraining redundantly unique
113                                                      # keys marks single column unique keys so that they are never removed
114                                                      # (the mark is adding unique_col=>1 to the unique key's hash).
115           24    100                          90      if ( $primary_key ) {
116           10                                 24         MKDEBUG && _d('Comparing PRIMARY KEY to UNIQUE keys');
117           10                                 74         push @dupes,
118                                                            $self->remove_prefix_duplicates([$primary_key], \@unique_keys, %args);
119                                                   
120           10                                 24         MKDEBUG && _d('Comparing PRIMARY KEY to normal keys');
121           10                                 60         push @dupes,
122                                                            $self->remove_prefix_duplicates([$primary_key], \@normal_keys, %args);
123                                                      }
124                                                   
125           24                                 59      MKDEBUG && _d('Comparing UNIQUE keys to normal keys');
126           24                                136      push @dupes,
127                                                         $self->remove_prefix_duplicates(\@unique_keys, \@normal_keys, %args);
128                                                   
129           24                                 58      MKDEBUG && _d('Comparing normal keys');
130           24                                122      push @dupes,
131                                                         $self->remove_prefix_duplicates(\@normal_keys, \@normal_keys, %args);
132                                                   
133                                                      # If --allstruct, then these special struct keys (FULLTEXT, HASH, etc.)
134                                                      # will have already been put in and handled by @normal_keys.
135           24                                 62      MKDEBUG && _d('Comparing FULLTEXT keys');
136           24                                133      push @dupes,
137                                                         $self->remove_prefix_duplicates(\@fulltext_keys, \@fulltext_keys, %args, exact_duplicates => 1);
138                                                   
139                                                      # TODO: other structs
140                                                   
141                                                      # Remove clustered duplicates.
142           24    100    100                  254      if ( $primary_key
      ***                   66                        
                           100                        
143                                                           && $args{clustered}
144                                                           && $args{tbl_info}->{engine}
145                                                           && $args{tbl_info}->{engine} =~ m/^(?:InnoDB|solidDB)$/ )
146                                                      {
147            2                                  5         MKDEBUG && _d('Removing UNIQUE dupes of clustered key');
148            2                                 13         push @dupes,
149                                                            $self->remove_clustered_duplicates($primary_key, \@unique_keys, %args);
150                                                   
151            2                                  5         MKDEBUG && _d('Removing ordinary dupes of clustered key');
152            2                                 10         push @dupes,
153                                                            $self->remove_clustered_duplicates($primary_key, \@normal_keys, %args);
154                                                      }
155                                                   
156           24                                114      return \@dupes;
157                                                   }
158                                                   
159                                                   sub get_duplicate_fks {
160            3                    3            18      my ( $self, $fks, %args ) = @_;
161   ***      3     50                          14      die "I need a fks argument" unless $fks;
162            3                                 15      my @fks = values %$fks;
163            3                                  8      my @dupes;
164                                                   
165            3                                 21      foreach my $i ( 0..$#fks - 1 ) {
166   ***      3     50                          13         next unless $fks[$i];
167            3                                 15         foreach my $j ( $i+1..$#fks ) {
168   ***      3     50                          12            next unless $fks[$j];
169                                                   
170                                                            # A foreign key is a duplicate no matter what order the
171                                                            # columns are in, so re-order them alphabetically so they
172                                                            # can be compared.
173            3                                  9            my $i_cols  = join(',', sort @{$fks[$i]->{cols}} );
               3                                 26   
174            3                                 10            my $j_cols  = join(',', sort @{$fks[$j]->{cols}} );
               3                                 15   
175            3                                  9            my $i_pcols = join(',', sort @{$fks[$i]->{parent_cols}} );
               3                                 16   
176            3                                 10            my $j_pcols = join(',', sort @{$fks[$j]->{parent_cols}} );
               3                                 14   
177                                                   
178   ***      3    100     66                   55            if ( $fks[$i]->{parent_tbl} eq $fks[$j]->{parent_tbl}
      ***                   66                        
179                                                                 && $i_cols  eq $j_cols
180                                                                 && $i_pcols eq $j_pcols ) {
181            2                                 53               my $dupe = {
182                                                                  key               => $fks[$j]->{name},
183                                                                  cols              => $fks[$j]->{colnames},
184                                                                  duplicate_of      => $fks[$i]->{name},
185                                                                  duplicate_of_cols => $fks[$i]->{colnames},
186                                                                  reason       =>
187                                                                       "FOREIGN KEY $fks[$j]->{name} ($fks[$j]->{colnames}) "
188                                                                     . "REFERENCES $fks[$j]->{parent_tbl} "
189                                                                     . "($fks[$j]->{parent_colnames}) "
190                                                                     . 'is a duplicate of '
191                                                                     . "FOREIGN KEY $fks[$i]->{name} ($fks[$i]->{colnames}) "
192                                                                     . "REFERENCES $fks[$i]->{parent_tbl} "
193                                                                     ."($fks[$i]->{parent_colnames})"
194                                                               };
195            2                                  7               push @dupes, $dupe;
196            2                                  8               delete $fks[$j];
197   ***      2     50                          16               $args{callback}->($dupe, %args) if $args{callback};
198                                                            }
199                                                         }
200                                                      }
201            3                                 34      return \@dupes;
202                                                   }
203                                                   
204                                                   # Removes and returns prefix duplicate keys from right_keys.
205                                                   # Both left_keys and right_keys are arrayrefs.
206                                                   #
207                                                   # Prefix duplicates are the typical type of duplicate like:
208                                                   #    KEY x (a)
209                                                   #    KEY y (a, b)
210                                                   # Key x is a prefix duplicate of key y.  This also covers exact
211                                                   # duplicates like:
212                                                   #    KEY y (a, b)
213                                                   #    KEY z (a, b)
214                                                   # Key y and z are exact duplicates.
215                                                   #
216                                                   # Usually two separate lists of keys are compared: the left and right
217                                                   # keys.  When a duplicate is found, the Left key is Left alone and the
218                                                   # Right key is Removed. This is done because some keys are more important
219                                                   # than others.  For example, the PRIMARY KEY is always a left key because
220                                                   # it is never removed.  When comparing UNIQUE keys to normal (non-unique)
221                                                   # keys, the UNIQUE keys are Left (alone) and any duplicating normal
222                                                   # keys are Removed.
223                                                   #
224                                                   # A list of keys can be compared to itself in which case left and right
225                                                   # keys reference the same list but this sub doesn't know that so it just
226                                                   # removes dupes from the left as usual.
227                                                   #
228                                                   # Optional args are:
229                                                   #    * exact_duplicates  Keys are dupes only if they're exact duplicates
230                                                   #    * callback          Sub called for each dupe found
231                                                   # 
232                                                   # For a full technical explanation of how/why this sub works, read:
233                                                   # http://code.google.com/p/maatkit/wiki/DeterminingDuplicateKeys
234                                                   sub remove_prefix_duplicates {
235           92                   92           482      my ( $self, $left_keys, $right_keys, %args ) = @_;
236           92                                246      my @dupes;
237           92                                203      my $right_offset;
238           92                                202      my $last_left_key;
239           92                                284      my $last_right_key = scalar(@$right_keys) - 1;
240                                                   
241                                                      # We use "scalar(@$arrayref) - 1" because the $# syntax is not
242                                                      # reliable with arrayrefs across Perl versions.  And we use index
243                                                      # into the arrays because we delete elements.
244                                                   
245           92    100                         359      if ( $right_keys != $left_keys ) {
246                                                         # Right and left keys are different lists.
247                                                   
248            1                                  5         @$left_keys = sort { $a->{colnames} cmp $b->{colnames} }
              27                                149   
249           44                                179                       grep { defined $_; }
250                                                                       @$left_keys;
251           31                                134         @$right_keys = sort { $a->{colnames} cmp $b->{colnames} }
              48                                158   
252           44                                160                        grep { defined $_; }
253                                                                       @$right_keys;
254                                                   
255                                                         # Last left key is its very last key.
256           44                                156         $last_left_key = scalar(@$left_keys) - 1;
257                                                   
258                                                         # No need to offset where we begin looping through the right keys.
259           44                                113         $right_offset = 0;
260                                                      }
261                                                      else {
262                                                         # Right and left keys are the same list.
263                                                   
264           17                                 64         @$left_keys = reverse sort { $a->{colnames} cmp $b->{colnames} }
              36                                114   
265           48                                186                       grep { defined $_; }
266                                                                       @$left_keys;
267                                                         
268                                                         # Last left key is its second-to-last key.
269                                                         # The very last left key will be used as a right key.
270           48                                158         $last_left_key = scalar(@$left_keys) - 2;
271                                                   
272                                                         # Since we're looping through the same list in two different
273                                                         # positions, we must offset where we begin in the right keys
274                                                         # so that we stay ahead of where we are in the left keys.
275           48                                129         $right_offset = 1;
276                                                      }
277                                                   
278                                                      LEFT_KEY:
279           92                                342      foreach my $left_index ( 0..$last_left_key ) {
280           41    100                         181         next LEFT_KEY unless defined $left_keys->[$left_index];
281                                                   
282                                                         RIGHT_KEY:
283           40                                158         foreach my $right_index ( $left_index+$right_offset..$last_right_key ) {
284   ***     36     50                         168            next RIGHT_KEY unless defined $right_keys->[$right_index];
285                                                   
286           36                                137            my $left_name      = $left_keys->[$left_index]->{name};
287           36                                122            my $left_cols      = $left_keys->[$left_index]->{colnames};
288           36                                125            my $left_len_cols  = $left_keys->[$left_index]->{len_cols};
289           36                                130            my $right_name     = $right_keys->[$right_index]->{name};
290           36                                124            my $right_cols     = $right_keys->[$right_index]->{colnames};
291           36                                120            my $right_len_cols = $right_keys->[$right_index]->{len_cols};
292                                                   
293           36                                 77            MKDEBUG && _d('Comparing left', $left_name, '(',$left_cols,')',
294                                                               'to right', $right_name, '(',$right_cols,')');
295                                                   
296                                                            # Compare the whole right key to the left key, not just
297                                                            # the their common minimum length prefix. This is correct.
298                                                            # Read http://code.google.com/p/maatkit/wiki/DeterminingDuplicateKeys.
299           36    100                         173            if (    substr($left_cols,  0, $right_len_cols)
300                                                                 eq substr($right_cols, 0, $right_len_cols) ) {
301                                                   
302                                                               # FULLTEXT keys, for example, are only duplicates if they
303                                                               # are exact duplicates.
304           18    100    100                  109               if ( $args{exact_duplicates} && ($right_len_cols<$left_len_cols) ) {
305            1                                  2                  MKDEBUG && _d($right_name, 'not exact duplicate of', $left_name);
306            1                                  5                  next RIGHT_KEY;
307                                                               }
308                                                   
309                                                               # Do not remove the unique key that is constraining a single
310                                                               # column to uniqueness. This prevents UNIQUE KEY (a) from being
311                                                               # removed by PRIMARY KEY (a, b).
312           17    100                          90               if ( exists $right_keys->[$right_index]->{unique_col} ) {
313            1                                  2                  MKDEBUG && _d('Cannot remove', $right_name,
314                                                                     'because is constrains col',
315                                                                     $right_keys->[$right_index]->{cols}->[0]);
316            1                                  4                  next RIGHT_KEY;
317                                                               }
318                                                   
319           16                                 32               MKDEBUG && _d('Remove', $right_name);
320           16                                 37               my $reason;
321           16    100                          79               if ( $right_keys->[$right_index]->{unconstrained} ) {
322            3                                 20                  $reason .= "Uniqueness of $right_name ignored because "
323                                                                     . $right_keys->[$right_index]->{constraining_key}->{name}
324                                                                     . " is a stronger constraint\n"; 
325                                                               }
326           16    100                          76               $reason .= $right_name
327                                                                        . ($right_len_cols<$left_len_cols ? ' is a left-prefix of '
328                                                                                                          : ' is a duplicate of ')
329                                                                        . $left_name;
330           16                                140               my $dupe = {
331                                                                  key               => $right_name,
332                                                                  cols              => $right_keys->[$right_index]->{real_cols},
333                                                                  duplicate_of      => $left_name,
334                                                                  duplicate_of_cols => $left_keys->[$left_index]->{real_cols},
335                                                                  reason            => $reason,
336                                                               };
337           16                                 47               push @dupes, $dupe;
338           16                                 51               delete $right_keys->[$right_index];
339                                                   
340   ***     16     50                         108               $args{callback}->($dupe, %args) if $args{callback};
341                                                            }
342                                                            else {
343           18                                 44               MKDEBUG && _d($right_name, 'not left-prefix of', $left_name);
344           18                                 71               next LEFT_KEY;
345                                                            }
346                                                         } # RIGHT_KEY
347                                                      } # LEFT_KEY
348           92                                307      MKDEBUG && _d('No more keys');
349                                                   
350                                                      # Cleanup the lists: remove removed keys.
351           92                                299      @$left_keys  = grep { defined $_; } @$left_keys;
              53                                189   
352           92                                302      @$right_keys = grep { defined $_; } @$right_keys;
              72                                259   
353                                                   
354           92                                370      return @dupes;
355                                                   }
356                                                   
357                                                   # Removes and returns clustered duplicate keys from keys.
358                                                   # primary is hashref and keys is an arrayref.
359                                                   #
360                                                   # For engines with a clustered index, if a key ends with a prefix
361                                                   # of the primary key, it's a duplicate. Example:
362                                                   #    PRIMARY KEY (a)
363                                                   #    KEY foo (b, a)
364                                                   # Key foo is redundant to PRIMARY.
365                                                   #
366                                                   # Optional args are:
367                                                   #    * callback          Sub called for each dupe found
368                                                   #
369                                                   sub remove_clustered_duplicates {
370            4                    4            31      my ( $self, $primary_key, $keys, %args ) = @_;
371   ***      4     50                          16      die "I need a primary_key argument" unless $primary_key;
372   ***      4     50                          14      die "I need a keys argument"        unless $keys;
373            4                                 13      my $pkcols = $primary_key->{colnames};
374            4                                  8      my @dupes;
375                                                   
376                                                      KEY:
377            4                                 18      for my $i ( 0 .. @$keys - 1 ) {
378            2                                  9         my $suffix = $keys->[$i]->{colnames};
379                                                         SUFFIX:
380            2                                 14         while ( $suffix =~ s/`[^`]+`,// ) {
381            1                                 15            my $len = min(length($pkcols), length($suffix));
382   ***      1     50                           6            if ( substr($suffix, 0, $len) eq substr($pkcols, 0, $len) ) {
383            1                                 18               my $dupe = {
384                                                                  key               => $keys->[$i]->{name},
385                                                                  cols              => $keys->[$i]->{real_cols},
386                                                                  duplicate_of      => $primary_key->{name},
387                                                                  duplicate_of_cols => $primary_key->{real_cols},
388                                                                  reason            => "Key $keys->[$i]->{name} ends with a "
389                                                                                     . "prefix of the clustered index",
390                                                               };
391            1                                  3               push @dupes, $dupe;
392            1                                  4               delete $keys->[$i];
393   ***      1     50                           8               $args{callback}->($dupe, %args) if $args{callback};
394            1                                 10               last SUFFIX;
395                                                            }
396                                                         }
397                                                      }
398            4                                 10      MKDEBUG && _d('No more keys');
399                                                   
400                                                      # Cleanup the lists: remove removed keys.
401            4                                 13      @$keys = grep { defined $_; } @$keys;
               1                                  4   
402                                                   
403            4                                 20      return @dupes;
404                                                   }
405                                                   
406                                                   # Given a primary key (can be undef) and an arrayref of unique keys,
407                                                   # removes and returns redundantly contrained unique keys from uniquie_keys.
408                                                   sub unconstrain_keys {
409           24                   24           101      my ( $self, $primary_key, $unique_keys ) = @_;
410   ***     24     50                          90      die "I need a unique_keys argument" unless $unique_keys;
411           24                                 56      my %unique_cols;
412           24                                 59      my @unique_sets;
413           24                                 55      my %unconstrain;
414           24                                 54      my @unconstrained_keys;
415                                                   
416           24                                 49      MKDEBUG && _d('Unconstraining redundantly unique keys');
417                                                   
418                                                      # First determine which unique keys define unique columns
419                                                      # and which define unique sets.
420                                                      UNIQUE_KEY:
421           24                                 87      foreach my $unique_key ( $primary_key, @$unique_keys ) {
422           36    100                         143         next unless $unique_key; # primary key may be undefined
423           22                                 68         my $cols = $unique_key->{cols};
424           22    100                          80         if ( @$cols == 1 ) {
425           11                                 24            MKDEBUG && _d($unique_key->{name},'defines unique column:',$cols->[0]);
426                                                            # Save only the first unique key for the unique col. If there
427                                                            # are others, then they are exact duplicates and will be removed
428                                                            # later when unique keys are compared to unique keys.
429   ***     11     50                          57            if ( !exists $unique_cols{$cols->[0]} ) {
430           11                                 41               $unique_cols{$cols->[0]}  = $unique_key;
431           11                                 58               $unique_key->{unique_col} = 1;
432                                                            }
433                                                         }
434                                                         else {
435           11                                 36            local $LIST_SEPARATOR = '-';
436           11                                 24            MKDEBUG && _d($unique_key->{name}, 'defines unique set:', @$cols);
437           11                                 64            push @unique_sets, { cols => $cols, key => $unique_key };
438                                                         }
439                                                      }
440                                                   
441                                                      # Second, find which unique sets can be unconstraind (i.e. those
442                                                      # which have which have at least one unique column).
443                                                      UNIQUE_SET:
444           24                                 84      foreach my $unique_set ( @unique_sets ) {
445           11                                 31         my $n_unique_cols = 0;
446           11                                 41         COL:
447           11                                 31         foreach my $col ( @{$unique_set->{cols}} ) {
448           24    100                         104            if ( exists $unique_cols{$col} ) {
449            7                                 14               MKDEBUG && _d('Unique set', $unique_set->{key}->{name},
450                                                                  'has unique col', $col);
451   ***      7     50                          30               last COL if ++$n_unique_cols > 1;
452            7                                 28               $unique_set->{constraining_key} = $unique_cols{$col};
453                                                            }
454                                                         }
455           11    100    100                   98         if ( $n_unique_cols && $unique_set->{key}->{name} ne 'PRIMARY' ) {
456                                                            # Unique set is redundantly constrained.
457            6                                 14            MKDEBUG && _d('Will unconstrain unique set',
458                                                               $unique_set->{key}->{name},
459                                                               'because it is redundantly constrained by key',
460                                                               $unique_set->{constraining_key}->{name},
461                                                               '(',$unique_set->{constraining_key}->{colnames},')');
462            6                                 34            $unconstrain{$unique_set->{key}->{name}}
463                                                               = $unique_set->{constraining_key};
464                                                         }
465                                                      }
466                                                   
467                                                      # And finally, unconstrain the redudantly unique sets found above by
468                                                      # removing them from the list of unique keys and adding them to the
469                                                      # list of normal keys.
470           24                                125      for my $i ( 0..(scalar @$unique_keys-1) ) {
471           12    100                          62         if ( exists $unconstrain{$unique_keys->[$i]->{name}} ) {
472            6                                 14            MKDEBUG && _d('Unconstraining', $unique_keys->[$i]->{name});
473            6                                 26            $unique_keys->[$i]->{unconstrained} = 1;
474            6                                 35            $unique_keys->[$i]->{constraining_key}
475                                                               = $unconstrain{$unique_keys->[$i]->{name}};
476            6                                 19            push @unconstrained_keys, $unique_keys->[$i];
477            6                                 22            delete $unique_keys->[$i];
478                                                         }
479                                                      }
480                                                   
481           24                                 55      MKDEBUG && _d('No more keys');
482           24                                109      return @unconstrained_keys;
483                                                   }
484                                                   
485                                                   sub _d {
486            1                    1            23      my ($package, undef, $line) = caller 0;
487   ***      2     50                           8      @_ = map { (my $temp = $_) =~ s/\n/\n# /g; $temp; }
               2                                  8   
               2                                 10   
488            1                                  5           map { defined $_ ? $_ : 'undef' }
489                                                           @_;
490            1                                  3      print STDERR "# $package:$line $PID ", join(' ', @_), "\n";
491                                                   }
492                                                   
493                                                   1;
494                                                   # ###########################################################################
495                                                   # End DuplicateKeyFinder package
496                                                   # ###########################################################################


Branches
--------

line  err      %   true  false   branch
----- --- ------ ------ ------   ------
55    ***     50      0     24   unless $keys
76           100     10     49   if ($$key{'name'} eq 'PRIMARY')
83           100      9     40   $$key{'type'} eq 'FULLTEXT' ? :
84           100     11     38   if ($args{'ignore_order'} or $is_fulltext)
94           100     12     37   $$key{'is_unique'} ? :
95           100     47      2   if (not $args{'ignore_structure'})
96           100      8     39   if $is_fulltext
115          100     10     14   if ($primary_key)
142          100      2     22   if ($primary_key and $args{'clustered'} and $args{'tbl_info'}{'engine'} and $args{'tbl_info'}{'engine'} =~ /^(?:InnoDB|solidDB)$/)
161   ***     50      0      3   unless $fks
166   ***     50      0      3   unless $fks[$i]
168   ***     50      0      3   unless $fks[$j]
178          100      2      1   if ($fks[$i]{'parent_tbl'} eq $fks[$j]{'parent_tbl'} and $i_cols eq $j_cols and $i_pcols eq $j_pcols)
197   ***     50      2      0   if $args{'callback'}
245          100     44     48   if ($right_keys != $left_keys) { }
280          100      1     40   unless defined $$left_keys[$left_index]
284   ***     50      0     36   unless defined $$right_keys[$right_index]
299          100     18     18   if (substr($left_cols, 0, $right_len_cols) eq substr($right_cols, 0, $right_len_cols)) { }
304          100      1     17   if ($args{'exact_duplicates'} and $right_len_cols < $left_len_cols)
312          100      1     16   if (exists $$right_keys[$right_index]{'unique_col'})
321          100      3     13   if ($$right_keys[$right_index]{'unconstrained'})
326          100      6     10   $right_len_cols < $left_len_cols ? :
340   ***     50     16      0   if $args{'callback'}
371   ***     50      0      4   unless $primary_key
372   ***     50      0      4   unless $keys
382   ***     50      1      0   if (substr($suffix, 0, $len) eq substr($pkcols, 0, $len))
393   ***     50      1      0   if $args{'callback'}
410   ***     50      0     24   unless $unique_keys
422          100     14     22   unless $unique_key
424          100     11     11   if (@$cols == 1) { }
429   ***     50     11      0   if (not exists $unique_cols{$$cols[0]})
448          100      7     17   if (exists $unique_cols{$col})
451   ***     50      0      7   if ++$n_unique_cols > 1
455          100      6      5   if ($n_unique_cols and $$unique_set{'key'}{'name'} ne 'PRIMARY')
471          100      6      6   if (exists $unconstrain{$$unique_keys[$i]{'name'}})
487   ***     50      2      0   defined $_ ? :


Conditions
----------

and 3 conditions

line  err      %     !l  l&&!r   l&&r   expr
----- --- ------ ------ ------ ------   ----
142          100     14      7      3   $primary_key and $args{'clustered'}
      ***     66     21      0      3   $primary_key and $args{'clustered'} and $args{'tbl_info'}{'engine'}
             100     21      1      2   $primary_key and $args{'clustered'} and $args{'tbl_info'}{'engine'} and $args{'tbl_info'}{'engine'} =~ /^(?:InnoDB|solidDB)$/
178   ***     66      0      1      2   $fks[$i]{'parent_tbl'} eq $fks[$j]{'parent_tbl'} and $i_cols eq $j_cols
      ***     66      1      0      2   $fks[$i]{'parent_tbl'} eq $fks[$j]{'parent_tbl'} and $i_cols eq $j_cols and $i_pcols eq $j_pcols
304          100     15      2      1   $args{'exact_duplicates'} and $right_len_cols < $left_len_cols
455          100      4      1      6   $n_unique_cols and $$unique_set{'key'}{'name'} ne 'PRIMARY'

or 3 conditions

line  err      %      l  !l&&r !l&&!r   expr
----- --- ------ ------ ------ ------   ----
84           100      2      9     38   $args{'ignore_order'} or $is_fulltext


Covered Subroutines
-------------------

Subroutine                  Count Location                                                 
--------------------------- ----- ---------------------------------------------------------
BEGIN                           1 /home/daniel/dev/maatkit/common/DuplicateKeyFinder.pm:22 
BEGIN                           1 /home/daniel/dev/maatkit/common/DuplicateKeyFinder.pm:23 
BEGIN                           1 /home/daniel/dev/maatkit/common/DuplicateKeyFinder.pm:24 
BEGIN                           1 /home/daniel/dev/maatkit/common/DuplicateKeyFinder.pm:26 
BEGIN                           1 /home/daniel/dev/maatkit/common/DuplicateKeyFinder.pm:28 
_d                              1 /home/daniel/dev/maatkit/common/DuplicateKeyFinder.pm:486
get_duplicate_fks               3 /home/daniel/dev/maatkit/common/DuplicateKeyFinder.pm:160
get_duplicate_keys             24 /home/daniel/dev/maatkit/common/DuplicateKeyFinder.pm:54 
new                             1 /home/daniel/dev/maatkit/common/DuplicateKeyFinder.pm:31 
remove_clustered_duplicates     4 /home/daniel/dev/maatkit/common/DuplicateKeyFinder.pm:370
remove_prefix_duplicates       92 /home/daniel/dev/maatkit/common/DuplicateKeyFinder.pm:235
unconstrain_keys               24 /home/daniel/dev/maatkit/common/DuplicateKeyFinder.pm:409


