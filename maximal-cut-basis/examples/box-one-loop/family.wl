(* One-loop massless box, p_i^2 = 0, s = (p1+p2)^2, t = (p2+p3)^2.  Maximal cuts: the box and the two
   bubbles are points; expected status eps-form everywhere (box normalisation s t, bubbles s and t). *)
<|
 "Name" -> "box",
 "LoopMomenta" -> {k},
 "ExternalMomenta" -> {p1, p2, p3},
 "ScalarProducts" -> {p1^2 -> 0, p2^2 -> 0, p3^2 -> 0, p1 p2 -> s/2, p2 p3 -> t/2, p1 p3 -> -(s + t)/2},
 "Propagators" -> {
   <|"Type" -> "Quadratic", "Momentum" -> k|>,
   <|"Type" -> "Quadratic", "Momentum" -> k + p1|>,
   <|"Type" -> "Quadratic", "Momentum" -> k + p1 + p2|>,
   <|"Type" -> "Quadratic", "Momentum" -> k + p1 + p2 + p3|>
 },
 "Invariants" -> <|s -> 2, t -> 2|>,
 "UnitScale" -> s,
 "D0" -> 4,
 "Masters" -> {j[box, 1, 0, 1, 0], j[box, 0, 1, 0, 1], j[box, 1, 1, 1, 1]},
 "Graph" -> {{1, 2, 1}, {2, 3, 2}, {3, 4, 3}, {4, 1, 4}, {1, p1}, {2, p2}, {3, p3}, {4, p4}}
|>
