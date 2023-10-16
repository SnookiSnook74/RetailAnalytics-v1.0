/*
Представление Периоды
Поле									Название поля в системе			Формат / возможные значения			Описание
Идентификатор клиента					Customer_ID						---									---
Идентификатор группы SKU				Group_ID						---									Идентификатор группы родственных товаров, к которой относится товар (например, одинаковые йогурты одного производителя и объема, но разных вкусов). Указывается один идентификатор для всех товаров в группе
Дата первой покупки группы				First_Group_Purchase_Date		гггг-мм-ддTчч:мм:сс.0000000			---
Дата последней покупки группы			Last_Group_Purchase_Date		гггг-мм-ддTчч:мм:сс.0000000			---
Количество транзакций с группой			Group_Purchase					Арабская цифра, десятичная дробь	---
Интенсивность покупок группы			Group_Frequency					Арабская цифра, десятичная дробь	---
Минимальный размер скидки по группе		Group_Min_Discount				Арабская цифра, десятичная дробь	---

*/
CREATE OR REPLACE VIEW periods AS
/*
	Определение даты первой покупки группы клиентом. 
	Дата первой покупки группы клиентом определяется на основе данных, 
	содержащихся в поле Transaction_DateTime таблицы История покупок. 
	Из всей совокупности записей, в рамках которых идентификаторы клиента и 
	группы равны идентификаторам клиента и группы анализируемой строки таблицы Периоды, 
	выбирается минимальное значение по полю Transaction_DateTime таблицы История покупок. 
	Результат сохраняется в поле First_Group_Purchase_Date таблицы Периоды.
*/
WITH level_1 AS (
	SELECT
		Customer_ID,
		Group_ID,
		MIN(Transaction_DateTime) AS First_Group_Purchase_Date
	FROM
		Purchase_history
	GROUP BY
		Customer_ID,
		Group_ID
		
),
/*
	Определение даты последней покупки группы клиентом. 
	Дата последней покупки группы клиентом определяется на основе данных, 
	содержащихся в поле Transaction_DateTime таблицы История покупок. 
	Из всей совокупности записей, в рамках которых идентификаторы клиента и 
	группы равны идентификаторам клиента и группы анализируемой строки таблицы Периоды, 
	выбирается максимальное значение по полю Transaction_DateTime таблицы История покупок. 
	Результат сохраняется в поле Last_Group_Purchase_Date таблицы Периоды.

*/
level_2 AS (
	SELECT
		level_1.Customer_ID,
		level_1.Group_ID,
		First_Group_Purchase_Date,
		MAX(Transaction_DateTime) AS Last_Group_Purchase_Date
	FROM
		level_1
	JOIN
		Purchase_history ON Purchase_history.Customer_ID = level_1.Customer_ID 
		AND Purchase_history.Group_ID = level_1.Group_ID
	GROUP BY
		level_1.Customer_ID,
		level_1.Group_ID,
		First_Group_Purchase_Date
		
),
/*
	Определение количества транзакций с анализируемой группой. 
	Определяется количество транзакций клиента в рамках анализируемого периода, 
	в которых присутствует анализируемая группа. Для этого используются данные, 
	содержащиеся в полях Customer_ID, Transaction_ID (берутся уникальные значения по полю Transaction_ID) 
	и Group_ID (берется идентификатор анализируемой группы) таблицы История покупок. 
	Значения в полях Customer_ID и Group_ID в таблице История покупок должны соответствовать 
	значениям в аналогичных полях таблицы Периоды. Результат сохраняется в поле Group_Purchase таблицы Периоды.
*/
level_3 AS (
	SELECT
		level_2.Customer_ID,
		level_2.Group_ID,
		First_Group_Purchase_Date,
		Last_Group_Purchase_Date,
		COUNT(Transaction_ID) AS Group_Purchase
	FROM
		level_2
	JOIN
		Purchase_history ON Purchase_history.Customer_ID = level_2.Customer_ID 
		AND Purchase_history.Group_ID = level_2.Group_ID
	GROUP BY
		level_2.Customer_ID,
		level_2.Group_ID,
		First_Group_Purchase_Date,
		Last_Group_Purchase_Date
),

