#!/usr/bin/env wolframscript
(* The cap on the power of eps ("MaxEpsDegree", default 2): entries above eps^cap are bad entries, fixed like finite poles;
   no change may raise an entry above the cap (an entry above it before may only not rise), and a row with negative
   powers of eps calls for a new maximal-cut basis. Planted data: the one-loop massless box of the
   maximal-cut-basis examples (masters: the two bubbles and s t times the box), one derivative (d/dt), and slices and
   reductions built so that the answer is known. A change is planted as new masters J' = M J: with a target DE R' in
   the new basis, the old slice is M^-1 R' M, and a candidate integral reduces to M[[3]] with the derivative R'[[3]].M.
   Two candidates replace the box: one whose rows stay at eps^2, one that puts eps^3 into the box row (and a third, for
   the scans, that leaves 1/eps there). A second planted system (the massive bubble family, two masters in the bubble
   sector) serves the source test, with negative powers of eps as a pole at eps = 0. Checked: the census,
   PFBDegreeViolations, the source test, the gate, the rescale search, the slot scan, the checks at extra points, the
   completion solver and PFBTryChange. No IBP reduction, no FiniteFlow.
   usage: bin/ws tests/eps_degree.wls        exit code 0 when every test passes *)
Get[FileNameJoin[{ParentDirectory[DirectoryName[$InputFileName]], "lib", "PoleFreeBasis.wl"}]];
$PFBVerbose = False;
boxFile = FileNameJoin[{ParentDirectory[ParentDirectory[DirectoryName[$InputFileName]]], "maximal-cut-basis", "examples", "box-one-loop", "family.wl"}];
tmp = CreateDirectory[];
loadSystem[masters_, name_] := (Put[masters, FileNameJoin[{tmp, name <> ".m"}]];
  Put[<|"Name" -> name, "Families" -> {<|"Name" -> "box", "Family" -> boxFile, "Masters" -> name <> ".m"|>}|>, FileNameJoin[{tmp, name <> ".wl"}]];
  PFBReadSystem[FileNameJoin[{tmp, name <> ".wl"}]]);
