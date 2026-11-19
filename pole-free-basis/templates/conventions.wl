(* conventions.wl: how an external slice of the DE was written (see reference/formats.md).
   The skill never trusts these by themselves: the calibration (bin/calibrate.wls) must agree exactly. Ask the user
   when anything below is not known for sure. *)
<|
 "File" -> "<slice.m>",                 (* Get gives {A_x1, A_x2, ...}: one matrix per differentiated invariant, exact in eps *)
 "Derivatives" -> {<s>, <t>},           (* the invariants of the matrices, in their order *)
 "Point" -> {<s> -> 1423, <t> -> 1637, <m2> -> 6229},   (* EVERY invariant, at its value in the slice *)
 "Labels" -> All,                       (* rows/columns: All (every master, in label order), a list {ut[3], ut[5], ...}, or a file with it *)
 "Frame" -> "RootFree",                 (* "RootFree": entries for the masters without their square roots (dlog of the roots on the diagonal);
                                           "RootSymbols": square roots were independent variables with the values RootValues;
                                           "Rational": full masters whose prefactors are rational at the point *)
 "RootValues" -> {},                    (* "RootSymbols" only: {r1 -> value, ...} *)
 "RootOrder" -> Automatic,              (* "RootSymbols" only: the root definitions, in the order the producer matched them *)
 "Transpose" -> False,                  (* True if the slice has columns = derivatives of the masters *)
 "Degrees" -> None,                     (* optional: a file with the kinematic degrees of the entries, in the slice's layout (reference/formats.md) *)
 "Credits" -> {}                        (* optional: what produced this DE, credited for the whole run in CITATIONS.md: tools by
                                           their registry names ("kira", "FiniteFlow", "LiteRed", ...; an unknown name refuses
                                           the import) and papers <|"reference" -> "authors, title, arXiv:...", "used" -> "..."|> *)
|>
