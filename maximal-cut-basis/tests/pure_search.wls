#!/usr/bin/env wolframscript
(* The search for eps-pure integrals. A basis element whose integrand, Gamma prefactor included, is eps-pure is likely to
   be uniform weight off the cut; the DE on the cut cannot tell (an (a + b eps) factor leaves a one-master DE as it is).
   The search orders its candidates with the eps-pure ones first (MCBOrderKey), before any priority and before a
   rational normalisation, and never gives up an eps-pure element for one that is not (MCBSimplifyBasis).
   Planted data: maximal-cut reductions at one point, one invariant, one master on the cut. No Kira, no BaikovPackage.
   usage: bin/ws tests/pure_search.wls        exit code 0 when every test passes *)
Get[FileNameJoin[{ParentDirectory[DirectoryName[$InputFileName]], "lib", "MaximalCutBasis.wl"}]];
$MCBVerbose = False;
cand[K_, opts___] := Join[<|"r2" -> 1, "K" -> K, "label" -> "planted", "provenance" -> "planted", "strict" -> False, "priority" -> 5, "weight" -> {1, 0, 0}|>, Association[opts]];
ja = j[fam, 1, 1, 0]; jb = j[fam, 2, 1, 0]; jc = j[fam, 1, 1, 1];

(* the order: eps-pure first, then the priority, a rational normalisation, the weight *)
pureRoot = cand[ja, "r2" -> s, "strict" -> True];      (* eps-pure, normalised by a square root *)
impureRat = cand[jb];                                   (* rational, not eps-pure *)
mappedImpure = cand[jc, "priority" -> 1];               (* a mapped basis: priority 1 *)
tests = {
  VerificationTest[SortBy[{impureRat, mappedImpure, pureRoot}, MCBOrderKey][[All, "K"]], {ja, jc, jb},
    TestID -> "MCBOrderKey: an eps-pure candidate comes first, before a mapped one and before a rational normalisation"],
  VerificationTest[SortBy[{cand[jb, "weight" -> {3, 2, 0}], cand[ja, "r2" -> s]}, MCBOrderKey][[All, "K"]], {jb, ja},
    TestID -> "MCBOrderKey: between candidates equally pure, a rational normalisation still comes first"]};

(* one master on the cut, invariant s at s = 3. J = Sqrt[r2] K, A = D T^-1 + d log Sqrt[r2]: both candidates are
   eps-form, A = eps. The pure one is normalised by Sqrt[s] (g = 1/(2 s) = 1/6); the rational one is (1 - 2 eps) times
   it on the cut, up to the root *)
pt = {s -> 3};
red = {<|"point" -> pt, "masters" -> {m1}, "invariants" -> {s}, "T" -> {{1 - 2 eps}, {2}}, "D" -> {{{(1 - 2 eps) eps}, {2 eps - 1/3}}}, "g" -> {{0, 1/6}}|>};
cs = {cand[jb], cand[ja, "r2" -> s, "strict" -> True]};
AppendTo[tests, VerificationTest[{MCBSearchBasis[red, cs, 1]["status"], MCBSearchBasis[red, cs, 1]["sub"]}, {"eps-form", {2}},
  TestID -> "MCBSearchBasis: of two eps-form candidates, the eps-pure one, normalised by a square root, is kept"]];
AppendTo[tests, VerificationTest[MCBSimplifyBasis[red, cs, {2}, {1, 2}]["sub"], {2},
  TestID -> "MCBSimplifyBasis: never gives up an eps-pure element for a rational one that is not"]];
AppendTo[tests, VerificationTest[MCBSimplifyBasis[red, cs, {1}, {1, 2}]["sub"], {2},
  TestID -> "MCBSimplifyBasis: replaces an element that is not eps-pure by an eps-pure one while the DE stays eps-form"]];

(* two masters, A = eps diag(1, 2) in their frame; a candidate is f(eps) times a constant row v (D = T A). A pair is
   eps-form when its rows are eigenvectors, or when their f's agree. p1 = e1, u1 = (1 + eps) e2 (not eps-pure),
   p2 = (1 + 2 eps)(1, 1), p3 = (1 + 2 eps)(1, 2): the eps-form pairs are {p1, u1} and {p2, p3} only. The first eps-form
   pair in the order is {p1, u1}, and no single swap reaches {p2, p3}: the search must try the eps-pure ones alone first *)
