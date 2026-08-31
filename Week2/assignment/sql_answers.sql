-- Week 2 SQL Assignment — Answers
-- Fill in each query below. See sql_assignment.md for the full scenario text.
-- Rename this file to sql_answers.sql before committing.


-- Q1 — Standardizing driver names from the raw feed (Basic · String functions)
-- Distinct, cleaned driver_name from rides — one column: clean_driver_name

SELECT
	DISTINCT INITCAP(
		TRIM(
			REGEXP_REPLACE(r.driver_name, '\s+', ' ', 'g')
		)
	) AS clean_driver_name
FROM
	rides r
ORDER BY
	clean_driver_name ;



-- Q2 — Every payment method actually in use (Basic · String functions)
-- Distinct, lowercased payment_method from rides, sorted alphabetically

SELECT DISTINCT LOWER(r.payment_method ) AS payment_method
FROM rides r 
WHERE r.payment_method IS NOT NULL
ORDER BY payment_method ;

-- Q3 — A readable log of every completed trip (Basic · Joins)
-- driver_name, passenger_name, pickup_city, dropoff_city, fare_amount, requested_at
-- Join locations twice (pickup + dropoff) with separate aliases

SELECT 
	d."name" AS driver_name,
	p."name" AS passenger_name,
	pkl.city_name AS pickup_city,
	dst.city_name AS dropoff_city,
	t.fare_amount ,
	t.requested_at 
FROM trips t 
LEFT JOIN drivers d ON t.driver_id = d.driver_id
LEFT JOIN passengers p ON t.passenger_id = p.passenger_id 
LEFT JOIN locations pkl ON t.pickup_location_id = pkl.location_id 
LEFT JOIN locations dst ON t.dropoff_location_id = dst.location_id 
WHERE t.status = 'completed';

-- Q4 — Drivers who have never driven a single trip (Basic–Intermediate · Joins)
-- driver_name — drivers with zero rows in trips at all
-- Comment: why can't INNER JOIN answer this?

SELECT d."name" AS driver_name
FROM drivers d 
LEFT JOIN trips t ON d.driver_id = t.driver_id 
WHERE t.trip_id IS NULL;
-- INNER JOIN can only join rows that exist on both table. 
--When there is no trip for a driver the driver is excluded from the joined table as well 
-- hence avoiding the answer we are looking for.

-- Q5 — Payment methods nobody has ever used (Intermediate · Joins)
-- payment_method_id, name — payment methods with zero trips
-- Comment: which join type / FROM table if written the other way around?

SELECT * 
FROM payment_methods pm 
LEFT JOIN trips t ON pm.payment_method_id = t.payment_method_id 
WHERE t.trip_id IS NULL;

-- Use RIGHT JOIN with trips as FROM table to write the query other way around.

-- Q6 — Numbering each driver's trips in order (Basic–Intermediate · Window functions)
-- driver_name, requested_at, fare_amount, trip_number (ROW_NUMBER per driver)

SELECT 
	d."name" driver_name,
	t.requested_at,
	t.fare_amount,
	ROW_NUMBER() OVER (
		PARTITION BY t.driver_id
		ORDER BY t.requested_at
	) AS trip_number
FROM drivers d 
INNER JOIN trips t ON d.driver_id = t.driver_id 
ORDER BY driver_name, t.requested_at ;


-- Q7 — Each driver's running earnings (Intermediate · Window functions)
-- driver_name, requested_at, fare_amount, running_total (cumulative SUM per driver)

SELECT
	d."name" driver_name,
	t.requested_at ,
	t.fare_amount ,
	SUM(t.fare_amount) OVER (
		PARTITION BY t.driver_id
		ORDER BY t.requested_at 
	) AS running_total
FROM trips t
LEFT JOIN drivers d ON t.driver_id = d.driver_id
WHERE t.status='completed'
ORDER BY driver_name, t.requested_at ;


-- Q8 — Each driver's single highest-fare trip, without a subquery (Intermediate · Window functions)
-- driver_name, trip_id, fare_amount — one row per driver, via RANK()/ROW_NUMBER() + CTE

WITH 
	ranked_fare_amount AS (
SELECT 
	d."name" driver_name,
	t.trip_id ,
	t.fare_amount ,
	ROW_NUMBER() OVER ( 
		PARTITION BY t.driver_id
		ORDER BY t.fare_amount DESC 
	) AS fare_amount_rank
FROM
	trips t
LEFT JOIN drivers d ON
	d.driver_id = t.driver_id )
SELECT
	driver_name,
	trip_id,
	fare_amount
FROM
	ranked_fare_amount
WHERE
	"fare_amount_rank" = 1
ORDER BY fare_amount DESC ;


-- Q9 — Driver performance scorecard (Intermediate · Conditional aggregation)
-- driver_name, total_trips, completed_trips, cancelled_trips, cancellation_rate, avg_rating

