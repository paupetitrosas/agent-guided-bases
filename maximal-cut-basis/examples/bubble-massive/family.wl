(* One-loop bubble with two equal masses, p^2 = s.  The maximal cut is a point; the normalisation is
   Sqrt[s (s - 4 m2)] and the canonical integral needs a dot in d = 4 - 2 eps: expected status eps-form. *)
<|
 "Name" -> "bub",
 "LoopMomenta" -> {k},
 "ExternalMomenta" -> {p},
 "ScalarProducts" -> {p^2 -> s},
 "Propagators" -> {
   <|"Type" -> "Quadratic", "Momentum" -> k, "Mass2" -> m2|>,
   <|"Type" -> "Quadratic", "Momentum" -> k + p, "Mass2" -> m2|>
 },
 "Invariants" -> <|s -> 2, m2 -> 2|>,
 "UnitScale" -> m2,
 "D0" -> 4,
 "Masters" -> {j[bub, 1, 0], j[bub, 1, 1]},
 "Graph" -> {{1, 2, 1}, {2, 1, 2}, {1, p}, {2, p}}
|>
