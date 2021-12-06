#Code for calculate an ENSO transition matrix (data from: https://data.mfe.govt.nz/table/52589-el-nino-southern-oscillation-index-19092013/)


# Libraries ---------------------------------------------------------------
library(dplyr) #Data manipulation
#library(lubridate)
library(ggplot2)
library(markovchain) #Creating sequence matrix
library(matrixStats) #Stats summaries on sequence matrix


# Analysis ---------------------------------------------------------

#Reading in detrended data
soi_df <- read.csv("./data/state_SOI_detrended.csv") %>% 
  mutate(enso_state = ifelse(soi_index > 0.5, 
                             "La Nina", 
                             ifelse(soi_index < -0.5, 
                                    "El Nino", "Neutral")),
         enso_state = factor(enso_state, 
                             levels = c("La Nina", 
                                        "Neutral",
                                        "El Nino"))) %>% 
  select(c(soi_year, soi_index, enso_state))

#Trying with added intermediate categories, as per the NIWA website
soi_df <- read.csv("./data/state_SOI_detrended.csv") %>% 
  mutate(enso_state = case_when(soi_index > 1 ~ "La Niña",
                                soi_index < 1 & soi_index > 0.5 ~ "La Niña Leaning",
                                soi_index <= 0.5 & soi_index >= -0.5 ~ "Neutral",
                                soi_index < -0.5 & soi_index > -1 ~ "El Niño Leaning",
                                soi_index < -1 ~ "El Niño"),
         enso_state = factor(enso_state, 
                             levels = c("La Niña", 
                                        "La Niña Leaning",
                                        "Neutral",
                                        "El Niño Leaning",
                                        "El Niño"))) %>% 
  select(c(soi_year, soi_index, enso_state))
#Using SOI year and index as this is probably the simplest and most tractable estimate of SOI

#Plot to check the data
ggplot(soi_df, aes(x = soi_year, y = soi_index)) +
  geom_line() +
  geom_point(aes(colour = enso_state)) + 
  scale_colour_viridis_d(direction = -1) + 
  labs(y = "Mean Southern Oscillation Index (Yearly)",
       x = "Year") +
  guides(colour = guide_legend("ENSO State")) +
  theme_bw()

ggsave("./graphs/enso_states.png",
       width = 8.5, height = 4.5)

#Calculating transition probabilities
#Renaming for easy of typing
soi_df <- soi_df %>% 
  mutate(enso_state = recode(enso_state,
                                    `La Niña` = "LN",           
                                    `La Niña Leaning` = "LNL",
                                    `Neutral` = "N",
                                    `El Niño Leaning` = "ENL",
                                    `El Niño` = "EN"))

#Fitting transition matrix
enso_markov <- markovchainFit(data = soi_df$enso_state)

#Pulling out the transition matrix and reordering the rows to match the coding above
transMat_df <- as.data.frame(enso_markov$estimate@transitionMatrix)[c(3,4,5,2,1), c(3,4,5,2,1)]

#Rounding to percentages/integers as NL's multinomial draw prefers this
transMat_df <- round(transMat_df *100, digits = 0)

#Saving data to the seabirdExtripation directory in data folder for netlogo access
write.csv(transMat_df, 
          row.names = FALSE,
          #Losing RN for NetLogo...
          "../data/enso/transition_matrix.csv")

#Extra code for checking results... 
#Creating a sequence matrix
enso_matrix <- createSequenceMatrix(soi_df$enso_state)

enso_matrix

