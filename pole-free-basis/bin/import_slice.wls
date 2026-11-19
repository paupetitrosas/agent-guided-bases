#!/usr/bin/env wolframscript
(* Import an external slice (conventions.wl of run.wl), convert it to the root-free frame, take its census and make it
   the current slice of the run.
   usage: import_slice.wls run.wl [--regenerated]
   --regenerated says that this slice is the full DE made again with the run's exported masters (the last step): the
   run is then marked as regenerated ("Regenerated" -> True in state.m, which CHANGES.md and the summary read) when
   the census of the slice is clean outside the flagged sectors; otherwise the mark is not set.
   The conventions are only trusted after the calibration (calibrate.wls) agrees exactly. The Euler relation of the
   homogeneous masters is checked on every row when the slice has a derivative in every invariant of non-zero
   dimension: a failure means the conventions (Frame, Transpose, Derivatives, Labels) or the masters' definitions
   do not match the slice. With conventions.wl "Degrees" -> file, the user's degrees of the slice's entries are validated
   against it (reference/formats.md) and stored with provenance "user" next to it; refused degrees refuse the import.
   conventions.wl "Credits" (the tools and papers that produced the slice) are recorded in the run's ledger for the whole
   run (CITATIONS.md); a name that is not in the registry refuses the import. *)
Get[FileNameJoin[{ParentDirectory[DirectoryName[$InputFileName]], "lib", "PoleFreeBasis.wl"}]];

Module[{st = PFBStartRun[$ScriptCommandLine[[2]]], conv, sl, c, s2, eu, dg = None},
If[st === $Failed, CoreVerdict["import_slice", "usage", <|"message" -> "no run found"|>]];
conv = PFBReadConventions[st["Run"]["Slice"]["Conventions"]];
If[conv === $Failed, CoreVerdict["import_slice", "usage", <|"message" -> "conventions.wl could not be read"|>]];
With[{cr = PFBSliceCredits[conv]}, If[StringQ[cr], Print[cr]; CoreVerdict["import_slice", "usage", <|"message" -> cr|>]]];
sl = PFBImportSlice[st["System"], conv];
If[sl === $Failed, CoreVerdict["import_slice", "fail", <|"message" -> "the slice was refused (see above)"|>]];
(* the user's degrees: validated before anything is stored *)
If[Lookup[conv, "Degrees", None] =!= None,
  dg = PFBImportDegrees[st["System"], sl, conv];
  Scan[Print["degrees: ", #] &, Join[dg["Errors"], ("warning: " <> #) & /@ dg["Warnings"]]];
  If[dg["Status"] =!= "ok", CoreVerdict["import_slice", "fail", <|"message" -> "the degrees of conventions.wl were refused; nothing was imported", "errors" -> dg["Errors"],
     "errorCount" -> Lookup[dg, "ErrorCount", Length[dg["Errors"]]]|>]]];
c = PFBCensus[st["System"], sl];
eu = PFBEulerCheck[st["System"], sl];
Print[If[eu["Pass"] === False, "WARNING: ", ""], eu["Message"]];
s2 = PFBStoreSlice[st["Dir"], st["State"], sl, c, "imported " <> FileNameTake[conv["File"]]];
PFBRecordSliceCredits[st["Dir"], conv];
If[AssociationQ[dg], s2 = PFBStoreDegrees[st["Dir"], s2, Length[s2["Slices"]], Join[dg["Table"], <|"Slice" -> s2["Current"]|>]];
  Print["degrees of the user: ", PFBDegreeText[dg["Table"]]]];
Print[PFBCensusText[c]];
If[MemberQ[$ScriptCommandLine, "--regenerated"],
  With[{left = Complement[c["BadSectors"], Keys[Lookup[s2, "Flagged", <||>]]]},
    If[left === {}, s2 = PFBSaveState[st["Dir"], Append[s2, "Regenerated" -> True]]; Print["the run is marked as regenerated"],
      Print["not marked as regenerated: the census has bad entries outside the flagged sectors, in ", StringRiffle[PFBSectorString /@ Take[left, UpTo[10]], ", "]]]]];
Print["current slice: ", s2["Current"], " in ", st["Dir"]];
CoreVerdict["import_slice", "pass", <|"slice" -> s2["Current"], "entriesWithPoles" -> Length[c["BadEntries"]], "rows" -> Length[c["BadRows"]],
  "negativePowers" -> Length[c["EpsZero"]], "euler" -> <|"pass" -> eu["Pass"], "message" -> eu["Message"]|>,
  "degrees" -> If[AssociationQ[dg], "stored (user)", "none given"], "regenerated" -> TrueQ[s2["Regenerated"]]|>]];
