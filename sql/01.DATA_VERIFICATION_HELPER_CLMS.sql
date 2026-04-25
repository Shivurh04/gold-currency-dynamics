-- Verifying the imported data
select count(*) as row_count
from gold_master;

-- Check date range
select 
	min(date) as earliest,
	max(date) as latest,
	count(*) as total_months
from gold_master;

-- Check for nulls in each columns
select 
	count(*) as total_rows,
	count(date) as dates,
	count(price_usd) as has_usd_price,
	count(inr_per_usd) as has_inr_price,
	count(gold_price_inr) as has_gold_inr,
	count(fed_intrest_rate) as has_fed_intrest,
	count(inflation_yoy) as has_inflation_yoy,
	count(gold_return_1d) as has_gold_return_1d,
	count(inr_change_1d) as has_inr_change,
	count(gold_inr_return_1d) as has_gold_inr_return
from gold_master;

-- Quick data snapshot
select *
from gold_master
order by date desc
limit 10;


-- Adding helper columns
-- Adding year, month column for easier groupings
ALTER TABLE gold_master ADD COLUMN year INT;
ALTER TABLE gold_master ADD COLUMN month INT;
ALTER TABLE gold_master ADD COLUMN month_name VARCHAR(3);

-- Updating year, month & month_name columns with actual data
UPDATE gold_master SET
	year = EXTRACT(YEAR FROM date),
	month = EXTRACT(MONTH FROM date),
	month_name = TO_CHAR(date, 'Mon');

-- Verifying the year, month and month_name
select *
from gold_master
limit 13;







