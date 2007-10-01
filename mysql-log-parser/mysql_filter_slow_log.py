#!/usr/bin/env python
# -*- coding: iso-8859-15 -*-


# MySQL Log Filter 1.9
# =====================
#
# Copyright 2007 René Leonhardt
#
# Website: http://code.google.com/p/mysql-log-filter/
#
# This program is free software you can redistribute it and/or
# modify it under the terms of the GNU General Public License
# as published by the Free Software Foundation either version 2
# of the License, or (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program if not, write to the Free Software
# Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA  02110-1301, USA.
#
# ABOUT MySQL Log Filter
# =======================
# The MySQL Log Filter allows you to easily filter only useful information of the
# MySQL Slow Query Log.
#
#
# LICENSE
# =======
# This code is released under the GPL. The full code is available from the website
# listed above.


"""Parse the MySQL Slow Query Log from file or STDIN and write all filtered queries or statistics to STDOUT.

In order to activate it see http://dev.mysql.com/doc/refman/5.1/en/slow-query-log.html.
For example you could add the following lines to your my.ini or my.cnf configuration file under the [mysqld] section:

long_query_time=3
log-slow-queries
log-queries-not-using-indexes


Required Python modules:
- sqlite3 (included in Python 2.5) or pysqlite2 for --incremental


Example input lines:

# Time: 070119 12:29:58
# User@Host: root[root] @ localhost []
# Query_time: 1  Lock_time: 0  Rows_sent: 1  Rows_examined: 12345
SELECT * FROM test;
"""

usage = """MySQL Slow Query Log Filter 1.9 for Python 2.4

Usage:

# Filter slow queries executed for at least 3 seconds not from root, remove duplicates,
# apply execution count as first sorting value and save first 10 unique queries to file.
# In addition, remember last input file position and statistics.
python mysql_filter_slow_log.py -T=3 -eu=root --no-duplicates --sort-execution-count --top=10 --incremental linux-slow.log > mysql-slow-queries.log

# Start permanent filtering of all slow queries from now on: at least 3 seconds or examining 10000 rows, exclude users root and test
tail -f -n 0 linux-slow.log | python mysql_filter_slow_log.py -T=3 -R=10000 -eu=root -eu=test &
# (-n 0 outputs only lines generated after start of tail)

# Stop permanent filtering
kill `ps auxww | grep 'tail -f -n 0 linux-slow.log' | egrep -v grep | awk '{print $2}'`


Options:

-T=min_query_time    Include only queries which took at least min_query_time seconds [default: 1]
-R=min_rows_examined Include only queries which examined at least min_rows_examined rows

-ih=include_host  Include only queries which contain include_host in the user field [multiple]
-eh=exclude_host  Exclude all queries which contain exclude_host in the user field [multiple]
-iu=include_user  Include only queries which contain include_user in the user field [multiple]
-eu=exclude_user  Exclude all queries which contain exclude_user in the user field [multiple]
-iq=include_query Include only queries which contain the string include_query (i.e. database or table name) [multiple]

--date=[<|>|-]date_first[-][date_last] Include only queries between date_first (and date_last).
                                       Input:                    Date Range:
                                       13.11.2006             -> 13.11.2006 - 14.11.2006 (exclusive)
                                       13.11.2006-15.11.2006  -> 13.11.2006 - 16.11.2006 (exclusive)
                                       15-11-2006-11/13/2006  -> 13.11.2006 - 16.11.2006 (exclusive)
                                       >13.11.2006            -> 14.11.2006 - later
                                       13.11.2006-            -> 13.11.2006 - later
                                       <13.11.2006            -> earlier    - 13.11.2006 (exclusive)
                                       -13.11.2006            -> earlier    - 14.11.2006 (exclusive)
                                       Please do not forget to escape the greater or lesser than symbols (><, i.e. "--date=>13.11.2006").
                                       Short dates are supported if you include a trailing separator (i.e. 13.11.-11/15/).

--incremental Remember input file positions and optionally --no-duplicates statistics between executions in mysql_filter_slow_log.sqlite3

--no-duplicates Output only unique query strings with additional statistics:
                Execution count, first and last timestamp.
                Query time: avg / max / sum.
                Lock time: avg / max / sum.
                Rows examined: avg / max / sum.
                Rows sent: avg / max / sum.

--no-output Do not print statistics, just update database with incremental statistics

Default ordering of unique queries:
--sort-sum-query-time    [ 1. position]
--sort-avg-query-time    [ 2. position]
--sort-max-query-time    [ 3. position]
--sort-sum-lock-time     [ 4. position]
--sort-avg-lock-time     [ 5. position]
--sort-max-lock-time     [ 6. position]
--sort-sum-rows-examined [ 7. position]
--sort-avg-rows-examined [ 8. position]
--sort-max-rows-examined [ 9. position]
--sort-execution-count   [10. position]
--sort-sum-rows-sent     [11. position]
--sort-avg-rows-sent     [12. position]
--sort-max-rows-sent     [13. position]

--sort=sum-query-time,avg-query-time,max-query-time,...   You can include multiple sorting values separated by commas.
--sort=sqt,aqt,mqt,slt,alt,mlt,sre,are,mre,ec,srs,ars,mrs Every long sorting option has an equivalent short form (first character of each word).

--top=max_unique_query_count Output maximal max_unique_query_count different unique queries
--details                    Enables output of timestamp based unique query time lines after user list
                             (i.e. # Query_time: 81  Lock_time: 0  Rows_sent: 884  Rows_examined: 2448350).


--help Output this message only and quit

[multiple] options can be passed more than once to set multiple values.
[position] options take the position of their first occurrence into account.
           The first passed option will replace the default first sorting, ...
           Remaining default ordering options will keep their relative positions.
"""

