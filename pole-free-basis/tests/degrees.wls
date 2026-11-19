#!/usr/bin/env wolframscript
(* The degree census without IBP: FiniteFlow graphs built from planted rational functions (FFAlgRatFunEval), whose
   degrees, powers of eps and letter content are known by hand. Checked: FFAllDegrees and its per-variable degrees
   (PFBFFDegrees), the split per power of eps, the whole entries (finite poles, above the cap), letter probing with
   multiplicities, the unexplained degree, the summary and its objective; the graph of expressions on a planted
   reduction, a variant measured on the same graph, exact samples, a line (PFBFFLine) and det T along it
   (PFBDetLineAnalysis, PFBDetLineReport on a planted line job); PFBDegreeProbes, PFBDegreeVariant, the collection of a
   planted degree job into the run's table (PFBCollectDegrees, state.m, census text, summary page), and the validation
   of a user's "Degrees" file (PFBImportDegrees). Needs FiniteFlow (no LiteRed, no LiteIBP).
   usage: bin/ws tests/degrees.wls        exit code 0 when every test passes; the tools from $PFB_TEST_PATHS (a
          paths.wl) when it is set, else the usual detection *)
Get[FileNameJoin[{ParentDirectory[DirectoryName[$InputFileName]], "lib", "PoleFreeBasis.wl"}]];
$PFBVerbose = False;
With[{p = Environment["PFB_TEST_PATHS"]}, MCBLoadPaths[If[StringQ[p] && FileExistsQ[p], p, Automatic]]];
If[StringQ[MCBPath["FiniteFlowLibrary"]], PrependTo[$LibraryPath, MCBPath["FiniteFlowLibrary"]]];
If[StringQ[MCBPath["FiniteFlow"]], $Path = DeleteDuplicates[Append[$Path, DirectoryName[MCBPath["FiniteFlow"]]]]];
Needs["FiniteFlow`"];
Get[FileNameJoin[{$PFBRoot, "lib", "PFB", "DegreeGraph.wl"}]];
(* an older library than FiniteFlow.m would hang the tests below: stop with the reason *)
With[{pb = PFBFFLibraryProblem[]}, If[StringQ[pb], Print["degrees.wls: ", pb, " (give the tool paths in PFB_TEST_PATHS)"]; Exit[1]]];

(* ---- planted entries in {eps, x, y}, cap eps^2 ---- *)
fs = {
  (1 + 2 eps) x/(y (x + y)),                                  (* 1: eps^0, eps^1: degrees {1, 2}; y and x + y below, x above *)
  eps^2 (x^2 + 3 y^3)/((x - y)^2 (x + y)),                     (* 2: eps^2: {3, 3}; (x - y)^2 (x + y) below, nothing known above *)
  (x + 1)/(eps x y^2) + eps (y - 2),                           (* 3: eps^-1 {1, 3}, eps^0 absent, eps^1 {1, 0} *)
  (x + y)/(1 - 2 eps),                                         (* 4: a finite pole: whole, {1, 0} *)
  eps^3 x,                                                     (* 5: above the cap: whole, {1, 0} *)
  0,                                                           (* 6: zero *)
  (x^2 + y^2 + 1)/((x^2 + y^2 + 7) (x + 2 y + 5)),             (* 7: eps^0 {2, 3}: a spurious factor of degree 2 *)
  1/(x + eps y),                                               (* 8: eps mixed with x and y: whole, {0, 1}, unexplained 1 *)
  eps (x + y)^3/y^2};                                          (* 9: eps^1 {3, 2}: (x + y)^3 above, y^2 below *)
