mysql> explain select * from sakila.film where 3 in (select 2 union select 1 from sakila.actor);
+----+--------------------+------------+------+---------------+------+---------+------+------+-----------------------------------------------------+
| id | select_type        | table      | type | possible_keys | key  | key_len | ref  | rows | Extra                                               |
+----+--------------------+------------+------+---------------+------+---------+------+------+-----------------------------------------------------+
|  1 | PRIMARY            | NULL       | NULL | NULL          | NULL | NULL    | NULL | NULL | Impossible WHERE noticed after reading const tables | 
|  2 | DEPENDENT SUBQUERY | NULL       | NULL | NULL          | NULL | NULL    | NULL | NULL | No tables used                                      | 
|  3 | DEPENDENT UNION    | NULL       | NULL | NULL          | NULL | NULL    | NULL | NULL | Impossible WHERE                                    | 
| NULL | UNION RESULT       | <union2,3> | ALL  | NULL          | NULL | NULL    | NULL | NULL |                                                     | 
+----+--------------------+------------+------+---------------+------+---------+------+------+-----------------------------------------------------+
4 rows in set (0.00 sec)

mysql> notee
