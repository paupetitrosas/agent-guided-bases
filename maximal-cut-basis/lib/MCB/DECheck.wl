(* ::Package:: *)

(* ::Title:: *)
(*MaximalCutBasis`DECheck`: the maximal-cut DE and the search for the best basis*)


(* ::Text:: *)
(*A candidate is <|"r2" -> R, "K" -> rational combination of integrals, "label", "strict", "weight",*)
(*"provenance", "priority"|> and stands for J = Sqrt[R] K.  At each numeric point Kira reduces K and*)
(*dK/dX (every invariant X) onto the cut masters: K = T.M, dK/dX = D.M.  Then*)
(*    dJ/dX = (D T^-1 + diag(g_X)) J   up to conjugation by Sqrt[R_i/R_j],   g_X = d log Sqrt[R]/dX.*)
(*The conjugation is eps independent, so it is dropped: it cannot change the eps structure.*)
(*eps-form allows relative powers eps^k_i: m_ij + k_i - k_j = 1 for every entry eps^m_ij, solved by BFS.*)


BeginPackage["MaximalCutBasis`DECheck`", {"MaximalCutBasis`", "SkillCore`Tools`", "SkillCore`Records`", "SkillCore`Pages`", "MaximalCutBasis`Family`",
   "MaximalCutBasis`Sectors`", "MaximalCutBasis`Rules`", "MaximalCutBasis`Derivatives`", "MaximalCutBasis`Kira`"}];

MCBCandidate::usage = "MCBCandidate[fam, sector, K, <|\"r2\" -> R, \"label\" -> ..., \"provenance\" -> ...|>] builds a candidate J = Sqrt[R] K with defaults.";
MCBSplitMaster::usage = "MCBSplitMaster[J] turns a masters.m expression eps^k Sqrt[R] (combination) back into <|\"r2\" -> R, \"K\" -> rational combination|>; $Failed (with a message) if the terms have different square roots.";
MCBSplitRoot::usage = "MCBSplitRoot[r2, K] = {square-free radicand, rational part times K}.";
MCBMasterExpression::usage = "MCBMasterExpression[cand, k] is eps^k Sqrt[radicand] (rational part K): the expression written to masters.m.";
MCBReduceCandidates::usage = "MCBReduceCandidates[fam, sector, cands, dir, pts] reduces every candidate and its derivatives in every invariant at each point (one Kira run per point). Returns a list of <|\"point\", \"masters\", \"T\", \"D\", \"g\", \"invariants\"|>.";
MCBSubsetDE::usage = "MCBSubsetDE[red, sub] returns the list of A_X (every point, every invariant) for the candidates sub; $Failed if they are dependent on the cut.";
MCBEpsProfile::usage = "MCBEpsProfile[entry] = \"0\", {lowest, highest} eps power of a Laurent polynomial, or \"rat\".";
MCBEpsFactorizedQ::usage = "MCBEpsFactorizedQ[As] = {True, k} if eps^k_i rescalings make every A_X equal to eps times an eps-independent matrix, else {False, profile}.";
MCBEpsPolynomialQ::usage = "MCBEpsPolynomialQ[As] = {True, {min, max}} if every entry is a Laurent polynomial in eps, else {False, reason}.";
MCBRescaleEps::usage = "MCBRescaleEps[A, k] is A after J_i -> eps^k_i J_i.";
MCBSearchBasis::usage = "MCBSearchBasis[red, cands, nMI, opts] searches subsets of nMI candidates for an eps-factorised maximal-cut DE (exact for nMI <= 2, numeric eps samples + exact check otherwise), then simplifies; on a dlog sector it searches the eps-pure candidates alone first (MCBOrderKey's purity), then those not known to be impure, then all. Without one, it keeps the eps-polynomial subset with the smallest spread of powers of eps; opts \"NonDlog\" -> True (a non-dlog sector) breaks a tie of spreads for a subset with an undotted element (MCBAllDotQ; \"Sector\" -> s, default: the candidates' top sector). Returns <|\"status\", \"sub\", \"k\", \"range\", \"A\", \"cands\"|>.";
MCBSimplifyBasis::usage = "MCBSimplifyBasis[red, cands, sub, keep] greedily replaces basis elements by candidates earlier in MCBOrderKey's order (an eps-pure one first, then a rational normalisation, then a lighter one) while the DE stays eps-factorised: it never gives up an eps-pure element for one that is not.";
MCBCheckBasis::usage = "MCBCheckBasis[fam, sector, masters, dir, <|\"Points\" -> pts|>] verifies ANY proposed basis (list of expressions as in masters.m) on the maximal-cut DE at the numeric points. Returns <|\"status\" -> eps-form | eps-polynomial | rational | failed, \"k\", \"range\", \"A\", \"pattern\", \"nMastersCut\", \"cutMasters\", \"points\", \"checks\", \"message\"|>; \"checks\" are those of MCBBasisChecks, and a basis whose DE breaks the Euler relation is failed.";
MCBBasisChecks::usage = "MCBBasisChecks[fam, masters, As, pts] checks a basis (expressions as in masters.m) and its maximal-cut DE (As as from MCBSubsetDE: every invariant at the first point, then at the next): the hard rules on masters, the letters (with an alphabet), the shared weight (MCBRulesCheck), and the Euler relation Sum_X d_X X A_X = diag(weights) at every point (MCBEulerCheck). Returns a list of <|\"Name\", \"Pass\", \"Detail\"|>. Only the Euler relation decides in this skill; the rules and weights are reported (d-dimensional dlog candidates may carry rational functions of eps, and derivative bases of curves mix weights).";
MCBPrintDE::usage = "MCBPrintDE[check] prints A_X/eps (eps-form) or the eps coefficients of A_X at the first point.";
MCBDottedQ::usage = "MCBDottedQ[J, s] is True when the basis element J (as in masters.m, or a candidate's rational part K) has an integral in the sector s and every one of its integrals in s is dotted (a propagator power > 1). Without s, the sector is that of J's integrals with the most propagators.";
MCBAllDotQ::usage = "MCBAllDotQ[masters, s] is True when every element of a basis is dotted (MCBDottedQ): on a non-dlog sector such a basis is flagged as likely to carry a weight between sectors, and loses a tie to one with an undotted element (SKILL.md, tie-breakers).";
MCBOrderKey::usage = "MCBOrderKey[cand] is the sort key of the search, {purity, priority, square-root normalisation, weight}: eps-pure candidates come first, before any priority, then those whose purity is not known, then those that are not eps-pure (the candidate's \"pure\" verdict, MCBCandidatePurity, else \"strict\"; SKILL.md, Purity and Tie-breakers).";
$MCBEpsSamples::usage = "$MCBEpsSamples are the numeric eps values of the fast subset screen.";

