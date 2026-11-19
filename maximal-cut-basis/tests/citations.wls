#!/usr/bin/env wolframscript
(* What maximal-cut-basis credits in the run's ledger of tools and papers (citations.m), and what it shows from it.
   A tool is credited where it produced something, not where it was loaded or failed (planted packages stand for
   DlogBasis and FiniteFlow; BaikovPackage, Kira and LiteIBP are missing on purpose); a basis.m written again keeps
   every tool of its sector (a check_basis.wls rewrite in a fresh kernel); a declared tool is checked against the
   registry; the words of a provenance credit nothing; the FiniteFlow check (the code of templates/ff/InvestigateDEQ.m on
   a planted DE) credits its tools; a basis mapped from a repeated geometry brings the credits of its sector, for that
   basis only (MCBAutoPass with planted reductions, as in mapped_basis.wls), and a replay of the mapped step imports
   nothing; a paper's basis key makes it consulted once a later basis replaces the basis; the pages and CITATIONS.md
   read the ledger.
   Planted run folders in a temporary folder (the family of examples/sunrise-equal-mass); no third-party tool.
   usage: bin/ws tests/citations.wls        exit code 0 when every test passes *)
Get[FileNameJoin[{ParentDirectory[DirectoryName[$InputFileName]], "lib", "MaximalCutBasis.wl"}]];
$MCBVerbose = False;
root = ParentDirectory[DirectoryName[$InputFileName]];
famFile = FileNameJoin[{root, "examples", "sunrise-equal-mass", "family.wl"}];
sun = MCBReadFamily[famFile];
tmp = CreateDirectory[];

