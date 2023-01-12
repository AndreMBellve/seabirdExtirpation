#Script to automate the global sensitivity analysis for the collapse model

# Simulations -------------------------------------------------------------


## Simulation Libraries ----------------------------------------------------------------
#Simple data manipulation
library(dplyr)
library(stringr) #String tidying for setup file reading
library(tictoc)

#Netlogo interface and futures for running in parallel
library(nlrx)
library(future)

## NL setup ----------------------------------------------------------------
#Where netlogo exe is stored...
netlogopath <- file.path("C:/Program Files/NetLogo 6.2.2")

#The model that I am running... 
modelpath <- file.path("D:/seabirdExtirpation/collapse_GSA.nlogo")

#Where my results from the nrlx run will be stored...
outpath <- file.path("D:/seabirdExtirpation/output/global_sensitivity_analysis")

# Setup nl object - this initialises an instance of NetLogo
collapse_gsa_nl <- nl(
  nlversion = "6.2.2",
  nlpath = netlogopath,
  modelpath = modelpath,
  jvmmem = 1024
)

## Variable creation ----------------------------------------------------
# Creating a list of variables defaults to feed into the experiment one line at a time.
gsa_default_ls <- list(
  #Actual testing variables
  #Island setup controls
  "initialisation-data" = "\"./data/global_sensitivity_analysis/gsa_two_isl_baseline.csv\"",
  
  #System controls
  "isl-att-curve" = "\"beta2\"",
  "diffusion-prop" = 0.4,
  "nhb-rad" = 4,
  #Habitat controls
  "burrow-attrition-rate" = 0.2,
  "patch-burrow-minimum" = 5,
  
  "time-to-prospect" = 2,
  "patch-burrow-limit" = 100,
  
  "collapse-perc" = 0.25,
  "collapse-perc-sd" = 0.05,
  
  #Mortality variables
  "chick-mortality-sd" = 0.1,
  
  "juvenile-mortality" = 0.65,
  "juvenile-mortality-sd" = 0.1,
  
  "adult-mortality" = 0.05,
  "adult-mortality-sd" = 0.01,
  
  "enso-breed-impact" = "\"[0.5 0.2 0 0.2 0.5]\"",
  "enso-adult-mort" = "\"[0.05 0.025 0 0.025 0.05]\"",
  
  "old-mortality" = 0.8,
  
  #Breeding controls
  "age-at-first-breeding" = 6,
  
  #Emigration controls
  "emigration-max-attempts" = 2,
  "emigration-curve" = 0.5,
  "raft-half-way" = 250,
  
  #These are never changed....
  #Data export controls
  "behav-output-path" = "\"./output/global_sensitivity_analysis/\""
)


#gsa list - each variable +/- 10% which will be drawn from 1 at a time during the for loop
gsa_ls <- list(
  #Actual testing variables
  #Island setup controls
  #init_files is setup outside of the list to pull in all the files from a particular folder to iterate over.
  "chick-predation" = list(min = 0.2, max = 1, step = 0.01, qfun = "qunif"),
  "clust-area" = list(min = 2, max = 15, step = 1, qfun = "qunif"), ## if this parameter is too big the model takes forever to run because there are too many agents. - it is the radius of the island
  "collapse-half-way" = list(min = 10, max = 200, step = 10, qfun = "qunif"),
  "emig-out-prob" = list(min = 0.1, max = 0.90, step = 0.05, qfun = "qunif"),
  "emigration-timer" = list(min = 1, max = 8, step = 1, qfun = "qunif"),
  "female-philopatry" = list(min = 0.5, max = 0.98, step = 0.01, qfun = "qunif"),
  "habitat-aggregation" = list(min = 0.2, max = 0.8, step = 0.01, qfun = "qunif"),
  "max-age" = list(min = 10, max = 40, step = 1, qfun = "qunif"),
  "max-tries" = list(min = 2, max = 10, step = 1, qfun = "qunif"),
  "natural-chick-mortality" = list(min = 0.2, max = 0.6, step = 0.01, qfun = "qunif"),
  "prop-returning-breeders" = list(min =  0.5, max = 1, step = 0.01, qfun = "qunif"),
  "prop-suitable" = list(min = 0.1, max = 0.9, step = 0.01, qfun = "qunif"),
  "sex-ratio" = list(min = 0.5, max = 2, step = 0.05 , qfun = "qunif")
  )

