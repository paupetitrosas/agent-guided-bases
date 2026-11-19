(* ::Package:: *)

(* ::Title:: *)
(*MaximalCutBasis`LoopByLoop`: the loop-by-loop reading of a sector's maximal cut*)


(* ::Text:: *)
(*What a sector's maximal cut looks like in each loop-by-loop representation, before any candidate search:*)
(*  - which subloop each Baikov polynomial belongs to (its exponent a + b eps: b = -1 is a subloop Baikov polynomial*)
(*    with E = d0 - 2 - 2a external momenta, b = +1 an external Gram determinant with E = 2a + d0 - 1);*)
(*  - the twist factors and their kinds (branch / integer / eps-only, see MCBTwistFactors);*)
(*  - the behaviour at infinity in each variable, which says what a numerator power costs: u ~ v^E_v gives the IBP*)
(*    factor (n + 1 + E_v) for v^n, the source of factors such as (1 - 3 eps) in a basis of ISP powers;*)
(*  - discriminants of the square root that are perfect squares (rationalisable after one integration);*)
(*  - the number of masters the representation sees (critical points of log u), with and without the eps-only*)
(*    factors: the difference lives on their boundaries, where the integrands need simple poles;*)
(*  - the geometry of the bulk and of every boundary (MCBBoundaries): a boundary can be a curve;*)
(*  - for given integrals, the cut integrand R relative to the twist and the form it induces on each boundary.*)


BeginPackage["MaximalCutBasis`LoopByLoop`", {"MaximalCutBasis`", "SkillCore`Tools`", "SkillCore`Records`", "SkillCore`Pages`", "MaximalCutBasis`Family`",
   "MaximalCutBasis`Sectors`", "MaximalCutBasis`Baikov`", "MaximalCutBasis`CutIntegrands`"}];

MCBPolynomialRoles::usage = "MCBPolynomialRoles[cd] annotates each cut polynomial with its exponent and role: subloop Baikov polynomial or external Gram determinant, with the number E of external momenta of that subloop.";
MCBInfinityExponents::usage = "MCBInfinityExponents[cd] = <|v -> <|\"exponent\" -> E_v, \"costs\" -> {n + 1 + E_v, n = 1, 2, 3}|>|>: the twist behaves as v^E_v at large v, so a numerator v^n reduces with the factor n + 1 + E_v.";
MCBRootDiscriminants::usage = "MCBRootDiscriminants[cd] lists, for every variable in which the eps = 0 square root is quadratic, its discriminant (factored) and whether it is a perfect square in the other variables (then the root is rational after integrating that variable).";
MCBMasterCount::usage = "MCBMasterCount[cd, opts] counts the critical points of log u (generic exponents, a random rational kinematic point): <|\"total\", \"bulk\" (eps-only factors dropped), \"point\", \"reliable\" (False when a factor is unregulated: the count treats it as regulated and the true number of masters can be larger)|>. opts: \"Point\", \"Seed\", \"TimeLimit\" (s, default 120).";
MCBBoundaryForm::usage = "MCBBoundaryForm[cd, R, f] is the form that the cut integrand R (relative to the twist, MCBCutIntegrand) induces on the boundary f = 0 at its leading order in eps, the integer powers of f in the eps = 0 twist included: <|\"k\" (eps order), \"form\" (rational part), \"radicand\", \"variable\"|> meaning eps^k form d(vars)/Sqrt[radicand]; \"form\" -> 0 when the integrand has no pole at f = 0, Missing[\"PoleOrder\", m] for a pole of order m > 1.";
MCBLoopByLoopReport::usage = "MCBLoopByLoopReport[fam, sector, opts] prints and returns the loop-by-loop reading of the sector's maximal cut for every loop order: polynomial roles, twist factors, behaviour at infinity, discriminants, master counts, bulk and boundary geometry, and (opts \"Integrals\" -> {j[...]..}) the cut integrands with their boundary forms. opts: \"Extra\" (ISPs beyond the minimum, default 0), \"AutoExtra\" (True: when the minimal representation of a loop order has an unregulated factor, the representations with one more ISP are read too), \"Count\" (True), \"KiraMasters\" (the number of masters on the cut, for comparison), \"TimeLimit\".";

Begin["`Private`"];


MCBPolynomialRoles[cd_Association] := Module[{d0 = cd["D0"]},
  Table[With[{p = cd["cutpolys"][[i]], e = Expand[cd["cutpows"][[i]]]},
     With[{a = e /. eps -> 0, b = Coefficient[e, eps]},
       <|"polynomial" -> p, "exponent" -> e,
         "role" -> Which[b == -1, "subloop Baikov polynomial, E = " <> ToString[d0 - 2 - 2 a],
                        b == 1, "external Gram determinant, E = " <> ToString[2 a + d0 - 1],
                        True, "exponent " <> ToString[e, InputForm]],
         "zdependent" -> ! FreeQ[p, z]|>]], {i, Length[cd["cutpolys"]]}]];

MCBInfinityExponents[cd_Association] := Module[{tf = MCBTwistFactors[cd]},
  Association[Table[v -> With[{ev = Expand[Total[Exponent[#["factor"], v] #["exponent"] & /@ tf]]},
       <|"exponent" -> ev, "costs" -> Table[Expand[n + 1 + ev], {n, 1, 3}]|>], {v, cd["vars"]}]]];

squareInQ[e_] := AllTrue[FactorList[Factor[e]], FreeQ[#[[1]], z] || EvenQ[#[[2]]] &];

MCBRootDiscriminants[cd_Association] := Module[{pr = cd["split"]["Pr"]},
  If[FreeQ[pr, z], Return[{}]];
  Table[With[{dd = Factor[Discriminant[pr, v]]}, <|"variable" -> v, "discriminant" -> dd, "square" -> squareInQ[dd]|>],
    {v, Select[cd["vars"], Exponent[pr, #] == 2 &]}]];

randomPoint[cd_, seed_] := BlockRandom[Thread[cd["invariants"] -> RandomPrime[{1000, 30000}, Length[cd["invariants"]]]], RandomSeeding -> seed];

MCBMasterCount[cd_Association, opts_Association : <||>] := Module[{vars = cd["vars"], tf = MCBTwistFactors[cd], pt, count, al, tl},
  If[vars === {}, Return[<|"total" -> 1, "bulk" -> 1, "point" -> {}, "reliable" -> True|>]];
  pt = Lookup[opts, "Point", randomPoint[cd, Lookup[opts, "Seed", 7]]];
  tl = Lookup[opts, "TimeLimit", 120];
  (* generic exponents: distinct non-integer rationals, one per factor *)
  al = Table[Prime[10 + 3 i]/Prime[40 + 5 i], {i, Length[tf]}];
  count[sel_] := Module[{fs = (#["factor"] /. pt) & /@ tf[[sel]], a = al[[sel]], eqs, prod, sols},
    If[fs === {}, Return[0]];
    prod = Times @@ fs;
    eqs = Table[Expand[Sum[a[[i]] D[fs[[i]], v] Times @@ Delete[fs, i], {i, Length[fs]}]], {v, vars}];
    (* t prod = 1 removes the components where the factors vanish (multiplying through by prod creates them, and
       they are positive-dimensional when two factors vanish together) *)
    sols = TimeConstrained[Quiet[NSolve[Join[Thread[eqs == 0], {tt prod == 1}], Append[vars, tt], WorkingPrecision -> 40]], tl, $Failed];
    If[sols === $Failed, Missing["TimeOut"], Length[sols]]];
  <|"total" -> count[Range[Length[tf]]], "bulk" -> count[Flatten[Position[tf, _?(#["kind"] =!= "eps-only" &), {1}, Heads -> False]]],
    "point" -> pt,
    (* the count assumes generic exponents: an unregulated factor is counted as if it were regulated *)
    "reliable" -> NoneTrue[tf, #["kind"] === "unregulated" &]|>];

MCBBoundaryForm[cd_Association, r_, f0_] := Module[{f = MCBCanonFactor[f0][[1]], le, r0, bg, v, sol, pr, num, den, res, sf},
  le = MCBLeadingEps[r]; If[le[[1]] === Infinity, Return[<|"k" -> Infinity, "form" -> 0|>]];
  (* the eps = 0 twist's rational part Rz carries the integer powers of the non-branch factors: include it before the residue *)
  r0 = Together[le[[2]] cd["split"]["Rz"]];
  bg = MCBBoundaryGeometry[cd, f];
  If[! KeyExistsQ[bg, "variable"], Return[<|"k" -> le[[1]], "form" -> Missing["NotAnalysed"]|>]];
  v = bg["variable"]; sol = bg["solution"];
  den = Denominator[r0];
  If[PolynomialRemainder[den, f, v] =!= 0, Return[<|"k" -> le[[1]], "form" -> 0, "variable" -> v|>]];
  (* a pole of order m > 1 on the boundary gives derivatives there (second-kind forms): reported, not reduced *)
  With[{m = poleOrder[den, f, v]}, If[m > 1, Return[<|"k" -> le[[1]], "form" -> Missing["PoleOrder", m], "variable" -> v, "vars" -> bg["vars"]|>]]];
  (* residue in v at the simple zero of f *)
  res = Together[(Numerator[r0]/PolynomialQuotient[den, f, v] /. v -> sol)/(D[f, v] /. v -> sol)];
  (* eps = 0 twist on the boundary: Rz/Sqrt[Pr] with Pr = N/D written as s Sqrt[rad]/D *)
  pr = Together[cd["split"]["Pr"] /. v -> sol];
  sf = Module[{rad = 1, s = 1}, Do[If[! FreeQ[g[[1]], z], rad *= g[[1]]^Mod[g[[2]], 2]; s *= g[[1]]^Quotient[g[[2]], 2]],
      {g, FactorList[Numerator[pr] Denominator[pr]]}]; {rad, s}];
  <|"k" -> le[[1]], "form" -> Factor[res Denominator[pr]/sf[[2]]], "radicand" -> sf[[1]], "variable" -> v, "vars" -> bg["vars"]|>];

poleOrder[den_, f_, v_] := Module[{d = den, m = 0}, While[PolynomialRemainder[d, f, v] === 0 && m < 10, d = PolynomialQuotient[d, f, v]; m++]; m];

epsFactors[e_] := Select[FactorList[e][[All, 1]], ! FreeQ[#, eps] && # =!= eps &];

MCBLoopByLoopReport[fam_Association, s_List, opts_Association : <||>] := Module[{extra = Lookup[opts, "Extra", 0], out = {}, ints = Lookup[opts, "Integrals", {}],
    kira = Lookup[opts, "KiraMasters", Missing[]], line},
  line[x__] := Print[x];
  line["== loop-by-loop reading of ", SectorName[s], " (", Total[s], " propagators)",
    If[MissingQ[kira], "", "; masters on the cut (reduction): " <> ToString[kira]]];
  Do[Module[{reps = Quiet[MCBRepresentations[fam, s, <|"Orders" -> {order}, "Standard" -> False, "Extra" -> extra, "TimeLimit" -> Lookup[opts, "TimeLimit", 120]|>]]},
     If[reps === {}, line["-- loop order ", order, ": no non-degenerate representation (a Baikov polynomial vanishes identically or on the cut: some loop sees only light-like vectors)"];
       AppendTo[out, <|"order" -> order, "reps" -> {}|>]; Continue[]];
     (* an unregulated factor hides masters from the minimal representation: read the ones with one more ISP too *)
     If[TrueQ[Lookup[opts, "AutoExtra", True]] && AnyTrue[reps, AnyTrue[MCBTwistFactors[#], Function[t, t["kind"] === "unregulated"]] &],
       line["-- loop order ", order, ": the minimal representation has an unregulated factor; the representations with ", extra + 1, " extra ISP(s) follow it"];
       reps = DeleteDuplicatesBy[Join[reps, Quiet[MCBRepresentations[fam, s, <|"Orders" -> {order}, "Standard" -> False, "Extra" -> extra + 1,
           "TimeLimit" -> Lookup[opts, "TimeLimit", 120]|>]]], #["isp"] &]];
     Do[Module[{tf = MCBTwistFactors[cd], inf = MCBInfinityExponents[cd], disc = MCBRootDiscriminants[cd], geo = cd["geometry"], cnt, rows = {}},
        line["-- loop order ", order, ", ISPs ", cd["isp"], ", variables ", cd["vars"]];
        Do[line["   ", If[r["zdependent"], "", "(constant) "], r["role"], ": exponent ", InputForm[r["exponent"]]], {r, MCBPolynomialRoles[cd]}];
        Do[line["   twist factor ", InputForm[t["factor"]], "^(", InputForm[t["exponent"]], ")  [", t["kind"], "]"], {t, tf}];
        KeyValueMap[line["   at large ", #1, ": u ~ ", #1, "^(", InputForm[#2["exponent"]], "); numerator powers 1, 2, 3 cost ", InputForm[#2["costs"]]] &, inf];
        Do[line["   discriminant of the root in ", dd["variable"], ": ", InputForm[dd["discriminant"]], If[dd["square"], "  (perfect square: rational after integrating " <> ToString[dd["variable"]] <> ")", ""]], {dd, disc}];
        line["   geometry (bulk): ", classText[geo]];
        Do[line["   boundary: ", b["text"]], {b, Lookup[geo, "boundaries", {}]}];
        Do[line["   !! ", InputForm[t["factor"]], " is unregulated (exponent ", InputForm[t["exponent"]],
            " with no eps part: a Gram determinant and a Baikov polynomial share it and the eps cancels). Integrands with a pole there are not regulated, and masters live on its zero set beyond the generic count; a representation with more ISPs, or another loop order, may separate the two polynomials."],
          {t, Select[tf, #["kind"] === "unregulated" &]}];
        cnt = If[TrueQ[Lookup[opts, "Count", True]], MCBMasterCount[cd, opts], <||>];
        If[cnt =!= <||>, line["   masters seen (critical points of log u", If[TrueQ[cnt["reliable"]], "", ", generic exponents: a lower bound here"], "): ", cnt["total"], "; without the eps-only factors: ", cnt["bulk"],
           If[IntegerQ[cnt["total"]] && IntegerQ[cnt["bulk"]] && cnt["total"] > cnt["bulk"],
             " -> " <> ToString[cnt["total"] - cnt["bulk"]] <> " master(s) live on the boundaries of " <>
               ToString[InputForm /@ Select[tf, #["kind"] === "eps-only" &][[All, "factor"]]] <> ": their integrands need simple poles there (dots on the propagators of that subloop)", ""],
           If[! MissingQ[kira] && IntegerQ[cnt["total"]] && cnt["total"] =!= kira, "  !! the reduction finds " <> ToString[kira], ""]]];
        Do[Module[{r = Quiet[MCBCutIntegrand[cd, jj]], le, bfs},
            If[r === $Failed, line["   ", jj, ": not expressible in this representation (numerator on an ISP it does not keep)"]; Continue[]];
            If[r === 0, line["   ", jj, ": vanishes on the cut"]; Continue[]];
            le = MCBLeadingEps[r];
            bfs = Select[Table[Append[MCBBoundaryForm[cd, r, t["factor"]], "factor" -> t["factor"]], {t, Select[tf, #["kind"] =!= "branch" &]}],
              MatchQ[#["form"], Except[0 | Missing["NotAnalysed"]]] &];
            line["   ", jj, ": R = eps^", le[[1]], " (", InputForm[Factor[le[[2]]]], ")",
              With[{ef = epsFactors[Factor[Together[r]]]}, If[ef === {}, "", "; eps-polynomial factors " <> ToString[InputForm[ef]]]],
              If[bfs === {}, "; no boundary pole", "; on " <> StringRiffle[(ToString[#["factor"], InputForm] <> " = 0: " <> If[MatchQ[#["form"], Missing["PoleOrder", _]],
                 "pole of order " <> ToString[#["form"][[2]]] <> " (derivatives on the boundary)",
                 "(" <> ToString[#["form"], InputForm] <> ") d" <> ToString[#["vars"]] <> "/Sqrt[radicand]"]) & /@ bfs, "; "]]];
            AppendTo[rows, <|"j" -> jj, "R" -> r, "k" -> le[[1]], "R0" -> le[[2]], "boundaryForms" -> bfs|>]], {jj, ints}];
        AppendTo[out, <|"order" -> order, "cd" -> cd, "factors" -> tf, "infinity" -> inf, "discriminants" -> disc, "counts" -> cnt, "integrals" -> rows|>]],
       {cd, reps}]],
    {order, Permutations[fam["LoopMomenta"]]}];
  out];

classText[geo_] := geo["text"] <> If[KeyExistsQ[geo, "bulk"] && geo["bulk"] =!= geo["class"], "  [class " <> geo["class"] <> " from a boundary; bulk " <> geo["bulk"] <> "]", ""];


End[];
EndPackage[];
