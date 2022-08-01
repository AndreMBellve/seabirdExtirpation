#Consistency analysis

#This script is for processing the consistency analysis data produced by NetLogo's behaviour space. A number of consistency analyses were run varying some key parameters, mainly the number of islands.


# Libraries ---------------------------------------------------------------

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
twoIsl_df <- list.files("../output/consistency/two_isl/", 
                        pattern = "run.csv",
                        full.names = TRUE) |>  
  read_csv() |> 
  
  #Creating a new column to keep track of the tick the run was up to
  group_by(run) |> 
  mutate(ticks = 1:n())

#Deterimining how long the runs ran for on average
twoIsl_df |> 
  group_by(run) |> 
  summarise(runTime = max(ticks)) |> 
  plot()

#Calculating 
adult_c_df <- twoIsl_df |> 
  #Pivot to long format
  pivot_longer(cols = starts_with("settled_"),
               names_to = "island_id",
               values_to = "adult_count") |> 
  #Removing the observation that hit an error because it disrupted the 
  #filter()
  mutate(line_id = paste(run, island_id)) |> 
  group_by(run, island_id) |> 
  mutate(adult_mean = cummean(adult_count))#,
         #adult_sd = rollapply(adult_count, width = 1:800, FUN = sd))
  
#Plotting
ggplot(adult_c_df, aes(ticks, adult_count,
                        group = line_id,
                        colour = island_id)) +
  geom_line(alpha = 0.5) +
  scale_x_continuous(breaks = seq(0, 800, by = 50)) +
  theme(axis.text.x = element_text(angle = 45))

#Plot of cumulative mean
ggplot(adult_c_df, aes(ticks, adult_mean,
                        group = line_id,
                        colour = island_id)) +
  geom_line(alpha = 0.5) +
  scale_x_continuous(breaks = seq(0, 800, by = 50)) +
  theme(axis.text.x = element_text(angle = 45))
