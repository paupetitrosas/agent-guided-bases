(* ::Package:: *)

(* ::Title:: *)
(*MaximalCutBasis`Candidates`: dlog / curve / single-integral candidate routes*)


BeginPackage["MaximalCutBasis`Candidates`", {"MaximalCutBasis`", "SkillCore`Tools`", "SkillCore`Records`", "SkillCore`Pages`", "MaximalCutBasis`Family`",
   "MaximalCutBasis`Sectors`", "MaximalCutBasis`Derivatives`", "MaximalCutBasis`Kira`", "MaximalCutBasis`Baikov`",
   "MaximalCutBasis`CutIntegrands`", "MaximalCutBasis`LeadingSingularities`", "MaximalCutBasis`Curves`",
   "MaximalCutBasis`DECheck`"}];

$MCBDefaultOptions::usage = "$MCBDefaultOptions are the default pool and search options: nd (numerator degree), nt (extra dots), w (total weight), maxsize (subset size), enough, global (whole-pool solve), nreps, tlim (time limit of one candidate search, of which the leading singularities get half), budget (MCBAutoPass only: time budget of all its searches for one sector, Infinity by default), maxpool (cap per number of cut variables), Standard (MCBAutoPass only: whether to build the standard Baikov representation, MCBRepresentations; Automatic only when it has at most $MCBMaxStandardVars cut variables or nothing else exists).";
MCBDlogCandidates::usage = "MCBDlogCandidates[fam, sector, cd, opts] builds the pool, its cut integrands, the leading singularities (MCBBestIteratedLS) and the combinations with constant leading singularities. Returns <|\"status\", \"candidates\", \"npool\", \"terms\", \"conds\", \"order\"|>.";
MCBCurveCandidates::usage = "MCBCurveCandidates[fam, sector, cd, opts] builds candidates for a one-variable curve cut: pool combinations matching each curve target (first, second, third kind), single pool integrals labelled by their reduced differential, and d/dX J1, d/dX J1/eps of the first-kind candidate.";
MCBSingleCandidates::usage = "MCBSingleCandidates[fam, sector, cd, opts] returns simple single pool integrals (labels only), for non-polylogarithmic multi-variable cuts.";
MCBScreenPoints::usage = "MCBScreenPoints[fam] are the kinematic points used to screen leading singularities numerically.";
MCBStrictTargetCandidates::usage = "MCBStrictTargetCandidates[fam, sector, cd, opts] returns candidates that are dlog in d dimensions on a one-variable cut with a root of degree <= 2: combinations Sum c_i(eps) j_i, with coefficients rational in eps and the kinematics, whose cut integrand is exactly a dlog form of the cut (MCBCurveTargets, plus d log g and Sqrt[disc] dz/g at quadratic factors g on a rational cut) times the twist.";
MCBPurifyCandidates::usage = "MCBPurifyCandidates[fam, sector, cd, cands, opts] makes candidates that are dlog at eps = 0 exact in eps: c(eps) K + Sum d_k(eps) j_k whose cut integrand (all orders in eps) equals the eps = 0 dlog form of K. Works with any number of cut variables.";
MCBProjectedCandidates::usage = "MCBProjectedCandidates[fam, sector, cd, opts] writes the dlog targets of a one-variable cut with a root of degree <= 2 (those of MCBStrictTargetCandidates) as combinations of pool integrals modulo total derivatives: no pool integral has to match a target exactly. Coefficients are rational in eps and the kinematics (FiniteFlow reconstructs them when it is available).";
MCBProjectedPurifyCandidates::usage = "MCBProjectedPurifyCandidates[fam, sector, cd, cands, opts] writes the eps = 0 cut integrand of each dlog candidate (made in the representation cd) as a combination of pool integrals modulo total derivatives, in any number of cut variables: the dlog candidates made exact in eps where MCBPurifyCandidates needs an exact match. Needs FiniteFlow.";

Begin["`Private`"];


$MCBDefaultOptions = <|"nd" -> 2, "nt" -> 2, "w" -> 3, "maxsize" -> 2, "enough" -> 30, "global" -> True, "nreps" -> 3,
   "tlim" -> 600, "budget" -> Infinity, "maxpool" -> {30, 22, 16, 12}, "nmi" -> 1, "Standard" -> Automatic|>;

MCBScreenPoints[fam_Association] := MCBPoints[fam, 6, 3];

poolFor[fam_, s_, cd_, opts_, extraCap_ : 0] := Module[{cap},
  cap = opts["maxpool"][[Min[Length[cd["vars"]] + 1, Length[opts["maxpool"]]]]] + extraCap;
  MCBSectorPool[fam, s, cd["isp"], <|"nd" -> opts["nd"], "nt" -> opts["nt"], "w" -> opts["w"], "cap" -> cap, "nmi" -> opts["nmi"]|>]];

repTag[cd_] := {cd["order"], cd["isp"], cd["kind"]};

