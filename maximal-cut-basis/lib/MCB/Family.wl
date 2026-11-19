(* ::Package:: *)

(* ::Title:: *)
(*MaximalCutBasis`Family`: family.wl reader, validation, translation to Baikov / Kira / LiteIBP*)


BeginPackage["MaximalCutBasis`Family`", {"MaximalCutBasis`", "SkillCore`Tools`", "SkillCore`Records`", "SkillCore`Pages`"}];

MCBReadFamily::usage = "MCBReadFamily[file] reads family.wl (an Association, see reference/formats.md) and returns the normalised family object. MCBReadFamily[assoc] normalises an Association directly.";
MCBValidateFamily::usage = "MCBValidateFamily[fam] runs the minimal checks (complete scalar-product basis, non-zero external Gram, mass-dimension homogeneity, declared symbols, consistent dependent momenta). Returns a list of <|\"check\", \"pass\", \"message\"|>.";
MCBValidationReport::usage = "MCBValidationReport[checks] formats the result of MCBValidateFamily as text.";
MCBFamilyOKQ::usage = "MCBFamilyOKQ[checks] is True when every check passed.";
MCBsp::usage = "MCBsp[a, b] is the scalar product a.b (Orderless).";
MCBD::usage = "MCBD[i] stands for the propagator D_i in the scalar-product maps.";
MCBToSP::usage = "MCBToSP[fam, expr] writes a polynomial in momenta (products = dot products) in terms of MCBsp, with the external scalar products substituted.";
MCBInvariants::usage = "MCBInvariants[fam] is the list of invariant symbols.";
MCBPropLabel::usage = "MCBPropLabel[fam, i] is a readable string for D_i.";
MCBToBaikov::usage = "MCBToBaikov[fam, sector, isps, order] sets the BaikovPackage inputs (by full name) for the sector propagators plus the ISPs isps, loop order order.";
MCBToKiraYAML::usage = "MCBToKiraYAML[fam, dir, <|\"Cut\" -> sector, \"TopLevel\" -> {ids}, \"UnitScale\" -> sym|>] writes config/integralfamilies.yaml and config/kinematics.yaml.";
MCBKiraName::usage = "MCBKiraName[fam, X] is the name used for invariant X in the Kira files.";
MCBKiraString::usage = "MCBKiraString[fam, expr] is expr as a string with the Kira names of the invariants.";
MCBInvariantsAsSP::usage = "MCBInvariantsAsSP[fam] expresses the invariants that appear in external scalar products through those scalar products (rules X -> expression in MCBsp).";
MCBToLiteIBP::usage = "MCBToLiteIBP[fam, sector] returns <|\"families0\" -> text, \"slots\" -> ...|> for the LiteIBP/LiteRed files of the FiniteFlow pipeline (maximal cut of sector).";
MCBDimensionOf::usage = "MCBDimensionOf[fam, expr] returns the mass dimension of expr if it is homogeneous, else $Failed.";
MCBRandomPoint::usage = "MCBRandomPoint[fam, seed] is a random rational point for the invariants.";
$MCBReserved::usage = "$MCBReserved lists the symbol names a family must not use for momenta or invariants.";

Begin["`Private`"];

SetAttributes[MCBsp, Orderless];

$MCBReserved = {"j", "eps", "z", "d", "x", "MCBsp", "MCBD",
   (* variables of the generated AnalysisMasters.m *)
   "fam", "sector", "pts", "reps", "cd", "cut", "nmi", "cr", "cands", "red", "res", "basis", "labels", "provenance", "check", "record",
   "rung", "old", "chosen", "flags", "adopt", "status", "steps", "written", "current"};


(* ::Section:: *)
(*Reading*)


MCBReadFamily::nofile = "family file `1` not found.";
MCBReadFamily::noassoc = "family file `1` does not evaluate to an Association.";

MCBReadFamily[file_String] := Module[{f = ExpandFileName[file], raw},
  If[! FileExistsQ[f], Message[MCBReadFamily::nofile, f]; Return[$Failed]];
  raw = Get[f];
  If[! AssociationQ[raw], Message[MCBReadFamily::noassoc, f]; Return[$Failed]];
  MCBReadFamily[Join[raw, <|"File" -> f, "Dir" -> DirectoryName[f]|>]]];

