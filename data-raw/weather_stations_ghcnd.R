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

# get GHCND stations within 100km radius of city coordinates
# ---------------------
  station_data <- ghcnd_stations()

  city_coords <- prognosticators %>%
    distinct(prognosticator_city, .keep_all = TRUE) %>%
    rename(latitude = prognosticator_lat,
           longitude = prognosticator_long,
           id = prognosticator_city) %>%
    select(id, latitude, longitude)

  weather_stations_ghcnd <-  meteo_nearby_stations(lat_lon_df = city_coords,
                                                   station_data = station_data,
                                                   radius = 100,
                                                   var = "TMAX") %>%
    map_df(~as.data.frame(.x), .id="prognosticator_city")

usethis::use_data(weather_stations_ghcnd, overwrite = TRUE)
