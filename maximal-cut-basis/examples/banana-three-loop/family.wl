(* Three-loop equal-mass banana, p^2 = s, four propagators of mass^2 m2 between two vertices, five ISPs, d = 2 - 2 eps.
   The maximal cut of j[banana,1,1,1,1,0,0,0,0,0] is a K3 surface: at eps = 0 the Picard-Fuchs operator of the
   corner integral has order 3 and is the symmetric square of an order-2 (elliptic) operator.
   Four masters: the cube of the tadpole and three on the maximal cut of the top sector.
   Expected status eps-polynomial; the planted K3 case of the picard-fuchs step. *)
<|
 "Name" -> "banana",
 "LoopMomenta" -> {k1, k2, k3},
 "ExternalMomenta" -> {p},
 "ScalarProducts" -> {p^2 -> s},
 "Propagators" -> {
   <|"Type" -> "Quadratic", "Momentum" -> k1, "Mass2" -> m2|>,
   <|"Type" -> "Quadratic", "Momentum" -> k2, "Mass2" -> m2|>,
   <|"Type" -> "Quadratic", "Momentum" -> k3, "Mass2" -> m2|>,
   <|"Type" -> "Quadratic", "Momentum" -> k1 + k2 + k3 - p, "Mass2" -> m2|>,
   <|"Type" -> "Quadratic", "Momentum" -> k1 - p|>,     (* ISP *)
   <|"Type" -> "Quadratic", "Momentum" -> k2 - p|>,     (* ISP *)
   <|"Type" -> "Quadratic", "Momentum" -> k3 - p|>,     (* ISP *)
   <|"Type" -> "Quadratic", "Momentum" -> k1 + k2|>,    (* ISP *)
   <|"Type" -> "Quadratic", "Momentum" -> k2 + k3|>     (* ISP *)
 },
 "Invariants" -> <|s -> 2, m2 -> 2|>,
 "UnitScale" -> m2,
 "D0" -> 2,
 "Masters" -> {j[banana, 1, 1, 1, 0, 0, 0, 0, 0, 0], j[banana, 1, 1, 1, 1, 0, 0, 0, 0, 0], j[banana, 2, 1, 1, 1, 0, 0, 0, 0, 0],
   j[banana, 3, 1, 1, 1, 0, 0, 0, 0, 0]},
 "Graph" -> {{1, 2, 1}, {1, 2, 2}, {1, 2, 3}, {2, 1, 4}, {1, p}, {2, p}}
|>
