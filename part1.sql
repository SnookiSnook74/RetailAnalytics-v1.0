-- Active: 1693889407428@@127.0.0.1@21000@postgres
-----------------------------------------------
-- Для создания БД можно воспользоваться make.
-- Правильная работа скрипта makefile возможна 
-- только с установленным docker.
-- 
-- make new 
-- создание нового контейнера postgres,
-- создание структуры данных,
-- импорт данных из папки datasets full
-- 
-- make list - вывод текущего контейнера sql3 и его volume ID
-- make prune - удаление текущего контейнера sql3 и его volume 
----------------------------------------------- 

-- DROP TABLE IF EXISTS retailstores;
-- DROP TABLE IF EXISTS checks;
-- DROP TABLE IF EXISTS transactions;
-- DROP TABLE IF EXISTS customercards;
-- DROP= TABLE IF EXISTS personaldetails;
-- DROP TABLE IF EXISTS productmatrix;
-- DROP TABLE IF EXISTS sku_groups;
-- DROP TABLE IF EXISTS analysisformation;
SET datestyle = 'ISO, DMY';

CREATE TABLE PersonalDetails (
    Customer_ID SERIAL PRIMARY KEY,
    Customer_Name VARCHAR(100) 
    CHECK (Customer_Name ~* '^([А-ЯA-Z][а-яa-z\- ]+)$'),
    Customer_Surname VARCHAR(100) 
    CHECK (Customer_Surname ~* '^([А-ЯA-Z][а-яa-z\- ]+)$'),
    Customer_Primary_Email VARCHAR(100) UNIQUE 
    CHECK (Customer_Primary_Email ~* '^[A-Za-z0-9._%-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,4}$'),
    Customer_Primary_Phone VARCHAR(15) UNIQUE 
    CHECK (Customer_Primary_Phone ~ '^\+7[0-9]{10}$')
);

CREATE TABLE CustomerCards (
    Customer_Card_ID SERIAL PRIMARY KEY,
    Customer_ID BIGINT,
    CONSTRAINT fk_сustomercards_personaldetails_customer_ID FOREIGN KEY (Customer_ID) REFERENCES PersonalDetails(Customer_ID)
);

CREATE TABLE Transactions (
    Transaction_ID SERIAL PRIMARY KEY,
    Customer_Card_ID BIGINT NOT NULL,
    Transaction_Summ NUMERIC CHECK (Transaction_Summ >= 0),
    Transaction_DateTime TIMESTAMP,
    Transaction_Store_ID INT,
    CONSTRAINT fk_transactions_customercards_customer_card_id FOREIGN KEY (Customer_Card_ID) REFERENCES CustomerCards(Customer_Card_ID)
);

CREATE TABLE SKU_Groups (
    Group_ID SERIAL PRIMARY KEY,
    Group_Name VARCHAR(255) CHECK (Group_Name ~ '^[A-Za-zА-Яа-я0-9\s\-\+\=\@\#\$\%\^\&\*\(\)\[\]\{\}\;\:\,\.\<\>\?\/\|\_\~]+$')
);

CREATE TABLE ProductMatrix (
    SKU_ID SERIAL PRIMARY KEY,
    SKU_Name VARCHAR(255) CHECK (SKU_Name ~ '^[A-Za-zА-Яа-я0-9\s\-\+\=\@\#\$\%\^\&\*\(\)\[\]\{\}\;\:\,\.\<\>\?\/\|\_\~]+$'),
    Group_ID BIGINT,
    CONSTRAINT fk_productmatrix_group_id FOREIGN KEY (Group_ID) REFERENCES SKU_Groups(Group_ID)
);

CREATE TABLE Checks (
    Transaction_ID BIGINT,
    SKU_ID BIGINT NOT NULL,
    SKU_Amount NUMERIC CHECK (SKU_Amount > 0),
    SKU_Summ NUMERIC CHECK (SKU_Summ >= 0),
    SKU_Summ_Paid NUMERIC CHECK (SKU_Summ_Paid >= 0),
    SKU_Discount NUMERIC CHECK (SKU_Discount >= 0),
    CONSTRAINT fk_receipts_transactions_transaction_id FOREIGN KEY (Transaction_ID) REFERENCES Transactions(Transaction_ID),
    CONSTRAINT fk_receipts_productmatrix_sku_id FOREIGN KEY (SKU_ID) REFERENCES ProductMatrix(SKU_ID) 
);

CREATE TABLE RetailStores (
    Transaction_Store_ID BIGINT,
    SKU_ID BIGINT NOT NULL,
    SKU_Purchase_Price NUMERIC CHECK (SKU_Purchase_Price >= 0),
    SKU_Retail_Price NUMERIC CHECK (SKU_Retail_Price >= 0),
    CONSTRAINT fk_retailstores_productmatrix_sku_id FOREIGN KEY (SKU_ID) REFERENCES ProductMatrix(SKU_ID)
);

CREATE TABLE AnalysisFormation (
    Analysis_Formation TIMESTAMP
);

CREATE OR REPLACE PROCEDURE export_data(table_name text, file_path text, delimiter text)
LANGUAGE plpgsql
AS $$
BEGIN
    EXECUTE format('COPY %I TO %L WITH CSV DELIMITER %L', table_name, file_path, delimiter);
END;
$$;

CREATE OR REPLACE PROCEDURE import_data(table_name text, file_path text, delimiter text)
LANGUAGE plpgsql
AS $$
BEGIN
    EXECUTE format('COPY %I FROM %L WITH CSV DELIMITER %L', table_name, file_path, delimiter);
END;
$$;

-- TEST --
-- Проверить стандартная ли папка с данными?
-- SHOW data_directory; 

-- EXPORT --
-- CALL export_data('personaldetails', '/var/lib/postgresql/Personal_Data_Mini.tsv', E'\t');
-- CALL export_data('customercards', '/var/lib/postgresql/Cards_Mini.tsv', E'\t');
-- CALL export_data('transactions', '/var/lib/postgresql/Transactions_Mini.tsv', E'\t');
-- CALL export_data('sku_groups', '/var/lib/postgresql/Groups_SKU_Mini.tsv', E'\t');
-- CALL export_data('productmatrix', '/var/lib/postgresql/SKU_Mini.tsv', E'\t');
-- CALL export_data('checks', '/var/lib/postgresql/Checks_Mini.tsv', E'\t');
-- CALL export_data('retailstores', '/var/lib/postgresql/Stores_Mini.tsv', E'\t');
-- CALL export_data('analysisformation', '/var/lib/postgresql/Date_Of_Analysis_Formation.tsv',E'\t');

-- IMPORT --
-- CALL import_data('personaldetails', '/var/lib/postgresql/Personal_Data_Mini.tsv', E'\t');
-- CALL import_data('customercards', '/var/lib/postgresql/Cards_Mini.tsv', E'\t');
-- CALL import_data('transactions', '/var/lib/postgresql/Transactions_Mini.tsv', E'\t');
-- CALL import_data('sku_groups', '/var/lib/postgresql/Groups_SKU_Mini.tsv', E'\t');
-- CALL import_data('productmatrix', '/var/lib/postgresql/SKU_Mini.tsv', E'\t');
-- CALL import_data('checks', '/var/lib/postgresql/Checks_Mini.tsv', E'\t');
-- CALL import_data('retailstores', '/var/lib/postgresql/Stores_Mini.tsv', E'\t');
-- CALL import_data('analysisformation', '/var/lib/postgresql/Date_Of_Analysis_Formation.tsv',E'\t');