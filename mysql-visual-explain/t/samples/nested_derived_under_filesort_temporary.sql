explain select outer_der.film_id, count(*)
from (
   select *,
      (select count(*) from sakila.film as mid_sub where mid_sub.film_id = mid_der.film_id)
   from (
      select * from sakila.film as inmost
   ) as mid_der
   order by mid_der.last_update
) as outer_der
group by outer_der.film_id
order by count(*) desc
+----+--------------------+------------+--------+---------------+---------+---------+-----------------+------+---------------------------------+
| id | select_type        | table      | type   | possible_keys | key     | key_len | ref             | rows | Extra                           |
+----+--------------------+------------+--------+---------------+---------+---------+-----------------+------+---------------------------------+
|  1 | PRIMARY            | <derived2> | ALL    | NULL          | NULL    | NULL    | NULL            | 1000 | Using temporary; Using filesort | 
|  2 | DERIVED            | <derived4> | ALL    | NULL          | NULL    | NULL    | NULL            | 1000 | Using filesort                  | 
|  4 | DERIVED            | inmost     | ALL    | NULL          | NULL    | NULL    | NULL            | 1131 |                                 | 
|  3 | DEPENDENT SUBQUERY | mid_sub    | eq_ref | PRIMARY       | PRIMARY | 2       | mid_der.film_id |    1 | Using where; Using index        | 
+----+--------------------+------------+--------+---------------+---------+---------+-----------------+------+---------------------------------+
