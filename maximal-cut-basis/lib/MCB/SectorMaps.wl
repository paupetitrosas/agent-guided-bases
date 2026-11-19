(* ::Package:: *)

(* ::Title:: *)
(*MaximalCutBasis`SectorMaps`: sectors with the same geometry (the same integrals at mapped kinematics)*)


(* ::Text:: *)
(*Two sectors of a family can be the same Feynman integrals up to a relabelling of their lines and a change of the*)
(*kinematic invariants: a sunrise at s12 and the same sunrise at s35, say. Kira keeps both (they are different*)
(*integrals), and the search for a basis would start from scratch in the second. The Feynman parametrisation*)
(*tells: with Sum_i x_i D_i = k^T M k + 2 Q.k + J over the lines of the sector, U = det M and*)
(*F = Q^T adj(M) Q - U J. The sectors match when a permutation of the lines that keeps the masses makes the U equal,*)
(*and a linear change of the invariants (masses fixed) makes the F equal. A basis of dotted integrals then maps over*)
(*line by line, with its coefficients at the mapped invariants. Numerators on ISPs do not map this way.*)


BeginPackage["MaximalCutBasis`SectorMaps`", {"MaximalCutBasis`", "SkillCore`Tools`", "SkillCore`Records`", "MaximalCutBasis`Family`",
   "MaximalCutBasis`Sectors`"}];

MCBSymanzik::usage = "MCBSymanzik[fam, sector] = <|\"U\", \"F\", \"x\", \"lines\"|>: the Symanzik polynomials of the sector's lines in local Feynman parameters x[[i]] (line lines[[i]]); $Failed when the lines do not depend on every loop momentum (det M = 0).";
MCBSectorMap::usage = "MCBSectorMap[fam, from, to] finds a map under which the integrals of sector from, at mapped invariants, are those of sector to: <|\"from\", \"to\", \"lines\" -> {line of from -> line of to, ...}, \"invariants\" -> {X -> Y(X), ...}|>, meaning j_to(X) = j_from(Y(X)) with the indices moved along the lines; Missing[\"NoMap\"] when there is none. The masses of the lines are kept.";
MCBMapBasis::usage = "MCBMapBasis[fam, map, basis] writes a basis of sector map[\"from\"] (expressions as in masters.m) for sector map[\"to\"]: indices moved along map[\"lines\"], coefficients and square roots at map[\"invariants\"]. Returns $Failed[reason] when an integral has an index outside the lines of the sector (a numerator on an ISP), which this map does not carry.";
MCBGeometryGroups::usage = "MCBGeometryGroups[fam, sectors] groups the sectors (0/1 lists, in the order given) that have the same geometry: <|name -> <|\"sameAs\" -> the first sector of its group, \"lines\", \"invariants\"|>, ...|> for every sector but the first of each group.";
MCBRepeatedGeometry::usage = "MCBRepeatedGeometry[fam, sector, runDir] lists the sectors of the run folder that have a basis (masters.m; eps-form first) and the same geometry as sector: each <|\"from\", \"status\", \"map\" (MCBSectorMap), \"basis\" (MCBMapBasis of its masters.m, or $Failed[reason])|>.";

Begin["`Private`"];


(* ::Section:: *)
(*Symanzik polynomials*)


