---------------------------- ------ ------ ------ ------ ------ ------ ------
File                           stmt   bran   cond    sub    pod   time  total
---------------------------- ------ ------ ------ ------ ------ ------ ------
...mon/DuplicateKeyFinder.pm  100.0   81.2   86.7  100.0    n/a  100.0   94.2
Total                         100.0   81.2   86.7  100.0    n/a  100.0   94.2
---------------------------- ------ ------ ------ ------ ------ ------ ------


Run:          DuplicateKeyFinder.t
Perl version: 118.53.46.49.48.46.48
OS:           linux
Start:        Sat Aug 29 15:01:44 2009
Finish:       Sat Aug 29 15:01:44 2009

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
18                                                    # DuplicateKeyFinder package $Revision: 4404 $
19                                                    # ###########################################################################
20                                                    package DuplicateKeyFinder;
21                                                    
22             1                    1             8   use strict;
               1                                  2   
               1                                  6   
23             1                    1             5   use warnings FATAL => 'all';
               1                                  2   
               1                                  9   
24             1                    1             6   use English qw(-no_match_vars);
               1                                  2   
               1                                  8   
25                                                    
26             1                    1             7   use List::Util qw(min);
               1                                  2   
               1                                 15   
27                                                    
28             1                    1             6   use constant MKDEBUG => $ENV{MKDEBUG};
               1                                  3   
               1                                 10   
