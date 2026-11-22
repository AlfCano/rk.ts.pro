local({
  # =========================================================================================
  # 1. Setup and Metadata
  # =========================================================================================
  require(rkwarddev)
  rkwarddev.required("0.10-3")

  plugin_name <- "rk.ts.pro"

  package_about <- rk.XML.about(
    name = plugin_name,
    author = person(
      given = "Alfonso",
      family = "Cano",
      email = "alfonso.cano@correo.buap.mx",
      role = c("aut", "cre")
    ),
    about = list(
      desc = "Advanced Time Series & Forecasting for RKWard: Prophet (Multiple Seasonality & Holidays), TBATS, Batch & Hierarchical Reconciliation (tsibble/fable), and Backtesting (Cross-Validation).",
      version = "0.0.1",
      url = "https://github.com/AlfCano/rk.ts.pro",
      license = "GPL (>= 3)"
    )
  )

  dependencies_node <- rk.XML.dependencies(
    dependencies = list(R.min = "4.1.0"),
    package = list(
      c(name = "prophet"),
      c(name = "forecast"),
      c(name = "fable"),
      c(name = "fabletools"),
      c(name = "tsibble"),
      c(name = "feasts"),
      c(name = "dplyr"),
      c(name = "ggplot2"),
      c(name = "future")
    )
  )

  # MISMA JERARQUÍA BASE QUE rk.forecast, rk.ts.prep Y rk.ts.models (Regla de Oro #2)
  h_pro <- list("analysis", "time_series", "Advanced & Hierarchical (Pro)")

  # Global JavaScript Helper Functions (Regla de Oro #8)
  js_helpers <- "
    function cleanStr(val) {
        if(!val) return '';
        return val.replace(/'/g, \"\\\\'\").replace(/\"/g, '\\\\\"');
    }

    function parseVar(fullPath) {
        if (!fullPath) return '';
        var raw_col = '';
        if (fullPath.indexOf('[[') > -1) {
            var parts = fullPath.split('[[');
            var inner = parts[1].replace(']]', '');
            raw_col = inner.replace(/[\"']/g, '');
        } else if (fullPath.indexOf('$') > -1) {
            raw_col = fullPath.split('$')[1];
        } else {
            raw_col = fullPath;
        }
        return raw_col;
    }
  "

  # =========================================================================================
  # 2. MODULE 1 (MAIN): 1. Multiple Seasonality & Holidays (Prophet / TBATS)
  # =========================================================================================

  # --- UI Elements ---
  pro_vs <- rk.XML.varselector(id.name = "pro_vs")
  pro_df <- rk.XML.varslot("Data Frame", source = "pro_vs", classes = "data.frame", required = TRUE, id.name = "pro_df")
  pro_y <- rk.XML.varslot("Target Variable (Y, Numeric)", source = "pro_vs", classes = c("numeric", "integer"), required = TRUE, id.name = "pro_y")
  pro_ds <- rk.XML.varslot("Date / Datetime Column (Required for Prophet)", source = "pro_vs", required = FALSE, id.name = "pro_ds")

  pro_engine <- rk.XML.radio("Forecasting Engine", options = list(
    "Prophet (Trends, Multiple Seasonalities & Country Holidays)" = list(val = "prophet", chk = TRUE),
    "TBATS (Trigonometric Multiple Seasonalities — Pure R)" = list(val = "tbats")
  ), id.name = "pro_engine")

  pro_h <- rk.XML.spinbox("Forecast Horizon (Periods ahead)", min = 1, max = 730, initial = 30, real = FALSE, id.name = "pro_h")

  # Prophet Specific Options
  pro_freq <- rk.XML.dropdown("Future Step Frequency (Prophet)", options = list(
    "Daily (day)" = list(val = "day", chk = TRUE),
    "Weekly (week)" = list(val = "week"),
    "Monthly (month)" = list(val = "month"),
    "Quarterly (quarter)" = list(val = "quarter"),
    "Yearly (year)" = list(val = "year"),
    "Hourly (hour)" = list(val = "hour")
  ), id.name = "pro_freq")

  pro_growth <- rk.XML.dropdown("Trend Growth", options = list(
    "Linear (Default)" = list(val = "linear", chk = TRUE),
    "Logistic (Requires saturation cap > 0)" = list(val = "logistic"),
    "Flat (No trend)" = list(val = "flat")
  ), id.name = "pro_growth")

  pro_cap <- rk.XML.spinbox("Logistic Saturation Cap (0 = Auto/Unused)", min = 0, max = 1000000000, initial = 0, real = TRUE, id.name = "pro_cap")

  pro_seas_mode <- rk.XML.dropdown("Seasonality Mode", options = list(
    "Additive" = list(val = "additive", chk = TRUE),
    "Multiplicative" = list(val = "multiplicative")
  ), id.name = "pro_seas_mode")

  pro_country <- rk.XML.dropdown("Add Built-in Country Holidays", options = list(
    "None" = list(val = "none", chk = TRUE),
    "Mexico (MX)" = list(val = "MX"),
    "United States (US)" = list(val = "US"),
    "Spain (ES)" = list(val = "ES"),
    "Colombia (CO)" = list(val = "CO"),
    "Argentina (AR)" = list(val = "AR"),
    "Chile (CL)" = list(val = "CL"),
    "Brazil (BR)" = list(val = "BR"),
    "Canada (CA)" = list(val = "CA"),
    "United Kingdom (GB)" = list(val = "GB"),
    "France (FR)" = list(val = "FR"),
    "Germany (DE)" = list(val = "DE")
  ), id.name = "pro_country")

  pro_yr_seas <- rk.XML.dropdown("Yearly Seasonality", options = list("Auto" = list(val = "auto", chk = TRUE), "Enable (TRUE)" = list(val = "TRUE"), "Disable (FALSE)" = list(val = "FALSE")), id.name = "pro_yr_seas")
  pro_wk_seas <- rk.XML.dropdown("Weekly Seasonality", options = list("Auto" = list(val = "auto", chk = TRUE), "Enable (TRUE)" = list(val = "TRUE"), "Disable (FALSE)" = list(val = "FALSE")), id.name = "pro_wk_seas")
  pro_dy_seas <- rk.XML.dropdown("Daily Seasonality", options = list("Auto" = list(val = "auto", chk = TRUE), "Enable (TRUE)" = list(val = "TRUE"), "Disable (FALSE)" = list(val = "FALSE")), id.name = "pro_dy_seas")
  pro_cp_scale <- rk.XML.spinbox("Changepoint Flexibility (prior scale)", min = 0.001, max = 1.0, initial = 0.05, real = TRUE, id.name = "pro_cp_scale")

  frm_prophet <- rk.XML.frame(
    rk.XML.row(pro_freq, pro_country),
    rk.XML.row(pro_growth, pro_cap),
    rk.XML.row(pro_seas_mode, pro_cp_scale),
    rk.XML.row(pro_yr_seas, pro_wk_seas, pro_dy_seas),
    label = "Prophet Configuration", id.name = "frm_prophet"
  )

  # TBATS Specific Options
  pro_tbats_periods <- rk.XML.input("Seasonal Periods (comma-separated, e.g., 7, 365.25 or 24, 168)", initial = "7, 365.25", id.name = "pro_tbats_periods")
  pro_tbats_start <- rk.XML.input("Start Cycle (comma-separated, e.g., 2020, 1)", initial = "2020, 1", id.name = "pro_tbats_start")
  frm_tbats <- rk.XML.frame(pro_tbats_periods, pro_tbats_start, label = "TBATS Multiple Seasonality (msts)", id.name = "frm_tbats")

  # Plot Options
  pro_comp_plot <- rk.XML.cbox("Include Component Breakdown Plot in Final Output (Trend/Holidays/Seasonalities)", value = "1", chk = TRUE, id.name = "pro_comp_plot")
  pro_theme <- rk.XML.dropdown("Plot Theme (ggplot2)", options = list(
    "Minimal (Clean business look)" = list(val = "minimal", chk = TRUE),
    "Classic (Scientific)" = list(val = "classic"),
    "Black & White (Grid)" = list(val = "bw")
  ), id.name = "pro_theme")
  pro_plot_main <- rk.XML.input("Main Title (Leave empty for default)", id.name = "pro_plot_main")
  pro_plot_xlab <- rk.XML.input("X-Axis Label (Leave empty for default)", id.name = "pro_plot_xlab")
  pro_plot_ylab <- rk.XML.input("Y-Axis Label (Leave empty for default)", id.name = "pro_plot_ylab")
  frm_pro_plot <- rk.XML.frame(pro_comp_plot, pro_theme, pro_plot_main, pro_plot_xlab, pro_plot_ylab, label = "Plot Customization")

  # Output Options
  pro_save_fc <- rk.XML.saveobj("Save Forecast Result as", initial = "pro_forecast", chk = TRUE, id.name = "pro_save_fc")
  pro_save_mod <- rk.XML.saveobj("Save Model Object as", initial = "pro_model", chk = FALSE, id.name = "pro_save_mod")

  pro_plot_w <- rk.XML.spinbox("HTML Plot Width (pixels)", min = 100, max = 5000, initial = 850, real = FALSE, id.name = "pro_plot_w")
  pro_plot_h <- rk.XML.spinbox("HTML Plot Height (pixels)", min = 100, max = 5000, initial = 600, real = FALSE, id.name = "pro_plot_h")
  pro_plot_res <- rk.XML.spinbox("Resolution (DPI)", min = 72, max = 600, initial = 120, real = FALSE, id.name = "pro_plot_res")
  frm_pro_graph <- rk.XML.frame(rk.XML.row(pro_plot_w, pro_plot_h, pro_plot_res), label = "HTML Graphics Size & Resolution")
  pro_save_plot <- rk.XML.saveobj("Save Main Plot (ggplot2) as", initial = "pro_plot", chk = FALSE, id.name = "pro_save_plot")

  pro_preview <- rk.XML.preview(label = "Preview Multi-Seasonal Forecast")

  # --- UI Logic ---
  cond_pro_prophet <- rk.XML.convert(sources = list(string = pro_engine), mode = c(equals = "prophet"), id.name = "cond_pro_prophet")
  cond_pro_tbats   <- rk.XML.convert(sources = list(string = pro_engine), mode = c(equals = "tbats"), id.name = "cond_pro_tbats")
  cond_pro_log     <- rk.XML.convert(sources = list(string = pro_growth), mode = c(equals = "logistic"), id.name = "cond_pro_log")

  logic_pro <- rk.XML.logic(
    rk.XML.connect(governor = pro_df, get = "available", client = pro_vs, set = "root"),
    cond_pro_prophet, cond_pro_tbats, cond_pro_log,
    rk.XML.connect(governor = cond_pro_prophet, client = pro_ds, set = "enabled"),
    rk.XML.connect(governor = cond_pro_prophet, client = frm_prophet, set = "enabled"),
    rk.XML.connect(governor = cond_pro_tbats, client = frm_tbats, set = "enabled"),
    rk.XML.connect(governor = cond_pro_log, client = pro_cap, set = "enabled")
  )

  # --- Layout ---
  tab_pro <- rk.XML.tabbook(tabs = list(
    "1. Data & Engine" = rk.XML.col(pro_df, pro_y, pro_ds, pro_engine, pro_h, rk.XML.stretch()),
    "2. Seasonality & Holidays" = rk.XML.col(frm_prophet, frm_tbats, rk.XML.stretch()),
    "3. Plot Options" = rk.XML.col(frm_pro_plot, rk.XML.stretch()),
    "4. Output" = rk.XML.col(
      rk.XML.frame(pro_save_fc, pro_save_mod, label = "Save Objects to Workspace"),
      frm_pro_graph,
      rk.XML.frame(pro_save_plot, label = "Save Plot Object"),
      rk.XML.stretch()
    )
  ))

  dialog_pro <- rk.XML.dialog(
    rk.XML.row(
      pro_vs,
      rk.XML.col(tab_pro, pro_preview)
    ),
    label = "1. Multiple Seasonality & Holidays (Prophet / TBATS)"
  )

  # --- JavaScript ---
  js_calc_pro <- "
    var df = getValue('pro_df');
    var y_col = parseVar(getValue('pro_y'));
    var ds_col = parseVar(getValue('pro_ds'));
    var engine = getValue('pro_engine');
    var h = getValue('pro_h');

    var theme = getValue('pro_theme');
    var main_tit = cleanStr(getValue('pro_plot_main'));
    var x_tit = cleanStr(getValue('pro_plot_xlab'));
    var y_tit = cleanStr(getValue('pro_plot_ylab'));

    if (engine === 'prophet') {
        if (ds_col === '') {
            echo('stop(\"Prophet requires a Date / Datetime column.\")\\n');
        }
        var freq = getValue('pro_freq');
        var growth = getValue('pro_growth');
        var cap = getValue('pro_cap');
        var seas_mode = getValue('pro_seas_mode');
        var country = getValue('pro_country');
        var yr_s = getValue('pro_yr_seas');
        var wk_s = getValue('pro_wk_seas');
        var dy_s = getValue('pro_dy_seas');
        var cp_s = getValue('pro_cp_scale');

        echo('if (!requireNamespace(\"prophet\", quietly = TRUE)) stop(\"Package prophet is required for the Prophet engine.\")\\n');
        echo('suppressPackageStartupMessages(require(prophet))\\n\\n');

        echo('ds_raw <- ' + df + '[[\"' + ds_col + '\"]]\\n');
        echo('if (is.character(ds_raw) || is.factor(ds_raw)) {\\n');
        echo('  ds_chr <- as.character(ds_raw)\\n');
        echo('  ds_parsed <- if (any(grepl(\":\", ds_chr))) as.POSIXct(ds_chr) else as.Date(ds_chr)\\n');
        echo('} else { ds_parsed <- ds_raw }\\n\\n');

        echo('df_p <- data.frame(ds = ds_parsed, y = as.numeric(' + df + '[[\"' + y_col + '\"]]))\\n');
        if (growth === 'logistic') {
            echo('cap_val <- if (' + cap + ' > 0) ' + cap + ' else max(df_p$y, na.rm = TRUE) * 1.2\\n');
            echo('df_p$cap <- cap_val\\n');
        }

        var yr_arg = (yr_s === 'auto') ? '\"auto\"' : yr_s;
        var wk_arg = (wk_s === 'auto') ? '\"auto\"' : wk_s;
        var dy_arg = (dy_s === 'auto') ? '\"auto\"' : dy_s;

        echo('pro_model <- prophet::prophet(\\n');
        echo('  growth = \"' + growth + '\",\\n');
        echo('  seasonality.mode = \"' + seas_mode + '\",\\n');
        echo('  yearly.seasonality = ' + yr_arg + ',\\n');
        echo('  weekly.seasonality = ' + wk_arg + ',\\n');
        echo('  daily.seasonality = ' + dy_arg + ',\\n');
        echo('  changepoint.prior.scale = ' + cp_s + '\\n');
        echo(')\\n');

        if (country !== 'none') {
            echo('pro_model <- prophet::add_country_holidays(pro_model, country_name = \"' + country + '\")\\n');
        }

        echo('pro_model <- suppressMessages(prophet::fit.prophet(pro_model, df_p))\\n');
        echo('future_df <- prophet::make_future_dataframe(pro_model, periods = ' + h + ', freq = \"' + freq + '\")\\n');
        if (growth === 'logistic') {
            echo('future_df$cap <- cap_val\\n');
        }
        echo('pro_forecast <- stats::predict(pro_model, future_df)\\n\\n');

        // Métricas in-sample
        echo('n_hist <- nrow(df_p)\\n');
        echo('eval_df <- data.frame(y = df_p$y, yhat = pro_forecast$yhat[seq_len(n_hist)])\\n');
        echo('eval_df <- stats::na.omit(eval_df)\\n');
        echo('err_vec <- eval_df$y - eval_df$yhat\\n');
        echo('rmse_v <- round(sqrt(mean(err_vec^2)), 4)\\n');
        echo('mae_v  <- round(mean(abs(err_vec)), 4)\\n');
        echo('mape_v <- round(mean(abs(err_vec[eval_df$y != 0] / eval_df$y[eval_df$y != 0])) * 100, 4)\\n');
        echo('pro_acc <- data.frame(Engine = \"Prophet\", Country_Holidays = \"' + country + '\", RMSE = rmse_v, MAE = mae_v, MAPE = mape_v)\\n\\n');

        echo('hol_tbl <- if (!is.null(pro_model$train.holiday.names)) data.frame(Holidays_Modeled = pro_model$train.holiday.names) else data.frame()\\n');
        echo('fc_tail <- utils::tail(pro_forecast[, c(\"ds\", \"yhat\", \"yhat_lower\", \"yhat_upper\", \"trend\")], ' + h + ')\\n');

        var title_str = (main_tit !== '') ? main_tit : 'Prophet Forecast: ' + y_col;
        echo('p <- plot(pro_model, pro_forecast) + ggplot2::theme_' + theme + '() +\\n');
        echo('     ggplot2::labs(title = \"' + title_str + '\"');
        if (x_tit !== '') echo(', x = \"' + x_tit + '\"'); else echo(', x = \"Date\"');
        if (y_tit !== '') echo(', y = \"' + y_tit + '\"'); else echo(', y = \"' + y_col + '\"');
        echo(')\\n');

    } else {
        // TBATS Engine
        var periods_str = cleanStr(getValue('pro_tbats_periods'));
        var start_str = cleanStr(getValue('pro_tbats_start'));
        if (periods_str === '') periods_str = '12';
        if (start_str === '') start_str = '2020, 1';

        echo('y_vec <- stats::na.omit(as.numeric(' + df + '[[\"' + y_col + '\"]]))\\n');
        echo('m_periods <- as.numeric(trimws(strsplit(\"' + periods_str + '\", \",\")[[1]]))\\n');
        echo('m_start   <- as.numeric(trimws(strsplit(\"' + start_str + '\", \",\")[[1]]))\\n');
        echo('ts_multi  <- forecast::msts(y_vec, seasonal.periods = m_periods, start = m_start)\\n\\n');

        echo('pro_model <- forecast::tbats(ts_multi)\\n');
        echo('pro_forecast <- forecast::forecast(pro_model, h = ' + h + ')\\n\\n');

        echo('acc_t <- forecast::accuracy(pro_model)\\n');
        echo('pro_acc <- data.frame(Engine = \"TBATS\", Seasonal_Periods = paste(m_periods, collapse = \", \"), RMSE = round(acc_t[1, \"RMSE\"], 4), MAE = round(acc_t[1, \"MAE\"], 4), MAPE = round(acc_t[1, \"MAPE\"], 4))\\n');
        echo('hol_tbl <- data.frame()\\n');
        echo('fc_tail <- as.data.frame(pro_forecast)\\n\\n');

        var title_str_t = (main_tit !== '') ? main_tit : 'TBATS Multi-Seasonal Forecast: ' + y_col;
        echo('p <- ggplot2::autoplot(pro_forecast) + ggplot2::theme_' + theme + '() +\\n');
        echo('     ggplot2::labs(title = \"' + title_str_t + '\"');
        if (x_tit !== '') echo(', x = \"' + x_tit + '\"');
        if (y_tit !== '') echo(', y = \"' + y_tit + '\"');
        echo(') + ggplot2::theme(legend.position = \"bottom\")\\n');
    }
  "

  js_print_pro <- "
    var engine = getValue('pro_engine');
    var do_comp = getValue('pro_comp_plot') === '1';
    var w = getValue('pro_plot_w');
    var h = getValue('pro_plot_h');
    var res = getValue('pro_plot_res');

    if (typeof is_preview !== 'undefined' && is_preview) {
        echo('print(p)\\n');
    }

    if (typeof is_preview === 'undefined' || !is_preview) {
        echo('rk.header(\"1. Multiple Seasonality & Holidays Forecast\")\\n');

        echo('rk.graph.on(width = ' + w + ', height = ' + h + ', res = ' + res + ')\\n');
        echo('print(p)\\n');
        echo('rk.graph.off()\\n\\n');

        if (do_comp) {
            echo('rk.header(\"Model Components Breakdown\", level = 3)\\n');
            echo('rk.graph.on(width = ' + w + ', height = ' + (parseInt(h, 10) + 150) + ', res = ' + res + ')\\n');
            if (engine === 'prophet') {
                echo('prophet::prophet_plot_components(pro_model, pro_forecast)\\n');
            } else {
                echo('plot(pro_model, main = \"TBATS Components\")\\n');
            }
            echo('rk.graph.off()\\n\\n');
        }

        echo('rk.header(\"In-Sample Accuracy Metrics\", level = 3)\\n');
        echo('rk.print(pro_acc)\\n');

        echo('if (nrow(hol_tbl) > 0) {\\n');
        echo('  rk.header(\"Modeled Country Holidays\", level = 3)\\n');
        echo('  rk.print(hol_tbl)\\n');
        echo('}\\n');

        echo('rk.header(\"Forecasted Values\", level = 3)\\n');
        echo('rk.print(fc_tail)\\n');

        if (getValue('pro_save_fc.active') || getValue('pro_save_mod.active') || getValue('pro_save_plot.active')) {
            echo('rk.print(\"<hr>\")\\n');
        }
        if (getValue('pro_save_fc.active')) {
            echo('rk.print(paste0(\"<b>Forecast saved as: </b><code>\", \"' + getValue('pro_save_fc') + '\", \"</code><br>\"))\\n');
        }
        if (getValue('pro_save_mod.active')) {
            echo('rk.print(paste0(\"<b>Model saved as: </b><code>\", \"' + getValue('pro_save_mod') + '\", \"</code><br>\"))\\n');
        }
        if (getValue('pro_save_plot.active')) {
            echo('p$plot_env <- emptyenv()\\n');
            echo('pro_plot <- p\\n');
            echo('rk.print(paste0(\"<b>Plot object (ggplot2) saved as: </b><code>\", \"' + getValue('pro_save_plot') + '\", \"</code>\"))\\n');
        }
    }
  "

  # =========================================================================================
  # 3. MODULE 2: 2. Batch & Hierarchical Forecasting (tsibble / fable)
  # =========================================================================================

  # --- UI Elements ---
  fab_vs <- rk.XML.varselector(id.name = "fab_vs")
  fab_df <- rk.XML.varslot("Data Frame", source = "fab_vs", classes = "data.frame", required = TRUE, id.name = "fab_df")
  fab_idx <- rk.XML.varslot("Time Index Column (Date / Year-Month / Numeric)", source = "fab_vs", required = TRUE, id.name = "fab_idx")
  fab_y <- rk.XML.varslot("Target Variable (Y, Numeric)", source = "fab_vs", classes = c("numeric", "integer"), required = TRUE, id.name = "fab_y")
  fab_keys <- rk.XML.varslot("Series Key(s) / Hierarchy Levels (e.g., Region, Store)", source = "fab_vs", multi = TRUE, required = FALSE, id.name = "fab_keys")

  fab_gran <- rk.XML.dropdown("Time Index Granularity", options = list(
    "Monthly (Convert Date -> yearmonth)" = list(val = "month", chk = TRUE),
    "Quarterly (Convert Date -> yearquarter)" = list(val = "quarter"),
    "Weekly (Convert Date -> yearweek)" = list(val = "week"),
    "Daily (Convert -> as.Date)" = list(val = "day"),
    "Native / Numeric (Keep index as-is)" = list(val = "raw")
  ), id.name = "fab_gran")

  # Hierarchy & Reconciliation
  fab_hier_mode <- rk.XML.radio("Multi-Series / Hierarchy Mode", options = list(
    "Independent Batch Forecasting (Each key series separately)" = list(val = "batch", chk = TRUE),
    "Nested Hierarchy (Key1 / Key2 / ... e.g., Region / Store)" = list(val = "nested"),
    "Crossed / Grouped Hierarchy (Key1 * Key2 * ...)" = list(val = "crossed")
  ), id.name = "fab_hier_mode")

  fab_reconcile <- rk.XML.dropdown("Hierarchical Reconciliation Method", options = list(
    "MinT Shrinkage (Optimal — mint_shrink)" = list(val = "mint_shrink", chk = TRUE),
    "MinT OLS (ols)" = list(val = "ols"),
    "Bottom-Up (Sum lower levels)" = list(val = "bottom_up"),
    "Top-Down (Historical proportions)" = list(val = "top_down")
  ), id.name = "fab_reconcile")

  frm_fab_hier <- rk.XML.frame(fab_hier_mode, fab_reconcile, label = "Batch & Reconciliation Structure")

  # Model & Horizon
  fab_model <- rk.XML.dropdown("Fable Model Engine", options = list(
    "ETS (Exponential Smoothing)" = list(val = "ets", chk = TRUE),
    "Auto-ARIMA" = list(val = "arima"),
    "Compare Both (ETS + ARIMA)" = list(val = "both"),
    "TSLM (Trend + Seasonality Linear Model)" = list(val = "tslm"),
    "SNAIVE (Seasonal Naive Baseline)" = list(val = "snaive")
  ), id.name = "fab_model")

  fab_h <- rk.XML.spinbox("Forecast Horizon (Periods)", min = 1, max = 120, initial = 12, real = FALSE, id.name = "fab_h")
  fab_parallel <- rk.XML.cbox("Enable Parallel Processing (future::multisession)", value = "1", chk = FALSE, id.name = "fab_parallel")
  frm_fab_mod <- rk.XML.frame(fab_model, fab_h, fab_parallel, label = "Modeling & Compute Options")

  # Plot Options
  fab_theme <- rk.XML.dropdown("Plot Theme (ggplot2)", options = list(
    "Minimal (Clean business look)" = list(val = "minimal", chk = TRUE),
    "Classic (Scientific)" = list(val = "classic"),
    "Black & White (Grid)" = list(val = "bw")
  ), id.name = "fab_theme")
  fab_plot_main <- rk.XML.input("Main Title (Leave empty for default)", id.name = "fab_plot_main")
  fab_max_plot <- rk.XML.spinbox("Max Series to Plot (Prevents cluttered facets)", min = 1, max = 20, initial = 6, real = FALSE, id.name = "fab_max_plot")
  frm_fab_plot <- rk.XML.frame(fab_theme, fab_plot_main, fab_max_plot, label = "Plot Customization")

  # Output Options
  fab_save_fc <- rk.XML.saveobj("Save Fable Forecast (fbl_ts) as", initial = "fable_forecast", chk = TRUE, id.name = "fab_save_fc")
  fab_save_mod <- rk.XML.saveobj("Save Mable Models (mdl_df) as", initial = "fable_models", chk = FALSE, id.name = "fab_save_mod")

  fab_plot_w <- rk.XML.spinbox("HTML Plot Width (pixels)", min = 100, max = 5000, initial = 900, real = FALSE, id.name = "fab_plot_w")
  fab_plot_h <- rk.XML.spinbox("HTML Plot Height (pixels)", min = 100, max = 5000, initial = 650, real = FALSE, id.name = "fab_plot_h")
  fab_plot_res <- rk.XML.spinbox("Resolution (DPI)", min = 72, max = 600, initial = 120, real = FALSE, id.name = "fab_plot_res")
  frm_fab_graph <- rk.XML.frame(rk.XML.row(fab_plot_w, fab_plot_h, fab_plot_res), label = "HTML Graphics Size & Resolution")
  fab_save_plot <- rk.XML.saveobj("Save Plot (ggplot2) as", initial = "fable_plot", chk = FALSE, id.name = "fab_save_plot")

  fab_preview <- rk.XML.preview(label = "Preview Batch / Hierarchical Plot")

  # --- UI Logic ---
  cond_fab_batch <- rk.XML.convert(sources = list(string = fab_hier_mode), mode = c(equals = "batch"), id.name = "cond_fab_batch")

  logic_fab <- rk.XML.logic(
    rk.XML.connect(governor = fab_df, get = "available", client = fab_vs, set = "root"),
    cond_fab_batch,
    rk.XML.connect(governor = cond_fab_batch, client = fab_reconcile, set = "enabled", not = TRUE)
  )

  # --- Layout ---
  tab_fab <- rk.XML.tabbook(tabs = list(
    "1. Data & Keys" = rk.XML.col(fab_df, fab_idx, fab_gran, fab_y, fab_keys, rk.XML.stretch()),
    "2. Hierarchy & Model" = rk.XML.col(frm_fab_hier, frm_fab_mod, rk.XML.stretch()),
    "3. Plot Options" = rk.XML.col(frm_fab_plot, rk.XML.stretch()),
    "4. Output" = rk.XML.col(
      rk.XML.frame(fab_save_fc, fab_save_mod, label = "Save Objects to Workspace"),
      frm_fab_graph,
      rk.XML.frame(fab_save_plot, label = "Save Plot Object"),
      rk.XML.stretch()
    )
  ))

  dialog_fab <- rk.XML.dialog(
    rk.XML.row(
      fab_vs,
      rk.XML.col(tab_fab, fab_preview)
    ),
    label = "2. Batch & Hierarchical Forecasting (fable)"
  )

  # --- JavaScript ---
  js_calc_fab <- "
    var df = getValue('fab_df');
    var idx_col = parseVar(getValue('fab_idx'));
    var gran = getValue('fab_gran');
    var y_col = parseVar(getValue('fab_y'));
    var keys_raw = getValue('fab_keys');
    var hier_mode = getValue('fab_hier_mode');
    var rec_meth = getValue('fab_reconcile');
    var mod_type = getValue('fab_model');
    var h = getValue('fab_h');
    var use_par = getValue('fab_parallel') === '1';

    var theme = getValue('fab_theme');
    var main_tit = cleanStr(getValue('fab_plot_main'));
    var max_plot = getValue('fab_max_plot');

    var keys_arr = (keys_raw !== '') ? keys_raw.split('\\n').map(parseVar).filter(Boolean) : [];
    var has_keys = keys_arr.length > 0;

    if (hier_mode !== 'batch' && !has_keys) {
        echo('stop(\"Hierarchical forecasting requires at least 1 Key column.\")\\n');
    }

    echo('df_fab <- as.data.frame(' + df + ')\\n');
    if (gran === 'month') {
        echo('df_fab[[\"' + idx_col + '\"]] <- tsibble::yearmonth(df_fab[[\"' + idx_col + '\"]])\\n');
    } else if (gran === 'quarter') {
        echo('df_fab[[\"' + idx_col + '\"]] <- tsibble::yearquarter(df_fab[[\"' + idx_col + '\"]])\\n');
    } else if (gran === 'week') {
        echo('df_fab[[\"' + idx_col + '\"]] <- tsibble::yearweek(df_fab[[\"' + idx_col + '\"]])\\n');
    } else if (gran === 'day') {
        echo('df_fab[[\"' + idx_col + '\"]] <- as.Date(df_fab[[\"' + idx_col + '\"]])\\n');
    }

    var key_arg = '';
    if (has_keys) {
        key_arg = ', key = c(' + keys_arr.map(function(k){ return '`' + k + '`'; }).join(', ') + ')';
    }
    echo('tsb <- tsibble::as_tsibble(df_fab, index = `' + idx_col + '`' + key_arg + ')\\n\\n');

    // Agregación jerárquica si aplica
    if (hier_mode !== 'batch' && has_keys) {
        var sep_op = (hier_mode === 'nested') ? ' / ' : ' * ';
        var key_expr = keys_arr.map(function(k){ return '`' + k + '`'; }).join(sep_op);
        echo('tsb <- tsb %>%\\n');
        echo('  fabletools::aggregate_key(' + key_expr + ', `' + y_col + '` = sum(`' + y_col + '`, na.rm = TRUE))\\n\\n');
    }

    if (use_par) {
        echo('future::plan(future::multisession)\\n');
    }

    // Especificación de modelos fable
    var y_bt = '`' + y_col + '`';
    var mod_args = [];
    if (mod_type === 'ets') {
        mod_args.push('ETS = fable::ETS(' + y_bt + ')');
    } else if (mod_type === 'arima') {
        mod_args.push('ARIMA = fable::ARIMA(' + y_bt + ')');
    } else if (mod_type === 'both') {
        mod_args.push('ETS = fable::ETS(' + y_bt + ')');
        mod_args.push('ARIMA = fable::ARIMA(' + y_bt + ')');
    } else if (mod_type === 'tslm') {
        mod_args.push('TSLM = fable::TSLM(' + y_bt + ' ~ trend() + season())');
    } else if (mod_type === 'snaive') {
        mod_args.push('SNAIVE = fable::SNAIVE(' + y_bt + ')');
    }

    echo('fable_models <- tsb %>%\\n  fabletools::model(' + mod_args.join(', ') + ')\\n');

    // Reconciliación jerárquica
    if (hier_mode !== 'batch' && has_keys) {
        var rec_fn = '';
        if (rec_meth === 'bottom_up') {
            rec_fn = 'fabletools::bottom_up';
        } else if (rec_meth === 'top_down') {
            rec_fn = 'fabletools::top_down';
        } else {
            rec_fn = 'fabletools::min_trace';
        }

        var rec_args = [];
        var mod_names = (mod_type === 'both') ? ['ETS', 'ARIMA'] : [(mod_type === 'ets' ? 'ETS' : (mod_type === 'arima' ? 'ARIMA' : (mod_type === 'tslm' ? 'TSLM' : 'SNAIVE')))];
        for (var i = 0; i < mod_names.length; i++) {
            var mn = mod_names[i];
            if (rec_meth === 'mint_shrink' || rec_meth === 'ols') {
                rec_args.push(mn + '_Rec = ' + rec_fn + '(' + mn + ', method = \"' + rec_meth + '\")');
            } else {
                rec_args.push(mn + '_Rec = ' + rec_fn + '(' + mn + ')');
            }
        }
        echo('fable_models <- fable_models %>%\\n  fabletools::reconcile(' + rec_args.join(', ') + ')\\n');
    }

    echo('fable_forecast <- fable_models %>%\\n  fabletools::forecast(h = ' + h + ')\\n');

    if (use_par) {
        echo('future::plan(future::sequential)\\n');
    }
    echo('\\n');

    // Accuracy table (convertida a data.frame limpio y reemplazando <aggregated> por (Total))
    echo('acc_fab <- as.data.frame(fabletools::accuracy(fable_models))\\n');
    echo('for (kn in tsibble::key_vars(tsb)) {\\n');
    echo('  if (kn %in% colnames(acc_fab)) { v_c <- format(acc_fab[[kn]]); acc_fab[[kn]] <- ifelse(v_c == \"<aggregated>\", \"(Total)\", v_c) }\\n');
    echo('}\\n');
    echo('keep_acc <- intersect(colnames(acc_fab), c(tsibble::key_vars(tsb), \".model\", \".type\", \"RMSE\", \"MAE\", \"MAPE\", \"MASE\"))\\n');
    echo('acc_fab <- acc_fab[, keep_acc, drop = FALSE]\\n');
    echo('for (cn in intersect(c(\"RMSE\", \"MAE\", \"MAPE\", \"MASE\"), colnames(acc_fab))) acc_fab[[cn]] <- round(acc_fab[[cn]], 4)\\n\\n');

    // Tabla de pronósticos conservando las llaves jerárquicas (agg_vec -> character)
    echo('fc_fab_tbl <- tryCatch({\\n');
    echo('  fable_forecast %>%\\n');
    echo('    fabletools::hilo(level = c(80, 95)) %>%\\n');
    echo('    fabletools::unpack_hilo(c(`80%`, `95%`)) %>%\\n');
    echo('    as.data.frame() %>%\\n');
    echo('    dplyr::mutate(dplyr::across(dplyr::where(~ inherits(.x, \"agg_vec\")), ~ ifelse(format(.x) == \"<aggregated>\", \"(Total)\", format(.x)))) %>%\\n');
    echo('    dplyr::select(dplyr::where(~ !is.list(.x) && !inherits(.x, \"distribution\")))\\n');
    echo('}, error = function(e) {\\n');
    echo('  df_tmp <- as.data.frame(fable_forecast)\\n');
    echo('  df_tmp[, vapply(df_tmp, function(c) !is.list(c) && !inherits(c, \"distribution\"), logical(1)), drop = FALSE]\\n');
    echo('})\\n');
    echo('fc_fab_tbl <- utils::head(fc_fab_tbl, 60)\\n\\n');


    // Gráfico inteligente: limitar a máximo 'max_plot' series si hay demasiadas llaves
    var default_tit = (hier_mode !== 'batch') ? 'Hierarchical Forecast (fable)' : 'Batch Forecast (fable)';
    var title_str = (main_tit !== '') ? main_tit : default_tit;

    echo('kv <- tsibble::key_vars(tsb)\\n');
    echo('if (length(kv) > 0) {\\n');
    echo('  key_df <- tsibble::key_data(tsb)\\n');
    echo('  if (nrow(key_df) > ' + max_plot + ') {\\n');
    if (hier_mode !== 'batch') {
        // Priorizar niveles agregados superiores en jerarquías
        echo('    n_aggs <- rowSums(vapply(key_df[, kv, drop = FALSE], fabletools::is_aggregated, logical(nrow(key_df))))\\n');
        echo('    sel_keys <- key_df[order(-n_aggs), kv, drop = FALSE][seq_len(' + max_plot + '), , drop = FALSE]\\n');
    } else {
        echo('    sel_keys <- key_df[seq_len(' + max_plot + '), kv, drop = FALSE]\\n');
    }
    echo('    fbl_plot <- dplyr::semi_join(fable_forecast, sel_keys, by = kv)\\n');
    echo('    tsb_plot <- dplyr::semi_join(tsb, sel_keys, by = kv)\\n');
    echo('  } else {\\n');
    echo('    fbl_plot <- fable_forecast; tsb_plot <- tsb\\n');
    echo('  }\\n');
    echo('} else {\\n');
    echo('  fbl_plot <- fable_forecast; tsb_plot <- tsb\\n');
    echo('}\\n\\n');

    echo('p <- ggplot2::autoplot(fbl_plot, tsb_plot) + ggplot2::theme_' + theme + '() +\\n');
    echo('     ggplot2::scale_y_continuous(n.breaks = 3) +\\n');
    echo('     ggplot2::labs(title = \"' + title_str + '\") + ggplot2::theme(legend.position = \"bottom\")\\n');
  "

  js_print_fab <- "
    var w = getValue('fab_plot_w');
    var h = getValue('fab_plot_h');
    var res = getValue('fab_plot_res');

    if (typeof is_preview !== 'undefined' && is_preview) {
        echo('print(p)\\n');
    }

    if (typeof is_preview === 'undefined' || !is_preview) {
        echo('rk.header(\"2. Batch & Hierarchical Forecasting (fable)\")\\n');

        echo('rk.graph.on(width = ' + w + ', height = ' + h + ', res = ' + res + ')\\n');
        echo('print(p)\\n');
        echo('rk.graph.off()\\n\\n');

        echo('rk.header(\"In-Sample Accuracy by Series / Level\", level = 3)\\n');
        echo('rk.print(utils::head(acc_fab, 100))\\n');

        echo('rk.header(\"Forecast Table (Top 60 rows)\", level = 3)\\n');
        echo('rk.print(fc_fab_tbl)\\n');

        if (getValue('fab_save_fc.active') || getValue('fab_save_mod.active') || getValue('fab_save_plot.active')) {
            echo('rk.print(\"<hr>\")\\n');
        }
        if (getValue('fab_save_fc.active')) {
            echo('rk.print(paste0(\"<b>Fable forecast saved as: </b><code>\", \"' + getValue('fab_save_fc') + '\", \"</code><br>\"))\\n');
        }
        if (getValue('fab_save_mod.active')) {
            echo('rk.print(paste0(\"<b>Mable models saved as: </b><code>\", \"' + getValue('fab_save_mod') + '\", \"</code><br>\"))\\n');
        }
        if (getValue('fab_save_plot.active')) {
            echo('p$plot_env <- emptyenv()\\n');
            echo('fable_plot <- p\\n');
            echo('rk.print(paste0(\"<b>Plot object (ggplot2) saved as: </b><code>\", \"' + getValue('fab_save_plot') + '\", \"</code>\"))\\n');
        }
    }
  "

  comp_batch <- rk.plugin.component(
    "2. Batch & Hierarchical Forecasting (fable)",
    xml = list(dialog = dialog_fab, logic = logic_fab),
    js = list(require = c("fable", "fabletools", "tsibble", "feasts", "dplyr", "ggplot2", "future"), globals = js_helpers, calculate = js_calc_fab, printout = js_print_fab),
    hierarchy = h_pro
  )

  # =========================================================================================
  # 4. MODULE 3: 3. Time-Series Cross-Validation (Backtesting)
  # =========================================================================================

  # --- UI Elements ---
  cv_vs <- rk.XML.varselector(id.name = "cv_vs")

  cv_mode <- rk.XML.radio("Backtesting Engine", options = list(
    "Univariate ts Object (forecast::tsCV — Error by Horizon h)" = list(val = "ts", chk = TRUE),
    "Data Frame (tsibble::stretch_tsibble + fable)" = list(val = "fable")
  ), id.name = "cv_mode")

  # TS Mode
  cv_ts <- rk.XML.varslot("Time Series Object (ts)", source = "cv_vs", classes = "ts", required = FALSE, id.name = "cv_ts")
  cv_window <- rk.XML.spinbox("Sliding Window Size (0 = Expanding Window)", min = 0, max = 500, initial = 0, real = FALSE, id.name = "cv_window")
  frm_cv_ts <- rk.XML.frame(cv_ts, cv_window, label = "Univariate tsCV Input", id.name = "frm_cv_ts")

  # Fable Mode
  cv_df <- rk.XML.varslot("Data Frame", source = "cv_vs", classes = "data.frame", required = FALSE, id.name = "cv_df")
  cv_idx <- rk.XML.varslot("Time Index Column", source = "cv_vs", required = FALSE, id.name = "cv_idx")
  cv_y <- rk.XML.varslot("Target Variable (Y, Numeric)", source = "cv_vs", classes = c("numeric", "integer"), required = FALSE, id.name = "cv_y")
  cv_gran <- rk.XML.dropdown("Time Granularity", options = list(
    "Monthly (yearmonth)" = list(val = "month", chk = TRUE),
    "Quarterly (yearquarter)" = list(val = "quarter"),
    "Weekly (yearweek)" = list(val = "week"),
    "Daily (as.Date)" = list(val = "day"),
    "Native / Numeric" = list(val = "raw")
  ), id.name = "cv_gran")
  cv_step <- rk.XML.spinbox("Step Between Rolling Folds (.step)", min = 1, max = 60, initial = 3, real = FALSE, id.name = "cv_step")
  frm_cv_df <- rk.XML.frame(cv_df, cv_idx, cv_gran, cv_y, cv_step, label = "tsibble / fable Rolling Input", id.name = "frm_cv_df")

  # Shared CV Parameters & Candidate Models
  cv_init <- rk.XML.spinbox("Initial Training Window Size (Minimum observations)", min = 6, max = 1000, initial = 36, real = FALSE, id.name = "cv_init")
  cv_h <- rk.XML.spinbox("Forecast Horizon per Fold (h)", min = 1, max = 60, initial = 6, real = FALSE, id.name = "cv_h")

  cv_mod_arima <- rk.XML.cbox("Auto-ARIMA", value = "1", chk = TRUE, id.name = "cv_mod_arima")
  cv_mod_ets <- rk.XML.cbox("ETS (Exponential Smoothing)", value = "1", chk = TRUE, id.name = "cv_mod_ets")
  cv_mod_snaive <- rk.XML.cbox("Seasonal Naive (Benchmark)", value = "1", chk = TRUE, id.name = "cv_mod_snaive")
  cv_mod_extra <- rk.XML.cbox("Additional Model (TBATS for ts / TSLM for fable)", value = "1", chk = FALSE, id.name = "cv_mod_extra")
  frm_cv_mods <- rk.XML.frame(cv_mod_arima, cv_mod_ets, cv_mod_snaive, cv_mod_extra, label = "Candidate Models to Compete")

  # Plot & Output
  cv_theme <- rk.XML.dropdown("Plot Theme (ggplot2)", options = list(
    "Minimal (Clean business look)" = list(val = "minimal", chk = TRUE),
    "Classic (Scientific)" = list(val = "classic"),
    "Black & White (Grid)" = list(val = "bw")
  ), id.name = "cv_theme")
  cv_plot_main <- rk.XML.input("Main Title (Leave empty for default)", id.name = "cv_plot_main")

  cv_save_tbl <- rk.XML.saveobj("Save Backtesting Accuracy Table as", initial = "cv_accuracy", chk = TRUE, id.name = "cv_save_tbl")
  cv_plot_w <- rk.XML.spinbox("HTML Plot Width (pixels)", min = 100, max = 5000, initial = 850, real = FALSE, id.name = "cv_plot_w")
  cv_plot_h <- rk.XML.spinbox("HTML Plot Height (pixels)", min = 100, max = 5000, initial = 550, real = FALSE, id.name = "cv_plot_h")
  cv_plot_res <- rk.XML.spinbox("Resolution (DPI)", min = 72, max = 600, initial = 120, real = FALSE, id.name = "cv_plot_res")
  frm_cv_graph <- rk.XML.frame(rk.XML.row(cv_plot_w, cv_plot_h, cv_plot_res), label = "HTML Graphics Size & Resolution")
  cv_save_plot <- rk.XML.saveobj("Save Backtesting Plot (ggplot2) as", initial = "cv_plot", chk = FALSE, id.name = "cv_save_plot")

  # --- UI Logic (Auto-Focus dual sin &&) ---
  cond_cv_ts <- rk.XML.convert(sources = list(string = cv_mode), mode = c(equals = "ts"), id.name = "cond_cv_ts")
  cond_cv_df <- rk.XML.convert(sources = list(string = cv_mode), mode = c(equals = "fable"), id.name = "cond_cv_df")

  cv_gui_script <- XiMpLe::XMLNode("script", '
    gui.addChangeCommand("cv_mode.string", "update_cv_root()");
    gui.addChangeCommand("cv_df.available", "update_cv_root()");
    function update_cv_root() {
       var mode = gui.getValue("cv_mode.string");
       var df = gui.getValue("cv_df.available");
       if (mode === "fable") {
          if (df !== "") {
             gui.setValue("cv_vs.root", df);
          } else {
             gui.setValue("cv_vs.root", "");
          }
       } else {
          gui.setValue("cv_vs.root", "");
       }
    }
  ')

  logic_cv <- rk.XML.logic(
    cond_cv_ts, cond_cv_df,
    rk.XML.connect(governor = cond_cv_ts, client = frm_cv_ts, set = "enabled"),
    rk.XML.connect(governor = cond_cv_df, client = frm_cv_df, set = "enabled"),
    cv_gui_script
  )

  # --- Layout ---
  tab_cv <- rk.XML.tabbook(tabs = list(
    "1. Data & Engine" = rk.XML.col(cv_mode, frm_cv_ts, frm_cv_df, rk.XML.stretch()),
    "2. Rolling Windows & Models" = rk.XML.col(rk.XML.frame(cv_init, cv_h, label = "Cross-Validation Horizon"), frm_cv_mods, rk.XML.stretch()),
    "3. Plot & Output" = rk.XML.col(
      rk.XML.frame(cv_theme, cv_plot_main, label = "Plot Customization"),
      frm_cv_graph,
      rk.XML.frame(cv_save_tbl, cv_save_plot, label = "Save Objects to Workspace"),
      rk.XML.stretch()
    )
  ))

  dialog_cv <- rk.XML.dialog(
    rk.XML.row(cv_vs, rk.XML.col(tab_cv)),
    label = "3. Time-Series Cross-Validation (Backtesting)"
  )

  # --- JavaScript ---
  js_calc_cv <- "
    var mode = getValue('cv_mode');
    var init_n = getValue('cv_init');
    var h = getValue('cv_h');
    var do_arima  = getValue('cv_mod_arima') === '1';
    var do_ets    = getValue('cv_mod_ets') === '1';
    var do_snaive = getValue('cv_mod_snaive') === '1';
    var do_extra  = getValue('cv_mod_extra') === '1';

    var theme = getValue('cv_theme');
    var main_tit = cleanStr(getValue('cv_plot_main'));

    if (!do_arima && !do_ets && !do_snaive && !do_extra) {
        echo('stop(\"Please select at least one candidate model for backtesting.\")\\n');
    }

    if (mode === 'ts') {
        var ts_obj = getValue('cv_ts');
        var win_sz = getValue('cv_window');
        var win_arg = (win_sz > 0) ? ', window = ' + win_sz : '';

        echo('y_ts <- ' + ts_obj + '\\n');
        echo('if (anyNA(y_ts)) stop(\"Series contains NAs. Please impute missing values first.\")\\n');
        echo('if (length(y_ts) <= ' + init_n + ' + ' + h + ') stop(\"Series is too short for the chosen Initial Window + Horizon.\")\\n');
        echo('y_vec <- as.numeric(y_ts); n_y <- length(y_vec)\\n\\n');

        echo('eval_tscv <- function(e_res, model_name) {\\n');
        echo('  e_mat <- if (is.null(dim(e_res))) matrix(e_res, ncol = 1) else as.matrix(e_res)\\n');
        echo('  rmse_tot <- round(sqrt(mean(e_mat^2, na.rm = TRUE)), 4)\\n');
        echo('  mae_tot  <- round(mean(abs(e_mat), na.rm = TRUE), 4)\\n');
        echo('  ape_all <- numeric(0)\\n');
        echo('  for (j in seq_len(ncol(e_mat))) {\\n');
        echo('    y_tgt <- if (j < n_y) c(y_vec[(j + 1):n_y], rep(NA_real_, j)) else rep(NA_real_, n_y)\\n');
        echo('    idx_ok <- !is.na(e_mat[, j]) & !is.na(y_tgt) & y_tgt != 0\\n');
        echo('    if (any(idx_ok)) ape_all <- c(ape_all, abs(e_mat[idx_ok, j] / y_tgt[idx_ok]) * 100)\\n');
        echo('  }\\n');
        echo('  mape_tot <- if (length(ape_all) > 0) round(mean(ape_all), 4) else NA_real_\\n');
        echo('  by_h <- data.frame(Model = model_name, Horizon = seq_len(ncol(e_mat)), RMSE = round(sqrt(colMeans(e_mat^2, na.rm = TRUE)), 4))\\n');
        echo('  list(summary = data.frame(Model = model_name, RMSE = rmse_tot, MAE = mae_tot, MAPE = mape_tot), by_h = by_h)\\n');
        echo('}\\n\\n');

        echo('cv_list <- list(); by_h_list <- list()\\n');
        if (do_arima) {
            echo('f_arima <- function(x, h) forecast::forecast(forecast::auto.arima(x), h = h)\\n');
            echo('e_arima <- forecast::tsCV(y_ts, forecastfunction = f_arima, h = ' + h + win_arg + ', initial = ' + init_n + ')\\n');
            echo('r_a <- eval_tscv(e_arima, \"Auto-ARIMA\"); cv_list[[length(cv_list)+1]] <- r_a$summary; by_h_list[[length(by_h_list)+1]] <- r_a$by_h\\n');
        }
        if (do_ets) {
            echo('f_ets <- function(x, h) forecast::forecast(forecast::ets(x), h = h)\\n');
            echo('e_ets <- forecast::tsCV(y_ts, forecastfunction = f_ets, h = ' + h + win_arg + ', initial = ' + init_n + ')\\n');
            echo('r_e <- eval_tscv(e_ets, \"ETS\"); cv_list[[length(cv_list)+1]] <- r_e$summary; by_h_list[[length(by_h_list)+1]] <- r_e$by_h\\n');
        }
        if (do_snaive) {
            echo('f_sn <- function(x, h) forecast::snaive(x, h = h)\\n');
            echo('e_sn <- forecast::tsCV(y_ts, forecastfunction = f_sn, h = ' + h + win_arg + ', initial = ' + init_n + ')\\n');
            echo('r_s <- eval_tscv(e_sn, \"Seasonal Naive\"); cv_list[[length(cv_list)+1]] <- r_s$summary; by_h_list[[length(by_h_list)+1]] <- r_s$by_h\\n');
        }
        if (do_extra) {
            echo('f_tb <- function(x, h) forecast::forecast(forecast::tbats(x), h = h)\\n');
            echo('e_tb <- forecast::tsCV(y_ts, forecastfunction = f_tb, h = ' + h + win_arg + ', initial = ' + init_n + ')\\n');
            echo('r_t <- eval_tscv(e_tb, \"TBATS\"); cv_list[[length(cv_list)+1]] <- r_t$summary; by_h_list[[length(by_h_list)+1]] <- r_t$by_h\\n');
        }

        echo('cv_accuracy <- do.call(rbind, cv_list)\\n');
        echo('cv_accuracy <- cv_accuracy[order(cv_accuracy$RMSE), , drop = FALSE]\\n');
        echo('rownames(cv_accuracy) <- NULL\\n');
        echo('cv_by_h <- do.call(rbind, by_h_list)\\n\\n');

        var title_str = (main_tit !== '') ? main_tit : 'Backtesting Error by Horizon (tsCV): ' + ts_obj;
        echo('p <- ggplot2::ggplot(cv_by_h, ggplot2::aes(x = Horizon, y = RMSE, color = Model, group = Model)) +\\n');
        echo('     ggplot2::geom_line(linewidth = 1) + ggplot2::geom_point(size = 2) +\\n');
        echo('     ggplot2::theme_' + theme + '() + ggplot2::theme(legend.position = \"bottom\") +\\n');
        echo('     ggplot2::labs(title = \"' + title_str + '\", x = \"Forecast Horizon (h)\", y = \"Out-of-Sample RMSE\")\\n');

    } else {
        // fable / stretch_tsibble mode
        var df = getValue('cv_df');
        var idx_col = parseVar(getValue('cv_idx'));
        var gran = getValue('cv_gran');
        var y_col = parseVar(getValue('cv_y'));
        var step_n = getValue('cv_step');

        echo('df_cv <- as.data.frame(' + df + ')\\n');
        if (gran === 'month') {
            echo('df_cv[[\"' + idx_col + '\"]] <- tsibble::yearmonth(df_cv[[\"' + idx_col + '\"]])\\n');
        } else if (gran === 'quarter') {
            echo('df_cv[[\"' + idx_col + '\"]] <- tsibble::yearquarter(df_cv[[\"' + idx_col + '\"]])\\n');
        } else if (gran === 'week') {
            echo('df_cv[[\"' + idx_col + '\"]] <- tsibble::yearweek(df_cv[[\"' + idx_col + '\"]])\\n');
        } else if (gran === 'day') {
            echo('df_cv[[\"' + idx_col + '\"]] <- as.Date(df_cv[[\"' + idx_col + '\"]])\\n');
        }

        echo('tsb_full <- tsibble::as_tsibble(df_cv, index = `' + idx_col + '`)\\n');
        echo('cv_folds <- tsb_full %>% tsibble::stretch_tsibble(.init = ' + init_n + ', .step = ' + step_n + ')\\n\\n');

        var y_bt = '`' + y_col + '`';
        var m_args = [];
        if (do_arima)  m_args.push('Auto_ARIMA = fable::ARIMA(' + y_bt + ')');
        if (do_ets)    m_args.push('ETS = fable::ETS(' + y_bt + ')');
        if (do_snaive) m_args.push('SNAIVE = fable::SNAIVE(' + y_bt + ')');
        if (do_extra)  m_args.push('TSLM = fable::TSLM(' + y_bt + ' ~ trend() + season())');

        echo('cv_fc <- cv_folds %>%\\n');
        echo('  fabletools::model(' + m_args.join(', ') + ') %>%\\n');
        echo('  fabletools::forecast(h = ' + h + ')\\n\\n');

        echo('acc_raw <- suppressWarnings(as.data.frame(fabletools::accuracy(cv_fc, tsb_full)))\\n');
        echo('keep_c <- intersect(colnames(acc_raw), c(\".model\", \".type\", \"RMSE\", \"MAE\", \"MAPE\", \"MASE\"))\\n');
        echo('cv_accuracy <- acc_raw[, keep_c, drop = FALSE]\\n');
        echo('colnames(cv_accuracy)[colnames(cv_accuracy) == \".model\"] <- \"Model\"\\n');
        echo('for (cn in intersect(c(\"RMSE\", \"MAE\", \"MAPE\", \"MASE\"), colnames(cv_accuracy))) cv_accuracy[[cn]] <- round(cv_accuracy[[cn]], 4)\\n');
        echo('cv_accuracy <- cv_accuracy[order(cv_accuracy$RMSE), , drop = FALSE]\\n');
        echo('rownames(cv_accuracy) <- NULL\\n\\n');

        var title_str_f = (main_tit !== '') ? main_tit : 'Rolling-Origin Backtesting RMSE: ' + y_col;
        echo('p <- ggplot2::ggplot(cv_accuracy, ggplot2::aes(x = stats::reorder(Model, -RMSE), y = RMSE, fill = Model)) +\\n');
        echo('     ggplot2::geom_col(show.legend = FALSE, width = 0.6) + ggplot2::coord_flip() +\\n');
        echo('     ggplot2::theme_' + theme + '() +\\n');
        echo('     ggplot2::labs(title = \"' + title_str_f + '\", x = \"Model\", y = \"Out-of-Sample RMSE\")\\n');
    }
  "

  js_print_cv <- "
    var w = getValue('cv_plot_w');
    var h = getValue('cv_plot_h');
    var res = getValue('cv_plot_res');

    if (typeof is_preview === 'undefined' || !is_preview) {
        echo('rk.header(\"3. Time-Series Cross-Validation (Backtesting)\")\\n');

        echo('rk.graph.on(width = ' + w + ', height = ' + h + ', res = ' + res + ')\\n');
        echo('print(p)\\n');
        echo('rk.graph.off()\\n\\n');

        echo('rk.header(\"Out-of-Sample Backtesting Accuracy (Ranked by RMSE)\", level = 3)\\n');
        echo('rk.print(cv_accuracy)\\n');

        if (getValue('cv_save_tbl.active') || getValue('cv_save_plot.active')) {
            echo('rk.print(\"<hr>\")\\n');
        }
        if (getValue('cv_save_tbl.active')) {
            echo('rk.print(paste0(\"<b>Accuracy table saved as: </b><code>\", \"' + getValue('cv_save_tbl') + '\", \"</code><br>\"))\\n');
        }
        if (getValue('cv_save_plot.active')) {
            echo('p$plot_env <- emptyenv()\\n');
            echo('cv_plot <- p\\n');
            echo('rk.print(paste0(\"<b>Plot object (ggplot2) saved as: </b><code>\", \"' + getValue('cv_save_plot') + '\", \"</code>\"))\\n');
        }
    }
  "

  comp_cv <- rk.plugin.component(
    "3. Time-Series Cross-Validation (Backtesting)",
    xml = list(dialog = dialog_cv, logic = logic_cv),
    js = list(require = c("forecast", "fable", "fabletools", "tsibble", "dplyr", "ggplot2"), globals = js_helpers, calculate = js_calc_cv, printout = js_print_cv),
    hierarchy = h_pro
  )

  # =========================================================================================
  # 5. BUILD SKELETON
  # =========================================================================================

  unlink("rk.ts.pro", recursive = TRUE)

  rk.plugin.skeleton(
    about = package_about,
    path = ".",
    xml = list(dialog = dialog_pro, logic = logic_pro),
    js = list(
      require = c("forecast", "ggplot2"),
      globals = js_helpers,
      calculate = js_calc_pro,
      printout = js_print_pro
    ),
    components = list(comp_batch, comp_cv),
    pluginmap = list(
      name = "1. Multiple Seasonality & Holidays (Prophet / TBATS)",
      hierarchy = h_pro
    ),
    dependencies = dependencies_node,
    create = c("pmap", "xml", "js", "desc", "rkh"),
    overwrite = TRUE,
    load = TRUE,
    show = FALSE
  )

  cat("\nPackage 'rk.ts.pro' generated successfully.\n")
})
