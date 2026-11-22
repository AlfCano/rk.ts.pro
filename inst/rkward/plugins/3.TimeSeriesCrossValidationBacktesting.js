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
  



function preprocess(is_preview){
	// add requirements etc. here
	echo("require(forecast)\n");	echo("require(fable)\n");	echo("require(fabletools)\n");	echo("require(tsibble)\n");	echo("require(dplyr)\n");	echo("require(ggplot2)\n");
}

function calculate(is_preview){
	// read in variables from dialog


	// the R code to be evaluated

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
        echo('stop("Please select at least one candidate model for backtesting.")\n');
    }

    if (mode === 'ts') {
        var ts_obj = getValue('cv_ts');
        var win_sz = getValue('cv_window');
        var win_arg = (win_sz > 0) ? ', window = ' + win_sz : '';

        echo('y_ts <- ' + ts_obj + '\n');
        echo('if (anyNA(y_ts)) stop("Series contains NAs. Please impute missing values first.")\n');
        echo('if (length(y_ts) <= ' + init_n + ' + ' + h + ') stop("Series is too short for the chosen Initial Window + Horizon.")\n');
        echo('y_vec <- as.numeric(y_ts); n_y <- length(y_vec)\n\n');

        echo('eval_tscv <- function(e_res, model_name) {\n');
        echo('  e_mat <- if (is.null(dim(e_res))) matrix(e_res, ncol = 1) else as.matrix(e_res)\n');
        echo('  rmse_tot <- round(sqrt(mean(e_mat^2, na.rm = TRUE)), 4)\n');
        echo('  mae_tot  <- round(mean(abs(e_mat), na.rm = TRUE), 4)\n');
        echo('  ape_all <- numeric(0)\n');
        echo('  for (j in seq_len(ncol(e_mat))) {\n');
        echo('    y_tgt <- if (j < n_y) c(y_vec[(j + 1):n_y], rep(NA_real_, j)) else rep(NA_real_, n_y)\n');
        echo('    idx_ok <- !is.na(e_mat[, j]) & !is.na(y_tgt) & y_tgt != 0\n');
        echo('    if (any(idx_ok)) ape_all <- c(ape_all, abs(e_mat[idx_ok, j] / y_tgt[idx_ok]) * 100)\n');
        echo('  }\n');
        echo('  mape_tot <- if (length(ape_all) > 0) round(mean(ape_all), 4) else NA_real_\n');
        echo('  by_h <- data.frame(Model = model_name, Horizon = seq_len(ncol(e_mat)), RMSE = round(sqrt(colMeans(e_mat^2, na.rm = TRUE)), 4))\n');
        echo('  list(summary = data.frame(Model = model_name, RMSE = rmse_tot, MAE = mae_tot, MAPE = mape_tot), by_h = by_h)\n');
        echo('}\n\n');

        echo('cv_list <- list(); by_h_list <- list()\n');
        if (do_arima) {
            echo('f_arima <- function(x, h) forecast::forecast(forecast::auto.arima(x), h = h)\n');
            echo('e_arima <- forecast::tsCV(y_ts, forecastfunction = f_arima, h = ' + h + win_arg + ', initial = ' + init_n + ')\n');
            echo('r_a <- eval_tscv(e_arima, "Auto-ARIMA"); cv_list[[length(cv_list)+1]] <- r_a$summary; by_h_list[[length(by_h_list)+1]] <- r_a$by_h\n');
        }
        if (do_ets) {
            echo('f_ets <- function(x, h) forecast::forecast(forecast::ets(x), h = h)\n');
            echo('e_ets <- forecast::tsCV(y_ts, forecastfunction = f_ets, h = ' + h + win_arg + ', initial = ' + init_n + ')\n');
            echo('r_e <- eval_tscv(e_ets, "ETS"); cv_list[[length(cv_list)+1]] <- r_e$summary; by_h_list[[length(by_h_list)+1]] <- r_e$by_h\n');
        }
        if (do_snaive) {
            echo('f_sn <- function(x, h) forecast::snaive(x, h = h)\n');
            echo('e_sn <- forecast::tsCV(y_ts, forecastfunction = f_sn, h = ' + h + win_arg + ', initial = ' + init_n + ')\n');
            echo('r_s <- eval_tscv(e_sn, "Seasonal Naive"); cv_list[[length(cv_list)+1]] <- r_s$summary; by_h_list[[length(by_h_list)+1]] <- r_s$by_h\n');
        }
        if (do_extra) {
            echo('f_tb <- function(x, h) forecast::forecast(forecast::tbats(x), h = h)\n');
            echo('e_tb <- forecast::tsCV(y_ts, forecastfunction = f_tb, h = ' + h + win_arg + ', initial = ' + init_n + ')\n');
            echo('r_t <- eval_tscv(e_tb, "TBATS"); cv_list[[length(cv_list)+1]] <- r_t$summary; by_h_list[[length(by_h_list)+1]] <- r_t$by_h\n');
        }

        echo('cv_accuracy <- do.call(rbind, cv_list)\n');
        echo('cv_accuracy <- cv_accuracy[order(cv_accuracy$RMSE), , drop = FALSE]\n');
        echo('rownames(cv_accuracy) <- NULL\n');
        echo('cv_by_h <- do.call(rbind, by_h_list)\n\n');

        var title_str = (main_tit !== '') ? main_tit : 'Backtesting Error by Horizon (tsCV): ' + ts_obj;
        echo('p <- ggplot2::ggplot(cv_by_h, ggplot2::aes(x = Horizon, y = RMSE, color = Model, group = Model)) +\n');
        echo('     ggplot2::geom_line(linewidth = 1) + ggplot2::geom_point(size = 2) +\n');
        echo('     ggplot2::theme_' + theme + '() + ggplot2::theme(legend.position = "bottom") +\n');
        echo('     ggplot2::labs(title = "' + title_str + '", x = "Forecast Horizon (h)", y = "Out-of-Sample RMSE")\n');

    } else {
        // fable / stretch_tsibble mode
        var df = getValue('cv_df');
        var idx_col = parseVar(getValue('cv_idx'));
        var gran = getValue('cv_gran');
        var y_col = parseVar(getValue('cv_y'));
        var step_n = getValue('cv_step');

        echo('df_cv <- as.data.frame(' + df + ')\n');
        if (gran === 'month') {
            echo('df_cv[["' + idx_col + '"]] <- tsibble::yearmonth(df_cv[["' + idx_col + '"]])\n');
        } else if (gran === 'quarter') {
            echo('df_cv[["' + idx_col + '"]] <- tsibble::yearquarter(df_cv[["' + idx_col + '"]])\n');
        } else if (gran === 'week') {
            echo('df_cv[["' + idx_col + '"]] <- tsibble::yearweek(df_cv[["' + idx_col + '"]])\n');
        } else if (gran === 'day') {
            echo('df_cv[["' + idx_col + '"]] <- as.Date(df_cv[["' + idx_col + '"]])\n');
        }

        echo('tsb_full <- tsibble::as_tsibble(df_cv, index = `' + idx_col + '`)\n');
        echo('cv_folds <- tsb_full %>% tsibble::stretch_tsibble(.init = ' + init_n + ', .step = ' + step_n + ')\n\n');

        var y_bt = '`' + y_col + '`';
        var m_args = [];
        if (do_arima)  m_args.push('Auto_ARIMA = fable::ARIMA(' + y_bt + ')');
        if (do_ets)    m_args.push('ETS = fable::ETS(' + y_bt + ')');
        if (do_snaive) m_args.push('SNAIVE = fable::SNAIVE(' + y_bt + ')');
        if (do_extra)  m_args.push('TSLM = fable::TSLM(' + y_bt + ' ~ trend() + season())');

        echo('cv_fc <- cv_folds %>%\n');
        echo('  fabletools::model(' + m_args.join(', ') + ') %>%\n');
        echo('  fabletools::forecast(h = ' + h + ')\n\n');

        echo('acc_raw <- suppressWarnings(as.data.frame(fabletools::accuracy(cv_fc, tsb_full)))\n');
        echo('keep_c <- intersect(colnames(acc_raw), c(".model", ".type", "RMSE", "MAE", "MAPE", "MASE"))\n');
        echo('cv_accuracy <- acc_raw[, keep_c, drop = FALSE]\n');
        echo('colnames(cv_accuracy)[colnames(cv_accuracy) == ".model"] <- "Model"\n');
        echo('for (cn in intersect(c("RMSE", "MAE", "MAPE", "MASE"), colnames(cv_accuracy))) cv_accuracy[[cn]] <- round(cv_accuracy[[cn]], 4)\n');
        echo('cv_accuracy <- cv_accuracy[order(cv_accuracy$RMSE), , drop = FALSE]\n');
        echo('rownames(cv_accuracy) <- NULL\n\n');

        var title_str_f = (main_tit !== '') ? main_tit : 'Rolling-Origin Backtesting RMSE: ' + y_col;
        echo('p <- ggplot2::ggplot(cv_accuracy, ggplot2::aes(x = stats::reorder(Model, -RMSE), y = RMSE, fill = Model)) +\n');
        echo('     ggplot2::geom_col(show.legend = FALSE, width = 0.6) + ggplot2::coord_flip() +\n');
        echo('     ggplot2::theme_' + theme + '() +\n');
        echo('     ggplot2::labs(title = "' + title_str_f + '", x = "Model", y = "Out-of-Sample RMSE")\n');
    }
  
}

