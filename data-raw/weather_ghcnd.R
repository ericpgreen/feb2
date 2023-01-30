# must run after prognosticators.R, weather_stations_ghcnd.R

library(tidyverse)
library(rnoaa)
# requires rgdal
# install.packages("https://cran.r-project.org/src/contrib/rgdal_0.9-1.tar.gz", repos = NULL, type="source", configure.args = "--with-gdal-config=/Library/Frameworks/GDAL.framework/Versions/1.10/unix/bin/gdal-config --with-proj-include=/Library/Frameworks/PROJ.framework/unix/include --with-proj-lib=/Library/Frameworks/PROJ.framework/unix/lib")

# NOAA access token
# https://www.ncdc.noaa.gov/cdo-web/token
  options(noaakey = Sys.getenv("NOAA_TOKEN"))

# get daily high temps
# ---------------------
  closest_n <- 10
  weather_stations_ghcnd_closest_n <- weather_stations_ghcnd %>%
    arrange(prognosticator_city, distance) %>%
    group_by(prognosticator_city) %>%
    slice_min(distance, n = closest_n) %>%
    ungroup()

  ghcnd_tmax <- ghcnd_search(
    weather_stations_ghcnd_closest_n$id,
    var = "TMAX",
    refresh = TRUE
  )
  ghcnd_tmax <- ghcnd_tmax$tmax

# join with prognosticator_city
# ---------------------
  ghcnd_tmax <- ghcnd_tmax %>%
    right_join(select(weather_stations_ghcnd_closest_n,
                      id, prognosticator_city),
               by = "id") %>%
    select(prognosticator_city, everything())

# average daily tmax across stations in each prognosticator_city
# ---------------------
  ghcnd_tmax_daily_mean_city <- ghcnd_tmax %>%
    group_by(prognosticator_city, date) %>%
    summarize(tmax_daily_mean = mean(tmax, na.rm=TRUE)) %>%
    mutate(tmax_daily_mean_f = tmax_daily_mean/10*1.8+32)

# average monthly tmax in each prognosticator_city, limited to feb and mar
# ---------------------
  ghcnd_tmax_monthly_mean_city <- ghcnd_tmax_daily_mean_city %>%
    filter(lubridate::month(date)==2 | lubridate::month(date)==3) %>%
    mutate(year = lubridate::year(date)) %>%
    mutate(month = lubridate::month(date)) %>%
    group_by(prognosticator_city, year, month) %>%
    summarize(tmax_monthly_mean_f = mean(tmax_daily_mean_f, na.rm=TRUE)) %>%
    mutate(yearmo = paste(year, str_pad(month, 2, pad = "0"), sep="-")) %>%
    select(prognosticator_city, yearmo, everything())

# calculate 15 year rolling average by month
# ---------------------
  ghcnd_tmax_monthly_mean_f_15y_2 <- ghcnd_tmax_monthly_mean_city %>%
    ungroup() %>%
    arrange(prognosticator_city, year) %>%
    filter(month==2) %>%
    tidyr::complete(prognosticator_city, year) %>%
    mutate(month=2) %>%
    mutate(yearmo = paste(year, str_pad(month, 2, pad = "0"), sep="-")) %>%
    group_by(prognosticator_city) %>%
    mutate(tmax_monthly_mean_f_15y = zoo::rollmean(tmax_monthly_mean_f,
                                                   k = 15, fill = NA,
                                                   align = "right")) %>%
    ungroup()

  ghcnd_tmax_monthly_mean_f_15y_3 <- ghcnd_tmax_monthly_mean_city %>%
    ungroup() %>%
    arrange(prognosticator_city, year) %>%
    filter(month==3) %>%
    tidyr::complete(prognosticator_city, year) %>%
    mutate(month=3) %>%
    mutate(yearmo = paste(year, str_pad(month, 2, pad = "0"), sep="-")) %>%
    group_by(prognosticator_city) %>%
    mutate(tmax_monthly_mean_f_15y = zoo::rollmean(tmax_monthly_mean_f,
                                                   k = 15, fill = NA,
                                                   align = "right")) %>%
    ungroup()

# determine if early spring
# ---------------------
  class_def1 <- ghcnd_tmax_monthly_mean_f_15y_2 %>%
    bind_rows(ghcnd_tmax_monthly_mean_f_15y_3) %>%
    filter(year >= 1887) %>%
    group_by(prognosticator_city, year) %>%
    mutate(class = case_when(
      any(tmax_monthly_mean_f > tmax_monthly_mean_f_15y) ~ "Early Spring",
      any(is.na(tmax_monthly_mean_f)) ~ NA_character_,
      any(is.na(tmax_monthly_mean_f_15y)) ~ NA_character_,
      TRUE ~ "Long Winter"
    )) %>%
    ungroup() %>%
    arrange(prognosticator_city, year) %>%
    {. ->> class_def1_data} %>%
    distinct(prognosticator_city, year, .keep_all = TRUE) %>%
    select(prognosticator_city, year, class)


  usethis::use_data(class_def1, overwrite = TRUE)
  usethis::use_data(class_def1_data, overwrite = TRUE)
