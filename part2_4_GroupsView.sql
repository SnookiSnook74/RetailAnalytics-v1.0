/*
Представление Группы
Поле	                    Название поля в системе	    Формат / возможные значения	        Описание
Идентификатор клиента	    Customer_ID	                ---	                                ---
Идентификатор группы	    Group_ID	                ---	                                ---
Индекс востребованности	    Group_Affinity_Index	    Арабская цифра, десятичная дробь	Коэффициент востребованности данной группы клиентом
Индекс оттока	            Group_Churn_Rate	        Арабская цифра, десятичная дробь	Индекс оттока клиента по конкретной группе
Индекс стабильности	        Group_Stability_Index	    Арабская цифра, десятичная дробь	Показатель, демонстрирующий стабильность потребления группы клиентом
Актуальная маржа по группе	Group_Margin	            Арабская цифра, десятичная дробь	Показатель актуальной маржи по группе для конкретного клиента
Доля транзакций со скидкой	Group_Discount_Share	    Арабская цифра, десятичная дробь	Доля транзакций по покупке группы клиентом, в рамках которых были применена скидка (без учета списания бонусов программы лояльности)
Минимальный размер скидки	Group_Minimum_Discount	    Арабская цифра, десятичная дробь	Минимальный размер скидки, зафиксированный для клиента по группе
Средний размер скидки	    Group_Average_Discount	    Арабская цифра, десятичная дробь	Средний размер скидки по группе для клиента
*/
/*
	Расчет фактической маржи по группе для клиента

	Выбор метода расчета маржи. 
	По умолчанию маржа рассчитывается
	для всех транзакций в рамках анализируемого периода (используются
	все доступные данные). Но пользователь должен иметь возможность
	внести индивидуальные настройки и выбрать метод расчета актуальной
	маржи – по периоду или по количеству транзакций.

		В случае выбора метода расчета маржи по периоду пользователь
		указывает, за какое количество дней от даты формирования анализа в обратном
		хронологическом порядке необходимо рассчитать маржу. 
		Для расчета берутся все транзакции, в которых присутствует
		анализируемая группа, совершенные пользователем в указанный
		период. Для подсчетов используются данные, содержащиеся в поле
		Transaction_DateTime таблицы История покупок.

		В случае выбора метода расчета маржи по количеству транзакций
		пользователь указывает количество транзакций, для которых
		необходимо рассчитать маржу. Маржа считается по заданному
		количеству транзакций, начиная с последней, в обратном
		хронологическом порядке. Для подсчетов используются данные,
		содержащиеся в поле Transaction_DateTime таблицы История
		покупок`.

	Расчет фактической маржи по группе. Для определения фактической
	маржи группы по клиенту в рамках анализируемого или заданного
	пользователем периода из суммы, на которую был куплен товар (поле
	Group_Summ_Paid таблицы История покупок) вычитается
	себестоимость приобретенного товара (значение поля Group_Cost
	таблицы История покупок). Итоговое значение сохраняется в качестве
	фактической маржи по данной группе для клиента в поле Group_Margin
	таблицы Группы.
*/
CREATE OR REPLACE FUNCTION fnc_count_margin(Cust_ID bigint, Gr_ID bigint,count_type integer DEFAULT 1, param integer DEFAULT NULL) RETURNS numeric AS
$$
DECLARE
	limit_date TIMESTAMP;
	BEGIN
		IF count_type = 1 THEN
			IF param IS NULL THEN
				param := 1e+6;
			END IF;
			limit_date := CURRENT_TIMESTAMP - param * INTERVAL '1 day';
			-- limit_date := '2022.08.21 12:14:59'::TIMESTAMP - param * INTERVAL '1 day';
			RETURN (
			SELECT
				SUM(Group_Summ_Paid-group_cost)::NUMERIC AS Group_Margin
			FROM purchase_history
			WHERE purchase_history.Customer_ID = Cust_ID
			AND purchase_history.Group_ID = Gr_ID
			AND Transaction_DateTime > limit_date
			GROUP BY 
					customer_id, 
					group_id
				   );
		
		ELSIF count_type = 2 THEN
			IF param IS NULL THEN
				param := (SELECT COUNT(Transaction_ID)FROM purchase_history) ;
			END IF;
			RETURN (
			SELECT
				SUM(Group_Summ_Paid-group_cost)::NUMERIC AS Group_Margin
			FROM (SELECT * 
				  FROM 
				  	purchase_history
				  WHERE purchase_history.Customer_ID = Cust_ID
				  AND purchase_history.Group_ID = Gr_ID
				  ORDER BY Transaction_DateTime DESC
				  LIMIT param) AS list);
		END IF;
	END;
