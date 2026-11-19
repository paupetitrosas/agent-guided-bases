(* ::Package:: *)

(* ::Title:: *)
(*MaximalCutBasis`Derivatives`: d/dX of integrals for arbitrary kinematics*)


(* ::Text:: *)
(*A derivative in an invariant X acts on the external momenta through a vector field*)
(*O_X = Sum c_ab p_a.d/dp_b chosen so that O_X (p_c.p_d) = d(p_c.p_d)/dX for every pair of*)
(*independent externals, plus the explicit derivative of the masses and of the constants*)
(*of linear propagators.  The Lorentz freedom in c_ab is fixed by setting free coefficients to 0.*)


BeginPackage["MaximalCutBasis`Derivatives`", {"MaximalCutBasis`", "SkillCore`Tools`", "SkillCore`Records`", "SkillCore`Pages`", "MaximalCutBasis`Family`",
   "MaximalCutBasis`Sectors`"}];

MCBVectorField::usage = "MCBVectorField[fam, X] returns the rules c[pa, pb] -> value of the external vector field Sum c_ab pa.d/dpb that reproduces d/dX on every external scalar product.";
MCBdPropdX::usage = "MCBdPropdX[fam, i, X] is dD_i/dX as a linear polynomial in the propagator symbols MCBD[l].";
MCBDerivJ::usage = "MCBDerivJ[fam, j[...], X] is d/dX of one integral, as a combination of integrals.";
MCBDerivExpr::usage = "MCBDerivExpr[fam, expr, X] is d/dX of a combination Sum c(X, eps) j.";
MCBScalingResidue::usage = "MCBScalingResidue[fam, j] = Sum_X [X] X d_X j - (L d - Sum a_i [D_i]) j. Reduced by IBPs it must vanish: this tests the derivatives and the Kira sign convention for linear propagators.";
MCBvf::usage = "MCBvf[pa, pb] is a coefficient of the external vector field.";
MCBVectorFieldAt::usage = "MCBVectorFieldAt[fam, X, point] is MCBVectorField solved at a numeric kinematic point (rules for the invariants).";
MCBdPropdXAt::usage = "MCBdPropdXAt[fam, i, X, point] is MCBdPropdX at a numeric point: dD_i/dX with numeric coefficients.";
MCBDerivJAt::usage = "MCBDerivJAt[fam, j[...], X, point] is MCBDerivJ at a numeric point (much cheaper than the symbolic version for many invariants).";
MCBDerivExprAt::usage = "MCBDerivExprAt[fam, expr, X, point] is MCBDerivExpr at a numeric point. expr is read as it is written (prefactor x pieces, or sums of such terms): each factor free of integrals is differentiated symbolically and evaluated at the point, and only then combined with the pieces, so a large prefactor is never expanded or put over a common denominator.";
MCBScalingResidueAt::usage = "MCBScalingResidueAt[fam, j, point] is MCBScalingResidue at a numeric point.";

$MCBPointDerivatives::usage = "$MCBPointDerivatives (True by default): MCBReduceCandidates builds the derivatives of the candidates at each kinematic point (MCBDerivExprAt) instead of symbolically (MCBDerivExpr). Both give the same reduced matrices; the point-wise version is much cheaper with many invariants.";

Begin["`Private`"];


famKey[fam_] := Hash[{fam["Propagators"][[All, "Expr"]], fam["ExtSP"], fam["InvList"]}];

$vfCache = <||>;
MCBVectorField::none = "no external vector field reproduces d/d`1` (degenerate kinematics?).";

MCBVectorField[fam_Association, X_] := Module[{key = {famKey[fam], X}, ext = fam["ExternalMomenta"], cs, pairs, eqs, sol, res},
  If[KeyExistsQ[$vfCache, key], Return[$vfCache[key]]];
  If[ext === {}, Return[$vfCache[key] = {}]];
  cs = Flatten@Table[MCBvf[a, b], {a, ext}, {b, ext}];
  pairs = Flatten[Table[{ext[[a]], ext[[b]]}, {a, Length[ext]}, {b, a, Length[ext]}], 1];
  eqs = Table[
     Sum[MCBvf[a, b] MCBToSP[fam, a D[pr[[1]] pr[[2]], b]], {a, ext}, {b, ext}] == D[MCBsp @@ pr /. fam["ExtSP"], X],
     {pr, pairs}];
  sol = Quiet@Solve[eqs, cs];
  If[sol === {}, Message[MCBVectorField::none, X]; Return[$Failed]];
  res = Thread[cs -> Together[(cs /. First[sol]) /. MCBvf[__] -> 0]];
  $vfCache[key] = res];

