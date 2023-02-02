#Checking my ENSO cycle looks correct

library(dplyr)
library(ggplot2)


# Reading in data ---------------------------------------------------------

#Data manipulations
library(readr) #reading in all files
library(janitor) #Name amendments
library(dplyr) #Data manipulations
library(tidyr) #Pivoting
library(stringr) #Parsing data
library(zoo) #Calculating cumulative statistics

#Graphing
library(ggplot2) #Plots
library(viridis) #Colour scheme 
library(wesanderson)


# Two Island --------------------------------------------------------------

#Creating a list of runs

#Reading in files
consistency_df <- list.files("../output/consistency_analysis/", 
                             pattern = ".csv",
                             full.names = TRUE) %>%  
  read_csv() %>% 
  
  #Creating a new column to keep track of the tick the run was up to
  group_by(run_id) %>% 
  mutate(ticks = 1:n())



enso_check <- consistency_df %>%
  ungroup() %>% 
  filter(run_id == "consistency_1993961617_1") %>% 
  select(c(enso_state, ticks)) %>% 
  mutate(enso_state = recode(enso_state,
                             `0` = "LN",           
                             `1` = "LNL",
                             `2` = "N",
                             `3` = "ENL",
                             `4` = "EN"))

ggplot(enso_check, aes(y = enso_state, x = ticks)) + 
  geom_line() + 
  #xlim(0, 100) +
  geom_point(aes(colour = enso_state)) +
  labs(y = "ENSO state",
       x = "Tick") +
  #guides(colour = guide_legend("ENSO State")) +
  theme_bw()

##Enso by state rather than SOI
enso_true <- soi_df %>% 
  mutate(enso_state = recode(enso_state,
                             "LN" = 0,           
                             "LNL" = 1,
                             "N" = 2,
                             "ENL" = 3,
                            "EN" = 4),
         tick = 1:nrow(.))

ggplot(enso_true, aes(x = tick, y = enso_state)) +
  geom_line() +
  geom_point(aes(colour = enso_state)) + 
  labs(y = "ENSO state",
       x = "Tick") +
  guides(colour = guide_legend("ENSO State")) +
  theme_bw()
