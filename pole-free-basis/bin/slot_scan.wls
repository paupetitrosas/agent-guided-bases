#!/usr/bin/env wolframscript
(* Try every candidate integral in one slot of a sector's new basis, exactly on the current slice, with the
   reductions of a job (dry runs: nothing is recorded, the gate is not called). The other new masters are fixed in
   <|label -> root-free definition|> (Cur[k] stands for the current master k). Candidates: the list given, or every
   pool integral of the slot's sector in the job. Prints the candidates best first: pole entries left in the
   sector's rows, the change of the census, the negative powers of eps (in the whole slice and in the sector's rows), and the entries raised above the cap on the power of eps (run.wl "MaxEpsDegree", which
   the gate refuses) with the highest power in the sector's rows, and the digit height of the sector's rows (PFBDigitHeight: the
   digits of their coefficients in eps at the slice point, a free proxy for the kinematic degree), which orders only the
   candidates equal on everything else. Use it after the structural reading has fixed the other masters of the sector; to try
   two slots at once, bin/pair_scan.wls. The best candidate and the pole entries it leaves in the sector's rows go to
   the sector's attempts.m (PFBRecordScan), for the hidden-weight test before a flag.
   usage: slot_scan.wls run.wl job "<|label -> def, ...|>" slotLabel ["{j[...], ...}"] *)
Get[FileNameJoin[{ParentDirectory[DirectoryName[$InputFileName]], "lib", "PoleFreeBasis.wl"}]];

Module[{a = Rest[$ScriptCommandLine], ctx, sys, sl, red, cal, base, slot, key, cands, scan, res},
  If[Length[a] < 4, Print["usage: slot_scan.wls run.wl job \"<|label -> def, ...|>\" slotLabel [\"{j[...], ...}\"]"]; CoreVerdict["slot_scan", "usage"]];
  ctx = PFBStartRun[a[[1]]]; If[ctx === $Failed, CoreVerdict["slot_scan", "usage", <|"message" -> "no run found"|>]]; sys = ctx["System"];
  sl = PFBCurrentSlice[ctx["Dir"], ctx["State"]];
  red = First[Get /@ PFBRedFiles[FileNameJoin[{ctx["Dir"], "jobs", a[[2]]}]]];
  cal = PFBCalibrate[sl, red]; If[cal["Status"] =!= "exact", Print["calibration: ", cal["Status"], " (change nothing until it is exact)"]; CoreVerdict["slot_scan", "fail", <|"message" -> "calibration " <> cal["Status"]|>]];
  base = ToExpression[a[[3]]] /. Cur[k_] :> PFBMaster[sys, k]["RootFree"]; slot = ToExpression[a[[4]]];
  key = PFBMaster[sys, slot]["SectorKey"];
  (* a tool used from here on is credited to the sector (the run's ledger) *)
  CoreCitationContext[ctx["Dir"], PFBSectorString[key], "slot scan"];
  cands = If[Length[a] >= 5, ToExpression[a[[5]]],
    Select[red["Pool"], MatchQ[#, j[f_, v__] /; f === key[[1]] && (Boole[Positive[{v}]] === key[[2]])] &]];
  scan = PFBScanSets[sys, sl, red, cal, key, Append[base, slot -> #] & /@ cands, <|"State" -> ctx["State"], "FullCensus" -> True|>];
  res = scan["Results"];
  PFBRecordScan[ctx["Dir"], key, res, <|"Rung" -> 2, "What" -> "slot scan (bin/slot_scan.wls), slot ut[" <> ToString[slot] <> "], " <> ToString[Length[cands]] <> " candidates"|>];
  Print["slot ", slot, " of ", PFBSectorString[key], ": ", Length[cands], " candidates, ", scan["Dependent"], " dependent on the others, ", Length[res], " tried"];
  Do[Print[r["bad"], " pole entries in the sector rows ", InputForm[r["factors"]], " | ", r["set"][slot], If[r["maxCut"], " (changes the maximal cut)", ""],
     " | census ", r["dCensus"], ", new pole entries ", r["newBad"], If[r["deferred"] > 0, " (and " <> ToString[r["deferred"]] <> " deferred to their own sectors)", ""],
     " | negative eps powers ", r["neg"], " (", r["zero"], " in the sector rows) | highest eps power ", r["deg"] /. -Infinity -> "-", ", ", r["high"], " entries of the sector rows above eps^", $PFBMaxEpsDegree,
     If[r["over"] > 0, " (" <> ToString[r["over"]] <> " raised there)", ""], " | digit height ", r["height"]], {r, Take[res, UpTo[30]]}];
  CoreVerdict["slot_scan", "pass", <|"slot" -> slot, "tried" -> Length[res], "best" -> If[res === {}, Null, ToString[First[res]["set"][slot], InputForm]],
    "poleFree" -> (ToString[#["set"][slot], InputForm] & /@ Select[res, #["bad"] == 0 && #["newBad"] == 0 && #["over"] == 0 &]),
    "aboveCap" -> (ToString[#["set"][slot], InputForm] & /@ Select[res, #["bad"] == 0 && #["newBad"] == 0 && #["over"] > 0 &]),
    "deferred" -> (<|"cand" -> ToString[#["set"][slot], InputForm], "entries" -> #["deferred"]|> & /@ Select[res, #["bad"] == 0 && #["newBad"] == 0 && #["deferred"] > 0 &])|>]];
