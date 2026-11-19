(* ::Package:: *)

(* ::Title:: *)
(*MaximalCutBasis`Fallbacks`: rungs 3 (d0 shift) and 6 (exporters for INITIAL, Libra, Fuchsia)*)


BeginPackage["MaximalCutBasis`Fallbacks`", {"MaximalCutBasis`", "SkillCore`Tools`", "SkillCore`Records`", "SkillCore`Pages`", "MaximalCutBasis`Family`",
   "MaximalCutBasis`Sectors`", "MaximalCutBasis`Derivatives`", "MaximalCutBasis`Kira`", "MaximalCutBasis`Baikov`",
   "MaximalCutBasis`CutIntegrands`", "MaximalCutBasis`LeadingSingularities`", "MaximalCutBasis`Curves`",
   "MaximalCutBasis`DECheck`", "MaximalCutBasis`Candidates`", "MaximalCutBasis`Reports`", "MaximalCutBasis`AutoPass`"}];

MCBSymanzikU::usage = "MCBSymanzikU[fam, x] is the first Symanzik polynomial of the family in the Feynman parameters x[i] (quadratic parts of all propagators).";
MCBTarasovLower::usage = "MCBTarasovLower[fam, expr, n] rewrites integrals in d0 - 2n - 2 eps dimensions as integrals in d0 - 2 eps: I^(d-2) = (-1)^L U(a_1 A_1^+, ..., a_N A_N^+) I^(d), applied n times.";
MCBDimensionShift::usage = "MCBDimensionShift[fam, sector, d0p, dir, opts] redoes representation, candidates and basis search in d = d0p - 2 eps (d0p < D0, same parity), maps the chosen candidates to D0 - 2 eps with MCBTarasovLower and checks them with MCBCheckBasis. Returns <|\"status\", \"masters\", \"check\", \"shifted\"|>.";
MCBSymbolicCutDE::usage = "MCBSymbolicCutDE[fam, sector, masters, dir, symb] reduces the basis and its derivatives on the maximal cut with the invariants symb kept symbolic (UnitScale -> 1, the others at a numeric point). Returns <|\"A\" -> <|X -> A_X|>, \"point\" -> fixed values|>. A is in the rational frame (square-root ratios dropped).";
MCBExportDE::usage = "MCBExportDE[dir, tool, de, invariants] writes the maximal-cut DE <|X -> A_X|> for \"INITIAL\", \"Libra\" (Mathematica files) or \"Fuchsia\" (Matrix Market, one file per invariant). Returns the files written.";

Begin["`Private`"];


(* ::Section:: *)
(*d0 shift (rung 3)*)


MCBSymanzikU[fam_Association, x_] := Module[{L = fam["LoopMomenta"], M, q},
  M = Table[Sum[With[{e = MCBToSP[fam, fam["Propagators"][[i]]["Expr"]]},
        x[i] If[a == b, Coefficient[e, MCBsp[L[[a]], L[[a]]]], Coefficient[e, MCBsp[L[[a]], L[[b]]]]/2]], {i, fam["N"]}],
     {a, Length[L]}, {b, Length[L]}];
  Expand[Det[M]]];

MCBTarasovLower[fam_Association, expr_, n_Integer : 1] := Module[{x, U, rules, op, e = expr},
  If[n <= 0, Return[expr]];
  U = MCBSymanzikU[fam, x];
  rules = CoefficientRules[U, x /@ Range[fam["N"]]];
  op[j[f_, a__]] := Module[{al = {a}},
    (-1)^fam["L"] Sum[r[[2]] (Times @@ MapThread[Pochhammer, {al, r[[1]]}]) j[f, Sequence @@ (al + r[[1]])], {r, rules}]];
  Do[e = Collect[Expand[e] /. jj : j[_, __] :> op[jj], _j, Together], {n}];
  MCBMarkToolUsed["Tarasov"];   (* cited only when the dimension shift was actually used *)
  e];

