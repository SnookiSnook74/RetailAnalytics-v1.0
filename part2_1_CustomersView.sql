/*
Представление Клиенты

Поле	                                        Название поля в системе	        Формат / возможные значения	        Описание
Идентификатор клиента	                        Customer_ID	                    ---	                                Уникальное значение
Значение среднего чека	                        Customer_Average_Check	        Арабская цифра, десятичная дробь	Значение среднего чека клиента в рублях за анализируемый период
Сегмент по среднему чеку	                    Customer_Average_Check_Segment	Высокий; Средний; Низкий	        Описание сегмента
Значение частоты транзакций	                    Customer_Frequency	            Арабская цифра, десятичная дробь	Значение частоты визитов клиента в среднем количестве дней между транзакциями. Также учитывается время, т.е. результатом может быть не целое число
Сегмент по частоте транзакций	                Customer_Frequency_Segment	    Часто; Средне; Редко	            Описание сегмента
Количество дней после предыдущей транзакции	    Customer_Inactive_Period	    Арабская цифра, десятичная дробь	Количество дней, прошедших с даты предыдущей транзакции клиента. Также учитывается время, т.е. результатом может быть не целое число
Коэффициент оттока	                            Customer_Churn_Rate	            Арабская цифра, десятичная дробь	Значение коэффициента оттока клиента
Сегмент по коэффициенту оттока	                Customer_Churn_Segment	        Высокий; Средний; Низкий	        Описание сегмента
Номер сегмента	                                Customer_Segment	            Арабская цифра	                    Номер сегмента, к которому принадлежит клиент
Идентификатор основного магазина	            Customer_Primary_Store	        ---	                                ---
*/


