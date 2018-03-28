library(auk)
ebd_dir <- "/Users/mes335/data/ebird/ebd_relFeb-2018" # change this!

# input files
f_in_ebd <- file.path(ebd_dir, "ebd_relFeb-2018_clean.txt")
f_in_sampling <- file.path(ebd_dir, "ebd_sampling_relFeb-2018_clean.txt")
# define filters
ebd_filters <- auk_ebd(f_in_ebd, f_in_sampling) %>% 
  # 2 thrush species
  auk_species(c("Bicknell's Thrush", "Swainson's Thrush")) %>% 
  # new hampshire
  auk_state("US-NH") %>% 
  # june of any year
  auk_date(c("*-06-01", "*-06-30")) %>% 
  # complete checklists only
  auk_complete()

# output files
f_out_ebd <- "data/ebd_thrush_nh.txt"
f_out_sampling <- "data/ebd_thrush_nh_sampling.txt"
# compile filters into awk script and run
auk_filter(ebd_filters, file = f_out_ebd, file_sampling = f_out_sampling)