$$ LANGUAGE plpgsql;

-- DROP VIEW IF EXISTS GroupsView;
CREATE VIEW GroupsView AS
/*
	Определение востребованных групп SKU для каждого клиента
	
	Формирование списка SKU для клиента. 
	Для каждого клиента (для всех карт клиента) формируется список всех SKU, которые покупал
	клиент в течение анализируемого периода. Для этого используются
	данные, содержащиеся в поле SKU_ID таблицы Чеки. Для
	идентификации всех транзакций клиента используются данные,
	содержащиеся в полях Transaction_ID таблиц Чеки и Транзакции, 
	Customer_Card_ID таблиц Транзакции и Карты, Customer_ID таблицы Персональные данные.

	Дедубликация списка SKU. После формирования из списка SKU
	каждого клиента удаляются дубликаты таким образом, чтобы в
	результате для каждого клиента был сформирован перечень уникальных
	SKU, которые он приобретал в течение анализируемого периода.

	Определение списка востребованных групп для клиента. Для каждого
	клиента по каждому уникальному SKU на основании данных из товарной
	матрицы указывается группа, к которой относится данный SKU. Для
	этого используются данные, содержащиеся в полях SKU_ID и
	Group_ID таблицы Товарная матрица.

	Дедубликация списка групп. После формирования из списка групп,
	востребованных клиентом, удаляются дубликаты таким образом, чтобы в
	результате для каждого клиента был сформирован перечень уникальных
	групп, которые он приобретал в течение анализируемого периода.
	Итоговый результат сохраняется в поле Group_ID таблиц Периоды и Группы. В таблицах должны содержаться
	уникальные значения, сформированные из пары Идентификатор клиента
	(Customer_ID) – Идентификатор группы (Group_ID).
*/
WITH Groups_list_for_every_customer AS (
	SELECT
		Customer_ID,
		Group_ID
	FROM 
		Transactions
	JOIN
		CustomerCards ON CustomerCards.Customer_Card_ID = Transactions.Customer_Card_ID
	JOIN
		Checks ON Checks.Transaction_ID = Transactions.Transaction_ID
	JOIN
		ProductMatrix ON ProductMatrix.SKU_ID = Checks.SKU_ID
	GROUP BY 
		Customer_ID, Group_ID/*Дедубликация путем группировки*/
	ORDER BY 
		Customer_ID, Group_ID
),
/*
	Расчет востребованности

	Определение общего количества транзакций клиента. Определяется
	общее количество транзакций клиента, совершенных им между первой и
	последней транзакциями с анализируемой группой (включая транзакции,
	в рамках которых не было анализируемой группы), включая первую и
	последнюю транзакции с группой. 
	
	Для этого подсчитывается количество уникальных значений в поле Transaction_ID таблицы История покупок, 
	дата совершения транзакций для которых больше или равна дате первой транзакции клиента с группой (значение поля
	First_Group_Purchase_Date таблицы Периоды) и меньше или
	равна дате последней транзакции клиента с группой (значение поля
	Last_Group_Purchase_Date таблицы Периоды).
	
	Расчет индекса востребованности группы. Количество транзакций с
	анализируемой группой (значение поля Group_Purchase таблицы Периоды) делится на общее количество транзакций клиента,
	совершенных с первой по последнюю транзакции, в которых была
	анализируемая группа. Итоговое значение
	сохраняется для группы в поле Group_Affinity_Index таблицы Группы.
*/
Calculation_of_demand AS (
	SELECT
		Groups_list_for_every_customer.Customer_ID,
		Groups_list_for_every_customer.Group_ID,
		(Group_Purchase * 1.0/COUNT(purchase_history.Transaction_ID)) AS Group_Affinity_Index
	FROM
		Groups_list_for_every_customer
	JOIN
		purchase_history ON Groups_list_for_every_customer.Customer_ID = purchase_history.Customer_ID
	JOIN
		periods ON Groups_list_for_every_customer.Customer_ID = periods.Customer_ID
		AND periods.Group_ID = Groups_list_for_every_customer.Group_ID
	WHERE
		transaction_datetime BETWEEN periods.First_Group_Purchase_Date AND periods.Last_Group_Purchase_Date
	GROUP BY
		Groups_list_for_every_customer.Customer_ID, Groups_list_for_every_customer.Group_ID, Group_Purchase
		
),
/*
	Расчет индекса оттока из группы

	Подсчет давности приобретения группы. 
	Из даты формирования анализа вычитается	дата последней транзакции клиента, 
	в которой была представлена	анализируемая группа. Для определения последней даты покупки группы
	клиентом выбирается максимальное значение по полю Transaction_DateTime
	таблицы История покупок для записей, в которых значения полей
	Customer_ID и Group_ID соответствуют значениям аналогичных полей
	таблицы Группы.

	Расчет коэффициента оттока. 
	Количество дней, прошедших после
	даты последней транзакции клиента с анализируемой группой, делится на среднее количество дней между покупками
	анализируемой группы клиентом (значение поля Group_Frequency
	таблицы Периоды). Итоговое значение сохраняется в поле
	Group_Churn_Rate таблицы Группы.
*/
Count_Churn_Index AS (
	SELECT
		Calculation_of_demand.Customer_ID,
		Calculation_of_demand.Group_ID,
		Group_Affinity_Index,
		-- EXTRACT(EPOCH FROM ('2022.08.21 12:14:59'::TIMESTAMP - MAX(purchase_history.Transaction_DateTime)))/periods.Group_Frequency / 86400.0 AS Group_Churn_Rate
		EXTRACT(EPOCH FROM (CURRENT_TIMESTAMP - MAX(purchase_history.Transaction_DateTime)))/periods.Group_Frequency / 86400.0 AS Group_Churn_Rate
	FROM
		Calculation_of_demand
	JOIN
		purchase_history ON purchase_history.Customer_ID = Calculation_of_demand.Customer_ID 
		AND purchase_history.Group_ID = Calculation_of_demand.Group_ID
	JOIN
		periods ON periods.Customer_ID = Calculation_of_demand.Customer_ID 
		AND periods.Group_ID = Calculation_of_demand.Group_ID
	GROUP BY
		Calculation_of_demand.Customer_ID, Calculation_of_demand.Group_ID, Group_Affinity_Index, Group_Frequency
),
/*
	Расчет стабильности потребления группы

	Расчет интервалов потребления группы. Определяются все интервалы
	(в количестве дней) между транзакциями клиента, содержащими
	анализируемую группу. Для этого все транзакции, содержащие
	анализируемую группу в покупках клиента, ранжируются по дате
	совершения (значению поля Transaction_DateTime таблицы История покупок) от самой ранней к самой поздней. Из даты каждой
	последующей транзакции вычитается дата предыдущей. Каждый интервал
	учитывается отдельно.
*/
Count_Group_Consumption_Stability_1 AS (
	SELECT 
		Count_Churn_Index.Customer_ID,
		Count_Churn_Index.Group_ID,
		Group_Affinity_Index,
		Group_Churn_Rate,
		EXTRACT(EPOCH FROM (Transaction_DateTime - LAG(Transaction_DateTime) OVER (PARTITION BY 
																				   	Count_Churn_Index.Customer_ID,
																				  	Count_Churn_Index.Group_ID	
																				   	ORDER BY 
																				   	Transaction_DateTime ASC))) / 86400.0 AS result_
	FROM 
		Count_Churn_Index
	JOIN
		purchase_history ON purchase_history.Customer_ID = Count_Churn_Index.Customer_ID 
		AND purchase_history.Group_ID = Count_Churn_Index.Group_ID
	ORDER BY
		Count_Churn_Index.Customer_ID, Count_Churn_Index.Group_ID, Transaction_DateTime
),
/*
	Подсчет абсолютного отклонения каждого интервала от средней
	частоты покупок группы. Из значения каждого интервала вычитается
	среднее количество дней между транзакциями с анализируемой группой
	(значение поля Group_Frequency таблицы Периоды). В случае,
	если получившееся значение является отрицательным, оно умножается на
	-1.
*/
Count_Group_Consumption_Stability_2 AS (
	SELECT 
		Count_Group_Consumption_Stability_1.Customer_ID,
		Count_Group_Consumption_Stability_1.Group_ID,
		Group_Affinity_Index,
		Group_Churn_Rate,
		ABS(result_ - periods.Group_Frequency) AS result_
	FROM 
		Count_Group_Consumption_Stability_1
	JOIN
		periods ON periods.Customer_ID = Count_Group_Consumption_Stability_1.Customer_ID 
		AND periods.Group_ID = Count_Group_Consumption_Stability_1.Group_ID
	ORDER BY
		Customer_ID, Group_ID
),
/*
	Подсчет относительного отклонения каждого интервала от средней
	частоты покупок группы. Получившееся на предыдущем шаге значение для
	каждого интервала делится на среднее количество дней между
	транзакциями с анализируемой группой (значение поля
	Group_Frequency таблицы Периоды).
*/
Count_Group_Consumption_Stability_3 AS (
	SELECT 
		Count_Group_Consumption_Stability_2.Customer_ID,
		Count_Group_Consumption_Stability_2.Group_ID,
		Group_Affinity_Index,
		Group_Churn_Rate,
		result_ / Group_Frequency  AS result_
	FROM 
		Count_Group_Consumption_Stability_2
	JOIN
		periods ON periods.Customer_ID = Count_Group_Consumption_Stability_2.Customer_ID 
		AND periods.Group_ID = Count_Group_Consumption_Stability_2.Group_ID
	ORDER BY
		Customer_ID, Group_ID
),
/*
	Определение стабильности потребления группы. Показатель
	стабильности потребления группы определяется как среднее значение
	всех показателей, получившихся на предыдущем шаге. Результат сохраняется в
	поле Group_Stability_Index таблицы Группы.
*/

