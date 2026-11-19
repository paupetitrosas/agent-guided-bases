#!/usr/bin/env wolframscript
(* The run's ledger of tools and papers (lib/Core/Citations.wl): the registry's names, the marks and their context, the
   entries a run appends, the reader (paper ids, dedupe, outcomes, the final-result rule, the records of older runs,
   imports between runs and sectors) and what is written from it (CITATIONS.md, the page blocks).
   Planted run folders in a temporary folder; no third-party tool (a planted package stands for one in the preflight).
   usage: core/bin/ws core/tests/citations.wls        exit code 0 when every test passes *)
Get[FileNameJoin[{ParentDirectory[DirectoryName[$InputFileName]], "lib", "SkillCore.wl"}]];
tmp = CreateDirectory[];
(* the preflight writes per-machine files (the kernel limit, its log): here they go to the temporary folder *)
SetEnvironment["XDG_CACHE_HOME" -> tmp];

tests = {};
SetAttributes[add, HoldAll];
add[args__] := AppendTo[tests, VerificationTest[args]];
mk[path__] := With[{d = FileNameJoin[{tmp, path}]}, If[! DirectoryQ[d], CreateDirectory[d, CreateIntermediateDirectories -> True]]; d];
raw[run_] := With[{f = FileNameJoin[{run, "citations.m"}]}, If[FileExistsQ[f], ReadList[f], {}]];
toolRows[es_] := Sort[Lookup[Select[es, #["kind"] === "tool" &], {"tool", "sector", "step"}]];
papersOf[es_, id_] := Select[es, #["kind"] === "paper" && #["id"] === id &];
md[run_] := Import[FileNameJoin[{run, "CITATIONS.md"}], "Text"];
(* the part of CITATIONS.md before "Also consulted", and the part after it *)
citePart[run_] := First[StringSplit[md[run], "## Also consulted"]];
consultedPart[run_] := With[{p = StringSplit[md[run], "## Also consulted"]}, If[Length[p] > 1, p[[2]], ""]];
ref[n_String] := "A. Author, B. Author, Title " <> n <> ", JHEP 01 (2021) 001, arXiv:" <> n;
paper[dir_, n_String, used_String, opts___Rule] := CoreRecordPaper[dir, Join[<|"reference" -> ref[n], "used" -> used|>, Association[opts]]];


(* ::Section:: *)
(*The registry*)


add[Lookup[$MCBTools, {"SOFIA", "ore_algebra", "Baikov", "CanonicalDE", "Tarasov", "PicardFuchs"}][[All, "Kind"]],
  {"external", "external", "method", "method", "method", "method"}, TestID -> "registry: SOFIA and ore_algebra are external, Baikov and CanonicalDE methods"];
add[With[{c = MCBCitations[{"Method"}]}, {Length[c], StringContainsQ[c[[1]], "hep-ph/9611449"] && StringContainsQ[c[[1]], "1701.07356"], StringContainsQ[c[[2]], "1304.1806"]}],
  {2, True, True}, TestID -> "MCBCitations: \"Method\" of older records is Baikov and CanonicalDE"];
add[MCBCitations[{"kira", "NotATool"}], $Failed, {MCBCitations::unknown}, TestID -> "MCBCitations: an unknown name is an error, not dropped"];
add[{MCBMarkToolUsed["NotATool"], MCBMarkToolUsed["Method"]}, {$Failed, $Failed}, {MCBMarkToolUsed::unknown, MCBMarkToolUsed::unknown},
  TestID -> "MCBMarkToolUsed: an unknown name (\"Method\" too) is refused"];
add[{MCBLoadTool["SOFIA"], MCBLoadTool["Baikov"], MCBDetectTools[{"SOFIA", "ore_algebra"}]},
  {False, False, <|"SOFIA" -> Missing["NotApplicable"], "ore_algebra" -> Missing["NotApplicable"]|>}, TestID -> "external and method entries are never loaded or detected"];


(* ::Section:: *)
(*Loading and the preflight are not uses*)


fakeDir = mk["fake"];
Export[FileNameJoin[{fakeDir, "INITIAL.m"}], "BeginPackage[\"INITIAL`\"];\nEndPackage[];\n", "Text"];
$MCBPaths = Join[Association[(# -> "/nonexistent/" <> #) & /@ Keys[$MCBTools]], <|"INITIAL" -> FileNameJoin[{fakeDir, "INITIAL.m"}]|>];
MCBResetToolsUsed[];
add[CoreWithCitationContext[None, MCBMarkToolUsed["kira"]]; MCBToolsUsed[], {}, TestID -> "a mark made with the context None is dropped"];
pflog = FileNameJoin[{tmp, "preflight.log"}];
pf = Block[{Print = (Null &)}, MCBPreflight[pflog]];
add[{pf["step:algorithms"], MCBLoadTool["INITIAL"], MCBToolsUsed[], StringFreeQ[Import[pflog, "Text"], "SOFIA" | "ore_algebra" | "CanonicalDE"]},
  {True, True, {}, True}, TestID -> "the preflight loads a planted package and marks nothing; credit-only entries have no row"];
add[StringFreeQ[MCBToolsLine[], "SOFIA" | "ore_algebra" | "Baikov," | "CanonicalDE"], True, TestID -> "MCBToolsLine skips methods and external tools"];
runP = mk["runP"]; Put[<||>, FileNameJoin[{runP, "run_info.m"}]];
CoreCitationContext[runP, "whole run", "after the preflight"];
add[raw[runP], {}, TestID -> "nothing is left pending after the preflight: the first context gets no entry"];
CoreCitationContext[None];


(* ::Section:: *)
(*Marks, their context, explicit records*)


runA = mk["runA"]; Put[<||>, FileNameJoin[{runA, "run_info.m"}]];
Scan[mk["runA", #] &, {"j0111", "j1111", "j0110"}];
MCBResetToolsUsed[];
MCBMarkToolUsed["kira"];   (* find_masters before the run folder is known *)
add[FileExistsQ[FileNameJoin[{runA, "citations.m"}]], False, TestID -> "a mark without a context waits"];
CoreCitationContext[runA, "whole run", "find_masters"];
add[toolRows[raw[runA]], {{"kira", "whole run", "find_masters"}}, TestID -> "a pending mark is flushed to the first context"];
CoreCitationContext[runA, Automatic, "later"];
add[Length[raw[runA]], 1, TestID -> "the next context gets nothing more"];
CoreCitationContext[FileNameJoin[{runA, "j0111"}], Automatic, "first pass"];
MCBMarkToolUsed["FiniteFlow"]; MCBMarkToolUsed["FiniteFlow"]; MCBMarkToolUsed["Baikov"];
CoreWithCitationContext[<|"Dir" -> runA, "Sector" -> "j1111", "Step" -> "check_basis"|>, MCBMarkToolUsed["kira"]];
add[{toolRows[raw[runA]], $CoreCitationContext["Sector"], MCBToolsUsed[]},
  {Sort[{{"kira", "whole run", "find_masters"}, {"FiniteFlow", "j0111", "first pass"}, {"Baikov", "j0111", "first pass"}, {"kira", "j1111", "check_basis"}}], "j0111",
    {"Baikov", "FiniteFlow", "kira"}}, TestID -> "with a context each use is appended at once, once per kernel; a scoped context ends with its scope"];
runR = mk["runR"];
CoreWithCitationContext[{runR, "whole run", "a step"}, MCBMarkToolUsed["kira"]; DeleteFile[FileNameJoin[{runR, "citations.m"}]]; MCBMarkToolUsed["kira"]];
add[toolRows[raw[runR]], {{"kira", "whole run", "a step"}}, TestID -> "a ledger deleted since the last mark is appended to again"];
MCBResetToolsUsed[];
n0 = Length[raw[runA]];
add[CoreRecordTool[FileNameJoin[{runA, "j0110"}], {"INITIAL", "NotATool"}, "declared"], $Failed, {CoreRecordTool::unknown},
  TestID -> "CoreRecordTool refuses an unknown name"];
add[{Length[raw[runA]] - n0, Lookup[CoreRecordTool[FileNameJoin[{runA, "j0110"}], {"INITIAL", "ore_algebra"}, "declared"], {"tool", "sector", "step"}],
    Length[raw[runA]] - n0, MCBToolsUsed[]},
  {0, {{"INITIAL", "j0110", "declared"}, {"ore_algebra", "j0110", "declared"}}, 2, {}}, TestID -> "CoreRecordTool appends for the sector of its folder and marks no kernel"];
CoreCitationContext[None];


(* ::Section:: *)
(*Sector names*)


runPF = mk["runPF"];
Put[<|"Accepted" -> {<|"Id" -> 1|>}, "Pending" -> {<|"Id" -> 2|>},
    "Rejected" -> {<|"Id" -> 3|>, <|"Id" -> 4, "Declined" -> "2026-10-19", "DeclineReason" -> "the user keeps the old basis"|>}|>, FileNameJoin[{runPF, "state.m"}]];
pfSector = mk["runPF", "fam", "j0101"];
SetDirectory[FileNameJoin[{runA, "j0111"}]];
dot = {CoreCitationSector["."], CoreRunFolder["."] === runA};
ResetDirectory[];
add[{CoreCitationSector[FileNameJoin[{runA, "j0111"}]], CoreCitationSector[runA], CoreCitationSector[pfSector], dot},
  {"j0111", "whole run", "fam/j0101", {"j0111", True}}, TestID -> "sector names: j0111, fam/j0101 in a pole-free run, \".\" expanded"];


(* ::Section:: *)
(*Paper ids and dedupe*)


add[CorePaperId /@ {"A. Author, Title, arXiv:2001.00001v2", "A. Author, Title, JHEP 01 (2020) 001, 2001.00001",
    "P. A. Baikov, Explicit solutions, Nucl. Instrum. Meth. A 389 (1997) 347, arXiv:hep-ph/9611449.", "X. Author, A title, math.AG/0501234v1",
    "N. M. Katz, Algebraic solutions, Invent. Math. 18 (1972) 1-118, doi:10.1007/BF01389714; N. M. Katz, Nilpotent connections, doi:10.1007/BF02684688.",
    "C. Author, A program, Comput. Phys. Commun. 320 (2026) 109970, doi:10.1016/j.cpc.2025.109970.",
    "R. N. Lee, LiteRed, arXiv:1212.2685; R. N. Lee, LiteRed 1.4, J. Phys. Conf. Ser. 523 (2014) 012059, arXiv:1310.1145.", "A. Nobody, An  Unpublished Note (2020)."},
  {"2001.00001", "2001.00001", "hep-ph/9611449", "math.ag/0501234", "10.1007/bf01389714", "10.1016/j.cpc.2025.109970", "1212.2685", "a nobody an unpublished note 2020"},
  TestID -> "paper ids: two spellings of an arXiv id, old style, DOI (never a piece of it), the first of several, no id"];
CoreRecordPaper[FileNameJoin[{runA, "j0111"}], <|"reference" -> "A. Author, B. Author, A title, JHEP 01 (2020) 001, arXiv:2001.00001", "used" -> "the basis of the sector",
   "rung" -> 2, "result" -> "adopted"|>];
CoreRecordPaper[FileNameJoin[{runA, "j0111"}], <|"reference" -> "A. Author, B. Author, A title, arXiv:2001.00001v3", "used" -> "the basis of the sector.",
   "rung" -> 2, "result" -> "adopted"|>];
add[Lookup[papersOf[CoreReadCitations[runA], "2001.00001"], {"sector", "rung", "result", "part"}], {{"j0111", 2, "adopted", "cite"}},
  TestID -> "the same paper written two ways, used the same way, is one use"];
n0 = Length[raw[runA]];
add[{CoreRecordPaper[runA, <|"reference" -> "A. Author, T, arXiv:2001.00009", "used" -> " "|>], MCBRecordLiterature[runA, <|"used" -> "x"|>],
    CoreRecordPaper[runA, <|"reference" -> "A. Author, T, arXiv:2001.00009", "used" -> "x", "result" -> "great"|>], Length[raw[runA]] - n0},
  {$Failed, $Failed, $Failed, 0}, {CoreRecordPaper::input, MCBRecordLiterature::input, CoreRecordPaper::result}, TestID -> "a paper without reference or use, or with an unknown result, is refused"];
add[Lookup[CoreRecordPaper[FileNameJoin[{runA, "j1111"}], <|"reference" -> "A. Nobody, An unpublished note (2020)", "used" -> "an idea for the numerators"|>], {"id", "sector", "result"}],
  {"a nobody an unpublished note 2020", "j1111", "used"}, {CoreRecordPaper::id}, TestID -> "a reference without an id is recorded with a warning"];
lit = MCBRecordLiterature[FileNameJoin[{runA, "j1111"}], <|"reference" -> "D. Author, Another title, doi:10.1234/abcd.5678.", "used" -> "the map of propagators",
   "outcome" -> "the candidates came from it"|>];
add[{FileNameTake[lit], FileExistsQ[lit], FileExistsQ[FileNameJoin[{runA, "literature.m"}]], Lookup[Last[raw[runA]], {"id", "sector"}]},
  {"CITATIONS.md", True, False, {"10.1234/abcd.5678", "j1111"}}, TestID -> "MCBRecordLiterature: the ledger, then CITATIONS.md"];
add[StringContainsQ[citePart[runA], "- A. Author, B. Author, A title, JHEP 01 (2020) 001, arXiv:2001.00001\n"], True, TestID -> "CITATIONS.md shows the fullest reference"];


(* ::Section:: *)
(*The final-result rule: bases*)


defs = {j[f, 1, 1, 1, 0], eps j[f, 2, 1, 1, 0]};
key = CoreBasisKey[defs]; oldKey = CoreBasisKey[{j[f, 1, 1, 1, 0], j[f, 1, 2, 1, 0]}];
Put[<|"name" -> "j0111", "status" -> "eps-form", "masters" -> (<|"definition" -> #, "label" -> "planted"|> & /@ defs), "toolsUsed" -> {"CanonicalDE", "kira"},
    "citations" -> MCBCitations[{"CanonicalDE", "kira"}]|>, FileNameJoin[{runA, "j0111", "basis.m"}]];
add[{CoreBasisKey[ToExpression["{ctxA`j[1] + ctxA`eps}"]] === CoreBasisKey[ToExpression["{ctxB`j[1] + ctxB`eps}"]],
    CoreBasisKey[Get[FileNameJoin[{runA, "j0111", "basis.m"}]]] === key, key === oldKey, CoreBasisKey[<|"status" -> "not run"|>]},
  {True, True, False, Missing["NoBasis"]}, TestID -> "CoreBasisKey: the masters' definitions without contexts; a basis.m record"];
s0111 = FileNameJoin[{runA, "j0111"}];
paper[s0111, "2003.00003", "the adopted basis", "rung" -> 2, "result" -> "adopted", "basisKey" -> key];
paper[s0111, "2004.00004", "an earlier adopted basis", "rung" -> 2, "result" -> "adopted", "basisKey" -> oldKey];
paper[s0111, "2005.00005", "candidates", "rung" -> 2, "result" -> "not adopted", "basisKey" -> CoreBasisKey[{j[f, 2, 1, 1, 0]}], "outcome" -> "eps-polynomial only"];
paper[s0111, "2006.00006", "the basis", "rung" -> 2, "result" -> "not adopted", "basisKey" -> key];
paper[s0111, "2006.00006", "the basis", "rung" -> 2, "result" -> "adopted", "basisKey" -> key];
esA = CoreReadCitations[runA];
add[{Lookup[papersOf[esA, "2003.00003"], "part"], Lookup[papersOf[esA, "2004.00004"], {"part", "result", "outcome"}], Lookup[papersOf[esA, "2005.00005"], "part"],
    Lookup[papersOf[esA, "2006.00006"], {"result", "part", "outcome"}]},
  {{"cite"}, {{"consulted", "adopted", "replaced by a later basis"}}, {"consulted"},
   {{"adopted", "cite", "its basis is the sector's final basis"}, {"adopted", "cite", Missing["KeyAbsent", "outcome"]}}},
  TestID -> "bases: the current one is cited; a replaced one or one never adopted is consulted; one not adopted then but the sector's basis now is cited"];
CoreWriteCitations[runA];
add[{StringContainsQ[citePart[runA], "arXiv:2003.00003"], StringContainsQ[consultedPart[runA], "arXiv:2004.00004"],
    StringContainsQ[consultedPart[runA], "Outcome: adopted (replaced by a later basis)."], StringContainsQ[consultedPart[runA], "arXiv:2005.00005"],
    StringContainsQ[consultedPart[runA], "Outcome: not adopted (eps-polynomial only)."], StringContainsQ[citePart[runA], "arXiv:2006.00006"], StringContainsQ[consultedPart[runA], "2006.00006"]},
  {True, True, True, True, True, True, False}, TestID -> "CITATIONS.md: Cite and Also consulted; a paper with one cited use is in Cite"];
add[StringContainsQ[citePart[runA], "- **Kira**: F. Lange" ~~ __ ~~ " Sectors: j0111 (earlier run), j1111 (check_basis), whole run (find_masters).\n"], True,
  TestID -> "CITATIONS.md: a tool line with its sectors and steps"];


(* ::Section:: *)
(*The final-result rule: pole-free changes and their outcomes*)


paper[pfSector, "2101.00001", "the new master", "change" -> 1, "result" -> "pending"];
CoreRecordOutcome[runPF, 1, "approved", "approved by the user"];
paper[pfSector, "2101.00002", "a numerator", "change" -> 2, "result" -> "pending"];
paper[pfSector, "2101.00003", "a completion", "change" -> 3, "result" -> "rejected", "outcome" -> "the gate failed"];
paper[pfSector, "2101.00003", "another completion", "change" -> 1, "result" -> "accepted"];
paper[pfSector, "2101.00004", "a derivative master", "change" -> 4, "result" -> "pending"];
CoreRecordOutcome[runPF, 4, "rejected", "first outcome"];
CoreRecordOutcome[runPF, 4, "declined", "the user keeps the old basis"];
paper[pfSector, "2101.00005", "a maximal-cut basis", "result" -> "not tried", "outcome" -> "no candidate from it"];
paper[pfSector, "2101.00006", "an idea"];
paper[pfSector, "2101.00007", "a rescaling", "change" -> 5];
paper[pfSector, "2101.00008", "letters of the family", "sector" -> "whole system"];
esPF = CoreReadCitations[runPF];
add[Table[Lookup[papersOf[esPF, n], {"result", "part"}], {n, {"2101.00001", "2101.00002", "2101.00003", "2101.00004", "2101.00005", "2101.00006", "2101.00007"}}],
  {{{"accepted", "cite"}}, {{"pending", "cite"}}, {{"rejected", "consulted"}, {"accepted", "cite"}}, {{"declined", "consulted"}}, {{"not tried", "consulted"}},
   {{"used", "cite"}}, {{"used", "consulted"}}}, TestID -> "changes: accepted and pending are cited, rejected, declined, not tried and unknown changes consulted"];
add[{Lookup[First[papersOf[esPF, "2101.00004"]], "outcome"], Lookup[First[papersOf[esPF, "2101.00007"]], "outcome"], Lookup[First[papersOf[esPF, "2101.00008"]], "sector"]},
  {"the user keeps the old basis", "change 5 is not in the final basis", "whole run"}, TestID -> "the latest outcome of a change wins; \"whole system\" is \"whole run\""];
CoreWriteCitations[runPF];
add[{StringContainsQ[citePart[runPF], #] & /@ {"2101.00001", "2101.00002", "2101.00003", "2101.00006", "2101.00008", "Outcome: pending."},
    StringContainsQ[consultedPart[runPF], #] & /@ {"2101.00004", "2101.00005", "2101.00007", "2101.00003", "Outcome: declined (the user keeps the old basis)."},
    StringContainsQ[md[runPF], "## Not covered by this file"], StringContainsQ[md[runA], "## Not covered by this file"]},
  {{True, True, True, True, True, True}, {True, True, True, False, True}, True, False}, TestID -> "CITATIONS.md of a pole-free run: the two parts, and the starting DE"];


(* ::Section:: *)
(*Older runs: literature.m and the toolsUsed of basis.m*)


runL = mk["runL"]; Put[<||>, FileNameJoin[{runL, "run_info.m"}]];
Scan[PutAppend[#, FileNameJoin[{runL, "literature.m"}]] &, {
  <|"sector" -> "j0101", "rung" -> 2, "reference" -> "E. Old, Old title, arXiv:1901.00001", "used" -> "the basis", "date" -> "2026-01-01"|>,
  <|"sector" -> "whole system", "reference" -> "F. Old, Other title, arXiv:1902.00002", "used" -> "the letters", "outcome" -> "accepted, change 1", "date" -> "2026-01-02"|>}];
(* an older record: its citations always ended with the method papers *)
Put[<|"name" -> "j0101", "masters" -> {<|"definition" -> j[g, 1, 0, 1]|>}, "toolsUsed" -> {"kira", "FiniteFlow", "SomeOtherProgram"},
    "citations" -> Join[MCBCitations[{"kira", "FiniteFlow"}], MCBCitations[{"Method"}]]|>, FileNameJoin[{mk["runL", "j0101"], "basis.m"}]];
Put[<|"name" -> "j0011", "masters" -> {<|"definition" -> j[g, 0, 0, 1]|>}, "toolsUsed" -> {"CanonicalDE", "kira"}, "citations" -> {"..."}|>, FileNameJoin[{mk["runL", "j0011"], "basis.m"}]];
(* a newer record of a sector where no Baikov representation was built and no DE checked: no method paper *)
Put[<|"name" -> "j0110", "masters" -> {<|"definition" -> j[g, 0, 1, 1]|>}, "toolsUsed" -> {"kira"}, "citations" -> MCBCitations[{"kira"}]|>,
  FileNameJoin[{mk["runL", "j0110"], "basis.m"}]];
Put[<|"status" -> "failed"|>, FileNameJoin[{mk["runL", "j0001"], "basis.m"}]];
CoreRecordTool[FileNameJoin[{runL, "j0101"}], "kira", "first pass"];
Export[FileNameJoin[{runL, "LITERATURE.md"}], "# Literature used in this run\n\nolder file\n", "Text"];
esL = CoreReadCitations[runL];
add[toolRows[esL], Sort[{{"kira", "j0101", "first pass"}, {"FiniteFlow", "j0101", "earlier run"}, {"SomeOtherProgram", "j0101", "earlier run"}, {"Baikov", "j0101", "earlier run"},
    {"CanonicalDE", "j0101", "earlier run"}, {"CanonicalDE", "j0011", "earlier run"}, {"kira", "j0011", "earlier run"}, {"kira", "j0110", "earlier run"}}],
  TestID -> "older basis.m: its toolsUsed, the method papers its citations name, nothing the ledger already credits"];
add[{Lookup[papersOf[esL, "1901.00001"], {"sector", "rung", "result", "part"}], Lookup[papersOf[esL, "1902.00002"], {"sector", "result", "change", "part"}]},
  {{{"j0101", 2, "used", "cite"}}, {{"whole run", "accepted", 1, "cite"}}}, TestID -> "older literature.m: its papers, as used"];
cL = CoreWriteCitations[runL];
add[{FileExistsQ[cL], FileExistsQ[FileNameJoin[{runL, "LITERATURE.md"}]], StringContainsQ[md[runL], "- **SomeOtherProgram**: not in the registry of the skill"],
    StringContainsQ[md[runL], "E. Old, Old title"]},
  {True, False, True, True}, TestID -> "CITATIONS.md replaces the skill's own LITERATURE.md; an unknown older tool is shown, not dropped"];
runU = mk["runU"];
CoreRecordTool[runU, "kira", "a reduction"];
Export[FileNameJoin[{runU, "LITERATURE.md"}], "# My reading list\n\nnot the skill's\n", "Text"];
CoreWriteCitations[runU];
add[{FileExistsQ[FileNameJoin[{runU, "CITATIONS.md"}]], FileExistsQ[FileNameJoin[{runU, "LITERATURE.md"}]]}, {True, True}, TestID -> "a LITERATURE.md that is not the skill's stays"];


(* ::Section:: *)
(*Imports*)


new = CoreImportCitations[runPF, runA, "j0111", "fam/j0111", "maximal-cut-basis run runA"];
esI = Select[CoreReadCitations[runPF], #["sector"] === "fam/j0111" &];
add[{SubsetQ[toolRows[esI], {{"FiniteFlow", "fam/j0111", "first pass"}, {"Baikov", "fam/j0111", "first pass"}, {"kira", "fam/j0111", "earlier run"}}],
    Union[Lookup[esI, "via"]], Lookup[papersOf[esI, "2004.00004"], {"result", "outcome", "part"}], Lookup[papersOf[esI, "2003.00003"], "part"],
    NoneTrue[esI, KeyExistsQ[#, "basisKey"] &], papersOf[esI, "a nobody an unpublished note 2020"]},
  {True, {"maximal-cut-basis run runA"}, {{"not adopted", "replaced by a later basis", "consulted"}}, {"cite"}, True, {}},
  TestID -> "import: the sector's tools and papers, older records included, under the new sector name; no other sector"];
add[{Length[new] > 0, CoreImportCitations[runPF, runA, "j0111", "fam/j0111", "maximal-cut-basis run runA"]}, {True, {}}, TestID -> "import: a second import copies nothing"];
CoreImportCitations[runA, runA, "j0111", "j0110", "mapped from j0111"];
add[Lookup[Select[CoreReadCitations[runA], #["sector"] === "j0110" && #["kind"] === "tool" && #["tool"] === "FiniteFlow" &], {"step", "via"}],
  {{"first pass", "mapped from j0111"}}, TestID -> "import within a run: a repeated geometry"];


(* ::Section:: *)
(*A paper that a tool or method already cites*)


runM = mk["runM"];
CoreRecordTool[FileNameJoin[{mk["runM", "j0111"]}], "CanonicalDE", "check_basis"];
CoreRecordPaper[FileNameJoin[{runM, "j0111"}], <|"reference" -> "J. Henn, Multiloop integrals made simple, PRL 110 (2013) 251601, arXiv:1304.1806v3", "used" -> "the eps-form of the DE"|>];
CoreWriteCitations[runM];
add[{StringCount[md[runM], "1304.1806"], StringContainsQ[md[runM], "### Papers"], StringContainsQ[md[runM], "  - j0111, " ~~ __ ~~ ": the eps-form of the DE."],
    Length[CoreCitationGroups[runM]["methods"][[1]]["papers"]]},
  {1, False, True, 1}, TestID -> "a paper with the id of a cited method is shown once, under the method"];
runN = mk["runN"];
CoreRecordPaper[FileNameJoin[{mk["runN", "j0111"]}], <|"reference" -> "J. Henn, Multiloop integrals made simple, arXiv:1304.1806", "used" -> "the eps-form of the DE"|>];
add[Length[CoreCitationGroups[runN]["papers"]], 1, TestID -> "without the method, the same paper is a paper of its own"];


(* ::Section:: *)
(*One sector, the page blocks, the older names*)


CoreRecordPaper[runA, <|"reference" -> ref["2007.00007"], "used" -> "the map of j0111 onto j1111"|>];
sc = CoreSectorCitations[runA, "j0111"];
add[{MemberQ[Lookup[sc["papers"], "id"], "2007.00007"], MemberQ[Lookup[sc["tools"], "tool"], "FiniteFlow"], MemberQ[Lookup[sc["papers"], "id"], "a nobody an unpublished note 2020"],
    MemberQ[Lookup[CoreSectorCitations[runA, "j1111"]["papers"], "id"], "2007.00007"], MemberQ[Lookup[CoreSectorCitations[runA, "j0110"]["papers"], "id"], "2007.00007"]},
  {True, True, False, True, False}, TestID -> "a sector's entries: its own, and the whole-run ones that name it"];
html = CoreCitationsHTML[runA]; shtml = CoreSectorCitationsHTML[runA, "j0111"];
add[{StringContainsQ[html, "<code>CITATIONS.md</code>"], StringContainsQ[html, "<b>Kira</b>"], StringContainsQ[html, "Also consulted"],
    StringContainsQ[shtml, "arXiv:2003.00003"], StringContainsQ[shtml, "replaced by a later basis"], StringContainsQ[shtml, "<b>FiniteFlow</b>"]},
  {True, True, True, True, True, True}, TestID -> "the page blocks"];
add[{CoreLiteratureSummary[runA] === CoreCitationsHTML[runA], CoreLiteratureList[{}], StringContainsQ[md[runA], CoreCiteMarkdown[runA]],
    Union[Lookup[MCBReadLiterature[runA], "kind"]], StringTrim[MCBWriteLiterature[runA]] === FileNameJoin[{runA, "CITATIONS.md"}]},
  {True, "", True, {"paper"}, True}, TestID -> "the older names: CoreLiteratureSummary, CoreLiteratureList, MCBReadLiterature, MCBWriteLiterature"];


(* ::Section:: *)
(*An empty run, a line cut short*)


runE = mk["runE"];
add[{CoreReadCitations[runE], CoreWriteCitations[runE], FileExistsQ[FileNameJoin[{runE, "CITATIONS.md"}]], CoreCitationsHTML[runE], CoreSectorCitationsHTML[runE, "j0111"], CoreCiteMarkdown[runE]},
  {{}, Missing["NoCitations"], False, "", "", ""}, TestID -> "an empty run writes nothing"];
runT = mk["runT"];
CoreRecordTool[runT, "kira", "one"];
(* the cut line has no newline: the next entry starts on it *)
With[{st = OpenAppend[FileNameJoin[{runT, "citations.m"}]]}, WriteString[st, "<|\"kind\" -> \"tool\", \"to"]; Close[st]];
CoreRecordTool[runT, "FiniteFlow", "two"];
add[toolRows[CoreReadCitations[runT]], {{"FiniteFlow", "whole run", "two"}, {"kira", "whole run", "one"}}, {CoreReadCitations::bad},
  TestID -> "a line cut short costs that entry only"];


(* ::Section:: *)
(*Tool names in another case, or by their display name*)


add[CoreToolKey /@ {"kira", "Kira", "KIRA", "fermat", "Baikov representation", "finiteflow", "nope", 3}, {"kira", "kira", "kira", "fer64", "Baikov", "FiniteFlow", $Failed, $Failed},
  TestID -> "CoreToolKey: the key, or the key or the display name in any case"];
runY = mk["runY"];
add[{CoreWithCitationContext[{runY, "whole run", "a step"}, MCBMarkToolUsed["Kira"]], Lookup[CoreRecordTool[runY, {"KIRA", "Fermat"}, "by hand"], "tool"],
    MCBCitations[{"Kira", "Fermat"}] === MCBCitations[{"kira", "fer64"}], MCBMarkToolUsed["nope"]},
  {"kira", {"kira", "fer64"}, True, $Failed}, {MCBMarkToolUsed::unknown}, TestID -> "marks, records and citations take display names; an unknown name is still refused"];
PutAppend[<|"kind" -> "tool", "tool" -> "Kira", "sector" -> "whole run", "step" -> "a hand-written line", "date" -> "2026-10-19"|>, FileNameJoin[{runY, "citations.m"}]];
add[Union[Lookup[Select[CoreReadCitations[runY], #["kind"] === "tool" &], "tool"]], {"fer64", "kira"}, TestID -> "the reader reads a display name in the ledger as its key"];
MCBResetToolsUsed[];


(* ::Section:: *)
(*Ids: links, and references that share an id*)


add[CorePaperId /@ {"https://arxiv.org/abs/2001.00001v2", "see arxiv.org/pdf/2001.00001v1.pdf", "http://arxiv.org/abs/hep-ph/9611449", "https://doi.org/10.1007/BF01389714"},
  {"2001.00001", "2001.00001", "hep-ph/9611449", "10.1007/bf01389714"}, TestID -> "paper ids: arxiv.org and doi.org links"];
runG = mk["runG"];
CoreRecordPaper[mk["runG", "j0111"], <|"reference" -> "X. Author, A title, JHEP 01 (2022) 001, doi:10.1234/abc.567, arXiv:2201.00001", "used" -> "the basis"|>];
CoreRecordPaper[mk["runG", "j1111"], <|"reference" -> "X. Author, A title, doi:10.1234/abc.567", "used" -> "the map"|>];
CoreRecordPaper[mk["runG", "j0110"], <|"reference" -> "X. Author, https://arxiv.org/abs/2201.00001", "used" -> "an idea"|>];
CoreRecordTool[FileNameJoin[{runG, "j0111"}], "INITIAL", "declared"];
CoreRecordPaper[FileNameJoin[{runG, "j0111"}], <|"reference" -> "C. Dlapa, J. Henn, K. Yan, JHEP 05 (2020) 025, doi:10.1007/JHEP05(2020)025", "used" -> "the seed"|>];
CoreRecordPaper[FileNameJoin[{runG, "j1111"}], <|"reference" -> "C. Dlapa et al., doi:10.1007/JHEP05(2020)025, arXiv:2002.02340", "used" -> "the seed integral"|>];
CoreRecordPaper[FileNameJoin[{runG, "j0111"}], <|"reference" -> "W. Author, Notes on a seed, arXiv:2301.00001; after C. Dlapa, J. Henn, K. Yan, arXiv:2002.02340", "used" -> "the notes"|>];
gG = CoreCitationGroups[runG];
add[{Lookup[gG["papers"], "id"], Length[gG["papers"][[1, "uses"]]], StringContainsQ[gG["papers"][[1, "reference"]], "JHEP"], Lookup[gG["tools"][[1, "papers"]], "used"]},
  {{"2201.00001", "2301.00001"}, 3, True, {"the seed", "the seed integral"}},
  TestID -> "references that share an id are one paper; one that shares any id with a cited tool is shown under it; a reference naming two papers merges nothing"];
(* the review's case: a reference naming two papers does not join them *)
runV = mk["runV"];
Put[<|"Accepted" -> {<|"Id" -> 1|>}, "Pending" -> {}, "Rejected" -> {<|"Id" -> 3|>}|>, FileNameJoin[{runV, "state.m"}]];
CoreRecordPaper[mk["runV", "fam", "j0101"], <|"reference" -> "X. One, A first paper, arXiv:2001.00011", "used" -> "a completion", "change" -> 3, "result" -> "rejected"|>];
CoreRecordPaper[FileNameJoin[{runV, "fam", "j0101"}], <|"reference" -> "Y. Two, A second paper, arXiv:2105.00002", "used" -> "a numerator", "change" -> 1, "result" -> "accepted"|>];
CoreRecordPaper[FileNameJoin[{runV, "fam", "j0101"}], <|"reference" -> "X. One, A first paper, arXiv:2001.00011; see Y. Two, arXiv:2105.00002", "used" -> "another completion",
   "change" -> 3, "result" -> "rejected"|>];
gV = CoreCitationGroups[runV];
add[{Lookup[gV["papers"], "id"], Lookup[gV["consulted"], "id"], Lookup[gV["consulted"][[1, "uses"]], "used"]},
  {{"2105.00002"}, {"2001.00011"}, {"a completion", "another completion"}}, TestID -> "two papers named in one reference stay two papers, each with its own part"];


(* ::Section:: *)
(*Imports follow what they went into*)


runS = mk["runS"]; Put[<||>, FileNameJoin[{runS, "run_info.m"}]];
CoreRecordTool[mk["runS", "j0011"], "kira", "first pass"];
CoreRecordPaper[FileNameJoin[{runS, "j0011"}], <|"reference" -> ref["2401.00001"], "used" -> "the basis", "result" -> "adopted"|>];
runX = mk["runX"]; Put[<||>, FileNameJoin[{runX, "run_info.m"}]];
$ahead = DatePlus[Now, {1, "Hour"}];
basisX[d_] := With[{f = FileNameJoin[{mk["runX", "j0101"], "basis.m"}]},
  Put[<|"name" -> "j0101", "masters" -> {<|"definition" -> d|>}, "toolsUsed" -> {}, "citations" -> {}|>, f]; SetFileDate[f, $ahead]];
basisX[j[h, 0, 1, 0, 1]];
CoreRecordTool[FileNameJoin[{runX, "j0101"}], "FiniteFlow", "first pass"];
CoreImportCitations[runX, runS, "j0011", "j0101", "mapped from j0011", "BasisKey" -> CoreBasisKey[{j[h, 0, 1, 0, 1]}]];
esX = CoreReadCitations[runX];
add[{Lookup[SelectFirst[esX, #["kind"] === "tool" && #["tool"] === "kira" &], {"sector", "via", "part"}], Lookup[First[papersOf[esX, "2401.00001"]], "part"]},
  {{"j0101", "mapped from j0011", "cite"}, "cite"}, TestID -> "an import stamped with the basis it went into is cited while that basis is current"];
(* the same size and the same date: only the content (MD5, for a file written in the last seconds) tells them apart *)
basisX[j[h, 0, 2, 0, 1]];
esX = CoreReadCitations[runX];
CoreWriteCitations[runX];
add[{Lookup[SelectFirst[esX, #["kind"] === "tool" && #["tool"] === "kira" &], {"part", "outcome"}], Lookup[First[papersOf[esX, "2401.00001"]], {"part", "outcome"}],
    Lookup[SelectFirst[esX, #["tool"] === "FiniteFlow" &], "part"], StringContainsQ[consultedPart[runX], "- **Kira**: " ~~ __ ~~ " Sectors: j0101 (first pass, mapped from j0011, replaced by a later basis).\n"],
    StringContainsQ[citePart[runX], "**Kira**"], StringContainsQ[citePart[runX], "**FiniteFlow**"]},
  {{"consulted", "replaced by a later basis"}, {"consulted", "replaced by a later basis"}, "cite", True, False, True},
  TestID -> "a later basis demotes the stamped import, tools included, to Also consulted; the run's own tools stay cited"];
runQ = mk["runQ"];
Put[<|"Accepted" -> {<|"Id" -> 1, "Replace" -> {7}, "NewDefs" -> <|7 -> 0|>|>}, "Pending" -> {<|"Id" -> 2|>},
    "Rejected" -> {<|"Id" -> 3|>, <|"Id" -> 4, "Declined" -> "2026-10-19", "DeclineReason" -> "the user keeps the old basis"|>},
    "Slices" -> {<|"File" -> "slices/slice_000.mx", "Label" -> "local slice"|>}|>, FileNameJoin[{runQ, "state.m"}]];
viaS = "maximal-cut-basis run runS";
MapThread[CoreImportCitations[runQ, runS, "j0011", #1, viaS, #2 -> #3] &, {{"fam/j0001", "fam/j0010", "fam/j0100", "fam/j1000", "fam/j1001", "fam/j1010", "fam/j1100"},
   {"Change", "Change", "Change", "Change", "Start", "Start", "Start"}, {1, 2, 3, 4, {7, 8}, {7}, True}}];
esQ = CoreReadCitations[runQ];
kiraQ[s_] := Lookup[SelectFirst[esQ, #["kind"] === "tool" && #["sector"] === s &], {"part", "outcome"}, Missing[]];
add[kiraQ /@ {"fam/j0001", "fam/j0010", "fam/j0100", "fam/j1000", "fam/j1001", "fam/j1010", "fam/j1100"},
  {{"cite", Missing[]}, {"cite", "pending"}, {"consulted", "change 3 rejected"}, {"consulted", "change 4 declined (the user keeps the old basis)"},
   {"cite", Missing[]}, {"consulted", "accepted changes replaced every starting master it went into"}, {"cite", Missing[]}},
  TestID -> "imports stamped with a change follow it (accepted, pending, rejected, declined); with starting masters, while one is left"];
add[Lookup[Select[papersOf[esQ, "2401.00001"], MemberQ[{"fam/j0100", "fam/j0010"}, #["sector"]] &], {"sector", "result", "part"}],
  {{"fam/j0010", "pending", "cite"}, {"fam/j0100", "rejected", "consulted"}}, TestID -> "the imported papers follow their change too"];
(* a rescale, or the simplification phase's letter rescaling, keeps the same integrals: the starting master stays *)
runR = mk["runR"];
Put[<|"Accepted" -> {<|"Id" -> 1, "Kind" -> "rescale", "Replace" -> {7}|>, <|"Id" -> 2, "Kind" -> "change", "Rung" -> "simplify", "Replace" -> {8},
      "NewDefs" -> <|8 -> 0|>, "Simplify" -> <|"Move" -> "rescale"|>|>, <|"Id" -> 3, "Kind" -> "change", "Replace" -> {9}, "NewDefs" -> <|9 -> 0|>|>},
    "Pending" -> {}, "Rejected" -> {}|>, FileNameJoin[{runR, "state.m"}]];
MapThread[CoreImportCitations[runR, runS, "j0011", #1, viaS, "Start" -> #2] &, {{"fam/j0001", "fam/j0010", "fam/j0100"}, {{7}, {8}, {9}}}];
esR = CoreReadCitations[runR];
partR[s_] := Lookup[SelectFirst[esR, #["kind"] === "tool" && #["sector"] === s &], "part", Missing[]];
add[{partR /@ {"fam/j0001", "fam/j0010", "fam/j0100"},
    CoreRescaleChangeQ /@ {<|"Kind" -> "rescale"|>, <|"Simplify" -> <|"Move" -> "rescale"|>|>, <|"Simplify" -> <|"Move" -> "swap"|>|>, <|"Kind" -> "change"|>, None}},
  {{"cite", "cite", "consulted"}, {True, True, False, False, False}},
  TestID -> "a rescaled starting master keeps the credits of the run that produced it; a replaced one does not"];


(* ::Section:: *)
(*Older records: literature.m outcomes, reduction jobs, the starting slice*)


runL2 = mk["runL2"]; Put[<||>, FileNameJoin[{runL2, "run_info.m"}]];
Scan[PutAppend[<|"sector" -> "j0101", "reference" -> ref[#[[1]]], "used" -> "the basis", "outcome" -> #[[2]], "date" -> "2026-01-01"|>, FileNameJoin[{runL2, "literature.m"}]] &,
  {{"2501.00001", "eps-form, adopted"}, {"2501.00002", "eps-polynomial, not adopted"}, {"2501.00003", "not adopted"}, {"2501.00004", "rejected, change 3"}, {"2501.00005", "a remark"}}];
esL2 = CoreReadCitations[runL2];
add[Table[With[{e = First[papersOf[esL2, n]]}, Append[Lookup[e, {"result", "change", "part"}, None], SkillCore`Citations`Private`outcomeText[e]]],
    {n, {"2501.00001", "2501.00002", "2501.00003", "2501.00004", "2501.00005"}}],
  {{"adopted", None, "cite", "adopted (eps-form)"}, {"not adopted", None, "consulted", "not adopted (eps-polynomial)"}, {"not adopted", None, "consulted", "not adopted"},
   {"rejected", 3, "consulted", "rejected"}, {"used", None, "cite", "a remark"}},
  TestID -> "older literature.m: \"..., not adopted\" and \"rejected, change 3\" give their result and change"];
Scan[PutAppend[<|"sector" -> "fam/j0101", "reference" -> ref[#[[1]]], "used" -> "a change", "outcome" -> #[[2]], "date" -> "2026-01-01"|>, FileNameJoin[{runQ, "literature.m"}]] &,
  {{"2501.00006", "pending, change 1"}, {"2501.00007", "accepted, change 3"}}];
esQ = CoreReadCitations[runQ];
add[Lookup[First[papersOf[esQ, #]], {"result", "part"}] & /@ {"2501.00006", "2501.00007"}, {{"accepted", "cite"}, {"rejected", "consulted"}},
  TestID -> "older literature.m of a pole-free run: state.m resolves the changes it names"];
runJ = mk["runJ"];
Put[<|"Accepted" -> {}, "Pending" -> {}, "Rejected" -> {}, "Slices" -> {<|"Label" -> "imported slice.m"|>}|>, FileNameJoin[{runJ, "state.m"}]];
Put[<|"Name" -> "old1", "SectorKey" -> {fam, {0, 1, 1}}|>, FileNameJoin[{mk["runJ", "jobs", "old1"], "job.m"}]];
Put[<|"Status" -> "done", "Reducers" -> {"Kira", "FiniteFlow", Missing[]}|>, FileNameJoin[{runJ, "jobs", "old1", "status.m"}]];
Put[<|"Name" -> "new1", "Analytic" -> <|"Rows" -> {}|>|>, FileNameJoin[{mk["runJ", "jobs", "new1"], "job.m"}]];
Put[<|"Status" -> "done", "Tools" -> {"FiniteFlow", "LiteRed", "LiteIBP"}|>, FileNameJoin[{runJ, "jobs", "new1", "status.m"}]];
Put[<|"Name" -> "unrun"|>, FileNameJoin[{mk["runJ", "jobs", "unrun"], "job.m"}]];
CoreRecordTool[runJ, "FiniteFlow", "an earlier analytic job", "Sector" -> "whole run"];
add[toolRows[CoreReadCitations[runJ]], Sort[{{"FiniteFlow", "whole run", "an earlier analytic job"}, {"LiteRed", "whole run", "analytic job new1"}, {"LiteIBP", "whole run", "analytic job new1"},
    {"LiteRed", "fam/j011", "reduction job old1"}, {"LiteIBP", "fam/j011", "reduction job old1"}, {"kira", "fam/j011", "reduction job old1"},
    {"fer64", "fam/j011", "reduction job old1"}, {"FiniteFlow", "fam/j011", "reduction job old1"}}],
  TestID -> "older pole-free jobs: status.m \"Tools\" or \"Reducers\", for what the ledger does not already credit"];
CoreWriteCitations[runJ]; CoreWriteCitations[runQ];
add[{StringContainsQ[md[runQ], "built inside the skill"], StringContainsQ[md[runJ], "came from outside the skill"], StringContainsQ[md[runPF], "came from outside the skill"]},
  {True, True, True}, TestID -> "the starting DE: built by the skill (a local slice) or from outside"];


(* ::Section:: *)
(*Second review: imported copies and outcomes, older jobs, repeated imports, the memo*)


(* an outcome entry of a change applies to the run's own papers; an imported copy follows its change through state.m *)
runS2 = mk["runS2"]; Put[<||>, FileNameJoin[{runS2, "run_info.m"}]];
CoreRecordPaper[mk["runS2", "j0011"], <|"reference" -> ref["2301.00021"], "used" -> "candidates kept out", "result" -> "not adopted"|>];
CoreRecordPaper[FileNameJoin[{runS2, "j0011"}], <|"reference" -> ref["2301.00022"], "used" -> "the basis", "result" -> "used"|>];
runW = mk["runW"];
Put[<|"Accepted" -> {<|"Id" -> 5|>}, "Pending" -> {}, "Rejected" -> {<|"Id" -> 6|>}, "Approval" -> True|>, FileNameJoin[{runW, "state.m"}]];
CoreImportCitations[runW, runS2, "j0011", "fam/j0011", "maximal-cut-basis run runS2", "Change" -> 5];
CoreImportCitations[runW, runS2, "j0011", "fam/j0110", "maximal-cut-basis run runS2", "Change" -> 6];
CoreRecordOutcome[runW, 5, "approved", "approved by the user"];
CoreRecordPaper[mk["runW", "fam", "j0011"], <|"reference" -> ref["2301.00023"], "used" -> "the change itself", "change" -> 5, "result" -> "pending"|>];
esW = CoreReadCitations[runW];
pW[n_, s_] := Lookup[SelectFirst[papersOf[esW, n], #["sector"] === s &], {"result", "part"}];
add[{pW["2301.00021", "fam/j0011"], pW["2301.00022", "fam/j0011"], pW["2301.00022", "fam/j0110"], pW["2301.00023", "fam/j0011"]},
  {{"not adopted", "consulted"}, {"accepted", "cite"}, {"rejected", "consulted"}, {"accepted", "cite"}},
  TestID -> "an approval does not cite an imported copy that was not adopted; an imported copy follows its change; the run's own paper takes the outcome"];
(* an older job's own use is not hidden by an imported (and consulted) credit of the same tool and sector *)
runJ2 = mk["runJ2"];
Put[<|"Accepted" -> {}, "Pending" -> {}, "Rejected" -> {}|>, FileNameJoin[{runJ2, "state.m"}]];
CoreImportCitations[runJ2, runS, "j0011", "fam/j011", viaS, "Change" -> 9];
Put[<|"Name" -> "old2", "SectorKey" -> {fam, {0, 1, 1}}|>, FileNameJoin[{mk["runJ2", "jobs", "old2"], "job.m"}]];
Put[<|"Status" -> "done", "Reducers" -> {"Kira"}|>, FileNameJoin[{runJ2, "jobs", "old2", "status.m"}]];
add[Sort[Lookup[Select[CoreReadCitations[runJ2], #["kind"] === "tool" && #["tool"] === "kira" &], {"step", "part"}]],
  Sort[{{"first pass", "consulted"}, {"reduction job old2", "cite"}}], TestID -> "an imported credit does not hide an older job's own use"];
(* older jobs without "Tools" or "Reducers": what their status says ran *)
runK = mk["runK"];
Put[<|"Accepted" -> {}, "Pending" -> {}, "Rejected" -> {}|>, FileNameJoin[{runK, "state.m"}]];
MapThread[(Put[<|"Name" -> #1|>, FileNameJoin[{mk["runK", "jobs", #1], "job.m"}]]; Put[<|"Status" -> #2|>, FileNameJoin[{runK, "jobs", #1, "status.m"}]]) &,
  {{"a", "b", "c", "d", "e"}, {"learned", "done", "refused", "failed", "running"}}];
add[GroupBy[Select[CoreReadCitations[runK], #["kind"] === "tool" &], #["step"] &, Sort[Lookup[#, "tool"]] &],
  <|"reduction job a" -> Sort[{"FiniteFlow", "LiteIBP", "LiteRed"}], "reduction job b" -> Sort[{"FiniteFlow", "LiteIBP", "LiteRed"}], "reduction job c" -> Sort[{"LiteIBP", "LiteRed"}]|>,
  TestID -> "an older job's status: learned or done credit FiniteFlow, LiteRed and LiteIBP; refused the identities only; failed or running nothing"];
(* a second import appends nothing, a paper whose id in the source is another reference's included *)
runS3 = mk["runS3"]; Put[<||>, FileNameJoin[{runS3, "run_info.m"}]];
CoreRecordTool[mk["runS3", "j0011"], "kira", "first pass"];
CoreRecordPaper[FileNameJoin[{runS3, "j0011"}], <|"reference" -> "Q. Five, A paper, doi:10.5555/abc.1", "used" -> "the basis"|>];
CoreRecordPaper[FileNameJoin[{runS3, "j0011"}], <|"reference" -> "Q. Five, A paper, doi:10.5555/abc.1, arXiv:2601.00001", "used" -> "the map"|>];
runT3 = mk["runT3"]; Put[<||>, FileNameJoin[{runT3, "run_info.m"}]];
lines[run_] := Length[ReadList[FileNameJoin[{run, "citations.m"}], String]];
imp1 = CoreImportCitations[runT3, runS3, "j0011", "j0101", "mapped from j0011", "BasisKey" -> "planted"]; n1 = lines[runT3];
imp2 = CoreImportCitations[runT3, runS3, "j0011", "j0101", "mapped from j0011", "BasisKey" -> "planted"];
add[{Length[imp1], Lookup[papersOf[CoreReadCitations[runS3], "10.5555/abc.1"], "used"], imp2, lines[runT3] === n1},
  {3, {"the basis", "the map"}, {}, True}, TestID -> "a second import appends nothing, for a paper whose id is shared too"];
(* the memo: the same files (dates and sizes) are not read again; a new date or size, state.m or basis.m reads them *)
runM2 = mk["runM2"]; Put[<||>, FileNameJoin[{runM2, "run_info.m"}]];
lfM = FileNameJoin[{runM2, "citations.m"}]; $past = DateObject[{2026, 1, 1, 12, 0, 0}];
writeLedger[step_] := (Put[<|"kind" -> "tool", "tool" -> "kira", "sector" -> "whole run", "step" -> step, "date" -> "2026-01-01"|>, lfM]; SetFileDate[lfM, $past]);
stepsM[] := Lookup[Select[CoreReadCitations[runM2], #["kind"] === "tool" &], "step"];
writeLedger["aaaa"]; m1 = stepsM[];
writeLedger["bbbb"]; m2 = stepsM[];   (* the same date and size: the memo answers *)
SetFileDate[lfM, DatePlus[$past, {1, "Day"}]]; m3 = stepsM[];
CoreRecordTool[runM2, "FiniteFlow", "cccc"]; m4 = stepsM[];
CoreRecordPaper[runM2, <|"reference" -> ref["2601.00002"], "used" -> "a change", "change" -> 1|>];
Put[<|"Accepted" -> {}, "Pending" -> {}, "Rejected" -> {}|>, FileNameJoin[{runM2, "state.m"}]];
m5 = Lookup[First[papersOf[CoreReadCitations[runM2], "2601.00002"]], "part"];
Put[<|"Accepted" -> {<|"Id" -> 1|>}, "Pending" -> {}, "Rejected" -> {}|>, FileNameJoin[{runM2, "state.m"}]];
m6 = Lookup[First[papersOf[CoreReadCitations[runM2], "2601.00002"]], "part"];
add[{m1, m2, m3, m4, m5, m6}, {{"aaaa"}, {"aaaa"}, {"bbbb"}, {"bbbb", "cccc"}, "consulted", "cite"},
  TestID -> "the memo: unchanged files are not read again; a changed ledger or state.m is"];


report = TestReport[tests];
Do[With[{r = report["TestResults"][id]},
    Print[If[r["Outcome"] === "Success", "PASS ", "FAIL "], r["TestID"], If[r["Outcome"] === "Success", "",
      "\n     got " <> ToString[Short[r["ActualOutput"], 5], InputForm] <> "\n     expected " <> ToString[Short[r["ExpectedOutput"], 5], InputForm] <>
        If[r["Outcome"] === "MessagesFailure", "\n     messages " <> ToString[r["ActualMessages"], InputForm], ""]]]],
  {id, Keys[report["TestResults"]]}];
Print[report["TestsSucceededCount"], " passed, ", report["TestsFailedCount"], " failed, ", Round[report["TimeElapsed"], 0.1]];
DeleteDirectory[tmp, DeleteContents -> True];
Exit[If[report["AllTestsSucceeded"], 0, 1]];
