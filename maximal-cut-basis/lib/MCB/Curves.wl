(* ::Package:: *)

(* ::Title:: *)
(*MaximalCutBasis`Curves`: non-dlog geometry, any genus*)


(* ::Text:: *)
(*A one-variable maximal cut whose eps = 0 integrand is kinNorm Rz(z)/Sqrt[P(z)] with deg P = n >= 3 lives on*)
(*the hyperelliptic curve y^2 = P(z) of genus g = Ceiling[n/2] - 1.  Every cut differential W(z) dz/y is*)
(*reduced modulo exact forms (Hermite reduction) to*)
(*    a_0 dz/y + ... + a_(n-2) z^(n-2) dz/y  +  Sum_g N_g(z)/(g(z) y) dz      (deg N_g < deg g)*)
(*where g runs over the punctures (twist factors or poles of Rz that do not divide P):*)
(*  - poles at branch factors f | P are removed with d(h y/f^m);*)
(*  - poles of order >= 2 at punctures are lowered with d(h y/f^(m-1)); h is a polynomial ansatz solved*)
(*    BEFORE differentiating;*)
(*  - the polynomial part is lowered with d(z^m y) to degree <= n - 2.*)
(*For n = 2g + 1 the n - 1 = 2g forms z^k dz/y span H^1 of the curve; for n = 2g + 2 there is one more,*)
(*z^(2g) dz/y, of the third kind at the two points at infinity (for a genus-2 sextic, 2g + 1 = 5 forms).*)


BeginPackage["MaximalCutBasis`Curves`", {"MaximalCutBasis`", "SkillCore`Tools`", "SkillCore`Records`", "SkillCore`Pages`", "MaximalCutBasis`Family`",
   "MaximalCutBasis`Sectors`", "MaximalCutBasis`Baikov`", "MaximalCutBasis`CutIntegrands`", "MaximalCutBasis`LeadingSingularities`"}];

MCBCurve::usage = "MCBCurve[cd] returns <|\"P\", \"z\", \"degree\", \"genus\", \"leading\", \"discriminant\", \"punctures\"|> for a one-variable cut y^2 = P(z).";
MCBCurveCoordinates::usage = "MCBCurveCoordinates[W, P, z] reduces W(z) dz/y (y^2 = P) modulo exact forms. Returns {{a_0, ..., a_(n-2)}, {{g, N_g}, ...}}: coordinates on z^k dz/y plus third-kind numerators at the punctures g.";
MCBCurveTargets::usage = "MCBCurveTargets[cd] lists the target differentials: first kind (k <= g-1), second kind, the form with poles at infinity (even degree), third kind at every linear puncture, each <|\"label\", \"index\", \"norm\"|>.";
MCBFibrationTable::usage = "MCBFibrationTable[cd] gives, for a multi-variable cut, the degree of Pr in every variable and the square roots left after integrating that variable first, with their degrees in the other variables.";

Begin["`Private`"];


MCBCurve[cd_Association] := Module[{v, P, n, disc, punct = {}, st = cd["split"], lc},
  If[Length[cd["vars"]] != 1, Return[$Failed]];
  v = First[cd["vars"]]; P = Expand[st["Pr"]]; n = Exponent[P, v];
  lc = Factor[Coefficient[P, v, n]];
  disc = TimeConstrained[Factor[Discriminant[P, v]], 120, "timeout"];
  Do[Do[With[{g = MCBCanonFactor[f[[1]]][[1]]},
       If[! FreeQ[g, v] && PolynomialRemainder[P, g, v] =!= 0, AppendTo[punct, g]]], {f, FactorList[poly]}],
    {poly, Join[cd["cutpolys"], {Numerator[Together[st["Rz"]]], Denominator[Together[st["Rz"]]]}]}];
  <|"P" -> Factor[P], "z" -> v, "degree" -> n, "genus" -> Ceiling[n/2] - 1, "leading" -> lc, "discriminant" -> disc,
    "punctures" -> DeleteDuplicates[punct]|>];

MCBCurveCoordinates[W_, P_, v_] := Catch[curveCoordinates[W, P, v], "mcbcurve"];