Count_Group_Consumption_Stability_4 AS (
	SELECT 
		Customer_ID,
		Group_ID,
		Group_Affinity_Index,
		Group_Churn_Rate,
		AVG(result_) AS Group_Stability_Index
	FROM 
		Count_Group_Consumption_Stability_3
	GROUP BY
		Customer_ID,
		Group_ID,
		Group_Affinity_Index,
		Group_Churn_Rate
	ORDER BY
		Customer_ID, 
		Group_ID
),
/*
	Расчет фактической маржи по группе для клиента

	Выбор метода расчета маржи. 
	По умолчанию маржа рассчитывается
	для всех транзакций в рамках анализируемого периода (используются
	все доступные данные). Но пользователь должен иметь возможность
	внести индивидуальные настройки и выбрать метод расчета актуальной
	маржи – по периоду или по количеству транзакций.

		В случае выбора метода расчета маржи по периоду пользователь
		указывает, за какое количество дней от даты формирования анализа в обратном
		хронологическом порядке необходимо рассчитать маржу. Для
		расчета берутся все транзакции, в которых присутствует
		анализируемая группа, совершенные пользователем в указанный
		период. Для подсчетов используются данные, содержащиеся в поле
		Transaction_DateTime таблицы История покупок.

		В случае выбора метода расчета маржи по количеству транзакций
		пользователь указывает количество транзакций, для которых
		необходимо рассчитать маржу. Маржа считается по заданному
		количеству транзакций, начиная с последней, в обратном
		хронологическом порядке. Для подсчетов используются данные,
		содержащиеся в поле Transaction_DateTime таблицы История
		покупок`.

	Расчет фактической маржи по группе. Для определения фактической
	маржи группы по клиенту в рамках анализируемого или заданного
	пользователем периода из суммы, на которую был куплен товар (поле
	Group_Summ_Paid таблицы История покупок) вычитается
	себестоимость приобретенного товара (значение поля Group_Cost
	таблицы История покупок). Итоговое значение сохраняется в качестве
	фактической маржи по данной группе для клиента в поле Group_Margin
	таблицы Группы.
*/


