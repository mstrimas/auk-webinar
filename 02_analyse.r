library(tidyverse)
library(sf)
library(rnaturalearth)
library(tigris)
library(viridisLite)
library(auk)

# read, de-duplicate group checklists, roll-up taxonomy
ebd <- read_ebd("data/ebd_thrush_nh.txt")
sed <- read_sampling("data/ebd_thrush_nh_sampling.txt")
# zero fill
zf <- auk_zerofill(ebd, sed)

# make a sightings map
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
# add a legend
usr <- graphics::par("usr")
xwidth <- usr[2] - usr[1]
yheight <- usr[4] - usr[3]
legend(x = usr[1] + 0.05 * xwidth,
       y = usr[3] + 0.95 * yheight,
       bg = "white",
       legend = c("Swainson's Thrush", "Bicknell's Thrush"),
       col = c("#4daf4a", "#377eb8"), pch = 19)

# make a map of freq of observation
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
