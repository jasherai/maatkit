explain select 1
from (
   select film_id from sakila.film limit 1
) as der_1
join (
   -- The goal is to make sure this middle derived table's rows can be
   -- distinguished from the one preceding and following it, so I'm going to
   -- make it nasty complicated.
   select film_id, actor_id, (select count(*) from sakila.rental) as r
   from sakila.film_actor limit 1
   union all
   select 1, 1, 1 from sakila.film_actor as dummy
) as der_2 using (film_id)
join (
   select actor_id from sakila.actor limit 1
) as der_3 using (actor_id);

+----+--------------+------------+--------+---------------+--------------------+---------+------+-------+-------------+
| id | select_type  | table      | type   | possible_keys | key                | key_len | ref  | rows  | Extra       |
+----+--------------+------------+--------+---------------+--------------------+---------+------+-------+-------------+
|  1 | PRIMARY      | <derived2> | system | NULL          | NULL               | NULL    | NULL |     1 |             | 
|  1 | PRIMARY      | <derived6> | system | NULL          | NULL               | NULL    | NULL |     1 |             | 
|  1 | PRIMARY      | <derived3> | ALL    | NULL          | NULL               | NULL    | NULL |  5463 | Using where | 
|  6 | DERIVED      | actor      | index  | NULL          | PRIMARY            | 2       | NULL |   200 | Using index | 
|  3 | DERIVED      | film_actor | index  | NULL          | idx_fk_film_id     | 2       | NULL |  5143 | Using index | 
|  4 | SUBQUERY     | rental     | index  | NULL          | idx_fk_staff_id    | 1       | NULL | 16298 | Using index | 
|  5 | UNION        | dummy      | index  | NULL          | idx_fk_film_id     | 2       | NULL |  5143 | Using index | 
| NULL | UNION RESULT | <union3,5> | ALL    | NULL          | NULL               | NULL    | NULL |  NULL |             | 
|  2 | DERIVED      | film       | index  | NULL          | idx_fk_language_id | 1       | NULL |   951 | Using index | 
+----+--------------+------------+--------+---------------+--------------------+---------+------+-------+-------------+
