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

#(115 hrs)
#saveRDS(extir_results_2, "../output/extirpation_simulation/extir_results.rds")

#names(extir_results_2) <- names(extir_ls)


#Checking the number of unique parameter settings
#length(unlist(gsa_ls))
#121 unique parameters - 100 seeds, so 10100 runs