-- DROP VIEW IF EXISTS CustomersView;
CREATE VIEW CustomersView AS 
/* Некоторые сложные расчеты приходилось делать в несколько этапов (level_1, level_2 ...)*/
WITH level_1 AS (
  SELECT
    PersonalDetails.Customer_ID,
	/*
		Расчет среднего чека. Для каждого клиента определяется величина среднего чека за анализируемый период. 
		Источник данных – таблица Транзакции. 
		Суммируются все транзакции по всем картам каждого клиента по полю Transaction_Summ таблицы Транзакции, 
		после чего полученная сумма делится на количество транзакций. 
		Полученные данные сохраняются в поле Customer_Average_Check таблицы Клиенты.
	*/
    SUM(Transaction_Summ)/COUNT(Transactions.Transaction_ID) AS Customer_Average_Check,
	/*
		Определение сегмента. 10% клиентов с наивысшим показателем среднего чека относятся к сегменту High. 
		Следующие 25% клиентов с наивысшим показателем среднего чека относятся к сегменту Medium. 
		Оставшиеся клиенты с наименьшим показателем среднего чека относятся к сегменту Low. 
		Данные указываются в поле Customer_Average_Check_Segment таблицы Клиенты.
	*/
    NTILE(100) OVER (ORDER BY SUM(Transaction_Summ)/COUNT(Transactions.Transaction_ID) DESC) AS Customer_Average_Check_Segment,
	/*
		Определение интенсивности транзакций. 
		Для каждого клиента определяется его текущая частота визитов в среднем интервале между визитами в днях. 
		Для этого из даты самой поздней на момент формирования анализа транзакции вычитается дата самой ранней за анализируемый период транзакции. 
		Данные берутся из поля Transaction_DateTime таблицы Транзакции. 
		Полученное значение делится на общее количество транзакций клиента за анализируемый период. 
		Количество транзакций клиента определяется как количество уникальных значений в поле Transaction_ID для всех карт клиента. 
		Полученные данные сохраняются в поле Customer_Frequency таблицы Клиенты.
	*/
	EXTRACT(EPOCH FROM ( MAX(Transaction_DateTime) - MIN(Transaction_DateTime)) / 86400.0 )/ COUNT(Transactions.Transaction_ID) AS Customer_Frequency,
	/*
		Определение сегмента. 10% клиентов с наименьшими значениями интервалов между визитами обладают наивысшей 
		частотой визитов и относятся к сегменту Often. Следующие 25% клиентов с наименьшими интервалами между визитами 
		относятся к сегменту Occasionally. Оставшиеся 65% клиентов относятся к сегменту Rarely. 
		Данные указываются в поле Customer_Frequency_Segment таблицы Клиенты
	*/
	NTILE(100) OVER (ORDER BY EXTRACT(EPOCH FROM ( MAX(Transaction_DateTime) - MIN(Transaction_DateTime)) / 86400.0 )/ COUNT(Transactions.Transaction_ID)) AS Customer_Frequency_Segment,
 	/*
		Определение периода после предыдущей транзакции. 
		Для каждого клиента необходимо определить количество дней, прошедших после самой поздней на момент анализа транзакции. 
		Для этого из даты формирования анализа вычитается дата самой поздней транзакции клиента. 
		Данные берутся из поля Transaction_DateTime таблицы Транзакции по всем картам клиента.
	*/
	--EXTRACT(EPOCH FROM CURRENT_TIMESTAMP - MAX(Transaction_DateTime)) / 86400.0  AS Customer_Inactive_Period
	EXTRACT(EPOCH FROM '2022.08.21 12:14:59'::TIMESTAMP - MAX(Transaction_DateTime)) / 86400.0  AS Customer_Inactive_Period
	/*
		Определение основного магазина клиента. 
		Для каждого клиента определяется его основной магазин.
		В случае, если три последние транзакции совершены в одном и том же магазине, 
		в качестве основного магазина клиента устанавливает этот магазин. 
		В ином случае в качестве основного магазина клиента указывается магазин, 
		в котором совершена наибольшая доля всех транзакций клиента. 
		В случае, если для нескольких магазинов указана одинаковая доля транзакций, 
		в качестве основного магазина выбирается тот из них, в которым была совершена самая поздняя транзакция.
		Получившееся значение указывается в поле Customer_Primary_Store таблицы Клиенты.
	*/	
	FROM PersonalDetails
	JOIN CustomerCards ON CustomerCards.Customer_ID = PersonalDetails.Customer_ID
	JOIN Transactions ON Transactions.Customer_Card_ID = CustomerCards.Customer_Card_ID
	GROUP BY PersonalDetails.Customer_ID
),
level_2  AS (
SELECT 
    Customer_ID,
    Customer_Average_Check,
    CASE
      WHEN Customer_Average_Check_Segment <= 0.1 * (SELECT COUNT(*) FROM level_1) THEN 'High'
      WHEN Customer_Average_Check_Segment <= 0.35 * (SELECT COUNT(*) FROM level_1) THEN 'Medium'
      ELSE 'Low'
    END AS Customer_Average_Check_Segment,
	Customer_Frequency,
	CASE
      WHEN Customer_Frequency_Segment <= 0.1 * (SELECT COUNT(*) FROM level_1) THEN 'Often'
      WHEN Customer_Frequency_Segment <= 0.35 * (SELECT COUNT(*) FROM level_1) THEN 'Occasionally'
      ELSE 'Rarely'
    END AS Customer_Frequency_Segment,
	Customer_Inactive_Period,
	/*
		Расчет коэффициента оттока. Для каждого клиента количество дней, прошедших с даты предыдущей транзакции 
		(значение поля Customer_Inactive_Period таблицы Клиенты), 
		делится на интенсивность транзакций клиента в прошлом 
		(значение поля Customer_Frequency таблицы Клиенты). 
		Получившийся результат сохраняется в поле Customer_Churn_Rate таблицы Клиенты.
	*/
	Customer_Inactive_Period / Customer_Frequency AS Customer_Churn_Rate,
	/*
		Определение вероятности оттока. В случае, если полученный коэффициент находится в интервале от 0 до 2, 
		вероятность оттока клиента оценивается как Low. Если коэффициент находится в интервале от 2 до 5, 
		вероятность оттока оценивается как Medium. В случае, если значение превышает 5, 
		присваивается значение High. Получившийся результат сохраняется в поле Customer_Churn_Segment таблицы Клиенты.
	*/
	CASE
      WHEN Customer_Inactive_Period / Customer_Frequency <= 2  THEN 'Low'
      WHEN Customer_Inactive_Period / Customer_Frequency <= 5  THEN 'Medium'
      ELSE 'High'
    END AS Customer_Churn_Segment
	
FROM level_1
ORDER BY Customer_ID),
	/*
		Определение перечня магазинов клиента. 
		Для каждого клиента для всех его карт формируется перечень магазинов, 
		в которых он совершал транзакции в течение анализируемого периода. 
		Одному клиенту могут соответствовать несколько магазинов. 
		Для этого используется данные, содержащиеся в поле Transaction_Store_ID таблицы Транзакции. 
		После формирования список дедублицируется.
		
		Расчет доли транзакций в каждом магазине. 
		Для каждого магазина, в котором клиент совершал покупки, 
		указывается доля транзакций, совершенных в этом магазине. 
		Для этого количество уникальных транзакций в каждом конкретном магазине 
		делится на общее количество уникальных транзакций клиента. 
		Для расчетов используются данные, содержащиеся в поле Transaction_ID и 
		Transaction_Store_ID таблицы Транзакции.
	*/
