#!/usr/bin/env wolframscript
(* The determinant of a change is recorded, not judged. det T, the new masters on the replaced ones, only has to be
   non-zero (PFBApplyChange): a change whose determinant is not an eps-monomial passes the gate like any other, defers
   new poles like any other, needs extra points only when its coefficients were fitted, waits for approval only in
   approval mode, and does not count, by its determinant, as a change of the maximal cut. The gate reads only what the
   DE shows: a weight on a master that no row shows as a pole passes, and the eps degree of its column is its only trace.
   Planted data: the one-loop massless box family of the maximal-cut-basis examples with four masters, the two bubbles
   (labels 1 and 2), s times the triangle j[box, 1, 1, 1, 0] (label 3, a clean lower sector) and s t times the box (label
   4), one derivative (d/dt). A change is planted as new masters J' = N J with a target DE R' in the new basis: the old
   slice is N^-1 R' N, and a candidate integral reduces to N[[m]] with the derivative N[[m]].R_old. A hidden weight
   I_3 = w J_3, w = 1 + 4 eps, leaves the triangle's own rows clean and puts 1/w into column 3 of the box row; the fix has
   det T = 1/w. The mirror case I_3 = J_3/w puts 1/w into row 3 towards the s-bubble; the fix has det T = w. Checked:
   the gate, PFBTryChange with planted reductions (the slice point and extra points), the approval mode, deferred
   poles, the scans, the derivative search (rung 7), the removed options ReferenceBasis and ReferenceDet, and the
   records and pages, old records with a reference basis included. No IBP reduction, no FiniteFlow.
   usage: bin/ws tests/determinant.wls        exit code 0 when every test passes *)
Get[FileNameJoin[{ParentDirectory[DirectoryName[$InputFileName]], "lib", "PoleFreeBasis.wl"}]];
$PFBVerbose = False;
boxFile = FileNameJoin[{ParentDirectory[ParentDirectory[DirectoryName[$InputFileName]]], "maximal-cut-basis", "examples", "box-one-loop", "family.wl"}];
tmp = CreateDirectory[];
loadSystem[masters_, name_] := (Put[masters, FileNameJoin[{tmp, name <> ".m"}]];
  Put[<|"Name" -> name, "Families" -> {<|"Name" -> "box", "Family" -> boxFile, "Masters" -> name <> ".m"|>}|>, FileNameJoin[{tmp, name <> ".wl"}]];
  PFBReadSystem[FileNameJoin[{tmp, name <> ".wl"}]]);