T2 = {{1, 0}, (1 + 2 eps) {1, 1}, (1 + eps) {0, 1}, (1 + 2 eps) {1, 2}};
red2 = {<|"point" -> pt, "masters" -> {m1, m2}, "invariants" -> {s}, "T" -> T2, "D" -> {T2 . (eps DiagonalMatrix[{1, 2}])}, "g" -> {{0, 0, 0, 0}}|>};
cs2 = {cand[j[fam, 1, 0, 1], "pure" -> True], cand[j[fam, 1, 1, 1], "pure" -> True], cand[j[fam, 2, 1, 1], "pure" -> False], cand[j[fam, 1, 2, 1], "pure" -> True]};
AppendTo[tests, VerificationTest[{MCBSearchBasis[red2, cs2, 2]["status"], MCBSearchBasis[red2, cs2, 2]["sub"], MCBSearchBasis[red2, cs2, 2, <|"NonDlog" -> True|>]["sub"]},
  {"eps-form", {2, 4}, {1, 3}},
  TestID -> "MCBSearchBasis: the eps-pure candidates are searched alone first, so a pure basis two swaps away is found (one search on a non-dlog sector)"]];

(* the purity verdict of a candidate (MCBCandidatePurity): MCBElementPurity is planted, by the integrals of K *)
plantedPurity = <|ja -> True, jb -> False|>;
purityCalls = 0;
(* as the real one: without a representation, nothing is checked *)
(* an integral in timeoutOnce times out at its first check *)
timeoutOnce = {}; timedOut = {};
plantedElementPurity[reps_, c_] := (purityCalls++; If[c["K"] === jc, Pause[1.5]];
  If[MemberQ[timeoutOnce, c["K"]] && ! MemberQ[timedOut, c["K"]], AppendTo[timedOut, c["K"]]; Return[<|"pure" -> Missing["Timeout"], "detail" -> "planted timeout"|>]];
  With[{p = If[reps === {}, Missing["NotChecked"], Lookup[plantedPurity, c["K"], Missing["NotChecked"]]]}, <|"pure" -> p, "detail" -> "planted: " <> ToString[p]|>]);
(* two planted representations: Gamma prefactor 1, and 2/(1 - 2 eps) *)
repOK = <|"id" -> 1, "order" -> {1}, "isp" -> {}, "kind" -> "planted", "vars" -> {}, "prefRat" -> 1|>;
repBad = <|"id" -> 2, "order" -> {2}, "isp" -> {}, "kind" -> "planted", "vars" -> {}, "prefRat" -> 2/(1 - 2 eps)|>;
pr = {repOK, repBad}; inOK = "rep" -> {{1}, {}, "planted"}; inBad = "rep" -> {{2}, {}, "planted"};
Block[{MCBElementPurity = plantedElementPurity},
  pv = MCBCandidatePurity[pr, {cand[ja], cand[jb], cand[jc], cand[ja + jb, "strict" -> True, "label" -> "d-dim dlog", "provenance" -> "planted builder", inOK],
     cand[jb, "pure" -> True, "pureDetail" -> "given"], cand[ja, "strict" -> True, inOK], cand[jb, "strict" -> True, "label" -> "projected", inOK],
     cand[jb, "strict" -> True, "label" -> "d-dim twin", inBad], cand[jb, "strict" -> True, "label" -> "no representation"]}, <|"TimeLimit" -> 1|>];
  calls1 = purityCalls; purityCalls = 0;
  pb = MCBCandidatePurity[pr, {cand[jc], cand[ja], cand[jb, "strict" -> True, "label" -> "d-dim", inOK], cand[jb, "strict" -> True, "label" -> "d-dim", inBad]},
    <|"TimeLimit" -> 5, "Budget" -> 0.5|>]];
