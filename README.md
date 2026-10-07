# Retail Store Analysis — SQL-Based Customer Segmentation & Store Performance

## Overview

An end-to-end SQL analysis of a retail transactions dataset (~5,600 customers, three relational tables) covering data cleaning, store-type and product-category performance, RFM-based customer segmentation, demographic analysis, and time-based sales trends.

This project goes beyond basic exploratory analysis by including a full RFM (Recency, Frequency, Monetary) customer segmentation model, a documented data quality investigation, and explicit, stated assumptions behind every revenue and segmentation definition used.

## Data Source

The dataset (transactions, customer, and product category tables) was originally provided as part of an AnalytixLabs certification assessment, which supplied a fixed set of specific questions to answer. This project is an independently scoped, self-directed extension built on the same dataset: rather than answering a predetermined question list, it defines its own analytical scope — RFM segmentation, store × category cross-analysis, time trends, and a full data quality investigation — none of which were part of the original assessment.

## Tools Used

- **MySQL (Workbench)** — data cleaning, transformation, and all analytical queries
- **Power BI** — dashboard visualization *(in progress)*

## Database Structure

| Table | Key Columns |
|---|---|
| `transactions` | transaction_id, cust_id, tran_date, prod_cat_code, prod_subcat_code, Qty, Rate, Tax, total_amt, Store_type |
| `customer` | customer_Id, DOB, Gender, city_code |
| `prod_cat_info` | prod_cat_code, prod_cat, prod_sub_cat_code, prod_subcat |

## Key Findings

**Revenue**
- Gross revenue (purchases only): ₹5,44,53,885
- Net revenue (after returns): ₹4,85,79,771
- Returns account for **~10.8% of gross revenue** — a more specific and business-relevant figure than a simple transaction-count return rate.

**Store & Category Performance**
- Store-type × product-category cross-analysis identifies which categories each store type sells most, alongside store-level return rates and average transaction value — not just top-line revenue.

**Customer Segmentation (RFM)**
- Customers segmented into Champion, Loyal, At Risk, New, Lost, Needs Attention, and Net Negative/High Returns groups based on Recency, Frequency (purchase transactions only), and Monetary value (net spend, including returns).
- Notable finding: **At Risk customers show a higher average net spend (₹12,761) than Loyal customers (₹11,348)** — these are historically high-value customers who have gone quiet recently, making win-back campaigns a higher-ROI priority than typical retention efforts for this group.
- A small but financially meaningful segment (84 customers) shows net-negative spend — customers whose returns exceeded their purchases — isolated and flagged separately rather than folded into "Lost."

**Data Quality Investigation**
- Identified that on return transactions, both `Qty` and `Rate` are stored as negative values, making `total_amt` inconsistent with `Qty × Rate + Tax` on a subset of return rows. `total_amt` was used as the source of truth throughout rather than recomputing it.
- Found 8 `cust_id` values in `transactions` with no matching record in `customer` (orphan records) — retained in revenue analysis, excluded from customer-level segmentation.
- Discovered that demographic fields (DOB, derived age, city_code, Gender) show distribution patterns consistent with synthetic/random generation rather than real customer demographics (sequential DOB assignment, near-uniform age and city_code spread, ~50/50 gender split). Documented explicitly; demographic cross-tabs are included to demonstrate method, not presented as genuine market insight.

## Assumptions

| Area | Decision |
|---|---|
| Revenue | Gross = purchases only (Qty ≥ 1); Net = all rows (returns reduce revenue automatically) |
| Reference date | All recency/age calculations anchored to `MAX(tran_date)` in the dataset, not the current date, since the data is historical |
| Return rows | `total_amt` used as source of truth; not recomputed from Qty × Rate due to inconsistent sign handling on returns |
| RFM — Recency & Frequency | Purchase transactions only (Qty ≥ 1) |
| RFM — Monetary | Net spend across all rows (true financial contribution) |
| Orphan customers | Retained in revenue/store analysis; excluded from customer-level and demographic analysis |

## Repository Structure

```
/sql        — full analytical SQL script (cleaning, EDA, RFM, trends)
/dashboard  — Power BI file (coming soon)
/docs       — this README, data dictionary
```

## Status

SQL analysis layer: complete.
Power BI dashboard: in progress.