import locale
import os
import re
import sys
import time


# http://aspn.activestate.com/ASPN/Cookbook/Python/Recipe/52560
locale.setlocale(locale.LC_NUMERIC,
                 os.name == 'nt' and 'en' or 'en_US.ISO8859-1')
def array_unique(seq):
    """Return a unique list of the sequence elements."""

    d ={}
    return [d.setdefault(e,e) for e in seq if e not in d]


# http://aspn.activestate.com/ASPN/Cookbook/Python/Recipe/473872
def number_format(num, places=0):
    """Format a number with grouped thousands and given decimal places"""

    return locale.format("%.*f", (places, num), True)


def cmp_query_times(a, b):
    """Compare two query executions by Query_time, Lock_time, Rows_examined."""

    for i in (0,1,3):
        if a[i] != b[i]:
            return -1 * cmp(a[i], b[i])
    return 0

def cmp_queries(a, b):
    """Compare two queries by the ordering defined in new_sorting."""

    for i in new_sorting:
        if a[1][i] != b[1][i]:
            return -1 * cmp(a[1][i], b[1][i])
    return 0

def cmp_users(a, b):
    """Compare two users lexicographically."""

    return cmp(a[0], b[0])

def process_query(queries, query, no_duplicates, user, host, timestamp,
                  query_time, ls):
    """Print or save query for later printing."""

    user_host = user + ' @ ' + host
    if no_duplicates:
        if not queries.has_key(query):
            queries[query] = {}
        if not queries[query].has_key(user_host):
            queries[query][user_host] = {timestamp: query_time}
        else:
            queries[query][user_host][timestamp] = query_time
    else:
        print '# Time: %s%s# User@Host: %s%s# Query_time: %d  Lock_time: %d  '\
              'Rows_sent: %d  Rows_examined: %d%s%s%s' % (timestamp, ls,
              user_host, ls, query_time[0], query_time[1], query_time[2],
              query_time[3], ls, query, ls),

def get_log_timestamp(t):
    return time.mktime(time.strptime(t, '%y%m%d %H:%M:%S'))

