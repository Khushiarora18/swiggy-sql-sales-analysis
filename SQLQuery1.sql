SELECT * FROM swiggy_data

--STEP 1: DATA VALIDATION AND CLEANING
-- NULL CHECK
SELECT
	SUM(CASE WHEN State IS NULL THEN 1 ELSE 0 END) AS null_state,
	SUM(CASE WHEN City IS NULL THEN 1 ELSE 0 END) AS null_city,
	SUM(CASE WHEN Order_Date IS NULL THEN 1 ELSE 0 END) AS null_order_date,
	SUM(CASE WHEN Restaurant_Name IS NULL THEN 1 ELSE 0 END) AS null_restaurant,
	SUM(CASE WHEN Location IS NULL THEN 1 ELSE 0 END) AS null_location,
	SUM(CASE WHEN Category IS NULL THEN 1 ELSE 0 END) AS null_category,
	SUM(CASE WHEN Dish_Name IS NULL THEN 1 ELSE 0 END) AS null_dish,
	SUM(CASE WHEN Price_INR IS NULL THEN 1 ELSE 0 END) AS null_price,
	SUM(CASE WHEN Rating IS NULL THEN 1 ELSE 0 END) AS null_rating,
	SUM(CASE WHEN Rating_Count IS NULL THEN 1 ELSE 0 END) AS null_rating_count
FROM swiggy_data;


--BLANK OR EMPTY STRINGS CHECK
SELECT *
FROM swiggy_data
WHERE
State = '' OR City = '' OR Restaurant_Name = '' OR Location = '' OR Category = '' OR Dish_Name = ''  
 

 --DUPLICATION DETECTION
 SELECT
 State, City, order_date, restaurant_name, location, category, dish_name, price_INR, rating, rating_count, count(*) as CNT
 FROM swiggy_data
 GROUP BY 
 State, City, order_date, restaurant_name, location, category, dish_name, price_INR, rating, rating_count
 HAVING count (*) > 1 


 --DELETION OF DUPLICATES DETECTED
 WITH CTE AS (
 SELECT *, ROW_NUMBER() Over (
	PARTITION BY State, City, order_date, restaurant_name, location, category, dish_name, price_INR, rating, rating_count
	ORDER BY (SELECT NULL)
	) AS rn
	FROM swiggy_data
	)
	DELETE FROM CTE WHERE rn>1



--SCHEMA CREATION
--DIMENSION TABLES

--DATE TABLE
CREATE TABLE dim_date (
	date_id INT IDENTITY(1,1) PRIMARY KEY,
	Full_Date DATE,
	Year INT,
	Month INT,
	Month_Name varchar(20),
	Quarter INT,
	Day INT,
	Week INT
	); 

--LOCATION TABLE
CREATE TABLE dim_location (
	location_id INT IDENTITY(1,1) PRIMARY KEY,
	State VARCHAR(100),
	City VARCHAR(100),
	Location VARCHAR (200)
	);

--RESTAURANT TABLE
CREATE TABLE dim_restaurant(
	restaurant_id INT IDENTITY(1,1) PRIMARY KEY,
	restaurant_name VARCHAR(200)
	);

--CATEGORY TABLE
CREATE TABLE dim_category(
	category_id INT IDENTITY(1,1) PRIMARY KEY,
	Category VARCHAR (200)
	);

--DISH TABLE
CREATE TABLE dim_dish(
	dish_id INT IDENTITY(1,1) PRIMARY KEY,
	Dish_Name VARCHAR(200)
	);


--FACT TABLE CREATION
CREATE TABLE fact_swiggy_orders(
	order_id INT IDENTITY(1,1) PRIMARY KEY,

	date_id INT, 
	Price_INR DECIMAL(10,2),
	Rating DECIMAL(4,2),
	Rating_Count INT,

	location_id INT,
	restaurant_id INT,
	category_id INT,
	dish_id INT,

	FOREIGN KEY (date_id) REFERENCES dim_date(date_id),
	FOREIGN KEY (location_id) REFERENCES dim_location(location_id),
	FOREIGN KEY (restaurant_id) REFERENCES dim_restaurant(restaurant_id),
	FOREIGN KEY (category_id) REFERENCES dim_category(category_id),
	FOREIGN KEY (dish_id) REFERENCES dim_dish(dish_id)
	);
	
