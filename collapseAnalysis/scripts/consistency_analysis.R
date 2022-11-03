#Script to automate the consistency analysis for the collapse model

# Simulation Libraries ----------------------------------------------------------------
#Simple data manipulation
library(dplyr)
library(stringr) #String tidying for setup file reading

#Netlogo interface and futures for running in parallel
library(nlrx)
library(future)

#Benchmarking
library(tictoc)

# NL setup ----------------------------------------------------------------
#Where netlogo exe is stored...
netlogopath <- file.path("C:/Program Files/NetLogo 6.2.2")

#The model that I am running... 
modelpath <- file.path("D:/seabirdExtirpation/collapse_behav_space.nlogo")

#Where my results from the nrlx run will be stored...
outpath <- file.path("D:/seabirdExtirpation/output/consistency_analysis")

# Setup nl object - this initialises an instance of NetLogo
collapse_nl <- nl(nlversion = "6.2.2",
                  nlpath = netlogopath,
                  modelpath = modelpath,
                  jvmmem = 1024)

# Variable creation ----------------------------------------------------
# Creating a list of variables defaults to feed into the experiment one line at a time.
default_ls <- list(
  #Actual testing variables
  #Island setup controls
  "initialisation-data" = "\"./data/local_sensitivity_analysis/lsa_two_isl_baseline.csv\"",
  
  #Habitat controls
  "isl-att-curve" = "\"beta2\"",
  "diffusion-prop" = 0.4,
  "nhb-rad" = 4,
  "max-tries" = 6,
  
  #Mortality variables
  "natural-chick-mortality" = 0.4,
  "chick-mortality-sd" = 0.01,
  
  "juvenile-mortality" = 0.65,
  "juvenile-mortality-sd" = 0.05,
  
  "adult-mortality" = 0.05,
  "adult-mortality-sd" = 0.01,
  
  "enso-breed-impact" = "\"[0.5 0.2 0 0.2 0.5]\"",
  "enso-adult-mort" = "\"[0.25 0.1 0 0.1 0.25]\"",
  
  "max-age" = 28,
  "old-mortality" = 0.8,
  
  #Breeding controls
  "sex-ratio" = 1,
  "female-philopatry" = 0.95,
  "prop-returning-breeders" = 0.95,
  "age-first-return" = 5,
  "age-at-first-breeding" = 6,
  
  #Emigration controls
  "emigration-timer" = 4,
  "emigration-max-attempts" = 2,
  "emig-out-prob" = 0.8,
  "emigration-curve" = 0.5,
  "raft-half-way" = 200,
  
  #These are never changed....
  #Data export controls
  "behav-output-path" = "\"./output/consistency_analysis/\""#,
  #"output-file-name" = "\"./output/local_sensitivity_analysis/lsa_two_isl_meta.csv\"",
  
  #Hashing these controls out because it caused an error with dplyr which was:
  # dplyr::bind_rows(res, .id = .id) : 
  #   Can't combine `..3$update-colour?` <logical> and `..4$update-colour?` <character> - it was the first and may have been caused by R trying to join multiple columns???
  
  #"update-colour?" = "false",
  #"debug?" = "false",
  #"profiler?" = "false",
  #"verbose?" = "false",
  #"nlrx?" = "true",
  
  #"capture-data?" = "true",
  #"prospect?" = "true",
  #"collapse?" = "true",
  #"enso?"  = "true"
)

# LSA experiment setup ----------------------------------------------------
#A for loop to iterate over the possible combinations with one variable being moved +/- 10% each time, while all others are held at their default (i.e. best guess)

#Setting up the nlrx experiment
collapse_nl@experiment <- experiment(
  expname = "consistency",
  outpath = outpath,
  repetition = 1,
  tickmetrics = "false",
  idsetup = c("setup", "set-defaults"),
  idgo = "step",
  runtime = 1000,
  evalticks = c(1000),
  constants = default_ls,
  idfinal = "behav-csv",
  #The nlrx_id will need to be updated on the basis of the list to give them unique identifiers
  idrunnum = "nlrx-id"
)


# Simulation design -------------------------------------------------------
#Creating the simulation design - the nseeds is the number of replicates to do of each parameter set
collapse_nl@simdesign <- simdesign_simple(nl = collapse_nl,
                                            nseeds = 200)

#Pre-flight checks...
print(collapse_nl)
eval_variables_constants(collapse_nl)
#Nothing should be defined for either output-file-name (this is a manual trigger when using the NetLogo Interface) or nlrx-id - this widget get's filled by nlrx while experimenting

# Simulation run -----------------------------------------------------------

#Setting up parallelisation
plan(multisession)

#Bench marking
tic("Consistency experiment loop")

#Setting up the progress bar to keep track of how far the run is
progressr::handlers("progress")
cons_results <- progressr::with_progress(
  run_nl_all(collapse_nl,
             split = 1)
)

toc()

#Saving the list of model results as an RDS
#saveRDS(cons_results, "./output/consistency_analysis/cons_results.rds")

#Took approximately 8813.06 seconds (2.45 hours to run)

#Consistency analysis

