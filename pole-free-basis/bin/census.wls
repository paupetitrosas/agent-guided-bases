#!/usr/bin/env wolframscript
(* Census of the current slice of a run: finite eps poles, negative powers of eps, eps profile, the highest power of eps
   and the entries above the cap (run.wl "MaxEpsDegree"), bad sectors bottom-up, and the possible hidden weights: clean
   sectors whose subtree holds every column of a pole factor (opened before the sectors where the poles show, unless
   their lower-sector scan was recorded); and the kinematic degrees of the slice when it has a degree table
   (bin/degrees.wls).
   usage: census.wls run.wl [--sector fam/jPATTERN]      (--sector: the rows of that one sector in detail) *)
Get[FileNameJoin[{ParentDirectory[DirectoryName[$InputFileName]], "lib", "PoleFreeBasis.wl"}]];

Module[{a = Rest[$ScriptCommandLine], st, sl, c, key, p},
st = PFBStartRun[a[[1]]];
If[st === $Failed, CoreVerdict["census", "usage", <|"message" -> "no run found"|>]];
sl = PFBCurrentSlice[st["Dir"], st["State"]];
If[sl === $Failed, Print["no current slice: run import_slice.wls (or build one locally)"]; CoreVerdict["census", "usage", <|"message" -> "no current slice"|>]];
c = PFBCensus[st["System"], sl, PFBCensusOptions[st]];
Print[PFBCensusText[c]];
Print["next sector (lowest bad, not possibly inherited, or a possible hidden weight below them): ", If[c["Next"] === None, "none", PFBSectorString[c["Next"]]]];
Do[Print["  possible hidden weight: ", PFBSectorString[h["Sector"]], " (clean) may carry " <> ToString[h["Factor"], InputForm] <> ": the rows ", ut /@ h["Rows"], " of ",
    StringRiffle[PFBSectorString /@ h["Sectors"], ", "], " have it only in the columns ", ut /@ h["Columns"], ", all in its subtree; ",
    If[TrueQ[h["Tried"]], "its lower-sector scan was recorded", "a hint: open it first with its lower-sector scan, small (one reduction of its subtree at the slice point), " <>
      "bin/pair_scan.wls run.wl <job of its subtree> " <> PFBSectorString[h["Sector"]] <> " --hidden-weight; once the scan is recorded the hint ends"]],
  {h, Lookup[c, "HiddenWeights", {}]}];
(* the kinematic degrees of this slice, when it has a degree table (bin/degrees.wls, the local slice, the user's) *)
With[{dt = PFBReadDegrees[st["Dir"], st["State"]]}, If[AssociationQ[dt], Print[PFBDegreeText[dt]]]];
(* SOFIA's candidate singularities of a family without letters wait for the user's yes (bin/singularities.wls) *)
Scan[Print["letters on offer: ", #["Message"]] &, PFBSingularityOffers[st["System"], st["Dir"]]];
Do[With[{s = c["Sectors"][k]}, Print["  ", s["Name"], ": ", StringRiffle[s["Issues"], ", "],
     If[s["BadRows"] === {}, "", "; pole rows " <> ToString[ut /@ s["BadRows"]] <> ", factors " <> ToString[s["PoleFactors"], InputForm]],
     If[s["SelfBlockPoles"] =!= {}, ", POLES IN ITS OWN BLOCK", ""],
     If[s["EpsZeroRows"] === {}, "", "; rows with negative powers of eps " <> ToString[ut /@ s["EpsZeroRows"]] <>
       If[Lookup[s, "SelfBlockEpsZero", {}] =!= {}, ", NEGATIVE POWERS IN ITS OWN BLOCK", ""]],
     If[s["HighRows"] === {}, "", "; rows above the cap " <> ToString[ut /@ s["HighRows"]] <> If[s["SelfBlockHigh"] =!= {}, ", ABOVE THE CAP IN ITS OWN BLOCK", ""]],
     If[s["PossiblyInherited"], "; couples to bad " <> ToString[PFBSectorString /@ s["CouplesToBadLower"]], ""]]],
  {k, c["BadSectors"]}];
p = Position[a, "--sector"];
If[p =!= {} && p[[1, 1]] < Length[a],
  key = With[{q = StringSplit[a[[p[[1, 1]] + 1]], "/"]}, {ToExpression[q[[1]]], SectorFromName[q[[2]]]}];
  With[{s = Lookup[c["Sectors"], Key[key], Missing[]]},
    If[MissingQ[s], Print["\n", a[[p[[1, 1]] + 1]], ": not in the slice"],
      Print["\n", s["Name"], ":"];
      Do[Print["  ", f, ": ", If[ListQ[s[f]], If[MemberQ[{"Rows", "BadRows", "PoleColumns", "EpsZeroRows", "SelfBlockEpsZero", "HighRows", "HighColumns", "SelfBlockHigh"}, f], ut /@ s[f], s[f]], s[f]]],
        {f, Select[{"Rows", "Issues", "BadRows", "PoleColumns", "SelfBlockPoles", "PoleFactors", "EpsZeroRows", "SelfBlockEpsZero", "HighRows", "HighColumns", "SelfBlockHigh", "CouplesToBadLower",
          "PossiblyInherited", "PossibleHiddenWeight", "HiddenWeightBelow"}, KeyExistsQ[s, #] &]}]]]];
(* pass: the DE is pole-free (no finite pole, no negative power of eps) and within the cap; otherwise there is work left *)
CoreVerdict["census", If[c["BadEntries"] === {} && c["EpsZero"] === {} && c["HighDegree"] === {}, "pass", "fail"],
  <|"entriesWithPoles" -> Length[c["BadEntries"]], "rows" -> Length[c["BadRows"]], "negativePowers" -> Length[c["EpsZero"]],
    "badSectors" -> (PFBSectorString /@ c["BadSectors"]), "next" -> If[c["Next"] === None, Null, PFBSectorString[c["Next"]]],
    "maxDegree" -> Replace[c["MaxDegree"], None -> Null], "aboveCap" -> Length[c["HighDegree"]], "cap" -> Replace[c["DegreeCap"], Infinity -> Null],
    "hiddenWeights" -> (<|"sector" -> PFBSectorString[#["Sector"]], "factor" -> #["Factor"], "rows" -> #["Rows"], "columns" -> #["Columns"], "tried" -> TrueQ[#["Tried"]]|> & /@
      Lookup[c, "HiddenWeights", {}]),
    "kinematicDegrees" -> With[{dt = PFBReadDegrees[st["Dir"], st["State"]]}, If[AssociationQ[dt], With[{u = dt["Summary"]},
       <|"highest" -> Replace[u["Highest"], None -> Null], "count" -> u["Count"], "sum" -> u["Sum"], "complete" -> u["Complete"]|>], Null]]|>]];