## GSA experiment setup ----------------------------------------------------

#Bench marking
tic("GSA experiment")
  
  #Setting up the nlrx experiment
  collapse_gsa_nl@experiment <- experiment(
    expname = "gsa",
    outpath = outpath,
    repetition = 1,
    tickmetrics = "false",
    idsetup = "setup",
    idgo = "step",
    runtime = 500,
    evalticks = c(500),
    stopcond = "not any? turtles",
    variables = gsa_ls,
    constants = gsa_default_ls,
    idfinal = "behav-csv",
    #The nlrx_id will need to be updated on the basis of the list to give them unique identifiers
    idrunnum = "nlrx-id"
  )
  
  
## Simulation design -------------------------------------------------------
  #Creating the simulation design - the nseeds is the number of replicates to do of each parameter set.
  collapse_gsa_nl@simdesign <- simdesign_lhs(nl = collapse_gsa_nl,
                                             samples = 5010,
                                             precision = 2,
                                             nseeds = 1)
  
  
  #gsa list - each variable +/- 10% which will be drawn from 1 at a time during the for loop
  int_param <- c("clust-area","collapse-half-way", "emigration-timer",  "max-age", "max-tries")
  
  for(i in 1:ncol(collapse_gsa_nl@simdesign@siminput)){
    if(names(collapse_gsa_nl@simdesign@siminput[,i]) %in% int_param){
      collapse_gsa_nl@simdesign@siminput[,i] <- round(collapse_gsa_nl@simdesign@siminput[,i], digits = 0 )
    }
  }
  
  #View(collapse_gsa_nl@simdesign@siminput)
  

  
  
  #Pre-flight checks...
  print(collapse_gsa_nl)
  eval_variables_constants(collapse_gsa_nl)
  #Nothing should be defined for either output-file-name (this is a manual trigger when using the NetLogo Interface) or nlrx-id - this widget get's filled by nlrx while experimenting
  
## Simulation run -----------------------------------------------------------
  
  #Setting up parallelisation
  plan(multisession)
  
  #Setting up the progress bar to keep track of how far the run is
  progressr::handlers("progress")
  gsa_results_2 <- progressr::with_progress(
    run_nl_all(collapse_gsa_nl,
               split = 15)
  )

toc()

#(115 hrs)
#saveRDS(gsa_results_2, "../output/global_sensitivity_analysis/gsa_results_2.rds")

#names(gsa_results_2) <- names(gsa_ls)


#Checking the number of unique parameter settings
#length(unlist(gsa_ls))
#121 unique parameters - 100 seeds, so 10100 runs



# Analysis ----------------------------------------------------------------


## Analysis Libraries ------------------------------------------------------
#Data manipulations
library(readr) #reading in all files
library(vroom)
library(janitor) #Name amendments
library(dplyr) #Data manipulations
library(tidyr) #Pivoting
library(stringr) #Parsing data
library(zoo) #Calculating cumulative statistics

#Graphing
library(ggplot2) #Plots
library(viridis) #Colour scheme 
library(lemon)

#Analysis
library(caret)
library(pdp)
library(gbm)

library(tictoc)

#Custom functions
#https://stackoverflow.com/questions/52459711/how-to-find-cumulative-variance-or-standard-deviation-in-r
source("./scripts/functions/cumvar.r")

## Reading in data ---------------------------------------------------------

#Reading in files
# tic("Reading individual files")
# 
# gsa_res_vr <- list.files("../output/global_sensitivity_analysis/",
#                         pattern = ".csv",
#                         full.names = TRUE) %>%
#   vroom() %>%
# 
#   # #tidying initialisation names for ease of handling
#   # mutate(initialisation_data = str_remove(
#   #   str_remove(initialisation_data,
#   #              "./data/global_sensitivity_analysis/"),
#   #   ".csv")) %>%
#   #
#   #Creating a new column to keep track of the tick the run was up to
#   group_by(run_id) %>%
# 
#   #Adding in ticks to sheet
#   mutate(ticks = 1:n()) %>%
# 
#   ungroup()
# 
# toc()
# #Reading in individual files took 183.5 seconds
# 
# # #Writing a single large file with some minor manipulations to make it quicker to read in and access
# vroom_write(gsa_res_vr,
#           "./output/global_sensitivity_analysis/gsa_allrun_data.csv",
#           col_names = TRUE)