MCBSymanzik[fam_Association, s_List] := Module[{L = fam["LoopMomenta"], ext = fam["ExternalMomenta"], lines = PropPos[s], n, x, sum, M, Qc, G, J, U, adj, F},
  n = Length[lines];
  x = Array[xp, n];
  sum = Expand[Sum[x[[i]] MCBToSP[fam, fam["Propagators"][[lines[[i]]]]["Expr"]], {i, n}]];
  M = Table[If[a == b, Coefficient[sum, MCBsp[L[[a]], L[[a]]]], Coefficient[sum, MCBsp[L[[a]], L[[b]]]]/2], {a, Length[L]}, {b, Length[L]}];
  U = Expand[Det[M]];
  If[U === 0, Return[$Failed]];
  (* the linear part 2 Sum_a k_a.Q_a, with Q_a written along the independent external momenta *)
  Qc = Table[Coefficient[sum, MCBsp[L[[a]], e]]/2, {a, Length[L]}, {e, ext}];
  G = If[ext === {}, {{}}, fam["Gram"]];
  J = Expand[sum /. Thread[fam["LoopSP"] -> 0]];
  adj = Together[U Inverse[M]];
  F = Expand[If[ext === {}, 0, Sum[adj[[a, b]] (Qc[[a]] . G . Qc[[b]]), {a, Length[L]}, {b, Length[L]}]] - U J];
  <|"U" -> U, "F" -> F, "x" -> x, "lines" -> lines|>];

(* what a permutation must keep: the type and, for a quadratic line, the mass *)
lineClass[fam_, i_] := With[{p = fam["Propagators"][[i]]}, If[p["Type"] === "Quadratic", {"Quadratic", p["Mass2"]}, {"Linear"}]];

