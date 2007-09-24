#!/usr/bin/env python
# -*- coding: utf-8 -*-

# This program is free software; you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation; either version 2 of the License, or
# (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program; if not, write to the Free Software
# Foundation, Inc., 59 Temple Place, Suite 330, Boston, MA  02111-1307  USA

"""
mysqlpdump is a wrapper to mysqldump to process it in paralel

It uses various threads to connect to the MySQL server so it can perform the
dump much faster than in traditional way.

mysqlpdump tries to implement some of the suggestions that appeared in MySQL performance weblog:
http://www.mysqlperformanceblog.com/2007/05/22/wishes-for-mysqldump/

Changelog:

- 0.1 
    - First version
- 0.2
    - Store dumps to files directly instead to stdout
    - Can compress files
    - Dump each table in its own file
    - Can pass parameters directly to mysqldump
- 0.3
    - Fixed a bug that prevented the tables of being dumped because of a lock
    - Added --master-data option to write "CHANGE MASTER TO " statement
- 0.4
    - Made it compatible with python 2.4
    - Can include and exclude specified databases.
- 0.5
    - Compress 00_master_data.sql file if specified
    - bugfix: when it's called without a terminal or a logged user, it uses "nobody".
    - bugfix: destination now works with 00_master_data.sql
"""

__title__ = "mysqlpdump"
__version__ = "0.5"
__author__= "Carles Amigo"
__email__= "fr3nd at fr3nd dot net"
__website__= "http://www.fr3nd.net/projects/mysqlpdump"

import threading, Queue
import MySQLdb
from optparse import OptionParser
import commands
import sys
import os
import gzip

class Log:
    """Simple class for logging"""
    def __init__(self, verbose):
        self.verbose = verbose
        
    def log(self, line):
        """Logs an especified line"""
        if self.verbose:
            sys.stderr.write (" - " + str(line) + "\n")

class Database:
    """Class to handle database connection"""
    def __init__(self, log, mysqluser, mysqlpass, mysqlhost):
        self.user = mysqluser
        self.password = mysqlpass
        self.host = mysqlhost
        self.log = log
        self.log.log("Connecting to database")
        self.db=MySQLdb.connect(user=mysqluser,passwd=mysqlpass,host=mysqlhost)
        self.cursor = self.db.cursor()
    
    def close(self):
        self.log.log("Closing database connection")
        self.db.close()
    
    def lock(self):
        """Locks all tables for read/write"""
        self.log.log("Locking all tables")
        self.cursor.execute("FLUSH TABLES WITH READ LOCK;")

    def unlock(self):
        """Unlocks all tables in the database"""
        self.log.log("Unlocking all tables")
        self.cursor.execute("UNLOCK TABLES")
    
    def get_databases(self, included, excluded):
        """Return all the databases. Included and excluded databases can be specified"""
        self.cursor.execute("show databases;")
        result = self.cursor.fetchall()
        databases = []
        for database in result:
            if len(included) == 0:          
                if database[0] not in excluded:
                    databases.append(database[0])
            else:
                if (database[0] in included) and (database[0] not in excluded):
                    databases.append(database[0])
        return databases

    def get_tables(self, database):
        """Return all tables for a given database"""
        self.cursor.execute("show tables from " + str(database) + ";")
        result = self.cursor.fetchall()
        tables = []
        for table in result:
            tables.append(table[0])
        return tables
    
    def get_slave_status(self):
        """Return slave status"""
        self.cursor.execute("show slave status;")
        result = self.cursor.fetchall()
        return result
    
    def get_change_master_to(self, slave_status):
        try:
            return "CHANGE MASTER TO MASTER_HOST=\'" + slave_status[0][1] + "\', MASTER_LOG_FILE=\'" + slave_status[0][5] + "\', MASTER_LOG_POS=" + str(slave_status[0][6]) + ";"
        except:
            return ""
    
    def mysqldump(self, database, table, destination, custom_parameters="", stdout=False, gzip=False, mysqldump="/usr/bin/mysqldump"):
        """Dumps a specified table. 
        It can dump it to a file or just return all the dumped data.
        It can waste a lot of memory if its returning a big table."""
        
        default_parameters = "--skip-lock-tables"
        
        cmd=mysqldump + " " + default_parameters
        if custom_parameters != "":
            cmd = cmd + " " + custom_parameters
        cmd = cmd + " -u" + self.user + " -p" + self.password + " -h" + self.host + " " + database + " " + table
        if stdout:
            return commands.getstatusoutput(cmd)
        else:
            file = destination + "/" + database + "-" + table + ".sql"
            if gzip:
                cmd = cmd + " | gzip -c > " + file + ".gz"
            else:
                cmd = cmd + " > " + file
            os.system(cmd)
            return (None, None)
            
        
