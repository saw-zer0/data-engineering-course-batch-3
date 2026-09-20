-- Week 3 Warehouse Assignment — Analytical Queries
-- Run these against your loaded movie_dw. See warehouse_assignment.md for the full scenario text.


-- Q8 — Best-rated movie per genre (Intermediate · Window functions)
-- genre_name, title, imdb_rating — one row per genre, the single highest-rated movie in it
SELECT 
	dg.genre_name,
	dm.title,
	fm.imdb_rating ,
	max(fm.imdb_rating ) OVER (
		PARTITION BY dg.genre_name
		ORDER BY fm.imdb_rating DESC 
	) AS highest_rating_in_genre
FROM fact_movie fm 
JOIN dim_movie dm ON fm.movie_key = dm.movie_key 
JOIN bridge_movie_genre bmg ON dm.movie_key = bmg.movie_key
JOIN dim_genre dg ON bmg.genre_key = dg.genre_key;

-- Q9 — Average rating by decade (Basic–Intermediate · Aggregation)
-- decade, movie_count, avg_imdb_rating (2 decimals) — one row per decade, sorted chronologically
SELECT 
	drd.decade ,
	count(*) AS movie_count,
	AVG(fm.imdb_rating )::NUMERIC(4,2) AS avg_imdb_rating
FROM fact_movie fm 
JOIN dim_release_date drd ON fm.release_date_key = drd.date_key
GROUP BY drd.decade 
ORDER BY drd.decade ;



-- Q10 — Directors with the highest average box office (Intermediate · Aggregation + filtering)
-- director_name, movies_loaded, avg_box_office_usd — only directors with 2+ movies loaded,
-- sorted by avg_box_office_usd descending

SELECT director_name,
	count(*) AS movies_loaded,
	AVG(fm.box_office_usd ) AS avg_box_office_usd
FROM fact_movie fm 
JOIN dim_director dd ON dd.director_key = fm.director_key
GROUP BY dd.director_name
HAVING count(*) > 1
ORDER BY avg_box_office_usd 