massInvariants[fam_, lines_] := Union @@ (Variables[fam["Propagators"][[#]]["Mass2"]] & /@ Select[lines, fam["Propagators"][[#]]["Type"] === "Quadratic" &]);

(* cheap necessary conditions, so that most pairs are told apart without a permutation *)
signature[fam_, sy_Association] := {Length[sy["lines"]], Sort[lineClass[fam, #] & /@ sy["lines"]],
   Length[CoefficientRules[sy["U"], sy["x"]]], Length[CoefficientRules[sy["F"], sy["x"]]],
   Sort[Total /@ Keys[CoefficientRules[sy["F"], sy["x"]]]]};


(* ::Section:: *)
(*Maps*)


(* the permutations of the lines of "to" that keep the class of every line of "from" *)
classPermutations[fam_, la_, lb_] := Module[{classes = DeleteDuplicates[lineClass[fam, #] & /@ la], pa, pb, per},
  pa = Table[Flatten[Position[lineClass[fam, #] & /@ la, c]], {c, classes}];
  pb = Table[Flatten[Position[lineClass[fam, #] & /@ lb, c]], {c, classes}];
  If[Length /@ pa =!= Length /@ pb, Return[{}]];
  per = Tuples[Permutations /@ pb];
  (* perm[[i]]: the position in lb of the line that line la[[i]] goes to *)
  Table[Module[{pm = ConstantArray[0, Length[la]]}, Do[pm[[pa[[c]]]] = p[[c]], {c, Length[classes]}]; pm], {p, per}]];

MCBSectorMap[fam_Association, sa_List, sb_List] := Module[{a = MCBSymanzik[fam, sa], b = MCBSymanzik[fam, sb], perms, x, invs = fam["InvList"],
    masses, Y, ua, fa, ra, rb, eqs, sol, subst},
  If[a === $Failed || b === $Failed || signature[fam, a] =!= signature[fam, b], Return[Missing["NoMap"]]];
  x = b["x"];   (* the same local variables xp[1..n] on both sides *)
  masses = massInvariants[fam, a["lines"]];
  Y = Table[If[MemberQ[masses, X], X, yv[X]], {X, invs}];
  perms = classPermutations[fam, a["lines"], b["lines"]];
  Do[
    ua = a["U"] /. Thread[x -> x[[pm]]];
    If[Expand[ua - b["U"]] =!= 0, Continue[]];
    fa = Expand[a["F"] /. Thread[x -> x[[pm]]]];
    ra = CoefficientRules[fa, x]; rb = CoefficientRules[b["F"], x];
    If[Sort[Keys[ra]] =!= Sort[Keys[rb]], Continue[]];
    (* a linear change of the invariants that turns every coefficient of F_from into that of F_to *)
    eqs = Table[Expand[(Lookup[ra, Key[k]] /. Thread[invs -> Y]) - Lookup[rb, Key[k]]] == 0, {k, Keys[rb]}];
    sol = Quiet@Solve[eqs, Cases[Y, _yv]];
    If[! MatchQ[sol, {{___Rule}, ___}], Continue[]];
    subst = Thread[invs -> (Y /. First[sol] /. yv[X_] :> X)];
    If[Expand[(fa /. subst) - b["F"]] =!= 0, Continue[]];
    Return[<|"from" -> SectorName[sa], "to" -> SectorName[sb], "lines" -> Thread[a["lines"] -> b["lines"][[pm]]],
      "invariants" -> Select[subst, #[[1]] =!= #[[2]] &]|>, Module],
    {pm, perms}];
  Missing["NoMap"]];

MCBMapBasis[fam_Association, map_Association, basis_List] := Module[{lines = Keys[map["lines"]], to = Values[map["lines"]], bad, mv},
  bad = Select[Union[Cases[basis, j[_, a__] :> {a}, Infinity]], Complement[Flatten[Position[#, x_Integer /; x != 0, {1}, Heads -> False]], lines] =!= {} &];
  (* $Failed holds its argument: the message is built first *)
  If[bad =!= {}, With[{msg = "an integral has an index outside the sector's lines (a numerator on an ISP), which the map of lines does not carry: indices " <>
       ToString[First[bad]]}, Return[$Failed[msg]]]];
  mv[a_List] := Module[{b = ConstantArray[0, fam["N"]]}, Do[b[[to[[i]]]] = a[[lines[[i]]]], {i, Length[lines]}]; b];
  (* the integrals first, then the invariants (all at once, as a substitution of the old values) *)
  (basis /. j[f_, a__] :> j[f, Sequence @@ mv[{a}]]) /. map["invariants"]];


(* ::Section:: *)
(*Groups and the run folder*)


MCBGeometryGroups[fam_Association, sectors_List] := Module[{sy, out = <||>, reps = {}, m},
  sy = AssociationMap[MCBSymanzik[fam, #] &, sectors];
  Do[If[sy[s] === $Failed, Continue[]];
    m = Missing["NoMap"];
    Do[If[signature[fam, sy[r]] === signature[fam, sy[s]], m = MCBSectorMap[fam, r, s]; If[! MissingQ[m], Break[]]], {r, reps}];
    If[MissingQ[m], AppendTo[reps, s], out[SectorName[s]] = <|"sameAs" -> m["from"], "lines" -> m["lines"], "invariants" -> m["invariants"]|>],
    {s, sectors}];
  out];

MCBRepeatedGeometry[fam_Association, s_List, runDir_String] := Module[{dirs, done, sy = MCBSymanzik[fam, s], out = {}},
  If[sy === $Failed, Return[{}]];
  dirs = Select[FileNames["j*", runDir], DirectoryQ[#] && StringMatchQ[FileNameTake[#], RegularExpression["j[01]+"]] &&
      FileNameTake[#] =!= SectorName[s] && FileExistsQ[FileNameJoin[{#, "masters.m"}]] &];
  done = Select[Table[<|"dir" -> d, "sector" -> SectorFromName[FileNameTake[d]], "status" -> Lookup[MCBReadBasis[d], "status", "not run"]|>, {d, dirs}],
    Length[#["sector"]] == fam["N"] && Total[#["sector"]] == Total[s] && MemberQ[{"eps-form", "eps-polynomial", "eps-polynomial (dlog search incomplete)"}, #["status"]] &];
  done = SortBy[done, {If[#["status"] === "eps-form", 0, 1], SectorID[#["sector"]]} &];
  Do[With[{m = MCBSectorMap[fam, d["sector"], s]},
      If[! MissingQ[m], AppendTo[out, <|"from" -> SectorName[d["sector"]], "status" -> d["status"], "map" -> m,
         "basis" -> MCBMapBasis[fam, m, Replace[MCBReadMasters[d["dir"]], Except[_List] -> {}]]|>]]],
    {d, done}];
  out];


End[];
EndPackage[];
