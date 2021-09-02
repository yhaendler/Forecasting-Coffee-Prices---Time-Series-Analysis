df_for_plotting <- function(m, fcst) {
  # Make sure there is no y in fcst
  fcst$y <- NULL
  df <- m$history %>%
    dplyr::select(ds, y) %>%
    dplyr::full_join(fcst, by = "ds") %>%
    dplyr::arrange(ds)
  return(df)
}



plot.prophet <- function(x, fcst, uncertainty = TRUE, plot_cap = TRUE,
                         xlabel = 'ds', ylabel = 'y', plot_title, ...) {
  df <- df_for_plotting(x, fcst)
  gg <- ggplot2::ggplot(df, ggplot2::aes(x = ds, y = y)) +
    ggplot2::labs(x = xlabel, y = ylabel)
  if (exists('cap', where = df) && plot_cap) {
    gg <- gg + ggplot2::geom_line(
      ggplot2::aes(y = cap), linetype = 'dashed', na.rm = TRUE)
  }
  if (x$logistic.floor && exists('floor', where = df) && plot_cap) {
    gg <- gg + ggplot2::geom_line(
      ggplot2::aes(y = floor), linetype = 'dashed', na.rm = TRUE)
  }
  if (uncertainty && x$uncertainty.samples && exists('yhat_lower', where = df)) {
    gg <- gg +
      ggplot2::geom_ribbon(ggplot2::aes(ymin = yhat_lower, ymax = yhat_upper),
                           alpha = 0.2,
                           #fill = '#E16F56',
                           fill='#2F3032',
                           #fill = "#0072B2",
                           na.rm = TRUE)
  }
  gg <- gg +
    ggplot2::geom_point(na.rm=TRUE) +
    ggplot2::geom_line(ggplot2::aes(y = yhat), 
                       #color = '#E16F56',
                       color='#CE1425',
                       #color = '#C70039',
                       #color='#194CA1',
                       size=1.1,
                       # color = "#0072B2",
                       na.rm = TRUE) +
    ggplot2::ggtitle(plot_title) +
    ggplot2::theme_bw() + 
    ggplot2::theme(aspect.ratio = 3 / 5,
                   axis.title = ggplot2::element_text(color='black',size=14),
                   axis.text = ggplot2::element_text(color='black',size=14))
  return(gg)
}



prophet_plot_components <- function(
  m, fcst, uncertainty = TRUE, plot_cap = TRUE, weekly_start = 0,
  yearly_start = 0, render_plot = TRUE
) {
  dt <- diff(time_diff(m$history$ds, m$start))
  min.dt <- min(dt[dt > 0])
  # Plot the trend
  panels <- list(
    plot_forecast_component(m, fcst, 'trend', uncertainty, plot_cap))
  # Plot holiday components, if present.
  if (!is.null(m$train.holiday.names) && ('holidays' %in% colnames(fcst))) {
    panels[[length(panels) + 1]] <- plot_forecast_component(
      m, fcst, 'holidays', uncertainty, FALSE)
  }
  # Plot weekly seasonality, if present
  if ("weekly" %in% colnames(fcst)) {
    if (min.dt < 1) {
      panels[[length(panels) + 1]] <- plot_seasonality(m, 'weekly', uncertainty)
    } else {
      panels[[length(panels) + 1]] <- plot_weekly(m, uncertainty, weekly_start)
    }
  }
  # Plot yearly seasonality, if present
  if ("yearly" %in% colnames(fcst)) {
    panels[[length(panels) + 1]] <- plot_yearly(m, uncertainty, yearly_start)
  }
  # Plot other seasonalities
  for (name in sort(names(m$seasonalities))) {
    if (!(name %in% c('weekly', 'yearly')) &&
        (name %in% colnames(fcst))) {
      if (m$seasonalities[[name]]$period == 7) {
        panels[[length(panels) + 1]] <- plot_weekly(m, uncertainty,
                                                    weekly_start, name)
      } else if (m$seasonalities[[name]]$period == 365.25) {
        panels[[length(panels) + 1]] <- plot_yearly(m, uncertainty,
                                                    yearly_start, name)
      } else {
        panels[[length(panels) + 1]] <- plot_seasonality(m, name, uncertainty)
      }
    }
  }
  # Plot extra regressors
  regressors <- list(additive = FALSE, multiplicative = FALSE)
  for (name in names(m$extra_regressors)) {
    regressors[[m$extra_regressors[[name]]$mode]] <- TRUE
  }
  for (mode in c('additive', 'multiplicative')) {
    if ((regressors[[mode]]) &
        (paste0('extra_regressors_', mode) %in% colnames(fcst))
    ) {
      panels[[length(panels) + 1]] <- plot_forecast_component(
        m, fcst, paste0('extra_regressors_', mode), uncertainty, FALSE)
    }
  }
  
  if (render_plot) {
    # Make the plot.
    grid::grid.newpage()
    grid::pushViewport(grid::viewport(layout = grid::grid.layout(length(panels),
                                                                 1)))
    for (i in seq_along(panels)) {
      print(panels[[i]], vp = grid::viewport(layout.pos.row = i,
                                             layout.pos.col = 1))
    }
  }
  return(invisible(panels))
}




