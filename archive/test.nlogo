extensions
[
  csv ;;loading in data for setup and exporting data from runs
  rnd ;;distribution functions
  profiler ;;profiling to detect bottlenecks
  stats ;;beta distribution pdf
  ;rnetlogo
]

globals
[
  num-islands

  the-islands
  the-sea
  the-shore

  island-id ;;List of ID's for the islands (1 - n; where n is the number of islands); sea is 0.
  colonies ;;list of patchsets for each island


  pred-islands
  safe-islands

  island-attractiveness ;;weighting for philopatry

  lekking-males ;;list of colony patch-sets that contain the patches with male-count > 0
  breeders
  recruits
  new-recruits

  isl-occ ;;the number of breeding bird on each island
  world-occ ;;the number of breeding birds in the world (adult breeders only)

  ; set demog lput (list a b c) demog
  adult-pop ;;the total number of adults
  juv-pop ;;the total number ofjuveniles
  pop-size ;;Total population

  philopatry-out ;;Count of birds who failed a philopatry test each year leaving the system

  demography-series
  demography-year
  island-series
  island-year

  old-pairs
  new-pairs
  nhb-rad
  diffusion-prop
  ;;Distribution parameters
  asymp-curve
]

patches-own
[

  ;;SETUP
  ;;initialisation globals for set up
  colony-id
  predation
  adult-predation
  chick-predation
  prop-suitable
  low-lambda
  high-lambda
  habitat-aggregation
  time-to-prospect
  collapse-half-way
  collapse-perc
  starting-juveniles
  starting-seabird-pop
  sex-ratio


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

  low-k             ;; capacity and
  low-value-resource  ;; current level of low value resource

;  mh-d
;  on-island?
;  edge-shell        ;; used by irregular island code
]


turtles-own
[

  breeding-grounds ;;patchset of breeding grounds
  breeding-ground-id ;;The location of their breeding ground
  natal-ground-id ;;What island they were born on
  burrow ;;a single patch that this bird last bred at - surrogate for mate with no males present

  settled? ;;Whether or not this bird has chosen a breeding ground (happens only once)
  breeding? ;;Whether or not it has found a patch within the colony (reset yearly)
  mating? ;;Whether or not a bird has successfully established a burrow with a 'male'

  age ;;numeric counting the age of individuals
  life-stage ;;Juvenile/Adults
  time-since-breed ;;counter for how long it has been since the bird has bred.

  last-breeding-success? ;;T/F indicating whether their last breeding attempt was successful or unsuccessful

]

breed ; convience name
[
  females female ;female birds
]

to setup
  init-patches
  init-isl-from-file
  init-adults
  assign-burrows
  init-juveniles
end


to init-patches ;;Creating default patches and patch-sets (all values set at value for the sea)
  set pred-islands no-patches

  ask patches
  [
    set habitable? FALSE
    set suitable? false
    set colony-id 0
    set habitat-attrac 0
    set occupancy 0
    set occupancy-limit 0
    set predators? false
    set pcolor blue
    set neighbourhood no-patches
  ]

end


to init-isl-from-file

  ;;carefully - wrap this function to fail gracefully if there is no file that can be loaded.
  let init-data csv:from-file "/data/simple_islands.csv"

  ;;Getting variable names and number of variables
  let var-names item 0 init-data
  let var-num length var-names
  let var-values remove-item 0 init-data

  ;;Number of islands
  set num-islands length var-values

  ;Sequence of 1 to number of islands for foreach loop
  let isl-seq  (range num-islands)

  ;;Creating island blobs
  foreach isl-seq [ i ->

    ;;A subsetted list of the values for this run
    let isl-values item i var-values

    ;;How big the island is
    let isl-area item 0 isl-values

    ;;Creating island foundation
    grow-islands isl-area

    ask patches with [ pcolor = green and colony-id = 0 ]
    [
      set colony-id (i + 1)
    ]

    let var-seq (range 1 var-num)

    foreach var-seq [ v ->

      ;;The name of the variable
      let po-name item v var-names
      ;;The value for the variable
      let po-val item v isl-values

      ;;Concatonating the command for setting island values
      let cmd (word "set " po-name " " po-val)
      ask patches with [ colony-id = (i  + 1) ]
      [
        run cmd
      ]
    ]
  ]
  ;;Creating agentsets of patches
  crt-patchsets

  ;;Creating the habitat
  init-habitat
