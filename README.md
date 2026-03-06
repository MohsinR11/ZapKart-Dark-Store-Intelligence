# 🛒 ZapKart Dark Store Operations Intelligence

![Python](https://img.shields.io/badge/Python-3776AB?style=for-the-badge&logo=python&logoColor=white)
![PostgreSQL](https://img.shields.io/badge/PostgreSQL-316192?style=for-the-badge&logo=postgresql&logoColor=white)
![Power BI](https://img.shields.io/badge/Power%20BI-F2C811?style=for-the-badge&logo=powerbi&logoColor=black)
![Excel](https://img.shields.io/badge/Microsoft%20Excel-217346?style=for-the-badge&logo=microsoft-excel&logoColor=white)
![Jupyter](https://img.shields.io/badge/Jupyter-F37626?style=for-the-badge&logo=jupyter&logoColor=white)

> An end-to-end data analytics project simulating real-world quick commerce operations — covering data generation, cleaning, SQL analysis, Excel reporting, and an interactive Power BI dashboard.

---

## 📌 Project Overview

ZapKart is a fictional quick commerce company operating **10 dark stores** across **Bengaluru, Mumbai, and Delhi** with a **10-minute delivery promise**.

This project replicates the exact analytics challenges faced by companies like **Zepto, Blinkit, and Swiggy Instamart** — from SLA monitoring and store profitability to picker productivity and substitution intelligence.

---

## 🎯 Business Problems Solved

| # | Business Question | Tools Used |
|---|---|---|
| 1 | Where is the 10-minute SLA breaking and why? | SQL · Power BI |
| 2 | Which dark stores are profitable vs loss-making? | Python · Excel · Power BI |
| 3 | What drives demand peaks by hour and day of week? | Python · Power BI |
| 4 | Where are picker productivity bottlenecks? | Python · SQL · Power BI |
| 5 | Which product substitutions are customers accepting? | SQL · Power BI |
| 6 | What is the break-even order volume per store? | SQL · Excel |
| 7 | Which categories drive the most revenue and margin? | SQL · Power BI |

---

## 🗃️ Dataset

Fully synthetic dataset generated using Python (NumPy + Faker) with realistic business logic:

- Store-specific SLA profiles (61% to 91% achievement)
- Hourly demand weights — morning (7–9 AM) and evening (6–9 PM) peaks
- Weekend order multiplier (1.35×)
- Festive season boost — Oct/Nov (1.45×)
- Skill-based picker efficiency (Beginner → Expert)
- Same-category vs cross-category substitution acceptance rates

| Table | Rows | Description |
|---|---|---|
| `dim_stores` | 10 | Store details, area, fixed costs, coordinates |
| `dim_skus` | 500 | Product catalog with categories and margins |
| `dim_customers` | 50,000 | Customer profiles and segments |
| `dim_pickers` | 80 | Warehouse picker profiles and skill levels |
| `fact_orders` | ~200,000 | Orders with full delivery time breakdown |
| `fact_order_items` | ~500,000 | Line items per order with margins |
| `fact_picker_activity` | ~180,000 | Pick tasks, duration, and error rates |
| `fact_substitutions` | ~25,000 | Substitution events and acceptance outcomes |

**Total: ~955,000 records across 8 tables**

---

## 🛠️ Tech Stack

| Tool | Version | Purpose |
|---|---|---|
| Python | 3.8+ | Data generation, cleaning, EDA, Excel automation |
| PostgreSQL | 14+ | Relational database and SQL analysis |
| pgAdmin | 4 | Database management and query execution |
| SQLAlchemy + psycopg2 | Latest | Python–PostgreSQL connection |
| Pandas + NumPy | Latest | Data manipulation |
| Matplotlib + Seaborn | Latest | EDA visualisation |
| openpyxl | Latest | Automated Excel report generation |
| Power BI Desktop | Latest | Interactive dashboard |

---

## 📁 Project Structure

```
ZapKart-DarkStore-Intelligence/
│
├── 01_Data/
│   ├── Raw/                         # 8 original generated CSV files
│   └── Processed/                   # 8 cleaned CSV files + audit log
│
├── 02_Notebooks/
│   ├── 01_Data_Generation.ipynb     # Synthetic data generation
│   ├── 02_Data_Cleaning.ipynb       # Data quality checks and cleaning
│   ├── 03_EDA.ipynb                 # 7 exploratory charts
│   ├── 04_SQL_Analysis.ipynb        # Load data to PostgreSQL
│   └── 05_Excel_Reports.ipynb       # Automated Excel report generation
│
├── 03_SQL/
│   ├── 03_delivery_analysis.sql     # SLA and delivery time queries
│   ├── 04_store_pnl.sql             # Store P&L and break-even queries
│   ├── 05_picker_analysis.sql       # Picker productivity queries
│   ├── 06_assortment_analysis.sql   # SKU and substitution queries
│   └── 07_demand_patterns.sql       # Demand and customer queries
│
├── 04_Excel/
│   └── ZapKart_Operational_Reports.xlsx   # 8-sheet operational report
│
├── 05_PowerBI/
│   └── ZapKart_Dashboard.pbix       # 5-page dark theme dashboard
│
├── 06_Outputs/
│   └── Charts/                      # 7 EDA charts (PNG)
│
├── 07_Documentation/
│   └── Key_Findings.md              # Summary of analytical insights
│
└── README.md
```

---

## 📊 Dashboard Pages (Power BI)

| Page | Title | Key Visuals |
|---|---|---|
| 1 | Executive Overview | 6 KPI cards · Revenue trend · Orders by city · Order status donut |
| 2 | Delivery & SLA | SLA by store with target line · Hourly demand vs delivery time |
| 3 | Store P&L | Revenue by store · Monthly trend · Revenue vs delivery cost scatter |
| 4 | Picker Intelligence | Pick rate by store/skill/shift · Picker leaderboard with gradient |
| 5 | Product Intelligence | Revenue by category · Revenue vs margin · Substitution donut |

All pages feature a **dark premium theme** (`#0F172A` background) with interactive slicers for City, Store, Date Range, Skill Level, and Shift.

---

## 🔍 Key Findings

### Delivery & SLA
- Network SLA achievement: **~78%** against 10-minute target
- Best store: **ZapKart Powai** at **91% SLA**
- Worst store: **ZapKart Connaught Place** at **61% SLA**
- Evening peak (6–9 PM) shows highest SLA breach concentration
- Pick time is the **#1 contributor** to SLA breaches across all stores

### Store P&L
- **7 out of 10 stores** profitable on monthly basis
- Revenue per sqft varies significantly across stores
- Break-even order volume: **~35–50 orders/day** per store
- Delivery cost is the largest variable cost driver

### Picker Productivity
- Expert pickers are **~40% faster** than beginners
- Night shift shows **lowest pick rate** across all stores
- Error rate inversely correlated with experience months
- Top 10% of pickers handle **25% of all pick activities**

### Substitutions
- Overall acceptance rate: **~65%**
- Same-category substitutions accepted at **74%**
- Cross-category substitutions accepted at only **41%**
- Out-of-stock is the primary substitution trigger

---

## ⚙️ How to Run This Project

### Prerequisites
- Python 3.8+
- PostgreSQL 14+
- Power BI Desktop (free)
- Jupyter Notebook / JupyterLab

### Setup

**1. Clone the repository**
```bash
git clone https://github.com/yourusername/zapkart-darkstore-intelligence.git
cd zapkart-darkstore-intelligence
```

**2. Install Python dependencies**
```bash
pip install pandas numpy faker matplotlib seaborn plotly psycopg2-binary sqlalchemy openpyxl
```

**3. Create PostgreSQL database**
```sql
CREATE DATABASE zapkart_db;
```

**4. Run notebooks in order**
```
01_Data_Generation.ipynb
02_Data_Cleaning.ipynb
03_EDA.ipynb
04_SQL_Analysis.ipynb
05_Excel_Reports.ipynb
```

**5. Open Power BI Dashboard**
- Open `05_PowerBI/ZapKart_Dashboard.pbix` in Power BI Desktop
- Update PostgreSQL connection: `localhost / zapkart_db`
- Enter your credentials and refresh

---

## 📈 SQL Analysis Coverage

23 queries across 5 files covering:

- SLA achievement by store, hour, and day of week
- Delivery time percentiles (p50, p75, p90, p95)
- Store P&L with break-even analysis
- Revenue per square foot ranking
- Picker productivity vs store average (window functions)
- Top 20 SKUs by revenue
- Customer frequency segmentation (RFM-lite)
- **Dark Store Scorecard** — composite ranking across revenue, SLA, and profitability

---

## 👤 Author

**Mohsin Raza | Data Analyst**

Built as a portfolio project targeting **Data Analyst roles** in Indian D2C and quick commerce sector.

**Skills demonstrated:**
`Python` `SQL` `PostgreSQL` `Power BI` `DAX` `Excel` `Data Modelling` `EDA` `Business Analytics` `Quick Commerce Domain`

---

## 📄 License

This project is for portfolio and educational purposes. The dataset is entirely synthetic — no real customer or business data is used.