(* the overall number of a normalisation (Baikov's 1/16, signs, phases) cannot change the eps structure: drop it,
   so that the basis carries no stray constants *)
dropNumber[e_] := Module[{t = Factor[Together[e]], c},
  c = Times @@ Select[If[Head[t] === Times, List @@ t, {t}], NumericQ];
  If[c === 0, t, Factor[Together[t/c]]]];

MCBDlogCandidates[fam_Association, s_List, cd_Association, opts0_Association : <||>] := Module[{opts = Join[$MCBDefaultOptions, opts0], st = cd["split"],
    prat = cd["prefRat"], pool, pf, cs, ls, terms, conds, pnum, out = {}, mk, ld, es, pts = MCBScreenPoints[fam], vec},
  pool = poolFor[fam, s, cd, opts];
  pf = MCBPoolData[cd, pool];
  If[pf === {}, Return[<|"status" -> "empty-pool", "candidates" -> {}|>]];
  cs = MCBc /@ Range[Length[pf]];
  vec = Together[st["Rz"] #["R0"]] & /@ pf;
  ls = If[cd["vars"] === {}, {{}, {{{vec . cs, st["Pr"]}}, {}}},
     With[{r = MCBBestIteratedLS[vec, st["Pr"], cd["vars"], opts["tlim"]/2, pts]},
       If[r === $Failed, $Failed, {r[[1]], {{#[[1]] . cs, #[[2]]} & /@ r[[2, 1]], r[[2, 2]]}}]]];
  If[ls === $Failed, Return[<|"status" -> "LS-failed", "candidates" -> {}, "npool" -> Length[pf]|>]];
  {terms, conds} = ls[[2]];
  pnum = MCBEpsPurityNumeric[pf, prat, cd["vars"], pts[[1 ;; 4]]];
  mk[sol_, K_, strict_] := Module[{cmb},
    cmb = Collect[Sum[sol[[i]] eps^(-pf[[i]]["k"]) pf[[i]]["j"], {i, Length[pf]}], _j, Together];
    <|"r2" -> dropNumber[K/st["kinNorm"]^2], "K" -> cmb, "strict" -> strict, "weight" -> ComboWeight[cmb, s],
      "label" -> "dlog" <> If[K === 1, "", ", LS class Sqrt[" <> ToString[K, InputForm] <> "]"], "provenance" -> "auto", "priority" -> 5,
      "rep" -> repTag[cd]|>];
  ld = MCBAddNumeric[Join[MCBBuildLSData[cs, conds, terms, {}], <|"Pnum" -> pnum|>], pts[[1 ;; 4]]];
  Do[
    Do[
      Do[
        Do[
          es = MCBScreenSubset[ld, sub, K, strict, pts[[1 ;; 4]]];
          Do[With[{sol = MCBSolveSubset[ld, sub, K, strict, e]},
               If[sol =!= $Failed && ! AllTrue[sol, # === 0 &],
                 AppendTo[out, mk[Normal[SparseArray[Thread[sub -> sol], Length[cs]]], K, strict]]]], {e, es}];
          If[es =!= {}, Break[]],
          {strict, {True, False}}],
        {K, ld["classes"]}],
      {sub, Subsets[Range[Length[pf]], {size}]}];
    If[Length[out] >= opts["enough"], Break[]],
    {size, 1, opts["maxsize"]}];
  If[TrueQ[opts["global"]] && Length[out] < 2 opts["nmi"] + 2,
    Do[
      es = MCBScreenSubset[ld, Range[Length[pf]], K, strict, pts[[1 ;; 4]]];
      Do[With[{sol = MCBSolveSubset[ld, Range[Length[pf]], K, strict, e]},
           If[sol =!= $Failed && ! AllTrue[sol, # === 0 &], AppendTo[out, mk[sol, K, strict]]]], {e, es}],
      {K, ld["classes"]}, {strict, {True, False}}]];
  <|"status" -> "ok", "route" -> "dlog", "npool" -> Length[pf], "terms" -> terms, "conds" -> conds, "order" -> ls[[1]],
    "candidates" -> DeleteDuplicatesBy[out, {#["K"], #["r2"]} &]|>];

MCBCurveCandidates[fam_Association, s_List, cd_Association, opts0_Association : <||>] := Module[{opts = Join[$MCBDefaultOptions, opts0], st = cd["split"],
    pool, pf, cs, v, forms, out = {}, mk, j1, pts = MCBScreenPoints[fam], tg, pr, nP, coords, gs, dim, M, subsAll, consistentQ, nfound, tgt, sol, labels, norms},
  v = First[cd["vars"]];
  pool = poolFor[fam, s, cd, opts, 6];
  pf = MCBPoolData[cd, pool];
  If[pf === {}, Return[<|"status" -> "empty-pool", "candidates" -> {}|>]];
  cs = MCBc /@ Range[Length[pf]];
  forms = Together[st["Rz"] #["R0"]] & /@ pf;
  mk[vec_, lab_] := <|"r2" -> dropNumber[1/st["kinNorm"]^2],
     "K" -> Collect[Sum[vec[[i]] eps^(-pf[[i]]["k"]) pf[[i]]["j"], {i, Length[pf]}], _j, Together],
     "strict" -> False, "weight" -> ComboWeight[Sum[vec[[i]] pf[[i]]["j"], {i, Length[pf]}], s], "label" -> lab,
     "provenance" -> "auto", "priority" -> 5, "rep" -> repTag[cd]|>;
  tg = MCBCurveTargets[cd];
  pr = st["Pr"]; nP = Exponent[pr, v];
  coords = MCBCurveCoordinates[#, pr, v] & /@ forms;
  If[MemberQ[coords, $Failed], coords = {}];
  gs = Lookup[Select[tg, KeyExistsQ[#, "puncture"] &], "puncture", {}];
  If[coords =!= {},
    (* rows: coordinates on {z^k dz/y} and the third kind at the linear punctures; columns: pool integrals *)
    M = Transpose[Together[Table[Join[co[[1]], Table[Lookup[Association[Rule @@@ co[[2]]], g, 0], {g, gs}]], {co, coords}]]];
    dim = Length[M];
    labels = Take[tg[[All, "label"]], UpTo[dim]]; norms = Take[tg[[All, "norm"]], UpTo[dim]];
    subsAll = Join[Subsets[Range[Length[pf]], {1}], Subsets[Range[Min[Length[pf], 18]], {2}]];
    consistentQ[sub_, rhs_] := AllTrue[pts[[1 ;; 2]], Function[pt,
        Module[{A = M[[All, sub]] /. pt, bb = rhs /. pt}, MatrixRank[A] == MatrixRank[Join[A, List /@ bb, 2]]]]];
    Do[
      tgt = UnitVector[dim, it]; nfound = 0;
      Do[
        If[consistentQ[sub, tgt],
          sol = Quiet@Solve[Thread[M[[All, sub]] . cs[[sub]] - tgt == 0], cs[[sub]]];
          If[sol =!= {},
            With[{vec = Normal[SparseArray[Thread[sub -> Together[cs[[sub]] /. First[sol] /. (Alternatives @@ cs) -> 0]], Length[cs]]]},
              AppendTo[out, Join[mk[vec, labels[[it]]], <|"r2" -> dropNumber[norms[[it]]/st["kinNorm"]^2], "priority" -> If[it == 1, 0, 5]|>]]];
            nfound++; If[nfound >= 2, Break[]]]],
        {sub, subsAll}],
      {it, Min[dim, Length[labels]]}]];
  Do[AppendTo[out, <|"r2" -> dropNumber[1/st["kinNorm"]^2], "K" -> eps^(-pf[[i]]["k"]) pf[[i]]["j"], "strict" -> False,
       "weight" -> ComboWeight[pf[[i]]["j"], s], "label" -> "(" <> ToString[Factor[forms[[i]]], InputForm] <> ") dz/y",
       "provenance" -> "auto", "priority" -> 5, "rep" -> repTag[cd]|>],
    {i, Min[Length[pf], 20]}];
  j1 = SelectFirst[out, StringStartsQ[#["label"], "dz/y"] &];
  (* derivatives of the first-kind integral only matter on curves of genus >= 1 (they bring in the second-kind
     forms); on a genus-0 cut dz/y is already a dlog form, and the symbolic derivatives can be expensive *)
  If[! MissingQ[j1] && Exponent[pr, v] >= 3,
    Do[With[{dk = Collect[DropOffCut[s][MCBDerivExpr[fam, j1["K"], X]], _j, Together]},
       If[dk =!= 0,
         AppendTo[out, <|"r2" -> j1["r2"], "K" -> dk, "strict" -> False, "weight" -> ComboWeight[dk, s], "label" -> "d/d" <> ToString[X] <> " J1", "provenance" -> "auto", "priority" -> 5|>];
         AppendTo[out, <|"r2" -> j1["r2"], "K" -> Collect[dk/eps, _j, Together], "strict" -> False, "weight" -> ComboWeight[dk, s], "label" -> "d/d" <> ToString[X] <> " J1 / eps", "provenance" -> "auto", "priority" -> 5|>]]],
      {X, fam["InvList"]}]];
  <|"status" -> "ok", "route" -> "curve", "targets" -> tg[[All, "label"]], "npool" -> Length[pf],
    "candidates" -> DeleteDuplicatesBy[out, {#["K"], #["r2"]} &]|>];

MCBSingleCandidates[fam_Association, s_List, cd_Association, opts0_Association : <||>] := Module[{opts = Join[$MCBDefaultOptions, opts0], pool, pf, st = cd["split"]},
  pool = Take[poolFor[fam, s, cd, opts], UpTo[Max[24, 3 opts["nmi"] + 6]]];
  pf = MCBPoolData[cd, pool];
  <|"status" -> "ok", "route" -> "single", "targets" -> {"single integrals"}, "npool" -> Length[pf],
    "candidates" -> Table[<|"r2" -> dropNumber[1/st["kinNorm"]^2], "K" -> eps^(-p0["k"]) p0["j"], "strict" -> False,
        "weight" -> ComboWeight[p0["j"], s], "label" -> "single integral", "provenance" -> "auto", "priority" -> 5, "rep" -> repTag[cd]|>, {p0, pf}]|>];


(* ::Section:: *)
(*Candidates that are dlog in d dimensions*)


(* ::Text:: *)
(*On the maximal cut, j = Int R_j(z, eps) u(z, eps) dz, with u the twist and R_j a polynomial in eps (MCBCutIntegrand).*)
(*If Rz Sum c_i(eps) R_i(z, eps) does not depend on eps and W(z) dz/Sqrt[Pr] is a dlog form, the combination is dlog in d*)
(*dimensions: its integrand is the dlog form times eps-powers of the twist. The other candidates only allow one power of eps*)
(*per integral, which cannot reproduce normalisations such as 1/(1 - 2 eps) or 1/eps between integrals (a massless bubble*)
(*inserted in a line, for instance); here the coefficients are rational in eps. Subsets of the pool are screened at random*)
(*rational points (cut variables, eps, kinematics) and solved exactly when consistent.*)


strictScreenData[fam_, cd_, P_List] := Module[{vars = cd["vars"], kin, epsv, zp},
  kin = Take[MCBPoints[fam, 2, 11], 2];
  epsv = {3/7, -5/13};
  zp = BlockRandom[SeedRandom[17]; Table[Thread[vars -> RandomInteger[{-40, 40}, Length[vars]]/RandomInteger[{7, 41}, Length[vars]]], {12}]];
  <|"kin" -> kin, "eps" -> epsv, "z" -> zp,
    "P" -> Table[Table[Quiet[f /. kp /. eps -> e /. zz], {zz, zp}], {f, P}, {kp, kin}, {e, epsv}]|>];

(* columns cols (lists of 12 values at each kinematic point and eps), right-hand side b: consistent at every sample? *)
strictConsistentQ[cols_, rhs_] := AllTrue[Flatten[Table[{ik, ie}, {ik, 2}, {ie, 2}], 1], Function[ii,
    Module[{A = Transpose[#[[Sequence @@ ii]] & /@ cols], b = rhs[[Sequence @@ ii]]},
      ! MemberQ[Flatten[{A, b}], ComplexInfinity | Indeterminate | _DirectedInfinity] &&
        MatrixRank[A] == MatrixRank[Join[A, List /@ b, 2]]]]];

strictSolve[fns_List, rhs_, vars_List] := Module[{c = Array[MaximalCutBasis`Candidates`Private`strictC, Length[fns]], num, sol},
  num = Numerator[Together[c . fns - rhs]];
  sol = Quiet@Solve[Thread[(Last /@ CoefficientRules[num, vars]) == 0], c];
  If[sol === {} || ! FreeQ[c /. First[sol], MaximalCutBasis`Candidates`Private`strictC], $Failed, Together[c /. First[sol]]]];

MCBStrictTargetCandidates[fam_Association, s_List, cd_Association, opts0_Association : <||>] := Module[{opts = Join[$MCBDefaultOptions, <|"maxsize" -> 3, "cap" -> 24, "cap3" -> 14|>, opts0],
    st = cd["split"], v, cu, tg, pool, pf, P, W, data, rhsOf, out = {}, subsets, n},
  If[Length[cd["vars"]] != 1, Return[<|"status" -> "not one variable", "candidates" -> {}|>]];
  v = First[cd["vars"]];
  If[Exponent[st["Pr"], v] > 2, Return[<|"status" -> "not genus 0", "candidates" -> {}|>]];
  cu = MCBCurve[cd];
  tg = MCBCurveTargets[cd];
  If[Exponent[st["Pr"], v] == 0 && AssociationQ[cu],
    Do[If[Exponent[g, v] == 2,
        tg = Join[tg, {<|"label" -> "d log(" <> ToString[g, InputForm] <> ")", "norm" -> 1, "W" -> Together[D[g, v]/g]|>,
          <|"label" -> "dz/(" <> ToString[g, InputForm] <> "), residues +-1 at its roots", "norm" -> Factor[Discriminant[g, v]], "W" -> 1/g|>}]],
      {g, cu["punctures"]}]];
  If[tg === {}, Return[<|"status" -> "no targets", "candidates" -> {}|>]];
  pool = MCBSectorPool[fam, s, cd["isp"], <|"nd" -> opts["nd"], "nt" -> opts["nt"], "w" -> opts["w"], "cap" -> opts["cap"], "nmi" -> opts["nmi"]|>];
  pf = MCBPoolData[cd, pool];
  If[pf === {}, Return[<|"status" -> "empty-pool", "candidates" -> {}|>]];
  P = Together[st["Rz"] #["R"]] & /@ pf;
  W[t_] := Which[KeyExistsQ[t, "W"], t["W"], KeyExistsQ[t, "puncture"], 1/t["puncture"], True, v^(t["index"] - 1)];
  data = strictScreenData[fam, cd, P];
  rhsOf[w_] := Table[Table[Quiet[w /. kp /. zz], {zz, data["z"]}], {kp, data["kin"]}, {e, data["eps"]}];
  n = Length[pf];
  subsets = Join[Subsets[Range[n], {1}], Subsets[Range[n], {2}], If[opts["maxsize"] >= 3, Subsets[Range[Min[n, opts["cap3"]]], {3}], {}]];
  Do[Module[{w = W[t], rhs, found = 0},
      rhs = rhsOf[w];
      Do[If[strictConsistentQ[data["P"][[sub]], rhs],
          With[{cf = strictSolve[P[[sub]], w, {v}]},
            If[cf =!= $Failed,
              AppendTo[out, <|"r2" -> dropNumber[t["norm"]/st["kinNorm"]^2],
                 "K" -> Collect[Sum[cf[[i]] pf[[sub[[i]]]]["j"], {i, Length[sub]}], _j, Together], "strict" -> True,
                 "weight" -> ComboWeight[Sum[pf[[i]]["j"], {i, sub}], s], "label" -> "d-dim " <> t["label"],
                 "provenance" -> "dlog in d dimensions (MCBStrictTargetCandidates)", "priority" -> 0, "rep" -> repTag[cd]|>];
              found++]]];
        If[found >= 2, Break[]],
        {sub, subsets}]],
    {t, tg}];
  <|"status" -> "ok", "route" -> "strict", "npool" -> n, "candidates" -> DeleteDuplicatesBy[out, {#["K"], #["r2"]} &]|>];

MCBPurifyCandidates[fam_Association, s_List, cd_Association, cands_List, opts0_Association : <||>] := Module[{opts = Join[$MCBDefaultOptions, <|"cap" -> 24, "maxextra" -> 2, "maxcands" -> 40|>, opts0],
    st = cd["split"], vars = cd["vars"], pool, pf, P, data, out = {}, cutOf},
  pool = MCBSectorPool[fam, s, cd["isp"], <|"nd" -> opts["nd"], "nt" -> opts["nt"], "w" -> opts["w"], "cap" -> opts["cap"], "nmi" -> opts["nmi"]|>];
  pf = MCBPoolData[cd, pool];
  P = Together[st["Rz"] #["R"]] & /@ pf;
  data = strictScreenData[fam, cd, P];
  cutOf[K_] := Module[{e = Collect[Expand[K], _j]},
    Together[st["Rz"] Sum[Coefficient[e, jj] MCBCutIntegrand[cd, jj], {jj, DeleteDuplicates[Cases[e, _j, Infinity]]}]]];
  Do[Module[{FK, m, G, F0, colG, rhs, found = False},
      FK = Quiet@cutOf[c["K"]];
      If[! FreeQ[FK, $Failed] || FK === 0, Continue[]];
      m = Module[{ser = Series[FK, {eps, 0, 2}]}, If[Head[ser] === SeriesData, ser[[4]]/ser[[6]], 0]];
      G = Together[FK/eps^m]; F0 = Together[G /. eps -> 0];
      If[F0 === 0, Continue[]];
      If[FreeQ[G, eps],
        AppendTo[out, Join[c, <|"K" -> Collect[c["K"]/eps^m, _j, Together], "label" -> "d-dim " <> c["label"], "strict" -> True|>]]; Continue[]];
      colG = Table[Table[Quiet[G /. kp /. eps -> e /. zz], {zz, data["z"]}], {kp, data["kin"]}, {e, data["eps"]}];
      rhs = Table[Table[Quiet[F0 /. kp /. zz], {zz, data["z"]}], {kp, data["kin"]}, {e, data["eps"]}];
      Do[If[strictConsistentQ[Prepend[data["P"][[sub]], colG], rhs],
          With[{cf = strictSolve[Prepend[P[[sub]], G], F0, vars]},
            If[cf =!= $Failed,
              AppendTo[out, Join[c, <|"K" -> Collect[cf[[1]] c["K"]/eps^m + Sum[cf[[i + 1]] pf[[sub[[i]]]]["j"], {i, Length[sub]}], _j, Together],
                 "label" -> "d-dim " <> c["label"], "strict" -> True, "provenance" -> "dlog candidate made exact in eps (MCBPurifyCandidates)"|>]];
              found = True]]];
        If[found, Break[]],
        {sub, Join[{{}}, Subsets[Range[Length[pf]], {1, opts["maxextra"]}]]}]],
    {c, Take[cands, UpTo[opts["maxcands"]]]}];
  DeleteDuplicatesBy[out, {#["K"], #["r2"]} &]];

(* ::Section:: *)
(*Projection onto pool integrals modulo total derivatives*)


(* ::Text:: *)
(*On the maximal cut, j = kinNorm Int P_j ut d^n z with P_j = Rz R_j and ut = u/(kinNorm Rz): Pr^(-1/2) times pure eps-powers*)
(*of the twist factors. Integrands that differ by a total derivative Sum_i (d_i xi_i + xi_i omega_i), omega_i = d_i log ut,*)
(*give the same integral. A dlog form W d^n z/Sqrt[Pr] of the cut is reached by any combination of pool integrals that*)
(*equals W up to such a derivative; exact matching (MCBStrictTargetCandidates, MCBPurifyCandidates) is the special case*)
(*xi = 0. With nmi independent targets, the coordinates M of nmi independent pool integrands in the targets give the targets*)
(*as Inverse[M] times those integrals, with coefficients rational in eps and the kinematics. xi_i = N_i(z) pref with N_i a*)
(*polynomial; pref cancels the poles that the derivative would otherwise create. One variable: the linear system comes*)
(*from the coefficients in z. Several variables: from random sample points z; independence is screened modulo a prime and*)
(*the degree of N is raised while the integrands seem to span more than nmi dimensions.*)


prjDefaults = <|"nd" -> 1, "nt" -> 1, "w" -> 2, "cap" -> 16, "nmi" -> 1, "verbose" -> False, "Kmax" -> 6, "maxcols" -> 60, "maxcands" -> 40|>;
prjOpts[opts0_] := Join[prjDefaults, KeyTake[opts0, {"nmi", "verbose", "Kmax", "maxcols", "maxcands"}]];
prjFFQ := prjFFQ = TrueQ[Quiet@MCBLoadTool["FiniteFlow"]];

(* omega_i = d_i log ut *)
prjOmegas[cd_] := Table[Together[Sum[If[FreeQ[cd["cutpolys"][[i]], v], 0, cd["cutpows"][[i]] D[cd["cutpolys"][[i]], v]/cd["cutpolys"][[i]]], {i, Length[cd["cutpolys"]]}] -
    D[cd["split"]["Rz"], v]/cd["split"]["Rz"]], {v, cd["vars"]}];

prjTotDeg[p_, vars_] := Module[{e = Expand[p]}, If[e === 0, -Infinity, Max[Total /@ (First /@ CoefficientRules[e, vars])]]];

(* pref = Prod G^e: e = 1 - (largest pole order of G among the functions); in one variable also e = 1 for a pole
   of omega only, since xi must vanish there. In several variables xi_i need not vanish on a twist factor G: only
   Sum_i xi_i d_i G must (a syzygy of G), and the sampled equations impose that themselves. K = degree of N. *)
prjAnsatz[fns_List, oms_List, vars_List] := Module[{facs = <||>, add, degInf, pref},
  add[f_, m_] := Module[{g = MCBCanonFactor[f][[1]]}, facs[g] = Max[Lookup[facs, g, 0], m]];
  Do[Do[If[! FreeQ[ff[[1]], Alternatives @@ vars], add[ff[[1]], ff[[2]]]], {ff, FactorList[Denominator[Together[f]]]}], {f, fns}];
  If[Length[vars] == 1, Do[Do[If[! FreeQ[ff[[1]], Alternatives @@ vars], add[ff[[1]], 0]], {ff, FactorList[Denominator[Together[om]]]}], {om, oms}]];
  pref = Times @@ KeyValueMap[#1^If[#2 >= 1, 1 - #2, 1] &, facs];
  degInf = Max[(prjTotDeg[Numerator[Together[#]], vars] - prjTotDeg[Denominator[Together[#]], vars]) & /@ fns];
  {pref, Max[0, degInf + 2 - (prjTotDeg[Numerator[Together[pref]], vars] - prjTotDeg[Denominator[Together[pref]], vars])]}];

(* one variable: F - x.Bs - (xi' + xi omega) = 0 coefficient by coefficient in v *)
prjEquations1[F_, Bs_List, om_, v_, pref_, K_] := Module[{x = Array[prjX, Length[Bs]], a = Array[prjA, K + 1], xi, ex},
  xi = (a . v^Range[0, K]) pref;
  ex = Together[F - x . Bs - D[xi, v] - xi om];
  {DeleteCases[CoefficientList[Numerator[ex], v], 0], x, a}];

prjInSpan1Q[F_, Bs_List, om_, v_, pref_, K_] := Module[{eq, x, a},
  {eq, x, a} = prjEquations1[F, Bs, om, v, pref, K];
  eq === {} || Quiet[Solve[Thread[eq == 0], Join[x, a]]] =!= {}];

(* the needed unknowns x of a linear system with symbolic parameters: FiniteFlow, else LinearSolve *)
prjSolve[eqs_List, x_List, a_List] := Module[{params, sol, ca},
  If[prjFFQ,
    params = Complement[Variables[eqs /. Equal -> List], Join[x, a]];
    sol = Quiet@MCBQualify["FiniteFlow`", "FFDenseSolve"][eqs, Join[x, a], "Parameters" -> params, "NeededVars" -> x];
    (* each solve FiniteFlow answered, a solution or FFImpossible, is a use (prjFFQ only remembers that it loaded) *)
    If[ListQ[sol] || sol === MCBQualify["FiniteFlow", "FFImpossible"], MCBMarkToolUsed["FiniteFlow"]];
    If[! ListQ[sol] || ! SubsetQ[First /@ sol, x], Return[$Failed]];
    sol = Together[x /. sol];
    Return[If[FreeQ[sol, Alternatives @@ a], sol, $Failed]]];
  ca = CoefficientArrays[eqs /. Equal[l_, r_] :> l - r, Join[x, a]];
  sol = Quiet@Check[LinearSolve[Normal[ca[[2]]], -Normal[ca[[1]]]], $Failed];
  If[sol === $Failed, $Failed, Together /@ Take[sol, Length[x]]]];

prjCoordinates1[F_, Bs_List, om_, v_] := Module[{pref, K, eq, x, a},
  {pref, K} = prjAnsatz[Join[{F}, Bs], {om}, {v}];
  {eq, x, a} = prjEquations1[F, Bs, om, v, pref, K];
  If[eq === {}, ConstantArray[0, Length[Bs]], prjSolve[Thread[eq == 0], x, a]]];

(* Inverse[M] row b: basis element b in the pool integrals J *)
prjCandidates[fam_, s_, cd_, pf_, J_, Minv_, picks_List] := Table[
   <|"r2" -> pk[[2]], "K" -> Collect[Sum[Minv[[pk[[1]], i]] pf[[J[[i]]]]["j"], {i, Length[J]}], _j, Together], "strict" -> True,
     "weight" -> ComboWeight[Sum[pf[[i]]["j"], {i, J}], s], "label" -> pk[[3]], "provenance" -> pk[[4]], "priority" -> 0, "rep" -> repTag[cd]|>,
   {pk, picks}];

(* Sqrt[e] when e is a perfect square of a rational function (numeric factor included), else $Failed *)
prjExactSqrt[e_] := Module[{t = Factor[Together[e]], fl, c, rest},
  If[t === 0, Return[0]];
  fl = Join[FactorList[Numerator[t]], {#[[1]], -#[[2]]} & /@ FactorList[Denominator[t]]];
  c = Times @@ (Power @@@ Select[fl, NumericQ[#[[1]]] &]); rest = Select[fl, ! NumericQ[#[[1]]] &];
  If[! (NumericQ[c] && c > 0 && Element[Sqrt[c], Rationals]) || AnyTrue[rest, OddQ[#[[2]]] &], Return[$Failed]];
  Sqrt[c] Times @@ (#[[1]]^(#[[2]]/2) & /@ rest)];

(* A quadratic factor g = al z^2 + be z + ga of the twist that does not divide Pr: at its roots r1, r2 the dlog
   forms Sqrt[Pr(r)] dz/((z - r) y) need Sqrt[Pr(r1)] = Sqrt[A + B Sqrt[D]], a nested square root. It denests when
   N^2 = A^2 - B^2 D = Pr(r1) Pr(r2) is a perfect square; then the sum and the difference of the two forms are
     [2 al (A +- N) z + be (A +- N) + B D]/g dz/y,  normalised by 1/Sqrt[2 (A +- N)].
   A, B D and N follow from the remainder of Pr modulo g. *)
prjDenestedTargets[Pr_, g_, v_] := Module[{al, be, ga, rem, c1, c0, A, BD, D0, nn},
  {ga, be, al} = CoefficientList[g, v];
  D0 = Together[be^2 - 4 al ga];
  rem = PolynomialRemainder[Pr, g, v]; c1 = Coefficient[rem, v, 1]; c0 = Coefficient[rem, v, 0];
  A = Together[c0 - c1 be/(2 al)]; BD = Together[c1 D0/(2 al)];
  nn = prjExactSqrt[A^2 - BD^2/D0];
  If[nn === $Failed || c1 === 0, Return[{}]];
  Table[<|"label" -> "dz/y at the roots of " <> ToString[g, InputForm] <> If[sg > 0, " (sum)", " (difference)"],
     "norm" -> Factor[1/(2 (A + sg nn))], "W" -> Together[(2 al (A + sg nn) v + be (A + sg nn) + BD)/g]|>, {sg, {1, -1}}]];

MCBProjectedCandidates[fam_Association, s_List, cd_Association, opts0_Association : <||>] := Module[{opts = prjOpts[opts0], v, st = cd["split"], cu, tg,
    pool, pf, P, Wt, om, nmi, pref, K, num, numOf, basis = {}, sel = {}, J = {}, M, Minv, order, all},
  nmi = opts["nmi"];
  If[Length[cd["vars"]] != 1, Return[{}]];
  v = First[cd["vars"]];
  If[Exponent[st["Pr"], v] > 2, Return[{}]];
  cu = MCBCurve[cd];
  tg = MCBCurveTargets[cd];
  If[Exponent[st["Pr"], v] == 0 && AssociationQ[cu],
    Do[If[Exponent[g, v] == 2,
        tg = Join[tg, {<|"label" -> "d log(" <> ToString[g, InputForm] <> ")", "norm" -> 1, "W" -> Together[D[g, v]/g]|>,
          <|"label" -> "dz/(" <> ToString[g, InputForm] <> ") (residues +-1 at its roots)", "norm" -> Factor[Discriminant[g, v]], "W" -> 1/g|>}]],
      {g, cu["punctures"]}]];
  If[Exponent[st["Pr"], v] == 2 && AssociationQ[cu],
    Do[If[Exponent[g, v] == 2, tg = Join[tg, prjDenestedTargets[st["Pr"], g, v]]], {g, cu["punctures"]}]];
  If[tg === {}, Return[{}]];
  Wt = Which[KeyExistsQ[#, "W"], #["W"], KeyExistsQ[#, "puncture"], 1/#["puncture"], True, v^(#["index"] - 1)] & /@ tg;
  om = First[prjOmegas[cd]];
  pool = MCBSectorPool[fam, s, cd["isp"], <|"nd" -> opts["nd"], "nt" -> opts["nt"], "w" -> opts["w"], "cap" -> opts["cap"], "nmi" -> nmi|>];
  pf = MCBPoolData[cd, pool];
  If[pf === {}, Return[{}]];
  P = Together[st["Rz"] #["R"]] & /@ pf;
  {pref, K} = prjAnsatz[Join[Wt, P], {om}, {v}];
  num = Join[First[MCBPoints[fam, 1, 23]], {eps -> 7/31}];
  numOf[e_] := Together[e /. num];
  (* smallest pool integrands first: the exact solve is cheap for them *)
  order = Ordering[LeafCount /@ P];
  all = Join[Transpose[{Range[Length[Wt]], ConstantArray["t", Length[Wt]]}], Transpose[{order, ConstantArray["p", Length[P]]}]];
  Do[If[Length[basis] < nmi,
      With[{F = If[e[[2]] === "t", Wt[[e[[1]]]], P[[e[[1]]]]]},
        If[! prjInSpan1Q[numOf[F], numOf /@ basis, numOf[om], v, numOf[pref], K], AppendTo[basis, F]; AppendTo[sel, e]]]],
    {e, all}];
  If[Length[basis] < nmi || FreeQ[sel, "t"], Return[{}]];
  Module[{cur = {}}, Do[If[Length[cur] < nmi && ! prjInSpan1Q[numOf[P[[i]]], numOf /@ P[[cur]], numOf[om], v, numOf[pref], K], AppendTo[cur, i]], {i, order}]; J = cur];
  If[Length[J] < nmi, Return[{}]];
  M = prjCoordinates1[P[[#]], basis, om, v] & /@ J;
  If[MemberQ[M, $Failed], Return[{}]];
  Minv = Quiet@Check[Together /@ # & /@ Inverse[M], $Failed];
  If[Minv === $Failed, Return[{}]];
  prjCandidates[fam, s, cd, pf, J, Minv,
    Table[If[sel[[b, 2]] === "t", With[{t = tg[[sel[[b, 1]]]]},
        {b, dropNumber[t["norm"]/st["kinNorm"]^2], "projected " <> t["label"], "dlog form of the cut projected onto pool integrals (MCBProjectedCandidates)"}], Nothing],
      {b, Length[sel]}]]];

prjMonomials[vars_, K_] := prjMonomials[vars, K] = Union[Times @@@ Tuples[Join[{1}, vars], K]];
prjPrime = 2147483647;
prjRank[m_] := MatrixRank[Map[Mod[Numerator[#] PowerMod[Denominator[#], -1, prjPrime], prjPrime] &, m, {2}], Modulus -> prjPrime];
prjColumns[vars_, oms_, pref_, K_] := Flatten[Table[D[m pref, vars[[i]]] + m pref oms[[i]], {i, Length[vars]}, {m, prjMonomials[vars, K]}]];
prjZPoints[vars_, n_, seed_] := BlockRandom[SeedRandom[seed];
  Table[Thread[vars -> (RandomInteger[{-97, 97}, Length[vars]]/RandomInteger[{5, 61}, Length[vars]])], {n}]];

MCBProjectedPurifyCandidates[fam_Association, s_List, cd_Association, cands_List, opts0_Association : <||>] := Module[{opts = prjOpts[opts0],
    vars = cd["vars"], st = cd["split"], oms, tg = {}, pool, pf, P, nmi, num, numOf, pref, K, kmax, cols, zp, A0, r0, fvals, sel, J, basis, M, Minv,
    order, dim, all, allN, cutOf, nb, prev = None},
  nmi = opts["nmi"];
  If[vars === {} || cands === {} || ! prjFFQ, Return[{}]];
  oms = prjOmegas[cd];
  cutOf[Kc_] := Module[{e = Collect[Expand[Kc], _j]},
    Together[st["Rz"] Sum[Coefficient[e, jj] MCBCutIntegrand[cd, jj], {jj, DeleteDuplicates[Cases[e, _j, Infinity]]}]]];
  (* targets: the eps = 0 cut integrand of each candidate, in units of kinNorm ut *)
  Do[Module[{FK = Quiet@cutOf[c["K"]], m, W},
      If[! FreeQ[FK, $Failed] || FK === 0, Continue[]];
      m = Module[{ser = Series[FK, {eps, 0, 2}]}, If[Head[ser] === SeriesData, ser[[4]]/ser[[6]], 0]];
      W = Together[Together[FK/eps^m] /. eps -> 0];
      If[W =!= 0 && FreeQ[W, ComplexInfinity | Indeterminate], AppendTo[tg, <|"cand" -> c, "W" -> W|>]]],
    {c, Take[cands, UpTo[opts["maxcands"]]]}];
  tg = DeleteDuplicatesBy[tg, #["W"] &];
  If[tg === {}, Return[{}]];
  pool = MCBSectorPool[fam, s, cd["isp"], <|"nd" -> opts["nd"], "nt" -> opts["nt"], "w" -> opts["w"], "cap" -> opts["cap"], "nmi" -> nmi|>];
  pf = MCBPoolData[cd, pool];
  If[pf === {}, Return[{}]];
  P = Together[st["Rz"] #["R"]] & /@ pf;
  order = Ordering[LeafCount /@ P];
  num = Join[First[MCBPoints[fam, 1, 23]], {eps -> 7/31}];
  numOf[e_] := Together[e /. num];
  {pref, K} = prjAnsatz[Join[#["W"] & /@ tg, P], oms, vars];
  kmax = Max[K, opts["Kmax"]];
  all = Join[#["W"] & /@ tg, P];
  allN = numOf /@ all;
  While[True,
    cols = numOf /@ prjColumns[vars, oms, pref, K];
    If[Length[cols] > opts["maxcols"],
      If[AssociationQ[prev], {K, cols, A0, fvals, r0, dim} = Lookup[prev, {"K", "cols", "A0", "fvals", "r0", "dim"}]; Break[], Return[{}]]];
    zp = prjZPoints[vars, Length[cols] + Length[all] + 30, 41];
    A0 = Quiet[Table[cols /. z0, {z0, zp}]];
    fvals = Quiet[Table[f /. z0, {f, allN}, {z0, zp}]];
    If[! FreeQ[{A0, fvals}, ComplexInfinity | Indeterminate | DirectedInfinity], zp = prjZPoints[vars, Length[zp], 43];
      A0 = Quiet[Table[cols /. z0, {z0, zp}]]; fvals = Quiet[Table[f /. z0, {f, allN}, {z0, zp}]]];
    r0 = prjRank[A0];
    dim = prjRank[Join[A0, Transpose[fvals], 2]] - r0;
    (* a dimension that stops falling is the cohomology (or a symmetry keeps it above nmi): keep the smaller K,
       the exact solve below costs (columns)^2 *)
    If[AssociationQ[prev] && dim >= prev["dim"], {K, cols, A0, fvals, r0, dim} = Lookup[prev, {"K", "cols", "A0", "fvals", "r0", "dim"}]; Break[]];
    If[dim <= nmi || K >= kmax, Break[]];
    prev = <|"K" -> K, "cols" -> cols, "A0" -> A0, "fvals" -> fvals, "r0" -> r0, "dim" -> dim|>;
    K++];
  (* the integrands can span more than nmi dimensions modulo total derivatives: symmetry relations of the
     sector are not total derivatives. Identities found modulo total derivatives are exact all the same, so work
     with a basis of the dimension found and let the search pick nmi candidates. *)
  If[dim < nmi, Return[{}]];
  nb = dim;
  sel = Module[{cur = {}}, Do[If[Length[cur] < nb && prjRank[Join[A0, Transpose[fvals[[Append[cur, i]]]], 2]] > r0 + Length[cur], AppendTo[cur, i]],
      {i, Join[Range[Length[tg]], Length[tg] + order]}]; cur];
  J = Module[{cur = {}}, Do[If[Length[cur] < nb && prjRank[Join[A0, Transpose[fvals[[Length[tg] + Append[cur, i]]]], 2]] > r0 + Length[cur], AppendTo[cur, i]],
      {i, order}]; cur];
  If[Length[sel] < nb || Length[J] < nb || Min[sel] > Length[tg], Return[{}]];
  basis = all[[sel]];
  (* the symbolic set-up and the solve grow fast with the number of columns: about 100 s and several GB at 105
     columns with five invariants, hence "maxcols" and a memory limit on the set-up *)
  M = MemoryConstrained[Module[{colsS = prjColumns[vars, oms, pref, K], x = Array[prjX, nb], a, zs, colsZ, basisZ},
    a = Array[prjA, Length[colsS]];
    zs = prjZPoints[vars, Length[colsS] + nb + 20, 47];
    colsZ = Table[Together /@ (colsS /. z0), {z0, zs}];
    basisZ = Table[Together /@ (basis /. z0), {z0, zs}];
    Table[prjSolve[Table[Together[P[[j]] /. zs[[k]]] - x . basisZ[[k]] - a . colsZ[[k]] == 0, {k, Length[zs]}], x, a], {j, J}]], 1500*^6, {$Failed}];
  If[MemberQ[M, $Failed], Return[{}]];
  Minv = Quiet@Check[Together /@ # & /@ Inverse[M], $Failed];
  If[Minv === $Failed, Return[{}]];
  prjCandidates[fam, s, cd, pf, J, Minv,
    Table[If[sel[[b]] <= Length[tg], With[{c = tg[[sel[[b]]]]["cand"]},
        {b, c["r2"], "projected " <> c["label"], "eps = 0 dlog candidate made exact in eps modulo total derivatives (MCBProjectedPurifyCandidates)"}], Nothing],
      {b, Length[sel]}]]];


End[];
EndPackage[];
