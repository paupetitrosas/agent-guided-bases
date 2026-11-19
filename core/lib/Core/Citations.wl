(* ::Package:: *)

(* ::Title:: *)
(*SkillCore`Citations`: the run's ledger of tools, methods and papers (citations.m), its reader, CITATIONS.md and the*)
(*page blocks (shared by both skills)*)


(* ::Text:: *)
(*Every use is appended to <run>/citations.m when it happens, one Association per line, and nothing is ever rewritten:*)
(*rewriting basis.m, resetting a kernel's marks or running in another process cannot lose a credit. Readers dedupe.*)
(*The pages, basis.m, CHANGES.md and CITATIONS.md all come from CoreReadCitations, so they cannot disagree.*)
(*An entry imported from another run or sector follows what it went into: it carries the basis, the change or the*)
(*starting masters it was imported for, and is cited while that is in the final result.*)


BeginPackage["SkillCore`Citations`", {"SkillCore`", "SkillCore`Tools`", "SkillCore`Records`", "SkillCore`Pages`"}];

$CoreCitationContext::usage = "$CoreCitationContext is where a use of a tool is credited: None, or <|\"Dir\" -> a folder of the run, \"Sector\" -> the sector (\"j0101\", \"fam/j0101\" or \"whole run\"), \"Step\" -> what ran (\"first pass\", \"check_basis\", ...)|>. Set it with CoreCitationContext, scope it with CoreWithCitationContext.";
CoreCitationContext::usage = "CoreCitationContext[dir, sector, step] sets $CoreCitationContext (sector Automatic: CoreCitationSector[dir]) and appends to it the marks this kernel left pending (MCBMarkToolUsed without a context), so that a use made before the run folder was known is credited to it. CoreCitationContext[None] unsets it. Returns the context.";
CoreWithCitationContext::usage = "CoreWithCitationContext[ctx, expr] evaluates expr with $CoreCitationContext = ctx (an Association as in $CoreCitationContext, or {dir, sector, step}); pending marks are not flushed into it. CoreWithCitationContext[None, expr] evaluates expr as no use at all: what it marks is dropped, and this kernel's marks are left as they were (MCBPreflight runs this way).";
CoreCitationSector::usage = "CoreCitationSector[dir] is the sector name the ledger uses for a folder: \"j0101\" for a sector folder of a maximal-cut-basis run, \"fam/j0101\" for <run>/fam/j0101 of a pole-free-basis run, \"whole run\" for any other folder. dir is expanded first (\".\" works).";
CoreRecordTool::usage = "CoreRecordTool[dir, tool, step] appends a use of tool (a name of $MCBTools as CoreToolKey reads it, or a list of names) to the ledger of the run of dir, for the sector of dir: for jobs and steps that ran elsewhere (another kernel, a program run by hand). Options \"Sector\" (Automatic: CoreCitationSector[dir]) and \"Via\" (an imported credit). An unknown name is a message and $Failed, and nothing is appended. It does not mark this kernel. Returns the entries.";
CoreRecordPaper::usage = "CoreRecordPaper[dir, <|\"reference\" -> \"authors, title, journal, arXiv:xxxx.xxxxx or DOI\", \"used\" -> \"what was taken from it and where it went\", ...|>] appends a paper entry to the ledger of the run of dir. reference and used must be non-empty strings: $Failed with a message otherwise (do not ignore it). A reference without an arXiv id or DOI is recorded with a warning. Optional keys: \"sector\" (default CoreCitationSector[dir]), \"rung\", \"outcome\" (text), \"result\" (\"used\", the default, \"adopted\", \"not adopted\", \"accepted\", \"pending\", \"rejected\", \"declined\" or \"not tried\"), \"change\" (the id of a pole-free change), \"basisKey\" (CoreBasisKey of the maximal-cut basis it went into), \"via\". Returns the entry.";
CoreRecordOutcome::usage = "CoreRecordOutcome[dir, change, result, outcome] appends a later outcome of a pole-free change (result \"accepted\" (\"approved\" is read so), \"declined\", \"rejected\", ...; outcome a text) to the ledger; the reader gives the latest one to every paper entry with that \"change\". Returns the entry.";
CoreImportCitations::usage = "CoreImportCitations[toDir, fromRunDir, fromSectors, toSector, via, opts] copies every tool and paper entry of the sectors fromSectors (a name or a list of names) of the run fromRunDir, as CoreReadCitations reads them (older records included), into the ledger of the run of toDir, with sector toSector and \"via\" -> via (\"maximal-cut-basis run <name>\", \"mapped from j0101\"). opts stamp every copy with what it went into, so that the reader cites it only while that is in the final result: \"BasisKey\" -> the CoreBasisKey of the maximal-cut-basis record it went into, \"Change\" -> the id of the pole-free change it went into, \"Start\" -> True or the labels of the starting masters of a pole-free sector it went into. The source's own \"basisKey\", \"change\" and \"start\" are dropped; an entry that is not in the source's final result comes as \"not adopted\", with its reason as outcome. Entries the ledger already holds are not copied again. Returns the entries appended.";
CoreReadCitations::usage = "CoreReadCitations[runDir] is every tool and paper entry of the run, oldest first: citations.m, and the records of older runs: literature.m (papers; an outcome \"..., not adopted\" or \"rejected, change 3\" gives that result and change), the \"toolsUsed\" of j*/basis.m (step \"earlier run\", with the method papers their citations name) and, in a pole-free run, the tools of jobs/*/status.m (\"Tools\", or the older \"Reducers\", or what its \"Status\" says ran), where the run's own ledger entries do not already credit the tool to the sector. Tool names are read with CoreToolKey, a paper's id is shared by every reference that has one of its ids, entries are deduplicated, \"whole system\" is read as \"whole run\", and the latest outcome of each pole-free change is applied to the run's own papers (an imported copy follows its change through state.m). Every entry gets \"part\": \"cite\" (a tool the run ran itself; a paper or imported entry behind the final result, a pending change's marked \"pending\") or \"consulted\" (rejected, declined, not adopted, not tried; a \"basisKey\" that is not the sector's current basis.m: \"replaced by a later basis\"; a change neither accepted nor pending in state.m; starting masters all replaced by accepted changes). A \"not adopted\" paper of the sector itself whose basis is the current one is cited (\"adopted\"); a use whose final state cannot be told is cited. Memoised on the dates and sizes of the files it reads.";
CoreSectorCitations::usage = "CoreSectorCitations[runDir, sector] is <|\"tools\" -> entries, \"papers\" -> entries|> of one sector, as CoreReadCitations gives them: its own entries (imported ones included) and the whole-run ones whose text names the sector.";
CoreCitationGroups::usage = "CoreCitationGroups[runDir] is what CITATIONS.md shows: <|\"tools\", \"methods\", \"consultedTools\" -> {<|\"name\", \"title\", \"kind\", \"citation\", \"uses\" -> tool entries, \"papers\" -> paper entries|>, ...}, \"papers\", \"consulted\" -> {<|\"id\", \"reference\", \"uses\" -> paper entries|>, ...}|>. A tool or paper with a cited use is under \"tools\", \"methods\" or \"papers\" with all its uses, else under \"consultedTools\" or \"consulted\"; a paper that shares an id with the citation of a cited tool or method is shown once, in that tool's \"papers\".";
CoreCiteMarkdown::usage = "CoreCiteMarkdown[runDir] is the \"Cite\" part of CITATIONS.md (its ### Tools, ### Methods and ### Papers sections), for other reports such as CHANGES.md; \"\" when the run has no entry.";
CoreWriteCitations::usage = "CoreWriteCitations[runDir] writes CITATIONS.md in the run folder from CoreReadCitations: what to cite (tools, methods, papers behind the final result) and what was only consulted (papers, imported tools), each with its sectors, steps and outcomes; for a pole-free run, where its starting DE came from. It removes the skill's own older LITERATURE.md (first line \"# Literature used in this run\"), never another file of that name. Returns the path of CITATIONS.md, or Missing[\"NoCitations\"] (nothing written) for a run with no entry.";
CoreCitationsHTML::usage = "CoreCitationsHTML[runDir] is the HTML block of a summary page: the tools, methods and papers to cite with their sectors, and what was only consulted, pointing to CITATIONS.md; \"\" for a run with no entry.";
CoreSectorCitationsHTML::usage = "CoreSectorCitationsHTML[runDir, sector] is the HTML block of a sector page: the tools, methods and papers of CoreSectorCitations, with their steps and outcomes; \"\" when the sector has none.";
CoreBasisKey::usage = "CoreBasisKey[defs] is the key of a maximal-cut basis for the \"basisKey\" of a paper entry: a SHA-256 hash (hexadecimal) of the InputForm of the list of its masters' definitions, written without contexts, so that every kernel gets the same key. CoreBasisKey[record] takes the \"definition\"s of a basis.m record's \"masters\" (Missing[\"NoBasis\"] when it has none).";
CoreRescaleChangeQ::usage = "CoreRescaleChangeQ[change] is True for an accepted change of a pole-free run (state.m) that only rescales masters: a rescale (\"Kind\" -> \"rescale\") or the simplification phase's letter rescaling (\"Simplify\" move \"rescale\"). Its masters are the same integrals, so it replaces no starting master: the credits of the run that produced them stay cited.";
CorePaperId::usage = "CorePaperId[reference] is the id of a paper: its first arXiv id, lowercased and without version (2001.00001, hep-ph/9611449; an arxiv.org/abs/ or /pdf/ link reads as its id), else its first DOI, lowercased (a doi.org link too), else the reference with case, punctuation and spaces normalised. The reader gives every reference that shares one of its ids with another the id of the first; a reference with two arXiv ids or two DOIs names two papers, links none of them, and counts as its first id.";

Begin["`Private`"];


esc = MCBHTMLEscape;
today[] := DateString[{"Year", "-", "Month", "-", "Day"}];
day[f_String] := DateString[FileDate[f], {"Year", "-", "Month", "-", "Day"}];
ledgerFile[run_String] := FileNameJoin[{run, "citations.m"}];

$results = {"used", "adopted", "not adopted", "accepted", "pending", "rejected", "declined", "not tried"};
$consultedResults = {"rejected", "declined", "not adopted", "not tried"};
normResult[r_] := Replace[r, "approved" -> "accepted"];
normSector[s_String] := Replace[StringTrim[s], "whole system" -> "whole run"];
normSector[_] := "whole run";

unknown[head_, bad_List] := Message[MessageName[head, "unknown"], StringRiffle[ToString[#, InputForm] & /@ DeleteDuplicates[bad], ", "], StringRiffle[Keys[$MCBTools], ", "]];
MCBMarkToolUsed::unknown = CoreRecordTool::unknown = "Not in the registry of tools and methods ($MCBTools): `1`. The known names are `2`.";


(* ::Section:: *)
(*Ids*)


(* the arXiv id: new style 2001.00001 or old style hep-ph/9611449, never a piece of a DOI or of a longer number; an
   arxiv.org link reads as the id it points to *)
$arXiv = RegularExpression["(?<![\\w./-])(?:(\\d{4}\\.\\d{4,5})|([A-Za-z-]+(?:\\.[A-Za-z]{2})?/\\d{7}))(?:v\\d+)?(?!\\d)"];
$doi = RegularExpression["(?<![\\w.])10\\.\\d{4,}/\\S+"];
arXivIds[t_String] := ToLowerCase /@ StringCases[StringReplace[t, RegularExpression["(?i)(?:https?://)?(?:www\\.)?arxiv\\.org/(?:abs|pdf)/"] -> "arXiv:"], $arXiv -> "$1$2"];
dois[t_String] := ToLowerCase[StringTrim[#, RegularExpression["[.,;:)\\]]+$"]]] & /@ StringCases[t, $doi];
paperIds[t_String] := DeleteDuplicates[Join[arXivIds[t], dois[t]]];
paperIds[_] := {};
normText[t_String] := StringTrim[StringReplace[StringReplace[ToLowerCase[t], RegularExpression["[^\\w\\s]"] -> " "], Whitespace -> " "]];
idsOrText[t_String] := Replace[paperIds[t], {} :> {normText[t]}];

CorePaperId[ref_String] := First[idsOrText[ref]];

(* a paper written with its arXiv id and its DOI is one paper with each of them: references that share an id, directly
   or through others, get the id of the first of them. A reference with two arXiv ids or two DOIs names two papers: it
   links nothing, and counts as its first id *)
onePaperQ[ref_String] := Length[arXivIds[ref]] <= 1 && Length[dois[ref]] <= 1;
linkedIds[ref_String] := If[onePaperQ[ref], idsOrText[ref], {CorePaperId[ref]}];
sharedIds[ps_List] := Module[{ids = linkedIds /@ Lookup[ps, "reference"], comp, first = <||>},
  comp = Association[Flatten[Function[c, (# -> First[c]) & /@ c] /@
     ConnectedComponents[Graph[Union @@ ids, Flatten[UndirectedEdge @@@ Partition[#, 2, 1] & /@ ids]]]]];
  Table[With[{c = comp[First[ids[[i]]]]}, If[! KeyExistsQ[first, c], first[c] = First[ids[[i]]]]; Append[ps[[i]], "id" -> first[c]]], {i, Length[ps]}]];

(* the masters' definitions without contexts: a basis read in a kernel without the toolkit has the same key *)
CoreBasisKey[defs_List] := IntegerString[Hash[StringReplace[
     Block[{$ContextPath = {"System`"}, $Context = "SkillCoreBasisKey`"}, ToString[defs, InputForm]],
     RegularExpression["(?:[A-Za-z$][A-Za-z0-9$]*`)+"] -> ""], "SHA256"], 16, 64];
CoreBasisKey[rec_Association] := With[{m = Lookup[rec, "masters", None]},
  If[ListQ[m] && AllTrue[m, AssociationQ[#] && KeyExistsQ[#, "definition"] &], CoreBasisKey[Lookup[m, "definition"]], Missing["NoBasis"]]];


(* ::Section:: *)
(*The context and the marks*)


(* "j0101" in a maximal-cut-basis run, "fam/j0101" in a pole-free one (<run>/<fam>/<jPATTERN>) *)
CoreCitationSector[dir_String] := Module[{d = ExpandFileName[dir], run},
  If[! MCBSectorFolderQ[d], Return["whole run"]];
  run = CoreRunFolder[d];
  If[FileNameDrop[d, -2] === run, FileNameTake[d, {-2}] <> "/" <> FileNameTake[d], FileNameTake[d]]];

CoreCitationContext::ctx = "`1` is not a citation context: give a folder of the run, a sector name (or Automatic) and a step.";
ctxOf[c_Association] := With[{dir = Lookup[c, "Dir", None], s = Lookup[c, "Sector", Automatic], step = Lookup[c, "Step", ""]},
  If[! StringQ[dir] || ! (StringQ[s] || s === Automatic) || ! StringQ[step], $Failed,
    <|"Dir" -> ExpandFileName[dir], "Sector" -> If[s === Automatic, CoreCitationSector[dir], normSector[s]], "Step" -> step|>]];
ctxOf[{dir_, s_, step_}] := ctxOf[<|"Dir" -> dir, "Sector" -> s, "Step" -> step|>];
ctxOf[_] := $Failed;

$CoreCitationContext = None;
(* this kernel's marks (MCBToolsUsed), the marks made without a context, and the entries it already appended *)
$used = {};
$pending = {};
$appended = <||>;
$sizes = <||>;

append[run_String, e_Association] := (
  If[! DirectoryQ[run], CreateDirectory[run, CreateIntermediateDirectories -> True]];
  PutAppend[e, ledgerFile[run]]; e);

(* appending the same entry twice is harmless (readers dedupe); a kernel just does not repeat itself, unless the ledger
   was deleted or replaced since (a run started again in the same folder) *)
appendTool[c_Association, t_String, extra_Association] := Module[{run = CoreRunFolder[c["Dir"]], e, key, f},
  e = Join[<|"kind" -> "tool", "tool" -> t, "sector" -> c["Sector"], "step" -> c["Step"]|>, extra, <|"date" -> today[]|>];
  key = {run, t, e["sector"], e["step"], Lookup[e, "via", None]};
  f = ledgerFile[run];
  If[! FileExistsQ[f] || FileByteCount[f] < Lookup[$sizes, run, 0], $appended = KeySelect[$appended, First[#] =!= run &]];
  If[! TrueQ[$appended[key]], append[run, e]; $appended[key] = True; $sizes[run] = FileByteCount[f]];
  e];

CoreCitationContext[None] := ($CoreCitationContext = None);
CoreCitationContext[dir_String, sector_ : Automatic, step_ : ""] := With[{c = ctxOf[{dir, sector, step}]},
  If[c === $Failed, Message[CoreCitationContext::ctx, {dir, sector, step}]; Return[$Failed]];
  $CoreCitationContext = c;
  Scan[appendTool[c, #, <||>] &, $pending];
  $pending = {};
  c];

SetAttributes[CoreWithCitationContext, HoldRest];
CoreWithCitationContext[None, expr_] := Block[{$CoreCitationContext = None, $used = $used, $pending = $pending}, expr];
CoreWithCitationContext[ctx_, expr_] := With[{c = ctxOf[ctx]},
  If[c === $Failed, Message[CoreCitationContext::ctx, ctx]; $Failed, Block[{$CoreCitationContext = c}, expr]]];

MCBMarkToolUsed[t_] := Module[{k = CoreToolKey[t], c},
  If[k === $Failed, unknown[MCBMarkToolUsed, {t}]; Return[$Failed]];
  $used = Union[$used, {k}];
  c = If[$CoreCitationContext === None, None, ctxOf[$CoreCitationContext]];
  If[c === $Failed, Message[CoreCitationContext::ctx, $CoreCitationContext]];
  If[AssociationQ[c], appendTool[c, k, <||>], $pending = Union[$pending, {k}]];
  k];
MCBToolsUsed[] := $used;
(* the marks are per sector: MCBAutoPass and the one-sector scripts reset them when a sector starts; the ledger keeps all *)
MCBResetToolsUsed[] := ($used = {}; $pending = {}; {});

Options[CoreRecordTool] = {"Sector" -> Automatic, "Via" -> None};
CoreRecordTool[dir_String, tools_, step_String, OptionsPattern[]] := Module[{ts = Flatten[{tools}], ks, s = OptionValue["Sector"], v = OptionValue["Via"]},
  ks = CoreToolKey /@ ts;
  If[MemberQ[ks, $Failed], unknown[CoreRecordTool, Pick[ts, ks, $Failed]]; Return[$Failed]];
  If[! (StringQ[s] || s === Automatic), Message[CoreCitationContext::ctx, {dir, s, step}]; Return[$Failed]];
  appendTool[<|"Dir" -> ExpandFileName[dir], "Sector" -> If[s === Automatic, CoreCitationSector[dir], normSector[s]], "Step" -> step|>, #,
      If[StringQ[v], <|"via" -> v|>, <||>]] & /@ DeleteDuplicates[ks]];


(* ::Section:: *)
(*Papers and outcomes*)


CoreRecordPaper::input = MCBRecordLiterature::input = "`1` is missing or empty: give the full reference (authors, title, arXiv number or DOI) and what was used from it.";
CoreRecordPaper::id = MCBRecordLiterature::id = "The reference \"`1`\" has no arXiv number or DOI; add one (checked on arXiv or INSPIRE) so that the authors can be found.";
CoreRecordPaper::result = MCBRecordLiterature::result = CoreRecordOutcome::result = "The result `1` is not one of `2`.";

paperEntry[head_, dir_String, e0_Association] := Module[{r = normResult[Lookup[e0, "result", "used"]], ref},
  Do[If[! StringQ[Lookup[e0, key, None]] || StringTrim[e0[key]] === "", Message[MessageName[head, "input"], key]; Return[$Failed, Module]],
    {key, {"reference", "used"}}];
  If[! MemberQ[$results, r], Message[MessageName[head, "result"], ToString[r, InputForm], StringRiffle[$results, ", "]]; Return[$Failed]];
  ref = StringTrim[e0["reference"]];
  If[paperIds[ref] === {}, Message[MessageName[head, "id"], ref]];
  Join[<|"kind" -> "paper", "reference" -> ref, "id" -> CorePaperId[ref],
      "sector" -> If[StringQ[Lookup[e0, "sector", None]], normSector[e0["sector"]], CoreCitationSector[dir]], "used" -> StringTrim[e0["used"]]|>,
    Select[KeyTake[e0, {"rung", "outcome", "change", "basisKey", "via"}], ! MatchQ[#, None | _Missing] &],
    <|"result" -> r, "date" -> today[]|>]];

CoreRecordPaper[dir_String, e0_Association] := With[{e = paperEntry[CoreRecordPaper, dir, e0]},
  If[e === $Failed, $Failed, append[CoreRunFolder[dir], e]]];

(* the older name, for existing calls and generated scripts: the same checks and messages, then CITATIONS.md *)
MCBRecordLiterature[dir_String, e0_Association] := With[{e = paperEntry[MCBRecordLiterature, dir, e0]},
  If[e === $Failed, $Failed, append[CoreRunFolder[dir], e]; CoreWriteCitations[dir]]];

CoreRecordOutcome[dir_String, change_, result_String, outcome_String : ""] := With[{r = normResult[result]},
  If[! MemberQ[$results, r], Message[CoreRecordOutcome::result, ToString[result, InputForm], StringRiffle[$results, ", "]]; Return[$Failed]];
  append[CoreRunFolder[dir], <|"kind" -> "outcome", "change" -> change, "result" -> r, "outcome" -> outcome, "date" -> today[]|>]];


(* ::Section:: *)
(*Reading*)


(* a line cut short (a writer that was stopped) costs that entry only: ReadList gives up on the whole file, so the text
   is cut before every Association, the next entry's included when no newline ended the cut one *)
readExprs[f_String] := Module[{r, txt},
  If[! FileExistsQ[f], Return[{}]];
  r = Quiet@ReadList[f];
  If[ListQ[r] && FreeQ[r, $Failed, {1}], Return[r]];
  txt = Quiet@ReadString[f];
  If[! StringQ[txt], {}, Quiet@Check[ToExpression[#], $Failed] & /@ StringCases[txt, RegularExpression["<\\|\"(?:(?!<\\|\")[\\s\\S])*"]]]];

normEntry[e_Association] := Switch[Lookup[e, "kind", None],
  "tool", If[StringQ[Lookup[e, "tool", None]],
    Join[e, <|"tool" -> Replace[CoreToolKey[e["tool"]], $Failed -> e["tool"]], "sector" -> normSector[Lookup[e, "sector", "whole run"]],
      "step" -> Replace[Lookup[e, "step", ""], Except[_String] -> ""]|>], $Failed],
  "paper", If[StringQ[Lookup[e, "reference", None]] && StringQ[Lookup[e, "used", None]],
    Join[e, <|"id" -> CorePaperId[e["reference"]], "sector" -> normSector[Lookup[e, "sector", "whole run"]], "result" -> normResult[Lookup[e, "result", "used"]]|>], $Failed],
  "outcome", If[KeyExistsQ[e, "change"] && StringQ[Lookup[e, "result", None]], Join[e, <|"result" -> normResult[e["result"]]|>], $Failed],
  _, $Failed];
normEntry[_] := $Failed;

CoreReadCitations::bad = "`1` of the entries of `2` could not be read and were left out (a line cut short?).";
ledger[run_String] := Module[{raw = readExprs[ledgerFile[run]], es},
  es = normEntry /@ raw;
  If[MemberQ[es, $Failed], Message[CoreReadCitations::bad, Count[es, $Failed], ledgerFile[run]]];
  DeleteCases[es, $Failed]];

(* what a file is now: a date has whole seconds, so a file written in the last two seconds is told apart by its content *)
fileStamp[f_String] := If[! FileExistsQ[f], {f, None}, With[{t = AbsoluteTime[FileDate[f]], n = FileByteCount[f]},
  {f, t, n, If[AbsoluteTime[] - t < 2, FileHash[f, "MD5"], None]}]];

(* basis.m, state.m and the jobs' files are read once per version *)
basisInfo[f_String] := basisInfo[f, fileStamp[f]];
basisInfo[f_String, stamp_] := basisInfo[f, stamp] = Module[{rec = Quiet@Get[f]},
  If[! AssociationQ[rec], <|"tools" -> None, "key" -> Missing["NoBasis"]|>,
    <|"tools" -> If[KeyExistsQ[rec, "toolsUsed"] || KeyExistsQ[rec, "citations"], olderTools[Lookup[rec, "toolsUsed", {}], Lookup[rec, "citations", {}]], None],
      "key" -> CoreBasisKey[rec]|>]];

(* a basis.m: its toolsUsed, and the method papers its citations name. An older record cited them always (its
   "Method"); a newer one only where they were applied, so the citation text decides, never their absence *)
olderTools[tu_, cites_] := Module[{ts = Flatten[Replace[Select[Flatten[{tu}], StringQ], "Method" -> {"Baikov", "CanonicalDE"}, {1}]],
    ids = Union @@ (paperIds /@ Select[Flatten[{cites}], StringQ])},
  DeleteDuplicates[Join[ts,
    If[IntersectingQ[ids, {"hep-ph/9611449", "1701.07356"}], {"Baikov"}, {}],
    If[MemberQ[ids, "1304.1806"], {"CanonicalDE"}, {}]]]];

(* the outcomes an older literature.m wrote as text: "eps-form, not adopted", "rejected, change 3"; what is left of the
   text once the result is read stays the outcome *)
olderOutcome[o_String] := With[{t = StringTrim[StringTrim[o], "."]}, Which[
  StringMatchQ[t, RegularExpression["(rejected|pending|accepted|declined|not tried), change \\d+"]],
    With[{p = StringSplit[t, ", change "]}, <|"result" -> p[[1]], "change" -> ToExpression[p[[2]]], "outcome" -> ""|>],
  StringMatchQ[t, RegularExpression["(.*,\\s*)?not adopted"]], <|"result" -> "not adopted", "outcome" -> StringTrim[StringTrim[StringDrop[t, -11]], ","]|>,
  StringMatchQ[t, RegularExpression["(.*,\\s*)?adopted"]], <|"result" -> "adopted", "outcome" -> StringTrim[StringTrim[StringDrop[t, -7]], ","]|>,
  True, <||>]];
olderOutcome[_] := <||>;

(* an older pole-free reduction job credited its tools in its status.m only: "Tools", or before that "Reducers" (the
   reducer of each point); every job generated its identities with LiteRed and LiteIBP. The sector and step are those
   the job writes in the ledger now (pole-free-basis lib/PFB/JobCitations.wl) *)
jobFam[f_Symbol] := SymbolName[f];
jobFam[f_] := ToString[f];
jobSector[job_] := With[{k = Lookup[job, "SectorKey", None]},
  If[MatchQ[k, {_, {(0 | 1) ..}}], jobFam[k[[1]]] <> "/j" <> StringJoin[ToString /@ k[[2]]], "whole run"]];
jobStep[job_, d_] := Which[
    TrueQ[Lookup[job, "LearnOnly", False]], "learn-only job ",
    AssociationQ[Lookup[job, "Analytic", None]], "analytic job ",
    AssociationQ[Lookup[job, "Degrees", None]], "degree job ",
    AssociationQ[Lookup[job, "Line", None]], "line job ",
    True, "reduction job "] <> ToString[Lookup[job, "Name", FileNameTake[d]]];
jobEntries[d_String] := With[{s = FileNameJoin[{d, "status.m"}], j = FileNameJoin[{d, "job.m"}]},
  If[FileExistsQ[s], jobInfo[d, fileStamp[s], fileStamp[j]], {}]];
jobInfo[d_String, ss_, js_] := jobInfo[d, ss, js] = Module[{st = Quiet@Get[ss[[1]]], job, tools},
  job = Replace[If[js[[2]] === None, <||>, Quiet@Get[js[[1]]]], Except[_Association] -> <||>];
  tools = Which[! AssociationQ[st], {},
    ListQ[Lookup[st, "Tools", None]], Select[st["Tools"], StringQ],
    ListQ[Lookup[st, "Reducers", None]], Join[{"LiteRed", "LiteIBP"},
      Flatten[Replace[st["Reducers"], {"Kira" -> {"kira", "fer64"}, "FiniteFlow" -> {"FiniteFlow"}, _ -> {}}, {1}]]],
    (* neither: what the status says ran (bin/subtree.wls). A job still running or failed cannot tell what it produced *)
    MemberQ[{"done", "learned", "nonut", "nonut-hosts"}, Lookup[st, "Status", None]], {"LiteRed", "LiteIBP", "FiniteFlow"},
    Lookup[st, "Status", None] === "refused", {"LiteRed", "LiteIBP"},
    True, {}];
  <|"kind" -> "tool", "tool" -> #, "sector" -> jobSector[job], "step" -> jobStep[job, d], "date" -> day[ss[[1]]]|> & /@ DeleteDuplicates[tools]];

olderRecords[run_String, ledgerTools_List] := Module[{lit, have, tools},
  lit = Join[<|"kind" -> "paper"|>, #, <|"result" -> "used"|>, olderOutcome[Lookup[#, "outcome", None]]] & /@
    Select[readExprs[FileNameJoin[{run, "literature.m"}]], AssociationQ[#] && StringQ[Lookup[#, "reference", None]] && StringQ[Lookup[#, "used", None]] &];
  tools = Join[
    Flatten[Table[With[{f = FileNameJoin[{d, "basis.m"}], s = FileNameTake[d]},
        If[! FileExistsQ[f], {}, With[{ts = basisInfo[f]["tools"]},
          If[ts === None, {}, <|"kind" -> "tool", "tool" -> #, "sector" -> s, "step" -> "earlier run", "date" -> day[f]|> & /@ ts]]]],
      {d, Select[FileNames["j*", run], DirectoryQ[#] && MCBSectorFolderQ[#] &]}]],
    If[FileExistsQ[FileNameJoin[{run, "state.m"}]], Flatten[jobEntries /@ Select[FileNames["*", FileNameJoin[{run, "jobs"}]], DirectoryQ]], {}]];
  (* a tool the run's ledger already credits to a sector, by a use of its own (not an import), needs no line of an
     older record there *)
  have = Lookup[Select[ledgerTools, NoneTrue[{"via", "basisKey", "change", "start"}, Function[k, KeyExistsQ[#, k]]] &], {"tool", "sector"}];
  Join[normEntry /@ lit, Select[normEntry /@ tools, ! MemberQ[have, {#["tool"], #["sector"]}] &]]];

(* the changes of a pole-free run (state.m): ids, the masters accepted changes replaced, and whether the starting
   slice was built by the skill (bin/local_slice.wls) *)
stateOf[run_String] := With[{f = FileNameJoin[{run, "state.m"}]}, If[FileExistsQ[f], stateIds[f, fileStamp[f]], None]];
stateIds[f_String, stamp_] := stateIds[f, stamp] = With[{st = Quiet@Get[f]},
  If[! AssociationQ[st], None, With[{acc = Select[Lookup[st, "Accepted", {}], AssociationQ]},
    <|"Accepted" -> idsIn[st, "Accepted"], "Pending" -> idsIn[st, "Pending"],
      "Rejected" -> (Join[KeyTake[#, {"Declined", "DeclineReason"}], <|"Id" -> ToString[Lookup[#, "Id", None]]|>] & /@ Select[Lookup[st, "Rejected", {}], AssociationQ]),
      "Replaced" -> (ToString /@ Union[Flatten[{Lookup[#, "Replace", {}], Keys[Replace[Lookup[#, "NewDefs", <||>], Except[_Association] -> <||>]]} & /@
          Select[acc, ! CoreRescaleChangeQ[#] &]]]),
      "LocalStart" -> With[{sl = Select[Lookup[st, "Slices", {}], AssociationQ]}, sl =!= {} && StringQ[Lookup[First[sl], "Label", None]] &&
          StringStartsQ[First[sl]["Label"], "local slice"]]|>]]];
idsIn[st_, key_] := ToString /@ DeleteCases[Lookup[Select[Lookup[st, key, {}], AssociationQ], "Id", None], None];
CoreRescaleChangeQ[a_Association] := Lookup[a, "Kind", None] === "rescale" ||
   Lookup[Replace[Lookup[a, "Simplify", <||>], Except[_Association] -> <||>], "Move", None] === "rescale";
CoreRescaleChangeQ[_] := False;

(* the same use written twice, a final period apart, is one use; an imported entry is told by what it went into *)
entryKey[e_] := Switch[e["kind"],
  "tool", {"tool", Lookup[e, {"tool", "sector", "step", "via", "basisKey", "change", "start", "result", "outcome"}, None]},
  "paper", {"paper", MapAt[StringTrim[StringTrim[#], "."] &, Lookup[e, {"id", "sector", "used", "rung", "result", "outcome", "change", "basisKey", "via", "start"}, None], 3]},
  _, {e["kind"], e}];

(* the tools a run ran itself are always cited; a paper, and an entry imported for a basis, a change or starting
   masters, by the final-result rule *)
stampedQ[e_] := e["kind"] === "paper" || AnyTrue[{"basisKey", "change", "start"}, KeyExistsQ[e, #] &] || MemberQ[$consultedResults, Lookup[e, "result", None]];

(* the final-result rule: consulted when rejected, declined, not adopted or not tried; when its basis is no longer the
   sector's basis.m; when its change is neither accepted nor pending; when accepted changes replaced every starting
   master it went into. Anything that cannot be told is cited *)
resolve[e_Association, keyOf_, st_] := Module[{r = Lookup[e, "result", None], paper = e["kind"] === "paper", ck = None, ch, rej, o, declined},
  o = StringTrim[Replace[Lookup[e, "outcome", ""], Except[_String] -> ""]];
  If[StringQ[Lookup[e, "basisKey", None]], ck = keyOf[e["sector"]]];
  Which[
    (* not adopted when the sector checked it, but its basis is the sector's basis now *)
    paper && ! KeyExistsQ[e, "via"] && r === "not adopted" && StringQ[ck] && ck === e["basisKey"],
      Join[e, <|"result" -> "adopted", "outcome" -> "its basis is the sector's final basis", "part" -> "cite"|>],
    MemberQ[$consultedResults, r], Append[e, "part" -> "consulted"],
    StringQ[ck] && ck =!= e["basisKey"], Join[e, <|"outcome" -> "replaced by a later basis", "part" -> "consulted"|>],
    KeyExistsQ[e, "change"] && AssociationQ[st],
      ch = ToString[e["change"]];
      Which[
        MemberQ[st["Pending"], ch], Join[e, If[paper, <|"result" -> "pending"|>, <|"outcome" -> "pending"|>], <|"part" -> "cite"|>],
        MemberQ[st["Accepted"], ch], Join[e, If[paper && MemberQ[{"used", "pending"}, r], <|"result" -> "accepted"|>, <||>], <|"part" -> "cite"|>],
        True,
          rej = SelectFirst[st["Rejected"], #["Id"] === ch &, None];
          declined = AssociationQ[rej] && KeyExistsQ[rej, "Declined"];
          Join[e, Which[
              paper, Join[If[AssociationQ[rej], <|"result" -> If[declined, "declined", "rejected"]|>, <||>], If[o =!= "", <||>,
                <|"outcome" -> If[declined && StringQ[Lookup[rej, "DeclineReason", None]], rej["DeclineReason"], "change " <> ch <> " is not in the final basis"]|>]],
              AssociationQ[rej], <|"outcome" -> "change " <> ch <> If[declined, " declined" <> If[StringQ[Lookup[rej, "DeclineReason", None]], " (" <> rej["DeclineReason"] <> ")", ""], " rejected"]|>,
              True, <|"outcome" -> "change " <> ch <> " is not in the final basis"|>],
            <|"part" -> "consulted"|>]],
    ListQ[Lookup[e, "start", None]] && e["start"] =!= {} && AssociationQ[st] && SubsetQ[st["Replaced"], ToString /@ e["start"]],
      Join[e, <|"outcome" -> "accepted changes replaced every starting master it went into", "part" -> "consulted"|>],
    True, Append[e, "part" -> "cite"]]];

readCitations[run_String] := Module[{es, outs, st, keyOf, ps},
  es = ledger[run];
  es = Join[olderRecords[run, Select[es, #["kind"] === "tool" &]], es];
  (* the latest outcome of each change, for the run's own papers; an imported copy follows its change through state.m,
     and keeps the source's verdict *)
  outs = Association[(ToString[#["change"]] -> #) & /@ Select[es, #["kind"] === "outcome" &]];
  es = Select[es, MemberQ[{"tool", "paper"}, #["kind"]] &];
  es = Map[If[#["kind"] === "paper" && ! KeyExistsQ[#, "via"] && KeyExistsQ[#, "change"] && KeyExistsQ[outs, ToString[#["change"]]],
      With[{o = outs[ToString[#["change"]]]}, Join[#, <|"result" -> o["result"]|>,
        If[StringQ[Lookup[o, "outcome", None]] && StringTrim[o["outcome"]] =!= "", <|"outcome" -> o["outcome"]|>, <||>]]], #] &, es];
  ps = Flatten[Position[Lookup[es, "kind", None], "paper"]];
  If[ps =!= {}, es[[ps]] = sharedIds[es[[ps]]]];
  st = stateOf[run];
  keyOf[s_String] := keyOf[s] = With[{f = FileNameJoin[Join[{run}, StringSplit[s, "/"], {"basis.m"}]]},
    If[StringMatchQ[s, RegularExpression["([^/]+/)?j[01]+"]] && FileExistsQ[f], basisInfo[f]["key"], Missing["NoBasis"]]];
  es = If[stampedQ[#], resolve[#, keyOf, st], Append[#, "part" -> "cite"]] & /@ es;
  DeleteDuplicatesBy[es, entryKey]];

(* every file the reader reads, as it is now: the pages read the ledger once per sector, and a report stays linear *)
signature[run_String] := Module[{dirs = Select[FileNames["*", run], DirectoryQ], secs, jobs},
  secs = Select[Join[dirs, Flatten[FileNames["j*", #] & /@ Select[dirs, ! MCBSectorFolderQ[#] &]]], MCBSectorFolderQ[#] && DirectoryQ[#] &];
  jobs = If[FileExistsQ[FileNameJoin[{run, "state.m"}]], Select[FileNames["*", FileNameJoin[{run, "jobs"}]], DirectoryQ], {}];
  fileStamp /@ Join[{ledgerFile[run], FileNameJoin[{run, "literature.m"}], FileNameJoin[{run, "state.m"}]}, FileNameJoin[{#, "basis.m"}] & /@ secs,
    Flatten[{FileNameJoin[{#, "status.m"}], FileNameJoin[{#, "job.m"}]} & /@ jobs]]];

$readCache = <||>;
CoreReadCitations[runDir_String] := Module[{run = CoreRunFolder[runDir], sig},
  sig = signature[run];
  If[! MatchQ[Lookup[$readCache, run, None], {s_, _} /; s === sig], $readCache[run] = {sig, readCitations[run]}];
  $readCache[run][[2]]];

(* the whole-run entries that name the sector belong to its page too *)
namesSectorQ[e_, s_String] := AnyTrue[Lookup[e, {"used", "step", "outcome"}, None], StringQ[#] && StringContainsQ[#, WordBoundary ~~ s ~~ WordBoundary] &];

CoreSectorCitations[runDir_String, sector_String] := Module[{s = normSector[sector], es},
  es = Select[CoreReadCitations[runDir], #["sector"] === s || (s =!= "whole run" && #["sector"] === "whole run" && namesSectorQ[#, s]) &];
  <|"tools" -> Select[es, #["kind"] === "tool" &], "papers" -> Select[es, #["kind"] === "paper" &]|>];

Options[CoreImportCitations] = {"BasisKey" -> None, "Change" -> None, "Start" -> False};
CoreImportCitations[toDir_String, fromRunDir_String, fromSectors_, toSector_String, via_String, OptionsPattern[]] := Module[{to = CoreRunFolder[toDir],
    ss = normSector /@ Flatten[{fromSectors}], s = normSector[toSector], stamp, src, have, new},
  (* what the copies went into here: this run's basis, change or starting masters, never the source's *)
  stamp = Join[If[StringQ[OptionValue["BasisKey"]], <|"basisKey" -> OptionValue["BasisKey"]|>, <||>],
    If[MatchQ[OptionValue["Change"], None | False], <||>, <|"change" -> OptionValue["Change"]|>],
    Switch[OptionValue["Start"], True, <|"start" -> True|>, {__}, <|"start" -> OptionValue["Start"]|>, _, <||>]];
  src = Select[CoreReadCitations[fromRunDir], MemberQ[ss, #["sector"]] &];
  (* a copy carries its own reference's id (the reader shares ids again in this run), so that both sides compare alike *)
  new = Table[With[{out = e["part"] === "consulted" && ! MemberQ[$consultedResults, Lookup[e, "result", None]]},
      Join[KeyDrop[e, Join[{"part", "basisKey", "change", "start"}, If[e["kind"] === "tool" && ! out, {"outcome"}, {}]]],
        If[e["kind"] === "paper", <|"id" -> CorePaperId[e["reference"]]|>, <||>],
        <|"sector" -> s, "via" -> If[StringQ[Lookup[e, "via", None]], via <> "; " <> e["via"], via]|>, If[out, <|"result" -> "not adopted"|>, <||>], stamp]],
    {e, src}];
  have = entryKey /@ ledger[to];
  new = Select[DeleteDuplicatesBy[new, entryKey], ! MemberQ[have, entryKey[#]] &];
  append[to, #] & /@ new];


(* ::Section:: *)
(*CITATIONS.md*)


title[t_] := Lookup[Lookup[$MCBTools, t, <||>], "Name", t];
kindOf[t_] := Lookup[Lookup[$MCBTools, t, <||>], "Kind", Missing["NotInRegistry"]];
registryIndex[t_] := Replace[FirstPosition[Keys[$MCBTools], t, {Infinity}], {i_} :> i];
sortSectors[ss_List] := Join[Sort[DeleteCases[ss, "whole run"]], If[MemberQ[ss, "whole run"], {"whole run"}, {}]];
citedQ[uses_List] := AnyTrue[uses, Lookup[#, "part", "cite"] === "cite" &];

groups[es_List] := Module[{tools = Select[es, #["kind"] === "tool" &], papers = Select[es, #["kind"] === "paper" &], names, byTool, owner, pg, tg},
  names = SortBy[DeleteDuplicates[Lookup[tools, "tool", {}]], {registryIndex[#], #} &];
  byTool = Association[Table[t -> <|"name" -> t, "title" -> title[t], "kind" -> kindOf[t], "citation" -> Lookup[Lookup[$MCBTools, t, <||>], "Citation", None],
       "uses" -> Select[tools, #["tool"] === t &], "papers" -> {}|>, {t, names}]];
  (* a recorded paper that a cited tool or method already cites (any id they share) is shown once, under it *)
  owner[ids_] := SelectFirst[names, citedQ[byTool[#]["uses"]] && IntersectingQ[paperIds[byTool[#]["citation"]], ids] &, None];
  pg = KeyValueMap[<|"id" -> #1, "uses" -> #2, "owner" -> owner[Union[{#1}, Flatten[linkedIds /@ Lookup[#2, "reference"]]]]|> &, GroupBy[papers, #["id"] &]];
  Scan[If[#["owner"] =!= None, byTool[[#["owner"], "papers"]] = Join[byTool[[#["owner"], "papers"]], #["uses"]]] &, pg];
  pg = <|"id" -> #["id"], "reference" -> First[MaximalBy[Lookup[#["uses"], "reference"], StringLength]], "uses" -> #["uses"]|> & /@ Select[pg, #["owner"] === None &];
  tg = Values[byTool];
  <|"tools" -> Select[tg, #["kind"] =!= "method" && citedQ[#["uses"]] &], "methods" -> Select[tg, #["kind"] === "method" && citedQ[#["uses"]] &],
    "consultedTools" -> Select[tg, ! citedQ[#["uses"]] &],
    "papers" -> Select[pg, citedQ[#["uses"]] &], "consulted" -> Select[pg, ! citedQ[#["uses"]] &]|>];

CoreCitationGroups[runDir_String] := groups[CoreReadCitations[runDir]];

rungText[e_] := With[{r = Lookup[e, "rung", None]}, Which[r === None || MissingQ[r], None, StringQ[r], r, True, "rung " <> ToString[r]]];
outcomeText[e_] := Module[{r = Lookup[e, "result", "used"], o = Replace[Lookup[e, "outcome", ""], Except[_String] -> ""]},
  o = StringTrim[StringTrim[o], "."];
  Which[r === "used", o, o === "", r, StringStartsQ[o, r], o, True, r <> " (" <> o <> ")"]];

(* "j0111, j1111 (first pass, check_basis), whole run (find_masters)": sectors with the same steps share a group; a use
   not in the final result says why *)
notesOf[e_] := DeleteCases[{Lookup[e, "step", ""], Lookup[e, "via", ""],
    Which[Lookup[e, "part", "cite"] === "consulted", outcomeText[e], Lookup[e, "outcome", ""] === "pending", "pending", True, ""]}, "" | _Missing];
sectorsText[uses_List] := Module[{by = GroupBy[uses, (#["sector"] &) -> notesOf, Union @@ # &]},
  StringRiffle[KeyValueMap[StringRiffle[#2, ", "] <> If[#1 === {}, "", " (" <> StringRiffle[#1, ", "] <> ")"] &,
    GroupBy[sortSectors[Keys[by]], by]], ", "]];

useLine[e_] := With[{p = DeleteCases[{rungText[e], If[KeyExistsQ[e, "change"], "change " <> ToString[e["change"]], None], Lookup[e, "via", None]}, None | _Missing],
    o = outcomeText[e]},
  StringJoin[e["sector"], If[p === {}, "", " (" <> StringRiffle[p, ", "] <> ")"], If[StringQ[Lookup[e, "date", None]], ", " <> e["date"], ""], ": ",
    StringTrim[StringTrim[e["used"]], "."], ".", If[o === "", "", " Outcome: " <> o <> "."]]];

citationText[t_] := Which[StringQ[t["citation"]], StringTrim[StringTrim[t["citation"]], "."] <> ".",
  MissingQ[t["kind"]], "not in the registry of the skill: find its reference and cite it yourself.", True, "no reference of its own."];
toolBlock[t_] := StringJoin["- **", t["title"], "**: ", citationText[t], " Sectors: ", sectorsText[t["uses"]], ".\n",
  ("  - " <> useLine[#] <> "\n") & /@ t["papers"]];
paperBlock[p_] := StringJoin["- ", p["reference"], "\n", ("  - " <> useLine[#] <> "\n") & /@ p["uses"]];

citeMarkdown[g_] := StringJoin[
  If[g["tools"] =!= {}, "### Tools\n\n" <> StringJoin[toolBlock /@ g["tools"]] <> "\n", ""],
  If[g["methods"] =!= {}, "### Methods\n\n" <> StringJoin[toolBlock /@ g["methods"]] <> "\n", ""],
  If[g["papers"] =!= {}, "### Papers\n\n" <> StringJoin[paperBlock /@ g["papers"]] <> "\n", ""]];

CoreCiteMarkdown[runDir_String] := With[{es = CoreReadCitations[runDir]}, If[es === {}, "", citeMarkdown[groups[es]]]];

(* a pole-free run: where its starting DE came from (state.m: the label of its first slice) *)
startNote[run_String] := Which[
  ! FileExistsQ[FileNameJoin[{run, "state.m"}]], "",
  TrueQ[Lookup[Replace[stateOf[run], Except[_Association] -> <||>], "LocalStart", False]],
    "## Not covered by this file\n\nThe starting differential equation was built inside the skill, from its own reductions (a local\n" <>
    "slice); the tools of those reductions are credited above.\n",
  True, "## Not covered by this file\n\nThe starting differential equation came from outside the skill. The tools and papers that produced it\n" <>
    "are listed above only when its conventions.wl names them (\"Credits\", for the whole run); otherwise cite them\nyourself.\n"];

citationsMarkdown[g_, note_String] := StringJoin[
  "# Citations for this run\n\n",
  "Cite the tools and papers under \"Cite\" when you use results of this run, and acknowledge the authors of the\n",
  "papers. Each entry says which sectors used it and how. The tool references were checked against INSPIRE, arXiv\n",
  "and CrossRef; the papers were recorded by the agent from arXiv or INSPIRE.\n\n",
  "## Cite\n\n", Replace[citeMarkdown[g], "" -> "Nothing to cite: everything recorded was only consulted.\n\n"],
  If[g["consulted"] === {} && g["consultedTools"] === {}, "",
    "## Also consulted (not in the final result)\n\n" <> StringJoin[toolBlock /@ g["consultedTools"]] <> StringJoin[paperBlock /@ g["consulted"]] <> "\n"],
  note];

CoreWriteCitations[runDir_String] := Module[{run = CoreRunFolder[runDir], es, f, old},
  es = CoreReadCitations[run];
  If[es === {}, Return[Missing["NoCitations"]]];
  f = FileNameJoin[{run, "CITATIONS.md"}];
  Export[f, citationsMarkdown[groups[es], startNote[run]], "Text"];
  (* the file this one replaces, when it is the skill's own *)
  old = FileNameJoin[{run, "LITERATURE.md"}];
  If[FileExistsQ[old] && MatchQ[Quiet@ReadList[old, String, 1], {l_String /; StringTrim[l] === "# Literature used in this run"}], DeleteFile[old]];
  f];

MCBWriteLiterature[runDir_String] := CoreWriteCitations[runDir];
MCBReadLiterature[runDir_String] := Select[CoreReadCitations[runDir], #["kind"] === "paper" &];


(* ::Section:: *)
(*Page blocks*)


toolItem[t_] := "<li><b>" <> esc[t["title"]] <> "</b>: " <> esc[citationText[t]] <> " <span class='muted'>(" <> esc[sectorsText[t["uses"]]] <> ")</span>" <>
  If[t["papers"] === {}, "", CoreLiteratureList[t["papers"]]] <> "</li>";
paperItem[p_] := "<li>" <> esc[p["reference"]] <> " <span class='muted'>(" <> esc[StringRiffle[
    DeleteDuplicates[With[{o = outcomeText[#]}, #["sector"] <> If[o === "" || #["part"] === "cite", "", ": " <> o]] & /@ p["uses"]], "; "]] <> ")</span></li>";
section[head_, items_List, f_] := If[items === {}, "", "<h3>" <> head <> "</h3><ul class='tight'>" <> StringJoin[f /@ items] <> "</ul>"];

CoreCitationsHTML[runDir_String] := Module[{es = CoreReadCitations[runDir], g},
  If[es === {}, Return[""]];
  g = groups[es];
  StringJoin["<h2>Cite &mdash; the tools, methods and papers behind this run</h2>",
    section["Tools", g["tools"], toolItem], section["Methods", g["methods"], toolItem], section["Papers", g["papers"], paperItem],
    If[g["papers"] === {} && g["tools"] === {} && g["methods"] === {}, "<p class='muted'>Nothing to cite: everything recorded was only consulted.</p>", ""],
    If[g["consulted"] === {} && g["consultedTools"] === {}, "", "<h2>Also consulted (not in the final result)</h2><ul class='tight'>" <>
      StringJoin[toolItem /@ g["consultedTools"]] <> StringJoin[paperItem /@ g["consulted"]] <> "</ul>"],
    "<p class='muted'>Which sector used each one, and how: <code>CITATIONS.md</code>.</p>"]];

CoreSectorCitationsHTML[runDir_String, sector_String] := Module[{sc = CoreSectorCitations[runDir, sector], tools, item},
  If[sc["tools"] === {} && sc["papers"] === {}, Return[""]];
  tools = groups[sc["tools"]];
  item[t_] := "<li><b>" <> esc[t["title"]] <> "</b>: " <> esc[citationText[t]] <> " <span class='muted'>(" <>
    esc[StringRiffle[DeleteDuplicates[Flatten[notesOf /@ t["uses"]]], ", "]] <> ")</span></li>";
  StringJoin[
    With[{c = Join[tools["tools"], tools["methods"]]}, If[c === {}, "",
      "<p class='muted'>Tools and methods used for this sector &mdash; please cite:</p><ul class='tight'>" <> StringJoin[item /@ c] <> "</ul>"]],
    With[{c = Select[sc["papers"], #["part"] === "cite" &]}, If[c === {}, "",
      "<p class='muted'>Papers used for this sector &mdash; please acknowledge:</p>" <> CoreLiteratureList[c]]],
    With[{c = Select[sc["papers"], #["part"] === "consulted" &]}, If[c === {} && tools["consultedTools"] === {}, "",
      "<p class='muted'>Consulted for this sector, not in its final result:</p>" <>
        If[tools["consultedTools"] === {}, "", "<ul class='tight'>" <> StringJoin[item /@ tools["consultedTools"]] <> "</ul>"] <> CoreLiteratureList[c]]],
    "<p class='muted'>Every tool and paper of the run: <code>CITATIONS.md</code>.</p>"]];

CoreLiteratureList[es_List] := If[es === {}, "",
  "<ul class='tight'>" <> StringJoin[Table[With[{o = outcomeText[e]}, "<li>" <> esc[e["reference"]] <> " &mdash; " <> esc[e["used"]] <>
       If[o === "", "", " <span class='muted'>(" <> esc[o] <> ")</span>"] <> "</li>"], {e, es}]] <> "</ul>"];

CoreLiteratureSummary[runDir_String] := (CoreWriteCitations[runDir]; CoreCitationsHTML[runDir]);


End[];
EndPackage[];
