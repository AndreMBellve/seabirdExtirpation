#Script to automate the global sensitivity analysis for the collapse model

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
outpath <- file.path("D:/seabirdExtirpation/output/global_sensitivity_analysis")

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
  "behav-output-path" = "\"./output/local_sensitivity_analysis/\""#,
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


#Creating a vector of all the initialisation files to be iterated over.
init_files <- list.files("../data/local_sensitivity_analysis/", full.names = TRUE) %>%
  #Removing the start of the path that doesn't apply to the NL model
  str_remove(".") %>% 
  #Converting it to the format nlrx needs to pass it to NL
  paste0("\"", ., "\"")


#LSA list - each variable +/- 10% which will be drawn from 1 at a time during the for loop
gsa_ls <- list(
  #Actual testing variables
  #Island setup controls
  #Habitat controls
  "isl-att-curve" = list(values = c("\"beta2\"", "\"beta1\"", "\"uniform\"")),

  #Mortality variables
  "natural-chick-mortality" = list(min = 0, max = 1,, step = 0.01, qfun = "qunif"),
  "chick-mortality-sd" = list(min = 0, max = 1,, step = 0.01, qfun = "qunif"),
  
  "adult-mortality" = list(min = 0, max = 1,, step = 0.01, qfun = "qunif"),

  #Island selection and return
  "female-philopatry" = list(min = 0, max = 1,, step = 0.01, qfun = "qunif"),
  "prop-returning-breeders" = list(min = 0, max = 1,, step = 0.01, qfun = "qunif"),
  "age-at-first-breeding" = list(min = 2, max = 15, step = 1, qfun = "qunif"),
  
  #Emigration controls
  "emigration-timer" = list(min = 1, max = 40, step = 1, qfun = "qunif")
  )


#Check that these match-up!
if(any(names(default_ls[1:length(lsa_ls)]) != names(lsa_ls))){
  stop("!!VARIABLE LISTS DO NO MATCH!!")
}


# lsa_ls <- list(
#   "initialisation-data" = list(values = c("\"./data/local_sensitivity_analysis/lsa_two_isl_prosp_d.csv\"")),
#   "max-tries" = list(values = c(5, 6, 7)),
#   "chick-mortality-sd" = list(values = c(0.009, 0.01, 0.011)))
# #If ^ this is TRUE we have a problem and needs to be checked again!!!


# LSA experiment setup ----------------------------------------------------
#Creating an empty list to fill with the LSA results.
lsa_results <- list()

#A for loop to iterate over the possible combinations with one variable being moved +/- 10% each time, while all others are held at their default (i.e. best guess)

#Bench marking
tic("GSA experiment loop")


  
  #Setting up the nlrx experiment
  collapse_nl@experiment <- experiment(
    expname = paste0("gsa_", variable_name),
    outpath = "./",
    repetition = 1,
    tickmetrics = "false",
    idsetup = c("setup"),
    idgo = "step",
    runtime = 500,
    evalticks = c(500),
    #metrics = "",
    variables = gsa_ls,
    constants = default_ls,
    idfinal = "behav-csv",
    #The nlrx_id will need to be updated on the basis of the list to give them unique identifiers
    idrunnum = "nlrx-id"
  )
  
  
  # Simulation design -------------------------------------------------------
  #Creating the simulation design - the nseeds is the number of replicates to do of each parameter set.
  collapse_nl@simdesign <- simdesign_lhs(nl = collapse_nl,
                                         samples = 100,
                                         nseeds = 100,
                                         precision = 3)
  
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
  lsa_results[[i]] <- progressr::with_progress(
    run_nl_all(collapse_nl,
               split = ncores)
  )
  
  #Written progress of how many variables have been completed
  cat(paste("Finished analysis of", variable_name, "-", i, "/", length(lsa_ls)))
  
}

toc()

#(148 hrs)

names(lsa_results) <- names(lsa_ls)

#Saving the list of model results as an RDS
#saveRDS(lsa_results, "./output/local_sensitivity_analysis/lsa_meta_results.rds")


#Checking the number of unique parameter settings
length(unlist(lsa_ls))
#109 unique parameters - 100 seeds, so 10100 runs