#Meta information 
gsa_meta_ls <- readRDS("../output/global_sensitivity_analysis/gsa_results_2.rds")

#Merging to a single df
gsa_meta_df <- bind_rows(gsa_meta_ls, .id = "varying_param") %>% 
  select(-c(`[run number]`, `[step]`, siminputrow)) 

#Changing names to for ease of typing
names(gsa_meta_df) <- str_replace_all(names(gsa_meta_df), "[-]", "_")

#Reading in combined files
gsa_df <- vroom("./output/global_sensitivity_analysis/gsa_allrun_data.csv") %>% 
  #Reducing this to just the last 50 years of data to summarise over.
  #filter(ticks >= 450) %>% 
  #Joining on the meta data
  left_join(gsa_meta_df, 
            by = c("run_id" = "nlrx_id")) %>% 
  pivot_longer(cols = starts_with("settled_"),
               names_to = "island_id",
               values_to = "adult_count") 


#Setting a reproducible seed
set.seed(42)

## Time to extinction analysis-------------------------------------------------------------------------
#Collapsing dataframe down to the time it took for the birds to go extinct
gsa_ext_time_df <- gsa_df %>%
  group_by(run_id) %>% 
  slice_tail()

#Subsetting dataframe to just the covariates (changing input params) and the response (time to extinction)
extinct_time_df <- gsa_ext_time_df %>% 
  ungroup() %>% 
  filter(ticks != 500) %>% 
  #removing the first one as it does not change
  dplyr::select(c(ticks, str_replace_all(names(gsa_ls), "-", "_"))) %>% 
  rename("time" = "ticks")

#Setting up the tuning parameter controls
gsa_et_tc <- trainControl(method = "cv",
                          number = 5,
                          search = "grid",
                          returnResamp = "all")


tic("extinction time gbm")
# #Fitting gradient boosting machine (linear)
# ext_time_gbml <- train(time ~ .,
#                        method = "xgbLinear",
#                        tuneLength = 12,
#                        trControl = gsa_et_tc,
#                        data = extinct_time_df)

ext_time_gbm <- train(time ~ .,
                       method = "gbm",
                       tuneLength = 12,
                       trControl = gsa_et_tc,
                       data = extinct_time_df)

toc()


#<4-5 hr cook time

#Saving model for later
#saveRDS(ext_time_gbml, "./output/global_sensitivity_analysis/ext_time_gbml.rds")

#Chick predation most important!
#varImp(ext_time_rf)

varImp(ext_time_gbm)

# Creating partial dependence curves for the pop size classes
extTime_pdp_plots <- vector(mode = "list", length = length(ext_time_rf$coefnames))

for (i in seq_along(ext_time_rf$coefnames)) {
  
  print(i)
  
  df_i <- ext_time_rf %>%
    pdp::partial(pred.var = ext_time_rf$coefnames[i],
                 plot.engine = "ggplot2",
                 plot = FALSE,
                 type = "regression")
  
  # tidy
  df_i <- data.frame(var = ext_time_rf$coefnames[i], df_i)
  colnames(df_i) <- c("var", "x", "y")
  extTime_pdp_plots[[i]] <- df_i
  
}

# clean up output
extTime_pdp_plots_clean <- bind_rows(extTime_pdp_plots)

extTime_pdp_var_imp <- varImp(ext_time_rf)[[1]] %>% 
  arrange(desc(Overall))
extTime_pdp_var_imp$var <- row.names(extTime_pdp_var_imp)


extTime_pdp_plots_clean


