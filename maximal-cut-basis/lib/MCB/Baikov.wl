(* ::Package:: *)

(* ::Title:: *)
(*MaximalCutBasis`Baikov`: representation search, cut data, geometry, scoring*)


(* ::Text:: *)
(*A representation is <|"order" -> loop order, "isp" -> ISPs kept, "kind" -> "LBL" | "standard", "comp" -> BaikovPackage output|>.*)
(*BaikovPackage numbers its variables x[1..] as Join[sector propagators, ISPs]; the cut data renames*)
(*them z[i] with the family numbering.  Representations where a Baikov polynomial vanishes*)
(*identically, or on the cut, are rejected: this happens when a loop only sees a light-like vector*)
(*(its Gram determinant is zero).*)


BeginPackage["MaximalCutBasis`Baikov`", {"MaximalCutBasis`", "SkillCore`Tools`", "SkillCore`Records`", "SkillCore`Pages`", "MaximalCutBasis`Family`",
   "MaximalCutBasis`Sectors`"}];

MCBRepresentations::usage = "MCBRepresentations[fam, sector, <|\"Extra\" -> 0, \"TimeLimit\" -> 120, \"Standard\" -> Automatic|>] returns the non-degenerate loop-by-loop representations with the fewest ISPs (+Extra), for every loop order, plus the standard Baikov representation, sorted by MCBScoreRepresentation, with the non-polylog ones (a root of degree above two in every variable) last. \"Standard\" -> Automatic builds the standard representation only when no loop-by-loop one exists, when none is dlog-compatible, or when it has at most $MCBMaxStandardVars cut variables (every ISP of the sector is one); True always, False never. The loop orders are searched together, size by size: an order that needs more than one ISP above the best order gives no representation.";
$MCBMaxStandardVars::usage = "$MCBMaxStandardVars (3) is the largest number of cut variables of a standard Baikov representation that MCBRepresentations builds by default next to loop-by-loop ones: with more, it is slow to build (four times the Baikov time limit) and the leading-singularity search does not finish in it.";
MCBCutData::usage = "MCBCutData[fam, sector, rep, <|\"D0\" -> d0|>] returns the maximal-cut data: z-polynomials, exponents at d = d0 - 2 eps, cut polynomials, the twist split kinNorm Rz/Sqrt[Pr], the Gamma-prefactor rational part and the geometry class.";
MCBSplitTwist::usage = "MCBSplitTwist[cd] = <|\"kinNorm\", \"Rz\", \"Pr\"|>: eps = 0 twist on the cut as kinNorm * Rz(z) / Sqrt[Pr(z)], exponents merged per canonical factor, half-integer exponents split as f^(e+1/2)/Sqrt[f].";
MCBPrefRat::usage = "MCBPrefRat[cd] is the rational eps-dependence of the Gamma prefactor relative to Gamma(1-eps), Gamma(1/2-eps).";
MCBGeometry::usage = "MCBGeometry[cd] = <|\"class\", \"nvars\", \"degrees\", \"genus\", \"text\", \"bulk\", \"boundaries\"|> with class point | rational | sqrt-quadratic | sqrt-mixed | curve | non-polylog. \"bulk\" classifies the eps = 0 square root; \"boundaries\" (MCBBoundaries) restricts it to the zero sets of the factors with integer or O(eps) exponents, and a curve of genus >= 1 there makes the class \"curve\".";
MCBDlogGeometryQ::usage = "MCBDlogGeometryQ[cd] is True unless the geometry is curve (genus >= 1) or non-polylog.";
MCBScoreRepresentation::usage = "MCBScoreRepresentation[cd] = {number of variables, max square-root degree, number of square-root factors, number of ISPs, 1 for the standard representation and 0 for loop-by-loop}, compared lexicographically (smaller is better).";
MCBRepresentationTable::usage = "MCBRepresentationTable[cds] prints order, ISPs, kind, variables, geometry and score of each representation.";
MCBCanonFactor::usage = "MCBCanonFactor[f] = {g, sign} with f = sign g and g having a positive leading coefficient.";
MCBTwistAtZero::usage = "MCBTwistAtZero[cd] is prod G^(exponent at eps = 0) on the cut.";
MCBTwistFactors::usage = "MCBTwistFactors[cd] lists the z-dependent factors of the twist on the cut, merged per canonical factor: <|\"factor\", \"exponent\" (a + b eps), \"e0\" (at eps = 0), \"kind\", \"degrees\"|>. kind: \"branch\" (half-integer e0: a branch locus of the square root), \"integer\" (non-zero integer e0, regulated by eps), \"eps-only\" (e0 = 0: invisible at eps = 0, but its zero set is a boundary that can carry masters), \"unregulated\" (an integer exponent with no eps part: a Gram determinant and a Baikov polynomial share the factor and the eps cancels; poles there are not regulated, and masters live on its zero set beyond the generic count).";
MCBBoundaryGeometry::usage = "MCBBoundaryGeometry[cd, f] restricts the eps = 0 square root of the cut to the zero set of the twist factor f (solved for a variable in which f is linear) and classifies it like MCBGeometry: <|\"factor\", \"kind\", \"exponent\", \"variable\", \"solution\", \"radicand\" (square-free), \"vars\", \"degrees\", \"genus\", \"class\", \"punctures\", \"text\"|>.";
MCBBoundaries::usage = "MCBBoundaries[cd] is MCBBoundaryGeometry for every non-branch twist factor (kinds \"integer\", \"eps-only\" and \"unregulated\").";

