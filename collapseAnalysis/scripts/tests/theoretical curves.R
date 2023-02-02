library(dplyr)
library(ggplot2)
library(tidyr)
# 
# to-report random-sigmoid [ x c1 c2 ]
# report 1 / (1 + (exp((-1 * c1) * (x - c2))))
# end

#The function to return a value from a sigmoid distribution
dsigmoid <- function(n, curve = 15, halfway = 0.5){
  1 / (1 + exp( (-1 * curve) * (n - halfway)))
}

theoreticalCurves <- data.frame(n = seq(0.01, 1, by = 0.01)) %>%
  mutate(Uniform = 0.5,#1/nrow(.), - cdf, so consistent very low prob.
         Linear = n/max(n),
         Beta1 = scales::rescale(dbeta(n, shape1 = 5, shape2 = 5)),
         Beta2 = scales::rescale(dbeta(n, shape1 = 5, shape2 = 2)),
         Sigmoid = dsigmoid(n, curve = 15, halfway = 0.5),
         Asymptotic = 1 * (1 - exp(-1 * 8 * n))) %>%
  #mutate(Beta1 = beta / sum(beta)) %>%
  pivot_longer(cols = c(Uniform, Linear, Beta1, Beta2,
                        Sigmoid, Asymptotic), 
               values_to = "Probability", 
               names_to = "Distribution") %>%
  mutate(Distribution = factor(Distribution, levels = c("Uniform", "Linear", "Asymptotic", "Sigmoid", "Beta1", "Beta2")))


library(colorspace)
hcl_palettes(type = "qualitative", palette = "Dark 3", n = 6L)
qualitative_hcl(6, palette = "dark3")             ## by name


#Colour palette (pastel)
pasPal <- qualitative_hcl(6, palette = "dark2")


ggplot(theoreticalCurves,
       aes(y = Probability * 100, x = n * 100,
           colour = Distribution)) +
  geom_line(size = 1.25)+
  scale_colour_manual(values = pasPal, guide = "none") +
  #scale_colour_colorblind() +
  xlab("Islands Share of Seabirds (%)") +
  ylab("Probability of Settling (%)") +
  facet_wrap(~Distribution) +
  theme_minimal() +
  theme(axis.title = element_text(size = 16),
        axis.text =  element_text(size = 14),
        strip.text = element_text(size = 14))

ggsave("./graphs/supporting_material/theoretical_curves.png",
       width = 12, height = 7.25)





