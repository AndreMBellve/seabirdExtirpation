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


# Data cleaning -----------------------------------------------------------


#Reading in meta data and cleaning names
chickPred_meta <- read.csv("../output/chick_predation/collapse_chick_predation.csv",
                     header = TRUE,
                     skip = 6) %>% 
  clean_names() 

#Run data
run_filenames <- list.files(path = "../output/chick_predation/",
                            pattern = "_run.csv",
                            full.names = TRUE)

#Creating an empty list to store all the dataframes
collapse_runs_list <- list()

#Raeding in all data into the list
for(i in seq_along(run_filenames)){
    collapse_runs_list[[i]] <- read.csv(run_filenames[i]) %>% 
      #Adding on ticks to plot through time
      mutate(ticks = 1:nrow(.))
}

#Binding them into a dataframe to join to and manipulate
chickPred_df <- bind_rows(collapse_runs_list)
remove(collapse_runs_list) #Removing chaff

#Binding together with the meta-data
chickPred_long_df <- chickPred_df %>%
  
  #Pivot to long format
  pivot_longer(cols = starts_with("settled_"),
               names_to = "island_id",
               values_to = "adult_count") %>%
  
  
  left_join(chickPred_meta,
            by = c("run" = "x_run_number")) %>%
  
  #Grabbing what I am interested in
  dplyr::select(c("run",
    "ticks",
    "island_id",
    "adult_count",
    "chick_pred_isl_1",
    "adult_pred_isl_1")) %>% 
  
  #Creating some convience columns 
  mutate(island_id = str_sub(island_id, 
                             start = 16L, end = 16L),
         predators = ifelse(island_id == "1", "Predators", "No Predators"),
         run = as.factor(run))


# Graphing ----------------------------------------------------------------
seaPal <- wesanderson::wes_palette("FantasticFox1")[c(4,3, 1)] 
#c("#440154FF",  "#FDE725FF")
#viridis(n = 2, begin = 0.2)

ggplot(
  chickPred_long_df,
  aes(
    x = ticks,
    y = adult_count,
    colour = predators,
    group = interaction(run, island_id)
  )
) +
  scale_colour_manual(values = seaPal, 
                      name = "Predation") +
  labs(y = "Adults (Count)", x = "Years") +
  #xlim(c(5, 100)) +
  geom_line(size = 0.8) +
  facet_grid(chick_pred_isl_1 ~ adult_pred_isl_1) #+
  #theme_minimal() +
  theme(axis.text = element_text(size = 12, colour = "white"),
        axis.title = element_text(size = 14, colour = "white"),
        strip.text = element_text(size = 12, colour = "white"),
        legend.text = element_text(size = 12, colour = "white"),
        legend.title = element_text(size = 14, colour = "white"),
        panel.grid = element_blank())


#Saving
# ggsave("./graphs/persistance.png",
#        width = 9.9, height = 5.5)


#
chickPred_sum <- chickPred_long_df %>% 
  group_by(chick_predation, island_id, ticks, predators) %>% 
  summarise(adult_count = mean(adult_count))

ggplot(chickPred_sum,
  aes(
    x = ticks,
    y = adult_count,
    colour = predators,
    group = interaction(chick_predation, island_id)
  )
) +
  geom_line() +
  facet_grid(chick_predation~.)  #chick_predation)
