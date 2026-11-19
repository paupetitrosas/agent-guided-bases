#!/usr/bin/env wolframscript
(* Integration test of the simplification phase on the one-loop massless box of the maximal-cut-basis examples
   (tests/simplify_example.sh runs it): masters I2(s) = j[box,1,0,1,0], I2(t) = j[box,0,1,0,1] and the box with a planted
   bad normalisation, B3 = s^2/(t (s + t)) j[box,1,1,1,1]; unit scale s, letters s, t, s + t, derivative d/dt. The DE of
   the bare masters is known by hand (tests/degrees_example.wls checks it against FiniteFlow); the slice is planted from
   it at s = 1, t = 3/7, and the degree jobs must calibrate exactly against it. A maximal-cut-basis run of the box sector
   is planted too (its element eps^2 s t j[box,1,1,1,1]): its normalisation is the candidate "mcb".
   Expected: the census measures {5, 2, 23}; move (i) rescales the box by t^2 (s + t)^2/s^4 (the program predicts
   {2, 2, 7}: the diagonal is a bound) and the variant job measures {2, 1, 6}, the "mcb" candidate {2, 3, 9}; the gate
   accepts the change (rung "simplify") and the new slice is the hand DE of the rescaled basis.
   Phases (one kernel each): PFB_EXAMPLE_PHASE=prepare|check PFB_EXAMPLE_DIR=<scratch folder> [PFB_TEST_PATHS=paths.wl]
   bin/ws tests/simplify_example.wls; between them the shell runs bin/simplify.wls and the jobs it writes. *)
Get[FileNameJoin[{ParentDirectory[DirectoryName[$InputFileName]], "lib", "PoleFreeBasis.wl"}]];
$PFBVerbose = False;
phase = Environment["PFB_EXAMPLE_PHASE"]; dir = Environment["PFB_EXAMPLE_DIR"];
If[! StringQ[phase] || ! StringQ[dir] || ! DirectoryQ[dir], Print["set PFB_EXAMPLE_PHASE (prepare, check) and PFB_EXAMPLE_DIR (an existing folder)"]; Exit[2]];
paths = Environment["PFB_TEST_PATHS"];
runFile = FileNameJoin[{dir, "run.wl"}];
key3 = {box, {1, 1, 1, 1}};
P = {s -> 1, t -> 3/7};
Abare = {{0, 0, 0}, {0, -eps/t, 0}, {-2 (1 - 2 eps)/(s t (s + t)), 2 (1 - 2 eps)/(t^2 (s + t)), -(1/t + eps s/(t (s + t)))}};
rescaled[n_] := With[{Dm = DiagonalMatrix[{1, 1, n}]}, Together[Dm . Abare . Inverse[Dm] + D[Dm, t] . Inverse[Dm]]];
g3 = s^2/(t (s + t));
r3 = t^2 (s + t)^2/s^4;
(* {row, column} -> {{power, num, den}, ...} of a DE at s = 1, as a degree job measures it *)
termsOf[f_] := Module[{gg = Together[f /. s -> 1], rg}, rg = PFBEpsRange[gg];
  If[rg === "zero", {}, Table[With[{c = Together[SeriesCoefficient[gg, {eps, 0, p}]]}, If[c === 0, Nothing, {p, Exponent[Numerator[c], t], Exponent[Denominator[c], t]}]], {p, rg[[1]], rg[[2]]}]]];
