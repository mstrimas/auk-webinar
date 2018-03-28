library(auk)
ebd_dir <- "/Users/mes335/data/ebird/ebd_relFeb-2018" # change this!

# clean ebd
f_ebd <- file.path(ebd_dir, "ebd_relFeb-2018.txt")
f_ebd_clean <- file.path(ebd_dir, "ebd_relFeb-2018_clean.txt") 
auk_clean(f_ebd, f_ebd_clean, remove_text = TRUE)

# clean sampling event data
f_sampling <- file.path(ebd_dir, "ebd_sampling_relFeb-2018.txt")
f_sampling_clean <- file.path(ebd_dir, "ebd_sampling_relFeb-2018_clean.txt") 
auk_clean(f_sampling, f_sampling_clean, remove_text = TRUE)