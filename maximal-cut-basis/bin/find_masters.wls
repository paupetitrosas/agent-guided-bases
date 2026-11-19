#!/usr/bin/env wolframscript
(* Sectors to analyse: from the user's masters (family.wl "Masters"), else a numeric whole-family Kira run below the
   top sectors (family.wl "TopSectors", else the lines of "Graph", else every line).
   Writes sectors.txt in the run folder: name, Kira id, number of propagators, fewest propagators first; and geometry.m,
   the sectors that are an earlier one at mapped kinematics (MCBGeometryGroups).
   usage: find_masters.wls run.wl|family.wl [--kira] *)
Get[FileNameJoin[{ParentDirectory[DirectoryName[$InputFileName]], "lib", "MaximalCutBasis.wl"}]];

Module[{args, fam, found, ms, s, secs, setup, groups},
args = Rest[$ScriptCommandLine];
If[args === {}, Print["usage: find_masters.wls run.wl|family.wl [--kira]"]; CoreVerdict["find_masters", "usage"]];
setup = MCBRunSetup[First[args]];
If[setup === $Failed, CoreVerdict["find_masters", "usage", <|"message" -> "no run found for " <> First[args]|>]];
CoreCitationContext[setup["dir"], "whole run", "find_masters"];   (* Kira's search for the masters is the whole run's *)
fam = setup["fam"];
Print[MCBToolsLine[]];
If[(MCBMasterSectors[fam] === <||> && ! MCBSkippedQ["find-masters"] && ! ListQ[setup["run"]["Sectors"]]) || MemberQ[args, "--kira"],
  If[MemberQ[fam["TopSectors"], $Failed], Print["family.wl: \"TopSectors\" cannot be read (bin/validate_family.wls says why)"];
    CoreVerdict["find_masters", "usage", <|"message" -> "family.wl \"TopSectors\" cannot be read"|>]];
  Print[If[MCBMasterSectors[fam] === <||>, "no masters list in family.wl", "--kira"], ": numeric whole-family Kira run below the top sector(s) ",
    StringRiffle[SectorName /@ fam["TopSectors"], ", "], " (from ", fam["TopSectorsSource"], ")"];
  If[fam["TopSectorsSource"] === "every line",
    Print["   NOTE: every line counts as a propagator here. If some lines are ISPs, give \"TopSectors\" (or \"Graph\") in family.wl:",
      " otherwise Kira reduces a larger family, and sectors with ISP lines are not sectors of this one"]];
  found = MCBFindMastersKira[fam, FileNameJoin[{setup["dir"], "kira_masters"}], First[MCBPoints[fam, 1, 1]]];
  If[found === $Failed || found === {}, Print["Kira did not return masters (see kira_masters/kira.out)"]; CoreVerdict["find_masters", "error", <|"message" -> "Kira did not return masters"|>]];
  Put[found, FileNameJoin[{setup["dir"], "masters_found.m"}]];
  (* a string in "Masters" is read as a Kira masters file, which masters_found.m is not: the list itself goes there *)
  Print[Length[found], " masters -> masters_found.m (add \"Masters\" -> Get[\"", FileNameJoin[{setup["dir"], "masters_found.m"}], "\"], or the list itself, to family.wl)"]];
secs = SortBy[MCBRunSectors[setup], {Total[#], SectorID[#]} &];
Export[FileNameJoin[{setup["dir"], "sectors.txt"}], StringRiffle[(SectorName[#] <> " " <> ToString[SectorID[#]] <> " " <> ToString[Total[#]]) & /@ secs, "\n"] <> "\n", "Text"];
ms = MCBMasterSectors[fam];
(* sectors that are an earlier one at mapped kinematics: the automatic pass tries the earlier basis, mapped, first *)
groups = Quiet@Check[MCBGeometryGroups[fam, secs], <||>];
Put[groups, FileNameJoin[{setup["dir"], "geometry.m"}]];
Print["sector  Kira-id  props  #MI(list)  same geometry as"];
Scan[Print[SectorName[#], "  ", SectorID[#], "  ", Total[#], "  ", Length[Lookup[Lookup[ms, SectorName[#], <||>], "masters", {}]],
    If[KeyExistsQ[groups, SectorName[#]], "  " <> groups[SectorName[#]]["sameAs"] <> " at " <> ToString[groups[SectorName[#]]["invariants"], InputForm], ""]] &, secs];
Print[Length[secs], " sectors -> ", FileNameJoin[{setup["dir"], "sectors.txt"}]];
If[groups =!= <||>, Print[Length[groups], " of them repeat the geometry of an earlier sector (geometry.m): finish the earlier one first, ",
  "and the automatic pass tries its basis, mapped, before any search"]];
Print["RUNDIR ", setup["dir"]];
Print["QUEUES ", If[IntegerQ[setup["run"]["Parallel"]], setup["run"]["Parallel"], MCBKernelBudget[]["Parallel"]]];
CoreVerdict["find_masters", "pass", <|"run" -> setup["dir"], "sectors" -> (SectorName /@ secs)|>]
];
