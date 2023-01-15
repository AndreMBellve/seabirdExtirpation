extensions
[
  csv ;;loading in data for setup and exporting data from runs
  rnd ;;distribution functions
  profiler ;;profiling to detect bottlenecks
  stats ;;beta distribution pdf
  ;;string ;;String functions
  ;rnetlogo
]

__includes
[
  "./helpers/distributions.nls"
  "./coreScripts/initialisation_rako.nls"
  "./coreScripts/withinSeason_rako.nls"
  "./coreScripts/plotter_gsa.nls"
]

globals
[
  ;;Patch-sets
  num-islands ;;A single element list with the number of islands
  the-islands ;;Patch-set of all the island patches
  the-sea ;;Patch-set of the sea patches
  the-shore ;; Island patches that border the sea (currrently unused)

  island-id ;;List of ID's for the islands (1 - n; where n is the number of islands); sea is 0.
  colonies ;;list of patchsets for each island

  pred-islands
  safe-islands

  ;;Agent-sets
  prospective-males ;;list of colony patch-sets that contain the patches with male-count > 0
  breeders ;;turtle-set of all adult birds
  recruits
  new-recruits
  returning-breeders ;; The birds coming back to breed this year....

  ;;Island meta details
  isl-occ ;;the number of breeding bird on each island
  world-occ ;;the number of breeding birds in the world (adult breeders only)
  island-attractiveness ;;weighting for philopatry

  ;;Helpful counts
  adult-pop ;;the total number of adults
  juv-pop ;;the total number ofjuveniles
  pop-size ;;Total population

  philopatry-out ;;Count of birds who failed a philopatry test each year leaving the system
  philo-emigrators ;;Turtle-set of birds that have chosen to emigrate to a new isl or out of system
  emig-out ;;Count of birds leaving due to inability to breed...

  ;;ENSO parameters
  enso-table ;;The table that gets read in with it's headers
  enso-matrix ;;Transition matrix to code for the probability of changing from one state to another
  enso-state ;;The current ENSO state of the system - currently five states

  ;;Census information
  ;;Master list
  island-series

  ;;Sub-lists to be filled each year and bound to master list
  juv-live-isl-counts
  juv-dead-isl-counts
  new-adult-isl-counts
  philo-suc-counts
  philo-fail-counts ;;One longer than # of isls
  emig-att ;;One longer than # of isls
  emig-source-counts ;; The number of birds in the emigration pool from each island
  emig-counts ;;One longer than # of isls
  male-counts
  adult-isl-counts
  breeder-isl-counts
  fledged-isl-counts
  chick-isl-pred
  adult-mort-isl-counts
  adult-isl-pred
  attrition-counts
  prospect-counts
  collapse-counts
  burrow-counts
  isl-attractiveness ;;One longer than # of isls

  lost-males ;;counter for how many unallocated males there are

  ;;Reporter for graphs only
  mating-isl-props

  demography-series
  demography-year
  island-year

  old-pairs
  new-pairs

  ;;Plotting globals
  isl-adult-pen-names
  isl-breed-pen-names
  isl-mating-pen-names
  isl-fledge-pen-names
  isl-burrow-pen-names

  ;;Distribution parameters
  asymp-curve
]

patches-own
[

  ;;SETUP
  ;;initialisation globals for set up
  colony-id
  ;;chick-predation
  ;;prop-suitable
  low-lambda
  high-lambda
  ;;habitat-aggregation
  starting-juveniles
  starting-seabird-pop

  habitable? ;;whether this is a habitable patch (T/F)
  suitable? ;;classifier for whether the patches are particularly suitable for burrows


  ;;Variables that fluctuate during model run
  habitat-attrac ;;the attractiveness of the patch
  occupancy ;;the number of birds in this patch
  occupancy-limit ;;the maximum number of birds the patch can have
  male-count ;;number of males in burrows
  neighbourhood ;;agentset of all patches
  maxK

  predators? ;;whether there are predators in this patch

;  low-k             ;; capacity and
;  low-value-resource  ;; current level of low value resource

;  mh-d
;  on-island?
;  edge-shell        ;; used by irregular island code
]

turtles-own
[

  breeding-grounds ;;patchset of breeding grounds
  breeding-ground-id ;;The location of their breeding ground
  natal-ground-id ;;What island they were born on
  burrow ;;a single patch that this bird last bred at - surrogate for mate with no males present.

  settled? ;;Whether or not this bird has chosen a breeding ground. Happens once birds recruit and is constant unless an individual has x unsuccessful breeding seasons
  breeding? ;;Whether or not it has found a patch within the colony (reset yearly)
  mating? ;;Whether or not a bird has successfully established a burrow with a 'male' this season
  return? ;; Logical indicating which birds are returning and which are not - refreshes every season

  age ;;numeric counting the age of individuals
  life-stage ;;Juvenile/Adults
  time-since-breed ;;counter for how long it has been since the bird has bred.
  emigration-attempts ;;How many times they have swapped islands

  last-breeding-success? ;;T/F indicating whether their last breeding attempt was successful or unsuccessful



]

breed ; convience name
[
  females female ;female birds
]