SELECT * FROM fact_swiggy_orders


--INSERT DATA IN TABLES

--dim date
INSERT INTO dim_date(Full_Date, Year, Month, Month_Name, Quarter, Day, Week)
SELECT DISTINCT
	Order_Date,
	YEAR(Order_Date),
	MONTH(Order_Date),
	DATENAME(MONTH, Order_Date),
	DATEPART(QUARTER, Order_Date),
	DAY(Order_Date),
	DATEPART(WEEK, Order_Date)
FROM swiggy_data
WHERE Order_Date IS NOT NULL;

SELECT * FROM dim_date

--dim location
INSERT INTO dim_location (State, City, Location)
SELECT DISTINCT
	State,
	City,
	Location
FROM swiggy_data;

--dim restaurant
INSERT INTO dim_restaurant (restaurant_name)
SELECT DISTINCT	
	Restaurant_Name
FROM swiggy_data;

--dim category
INSERT INTO dim_category(Category)
SELECT DISTINCT
	Category
FROM swiggy_data;

--dim dish
INSERT INTO dim_dish(Dish_Name)
SELECT DISTINCT
	Dish_Name
FROM swiggy_data;


--FACT TABLE DATA

INSERT INTO fact_swiggy_orders
(
	date_id,
	Price_INR,
	Rating,
	Rating_Count,
	location_id,
	restaurant_id,
	category_id,
	dish_id
)
SELECT
	dd.date_id,
	s.Price_INR,
	s.Rating,
	s.Rating_Count,
	dl.location_id,
	dr.restaurant_id,
	dc.category_id,
	dsh.dish_id
FROM swiggy_data s

JOIN dim_date dd
	ON dd.Full_Date = s.Order_Date

JOIN dim_location dl
	ON dl.State = s.State
	AND dl.City = s.City
	AND dl.Location = s.Location

JOIN dim_restaurant dr
	ON dr.restaurant_name = s.Restaurant_Name

JOIN dim_category dc
	ON dc.Category = s.Category

JOIN dim_dish dsh
	ON dsh.Dish_Name = s.Dish_Name;

SELECT * FROM fact_swiggy_orders

--SCHEMA REQUIRED
SELECT * FROM fact_swiggy_orders f
JOIN dim_date d ON f.date_id = d.date_id
JOIN dim_location l ON f.location_id = l.location_id
JOIN dim_restaurant r ON f.restaurant_id = r.restaurant_id
JOIN dim_category c ON f.category_id = c.category_id
JOIN dim_dish di ON f.dish_id = di.dish_id;


--KPIs

--TOTAL ORDERS
SELECT COUNT(*) AS Total_Orders
FROM fact_swiggy_orders

--TOTAL REVENUE (INR Million)
SELECT
FORMAT(SUM(CONVERT(FLOAT, price_INR))/1000000, 'N2') + 'INR Million'
AS Total_Revenue
FROm fact_swiggy_orders

--AVERAGE DISH PRICE
SELECT
FORMAT(AVG(CONVERT(FLOAT, price_INR)), 'N2') + 'INR'
AS Total_Revenue
FROm fact_swiggy_orders

--AVERAGE RATINGS
SELECT
AVG(Rating) AS Avg_Rating
FROM fact_swiggy_orders

--GRANULAR REQUIREMENTS

--MONTHLY ORDERS (YYYY-MM)
SELECT
	d.year,
	d.month,
	d.month_name,
	COUNT(*) AS total_orders
FROM fact_swiggy_orders f
JOIN dim_date d ON f.date_id = d.date_id
GROUP BY d.Year, d.month, d.month_name
ORDER BY d.year, d.month;

--QUATERLY ORDERS (Q1, Q2,Q3,Q4)
SELECT
	d.year,
	d.quarter,
	COUNT(*) AS total_orders
FROM fact_swiggy_orders f
JOIN dim_date d ON f.date_id = d.date_id
GROUP BY d.year, d.quarter
ORDER BY d.year, d.quarter;

--YEARLY ORDERS
SELECT
	d.year,
	COUNT(*) AS total_orders
FROM fact_swiggy_orders f
JOIN dim_date d ON f.date_id = d.date_id
GROUP BY d.year
ORDER BY d.year;

