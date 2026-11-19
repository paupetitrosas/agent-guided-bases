(* ::Package:: *)

(* FiniteFlow check of {{FAMILY}} {{SECTORNAME}}, step 2 of 3: differentiate the basis, reduce the derivatives on
   the maximal cut and reconstruct the DE  d ut/dX = A_X ut  (rational frame: J_i = Sqrt[prefacts_i] ut_i).
   - The basis never enters the IBP system. Each element is read as it is written in elements.m, ut_i = Sum_a c_ia j_a
     (prefactor x pieces), and FiniteFlow evaluates every coefficient as it stands (FFAlgRatExprEval, FiniteFlow 2.0 or
     later): no Expand, no Together, no Simplify, however large the coefficients. Only the pieces j_a and their
     derivatives are reduced; two sparse products combine them with the coefficients:
       E (pieces and their derivatives on the integrals) . R (the integrals on the masters M of the cut)  = W,
       L (the coefficients, and their derivatives) . W  =  ( T ; D ),   ut = T M,  d ut/dX = D_X M,
     and a small linear solver in the graph gives A_X = D_X T^-1. T must be invertible: the basis is a basis of the cut.
   - The derivatives with respect to the invariants of the external scalar products come from LiteIBP (LIBPDeriv,
     fast: the derivative of every propagator is computed once); the others (internal masses that are not such
     invariants, constants of linear propagators) were computed by MaximalCutBasis and are read from derivatives.m.
   - The square roots never appear: J_i = Sqrt[R_i] ut_i with R_i in prefacts.m, so the d log term is R_i'/(2 R_i),
     rational.
   Environment MCB_FF_MODE=slice: reconstruct in eps only, at the point of ffinfo.m (the fallback when the
   full reconstruction exceeds the time limit).
   MCB_FF_MODE=line (the Picard-Fuchs step): the DE along the line x(tt) = p0 + tt v of ffline.m, A_tt = Sum_X v_X A_X,
   and the row of the corner integral, expanded in eps up to eps^order and reconstructed in tt alone; written to
   sysline.m.  Written by MaximalCutBasis. *)

{{PATHS}}
(* MaximalCutBasis also runs this file inside its own kernel (MCB_FF_INKERNEL=1, for the Picard-Fuchs line): the
   packages are then loaded already, and the script ends by a Throw instead of Quit *)
finish[] := If[Environment["MCB_FF_INKERNEL"] === "1", Throw[Null, "mcbff"], Quit[]];
If[! MemberQ[$Packages, "FiniteFlow`"], Get["FiniteFlow`"]];
If[! MemberQ[$Packages, "LiteRed`"], Get["{{LITEREDFILE}}"]];
If[! MemberQ[$Packages, "LiteIBP`"], Get["LiteIBP`"]];
Get["topology.wl"];

info = Get["ffinfo.m"];
mode = Switch[Environment["MCB_FF_MODE"], "slice", "eps-slice", "line", "line", _, "full"];
fail[msg_] := (Export["sysinfo.m", <|"status" -> "failed", "message" -> msg, "mode" -> mode|>]; Print["FAILED: ", msg]; finish[]);

(* the basis as written: per element, the pieces {j, c} with their coefficients as they stand (UnitScale -> 1) *)
elements = Get["elements.m"];
nb = Length[elements];
uv = Table[ut[i], {i, nb}];
integrals = LIBPGetAllInts[FileNames["ibps/ints_*.mx"]];
variables = info["variables"];
invariants = info["derivativeVariables"];
(* a sector that depends on the unit scale only (a tadpole) has no invariant left once it is set to 1: its DE follows
   from the mass dimension, which the Kira check covers *)
If[variables === {} || invariants === {},
  Export["sysinfo.m", <|"status" -> "not applicable", "mode" -> mode,
    "message" -> "the sector depends on the unit scale only: no DE to reconstruct with UnitScale = 1 (the Kira check covers it)"|>];
  Print["not applicable: the sector depends on the unit scale only"]; finish[]];

FFNewGraph[graph, in, variables];
eqsfiles = FileNames["ibps/sids_*.json"];

