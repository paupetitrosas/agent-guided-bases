#!/usr/bin/env wolframscript
(* Integration tests of the picard-fuchs step on two examples, from nothing: Kira's recount, the representations,
   the line DE (FiniteFlow, in this kernel), the label and both checks. Then the planted controls on the sunrise's
   real line DE: a random rational change of frame keeps the label, a perturbation that is no Gauss-Manin
   connection gives "unresolved". Needs Kira, FiniteFlow, LiteRed, LiteIBP and BaikovPackage; about 2 minutes.
   usage: bin/ws tests/picard_fuchs_examples.wls [paths.wl]        exit code 0 when every test passes
   (a paths.wl for the tools, else the usual detection; the copies of the examples go to a temporary folder) *)
Get[FileNameJoin[{ParentDirectory[DirectoryName[$InputFileName]], "lib", "MaximalCutBasis.wl"}]];
SeedRandom[20261014];

root = CreateDirectory[];
paths = SelectFirst[Rest[$ScriptCommandLine], FileExistsQ, None];
run[ex_, sec_] := Module[{d = FileNameJoin[{root, ex}], setup},
  CreateDirectory[d];
  Scan[CopyFile[FileNameJoin[{$MCBRoot, "examples", ex, #}], FileNameJoin[{d, #}]] &, {"family.wl", "run.wl"}];
  If[StringQ[paths], CopyFile[paths, FileNameJoin[{d, "paths.wl"}]]];
  setup = MCBRunSetup[FileNameJoin[{d, "run.wl"}]];
  <|"fam" -> setup["fam"], "sec" -> SectorFromName[sec], "dir" -> d,
    "pf" -> MCBPicardFuchs[setup["fam"], SectorFromName[sec], <|"Dir" -> FileNameJoin[{d, "pf"}]|>]|>];

(* not "sunrise" and "banana": those are the families' own symbols, inside every j[sunrise, ...] *)
sunriseRun = run["sunrise-equal-mass", "j11100"];
bananaRun = run["banana-three-loop", "j111100000"];

(* the sunrise's line DE at eps = 0, through the same points *)
a0 = Module[{fam = sunriseRun["fam"], s = sunriseRun["sec"], pts, ms, line},
  pts = MCBPoints[fam, 2, 1];
  ms = sunriseRun["pf"]["masters"];
  line = MCBFFLineDE[fam, s, ms, FileNameJoin[{sunriseRun["dir"], "line"}], <|"p0" -> pts[[1]], "p1" -> pts[[2]]|>, <|"Variable" -> t|>];
  If[line["status"] =!= "ok", Print["the line DE for the controls: ", KeyTake[line, {"status", "message"}]]];
  MCBPFRegularise[MCBPFLaurentMatrix[line["A"], line["kmin"], eps], t, eps]["A0"]];
gauged = Module[{g = Table[RandomInteger[{-3, 3}] + RandomInteger[{-2, 2}] t, {2}, {2}]},
  While[Det[g] === 0, g = Table[RandomInteger[{-3, 3}] + RandomInteger[{-2, 2}] t, {2}, {2}]];
  Together[g . a0 . Inverse[g] + D[g, t] . Inverse[g]]];
perturbed = a0 + {{0, 0}, {1/(3 (t - 5)), 0}};
labelOf[a_] := MCBPFClassifyOperator[MCBPFOperator[a, t, {3, 5}], t]["label"];

tests = {
  VerificationTest[sunriseRun["pf"]["label"], "elliptic", TestID -> "sunrise: elliptic"],
  VerificationTest[sunriseRun["pf"]["baikovCheck"]["status"], "agree", TestID -> "sunrise: log points = degenerations of the Baikov curve"],
  VerificationTest[sunriseRun["pf"]["kiraCheck"]["status"], "agree", TestID -> "sunrise: line DE = Kira at the first point"],
  VerificationTest[sunriseRun["pf"]["cornerOrder"], 2, TestID -> "sunrise: the corner integral's operator has order 2"],
  VerificationTest[bananaRun["pf"]["label"], "K3", TestID -> "banana: K3"],
  VerificationTest[bananaRun["pf"]["kiraCheck"]["status"], "agree", TestID -> "banana: line DE = Kira at the first point"],
  VerificationTest[bananaRun["pf"]["cornerOrder"], 3, TestID -> "banana: the corner integral's operator has order 3"],
  VerificationTest[labelOf[a0], "elliptic", TestID -> "control: the sunrise's eps = 0 connection"],
  VerificationTest[labelOf[gauged], "elliptic", TestID -> "control: a random rational frame keeps the label"],
  VerificationTest[StringStartsQ[labelOf[perturbed], "unresolved"], True, TestID -> "control: a perturbed connection is unresolved"]
};

report = TestReport[tests];
Do[With[{r = report["TestResults"][id]},
    Print[If[r["Outcome"] === "Success", "PASS ", "FAIL "], r["TestID"], If[r["Outcome"] === "Success", "",
      "\n     got " <> ToString[Short[r["ActualOutput"], 3], InputForm] <> "\n     expected " <> ToString[Short[r["ExpectedOutput"], 3], InputForm]]]],
  {id, Keys[report["TestResults"]]}];
Print["times: sunrise ", sunriseRun["pf"]["time"], " s ", sunriseRun["pf"]["timing"], ", banana ", bananaRun["pf"]["time"], " s ", bananaRun["pf"]["timing"]];
Print[report["TestsSucceededCount"], " passed, ", report["TestsFailedCount"], " failed, ", Round[report["TimeElapsed"], 0.1]];
Quiet[DeleteDirectory[root, DeleteContents -> True]];
Exit[If[report["AllTestsSucceeded"], 0, 1]];
