#!/usr/bin/env wolframscript
(* The integration test of rung 8 with the maximal-cut-basis gate, run by tests/maxcut_kira.sh (PFB_MCK_RUN=1, tool
   paths in PFB_MCK_PATHS). On the equal-mass bubble of the maximal-cut-basis examples, in this kernel:
   - PFBMaxCutCandidates runs maximal-cut-basis's candidate routes (BaikovPackage) and keeps candidates with the root
     of the master they replace;
   - PFBMaxCutCheck runs MCBCheckBasis (Kira on the cut at two points): the canonical dotted bubble with its root is
     eps-form, the bare bubble passes, an element mixing mass dimensions breaks the Euler relation and is refused;
   - PFBMaxCutFinalists checks a set built from a route candidate;
   - PFBTryChange, with no verdict given, runs the check itself for a change that alters the maximal cut (planted
     slice and reduction), records it, and leaves no Kira scratch in the run folder.
   Run directly without PFB_MCK_RUN it does nothing and exits with 0 (the planted tests run it that way). *)
Get[FileNameJoin[{ParentDirectory[DirectoryName[$InputFileName]], "lib", "PoleFreeBasis.wl"}]];
$PFBVerbose = False;
If[Environment["PFB_MCK_RUN"] =!= "1", Print["maxcut_kira.wls: run it through tests/maxcut_kira.sh (it needs Kira and BaikovPackage)"]; Exit[0]];
With[{p = Environment["PFB_MCK_PATHS"]}, MCBLoadPaths[If[StringQ[p] && p =!= "", p, Automatic]]];
If[! AllTrue[{"kira", "fer64", "BaikovPackage"}, MCBAvailableQ], Print["maxcut_kira: tools missing: ", Select[{"kira", "fer64", "BaikovPackage"}, ! MCBAvailableQ[#] &]]; Exit[1]];
bubFile = FileNameJoin[{ParentDirectory[ParentDirectory[DirectoryName[$InputFileName]]], "maximal-cut-basis", "examples", "bubble-massive", "family.wl"}];
tmp = CreateDirectory[];
writeSystem[name_, masters_, extra_ : <||>] := (Put[masters, FileNameJoin[{tmp, name <> ".m"}]];
  Put[Join[<|"Name" -> name, "Families" -> {<|"Name" -> "bub", "Family" -> bubFile, "Masters" -> name <> ".m"|>}|>, extra], FileNameJoin[{tmp, name <> ".wl"}]];
  PFBReadSystem[FileNameJoin[{tmp, name <> ".wl"}]]);
sysR = writeSystem["root", {j[bub, 1, 0], r1 eps j[bub, 1, 2]}, <|"Roots" -> {r1 -> Sqrt[s (s - 4 m2)]}|>];
sysP = writeSystem["plain", {j[bub, 1, 0], eps s j[bub, 1, 2]}];
key = {bub, {1, 1}};
t0 = AbsoluteTime[];

(* candidates from the toolkit's routes *)
cands = PFBMaxCutCandidates[sysR, key, <|"Reps" -> 2, "TimeLimit" -> 120|>];
Print[cands["Message"]];
route = Select[cands["Candidates"], StringStartsQ[#["Source"], "route"] &];
(* the gate on the cut *)
vE = PFBMaxCutCheck[sysR, key, <|2 -> eps j[bub, 2, 1]|>];
vB = PFBMaxCutCheck[sysR, key, <|2 -> j[bub, 1, 1]|>];
vF = PFBMaxCutCheck[sysR, key, <|2 -> eps j[bub, 2, 1] + j[bub, 1, 1]|>];
Print["verdicts: ", {vE["Status"], vB["Status"], vF["Status"]}, " ", vF["Message"]];
runX = CreateDirectory[FileNameJoin[{tmp, "finalists"}]];
fin = If[route === {}, <|"Finalists" -> {}|>, PFBMaxCutFinalists[sysR, key, {<|"bad" -> 0, "newBad" -> 0, "over" -> 0, "set" -> First[route]["Defs"]|>}, <|"RunDir" -> runX|>]];

(* PFBTryChange runs the check itself: a planted slice where the old bubble carries 1/(1 - 2 eps) towards the tadpole *)
lam = 1/(1 - 2 eps); Nb = {{1, 0}, {lam, 1}}; Rp = {{0, 0}, {eps + eps^2, -2 eps}}; Rold = Together[Inverse[Nb] . Rp . Nb];
P = {s -> 13, m2 -> 3};
slice = <|"R" -> {Rold}, "Derivatives" -> {s}, "Point" -> P, "Labels" -> {1, 2}, "Index" -> <|1 -> 1, 2 -> 2|>, "History" -> {}|>;
cand = j[bub, 2, 1]; c0 = eps s; H = Nb[[2]];
(* the planted DE at the slice point and at two extra points *)
redAt[pt_] := <|"Masters" -> {ut[1], ut[2]}, "Point" -> pt, "Invariants" -> {s}, "Focus" -> {1, 2}, "Dm" -> {Rold}, "Pool" -> {cand}, "Rp" -> {H/(c0 /. pt)},
   "dRp" -> {{Together[((H . Rold) - (D[c0, s] /. pt) H/(c0 /. pt))/(c0 /. pt)]}}|>;
runDir = CreateDirectory[FileNameJoin[{tmp, "run"}]];
st = <|"Run" -> "none", "Created" -> PFBTimeStamp[], "Slices" -> {}, "Current" -> None, "Censuses" -> {}, "Accepted" -> {}, "Pending" -> {}, "Rejected" -> {},
   "Flagged" -> <||>, "Approval" -> False, "Regenerated" -> False|>;
st = PFBStoreSlice[runDir, st, slice, PFBCensus[sysP, slice], "start"];
ctx = <|"Run" -> <|"MaxEpsDegree" -> 2|>, "System" -> sysP, "Dir" -> runDir, "State" -> st|>;
rT = PFBTryChange[ctx, key, <|2 -> eps s cand|>, <|"Rung" -> 8, "Provenance" -> "planted"|>, <|"Reds" -> (redAt /@ {P, {s -> 17, m2 -> 3}, {s -> 19, m2 -> 3}}), "MaxCutChanged" -> True|>];
Print["PFBTryChange: ", rT["Status"], "; ", Lookup[Lookup[rT, "Record", <||>], "MaxCutCheck", Missing[]]];
Print["seconds: ", Round[AbsoluteTime[] - t0]];

tests = {
  VerificationTest[{route =!= {}, AllTrue[cands["Candidates"], KeyExistsQ[#["Defs"], 2] &], AllTrue[cands["Candidates"], PFBRuleViolations[sysR, #["Defs"][2], <|"Letters" -> {}|>] === {} &],
      AllTrue[cands["Dropped"], AllTrue[#["Reasons"], StringStartsQ[#, {"rule 1", "rule 2", "rule 4", "root"}] &] &]},
    {True, True, True, True}, TestID -> "routes: maximal-cut-basis's candidates in this kernel, kept with the master's root, the others dropped by the rules or the root"],
  VerificationTest[{vE["Check"], vE["Euler"], vE["Refuses"], vE["NMastersCut"], vE["Tool"]}, {"eps-form", True, False, 1, "Kira (MCBCheckBasis)"},
    TestID -> "the gate on the cut: the canonical dotted bubble with its root is eps-form"],
  VerificationTest[{MemberQ[{"eps-form", "eps-polynomial"}, vB["Check"]], vB["Refuses"]}, {True, False}, TestID -> "the gate on the cut: the bare bubble passes"],
  VerificationTest[{vF["Check"], vF["Euler"], vF["Refuses"]}, {"failed", False, True}, TestID -> "the gate on the cut: an element mixing mass dimensions breaks the Euler relation, refused"],
  VerificationTest[With[{f = fin["Finalists"]}, {Length[f], f =!= {} && ! First[f]["Refused"], f =!= {} && First[f]["Verdict"]["Euler"] === True,
      Length[PFBReadMaxCutFinalists[runX, key]]}], {1, True, True, 1}, TestID -> "finalists: a route candidate's set through the gate, written"],
  VerificationTest[{rT["Status"], rT["Record"]["MaxCutCheck"]["Tool"], MemberQ[{"eps-form", "eps-polynomial"}, rT["Record"]["MaxCutCheck"]["Check"]],
      FileExistsQ[FileNameJoin[{runDir, "maxcut", "bub", "run_info.m"}]], Select[FileNames["*", runDir, Infinity], StringContainsQ[#, "kira"] &]},
    {"accepted", "Kira (MCBCheckBasis)", True, True, {}}, TestID -> "PFBTryChange runs the check itself, records it, keeps no Kira scratch in the run"]
};

report = TestReport[tests];
Do[With[{r = report["TestResults"][id]},
    Print[If[r["Outcome"] === "Success", "PASS ", "FAIL "], r["TestID"], If[r["Outcome"] === "Success", "",
      "\n     got " <> ToString[Short[r["ActualOutput"], 3], InputForm] <> "\n     expected " <> ToString[Short[r["ExpectedOutput"], 3], InputForm]]]],
  {id, Keys[report["TestResults"]]}];
Print[report["TestsSucceededCount"], " passed, ", report["TestsFailedCount"], " failed, ", Round[report["TimeElapsed"], 0.1]];
DeleteDirectory[tmp, DeleteContents -> True];
Exit[If[report["AllTestsSucceeded"], 0, 1]];
