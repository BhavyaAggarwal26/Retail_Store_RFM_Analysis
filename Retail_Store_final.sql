###############################################################################################################################################
##################################################  Retail Store Analysis  ####################################################################
###############################################################################################################################################

-- Data Source --
-- This retail store dataset was provided as part of an AnalytixLabs certification assessment (2022).
-- This project extends beyond that coursework with RFM-based customer segmentation, store-type x
-- category analysis, time-based trends, and a documented data quality investigation.

-- Assumptions --
-- 1. Gross revenue = sum(total_amt) where Qty >= 1 (purchases only, returns excluded)
--    Net revenue   = sum(total_amt) across all rows (returns reduce revenue automatically, since
--                     return rows carry negative total_amt)
-- 2. All date-relative calculations (recency, age) are anchored to MAX(tran_date) in the dataset,
--    not the current system date, since this is a historical/static dataset.
-- 3. total_amt is treated as the source of truth for revenue. On return rows, both Qty and Rate
--    are stored as negative, which makes Qty*Rate+Tax inconsistent with total_amt on those rows
--    (see validation query below). total_amt is therefore used directly rather than recomputed.
-- 4. RFM Recency and Frequency are computed on purchase rows only (Qty >= 1); Monetary uses net
--    spend (all rows, including returns), since it should reflect true financial contribution.
-- 5. 8 cust_id values in transactions have no matching record in the customer table (orphans).
--    These are retained in revenue/store-type analysis but excluded from customer-level and
--    demographic analysis, since no customer attributes exist for them.
-- 6. Demographic fields (DOB, age, city_code, Gender) show distribution patterns consistent with
--    synthetic generation rather than real customer data (see note before Demographics section).
--    Demographic cross-tabs are included to demonstrate method, not as genuine market insight.

###############################################################################################################################################
-- 1. Setup & Data Type Corrections
###############################################################################################################################################

use Retail_Store_Analysis;

select tran_date,
       str_to_date(replace(tran_date, '/', '-'), '%d-%m-%Y') as converted_date
from transactions;

set sql_safe_updates = 0;

update transactions
set tran_date = str_to_date(replace(tran_date, '/', '-'), '%d-%m-%Y');

set sql_safe_updates = 1;

alter table transactions modify column tran_date date;

update customer
set DOB = str_to_date(DOB, '%d-%m-%Y');

alter table customer modify column DOB date;

###############################################################################################################################################
-- 2. Data Quality Checks
###############################################################################################################################################

-- Cross join row count -- documented as a "why not to do this", not a real query to use
select count(*) from (transactions, customer, prod_cat_info);

-- Proper join row count check, for comparison
select count(*) from transactions t
left join customer c
    on t.cust_id = c.customer_id
left join prod_cat_info p
    on t.prod_subcat_code = p.prod_sub_cat_code
    and t.prod_cat_code = p.prod_cat_code;

-- Number of records in each table
select 'Customer' as table_name, count(*) as record_count from customer
union all
select 'Transactions', count(*) from transactions
union all
select 'prod_cat_info', count(*) from prod_cat_info;

-- Blank gender check
select count(*) as blank_gender_count from customer where Gender = "";

-- Qty = 0 check (confirms return-rate logic using Qty < 1 is safe)
select * from transactions where Qty = 0;

