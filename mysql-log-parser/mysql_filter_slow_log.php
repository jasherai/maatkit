<?php

/*
MySQL Log Filter 1.9
=====================

Copyright 2007 René Leonhardt

Website: http://code.google.com/p/mysql-log-filter/

This program is free software; you can redistribute it and/or
modify it under the terms of the GNU General Public License
as published by the Free Software Foundation; either version 2
of the License, or (at your option) any later version.

This program is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
GNU General Public License for more details.

You should have received a copy of the GNU General Public License
along with this program; if not, write to the Free Software
Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA  02110-1301, USA.

ABOUT MySQL Log Filter
=======================
The MySQL Log Filter allows you to easily filter only useful information of the
MySQL Slow Query Log.


LICENSE
=======
This code is released under the GPL. The full code is available from the website
listed above.

*/


/**
 * Parse the MySQL Slow Query Log from file or STDIN and write all filtered queries or statistics to STDOUT.
 *
 * In order to activate it see http://dev.mysql.com/doc/refman/5.1/en/slow-query-log.html.
 * For example you could add the following lines to your my.ini or my.cnf configuration file under the [mysqld] section:
 *
 * long_query_time=3
 * log-slow-queries
 * log-queries-not-using-indexes
 *
 *
 * Required PHP extensions:
 * - BCMath
 * - PDO SQLite (SQLite 3) for --incremental
 *
 *
 * Example input lines:
 *
 * # Time: 070119 12:29:58
 * # User@Host: root[root] @ localhost []
 * # Query_time: 1  Lock_time: 0  Rows_sent: 1  Rows_examined: 12345
 * SELECT * FROM test;
 *
 */

$usage = <<<EOD
MySQL Slow Query Log Filter 1.9 for PHP5 (requires BCMath extension)

Usage:

# Filter slow queries executed for at least 3 seconds not from root, remove duplicates,
# apply execution count as first sorting value and save first 10 unique queries to file.
# In addition, remember last input file position and statistics.
php mysql_filter_slow_log.php -T=3 -eu=root --no-duplicates --sort-execution-count --top=10 --incremental linux-slow.log > mysql-slow-queries.log

# Start permanent filtering of all slow queries from now on: at least 3 seconds or examining 10000 rows, exclude users root and test
tail -f -n 0 linux-slow.log | php mysql_filter_slow_log.php -T=3 -R=10000 -eu=root -eu=test &
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
EOD;


function cmp_queries(&$a, &$b) {
  foreach($GLOBALS['new_sorting'] as $i)
    if($a[$i] != $b[$i])
      return 10 == $i || 13 == $i ? -1 * bccomp($a[$i], $b[$i]) : ($a[$i] < $b[$i] ? 1 : -1);
  return 0;
}

function cmp_query_times(&$a, &$b) {
  foreach(array(0,1,3) as $i)
    if($a[$i] != $b[$i]) return $a[$i] < $b[$i] ? 1 : -1;
  return 0;
}

function process_query(&$queries, $query, $no_duplicates, $user, $host, $timestamp, $query_time, $ls) {
  if($no_duplicates)
    $queries[$query][$user . ' @ ' . $host][$timestamp] = $query_time;
  else
    echo '# Time: ', $timestamp, $ls, "# User@Host: ", $user, ' @ ', $host, $ls, "# Query_time: $query_time[0]  Lock_time: $query_time[1]  Rows_sent: $query_time[2]  Rows_examined: $query_time[3]", $ls, $query, $ls;
}

function get_log_timestamp($t) {
  // Note: strptime not available on Windows
  return mktime (substr($t,7,2), substr($t,10,2), substr($t,13,2), substr($t,2,2), substr($t,4,2), substr($t,0,2) + 2000);
}

/**
 * Input:                    Date Range:
 * 13.11.2006             -> 13.11.2006 - 14.11.2006 (exclusive)
 * 13.11.2006-15.11.2006  -> 13.11.2006 - 16.11.2006 (exclusive)
 * 15-11-2006-11/13/2006  -> 13.11.2006 - 16.11.2006 (exclusive)
 * >13.11.2006            -> 14.11.2006 - later
 * 13.11.2006-            -> 13.11.2006 - later
 * <13.11.2006            -> earlier    - 13.11.2006 (exclusive)
 * -13.11.2006            -> earlier    - 14.11.2006 (exclusive)
 */
