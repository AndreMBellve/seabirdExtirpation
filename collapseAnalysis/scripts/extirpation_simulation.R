#Extirpation Analysis

#This script runs a simulation experiment through nlrx for the collapse model (base), with the key parameter varying being the amount of adult and chick predation 


# Simulation Libraries ----------------------------------------------------------------
#Simple data manipulation
library(dplyr)
library(stringr) #String tidying for setup file reading
library(tictoc)

#Netlogo interface and futures for running in parallel
library(nlrx)
library(future)

# NL setup ----------------------------------------------------------------
#Where netlogo exe is stored...
netlogopath <- file.path("C:/Program Files/NetLogo 6.2.2")

#The model that I am running... 
modelpath <- file.path("D:/seabirdExtirpation/collapse_extirpation.nlogo")

#Where my results from the nrlx run will be stored...
outpath <- file.path("D:/seabirdExtirpation/output/extirpation_simulation")

# Setup nl object - this initialises an instance of NetLogo
collapse_extir_nl <- nl(
  nlversion = "6.2.2",
  nlpath = netlogopath,
  modelpath = modelpath,
  jvmmem = 1024
)

# Variable creation ----------------------------------------------------
# Creating a list of variables defaults to feed into the experiment one line at a time.
extir_default_ls <- list(
  #Actual testing variables
  #Island setup controls
  "initialisation-data" = "\"./data/extirpation_simulation/extir_two_isl_baseline.csv\"",
  
  #System controls
  "isl-att-curve" = "\"beta2\"",
  "diffusion-prop" = 0.4,
  "nhb-rad" = 4,
  "max-tries" = 6,
  
  #Added Isl GSA controls (applies to all islands)
  "prop-suitable" = 0.3,
  "clust-area" = 10, 
  "habitat-aggregation" = 0.2,
  
  #Habitat controls
  "burrow-attrition-rate" = 0.2,
  "patch-burrow-minimum" = 5,
  
  "time-to-prospect" = 2,
  "patch-burrow-limit" = 100,
  
  "collapse-half-way" = 150,
  "collapse-perc" = 0.25,
  "collapse-perc-sd" = 0.05,
  
  #Mortality variables
  "natural-chick-mortality" = 0.4,
  "chick-mortality-sd" = 0.1,
  
  "juvenile-mortality" = 0.65,
  "juvenile-mortality-sd" = 0.1,
  
  "adult-mortality" = 0.05,
  "adult-mortality-sd" = 0.01,
  
  "enso-breed-impact" = "\"[0.5 0.2 0 0.2 0.5]\"",
  "enso-adult-mort" = "\"[0.05 0.025 0 0.025 0.05]\"",
  
  "max-age" = 30,
  "old-mortality" = 0.8,
  
  #Breeding controls
  "sex-ratio" = 1,
  "female-philopatry" = 0.95,
  "prop-returning-breeders" = 0.85,
  "age-first-return" = 5,
  "age-at-first-breeding" = 6,
  
  
  #Emigration controls
  "emigration-timer" = 4,
  "emigration-max-attempts" = 2,
  "emig-out-prob" = 0.75,
  "emigration-curve" = 0.5,
  "raft-half-way" = 250,
  
  #These are never changed....
  #Data export controls
  "behav-output-path" = "\"./output/extirpation_simulation/\""
)

extir_ls <- list(
  "chick-predation" = list(values = c(0, 0.1, 0.2, 0.3, 0.4, 0.5)),
  "adult-predation" = list(values = c(0, 0.01, 0.02, 0.03, 0.04, 0.05))
  )

# Extirpation experiment setup ----------------------------------------------------

#Bench marking
tic("Extirpation experiment")

#Setting up the nlrx experiment
collapse_extir_nl@experiment <- experiment(
  expname = "extir",
  outpath = outpath,
  repetition = 1,
  tickmetrics = "false",
  idsetup = "setup",
  idgo = "step",
  runtime = 500,
  evalticks = c(500),
  stopcond = "not any? turtles",
  variables =  extir_ls,
  constants = extir_default_ls,
  idfinal = "behav-csv",
  #The nlrx_id will need to be updated on the basis of the list to give them unique identifiers
  idrunnum = "nlrx-id"
)

# Simulation design -------------------------------------------------------
#Creating the simulation design - the nseeds is the number of replicates to do of each parameter set.
collapse_extir_nl@simdesign <- simdesign_ff(nl = collapse_extir_nl,
                                                nseeds = 100)

#Pre-flight checks...
print(collapse_extir_nl)
eval_variables_constants(collapse_extir_nl)
#Nothing should be defined for either output-file-name (this is a manual trigger when using the NetLogo Interface) or nlrx-id - this widget get's filled by nlrx while experimenting

# Simulation run -----------------------------------------------------------

#Setting up parallelisation
plan(multisession)

#Setting up the progress bar to keep track of how far the run is
progressr::handlers("progress")
extir_results_2 <- progressr::with_progress(
  run_nl_all(collapse_extir_nl,
             split = 12)
)

toc()

#(110 hrs)
#saveRDS(extir_results_2, "../output/extirpation_simulation/extir_results.rds")

