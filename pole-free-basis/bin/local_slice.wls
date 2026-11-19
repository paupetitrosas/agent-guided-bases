#!/usr/bin/env wolframscript
(* Build the slice of the whole system locally.
   usage: local_slice.wls run.wl [--no-degrees]  writes the job (point: conventions.wl's "Point" if given, else random primes) and prints its command
          local_slice.wls run.wl --collect       after the job finished: makes its reduction the current slice of the run, with its starting degrees
   The job refuses to learn when the predicted memory does not fit: run its folder on a larger machine then. By default
   the same job, on the same learned system, also measures the starting degrees of every row (the degree census of
   bin/degrees.wls: FFAllDegrees, nothing reconstructed; reference/workflow.md); --no-degrees skips them. The degrees
   need FiniteFlow's learned system, so a job with them is FiniteFlow's at every point; without them (--no-degrees)
   Kira may reduce the slice point (run.wl "Reducer"; reference/workflow.md, "Which reducer"). *)
Get[FileNameJoin[{ParentDirectory[DirectoryName[$InputFileName]], "lib", "PoleFreeBasis.wl"}]];

Module[{a = Rest[$ScriptCommandLine], st, sys, conv, pt, ders, job, red, sl, c, eu, s2, dg, dspec},
st = PFBStartRun[a[[1]]]; If[st === $Failed, CoreVerdict["local_slice", "usage", <|"message" -> "no run found for " <> ToString[a[[1]]]|>]]; sys = st["System"];
conv = If[StringQ[Lookup[st["Run"]["Slice"], "Conventions", None]] && FileExistsQ[st["Run"]["Slice"]["Conventions"]], PFBReadConventions[st["Run"]["Slice"]["Conventions"]], <||>];
job = FileNameJoin[{st["Dir"], "jobs", "local_slice"}];
If[MemberQ[a, "--collect"],
  red = PFBReadRed[job, 1];
  If[red === $Failed, Print["no reduction yet: ", PFBSubtreeStatus[job]]; CoreVerdict["local_slice", "usage", <|"message" -> "no reduction yet", "job" -> PFBSubtreeStatus[job]|>]];
  PFBImportMemory[job];
  sl = PFBSliceFromRed[sys, red]; If[sl === $Failed, CoreVerdict["local_slice", "fail", <|"message" -> "the reduction does not give a slice"|>]];
  c = PFBCensus[sys, sl];
  s2 = PFBStoreSlice[st["Dir"], st["State"], sl, c, "local slice"];
  eu = PFBEulerCheck[sys, sl];
  Print[PFBCensusText[c]]; Print[If[eu["Pass"] === False, "WARNING: ", ""], eu["Message"]];
  (* the starting degrees, measured by the same job *)
  dg = If[AssociationQ[Lookup[Replace[Quiet@Get[FileNameJoin[{job, "job.m"}]], Except[_Association] -> <||>], "Degrees", None]],
    PFBCollectDegrees[Join[st, <|"State" -> s2|>], {job}], None];
  If[AssociationQ[dg], Print["starting degrees: ", PFBDegreeText[dg["Table"]]]];
  CoreVerdict["local_slice", "pass", <|"collected" -> True, "entriesWithPoles" -> Length[c["BadEntries"]], "euler" -> <|"pass" -> eu["Pass"], "message" -> eu["Message"]|>,
    "degrees" -> If[AssociationQ[dg], With[{u = dg["Table"]["Summary"]}, <|"table" -> dg["File"], "highest" -> Replace[u["Highest"], None -> Null], "count" -> u["Count"], "sum" -> u["Sum"],
       "complete" -> u["Complete"], "notMeasured" -> (PFBSectorString /@ u["NotMeasured"])|>], "not measured (--no-degrees)"]|>]];
pt = Replace[Lookup[conv, "Point", None], None :> First[PFBRandomPoints[sys, 1, 12345]]];
ders = Replace[Lookup[conv, "Derivatives", Automatic], Automatic :> DeleteCases[sys["Invariants"], PFBFamily[sys, First[sys["Order"]]]["UnitScale"]]];
(* the starting degrees of every row, unless --no-degrees: on every sector, with the known singularities of every family *)
dspec = If[MemberQ[a, "--no-degrees"], None, PFBDegreeSpec[st, PFBSectorKeys[sys], Automatic, sys["Order"], <||>]];
job = PFBLocalSliceJob[sys, st["Dir"], pt, ders, Join[<|"Seeds" -> st["Run"]["Seeds"], "MaxGB" -> st["Run"]["MaxGB"], "TimeLimit" -> st["Run"]["TimeLimit"]|>,
   If[dspec === None, <||>, <|"Degrees" -> dspec|>]]];
If[job === $Failed, CoreVerdict["local_slice", "fail", <|"message" -> "the job was not written (see above)"|>]];
Print["point ", pt, "; derivatives ", ders, If[dspec === None, "; no starting degrees", "; the job also measures the starting degrees (--no-degrees to skip)"]];
Print["run it with:\n  ", PFBSubtreeCommand[job], "\nthen: bin/ws bin/local_slice.wls ", a[[1]], " --collect"];
CoreVerdict["local_slice", "pass", <|"job" -> job, "command" -> PFBSubtreeCommand[job]|>]];
