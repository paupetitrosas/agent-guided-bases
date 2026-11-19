#!/usr/bin/env wolframscript
(* Extra points are new points. The gate confirms fitted coefficients at reduction points away from the slice: a
   reduction at the slice point, or a second one at a point already checked, confirms nothing new. It is ignored and
   reported (PFBDistinctPoints), by PFBVerifyAtPoints and PFBTryChange.
   Planted data: the one-loop massless box family of the maximal-cut-basis examples with four masters, the two bubbles
   (labels 1 and 2), s times the triangle (label 3) and s t times the box (label 4), one derivative (d/dt). A change
   is planted as new masters J' = N J with a pole-free target DE R': the old slice is N^-1 R' N, and a candidate integral
   reduces to N[[m]] at every point (the planted DE is the same at every point; only the point differs). The change: a
   fitted one (rung 3) whose triangle carries 1/(1 - 2 eps) towards the s-bubble. No IBP reduction, no FiniteFlow.
   usage: bin/ws tests/extra_points.wls        exit code 0 when every test passes *)
Get[FileNameJoin[{ParentDirectory[DirectoryName[$InputFileName]], "lib", "PoleFreeBasis.wl"}]];
$PFBVerbose = False;
boxFile = FileNameJoin[{ParentDirectory[ParentDirectory[DirectoryName[$InputFileName]]], "maximal-cut-basis", "examples", "box-one-loop", "family.wl"}];
tmp = CreateDirectory[];
Put[{j[box, 1, 0, 1, 0], j[box, 0, 1, 0, 1], s j[box, 1, 1, 1, 0], s t j[box, 1, 1, 1, 1]}, FileNameJoin[{tmp, "planted.m"}]];
Put[<|"Name" -> "planted", "Families" -> {<|"Name" -> "box", "Family" -> boxFile, "Masters" -> "planted.m"|>}|>, FileNameJoin[{tmp, "planted.wl"}]];
sys = PFBReadSystem[FileNameJoin[{tmp, "planted.wl"}]];
keyT = {box, {1, 1, 1, 0}};
P = {s -> 1, t -> 3/7}; P2 = {s -> 1, t -> 5/11}; P3 = {s -> 1, t -> 2/13};
slice[R_] := <|"R" -> {R}, "Derivatives" -> {t}, "Point" -> P, "Labels" -> {1, 2, 3, 4}, "Index" -> <|1 -> 1, 2 -> 2, 3 -> 3, 4 -> 4|>, "History" -> {}|>;
checkOf[g_, name_] := SelectFirst[g["Checks"], #["Name"] === name &, <||>];
failing[g_] := #["Name"] & /@ Select[g["Checks"], ! #["Pass"] &];
g = 1 - 2 eps;
Rp = {{-eps, 0, 0, 0}, {0, -2 eps, 0, 0}, {eps, 0, -2 eps, 0}, {eps + eps^2, 1 + eps, eps, -1 - 2 eps}};
oldOf[Rnew_, N_] := Together[Inverse[N] . Rnew . N];
(* a reduction at a point: candidates {integral, coefficient, row of N}; coefficient * integral = N-row . old *)
redOf[Rold_, cands_List, pt_] := <|"Masters" -> ut /@ {1, 2, 3, 4}, "Point" -> pt, "Invariants" -> {t}, "Focus" -> {1, 2, 3, 4}, "Dm" -> {Rold}, "Pool" -> cands[[All, 1]],
   "Rp" -> Table[c[[3]]/(c[[2]] /. pt), {c, cands}],
   "dRp" -> {Table[With[{c0 = c[[2]] /. pt, dc = D[c[[2]], t] /. pt}, Together[((c[[3]] . Rold) - dc c[[3]]/c0)/c0]], {c, cands}]}|>;
cand = j[box, 1, 1, 2, 0];
newRun[Rold_, name_] := Module[{dir = CreateDirectory[FileNameJoin[{tmp, name}]], st, sl = slice[Rold]},
  st = <|"Run" -> "none", "Created" -> PFBTimeStamp[], "Slices" -> {}, "Current" -> None, "Censuses" -> {}, "Accepted" -> {}, "Pending" -> {},
    "Rejected" -> {}, "Flagged" -> <||>, "Approval" -> False, "Regenerated" -> False|>;
  st = PFBStoreSlice[dir, st, sl, PFBCensus[sys, sl], "start"];
  <|"Run" -> <|"MaxEpsDegree" -> 2|>, "System" -> sys, "Dir" -> dir, "State" -> st|>];

(* the fitted change: I_3 = J_3 - lam I_1, the honest J_3 a dotted triangle; det T = 1 *)
NT = {{1, 0, 0, 0}, {0, 1, 0, 0}, {1/g, 0, 1, 0}, {0, 0, 0, 1}}; RoT = oldOf[Rp, NT];
redT[pt_] := redOf[RoT, {{cand, s^2, NT[[3]]}}, pt];
tryT[reds_, name_] := PFBTryChange[newRun[RoT, name], keyT, <|3 -> s^2 cand|>, <|"Rung" -> 3, "Provenance" -> "planted"|>, <|"Reds" -> reds|>];

tests = {
  VerificationTest[With[{d = PFBDistinctPoints[{redT[P], redT[P2], redT[{t -> 5/11, s -> 1}], redT[P3]}, {t -> 3/7, s -> 1}]},
      {Lookup[d["Reds"], "Point"], d["Ignored"][[All, 1]], StringStartsQ[#, {"the slice point", "the point of an earlier reduction"}] & /@ d["Ignored"][[All, 2]]}],
    {{P2, P3}, {P, {t -> 5/11, s -> 1}}, {True, True}}, TestID -> "PFBDistinctPoints: the slice point and a repeated point are ignored, whatever the order of the rules"],
  VerificationTest[With[{v = PFBVerifyAtPoints[sys, {redT[P], redT[P2], redT[P2]}, keyT, <|3 -> s^2 cand|>, <||>, <|"SlicePoint" -> P|>]},
      {v["Pass"], v["Points"], Length[v["Ignored"]], v["Detail"][[All, 1]]}],
    {True, 1, 2, {P2}}, TestID -> "PFBVerifyAtPoints: one extra point counted, the slice point and the repeat ignored"],
  VerificationTest[PFBVerifyAtPoints[sys, {redT[P]}, keyT, <|3 -> s^2 cand|>, <||>, <|"SlicePoint" -> P|>]["Pass"], False,
    TestID -> "PFBVerifyAtPoints: the slice point alone is no check"]
};

(* PFBTryChange, fitted: the slice point three times is no verification; two new points are *)
rT1 = tryT[{redT[P], redT[P], redT[P]}, "fitted-slice"];
rT2 = tryT[{redT[P], redT[P2], redT[P2]}, "fitted-repeat"];
rT3 = tryT[{redT[P], redT[P2], redT[P3]}, "fitted-new"];
AppendTo[tests, VerificationTest[{rT1["Status"], failing[rT1["Gate"]], rT1["Record"]["PointsVerified"], StringContainsQ[checkOf[rT1["Gate"], "points"]["Detail"], "2 reductions ignored"]},
  {"rejected", {"points"}, 0, True}, TestID -> "PFBTryChange: reductions at the slice point do not confirm a fit, and the gate says why"]];
AppendTo[tests, VerificationTest[{rT2["Status"], rT2["Record"]["PointsVerified"], StringContainsQ[checkOf[rT2["Gate"], "points"]["Detail"], "the point of an earlier reduction"]},
  {"rejected", 1, True}, TestID -> "PFBTryChange: a point given twice counts once"]];
AppendTo[tests, VerificationTest[{rT3["Status"], rT3["Record"]["PointsVerified"], rT3["Record"]["Verification"]["Ignored"]}, {"accepted", 2, {}},
  TestID -> "PFBTryChange: two new points confirm the fit"]];
(* a change that names no rung is not known to be exact: it counts as fitted, and needs its extra points *)
rT4 = PFBTryChange[newRun[RoT, "no-rung"], keyT, <|3 -> s^2 cand|>, <|"Provenance" -> "planted"|>, <|"Reds" -> {redT[P]}|>];
AppendTo[tests, VerificationTest[{rT4["Status"], failing[rT4["Gate"]], rT4["Record"]["Fitted"]}, {"rejected", {"points"}, True},
  TestID -> "PFBTryChange: a change that names no rung counts as fitted"]];
(* a third reduction whose pool lacks the new master's integral cannot be checked: two verified points do not pass over it *)
rT5 = tryT[{redT[P], redT[P2], redT[P3], Join[redT[{s -> 1, t -> 7/17}], <|"Pool" -> {j[box, 1, 1, 1, 0]}|>]}, "fitted-unchecked"];
AppendTo[tests, VerificationTest[{rT5["Status"], failing[rT5["Gate"]], rT5["Record"]["PointsVerified"], StringContainsQ[checkOf[rT5["Gate"], "points"]["Detail"], "1 could not be checked"]},
  {"rejected", {"points"}, 2, True}, TestID -> "PFBTryChange: a point that could not be checked does not pass, whatever the others confirm"]];

(* a calibration compares the focus rows of the reduction with the slice: when the reduction has focus rows and none
   is a row of the slice (here a slice of the two bubbles, a reduction whose focus is the triangle), it is not exact *)
bubbles = <|"R" -> {RoT[[{1, 2}, {1, 2}]]}, "Derivatives" -> {t}, "Point" -> P, "Labels" -> {1, 2}, "Index" -> <|1 -> 1, 2 -> 2|>, "History" -> {}|>;
AppendTo[tests, VerificationTest[{PFBCalibrate[slice[RoT], redT[P]]["Status"], PFBCalibrate[bubbles, Join[redT[P], <|"Focus" -> {3}, "Dm" -> {RoT[[{3}]]}|>]]["Status"]},
  {"exact", "undetermined"}, TestID -> "PFBCalibrate: a reduction with no focus row in the slice compares nothing, and is not exact"]];

report = TestReport[tests];
Do[With[{r = report["TestResults"][id]},
    Print[If[r["Outcome"] === "Success", "PASS ", "FAIL "], r["TestID"], If[r["Outcome"] === "Success", "",
      "\n     got " <> ToString[Short[r["ActualOutput"], 3], InputForm] <> "\n     expected " <> ToString[Short[r["ExpectedOutput"], 3], InputForm]]]],
  {id, Keys[report["TestResults"]]}];
Print[report["TestsSucceededCount"], " passed, ", report["TestsFailedCount"], " failed, ", Round[report["TimeElapsed"], 0.1]];
DeleteDirectory[tmp, DeleteContents -> True];
Exit[If[report["AllTestsSucceeded"], 0, 1]];
