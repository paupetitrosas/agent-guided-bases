(* ::Package:: *)

(* ::Title:: *)
(*PoleFreeBasis`Rungs`: the escalation ladder*)


(* ::Text:: *)
(*1 rescale, 2 dot move, 3 pair scan, 4 residue fit, 5 numerator rewrite, 6 completion solver, 7 derivative*)
(*construction, 8 maximal-cut change, 9 flag. Every rung only proposes; the gate (Gate.wl) decides. See reference/escalation.md.*)


BeginPackage["PoleFreeBasis`Rungs`", {"PoleFreeBasis`", "PoleFreeBasis`Config`", "PoleFreeBasis`System`", "PoleFreeBasis`Slice`",
  "PoleFreeBasis`Census`", "PoleFreeBasis`Residues`", "PoleFreeBasis`Transform`",
  "MaximalCutBasis`", "SkillCore`Tools`", "SkillCore`Records`", "SkillCore`Pages`", "MaximalCutBasis`Family`", "MaximalCutBasis`Sectors`", "MaximalCutBasis`Rules`", "MaximalCutBasis`Derivatives`"}];

PFBSolveLinear::usage = "PFBSolveLinear[eqs, unknowns] solves a linear system over the rationals (FiniteFlow's sparse solver when available, else Gaussian elimination in the same order). Unknowns listed first are preferred: they are eliminated first, and the free parameters, the last ones, are set to 0. A solve by FiniteFlow marks it as used (MCBMarkToolUsed: the run's ledger, for the citation context's sector). Returns <|\"Status\" -> \"solved\" | \"impossible\", \"Solution\", \"Free\"|>.";
PFBRescaleSearch::usage = "PFBRescaleSearch[sys, sl, opts] (rung 1) looks for the smallest integer shifts n_i (U_i -> eps^n_i U_i) removing every negative power of eps, in every entry (entries with finite poles included); opts: \"MaxEpsDegree\" (default $PFBMaxEpsDegree: no entry may end above eps^cap, except entries above it before, which may only not rise; an entry with finite poles is measured at eps -> infinity, as the gate does), \"Upper\" (bounds on the highest power of the entries without finite poles after the shift, tried in order, each at most the cap; default 1, ..., cap, or {1, 2, 3, Automatic, Infinity} without a cap), \"Labels\" (masters allowed to move, default the non-frozen ones), \"Floors\" (<|{row, column} -> f|> in slice positions: those entries need only end at order >= f; the gate uses it for entries that were already negative). Diagonal entries do not move under a rescaling and are not constrained. Entries above the cap are bad entries too: the search first asks every entry to end at or below the cap (\"Strict\" -> True), and only when that is impossible lifts the negative powers without raising any entry (\"Strict\" -> False; \"AboveCapLeft\" counts the off-diagonal entries still above the cap). Returns <|\"Feasible\", \"Shifts\", \"Upper\", \"Strict\", \"AboveCapLeft\", \"Cycle\", \"MaxEpsDegree\"|>, and when it is infeasible within the cap \"MinimalCap\": the smallest cap that would make it feasible (None when no cap does: the negative powers alone are inconsistent).";
PFBDotCandidates::usage = "PFBDotCandidates[sys, red, label] (rung 2) lists the integrals of the master's own sector obtained from the dotted integrals of its definition by moving one dot to another propagator of the sector, numerators unchanged: the candidates for a replacement with the same maximal-cut class, to be ranked exactly on the slice with bin/slot_scan.wls. With red = None every candidate is returned; with a reduction only those in its pool, the others under \"NotInPool\" (add them with PoolExtra). Returns <|\"Dotted\", \"Candidates\", \"NotInPool\"|>.";
PFBNaturalIntegrals::usage = "PFBNaturalIntegrals[sys, red, key, opts] (rung 3) lists the natural integrals of the sector: its own integrals (no propagator pinched) with at most \"MaxWeight\" (default 1) extra dots plus numerator powers, lightest first, plus opts \"Extra\" (the candidates of the structural reading). They are the candidates of bin/pair_scan.wls, which tries them in two (or more) slots of the sector at once, exactly on the slice. With red = None every one is returned; with a reduction only those in its pool, the others under \"NotInPool\" (add them with PoolExtra). Returns <|\"Candidates\", \"NotInPool\", \"Weights\"|>.";
PFBNormaliseCandidate::usage = "PFBNormaliseCandidate[sys, an, expr, source] normalises a candidate (rungs 2 and 3) to the maximal-cut class of the master it replaces, from its analytic coefficients (an = PFBAnalyticCoefficients of an analytic job; expr one of its expressions, or its index): c = its coefficient on ut[source], a function of eps and the invariants. When c is a monomial in eps times a rational function of the invariants, \"Def\" is expr / c, whose coefficient on the source is exactly 1; otherwise c carries a factor such as (1 - 2 eps) (a hidden weight) and nothing is normalised. \"SameClass\" says whether its coefficients on the other masters reconstructed are zero. Returns <|\"Coefficient\", \"EpsMonomial\", \"EpsFactors\", \"SameClass\", \"Def\", \"Message\"|>.";
PFBPinchedCandidates::usage = "PFBPinchedCandidates[sys, red, key, opts] lists the pool integrals of the sector's family in proper subsectors of the sector (one or more propagators pinched, \"MaxPinched\" -> 1 by default): the candidates of the residue fit.";
PFBResidueFit::usage = "PFBResidueFit[sys, sl, red, cal, sources, testRows, cands, opts] (rung 4) fits the corrections m -> m + Sum c eps^p v so that the principal parts of the test rows vanish at every pole, on the slice. opts: \"Powers\" (list of eps powers, default {the source's power}). Returns <|\"Status\", \"Coefficients\" -> <|m -> {{v, p, c}..}|>, \"Integer\", \"Defs\"|>.";
PFBNumeratorFromFit::usage = "PFBNumeratorFromFit[sys, corner, terms] reads a fit made of single pinches of the corner integral, {{v, p, c}..}, as one numerator: <|\"D\" -> Sum c_i D_i, \"SP\" -> the same in scalar products, \"Power\" -> p|>, or $Failed.";
PFBNumeratorIntegrals::usage = "PFBNumeratorIntegrals[sys, corner, numerator] writes corner * numerator (a polynomial in MCBD[i]) as a combination of integrals.";
PFBNumeratorAsSP::usage = "PFBNumeratorAsSP[sys, fam, numerator] writes a polynomial in MCBD[i] in scalar products of the momenta (rung 5: completions such as N = D8 - D6 - D7 + D5 are scalar products linear in a loop momentum).";
PFBSPToNumerator::usage = "PFBSPToNumerator[sys, fam, expr] writes a polynomial in scalar products (products of momenta, as in family.wl) in terms of MCBD[i].";
PFBAnsatzMonomials::usage = "PFBAnsatzMonomials[sys, dim] lists the monomials in the invariants of mass dimension dim (empty for odd or negative dim). The completion solver tries them by PFBMonomialDegree, lowest first.";
PFBMonomialDegree::usage = "PFBMonomialDegree[sys, expr] is the degree of a monomial of the ansatz (or of any rational function of the invariants) in the invariants with the unit scale set to 1: the total degree of its numerator or of its denominator, the larger. Among unknowns that are equal in weight and power of eps, the completion solver prefers the lower degree.";
PFBCompletionSolve::usage = "PFBCompletionSolve[sys, reds, key, opts] (rung 6) solves for corrections h_i = base_i + Sum_{a,b,n} c eps^n phi_b(x) w_a with w_a pool integrals of lower sectors (all reduction points at once, x-independent unknowns c). Conditions per entry of the new rows: no principal part at any finite pole and (\"Target\" -> \"PoleFree\") no negative power of eps and none above eps^cap (\"MaxEpsDegree\", default $PFBMaxEpsDegree; entries above the cap are bad entries of the sector), or (\"EpsForm\") pure eps^1. When no solution brings every entry to the cap, it removes the poles alone, keeping the powers above the cap the current rows have (\"AboveCapKept\" -> True). opts: Base (<|label -> def|>, default the current masters; any basis of the sector with an invertible matrix on the current masters, whose own block is free of finite poles), Powers (eps powers of the corrections, default the master's lowest and one below), Monomials (default: every monomial of the right mass dimension), PoolSelect (a test on the pool integrals), SameFamily (True: each master is corrected with integrals of its own family), Tiers (True: try integrals of weight dots + numerator powers <= 0, 1, ... and keep the lightest solution), Sparsify (True: then drop the most complex integrals while a solution remains), MaxPool. Order: the configurations by weight, then by power of eps; within one, the unknowns by the dots, propagators, numerator powers and power of eps of their integral, then by the degree of their monomial (PFBMonomialDegree), so that the solution uses the lowest degree that works. Among the completions of equal weight the solver meets (its first solution and those it reaches while it drops integrals, whose integrals and monomials have the same complexities as the last one), the one whose new rows have the smallest digit height at the first reduction point (the slice point of a job; PFBDigitHeight) is returned, the last one on a tie. Returns <|\"Status\", \"Defs\", \"Free\", \"Unknowns\", \"Equations\", \"AboveCapKept\", \"Height\" (that digit height), \"EqualWeight\" (the completions of equal weight compared)|>.";
PFBGramFreeOperators::usage = "PFBGramFreeOperators[sys, fam, expr, opts] (rung 7) finds first-order operators O = Sum_k a_k(x) d_k, a_k polynomials of degree \"Degree\" (default 1) in the invariants, such that O(expr) has polynomial coefficients (no Gram denominators). opts: Invariants (default: those of the slice). Returns a list of operators {a_1, ..., a_n} paired with the invariants.";
PFBApplyOperator::usage = "PFBApplyOperator[sys, fam, op, def, pref] is the root-free definition of (1/pref) O(pref def) for op = {{x1, a1}, ...}.";
PFBOperatorVector::usage = "PFBOperatorVector[sys, sl, op, label] is the slice vector of (1/pref) O(pref U_label) at the slice point, computed from the slice alone.";
PFBDerivativeSearch::usage = "PFBDerivativeSearch[sys, sl, key, sources, opts] (rung 7) proposes replacing the source masters by derivatives O(U_c) of clean masters c of the sector, with Gram-free operators: it keeps the choices whose determinant on the sector block is not zero (coupling-rank check), fewest and smallest operators first. Returns a ranked list of <|\"Replace\", \"Ops\", \"Defs\", \"Det\"|>. (The option ReferenceDet was removed: passing it prints why and returns $Failed.)";
PFBMaxCutBasis::usage = "PFBMaxCutBasis[sys, key, defs] is the sector's basis on its base family as the maximal-cut-basis toolkit reads it (MCBCheckBasis, check_basis.wls): one expression per master of the base family in label order, the new ones from defs = <|label -> root-free def|>, the others unchanged, each with its square root and with ut[k] and Dinv[a, X] written out as integrals. PFBMaxCutBasis[sys, key] lists those labels.";
PFBWriteMCBBasisFile::usage = "PFBWriteMCBBasisFile[sys, key, defs, file] writes the sector's masters of its base family (new ones from defs = <|label -> root-free def|>, the others unchanged) in the format of the maximal-cut-basis skill (check_basis.wls), with explicit square roots. ut[k] terms (the current master k) and Dinv[a, X] (the derivative of a) are written out as integrals j[...], which is all the maximal-cut-basis toolkit reads.";

