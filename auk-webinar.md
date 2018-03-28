---
title: "auk: working with eBird data in R"
author: "Matthew Strimas-Mackey"
output: 
  html_document:
    keep_md: true
editor_options: 
  chunk_output_type: console
---



These notes accompany a webinar given on March 28, 2018 on extracting and processing eBird data with the R package `auk`.

## Getting started

### Access the data

Access to the full eBird dataset is provided via two large, tab-separated text files. The eBird Basic Dataset consist of one line for each observation of a species on a checklist. The Sampling Event Data consists of one line for each checklist.

To access eBird data, begin by [creating an eBird account and signing in](https://secure.birds.cornell.edu/cassso/login). Then visit the [Download Data](http://ebird.org/ebird/data/download) page. eBird data access is free; however, you will need to [request access](http://ebird.org/ebird/data/request) in order to obtain access to the EBD. Filling out the access request form allows eBird to keep track of the number of people using the data and obtain information on the applications for which the data are used

Once you have access to the data, proceed to the [download page](http://ebird.org/ebird/data/download/ebd). Download and uncompress (twice!) both the EBD and the corresponding Sampling Event Data. Put these two large text files somewhere sensible on either your computer's hard drive or an external drive, and remember the location of containing folder.

### Project setup

Create a new RStudio project in a fresh directory, then create a new R script within this project. At the top of your script, load `auk` and any other necessary R packages. Also, create a variable to store the path to your EBD data files.


```r
library(tidyverse)
library(sf)
library(rnaturalearth)
library(tigris)
library(viridisLite)
library(auk)
ebd_dir <- "/Users/mes335/data/ebird/ebd_relFeb-2018" # change this!
```

### Example datasets

The full EBD is nearly 200 GB in size and takes multiple hours to process. For demonstration purposes several small subsets of the eBird data have been included in the `auk` package. They can be accessed using the `system.file()` command, which returns the path to package files. The first is a sample of 500 observations of Green, Gray, Blue, and Steller's Jays from North America:


```r
system.file("extdata/ebd-sample.txt", package = "auk")
#> [1] "/Library/Frameworks/R.framework/Versions/3.4/Resources/library/auk/extdata/ebd-sample.txt"
```

The second is suitable for producing zero-filled, presence-absence data. It contains every sighting from Singapore in 2012 of Collared Kingfisher, White-throated Kingfisher, and Blue-eared Kingfisher. The full Sampling Event Data file is also included, and contains all checklists from Singapore in 2012. These files can be accessed with:


```r
# ebd
system.file("extdata/zerofill-ex_ebd.txt", package = "auk")
#> [1] "/Library/Frameworks/R.framework/Versions/3.4/Resources/library/auk/extdata/zerofill-ex_ebd.txt"
# sampling event data
system.file("extdata/zerofill-ex_sampling.txt", package = "auk")
#> [1] "/Library/Frameworks/R.framework/Versions/3.4/Resources/library/auk/extdata/zerofill-ex_sampling.txt"
```

### The pipe `%>%`

`%>%`, called the pipe operator, is extremely useful for making your code more readable; however, it takes a little getting used to. It "pipes"" its left-hand side value forward into the expressions that appears on the right-hand side, i.e. one can replace `f(x)` with `x %>% f()`. The pipe can be read as "then". For more details see the [chapter on pipes](http://r4ds.had.co.nz/pipes.html) in the R for Data Science book.

## Using `auk`

There are essentially five main tasks that `auk` is designed to accomplish, and we'll go through each in turn:

1. Clean
2. Filter
3. Import
4. Pre-process
5. Zero-fill

### Cleaning
 
Some rows in the EBD may have problematic characters in the comments fields that will cause import errors, and the dataset has an extra blank column at the end. The function `auk_clean()` drops these erroneous records and removes the blank column. In addition, you can use `remove_text = TRUE` to remove free text entry columns, including the comments and location and observation names. These fields are typically not required and removing them can significantly decrease file size. 

This process should be run on both the EBD and sampling event data. It typically takes several hours for the full EBD; however, it only needs to be run once because the output from the process is saved out to a new tab-separated text file for subsequent use. After running `auk_clean()`, you can delete the original, uncleaned data files to save space


```r
# ebd
f <- file.path(ebd_dir, "ebd_relFeb-2018.txt")
f_clean <- file.path(ebd_dir, "ebd_relFeb-2018_clean.txt")
auk_clean(f, f_out = f_clean, remove_text = TRUE)
# sampling
f_sampling <- file.path(ebd_dir, "ebd_sampling_relFeb-2018.txt")
f_sampling_clean <- file.path(ebd_dir, "ebd_sampling_relFeb-2018_clean.txt")
auk_clean(f, f_out = f_sampling_clean, remove_text = TRUE)
```

### Filtering

The EBD is huge! If we're going to work with it, we need to extract a manageable subset of the data. With this in mind, the main purpose of auk is to provide a variety of functions to define taxonomic, spatial, temporal, or effort-based filters. To get started, we'll use `auk_ebd()` to set up a reference to the EBD. We'll also provide a reference to the sampling event data. This step is optional, but it will allow us to apply exactly the same set of filters (except for taxonomic filters) to the sampling event data and the EBD. We'll see why this is valuable later.


```r
# define the paths to ebd and sampling event files
f_in_ebd <- file.path(ebd_dir, "ebd_relFeb-2018_clean.txt")
f_in_sampling <- file.path(ebd_dir, "ebd_sampling_relFeb-2018_clean.txt")
# create an object referencing these files
auk_ebd(file = f_in_ebd, file_sampling = f_in_sampling)
#> Input 
#>   EBD: /Users/mes335/data/ebird/ebd_relFeb-2018/ebd_relFeb-2018_clean.txt 
#>   Sampling events: /Users/mes335/data/ebird/ebd_relFeb-2018/ebd_sampling_relFeb-2018_clean.txt 
#> 
#> Output 
#>   Filters not executed
#> 
#> Filters 
#>   Species: all
#>   Countries: all
#>   States: all
#>   Spatial extent: full extent
#>   Date: all
#>   Start time: all
#>   Last edited date: all
#>   Protocol: all
#>   Project code: all
#>   Duration: all
#>   Distance travelled: all
#>   Records with breeding codes only: no
#>   Complete checklists only: no
```

Next we'll define some filters. Consult the [vignette](https://cornelllabofornithology.github.io/auk/articles/auk.html#defining-filters) to see all the possible ways we can filter the EBD, but for now we'll extract records from New Hampshire for Bicknell's Thrush and Swainson's Thrush from [complete](http://help.ebird.org/customer/portal/articles/1006361-are-you-reporting-all-species) checklists in June of any year.


```r
ebd_filters <- auk_ebd(f_in_ebd, f_in_sampling) %>% 
  auk_species(c("Bicknell's Thrush", "Swainson's Thrush")) %>% 
  auk_state("US-NH") %>% 
  auk_date(c("*-06-01", "*-06-30")) %>% 
  auk_complete()
```

The above code only defines the filters, no data has actually been extracted yet. To compile the filters into an AWK script and run it, use `auk_filter()`. Since I provided an EBD and sampling event file to `auk_ebd()`, both will be filtered and I will need to provide two output filenames. Note that I've stored the full EBD in a central location that can be accessed by many projects, but I save the extracted data into a subdirectory of the project folder. This ensures that the project is self-contained apart from the initial extraction of the data.


```r
f_out_ebd <- "data/ebd_thrush_nh.txt"
f_out_sampling <- "data/ebd_thrush_nh_sampling.txt"
ebd_filtered <- auk_filter(ebd_filters, file = f_out_ebd, 
                           file_sampling = f_out_sampling)
```



Running `auk_filter()` takes a long time, typically a few hours, so you'll need to be patient. Also, since it's so time consuming, you'll likely only want to do this once in each project. With this in mind I'd keep the filtering code in a script of it's own, e.g. `01_ebd-extract.r`, then create a new script for all the processing and analysis steps. Here, for simplicity, I'll keep everything together in one file.

### Importing

Now that we have an EBD extract of a reasonable size, we can read it in to an R data frame. The files output from `auk_filter()` are just tab-separated text files, so we could read them using any of our usual R tools, e.g. `read.delim()`. However, `auk` contains functions specifically designed for reading in EBD data. These functions choose sensible variable names, set the data types of columns correctly, and perform two important post-processing steps: taxonomic roll-up and de-duplicating group checklists.

We'll put the sampling event data aside for now, and just read in the EBD:


```r
ebd <- read_ebd(f_out_ebd)
glimpse(ebd)
#> Observations: 2,253
#> Variables: 42
#> $ checklist_id                 <chr> "S3910100", "S4263131", "S3936987...
#> $ global_unique_identifier     <chr> "URN:CornellLabOfOrnithology:EBIR...
#> $ last_edited_date             <chr> "2014-05-07 19:23:51", "2014-05-0...
#> $ taxonomic_order              <dbl> 24602, 24600, 24600, 24602, 24602...
#> $ category                     <chr> "species", "species", "species", ...
#> $ common_name                  <chr> "Swainson's Thrush", "Bicknell's ...
#> $ scientific_name              <chr> "Catharus ustulatus", "Catharus b...
#> $ observation_count            <chr> "X", "1", "2", "1", "1", "2", "5"...
#> $ breeding_bird_atlas_code     <chr> NA, NA, NA, NA, NA, NA, NA, NA, N...
#> $ breeding_bird_atlas_category <chr> NA, NA, NA, NA, NA, NA, NA, NA, N...
#> $ age_sex                      <chr> NA, NA, NA, NA, NA, NA, NA, NA, N...
#> $ country                      <chr> "United States", "United States",...
#> $ country_code                 <chr> "US", "US", "US", "US", "US", "US...
#> $ state                        <chr> "New Hampshire", "New Hampshire",...
#> $ state_code                   <chr> "US-NH", "US-NH", "US-NH", "US-NH...
#> $ county                       <chr> "Grafton", "Grafton", "Coos", "Co...
#> $ county_code                  <chr> "US-NH-009", "US-NH-009", "US-NH-...
#> $ iba_code                     <chr> NA, NA, "US-NH_2408", "US-NH_2419...
#> $ bcr_code                     <int> 14, 14, 14, 14, 14, 14, 14, 14, 1...
#> $ usfws_code                   <chr> NA, NA, NA, NA, NA, NA, NA, NA, N...
#> $ atlas_block                  <chr> NA, NA, NA, NA, NA, NA, NA, NA, N...
#> $ locality_id                  <chr> "L722150", "L291562", "L295828", ...
#> $ locality_type                <chr> "H", "H", "H", "H", "H", "H", "H"...
#> $ latitude                     <dbl> 43.94204, 44.16991, 44.27132, 45....
#> $ longitude                    <dbl> -71.72562, -71.68741, -71.30302, ...
#> $ observation_date             <date> 2008-06-01, 2004-06-30, 2008-06-...
#> $ time_observations_started    <chr> NA, NA, NA, "09:00:00", "08:00:00...
#> $ observer_id                  <chr> "obsr50351", "obsr131204", "obsr1...
#> $ sampling_event_identifier    <chr> "S3910100", "S4263131", "S3936987...
#> $ protocol_type                <chr> "Incidental", "Incidental", "Inci...
#> $ protocol_code                <chr> "P20", "P20", "P20", "P22", "P22"...
#> $ project_code                 <chr> "EBIRD", "EBIRD", "EBIRD_BCN", "E...
#> $ duration_minutes             <int> NA, NA, NA, 120, 180, 180, 180, 1...
#> $ effort_distance_km           <dbl> NA, NA, NA, 7.242, 11.265, 11.265...
#> $ effort_area_ha               <dbl> NA, NA, NA, NA, NA, NA, NA, NA, N...
#> $ number_observers             <int> NA, 1, NA, 2, 2, 2, 2, 2, 2, 16, ...
#> $ all_species_reported         <lgl> TRUE, TRUE, TRUE, TRUE, TRUE, TRU...
#> $ group_identifier             <chr> NA, NA, NA, NA, NA, NA, NA, NA, N...
#> $ has_media                    <lgl> FALSE, FALSE, FALSE, FALSE, FALSE...
#> $ approved                     <lgl> TRUE, TRUE, TRUE, TRUE, TRUE, TRU...
#> $ reviewed                     <lgl> FALSE, FALSE, FALSE, FALSE, FALSE...
#> $ reason                       <chr> NA, NA, NA, NA, NA, NA, NA, NA, N...
```

### Pre-processing

By default, two important pre-processing steps are performed to handle taxonomy and group checklists. In most cases, you'll want this to be done; however, these can be turned off to get the raw data.


```r
ebd_raw <- read_ebd(f_out_ebd, 
                    # leave group checklists as in
                    unique = FALSE,
                    # leave taxonomy as is
                    rollup = FALSE)
```

#### Taxonomic rollup

The [eBird taxonomy](http://help.ebird.org/customer/portal/articles/1006825-the-ebird-taxonomy) is an annually updated list of all field recognizable taxa. Taxa are grouped into eight different categories, some at a higher level than species and others at a lower level. The function `auk_rollup()` (called by default by `read_ebd()`) produces an EBD containing just true species. The categories and their treatment by `auk_rollup()` are as follows:

- **Species:** e.g., Mallard.
- **ISSF or Identifiable Sub-specific Group:** Identifiable subspecies or
group of subspecies, e.g., Mallard (Mexican). Rolled-up to species level.
- **Intergrade:** Hybrid between two ISSF (subspecies or subspecies
groups), e.g., Mallard (Mexican intergrade. Rolled-up to species level.
- **Form:** Miscellaneous other taxa, including recently-described species
yet to be accepted or distinctive forms that are not universally accepted
(Red-tailed Hawk (Northern), Upland Goose (Bar-breasted)). If the checklist
contains multiple taxa corresponding to the same species, the lower level
taxa are rolled up, otherwise these records are left as is.
- **Spuh:**  Genus or identification at broad level -- e.g., duck sp.,
dabbling duck sp.. Dropped by `auk_rollup()`.
- **Slash:** Identification to Species-pair e.g., American Black
Duck/Mallard). Dropped by `auk_rollup()`.
- **Hybrid:** Hybrid between two species, e.g., American Black Duck x
Mallard (hybrid). Dropped by `auk_rollup()`.
- **Domestic:** Distinctly-plumaged domesticated varieties that may be
free-flying (these do not count on personal lists) e.g., Mallard (Domestic
type). Dropped by `auk_rollup()`.

`auk` contains the full eBird taxonomy as a data frame.


```r
glimpse(ebird_taxonomy)
#> Observations: 15,966
#> Variables: 8
#> $ taxon_order     <dbl> 3.0, 5.0, 6.0, 7.0, 13.0, 14.0, 17.0, 32.0, 33...
#> $ category        <chr> "species", "species", "slash", "species", "spe...
#> $ species_code    <chr> "ostric2", "ostric3", "y00934", "grerhe1", "le...
#> $ common_name     <chr> "Common Ostrich", "Somali Ostrich", "Common/So...
#> $ scientific_name <chr> "Struthio camelus", "Struthio molybdophanes", ...
#> $ order           <chr> "Struthioniformes", "Struthioniformes", "Strut...
#> $ family          <chr> "Struthionidae (Ostriches)", "Struthionidae (O...
#> $ report_as       <chr> NA, NA, NA, NA, NA, "lesrhe2", "lesrhe2", NA, ...
```

We can use one of the example datasets in the package to explore what `auk_rollup()` does.


```r
# get the path to the example data included in the package
f <- system.file("extdata/ebd-rollup-ex.txt", package = "auk")
# read in data without rolling up
ebd_wo_ru <- read_ebd(f, rollup = FALSE)
# rollup
ebd_w_ru <- auk_rollup(ebd_wo_ru)

# all taxa not identifiable to species are dropped
unique(ebd_wo_ru$category)
#> [1] "domestic"   "form"       "hybrid"     "intergrade" "slash"     
#> [6] "spuh"       "species"    "issf"
unique(ebd_w_ru$category)
#> [1] "species"

# yellow-rump warbler subspecies rollup
# without rollup, there are three observations
ebd_wo_ru %>%
  filter(common_name == "Yellow-rumped Warbler") %>% 
  select(checklist_id, category, common_name, subspecies_common_name, 
         observation_count)
#> # A tibble: 3 x 5
#>   checklist_id category common_name   subspecies_common_… observation_cou…
#>   <chr>        <chr>    <chr>         <chr>               <chr>           
#> 1 S41507433    species  Yellow-rumpe… <NA>                10              
#> 2 S41507433    issf     Yellow-rumpe… Yellow-rumped Warb… 5               
#> 3 S41507433    issf     Yellow-rumpe… Yellow-rumped Warb… 1
# with rollup, they have been combined
ebd_w_ru %>%
  filter(common_name == "Yellow-rumped Warbler") %>% 
  select(checklist_id, category, common_name, observation_count)
#> # A tibble: 1 x 4
#>   checklist_id category common_name           observation_count
#>   <chr>        <chr>    <chr>                 <chr>            
#> 1 S41507433    species  Yellow-rumped Warbler 16
```

#### Group checklists

eBird observers birding together can share checklists resulting in group checklists. In the simplest case, all observers will have seen the same set of species; however, observers can also add or remove species from their checklist. In the EBD, group checklists result in duplicate records, one for each observer. `auk_unique()` (called by default by `read_ebd()`) de-duplicates the EBD, resulting in one record for each species on each group checklist.

### Zero-filling

So far we've been working with presence-only data; however, many applications of the eBird data require presence-absence information. Although observers only explicitly record presence, they have the option of designating their checklists as "complete", meaning they are reporting all the species they saw or heard. With complete checklists, any species not reported can be taken to have an implicit count of zero. Therefore, by focusing on complete checklists, we can use the sampling event data to "zero-fill" the EBD producing presence-absence data. This is why it's important to filter both the EBD and the sampling event data at the same time; we need to ensure that the EBD observations are drawn from the population of checklists defined by the sampling event data.

Given an EBD file or data frame, and corresponding sampling event data, function `auk_zerofill()` produces zero-filled, presence-absence data.


```r
zf <- auk_zerofill(f_out_ebd, f_out_sampling)
zf
#> Zero-filled EBD: 12,938 unique checklists, for 2 species.
zf$observations
#> # A tibble: 25,876 x 4
#>    checklist_id scientific_name    observation_count species_observed
#>    <chr>        <chr>              <chr>             <lgl>           
#>  1 G1003224     Catharus bicknelli 0                 FALSE           
#>  2 G1003224     Catharus ustulatus X                 TRUE            
#>  3 G1022603     Catharus bicknelli 0                 FALSE           
#>  4 G1022603     Catharus ustulatus 0                 FALSE           
#>  5 G1054429     Catharus bicknelli 3                 TRUE            
#>  6 G1054429     Catharus ustulatus X                 TRUE            
#>  7 G1054430     Catharus bicknelli 0                 FALSE           
#>  8 G1054430     Catharus ustulatus X                 TRUE            
#>  9 G1054431     Catharus bicknelli 1                 TRUE            
#> 10 G1054431     Catharus ustulatus X                 TRUE            
#> # ... with 25,866 more rows
zf$sampling_events
#> # A tibble: 12,938 x 29
#>    checklist_id last_edited_date  country   country_code state  state_code
#>    <chr>        <chr>             <chr>     <chr>        <chr>  <chr>     
#>  1 S10836735    2014-05-07 19:19… United S… US           New H… US-NH     
#>  2 S10936397    2014-05-07 19:03… United S… US           New H… US-NH     
#>  3 S10995603    2014-05-07 19:03… United S… US           New H… US-NH     
#>  4 S11005948    2012-06-19 12:40… United S… US           New H… US-NH     
#>  5 S11013341    2012-06-20 18:26… United S… US           New H… US-NH     
#>  6 S15136517    2013-09-10 08:16… United S… US           New H… US-NH     
#>  7 S11012701    2017-06-12 06:31… United S… US           New H… US-NH     
#>  8 S10995655    2012-06-17 19:56… United S… US           New H… US-NH     
#>  9 S15295339    2014-05-07 18:59… United S… US           New H… US-NH     
#> 10 S10932312    2014-05-07 18:45… United S… US           New H… US-NH     
#> # ... with 12,928 more rows, and 23 more variables: county <chr>,
#> #   county_code <chr>, iba_code <chr>, bcr_code <int>, usfws_code <chr>,
#> #   atlas_block <chr>, locality_id <chr>, locality_type <chr>,
#> #   latitude <dbl>, longitude <dbl>, observation_date <date>,
#> #   time_observations_started <chr>, observer_id <chr>,
#> #   sampling_event_identifier <chr>, protocol_type <chr>,
#> #   protocol_code <chr>, project_code <chr>, duration_minutes <int>,
#> #   effort_distance_km <dbl>, effort_area_ha <dbl>,
#> #   number_observers <int>, all_species_reported <lgl>,
#> #   group_identifier <chr>
```

The resulting `auk_zerofill` object is a list of two data frames: `observations` stores the species' counts for each checklist and `sampling_events` stores the checklists. The `checklist_id` field can be used to combine the files together manually, or you can use the `collapse_zerofill()` function.


```r
collapse_zerofill(zf)
#> # A tibble: 25,876 x 32
#>    checklist_id last_edited_date  country   country_code state  state_code
#>    <chr>        <chr>             <chr>     <chr>        <chr>  <chr>     
#>  1 S10836735    2014-05-07 19:19… United S… US           New H… US-NH     
#>  2 S10836735    2014-05-07 19:19… United S… US           New H… US-NH     
#>  3 S10936397    2014-05-07 19:03… United S… US           New H… US-NH     
#>  4 S10936397    2014-05-07 19:03… United S… US           New H… US-NH     
#>  5 S10995603    2014-05-07 19:03… United S… US           New H… US-NH     
#>  6 S10995603    2014-05-07 19:03… United S… US           New H… US-NH     
#>  7 S11005948    2012-06-19 12:40… United S… US           New H… US-NH     
#>  8 S11005948    2012-06-19 12:40… United S… US           New H… US-NH     
#>  9 S11013341    2012-06-20 18:26… United S… US           New H… US-NH     
#> 10 S11013341    2012-06-20 18:26… United S… US           New H… US-NH     
#> # ... with 25,866 more rows, and 26 more variables: county <chr>,
#> #   county_code <chr>, iba_code <chr>, bcr_code <int>, usfws_code <chr>,
#> #   atlas_block <chr>, locality_id <chr>, locality_type <chr>,
#> #   latitude <dbl>, longitude <dbl>, observation_date <date>,
#> #   time_observations_started <chr>, observer_id <chr>,
#> #   sampling_event_identifier <chr>, protocol_type <chr>,
#> #   protocol_code <chr>, project_code <chr>, duration_minutes <int>,
#> #   effort_distance_km <dbl>, effort_area_ha <dbl>,
#> #   number_observers <int>, all_species_reported <lgl>,
#> #   group_identifier <chr>, scientific_name <chr>,
#> #   observation_count <chr>, species_observed <lgl>
```

This zero-filled dataset is now suitable for applications such as species distribution modelling.

## Applications

I'll work through some simple applications of the data we've just generated.

### Presence-only data

One of the most obvious things to do with the presence data is make a map!


```r
# convert ebd to spatial object
ebd_sf <- ebd %>% 
  select(common_name, latitude, longitude) %>% 
  st_as_sf(coords = c("longitude", "latitude"), crs = 4326)
# get state boundaries using rnaturalearth package
states <- ne_states(iso_a2 = c("US", "CA"), returnclass = "sf")
nh <- filter(states, postal == "NH") %>% 
  st_geometry()
# map
par(mar = c(0, 0, 0, 0), bg = "skyblue")
# set plot extent
plot(nh, col = NA)
# add state boundaries
plot(states %>% st_geometry(), col = "grey40", border = "white", add = TRUE)
plot(nh, col = "grey20", border = "white", add = TRUE)
# ebird data
plot(ebd_sf %>% filter(common_name == "Swainson's Thrush"), 
     col = "#4daf4a99", pch = 19, cex = 0.75, add = TRUE)
plot(ebd_sf %>% filter(common_name == "Bicknell's Thrush") %>% st_geometry(), 
     col = "#377eb899", pch = 19, cex = 0.75, add = TRUE)
```

<img src="figures/loc-map-1.png" style="display: block; margin: auto;" />

### Zero-filled data

The above map doesn't account for effort. We can address this by using the zero-filled data to produce maps of frequency of observation on checklists. The EBD comes with a column for the county that the observation came from, so I'll use that to summarize these data.


```r
# summarize over counties
checklist_freq <- collapse_zerofill(zf) %>% 
  group_by(scientific_name, county_code) %>% 
  summarise(frequency = sum(species_observed) / n()) %>% 
  ungroup() %>% 
  mutate(COUNTYFP = sub("US-NH-", "", county_code)) %>% 
  inner_join(ebird_taxonomy %>% select(scientific_name, common_name),
             by = "scientific_name")
# get county boundaries
nh_counties <- counties(state = "NH", cb = TRUE) %>% 
  st_as_sf() %>% 
  inner_join(checklist_freq, by = "COUNTYFP")
# map
ggplot(nh_counties) +
  geom_sf(aes(fill = frequency), color = "white") +
  scale_fill_viridis_c("Frequency observed on eBird checklists", 
                       trans = "sqrt") +
  guides(fill = guide_colourbar(title.position = "top", title.hjust = 0)) +
  facet_wrap(~ common_name, nrow = 1) +
  theme_minimal() +
  theme(legend.position = "bottom",
        legend.key.width = unit(3,"line"))
```

<img src="figures/freq-map-1.png" style="display: block; margin: auto;" />