sys = loadSystem[{j[box, 1, 0, 1, 0], j[box, 0, 1, 0, 1], s t j[box, 1, 1, 1, 1]}, "planted"];
key = {box, {1, 1, 1, 1}};
P = {s -> 1, t -> 3/7};
slice[R_] := <|"R" -> {R}, "Derivatives" -> {t}, "Point" -> P, "Labels" -> {1, 2, 3}, "Index" -> <|1 -> 1, 2 -> 2, 3 -> 3|>, "History" -> {}|>;
checkOf[g_, name_] := SelectFirst[g["Checks"], #["Name"] === name &];
failing[g_] := #["Name"] & /@ Select[g["Checks"], ! #["Pass"] &];

(* the target DEs in the new basis, pole-free: the box row at eps^2 at most, or with eps^3 in (3, 1). Entry (1, 2) is at
   eps^3 in both, before and after: above the cap, untouched *)
Rgood = {{-eps/3, eps^3, 0}, {eps, -2 eps, 0}, {eps + eps^2, 1 + eps, -1 - 2 eps}};
Rhigh = ReplacePart[Rgood, {3, 1} -> eps + 2 eps^3];
(* the box replaced by a dotted box whose reduction carries lam = (2 + eps)/(1 - 2 eps) on the t-bubble: the old box row
   has finite poles, which the change removes *)
lam = (2 + eps)/(1 - 2 eps);
M = {{1, 0, 0}, {0, 1, 0}, {0, lam, 1}};
Rold = Together[Inverse[M] . Rgood . M];
oldSl = slice[Rold]; c0 = PFBCensus[sys, oldSl];
change[Rp_, int_] := <|"Name" -> "planted", "Key" -> key, "Kind" -> "change", "Replace" -> {3}, "H" -> {M[[3]]},
   "G" -> {{Together[Rp[[3]] . M]}}, "NewDefs" -> <|3 -> s t^2 int|>|>;
good = change[Rgood, j[box, 1, 1, 1, 2]]; high = change[Rhigh, j[box, 1, 1, 2, 1]];
gate[ch_, opts_ : <||>] := PFBGate[sys, oldSl, c0, PFBApplyChange[oldSl, ch], ch, opts];

(* a reduction at the slice point that holds the candidates: Rp is each pool integral on the masters, dRp its d/dt. The
   third is the good box plus U2/eps: its row gets 1/eps in the column of U2 *)
M3 = {0, lam + 1/eps, 1};
redAt[pt_] := With[{t0 = t /. pt}, <|"Masters" -> {ut[1], ut[2], ut[3]}, "Point" -> pt, "Invariants" -> {t}, "Focus" -> {1, 2, 3}, "Dm" -> {Rold},
   "Pool" -> {j[box, 1, 0, 1, 0], j[box, 0, 1, 0, 1], j[box, 1, 1, 1, 1], j[box, 1, 1, 1, 2], j[box, 1, 1, 2, 1], j[box, 2, 1, 1, 1]},
   "Rp" -> {{1, 0, 0}, {0, 1, 0}, {0, 0, 1/t0}, M[[3]]/t0^2, M[[3]]/t0^2, M3/t0^2},
   "dRp" -> {{Rold[[1]], Rold[[2]], (Rold[[3]] - {0, 0, 1/t0})/t0,
      Together[(good["G"][[1, 1]] - 2 M[[3]]/t0)/t0^2], Together[(high["G"][[1, 1]] - 2 M[[3]]/t0)/t0^2], Together[(M3 . Rold - 2 M3/t0)/t0^2]}}|>];
(* the same planted DE at two extra points *)
red = redAt[P]; P2 = {s -> 1, t -> 5/11}; P3 = {s -> 1, t -> 2/13};
cal = PFBCalibrate[oldSl, red];
sets = {<|3 -> s t^2 j[box, 1, 1, 2, 1]|>, <|3 -> s t^2 j[box, 1, 1, 1, 2]|>};
ver[defs_, opts_ : <||>] := PFBVerifyAtPoints[sys, {red}, key, defs, <||>, opts];

tests = {
  VerificationTest[sys =!= $Failed && Length[PFBMasters[sys]] == 3, True, TestID -> "the planted system loads"],
  VerificationTest[$PFBMaxEpsDegree, 2, TestID -> "the cap is eps^2 by default"],
  (* census: the highest power of eps and the entries above the cap, which make their sector bad *)
  VerificationTest[With[{c = PFBCensus[sys, slice[Rgood]]}, {c["MaxDegree"], c["HighDegree"], c["DegreeCap"], c["BadEntries"], c["BadSectors"],
      Lookup[c["Sectors"][{box, {1, 0, 1, 0}}], {"Issues", "HighRows", "HighColumns"}], c["Next"]}],
    {3, {{1, 1, 2, 3}}, 2, {}, {{box, {1, 0, 1, 0}}}, {{"above eps^2"}, {1}, {2}}, {box, {1, 0, 1, 0}}}, TestID -> "census: an entry above the cap makes its sector bad"],
  VerificationTest[PFBCensus[sys, slice[Rgood], <|"MaxEpsDegree" -> 3|>]["HighDegree"], {}, TestID -> "census: nothing above a cap of 3"],
  VerificationTest[StringContainsQ[PFBCensusText[PFBCensus[sys, slice[Rgood]]], {"highest power of eps 3 (1 entries above the cap eps^2)", "box/j1010 [above eps^2]"}],
    True, TestID -> "census text"],
  VerificationTest[With[{c = PFBCensus[sys, slice[ReplacePart[Rgood, {3, 1} -> 1/eps]]]}, {Lookup[c["Sectors"][key], {"Issues", "EpsZeroRows"}], MemberQ[c["BadSectors"], key]}],
    {{{"negative powers of eps"}, {3}}, True}, TestID -> "census: a negative power of eps makes its sector bad"],
  VerificationTest[With[{c = PFBCensus[sys, slice[Rgood]]}, PFBSectorStatus[sys, <|"Accepted" -> {}, "Flagged" -> <||>|>, c, #] & /@ {{box, {1, 0, 1, 0}}, key}],
    {"open", "pole-free"}, TestID -> "status: a sector above the cap is not done"],
  VerificationTest[{PFBEpsDegree[0], PFBEpsDegree[eps^-1 + 2 eps^2], PFBEpsDegree[eps/(1 - 2 eps)], PFBEpsDegree[(eps^3 - eps)/eps^2]}, {None, 2, None, 1},
    TestID -> "PFBEpsDegree"],
  (* PFBDegreeViolations: rises above the cap; an entry above the cap before may keep its power, not raise it *)
  VerificationTest[PFBDegreeViolations[slice[Rgood], slice[ReplacePart[Rgood, {3, 2} -> eps^3]], 2], {{1, 3, 2, 3, 1}},
    TestID -> "violations: a rise from eps^1 to eps^3"],
  VerificationTest[PFBDegreeViolations[slice[Rgood], slice[ReplacePart[Rgood, {1, 2} -> 5 eps^3 + eps]], 2], {},
    TestID -> "violations: an entry at eps^3 before may stay there"],
  VerificationTest[PFBDegreeViolations[slice[Rgood], slice[ReplacePart[Rgood, {1, 2} -> eps^4]], 2], {{1, 1, 2, 4, 3}},
    TestID -> "violations: an entry at eps^3 before may not rise to eps^4"],
  (* entries with finite poles: their power is the degree at eps -> infinity, before and after *)
  VerificationTest[PFBDegreeViolations[slice[ReplacePart[Rgood, {3, 2} -> eps^3/(1 - 2 eps)]], slice[ReplacePart[Rgood, {3, 2} -> eps^3]], 2], {{1, 3, 2, 3, 2}},
    TestID -> "violations: a pole fix may not raise the entry above the cap at eps -> infinity"],
  VerificationTest[PFBDegreeViolations[slice[ReplacePart[Rgood, {3, 2} -> eps^4/(1 - 2 eps)]], slice[ReplacePart[Rgood, {3, 2} -> eps^3 + 1]], 2], {},
    TestID -> "violations: a pole fix may leave the power the entry had with its pole"],
  VerificationTest[{PFBDegreeViolations[slice[Rgood], slice[ReplacePart[Rgood, {3, 2} -> eps^5/(1 + eps)]], 2], PFBDegreeViolations[slice[Rgood], slice[ReplacePart[Rgood, {3, 2} -> eps^3/(1 + eps)]], 2]},
    {{{1, 3, 2, 4, 1}}, {}}, TestID -> "violations: a new pole entry is judged at eps -> infinity too"],
  VerificationTest[{PFBDegreeViolations[slice[Rgood], slice[ReplacePart[Rgood, {3, 2} -> eps^3]], 3],
      PFBDegreeViolations[slice[Rgood], slice[ReplacePart[Rgood, {3, 2} -> eps^9]], Infinity]}, {{}, {}}, TestID -> "violations: a higher cap, and no cap"],
  VerificationTest[PFBDegreeViolations[slice[Rgood], slice[ReplacePart[Rgood, {{3, 2} -> eps^3, {2, 1} -> eps^3}]], 2, <|"Rows" -> {3}|>], {{1, 3, 2, 3, 1}},
    TestID -> "violations: only the rows asked for"],
  (* the gate *)
  VerificationTest[{c0["BadRows"], c0["MaxDegree"]}, {{3}, 3}, TestID -> "the planted old slice: finite poles in the box row"],
  (* a change that only brings an entry above the cap down is progress: lam2 = -2 eps^2, an honest eps-monomial
     correction, puts eps^3 into (3, 1) of the old slice, without a pole *)
  VerificationTest[With[{M2 = {{1, 0, 0}, {0, 1, 0}, {0, -2 eps^2, 1}}}, Module[{sl2 = slice[Together[Inverse[M2] . Rgood . M2]], ch, g},
      ch = <|"Name" -> "lower", "Key" -> key, "Kind" -> "change", "Replace" -> {3}, "H" -> {M2[[3]]}, "G" -> {{Together[Rgood[[3]] . M2]}},
        "NewDefs" -> <|3 -> ut[3] - 2 eps^2 ut[2]|>|>;
      g = PFBGate[sys, sl2, PFBCensus[sys, sl2], PFBApplyChange[sl2, ch], ch];
      {Lookup[PFBCensus[sys, sl2], {"BadEntries", "HighDegree"}], g["Pass"], g["Comparison"]["RemovedHigh"], StringContainsQ[checkOf[g, "census"]["Detail"], "entries above eps^2 2 -> 1"]}]],
    {{{}, {{1, 1, 2, 3}, {1, 3, 1, 3}}}, True, {{1, 3, 1}}, True}, TestID -> "gate: lowering an entry above the cap is progress"],
  VerificationTest[{PFBApplyChange[oldSl, good]["R"] === {Rgood}, PFBApplyChange[oldSl, high]["R"] === {Rhigh}}, {True, True},
    TestID -> "the planted changes give the target DEs"],
  VerificationTest[With[{g = gate[good]}, {g["Pass"], checkOf[g, "degree"]["Pass"]}], {True, True}, TestID -> "gate: a change that stays at eps^2 passes"],
  VerificationTest[With[{g = gate[high]}, {g["Pass"], failing[g]}], {False, {"degree"}}, TestID -> "gate: an entry raised to eps^3 is refused, by the degree check alone"],
  VerificationTest[StringContainsQ[checkOf[gate[high], "degree"]["Detail"], "1 entries rise above eps^2, up to eps^3, in rows {ut[3]}"], True,
    TestID -> "gate: the refusal names the entries"],
  VerificationTest[{gate[high, <|"MaxEpsDegree" -> 3|>]["Pass"], gate[high, <|"MaxEpsDegree" -> Infinity|>]["Pass"]}, {True, True},
    TestID -> "gate: a cap of 3, or none, lets it pass"],
  VerificationTest[Block[{$PFBMaxEpsDegree = 3}, gate[high]["Pass"]], True, TestID -> "gate: the default cap is $PFBMaxEpsDegree"],
  (* a rescale is judged too: eps^-1 on the t-bubble raises its column, and entry (1, 2), at eps^3 already, to eps^4 *)
  VerificationTest[With[{sl0 = slice[Rgood]}, Module[{sl1 = PFBRescaleSlice[sl0, <|2 -> -1|>]},
      checkOf[PFBGate[sys, sl0, PFBCensus[sys, sl0], sl1, <|"Kind" -> "rescale", "Replace" -> {2}, "Shifts" -> <|2 -> -1|>, "Name" -> "rescale"|>], "degree"]["Pass"]]],
    False, TestID -> "gate: a rescale that raises an entry above the cap is refused"],
  (* the scans rank by the cap, then by the lowest power: the eps^3 candidate is listed first in sets, second in the result *)
  VerificationTest[cal["Status"], "exact", TestID -> "the planted reduction calibrates"],
  VerificationTest[Lookup[#, {"bad", "over", "high", "deg"}] & /@ PFBScanSets[sys, oldSl, red, cal, key, sets, <|"Census" -> c0, "FullCensus" -> True|>]["Results"],
    {{0, 0, 0, 2}, {0, 1, 1, 3}}, TestID -> "scan: the set above the cap is counted and ranked last"],
  VerificationTest[Lookup[#, {"over", "deg"}] & /@ PFBScanSets[sys, oldSl, red, cal, key, sets, <|"Census" -> c0, "MaxEpsDegree" -> Infinity|>]["Results"],
    {{0, 2}, {0, 3}}, TestID -> "scan: without a cap, the lowest power still wins a tie"],
  VerificationTest[Lookup[#, {"bad", "over", "zero", "high"}] & /@ PFBScanSets[sys, oldSl, red, cal, key, Append[sets, <|3 -> s t^2 j[box, 2, 1, 1, 1]|>],
      <|"Census" -> c0, "FullCensus" -> True|>]["Results"],
    {{0, 0, 0, 0}, {0, 0, 1, 0}, {0, 1, 0, 1}}, TestID -> "scan: a set that leaves 1/eps in the sector rows is counted, after one that raises an entry"],
  (* the extra points: the same reduction stands in for a point the fit did not use *)
  VerificationTest[With[{v = ver[sets[[1]]]}, {v["Pass"], v["Points"], v["Detail"][[1, 2]]}], {False, 0, "sector rows pole-free, but 1 entries above eps^2 (up to eps^3)"},
    TestID -> "extra points: an entry above the cap fails the point"],
  VerificationTest[{ver[sets[[1]], <|"DegreeAllowed" -> <|{t, 3, 1} -> 3|>|>]["Pass"], ver[sets[[1]], <|"MaxEpsDegree" -> 3|>]["Pass"], ver[sets[[2]]]["Pass"]},
    {True, True, True}, TestID -> "extra points: the slice's own power, a higher cap, a candidate at eps^2"]
};

(* rung 1: the rescale search keeps every entry at or below the cap. Entry (2, 1) has 1/eps: U2 needs eps^1 more than U1;
   (1, 3) at eps^0 keeps U3 at or below U1; so (2, 3), at eps^2, ends at eps^3 or higher *)
Rres = {{0, 0, 1}, {1/eps + 1, 0, eps^2}, {0, 0, 0}};
Rres3 = ReplacePart[Rres, {2, 3} -> eps^3];
AppendTo[tests, VerificationTest[{PFBRescaleSearch[sys, slice[Rres]]["Feasible"], Lookup[PFBRescaleSearch[sys, slice[Rres], <|"MaxEpsDegree" -> 3|>], {"Feasible", "Shifts"}],
    PFBRescaleSearch[sys, slice[Rres], <|"MaxEpsDegree" -> Infinity|>]["Feasible"]}, {False, {True, <|2 -> 1|>}, True},
  TestID -> "rescale search: infeasible within eps^2, feasible with a cap of 3 or none"]];
AppendTo[tests, VerificationTest[{PFBRescaleSearch[sys, slice[Rres3]]["Feasible"], PFBRescaleSearch[sys, slice[Rres3], <|"MaxEpsDegree" -> Infinity|>]["Feasible"]},
  {False, True}, TestID -> "rescale search: an entry above the cap may not rise"]];
AppendTo[tests, VerificationTest[{PFBRescaleSearch[sys, slice[Rres], <|"Upper" -> {Infinity}|>]["Feasible"],
    PFBRescaleSearch[sys, slice[Rres], <|"Upper" -> {Infinity}, "MaxEpsDegree" -> 3|>]["Feasible"]}, {False, True},
  TestID -> "rescale search: an explicit bound is clipped to the cap (the gate's lift of new negative powers)"]];
AppendTo[tests, VerificationTest[With[{r = PFBRescaleSearch[sys, slice[Rres]]}, {StringContainsQ[r["Message"], "within the cap eps^2"], r["MinimalCap"]}], {True, 3},
  TestID -> "rescale search: the message names the cap, and the smallest cap that would do"]];
AppendTo[tests, VerificationTest[{PFBRescaleSearch[sys, slice[Rres3]]["MinimalCap"], PFBRescaleSearch[sys, slice[{{0, 1/eps, 0}, {1/eps, 0, 0}, {0, 0, 0}}]]["MinimalCap"]},
  {4, None}, TestID -> "rescale search: the smallest cap with an entry above it, and None when the negative powers alone are inconsistent"]];
(* entries above the cap are brought down when a uniform eps^k can, to the tightest bound: eps^2 on U1 takes (3, 1) from
   eps^3 to eps^1; (3, 2) at eps^0 keeps U3 from moving down instead *)
AppendTo[tests, VerificationTest[Lookup[PFBRescaleSearch[sys, slice[{{0, 0, 0}, {0, 0, 0}, {eps^3, 1, 0}}]], {"Feasible", "Strict", "Shifts", "AboveCapLeft"}],
  {True, True, <|1 -> 2|>, 0}, TestID -> "rescale search: an entry above the cap brought down"]];
(* (1, 2) spans eps^0 to eps^3, wider than the cap: no uniform eps^k brings it down. The 1/eps of (3, 1) is still lifted,
   without raising (1, 2) *)
AppendTo[tests, VerificationTest[Lookup[PFBRescaleSearch[sys, slice[{{0, 1 + eps^3, 0}, {0, 0, 0}, {1/eps, 0, 0}}]], {"Feasible", "Strict", "Shifts", "AboveCapLeft"}],
  {True, False, <|3 -> 1|>, 1}, TestID -> "rescale search: the lift without lowering, when lowering is impossible"]];

(* entries with finite poles: the search measures them at eps -> infinity, as the gate does. Lifting the 1/eps of (3, 1)
   by eps^1 on U3 alone would take (3, 2) from eps^3/(1 - 2 eps) (eps^2 at infinity) to eps^3 at infinity *)
RresP = {{0, 0, 0}, {0, 0, 0}, {1/eps, eps^3/(1 - 2 eps), 0}};
rescaleGate[R_, sh_] := With[{sl0 = slice[R]}, PFBGate[sys, sl0, PFBCensus[sys, sl0], PFBRescaleSlice[sl0, sh], <|"Kind" -> "rescale", "Replace" -> Keys[sh], "Shifts" -> sh,
    "Name" -> "rescale"|>]];
AppendTo[tests, VerificationTest[{Lookup[PFBRescaleSearch[sys, slice[RresP], <|"Labels" -> {3}|>], {"Feasible", "MinimalCap"}],
    PFBRescaleSearch[sys, slice[RresP], <|"Labels" -> {3}, "MaxEpsDegree" -> 3|>]["Shifts"], #["Name"] & /@ Select[rescaleGate[RresP, <|3 -> 1|>]["Checks"], ! #["Pass"] &]},
  {{False, 3}, <|3 -> 1|>, {"degree"}}, TestID -> "rescale search: an entry with a finite pole may not rise above the cap at eps -> infinity, as in the gate"]];
AppendTo[tests, VerificationTest[With[{r = PFBRescaleSearch[sys, slice[RresP]]}, {r["Feasible"],
    Last[PFBEpsOrders[PFBRescaleSlice[slice[RresP], r["Shifts"]]["R"][[1, 3, 2]]]] <= 2, rescaleGate[RresP, r["Shifts"]]["Pass"]}],
  {True, True, True}, TestID -> "rescale search: with every master free, a shift the gate takes"]];

(* rung 6: the completion solver keeps the corrected rows at or below the cap. The box master is s j[box, 1, 1, 1, 1]
   here, so that singly dotted bubbles correct it with constant coefficients. w1 (one dot) removes the pole of (3, 1)
   and leaves eps + eps^3; w2 (two dots and a numerator, a heavier tier) adds eps^3 alone. Without a cap the lightest
   tier, w1 alone, wins; with eps^2 the solver needs w2 as well. *)
sysC = loadSystem[{j[box, 1, 0, 1, 0], j[box, 0, 1, 0, 1], s j[box, 1, 1, 1, 1]}, "completion"];
w1 = j[box, 2, 0, 1, 0]; w2 = j[box, 3, -1, 1, 0];
A33 = -2 eps; v1 = 1/(1 - 2 eps);
RoldC = {{-eps, 0, 0}, {0, -2 eps, 0}, {Together[eps + eps^3 - (v1 - A33)], eps, A33}};
redC = <|"Masters" -> {ut[1], ut[2], ut[3]}, "Point" -> P, "Invariants" -> {t}, "Focus" -> {1, 2, 3}, "Dm" -> {RoldC},
   "Pool" -> {j[box, 1, 0, 1, 0], j[box, 0, 1, 0, 1], j[box, 1, 1, 1, 1], w1, w2},
   "Rp" -> {{1, 0, 0}, {0, 1, 0}, {0, 0, 1}, {1, 0, 0}, {1, 0, 0}},
   "dRp" -> {{RoldC[[1]], RoldC[[2]], RoldC[[3]], {v1, 0, 0}, {eps^3 + A33, 0, 0}}}|>;
comp[opts_] := PFBCompletionSolve[sysC, {redC}, key, Join[<|"Sparsify" -> False|>, opts]];
AppendTo[tests, VerificationTest[With[{r = comp[<|"MaxEpsDegree" -> Infinity|>]}, {r["Status"], Coefficient[r["Defs"][3], {w1, w2}]}], {"solved", {1, 0}},
  TestID -> "completion: without a cap the lightest tier leaves eps^3"]];
AppendTo[tests, VerificationTest[With[{r = comp[<||>]}, {r["Status"], Coefficient[r["Defs"][3], {w1, w2}]}], {"solved", {1, -1}},
  TestID -> "completion: with eps^2 the solver removes eps^3"]];
(* without w2 nothing brings (3, 1) within the cap; it has eps^3 at eps -> infinity with its pole, so the fallback removes
   the pole and keeps that power, as the gate allows *)
AppendTo[tests, VerificationTest[With[{r = comp[<|"PoolSelect" -> (# =!= w2 &)|>]}, {r["Status"], Coefficient[r["Defs"][3], w1], r["AboveCapKept"]}], {"solved", 1, True},
  TestID -> "completion: without w2, the pole removed and the power it had with it kept"]];
(* a sector whose only bad entry is (3, 1) at eps^3: w2 brings it down; without w2 nothing does, and no correction is
   returned *)
compWith[R_, opts_] := PFBCompletionSolve[sysC, {Join[redC, <|"Dm" -> {R}, "dRp" -> {{R[[1]], R[[2]], R[[3]], {v1, 0, 0}, {eps^3 + A33, 0, 0}}}|>]}, key,
  Join[<|"Sparsify" -> False|>, opts]];
RhighC = ReplacePart[RoldC, {3, 1} -> eps + eps^3];
AppendTo[tests, VerificationTest[With[{r = compWith[RhighC, <||>]}, {r["Status"], Coefficient[r["Defs"][3], {w1, w2}], r["AboveCapKept"]}], {"solved", {0, -1}, False},
  TestID -> "completion: an entry above the cap brought down, no pole involved"]];
AppendTo[tests, VerificationTest[compWith[RhighC, <|"PoolSelect" -> (# =!= w2 &)|>]["Status"], "no solution", TestID -> "completion: nothing to bring it down"]];
(* (3, 1) has the pole, (3, 2) is at eps^3 and no pool integral reaches column 2: the poles are removed, eps^3 is kept and
   said so *)
AppendTo[tests, VerificationTest[With[{r = compWith[ReplacePart[RoldC, {{3, 1} -> Together[eps - (v1 - A33)], {3, 2} -> eps^3}], <|"PoolSelect" -> (# =!= w2 &)|>]},
    {r["Status"], Coefficient[r["Defs"][3], w1], r["AboveCapKept"]}],
  {"solved", 1, True}, TestID -> "completion: the poles alone when an entry above the cap cannot come down"]];

(* the source test, on a sector of two masters: the massive bubble family, U1 the tadpole, U2 and U3 in the bubble
   sector. (3, 1) at eps^3 factors through column 3 (replace U3) and, since (3, 2) = eps, through column 2 as well
   (replace U2 by U2 + eps^2 U1) *)
sysB = PFBReadSystem[(Put[{j[bub, 1, 0], j[bub, 1, 1], j[bub, 2, 1]}, FileNameJoin[{tmp, "bub.m"}]];
   Put[<|"Name" -> "bub", "Families" -> {<|"Name" -> "bub", "Family" -> StringReplace[boxFile, "box-one-loop" -> "bubble-massive"], "Masters" -> "bub.m"|>}|>,
     FileNameJoin[{tmp, "bub.wl"}]]; FileNameJoin[{tmp, "bub.wl"}])];
keyB = {bub, {1, 1}};
sliceB[R_] := <|"R" -> {R}, "Derivatives" -> {s}, "Point" -> {s -> 5/3, m2 -> 1}, "Labels" -> {1, 2, 3}, "Index" -> <|1 -> 1, 2 -> 2, 3 -> 3|>, "History" -> {}|>;
RB = {{-eps, 0, 0}, {eps^2, -eps, eps}, {eps + eps^3, eps, -2 eps}};
srcB[R_] := PFBSourceTest[sysB, sliceB[R], PFBCensus[sysB, sliceB[R]], keyB];
AppendTo[tests, VerificationTest[With[{r = srcB[RB]}, {r["Outcome"], Sort[#["Sources"] & /@ r["Passing"]], r["HighColumns"]}], {"degree-source", {{2}, {3}}, {1}},
  TestID -> "source test: entries above the cap factor through a column"]];
AppendTo[tests, VerificationTest[With[{r = srcB[ReplacePart[RB, {3, 2} -> 0]]}, {r["Outcome"], #["Sources"] & /@ r["Passing"]}], {"degree-source", {{3}}},
  TestID -> "source test: only the row's own master when no column reaches it"]];
AppendTo[tests, VerificationTest[{srcB[ReplacePart[RB, {3, 2} -> eps^3]]["Outcome"], srcB[ReplacePart[RB, {2, 3} -> 1/eps]]["Outcome"]}, {"maximal-cut", "maximal-cut"},
  TestID -> "source test: an own block above the cap, or with 1/eps, needs a new maximal-cut basis"]];
(* 1/eps towards the lower master: a pole at eps = 0 like a finite one. Row 3 is clean at eps = 0, so U2 is the source *)
AppendTo[tests, VerificationTest[With[{r = srcB[ReplacePart[RB, {2, 1} -> 1/eps]]}, {r["Outcome"], #["Sources"] & /@ r["Passing"], r["Poles"]}],
  {"source", {{2}}, <|0 -> 1|>}, TestID -> "source test: a row with 1/eps towards a lower master gets the residue-column test at eps = 0"]];
AppendTo[tests, VerificationTest[{PFBSourceTest[sysB, sliceB[ReplacePart[RB, {2, 1} -> 1/eps]], PFBCensus[sysB, sliceB[ReplacePart[RB, {2, 1} -> 1/eps]]], keyB,
    <|"PolesOnly" -> True|>]["Outcome"], srcB[{{-eps, 0, 0}, {eps, -eps, eps}, {eps, eps, -2 eps}}]["Outcome"]}, {"pole-free", "pole-free"},
  TestID -> "source test: the poles alone for the gate's deferral, and a clean sector"]];
AppendTo[tests, VerificationTest[Lookup[Last[PFBSourcesByPole[sysB, sliceB[RB], keyB]], {"pole", "factor", "order", "ownBlock", "sources"}],
  {Infinity, eps^3, 1, False, {{2}, {3}}}, TestID -> "sources by pole: eps -> infinity as one more pole"]];
AppendTo[tests, VerificationTest[Lookup[First[PFBSourcesByPole[sysB, sliceB[ReplacePart[RB, {2, 1} -> 1/eps]], keyB]], {"pole", "factor", "order", "ownBlock", "sources"}],
  {0, eps, 1, False, {{2}}}, TestID -> "sources by pole: eps = 0 as a pole"]];
(* the new master U3' = U3 + lam U1 (a dot moved: the maximal cut unchanged) relates to the old one through lam. With 1/eps
   in lam the old rows have 1/eps, with or without a finite pole beside it; the source test names U3, and the gate takes
   the change *)
RtB = {{-eps, 0, 0}, {eps, -eps, 1}, {eps, eps, -2 eps}};
planted[lam_] := With[{M = {{1, 0, 0}, {0, 1, 0}, {lam, 0, 1}}}, Module[{sl = sliceB[Together[Inverse[M] . RtB . M]], c, ch, g},
   c = PFBCensus[sysB, sl];
   ch = <|"Name" -> "planted", "Key" -> keyB, "Kind" -> "change", "Replace" -> {3}, "H" -> {M[[3]]}, "G" -> {{Together[RtB[[3]] . M]}}, "NewDefs" -> <|3 -> j[bub, 1, 2]|>|>;
   g = PFBGate[sysB, sl, c, PFBApplyChange[sl, ch], ch];
   {Lookup[c["Sectors"][keyB], {"BadRows", "EpsZeroRows", "SelfBlockEpsZero"}], PFBSourceTest[sysB, sl, c, keyB][["Outcome"]],
     MemberQ[#["Sources"] & /@ PFBSourceTest[sysB, sl, c, keyB]["Passing"], {3}], PFBApplyChange[sl, ch]["R"] === {RtB}, g["Pass"]}]];
AppendTo[tests, VerificationTest[planted[(1 + eps)/(eps (1 - 2 eps))], {{{2, 3}, {2}, {}}, "source", True, True, True},
  TestID -> "source test: a finite pole and 1/eps in the same entries, one source for both"]];
AppendTo[tests, VerificationTest[planted[(1 + eps)/eps], {{{}, {2}, {}}, "source", True, True, True},
  TestID -> "source test: 1/eps alone, removed with the maximal cut unchanged"]];
AppendTo[tests, VerificationTest[Lookup[PFBCensus[sysB, sliceB[ReplacePart[RB, {2, 3} -> 1/eps]]]["Sectors"][keyB], {"EpsZeroRows", "SelfBlockEpsZero"}], {{2}, {3}},
  TestID -> "census: negative powers of eps in the own block"]];

(* the gate on a pole fix whose entry had eps^3 at eps -> infinity with its pole: keeping eps^3 passes, eps^4 does not *)
gateKeep[top_] := With[{Rt = ReplacePart[RtB, {3, 1} -> eps + top], M = {{1, 0, 0}, {0, 1, 0}, {(2 + eps)/(1 - 2 eps), 0, 1}}}, Module[{sl, ch, g},
    sl = sliceB[Together[Inverse[M] . ReplacePart[RtB, {3, 1} -> eps + eps^3] . M]];
    ch = <|"Name" -> "keep", "Key" -> keyB, "Kind" -> "change", "Replace" -> {3}, "H" -> {M[[3]]}, "G" -> {{Together[Rt[[3]] . M]}}, "NewDefs" -> <|3 -> j[bub, 1, 2]|>|>;
    g = PFBGate[sysB, sl, PFBCensus[sysB, sl], PFBApplyChange[sl, ch], ch];
    {PFBEpsOrders[sl["R"][[1, 3, 1]]], PFBApplyChange[sl, ch]["R"][[1, 3, 1]], g["Pass"], #["Name"] & /@ Select[g["Checks"], ! #["Pass"] &]}]];
AppendTo[tests, VerificationTest[{gateKeep[eps^3], gateKeep[eps^4][[3 ;;]]}, {{{1, 3}, eps + eps^3, True, {}}, {False, {"degree"}}},
  TestID -> "gate: a pole fix keeps the power the entry had with its pole, and may not raise it"]];

(* PFBTryChange: the run's cap reaches the gate and the extra points (the planted reduction at two new points) *)
tryRun[cap_] := Module[{dir = CreateDirectory[FileNameJoin[{tmp, "run" <> ToString[cap]}]], st, ctx},
  st = <|"Run" -> "none", "Created" -> PFBTimeStamp[], "Slices" -> {}, "Current" -> None, "Censuses" -> {}, "Accepted" -> {}, "Pending" -> {},
    "Rejected" -> {}, "Flagged" -> <||>, "Approval" -> False, "Regenerated" -> False|>;
  st = PFBStoreSlice[dir, st, oldSl, c0, "start"];
  ctx = <|"Run" -> <|"MaxEpsDegree" -> cap|>, "System" -> sys, "Dir" -> dir, "State" -> st|>;
  PFBTryChange[ctx, key, sets[[1]], <|"Rung" -> 3, "Provenance" -> "planted"|>, <|"Reds" -> {red, redAt[P2], redAt[P3]}|>]];
(* the slice gate refuses it; the extra points only check that no point goes above the slice's own power *)
AppendTo[tests, VerificationTest[With[{r = tryRun[2]}, {r["Status"], failing[r["Gate"]], r["Record"]["PointsVerified"]}], {"rejected", {"degree"}, 2},
  TestID -> "PFBTryChange: refused under the run's cap of 2"]];
AppendTo[tests, VerificationTest[With[{r = tryRun[3]}, {r["Status"], r["Record"]["PointsVerified"], Lookup[Last[r["Context"]["State"]["Slices"]], {"MaxDegree", "HighDegree"}]}],
  {"accepted", 2, {3, 0}}, TestID -> "PFBTryChange: accepted under a cap of 3"]];

(* a negative power of eps on the diagonal cannot be lifted by a uniform eps^k, also where it takes the place of a finite
   pole: the census does not count that entry as new (it lost its pole), and the gate still refuses it. The two slices
   are planted: the box's diagonal entry with eps/(1 - 2 eps) before, with 1/eps after *)
gDiag = With[{slA = slice[ReplacePart[Rgood, {3, 3} -> -1 - 2 eps + eps/(1 - 2 eps)]], slB = slice[ReplacePart[Rgood, {3, 3} -> -1 - 2 eps + 1/eps]]},
  PFBGate[sys, slA, PFBCensus[sys, slA], slB, good]];
AppendTo[tests, VerificationTest[{checkOf[gDiag, "rows"]["Pass"], checkOf[gDiag, "census"]["Pass"], StringContainsQ[checkOf[gDiag, "census"]["Detail"], "1 on the diagonal"]},
  {True, False, True}, TestID -> "gate: a finite pole on the diagonal that becomes 1/eps is refused"]];

report = TestReport[tests];
Do[With[{r = report["TestResults"][id]},
    Print[If[r["Outcome"] === "Success", "PASS ", "FAIL "], r["TestID"], If[r["Outcome"] === "Success", "",
      "\n     got " <> ToString[Short[r["ActualOutput"], 3], InputForm] <> "\n     expected " <> ToString[Short[r["ExpectedOutput"], 3], InputForm]]]],
  {id, Keys[report["TestResults"]]}];
Print[report["TestsSucceededCount"], " passed, ", report["TestsFailedCount"], " failed, ", Round[report["TimeElapsed"], 0.1]];
DeleteDirectory[tmp, DeleteContents -> True];
Exit[If[report["AllTestsSucceeded"], 0, 1]];
