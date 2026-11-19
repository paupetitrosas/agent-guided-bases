(* ::Package:: *)

(* ::Title:: *)
(*PoleFreeBasis`System`: the system of families, images, roots and masters*)


BeginPackage["PoleFreeBasis`System`", {"PoleFreeBasis`", "PoleFreeBasis`Config`", "MaximalCutBasis`", "SkillCore`Tools`", "SkillCore`Records`", "SkillCore`Pages`",
  "MaximalCutBasis`Family`", "MaximalCutBasis`Sectors`", "MaximalCutBasis`Rules`"}];

Dinv::usage = "Dinv[expr, X] in a masters file stands for the derivative of expr with respect to the invariant X.";
PFBReadSystem::usage = "PFBReadSystem[file] reads system.wl (see reference/formats.md) and returns the system object: families (base and images; a family's optional \"MCBRun\", the maximal-cut-basis run folder that produced its masters, as an absolute path under \"MCBRun\"), roots, masters with global labels ut[k], symmetry rules and policy.";
PFBValidateSystem::usage = "PFBValidateSystem[sys] runs the checks of reference/workflow.md, section 2 (SKILL.md's step 1; a family's \"MCBRun\" included: a base family's, a folder with the run_info.m of a maximal-cut-basis run of the same family). Returns <|\"Errors\" -> {...}, \"Warnings\" -> {...}, \"Questions\" -> {...}|>; questions are ambiguities to put to the user. PFBValidateSystem[sys, runDir] adds what the run's SOFIA caches say: families without letters whose candidate singularities wait for the user's yes (questions, PFBSingularityOffers), and \"LettersFromSOFIA\" -> True without a usable cache (warnings).";
PFBMasters::usage = "PFBMasters[sys] is the list of master records, in label order. A record has Label, Family, Base, Pos, Def (as written, with root symbols), Mono (root monomial), Pref (Mono with the square roots written out), RootFree (Def with every root set to 1), Sector, SectorKey, Integrals.";
PFBMaster::usage = "PFBMaster[sys, k] is the record of ut[k].";
PFBFamily::usage = "PFBFamily[sys, name] is the family object (maximal-cut-basis format) of a base or image family.";
PFBBaseOf::usage = "PFBBaseOf[sys, fam] is the base family of an image (fam itself for a base family).";
PFBImagesOf::usage = "PFBImagesOf[sys, fam] lists the image families of a base family.";
PFBImageExpr::usage = "PFBImageExpr[sys, expr, image] maps an expression of the base family to the image family: integral family renamed, invariants mapped, roots renamed.";
PFBSectorKey::usage = "PFBSectorKey[sys, rec] is {base family, sector} of a master record: images share the key of their base sector.";
PFBSectorString::usage = "PFBSectorString[key] is \"fam/j0101...\" for a sector key {fam, sector}.";
PFBSectorDir::usage = "PFBSectorDir[runDir, key] is the folder of a sector of a run.";
PFBSectorKeys::usage = "PFBSectorKeys[sys] lists every sector key, bottom-up: fewest propagators first, then family order.";
PFBSectorMasters::usage = "PFBSectorMasters[sys, key] lists the labels of the masters of a sector key (base family and its images).";
PFBRootDefs::usage = "PFBRootDefs[sys] are the rules root symbol -> Sqrt[radicand], base roots first, then the roots of each image in family order.";
PFBRootMonomial::usage = "PFBRootMonomial[sys, expr] = {mono, rest}: the root symbols multiplying expr and the root-free remainder (roots set to 1).";
PFBRawMasters::usage = "PFBRawMasters[sys, fam] = <|\"File\", \"Raw\" -> the elements of the family's masters file as written (flattened, before \"Rules\"), \"Prefactors\" -> its prefactor list or None|>, or Missing[\"NoFile\"] for a family without its own masters file (an image that follows the maps).";
PFBRootify::usage = "PFBRootify[sys, expr] replaces explicit square roots Sqrt[R] by root symbols of the system (new symbols are created and recorded when no root matches).";
PFBEpsPowers::usage = "PFBEpsPowers[expr] lists {integral, {powers of eps in its coefficient}} for a combination of integrals (Dinv arguments included).";
PFBRuleViolations::usage = "PFBRuleViolations[sys, expr, opts] lists the hard-rule violations of a root-free master definition (empty if it is allowed): rules 1, 2 and 4 (mixed powers of eps in one coefficient, eps in a denominator, a coefficient that is not rational in the invariants) and, with an alphabet, denominator factors that are not letters (MCBRuleViolations). ut[k] terms are checked through the integrals they stand for, Dinv[a, x] through a. opts: \"Letters\" (default PFBLetters[sys]; {} for no letter check).";
PFBLetters::usage = "PFBLetters[sys] is the alphabet of the system: \"Letters\" of system.wl and of the base families' family.wl, SOFIA's polynomials of the base families whose entry has \"LettersFromSOFIA\" -> True (PFBAttachSOFIALetters, called by PFBStartRun), with their images under the invariant maps of the image families; {} when none is given (no letter check).";
PFBMasterWeight::usage = "PFBMasterWeight[sys, def, pref] is the Euler weight (mass dimension) of the master pref*def, for a root-free definition def (ut[k] terms and Dinv[a, x] included, integrals of any family of the system); $Failed when its terms differ (MCBMasterWeight).";
PFBMasterWeights::usage = "PFBMasterWeights[sys, labels] = <|label -> weight|> of the masters as defined (default: every master).";
PFBEulerCheck::usage = "PFBEulerCheck[sys, data, opts] checks the Euler relation Sum_X d_X X R_X = diag(weights) on the rows of a slice (data = slice; opts \"Rows\" -> labels, default all) or on the focus rows of a reduction that are masters of it (data = reduction). Off the diagonal the root-free frame changes nothing; the diagonal is the weight of the full master pref*U. opts \"Weights\" -> <|label -> weight|> (default PFBMasterWeights). Not checked when the data has no derivative in an invariant of non-zero dimension (a unit scale set to 1). Returns MCBEulerCheck's result.";
PFBIntegralDimension::usage = "PFBIntegralDimension[sys, j[...]] is the mass dimension of the integral without the common L*d part: -Sum a_i [D_i].";
PFBFamiliesCode::usage = "PFBFamiliesCode[sys] is the text of a LiteRed/LiteIBP file that defines every family of the system in load order, with symmetries.";
PFBSystemData::usage = "PFBSystemData[sys] is the self-contained data a reduction job needs (masters root-free, prefactors, symmetry rules, invariants).";
PFBImportLiteIBPFamilies::usage = "PFBImportLiteIBPFamilies[file, outDir, opts] reads a LiteRed/LiteIBP families file (Kinematics0 = {mmp[a, b] -> v, ...}; Propagators[fam] = {mp2[...] - m, ...}) and writes one family.wl per family (maximal-cut-basis format) into outDir. opts: Families (default All), MomentumConservation, Invariants (<|X -> dimension|>, default every symbol with dimension 2), UnitScale, D0. Returns the files written.";
PFBFrozenQ::usage = "PFBFrozenQ[sys, fam] is True when the policy forbids changes of the masters of fam.";

