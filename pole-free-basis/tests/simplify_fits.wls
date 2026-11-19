#!/usr/bin/env wolframscript
(* The fits of moves (iii) and (iv) without FiniteFlow or IBP: a denominator factor no known singularity explains, samples
   at singular points, and the lines of a fit. Planted data as in tests/simplify.wls (section G): four masters of the
   one-loop massless box of the maximal-cut-basis examples (the two bubbles, a triangle over the s-bubble and the box;
   unit scale s, letters s, t, s + t, derivative d/dt), a planted low-degree DE whose triangle row has a spurious factor
   3 s + 2 t (no letter) in its column of the s-bubble, and the DE after the triangle is shifted by the s-bubble with
   c = 3/s. The fit must undo the shift with the spurious factor kept in the term's denominator.
   Checked: the spurious degree of the old term in the problem, the fit with it (it found no denominator before), a
   sample without exact values (refused with the reason), the samples a completion needs, and the lines: no point on a
   zero of the polynomials to avoid, every one of them keeping its degree along each direction, directions beyond 3.
   usage: bin/ws tests/simplify_fits.wls        exit code 0 when every test passes *)
Get[FileNameJoin[{ParentDirectory[DirectoryName[$InputFileName]], "lib", "PoleFreeBasis.wl"}]];
$PFBVerbose = False;
boxFile = FileNameJoin[{ParentDirectory[$PFBRoot], "maximal-cut-basis", "examples", "box-one-loop", "family.wl"}];
key3 = {box, {1, 1, 1, 1}}; key2 = {box, {0, 1, 0, 1}}; key1 = {box, {1, 0, 1, 0}}; key4 = {box, {1, 1, 1, 0}};
P = {s -> 1, t -> 3/7};
probes = {t, 1 + t};
mult[p_, q_] := Module[{m = 0}, While[PolynomialRemainder[p, q^(m + 1), t] === 0, m++]; m];
letterContent[p_] := Association[Select[Table[q -> mult[p, q], {q, probes}], #[[2]] > 0 &]];
termOf[c_, pw_] := Module[{gg = Together[c], n, d, nl, dl},
  n = Numerator[gg]; d = Denominator[gg]; nl = letterContent[n]; dl = letterContent[d];
  <|"Power" -> pw, "Num" -> Exponent[n, t], "Den" -> Exponent[d, t], "VarDegrees" -> {{Exponent[n, t], 0, Exponent[d, t], 0}}, "NumLetters" -> nl, "DenLetters" -> dl,
    "NumUnexplained" -> Exponent[n, t] - Total[KeyValueMap[#2 Exponent[#1, t] &, nl]], "DenUnexplained" -> Exponent[d, t] - Total[KeyValueMap[#2 Exponent[#1, t] &, dl]]|>];
entriesOfN[A_, rows_] := Flatten[Table[With[{f = Together[A[[r, c]] /. s -> 1]}, If[f === 0, {},
     With[{rg = PFBEpsRange[f]}, {<|"Matrix" -> 1, "Derivative" -> t, "Row" -> r, "Column" -> c, "Eps" -> {"Laurent", rg[[1]], rg[[2]]},
       "Terms" -> Table[With[{cf = Together[SeriesCoefficient[f, {eps, 0, pw}]]}, If[cf === 0, Nothing, termOf[cf, pw]]], {pw, rg[[1]], rg[[2]]}]|>}]]], {r, rows}, {c, Length[A]}], 2];
tableOf4[A_] := Module[{rec, tb}, rec[rows_] := With[{ents = entriesOfN[A, rows]}, <|"Status" -> "measured", "Source" -> "measured", "Job" -> "planted", "Rows" -> rows,
      "Entries" -> ents, "Summary" -> PFBDegreeSummary[ents], "Probes" -> probes, "JobSectors" -> 1, "JobWallSeconds" -> 10, "JobSeconds" -> 1|>];
  tb = <|"Keys" -> {key1, key2, key4, key3}, "UnitScale" -> s, "Vars" -> {t}, "Provenance" -> <|"Source" -> "measured"|>,
    "Sectors" -> <|key1 -> rec[{1}], key2 -> rec[{2}], key4 -> rec[{3}], key3 -> rec[{4}]|>|>;
  Join[tb, <|"Summary" -> PFBDegreeSummary[tb]|>]];
newRunN[dir_, A_, masters_] := Module[{ctx, sl, st, n = Length[masters]},
  CreateDirectory[dir, CreateIntermediateDirectories -> True];
  Put[masters, FileNameJoin[{dir, "masters.m"}]];
  Put[<|"Name" -> "planted", "Families" -> {<|"Name" -> "box", "Family" -> boxFile, "Masters" -> "masters.m"|>}, "Letters" -> {s, t, s + t}|>, FileNameJoin[{dir, "system.wl"}]];
  Put[<|"System" -> "system.wl", "OutputDir" -> FileNameJoin[{dir, "run"}], "AllowTmp" -> True, "Paths" -> Automatic|>, FileNameJoin[{dir, "run.wl"}]];
  ctx = PFBStartRun[FileNameJoin[{dir, "run.wl"}]];
  sl = <|"R" -> {Together[A /. P]}, "Derivatives" -> {t}, "Point" -> P, "Labels" -> Range[n], "Index" -> AssociationThread[Range[n] -> Range[n]], "Frame" -> "RootFree", "History" -> {}|>;
  st = PFBStoreSlice[ctx["Dir"], ctx["State"], sl, PFBCensus[ctx["System"], sl], "planted"];
  Join[ctx, <|"State" -> st|>]];
samplesOf[A_, pr_] := <|"Status" -> "sampled", "Rows" -> pr["JobRows"], "Columns" -> Range[Length[A]],
   "Samples" -> Table[<|"Point" -> pt, "Values" -> <|"Base" -> {Table[A[[r, c]] /. s -> 1 /. pt, {r, pr["JobRows"]}, {c, Length[A]}]}|>|>, {pt, pr["Points"]}]|>;
shifted[B_, c_, i_, k_] := With[{T = ReplacePart[IdentityMatrix[Length[B]], {i, k} -> c]}, Together[T . B . Inverse[T] + D[T, t] . Inverse[T]]];
tmp = CreateDirectory[];

(* ---- a spurious factor in the term the shift lowers ---- *)
Bsp = {{0, 0, 0, 0}, {0, -eps/t, 0, 0}, {2/(3 s + 2 t), 0, -eps/(s + t) - 1/t, 0}, {1/(s t), eps/t, eps/t, -eps/(s + t)}};
Asp = shifted[Bsp, 3/s, 3, 1];
masters4 = {j[box, 1, 0, 1, 0], j[box, 0, 1, 0, 1], j[box, 1, 1, 1, 0] + 3/s j[box, 1, 0, 1, 0], j[box, 1, 1, 1, 1]};
ctxSp = newRunN[FileNameJoin[{tmp, "spurious"}], Asp, masters4];
tabSp = tableOf4[Asp];
term31 = SelectFirst[SelectFirst[tabSp["Sectors"][key4]["Entries"], #["Row"] == 3 && #["Column"] == 1 &]["Terms"], #["Power"] === 0 &];
probSp = PFBShiftProblem[ctxSp, tabSp, 3];
spurTerm = If[AssociationQ[probSp], SelectFirst[probSp["Terms"], #["Key"] === {1, 1} && #["Power"] === 0 &, <||>], <||>];
fitSp = If[AssociationQ[probSp], PFBShiftFit[probSp, samplesOf[Asp, probSp]], <||>];

(* ---- samples without exact values ---- *)
A1 = shifted[ReplacePart[Bsp, {3, 1} -> 2/(s + t)], 3/s, 3, 1];
ctxA1 = newRunN[FileNameJoin[{tmp, "singular"}], A1, masters4];
probA1 = PFBShiftProblem[ctxA1, tableOf4[A1], 3];
smpA1 = samplesOf[A1, probA1];
smpBad = ReplacePart[smpA1, {"Samples", 7, "Values", "Base"} -> $Failed];
fitGood = PFBShiftFit[probA1, smpA1];
fitBad = PFBShiftFit[probA1, smpBad];
samplesIssue = PoleFreeBasis`Simplify`Private`samplesIssue;
compSmp = <|"Samples" -> {<|"Point" -> {t -> 1}, "Values" -> <|"Base" -> {{{1, 2}}}, "Exprs" -> {{0, 1}}, "DExprs" -> {{{0, 1/3}}}|>|>,
    <|"Point" -> {t -> 2}, "Values" -> <|"Base" -> {{{1, 2}}}|>|>}|>;

(* ---- the lines of a fit ---- *)
fitLines = PoleFreeBasis`Simplify`Private`fitLines;
avoid = {x - y, x + y - 200, 3 x - 2 y, x^2 - 7 y};
lines = fitLines[{x, y}, 40, 15, 7, avoid];
dirsOf[ls_] := Table[(({x, y} /. l[[2]]) - ({x, y} /. l[[1]])), {l, ls}];
onZero = If[ListQ[lines], Select[Flatten[lines, 1], Function[pt, AnyTrue[avoid, (# /. pt) == 0 &]]], {"no lines"}];
topLost = If[ListQ[lines], Select[dirsOf[lines], Function[v, v[[1]] == v[[2]] || 3 v[[1]] == 2 v[[2]] || v[[1]] == 0]], {"no lines"}];
avoidBox = PoleFreeBasis`Simplify`Private`fitAvoid[ctxA1["System"], ctxA1["Dir"], box, {t}, {3, 1}];

tests = {
  VerificationTest[{term31["Den"], term31["DenUnexplained"], spurTerm["Spurious"]["Degree"], probSp["Start"], probSp["Lower"]}, {2, 1, 1, 1, {1}},
    TestID -> "spurious factor: the old term's unexplained denominator degree goes into the problem"],
  VerificationTest[{fitSp["Status"], Lookup[fitSp["Solutions"], "Target"], Together[fitSp["Best"]["Coefficients"][1] + 3/s]}, {"solved", {1}, 0},
    TestID -> "spurious factor: the fit keeps the term's own factor along each line and undoes the shift"],
  (* samples at singular points *)
  VerificationTest[{fitGood["Status"], fitBad["Status"], StringContainsQ[fitBad["Message"], "no exact values"]}, {"solved", "failed", True},
    TestID -> "samples: a sample without exact values stops the fit with the reason"],
  VerificationTest[{samplesIssue[<|"Points" -> {1, 2}|>, compSmp, {"Base"}], StringQ[samplesIssue[<|"Points" -> {1, 2}|>, compSmp, {"Base", "Exprs", "DExprs"}]],
      StringQ[samplesIssue[<|"Points" -> {1}|>, compSmp]]}, {None, True, True}, TestID -> "samples: a completion's fit needs exact rows, expressions and derivatives"],
  (* lines *)
  VerificationTest[{ListQ[lines], Length[lines], Length[First[lines]], onZero, topLost, Max[dirsOf[lines]] > 3}, {True, 40, 15, {}, {}, True},
    TestID -> "lines: no point on a zero of a polynomial to avoid, each keeps its degree along every direction"],
  VerificationTest[{Sort[avoidBox], ListQ[probA1["Line"]], AllTrue[Flatten[(t /. #) & /@ Flatten[probA1["Line"], 1]], # > 1 &]}, {Sort[{t, 1 + t, t - 1}], True, True},
    TestID -> "lines: a fit avoids the known singularities, the invariants and their differences with the unit scale"]
};

report = TestReport[tests];
Do[With[{r = report["TestResults"][id]},
    Print[If[r["Outcome"] === "Success", "PASS ", "FAIL "], r["TestID"], If[r["Outcome"] === "Success", "",
      "\n     got " <> ToString[Short[r["ActualOutput"], 3], InputForm] <> "\n     expected " <> ToString[Short[r["ExpectedOutput"], 3], InputForm]]]],
  {id, Keys[report["TestResults"]]}];
Print[report["TestsSucceededCount"], " passed, ", report["TestsFailedCount"], " failed, ", Round[report["TimeElapsed"], 0.1]];
DeleteDirectory[tmp, DeleteContents -> True];
Exit[If[report["AllTestsSucceeded"], 0, 1]];
