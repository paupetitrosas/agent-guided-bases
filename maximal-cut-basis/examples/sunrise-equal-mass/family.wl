(* Two-loop equal-mass sunrise, p^2 = s, three propagators of mass^2 m2, two ISPs.
   The maximal cut of j[sunrise,1,1,1,0,0] is an elliptic curve: expected status eps-polynomial. *)
<|
 "Name" -> "sunrise",
 "LoopMomenta" -> {k1, k2},
 "ExternalMomenta" -> {p},
 "ScalarProducts" -> {p^2 -> s},
 "Propagators" -> {
   <|"Type" -> "Quadratic", "Momentum" -> k1, "Mass2" -> m2|>,
   <|"Type" -> "Quadratic", "Momentum" -> k2, "Mass2" -> m2|>,
   <|"Type" -> "Quadratic", "Momentum" -> k1 + k2 - p, "Mass2" -> m2|>,
   <|"Type" -> "Quadratic", "Momentum" -> k1 - p|>,     (* ISP *)
   <|"Type" -> "Quadratic", "Momentum" -> k2 - p|>      (* ISP *)
 },
 "Invariants" -> <|s -> 2, m2 -> 2|>,
 "UnitScale" -> m2,
 "D0" -> 4,
 "Masters" -> {j[sunrise, 1, 1, 0, 0, 0], j[sunrise, 1, 1, 1, 0, 0], j[sunrise, 2, 1, 1, 0, 0]},
 "Graph" -> {{1, 2, 1}, {1, 2, 2}, {2, 1, 3}, {1, p}, {2, p}}
|>
