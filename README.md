
<!-- README.md is generated from README.Rmd -->

# feb2 <img src="man/figures/hex.png" align="right" alt="" width="120" />

## Overview

Every year on February 2, [Groundhog
Day](https://en.wikipedia.org/wiki/Groundhog_Day), the famous groundhog
[Punxsutawney Phil](https://en.wikipedia.org/wiki/Punxsutawney_Phil)—and
a growing cast of creatures (including stuffed animals, sock puppets,
and mascots)—emerge from their burrows to predict the weather.
Punxsutawney Phil, the prognosticator of prognosticators, has been
predicting the weather since 1887. If he sees his shadow, his prediction
is for six more weeks of winter. If not, he predicts an early spring.

This package brings together prediction data from [Countdown to
Groundhog Day](https://countdowntogroundhogday.com/) and weather data
from [Open-Meteo](https://open-meteo.com/) to help you evaluate which
prognosticators you can trust.

## Installation

``` r
# Install from GitHub
devtools::install_github("ericpgreen/feb2")
```

## Usage

Currently this is a function-less data package designed to facilitate
your analyses of Groundhog Day prediction data.

``` r
library(feb2)
```

## Datasets

There are three main datasets and several supporting datasets.

``` mermaid
erDiagram
    prognosticators {
        string prognosticator_slug PK
        string prognosticator_name
        string prognosticator_city
        float prognosticator_lat
        float prognosticator_long
        string prognosticator_type
        string prognosticator_creature
        string Status
    }
    predictions {
        string prognosticator_slug FK
        int year
        string prediction
        int predict_early_spring
    }
    class_def1 {
        string prognosticator_city FK
        int year
        string class
    }
    class_def1_data {
        string prognosticator_city FK
        int year
        int month
        float tmax_monthly_mean_f
        float tmax_monthly_mean_f_15y
        string class
    }
    prognosticators ||--o{ predictions : "prognosticator_slug"
    prognosticators ||--o{ class_def1 : "prognosticator_city"
    prognosticators ||--o{ class_def1_data : "prognosticator_city"
```

### `prognosticators`

Michael Venos, the creator of [Countdown to Groundhog
Day](https://countdowntogroundhogday.com/), maintains the internet’s
most comprehensive database about Groundhog Day predictions. He
generously agreed to allow me to incorporate his data into this package.
Currently he has data on a diverse collection of 315 prognosticators.

Each prognosticator is uniquely identified by a `prognosticator_slug`
derived from their URL on the Countdown to Groundhog Day website. This
allows for accurate linking even when multiple prognosticators share the
same name (e.g., there are multiple “Woody” prognosticators in different
cities).

``` r
library(tidyverse)
#> Warning: package 'ggplot2' was built under R version 4.3.3
#> Warning: package 'tibble' was built under R version 4.3.3
#> Warning: package 'purrr' was built under R version 4.3.3
#> Warning: package 'lubridate' was built under R version 4.3.3
prognosticators %>%
  group_by(prognosticator_status) %>%
  count()
#> # A tibble: 4 × 2
#> # Groups:   prognosticator_status [4]
#>   prognosticator_status     n
#>   <chr>                 <int>
#> 1 Creature                254
#> 2 Human Mascot             13
#> 3 Inanimate                47
#> 4 <NA>                      1
```

Rodents are by far the most common prognosticators. One lobster is
holding it down for the arthropods.

``` r
prognosticators %>%
  group_by(prognosticator_phylum, prognosticator_class, prognosticator_order) %>%
  count()
#> # A tibble: 20 × 4
#> # Groups:   prognosticator_phylum, prognosticator_class, prognosticator_order [20]
#>    prognosticator_phylum prognosticator_class prognosticator_order     n
#>    <chr>                 <chr>                <chr>                <int>
#>  1 Arthropoda            Malacostraca         Decapoda                 1
#>  2 Chordata              Actinopterygii       Perciformes              1
#>  3 Chordata              Amphibia             Anura                    3
#>  4 Chordata              Aves                 Anseriformes             1
#>  5 Chordata              Aves                 Galliformes              1
#>  6 Chordata              Aves                 Sphenisciformes          1
#>  7 Chordata              Aves                 Strigiformes             2
#>  8 Chordata              Aves                 Struthioniformes         1
#>  9 Chordata              Mammalia             Artiodactyla             5
#> 10 Chordata              Mammalia             Carnivora               26
#> 11 Chordata              Mammalia             Cingulata                3
#> 12 Chordata              Mammalia             Didelphimorphia          3
#> 13 Chordata              Mammalia             Eulipotyphla            21
#> 14 Chordata              Mammalia             Proboscidea              1
#> 15 Chordata              Mammalia             Rodentia               236
#> 16 Chordata              Mammalia             Tubulidentata            2
#> 17 Chordata              Reptilia             Crocodilia               2
#> 18 Chordata              Reptilia             Testudines               1
#> 19 Mollusca              Bivalvia             Venerida                 1
#> 20 <NA>                  <NA>                 <NA>                     3
```

### `predictions`

Michael has collected 2482 predictions going back to Punxsutawney Phil’s
first prediction in 1887. Some years the prediction is uncertain or not
recorded, accounting for the `NA`s.

Predictions are linked to prognosticators via `prognosticator_slug`,
ensuring accurate attribution even for prognosticators with duplicate
names.

``` r
predictions %>%
  group_by(prediction) %>%
  count()
#> # A tibble: 3 × 2
#> # Groups:   prediction [3]
#>   prediction       n
#>   <chr>        <int>
#> 1 Early Spring  1239
#> 2 Long Winter   1165
#> 3 <NA>            78
```

### `class_def1`

The biggest challenge for evaluating Groundhog Day predictions is
defining what we mean by “early spring”. So far in this package I follow
the general approach of earlier analyses by
[NOAA](https://www.ncei.noaa.gov/news/groundhog-day-forecasts-and-climate-history)
and
[538](https://fivethirtyeight.com/features/groundhogs-do-not-make-good-meteorologists/).
I define early spring for a prognosticator’s location as one month
(February OR March) with an average high temperature above the
historical average for that month.[^1] Unlike the previous analyses,
however, I use local data for each prognosticator. NOAA used U.S.
national temperatures, and 538 looked across nine U.S. regions.[^2] I
think it’s just silly to expect a real or stuffed groundhog to be able
to predict national or regional weather based on localized sunshine. I
say let’s evaluate their powers of prognostication using local data.[^3]

#### Current Coverage

The `class_def1` dataset currently covers:

- **158 unique cities** (prognosticator locations with valid
  coordinates)
- **Years 1887-2025** (pre-1940 data from GHCND for Punxsutawney and Quarryville, 1940+
  from Open-Meteo)
- **~14,000 city-year classifications**

``` r
class_def1 %>%
  filter(!is.na(class)) %>%
  count(class)
#> # A tibble: 2 × 2
#>   class            n
#>   <chr>        <int>
#> 1 Early Spring  8762
#> 2 Long Winter   2689
```

#### Missing Values (NA)

Approximately 16% of classifications are `NA`. This is expected due to:

1. **Insufficient history for rolling average** (~98% of NAs): The 15-year
   rolling average requires 14 prior years of data. Since Open-Meteo data
   begins in 1940, classifications for most cities start in 1954.

2. **Missing weather data** (~2% of NAs): Some early years have gaps in GHCND
   records (e.g., Punxsutawney 1887-1892 and 1906-1910).

``` r
class_def1 %>%
  count(is.na(class))
#> # A tibble: 2 × 2
#>   `is.na(class)`     n
#>   <lgl>          <int>
#> 1 FALSE          11451
#> 2 TRUE            2243
```

## Weather Data

Weather data comes from [Open-Meteo’s Historical Weather
API](https://open-meteo.com/en/docs/historical-weather-api), which
provides ERA5 reanalysis data back to 1940. Each prognosticator’s city
is geocoded to coordinates, and daily maximum temperatures are retrieved
directly for those coordinates.

For Punxsutawney Phil’s predictions from 1887-1939 (before Open-Meteo
coverage), weather data comes from nearby NOAA GHCND weather stations.

The `weather_stations_ghcnd` and `weather_stations_isd` datasets contain
historical weather station information and may be useful for
supplementary analyses.

### Reproducing the Weather Data

The raw weather data files (~5 million daily temperature records) are
**not committed to this repository** due to their size. The processed
classification data (`class_def1.rda` and `class_def1_data.rda`) is
included.

To reproduce the weather data collection from scratch:

1.  Run `data-raw/weather_openmeteo_batch.R` to collect daily
    temperatures from Open-Meteo (note: may take time due to API rate
    limits)
2.  Run `data-raw/process_openmeteo_batch.R` to process raw data into
    classifications
3.  Run `data-raw/export_json.R` to export JSON files for web
    applications

#### Classification Steps

1.  Geocode each prognosticator’s city to latitude/longitude coordinates
2.  Query Open-Meteo Historical API for daily maximum temperatures
    (February and March, 1940-present)
3.  Calculate the mean monthly high temperature for each location
4.  Calculate the 15-year rolling mean high monthly temperature
5.  Use the `def1` definition to classify each year as “early spring” or
    “long winter”

The `class_def1` dataset contains one row per city-year with the
classification. The `class_def1_data` dataset contains the underlying
monthly temperature data and rolling averages.

## JSON Exports

For web applications (like [Byte
Burrower](https://www.groundhogday.app/)), JSON exports are available in
`inst/json/`:

- `prognosticators.json` - All prognosticator data
- `predictions.json` - All predictions
- `class_def1.json` - Classification data
- `accuracy.json` - Accuracy statistics by prognosticator

These are regenerated by running `data-raw/export_json.R`.

## Annual Updates

The package should be updated annually **on or after April 1** once March weather data is complete. The classification definition (`def1`) requires March temperatures to determine whether spring came early.

### Update Steps

1. **Scrape new predictions** (February 2 or later)
   ```r
   # Run data-raw/predictions.R to scrape new year's predictions
   # from countdowntogroundhogday.com
   ```

2. **Collect weather data** (April 1 or later)
   ```r
   # Run data-raw/weather_openmeteo_batch.R to get Feb/March temperatures
   # Note: API rate limits apply; may take time for all locations
   ```

3. **Process classifications**
   ```r
   # Run data-raw/process_openmeteo_batch.R to calculate class_def1
   ```

4. **Export JSON files**
   ```r
   # Run data-raw/export_json.R for web applications (Byte Burrower)
   ```

5. **Rebuild package**
   ```r
   devtools::document()
   devtools::build()
   devtools::install()
   ```

6. **Push to GitHub** so Byte Burrower can access updated JSON files

## Data Use

Open-Meteo weather data is available under [CC BY
4.0](https://creativecommons.org/licenses/by/4.0/). Data on
prognosticators and their predictions come with permission from
[Countdown to Groundhog Day](https://countdowntogroundhogday.com/). You
are welcome to use the data via this package for any purpose, but please
do not post the raw data on any other public sites. Instead, give credit
to Michael’s tremendous effort by pointing back to [Countdown to
Groundhog Day](https://countdowntogroundhogday.com/).

## See Also

- [Byte Burrower](https://www.groundhogday.app/) - An AI-powered
  groundhog that uses this data to make personalized predictions for
  your location
- [Data Science and Byte
  Burrower](https://groundhogday.site/episode/Data-Science-and-Byte-Burrower) -
  Podcast episode discussing the data science behind Groundhog Day
  predictions

## Hex Sticker

The groundhog pixel art is a [DALL-E 2](https://openai.com/dall-e-2/)
creation.

## Issues

Please [submit an issue](https://github.com/ericpgreen/feb2/issues) if
you encounter any bugs or errors. This package comes with no warranty of
any kind. Don’t rely on me or these rodents to get it right. Though my
family did live in Punxsutawney when I was 4, and I have been to
Gobbler’s Knob.

<div class="figure">

<img src="man/figures/gk.png" alt="Me visting Gobbler's Knob as a child." width="900" />
<p class="caption">

Me visting Gobbler’s Knob as a child.
</p>

</div>

[^1]: 538 uses the 15-year rolling mean, and so do I.

[^2]: NOAA evaluated Phil’s predictions from 2012-2021. 538 expanded the
    scope of the inquiry from 1 to 9 prognosticators, and included more
    years, 1994-2021.

[^3]: I refer to this classification definition as `def1`.
