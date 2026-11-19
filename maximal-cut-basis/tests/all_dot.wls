#!/usr/bin/env wolframscript
(* The all-dot flag. On a non-dlog sector (status eps-polynomial, or a Picard-Fuchs label that is not polylogarithmic) a
   basis whose every element is dotted (each integral of the element in the sector has a propagator power > 1) is
   likely to carry a weight between sectors: basis.m gets the check "all-dot" and a flag, the page shows it, and among
   bases that are otherwise equal one with an undotted element wins (MCBBetterBasisQ, MCBSearchBasis). A dlog sector is
   unaffected, dotted bubbles included.
   Planted data: basis records of the equal-mass sunrise (elliptic cut, two masters) and of the one-loop box of the
   examples, and planted maximal-cut reductions for the search. No Kira, no BaikovPackage.
   usage: bin/ws tests/all_dot.wls        exit code 0 when every test passes *)
Get[FileNameJoin[{ParentDirectory[DirectoryName[$InputFileName]], "lib", "MaximalCutBasis.wl"}]];
$MCBVerbose = False;
ex = FileNameJoin[{ParentDirectory[DirectoryName[$InputFileName]], "examples"}];
sun = MCBReadFamily[FileNameJoin[{ex, "sunrise-equal-mass", "family.wl"}]];
box = MCBReadFamily[FileNameJoin[{ex, "box-one-loop", "family.wl"}]];
tmp = CreateDirectory[];
sS = {1, 1, 1, 0, 0}; sB = {0, 1, 0, 1};
j111 = j[sunrise, 1, 1, 1, 0, 0]; j211 = j[sunrise, 2, 1, 1, 0, 0]; j121 = j[sunrise, 1, 2, 1, 0, 0]; j110 = j[sunrise, 1, 1, 0, 0, 0];
cand[K_, opts___] := Join[<|"r2" -> 1, "K" -> K, "label" -> "planted", "provenance" -> "planted", "strict" -> False, "priority" -> 5, "weight" -> {1, 0, 0}|>, Association[opts]];
check[st_, range_] := <|"status" -> st, "range" -> range, "checks" -> {<|"Name" -> "euler", "Pass" -> True, "Detail" -> "planted"|>}, "points" -> {}|>;
record[fam_, s_, Ks_, st_, cls_ : Missing["NotRun"], range_ : {0, 1}] := MCBBasisRecord[fam, s, <|"check" -> check[st, range], "cands" -> (cand /@ Ks), "status" -> st,
   "classification" -> cls, "geometry" -> <|"class" -> "planted", "text" -> "planted"|>|>];
