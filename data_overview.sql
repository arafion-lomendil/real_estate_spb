/*В этой части проекта познакомимся с данными и
изучим содержимое таблиц. Это поможет оценить 
объём данных, разброс метрик и найти ошибки вроде
аномальных или неправдоподобных значений.
*/
-- Временной интервал данных
SELECT MIN(first_day_exposition) AS min_date,
MAX(first_day_exposition) AS max_date
FROM real_estate.advertisement;

-- Типы населённых пунктов
SELECT type,
COUNT(id) AS ad_count,
ROUND(COUNT(id) * 1.0 / SUM(COUNT(id)) OVER (),4) AS ad_share 
FROM real_estate.type 
JOIN real_estate.flats USING(type_id)
GROUP BY 1
ORDER BY 2 DESC;

-- Время активности объявления
SELECT MIN(days_exposition) AS min_days,
MAX(days_exposition) AS max_days,
AVG(days_exposition) AS avg_days,
PERCENTILE_DISC(0.5) WITHIN GROUP (ORDER BY days_exposition) AS perc_days
FROM real_estate.advertisement;

-- Доля снятых с публикации объявлений
SELECT COUNT(days_exposition) AS real_estate_sold,
COUNT(*) real_estate_total,
ROUND(COUNT(days_exposition)*1.0/COUNT(*),4) AS real_estate_sold_share
FROM real_estate.advertisement;

-- Объявления Санкт-Петербурга
SELECT COUNT(*) FILTER (WHERE city='Санкт-Петербург') AS cnt_ad_spb,
COUNT(*) AS ad_total,
ROUND(COUNT(*) FILTER (WHERE city='Санкт-Петербург') *1.0/ COUNT(*),4) AS ad_spb_share
FROM real_estate.advertisement
JOIN real_estate.flats USING(id)
JOIN real_estate.city USING(city_id);

-- Стоимость квадратного метра
SELECT ROUND(MIN(last_price/total_area)::numeric,2) AS min_price_per_meter,
ROUND(MAX(last_price/total_area)::numeric,2) AS max_price_per_meter,
ROUND(AVG(last_price/total_area)::numeric,2) AS avg_price_per_meter,
PERCENTILE_DISC(0.5) WITHIN GROUP (ORDER BY last_price/total_area) AS perc_price_per_meter
FROM real_estate.advertisement
JOIN real_estate.flats USING(id);

-- Статистические показатели
SELECT 'total_area' AS PARAMETER,
MIN(total_area) AS min_value,
MAX(total_area) AS max_value,
AVG(total_area) AS avg_value,
PERCENTILE_DISC(0.5) WITHIN GROUP (ORDER BY total_area) AS median,
PERCENTILE_DISC(0.99) WITHIN GROUP (ORDER BY total_area) AS perc_99
FROM real_estate.flats
UNION ALL
SELECT 'rooms',
MIN(rooms),
MAX(rooms),
AVG(rooms),
PERCENTILE_DISC(0.5) WITHIN GROUP (ORDER BY rooms),
PERCENTILE_DISC(0.99) WITHIN GROUP (ORDER BY rooms)
FROM real_estate.flats
UNION ALL
SELECT 'balcony',
MIN(balcony),
MAX(balcony),
AVG(balcony),
PERCENTILE_DISC(0.5) WITHIN GROUP (ORDER BY balcony),
PERCENTILE_DISC(0.99) WITHIN GROUP (ORDER BY balcony)
FROM real_estate.flats
UNION ALL
SELECT 'ceiling_height',
MIN(ceiling_height),
MAX(ceiling_height),
AVG(ceiling_height),
PERCENTILE_DISC(0.5) WITHIN GROUP (ORDER BY ceiling_height),
PERCENTILE_DISC(0.99) WITHIN GROUP (ORDER BY ceiling_height)
FROM real_estate.flats
UNION ALL
SELECT 'floor',
MIN(floor),
MAX(floor),
AVG(floor),
PERCENTILE_DISC(0.5) WITHIN GROUP (ORDER BY floor),
PERCENTILE_DISC(0.99) WITHIN GROUP (ORDER BY floor)
FROM real_estate.flats;
/* Данные содержат аномально высокие значения практически в каждом столбце, кроме этажа недвижимости. 
 * Это можно проверить, если сравнить максимальное значение с 99 перцентилем. Столь высокие значения 
 * негативно сказываются на средних значениях, поэтому их надо отфильтровать при основном анализе данных.
 * Также смущает низкое значение высоты потолка — всего 1 метр. Возможно, в этом случае такое значение 
 * можно рассматривать как аномальное, и его тоже стоит отфильтровать при исследовании, например, проверив 
 * значение 1 перцентиля, которое будет принимать адекватные значения.
 */