expected[A_, rows_] := Association[Flatten[Table[If[termsOf[A[[r, c]]] === {}, Nothing, {r, c} -> termsOf[A[[r, c]]]], {r, rows}, {c, 3}], 1]];
measured[sec_] := Association[Table[{e["Row"], e["Column"]} -> ({#["Power"], #["Num"], #["Den"]} & /@ e["Terms"]), {e, Lookup[sec, "Entries", {}]}]];

Switch[phase,
"prepare", Module[{ctx, sl, mcb = FileNameJoin[{dir, "mcb"}]},
  Put[{j[box, 1, 0, 1, 0], j[box, 0, 1, 0, 1], g3 j[box, 1, 1, 1, 1]}, FileNameJoin[{dir, "masters.m"}]];
  CreateDirectory[FileNameJoin[{mcb, "j1111"}], CreateIntermediateDirectories -> True];
  Put[{eps^2 s t j[box, 1, 1, 1, 1]}, FileNameJoin[{mcb, "j1111", "masters.m"}]];
  Put[<|"status" -> "eps-form", "masters" -> {<|"definition" -> eps^2 s t j[box, 1, 1, 1, 1], "normalisation" -> "rational"|>}|>, FileNameJoin[{mcb, "j1111", "basis.m"}]];
  Put[<|"Name" -> "box example", "Families" -> {<|"Name" -> "box", "Family" -> FileNameJoin[{ParentDirectory[$PFBRoot], "maximal-cut-basis", "examples", "box-one-loop", "family.wl"}],
      "Masters" -> "masters.m", "MCBRun" -> "mcb"|>}, "Letters" -> {s, t, s + t}|>, FileNameJoin[{dir, "system.wl"}]];
  (* move (i) only: tests/simplify_moves_example.sh runs the later ones *)
  Put[Join[<|"System" -> "system.wl", "OutputDir" -> FileNameJoin[{dir, "run"}], "AllowTmp" -> True, "Seeds" -> <|"Rank" -> 2, "Dots" -> 1|>, "Threads" -> 2, "TimeLimit" -> 900,
      "SimplifyMoves" -> {"rescale"}|>,
     If[StringQ[paths] && FileExistsQ[paths], <|"Paths" -> paths|>, <||>]], runFile];
  ctx = PFBStartRun[runFile];
  sl = <|"R" -> {Together[rescaled[g3] /. P]}, "Derivatives" -> {t}, "Point" -> P, "Labels" -> {1, 2, 3}, "Index" -> <|1 -> 1, 2 -> 2, 3 -> 3|>, "Frame" -> "RootFree",
    "Source" -> "planted from the DE by hand", "History" -> {}|>;
  PFBStoreSlice[ctx["Dir"], ctx["State"], sl, PFBCensus[ctx["System"], sl], "planted slice"];
  Print["prepared: ", ctx["Dir"]];
  Exit[0]],

"check", Module[{ctx = PFBStartRun[runFile], st, ph, phNew, old, sl, mv, cands, ip, mcb, rec, tab, sec3, rep, ch, sm, jobTimes},
  st = ctx["State"];
  (* the phase that ran is kept as simplify/phase_<date>.m by the last call (--new) *)
  old = FileNames["phase_*.m", FileNameJoin[{ctx["Dir"], "simplify"}]];
  ph = If[Length[old] == 1, Get[First[old]], None];
  phNew = PFBReadPhase[ctx["Dir"]];
  sl = PFBCurrentSlice[ctx["Dir"], st];
  mv = If[AssociationQ[ph] && ph["Moves"] =!= {}, First[ph["Moves"]], <||>];
  cands = Association[(#["Name"] -> #) & /@ Lookup[mv, "Candidates", {}]];
  ip = Lookup[cands, "ip", <||>]; mcb = Lookup[cands, "mcb", <||>];
  rec = SelectFirst[st["Accepted"], Lookup[#, "Rung", None] === "simplify" &, <||>];
  tab = PFBReadDegrees[ctx["Dir"], st];
  sec3 = If[AssociationQ[tab], tab["Sectors"][key3], <||>];
  rep = PFBMakeReports[ctx["Dir"], ctx["System"], st];
  ch = Import[FileNameJoin[{ctx["Dir"], "CHANGES.md"}], "Text"];
  sm = If[StringQ[rep], Import[rep, "Text"], ""];
  jobTimes = If[AssociationQ[ph] && AssociationQ[Lookup[ph, "Start", None]], Lookup[Lookup[ph, "Census", <||>], "Jobs", {}], {}];
  tests = {
    VerificationTest[{AssociationQ[ph], Lookup[ph, "Status", None], ph["Start"]["Summary"]["Highest"], ph["Start"]["Summary"]["Count"], ph["Start"]["Summary"]["Sum"]},
      {True, "done", 5, 2, 23}, TestID -> "census: the planted bad normalisation measures {5, 2, 23}"],
    VerificationTest[{Length[jobTimes], AllTrue[Values[Select[PFBReadDegrees[ctx["Dir"], st, 1]["Sectors"], #["Status"] === "measured" &]], NumericQ[#["JobWallSeconds"]] && #["JobSectors"] == 1 &]},
      {3, True}, TestID -> "census: one timed degree job per sector"],
    VerificationTest[{ph["Budget"]["Source"], NumericQ[ph["Budget"]["Seconds"]] && ph["Budget"]["Seconds"] == ph["Budget"]["Proposed"]}, {"the proposal, accepted by the user", True},
      TestID -> "budget: proposed, then accepted"],
    VerificationTest[{mv["Move"], mv["Status"], mv["Chosen"], Sort[Keys[cands]]}, {"rescale", "accepted", "ip", {"ip", "mcb"}}, TestID -> "move (i): two candidates measured, the program's chosen"],
    VerificationTest[{ip["Objective"], ip["MeasuredObjective"], mcb["MeasuredObjective"]}, {{2, 2, 7}, {2, 1, 6}, {2, 3, 9}},
      TestID -> "move (i): predicted and measured objectives (the diagonal's prediction is a bound)"],
    VerificationTest[{Together[ip["Info"]["Rescalings"][3] - r3], Together[mcb["Info"]["Rescalings"][3] - t^2 (s + t)/s^3]}, {0, 0},
      TestID -> "move (i): the rescalings, the planted normalisation undone"],
    VerificationTest[{rec["Rung"], rec["Replace"], Together[rec["NewDefs"][3] - r3 g3 j[box, 1, 1, 1, 1]], Lookup[rec["Simplify"], "AfterObjective", None],
      AllTrue[rec["Gate"], #["Pass"] &]}, {"simplify", {3}, 0, {2, 1, 6}, True}, TestID -> "gate: the change is recorded with rung simplify"],
    VerificationTest[Together[sl["R"][[1]] - (rescaled[g3 r3] /. P)], ConstantArray[0, {3, 3}], TestID -> "the new slice is the hand DE of the rescaled basis"],
    VerificationTest[{AssociationQ[tab], tab["Summary"]["Highest"], tab["Summary"]["Count"], tab["Summary"]["Sum"], measured[sec3]}, {True, 2, 1, 6, expected[rescaled[g3 r3], {3}]},
      TestID -> "the degrees of the new slice: the variant's measurement, as by hand"],
    VerificationTest[{StringContainsQ[ch, {"## Kinematic degrees", "| after the simplification phase |", "candidate ip: predicted {2, 2, 7}, measured {2, 1, 6}"}],
      StringContainsQ[sm, {"Degrees by stage", "Simplification phase"}]}, {True, True}, TestID -> "reports: CHANGES.md and summary.html"],
    VerificationTest[{Length[old], AssociationQ[phNew], Lookup[phNew, "Moves", None], Lookup[phNew, "Status", None], KeyExistsQ[phNew, "Proposal"], Lookup[Lookup[phNew, "Start", <||>], "Summary", <||>]["Highest"]},
      {1, True, {}, "open", True, 2}, TestID -> "a new phase starts from the measured degrees of the new slice and asks for a budget"]
  };
  report = TestReport[tests];
  Do[With[{r = report["TestResults"][id]},
      Print[If[r["Outcome"] === "Success", "PASS ", "FAIL "], r["TestID"], If[r["Outcome"] === "Success", "",
        "\n     got " <> ToString[Short[r["ActualOutput"], 6], InputForm] <> "\n     expected " <> ToString[Short[r["ExpectedOutput"], 6], InputForm]]]],
    {id, Keys[report["TestResults"]]}];
  Print["degree jobs of the phase: ", Round[Lookup[ph, "Spent", 0]], " s of move jobs; census jobs ",
    Round[Total[Replace[Lookup[PFBSubtreeStatus[#], "Seconds", 0], Except[_?NumericQ] -> 0] & /@ jobTimes]], " s"];
  Print[report["TestsSucceededCount"], " passed, ", report["TestsFailedCount"], " failed"];
  Exit[If[report["AllTestsSucceeded"], 0, 1]]],

_, Print["unknown phase ", phase]; Exit[2]];
