#!/usr/bin/env wolframscript
(* Compare a finished reduction (red_1.m, at the slice point) with the current slice: every focus row must agree exactly.
   usage: calibrate.wls run.wl jobDir
   It also checks the Euler relation on the reduction's focus rows (when the reduction differentiates every invariant
   of non-zero dimension): a failure there points at the family or the masters' definitions, not at the slice. *)
Get[FileNameJoin[{ParentDirectory[DirectoryName[$InputFileName]], "lib", "PoleFreeBasis.wl"}]];

Module[{a = Rest[$ScriptCommandLine], st, sl, red, cal, eu},
st = PFBStartRun[a[[1]]]; If[st === $Failed, CoreVerdict["calibrate", "usage", <|"message" -> "no run found for " <> ToString[a[[1]]]|>]];
sl = PFBCurrentSlice[st["Dir"], st["State"]];
red = PFBReadRed[a[[2]], 1];
If[red === $Failed, Print["no red_1.m in ", a[[2]], "; status: ", PFBSubtreeStatus[a[[2]]]];
  CoreVerdict["calibrate", "usage", <|"message" -> "no red_1.m in " <> a[[2]], "job" -> PFBSubtreeStatus[a[[2]]]|>]];
PFBImportMemory[a[[2]]];
cal = PFBCalibrate[sl, red];
Print["calibration: ", cal["Status"], "; rows checked ", Length[Lookup[cal, "Checked", {}]], "; ", cal["Message"]];
eu = PFBEulerCheck[st["System"], red];
Print[If[eu["Pass"] === False, "WARNING: ", ""], eu["Message"]];
(* a calibration that compared no row (a job without focus rows) confirms nothing *)
If[cal["Status"] === "exact" && Lookup[cal, "Checked", {}] === {}, Print["no row was compared: the job has no focus row in the slice, so this is no calibration"]];
CoreVerdict["calibrate", If[cal["Status"] === "exact" && Lookup[cal, "Checked", {}] =!= {}, "pass", "fail"], <|"status" -> cal["Status"], "message" -> cal["Message"],
  "rows" -> Length[Lookup[cal, "Checked", {}]], "euler" -> <|"pass" -> eu["Pass"], "message" -> eu["Message"]|>|>]];
