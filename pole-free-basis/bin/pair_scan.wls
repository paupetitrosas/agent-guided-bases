#!/usr/bin/env wolframscript
(* Rung 3: try the natural integrals of a sector in two (or three) slots at once, exactly on the current slice, with
   the reductions of a job (dry runs: nothing is recorded, the gate is not called). Natural integrals are the sector's
   own integrals with at most --weight extra dots plus numerator powers (default 1), and the candidates of the
   structural reading (--cands); each slot may also keep its current master, so single replacements are tried too.
   It costs minutes: run it after the structural reading and before any fit or completion.
   Slots: --slots, or the sector's masters when it has at most three, or else the sources of the source test.
   Prints the sets best first: pole entries left in the sector's rows, whether the set changes the maximal cut, the
   entries with negative powers of eps left in the sector's rows, the entries raised above
   the cap on the power of eps (run.wl "MaxEpsDegree"; the gate refuses them) and the highest power in the sector's
   rows, for sets that clear the sector's rows, the change of the census, new poles above and negative powers of
   eps, and the digit height of the sector's rows (PFBDigitHeight: the digits of their coefficients in eps at the slice
   point, a free proxy for the kinematic degree), which orders only the sets equal on everything else. It times a pilot
   and stops when the whole scan would take longer than --budget minutes (default 30). The best set and the pole entries
   it leaves in the sector's rows go to the sector's attempts.m (PFBRecordScan): the hidden-weight test reads them before
   a flag.
   --hidden-weight: the lower-sector scan of a clean sector that may carry a hidden weight (the census's hint,
   PossibleHiddenWeight, or the factor of PFBHiddenWeightTest with --factor): the same sets over its masters, judged on
   the rows above that carry the factor (fewest entries with it left there first), its own rows kept free of finite
   poles (sets that put a pole there are ranked out). The job is a reduction of that sector's subtree: the rows above
   change through its columns, as the gate computes them (PFBHiddenWeightScan). --rows: the rows to judge (default:
   every row above that couples to the sector's masters and has a pole of the factor). The sector's maximal-cut-basis
   candidates (bin/maxcut_candidates.wls) join that scan when they were written.
   --maxcut: rung 8, the maximal-cut scan. The candidates of bin/maxcut_candidates.wls (the job must be the one it wrote,
   or one whose pool holds their integrals) join the natural integrals (--weight 0 by default: the corner only), each
   slot taking only those that keep its square root. Sets are ranked by the full rows as above, and on a non-dlog
   sector (the run's status or Picard-Fuchs label) the sector's new basis is marked "all-dot" when every element is
   dotted. The best --finalists sets (default 3) that clear the sector's rows then go through the maximal-cut-basis gate
   in this kernel (Kira on the cut at two points, the Euler relation): a failed check refuses a set, and Kira failing
   leaves it unchecked; the full rows rank the finalists first (PFBScanKey but its last key), and among sets they rank
   equal eps-form on the cut breaks the tie, then an eps-polynomial DE with the smaller spread, then, on a non-dlog
   sector, a set with an undotted element, and last the digit height (PFBScanKey's last key). The ranked
   finalists go to the sector folder (maxcut_finalists.m, PFBReadMaxCutFinalists): send the first through PFBTryChange
   with "Rung" -> 8 and "MaxCutCheck" -> its verdict. --no-check stops after the scan.
   usage: pair_scan.wls run.wl job fam/jPATTERN [--slots "{l1, l2}"] [--weight w] [--cands "{j[...], ...}"]
                        [--keep "<|label -> def|>"] [--max n] [--budget minutes]
                        [--hidden-weight [--factor "1 + 4 eps"] [--rows "{l1, ...}"]]
                        [--maxcut [--finalists n] [--no-check]] *)
Get[FileNameJoin[{ParentDirectory[DirectoryName[$InputFileName]], "lib", "PoleFreeBasis.wl"}]];

Module[{a = Rest[$ScriptCommandLine], opt, ctx, sys, sl, red, cal, key, secBase, slots, w, nat, cands, keep, symm, sets, maxSets, budget,
    c0, pilot, est, scan, res, show, src, nSets, ss, high0, zero0, hadPoles, hw, maxcut, mc = None, mcRun = None, allDot, fin = None, missing},
  If[Length[a] < 3, Print["usage: pair_scan.wls run.wl job fam/jPATTERN [--slots \"{l1, l2}\"] [--weight w] [--cands \"{...}\"] [--keep \"<|...|>\"] [--max n] [--budget minutes] [--hidden-weight [--factor \"1 + 4 eps\"]] [--maxcut [--finalists n] [--no-check]]"];
    CoreVerdict["pair_scan", "usage"]];
  opt[name_, def_] := With[{p = Position[a, name]}, If[p === {} || p[[1, 1]] == Length[a], def, a[[p[[1, 1]] + 1]]]];
  maxcut = MemberQ[a, "--maxcut"];
  ctx = PFBStartRun[a[[1]]]; If[ctx === $Failed, CoreVerdict["pair_scan", "usage", <|"message" -> "no run found"|>]]; sys = ctx["System"];
  sl = PFBCurrentSlice[ctx["Dir"], ctx["State"]];
  If[PFBRedFiles[FileNameJoin[{ctx["Dir"], "jobs", a[[2]]}]] === {}, CoreVerdict["pair_scan", "usage", <|"message" -> "the job " <> a[[2]] <> " has no reductions"|>]];
  red = Get[First[PFBRedFiles[FileNameJoin[{ctx["Dir"], "jobs", a[[2]]}]]]];
  cal = PFBCalibrate[sl, red];
  If[cal["Status"] =!= "exact", Print["calibration: ", cal["Status"], " (change nothing until it is exact)"]; CoreVerdict["pair_scan", "fail", <|"message" -> "calibration " <> cal["Status"]|>]];
  key = With[{p = StringSplit[a[[3]], "/"]}, {ToExpression[p[[1]]], SectorFromName[p[[2]]]}];
  (* a tool used from here on (the maximal-cut gate on the finalists: Kira, the representations) is credited to the sector *)
  CoreCitationContext[ctx["Dir"], PFBSectorString[key], Which[MemberQ[a, "--hidden-weight"], "lower-sector scan", maxcut, "maximal-cut scan (rung 8)", True, "pair scan"]];
  secBase = Select[Intersection[PFBSectorMasters[sys, key], sl["Labels"]], PFBMaster[sys, #]["Family"] === key[[1]] &];
  c0 = Block[{Print}, PFBCensus[sys, sl, PFBCensusOptions[ctx]]];
  maxSets = ToExpression[opt["--max", "3000"]]; budget = ToExpression[opt["--budget", "30"]];
  (* the lower-sector scan of a clean sector with a possible hidden weight: judged on the rows above that carry it *)
  If[MemberQ[a, "--hidden-weight"],
    hw = PFBHiddenWeightScan[sys, sl, red, cal, key, <|"Census" -> c0, "State" -> ctx["State"], "RunDir" -> ctx["Dir"],
      "Factors" -> Replace[opt["--factor", None], {s_String :> Flatten[{ToExpression[s]}], None -> Automatic}],
      "Rows" -> Replace[opt["--rows", None], {s_String :> ToExpression[s], None -> Automatic}],
      "Slots" -> Replace[opt["--slots", None], {s_String :> ToExpression[s], None -> Automatic}], "MaxWeight" -> ToExpression[opt["--weight", "1"]],
      "Candidates" -> Replace[opt["--cands", None], {s_String :> ToExpression[s], None -> {}}],
      "Keep" -> Replace[opt["--keep", None], {s_String :> (ToExpression[s] /. Cur[k_] :> PFBMaster[sys, k]["RootFree"]), None -> <||>}],
      "MaxSets" -> maxSets, "BudgetMinutes" -> budget|>];
    Print[hw["Message"]];
    If[hw["Status"] =!= "done",
      If[hw["Factors"] =!= {}, Print["recorded in the sector's attempts.m as a lower-sector scan that could not run: the hint is now tried, and the sectors where the poles show come next"]];
      CoreVerdict["pair_scan", If[hw["Status"] === "no factor", "usage", "fail"], <|"sector" -> a[[3]], "message" -> hw["Message"], "status" -> hw["Status"]|>]];
    If[hw["NotInPool"] =!= {}, Print[Length[hw["NotInPool"]], " natural integrals are not in the job's pool (add them with PoolExtra to try them): ", Short[hw["NotInPool"], 3]]];
    show[r_] := StringRiffle[Table["ut[" <> ToString[l] <> "] -> " <> If[r["set"][l] === PFBMaster[sys, l]["RootFree"], "current", ToString[r["set"][l], InputForm]], {l, hw["Slots"]}], ", "];
    Do[Print[r["above"], " entries with " <> ToString[hw["Factors"], InputForm] <> " left in the rows above (", hw["AboveBefore"], " now) | ", show[r], If[r["maxCut"], " (changes the maximal cut)", ""],
       " | census ", r["dCensus"], ", new pole entries ", r["newBad"], " | negative eps powers ", r["neg"], " | highest eps power in the sector rows ", r["deg"] /. -Infinity -> "-",
       If[r["over"] > 0, ", " <> ToString[r["over"]] <> " raised above eps^" <> ToString[$PFBMaxEpsDegree], ""]], {r, Take[hw["Results"], UpTo[30]]}];
    If[hw["RankedOut"] =!= {}, Print[Length[hw["RankedOut"]], " sets ranked out: they put finite poles into the sector's own rows (e.g. ", show[First[hw["RankedOut"]]], ")"]];
    With[{good = hw["ClearingSets"]},
      Print[If[good =!= {}, "next: normalise the best set to the maximal-cut class of the masters it replaces and send it through PFBTryChange with checkReds (two or more extra points)",
        "no set clears the rows above: write in notes.md which entries stay; the scan is recorded, so the census no longer makes this sector Next for this factor, and the sectors where the poles show come next"]];
      CoreVerdict["pair_scan", "pass", <|"sector" -> a[[3]], "mode" -> "hidden-weight", "factors" -> hw["Factors"], "rows" -> hw["Rows"], "slots" -> hw["Slots"], "sets" -> hw["Sets"],
        "tried" -> Length[hw["Results"]] + Length[hw["RankedOut"]], "rankedOut" -> Length[hw["RankedOut"]], "aboveBefore" -> hw["AboveBefore"], "clearing" -> hw["Clearing"],
        "seconds" -> hw["Seconds"], "best" -> If[hw["Results"] === {}, Null, show[First[hw["Results"]]]],
        "clears" -> (<|"set" -> show[#], "maxCutChanged" -> #["maxCut"]|> & /@ good)|>]]];
  If[Lookup[Lookup[c0["Sectors"], Key[key], <||>], "Issues", {}] === {},
    Print[PFBSectorString[key], ": its rows have no finite pole, no negative power of eps and no entry above eps^", $PFBMaxEpsDegree, " on the current slice; nothing to scan",
      If[Lookup[c0["Sectors"][key], "PossibleHiddenWeight", {}] === {}, "", " for its own rows, but the census marks it as a possible hidden weight " <>
        ToString[c0["Sectors"][key]["PossibleHiddenWeight"], InputForm] <> ": run the lower-sector scan with --hidden-weight"]];
    CoreVerdict["pair_scan", "pass", <|"sector" -> a[[3]], "message" -> "the sector's rows are pole-free and within the cap"|>]];
  (* entries of the sector's rows with negative powers of eps or above the cap now: a set for a sector without finite
     poles must lower them to count *)
  zero0 = Count[c0["EpsZero"], e_ /; MemberQ[PFBSectorMasters[sys, key], e[[2]]]];
  high0 = Count[c0["HighDegree"], e_ /; MemberQ[PFBSectorMasters[sys, key], e[[2]]]];
  hadPoles = Lookup[c0["Sectors"][key], "BadRows", {}] =!= {};
  (* rung 8: the sector's maximal-cut-basis candidates, one root-free definition per slot that keeps its square root *)
  If[maxcut,
    mc = PFBReadMaxCutCandidates[ctx["Dir"], key];
    If[! AssociationQ[mc], Print["no maximal-cut candidates for ", a[[3]], ": run bin/maxcut_candidates.wls run.wl ", a[[3]], " first"];
      CoreVerdict["pair_scan", "usage", <|"message" -> "no maxcut_candidates.m: run bin/maxcut_candidates.wls first"|>]];
    mcRun = PFBMaxCutRun[sys, ctx["Dir"], key[[1]]]["Dir"];
    missing = Select[mc["Candidates"], ! SubsetQ[red["Pool"], #["Integrals"]] &];
    If[missing =!= {}, Print[Length[missing], " maximal-cut candidates have integrals outside the job's pool and cannot be tried (use the job of bin/maxcut_candidates.wls): ",
      Short[missing[[All, "Label"]], 3]]]];
  (* the slots: given; else the whole sector when it is small; else the sources of the source test *)
  slots = Replace[opt["--slots", None], {s_String :> ToExpression[s], None :> If[Length[secBase] <= 3, secBase,
      src = PFBSourceTest[sys, sl, c0, key, <|"Flagged" -> Keys[Lookup[ctx["State"], "Flagged", <||>]],
         "Fixed" -> Union[Flatten[#["Replace"] & /@ Select[Lookup[ctx["State"], "Accepted", {}], Lookup[#, "Kind", "change"] =!= "rescale" &]]]|>];
      If[MemberQ[{"source", "degree-source"}, src["Outcome"]], Intersection[First[src["Passing"]]["Sources"], secBase], {}]]}];
  If[! MatchQ[slots, {__Integer}] || ! SubsetQ[secBase, slots] || Length[slots] > 3,
    Print["give the slots with --slots (one to three masters of ", PFBSectorString[key], ", base family: ", ut /@ secBase, "); the sources pole by pole:"];
    Do[Print["  ", p["factor"], ": ", If[p["ownBlock"], "own block (maximal cut)", Map[ut, p["sources"], {2}]]], {p, PFBSourcesByPole[sys, sl, key]}];
    CoreVerdict["pair_scan", "usage", <|"message" -> "no slots: give --slots"|>]];
  w = ToExpression[opt["--weight", If[maxcut, "0", "1"]]];
  nat = PFBNaturalIntegrals[sys, red, key, <|"MaxWeight" -> w, "Extra" -> Replace[opt["--cands", None], {s_String :> ToExpression[s], None -> {}}]|>];
  cands = Join[nat["Candidates"], If[maxcut, PFBMaxCutScanCandidates[mc], {}]];
  If[nat["NotInPool"] =!= {}, Print[Length[nat["NotInPool"]], " natural integrals are not in the job's pool (add them with PoolExtra to try them): ", Short[nat["NotInPool"], 3]]];
  keep = Replace[opt["--keep", None], {s_String :> (ToExpression[s] /. Cur[k_] :> PFBMaster[sys, k]["RootFree"]), None -> <||>}];
  (* the sets: each slot a candidate (with the slot's own power of eps) or its current master; interchangeable slots in
     one order of their candidates; counted before they are built (PFBSlotSets) *)
  ss = PFBSlotSets[sys, slots, cands, <|"Keep" -> keep, "MaxSets" -> maxSets|>];
  symm = ss["Symmetric"]; nSets = ss["Count"];
  Print[PFBSectorString[key], ": slots ", ut /@ slots, ", ", Length[cands], " candidates", If[maxcut, " (" <> ToString[Length[mc["Candidates"]]] <> " from maximal-cut-basis, natural integrals of weight <= " <> ToString[w] <> ")",
    " of weight <= " <> ToString[w]], " (and the current masters), ", nSets, If[maxcut, " sets at most", " sets"]];
  If[nSets == 0,
    Print["nothing to scan: no natural integral of the sector is in the job's pool (", Length[nat["NotInPool"]], " missing): add them with PoolExtra, or scan with a job whose roots contain the sector"];
    CoreVerdict["pair_scan", "fail", <|"message" -> "no candidate in the job's pool", "notInPool" -> Length[nat["NotInPool"]]|>]];
  If[nSets > maxSets,
    Print["more than ", maxSets, " sets: lower --weight, give the candidates of the structural reading with --cands, fix a slot with --keep, or raise --max"];
    CoreVerdict["pair_scan", "fail", <|"message" -> ToString[nSets] <> " sets, above --max " <> ToString[maxSets], "sets" -> nSets|>]];
  sets = ss["Sets"];
  (* a timed pilot first (timing-discipline): the whole scan must fit the budget *)
  pilot = PFBScanSets[sys, sl, red, cal, key, Take[sets, UpTo[5]], <|"Census" -> c0, "State" -> ctx["State"]|>];
  est = N[Max[pilot["Seconds"], 1] Length[sets]/Min[5, Length[sets]]];
  Print["pilot: ", Min[5, Length[sets]], " sets in ", pilot["Seconds"], " s; the whole scan about ", Round[est/60.], " min"];
  If[est > 60 budget, Print["above the budget of ", budget, " min: narrow the candidates or raise --budget"];
    CoreVerdict["pair_scan", "fail", <|"message" -> "estimated " <> ToString[Round[est/60.]] <> " min, above --budget", "sets" -> Length[sets]|>]];
  scan = PFBScanSets[sys, sl, red, cal, key, sets, <|"Census" -> c0, "State" -> ctx["State"]|>];
  res = scan["Results"];
  (* interchangeable slots were scanned in one order of their candidates, but the maximal cut (and the normalisation to
     the master each one replaces) depends on the order: a set that clears the rows but changes the maximal cut is
     tried in the other orders too, and one that keeps it replaces it *)
  If[symm && Length[slots] > 1,
    res = Function[r, If[! (r["bad"] == 0 && TrueQ[r["maxCut"]]), r,
        SelectFirst[PFBScanSets[sys, sl, red, cal, key, Table[Join[r["set"], AssociationThread[slots -> Lookup[r["set"], slots][[p]]]],
            {p, Rest[Permutations[Range[Length[slots]]]]}], <|"Census" -> c0, "State" -> ctx["State"]|>]["Results"],
          #["bad"] == 0 && ! TrueQ[#["maxCut"]] &, r]]] /@ res];
  show[r_] := StringRiffle[Table["ut[" <> ToString[l] <> "] -> " <> If[r["set"][l] === PFBMaster[sys, l]["RootFree"], "current", ToString[r["set"][l], InputForm]], {l, slots}], ", "];
  Print[Length[res], " tried, ", scan["Dependent"], " dependent (det T = 0), ", scan["OutsidePool"], " outside the pool, in ", scan["Seconds"], " s"];
  (* the best set and what it leaves in the sector's rows, for the hidden-weight test before a flag *)
  PFBRecordScan[ctx["Dir"], key, res, <|"Rung" -> If[maxcut, 8, 3], "What" -> If[maxcut, "maximal-cut scan (bin/pair_scan.wls --maxcut)", "pair scan (bin/pair_scan.wls)"] <>
    ", slots " <> ToString[ut /@ slots] <> ", " <> ToString[Length[sets]] <> " sets"|>];
  (* the sector's new basis with every element dotted, on a non-dlog sector: it loses ties (the all-dot flag) *)
  allDot[r_] := maxcut && PFBMaxCutAllDotQ[sys, key, r["set"], Lookup[mc, "NonDlog", False]];
  Do[Print[r["bad"], " pole entries in the sector rows ", InputForm[r["factors"]], " | ", show[r],
     If[r["maxCut"], " (changes the maximal cut)", ""], If[allDot[r], " (all-dot)", ""],
     " | " <> ToString[r["zero"]] <> " entries with negative eps powers in the sector rows (" <> ToString[zero0] <> " now)",
     " | highest eps power " <> ToString[r["deg"] /. -Infinity -> "-"] <> ", " <> ToString[r["high"]] <> " entries of the sector rows above eps^" <> ToString[$PFBMaxEpsDegree] <>
       " (" <> ToString[high0] <> " now)" <> If[r["over"] > 0, ", " <> ToString[r["over"]] <> " raised", ""],
     If[MissingQ[r["dCensus"]], "", " | census " <> ToString[r["dCensus"]] <> ", new pole entries " <> ToString[r["newBad"]] <>
       If[r["deferred"] > 0, " (and " <> ToString[r["deferred"]] <> " deferred to their own sectors)", ""] <> " | negative eps powers " <> ToString[r["neg"]]],
     " | digit height ", r["height"]],
    {r, Take[res, UpTo[30]]}];
  (* ready for the gate: no pole left in the sector's rows, none new, nothing raised above the cap, and progress: the
     poles it had, or fewer entries with negative powers of eps or above the cap *)
  (* rung 8: the finalists through the maximal-cut-basis gate, ranked with its tie-breakers *)
  If[maxcut && ! MemberQ[a, "--no-check"],
    fin = PFBMaxCutFinalists[sys, key, res, <|"RunDir" -> ctx["Dir"], "MCBRun" -> mcRun, "Finalists" -> ToExpression[opt["--finalists", "3"]]|>];
    Print["\nfinalists (the maximal-cut-basis gate; ", fin["Message"], "):"];
    Do[Print[f["Rank"], ". ", StringRiffle[KeyValueMap["ut[" <> ToString[#1] <> "] -> " <> With[{t = ToString[#2, InputForm]}, If[StringLength[t] > 160, StringTake[t, 157] <> "...", t]] &, f["Defs"]], ", "], " | ",
       f["Verdict"]["Status"], Switch[f["Verdict"]["Check"], "eps-polynomial", " " <> ToString[f["Verdict"]["Range"]], "rational", " (rational in eps on the cut)", _, ""], ", Euler ",
       Which[f["Verdict"]["Euler"] === True, "ok", f["Verdict"]["Euler"] === False, "FAILED", True, "not checked"],
       If[TrueQ[f["Verdict"]["NonDlog"]] && TrueQ[f["Verdict"]["AllDot"]], ", all-dot", ""],
       If[f["Refused"], " | REFUSED: " <> f["Verdict"]["Message"], ""], If[TrueQ[f["NotChecked"]], " | NOT CHECKED: " <> f["Verdict"]["ToolFailure"], ""]], {f, fin["Finalists"]}];
    If[fin["Finalists"] =!= {} && ! First[fin["Finalists"]]["Refused"] && ! TrueQ[First[fin["Finalists"]]["NotChecked"]],
      Print["next: fin = PFBReadMaxCutFinalists[ctx[\"Dir\"], key]; PFBTryChange[ctx, key, fin[[1]][\"Defs\"], <|\"Rung\" -> 8, ...|>, <|\"Reds\" -> checkReds, ",
        "\"MaxCutCheck\" -> fin[[1]][\"Verdict\"]|>]: announce it to the user with the eps profile of the sector rows before and after"]]];
  With[{good = Select[res, #["bad"] == 0 && #["newBad"] === 0 && #["over"] == 0 && (hadPoles || #["zero"] < zero0 || #["high"] < high0) &]},
    If[good =!= {} && ! maxcut, Print["next: normalise the best set to the maximal-cut class of the masters it replaces (reference/escalation.md, rung 3) and send it through PFBTryChange with \"Rung\" -> 3",
      If[AnyTrue[good, #["maxCut"] &], "; a set that changes the maximal cut also passes the maximal-cut-basis gate (PFBTryChange runs it) and is announced to the user", ""]],
      If[good === {}, Print["no set clears the sector's rows", If[hadPoles, "", " and fewer entries with negative powers of eps or above eps^" <> ToString[$PFBMaxEpsDegree]],
        If[AnyTrue[res, #["bad"] == 0 && #["newBad"] === 0 && #["over"] > 0 &], " without raising an entry above the cap", ""],
        ": write in notes.md which entries and factors stay, then go on up the ladder"]]];
    CoreVerdict["pair_scan", "pass", <|"sector" -> a[[3]], "slots" -> slots, "sets" -> Length[sets], "tried" -> Length[res], "dependent" -> scan["Dependent"],
      "outsidePool" -> scan["OutsidePool"], "notInPool" -> Length[nat["NotInPool"]], "seconds" -> scan["Seconds"], "best" -> If[res === {}, Null, show[First[res]]],
      "poleFree" -> (<|"set" -> show[#], "maxCutChanged" -> #["maxCut"], "deferred" -> #["deferred"], "height" -> #["height"]|> & /@ good),
      "finalists" -> If[AssociationQ[fin], (<|"rank" -> #["Rank"], "changes" -> (ToString /@ Keys[#["Defs"]]), "status" -> #["Verdict"]["Status"], "range" -> #["Verdict"]["Range"],
          "euler" -> #["Verdict"]["Euler"], "allDot" -> (TrueQ[#["Verdict"]["NonDlog"]] && TrueQ[#["Verdict"]["AllDot"]]), "refused" -> #["Refused"],
          "notChecked" -> TrueQ[#["NotChecked"]]|> & /@ fin["Finalists"]), Null]|>]]];
