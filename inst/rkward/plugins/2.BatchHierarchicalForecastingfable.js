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
		echo("if(!base::require(fable)){stop(" + i18n("Preview not available, because package fable is not installed or cannot be loaded.") + ")}\n");
	} else {
		echo("require(fable)\n");
	}	if(is_preview) {
		echo("if(!base::require(fabletools)){stop(" + i18n("Preview not available, because package fabletools is not installed or cannot be loaded.") + ")}\n");
	} else {
		echo("require(fabletools)\n");
	}	if(is_preview) {
		echo("if(!base::require(tsibble)){stop(" + i18n("Preview not available, because package tsibble is not installed or cannot be loaded.") + ")}\n");
	} else {
		echo("require(tsibble)\n");
	}	if(is_preview) {
		echo("if(!base::require(feasts)){stop(" + i18n("Preview not available, because package feasts is not installed or cannot be loaded.") + ")}\n");
	} else {
		echo("require(feasts)\n");
	}	if(is_preview) {
		echo("if(!base::require(dplyr)){stop(" + i18n("Preview not available, because package dplyr is not installed or cannot be loaded.") + ")}\n");
	} else {
		echo("require(dplyr)\n");
	}	if(is_preview) {
		echo("if(!base::require(ggplot2)){stop(" + i18n("Preview not available, because package ggplot2 is not installed or cannot be loaded.") + ")}\n");
	} else {
		echo("require(ggplot2)\n");
	}	if(is_preview) {
		echo("if(!base::require(future)){stop(" + i18n("Preview not available, because package future is not installed or cannot be loaded.") + ")}\n");
	} else {
		echo("require(future)\n");
	}
}

