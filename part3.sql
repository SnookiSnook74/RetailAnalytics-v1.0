-- Создание роли "Администратор"
CREATE ROLE admin WITH LOGIN PASSWORD '8800';
-- Выдача полных прав на все таблицы в базе данных 
GRANT ALL PRIVILEGES ON DATABASE "postgres" TO admin;
GRANT ALL PRIVILEGES ON SCHEMA public TO admin;
ALTER ROLE admin CREATEDB CREATEROLE;

-- Создание роли "Посетитель"
CREATE ROLE visitor WITH LOGIN PASSWORD '8800';
-- Выдача прав на чтение для всех таблиц в схеме "public" 
GRANT USAGE, SELECT ON ALL SEQUENCES IN SCHEMA public TO visitor;
GRANT SELECT ON ALL TABLES IN SCHEMA public TO visitor;
-- Чтобы автоматически давать права на чтение для всех будущих таблиц
ALTER DEFAULT PRIVILEGES IN SCHEMA public GRANT USAGE, SELECT ON SEQUENCES TO visitor;
ALTER DEFAULT PRIVILEGES IN SCHEMA public GRANT SELECT ON TABLES TO visitor;

-- TEST -- 
-- Не даст сделать от пользователя visitor , но даст сделать от имени admin, для
-- подключения использовать -psql -U имя пользователя(amdin или visior) -d "имя базы"  
CREATE TABLE test_table (id INT PRIMARY KEY, name TEXT);