prefacts = Get["prefacts.m"];              (* R_i: J_i = Sqrt[R_i] ut_i *)
dinfo = Get["derivatives.m"];              (* <|"LiteIBP" -> {X..}, "Precomputed" -> <|X -> <|j -> dj/dX|>|>|> *)
liteX = Intersection[invariants, dinfo["LiteIBP"]];
If[liteX =!= {}, LIBPComputeDerivatives[{{FAMILY}}]];
pfline = If[mode === "line", Get["ffline.m"], None];
pieces = Union[Flatten[elements[[All, All, 1]]], If[mode === "line", {pfline["corner"]}, {}]];
(* the derivative of each piece: one integral, small coefficients.
   LIBPDeriv returns products (dD_k/dX) j[a + e_k] whose first factor holds j's of numerators only, e.g. j[f, 0, 0, 0, -1, 0]:
   LiteRed merges them into integrals only when the product is expanded (Collect), and LIBPEliminateZeroSectors on the
   unexpanded product would take them for scaleless integrals and drop them *)
(* the iterators are local: this runs in Global`, where an invariant may be called X or i *)
liteDeriv[jj_, x_] := LIBPEliminateZeroSectors[Collect[LIBPDeriv[jj, x], _j] /. {{SUBST}}];
pieceDeriv = Module[{x, jj}, Association[Table[x -> Association[Table[jj -> If[MemberQ[liteX, x], liteDeriv[jj, x],
      Lookup[Lookup[dinfo["Precomputed"], x, <||>], jj, Missing[]]], {jj, pieces}]], {x, invariants}]]];
If[! FreeQ[pieceDeriv, _Missing],
  fail["derivatives.m has no derivative of " <> ToString[Take[Union[Cases[Normal[pieceDeriv], (jj_ -> _Missing) :> jj, Infinity]], UpTo[3]], InputForm] <>
    ": write the pipeline again"]];
(* LiteIBP builds its derivative operators with FFDenseSolve; when that fails (an old FiniteFlow library, for example),
   LIBPDeriv returns unevaluated operators, which FiniteFlow would only refuse much later *)
With[{stray = Complement[Union[Cases[Values /@ Values[pieceDeriv] /. _j -> 1, _Symbol, {0, Infinity}]], variables]},
  If[stray =!= {}, fail["the derivatives contain " <> ToString[Take[stray, UpTo[5]], InputForm] <> ", not only the variables " <> ToString[variables, InputForm] <>
     If[liteX =!= {}, ": LiteIBP could not build its derivative operators (FFDenseSolve failed, as with a FiniteFlow library older than 2.0); point FiniteFlowLibrary to a current build", ""]]]];
Print["derivatives: LiteIBP for ", liteX, ", precomputed for ", Complement[invariants, liteX]];

(* the coefficients of the rows, as written: T rows ut_i = Sum_a c_ia j_a; D rows (X-major) d ut_i/dX = Sum_a (dc_ia/dX +
   g_iX c_ia) j_a + c_ia dj_a/dX, with g_iX = d log Sqrt[R_i]/dX; in line mode one more row, the corner integral *)
(* local iterators: an invariant may be called i or x, and the coefficients hold the invariants *)
lrows = Module[{i, x}, Join[
  Table[{{"j", #[[1]]}, #[[2]]} & /@ elements[[i]], {i, nb}],
  Join @@ Table[With[{g = D[prefacts[[i]], x]/(2 prefacts[[i]]), xx = x},
      Join @@ ({{{"j", #[[1]]}, D[#[[2]], xx] + g #[[2]]}, {{"d", xx, #[[1]]}, #[[2]]}} & /@ elements[[i]])], {x, invariants}, {i, nb}],
  If[mode === "line", {{{{"j", pfline["corner"]}, 1}}}, {}]]];
With[{stray = Complement[Union[Cases[lrows[[All, All, 2]], _Symbol?(! NumericQ[#] &), {0, Infinity}]], variables]},
  If[stray =!= {}, fail["the coefficients of the basis contain " <> ToString[Take[stray, UpTo[5]], InputForm] <> ", not only the variables " <> ToString[variables, InputForm]]]];
(* every derivative vanishes on the cut (the sector does not depend on the invariants left, e.g. a tadpole): the DE is
   zero, and FiniteFlow has nothing to solve. The line mode still needs the corner row *)
If[mode =!= "line" && AllTrue[Flatten[Values /@ Values[pieceDeriv]], # === 0 &] &&
   AllTrue[Cases[lrows[[nb + 1 ;; nb + nb Length[invariants]]], {{"j", _}, c_} :> c, {2}], # === 0 &],
  Export["sys.m", ConstantArray[0, {Length[invariants], nb, nb}]];
  Export["sysinfo.m", <|"status" -> "ok", "mode" -> mode, "invariants" -> invariants, "masters" -> uv,
     "slicePoint" -> If[mode === "full", None, info["slicePoint"]], "liteIBPInvariants" -> liteX|>];
  Print["every derivative vanishes on the cut: the DE is zero"]; finish[]];

newneededints = Union[pieces, LIBPIntegralsIn[Values /@ Values[pieceDeriv]]];
If[! SubsetQ[integrals, newneededints],
  fail["seeds too small: " <> ToString[Length[Complement[newneededints, integrals]]] <> " integrals of the basis or its derivatives are not in the system, e.g. " <>
    ToString[Take[Complement[newneededints, integrals], UpTo[3]], InputForm] <> "; raise rank/maxdots in genIBPs.m"]];

LIBPWriteSystemJSON[eqsfiles, integrals, newneededints, variables, "FileName" -> "system.json"];
FFAlgJSONSparseSolver[graph, ibps, {in}, "system.json"];
FFSolverOnlyHomogeneous[graph, ibps];
FFGraphOutput[graph, ibps];
ibplearn = FFSparseSolverLearn[graph, integrals];
{nonmasters, masters} = {"DepVars", "IndepVars"} /. ibplearn;
Print["masters of the cut system: ", masters];
If[Length[masters] =!= nb,
  fail["the basis is not a basis of the maximal cut: its elements, their derivatives and the corner integral reduce onto the " <> ToString[Length[masters]] <>
    " masters " <> ToString[masters, InputForm] <> ", the basis has " <> ToString[nb] <> " elements"]];
FFSparseSolverMarkAndSweepEqs[graph, ibps];
FFSparseSolverDeleteUnneededEqs[graph, ibps];

(* the entries of a sparse matrix, row by row, as {columns, values}: the terms of one integral are added, nothing is
   put over a common denominator. The integral is replaced by 1, not divided out: LiteRed multiplies j's
   (j[f, a]/j[f, a] is j[f, 0, ..., 0], not 1) *)
ffpos = AssociationThread[Join[nonmasters, masters] -> Range[Length[nonmasters] + nb]];
sparseRow[e_] := Module[{a = <||>, t = Collect[e, _j]},
  Scan[Function[term, With[{js = Union[Cases[{term}, _j, {0, Infinity}]]},
      Switch[Length[js], 0, Null, 1, a[First[js]] = Lookup[a, First[js], 0] + (term /. First[js] -> 1),
        _, fail["a term with two integrals in a derivative: " <> ToString[Short[term, 2], InputForm]]]]], If[Head[t] === Plus, List @@ t, {t}]];
  a = DeleteCases[a, 0];
  SortBy[{ffpos[#], a[#]} & /@ Keys[a], First]];
items = Join[{"j", #} & /@ pieces, Module[{x, jj}, Flatten[Table[{"d", x, jj}, {x, invariants}, {jj, pieces}], 1]]];
itemPos = AssociationThread[items -> Range[Length[items]]];
erows = Module[{it}, Table[If[it[[1]] === "j", {{ffpos[it[[2]]], 1}}, sparseRow[pieceDeriv[it[[2]]][it[[3]]]]], {it, items}]];
lrows = SortBy[DeleteCases[{itemPos[#[[1]]], #[[2]]} & /@ #, {_, 0}], First] & /@ lrows;
nrows = Length[lrows];
(* FFAlgRatExprEval needs a library built from FiniteFlow of September 2025 or later (commit 98641f0), which changed its
   bytecode without changing the version number: libraries of December 2024 to September 2025 report 2.0 too. An older
   library, typically a copy in the user's SystemFiles/LibraryResources, hangs on the new bytecode inside the library,
   where no time limit can stop it. The rational-expression parser came with that change, so its library function
   (loaded by the package; $Failed with an older library) tells them apart. With an older library the coefficients are
   put over a common denominator and evaluated with FFAlgRatFunEval: slower, same result *)
evaluator = If[IntegerQ[$FFVersion] && $FFVersion >= 2 && Head[FiniteFlow`Private`FFAlgRatExprEvalParseImplem] === LibraryFunction,
  "FFAlgRatExprEval", "FFAlgRatFunEval"];
If[evaluator =!= "FFAlgRatExprEval",
  Print["WARNING: the FiniteFlow library ", FindLibrary["fflowmlink"], " predates the evaluator of September 2025: the coefficients go ",
    "through Together and FFAlgRatFunEval. Point \"FiniteFlowLibrary\" in paths.wl to a current build."]];
evalNode[node_, exprs_] := If[evaluator === "FFAlgRatExprEval",
  FFAlgRatExprEval[graph, node, {in}, variables, exprs],
  FFAlgRatFunEval[graph, node, {in}, variables, Together /@ exprs]];
(* W = E . R^: the pieces and their derivatives on the masters; R^ is the reduction of the integrals (ibps) with the
   identity rows of the masters below it *)
evalNode[enode, Flatten[erows[[All, All, 2]]]];
FFAlgRatNumEval[graph, unit, Flatten[IdentityMatrix[nb]]];
FFAlgChain[graph, rhat, {ibps, unit}];
FFAlgSparseMatMul[graph, wnode, {enode, rhat}, Length[items], Length[ffpos], nb, erows[[All, All, 1]], ConstantArray[Range[nb], Length[ffpos]]];
(* V = L . W: the rows of T (the basis on the masters), then of D (its derivatives), then the corner *)
evalNode[lnode, Flatten[lrows[[All, All, 2]]]];
FFAlgSparseMatMul[graph, vnode, {lnode, wnode}, nrows, Length[items], nb, lrows[[All, All, 1]], ConstantArray[Range[nb], Length[items]]];
FFAlgSlice[graph, tnode, {vnode}, 1, nb^2];
FFAlgSlice[graph, dnode, {vnode}, nb^2 + 1];
(* T^-1 from the equations Sum_k T_ik M_k - ut_i = 0 in the unknowns {M_1.., ut_1..}: the M's are eliminated first, so
   they come out in terms of the ut's; ut's left dependent mean that T is singular. A dense solver: T has entries that
   vanish identically (an element with fewer integrals), which a sparse one must be told of in advance *)
mv = Table[mvar[k], {k, nb}];
FFAlgRatNumEval[graph, cnum, {-1, 0}];
FFAlgTake[graph, tsys, {tnode, cnum}, Flatten[Table[Join[Table[{1, (i - 1) nb + k}, {k, nb}], Table[{2, If[c == i, 1, 2]}, {c, nb}], {{2, 2}}], {i, nb}], 1]];
FFAlgNodeDenseSolver[graph, tinv, {tsys}, nb, Join[mv, uv], "NeededVars" -> mv];
FFSolverOnlyHomogeneous[graph, tinv];
FFGraphOutput[graph, tinv];
tlearn = FFDenseSolverLearn[graph, Join[mv, uv]];
If[! ListQ[tlearn] || Sort["IndepVars" /. tlearn] =!= Sort[uv] || Sort["DepVars" /. tlearn] =!= Sort[mv],
  fail["the basis elements are linearly dependent on the maximal cut (FiniteFlow): " <> ToString[tlearn, InputForm]]];
(* rows in the order of the masters, columns in the order ut[1], ut[2], ... *)
FFAlgTake[graph, tinvo, {tinv}, Flatten[Table[{1, (Position["DepVars" /. tlearn, mv[[r]]][[1, 1]] - 1) nb + Position["IndepVars" /. tlearn, uv[[c]]][[1, 1]]},
   {r, nb}, {c, nb}], 1]];
FFAlgMatMul[graph, de, {dnode, tinvo}, nrows - nb, nb, nb];
FFGraphOutput[graph, de];

If[mode === "line",
  (* rows of de: the derivatives of ut[1..n] in every invariant, then the corner integral; columns: ut[1..n].
     A constant matrix takes A_tt = Sum_X v_X A_X and the corner row out of them *)
  Module[{nm = nb, ni = Length[invariants], wt, llearn, lrec, lsol, kmin, kmax, rows, ser},
    wt = Table[Which[i <= nm && c <= ni nm && Mod[c - 1, nm] + 1 == i, pfline["v"][[Quotient[c - 1, nm] + 1]],
        i == nm + 1 && c == ni nm + 1, 1, True, 0], {i, nm + 1}, {c, ni nm + 1}];
    FFNewGraph[gline, lin, {eps, tt}];
    FFAlgRatFunEval[gline, lmap, {lin}, {eps, tt}, Join[{eps}, pfline["p0"] + tt pfline["v"]]];
    FFAlgSimpleSubgraph[gline, lsub, {lmap}, graph];
    FFAlgRatNumEval[gline, lwt, Flatten[wt]];
    FFAlgMatMul[gline, lout, {lwt, lsub}, nm + 1, ni nm + 1, nm];
    FFGraphOutput[gline, lout];
    FFNewGraph[glaur, tin, {tt}];
    FFAlgLaurent[glaur, laur, {tin}, gline, pfline["order"]];
    FFGraphOutput[glaur, laur];
    llearn = FFLaurentLearn[glaur];
    (* one variable: FFReconstructFunction would evaluate in one thread, FFParallelReconstructUnivariate uses them all *)
    lrec = FFParallelReconstructUnivariate[glaur, {tt}, "MaxPrimes" -> 200, "MaxDegree" -> 2000];
    If[! ListQ[lrec], fail["the reconstruction along the line failed: " <> ToString[Short[lrec], InputForm]]];
    lsol = FFLaurentSol[lrec, eps, llearn];
    (* columns in the order ut[1], ut[2], ... *)
    rows = ArrayReshape[lsol, {nm + 1, nm}];
    kmin = Min[0, Min[Cases[Flatten[rows], ser_SeriesData :> ser[[4]]]]];
    kmax = pfline["order"];
    Export["sysline.m", <|"kmin" -> kmin, "order" -> kmax, "masters" -> uv,
       "A" -> Table[Map[Together[SeriesCoefficient[#, k]] &, rows[[1 ;; nm]], {2}], {k, kmin, kmax}],
       "corner" -> Table[Together[SeriesCoefficient[#, k]] & /@ rows[[nm + 1]], {k, kmin, kmax}]|>];
    Export["sysinfo.m", <|"status" -> "ok", "mode" -> mode, "invariants" -> invariants, "masters" -> uv,
       "liteIBPInvariants" -> liteX, "coefficientEvaluator" -> evaluator|>];
    FFDeleteGraph[glaur]; FFDeleteGraph[gline]; FFDeleteGraph[graph]];
  finish[]];
FFAlgNonZeroes[graph, denz, {de}];
FFGraphOutput[graph, denz];
nzlearn = FFNonZeroesLearn[graph];

If[mode === "full",
  rec0 = FFReconstructFunction[graph, variables, "NThreads" -> Automatic],
  (* eps-only slice at a numeric point: the fallback when the full reconstruction takes too long *)
  FFNewGraph[graphslice];
  FFGraphInputVars[graphslice, epsin, {eps}];
  FFAlgRatFunEval[graphslice, subnode, {epsin}, {eps}, Join[{eps}, info["slicePoint"]]];
  FFAlgSimpleSubgraph[graphslice, slicecoeffs, {subnode}, graph];
  FFGraphOutput[graphslice, slicecoeffs];
  rec0 = FFReconstructFunction[graphslice, {eps}, "NThreads" -> Automatic, "MaxPrimes" -> 200, "MaxDegree" -> 200]];
rec = Normal[FFNonZeroesSol[rec0, nzlearn]];
deall = ArrayReshape[rec, {Length[invariants], nb, nb}];
Export["sys.m", deall];
Export["sysinfo.m", <|"status" -> "ok", "mode" -> mode, "invariants" -> invariants, "masters" -> uv,
   "slicePoint" -> If[mode === "full", None, info["slicePoint"]], "liteIBPInvariants" -> liteX, "coefficientEvaluator" -> evaluator|>];
finish[];
