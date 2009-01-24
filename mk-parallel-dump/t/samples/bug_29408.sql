drop database if exists mk_parallel_dump_foo;
create database mk_parallel_dump_foo;
use mk_parallel_dump_foo;

delimiter //
CREATE FUNCTION `function1`() RETURNS tinyint(4) deterministic
BEGIN
 return 1;
END
//
delimiter ;

create view v as select function1();
