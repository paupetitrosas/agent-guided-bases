#!/usr/bin/env wolframscript
(* Integration test of the degree census on the one-loop massless box of the maximal-cut-basis examples, masters
   j[box,1,0,1,0], j[box,0,1,0,1], j[box,1,1,1,1], unit scale s = 1, derivative d/dt. Its DE is known by hand
   (d = 4 - 2 eps; from the canonical form f1 = eps (1 - 2 eps) I2(s), f2 = eps (1 - 2 eps) I2(t), f3 = eps^2 s t I4, with
   d f3/dt = eps [-2/(s + t) f1 + 2 s/(t (s + t)) f2 - s/(t (s + t)) f3], fixed by the eps expansion of the box):
     d I2(t)/dt = -eps/t I2(t),   d I2(s)/dt = 0,
     d I4/dt = -2 (1 - 2 eps)/(s t (s + t)) I2(s) + 2 (1 - 2 eps)/(t^2 (s + t)) I2(t) - (1/t + eps s/(t (s + t))) I4.
   Its value at the slice point is checked against the local slice, exactly in eps, before its degrees are compared.
   Checked: the starting degrees of the local slice (bin/local_slice.wls's job, on the same learned system), a sector's
   degree job (bin/degrees.wls's) with a variant (the box rescaled by t) and a sample point, the letter content with the
   letters s, t, s + t, and det T of a planted change (box -> (s + 2 t) box) along a line, whose factor 1 + 2 t is no
   letter: spurious. No IBP outside the jobs.
   Three phases (one kernel at a time; the jobs in between), run by tests/degrees_example.sh:
     PFB_EXAMPLE_PHASE=prepare|middle|check PFB_EXAMPLE_DIR=<scratch folder> [PFB_TEST_PATHS=paths.wl] bin/ws tests/degrees_example.wls
   prepare writes the run and the local slice job (command in cmd1.sh), middle collects the slice and its degrees and
   writes the sector's degree job and the line job (cmd2.sh), check runs the tests (exit code 0 when they pass). *)
Get[FileNameJoin[{ParentDirectory[DirectoryName[$InputFileName]], "lib", "PoleFreeBasis.wl"}]];
$PFBVerbose = False;
phase = Environment["PFB_EXAMPLE_PHASE"]; dir = Environment["PFB_EXAMPLE_DIR"];
If[! StringQ[phase] || ! StringQ[dir] || ! DirectoryQ[dir], Print["set PFB_EXAMPLE_PHASE (prepare, middle, check) and PFB_EXAMPLE_DIR (an existing folder)"]; Exit[2]];
paths = Environment["PFB_TEST_PATHS"];
runFile = FileNameJoin[{dir, "run.wl"}];
key = {box, {1, 1, 1, 1}};
(* the DE by hand, and its degrees at s = 1 *)
Ahand = {{0, 0, 0}, {0, -eps/t, 0},
   {-2 (1 - 2 eps)/(s t (s + t)), 2 (1 - 2 eps)/(t^2 (s + t)), -(1/t + eps s/(t (s + t)))}};
termsOf[f_] := Module[{g = Together[f /. s -> 1], rg},
  rg = PFBEpsRange[g];
  If[rg === "zero", {}, Table[With[{c = Together[SeriesCoefficient[g, {eps, 0, p}]]}, If[c === 0, Nothing, {p, Exponent[Numerator[c], t], Exponent[Denominator[c], t]}]],
    {p, rg[[1]], rg[[2]]}]]];
masters = {j[box, 1, 0, 1, 0], j[box, 0, 1, 0, 1], j[box, 1, 1, 1, 1]};

Switch[phase,
"prepare", Module[{ctx, st, job, spec},
  Put[masters, FileNameJoin[{dir, "masters.m"}]];
  Put[<|"Name" -> "box example", "Families" -> {<|"Name" -> "box", "Family" -> FileNameJoin[{ParentDirectory[$PFBRoot], "maximal-cut-basis", "examples", "box-one-loop", "family.wl"}],
      "Masters" -> "masters.m"|>}, "Letters" -> {s, t, s + t}|>, FileNameJoin[{dir, "system.wl"}]];
  Put[Join[<|"System" -> "system.wl", "OutputDir" -> FileNameJoin[{dir, "run"}], "AllowTmp" -> True, "Seeds" -> <|"Rank" -> 2, "Dots" -> 1|>, "Threads" -> 2, "TimeLimit" -> 900|>,
     If[StringQ[paths] && FileExistsQ[paths], <|"Paths" -> paths|>, <||>]], runFile];
  ctx = PFBStartRun[runFile];
  (* a planted change of the box, rejected: det T = s + 2 t, no letter *)
  st = ctx["State"];
  st["Rejected"] = {<|"Id" -> 1, "Key" -> key, "Name" -> "planted", "Kind" -> "change", "Replace" -> {3}, "NewDefs" -> <|3 -> (s + 2 t) j[box, 1, 1, 1, 1]|>,
     "OldDefs" -> <|3 -> j[box, 1, 1, 1, 1]|>, "Date" -> PFBTimeStamp[]|>};
  PFBSaveState[ctx["Dir"], st];
  (* the local slice with its starting degrees, as bin/local_slice.wls writes it *)
  spec = PFBDegreeSpec[ctx, PFBSectorKeys[ctx["System"]], Automatic, ctx["System"]["Order"], <||>];
  job = PFBLocalSliceJob[ctx["System"], ctx["Dir"], {s -> 1, t -> 3/7}, {t}, <|"Seeds" -> ctx["Run"]["Seeds"], "TimeLimit" -> 900, "Threads" -> 2, "Degrees" -> spec|>];
  If[job === $Failed, Exit[1]];
  Export[FileNameJoin[{dir, "cmd1.sh"}], PFBSubtreeCommand[job] <> "\n", "Text"];
  Print["prepared: ", job];
  Exit[0]],

"middle", Module[{ctx = PFBStartRun[runFile], sys, job, red, sl, s2, dg, dj, lj},
  sys = ctx["System"];
  job = FileNameJoin[{ctx["Dir"], "jobs", "local_slice"}];
  red = PFBReadRed[job, 1];
  If[! AssociationQ[red], Print["no local slice: ", PFBSubtreeStatus[job]]; Exit[1]];
  sl = PFBSliceFromRed[sys, red];
  s2 = PFBStoreSlice[ctx["Dir"], ctx["State"], sl, PFBCensus[sys, sl], "local slice"];
  ctx = Join[ctx, <|"State" -> s2|>];
  dg = PFBCollectDegrees[ctx, {job}];
  ctx = Join[ctx, <|"State" -> dg["State"]|>];
  Print["starting degrees: ", PFBDegreeText[dg["Table"]]];
  (* the box sector's degree job, with a variant (the box rescaled by t) and one sample point *)
  (* and the same in integrals (T^-1 inside the job's graph), a shift by the t-bubble in integrals, and a dotted box (its
     integrals seeded by the job) *)
  dj = PFBDegreesJob[ctx, key, <|"ReuseIds" -> FileNameJoin[{job, "ibps"}], "Variants" -> {PFBDegreeVariant["box times t", <|3 -> t ut[3]|>],
       PFBDegreeVariant["box times t, in integrals", <|3 -> t j[box, 1, 1, 1, 1]|>], PFBDegreeVariant["box shifted, in integrals", <|3 -> t j[box, 1, 1, 1, 1] + j[box, 0, 1, 0, 1]|>],
       PFBDegreeVariant["dotted box", <|3 -> j[box, 1, 1, 1, 2]|>]},
     (* two expressions sampled with their derivatives, as a fit of move (iv) needs them: one by hand, a dotted bubble *)
     "SampleExprs" -> {t j[box, 0, 1, 0, 1] + 2 j[box, 1, 0, 1, 0], j[box, 0, 2, 0, 1]},
     "Samples" -> {{eps -> 3/7, s -> 1, t -> 5/11}}|>];
  lj = PFBDetLineJob[ctx, 1, <|"ReuseIds" -> FileNameJoin[{job, "ibps"}]|>];
  If[dj === $Failed || lj === $Failed, Exit[1]];
  Export[FileNameJoin[{dir, "cmd2.sh"}], PFBDegreesCommand[{dj, lj}] <> "\n", "Text"];
  Exit[0]],

"check", Module[{ctx = PFBStartRun[runFile], sys, sl, t1, tab, col, sec, dj, deg, var, smp, rep, measured, expected, entryTerms, jobT},
  sys = ctx["System"];
  sl = PFBCurrentSlice[ctx["Dir"], ctx["State"]];
  t1 = PFBReadDegrees[ctx["Dir"], ctx["State"]];
  dj = FileNameJoin[{ctx["Dir"], "jobs", "deg_box_j1111"}];
  col = PFBCollectDegrees[ctx, {dj}];
  tab = col["Table"];
  deg = PFBReadDegreeJob[dj];
  var = If[AssociationQ[deg], deg["Variants"]["box times t"], <||>];
  smp = If[AssociationQ[deg], deg["Samples"], {}];
  rep = PFBDetLineReport[ctx, 1];
  (* {row, column} -> {{power, num, den}, ...} *)
  entryTerms[ents_] := Association[Table[{e["Row"], e["Column"]} -> ({#["Power"], #["Num"], #["Den"]} & /@ e["Terms"]), {e, ents}]];
  measured[tb_, k_] := entryTerms[Lookup[tb["Sectors"][k], "Entries", {}]];
  expected[rows_, A_] := Association[Flatten[Table[If[termsOf[A[[r, c]]] === {}, Nothing, {r, c} -> termsOf[A[[r, c]]]], {r, rows}, {c, 3}], 1]];
  jobT = Lookup[Replace[Quiet@Get[FileNameJoin[{dj, "times.m"}]], Except[_List] -> {}], "WallSeconds", {}];
  tests = {
    VerificationTest[Together[sl["R"][[1]] - (Ahand /. sl["Point"])], ConstantArray[0, {3, 3}], TestID -> "the DE by hand agrees with the local slice, exactly in eps"],
    VerificationTest[{AssociationQ[t1], If[AssociationQ[t1], t1["Summary"]["Complete"], None]}, {True, True}, TestID -> "local slice: starting degrees of every sector"],
    VerificationTest[Join[measured[t1, {box, {0, 1, 0, 1}}], measured[t1, key]], expected[{2, 3}, Ahand], TestID -> "local slice: degrees per power of eps match the DE by hand"],
    VerificationTest[{t1["Sectors"][{box, {1, 0, 1, 0}}]["Summary"]["Highest"], KeyTake[t1["Summary"], {"Highest", "Count", "Sum", "Terms"}]},
      {None, <|"Highest" -> 3, "Count" -> 2, "Sum" -> 14, "Terms" -> 7|>}, TestID -> "local slice: the summary (a row of zeros, highest 3 twice, sum 14)"],
    VerificationTest[Sort[Normal[#]] & /@ Lookup[SelectFirst[t1["Sectors"][key]["Entries"], #["Column"] == 2 &]["Terms"], "DenLetters"], {{t -> 2, 1 + t -> 1}, {t -> 2, 1 + t -> 1}},
      TestID -> "letter content: t^2 (1 + t) below the box's bubble column"],
    VerificationTest[Union[Lookup[Flatten[Lookup[t1["Sectors"][key]["Entries"], "Terms"]], "DenUnexplained"]], {0}, TestID -> "letter content: the letters explain every denominator"],
    VerificationTest[{tab["Sectors"][key]["Status"], tab["Sectors"][key]["Job"], measured[tab, key]}, {"measured", "deg_box_j1111", expected[{3}, Ahand]},
      TestID -> "degree job of the box sector: the same degrees"],
    (* the DE after U3' = t U3: T A T^-1 + dT T^-1 *)
    VerificationTest[If[AssociationQ[var] && var["Status"] === "measured", entryTerms[var["Entries"]], var],
      expected[{3}, Together[DiagonalMatrix[{1, 1, t}] . Ahand . DiagonalMatrix[{1, 1, 1/t}] + DiagonalMatrix[{0, 0, 1/t}]]],
      TestID -> "variant: the box rescaled by t, on the same learned system"],
    VerificationTest[With[{v = Lookup[Lookup[deg, "Variants", <||>], "box times t, in integrals", <||>]}, If[Lookup[v, "Status", None] === "measured", entryTerms[v["Entries"]], v]],
      expected[{3}, Together[DiagonalMatrix[{1, 1, t}] . Ahand . DiagonalMatrix[{1, 1, 1/t}] + DiagonalMatrix[{0, 0, 1/t}]]],
      TestID -> "variant in integrals: the same, T^-1 inside the job's graph"],
    VerificationTest[With[{v = Lookup[Lookup[deg, "Variants", <||>], "box shifted, in integrals", <||>]},
        {If[Lookup[v, "Status", None] === "measured", entryTerms[v["Entries"]], v], v["TInverse"]}],
      {expected[{3}, Together[{{1, 0, 0}, {0, 1, 0}, {0, 1, t}} . Ahand . Inverse[{{1, 0, 0}, {0, 1, 0}, {0, 1, t}}] + D[{{1, 0, 0}, {0, 1, 0}, {0, 1, t}}, t] . Inverse[{{1, 0, 0}, {0, 1, 0}, {0, 1, t}}]]],
        Automatic}, TestID -> "variant in integrals: a shift by the t-bubble"],
    VerificationTest[Lookup[Lookup[Lookup[deg, "Variants", <||>], "dotted box", <||>], "Status", None], "measured", TestID -> "variant in integrals: a dotted box, seeded by the job"],
    VerificationTest[With[{v = If[smp =!= {} && KeyExistsQ[smp[[1]], "Values"], smp[[1]]["Values"], <||>], cols = Lookup[deg, "Columns", {}], pt = {eps -> 3/7, s -> 1, t -> 5/11}},
        {Lookup[v, "Exprs", None][[1]], Lookup[v, "DExprs", None][[1, 1]], Unitize[Lookup[v, "Exprs", None][[2]]], Unitize[Lookup[v, "DExprs", None][[1, 2]]]}],
      With[{cols = Lookup[deg, "Columns", {}], pt = {eps -> 3/7, s -> 1, t -> 5/11}}, {({2, t, 0}[[cols]]) /. pt, ({0, 1 - eps, 0}[[cols]]) /. pt, {0, 1, 0}[[cols]], {0, 1, 0}[[cols]]}],
      TestID -> "sampled expressions: their vectors and those of their derivatives on the masters"],
    VerificationTest[If[smp =!= {} && KeyExistsQ[smp[[1]], "Values"], smp[[1]]["Values"]["Base"], smp],
      {{Ahand[[3, deg["Columns"] /. ut[k_] :> k]] /. {eps -> 3/7, s -> 1, t -> 5/11}}}, TestID -> "samples: the exact rows at a rational point"],
    VerificationTest[If[AssociationQ[rep], With[{f = Expand[(1 + 2 t) /. rep["Line"]], v = rep["Variable"]},
        {Length[rep["Spurious"]], Expand[rep["Spurious"][[1]]["Factor"] - f/Coefficient[f, v, 1]], rep["Factors"] === rep["Spurious"], rep["Check"]}], rep],
      {1, 0, True, "agrees with the reduction at the base point"}, TestID -> "det T along a line: 1 + 2 t named spurious"]
  };
  report = TestReport[tests];
  Do[With[{r = report["TestResults"][id]},
      Print[If[r["Outcome"] === "Success", "PASS ", "FAIL "], r["TestID"], If[r["Outcome"] === "Success", "",
        "\n     got " <> ToString[Short[r["ActualOutput"], 6], InputForm] <> "\n     expected " <> ToString[Short[r["ExpectedOutput"], 6], InputForm]]]],
    {id, Keys[report["TestResults"]]}];
  Print["degree job of the box sector: degrees in ", Lookup[deg, "Seconds", "?"], " s (", Lookup[deg, "CPUSeconds", "?"], " s CPU), points ", jobT, " s wall-clock"];
  Print[report["TestsSucceededCount"], " passed, ", report["TestsFailedCount"], " failed"];
  Exit[If[report["AllTestsSucceeded"], 0, 1]]],

_, Print["unknown phase ", phase]; Exit[2]];