def parse_date_range(date):
    """
Input:                    Date Range:
13.11.2006             -> 13.11.2006 - 14.11.2006 (exclusive)
13.11.2006-15.11.2006  -> 13.11.2006 - 16.11.2006 (exclusive)
15-11-2006-11/13/2006  -> 13.11.2006 - 16.11.2006 (exclusive)
>13.11.2006            -> 14.11.2006 - later
13.11.2006-            -> 13.11.2006 - later
<13.11.2006            -> earlier    - 13.11.2006 (exclusive)
-13.11.2006            -> earlier    - 14.11.2006 (exclusive)
"""

    date_first = date_last = False
    _date_first = _date_last = False
    date_regex = re.compile(r'''
    (                  # first date (don't match beginning of string)
    (?:\d{4}|\d{1,2})  # first part can be 1-2 or 4 digits long (DD, MM, YYYY)
    (?:[./-]?\d{1,2}[./-]?)? # middle part (1-2 digits), optionally separated
    (?:\d{4}|\d{1,2})? # end part (1-2, 4 digits), optionally separated
    )                  # end of first date
    (?:-(              # optional second date, separated by "-"
    (?:\d{4}|\d{1,2})  # first part can be 1-2 or 4 digits long (DD, MM, YYYY)
    (?:[./-]?\d{1,2})? # middle part (1-2 digits), optionally separated
    (?:[./-]?(?:\d{4}|\d{1,2}))? # end part (1-2, 4 digits), optionally separated
    ))?                # end of optional second date
    ''', re.VERBOSE)

    # Date range: < or > or -
    if date[0] in '<>-':
        match = date_regex.search(date)
        match = match and match.groups('') or ()
        time1 = parse_time(match[0])
        if time1:
            if '>' == date[0]: _date_first = time1 + 86400
            elif '-' == date[0]: _date_last = time1 + 86400
            elif '<' == date[0]: _date_last = time1
    else:
        match = date_regex.search(date)
        match = match and match.groups('') or ()
        if len(match) < 1:
            return (date_first, date_last)

        time1 = parse_time(match[0])
        time2 = len(match) > 1 and parse_time(match[1])
        if time2:
            if not time1:
                _date_last = time2 + 86400 # -13.11.2006
            else:
                _date_first = time1
                _date_last = time2
                if time2 < time1:
                    _date_first, _date_last = (_date_last, _date_first)
                _date_last += 86400 # 13.11.2006-15.11.2006
        elif time1:
            # TODO: --date=3.2-
            if len(date) == len(match[0]) or date[len(match[0])] != '-':
                _date_first = time1
                _date_last = time1 + 86400 # 13.11.2006
            else:
                _date_first = time1 # 13.11.2006-

    return (_date_first, _date_last)

def parse_time(date):
    """Return a unix timestamp from the given date."""

    if date and '-' == date[-1]:
        date = date[:-1]
    match = re.match(r'(\d{4}|\d{1,2})([./-])(\d{1,2})(?:\2(\d{4}|\d{1,2}))?', date)
    if match:
        formats = {'-': '%d-%m-%Y', '.': '%d.%m.%Y', '/': '%m/%d/%Y'}
        match = match.groups('')
        now = time.gmtime()
        date = '%s%s%s%s' % (match[0], match[1], match[2], match[1])
        date += str(now[0])[:4-len(match[3])] + match[3]
        try:
            return time.mktime(time.strptime(date, formats[match[1]]))
        except ValueError, e:
            pass

    return False


infile = None
min_query_time = 1
min_rows_examined = 0
include_hosts = []
exclude_hosts = []
include_users = []
exclude_users = []
include_queries = []
no_duplicates = False
no_output = False
details = False
date_first = False
date_last = False
ls = os.linesep
date_format = '%Y-%m-%d %H:%M:%S'
default_sorting = [4, 'sum-query-time', 2, 'avg-query-time', 3, 'max-query-time',
                   7, 'sum-lock-time', 5, 'avg-lock-time', 6, 'max-lock-time',
                   13, 'sum-rows-examined', 11, 'avg-rows-examined',
                   12, 'max-rows-examined', 1, 'execution-count',
                   10, 'sum-rows-sent', 8, 'avg-rows-sent', 9, 'max-rows-sent']