plot_forecast_component <- function(
  m, fcst, name, uncertainty = TRUE, plot_cap = FALSE
) {
  
  wrapped.name <- paste0("`", name, "`")
  
  lower.name <- paste0(name, '_lower')
  lower.name <- paste0("`", lower.name, "`")
  
  upper.name <- paste0(name, '_upper')
  upper.name <- paste0("`", upper.name, "`")
  
  gg.comp <- ggplot2::ggplot(
    fcst, ggplot2::aes_string(x = 'ds', y = wrapped.name, group = 1)) +
    ggplot2::geom_line(color = "#E16F56", na.rm = TRUE, size=1.1) + 
    ggplot2::theme_bw() + 
    ggplot2::theme(axis.title = ggplot2::element_text(color='black',size=14),
                   axis.text = ggplot2::element_text(color='black',size=14))
  if (exists('cap', where = fcst) && plot_cap) {
    gg.comp <- gg.comp + ggplot2::geom_line(
      ggplot2::aes(y = cap), linetype = 'dashed', na.rm = TRUE)
  }
  if (exists('floor', where = fcst) && plot_cap) {
    gg.comp <- gg.comp + ggplot2::geom_line(
      ggplot2::aes(y = floor), linetype = 'dashed', na.rm = TRUE)
  }
  if (uncertainty && m$uncertainty.samples) {
    gg.comp <- gg.comp +
      ggplot2::geom_ribbon(
        ggplot2::aes_string(
          ymin = lower.name, ymax = upper.name
        ),
        alpha = 0.2,
        fill = "#2F3032",
        na.rm = TRUE)
  }
  if (name %in% m$component.modes$multiplicative) {
    gg.comp <- gg.comp + ggplot2::scale_y_continuous(labels = scales::percent)
  }
  return(gg.comp)
}



seasonality_plot_df <- function(m, ds) {
  df_list <- list(ds = ds, cap = 1, floor = 0)
  for (name in names(m$extra_regressors)) {
    df_list[[name]] <- 0
  }
  # Activate all conditional seasonality columns
  for (name in names(m$seasonalities)) {
    condition.name = m$seasonalities[[name]]$condition.name
    if (!is.null(condition.name)) {
      df_list[[condition.name]] <- TRUE
    }
  }
  df <- as.data.frame(df_list)
  df <- setup_dataframe(m, df)$df
  return(df)
}



plot_weekly <- function(m, uncertainty = TRUE, weekly_start = 0,
                        name = 'weekly') {
  # Compute weekly seasonality for a Sun-Sat sequence of dates.
  days <- seq(set_date('2017-01-01'), by='d', length.out=7) + as.difftime(
    weekly_start, units = "days")
  df.w <- seasonality_plot_df(m, days)
  seas <- predict_seasonal_components(m, df.w)
  seas$dow <- factor(weekdays(df.w$ds), levels=weekdays(df.w$ds))
  
  gg.weekly <- ggplot2::ggplot(
    seas, ggplot2::aes_string(x = 'dow', y = name, group = 1)) +
    ggplot2::geom_line(color = "#E16F56", na.rm = TRUE, size=1.1) +
    ggplot2::labs(x = "Day of week") + 
    ggplot2::theme_bw() +
    ggplot2::theme(axis.title = ggplot2::element_text(color='black',size=14),
                   axis.text = ggplot2::element_text(color='black',size=14))
  if (uncertainty && m$uncertainty.samples) {
    gg.weekly <- gg.weekly +
      ggplot2::geom_ribbon(ggplot2::aes_string(ymin = paste0(name, '_lower'),
                                               ymax = paste0(name, '_upper')),
                           alpha = 0.2,
                           fill = "#2F3032",
                           na.rm = TRUE)
  }
  if (m$seasonalities[[name]]$mode == 'multiplicative') {
    gg.weekly <- (
      gg.weekly + ggplot2::scale_y_continuous(labels = scales::percent)
    )
  }
  return(gg.weekly)
}



