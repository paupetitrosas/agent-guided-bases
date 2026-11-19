(* ::Package:: *)

(* ::Title:: *)
(*MaximalCutBasis`LeadingSingularities`: iterated residues, dlog conditions, pure combinations*)


(* ::Text:: *)
(*An ansatz integrand is carried as a list of terms {vec, P}: the integrand is (vec . c)/Sqrt[P] with*)
(*vec a list of rational functions (one per ansatz coefficient MCBc[i]) and P square free.  One variable*)
(*at a time:*)
(*  - Sqrt[P] quadratic in v: Euler substitution Sqrt[P_v] = Sqrt[a] (v + t);*)
(*  - Sqrt[P] linear in v: v = (t^2 - c0)/b;*)
(*  - Sqrt[P] of degree > 2 in v: that piece integrates to non-polylogarithmic functions, so it must*)
(*    vanish identically (conditions);*)
(*  - partial fractions in t PER INTEGRAND (Apart of each vec entry, merged by monic factor): polynomial*)
(*    parts and double poles give linear conditions; simple poles give residues, at quadratic factors*)
(*    alpha +- beta/Sqrt[Delta] (two terms, the second in a new square-root class).*)
(*At the end every term is (F . c)/Sqrt[K(kinematics)]: the leading singularities.*)


BeginPackage["MaximalCutBasis`LeadingSingularities`", {"MaximalCutBasis`", "SkillCore`Tools`", "SkillCore`Records`", "SkillCore`Pages`", "MaximalCutBasis`Family`",
   "MaximalCutBasis`Sectors`", "MaximalCutBasis`Baikov`", "MaximalCutBasis`CutIntegrands`"}];

MCBc::usage = "MCBc[i] is the i-th ansatz coefficient.";
MCBResidueStep::usage = "MCBResidueStep[{vec, P}, v, rest, n] integrates one variable v: returns {new terms, linear conditions on MCBc[1..n]}.";
MCBIteratedLS::usage = "MCBIteratedLS[vec, Pr, order] runs the residue steps in the variable order order. Returns {terms {F, K}, conditions}.";
MCBBestIteratedLS::usage = "MCBBestIteratedLS[vec, Pr, vars, tlim, pts] tries every variable order (<= 3 variables, else the order and its reverse) and keeps the one with the largest dlog space (ansatz dimension minus rank of the conditions at a random point). Returns {order, {terms, conditions}} or $Failed.";
MCBSqrtClass::usage = "MCBSqrtClass[K] is the canonical representative of the square class of K (numerical content and signs dropped).";
MCBSqFreeSplit::usage = "MCBSqFreeSplit[P] = {sq, rt} with P = rt^2 sq and sq square free.";
MCBLinearMatrix::usage = "MCBLinearMatrix[forms, cs] is the coefficient matrix of linear forms in cs.";
MCBBuildLSData::usage = "MCBBuildLSData[cs, conds, terms, pconds] groups the leading singularities by square-root class: <|\"cs\", \"C\" (conditions), \"P\" (purity), \"L\" -> <|class -> rows|>, \"classes\"|>.";
MCBAddNumeric::usage = "MCBAddNumeric[ld, pts] adds numeric copies of the matrices at the screening points.";
MCBScreenSubset::usage = "MCBScreenSubset[ld, sub, K, strict, pts] screens a subset of the ansatz numerically for combinations with constant leading singularities in class K (zero in the other classes). Returns candidate target vectors.";
MCBSolveSubset::usage = "MCBSolveSubset[ld, sub, K, strict, e] solves the subset exactly for the target vector e; returns the coefficient vector or $Failed.";
MCBSpanIntersection::usage = "MCBSpanIntersection[{W1, W2, ...}] intersects the row spans.";
MCBEpsPurityNumeric::usage = "MCBEpsPurityNumeric[pd, prefRat, vars, pts, mmax] gives, per point, the rows whose vanishing makes the integrand PrefRat Sum c_i eps^-k_i R_i independent of eps (integrand-level eps-purity, SKILL.md \"Purity\").";
MCBDlogBasisCrossCheck::usage = "MCBDlogBasisCrossCheck[cd, integrand] computes the leading singularities of an eps = 0 cut integrand with DlogBasis (optional, never decides anything).";
MCBElementPurity::usage = "MCBElementPurity[reps, cand] says whether a basis element (a candidate <|\"K\", \"r2\", \"rep\"|>) is eps-pure off the cut: whether its integrand with the rational part of the Gamma prefactor, PrefRat Sum c_i R_i(z, eps), is eps^m times a function free of eps: in the representations without cut variables that express its integrals when there are any (pure when one of them shows it; the test is exact there), else in the representation it was built in (\"rep\") when that one expresses them, else in the representations with the fewest cut variables that do (pure when one of them shows it): the split between prefactor and integrand depends on the representation, and the integration over more cut variables can bring an eps-dependence the integrand does not show. Checked exactly in eps at three random points of the cut variables and the invariants. Returns <|\"pure\" -> True | False | Missing[...], \"detail\" -> text|>; when it is not pure and the eps-dependence splits off, the detail names that factor (up to a number).";
MCBCandidatePurity::usage = "MCBCandidatePurity[reps, cands, opts] gives every candidate a purity verdict, \"pure\" (True, False or Missing[...]) and \"pureDetail\", for the search to order them (MCBOrderKey) and for basis.m (\"epsPure\"): a candidate with a verdict keeps it; any other gets MCBElementPurity's in the representations reps, except that one built eps-pure (\"strict\" -> True: dlog in d dimensions, or checked when it was built) is True, as built when its integrand does not show it, provided the Gamma prefactor of the representation it was built in (its \"rep\", in reps) is eps^m times a number; each within opts \"TimeLimit\" seconds (default 20) and all within \"Budget\" seconds (default Infinity; the ones left get Missing[\"Timeout\"]).";
MCBDlogBasisCheckCandidates::usage = "MCBDlogBasisCheckCandidates[reps, cands] (or [cd, cands]) checks each candidate in the representation it was built in, else in the first rational one that expresses its integrals. It runs MCBDlogBasisCrossCheck on the eps = 0 cut integrand (rational part Rz R0) of every candidate; returns a list of <|\"label\", \"LS\"|> (strings). Only for rational cuts with cut variables.";
MCBZeroConditions::usage = "MCBZeroConditions[expr, vars] are the conditions for expr to vanish identically in vars.";

