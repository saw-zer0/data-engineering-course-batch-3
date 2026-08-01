-- Week 1 SQL Assignment — Answers
-- Fill in each query below. See sql_assignment.md for the full scenario text.
-- Rename this file to sql_answers.sql before committing.
-- Q1 — Kathmandu to Pokhara (Basic · DQL)
-- Completed rides from Kathmandu to Pokhara: ride_id, driver_name, passenger_name, fare_amount

SELECT
	r.ride_id,
	r.driver_name,
	r.passenger_name ,
	r.fare_amount
FROM
	rides r
WHERE
	LOWER(r.pickup_city) = 'kathmandu'
	AND 
	LOWER(r.dropoff_city) = 'pokhara';

-- Q2 — Top 5 highest fares (Basic · DQL)
-- driver_name, passenger_name, fare_amount — 5 highest fares, descending

SELECT
	r.driver_name,
	r.passenger_name,
	r.fare_amount
FROM 
	rides r
ORDER BY
	fare_amount DESC
LIMIT 5;

-- Q3 — The "Shrestha" complaint (Basic · DQL)
-- Every ride where driver_name contains "shrestha", case-insensitive

SELECT 
	DISTINCT r.driver_name
FROM
	rides r
WHERE 
	r.driver_name ILIKE '%shrestha%';

-- Q4 — How many rides were never rated? (Basic–Intermediate · NULL)
-- One query returning: total_rides, rated_rides, unrated_rides

SELECT 
	count(*) AS total_rides,
	count(r.rating) AS rated_rides,
	count(*)FILTER(WHERE r.rating IS NULL ) AS unrated_rides
FROM
	rides r;

-- Q5 — Every ride that wasn't paid in cash (Intermediate · NULL)
-- ride_id, driver_name, payment_method — not cash, including unrecorded payment methods

SELECT
	r.ride_id,
	r.driver_name,
	r.payment_method
FROM 
	rides r
WHERE 
	r.payment_method IS NULL
	OR 
	r.payment_method != 'cash';

-- Q6 — Revenue by pickup city (Intermediate · Aggregation)
-- pickup_city, total_rides, total_revenue, avg_fare (2 decimals) — sorted by total_revenue desc

SELECT 
	r.pickup_city ,
	count(*) AS total_rides,
	sum(r.fare_amount) AS total_revenue,
	avg(r.fare_amount)::numeric(10,2) AS avg_revenue
FROM
	rides r
GROUP BY
	pickup_city
ORDER BY
	total_revenue DESC ;

-- Q7 — Drivers who qualify for the loyalty bonus (Intermediate · Aggregation)
-- driver_name, completed_rides — drivers with more than 100 completed rides, sorted desc

SELECT 
	driver_name,
	count(*) AS completed_rides
FROM 
	rides r
WHERE
	r.ride_status = 'completed'
GROUP BY
	driver_name
HAVING
	count(*) > 100
ORDER BY
	completed_rides DESC ;

-- Q8 — Ride outcomes by status (Intermediate · Aggregation)
-- ride_status, ride_count, avg_distance_km (2 decimals) — sorted by ride_count desc

SELECT 
	r.ride_status,
	count(*) AS ride_count,
	avg(r.ride_distance_km)::NUMERIC(10, 2) AS avg_distance_km
FROM 
	rides r
GROUP BY
	r.ride_status
ORDER BY
	ride_count DESC ;

-- Q9 — A new driver's first ride (Basic–Intermediate · DML)
-- 9a. INSERT the new ride (ride_id 9001, rating NULL)

INSERT
	INTO
	rides (
	ride_id,
	driver_name,
	passenger_name,
	pickup_city,
	dropoff_city,
	fare_amount,
	ride_distance_km,
	ride_status,
	requested_at,
	completed_at,
	payment_method
)
VALUES (
	9001,
	'Sunita Gurung',
	'Rajan Thapa',
	'Lalitpur',
	'Bhaktapur',
	350,
	12.4,
	'completed',
	now(),
	now(),
	'cash'
)

SELECT
	*
FROM
	rides
ORDER BY
	ride_id DESC ;

-- 9b. UPDATE the rating to 4.8 for ride_id 9001

UPDATE
	rides r
SET
	rating = 4.8
WHERE
	ride_id = 9001;

-- Q10 — Locking down payment methods (Intermediate · DDL)
-- 10a. ALTER TABLE to restrict payment_method to a fixed set of values

ALTER TABLE rides 
	ADD CONSTRAINT check_payment_method
	CHECK(payment_method IN ('cash', 'esewa', 'khalti', 'card', 'wallet'));

-- 10b. INSERT using an invalid payment method — note the error you'd expect in a comment

INSERT
	INTO
	rides (
	ride_id,
	driver_name,
	passenger_name,
	pickup_city,
	dropoff_city,
	fare_amount,
	ride_distance_km,
	ride_status,
	requested_at,
	completed_at,
	payment_method
)
VALUES (
	9002,
	'Sunita Gurung',
	'Rajan Thapa',
	'Lalitpur',
	'Bhaktapur',
	350,
	12.4,
	'completed',
	now(),
	now(),
	'paypal'
) -- ERROR: new row for relation "rides" violates check constraint "check_payment_method"

-- Q11 — Rides priced above the platform average (Intermediate · Subquery)
-- ride_id, driver_name, fare_amount — fare_amount above the average of ALL rides (via subquery)

SELECT
	r.ride_id ,
	r.driver_name ,
	r.fare_amount
FROM
	rides r
WHERE
	r.fare_amount > (
	SELECT
		avg(fare_amount)
	FROM
		rides);
-- Q12 — Each driver's single best ride (Intermediate · Correlated subquery)
-- driver_name, ride_id, fare_amount — one row per driver, their own max fare_amount

SELECT
	r.driver_name ,
	r.ride_id ,
	r.fare_amount
FROM
	rides r
WHERE
	r.fare_amount = (
	SELECT
		max(t.fare_amount)
	FROM
		rides t
	WHERE
		t.driver_name = r.driver_name );