Begin["`Private`"];


(* ::Section:: *)
(*Candidates and masters.m expressions*)


(* a large K (MCBLargeQ) is kept as written: prefactor x pieces stays one product *)
MCBCandidate[fam_Association, s_List, K_, opts_Association : <||>] := Join[
  <|"r2" -> 1, "label" -> "", "strict" -> False, "provenance" -> "agent", "priority" -> 5|>, opts,
  <|"K" -> If[MCBLargeQ[K], K, Collect[K, _j, Together]], "weight" -> ComboWeight[K, s]|>];

MCBSplitRoot[r2_, K_] := Module[{fl = FactorList[Factor[r2]], rat = 1, rest = 1},
  Do[If[NumericQ[f[[1]]], rest *= f[[1]]^f[[2]], rat *= f[[1]]^Quotient[f[[2]], 2]; rest *= f[[1]]^Mod[f[[2]], 2]], {f, fl}];
  {Factor[rest], If[MCBLargeQ[K], rat K, Collect[rat K, _j, Factor]]}];

MCBMasterExpression[cand_Association, k_Integer : 0] := Module[{sr = MCBSplitRoot[cand["r2"], cand["K"]]},
  eps^k If[sr[[1]] === 1, 1, Sqrt[sr[[1]]]] sr[[2]]];

halfPow = Power[_, e_Rational /; Denominator[e] == 2];

(* An element is read as it is written, eps^k Sqrt[R] p (Sum_a q_a j_a) or any sum of such terms: one half power of each
   radicand is taken out of every place it appears, and J^2 = R K^2 is checked at random points. Nothing is expanded,
   so a large prefactor p stays one factor. An element whose roots are not placed that way (a root inside a sum, a
   root that appears twice) goes the old way, through Expand and Together. *)
MCBSplitMaster::mixed = "the terms of `1` do not share one square root: split it into separate basis elements or rationalise it.";
MCBSplitMaster[J_] := Module[{rads, K},
  If[JIntegrals[J] === {}, Return[$Failed]];
  rads = Union@Cases[{J}, Power[a_, e_Rational] /; Denominator[e] == 2 :> a, {0, Infinity}];
  If[rads === {}, Return[<|"r2" -> 1, "K" -> J|>]];
  K = J /. Power[a_, e_Rational] /; Denominator[e] == 2 :> a^(e - 1/2);
  If[FreeQ[K, halfPow] && MCBEqualAtPointsQ[J^2, (Times @@ rads) K^2], <|"r2" -> Times @@ rads, "K" -> K|>, splitExpanded[J]]];

