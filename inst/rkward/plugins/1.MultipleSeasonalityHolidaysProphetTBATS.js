// this code was generated using the rkwarddev package.
// perhaps don't make changes here, but in the rkwarddev script instead!

// define variables globally
    function cleanStr(val) {
        if(!val) return '';
        return val.replace(/'/g, "\\'").replace(/"/g, '\\"');
    }

    function parseVar(fullPath) {
        if (!fullPath) return '';
        var raw_col = '';
        if (fullPath.indexOf('[[') > -1) {
            var parts = fullPath.split('[[');
            var inner = parts[1].replace(']]', '');
            raw_col = inner.replace(/["']/g, '');
        } else if (fullPath.indexOf('$') > -1) {
            raw_col = fullPath.split('$')[1];
        } else {
            raw_col = fullPath;
        }
        return raw_col;
    }
  

function preview(){
	preprocess(true);
	calculate(true);
	printout(true);
}

function preprocess(is_preview){
	// add requirements etc. here
	if(is_preview) {
		echo("if(!base::require(forecast)){stop(" + i18n("Preview not available, because package forecast is not installed or cannot be loaded.") + ")}\n");
	} else {
		echo("require(forecast)\n");
	}	if(is_preview) {
		echo("if(!base::require(ggplot2)){stop(" + i18n("Preview not available, because package ggplot2 is not installed or cannot be loaded.") + ")}\n");
	} else {
		echo("require(ggplot2)\n");
	}
}

function calculate(is_preview){
	// read in variables from dialog


	// the R code to be evaluated

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
            echo('stop("Prophet requires a Date / Datetime column.")\n');
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

        echo('if (!requireNamespace("prophet", quietly = TRUE)) stop("Package prophet is required for the Prophet engine.")\n');
        echo('suppressPackageStartupMessages(require(prophet))\n\n');

        echo('ds_raw <- ' + df + '[["' + ds_col + '"]]\n');
        echo('if (is.character(ds_raw) || is.factor(ds_raw)) {\n');
        echo('  ds_chr <- as.character(ds_raw)\n');
        echo('  ds_parsed <- if (any(grepl(":", ds_chr))) as.POSIXct(ds_chr) else as.Date(ds_chr)\n');
        echo('} else { ds_parsed <- ds_raw }\n\n');

        echo('df_p <- data.frame(ds = ds_parsed, y = as.numeric(' + df + '[["' + y_col + '"]]))\n');
        if (growth === 'logistic') {
            echo('cap_val <- if (' + cap + ' > 0) ' + cap + ' else max(df_p$y, na.rm = TRUE) * 1.2\n');
            echo('df_p$cap <- cap_val\n');
        }

        var yr_arg = (yr_s === 'auto') ? '"auto"' : yr_s;
        var wk_arg = (wk_s === 'auto') ? '"auto"' : wk_s;
        var dy_arg = (dy_s === 'auto') ? '"auto"' : dy_s;

        echo('pro_model <- prophet::prophet(\n');
        echo('  growth = "' + growth + '",\n');
        echo('  seasonality.mode = "' + seas_mode + '",\n');
        echo('  yearly.seasonality = ' + yr_arg + ',\n');
        echo('  weekly.seasonality = ' + wk_arg + ',\n');
        echo('  daily.seasonality = ' + dy_arg + ',\n');
        echo('  changepoint.prior.scale = ' + cp_s + '\n');
        echo(')\n');

        if (country !== 'none') {
            echo('pro_model <- prophet::add_country_holidays(pro_model, country_name = "' + country + '")\n');
        }

        echo('pro_model <- suppressMessages(prophet::fit.prophet(pro_model, df_p))\n');
        echo('future_df <- prophet::make_future_dataframe(pro_model, periods = ' + h + ', freq = "' + freq + '")\n');
        if (growth === 'logistic') {
            echo('future_df$cap <- cap_val\n');
        }
        echo('pro_forecast <- stats::predict(pro_model, future_df)\n\n');

        // Métricas in-sample
        echo('n_hist <- nrow(df_p)\n');
        echo('eval_df <- data.frame(y = df_p$y, yhat = pro_forecast$yhat[seq_len(n_hist)])\n');
        echo('eval_df <- stats::na.omit(eval_df)\n');
        echo('err_vec <- eval_df$y - eval_df$yhat\n');
        echo('rmse_v <- round(sqrt(mean(err_vec^2)), 4)\n');
        echo('mae_v  <- round(mean(abs(err_vec)), 4)\n');
        echo('mape_v <- round(mean(abs(err_vec[eval_df$y != 0] / eval_df$y[eval_df$y != 0])) * 100, 4)\n');
        echo('pro_acc <- data.frame(Engine = "Prophet", Country_Holidays = "' + country + '", RMSE = rmse_v, MAE = mae_v, MAPE = mape_v)\n\n');

        echo('hol_tbl <- if (!is.null(pro_model$train.holiday.names)) data.frame(Holidays_Modeled = pro_model$train.holiday.names) else data.frame()\n');
        echo('fc_tail <- utils::tail(pro_forecast[, c("ds", "yhat", "yhat_lower", "yhat_upper", "trend")], ' + h + ')\n');

        var title_str = (main_tit !== '') ? main_tit : 'Prophet Forecast: ' + y_col;
        echo('p <- plot(pro_model, pro_forecast) + ggplot2::theme_' + theme + '() +\n');
        echo('     ggplot2::labs(title = "' + title_str + '"');
        if (x_tit !== '') echo(', x = "' + x_tit + '"'); else echo(', x = "Date"');
        if (y_tit !== '') echo(', y = "' + y_tit + '"'); else echo(', y = "' + y_col + '"');
        echo(')\n');

    } else {
        // TBATS Engine
        var periods_str = cleanStr(getValue('pro_tbats_periods'));
        var start_str = cleanStr(getValue('pro_tbats_start'));
        if (periods_str === '') periods_str = '12';
        if (start_str === '') start_str = '2020, 1';

        echo('y_vec <- stats::na.omit(as.numeric(' + df + '[["' + y_col + '"]]))\n');
        echo('m_periods <- as.numeric(trimws(strsplit("' + periods_str + '", ",")[[1]]))\n');
        echo('m_start   <- as.numeric(trimws(strsplit("' + start_str + '", ",")[[1]]))\n');
        echo('ts_multi  <- forecast::msts(y_vec, seasonal.periods = m_periods, start = m_start)\n\n');

        echo('pro_model <- forecast::tbats(ts_multi)\n');
        echo('pro_forecast <- forecast::forecast(pro_model, h = ' + h + ')\n\n');

        echo('acc_t <- forecast::accuracy(pro_model)\n');
        echo('pro_acc <- data.frame(Engine = "TBATS", Seasonal_Periods = paste(m_periods, collapse = ", "), RMSE = round(acc_t[1, "RMSE"], 4), MAE = round(acc_t[1, "MAE"], 4), MAPE = round(acc_t[1, "MAPE"], 4))\n');
        echo('hol_tbl <- data.frame()\n');
        echo('fc_tail <- as.data.frame(pro_forecast)\n\n');

        var title_str_t = (main_tit !== '') ? main_tit : 'TBATS Multi-Seasonal Forecast: ' + y_col;
        echo('p <- ggplot2::autoplot(pro_forecast) + ggplot2::theme_' + theme + '() +\n');
        echo('     ggplot2::labs(title = "' + title_str_t + '"');
        if (x_tit !== '') echo(', x = "' + x_tit + '"');
        if (y_tit !== '') echo(', y = "' + y_tit + '"');
        echo(') + ggplot2::theme(legend.position = "bottom")\n');
    }
  
}

function printout(is_preview){
	// read in variables from dialog


	// printout the results
	if(!is_preview) {
		new Header(i18n("1. Multiple Seasonality & Holidays (Prophet / TBATS) results")).print();	
	}
    var engine = getValue('pro_engine');
    var do_comp = getValue('pro_comp_plot') === '1';
    var w = getValue('pro_plot_w');
    var h = getValue('pro_plot_h');
    var res = getValue('pro_plot_res');

    if (typeof is_preview !== 'undefined' && is_preview) {
        echo('print(p)\n');
    }

    if (typeof is_preview === 'undefined' || !is_preview) {
        echo('rk.header("1. Multiple Seasonality & Holidays Forecast")\n');

        echo('rk.graph.on(width = ' + w + ', height = ' + h + ', res = ' + res + ')\n');
        echo('print(p)\n');
        echo('rk.graph.off()\n\n');

        if (do_comp) {
            echo('rk.header("Model Components Breakdown", level = 3)\n');
            echo('rk.graph.on(width = ' + w + ', height = ' + (parseInt(h, 10) + 150) + ', res = ' + res + ')\n');
            if (engine === 'prophet') {
                echo('prophet::prophet_plot_components(pro_model, pro_forecast)\n');
            } else {
                echo('plot(pro_model, main = "TBATS Components")\n');
            }
            echo('rk.graph.off()\n\n');
        }

        echo('rk.header("In-Sample Accuracy Metrics", level = 3)\n');
        echo('rk.print(pro_acc)\n');

        echo('if (nrow(hol_tbl) > 0) {\n');
        echo('  rk.header("Modeled Country Holidays", level = 3)\n');
        echo('  rk.print(hol_tbl)\n');
        echo('}\n');

        echo('rk.header("Forecasted Values", level = 3)\n');
        echo('rk.print(fc_tail)\n');

        if (getValue('pro_save_fc.active') || getValue('pro_save_mod.active') || getValue('pro_save_plot.active')) {
            echo('rk.print("<hr>")\n');
        }
        if (getValue('pro_save_fc.active')) {
            echo('rk.print(paste0("<b>Forecast saved as: </b><code>", "' + getValue('pro_save_fc') + '", "</code><br>"))\n');
        }
        if (getValue('pro_save_mod.active')) {
            echo('rk.print(paste0("<b>Model saved as: </b><code>", "' + getValue('pro_save_mod') + '", "</code><br>"))\n');
        }
        if (getValue('pro_save_plot.active')) {
            echo('p$plot_env <- emptyenv()\n');
            echo('pro_plot <- p\n');
            echo('rk.print(paste0("<b>Plot object (ggplot2) saved as: </b><code>", "' + getValue('pro_save_plot') + '", "</code>"))\n');
        }
    }
  
	if(!is_preview) {
		//// save result object
		// read in saveobject variables
		var proSaveFc = getValue("pro_save_fc");
		var proSaveFcActive = getValue("pro_save_fc.active");
		var proSaveFcParent = getValue("pro_save_fc.parent");		var proSaveMod = getValue("pro_save_mod");
		var proSaveModActive = getValue("pro_save_mod.active");
		var proSaveModParent = getValue("pro_save_mod.parent");		var proSavePlot = getValue("pro_save_plot");
		var proSavePlotActive = getValue("pro_save_plot.active");
		var proSavePlotParent = getValue("pro_save_plot.parent");
		// assign object to chosen environment
		if(proSaveFcActive) {
			echo(".GlobalEnv$" + proSaveFc + " <- pro_forecast\n");
		}
		if(proSaveModActive) {
			echo(".GlobalEnv$" + proSaveMod + " <- pro_model\n");
		}
		if(proSavePlotActive) {
			echo(".GlobalEnv$" + proSavePlot + " <- pro_plot\n");
		}	
	}

}

