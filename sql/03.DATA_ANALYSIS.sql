select *
from gold_master;

-- Query 1: Annual Returns — The Currency Effect
with ranked as (
	select *,
		row_number() over(partition by year order by date) as rn_asc,
		row_number() over(partition by year order by date desc) rn_desc
	from gold_master
),
grouped as (
	select year,
		max(case when rn_asc = 1 then price_usd end) as open_usd,
		max(case when rn_desc = 1 then price_usd end) as close_usd,
		max(case when rn_asc = 1 then gold_price_inr end) as open_gold_inr,
		max(case when rn_desc = 1 then gold_price_inr end) as close_gold_inr,
		max(case when rn_asc = 1 then inr_per_usd end) as open_inr,
		max(case when rn_desc = 1 then inr_per_usd end) as close_inr
	from ranked
	group by year
)
select year,
	round(open_usd, 2) as open,
	round(close_usd, 2) as close,
	round((close_usd - open_usd)/open_usd * 100, 2) as return_pct_usd,
	round((close_gold_inr - open_gold_inr)/open_gold_inr * 100, 2) as return_pct_inr,
	round(((close_inr - open_inr)/open_inr * 100 - 
		(close_usd - open_usd)/open_usd * 100), 2) as currency_effect_pct,
	round(open_inr, 2) as open_inr,
	round(close_inr, 2) as close_inr,
	round((close_inr - open_inr)/open_inr * 100, 2) as currency_deprication_pct
from grouped;


-- Query 2: Cumulative Gold Returns Over Time (Running Total)
with base as (
	select date, year, price_usd, gold_price_inr,
		(price_usd/first_value(price_usd) over(order by date)) as gold_growth_usd,
		(gold_price_inr/first_value(gold_price_inr) over(order by date)) as gold_growth_inr
	from gold_master
)
select date, year, price_usd, gold_price_inr,
	round(gold_growth_usd * 1000, 2) as value_of_1k_usd,
	round(gold_growth_inr * 1000, 2) as value_of_1k_inr
 from base;

-- Query 2: Fed Rate Impact on Gold
with rate_changes as (
	select date,
		fed_intrest_rate,
		lag(fed_intrest_rate) over(order by date) as prev_fed_intrest_rate,
		fed_intrest_rate - lag(fed_intrest_rate) over(order by date) rate_change,
		gold_return_1d,
		gold_inr_return_1d,
		inr_change_1d
	from gold_master
	where fed_intrest_rate is not null
)
select 
	case
		when rate_change > 0 then 'Rate Hike'
		when rate_change < 0 then 'Rate Cut'
		else 'No change'
	end as rate_category, 
	count(*) as months, 
	round(avg(gold_return_1d), 2) as avg_gold_usd_return, 
	round(avg(gold_inr_return_1d), 2) as avg_gold_inr_return,
	round(avg(inr_change_1d), 2) as avg_currency_movement
from rate_changes
where prev_fed_intrest_rate is not null 
group by 
	case
		when rate_change > 0 then 'Rate Hike'
		when rate_change < 0 then 'Rate Cut'
		else 'No change'
	end
order by avg_gold_usd_return desc;


--Query 4: Best and Worst Months — Seasonality
select month, month_name,
	round(avg(gold_return_1d), 2) as avg_gold_return_usd,
	round(avg(gold_inr_return_1d), 2) as avg_gold_return_inr,
	round(avg(inr_change_1d), 2) as avg_inr_change,
	round(min(gold_inr_return_1d), 2) as worst_ever,
	round(max(gold_inr_return_1d), 2) as best_ever,
	sum(case when gold_inr_return_1d > 0 then 1 else 0 end) as positive_months,
	round(sum(case when gold_inr_return_1d > 0 then 1 else 0 end)::numeric/count(*)::numeric * 100, 1) as pct_change
from gold_master
where gold_inr_return_1d is not null
group by month, month_name
order by pct_change desc;


-- Query 5: Gold as Inflation Hedge 
select 
	case
		when inflation_yoy >= 6 then 'Very High(6%+)'
		when inflation_yoy >= 4 then 'High(4-6%)'
		when inflation_yoy >= 2 then 'Medium(2-4%)'
		when inflation_yoy >= 0 then 'Low(0-2%)'
		else 'Deflation(<0%)'
	end as inflation_cat,
	round(avg(inflation_yoy), 2) avg_inflation,
	round(avg(gold_return_1d), 2) as avg_gold_usd,
	round(avg(gold_inr_return_1d), 2) as avg_gold_inr,
	round(avg(inr_change_1d), 2) as avg_inr_change
