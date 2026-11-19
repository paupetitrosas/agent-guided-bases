(* ::Package:: *)

(* ::Title:: *)
(*{{SECTOR}}: removing the eps poles of the differential equation*)


(* ::Text:: *)
(*Written by the pole-free-basis skill ({{DATE}}); edit it freely. Run it with*)
(*    {{WS}} AnalysisPoles.m      (bin/ws waits for a free licence slot; keep any log of it outside the run folder)*)
(*or evaluate it section by section. Every proposal goes through PFBTryChange (or PFBTryRescale): the gate decides,*)
(*nothing else changes the basis. Write your reasoning in notes.md (PFBAppendNotes): it appears on the sector page.*)
(*Record every paper you take something from with PFBRecordLiterature[ctx["Dir"], key, <|"reference" -> ..., "used" -> ...|>],*)
(*or in the change itself (info "Reference"), and a tool you ran by hand in info "Tools" (a name of $MCBTools): the run's*)
(*CITATIONS.md lists them, with the tools the toolkit ran for this sector.*)


(* ::Section:: *)
(*1. Init*)


Get["{{LIBFILE}}"];
(* this kernel's tool marks start here: none left from an earlier session goes to this run *)
MCBResetToolsUsed[];
ctx = PFBStartRun["{{RUNFILE}}"];
sys = ctx["System"];
key = {{{FAMILY}}, {{SECTORLIST}}};
(* the tools used from here on are credited to this sector in the run's ledger (citations.m) *)
CoreCitationContext[ctx["Dir"], PFBSectorString[key], "AnalysisPoles.m"];
sl = PFBCurrentSlice[ctx["Dir"], ctx["State"]];
census = PFBCensus[sys, sl, PFBCensusOptions[ctx]];
sec = census["Sectors"][key];
Print[PFBSectorString[key], ": masters ", {#, PFBMaster[sys, #]["Family"], PFBMaster[sys, #]["Pos"]} & /@ sec["Rows"]];
Print[sec["Issues"], ": rows with poles ", ut /@ sec["BadRows"], ", factors ", sec["PoleFactors"], ", negative eps powers in ", ut /@ sec["EpsZeroRows"],
  If[sec["SelfBlockEpsZero"] =!= {}, " (own block: a new maximal-cut basis)", " (poles at eps = 0: the source test)"],
  ", above the cap in ", ut /@ sec["HighRows"], If[sec["SelfBlockHigh"] =!= {}, " (own block: a new maximal-cut basis)", ""]];
Print["own block poles: ", sec["SelfBlockPoles"], "; possibly inherited from ", PFBSectorString /@ sec["CouplesToBadLower"]];
(* a sector whose poles may come from a lower bad sector waits until that sector is done (bottom-up) *)
(* the census's hidden-weight hints: this clean sector may carry a factor that shows in the rows above (section 6b), or
   this sector's poles of a factor sit only in the columns of a clean lower sector's subtree (open that one first) *)
Print["possible hidden weight here: ", Select[census["HiddenWeights"], #["Sector"] === key &], "; below: ", Normal[sec["HiddenWeightBelow"]]];


(* ::Section:: *)
(*2. Where the poles come from*)


src = PFBSourceTest[sys, sl, census, key, <|"Flagged" -> Keys[Lookup[ctx["State"], "Flagged", <||>]],
   "Fixed" -> Union[Flatten[#["Replace"] & /@ Select[Lookup[ctx["State"], "Accepted", {}], Lookup[#, "Kind", "change"] =!= "rescale" &]]]|>];
(* new poles that changes of lower sectors deferred to this sector, moved poles included (Kind "moved": factors its rows
   had, carried into new columns): its fix must remove them too *)
Print["deferred here: ", PFBDeferredObligations[ctx["State"], key]];
Print[src["Outcome"], ": ", src["Message"]];
Print[{ut /@ #["Sources"], #["Kind"], #["Free"]} & /@ src["Passing"]];
(* "undecided": lower sectors that are still bad can change these rows: fix or flag them first, then test again.
   "SingleColumn": poles that sit in one lower master's column only, a possible hidden normalisation of that master.
   "HiddenWeight": the census's hints that concern this sector (section 6b for a clean sector that may carry one) *)
Print[{"wait for", ut /@ Lookup[src, "WaitFor", {}], "single column", Map[ut, Lookup[src, "SingleColumn", <||>], {2}], "hidden weight", Lookup[src, "HiddenWeight", {}]}];


(* ::Section:: *)
(*2b. The structure: sources pole by pole and the loop-by-loop reading (before any reduction or search)*)


(* for each pole factor, the smallest sets of the sector's masters whose replacement can remove it (the residue-column
   test pole by pole), and whether the sector's own block has it (then only a new maximal-cut basis helps) *)
byPole = PFBSourcesByPole[sys, sl, key];
Print[{#["factor"], "order " <> ToString[#["order"]], If[#["ownBlock"], "own block: maximal cut",
     "sources " <> ToString[Map[ut, #["sources"], {2}]]], "columns " <> ToString[ut /@ #["columns"]]} & /@ byPole];
(* the maximal cut loop by loop, every loop order: subloop of each Baikov polynomial, twist factors and kinds, the cost
   of numerator powers at infinity, master counts with and without the O(eps) factors, bulk and boundary geometry,
   and the cut integrands of the current masters and of their dotted variants with the forms they induce on the
   boundaries. Masters that live on the boundary of an O(eps) factor need dots on that subloop's propagators. *)
famObj = sys["Families"][key[[1]]]["Object"];
curInts = Union[Cases[PFBMaster[sys, #]["RootFree"] & /@ sec["Rows"], _j, Infinity]];
dotted = Union[Flatten[Table[ReplacePart[jj, i + 1 -> jj[[i + 1]] + 1], {jj, curInts}, {i, Flatten[Position[key[[2]], 1]]}]]];
(* rung 2's candidates: the dots of dotted masters moved to another propagator (they go into the pool of section 4) *)
dotMoves = Union[Flatten[Table[Prepend[Table[Head[c][im, Sequence @@ Rest[c]], {im, PFBImagesOf[sys, c[[1]]]}], c],
   {c, Union[Flatten[PFBDotCandidates[sys, None, #]["Candidates"] & /@ sec["Rows"]]]}]]];   (* and their images *)
lbl = MCBLoopByLoopReport[famObj, key[[2]], <|"KiraMasters" -> Length[sec["Rows"]], "Integrals" -> Join[curInts, dotted]|>];


(* ::Section:: *)
(*3. Rung 1: powers of eps*)


(* on the whole slice, before the first sector (rerun it when a sector's rows have negative powers of eps or entries
   above the cap). Entries above the cap (run.wl "MaxEpsDegree") are brought down where a uniform eps^k can
   (rs["Strict"]); negative powers it leaves are poles at eps = 0 for the source test (section 2), a new
   maximal-cut basis (section 11) when they sit in the own block. rs["MinimalCap"] is for
   the user only: never raise the cap to make a rescale pass *)
rs = PFBRescaleSearch[sys, sl];
Print[rs];
(* If[rs["Feasible"], r = PFBTryRescale[ctx, rs["Shifts"], <|"Provenance" -> "uniform eps^k: negative powers of eps in the rows of ..."|>];
     ctx = r["Context"]; sl = r["Slice"]]; *)


(* ::Section:: *)
(*4. A reduction of the sector's subtree*)


(* at the slice point, the points of the fits, and two more that no fit sees: the gate checks fitted coefficients there.
   The pool is what the structural reading needs, no more: every pool integral and its derivatives are reconstructed at
   every point, so the time of a point grows with the pool (with a generic pool it took as long as the IBP solve itself).
   PoolSpec {1, 1, 0, 0} holds the sector's natural integrals (the pair scan's candidates) and the corners of its
   one-propagator subsectors; the runner adds the integrals of the sector's current masters; PoolExtra adds the
   candidates of section 2b (the dotted variants, rung 2's dot moves, numerators that vanish on the cut, ...).
   A rung that needs more widens the pool for its own job: the residue fit's pinched integrals ({1, 1, 2, 1}), the
   completion's lower integrals ({2, 2, 2, 1}). The job folder belongs to this specification and this basis: after an
   accepted change, or to change points, seeds or pool, give a new "Name" or "Replace" -> True. *)
job = PFBSubtreeJob[sys, ctx["Dir"], <|"Name" -> "{{JOBNAME}}", "SectorKey" -> key,
   "Points" -> Join[{sl["Point"]}, PFBRandomPoints[sys, ctx["Run"]["ExtraPoints"] + 2, 1]], "Derivatives" -> sl["Derivatives"],
   "Seeds" -> ctx["Run"]["Seeds"], "MaxGB" -> ctx["Run"]["MaxGB"], "TimeLimit" -> ctx["Run"]["TimeLimit"],
   "Threads" -> Replace[ctx["Run"]["Threads"], Automatic -> Max[1, Min[8, $ProcessorCount - 1]]], "Reducer" -> Lookup[ctx["Run"], "Reducer", Automatic],
   "PoolSpec" -> {1, 1, 0, 0}, "PoolExtra" -> Union[dotted, dotMoves]|>];
(* run it from the shell (it needs a licence slot of its own):  sh <job folder>/command.sh
   and wait for it without a kernel:  bin/wait_job <job folder> --timeout <from a pilot>   (never a loop of your own; a
   killed job resumes at its first missing point when its command runs again) *)
(* a subtree that keeps a master the system lacks (status "nonut", or "NonUT" in status.m): give the job "AllowNonUT" -> True
   (a job that already ran: a new "Name" with "ReuseIds" -> "<old job>/ibps", since "Replace" deletes its identities)
   and remove that master exactly with bin/extra_masters.wls, or find once the sector that supplies the missing relation
   with bin/relation_sector.wls and add it with "ExtraRoots"; never whole-family reductions (reference/workflow.md) *)
Export[FileNameJoin[{job, "command.sh"}], PFBSubtreeCommand[job] <> "\n", "Text"];
Print[PFBSubtreeStatus[job]];
reds = Get /@ PFBRedFiles[job];
(* the fits use the slice point and the points after it except the last two; the gate verifies on the last two *)
fitReds = Drop[reds, -Min[2, Max[0, Length[reds] - 1]]];
checkReds = If[Length[reds] >= 3, Join[{First[reds]}, Take[reds, -2]], Take[reds, UpTo[1]]];
If[reds =!= {}, PFBImportMemory[job]; cal = PFBCalibrate[sl, First[reds]]; Print["calibration: ", cal["Status"], " ", cal["Message"]]];


(* ::Section:: *)
(*5. Rung 2: move a dot*)


(* for a source whose definition contains a dot: the same integrals with the dot on another propagator of the sector.
   Rank them exactly on the slice (dry run, nothing recorded), then normalise the winner to the source's maximal-cut
   class: its coefficient on the source is a power of eps times a rational function, which FiniteFlow reconstructs
   (never guess it from the reduction points):
     bin/ws bin/coefficients.wls run.wl <job> "{<winner>}"   then, once its job is done,   ... --collect --source <label>
   (or an = PFBAnalyticCoefficients[<job>_a]; PFBNormaliseCandidate[sys, an, 1, <label>]["Def"]),
   and send it through section 12 with "Rung" -> 2:
   dots = PFBDotCandidates[sys, First[reds], First[First[src["Passing"]]["Sources"]]];
   Print[dots["Candidates"], " not in the pool: ", dots["NotInPool"]];
   bin/ws bin/slot_scan.wls run.wl <job> "<|...the sector's other masters...|>" <source label> "<dots[\"Candidates\"]>" *)


(* ::Section:: *)
(*6. Rung 3: pairs of natural integrals (minutes; before any fit or completion)*)


(* the sector's own integrals with few dots and numerators, and the candidates of section 2b, in two or three slots at
   once, exactly on the slice (dry runs). Each slot may keep its current master, so single replacements come too. Run
   it from the shell (it needs a licence slot of its own; it times a pilot and stops above its budget):
   bin/ws bin/pair_scan.wls run.wl <job> {{SECTOR}} [--slots "{l1, l2}"] [--weight 1] [--cands "{...}"]
   The natural integrals the job's pool lacks, to add with PoolExtra before the scan:
   Print[PFBNaturalIntegrals[sys, First[reds], key, <|"MaxWeight" -> 1|>]["NotInPool"]];
   A set that clears the sector's rows is normalised like the dot move and goes through section 12 with "Rung" -> 3; for one that changes the maximal cut, PFBTryChange also runs the maximal-cut-basis gate (section 11).
   No set: write in notes.md which entries and factors stay, then go on. *)


(* ::Section:: *)
(*6b. A hidden weight on this clean sector (the census's hint, or the hidden-weight test of a sector above)*)


(* this sector's rows are clean, but the rows above carry a factor w only in the columns of its subtree: one of its
   masters may be w J with J honest (method.md, "A hidden weight on a clean lower sector"). The lower-sector scan tries
   sets of its masters (its natural integrals, the structural reading's candidates, full definitions in "Candidates", and
   its maximal-cut-basis candidates when bin/maxcut_candidates.wls wrote them for this sector)
   on the slice, judged on the rows above that carry w; its own rows must stay free of finite poles. The job of
   section 4 (this sector's subtree) is all it needs: the rows above change through this sector's columns. "RunDir"
   records it in attempts.m, so the census no longer makes this sector "Next" for w. From the shell:
   bin/ws bin/pair_scan.wls run.wl <job> {{SECTOR}} --hidden-weight [--factor "1 + 4 eps"] [--cands "{...}"]
   hws = PFBHiddenWeightScan[sys, sl, First[reds], cal, key, <|"Census" -> census, "State" -> ctx["State"], "RunDir" -> ctx["Dir"],
      "Candidates" -> {}|>];
   Print[hws["Message"]]; Print[Take[{#["set"], #["above"], #["newBad"]} & /@ hws["Results"], UpTo[5]]];
   The winner goes through section 12 (normalised, with checkReds). *)


(* ::Section:: *)
(*7. Rung 4: residue fit with pinched corners*)


(* sources from section 2; the other rows of the sector are the test rows *)
(* srcs = First[src["Passing"]]["Sources"]; oth = Complement[sec["Rows"], srcs];
   cands = PFBPinchedCandidates[sys, First[reds], key, <|"MaxPinched" -> 1|>];
   fit = PFBResidueFit[sys, sl, First[reds], cal, srcs, oth, cands];
   Print[fit["Status"], " integer coefficients: ", fit["Integer"]]; Print[fit["Coefficients"]];
   (* integer coefficients: read them as one numerator *)
   Print[PFBNumeratorFromFit[sys, MCBCornerIntegral[PFBFamily[sys, key[[1]]], key[[2]]], fit["Coefficients"][First[srcs]]]]; *)


(* ::Section:: *)
(*8. Rung 5: a numerator written as a scalar product*)


(* num = PFBSPToNumerator[sys, key[[1]], <scalar product, e.g. 2 (k1 + k2) p4 - qq>];
   def = PFBNumeratorIntegrals[sys, MCBCornerIntegral[PFBFamily[sys, key[[1]]], key[[2]]], num]; *)


(* ::Section:: *)
(*9. Rung 6: completion solver (only after the scans of sections 5 and 6 found nothing)*)


(* every entry of the new rows at or below the cap; comp["AboveCapKept"]: only the poles could be removed
   comp = PFBCompletionSolve[sys, fitReds, key, <|"Target" -> ctx["Run"]["Target"]|>];
   Print[comp["Status"], ": ", comp["Message"]]; *)


(* ::Section:: *)
(*10. Rung 7: derivatives of clean masters*)


(* ders = PFBDerivativeSearch[sys, sl, key, First[src["Passing"]]["Sources"]];
   Print[Take[{#["Replace"], #["From"], #["Ops"], #["Det"]} & /@ ders, UpTo[5]]]; *)


(* ::Section:: *)
(*11. Rung 8: a new maximal-cut basis, with the maximal-cut-basis toolkit*)


(* The family's maximal-cut-basis run (system.wl "MCBRun", read only; else this skill's own in <run>/maxcut/<fam>/) gives
   the candidates, in this kernel: its basis of the sector, its candidate steps replayed, its candidate routes (dlog
   candidates normalised by their leading singularities, curve candidates, single integrals), plus the structural
   reading's (section 2b). Before any reduction they are filtered by the hard rules 1, 2 and 4 and by the square root of
   the master each replaces. Then one reduction with them in the pool, the pair scan over the sector's slots ranked by
   the full rows, and the best few sets that clear them (the finalists) through the maximal-cut-basis gate (Kira on the
   cut at two points, the Euler relation): a failed check refuses a set; eps-form on the cut breaks ties among the sets
   that clear the rows, then an eps-polynomial DE with the smaller spread, then, on a non-dlog sector, a set with an
   undotted element, then the smaller digit height of the rows. eps-form is never a requirement. From the shell, one kernel each:
     bin/ws bin/maxcut_candidates.wls run.wl {{SECTOR}} [--cands "{...the structural reading's...}"]
     sh <its job>/command.sh;  bin/wait_job <its job> --timeout <from a pilot>
     bin/ws bin/pair_scan.wls run.wl <its job> {{SECTOR}} --maxcut
   then, with the reductions of that job (section 4 with its name) as checkReds:
   fin = PFBReadMaxCutFinalists[ctx["Dir"], key];
   Print[{#["Rank"], Keys[#["Defs"]], #["Verdict"]["Status"], #["Verdict"]["Range"], #["Verdict"]["AllDot"], #["Refused"]} & /@ fin];
   and section 12 with newDefs = fin[[1]]["Defs"], "Rung" -> 8, "Fitted" -> False and "MaxCutCheck" -> fin[[1]]["Verdict"].
   A paper's canonical basis of the same topology is a candidate too (--cands with its root-free definitions; record the
   paper). PFBWriteMCBBasisFile writes a set for maximal-cut-basis's check_basis.wls, if you want its page. *)


(* ::Section:: *)
(*12. Try a change*)


(* newDefs: <|label -> root-free definition|> for the masters of the base family; the images follow by the maps *)
(* "Fitted" -> True for coefficients that came from a fit (rungs 2 to 7): the gate then wants them confirmed at the
   checkReds points, which no fit has seen *)
(* a change that alters the maximal cut (rung 8, or a scanned set of rung 3) also passes the maximal-cut-basis gate: give
   the finalist's verdict ("MaxCutCheck" -> fin[[1]]["Verdict"]: taken when it is Kira's on exactly this sector basis), or
   PFBTryChange runs it (Kira on the cut, minutes); Kira failing leaves the change "not tried", and a machine without Kira
   skips the check, recorded as not verified *)
(* a paper the change came from: info "Reference" -> "authors, title, arXiv:..." (or a list, or <|"reference", "used"|>),
   recorded with the change's outcome; a tool run by hand for it: info "Tools" -> {"..."} (names of $MCBTools) *)
(* r = PFBTryChange[ctx, key, newDefs, <|"Rung" -> 6, "Provenance" -> "...", "Sources" -> src["Passing"][[1]]["Sources"]|>,
     <|"Reds" -> checkReds, "Fitted" -> True|>];
   Print[r["Status"]]; Print[If[KeyExistsQ[r, "Gate"], r["Gate"]["Message"], r["Message"]]];   (* "not tried": no gate, the reason is in r["Message"] *)
   ctx = r["Context"]; If[KeyExistsQ[r, "Slice"], sl = r["Slice"]]; *)


(* ::Section:: *)
(*13. Records*)


PFBWriteSectorRecord[ctx["Dir"], ctx["System"], ctx["State"], PFBCensus[ctx["System"], PFBCurrentSlice[ctx["Dir"], ctx["State"]], PFBCensusOptions[ctx]], key];
(* nothing worked within the limits: first the hidden-weight test. When the pole factor the attempts left always sits in
   the columns of one clean lower sector's subtree, that sector may carry it: PFBFlagSector refuses until that sector's
   lower-sector scan is recorded (its section 6b), "Force" -> True flags anyway
   hwt = PFBHiddenWeightTest[ctx, key]; Print[hwt["Message"]];
   ctx["State"] = PFBFlagSector[ctx, key, "<why>", {"<rungs tried>"}]; *)
