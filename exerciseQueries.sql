SELECT *
FROM dannys_diner.members;

SELECT *
FROM dannys_diner.menu;

SELECT *
FROM dannys_diner.sales;

-- 1. What is the total amount each customer spent at the restaurant?

SELECT 
	sales.customer_id, 
    SUM(menu.price) AS total_sales
FROM dannys_diner.sales 
JOIN dannys_diner.menu
	ON sales.product_id = menu.product_id
GROUP BY sales.customer_id;

-- 2. How many days has each customer visited the restaurant?

SELECT 
	sales.customer_id, 
    COUNT(distinct(sales.order_date)) AS visit_count
FROM dannys_diner.sales 
GROUP BY sales.customer_id;

-- 3. What was the first item from the menu purchased by each customer?

WITH 
	ranked_sales_per_customer AS(
		SELECT
			sales.customer_id,
			sales.order_date,
			menu.product_name,
			dense_rank() over(partition by sales.customer_id order by sales.order_date) as ranking
		FROM dannys_diner.sales
		JOIN dannys_diner.menu
			ON sales.product_id = menu.product_id
    )
SELECT 
	customer_id,
    product_name,
    order_date
FROM ranked_sales_per_customer
WHERE
	ranking = 1
GROUP BY customer_id, product_name, order_date;

-- 4. What is the most purchased item on the menu and how many times was it purchased by all customers?

SELECT 
	sales.product_id, 
    COUNT(sales.product_id) AS order_count
FROM dannys_diner.sales 
GROUP BY sales.product_id;

-- 5. Which item was the most popular for each customer?

WITH
	most_popular_product AS(
		SELECT 
			sales.customer_id,
			sales.product_id, 
			COUNT(sales.product_id) AS order_count,
			rank() over(partition by sales.customer_id order by COUNT(sales.product_id) desc) as ranking
		FROM 
			dannys_diner.sales 
		GROUP BY 
			sales.customer_id, sales.product_id
	)
SELECT 
	customer_id,
    product_id,
    order_count
FROM most_popular_product
WHERE
	ranking = 1;
    
-- 6. Which item was purchased first by the customer after they became a member?

WITH
	purchased_items_ranked_after_membership AS(
		SELECT 
			sales.customer_id,
			sales.product_id,
			sales.order_date,
			rank() over(partition by sales.customer_id order by sales.order_date asc) as ranking
		FROM 
			dannys_diner.members
		left join
			dannys_diner.sales 
		ON 
			members.customer_id = sales.customer_id
		WHERE
			sales.order_date >= members.join_date
	)
SELECT 
	customer_id,
    product_id,
    order_date
FROM purchased_items_ranked_after_membership
WHERE
	ranking = 1;
    
    
-- 7. Which item was purchased just before the customer became a member?

WITH
	purchased_items_ranked_before_membership AS(
		SELECT
			sales.customer_id,
			sales.product_id,
			sales.order_date,
			rank() over(partition by sales.customer_id order by sales.order_date desc) as ranking
		FROM
			dannys_diner.sales
			LEFT JOIN dannys_diner.members ON sales.customer_id = members.customer_id
		WHERE
			members.customer_id IS NULL OR sales.order_date < members.join_date
	)
SELECT 
	customer_id,
    product_id,
    order_date
FROM purchased_items_ranked_before_membership
WHERE
	ranking = 1;


-- 8. What is the total items and amount spent for each member before they became a member?

SELECT
	sales.customer_id,
    SUM(menu.price) AS Total_spent
FROM
	dannys_diner.sales
	LEFT JOIN dannys_diner.members ON sales.customer_id = members.customer_id
    LEFT JOIN dannys_diner.menu ON sales.product_id = menu.product_id
WHERE
	members.customer_id IS NULL OR sales.order_date < members.join_date
GROUP By sales.customer_id;

-- 9. If each $1 spent equates to 10 points and sushi has a 2x points multiplier - how many points would each customer have?

WITH
	points_table AS (
		SELECT *, 
			CASE WHEN menu.product_name = 'sushi' THEN menu.price * 20
			ELSE menu.price * 10 END AS points
		FROM dannys_diner.menu
    )
SELECT 
	sales.customer_id, 
    SUM(points) AS total_points
FROM 
	dannys_diner.sales 
	JOIN points_table ON sales.product_id = points_table.product_id
GROUP BY sales.customer_id;


-- 10. In the first week after a customer joins the program (including their join date) they earn 2x points on all items, 
-- not just sushi - how many points do customer A and B have at the end of January?

-- Tips
	-- 1. Find member validity date of each customer and get last date of January
	-- 2. Use CASE WHEN to allocate points by date and product id
	-- 3. SUM price and points


-- Detailed

WITH datetime_cte AS(
	SELECT *, 
		DATE_ADD(members.join_date, INTERVAL 6 DAY) AS valid_date, 
		LAST_DAY('2021-01-31') AS last_date
	FROM dannys_diner.members
)
SELECT 
	sales.customer_id,
	menu.product_name,
	sales.order_date,
    COUNT(sales.customer_id) * menu.price,
    datetime_cte.join_date,
    datetime_cte.valid_date,
    datetime_cte.last_date,
    SUM(CASE WHEN menu.product_name = 'sushi' THEN 2 * 10 * menu.price
		 WHEN sales.order_date BETWEEN datetime_cte.join_date AND datetime_cte.valid_date THEN 2 * 10 * menu.price
	ELSE 10 * menu.price END) AS total_points
FROM
	dannys_diner.sales
	RIGHT JOIN datetime_cte ON sales.customer_id = datetime_cte.customer_id
    LEFT JOIN dannys_diner.menu ON sales.product_id = menu.product_id    
WHERE
	sales.order_date < datetime_cte.last_date
GROUP BY 
	datetime_cte.customer_id, menu.product_name, sales.order_date, menu.price, datetime_cte.join_date, datetime_cte.valid_date, datetime_cte.last_date;
    
    
-- Answer

WITH datetime_cte AS(
	SELECT *, 
		DATE_ADD(members.join_date, INTERVAL 6 DAY) AS valid_date, 
		LAST_DAY('2021-01-31') AS last_date
	FROM dannys_diner.members
)
SELECT 
	sales.customer_id,
    SUM(CASE WHEN menu.product_name = 'sushi' THEN 2 * 10 * menu.price
		 WHEN sales.order_date BETWEEN datetime_cte.join_date AND datetime_cte.valid_date THEN 2 * 10 * menu.price
	ELSE 10 * menu.price END) AS total_points,
    SUM(price) as total_price
FROM
	dannys_diner.sales
	RIGHT JOIN datetime_cte ON sales.customer_id = datetime_cte.customer_id
    LEFT JOIN dannys_diner.menu ON sales.product_id = menu.product_id    
WHERE
	sales.order_date < datetime_cte.last_date
GROUP BY 
	datetime_cte.customer_id;