first_chars = lambda words: ''.join([word[0] for word in words])
# TODO: Is there an easier way to extend with each of the two value pairs?
for t in [[default_sorting[i], first_chars(default_sorting[i+1].split('-'))]
    for i in range(0, len(default_sorting), 2)]:
  default_sorting.extend(t)
new_sorting = []
top = 0
incremental = False

# Decode all parameters to Unicode before parsing
fs_encoding = sys.getfilesystemencoding()
sys.argv = [s.decode(fs_encoding) for s in sys.argv]

# TODO: use optparse
for arg in sys.argv[1:]:
    _arg = arg[:3]
    try:
        if '-T=' == _arg: min_query_time = abs(int(arg[3:]))
        elif '-R=' == _arg: min_rows_examined = abs(int(arg[3:]))
        elif '-ih' == _arg: include_hosts.append(arg[4:])
        elif '-eh' == _arg: exclude_hosts.append(arg[4:])
        elif '-iu' == _arg: include_users.append(arg[4:])
        elif '-eu' == _arg: exclude_users.append(arg[4:])
        elif '-iq' == _arg: include_queries.append(arg[4:])
        elif '--incremental' == arg: incremental = True
        elif '--no-duplicates' == arg: no_duplicates = True
        elif '--no-output' == arg: no_output = True
        elif '--details' == arg: details = True
        elif '--sort' == arg[:6] and len(arg) > 9 and arg[6] in '=-':
            for sorting in arg[7:].split(','):
                if not sorting.isdigit() and sorting in default_sorting:
                    i = default_sorting.index(sorting)-1
                    if default_sorting[i] not in new_sorting:
                        new_sorting.append(default_sorting[i])
        elif '--include-user=' == arg[:15]: include_users.append(arg[15:])
        elif '--exclude-user=' == arg[:15]: exclude_users.append(arg[15:])
        elif '--include-host=' == arg[:15]: include_hosts.append(arg[15:])
        elif '--exclude-host=' == arg[:15]: exclude_hosts.append(arg[15:])
        elif '--include-query=' == arg[:16]: include_queries.append(arg[16:])
        elif '--top=' == arg[:6]:
            _top = abs(int(arg[6:]))
            if _top:
                top = _top
        elif '--date=' == arg[:7] and len(arg) > 10:
            # Do not overwrite already parsed date values
            if date_first or date_last:
                continue
            date_first, date_last = parse_date_range(arg[7:])
        elif '--help' == arg:
            print >>sys.stderr, usage
            sys.exit()
        elif not infile and os.path.isfile(arg):
            infile = open(arg, 'r')
    except ValueError, e:
        pass

if not infile:
    try:
        sys.stdin.tell()
        infile = sys.stdin
    except IOError:
        print >>sys.stderr, "ERROR: No input data on STDIN available"
        sys.exit()

include_hosts = array_unique(include_hosts)
exclude_hosts = array_unique(exclude_hosts)
include_users = array_unique(include_users)
exclude_users = array_unique(exclude_users)
for i in range(0, len(default_sorting)-1, 2):
    if default_sorting[i] not in new_sorting:
        new_sorting.append(default_sorting[i])


in_query = False
query = ''
timestamp = ''
user = ''
query_time = []
queries = {}
con = None

