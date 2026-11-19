#!/usr/bin/env wolframscript
(* Sector records and pages, summary.html, export/ (the new masters files), CHANGES.md and CITATIONS.md (what to cite,
   from the run's ledger citations.m) of a run.
   usage: make_reports.wls run.wl *)
Get[FileNameJoin[{ParentDirectory[DirectoryName[$InputFileName]], "lib", "PoleFreeBasis.wl"}]];

Module[{st = PFBStartRun[$ScriptCommandLine[[2]]], f},
If[st === $Failed, CoreVerdict["make_reports", "usage", <|"message" -> "no run found"|>]];
f = PFBMakeReports[st["Dir"], st["System"], st["State"]];
CoreVerdict["make_reports", "pass", <|"summary" -> f, "changes" -> FileNameJoin[{st["Dir"], "CHANGES.md"}],
  "citations" -> If[FileExistsQ[FileNameJoin[{st["Dir"], "CITATIONS.md"}]], FileNameJoin[{st["Dir"], "CITATIONS.md"}], Null]|>]];
