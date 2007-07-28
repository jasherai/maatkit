explain
select * from (
   select foo from(
      select 1 as foo from sakila.actor as actor_1
      union
      select 1 from sakila.actor as actor_2
   ) as der_1
   join (
      select 1 as foo from sakila.actor as actor_3
   ) as der_2 using(foo)
) as der_3;
+----+--------------+------------+--------+---------------+---------+---------+------+------+-------------+
| id | select_type  | table      | type   | possible_keys | key     | key_len | ref  | rows | Extra       |
+----+--------------+------------+--------+---------------+---------+---------+------+------+-------------+
|  1 | PRIMARY      | <derived2> | ALL    | NULL          | NULL    | NULL    | NULL |  200 |             | 
|  2 | DERIVED      | <derived3> | system | NULL          | NULL    | NULL    | NULL |    1 |             | 
|  2 | DERIVED      | <derived5> | ALL    | NULL          | NULL    | NULL    | NULL |  200 | Using where | 
|  5 | DERIVED      | actor_3    | index  | NULL          | PRIMARY | 2       | NULL |  200 | Using index | 
|  3 | DERIVED      | actor_1    | index  | NULL          | PRIMARY | 2       | NULL |  200 | Using index | 
|  4 | UNION        | actor_2    | index  | NULL          | PRIMARY | 2       | NULL |  200 | Using index | 
|    | UNION RESULT | <union3,4> | ALL    | NULL          | NULL    | NULL    | NULL | NULL |             | 
+----+--------------+------------+--------+---------------+---------+---------+------+------+-------------+
