#!/usr/bin/env wolframscript
(* Create a sector folder with a readable AnalysisMasters.m to work on by hand.
   usage: new_sector.wls run.wl|family.wl j0101...|kira-id [--overwrite] *)
Get[FileNameJoin[{ParentDirectory[DirectoryName[$InputFileName]], "lib", "MaximalCutBasis.wl"}]];

Module[{args, dir, f, fam, s, setup},
args = Rest[$ScriptCommandLine];
If[Length[args] < 2, Print["usage: new_sector.wls run.wl|family.wl j0101...|id [--overwrite]"]; CoreVerdict["new_sector", "usage"]];
setup = MCBRunSetup[args[[1]]];
If[setup === $Failed, CoreVerdict["new_sector", "usage", <|"message" -> "no run found for " <> First[args]|>]];
fam = setup["fam"];
s = If[StringStartsQ[args[[2]], "j"], SectorFromName[args[[2]]], SectorFromName[ToExpression[args[[2]]], fam["N"]]];
dir = MCBSectorDir[setup["dir"], s];
f = MCBWriteAnalysisScript[fam, s, dir, <|"FamilyFile" -> setup["run"]["Family"], "PathsFile" -> setup["paths"],
   "Overwrite" -> MemberQ[args, "--overwrite"], "Seed" -> setup["run"]["Seed"]|>];
CoreVerdict["new_sector", "pass", <|"script" -> f|>]
];