end

to grow-islands [ clust-area ] ;;Creating islands and colonies

  ask one-of patches with [ count patches with [ pcolor = green ] in-radius (clust-area + 1)  = 0 and abs(pycor) > clust-area and abs(pxcor) > clust-area] ;Bouncing off edge of world
  [
    let cluster patches in-radius clust-area ;creating patch-set of the cluster

    ;;Setting seed patches parameters
    set pcolor green
    set habitable? TRUE ;setting this to be desireable habitat for the turtle

    ;;Setting surround patches parameters
    ask cluster ;expanding the patch as a function of density and user defined area
    [
      set pcolor green
      set habitable? TRUE ;see above for this line and the one below
    ]
  ]

end

to crt-patchsets

  ;Setting some conviences names
  set colonies patches with [ colony-id > 0 ] ;the baseline initialisation for cells is 0 (i.e. sea cells are 0)
  set the-islands patches with [ habitable? ] ;convenience name
  set island-id sort remove-duplicates [ colony-id ] of the-islands ;;creating a list of island-id's
  set the-sea patches with [ not habitable? ]
  set pred-islands patches with [ predators? ]
  set safe-islands patches with [ habitable? = true and not predators? ]

end

 to init-habitat

  ;Creating habitat heterogeneity and storing the colony patch-sets in a list (colonies)
  set colonies []
  foreach island-id [n ->
    dig-burrows n
    set colonies lput (patches with [colony-id = n]) colonies
  ]

  ;Now diffuse surface
  diffuse occupancy-limit diffusion-prop

  ask patches
  [
    set occupancy-limit floor occupancy-limit
  ]

  ;Removing occupancy limits that shouldn't exist
  ask the-sea
  [
    set occupancy-limit 0
  ]


  ask patches with [ habitable? ]
  [
    ifelse nhb-rad <= 1 [set neighbourhood (neighbors with [ habitable? ])][set neighbourhood patches with [ habitable? ] in-radius nhb-rad] ; set neighbourhoods for only island patches
  ]

  ;;for the colour scale...
  let min-occ-lim min [ occupancy-limit ] of the-islands
  let max-occ-lim max [ occupancy-limit ] of the-islands

  ask the-islands
  [
    ;;making it prettier
    set pcolor scale-color green occupancy-limit max-occ-lim min-occ-lim

    ;;initialising habitat attractiveness
    set maxK max [ occupancy-limit ] of neighbourhood
    ask the-islands with [ maxK != 0 ] ;defensive in case there are any patches surrounded by 0
    [
      set habitat-attrac ( occupancy-limit / maxK ) * 0.3
    ]
  ]

end

to dig-burrows [ n ]

  let island-patches patches with [ colony-id = n ] ;looking at only this island
  let island-size count island-patches ;counting island size for determining suitability

  let example one-of island-patches
  let prop-suit [prop-suitable] of example
  let habitat-agg [habitat-aggregation] of example
  let high-l  [high-lambda] of example
  let low-l  [low-lambda] of example

  ;; seeds the grid with one patch as suitable
  ask one-of island-patches [ set suitable? true]
  let filled 1

  ;; this sequentially fills the grid by selecting patches and making them suitable
  while [filled <= (prop-suit * island-size)]
  [
    ;; if rnd test is less than attract-suitable then an *unsuitable* patch next to a suitable patch is made suitable
    ifelse random-float 1 <= habitat-agg
    [
      ask one-of [ neighbors with [ habitable? ] ] of (island-patches with [suitable?])
      [
        if suitable? = false
        [
          set suitable? true
          set filled filled + 1
        ]
      ]
    ]

    ;; otherwise pick a patch at random (this could any neighbouring a suitable patch)
    ;; if you want to make sure it does not you'd need to use
    ;; ask one-of patches with [(not suitable?) and (count neighbors with [suitable?] = 0)]
    [
      ask one-of island-patches with [habitable? and not suitable?]
      ;;ask one-of patches with [(not suitable?) and (count neighbors with [suitable?] = 0)]
      [
        set suitable? true
        set filled filled + 1
      ]
    ]
 ]

  ;Now set two different poisson distributions
  ask island-patches
  [
    ifelse suitable?
    [
      set occupancy-limit random-poisson high-l
    ]
    [
      set occupancy-limit random-poisson low-l
    ]
  ]


  set island-attractiveness [] ; initialising

  foreach island-id [ i ->
    let isl-att round( (1 / max island-id) * 100 )
    set island-attractiveness lput isl-att island-attractiveness
  ]

