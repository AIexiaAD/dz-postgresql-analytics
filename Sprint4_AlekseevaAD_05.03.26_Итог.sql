/* Проект «Секреты Тёмнолесья»
 * Цель проекта: изучить влияние характеристик игроков и их игровых персонажей 
 * на покупку внутриигровой валюты «райские лепестки», а также оценить 
 * активность игроков при совершении внутриигровых покупок
 * 
 * Автор: Алексеева Анастасия
*/

-- Часть 1. Исследовательский анализ данных
-- Задача 1. Исследование доли платящих игроков

-- 1.1. Доля платящих пользователей по всем данным:
-- (Исправленная версия) Общая доля платящих игроков
SELECT 
    COUNT(*) AS total_players,
    SUM(payer) AS paying_players,
    ROUND(AVG(payer) * 100, 2) AS paying_percent
FROM fantasy.users;
-- Итог: Всего зарегистрированных игроков = 22 214 человек;
-- 		 Из них 3 929 человек совершали покупки за реальные деньги. Это ~17,7%;
-- 		 Получается, что каждый шестой игрок хотя бы раз что-то покупал в игре (1/0,17687 = 5,65).



-- 1.2. Доля платящих пользователей в разрезе расы персонажа:
-- (Исправленная версия) Доля платящих игроков в разрезе рас
SELECT 
    r.race,
    SUM(u.payer) AS paying_players,
    COUNT(*) AS total_players,
    ROUND(AVG(u.payer) * 100, 2) AS paying_percent
FROM fantasy.users u
JOIN fantasy.race r ON u.race_id = r.race_id
GROUP BY r.race
ORDER BY r.race;
-- Итог: Раса Demon имеет самую max долю игроков, которые что-то покупали = 19,37%;
-- 		 Раса Elf имеет самую min долю донатеров = 17,07%;
-- 		 Остальные расы находятся в диапазоне 17,2 - 18,1%.




-- Задача 2. Исследование внутриигровых покупок
-- 2.1. Статистические показатели по полю amount:
SELECT 
    COUNT(*) AS total_purchases,
    SUM(amount) AS total_amount,
    MIN(amount) AS min_amount,
    MAX(amount) AS max_amount,
    AVG(amount) AS avg_amount,
    PERCENTILE_CONT(0.5) 
    WITHIN GROUP (ORDER BY amount) AS median_amount,
    STDDEV(amount) AS stddev_amount
FROM fantasy.events;
-- Итог: Всего было 1 307 678 покупок на сумму 686 615 040;
-- 		 Min стоимость = 0. Max = 486 615,1;
-- 		 Ср. стоимость = 525,7. Медиана = 74,9;
-- 		 Станд. отклонение = 2 517,3.


-- 2.2: Аномальные нулевые покупки:
SELECT 
    COUNT(*) AS zero_purchases,
    ROUND(COUNT(*) * 100.0 / (SELECT COUNT(*) FROM fantasy.events), 2) AS zero_percentage
FROM fantasy.events
WHERE amount = 0;
-- Итог: Всего таких транзакций = 907. Это 0,07% от общ. числа покупок (1 307 678);
-- 		 Возможно это было из-за акций по типу "бесплатный предмет" или начисление разных бонусов, подарков или возвратов.


-- 2.3 (Новая версия): Популярные эпические предметы:
WITH 
    total_stats AS (
        SELECT 
            COUNT(*) AS total_orders,
            COUNT(DISTINCT id) AS total_buyers
        FROM fantasy.events
        WHERE amount > 0
    )
SELECT 
    i.game_items AS item_name,
    COUNT(e.transaction_id) AS sales_count,
    ROUND(COUNT(e.transaction_id) * 100.0 / total_stats.total_orders, 2) AS sales_percent,
    ROUND(COUNT(DISTINCT e.id) * 100.0 / total_stats.total_buyers, 2) AS buyers_percent
