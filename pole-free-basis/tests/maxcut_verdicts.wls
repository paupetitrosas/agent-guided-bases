#!/usr/bin/env wolframscript
(* The maximal-cut gate's verdicts in rung 8 and PFBTryChange. Checked:
   - the finalists are ranked by the full rows first, as the scan ranks the sets (PFBScanKey), and the maximal cut
     (eps-form, the spread, the all-dot flag) only breaks ties among sets those keys rank equal;
   - "MaxCutChanged" -> False cannot switch the check off for a change that alters the maximal cut;
   - Kira failing (or missing) is no verdict: the change is "not tried" with the reason, and without Kira on the machine
     the check is skipped and the change listed as not verified; a failed verdict (the Euler relation, dependent
     elements, the wrong count) still refuses;
   - a verdict given with the change is used only when it is the maximal-cut gate's (Kira, or a planted check under the
     tests' "AllowPlantedCheck" -> True) on exactly this sector basis; a hand-made Association or a verdict for another
     basis is checked again; a planted check outside the tests is refused;
   - the all-dot flag only on a non-dlog sector (PFBMaxCutAllDotQ, bin/pair_scan.wls --maxcut).
   Planted data: the one-loop massless box family of the maximal-cut-basis examples with four masters (the two bubbles,
   s times the triangle, s t times the box), and with five (s^2 times the dotted triangle as the triangle sector's second
   master, for a change that mixes the sector's masters), one derivative (d/dt), planted slices and reductions (the same DE at the
   slice point and two extra points), and planted maximal-cut verdicts (MCBCheckBasis planted through "Check"). No IBP
   reduction, no Kira, no BaikovPackage.
   usage: bin/ws tests/maxcut_verdicts.wls        exit code 0 when every test passes *)
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
hasAll[str_String, l_List] := AllTrue[l, StringContainsQ[str, #] &];
hasAll[_, _] := False;
g = 1 - 2 eps;
Rp = {{-eps, 0, 0, 0}, {0, -2 eps, 0, 0}, {eps, 0, -2 eps, 0}, {eps + eps^2, 1 + eps, eps, -1 - 2 eps}};
oldOf[Rnew_, N_] := Together[Inverse[N] . Rnew . N];
redOf[Rold_, cands_List, pt_] := <|"Masters" -> ut /@ {1, 2, 3, 4}, "Point" -> pt, "Invariants" -> {t}, "Focus" -> {1, 2, 3, 4}, "Dm" -> {Rold}, "Pool" -> cands[[All, 1]],
   "Rp" -> Table[c[[3]]/(c[[2]] /. pt), {c, cands}],
   "dRp" -> {Table[With[{c0 = c[[2]] /. pt, dc = D[c[[2]], t] /. pt}, Together[((c[[3]] . Rold) - dc c[[3]]/c0)/c0]], {c, cands}]}|>;
cand = j[box, 1, 1, 2, 0]; other = j[box, 1, 2, 1, 0];
newRun[Rold_, name_] := Module[{dir = CreateDirectory[FileNameJoin[{tmp, name}]], st, sl = slice[Rold]},
  st = <|"Run" -> "none", "Created" -> PFBTimeStamp[], "Slices" -> {}, "Current" -> None, "Censuses" -> {}, "Accepted" -> {}, "Pending" -> {},
    "Rejected" -> {}, "Flagged" -> <||>, "Approval" -> False, "Regenerated" -> False|>;
  st = PFBStoreSlice[dir, st, sl, PFBCensus[sys, sl], "start"];
  <|"Run" -> <|"MaxEpsDegree" -> 2|>, "System" -> sys, "Dir" -> dir, "State" -> st|>];
withKira[on_, body_] := Block[{$MCBPaths = If[on, Append[$MCBPaths, "kira" -> $InputFileName], KeyDrop[$MCBPaths, "kira"]]}, body];
SetAttributes[withKira, HoldRest];

(* planted verdicts of MCBCheckBasis *)
calls = 0;
planted[res_][fam_, sec_, ms_, dir_, o_] := (calls++; Join[<|"points" -> {}, "nMastersCut" -> Length[ms], "message" -> "planted"|>, res]);
eulerOK = {<|"Name" -> "euler", "Pass" -> True, "Detail" -> "planted"|>};
epsForm = <|"status" -> "eps-form", "k" -> {0}, "range" -> {1, 1}, "checks" -> eulerOK|>;
poly1 = <|"status" -> "eps-polynomial", "k" -> {0}, "range" -> {0, 1}, "checks" -> eulerOK|>;
kiraFailed = <|"status" -> "failed", "message" -> "Kira failed (see a scratch folder)"|>;
dependent = <|"status" -> "failed", "message" -> "the basis elements are linearly dependent on the maximal cut"|>;
eulerFail = <|"status" -> "failed", "checks" -> {<|"Name" -> "euler", "Pass" -> False, "Detail" -> "planted"|>}, "message" -> "the maximal-cut DE breaks the Euler relation of homogeneous integrals"|>;
plantedOpts[res_] := <|"MaxCutCheckOptions" -> <|"Check" -> planted[res], "Representations" -> {}|>, "AllowPlantedCheck" -> True|>;

(* change 1: the triangle carries 1/(1 - 2 eps) towards the s-bubble, det T = 1 (the maximal cut kept: forced) *)
NT = {{1, 0, 0, 0}, {0, 1, 0, 0}, {1/g, 0, 1, 0}, {0, 0, 0, 1}}; RoT = oldOf[Rp, NT];
redsT = redOf[RoT, {{cand, s^2, NT[[3]]}, {other, s^2, {0, 0, 1, 0}}}, #] & /@ {P, P2, P3};
tryT[name_, defs_, opts_] := PFBTryChange[newRun[RoT, name], keyT, defs, <|"Rung" -> 8, "Provenance" -> "planted"|>, Join[<|"Reds" -> redsT, "MaxCutChanged" -> True|>, opts]];
(* change 2: five masters, the triangle's sector with two (labels 3 and 4); the new master of slot 3 has a component on
   ut[4], I'_3 = I_3 + I_4/(1 - 2 eps): it alters the maximal cut *)
Put[{j[box, 1, 0, 1, 0], j[box, 0, 1, 0, 1], s j[box, 1, 1, 1, 0], s^2 j[box, 2, 1, 1, 0], s t j[box, 1, 1, 1, 1]}, FileNameJoin[{tmp, "five.m"}]];
Put[<|"Name" -> "five", "Families" -> {<|"Name" -> "box", "Family" -> boxFile, "Masters" -> "five.m"|>}|>, FileNameJoin[{tmp, "five.wl"}]];
sys5 = PFBReadSystem[FileNameJoin[{tmp, "five.wl"}]];
Rp5 = {{-eps, 0, 0, 0, 0}, {0, -2 eps, 0, 0, 0}, {eps, 0, -2 eps, eps, 0}, {2 eps, 0, 0, -3 eps, 0}, {eps + eps^2, 1 + eps, eps, 0, -1 - 2 eps}};
Nm = ReplacePart[IdentityMatrix[5], 3 -> {0, 0, 1, 1/g, 0}]; Rm = oldOf[Rp5, Nm];
redsM = Function[pt, <|"Masters" -> ut /@ Range[5], "Point" -> pt, "Invariants" -> {t}, "Focus" -> Range[5], "Dm" -> {Rm}, "Pool" -> {cand},
    "Rp" -> {Nm[[3]]/(s^2 /. pt)}, "dRp" -> {{Together[(Nm[[3]] . Rm - (D[s^2, t] /. pt) Nm[[3]]/(s^2 /. pt))/(s^2 /. pt)]}}|>] /@ {P, P2, P3};
newRun5[name_] := Module[{dir = CreateDirectory[FileNameJoin[{tmp, name}]], st, sl},
  sl = <|"R" -> {Rm}, "Derivatives" -> {t}, "Point" -> P, "Labels" -> Range[5], "Index" -> AssociationThread[Range[5] -> Range[5]], "History" -> {}|>;
  st = <|"Run" -> "none", "Created" -> PFBTimeStamp[], "Slices" -> {}, "Current" -> None, "Censuses" -> {}, "Accepted" -> {}, "Pending" -> {},
    "Rejected" -> {}, "Flagged" -> <||>, "Approval" -> False, "Regenerated" -> False|>;
  st = PFBStoreSlice[dir, st, sl, PFBCensus[sys5, sl], "start"];
  <|"Run" -> <|"MaxEpsDegree" -> 2|>, "System" -> sys5, "Dir" -> dir, "State" -> st|>];
tryM[name_, opts_] := PFBTryChange[newRun5[name], keyT, <|3 -> s^2 cand|>, <|"Rung" -> 8, "Provenance" -> "planted"|>, Join[<|"Reds" -> redsM|>, opts]];

(* 1. the finalists' order: the scan's keys first *)
verd[st_, sp_, nd_, ad_, rf_ : False] := <|"Check" -> st, "Status" -> st, "Spread" -> sp, "NonDlog" -> nd, "AllDot" -> ad, "Refuses" -> rf|>;
ents = {
  <|"Name" -> "A: nothing deferred, eps-polynomial spread 1", "Result" -> <|"bad" -> 0, "newBad" -> 0, "over" -> 0, "deferred" -> 0|>,
    "Verdict" -> verd["eps-polynomial", 1, True, False]|>,
  <|"Name" -> "B: nothing deferred, eps-form", "Result" -> <|"bad" -> 0, "newBad" -> 0, "over" -> 0, "deferred" -> 0|>,
    "Verdict" -> verd["eps-form", 0, True, False]|>,
  <|"Name" -> "C: 4 poles deferred, eps-form", "Result" -> <|"bad" -> 0, "newBad" -> 0, "over" -> 0, "deferred" -> 4|>, "Verdict" -> verd["eps-form", 0, True, False]|>};
row[o___] := Join[<|"bad" -> 0, "newBad" -> 0, "over" -> 0, "zero" -> 0, "high" -> 0, "deferred" -> 0, "dCensus" -> -1, "neg" -> 0, "deg" -> 1|>, Association[o]];
ents2 = {<|"Name" -> "unchecked, best rows", "Result" -> row["dCensus" -> -3], "Verdict" -> Join[verd["failed", Infinity, True, False], <|"ToolFailure" -> "Kira failed"|>]|>,
   <|"Name" -> "eps-polynomial, census -2", "Result" -> row["dCensus" -> -2], "Verdict" -> verd["eps-polynomial", 2, True, False]|>,
   <|"Name" -> "eps-form, census -1", "Result" -> row[], "Verdict" -> verd["eps-form", 0, True, False]|>,
   <|"Name" -> "spread 1, census -2", "Result" -> row["dCensus" -> -2], "Verdict" -> verd["eps-polynomial", 1, True, False]|>};
tests = {
  VerificationTest[StringTake[#, 1] & /@ Lookup[PFBMaxCutRank[ents], "Name"], {"B", "A", "C"},
    TestID -> "finalists: deferred poles rank a set last, eps-form on the cut breaks the tie of the others"],
  VerificationTest[{Lookup[PFBMaxCutRank[ents2], "Name"], Lookup[PFBMaxCutRank[ents2], "NotChecked"], Lookup[PFBMaxCutRank[ents2], "Refused"]},
    {{"spread 1, census -2", "eps-polynomial, census -2", "eps-form, census -1", "unchecked, best rows"}, {False, False, False, True}, {False, False, False, False}},
    TestID -> "finalists: the census before eps-form, the spread at equal rows; a set the gate could not check after the checked ones, not refused"],
  VerificationTest[{PFBScanKey[<|"bad" -> 0|>][[2 ;; 3]], Ordering[PFBScanKey /@ {row["deg" -> 2], row["deg" -> 1], row["neg" -> 1]}]}, {{Infinity, Infinity}, {2, 1, 3}},
    TestID -> "PFBScanKey: a missing key counts as the worst; the census's negative powers before the power of eps"]
};

(* 2. "MaxCutChanged" -> False cannot switch the check off *)
calls = 0;
rM = tryM["maxcut-false", Join[<|"MaxCutChanged" -> False|>, plantedOpts[eulerFail]]];
AppendTo[tests, VerificationTest[{rM["Status"], failing[rM["Gate"]], rM["Record"]["MaxCutChanged"], calls}, {"rejected", {"maximal cut"}, True, 1},
  TestID -> "MaxCutChanged -> False: a change that alters the maximal cut is still checked, and refused here"]];

(* 3. tool failures and genuine failures *)
rK = tryT["kira-failed", <|3 -> s^2 cand|>, plantedOpts[kiraFailed]];
AppendTo[tests, VerificationTest[{rK["Status"], hasAll[rK["Message"], {"Kira failed", "not recorded"}], Length[rK["Context"]["State"]["Rejected"]], KeyExistsQ[rK, "Record"]},
  {"not tried", True, 0, False}, TestID -> "Kira failing is no verdict: the change is not tried, with the reason, and nothing is recorded as rejected"]];
rD = tryT["dependent", <|3 -> s^2 cand|>, plantedOpts[dependent]];
AppendTo[tests, VerificationTest[{rD["Status"], failing[rD["Gate"]], StringContainsQ[checkOf[rD["Gate"], "maximal cut"]["Detail"], "linearly dependent"]}, {"rejected", {"maximal cut"}, True},
  TestID -> "a failed verdict (dependent elements on the cut) still refuses"]];
rN = withKira[False, tryT["no-kira", <|3 -> s^2 cand|>, <||>]];
PFBMakeReports[rN["Context"]["Dir"], rN["Context"]["System"], rN["Context"]["State"]];
chN = Import[FileNameJoin[{rN["Context"]["Dir"], "CHANGES.md"}], "Text"];
AppendTo[tests, VerificationTest[{rN["Status"], TrueQ[checkOf[rN["Gate"], "maximal cut"]["NotChecked"]], StringStartsQ[rN["Record"]["MaxCutCheck"]["Skipped"], "Kira is not available on this machine"],
    hasAll[chN, {"Not verified", "the maximal-cut-basis gate did not run on the new basis (Kira is not available on this machine"}]},
  {"accepted", True, True, True}, TestID -> "no Kira on the machine: the check is skipped by itself and the change listed as not verified"]];
fv = PFBMaxCutCheck[sys, keyT, <|3 -> s^2 cand|>, <|"Check" -> planted[kiraFailed], "Representations" -> {}|>];
AppendTo[tests, VerificationTest[{fv["Refuses"], StringQ[fv["ToolFailure"]], fv["Tool"]}, {False, True, "planted"},
  TestID -> "PFBMaxCutCheck: Kira failing is a tool failure, not a refusal; a planted check says so"]];

(* 4. verdicts given with the change *)
calls = 0;
vGood = Join[PFBMaxCutCheck[sys, keyT, <|3 -> s^2 cand|>, <|"Check" -> planted[poly1], "Representations" -> {}|>], <|"Tool" -> "Kira (MCBCheckBasis)"|>];
vOther = Join[PFBMaxCutCheck[sys, keyT, <|3 -> s^2 other|>, <|"Check" -> planted[poly1], "Representations" -> {}|>], <|"Tool" -> "Kira (MCBCheckBasis)"|>];
calls = 0;
rG = tryT["given", <|3 -> s^2 cand|>, Join[plantedOpts[epsForm], <|"MaxCutCheck" -> vGood|>]];
rO = tryT["given-other", <|3 -> s^2 cand|>, Join[plantedOpts[epsForm], <|"MaxCutCheck" -> vOther|>]];
rH = tryT["hand-made", <|3 -> s^2 cand|>, Join[plantedOpts[epsForm], <|"MaxCutCheck" -> <|"Status" -> "eps-form", "Check" -> "eps-form", "Refuses" -> False, "Defs" -> <|3 -> s^2 cand|>|>|>]];
AppendTo[tests, VerificationTest[{rG["Record"]["MaxCutCheck"]["Check"], KeyExistsQ[rG["Record"]["MaxCutCheck"], "Given"], rO["Record"]["MaxCutCheck"]["Check"],
    StringContainsQ[rO["Record"]["MaxCutCheck"]["Given"], "for another basis"], rH["Record"]["MaxCutCheck"]["Check"], StringContainsQ[rH["Record"]["MaxCutCheck"]["Given"], "lacks the fields"], calls},
  {"eps-polynomial", False, "eps-form", True, "eps-form", True, 2},
  TestID -> "a verdict of the gate on this basis is recorded as given; one for another basis, or a hand-made one, is checked again and the record says why"]];
vPl = PFBMaxCutCheck[sys, keyT, <|3 -> s^2 cand|>, <|"Check" -> planted[poly1], "Representations" -> {}|>];
rPl = withKira[False, tryT["planted-given", <|3 -> s^2 cand|>, <|"MaxCutCheck" -> vPl|>]];
rPc = tryT["planted-check", <|3 -> s^2 cand|>, <|"MaxCutCheckOptions" -> <|"Check" -> planted[epsForm], "Representations" -> {}|>|>];
AppendTo[tests, VerificationTest[{StringContainsQ[rPl["Record"]["MaxCutCheck"]["Given"], "its tool is \"planted\""], KeyExistsQ[rPl["Record"]["MaxCutCheck"], "Skipped"],
    rPc["Status"], StringContainsQ[rPc["Message"], "for tests only"]},
  {True, True, "not tried", True}, TestID -> "a planted verdict or check outside the tests is not taken"]];

(* 5. the all-dot flag only on a non-dlog sector *)
AppendTo[tests, VerificationTest[{PFBMaxCutAllDotQ[sys, keyT, <|3 -> s^2 cand|>, True], PFBMaxCutAllDotQ[sys, keyT, <|3 -> s^2 cand|>, False],
    PFBMaxCutAllDotQ[sys, keyT, <|3 -> s^2 cand|>, Missing["NoRun"]], PFBMaxCutAllDotQ[sys, keyT, <|3 -> s j[box, 1, 1, 1, 0]|>, True]},
  {True, False, False, False}, TestID -> "PFBMaxCutAllDotQ: every element dotted, on a non-dlog sector only"]];

report = TestReport[tests];
Do[With[{r = report["TestResults"][id]},
    Print[If[r["Outcome"] === "Success", "PASS ", "FAIL "], r["TestID"], If[r["Outcome"] === "Success", "",
      "\n     got " <> ToString[Short[r["ActualOutput"], 3], InputForm] <> "\n     expected " <> ToString[Short[r["ExpectedOutput"], 3], InputForm]]]],
  {id, Keys[report["TestResults"]]}];
Print[report["TestsSucceededCount"], " passed, ", report["TestsFailedCount"], " failed, ", Round[report["TimeElapsed"], 0.1]];
DeleteDirectory[tmp, DeleteContents -> True];
Exit[If[report["AllTestsSucceeded"], 0, 1]];
