SET datestyle = 'ISO, DMY';
-- \COPY personaldetails FROM '../datasets/Personal_Data.tsv' WITH CSV DELIMITER E'\t';
-- \COPY customercards FROM '../datasets/Cards.tsv' WITH CSV DELIMITER E'\t';
-- \COPY transactions FROM '../datasets/Transactions.tsv' WITH CSV DELIMITER E'\t';
-- \COPY sku_groups FROM '../datasets/Groups_SKU.tsv' WITH CSV DELIMITER E'\t';
-- \COPY productmatrix FROM '../datasets/SKU.tsv' WITH CSV DELIMITER E'\t';
-- \COPY checks FROM '../datasets/Checks.tsv' WITH CSV DELIMITER E'\t';
-- \COPY retailstores FROM '../datasets/Stores.tsv' WITH CSV DELIMITER E'\t';
-- \COPY analysisformation FROM '../datasets/Date_Of_Analysis_Formation.tsv' WITH CSV DELIMITER E'\t';

----------------------------------------------- 
--               MINI BASE                   --
----------------------------------------------- 
\COPY personaldetails FROM '../datasets/Personal_Data_Mini.tsv' WITH CSV DELIMITER E'\t';
\COPY customercards FROM '../datasets/Cards_Mini.tsv' WITH CSV DELIMITER E'\t';
\COPY transactions FROM '../datasets/Transactions_Mini.tsv' WITH CSV DELIMITER E'\t';
\COPY sku_groups FROM '../datasets/Groups_SKU_Mini.tsv' WITH CSV DELIMITER E'\t';
\COPY productmatrix FROM '../datasets/SKU_Mini.tsv' WITH CSV DELIMITER E'\t';
\COPY checks FROM '../datasets/Checks_Mini.tsv' WITH CSV DELIMITER E'\t';
\COPY retailstores FROM '../datasets/Stores_Mini.tsv' WITH CSV DELIMITER E'\t';
\COPY analysisformation FROM '../datasets/Date_Of_Analysis_Formation.tsv' WITH CSV DELIMITER E'\t';