elliptic = <|"label" -> "elliptic", "reason" -> "planted"|>; polylog = <|"label" -> "polylog", "reason" -> "planted"|>;
allDot[rec_] := SelectFirst[rec["checks"], #["Name"] === "all-dot" &, None];
flagged[rec_] := AnyTrue[rec["flags"], StringStartsQ[#, "all-dot:"] &];

recDot = record[sun, sS, {j211, eps j121 + j110}, "eps-polynomial"];      (* every element dotted: j110 lies in a subsector *)
recMix = record[sun, sS, {j111, j211}, "eps-polynomial"];
recBox = record[box, sB, {s eps j[box, 0, 2, 0, 1]}, "eps-form", polylog, {1, 1}];   (* a dotted bubble: the canonical one, dlog *)

tests = {
  VerificationTest[{MCBDottedQ[j211, sS], MCBDottedQ[j111, sS], MCBDottedQ[m2 j211 + j110, sS], MCBDottedQ[eps^2 Sqrt[s (s - 4 m2)] (j211 - j121)], MCBDottedQ[j111 + j211, sS],
      MCBDottedQ[j110, sS]}, {True, False, True, True, False, False}, TestID -> "MCBDottedQ: every integral of the element in the sector dotted; subsector integrals do not count"],
  VerificationTest[{MCBAllDotQ[{j211, j121}, sS], MCBAllDotQ[{j211, j111}, sS], MCBAllDotQ[{}, sS]}, {True, False, False}, TestID -> "MCBAllDotQ"],
  VerificationTest[{MCBNonDlogQ["eps-polynomial", None], MCBNonDlogQ["eps-form", elliptic], MCBNonDlogQ["eps-form", polylog], MCBNonDlogQ["eps-polynomial (dlog search incomplete)", polylog]},
    {True, True, False, False}, TestID -> "MCBNonDlogQ: an eps-polynomial status or a label that is not polylogarithmic"],
  VerificationTest[{Lookup[allDot[recDot], "Pass"], flagged[recDot], Lookup[allDot[recMix], "Pass"], flagged[recMix]}, {False, True, True, False},
    TestID -> "basis.m: the all-dot check fails and flags a basis of dotted elements on a non-dlog sector, passes with an undotted element"],
  VerificationTest[{allDot[recBox], flagged[recBox], allDot[record[sun, sS, {j211, j121}, "eps-polynomial (dlog search incomplete)", polylog]]}, {None, False, None},
    TestID -> "a dlog sector is unaffected: no check, no flag (a dotted bubble, a polylog label)"],
  VerificationTest[{Lookup[allDot[record[sun, sS, {j211, j121}, "eps-form", elliptic]], "Pass"], MCBFlaggedQ[recDot], MCBFlaggedQ[recMix]}, {False, False, False},
    TestID -> "a non-polylog label decides too; the flag does not make the sector one that needs attention"],
  (* the tie-breaker of adoption *)
  VerificationTest[{MCBBetterBasisQ["eps-polynomial", {0, 1}, recDot, <|"masters" -> {j111, j211}|>], MCBBetterBasisQ["eps-polynomial", {0, 1}, recMix, <|"masters" -> {j211, j121}|>],
      MCBBetterBasisQ["eps-polynomial", {0, 1}, recDot], MCBBetterBasisQ["eps-polynomial", {0, 2}, recDot, <|"masters" -> {j111, j211}|>],
      MCBBetterBasisQ["eps-polynomial", {0, 1}, record[sun, sS, {j211, j121}, "eps-polynomial", Missing["NotRun"], {0, 2}], <|"masters" -> {j211, j121}|>]},
    {True, False, False, False, True}, TestID -> "MCBBetterBasisQ: an undotted element wins a tie of spreads, a smaller spread still comes first"],
  VerificationTest[MCBBetterBasisQ["eps-form", {1, 1}, recBox, <|"masters" -> {s eps j[box, 0, 1, 0, 1]}|>], False, TestID -> "MCBBetterBasisQ: no tie-breaker on a dlog sector"]
};

(* the page and a record that gets its classification later (MCBKeepClassification) *)
sd = FileNameJoin[{tmp, "sun_analysis", SectorName[sS]}]; CreateDirectory[sd, CreateIntermediateDirectories -> True];
Put[<|"FamilyFile" -> FileNameJoin[{ex, "sunrise-equal-mass", "family.wl"}]|>, FileNameJoin[{ParentDirectory[sd], "run_info.m"}]];
MCBWriteBasis[sd, recDot];
MCBBasisHTML[sd, sun];
page = Import[FileNameJoin[{sd, "basis.html"}], "Text"];
AppendTo[tests, VerificationTest[{StringContainsQ[page, "all-dot: every element is dotted"], StringContainsQ[page, "all-dot</li>"] || StringContainsQ[page, "all-dot: <b>fail</b>"]}, {True, True},
  TestID -> "basis.html: the flag and the check"]];
MCBWriteBasis[sd, record[sun, sS, {j211, j121}, "eps-polynomial", elliptic]];
late = MCBKeepClassification[sd, record[sun, sS, {j211, j121}, "eps-polynomial (dlog search incomplete)"]];
AppendTo[tests, VerificationTest[{late["status"], Lookup[allDot[late], "Pass"], flagged[late]}, {"eps-polynomial", False, True},
  TestID -> "a record that gets the elliptic label later gets the check and the flag"]];

(* the search: planted maximal-cut reductions at one point, one invariant. nmi = 1 (exact search): a dotted candidate
   first in the order, an undotted one with the same spread (it is 1 - 2 eps times the first on the cut) *)
pt = {s -> 3, m2 -> 1};
red1 = {<|"point" -> pt, "masters" -> {j111}, "invariants" -> {s}, "T" -> {{1}, {1 - 2 eps}}, "D" -> {{{1 + eps}, {(1 - 2 eps) (1 + eps)}}}, "g" -> {{0, 0}}|>};
c1 = {cand[j211, "priority" -> 0], cand[j111]};
AppendTo[tests, VerificationTest[{MCBSearchBasis[red1, c1, 1]["sub"], MCBSearchBasis[red1, c1, 1, <|"NonDlog" -> True, "Sector" -> sS|>]["sub"],
    MCBSearchBasis[red1, c1, 1, <|"NonDlog" -> True|>]["sub"], MCBSearchBasis[red1, c1, 1, <|"NonDlog" -> True|>]["range"]},
  {{1}, {2}, {2}, {0, 1}}, TestID -> "MCBSearchBasis, exact: on a non-dlog sector a tie of spreads goes to the undotted candidate"]];
(* nmi = 3 (screened search): three dotted candidates first, an undotted one in another direction; every subset has the
   same spread, A = (1 + eps) T M T^-1 *)
M = {{1, 2, 0}, {0, 1, 1}, {1, 0, 1}}; T3 = {{1, 0, 0}, {0, 1, 0}, {0, 0, 1}, {1, 0, 1}};
red3 = {<|"point" -> pt, "masters" -> {m1, m2x, m3}, "invariants" -> {s}, "T" -> T3, "D" -> {(1 + eps) T3 . M}, "g" -> {{0, 0, 0, 0}}|>};
c3 = {cand[j211, "priority" -> 0], cand[j121, "priority" -> 0], cand[j[sunrise, 1, 1, 2, 0, 0], "priority" -> 0], cand[j111]};
AppendTo[tests, VerificationTest[{MCBSearchBasis[red3, c3, 3]["sub"], MCBSearchBasis[red3, c3, 3, <|"NonDlog" -> True, "Sector" -> sS|>]["sub"],
    MCBSearchBasis[red3, c3, 3, <|"NonDlog" -> True, "Sector" -> sS|>]["status"]},
  {{1, 2, 3}, {1, 2, 4}, "eps-polynomial"}, TestID -> "MCBSearchBasis, screened: the same tie-breaker"]];

report = TestReport[tests];
Do[With[{r = report["TestResults"][id]},
    Print[If[r["Outcome"] === "Success", "PASS ", "FAIL "], r["TestID"], If[r["Outcome"] === "Success", "",
      "\n     got " <> ToString[Short[r["ActualOutput"], 3], InputForm] <> "\n     expected " <> ToString[Short[r["ExpectedOutput"], 3], InputForm]]]],
  {id, Keys[report["TestResults"]]}];
Print[report["TestsSucceededCount"], " passed, ", report["TestsFailedCount"], " failed, ", Round[report["TimeElapsed"], 0.1]];
DeleteDirectory[tmp, DeleteContents -> True];
Exit[If[report["AllTestsSucceeded"], 0, 1]];