sys = loadSystem[{j[box, 1, 0, 1, 0], j[box, 0, 1, 0, 1], s j[box, 1, 1, 1, 0], s t j[box, 1, 1, 1, 1]}, "planted"];
keyT = {box, {1, 1, 1, 0}}; keyB2 = {box, {0, 1, 0, 1}}; keyBox = {box, {1, 1, 1, 1}};
P = {s -> 1, t -> 3/7}; P2 = {s -> 1, t -> 5/11}; P3 = {s -> 1, t -> 2/13};   (* the slice point and two extra points *)
slice[R_] := <|"R" -> {R}, "Derivatives" -> {t}, "Point" -> P, "Labels" -> {1, 2, 3, 4}, "Index" -> <|1 -> 1, 2 -> 2, 3 -> 3, 4 -> 4|>, "History" -> {}|>;
checkOf[g_, name_] := SelectFirst[g["Checks"], #["Name"] === name &, <||>];
failing[g_] := #["Name"] & /@ Select[g["Checks"], ! #["Pass"] &];
sameR[a_, b_] := AllTrue[Flatten[Together[a - b]], # === 0 &];
w = 1 + 4 eps; g = 1 - 2 eps;

(* the target DE in the honest basis: pole-free *)
Rp = {{-eps, 0, 0, 0}, {0, -2 eps, 0, 0}, {eps, 0, -2 eps, 0}, {eps + eps^2, 1 + eps, eps, -1 - 2 eps}};
oldOf[Rnew_, N_] := Together[Inverse[N] . Rnew . N];
(* a reduction at a point: masters (labels), focus rows of the old DE, and candidates {integral, coefficient, H} whose
   definition coefficient * integral is the new master H . old (its derivative H . R_old) *)
redOf[Rold_, cands_List, pt_ : P, focus_ : {1, 2, 3, 4}, masters_ : {1, 2, 3, 4}] := <|"Masters" -> ut /@ masters, "Point" -> pt, "Invariants" -> {t},
   "Focus" -> focus, "Dm" -> {Rold[[focus, masters]]}, "Pool" -> cands[[All, 1]],
   "Rp" -> Table[c[[3, masters]]/(c[[2]] /. pt), {c, cands}],
   "dRp" -> {Table[With[{c0 = c[[2]] /. pt, dc = D[c[[2]], t] /. pt}, Together[((c[[3]] . Rold)[[masters]] - dc c[[3, masters]]/c0)/c0]], {c, cands}]}|>;
cand3 = j[box, 1, 1, 2, 0]; def3 = <|3 -> s^2 cand3|>;
red3[Rold_, N_, rest___] := redOf[Rold, {{cand3, s^2, N[[3]]}}, rest];
change[Rold_, N_, m_] := <|"Name" -> "planted", "Key" -> PFBMaster[sys, m]["SectorKey"], "Kind" -> "change", "Replace" -> {m}, "H" -> {N[[m]]},
   "G" -> {{Together[N[[m]] . Rold]}}, "NewDefs" -> <|m -> PFBMaster[sys, m]["RootFree"]|>|>;

(* a run with the old slice as its current slice *)
newRun[Rold_, name_, approval_ : False] := Module[{dir = CreateDirectory[FileNameJoin[{tmp, name}]], st, sl = slice[Rold]},
  st = <|"Run" -> "none", "Created" -> PFBTimeStamp[], "Slices" -> {}, "Current" -> None, "Censuses" -> {}, "Accepted" -> {}, "Pending" -> {},
    "Rejected" -> {}, "Flagged" -> <||>, "Approval" -> approval, "Regenerated" -> False|>;
  st = PFBStoreSlice[dir, st, sl, PFBCensus[sys, sl], "start"];
  <|"Run" -> <|"MaxEpsDegree" -> 2|>, "System" -> sys, "Dir" -> dir, "State" -> st|>];
try[ctx_, reds_, key_ : keyT, defs_ : def3, opts_ : <||>] := PFBTryChange[ctx, key, defs, <|"Rung" -> 8, "Provenance" -> "planted"|>, Join[<|"Reds" -> reds|>, opts]];
current[r_] := PFBCurrentSlice[r["Context"]["Dir"], r["Context"]["State"]];

(* the planted cases *)
Na = DiagonalMatrix[{1, 1, 1/w, 1}]; Ra = oldOf[Rp, Na];          (* hidden weight on ut[3]: det T = 1/w *)
Nb = DiagonalMatrix[{1, 1, w, 1}]; Rb = oldOf[Rp, Nb];            (* the mirror: det T = w *)
redA[pt_ : P] := red3[Ra, Na, pt]; redB[pt_ : P] := red3[Rb, Nb, pt, {1, 3}, {1, 3}];      (* redB: the triangle's subtree only *)
at3[f_] := f /@ {P, P2, P3};   (* reductions at the slice point and at two extra points *)

tests = {
  VerificationTest[sys =!= $Failed && Length[PFBMasters[sys]] == 4, True, TestID -> "the planted system loads"],
  (* the planted old slices: the hidden weight shows only in column 3 of the box row, the mirror only in row 3 *)
  VerificationTest[With[{c = PFBCensus[sys, slice[Ra]]}, {c["BadEntries"], c["Sectors"][keyT]["BadRows"]}], {{{1, 4, 3, {w}}}, {}},
    TestID -> "hidden weight: the triangle's rows are clean, the box row has 1/w in column 3"],
  VerificationTest[PFBCensus[sys, slice[Rb]]["BadEntries"], {{1, 3, 1, {w}}}, TestID -> "mirror: 1/w in row 3 towards the s-bubble"],
  (* the gate on the slice: no determinant check, no approval *)
  VerificationTest[With[{sl = slice[Ra], ch = change[Ra, Na, 3]}, With[{gt = PFBGate[sys, sl, PFBCensus[sys, sl], PFBApplyChange[sl, ch], ch]},
      {gt["Pass"], failing[gt], checkOf[gt, "determinant"], KeyExistsQ[gt, "NeedsApproval"], Together[Last[PFBApplyChange[sl, ch]["History"]]["DetT"] - 1/w]}]],
    {True, {}, <||>, False, 0}, TestID -> "gate: det T = 1/w is recorded in the slice's history, and no check judges it"]
};

(* PFBTryChange: the hidden weight, reductions of the whole system at the extra points *)
rA = try[newRun[Ra, "hidden"], at3[redA]];
AppendTo[tests, VerificationTest[{rA["Status"], rA["Gate"]["Pass"], Together[rA["Record"]["Determinant"] - 1/w], rA["Record"]["MaxCutChanged"], rA["Record"]["MaxCutCheck"],
    Intersection[Keys[rA["Record"]], {"WeightEvidence", "NeedsApproval"}], sameR[current[rA]["R"], {Rp}]},
  {"accepted", True, 0, False, Missing["NotNeeded"], {}, True},
  TestID -> "hidden weight: accepted with det T = 1/w, a rescaling on the cut, not a change of the maximal cut"]];
(* approval mode: pending like any change, accepted once approved *)
rAp = try[newRun[Ra, "hidden-approval", True], at3[redA]];
apA = PFBApprove[rAp["Context"]["Dir"], rAp["Context"]["State"], rAp["Context"]["System"], rAp["Record"]["Id"]];
AppendTo[tests, VerificationTest[{rAp["Status"], Lookup[#, "Id"] & /@ apA["State"]["Accepted"], apA["State"]["Pending"], sameR[PFBCurrentSlice[rAp["Context"]["Dir"], apA["State"]]["R"], {Rp}]},
  {"pending", {rAp["Record"]["Id"]}, {}, True}, TestID -> "approval mode: pending, and accepted once approved"]];

(* the mirror, with the triangle's subtree as the reductions *)
rB = try[newRun[Rb, "mirror"], at3[redB]];
AppendTo[tests, VerificationTest[{rB["Status"], Together[rB["Record"]["Determinant"] - w], rB["Record"]["PointsVerified"], sameR[current[rB]["R"], {Rp}]},
  {"accepted", 0, 2, True}, TestID -> "mirror: accepted with det T = w"]];

(* a weight the DE does not show: the old basis carried g = 1 - 2 eps on the t-bubble, and the change divides it by g w.
   It removes g, and puts the weight 1/w on a master whose row has nothing off the diagonal: no row shows it as a pole,
   so the change passes; the box row's entry in its column is (1 + eps) w, one power of eps higher *)
Nu = DiagonalMatrix[{1, 1/g, 1, 1}]; Rc = oldOf[Rp, Nu];
Nc = DiagonalMatrix[{1, 1/(g w), 1, 1}];
candB = j[box, 0, 2, 0, 1];
redC[pt_] := redOf[Rc, {{candB, t, Nc[[2]]}}, pt];
rC = try[newRun[Rc, "unseen"], at3[redC], keyB2, <|2 -> t candB|>];
AppendTo[tests, VerificationTest[{rC["Status"], Together[rC["Record"]["Determinant"] - 1/(g w)], PFBCensus[sys, current[rC]]["BadEntries"],
    Together[current[rC]["R"][[1, 4, 2]] - (1 + eps) w]},
  {"accepted", 0, {}, 0}, TestID -> "a weight no row shows as a pole passes: only the eps degree of its column rises"]];

(* locality: ut[2] carries w as well, for an independent reason; the change fixes ut[3] only and leaves (4, 2) as it was *)
Rd = oldOf[Rp, DiagonalMatrix[{1, 1/w, 1/w, 1}]];
rD = try[newRun[Rd, "locality"], at3[red3[Rd, Na, #] &]];
AppendTo[tests, VerificationTest[{rD["Status"], rD["Gate"]["Census"]["BadEntries"]}, {"accepted", {{1, 4, 2, {w}}}},
  TestID -> "w left in an entry the change does not alter: accepted, the entry kept for its own sector"]];

(* a new pole elsewhere: the change ut[3] -> I_3/w + I_1/g removes the g-pole of row 3 and puts g into (4, 1). The box
   takes it as a deferred pole, as for any change *)
lam = 1/g; Ne = {{1, 0, 0, 0}, {0, 1, 0, 0}, {lam, 0, 1/w, 0}, {0, 0, 0, 1}};
Ree = ReplacePart[Rp, {4, 1} -> Rp[[4, 1]] - Rp[[4, 3]] lam]; RoE = oldOf[Ree, Ne];
rE = try[newRun[RoE, "newpole"], at3[red3[RoE, Ne, #] &]];
AppendTo[tests, VerificationTest[{PFBCensus[sys, slice[RoE]]["BadEntries"], rE["Status"], Keys[checkOf[rE["Gate"], "rows"]["Deferred"]],
    checkOf[rE["Gate"], "rows"]["Deferred"][keyBox]["Rows"], Together[rE["Record"]["Determinant"] - 1/w]},
  {{{1, 3, 1, {g}}, {1, 4, 3, {w}}}, "accepted", {keyBox}, {4}, 0}, TestID -> "a new pole above: deferred to its sector, whatever the determinant"]];

(* extra points: a change that is not fitted (rung 8) needs none, whatever its determinant *)
rF = try[newRun[Ra, "points-none"], {redA[P]}];
AppendTo[tests, VerificationTest[{rF["Status"], rF["Record"]["PointsVerified"], checkOf[rF["Gate"], "points"]}, {"accepted", 0, <||>},
  TestID -> "extra points: none needed for an exact change with det T = 1/w"]];

(* the scans do not look at the determinant: two sets that clear the rows, with det T = 1/w and 1/(w (1 + 3 eps)), rank
   equal. Row 3 without its lower coupling, so that dividing ut[3] by another factor leaves the sector's rows clean too *)
Ra0 = oldOf[ReplacePart[Rp, {3, 1} -> 0], Na];
redS = redOf[Ra0, {{cand3, s^2, Na[[3]]}, {j[box, 2, 1, 1, 0], s^2, DiagonalMatrix[{1, 1, 1/(w (1 + 3 eps)), 1}][[3]]}}];
calS = PFBCalibrate[slice[Ra0], redS];
scanS = PFBScanSets[sys, slice[Ra0], redS, calS, keyT, {<|3 -> s^2 j[box, 2, 1, 1, 0]|>, <|3 -> s^2 cand3|>}, <|"FullCensus" -> True|>];
AppendTo[tests, VerificationTest[{calS["Status"], Lookup[#, {"bad", "newBad"}] & /@ scanS["Results"], Equal @@ (PFBScanKey /@ scanS["Results"]),
    AnyTrue[scanS["Results"], KeyExistsQ[#, "det"] || KeyExistsQ[#, "detMonomial"] || KeyExistsQ[#, "detEvidence"] &]},
  {"exact", {{0, 0}, {0, 0}}, True, False}, TestID -> "scan: two sets that clear the rows rank equal whatever their determinants"]];

(* the derivative search (rung 7): two planted operators on the clean master of the triangle sector, one with an
   eps-monomial determinant, one with eps (1 + 4 eps); both are kept *)
sys5 = loadSystem[{j[box, 1, 0, 1, 0], j[box, 0, 1, 0, 1], s j[box, 1, 1, 1, 0], s^2 j[box, 2, 1, 1, 0], s t j[box, 1, 1, 1, 1]}, "five"];
row3s = {0, 0, -eps, eps, 0}; row3t = {0, 0, -2 eps, eps w, 0};
sl5 = <|"R" -> {ReplacePart[ConstantArray[0, {5, 5}], 3 -> row3s], ReplacePart[ConstantArray[0, {5, 5}], 3 -> row3t]}, "Derivatives" -> {s, t}, "Point" -> P,
   "Labels" -> Range[5], "Index" -> AssociationThread[Range[5] -> Range[5]], "History" -> {}|>;
ds = Block[{PFBGramFreeOperators, PFBApplyOperator, Print},
   PFBGramFreeOperators[___] := {{{s, 1}}, {{t, 1}}};
   PFBApplyOperator[_, _, op_, def_, _] := opOf[op] def;
   PFBDerivativeSearch[sys5, sl5, keyT, {4}]];
AppendTo[tests, VerificationTest[{Sort[Lookup[ds, "Det"]], Sort[Lookup[ds, "Ops"]], AnyTrue[ds, KeyExistsQ[#, "NeedsEvidence"] &]}, {Sort[{eps, eps w}], Sort[{{{{s, 1}}}, {{{t, 1}}}}], False},
  TestID -> "derivative search: both choices are kept, the one whose determinant is not an eps-monomial unmarked"]];

(* the removed options *)
AppendTo[tests, VerificationTest[With[{r = try[newRun[Ra, "reference"], at3[redA], keyT, def3, <|"ReferenceBasis" -> <|3 -> s j[box, 1, 1, 1, 0]|>, "ReferenceSource" -> "a paper"|>]},
    {r["Status"], StringStartsQ[r["Message"], "removed: the options ReferenceBasis and ReferenceSource no longer exist"]}], {"not tried", True}, TestID -> "ReferenceBasis: refused, with the reason"]];
AppendTo[tests, VerificationTest[Block[{Print}, PFBDerivativeSearch[sys, slice[Rp], keyT, {3}, <|"ReferenceDet" -> 1|>]], $Failed, TestID -> "ReferenceDet of the derivative search: refused"]];

(* records and pages: the accepted change, and an old record with a reference basis (a change of the maximal cut) *)
stR = rA["Context"]["State"];
oldRec = Join[First[stR["Accepted"]], <|"Id" -> 7, "Name" -> "an old change", "Determinant" -> eps^2 (1 - 4 eps), "MaxCutChanged" -> True,
   "ReferenceSource" -> "a planted paper", "DetReference" -> 1 - 4 eps, "DetOnReference" -> eps^2,
   "ReferenceWarnings" -> {"the reference equals the candidate on the maximal cut for {ut[3]}: the determinant check is then vacuous and rule 5 rests on the reference's source"}|>];
stR["Accepted"] = Append[stR["Accepted"], oldRec];
summaryR = Quiet[PFBMakeReports[rA["Context"]["Dir"], rA["Context"]["System"], stR]];
changesR = Import[FileNameJoin[{rA["Context"]["Dir"], "CHANGES.md"}], "Text"];
AppendTo[tests, VerificationTest[{StringContainsQ[changesR, "`" <> ToString[Factor[1/w], InputForm] <> "`"], StringContainsQ[changesR, "on the reference basis (a planted paper)"],
    StringContainsQ[changesR, "the determinant check of that version rested on the reference's source (a planted paper)"], StringContainsQ[changesR, {"ule 5", "evidence"}]},
  {True, True, True, False}, TestID -> "CHANGES.md: the determinant in the summary, an old record with a reference basis still shown, no rule on the determinant"]];
AppendTo[tests, VerificationTest[With[{h = Import[summaryR, "Text"], sec = Import[FileNameJoin[{PFBSectorDir[rA["Context"]["Dir"], keyT], "sector.html"}], "Text"]},
    {StringContainsQ[h, "on the reference basis (a planted paper)"], StringContainsQ[sec, "on the reference basis (a planted paper)"], StringContainsQ[h, {"ule 5", "evidence"}],
     StringContainsQ[sec, {"ule 5", "evidence"}]}],
  {True, True, False, False}, TestID -> "pages: the summary and the sector page show the old record, and no rule on the determinant"]];

report = TestReport[tests];
Do[With[{r = report["TestResults"][id]},
    Print[If[r["Outcome"] === "Success", "PASS ", "FAIL "], r["TestID"], If[r["Outcome"] === "Success", "",
      "\n     got " <> ToString[Short[r["ActualOutput"], 3], InputForm] <> "\n     expected " <> ToString[Short[r["ExpectedOutput"], 3], InputForm]]]],
  {id, Keys[report["TestResults"]]}];
Print[report["TestsSucceededCount"], " passed, ", report["TestsFailedCount"], " failed, ", Round[report["TimeElapsed"], 0.1]];
DeleteDirectory[tmp, DeleteContents -> True];
Exit[If[report["AllTestsSucceeded"], 0, 1]];