if incremental:
    try:
        import sqlite3
    except ImportError, e:
        try:
            from pysqlite2 import dbapi2 as sqlite3
        except ImportError, e:
            print >>sys.stderr, "ERROR: Python sqlite3 module not available"
            sys.exit()
    con = sqlite3.connect("mysql_filter_slow_log.sqlite3")
    cur = con.cursor()
    cur.execute("CREATE TABLE IF NOT EXISTS files (file VARCHAR NOT NULL PRIMARY KEY, last_pos INTEGER NOT NULL DEFAULT 0, last_update INTEGER NOT NULL DEFAULT 0)")
    cur.execute("CREATE TABLE IF NOT EXISTS hosts (host_id INTEGER PRIMARY KEY, host VARCHAR(255) NOT NULL UNIQUE)")
    cur.execute("CREATE TABLE IF NOT EXISTS users (user_id INTEGER PRIMARY KEY, user VARCHAR(255) NOT NULL UNIQUE)")
    cur.execute("CREATE TABLE IF NOT EXISTS queries (query_id INTEGER PRIMARY KEY, query TEXT NOT NULL UNIQUE)")
    cur.execute("CREATE TABLE IF NOT EXISTS stats (host_id INTEGER UNSIGNED NOT NULL, user_id INTEGER UNSIGNED NOT NULL, query_id INTEGER UNSIGNED NOT NULL, unixdate INTEGER UNSIGNED NOT NULL, query_time INTEGER UNSIGNED NOT NULL, lock_time INTEGER UNSIGNED NOT NULL, rows_sent INTEGER UNSIGNED NOT NULL, rows_examined INTEGER UNSIGNED NOT NULL, PRIMARY KEY(host_id, user_id, query_id, unixdate))")
    # SELECT host,user,query,COUNT(unixdate) AS execution_count, avg(query_time) AS avg_query_time, max(query_time) AS max_query_time, sum(query_time) AS sum_query_time, avg(lock_time) AS avg_lock_time, max(lock_time) AS max_lock_time, sum(lock_time) AS sum_lock_time, avg(rows_examined) AS avg_rows_examined, max(rows_examined) AS max_rows_examined, sum(rows_examined) AS sum_rows_examined, avg(rows_sent) AS avg_rows_sent, max(rows_sent) AS max_rows_sent, sum(rows_sent) AS sum_rows_sent FROM stats LEFT JOIN hosts USING (host_id) LEFT JOIN users ON (users.user_id=stats.user_id) LEFT JOIN queries ON (queries.query_id=stats.query_id) GROUP BY stats.query_id ORDER BY sum_query_time DESC, avg_query_time DESC, max_query_time DESC, sum_lock_time DESC, avg_lock_time DESC, max_lock_time DESC, sum_rows_examined DESC, avg_rows_examined DESC, max_rows_examined DESC, execution_count DESC, sum_rows_sent DESC, avg_rows_sent DESC, max_rows_sent DESC;

    cur.execute("SELECT last_pos FROM files WHERE file=?", (infile.name,))
    last_pos = cur.fetchone()
    last_pos = last_pos and last_pos[0] or 0
    if last_pos: infile.seek(last_pos) # TODO: infile != stdin, last_pos < size

for line in infile:
    if not line: continue
    if line[0] == '#' and line[1] == ' ':
        if query:
            if include_queries:
                in_query = False
                for iq in include_queries:
                    if iq in query:
                        in_query = True
                        break
            if in_query:
                process_query(queries, query, no_duplicates, user, host,
                              timestamp, query_time, ls)
            query = ''
            in_query = False

        if line[2] == 'T':  # # Time: 070119 12:29:58
            timestamp = line[8:-1]
            t = get_log_timestamp(timestamp)
            if date_first and t < date_first or date_last and t > date_last:
                timestamp = False
        elif line[2] == 'U' and timestamp: # # User@Host: root[root] @ localhost []
            user, host = line[13:-1].split(' @ ', 2)

            if not include_hosts:
                in_query = True
                for eh in exclude_hosts:
                    if eh in host:
                        in_query = False
                        break
            else:
                in_query = False
                for ih in include_hosts:
                    if ih in host:
                        in_query = True
                        break

            if not in_query: continue

            if not include_users:
                in_query = True
                for eu in exclude_users:
                    if eu in user:
                        in_query = False
                        break
            else:
                in_query = False
                for iu in include_users:
                    if iu in user:
                        in_query = True
                        break
        # # Query_time: 0  Lock_time: 0  Rows_sent: 0  Rows_examined: 156
        elif in_query and line[2] == 'Q':
            numbers = line[12:-1].split(':')
            query_time = (int(numbers[1].split()[0]), int(numbers[2].split()[0]),
                          int(numbers[3].split()[0]), int(numbers[4]))
            in_query = query_time[0] >= min_query_time or (min_rows_examined
                       and query_time[3] >= min_rows_examined)

    elif in_query:
        query += line[:-1]