/*
	Определение интенсивности покупок группы. 
	Для определения интенсивности покупок группы из даты последней транзакции 
	с группой (значение поля Last_Group_Purchase_Date таблицы Периоды) 
	вычитается значение поля (значение поля First_Group_Purchase_Date таблицы Периоды), 
	добавляется единица, после чего результат делится на количество транзакций с анализируемой группой 
	(значение поля Group_Purchase таблицы Периоды). 
	Результат сохраняется в поле Group_Frequency таблицы Периоды.
*/

level_4 AS (
	SELECT
		level_3.Customer_ID,
		level_3.Group_ID,
		First_Group_Purchase_Date,
		Last_Group_Purchase_Date,
		Group_Purchase,
		CASE 
        	WHEN COUNT(purchase_history.transaction_id) = 1 THEN 1
        	ELSE (EXTRACT(EPOCH FROM (MAX(transaction_datetime) - MIN(transaction_datetime)))/ 86400.0 + 1) / (COUNT(purchase_history.transaction_id))
    	END AS Group_Frequency
	FROM
		level_3
	JOIN
		Purchase_history ON Purchase_history.Customer_ID = level_3.Customer_ID 
		AND Purchase_history.Group_ID = level_3.Group_ID
	GROUP BY
		level_3.Customer_ID,
		level_3.Group_ID,
		First_Group_Purchase_Date,
		Last_Group_Purchase_Date,
		Group_Purchase	
),

/*
	Подсчет минимальной скидки по группе. 
	Для каждой группы каждой транзакции устанавливается минимальный размер скидки, 
	который был предоставлен в рамках данной транзакции. 
	Для этого предоставленный размер скидки по каждому SKU (значение поля SKU_Discount таблицы Чеки) 
	делится на базовую розничную стоимость данного SKU (значение поля SKU_Summ таблицы Чеки). 
	Результат сохраняется в поле Group_Min_Discount таблицы Периоды. 
	В случае отсутствия скидки по всем SKU группы указывается значение 0.
*/
discount AS (
SELECT 
	PersonalDetails.customer_id,
	group_id,
	sku_discount * 1.0/sku_summ as Group_Discount
FROM 
	PersonalDetails
JOIN
	CustomerCards ON CustomerCards.Customer_ID = PersonalDetails.Customer_ID
JOIN
	Transactions ON Transactions.Customer_Card_ID = CustomerCards.Customer_Card_ID
JOIN
	Checks ON Checks.Transaction_ID = Transactions.Transaction_ID
JOIN
	ProductMatrix ON ProductMatrix.SKU_ID = Checks.SKU_ID
GROUP BY 
	PersonalDetails.customer_id,
	group_id,
	Group_Discount
ORDER BY
	customer_id,
	group_id
),


level_5 AS (
	SELECT
		level_4.Customer_ID,
		level_4.Group_ID,
		First_Group_Purchase_Date,
		Last_Group_Purchase_Date,
		Group_Purchase,
		Group_Frequency,
		CASE
			WHEN max(Group_Discount) = 0 THEN 0
			ELSE (min(Group_Discount) FILTER ( WHERE Group_Discount > 0 ))
		END AS Group_min_Discount
	FROM
		level_4
	JOIN
		discount ON discount.Customer_ID = level_4.Customer_ID
		AND discount.Group_ID = level_4.Group_ID
	GROUP BY
		level_4.Customer_ID,
		level_4.Group_ID,
		First_Group_Purchase_Date,
		Last_Group_Purchase_Date,
		Group_Purchase,
		Group_Frequency
		
)
SELECT *
FROM level_5;

-- TEST --
-- SELECT *
-- FROM periods
-- WHERE group_id = 4

-- SELECT *
-- FROM periods
-- WHERE first_group_purchase_date > '2020-01-01'

-- SELECT *
-- FROM periods
-- WHERE first_group_purchase_date > '2020-01-01'

-- SELECT *
-- FROM periods
-- WHERE group_purchase > 8