-- Creating the Schema and Tables
CREATE SCHEMA dannys_diner;
SET search_path = dannys_diner;

CREATE TABLE sales (
  "customer_id" VARCHAR(1),
  "order_date" DATE,
  "product_id" INTEGER
);

INSERT INTO sales
  ("customer_id", "order_date", "product_id")
VALUES
  ('A', '2021-01-01', '1'),
  ('A', '2021-01-01', '2'),
  ('A', '2021-01-07', '2'),
  ('A', '2021-01-10', '3'),
  ('A', '2021-01-11', '3'),
  ('A', '2021-01-11', '3'),
  ('B', '2021-01-01', '2'),
  ('B', '2021-01-02', '2'),
  ('B', '2021-01-04', '1'),
  ('B', '2021-01-11', '1'),
  ('B', '2021-01-16', '3'),
  ('B', '2021-02-01', '3'),
  ('C', '2021-01-01', '3'),
  ('C', '2021-01-01', '3'),
  ('C', '2021-01-07', '3');
 

CREATE TABLE menu (
  "product_id" INTEGER,
  "product_name" VARCHAR(5),
  "price" INTEGER
);

INSERT INTO menu
  ("product_id", "product_name", "price")
VALUES
  ('1', 'sushi', '10'),
  ('2', 'curry', '15'),
  ('3', 'ramen', '12');
  

CREATE TABLE members (
  "customer_id" VARCHAR(1),
  "join_date" DATE
);

INSERT INTO members
  ("customer_id", "join_date")
VALUES
  ('A', '2021-01-07'),
  ('B', '2021-01-09');
  
-- Checking the tables
select * from members;
select * from menu;
select * from sales;

-- PROBLEM STATEMENTS

-- 1. What is the total amount each customer spent at the restaurant?
SELECT 
    s.customer_id,
    SUM(m.price) AS total_spent
FROM 
    sales s
JOIN 
    menu m ON s.product_id = m.product_id
GROUP BY 
    s.customer_id
ORDER BY 
    total_spent DESC;
	
--2. How many days has each customer visited the restaurant?
SELECT 
    customer_id,
    COUNT(DISTINCT order_date) AS visit_days
FROM 
    sales
GROUP BY 
    customer_id
ORDER BY 
    visit_days DESC;

-- 3. What was the first item from the menu purchased by each customer?
WITH RankedOrders AS (
    SELECT
        s.customer_id,
        s.order_date,
        s.product_id,
        ROW_NUMBER() OVER (PARTITION BY s.customer_id ORDER BY s.order_date) AS rank
    FROM
        sales s
)
SELECT
    ro.customer_id,
    ro.order_date AS first_order_date,
    m.product_name
FROM
    RankedOrders ro
JOIN
    menu m ON ro.product_id = m.product_id
WHERE
    ro.rank = 1
ORDER BY
    ro.customer_id;

-- 4. What is the most purchased item on the menu and how many times was it purchased by all customers?
SELECT
    m.product_name,
    COUNT(s.product_id) AS purchase_count
FROM
    sales s
JOIN
    menu m ON s.product_id = m.product_id
GROUP BY
    m.product_name
ORDER BY
    purchase_count DESC
LIMIT 1;

-- 5. Which item was the most popular for each customer?
WITH CustomerProductCount AS (
    SELECT
        s.customer_id,
        s.product_id,
        m.product_name,
        COUNT(s.product_id) AS purchase_count
    FROM
        sales s
    JOIN
        menu m ON s.product_id = m.product_id
    GROUP BY
        s.customer_id,
        s.product_id,
        m.product_name
),
RankedCustomerProducts AS (
    SELECT
        cpc.customer_id,
        cpc.product_name,
        cpc.purchase_count,
        ROW_NUMBER() OVER (PARTITION BY cpc.customer_id ORDER BY cpc.purchase_count DESC, cpc.product_name) AS rank
    FROM
        CustomerProductCount cpc
)
SELECT
    rcp.customer_id,
    rcp.product_name,
    rcp.purchase_count
FROM
    RankedCustomerProducts rcp
WHERE
    rcp.rank = 1
ORDER BY
    rcp.customer_id;

-- 6. Which item was purchased first by the customer after they became a member?
WITH FirstPurchaseAfterJoin AS (
    SELECT 
        s.customer_id,
        s.product_id,
        m.product_name,
        s.order_date,
        mem.join_date,
        ROW_NUMBER() OVER (PARTITION BY s.customer_id ORDER BY s.order_date) AS purchase_rank
    FROM 
        sales s
    JOIN 
        menu m ON s.product_id = m.product_id
    JOIN 
        members mem ON s.customer_id = mem.customer_id
    WHERE 
        s.order_date >= mem.join_date
)
SELECT 
    customer_id,
    product_name AS first_item_after_join,
    order_date
FROM 
    FirstPurchaseAfterJoin
WHERE 
    purchase_rank = 1;