Begin["`Private`"];


(* ::Section:: *)
(*Linear algebra*)


PFBSolveLinear[eqs0_List, unk_List] := Module[{xs, toX, fromX, eqs, sol, free, ff},
  (* plain indexed unknowns for the solver, in the same order *)
  xs = Table[PoleFreeBasis`Rungs`Private`xv[i], {i, Length[unk]}];
  toX = Dispatch[Thread[unk -> xs]]; fromX = Thread[xs -> unk];
  eqs = DeleteCases[Expand /@ (eqs0 /. toX), 0];
  If[eqs === {}, Return[<|"Status" -> "solved", "Solution" -> Thread[unk -> 0], "Free" -> Length[unk]|>]];
  If[AnyTrue[eqs, FreeQ[#, PoleFreeBasis`Rungs`Private`xv] &], Return[<|"Status" -> "impossible", "Solution" -> {}, "Free" -> 0|>]];
  ff = PFBLoadFiniteFlow[];
  sol = If[TrueQ[ff],
     MCBQualify["FiniteFlow", "FFSparseSolve"][Thread[eqs == 0], xs, "Parameters" -> {}],
     gaussSolve[eqs, xs]];
  (* FiniteFlow is credited in the run's ledger when its solver gave the answer, not when the fallback did *)
  If[TrueQ[ff] && (ListQ[sol] || sol === MCBQualify["FiniteFlow", "FFImpossible"]), MCBMarkToolUsed["FiniteFlow"]];
  If[! ListQ[sol], Return[<|"Status" -> "impossible", "Solution" -> {}, "Free" -> 0|>]];
  free = Complement[xs, sol[[All, 1]]];
  sol = Join[sol /. Thread[free -> 0], Thread[free -> 0]];
  <|"Status" -> "solved", "Solution" -> ((sol /. fromX) /. (a_ -> b_) :> (a -> b)), "Free" -> Length[free]|>];


(* without FiniteFlow: sparse Gaussian elimination with the columns in the order given, as FFSparseSolve does, so that
   the order of the unknowns means the same with and without it (Solve would leave the first unknowns free). Each row is
   an Association column -> coefficient (the right-hand side under n + 1), with an index of the rows of each column.
   Forward elimination column by column: the pivot of a column is the shortest row without a pivot that has it, and the
   column is eliminated from the other such rows only. The pivots are the first independent columns (the unknowns
   solved for); the others are free and set to 0, and back substitution, last pivot first, gives the solution (the
   same whichever rows are chosen as pivots). Exact over the rationals, never dense *)