#rename model params for plotting
extTime_pdp_plots_clean <- extTime_pdp_plots_clean %>%
  mutate(var = recode(var,
                      "chick_predation" = "Chick Predation(mean)",
                      "clust_area" = "Island Radius",
                      "collapse_half_way" = "Collapse 50% Threshold",
                      "emig_out_prob" = "Emigrate out of System (%)",
                      "emigration_timer" =  "Successive Failed Breeding Tries" ,
                      "female_philopatry" = "Female Philopatry",
                      "habitat_aggregation" = "Habitat Aggregation",
                      "max_age" = "Senior Mortality Age",
                      "max_tries" = "Maximum Courting Attempts",
                      "natural_chick_mortality" = "Natural Chick Mortality",
                      "prop_returning_breeders" = "Proportion of Breeders Returning",
                      "prop_suitable" = "Proportion of Suitable Habitat",
                      "sex_ratio" = "Sex Ratio"))


extTime_pdp_var_imp <- extTime_pdp_var_imp %>%
  mutate(var = recode(var,
                      "chick_predation" = "Chick Predation(mean)",
                      "clust_area" = "Island Radius",
                      "collapse_half_way" = "Collapse 50% Threshold",
                      "emig_out_prob" = "Emigrate out of System (%)",
                      "emigration_timer" =  "Successive Failed Breeding Tries" ,
                      "female_philopatry" = "Female Philopatry",
                      "habitat_aggregation" = "Habitat Aggregation",
                      "max_age" = "Senior Mortality Age",
                      "max_tries" = "Maximum Courting Attempts",
                      "natural_chick_mortality" = "Natural Chick Mortality",
                      "prop_returning_breeders" = "Proportion of Breeders Returning",
                      "prop_suitable" = "Proportion of Suitable Habitat",
                      "sex_ratio" = "Sex Ratio"))


# fix var order for plotting
extTime_pdp_plots_clean$var <-  factor(extTime_pdp_plots_clean$var,
                                     levels = extTime_pdp_var_imp$var)

extTime_pdp_var_imp$var <- as.factor(extTime_pdp_var_imp$var)

extTime_pdp_var_imp2 <- extTime_pdp_var_imp %>%
  filter(Overall > 10)

extTime_pdp_plots_clean2 <- extTime_pdp_plots_clean %>%
  filter(var %in% extTime_pdp_var_imp2$var)


# add vertical line for default model setting
df_line <- data.frame(var = extTime_pdp_var_imp2$var,
                      z = c(30, 150, 6, 4, 0.95, 0.75, 0.5, 0.2, 1, 0.4, 0.85, 0.3))


# plot
ggplot(extTime_pdp_plots_clean2, aes(x, y)) +
  geom_line() +
  geom_smooth() +
  geom_text(
    data = extTime_pdp_var_imp2,
    mapping = aes(x = -Inf, y = -Inf, label = round(Overall)),
    hjust = -0.5,
    vjust = -18) +
  facet_rep_wrap(~var, scales = "free_x", strip.position = "bottom", nrow = 2) +
  geom_vline(data = df_line, aes(xintercept = z), linetype = 2, colour = "red") +
  labs(x = "",
       y = "Time to Extinction") +
  theme_classic() +
  theme(strip.background = element_blank(),
        strip.placement = "outside")

#Saving
ggsave("./graphs/gsa_extinction_time_plot.png",
       width = 15.2, height = 8.14)

## Population Size (50 y Average) ---------------------------------------------------------

#calculating the number of birds for the run where there was no extinction for the last 50 years
gsa_50y_ps_df <- gsa_df %>% 
  filter(ticks > 451) %>% 
  group_by(run_id, island_id) %>% 
  summarise(adult_mean = mean(adult_count),
            .groups = "keep") %>% 
  ungroup() %>% 
  left_join(gsa_meta_df, by = c("run_id" = "nlrx_id")) %>% 
  select(adult_mean, island_id, str_replace_all(names(gsa_ls), "-", "_"))


#Setting up the tuning parameter controls
gsa_ps_tc <- trainControl(method = "cv",
                          number = 5,
                          search = "grid",
                          returnResamp = "all")

gsa_50y_ps_1_df <- gsa_50y_ps_df %>% 
  filter(island_id == "settled_ct_isl_1") %>% 
  select(-island_id)


tic("pop size gbm - 1")
pop_size_1_gbm <- train(adult_mean ~ .,
                        method = "gbm",
                        tuneLength = 12,
                        trControl = gsa_et_tc,
                        data = gsa_50y_ps_1_df)