curveCoordinates[W_, P_, v_] := Module[{n = Exponent[P, v], ap, poly = 0, parts = <||>, num, den, fl, f, k, A, third = {}, Pp},
  Pp = D[P, v];
  ap = Apart[Together[W], v];
  Do[
    num = Numerator[Together[tm]]; den = Denominator[Together[tm]];
    fl = Select[FactorList[den], ! FreeQ[#[[1]], v] &];
    If[fl === {}, poly += tm; Continue[]];
    f = MCBCanonFactor[fl[[1, 1]]][[1]]; k = fl[[1, 2]];
    A = Together[tm f^k];
    parts[f] = Append[Lookup[parts, f, {}], {k, A}],
    {tm, If[Head[ap] === Plus, List @@ ap, {ap}]}];
  KeyValueMap[Function[{ff, lst},
     Module[{kmax, cur, isBranch = PolynomialRemainder[P, ff, v] === 0, ex},
       cur = Total[#[[2]]/ff^#[[1]] & /@ lst];
       kmax = Max[lst[[All, 1]]];
       Do[
         If[m < 1 || (m == 1 && ! isBranch), Break[]];
         (* d(h y/ff^jj)/(dz/y): pole of order jj+1 at a puncture, of order jj at a branch factor *)
         Module[{hsym = Sum[hc[i] v^i, {i, 0, Exponent[ff, v] - 1}], ex2, lead2, sol, jj = If[isBranch, m, m - 1]},
           ex2 = Together[(D[hsym, v] P + hsym Pp/2)/ff^jj - jj hsym P D[ff, v]/ff^(jj + 1)];
           lead2 = PolynomialRemainder[Together[Numerator[Together[(cur - ex2) ff^m]]], ff, v];
           sol = Quiet@Solve[Thread[CoefficientList[Numerator[Together[lead2]], v] == 0], Table[hc[i], {i, 0, Exponent[ff, v] - 1}]];
           If[sol === {}, Throw[$Failed, "mcbcurve"]];
           cur = Together[cur - (ex2 /. First[sol] /. hc[_] -> 0)]],
         {m, kmax, 1, -1}];
       ex = Apart[Together[cur], v];
       Do[If[FreeQ[Denominator[Together[tt]], v], poly += tt,
            If[! isBranch, AppendTo[third, {ff, Together[tt ff]}], poly += tt]],
         {tt, If[Head[ex] === Plus, List @@ ex, {ex}]}]]], parts];
  poly = Expand[Together[poly]];
  If[! PolynomialQ[poly, v], poly = Together[poly]];
  Module[{dg, r, lc},
    While[PolynomialQ[poly, v] && (dg = Exponent[poly, v]) >= n - 1,
      r = Expand[(dg - n + 1) v^(dg - n) P + v^(dg - n + 1) Pp/2];
      lc = Coefficient[poly, v, dg]/Coefficient[r, v, dg];
      poly = Expand[Together[poly - lc r]]]];
  {Table[Together[Coefficient[poly, v, i]], {i, 0, n - 2}],
   {#[[1, 1]], Together[Total[#[[All, 2]]]]} & /@ GatherBy[third, First]}];

MCBCurveTargets[cd_Association] := Module[{cu = MCBCurve[cd], n, g, v, out = {}, lin},
  If[cu === $Failed, Return[{}]];
  n = cu["degree"]; g = cu["genus"]; v = cu["z"];
  (* For even n the last form, z^(n-2) dz/y, has residues +-1/Sqrt[leading coefficient] at the two points at
     infinity, so it is normalised by that square root (norm = leading coefficient). For n = 2 (genus 0) this is
     dz/y itself, a dlog form. The first- and second-kind forms have no residues and keep norm 1. *)
  Do[AppendTo[out, <|"label" -> If[k == 0, "dz/y", "z^" <> ToString[k] <> " dz/y"] <> Which[k <= g - 1, " (first kind)", k <= 2 g - 1, " (second kind)", True, " (third kind at the points at infinity)"],
      "index" -> k + 1, "norm" -> If[EvenQ[n] && k == n - 2, cu["leading"], 1]|>], {k, 0, n - 2}];
  (* dz/((c z + d) y) has residue 1/(c y(p0)) at its puncture p0 = -d/c, so norm = (1/residue)^2 = c^2 P(p0) *)
  lin = Select[cu["punctures"], Exponent[#, v] == 1 &];
  Do[With[{p0 = v /. First[Solve[lin[[i]] == 0, v]]},
      AppendTo[out, <|"label" -> "dz/((" <> ToString[lin[[i]], InputForm] <> ") y) (third kind)", "index" -> n - 1 + i,
        "norm" -> Factor[Together[(cu["P"] /. v -> p0) Coefficient[lin[[i]], v, 1]^2]], "puncture" -> lin[[i]]|>]],
    {i, Length[lin]}];
  out];

MCBFibrationTable[cd_Association] := Module[{vars = cd["vars"], pr = cd["split"]["Pr"], rows = {}},
  If[pr === 1, Return[{{"rational integrand: no square roots"}}]];
  Do[Module[{d = Exponent[pr, v], fl = FactorList[pr], Pv = 1, Prest = 1, a, left, others = DeleteCases[vars, v], disc},
      Do[If[FreeQ[ff[[1]], v], Prest *= ff[[1]]^ff[[2]], Pv *= ff[[1]]^ff[[2]]], {ff, fl}];
      Which[
        d == 0, AppendTo[rows, {v, 0, "-", "-", "-"}],
        d == 1, AppendTo[rows, {v, 1, "rationalised by v = (t^2 - c)/b", Factor[Prest], Exponent[Prest, #] & /@ others}],
        d == 2, a = Coefficient[Expand[Pv], v, 2]; left = MCBSqFreeSplit[Factor[a Prest]][[1]];
          disc = Factor[Discriminant[Expand[Pv], v]];
          AppendTo[rows, {v, 2, "Euler substitution; branch points collide at disc = " <> ToString[disc, InputForm], left, Exponent[left, #] & /@ others}],
        True, AppendTo[rows, {v, d, "degree > 2: a curve in this variable (elliptic if 3-4)", Factor[Pv], Exponent[Pv, #] & /@ others}]]],
    {v, vars}];
  Prepend[rows, {"variable", "degree of Pr", "first integration", "square root left", "its degrees in the other variables"}]];


End[];
EndPackage[];
