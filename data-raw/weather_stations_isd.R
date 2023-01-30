# must run after prognosticators.R

library(tidyverse)
library(rnoaa)
# requires rgdal
# install.packages("https://cran.r-project.org/src/contrib/rgdal_0.9-1.tar.gz", repos = NULL, type="source", configure.args = "--with-gdal-config=/Library/Frameworks/GDAL.framework/Versions/1.10/unix/bin/gdal-config --with-proj-include=/Library/Frameworks/PROJ.framework/unix/include --with-proj-lib=/Library/Frameworks/PROJ.framework/unix/lib")

# NOAA access token
# https://www.ncdc.noaa.gov/cdo-web/token
  options(noaakey = Sys.getenv("NOAA_TOKEN"))

# get isd stations within 100km radius of city coordinates
# ---------------------
  isd_stations <- NULL
  unique_cities <- prognosticators %>%
    distinct(prognosticator_city, .keep_all = TRUE)

  for (i in 1:nrow(unique_cities)) {
    stations <- isd_stations_search(lat = unique_cities$prognosticator_lat[i],
                                    lon = unique_cities$prognosticator_long[i],
                                    radius = 100,
                                    bbox = NULL)

    stations$prognosticator_city <- unique_cities$prognosticator_city[i]

    isd_stations <- isd_stations %>%
      bind_rows(stations)
  }

  weather_stations_isd <- isd_stations %>%
    select(prognosticator_city, everything())

usethis::use_data(weather_stations_isd, overwrite = TRUE)
