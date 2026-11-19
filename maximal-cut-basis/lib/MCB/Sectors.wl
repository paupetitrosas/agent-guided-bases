(* ::Package:: *)

(* ::Title:: *)
(*MaximalCutBasis`Sectors`: sector bookkeeping, integral notation, pools*)


BeginPackage["MaximalCutBasis`Sectors`", {"MaximalCutBasis`", "SkillCore`Tools`", "SkillCore`Records`", "SkillCore`Pages`", "MaximalCutBasis`Family`"}];

SectorOf::usage = "SectorOf[j[fam, a...]] or SectorOf[{a...}] is the 0/1 pattern of positive indices.";
SectorID::usage = "SectorID[s] is Kira's sector number Sum s_i 2^(i-1).";
SectorName::usage = "SectorName[s] is \"j\" followed by the 0/1 pattern (the folder name).";
SectorFromName::usage = "SectorFromName[\"j0101...\"] is the 0/1 list; SectorFromName[id, n] converts a Kira id.";
PropPos::usage = "PropPos[s] are the positions of the propagators of sector s.";
ISPPos::usage = "ISPPos[s] are the positions of the irreducible scalar products of sector s.";
OffCutQ::usage = "OffCutQ[s][j[...]] is True when the integral vanishes on the maximal cut of s.";
DropOffCut::usage = "DropOffCut[s][expr] sets to zero the integrals that vanish on the maximal cut of s.";
JIntegrals::usage = "JIntegrals[expr] lists the j[...] in expr.";
JWeight::usage = "JWeight[j[...], s] is the number of extra dots plus the numerator degree relative to the corner integral of s.";
ComboWeight::usage = "ComboWeight[expr, s] = {number of integrals, max weight, total weight}: the complexity of a combination.";
MCBReadKiraMasters::usage = "MCBReadKiraMasters[file, fam] reads a Kira masters file (lines fam[a1,...]  # id) into j[fam, ...].";
MCBMasterSectors::usage = "MCBMasterSectors[fam] groups the user's master list by sector: an Association name -> <|\"sector\", \"id\", \"nprops\", \"masters\"|> ordered by (number of propagators, id).";
MCBSectorPool::usage = "MCBSectorPool[fam, s, isps, <|\"nd\" -> nd, \"nt\" -> nt, \"w\" -> w, \"cap\" -> cap, \"nmi\" -> n|>] builds the integrals of s with numerator monomials in the ISPs isps of degree <= nd and <= nt dots, total weight <= w, sorted by weight and capped at Max[cap, 6 n + 10].";
MCBCornerIntegral::usage = "MCBCornerIntegral[fam, s] is j[fam, s...] (all sector propagators to the first power, no numerators).";
MCBTerms::usage = "MCBTerms[expr] = <|j -> coefficient|> of a linear combination of integrals, read from the way it is written: products such as prefactor (pieces) are not expanded and nothing is put over a common denominator (the coefficient of an integral that appears in several terms is the sum of their factors). <||> when expr holds no integral, $Failed when it is not linear in them.";
MCBCoefficients::usage = "MCBCoefficients[expr] = <|j -> coefficient|>: MCBTerms when expr is linear in the integrals as written, else the coefficients of the expanded expression.";
MCBEqualAtPointsQ::usage = "MCBEqualAtPointsQ[a, b] is True when a and b agree at two random rational values of every symbol they contain (eps included, each integral replaced by a random integer): an exact comparison in rational numbers that needs no Together or Expand of large coefficients. Values where a or b is singular are skipped.";
MCBRandomValues::usage = "MCBRandomValues[expr, seed, keep] are rules giving a random rational to every symbol of expr except those in keep (and a random integer to every integral).";
MCBLargeQ::usage = "MCBLargeQ[expr] is True when expr is larger than $MCBLargeLeafCount: such coefficients are never put through Together, Expand or Factor by the skill; they are evaluated at points.";
$MCBLargeLeafCount::usage = "$MCBLargeLeafCount (2000) is the LeafCount above which a coefficient counts as large (MCBLargeQ).";

Begin["`Private`"];


