#Script for processing behaviour space output of collapse model


# Libraries ---------------------------------------------------------------
library(janitor)
library(dplyr)
library(tidyr)
library(stringr)
library(ggplot2)


# Data cleaning -----------------------------------------------------------

collapse_meta <- read.csv("./data/chick_predation/collapse_chickPred_meta.csv",
                     header = TRUE,
                     skip = 6) %>% 
  clean_names()

#Run summary data
run_filenames <- list.files(path = "./data/chick_predation/",
                            pattern = "_test.csv",
                            full.names = TRUE)

for(i in seq_along(run_filenames)){
  if(i == 1){
    collaspe_runs <- read.csv(run_filenames[i])
  }else{
    collaspe_runs <- read.csv(run_filenames[i]) %>% 
      bind_rows(collapse_runs)
  }
}

isl_series <- collapse$island.series