$dpCache = <||>;
MCBdPropdX[fam_Association, i_Integer, X_] := Module[{key = {famKey[fam], i, X}, cf, ext, expl, e = fam["Propagators"][[i]]["Expr"], exts = fam["ExternalMomenta"], res},
  If[KeyExistsQ[$dpCache, key], Return[$dpCache[key]]];
  cf = MCBVectorField[fam, X];
  If[cf === $Failed, Return[$Failed]];
  ext = Sum[(MCBvf[a, b] /. cf) MCBToSP[fam, a D[e, b]], {a, exts}, {b, exts}];
  (* explicit dependence: the "- m2" of a quadratic and the "- c" of a linear propagator *)
  expl = D[e /. Thread[Join[fam["Momenta"], Keys[fam["Dependent"]]] -> 0], X];
  res = Collect[Expand[(ext /. fam["SPtoD"]) + expl], MCBD[_], Together];
  $dpCache[key] = res];

MCBDerivJ[fam_Association, j[f_, a__], X_] := Module[{al = {a}, n = fam["N"], res = 0, dp, shifted},
  Do[
    If[al[[i]] != 0,
      dp = MCBdPropdX[fam, i, X];
      shifted = ReplacePart[al, i -> al[[i]] + 1];
      res += -al[[i]] (dp /. MCBD[_] -> 0) j[f, Sequence @@ shifted];
      Do[With[{cl = Coefficient[dp, MCBD[l]]},
          If[cl =!= 0, res += -al[[i]] cl j[f, Sequence @@ ReplacePart[shifted, l -> shifted[[l]] - 1]]]], {l, n}]],
    {i, n}];
  Collect[res, _j, Together]];

MCBDerivExpr[fam_Association, expr_, X_] := Module[{e = Collect[Expand[expr], _j], ints},
  ints = JIntegrals[e];
  Collect[Sum[D[Coefficient[e, jj], X] jj + Coefficient[e, jj] MCBDerivJ[fam, jj, X], {jj, ints}], _j, Together]];

MCBScalingResidue[fam_Association, jj : j[_, a__]] := Module[{dimI},
  dimI = fam["L"] (fam["D0"] - 2 eps) - Total[{a} fam["PropDims"]];
  Collect[Sum[fam["Invariants"][X] X MCBDerivJ[fam, jj, X], {X, fam["InvList"]}] - dimI jj, _j, Together]];


(* ::Section:: *)
(*The same derivatives at a numeric point*)


