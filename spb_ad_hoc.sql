/* Анализ данных для агентства недвижимости
 Решаем ad hoc задачи
 Автор: Денис Рубцов
 Дата: 16.12.2025
*/

-- Задача 1: Время активности объявлений
-- Определим аномальные значения (выбросы) по значению перцентилей:
WITH limits AS (
    SELECT
        PERCENTILE_CONT(0.99) WITHIN GROUP (ORDER BY total_area) AS total_area_limit,
        PERCENTILE_DISC(0.99) WITHIN GROUP (ORDER BY rooms) AS rooms_limit,
        PERCENTILE_DISC(0.99) WITHIN GROUP (ORDER BY balcony) AS balcony_limit,
        PERCENTILE_CONT(0.99) WITHIN GROUP (ORDER BY ceiling_height) AS ceiling_height_limit_h,
        PERCENTILE_CONT(0.01) WITHIN GROUP (ORDER BY ceiling_height) AS ceiling_height_limit_l
    FROM real_estate.flats
),
-- Найдём id объявлений, которые не содержат выбросы, также оставим пропущенные данные:
filtered_id AS(
    SELECT id
    FROM real_estate.flats
    WHERE
        total_area < (SELECT total_area_limit FROM limits)
        AND (rooms < (SELECT rooms_limit FROM limits) OR rooms IS NULL)
        AND (balcony < (SELECT balcony_limit FROM limits) OR balcony IS NULL)
        AND ((ceiling_height < (SELECT ceiling_height_limit_h FROM limits)
            AND ceiling_height > (SELECT ceiling_height_limit_l FROM limits)) OR ceiling_height IS NULL)
    ),
categorized_data AS (
SELECT  id,
		first_day_exposition,
		days_exposition,
		last_price,
		total_area,
		rooms,
		balcony,
		floor,
		ceiling_height,
		is_apartment,
		open_plan,
		airports_nearest,
		parks_around3000,
		ponds_around3000,
        CASE 
        	WHEN city = 'Санкт-Петербург' THEN 'Санкт-Петербург'
        	WHEN type = 'город' AND city <> 'Санкт-Петербург' THEN 'ЛенОбл'
        END AS region,
        CASE
            WHEN days_exposition BETWEEN 1 AND 30 THEN '01. 1-30 days'
            WHEN days_exposition BETWEEN 31 AND 90 THEN '02. 31-90 days'
            WHEN days_exposition BETWEEN 91 AND 180 THEN '03. 91-180 days'
            WHEN days_exposition >= 181 THEN '04. 181+ days'
            WHEN days_exposition IS NULL THEN '05. non category'
        END AS category
    FROM real_estate.advertisement
    LEFT JOIN real_estate.flats USING (id)
    LEFT JOIN real_estate.city USING (city_id)
    LEFT JOIN real_estate.type USING (type_id)
    WHERE
        first_day_exposition BETWEEN '2015-01-01' AND '2018-12-31'
        AND id IN (SELECT * FROM filtered_id)
    )
SELECT region,
	   category,
	   COUNT(*) AS ad_count,
	   ROUND(COUNT(*)::NUMERIC / SUM(COUNT(*)) OVER (PARTITION BY region), 2) AS ad_count_share,
	   ROUND(AVG(last_price/total_area)::NUMERIC,2) AS price_per_meter,
	   ROUND(AVG(total_area)::NUMERIC,2) AS average_area,
	   ROUND(AVG(ceiling_height)::NUMERIC, 2) AS avg_ceil_height,
	   ROUND(AVG(airports_nearest)::NUMERIC / 1000, 2) AS avg_nearest_airport_km,
	   ROUND((SELECT COUNT(*) FROM categorized_data WHERE rooms = 0 OR rooms IS NULL) / COUNT(*)::NUMERIC, 2) AS studio_perc,
	   ROUND((SELECT COUNT(*) FROM categorized_data WHERE is_apartment = 1) / COUNT(*)::NUMERIC, 2) AS apart_perc,
	   ROUND((SELECT COUNT(*) FROM categorized_data WHERE open_plan = 1) / COUNT(*)::NUMERIC, 2) AS open_plan_perc,
	   PERCENTILE_DISC(0.5) WITHIN GROUP (ORDER BY rooms) AS mediane_rooms,	   
	   PERCENTILE_DISC(0.5) WITHIN GROUP (ORDER BY balcony) AS mediane_balcony,	   
	   PERCENTILE_CONT(0.5) WITHIN GROUP (ORDER BY floor) AS mediane_floor,
	   PERCENTILE_CONT(0.5) WITHIN GROUP (ORDER BY parks_around3000) AS mediane_parks,
	   PERCENTILE_CONT(0.5) WITHIN GROUP (ORDER BY ponds_around3000) AS mediane_ponds