function parse_date_range($date) {
  $date_first = $date_last = FALSE;
  $_date_first = $_date_last = FALSE;

  $date_regex = '°((?:\d{4}|\d{1,2})(?:[./-]?\d{1,2}[./-]?)(?:\d{4}|\d{1,2})?)(?:-((?:\d{4}|\d{1,2})(?:[./-]?\d{1,2})?(?:[./-]?(?:\d{4}|\d{1,2}))?))?°';

  // Date range: < or > or -
  if(strpos(' <>-', $date[0])) {
    if(preg_match($date_regex, $date, $match)
     && isset($match[1]) && (FALSE !== $time1 = parse_time($match[1]))) {
       switch($date[0]) {
         case '>': $_date_first = $time1 + 86400; break;
         case '-': $_date_last = $time1 + 86400; break;
         case '<': $_date_last = $time1; break;
       }
    }
  } else {
    if(! preg_match($date_regex, $date, $match) || ! isset($match[1]))
      return array($date_first, $date_last);

    $time1 = parse_time($match[1]);
    if(isset($match[2]) && (FALSE !== $time2 = parse_time($match[2]))) {
      if(FALSE === $time1) {
        $_date_last = $time2 + 86400; // -13.11.2006
      } else {
        $_date_first = $time1;
        $_date_last = $time2;
        if($time2 < $time1)
          list($_date_first, $_date_last) = array($_date_last, $_date_first);
        $_date_last += 86400; // 13.11.2006-15.11.2006
      }
    } else if(FALSE !== $time1) {
      // TODO: --date=3.2-
      if(strlen($date) == strlen($match[1]) || $date[strlen($match[1])] != '-') {
        $_date_first = $time1;
        $_date_last = $time1 + 86400; // 13.11.2006
      } else {
        $_date_first = $time1; // 13.11.2006-
      }

    }
  }
  return array($_date_first, $_date_last);
}

/** Return a unix timestamp from the given date. */
function parse_time($date) {
  if($date && '-' == $date[strlen($date) -1])
    $date = substr($date, 0, -1);
  if(preg_match('°(\d{4}|\d{1,2})([./-])(\d{1,2})(?:\2(\d{4}|\d{1,2}))?°', $date, $match)) {
    if(! isset($match[4])) $match[4] = '';
    $formats = array('-' => '%d-%match-%Y', '.' => '%d.%match.%Y', '/' => '%match/%d/%Y');
    $now = array(idate('Y'));
    $date = "$match[1]$match[2]$match[3]$match[2]";
    $date .= substr($now[0], 0, 4-strlen($match[4])) . $match[4];

    return strtotime($date);
  }

  return FALSE;
}


$infile = NULL;
$min_query_time = 1;
$min_rows_examined = 0;
$include_hosts = array();
$exclude_hosts = array();
$include_users = array();
$exclude_users = array();
$include_queries = array();
$no_duplicates = FALSE;
$no_output = FALSE;
$details = FALSE;
$date_first = FALSE;
$date_last = FALSE;
$ls = defined('PHP_EOL') ? PHP_EOL : "\n";
$default_sorting = array_flip(array(4=>'sum-query-time', 2=>'avg-query-time', 3=>'max-query-time', 7=>'sum-lock-time', 5=>'avg-lock-time', 6=>'max-lock-time', 13=>'sum-rows-examined', 11=>'avg-rows-examined', 12=>'max-rows-examined', 1=>'execution-count', 10=>'sum-rows-sent', 8=>'avg-rows-sent', 9=>'max-rows-sent'));
foreach($default_sorting as $k => $v) {
  $_key = '';
  foreach(explode('-', $k) as $_word)
    $_key .= $_word[0];
  $default_sorting[$_key] = $v;
}
$new_sorting = array();
$top = 0;
$incremental = false;