function printout(is_preview){
	// printout the results
	new Header(i18n("3. Time-Series Cross-Validation (Backtesting) results")).print();

    var w = getValue('cv_plot_w');
    var h = getValue('cv_plot_h');
    var res = getValue('cv_plot_res');

    if (typeof is_preview === 'undefined' || !is_preview) {
        echo('rk.header("3. Time-Series Cross-Validation (Backtesting)")\n');

        echo('rk.graph.on(width = ' + w + ', height = ' + h + ', res = ' + res + ')\n');
        echo('print(p)\n');
        echo('rk.graph.off()\n\n');

        echo('rk.header("Out-of-Sample Backtesting Accuracy (Ranked by RMSE)", level = 3)\n');
        echo('rk.print(cv_accuracy)\n');

        if (getValue('cv_save_tbl.active') || getValue('cv_save_plot.active')) {
            echo('rk.print("<hr>")\n');
        }
        if (getValue('cv_save_tbl.active')) {
            echo('rk.print(paste0("<b>Accuracy table saved as: </b><code>", "' + getValue('cv_save_tbl') + '", "</code><br>"))\n');
        }
        if (getValue('cv_save_plot.active')) {
            echo('p$plot_env <- emptyenv()\n');
            echo('cv_plot <- p\n');
            echo('rk.print(paste0("<b>Plot object (ggplot2) saved as: </b><code>", "' + getValue('cv_save_plot') + '", "</code>"))\n');
        }
    }
  
	//// save result object
	// read in saveobject variables
	var cvSaveTbl = getValue("cv_save_tbl");
	var cvSaveTblActive = getValue("cv_save_tbl.active");
	var cvSaveTblParent = getValue("cv_save_tbl.parent");	var cvSavePlot = getValue("cv_save_plot");
	var cvSavePlotActive = getValue("cv_save_plot.active");
	var cvSavePlotParent = getValue("cv_save_plot.parent");
	// assign object to chosen environment
	if(cvSaveTblActive) {
		echo(".GlobalEnv$" + cvSaveTbl + " <- cv_accuracy\n");
	}
	if(cvSavePlotActive) {
		echo(".GlobalEnv$" + cvSavePlot + " <- cv_plot\n");
	}

}