-- 7. Which item was purchased just before the customer became a member?
WITH EligiblePurchases AS (
    SELECT
        s.customer_id,
        s.order_date,
        s.product_id,
        m.join_date,
        LAG(s.order_date) OVER (PARTITION BY s.customer_id ORDER BY s.order_date) AS prev_order_date
    FROM
        sales s
    JOIN
        members m ON s.customer_id = m.customer_id
    WHERE
        s.order_date < m.join_date
),
LatestPurchases AS (
    SELECT
        ep.customer_id,
        MAX(ep.prev_order_date) AS latest_order_date
    FROM
        EligiblePurchases ep
    GROUP BY
        ep.customer_id
)
SELECT
    lp.customer_id,
    lp.latest_order_date,
    mn.product_name
FROM
    LatestPurchases lp
JOIN
    EligiblePurchases ep ON lp.customer_id = ep.customer_id AND lp.latest_order_date = ep.prev_order_date
JOIN
    menu mn ON ep.product_id = mn.product_id
ORDER BY
    lp.customer_id;

-- 8. What is the total items and amount spent for each member before they became a member?
WITH EligiblePurchases AS (
    SELECT
        s.customer_id,
        s.product_id,
        m.price,
        mb.join_date
    FROM
        sales s
    JOIN
        menu m ON s.product_id = m.product_id
    JOIN
        members mb ON s.customer_id = mb.customer_id
    WHERE
        s.order_date < mb.join_date
),
Totals AS (
    SELECT
        ep.customer_id,
        COUNT(ep.product_id) AS total_items,
        SUM(ep.price) AS total_amount
    FROM
        EligiblePurchases ep
    GROUP BY
        ep.customer_id
)
SELECT
    mb.customer_id,
    mb.join_date,
    t.total_items,
    t.total_amount
FROM
    members mb
JOIN
    Totals t ON mb.customer_id = t.customer_id
ORDER BY
    mb.customer_id;

-- 9.  If each $1 spent equates to 10 points and sushi has a 2x points multiplier 
-- - how many points would each customer have?
WITH PurchasePoints AS (
    SELECT
        s.customer_id,
        SUM(CASE WHEN m.product_name = 'Sushi' THEN m.price * 2 ELSE m.price END) AS total_spent
    FROM
        sales s
    JOIN
        menu m ON s.product_id = m.product_id
    GROUP BY
        s.customer_id
)
SELECT
    customer_id,
    total_spent * 10 AS total_points
FROM
    PurchasePoints;

-- 10. In the first week after a customer joins the program (including their join date) they earn 2x points 
-- on all items, not just sushi - how many points do customer A and B have at the end of January?
WITH CustomerPoints AS (
    SELECT
        s.customer_id,
        SUM(CASE 
                WHEN s.order_date <= members.join_date + INTERVAL '7' DAY THEN menu.price * 2
                ELSE menu.price 
            END) * 10 AS total_points
    FROM
        sales s
    JOIN
        menu ON s.product_id = menu.product_id
    JOIN
        members ON s.customer_id = members.customer_id
    WHERE
        s.order_date <= '2024-01-31' -- End of January
    GROUP BY
        s.customer_id
)
SELECT
    customer_id,
    total_points
FROM
    CustomerPoints;

-- CUSTOMER LOYALTY ON THE BASIS OF MEMBERSHIP
SELECT
    s.customer_id,
    s.order_date,
    m.product_name,
    m.price,
    CASE
        WHEN s.order_date >= members.join_date THEN 'Yes'
        ELSE 'No'
    END AS is_member
FROM
    sales s
JOIN
    menu m ON s.product_id = m.product_id
LEFT JOIN
    members ON s.customer_id = members.customer_id;

-- CUSTOMER RANKING[ONLY MEMBERS]
WITH RankedSales AS (
    SELECT
        s.customer_id,
        s.order_date,
        m.product_name,
        m.price,
        RANK() OVER(PARTITION BY s.customer_id ORDER BY s.order_date) AS ranking
    FROM
        sales s
    JOIN
        menu m ON s.product_id = m.product_id
    LEFT JOIN
        members mb ON s.customer_id = mb.customer_id
    WHERE
        mb.customer_id IS NOT NULL -- Exclude non-member purchases
)
SELECT
    customer_id,
    order_date,
    product_name,
    price,
    CASE
        WHEN customer_id IS NULL THEN NULL -- Set ranking to NULL for non-member purchases
        ELSE ranking
    END AS ranking
FROM
    RankedSales;

-- CUSTOMER RANKING[ADDING NON MEMBERS]
WITH MemberShip as (
SELECT
    s.customer_id,
    s.order_date,
    m.product_name,
    m.price,
    CASE
        WHEN s.order_date >= members.join_date THEN 'Yes'
        ELSE 'No'
    END AS is_member
FROM
    sales s
JOIN
    menu m ON s.product_id = m.product_id
LEFT JOIN
    members ON s.customer_id = members.customer_id
)
select *,
case is_member
		when 'Yes' then RANK() OVER(PARTITION BY customer_id, is_member ORDER BY order_date)
		else NULL
end as ranking
from MemberShip

-- THANK YOU