#!/usr/bin/env wolframscript
(* Integration test of moves (iii) and (ii) on the one-loop massless box of the maximal-cut-basis examples
   (tests/simplify_moves_example.sh runs it): masters I2(s) = j[box,1,0,1,0], I2(t) = j[box,0,1,0,1] and the box with a
   planted shift by the t-bubble, B3 = j[box,1,1,1,1] + t^2/s^4 j[box,0,1,0,1]; unit scale s, letters s, t, s + t,
   derivative d/dt. The DE of the bare masters is known by hand (tests/degrees_example.wls checks it against FiniteFlow);
   the slice is planted from A = T A_bare T^-1 + dT T^-1 at s = 1, t = 3/7, and every job must calibrate exactly
   against it. One move runs (PFB_EXAMPLE_MOVE: "shift" or "swap", run.wl "SimplifyMoves").
   Expected: the census measures {4, 2, 16}; move (iii) finds, from the samples of one job, the shift by -t^2/s^4 (target
   degree 3, not 2); move (ii) finds, on a reduction of the box sector at the slice point, the box integral alone (no
   other set of the scan clears the box row); the variant job measures {3, 2, 14} (for the swap with T^-1 inside
   its graph); the gate accepts it and the new slice is the hand DE of the bare masters.
   Phases (one kernel each): PFB_EXAMPLE_PHASE=prepare|check PFB_EXAMPLE_DIR=<scratch folder> PFB_EXAMPLE_MOVE=shift|swap
   [PFB_TEST_PATHS=paths.wl] bin/ws tests/simplify_moves_example.wls; between them the shell runs bin/simplify.wls and the
   jobs it writes. *)
Get[FileNameJoin[{ParentDirectory[DirectoryName[$InputFileName]], "lib", "PoleFreeBasis.wl"}]];
$PFBVerbose = False;
phase = Environment["PFB_EXAMPLE_PHASE"]; dir = Environment["PFB_EXAMPLE_DIR"];
If[! StringQ[phase] || ! StringQ[dir] || ! DirectoryQ[dir], Print["set PFB_EXAMPLE_PHASE (prepare, check) and PFB_EXAMPLE_DIR (an existing folder)"]; Exit[2]];
paths = Environment["PFB_TEST_PATHS"];
move = Replace[Environment["PFB_EXAMPLE_MOVE"], Except["shift" | "swap"] -> "shift"];
runFile = FileNameJoin[{dir, "run.wl"}];
key3 = {box, {1, 1, 1, 1}};
P = {s -> 1, t -> 3/7};
Abare = {{0, 0, 0}, {0, -eps/t, 0}, {-2 (1 - 2 eps)/(s t (s + t)), 2 (1 - 2 eps)/(t^2 (s + t)), -(1/t + eps s/(t (s + t)))}};
c32 = t^2/s^4;
Tm = {{1, 0, 0}, {0, 1, 0}, {0, c32, 1}};
Ashift = Together[Tm . Abare . Inverse[Tm] + D[Tm, t] . Inverse[Tm]];

