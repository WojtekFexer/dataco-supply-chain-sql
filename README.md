# DataCo Supply Chain: orders and deliveries analysis in SQL

My first project on a raw, messy dataset. I wanted to go through the whole process on my own: import the file, check the data, clean it, ask business questions and write down what the data actually shows.

This is a learning project. I don't have commercial experience as an analyst yet, but I worked for about 8 years in manufacturing and logistics (Scania, DHL Supply Chain), so orders, shipping and warehouse data are close to what I know from the shop floor.

**Tools:** PostgreSQL, DBeaver, psql

---

## Key findings

- **Late delivery rates say more about the plan than about the delivery.** Every shipping mode has a fixed planned time. First Class is late in 100% of items because the plan is 1 day and the real time is always 2.
- **Market ranking mostly reflects how long each market was active.** Markets appear in blocks of months, not continuously. Total profit per day stays roughly the same no matter how many markets are active.
- **About 19% of items are sold at a loss, in almost every category.** Losses follow volume, not one "bad" category.
- **Discounts don't create more loss-making items.** They lower the profit on profitable items (from about $60 to about $45 at a 25% discount).
- **Customer segments differ in size, not in value.** Profit per customer is almost the same in every segment ($182–189).

The data looks synthetic (more on that below), so these are conclusions about this dataset, not about a real business.

---

## Dataset

[DataCo Smart Supply Chain for Big Data Analysis](https://www.kaggle.com/datasets/shashwatwork/dataco-smart-supply-chain-for-big-data-analysis) from Kaggle.

| | |
|---|---|
| Rows | 180,519 (one row = one order item) |
| Columns | 53 in the raw file, 45 after cleaning |
| Orders | 65,752 |
| Period | Jan 2015 – Jan 2018 |

The data file is not included in this repo. You need to download it from Kaggle.

---

## What I did

1. **Import.** Loaded the raw CSV into a `raw` table with every column as text, so nothing gets lost or converted wrongly on the way in.
2. **Audit.** Checked missing values, extra spaces, data grain, categorical values, logical consistency and date formats.
3. **Cleaning.** Built a `clean` table with proper data types, trimmed text, removed useless columns and added a few helper columns (`delay_days`, `is_cancelled`).
4. **Analysis.** Answered 5 business questions. Cancelled items are excluded from all of them.
5. **Checks.** Every result is reconciled with known totals (see [How I checked my results](#how-i-checked-my-results)).

---

## Data issues I found

| # | Problem | What I did |
|---|---|---|
| 1 | `product_description` 100% empty, `order_zipcode` ~86% empty, email and password masked | Removed |
| 2 | Trailing spaces in `product_name` (1,774), `category_name` (1,475), `customer_street` (1,829), `product_image` (886) | `TRIM` on all text columns |
| 3 | Dates stored as text (`M/D/YYYY HH:MI`), plain `CAST` failed | `TO_TIMESTAMP` with an explicit format |
| 4 | 5 duplicated columns and `product_status` with only one value (0) | Kept one column from each pair, removed the rest |
| 5 | 7,754 cancelled items still have delivery days filled in (4,423 of them counted as "late") | Added an `is_cancelled` flag and excluded them from analysis |
| 6 | 391 customers have only cancelled items | They drop out together with cancelled items |
| 7 | `delivery_status` and `late_delivery_risk` are calculated from a fixed plan per shipping mode | Didn't compare shipping modes by late rate alone |
| 8 | `customer_country` has only 2 values, `order_country` has 164 values in Spanish | Used `market` and `order_region` instead |
| 9 | "Electronics" has two different `category_id` values (two departments) | Grouped by name, noted the difference |
| 10 | Markets have data in blocks of months (61 market-months out of 185 possible) | Month-over-month only inside blocks, no year-over-year |
| 11 | Data looks synthetic: fixed plans, even group sizes, ~1 item per order from Oct 2017 instead of ~3 | No conclusions about real business behaviour |
| 12 | 18.7% of items have negative profit, and I don't know how profit is calculated | Left as is |

---

## Questions and findings

### 1. Which shipping mode has the highest share of late deliveries?

| Shipping mode | Planned days | Late items |
|---|---|---|
| First Class | 1 | 100.00% |
| Second Class | 2 | 79.83% |
| Same Day | 0 | 47.93% |
| Standard Class | 4 | 39.77% |

The planned time is the same for every order within a mode. First Class always takes exactly 2 days against a plan of 1, so it is always late. The late rate shows how the plan was set, not how good the delivery was.

### 2. Which market brings the most profit, and how does it change month to month?

Europe has the highest total profit ($1.13M), then LATAM ($1.07M) and Pacific Asia ($0.83M).

But when I checked month by month, no market has sales in every month. They show up in blocks, and sometimes only one market is active at a time. Total profit per day stays at a similar level whether 1 or 5 markets are active. So the ranking mostly shows how long each market was active. A fairer comparison would be profit per active day.

Some extreme month-over-month changes (from −98% to +3,571%) come from incomplete months, for example a month with only one day of data.

### 3. Are losses concentrated in a few categories?

No. About 19% of items are sold at a loss, and in most categories it's between 15% and 20%. The categories with the biggest losses are simply the ones that sell the most. No category has negative total profit. Overall, losses equal about half of the profit from profitable items.

### 4. Do discounts increase losses?

There are 18 discount levels from 0% to 25%, each with about 9,600 items.

| | 0% discount | 25% discount |
|---|---|---|
| Share of loss-making items | ~18–19% | ~18–19% |
| Avg profit on profitable items | $60.39 | $45.15 |
| Avg item price | ~$141 | ~$141 |

Discounts don't change how many items lose money. They reduce how much the profitable items earn.

### 5. Which customer segment brings the most profit?

Consumer brings the most profit, but only because it has the most customers. Profit per customer is almost the same in every segment ($182–189). Each customer belongs to exactly one segment (checked).

---

## How I checked my results

I tried not to trust any number until it matched something I already knew:

- after import: 180,519 rows in every key column
- after cleaning: 65,752 orders, 7,754 cancelled items, 45 columns, primary key on `order_item_id`
- every analysis query sums back to 172,765 non-cancelled items and $3,806,420.63 total profit
- late items in Q1 add up to the 98,977 "Late" items found in the audit
- `days_for_shipping_real` matches the difference between shipping date and order date in all rows

---

## SQL I used

CTEs, window functions (`LAG` with `PARTITION BY`), `FILTER`, `CASE`, `NULLIF`, `DATE_TRUNC`, `TO_TIMESTAMP`, `INTERVAL`, `GROUP BY` / `HAVING`, `EXCEPT`, `information_schema`

---

## Repository structure

```
01_setup_import.sql   – database, raw table, import
02_audit.sql          – data quality checks
03_clean.sql          – clean table and checks after cleaning
04_questions.sql      – the 5 business questions
```

## How to run

1. Download the CSV from Kaggle.
2. Create the database and schema (`01_setup_import.sql`).
3. Import with `\copy` in psql (not the DBeaver importer – it matches columns by name and broke my import):
   ```
   \copy logistics.raw FROM 'path/to/DataCoSupplyChainDataset.csv' WITH (FORMAT csv, HEADER true, ENCODING 'LATIN1')
   ```
   Expected result: `COPY 180519`
4. Run the remaining files in order, section by section.

---

## What's next

- An Excel report with the three most useful findings
- A Power BI dashboard on the same data

---

**Wojciech Fexer** · [LinkedIn](https://www.linkedin.com/in/wojtek-fexer) · wojjok123@gmail.com
