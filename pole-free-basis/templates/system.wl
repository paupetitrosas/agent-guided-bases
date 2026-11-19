(* system.wl: the families, their masters and the order of the masters in the differential equation
   (see reference/formats.md). Paths are relative to this file. Replace every <...>. *)
<|
 "Name" -> "<name of the problem>",
 "Families" -> {
   (* a base family: its definition in maximal-cut-basis format (family.wl) and its masters *)
   <|"Name" -> "<fam1>", "Family" -> "<families/fam1.wl>", "Masters" -> "<masters/fam1.m>",
     (* optional: "Prefactors" -> "<roots.m>"  (a list multiplying the masters one by one),
                  "Rules" -> {FFG -> j, j[a_, {b__}] :> j[a, b]}   (applied in turn, to bring the file to j[fam, a1, ..., aN]),
                  "ISPs" -> {8, 9}   (positions that are never propagators; found from the masters when left out),
                  "LettersFromSOFIA" -> True   (only after the user's yes: SOFIA's polynomials from bin/singularities.wls are its letters),
                  "MCBRun" -> "<the maximal-cut-basis run folder that produced these masters>"   (read only: rung 8 and the
                     rational normalisations of the simplification phase) *)
   |>,
   (* an image family: the base family with external momenta exchanged; masters, invariants and roots follow *)
   <|"Name" -> "<fam1x12>", "ImageOf" -> "<fam1>", "MomentumMap" -> {p1 -> p2, p2 -> p1}
     (* optional: "InvariantMap" (checked against the one implied by the momentum map), "RootSuffix" -> "x12", "RootMap" -> {r1 -> r1x12, ...},
                  "Masters" (only if the image's masters are not the mapped ones) *)
   |>
 },
 "LoadOrder" -> Automatic,          (* the order in which the families are defined for LiteRed: the order above *)
 "MasterOrder" -> "Join",           (* global labels ut[k]: "Join" (masters of the families in order), "ReverseJoin", or {{fam, pos}, ...} *)
 "Roots" -> {r1 -> Sqrt[<radicand>]},   (* or a file; every square root in the masters must be one of these (or is named automatically) *)
 "SymmetryRules" -> None,           (* optional: file with rules j[...] -> combination that LiteRed misses (extra identities) *)
 "Frozen" -> {}                     (* families whose masters must not change *)
|>