Switch[phase,
"prepare", Module[{ctx, sl},
  Put[{j[box, 1, 0, 1, 0], j[box, 0, 1, 0, 1], j[box, 1, 1, 1, 1] + c32 j[box, 0, 1, 0, 1]}, FileNameJoin[{dir, "masters.m"}]];
  Put[<|"Name" -> "box example", "Families" -> {<|"Name" -> "box", "Family" -> FileNameJoin[{ParentDirectory[$PFBRoot], "maximal-cut-basis", "examples", "box-one-loop", "family.wl"}],
      "Masters" -> "masters.m"|>}, "Letters" -> {s, t, s + t}|>, FileNameJoin[{dir, "system.wl"}]];
  Put[Join[<|"System" -> "system.wl", "OutputDir" -> FileNameJoin[{dir, "run"}], "AllowTmp" -> True, "Seeds" -> <|"Rank" -> 2, "Dots" -> 1|>, "Threads" -> 2, "TimeLimit" -> 900,
      "SimplifyMoves" -> {move}|>, If[StringQ[paths] && FileExistsQ[paths], <|"Paths" -> paths|>, <||>]], runFile];
  ctx = PFBStartRun[runFile];
  sl = <|"R" -> {Together[Ashift /. P]}, "Derivatives" -> {t}, "Point" -> P, "Labels" -> {1, 2, 3}, "Index" -> <|1 -> 1, 2 -> 2, 3 -> 3|>, "Frame" -> "RootFree",
    "Source" -> "planted from the DE by hand", "History" -> {}|>;
  PFBStoreSlice[ctx["Dir"], ctx["State"], sl, PFBCensus[ctx["System"], sl], "planted slice"];
  Print["prepared: ", ctx["Dir"]];
  Exit[0]],

"check", Module[{ctx = PFBStartRun[runFile], st, ph, mv, sl, rec, cand, tab, fitJob, fitTime},
  st = ctx["State"];
  ph = PFBReadPhase[ctx["Dir"]];
  sl = PFBCurrentSlice[ctx["Dir"], st];
  mv = If[AssociationQ[ph] && ph["Moves"] =!= {}, First[ph["Moves"]], <||>];
  cand = SelectFirst[Lookup[mv, "Candidates", {}], #["Name"] === Lookup[mv, "Chosen", None] &, <||>];
  rec = SelectFirst[st["Accepted"], Lookup[#, "Rung", None] === "simplify" &, <||>];
  tab = PFBReadDegrees[ctx["Dir"], st];
  fitJob = If[ListQ[Lookup[mv, "PrepJobs", None]], First[mv["PrepJobs"]], None];
  fitTime = If[StringQ[fitJob], Lookup[PFBSubtreeStatus[fitJob], "Seconds", Missing[]], Missing[]];
  tests = Join[{
    VerificationTest[{AssociationQ[ph], Lookup[ph, "Status", None], ph["Start"]["Summary"]["Highest"], ph["Start"]["Summary"]["Count"], ph["Start"]["Summary"]["Sum"]},
      {True, "done", 4, 2, 16}, TestID -> move <> ": census: the planted shift measures {4, 2, 16}"]},
   If[move === "shift", {
    VerificationTest[{mv["Move"], mv["Status"], mv["Info"]["Row"], Sort[mv["Info"]["Lower"]], Lookup[mv, "PrepStages", None], NumericQ[Lookup[mv, "PrepSpent", None]]},
      {"shift", "accepted", 3, {1, 2}, 1, True}, TestID -> "move (iii): the box row shifted by the bubbles, one job of samples"],
    VerificationTest[{cand["Info"]["Target"], Together[cand["Info"]["Coefficients"][2] + c32], Together[cand["Info"]["Coefficients"][1]], cand["MeasuredObjective"]},
      {3, 0, 0, {3, 2, 14}}, TestID -> "move (iii): the fit undoes the planted shift (target 3), measured {3, 2, 14}"]}, {
    VerificationTest[{mv["Move"], mv["Status"], mv["Info"]["Master"], Lookup[mv, "PrepStages", None], StringContainsQ[FileNameTake[Lookup[mv["Info"], "Job", ""]], "_scan_"]},
      {"swap", "accepted", 3, 1, True}, TestID -> "move (ii): the box swapped, on a reduction of its sector written by the move"],
    VerificationTest[{cand["Info"]["Set"], cand["MeasuredObjective"], Lookup[mv["Info"], "Clear", None] >= 1},
      {<|3 -> j[box, 1, 1, 1, 1]|>, {3, 2, 14}, True}, TestID -> "move (ii): the box integral alone, measured {3, 2, 14} with T^-1 inside the job's graph"]}], {
    VerificationTest[{rec["Rung"], rec["Replace"], Together[rec["NewDefs"][3] - j[box, 1, 1, 1, 1]], AllTrue[rec["Gate"], #["Pass"] &]}, {"simplify", {3}, 0, True},
      TestID -> move <> ": gate: the change is recorded, the box back in integrals"],
    VerificationTest[Together[sl["R"][[1]] - (Abare /. P)], ConstantArray[0, {3, 3}], TestID -> move <> ": the new slice is the hand DE of the bare masters"],
    VerificationTest[{AssociationQ[tab], KeyTake[tab["Summary"], {"Highest", "Count", "Sum"}]}, {True, <|"Highest" -> 3, "Count" -> 2, "Sum" -> 14|>},
      TestID -> move <> ": the degrees of the new slice: the variant's measurement"]
  }];
  report = TestReport[tests];
  Do[With[{r = report["TestResults"][id]},
      Print[If[r["Outcome"] === "Success", "PASS ", "FAIL "], r["TestID"], If[r["Outcome"] === "Success", "",
        "\n     got " <> ToString[Short[r["ActualOutput"], 6], InputForm] <> "\n     expected " <> ToString[Short[r["ExpectedOutput"], 6], InputForm]]]],
    {id, Keys[report["TestResults"]]}];
  Print[Lookup[mv, "Message", "-"]];
  Print["the move's own job: ", fitTime, " s; the phase's moves: ", Round[Lookup[ph, "Spent", 0]], " s of jobs"];
  Print[report["TestsSucceededCount"], " passed, ", report["TestsFailedCount"], " failed"];
  Exit[If[report["AllTestsSucceeded"], 0, 1]]],

_, Print["unknown phase ", phase]; Exit[2]];