FROM categorized_data
WHERE region IS NOT NULL
GROUP BY region, category
ORDER BY region DESC, category;

-- Задача 2: Сезонность объявлений
-- Определим аномальные значения (выбросы) по значению перцентилей:
set lc_time = 'ru_RU';

WITH limits AS (
    SELECT
        PERCENTILE_CONT(0.99) WITHIN GROUP (ORDER BY total_area) AS total_area_limit,
        PERCENTILE_DISC(0.99) WITHIN GROUP (ORDER BY rooms) AS rooms_limit,
        PERCENTILE_DISC(0.99) WITHIN GROUP (ORDER BY balcony) AS balcony_limit,
        PERCENTILE_CONT(0.99) WITHIN GROUP (ORDER BY ceiling_height) AS ceiling_height_limit_h,
        PERCENTILE_CONT(0.01) WITHIN GROUP (ORDER BY ceiling_height) AS ceiling_height_limit_l
    FROM real_estate.flats
),
filtered_id AS (
    SELECT id
    FROM real_estate.flats
    WHERE
        total_area < (SELECT total_area_limit FROM limits)
        AND (rooms < (SELECT rooms_limit FROM limits) OR rooms IS NULL)
        AND (balcony < (SELECT balcony_limit FROM limits) OR balcony IS NULL)
        AND (
            (ceiling_height < (SELECT ceiling_height_limit_h FROM limits)
            AND ceiling_height > (SELECT ceiling_height_limit_l FROM limits))
            OR ceiling_height IS NULL
        )
),
publication_month AS (
    SELECT id,
        EXTRACT(MONTH FROM first_day_exposition) AS month_num,
        TO_CHAR(first_day_exposition, 'TMmon') AS month_name,
        last_price,
        total_area
    FROM real_estate.advertisement ad
    LEFT JOIN real_estate.flats USING (id)
    LEFT JOIN real_estate.type USING (type_id)
    WHERE first_day_exposition BETWEEN '2015-01-01' AND '2018-12-31'
        AND id IN (SELECT * FROM filtered_id)
        AND type = 'город'
    ORDER BY month_num
),
sales_month AS (
    SELECT id,
        EXTRACT(MONTH FROM first_day_exposition + days_exposition * INTERVAL '1 day') AS month_num,
        TO_CHAR(first_day_exposition + days_exposition * INTERVAL '1 day', 'TMmon') AS month_name,
        last_price,
        total_area
    FROM real_estate.advertisement ad
    LEFT JOIN real_estate.flats USING (id)
    LEFT JOIN real_estate.type USING (type_id)
    WHERE first_day_exposition + days_exposition * INTERVAL '1 day' BETWEEN '2015-01-01' AND '2018-12-31'
        AND id IN (SELECT * FROM filtered_id)
        AND type = 'город'
        ORDER BY month_num
)
SELECT 
    month_num,
    'published' AS category,
    month_name,
    COUNT(id) AS ad_count,
    RANK() OVER(ORDER BY COUNT(id) DESC) AS ad_rank,
    ROUND(COUNT(id)::NUMERIC / SUM(COUNT(id)) OVER (), 2) AS ad_count_share,
    ROUND(AVG(last_price / total_area)::NUMERIC, 2) AS price_per_meter,
    ROUND(AVG(total_area)::NUMERIC, 2) AS average_area
FROM publication_month
GROUP BY month_num, month_name
UNION
SELECT
	month_num,
	'sold' AS category,
    month_name,
    COUNT(id),
    RANK() OVER(ORDER BY COUNT(id) DESC),
    ROUND(COUNT(id)::NUMERIC / SUM(COUNT(id)) OVER (), 2) AS ad_count_share,
    ROUND(AVG(last_price / total_area)::NUMERIC, 2),
    ROUND(AVG(total_area)::NUMERIC, 2)
FROM sales_month
GROUP BY month_num, month_name
ORDER BY 1, 2;
