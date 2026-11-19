#!/usr/bin/env wolframscript
(* Degree and line jobs are FiniteFlow's, whatever the slice-point reducer, without Kira or FiniteFlow: the tool
   paths are planted files (nothing runs), as in tests/kira_slice.wls. A degree job (job.m "Degrees", with its
   variants and samples) and a line job ("Line") evaluate FiniteFlow's learned system, which Kira does not make: with
   Kira at the slice point, a degree job of one point would end after Kira's reduction with no degrees measured.
   Checked: PFBReducerChoice with a degree job (Automatic: FiniteFlow, saying why; "Kira": refused); PFBSubtreeJob
   with "Degrees" or "Line" (FiniteFlow, no Kira configuration, the reason in "ReducerNote"), with run.wl's
   "Reducer" -> "Kira" (a degree job stays FiniteFlow's, a plain job takes Kira: the control), and with "Reducer" ->
   "Kira" asked for (refused); PFBDegreesJob on a planted run (the job the degree census and the simplification phase
   write).
   usage: bin/ws tests/degree_reducer.wls        exit code 0 when every test passes *)
Get[FileNameJoin[{ParentDirectory[DirectoryName[$InputFileName]], "lib", "PoleFreeBasis.wl"}]];
$PFBVerbose = False;
boxFile = FileNameJoin[{ParentDirectory[ParentDirectory[DirectoryName[$InputFileName]]], "maximal-cut-basis", "examples", "box-one-loop", "family.wl"}];
tmp = CreateDirectory[];
plantTools[] := Do[With[{f = FileNameJoin[{tmp, "tools", t}]}, Quiet@CreateDirectory[DirectoryName[f], CreateIntermediateDirectories -> True]; Export[f, "", "Text"]; MCBSetPath[t, f]],
  {t, {"FiniteFlow", "FiniteFlowLibrary", "LiteRed", "LiteIBP", "kira", "fer64"}}];
plantTools[];

(* a planted system: the one-loop box of the maximal-cut-basis examples *)
masters = {j[box, 1, 0, 1, 0], j[box, 0, 1, 0, 1], s t j[box, 1, 1, 1, 1]};
Put[masters, FileNameJoin[{tmp, "box.m"}]];
Put[<|"Name" -> "planted", "Families" -> {<|"Name" -> "box", "Family" -> boxFile, "Masters" -> "box.m"|>}, "Letters" -> {s, t, s + t}|>, FileNameJoin[{tmp, "system.wl"}]];
sys = PFBReadSystem[FileNameJoin[{tmp, "system.wl"}]];
P = {s -> 1409, t -> 1637};
key = {box, {1, 1, 1, 1}};
writeJob[name_, spec_, run_ : tmp] := PFBSubtreeJob[sys, run, Join[<|"Name" -> name, "Points" -> {P}, "Derivatives" -> {t}, "Roots" -> {key}|>, spec]];
jobOf[d_] := If[StringQ[d], Get[FileNameJoin[{d, "job.m"}]], d];
degSpec = <|"Keys" -> {key}, "Rows" -> Automatic, "Fix" -> {s -> 1}, "Cap" -> 2, "Probes" -> {t, 1 + t}, "Probe" -> True, "Variants" -> {}, "Samples" -> {}|>;
lineSpec = <|"Change" -> 1, "Key" -> key, "Labels" -> {3}, "Changed" -> {3}, "Exprs" -> {s t j[box, 1, 1, 1, 1], t j[box, 1, 1, 1, 1]}, "Masters" -> {3},
   "Base" -> {t -> 3}, "Direction" -> {t -> 1}, "Eps" -> 1009/2027, "Fix" -> {s -> 1}|>;
(* the reducer the job's slice point gets, its Kira configuration, and whether its note says that it is a degree or line job *)
summary[job_] := If[AssociationQ[job], {StringStartsQ[job["ReducerNote"], "slice point: FiniteFlow"], job["Kira"], StringContainsQ[job["ReducerNote"], "degree or line job"]}, job];
tests = {};

(* the choice *)
AppendTo[tests, VerificationTest[With[{c = PFBReducerChoice[Automatic, <|"KiraAvailable" -> True, "Families" -> {box}, "Degrees" -> True|>]},
    {c["Reducer"], c["Refused"], StringContainsQ[c["Reason"], "degree or line job"]}],
  {"FiniteFlow", False, True}, TestID -> "choice: a degree or line job is FiniteFlow's, saying why"]];
AppendTo[tests, VerificationTest[PFBReducerChoice["Kira", <|"KiraAvailable" -> True, "Families" -> {box}, "Degrees" -> True|>][[{"Reducer", "Refused"}]],
  <|"Reducer" -> "FiniteFlow", "Refused" -> True|>, TestID -> "choice: Kira asked for a degree job is refused"]];

(* the job writer *)
plainJob = jobOf[writeJob["plain", <||>]];
degJob = jobOf[writeJob["deg", <|"Degrees" -> degSpec|>]];
lineJob = jobOf[writeJob["line", <|"Line" -> lineSpec|>]];
AppendTo[tests, VerificationTest[{StringStartsQ[plainJob["ReducerNote"], "slice point: Kira"], plainJob["Kira"] =!= None, summary[degJob], summary[lineJob]},
  {True, True, {True, None, True}, {True, None, True}},
  TestID -> "PFBSubtreeJob: a degree job and a line job are FiniteFlow's, with no Kira configuration; a plain job of the same subtree takes Kira"]];
(* run.wl's "Reducer" -> "Kira" (through run_info.m) is the default of plain jobs only *)
runDir = FileNameJoin[{tmp, "run"}]; CreateDirectory[runDir];
Put[<|"Run" -> <|"Reducer" -> "Kira"|>|>, FileNameJoin[{runDir, "run_info.m"}]];
runPlain = jobOf[writeJob["plain", <||>, runDir]];
runDeg = jobOf[writeJob["deg", <|"Degrees" -> degSpec|>, runDir]];
AppendTo[tests, VerificationTest[{runPlain["Reducer"], runPlain["Kira"] =!= None, summary[runDeg]},
  {"Kira", True, {True, None, True}}, TestID -> "run.wl's \"Reducer\" -> \"Kira\": a degree job stays FiniteFlow's"]];
(* "Reducer" -> "Kira" asked for with degrees: refused when the job is written *)
forced = Block[{Print}, writeJob["forced", <|"Degrees" -> degSpec, "Reducer" -> "Kira"|>]];
AppendTo[tests, VerificationTest[{forced, FileExistsQ[FileNameJoin[{tmp, "jobs", "forced", "job.m"}]]}, {$Failed, False},
  TestID -> "a degree job with \"Reducer\" -> \"Kira\" is refused"]];

(* PFBDegreesJob, as bin/degrees.wls and the simplification phase write it: a planted run with a slice of the box *)
Module[{dir = FileNameJoin[{tmp, "ctx"}], ctx, sl, job},
  CreateDirectory[dir];
  Put[masters, FileNameJoin[{dir, "box.m"}]];
  Put[<|"Name" -> "planted", "Families" -> {<|"Name" -> "box", "Family" -> boxFile, "Masters" -> "box.m"|>}, "Letters" -> {s, t, s + t}|>, FileNameJoin[{dir, "system.wl"}]];
  Put[<|"System" -> "system.wl", "OutputDir" -> FileNameJoin[{dir, "out"}], "AllowTmp" -> True, "Paths" -> Automatic|>, FileNameJoin[{dir, "run.wl"}]];
  ctx = Block[{Print}, PFBStartRun[FileNameJoin[{dir, "run.wl"}]]];
  plantTools[];
  sl = <|"R" -> {{{-eps/t, 0, 0}, {0, -1/t, 0}, {2 eps/(s + t), -2 eps/(s + t), -eps/t}}}, "Derivatives" -> {t}, "Point" -> {s -> 1, t -> 3}, "Labels" -> {1, 2, 3},
    "Index" -> <|1 -> 1, 2 -> 2, 3 -> 3|>, "Frame" -> "RootFree", "History" -> {}|>;
  ctx = Join[ctx, <|"State" -> PFBStoreSlice[ctx["Dir"], ctx["State"], sl, PFBCensus[ctx["System"], sl], "planted"]|>];
  job = jobOf[Block[{Print}, PFBDegreesJob[ctx, key]]];
  AppendTo[tests, VerificationTest[If[AssociationQ[job], {AssociationQ[job["Degrees"]], Length[job["Points"]], StringStartsQ[job["ReducerNote"], "slice point: FiniteFlow"], job["Kira"]}, job],
    {True, 1, True, None}, TestID -> "PFBDegreesJob: the degree job of a sector, at the slice point alone, is FiniteFlow's"]]];

report = TestReport[tests];
Do[With[{r = report["TestResults"][id]},
    Print[If[r["Outcome"] === "Success", "PASS ", "FAIL "], r["TestID"], If[r["Outcome"] === "Success", "",
      "\n     got " <> ToString[Short[r["ActualOutput"], 3], InputForm] <> "\n     expected " <> ToString[Short[r["ExpectedOutput"], 3], InputForm]]]],
  {id, Keys[report["TestResults"]]}];
Print[report["TestsSucceededCount"], " passed, ", report["TestsFailedCount"], " failed, ", Round[report["TimeElapsed"], 0.1]];
Quiet[DeleteDirectory[tmp, DeleteContents -> True]];
Exit[If[report["AllTestsSucceeded"], 0, 1]];
