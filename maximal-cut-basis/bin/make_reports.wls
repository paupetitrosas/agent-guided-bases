#!/usr/bin/env wolframscript
(* basis.html for every sector folder (or the ones named) and summary.html, masters_all.m, CITATIONS.md (from the run's
   ledger, citations.m).
   usage: make_reports.wls <run folder>|run.wl [j0101... ...] *)
Get[FileNameJoin[{ParentDirectory[DirectoryName[$InputFileName]], "lib", "MaximalCutBasis.wl"}]];

Module[{args, d, dirs, fam, ff, names, rec, run, setup},
args = Rest[$ScriptCommandLine];
If[args === {}, Print["usage: make_reports.wls <run folder>|run.wl [sector ...]"]; CoreVerdict["make_reports", "usage"]];
setup = MCBRunSetup[First[args]];
If[setup === $Failed, CoreVerdict["make_reports", "usage", <|"message" -> "no run found for " <> First[args]|>]];
fam = setup["fam"]; run = setup["dir"];
names = Select[Rest[args], StringStartsQ[#, "j"] &];
dirs = If[names =!= {}, FileNameJoin[{run, #}] & /@ names,
   Select[FileNames["j*", run], DirectoryQ[#] && StringMatchQ[FileNameTake[#], RegularExpression["j[01]+"]] &]];
Do[
  If[! FileExistsQ[FileNameJoin[{d, "basis.m"}]], Continue[]];
  rec = MCBReadBasis[d];
  ff = MCBReadFFVerdict[d];
  If[AssociationQ[ff], rec["finiteflowVerdict"] = ff; MCBWriteBasis[d, rec]];
  MCBBasisHTML[d, fam],
  {d, dirs}];
(* summary.html writes CITATIONS.md with it *)
CoreVerdict["make_reports", "pass", <|"summary" -> MCBSummaryHTML[run, fam],
  "citations" -> If[FileExistsQ[FileNameJoin[{run, "CITATIONS.md"}]], FileNameJoin[{run, "CITATIONS.md"}], Missing["NoCitations"]]|>]
];
