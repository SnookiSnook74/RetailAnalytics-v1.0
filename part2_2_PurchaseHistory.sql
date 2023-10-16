CREATE OR REPLACE VIEW Purchase_history AS 
WITH UniqueCustomerTransactions AS (
SELECT personaldetails.customer_id,
       transactions.transaction_id,
	   transactions.transaction_datetime,
	   transactions.transaction_store_id,
	   checks.sku_id,
	   productmatrix.group_id,
	   retailstores.sku_purchase_price,
	   checks.sku_amount,
	   checks.sku_summ,
	   checks.sku_summ_paid
	   
FROM personaldetails
JOIN customercards ON customercards.customer_id = personaldetails.customer_id
JOIN transactions ON customercards.customer_card_id = transactions.customer_card_id
JOIN checks ON 	transactions.transaction_id = checks.transaction_id
JOIN productmatrix ON productmatrix.sku_id = checks.sku_id
JOIN retailstores ON retailstores.sku_id = checks.sku_id
	              AND retailstores.transaction_store_id = transactions.transaction_store_id
)

SELECT customer_id,
       transaction_id,
	   transaction_datetime,
	   group_id,
	   SUM (sku_purchase_price * SKU_Amount)  AS Group_Cost,
	   SUM(sku_summ) AS Group_Summ,
       SUM(sku_summ_paid) AS Group_Summ_Paid	   
FROM UniqueCustomerTransactions
GROUP BY 
       customer_id,
       transaction_id,
	   transaction_datetime,
	   group_id;

-- TEST -- 
-- SELECT *
-- FROM purchase_history
-- WHERE group_id = 1

-- SELECT *
-- FROM purchase_history
-- WHERE group_cost > 1000