unset($_SERVER['argv'][0]);
foreach($_SERVER['argv'] as $arg) {
  switch(substr($arg, 0, 3)) {
    case '-T=': $min_query_time = abs(substr($arg, 3)); break;
    case '-R=': $min_rows_examined = abs(substr($arg, 3)); break;
    case '-ih': $include_hosts[] = substr($arg, 4); break;
    case '-eh': $exclude_hosts[] = substr($arg, 4); break;
    case '-iu': $include_users[] = substr($arg, 4); break;
    case '-eu': $exclude_users[] = substr($arg, 4); break;
    case '-iq': $include_queries[] = substr($arg, 4); break;
    default:
      if('--sort' == substr($arg, 0, 6) && strlen($arg) > 9 && strpos(' -=', $arg[6])) {
        foreach(explode(',', substr($arg, 7)) as $sorting) {
          if(isset($default_sorting[$sorting]) && ! in_array($default_sorting[$sorting], $new_sorting))
            $new_sorting[] = $default_sorting[$sorting];
        }
      } else if('--include-user=' == substr($arg, 0, 15)) {
        $include_users[] = substr($arg, 15);
      } else if('--exclude-user=' == substr($arg, 0, 15)) {
        $exclude_users[] = substr($arg, 15);
      } else if('--include-host=' == substr($arg, 0, 15)) {
        $include_hosts[] = substr($arg, 15);
      } else if('--exclude-host=' == substr($arg, 0, 15)) {
        $exclude_hosts[] = substr($arg, 15);
      } else if('--include-query=' == substr($arg, 0, 16)) {
        $include_queries[] = substr($arg, 16);
      } else if('--top=' == substr($arg, 0, 6)) {
        if($_top = abs(substr($arg, 6)))
          $top = $_top;
      } else if('--date=' == substr($arg, 0, 7) && strlen($arg) > 10) {
        // Do not overwrite already parsed date values
        if($date_first || $date_last)
          continue;
        list($date_first, $date_last) = parse_date_range(substr($arg, 7));
      } else switch($arg) {
        case '--no-duplicates': $no_duplicates = TRUE; break;
        case '--no-output': $no_output = TRUE; break;
        case '--incremental': $incremental = TRUE; break;
        case '--details': $details = TRUE; break;
        case '--help': fwrite(STDERR, $usage); exit(0);
        default:
          if(!$infile && is_file($arg)) {
            $infile = fopen($arg, 'r');
            $infile_name = $arg;
          }
      }
      break;
  }
}

if(! $infile) {
  if(0 !== ftell(STDIN)) {
    fwrite(STDERR, "ERROR: No input data on STDIN available\n");
    exit;
  }
  $infile = STDIN;
  $infile_name = '<stdin>';
}

$include_hosts = array_unique($include_hosts);
$exclude_hosts = array_unique($exclude_hosts);
$include_users = array_unique($include_users);
$exclude_users = array_unique($exclude_users);
foreach($default_sorting as $i)
  if(! in_array($i, $new_sorting))
    $new_sorting[] = $i;


$in_query = FALSE;
$query = '';
$timestamp = '';
$user = '';
$query_time = array();
$queries = array();
$con = NULL;