-- Rate/Qty sign validation: does total_amt reconcile with Qty*Rate+Tax?
-- (It won't on return rows, since Rate is also negated there -- see Assumption 3)
select count(*) as mismatched_rows
from transactions
where round(Qty * Rate + Tax, 2) <> round(total_amt, 2);

-- Orphan customers: cust_id present in transactions but missing from customer table
select count(distinct cust_id) as distinct_cust_in_transactions from transactions;
select count(distinct customer_Id) as distinct_cust_in_customer_table from customer;

select t.cust_id from transactions t
left join customer c on t.cust_id = c.customer_Id
where c.customer_Id is null;

###############################################################################################################################################
-- 3. Descriptive Stats
###############################################################################################################################################

-- % returns of total transactions
select sum(case when Qty < 1 then 1 else 0 end) * 100.0 / count(*) as return_rate
from transactions;

-- Time range of the data
select distinct year(tran_date) as years from transactions;

-- Note: this approach is flawed when min/max don't align across year boundaries -- kept only to
-- document why TIMESTAMPDIFF below is the correct method, not as a trusted result
select
    year(max(tran_date)) - year(min(tran_date)) as years,
    month(max(tran_date)) - month(min(tran_date)) as months,
    day(max(tran_date)) - day(min(tran_date)) as days
from transactions;

select
    timestampdiff(day, min(tran_date), max(tran_date)) as days,
    timestampdiff(month, min(tran_date), max(tran_date)) as months,
    timestampdiff(year, min(tran_date), max(tran_date)) as years
from transactions;

-- Highest selling category -- by transaction frequency (most frequently transacted)
select * from (
    select p.prod_cat, count(t.prod_cat_code) as txn_count
    from transactions t
    left join prod_cat_info p
        on t.prod_cat_code = p.prod_cat_code
        and t.prod_subcat_code = p.prod_sub_cat_code
    where t.Qty >= 1
    group by p.prod_cat
) a
order by txn_count desc
limit 1;

-- Highest revenue generating category
select * from (
    select p.prod_cat, round(sum(t.total_amt)) as gross_revenue
    from transactions t
    left join prod_cat_info p
        on t.prod_cat_code = p.prod_cat_code
        and t.prod_subcat_code = p.prod_sub_cat_code
    where t.Qty >= 1
    group by p.prod_cat
) a
order by gross_revenue desc;

###############################################################################################################################################
-- 4. Store Type x Category Analysis
###############################################################################################################################################

select store_type, round(sum(total_amt)) as gross_sales      -- total gross sales by each store
from transactions
where Qty >= 1
group by store_type;

select store_type, round(sum(total_amt)) as net_sales        -- total net sales by each store
from transactions
group by store_type;

select store_type, round(avg(total_amt)) as avg_sales        -- avg transaction value by each store
from transactions
group by store_type;

select store_type, count(*) as total_txn                     -- total number of transactions at each store
from transactions
group by store_type;

select store_type,
       round(sum(case when Qty < 1 then 1 else 0 end) * 100.00 / count(*), 2) as return_rate   -- return rate by store
from transactions
group by store_type;

select t.store_type, p.prod_cat, p.prod_subcat,
       round(sum(total_amt)) as net_sales                    -- store x category cross-tab (net sales)
from transactions t
left join prod_cat_info p
    on t.prod_cat_code = p.prod_cat_code
    and t.prod_subcat_code = p.prod_sub_cat_code
group by t.store_type, p.prod_cat, p.prod_subcat;

select store_type, round(sum(total_amt)) as net_revenue      -- highest net revenue generating store
from transactions
group by store_type
order by net_revenue desc
limit 1;

###############################################################################################################################################
-- 5. Customer Analysis / RFM Segmentation
###############################################################################################################################################

-- One-time vs repeat customers (purchase rows only)
select count(case when tran_count = 1 then 1 end) as one_time_customers,
       count(case when tran_count > 1 then 1 end) as repeat_customers
from (
    select cust_id, count(cust_id) as tran_count
    from transactions
    where Qty >= 1
    group by cust_id
) a;

-- Sanity check: how many customers have negative or zero net spend?
select
    sum(case when net_spend < 0 then 1 else 0 end) as negative_spend_customers,
    sum(case when net_spend = 0 then 1 else 0 end) as zero_spend_customers,
    count(*) as total_customers
from (
    select cust_id, sum(total_amt) as net_spend
    from transactions
    group by cust_id
) a;

with recency as (
    select cust_id,
           datediff((select max(tran_date) from transactions), max(tran_date)) as recency_days
    from transactions
    where Qty >= 1
    group by cust_id
),

frequency as (
    select cust_id, count(transaction_id) as frequency
    from transactions
    where Qty >= 1
    group by cust_id
),

monetary as (
    select cust_id, round(sum(total_amt), 2) as net_spend
    from transactions
    group by cust_id
),

rfm_score as (
    select r.cust_id, r.recency_days, f.frequency, m.net_spend,
           ntile(5) over (order by r.recency_days desc) as recency_score,
           ntile(5) over (order by f.frequency) as frequency_score,
           ntile(5) over (order by m.net_spend) as monetary_score
    from recency r
    join frequency f on r.cust_id = f.cust_id
    join monetary m on r.cust_id = m.cust_id
),

rfm_final as (
    select cust_id, recency_days, frequency, net_spend,
           recency_score, frequency_score, monetary_score,
           concat(recency_score, frequency_score, monetary_score) as rfm_code,
           case
               when net_spend <= 0 then "Net negative / high returns"
               when recency_score >= 4 and frequency_score >= 4 and monetary_score >= 4 then "Champion customer"
               when recency_score >= 3 and frequency_score >= 3 and monetary_score >= 3 then "Loyal customer"
               when recency_score >= 4 and frequency_score <= 2 and monetary_score <= 3 then "New customer"
               when recency_score <= 2 and (frequency_score >= 4 or monetary_score >= 4) then "At risk customer"
               when recency_score <= 2 and frequency_score <= 2 and monetary_score <= 2 then "Lost customer"
               else "Needs attention"
           end as rfm_segment
    from rfm_score
)

select *, round((customer_count / 5645) * 100) as pct_of_customers from (
    select rfm_segment, count(*) as customer_count,
           round(avg(net_spend)) as avg_net_spend
    from rfm_final
    group by rfm_segment
    order by customer_count desc
) a;

###############################################################################################################################################
-- 6. Demographics Layer
###############################################################################################################################################

-- Age calculation (anchored to max(tran_date), per Assumption 2)
select customer_Id, DOB,
       timestampdiff(year, DOB, (select max(tran_date) from transactions)) as age
from customer;

select timestampdiff(year, DOB, (select max(tran_date) from transactions)) as age,
       count(*) as cust_count
from customer
group by age
order by age;

-- Birth year distribution (used to detect the sequential DOB pattern)
select year(DOB) as birth_year, count(*) as customer_count
from customer
group by birth_year
order by birth_year;

-- Revenue distribution by gender (orphans and blanks handled explicitly)
select
    case
        when c.customer_Id is null then "No customer record"
        when c.Gender is null or c.Gender = "" then "Unknown/Blank"
        else c.Gender
    end as gender_group,
    round(sum(t.total_amt)) as net_revenue
from transactions t
left join customer c on t.cust_id = c.customer_Id
group by gender_group
order by net_revenue desc;

select Gender, count(*) as cust_count from customer group by Gender;

-- City code distribution (used to detect synthetic near-uniform spread)
select city_code, count(city_code) as code_count
from customer
group by city_code
order by code_count;

/*  Data Limitation -- Demographic Fields:
    DOB, city_code, and Gender all show distribution patterns consistent with
    synthetic/random generation rather than real-world customer demographics:
    - DOB values are sequentially assigned across 1970-1992
    - Derived age shows a near-uniform spread (215-271 customers per age-year)
    - city_code is near-evenly split across all 10 codes (520-590 each)
    - Gender is close to a 50/50 split
    Demographic cross-tabs are included to demonstrate analytical technique,
    but are not presented as genuine market insights.
*/

###############################################################################################################################################
-- 7. Time-Based Trends
###############################################################################################################################################

-- Monthly revenue trend
select year(tran_date) as years, month(tran_date) as month_num, monthname(tran_date) as months,
       round(sum(total_amt)) as net_revenue
from transactions
group by years, month_num, months
order by years, month_num;

select year(tran_date) as years, month(tran_date) as month_num, monthname(tran_date) as months,
       round(sum(total_amt)) as gross_revenue
from transactions
where Qty >= 1
group by years, month_num, months
order by years, month_num;

-- Quarterly revenue trend
select year(tran_date) as years, quarter(tran_date) as quarters,
       round(sum(total_amt)) as net_revenue
from transactions
group by years, quarters
order by years, quarters;

select year(tran_date) as years, quarter(tran_date) as quarters,
       round(sum(total_amt)) as gross_revenue
from transactions
where Qty >= 1
group by years, quarters
order by years, quarters;

-- Day of week pattern
select dayname(tran_date) as day_name, round(sum(total_amt)) as net_revenue
from transactions
group by day_name
order by field(day_name, 'Monday','Tuesday','Wednesday','Thursday','Friday','Saturday','Sunday');

select dayname(tran_date) as day_name, round(sum(total_amt)) as gross_revenue
from transactions
where Qty >= 1
group by day_name
order by field(day_name, 'Monday','Tuesday','Wednesday','Thursday','Friday','Saturday','Sunday');

-- Return rate trend over time
select year(tran_date) as years, month(tran_date) as month_num, monthname(tran_date) as months,
       sum(case when Qty < 1 then 1 else 0 end) * 100.00 / count(*) as return_rate
from transactions
group by years, month_num, months
order by years, month_num;