splitExpanded[J_] := Module[{Jc = Collect[Expand[J], _j], ints, coefs, rads, r2, Ks},
  ints = JIntegrals[Jc];
  If[ints === {}, Return[$Failed]];
  coefs = Coefficient[Jc, #] & /@ ints;
  rads = Union@Cases[coefs, Power[a_, e_Rational] /; Denominator[e] == 2 :> a, {0, Infinity}];
  r2 = Times @@ rads;
  Ks = Together[#/(Times @@ (Sqrt /@ rads))] & /@ coefs;
  If[! FreeQ[Ks, halfPow], Message[MCBSplitMaster::mixed, Short[J]]; Return[$Failed]];
  <|"r2" -> r2, "K" -> Collect[Ks . ints, _j, Together]|>];

(* the all-dot flag: a dot on every element is the first thing a basis that hides an (a + b eps) weight between sectors
   tends to show on a non-dlog cut (an elliptic sector's derivative basis, say); an undotted element pins the weight *)
topSector[J_] := With[{ss = SectorOf /@ JIntegrals[J]}, If[ss === {}, None, First[MaximalBy[ss, Total]]]];
MCBDottedQ[J_, s_List] := With[{ints = Select[JIntegrals[J], SectorOf[#] === s &]}, ints =!= {} && AllTrue[ints, Max[List @@ Rest[#]] > 1 &]];
MCBDottedQ[J_] := With[{s = topSector[J]}, s =!= None && MCBDottedQ[J, s]];
MCBAllDotQ[ms_List, s_List] := ms =!= {} && AllTrue[ms, MCBDottedQ[#, s] &];
MCBAllDotQ[ms_List, Automatic | None] := ms =!= {} && AllTrue[ms, MCBDottedQ];

(* the search order (SKILL.md, Purity and Tie-breakers): eps-pure candidates first, whatever their priority, so that a mapped basis
   or a target of the route comes first only among candidates that are as pure; then a rational normalisation, then
   the weight. Purity is the candidate's verdict (MCBCandidatePurity) when it has one, else "strict": pure, then not known,
   then not pure *)
pureRank[c_Association] := With[{p = Lookup[c, "pure", Missing[]]}, Which[TrueQ[p], 0, p === False, 2, TrueQ[Lookup[c, "strict", False]], 0, True, 1]];
MCBOrderKey[c_Association] := {pureRank[c], Lookup[c, "priority", 5],
   If[MCBSplitRoot[c["r2"], 1][[1]] === 1 || NumericQ[MCBSplitRoot[c["r2"], 1][[1]]], 0, 1],
   Lookup[c, "weight", {0, 0, 0}]};


(* ::Section:: *)
(*Reductions of candidates and derivatives*)


(* $MCBPointDerivatives (Derivatives.wl): build the derivatives at each kinematic point, or symbolically first *)
MCBReduceCandidates[fam_Association, s_List, cands_List, dir_String, pts_List] := Module[{Ks, derivs, ints, out = {}, rules, masters, g, invs = fam["InvList"]},
  Ks = DropOffCut[s] /@ (#["K"] & /@ cands);
  If[! TrueQ[$MCBPointDerivatives], derivs = Table[DropOffCut[s] /@ (MCBDerivExpr[fam, #, X] & /@ Ks), {X, invs}]];
  Do[
    If[TrueQ[$MCBPointDerivatives], derivs = Table[DropOffCut[s] /@ (MCBDerivExprAt[fam, #, X, pts[[ip]]] & /@ Ks), {X, invs}]];
    ints = JIntegrals[{Ks, derivs}];
    {rules, masters} = MCBKiraCutReduce[fam, s, ints, FileNameJoin[{dir, "pt" <> ToString[ip]}], pts[[ip]]];
    If[masters === $Failed, Return[$Failed, Module]];
    g = Table[(D[#["r2"], X]/(2 #["r2"])) /. pts[[ip]] & /@ cands, {X, invs}];
    AppendTo[out, <|"point" -> pts[[ip]], "masters" -> masters, "invariants" -> invs,
       "T" -> (MCBReduceTo[#, pts[[ip]], rules, masters] & /@ Ks),
       "D" -> Table[MCBReduceTo[#, pts[[ip]], rules, masters] & /@ derivs[[ix]], {ix, Length[invs]}], "g" -> g|>];
    (* a candidate or a derivative that Kira left unreduced (MCBReduceTo): the reduction is not usable *)
    If[! FreeQ[Last[out], $Failed], Return[$Failed, Module]],
    {ip, Length[pts]}];
  out];

MCBSubsetDE[red_List, sub_List] := Module[{T, Ti},
  Flatten[Table[
     T = r["T"][[sub]];
     If[Length[T] != Length[r["masters"]] || Together[Det[T /. eps -> 5/11]] === 0, Return[$Failed, Module]];
     Ti = Together[Inverse[T]];
     Table[Together[r["D"][[ix]][[sub]] . Ti + DiagonalMatrix[r["g"][[ix]][[sub]]]], {ix, Length[r["invariants"]]}],
     {r, red}], 1]];


(* ::Section:: *)
(*eps structure*)


MCBEpsProfile[0] := "0";
MCBEpsProfile[e_] := Module[{t = Together[e], nu, de, dpw},
  If[t === 0, Return["0"]];
  nu = Numerator[t]; de = Denominator[t];
  (* a Laurent polynomial has a power of eps in the denominator and nothing else of eps: eps (1 - 2 eps) is rational *)
  If[! FreeQ[de, eps] && ! MatchQ[Factor[de], (c_. eps^_.) /; FreeQ[c, eps]], Return["rat"]];
  dpw = Exponent[de, eps];
  {Exponent[nu, eps, Min] - dpw, Exponent[nu, eps] - dpw}];

MCBEpsFactorizedQ[As_List] := Module[{n, prof, edges, kv, queue, ok = True, i},
  If[As === {} || As === $Failed, Return[{False, {}}]];
  n = Length[First[As]];
  prof = Table[MCBEpsProfile[As[[x, i1, i2]]], {x, Length[As]}, {i1, n}, {i2, n}];
  If[MemberQ[Flatten[prof, 2], "rat"], Return[{False, prof}]];
  edges = Union@Flatten[Table[If[prof[[x, i1, i2]] =!= "0",
        If[prof[[x, i1, i2, 1]] == prof[[x, i1, i2, 2]], {i1, i2, prof[[x, i1, i2, 1]]}, ok = False; Nothing], Nothing],
      {x, Length[As]}, {i1, n}, {i2, n}], 2];
  If[! ok, Return[{False, prof}]];
  kv = ConstantArray[Null, n];
  Do[If[kv[[st]] === Null, kv[[st]] = 0; queue = {st};
     While[queue =!= {}, i = First[queue]; queue = Rest[queue];
       Do[With[{a = e[[1]], b = e[[2]], mm = e[[3]]},
          If[a == i && kv[[b]] === Null, kv[[b]] = kv[[a]] + mm - 1; AppendTo[queue, b]];
          If[b == i && kv[[a]] === Null, kv[[a]] = kv[[b]] - mm + 1; AppendTo[queue, a]]], {e, edges}]]], {st, n}];
  If[AllTrue[edges, #[[3]] + kv[[#[[1]]]] - kv[[#[[2]]]] == 1 &], {True, kv - Min[kv]}, {False, prof}]];

MCBEpsPolynomialQ[As_List] := Module[{prof = Flatten[Table[MCBEpsProfile /@ Flatten[a], {a, As}], 1]},
  If[MemberQ[prof, "rat"], {False, "rational eps dependence"},
    {True, If[DeleteCases[prof, "0"] === {}, {1, 1}, MinMax[Flatten[DeleteCases[prof, "0"]]]]}]];

MCBRescaleEps[A_, kv_] := Together[DiagonalMatrix[eps^kv] . A . DiagonalMatrix[eps^-kv]];


(* ::Section:: *)
(*Basis search*)


MCBSimplifyBasis[red_List, cands_List, sub0_List, keep_List] := Module[{sub = sub0, w, ord, try, As, ef, changed = True, pass = 0},
  w[i_] := MCBOrderKey[cands[[i]]];
  While[changed && pass < 3, changed = False; pass++;
    ord = Reverse[SortBy[Range[Length[sub]], w[sub[[#]]] &]];
    Do[
      Do[If[MemberQ[sub, cnd] || OrderedQ[{w[sub[[pos]]], w[cnd]}], Continue[]];
         try = ReplacePart[sub, pos -> cnd];
         As = MCBSubsetDE[red, try];
         If[As =!= $Failed && MCBEpsFactorizedQ[As][[1]], sub = try; changed = True; Break[]],
        {cnd, SortBy[keep, w]}],
      {pos, ord}]];
  As = MCBSubsetDE[red, sub]; ef = MCBEpsFactorizedQ[As];
  <|"status" -> "eps-form", "sub" -> sub, "k" -> ef[[2]], "A" -> As, "cands" -> cands[[sub]]|>];

(* Candidates proportional at one value of eps point the same way on the cut, but they are interchangeable only when one
   is a number times a power of eps times the other (square roots included, at every point): only then does swapping
   them leave the DE as it is. A ratio such as 1 - 2 eps, or one that depends on the kinematics, changes the DE, and the
   variant that gives eps-form may come later in MCBOrderKey's order. So such variants are kept, up to
   $MCBVariantsPerDirection per direction (the first by MCBOrderKey), so that one direction cannot fill the cap. *)
$MCBVariantsPerDirection = 3;

epsMonomialQ[e_] := Module[{t = Together[e], k},
  If[t === 0, Return[False]];
  k = Exponent[Numerator[t], eps] - Exponent[Denominator[t], eps];
  NumericQ[Together[t/eps^k]]];

(* the ratio J_a/J_b at one point, squared (J = Sqrt[r2] K: squares need no square roots); $Failed when K_a and K_b are
   not proportional there *)
ratioSquared[r_, cands_, a_, b_] := Module[{ta = r["T"][[a]], tb = r["T"][[b]], p, q},
  p = FirstPosition[tb, x_ /; Together[x] =!= 0, None, {1}, Heads -> False];
  If[p === None, Return[$Failed]];
  q = Together[ta[[First[p]]]/tb[[First[p]]]];
  If[! AllTrue[Together[ta - q tb], # === 0 &], Return[$Failed]];
  Together[q^2 (cands[[a]]["r2"]/cands[[b]]["r2"] /. r["point"])]];

interchangeableQ[red_, cands_, a_, b_] := Module[{qs = ratioSquared[#, cands, a, b] & /@ red},
  ! MemberQ[qs, $Failed] && AllTrue[Rest[qs], Together[# - First[qs]] === 0 &] && epsMonomialQ[First[qs]]];

keepIndependent[red_, cands_, cap_] := Module[{order, dirs = {}, keep = {}, v, d},
  order = SortBy[Range[Length[cands]], MCBOrderKey[cands[[#]]] &];
  Do[v = red[[1]]["T"][[i]] /. eps -> 3/7;
     If[AllTrue[v, # === 0 &], Continue[]];
     d = SelectFirst[Range[Length[dirs]], MatrixRank[{dirs[[#, 1]], v}] == 1 &, None];
     Which[
       d === None, AppendTo[dirs, {v, {i}}]; AppendTo[keep, i],
       Length[dirs[[d, 2]]] < $MCBVariantsPerDirection && NoneTrue[dirs[[d, 2]], interchangeableQ[red, cands, #, i] &],
         dirs[[d, 2]] = Append[dirs[[d, 2]], i]; AppendTo[keep, i]],
     {i, order}];
  Take[keep, UpTo[cap]]];

(* tie = None, or the sector of a non-dlog search: then, between eps-polynomial subsets with the same spread, one with an
   undotted element wins (the all-dot flag) *)
allDotSub[cands_, sub_, s_] := MCBAllDotQ[#["K"] & /@ cands[[sub]], s];

searchExact[red_, cands_, nmi_, keep_, maxTries_, tie_ : None, swap_ : Automatic] := Module[{As, ef, best = $Failed, bestScore = Infinity, poly, sc, tries = 0, bestDot = True,
    sw = If[swap === Automatic, keep, swap]},
  Do[
    tries++; If[tries > maxTries, Break[]];
    As = MCBSubsetDE[red, sub];
    If[As === $Failed, Continue[]];
    ef = MCBEpsFactorizedQ[As];
    If[ef[[1]], Return[MCBSimplifyBasis[red, cands, sub, sw], Module]];
    poly = MCBEpsPolynomialQ[As];
    sc = If[poly[[1]], poly[[2, 2]] - poly[[2, 1]], 100];
    If[sc < bestScore || (tie =!= None && sc == bestScore && sc < 100 && bestDot && ! allDotSub[cands, sub, tie]),
      bestScore = sc; If[tie =!= None, bestDot = allDotSub[cands, sub, tie]];
      best = <|"status" -> If[poly[[1]], "eps-polynomial", "rational"], "sub" -> sub, "range" -> poly[[2]], "A" -> As, "cands" -> cands[[sub]]|>],
    {sub, Subsets[keep, {nmi}]}];
  best];

$MCBEpsSamples = {3/7, 5/11, -2/13, 7/17, 11/19, -3/23, 13/29, 17/31};
$laurentRange = Range[-3, 3];
vInv := vInv = N[Inverse[Table[e^m, {e, $MCBEpsSamples[[1 ;; Length[$laurentRange]]]}, {m, $laurentRange}]], 40];
laurentFit[vals_List] := Module[{n = Length[$laurentRange], cf, sc},
  cf = vInv . vals[[1 ;; n]];
  sc = Max[Abs[vals], 10^-30];
  cf = If[Abs[#] < 10^-20 sc, 0, #] & /@ cf;
  If[Abs[cf . (N[$MCBEpsSamples[[n + 1]], 40]^$laurentRange) - vals[[n + 1]]] > 10^-15 sc, $Failed, cf]];

fastProfile[num_, sub_, nx_] := Module[{As, T, Ti},
  As = Table[
     T = num["T"][[ie]][[sub]];
     If[Abs[Det[T]] < 10^-25 Max[Abs[Flatten[T]]]^Length[sub], Return[$Failed, Module]];
     Ti = Inverse[T];
     Table[num["D"][[ie, ix]][[sub]] . Ti + DiagonalMatrix[num["g"][[ix]][[sub]]], {ix, nx}],
     {ie, Length[$MCBEpsSamples]}];
  Table[Map[laurentFit, Transpose[As[[All, ix]], {3, 1, 2}], {2}], {ix, nx}]];

fastScore[prof_] := Module[{fl, pw},
  If[prof === $Failed, Return[{$Failed, 1000}]];
  fl = Flatten[prof, 2];
  If[MemberQ[fl, $Failed], Return[{"rational", 100}]];
  pw = Flatten[Pick[$laurentRange, # =!= 0 & /@ #] & /@ fl];
  If[pw === {}, {"zero", 0}, {"poly", Max[pw] - Min[pw]}]];

(* Working precision of the numeric screening. The DE entries are ratios of large integers and the masters can be
   nearly dependent at the sample points, so inverting the matrices loses many digits: with 40 digits, spurious
   powers of eps survived the Laurent fit and eps-form subsets were scored as polynomial or rational. *)
$MCBScreenPrecision = 120;
(* how many of the best-scored subsets are re-examined exactly when the screening found no eps-form subset *)
$MCBExactRecheck = 12;

searchFast[red_, cands_, nmi_, keep_, maxTries_, tie_ : None, swap_ : Automatic] := Module[{num, nx = Length[red[[1]]["invariants"]], scored = {}, tries = 0, prof, sc, As, symA, best,
    sw = If[swap === Automatic, keep, swap]},
  num = <|"T" -> N[Table[red[[1]]["T"] /. eps -> e, {e, $MCBEpsSamples}], $MCBScreenPrecision],
          "D" -> N[Table[red[[1]]["D"][[ix]] /. eps -> e, {e, $MCBEpsSamples}, {ix, nx}], $MCBScreenPrecision],
          "g" -> N[red[[1]]["g"], $MCBScreenPrecision]|>;
  scored = Reap[Do[
    tries++; If[tries > maxTries, Break[]];
    prof = fastProfile[num, sub, nx];
    If[prof === $Failed, Continue[]];
    sc = fastScore[prof];
    If[sc[[1]] === "poly" && sc[[2]] <= 2,
      symA = Table[Map[Rationalize[#, 10^-12] . (eps^$laurentRange) &, prof[[ix]], {2}], {ix, nx}];
      If[MCBEpsFactorizedQ[symA][[1]],
        As = MCBSubsetDE[red, sub];
        If[As =!= $Failed && MCBEpsFactorizedQ[As][[1]], Return[MCBSimplifyBasis[red, cands, sub, sw], Module]]]];
    Sow[{sc[[2]], sub}],
    {sub, Subsets[keep, {nmi}]}]][[2]];
  scored = If[scored === {}, {}, First[scored]];
  If[scored === {}, Return[$Failed]];
  (* the screening is only a filter: decide exactly on the best few subsets, with the eps^k rescalings that
     MCBEpsFactorizedQ allows, before settling for an eps-polynomial basis *)
  scored = Take[SortBy[scored, First], UpTo[$MCBExactRecheck]];
  Do[As = MCBSubsetDE[red, x[[2]]];
    If[As =!= $Failed && MCBEpsFactorizedQ[As][[1]], Return[MCBSimplifyBasis[red, cands, x[[2]], sw], Module]],
    {x, scored}];
  best = scored[[1, 2]];
  (* a non-dlog sector: among the subsets with the best score, the first with an undotted element *)
  If[tie =!= None && scored[[1, 1]] < 100 && allDotSub[cands, best, tie],
    best = SelectFirst[Select[scored, #[[1]] == scored[[1, 1]] &], ! allDotSub[cands, #[[2]], tie] &, {0, best}][[2]]];
  As = MCBSubsetDE[red, best];
  With[{poly = MCBEpsPolynomialQ[As]},
    <|"status" -> If[poly[[1]], "eps-polynomial", "rational"], "sub" -> best, "range" -> poly[[2]], "A" -> As, "cands" -> cands[[best]]|>]];

MCBSearchBasis[red_List, cands_List, nmi_Integer, opts_Association : <||>] := Module[{keep, rk, tie, res = $Failed, run, tiers},
  If[red === $Failed || cands === {}, Return[$Failed]];
  (* pairs and singles are cheap to test exactly: keep many candidates there *)
  keep = keepIndependent[red, cands, Lookup[opts, "Cap", Which[nmi <= 2, 40, nmi <= 4, 22, True, 16]]];
  rk = If[keep === {}, 0, MatrixRank[red[[1]]["T"][[keep]] /. eps -> 3/7]];
  If[rk < nmi, Return[<|"status" -> "rank-deficient", "rank" -> rk|>]];
  tie = If[TrueQ[Lookup[opts, "NonDlog", False]], Replace[Lookup[opts, "Sector", Automatic], Automatic :> topSector[cands[[1]]["K"]]], None];
  run[k_] := If[nmi <= 2, searchExact[red, cands, nmi, k, Lookup[opts, "MaxTries", 20000], tie, keep],
    searchFast[red, cands, nmi, k, Lookup[opts, "MaxTries", 60000], tie, keep]];
  (* a dlog search tries the eps-pure candidates alone first, then those not known to be impure, and only then all of
     them: the first eps-form subset of the whole list can have an element that is not eps-pure while an eps-pure basis
     needs two swaps or more, which the simplification, one element at a time, does not make. The simplification may
     swap in any candidate. On a non-dlog sector purity decides nothing: one search *)
  tiers = If[tie =!= None, {},
    Select[DeleteDuplicates[{Select[keep, pureRank[cands[[#]]] == 0 &], Select[keep, pureRank[cands[[#]]] <= 1 &]}],
      Length[#] >= nmi && Length[#] < Length[keep] && MatrixRank[red[[1]]["T"][[#]] /. eps -> 3/7] >= nmi &]];
  Do[With[{r = run[t]}, If[AssociationQ[r] && r["status"] === "eps-form", res = r; Break[]]], {t, tiers}];
  If[res === $Failed, res = run[keep]];
  (* a basis whose DE was tested for an eps-factorised form (the first pass's DE checks) *)
  If[AssociationQ[res] && KeyExistsQ[res, "A"], MCBMarkToolUsed["CanonicalDE"]];
  res];


(* ::Section:: *)
(*The single gate: check any proposed basis*)


(* The Euler relation holds for any basis of homogeneous integrals, so it tests the DE itself: a failure means an
   element mixes mass dimensions, or the reductions or derivatives are wrong (validate_family.wls --scaling). An
   eps-form DE always passes it; the rules and the shared weight are reported only (see the usage). *)
MCBBasisChecks[fam_Association, masters_List, As_List, pts_List] := Module[{nx = Length[fam["InvList"]], checks, ws, eu},
  checks = MCBRulesCheck[fam, masters];
  ws = Lookup[SelectFirst[checks, #["Name"] === "weights" &, <||>], "Weights", Automatic];
  eu = If[Length[As] =!= nx Length[pts], <|"Pass" -> Missing["NotChecked"], "Message" -> "not checked: the DE does not have one matrix per invariant and point"|>,
    MCBEulerCheck[AssociationThread[fam["InvList"] -> #] & /@ Partition[As, nx], pts, fam["Invariants"], ws,
      <|"RowNames" -> Table["J" <> ToString[i], {i, Length[masters]}], "ColumnNames" -> Table["J" <> ToString[i], {i, Length[masters]}]|>]];
  Append[checks, <|"Name" -> "euler", "Pass" -> eu["Pass"], "Detail" -> eu["Message"]|>]];

MCBCheckBasis[fam_Association, s_List, masters_List, dir_String, opts_Association : <||>] := Module[{cands, pts, red, As, ef, poly, nx, res, ncut, checks},
  If[MCBSkippedQ["kira-check"], Return[<|"status" -> "skipped by user"|>]];
  cands = MCBSplitMaster /@ masters;
  If[MemberQ[cands, $Failed], Return[<|"status" -> "failed", "message" -> "a basis element is not of the form Sqrt[R] (rational combination)"|>]];
  pts = Lookup[opts, "Points", MCBPoints[fam, 2, Lookup[opts, "Seed", 1]]];
  red = MCBReduceCandidates[fam, s, cands, dir, pts];
  If[red === $Failed, Return[<|"status" -> "failed", "message" -> "Kira failed (see " <> dir <> ")", "points" -> pts|>]];
  ncut = Length[red[[1]]["masters"]];
  If[ncut != Length[cands],
    Return[<|"status" -> "failed", "points" -> pts, "nMastersCut" -> ncut, "cutMasters" -> red[[1]]["masters"],
      "message" -> "the basis has " <> ToString[Length[cands]] <> " elements but the maximal cut has " <> ToString[ncut] <> " masters " <> ToString[red[[1]]["masters"], InputForm]|>]];
  As = MCBSubsetDE[red, Range[Length[cands]]];
  If[As === $Failed, Return[<|"status" -> "failed", "points" -> pts, "nMastersCut" -> ncut, "cutMasters" -> red[[1]]["masters"],
      "message" -> "the basis elements are linearly dependent on the maximal cut"|>]];
  MCBMarkToolUsed["CanonicalDE"];   (* the basis has a DE, checked below for an eps-factorised form *)
  nx = Length[fam["InvList"]];
  checks = MCBBasisChecks[fam, masters, As, red[[All, "point"]]];
  res = <|"points" -> pts, "nMastersCut" -> ncut, "cutMasters" -> red[[1]]["masters"], "invariants" -> fam["InvList"], "checks" -> checks|>;
  If[Last[checks]["Pass"] === False,
    Return[Join[res, <|"status" -> "failed", "A" -> AssociationThread[fam["InvList"] -> Take[As, nx]],
      "message" -> "the maximal-cut DE breaks the Euler relation of homogeneous integrals: " <> Last[checks]["Detail"] <>
        " (an element mixes mass dimensions, or the reductions or derivatives are wrong: run validate_family.wls --scaling)"|>]]];
  ef = MCBEpsFactorizedQ[As];
  If[ef[[1]],
    Join[res, <|"status" -> "eps-form", "k" -> ef[[2]], "range" -> {1, 1},
      "A" -> AssociationThread[fam["InvList"] -> (MCBRescaleEps[#, ef[[2]]] & /@ Take[As, nx])],
      "pattern" -> Map[MCBEpsProfile, MCBRescaleEps[#, ef[[2]]] & /@ Take[As, nx], {3}],
      "message" -> If[AllTrue[ef[[2]], # == 0 &], "eps-factorised as written",
         "eps-factorised after J_i -> eps^k_i J_i with k = " <> ToString[ef[[2]]] <> " (multiply the elements by these powers)"]|>],
    poly = MCBEpsPolynomialQ[As];
    Join[res, <|"status" -> If[poly[[1]], "eps-polynomial", "rational"], "k" -> ConstantArray[0, Length[cands]], "range" -> poly[[2]],
      "A" -> AssociationThread[fam["InvList"] -> Take[As, nx]], "pattern" -> Map[MCBEpsProfile, Take[As, nx], {3}],
      "message" -> If[poly[[1]], "Laurent polynomial in eps, powers " <> ToString[poly[[2]]], "rational (non-polynomial) eps dependence"]|>]]];

MCBPrintDE[chk_Association] := Module[{},
  If[! KeyExistsQ[chk, "A"], Print["   (no DE: ", Lookup[chk, "message", chk["status"]], ")"]; Return[Null]];
  Print["   maximal-cut DE at ", ToString[First[chk["points"]], InputForm], ":"];
  KeyValueMap[Function[{X, A},
     Which[
       chk["status"] === "eps-form", Print["     A_", X, " / eps = ", ToString[Together[A/eps], InputForm]],
       chk["status"] === "eps-polynomial" && ListQ[chk["range"]],
         Print["     A_", X, " eps-coefficients ", chk["range"], ": ",
           ToString[Table[Map[Together[SeriesCoefficient[#, {eps, 0, m}]] &, A, {2}], {m, chk["range"][[1]], chk["range"][[2]]}], InputForm]],
       True, Print["     A_", X, " = ", ToString[Short[Together[A], 20], InputForm]]]],
    chk["A"]]];


End[];
EndPackage[];
