#!/usr/bin/env wolframscript
(* Free tie-breaks during the ladder: the digit height of the rows on the slice (PFBDigitHeight, one helper shared by the
   scans, the completion solver and the swaps of the simplification phase) orders the sets the scans rank equal on every
   other key, and the completions of equal weight the completion solver meets; the solver tries the monomials of its
   ansatz by degree in the invariants with the unit scale set to 1 (PFBMonomialDegree), lowest first.
   Planted data, as in tests/eps_degree.wls: the one-loop massless box of the maximal-cut-basis examples (unit scale s,
   one derivative d/dt). A change is planted as new masters J' = M J: with a target DE R' in the new basis the old slice
   is M^-1 R' M, and a candidate integral reduces to M[[3]] with the derivative R'[[3]].M. Completions are planted as
   reductions whose correction integrals carry the pole 1/(1 - 2 eps) of the box row. No IBP reduction. The linear solver
   is checked without FiniteFlow (its fallback, a sparse elimination in the order of the unknowns) and, when FiniteFlow
   is found and its library matches FiniteFlow.m, against FFSparseSolve; a library that lacks functions FiniteFlow.m
   loads (planted by setting one of them to $Failed) is refused at once instead of hanging in FFSparseSolve.
   usage: bin/ws tests/tie_breaks.wls        exit code 0 when every test passes; the tools from $PFB_TEST_PATHS (a
          paths.wl) when it is set, else the usual detection *)
Get[FileNameJoin[{ParentDirectory[DirectoryName[$InputFileName]], "lib", "PoleFreeBasis.wl"}]];
$PFBVerbose = False;
With[{p = Environment["PFB_TEST_PATHS"]}, MCBLoadPaths[If[StringQ[p] && FileExistsQ[p], p, Automatic]]];
boxFile = FileNameJoin[{ParentDirectory[ParentDirectory[DirectoryName[$InputFileName]]], "maximal-cut-basis", "examples", "box-one-loop", "family.wl"}];
tmp = CreateDirectory[];
loadSystem[masters_, name_] := (Put[masters, FileNameJoin[{tmp, name <> ".m"}]];
  Put[<|"Name" -> name, "Families" -> {<|"Name" -> "box", "Family" -> boxFile, "Masters" -> name <> ".m"|>}|>, FileNameJoin[{tmp, name <> ".wl"}]];
  PFBReadSystem[FileNameJoin[{tmp, name <> ".wl"}]]);
key = {box, {1, 1, 1, 1}};
P = {s -> 1, t -> 3/7}; t0 = t /. P;
slice[R_] := <|"R" -> {R}, "Derivatives" -> {t}, "Point" -> P, "Labels" -> {1, 2, 3}, "Index" -> <|1 -> 1, 2 -> 2, 3 -> 3|>, "History" -> {}|>;

(* ---- the scans ---- *)
sys = loadSystem[{j[box, 1, 0, 1, 0], j[box, 0, 1, 0, 1], s t j[box, 1, 1, 1, 1]}, "scan"];
(* the box replaced by a dotted box whose reduction carries lam on the t-bubble: the old box row has finite poles. The
   target box rows: L and H have the same eps profile (eps to eps^2, nothing above the cap) and differ only in their
   digits; D is heavier than L but ends at eps^1, so the highest power of eps decides before the digit height *)