FROM fantasy.events e
LEFT JOIN fantasy.items i ON e.item_code = i.item_code
CROSS JOIN total_stats
WHERE e.amount > 0
GROUP BY i.game_items, total_stats.total_orders, total_stats.total_buyers
ORDER BY buyers_percent DESC;
-- Итог: Предмет 6010 (Book of Legends) охватывает 88,4% покупаателей и 76,7% продаж;
-- 		 Предмет 6011 (Bag of Holding) охватывает 86,7% покупаталей и 20,8% продаж;
--		 Скорее всего эти предметы базовые или используются как расходные материалы;
-- 		 Предмет 6012 (Necklace of Wisdom) имеет всего 11,8% покупаталей и всего 1% продаж;
-- 		 Остальные предметы покупают очень редко. Возможно они очень редкие или очень дорогие.




-- Часть 2.(Новая версия) Решение ad hoc-задачи
-- Задача: Зависимость активности игроков от расы персонажа:

WITH 
gamers_stat AS (
    SELECT race_id, 
    COUNT(*) AS total_gamers
    FROM fantasy.users
    GROUP BY race_id
),
buyers_stat AS ( -- Считаем статистику по покупателям
    SELECT 
        u.race_id,
        COUNT(DISTINCT u.id) AS total_buyers,
        AVG(u.payer) AS payer_share_among_buyers
    FROM fantasy.users u
    WHERE u.id IN (SELECT id FROM fantasy.events WHERE amount > 0)
    GROUP BY u.race_id
),
orders_stat AS ( -- Считаем статистику по покупкам
    SELECT 
        u.race_id,
        COUNT(*) AS total_orders,
        SUM(e.amount) AS total_amount
    FROM fantasy.events e
    JOIN fantasy.users u ON e.id = u.id
    WHERE e.amount > 0
    GROUP BY u.race_id
)
SELECT 
    r.race,
    COALESCE(g.total_gamers, 0) AS total_gamers,
    COALESCE(b.total_buyers, 0) AS total_buyers,
    CASE 
        WHEN COALESCE(g.total_gamers, 0) > 0 
        THEN ROUND(COALESCE(b.total_buyers, 0)::numeric / g.total_gamers, 4)
        ELSE 0 
    END AS buyers_share,
    ROUND(COALESCE(b.payer_share_among_buyers, 0)::numeric, 4) AS paying_share_among_buyers,
    CASE 
        WHEN COALESCE(b.total_buyers, 0) > 0 
        THEN ROUND(COALESCE(o.total_orders, 0)::numeric / b.total_buyers, 2)
        ELSE 0 
    END AS avg_purchases_per_buyer,
    CASE 
        WHEN COALESCE(o.total_orders, 0) > 0 
        THEN ROUND(COALESCE(o.total_amount, 0)::numeric / o.total_orders, 2)
        ELSE 0 
    END AS avg_amount_per_purchase,
    CASE 
        WHEN COALESCE(b.total_buyers, 0) > 0 
        THEN ROUND(COALESCE(o.total_amount, 0)::numeric / b.total_buyers, 2)
        ELSE 0 
    END AS avg_total_amount_per_buyer
FROM fantasy.race r
LEFT JOIN gamers_stat g ON r.race_id = g.race_id
LEFT JOIN buyers_stat b ON r.race_id = b.race_id
LEFT JOIN orders_stat o ON r.race_id = o.race_id
ORDER BY r.race;
-- Итог: Доля покупателей для всех рас ~60-63%;
-- 		 Доля платящих игроков варьируется от 16,3% (Elf) до 20% (Demon);
--		 Ср. кол-во покупок на покупателя: Human (121,4), Angel (106,8);
--		 Скорее всего расы Human и Angel нуждаются в предметах чаще или они более активны в игре;
-- 		 Demon (77,9) и Orc (81,7) покупают реже всего;
-- 		 Ср. стоимость одной покупки max у Northman (761,5). Min у Human (403,1);
-- 		 Ср. суммарная трата на одного покупателя max у Northman (62 519,1). Дальше у Elf (53 761,2);
-- 		 Min у Demon (41 194,4) и также у Orc (41 761,7);
-- 		 В итоге Northman тратит на 52% больше, чем Demon;
-- 		 Northman и Elf более дорогие расы. Demon и Orc - экономные расы. Раса Human не лидирует по суммарным затратам, хотя у них высокая частота покупок. 