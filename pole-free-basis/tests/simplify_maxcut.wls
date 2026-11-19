#!/usr/bin/env wolframscript
(* A simplification move (rung "simplify") against the checks of the pole-free work, without FiniteFlow or IBP.
   Planted data: the two-loop equal-mass sunrise of the maximal-cut-basis examples (unit scale m2, derivative d/ds)
   with two planted masters in the sector of the two tadpoles (labels 1 and 2) and one in the top sector (label 3), a
   planted slice, planted measured degrees, and a planted maximal-cut check (the verdict MCBCheckBasis would give).
   Checked: a swap that changes the tadpoles' maximal cut passes the maximal-cut-basis gate like any change of the
   maximal cut (accepted with a passing verdict and recorded; rejected when the planted check refuses; not tried with a
   planted check outside the tests, or with "NoKira" while Kira is there); a rescaling does not change the maximal cut
   and runs no check; the determinant is not judged: a mixing with det T = 1 - eps is refused for the poles it brings,
   and a move with det T = 1 + 4 eps that is otherwise clean passes without waiting for approval; the record of the
   checks of several sectors.
   usage: bin/ws tests/simplify_maxcut.wls        exit code 0 when every test passes *)
Get[FileNameJoin[{ParentDirectory[DirectoryName[$InputFileName]], "lib", "PoleFreeBasis.wl"}]];
$PFBVerbose = False;
sunFile = FileNameJoin[{ParentDirectory[$PFBRoot], "maximal-cut-basis", "examples", "sunrise-equal-mass", "family.wl"}];
keyLow = {sunrise, {1, 1, 0, 0, 0}}; keyTop = {sunrise, {1, 1, 1, 0, 0}};
P = {s -> 3/7, m2 -> 1};
masters = {j[sunrise, 1, 1, 0, 0, 0], m2 j[sunrise, 2, 1, 0, 0, 0], j[sunrise, 1, 1, 1, 0, 0]};
R = {{-2 + eps, 3/5, 0}, {7/3 eps, -1 - 2 eps, 0}, {5/11 + eps, 0, -3 + eps}};
tmp = CreateDirectory[];
(* a fresh run with the planted slice *)
newRun[name_] := Module[{dir = FileNameJoin[{tmp, name}], ctx, sl},
  CreateDirectory[dir, CreateIntermediateDirectories -> True];
  Put[masters, FileNameJoin[{dir, "masters.m"}]];
  Put[<|"Name" -> "planted", "Families" -> {<|"Name" -> "sunrise", "Family" -> sunFile, "Masters" -> "masters.m"|>}, "Letters" -> {s, m2, s - m2, s - 9 m2}|>,
    FileNameJoin[{dir, "system.wl"}]];
  Put[<|"System" -> "system.wl", "OutputDir" -> FileNameJoin[{dir, "out"}], "AllowTmp" -> True, "Paths" -> Automatic|>, FileNameJoin[{dir, "run.wl"}]];
  ctx = PFBStartRun[FileNameJoin[{dir, "run.wl"}]];
  sl = <|"R" -> {R}, "Derivatives" -> {s}, "Point" -> P, "Labels" -> {1, 2, 3}, "Index" -> <|1 -> 1, 2 -> 2, 3 -> 3|>, "Frame" -> "RootFree", "History" -> {}|>;
  Join[ctx, <|"State" -> PFBStoreSlice[ctx["Dir"], ctx["State"], sl, PFBCensus[ctx["System"], sl], "planted"]|>]];
degs[b_, a_] := <|"Degrees" -> <|"Before" -> <|"Highest" -> b[[1]], "Count" -> b[[2]], "Sum" -> b[[3]], "Terms" -> 6|>,
    "After" -> <|"Highest" -> a[[1]], "Count" -> a[[2]], "Sum" -> a[[3]], "Terms" -> 6|>, "Measured" -> True, "Jobs" -> {"planted"}|>|>;
info[name_, move_] := <|"Rung" -> "simplify", "Name" -> name, "Provenance" -> "planted",
   "Simplify" -> <|"MoveId" -> 1, "Move" -> move, "Title" -> move, "Candidate" -> move <> "1", "BeforeObjective" -> {3, 2, 9}, "AfterObjective" -> {2, 2, 7}|>|>;