to setup

  clear-all
  reset-ticks

  ;;Checking if it is a nlrx run or not as the seed will be set by nlrx if it is
  if not nlrx?
   [

  ;;Setting seed specified by user...
  ifelse is-number? seed-id
    [
      random-seed seed-id
    ]
    ;;or use a random one if undefined...
    [
      set seed-id new-seed
      random-seed seed-id
    ]

  ]
  ;;Default values for patches
  init-patches

  ;;Reading in the data for the islands and creating them
  init-isl-from-file

  ;;Set up for seabirds
  init-adults
  assign-burrows
  init-juveniles

  ;;Climate variation in mortality and breeding success
  if enso?
  [
    init-enso
  ]

  ;;Custom plot setups
  init-by-isl-plots

  ;;Initialising column headers for data extraction
  ;if capture-data?
  ;[
   init-census-data
  ;]


  set pop-size []

end

to go

  while [ count turtles > 0 ]
  [
    step
  ]
end

to step

  if profiler? [ profiler:start ]

  if print-stage? [ show "Recruitment" ]
  recruit ;;adding new individuals
  ;; set deomg-yr lput x demog-yr

  if print-stage? [ show "Philopatry check" ]
  philopatry-check ;;checking if new recruits are natal ground bound

  if print-stage? [ show "Emigration" ]
  emigrate ;;potentially abandoning patches

 if print-stage? [  show "Burrowing" ]
  burrowing ;;males spread across patches (multi-nomial draw)

  if print-stage? [ show "Mating" ]
  find-mate ;;females find a 'male' and settle down in a patch

  if print-stage? [ show "Hatching-Fledging" ]
  hatching-fledging ;;this stage includes chick mortality - To do: create data output list for each island

  if print-stage? [ show "Adult Death" ]
  mortality ;;Killing off some proportion of the adults

  if print-stage? [ show "New Year" ]
  season-reset

  tick

  if profiler?
  [
    profiler:stop          ;; stop profiling
    print profiler:report  ;; view the results
    profiler:reset         ;; clear the data
  ]
end


to-report patch-occ
  report [ occupancy ] of patch-here / [ maxK ] of patch-here
end

to-report hab-quality
  report [ occupancy-limit ] of patch-here / [ maxK ] of patch-here
end

to-report local-occ
  report (mean[ occupancy ] of neighbourhood) / [ maxK ] of patch-here
end
@#$#@#$#@
GRAPHICS-WINDOW
665
15
1178
529
-1
-1
5.0
1
10
1
1
1
0
0
0
1
0
100
0
100
1
1
1
ticks
30.0

BUTTON
275
25
339
58
Setup
setup
NIL
1
T
OBSERVER
NIL
NIL
NIL
NIL
1

BUTTON
355
25
418
58
Go
go
NIL
1
T
OBSERVER
NIL
NIL
NIL
NIL
1

SLIDER
20
290
192
323
female-philopatry
female-philopatry
0
1
0.95
0.01
1
NIL
HORIZONTAL

TEXTBOX
20
405
195
461
1 represents a even sex ration. Higher values give more males\n\n
11
0.0
1

SLIDER
245
320
420
353
adult-mortality
adult-mortality
0
1
0.05
0.01
1
NIL
HORIZONTAL

SLIDER
245
160
420
193
juvenile-mortality
juvenile-mortality
0
1
0.65
0.01
1
NIL
HORIZONTAL

SLIDER
245
240
420
273
natural-chick-mortality
natural-chick-mortality
0
1
0.37
0.01
1
NIL
HORIZONTAL

SLIDER
20
250
192
283
age-at-first-breeding
age-at-first-breeding
0
12
6.0
1
1
NIL
HORIZONTAL

SLIDER
20
210
192
243
age-first-return
age-first-return
0
10
5.0
1
1
NIL
HORIZONTAL

SLIDER
20
730
192
763
max-tries
max-tries
1
10
6.0
1
1
NIL
HORIZONTAL

PLOT
1460
200
1895
370
Proportion Mating
Ticks
Proportion
0.0
1.0
0.0
1.0
true
true
"" "isl-mating-plot"
PENS

MONITOR
1185
70
1282
115
Mating Females
count breeders with [ mating? ]
0
1
11

SWITCH
980
568
1082
601
debug?
debug?
1
1
-1000

SLIDER
20
690
192
723
nhb-rad
nhb-rad
1
5
4.0
1
1
NIL
HORIZONTAL

SLIDER
245
400
420
433
max-age
max-age
0
100
30.0
1
1
NIL
HORIZONTAL

PLOT
1185
120
1450
260
Age histogram
Age
Frequency
6.0
40.0
0.0
10.0
true
false
"" ""
PENS
"default" 1.0 1 -16777216 true "" "histogram [age] of turtles"

SLIDER
245
440
420
473
old-mortality
old-mortality
0
1
0.8
0.01
1
NIL
HORIZONTAL

SLIDER
20
330
190
363
prop-returning-breeders
prop-returning-breeders
0
1
0.85
0.01
1
NIL
HORIZONTAL

SLIDER
245
280
417
313
chick-mortality-sd
chick-mortality-sd
0
2
0.1
0.01
1
NIL
HORIZONTAL

SWITCH
980
608
1082
641
verbose?
verbose?
1
1
-1000

BUTTON
435
25
490
58
Step
step
NIL
1
T
OBSERVER
NIL
NIL
NIL
NIL
1