tests = {};
SetAttributes[add, HoldAll];
add[args__] := AppendTo[tests, VerificationTest[args]];
sS = {1, 1, 1, 0, 0}; nS = SectorName[sS];
j111 = j[sunrise, 1, 1, 1, 0, 0]; j211 = j[sunrise, 2, 1, 1, 0, 0]; j121 = j[sunrise, 1, 2, 1, 0, 0];
(* a run folder of maximal-cut-basis (run_info.m) and its sector folders *)
mkRun[name_, sectors_List] := Module[{run = FileNameJoin[{tmp, name}]},
  CreateDirectory[run, CreateIntermediateDirectories -> True];
  Put[<|"FamilyFile" -> famFile|>, FileNameJoin[{run, "run_info.m"}]];
  Scan[CreateDirectory[FileNameJoin[{run, #}]] &, sectors];
  run];
plant[name_, text_] := With[{f = FileNameJoin[{tmp, "planted", name}]},
  Quiet@CreateDirectory[DirectoryName[f], CreateIntermediateDirectories -> True]; Export[f, text, "Text"]; f];
rows[run_] := Sort[Lookup[#, {"tool", "sector", "step"}] & /@ Select[CoreReadCitations[run], #["kind"] === "tool" &]];
viaRows[run_, sec_] := Sort[Lookup[#, {"tool", "via"}] & /@ Select[CoreReadCitations[run], #["kind"] === "tool" && #["sector"] === sec && KeyExistsQ[#, "via"] &]];
viaParts[run_, sec_] := Sort[Lookup[#, {"tool", "part", "outcome"}, None] & /@ Select[CoreReadCitations[run], #["kind"] === "tool" && #["sector"] === sec && KeyExistsQ[#, "via"] &]];
paperOf[run_, id_] := Select[CoreReadCitations[run], #["kind"] === "paper" && #["id"] === id &];
cand[K_, opts___] := Join[<|"r2" -> 1, "K" -> K, "label" -> "planted", "provenance" -> "planted", "strict" -> False, "priority" -> 5, "weight" -> {1, 0, 0}|>,
  Association[opts]];
check[st_] := <|"status" -> st, "range" -> {0, 1}, "checks" -> {<|"Name" -> "euler", "Pass" -> True, "Detail" -> "planted"|>}, "points" -> {}|>;
record[cs_List, opts___] := MCBBasisRecord[sun, sS, Join[<|"check" -> check["eps-polynomial"], "cands" -> cs, "status" -> "eps-polynomial",
   "geometry" -> <|"class" -> "planted", "text" -> "planted"|>|>, Association[opts]]];
ref[n_String] := "A. Author, B. Author, Title " <> n <> ", JHEP 01 (2021) 001, arXiv:" <> n;
(* the key bin/check_basis.wls gives a basis that is not the sector's: that of the record it would have written *)
keyOf[b_List] := Last[MCBCheckedBasisKey[b, <||>]];


(* ::Section:: *)
(*The run's context, the generated script's*)


(* every tool is named in paths.wl, at a path that does not exist: nothing is detected, nothing is available *)
pathsFile = plant["paths.wl", ToString[Association[(# -> "/nonexistent/" <> #) & /@ Keys[$MCBTools]], InputForm]];
runW = FileNameJoin[{tmp, "runW"}];
runWl = plant["run.wl", ToString[<|"Family" -> famFile, "OutputDir" -> runW, "Paths" -> pathsFile|>, InputForm]];
setupW = MCBRunSetup[runWl];
add[{Lookup[$CoreCitationContext, {"Dir", "Sector"}], MCBAvailableQ["kira"]}, {{runW, "whole run"}, False}, TestID -> "MCBRunSetup: the whole run is the citation context"];
CoreCitationContext[None];
scriptDir = FileNameJoin[{runW, nS}];
MCBWriteAnalysisScript[sun, sS, scriptDir, <|"FamilyFile" -> famFile|>];
add[StringContainsQ[Import[FileNameJoin[{scriptDir, "AnalysisMasters.m"}], "Text"],
    "MCBResetToolsUsed[];\nCoreCitationContext[$SectorDir, \"" <> nS <> "\", \"AnalysisMasters.m\"];"], True,
  TestID -> "AnalysisMasters.m drops this kernel's marks, then sets its sector as the citation context"];


(* ::Section:: *)
(*A tool is credited where it produced something*)


runU = mkRun["runU", {nS, "j01110", "j01011"}];
uS = FileNameJoin[{runU, nS}]; u2 = FileNameJoin[{runU, "j01110"}]; u3 = FileNameJoin[{runU, "j01011"}];
MCBSetPath["DlogBasis", plant["DlogBasis.wl", "BeginPackage[\"DlogBasis`\"];\nLeadingSingularities::usage = \"planted\";\nBegin[\"`Private`\"];\n" <>
   "LeadingSingularities[f_, vars_] := If[f === 0, $Failed, {1}];\nEnd[];\nEndPackage[];\n"]];
MCBSetPath["FiniteFlow", plant[FileNameJoin[{"ff", "FiniteFlow.m"}], "BeginPackage[\"FiniteFlow`\"];\nFFDenseSolve::usage = \"planted\";\nFFImpossible::usage = \"planted\";\n" <>
   "Begin[\"`Private`\"];\nFFDenseSolve[eqs_, vars_, ___] := Replace[Solve[eqs, vars], {{} -> FFImpossible, r_ :> First[r]}];\nEnd[];\nEndPackage[];\n"]];
cdZ = <|"vars" -> {zz}|>;
prjSolve = MaximalCutBasis`Candidates`Private`prjSolve;
MCBResetToolsUsed[];
dlog = CoreWithCitationContext[{uS, nS, "first pass"}, {MCBDlogBasisCrossCheck[cdZ, 1/zz], MCBDlogBasisCrossCheck[cdZ, 0]}];
CoreWithCitationContext[{u2, "j01110", "first pass"}, MCBDlogBasisCrossCheck[cdZ, 0]];
(* the projected candidates' solver: FiniteFlow at every solve, in every sector, although its loading is remembered; an
   answer FFImpossible is a solve too *)
solved = Append[Table[CoreWithCitationContext[{d, Automatic, "first pass"}, prjSolve[{xx1 + 2 aa1 == 3, aa1 == 0}, {xx1}, {aa1}]], {d, {uS, u2}}],
  CoreWithCitationContext[{u3, Automatic, "first pass"}, prjSolve[{xx1 == 1, xx1 == 2}, {xx1}, {aa1}]]];
add[{dlog, solved, Select[rows[runU], MemberQ[{"DlogBasis", "FiniteFlow"}, #[[1]]] &]},
  {{{1}, $Failed}, {{3}, {3}, $Failed},
   Sort[{{"DlogBasis", nS, "first pass"}, {"FiniteFlow", nS, "first pass"}, {"FiniteFlow", "j01110", "first pass"}, {"FiniteFlow", "j01011", "first pass"}}]},
  TestID -> "DlogBasis is credited when it gave a result; FiniteFlow at every solve of the projected candidates (FFImpossible too), sector by sector"];
MCBResetToolsUsed[];
Block[{Print},
  noUse = {MCBRepresentations[sun, sS], MCBKiraReduce[sun, uS, {s -> 3, m2 -> 1}]["ok"],
    MCBFFLineDE[sun, sS, {j111}, FileNameJoin[{tmp, "line"}], <|"p0" -> {s -> 3, m2 -> 1}, "v" -> {1}|>]["status"]};
  Quiet@MCBWriteFFPipeline[sun, sS, {j111, j211}, FileNameJoin[{tmp, "ffpipeline"}]]];
add[{noUse, MCBToolsUsed[]}, {{{}, False, "not computed"}, {}},
  TestID -> "nothing is credited for a tool that is missing, nor for writing the FiniteFlow scripts"];
add[{MCBTarasovLower[sun, j111, 0], MCBToolsUsed[], MCBTarasovLower[sun, j111] =!= j111, MCBToolsUsed[]}, {j111, {}, True, {"Tarasov"}},
  TestID -> "Tarasov is credited when the dimension shift was applied"];
MCBResetToolsUsed[];
pfOf[res_] := Block[{MaximalCutBasis`PicardFuchs`Private`pfStep}, MaximalCutBasis`PicardFuchs`Private`pfStep[___] := res;
  MCBPicardFuchs[sun, sS, <|"Dir" -> FileNameJoin[{tmp, "pf"}]|>]; MCBToolsUsed[]];
add[{pfOf[<|"label" -> "not computed", "reason" -> "planted", "blocks" -> {<|"size" -> 2|>}|>], pfOf[<|"label" -> "polylog", "reason" -> "planted", "blocks" -> {}|>],
    pfOf[<|"label" -> "elliptic", "reason" -> "planted", "blocks" -> {<|"size" -> 2|>}|>]}, {{}, {}, {"PicardFuchs"}},
  TestID -> "PicardFuchs is credited when its criteria labelled the sector, never for a step that ends not computed"];
MCBResetToolsUsed[];
(* the gate on planted reductions on the cut: a DE was obtained, or the basis was refused before *)
pt = {s -> 3, m2 -> 1}; A0 = {{eps, 1}, {eps, 2 eps}}; rowOf = <|j211 -> {1, 0}, j121 -> {0, 1}, j111 -> {1, 1}|>;
plantedReduce[fam_, sec_, cs_, dir_, pts_] := Module[{T = Lookup[rowOf, #["K"], Missing[]] & /@ cs},
  If[cs === {} || MemberQ[T, _Missing], $Failed,
    {<|"point" -> pt, "masters" -> {mm1, mm2}, "invariants" -> {s, m2}, "T" -> T, "D" -> {T . A0, T . A0}, "g" -> ConstantArray[0, {2, Length[cs]}]|>}]];
gate = Block[{MCBReduceCandidates}, MCBReduceCandidates[a___] := plantedReduce[a];
  {Quiet[MCBCheckBasis[sun, sS, {j211, eps}, uS, <|"Points" -> {pt}|>]]["message"], MCBToolsUsed[],
   Quiet[MCBCheckBasis[sun, sS, {j211, j121}, uS, <|"Points" -> {pt}|>]]; MCBToolsUsed[]}];
add[gate, {"a basis element is not of the form Sqrt[R] (rational combination)", {}, {"CanonicalDE"}},
  TestID -> "CanonicalDE is credited when the gate obtained a DE, not for a basis it refused before"];
MCBResetToolsUsed[];


(* ::Section:: *)
(*basis.m written again keeps every tool of its sector; declared tools; no provenance words*)


runC = mkRun["runC", {nS}]; sC = FileNameJoin[{runC, nS}];
(* the first pass, in one kernel *)
CoreCitationContext[sC, nS, "first pass"]; MCBResetToolsUsed[];
Scan[MCBMarkToolUsed, {"BaikovPackage", "Baikov", "kira", "CanonicalDE", "DlogBasis", "PicardFuchs"}];
rec1 = record[cand /@ {j111, j211}];
MCBWriteBasis[sC, rec1];
key1 = CoreBasisKey[MCBReadBasis[sC]];
CoreRecordPaper[sC, <|"reference" -> ref["2101.00001"], "used" -> "the first basis", "result" -> "adopted", "basisKey" -> key1|>];
CoreRecordPaper[sC, <|"reference" -> ref["2101.00002"], "used" -> "a basis checked and kept out", "result" -> "not adopted", "basisKey" -> keyOf[{j211, j121}]|>];
CoreRecordPaper[sC, <|"reference" -> ref["2101.00004"], "used" -> "another basis kept out", "result" -> "not adopted", "basisKey" -> keyOf[{j111, j121}]|>];
part1 = Lookup[First[paperOf[runC, #]], "part"] & /@ {"2101.00001", "2101.00002", "2101.00004"};
(* bin/check_basis.wls in another kernel: a fresh context and none of the first pass's marks; a tool run by hand *)
MCBResetToolsUsed[]; CoreCitationContext[sC, nS, "check_basis"];
MCBMarkToolUsed["kira"];
rec2 = record[cand /@ {j211, j121}, "tools" -> {"INITIAL"}];
MCBWriteBasis[sC, rec2];
key2 = CoreBasisKey[MCBReadBasis[sC]];
CoreRecordPaper[sC, <|"reference" -> ref["2101.00003"], "used" -> "the second basis", "result" -> "adopted", "basisKey" -> key2|>];
add[{rec1["toolsUsed"], SubsetQ[rec2["toolsUsed"], Join[rec1["toolsUsed"], {"INITIAL"}]], Length[rec2["citations"]] == Length[rec2["toolsUsed"]],
    FreeQ[rec2, $Failed], MemberQ[rows[runC], {"INITIAL", nS, "declared"}]},
  {Sort[{"BaikovPackage", "Baikov", "kira", "CanonicalDE", "DlogBasis", "PicardFuchs"}], True, True, True, True},
  TestID -> "a basis.m written again in a fresh kernel keeps the tools of the first pass, and a declared tool is recorded"];
(* an older run: no ledger, its basis.m lists the tools *)
runO = mkRun["runO", {nS}]; sO = FileNameJoin[{runO, nS}];
Put[<|"sector" -> sS, "name" -> nS, "masters" -> {<|"definition" -> j111|>}, "toolsUsed" -> {"kira", "FiniteFlow"}, "citations" -> {"older"}|>, FileNameJoin[{sO, "basis.m"}]];
CoreCitationContext[sO, nS, "check_basis"]; MCBResetToolsUsed[];
add[SubsetQ[record[cand /@ {j111, j211}]["toolsUsed"], {"kira", "FiniteFlow"}], True, TestID -> "the same for an older run whose basis.m listed its tools"];
add[{MCBKnownTools[{"INITIAL", "ore_algebra", "INITIAL"}], MCBKnownTools[{"Kira", "fermat", "kira", "initial"}], MCBKnownTools[{}], MCBKnownTools[{"kira", "Nope"}],
    MCBKnownTools[{"Method"}]},
  {{"INITIAL", "ore_algebra"}, {"kira", "fer64", "INITIAL"}, {}, $Failed, $Failed}, {MCBKnownTools::unknown, MCBKnownTools::unknown},
  TestID -> "--tool: a registry key or display name in any case (--tool Kira), or a message that lists the known names (\"Method\" is no tool)"];
runP = mkRun["runP", {nS}]; sP = FileNameJoin[{runP, nS}];
CoreCitationContext[sP, nS, "check_basis"]; MCBResetToolsUsed[];
add[recP = record[{cand[j111, "provenance" -> "INITIAL failed here; d0-shift (d0' = 2) not tried"], cand[j211, "provenance" -> "Libra was not run"]},
    "tools" -> {"NotATool", "Fuchsia"}];
  {recP["toolsUsed"], FreeQ[recP["citations"], $Failed], rows[runP]}, {{"Fuchsia"}, True, {{"Fuchsia", nS, "declared"}}},
  {MCBKnownTools::unknown}, TestID -> "the words of a provenance credit nothing; an unknown declared tool is refused, the known one kept"];
CoreCitationContext[None];


(* ::Section:: *)
(*A paper's basis, and a later basis*)


add[{part1, keyOf[{j211, j121}] === key2, key1 === key2,
    Lookup[First[paperOf[runC, "2101.00001"]], {"part", "outcome"}], Lookup[First[paperOf[runC, "2101.00002"]], {"part", "result"}],
    Lookup[First[paperOf[runC, "2101.00003"]], "part"], Lookup[First[paperOf[runC, "2101.00004"]], "part"]},
  {{"cite", "consulted", "consulted"}, True, False, {"consulted", "replaced by a later basis"}, {"cite", "adopted"}, "cite", "consulted"},
  TestID -> "basisKey: the paper of a replaced basis is consulted, that of a basis kept out and later adopted is cited; check_basis's key is the record's"];


(* bin/check_basis.wls re-checks the first pass's eps-form basis from a file: the first pass writes eps^k outside the sum
   of an element eps^k Sqrt[R] (a j1 + b j2), the rebuilt record inside it, so the two keys differ; it is the same basis,
   and its paper is stamped with the key of basis.m *)
runK = mkRun["runK", {nS}]; sK = FileNameJoin[{runK, nS}];
Put[MCBBasisRecord[sun, sS, <|"check" -> check["eps-form"], "cands" -> {cand[j211 + 2 j121, "r2" -> s (s - 4 m2)], cand[j111]}, "k" -> {1, 0},
   "status" -> "eps-form", "dir" -> None|>], FileNameJoin[{sK, "basis.m"}]];
oldK = MCBReadBasis[sK];
fileBasis = Lookup[#, "definition"] & /@ oldK["masters"];   (* masters.m as the first pass wrote it *)
skK = MCBCheckedBasisKey[fileBasis, oldK];
CoreRecordPaper[sK, <|"reference" -> ref["2103.00001"], "used" -> "the same basis, from a file", "result" -> "adopted", "basisKey" -> Last[skK]|>];
add[{MatchQ[First[fileBasis], eps _Plus | eps _ _Plus], keyOf[fileBasis] === CoreBasisKey[oldK], skK === {True, CoreBasisKey[oldK]},
    First[MCBCheckedBasisKey[{j121, j111}, oldK]], Lookup[First[paperOf[runK, "2103.00001"]], "part"]},
  {True, False, True, False, "cite"},
  TestID -> "check_basis: the first pass's eps-form basis re-checked from a file is the same basis, stamped with the key of basis.m"];
(* bin/check_basis.wls re-checks masters.m (no file) and writes its record again: the unchanged basis keeps the first
   pass's definitions, so its key, and the paper stamped with it, stay; rebuilt, the definitions would have another key *)
reCands = Join[MCBSplitMaster[#], <|"label" -> "", "provenance" -> "agent"|>] & /@ fileBasis;
reRecord[defs_] := MCBBasisRecord[sun, sS, <|"check" -> check["eps-form"], "cands" -> reCands, "status" -> "eps-form", "dir" -> sK, "definitions" -> defs|>];
MCBWriteBasis[sK, reRecord[If[MCBSameBasisQ[fileBasis, fileBasis], fileBasis, None]]];
add[{CoreBasisKey[MCBReadBasis[sK]] === CoreBasisKey[oldK], Lookup[First[paperOf[runK, "2103.00001"]], "part"], CoreBasisKey[reRecord[None]] === CoreBasisKey[oldK]},
  {True, "cite", False}, TestID -> "a record written again for an unchanged basis keeps its definitions verbatim: its key and its paper stay"];
(* a chain of repeated geometries jW -> jX -> jY: jX's mapped basis was replaced later, so jW's credit came to jX for a
   basis jX no longer has; jY's record, mapped from jX, lists jX's own tools and not jW's *)
CoreCitationContext[None]; MCBResetToolsUsed[];
runCh = mkRun["runCh", {"j11110", "j11101", nS}];
{chW, chX, chY} = FileNameJoin[{runCh, #}] & /@ {"j11110", "j11101", nS};
CoreRecordTool[chW, "Libra", "first pass"]; CoreRecordTool[chX, "kira", "first pass"];
mappedFrom[from_] := cand[#, "provenance" -> "mapped from " <> from <> " (repeated geometry)"] & /@ {j111, j211};
MCBWriteBasis[chX, MCBBasisRecord[sun, SectorFromName["j11101"], <|"check" -> check["eps-polynomial"], "cands" -> mappedFrom["j11110"], "status" -> "eps-polynomial",
   "geometry" -> <|"class" -> "planted", "text" -> "planted"|>, "dir" -> chX|>]];
Put[<|"sector" -> SectorFromName["j11101"], "name" -> "j11101", "status" -> "eps-polynomial", "masters" -> {<|"definition" -> j121, "label" -> "a later basis"|>}|>,
  FileNameJoin[{chX, "basis.m"}]];
Put[<|"sector" -> sS, "name" -> nS, "status" -> "failed", "masters" -> {<|"definition" -> j121|>, <|"definition" -> j111|>}|>, FileNameJoin[{chY, "basis.m"}]];
recY = MCBBasisRecord[sun, sS, <|"check" -> check["eps-polynomial"], "cands" -> mappedFrom["j11101"], "status" -> "eps-polynomial",
   "geometry" -> <|"class" -> "planted", "text" -> "planted"|>, "dir" -> chY|>];
add[{Lookup[First[Select[CoreReadCitations[runCh], #["kind"] === "tool" && #["tool"] === "Libra" && #["sector"] === "j11101" &]], "part"],
    Lookup[First[Select[CoreReadCitations[runCh], #["kind"] === "tool" && #["tool"] === "Libra" && #["sector"] === nS &]], {"result", "outcome", "basisKey"}] ===
      {"not adopted", "replaced by a later basis", CoreBasisKey[recY]},
    MemberQ[recY["toolsUsed"], "kira"], MemberQ[recY["toolsUsed"], "Libra"]},
  {"consulted", True, True, False},
  TestID -> "a chain of repeated geometries: a credit the middle sector no longer uses is not in the record of the last one"];


(* ::Section:: *)
(*The FiniteFlow check, through the code of InvestigateDEQ.m*)


runF = mkRun["runF", {nS, "j01110"}];
(* a planted pipeline that reconstructed a DE (eps-form) in one sector, and one whose SetSDE.m failed in the other *)
investigate[sdir_, sysinfo0_] := Module[{ff = FileNameJoin[{sdir, "finiteflow"}]},
  CreateDirectory[ff];
  Put[<|"unitScale" -> None, "masters" -> {j111}, "alpha" -> {0}, "beta" -> <||>, "phases" -> {1}, "sliceFromKiraPoint" -> False|>, FileNameJoin[{ff, "ffinfo.m"}]];
  Put[sysinfo0, FileNameJoin[{ff, "sysinfo.m"}]];
  Export[FileNameJoin[{ff, "sys.m"}], "{{{eps/xx}}}\n", "Text"];
  Put[{1}, FileNameJoin[{ff, "prefacts.m"}]];
  Export[FileNameJoin[{ff, "InvestigateDEQ.m"}], StringReplace[Import[FileNameJoin[{root, "templates", "ff", "InvestigateDEQ.m"}], "Text"],
     {"{{LIBFILE}}" -> plant["nothing.wl", ""], "{{FAMILY}}" -> "sunrise", "{{SECTORNAME}}" -> FileNameTake[sdir]}], "Text"];
  Put[MCBBasisRecord[sun, sS, <|"check" -> check["eps-form"], "cands" -> {cand[j111]}, "status" -> "eps-form", "dir" -> None|>], FileNameJoin[{sdir, "basis.m"}]];
  SetDirectory[ff];
  Block[{Quit = Throw[Null, "quit"] &, Print, $Context = "MCBTestInvestigate`", $ContextPath = DeleteCases[$ContextPath, "Global`"]},
    Catch[Get["InvestigateDEQ.m"], "quit"]];
  ResetDirectory[];
  Lookup[Get[FileNameJoin[{ff, "verdict.m"}]], "status"]];
ffv = {investigate[FileNameJoin[{runF, nS}], <|"status" -> "ok", "invariants" -> {xx}, "mode" -> "full", "slicePoint" -> None|>],
  investigate[FileNameJoin[{runF, "j01110"}], <|"status" -> "failed", "message" -> "planted", "mode" -> "full"|>]};
add[{ffv, Select[rows[runF], MemberQ[{"FiniteFlow", "LiteRed", "LiteIBP"}, First[#]] &], Lookup[MCBReadBasis[FileNameJoin[{runF, nS}]]["finiteflowVerdict"], "status"]},
  {{"eps-form", "failed"}, Sort[{{"FiniteFlow", nS, "FiniteFlow check"}, {"LiteIBP", nS, "FiniteFlow check"}, {"LiteRed", nS, "FiniteFlow check"}}], "eps-form"},
  TestID -> "the FiniteFlow check credits FiniteFlow, LiteRed and LiteIBP when it reconstructed a DE, nothing when it failed"];
add[{MCBRecordFFCheck[FileNameJoin[{runF, nS}], <|"status" -> "not applicable"|>], MCBRecordFFCheck[FileNameJoin[{runF, nS}], Missing["NotRun"]]}, {{}, {}},
  TestID -> "MCBRecordFFCheck: a not applicable or missing verdict credits nothing"];


(* ::Section:: *)
(*A repeated geometry*)


rep = <|"kind" -> "planted", "order" -> {1}, "isp" -> {}, "id" -> 1, "vars" -> {zz}, "geometry" -> <|"class" -> "curve", "nvars" -> 1, "text" -> "planted elliptic curve"|>|>;
(* the sector the basis comes from has its tools and a paper; the pass on nS runs to its end on planted data, over a
   basis.m of another basis, and writes its record *)
mappedPass[name_, mapped_] := Module[{run = mkRun[name, {"j11101", nS}], dir, rec},
  dir = FileNameJoin[{run, nS}];
  Put[<|"sector" -> sS, "name" -> nS, "status" -> "failed", "masters" -> {<|"definition" -> j121|>, <|"definition" -> j111|>}|>, FileNameJoin[{dir, "basis.m"}]];
  CoreRecordTool[FileNameJoin[{run, "j11101"}], {"BaikovPackage", "kira"}, "first pass"];
  CoreRecordPaper[FileNameJoin[{run, "j11101"}], <|"reference" -> ref["2102.00001"], "used" -> "the basis of j11101", "result" -> "adopted"|>];
  rec = Block[{MCBRepresentations, MCBPrintCutData, MCBCutMasters, MCBPicardFuchs, MCBRepeatedGeometry, MCBReduceCandidates, MCBCandidatesFor,
       MCBSingleCandidates, MCBStatusFor, MCBCurve, MCBElementPurity, MaximalCutBasis`AutoPass`Private`verdictFromSearch, $MCBSkip = {"reports"}, Print},
      MCBRepresentations[___] := {rep};
      MCBPrintCutData[___] := Null;
      MCBCutMasters[___] := <|"masters" -> {mm1, mm2}, "n" -> 2, "rules" -> None|>;
      MCBPicardFuchs[___] := <|"label" -> "elliptic", "reason" -> "planted", "time" -> 0|>;
      MCBRepeatedGeometry[___] := {<|"from" -> "j11101", "status" -> "eps-polynomial", "map" -> <|"lines" -> {1, 2, 3}, "invariants" -> {}|>, "basis" -> mapped|>};
      MCBReduceCandidates[a___] := plantedReduce[a];
      MCBCandidatesFor[___] := <|"status" -> "ok", "candidates" -> (cand /@ {j111, j211})|>;
      MCBSingleCandidates[___] := <|"status" -> "ok", "candidates" -> {}|>;
      MaximalCutBasis`AutoPass`Private`verdictFromSearch[red_, res_, fam_] := <|"status" -> res["status"], "k" -> ConstantArray[0, Length[res["cands"]]],
        "range" -> res["range"], "points" -> {pt}, "message" -> "planted"|>;
      MCBStatusFor[chk_, ___] := chk["status"];
      MCBCurve[___] := <||>;
      MCBElementPurity[___] := <|"pure" -> Missing["NotChecked"], "detail" -> "planted"|>;
      MCBAutoPass[sun, sS, dir, <|"Points" -> {pt}|>]];
  <|"Run" -> run, "Record" -> rec|>];
pA = mappedPass["runA", {j111, j211}]; runA = pA["Run"];
pB = mappedPass["runB", $Failed["planted: no map"]]; runB = pB["Run"];
partsA = viaParts[runA, nS];
paperA = Lookup[paperOf[runA, "2102.00001"], {"sector", "via", "part"}][[-1]];
(* a later basis of the sector: the credits imported for the mapped one are only consulted now *)
Put[<|"sector" -> sS, "name" -> nS, "status" -> "eps-polynomial", "masters" -> {<|"definition" -> j121, "label" -> "a later basis"|>,
   <|"definition" -> j211, "label" -> "a later basis"|>}|>, FileNameJoin[{runA, nS, "basis.m"}]];
add[{viaRows[runA, nS], partsA, paperA, SubsetQ[pA["Record"]["toolsUsed"], {"BaikovPackage", "kira"}],
    MemberQ[rows[runA], {"CanonicalDE", nS, "first pass"}], viaRows[runB, nS], SubsetQ[pB["Record"]["toolsUsed"], {"BaikovPackage"}], viaParts[runA, nS],
    Lookup[paperOf[runA, "2102.00001"], "part"][[-1]]},
  {{{"BaikovPackage", "mapped from j11101"}, {"kira", "mapped from j11101"}}, {{"BaikovPackage", "cite", None}, {"kira", "cite", None}},
   {nS, "mapped from j11101", "cite"}, True, True, {}, False,
   {{"BaikovPackage", "consulted", "replaced by a later basis"}, {"kira", "consulted", "replaced by a later basis"}}, "consulted"},
  TestID -> "first pass: a basis mapped from a repeated geometry brings the credits of its sector for that basis only; a search's basis brings none"];
(* AnalysisMasters.m replays the mapped step: the candidates are built, nothing is imported (the record does that) *)
runR = mkRun["runR", {"j11101", nS}];
Put[{j111, j211}, FileNameJoin[{runR, "j11101", "masters.m"}]];
CoreRecordTool[FileNameJoin[{runR, "j11101"}], "kira", "first pass"];
mappedStep = {<|"call" -> "mapped", "from" -> "j11101", "map" -> <|"lines" -> <|1 -> 1, 2 -> 2, 3 -> 3|>, "invariants" -> {}|>|>};
CoreCitationContext[FileNameJoin[{runR, nS}], nS, "AnalysisMasters.m"];
replayed = MCBReplayCandidates[sun, sS, {rep}, mappedStep, <|"dir" -> FileNameJoin[{runR, nS}]|>];
CoreCitationContext[None];
add[{Length[replayed], Union[Lookup[replayed, "provenance"]], viaRows[runR, nS]}, {2, {"mapped from j11101 (repeated geometry)"}, {}},
  TestID -> "the replay of a mapped step builds its candidates and imports nothing"];


(* ::Section:: *)
(*The pages and CITATIONS.md read the ledger*)


MCBBasisHTML[sC, sun];
page = Import[FileNameJoin[{sC, "basis.html"}], "Text"];
summaryFile = MCBSummaryHTML[runC, sun];
summary = Import[summaryFile, "Text"];
md = Import[FileNameJoin[{runC, "CITATIONS.md"}], "Text"];
add[{StringContainsQ[page, "Tools and methods used for this sector"], StringContainsQ[page, "<b>INITIAL</b>"], StringContainsQ[page, "replaced by a later basis"],
    StringContainsQ[page, "Tools used &mdash; please cite:"], StringCount[summary, "<b>Kira</b>"], StringContainsQ[summary, "Tools used &mdash; please cite"],
    StringContainsQ[md, "- **Kira**:"], StringContainsQ[md, "## Also consulted"], StringContainsQ[First[StringSplit[md, "## Also consulted"]], "arXiv:2101.00003"]},
  {True, True, True, False, 1, False, True, True, True},
  TestID -> "basis.html and summary.html show the ledger's block once; MCBSummaryHTML writes CITATIONS.md"];


report = TestReport[tests];
Do[With[{r = report["TestResults"][id]},
    Print[If[r["Outcome"] === "Success", "PASS ", "FAIL "], r["TestID"], If[r["Outcome"] === "Success", "",
      "\n     got " <> ToString[Short[r["ActualOutput"], 5], InputForm] <> "\n     expected " <> ToString[Short[r["ExpectedOutput"], 5], InputForm] <>
        If[r["Outcome"] === "MessagesFailure", "\n     messages " <> ToString[r["ActualMessages"], InputForm], ""]]]],
  {id, Keys[report["TestResults"]]}];
Print[report["TestsSucceededCount"], " passed, ", report["TestsFailedCount"], " failed, ", Round[report["TimeElapsed"], 0.1]];
DeleteDirectory[tmp, DeleteContents -> True];
Exit[If[report["AllTestsSucceeded"], 0, 1]];