Begin["`Private`"];


MCBSqFreeSplit[P_] := Module[{fl = FactorList[P], sq = 1, rt = 1},
  Do[If[OddQ[f[[2]]], sq *= f[[1]]]; rt *= f[[1]]^Quotient[f[[2]], 2], {f, fl}];
  {sq, rt}];

MCBZeroConditions[expr_, vs_List] := Module[{num = Numerator[Together[expr]]},
  Which[num === 0, {}, vs === {}, {num}, True, DeleteCases[Flatten[{CoefficientList[Expand[num], vs]}], 0]]];

monicIn[f_, t_] := Together[f/Coefficient[f, t, Exponent[f, t]]];

(* rho = poly + Sum a/f^k with f monic irreducible, deg a < deg f *)
partialFractionData[rho_, t_] := Module[{ap, terms, poly = 0, out = {}, num, den, fl, tf, pw},
  If[rho === 0, Return[{0, {}}]];
  ap = Apart[Together[rho], t];
  terms = If[Head[ap] === Plus, List @@ ap, {ap}];
  Do[
    num = Numerator[Together[tm]]; den = Denominator[Together[tm]];
    fl = Select[FactorList[den], ! FreeQ[#[[1]], t] &];
    Which[
      fl === {}, poly += tm,
      Length[fl] == 1,
        tf = fl[[1, 1]]; pw = fl[[1, 2]];
        AppendTo[out, {monicIn[tf, t], pw, Together[tm monicIn[tf, t]^pw]}],
      True,
        Module[{sub = partialFractionData[Apart[tm, t], t]}, poly += sub[[1]]; out = Join[out, sub[[2]]]]],
    {tm, terms}];
  {poly, out}];

MCBResidueStep[{vec_, P_}, v_, rest_List, n_Integer] := Module[{Pv = 1, Prest = 1, fl, sq, rt, a, bb, cc, vt, dvt, rhos, pfd, t, vs,
    conds = {}, terms = {}, groups, sub, f1, f0, Delta, a1, a0, al, be, s2, r2},
  vs = Join[{t}, rest];
  fl = FactorList[P];
  Do[If[FreeQ[ff[[1]], v], Prest *= ff[[1]]^ff[[2]], Pv *= ff[[1]]^ff[[2]]], {ff, fl}];
  Switch[Exponent[Pv, v],
    0, rhos = (# /. v -> t) & /@ vec; sq = Prest,
    1, vt = (t^2 - Coefficient[Pv, v, 0])/Coefficient[Pv, v, 1];
       rhos = Together[(# /. v -> vt) 2/Coefficient[Pv, v, 1]] & /@ vec; sq = Prest,
    2, a = Coefficient[Pv, v, 2]; bb = Coefficient[Pv, v, 1]/a; cc = Coefficient[Pv, v, 0]/a;
       vt = (t^2 - cc)/(bb - 2 t); dvt = Together[D[vt, t]];
       {sq, rt} = MCBSqFreeSplit[Factor[a]];
       Module[{s3, r3}, {s3, r3} = MCBSqFreeSplit[Factor[sq Prest]];
         rhos = Together[(# /. v -> vt) dvt/(rt r3 (vt + t))] & /@ vec; sq = s3],
    _, Return[{{}, MCBZeroConditions[Sum[MCBc[i] vec[[i]], {i, n}], Join[{v}, rest]]}]];
  pfd = partialFractionData[#, t] & /@ rhos;
  conds = Join[conds, MCBZeroConditions[Sum[MCBc[i] pfd[[i, 1]], {i, n}], vs]];
  groups = GroupBy[Flatten[Table[{#[[1]], #[[2]], i, #[[3]]} & /@ pfd[[i, 2]], {i, n}], 1], {#[[1]], #[[2]]} &];
  Do[
    With[{f = key[[1]], kk = key[[2]], ent = groups[key]},
      If[kk >= 2,
        conds = Join[conds, MCBZeroConditions[Sum[MCBc[e[[3]]] e[[4]], {e, ent}], vs]],
        Switch[Exponent[f, t],
          1, sub = ConstantArray[0, n]; Do[sub[[e[[3]]]] += Together[e[[4]]], {e, ent}];
             AppendTo[terms, {sub, sq}],
          2, f1 = Coefficient[f, t, 1]; f0 = Coefficient[f, t, 0];
             Delta = Factor[f1^2 - 4 f0];
             al = ConstantArray[0, n]; be = ConstantArray[0, n];
             Do[a1 = Together[Coefficient[Numerator[Together[e[[4]]]], t, 1]/Denominator[Together[e[[4]]]]];
                a0 = Together[Coefficient[Numerator[Together[e[[4]]]], t, 0]/Denominator[Together[e[[4]]]]];
                (* residue at the roots of f: a1/2 +- (a0 - a1 f1/2)/Sqrt[Delta] *)
                al[[e[[3]]]] += Together[a1/2];
                be[[e[[3]]]] += Together[a0 - a1 f1/2], {e, ent}];
             AppendTo[terms, {al, sq}];
             {s2, r2} = MCBSqFreeSplit[Factor[Delta sq]];
             AppendTo[terms, {Together[be r2 s2/(Delta sq)], s2}],
          _, conds = Join[conds, MCBZeroConditions[Sum[MCBc[e[[3]]] e[[4]], {e, ent}], vs]]]]],
    {key, Keys[groups]}];
  {Select[terms, ! AllTrue[#[[1]], # === 0 &] &], conds}];

MCBIteratedLS[vec0_List, P0_, order_List] := Module[{n = Length[vec0], terms = {{Together /@ vec0, P0}}, conds = {}, res, new},
  Do[
    new = {};
    Do[res = MCBResidueStep[tm, order[[iv]], order[[iv + 1 ;;]], n];
       If[res === $Failed, Return[$Failed, Module]];
       new = Join[new, res[[1]]]; conds = Join[conds, res[[2]]], {tm, terms}];
    terms = new, {iv, Length[order]}];
  {terms, DeleteDuplicates[conds]}];

MCBBestIteratedLS[vec0_List, P0_, vars_List, tlim_ : 300, pts_List : {}] := Module[{best = $Failed, bestScore = {-1, 0}, r, ords, n = Length[vec0], sc, cm, pt},
  pt = If[pts === {}, {}, pts[[Min[2, Length[pts]]]]];
  ords = If[Length[vars] <= 3, Permutations[vars], {vars, Reverse[vars]}];
  Do[r = TimeConstrained[MCBIteratedLS[vec0, P0, o], tlim, $Failed];
     If[r =!= $Failed,
       cm = If[r[[2]] === {}, {}, MCBLinearMatrix[r[[2]], MCBc /@ Range[n]] /. pt];
       sc = {n - If[cm === {}, 0, MatrixRank[cm]], -Length[r[[1]]]};
       If[sc[[1]] > bestScore[[1]] || (sc[[1]] == bestScore[[1]] && sc[[2]] > bestScore[[2]]), bestScore = sc; best = {o, r}]],
    {o, ords}];
  best];


(* ::Section:: *)
(*Square-root classes and pure combinations*)


canonSign[f_] := Module[{cr = CoefficientRules[f, Variables[f]]}, If[cr =!= {} && TrueQ[Negative[cr[[1, 2]]]], -f, f]];

MCBSqrtClass[K_] := Module[{fl = FactorList[Factor[K]]},
  Times @@ (canonSign[#[[1]]] & /@ Select[fl, OddQ[#[[2]]] && ! NumericQ[#[[1]]] &])];

MCBLinearMatrix[forms_List, cs_List] := If[forms === {}, {}, Table[Together[Coefficient[f, cc]], {f, forms}, {cc, cs}]];

MCBBuildLSData[cs_List, conds_List, terms_List, pconds_List] := Module[{cls, byK},
  cls = DeleteDuplicates[MCBSqrtClass[#[[2]]] & /@ terms];
  byK = Association@Table[K -> MCBLinearMatrix[
        Table[With[{r = PowerExpand[Sqrt[Factor[Together[tm[[2]]/K]]]]}, Together[tm[[1]]/r]], {tm, Select[terms, MCBSqrtClass[#[[2]]] === K &]}], cs],
      {K, cls}];
  <|"cs" -> cs, "C" -> MCBLinearMatrix[conds, cs], "P" -> MCBLinearMatrix[pconds, cs], "L" -> byK, "classes" -> cls|>];

numAt[M_, pt_] := If[M === {}, {}, M /. pt];

MCBSpanIntersection[Ws_List] := Module[{basis = Ws[[1]], ns, k},
  Do[
    If[basis === {} || Ws[[i]] === {}, Return[{}, Module]];
    k = Length[basis];
    ns = NullSpace[Transpose[Join[basis, -Ws[[i]]]]];
    basis = If[ns === {}, {}, RowReduce[(#[[1 ;; k]] . basis) & /@ ns]];
    basis = DeleteCases[basis, vv_ /; AllTrue[vv, # == 0 &]],
    {i, 2, Length[Ws]}];
  basis];

MCBAddNumeric[ld_Association, pts_List] := Join[ld, <|"pts" -> pts,
   "Cnum" -> Table[numAt[ld["C"], pt], {pt, pts}],
   "Lnum" -> Association[Table[K -> Table[numAt[ld["L"][K], pt], {pt, pts}], {K, ld["classes"]}]]|>];

MCBScreenSubset[ld0_Association, sub_List, K_, strict_, pts_List] := Module[{ld = ld0, Ws, A, V, LK, others, ip = 0},
  If[! KeyExistsQ[ld, "Cnum"], ld = MCBAddNumeric[ld, pts]];
  others = DeleteCases[ld["classes"], K];
  Ws = Table[ip++;
     A = Join[ld["Cnum"][[ip]], If[strict, If[KeyExistsQ[ld, "Pnum"], ld["Pnum"][[ip]], numAt[ld["P"], pt]], {}], Join @@ (ld["Lnum"][#][[ip]] & /@ others)];
     A = If[A === {}, {}, A[[All, sub]]];
     V = If[A === {}, IdentityMatrix[Length[sub]], NullSpace[A]];
     If[V === {}, Return[{}, Module]];
     LK = ld["Lnum"][K][[ip]][[All, sub]];
     DeleteCases[RowReduce[(LK . #) & /@ V], vv_ /; AllTrue[vv, # == 0 &]],
     {pt, pts}];
  If[MemberQ[Ws, {}], {}, MCBSpanIntersection[Ws]]];

MCBSolveSubset[ld_Association, sub_List, K_, strict_, e_List] := Module[{cs = ld["cs"][[sub]], A, others, eqs, sol, vec},
  others = DeleteCases[ld["classes"], K];
  A = Join[ld["C"], If[strict && ! KeyExistsQ[ld, "Pnum"], ld["P"], {}], Join @@ (ld["L"][#] & /@ others)];
  eqs = Join[If[A === {}, {}, Thread[A[[All, sub]] . cs == 0]], Thread[ld["L"][K][[All, sub]] . cs == e]];
  sol = Quiet@Solve[eqs, cs];
  If[sol === {}, Return[$Failed]];
  vec = Together[cs /. First[sol] /. (Alternatives @@ cs) -> 0];
  (* strict: check the integrand-level eps-purity at the first screening point *)
  If[strict && KeyExistsQ[ld, "Pnum"],
    If[! AllTrue[Flatten[ld["Pnum"][[1]][[All, sub]] . (vec /. ld["pts"][[1]])], # === 0 &], Return[$Failed]]];
  vec];

MCBEpsPurityNumeric[pd_List, prat_, vars_List, pts_List, mmax_ : 5] := Module[{zpts},
  zpts = BlockRandom[If[vars === {}, {{}}, Table[Thread[vars -> Table[RandomChoice[{-1, 1}] Prime[RandomInteger[{12, 60}]]/Prime[RandomInteger[{3, 11}]], Length[vars]]], {Length[pd] + 6}]], RandomSeeding -> 17];
  Table[
    Module[{cols},
      (* Normal, then Coefficient: an integrand free of eps has a plain expression as its Series, on which
         SeriesCoefficient[ser, m] stays unevaluated (no message) and reads as nonzero, so it never counted as strict *)
      cols = Table[Module[{ser = Normal[Series[Together[(prat eps^(-p0["k"]) p0["R"]) /. pt], {eps, 0, mmax}]]},
          Flatten@Table[Quiet@Check[Together[Coefficient[ser, eps, m] /. zp], 0], {m, 1, mmax}, {zp, zpts}]], {p0, pd}];
      Transpose[cols]],
    {pt, pts}]];


(* ::Section:: *)
(*Optional cross-check with DlogBasis*)


MCBDlogBasisCrossCheck[cd_Association, integrand_] := Module[{vars = cd["vars"], r},
  If[MCBSkippedQ["dlogbasis-crosscheck"], Return["skipped by user"]];
  If[! MCBLoadTool["DlogBasis"], Return[Missing["DlogBasisNotAvailable"]]];
  If[vars === {}, Return[{integrand}]];
  r = Quiet@Block[{Print = (Null &)}, TimeConstrained[MCBQualify["DlogBasis", "LeadingSingularities"][integrand, vars], 300, $Failed]];
  If[r =!= $Failed, MCBMarkToolUsed["DlogBasis"]];   (* a use when it gave a result, not on loading or a timeout *)
  r];


(* each candidate in its own representation (the one it was built in, "rep" -> {order, isp, kind}); otherwise the first
   rational representation in which every integral of the candidate has a cut integrand. A candidate that none of them
   expresses is reported as not checked, never with integrals set to zero *)
MCBDlogBasisCheckCandidates[cd_Association, cands_List] := MCBDlogBasisCheckCandidates[{cd}, cands];
MCBDlogBasisCheckCandidates[reps0_List, cands_List] := Module[{out = {}, reps = DeleteDuplicatesBy[Select[reps0, AssociationQ[#] && #["vars"] =!= {} && #["split"]["Pr"] === 1 &], #["id"] &]},
  If[reps === {} || ! MCBAvailableQ["DlogBasis"] || MCBSkippedQ["dlogbasis-crosscheck"], Return[{}]];
  Do[Module[{cs = MCBCoefficients[c["K"]], ints, cd, r, le, ls},
      ints = Keys[cs];
      (* the cross-check is symbolic in the invariants: an element with large coefficients would spend its whole time
         limit expanding them *)
      If[AnyTrue[Values[cs], MCBLargeQ],
        AppendTo[out, <|"label" -> Lookup[c, "label", ""], "LS" -> "not checked: large coefficients (the cross-check is symbolic)", "normalisation" -> "-"|>];
        Continue[]];
      (* its own representation first, then the others in their order *)
      cd = SelectFirst[ownFirst[reps, c],
        Function[rp, FreeQ[MCBCutIntegrand[rp, #] & /@ ints, $Failed]], None];
      If[cd === None,
        AppendTo[out, <|"label" -> Lookup[c, "label", ""], "LS" -> "not checked: no rational representation expresses all its integrals", "normalisation" -> "-"|>],
        r = Total[(cs[#] MCBCutIntegrand[cd, #]) & /@ ints];
        le = MCBLeadingEps[Collect[Expand[r], eps, Together]];
        ls = If[le[[1]] === Infinity, "vanishes on the cut", MCBDlogBasisCrossCheck[cd, Together[cd["split"]["Rz"] le[[2]]]]];
        AppendTo[out, <|"label" -> Lookup[c, "label", ""], "LS" -> With[{t = ToString[ls, InputForm]}, If[StringLength[t] > 300, StringTake[t, 300] <> " ...", t]],
          "normalisation" -> ToString[Sqrt[c["r2"]] cd["split"]["kinNorm"], InputForm]|>]]],
    {c, cands}];
  out];


(* Purity (SKILL.md): an element whose integrand, Gamma prefactor included, is eps-pure is likely uniform-weight off the
   cut as well. The DE on the cut cannot tell (any eps-dependent factor that does not depend on the kinematics leaves a
   one-master DE as it is), so the pages show it element by element. *)
epsPower[v_] := Module[{t = Together[v], k},
  If[t === 0, Return[Missing["Zero"]]];
  k = Exponent[Numerator[t], eps] - Exponent[Denominator[t], eps];
  If[NumericQ[Together[t/eps^k]], k, Missing["NotMonomial"]]];

dropConstants[f_] := Module[{t = Factor[Together[f]], parts},
  parts = If[Head[t] === Times, List @@ t, {t}];
  Times @@ Select[parts, ! NumericQ[#] && ! MatchQ[#, eps | eps^_] &]];

(* The split between the Gamma prefactor and the integrand depends on the representation: the same element can be pure
   in the representation it was built in and not in another (seen in a three-line sector). The test says something
   only where the integration over the cut variables keeps the weight: the integrand of an undotted massless bubble
   looks eps-pure in a representation with two cut variables, whose integration brings the 1/(1 - 2 eps) that its own,
   with none, shows in the prefactor. Without cut variables nothing is integrated and the test is exact, so those
   representations decide first, pure when one of them shows it; then the element's own representation (a dlog
   candidate is dlog there), when it expresses the element; then the representations with the fewest cut variables,
   pure when one of them shows it. *)
MCBElementPurity[reps0_List, c_Association] := Module[{reps = DeleteDuplicatesBy[Select[reps0, AssociationQ], #["id"] &], ints, cds, judge, res,
    own = Lookup[c, "rep", None], nv},
  ints = JIntegrals[c["K"]];
  cds = Select[ownFirst[reps, c], Function[rp, FreeQ[MCBCutIntegrand[rp, #] & /@ ints, $Failed]]];
  If[cds === {}, Return[<|"pure" -> Missing["NotChecked"], "detail" -> "not checked: no representation expresses all its integrals"|>]];
  nv[rp_] := Length[Lookup[rp, "vars", {}]];
  judge = Which[AnyTrue[cds, nv[#] == 0 &], Select[cds, nv[#] == 0 &],
    own =!= None && {cds[[1]]["order"], cds[[1]]["isp"], cds[[1]]["kind"]} === own, {First[cds]},
    True, Select[cds, nv[#] == Min[nv /@ cds] &]];
  res = {};
  Do[AppendTo[res, purityIn[cd, c]]; If[TrueQ[Last[res]["pure"]], Break[]], {cd, judge}];
  SelectFirst[res, TrueQ[#["pure"]] &, First[res]]];

(* A candidate built eps-pure keeps that verdict: a d-dimensional dlog candidate made exact modulo total derivatives
   (MCBProjectedPurifyCandidates) is pure as an integral, but its integrand need not be eps-pure, so MCBElementPurity
   could call it impure. The d-dimensional builders make Rz Sum c_i R_i free of eps without the Gamma prefactor, so
   "strict" counts as built eps-pure only when the prefactor of the representation it was built in is eps^m times a
   number: under 2/(1 - 2 eps) the candidate is not pure, and MCBElementPurity's False, which names the factor, stands.
   Its integrand is checked all the same, for the detail; only when that does not show it pure does the verdict say
   "as built". A verdict is never computed twice: the search and the record read the same one. *)
asBuilt[c_Association] := "eps-pure as built (" <> StringRiffle[Select[{Lookup[c, "label", ""], Lookup[c, "provenance", ""]}, StringQ[#] && # =!= "" &], "; "] <> ")";
builtPure[reps_List, c_Association] := TrueQ[Lookup[c, "strict", False]] &&
  With[{own = SelectFirst[reps, AssociationQ[#] && {Lookup[#, "order", None], Lookup[#, "isp", None], Lookup[#, "kind", None]} === Lookup[c, "rep", None] &, None]},
    AssociationQ[own] && KeyExistsQ[own, "prefRat"] && IntegerQ[epsPower[own["prefRat"]]]];
MCBCandidatePurity[reps_List, cands_List, opts_Association : <||>] := Module[{t0 = AbsoluteTime[], tl = Lookup[opts, "TimeLimit", 20], budget = Lookup[opts, "Budget", Infinity], built, p},
  Map[Function[c, built = builtPure[reps, c]; Which[
      KeyExistsQ[c, "pure"], c,
      AbsoluteTime[] - t0 > budget, Join[c, If[built, <|"pure" -> True, "pureDetail" -> asBuilt[c]|>,
        <|"pure" -> Missing["Timeout"], "pureDetail" -> "not checked: the time for the purity checks was used up"|>]],
      True,
        p = Quiet@TimeConstrained[MCBElementPurity[reps, c], tl, <|"pure" -> Missing["Timeout"], "detail" -> "not checked: timed out"|>];
        If[! AssociationQ[p] || ! KeyExistsQ[p, "pure"], p = <|"pure" -> Missing["Failed"], "detail" -> "not checked: the purity check failed"|>];
        Join[c, If[built && ! TrueQ[p["pure"]], <|"pure" -> True, "pureDetail" -> asBuilt[c]|>, <|"pure" -> p["pure"], "pureDetail" -> Lookup[p, "detail", ""]|>]]]], cands]];

(* its own representation (the one it was built in) first, then the others in their order *)
ownFirst[reps_List, c_Association] := With[{own = Lookup[c, "rep", None]},
  Join[Select[reps, {#["order"], #["isp"], #["kind"]} === own &], Select[reps, {#["order"], #["isp"], #["kind"]} =!= own &]]];

(* the coefficients as written (MCBCoefficients): only their values at the sample points are needed *)
purityIn[cd_Association, c_Association] := Module[{cs = MCBCoefficients[c["K"]], ints, T, pts, vals, ks, where},
  ints = Keys[cs];
  where = " (in " <> cd["kind"] <> " " <> ToString[cd["order"]] <> " ISPs " <> ToString[cd["isp"]] <> ")";
  T = cd["prefRat"] Total[(cs[#] MCBCutIntegrand[cd, #]) & /@ ints];
  pts = BlockRandom[Table[Thread[Join[cd["invariants"], cd["vars"]] ->
       Table[RandomChoice[{-1, 1}] Prime[RandomInteger[{5, 40}]]/Prime[RandomInteger[{2, 12}]], Length[cd["invariants"]] + Length[cd["vars"]]]], {3}],
     RandomSeeding -> 23];
  vals = Select[Quiet[Together[T /. #] & /@ pts], FreeQ[#, Indeterminate | ComplexInfinity | DirectedInfinity] && # =!= 0 &];
  If[vals === {}, Return[<|"pure" -> Missing["NotChecked"], "detail" -> "not checked: its cut integrand vanishes at the sample points" <> where|>]];
  ks = epsPower /@ vals;
  Which[
    AllTrue[ks, IntegerQ] && Equal @@ ks,
      <|"pure" -> True, "detail" -> "eps-pure off the cut: Gamma prefactor x integrand = eps^" <> ToString[First[ks]] <> " x (free of eps)" <> where|>,
    AllTrue[Rest[vals], FreeQ[Together[#/First[vals]], eps] &],
      <|"pure" -> False, "detail" -> "not eps-pure off the cut: Gamma prefactor x integrand carries " <> ToString[dropConstants[First[vals]], InputForm] <>
         " (up to a number and a power of eps)" <> where|>,
    True, <|"pure" -> False, "detail" -> "not eps-pure off the cut: its eps-dependence changes over the cut" <> where|>]];

End[];
EndPackage[];