toc()

varImp(pop_size_1_gbm)

# Creating partial dependence curves for the pop size classes
popsize_pdp_plots <- vector(mode = "list", length = length(pop_size_1_gbm$coefnames))

for (i in seq_along(pop_size_1_gbm$coefnames)) {
  
  print(i)
  
  df_i <- pop_size_1_gbm %>%
    pdp::partial(pred.var = pop_size_1_gbm$coefnames[i],
                 plot.engine = "ggplot2",
                 plot = FALSE,
                 type = "regression")
  
  # tidy
  df_i <- data.frame(var = pop_size_1_gbm$coefnames[i], df_i)
  colnames(df_i) <- c("var", "x", "y")
  popsize_pdp_plots[[i]] <- df_i
  
}

# clean up output
popsize_pdp_plots_clean <- bind_rows(popsize_pdp_plots)

popsize_pdp_var_imp <- varImp(pop_size_1_gbm)[[1]] %>% 
  arrange(desc(Overall))
popsize_pdp_var_imp$var <- row.names(popsize_pdp_var_imp)

#rename model params for plotting
popsize_pdp_plots_clean <- popsize_pdp_plots_clean %>%
  mutate(var = recode(var,
                      "chick_predation" = "Chick Predation(mean)",
                      "clust_area" = "Island Radius",
                      "collapse_half_way" = "Collapse 50% Threshold",
                      "emig_out_prob" = "Emigrate out of System (%)",
                      "emigration_timer" =  "Successive Failed Breeding Tries" ,
                      "female_philopatry" = "Female Philopatry",
                      "habitat_aggregation" = "Habitat Aggregation",
                      "max_age" = "Senior Mortality Age",
                      "max_tries" = "Maximum Courting Attempts",
                      "natural_chick_mortality" = "Natural Chick Mortality",
                      "prop_returning_breeders" = "Proportion of Breeders Returning",
                      "prop_suitable" = "Proportion of Suitable Habitat",
                      "sex_ratio" = "Sex Ratio"))


popsize_pdp_var_imp <- popsize_pdp_var_imp %>%
  mutate(var = recode(var,
                      "chick_predation" = "Chick Predation(mean)",
                      "clust_area" = "Island Radius",
                      "collapse_half_way" = "Collapse 50% Threshold",
                      "emig_out_prob" = "Emigrate out of System (%)",
                      "emigration_timer" =  "Successive Failed Breeding Tries" ,
                      "female_philopatry" = "Female Philopatry",
                      "habitat_aggregation" = "Habitat Aggregation",
                      "max_age" = "Senior Mortality Age",
                      "max_tries" = "Maximum Courting Attempts",
                      "natural_chick_mortality" = "Natural Chick Mortality",
                      "prop_returning_breeders" = "Proportion of Breeders Returning",
                      "prop_suitable" = "Proportion of Suitable Habitat",
                      "sex_ratio" = "Sex Ratio"))


# fix var order for plotting
popsize_pdp_plots_clean$var <-  factor(popsize_pdp_plots_clean$var,
                                        levels = popsize_pdp_var_imp$var)

popsize_pdp_var_imp$var <- as.factor(popsize_pdp_var_imp$var)

popsize_pdp_var_imp2 <- popsize_pdp_var_imp %>%
  filter(Overall >= 10)

popsize_pdp_plots_clean2 <- popsize_pdp_plots_clean %>%
  filter(var %in% popsize_pdp_var_imp2$var)


# add vertical line for default model setting
df_line <- data.frame(var = popsize_pdp_var_imp2$var,
                      z = c(150, 10, 0.5, 0.4, 0.75, 4, 30, 1))


#THIS PLOT IS BROKEN - RESULTS NEED TO BE BACK-TRANSFORMED?
# plot
ggplot(popsize_pdp_plots_clean2, aes(x, y)) +
  geom_line() +
  geom_smooth() +
  geom_text(
    data = popsize_pdp_var_imp2,
    mapping = aes(x = -Inf, y = -Inf, label = round(Overall)),
    hjust = -0.5,
    vjust = -18) +
  facet_rep_wrap(~var, scales = "free_x", strip.position = "bottom", nrow = 2) +
  geom_vline(data = df_line, aes(xintercept = z), linetype = 2, colour = "red") +
  labs(x = "",
       y = "Population size") +
  theme_classic() +
  theme(strip.background = element_blank(),
        strip.placement = "outside")