count_margin AS (
	SELECT 
		Customer_ID,
		Group_ID,
		Group_Affinity_Index,
		Group_Churn_Rate,
		Group_Stability_Index,
		fnc_count_margin(Customer_ID,Group_ID) AS Group_Margin
	FROM 
		Count_Group_Consumption_Stability_4
	GROUP BY
		Customer_ID,
		Group_ID,
		Group_Affinity_Index,
		Group_Churn_Rate,
		Group_Stability_Index
	ORDER BY
		Customer_ID, 
		Group_ID
),

/*
	Анализ предоставления скидок по группе

	Определение количества транзакций клиента со скидкой. 
	Определяется количество транзакций, в рамках которых анализируемая 
	группа была приобретена клиентом с применением какой-либо скидки. 
	Для подсчета используются уникальные значения по полю Transaction_ID таблицы Чеки для транзакций, 
	в рамках которых клиент приобретал анализируемую группу, при этом значение поля SKU_Discount таблицы Чеки больше нуля. 
	Скидка, представленная в рамках списания бонусных баллов, не учитывается.
*/
count_transactions_with_discount AS (
	SELECT 
		count_margin.Customer_ID,
		count_margin.Group_ID,
		Group_Affinity_Index,
		Group_Churn_Rate,
		Group_Stability_Index,
		Group_Margin,
		COUNT(Checks.Transaction_ID) FILTER(WHERE SKU_Discount > 0) AS transactions_with_discount
	FROM 
		count_margin
	JOIN
		CustomerCards ON CustomerCards.Customer_ID = count_margin.Customer_ID
	JOIN
		Transactions ON Transactions.Customer_Card_ID = CustomerCards.Customer_Card_ID
	JOIN
		Checks ON Checks.Transaction_ID = Transactions.Transaction_ID
	JOIN
		ProductMatrix ON ProductMatrix.Group_ID = count_margin.Group_ID
		AND ProductMatrix.SKU_ID = Checks.SKU_ID
	GROUP BY
		count_margin.Customer_ID,
		count_margin.Group_ID,
		Group_Affinity_Index,
		Group_Churn_Rate,
		Group_Stability_Index,
		Group_Margin
	ORDER BY
		Customer_ID, 
		Group_ID
),

