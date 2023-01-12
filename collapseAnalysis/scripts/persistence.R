#Persistence experiment - how long can a colony persist for under varying levels of chick and adult predation


# Simulation Libraries ----------------------------------------------------------------
#Simple data manipulation
library(dplyr)
library(stringr) #String tidying for setup file reading

#Netlogo interface and futures for running in parallel
library(nlrx)
library(future)

# NL setup ----------------------------------------------------------------
#Where netlogo exe is stored...
netlogopath <- file.path("C:/Program Files/NetLogo 6.2.2")

#The model that I am running... 
modelpath <- file.path("D:/seabirdExtirpation/collapse_behav_space.nlogo")

#Where my results from the nrlx run will be stored...
outpath <- file.path("D:/seabirdExtirpation/output/persistence")

# Setup nl object - this initialises an instance of NetLogo
persist_nl <- nl(nlversion = "6.2.2",
                  nlpath = netlogopath,
                  modelpath = modelpath,
                  jvmmem = 1024)

# Variable creation ----------------------------------------------------
# Creating a list of variables defaults to feed into the experiment one line at a time.
default_ls <- list(
  #Actual testing variables
  #Island setup controls
  #System controls
  "isl-att-curve" = "\"beta2\"",
  "diffusion-prop" = 0.4,
  "nhb-rad" = 4,
  "max-tries" = 6,
  
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
  #"age-first-return" = 5,
  "age-at-first-breeding" = 6,
  
  #Emigration controls
  "emigration-timer" = 4,
  "emigration-max-attempts" = 2,
  "emig-out-prob" = 0.75,
  "emigration-curve" = 0.5,
  "raft-half-way" = 250,
  
  #These are never changed....
  #Data export controls
  "behav-output-path" = "\"../output/persistence/\""
)

#Creating a vector of all the initialisation files to be iterated over.
init_files <- list.files("../data/persistence/", full.names = TRUE) %>%
  #Removing the start of the path that doesn't apply to the NL model
  str_remove(".") %>% 
  #Converting it to the format nlrx needs to pass it to NL
  paste0("\"", ., "\"")


#LSA list - each variable +/- 10% which will be drawn from 1 at a time during the for loop
persist_ls <- list(
  #Actual testing variables
  #Island setup controls
  #init_files is setup outside of the list to pull in all the files from a particular folder to iterate over.
  "initialisation-data" = list(values = init_files)
)


# LSA experiment setup ----------------------------------------------------
#Creating an empty list to fill with the LSA results.
persist_results <- list()

#A for loop to iterate over the possible combinations with one variable being moved +/- 10% each time, while all others are held at their default (i.e. best guess)

#Bench marking
tic("Persistence experiment loop")


  # #Creating the basis for the nlrx-id to be the name of the variable that is changing to make it easier to match these with the meta-results list and find all the run names. Have to bind on the \ and " because NL can't directly read strings, unless they are simple true/false.
  # default_ls[["nlrx-id"]] <- variable_name  %>%
  #   paste0("\"", ., "\"")
  # # 
  #Finding the number of values that are being iterated over 
  param_length <- length(persist_ls[[1]]$values)
  
  #Setting up the nlrx experiment
  persist_nl@experiment <- experiment(
    expname = paste0("persist_", variable_name),
    outpath = "./",
    repetition = 1,
    tickmetrics = "false",
    idsetup = c("setup"),
    idgo = "step",
    runtime = 500,
    evalticks = c(500),
    #metrics = "",
    variables = persist_ls[1],
    constants = default_ls,
    idfinal = "behav-csv",
    #The nlrx_id will need to be updated on the basis of the list to give them unique identifiers
    idrunnum = "nlrx-id"
  )
  
  
  # Simulation design -------------------------------------------------------
  #Creating the simulation design - the nseeds is the number of replicates to do of each parameter set.
  persist_nl@simdesign <- simdesign_distinct(nl = persist_nl,
                                              nseeds = 100)
  
  #Pre-flight checks...
  #print(collapse_nl)
  #eval_variables_constants(collapse_nl)
  #Nothing should be defined for either output-file-name (this is a manual trigger when using the NetLogo Interface) or nlrx-id - this widget get's filled by nlrx while experimenting
  
  # Simulation run -----------------------------------------------------------
  
  #Setting up parallelisation
  plan(multisession)
  
  #Put in the number of cores that it is possible to use (in this case my machine have 12 cores and I leave two open for other processing)
  ncores <- max(which((param_length %% (1:15)) == 0))
  
  #Setting up the progress bar to keep track of how far the run is
  progressr::handlers("progress")
  persist_results <- progressr::with_progress(
    run_nl_all(persist_nl,
               split = ncores)
  )

toc()

#Persistence experiment loop: 5453.73 sec elapsed - 100 seeds × 50 ticks 

#Saving the list of model results as an RDS
#saveRDS(persist_results, "./output/persistence/persist_meta_results.rds")