class Worker(threading.Thread):
    def __init__(self, queue, log, db, event_dict, destination, custom_parameters="", stdout=False, gzip=False, ):
        threading.Thread.__init__(self)
        self.queue = queue
        self.log = log
        self.db = db
        self.event_dict = event_dict
        self.stdout = stdout
        self.gzip = gzip
        self.destination = destination
        self.custom_parameters = custom_parameters
    
    def run(self):
        self.log.log("Worker " + self.getName() + " started")
        while True:
            try:
                num, database, table = self.queue.get(True, 1)
            except Queue.Empty:
                break
            self.event_dict[num] = threading.Event()
            self.event_dict[num].clear()
            self.log.log(self.getName() + " dumping " + database + " " + table)
            status, output = self.db.mysqldump(database, table, custom_parameters=self.custom_parameters, stdout=self.stdout, gzip=self.gzip, destination=self.destination)
            if self.stdout:
                if num > 0:
                    while not self.event_dict[num-1].isSet():
                        self.event_dict[num-1].wait()
            self.log.log(self.getName() + " dumped " + database + " " + table)
            if output:
                print output
            self.event_dict[num].set()

def main():
    try:
        current_user = os.getlogin()
    except:
        current_user = "nobody"
        
    usage = "usage: %prog [options]\n Run mysqldump in paralel"
    parser = OptionParser(usage, version=__version__)
    parser.add_option("-v", "--verbose", action="store_true", dest="verbose", default=False, help="verbose output.")
    parser.add_option("-u", "--user", action="store", dest="user", type="string", default=current_user, help="User for login.")
    parser.add_option("-p", "--password", action="store", dest="password", type="string", default='', help="Password for login.")
    parser.add_option("-H", "--host", action="store", dest="host", type="string", default='localhost', help="Connect to host.")
    parser.add_option("-t", "--threads", action="store", dest="threads", type="int", default=5, help="Threads used. Default = 5")
    parser.add_option("-s", "--stdout", action="store_true", dest="stdout", default=False, help="Output dumps to stdout instead to files. WARNING: It can exaust all your memory!")
    parser.add_option("-g", "--gzip", action="store_true", dest="gzip", default=False, help="Add gzip compression to files.")
    parser.add_option("-m", "--master-data", action="store_true", dest="master_data", default=False, help="This causes the binary log position and filename to be written to the file 00_master_data.sql.")
    parser.add_option("-d", "--destination", action="store", dest="destination", type="string", default=".", help="Path where to store generated dumps.")
    parser.add_option("-P", "--parameters", action="store", dest="parameters", type="string", default="", help="Pass parameters directly to mysqldump.")
    parser.add_option("-i", "--include_database", action="append", dest="included_databases", default=[], help="Databases to be dumped. By default, all databases are dumped. Can be called more than one time.")
    parser.add_option("-e", "--exclude_database", action="append", dest="excluded_databases", default=[], help="Databases to be excluded from the dump. No database is excluded by default. Can be called more than one time.")
    

    (options, args) = parser.parse_args()
    
    log = Log(options.verbose)
    try:
        db = Database(log, options.user, options.password, options.host)
    except:
        parser.error("Cannot connect to database")
    db.lock()
    queue = Queue.Queue()
    
    x = 0
    
    if options.master_data:
        if options.gzip:
            f=gzip.open(options.destination + '/00_master_data.sql.gz', 'w')
        else:
            f=open(options.destination + '/00_master_data.sql', 'w')
        f.write(db.get_change_master_to(db.get_slave_status()))
        f.write('\n')
        f.close()
    
    for database in db.get_databases(options.included_databases, options.excluded_databases):
        for table in db.get_tables(database):
            queue.put([x,database,table])
            x = x + 1

    event_dict = {}
    threads = []
    x = 0
    for i in range(options.threads):
        threads.append(Worker(queue, log, db, event_dict, custom_parameters=options.parameters, stdout=options.stdout, gzip=options.gzip, destination=options.destination))
        threads[x].setDaemon(True)
        threads[x].start()
        x = x + 1
    
    # Wait for all threads to finish
    for thread in threads:
        thread.join()
    
    db.unlock()
    db.close()

if __name__ == "__main__":
    main()