#This script is for processing the consistency analysis data produced by NetLogo's behaviour space. A number of consistency analyses were run varying some key parameters, mainly the number of islands.


# Processing the nlrx data ------------------------------------------------

# Analysis Libraries ---------------------------------------------------------------

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
twoIsl_df <- list.files("../output/consistency_analysis/", 
                        pattern = ".csv",
                        full.names = TRUE) %>%  
  read_csv() %>% 
  
  #Creating a new column to keep track of the tick the run was up to
  group_by(run_id) %>% 
  mutate(ticks = 1:n())

#Deterimining how long the runs ran for on average
twoIsl_df %>% 
  group_by(run_id) %>% 
  summarise(runTime = max(ticks)) %>%
  summary()
#All of them ran for the correct amount of time

#Utility function
#https://stackoverflow.com/questions/52459711/how-to-find-cumulative-variance-or-standard-deviation-in-r
cumvar <- function (x, sd = FALSE) {
  x <- x - x[sample.int(length(x), 1)]  ## see Remark 2 below
  n <- seq_along(x)
  v <- (cumsum(x ^ 2) - cumsum(x) ^ 2 / n) / (n - 1)
  if (sd) v <- sqrt(v)
  v
}

#Calculating 
adult_c_df <- twoIsl_df %>% 
  filter(ticks > 50) %>%
  #Pivot to long format
  pivot_longer(cols = starts_with("settled_"),
               names_to = "island_id",
               values_to = "adult_count") %>% 
  mutate(line_id = paste(run_id, island_id)) %>% 
  group_by(run_id, island_id) %>% 
  mutate(adult_mean = cummean(adult_count),
         adult_sd = cumvar(adult_count, sd = TRUE)) %>% 
  ungroup()

adult_sum <- adult_c_df %>%
  group_by(island_id, ticks) %>% 
  summarise(isl_mean = mean(adult_count, na.rm = T),
            isl_sd = sd(adult_count, na.rm = T))


#Plotting the count by island to visualise the data through time.
ggplot() +
  # geom_line(data = adult_c_df, 
  #           aes(ticks, adult_count,
  #               group = line_id,
  #               colour = island_id),
  #           alpha = 0.5) +

  geom_ribbon(data = adult_sum,
              aes(ticks, 
                  ymin = isl_mean - isl_sd,
                  ymax = isl_mean + isl_sd, 
                  group = island_id,
                  fill = island_id),
              colour = "black",
              alpha = 0.2) + 
  geom_line(data = adult_sum,
            aes(ticks, isl_mean, 
                group = island_id,
                colour = island_id)) +
  scale_x_continuous(breaks = seq(0, 1000, by = 50)) +
  theme(axis.text.x = element_text(angle = 45)) + 
  

#Trying to plot the mean/median of each island for the last 50 years
adult_c_df %>% 
  filter(ticks > 950) %>%
  group_by(run_id, island_id) %>%
  summarise(median_50y = mean(adult_count)) %>%
  ungroup() %>%
  ggplot(aes(y = median_50y, x = island_id)) + 
  geom_boxplot()


#Determining the number of ticks before the simulation stabilises on the basis of a cumulative mean and standard deviation by each island.
#Plot of cumulative mean
ggplot(adult_c_df, aes(ticks, adult_mean,
                       group = line_id,
                       colour = island_id)) +
  geom_line(alpha = 0.5) +
  scale_x_continuous(breaks = seq(50, 1000, by = 50)) +
  theme(axis.text.x = element_text(angle = 45))

#The cumulative standard deviation of adult counts through time.

ggplot(adult_c_df, aes(ticks, adult_sd,
                       group = line_id,
                       colour = island_id)) +
  geom_line(alpha = 0.5) +
  scale_x_continuous(breaks = seq(50, 1000, by = 50)) +
  theme(axis.text.x = element_text(angle = 45))


#Determining the number of replicates needed of a particular parameter set to accurately capture variability.
#Calculating 
adult_var_df <- twoIsl_df %>% 
  filter(ticks == 1000) %>%
  pivot_longer(cols = starts_with("settled_"),
               names_to = "island_id",
               values_to = "adult_count") %>%
  select(c(run_id, island_id, adult_count)) %>%
  arrange(run_id)

adult_var_df$run_num <- rep((1:(nrow(adult_var_df)/2)), each = 2) 

adult_var_df <- adult_var_df %>% 
  group_by(island_id) %>% 
  mutate(adult_mean = cummean(adult_count),
         adult_sd = cumvar(adult_count, sd = TRUE))

#This plot suggests the  mean number of adults seems to stabalise at about 60 runs
ggplot(adult_var_df, aes(run_num, adult_mean,
                         group = island_id,
                         colour = island_id)) +
  geom_line(alpha = 0.5) +
  theme(axis.text.x = element_text(angle = 45))

#This plot suggests the standard deviation around the mean number of adults seems to stabalise at about 25 -> 50 runs
ggplot(adult_var_df, aes(run_num, adult_sd,
                         group = island_id,
                         colour = island_id)) +
  geom_line(alpha = 0.5) +
  theme(axis.text.x = element_text(angle = 45))