AppendTo[tests, VerificationTest[{pv[[All, "pure"]], pv[[{4, 5, 6, 7, 8}, "pureDetail"]], calls1},
  {{True, False, Missing["Timeout"], True, True, True, True, False, False},
    {"eps-pure as built (d-dim dlog; planted builder)", "given", "planted: True", "eps-pure as built (projected; planted)", "planted: False"}, 8},
  TestID -> "MCBCandidatePurity: MCBElementPurity's verdict, a timeout, a given verdict kept; a strict candidate is True as built only under a prefactor that is a power of eps"]];
AppendTo[tests, VerificationTest[{pb[[All, "pure"]], pb[[3, "pureDetail"]]}, {{Missing["NotChecked"], Missing["Timeout"], True, Missing["Timeout"]}, "eps-pure as built (d-dim; planted)"},
  TestID -> "MCBCandidatePurity: once the budget is used up, the candidates left are not checked, except one built eps-pure"]];
AppendTo[tests, VerificationTest[{SortBy[{cand[jb, "pure" -> False, "priority" -> 0], cand[jc], cand[ja, "pure" -> True, "r2" -> s]}, MCBOrderKey][[All, "K"]],
    SortBy[{cand[jb, "strict" -> True, "pure" -> False], cand[jc], cand[ja, "strict" -> True]}, MCBOrderKey][[All, "K"]]}, {{ja, jc, jb}, {ja, jc, jb}},
  TestID -> "MCBOrderKey: eps-pure, then purity not known, then not eps-pure; a verdict outranks strict"]];