function calculate(is_preview){
	// read in variables from dialog


	// the R code to be evaluated

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

    var keys_arr = (keys_raw !== '') ? keys_raw.split('\n').map(parseVar).filter(Boolean) : [];
    var has_keys = keys_arr.length > 0;

    if (hier_mode !== 'batch' && !has_keys) {
        echo('stop("Hierarchical forecasting requires at least 1 Key column.")\n');
    }

    echo('df_fab <- as.data.frame(' + df + ')\n');
    if (gran === 'month') {
        echo('df_fab[["' + idx_col + '"]] <- tsibble::yearmonth(df_fab[["' + idx_col + '"]])\n');
    } else if (gran === 'quarter') {
        echo('df_fab[["' + idx_col + '"]] <- tsibble::yearquarter(df_fab[["' + idx_col + '"]])\n');
    } else if (gran === 'week') {
        echo('df_fab[["' + idx_col + '"]] <- tsibble::yearweek(df_fab[["' + idx_col + '"]])\n');
    } else if (gran === 'day') {
        echo('df_fab[["' + idx_col + '"]] <- as.Date(df_fab[["' + idx_col + '"]])\n');
    }

    var key_arg = '';
    if (has_keys) {
        key_arg = ', key = c(' + keys_arr.map(function(k){ return '`' + k + '`'; }).join(', ') + ')';
    }
    echo('tsb <- tsibble::as_tsibble(df_fab, index = `' + idx_col + '`' + key_arg + ')\n\n');

    // Agregación jerárquica si aplica
    if (hier_mode !== 'batch' && has_keys) {
        var sep_op = (hier_mode === 'nested') ? ' / ' : ' * ';
        var key_expr = keys_arr.map(function(k){ return '`' + k + '`'; }).join(sep_op);
        echo('tsb <- tsb %>%\n');
        echo('  fabletools::aggregate_key(' + key_expr + ', `' + y_col + '` = sum(`' + y_col + '`, na.rm = TRUE))\n\n');
    }

    if (use_par) {
        echo('future::plan(future::multisession)\n');
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

    echo('fable_models <- tsb %>%\n  fabletools::model(' + mod_args.join(', ') + ')\n');

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
                rec_args.push(mn + '_Rec = ' + rec_fn + '(' + mn + ', method = "' + rec_meth + '")');
            } else {
                rec_args.push(mn + '_Rec = ' + rec_fn + '(' + mn + ')');
            }
        }
        echo('fable_models <- fable_models %>%\n  fabletools::reconcile(' + rec_args.join(', ') + ')\n');
    }

    echo('fable_forecast <- fable_models %>%\n  fabletools::forecast(h = ' + h + ')\n');

    if (use_par) {
        echo('future::plan(future::sequential)\n');
    }
    echo('\n');

    // Accuracy table (convertida a data.frame limpio y reemplazando <aggregated> por (Total))
    echo('acc_fab <- as.data.frame(fabletools::accuracy(fable_models))\n');
    echo('for (kn in tsibble::key_vars(tsb)) {\n');
    echo('  if (kn %in% colnames(acc_fab)) { v_c <- format(acc_fab[[kn]]); acc_fab[[kn]] <- ifelse(v_c == "<aggregated>", "(Total)", v_c) }\n');
    echo('}\n');
    echo('keep_acc <- intersect(colnames(acc_fab), c(tsibble::key_vars(tsb), ".model", ".type", "RMSE", "MAE", "MAPE", "MASE"))\n');
    echo('acc_fab <- acc_fab[, keep_acc, drop = FALSE]\n');
    echo('for (cn in intersect(c("RMSE", "MAE", "MAPE", "MASE"), colnames(acc_fab))) acc_fab[[cn]] <- round(acc_fab[[cn]], 4)\n\n');

    // Tabla de pronósticos conservando las llaves jerárquicas (agg_vec -> character)
    echo('fc_fab_tbl <- tryCatch({\n');
    echo('  fable_forecast %>%\n');
    echo('    fabletools::hilo(level = c(80, 95)) %>%\n');
    echo('    fabletools::unpack_hilo(c(`80%`, `95%`)) %>%\n');
    echo('    as.data.frame() %>%\n');
    echo('    dplyr::mutate(dplyr::across(dplyr::where(~ inherits(.x, "agg_vec")), ~ ifelse(format(.x) == "<aggregated>", "(Total)", format(.x)))) %>%\n');
    echo('    dplyr::select(dplyr::where(~ !is.list(.x) && !inherits(.x, "distribution")))\n');
    echo('}, error = function(e) {\n');
    echo('  df_tmp <- as.data.frame(fable_forecast)\n');
    echo('  df_tmp[, vapply(df_tmp, function(c) !is.list(c) && !inherits(c, "distribution"), logical(1)), drop = FALSE]\n');
    echo('})\n');
    echo('fc_fab_tbl <- utils::head(fc_fab_tbl, 60)\n\n');


    // Gráfico inteligente: limitar a máximo 'max_plot' series si hay demasiadas llaves
    var default_tit = (hier_mode !== 'batch') ? 'Hierarchical Forecast (fable)' : 'Batch Forecast (fable)';
    var title_str = (main_tit !== '') ? main_tit : default_tit;

    echo('kv <- tsibble::key_vars(tsb)\n');
    echo('if (length(kv) > 0) {\n');
    echo('  key_df <- tsibble::key_data(tsb)\n');
    echo('  if (nrow(key_df) > ' + max_plot + ') {\n');
    if (hier_mode !== 'batch') {
        // Priorizar niveles agregados superiores en jerarquías
        echo('    n_aggs <- rowSums(vapply(key_df[, kv, drop = FALSE], fabletools::is_aggregated, logical(nrow(key_df))))\n');
        echo('    sel_keys <- key_df[order(-n_aggs), kv, drop = FALSE][seq_len(' + max_plot + '), , drop = FALSE]\n');
    } else {
        echo('    sel_keys <- key_df[seq_len(' + max_plot + '), kv, drop = FALSE]\n');
    }
    echo('    fbl_plot <- dplyr::semi_join(fable_forecast, sel_keys, by = kv)\n');
    echo('    tsb_plot <- dplyr::semi_join(tsb, sel_keys, by = kv)\n');
    echo('  } else {\n');
    echo('    fbl_plot <- fable_forecast; tsb_plot <- tsb\n');
    echo('  }\n');
    echo('} else {\n');
    echo('  fbl_plot <- fable_forecast; tsb_plot <- tsb\n');
    echo('}\n\n');

    echo('p <- ggplot2::autoplot(fbl_plot, tsb_plot) + ggplot2::theme_' + theme + '() +\n');
    echo('     ggplot2::scale_y_continuous(n.breaks = 3) +\n');
    echo('     ggplot2::labs(title = "' + title_str + '") + ggplot2::theme(legend.position = "bottom")\n');
  
}

