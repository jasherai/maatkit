explain
select
   (select count(*) from sakila.actor as sub_1 where sub_1.actor_id = der_3.foo)
from (
   select (select count(*) from sakila.actor as sub_2 where sub_2.actor_id = der_2.foo) as foo
   from(
      select 1 as foo from sakila.actor as actor_1
      union
      select (select count(*) from sakila.actor as sub_3 where sub_3.actor_id = actor_2.actor_id)
      from sakila.actor as actor_2
   ) as der_1
   join (
      select 1 as foo from sakila.actor as actor_3)
   as der_2 using(foo)
) as der_3;
+----+--------------------+------------+--------+---------------+---------+---------+-------------------------+------+--------------------------+
| id | select_type        | table      | type   | possible_keys | key     | key_len | ref                     | rows | Extra                    |
+----+--------------------+------------+--------+---------------+---------+---------+-------------------------+------+--------------------------+
|  1 | PRIMARY            | <derived3> | ALL    | NULL          | NULL    | NULL    | NULL                    |  200 |                          | 
|  3 | DERIVED            | <derived5> | system | NULL          | NULL    | NULL    | NULL                    |    1 |                          | 
|  3 | DERIVED            | <derived8> | ALL    | NULL          | NULL    | NULL    | NULL                    |  200 | Using where              | 
|  8 | DERIVED            | actor_3    | index  | NULL          | PRIMARY | 2       | NULL                    |  200 | Using index              | 
|  5 | DERIVED            | actor_1    | index  | NULL          | PRIMARY | 2       | NULL                    |  200 | Using index              | 
|  6 | UNION              | actor_2    | index  | NULL          | PRIMARY | 2       | NULL                    |  200 | Using index              | 
|  7 | DEPENDENT SUBQUERY | sub_3      | eq_ref | PRIMARY       | PRIMARY | 2       | sakila.actor_2.actor_id |    1 | Using index              | 
|    | UNION RESULT       | <union5,6> | ALL    | NULL          | NULL    | NULL    | NULL                    | NULL |                          | 
|  4 | DEPENDENT SUBQUERY | sub_2      | eq_ref | PRIMARY       | PRIMARY | 2       | der_2.foo               |    1 | Using where; Using index | 
|  2 | DEPENDENT SUBQUERY | sub_1      | eq_ref | PRIMARY       | PRIMARY | 2       | der_3.foo               |    1 | Using where; Using index | 
+----+--------------------+------------+--------+---------------+---------+---------+-------------------------+------+--------------------------+
