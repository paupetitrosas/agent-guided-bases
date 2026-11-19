#!/usr/bin/env wolframscript
(* The optional automatic first pass (rung 1) over sectors, one after the other in this kernel.
   usage: auto_pass.wls run.wl [j0101... ...] [--force]
   Without sector names: every sector of the run (sectors with basis.m are skipped unless --force). *)
Get[FileNameJoin[{ParentDirectory[DirectoryName[$InputFileName]], "lib", "MaximalCutBasis.wl"}]];

Module[{args, dir, fam, force, names, opts, rec, s, secs, setup},
args = Rest[$ScriptCommandLine];
If[args === {}, Print["usage: auto_pass.wls run.wl [sector ...] [--force]"]; CoreVerdict["auto_pass", "usage"]];
setup = MCBRunSetup[First[args]];
If[setup === $Failed, CoreVerdict["auto_pass", "usage", <|"message" -> "no run found for " <> First[args]|>]];
fam = setup["fam"];
names = Select[Rest[args], StringStartsQ[#, "j"] &];
secs = If[names =!= {}, SectorFromName /@ names, MCBRunSectors[setup]];
force = MemberQ[args, "--force"] || Environment["FORCE"] === "1";
opts = MCBAutoPassOptions[setup];   (* run.wl "AutoPass" and the time limits, including the budget per sector *)
Do[
  dir = MCBSectorDir[setup["dir"], s];
  If[FileExistsQ[FileNameJoin[{dir, "basis.m"}]] && ! force, Print["skip ", SectorName[s], " (basis.m exists; --force to redo)"]; Continue[]];
  If[force && DirectoryQ[FileNameJoin[{dir, "kira"}]], DeleteDirectory[FileNameJoin[{dir, "kira"}], DeleteContents -> True]];
  rec = MCBAutoPass[fam, s, dir, opts];
  Print["DONE ", SectorName[s], " ", rec["status"]],
  {s, secs}];
CoreVerdict["auto_pass", "pass", <|"sectors" -> (SectorName /@ secs)|>]
];
