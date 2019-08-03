TRUNCATE adjusted_price;
INSERT INTO adjusted_price(
    isin, p_date, adjusted_close, adjusted_shares, adjusted_mkt_val, p_date_prev
)
SELECT  p.isin, p.p_date,
		p.p_price * split.split_factor * spinoff.spinoff_factor,
		p.p_com_shs_out / split.split_factor / spinoff.spinoff_factor,
		p.p_price * p.p_com_shs_out,
		case
			when extract(isodow from p.p_date-interval '1 day')=6 then date(p.p_date-interval '2 day')
			when extract(isodow from p.p_date-interval '1 day')=7 then date(p.p_date-interval '3 day')
			else date(p.p_date-interval '1 day')
		end
FROM
    price p
	LEFT join lateral (
		select COALESCE(exp(sum(ln(splits.p_split_factor))),1) as split_factor
		from splits
		where splits.isin = p.isin and splits.p_split_date>p.p_date
	) as split on true
	LEFT join lateral (
		select max(divs.p_divs_exdate) as exdate, sum(divs.p_divs_pd) as divs
		from dividends divs 
		where divs.isin = p.isin and divs.p_divs_exdate>p.p_date and divs.p_divs_s_pd=1
	) divs on true
	LEFT join lateral (
		select p1.p_price as prev_price
		from price p1
		where p1.p_date<divs.exdate and p1.isin=p.isin
		order by p1.p_date desc fetch first 1 row only
	) prev on true
	LEFT join lateral (
		select case 
			when (prev.prev_price-divs) <= 0 or prev.prev_price is null then 1
			else (prev.prev_price-divs)/prev.prev_price 
			end as spinoff_factor
	) spinoff on true;