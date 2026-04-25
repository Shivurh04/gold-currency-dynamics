-- Creating table
CREATE TABLE gold_master (
	date DATE PRIMARY KEY,
	price_usd DECIMAL (10,2),
	inr_per_usd DECIMAL (10,4),
	gold_price_inr DECIMAL (14,2),
	fed_intrest_rate DECIMAL (5,2),
	inflation_yoy DECIMAL (8,5),
	gold_return_1d DECIMAL (10,6),
	inr_change_1d DECIMAL (10,6),
	gold_inr_return_1d DECIMAL (10,6)
)	