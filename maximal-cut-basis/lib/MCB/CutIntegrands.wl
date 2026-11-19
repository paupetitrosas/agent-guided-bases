(* ::Package:: *)

(* ::Title:: *)
(*MaximalCutBasis`CutIntegrands`: the maximal-cut integrand of any integral (numerators, dots)*)


(* ::Text:: *)
(*On the maximal cut j[fam, a] -> Res_{z_i = 0} prod z^(-a) u(z).  A dot (a_i >= 2) gives the derivative*)
(*d^(a_i - 1) u / (a_i - 1)!.  Instead of differentiating the Baikov product (slow, and PowerExpand phase*)
(*artefacts), d^alpha u / u is written through Ld[beta] = d^beta log u, and each Ld is evaluated on the*)
(*cut and cached.  The result R(z, eps) = (cut integrand)/(twist on the cut) is a polynomial in eps.*)


BeginPackage["MaximalCutBasis`CutIntegrands`", {"MaximalCutBasis`", "SkillCore`Tools`", "SkillCore`Records`", "SkillCore`Pages`", "MaximalCutBasis`Family`",
   "MaximalCutBasis`Sectors`", "MaximalCutBasis`Baikov`"}];

MCBCutIntegrand::usage = "MCBCutIntegrand[cd, j] returns R(z, eps) = (maximal-cut integrand of j)/(twist on the cut), a polynomial in eps; $Failed if j has a numerator on an ISP that the representation does not keep (use a representation with that ISP), 0 if j vanishes on the cut.";
MCBLeadingEps::usage = "MCBLeadingEps[R] = {k, R0} with R = eps^k (R0 + O(eps)).";
MCBPoolData::usage = "MCBPoolData[cd, pool] returns, for each integral of pool that the representation can express, <|\"j\", \"R\", \"k\", \"R0\"|>.";
MCBCutIntegrand0::usage = "MCBCutIntegrand0[cd, j] = {k, integrand at eps^k including the eps = 0 twist}: what the leading-singularity analysis sees.";
MCBClearCutCache::usage = "MCBClearCutCache[] empties the cache of log-derivatives.";
Ld::usage = "Ld[beta] stands for d^beta log u in MCBDUoverU.";
MCBDUoverU::usage = "MCBDUoverU[alpha] is (d^alpha u)/u written through the Ld[beta].";

Begin["`Private`"];


dLd[expr_, i_] := Module[{syms = Union[Cases[{expr}, Ld[_], Infinity]]},
  Expand[Sum[D[expr, sy] (sy /. Ld[b_] :> Ld[b + UnitVector[Length[b], i]]), {sy, syms}]]];

ClearAll[MCBDUoverU];
MCBDUoverU[alpha_List] := MCBDUoverU[alpha] = Module[{i, prev, e},
  If[AllTrue[alpha, # == 0 &], Return[1]];
  i = First@FirstPosition[alpha, _?Positive];
  e = UnitVector[Length[alpha], i];
  prev = MCBDUoverU[alpha - e];
  Expand[dLd[prev, i] + prev Ld[e]]];

$ldCache = <||>;
MCBClearCutCache[] := ($ldCache = <||>);

ldValue[cd_Association, beta_List] := Module[{key = {cd["id"], beta}, pp = PropPos[cd["sector"]], zs, zc, val},
  If[KeyExistsQ[$ldCache, key], Return[$ldCache[key]]];
  zs = z /@ pp; zc = Thread[zs -> 0];
  val = Collect[Sum[cd["pows"][[k]] Together[D[Log[cd["polys"][[k]]], Sequence @@ DeleteCases[Transpose[{zs, beta}], {_, 0}]] /. zc],
      {k, Length[cd["polys"]]}], eps, Together];
  $ldCache[key] = val];

MCBCutIntegrand[cd_Association, j[_, a__]] := Module[{al = {a}, s = cd["sector"], others, pp, alpha, du, mono},
  others = Complement[ISPPos[s], cd["isp"]];
  If[AnyTrue[others, al[[#]] != 0 &] || AnyTrue[ISPPos[s], al[[#]] > 0 &], Return[$Failed]];
  pp = PropPos[s];
  If[AnyTrue[al[[pp]], # <= 0 &], Return[0]];
  alpha = al[[pp]] - 1;
  mono = Times @@ (z[#]^(-al[[#]]) & /@ cd["isp"]);
  du = MCBDUoverU[alpha] /. Ld[b_] :> ldValue[cd, b];
  Collect[Expand[mono du/(Times @@ (alpha!)), eps], eps, Together]];

MCBLeadingEps[r_] := Module[{t, kk = -3, c, cl},
  If[r === 0, Return[{Infinity, 0}]];
  (* fast path: polynomial in eps; never FirstPosition with a level spec here *)
  If[PolynomialQ[r, eps],
    cl = Together /@ CoefficientList[r, eps];
    kk = LengthWhile[cl, # === 0 &];
    Return[If[kk >= Length[cl], {Infinity, 0}, {kk, Factor[cl[[kk + 1]]]}]]];
  t = Together[r];
  If[t === 0, Return[{Infinity, 0}]];
  While[(c = Together[SeriesCoefficient[t, {eps, 0, kk}]]) === 0 && kk < 8, kk++];
  {kk, Factor[c]}];

MCBPoolData[cd_Association, pool_List] := Module[{r, le},
  DeleteCases[Table[
     r = MCBCutIntegrand[cd, jj];
     If[r === $Failed || r === 0, Nothing, le = MCBLeadingEps[r];
       If[le[[1]] === Infinity, Nothing, <|"j" -> jj, "R" -> r, "k" -> le[[1]], "R0" -> le[[2]]|>]], {jj, pool}], Nothing]];

MCBCutIntegrand0[cd_Association, jj_] := Module[{r = MCBCutIntegrand[cd, jj], le},
  If[r === $Failed || r === 0, Return[r]];
  le = MCBLeadingEps[r];
  {le[[1]], PowerExpand[MCBTwistAtZero[cd] le[[2]]]}];


End[];
EndPackage[];