/*
	Определение доли транзакций со скидкой. 
	Количество транзакций, в рамках которых приобретение товаров из 
	анализируемой группы было совершено со скидкой делится на общее 
	количество транзакций клиента с анализируемой группой за анализируемый 
	период (данные поля Group_Purchase таблицы Периоды для анализируемой группы по клиенту). 
	Получившееся значения сохраняется в качестве доли транзакций по покупке 
	анализируемой группы со скидкой в поле Group_Discount_Share таблицы Группы.
*/
Group_Discount_Share AS (
	SELECT 
		count_transactions_with_discount.Customer_ID,
		count_transactions_with_discount.Group_ID,
		Group_Affinity_Index,
		Group_Churn_Rate,
		Group_Stability_Index,
		Group_Margin,
		transactions_with_discount * 1.0/ Group_Purchase AS Group_Discount_Share
	FROM 
		count_transactions_with_discount
	JOIN
		periods ON count_transactions_with_discount.Customer_ID = periods.Customer_ID 
		AND count_transactions_with_discount.Group_ID = periods.Group_ID
	GROUP BY
		count_transactions_with_discount.Customer_ID,
		count_transactions_with_discount.Group_ID,
		Group_Affinity_Index,
		Group_Churn_Rate,
		Group_Stability_Index,
		Group_Margin,
		Group_Discount_Share
	ORDER BY
		Customer_ID, 
		Group_ID
),

