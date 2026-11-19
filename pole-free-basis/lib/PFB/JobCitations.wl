(* ::Package:: *)

(* ::Title:: *)
(*PoleFreeBasis`JobCitations`: the lines a reduction job appends to its run's ledger of tools (citations.m)*)


(* ::Text:: *)
(*Self-contained: bin/subtree.wls loads this file without the rest of the toolkit (it runs in its own kernel, without*)
(*the skills' core). A job credits the tools that produced a result when the result is written: LiteRed and LiteIBP*)
(*(the families' sector maps, the derivatives, the identities), FiniteFlow for a point it reduced and for what its*)
(*learned system gave (learned masters, analytic coefficients, degrees, a line), Kira and Fermat for a point whose*)
(*reduction by Kira was written (not a point FiniteFlow reduced instead). Each line is an Association in the format of*)
(*the core's ledger (core/lib/Core/Citations.wl), appended with PutAppend to <run>/citations.m, the job folder being*)
(*<run>/jobs/<name> of a pole-free run (state.m); the readers dedupe, so a job run again appends its lines again*)
(*without harm. A job elsewhere appends nothing: its status.m "Tools" keeps the record, which the reader takes once the*)
(*job is in a run's jobs folder.*)


BeginPackage["PoleFreeBasis`JobCitations`"];

PFBJobSector::usage = "PFBJobSector[job] is the sector a job's tools are credited to: its job.m \"SectorKey\" {fam, sector} written \"fam/jPATTERN\", else \"whole run\".";
PFBJobStep::usage = "PFBJobStep[job] is the step of a job's lines in the ledger: its kind and name, \"reduction job <name>\", or \"learn-only job\", \"analytic job\", \"degree job\", \"line job\" for those.";
PFBJobTools::usage = "PFBJobTools[what] lists the tools a job credits for what it produced: \"Kira\" (a point whose reduction by Kira was written: kira and fer64, with LiteRed and LiteIBP, whose sector maps and derivatives it used), \"FiniteFlow\" (a point FiniteFlow reduced, or what its learned system gave: learned masters, analytic coefficients, degrees, a line; with LiteRed and LiteIBP), \"Identities\" (identities generated: LiteRed and LiteIBP). {} for anything else.";
PFBJobCitationEntries::usage = "PFBJobCitationEntries[job, tools, date] are a job's lines of the ledger, one per tool: <|\"kind\" -> \"tool\", \"tool\", \"sector\" -> PFBJobSector[job], \"step\" -> PFBJobStep[job], \"date\" -> \"YYYY-MM-DD\"|> (date: today when omitted or Automatic).";
PFBJobRunFolder::usage = "PFBJobRunFolder[jobDir] is the run folder of a job folder <run>/jobs/<name> of a pole-free run (the run folder holds state.m), or None.";
PFBJobPreviousTools::usage = "PFBJobPreviousTools[jobDir] are the tools the job's earlier runs credited, from its status.m \"Tools\" ({} without one): a run starts from them, so that status.m keeps every run's credits (the only record of a job outside a run) and the ledger gets each tool once.";
PFBJobCredit::usage = "PFBJobCredit[jobDir, job, credited, what] credits what a job just wrote (PFBJobTools[what]: \"Kira\", \"FiniteFlow\", \"Identities\"): the tools not in credited are appended to the run's ledger (PFBAppendJobCitations, when the job is in a pole-free run). Returns credited with them, for status.m \"Tools\".";
PFBAppendJobCitations::usage = "PFBAppendJobCitations[jobDir, entries] appends the entries (PFBJobCitationEntries) to the ledger of the job's run, <run>/citations.m. Returns the file, or None (nothing written) when the job folder is not <run>/jobs/<name> of a pole-free run: its status.m \"Tools\" keeps the record.";

Begin["`Private`"];


today[] := DateString[{"Year", "-", "Month", "-", "Day"}];
(* job.m is read before the families are defined: a family's symbol may carry another context *)
famName[f_Symbol] := SymbolName[f];
famName[f_] := ToString[f];

PFBJobSector[job_Association] := With[{k = Lookup[job, "SectorKey", None]},
  If[MatchQ[k, {_, {(0 | 1) ..}}], famName[k[[1]]] <> "/j" <> StringJoin[ToString /@ k[[2]]], "whole run"]];

PFBJobStep[job_Association] := Which[
    TrueQ[Lookup[job, "LearnOnly", False]], "learn-only job ",
    AssociationQ[Lookup[job, "Analytic", None]], "analytic job ",
    AssociationQ[Lookup[job, "Degrees", None]], "degree job ",
    AssociationQ[Lookup[job, "Line", None]], "line job ",
    True, "reduction job "] <> ToString[Lookup[job, "Name", "?"]];

PFBJobTools["Kira"] = {"kira", "fer64", "LiteRed", "LiteIBP"};
PFBJobTools["FiniteFlow"] = {"FiniteFlow", "LiteRed", "LiteIBP"};
PFBJobTools["Identities"] = {"LiteRed", "LiteIBP"};
PFBJobTools[_] := {};

PFBJobCitationEntries[job_Association, tools_List, date_ : Automatic] := With[{s = PFBJobSector[job], st = PFBJobStep[job], d = Replace[date, Automatic :> today[]]},
  <|"kind" -> "tool", "tool" -> #, "sector" -> s, "step" -> st, "date" -> d|> & /@ DeleteDuplicates[tools]];

PFBJobRunFolder[jobDir_String] := With[{d = ExpandFileName[jobDir]},
  If[FileNameTake[FileNameDrop[d, -1]] === "jobs" && FileExistsQ[FileNameJoin[{FileNameDrop[d, -2], "state.m"}]], FileNameDrop[d, -2], None]];

PFBAppendJobCitations[jobDir_String, es_List] := With[{run = PFBJobRunFolder[jobDir]},
  If[run === None, None,
    Scan[PutAppend[#, FileNameJoin[{run, "citations.m"}]] &, es];
    FileNameJoin[{run, "citations.m"}]]];

PFBJobPreviousTools[jobDir_String] := With[{st = Quiet@Get[FileNameJoin[{jobDir, "status.m"}]]},
  If[AssociationQ[st] && ListQ[Lookup[st, "Tools", None]], DeleteDuplicates[Select[st["Tools"], StringQ]], {}]];

PFBJobCredit[jobDir_String, job_Association, credited_List, what_String] := With[{new = Select[PFBJobTools[what], ! MemberQ[credited, #] &]},
  If[new =!= {}, PFBAppendJobCitations[jobDir, PFBJobCitationEntries[job, new]]];
  Join[credited, new]];


End[];
EndPackage[];