Begin["`Private`"];


(* ::Section:: *)
(*Reading*)


resolve[dir_, f_String] := If[StringStartsQ[f, "/"] || StringStartsQ[f, "~"], ExpandFileName[f], FileNameJoin[{dir, f}]];
loadValue[dir_, v_String] := With[{f = resolve[dir, v]}, If[FileExistsQ[f], Get[f], (Print["PFBReadSystem: file not found: ", f]; $Failed)]];
loadValue[_, v_] := v;

(* "MCBRun": the maximal-cut-basis run folder of the family (read only), relative to system.wl *)
mcbRunOf[dir_, e_] := With[{r = Lookup[e, "MCBRun", None]}, If[StringQ[r], resolve[dir, r], r]];

symOf[x_String] := ToExpression[x];
symOf[x_Symbol] := x;

PFBReadSystem[file_String] := Module[{f = ExpandFileName[file], raw, dir, sys, fams = <||>, entries, order, roots, masters, nm, base, img},
  If[! FileExistsQ[f], Print["PFBReadSystem: ", f, " not found."]; Return[$Failed]];
  raw = Get[f]; dir = DirectoryName[f];
  If[! AssociationQ[raw], Print["PFBReadSystem: ", f, " does not evaluate to an Association."]; Return[$Failed]];
  entries = Lookup[raw, "Families", {}];
  sys = <|"Name" -> Lookup[raw, "Name", FileBaseName[f]], "File" -> f, "Dir" -> dir, "Raw" -> raw, "Errors" -> {}, "Warnings" -> {}, "Questions" -> {},
    "NewRoots" -> {}|>;
  (* base families first: their family.wl in maximal-cut-basis format *)
  Do[If[! KeyExistsQ[e, "ImageOf"],
     nm = symOf[e["Name"]];
     Module[{fo = MCBReadFamily[resolve[dir, e["Family"]]]},
       If[fo === $Failed, AppendTo[sys["Errors"], "family " <> ToString[nm] <> ": cannot read " <> e["Family"]]; Continue[]];
       If[fo["Name"] =!= nm, AppendTo[sys["Errors"], "family " <> ToString[nm] <> ": the family file names it " <> ToString[fo["Name"]]]];
       fams[nm] = <|"Name" -> nm, "Base" -> nm, "Object" -> fo, "Entry" -> e, "Image" -> None, "MCBRun" -> mcbRunOf[dir, e]|>]], {e, entries}];
  (* images: propagators from the base with the momentum map *)
  Do[If[KeyExistsQ[e, "ImageOf"],
     nm = symOf[e["Name"]]; base = symOf[e["ImageOf"]];
     If[! KeyExistsQ[fams, base], AppendTo[sys["Errors"], "image " <> ToString[nm] <> ": base family " <> ToString[base] <> " is not defined before it"]; Continue[]];
     img = imageFamily[fams[base]["Object"], nm, Lookup[e, "MomentumMap", {}]];
     fams[nm] = <|"Name" -> nm, "Base" -> base, "Object" -> img, "Entry" -> e, "MCBRun" -> mcbRunOf[dir, e],
       "Image" -> <|"MomentumMap" -> Lookup[e, "MomentumMap", {}],
         "InvariantMap" -> Replace[Lookup[e, "InvariantMap", Automatic], Automatic :> invariantMap[fams[base]["Object"], Lookup[e, "MomentumMap", {}]]],
         "RootSuffix" -> Lookup[e, "RootSuffix", If[StringStartsQ[ToString[nm], ToString[base]], StringDrop[ToString[nm], StringLength[ToString[base]]], "i" <> ToString[nm]]],
         "RootMap" -> Lookup[e, "RootMap", Automatic]|>|>], {e, entries}];
  order = Replace[Lookup[raw, "LoadOrder", Automatic], Automatic :> (symOf[#["Name"]] & /@ entries)];
  order = symOf /@ order;
  sys["Families"] = fams; sys["Order"] = Select[order, KeyExistsQ[fams, #] &];
  (* roots: base roots, then the images' *)
  roots = Replace[loadValue[dir, Lookup[raw, "Roots", {}]], Except[_List] -> {}];
  sys["BaseRoots"] = roots;
  sys["RootDefs"] = roots;
  Do[If[fams[fn]["Image"] =!= None, Module[{im = fams[fn]["Image"], rm},
      rm = Replace[im["RootMap"], Automatic :> Table[r[[1]] -> Symbol[ToString[r[[1]]] <> im["RootSuffix"]], {r, roots}]];
      fams[fn]["Image"]["RootMap"] = rm;
      (* images sharing a suffix share their roots: the first definition of a symbol is kept *)
      sys["RootDefs"] = DeleteDuplicatesBy[Join[sys["RootDefs"], Table[(r[[1]] /. rm) -> (r[[2]] /. im["InvariantMap"]), {r, roots}]], First]]], {fn, sys["Order"]}];
  sys["Families"] = fams;
  sys["Invariants"] = fams[First[sys["Order"]]]["Object"]["InvList"];
  sys["Frozen"] = symOf /@ Lookup[raw, "Frozen", {}];
  sys["Letters"] = Replace[loadValue[dir, Lookup[raw, "Letters", {}]], Except[_List] -> {}];
  sys["SymmetryRules"] = Replace[loadValue[dir, Lookup[raw, "SymmetryRules", {}]], None | Except[_List] -> {}];
  sys["ISPs"] = Association[Table[fn -> Replace[Lookup[fams[fn]["Entry"], "ISPs", Lookup[fams[fams[fn]["Base"]]["Entry"], "ISPs", Automatic]],
       Automatic -> Automatic], {fn, sys["Order"]}]];
  (* masters: per family, then global labels *)
  masters = Association[Table[fn -> readMasters[sys, fn, dir], {fn, sys["Order"]}]];
  sys["FamilyMasters"] = masters;
  sys = labelMasters[sys, Lookup[raw, "MasterOrder", "Join"]];
  sys["ISPs"] = Association[KeyValueMap[#1 -> If[#2 === Automatic, guessISPs[sys, #1], #2] &, sys["ISPs"]]];
  sys["MasterRecords"] = Table[Join[r, <|"Sector" -> masterSector[r["Integrals"], fams[r["Family"]]["Object"]["N"]]|>], {r, sys["MasterRecords"]}];
  sys["MasterRecords"] = Table[Join[r, <|"SectorKey" -> {fams[r["Family"]]["Base"], r["Sector"]}|>], {r, sys["MasterRecords"]}];
  sys];

(* image family object: same propagators with the momentum map applied *)
imageFamily[fo_Association, nm_, map_List] := Module[{raw = fo["Raw"], dep = fo["Dependent"], props},
  props = Table[Module[{p = KeyDrop[pr, {"Expr", "Index", "Label"}]},
      p["Momentum"] = Expand[(pr["Momentum"] /. dep) /. map];
      If[KeyExistsQ[p, "Vector"], p["Vector"] = Expand[(pr["Vector"] /. dep) /. map]];
      p], {pr, fo["Propagators"]}];
  MCBReadFamily[Join[raw, <|"Name" -> nm, "Propagators" -> props, "File" -> fo["File"], "Dir" -> fo["Dir"]|>]]];

(* invariant map induced by a momentum map: X = f(sp)  ->  f(mapped sp) in the invariants *)
invariantMap[fo_Association, {}] := {};
invariantMap[fo_Association, map_List] := Module[{asSP = MCBInvariantsAsSP[fo], mapSP},
  mapSP[a_, b_] := MCBToSP[fo, Expand[((a /. fo["Dependent"]) /. map) ((b /. fo["Dependent"]) /. map)]];
  DeleteCases[Table[r[[1]] -> Together[r[[2]] /. MCBsp[a_, b_] :> mapSP[a, b]], {r, asSP}], (x_ -> x_)]];

(* one family's master list: Get, user rules, prefactor list, flatten, roots as symbols *)
readMasters[sys_, fn_, dir_] := Module[{fe = sys["Families"][fn], e, base, list, pre},
  e = fe["Entry"];
  If[fe["Image"] =!= None && ! KeyExistsQ[e, "Masters"],
    base = fe["Base"];
    Return[PFBImageExpr[sys, #, fn] & /@ readMasters[sys, base, dir]]];
  If[! KeyExistsQ[e, "Masters"], Return[{}]];
  list = loadValue[dir, e["Masters"]];
  If[list === $Failed, Return[{}]];
  (* the rules are applied one after the other, as a chain of /. *)
  list = Flatten[{Fold[ReplaceAll, list, Flatten[{Lookup[e, "Rules", {}]}]]}];
  If[KeyExistsQ[e, "Prefactors"],
    pre = Flatten[{loadValue[dir, e["Prefactors"]]}];
    If[Length[pre] =!= Length[list], Print["PFBReadSystem: family ", fn, ": ", Length[pre], " prefactors for ", Length[list], " masters."]; Return[{}]];
    list = pre list];
  list];

PFBRawMasters[sys_Association, fn_] := Module[{e = sys["Families"][symOf[fn]]["Entry"]},
  If[! KeyExistsQ[e, "Masters"], Return[Missing["NoFile"]]];
  <|"File" -> resolve[sys["Dir"], e["Masters"]], "Raw" -> Flatten[{loadValue[sys["Dir"], e["Masters"]]}],
    "Prefactors" -> If[KeyExistsQ[e, "Prefactors"], Flatten[{loadValue[sys["Dir"], e["Prefactors"]]}], None]|>];

(* explicit Sqrt[...] -> root symbols, the first matching definition wins; unknown radicands become new symbols rPFB1, ... *)
$newRoots = {};

PFBRootify[sys_Association, expr_] := Module[{defs = PFBRootDefs[sys], rad},
  rad = Association[Table[Expand[d[[2, 1]]] -> d[[1]], {d, Reverse[defs]}]];
  expr /. Sqrt[a_] :> Module[{sq = sqFree[a]},
     If[KeyExistsQ[rad, Expand[sq[[2]]]], sq[[1]] rad[Expand[sq[[2]]]],
       If[KeyExistsQ[rad, Expand[-sq[[2]]]], I sq[[1]] rad[Expand[-sq[[2]]]], newRoot[sq[[2]]] sq[[1]]]]]];

sqFree[a_] := Module[{fl = FactorList[Factor[a]], out = 1, in = 1},
  Do[out *= f[[1]]^Quotient[f[[2]], 2]; in *= f[[1]]^Mod[f[[2]], 2], {f, fl}];
  {out, Expand[in]}];

newRoot[r2_] := Module[{hit = SelectFirst[$newRoots, Expand[#[[2, 1]] - r2] === 0 &, None], sym},
  If[hit =!= None, Return[hit[[1]]]];
  sym = Symbol["rPFB" <> ToString[Length[$newRoots] + 1]];
  AppendTo[$newRoots, sym -> Sqrt[r2]];
  sym];

PFBRootDefs[sys_Association] := Join[sys["RootDefs"], Lookup[sys, "NewRoots", {}]];

rootSyms[sys_] := Keys[PFBRootDefs[sys]];

PFBRootMonomial[sys_Association, expr_] := Module[{rs = Select[rootSyms[sys], ! FreeQ[expr, #] &]},
  {Times @@ rs, expr /. Thread[rs -> 1]}];

(* global labels: concatenation in load order ("Join"), its reverse ("ReverseJoin"), or an explicit list {fam, pos} *)
labelMasters[sys0_, how_] := Module[{sys = sys0, pairs, recs, k = 0},
  Block[{$newRoots = {}},
    sys["FamilyMasters"] = Association[KeyValueMap[#1 -> (PFBRootify[sys, #] & /@ #2) &, sys["FamilyMasters"]]];
    sys["NewRoots"] = $newRoots];
  If[sys["NewRoots"] =!= {}, AppendTo[sys["Warnings"], "square roots without a symbol in \"Roots\" were named " <> ToString[Keys[sys["NewRoots"]]] <> ": " <> ToString[sys["NewRoots"], InputForm]]];
  pairs = Flatten[Table[{fn, p}, {fn, sys["Order"]}, {p, Length[sys["FamilyMasters"][fn]]}], 1];
  pairs = Switch[how, "Join", pairs, "ReverseJoin", Reverse[pairs], _List, {symOf[#[[1]]], #[[2]]} & /@ how, _, pairs];
  recs = Table[k++; Module[{fn = pr[[1]], def = sys["FamilyMasters"][pr[[1]]][[pr[[2]]]], mono, rf},
      {mono, rf} = PFBRootMonomial[sys, def];
      <|"Label" -> k, "Family" -> fn, "Base" -> sys["Families"][fn]["Base"], "Pos" -> pr[[2]], "Def" -> def, "Mono" -> mono,
        "Pref" -> (mono /. PFBRootDefs[sys]), "RootFree" -> rf, "Integrals" -> integralsIn[def]|>], {pr, pairs}];
  sys["MasterRecords"] = recs;
  sys["LabelOf"] = Association[Table[{r["Family"], r["Pos"]} -> r["Label"], {r, recs}]];
  sys];

integralsIn[expr_] := Union[Cases[{expr /. Dinv[a_, _] :> a}, _j, Infinity]];

masterSector[ints_List, n_] := Module[{secs = Union[(Boole[Positive[#]] & /@ Take[List @@ Rest[#], n]) & /@ ints], mx},
  If[secs === {}, Return[ConstantArray[0, n]]];
  mx = Max[Total /@ secs];
  (* the largest sector; when several sectors tie, their union (reported by the validation) *)
  Boole[Positive[#]] & /@ Total[Select[secs, Total[#] == mx &]]];

guessISPs[sys_, fn_] := Module[{n = sys["Families"][fn]["Object"]["N"], ints},
  ints = Flatten[Select[sys["MasterRecords"], #["Family"] === fn &][[All, "Integrals"]]];
  If[ints === {}, Return[{}]];
  Select[Range[n], Function[i, AllTrue[ints, (List @@ Rest[#])[[i]] <= 0 &]]]];


(* ::Section:: *)
(*Accessors*)


PFBMasters[sys_Association] := sys["MasterRecords"];
PFBMaster[sys_Association, k_Integer] := sys["MasterRecords"][[k]];
PFBMaster[sys_Association, ut[k_Integer]] := sys["MasterRecords"][[k]];
PFBFamily[sys_Association, fn_] := sys["Families"][symOf[fn]]["Object"];
PFBBaseOf[sys_Association, fn_] := sys["Families"][symOf[fn]]["Base"];
PFBImagesOf[sys_Association, fn_] := Select[sys["Order"], sys["Families"][#]["Base"] === symOf[fn] && # =!= symOf[fn] &];
PFBFrozenQ[sys_Association, fn_] := MemberQ[sys["Frozen"], PFBBaseOf[sys, fn]] || MemberQ[sys["Frozen"], symOf[fn]];

PFBImageExpr[sys_Association, expr_, image_] := Module[{fe = sys["Families"][symOf[image]], im},
  im = fe["Image"];
  If[im === None, Return[expr]];
  expr /. {j[fe["Base"], a___] :> j[fe["Name"], a]} /. im["InvariantMap"] /. im["RootMap"]];

PFBSectorKey[sys_Association, rec_Association] := rec["SectorKey"];
PFBSectorString[{fn_, sec_List}] := ToString[fn] <> "/" <> SectorName[sec];
PFBSectorDir[runDir_String, {fn_, sec_List}] := FileNameJoin[{runDir, ToString[fn], SectorName[sec]}];

PFBSectorKeys[sys_Association] := Module[{keys = Union[#["SectorKey"] & /@ sys["MasterRecords"]], pos},
  pos = AssociationThread[sys["Order"] -> Range[Length[sys["Order"]]]];
  SortBy[Select[keys, Total[#[[2]]] > 0 &], {Total[#[[2]]], pos[#[[1]]], SectorID[#[[2]]]} &]];

PFBSectorMasters[sys_Association, key_List] := Select[sys["MasterRecords"], #["SectorKey"] === key &][[All, "Label"]];


(* ::Section:: *)
(*Rules on master definitions*)


PFBEpsPowers[expr_] := Module[{ints = integralsIn[expr], col},
  col = Collect[expr /. Dinv[a_, x_] :> a, _j];
  Table[{jj, powersIn[Coefficient[col, jj]]}, {jj, ints}]];

powersIn[c_] := Module[{t = Together[c], num, den, dpow, terms},
  num = Numerator[t]; den = Denominator[t];
  If[! FreeQ[den, eps], dpow = Exponent[den, eps, Min];
    If[! FreeQ[Expand[den/eps^dpow], eps], Return[{"eps in denominator"}]], dpow = 0];
  terms = If[Head[Expand[num]] === Plus, List @@ Expand[num], {Expand[num]}];
  Union[(Exponent[#, eps] - dpow) & /@ terms]];

(* the rules and weights are those of MaximalCutBasis`Rules`, shared with the maximal-cut gate; the system's
   invariants are those of its first family *)
utExpand[sys_, d_] := d /. ut[k_Integer] :> PFBMaster[sys, k]["RootFree"];
famObjects[sys_] := Association[Table[fn -> sys["Families"][fn]["Object"], {fn, sys["Order"]}]];

PFBLetters[sys_Association] := Module[{fams = sys["Families"], base},
  base = DeleteDuplicates[Join[Lookup[sys, "Letters", {}],
     Flatten[Table[If[fams[fn]["Image"] === None, Lookup[fams[fn]["Object"], "Letters", {}], {}], {fn, sys["Order"]}]],
     Flatten[Values[Lookup[sys, "SOFIALetters", <||>]]]]];
  If[base === {}, Return[{}]];
  DeleteDuplicates[Join[base, Flatten[Table[With[{im = fams[fn]["Image"]}, If[im === None, {}, base /. im["InvariantMap"]]], {fn, sys["Order"]}]]]]];

PFBRuleViolations[sys_Association, expr_, opts_Association : <||>] := MCBRuleViolations[PFBFamily[sys, First[sys["Order"]]],
   utExpand[sys, expr] /. Dinv[a_, _] :> a, <|"Letters" -> Lookup[opts, "Letters", PFBLetters[sys]]|>];

(* the derivative in X lowers the weight by the dimension of X: Dinv[a, X] weighs as a/X *)
PFBMasterWeight[sys_Association, def_, pref_ : 1] := MCBMasterWeight[PFBFamily[sys, First[sys["Order"]]],
   (pref /. PFBRootDefs[sys]) (utExpand[sys, def] /. Dinv[a_, x_] :> a/x), <|"Families" -> famObjects[sys]|>];

PFBMasterWeights[sys_Association, labs_List : All] := Association[Table[l -> PFBMasterWeight[sys, PFBMaster[sys, l]["RootFree"], PFBMaster[sys, l]["Pref"]],
   {l, If[labs === All, PFBMasters[sys][[All, "Label"]], labs]}]];

PFBEulerCheck[sys_Association, data_Association, opts_Association : <||>] := Module[{rows, cols, diag, As, ders, wl},
  If[KeyExistsQ[data, "Dm"],
    (* a reduction: rows of focus masters that are masters of the reduction, columns its masters *)
    cols = data["Masters"]; ders = data["Invariants"];
    rows = Select[data["Focus"], MemberQ[cols, ut[#]] &];
    diag = First[FirstPosition[cols, ut[#], {0}, {1}]] & /@ rows;
    As = AssociationThread[ders -> Table[data["Dm"][[k, First[FirstPosition[data["Focus"], #, {0}, {1}]] & /@ rows]], {k, Length[ders]}]],
    (* a slice *)
    cols = ut /@ data["Labels"]; ders = data["Derivatives"];
    rows = Intersection[Lookup[opts, "Rows", data["Labels"]], data["Labels"]];
    diag = data["Index"] /@ rows;
    As = AssociationThread[ders -> Table[data["R"][[k, diag]], {k, Length[ders]}]]];
  wl = Replace[Lookup[opts, "Weights", Automatic], Automatic :> PFBMasterWeights[sys, rows]];
  MCBEulerCheck[{As}, {data["Point"]}, PFBFamily[sys, First[sys["Order"]]]["Invariants"], Table[Lookup[wl, r, $Failed], {r, rows}],
    <|"Diagonal" -> diag, "RowNames" -> (ut /@ rows), "ColumnNames" -> cols|>]];

PFBIntegralDimension[sys_Association, jj_j] := Module[{fo = PFBFamily[sys, jj[[1]]]},
  -Total[(List @@ Rest[jj]) fo["PropDims"]]];


(* ::Section:: *)
(*Validation*)


PFBValidateSystem[sys_Association] := Module[{err = sys["Errors"], warn = sys["Warnings"], q = sys["Questions"], fams = sys["Families"], ref, recs = sys["MasterRecords"], dup},
  If[sys["Order"] === {}, AppendTo[err, "no family could be read"]];
  ref = fams[First[sys["Order"]]]["Object"];
  (* one shared kinematics: LiteIBP finds the maps between families only then *)
  Do[With[{fo = fams[fn]["Object"]},
     If[fo["LoopMomenta"] =!= ref["LoopMomenta"] || fo["ExternalMomenta"] =!= ref["ExternalMomenta"], AppendTo[err, ToString[fn] <> ": loop or external momenta differ from " <> ToString[ref["Name"]] <> " (all families must share them)"]];
     If[Sort[fo["ExtSP"]] =!= Sort[ref["ExtSP"]], AppendTo[err, ToString[fn] <> ": external scalar products differ from " <> ToString[ref["Name"]]]];
     If[fo["SPtoD"] === $Failed, AppendTo[err, ToString[fn] <> ": the propagators and ISPs are not a basis of the loop scalar products"]];
     If[fo["Errors"] =!= {}, err = Join[err, (ToString[fn] <> ": " <> #) & /@ fo["Errors"]]]], {fn, sys["Order"]}];
  (* images: the invariant map must be an involution or at least invertible, and keep the propagator set consistent *)
  Do[With[{im = fams[fn]["Image"]}, If[im =!= None,
      If[im["MomentumMap"] === {}, AppendTo[err, ToString[fn] <> ": an image needs a \"MomentumMap\""]];
      If[im["InvariantMap"] === {}, AppendTo[warn, ToString[fn] <> ": the momentum map leaves every invariant unchanged"]];
      If[KeyExistsQ[fams[fn]["Entry"], "InvariantMap"] && fams[fn]["Entry"]["InvariantMap"] =!= Automatic,
        With[{auto = invariantMap[fams[fams[fn]["Base"]]["Object"], im["MomentumMap"]]},
          If[! AllTrue[Keys[auto], Together[(# /. auto) - (# /. im["InvariantMap"])] === 0 &],
            AppendTo[err, ToString[fn] <> ": the given \"InvariantMap\" disagrees with the one implied by the momentum map: " <> ToString[auto, InputForm]]]]]]], {fn, sys["Order"]}];
  If[recs === {}, AppendTo[err, "no masters were read"]];
  Do[Module[{chk = Together[r["Def"] - r["Mono"] r["RootFree"]]},
     If[chk =!= 0, AppendTo[err, "ut[" <> ToString[r["Label"]] <> "] (" <> ToString[r["Family"]] <> " pos " <> ToString[r["Pos"]] <>
        "): the square roots are not an overall factor; split it into masters with one root monomial each"]];
     If[Length[Union[Select[(Boole[Positive[#]] & /@ Take[List @@ Rest[#], fams[r["Family"]]["Object"]["N"]]) & /@ r["Integrals"], Total[#] == Total[r["Sector"]] &]]] > 1,
       AppendTo[q, "ut[" <> ToString[r["Label"]] <> "] has integrals in several sectors with " <> ToString[Total[r["Sector"]]] <>
         " propagators; which sector does it belong to? (assumed: their union " <> SectorName[r["Sector"]] <> ")"]];
     If[! FreeQ[r["RootFree"], Sqrt], AppendTo[err, "ut[" <> ToString[r["Label"]] <> "] keeps an explicit square root after root extraction"]];
     If[r["Integrals"] === {} && r["Def"] =!= 0, AppendTo[warn, "ut[" <> ToString[r["Label"]] <> "] contains no integral"]];
     If[! MemberQ[sys["Order"], r["Family"]] || ! AllTrue[r["Integrals"], #[[1]] === r["Family"] &],
       AppendTo[warn, "ut[" <> ToString[r["Label"]] <> "] (" <> ToString[r["Family"]] <> ") uses integrals of other families"]]], {r, recs}];
  dup = Select[GatherBy[recs, Expand[#["RootFree"]] &], Length[#] > 1 && #[[1]]["RootFree"] =!= 0 &];
  Do[AppendTo[warn, "identical root-free definitions: " <> ToString[("ut[" <> ToString[#] <> "]") & /@ d[[All, "Label"]]]], {d, dup}];
  Do[If[! MemberQ[sys["Order"], f], AppendTo[err, "frozen family " <> ToString[f] <> " is not defined"]], {f, sys["Frozen"]}];
  (* "MCBRun": the maximal-cut-basis run of a base family, read only *)
  Do[With[{r = Lookup[fams[fn], "MCBRun", None]}, If[r =!= None, With[{why = Which[
        fams[fn]["Image"] =!= None, "is given for an image family, which follows its base family's maps: give the run of " <> ToString[fams[fn]["Base"]],
        ! StringQ[r], "must be the path of a maximal-cut-basis run folder, not " <> ToString[r, InputForm],
        True, mcbRunProblem[fams[fn]["Object"], r]]},
      If[StringQ[why], AppendTo[err, ToString[fn] <> ": \"MCBRun\" " <> why]]]]], {fn, sys["Order"]}];
  Do[If[! MatchQ[r, _j -> _], AppendTo[err, "symmetry rule " <> ToString[Short[r], InputForm] <> " is not of the form j[...] -> combination"]], {r, sys["SymmetryRules"]}];
  (* the user's yes to SOFIA's polynomials as letters: True or False, on a base family *)
  Do[With[{e = fams[fn]["Entry"]}, If[KeyExistsQ[e, "LettersFromSOFIA"],
      Which[! BooleanQ[e["LettersFromSOFIA"]], AppendTo[err, ToString[fn] <> ": \"LettersFromSOFIA\" must be True or False"],
        fams[fn]["Image"] =!= None, AppendTo[err, ToString[fn] <> ": \"LettersFromSOFIA\" belongs on the base family " <> ToString[fams[fn]["Base"]] <> "; its images follow by the invariant map"]]]],
    {fn, sys["Order"]}];
  <|"Errors" -> DeleteDuplicates[err], "Warnings" -> DeleteDuplicates[warn], "Questions" -> DeleteDuplicates[q]|>];


(* a maximal-cut-basis run folder of the same family: run_info.m names a family file with the same name, propagators and
   kinematics; None when it is one *)
mcbRunProblem[fo_Association, r_String] := Module[{info, ff, rf},
  If[! DirectoryQ[r], Return["names a folder that does not exist: " <> r]];
  info = Quiet[Get[FileNameJoin[{r, "run_info.m"}]]];
  If[! AssociationQ[info], Return["is not a maximal-cut-basis run folder (no run_info.m in " <> r <> ")"]];
  ff = Lookup[info, "FamilyFile", None];
  If[! StringQ[ff] || ! FileExistsQ[ff], Return["names a run whose run_info.m points to no family file that exists (" <> ToString[ff] <> ")"]];
  rf = Block[{Print}, Quiet[MCBReadFamily[ff]]];
  If[! AssociationQ[rf], Return["names a run whose family file cannot be read: " <> ff]];
  Which[
    rf["Name"] =!= fo["Name"], "is a run of the family " <> ToString[rf["Name"]] <> ", not " <> ToString[fo["Name"]] <> " (" <> ff <> ")",
    Expand[Lookup[rf["Propagators"], "Expr"]] =!= Expand[Lookup[fo["Propagators"], "Expr"]], "is a run of a family " <> ToString[fo["Name"]] <> " with other propagators (" <> ff <> ")",
    Sort[rf["ExtSP"]] =!= Sort[fo["ExtSP"]], "is a run of a family " <> ToString[fo["Name"]] <> " with other kinematics (" <> ff <> ")",
    True, None]];


(* ::Section:: *)
(*Importer of LiteIBP family files*)


PFBImportLiteIBPFamilies[file_String, outDir_String, opts_Association : <||>] := Module[{ctx = "PFBImportSandbox`", sb, back, kin, pairs, fams, files = {}, sps, invs, ext},
  (* evaluate the file in a sandbox context, match there, and rename the symbols back to the current context at the end *)
  Block[{$Context = ctx, $ContextPath = {"System`"}}, Quiet[Get[file]]];
  sb[name_] := Symbol[ctx <> name];
  back[e_] := e /. s_Symbol /; Context[s] === ctx :> RuleCondition[Symbol[SymbolName[s]]];
  kin = sb["Kinematics0"];
  If[! ListQ[kin], Print["PFBImportLiteIBPFamilies: no Kinematics0 list in ", file]; Return[$Failed]];
  pairs = Cases[kin, (sb["mmp"][a_, b_] -> v_) :> {a, b, v}];
  ext = back[Union[Flatten[pairs[[All, 1 ;; 2]]]]];
  sps = back[Table[If[pr[[1]] === pr[[2]], pr[[1]]^2, pr[[1]] pr[[2]]] -> pr[[3]], {pr, pairs}]];
  fams = Cases[DownValues[Evaluate[sb["Propagators"]]], (Verbatim[HoldPattern][_[f_Symbol]] :> _) :> f];
  If[ListQ[Lookup[opts, "Families", All]], fams = Select[fams, MemberQ[opts["Families"], SymbolName[#]] &]];
  invs = Lookup[opts, "Invariants", Automatic];
  If[! DirectoryQ[outDir], CreateDirectory[outDir, CreateIntermediateDirectories -> True]];
  Do[Module[{props = sb["Propagators"][f], out, loop, allInv, fl, unmm},
     unmm[q_] := q /. sb["mm"][x_] :> x;
     out = Table[Module[{q2 = Cases[{pr}, sb["mp2"][x_] :> x, Infinity], q1 = Cases[{pr}, sb["mp"][x_, y_] :> {x, y}, Infinity]},
         Which[
           Length[q2] == 1, <|"Type" -> "Quadratic", "Momentum" -> unmm[q2[[1]]], "Mass2" -> Expand[-(pr - sb["mp2"][q2[[1]]])]|>,
           Length[q1] == 1, <|"Type" -> "Linear", "Momentum" -> unmm[q1[[1, 1]]], "Vector" -> unmm[q1[[1, 2]]], "Constant" -> Expand[-(pr - sb["mp"] @@ q1[[1]])]|>,
           True, $Failed]], {pr, props}];
     If[MemberQ[out, $Failed], Print["PFBImportLiteIBPFamilies: ", SymbolName[f], ": a propagator is neither mp2[q] - m nor mp[q, v] - c"]; Continue[]];
     out = Association /@ back[Normal /@ out];
     loop = Complement[Union[Cases[out[[All, "Momentum"]], _Symbol, Infinity]], ext, Keys[Association[Lookup[opts, "MomentumConservation", {}]]]];
     allInv = Union[Cases[{sps[[All, 2]], Lookup[#, "Mass2", Lookup[#, "Constant", 0]] & /@ out}, _Symbol, Infinity]];
     fl = FileNameJoin[{outDir, "family_" <> SymbolName[f] <> ".wl"}];
     Export[fl, "(* family " <> SymbolName[f] <> ", imported from " <> file <> " by the pole-free-basis skill; check the mass dimensions of the invariants. *)\n" <>
        ToString[<|"Name" -> SymbolName[f], "LoopMomenta" -> loop, "ExternalMomenta" -> ext, "MomentumConservation" -> Lookup[opts, "MomentumConservation", {}],
          "ScalarProducts" -> sps, "Propagators" -> out,
          "Invariants" -> If[AssociationQ[invs], invs, Association[Thread[allInv -> 2]]],
          "UnitScale" -> Lookup[opts, "UnitScale", First[allInv]], "D0" -> Lookup[opts, "D0", 4]|>, InputForm], "Text"];
     AppendTo[files, fl]], {f, fams}];
  files];


(* ::Section:: *)
(*LiteIBP code and job data*)


PFBFamiliesCode[sys_Association] := Module[{order = sys["Order"], first, slots, isp, pat, propsCode},
  first = PFBFamily[sys, First[order]];
  slots = MCBToLiteIBP[first, ConstantArray[1, first["N"]]];
  propsCode = StringJoin[Table[Module[{fo = PFBFamily[sys, fn], s},
      s = MCBToLiteIBP[fo, ConstantArray[1, fo["N"]]];
      "Propagators[" <> ToString[fn] <> "] = {\n" <> s["PROPAGATORS"] <> "\n};\n"], {fn, order}]];
  pat[fn_] := Module[{n = PFBFamily[sys, fn]["N"], is = Lookup[sys["ISPs"], fn, {}]},
    "{" <> StringRiffle[Table[If[MemberQ[is, i], "0", "_"], {i, n}], ", "] <> "}"];
  StringJoin[
    "(* ::Package:: *)\n(* written by PoleFreeBasis from ", sys["File"], " *)\n\n",
    "Kinematics0 = {\n", slots["KINEMATICS"], "\n};\n\n", propsCode, "\n",
    "PFBFamilyOrder = {", StringRiffle[ToString /@ order, ", "], "};\n",
    "PFBSectorPattern = <|", StringRiffle[(ToString[#] <> " -> " <> pat[#]) & /@ order, ", "], "|>;\n",
    "PFBLoop = ", slots["LOOP"], ";\nPFBExternal = ", slots["EXTERNAL"], ";\nPFBMomCons = ", slots["MOMCONS"], ";\n",
    "PFBInvariantsSP = ", slots["INVARIANTS"], ";\n",
    "PFBAllInvariants = ", ToString[sys["Invariants"], InputForm], ";\n",
    "SetDim[", slots["D0"], " - 2 eps];\n",
    "PFBLoaded = {};\n",
    "Block[{Print},\n Do[With[{f = PFBFamilyOrder[[ii]]},\n",
    "   LIBPFamilyLite[f, Propagators[f] /. PFBMomCons /. Kinematics0 // Expand, PFBLoop, PFBExternal, PFBMomCons, Kinematics0, PFBInvariantsSP];\n",
    (* every invariant, masses and constants of linear propagators included, is a number for LiteRed: without this a
       constant such as c in k.n - c is an unknown symbol, NewBasis fails silently and FeynParUF breaks. Declare holds
       its arguments, so the list is written out *)
    "   Quiet[Declare[", ToString[sys["Invariants"], InputForm], ", Number]];\n",
    "   AppendTo[PFBLoaded, f];\n",
    "   NewBasis[f, LIBPToLiteRed[Propagators[f]], LIBPLoopMomenta[f], GenerateIBP -> True];\n",
    "   AnalyzeSectors[f, PFBSectorPattern[f]];\n",
    "   FindExtSymmetries[Sequence @@ Reverse[PFBLoaded], EMs -> LIBPEMs[f]];\n",
    "   LIBPFindSymmetries[f, EMs -> LIBPEMs[f]]], {ii, Length[PFBFamilyOrder]}]];\n"]];

PFBSystemData[sys_Association] := <|
  "Name" -> sys["Name"], "Order" -> sys["Order"], "Invariants" -> sys["Invariants"],
  "N" -> Association[Table[fn -> PFBFamily[sys, fn]["N"], {fn, sys["Order"]}]],
  "ISPs" -> sys["ISPs"],
  "Masters" -> Table[<|"Label" -> r["Label"], "Family" -> r["Family"], "Def" -> r["RootFree"], "Pref" -> r["Pref"], "Sector" -> r["Sector"]|>, {r, sys["MasterRecords"]}],
  "SymmetryRules" -> sys["SymmetryRules"],
  "UnitScale" -> PFBFamily[sys, First[sys["Order"]]]["UnitScale"]|>;


End[];
EndPackage[];