ggsave("./graphs/global_sensitivity_analysis/pop_size_isl_1_gsa.png", width = 9, height = 4)

#Island 2 model
gsa_50y_ps_2_df <- gsa_50y_ps_df %>% 
  filter(island_id == "settled_ct_isl_2") %>% 
  select(-island_id)

tic("pop size gbm- 2")
pop_size_2_gbm <- train(adult_mean ~ .,
                        method = "gbm",
                        tuneLength = 12,
                        trControl = gsa_et_tc,
                        data = gsa_50y_ps_2_df) 
toc()
varImp(pop_size_2_gbm)






# Creating partial dependence curves for the pop size classes
popsize_pdp_plots <- vector(mode = "list", length = length(pop_size_2_gbm$coefnames))

for (i in seq_along(pop_size_2_gbm$coefnames)) {
  
  print(i)
  
  df_i <- pop_size_2_gbm %>%
    pdp::partial(pred.var = pop_size_2_gbm$coefnames[i],
                 plot.engine = "ggplot2",
                 plot = FALSE,
                 type = "regression")
  
  # tidy
  df_i <- data.frame(var = pop_size_2_gbm$coefnames[i], df_i)
  colnames(df_i) <- c("var", "x", "y")
  popsize_pdp_plots[[i]] <- df_i
  
}

# clean up output
popsize_pdp_plots_clean <- bind_rows(popsize_pdp_plots)

popsize_pdp_var_imp <- varImp(pop_size_2_gbm)[[1]] %>% 
  arrange(desc(Overall))
popsize_pdp_var_imp$var <- row.names(popsize_pdp_var_imp)

#rename model params for plotting
popsize_pdp_plots_clean <- popsize_pdp_plots_clean %>%
  mutate(var = recode(var,
                      "chick_predation" = "Chick Predation(mean)",
                      "clust_area" = "Island Radius",
                      "collapse_half_way" = "Collapse 50% Threshold",
                      "emig_out_prob" = "Emigrate out of System (%)",
                      "emigration_timer" =  "Successive Failed Breeding Tries" ,
                      "female_philopatry" = "Female Philopatry",
                      "habitat_aggregation" = "Habitat Aggregation",
                      "max_age" = "Senior Mortality Age",
                      "max_tries" = "Maximum Courting Attempts",
                      "natural_chick_mortality" = "Natural Chick Mortality",
                      "prop_returning_breeders" = "Proportion of Breeders Returning",
                      "prop_suitable" = "Proportion of Suitable Habitat",
                      "sex_ratio" = "Sex Ratio"))


popsize_pdp_var_imp <- popsize_pdp_var_imp %>%
  mutate(var = recode(var,
                      "chick_predation" = "Chick Predation(mean)",
                      "clust_area" = "Island Radius",
                      "collapse_half_way" = "Collapse 50% Threshold",
                      "emig_out_prob" = "Emigrate out of System (%)",
                      "emigration_timer" =  "Successive Failed Breeding Tries" ,
                      "female_philopatry" = "Female Philopatry",
                      "habitat_aggregation" = "Habitat Aggregation",
                      "max_age" = "Senior Mortality Age",
                      "max_tries" = "Maximum Courting Attempts",
                      "natural_chick_mortality" = "Natural Chick Mortality",
                      "prop_returning_breeders" = "Proportion of Breeders Returning",
                      "prop_suitable" = "Proportion of Suitable Habitat",
                      "sex_ratio" = "Sex Ratio"))


# fix var order for plotting
popsize_pdp_plots_clean$var <-  factor(popsize_pdp_plots_clean$var,
                                       levels = popsize_pdp_var_imp$var)

popsize_pdp_var_imp$var <- as.factor(popsize_pdp_var_imp$var)

popsize_pdp_var_imp2 <- popsize_pdp_var_imp %>%
  filter(Overall >= 10)

popsize_pdp_plots_clean2 <- popsize_pdp_plots_clean %>%
  filter(var %in% popsize_pdp_var_imp2$var)