--ORDERS BY DAY OF WEEK (MON TO SUN)
SELECT
	DATENAME(WEEKDAY, d.full_date) AS day_name,
	COUNT(*) AS total_orders
FROM fact_swiggy_orders f
JOIN dim_date d ON f.date_id = d.date_id
GROUP BY DATENAME(WEEKDAY, d.full_date), DATEPART(WEEKDAY, d.full_date)
ORDER BY DATEPART(WEEKDAY, d.full_date);

--TOP 10 CITIES BY ORDER VOLUME
SELECT TOP 10
l.city,
COUNT(*) AS Total_Orders FROM fact_swiggy_orders f
JOIN dim_location l
ON l.location_id = f.location_id
GROUP BY l.City
ORDER BY COUNT(*) DESC

SELECT TOP 10
l.city,
SUM(f.Price_INR) AS Total_Revenue FROM fact_swiggy_orders f
JOIN dim_location l
ON l.location_id = f.location_id
GROUP BY l.City
ORDER BY SUM(f.Price_INR) DESC

--REVENUE CONTRIBUTION BY STATES
SELECT 
l.state,
SUM(f.Price_INR) AS Total_Revenue FROM fact_swiggy_orders f
JOIN dim_location l
ON l.location_id = f.location_id
GROUP BY l.State
ORDER BY SUM(f.Price_INR) DESC

--TOP 10 RESTAURANTS BY ORDERS
SELECT TOP 10
r.restaurant_name,
COUNT(*) AS Total_Orders FROM fact_swiggy_orders f
JOIN dim_restaurant r
ON r.restaurant_id = f.restaurant_id
GROUP BY r.restaurant_name
ORDER BY COUNT(*) DESC


--TOP CATEGORIES BY ORDER VOLUME
SELECT
	c.category,
	COUNT(*) AS Total_Orders
FROM fact_swiggy_orders f
JOIN dim_category c ON f.category_id = c.category_id
GROUP BY c.category
ORDER BY Total_Orders DESC;

--MOST ORDERED DISHES
SELECT 
	c.category,
	COUNT(*) AS total_orders
FROM fact_swiggy_orders f
JOIN dim_category c ON f.category_id = c.category_id
GROUP BY c.category
ORDER BY total_orders DESC;

--TOTAL REVENUE BY STATE
SELECT
	 l.state,
	 SUM(CONVERT(FLOAT, f.price_inr)) AS total_revenue_inr
FROM fact_swiggy_orders f
JOIN dim_location l ON f.location_id = l.location_id
GROUP BY l.state
ORDER BY total_revenue_inr DESC;

--CUISINE PERFORMANCE (ORDERS AND AVERAGE RATING)
SELECT
	c.category,
	COUNT(*) AS total_orders,
	AVG(CONVERT(FLOAT, f.rating)) AS avg_rating
FROM fact_swiggy_orders f
JOIN dim_category c ON f.category_id = c.category_id
GROUP BY c.category
ORDER BY total_orders DESC;

--TOTAL ORDERS BY PRICE RANGE
SELECT
	CASE
		WHEN CONVERT(FLOAT, price_inr) < 100 THEN 'Under 100'
		WHEN CONVERT(FLOAT, price_inr) BETWEEN 100 AND 199 THEN '100-199'
		WHEN CONVERT(FLOAT, price_inr) BETWEEN 200 AND 299 THEN '200-299'
		WHEN CONVERT(FLOAT, price_inr) BETWEEN 300 AND 499 THEN '300-499'
		ELSE '500+'
	END AS price_range,
	COUNT(*) AS total_orders
FROM fact_swiggy_orders
GROUP BY
	CASE
		WHEN CONVERT(FLOAT, price_inr) < 100 THEN 'Under 100'
		WHEN CONVERT(FLOAT, price_inr) BETWEEN 100 AND 199 THEN '100-199'
		WHEN CONVERT(FLOAT, price_inr) BETWEEN 200 AND 299 THEN '200-299'
		WHEN CONVERT(FLOAT, price_inr) BETWEEN 300 AND 499 THEN '300-499'
		ELSE '500+'
	END
ORDER BY total_orders DESC;

--RATING COUNT DISTRIBUTION (1-5)
SELECT
	rating,
	COUNT(*) AS rating_count
FROM fact_swiggy_orders
GROUP BY rating
ORDER BY rating;