(* ::Text:: *)
(*The DE check only needs the derivatives at its kinematic points. Building them symbolically first means*)
(*simplifying rational functions with the inverse Gram determinant of the external momenta in the denominator,*)
(*for every propagator and invariant; with four external momenta and seven invariants that took minutes. Here*)
(*the invariants are replaced by the point's numbers as early as possible: the vector field is solved at the*)
(*point (another solution only differs by a Lorentz rotation, which leaves scalar integrals unchanged), and the*)
(*coefficients of the propagator derivatives are numbers. The symbolic functions above stay for FiniteFlow.*)


(* the default; set it to False to go back to the symbolic derivatives in the DE check and the self-test *)
$MCBPointDerivatives = True;

$vfPtCache = <||>;
MCBVectorFieldAt[fam_Association, X_, pt_List] := Module[{key = {famKey[fam], X, pt}, ext = fam["ExternalMomenta"], cs, pairs, eqs, sol, res},
  If[KeyExistsQ[$vfPtCache, key], Return[$vfPtCache[key]]];
  If[ext === {}, Return[$vfPtCache[key] = {}]];
  cs = Flatten@Table[MCBvf[a, b], {a, ext}, {b, ext}];
  pairs = Flatten[Table[{ext[[a]], ext[[b]]}, {a, Length[ext]}, {b, a, Length[ext]}], 1];
  eqs = Table[
     (Sum[MCBvf[a, b] MCBToSP[fam, a D[pr[[1]] pr[[2]], b]], {a, ext}, {b, ext}] /. pt) == (D[MCBsp @@ pr /. fam["ExtSP"], X] /. pt),
     {pr, pairs}];
  sol = Quiet@Solve[eqs, cs];
  If[sol === {}, Message[MCBVectorField::none, X]; Return[$Failed]];
  res = Thread[cs -> ((cs /. First[sol]) /. MCBvf[__] -> 0)];
  $vfPtCache[key] = res];

$dpPtCache = <||>;
MCBdPropdXAt[fam_Association, i_Integer, X_, pt_List] := Module[{key = {famKey[fam], i, X, pt}, cf, ext, expl, e = fam["Propagators"][[i]]["Expr"], exts = fam["ExternalMomenta"], res},
  If[KeyExistsQ[$dpPtCache, key], Return[$dpPtCache[key]]];
  cf = MCBVectorFieldAt[fam, X, pt];
  If[cf === $Failed, Return[$Failed]];
  ext = Sum[(MCBvf[a, b] /. cf) MCBToSP[fam, a D[e, b]], {a, exts}, {b, exts}];
  expl = D[e /. Thread[Join[fam["Momenta"], Keys[fam["Dependent"]]] -> 0], X];
  res = Collect[Expand[((ext /. fam["SPtoD"]) + expl) /. pt], MCBD[_]];
  $dpPtCache[key] = res];

MCBDerivJAt[fam_Association, j[f_, a__], X_, pt_List] := Module[{al = {a}, n = fam["N"], res = 0, dp, shifted},
  Do[
    If[al[[i]] != 0,
      dp = MCBdPropdXAt[fam, i, X, pt];
      shifted = ReplacePart[al, i -> al[[i]] + 1];
      res += -al[[i]] (dp /. MCBD[_] -> 0) j[f, Sequence @@ shifted];
      Do[With[{cl = Coefficient[dp, MCBD[l]]},
          If[cl =!= 0, res += -al[[i]] cl j[f, Sequence @@ ReplacePart[shifted, l -> shifted[[l]] - 1]]]], {l, n}]],
    {i, n}];
  Collect[res, _j, Together]];

(* The element is differentiated as it is written, prefactor x pieces: a factor free of integrals is differentiated once
   and evaluated at the point, the factor that holds the integrals is evaluated there (its own derivative recursively),
   and only these numbers are combined. Nothing is expanded, and Together only sees numbers and eps. *)
MCBDerivExprAt[fam_Association, expr_, X_, pt_List] := Collect[derivAt[fam, expr, X, pt], _j, Together];

derivAt[fam_, jj : j[_, __], X_, pt_] := MCBDerivJAt[fam, jj, X, pt];
derivAt[fam_, e_Plus, X_, pt_] := derivAt[fam, #, X, pt] & /@ e;
derivAt[fam_, e_Times, X_, pt_] := Module[{f = List @@ e, w, c},
  w = Select[f, ! FreeQ[#, j[_, __]] &];
  If[Length[w] != 1, Return[derivExpandedAt[fam, e, X, pt]]];
  c = Times @@ Select[f, FreeQ[#, j[_, __]] &];
  (D[c, X] /. pt) (First[w] /. pt) + (c /. pt) derivAt[fam, First[w], X, pt]];
derivAt[fam_, e_, X_, pt_] := If[FreeQ[e, j[_, __]], 0, derivExpandedAt[fam, e, X, pt]];

(* anything else (a power of a sum, say): expanded, as before *)
derivExpandedAt[fam_, expr_, X_, pt_] := Module[{e = Collect[Expand[expr], _j]},
  Sum[(D[Coefficient[e, jj], X] /. pt) jj + (Coefficient[e, jj] /. pt) MCBDerivJAt[fam, jj, X, pt], {jj, JIntegrals[e]}]];

MCBScalingResidueAt[fam_Association, jj : j[_, a__], pt_List] := Module[{dimI},
  dimI = fam["L"] (fam["D0"] - 2 eps) - Total[{a} fam["PropDims"]];
  Collect[Sum[fam["Invariants"][X] (X /. pt) MCBDerivJAt[fam, jj, X, pt], {X, fam["InvList"]}] - dimI jj, _j, Together]];


End[];
EndPackage[];