WITH driver_trip_cte AS (
SELECT 
	d."name" AS driver_name,
	count(t.trip_id) AS total_trips,
	count(*) FILTER (WHERE t.status = 'completed') AS completed_trips ,
	count(*) FILTER (WHERE t.status = 'cancelled') AS cancelled_trips ,
	AVG(t.rating)::NUMERIC(3, 2) AS avg_rating
FROM
	drivers d
LEFT JOIN trips t ON
	d.driver_id = t.driver_id 
GROUP BY d."name", d.driver_id
)
SELECT
	*,
	(CASE
		WHEN dt.total_trips = 0 THEN NULL 
	ELSE
		((dt.cancelled_trips::NUMERIC / dt.total_trips) * 100)
	END )::NUMERIC(5, 2) AS cancellation_rate
	FROM
		driver_trip_cte dt;

-- Q10 — Onboarding a new driver atomically (Intermediate · Transactions)
-- BEGIN; INSERT driver; 3x INSERT trip; COMMIT;
-- Comment: what would trigger a rollback, and what happens to the driver row then?



SELECT count(*) FROM drivers d ;
SELECT count(*) FROM trips t ;

BEGIN;

--insert driver
INSERT INTO drivers (name)
VALUES ('Sunita Gurung');

--insert trip1
INSERT
	INTO
	trips (driver_id,
	passenger_id,
	pickup_location_id,
	dropoff_location_id,
	fare_amount,
	distance_km,
	status,
	requested_at,
	completed_at,
	rating,
	payment_method_id)
VALUES (
	1,
	1,
	1,
	1,
	240,
	23,
	'completed',
	NOW(),
	NOW(),
	4,
	3);

--insert trip2
INSERT
	INTO
	trips (driver_id,
	passenger_id,
	pickup_location_id,
	dropoff_location_id,
	fare_amount,
	distance_km,
	status,
	requested_at)
VALUES (
	1,
	1,
	1,
	1,
	240,
	23,
	'cancelled',
	NOW());

--insert trip3
INSERT
	INTO
	trips (driver_id,
	passenger_id,
	pickup_location_id,
	dropoff_location_id,
	fare_amount,
	distance_km,
	status,
	requested_at)
VALUES (
	1,
	1,
	1,
	1,
	-240,
	23,
	'cancelled',
	NOW());
COMMIT ;

SELECT count(*) FROM drivers d ;
SELECT count(*) FROM trips t ;


-- the fare amount in the third insert statement is invalid which triggers a rollback.
-- should the statement fail none of the statements in the transaction will work.

-- Q11 — A saved view for the ops dashboard (Intermediate · Views)
-- 11a. CREATE VIEW driver_cancellation_summary AS ...

CREATE VIEW driver_cancellation_summary AS
WITH driver_trip_cte AS(
SELECT 
	d."name" driver_name,
	count(d.driver_id) AS total_trips,
	count(*) FILTER (WHERE t.status = 'completed') AS completed_trips,
	count(*) FILTER (WHERE t.status = 'cancelled') AS cancelled_trips,
	AVG(t.rating)::NUMERIC(3, 2) AS avg_rating
FROM trips t 
LEFT JOIN drivers d ON t.driver_id = d.driver_id
GROUP BY d."name", d.driver_id)
SELECT
	*,
	((cancelled_trips::NUMERIC / total_trips)* 100)::NUMERIC(5, 2) AS cancellation_rate
FROM
	driver_trip_cte;

-- 11b. SELECT from the view: drivers with cancellation_rate above 20%

SELECT
	*
FROM
	driver_cancellation_summary dcs
WHERE
	dcs.cancellation_rate >20;

-- Q12 — Speeding up a slow driver lookup (Intermediate · Indexing — beyond the pre-reads)
-- 12a. EXPLAIN ANALYZE before the index — note scan type + execution time in a comment
EXPLAIN ANALYZE 
SELECT * FROM trips WHERE driver_id = 8;
--Seq Scan on trips  (cost=0.00..128.49 rows=498 width=67) (actual time=0.032..1.570 rows=490.00 loops=1)
--  Filter: (driver_id = 8)
--  Rows Removed by Filter: 4511
--  Buffers: shared hit=65
--Planning Time: 0.183 ms
--Execution Time: 1.692 ms

-- 12b. CREATE INDEX
CREATE INDEX idx_trips_driver_id
ON trips(driver_id);

-- 12c. EXPLAIN ANALYZE after the index — note what changed in a comment
EXPLAIN ANALYZE 
SELECT * FROM trips WHERE driver_id = 8;
--Bitmap Heap Scan on trips  (cost=8.08..79.20 rows=490 width=67) (actual time=0.189..0.551 rows=490.00 loops=1)
--  Recheck Cond: (driver_id = 8)
--  Heap Blocks: exact=64
--  Buffers: shared hit=64 read=2
--  ->  Bitmap Index Scan on idx_trips_driver_id  (cost=0.00..7.96 rows=490 width=0) (actual time=0.121..0.121 rows=490.00 loops=1)
--        Index Cond: (driver_id = 8)
--        Index Searches: 1
--        Buffers: shared read=2
--Planning:
--  Buffers: shared hit=15 read=1
--Planning Time: 0.467 ms
--Execution Time: 0.677 ms
