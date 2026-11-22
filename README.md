# rk.ts.pro: Advanced Multi-Seasonality, Hierarchical Forecasting & Backtesting for RKWard

![Version](https://img.shields.io/badge/Version-0.0.1-blue.svg)
[![License: GPL v3](https://img.shields.io/badge/License-GPL%20v3-blue.svg)](https://www.gnu.org/licenses/gpl-3.0)
![RKWard](https://img.shields.io/badge/Platform-RKWard-green)
[![R Linter](https://github.com/AlfCano/rk.ts.pro/actions/workflows/lintr.yml/badge.svg)](https://github.com/AlfCano/rk.ts.pro/actions/workflows/lintr.yml)
![AI Gemini](https://img.shields.io/badge/AI-Gemini-4285F4?logo=googlegemini&logoColor=white)

**A Zero-Code GUI Wrapper for `prophet`, `tbats`, `fable`, `tsibble`, and `tsCV` bringing Enterprise-Grade Time Series Forecasting to RKWard**

`rk.ts.pro` is the advanced Phase 2 capstone of the RKWard Time Series & Forecasting ecosystem (building upon [`rk.forecast`](https://github.com/AlfCano/rk.forecast), [`rk.ts.prep`](https://github.com/AlfCano/rk.ts.prep), and [`rk.ts.models`](https://github.com/AlfCano/rk.ts.models)). Designed to go well beyond legacy statistical GUIs like SPSS Forecasting, this plugin provides a seamless point-and-click interface for daily/hourly multiple seasonality with country holidays, parallel batch and hierarchical reconciliation (`MinT`), and true rolling-origin out-of-sample cross-validation—all without writing a single line of R code.

---

## 🌟 Key Features

*   **Multiple Seasonality & Public Holidays (`Prophet` & `TBATS`):** Handle complex daily or hourly data containing overlapping weekly and annual cycles. Inject built-in country holidays (Mexico, US, Spain, Brazil, France, Germany, and more), model linear or logistic saturation growth (`cap`), inspect component breakdowns (Trend, Holidays, Weekly, Yearly), or use pure-R trigonometric `TBATS` without needing Stan.
*   **Batch & Hierarchical Forecasting (`tsibble` & `fable`):** Automatically convert date columns into regular `yearmonth`, `yearquarter`, `yearweek`, or daily `tsibble` indexes without implicit-gap errors. Fit `ETS`, `ARIMA`, `TSLM`, or `SNAIVE` across multiple series simultaneously—optionally accelerated with parallel processing (`future::multisession`).
*   **Coherent Hierarchical Reconciliation:** Aggregate nested (`Region / Store`) or crossed (`Region * Product`) hierarchies and reconcile bottom-to-top forecasts using optimal **MinT Shrinkage**, **MinT OLS**, **Bottom-Up**, or **Top-Down** methods, complete with unpacked 80% and 95% confidence intervals.
*   **True Rolling-Origin Backtesting (`tsCV` & `stretch_tsibble`):** Eliminate in-sample overfitting illusions. Pit `Auto-ARIMA`, `ETS`, `TBATS`, `TSLM`, and `Seasonal Naive` head-to-head across expanding or sliding windows, plotting out-of-sample RMSE by forecast horizon ($h$) and ranking models objectively.
*   **Multilingual Ready:** Prepared for English, Spanish, French, German, and Portuguese (Brazil).

---

## What's New in Version 0.0.1

*   **Initial Release:** Introduces 3 advanced forecasting engines nested cleanly under `Analysis > Time Series > Advanced & Hierarchical (Pro)`.
*   **Production-Safe Rendering:** Automatic `<aggregated>` HTML escaping in hierarchical tables, unpacked `hilo` distribution columns for clean `rk.print()` output, smart facet limiting for massive multi-series plots, and emptied `ggplot2` environments upon workspace export.

---

## ⚙️ Prerequisites

You must have [RKWard](https://rkward.kde.org/) installed along with the following R packages:

```R
install.packages(c("prophet", "forecast", "fable", "fabletools", "tsibble", "feasts", "dplyr", "ggplot2", "future"))
```

*(Note: If you only plan to use `TBATS`, `fable`, and `tsCV`, those modules operate independently even if `prophet` is not installed.)*

---

## 🚀 Installation

You can install this plugin directly from R-Universe or GitHub inside your RKWard console:

```R
# From R-Universe (Recommended)
install.packages('rk.ts.pro', repos = c('https://alfcano.r-universe.dev', 'https://cloud.r-project.org'))

# Or directly from GitHub
library("remotes")
install_github("AlfCano/rk.ts.pro")
```

Once installed, restart RKWard to ensure the new menu entries under **Analysis > Time Series > Advanced & Hierarchical (Pro)** appear correctly.

---

## 🛠️ Usage Workflow (The 3 Modules)

This plugin adds three advanced dialogs under **Analysis > Time Series > Advanced & Hierarchical (Pro)**:

1. **1. Multiple Seasonality & Holidays (Prophet / TBATS):** Model high-frequency business data with overlapping seasonalities, growth saturation caps, and national holidays, outputting full component decomposition charts.
2. **2. Batch & Hierarchical Forecasting (fable):** Forecast dozens of SKUs, stores, or regions at once, or aggregate and reconcile coherent hierarchies with `MinT Shrinkage` and parallel processing.
3. **3. Time-Series Cross-Validation (Backtesting):** Evaluate true out-of-sample generalization via rolling/expanding origin cross-validation (`forecast::tsCV` or `tsibble::stretch_tsibble`).

---

## 📊 Complete Practical Case Studies

First, paste this setup script into the **R Console** in RKWard to generate realistic daily retail data (2 years with weekend surges) and a 2-level monthly regional/store hierarchy:

```R
set.seed(2026)

# 1. Daily retail data (2 years) for Prophet / TBATS
dates <- seq(as.Date("2024-01-01"), as.Date("2025-12-31"), by = "day")
n_d <- length(dates)
is_wknd <- ifelse(as.POSIXlt(dates)$wday %in% c(0, 6), 35, 0)
df_daily <- data.frame(
  date = dates,
  sales = 200 + 0.15 * seq_len(n_d) + is_wknd + 25 * sin(2 * pi * seq_len(n_d) / 365.25) + rnorm(n_d, 0, 8)
)

# 2. Monthly hierarchical data (Region -> Store) for fable
months <- seq(as.Date("2022-01-01"), as.Date("2025-12-01"), by = "month")
df_hierarchy <- expand.grid(date = months, region = c("North", "Center"), store = c("A", "B"))
df_hierarchy$sales <- 100 + rep(seq_along(months), 4) * 2 + 20 * sin(2 * pi * rep(seq_along(months), 4) / 12) + rnorm(nrow(df_hierarchy), 0, 5)
```

---

### Case Study 1: Multi-Seasonality & Country Holidays (`Prophet`)
*Goal: Forecast 60 days of daily sales capturing weekend spikes, annual cycles, and Mexican public holidays.*
1. Go to **Analysis > Time Series > Advanced & Hierarchical (Pro) > 1. Multiple Seasonality & Holidays (Prophet / TBATS)**.
2. In **1. Data & Engine**, select `df_daily`, set Target to `sales`, Date Column to `date`, Engine to **Prophet**, and Horizon to `60`.
3. In **2. Seasonality & Holidays**, set Country Holidays to **Mexico (MX)**.
4. Click **Submit**.
   *👉 Look at the output: Prophet achieves **RMSE = 7.7** and **MAPE = 2.4%**, models all 12 official Mexican holidays, and plots a crisp 4-panel breakdown (`trend`, `holidays`, `weekly` clearly isolating the +35 weekend surge, and `yearly`).*

---

### Case Study 2: Hierarchical Reconciliation (`fable` + `MinT Shrinkage`)
*Goal: Generate coherent monthly forecasts across Total National, 2 Regions (`North`, `Center`), and 4 Stores (`A`, `B`) so store totals add up exactly to regional and national budgets.*
1. Go to **2. Batch & Hierarchical Forecasting (fable)**.
2. In **1. Data & Keys**, select `df_hierarchy`, Time Index `date` (Granularity: `Monthly -> yearmonth`), Target `sales`, and add `region` and `store` to **Series Key(s)**.
3. In **2. Hierarchy & Model**, choose **Nested Hierarchy (`region / store`)**, Reconciliation **MinT Shrinkage**, and Model Engine **Compare Both (ETS + ARIMA)**.
4. Click **Submit**.
   *👉 Look at the output: `fable` fits and reconciles all 7 hierarchical series (`(Total)`, `North`, `Center`, `North/A`, `North/B`, `Center/A`, `Center/B`) across `ETS`, `ARIMA`, `ETS_Rec`, and `ARIMA_Rec`, returning unified accuracy metrics and 80%/95% forecast intervals.*

---

### Case Study 3: Out-of-Sample Backtesting (`tsCV`)
*Goal: Verify whether `Auto-ARIMA` or `ETS` truly generalizes better on `ts_clean` (from `rk.ts.prep` / `AirPassengers`), where both tied in-sample (`RMSE = 11`).*
1. Go to **3. Time-Series Cross-Validation (Backtesting)**.
2. Keep **Univariate ts Object (`forecast::tsCV`)** and select `ts_clean`.
3. In **2. Rolling Windows & Models**, set Initial Training Window to `48`, Horizon per Fold to `6`, and leave `Auto-ARIMA`, `ETS`, and `Seasonal Naive` checked.
4. Click **Submit**.
   *👉 Look at the Out-of-Sample Accuracy ranking and horizon curve: Unlike in-sample evaluation, rolling backtesting reveals that **`Auto-ARIMA` (`RMSE = 19`, `MAPE = 4.4%`) outperforms `ETS` (`RMSE = 24`, `MAPE = 5.0%`) at every single horizon ($h = 1..6$)** and cuts error by more than half compared to the `Seasonal Naive` benchmark (`RMSE = 40`, `MAPE = 10.1%`).*

---

## 🗣️ Communicating with Numbers (Translating Output to Business)

> *"For daily store operations, Prophet isolated our +35 unit weekend surge and 12 national holiday effects with a 2.4% MAPE. At the corporate planning level, `fable` MinT reconciliation ensures that our individual store forecasts sum coherently to regional and national revenue targets. Finally, rolling-origin backtesting proved out-of-sample that Auto-ARIMA generalizes best across a 6-month planning horizon—cutting forecast error by 56% relative to traditional seasonal carryover."*

---

## 🌍 Internationalization (i18n)

The graphical interface automatically adapts to your RKWard language settings. Currently supported languages:
*   🇺🇸 English (Default)
*   🇪🇸 Spanish (Español)
*   🇫🇷 French (Français)
*   🇩🇪 German (Deutsch)
*   🇧🇷 Portuguese (Português do Brasil)

---

## 📝 License and Author

**Author:** Alfonso Cano ([@AlfCano](https://github.com/AlfCano))  
**Email:** alfonso.cano@correo.buap.mx  
*   **Assisted by:** Gemini, a large language model from Google.
*   **License:** GPL (>= 3)

This project is licensed under the **GPL (>= 3)** License.