if($incremental) {
    if (!extension_loaded('pdo_sqlite')) {
      fwrite(STDERR, "ERROR: PHP PDO SQLite (SQLite3) extension not available\n");
      exit;
    }
    $con = new PDO("sqlite:mysql_filter_slow_log.sqlite3", "", "", array(PDO::ATTR_DEFAULT_FETCH_MODE=>PDO::FETCH_NUM));
    $con->beginTransaction();
    $con->exec("CREATE TABLE IF NOT EXISTS files (file VARCHAR NOT NULL PRIMARY KEY, last_pos INTEGER NOT NULL DEFAULT 0, last_update INTEGER NOT NULL DEFAULT 0)");
    $con->exec("CREATE TABLE IF NOT EXISTS hosts (host_id INTEGER PRIMARY KEY, host VARCHAR(255) NOT NULL UNIQUE)");
    $con->exec("CREATE TABLE IF NOT EXISTS users (user_id INTEGER PRIMARY KEY, user VARCHAR(255) NOT NULL UNIQUE)");
    $con->exec("CREATE TABLE IF NOT EXISTS queries (query_id INTEGER PRIMARY KEY, query TEXT NOT NULL UNIQUE)");
    $con->exec("CREATE TABLE IF NOT EXISTS stats (host_id INTEGER UNSIGNED NOT NULL, user_id INTEGER UNSIGNED NOT NULL, query_id INTEGER UNSIGNED NOT NULL, unixdate INTEGER UNSIGNED NOT NULL, query_time INTEGER UNSIGNED NOT NULL, lock_time INTEGER UNSIGNED NOT NULL, rows_sent INTEGER UNSIGNED NOT NULL, rows_examined INTEGER UNSIGNED NOT NULL, PRIMARY KEY(host_id, user_id, query_id, unixdate))");
    // SELECT host,user,query,COUNT(unixdate) AS execution_count, avg(query_time) AS avg_query_time, max(query_time) AS max_query_time, sum(query_time) AS sum_query_time, avg(lock_time) AS avg_lock_time, max(lock_time) AS max_lock_time, sum(lock_time) AS sum_lock_time, avg(rows_examined) AS avg_rows_examined, max(rows_examined) AS max_rows_examined, sum(rows_examined) AS sum_rows_examined, avg(rows_sent) AS avg_rows_sent, max(rows_sent) AS max_rows_sent, sum(rows_sent) AS sum_rows_sent FROM stats LEFT JOIN hosts USING (host_id) LEFT JOIN users ON (users.user_id=stats.user_id) LEFT JOIN queries ON (queries.query_id=stats.query_id) GROUP BY stats.query_id ORDER BY sum_query_time DESC, avg_query_time DESC, max_query_time DESC, sum_lock_time DESC, avg_lock_time DESC, max_lock_time DESC, sum_rows_examined DESC, avg_rows_examined DESC, max_rows_examined DESC, execution_count DESC, sum_rows_sent DESC, avg_rows_sent DESC, max_rows_sent DESC;

    $cur = $con->prepare("SELECT last_pos FROM files WHERE file=?");
    $cur->execute(array($infile_name));
    $last_pos = $cur->fetchColumn(0);
    if($last_pos) fseek($infile, $last_pos); // TODO: infile != stdin, last_pos < size
}

while(! feof($infile)) {
  if(! ($line = stream_get_line($infile, 10000, "\n"))) continue;
  if($line[0] == '#' && $line[1] == ' ') {
    if($query) {
      if($include_queries) {
        $in_query = FALSE;
        foreach($include_queries as $iq)
          if(FALSE !== stripos($query, $iq)) {
            $in_query = TRUE;
            break;
          }
      }
      if($in_query)
        process_query($queries, $query, $no_duplicates, $user, $host, $timestamp, $query_time, $ls);
      $query = '';
      $in_query = FALSE;
    }

    if($line[2] == 'T') { // # Time: 070119 12:29:58
      $timestamp = substr($line, 8);
      $t = get_log_timestamp($timestamp);
      if(($date_first && $t < $date_first) || ($date_last && $t > $date_last))
        $timestamp = FALSE;
    } else if(($line[2] == 'U') && $timestamp) { // # User@Host: root[root] @ localhost []
      list($user, $host) = explode(' @ ', substr($line, 13), 2);

      if(! $include_hosts) {
        $in_query = TRUE;
        foreach($exclude_hosts as $eh)
          if(FALSE !== stripos($host, $eh)) {
            $in_query = FALSE;
            break;
          }
      } else {
        $in_query = FALSE;
        foreach($include_hosts as $ih)
          if(FALSE !== stripos($host, $ih)) {
            $in_query = TRUE;
            break;
          }
      }

      if(! $in_query) continue;

      if(! $include_users) {
        $in_query = TRUE;
        foreach($exclude_users as $eu)
          if(FALSE !== stripos($user, $eu)) {
            $in_query = FALSE;
            break;
          }
      } else {
        $in_query = FALSE;
        foreach($include_users as $iu)
          if(FALSE !== stripos($user, $iu)) {
            $in_query = TRUE;
            break;
          }
      }
    } else if($in_query && $line[2] == 'Q') { // # Query_time: 0  Lock_time: 0  Rows_sent: 0  Rows_examined: 156
      $numbers = explode(': ', substr($line, 12));
      $query_time = array((int) $numbers[1], (int) $numbers[2], (int) $numbers[3], (int) $numbers[4]);
      $in_query = $query_time[0] >= $min_query_time || ($min_rows_examined && $query_time[3] >= $min_rows_examined);
    }
  } else if($in_query) {
    $query .= $line;
  }
}

if($query)
  process_query($queries, $query, $no_duplicates, $user, $host, $timestamp, $query_time, $ls);