(* the planted maximal-cut check, as in tests/maxcut_rung8.wls *)
calls = 0;
planted[res_][fam_, sec_, ms_, dir_, o_] := (calls++; Join[<|"points" -> Lookup[o, "Points", {}], "nMastersCut" -> Length[ms], "message" -> "planted"|>, res]);
eulerOK = {<|"Name" -> "euler", "Pass" -> True, "Detail" -> "planted"|>};
epsForm = <|"status" -> "eps-form", "k" -> {0}, "range" -> {1, 1}, "checks" -> eulerOK|>;
eulerFail = <|"status" -> "failed", "checks" -> {<|"Name" -> "euler", "Pass" -> False, "Detail" -> "planted: the diagonal changes with the kinematics"|>},
   "message" -> "the maximal-cut DE breaks the Euler relation of homogeneous integrals"|>;
checkOpts[res_] := <|"AllowPlantedCheck" -> True, "MaxCutCheckOptions" -> <|"Check" -> planted[res], "Representations" -> {}|>|>;
swap = <|2 -> ut[2] + 2 ut[1]|>;
checkOf[g_, name_] := SelectFirst[Lookup[Lookup[g, "Gate", <||>], "Checks", {}], #["Name"] === name &, <||>];
tests = {};

(* a swap that changes the maximal cut of the tadpoles: the maximal-cut gate runs, and its verdict is recorded *)
calls = 0;
gOK = PFBTryChange[newRun["ok"], None, swap, info["swap of the tadpoles", "swap"], Join[degs[{3, 2, 9}, {2, 2, 7}], checkOpts[epsForm]]];
callsOK = calls;
recOK = Lookup[gOK, "Record", <||>];
AppendTo[tests, VerificationTest[{gOK["Status"], callsOK, TrueQ[checkOf[gOK, "maximal cut"]["Pass"]], recOK["MaxCutChanged"], recOK["MaxCutCheck"]["Status"],
    recOK["MaxCutCheck"]["Sector"], StringContainsQ[recOK["MaxCutCheck"]["Text"], "planted"]},
  {"accepted", 1, True, True, "eps-form", keyLow, True}, TestID -> "a swap that changes the maximal cut passes the maximal-cut gate, and the record keeps its verdict"]];
(* the planted check refuses: the swap is rejected on the maximal cut, whatever the degrees say *)
calls = 0;
gF = PFBTryChange[newRun["euler"], None, swap, info["swap of the tadpoles", "swap"], Join[degs[{3, 2, 9}, {2, 2, 7}], checkOpts[eulerFail]]];
AppendTo[tests, VerificationTest[{gF["Status"], calls, checkOf[gF, "maximal cut"]["Pass"], TrueQ[checkOf[gF, "kinematic degrees"]["Pass"]], Length[gF["Context"]["State"]["Rejected"]]},
  {"rejected", 1, False, True, 1}, TestID -> "a swap whose maximal-cut DE fails the gate is rejected"]];
(* a planted check outside the tests, and "NoKira" where Kira is there: not tried, nothing recorded *)
calls = 0;
gP = PFBTryChange[newRun["planted"], None, swap, info["swap of the tadpoles", "swap"],
   Join[degs[{3, 2, 9}, {2, 2, 7}], <|"MaxCutCheckOptions" -> <|"Check" -> planted[epsForm], "Representations" -> {}|>|>]];
gK = If[MaximalCutBasis`Kira`MCBKiraAvailableQ[], PFBTryChange[newRun["nokira"], None, swap, info["swap of the tadpoles", "swap"], Join[degs[{3, 2, 9}, {2, 2, 7}], <|"MaxCutCheck" -> "NoKira"|>]],
   <|"Status" -> "not tried", "Message" -> "Kira is available here"|>];
AppendTo[tests, VerificationTest[{gP["Status"], StringContainsQ[gP["Message"], "tests only"], calls, gK["Status"], StringContainsQ[gK["Message"], "Kira is available"],
    Length[gP["Context"]["State"]["Accepted"]] + Length[gP["Context"]["State"]["Rejected"]]},
  {"not tried", True, 0, "not tried", True, 0}, TestID -> "a planted check outside the tests, or NoKira with Kira there: the move is not tried"]];
(* a rescaling keeps the maximal cut: no check *)
calls = 0;
gR = PFBTryChange[newRun["rescale"], None, <|1 -> (s/m2) ut[1], 3 -> (s/m2) ut[3]|>, info["rescaling of both sectors", "rescale"],
   Join[degs[{3, 2, 9}, {2, 1, 6}], checkOpts[eulerFail]]];
AppendTo[tests, VerificationTest[{gR["Status"], calls, checkOf[gR, "maximal cut"], gR["Record"]["MaxCutChanged"], gR["Record"]["MaxCutCheck"]},
  {"accepted", 0, <||>, False, Missing["NotNeeded"]}, TestID -> "a rescaling does not change the maximal cut and runs no maximal-cut check"]];

(* a determinant that is not an eps-monomial: 1 - eps, with rules, weights and degrees fine. Refused for the poles
   1/(1 - eps) that T^-1 brings into the rows, not for its determinant; no maximal-cut check runs for a change the gate
   refuses *)
calls = 0;
gD = PFBTryChange[newRun["det"], None, <|1 -> ut[1] + ut[2], 2 -> ut[2] + eps ut[1]|>, info["a mixing with det 1 - eps", "swap"],
   Join[degs[{3, 2, 9}, {2, 2, 7}], checkOpts[epsForm]]];
AppendTo[tests, VerificationTest[{gD["Status"], checkOf[gD, "determinant"], checkOf[gD, "rows"]["Pass"], Length[gD["Context"]["State"]["Pending"]], calls},
  {"rejected", <||>, False, 0, 0}, TestID -> "a simplification with det T = 1 - eps is refused for its new poles, not for its determinant"]];
(* PFBSimplifyGate on a move with det T = 1 + 4 eps whose rows and census are clean: it passes, without approval, and
   has no determinant check *)
Module[{ctx = newRun["weight"], sys, sl, c, slNew, ch, gate0, g},
  sys = ctx["System"]; sl = PFBCurrentSlice[ctx["Dir"], ctx["State"]]; c = PFBCensus[sys, sl];
  slNew = Join[sl, <|"History" -> {<|"DetT" -> 1 + 4 eps|>}|>];
  ch = <|"Name" -> "planted", "Key" -> None, "Kind" -> "change", "Replace" -> {2}, "NewDefs" -> <|2 -> PFBMaster[sys, 2]["RootFree"]|>|>;
  gate0 = <|"Pass" -> True, "Checks" -> {<|"Name" -> "rules", "Pass" -> True, "Detail" -> "planted"|>},
    "Census" -> c, "Comparison" -> PFBCompareCensus[c, c], "Message" -> ""|>;
  g = PFBSimplifyGate[gate0, sys, sl, c, slNew, ch, degs[{3, 2, 9}, {2, 2, 7}]];
  AppendTo[tests, VerificationTest[{g["Pass"], KeyExistsQ[g, "NeedsApproval"], Count[g["Checks"], _?(#["Name"] === "determinant" &)]},
    {True, False, 0}, TestID -> "PFBSimplifyGate passes a clean move whatever its determinant, without approval"]]];

(* the record of the maximal-cut checks of a move of several sectors, and a verdict given per sector *)
Module[{v1 = <|"Status" -> "eps-form", "Check" -> "eps-form", "Range" -> {1, 1}, "Euler" -> True, "Refuses" -> False, "Tool" -> "planted", "Points" -> {{}, {}}|>,
    v2 = <|"Skipped" -> "Kira is not available on this machine"|>, rec, o1, o2, o3},
  rec = PoleFreeBasis`Records`Private`maxCutRecord[<|keyLow -> v1, keyTop -> v2|>];
  o1 = PoleFreeBasis`Records`Private`sectorMaxCutOpts[<|"MaxCutCheck" -> <|keyLow -> v1|>|>, keyLow, 2];
  o2 = PoleFreeBasis`Records`Private`sectorMaxCutOpts[<|"MaxCutCheck" -> <|keyLow -> v1|>|>, keyTop, 2];
  o3 = PoleFreeBasis`Records`Private`sectorMaxCutOpts[<|"MaxCutCheck" -> v1|>, keyLow, 1];
  AppendTo[tests, VerificationTest[{Sort[Keys[rec["Sectors"]]] === Sort[{keyLow, keyTop}], StringContainsQ[rec["Text"], PFBSectorString[keyLow]] && StringContainsQ[rec["Text"], PFBSectorString[keyTop]],
      StringContainsQ[rec["Skipped"], PFBSectorString[keyTop]], o1["MaxCutCheck"] === v1, o2["MaxCutCheck"], o3["MaxCutCheck"] === v1},
    {True, True, True, True, Automatic, True}, TestID -> "the record of several sectors' checks, and a verdict given per sector"]]];

report = TestReport[tests];
Do[With[{r = report["TestResults"][id]},
    Print[If[r["Outcome"] === "Success", "PASS ", "FAIL "], r["TestID"], If[r["Outcome"] === "Success", "",
      "\n     got " <> ToString[Short[r["ActualOutput"], 3], InputForm] <> "\n     expected " <> ToString[Short[r["ExpectedOutput"], 3], InputForm]]]],
  {id, Keys[report["TestResults"]]}];
Print[report["TestsSucceededCount"], " passed, ", report["TestsFailedCount"], " failed, ", Round[report["TimeElapsed"], 0.1]];
Quiet[DeleteDirectory[tmp, DeleteContents -> True]];
Exit[If[report["AllTestsSucceeded"], 0, 1]];