if query:
    process_query(queries, query, no_duplicates, user, host, timestamp,
                  query_time, ls)

if queries and no_duplicates:
    if con:
        db_queries = {}
        cur.execute("SELECT * FROM queries")
        for (id, query) in cur: db_queries[query] = id
        db_query_id = 1
        if db_queries:
            db_query_id = max(db_queries.values()) + 1

        db_hosts = {}
        cur.execute("SELECT * FROM hosts")
        for (id, host) in cur: db_hosts[host] = id
        db_host_id = 1
        if db_hosts:
            db_host_id = max(db_hosts.values()) + 1

        db_users = {}
        cur.execute("SELECT * FROM users")
        for (id, user) in cur: db_users[user] = id
        db_user_id = 1
        if db_users:
            db_userid = max(db_users.values()) + 1

    lines = {}
    for query, users in queries.items():
        if con:
            if query in db_queries:
                query_id = db_queries[query]
            else:
                query_id = db_query_id
                db_queries[query] = query_id
                cur.execute("INSERT INTO queries VALUES(?,?)", (query_id, query))
                db_query_id += 1

        execution_count = 0
        max_timestamp = 0.0
        min_timestamp = 2147483647.0 # MAX_INT
        sum_query_time = max_query_time = 0
        sum_lock_time = max_lock_time = 0
        sum_rows_examined = max_rows_examined = 0
        sum_rows_sent = max_rows_sent = 0
        output = ''
        for user, timestamps in sorted(users.iteritems(), cmp_users):
            output += "# User@Host: %s%s" % (user, ls)
            if con:
                user, host = user.split(' @ ', 2)
                if user in db_users:
                    user_id = db_users[user]
                else:
                    user_id = db_user_id
                    db_users[user] = user_id
                    cur.execute("INSERT INTO users VALUES(?,?)", (user_id, user))
                    db_user_id += 1
                if host in db_hosts:
                    host_id = db_hosts[host]
                else:
                    host_id = db_host_id
                    db_hosts[host] = host_id
                    cur.execute("INSERT INTO hosts VALUES(?,?)", (host_id, host))
                    db_host_id += 1

            query_times = {}
            for t, query_time in timestamps.iteritems():
                t = get_log_timestamp(t)
                if not query_times.has_key(query_time):
                    query_times[query_time] = "# Query_time: %d  Lock_time: "\
                        "%d  Rows_sent: %d  Rows_examined: %d%s" % (query_time[0],
                        query_time[1], query_time[2], query_time[3], ls)
                    if query_time[0] > max_query_time:
                        max_query_time = query_time[0]
                    if query_time[1] > max_lock_time:
                        max_lock_time = query_time[1]
                    if query_time[2] > max_rows_sent:
                        max_rows_sent = query_time[2]
                    if query_time[3] > max_rows_examined:
                        max_rows_examined = query_time[3]
                if t < min_timestamp:
                    min_timestamp = t
                elif t > max_timestamp:
                    max_timestamp = t
                sum_query_time += query_time[0]
                sum_lock_time += query_time[1]
                sum_rows_sent += query_time[2]
                sum_rows_examined += query_time[3]
                execution_count += 1

                if con:
                    cur.execute("REPLACE INTO stats VALUES(?,?,?,?,?,?,?,?)", (
                        host_id, user_id, query_id, t, query_time[0],
                        query_time[1], query_time[2], query_time[3]))

            if details:
                for query_time in sorted(query_times.iterkeys(), cmp_query_times):
                    output += query_times[query_time]
        output += "%s%s%s" % (ls, query, ls*2)
        avg_query_time = round(float(sum_query_time) / float(execution_count), 1)
        avg_lock_time = round(float(sum_lock_time) / float(execution_count), 1)
        avg_rows_sent = round(sum_rows_sent / execution_count, 0)
        avg_rows_examined = round(sum_rows_examined / execution_count, 0)
        lines[query] = [output, execution_count, avg_query_time, max_query_time,
                        sum_query_time, avg_lock_time, max_lock_time,
                        sum_lock_time, avg_rows_sent, max_rows_sent,
                        sum_rows_sent, avg_rows_examined, max_rows_examined,
                        sum_rows_examined, min_timestamp, max_timestamp]

    if no_output:
        lines.clear() # Do not output if incremental processing

    i = 0
    for query, data in sorted(lines.iteritems(), cmp_queries):
        # Determine maximum size for each column
        max_length = [3,3,3]
        for k in range(2, 14):
            c = k % 3
            if c == 2:
                c = 0
            else:
                c += 1 # 2 -> 2 -> 0 | 3 -> 0 -> 1 | 4 -> 1 -> 2
            data[k] = number_format(data[k], not c and 1 or 0)
            if len(data[k]) > max_length[c]:
                max_length[c] = len(data[k])

        # Remove trailing 0 if all average values end with it
        for c in [2,5,8,11]:
            if data[c][-1] != '0':
                break
        else:
            for c in [2,5,8,11]:
                data[c] = data[c][:-2]
            if max_length[0] >= 5:
                max_length[0] -= 2

        output, execution_count, avg_query_time, max_query_time,\
        sum_query_time, avg_lock_time, max_lock_time, sum_lock_time,\
        avg_rows_sent, max_rows_sent, sum_rows_sent, avg_rows_examined,\
        max_rows_examined, sum_rows_examined, min_timestamp, max_timestamp = data

        execution_count = number_format(data[1])
        print "# Execution count: %s time%s" % (execution_count, data[1] != 1 and 's' or ''),
        if max_timestamp:
          print "between %s and %s.%s" % (time.strftime(date_format, time.localtime(min_timestamp)), time.strftime(date_format, time.localtime(max_timestamp)), ls),
        else:
          print "on %s.%s" % (time.strftime(date_format, time.localtime(min_timestamp)), ls),

        print "# Column       :", 'avg'.rjust(max_length[0]), "|", 'max'.rjust(max_length[1]), "| %s%s" % ('sum'.rjust(max_length[2]), ls),
        print "# Query time   :", avg_query_time.rjust(max_length[0]), "|", max_query_time.rjust(max_length[1]), "| %s%s" % (sum_query_time.rjust(max_length[2]), ls),
        print "# Lock time    :", avg_lock_time.rjust(max_length[0]), "|", max_lock_time.rjust(max_length[1]), "| %s%s" % (sum_lock_time.rjust(max_length[2]), ls),
        print "# Rows examined:", avg_rows_examined.rjust(max_length[0]), "|", max_rows_examined.rjust(max_length[1]), "| %s%s" % (sum_rows_examined.rjust(max_length[2]), ls),
        print "# Rows sent    :", avg_rows_sent.rjust(max_length[0]), "|", max_rows_sent.rjust(max_length[1]), "| %s%s" % (sum_rows_sent.rjust(max_length[2]), ls),
        print output,

        if top:
            i += 1
            if i >= top:
                break

if con:
    cur.execute("REPLACE INTO files VALUES (?,?,strftime('%s','now'))", (infile.name,infile.tell()))
    con.commit()
    con.close()