lam = (2 + eps)/(1 - 2 eps);
M = {{1, 0, 0}, {0, 1, 0}, {0, lam, 1}};
Rtop = {{-eps/3, 0, 0}, {eps, -2 eps, 0}};
rowL = {eps + eps^2, 1 + eps, -1 - 2 eps};
rowH = {123457/89 eps + eps^2, 1 + eps, -1 - 2 eps};
rowD = {98765/43 eps, 1 + eps, -1 - 2 eps};
Rold = Together[Inverse[M] . Append[Rtop, rowL] . M];
oldSl = slice[Rold]; c0 = PFBCensus[sys, oldSl];
(* a reduction at the slice point whose candidates (definition s t^2 times the integral) give the rows asked for *)
redOf[rows_Association] := <|"Masters" -> {ut[1], ut[2], ut[3]}, "Point" -> P, "Invariants" -> {t}, "Focus" -> {1, 2, 3}, "Dm" -> {Rold},
   "Pool" -> Join[{j[box, 1, 0, 1, 0], j[box, 0, 1, 0, 1], j[box, 1, 1, 1, 1]}, Keys[rows]],
   "Rp" -> Join[{{1, 0, 0}, {0, 1, 0}, {0, 0, 1/t0}}, ConstantArray[M[[3]]/t0^2, Length[rows]]],
   "dRp" -> {Join[{Rold[[1]], Rold[[2]], (Rold[[3]] - {0, 0, 1/t0})/t0}, Together[(# . M - 2 M[[3]]/t0)/t0^2] & /@ Values[rows]]}|>;
(* the same two rows on two integrals, both ways round: whichever order the integrals come in, the lighter row wins *)
red1 = redOf[<|j[box, 1, 1, 1, 2] -> rowL, j[box, 1, 1, 2, 1] -> rowH, j[box, 1, 2, 1, 1] -> rowD|>];
red2 = redOf[<|j[box, 1, 1, 2, 1] -> rowL, j[box, 1, 1, 1, 2] -> rowH, j[box, 1, 2, 1, 1] -> rowD|>];
cal1 = PFBCalibrate[oldSl, red1]; cal2 = PFBCalibrate[oldSl, red2];
setOf[int_] := <|3 -> s t^2 int|>;
scan[red_, cal_, ints_] := PFBScanSets[sys, oldSl, red, cal, key, setOf /@ ints, <|"Census" -> c0, "FullCensus" -> True|>]["Results"];
intOf[r_] := r["set"][3]/(s t^2);
keysOf[r_] := Lookup[r, {"bad", "newBad", "over", "zero", "high", "deferred", "dCensus", "neg", "deg"}];
scan1 = scan[red1, cal1, {j[box, 1, 1, 2, 1], j[box, 1, 1, 1, 2]}];
scan2 = scan[red2, cal2, {j[box, 1, 1, 1, 2], j[box, 1, 1, 2, 1]}];
scanD = scan[red1, cal1, {j[box, 1, 1, 1, 2], j[box, 1, 2, 1, 1]}];

tests = {
  VerificationTest[{sys =!= $Failed, cal1["Status"], cal2["Status"], c0["BadRows"]}, {True, "exact", "exact", {3}}, TestID -> "the planted system and reductions"],
  VerificationTest[{Context[PFBDigitHeight], Context[PFBRowsDigitHeight], PFBDigitHeight[123/45 eps + 7], PFBDigitHeight[{0, 1, {2 eps}}],
      PFBRowsDigitHeight[slice[Append[Rtop, rowL]], {3}] == PFBDigitHeight[rowL], PFBRowsDigitHeight[slice[Append[Rtop, rowL]], {1, 3}] == PFBDigitHeight[{Rtop[[1]], rowL}]},
    {"PoleFreeBasis`Slice`", "PoleFreeBasis`Slice`", 10, 8, True, True}, TestID -> "digit height: one helper, the sum over every entry and every power of eps"],
  VerificationTest[{PFBDigitHeight[rowL] < PFBDigitHeight[rowH], PFBDigitHeight[rowL] < PFBDigitHeight[rowD]}, {True, True}, TestID -> "the planted rows: L is the lightest"],
  (* two sets equal on every key: the smaller digit height first, whichever integral carries it *)
  VerificationTest[{keysOf[scan1[[1]]] === keysOf[scan1[[2]]], keysOf[scan2[[1]]] === keysOf[scan2[[2]]], keysOf[scan1[[1]]]},
    {True, True, {0, 0, 0, 0, 0, 0, -Length[c0["BadEntries"]], 0, 2}}, TestID -> "scan: the planted sets are equal on every other key"],
  VerificationTest[{intOf /@ scan1, intOf /@ scan2, Lookup[scan1, "height"], Lookup[scan2, "height"]},
    {{j[box, 1, 1, 1, 2], j[box, 1, 1, 2, 1]}, {j[box, 1, 1, 2, 1], j[box, 1, 1, 1, 2]}, PFBDigitHeight /@ {rowL, rowH}, PFBDigitHeight /@ {rowL, rowH}},
    TestID -> "scan: among sets equal on every key, the smaller digit height of the sector's rows first"],
  (* the existing keys decide: D ends at eps^1, L at eps^2, so D comes first although its digits are heavier *)
  VerificationTest[{intOf /@ scanD, Lookup[scanD, "deg"], Lookup[scanD, "height"]},
    {{j[box, 1, 2, 1, 1], j[box, 1, 1, 1, 2]}, {1, 2}, PFBDigitHeight /@ {rowD, rowL}}, TestID -> "scan: the highest power of eps decides before the digit height"],
  VerificationTest[With[{ch = PFBChangeVectors[sys, oldSl, red1, cal1, PFBImageDefs[sys, setOf[j[box, 1, 1, 2, 1]]]]},
      PFBRowsDigitHeight[PFBApplyChange[oldSl, Join[ch, <|"Name" -> "check"|>]], {3}]], PFBDigitHeight[rowH], TestID -> "scan: the height is that of the sector's rows on the new slice"]
};

(* ---- the completion solver ---- *)
(* the box row has the pole of v1 = 1/(1 - 2 eps) in column 1; the sector's own block is A33 = -2 eps. A correction
   c phi w with w = U1 on the lower masters adds c (d phi + phi (dw - A33 w)) to (3, 1) *)
A33 = -2 eps; v1 = 1/(1 - 2 eps);
RoldC = {{-eps, 0, 0}, {0, -2 eps, 0}, {Together[eps - (v1 - A33)], eps, A33}};
redC[base_, extra_Association] := <|"Masters" -> {ut[1], ut[2], ut[3]}, "Point" -> P, "Invariants" -> {t}, "Focus" -> {1, 2, 3}, "Dm" -> {RoldC},
   "Pool" -> Join[{j[box, 1, 0, 1, 0], j[box, 0, 1, 0, 1], j[box, 1, 1, 1, 1]}, Keys[extra]],
   "Rp" -> Join[{{1, 0, 0}, {0, 1, 0}, {0, 0, 1/(base /. P)}}, ConstantArray[{1, 0, 0}, Length[extra]]],
   "dRp" -> {Join[{RoldC[[1]], RoldC[[2]], Together[(RoldC[[3]] - (D[base, t] /. P) {0, 0, 1/(base /. P)})/(base /. P)]}, ({#, 0, 0} & /@ Values[extra])]}|>;
(* completions of equal weight: wA and wB carry one dot each, in the same subsector. wA alone removes the pole with
   coefficient 1 and leaves eps in (3, 1); wB alone with 1/2 and leaves 123457/178. The solver finds wA first (its
   unknown is listed first), then drops it for wB while it sparsifies: both are completions of the same weight *)
sysC = loadSystem[{j[box, 1, 0, 1, 0], j[box, 0, 1, 0, 1], s j[box, 1, 1, 1, 1]}, "completion"];
wA = j[box, 1, 0, 2, 0]; wB = j[box, 2, 0, 1, 0]; wC = j[box, 3, -1, 1, 0];
redAB = redC[s, <|wA -> v1, wB -> 2 v1 + 123457/89|>];
compAB = PFBCompletionSolve[sysC, {redAB}, key, <||>];
(* the other way round: wB light, wA heavy *)
compBA = PFBCompletionSolve[sysC, {redC[s, <|wA -> 2 v1 + 123457/89, wB -> v1|>]}, key, <||>];
compB = PFBCompletionSolve[sysC, {redAB}, key, <|"PoolSelect" -> (# =!= wA &)|>];
(* the weight decides first: wC (two dots and a numerator) would leave eps like wA, but wB is lighter *)
compBC = PFBCompletionSolve[sysC, {redC[s, <|wB -> 2 v1 + 123457/89, wC -> v1|>]}, key, <||>];
(* the monomial order: the box master s t j[box, 1, 1, 1, 1] needs coefficients of mass dimension 2 on w1 (one dot), s
   or t. With s (degree 0, unit scale s) the correction is s w1 and (3, 1) becomes eps; with t (degree 1) it is 7/3 t w1.
   Both remove the pole: the lower degree is used *)
sysM = loadSystem[{j[box, 1, 0, 1, 0], j[box, 0, 1, 0, 1], s t j[box, 1, 1, 1, 1]}, "monomials"];
w1 = j[box, 2, 0, 1, 0];
redM = redC[s t, <|w1 -> v1|>];
compM = PFBCompletionSolve[sysM, {redM}, key, <||>];
compMt = PFBCompletionSolve[sysM, {redM}, key, <|"Monomials" -> {t, s}|>];
compMs = PFBCompletionSolve[sysM, {redM}, key, <|"Monomials" -> {s, t}|>];
compMonly = PFBCompletionSolve[sysM, {redM}, key, <|"Monomials" -> {t}|>];

(* ---- the linear solver, with FiniteFlow and without ---- *)
ffQ = PFBLoadFiniteFlow[];
noFF[e_] := Block[{PFBLoadFiniteFlow = (False &)}, e];
SetAttributes[noFF, HoldFirst];
(* small systems: one equation, a dependent pair, a free unknown in the middle, an inconsistent one, homogeneous ones *)
systems = {{{x1 + 3/7 x2 - 1}, {x1, x2}}, {{x1 + 3/7 x2 - 1}, {x2, x1}}, {{x1 + x2 + x3 - 1, x2 - x3}, {x1, x2, x3}}, {{x1 + x2 + x3 - 1, x2 - x3}, {x3, x2, x1}},
   {{x1 + x2 - 1, 2 x1 + 2 x2 - 3}, {x1, x2}}, {{x1 + x2 - 1, x2 - x3}, {x1, x2, x3}}, {{2 x1 - x3 + 5, x2 + 4 x4 - 1/3, x1 - x3 + x4, 4 x2 + 16 x4 - 4/3}, {x1, x2, x3, x4}},
   {{x2 - 2 x3, x1 + x2 + x3 + x4 - 2, 3 x1 + x4}, {x4, x3, x2, x1}}, {{x1 - x2, x2 - x3}, {x1, x2, x3}}};
solveSorted[e_, u_] := With[{r = PFBSolveLinear[e, u]}, {r["Status"], Sort[r["Solution"]], r["Free"]}];
fallbackSols = noFF[solveSorted @@@ systems];
ffSols = If[ffQ, solveSorted @@@ systems, fallbackSols];
(* a long sparse chain: x_i - x_(i+1) = 1, x_n = 0. The fallback eliminates it row by row in a few MB; the dense
   elimination it replaces needed 1.5 GB for 3000 unknowns *)
chainN = 3000; chainX = Array[xc, chainN];
chainEqs = Append[Table[chainX[[i]] - chainX[[i + 1]] - 1, {i, chainN - 1}], chainX[[chainN]]];
chainMem = MaxMemoryUsed[chain = noFF[TimeConstrained[PFBSolveLinear[chainEqs, chainX], 120, $Aborted]]];
(* a library that lacks a function FiniteFlow.m loads: refused at once, and the solver falls back *)
ffBad = If[ffQ, Block[{FiniteFlow`Private`FFRegisterSparseSolverExImplem = $Failed}, {PFBFiniteFlowProblem[], PFBLoadFiniteFlow[], solveSorted @@ systems[[3]]}], None];

tests = Join[tests, {
  (* the solver uses the unknowns listed first, with FiniteFlow or without *)
  VerificationTest[{Sort[PFBSolveLinear[{x1 + 3/7 x2 - 1}, {x1, x2}]["Solution"]], Sort[PFBSolveLinear[{x1 + 3/7 x2 - 1}, {x2, x1}]["Solution"]],
      Sort[PFBSolveLinear[{x1 + x2 + x3 - 1, x2 - x3}, {x1, x2, x3}]["Solution"]], Sort[PFBSolveLinear[{x1 + x2 + x3 - 1, x2 - x3}, {x3, x2, x1}]["Solution"]],
      PFBSolveLinear[{x1 + x2 - 1, 2 x1 + 2 x2 - 3}, {x1, x2}]["Status"], PFBSolveLinear[{x1 + x2 - 1, x2 - x3}, {x1, x2, x3}]["Free"]},
    {{x1 -> 1, x2 -> 0}, {x1 -> 0, x2 -> 7/3}, {x1 -> 1, x2 -> 0, x3 -> 0}, {x1 -> 0, x2 -> 1/2, x3 -> 1/2}, "impossible", 1},
    TestID -> "linear solver: the first unknowns are solved for, the last ones are free and set to 0"],
  VerificationTest[noFF[{Sort[PFBSolveLinear[{x1 + 3/7 x2 - 1}, {x2, x1}]["Solution"]], PFBSolveLinear[{x1 + x2 - 1, 2 x1 + 2 x2 - 3}, {x1, x2}]["Status"],
      PFBSolveLinear[{x1 + x2 - 1, x2 - x3}, {x1, x2, x3}]["Free"]}], {{x1 -> 0, x2 -> 7/3}, "impossible", 1},
    TestID -> "linear solver without FiniteFlow: the same order of the unknowns"],
  VerificationTest[fallbackSols === ffSols, True, TestID -> "linear solver: the fallback gives FFSparseSolve's solutions and free unknowns (when FiniteFlow is found)"],
  VerificationTest[{AssociationQ[chain], Lookup[chain, "Free", None], Lookup[Association[Lookup[chain, "Solution", {}]], {xc[1], xc[chainN]}, None], chainMem < 10^8},
    {True, 0, {chainN - 1, 0}, True}, TestID -> "linear solver without FiniteFlow: sparse elimination of a long chain, under 100 MB"],
  VerificationTest[If[ffQ, {StringQ[ffBad[[1]]] && StringContainsQ[ffBad[[1]], "FFRegisterSparseSolverEx"], ffBad[[2]], ffBad[[3]], PFBLoadFiniteFlow[]}, "no FiniteFlow"],
    If[ffQ, {True, False, fallbackSols[[3]], True}, "no FiniteFlow"], TestID -> "FiniteFlow: a library older than FiniteFlow.m is refused at once, the solver falls back"],
  VerificationTest[{PFBAnsatzMonomials[sysM, 2], PFBMonomialDegree[sysM, #] & /@ {1, s, t, s t, t^2/s, s^2, t/(s + t), 1/t^2}}, {{t, s}, {0, 0, 1, 1, 2, 0, 1, 2}},
    TestID -> "monomial degree: in the invariants with the unit scale set to 1"],
  VerificationTest[{compM["Status"], Coefficient[compM["Defs"][3], w1], Coefficient[compMt["Defs"][3], w1], Coefficient[compMs["Defs"][3], w1]}, {"solved", s, s, s},
    TestID -> "completion: the monomial of lowest degree first, from PFBAnsatzMonomials or from \"Monomials\""],
  VerificationTest[{compMonly["Status"], Coefficient[compMonly["Defs"][3], w1]}, {"solved", 7 t/3}, TestID -> "completion: a higher degree when it is the only one"],
  VerificationTest[{compAB["Status"], Coefficient[compAB["Defs"][3], {wA, wB}], compAB["EqualWeight"], compAB["Height"]},
    {"solved", {1, 0}, 2, PFBDigitHeight[{A33, eps, eps}]}, TestID -> "completion: of two completions of equal weight, the smaller digit height of the new rows"],
  VerificationTest[{compBA["Status"], Coefficient[compBA["Defs"][3], {wA, wB}], compBA["EqualWeight"], compBA["Height"]},
    {"solved", {0, 1}, 2, PFBDigitHeight[{A33, eps, eps}]}, TestID -> "completion: the same, the other way round"],
  VerificationTest[{compB["Status"], Coefficient[compB["Defs"][3], {wA, wB}], compB["EqualWeight"], compB["Height"]},
    {"solved", {0, 1/2}, 1, PFBDigitHeight[{A33, 123457/178, eps}]}, TestID -> "completion: the only completion is kept, whatever its height"],
  VerificationTest[{compBC["Status"], Coefficient[compBC["Defs"][3], {wB, wC}], compBC["EqualWeight"], compBC["Height"] > PFBDigitHeight[{A33, eps, eps}]},
    {"solved", {1/2, 0}, 1, True}, TestID -> "completion: the lighter weight first, before any digit height"]
}];

report = TestReport[tests];
Do[With[{r = report["TestResults"][id]},
    Print[If[r["Outcome"] === "Success", "PASS ", "FAIL "], r["TestID"], If[r["Outcome"] === "Success", "",
      "\n     got " <> ToString[Short[r["ActualOutput"], 3], InputForm] <> "\n     expected " <> ToString[Short[r["ExpectedOutput"], 3], InputForm]]]],
  {id, Keys[report["TestResults"]]}];
Print[report["TestsSucceededCount"], " passed, ", report["TestsFailedCount"], " failed, ", Round[report["TimeElapsed"], 0.1]];
DeleteDirectory[tmp, DeleteContents -> True];
Exit[If[report["AllTestsSucceeded"], 0, 1]];