(* basis.m takes the candidate's verdict; one left open by the search is checked again *)
box = MCBReadFamily[FileNameJoin[{ParentDirectory[DirectoryName[$InputFileName]], "examples", "box-one-loop", "family.wl"}]];
sB = {0, 1, 0, 1};
bubA = j[box, 0, 1, 0, 1]; bubB = j[box, 0, 2, 0, 1];
plantedPurity = <|bubA -> False, bubB -> True|>;
check1 = <|"status" -> "eps-form", "range" -> {1, 1}, "checks" -> {<|"Name" -> "euler", "Pass" -> True, "Detail" -> "planted"|>}, "points" -> {}|>;
rec[cs_, reps_ : None] := Block[{MCBElementPurity = plantedElementPurity},
  MCBBasisRecord[box, sB, Join[<|"check" -> check1, "cands" -> cs, "status" -> "eps-form", "geometry" -> <|"class" -> "planted", "text" -> "planted"|>|>,
    If[reps === None, <||>, <|"reps" -> reps|>]]]];
purityCalls = 0;
r1 = rec[{cand[bubA, "pure" -> True, "pureDetail" -> "from the search"]}, {}];
r2 = rec[{cand[bubA, "strict" -> True, "label" -> "d-dim dlog", "provenance" -> "planted builder", inOK]}, {repOK}];
r3 = rec[{cand[bubB, "pure" -> Missing["Timeout"], "pureDetail" -> "not checked: timed out"]}, pr];
r4 = rec[{cand[bubB]}];
AppendTo[tests, VerificationTest[{r1["masters"][[1, {"epsPure", "epsPureDetail"}]], r2["masters"][[1, {"epsPure", "epsPureDetail"}]], r3["masters"][[1, "epsPure"]],
    r4["masters"][[1, "epsPure"]], purityCalls},
  {<|"epsPure" -> True, "epsPureDetail" -> "from the search"|>, <|"epsPure" -> True, "epsPureDetail" -> "eps-pure as built (d-dim dlog; planted builder)"|>, True,
    Missing["NotChecked"], 2},
  TestID -> "basis.m: epsPure is the search's verdict, True as built, checked again after a timeout, not checked without representations"]];

(* which representation judges an element (MCBElementPurity): those without cut variables first (the test is exact
   there), pure when one of them shows it; then its own; then those with the fewest cut variables, pure when one shows
   it. The cut integrands and the test in one representation are planted: A has no cut variable and shows the element
   impure (a 1/(1 - 2 eps) in its prefactor), B has two and shows it pure, C has none and shows it pure, D has one and
   shows it impure *)
repOf[id_, nv_, pure_] := <|"id" -> id, "order" -> {id}, "isp" -> {}, "kind" -> "planted", "vars" -> Table[z[i], {i, nv}], "planted" -> pure|>;
rA = repOf[1, 0, False]; rB = repOf[2, 2, True]; rC = repOf[3, 0, True]; rD = repOf[4, 1, False];
judged[reps_, c_] := Block[{MCBCutIntegrand = (1 &), MaximalCutBasis`LeadingSingularities`Private`purityIn = Function[{cd, cc}, <|"pure" -> cd["planted"], "detail" -> "rep " <> ToString[cd["id"]]|>]},
  MCBElementPurity[reps, c]];
AppendTo[tests, VerificationTest[{judged[{rA, rB}, cand[ja, "rep" -> {{1}, {}, "planted"}]], judged[{rA, rB}, cand[ja]], judged[{rB, rA}, cand[ja, "rep" -> {{2}, {}, "planted"}]],
    judged[{rA, rB, rC}, cand[ja]], judged[{rD, rB}, cand[ja, "rep" -> {{2}, {}, "planted"}]], judged[{rB, rD}, cand[ja]]},
  {<|"pure" -> False, "detail" -> "rep 1"|>, <|"pure" -> False, "detail" -> "rep 1"|>, <|"pure" -> False, "detail" -> "rep 1"|>, <|"pure" -> True, "detail" -> "rep 3"|>,
    <|"pure" -> True, "detail" -> "rep 2"|>, <|"pure" -> False, "detail" -> "rep 4"|>},
  TestID -> "MCBElementPurity: the representations without cut variables decide; then its own; then those with the fewest cut variables"]];

(* a re-check keeps the verdict basis.m has for an unchanged element (MCBKeptPurity), only one of this rule's version *)
oldRec[rule_] := <|"masters" -> {<|"definition" -> eps j[box, 0, 1, 0, 1], "epsPure" -> False, "epsPureDetail" -> "planted", "purityRule" -> rule|>,
    <|"definition" -> s j[box, 0, 2, 0, 1], "epsPure" -> Missing["NotChecked"], "epsPureDetail" -> "planted", "purityRule" -> rule|>}|>;
AppendTo[tests, VerificationTest[{MCBKeptPurity[oldRec[$MCBPurityRule], {eps j[box, 0, 1, 0, 1], s j[box, 0, 2, 0, 1], t j[box, 0, 2, 0, 1]}],
    MCBKeptPurity[oldRec[1], {eps j[box, 0, 1, 0, 1]}], MCBKeptPurity[<||>, {eps j[box, 0, 1, 0, 1]}]},
  {{<|"pure" -> False, "pureDetail" -> "planted"|>, <||>, <||>}, {<||>}, {<||>}},
  TestID -> "MCBKeptPurity: an unchanged element keeps a True or False verdict of this rule; another rule, an unknown verdict or a new element is judged again"]];

(* adoption (MCBBetterBasisQ, check_basis.wls, AnalysisMasters.m): between two eps-form bases, the one with fewer elements
   that are not eps-pure, then with more that are, is better *)
recP[ps_, st_ : "eps-form"] := <|"status" -> st, "range" -> {1, 1}, "sector" -> sB, "masters" -> (<|"definition" -> bubA, "epsPure" -> #|> & /@ ps)|>;
AppendTo[tests, VerificationTest[{
    MCBBetterBasisQ["eps-form", {1, 1}, recP[{False}], <|"masters" -> {bubB}, "purity" -> {True}|>],
    MCBBetterBasisQ["eps-form", {1, 1}, recP[{True}], <|"masters" -> {bubB}, "purity" -> {False}|>],
    MCBBetterBasisQ["eps-form", {1, 1}, recP[{True}], <|"masters" -> {bubB}, "purity" -> {True}|>],
    MCBBetterBasisQ["eps-form", {1, 1}, recP[{False}], <|"masters" -> {bubB}|>],
    MCBBetterBasisQ["eps-form", {1, 1}, recP[{Missing["NotChecked"]}], <|"masters" -> {bubB}, "purity" -> {True}|>],
    MCBBetterBasisQ["eps-form", {1, 1}, recP[{True, Missing["NotChecked"]}], <|"masters" -> {bubA, bubB}, "purity" -> {True, True}|>],
    MCBBetterBasisQ["eps-form", {1, 1}, recP[{True, True}], <|"masters" -> {bubA, bubB}, "purity" -> {True, Missing["Timeout"]}|>],
    MCBBetterBasisQ["eps-polynomial", {0, 1}, recP[{False}], <|"masters" -> {bubB}, "purity" -> {True}|>],
    MCBBetterBasisQ["eps-form", {1, 1}, recP[{True}, "eps-polynomial"], <|"masters" -> {bubB}, "purity" -> {False}|>]},
  {True, False, False, False, True, True, False, False, True},
  TestID -> "MCBBetterBasisQ: between two eps-form bases fewer elements that are not eps-pure win, then more that are; the status still comes first"]];
(* the check of a tie-breaker (check_basis.wls): the current basis, more eps-pure, is better than the new one *)
AppendTo[tests, VerificationTest[MCBBetterBasisQ["eps-form", {1, 1}, <|"status" -> "eps-form", "range" -> {1, 1}, "masters" -> {bubA}, "purity" -> {False}|>,
    <|"masters" -> recP[{True}]["masters"]|>], True,
  TestID -> "MCBBetterBasisQ: a tie-breaker cannot replace a basis that is more eps-pure"]];

(* the flag: an eps-form basis with an element that is not eps-pure needs step 4 (MCBFlaggedQ), with a retry hint *)
recF = rec[{cand[bubA, "pure" -> False, "pureDetail" -> "not eps-pure off the cut: planted"]}];
recT = rec[{cand[bubB, "pure" -> True, "pureDetail" -> "planted"]}];
recU = rec[{cand[bubB, "pure" -> Missing["NotChecked"], "pureDetail" -> "planted"]}];
recQ = Join[recF, <|"status" -> "eps-polynomial"|>];
hdir = CreateDirectory[];
AppendTo[tests, VerificationTest[{MCBFlaggedQ[recF], MCBFlaggedQ[recT], MCBFlaggedQ[recU], MCBFlaggedQ[recQ],
    AnyTrue[recF["flags"], StringContainsQ[#, "needs step 4"] &], AnyTrue[MCBRetryHints[hdir, recF], StringStartsQ[#, "Not eps-pure: J1"] &],
    AnyTrue[MCBRetryHints[hdir, recT], StringStartsQ[#, "Not eps-pure"] &]},
  {True, False, False, False, True, True, False},
  TestID -> "MCBFlaggedQ: an eps-form basis with an element that is not eps-pure is flagged, with a retry hint; pure or not known is not"]];
DeleteDirectory[hdir, DeleteContents -> True];

(* the automatic pass on a dlog sector with one master: the representation, the count of masters, the Picard-Fuchs label,
   the candidate routes and the reductions on the cut are planted (Block), and so is MCBElementPurity; the searches and
   the choice between them are the real ones. The pass is stopped where it would write its record *)
pt = {s -> 3, t -> -2};
rowOf = <|bubA -> {1 - 2 eps, (1 - 2 eps) eps, 0}, bubB -> {2, 2 eps - 1/3, 1/6}|>;   (* T, D, g: both eps-form, A = eps *)
plantedReduce[fam_, s0_, cs_, dir_, pts_] := Module[{rows = Lookup[rowOf, #["K"], Missing[]] & /@ cs},
  If[cs === {} || MemberQ[rows, _Missing], $Failed,
    {<|"point" -> pt, "masters" -> {m1}, "invariants" -> {s}, "T" -> List /@ rows[[All, 1]], "D" -> {List /@ rows[[All, 2]]}, "g" -> {rows[[All, 3]]}|>}]];
repB = <|"kind" -> "planted", "order" -> {1}, "isp" -> {}, "id" -> 1, "vars" -> {z}, "split" -> <|"Pr" -> 1|>,
   "geometry" -> <|"class" -> "rational", "nvars" -> 1, "text" -> "planted rational cut"|>|>;
pass[name_, route_List, more_ : {}, mapped_ : None, label_ : "polylog", singles_ : {}] := Module[{dir = FileNameJoin[{tmp, name, "box_analysis", SectorName[sB]}], out, calls = <||>},
  CreateDirectory[dir, CreateIntermediateDirectories -> True];
  Put[<|"FamilyFile" -> FileNameJoin[{ParentDirectory[DirectoryName[$InputFileName]], "examples", "box-one-loop", "family.wl"}]|>, FileNameJoin[{ParentDirectory[dir], "run_info.m"}]];
  out = Catch[Block[{MCBRepresentations, MCBPrintCutData, MCBCutMasters, MCBPicardFuchs, MCBRepeatedGeometry, MCBReduceCandidates, MCBCandidatesFor,
       MCBSingleCandidates, MCBProjectedCandidates, MCBStrictTargetCandidates, MCBProjectedPurifyCandidates, MCBPurifyCandidates, MCBStatusFor,
       MCBElementPurity = plantedElementPurity, MaximalCutBasis`AutoPass`Private`verdictFromSearch},
      MCBRepresentations[___] := {repB};
      MCBPrintCutData[___] := Null;
      MCBCutMasters[___] := <|"masters" -> {m1}, "n" -> 1, "rules" -> None|>;
      MCBPicardFuchs[___] := <|"label" -> label, "reason" -> "planted", "time" -> 0|>;
      MCBRepeatedGeometry[___] := If[mapped === None, {},
        {<|"from" -> "j0101", "status" -> "eps-form", "map" -> <|"lines" -> {2, 4}, "invariants" -> {}|>, "basis" -> mapped|>}];
      MCBReduceCandidates[a___] := plantedReduce[a];
      MCBCandidatesFor[___] := (calls["route"] = Lookup[calls, "route", 0] + 1; <|"status" -> "ok", "candidates" -> route|>);
      MCBSingleCandidates[___] := <|"status" -> "ok", "candidates" -> singles|>;
      MCBProjectedCandidates[___] := (calls["d-dim"] = Lookup[calls, "d-dim", 0] + 1; more);
      MCBStrictTargetCandidates[___] := <|"candidates" -> {}|>;
      MCBProjectedPurifyCandidates[___] := {};
      MCBPurifyCandidates[___] := {};
      MaximalCutBasis`AutoPass`Private`verdictFromSearch[red_, res_, fam_] := Throw[<|"Best" -> res|>, "stop"];
      MCBStatusFor[chk_, ___] := Throw[<|"Best" -> None, "Check" -> chk|>, "stop"];
      Block[{Print}, MCBAutoPass[box, sB, dir, <|"Points" -> {pt}|>]]], "stop"];
  Join[out, <|"Attempts" -> MCBReadAttempts[dir], "Calls" -> calls|>]];
kOf[r_] := If[AssociationQ[r["Best"]], #["K"] & /@ r["Best"]["cands"], None];
searchedOn[r_] := AnyTrue[r["Attempts"], Lookup[#, "what", ""] === "eps-pure elements" &];
mappedOutcome[r_] := Lookup[SelectFirst[r["Attempts"], StringContainsQ[Lookup[#, "what", ""], "mapped (repeated geometry)"] &, <||>], "outcome", None];
tmp = CreateDirectory[];
rP = pass["purity", {cand[bubA, "rep" -> {{1}, {}, "planted"}], cand[bubB, "r2" -> s, "rep" -> {{1}, {}, "planted"}]}];
AppendTo[tests, VerificationTest[{rP["Best"]["status"], kOf[rP], rP["Best"]["cands"][[1, "pure"]]}, {"eps-form", {bubB}, True},
  TestID -> "MCBAutoPass: of two eps-form candidates the one MCBElementPurity calls eps-pure is chosen, normalised by a square root"]];

(* the pass searches on while the eps-form basis has an element that is not eps-pure *)
dd = cand[bubB, "r2" -> s, "strict" -> True, "label" -> "d-dim dlog", "provenance" -> "planted builder", "rep" -> {{1}, {}, "planted"}];
rD = pass["d-dim", {cand[bubA, "rep" -> {{1}, {}, "planted"}]}, {dd}];
rN = pass["none", {cand[bubA, "rep" -> {{1}, {}, "planted"}]}];
rQ = pass["pure-route", {cand[bubB, "r2" -> s, "rep" -> {{1}, {}, "planted"}]}, {dd}];
rM = pass["mapped", {cand[bubB, "r2" -> s, "rep" -> {{1}, {}, "planted"}]}, {}, {bubA}];
(* MCBPurifyCandidates' eps-free twin of a candidate: the same K and r2, "strict" -> True, but a prefactor that is not a
   power of eps (the planted representation has none to show): it is judged on its own, and it is not pure *)
rT = pass["twin", {cand[bubA, "rep" -> {{1}, {}, "planted"}]}, {cand[bubA, "strict" -> True, "label" -> "d-dim single integral", "rep" -> {{1}, {}, "planted"}]}];
AppendTo[tests, VerificationTest[{kOf[rT], Lookup[rT["Best"]["cands"][[1]], "pure"], searchedOn[rT], Lookup[rT["Calls"], "route", 0]}, {{bubA}, False, True, 2},
  TestID -> "MCBAutoPass: a strict twin of a candidate that is not eps-pure is no eps-pure element"]];
(* an element whose purity check timed out is checked again before the pass counts its basis as done *)
timeoutOnce = {bubA}; timedOut = {};
rO = pass["timeout", {cand[bubA, "rep" -> {{1}, {}, "planted"}]}];
timeoutOnce = {};
AppendTo[tests, VerificationTest[{Lookup[rO["Best"]["cands"][[1]], "pure"], searchedOn[rO], Lookup[rO["Calls"], "route", 0]}, {False, True, 2},
  TestID -> "MCBAutoPass: a verdict the purity budget left open is checked again before the pass stops at an eps-form basis"]];
(* a non-dlog sector (a label that is not polylogarithmic): purity decides nothing there, and no candidate is checked *)
purityCalls = 0;
rE = pass["elliptic", {}, {}, None, "elliptic", {cand[bubA, "rep" -> {{1}, {}, "planted"}], cand[bubB, "r2" -> s, "rep" -> {{1}, {}, "planted"}]}];
AppendTo[tests, VerificationTest[{purityCalls, KeyExistsQ[First[rE["Best"]["cands"]], "pure"]}, {0, False},
  TestID -> "MCBAutoPass: a non-dlog sector runs no purity check"]];
AppendTo[tests, VerificationTest[{kOf[rD], rD["Best"]["cands"][[1, "pureDetail"]], searchedOn[rD], Lookup[rD["Calls"], "d-dim", 0], Lookup[rD["Calls"], "route", 0]},
  {{bubB}, "planted: True", True, 1, 1},
  TestID -> "MCBAutoPass: an eps-form basis that is not eps-pure is no end; the d-dimensional candidates give an eps-pure one"]];
AppendTo[tests, VerificationTest[{kOf[rN], rN["Best"]["status"], searchedOn[rN], Lookup[rN["Calls"], "route", 0]}, {{bubA}, "eps-form", True, 2},
  TestID -> "MCBAutoPass: without an eps-pure candidate the pass tries the larger pools too, and keeps the eps-form basis"]];
AppendTo[tests, VerificationTest[{kOf[rQ], searchedOn[rQ], Lookup[rQ["Calls"], "d-dim", 0], Lookup[rQ["Calls"], "route", 0]}, {{bubB}, False, 0, 1},
  TestID -> "MCBAutoPass: an eps-pure eps-form basis ends the pass at once"]];
AppendTo[tests, VerificationTest[{mappedOutcome[rM], Lookup[rM["Calls"], "route", 0], kOf[rM]}, {"eps-form", 1, {bubB}},
  TestID -> "MCBAutoPass: a mapped eps-form basis that is not eps-pure does not skip the searches, and an eps-pure one replaces it"]];

report = TestReport[tests];
Do[With[{r = report["TestResults"][id]},
    Print[If[r["Outcome"] === "Success", "PASS ", "FAIL "], r["TestID"], If[r["Outcome"] === "Success", "",
      "\n     got " <> ToString[Short[r["ActualOutput"], 3], InputForm] <> "\n     expected " <> ToString[Short[r["ExpectedOutput"], 3], InputForm]]]],
  {id, Keys[report["TestResults"]]}];
Print[report["TestsSucceededCount"], " passed, ", report["TestsFailedCount"], " failed, ", Round[report["TimeElapsed"], 0.1]];
DeleteDirectory[tmp, DeleteContents -> True];
Exit[If[report["AllTestsSucceeded"], 0, 1]];