MCBDimensionShift[fam_Association, s_List, d0p_Integer, dir_String, opts0_Association : <||>] := Module[{opts = Join[$MCBDefaultOptions, opts0], fam2, reps, cd, cr,
    pts, cm, nmi, red, res, cands, k, shifted, chk, n},
  If[MCBSkippedQ["d0-shift"], Return[<|"status" -> "skipped by user"|>]];
  If[d0p >= fam["D0"] || OddQ[fam["D0"] - d0p], Print["MCBDimensionShift: d0' must be below D0 with the same parity"]; Return[$Failed]];
  n = (fam["D0"] - d0p)/2;
  fam2 = Join[fam, <|"D0" -> d0p|>];
  reps = MCBRepresentations[fam2, s, <|"D0" -> d0p|>];
  If[reps === {}, Return[<|"status" -> "failed", "message" -> "no representation"|>]];
  cd = First[reps];
  Print["  d0' = ", d0p, ": ", cd["geometry"]["text"]];
  pts = Lookup[opts, "Points", MCBPoints[fam, 2, 1]];
  cm = MCBCutMasters[fam2, s, FileNameJoin[{dir, "count"}], First[pts]];
  If[cm["masters"] === $Failed, Return[<|"status" -> "failed", "message" -> "Kira failed while counting the masters in d0' = " <> ToString[d0p]|>]];
  nmi = cm["n"]; opts["nmi"] = nmi;
  cr = MCBCandidatesFor[fam2, s, cd, opts];
  If[cr["candidates"] === {}, Return[<|"status" -> "failed", "message" -> "no candidates in d0' = " <> ToString[d0p]|>]];
  red = MCBReduceCandidates[fam2, s, cr["candidates"], FileNameJoin[{dir, "kira"}], pts];
  (* purity orders the search on a dlog cut only *)
  res = MCBSearchBasis[red, If[AnyTrue[reps, #["geometry"]["class"] === "curve" &] || NoneTrue[reps, MCBDlogGeometryQ], cr["candidates"],
     MCBCandidatePurity[reps, cr["candidates"], <|"Budget" -> 120|>]], nmi];
  If[! AssociationQ[res] || ! KeyExistsQ[res, "cands"], Return[<|"status" -> "failed", "message" -> "no basis in d0' = " <> ToString[d0p], "search" -> res|>]];
  Print["  basis search in d0' = ", d0p, ": ", res["status"]];
  cands = res["cands"]; k = If[res["status"] === "eps-form", res["k"], ConstantArray[0, Length[cands]]];
  (* the same functions written with D0 - 2 eps integrals. Their purity in d0' says nothing about these integrands, and
     the representation they were built in is a d0' one: the record checks them again in the D0 representations *)
  shifted = Table[Join[KeyDrop[cands[[i]], {"pure", "pureDetail", "rep"}], <|"K" -> MCBTarasovLower[fam, cands[[i]]["K"], n], "strict" -> False,
      "provenance" -> "d0-shift (d0' = " <> ToString[d0p] <> ")"|>], {i, Length[cands]}];
  chk = MCBCheckBasis[fam, s, MapThread[MCBMasterExpression, {shifted, k}], FileNameJoin[{dir, "check"}], <|"Points" -> pts|>];
  <|"status" -> chk["status"], "masters" -> MapThread[MCBMasterExpression, {shifted, k}], "cands" -> shifted, "check" -> chk,
    "shifted" -> <|"d0p" -> d0p, "status" -> res["status"], "basis" -> MapThread[MCBMasterExpression, {cands, k}]|>|>];


(* ::Section:: *)
(*Symbolic maximal-cut DE (for the exporters)*)


MCBSymbolicCutDE::roots = "The start basis has different square roots `1`: the matrix would not be the DE of any basis. Give a rational start basis (square roots stripped), or one in which every element has the same square root.";
MCBSymbolicCutDE[fam_Association, s_List, masters_List, dir_String, symb_List, opts_Association : <||>] := Module[{cands, pt0, pt, red, As},
  cands = MCBSplitMaster /@ masters;
  If[MemberQ[cands, $Failed], Return[$Failed]];
  (* MCBSubsetDE drops the ratios Sqrt[r2_i/r2_j]: it is the DE of the basis only when every element has the same root *)
  If[Length[Union[Together[#["r2"]] & /@ cands]] > 1, Message[MCBSymbolicCutDE::roots, Union[Together[#["r2"]] & /@ cands]]; Return[$Failed]];
  pt0 = First[Lookup[opts, "Points", MCBPoints[fam, 1, 5]]];
  pt = Join[If[fam["UnitScale"] =!= None && ! MemberQ[symb, fam["UnitScale"]], {fam["UnitScale"] -> 1}, {}],
     Select[pt0, ! MemberQ[symb, #[[1]]] && #[[1]] =!= fam["UnitScale"] &]];
  red = MCBReduceCandidates[fam, s, cands, dir, {pt}];
  If[red === $Failed, Return[$Failed]];
  As = MCBSubsetDE[red, Range[Length[cands]]];
  If[As === $Failed, Return[$Failed]];
  <|"A" -> AssociationThread[symb -> (Together /@ As[[Flatten[Position[fam["InvList"], #] & /@ symb]]])], "point" -> pt|>];


(* ::Section:: *)
(*Exporters (rung 6)*)


pyString[e_] := StringReplace[ToString[e, InputForm], "^" -> "**"];

MCBExportDE[dir_String, tool_String, de_Association, invs_List : Automatic] := Module[{files = {}, xs = If[invs === Automatic, Keys[de], invs], f},
  If[! DirectoryQ[dir], CreateDirectory[dir, CreateIntermediateDirectories -> True]];
  Switch[tool,
    "INITIAL" | "Libra",
      f = FileNameJoin[{dir, "de_" <> ToLowerCase[tool] <> ".m"}];
      Put[<|"invariants" -> xs, "A" -> (de /@ xs), "eps" -> eps,
          "note" -> "dJ/dX = A[[X]] J on the maximal cut (rational frame). Load " <> tool <> " and follow its manual; bring the new basis back as masters.m expressions and run MCBCheckBasis."|>, f];
      AppendTo[files, f],
    "Fuchsia",
      Do[
        f = FileNameJoin[{dir, "de_fuchsia_" <> ToString[X] <> ".mtx"}];
        With[{A = de[X], n = Length[de[X]]},
          Module[{nz = Select[Flatten[Table[{r, c, A[[r, c]]}, {r, n}, {c, n}], 1], ! TrueQ[#[[3]] == 0] &]},
            Export[f, StringJoin["%%MatrixMarket matrix coordinate expression general\n", ToString[n], " ", ToString[n], " ", ToString[Length[nz]], "\n",
               StringRiffle[(ToString[#[[1]]] <> " " <> ToString[#[[2]]] <> " " <> pyString[Together[#[[3]]]]) & /@ nz, "\n"], "\n"], "Text"]]];
        AppendTo[files, f], {X, xs}],
    _, Print["MCBExportDE: tool must be INITIAL, Libra or Fuchsia"]];
  files];


End[];
EndPackage[];
