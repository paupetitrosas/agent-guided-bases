(* family.wl: the definition of one integral family (see reference/formats.md).
   j[NAME, a1, ..., aN] = Int prod_i D_i^(-a_i), d = D0 - 2 eps.  Replace every <...>. *)
<|
 "Name"                 -> "<name>",
 "LoopMomenta"          -> {k1, k2},
 "ExternalMomenta"      -> {p1, p2, p3},                      (* independent external momenta *)
 "MomentumConservation" -> {p4 -> -p1 - p2 - p3},             (* optional *)
 "ScalarProducts"       -> {p1^2 -> 0, p2^2 -> 0, p3^2 -> 0, p1 p2 -> s/2, p2 p3 -> t/2, p1 p3 -> -(s + t)/2},
 "Propagators"          -> {                                   (* L(L+1)/2 + L E entries, ISPs included *)
   <|"Type" -> "Quadratic", "Momentum" -> k1, "Mass2" -> 0|>,
   <|"Type" -> "Quadratic", "Momentum" -> k1 + p1|>,
   (* <|"Type" -> "Linear", "Momentum" -> k1, "Vector" -> n, "Constant" -> w|>   is  k1.n - w *)
   <|"Type" -> "Quadratic", "Momentum" -> k2 + p1|>              (* ISP *)
 },
 "Invariants"           -> <|s -> 2, t -> 2|>,                 (* every symbol, with its mass dimension *)
 "UnitScale"            -> s,
 "D0"                   -> 4,
 "Masters"              -> None,                               (* or "path/to/kira/masters", or {j[<name>, ...], ...} *)
 "TopSectors"           -> {"j110"}                            (* the propagators, ISPs left out: bounds the whole-family Kira run *)
 (* , "Graph" -> {{1, 2, 1}, {2, 3, 2}, ..., {1, p1}, ...}     optional: lines {vertex, vertex, propagator}, legs {vertex, momentum} *)
|>
