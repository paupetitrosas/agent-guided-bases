#!/usr/bin/env wolframscript
(* The eps structure of the rows under a simplification move: no row's lowest power of eps drops, and an eps-form row
   (every entry eps^1, or zero) stays eps-form (PFBRowEpsProfile, PFBEpsFloorViolations, PFBEpsFloorWorseQ), on the
   slice (PFBSimplifySliceCheck, PFBSimplifyGate's "eps structure") and at the degree jobs' points (the phase's
   off-slice check on planted degree tables). Planted slices of the one-loop massless box of the maximal-cut-basis
   examples (the s-bubble, the t-bubble, the box), without FiniteFlow or IBP.
   usage: bin/ws tests/eps_structure.wls        exit code 0 when every test passes *)
Get[FileNameJoin[{ParentDirectory[DirectoryName[$InputFileName]], "lib", "PoleFreeBasis.wl"}]];
$PFBVerbose = False;
boxFile = FileNameJoin[{ParentDirectory[$PFBRoot], "maximal-cut-basis", "examples", "box-one-loop", "family.wl"}];
tmp = CreateDirectory[];
tests = {};
sliceOf[R_, n_] := <|"R" -> {R}, "Derivatives" -> {t}, "Point" -> {s -> 1, t -> 3/7}, "Labels" -> Range[n], "Index" -> AssociationThread[Range[n] -> Range[n]],
   "Frame" -> "RootFree", "History" -> {}|>;

(* ---- the rows: an eps-form row, an eps-polynomial row from eps^1, a row with eps^-1, a zero row ---- *)
R0 = {{-eps, 0, 0, 0}, {0, eps, eps^2, 0}, {1/eps, eps, 1, 0}, {0, 0, 0, 0}};
sl0 = sliceOf[R0, 4];
viol[R_] := {#[[2]], #[[3]], #[[4]]} & /@ PFBEpsFloorViolations[sl0, sliceOf[R, 4]];
AppendTo[tests, VerificationTest[PFBRowEpsProfile[sl0, 1, #] & /@ {1, 2, 3, 4}, {{1, 1}, {1, 2}, {-1, 1}, "zero"}, TestID -> "the eps range of a row"]];
AppendTo[tests, VerificationTest[{viol[ReplacePart[R0, {1, 2} -> 1]], viol[ReplacePart[R0, {1, 2} -> eps^2]]}, {{{1, {1, 1}, {0, 1}}}, {{1, {1, 1}, {1, 2}}}},
  TestID -> "an eps-form row that gains eps^0 or eps^2 loses its form"]];
AppendTo[tests, VerificationTest[{viol[ReplacePart[R0, {2, 1} -> 1 + eps]], viol[ReplacePart[R0, {2, 4} -> eps^2]]}, {{{2, {1, 2}, {0, 2}}}, {}},
  TestID -> "a row from eps^1 may not gain eps^0, and may gain eps^2"]];
AppendTo[tests, VerificationTest[{viol[ReplacePart[R0, {3, 1} -> 1/eps^2]], viol[ReplacePart[R0, {3, 4} -> 3]]}, {{{3, {-1, 1}, {-2, 1}}}, {}},
  TestID -> "a row with eps^-1 may not go to eps^-2, and may gain eps^0"]];
AppendTo[tests, VerificationTest[{viol[ReplacePart[R0, {4, 1} -> 2 eps]], viol[ReplacePart[R0, {4, 1} -> 2]]}, {{}, {{4, "zero", {0, 0}}}},
  TestID -> "a zero row may gain eps^1 entries only"]];
AppendTo[tests, VerificationTest[{viol[ReplacePart[R0, {1, 2} -> 1/(1 - 2 eps)]], PFBEpsFloorWorseQ["pole", {0, 0}]}, {{}, False},
  TestID -> "rows with finite poles are left to the pole checks"]];

(* ---- the slice check and the gate of the phase ---- *)
Put[{j[box, 1, 0, 1, 0], j[box, 0, 1, 0, 1], s t j[box, 1, 1, 1, 1]}, FileNameJoin[{tmp, "box.m"}]];
Put[<|"Name" -> "planted", "Families" -> {<|"Name" -> "box", "Family" -> boxFile, "Masters" -> "box.m"|>}|>, FileNameJoin[{tmp, "box.wl"}]];
sys = PFBReadSystem[FileNameJoin[{tmp, "box.wl"}]];
(* the t-bubble's row is eps-form; the shift of the move puts eps^0 into it (column 1), which its own block (one entry)
   does not see *)
RS = {{-eps, 0, 0}, {0, -2 eps, 0}, {eps, 1 + eps, -1 - 2 eps}};
slA = sliceOf[RS, 3]; slB = sliceOf[ReplacePart[RS, {2, 1} -> 5/7], 3];
cA = PFBCensus[sys, slA];
chk = PFBSimplifySliceCheck[sys, slA, cA, slB];
AppendTo[tests, VerificationTest[{chk["Pass"], StringContainsQ[StringRiffle[chk["Reasons"]], "eps structure gets worse (a lower power of eps, or an eps-form row that loses its form): ut[2]"],
    StringContainsQ[StringRiffle[chk["Reasons"]], "eps-form blocks"]}, {False, True, False},
  TestID -> "slice check: eps^0 in an eps-form row is refused, though the sector's own block keeps its form"]];
gate0 = <|"Pass" -> True, "Checks" -> {<|"Name" -> "rules", "Pass" -> True, "Detail" -> "planted"|>},
   "Census" -> PFBCensus[sys, slB], "Comparison" -> PFBCompareCensus[cA, PFBCensus[sys, slB]], "Message" -> ""|>;
degs = <|"Degrees" -> <|"Before" -> <|"Highest" -> 3, "Count" -> 2, "Sum" -> 9, "Terms" -> 6|>, "After" -> <|"Highest" -> 2, "Count" -> 2, "Sum" -> 7, "Terms" -> 6|>,
    "Measured" -> True, "Jobs" -> {"planted"}|>|>;
chOf[sl_] := <|"Name" -> "planted", "Key" -> None, "Kind" -> "change", "Replace" -> {2}, "H" -> {{0, 1, 0}}, "NewDefs" -> <|2 -> PFBMaster[sys, 2]["RootFree"]|>|>;
checkOf[g_, name_] := SelectFirst[g["Checks"], #["Name"] === name &, <||>];
g = PFBSimplifyGate[gate0, sys, slA, cA, Join[slB, <|"History" -> {<|"DetT" -> 1|>}|>], chOf[slB], degs];
AppendTo[tests, VerificationTest[{g["Pass"], checkOf[g, "eps structure"]["Pass"], StringContainsQ[checkOf[g, "eps structure"]["Detail"], "ut[2] (d/dt): eps^1 -> eps^0..1"],
    TrueQ[checkOf[g, "eps-form blocks"]["Pass"]]}, {False, False, True, True},
  TestID -> "gate: the check \"eps structure\" refuses the move"]];
slC = sliceOf[ReplacePart[RS, {3, 1} -> 2 + eps], 3];
gC = PFBSimplifyGate[Join[gate0, <|"Census" -> PFBCensus[sys, slC], "Comparison" -> PFBCompareCensus[cA, PFBCensus[sys, slC]]|>], sys, slA, cA,
   Join[slC, <|"History" -> {<|"DetT" -> 1|>}|>], chOf[slC], degs];
AppendTo[tests, VerificationTest[checkOf[gC, "eps structure"]["Pass"], True, TestID -> "gate: eps^0 in a row that had eps^0 passes"]];

(* ---- at the degree jobs' points: the planted tables of the phase's off-slice check ---- *)
key2 = {box, {0, 1, 0, 1}}; key3 = {box, {1, 1, 1, 1}};
ent[r_, c_, lo_, hi_] := <|"Matrix" -> 1, "Derivative" -> t, "Row" -> r, "Column" -> c, "Eps" -> {"Laurent", lo, hi}|>;
tabOf[e2_, e3_] := <|"Sectors" -> <|key2 -> <|"Rows" -> {2}, "Entries" -> e2|>, key3 -> <|"Rows" -> {3}, "Entries" -> e3|>|>|>;
before = tabOf[{ent[2, 2, 1, 1]}, {ent[3, 1, 1, 1], ent[3, 3, 0, 1]}];
off = PoleFreeBasis`Simplify`Private`offSliceCheck;
oBad = off[before, tabOf[{ent[2, 2, 1, 1], ent[2, 1, 0, 0]}, {ent[3, 1, 1, 1], ent[3, 3, 0, 1]}], {key2, key3}];
oOK = off[before, tabOf[{ent[2, 2, 1, 1], ent[2, 1, 1, 1]}, {ent[3, 1, 0, 1], ent[3, 3, 0, 1]}], {key2, key3}];
AppendTo[tests, VerificationTest[{oBad["Pass"], StringContainsQ[StringRiffle[oBad["Bad"]], "ut[2]"], oOK["Pass"]}, {False, True, True},
  TestID -> "away from the slice: a row whose eps structure gets worse is refused; eps^1 in an eps-form row and eps^0 in a row with eps^0 pass"]];

report = TestReport[tests];
Do[With[{r = report["TestResults"][id]},
    Print[If[r["Outcome"] === "Success", "PASS ", "FAIL "], r["TestID"], If[r["Outcome"] === "Success", "",
      "\n     got " <> ToString[Short[r["ActualOutput"], 3], InputForm] <> "\n     expected " <> ToString[Short[r["ExpectedOutput"], 3], InputForm]]]],
  {id, Keys[report["TestResults"]]}];
Print[report["TestsSucceededCount"], " passed, ", report["TestsFailedCount"], " failed, ", Round[report["TimeElapsed"], 0.1]];
Quiet[DeleteDirectory[tmp, DeleteContents -> True]];
Exit[If[report["AllTestsSucceeded"], 0, 1]];
