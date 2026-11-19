#!/usr/bin/env wolframscript
(* Read and check system.wl: families, images (maps), roots, masters and their labels, sectors.
   usage: validate_system.wls system.wl|run.wl
   With run.wl it also reads the run's SOFIA caches (bin/singularities.wls): a family without letters whose candidate
   singularities wait for the user's yes is a question.
   Exit code 1 when there are errors. Questions are ambiguities to put to the user, never to be guessed. *)
Get[FileNameJoin[{ParentDirectory[DirectoryName[$InputFileName]], "lib", "PoleFreeBasis.wl"}]];

Module[{f = If[Length[$ScriptCommandLine] >= 2, $ScriptCommandLine[[2]], "system.wl"], sys, v, keys, run = None},
If[KeyExistsQ[Replace[Quiet@Get[f], Except[_Association] -> <||>], "System"], run = PFBReadRun[f]; f = run["System"]];
sys = PFBReadSystem[f];
If[sys === $Failed, CoreVerdict["validate_system", "usage", <|"message" -> "system.wl could not be read: " <> f|>]];
v = If[AssociationQ[run], PFBValidateSystem[sys, PFBRunDirPath[run]], PFBValidateSystem[sys]];
keys = PFBSectorKeys[sys];
Print["system ", sys["Name"], ": families ", sys["Order"], " (images: ", Select[sys["Order"], PFBBaseOf[sys, #] =!= # &], ")"];
Print[Length[PFBMasters[sys]], " masters (global labels ut[1..", Length[PFBMasters[sys]], "]), ", Length[keys], " sectors, ", Length[PFBRootDefs[sys]], " roots"];
Do[With[{im = sys["Families"][fn]["Image"]}, If[im =!= None, Print["  ", fn, " = ", PFBBaseOf[sys, fn], " with ", im["MomentumMap"], "; invariants ", im["InvariantMap"]]]], {fn, sys["Order"]}];
Print["frozen: ", sys["Frozen"], "; symmetry rules: ", Length[sys["SymmetryRules"]]];
Print["\nerrors (", Length[v["Errors"]], "):"]; Scan[Print["  - ", #] &, v["Errors"]];
Print["warnings (", Length[v["Warnings"]], "):"]; Scan[Print["  - ", #] &, v["Warnings"]];
Print["questions for the user (", Length[v["Questions"]], "):"]; Scan[Print["  - ", #] &, v["Questions"]];
CoreVerdict["validate_system", If[v["Errors"] === {}, "pass", "fail"], <|"errors" -> v["Errors"], "warnings" -> v["Warnings"], "questions" -> v["Questions"]|>]];