end

to init-adults

  foreach island-id [ n ->

    let example one-of patches with [ colony-id = n ]
    let isl-n-females [ starting-seabird-pop ] of example

    ;initialising females
    create-females [ starting-seabird-pop ] of example

    ;initialising basic parameters of birds
    ask females with [ settled? = 0]
    [
      ;set shape "bird side"
      setxy 0 0 ;making them all start on the left edge of the ma
      set age 6 + random-poisson 5 ;adding some age variability
      set size 1
      set life-stage "Adult"
      set time-since-breed 0

      set natal-ground-id n
      set breeding-ground-id n
      set breeding-grounds patch-set patches with [ colony-id = n ]
      set burrow no-patches

      set settled? true ;Has not been assigned a colony
      set breeding? false ;Has not found a patch
      set mating? false ;Has not found a mate
    ]

  ]

    ask females
    [
      set color orange
    ]

    set breeders females with [ life-stage = "Adult"]

end

;to assign-colonies
;
;  if debug? [ show island-id ]
;
;  ask breeders with [not settled?]
;  [
;    ;set breeding-ground-id to match a colony-id and that the occupancy is less than the occupancy-limit
;    let target-grd one-of island-id
;    set breeding-ground-id target-grd
;    set natal-ground-id target-grd ;intialising as the breeding-grounds = natal grounds
;    set settled? true
;    set breeding-grounds patch-set patches with [ colony-id = target-grd ]
;    ; if [debug?] [ show "target grd id: " show target-grd ]
;  ]
;
;end


to assign-burrows

  ask breeders with [ life-stage = "Adult" and breeding-grounds != no-patches ]
  [
    set burrow one-of breeding-grounds with [ occupancy < occupancy-limit ]
    ;if debug? [ show burrow ]
  ]

end

to init-juveniles

  foreach island-id [ n ->

    let example one-of patches with [ colony-id = n ]
    let juvenile-pop [ starting-juveniles ] of example

    create-females juvenile-pop
    [
      raise-chick orange
    ]

    ;;Adding to the recruits agentset
    set recruits turtles with [ life-stage = "Juvenile"]

    ;;Assigning them to their natal island
    ask recruits with [ not settled? ]
    [
      set breeding-ground-id n
      set breeding-grounds patch-set patches with [ colony-id = n ]
      set settled? TRUE
    ]
  ]

end


to raise-chick [ colour ]

  set color colour

  set size 1
  set shape "bird side"
  set age random 6
  set settled? false
  set breeding? false
  set mating? false
  set last-breeding-success? false
  set life-stage "Juvenile"
  set natal-ground-id colony-id
  set breeding-ground-id 0
  set breeding-grounds no-patches
  set burrow no-patches
  set time-since-breed 0

end


;to assign-natal-grounds
;  ask recruits
;  [
;    set natal-ground-id one-of island-id ;Assigning a random colony as natal grounds
;  ]
;end

to create-data-sheet

  set demography-series ["recruits" "" ]

end
@#$#@#$#@
GRAPHICS-WINDOW
210
10
1022
823
-1
-1
4.0
1
10
1
1
1
0
1
1
1
-100
100
-100
100
0
0
1
ticks
30.0

BUTTON
104
79
167
112
go
go\n
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
36
81
99
114
setup
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
NetLogo 6.2.0
@#$#@#$#@
@#$#@#$#@
@#$#@#$#@
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
0
@#$#@#$#@