gaussSolve[eqs_List, xs_List] := Module[{n = Length[xs], b, A, rows, colRows = <||>, used = <||>, piv = <||>, nr, val = <||>},
  {b, A} = Take[CoefficientArrays[eqs, xs], 2];
  nr = Length[eqs];
  rows = Table[Association[Join[Cases[Most[ArrayRules[SparseArray[A[[r]]]]], ({c_Integer} -> v_) /; v =!= 0 :> (c -> v)], If[b[[r]] =!= 0, {n + 1 -> -b[[r]]}, {}]]], {r, nr}];
  Do[Scan[(colRows[#] = Append[Lookup[colRows, #, <||>], r -> True]) &, Keys[rows[[r]]]], {r, nr}];
  Do[Module[{cand = Select[Keys[Lookup[colRows, c, <||>]], ! KeyExistsQ[used, #] &], p, pr},
     If[cand === {}, Continue[]];
     p = First[SortBy[cand, {Length[rows[[#]]], #} &]];
     pr = rows[[p]]/rows[[p]][c];
     rows[[p]] = pr; used[p] = True; piv[c] = p;
     Do[If[q =!= p, Module[{f = rows[[q]][c], nw},
        nw = Select[Merge[{rows[[q]], -f pr}, Total], # =!= 0 &];
        Do[If[KeyExistsQ[nw, k], colRows[k] = Append[Lookup[colRows, k, <||>], q -> True], If[KeyExistsQ[colRows, k], colRows[k] = KeyDrop[colRows[k], q]]], {k, Keys[pr]}];
        rows[[q]] = nw]], {q, cand}]], {c, n}];
  (* a row left without a pivot keeps only its right-hand side: the system is inconsistent when one is not 0 *)
  If[AnyTrue[Complement[Range[nr], Keys[used]], rows[[#]] =!= <||> &], Return[$Failed]];
  (* a pivot row holds its column and later ones only *)
  Do[With[{r = rows[[piv[c]]]}, val[c] = Lookup[r, n + 1, 0] - Total[KeyValueMap[If[#1 > c && #1 <= n, #2 Lookup[val, #1, 0], 0] &, r]]], {c, Reverse[Sort[Keys[piv]]]}];
  Table[xs[[c]] -> val[c], {c, Sort[Keys[piv]]}]];


(* ::Section:: *)
(*Rung 1: uniform powers of eps*)


(* difference constraints: entry {lo, hi} becomes {lo + n_r - n_c, hi + n_r - n_c}; lo' >= 0 is n_c - n_r <= lo,
   hi' <= u is n_r - n_c <= u - hi. Bellman-Ford from a virtual source; frozen masters are pinned to 0. *)
bellmanFord = Compile[{{n, _Integer}, {from, _Integer, 1}, {to, _Integer, 1}, {w, _Integer, 1}},
   Module[{d = Table[0, {n}], pred = Table[0, {n}], changed = True, it = 0, m = Length[from], last = 0},
    While[changed && it <= n, changed = False; it++;
     Do[If[d[[from[[e]]]] + w[[e]] < d[[to[[e]]]], d[[to[[e]]]] = d[[from[[e]]]] + w[[e]]; pred[[to[[e]]]] = from[[e]]; changed = True; last = to[[e]]], {e, m}]];
    Join[d, pred, {If[changed, last, 0]}]]];

PFBRescaleSearch[sys_Association, sl_Association, opts_Association : <||>] := Module[{labs = sl["Labels"], n, lo, hi, mov, pinned, consFor, cycleOf, solve, uppers,
    res = <|"Feasible" -> False|>, big = 1000, cap = Lookup[opts, "MaxEpsDegree", $PFBMaxEpsDegree], runUppers, hiP},
  n = Length[labs];
  mov = Lookup[opts, "Labels", Select[labs, ! PFBFrozenQ[sys, PFBMaster[sys, #]["Family"]] &]];
  pinned = sl["Index"] /@ Complement[labs, mov];
  lo = <||>; hi = <||>; hiP = <||>;
  (* the order at eps = 0 of every entry, finite poles or not, must end up >= 0; the bound on the highest power (the eps
     profile) is taken from the entries without finite poles. Those with finite poles (hiP, their degree at
     eps -> infinity) only must not end above the cap, or rise when they are above it already: the gate's measure *)
  Do[With[{f = sl["R"][[k, r, c]]}, If[f =!= 0 && r =!= c, With[{rg = PFBEpsOrders[f]},
       lo[{r, c}] = Min[Lookup[lo, Key[{r, c}], Infinity], rg[[1]]];
       If[PFBEpsFactors[f] === {}, hi[{r, c}] = Max[Lookup[hi, Key[{r, c}], -Infinity], rg[[2]]],
         hiP[{r, c}] = Max[Lookup[hiP, Key[{r, c}], -Infinity], rg[[2]]]]]]],
    {k, Length[sl["R"]]}, {r, n}, {c, n}];
  (* constraints {a, b, w}: x_a - x_b <= w.  lo' >= 0: x_c - x_r <= lo;  hi' <= u: x_r - x_c <= u - hi *)
  (* "Floors" -> <|{r, c} -> f|> (slice positions): the entry must end at order >= f instead of >= 0 *)
  (* the bound u is at most the cap cp. Strict: every entry ends at or below it, those above the cap now included (they
     are bad entries); otherwise an entry above the cap only must not rise: hi' <= hi *)
  consFor[u_, cp_ : cap, strict_ : False] := With[{ue = Min[u, cp]}, Join[KeyValueMap[{#1[[2]], #1[[1]], #2 - Lookup[Lookup[opts, "Floors", <||>], Key[#1], 0]} &, lo],
    If[ue === Infinity, {}, KeyValueMap[{#1[[1]], #1[[2]], If[#2 > cp && ! strict, 0, ue - #2]} &, hi]],
    If[cp === Infinity, {}, KeyValueMap[{#1[[1]], #1[[2]], Max[cp, #2] - #2} &, hiP]]]];
  (* an inconsistent set of constraints is a negative cycle; vertex n+1 is the reference the pinned masters are tied to *)
  cycleOf[cons_] := Module[{es = Join[{#[[2]], #[[1]], #[[3]]} & /@ cons, Table[{n + 1, i, big}, {i, n}], Table[{i, n + 1, big}, {i, n}],
       Table[{n + 1, i, 0}, {i, pinned}], Table[{i, n + 1, 0}, {i, pinned}]], out, pred, last, v},
    out = bellmanFord[n + 1, es[[All, 1]], es[[All, 2]], es[[All, 3]]];
    pred = out[[n + 2 ;; 2 n + 2]]; last = out[[-1]];
    If[last === 0, None,
      v = last; Do[v = pred[[v]], {n + 1}];
      Module[{c = {v}, w = pred[[v]]}, While[w =!= v && Length[c] <= n + 1, AppendTo[c, w]; w = pred[[w]]]; labs[[Select[Reverse[c], # <= n &]]]]]];
  (* smallest shifts: minimise Sum |x| (x = p - q) with the pinned masters at 0; the matrix is totally unimodular *)
  solve[cons_] := Module[{mv = Complement[Range[n], pinned], pos, m, b, rows = {}, sol, x},
    pos = AssociationThread[mv -> Range[Length[mv]]];
    Do[With[{a = Lookup[pos, cn[[1]], None], bb = Lookup[pos, cn[[2]], None]},
       If[a === None && bb === None, If[cn[[3]] < 0, Return[$Failed, Module]]; Continue[]];
       AppendTo[rows, {a, bb, cn[[3]]}]], {cn, cons}];
    m = SparseArray[Flatten[Table[With[{rw = rows[[q]]}, Join[
          If[rw[[1]] =!= None, {{q, rw[[1]]} -> -1, {q, Length[mv] + rw[[1]]} -> 1}, {}],
          If[rw[[2]] =!= None, {{q, rw[[2]]} -> 1, {q, Length[mv] + rw[[2]]} -> -1}, {}]]], {q, Length[rows]}], 1], {Length[rows], 2 Length[mv]}];
    b = -rows[[All, 3]];
    sol = Quiet@LinearProgramming[ConstantArray[1, 2 Length[mv]], m, b, Method -> "Simplex"];
    If[! VectorQ[sol, NumericQ], Return[$Failed]];
    x = Round[sol[[1 ;; Length[mv]]] - sol[[Length[mv] + 1 ;; 2 Length[mv]]]];
    Association[Select[Table[labs[[mv[[i]]]] -> x[[i]], {i, Length[mv]}], #[[2]] =!= 0 &]]];
  (* the tightest bound on the highest power that works: profiles as close to eps^1 as the couplings allow *)
  uppers = Lookup[opts, "Upper", If[cap === Infinity, {1, 2, 3, Automatic, Infinity}, Range[cap]]] /. Automatic -> Max[Append[Values[hi], 1]];
  (* first every entry at or below the cap (entries above it brought down too); when that is impossible, the negative
     powers lifted without raising any entry above the cap, or above its own power when it is already there *)
  runUppers[strict_] := (res = <|"Feasible" -> False|>;
    Do[Module[{cons = consFor[u, cap, strict], cyc, sh},
       cyc = cycleOf[cons];
       If[cyc =!= None, res = <|"Feasible" -> False, "Upper" -> u, "Cycle" -> cyc,
           "Message" -> "inconsistent: the shifts around this cycle of couplings cannot all be satisfied" <> If[cap === Infinity, "", " within the cap eps^" <> ToString[cap]]|>; Continue[]];
       sh = solve[cons];
       If[sh === $Failed, res = <|"Feasible" -> False, "Upper" -> u, "Message" -> "no integer solution found"|>; Continue[]];
       res = <|"Feasible" -> True, "Upper" -> u, "Shifts" -> sh, "Strict" -> strict|>; Break[]], {u, uppers}];
    res);
  runUppers[True];
  If[! res["Feasible"] && cap =!= Infinity && AnyTrue[Values[hi], # > cap &], With[{first = res}, runUppers[False]; If[! res["Feasible"], res = first]]];
  (* off-diagonal entries without finite poles that stay above the cap after the shifts (the diagonal does not move) *)
  If[res["Feasible"] && cap =!= Infinity,
    res["AboveCapLeft"] = Count[KeyValueMap[#2 + Lookup[res["Shifts"], labs[[#1[[1]]]], 0] - Lookup[res["Shifts"], labs[[#1[[2]]]], 0] &, hi], d_ /; d > cap]];
  If[res["Feasible"] && res["Shifts"] === <||>, res["Message"] = "no uniform eps^k improves the slice: nothing to try at rung 1"];
  (* infeasible within the cap: the smallest cap that would do (difference constraints are feasible exactly when they
     have no negative cycle), for the user to decide on; None when no cap does *)
  If[! res["Feasible"] && cap =!= Infinity,
    res["MinimalCap"] = If[cycleOf[consFor[Infinity, Infinity]] =!= None, None,
      SelectFirst[Range[cap + 1, cap + 12], cycleOf[consFor[#, #]] === None &, Infinity]];
    If[res["MinimalCap"] =!= None, res["Message"] = Lookup[res, "Message", "infeasible"] <> "; feasible with a cap of " <>
       If[res["MinimalCap"] === Infinity, "more than eps^" <> ToString[cap + 12], "eps^" <> ToString[res["MinimalCap"]]] <>
       " (run.wl \"MaxEpsDegree\": only with the user's agreement)"]];
  Append[res, "MaxEpsDegree" -> cap]];


(* ::Section:: *)
(*Rung 2: move a dot*)


PFBDotCandidates[sys_Association, red_, lab_] := Module[{m = PFBMaster[sys, lab], fn, sec, ints, dotted, moves, cands, pool},
  {fn, sec} = m["SectorKey"];
  (* the integrals of the definition that lie in the master's own sector, and among them the dotted ones *)
  ints = Union[Cases[{m["RootFree"]}, jj_j /; jj[[1]] === fn && SectorOf[jj] === sec, Infinity]];
  dotted = Select[ints, Max[List @@ Rest[#]] >= 2 &];
  (* one dot moved from propagator a (index >= 2) to another propagator b of the sector (index >= 1) *)
  moves = Flatten[Table[With[{v = List @@ Rest[jj]},
      Table[If[a =!= b && v[[a]] >= 2 && v[[b]] >= 1, j[fn, Sequence @@ (v - UnitVector[Length[v], a] + UnitVector[Length[v], b])], Nothing],
        {a, Length[v]}, {b, Length[v]}]], {jj, dotted}]];
  cands = Complement[Union[moves], ints];
  pool = If[AssociationQ[red], red["Pool"], None];
  <|"Dotted" -> dotted, "Candidates" -> If[pool === None, cands, Select[cands, MemberQ[pool, #] &]],
    "NotInPool" -> If[pool === None, {}, Select[cands, ! MemberQ[pool, #] &]]|>];


(* the normalisation of a moved dot or of a scanned integral, from coefficients reconstructed as functions (never guessed
   from their values at a few reduction points) *)
PFBNormaliseCandidate[sys_Association, an_Association, e_, source_Integer] := Module[{i, c, col, others, efs},
  i = If[IntegerQ[e], e, FirstPosition[an["Exprs"], _?(Together[# - e] === 0 &), {None}, {1}][[1]]];
  If[i === None, Return[<|"Message" -> "the expression is not one of the analytic job's"|>]];
  col = FirstPosition[an["Masters"], ut[source], {None}, {1}][[1]];
  If[col === None, Return[<|"Message" -> "ut[" <> ToString[source] <> "] was not reconstructed (give it in \"Masters\")"|>]];
  c = Factor[an["Coefficients"][[i, col]]];
  others = Delete[an["Coefficients"][[i]], col];
  efs = Select[Join[FactorList[Numerator[c]][[All, 1]], FactorList[Denominator[c]][[All, 1]]], ! FreeQ[#, eps] && # =!= eps &];
  <|"Coefficient" -> c, "EpsMonomial" -> (c =!= 0 && efs === {}), "EpsFactors" -> efs, "SameClass" -> AllTrue[others, # === 0 &],
    "Def" -> Which[c === 0 || efs =!= {}, Missing["NotMonomial"], an["Fix"] =!= {}, Missing["FixedInvariants", an["Fix"]],
      True, Collect[an["Exprs"][[i]]/c, _j, Factor]],
    "Message" -> Which[c === 0, "no component on the source", efs =!= {}, "the coefficient carries " <> ToString[efs, InputForm] <> ": a hidden weight, not a normalisation",
      an["Fix"] =!= {}, "reconstructed with " <> ToString[an["Fix"], InputForm] <> " fixed: reconstruct without Fix to normalise", True, "normalised: coefficient 1 on the source"]|>];


(* ::Section:: *)
(*Rung 3: pairs of natural integrals*)


(* the sector's own integrals with w extra dots plus numerator powers in total (numerators on any index that is not a
   propagator of the sector, as in the pool of the runner) *)
naturalOf[fn_, sec_List, w_Integer] := Module[{prp = Flatten@Position[sec, 1], zer = Flatten@Position[sec, 0], n = Length[sec]},
  Flatten[Table[j[fn, Sequence @@ (sec + Sum[dv[[q]] UnitVector[n, prp[[q]]], {q, Length[prp]}] - Sum[nv[[q]] UnitVector[n, zer[[q]]], {q, Length[zer]}])],
    {nv, Select[Tuples[Range[0, w], Length[zer]], Total[#] <= w &]}, {dv, Select[Tuples[Range[0, w], Length[prp]], Total[#] + Total[nv] == w &]}]]];

PFBNaturalIntegrals[sys_Association, red_, {fn_, sec_List}, opts_Association : <||>] := Module[{w = Lookup[opts, "MaxWeight", 1], all, pool, wt},
  wt[jj_j] := Total[Select[List @@ Rest[jj], # > 1 &] - 1] + Total[-Select[List @@ Rest[jj], # < 0 &]];
  all = DeleteDuplicates[Join[Flatten[Table[naturalOf[fn, sec, k], {k, 0, w}]], Lookup[opts, "Extra", {}]]];
  pool = If[AssociationQ[red], red["Pool"], None];
  <|"Candidates" -> If[pool === None, all, Select[all, MemberQ[pool, #] || ! MatchQ[#, _j] &]],
    "NotInPool" -> If[pool === None, {}, Select[all, MatchQ[#, _j] && ! MemberQ[pool, #] &]],
    "Weights" -> Association[(# -> If[MatchQ[#, _j], wt[#], Missing["NotAnIntegral"]]) & /@ all]|>];


(* ::Section:: *)
(*Rung 4: residue fit*)


PFBPinchedCandidates[sys_Association, red_Association, {fn_, sec_List}, opts_Association : <||>] := Module[{mp = Lookup[opts, "MaxPinched", 1], fams},
  fams = Join[{fn}, If[TrueQ[Lookup[opts, "Images", False]], PFBImagesOf[sys, fn], {}]];
  Select[red["Pool"], Function[jj, MemberQ[fams, jj[[1]]] && With[{s = SectorOf[jj]}, subOf[s, sec] && 1 <= Total[sec - s] <= mp]]]];
subOf[v_, w_] := And @@ Thread[v <= w];

PFBResidueFit[sys_Association, sl_Association, red_Association, cal_Association, srcs_List, oth_List, cands_List, opts_Association : <||>] := Module[{R = sl["R"], ix = sl["Index"],
    nk = Length[sl["R"]], cols, vecs, pw, unk, eqs, poles, res, coef, defs, lcache, lcv, okFam},
  pw[m_] := Lookup[opts, "Powers", {Max[DeleteCases[Flatten[PFBEpsPowers[PFBMaster[sys, m]["RootFree"]][[All, 2]]], _String] /. {} -> {0}]}];
  cols = Complement[sl["Labels"], srcs, oth];
  vecs = Association[Table[v -> PFBExprVector[sys, sl, red, cal, v], {v, cands}]];
  If[MemberQ[Values[vecs], $Failed], Return[<|"Status" -> "failed", "Message" -> "candidates outside the reduction pool"|>]];
  (* each source is corrected with integrals of its own family unless "SameFamily" -> False *)
  okFam[m_, q_] := ! TrueQ[Lookup[opts, "SameFamily", True]] || cands[[q, 1]] === PFBMaster[sys, m]["Family"];
  unk = Flatten[Table[If[okFam[m, q], PoleFreeBasis`Rungs`Private`cc[m, q, p], Nothing], {m, srcs}, {q, Length[cands]}, {p, pw[m]}]];
  poles = Union[Flatten[Table[PFBFinitePoles[R[[k, ix[r], ix[c]]]], {k, nk}, {r, oth}, {c, cols}]]];
  If[poles === {}, Return[<|"Status" -> "pole-free", "Message" -> "the test rows have no poles"|>]];
  lcache = <||>;
  lcv[f_, e0_, n_] := With[{key = {f, e0, n}}, If[KeyExistsQ[lcache, key], lcache[key], lcache[key] = PFBLaurent[f, e0, n]]];
  (* the principal part of A_rm (eps^p v_q)_c at e0, in full: with pole orders pf of A_rm and pg of the candidates, the
     product's coefficient of order n sums i from -pf to n + pg, and the orders down to -(pf + pg) must match too *)
  eqs = Flatten[Table[Module[{nn, pf, pg},
       pf = Max[0, Max[Table[PFBPoleOrder[R[[k, ix[r], ix[m]]], e0], {k, nk}, {r, oth}, {m, srcs}]]];
       pg = Max[0, Max[Table[PFBPoleOrder[eps^p vecs[cands[[q]]][[ix[c]]], e0], {q, Length[cands]}, {c, cols}, {p, Union[Flatten[pw /@ srcs]]}]]];
       nn = Max[1, pf + pg, Max[Table[PFBPoleOrder[R[[k, ix[r], ix[c]]], e0], {k, nk}, {r, oth}, {c, cols}]]];
       Table[With[{Arm = Table[R[[k, ix[r], ix[m]]], {m, srcs}]},
         lcv[R[[k, ix[r], ix[c]]], e0, n] - Sum[With[{m = srcs[[im]]},
             Sum[If[okFam[m, q], Sum[lcv[Arm[[im]], e0, i] lcv[eps^p vecs[cands[[q]]][[ix[c]]], e0, n - i] PoleFreeBasis`Rungs`Private`cc[m, q, p], {i, -pf, n + pg}], 0],
               {q, Length[cands]}, {p, pw[m]}]], {im, Length[srcs]}]],
         {k, nk}, {r, oth}, {c, cols}, {n, -nn, -1}]], {e0, poles}]];
  res = PFBSolveLinear[eqs, unk];
  If[res["Status"] =!= "solved", Return[<|"Status" -> "no solution", "Poles" -> poles, "Equations" -> Length[eqs], "Unknowns" -> Length[unk]|>]];
  coef = Association[Table[m -> Select[Flatten[Table[{cands[[q]], p, PoleFreeBasis`Rungs`Private`cc[m, q, p] /. res["Solution"] /. PoleFreeBasis`Rungs`Private`cc[__] -> 0}, {q, Length[cands]}, {p, pw[m]}], 1], #[[3]] =!= 0 &], {m, srcs}]];
  defs = Association[Table[m -> PFBMaster[sys, m]["RootFree"] + Total[(#[[3]] eps^#[[2]] #[[1]]) & /@ coef[m]], {m, srcs}]];
  <|"Status" -> "solved", "Coefficients" -> coef, "Free" -> res["Free"], "Integer" -> AllTrue[Flatten[Values[coef][[All, All, 3]]], IntegerQ],
    "Defs" -> defs, "Poles" -> poles, "Fitted" -> True, "Message" -> "coefficients fitted at the slice point only: check at two more points before accepting"|>];

PFBNumeratorFromFit[sys_Association, corner_j, terms_List] := Module[{fo = PFBFamily[sys, corner[[1]]], idx = List @@ Rest[corner], nd = 0, p},
  If[terms === {}, Return[$Failed]];
  p = Union[terms[[All, 2]]];
  If[Length[p] > 1, Return[$Failed]];
  (* every term must be the corner with one propagator pinched, in the corner's family; otherwise there is no numerator *)
  If[! AllTrue[terms, Function[t, With[{d = idx - List @@ Rest[t[[1]]]},
       t[[1, 1]] === corner[[1]] && Count[d, 1] === 1 && Count[d, 0] === Length[d] - 1]]], Return[$Failed]];
  Do[nd += t[[3]] MCBD[First[Flatten[Position[idx - List @@ Rest[t[[1]]], 1]]]], {t, terms}];
  <|"D" -> nd, "SP" -> PFBNumeratorAsSP[sys, corner[[1]], nd], "Power" -> First[p]|>];


(* ::Section:: *)
(*Rung 5: numerators*)


PFBNumeratorAsSP[sys_Association, fn_, num_] := Module[{fo = PFBFamily[sys, fn]},
  Expand[num /. MCBD[i_] :> MCBToSP[fo, fo["Propagators"][[i]]["Expr"]]]];

PFBSPToNumerator[sys_Association, fn_, expr_] := Module[{fo = PFBFamily[sys, fn]},
  If[fo["SPtoD"] === $Failed, Return[$Failed]];
  Expand[MCBToSP[fo, expr] /. fo["SPtoD"]]];

PFBNumeratorIntegrals[sys_Association, corner_j, num_] := Module[{fo = PFBFamily[sys, corner[[1]]], n, terms, idx = List @@ Rest[corner]},
  n = fo["N"];
  terms = If[Head[Expand[num]] === Plus, List @@ Expand[num], {Expand[num]}];
  Total[Table[Module[{pows = Table[Exponent[t, MCBD[i]], {i, n}], c},
      c = t /. MCBD[_] -> 1;
      c j[corner[[1]], Sequence @@ (idx - pows)]], {t, terms}]]];


(* ::Section:: *)
(*Rung 6: completion solver*)


PFBAnsatzMonomials[sys_Association, dim_] := Module[{fo = PFBFamily[sys, First[sys["Order"]]], invs, dims},
  invs = fo["InvList"]; dims = Lookup[fo["Invariants"], invs];
  If[! IntegerQ[dim] || dim < 0, Return[{}]];
  If[dim == 0, Return[{1}]];
  Times @@@ (invs^# & /@ Select[Tuples[Range[0, Ceiling[dim/Min[dims]]], Length[invs]], #.dims == dim &])];

PFBMonomialDegree[sys_Association, ex_] := Module[{fo = PFBFamily[sys, First[sys["Order"]]], xs, f, deg},
  xs = DeleteCases[fo["InvList"], fo["UnitScale"]];
  f = Together[ex /. fo["UnitScale"] -> 1];
  deg[p_] := If[xs === {} || FreeQ[p, Alternatives @@ xs], 0, Max[Total /@ CoefficientRules[p, xs][[All, 1]]]];
  If[f === 0, 0, Max[deg[Numerator[f]], deg[Denominator[f]]]]];

coefDim[sys_, fn_, expr_] := Module[{fo = PFBFamily[sys, fn], e = Collect[expr, _j], jl},
  jl = Cases[Variables[e], _j];
  If[jl === {}, Return[$Failed]];
  MCBDimensionOf[fo, Coefficient[e, First[jl]] /. eps -> 1] + PFBIntegralDimension[sys, First[jl]]];

ppAt[f_, e0_] := Module[{d, s}, If[f === 0, Return[<||>]]; s = Series[Together[f /. eps -> e0 + d], {d, 0, -1}];
   If[Head[s] =!= SeriesData, <||>, Select[Association[Thread[Range[s[[4]], s[[4]] + Length[s[[3]]] - 1]/s[[6]] -> s[[3]]]], # =!= 0 &]]];
lowAt0[f_, top_] := Module[{d, s}, If[f === 0, Return[<||>]]; s = Series[Together[f /. eps -> d], {d, 0, top}];
   If[Head[s] =!= SeriesData, If[FreeQ[s, d] && 0 <= top, <|0 -> s|>, <||>], Select[Association[Thread[Range[s[[4]], s[[4]] + Length[s[[3]]] - 1]/s[[6]] -> s[[3]]]], # =!= 0 &]]];
highAtInf[f_, lowest_] := Module[{w, s}, If[f === 0, Return[<||>]]; s = Series[Together[f /. eps -> 1/w], {w, 0, -lowest}];
   If[Head[s] =!= SeriesData, If[FreeQ[s, w] && 0 >= lowest, <|0 -> s|>, <||>], Select[Association[Thread[-Range[s[[4]], s[[4]] + Length[s[[3]]] - 1]/s[[6]] -> s[[3]]]], # =!= 0 &]]];

PFBCompletionSolve[sys_Association, reds_List, key_List, opts_Association : <||>] := Module[{target = Lookup[opts, "Target", "PoleFree"], Sm, base, pref, pw, nmax, ztop, conds, wgt, tierU, minPow, off, offs,
    unk = {}, addC, addK, phi, sel, sel1, eqs, ordered, res, corr, defs, failure, t0 = AbsoluteTime[], cap = Lookup[opts, "MaxEpsDegree", $PFBMaxEpsDegree],
    keepA = <||>, condA, eqsKeep, tiers, kept = False, at1, cx, mdeg, prof, heightOf, visited, same, height},
  If[! AllTrue[Flatten[#["Masters"] & /@ reds], MatchQ[#, _ut] &],
    Return[<|"Status" -> "failed", "Message" -> "the reductions have masters that are not masters of the system: remove them first (bin/extra_masters.wls), or close the subtrees (bin/relation_sector.wls)"|>]];
  Sm = Select[PFBSectorMasters[sys, key], MemberQ[reds[[1]]["Focus"], #] &];
  If[Sm === {}, Return[<|"Status" -> "failed", "Message" -> "the sector's masters are not in the reductions' focus"|>]];
  base = Join[Association[Table[m -> PFBMaster[sys, m]["RootFree"], {m, Sm}]], Lookup[opts, "Base", <||>]];
  pref = Association[Table[m -> PFBMaster[sys, m]["Pref"], {m, Sm}]];
  (* eps powers of the corrections: no eps in a denominator beyond the master's own uniform normalisation (rule 3 allows
     a uniform eps^k with k < 0, as in maximal-cut bases written with 1/eps^k); for masters with non-negative powers this
     is the old rule, never negative *)
  pw[m_] := Module[{p = DeleteCases[Flatten[PFBEpsPowers[base[m]][[All, 2]]], _String]},
    Select[Lookup[opts, "Powers", If[p === {}, {0}, {Min[p] - 1, Min[p]}]], # >= Min[0, If[p === {}, 0, Min[p]]] &]];
  nmax = Max[Flatten[pw /@ Sm]] + 2;
  (* conditions are collected as {key, unknown or 1, value} and summed per key at the end *)
  addC[key2_, u_, v_] := If[v =!= 0, Sow[{key2, u, v}, "cond"]];
  addK[key2_, v_] := If[v =!= 0, Sow[{key2, 1, v}, "cond"]];
  {failure, conds} = Reap[Catch[Do[Module[{rd = reds[[ip]], mast, P, ders, Spos, Lpos, fpos, idx, H0, dH0, A, rhs0, e0s, dl, vecP, dvecP, phiv, dphiv, contrib, expF, nk,
      ceil, ceilT, infLow},
     mast = rd["Masters"]; P = rd["Point"]; ders = rd["Invariants"]; nk = Length[ders];
     Spos = Flatten[Position[mast, ut[#]] & /@ Sm]; Lpos = Complement[Range[Length[mast]], Spos];
     fpos = Flatten[Position[rd["Focus"], #] & /@ Sm];
     idx = AssociationThread[rd["Pool"] -> Range[Length[rd["Pool"]]]];
     vecP[ex_] := Module[{e = Collect[Expand[ex], _j], jl}, jl = Union[Cases[{e}, _j, Infinity]];
       If[! SubsetQ[rd["Pool"], jl], Return[$Failed]]; Together[Sum[(Coefficient[e, jj] /. P) rd["Rp"][[idx[jj]]], {jj, jl}]]];
     dvecP[ex_, k_] := Module[{e = Collect[Expand[ex], _j], jl}, jl = Union[Cases[{e}, _j, Infinity]];
       Together[Sum[(D[Coefficient[e, jj], ders[[k]]] /. P) rd["Rp"][[idx[jj]]] + (Coefficient[e, jj] /. P) rd["dRp"][[k, idx[jj]]], {jj, jl}]]];
     dl[m_, k_] := Together[D[pref[m]^2, ders[[k]]]/(2 pref[m]^2)] /. P;
     (* the base masters: the current ones (their rows are the focus rows) or given expressions reduced with the pool *)
     H0 = Table[If[base[m] === PFBMaster[sys, m]["RootFree"], UnitVector[Length[mast], First[Flatten[Position[mast, ut[m]]]]], vecP[base[m]]], {m, Sm}];
     If[MemberQ[H0, $Failed], Throw[<|"Status" -> "failed", "Message" -> "base integrals outside the pool of reduction " <> ToString[ip]|>]];
     dH0 = Table[If[base[Sm[[i]]] === PFBMaster[sys, Sm[[i]]]["RootFree"], rd["Dm"][[k, fpos[[i]]]], Together[dvecP[base[Sm[[i]]], k] + dl[Sm[[i]], k] H0[[i]]]], {k, nk}, {i, Length[Sm]}];
     (* the base's own block: with T = H0 on the sector masters, dT + T A_current = dH0 there, so A_base = dH0 T^-1.
        It is the current block only when the base is the current basis, or a uniform eps^k of it *)
     A = With[{Ti = Quiet@Check[Together[Inverse[H0[[All, Spos]]]], $Failed]},
       If[Ti === $Failed, Throw[<|"Status" -> "failed", "Message" -> "the base masters are not independent on the sector's masters"|>]];
       Table[Together[dH0[[k, All, Spos]] . Ti], {k, nk}]];
     If[AnyTrue[Flatten[A], PFBEpsFactors[#] =!= {} &], Throw[<|"Status" -> "failed", "Message" -> "the sector's own block has finite poles: change its maximal-cut basis first (rung 8)"|>]];
     (* correction pool: lower integrals (no component on the sector); optionally sector integrals with an exact zero class *)
     sel = Select[Range[Length[rd["Pool"]]], AllTrue[rd["Rp"][[#, Spos]], # === 0 &] && AnyTrue[rd["Rp"][[#, Lpos]], # =!= 0 &] &&
         TrueQ[Lookup[opts, "PoolSelect", (True &)][rd["Pool"][[#]]]] &];
     If[ip == 1, sel1 = Take[sel, UpTo[Lookup[opts, "MaxPool", 400]]]; PFBPrint["completion: ", Length[sel1], " correction integrals, sector ", PFBSectorString[key]]];
     rhs0 = Table[Together[dH0[[k, i, Lpos[[l]]]] - Sum[A[[k, i, m]] H0[[m, Lpos[[l]]]], {m, Length[Sm]}]], {k, nk}, {i, Length[Sm]}, {l, Length[Lpos]}];
     (* the first point (the slice point of a job): what the digit height of a completion's new rows needs *)
     If[ip == 1, at1 = <|"Reduction" -> rd, "Index" -> idx, "Point" -> P, "Invariants" -> ders, "Lpos" -> Lpos, "A" -> A, "Rhs" -> rhs0|>];
     e0s = Union[Flatten[{PFBFinitePoles /@ Flatten[{rd["Rp"][[sel1, Lpos]], rd["dRp"][[All, sel1, Lpos]], rhs0}]}]];
     (* at eps = 0, a term eps^n' f (n' = n, or n plus a power of A) needs the orders of f up to -n' *)
     ztop = Max[0, -(Min[Flatten[pw /@ Sm]] + Min[Append[Exponent[Expand[#], eps, Min] & /@ DeleteCases[Flatten[A], 0], 0]])];
     (* the highest power of eps an entry {k, i, l} may have: eps^1 for eps-form, else the cap (entries above it are bad
        entries of this sector); no bound without a cap. keepA: the gate's bound, the current entry's own power at
        eps -> infinity (finite poles or not) when it is above the cap, for the fallback that removes the poles only *)
     ceilT = Table[Which[target === "EpsForm", 1, cap === Infinity, Infinity, True, cap], {k, nk}, {i, Length[Sm]}, {l, Length[Lpos]}];
     ceil[k_, i_, l_] := ceilT[[k, i, l]];
     If[target =!= "EpsForm" && cap =!= Infinity,
       Do[keepA[{ip, k, i, l}] = With[{f = rd["Dm"][[k, fpos[[i]], Lpos[[l]]]]}, If[f === 0, -Infinity, Last[PFBEpsOrders[f]]]], {k, nk}, {i, Length[Sm]}, {l, Length[Lpos]}]];
     (* at eps -> infinity, a term eps^n' f (n' up to the corrections' highest power plus that of A) needs the powers of f
        from (lowest bound + 1) - n' *)
     infLow = Min[2 - nmax, If[cap === Infinity, Infinity,
       cap + 1 - (Max[Flatten[pw /@ Sm]] + Max[Append[Exponent[Expand[#], eps] & /@ DeleteCases[Flatten[A], 0], 0]])]];
     expF[f_] := <|"pp" -> Association[Table[e0 -> ppAt[f, e0], {e0, e0s}]], "z" -> lowAt0[f, ztop], "inf" -> highAtInf[f, infLow]|>;
     (* contribution of u * coef * eps^n * f to the conditions of entry E *)
     (* eps^n = (e0 + d)^n = Sum_q Binomial[n, q] e0^(n - q) d^q around a pole e0 =!= 0: a finite sum for n >= 0, a series
        for n < 0; the principal part only needs q <= r - (lowest order of f) *)
     contrib[ek_, u_, coef_, n_, ex_] := (
       KeyValueMap[Function[{e0, ppv}, If[ppv =!= <||>, With[{lo = Min[Keys[ppv]]},
           Do[addC[Join[ek, {"pp", e0, r}], u, coef Sum[Binomial[n, q] e0^(n - q) Lookup[ppv, r - q, 0], {q, 0, r - lo}]], {r, lo, -1}]]]], ex["pp"]];
       Do[With[{r = q + n}, If[r < 0 || (target === "EpsForm" && r <= 0), addC[Join[ek, {"z", r}], u, coef ex["z"][q]]]], {q, Keys[ex["z"]]}];
       With[{top = ceil @@ Rest[ek]}, If[top =!= Infinity, Do[With[{r = q + n}, If[r > top, addC[Join[ek, {"inf", r}], u, coef ex["inf"][q]]]], {q, Keys[ex["inf"]]}]]]);
     Do[With[{ek = {ip, k, i, l}, ex = expF[rhs0[[k, i, l]]]},
        KeyValueMap[Function[{e0, ppv}, KeyValueMap[addK[Join[ek, {"pp", e0, #1}], #2] &, ppv]], ex["pp"]];
        Do[If[q < 0 || (target === "EpsForm" && q <= 0), addK[Join[ek, {"z", q}], ex["z"][q]]], {q, Keys[ex["z"]]}];
        With[{top = ceil[k, i, l]}, If[top =!= Infinity, Do[If[q > top, addK[Join[ek, {"inf", q}], ex["inf"][q]]], {q, Keys[ex["inf"]]}]]]],
       {k, nk}, {i, Length[Sm]}, {l, Length[Lpos]}];
     Do[Module[{ja = rd["Pool"][[a]], phs, exA, exdA},
        phs = Lookup[opts, "Monomials", Automatic];
        exA = Table[expF[rd["Rp"][[a, Lpos[[l]]]]], {l, Length[Lpos]}];
        exdA = Table[expF[rd["dRp"][[k, a, Lpos[[l]]]]], {k, nk}, {l, Length[Lpos]}];
        Do[If[TrueQ[Lookup[opts, "SameFamily", True]] && ja[[1]] =!= PFBMaster[sys, m]["Family"], Continue[]];
          Module[{dimN = coefDim[sys, ja[[1]], base[m]] - PFBIntegralDimension[sys, ja], mons},
           mons = If[phs === Automatic, PFBAnsatzMonomials[sys, dimN], phs];
           Do[Module[{ph = mons[[b]], phv, dphv},
              phv = ph /. P; dphv = Table[D[ph, ders[[k]]] /. P, {k, nk}];
              Do[With[{u = PoleFreeBasis`Rungs`Private`cu[m, ja, b, n], im = First[Flatten[Position[Sm, m]]]},
                 If[ip == 1, AppendTo[unk, u]; phi[u] = ph];
                 Do[
                   contrib[{ip, k, im, l}, u, dphv[[k]] + dl[m, k] phv, n, exA[[l]]];
                   contrib[{ip, k, im, l}, u, phv, n, exdA[[k, l]]];
                   (* - A_{k, i, m} times the correction of m, for every master i of the sector *)
                   Do[With[{a0 = A[[k, i, im]]}, If[a0 =!= 0,
                      Do[With[{cf = Coefficient[Expand[a0], eps, pp]}, If[cf =!= 0, contrib[{ip, k, i, l}, u, -cf phv, n + pp, exA[[l]]]]],
                        {pp, Exponent[Expand[a0], eps, Min], Exponent[Expand[a0], eps]}]]], {i, Length[Sm]}],
                   {k, nk}, {l, Length[Lpos]}]], {n, pw[m]}]], {b, Length[mons]}]], {m, Sm}]],
      {a, sel1}];
     PFBPrint["   point ", ip, " assembled (", Round[AbsoluteTime[] - t0], " s)"]],
    {ip, Length[reds]}]; None], "cond"];
  If[failure =!= None, Return[failure]];
  condA = If[conds === {}, <||>, GroupBy[First[conds], First -> (#[[2]] #[[3]] &), Total]];
  If[unk === {}, Return[<|"Status" -> "failed", "Message" -> "no unknowns: empty correction pool or no monomials of the right dimension"|>]];
  eqs = DeleteCases[Expand /@ Values[condA], 0];
  (* the fallback: powers above the cap that the current rows already have may stay (the gate's rule) *)
  eqsKeep = DeleteCases[Expand /@ Values[KeySelect[condA, ! MatchQ[#, {ip_, k_, i_, l_, "inf", r_} /; r <= Lookup[keepA, Key[{ip, k, i, l}], -Infinity]] &]], 0];
  (* prefer few dots, many propagators, low rank, the master's own power of eps, and then a monomial of low degree in the
     invariants (unit scale 1): the solver uses the unknowns listed first, so the solution takes the lowest degree that
     works among unknowns that are otherwise equal *)
  cx[jj_] := {Total[Select[List @@ Rest[jj], # > 1 &] - 1], -Total[SectorOf[jj]], Total[-Select[List @@ Rest[jj], # < 0 &]]};
  mdeg[ph_] := mdeg[ph] = PFBMonomialDegree[sys, ph];
  ordered = SortBy[unk, Join[cx[#[[2]]], {Abs[#[[4]] - Max[pw[#[[1]]]]], mdeg[phi[#]]}] &];
  PFBPrint["completion: ", Length[eqs], " conditions, ", Length[ordered], " unknowns"];
  (* lightest first: integrals of weight (dots + numerator powers) <= w, for w = 0, 1, ...; the first weight with a
     solution wins. Different completions can have the same effect on the DE; this picks the simplest-looking one. *)
  wgt[jj_] := Total[Select[List @@ Rest[jj], # > 1 &] - 1] + Total[-Select[List @@ Rest[jj], # < 0 &]];
  (* one power of eps per integral (hard rule 1): every configuration fixes the offset of the corrections' power from
     the master's lowest power (0 first, then -1, ...), the same for all its integrals *)
  minPow[m_] := Min[DeleteCases[Flatten[PFBEpsPowers[base[m]][[All, 2]]], _String] /. {} -> {0}];
  off[u_] := u[[4]] - minPow[u[[1]]];
  offs = SortBy[Union[off /@ ordered], {Abs[#], -#} &];
  tiers[eqsX_] := (res = <|"Status" -> "impossible"|>; tierU = ordered;
    Catch[Do[With[{keep = Select[ordered, wgt[#[[2]]] <= w && off[#] == d &]},
       If[keep === {}, Continue[]];
       With[{zero = Complement[ordered, keep]},
         res = PFBSolveLinear[eqsX /. Thread[zero -> 0], keep];
         If[res["Status"] === "solved", res["Solution"] = Join[res["Solution"], Thread[zero -> 0]]; tierU = keep;
           PFBPrint["completion: solved with integrals of weight <= ", w, ", powers of eps at offset ", d, " from the masters'"]; Throw[True]]]],
      {w, If[TrueQ[Lookup[opts, "Tiers", True]], Union[wgt[#[[2]]] & /@ ordered], {Max[wgt[#[[2]]] & /@ ordered]}]}, {d, offs}]]);
  tiers[eqs];
  (* nothing brings every entry to the cap: remove the poles and negative powers alone, when that needs a correction at
     all, and say that entries above the cap are left *)
  If[res["Status"] =!= "solved" && eqsKeep =!= eqs,
    With[{r0 = res}, tiers[eqsKeep];
      If[res["Status"] === "solved" && AnyTrue[res["Solution"], #[[2]] =!= 0 &], eqs = eqsKeep; kept = True;
        PFBPrint["completion: no solution within eps^", cap, " for every entry; this one removes the poles and keeps the powers above the cap the rows already have"],
        res = r0]]];
  If[res["Status"] =!= "solved", Return[<|"Status" -> "no solution", "Equations" -> Length[eqs], "Unknowns" -> Length[ordered],
     "Message" -> "no completion within this pool, these powers of eps and this ansatz: enlarge the pool (more points, more dots), or the maximal-cut basis must change"|>]];
  (* sparsify: drop the most complex integral of the solution's support while a solution remains *)
  visited = {res};
  If[TrueQ[Lookup[opts, "Sparsify", True]], Module[{support, excluded = {}, tryOut, improved = True, rounds = 0},
     support[r_] := Union[Cases[Select[r["Solution"], #[[2]] =!= 0 &], (u_ -> _) :> u[[2]]]];
     While[improved && rounds < Lookup[opts, "SparsifyRounds", 12],
       improved = False; rounds++;
       Do[With[{drop = Append[excluded, jj]},
          (* within the winning tier only *)
          tryOut = PFBSolveLinear[eqs /. Thread[Select[ordered, MemberQ[drop, #[[2]]] || ! MemberQ[tierU, #] &] -> 0], Select[tierU, ! MemberQ[drop, #[[2]]] &]];
          If[tryOut["Status"] === "solved",
            res = <|"Status" -> "solved", "Solution" -> Join[tryOut["Solution"], Thread[Select[ordered, MemberQ[drop, #[[2]]] || ! MemberQ[tierU, #] &] -> 0]], "Free" -> tryOut["Free"]|>;
            AppendTo[visited, res]; excluded = drop; improved = True; Break[]]],
         {jj, ReverseSortBy[support[res], cx]}]];
     PFBPrint["completion: sparsified in ", rounds, " round(s), support ", Length[support[res]], " integrals"]]];
  (* the new rows of the sector at the first point for a solution: the base's own block, and towards the lower masters
     the right-hand side plus the corrections' terms, as the conditions are built *)
  heightOf[sol_] := Module[{rd = at1["Reduction"], ix = at1["Index"], P = at1["Point"], ders = at1["Invariants"], Lp = at1["Lpos"], terms, cv, dv, dl1},
    terms = Cases[sol, (u_ -> c_) /; c =!= 0 :> {u, c}];
    dl1[m_, k_] := Together[D[pref[m]^2, ders[[k]]]/(2 pref[m]^2)] /. P;
    cv = Association[Table[m -> Sum[tc[[2]] eps^tc[[1, 4]] (phi[tc[[1]]] /. P) rd["Rp"][[ix[tc[[1, 2]]], Lp]], {tc, Select[terms, #[[1, 1]] === m &]}], {m, Sm}]];
    dv[k_, m_] := Sum[With[{u = tc[[1]], ia = ix[tc[[1, 2]]]}, tc[[2]] eps^u[[4]] (((D[phi[u], ders[[k]]] /. P) + dl1[m, k] (phi[u] /. P)) rd["Rp"][[ia, Lp]] +
         (phi[u] /. P) rd["dRp"][[k, ia, Lp]])], {tc, Select[terms, #[[1, 1]] === m &]}];
    PFBDigitHeight[{at1["A"], Table[at1["Rhs"][[k, i]] + dv[k, Sm[[i]]] - Sum[at1["A"][[k, i, im]] cv[Sm[[im]]], {im, Length[Sm]}], {k, Length[ders]}, {i, Length[Sm]}]}]];
  (* completions of equal weight: those met above whose integrals and monomials have the same complexities as the last
     one. The smallest digit height of the new rows at the first point wins, the last one on a tie *)
  prof[r_] := ReverseSort[Cases[r["Solution"], (u_ -> c_) /; c =!= 0 :> {cx[u[[2]]], mdeg[phi[u]]}]];
  same = Reverse[Select[visited, prof[#] === prof[res] &]];
  With[{hs = heightOf[#["Solution"]] & /@ same}, res = same[[First[Ordering[hs, 1]]]]; height = Min[hs];
    If[Length[same] > 1, PFBPrint["completion: ", Length[same], " completions of equal weight, digit heights ", hs, " of the new rows at the first point; the lowest kept"]]];
  corr = Association[Table[m -> Total[Select[res["Solution"], #[[1, 1]] === m && #[[2]] =!= 0 &] /. (u_ -> c_) :> c eps^u[[4]] phi[u] u[[2]]], {m, Sm}]];
  defs = Association[Table[m -> Collect[base[m] + corr[m], _j, Factor], {m, Sm}]];
  <|"Status" -> "solved", "Defs" -> defs, "Corrections" -> corr, "Free" -> res["Free"], "Unknowns" -> Length[ordered], "Equations" -> Length[eqs],
    "Points" -> Length[reds], "Fitted" -> True, "AboveCapKept" -> kept, "Height" -> height, "EqualWeight" -> Length[same],
    "Message" -> "solution over " <> ToString[Length[reds]] <> " point(s): check it at points not used in the fit" <>
      If[kept, "; it keeps the entries above eps^" <> ToString[cap] <> " the rows already have (none brings them down within this pool): the sector stays bad", ""]|>];


(* ::Section:: *)
(*Rung 7: derivative construction*)


expandDinv[sys_, fn_, expr_] := expr /. Dinv[a_, x_] :> MCBDerivExpr[PFBFamily[sys, fn], a, x];
opDerivative[sys_, fn_, expr_, x_] := MCBDerivExpr[PFBFamily[sys, fn], expandDinv[sys, fn, expr], x];
defaultInvs[sys_] := With[{u = PFBFamily[sys, First[sys["Order"]]]["UnitScale"]}, DeleteCases[sys["Invariants"], u]];

PFBGramFreeOperators[sys_Association, fn_, expr_, opts_Association : <||>] := Module[{xs = Lookup[opts, "Invariants", defaultInvs[sys]], deg = Lookup[opts, "Degree", 1],
    fo = PFBFamily[sys, fn], invs, mons, dv, jl, unk, a, eqs, den, facs, sol, basis},
  invs = fo["InvList"];
  mons = Flatten[Table[PFBAnsatzMonomials[sys, 2 dd], {dd, 0, deg}]];
  dv = Association[Table[x -> Collect[opDerivative[sys, fn, expr, x], _j, Together], {x, xs}]];
  jl = Union[Cases[Values[dv], _j, Infinity]];
  unk = Flatten[Table[PoleFreeBasis`Rungs`Private`ua[x, q], {x, xs}, {q, Length[mons]}]];
  a[x_] := Sum[PoleFreeBasis`Rungs`Private`ua[x, q] mons[[q]], {q, Length[mons]}];
  eqs = Flatten[Table[Module[{cs = Table[Together[Coefficient[dv[x], jj]], {x, xs}], d, num},
      d = PolynomialLCM @@ (Denominator /@ cs);
      (* {factor, power}: the numerator must cancel the factor to its full power, or 1/f^(power - 1) is left *)
      facs = Select[FactorList[d], ! FreeQ[#[[1]], Alternatives @@ invs] &];
      num = Expand[Sum[a[xs[[i]]] Together[cs[[i]] d], {i, Length[xs]}]];
      Table[CoefficientRules[PolynomialReduce[num, {f[[1]]^f[[2]]}, invs][[2]], invs][[All, 2]], {f, facs}]], {jj, jl}]];
  eqs = DeleteCases[Flatten[eqs], 0];
  sol = If[eqs === {}, {}, Quiet@Solve[Thread[eqs == 0], unk]];
  If[sol === {} && eqs =!= {}, Return[{}]];
  basis = With[{gen = unk /. If[sol === {}, {}, First[sol]]}, Module[{fr = Variables[gen]},
      Table[gen /. Thread[fr -> UnitVector[Length[fr], i]], {i, Length[fr]}]]];
  Table[Select[Table[{xs[[i]], Factor[Sum[b[[(i - 1) Length[mons] + q]] mons[[q]], {q, Length[mons]}]]}, {i, Length[xs]}], #[[2]] =!= 0 &], {b, basis}]];

PFBApplyOperator[sys_Association, fn_, op_List, def_, pref_] := Collect[
  Sum[o[[2]] (opDerivative[sys, fn, def, o[[1]]] + Together[D[pref^2, o[[1]]]/(2 pref^2)] expandDinv[sys, fn, def]), {o, op}], _j, Together];

PFBOperatorVector[sys_Association, sl_Association, op_List, l_Integer] := Module[{n = PFBSliceSize[sl], w, pr = PFBMaster[sys, l]["Pref"]},
  w = ConstantArray[0, n];
  Do[With[{k = First[Flatten[Position[sl["Derivatives"], o[[1]]]]]},
     w += (o[[2]] /. sl["Point"]) sl["R"][[k, sl["Index"][l]]]], {o, op}];
  (* the slice row already contains dlog(pref) of U_l, which is what (1/pref) O(pref U) needs *)
  Together[w]];

PFBDerivativeSearch[sys_Association, sl_Association, key_List, sources_List, opts_Association : <||>] := Module[{S = PFBSectorMasters[sys, key], clean, cands = {}, combos, out = {}, fn = key[[1]], scol},
  If[KeyExistsQ[opts, "ReferenceDet"], Print["PFBDerivativeSearch: the option ReferenceDet was removed: the determinant of a change is not judged, only required to be non-zero."];
    Return[$Failed]];
  clean = Lookup[opts, "Clean", Complement[S, sources]];
  scol = sl["Index"] /@ S;
  Do[Module[{ops = PFBGramFreeOperators[sys, PFBMaster[sys, c]["Family"], PFBMaster[sys, c]["RootFree"], Join[<|"Invariants" -> sl["Derivatives"]|>, KeyTake[opts, {"Degree"}]]]},
     Do[AppendTo[cands, <|"From" -> c, "Op" -> op, "H" -> PFBOperatorVector[sys, sl, op, c]|>], {op, ops}]], {c, clean}];
  PFBPrint["derivative candidates: ", Length[cands], " (", Length[clean], " clean masters)"];
  combos = Subsets[Range[Length[cands]], {Length[sources]}];
  Do[Module[{Hs = Table[cands[[i]]["H"][[scol]], {i, cb}], T, det},
     (* new sector basis: the clean masters plus the candidates, on the old sector masters *)
     T = Join[Table[UnitVector[Length[S], First[Flatten[Position[S, c]]]], {c, Complement[S, sources]}], Hs];
     det = Factor[Det[T]];
     If[det =!= 0, AppendTo[out, <|"Replace" -> sources, "From" -> cands[[cb, "From"]], "Ops" -> cands[[cb, "Op"]], "Det" -> det,
        "Defs" -> Association[Table[sources[[q]] -> PFBApplyOperator[sys, PFBMaster[sys, cands[[cb[[q]]]]["From"]]["Family"], cands[[cb[[q]]]]["Op"],
             PFBMaster[sys, cands[[cb[[q]]]]["From"]]["RootFree"], PFBMaster[sys, cands[[cb[[q]]]]["From"]]["Pref"]], {q, Length[sources]}]]|>]]],
    {cb, Take[combos, UpTo[Lookup[opts, "MaxCombinations", 200]]]}];
  SortBy[out, {Total[Length /@ #["Ops"]], LeafCount[#["Ops"]]} &]];


(* ::Section:: *)
(*Rung 8: maximal-cut change*)


(* maximal-cut-basis reads a basis element as integrals j[...] only (MCBSplitMaster): a ut[k] term stands for the
   current master k (its root-free definition, as in the gate), and Dinv[a, X] is the derivative of a in X, written out
   as integrals (MCBDerivExpr), innermost first *)
mcbIntegrals[sys_, e_] := Module[{x = e /. ut[k_Integer] :> PFBMaster[sys, k]["RootFree"]},
  x = x //. Dinv[a_ /; FreeQ[a, Dinv], v_] :> MCBDerivExpr[PFBFamily[sys, First[Cases[{a}, j[f_, ___] :> f, Infinity], sys["Order"][[1]]]], a, v];
  If[MCBLargeQ[x], x, Collect[x, _j, Together]]];

PFBMaxCutBasis[sys_Association, key_List] := Select[PFBSectorMasters[sys, key], PFBMaster[sys, #]["Family"] === key[[1]] &];
(* defs are root-free, like the masters' "RootFree": a new master keeps the square-root prefactor of the one it replaces *)
PFBMaxCutBasis[sys_Association, key_List, defs_Association] := Table[
   (PFBMaster[sys, l]["Mono"] mcbIntegrals[sys, If[KeyExistsQ[defs, l], defs[l], PFBMaster[sys, l]["RootFree"]]]) /. PFBRootDefs[sys], {l, PFBMaxCutBasis[sys, key]}];

PFBWriteMCBBasisFile[sys_Association, key_List, defs_Association, file_String] := Module[{S = PFBMaxCutBasis[sys, key], list},
  list = MapThread[<|"definition" -> #2, "label" -> "ut[" <> ToString[#1] <> "]" <> If[KeyExistsQ[defs, #1], " (new)", ""],
      "provenance" -> If[KeyExistsQ[defs, #1], "pole-free-basis", "unchanged"]|> &, {S, PFBMaxCutBasis[sys, key, defs]}];
  Put[list, file];
  file];


End[];
EndPackage[];