#names(extir_results_2) <- names(extir_ls)


#Checking the number of unique parameter settings
#length(unlist(gsa_ls))
#121 unique parameters - 100 seeds, so 10100 runs


# Extirpation analysis ----------------------------------------------------

#Reading in large data
library(vroom)

#Data manipulations
library(janitor) #Name amendments
library(dplyr) #Data manipulations
library(tidyr) #Pivoting
library(stringr) #Parsing data

#Graphing
library(ggplot2) #Plots
library(viridis) #Colour scheme 


# #Reading in files
# extirp_res_vr <- list.files("../output/extirpation_simulation/",
#                         pattern = ".csv",
#                         full.names = TRUE) %>%
#   vroom() %>%
# 
#  
#   #Creating a new column to keep track of the tick the run was up to
#   group_by(run_id) %>%
# 
#   #Adding in ticks to sheet
#   mutate(ticks = 1:n()) %>%
# 
#   ungroup()
# 
#  #Writing a single large file with some minor manipulations to make it quicker to read in and access
# vroom_write(extirp_res_vr,
#           "./output/extirpation_simulation/extirp_allrun_data.csv",
#           col_names = TRUE)

#Meta information for each run 
extirp_meta_df <- readRDS("../output/extirpation_simulation/extir_results.rds") %>% 
  clean_names()

#Reading in the run data
extirp_df <-  vroom("./output/extirpation_simulation/extirp_allrun_data.csv") %>% 
  #Reducing this to just the last 50 years of data to summarise over.
  #filter(ticks >= 450) %>% 
  #Joining on the meta data
  left_join(extirp_meta_df, 
            by = c("run_id" = "nlrx_id")) %>% 
  pivot_longer(cols = starts_with("settled_"),
               names_to = "island_id",
               values_to = "adult_count") %>%  
  #Creating some convience columns 
  mutate(island_id = str_sub(island_id, 
                             start = 16L, end = 16L),
         predators = ifelse(island_id == "1", "Present", "Absent"),
         run_number = as.factor(run_number))



# Graphing ----------------------------------------------------------------

seaPal <- wesanderson::wes_palette("FantasticFox1")[c(4,3, 1)] 
#c("#440154FF",  "#FDE725FF")
#viridis(n = 2, begin = 0.2)

ggplot(extirp_df[sample(n = 10^4, 1:180000),],
  aes(x = ticks, y = adult_count,
    colour = predators,
    group = interaction(run_number,  island_id))) +
  
  geom_line(linewidth = 0.8) +
  scale_colour_manual(values = seaPal, 
                      name = "Predation") +
  
  labs(y = "Adults (Count)", x = "Years") +
  #xlim(c(5, 100)) +
  
 
  
 facet_grid(chick_pred_isl_1 ~ adult_pred_isl_1) +
theme_minimal() +
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
extirp_summ <- extirp_df %>% 
  group_by(chick_predation, adult_predation, island_id, ticks, predators) %>% 
  summarise(adult_mean = mean(adult_count),
            adult_sd = sd(adult_count),
            adult_lwr = adult_mean - adult_sd,
            adult_lwr = replace(adult_lwr, adult_lwr < 0, 0),
            adult_upr = adult_mean + adult_sd)


#Calculating an average for the null no predation scenario to compare other scenarios too

null_scenario <- extirp_summ %>% 
  filter(chick_predation == 0 & adult_predation == 0) %>% 
  filter(ticks > 100) %>% 
  group_by(island_id) %>% 
  summarise(mean_count = mean(adult_mean))

ggplot(extirp_summ,
       aes(x = ticks, y = adult_mean,
           colour = predators,
           group = interaction(chick_predation,
                               adult_predation,
                               island_id))) +

  
  geom_ribbon(aes(ymin = adult_lwr, 
                  ymax = adult_upr,
                  fill = predators,
                  colour = predators),
              alpha = 0.7) + 
  
  geom_line(aes(linetype = predators),
            colour = "black") +
  
  geom_hline(aes(yintercept = 40750),
             colour = "#ff960f",
             linetype = "dotdash",
             linewidth = 0.5) +
  
  scale_colour_manual(values = c("#F21A00","#3B9AB2"), 
                      name = "Predator Status") +
  scale_fill_manual(values = c("#F21A00","#3B9AB2"), 
                      name = "Predator Status") +
  
  scale_linetype_manual(values = c("solid", "dashed"), 
                    name = "Island Status") +
  
  labs(y = "Mean Adult Count", x = "Years") +
  
  scale_x_continuous(breaks = seq(0, 500, by = 100)) +
  
  facet_grid(chick_predation ~ adult_predation) + 
  
  theme_bw() +
  
  theme(axis.text = element_text(size = 12),
        axis.text.x = element_text(angle = 90),
        axis.title = element_text(size = 14),
        strip.text = element_text(size = 12),
        legend.text = element_text(size = 12),
        legend.title = element_text(size = 14),
        panel.grid = element_blank())


#Calculate the time to the predator invaded island reaching (min time, max time, mean time for each scenario)
