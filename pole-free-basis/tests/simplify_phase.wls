#!/usr/bin/env wolframscript
(* The simplification phase's steps without FiniteFlow or IBP. Planted data as in tests/simplify.wls: the one-loop
   massless box of the maximal-cut-basis examples (unit scale s, letters s, t, s + t, derivative d/dt) with a planted
   bad normalisation of the box master, B3 = s^2/(t (s + t)) I4, and its known DE. The degree jobs are planted: the
   phase's PFBDegreesJob is replaced by a function that writes a finished job folder (job.m, status.m, the reduction at
   the slice point, degrees.m with planted measurements), so that the phase runs end to end on known numbers.
   Checked: a slice without a derivative in every invariant but the unit scale (refused); a candidate whose measured
   rows show a finite pole at the degree job's own point (refused, and the next best taken; the gate records the check);
   the census job's times kept in the table after an accepted move (not the variant job's); a pending simplification
   declined by the user (PFBDecline, then the phase goes on); census jobs that failed (run once more, then not measured).
   usage: bin/ws tests/simplify_phase.wls        exit code 0 when every test passes *)
Get[FileNameJoin[{ParentDirectory[DirectoryName[$InputFileName]], "lib", "PoleFreeBasis.wl"}]];
$PFBVerbose = False;
boxFile = FileNameJoin[{ParentDirectory[$PFBRoot], "maximal-cut-basis", "examples", "box-one-loop", "family.wl"}];
key3 = {box, {1, 1, 1, 1}}; key2 = {box, {0, 1, 0, 1}}; key1 = {box, {1, 0, 1, 0}};
P = {s -> 1, t -> 3/7};
Abare = {{0, 0, 0}, {0, -eps/t, 0}, {-2 (1 - 2 eps)/(s t (s + t)), 2 (1 - 2 eps)/(t^2 (s + t)), -(1/t + eps s/(t (s + t)))}};
rescaled[n_] := With[{Dm = DiagonalMatrix[{1, 1, n}]}, Together[Dm . Abare . Inverse[Dm] + D[Dm, t] . Inverse[Dm]]];
g3 = s^2/(t (s + t)); r3 = t^2 (s + t)^2/s^4;
Abad = rescaled[g3];
probes = {t, 1 + t};
mult[p_, q_] := Module[{m = 0}, While[PolynomialRemainder[p, q^(m + 1), t] === 0, m++]; m];
letterContent[p_] := Association[Select[Table[q -> mult[p, q], {q, probes}], #[[2]] > 0 &]];
termOf[c_, pw_] := Module[{gg = Together[c], n, d, nl, dl},
  n = Numerator[gg]; d = Denominator[gg]; nl = letterContent[n]; dl = letterContent[d];
  <|"Power" -> pw, "Num" -> Exponent[n, t], "Den" -> Exponent[d, t], "VarDegrees" -> {{Exponent[n, t], 0, Exponent[d, t], 0}}, "NumLetters" -> nl, "DenLetters" -> dl,
    "NumUnexplained" -> Exponent[n, t] - Total[KeyValueMap[#2 Exponent[#1, t] &, nl]], "DenUnexplained" -> Exponent[d, t] - Total[KeyValueMap[#2 Exponent[#1, t] &, dl]]|>];
entriesOf[A_, rows_] := Flatten[Table[With[{f = Together[A[[r, c]] /. s -> 1]}, If[f === 0, {},
     With[{rg = PFBEpsRange[f]}, {<|"Matrix" -> 1, "Derivative" -> t, "Row" -> r, "Column" -> c, "Eps" -> {"Laurent", rg[[1]], rg[[2]]},
       "Terms" -> Table[With[{cf = Together[SeriesCoefficient[f, {eps, 0, pw}]]}, If[cf === 0, Nothing, termOf[cf, pw]]], {pw, rg[[1]], rg[[2]]}]|>}]]], {r, rows}, {c, 3}], 2];
secRec[A_, rows_, wall_, meas_] := With[{ents = entriesOf[A, rows]}, <|"Status" -> "measured", "Source" -> "measured", "Job" -> "planted", "Rows" -> rows, "Entries" -> ents,
   "Summary" -> PFBDegreeSummary[ents], "Probes" -> probes, "JobSectors" -> 1, "JobWallSeconds" -> wall, "JobSeconds" -> meas|>];
tableOf[A_] := Module[{tb = <|"Keys" -> {key1, key2, key3}, "UnitScale" -> s, "Vars" -> {t}, "Provenance" -> <|"Source" -> "measured"|>,
     "Sectors" -> <|key1 -> secRec[A, {1}, 11, 1], key2 -> secRec[A, {2}, 12, 1], key3 -> secRec[A, {3}, 20, 2]|>|>}, Join[tb, <|"Summary" -> PFBDegreeSummary[tb]|>]];
mastersBad = {j[box, 1, 0, 1, 0], j[box, 0, 1, 0, 1], g3 j[box, 1, 1, 1, 1]};
newRun[dir_, A_, ders_ : {t}, run_ : <||>] := Module[{ctx, sl},
  CreateDirectory[dir, CreateIntermediateDirectories -> True];
  Put[mastersBad, FileNameJoin[{dir, "masters.m"}]];
  Put[<|"Name" -> "planted", "Families" -> {<|"Name" -> "box", "Family" -> boxFile, "Masters" -> "masters.m"|>}, "Letters" -> {s, t, s + t}|>, FileNameJoin[{dir, "system.wl"}]];
  Put[Join[<|"System" -> "system.wl", "OutputDir" -> FileNameJoin[{dir, "run"}], "AllowTmp" -> True, "Paths" -> Automatic|>, run], FileNameJoin[{dir, "run.wl"}]];
  ctx = PFBStartRun[FileNameJoin[{dir, "run.wl"}]];
  sl = <|"R" -> {Together[A /. P]}, "Derivatives" -> ders, "Point" -> P, "Labels" -> {1, 2, 3}, "Index" -> <|1 -> 1, 2 -> 2, 3 -> 3|>, "Frame" -> "RootFree", "History" -> {}|>;
  Join[ctx, <|"State" -> PFBStoreSlice[ctx["Dir"], ctx["State"], sl, PFBCensus[ctx["System"], sl], "planted"]|>]];
withTable[ctx_, A_] := Join[ctx, <|"State" -> PFBStoreDegrees[ctx["Dir"], ctx["State"], 1, Join[tableOf[A], <|"Slice" -> ctx["State"]["Current"]|>]]|>];
tmp = CreateDirectory[];

(* ---- the derivatives of the slice ---- *)
(* the box's slice with d/ds alone: the degrees in t would never be measured *)
ctxD = newRun[FileNameJoin[{tmp, "derivatives"}], Abad, {s}];
stepD = PFBSimplifyStep[ctxD, <|"Budget" -> 600|>];

(* ---- planted degree jobs ---- *)
(* the runner's form of an entry: the column as a master of the reduction *)
runnerForm[ents_] := (Join[#, <|"Column" -> ut[#["Column"]]|>] &) /@ ents;
goodEnts = entriesOf[rescaled[g3 r3], {3}];
(* lower than good, but with finite poles at the job's point: whole entries of degree 0 *)
badEnts = {<|"Matrix" -> 1, "Derivative" -> t, "Row" -> 3, "Column" -> 3, "Eps" -> {"Whole", "finite poles"},
    "Terms" -> {<|"Power" -> "whole", "Num" -> 0, "Den" -> 0, "VarDegrees" -> {{0, 0, 0, 0}}, "NumLetters" -> <||>, "DenLetters" -> <||>, "NumUnexplained" -> 0, "DenUnexplained" -> 0|>}|>};
plantedVariants = <|"good" -> goodEnts, "bad" -> badEnts|>;
redAt[ctx_] := With[{sl = PFBCurrentSlice[ctx["Dir"], ctx["State"]]}, <|"Masters" -> (ut /@ sl["Labels"]), "Point" -> sl["Point"], "Invariants" -> sl["Derivatives"],
   "Focus" -> sl["Labels"], "Dm" -> sl["R"], "Pool" -> {}, "Rp" -> {}, "dRp" -> {{}}|>];
(* a finished variant job of the sector: 300 s of kernel, each variant measured in 4 s *)
plantVariantJob[ctx_, key_, o_] := Module[{jd = FileNameJoin[{ctx["Dir"], "jobs", Lookup[o, "Name", "deg"]}]},
  CreateDirectory[jd, CreateIntermediateDirectories -> True];
  Put[<|"Degrees" -> <|"Keys" -> {key}, "ProbeSources" -> <||>, "UnitScaleOnly" -> {}|>|>, FileNameJoin[{jd, "job.m"}]];
  Put[<|"Status" -> "done", "Seconds" -> 300|>, FileNameJoin[{jd, "status.m"}]];
  Put[redAt[ctx], FileNameJoin[{jd, "red_1.m"}]];
  Put[<|"Status" -> "measured", "Rows" -> {3}, "Columns" -> (ut /@ {1, 2, 3}), "Derivatives" -> {t}, "Vars" -> {t}, "Fix" -> {s -> 1}, "Cap" -> 2, "Eps" -> 1/3,
     "Point" -> {t -> 101}, "Probes" -> probes, "Entries" -> {},
     "Variants" -> Association[Table[v["Name"] -> <|"Status" -> "measured", "Rows" -> {3}, "Entries" -> runnerForm[plantedVariants[v["Name"]]], "Seconds" -> 4|>,
       {v, Lookup[o, "Variants", {}]}]], "Samples" -> {}, "Seconds" -> 10, "CPUSeconds" -> 10, "Threads" -> 1, "Steps" -> {}|>, FileNameJoin[{jd, "degrees.m"}]];
  jd];
(* a planted move: the same rescaling, measured twice as two candidates *)
plantedMove[cx_, tb_, ph_, op_] := <|"Status" -> "proposed", "Message" -> "two planted candidates",
   "Candidates" -> {<|"Name" -> "bad", "T" -> <|3 -> r3 ut[3]|>, "Objective" -> {0, 1, 0}|>, <|"Name" -> "good", "T" -> <|3 -> r3 ut[3]|>, "Objective" -> {2, 1, 6}|>}|>;
moves = {<|"Name" -> "planted", "Title" -> "planted candidates", "Propose" -> plantedMove|>};
phaseStep[ctx_, opts_ : <||>] := Block[{$PFBSimplifyMoves = moves, PFBDegreesJob = plantVariantJob}, PFBSimplifyStep[ctx, opts]];

(* ---- away from the slice, and the census job's times ---- *)
ctxB = withTable[newRun[FileNameJoin[{tmp, "offslice"}], Abad], Abad];
stepB1 = phaseStep[ctxB, <|"Budget" -> 10^4|>];
stepB2 = phaseStep[stepB1["Context"]];
phB = PFBReadPhase[ctxB["Dir"]];
moveB = If[AssociationQ[phB], First[phB["Moves"]], <||>];
candB[n_] := SelectFirst[Lookup[moveB, "Candidates", {}], #["Name"] === n &, <||>];
stB = stepB2["Context"]["State"];
recB = If[stB["Accepted"] === {}, <||>, Last[stB["Accepted"]]];
tabB = PFBReadDegrees[ctxB["Dir"], stB];
gateB = SelectFirst[Lookup[recB, "Gate", {}], #["Name"] === "away from the slice" &, <||>];

(* ---- a pending simplification declined ---- *)
ctxC = withTable[newRun[FileNameJoin[{tmp, "decline"}], Abad], Abad];
ctxC = Join[ctxC, <|"State" -> PFBSaveState[ctxC["Dir"], Join[ctxC["State"], <|"Approval" -> True|>]]|>];
stepC1 = phaseStep[ctxC, <|"Budget" -> 10^4|>];
stepC2 = phaseStep[stepC1["Context"]];
pendC = stepC2["Context"]["State"]["Pending"];
decC = PFBDecline[ctxC["Dir"], stepC2["Context"]["State"], stepC2["Context"]["System"], If[pendC === {}, 0, pendC[[1, "Id"]]], "planted: the user said no"];
stepC3 = phaseStep[Join[stepC2["Context"], <|"State" -> decC["State"]|>]];
phC = PFBReadPhase[ctxC["Dir"]];
stateC = PFBStartRun[FileNameJoin[{tmp, "decline", "run.wl"}]]["State"];

(* ---- census jobs that fail ---- *)
plantCensusJob[ctx_, key_, o_] := Module[{jd = FileNameJoin[{ctx["Dir"], "jobs", "deg_" <> PoleFreeBasis`Simplify`Private`sectorJobName[key]}]},
  CreateDirectory[jd, CreateIntermediateDirectories -> True];
  Put[<|"Degrees" -> <|"Keys" -> {key}, "ProbeSources" -> <||>, "UnitScaleOnly" -> {}|>|>, FileNameJoin[{jd, "job.m"}]];
  jd];
failJobs[ctx_] := Scan[Put[<|"Status" -> "failed", "Seconds" -> 5, "Message" -> "planted failure"|>, FileNameJoin[{#, "status.m"}]] &,
   FileNames["deg_*", FileNameJoin[{ctx["Dir"], "jobs"}]]];
censusStep[ctx_, opts_ : <||>] := Block[{$PFBSimplifyMoves = {}, PFBDegreesJob = plantCensusJob}, PFBSimplifyStep[ctx, opts]];
ctxE = newRun[FileNameJoin[{tmp, "census"}], Abad];
stepE1 = censusStep[ctxE, <|"Budget" -> 600|>];
failJobs[ctxE];
stepE2 = censusStep[stepE1["Context"]];
phE2 = PFBReadPhase[ctxE["Dir"]];
stepE3 = censusStep[stepE2["Context"], <|"Budget" -> 600|>];
tabE = PFBReadDegrees[ctxE["Dir"], stepE3["Context"]["State"]];

tests = {
  VerificationTest[{stepD["Outcome"], StringContainsQ[stepD["Message"], {"derivatives", "{t}"}], Lookup[stepD, "MissingDerivatives", None]}, {"refused", True, {t}},
    TestID -> "derivatives: a slice without d/dt refuses the phase, with the reason"],
  (* away from the slice *)
  VerificationTest[{stepB1["Outcome"], stepB2["Outcome"], moveB["Status"], moveB["Chosen"]}, {"jobs", "done", "accepted", "good"},
    TestID -> "away from the slice: the planted phase measures both candidates and accepts the good one"],
  VerificationTest[{candB["bad"]["MeasuredObjective"], candB["good"]["MeasuredObjective"], candB["bad"]["OffSlice"]["Pass"], StringContainsQ[candB["bad"]["OffSlice"]["Detail"], "finite poles"],
      candB["good"]["OffSlice"]["Pass"]}, {{1, 1, 1}, {2, 1, 6}, False, True, True},
    TestID -> "away from the slice: the lower candidate shows a finite pole at its degree job's point and is refused"],
  VerificationTest[{gateB["Pass"], Lookup[gateB, "NotChecked", False]}, {True, False}, TestID -> "away from the slice: the gate records the check of the chosen candidate"],
  (* the census job's times *)
  VerificationTest[{tabB["Sectors"][key3]["JobWallSeconds"], tabB["Sectors"][key3]["JobSeconds"], tabB["Sectors"][key3]["VariantJobWallSeconds"], tabB["Sectors"][key3]["VariantSeconds"],
      tabB["Sectors"][key1]["JobWallSeconds"]}, {20, 2, 300, 4, 11}, TestID -> "budget: an accepted move keeps the census job's times; the variant job's are kept apart"],
  (* declined *)
  VerificationTest[{stepC2["Outcome"], StringContainsQ[stepC2["Message"], "--decline"], Length[pendC], decC["Record"]["DeclineReason"]}, {"approval", True, 1, "planted: the user said no"},
    TestID -> "decline: a pending simplification can be declined"],
  VerificationTest[{stateC["Pending"], KeyExistsQ[Last[stateC["Rejected"]], "Declined"], stepC3["Outcome"], First[phC["Moves"]]["Status"], StringContainsQ[stepC3["Message"], "declined"]},
    {{}, True, "done", "declined", True}, TestID -> "decline: recorded as rejected, and the phase goes on"],
  (* census jobs *)
  VerificationTest[{stepE1["Outcome"], stepE2["Outcome"], StringContainsQ[stepE2["Message"], "once more"], Sort[phE2["Census"]["Retried"]]}, {"jobs", "jobs", True, Sort[{key1, key2, key3}]},
    TestID -> "census: failed degree jobs are run once more"],
  VerificationTest[{stepE3["Outcome"], StringContainsQ[stepE3["Message"], "not measured after one retry"], Lookup[tabE["Sectors"][key3], "Status", None]},
    {"done", True, "not measured"}, TestID -> "census: after a second failure their sectors are not measured, and the phase goes on"]
};

report = TestReport[tests];
Do[With[{r = report["TestResults"][id]},
    Print[If[r["Outcome"] === "Success", "PASS ", "FAIL "], r["TestID"], If[r["Outcome"] === "Success", "",
      "\n     got " <> ToString[Short[r["ActualOutput"], 3], InputForm] <> "\n     expected " <> ToString[Short[r["ExpectedOutput"], 3], InputForm]]]],
  {id, Keys[report["TestResults"]]}];
Print[report["TestsSucceededCount"], " passed, ", report["TestsFailedCount"], " failed, ", Round[report["TimeElapsed"], 0.1]];
DeleteDirectory[tmp, DeleteContents -> True];
Exit[If[report["AllTestsSucceeded"], 0, 1]];
