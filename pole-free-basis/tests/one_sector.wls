#!/usr/bin/env wolframscript
(* A change of the masters of one sector at a time: the gate judges the rows of the sector whose key it is given, and
   the extra points reduce that sector's subtree, so a new master of another sector would be checked by neither.
   Planted, without FiniteFlow or IBP: the one-loop box of the maximal-cut-basis examples (4 masters) with a hidden
   weight on the triangle, I_3 = w J_3, w = 1 + 4 eps, and planted reductions at three points: PFBTryChange with the
   triangle's key and new masters for the triangle and the s-bubble is not tried, and nothing is recorded; the
   triangle's change alone is accepted.
   usage: bin/ws tests/one_sector.wls        exit code 0 when every test passes *)
Get[FileNameJoin[{ParentDirectory[DirectoryName[$InputFileName]], "lib", "PoleFreeBasis.wl"}]];
$PFBVerbose = False;
examples = FileNameJoin[{ParentDirectory[$PFBRoot], "maximal-cut-basis", "examples"}];
tmp = CreateDirectory[];
tests = {};
w = 1 + 4 eps;

(* ---- the box: a change of two sectors through the gate of the pole-free work ---- *)
Put[{j[box, 1, 0, 1, 0], j[box, 0, 1, 0, 1], s j[box, 1, 1, 1, 0], s t j[box, 1, 1, 1, 1]}, FileNameJoin[{tmp, "box.m"}]];
Put[<|"Name" -> "planted", "Families" -> {<|"Name" -> "box", "Family" -> FileNameJoin[{examples, "box-one-loop", "family.wl"}], "Masters" -> "box.m"|>}|>,
  FileNameJoin[{tmp, "box.wl"}]];
sysB = PFBReadSystem[FileNameJoin[{tmp, "box.wl"}]];
keyT = {box, {1, 1, 1, 0}};
P = {s -> 1, t -> 3/7}; P2 = {s -> 1, t -> 5/11}; P3 = {s -> 1, t -> 2/13};
slice[R_] := <|"R" -> {R}, "Derivatives" -> {t}, "Point" -> P, "Labels" -> {1, 2, 3, 4}, "Index" -> <|1 -> 1, 2 -> 2, 3 -> 3, 4 -> 4|>, "History" -> {}|>;
(* the honest basis's DE; the old basis I = N J carries w on the triangle *)
Rp = {{-eps, 0, 0, 0}, {0, -2 eps, 0, 0}, {eps, 0, -2 eps, 0}, {eps + eps^2, 1 + eps, eps, -1 - 2 eps}};
NN = DiagonalMatrix[{w, 1, 1/w, 1}];
Rold = Together[Inverse[NN] . Rp . NN];
(* candidates {integral, its prefactor, its vector on the old masters}: J_3 for the triangle (det 1/w), and an s-bubble
   integral equal to w I_1 (det w) *)
cand3 = j[box, 1, 1, 2, 0]; candB = j[box, 2, 0, 1, 0];
cands = {{cand3, s^2, NN[[3]]}, {candB, s, NN[[1]]}};
redOf[pt_] := <|"Masters" -> ut /@ {1, 2, 3, 4}, "Point" -> pt, "Invariants" -> {t}, "Focus" -> {1, 2, 3, 4}, "Dm" -> {Rold}, "Pool" -> cands[[All, 1]],
   "Rp" -> Table[c[[3]]/(c[[2]] /. pt), {c, cands}],
   "dRp" -> {Table[With[{c0 = c[[2]] /. pt, dc = D[c[[2]], t] /. pt}, Together[((c[[3]] . Rold) - dc c[[3]]/c0)/c0]], {c, cands}]}|>;
newRunB[name_] := Module[{dir = CreateDirectory[FileNameJoin[{tmp, name}]], st, sl = slice[Rold]},
  st = <|"Run" -> "none", "Created" -> PFBTimeStamp[], "Slices" -> {}, "Current" -> None, "Censuses" -> {}, "Accepted" -> {}, "Pending" -> {},
    "Rejected" -> {}, "Flagged" -> <||>, "Approval" -> False, "Regenerated" -> False|>;
  st = PFBStoreSlice[dir, st, sl, PFBCensus[sysB, sl], "start"];
  <|"Run" -> <|"MaxEpsDegree" -> 2|>, "System" -> sysB, "Dir" -> dir, "State" -> st|>];
opts = <|"Reds" -> (redOf /@ {P, P2, P3})|>;

both = PFBTryChange[newRunB["both"], keyT, <|3 -> s^2 cand3, 1 -> s candB|>, <|"Rung" -> 8, "Provenance" -> "planted"|>, opts];
AppendTo[tests, VerificationTest[{both["Status"], AllTrue[{"masters of its own sector only", "{ut[1]} are not masters of"}, StringContainsQ[both["Message"], #] &],
    Length[both["Context"]["State"]["Accepted"]] + Length[both["Context"]["State"]["Pending"]] + Length[both["Context"]["State"]["Rejected"]]},
  {"not tried", True, 0}, TestID -> "a change with new masters of two sectors is not tried, and nothing is recorded"]];
onlyT = PFBTryChange[newRunB["onlyT"], keyT, <|3 -> s^2 cand3|>, <|"Rung" -> 8, "Provenance" -> "planted"|>, opts];
AppendTo[tests, VerificationTest[onlyT["Status"], "accepted", TestID -> "the triangle's change alone is accepted"]];

report = TestReport[tests];
Do[With[{r = report["TestResults"][id]},
    Print[If[r["Outcome"] === "Success", "PASS ", "FAIL "], r["TestID"], If[r["Outcome"] === "Success", "",
      "\n     got " <> ToString[Short[r["ActualOutput"], 3], InputForm] <> "\n     expected " <> ToString[Short[r["ExpectedOutput"], 3], InputForm]]]],
  {id, Keys[report["TestResults"]]}];
Print[report["TestsSucceededCount"], " passed, ", report["TestsFailedCount"], " failed, ", Round[report["TimeElapsed"], 0.1]];
Quiet[DeleteDirectory[tmp, DeleteContents -> True]];
Exit[If[report["AllTestsSucceeded"], 0, 1]];
