#Checking my ENSO cycle looks correct

library(dplyr)
library(ggplot2)


# Reading in data ---------------------------------------------------------

enso_check <- read.csv("../output/test.csv") %>% 
  mutate(tick = 1:nrow(.)) %>% 
  select(c(enso_state, tick))

ggplot(enso_check, aes(y = enso_state, x = tick)) + 
  geom_line() + 
  xlim(0, 100) +
  geom_point(aes(colour = enso_state)) +
  labs(y = "ENSO state",
       x = "Tick") +
  guides(colour = guide_legend("ENSO State")) +
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
