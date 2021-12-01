#Script for processing behaviour space output of collapse model


# Libraries ---------------------------------------------------------------

#Data manipulations
library(janitor) #Name amendments
library(dplyr) #Data manipulations
library(tidyr) #Pivoting
library(stringr) #Parsing data

#Graphing
library(ggplot2) #Plots
library(viridis) #Colour scheme 
library(wesanderson)


# Data cleaning -----------------------------------------------------------

#Reading in meta data and cleaning names
recol_meta <- read.csv("./data/recolonisation/collapse_recolonisation.csv",
                           header = TRUE,
                           skip = 6) %>% 
  clean_names()

#Run data
run_filenames <- list.files(path = "./data/recolonisation/",
                            pattern = "_run.csv",
                            full.names = TRUE)

#Creating an empty list to store all the dataframes
collapse_runs_list <- list()

#Raeding in all data into the list
for(i in seq_along(run_filenames)){
  collapse_runs_list[[i]] <- read.csv(run_filenames[i]) %>% 
    #Adding on ticks to plot through time
    mutate(ticks = 1:nrow(.),
           run = i)
}

#Binding them into a dataframe to join to and manipulate
recol_df <- bind_rows(collapse_runs_list)
remove(collapse_runs_list) #Removing chaff

#Binding together with the meta-data
recol_long_df <- recol_df %>%
  
  #Pivot to long format
  pivot_longer(cols = starts_with("settled_"),
               names_to = "island_id",
               values_to = "adult_count") %>%
  
  #Adding meta-data
  left_join(recol_meta,
            by = c("run" = "x_run_number")) %>%
  #Grabbing what I am interested in
  dplyr::select(c(
    "run",
    "ticks",
    "island_id",
    "adult_count"
  )) %>% 
  mutate(island_id = str_sub(island_id, 
                             start = 16L, end = 16L),
         predators = case_when(
           run <= 30 ~ "0%",
           run > 30 & run <= 60 ~ "10%",
           run > 60 ~ "20%"),
         starting_condition = ifelse(island_id == 1, "Uncolonised", "Colonised"),
         run = as.factor(run))


# Graphing ----------------------------------------------------------------

#Colour palette
seaPal <- wesanderson::wes_palette("FantasticFox1")[c(4,3)] 
  #c("#440154FF",  "#FDE725FF")
  #viridis(n = 2, begin = 0.2)


#Counting number of successful recolonisations
recol_count <- recol_long_df %>% 
  filter(ticks == 300 & island_id == 1 & adult_count > 10000) %>% 
  group_by(predators) %>% 
  summarise(count = n())


#Graphing through time
ggplot(recol_long_df, aes(
    x = ticks,
    y = adult_count,
    colour = starting_condition,
    group = interaction(island_id, run))) +
  geom_line(size = 0.8) +
  scale_colour_manual(values = seaPal, 
                      name = "Starting Condition") +
  xlim(c(50, 300)) +
  labs(y = "Adults (Count)", x = "Years") +
  facet_grid(predators~.) +
  theme_minimal() +
  theme(axis.text = element_text(size = 12, colour = "white"),
        axis.title = element_text(size = 14, colour = "white"),
        strip.text = element_text(size = 12, colour = "white"),
        legend.text = element_text(size = 12, colour = "white"),
        legend.title = element_text(size = 14, colour = "white"),
        panel.grid = element_blank())
#Saving
ggsave("./graphs/recolonisation.png",
       width = 9.9, height = 5.5)

#Summarise over runs
recol_sum <- chickPred_long_df %>% 
  group_by(island_id, ticks, predators) %>% 
  summarise(adult_count = mean(adult_count))

ggplot(recol_sum,
       aes(
         x = ticks,
         y = adult_count,
         colour = predators,
         group = island_id)
       ) +
  geom_line()
