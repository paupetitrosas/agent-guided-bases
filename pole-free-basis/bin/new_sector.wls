#!/usr/bin/env wolframscript
(* Write <run folder>/<fam>/<jPATTERN>/AnalysisPoles.m from templates/AnalysisPoles.m, for the agent to edit.
   usage: new_sector.wls run.wl fam/jPATTERN [--force]   (an edited script is never overwritten without --force) *)
Get[FileNameJoin[{ParentDirectory[DirectoryName[$InputFileName]], "lib", "PoleFreeBasis.wl"}]];

Module[{a = Rest[$ScriptCommandLine], st, key, sd, f, t},
If[Length[a] < 2, Print["usage: new_sector.wls run.wl fam/jPATTERN [--force]"]; CoreVerdict["new_sector", "usage"]];
st = PFBStartRun[a[[1]]]; If[st === $Failed, CoreVerdict["new_sector", "usage", <|"message" -> "no run found for " <> ToString[a[[1]]]|>]];
key = With[{p = StringSplit[a[[2]], "/"]}, {ToExpression[p[[1]]], SectorFromName[p[[2]]]}];
If[! MemberQ[PFBSectorKeys[st["System"]], key], Print["no masters in ", a[[2]]]; CoreVerdict["new_sector", "usage", <|"message" -> "no masters in " <> a[[2]]|>]];
sd = PFBSectorDir[st["Dir"], key];
If[! DirectoryQ[sd], CreateDirectory[sd, CreateIntermediateDirectories -> True]];
f = FileNameJoin[{sd, "AnalysisPoles.m"}];
If[FileExistsQ[f] && ! MemberQ[a, "--force"], Print[f, " exists; pass --force to overwrite it"]; CoreVerdict["new_sector", "usage", <|"message" -> f <> " exists; pass --force to overwrite it"|>]];
t = Import[FileNameJoin[{$PFBRoot, "templates", "AnalysisPoles.m"}], "Text"];
t = StringReplace[t, {"{{SECTOR}}" -> PFBSectorString[key], "{{DATE}}" -> PFBTimeStamp[], "{{WS}}" -> FileNameJoin[{$PFBRoot, "bin", "ws"}],
    "{{LIBFILE}}" -> FileNameJoin[{$PFBRoot, "lib", "PoleFreeBasis.wl"}], "{{RUNFILE}}" -> st["Run"]["File"],
    "{{FAMILY}}" -> ToString[key[[1]]], "{{SECTORLIST}}" -> ToString[key[[2]]], "{{JOBNAME}}" -> StringReplace[PFBSectorString[key], "/" -> "_"]}];
Export[f, t, "Text"];
CoreVerdict["new_sector", "pass", <|"script" -> f|>]];