from gold_master
where inflation_yoy is not null
group by 
	case
		when inflation_yoy >= 6 then 'Very High(6%+)'
		when inflation_yoy >= 4 then 'High(4-6%)'
		when inflation_yoy >= 2 then 'Medium(2-4%)'
		when inflation_yoy >= 0 then 'Low(0-2%)'
		else 'Deflation(<0%)'
	end
order by 2 desc;

-- Query 6: Decade-by-Decade Comparison
with decade_data as (
	select *,
		case
			when year between 1978 and 1989 then '1978-1989'
			when year between 1990 and 1999 then '1990-1999'
			when year between 2000 and 2009 then '2000-2009'
			when year between 2010 and 2019 then '2010-2019'
			else '2020-current'
		end as decade
	from gold_master
)
select 
	decade,
	count(*) as total_months,
	round(avg(price_usd), 2) as gold_price_usd,
	round(avg(gold_price_inr), 2) as gold_price_inr, 
	round(avg(gold_return_1d), 2) as avg_gold_return_usd,
	round(avg(gold_inr_return_1d), 2) as avg_gold_return_inr,
	round(avg(inr_change_1d), 2) as avg_inr_change
from decade_data
group by decade
order by decade;

-- Query 7: Top 10 Best and Worst Months Ever
(
	select 'BEST' as category,
		date, year, month_name,
		round(gold_return_1d, 2) as avg_gold_return_usd,
		round(gold_inr_return_1d, 2) as avg_gold_return_inr,
		round(inr_change_1d, 2) as avg_inr_change
	from gold_master
	where gold_inr_return_1d is not null
	order by avg_gold_return_inr desc
	limit 10
)
union all 
(
	select 'WORST' as category,
		date, year, month_name,
		round(gold_return_1d, 2) as avg_gold_return_usd,
		round(gold_inr_return_1d, 2) as avg_gold_return_inr,
		round(inr_change_1d, 2) as avg_inr_change
	from gold_master
	where gold_inr_return_1d is not null
	order by avg_gold_return_inr
	limit 10
)

-- Query 8: Rolling Correlation — Gold vs Fed Rate
with rolling as (
	select date, year, month_name,
		fed_intrest_rate, gold_return_1d,
		avg(fed_intrest_rate) over(order by date rows between 11 preceding and current row) as avg_fed_12m,
		avg(gold_return_1d) over(order by date rows between 11 preceding and current row) as avg_gold_12m
	from gold_master
	where fed_intrest_rate is not null and gold_return_1d is not null
)
select 
	date, year,
	round(fed_intrest_rate, 2) as fed_rate,
	round(gold_return_1d, 2) as gold_return,
	round(avg_fed_12m, 2) as fed_rolling,
	round(avg_gold_12m, 2) as gold_rolling
from rolling
order by date;

-- Query 9: Investment Simulation — SIP in Gold
with sip as (
	select date, year, month_name,
		gold_price_inr,
		1000 as monthly_investment,
		(1000/gold_price_inr) as units_brought,
		sum(1000/gold_price_inr) over(order by date) as total_units,
		sum(1000) over(order by date) as total_invested
	from gold_master
	--where year >= 2014
)
select date, year, month_name,
	round(gold_price_inr, 2) as gold_inr_price,
	round(units_brought, 2) as total_units_owned,
	round(total_units, 2) as total_units,
	total_invested,
	round((total_units * gold_price_inr), 2) as current_value,
	round((total_units * gold_price_inr - total_invested)/total_invested, 2) as profit_pct
from sip
order by date;
	
-- Query 10: Summary Dashboard Data
select 
	min(date) as start_date,
	max(date) as last_date,
	count(*) as total_months,

	-- Gold price journey
	round((select price_usd from gold_master order by date limit 1), 2) as first_gold_usd,
	round((select price_usd from gold_master order by date desc limit 1), 2) as last_gold_usd,
	round((select gold_price_inr from gold_master order by date limit 1), 2) as first_gold_inr,
	round((select gold_price_inr from gold_master order by date desc limit 1), 2) as last_gold_inr,

	-- Total returns in inr
	round((
		(select gold_price_inr from gold_master order by date desc limit 1) /
		(select gold_price_inr from gold_master order by date limit 1) -1)*100, 2) as total_return_pct_inr,
	-- Total returns in usd
	round((
		(select price_usd from gold_master order by date desc limit 1) /
		(select price_usd from gold_master order by date limit 1) -1)*100, 2) as total_return_pct_usd,
		
	-- Exchange rate journey
	(select inr_per_usd from gold_master order by date limit 1) as first_inr_rate,
	(select inr_per_usd from gold_master order by date desc limit 1) as last_inr_rate,

	-- Averages
	round(avg(fed_intrest_rate), 2) as avg_fed_rate,
	round(avg(inflation_yoy), 2) as avg_inflation
from gold_master;