(* ::Package:: *)

(* ::Title:: *)
(*MaximalCutBasis`Rules`: the rules every master obeys, and the Euler check of every DE (used by both skills' gates)*)


(* ::Text:: *)
(*Hard rules on a master  eps^k Sqrt[R] (Sum_a c_a j_a):*)
(*  1  one power of eps per integral, with an eps-independent coefficient;*)
(*  2  no (a + b eps) factor and no eps in a denominator (a uniform eps^k, k < 0 included, is rule 3);*)
(*  3  a uniform eps^k on the whole master is allowed;*)
(*  4  coefficients rational in the invariants, one square root for the whole master.*)
(*Letter check: with an alphabet given ("Letters" in family.wl or system.wl), every factor of a coefficient's*)
(*denominator is a letter (up to a constant).*)
(*Euler: the integrals are homogeneous, so Sum_X d_X X dJ/dX = w J, with d_X the mass dimension of X and w that of J.*)
(*For a DE dJ = Sum_X A_X dX J this is Sum_X d_X X A_X = diag(w): no off-diagonal part, a diagonal that does not*)
(*depend on the kinematics and equals the weights of the masters' definitions. A master whose terms differ in weight*)
(*has a missing or wrong prefactor; in a basis meant to be dimensionless, so does one whose weight differs from the*)
(*others of its sector (curve bases of derivatives, and bases of bare integrals, are not dimensionless).*)
(*The maximal-cut gate (MCBBasisChecks) decides on the Euler relation and reports the rest; the pole-free gate*)
(*(PFBGate) enforces the rules, the letters, the weight of each new master and the Euler relation on its rows.*)


BeginPackage["MaximalCutBasis`Rules`", {"MaximalCutBasis`", "SkillCore`Tools`", "MaximalCutBasis`Family`", "MaximalCutBasis`Sectors`"}];

MCBWeightOf::usage = "MCBWeightOf[fam, expr] is the mass dimension of an expression in the invariants (square roots included), or $Failed when it is not homogeneous; eps is dimensionless.";
MCBIntegralWeight::usage = "MCBIntegralWeight[fam, j[...]] = L (D0 - 2 eps) - Sum_i a_i dim(D_i): the mass dimension (Euler weight) of an integral.";
MCBMasterWeight::usage = "MCBMasterWeight[fam, J, opts] is the Euler weight of a master eps^k Sqrt[R] (Sum c j): the common weight of its terms, or $Failed when they differ (an inhomogeneous prefactor or coefficient). opts: \"Families\" -> <|name -> family|> for integrals of other families.";
MCBRuleViolations::usage = "MCBRuleViolations[fam, J, <|\"Letters\" -> {...}|>] lists the violations of hard rules 1, 2 and 4 by a master, and of the letter check when an alphabet is given; {} when the master is honest.";
MCBHonestQ::usage = "MCBHonestQ[fam, J, opts] is True when J breaks no hard rule and passes the letter check.";
MCBLetterQ::usage = "MCBLetterQ[f, letters, vars] is True when the polynomial f is a constant multiple of one of the letters (or free of vars).";
MCBEulerMatrix::usage = "MCBEulerMatrix[As, dims, point] = Sum_X dims[X] X A_X at the point (rules; {} for analytic matrices), for As = <|X -> A_X|>.";
MCBEulerCheck::usage = "MCBEulerCheck[{As_1, As_2, ...}, {pt_1, pt_2, ...}, dims, weights, opts] checks Sum_X d_X X A_X = diag(weights) at every point: no off-diagonal part, the same diagonal at every point (analytic matrices: free of the invariants, pt = {}), equal to the weights when they are given (a list, one per row, $Failed for a row to skip; Automatic to skip all). opts: \"Diagonal\" (the column of each row's own master, when the rows are a block of a larger matrix; default row i <-> column i), \"RowNames\", \"ColumnNames\" (for the messages). Returns <|\"Pass\" -> True | False | Missing[\"NotChecked\"], \"Diagonal\", \"OffDiagonal\" -> {{row, column, point}, ...}, \"Mismatch\" -> {{row, diagonal, weight}, ...}, \"Message\"|>; not checked when an invariant of non-zero dimension has no matrix.";
MCBWeightCheck::usage = "MCBWeightCheck[weights, labels] checks that the masters of one sector share one weight (dimensionless masters): <|\"Pass\", \"Weight\", \"Outliers\" -> {{label, weight}, ...}, \"Message\"|>.";
MCBRulesCheck::usage = "MCBRulesCheck[fam, masters, opts] runs the rules, the letter check and the weight check on the masters of one sector and returns the checks as a list of <|\"Name\", \"Pass\", \"Detail\"|>.";

Begin["`Private`"];


(* ::Section:: *)
(*Weights*)


(* eps is dimensionless and stays symbolic: setting it to a number could make a coefficient such as (1 - eps) vanish.
   With square roots the weight is half that of expr^2, which is rational: simplifying Sqrt[lam^8 P]/Sqrt[P] instead
   depends on how P is factored (a sign left under the root gives a stray I) *)
MCBWeightOf[fam_Association, expr_] := Module[{lam, sc, ratW, sq},
  If[TrueQ[expr == 0], Return[Indeterminate]];
  If[MCBLargeQ[expr], Return[weightAtPoints[fam, expr]]];
  sc[e_] := e /. KeyValueMap[#1 -> lam^#2 #1 &, fam["Invariants"]];
  ratW[r0_] := With[{r = Factor[r0]}, Which[r === 1, 0, MatchQ[r, lam^_?NumericQ | lam], Exponent[r, lam], True, $Failed]];
  sq = Together[expr^2];
  If[FreeQ[sq, Power[_, _Rational]],
    With[{w = ratW[Together[sc[sq]/sq]]}, If[w === $Failed, $Failed, w/2]],
    ratW[PowerExpand[Factor[Together[sc[expr]/expr]]]]]];

(* a large expression (MCBLargeQ): its values at a random point x and at the scaled points lam^d x, lam = 2 and 3, with
   the other symbols (eps included) at random values. The ratio is lam^w exactly when the expression has weight w;
   squares make it rational when the expression holds square roots *)
weightAtPoints[fam_, e_] := Module[{seed = 0, r, v0, q, q2, w},
  q[lam_] := Quiet[Expand[((e /. (#[[1]] -> If[KeyExistsQ[fam["Invariants"], #[[1]]], lam^fam["Invariants"][#[[1]]], 1] #[[2]] & /@ r))/v0)^2]];
  While[seed < 10, seed++;
    r = MCBRandomValues[e, 2000 + seed];
    v0 = Quiet[e /. r];
    If[singular[v0] || numberZeroQ[v0], Continue[]];
    q2 = q[2];
    If[! MatchQ[q2, _Integer | _Rational] || q2 <= 0, Return[$Failed, Module]];
    w = Log[2, q2]/2;
    Return[If[MatchQ[w, _Integer | _Rational] && q[3] === 3^(2 w), w, $Failed], Module]];
  (* zero wherever it is defined: a coefficient that is zero as written, like the small ones that are 0 *)
  If[singular[v0], $Failed, Indeterminate]];
numberZeroQ[d_] := With[{z = Expand[d]}, z === 0 || (! FreeQ[z, Power[_, _Rational]] && RootReduce[z] === 0)];
singular[d_] := ! FreeQ[d, ComplexInfinity | Indeterminate | DirectedInfinity];

MCBIntegralWeight[fam_Association, jj_j] := fam["L"] (fam["D0"] - 2 eps) - Total[(List @@ Rest[jj]) fam["PropDims"]];

(* "Families" -> <|name -> family|>: integrals of other families (the pole-free skill's systems) take their own
   propagator dimensions *)
MCBMasterWeight[fam_Association, J_, opts_Association : <||>] := Module[{cs = MCBCoefficients[J], ints, ws, famOf},
  famOf[jj_] := Lookup[Lookup[opts, "Families", <||>], jj[[1]], fam];
  ints = Keys[cs];
  If[ints === {}, Return[$Failed]];
  ws = Table[With[{wc = MCBWeightOf[fam, cs[jj]]}, If[wc === $Failed, $Failed, wc + MCBIntegralWeight[famOf[jj], jj]]], {jj, ints}];
  (* an integral whose coefficient is zero as written (MCBWeightOf gives Indeterminate) does not count *)
  ws = DeleteCases[ws, Indeterminate];
  If[ws === {}, Return[$Failed]];
  If[MemberQ[ws, $Failed] || Length[Union[Expand /@ ws]] > 1, $Failed, Expand[First[ws]]]];

MCBWeightCheck[ws_List, labels_List] := Module[{good = Select[Transpose[{labels, ws}], #[[2]] =!= $Failed &], w0, out},
  If[Length[good] < Length[ws],
    Return[<|"Pass" -> False, "Weight" -> Missing["Inhomogeneous"], "Outliers" -> Select[Transpose[{labels, ws}], #[[2]] === $Failed &],
      "Message" -> "inhomogeneous: " <> StringRiffle[ToString /@ Select[Transpose[{labels, ws}], #[[2]] === $Failed &][[All, 1]], ", "] <>
        " mix terms of different mass dimension (a prefactor or coefficient of the wrong dimension)"|>]];
  If[good === {}, Return[<|"Pass" -> True, "Weight" -> Missing["NoMasters"], "Outliers" -> {}, "Message" -> "no masters"|>]];
  w0 = First[Commonest[Expand /@ ws]];
  out = Select[Transpose[{labels, ws}], Expand[#[[2]] - w0] =!= 0 &];
  <|"Pass" -> out === {}, "Weight" -> w0, "Outliers" -> out,
    "Message" -> If[out === {}, "every master has weight " <> ToString[w0, InputForm] <> If[(w0 /. eps -> 0) === 0, " (dimensionless)", ""],
      StringRiffle[(ToString[#[[1]]] <> " has weight " <> ToString[#[[2]], InputForm] <> ", the sector " <> ToString[w0, InputForm] <>
          ": its prefactor is off by mass dimension " <> ToString[Expand[#[[2]] - w0], InputForm]) & /@ out, "; "]]|>];


(* ::Section:: *)
(*Rules*)


MCBLetterQ[f_, letters_List, vars_List] := FreeQ[f, Alternatives @@ vars] ||
   AnyTrue[letters, Function[l, ! FreeQ[l, Alternatives @@ vars] && FreeQ[Together[f/l], Alternatives @@ vars]]];

(* the powers of eps of one coefficient, relative to an eps^k in its denominator, or "eps in denominator" *)
powersIn[c_] := Module[{t = Together[c], num, den, dpow, terms},
  num = Numerator[t]; den = Denominator[t];
  If[! FreeQ[den, eps], dpow = Exponent[den, eps, Min];
    If[! FreeQ[Expand[den/eps^dpow], eps], Return[{"eps in denominator"}]], dpow = 0];
  terms = If[Head[Expand[num]] === Plus, List @@ Expand[num], {Expand[num]}];
  Union[(Exponent[#, eps] - dpow) & /@ terms]];

(* a large coefficient (MCBLargeQ): the same, from its values at two random points of the invariants, eps kept *)
powersAtPoints[c_] := Module[{seed = 0, ok = 0, out = {}, v},
  While[ok < 2 && seed < 20, seed++;
    v = Quiet[c /. MCBRandomValues[c, 3000 + seed, {eps}]];
    If[singular[v] || numberZeroQ[v /. eps -> 7/13], Continue[]];
    out = Union[out, powersIn[v]]; ok++];
  out];

(* a large coefficient: whether its denominator has a factor that is not a letter, read on a random line through the
   space of invariants (eps = 1, as for small ones): the denominator there, a polynomial in one variable, must divide a
   product of powers of the letters on that line. The non-letter factors are named when they are written as factors *)
nonLettersAtPoints[c_, letters_, invs_] := Module[{r, tau, line, den, lp, g, rem, cand},
  r = MCBRandomValues[c, 4000, {eps}];
  line = Join[BlockRandom[Table[x -> (x /. r) + RandomInteger[{1, 50}] tau, {x, invs}], RandomSeeding -> 4001], Select[r, ! MemberQ[invs, #[[1]]] &], {eps -> 1}];
  den = Denominator[Together[c /. line]];
  lp = Times @@ Select[letters /. line, ! FreeQ[#, tau] &];
  rem = den;
  While[Exponent[g = PolynomialGCD[rem, lp], tau] > 0, rem = Cancel[rem/g]];
  If[Exponent[rem, tau] == 0, Return[{}]];
  cand = Select[Union[Flatten[FactorList[#][[All, 1]] & /@ Cases[{c /. eps -> 1}, Power[b_, n_?Negative] :> b, {0, Infinity}]]],
    ! MCBLetterQ[#, letters, invs] && Exponent[PolynomialGCD[rem, # /. line], tau] > 0 &];
  If[cand === {}, {"a factor of degree " <> ToString[Exponent[rem, tau]] <> " on a random line"}, cand]];

(* the square-root factors of a coefficient are its prefactor, checked as a whole (rule 4) *)
rootFree[c_] := c /. Power[a_, r_Rational] /; Denominator[r] == 2 :> a^(r - 1/2) /. Power[a_, 0] :> 1;
rootsOf[c_] := Union[Cases[{c}, Power[a_, r_Rational] /; Denominator[r] == 2 :> a, {0, Infinity}]];

(* the coefficients are read as written (MCBCoefficients); a large one is checked at points instead of symbolically *)
MCBRuleViolations[fam_Association, J_, opts_Association : <||>] := Module[{cs = MCBCoefficients[J], ints, out = {}, invs = fam["InvList"],
    letters = Replace[Lookup[opts, "Letters", Lookup[fam, "Letters", {}]], Except[_List] -> {}], roots},
  ints = Keys[cs];
  If[ints === {}, Return[{"no integral"}]];
  roots = Union[Flatten[rootsOf[cs[#]] & /@ ints]];
  If[Length[Union[Together[Times @@ rootsOf[cs[#]]] & /@ ints]] > 1,
    AppendTo[out, "rule 4: the terms carry different square roots " <> ToString[roots, InputForm] <> " (one square root for the whole master)"]];
  Do[With[{c = rootFree[cs[jj]], name = ToString[jj, InputForm], large = MCBLargeQ[cs[jj]]},
     With[{p = If[large, powersAtPoints[c], powersIn[c]]},
       Which[MemberQ[p, "eps in denominator"], AppendTo[out, "rule 2: " <> name <> " has eps in a denominator of its coefficient"],
         Length[p] > 1, AppendTo[out, "rule 1: " <> name <> " has several powers of eps " <> ToString[p] <> " in its coefficient (an (a+b eps) factor)"]]];
     With[{x = Complement[If[large, MCBRandomValues[c, 1][[All, 1]], Variables[{Numerator[Together[c]], Denominator[Together[c]]}]], Join[invs, {eps}]]},
       If[x =!= {}, AppendTo[out, "rule 4: the coefficient of " <> name <> " depends on " <> ToString[x] <> ", not only on the invariants"]]];
     If[letters =!= {},
       With[{bad = If[large, nonLettersAtPoints[c, letters, invs], Select[FactorList[Denominator[Together[c /. eps -> 1]]][[All, 1]], ! MCBLetterQ[#, letters, invs] &]]},
         If[bad =!= {}, AppendTo[out, "letters: the coefficient of " <> name <> " has the non-letter denominator factor(s) " <> ToString[bad, InputForm]]]]]],
    {jj, ints}];
  out];

MCBHonestQ[fam_Association, J_, opts_Association : <||>] := MCBRuleViolations[fam, J, opts] === {};

MCBRulesCheck[fam_Association, masters_List, opts_Association : <||>] := Module[{viol, ws, wc, letters = Replace[Lookup[opts, "Letters", Lookup[fam, "Letters", {}]], Except[_List] -> {}]},
  viol = Flatten[Table[("J" <> ToString[i] <> ": " <> #) & /@ MCBRuleViolations[fam, masters[[i]], <|"Letters" -> {}|>], {i, Length[masters]}]];
  ws = MCBMasterWeight[fam, #] & /@ masters;
  wc = MCBWeightCheck[ws, Table["J" <> ToString[i], {i, Length[masters]}]];
  Join[{<|"Name" -> "rules", "Pass" -> viol === {}, "Detail" -> If[viol === {}, "one power of eps per integral, no eps denominators, rational coefficients, one square root", StringRiffle[viol, "; "]]|>},
    If[letters === {}, {}, With[{lv = Flatten[Table[("J" <> ToString[i] <> ": " <> #) & /@ Select[MCBRuleViolations[fam, masters[[i]], <|"Letters" -> letters|>], StringStartsQ[#, "letters"] &], {i, Length[masters]}]]},
      {<|"Name" -> "letters", "Pass" -> lv === {}, "Detail" -> If[lv === {}, "every denominator factor is a letter", StringRiffle[lv, "; "]]|>}]],
    {<|"Name" -> "weights", "Pass" -> wc["Pass"], "Detail" -> wc["Message"], "Weights" -> ws|>}]];


(* ::Section:: *)
(*Euler*)


MCBEulerMatrix[As_Association, dims_Association, pt_List] := Together[Sum[dims[X] (X /. pt) As[X], {X, Keys[As]}]];

(* rows may be a block of a larger matrix: "Diagonal" gives the column of each row's own master. A row whose weight is
   $Failed (an inhomogeneous master, reported by the weight check) is only checked off the diagonal. *)
MCBEulerCheck[Alist_List, pts_List, dims_Association, ws_, opts_Association : <||>] := Module[{missing, Es, n, m, dc, rn, cn, off, diags, varying, mism,
    analytic, invs = Keys[dims], given, nm, offText},
  missing = Select[invs, dims[#] =!= 0 && ! AllTrue[Alist, Function[a, KeyExistsQ[a, #]]] &];
  If[missing =!= {}, Return[<|"Pass" -> Missing["NotChecked"], "OffDiagonal" -> {}, "Mismatch" -> {}, "Message" -> "not checked: no matrix for " <>
       ToString[missing] <> " (the Euler relation needs the derivative in every invariant of non-zero dimension)"|>]];
  Es = MapThread[MCBEulerMatrix[KeyTake[#1, invs], dims, #2] &, {Alist, pts}];
  n = Length[First[Es]];
  If[n == 0, Return[<|"Pass" -> Missing["NotChecked"], "OffDiagonal" -> {}, "Mismatch" -> {}, "Message" -> "not checked: no rows"|>]];
  m = Length[First[First[Es]]];
  dc = Lookup[opts, "Diagonal", Range[n]];
  rn = Lookup[opts, "RowNames", Range[n]]; cn = Lookup[opts, "ColumnNames", Range[m]];
  nm[x_] := If[StringQ[x], x, ToString[x, InputForm]];
  off = Flatten[Table[If[c =!= dc[[i]] && Es[[p, i, c]] =!= 0, {{p, i, c}}, {}], {p, Length[Es]}, {i, n}, {c, m}], 3];
  diags = Table[Es[[p, i, dc[[i]]]], {p, Length[Es]}, {i, n}];
  analytic = AnyTrue[pts, # === {} &];
  varying = Select[Range[n], Function[i, If[analytic, ! FreeQ[diags[[All, i]], Alternatives @@ invs],
      AnyTrue[Rest[diags[[All, i]]], Together[# - diags[[1, i]]] =!= 0 &]]]];
  given = ListQ[ws] && Length[ws] == n;
  mism = If[given, Select[Range[n], ws[[#]] =!= $Failed && ! MissingQ[ws[[#]]] && AnyTrue[diags[[All, #]], Function[d, Together[d - ws[[#]]] =!= 0]] &], {}];
  offText = StringRiffle[(nm[rn[[#[[2]]]]] <> " -> " <> nm[cn[[#[[3]]]]] <> If[Length[Es] > 1, " (point " <> ToString[#[[1]]] <> ")", ""]) & /@ Take[off, UpTo[3]], ", "];
  <|"Pass" -> off === {} && varying === {} && mism === {}, "Diagonal" -> First[diags],
    "OffDiagonal" -> ({rn[[#[[2]]]], cn[[#[[3]]]], #[[1]]} & /@ Take[off, UpTo[10]]),
    "Mismatch" -> ({rn[[#]], diags[[1, #]], ws[[#]]} & /@ Take[mism, UpTo[10]]),
    "Message" -> If[off === {} && varying === {} && mism === {},
      "Sum_X d_X X A_X = " <> If[Length[Union[Expand /@ First[diags]]] == 1, nm[Expand[First[First[diags]]]] <> " times the identity", "a diagonal matrix"] <>
        If[given && AnyTrue[ws, # =!= $Failed && ! MissingQ[#] &], ", the masters' weights", ""],
      StringRiffle[Join[
        If[off === {}, {}, {ToString[Length[off]] <> " non-zero off-diagonal entries of Sum_X d_X X A_X (row -> column), e.g. " <> offText}],
        If[varying === {}, {}, {"the diagonal changes with the kinematics in rows " <> StringRiffle[nm /@ rn[[Take[varying, UpTo[10]]]], ", "]}],
        If[mism === {}, {}, {"the diagonal is not the master's weight in rows " <>
          StringRiffle[(nm[rn[[#]]] <> " (" <> nm[Together[diags[[1, #]]]] <> ", weight " <> nm[ws[[#]]] <> ")") & /@ Take[mism, UpTo[5]], ", "]}]], "; "]]|>];


End[];
EndPackage[];