probes = {x, y, x + y, x - y, x + 2 y + 5, x^2 + y + 3};
FFNewGraph[gp, inp, {eps, x, y}];
FFAlgRatFunEval[gp, fp, {inp}, {eps, x, y}, Together /@ fs];
FFGraphOutput[gp, fp];
m = PFBFFMeasure[gp, {eps, x, y}, <|"Cap" -> 2, "Probes" -> probes, "Eps" -> 1009/2027|>];
ent[i_] := SelectFirst[m["Entries"], #["Index"] == i &, None];
termAt[i_, p_] := SelectFirst[Lookup[Replace[ent[i], None -> <||>], "Terms", {}], #["Power"] === p &, None];
pick[t_, ks_] := If[AssociationQ[t], Lookup[t, ks], None];
(* associations compared as sets of rules: the order of the letters found does not matter *)
sameA[a_, b_] := (a /. as_Association :> Sort[Normal[as]]) === (b /. as_Association :> Sort[Normal[as]]);

(* ---- the graph of expressions on a planted reduction: two dependent integrals on two masters, in {eps, s, t}, with the
   unit scale s set to 1 ---- *)
Rpl = {{(1 + t)/(t (1 - 2 eps)), eps/t}, {t + eps, 1/(1 + t)}};          (* jj[1], jj[2] on ut[1], ut[2] *)
FFNewGraph[gR, inR, {eps, s, t}];
FFAlgRatFunEval[gR, fR, {inR}, {eps, s, t}, Together /@ Flatten[Rpl]];
FFGraphOutput[gR, fR];
exprs = {(2 + eps)/t jj[1] + t^2 jj[2], (1 + t) jj[2] + eps ut[2], s t ut[1]};
expected = Together[{(2 + eps)/t Rpl[[1]] + t^2 Rpl[[2]], (1 + t) Rpl[[2]] + eps {0, 1}, s t {1, 0}} /. s -> 1];
gE = PFBFFExprGraph[gExpr, gR, <|"DepVars" -> {jj[1], jj[2]}, "IndepVars" -> {ut[1], ut[2]}|>, {eps, s, t}, {eps, t}, {s -> 1}, exprs, {ut[1], ut[2]}];
pt = {7/11, 13/5};
smp = If[gE === gExpr, PFBFFSamples[gE, {pt}], $Failed];
(* a variant on the same planted reduction: U2' = (1 + t) U2, so the columns of ut[2] are divided by 1 + t *)
gV = PFBFFTransformGraph[gVar, gE, {eps, t}, 3, 2, {{1, 0}, {0, 1/(1 + t)}}];
mE = PFBFFMeasure[gE, {eps, t}, <|"Probes" -> {t, 1 + t}|>];
mV = PFBFFMeasure[gV, {eps, t}, <|"Probes" -> {t, 1 + t}|>];
degOf[mm_, i_, p_] := Lookup[SelectFirst[Lookup[SelectFirst[mm["Entries"], #["Index"] == i &, <||>], "Terms", {}], #["Power"] === p &, <||>], {"Num", "Den", "DenLetters"}, None];
(* a swap on the same planted reduction: ut[2] replaced by H = h1 ut[1] + h2 ut[2] given by a graph of its own, T^-1
   evaluated inside the graph *)
hRep = {t/(1 + t), (2 + eps)/t};
FFNewGraph[gH, inH, {eps, t}];
FFAlgRatFunEval[gH, fH, {inH}, {eps, t}, hRep];
FFGraphOutput[gH, fH];
gRep = If[gE === gExpr, PFBFFReplaceGraph[gRepl, gE, gH, {eps, t}, 3, 2, {2}], $Failed];
smpRep = If[gRep === gRepl, PFBFFSamples[gRep, {pt}], $Failed];
expRep = Flatten[(ArrayReshape[expected, {3, 2}] . Inverse[{{1, 0}, hRep}]) /. {eps -> pt[[1]], t -> pt[[2]]}];
(* a line through the planted graph *)
lineF = PFBFFLine[gp, {eps, x, y}, {3, 5}, {1, -2}, 1009/2027, tau];
lineX = Together[fs /. {eps -> 1009/2027, x -> 3 + tau, y -> 5 - 2 tau}];

(* ---- det T along a line ---- *)
detP = 7/3 (3 + tau)^2 (5 tau^2 - 14 tau + 41) (tau^2 + tau + 1)/(8 - tau);
an = PFBDetLineAnalysis[detP, {x, y, x + y, x^2 + y^2 + 7}, {x -> 3, y -> 5}, {x -> 1, y -> -2}, tau];
facOf[f_] := SelectFirst[an["Factors"], Expand[#["Factor"] - f] === 0 &, None];

(* ---- the toolkit side: a planted run on the one-loop box of the maximal-cut-basis examples (unit scale s) ---- *)
boxFile = FileNameJoin[{ParentDirectory[$PFBRoot], "maximal-cut-basis", "examples", "box-one-loop", "family.wl"}];
tmp = CreateDirectory[];
Put[{j[box, 1, 0, 1, 0], j[box, 0, 1, 0, 1], s t j[box, 1, 1, 1, 1]}, FileNameJoin[{tmp, "masters.m"}]];
Put[<|"Name" -> "planted", "Families" -> {<|"Name" -> "box", "Family" -> boxFile, "Masters" -> "masters.m"|>}, "Letters" -> {s, t, s + t}|>, FileNameJoin[{tmp, "system.wl"}]];
Put[<|"System" -> "system.wl", "OutputDir" -> FileNameJoin[{tmp, "run"}], "AllowTmp" -> True, "Paths" -> Automatic|>, FileNameJoin[{tmp, "run.wl"}]];
ctx = PFBStartRun[FileNameJoin[{tmp, "run.wl"}]];
sys = ctx["System"];
key = {box, {1, 1, 1, 1}};
P = {s -> 1, t -> 3/7};
Rsl = {{0, 0, 0}, {0, -eps/t, 0}, {(1 - 2 eps)/(eps t (1 + t)), -(1 - 2 eps)/(eps t (1 + t)), -1/t - eps/(1 + t)}} /. P;
sl = <|"R" -> {Rsl}, "Derivatives" -> {t}, "Point" -> P, "Labels" -> {1, 2, 3}, "Index" -> <|1 -> 1, 2 -> 2, 3 -> 3|>, "Frame" -> "RootFree", "History" -> {}|>;
st1 = PFBStoreSlice[ctx["Dir"], ctx["State"], sl, PFBCensus[sys, sl], "planted"];
ctx = Join[ctx, <|"State" -> st1|>];
pr = PFBDegreeProbes[sys, ctx["Dir"], {box}];
(* a planted degree job of the box sector, as the runner leaves it *)
jd = FileNameJoin[{ctx["Dir"], "jobs", "deg_box_j1111"}];
CreateDirectory[jd, CreateIntermediateDirectories -> True];
spec = PFBDegreeSpec[ctx, {key}, {3}, {box}];
Put[<|"Name" -> "deg_box_j1111", "Degrees" -> spec|>, FileNameJoin[{jd, "job.m"}]];
Put[<|"Status" -> "done", "Date" -> DateString[]|>, FileNameJoin[{jd, "status.m"}]];
Put[<|"Masters" -> {ut[1], ut[2], ut[3]}, "Labels" -> {1, 2, 3}, "Point" -> P, "Focus" -> {3}, "Dm" -> {{Rsl[[3]]}}, "Pool" -> {}, "Rp" -> {}, "dRp" -> {},
   "Invariants" -> {t}, "Roots" -> {key}|>, FileNameJoin[{jd, "red_1.m"}]];
plantTerm[p_, n_, d_, dl_, un_] := <|"Power" -> p, "Num" -> n, "Den" -> d, "VarDegrees" -> {{n, 0, d, 0}}, "NumLetters" -> <||>, "DenLetters" -> dl, "NumUnexplained" -> n, "DenUnexplained" -> un|>;
Put[<|"Status" -> "measured", "Rows" -> {3}, "Columns" -> {ut[1], ut[2], ut[3]}, "Derivatives" -> {t}, "Vars" -> {t}, "Fix" -> {s -> 1}, "Cap" -> 2, "Eps" -> 1/3, "Point" -> {t -> 101},
   "Probes" -> pr["Probes"], "Entries" -> {
     <|"Matrix" -> 1, "Derivative" -> t, "Row" -> 3, "Column" -> ut[1], "Eps" -> {"Laurent", -1, 0}, "Terms" -> {plantTerm[-1, 0, 2, <|t -> 1, 1 + t -> 1|>, 0], plantTerm[0, 0, 2, <|t -> 1, 1 + t -> 1|>, 0]}|>,
     <|"Matrix" -> 1, "Derivative" -> t, "Row" -> 3, "Column" -> ut[2], "Eps" -> {"Laurent", -1, 0}, "Terms" -> {plantTerm[-1, 0, 2, <|t -> 1, 1 + t -> 1|>, 0], plantTerm[0, 0, 2, <|t -> 1, 1 + t -> 1|>, 0]}|>,
     <|"Matrix" -> 1, "Derivative" -> t, "Row" -> 3, "Column" -> ut[3], "Eps" -> {"Laurent", 0, 1}, "Terms" -> {plantTerm[0, 0, 1, <|t -> 1|>, 0], plantTerm[1, 0, 1, <|1 + t -> 1|>, 0]}|>},
   "Variants" -> <||>, "Samples" -> {}, "Seconds" -> 12, "CPUSeconds" -> 20, "Threads" -> 1, "Steps" -> {}|>, FileNameJoin[{jd, "degrees.m"}]];
(* and a job that was refused *)
jr = FileNameJoin[{ctx["Dir"], "jobs", "deg_box_j0101"}];
CreateDirectory[jr];
Put[<|"Name" -> "deg_box_j0101", "Degrees" -> PFBDegreeSpec[ctx, {{box, {0, 1, 0, 1}}}, {2}, {box}]|>, FileNameJoin[{jr, "job.m"}]];
Put[<|"Status" -> "refused", "Message" -> "predicted memory above what is free", "Date" -> DateString[]|>, FileNameJoin[{jr, "status.m"}]];
col = PFBCollectDegrees[ctx, {jd, jr}];
st2 = col["State"];
tab = PFBReadDegrees[ctx["Dir"], st2];
summaryPage = Quiet@PFBSummaryHTML[ctx["Dir"], sys, st2];
(* a planted line job of a recorded change of the box sector, along t = 5 + 2 tau: the old box on the current one is 1,
   the new one is (t + 1)(t^2 + 3) times it *)
jl = FileNameJoin[{ctx["Dir"], "jobs", "detline_7"}];
CreateDirectory[jl];
Put[<|"Status" -> "done", "Date" -> DateString[]|>, FileNameJoin[{jl, "status.m"}]];
Put[<|"Status" -> "done", "Change" -> 7, "Key" -> key, "Labels" -> {3}, "Changed" -> {3}, "Masters" -> {ut[3]}, "Variable" -> tau, "Base" -> {t -> 5}, "Direction" -> {t -> 2},
   "Eps" -> 1/3, "Fix" -> {s -> 1}, "Check" -> "agrees with the reduction at the base point",
   "Coefficients" -> {{1}, {Expand[(t + 1) (t^2 + 3) /. t -> 5 + 2 tau]}}|>, FileNameJoin[{jl, "line.m"}]];
rep = PFBDetLineReport[ctx, 7];

(* ---- a user's degrees with an imported slice ---- *)
Rimp = {{-eps/3, eps^3, 0}, {eps/(1 - 2 eps), -2 eps, 0}, {eps + eps^2, 1 + eps, -1 - 2 eps}};
sli = Join[sl, <|"R" -> {Rimp}|>];
good = {{{<|1 -> {0, 0}|>, <|3 -> {1, 2}|>, 0}, {<|"Whole" -> {2, 1}|>, <|1 -> {0, 1}|>, 0}, {<|1 -> {1, 1}, 2 -> {2, 2}|>, <|0 -> {0, 0}, 1 -> {1, 1}|>, <|0 -> {0, 1}, 1 -> {1, 1}|>}}};
writeDeg[d_, name_] := (Put[d, FileNameJoin[{tmp, name}]]; <|"Degrees" -> name, "Dir" -> tmp, "Transpose" -> False, "Frame" -> "RootFree"|>);
imp[d_, extra_ : <||>] := PFBImportDegrees[sys, sli, Join[writeDeg[d, "deg.m"], extra]];
errOf[r_] := StringRiffle[Lookup[r, "Errors", {}], " | "];

(* the library matches FiniteFlow.m; one that lacks a function FiniteFlow.m loads is named (planted: set to $Failed) *)
libOK = PFBFFLibraryProblem[];
libBad = Block[{FiniteFlow`Private`FFVersionImplem = $Failed}, PFBFFLibraryProblem[]];

tests = {
  VerificationTest[{libOK, StringQ[libBad] && StringContainsQ[libBad, "FFVersion"]}, {None, True},
    TestID -> "library: the loaded FiniteFlow library provides every function FiniteFlow.m loads; a missing one is named"],
  VerificationTest[m["Status"], "measured", TestID -> "measure: the planted graph"],
  VerificationTest[{m["Total"], Sort[Lookup[m["Entries"], "Index"]]}, {9, {1, 2, 3, 4, 5, 7, 8, 9}}, TestID -> "measure: the zero output is left out"],
  VerificationTest[Lookup[ent[#], "Eps"] & /@ {1, 2, 3, 4, 5, 7, 8, 9},
    {{"Laurent", 0, 1}, {"Laurent", 2, 2}, {"Laurent", -1, 1}, {"Whole", "finite poles"}, {"Whole", "above the cap"}, {"Laurent", 0, 0}, {"Whole", "finite poles"}, {"Laurent", 1, 1}},
    TestID -> "eps structure: Laurent ranges, finite poles, above the cap, eps mixed with the invariants"],
  VerificationTest[Lookup[Lookup[ent[3], "Terms"], "Power"], {-1, 1}, TestID -> "per power of eps: a vanishing eps^0 coefficient is no term"],
  VerificationTest[{pick[termAt[1, 0], {"Num", "Den"}], pick[termAt[1, 1], {"Num", "Den"}], pick[termAt[2, 2], {"Num", "Den"}], pick[termAt[3, -1], {"Num", "Den"}],
      pick[termAt[3, 1], {"Num", "Den"}], pick[termAt[7, 0], {"Num", "Den"}], pick[termAt[9, 1], {"Num", "Den"}]},
    {{1, 2}, {1, 2}, {3, 3}, {1, 3}, {1, 0}, {2, 3}, {3, 2}}, TestID -> "FFAllDegrees: total degrees per power of eps"],
  VerificationTest[{pick[termAt[4, "whole"], {"Num", "Den"}], pick[termAt[5, "whole"], {"Num", "Den"}], pick[termAt[8, "whole"], {"Num", "Den"}]},
    {{1, 0}, {1, 0}, {0, 1}}, TestID -> "whole entries at a generic eps"],
  VerificationTest[{termAt[1, 0]["VarDegrees"], termAt[2, 2]["VarDegrees"], termAt[3, -1]["VarDegrees"]},
    {{{1, 1, 1, 0}, {0, 0, 2, 1}}, {{2, 0, 3, 0}, {3, 0, 3, 0}}, {{1, 0, 1, 1}, {0, 0, 2, 2}}}, TestID -> "per-variable degrees {numMax, numMin, denMax, denMin}"],
  VerificationTest[{pick[termAt[1, 0], {"DenLetters", "NumLetters", "DenUnexplained", "NumUnexplained"}],
      pick[termAt[2, 2], {"DenLetters", "NumLetters", "DenUnexplained", "NumUnexplained"}],
      pick[termAt[3, -1], {"DenLetters", "DenUnexplained", "NumUnexplained"}]},
    {{<|y -> 1, x + y -> 1|>, <|x -> 1|>, 0, 0}, {<|x - y -> 2, x + y -> 1|>, <||>, 0, 3}, {<|x -> 1, y -> 2|>, 0, 1}},
    TestID -> "letters: multiplicities below and above, one-variable probes from the lowest powers", SameTest -> sameA],
  VerificationTest[{pick[termAt[9, 1], {"NumLetters", "DenLetters"}], pick[termAt[4, "whole"], {"NumLetters", "DenLetters"}]},
    {{<|x + y -> 3|>, <|y -> 2|>}, {<|x + y -> 1|>, <||>}}, TestID -> "letters: a cube in the numerator, a whole entry", SameTest -> sameA],
  VerificationTest[{pick[termAt[7, 0], {"DenLetters", "DenUnexplained", "NumUnexplained"}], pick[termAt[8, "whole"], {"DenLetters", "DenUnexplained"}]},
    {{<|x + 2 y + 5 -> 1|>, 2, 2}, {<||>, 1}}, TestID -> "unexplained degree: a spurious factor of known degree", SameTest -> sameA],
  VerificationTest[Lookup[PFBFFMeasure[gp, {eps, x, y}, <|"Cap" -> Infinity, "Probe" -> False|>]["Entries"][[5]], {"Index", "Eps"}], {5, {"Laurent", 3, 3}},
    TestID -> "no cap: eps^3 is measured per power"],
  VerificationTest[Lookup[PFBFFMeasure[gp, {eps, x, y}, <|"Probe" -> False|>]["Entries"][[1, "Terms", 1]], "DenLetters"], Missing["NotProbed"], TestID -> "\"Probe\" -> False: no letter content"],
  (* summary and objective *)
  VerificationTest[KeyTake[PFBDegreeSummary[m["Entries"]], {"Highest", "Count", "Sum", "Terms", "Entries", "Whole", "Unexplained", "MaxUnexplained"}],
    <|"Highest" -> 3, "Count" -> 4, "Sum" -> 20, "Terms" -> 10, "Entries" -> 8, "Whole" -> 3, "Unexplained" -> 3, "MaxUnexplained" -> 2|>, TestID -> "summary: highest, count at it, sum"],
  VerificationTest[{PFBDegreeObjective[PFBDegreeSummary[m["Entries"]]], OrderedQ[{{2, 9, 40}, {3, 1, 5}}], PFBDegreeObjective[PFBDegreeSummary[{}]][[1]]}, {{3, 4, 20}, True, -Infinity},
    TestID -> "objective: lexicographic {highest, count, sum}"],
  (* expressions on a planted reduction, samples, a variant on the same graph *)
  VerificationTest[{gE, smp}, {gExpr, {Flatten[expected /. {eps -> pt[[1]], t -> pt[[2]]}]}}, TestID -> "expression graph on a planted reduction: exact samples"],
  VerificationTest[{Lookup[SelectFirst[mE["Entries"], #["Index"] == 1 &], "Eps"], degOf[mE, 2, 0], degOf[mE, 3, 1], degOf[mE, 4, 0], Lookup[mE["Entries"], "Index"]},
    {{"Whole", "finite poles"}, {2, 1, <|1 + t -> 1|>}, {1, 0, <||>}, {0, 0, <||>}, {1, 2, 3, 4, 5}},
    TestID -> "expression graph: degrees of the reduced rows", SameTest -> sameA],
  VerificationTest[{degOf[mV, 2, 0], degOf[mV, 2, 1], degOf[mV, 4, 0], degOf[mV, 4, 1], degOf[mV, 3, 1]},
    {{2, 2, <|1 + t -> 2|>}, {0, 3, <|t -> 2, 1 + t -> 1|>}, {0, 1, <|1 + t -> 1|>}, {0, 1, <|1 + t -> 1|>}, degOf[mE, 3, 1]},
    TestID -> "variant: the columns of a rescaled master on the same graph, nothing learned again", SameTest -> sameA],
  VerificationTest[StringQ[PFBFFExprGraph[gBad, gR, <|"DepVars" -> {jj[1], jj[2]}, "IndepVars" -> {ut[1], ut[2]}|>, {eps, s, t}, {eps, t}, {s -> 1}, {u jj[1]}, {ut[1]}]], True,
    TestID -> "expression graph: a coefficient outside the inputs is refused"],
  VerificationTest[{gRep, Together[smpRep - {expRep}]}, {gRepl, {ConstantArray[0, 6]}}, TestID -> "replace graph: W . T^-1 with T^-1 evaluated inside the graph"],
  VerificationTest[Together[lineF - lineX], ConstantArray[0, Length[fs]], TestID -> "line: the outputs along a line, univariate"],
  (* det T along a line *)
  VerificationTest[{Lookup[facOf[tau + 3], {"Power", "Known"}], Lookup[facOf[tau^2 - 14 tau/5 + 41/5], {"Power", "Known"}], Lookup[facOf[tau - 8], {"Power", "Known"}],
      Lookup[facOf[tau^2 + tau + 1], {"Power", "Known"}], an["SpuriousDegree"], Length[an["Factors"]]},
    {{2, {x}}, {1, {x^2 + y^2 + 7}}, {-1, {x + y}}, {1, {}}, 2, 4}, TestID -> "det T on a line: known factors matched, the spurious one named"],
  VerificationTest[{AssociationQ[rep], If[AssociationQ[rep], {Expand[#["Factor"]], #["Power"], #["Known"]} & /@ SortBy[rep["Factors"], #["Degree"] &], rep]},
    {True, {{3 + tau, 1, {1 + t}}, {7 + 5 tau + tau^2, 1, {}}}}, TestID -> "det T report on a planted line job"],
  VerificationTest[StringContainsQ[PFBDetLineText[rep], "1 spurious"], True, TestID -> "det T text"],
  (* the toolkit side *)
  VerificationTest[{PFBUnitScale[sys], pr["Probes"], pr["UnitScaleOnly"]}, {s, {t, 1 + t}, {s}}, TestID -> "probes: the known singularities with the unit scale set to 1"],
  VerificationTest[With[{a = PFBDegreeSpec[ctx, {key}, {3}, {box}], b = PFBDegreeSpec[ctx, {key}, {3}, {box}]}, {a === b, a["Fix"], a["Cap"], a["Probes"], Keys[a["Point"]]}],
    {True, {s -> 1}, 2, {t, 1 + t}, {t}}, TestID -> "spec: deterministic, unit scale fixed, the run's cap"],
  VerificationTest[{PFBDegreeVariant["r", <|2 -> (1 + t) ut[2]|>]["TInverse"], PFBDegreeVariant["sh", <|3 -> ut[3] + t ut[2]|>]["TInverse"], Quiet[PFBDegreeVariant["z", <|3 -> 0 ut[3] + ut[2]|>]]},
    {<|2 -> ut[2]/(1 + t)|>, <|3 -> -t ut[2] + ut[3]|>, $Failed}, TestID -> "variants: T^-1 of a rescaling and of a shift; a singular T"],
  VerificationTest[{tab["Sectors"][key]["Status"], tab["Sectors"][key]["Summary"]["Highest"], tab["Sectors"][key]["Summary"]["Count"], tab["Sectors"][key]["Summary"]["Sum"],
      Lookup[tab["Sectors"][key]["Entries"], "Column"], tab["Sectors"][{box, {0, 1, 0, 1}}]["Status"]},
    {"measured", 2, 4, 10, {1, 2, 3}, "not measured"}, TestID -> "collect: the sector's table on slice labels; a refused job leaves its sector not measured"],
  VerificationTest[{Last[st2["Slices"]]["Degrees"], FileExistsQ[FileNameJoin[{ctx["Dir"], "degrees", "degrees_000.m"}]], Last[st2["Slices"]]["DegreeSummary"]["Measured"],
      Last[st2["Slices"]]["DegreeSummary"]["Complete"]},
    {"degrees/degrees_000.m", True, 1, False}, TestID -> "collect: degrees_NNN.m indexed in state.m next to its slice"],
  VerificationTest[StringContainsQ[PFBDegreeText[tab], {"highest 2 (4 of 6 terms), sum 10", "not measured: box/j0101"}], True, TestID -> "census text of the degrees"],
  VerificationTest[StringQ[summaryPage] && StringContainsQ[Import[summaryPage, "Text"], "Kinematic degrees"], True, TestID -> "summary page: the degree table"],
  VerificationTest[With[{c2 = PFBCollectDegrees[ctx, {jd}]}, Module[{redOff = Get[FileNameJoin[{jd, "red_1.m"}]]},
      Put[Join[redOff, <|"Dm" -> {{Rsl[[3]] + {0, 1, 0}}}|>], FileNameJoin[{jd, "red_1.m"}]];
      PFBCollectDegrees[Join[ctx, <|"State" -> c2["State"]|>], {jd}]["Table"]["Sectors"][key]["Status"]]], "not measured",
    TestID -> "collect: a reduction that does not calibrate against the slice is not measured"],
  (* a user's degrees *)
  VerificationTest[With[{r = imp[good]}, {r["Status"], r["Table"]["Provenance"]["Source"], r["Table"]["Sectors"][key]["Summary"]["Highest"], r["Table"]["Sectors"][key]["Status"]}],
    {"ok", "user", 2, "measured"}, TestID -> "import: a valid degrees file, provenance user"],
  VerificationTest[imp[Transpose /@ good, <|"Transpose" -> True|>]["Status"], "ok", TestID -> "import: the slice's Transpose applies"],
  VerificationTest[With[{r = imp[{Most[good[[1]]]}]}, {r["Status"], StringContainsQ[errOf[r], "matrix per derivative"]}], {"refused", True}, TestID -> "import: wrong dimensions"],
  VerificationTest[With[{r = imp[ReplacePart[good, {1, 2, 1} -> <|1 -> {1, 1}|>]]}, {r["Status"], StringContainsQ[errOf[r], "finite poles"]}], {"refused", True},
    TestID -> "import: per power of eps on an entry with finite poles"],
  VerificationTest[With[{r = imp[ReplacePart[good, {1, 3, 1} -> <|1 -> {1, 1}|>]]}, {r["Status"], StringContainsQ[errOf[r], "powers of eps {2}"]}], {"refused", True},
    TestID -> "import: a power of eps the entry has is missing"],
  VerificationTest[With[{r = imp[ReplacePart[good, {1, 1, 3} -> <|0 -> {1, 1}|>]]}, {r["Status"], StringContainsQ[errOf[r], "0 in the slice"]}], {"refused", True},
    TestID -> "import: degrees for a zero entry"],
  VerificationTest[With[{r = imp[ReplacePart[good, {1, 3, 3} -> 0]]}, {r["Status"], StringContainsQ[errOf[r], "no degrees"]}], {"refused", True},
    TestID -> "import: no degrees for a non-zero entry"],
  VerificationTest[{imp[ReplacePart[good, {1, 3, 3} -> <|0 -> {-1, 1}, 1 -> {1, 1}|>]]["Status"], imp[ReplacePart[good, {1, 2, 1} -> <|"Whole" -> {1, 1}, 0 -> {1, 1}|>]]["Status"]},
    {"refused", "refused"}, TestID -> "import: negative degrees, and Whole with other keys"],
  VerificationTest[With[{r = imp[ReplacePart[good, {1, 3, 3} -> <|0 -> {0, 1}, 1 -> {1, 1}, 2 -> {1, 1}|>]]}, {r["Status"], Length[r["Warnings"]]}], {"ok", 1},
    TestID -> "import: a power whose coefficient vanishes at the slice point is a warning"]
};

report = TestReport[tests];
Do[With[{r = report["TestResults"][id]},
    Print[If[r["Outcome"] === "Success", "PASS ", "FAIL "], r["TestID"], If[r["Outcome"] === "Success", "",
      "\n     got " <> ToString[Short[r["ActualOutput"], 5], InputForm] <> "\n     expected " <> ToString[Short[r["ExpectedOutput"], 5], InputForm]]]],
  {id, Keys[report["TestResults"]]}];
Print[report["TestsSucceededCount"], " passed, ", report["TestsFailedCount"], " failed, ", Round[report["TimeElapsed"], 0.1]];
Quiet[DeleteDirectory[tmp, DeleteContents -> True]];
Exit[If[report["AllTestsSucceeded"], 0, 1]];