29                                                    
30                                                    sub new {
31             1                    1            30      my ( $class, %args ) = @_;
32             1                                  4      my $self = {};
33             1                                 23      return bless $self, $class;
34                                                    }
35                                                    
36                                                    # %args should contain:
37                                                    #
38                                                    #  *  keys             (req) A hashref from TableParser::get_keys().
39                                                    #  *  clustered_key    The clustered key, if any; also from get_keys().
40                                                    #  *  tbl_info         { db, tbl, engine, ddl } hashref.
41                                                    #  *  callback         An anonymous subroutine, called for each dupe found.
42                                                    #  *  ignore_order     Order never matters for any type of index (generally
43                                                    #                      order matters except for FULLTEXT).
44                                                    #  *  ignore_structure Compare different index types as if they're the same.
45                                                    #  *  clustered        Perform duplication checks against the clustered  key.
46                                                    #
47                                                    # Returns an arrayref of duplicate key hashrefs.  Each contains
48                                                    #
49                                                    #  *  key               The name of the index that's a duplicate.
50                                                    #  *  cols              The columns in that key (arrayref).
51                                                    #  *  duplicate_of      The name of the index it duplicates.
52                                                    #  *  duplicate_of_cols The columns of the index it duplicates.
53                                                    #  *  reason            A human-readable description of why this is a duplicate.
54                                                    #  *  dupe_type         Either exact, prefix, fk, or clustered.
55                                                    #
56                                                    sub get_duplicate_keys {
57            25                   25           516      my ( $self, $keys,  %args ) = @_;
58    ***     25     50                         104      die "I need a keys argument" unless $keys;
59            25                                164      my %keys = %$keys;  # Copy keys because we remove non-duplicates.
60            25                                 75      my $primary_key;
61            25                                 55      my @unique_keys;
62            25                                 71      my @normal_keys;
63            25                                 56      my @fulltext_keys;
64            25                                 62      my @dupes;
65                                                    
66                                                       KEY:
67            25                                 98      foreach my $key ( values %keys ) {
68                                                          # Save real columns before we potentially re-order them.  These are
69                                                          # columns we want to print if the key is a duplicate.
70            61                                266         $key->{real_cols} = $key->{colnames}; 
71                                                    
72                                                          # We use column lengths to compare keys.
73            61                                236         $key->{len_cols}  = length $key->{colnames};
74                                                    
75                                                          # The primary key is treated specially.  It is effectively never a
76                                                          # duplicate, so it is never removed.  It is compared to all other
77                                                          # keys, and in any case of duplication, the primary is always kept
78                                                          # and the other key removed.  Usually the primary is the acutal
79                                                          # PRIMARY KEY, but for an InnoDB table without a PRIMARY KEY, the
80                                                          # effective primary key is the clustered key.
81            61    100    100                  590         if ( $key->{name} eq 'PRIMARY'
                           100                        
82                                                               || ($args{clustered_key} && $key->{name} eq $args{clustered_key}) ) {
83            11                                 36            $primary_key = $key;
84            11                                 24            MKDEBUG && _d('primary key:', $key->{name});
85            11                                 44            next KEY;
86                                                          }
87                                                    
88                                                          # Key column order matters for all keys except FULLTEXT, so unless
89                                                          # ignore_order is specified we only sort FULLTEXT keys.
90            50    100                         214         my $is_fulltext = $key->{type} eq 'FULLTEXT' ? 1 : 0;
91            50    100    100                  409         if ( $args{ignore_order} || $is_fulltext  ) {
92            11                                 87            my $ordered_cols = join(',', sort(split(/,/, $key->{colnames})));
93            11                                 27            MKDEBUG && _d('Reordered', $key->{name}, 'cols from',
94                                                                $key->{colnames}, 'to', $ordered_cols); 
95            11                                 39            $key->{colnames} = $ordered_cols;
96                                                          }
97                                                    
98                                                          # Unless ignore_structure is specified, only keys of the same
99                                                          # structure (btree, fulltext, etc.) are compared to one another.
100                                                         # UNIQUE keys are kept separate to make comparisons easier.
101           50    100                         223         my $push_to = $key->{is_unique} ? \@unique_keys : \@normal_keys;
102           50    100                         212         if ( !$args{ignore_structure} ) {
103           48    100                         172            $push_to = \@fulltext_keys if $is_fulltext;
104                                                            # TODO:
105                                                            # $push_to = \@hash_keys     if $is_hash;
106                                                            # $push_to = \@spatial_keys  if $is_spatial;
107                                                         }
108           50                                189         push @$push_to, $key; 
109                                                      }
110                                                   
111                                                      # Redundantly constrained unique keys are treated as normal keys.
112           25                                138      push @normal_keys, $self->unconstrain_keys($primary_key, \@unique_keys);
113                                                   
114                                                      # Do not check the primary key against uniques before unconstraining
115                                                      # redundantly unique keys.  In cases like
116                                                      #    PRIMARY KEY (a, b)
117                                                      #    UNIQUE KEY  (a)
118                                                      # the unique key will be wrongly removed.  It is needed to keep
119                                                      # column a unique.  The process of unconstraining redundantly unique
120                                                      # keys marks single column unique keys so that they are never removed
121                                                      # (the mark is adding unique_col=>1 to the unique key's hash).
122           25    100                          99      if ( $primary_key ) {
123           11                                 27         MKDEBUG && _d('Comparing PRIMARY KEY to UNIQUE keys');
124           11                                 75         push @dupes,
125                                                            $self->remove_prefix_duplicates([$primary_key], \@unique_keys, %args);
126                                                   
127           11                                 30         MKDEBUG && _d('Comparing PRIMARY KEY to normal keys');
128           11                                 64         push @dupes,
129                                                            $self->remove_prefix_duplicates([$primary_key], \@normal_keys, %args);
130                                                      }
131                                                   
132           25                                 70      MKDEBUG && _d('Comparing UNIQUE keys to normal keys');
133           25                                152      push @dupes,
134                                                         $self->remove_prefix_duplicates(\@unique_keys, \@normal_keys, %args);
135                                                   
136           25                                 72      MKDEBUG && _d('Comparing normal keys');
137           25                                126      push @dupes,
138                                                         $self->remove_prefix_duplicates(\@normal_keys, \@normal_keys, %args);
139                                                   
140                                                      # If --allstruct, then these special struct keys (FULLTEXT, HASH, etc.)
141                                                      # will have already been put in and handled by @normal_keys.
142           25                                 62      MKDEBUG && _d('Comparing FULLTEXT keys');
143           25                                145      push @dupes,
144                                                         $self->remove_prefix_duplicates(\@fulltext_keys, \@fulltext_keys, %args, exact_duplicates => 1);
145                                                   
146                                                      # TODO: other structs
147                                                   
148                                                      # Remove clustered duplicates.
149           25    100                         119      my $clustered_key = $args{clustered_key} ? $keys{$args{clustered_key}}
150                                                                        : undef;
151           25                                 51      MKDEBUG && _d('clustered key:', $clustered_key->{name});
152           25    100    100                  220      if ( $clustered_key
      ***                   66                        
      ***                   66                        
153                                                           && $args{clustered}
154                                                           && $args{tbl_info}->{engine}
155                                                           && $args{tbl_info}->{engine} =~ m/InnoDB/i )
156                                                      {
157            2                                  6         MKDEBUG && _d('Removing UNIQUE dupes of clustered key');
158            2                                 13         push @dupes,
159                                                            $self->remove_clustered_duplicates($clustered_key, \@unique_keys, %args);
160                                                   
161            2                                  5         MKDEBUG && _d('Removing ordinary dupes of clustered key');
162            2                                 10         push @dupes,
163                                                            $self->remove_clustered_duplicates($clustered_key, \@normal_keys, %args);
164                                                      }
165                                                   
166           25                                140      return \@dupes;
167                                                   }
168                                                   
169                                                   sub get_duplicate_fks {
170            3                    3            18      my ( $self, $fks, %args ) = @_;
171   ***      3     50                          16      die "I need a fks argument" unless $fks;
172            3                                 16      my @fks = values %$fks;
173            3                                  9      my @dupes;
174                                                   
175            3                                 23      foreach my $i ( 0..$#fks - 1 ) {
176   ***      3     50                          20         next unless $fks[$i];
177            3                                 17         foreach my $j ( $i+1..$#fks ) {
178   ***      3     50                          12            next unless $fks[$j];
179                                                   
180                                                            # A foreign key is a duplicate no matter what order the
181                                                            # columns are in, so re-order them alphabetically so they
182                                                            # can be compared.
183            3                                 11            my $i_cols  = join(',', sort @{$fks[$i]->{cols}} );
               3                                 25   
184            3                                  9            my $j_cols  = join(',', sort @{$fks[$j]->{cols}} );
               3                                 17   
185            3                                  9            my $i_pcols = join(',', sort @{$fks[$i]->{parent_cols}} );
               3                                 16   
186            3                                  9            my $j_pcols = join(',', sort @{$fks[$j]->{parent_cols}} );
               3                                 14   
187                                                   
188   ***      3    100     66                   48            if ( $fks[$i]->{parent_tbl} eq $fks[$j]->{parent_tbl}
      ***                   66                        
189                                                                 && $i_cols  eq $j_cols
190                                                                 && $i_pcols eq $j_pcols ) {
191            2                                 63               my $dupe = {
192                                                                  key               => $fks[$j]->{name},
193                                                                  cols              => $fks[$j]->{colnames},
194                                                                  duplicate_of      => $fks[$i]->{name},
195                                                                  duplicate_of_cols => $fks[$i]->{colnames},
196                                                                  reason            =>
197                                                                       "FOREIGN KEY $fks[$j]->{name} ($fks[$j]->{colnames}) "
198                                                                     . "REFERENCES $fks[$j]->{parent_tbl} "
199                                                                     . "($fks[$j]->{parent_colnames}) "
200                                                                     . 'is a duplicate of '
201                                                                     . "FOREIGN KEY $fks[$i]->{name} ($fks[$i]->{colnames}) "
202                                                                     . "REFERENCES $fks[$i]->{parent_tbl} "
203                                                                     ."($fks[$i]->{parent_colnames})",
204                                                                  dupe_type         => 'fk',
205                                                               };
206            2                                  7               push @dupes, $dupe;
207            2                                  8               delete $fks[$j];
208   ***      2     50                          18               $args{callback}->($dupe, %args) if $args{callback};
209                                                            }
210                                                         }
211                                                      }
212            3                                 34      return \@dupes;
213                                                   }
214                                                   
215                                                   # Removes and returns prefix duplicate keys from right_keys.
216                                                   # Both left_keys and right_keys are arrayrefs.
217                                                   #
218                                                   # Prefix duplicates are the typical type of duplicate like:
219                                                   #    KEY x (a)
220                                                   #    KEY y (a, b)
221                                                   # Key x is a prefix duplicate of key y.  This also covers exact
222                                                   # duplicates like:
223                                                   #    KEY y (a, b)
224                                                   #    KEY z (a, b)
225                                                   # Key y and z are exact duplicates.
226                                                   #
227                                                   # Usually two separate lists of keys are compared: the left and right
228                                                   # keys.  When a duplicate is found, the Left key is Left alone and the
229                                                   # Right key is Removed. This is done because some keys are more important
230                                                   # than others.  For example, the PRIMARY KEY is always a left key because
231                                                   # it is never removed.  When comparing UNIQUE keys to normal (non-unique)
232                                                   # keys, the UNIQUE keys are Left (alone) and any duplicating normal
233                                                   # keys are Removed.
234                                                   #
235                                                   # A list of keys can be compared to itself in which case left and right
236                                                   # keys reference the same list but this sub doesn't know that so it just
237                                                   # removes dupes from the left as usual.
238                                                   #
239                                                   # Optional args are:
240                                                   #    * exact_duplicates  Keys are dupes only if they're exact duplicates
241                                                   #    * callback          Sub called for each dupe found
242                                                   # 
243                                                   # For a full technical explanation of how/why this sub works, read:
244                                                   # http://code.google.com/p/maatkit/wiki/DeterminingDuplicateKeys
245                                                   sub remove_prefix_duplicates {
246           97                   97           504      my ( $self, $left_keys, $right_keys, %args ) = @_;
247           97                                278      my @dupes;
248           97                                204      my $right_offset;
249           97                                218      my $last_left_key;
250           97                                302      my $last_right_key = scalar(@$right_keys) - 1;
251                                                   
252                                                      # We use "scalar(@$arrayref) - 1" because the $# syntax is not
253                                                      # reliable with arrayrefs across Perl versions.  And we use index
254                                                      # into the arrays because we delete elements.
255                                                   
256           97    100                         336      if ( $right_keys != $left_keys ) {
257                                                         # Right and left keys are different lists.
258                                                   
259            1                                  4         @$left_keys = sort { $a->{colnames} cmp $b->{colnames} }
              29                                161   
260           47                                186                       grep { defined $_; }
261                                                                       @$left_keys;
262           31                                122         @$right_keys = sort { $a->{colnames} cmp $b->{colnames} }
              50                                162   
263           47                                174                        grep { defined $_; }
264                                                                       @$right_keys;
265                                                   
266                                                         # Last left key is its very last key.
267           47                                169         $last_left_key = scalar(@$left_keys) - 1;
268                                                   
269                                                         # No need to offset where we begin looping through the right keys.
270           47                                140         $right_offset = 0;
271                                                      }
272                                                      else {
273                                                         # Right and left keys are the same list.
274                                                   
275           17                                 75         @$left_keys = reverse sort { $a->{colnames} cmp $b->{colnames} }
              37                               1521   
276           50                                197                       grep { defined $_; }
277                                                                       @$left_keys;
278                                                         
279                                                         # Last left key is its second-to-last key.
280                                                         # The very last left key will be used as a right key.
281           50                                174         $last_left_key = scalar(@$left_keys) - 2;
282                                                   
283                                                         # Since we're looping through the same list in two different
284                                                         # positions, we must offset where we begin in the right keys
285                                                         # so that we stay ahead of where we are in the left keys.
286           50                                136         $right_offset = 1;
287                                                      }
288                                                   
289                                                      LEFT_KEY:
290           97                                348      foreach my $left_index ( 0..$last_left_key ) {
291           43    100                         189         next LEFT_KEY unless defined $left_keys->[$left_index];
292                                                   
293                                                         RIGHT_KEY:
294           42                                187         foreach my $right_index ( $left_index+$right_offset..$last_right_key ) {
295   ***     37     50                         178            next RIGHT_KEY unless defined $right_keys->[$right_index];
296                                                   
297           37                                134            my $left_name      = $left_keys->[$left_index]->{name};
298           37                                138            my $left_cols      = $left_keys->[$left_index]->{colnames};
299           37                                174            my $left_len_cols  = $left_keys->[$left_index]->{len_cols};
300           37                                130            my $right_name     = $right_keys->[$right_index]->{name};
301           37                                127            my $right_cols     = $right_keys->[$right_index]->{colnames};
302           37                                127            my $right_len_cols = $right_keys->[$right_index]->{len_cols};
303                                                   
304           37                                 85            MKDEBUG && _d('Comparing left', $left_name, '(',$left_cols,')',
305                                                               'to right', $right_name, '(',$right_cols,')');
306                                                   
307                                                            # Compare the whole right key to the left key, not just
308                                                            # the their common minimum length prefix. This is correct.
309                                                            # Read http://code.google.com/p/maatkit/wiki/DeterminingDuplicateKeys.
310           37    100                         183            if (    substr($left_cols,  0, $right_len_cols)
311                                                                 eq substr($right_cols, 0, $right_len_cols) ) {
312                                                   
313                                                               # FULLTEXT keys, for example, are only duplicates if they
314                                                               # are exact duplicates.
315           18    100    100                  105               if ( $args{exact_duplicates} && ($right_len_cols<$left_len_cols) ) {
316            1                                  3                  MKDEBUG && _d($right_name, 'not exact duplicate of', $left_name);
317            1                                  5                  next RIGHT_KEY;
318                                                               }
319                                                   
320                                                               # Do not remove the unique key that is constraining a single
321                                                               # column to uniqueness. This prevents UNIQUE KEY (a) from being
322                                                               # removed by PRIMARY KEY (a, b).
323           17    100                          74               if ( exists $right_keys->[$right_index]->{unique_col} ) {
324            1                                  2                  MKDEBUG && _d('Cannot remove', $right_name,
325                                                                     'because is constrains col',
326                                                                     $right_keys->[$right_index]->{cols}->[0]);
327            1                                  4                  next RIGHT_KEY;
328                                                               }
329                                                   
330           16                                 34               MKDEBUG && _d('Remove', $right_name);
331           16                                 43               my $reason;
332           16    100                          81               if ( $right_keys->[$right_index]->{unconstrained} ) {
333            3                                 24                  $reason .= "Uniqueness of $right_name ignored because "
334                                                                     . $right_keys->[$right_index]->{constraining_key}->{name}
335                                                                     . " is a stronger constraint\n"; 
336                                                               }
337           16    100                          57               my $exact_dupe = $right_len_cols < $left_len_cols ? 0 : 1;
338           16    100                          77               $reason .= $right_name
339                                                                        . ($exact_dupe ? ' is a duplicate of '
340                                                                                       : ' is a left-prefix of ')
341                                                                        . $left_name;
342           16    100                         187               my $dupe = {
343                                                                  key               => $right_name,
344                                                                  cols              => $right_keys->[$right_index]->{real_cols},
345                                                                  duplicate_of      => $left_name,
346                                                                  duplicate_of_cols => $left_keys->[$left_index]->{real_cols},
347                                                                  reason            => $reason,
348                                                                  dupe_type         => $exact_dupe ? 'exact' : 'prefix',
349                                                               };
350           16                                 48               push @dupes, $dupe;
351           16                                 52               delete $right_keys->[$right_index];
352                                                   
353   ***     16     50                         122               $args{callback}->($dupe, %args) if $args{callback};
354                                                            }
355                                                            else {
356           19                                 42               MKDEBUG && _d($right_name, 'not left-prefix of', $left_name);
357           19                                120               next LEFT_KEY;
358                                                            }
359                                                         } # RIGHT_KEY
360                                                      } # LEFT_KEY
361           97                                308      MKDEBUG && _d('No more keys');
362                                                   
363                                                      # Cleanup the lists: remove removed keys.
364           97                                660      @$left_keys  = grep { defined $_; } @$left_keys;
              56                                208   
365           97                                308      @$right_keys = grep { defined $_; } @$right_keys;
              75                                248   
366                                                   
367           97                                379      return @dupes;
368                                                   }
369                                                   
370                                                   # Removes and returns clustered duplicate keys from keys.
371                                                   # ck (clustered key) is hashref and keys is an arrayref.
372                                                   #
373                                                   # For engines with a clustered index, if a key ends with a prefix
374                                                   # of the primary key, it's a duplicate. Example:
375                                                   #    PRIMARY KEY (a)
376                                                   #    KEY foo (b, a)
377                                                   # Key foo is redundant to PRIMARY.
378                                                   #
379                                                   # Optional args are:
380                                                   #    * callback          Sub called for each dupe found
381                                                   #
382                                                   sub remove_clustered_duplicates {
383            4                    4            24      my ( $self, $ck, $keys, %args ) = @_;
384   ***      4     50                          17      die "I need a ck argument"   unless $ck;
385   ***      4     50                          15      die "I need a keys argument" unless $keys;
386            4                                 13      my $ck_cols = $ck->{colnames};
387            4                                  9      my @dupes;
388                                                   
389                                                      KEY:
390            4                                 19      for my $i ( 0 .. @$keys - 1 ) {
391            2                                  8         my $suffix = $keys->[$i]->{colnames};
392                                                         SUFFIX:
393            2                                 15         while ( $suffix =~ s/`[^`]+`,// ) {
394            1                                 15            my $len = min(length($ck_cols), length($suffix));
395   ***      1     50                           7            if ( substr($suffix, 0, $len) eq substr($ck_cols, 0, $len) ) {
396            1                                 14               my $dupe = {
397                                                                  key               => $keys->[$i]->{name},
398                                                                  cols              => $keys->[$i]->{real_cols},
399                                                                  duplicate_of      => $ck->{name},
400                                                                  duplicate_of_cols => $ck->{real_cols},
401                                                                  reason            => "Key $keys->[$i]->{name} ends with a "
402                                                                                     . "prefix of the clustered index",
403                                                                  dupe_type         => 'clustered',
404                                                                  short_key         => $self->shorten_clustered_duplicate(
405                                                                                          $ck_cols,
406                                                                                          $keys->[$i]->{real_cols}
407                                                                                       ),
408                                                               };
409            1                                  3               push @dupes, $dupe;
410            1                                  4               delete $keys->[$i];
411   ***      1     50                          13               $args{callback}->($dupe, %args) if $args{callback};
412            1                                 10               last SUFFIX;
413                                                            }
414                                                         }
415                                                      }
416            4                                  8      MKDEBUG && _d('No more keys');
417                                                   
418                                                      # Cleanup the lists: remove removed keys.
419            4                                 15      @$keys = grep { defined $_; } @$keys;
               1                                  5   
420                                                   
421            4                                 17      return @dupes;
422                                                   }
423                                                   
424                                                   sub shorten_clustered_duplicate {
425            4                    4            22      my ( $self, $ck_cols, $dupe_key_cols ) = @_;
426            4    100                          22      return $ck_cols if $ck_cols eq $dupe_key_cols;
427            3                                 48      $dupe_key_cols =~ s/$ck_cols$//;
428            3                                 11      $dupe_key_cols =~ s/,+$//;
429            3                                 21      return $dupe_key_cols;
430                                                   }
431                                                   
432                                                   # Given a primary key (can be undef) and an arrayref of unique keys,
433                                                   # removes and returns redundantly contrained unique keys from uniquie_keys.
434                                                   sub unconstrain_keys {
435           25                   25           103      my ( $self, $primary_key, $unique_keys ) = @_;
436   ***     25     50                         105      die "I need a unique_keys argument" unless $unique_keys;
437           25                                 55      my %unique_cols;
438           25                                 60      my @unique_sets;
439           25                                 56      my %unconstrain;
440           25                                 54      my @unconstrained_keys;
441                                                   
442           25                                 59      MKDEBUG && _d('Unconstraining redundantly unique keys');
443                                                   
444                                                      # First determine which unique keys define unique columns
445                                                      # and which define unique sets.
446                                                      UNIQUE_KEY:
447           25                                112      foreach my $unique_key ( $primary_key, @$unique_keys ) {
448           37    100                         147         next unless $unique_key; # primary key may be undefined
449           23                                 76         my $cols = $unique_key->{cols};
450           23    100                         107         if ( @$cols == 1 ) {
451           12                                 28            MKDEBUG && _d($unique_key->{name},'defines unique column:',$cols->[0]);
452                                                            # Save only the first unique key for the unique col. If there
453                                                            # are others, then they are exact duplicates and will be removed
454                                                            # later when unique keys are compared to unique keys.
455   ***     12     50                          63            if ( !exists $unique_cols{$cols->[0]} ) {
456           12                                 43               $unique_cols{$cols->[0]}  = $unique_key;
457           12                                 75               $unique_key->{unique_col} = 1;
458                                                            }
459                                                         }
460                                                         else {
461           11                                 35            local $LIST_SEPARATOR = '-';
462           11                                 27            MKDEBUG && _d($unique_key->{name}, 'defines unique set:', @$cols);
463           11                                 66            push @unique_sets, { cols => $cols, key => $unique_key };
464                                                         }
465                                                      }
466                                                   
467                                                      # Second, find which unique sets can be unconstraind (i.e. those
468                                                      # which have which have at least one unique column).
469                                                      UNIQUE_SET:
470           25                                 96      foreach my $unique_set ( @unique_sets ) {
471           11                                 30         my $n_unique_cols = 0;
472           11                                 44         COL:
473           11                                 30         foreach my $col ( @{$unique_set->{cols}} ) {
474           24    100                         104            if ( exists $unique_cols{$col} ) {
475            7                                 16               MKDEBUG && _d('Unique set', $unique_set->{key}->{name},
476                                                                  'has unique col', $col);
477   ***      7     50                          29               last COL if ++$n_unique_cols > 1;
478            7                                 31               $unique_set->{constraining_key} = $unique_cols{$col};
479                                                            }
480                                                         }
481           11    100    100                   93         if ( $n_unique_cols && $unique_set->{key}->{name} ne 'PRIMARY' ) {
482                                                            # Unique set is redundantly constrained.
483            6                                 13            MKDEBUG && _d('Will unconstrain unique set',
484                                                               $unique_set->{key}->{name},
485                                                               'because it is redundantly constrained by key',
486                                                               $unique_set->{constraining_key}->{name},
487                                                               '(',$unique_set->{constraining_key}->{colnames},')');
488            6                                 53            $unconstrain{$unique_set->{key}->{name}}
489                                                               = $unique_set->{constraining_key};
490                                                         }
491                                                      }
492                                                   
493                                                      # And finally, unconstrain the redudantly unique sets found above by
494                                                      # removing them from the list of unique keys and adding them to the
495                                                      # list of normal keys.
496           25                                136      for my $i ( 0..(scalar @$unique_keys-1) ) {
497           12    100                          66         if ( exists $unconstrain{$unique_keys->[$i]->{name}} ) {
498            6                                 12            MKDEBUG && _d('Unconstraining', $unique_keys->[$i]->{name});
499            6                                 27            $unique_keys->[$i]->{unconstrained} = 1;
500            6                                 36            $unique_keys->[$i]->{constraining_key}
501                                                               = $unconstrain{$unique_keys->[$i]->{name}};
502            6                                 19            push @unconstrained_keys, $unique_keys->[$i];
503            6                                 23            delete $unique_keys->[$i];
504                                                         }
505                                                      }
506                                                   
507           25                                 54      MKDEBUG && _d('No more keys');
508           25                                110      return @unconstrained_keys;
509                                                   }
510                                                   
511                                                   sub _d {
512            1                    1            33      my ($package, undef, $line) = caller 0;
513   ***      2     50                          10      @_ = map { (my $temp = $_) =~ s/\n/\n# /g; $temp; }
               2                                  8   
               2                                 12   
514            1                                  5           map { defined $_ ? $_ : 'undef' }
515                                                           @_;
516            1                                  4      print STDERR "# $package:$line $PID ", join(' ', @_), "\n";
517                                                   }
518                                                   
519                                                   1;
520                                                   # ###########################################################################
521                                                   # End DuplicateKeyFinder package
522                                                   # ###########################################################################


Branches
--------

line  err      %   true  false   branch
----- --- ------ ------ ------   ------
58    ***     50      0     25   unless $keys
81           100     11     50   if ($$key{'name'} eq 'PRIMARY' or $args{'clustered_key'} and $$key{'name'} eq $args{'clustered_key'})
90           100      9     41   $$key{'type'} eq 'FULLTEXT' ? :
91           100     11     39   if ($args{'ignore_order'} or $is_fulltext)
101          100     12     38   $$key{'is_unique'} ? :
102          100     48      2   if (not $args{'ignore_structure'})
103          100      8     40   if $is_fulltext
122          100     11     14   if ($primary_key)
149          100      4     21   $args{'clustered_key'} ? :
152          100      2     23   if ($clustered_key and $args{'clustered'} and $args{'tbl_info'}{'engine'} and $args{'tbl_info'}{'engine'} =~ /InnoDB/i)
171   ***     50      0      3   unless $fks
176   ***     50      0      3   unless $fks[$i]
178   ***     50      0      3   unless $fks[$j]
188          100      2      1   if ($fks[$i]{'parent_tbl'} eq $fks[$j]{'parent_tbl'} and $i_cols eq $j_cols and $i_pcols eq $j_pcols)
208   ***     50      2      0   if $args{'callback'}
256          100     47     50   if ($right_keys != $left_keys) { }
291          100      1     42   unless defined $$left_keys[$left_index]
295   ***     50      0     37   unless defined $$right_keys[$right_index]
310          100     18     19   if (substr($left_cols, 0, $right_len_cols) eq substr($right_cols, 0, $right_len_cols)) { }
315          100      1     17   if ($args{'exact_duplicates'} and $right_len_cols < $left_len_cols)
323          100      1     16   if (exists $$right_keys[$right_index]{'unique_col'})
332          100      3     13   if ($$right_keys[$right_index]{'unconstrained'})
337          100      6     10   $right_len_cols < $left_len_cols ? :
338          100     10      6   $exact_dupe ? :
342          100     10      6   $exact_dupe ? :
353   ***     50     16      0   if $args{'callback'}
384   ***     50      0      4   unless $ck
385   ***     50      0      4   unless $keys
395   ***     50      1      0   if (substr($suffix, 0, $len) eq substr($ck_cols, 0, $len))
411   ***     50      1      0   if $args{'callback'}
426          100      1      3   if $ck_cols eq $dupe_key_cols
436   ***     50      0     25   unless $unique_keys
448          100     14     23   unless $unique_key
450          100     12     11   if (@$cols == 1) { }
455   ***     50     12      0   if (not exists $unique_cols{$$cols[0]})
474          100      7     17   if (exists $unique_cols{$col})
477   ***     50      0      7   if ++$n_unique_cols > 1
481          100      6      5   if ($n_unique_cols and $$unique_set{'key'}{'name'} ne 'PRIMARY')
497          100      6      6   if (exists $unconstrain{$$unique_keys[$i]{'name'}})
513   ***     50      2      0   defined $_ ? :


Conditions
----------

and 3 conditions

line  err      %     !l  l&&!r   l&&r   expr
----- --- ------ ------ ------ ------   ----
81           100     46      4      1   $args{'clustered_key'} and $$key{'name'} eq $args{'clustered_key'}
152          100     21      2      2   $clustered_key and $args{'clustered'}
      ***     66     23      0      2   $clustered_key and $args{'clustered'} and $args{'tbl_info'}{'engine'}
      ***     66     23      0      2   $clustered_key and $args{'clustered'} and $args{'tbl_info'}{'engine'} and $args{'tbl_info'}{'engine'} =~ /InnoDB/i
188   ***     66      0      1      2   $fks[$i]{'parent_tbl'} eq $fks[$j]{'parent_tbl'} and $i_cols eq $j_cols
      ***     66      1      0      2   $fks[$i]{'parent_tbl'} eq $fks[$j]{'parent_tbl'} and $i_cols eq $j_cols and $i_pcols eq $j_pcols
315          100     15      2      1   $args{'exact_duplicates'} and $right_len_cols < $left_len_cols
481          100      4      1      6   $n_unique_cols and $$unique_set{'key'}{'name'} ne 'PRIMARY'

or 3 conditions

line  err      %      l  !l&&r !l&&!r   expr
----- --- ------ ------ ------ ------   ----
81           100     10      1     50   $$key{'name'} eq 'PRIMARY' or $args{'clustered_key'} and $$key{'name'} eq $args{'clustered_key'}
91           100      2      9     39   $args{'ignore_order'} or $is_fulltext


Covered Subroutines
-------------------

Subroutine                  Count Location                                                 
--------------------------- ----- ---------------------------------------------------------
BEGIN                           1 /home/daniel/dev/maatkit/common/DuplicateKeyFinder.pm:22 
BEGIN                           1 /home/daniel/dev/maatkit/common/DuplicateKeyFinder.pm:23 
BEGIN                           1 /home/daniel/dev/maatkit/common/DuplicateKeyFinder.pm:24 
BEGIN                           1 /home/daniel/dev/maatkit/common/DuplicateKeyFinder.pm:26 
BEGIN                           1 /home/daniel/dev/maatkit/common/DuplicateKeyFinder.pm:28 
_d                              1 /home/daniel/dev/maatkit/common/DuplicateKeyFinder.pm:512
get_duplicate_fks               3 /home/daniel/dev/maatkit/common/DuplicateKeyFinder.pm:170
get_duplicate_keys             25 /home/daniel/dev/maatkit/common/DuplicateKeyFinder.pm:57 
new                             1 /home/daniel/dev/maatkit/common/DuplicateKeyFinder.pm:31 
remove_clustered_duplicates     4 /home/daniel/dev/maatkit/common/DuplicateKeyFinder.pm:383
remove_prefix_duplicates       97 /home/daniel/dev/maatkit/common/DuplicateKeyFinder.pm:246
shorten_clustered_duplicate     4 /home/daniel/dev/maatkit/common/DuplicateKeyFinder.pm:425
unconstrain_keys               25 /home/daniel/dev/maatkit/common/DuplicateKeyFinder.pm:435


