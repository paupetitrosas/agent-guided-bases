#!/usr/bin/env wolframscript
(* Rung 8 through the maximal-cut-basis toolkit. Checked: system.wl "MCBRun" (read and validated, never written into);
   the skill's own run when there is none; the filter of candidates before any reduction (hard rules 1, 2 and 4, the
   square root of the master each replaces, the slot's power of eps); the run's basis and its replayed steps as
   candidates; per-slot candidates in the scans; the verdict of the maximal-cut gate; the order of the finalists (rows
   first, then eps-form, the smaller spread and the all-dot flag); PFBTryChange requiring the maximal-cut check for a
   change that alters the maximal cut, running it when no verdict is given, recording it, refusing a set that fails it,
   and skipping it only where Kira is not available; the records and pages.
   Planted data: the one-loop massless box and the equal-mass bubble of the maximal-cut-basis examples, planted slices,
   reductions and maximal-cut verdicts (MCBCheckBasis is planted through the option "Check"). No IBP reduction, no
   Kira, no BaikovPackage.
   usage: bin/ws tests/maxcut_rung8.wls        exit code 0 when every test passes *)
Get[FileNameJoin[{ParentDirectory[DirectoryName[$InputFileName]], "lib", "PoleFreeBasis.wl"}]];
$PFBVerbose = False;
ex = FileNameJoin[{ParentDirectory[ParentDirectory[DirectoryName[$InputFileName]]], "maximal-cut-basis", "examples"}];
boxFile = FileNameJoin[{ex, "box-one-loop", "family.wl"}]; bubFile = FileNameJoin[{ex, "bubble-massive", "family.wl"}];
tmp = CreateDirectory[];
writeSystem[name_, fams_, extra_ : <||>] := (Put[Join[<|"Name" -> name, "Families" -> fams|>, extra], FileNameJoin[{tmp, name <> ".wl"}]]; PFBReadSystem[FileNameJoin[{tmp, name <> ".wl"}]]);
errorsOf[sys_] := Select[PFBValidateSystem[sys]["Errors"], StringContainsQ[#, "MCBRun"] &];
listing[d_] := Sort[FileNames["*", d, Infinity]];
hasAll[str_String, l_List] := AllTrue[l, StringContainsQ[str, #] &];
hasAll[_, _] := False;
checkOf[g_, name_] := SelectFirst[g["Checks"], #["Name"] === name &, <||>];
failing[g_] := #["Name"] & /@ Select[g["Checks"], ! #["Pass"] &];

(* a planted maximal-cut-basis run of the box: run_info.m, and the triangle's sector with its basis, record and script *)
mcb = FileNameJoin[{tmp, "box_analysis"}]; CreateDirectory[FileNameJoin[{mcb, "j1110"}], CreateIntermediateDirectories -> True];
Put[<|"Run" -> <|"AutoPass" -> <|"nd" -> 2|>|>, "FamilyFile" -> boxFile, "OutputDir" -> mcb|>, FileNameJoin[{mcb, "run_info.m"}]];
Put[{eps s j[box, 1, 1, 1, 0]}, FileNameJoin[{mcb, "j1110", "masters.m"}]];
Put[<|"status" -> "eps-form", "sector" -> {1, 1, 1, 0}, "masters" -> {<|"definition" -> eps s j[box, 1, 1, 1, 0], "label" -> "dlog"|>}, "classification" -> <|"label" -> "polylog"|>,
  "points" -> {{s -> 3, t -> 5}, {s -> 7, t -> 11}}|>, FileNameJoin[{mcb, "j1110", "basis.m"}]];
Export[FileNameJoin[{mcb, "j1110", "AnalysisMasters.m"}], "(* planted *)\nsector = {1, 1, 1, 0};\nreps = MCBRepresentations[fam, sector, <|\"Extra\" -> 1, \"Standard\" -> False|>];\n" <>
  "cd = reps[[2]];\nsteps = {<|\"call\" -> \"single\", \"rep\" -> {\"loop-by-loop\", {1}, {}}, \"opts\" -> <|\"nd\" -> 2, \"nmi\" -> Automatic|>|>};\n" <>
  "cands = MCBReplayCandidates[fam, sector, reps, steps, <|\"cd\" -> cd|>];\n", "Text"];
CreateDirectory[FileNameJoin[{tmp, "empty"}]];
otherFam = FileNameJoin[{tmp, "box_other.wl"}];
Put[Join[Get[boxFile], <|"Propagators" -> ReplacePart[Get[boxFile]["Propagators"], {4, "Momentum"} -> k + p1 + p3]|>], otherFam];
mcbOther = FileNameJoin[{tmp, "other_analysis"}]; CreateDirectory[mcbOther]; Put[<|"FamilyFile" -> otherFam|>, FileNameJoin[{mcbOther, "run_info.m"}]];
mcbBub = FileNameJoin[{tmp, "bub_analysis"}]; CreateDirectory[mcbBub]; Put[<|"FamilyFile" -> bubFile|>, FileNameJoin[{mcbBub, "run_info.m"}]];
Put[{j[box, 1, 0, 1, 0], j[box, 0, 1, 0, 1], s j[box, 1, 1, 1, 0], s t j[box, 1, 1, 1, 1]}, FileNameJoin[{tmp, "box.m"}]];
boxEntry[run_] := Join[<|"Name" -> "box", "Family" -> boxFile, "Masters" -> "box.m"|>, If[run === None, <||>, <|"MCBRun" -> run|>]];
(* the run's ledger: the triangle's credits, which a change that takes from the run carries, stamped with its id *)
Scan[PutAppend[#, FileNameJoin[{mcb, "citations.m"}]] &, {<|"kind" -> "tool", "tool" -> "BaikovPackage", "sector" -> "j1110", "step" -> "first pass", "date" -> "2026-01-01"|>,
   <|"kind" -> "paper", "reference" -> "A. Author, Planted paper of the triangle, JHEP 01 (2021) 001, arXiv:2106.00012", "sector" -> "j1110",
     "used" -> "the triangle's dlog form", "result" -> "adopted", "date" -> "2026-01-01"|>}];
before = listing[mcb];

sysR = writeSystem["withrun", {boxEntry["box_analysis"]}];
tests = {
  VerificationTest[{sysR["Families"][box]["MCBRun"], errorsOf[sysR]}, {mcb, {}}, TestID -> "MCBRun: read relative to system.wl, a run of the same family passes"],
  VerificationTest[{hasAll[First[errorsOf[writeSystem["norun", {boxEntry["empty"]}]], ""], {"not a maximal-cut-basis run folder"}],
      hasAll[First[errorsOf[writeSystem["missing", {boxEntry["nowhere"]}]], ""], {"a folder that does not exist"}],
      hasAll[First[errorsOf[writeSystem["otherrun", {boxEntry["bub_analysis"]}]], ""], {"is a run of the family bub, not box"}],
      hasAll[First[errorsOf[writeSystem["otherprops", {boxEntry["other_analysis"]}]], ""], {"with other propagators"}],
      hasAll[First[errorsOf[writeSystem["image", {boxEntry[None], <|"Name" -> "boxu", "ImageOf" -> "box", "MomentumMap" -> {p1 -> p2, p2 -> p1}, "MCBRun" -> "box_analysis"|>}]], ""],
        {"boxu", "an image family", "give the run of box"}],
      errorsOf[writeSystem["plain", {boxEntry[None]}]]},
    {True, True, True, True, True, {}}, TestID -> "MCBRun: validation refuses a folder that is no run, missing, another family's, other propagators, an image's"]
};

(* the run of a family: the given one, or this skill's own *)
sysP = writeSystem["plain", {boxEntry[None]}];
runP = FileNameJoin[{tmp, "runP"}]; CreateDirectory[runP];
ownRun = PFBMaxCutRun[sysP, runP, box];
AppendTo[tests, VerificationTest[{PFBMaxCutRun[sysR, runP, box]["Dir"], PFBMaxCutRun[sysR, runP, box]["Given"], ownRun["Given"], ownRun["Dir"],
    Get[FileNameJoin[{ownRun["Dir"], "run_info.m"}]]["FamilyFile"], Get[FileNameJoin[{ownRun["Dir"], "run.wl"}]]["Family"]},
  {mcb, True, False, FileNameJoin[{runP, "maxcut", "box"}], boxFile, boxFile}, TestID -> "PFBMaxCutRun: the given run, or the skill's own with run.wl and run_info.m"]];

(* the run's script, read without running it *)
AppendTo[tests, VerificationTest[With[{sc = PoleFreeBasis`MaxCut`Private`scriptSteps[FileNameJoin[{mcb, "j1110"}]]}, {sc["RepIndex"], sc["RepOptions"], Lookup[sc["Steps"], "call"]}],
  {2, <|"Extra" -> 1, "Standard" -> False|>, {"single"}}, TestID -> "the run's AnalysisMasters.m: its steps, representation and options"]];

(* candidates from the run: its basis and the structural reading's; nothing is written into the run *)
keyT = {box, {1, 1, 1, 0}};
candT = PFBMaxCutCandidates[sysR, keyT, <|"MCBRun" -> mcb, "Representations" -> {}, "Routes" -> False, "Extra" -> {j[box, 1, 1, 2, 0], (1 + eps) j[box, 2, 1, 1, 0]}|>];
AppendTo[tests, VerificationTest[{Lookup[candT["Candidates"], "Source"], Lookup[candT["Candidates"], "Defs"], Lookup[candT["Dropped"], "Label"], candT["Status"], candT["NonDlog"]},
  {{"the run's basis", "structural reading"}, {<|3 -> s j[box, 1, 1, 1, 0]|>, <|3 -> j[box, 1, 1, 2, 0]|>}, {"(1 + eps)*j[box, 2, 1, 1, 0]"}, "eps-form", False},
  TestID -> "candidates: the run's basis (at the slot's power of eps) and the structural reading's, a rule-1 one dropped"]];

(* the filter on the bubble: the square root of the master it replaces, rules 1, 2 and 4, the slot's power of eps *)
Put[{j[bub, 1, 0], r1 j[bub, 1, 1]}, FileNameJoin[{tmp, "bub.m"}]];
sysB = writeSystem["bubble", {<|"Name" -> "bub", "Family" -> bubFile, "Masters" -> "bub.m"|>}, <|"Roots" -> {r1 -> Sqrt[s (s - 4 m2)]}|>];
keyB = {bub, {1, 1}};
mk[K_, r2_, lab_, o___] := Join[<|"r2" -> r2, "K" -> K, "label" -> lab, "source" -> "planted route", "strict" -> False, "priority" -> 5, "weight" -> {1, 0, 0}|>, Association[o]];
fl = PFBMaxCutFilter[sysB, keyB, {mk[eps j[bub, 1, 2], s (s - 4 m2), "dlog"], mk[eps j[bub, 2, 1], 4 m2^2 s (s - 4 m2), "dlog, a square under the root"],
   mk[eps j[bub, 2, 1], -m2^2 (s - 4 m2)/s, "phase"],
   mk[j[bub, 1, 1], s, "another root"], mk[j[bub, 1, 2] + j[bub, 1, 1]/(1 - 2 eps), s (s - 4 m2), "d-dim target", "strict" -> True],
   mk[(1 + eps) j[bub, 1, 2], s (s - 4 m2), "mixed powers"], j[bub, 2, 2], (1 - 2 eps) j[bub, 1, 2], mk[eps j[bub, 1, 2], s (s - 4 m2), "dlog"]}];
AppendTo[tests, VerificationTest[{Lookup[fl["Kept"], "Label"], Lookup[fl["Kept"], "Defs"], Lookup[fl["Kept"], "Dotted"]},
  {{"dlog", "dlog, a square under the root", "phase", "j[bub, 2, 2]"}, {<|2 -> j[bub, 1, 2]|>, <|2 -> m2 j[bub, 2, 1]|>, <|2 -> m2 j[bub, 2, 1]/s|>, <|2 -> j[bub, 2, 2]|>},
   {True, True, True, True}},
  TestID -> "filter: kept with the slot's root taken out (numbers and phases dropped) and its power of eps, duplicates once"]];
AppendTo[tests, VerificationTest[{Lookup[fl["Dropped"], "Label"], StringTake[First[#["Reasons"]], 6] & /@ fl["Dropped"]},
  {{"another root", "d-dim target", "mixed powers", "(1 - 2*eps)*j[bub, 1, 2]"}, {"root: ", "rule 2", "rule 1", "rule 1"}},
  TestID -> "filter: a root mismatch, a d-dimensional candidate with eps-rational coefficients, rule-1 violations dropped"]];

(* per-slot candidates in the scans: one slot with the root, one without *)
Put[{j[bub, 1, 0], r1 j[bub, 1, 1], j[bub, 2, 1]}, FileNameJoin[{tmp, "bub2.m"}]];
sysB2 = writeSystem["bubble2", {<|"Name" -> "bub", "Family" -> bubFile, "Masters" -> "bub2.m"|>}, <|"Roots" -> {r1 -> Sqrt[s (s - 4 m2)]}|>];
ssB = PFBSlotSets[sysB2, {2, 3}, {<|2 -> j[bub, 1, 2]|>, <|3 -> m2 j[bub, 2, 2]|>, j[bub, 2, 2]}];
AppendTo[tests, VerificationTest[{Length[ssB["Sets"]], ssB["Count"], ssB["Symmetric"], MemberQ[Lookup[ssB["Sets"], 3], j[bub, 1, 2]], MemberQ[Lookup[ssB["Sets"], 2], m2 j[bub, 2, 2]],
    MemberQ[ssB["Sets"], <|2 -> j[bub, 1, 2], 3 -> m2 j[bub, 2, 2]|>]},
  {7, 8, False, False, False, True}, TestID -> "PFBSlotSets: a candidate given per slot is tried only in the slots it names"]];

(* the verdict of the maximal-cut gate, planted *)
calls = 0;
planted[res_][fam_, sec_, ms_, dir_, o_] := (calls++; Join[<|"points" -> Lookup[o, "Points", {}], "nMastersCut" -> Length[ms], "message" -> "planted"|>, res]);
eulerOK = {<|"Name" -> "euler", "Pass" -> True, "Detail" -> "planted"|>};
epsForm = <|"status" -> "eps-form", "k" -> {0}, "range" -> {1, 1}, "checks" -> eulerOK|>;
poly[r_] := <|"status" -> "eps-polynomial", "k" -> {0}, "range" -> r, "checks" -> eulerOK|>;
eulerFail = <|"status" -> "failed", "checks" -> {<|"Name" -> "euler", "Pass" -> False, "Detail" -> "planted: the diagonal changes with the kinematics"|>},
   "message" -> "the maximal-cut DE breaks the Euler relation of homogeneous integrals"|>;
vT = PFBMaxCutCheck[sysR, keyT, <|3 -> s^2 j[box, 1, 1, 2, 0]|>, <|"MCBRun" -> mcb, "Check" -> planted[epsForm], "Representations" -> {}|>];
vP = PFBMaxCutCheck[sysB, keyB, <|2 -> j[bub, 2, 2]|>, <|"Check" -> planted[poly[{0, 2}]], "Representations" -> {}, "Classification" -> <|"label" -> "elliptic"|>|>];
vF = PFBMaxCutCheck[sysB, keyB, <|2 -> j[bub, 1, 2]|>, <|"Check" -> planted[eulerFail], "Representations" -> {}|>];
AppendTo[tests, VerificationTest[{vT["Status"], vT["Refuses"], vT["Euler"], vT["Points"], vT["Basis"], vT["Labels"], listing[mcb] === before},
  {"eps-form", False, True, {{s -> 3, t -> 5}, {s -> 7, t -> 11}}, {s^2 j[box, 1, 1, 2, 0]}, {3}, True},
  TestID -> "PFBMaxCutCheck: the sector's new basis, the run's points, nothing written into the run"]];
AppendTo[tests, VerificationTest[{vP["Status"], vP["Spread"], vP["NonDlog"], vP["AllDot"], StringQ[vP["Flag"]], MCBEqualAtPointsQ[First[vP["Basis"]], Sqrt[s (s - 4 m2)] j[bub, 2, 2]],
    vF["Refuses"], vF["Euler"]},
  {"eps-polynomial", 2, True, True, True, True, True, False}, TestID -> "PFBMaxCutCheck: spread, the all-dot flag on a non-dlog sector, a failed Euler relation refuses"]];

(* the finalists' order: rows first, then eps-form, the smaller spread, the all-dot flag; refused last *)
row[bad_ : 0] := <|"bad" -> bad, "newBad" -> 0, "over" -> 0|>;
verd[st_, sp_, ad_, nd_, ref_ : False] := <|"Check" -> st, "Spread" -> sp, "AllDot" -> ad, "NonDlog" -> nd, "Refuses" -> ref|>;
ents = {<|"Result" -> row[], "Verdict" -> verd["eps-polynomial", 2, False, True], "Name" -> "spread 2"|>,
   <|"Result" -> row[], "Verdict" -> verd["eps-form", 0, True, False], "Name" -> "eps-form"|>,
   <|"Result" -> row[], "Verdict" -> verd["eps-polynomial", 1, True, True], "Name" -> "spread 1, all-dot"|>,
   <|"Result" -> row[], "Verdict" -> verd["eps-polynomial", 1, False, True], "Name" -> "spread 1, undotted"|>,
   <|"Result" -> row[], "Verdict" -> verd["failed", Infinity, False, True, True], "Name" -> "Euler failed"|>,
   <|"Result" -> row[1], "Verdict" -> verd["eps-form", 0, False, False], "Name" -> "a pole left"|>};
AppendTo[tests, VerificationTest[Lookup[PFBMaxCutRank[ents], "Name"], {"eps-form", "spread 1, undotted", "spread 1, all-dot", "spread 2", "a pole left", "Euler failed"},
  TestID -> "finalists: the rows first, then eps-form, the smaller spread, an undotted element; refused last"]];
AppendTo[tests, VerificationTest[Lookup[PFBMaxCutRank[{Join[ents[[3]], <|"Verdict" -> verd["eps-polynomial", 1, True, False]|>], Join[ents[[4]], <|"Verdict" -> verd["eps-polynomial", 1, False, False]|>]}], "Name"],
  {"spread 1, all-dot", "spread 1, undotted"}, TestID -> "finalists: no all-dot tie-breaker on a dlog sector"]];

(* PFBTryChange. The old triangle carries 1/(1 - 2 eps) towards the s-bubble: I_3 = J_3 - lam I_1; the honest J_3 is a
   dotted triangle that reduces to I_3 + lam I_1. det T = 1 *)
w = 1 + 4 eps; g = 1 - 2 eps; lam = 1/g;
Rp = {{-eps, 0, 0, 0}, {0, -2 eps, 0, 0}, {eps, 0, -2 eps, 0}, {eps + eps^2, 1 + eps, eps, -1 - 2 eps}};
NT = {{1, 0, 0, 0}, {0, 1, 0, 0}, {lam, 0, 1, 0}, {0, 0, 0, 1}}; Rold = Together[Inverse[NT] . Rp . NT];
P = {s -> 1, t -> 3/7}; P2 = {s -> 1, t -> 5/11}; P3 = {s -> 1, t -> 2/13};   (* the slice point and two extra points *)
slice[R_] := <|"R" -> {R}, "Derivatives" -> {t}, "Point" -> P, "Labels" -> {1, 2, 3, 4}, "Index" -> <|1 -> 1, 2 -> 2, 3 -> 3, 4 -> 4|>, "History" -> {}|>;
redOf[R_, cands_, pt_ : P] := <|"Masters" -> ut /@ {1, 2, 3, 4}, "Point" -> pt, "Invariants" -> {t}, "Focus" -> {1, 2, 3, 4}, "Dm" -> {R}, "Pool" -> cands[[All, 1]],
   "Rp" -> Table[c[[3]]/(c[[2]] /. pt), {c, cands}],
   "dRp" -> {Table[With[{c0 = c[[2]] /. pt, dc = D[c[[2]], t] /. pt}, Together[((c[[3]] . R) - dc c[[3]]/c0)/c0]], {c, cands}]}|>;
cand = j[box, 1, 1, 2, 0];
reds = redOf[Rold, {{cand, s^2, NT[[3]]}, {j[box, 1, 2, 1, 0], s^2, {0, 0, 1, 0}}}, #] & /@ {P, P2, P3};
newRun[sys_, name_] := Module[{dir = CreateDirectory[FileNameJoin[{tmp, name}]], st, sl = slice[Rold]},
  st = <|"Run" -> "none", "Created" -> PFBTimeStamp[], "Slices" -> {}, "Current" -> None, "Censuses" -> {}, "Accepted" -> {}, "Pending" -> {},
    "Rejected" -> {}, "Flagged" -> <||>, "Approval" -> False, "Regenerated" -> False|>;
  st = PFBStoreSlice[dir, st, sl, PFBCensus[sys, sl], "start"];
  <|"Run" -> <|"MaxEpsDegree" -> 2|>, "System" -> sys, "Dir" -> dir, "State" -> st|>];
try[ctx_, defs_, opts_] := PFBTryChange[ctx, keyT, defs, <|"Rung" -> 8, "Provenance" -> "planted"|>, Join[<|"Reds" -> reds, "AllowPlantedCheck" -> True|>, opts]];
withKira[on_, body_] := Block[{$MCBPaths = If[on, Append[$MCBPaths, "kira" -> $InputFileName], KeyDrop[$MCBPaths, "kira"]]}, body];
SetAttributes[withKira, HoldRest];

calls = 0;
rA = try[newRun[sysR, "ok"], <|3 -> s^2 cand|>, <|"MaxCutChanged" -> True, "MaxCutCheckOptions" -> <|"Check" -> planted[epsForm], "Representations" -> {}|>|>];
AppendTo[tests, VerificationTest[{rA["Status"], calls, checkOf[rA["Gate"], "maximal cut"]["Pass"], rA["Record"]["MaxCutCheck"]["Status"], rA["Record"]["MaxCutCheck"]["Tool"],
    StringContainsQ[rA["Record"]["MaxCutCheck"]["Text"], "eps-form; Euler relation ok"], listing[mcb] === before},
  {"accepted", 1, True, "eps-form", "planted", True, True}, TestID -> "PFBTryChange: a change that alters the maximal cut gets the check, run and recorded"]];
calls = 0;
rF = try[newRun[sysR, "euler"], <|3 -> s^2 cand|>, <|"MaxCutChanged" -> True, "MaxCutCheckOptions" -> <|"Check" -> planted[eulerFail], "Representations" -> {}|>|>];
AppendTo[tests, VerificationTest[{rF["Status"], failing[rF["Gate"]], StringContainsQ[checkOf[rF["Gate"], "maximal cut"]["Detail"], "Euler relation FAILED"], calls},
  {"rejected", {"maximal cut"}, True, 1}, TestID -> "PFBTryChange: a failed Euler relation on the cut refuses the change"]];
(* the run's credits of the sector go with the change, stamped with its id: cited when it is accepted, consulted when
   the gate refused it *)
viaOf[r_] := Select[CoreReadCitations[r["Context"]["Dir"]], Lookup[#, "via", None] === "maximal-cut-basis run box_analysis" &];
AppendTo[tests, VerificationTest[{Sort[Lookup[viaOf[rA], {"kind", "sector", "change", "part"}]], Sort[Lookup[viaOf[rF], {"kind", "change", "part"}]],
    AllTrue[viaOf[rF], StringContainsQ[#["outcome"], "change 1"] &]},
  {{{"paper", "box/j1110", 1, "cite"}, {"tool", "box/j1110", 1, "cite"}}, {{"paper", 1, "consulted"}, {"tool", 1, "consulted"}}, True},
  TestID -> "rung 8: the maximal-cut-basis run's credits of the sector go with the change, cited when accepted, consulted when refused"]];
calls = 0;
given = PFBMaxCutCheck[sysR, keyT, <|3 -> s^2 cand|>, <|"Check" -> planted[poly[{0, 1}]], "Representations" -> {}|>];
calls = 0;
rG = try[newRun[sysR, "given"], <|3 -> s^2 cand|>, <|"MaxCutChanged" -> True, "MaxCutCheck" -> given, "MaxCutCheckOptions" -> <|"Check" -> planted[epsForm], "Representations" -> {}|>|>];
rO = try[newRun[sysR, "given-other"], <|3 -> s^2 cand|>, <|"MaxCutChanged" -> True, "MaxCutCheck" -> Join[given, <|"Basis" -> {s^2 j[box, 2, 1, 1, 0]}|>],
   "MaxCutCheckOptions" -> <|"Check" -> planted[epsForm], "Representations" -> {}|>|>];
AppendTo[tests, VerificationTest[{rG["Status"], rG["Record"]["MaxCutCheck"]["Check"], rO["Record"]["MaxCutCheck"]["Check"], calls},
  {"accepted", "eps-polynomial", "eps-form", 1}, TestID -> "PFBTryChange: a verdict for this basis is recorded as given, one for another basis checked again"]];
calls = 0;
rN = try[newRun[sysR, "notrun"], <|3 -> s^2 j[box, 1, 2, 1, 0]|>, <|"MaxCutChanged" -> True, "MaxCutCheckOptions" -> <|"Check" -> planted[epsForm], "Representations" -> {}|>|>];
AppendTo[tests, VerificationTest[{rN["Status"], MemberQ[failing[rN["Gate"]], "maximal cut"], TrueQ[checkOf[rN["Gate"], "maximal cut"]["NotChecked"]], calls},
  {"rejected", False, True, 0}, TestID -> "PFBTryChange: the check does not run when the gate refuses the change already"]];
calls = 0;
rK = try[newRun[sysR, "keeps"], <|3 -> s^2 cand|>, <|"MaxCutCheckOptions" -> <|"Check" -> planted[epsForm], "Representations" -> {}|>|>];
AppendTo[tests, VerificationTest[{rK["Status"], rK["Record"]["MaxCutChanged"], rK["Record"]["MaxCutCheck"], calls, KeyExistsQ[Association[#["Name"] -> 1 & /@ rK["Gate"]["Checks"]], "maximal cut"]},
  {"accepted", False, Missing["NotNeeded"], 0, False}, TestID -> "PFBTryChange: a change that keeps the maximal cut needs no check"]];
rS = withKira[False, try[newRun[sysR, "nokira"], <|3 -> s^2 cand|>, <|"MaxCutChanged" -> True, "MaxCutCheck" -> "NoKira"|>]];
rR = withKira[True, try[newRun[sysR, "kira-there"], <|3 -> s^2 cand|>, <|"MaxCutChanged" -> True, "MaxCutCheck" -> "NoKira"|>]];
AppendTo[tests, VerificationTest[{rS["Status"], TrueQ[checkOf[rS["Gate"], "maximal cut"]["NotChecked"]], StringStartsQ[rS["Record"]["MaxCutCheck"]["Skipped"], "Kira is not available"],
    rR["Status"], StringContainsQ[rR["Message"], "Kira is available here"]},
  {"accepted", True, True, "not tried", True}, TestID -> "PFBTryChange: \"NoKira\" skips the check only where Kira is not available, and says so"]];

(* records and pages *)
st2 = rS["Context"]["State"];
PFBMakeReports[rS["Context"]["Dir"], rS["Context"]["System"], st2];
chS = Import[FileNameJoin[{rS["Context"]["Dir"], "CHANGES.md"}], "Text"];
PFBMakeReports[rA["Context"]["Dir"], rA["Context"]["System"], rA["Context"]["State"]];
chA = Import[FileNameJoin[{rA["Context"]["Dir"], "CHANGES.md"}], "Text"];
secA = Import[FileNameJoin[{PFBSectorDir[rA["Context"]["Dir"], keyT], "sector.html"}], "Text"];
AppendTo[tests, VerificationTest[{hasAll[chA, {"maximal cut: maximal-cut-basis gate", "eps-form; Euler relation ok"}], StringContainsQ[secA, "maximal cut: maximal-cut-basis gate"],
    hasAll[chS, {"Not verified", "the maximal-cut-basis gate did not run on the new basis (Kira is not available"}],
    Lookup[MCBReadBasis[PFBSectorDir[rA["Context"]["Dir"], keyT]], "maxCutCheck", {}][[All, "Status"]]},
  {True, True, True, {"eps-form"}}, TestID -> "records: CHANGES.md, the sector page and basis.m keep the verdict; a skipped check is not verified"]];

(* the finalists of a scan, planted: the clearing sets only, at most three, checked and ranked, written and read back *)
calls = 0;
scanRes = Join[row[], <|"set" -> #|>] & /@ {<|3 -> s^2 j[box, 1, 2, 1, 0]|>, <|3 -> s^2 cand|>, <|3 -> s^2 j[box, 2, 1, 1, 0]|>, <|3 -> s j[box, 1, 1, 1, 0], 4 -> s t j[box, 1, 1, 1, 1]|>};
scanRes = Prepend[scanRes, Join[row[1], <|"set" -> <|3 -> s^2 j[box, 1, 1, 1, -1]|>|>]];
byBasis[fam_, sec_, ms_, dir_, o_] := (calls++; If[MemberQ[JIntegrals[ms], cand], Join[epsForm, <|"points" -> {}|>], Join[poly[{0, 1}], <|"points" -> {}|>]]);
runF = newRun[sysR, "finalists"]["Dir"];
fin = PFBMaxCutFinalists[sysR, keyT, scanRes, <|"RunDir" -> runF, "MCBRun" -> mcb, "Check" -> byBasis, "Representations" -> {}|>];
AppendTo[tests, VerificationTest[{calls, Lookup[fin["Finalists"], "Defs"], Lookup[Lookup[fin["Finalists"], "Verdict"], "Check"], Lookup[PFBReadMaxCutFinalists[runF, keyT], "Rank"],
    AnyTrue[MCBReadAttempts[PFBSectorDir[runF, keyT]], Lookup[#, "rung", None] === 8 &]},
  {3, {<|3 -> s^2 cand|>, <|3 -> s^2 j[box, 1, 2, 1, 0]|>, <|3 -> s^2 j[box, 2, 1, 1, 0]|>}, {"eps-form", "eps-polynomial", "eps-polynomial"}, {1, 2, 3}, True},
  TestID -> "finalists: three clearing sets checked, eps-form first, written and recorded"]];
AppendTo[tests, VerificationTest[listing[mcb] === before, True, TestID -> "the given run is never written into"]];

report = TestReport[tests];
Do[With[{r = report["TestResults"][id]},
    Print[If[r["Outcome"] === "Success", "PASS ", "FAIL "], r["TestID"], If[r["Outcome"] === "Success", "",
      "\n     got " <> ToString[Short[r["ActualOutput"], 3], InputForm] <> "\n     expected " <> ToString[Short[r["ExpectedOutput"], 3], InputForm]]]],
  {id, Keys[report["TestResults"]]}];
Print[report["TestsSucceededCount"], " passed, ", report["TestsFailedCount"], " failed, ", Round[report["TimeElapsed"], 0.1]];
DeleteDirectory[tmp, DeleteContents -> True];
Exit[If[report["AllTestsSucceeded"], 0, 1]];