Customer_Primary_Store_Set AS (
	SELECT
	  Customer_ID,
	  Transaction_Store_ID,
	  ((TransactionCount * 100.0) / TotalTransactionCount) AS TransactionPercentage,
		(SELECT MAX(Transaction_DateTime) 
		 FROM Transactions 
		 JOIN CustomerCards ON CustomerCards.Customer_Card_ID = Transactions.Customer_Card_ID
		 WHERE list.Transaction_Store_ID = Transactions.Transaction_Store_ID
		AND CustomerCards.Customer_ID = list.Customer_ID) AS last_transaction
	FROM (	  
		SELECT
			Customer_ID,
			Transaction_Store_ID,
			COUNT(Transaction_ID) AS TransactionCount,
			SUM(COUNT(Transaction_ID)) OVER (PARTITION BY Customer_ID) AS TotalTransactionCount
		  FROM Transactions
		  JOIN CustomerCards ON CustomerCards.Customer_Card_ID = Transactions.Customer_Card_ID
			GROUP BY Customer_ID, transaction_store_id
		 ) AS list
	ORDER BY Customer_ID, Transaction_Store_ID),
/*
Определение магазина, в котором клиент совершил три предыдущие транзакции. 
Для каждого клиента для всех его карт определяется магазин или магазины, в котором(-ых) 
были совершены три самые поздние транзакции. 
Для этого используются данные, содержащиеся в полях Transaction_Store_ID и Transaction_DateTime.
*/
loyal_customers AS (
	SELECT Customer_ID
	FROM (
		/*получаем последние 3 транзакции для каждого пользователя*/
		SELECT
		  Customer_ID,
		  Transaction_Store_ID
		FROM (
			/*нумеруем транзакции начиная с последней*/
			SELECT
				Customer_ID,
				Transaction_Store_ID,
				Transaction_DateTime,
				ROW_NUMBER() OVER (PARTITION BY Customer_ID ORDER BY Transaction_DateTime DESC) AS rn
		  FROM Transactions
		  JOIN CustomerCards ON CustomerCards.Customer_Card_ID = Transactions.Customer_Card_ID) AS list
	WHERE rn <= 3) list
	GROUP BY Customer_ID
	/*получаем пользователей у которых в последних 3х транзакциях только один магазин*/
	HAVING COUNT(DISTINCT Transaction_Store_ID) = 1
	
)

	SELECT 
		level_2.Customer_ID,
		Customer_Average_Check,
		Customer_Average_Check_Segment,
		Customer_Frequency,
		Customer_Frequency_Segment,
		Customer_Inactive_Period,
		Customer_Churn_Rate,
		Customer_Churn_Segment,
		/*
		Присвоение номера сегмента. На основании комбинации значений клиента в полях 
		Customer_Average_Check_Segment, Customer_Frequency_Segment и Customer_Churn_Segment 
		таблицы Клиенты клиенту присваивается номер сегмента в соответствии со следующей таблицей:
		Сегмент	Средний чек	Частота покупок	Вероятность оттока
			1	Низкий	Редко	Низкая
			2	Низкий	Редко	Средняя
			3	Низкий	Редко	Высокая
			4	Низкий	Средне	Низкая
			5	Низкий	Средне	Средняя
			6	Низкий	Средне	Высокая
			7	Низкий	Часто	Низкая
			8	Низкий	Часто	Средняя
			9	Низкий	Часто	Высокая
			10	Средний	Редко	Низкая
			11	Средний	Редко	Средняя
			12	Средний	Редко	Высокая
			13	Средний	Средне	Низкая
			14	Средний	Средне	Средняя
			15	Средний	Средне	Высокая
			16	Средний	Часто	Низкая
			17	Средний	Часто	Средняя
			18	Средний	Часто	Высокая
			19	Высокий	Редко	Низкая
			20	Высокий	Редко	Средняя
			21	Высокий	Редко	Высокая
			22	Высокий	Средне	Низкая
			23	Высокий	Средне	Средняя
			24	Высокий	Средне	Высокая
			25	Высокий	Часто	Низкая
			26	Высокий	Часто	Средняя
			27	Высокий	Часто	Высокая
		*/
		(CASE
			WHEN Customer_Average_Check_Segment = 'Low' THEN
				CASE
					WHEN Customer_Frequency_Segment = 'Rarely' THEN 
						CASE
							WHEN Customer_Churn_Segment = 'Low' THEN 1
							WHEN Customer_Churn_Segment = 'Medium' THEN 2
							WHEN Customer_Churn_Segment = 'High' THEN 3
						END
					WHEN Customer_Frequency_Segment = 'Occasionally' THEN
						CASE
							WHEN Customer_Churn_Segment = 'Low' THEN 4
							WHEN Customer_Churn_Segment = 'Medium' THEN 5
							WHEN Customer_Churn_Segment = 'High' THEN 6
						END
					WHEN Customer_Frequency_Segment = 'Often' THEN
						CASE
							WHEN Customer_Churn_Segment = 'Low' THEN 7
							WHEN Customer_Churn_Segment = 'Medium' THEN 8
							WHEN Customer_Churn_Segment = 'High' THEN 9
						END
				END
			WHEN Customer_Average_Check_Segment = 'Medium' THEN
				CASE
					WHEN Customer_Frequency_Segment = 'Rarely' THEN
						CASE
							WHEN Customer_Churn_Segment = 'Low' THEN 10
							WHEN Customer_Churn_Segment = 'Medium' THEN 11
							WHEN Customer_Churn_Segment = 'High' THEN 12
						END
					WHEN Customer_Frequency_Segment = 'Occasionally' THEN
						CASE
							WHEN Customer_Churn_Segment = 'Low' THEN 13
							WHEN Customer_Churn_Segment = 'Medium' THEN 14
							WHEN Customer_Churn_Segment = 'High' THEN 15
						END
					WHEN Customer_Frequency_Segment = 'Often' THEN
						CASE
							WHEN Customer_Churn_Segment = 'Low' THEN 16
							WHEN Customer_Churn_Segment = 'Medium' THEN 17
							WHEN Customer_Churn_Segment = 'High' THEN 18
						END
				END
			WHEN Customer_Average_Check_Segment = 'High' THEN
				CASE
					WHEN Customer_Frequency_Segment = 'Rarely' THEN
						CASE
							WHEN Customer_Churn_Segment = 'Low' THEN 19
							WHEN Customer_Churn_Segment = 'Medium' THEN 20
							WHEN Customer_Churn_Segment = 'High' THEN 21
						END
					WHEN Customer_Frequency_Segment = 'Occasionally' THEN
						CASE
							WHEN Customer_Churn_Segment = 'Low' THEN 22
							WHEN Customer_Churn_Segment = 'Medium' THEN 23
							WHEN Customer_Churn_Segment = 'High' THEN 24
						END
					WHEN Customer_Frequency_Segment = 'Often' THEN
						CASE
							WHEN Customer_Churn_Segment = 'Low' THEN 25
							WHEN Customer_Churn_Segment = 'Medium' THEN 26
							WHEN Customer_Churn_Segment = 'High' THEN 27
						END
				END
		END) AS Customer_Segment,
		(CASE
		 	/*Если покупатель входит в список тех кто последние три покупки совершал в одном магазине*/
			WHEN level_2.Customer_ID = (SELECT Customer_ID FROM loyal_customers) THEN 
		 		(SELECT
				  Transaction_Store_ID
				FROM (
					/*нумеруем транзакции начиная с последней*/
					SELECT
						Customer_ID,
						Transaction_Store_ID,
						Transaction_DateTime,
						ROW_NUMBER() OVER (PARTITION BY Customer_ID ORDER BY Transaction_DateTime DESC) AS rn
				  	FROM Transactions
				  	JOIN CustomerCards ON CustomerCards.Customer_Card_ID = Transactions.Customer_Card_ID) AS list
				 /*просто получаем последнюю транзакцию данного клиента и извлекаем id магазина*/
				WHERE rn = 1 AND list.Customer_ID = level_2.Customer_ID)
		 /*Если покупатель НЕ(!!!) входит в список тех кто последние три покупки совершал в одном магазине*/
		 ELSE
			(
				SELECT Transaction_Store_ID 
				FROM Customer_Primary_Store_Set
				WHERE Customer_Primary_Store_Set.Customer_ID = level_2.Customer_ID
				AND TransactionPercentage = (
					SELECT MAX(TransactionPercentage) AS bigest/*Выбираем магазин куда покупатель ходит чаще всего*/
					FROM Customer_Primary_Store_Set 
					WHERE Customer_Primary_Store_Set.Customer_ID = level_2.Customer_ID
					)
				AND last_transaction = ( /*Если таких магазинов несколько то из них...*/
					SELECT MAX(last_transaction)/*...получаем магазин с датой последней транзакции...*/
				    FROM Customer_Primary_Store_Set
				    WHERE Customer_Primary_Store_Set.Customer_ID = level_2.Customer_ID
					AND TransactionPercentage = ( 
						SELECT MAX(TransactionPercentage) AS bigest
						FROM Customer_Primary_Store_Set 
					 	WHERE Customer_Primary_Store_Set.Customer_ID = level_2.Customer_ID)))

		END) AS Customer_Primary_Store
	FROM level_2
	FULL JOIN loyal_customers ON loyal_customers.Customer_ID = level_2.Customer_ID;
	
-- SELECT * FROM CustomersView