MCBReadFamily[raw_Association] := Module[{fam = <||>, name, loop, ext, dep, props, invs, moms, spR, errs = {},
    extPairs, extSP, eqs, sol, loopSP, spToD, mdims, pdims},
  name = Lookup[raw, "Name", "fam"];
  name = If[StringQ[name], ToExpression[name], name];
  loop = Lookup[raw, "LoopMomenta", {}];
  ext = Lookup[raw, "ExternalMomenta", {}];
  dep = Replace[Lookup[raw, "MomentumConservation", {}], r_Rule :> {r}];
  invs = Lookup[raw, "Invariants", <||>];
  If[ListQ[invs], invs = Association[If[MatchQ[#, _Rule], #, # -> 2] & /@ invs]];
  moms = Join[loop, ext];
  mdims = Join[AssociationThread[Join[moms, Keys[dep]] -> 1], Association[Lookup[raw, "MomentumDimensions", <||>]]];
  (* scalar-product rules for all pairs of loop and independent external momenta *)
  spR = Flatten@Table[If[i == k, moms[[i]]^2 -> MCBsp[moms[[i]], moms[[i]]], moms[[i]] moms[[k]] -> MCBsp[moms[[i]], moms[[k]]]],
     {i, Length[moms]}, {k, i, Length[moms]}];
  props = MapIndexed[normaliseProp[#1, First[#2], dep] &, Lookup[raw, "Propagators", {}]];
  If[MemberQ[props, $Failed], AppendTo[errs, "a propagator is not a valid Association (see formats.md)"]];
  props = DeleteCases[props, $Failed];
  (* external scalar products *)
  extPairs = Flatten[Table[MCBsp[ext[[a]], ext[[b]]], {a, Length[ext]}, {b, a, Length[ext]}]];
  eqs = Table[
     Expand[Expand[(r[[1]] /. dep)] /. spR] == r[[2]],
     {r, Replace[Lookup[raw, "ScalarProducts", {}], r_Rule :> {r}]}];
  sol = If[extPairs === {}, {{}}, Quiet@Solve[eqs, extPairs]];
  extSP = Which[
     sol === {}, AppendTo[errs, "the scalar-product rules are inconsistent (check 5)"]; {},
     ! FreeQ[extPairs /. First[sol], Alternatives @@ extPairs] || Length[First[sol]] < Length[extPairs],
       AppendTo[errs, "the scalar-product rules do not fix every external scalar product: missing " <>
         ToString[Select[extPairs, ! FreeQ[# /. First[sol], Alternatives @@ extPairs] &], InputForm]]; First[sol],
     True, Thread[extPairs -> Together[extPairs /. First[sol]]]];
  loopSP = Join[Flatten[Table[MCBsp[loop[[a]], loop[[b]]], {a, Length[loop]}, {b, a, Length[loop]}]],
     Flatten[Table[MCBsp[l, e], {l, loop}, {e, ext}]]];
  fam = <|
    "Name" -> name, "NameString" -> ToString[name], "LoopMomenta" -> loop, "ExternalMomenta" -> ext,
    "Dependent" -> dep, "Momenta" -> moms, "SPRules" -> spR, "Propagators" -> props, "N" -> Length[props],
    "L" -> Length[loop], "E" -> Length[ext], "Invariants" -> invs, "InvList" -> Keys[invs],
    "UnitScale" -> Lookup[raw, "UnitScale", None], "D0" -> Lookup[raw, "D0", 4], "Letters" -> Replace[Lookup[raw, "Letters", {}], Except[_List] -> {}],
    "MastersSpec" -> Lookup[raw, "Masters", None], "Graph" -> Lookup[raw, "Graph", None],
    "File" -> Lookup[raw, "File", None], "Dir" -> Lookup[raw, "Dir", Directory[]],
    "ExtSP" -> extSP, "ExtPairs" -> extPairs, "LoopSP" -> loopSP, "MomDims" -> mdims,
    "ScalarProductEquations" -> eqs, "Raw" -> raw, "Errors" -> errs|>;
  {fam["TopSectors"], fam["TopSectorsSource"]} = topSectors[raw, Length[props]];
  fam["KinBP"] = Table[With[{a = r[[1, 1]], b = r[[1, 2]]}, If[a === b, a^2, a b] -> r[[2]]], {r, extSP}];
  (* loop scalar products in terms of the propagators MCBD[i] *)
  spToD = If[Length[props] == Length[loopSP] && (ext === {} || extSP =!= {}),
     Quiet@Solve[Table[(MCBToSP[fam, props[[i]]["Expr"]]) == MCBD[i], {i, Length[props]}], loopSP], {}];
  fam["SPtoD"] = If[spToD === {} || spToD === $Failed, $Failed, First[spToD]];
  fam["Gram"] = If[ext === {}, {{1}}, Table[MCBsp[a, b] /. extSP, {a, ext}, {b, ext}]];
  fam["PropDims"] = propDim[fam, #] & /@ props;
  fam];

(* one propagator: <|"Type" -> "Quadratic", "Momentum" -> q, "Mass2" -> m|> or <|"Type" -> "Linear", "Momentum" -> q, "Vector" -> v, "Constant" -> c|> *)
normaliseProp[p_Association, i_, dep_] := Module[{t = Lookup[p, "Type", "Quadratic"], q, v, m, c},
  q = Expand[Lookup[p, "Momentum", $Failed] /. dep];
  If[q === $Failed, Return[$Failed]];
  Switch[ToLowerCase[t],
    "quadratic",
      m = Lookup[p, "Mass2", 0];
      <|"Type" -> "Quadratic", "Momentum" -> q, "Mass2" -> m, "Expr" -> q^2 - m, "Index" -> i,
        "Label" -> "(" <> ToString[q, InputForm] <> ")^2" <> If[m === 0, "", " - " <> ToString[m, InputForm]]|>,
    "linear",
      v = Expand[Lookup[p, "Vector", $Failed] /. dep]; c = Lookup[p, "Constant", 0];
      If[v === $Failed, Return[$Failed]];
      <|"Type" -> "Linear", "Momentum" -> q, "Vector" -> v, "Constant" -> c, "Expr" -> Expand[q v] - c, "Index" -> i,
        "Label" -> "(" <> ToString[q, InputForm] <> ").(" <> ToString[v, InputForm] <> ")" <> If[c === 0, "", " - " <> ToString[c, InputForm]]|>,
    _, $Failed]];
normaliseProp[_, _, _] := $Failed;

(* The top sectors bound the whole-family Kira run that finds the masters when family.wl has no list (MCBFindMastersKira).
   "TopSectors" gives them (sector names j0101..., Kira ids or 0/1 lists); else the internal lines of "Graph" form one;
   else every line does, and then the ISPs count as propagators: Kira reduces a much larger family, and its sectors with
   ISP lines are not sectors of this one. Returns {sectors, source}; a sector that cannot be read is $Failed. *)
topSectors[raw_Association, n_Integer] := Module[{spec = Lookup[raw, "TopSectors", Lookup[raw, "TopSector", None]], one, lines},
  one[x_] := Which[
    StringQ[x] && StringMatchQ[x, RegularExpression["j[01]+"]] && StringLength[x] == n + 1, ToExpression /@ Characters[StringDrop[x, 1]],
    IntegerQ[x] && 0 < x < 2^n, Reverse[IntegerDigits[x, 2, n]],
    MatchQ[x, {(0 | 1) ..}] && Length[x] == n, x,
    True, $Failed];
  Which[
    spec =!= None, {one /@ If[MatchQ[spec, {(0 | 1) ..}] || ! ListQ[spec], {spec}, spec], "family.wl"},
    ListQ[lines = Lookup[raw, "Graph", None]] && (lines = Union[Cases[lines, {_, _, i_Integer} /; 1 <= i <= n :> i]]) =!= {},
      {{Table[Boole[MemberQ[lines, i]], {i, n}]}, "Graph"},
    True, {{ConstantArray[1, n]}, "every line"}]];

MCBToSP[fam_Association, expr_] := Expand[Expand[Expand[expr /. fam["Dependent"]] /. fam["SPRules"]] /. fam["ExtSP"]];

MCBInvariants[fam_Association] := fam["InvList"];

MCBPropLabel[fam_Association, i_Integer] := fam["Propagators"][[i]]["Label"];

MCBRandomPoint[fam_Association, seed_Integer : 1] := BlockRandom[
   Thread[fam["InvList"] -> Table[RandomChoice[{-1, 1}] RandomInteger[{3, 97}]/RandomInteger[{2, 29}], Length[fam["InvList"]]]],
   RandomSeeding -> seed];


(* ::Section:: *)
(*Mass dimensions*)


MCBDimensionOf[fam_Association, expr_] := Module[{lam, e2, r, dims = fam["Invariants"]},
  If[TrueQ[expr == 0], Return[Indeterminate]];
  e2 = expr /. KeyValueMap[#1 -> lam^#2 #1 &, dims];
  r = Factor[PowerExpand[Together[e2/expr]]];
  Which[r === 1, 0, MatchQ[r, lam^_Integer | lam], Exponent[r, lam], True, $Failed]];

momDim[fam_, q_] := Module[{ms = Select[Join[fam["Momenta"], Keys[fam["Dependent"]]], ! FreeQ[q, #] &], ds},
  ds = DeleteDuplicates[Lookup[fam["MomDims"], ms, 1]];
  If[Length[ds] == 1, First[ds], $Failed]];

propDim[fam_, p_] := Module[{dq = momDim[fam, p["Momentum"]]},
  If[dq === $Failed, Return[$Failed]];
  If[p["Type"] === "Quadratic", 2 dq, With[{dv = momDim[fam, p["Vector"]]}, If[dv === $Failed, $Failed, dq + dv]]]];


(* ::Section:: *)
(*Validation*)


check[name_, pass_, msg_] := <|"check" -> name, "pass" -> TrueQ[pass], "message" -> msg|>;

MCBValidateFamily[fam_Association] := Module[{out = {}, n = fam["N"], nsp = Length[fam["LoopSP"]], pt, g, bad, syms, decl, res,
    rank, M},
  (* 0. reading problems *)
  AppendTo[out, check["read", fam["Errors"] === {}, If[fam["Errors"] === {}, "family.wl read", StringRiffle[fam["Errors"], "; "]]]];
  (* 1. complete basis of loop scalar products *)
  M = If[n > 0, Table[Coefficient[MCBToSP[fam, fam["Propagators"][[i]]["Expr"]], s], {i, n}, {s, fam["LoopSP"]}], {}];
  rank = If[M === {}, 0, MatrixRank[M /. MCBRandomPoint[fam, 7]]];
  AppendTo[out, check["complete-basis", n == nsp && rank == nsp && fam["SPtoD"] =!= $Failed,
     "propagators + ISPs: " <> ToString[n] <> "; loop scalar products L(L+1)/2 + L E = " <> ToString[nsp] <>
     "; rank " <> ToString[rank] <> If[n == nsp && rank == nsp, " (complete)", " -> add or change ISPs so that they form a basis"]]];
  (* 2. external Gram determinant *)
  pt = MCBRandomPoint[fam, 11];
  g = If[fam["E"] == 0, 1, Quiet@Det[fam["Gram"] /. pt]];
  AppendTo[out, check["gram", NumericQ[g] && g != 0,
     "det Gram(externals) at a random point = " <> ToString[g, InputForm] <> If[NumericQ[g] && g != 0, "", " -> the external momenta are not independent (remove one or add momentum conservation)"]]];
  (* 3. mass-dimension homogeneity *)
  bad = {};
  Do[With[{p = fam["Propagators"][[i]], dp = fam["PropDims"][[i]]},
      Which[
        dp === $Failed, AppendTo[bad, "D" <> ToString[i] <> ": momenta of different dimensions"],
        p["Type"] === "Quadratic" && ! MatchQ[MCBDimensionOf[fam, p["Mass2"]], dp | Indeterminate],
          AppendTo[bad, "D" <> ToString[i] <> " = " <> p["Label"] <> ": Mass2 has dimension " <> ToString[MCBDimensionOf[fam, p["Mass2"]]] <> ", the momentum part " <> ToString[dp]],
        p["Type"] === "Linear" && ! MatchQ[MCBDimensionOf[fam, p["Constant"]], dp | Indeterminate],
          AppendTo[bad, "D" <> ToString[i] <> " = " <> p["Label"] <> ": the constant has dimension " <> ToString[MCBDimensionOf[fam, p["Constant"]]] <> " but the product has dimension " <> ToString[dp] <> " (declare it with dimension " <> ToString[dp] <> " in Invariants)"]]],
    {i, n}];
  Do[With[{a = r[[1, 1]], b = r[[1, 2]]},
      With[{dv = MCBDimensionOf[fam, r[[2]]], de = Lookup[fam["MomDims"], a, 1] + Lookup[fam["MomDims"], b, 1]},
        If[! MatchQ[dv, de | Indeterminate], AppendTo[bad, ToString[a] <> "." <> ToString[b] <> " = " <> ToString[r[[2]], InputForm] <> " has dimension " <> ToString[dv] <> ", expected " <> ToString[de]]]]],
    {r, fam["ExtSP"]}];
  AppendTo[out, check["dimensions", bad === {}, If[bad === {}, "every propagator and scalar product is homogeneous", StringRiffle[bad, "; "]]]];
  (* 4. declared symbols, reserved names *)
  syms = Union@Cases[{fam["Propagators"][[All, "Expr"]], fam["ExtSP"][[All, 2]]}, s_Symbol /; Context[s] =!= "System`", Infinity];
  decl = Join[fam["InvList"], fam["Momenta"], Keys[fam["Dependent"]]];
  bad = Complement[syms, decl];
  (* Context is HoldFirst: pass evaluated symbols *)
  With[{ctx = Context @@ {fam["Name"]}},
    res = Select[Join[decl, {fam["Name"]}], MemberQ[$MCBReserved, SymbolName[#]] || Context[#] === "System`" || Context[#] =!= ctx &]];
  AppendTo[out, check["symbols", bad === {} && res === {},
     StringJoin[If[bad === {}, "all symbols declared", "undeclared symbols (add them to Invariants): " <> ToString[bad]],
       If[res === {}, "", "; reserved or System symbols used as names: " <> ToString[res] <> " (reserved: " <> StringRiffle[$MCBReserved, ", "] <> ")"]]]];
  (* 5. dependent momenta *)
  bad = Select[Keys[fam["Dependent"]], ! FreeQ[fam["Dependent"][[All, 2]], #] || MemberQ[fam["Momenta"], #] &];
  AppendTo[out, check["momentum-conservation", bad === {} && NoneTrue[fam["Errors"], StringContainsQ[ToString[#], "inconsistent"] &] &&
      AllTrue[fam["Dependent"][[All, 2]], Complement[Variables[#], fam["ExternalMomenta"]] === {} &],
     If[bad === {}, "dependent momenta " <> ToString[Keys[fam["Dependent"]]] <> " consistent with the scalar-product rules",
       "dependent momenta must be written in the independent external momenta only: " <> ToString[bad]]]];
  (* extras *)
  AppendTo[out, check["options", IntegerQ[fam["D0"]] && (fam["UnitScale"] === None || MemberQ[fam["InvList"], fam["UnitScale"]]),
     "D0 = " <> ToString[fam["D0"]] <> ", UnitScale = " <> ToString[fam["UnitScale"]]]];
  (* the top sectors only matter for the whole-family Kira run (find_masters.wls without a masters list) *)
  AppendTo[out, check["top-sectors", ! MemberQ[fam["TopSectors"], $Failed],
     If[MemberQ[fam["TopSectors"], $Failed],
       "\"TopSectors\" must list sector names j0101... of " <> ToString[n] <> " digits, Kira ids or 0/1 lists of length " <> ToString[n],
       StringRiffle[StringJoin["j", ToString /@ #] & /@ fam["TopSectors"], ", "] <> " (from " <> fam["TopSectorsSource"] <> ")" <>
         If[fam["TopSectorsSource"] === "every line" && fam["MastersSpec"] === None,
           "; if some lines are ISPs, give \"TopSectors\" (or \"Graph\"): without a masters list, find_masters.wls would reduce them as propagators", ""]]]];
  out];

MCBFamilyOKQ[checks_List] := AllTrue[checks, #["pass"] &];

MCBValidationReport[checks_List] := StringRiffle[
   Table[StringPadRight[c["check"], 22] <> If[c["pass"], "PASS  ", "FAIL  "] <> c["message"], {c, checks}], "\n"];


(* ::Section:: *)
(*BaikovPackage*)


MCBToBaikov[fam_Association, sector_List, isps_List, order_List] := Module[{pp = Flatten@Position[sector, 1]},
  MCBSetSymbol["BaikovPackage", "Internal", order];
  MCBSetSymbol["BaikovPackage", "External", fam["ExternalMomenta"]];
  MCBSetSymbol["BaikovPackage", "Replacements", fam["KinBP"]];
  MCBSetSymbol["BaikovPackage", "Propagators", fam["Propagators"][[pp, "Expr"]]];
  MCBSetSymbol["BaikovPackage", "PropagatorsExtra", fam["Propagators"][[isps, "Expr"]]];
  Join[pp, isps]];


(* ::Section:: *)
(*Kira*)


$kiraReserved = {"d", "D", "I", "E", "eps", "ep", "Pi", "N", "i", "e"};

(* Kira passes the invariants to Fermat, which rejects capital letters in variable names. Any name that is not made
   of lowercase letters and digits is therefore renamed in the Kira files, and mapped back when the results are read. *)
MCBKiraName[fam_Association, X_Symbol] := Module[{s = SymbolName[X], pos},
  If[MemberQ[$kiraReserved, s] || ! StringMatchQ[s, RegularExpression["[a-z][a-z0-9]*"]],
    pos = First@FirstPosition[fam["InvList"], X, {0}]; "mcbinv" <> ToString[pos], s]];


MCBKiraString[fam_Association, expr_] := Module[{s = ToString[expr, InputForm], rules},
  rules = Select[Table[SymbolName[X] -> MCBKiraName[fam, X], {X, fam["InvList"]}], #[[1]] =!= #[[2]] &];
  If[rules === {}, s, StringReplace[s, (RegularExpression["\\b" <> #[[1]] <> "\\b"] -> #[[2]]) & /@ rules]]];

MCBToKiraYAML[fam_Association, dir_String, opts_Association : <||>] := Module[{cut = Lookup[opts, "Cut", None], top, props, kin, name = fam["NameString"], ms, us},
  If[! DirectoryQ[FileNameJoin[{dir, "config"}]], CreateDirectory[FileNameJoin[{dir, "config"}], CreateIntermediateDirectories -> True]];
  top = Lookup[opts, "TopLevel", If[ListQ[cut], {Total[cut 2^Range[0, fam["N"] - 1]]},
     Total[# 2^Range[0, fam["N"] - 1]] & /@ Select[Lookup[fam, "TopSectors", {ConstantArray[1, fam["N"]]}], ListQ]]];
  props = Table[
     If[p["Type"] === "Quadratic",
       "      - [\"(" <> ToString[p["Momentum"], InputForm] <> ")^2\", \"" <> MCBKiraString[fam, p["Mass2"]] <> "\"]\n",
       "      - {bilinear: [[\"" <> ToString[p["Momentum"], InputForm] <> "\", \"" <> ToString[p["Vector"], InputForm] <> "\"], \"" <> MCBKiraString[fam, p["Constant"]] <> "\"]}\n"],
     {p, fam["Propagators"]}];
  Export[FileNameJoin[{dir, "config", "integralfamilies.yaml"}], StringJoin[
    "integralfamilies:\n",
    "  - name: \"", name, "\"\n",
    "    loop_momenta: [", StringRiffle[ToString /@ fam["LoopMomenta"], ", "], "]\n",
    "    top_level_sectors: [", StringRiffle[ToString /@ top, ", "], "]\n",
    If[ListQ[cut], "    cut_propagators: [" <> StringRiffle[ToString /@ Flatten@Position[cut, 1], ", "] <> "]\n", ""],
    "    propagators:\n", props], "Text"];
  us = Lookup[opts, "UnitScale", None];
  kin = StringJoin[
    "kinematics:\n",
    "  incoming_momenta: [", StringRiffle[ToString /@ fam["ExternalMomenta"], ", "], "]\n",
    "  kinematic_invariants:\n",
    Table["    - [" <> MCBKiraName[fam, X] <> ", " <> ToString[fam["Invariants"][X]] <> "]\n", {X, fam["InvList"]}],
    "  scalarproduct_rules:\n",
    If[fam["ExtSP"] === {}, "    []\n",
      Table["    - [[" <> ToString[r[[1, 1]]] <> ", " <> ToString[r[[1, 2]]] <> "], \"" <> MCBKiraString[fam, r[[2]]] <> "\"]\n", {r, fam["ExtSP"]}]],
    If[us =!= None, "  symbol_to_replace_by_one: " <> MCBKiraName[fam, us] <> "\n", ""]];
  (* an empty rule list must be written inline *)
  kin = StringReplace[kin, "scalarproduct_rules:\n    []\n" -> "scalarproduct_rules: []\n"];
  Export[FileNameJoin[{dir, "config", "kinematics.yaml"}], kin, "Text"];
  top];


(* ::Section:: *)
(*LiteIBP / LiteRed (FiniteFlow pipeline)*)


MCBInvariantsAsSP[fam_Association] := Module[{eqs, invs, J, rows = {}, pt = MCBRandomPoint[fam, 5], sol, r},
  eqs = (#[[1]] - #[[2]]) & /@ fam["ExtSP"];
  invs = Select[fam["InvList"], ! FreeQ[fam["ExtSP"][[All, 2]], #] &];
  If[invs === {} || eqs === {}, Return[{}]];
  J = Table[D[e, X], {e, eqs}, {X, invs}] /. pt;
  Do[If[MatrixRank[J[[Append[rows, r]]]] > Length[rows], AppendTo[rows, r]], {r, Length[eqs]}];
  sol = Quiet@Solve[Thread[eqs[[rows]] == 0], invs];
  If[sol === {} || ! ListQ[sol], {}, Select[First[sol], FreeQ[#[[2]], Alternatives @@ invs] &]]];

mmString[fam_, q_] := Module[{s = ToString[Expand[q], InputForm], names},
  names = SymbolName /@ Join[fam["Momenta"], Keys[fam["Dependent"]]];
  StringReplace[s, RegularExpression["\\b(" <> StringRiffle[names, "|"] <> ")\\b"] -> "mm[$1]"]];

spString[expr_] := StringReplace[ToString[expr /. MCBsp[a_, b_] :> MCBspPrint[a, b], InputForm],
   RegularExpression["[A-Za-z`]*MCBspPrint\\["] -> "mmp["];

MCBToLiteIBP[fam_Association, sector_List] := Module[{kin, props, invs, dummy = "mcbpout", ext},
  kin = StringRiffle[Table[" mmp[" <> ToString[r[[1, 1]]] <> ", " <> ToString[r[[1, 2]]] <> "] -> " <> ToString[r[[2]], InputForm], {r, fam["ExtSP"]}], ",\n"];
  props = StringRiffle[Table[
      If[p["Type"] === "Quadratic",
        " mp2[" <> mmString[fam, p["Momentum"]] <> "]" <> If[p["Mass2"] === 0, "", " - (" <> ToString[p["Mass2"], InputForm] <> ")"],
        " mp[" <> mmString[fam, p["Momentum"]] <> ", " <> mmString[fam, p["Vector"]] <> "]" <> If[p["Constant"] === 0, "", " - (" <> ToString[p["Constant"], InputForm] <> ")"]],
      {p, fam["Propagators"]}], ",\n"];
  invs = MCBInvariantsAsSP[fam];
  ext = ToString /@ fam["ExternalMomenta"];
  <|"families0" -> StringJoin[
      "(* ::Package:: *)\n\n(* written by MaximalCutBasis from family.wl *)\n\nKinematics0 = {\n", kin, "\n};\n\n",
      "Propagators[1] = {\n", props, "\n};\n"],
    "KINEMATICS" -> kin, "PROPAGATORS" -> props,
    "FAMILY" -> fam["NameString"], "D0" -> ToString[fam["D0"]],
    "LOOP" -> "{" <> StringRiffle[ToString /@ fam["LoopMomenta"], ", "] <> "}",
    (* LiteIBP needs one momentum-conservation rule: an auxiliary outgoing momentum balancing the independent ones *)
    "EXTERNAL" -> "{" <> StringRiffle[Append[ext, dummy], ", "] <> "}",
    "MOMCONS" -> "{mm[" <> dummy <> "] -> " <> If[ext === {}, "0", StringRiffle["-mm[" <> # <> "]" & /@ ext, " "]] <> "}",
    "INVARIANTS" -> "{" <> StringRiffle[(ToString[#[[1]]] <> " -> " <> spString[#[[2]]]) & /@ invs, ", "] <> "}",
    "ALLINV" -> "{" <> StringRiffle[ToString /@ fam["InvList"], ", "] <> "}",
    "SECTORPATTERN" -> "{" <> StringRiffle[If[# == 1, "_", "0"] & /@ sector, ", "] <> "}",
    "CUT" -> "{" <> StringRiffle[ToString /@ sector, ", "] <> "}"|>];


End[];
EndPackage[];
