#!/usr/bin/env wolframscript
(* Residue-column test on the current slice: which masters cause the poles of a sector, or its entries above the cap on
   the power of eps (the same test at eps -> infinity); negative powers of eps are a pole at eps = 0.
   usage: sources.wls run.wl fam/jPATTERN [maxLowerSources] *)
Get[FileNameJoin[{ParentDirectory[DirectoryName[$InputFileName]], "lib", "PoleFreeBasis.wl"}]];

Module[{a = Rest[$ScriptCommandLine], st, sl, c, key, r, sys},
If[Length[a] < 2, Print["usage: sources.wls run.wl fam/jPATTERN [maxLowerSources]"]; CoreVerdict["sources", "usage"]];
st = PFBStartRun[a[[1]]]; If[st === $Failed, CoreVerdict["sources", "usage", <|"message" -> "no run found for " <> ToString[a[[1]]]|>]]; sys = st["System"];
sl = PFBCurrentSlice[st["Dir"], st["State"]];
If[sl === $Failed, Print["no current slice"]; CoreVerdict["sources", "usage", <|"message" -> "no current slice"|>]];
key = With[{p = StringSplit[a[[2]], "/"]}, {ToExpression[p[[1]]], SectorFromName[p[[2]]]}];
c = PFBCensus[sys, sl, PFBCensusOptions[st]];
r = PFBSourceTest[sys, sl, c, key, <|"MaxLowerSources" -> If[Length[a] >= 3, ToExpression[a[[3]]], 1], "Flagged" -> Keys[Lookup[st["State"], "Flagged", <||>]],
  "Fixed" -> Union[Flatten[#["Replace"] & /@ Select[Lookup[st["State"], "Accepted", {}], Lookup[#, "Kind", "change"] =!= "rescale" &]]]|>];
Print[r["Outcome"], ": ", r["Message"]];
Print["poles (order): ", Lookup[r, "Poles", <||>], If[KeyExistsQ[r, "HighColumns"], "; columns above eps^" <> ToString[$PFBMaxEpsDegree] <> ": " <> ToString[ut /@ r["HighColumns"]], ""]];
Do[Print["  sources ", ut /@ p["Sources"], " (", p["Kind"], ", positions ", Lookup[p, "Positions", "-"], ", free parameters ", p["Free"], ")"], {p, r["Passing"]}];
If[KeyExistsQ[r, "WaitFor"], Print["  wait for the sectors of ", ut /@ r["WaitColumns"], " (their columns carry the poles) and ", ut /@ r["WaitCouplings"], " (the rows couple to them)"]];
KeyValueMap[Print["  at eps = ", #1, " every pole sits in the column of ", ut /@ #2] &, Lookup[r, "SingleColumn", <||>]];
Do[Print["  possible hidden weight " <> ToString[h["Factor"], InputForm] <> " on the clean sector ", PFBSectorString[h["Sector"]], " (columns ", ut /@ h["Columns"], ", rows ", ut /@ h["Rows"], ")",
    If[TrueQ[h["Tried"]], ": its lower-sector scan was recorded", ""]], {h, Lookup[r, "HiddenWeight", {}]}];
Do[If[Lookup[o, "Kind", "new"] === "moved",
    Print["  moved here by change ", o["Change"], ": rows ", ut /@ o["Rows"], ", factors ", InputForm[o["Factors"]], " (this sector's rows had them before; now also in ", Length[o["Entries"]], " new entries)"],
    Print["  deferred here by change ", o["Change"], ": rows ", ut /@ o["Rows"], " (through ", ut /@ o["Sources"], If[o["Verified"], "", ", not verified"], ")"]],
  {o, PFBDeferredObligations[st["State"], key]}];
CoreVerdict["sources", "pass", <|"sector" -> a[[2]], "outcome" -> r["Outcome"], "message" -> r["Message"], "sources" -> (#["Sources"] & /@ r["Passing"]),
  "waitFor" -> Lookup[r, "WaitFor", {}],
  "singleColumn" -> KeyValueMap[<|"pole" -> ToString[#1, InputForm], "masters" -> #2|> &, Lookup[r, "SingleColumn", <||>]],
  "hiddenWeight" -> (<|"sector" -> PFBSectorString[#["Sector"]], "factor" -> #["Factor"], "tried" -> TrueQ[#["Tried"]]|> & /@ Lookup[r, "HiddenWeight", {}])|>]];