SectorOf[a_List] := Boole[# > 0] & /@ a;
SectorOf[j[_, a__]] := SectorOf[{a}];
SectorID[s_List] := Total[s 2^Range[0, Length[s] - 1]];
SectorName[s_List] := "j" <> StringJoin[ToString /@ s];
SectorFromName[name_String] := ToExpression /@ Characters[StringDrop[StringTrim[name], 1]];
SectorFromName[id_Integer, n_Integer] := IntegerDigits[id, 2, n] // Reverse;
PropPos[s_List] := Flatten@Position[s, 1];
ISPPos[s_List] := Flatten@Position[s, 0];

OffCutQ[s_List][j[_, a__]] := AnyTrue[PropPos[s], {a}[[#]] <= 0 &];
DropOffCut[s_List][expr_] := expr /. jj : j[_, __] :> 0 /; OffCutQ[s][jj];

JIntegrals[expr_] := Union@Cases[{expr}, j[_, __], Infinity];

JWeight[j[_, a__], s_List] := Total[Abs[{a} - s]];
ComboWeight[cmb_, s_List] := Module[{js = JIntegrals[cmb]},
  If[js === {}, {0, 0, 0}, {Length[js], Max[JWeight[#, s] & /@ js], Total[JWeight[#, s] & /@ js]}]];

MCBCornerIntegral[fam_Association, s_List] := j[fam["Name"], Sequence @@ s];


(* ::Section:: *)
(*Elements as written: prefactor x pieces*)


(* A basis element may carry a large prefactor, or large coefficients: Expand multiplies the prefactor into every term
   and Together then puts each coefficient over a common denominator, which can take longer than the whole Kira check.
   The functions below read an element as it is written and evaluate it at points instead. *)

$MCBLargeLeafCount = 2000;
MCBLargeQ[e_] := LeafCount[e] > $MCBLargeLeafCount;

(* {integral, coefficient} pairs: a sum gives the pairs of its terms; a product gives the pairs of its one factor that
   holds integrals, times the other factors *)
termList[jj : j[_, __]] := {{jj, 1}};
termList[e_Plus] := With[{ts = termList /@ List @@ e}, If[MemberQ[ts, $Failed], $Failed, Join @@ ts]];
termList[e_Times] := Module[{f = List @@ e, w, t},
  w = Select[f, ! FreeQ[#, j[_, __]] &];
  Which[w === {}, {},
    Length[w] > 1, $Failed,
    True, t = termList[First[w]];
      If[t === $Failed, $Failed, With[{c = Times @@ Select[f, FreeQ[#, j[_, __]] &]}, {#[[1]], c #[[2]]} & /@ t]]]];
termList[e_] := If[FreeQ[e, j[_, __]], {}, $Failed];

MCBTerms[e_] := With[{t = termList[e]}, If[t === $Failed, $Failed, GroupBy[t, First -> Last, Total]]];

MCBCoefficients[e_] := With[{t = MCBTerms[e]},
  If[AssociationQ[t], t, With[{x = Collect[Expand[e], j[_, __]]}, AssociationMap[Coefficient[x, #] &, JIntegrals[x]]]]];

MCBRandomValues[e_, seed_Integer : 1, keep_List : {}] := Module[{js = JIntegrals[e], syms},
  syms = Complement[Union[Cases[{e /. j[__] -> 1}, x_Symbol /; ! NumericQ[x] && Context[x] =!= "System`", {0, Infinity}, Heads -> False]], keep];
  BlockRandom[Join[Table[x -> RandomInteger[{1, 10^9}], {x, js}], Table[x -> RandomPrime[{10^4, 10^6}]/RandomPrime[{10, 10^4}], {x, syms}]],
    RandomSeeding -> seed]];

(* exact in rational numbers; square roots of rational numbers are reduced by Expand, nested ones by RootReduce *)
zeroNumberQ[d_] := With[{z = Expand[d]}, z === 0 || (! FreeQ[z, Power[_, _Rational]] && RootReduce[z] === 0)];
singularQ[d_] := ! FreeQ[d, ComplexInfinity | Indeterminate | DirectedInfinity];

MCBEqualAtPointsQ[a_, b_, n_Integer : 2] := Module[{ok = 0, seed = 0, r, d},
  If[a === b, Return[True]];
  While[ok < n && seed < 10 n, seed++;
    r = MCBRandomValues[{a, b}, 1000 + seed];
    d = Quiet[(a /. r) - (b /. r)];
    If[singularQ[d], Continue[]];
    If[! zeroNumberQ[d], Return[False, Module]];
    ok++];
  ok == n];


MCBReadKiraMasters[file_String, fam_Association] := Module[{ls, nm = fam["NameString"]},
  ls = Select[StringTrim[StringReplace[#, "#" ~~ ___ -> ""]] & /@ Import[file, "Lines"], # =!= "" &];
  Table[With[{e = StringCases[l, nm ~~ "[" ~~ args : Except["]"] .. ~~ "]" :> args]},
     If[e === {}, Nothing, j[fam["Name"], Sequence @@ ToExpression["{" <> First[e] <> "}"]]]], {l, ls}]];

MCBMasterSectors[fam_Association] := Module[{spec = fam["MastersSpec"], ms, file, g},
  ms = Which[
    ListQ[spec], Cases[spec, j[_, __]],
    StringQ[spec],
      file = If[FileExistsQ[spec], spec, FileNameJoin[{fam["Dir"], spec}]];
      If[FileExistsQ[file], MCBReadKiraMasters[file, fam], Print["MCBMasterSectors: masters file ", spec, " not found"]; {}],
    True, {}];
  ms = ms /. j[_, a__] :> j[fam["Name"], a];
  g = GroupBy[ms, SectorOf];
  g = KeySortBy[g, {Total[#], SectorID[#]} &];
  Association@KeyValueMap[SectorName[#1] -> <|"sector" -> #1, "id" -> SectorID[#1], "nprops" -> Total[#1], "masters" -> #2|> &, g]];

MCBSectorPool[fam_Association, s_List, isps_List, opts_Association] := Module[{nd, nt, w, cap, nmi, pp = PropPos[s], mons, dts, res = {}},
  nd = Lookup[opts, "nd", 2]; nt = Lookup[opts, "nt", 2]; w = Lookup[opts, "w", Infinity];
  cap = Lookup[opts, "cap", Infinity]; nmi = Lookup[opts, "nmi", 1];
  mons = Select[Tuples[Range[0, nd], Length[isps]], Total[#] <= nd &];
  dts = Select[Tuples[Range[0, nt], Length[pp]], Total[#] <= nt &];
  Do[If[Total[m] + Total[dd] <= w,
      AppendTo[res, j[fam["Name"], Sequence @@ ReplacePart[s, Join[Thread[isps -> -m], Thread[pp -> 1 + dd]]]]]],
    {m, mons}, {dd, dts}];
  res = SortBy[res, {JWeight[#, s] &, # &}];
  If[cap === Infinity, res, Take[res, UpTo[Max[cap, 6 nmi + 10]]]]];


End[];
EndPackage[];