# add vertical line for default model setting
df_line <- data.frame(var = popsize_pdp_var_imp2$var,
                      z = c(150, 10, 4, 0.4, 6, 0.85))


#THIS PLOT IS BROKEN - RESULTS NEED TO BE BACK-TRANSFORMED?
# plot
ggplot(popsize_pdp_plots_clean2, aes(x, y)) +
  geom_line() +
  geom_smooth() +
  geom_text(
    data = popsize_pdp_var_imp2,
    mapping = aes(x = -Inf, y = -Inf, label = round(Overall)),
    hjust = -0.5,
    vjust = -18) +
  facet_rep_wrap(~var, scales = "free_x", strip.position = "bottom", nrow = 2) +
  geom_vline(data = df_line, aes(xintercept = z), linetype = 2, colour = "red") +
  labs(x = "",
       y = "Population size") +
  theme_classic() +
  theme(strip.background = element_blank(),
        strip.placement = "outside")

ggsave("./graphs/global_sensitivity_analysis/pop_size_isl_2_gsa.png", width = 9, height = 4)


## Population State -----------------------------------------------

#Data prep
#Dataframe for island 1
gsa_state_1_df <- gsa_df %>% 
  filter(island_id == "settled_ct_isl_1") %>% 
  group_by(run_id) %>% 
  slice_tail() %>% 
  ungroup() %>% 
  mutate(pop_state = case_when(
    adult_count == 0 ~ "Extinct",
    adult_count > 0 & adult_count <= 50 ~ "Pseudo-Extinct",
    adult_count > 50 & adult_count <= 500 ~ "Threatened",
    adult_count > 500 ~ "Stable")) %>% 
  select(pop_state, str_replace_all(names(gsa_ls), "-", "_"))