Begin["`Private`"];


$MCBMaxStandardVars = 3;

bp[name_String] := MCBQualify["BaikovPackage", name];

needBaikov[] := If[! MCBLoadTool["BaikovPackage"], Print["!! BaikovPackage is not available: MCBSetPath[\"BaikovPackage\", \".../BaikovPackage.m\"]"]; False, True];

lblTry[fam_, s_, order_, isps_, kind_, tl_] := Module[{comp, np = Total[s], zc},
  zc = Thread[bp["x"] /@ Range[np] -> 0];
  comp = Quiet@Block[{Print = (Null &)},
     TimeConstrained[MCBToBaikov[fam, s, isps, order]; If[kind === "standard", bp["BaikovStandard"][], bp["BaikovLBL"][]], tl, $Failed]];
  If[! (ListQ[comp] && Length[comp] == 4), Return[$Failed]];
  If[MemberQ[Expand[comp[[1]]], 0] || MemberQ[Expand[comp[[1]] /. zc], 0], Return[$Failed]];
  <|"order" -> order, "isp" -> isps, "kind" -> kind, "comp" -> comp|>];

MCBRepresentations[fam_Association, s_List, opts_Association : <||>] := Module[{extra = Lookup[opts, "Extra", 0], tl = Lookup[opts, "TimeLimit", 120],
    isp = ISPPos[s], found = {}, c, nmin, orders, std, cds},
  If[! needBaikov[], Return[{}]];
  orders = Lookup[opts, "Orders", Permutations[fam["LoopMomenta"]]];
  (* The fewest ISPs with which each loop order gives a representation, searched size by size over all orders at once.
     Order by order, an order that has none tried every subset of the ISPs: 2^8 BaikovPackage calls and 437 s for the
     a three-line sector with eight ISPs, whose other order needed one ISP. Orders that need more than one ISP above the
     best order are left out: their representations have more variables, and the score puts them after the others. *)
  nmin = <||>;
  Do[
    Do[If[! KeyExistsQ[nmin, order] && AnyTrue[Subsets[isp, {size}], lblTry[fam, s, order, #, "LBL", tl] =!= $Failed &], nmin[order] = size],
      {order, orders}];
    If[Length[nmin] == Length[orders] || (nmin =!= <||> && size >= Min[Values[nmin]] + 1), Break[]],
    {size, 0, Length[isp]}];
  Do[If[nmin[order] + extra <= Length[isp],
      Do[c = lblTry[fam, s, order, sub, "LBL", tl]; If[c =!= $Failed, AppendTo[found, c]], {sub, Subsets[isp, {nmin[order] + extra}]}]],
    {order, Keys[nmin]}];
  (* the same ISP set with the same polynomials from two loop orders is one representation *)
  found = DeleteDuplicatesBy[found, {#["isp"], Sort[Expand /@ #["comp"][[1]]]} &];
  cds = MCBCutData[fam, s, #, opts] & /@ found;
  (* The standard representation has every ISP of the sector as a cut variable. With many of them the
     leading-singularity search only times out in it (twice 600 s with eight ISPs), and it takes longer to
     build. By default it is built only when it is small, when there is nothing else, or when no loop-by-loop
     representation is dlog-compatible: a non-dlog verdict needs every representation to be non-polylogarithmic. *)
  Switch[Lookup[opts, "Standard", Automatic],
    True, std = lblTry[fam, s, fam["LoopMomenta"], isp, "standard", 4 tl],
    False, std = $Failed,
    _, If[cds === {} || Length[isp] <= $MCBMaxStandardVars || NoneTrue[cds, MCBDlogGeometryQ],
      std = lblTry[fam, s, fam["LoopMomenta"], isp, "standard", 4 tl],
      std = $Failed;
      Print["  standard Baikov representation not built: ", Length[isp], " cut variables (more than $MCBMaxStandardVars = ",
        $MCBMaxStandardVars, ") next to ", Length[cds], " dlog-compatible loop-by-loop representation(s); <|\"Standard\" -> True|> builds it"]]];
  If[std =!= $Failed && ! MemberQ[{#["isp"], Sort[Expand /@ #["rep"]["comp"][[1]]]} & /@ cds, {std["isp"], Sort[Expand /@ std["comp"][[1]]]}],
    AppendTo[cds, MCBCutData[fam, s, std, opts]]];
  (* a root of degree above two in every variable ("non-polylog") proves nothing: another representation of the
     same cut can be rational, and the dlog route needs that one. Those go last; then the score. A curve of genus
     >= 1 in one variable is a property of the cut and keeps its place (one variable scores first). *)
  cds = SortBy[cds, {If[#["geometry"]["class"] === "non-polylog", 1, 0], MCBScoreRepresentation[#]} &];
  (* a use of BaikovPackage and of the Baikov representation only when representations came out *)
  If[cds =!= {}, MCBMarkToolUsed["BaikovPackage"]; MCBMarkToolUsed["Baikov"]];
  cds];


(* ::Section:: *)
(*Cut data*)


MCBCanonFactor[f_] := Module[{cr = CoefficientRules[f, Variables[f]]},
  If[cr =!= {} && TrueQ[Negative[cr[[1, 2]]]], {Expand[-f], -1}, {f, 1}]];

MCBCutData[fam_Association, s_List, rep_Association, opts_Association : <||>] := Module[{comp = rep["comp"], vars, ren, polys, pows, zc, d0, cd},
  d0 = Lookup[opts, "D0", fam["D0"]];
  vars = Join[PropPos[s], rep["isp"]];
  ren = Thread[bp["x"] /@ Range[Length[vars]] -> z /@ vars];
  polys = comp[[1]] /. ren; pows = comp[[2]];
  zc = Thread[z /@ PropPos[s] -> 0];
  cd = <|"family" -> fam["Name"], "sector" -> s, "order" -> rep["order"], "isp" -> rep["isp"], "kind" -> rep["kind"],
    "vars" -> (z /@ rep["isp"]), "polys" -> polys, "pows" -> (pows /. bp["d"] -> d0 - 2 eps),
    "cutpolys" -> Factor[polys /. zc], "cutpows" -> (pows /. bp["d"] -> d0 - 2 eps),
    "prefactor" -> (comp[[3]] /. bp["d"] -> d0 - 2 eps), "D0" -> d0, "invariants" -> fam["InvList"], "rep" -> rep|>;
  (* the cut-integrand cache is keyed on this: the polynomials are part of it, so that two families with the same name, or a
     family read again after an edit, never share entries *)
  cd["id"] = Hash[{s, rep["order"], rep["isp"], rep["kind"], d0, fam["NameString"], polys, cd["pows"]}];
  cd["split"] = MCBSplitTwist[cd];
  cd["prefRat"] = MCBPrefRat[cd];
  cd["geometry"] = MCBGeometry[cd];
  cd["score"] = MCBScoreRepresentation[cd];
  cd];

MCBSplitTwist[cd_Association] := Module[{kin = 1, rz = 1, pr = 1, fl, e, acc = <||>, cf},
  Do[
    fl = FactorList[cd["cutpolys"][[i]]];
    Do[e = f[[2]] (cd["cutpows"][[i]] /. eps -> 0);
      If[FreeQ[f[[1]], z], kin *= f[[1]]^e,
        cf = MCBCanonFactor[f[[1]]]; kin *= cf[[2]]^e;
        acc[cf[[1]]] = Lookup[acc, cf[[1]], 0] + e],
      {f, fl}],
    {i, Length[cd["cutpolys"]]}];
  (* kinematic factors of the prefactor (other than Gamma functions and numbers) *)
  Do[If[! NumericQ[f] && FreeQ[f, Gamma] && ! FreeQ[f, Alternatives @@ cd["invariants"]],
      kin *= (f /. eps -> 0)], {f, If[Head[#] === Times, List @@ #, {#}] &[Times @@ Flatten[{cd["prefactor"]}]]}];
  (* f^e with e half-integer = f^(e + 1/2) / Sqrt[f] *)
  KeyValueMap[Function[{f, ee}, If[IntegerQ[ee], rz *= f^ee, rz *= f^(ee + 1/2); pr *= f]], acc];
  <|"kinNorm" -> PowerExpand[kin], "Rz" -> rz, "Pr" -> pr|>];

MCBTwistAtZero[cd_Association] := Times @@ MapThread[Power, {cd["cutpolys"], cd["cutpows"] /. eps -> 0}];

(* Gamma[c + a eps] = Gamma[base + a eps] Pochhammer[base + a eps, c - base], base = 1 or 1/2: the Pochhammer is the rational part *)
ratGamma[arg_] := Module[{c = arg /. eps -> 0, a = Coefficient[Expand[arg], eps], base},
  base = If[IntegerQ[c], 1, 1/2];
  Together[FunctionExpand[Pochhammer[base + a eps, c - base]]]];

MCBPrefRat[cd_Association] := Module[{fs},
  fs = Flatten[Replace[#, t_Times :> List @@ t] & /@ Flatten[{cd["prefactor"]}]];
  Together[Times @@ Table[Replace[f, {Power[Gamma[g_], k_Integer] :> ratGamma[g]^k, Gamma[g_] :> ratGamma[g], _ -> 1}], {f, fs}]]];


(* ::Section:: *)
(*Geometry and score*)


(* The eps = 0 twist only sees factors whose exponent does not vanish at eps = 0. A factor with exponent O(eps) (a Baikov
   polynomial of a one-loop subloop with E = d0 - 2 external legs, for example) is invisible there, but its zero set is a
   boundary of the twisted cycle: masters can live on it, and the square root restricted to it can be a curve even when
   the bulk is rational. Factors with an integer exponent at eps = 0 (regulated poles) are boundaries in the same sense. *)

MCBTwistFactors[cd_Association] := Module[{acc = <||>, fl, cf},
  Do[fl = FactorList[cd["cutpolys"][[i]]];
    Do[If[! FreeQ[f[[1]], z], cf = MCBCanonFactor[f[[1]]];
        acc[cf[[1]]] = Expand[Lookup[acc, cf[[1]], 0] + f[[2]] cd["cutpows"][[i]]]], {f, fl}],
    {i, Length[cd["cutpolys"]]}];
  KeyValueMap[Function[{f, ex}, With[{e0 = ex /. eps -> 0},
      If[ex === 0, Nothing,
        <|"factor" -> f, "exponent" -> ex, "e0" -> e0,
          "kind" -> Which[e0 === 0, "eps-only", IntegerQ[e0] && FreeQ[ex, eps], "unregulated", IntegerQ[e0], "integer", True, "branch"],
          "degrees" -> (Exponent[f, #] & /@ cd["vars"])|>]]], acc]];

(* Sqrt[N/D] = s Sqrt[kin rad]/D with rad square-free: the radicand that decides the geometry *)
squareFree[expr_] := Module[{t = Together[expr], rad = 1, s = 1, kin = 1},
  Do[If[FreeQ[f[[1]], z], kin *= f[[1]]^f[[2]], rad *= f[[1]]^Mod[f[[2]], 2]; s *= f[[1]]^Quotient[f[[2]], 2]],
    {f, FactorList[Numerator[t] Denominator[t]]}];
  <|"rad" -> rad, "sq" -> s, "den" -> Denominator[t], "kin" -> kin|>];

(* a square in the invariants up to a numeric constant: the square root is rational there *)
perfectSquareQ[e_] := AllTrue[FactorList[Factor[e]], NumericQ[#[[1]]] || EvenQ[#[[2]]] &];

classifyRadicand[pr_, vars_List] := Module[{n = Length[vars], degs, g},
  If[n == 0, Return[<|"class" -> "point", "nvars" -> 0, "degrees" -> {}, "genus" -> 0, "text" -> "point (no integration left)"|>]];
  If[FreeQ[pr, z], Return[<|"class" -> "rational", "nvars" -> n, "degrees" -> ConstantArray[0, n], "genus" -> 0,
     "text" -> "rational integrand in " <> ToString[n] <> " variable(s) " <> ToString[vars]|>]];
  degs = Exponent[pr, #] & /@ vars;
  Which[
    n == 1 && degs[[1]] <= 2,
      <|"class" -> "sqrt-quadratic", "nvars" -> 1, "degrees" -> degs, "genus" -> 0,
        "text" -> "one square root of a " <> If[degs[[1]] == 1, "linear", "quadratic"] <> " polynomial in " <> ToString[vars] <> " (rationalisable)"|>,
    n == 1,
      g = Ceiling[degs[[1]]/2] - 1;
      <|"class" -> "curve", "nvars" -> 1, "degrees" -> degs, "genus" -> g,
        "text" -> If[g == 1, "elliptic curve", "hyperelliptic curve of genus " <> ToString[g]] <> " y^2 = P(" <> ToString[vars[[1]]] <> "), deg P = " <> ToString[degs[[1]]]|>,
    Max[degs] <= 2,
      <|"class" -> "sqrt-quadratic", "nvars" -> n, "degrees" -> degs, "genus" -> 0,
        "text" -> "square root of degrees " <> ToString[degs] <> " in " <> ToString[vars]|>,
    AllTrue[degs, # > 2 &],
      <|"class" -> "non-polylog", "nvars" -> n, "degrees" -> degs, "genus" -> Missing["NotComputed"],
        "text" -> "square root of degrees " <> ToString[degs] <> " in " <> ToString[vars] <> ": degree > 2 in every variable (non-polylogarithmic unless a change of variables helps)"|>,
    True,
      <|"class" -> "sqrt-mixed", "nvars" -> n, "degrees" -> degs, "genus" -> Missing["NotComputed"],
        "text" -> "square root of degrees " <> ToString[degs] <> " in " <> ToString[vars] <> " (integrate a low-degree variable first)"|>]];

MCBBoundaryGeometry[cd_Association, f0_] := Module[{f = MCBCanonFactor[f0][[1]], tfs, rec, vars = cd["vars"], pr = cd["split"]["Pr"],
    cand, v, sol, sf, rest, cl, others, punct, base},
  tfs = MCBTwistFactors[cd];
  rec = SelectFirst[tfs, Expand[#["factor"] - f] === 0 &, <|"kind" -> "?", "exponent" -> "?"|>];
  base = <|"factor" -> f, "kind" -> rec["kind"], "exponent" -> rec["exponent"]|>;
  cand = Select[vars, Exponent[f, #] == 1 &];
  If[cand === {}, Return[Join[base, <|"class" -> "not analysed", "genus" -> Missing["NotComputed"],
     "text" -> "boundary " <> ToString[f, InputForm] <> " = 0 is not linear in any cut variable: not analysed"|>]]];
  (* eliminate the variable in which the square root has the highest degree *)
  v = First[SortBy[cand, -Exponent[pr, #] &]];
  sol = Together[v /. First[Solve[f == 0, v]]];
  sf = squareFree[pr /. v -> sol];
  rest = DeleteCases[vars, v];
  cl = classifyRadicand[sf["rad"], rest];
  (* punctures on the boundary: zeros of the other non-branch factors, and the poles of the solution *)
  others = Select[tfs, #["kind"] =!= "branch" && Expand[#["factor"] - f] =!= 0 &];
  punct = Union[Join[Flatten[Select[FactorList[Numerator[Together[#["factor"] /. v -> sol]]][[All, 1]], ! FreeQ[#, z] &] & /@ others],
      Select[FactorList[Denominator[sol]][[All, 1]], ! FreeQ[#, z] &]]];
  punct = Table[<|"puncture" -> p, "rational" -> If[Length[rest] == 1 && Exponent[p, rest[[1]]] == 1,
        perfectSquareQ[sf["rad"] /. First[Solve[p == 0, rest[[1]]]]], Missing["NotComputed"]]|>, {p, punct}];
  Join[base, cl, <|"variable" -> v, "solution" -> sol, "radicand" -> sf["rad"], "vars" -> rest, "punctures" -> punct,
    "text" -> "on " <> ToString[f, InputForm] <> " = 0 (exponent " <> ToString[rec["exponent"], InputForm] <> ", " <> rec["kind"] <> "; " <>
      ToString[v] <> " = " <> ToString[sol, InputForm] <> "): " <> cl["text"] <>
      If[punct =!= {}, "; punctures at " <> StringRiffle[(ToString[#["puncture"], InputForm] <> If[#["rational"] === True, " (rational point)", ""]) & /@ punct, ", "], ""]|>]];

MCBBoundaries[cd_Association] := If[cd["vars"] === {}, {},
   MCBBoundaryGeometry[cd, #["factor"]] & /@ Select[MCBTwistFactors[cd], #["kind"] =!= "branch" &]];

MCBGeometry[cd_Association] := Module[{bulk = classifyRadicand[cd["split"]["Pr"], cd["vars"]], bds, curves},
  bds = If[MemberQ[{"point"}, bulk["class"]], {}, Quiet[MCBBoundaries[cd]]];
  curves = Select[bds, #["class"] === "curve" &];
  (* a curve of genus >= 1 on a boundary is a property of the cut, as in the bulk: the forms of its first kind are masters *)
  If[curves =!= {} && ! MemberQ[{"curve", "non-polylog"}, bulk["class"]],
    Join[bulk, <|"class" -> "curve", "genus" -> Max[#["genus"] & /@ curves], "bulk" -> bulk["class"], "boundaries" -> bds,
      "text" -> bulk["text"] <> "; boundary " <> StringRiffle[#["text"] & /@ curves, "; "]|>],
    Join[bulk, <|"bulk" -> bulk["class"], "boundaries" -> bds|>]]];

MCBDlogGeometryQ[cd_Association] := ! MemberQ[{"curve", "non-polylog"}, cd["geometry"]["class"]];

MCBScoreRepresentation[cd_Association] := Module[{pr = cd["split"]["Pr"], vars = cd["vars"]},
  {Length[vars], If[pr === 1 || vars === {}, 0, Max[Exponent[pr, #] & /@ vars]],
   If[pr === 1, 0, Length[Select[FactorList[pr], ! FreeQ[#[[1]], z] &]]], Length[cd["isp"]], If[cd["kind"] === "standard", 1, 0]}];


MCBRepresentationTable[cds_List] := StringRiffle[Prepend[
    Table[StringRiffle[{ToString[i], cds[[i]]["kind"], ToString[cds[[i]]["order"]], ToString[cds[[i]]["isp"]], ToString[cds[[i]]["vars"]],
       cds[[i]]["geometry"]["class"], ToString[cds[[i]]["score"]]}, "  |  "], {i, Length[cds]}],
    "#  |  kind  |  loop order  |  ISPs  |  cut variables  |  geometry  |  score"], "\n"];


End[];
EndPackage[];