plot_yearly <- function(m, uncertainty = TRUE, yearly_start = 0,
                        name = 'yearly') {
  # Compute yearly seasonality for a Jan 1 - Dec 31 sequence of dates.
  days <- seq(set_date('2017-01-01'), by='d', length.out=365) + as.difftime(
    yearly_start, units = "days")
  df.y <- seasonality_plot_df(m, days)
  seas <- predict_seasonal_components(m, df.y)
  seas$ds <- df.y$ds
  
  gg.yearly <- ggplot2::ggplot(
    seas, ggplot2::aes_string(x = 'ds', y = name, group = 1)) +
    ggplot2::geom_line(color = "#E16F56", na.rm = TRUE, size=1.1) +
    ggplot2::labs(x = "Day of year") +
    ggplot2::theme_bw() + 
    ggplot2::theme(axis.title = ggplot2::element_text(color='black',size=14),
                   axis.text = ggplot2::element_text(color='black',size=14))
    ggplot2::scale_x_datetime(labels = scales::date_format('%B %d'))
  if (uncertainty && m$uncertainty.samples) {
    gg.yearly <- gg.yearly +
      ggplot2::geom_ribbon(ggplot2::aes_string(ymin = paste0(name, '_lower'),
                                               ymax = paste0(name, '_upper')),
                           alpha = 0.2,
                           fill = "#2F3032",
                           na.rm = TRUE)
  }
  if (m$seasonalities[[name]]$mode == 'multiplicative') {
    gg.yearly <- (
      gg.yearly + ggplot2::scale_y_continuous(labels = scales::percent)
    )
  }
  return(gg.yearly)
}



plot_seasonality <- function(m, name, uncertainty = TRUE) {
  # Compute seasonality from Jan 1 through a single period.
  start <- set_date('2017-01-01')
  period <- m$seasonalities[[name]]$period
  end <- start + period * 24 * 3600
  plot.points <- 200
  days <- seq(from=start, to=end, length.out=plot.points)
  df.y <- seasonality_plot_df(m, days)
  seas <- predict_seasonal_components(m, df.y)
  seas$ds <- df.y$ds
  gg.s <- ggplot2::ggplot(
    seas, ggplot2::aes_string(x = 'ds', y = name, group = 1)) +
    ggplot2::geom_line(color = "#E16F56", na.rm = TRUE, size=1.1) + 
    ggplot2::theme_bw() + 
    ggplot2::theme(axis.title = ggplot2::element_text(color='black',size=14),
                   axis.text = ggplot2::element_text(color='black',size=14))
  
  date_breaks <- ggplot2::waiver()
  label <- 'ds'
  if (name == 'weekly') {
    fmt.str <- '%a'
    date_breaks <- '1 day'
    label <- 'Day of Week'
  } else if (name == 'daily') {
    fmt.str <- '%T'
    date_breaks <- '4 hours'
    label <- 'Hour of day'
  } else if (period <= 2) {
    fmt.str <- '%T'
    label <- 'Hours'
  } else if (period < 14) {
    fmt.str <- '%m/%d %R'
  } else {
    fmt.str <- '%m/%d'
  }
  gg.s <- gg.s +
    ggplot2::scale_x_datetime(
      labels = scales::date_format(fmt.str), date_breaks = date_breaks
    ) +
    ggplot2::xlab(label)
  if (uncertainty && m$uncertainty.samples) {
    gg.s <- gg.s +
      ggplot2::geom_ribbon(
        ggplot2::aes_string(
          ymin = paste0(name, '_lower'), ymax = paste0(name, '_upper')
        ),
        alpha = 0.2,
        fill = "#2F3032",
        na.rm = TRUE)
  }
  if (m$seasonalities[[name]]$mode == 'multiplicative') {
    gg.s <- gg.s + ggplot2::scale_y_continuous(labels = scales::percent)
  }
  return(gg.s)
}


# plot_cross_validation_metric
plot_cross_validation_metric <- function(df_cv, metric, rolling_window=0.1) {
  df_none <- performance_metrics(df_cv, metrics = metric, rolling_window = -1)
  df_h <- performance_metrics(
    df_cv, metrics = metric, rolling_window = rolling_window
  )
  
  # Better plotting of difftime
  # Target ~10 ticks
  tick_w <- max(as.double(df_none$horizon, units = 'secs')) / 10.
  # Find the largest time resolution that has <1 unit per bin
  dts <- c('days', 'hours', 'mins', 'secs')
  dt_conversions <- c(
    24 * 60 * 60,
    60 * 60,
    60,
    1
  )
  for (i in seq_along(dts)) {
    if (as.difftime(1, units = dts[i]) < as.difftime(tick_w, units = 'secs')) {
      break
    }
  }
  df_none$x_plt <- (
    as.double(df_none$horizon, units = 'secs') / dt_conversions[i]
  )
  df_h$x_plt <- as.double(df_h$horizon, units = 'secs') / dt_conversions[i]
  
  gg <- (
    ggplot2::ggplot(df_none, ggplot2::aes_string(x = 'x_plt', y = metric)) +
      ggplot2::labs(x = paste0('Horizon (', dts[i], ')'), y = metric) +
      ggplot2::geom_point(color = 'gray') +
      ggplot2::geom_line(
        data = df_h, ggplot2::aes_string(x = 'x_plt', y = metric), color = '#CE1425', size=1.1
      ) +
      ggplot2::theme_bw() + 
      ggplot2::scale_x_continuous(breaks=c(0,30,60,90,120,150,180,210,240,270,300,330,360)) + 
      ggplot2::theme(aspect.ratio = 3 / 5,
                     axis.title = ggplot2::element_text(color='black',size=16),
                     axis.text = ggplot2::element_text(color='black',size=16))
  )
  
  return(gg)
}
