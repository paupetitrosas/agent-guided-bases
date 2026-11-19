(* Two-loop planar massless double box, p_i^2 = 0, s = (p1+p2)^2, t = (p2+p3)^2, two ISPs.
   Top sector j[dbox,1,1,1,1,1,1,1,0,0]: two masters, a one-variable rational cut in the loop-by-loop
   representation.  Known UT basis (e.g. arXiv:1304.1806): s^2 t eps^4 j[..,0,0] and s^2 eps^4 j[..,-1,0]
   with the numerator (k1+p4)^2 up to normalisation.  Expected status eps-form. *)
<|
 "Name" -> "dbox",
 "LoopMomenta" -> {k1, k2},
 "ExternalMomenta" -> {p1, p2, p3},
 "MomentumConservation" -> {p4 -> -p1 - p2 - p3},
 "ScalarProducts" -> {p1^2 -> 0, p2^2 -> 0, p3^2 -> 0, p1 p2 -> s/2, p2 p3 -> t/2, p1 p3 -> -(s + t)/2},
 "Propagators" -> {
   <|"Type" -> "Quadratic", "Momentum" -> k1|>,
   <|"Type" -> "Quadratic", "Momentum" -> k1 + p1|>,
   <|"Type" -> "Quadratic", "Momentum" -> k1 + p1 + p2|>,
   <|"Type" -> "Quadratic", "Momentum" -> k2 + p1 + p2|>,
   <|"Type" -> "Quadratic", "Momentum" -> k2 - p4|>,
   <|"Type" -> "Quadratic", "Momentum" -> k2|>,
   <|"Type" -> "Quadratic", "Momentum" -> k1 - k2|>,
   <|"Type" -> "Quadratic", "Momentum" -> k1 + p4|>,     (* ISP *)
   <|"Type" -> "Quadratic", "Momentum" -> k2 + p1|>      (* ISP *)
 },
 "Invariants" -> <|s -> 2, t -> 2|>,
 "UnitScale" -> s,
 "D0" -> 4,
 "Masters" -> {j[dbox, 1, 1, 1, 1, 1, 1, 1, 0, 0], j[dbox, 1, 1, 1, 1, 1, 1, 1, -1, 0]}
|>