MONITOR
1185
20
1282
65
# Adults
count turtles with [ life-stage = \"Adult\" ]
0
1
11

SLIDER
20
590
192
623
emigration-timer
emigration-timer
1
10
4.0
1
1
NIL
HORIZONTAL

SWITCH
1095
568
1198
601
profiler?
profiler?
1
1
-1000

SWITCH
515
25
635
58
capture-data?
capture-data?
0
1
-1000

SWITCH
1095
608
1220
641
update-colour?
update-colour?
1
1
-1000

SLIDER
20
470
192
503
raft-half-way
raft-half-way
0
500
250.0
5
1
NIL
HORIZONTAL

SWITCH
245
675
345
708
collapse?
collapse?
0
1
-1000

SLIDER
20
510
192
543
emigration-curve
emigration-curve
0
2
0.5
0.25
1
NIL
HORIZONTAL

SWITCH
245
595
345
628
prospect?
prospect?
0
1
-1000

BUTTON
275
70
355
103
NIL
set-defaults
NIL
1
T
OBSERVER
NIL
NIL
NIL
NIL
1

CHOOSER
15
140
153
185
isl-att-curve
isl-att-curve
"uniform" "linear" "asymptotic" "sigmoid" "beta1" "beta2"
5

SLIDER
20
550
192
583
emig-out-prob
emig-out-prob
0
1
0.75
0.05
1
NIL
HORIZONTAL

INPUTBOX
15
30
255
95
initialisation-data
./data/extirpation_simulation/extir_two_isl_baseline.csv
1
0
String

SLIDER
15
100
187
133
diffusion-prop
diffusion-prop
0
1
0.4
0.01
1
NIL
HORIZONTAL

SLIDER
20
370
192
403
sex-ratio
sex-ratio
0
2
1.0
0.1
1
NIL
HORIZONTAL

PLOT
1461
8
1896
193
Island Adult Counts
Ticks
Number of Seabirds
0.0
10.0
0.0
10.0
true
true
"" "isl-adult-plot"
PENS

MONITOR
1295
20
1372
65
# Juveniles
count turtles with [ life-stage = \"Juvenile\" ]
17
1
11

SLIDER
20
630
190
663
emigration-max-attempts
emigration-max-attempts
1
5
2.0
1
1
NIL
HORIZONTAL

PLOT
1461
553
1896
728
Chicks Fledged
NIL
NIL
0.0
10.0
0.0
10.0
true
true
"" "isl-fledge-plot"
PENS

MONITOR
1295
70
1452
115
Emigrants Leaving System
emig-out
17
1
11

PLOT
1461
378
1896
543
Island Breeding Attempts
Number of Breeders Attempting
NIL
0.0
10.0
0.0
10.0
true
true
"" "isl-breed-plot"
PENS

INPUTBOX
750
538
967
598
output-file-name
./output/test.csv
1
0
String

BUTTON
660
538
737
571
Save file
csv:to-file output-file-name island-series
NIL
1
T
OBSERVER
NIL
NIL
NIL
NIL
1

TEXTBOX
980
548
1080
574
Systems checks
12
0.0
1

TEXTBOX
15
10
165
28
System Creation\n
12
0.0
1

TEXTBOX
20
195
170
213
Seabird Recruitment\n
12
0.0
1

TEXTBOX
245
140
395
158
Natural Mortality
12
0.0
1

TEXTBOX
20
450
165
468
Emigration
12
0.0
1

TEXTBOX
20
670
170
688
Mate Finding\n
12
0.0
1

SLIDER
245
360
417
393
adult-mortality-sd
adult-mortality-sd
0
1
0.01
0.01
1
NIL
HORIZONTAL

SLIDER
245
200
417
233
juvenile-mortality-sd
juvenile-mortality-sd
0
1
0.1
0.01
1
NIL
HORIZONTAL

INPUTBOX
885
703
1102
763
behav-output-path
./output/
1
0
String

SWITCH
435
155
538
188
enso?
enso?
0
1
-1000

INPUTBOX
435
195
610
255
enso-breed-impact
[0.5 0.2 0 0.2 0.5]
1
0
String

TEXTBOX
545
155
660
185
Added ENSO mortality \n(LN LNL N ENL EN)
11
0.0
1

INPUTBOX
435
260
610
320
enso-adult-mort
[0.05 0.025 0 0.025 0.05]
1
0
String

PLOT
1185
265
1450
410
ENSO States
Ticks
ENSO State
0.0
10.0
0.0
4.0
true
false
"" ""
PENS
"default" 1.0 0 -12345184 true "" "plot enso-state"

INPUTBOX
765
703
870
763
nlrx-id
test
1
0
String

SWITCH
660
703
750
736
nlrx?
nlrx?
0
1
-1000

TEXTBOX
755
609
985
659
The save file button is for individual runs and will save all simulation information to the specified output-file-name\n
11
0.0
1

TEXTBOX
890
768
1115
809
The behav-output-path is only for use with behaviour space or nlrx\n
11
0.0
1

SWITCH
980
648
1105
681
print-stage?
print-stage?
1
1
-1000

INPUTBOX
515
65
635
125
seed-id
42.0
1
0
Number

SLIDER
355
595
530
628
patch-burrow-limit
patch-burrow-limit
10
300
100.0
5
1
NIL
HORIZONTAL

TEXTBOX
435
140
585
158
ENSO Mortality
12
0.0
1

TEXTBOX
245
495
395
513
Habitat
12
0.0
1

SLIDER
355
550
527
583
burrow-attrition-rate
burrow-attrition-rate
0
1
0.2
0.01
1
NIL
HORIZONTAL

SWITCH
245
515
345
548
attrition?
attrition?
0
1
-1000

SLIDER
355
630
530
663
time-to-prospect
time-to-prospect
1
10
2.0
1
1
NIL
HORIZONTAL

SLIDER
355
675
527
708
collapse-half-way
collapse-half-way
10
400
26.0
5
1
NIL
HORIZONTAL

SLIDER
355
710
527
743
collapse-perc
collapse-perc
0
1
0.25
0.01
1
NIL
HORIZONTAL

SLIDER
355
745
527
778
collapse-perc-sd
collapse-perc-sd
0
0.2
0.05
0.01
1
NIL
HORIZONTAL

PLOT
1185
415
1450
540
Burrow Counts
Ticks
# of Burrows
0.0
10.0
0.0
10.0
true
true
"" "isl-burrow-plot"
PENS

SLIDER
355
515
527
548
patch-burrow-minimum
patch-burrow-minimum
0
10
5.0
1
1
NIL
HORIZONTAL

SLIDER
1247
755
1420
788
chick-predation
chick-predation
0
1
0.4
0.01
1
NIL
HORIZONTAL

SLIDER
1244
625
1417
658
clust-area
clust-area
2
20
10.0
1
1
NIL
HORIZONTAL

SLIDER
1247
668
1420
701
habitat-aggregation
habitat-aggregation
0
1
0.2
0.01
1
NIL
HORIZONTAL

SLIDER
1247
712
1420
745
prop-suitable
prop-suitable
0
1
0.3
0.01
1
NIL
HORIZONTAL

TEXTBOX
1228
568
1443
614
TBD - these have been included for the GSA to allow for integration with the nlrx package
11
0.0
1

SLIDER
1535
775
1707
808
adult-predation
adult-predation
0
1
0.01
0.01
1
NIL
HORIZONTAL

@#$#@#$#@
## WHAT IS IT?

(a general understanding of what the model is trying to show or explain)

## HOW IT WORKS

(what rules the agents use to create the overall behavior of the model)

## HOW TO USE IT

(how to use the model, including a description of each of the items in the Interface tab)

## THINGS TO NOTICE

(suggested things for the user to notice while running the model)

## THINGS TO TRY

(suggested things for the user to try to do (move sliders, switches, etc.) with the model)

## EXTENDING THE MODEL

(suggested things to add or change in the Code tab to make the model more complicated, detailed, accurate, etc.)

## NETLOGO FEATURES

(interesting or unusual features of NetLogo that the model uses, particularly in the Code tab; or where workarounds were needed for missing features)

## RELATED MODELS

(models in the NetLogo Models Library and elsewhere which are of related interest)

## CREDITS AND REFERENCES

(a reference to the model's URL on the web if it has one, as well as any other necessary credits, citations, and links)
@#$#@#$#@
default
true
0
Polygon -7500403 true true 150 5 40 250 150 205 260 250

airplane
true
0
Polygon -7500403 true true 150 0 135 15 120 60 120 105 15 165 15 195 120 180 135 240 105 270 120 285 150 270 180 285 210 270 165 240 180 180 285 195 285 165 180 105 180 60 165 15

arrow
true
0
Polygon -7500403 true true 150 0 0 150 105 150 105 293 195 293 195 150 300 150

bird side
false
0
Polygon -7500403 true true 0 120 45 90 75 90 105 120 150 120 240 135 285 120 285 135 300 150 240 150 195 165 255 195 210 195 150 210 90 195 60 180 45 135
Circle -16777216 true false 38 98 14

box
false
0
Polygon -7500403 true true 150 285 285 225 285 75 150 135
Polygon -7500403 true true 150 135 15 75 150 15 285 75
Polygon -7500403 true true 15 75 15 225 150 285 150 135
Line -16777216 false 150 285 150 135
Line -16777216 false 150 135 15 75
Line -16777216 false 150 135 285 75

bug
true
0
Circle -7500403 true true 96 182 108
Circle -7500403 true true 110 127 80
Circle -7500403 true true 110 75 80
Line -7500403 true 150 100 80 30
Line -7500403 true 150 100 220 30

butterfly
true
0
Polygon -7500403 true true 150 165 209 199 225 225 225 255 195 270 165 255 150 240
Polygon -7500403 true true 150 165 89 198 75 225 75 255 105 270 135 255 150 240
Polygon -7500403 true true 139 148 100 105 55 90 25 90 10 105 10 135 25 180 40 195 85 194 139 163
Polygon -7500403 true true 162 150 200 105 245 90 275 90 290 105 290 135 275 180 260 195 215 195 162 165
Polygon -16777216 true false 150 255 135 225 120 150 135 120 150 105 165 120 180 150 165 225
Circle -16777216 true false 135 90 30
Line -16777216 false 150 105 195 60
Line -16777216 false 150 105 105 60

car
false
0
Polygon -7500403 true true 300 180 279 164 261 144 240 135 226 132 213 106 203 84 185 63 159 50 135 50 75 60 0 150 0 165 0 225 300 225 300 180
Circle -16777216 true false 180 180 90
Circle -16777216 true false 30 180 90
Polygon -16777216 true false 162 80 132 78 134 135 209 135 194 105 189 96 180 89
Circle -7500403 true true 47 195 58
Circle -7500403 true true 195 195 58

circle
false
0
Circle -7500403 true true 0 0 300

circle 2
false
0
Circle -7500403 true true 0 0 300
Circle -16777216 true false 30 30 240

cow
false
0
Polygon -7500403 true true 200 193 197 249 179 249 177 196 166 187 140 189 93 191 78 179 72 211 49 209 48 181 37 149 25 120 25 89 45 72 103 84 179 75 198 76 252 64 272 81 293 103 285 121 255 121 242 118 224 167
Polygon -7500403 true true 73 210 86 251 62 249 48 208
Polygon -7500403 true true 25 114 16 195 9 204 23 213 25 200 39 123

cylinder
false
0
Circle -7500403 true true 0 0 300

dot
false
0
Circle -7500403 true true 90 90 120

face happy
false
0
Circle -7500403 true true 8 8 285
Circle -16777216 true false 60 75 60
Circle -16777216 true false 180 75 60
Polygon -16777216 true false 150 255 90 239 62 213 47 191 67 179 90 203 109 218 150 225 192 218 210 203 227 181 251 194 236 217 212 240

face neutral
false
0
Circle -7500403 true true 8 7 285
Circle -16777216 true false 60 75 60
Circle -16777216 true false 180 75 60
Rectangle -16777216 true false 60 195 240 225

face sad
false
0
Circle -7500403 true true 8 8 285
Circle -16777216 true false 60 75 60
Circle -16777216 true false 180 75 60
Polygon -16777216 true false 150 168 90 184 62 210 47 232 67 244 90 220 109 205 150 198 192 205 210 220 227 242 251 229 236 206 212 183

fish
false
0
Polygon -1 true false 44 131 21 87 15 86 0 120 15 150 0 180 13 214 20 212 45 166
Polygon -1 true false 135 195 119 235 95 218 76 210 46 204 60 165
Polygon -1 true false 75 45 83 77 71 103 86 114 166 78 135 60
Polygon -7500403 true true 30 136 151 77 226 81 280 119 292 146 292 160 287 170 270 195 195 210 151 212 30 166
Circle -16777216 true false 215 106 30

flag
false
0
Rectangle -7500403 true true 60 15 75 300
Polygon -7500403 true true 90 150 270 90 90 30
Line -7500403 true 75 135 90 135
Line -7500403 true 75 45 90 45

flower
false
0
Polygon -10899396 true false 135 120 165 165 180 210 180 240 150 300 165 300 195 240 195 195 165 135
Circle -7500403 true true 85 132 38
Circle -7500403 true true 130 147 38
Circle -7500403 true true 192 85 38
Circle -7500403 true true 85 40 38
Circle -7500403 true true 177 40 38
Circle -7500403 true true 177 132 38
Circle -7500403 true true 70 85 38
Circle -7500403 true true 130 25 38
Circle -7500403 true true 96 51 108
Circle -16777216 true false 113 68 74
Polygon -10899396 true false 189 233 219 188 249 173 279 188 234 218
Polygon -10899396 true false 180 255 150 210 105 210 75 240 135 240

house
false
0
Rectangle -7500403 true true 45 120 255 285
Rectangle -16777216 true false 120 210 180 285
Polygon -7500403 true true 15 120 150 15 285 120
Line -16777216 false 30 120 270 120

leaf
false
0
Polygon -7500403 true true 150 210 135 195 120 210 60 210 30 195 60 180 60 165 15 135 30 120 15 105 40 104 45 90 60 90 90 105 105 120 120 120 105 60 120 60 135 30 150 15 165 30 180 60 195 60 180 120 195 120 210 105 240 90 255 90 263 104 285 105 270 120 285 135 240 165 240 180 270 195 240 210 180 210 165 195
Polygon -7500403 true true 135 195 135 240 120 255 105 255 105 285 135 285 165 240 165 195

line
true
0
Line -7500403 true 150 0 150 300

line half
true
0
Line -7500403 true 150 0 150 150

pentagon
false
0
Polygon -7500403 true true 150 15 15 120 60 285 240 285 285 120

person
false
0
Circle -7500403 true true 110 5 80
Polygon -7500403 true true 105 90 120 195 90 285 105 300 135 300 150 225 165 300 195 300 210 285 180 195 195 90
Rectangle -7500403 true true 127 79 172 94
Polygon -7500403 true true 195 90 240 150 225 180 165 105
Polygon -7500403 true true 105 90 60 150 75 180 135 105

plant
false
0
Rectangle -7500403 true true 135 90 165 300
Polygon -7500403 true true 135 255 90 210 45 195 75 255 135 285
Polygon -7500403 true true 165 255 210 210 255 195 225 255 165 285
Polygon -7500403 true true 135 180 90 135 45 120 75 180 135 210
Polygon -7500403 true true 165 180 165 210 225 180 255 120 210 135
Polygon -7500403 true true 135 105 90 60 45 45 75 105 135 135
Polygon -7500403 true true 165 105 165 135 225 105 255 45 210 60
Polygon -7500403 true true 135 90 120 45 150 15 180 45 165 90

sheep
false
15
Circle -1 true true 203 65 88
Circle -1 true true 70 65 162
Circle -1 true true 150 105 120
Polygon -7500403 true false 218 120 240 165 255 165 278 120
Circle -7500403 true false 214 72 67
Rectangle -1 true true 164 223 179 298
Polygon -1 true true 45 285 30 285 30 240 15 195 45 210
Circle -1 true true 3 83 150
Rectangle -1 true true 65 221 80 296
Polygon -1 true true 195 285 210 285 210 240 240 210 195 210
Polygon -7500403 true false 276 85 285 105 302 99 294 83
Polygon -7500403 true false 219 85 210 105 193 99 201 83

square
false
0
Rectangle -7500403 true true 30 30 270 270

square 2
false
0
Rectangle -7500403 true true 30 30 270 270
Rectangle -16777216 true false 60 60 240 240

star
false
0
Polygon -7500403 true true 151 1 185 108 298 108 207 175 242 282 151 216 59 282 94 175 3 108 116 108

target
false
0
Circle -7500403 true true 0 0 300
Circle -16777216 true false 30 30 240
Circle -7500403 true true 60 60 180
Circle -16777216 true false 90 90 120
Circle -7500403 true true 120 120 60

tree
false
0
Circle -7500403 true true 118 3 94
Rectangle -6459832 true false 120 195 180 300
Circle -7500403 true true 65 21 108
Circle -7500403 true true 116 41 127
Circle -7500403 true true 45 90 120
Circle -7500403 true true 104 74 152

triangle
false
0
Polygon -7500403 true true 150 30 15 255 285 255

triangle 2
false
0
Polygon -7500403 true true 150 30 15 255 285 255
Polygon -16777216 true false 151 99 225 223 75 224

truck
false
0
Rectangle -7500403 true true 4 45 195 187
Polygon -7500403 true true 296 193 296 150 259 134 244 104 208 104 207 194
Rectangle -1 true false 195 60 195 105
Polygon -16777216 true false 238 112 252 141 219 141 218 112
Circle -16777216 true false 234 174 42
Rectangle -7500403 true true 181 185 214 194
Circle -16777216 true false 144 174 42
Circle -16777216 true false 24 174 42
Circle -7500403 false true 24 174 42
Circle -7500403 false true 144 174 42
Circle -7500403 false true 234 174 42

turtle
true
0
Polygon -10899396 true false 215 204 240 233 246 254 228 266 215 252 193 210
Polygon -10899396 true false 195 90 225 75 245 75 260 89 269 108 261 124 240 105 225 105 210 105
Polygon -10899396 true false 105 90 75 75 55 75 40 89 31 108 39 124 60 105 75 105 90 105
Polygon -10899396 true false 132 85 134 64 107 51 108 17 150 2 192 18 192 52 169 65 172 87
Polygon -10899396 true false 85 204 60 233 54 254 72 266 85 252 107 210
Polygon -7500403 true true 119 75 179 75 209 101 224 135 220 225 175 261 128 261 81 224 74 135 88 99

wheel
false
0
Circle -7500403 true true 3 3 294
Circle -16777216 true false 30 30 240
Line -7500403 true 150 285 150 15
Line -7500403 true 15 150 285 150
Circle -7500403 true true 120 120 60
Line -7500403 true 216 40 79 269
Line -7500403 true 40 84 269 221
Line -7500403 true 40 216 269 79
Line -7500403 true 84 40 221 269

wolf
false
0
Polygon -16777216 true false 253 133 245 131 245 133
Polygon -7500403 true true 2 194 13 197 30 191 38 193 38 205 20 226 20 257 27 265 38 266 40 260 31 253 31 230 60 206 68 198 75 209 66 228 65 243 82 261 84 268 100 267 103 261 77 239 79 231 100 207 98 196 119 201 143 202 160 195 166 210 172 213 173 238 167 251 160 248 154 265 169 264 178 247 186 240 198 260 200 271 217 271 219 262 207 258 195 230 192 198 210 184 227 164 242 144 259 145 284 151 277 141 293 140 299 134 297 127 273 119 270 105
Polygon -7500403 true true -1 195 14 180 36 166 40 153 53 140 82 131 134 133 159 126 188 115 227 108 236 102 238 98 268 86 269 92 281 87 269 103 269 113

x
false
0
Polygon -7500403 true true 270 75 225 30 30 225 75 270
Polygon -7500403 true true 30 75 75 30 270 225 225 270
@#$#@#$#@
NetLogo 6.2.2
@#$#@#$#@
@#$#@#$#@
@#$#@#$#@
<experiments>
  <experiment name="recolonisation_pred" repetitions="30" runMetricsEveryStep="false">
    <setup>setup</setup>
    <go>step</go>
    <final>behav-csv</final>
    <timeLimit steps="300"/>
    <exitCondition>count turtles = 0</exitCondition>
    <enumeratedValueSet variable="prospect?">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="isl-att-curve">
      <value value="&quot;beta2&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="collapse?">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="juvenile-mortality">
      <value value="0.65"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prop-returning-breeders">
      <value value="0.95"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="sex-ratio">
      <value value="1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="capture-data?">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="emigrant-perc">
      <value value="0.8"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="diffusion-prop">
      <value value="0.42"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="adult-mortality-sd">
      <value value="0.05"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="emig-out-prob">
      <value value="0.8"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="verbose?">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="emigration-rate">
      <value value="0.8"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="raft-half-way">
      <value value="200"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="emigration-timer">
      <value value="3"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="age-first-return">
      <value value="6"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="old-mortality">
      <value value="0.8"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="output-file-name">
      <value value="&quot;./output/test.csv&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="emigration-curve">
      <value value="0.5"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="emigration-max-attempts">
      <value value="2"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="natural-chick-mortality">
      <value value="0.35"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="update-colour?">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="female-philopatry">
      <value value="0.95"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="chick-mortality-sd">
      <value value="0.1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="nhb-rad">
      <value value="4"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="adult-mortality">
      <value value="0.05"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="initialisation-data">
      <value value="&quot;/data/twoIsl_recolonisation/twoIsl_pred20_uncolonised.csv&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="max-tries">
      <value value="8"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="max-age">
      <value value="28"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="debug?">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="profiler?">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="age-at-first-breeding">
      <value value="6"/>
    </enumeratedValueSet>
  </experiment>
  <experiment name="two_isl_predation" repetitions="30" runMetricsEveryStep="false">
    <setup>setup</setup>
    <go>step</go>
    <final>behav-csv</final>
    <timeLimit steps="200"/>
    <enumeratedValueSet variable="prospect?">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="isl-att-curve">
      <value value="&quot;beta2&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="collapse?">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="juvenile-mortality">
      <value value="0.65"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prop-returning-breeders">
      <value value="0.95"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="sex-ratio">
      <value value="1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="capture-data?">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="emigrant-perc">
      <value value="0.8"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="diffusion-prop">
      <value value="0.42"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="adult-mortality-sd">
      <value value="0.02"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="emig-out-prob">
      <value value="0.6"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="verbose?">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="emigration-rate">
      <value value="0.8"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="raft-half-way">
      <value value="200"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="emigration-timer">
      <value value="3"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="age-first-return">
      <value value="4"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="behav-output-path">
      <value value="&quot;./output/chick_predation/&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="old-mortality">
      <value value="0.8"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="output-file-name">
      <value value="&quot;./output/test.csv&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="emigration-curve">
      <value value="0.5"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="juvenile-mortality-sd">
      <value value="0.22"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="emigration-max-attempts">
      <value value="2"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="natural-chick-mortality">
      <value value="0.35"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="update-colour?">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="female-philopatry">
      <value value="0.95"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="chick-mortality-sd">
      <value value="0.1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="nhb-rad">
      <value value="4"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="adult-mortality">
      <value value="0.05"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="initialisation-data">
      <value value="&quot;./data/twoIsl_chickPred/small/two_isl_chickpred00_adult0.csv&quot;"/>
      <value value="&quot;./data/twoIsl_chickPred/small/two_isl_chickpred10_adult0.csv&quot;"/>
      <value value="&quot;./data/twoIsl_chickPred/small/two_isl_chickpred10_adult5.csv&quot;"/>
      <value value="&quot;./data/twoIsl_chickPred/small/two_isl_chickpred20_adult0.csv&quot;"/>
      <value value="&quot;./data/twoIsl_chickPred/small/two_isl_chickpred20_adult5.csv&quot;"/>
      <value value="&quot;./data/twoIsl_chickPred/small/two_isl_chickpred30_adult0.csv&quot;"/>
      <value value="&quot;./data/twoIsl_chickPred/small/two_isl_chickpred30_adult5.csv&quot;"/>
      <value value="&quot;./data/twoIsl_chickPred/small/two_isl_chickpred40_adult0.csv&quot;"/>
      <value value="&quot;./data/twoIsl_chickPred/small/two_isl_chickpred40_adult5.csv&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="max-tries">
      <value value="6"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="max-age">
      <value value="28"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="debug?">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="profiler?">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="age-at-first-breeding">
      <value value="6"/>
    </enumeratedValueSet>
  </experiment>
  <experiment name="test" repetitions="2" runMetricsEveryStep="false">
    <setup>setup</setup>
    <go>step</go>
    <final>behav-csv</final>
    <timeLimit steps="100"/>
    <enumeratedValueSet variable="prospect?">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="isl-att-curve">
      <value value="&quot;beta2&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="collapse?">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="juvenile-mortality">
      <value value="0.65"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prop-returning-breeders">
      <value value="0.95"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="sex-ratio">
      <value value="1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="capture-data?">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="emigrant-perc">
      <value value="0.8"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="diffusion-prop">
      <value value="0.42"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="adult-mortality-sd">
      <value value="0.05"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="emig-out-prob">
      <value value="0.8"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="verbose?">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="emigration-rate">
      <value value="0.8"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="raft-half-way">
      <value value="200"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="emigration-timer">
      <value value="3"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="age-first-return">
      <value value="6"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="old-mortality">
      <value value="0.8"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="output-file-name">
      <value value="&quot;./output/test.csv&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="emigration-curve">
      <value value="0.5"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="emigration-max-attempts">
      <value value="2"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="natural-chick-mortality">
      <value value="0.35"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="update-colour?">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="female-philopatry">
      <value value="0.95"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="chick-mortality-sd">
      <value value="0.1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="nhb-rad">
      <value value="4"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="adult-mortality">
      <value value="0.05"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="initialisation-data">
      <value value="&quot;/data/twoIsl_recolonisation/twoIsl_pred20_uncolonised.csv&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="max-tries">
      <value value="8"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="max-age">
      <value value="28"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="debug?">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="profiler?">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="age-at-first-breeding">
      <value value="6"/>
    </enumeratedValueSet>
  </experiment>
  <experiment name="experiment" repetitions="1" runMetricsEveryStep="true">
    <setup>setup</setup>
    <go>go</go>
    <metric>count turtles</metric>
    <enumeratedValueSet variable="prospect?">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="isl-att-curve">
      <value value="&quot;beta2&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="juvenile-mortality">
      <value value="0.65"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="collapse?">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prop-returning-breeders">
      <value value="0.95"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="sex-ratio">
      <value value="1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="capture-data?">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="diffusion-prop">
      <value value="0.42"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="adult-mortality-sd">
      <value value="0.02"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="emig-out-prob">
      <value value="0.6"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="verbose?">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="raft-half-way">
      <value value="200"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="emigration-timer">
      <value value="6"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="age-first-return">
      <value value="4"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="behav-output-path">
      <value value="&quot;./output/chick_predation/&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="old-mortality">
      <value value="0.5"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="output-file-name">
      <value value="&quot;./output/test.csv&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="emigration-curve">
      <value value="0.5"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="juvenile-mortality-sd">
      <value value="0.22"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="emigration-max-attempts">
      <value value="2"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="natural-chick-mortality">
      <value value="0.35"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="update-colour?">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="female-philopatry">
      <value value="0.95"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="chick-mortality-sd">
      <value value="0.1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="nhb-rad">
      <value value="4"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="adult-mortality">
      <value value="0.05"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="enso?">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="initialisation-data">
      <value value="&quot;./data/simple_islands.csv&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="max-tries">
      <value value="6"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="max-age">
      <value value="28"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="enso-adult-mort">
      <value value="&quot;[0.25 0.1 0 0.1 0.25]&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="debug?">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="profiler?">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="enso-breed-impact">
      <value value="&quot;[0.5 0.2 0 0.2 0.5]&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="age-at-first-breeding">
      <value value="6"/>
    </enumeratedValueSet>
  </experiment>
  <experiment name="persistence" repetitions="10" runMetricsEveryStep="true">
    <setup>setup</setup>
    <go>step</go>
    <final>behav-csv</final>
    <timeLimit steps="50"/>
    <enumeratedValueSet variable="age-at-first-breeding">
      <value value="6"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prospect?">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="isl-att-curve">
      <value value="&quot;beta2&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="collapse?">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="juvenile-mortality">
      <value value="0.65"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prop-returning-breeders">
      <value value="0.9"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="sex-ratio">
      <value value="1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="capture-data?">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="diffusion-prop">
      <value value="0.4"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="adult-mortality-sd">
      <value value="0.01"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="emig-out-prob">
      <value value="0.75"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="verbose?">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="attrition?">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="raft-half-way">
      <value value="250"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="emigration-timer">
      <value value="4"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="collapse-half-way">
      <value value="150"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="age-first-return">
      <value value="5"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="behav-output-path">
      <value value="&quot;./output/&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="old-mortality">
      <value value="0.8"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="emigration-curve">
      <value value="0.5"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="collapse-perc-sd">
      <value value="0.05"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="juvenile-mortality-sd">
      <value value="0.1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="emigration-max-attempts">
      <value value="2"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="natural-chick-mortality">
      <value value="0.4"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="print-stage?">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="update-colour?">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="female-philopatry">
      <value value="0.95"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="chick-mortality-sd">
      <value value="0.1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="nhb-rad">
      <value value="4"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="patch-burrow-limit">
      <value value="100"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="adult-mortality">
      <value value="0.05"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="initialisation-data">
      <value value="&quot;./data/hyper_densities/predators.csv&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="enso?">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="max-tries">
      <value value="6"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="max-age">
      <value value="28"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="enso-adult-mort">
      <value value="&quot;[0.05 0.025 0 0.025 0.05]&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="debug?">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="collapse-perc">
      <value value="0.25"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="nlrx?">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="time-to-prospect">
      <value value="2"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="burrow-attrition-rate">
      <value value="0.2"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="patch-burrow-minimum">
      <value value="5"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="profiler?">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="enso-breed-impact">
      <value value="&quot;[0.5 0.2 0 0.2 0.5]&quot;"/>
    </enumeratedValueSet>
  </experiment>
</experiments>
@#$#@#$#@
@#$#@#$#@
default
0.0
-0.2 0 0.0 1.0
0.0 1 1.0 0.0
0.2 0 0.0 1.0
link direction
true
0
Line -7500403 true 150 150 90 180
Line -7500403 true 150 150 210 180
@#$#@#$#@
1
@#$#@#$#@