if($queries && $no_duplicates) {
  if($con) {
    $db_queries = array();
    foreach($con->query("SELECT * FROM queries") as $row)
      $db_queries[$row[1]] = $row[0];
    $db_query_id = 1;
    if($db_queries)
      $db_query_id = max($db_queries) + 1;

    $db_hosts = array();
    foreach($con->query("SELECT * FROM hosts") as $row)
      $db_hosts[$row[1]] = $row[0];
    $db_host_id = 1;
    if($db_hosts)
      $db_host_id = max($db_hosts) + 1;

    $db_users = array();
    foreach($con->query("SELECT * FROM users") as $row)
      $db_users[$row[1]] = $row[0];
    $db_user_id = 1;
    if($db_users)
      $db_user_id = max($db_users) + 1;
  }

  $lines = array();
  foreach($queries as $query => &$users) {
    if($con) {
      if(isset($db_queries[$query]))
        $query_id = $db_queries[$query];
      else {
        $query_id = $db_query_id;
        $db_queries[$query] = $query_id;
        $cur = $con->prepare("INSERT INTO queries VALUES(?,?)");
        $cur->execute(array($query_id, $query));
        $db_query_id++;
      }
    }

    $execution_count = $max_timestamp = 0;
    $min_timestamp = 2147483647; // MAX_INT
    $sum_query_time = $max_query_time = 0;
    $sum_lock_time = $max_lock_time = 0;
    $sum_rows_examined = '0'; $max_rows_examined = 0;
    $sum_rows_sent = '0'; $max_rows_sent = 0;
    $output = '';
    ksort($users);
    foreach($users as $user => &$timestamps) {
      $output .= "# User@Host: ". $user. $ls;
      if($con) {
        list($user, $host) = explode(' @ ', $user, 2);
        if(isset($db_users[$user]))
          $user_id = $db_users[$user];
        else {
          $user_id = $db_user_id;
          $db_users[$user] = $user_id;
          $cur = $con->prepare("INSERT INTO users VALUES(?,?)");
          $cur->execute(array($user_id, $user));
          $db_user_id++;
        }
        if(isset($db_hosts[$host]))
          $host_id = $db_hosts[$host];
        else {
          $host_id = $db_host_id;
          $db_hosts[$host] = $host_id;
          $cur = $con->prepare("INSERT INTO hosts VALUES(?,?)");
          $cur->execute(array($host_id, $host));
          $db_host_id++;
        }
      }

      uasort($timestamps, 'cmp_query_times');
      $query_times = array();
      foreach($timestamps as $t => $query_time) {
        $t = get_log_timestamp($t);
        $query_times["# Query_time: $query_time[0]  Lock_time: $query_time[1]  Rows_sent: $query_time[2]  Rows_examined: $query_time[3]$ls"] = 1;
        if($query_time[0] > $max_query_time)
          $max_query_time = $query_time[0];
        if($query_time[1] > $max_lock_time)
          $max_lock_time = $query_time[1];
        if($query_time[2] > $max_rows_sent)
          $max_rows_sent = $query_time[2];
        if($query_time[3] > $max_rows_examined)
          $max_rows_examined = $query_time[3];
        if($t < $min_timestamp)
          $min_timestamp = $t;
        else if($t > $max_timestamp)
          $max_timestamp = $t;
        $sum_query_time += $query_time[0];
        $sum_lock_time += $query_time[1];
        $sum_rows_sent = bcadd($sum_rows_sent, $query_time[2]);
        $sum_rows_examined = bcadd($sum_rows_examined, $query_time[3]);
        $execution_count++;

        if($con) {
          $cur = $con->prepare("REPLACE INTO stats VALUES(?,?,?,?,?,?,?,?)");
          $cur->execute(array($host_id, $user_id, $query_id, $t, $query_time[0], $query_time[1], $query_time[2], $query_time[3]));
        }
      }
      if($details)
        $output .= implode('', array_keys($query_times));
    }
    $output .= $ls . $query . $ls . $ls;
    $avg_query_time = round($sum_query_time / $execution_count, 1);
    $avg_lock_time = round($sum_lock_time / $execution_count, 1);
    $avg_rows_sent = bcdiv($sum_rows_sent, $execution_count, 1);
    $avg_rows_examined = bcdiv($sum_rows_examined, $execution_count, 1);
    $lines[$query] = array($output, $execution_count, $avg_query_time, $max_query_time, $sum_query_time, $avg_lock_time, $max_lock_time, $sum_lock_time, $avg_rows_sent, $max_rows_sent, $sum_rows_sent, $avg_rows_examined, $max_rows_examined, $sum_rows_examined, $min_timestamp, $max_timestamp);
  }

  if($no_output)
    $lines = array(); // Do not output if incremental processing

  uasort($lines, 'cmp_queries');
  $i = 0;
  foreach($lines as $query => &$data) {
    // Determine maximum size for each column
    $max_length = array(3,3,3);
    for($k=2; $k < 14; $k++) {
      $c = $k % 3;
      $c = $c == 2 ? 0 : $c + 1; // 2 -> 2 -> 0 | 3 -> 0 -> 1 | 4 -> 1 -> 2
      $data[$k] = number_format($data[$k], $c == 0 ? 1 : 0, '.', ',');
      if(($l = strlen($data[$k])) > $max_length[$c])
        $max_length[$c] = $l;
    }

    // Remove trailing 0 if all average values end with it
    for($k=1; $k<3; $k++) {
      foreach(array(2,5,8,11) as $c)
        if(substr($data[$c], -1) != 0)
          break 2;
      foreach(array(2,5,8,11) as $c)
        $data[$c] = substr($data[$c], 0, -2);
      if($max_length[0] >= 5)
        $max_length[0] -= 2;
    }

    list($output, $execution_count, $avg_query_time, $max_query_time, $sum_query_time, $avg_lock_time, $max_lock_time, $sum_lock_time, $avg_rows_sent, $max_rows_sent, $sum_rows_sent, $avg_rows_examined, $max_rows_examined, $sum_rows_examined, $min_timestamp, $max_timestamp) = $data;

    $execution_count = number_format($data[1], 0, '.', ',');
    echo "# Execution count: $execution_count time", ($data[1] == 1 ? '' : 's') . ' ';
    if($max_timestamp)
      echo "between ", date('Y-m-d H:i:s', $min_timestamp), ' and ', date('Y-m-d H:i:s', $max_timestamp);
    else
      echo "on ", date('Y-m-d H:i:s', $min_timestamp);
    echo '.', $ls;

    echo "# Column       : ", str_pad('avg', $max_length[0], ' ', STR_PAD_LEFT), " | ", str_pad('max', $max_length[1], ' ', STR_PAD_LEFT), " | ", str_pad('sum', $max_length[2], ' ', STR_PAD_LEFT), $ls;
    echo "# Query time   : ", str_pad($avg_query_time, $max_length[0], ' ', STR_PAD_LEFT), " | ", str_pad($max_query_time, $max_length[1], ' ', STR_PAD_LEFT), " | ", str_pad($sum_query_time, $max_length[2], ' ', STR_PAD_LEFT), $ls;
    echo "# Lock time    : ", str_pad($avg_lock_time, $max_length[0], ' ', STR_PAD_LEFT), " | ", str_pad($max_lock_time, $max_length[1], ' ', STR_PAD_LEFT), " | ", str_pad($sum_lock_time, $max_length[2], ' ', STR_PAD_LEFT), $ls;
    echo "# Rows examined: ", str_pad($avg_rows_examined, $max_length[0], ' ', STR_PAD_LEFT), " | ", str_pad($max_rows_examined, $max_length[1], ' ', STR_PAD_LEFT), " | ", str_pad($sum_rows_examined, $max_length[2], ' ', STR_PAD_LEFT), $ls;
    echo "# Rows sent    : ", str_pad($avg_rows_sent, $max_length[0], ' ', STR_PAD_LEFT), " | ", str_pad($max_rows_sent, $max_length[1], ' ', STR_PAD_LEFT), " | ", str_pad($sum_rows_sent, $max_length[2], ' ', STR_PAD_LEFT), $ls;
    echo $output;

    if($top) {
      $i++;
      if($i >= $top)
        break;
    }
  }
}


if($con) {
  $cur = $con->prepare("REPLACE INTO files VALUES (?,?,strftime('%s','now'))");
  $cur->execute(array($infile_name, ftell($infile)));
  $con->commit();
  unset($con);
}
?>