/*
	Определение минимального размера скидки по группе. 
	Определяется минимальный размер скидки по каждой группе для каждого клиента. 
	Для этого выбирается минимальное не равное нулю значение поля Group_Min_Discount 
	таблицы Периоды для заданных клиента и группы. Результат сохраняется в поле Group_Minimum_Discount таблицы Группы.
*/
Group_Minimum_Discount AS (
	SELECT 
		Group_Discount_Share.Customer_ID,
		Group_Discount_Share.Group_ID,
		Group_Affinity_Index,
		Group_Churn_Rate,
		Group_Stability_Index,
		Group_Margin,
		Group_Discount_Share,
		MIN(Group_Min_Discount) FILTER (WHERE group_min_discount > 0) AS Group_Minimum_Discount
	FROM 
		Group_Discount_Share
	JOIN
		periods ON Group_Discount_Share.Customer_ID = periods.Customer_ID 
		AND Group_Discount_Share.Group_ID = periods.Group_ID
	GROUP BY
		Group_Discount_Share.Customer_ID,
		Group_Discount_Share.Group_ID,
		Group_Affinity_Index,
		Group_Churn_Rate,
		Group_Stability_Index,
		Group_Margin,
		Group_Discount_Share
	ORDER BY
		Customer_ID, 
		Group_ID
),
/*
	Определение среднего размера скидки по группе. 
	Для определения среднего размера скидки по группе для клиента 
	фактически оплаченная сумма по покупке группы в рамках всех транзакций 
	(значение поля Group_Summ_Paid таблицы История покупок для всех транзакций) 
	делится на сумму розничной стоимости данной группы в рамках всех транзакций 
	(сумма по группе по значению поля Group_Summ таблицы История покупок). 
	В расчете участвуют только транзакции, в которых была предоставлена скидка. 
	Результат сохраняется в поле Group_Average_Discount таблицы Группы.
*/
Group_avg_Discount AS (
	SELECT 
		Group_Minimum_Discount.Customer_ID,
		Group_Minimum_Discount.Group_ID,
		Group_Affinity_Index,
		Group_Churn_Rate,
		Group_Stability_Index,
		fnc_count_margin(Group_Minimum_Discount.Customer_ID,Group_Minimum_Discount.Group_ID) AS Group_Margin,/*Задать тип рассчета маржинальности*/
		Group_Discount_Share,
		Group_Minimum_Discount,
		SUM(Group_Summ_Paid)/SUM(Group_Summ) AS Group_Average_Discount
	FROM 
		Group_Minimum_Discount
	JOIN
		purchase_history ON purchase_history.Customer_ID = Group_Minimum_Discount.Customer_ID
		AND purchase_history.Group_ID = Group_Minimum_Discount.Group_ID
		AND Group_Summ_Paid != Group_Summ
	GROUP BY
		Group_Minimum_Discount.Customer_ID,
		Group_Minimum_Discount.Group_ID,
		Group_Affinity_Index,
		Group_Churn_Rate,
		Group_Stability_Index,
		Group_Margin,
		Group_Discount_Share,
		Group_Minimum_Discount
	ORDER BY
		Customer_ID, 
		Group_ID
) SELECT * FROM Group_avg_Discount;
-- SELECT * FROM GroupsView