function printout(is_preview){
	// read in variables from dialog


	// printout the results
	if(!is_preview) {
		new Header(i18n("2. Batch & Hierarchical Forecasting (fable) results")).print();	
	}
    var w = getValue('fab_plot_w');
    var h = getValue('fab_plot_h');
    var res = getValue('fab_plot_res');

    if (typeof is_preview !== 'undefined' && is_preview) {
        echo('print(p)\n');
    }

    if (typeof is_preview === 'undefined' || !is_preview) {
        echo('rk.header("2. Batch & Hierarchical Forecasting (fable)")\n');

        echo('rk.graph.on(width = ' + w + ', height = ' + h + ', res = ' + res + ')\n');
        echo('print(p)\n');
        echo('rk.graph.off()\n\n');

        echo('rk.header("In-Sample Accuracy by Series / Level", level = 3)\n');
        echo('rk.print(utils::head(acc_fab, 100))\n');

        echo('rk.header("Forecast Table (Top 60 rows)", level = 3)\n');
        echo('rk.print(fc_fab_tbl)\n');

        if (getValue('fab_save_fc.active') || getValue('fab_save_mod.active') || getValue('fab_save_plot.active')) {
            echo('rk.print("<hr>")\n');
        }
        if (getValue('fab_save_fc.active')) {
            echo('rk.print(paste0("<b>Fable forecast saved as: </b><code>", "' + getValue('fab_save_fc') + '", "</code><br>"))\n');
        }
        if (getValue('fab_save_mod.active')) {
            echo('rk.print(paste0("<b>Mable models saved as: </b><code>", "' + getValue('fab_save_mod') + '", "</code><br>"))\n');
        }
        if (getValue('fab_save_plot.active')) {
            echo('p$plot_env <- emptyenv()\n');
            echo('fable_plot <- p\n');
            echo('rk.print(paste0("<b>Plot object (ggplot2) saved as: </b><code>", "' + getValue('fab_save_plot') + '", "</code>"))\n');
        }
    }
  
	if(!is_preview) {
		//// save result object
		// read in saveobject variables
		var fabSaveFc = getValue("fab_save_fc");
		var fabSaveFcActive = getValue("fab_save_fc.active");
		var fabSaveFcParent = getValue("fab_save_fc.parent");		var fabSaveMod = getValue("fab_save_mod");
		var fabSaveModActive = getValue("fab_save_mod.active");
		var fabSaveModParent = getValue("fab_save_mod.parent");		var fabSavePlot = getValue("fab_save_plot");
		var fabSavePlotActive = getValue("fab_save_plot.active");
		var fabSavePlotParent = getValue("fab_save_plot.parent");
		// assign object to chosen environment
		if(fabSaveFcActive) {
			echo(".GlobalEnv$" + fabSaveFc + " <- fable_forecast\n");
		}
		if(fabSaveModActive) {
			echo(".GlobalEnv$" + fabSaveMod + " <- fable_models\n");
		}
		if(fabSavePlotActive) {
			echo(".GlobalEnv$" + fabSavePlot + " <- fable_plot\n");
		}	
	}

}