# #Dataframe for island 1
# gsa_state_2_df <- gsa_df %>% 
#   filter(island_id == "settled_ct_isl_2") %>% 
#   group_by(run_id) %>% 
#   slice_tail() %>% 
#   ungroup() %>% 
#   mutate(pop_state = case_when(
#     adult_count == 0 ~ "Extinct",
#     adult_count > 0 & adult_count <= 50 ~ "Pseudo-Extinct",
#     adult_count > 50 & adult_count <= 500 ~ "Threatened",
#     adult_count > 500 ~ "Stable")) %>% 
#   select(pop_state, str_replace_all(names(gsa_ls), "-", "_"))
# 
# 
# #Fitting random forest
# tic("state rf")
# pop_state_1_rf <- train(pop_state ~ .,
#                        method = "rf",
#                        tuneLength = 12,
#                        trControl = gsa_et_tc,
#                        data = gsa_state_1_df)
# toc()
# #state rf: 225 sec elapsed
# 
# 
# tic("state rf")
# pop_state_2_rf <- train(pop_state ~ .,
#                         method = "rf",
#                         tuneLength = 12,
#                         trControl = gsa_et_tc,
#                         data = gsa_state_2_df)
# 
# toc()
# 
# # #GBM
# # tic("state gbml")
# # pop_state_1_gbml <- train(pop_state ~ .,
# #                           method = "xgbLinear",
# #                           tuneLength = 12,
# #                           trControl = gsa_et_tc,
# #                           data = gsa_state_1_df)
# # toc()
# # 
# # tic("state gbml")
# # pop_state_2_gbml <- train(pop_state ~ .,
# #                           method = "xgbLinear",
# #                           tuneLength = 12,
# #                           trControl = gsa_et_tc,
# #                           data = gsa_state_2_df)
# # toc()
# 
# # 
# # varImp(pop_state_1_gbml)
# # 
# # varImp(pop_state_2_gbml)
# 
# #Variable importance
# varImp(pop_state_1_rf)
# varImp(pop_state_2_rf)
# 
# 
# # Creating partial dependence curves for the pop size classes
# popState_pdp_plots <- vector(mode = "list", length = length(pop_state_1_rf$coefnames))
# 
# for (i in seq_along(pop_state_1_rf$coefnames)) {
#   
#   print(i)
#   
#   df_i <- pop_state_1_rf %>%
#     pdp::partial(pred.var = pop_state_1_rf$coefnames[i],
#                  plot.engine = "ggplot2",
#                  plot = FALSE,
#                  type = "classification")
#   
#   # tidy
#   df_i <- data.frame(var = pop_state_1_rf$coefnames[i], df_i)
#   colnames(df_i) <- c("var", "x", "y")
#   popState_pdp_plots[[i]] <- df_i
#   
# }
# 
# # clean up output
# popState_pdp_plots_clean <- bind_rows(popState_pdp_plots)
# 
# popState_pdp_var_imp <- varImp(pop_state_1_rf)[[1]] %>% 
#   arrange(desc(Overall))
# popState_pdp_var_imp$var <- row.names(popState_pdp_var_imp)
# 
# #rename model params for plotting
# popState_pdp_plots_clean <- popState_pdp_plots_clean %>%
#   mutate(var = recode(var,
#                       "chick_predation" = "Chick Predation(mean)",
#                       "clust_area" = "Island Radius",
#                       "collapse_half_way" = "Collapse 50% Threshold",
#                       "emig_out_prob" = "Emigrate out of System (%)",
#                       "emigration_timer" =  "Successive Failed Breeding Tries" ,
#                       "female_philopatry" = "Female Philopatry",
#                       "habitat_aggregation" = "Habitat Aggregation",
#                       "max_age" = "Senior Mortality Age",
#                       "max_tries" = "Maximum Courting Attempts",
#                       "natural_chick_mortality" = "Natural Chick Mortality",
#                       "prop_returning_breeders" = "Proportion of Breeders Returning",
#                       "prop_suitable" = "Proportion of Suitable Habitat",
#                       "sex_ratio" = "Sex Ratio"))
# 
# 
# popState_pdp_var_imp <- popState_pdp_var_imp %>%
#   mutate(var = recode(var,
#                       "chick_predation" = "Chick Predation(mean)",
#                       "clust_area" = "Island Radius",
#                       "collapse_half_way" = "Collapse 50% Threshold",
#                       "emig_out_prob" = "Emigrate out of System (%)",
#                       "emigration_timer" =  "Successive Failed Breeding Tries" ,
#                       "female_philopatry" = "Female Philopatry",
#                       "habitat_aggregation" = "Habitat Aggregation",
#                       "max_age" = "Senior Mortality Age",
#                       "max_tries" = "Maximum Courting Attempts",
#                       "natural_chick_mortality" = "Natural Chick Mortality",
#                       "prop_returning_breeders" = "Proportion of Breeders Returning",
#                       "prop_suitable" = "Proportion of Suitable Habitat",
#                       "sex_ratio" = "Sex Ratio"))
# 
# 
# # fix var order for plotting
# popState_pdp_plots_clean$var <-  factor(popState_pdp_plots_clean$var,
#                                         levels = popState_pdp_var_imp$var)
# 
# popState_pdp_var_imp$var <- as.factor(popState_pdp_var_imp$var)
# 
# popState_pdp_var_imp2 <- popState_pdp_var_imp %>%
#   filter(Overall >= 10)
# 
# popState_pdp_plots_clean2 <- popState_pdp_plots_clean %>%
#   filter(var %in% popState_pdp_var_imp2$var)
# 
# 
# # add vertical line for default model setting
# df_line <- data.frame(var = popState_pdp_var_imp2$var,
#                       z = c(0.4, 30, 0.75, 0.4, 4, 1, 0.85, 150))
# 
# 
# #THIS PLOT IS BROKEN - RESULTS NEED TO BE BACK-TRANSFORMED?
# # plot
# ggplot(popState_pdp_plots_clean2, aes(x, y)) +
#   geom_line() +
#   geom_smooth() +
#   geom_text(
#     data = popState_pdp_var_imp2,
#     mapping = aes(x = -Inf, y = -Inf, label = round(Overall)),
#     hjust = -0.5,
#     vjust = -18) +
#   facet_rep_wrap(~var, scales = "free_x", strip.position = "bottom", nrow = 2) +
#   geom_vline(data = df_line, aes(xintercept = z), linetype = 2, colour = "red") +
#   labs(x = "",
#        y = "Population State") +
#   theme_classic() +
#   theme(strip.background = element_blank(),
#         strip.placement = "outside")


