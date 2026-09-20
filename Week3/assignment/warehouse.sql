-- Week 3 Warehouse Assignment — Answers
-- Fill in each CREATE TABLE below. See warehouse_assignment.md for the full spec.
-- Run this against a fresh database, e.g.:
--   psql -U postgres -d postgres -c "CREATE DATABASE movie_dw;"
--   psql -U postgres -d movie_dw -f warehouse.sql
CREATE DATABASE movie_dw;

-- Q1 — dim_movie
-- movie_key (surrogate PK), imdb_id (UNIQUE NOT NULL, natural key), title, rated, plot, poster_url
CREATE TABLE dim_movie (
    movie_key  SERIAL       PRIMARY KEY,
    imdb_id    VARCHAR(100) UNIQUE NOT NULL,
    title      VARCHAR(200) NOT NULL,
    plot       TEXT,
    poster_url TEXT
);

-- Q2 — dim_director, dim_country, dim_language
-- Each: surrogate key + UNIQUE name column. Store only the first-listed value from the
-- comma-separated OMDb field — note the simplification in a comment on each table.

CREATE TABLE dim_director (
    director_key  SERIAL PRIMARY KEY,
    director_name VARCHAR(200) UNIQUE NOT NULL -- only store first listed value from comma seperated field 
);

CREATE TABLE dim_country (
    country_key SERIAL PRIMARY KEY,
    country_name VARCHAR(200) UNIQUE NOT NULL -- only store first listed value from comma seperated field 
);

CREATE TABLE dim_language (
    language_key SERIAL PRIMARY KEY,
    language_name VARCHAR(200) UNIQUE NOT NULL -- only store first listed value from comma seperated field 
);

-- Q3 — dim_genre + bridge_movie_genre
-- dim_genre: genre_key, genre_name (UNIQUE)
-- bridge_movie_genre: movie_key, genre_key — composite PK, both REFERENCES
-- Comment: why can't dim_movie just have a genre_key FK column like it has director_key?

CREATE TABLE dim_genre (
    genre_key SERIAL PRIMARY KEY,
    genre_name VARCHAR(200) UNIQUE NOT NULL
);

CREATE TABLE bridge_movie_genre (
    movie_key INT REFERENCES dim_movie (movie_key),
    genre_key INT REFERENCES dim_genre (genre_key),
    PRIMARY KEY (movie_key, genre_key)
);

-- Q4 — dim_certificate
-- certificate_key, code (UNIQUE) — for the Rated field (PG-13, R, G, Not Rated, ...)

CREATE TABLE dim_certificate (
    certificate_key SERIAL PRIMARY KEY,
    rated_code VARCHAR(20) UNIQUE NOT NULL
)

-- Q5 — dim_release_date
-- date_key (YYYYMMDD INTEGER PK), full_date, year, decade, month, month_name
-- Populate with generate_series, 1900-01-01 through today (same pattern as class's dim_date)

CREATE TABLE dim_release_date (
    date_key INT PRIMARY KEY,
    full_date DATE NOT NULL UNIQUE,
    year SMALLINT NOT NULL,
    decade SMALLINT NOT NULL,
    month SMALLINT NOT NULL CHECK (MONTH BETWEEN 1 AND 12),
    month_name VARCHAR(10)
)

INSERT INTO dim_release_date (
	date_key, full_date , "year" , decade, "month", month_name 
)
SELECT 
	to_char(d, 'YYYYMMDD')::INT AS date_key,
	d::DATE ,
	EXTRACT (YEAR FROM d)::SMALLINT AS "year",
	EXTRACT (DECADE FROM d)::SMALLINT AS decade,
	EXTRACT (MONTH FROM d)::SMALLINT AS "month",
	trim(to_char(d, 'month')) AS month_name
FROM generate_series(
	'1900-01-01'::TIMESTAMP, 
	'2026-09-20'::TIMESTAMP, 	
	'1 DAY'::INTERVAL
) AS d;


-- Q6 — fact_movie
-- One row per movie. FKs to every dimension above, plus measures:
-- runtime_minutes, imdb_rating, imdb_votes, metascore, rotten_tomatoes_pct, box_office_usd
-- UNIQUE constraint tying each row back to its dim_movie row (for idempotent loads)

CREATE TABLE fact_movie (
	fact_movie_key SERIAL PRIMARY KEY ,
    movie_key INT REFERENCES dim_movie (movie_key) UNIQUE ,
    director_key INT REFERENCES dim_director (director_key),
    country_key INT REFERENCES dim_country (country_key),
    language_key INT REFERENCES dim_language (language_key),
    certificate_key INT REFERENCES dim_certificate (certificate_key),
    release_date_key INT REFERENCES dim_release_date (date_key),
    runtime_minutes INT,
    imdb_rating NUMERIC(3,1) CHECK (imdb_rating BETWEEN 1 AND 10),
    imdb_votes BIGINT ,
    metascore INT CHECK (metascore BETWEEN 0 AND 100),
    rotten_tomatoes_pct NUMERIC(3,1) CHECK (rotten_tomatoes_pct BETWEEN 0 AND 100),
    box_office_us BIGINT
)

