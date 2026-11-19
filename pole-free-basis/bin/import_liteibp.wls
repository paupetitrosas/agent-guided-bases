#!/usr/bin/env wolframscript
(* Write family.wl files from a LiteRed/LiteIBP families file (Kinematics0, Propagators[fam] = {...}).
   usage: import_liteibp.wls families.m outDir [UnitScale] [fam1,fam2,...]
   Check the mass dimensions of the invariants afterwards (default 2 for every symbol). *)
Get[FileNameJoin[{ParentDirectory[DirectoryName[$InputFileName]], "lib", "PoleFreeBasis.wl"}]];

Module[{a = Rest[$ScriptCommandLine], opts = <||>, fl},
If[Length[a] < 2, Print["usage: import_liteibp.wls families.m outDir [UnitScale] [fam1,fam2,...]"]; CoreVerdict["import_liteibp", "usage"]];
If[Length[a] >= 3, opts["UnitScale"] = ToExpression[a[[3]]]];
If[Length[a] >= 4, opts["Families"] = StringSplit[a[[4]], ","]];
fl = PFBImportLiteIBPFamilies[a[[1]], a[[2]], opts];
If[fl === $Failed, CoreVerdict["import_liteibp", "fail", <|"message" -> "the families file could not be converted (see above)"|>]];
CoreVerdict["import_liteibp", "pass", <|"files" -> fl|>]];
