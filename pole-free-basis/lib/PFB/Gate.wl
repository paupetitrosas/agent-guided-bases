(* ::Package:: *)

(* ::Title:: *)
(*PoleFreeBasis`Gate`: when a basis change is accepted*)


(* ::Text:: *)
(*A change is accepted only when every check passes:*)
(*  rules        each new master: one power of eps per integral, no eps in a denominator, coefficients rational in the*)
(*               invariants (its square-root prefactor apart); ut[k] terms are checked through what they contain;*)
(*  letters      with an alphabet ("Letters"), every denominator factor of a new coefficient is a letter;*)
(*  weights      each new master is homogeneous (one mass dimension, its Euler weight) and keeps the weight of the*)
(*               master it replaces or is dimensionless (a new maximal-cut basis may fix bare integrals);*)
(*  euler        the new rows satisfy Sum_X d_X X R_X = diag(weights); not checked when the slice has no derivative*)
(*               in some invariant of non-zero dimension (a unit scale set to 1);*)
(*  frozen       no master of a frozen family changes;*)
(*  rows         the sector's rows are free of finite eps poles, exactly in eps; rows coupling to its masters keep the*)
(*               poles they had (their own sectors come later, bottom-up) and may gain new ones only when*)
(*               PFBDeferredPoles defers them to their own sector (a necessary condition for its fix: factors the change*)
(*               removed from its own rows, or moved poles, factors that sector's rows had); for a rescale*)
(*               (uniform eps^k, which cannot move finite poles) only: no rescaled row gains a finite pole;*)
(*  census       the census removes bad entries: finite poles (from the sector's own rows when any is deferred), negative*)
(*               powers of eps or entries above the cap; it has no new finite pole*)
(*               except deferred ones; new negative*)
(*               powers of eps are allowed only when a uniform eps^k (rung 1) removes them, so never on the diagonal, and*)
(*               without pushing an entry above the cap;*)
(*  degree       no entry ends above eps^cap ("MaxEpsDegree", default $PFBMaxEpsDegree = 2) at eps -> infinity, finite poles*)
(*               or not, unless it was above the cap before, and then not above its own earlier power (with its poles,*)
(*               for an entry whose poles the change removes);*)
(*  points       coefficients that were fitted are confirmed at two or more points besides the slice point;*)
(*  maximal cut  for a change that alters the maximal cut, the maximal-cut-basis gate on the new sector basis (Kira on*)
(*               the cut, the Euler relation): PFBTryChange adds it (PFBMaxCutGateCheck, MaxCut.wl); eps-form not required.*)
(*The determinant of the new masters on the replaced ones is recorded, not judged: it only has to be non-zero, or the*)
(*change cannot be applied (PFBApplyChange).*)


BeginPackage["PoleFreeBasis`Gate`", {"MaximalCutBasis`Rules`", "PoleFreeBasis`", "PoleFreeBasis`Config`", "PoleFreeBasis`System`", "PoleFreeBasis`Slice`", "PoleFreeBasis`Residues`", "PoleFreeBasis`Rungs`",
  "PoleFreeBasis`Census`", "PoleFreeBasis`Transform`", "MaximalCutBasis`"}];

PFBGate::usage = "PFBGate[sys, slOld, censusOld, slNew, change, opts] runs the checks of a change. change: <|\"Name\", \"Key\", \"Replace\", \"NewDefs\" (root-free), \"Fitted\" -> True/False, \"PointsVerified\" -> n, \"Kind\" -> \"rescale\" | \"change\"|>. opts: \"MinPoints\" (2: extra points for fitted coefficients), \"MaxEpsDegree\" (default $PFBMaxEpsDegree: no entry may end above eps^cap at eps -> infinity, finite poles or not, unless it was above it before and does not rise; Infinity for no cap), \"DeferPoles\", \"NoDefer\". Returns <|\"Pass\", \"Checks\", \"Census\", \"Comparison\", \"Message\"|>.";
PFBVerifyAtPoints::usage = "PFBVerifyAtPoints[sys, reds, key, newDefs, prefs, opts] checks a change at reduction points away from the slice: the rows of the sector in the new basis must be free of finite eps poles, and of negative powers of eps except where opts \"EpsZeroAllowed\" -> <|{derivative, row, column} -> lowest order|> (the new slice's own, which the slice gate judges) allows them, down to that order; and no entry may rise above eps^cap (opts \"MaxEpsDegree\", default $PFBMaxEpsDegree) except where opts \"DegreeAllowed\" -> <|{derivative, row, column} -> highest power|> (the new slice's own) allows it, up to that power. Every reduction needs the new definitions' integrals in its pool and only system masters (bin/extra_masters.wls removes the others exactly). A reduction at opts \"SlicePoint\" (the slice's point), or at the point of an earlier reduction, confirms nothing new: it is ignored and reported (PFBDistinctPoints). Returns <|\"Pass\", \"Points\" -> n, \"Detail\", \"Ignored\" -> {{point, reason}..}|>.";
PFBDistinctPoints::usage = "PFBDistinctPoints[reds, slicePoint] keeps the reductions whose \"Point\" is an extra point: neither slicePoint (None: no slice point given) nor the point of an earlier reduction in the list (points compared as sets of rules). Returns <|\"Reds\" (kept, in order), \"Ignored\" -> {{point, reason}..}|>.";
PFBBlockProfile::usage = "PFBBlockProfile[sl, rows, cols] = <|\"Range\" -> {lo, hi} | \"pole\", \"Counts\" -> <|range -> n|>|>: the eps profile of a block of the slice.";
PFBRowsCouplingTo::usage = "PFBRowsCouplingTo[sl, labels] lists the rows with a non-zero entry in the columns labels (the labels excluded).";
PFBSimplifyGate::usage = "PFBSimplifyGate[gate, sys, slOld, censusOld, slNew, change, opts] are the checks of a simplification move (PFBTryChange with \"Rung\" -> \"simplify\"), from gate = PFBGate of the change as kind \"change\": rules, letters, weights, Euler relation, frozen families and the cap are kept; \"rows\" (no row gains a finite pole), \"census\" (no new pole, negative power of eps or entry above the cap; the census need not lose a bad entry), \"eps-form blocks\" (every sector's own block that is eps-form, or zero, stays so), \"eps structure\" (no row's lowest power of eps drops, every eps-form row stays so: PFBEpsFloorViolations) and \"kinematic degrees\" (opts \"Degrees\" -> <|\"Before\", \"After\" (degree summaries), \"Measured\" -> True, \"Jobs\", \"OffSlice\"|>: {highest, terms at it, sum} must drop, as FFAllDegrees measured it) and \"away from the slice\" (\"OffSlice\" -> <|\"Pass\", \"Detail\"|>: the measured rows show, at the degree jobs' own points, no finite pole, nothing above the cap and no negative power of eps they did not have; not checked without it) replace the rows, census and points checks. Returns <|\"Pass\", \"Checks\", \"Census\", \"Comparison\", \"Message\"|>.";
PFBObjectiveLess::usage = "PFBObjectiveLess[a, b] is True when the objective a = {highest degree, terms at it, sum} is lexicographically below b (numbers; -Infinity for no term).";

PFBScanSets::usage = "PFBScanSets[sys, sl, red, cal, key, sets, opts] tries candidate sets of new masters of the sector key exactly on the slice, as dry runs of the gate's slice checks (nothing is recorded, the gate is not called): each set is <|label -> root-free definition|> for base-family masters, the image families follow by the maps. Per set: \"bad\" (pole entries left in the sector's rows) and their \"factors\", \"zero\" (entries of the sector's rows with negative powers of eps: poles at eps = 0), \"over\" (entries the set raises above eps^cap, opts \"MaxEpsDegree\", default $PFBMaxEpsDegree: in the sector's rows, and in every row when the census is computed; the gate refuses them), \"high\" (entries of the sector's rows left above the cap: bad entries still to fix) and \"deg\" (the highest power of eps in the sector's rows, without finite poles), \"maxCut\" (the set changes the sector's maximal-cut basis), \"height\" (the digit height of the sector's rows on the new slice, PFBRowsDigitHeight), and, when the sector's rows come out pole-free or opts \"FullCensus\" -> True, \"dCensus\", \"newBad\", \"deferred\" (new poles above that the gate would defer to their own sectors) and \"neg\" (entries with negative powers of eps). \"Results\" are ranked by PFBScanKey, whose last key, the digit height, orders only sets equal on every other key. \"left\": the pole entries left in the sector's rows, {row, column, factors} over every derivative (what PFBRecordScan stores for the hidden-weight test). opts: \"Census\" (of sl), \"State\" (the run state: flagged and fixed sectors are never deferred to), \"FullCensus\" (False), \"HiddenWeight\" -> <|\"Factors\" -> {w, ...}, \"Rows\" -> rows above|> (the lower-sector scan of a clean sector, PFBHiddenWeightScan: \"above\" counts the entries of those rows with a pole of a factor w; a set must keep the sector's own rows free of finite poles, the others are returned under \"RankedOut\"; the rest rank by \"above\" first, then as usual). Returns <|\"Results\" (best first), \"Dependent\" (sets with det T = 0), \"OutsidePool\", \"Seconds\"|>, and with \"HiddenWeight\" also \"RankedOut\" and \"AboveBefore\" (those entries on sl).";
PFBScanKey::usage = "PFBScanKey[result] is the key by which PFBScanSets orders its results (smallest first): pole entries left in the sector's rows, new poles, entries raised above the cap, negative powers of eps and entries above the cap left in the sector's rows, deferred poles, the change of the census, negative powers of eps in the census, the highest power of eps in the sector's rows, and last the digit height of the sector's rows on the new slice (\"height\", PFBRowsDigitHeight), which orders only results equal on every other key. A key the result lacks counts as the worst; PFBMaxCutRank orders the finalists of a maximal-cut scan by it first.";
PFBSlotSets::usage = "PFBSlotSets[sys, slots, cands, opts] builds the candidate sets of a scan over a sector's slots (bin/pair_scan.wls, PFBHiddenWeightScan): every slot takes a candidate or keeps its current master (its root-free definition), at least one slot changes, a candidate integral j[...] carries the slot's own lowest power of eps (other candidates, full root-free definitions, are used as given; a candidate <|slot -> root-free def, ...|>, such as a maximal-cut-basis candidate from PFBMaxCutCandidates, takes in each slot its definition there and is not tried in a slot it does not name), a candidate equal to a slot's master is not tried there, and slots with the same prefactor and power of eps are interchangeable (one order of their candidates). opts: \"Keep\" (<|label -> def|> fixed in every set), \"MaxSets\" (Infinity: above it no set is built). Returns <|\"Sets\", \"Count\" (counted before they are built), \"Symmetric\", \"TooMany\"|>.";
PFBHiddenWeightScan::usage = "PFBHiddenWeightScan[sys, sl, red, cal, key, opts] is the lower-sector scan of a clean sector S that may carry a hidden weight w (PFBCensus \"HiddenWeights\", PFBHiddenWeightTest): sets over S's masters, judged on the rows above that carry w, with S's own rows kept free of finite poles. red is a reduction of S's subtree at the slice point (calibrated: cal); the rows above change exactly through the change of S's columns (T^-1, and -R_rm lambda for the lower columns), as the gate computes them. opts: \"Factors\" (default: the census's hints on S), \"Rows\" (default: every row outside S's subtree that couples to S's masters and has a pole of those factors), \"Slots\" (default: S's base-family masters when at most three, else those whose columns carry the factors), \"MaxWeight\" (1: S's natural integrals, PFBNaturalIntegrals), \"Candidates\" (more candidates: integrals of the structural reading, or full root-free definitions), \"MaxCut\" (Automatic: with \"RunDir\", S's maximal-cut-basis candidates from maxcut_candidates.m join them, when bin/maxcut_candidates.wls wrote them; False: not), \"Sets\" (sets given whole, scanned too), \"Keep\", \"MaxSets\" (3000), \"BudgetMinutes\" (Infinity: a timed pilot of five sets refuses a longer scan), \"Census\", \"State\", \"RunDir\" (records the scan in S's attempts.m, PFBRecordScan, which the census and PFBFlagSector read). Returns <|\"Status\" (\"done\", \"no factor\", \"no slots\", \"too many\", \"over budget\"), \"Factors\", \"Rows\", \"Slots\", \"Candidates\", \"NotInPool\", \"Results\" (best first: fewest entries with w left in those rows, then the usual keys of PFBScanSets), \"RankedOut\" (sets that put a finite pole into S's own rows), \"AboveBefore\", \"Clearing\" and \"ClearingSets\" (the sets that leave no entry with w in those rows, no new pole and nothing raised above the cap), \"Sets\", \"Seconds\", \"Message\"|>. With \"RunDir\", a scan that cannot run (no slots, too many sets, over budget) is recorded too, with its reason: the hint is then tried (PFBHiddenWeightTried).";
PFBDeferredPoles::usage = "PFBDeferredPoles[sys, slOld, slNew, cOld, cNew, newBad, opts] sorts the new poles of a change in rows above it (newBad: \"NewBad\" entries of PFBCompareCensus) by the sector K of their rows: \"Deferred\" -> <|K -> <|\"Rows\", \"Sources\" (a proper subset of K's masters through which all of K's poles, old and new, factor), \"Verified\" (False for a sector of one master)|>|> for poles of factors the change removed from its own rows (opts \"Removed\", \"SectorRows\"), \"Moved\" -> <|K -> <|\"Rows\", \"Factors\", \"Entries\" ({derivative, row, column, factor})|>|> for moved poles, of factors K's rows had before the change (no source condition, but the census as a whole must lose bad entries), or \"Refused\" -> <|K -> reason|>. Deferred only when K can still change (not in opts \"NoDefer\", no frozen family) and the change replaces none of K's masters (opts \"Replaced\"); a fresh factor refuses K. A necessary condition for K's own fix, not a guarantee.";

Begin["`Private`"];


PFBBlockProfile[sl_Association, rows_List, cols_List] := Module[{ix = sl["Index"], rg, cnt},
  rg = DeleteCases[Flatten[Table[PFBEpsRange[sl["R"][[k, ix[r], ix[c]]]], {k, Length[sl["R"]]}, {r, rows}, {c, cols}], 2], "zero"];
  cnt = Counts[rg];
  <|"Range" -> Which[rg === {}, "zero", MemberQ[rg, "pole"], "pole", True, {Min[rg[[All, 1]]], Max[rg[[All, 2]]]}], "Counts" -> cnt|>];

PFBRowsCouplingTo[sl_Association, labs_List] := Module[{ix = sl["Index"], cols = sl["Index"] /@ labs},
  Complement[Select[sl["Labels"], Function[r, AnyTrue[Range[Length[sl["R"]]], Function[k, AnyTrue[sl["R"][[k, ix[r], cols]], # =!= 0 &]]]]], labs]];

rowPoleFree[sl_, r_] := AllTrue[Flatten[Table[sl["R"][[k, sl["Index"][r]]], {k, Length[sl["R"]]}]], # === 0 || PFBEpsFactors[#] === {} &];
check[name_, pass_, detail_] := <|"Name" -> name, "Pass" -> TrueQ[pass], "Detail" -> detail|>;


(* ::Section:: *)
(*Deferred poles, the scans and the gate*)


(* New poles in the rows of a sector K above the change: K's rows lost R_rm lambda_S (rows coupling to the changed
   master m). A correct lower fix can do that, and K's own fix may remove them later. Deferred only when:
   - K can still change: not flagged, not already fixed by an accepted change ("NoDefer"), no frozen family;
   - the change replaces none of K's masters ("Replaced"): rows it rewrote must be pole-free now;
   - every new pole carries a factor the change removed from its own rows (lambda's poles) or a factor K's rows had
     before the change (a moved pole: R_rm lambda_S carries R_rm's factors into column S), never a fresh factor;
   - for lambda's poles: K's poles, old and new together, still factor through one proper subset of its masters at
     every pole, as for a source of K (PFBSourceTest without lower sources), so that K stays a "source" sector. A
     sector of one master qualifies unverified: its own row changes through d lambda, which the slice cannot check;
   - for moved poles: the census as a whole loses bad entries (finite poles, negative powers of eps, entries above
     the cap). The source condition is not asked: K had the factor already, and its own fix has to remove it anyway.
     A new pole of a factor the change removed, in a sector that fails the source condition, is a moved pole when K's
     rows had that factor too.
   This is a necessary condition, not a guarantee that K's honest fix exists. *)
PFBDeferredPoles[sys_Association, slOld_Association, slNew_Association, cOld_Association, cNew_Association, newBad_List, opts_Association : <||>] :=
  Module[{rowsByK, out = <||>, moved = <||>, refused = <||>, sec = Lookup[opts, "SectorRows", {}], noDefer = Lookup[opts, "NoDefer", {}], removedF, nBad, loses},
  removedF = Union[Cases[Lookup[opts, "Removed", {}], {_, r_, _, f_} /; MemberQ[sec, r] :> f]];
  (* the bad entries of a census: entries with finite poles, negative powers of eps or above the cap *)
  nBad[c_] := Length[Union[c["BadEntries"][[All, 1 ;; 3]], Lookup[c, "EpsZero", {}][[All, 1 ;; 3]], Lookup[c, "HighDegree", {}][[All, 1 ;; 3]]]];
  loses = nBad[cNew] < nBad[cOld];
  rowsByK = GroupBy[Union[newBad[[All, 2]]], PFBMaster[sys, #]["SectorKey"] &];
  KeyValueMap[Function[{K, krows}, Module[{kl = Intersection[PFBSectorMasters[sys, K], slNew["Labels"]], nPos, ents, oldF, fresh, lamE, movE, lam = None, why = None, st},
      nPos = Length[Union[PFBMaster[sys, #]["Pos"] & /@ kl]];
      ents = Select[newBad, MemberQ[krows, #[[2]]] &];
      oldF = Lookup[Lookup[cOld["Sectors"], Key[K], <||>], "PoleFactors", {}];
      fresh = Complement[Union[ents[[All, 4]]], removedF, oldF];
      Which[
        MemberQ[noDefer, K], refused[K] = "flagged, or already fixed by an accepted change",
        (* a change that also replaces masters of K must leave their rows pole-free: it is K's fix itself *)
        IntersectingQ[kl, Lookup[opts, "Replaced", {}]], refused[K] = "the change replaces masters of this sector itself",
        AnyTrue[kl, PFBFrozenQ[sys, PFBMaster[sys, #]["Family"]] &], refused[K] = "a frozen family: its masters never change",
        fresh =!= {}, refused[K] = "new factors " <> ToString[fresh, InputForm] <> " that the change did not remove from its own rows and that this sector's rows did not have",
        True,
          lamE = Select[ents, MemberQ[removedF, #[[4]]] &]; movE = Complement[ents, lamE];
          If[lamE =!= {},
            Which[
              Lookup[Lookup[cNew["Sectors"], Key[K], <||>], "SelfBlockPoles", {}] =!= {}, why = "its own block has finite poles",
              nPos == 1, lam = <|"Rows" -> Union[lamE[[All, 2]]], "Sources" -> kl, "Verified" -> False|>,
              True,
                st = PFBSourceTest[sys, slNew, cNew, K, <|"MaxLowerSources" -> 0, "PolesOnly" -> True|>];
                If[st["Outcome"] === "source",
                  lam = <|"Rows" -> Union[lamE[[All, 2]]], "Sources" -> First[st["Passing"]]["Sources"], "Verified" -> True|>,
                  why = If[st["Outcome"] === "maximal-cut", "its own block has finite poles",
                    "its poles, old and new together, no longer factor through one proper subset of its masters"]]];
            (* lambda's poles of a factor that K's rows had before can still be moved poles *)
            If[StringQ[why], movE = Join[movE, Select[lamE, MemberQ[oldF, #[[4]]] &]]; lamE = Select[lamE, ! MemberQ[oldF, #[[4]]] &]]];
          Which[
            StringQ[why] && lamE =!= {}, refused[K] = why,
            movE =!= {} && ! loses, refused[K] = "moved poles (factors " <> ToString[Union[movE[[All, 4]]], InputForm] <>
              ", which its rows had before), but the census as a whole does not lose bad entries (" <> ToString[nBad[cOld]] <> " -> " <> ToString[nBad[cNew]] <> ")",
            True,
              If[AssociationQ[lam], out[K] = lam];
              If[movE =!= {}, moved[K] = <|"Rows" -> Union[movE[[All, 2]]], "Factors" -> Union[movE[[All, 4]]],
                "Entries" -> ({slNew["Derivatives"][[#[[1]]]], #[[2]], #[[3]], #[[4]]} & /@ movE)|>]]]]], rowsByK];
  <|"Deferred" -> out, "Moved" -> moved, "Refused" -> refused|>];

(* Dry runs of candidate sets on the slice, for bin/slot_scan.wls and bin/pair_scan.wls. The sector's rows are read
   straight from the new slice; the full census (the costly part on a large slice) only for sets that clear them,
   unless "FullCensus" -> True: a set that leaves poles in its own rows is ranked below every set that clears them. *)
PFBScanSets[sys_Association, sl_Association, red_Association, cal_Association, key_List, sets_List, opts_Association : <||>] := Module[{c0, st, rows, ix = sl["Index"],
    sec, res = {}, nDep = 0, nOut = 0, noDefer, full = TrueQ[Lookup[opts, "FullCensus", False]], t0 = AbsoluteTime[], cap = Lookup[opts, "MaxEpsDegree", $PFBMaxEpsDegree],
    ceil0, hw = Lookup[opts, "HiddenWeight", None], aboveOf, keys},
  (* the lower-sector scan of a clean sector (PFBHiddenWeightScan): the entries of the rows above with a pole of w *)
  aboveOf[s_] := If[! AssociationQ[hw], Missing["NotAsked"], Count[Flatten[Table[With[{f = s["R"][[k, s["Index"][r], c]]}, f =!= 0 && IntersectingQ[PFBEpsFactors[f], hw["Factors"]]],
     {k, Length[s["R"]]}, {r, Intersection[hw["Rows"], s["Labels"]]}, {c, Length[s["Labels"]]}]], True]];
  c0 = Lookup[opts, "Census", Block[{Print}, PFBCensus[sys, sl]]];
  st = Lookup[opts, "State", <||>];
  rows = Intersection[PFBSectorMasters[sys, key], sl["Labels"]];
  sec = ix /@ rows;
  noDefer = Union[Keys[Lookup[st, "Flagged", <||>]], DeleteCases[#["Key"] & /@ Lookup[st, "Accepted", {}], None]];
  (* the highest power at eps -> infinity each entry of the sector's rows may reach, from the slice before the change
     (PFBDegreeViolations), once for every set *)
  ceil0 = Table[With[{f = sl["R"][[k, ix[r], c]]}, Max[cap, If[f === 0, -Infinity, Last[PFBEpsOrders[f]]]]], {k, Length[sl["R"]]}, {r, rows}, {c, Length[sl["Labels"]]}];
  Do[Module[{defs = PFBImageDefs[sys, set], ch, slNew, bad, sr, B, out, degs},
     ch = Quiet[PFBChangeVectors[sys, sl, red, cal, defs]];
     If[ch === $Failed, nOut++; Continue[]];
     slNew = Block[{Print}, Quiet[PFBApplyChange[sl, Join[ch, <|"Name" -> "scan"|>]]]];
     If[! AssociationQ[slNew], nDep++; Continue[]];
     bad = Flatten[Table[With[{f = slNew["R"][[k, ix[r], c]]}, If[f =!= 0 && PFBEpsFactors[f] =!= {}, {{k, r, sl["Labels"][[c]], PFBEpsFactors[f]}}, {}]],
       {k, Length[slNew["R"]]}, {r, rows}, {c, Length[sl["Labels"]]}], 3];
     (* the maximal cut changes when a new master has a component on another master of the sector (as PFBTryChange) *)
     sr = ix /@ ch["Replace"]; B = ch["H"][[All, sec]];
     degs = Table[PFBEpsDegree[slNew["R"][[k, ix[r], c]]], {k, Length[slNew["R"]]}, {r, rows}, {c, Length[sl["Labels"]]}];
     out = <|"set" -> set, "bad" -> Length[bad], "factors" -> Union[Flatten[bad[[All, 4]]]],
       "left" -> KeyValueMap[Join[#1, {Union @@ #2}] &, GroupBy[bad, (#[[2 ;; 3]] &) -> (#[[4]] &)]], "above" -> aboveOf[slNew],
       "zero" -> Count[Flatten[Table[With[{f = slNew["R"][[k, ix[r], c]]}, f =!= 0 && First[PFBEpsOrders[f]] < 0], {k, Length[slNew["R"]]}, {r, rows}, {c, Length[sl["Labels"]]}]], True],
       "over" -> Count[Flatten[MapThread[If[#1 =!= 0 && Last[PFBEpsOrders[#1]] > #2, 1, 0] &,
         {Table[slNew["R"][[k, ix[r], c]], {k, Length[slNew["R"]]}, {r, rows}, {c, Length[sl["Labels"]]}], ceil0}, 3]], 1],
       "high" -> Count[Flatten[degs], d_Integer /; d > cap], "deg" -> Max[Append[Cases[Flatten[degs], _Integer], -Infinity]],
       "maxCut" -> ! AllTrue[Flatten[Table[If[sec[[cc]] === sr[[i]], True, B[[i, cc]] === 0], {i, Length[sr]}, {cc, Length[sec]}]], TrueQ],
       "height" -> PFBRowsDigitHeight[slNew, rows],
       "dCensus" -> Missing["NotComputed"], "newBad" -> Missing["NotComputed"], "deferred" -> Missing["NotComputed"], "neg" -> Missing["NotComputed"]|>;
     If[full || bad === {}, Module[{c1 = Block[{Print}, PFBCensus[sys, slNew]], cmp, above, dr},
        cmp = PFBCompareCensus[c0, c1];
        (* new poles above that their own sector can remove are deferred by the gate: counted apart, only for a set that
           clears the sector's rows, and only in the rows above: a preview of the gate *)
        above = Select[cmp["NewBad"], ! MemberQ[rows, #[[2]]] &];
        dr = If[above === {} || bad =!= {} || ! AnyTrue[cmp["Removed"], MemberQ[rows, #[[2]]] &], {},
          With[{d = PFBDeferredPoles[sys, sl, slNew, c0, c1, above, <|"Removed" -> cmp["Removed"], "SectorRows" -> rows, "NoDefer" -> noDefer|>]},
            Union[Union @@ Values[#["Rows"] & /@ d["Deferred"]], Union @@ Values[#["Rows"] & /@ d["Moved"]]]]];
        out = Join[out, <|"over" -> Length[PFBDegreeViolations[sl, slNew, cap]], "dCensus" -> Length[c1["BadEntries"]] - Length[c0["BadEntries"]], "newBad" -> Count[cmp["NewBad"], x_ /; ! MemberQ[dr, x[[2]]]],
          "deferred" -> Count[cmp["NewBad"], x_ /; MemberQ[dr, x[[2]]]], "neg" -> Length[c1["EpsZero"]]|>]]];
     AppendTo[res, out]], {set, sets}];
  keys = scanKeys;
  If[! AssociationQ[hw],
    <|"Results" -> SortBy[res, PFBScanKey], "Dependent" -> nDep, "OutsidePool" -> nOut, "Seconds" -> Round[AbsoluteTime[] - t0]|>,
    (* the lower-sector scan: the sector's own rows must stay free of finite poles; then the entries with w left in the
       rows above, then the usual keys *)
    <|"Results" -> SortBy[Select[res, #["bad"] == 0 &], Prepend[keys[#], #["above"]] &], "RankedOut" -> SortBy[Select[res, #["bad"] > 0 &], {#["bad"], #["above"]} &],
      "AboveBefore" -> aboveOf[sl], "Dependent" -> nDep, "OutsidePool" -> nOut, "Seconds" -> Round[AbsoluteTime[] - t0]|>]];

(* The order of a scan's sets after the pole entries left in the sector's rows: new poles, entries raised above the cap,
   negative powers of eps, entries left above the cap, deferred poles, the change of the census, negative powers in the
   census, the lowest power of eps (among sets that are otherwise as good, the one closest to eps-form), and last the
   digit height of the sector's rows, a free proxy for their kinematic degree that orders only sets equal on every other
   key. A key a result lacks counts as the worst *)
scanKeys[r_] := {Replace[Lookup[r, "newBad", Infinity], _Missing -> Infinity], Lookup[r, "over", Infinity], Lookup[r, "zero", Infinity], Lookup[r, "high", Infinity],
   Replace[Lookup[r, "deferred", Infinity], _Missing -> Infinity], Replace[Lookup[r, "dCensus", Infinity], _Missing -> Infinity],
   Replace[Lookup[r, "neg", Infinity], _Missing -> Infinity], Lookup[r, "deg", Infinity],
   Replace[Lookup[r, "height", Infinity], _Missing -> Infinity]};
PFBScanKey[r_Association] := Prepend[scanKeys[r], Lookup[r, "bad", Infinity]];

(* the sets of a scan over a sector's slots: each slot takes a candidate or keeps its master, at least one changes. The
   (n + 1)^k tuples of a long candidate list do not fit in memory: they are counted before they are built *)
PFBSlotSets[sys_Association, slots_List, cands_List, opts_Association : <||>] := Module[{keep = Lookup[opts, "Keep", <||>], pow, setOf, symm, nSets, isCur, tuples, defIn, okIn, perSlot},
  (* each candidate integral carries the slot's own power of eps, so that a uniform normalisation does not count; a
     candidate given per slot (<|slot -> def|>, a maximal-cut-basis candidate with the slot's square root) takes its
     definition there, and is not tried in a slot it does not name *)
  pow[l_] := With[{p = DeleteCases[Flatten[PFBEpsPowers[PFBMaster[sys, l]["RootFree"]][[All, 2]]], _String]}, If[p === {}, 0, Min[p]]];
  defIn[c_, l_] := Which[AssociationQ[c], c[l], MatchQ[c, _j], eps^pow[l] c, True, c];
  okIn[c_, l_] := ! AssociationQ[c] || KeyExistsQ[c, l];
  setOf[t_] := Join[keep, Association[Table[slots[[i]] -> If[t[[i]] == 0, PFBMaster[sys, slots[[i]]]["RootFree"], defIn[cands[[t[[i]]]], slots[[i]]]], {i, Length[slots]}]]];
  (* slots with the same prefactor and power of eps are interchangeable: one order of their candidates is enough *)
  symm = Length[Union[{PFBMaster[sys, #]["Pref"], pow[#]} & /@ slots]] == 1;
  perSlot = Table[Select[Range[Length[cands]], okIn[cands[[#]], l] &], {l, slots}];
  (* counted before they are built; with candidates given per slot, the tuples of each slot's candidates (an upper bound) *)
  nSets = If[NoneTrue[cands, AssociationQ], Sum[Binomial[Length[slots], k] If[symm, Binomial[Length[cands], k], FactorialPower[Length[cands], k]], {k, Length[slots]}],
    Times @@ (Length /@ perSlot + 1) - 1];
  If[nSets > Lookup[opts, "MaxSets", Infinity], Return[<|"Sets" -> {}, "Count" -> nSets, "Symmetric" -> symm, "TooMany" -> True|>]];
  (* a candidate equal to a slot's current master (the sector's corner, say) is the set that keeps it: tried once *)
  isCur[i_, k_] := k =!= 0 && Together[defIn[cands[[k]], slots[[i]]] - PFBMaster[sys, slots[[i]]]["RootFree"]] === 0;
  tuples = Select[Tuples[Table[Prepend[perSlot[[i]], 0], {i, Length[slots]}]], Function[t, With[{nz = DeleteCases[t, 0]},
      nz =!= {} && DuplicateFreeQ[nz] && (! symm || OrderedQ[nz]) && NoneTrue[Range[Length[t]], isCur[#, t[[#]]] &]]]];
  <|"Sets" -> setOf /@ tuples, "Count" -> nSets, "Symmetric" -> symm, "TooMany" -> False|>];

(* The lower-sector scan (method.md, "A hidden weight on a clean lower sector"). A clean sector S whose master carries a
   hidden weight, I_m = w J_m, has clean rows, and every row above that couples to I_m has 1/w in column m. The scan
   tries sets of S's masters on the slice: the rows above change exactly through S's columns, A'_rS = A_rS T^-1 and
   A'_rL = A_rL - A_rS T^-1 Lambda (PFBApplyChange), so a reduction of S's subtree is all it needs. A set is judged on
   the rows above that carry w; S's own rows must stay free of finite poles *)
PFBHiddenWeightScan[sys_Association, sl_Association, red_Association, cal_Association, key_List, opts_Association : <||>] := Module[{c0, st = Lookup[opts, "State", <||>],
    hints, facs, sub, rows, secBase, slots, nat, ss, sets, scan, pilot, est, res, out, t0 = AbsoluteTime[], hwOpt, carriers, budget = Lookup[opts, "BudgetMinutes", Infinity],
    fail, clears},
  c0 = Lookup[opts, "Census", Block[{Print}, PFBCensus[sys, sl]]];
  (* a scan that cannot run is recorded with its reason (with "RunDir"): the hint is then tried, and the sectors where the
     poles show may be flagged; without a factor there is nothing to record *)
  fail[status_, msg_] := With[{f = <|"Status" -> status, "Message" -> msg, "Results" -> {}, "RankedOut" -> {}, "Seconds" -> Round[AbsoluteTime[] - t0],
       "Factors" -> If[ListQ[facs], facs, {}]|>},
    If[StringQ[Lookup[opts, "RunDir", None]] && ListQ[facs] && facs =!= {},
      PoleFreeBasis`Records`PFBRecordScan[opts["RunDir"], key, f, <|"What" -> "lower-sector scan (hidden weight " <> ToString[facs, InputForm] <> ")"|>]];
    f];
  (* a set that clears the rows above: no entry with the factors left there, no new pole, nothing raised above the cap *)
  clears[r_] := r["above"] == 0 && r["newBad"] === 0 && r["over"] == 0;
  hints = Select[Lookup[c0, "HiddenWeights", {}], #["Sector"] === key &];
  facs = Replace[Lookup[opts, "Factors", Automatic], Automatic :> Union[#["Factor"] & /@ hints]];
  If[facs === {}, Return[fail["no factor", "the census marks no hidden weight on " <> PFBSectorString[key] <> ": give the factor with \"Factors\" (from PFBHiddenWeightTest)"]]];
  sub = PFBSubtreeMasters[sys, sl, key];
  (* the rows above that a change of S's masters alters (they couple to them) and that have a pole of the factors *)
  rows = Replace[Lookup[opts, "Rows", Automatic], Automatic :> Select[Intersection[Complement[sl["Labels"], sub],
      PFBRowsCouplingTo[sl, Intersection[PFBSectorMasters[sys, key], sl["Labels"]]]], Function[r,
      AnyTrue[Flatten[Table[sl["R"][[k, sl["Index"][r]]], {k, Length[sl["R"]]}]], # =!= 0 && IntersectingQ[PFBEpsFactors[#], facs] &]]]];
  If[rows === {}, Return[fail["no factor", "no row above " <> PFBSectorString[key] <> " that couples to its masters has a pole of " <> ToString[facs, InputForm]]]];
  secBase = Select[Intersection[PFBSectorMasters[sys, key], sl["Labels"]], PFBMaster[sys, #]["Family"] === key[[1]] &];
  (* the masters of S whose columns carry the factors in those rows *)
  carriers = Select[secBase, Function[m, AnyTrue[rows, Function[r, AnyTrue[Range[Length[sl["R"]]], Function[k,
      With[{f = sl["R"][[k, sl["Index"][r], sl["Index"][m]]]}, f =!= 0 && IntersectingQ[PFBEpsFactors[f], facs]]]]]]]];
  slots = Replace[Lookup[opts, "Slots", Automatic], Automatic :> If[Length[secBase] <= 3, secBase, carriers]];
  If[! MatchQ[slots, {__Integer}] || ! SubsetQ[secBase, slots] || Length[slots] > 3,
    Return[Join[fail["no slots", "give \"Slots\": one to three masters of " <> PFBSectorString[key] <> " (base family: " <> ToString[ut /@ secBase] <>
      "; those whose columns carry the factor: " <> ToString[ut /@ carriers] <> ")"], <|"Carriers" -> carriers|>]]];
  (* S's maximal-cut-basis candidates (bin/maxcut_candidates.wls for S), when they were written: a clean sector with a
     hidden weight is often one whose maximal-cut basis must change (MaxCut.wl loads after this file: full names) *)
  nat = PFBNaturalIntegrals[sys, red, key, <|"MaxWeight" -> Lookup[opts, "MaxWeight", 1], "Extra" -> Join[Lookup[opts, "Candidates", {}],
     If[StringQ[Lookup[opts, "RunDir", None]] && Lookup[opts, "MaxCut", Automatic] =!= False,
       With[{mc = PoleFreeBasis`MaxCut`PFBReadMaxCutCandidates[opts["RunDir"], key]}, If[AssociationQ[mc], PoleFreeBasis`MaxCut`PFBMaxCutScanCandidates[mc], {}]], {}]]|>];
  ss = PFBSlotSets[sys, slots, nat["Candidates"], <|"Keep" -> Lookup[opts, "Keep", <||>], "MaxSets" -> Lookup[opts, "MaxSets", 3000]|>];
  If[ss["TooMany"], Return[Join[fail["too many", ToString[ss["Count"]] <> " sets, above \"MaxSets\": lower \"MaxWeight\", give the structural reading's candidates, fix a slot with \"Keep\", or raise \"MaxSets\""],
    <|"Sets" -> ss["Count"]|>]]];
  sets = Join[ss["Sets"], Lookup[opts, "Sets", {}]];
  If[sets === {}, Return[Join[fail["no slots", "no candidate of " <> PFBSectorString[key] <> " is in the reduction's pool (" <> ToString[Length[nat["NotInPool"]]] <>
      " natural integrals missing: add them with PoolExtra)"], <|"NotInPool" -> nat["NotInPool"]|>]]];
  hwOpt = <|"Census" -> c0, "State" -> st, "HiddenWeight" -> <|"Factors" -> facs, "Rows" -> rows|>|>;
  (* a timed pilot first (timing-discipline) when there is a budget *)
  If[budget =!= Infinity,
    pilot = PFBScanSets[sys, sl, red, cal, key, Take[sets, UpTo[5]], hwOpt];
    est = N[Max[pilot["Seconds"], 1] Length[sets]/Min[5, Length[sets]]];
    If[est > 60 budget, Return[Join[fail["over budget", "the pilot of " <> ToString[Min[5, Length[sets]]] <> " sets took " <> ToString[pilot["Seconds"]] <> " s: the scan would take about " <>
      ToString[Round[est/60.]] <> " min, above the budget of " <> ToString[budget] <> " min"], <|"Sets" -> Length[sets]|>]]]];
  scan = PFBScanSets[sys, sl, red, cal, key, sets, hwOpt];
  res = scan["Results"];
  (* interchangeable slots were scanned in one order of their candidates; a set that clears the rows above but changes
     the maximal cut is tried in the other orders, and one that keeps the maximal cut replaces it (as bin/pair_scan.wls) *)
  If[ss["Symmetric"] && Length[slots] > 1,
    res = Function[r, If[! (r["above"] == 0 && TrueQ[r["maxCut"]]), r,
        SelectFirst[PFBScanSets[sys, sl, red, cal, key, Table[Join[r["set"], AssociationThread[slots -> Lookup[r["set"], slots][[p]]]],
            {p, Rest[Permutations[Range[Length[slots]]]]}], hwOpt]["Results"], #["above"] == 0 && ! TrueQ[#["maxCut"]] &, r]]] /@ res];
  out = <|"Status" -> "done", "Factors" -> facs, "Rows" -> rows, "Slots" -> slots, "Carriers" -> carriers, "Candidates" -> nat["Candidates"], "NotInPool" -> nat["NotInPool"],
    "Results" -> res, "RankedOut" -> scan["RankedOut"], "AboveBefore" -> scan["AboveBefore"],
    "Clearing" -> Count[res, _?clears], "ClearingSets" -> Select[res, clears],
    "Sets" -> Length[sets], "Dependent" -> scan["Dependent"], "OutsidePool" -> scan["OutsidePool"], "Seconds" -> Round[AbsoluteTime[] - t0]|>;
  out["Message"] = PFBSectorString[key] <> ", lower-sector scan for " <> ToString[facs, InputForm] <> " in the rows " <> ToString[ut /@ rows] <> ": " <> ToString[Length[sets]] <> " sets, " <>
    ToString[Length[res]] <> " keep the sector's rows free of finite poles (" <> ToString[Length[scan["RankedOut"]]] <> " ranked out), " <> ToString[out["Clearing"]] <>
    " leave no entry with the factor in those rows (" <> ToString[scan["AboveBefore"]] <> " now), no new pole and nothing above the cap" <>
    If[res === {}, "", "; the best leaves " <> ToString[First[res]["above"]] <> If[out["Clearing"] > 0, ": normalise it and send it through PFBTryChange with checkReds (two or more extra points)", ""]];
  If[StringQ[Lookup[opts, "RunDir", None]], PoleFreeBasis`Records`PFBRecordScan[opts["RunDir"], key, out, <|"What" -> "lower-sector scan (hidden weight " <> ToString[facs, InputForm] <> ")"|>]];
  out];

verdictWord[c_] := If[c["Pass"], If[TrueQ[Lookup[c, "NotChecked", False]], "not checked", "ok"], "FAILED"];

(* a ut[k] term of a new definition stands for the current master k: the rules apply to the integrals it contains *)
expandUT[sys_, d_] := d /. ut[k_Integer] :> PFBMaster[sys, k]["RootFree"];

PFBGate[sys_Association, slOld_Association, cOld_Association, slNew_Association, ch_Association, opts_Association : <||>] := Module[{checks = {}, kind = Lookup[ch, "Kind", "change"],
    key = Lookup[ch, "Key", None], secRows, coupled, cNew, cmp, viol, minPts = Lookup[opts, "MinPoints", 2], badSec, badCpl, defer, deferredRows, rescOK,
    frozen, diag, wNew, wOld, wBad, eu, lab, cap = Lookup[opts, "MaxEpsDegree", $PFBMaxEpsDegree], over, cO},
  (* rows of the sector and rows coupling to it, and the census before and after *)
  secRows = If[key === None, Lookup[ch, "Replace", {}], Intersection[PFBSectorMasters[sys, key], slNew["Labels"]]];
  coupled = PFBRowsCouplingTo[slNew, secRows];
  cNew = PFBCensus[sys, slNew, <|"MaxEpsDegree" -> cap|>];
  (* the entries above the cap of both censuses with the same cap (a stored census may have another) *)
  cO = If[Lookup[cOld, "DegreeCap", None] === cap, cOld, Block[{PFBPrint}, PFBCensus[sys, slOld, <|"MaxEpsDegree" -> cap|>]]];
  cmp = PFBCompareCensus[cO, cNew];
  (* rules, letters, weights and the Euler relation of the new masters: MaximalCutBasis`Rules`, shared with the
     maximal-cut gate *)
  If[kind =!= "rescale",
    lab[l_] := "ut[" <> ToString[l] <> "]";
    viol = Flatten[KeyValueMap[Function[{l, d}, (lab[l] <> " " <> #) & /@ PFBRuleViolations[sys, d, <|"Letters" -> {}|>]], ch["NewDefs"]]];
    AppendTo[checks, check["rules", viol === {}, If[viol === {}, "one power of eps per integral, no eps denominators, coefficients rational in the invariants",
      StringRiffle[viol, "; "]]]];
    If[PFBLetters[sys] =!= {},
      viol = Flatten[KeyValueMap[Function[{l, d}, (lab[l] <> " " <> #) & /@ Select[PFBRuleViolations[sys, d], StringStartsQ[#, "letters"] &]], ch["NewDefs"]]];
      AppendTo[checks, check["letters", viol === {}, If[viol === {}, "every denominator factor of the new coefficients is a letter", StringRiffle[viol, "; "]]]]];
    (* each new master is homogeneous, and keeps the weight of the one it replaces or is dimensionless: real bases are
       not always dimensionless (bare integrals as masters), and a new maximal-cut basis may normalise them. A slip in a
       normalisation (a factor dropped) makes a master inhomogeneous, or moves it away from its weight *)
    wNew = Association[KeyValueMap[#1 -> PFBMasterWeight[sys, #2, Lookup[Lookup[ch, "Prefs", <||>], #1, PFBMaster[sys, #1]["Pref"]]] &, ch["NewDefs"]]];
    wOld = PFBMasterWeights[sys, Keys[ch["NewDefs"]]];
    wBad = Select[Keys[wNew], wNew[#] === $Failed || ! (wOld[#] === $Failed || Expand[wNew[#] - wOld[#]] === 0 || Expand[wNew[#] /. eps -> 0] === 0) &];
    AppendTo[checks, check["weights", wBad === {}, If[wBad === {},
      "every new master is homogeneous and keeps its weight or is dimensionless" <> With[{moved = Select[Keys[wNew], wOld[#] =!= $Failed && Expand[wNew[#] - wOld[#]] =!= 0 &],
          was = Select[Keys[wOld], wOld[#] === $Failed &]},
        If[moved === {}, "", "; made dimensionless: " <> StringRiffle[lab /@ moved, ", "]] <>
        If[was === {}, "", "; " <> StringRiffle[lab /@ was, ", "] <> " mixed mass dimensions before"]],
      StringRiffle[If[wNew[#] === $Failed, lab[#] <> " mixes terms of different mass dimension (a missing or wrong prefactor)",
          lab[#] <> " has weight " <> ToString[wNew[#], InputForm] <> ", the master it replaces " <> ToString[wOld[#], InputForm] <>
            " (a prefactor off by mass dimension " <> ToString[Expand[wNew[#] - wOld[#]], InputForm] <> ")"] & /@ wBad, "; "]]]];
    eu = PFBEulerCheck[sys, slNew, <|"Rows" -> Keys[ch["NewDefs"]], "Weights" -> wNew|>];
    AppendTo[checks, Join[check["euler", eu["Pass"] =!= False, StringReplace[eu["Message"], StartOfString ~~ "not checked: " -> ""]],
      <|"NotChecked" -> MissingQ[eu["Pass"]]|>]]];
  (* frozen families: their masters never change, whichever rung or map proposes it *)
  frozen = Select[If[kind === "rescale", Keys[Select[Lookup[ch, "Shifts", <||>], # =!= 0 &]], Lookup[ch, "Replace", {}]],
    PFBFrozenQ[sys, PFBMaster[sys, #]["Family"]] &];
  AppendTo[checks, check["frozen", frozen === {}, If[frozen === {}, "no master of a frozen family changes",
     "masters of frozen families would change: " <> ToString[ut /@ frozen]]]];
  (* the sector's rows: pole-free. The rows above may keep poles that existed before (their own sources, fixed when
     their sectors come, bottom-up), and gain new ones only when PFBDeferredPoles defers them; nothing else may appear *)
  (* a uniform eps^k multiplies each entry by eps^(k_r - k_c): finite poles can neither appear nor disappear, so a rescale
     only has to leave its rows with no new finite pole (rows that still carry poles are fixed with their own sectors) *)
  badSec = If[kind === "rescale", Select[secRows, rowPoleFree[slOld, #] && ! rowPoleFree[slNew, #] &], Select[secRows, ! rowPoleFree[slNew, #] &]];
  badCpl = Union[Cases[cmp["NewBad"], {_, r_, _, _} /; MemberQ[coupled, r] :> r]];
  (* new poles above that the upper sector's own fix can remove are deferred, not refused (a correct lower fix adds
     -R_rm lambda_S to every row coupling to it, poles included) *)
  defer = If[kind =!= "rescale" && badCpl =!= {} && TrueQ[Lookup[opts, "DeferPoles", True]],
    PFBDeferredPoles[sys, slOld, slNew, cO, cNew, Select[cmp["NewBad"], MemberQ[badCpl, #[[2]]] &],
      <|"Removed" -> cmp["Removed"], "SectorRows" -> secRows, "NoDefer" -> Lookup[opts, "NoDefer", {}], "Replaced" -> Lookup[ch, "Replace", {}]|>], <|"Deferred" -> <||>, "Moved" -> <||>, "Refused" -> <||>|>];
  deferredRows = Union[Union @@ Values[#["Rows"] & /@ defer["Deferred"]], Union @@ Values[#["Rows"] & /@ defer["Moved"]]];
  badCpl = Complement[badCpl, deferredRows];
  AppendTo[checks, Join[check["rows", badSec === {} && badCpl === {},
    If[badSec === {} && badCpl === {}, If[kind === "rescale",
          "no finite pole gained in the " <> ToString[Length[secRows]] <> " rescaled rows (" <> ToString[Count[secRows, x_ /; ! rowPoleFree[slNew, x]]] <> " keep earlier ones)",
          "the " <> ToString[Length[secRows]] <> " sector rows are free of finite poles"] <> "; " <> If[deferredRows === {}, "no new pole", "no new pole that their own sectors cannot remove"] <> " in the " <>
        ToString[Length[coupled]] <> " rows coupling to them" <>
        With[{left = Complement[Select[coupled, ! rowPoleFree[slNew, #] &], deferredRows]}, If[left =!= {}, " (" <> ToString[Length[left]] <> " keep earlier poles, to be fixed with their own sectors: " <>
          ToString[ut /@ Take[left, UpTo[12]]] <> ")", ""]],
      "rows with finite poles: sector " <> ToString[ut /@ Take[badSec, UpTo[20]]] <> "; coupled rows with new poles " <> ToString[ut /@ Take[badCpl, UpTo[20]]] <>
        If[defer["Refused"] === <||>, "", " (not deferred: " <> StringRiffle[KeyValueMap[PFBSectorString[#1] <> " " <> #2 &, defer["Refused"]], "; "] <> ")"]] <>
      If[defer["Deferred"] === <||>, "", "; new poles deferred to their own sectors: " <> StringRiffle[KeyValueMap[PFBSectorString[#1] <> " rows " <> ToString[ut /@ #2["Rows"]] <>
          " (through " <> ToString[ut /@ #2["Sources"]] <> If[TrueQ[#2["Verified"]], "", ", one master: not verified"] <> ")" &, defer["Deferred"]], "; "]] <>
      If[defer["Moved"] === <||>, "", "; moved poles deferred to their own sectors: " <> StringRiffle[KeyValueMap[PFBSectorString[#1] <> " rows " <> ToString[ut /@ #2["Rows"]] <>
          " (factors " <> ToString[#2["Factors"], InputForm] <> ", which its rows had before, in " <> ToString[Length[#2["Entries"]]] <> If[Length[#2["Entries"]] == 1, " new entry)", " new entries)"] &, defer["Moved"]], "; "]]],
    <|"Deferred" -> defer["Deferred"], "Moved" -> defer["Moved"]|>]];
  (* census: poles removed, no new pole except deferred ones; new negative powers of eps only if a uniform eps^k removes them *)
  (* a uniform eps^k leaves the diagonal as it is: a new negative power of eps there can never be removed. Off the
     diagonal, the new negative powers must be liftable by some uniform eps^k that keeps every other entry at order >= 0,
     except entries that were negative before the change: they only must not end lower than they were. So an unrelated
     inconsistency elsewhere in the slice does not block the change. The lift must also keep every entry at or below
     the cap (entries above it: at their power), or rung 1 could not take it *)
  (* on the diagonal this holds also where the negative power takes the place of a finite pole, an entry the census
     does not count as new (PFBCompareCensus) *)
  diag = Select[Complement[cNew["EpsZero"][[All, 1 ;; 3]], cO["EpsZero"][[All, 1 ;; 3]]], #[[2]] === #[[3]] &];
  rescOK = Which[diag =!= {}, False, cmp["NewEpsZero"] === {}, True,
    True, Lookup[PFBRescaleSearch[sys, slNew, <|"Upper" -> {Infinity}, "MaxEpsDegree" -> cap,
       "Floors" -> Merge[{#[[2]], #[[3]]} -> #[[4]] & /@ Select[cOld["EpsZero"], KeyExistsQ[slNew["Index"], #[[2]]] && KeyExistsQ[slNew["Index"], #[[3]]] &] /.
          ({r_, c_} -> v_) :> ({slNew["Index"][r], slNew["Index"][c]} -> v), Min]|>], "Feasible", False]];
  (* progress: finite poles, negative powers of eps or entries above the cap removed (all three are bad entries) *)
  AppendTo[checks, check["census", If[kind === "rescale", cmp["NewBad"] === {} && cmp["NewEpsZero"] === {} && (cmp["RemovedEpsZero"] =!= {} || cmp["Removed"] =!= {} || cmp["RemovedHigh"] =!= {}),
      Select[cmp["NewBad"], ! MemberQ[deferredRows, #[[2]]] &] === {} && (cmp["Removed"] =!= {} || cmp["RemovedEpsZero"] =!= {} || cmp["RemovedHigh"] =!= {}) && TrueQ[rescOK] &&
        (* deferring is only for a change that clears poles of its own rows *)
        (deferredRows === {} || AnyTrue[cmp["Removed"], MemberQ[secRows, #[[2]]] &])],
    "bad entries " <> ToString[Length[cOld["BadEntries"]]] <> " -> " <> ToString[Length[cNew["BadEntries"]]] <>
      ", bad rows " <> ToString[cmp["BadRowsBefore"]] <> " -> " <> ToString[cmp["BadRowsAfter"]] <>
      ", negative eps powers " <> ToString[Length[cOld["EpsZero"]]] <> " -> " <> ToString[Length[cNew["EpsZero"]]] <>
      If[cap === Infinity, "", ", entries above eps^" <> ToString[cap] <> " " <> ToString[Length[cO["HighDegree"]]] <> " -> " <> ToString[Length[cNew["HighDegree"]]]] <>
      If[cmp["NewEpsZero"] =!= {} || diag =!= {}, " (" <> ToString[Length[Union[cmp["NewEpsZero"], diag]]] <> " new, " <> If[TrueQ[rescOK], "removable by a uniform eps^k (rung 1)",
         "NOT removable by a uniform eps^k" <> If[diag =!= {}, ", " <> ToString[Length[diag]] <> " on the diagonal", If[cap === Infinity, "", " within the cap eps^" <> ToString[cap]]]] <> ")", ""] <>
      With[{nd = Select[cmp["NewBad"], ! MemberQ[deferredRows, #[[2]]] &], nDef = Count[cmp["NewBad"], x_ /; MemberQ[deferredRows, x[[2]]]]},
        If[nDef > 0, "; " <> ToString[nDef] <> " new pole entries deferred (rows check), " <> ToString[Count[cmp["Removed"], x_ /; MemberQ[secRows, x[[2]]]]] <>
          " removed from the sector's own rows", ""] <>
        If[nd =!= {}, "; NEW poles in " <> ToString[Length[nd]] <> " entries, e.g. " <> ToString[Take[nd, UpTo[3]], InputForm], ""]]]];
  (* the power of eps at eps -> infinity: no entry rises above the cap, finite poles or not. Entries above it before
     (the starting basis's, or a cap raised later) may keep their power, also when the change removes their poles *)
  over = PFBDegreeViolations[slOld, slNew, cap];
  AppendTo[checks, check["degree", over === {}, Which[
    cap === Infinity, "no cap on the power of eps",
    over === {}, "no entry rises above eps^" <> ToString[cap] <> "; highest power of eps " <> ToString[Lookup[cO, "MaxDegree", "?"] /. None -> "-"] <> " -> " <>
      ToString[cNew["MaxDegree"] /. None -> "-"] <> If[cNew["HighDegree"] === {}, "", " (" <> ToString[Length[cNew["HighDegree"]]] <> " entries above the cap, none raised)"],
    True, ToString[Length[over]] <> " entries rise above eps^" <> ToString[cap] <> ", up to eps^" <> ToString[Max[over[[All, 4]]]] <> ", in rows " <>
      ToString[ut /@ Take[Union[over[[All, 2]]], UpTo[12]]] <> ", e.g. " <> ToString[Take[over[[All, 1 ;; 4]], UpTo[3]], InputForm] <>
      " (a higher cap, run.wl \"MaxEpsDegree\", only with the user's agreement)"]]];
  (* fitted coefficients need points beyond the slice point *)
  If[TrueQ[Lookup[ch, "Fitted", False]],
    With[{un = Lookup[ch, "PointsUnchecked", {}]},
      AppendTo[checks, check["points", Lookup[ch, "PointsVerified", 0] >= minPts && un === {},
        ToString[Lookup[ch, "PointsVerified", 0]] <> " extra point(s) verified (at least " <> ToString[minPts] <> " needed for fitted coefficients)" <>
          If[un === {}, "", "; " <> ToString[Length[un]] <> " could not be checked (" <> ToString[un[[1, 1]], InputForm] <> ": " <> un[[1, 2]] <>
            "): the fit must hold at every point given, so leave that reduction out or reduce the point again"] <>
          ignoredText[Lookup[ch, "PointsIgnored", {}]]]]]];
  <|"Pass" -> AllTrue[checks, #["Pass"] &], "Checks" -> checks, "Census" -> cNew, "Comparison" -> cmp,
    "Message" -> StringRiffle[(#["Name"] <> ": " <> verdictWord[#] <> " (" <> #["Detail"] <> ")") & /@ checks, "\n"]|>];


(* ::Section:: *)
(*Checks at other points*)


(* An extra point is a point the slice and the other reductions have not used: a reduction at the slice point, or at the
   point of an earlier reduction, confirms nothing new. Each is ignored and reported, {point, reason} *)
samePointQ[a_List, b_List] := Sort[a /. (x_ -> v_) :> (x -> Together[v])] === Sort[b /. (x_ -> v_) :> (x -> Together[v])];
samePointQ[_, _] := False;
PFBDistinctPoints[reds_List, slicePt_ : None] := Module[{seen = {}, kept = {}, ignored = {}},
  Do[With[{P = Lookup[rd, "Point", None]}, Which[
      ListQ[slicePt] && samePointQ[P, slicePt], AppendTo[ignored, {P, "the slice point: not an extra point"}],
      AnyTrue[seen, samePointQ[P, #] &], AppendTo[ignored, {P, "the point of an earlier reduction: counted once"}],
      True, AppendTo[seen, P]; AppendTo[kept, rd]]], {rd, reds}];
  <|"Reds" -> kept, "Ignored" -> ignored|>];
ignoredText[ig_List] := If[ig === {}, "", "; " <> ToString[Length[ig]] <> If[Length[ig] == 1, " reduction", " reductions"] <> " ignored (" <>
   StringRiffle[(ToString[#[[1]], InputForm] <> ": " <> #[[2]]) & /@ Take[ig, UpTo[3]], "; "] <> If[Length[ig] > 3, "; ...", ""] <> ")"];

PFBVerifyAtPoints[sys_Association, reds0_List, key_List, newDefs0_Association, prefs_Association : <||>, opts_Association : <||>] := Module[{detail = {}, ok = True,
    newDefs = expandUT[sys, #] & /@ newDefs0, allowed = Lookup[opts, "EpsZeroAllowed", <||>], cap = Lookup[opts, "MaxEpsDegree", $PFBMaxEpsDegree],
    allowedDeg = Lookup[opts, "DegreeAllowed", <||>], dp = PFBDistinctPoints[reds0, Lookup[opts, "SlicePoint", None]], reds},
  reds = dp["Reds"];
  Do[Module[{mast = rd["Masters"], P = rd["Point"], ders = rd["Invariants"], S, Spos, Lpos, idx, vec, dvec, H, G, T, Ti, Lam, rows, bad, high, pref, nk},
     If[! AllTrue[mast, MatchQ[#, _ut] &], AppendTo[detail, {P, "masters the system lacks (remove them first: bin/extra_masters.wls): not a check"}]; ok = False; Continue[]];
     nk = Length[ders];
     S = Select[PFBSectorMasters[sys, key], MemberQ[mast, ut[#]] &];
     Spos = Flatten[Position[mast, ut[#]] & /@ S]; Lpos = Complement[Range[Length[mast]], Spos];
     idx = AssociationThread[rd["Pool"] -> Range[Length[rd["Pool"]]]];
     pref[m_] := Lookup[prefs, m, PFBMaster[sys, m]["Pref"]];
     vec[ex_] := Module[{e = Collect[Expand[ex], _j], jl}, jl = Union[Cases[{e}, _j, Infinity]];
       If[! SubsetQ[rd["Pool"], jl], Return[$Failed, Module]]; Together[Sum[(Coefficient[e, jj] /. P) rd["Rp"][[idx[jj]]], {jj, jl}]]];
     dvec[ex_, k_] := Module[{e = Collect[Expand[ex], _j], jl}, jl = Union[Cases[{e}, _j, Infinity]];
       Together[Sum[(D[Coefficient[e, jj], ders[[k]]] /. P) rd["Rp"][[idx[jj]]] + (Coefficient[e, jj] /. P) rd["dRp"][[k, idx[jj]]], {jj, jl}]]];
     (* new sector basis: replaced masters from their definitions, the others unchanged *)
     H = Table[If[KeyExistsQ[newDefs, m], vec[newDefs[m]], UnitVector[Length[mast], First[Flatten[Position[mast, ut[m]]]]]], {m, S}];
     If[MemberQ[H, $Failed], AppendTo[detail, {P, "integrals of the new masters outside the pool"}]; ok = False; Continue[]];
     If[! AllTrue[S, KeyExistsQ[newDefs, #] || MemberQ[rd["Focus"], #] &], AppendTo[detail, {P, "unchanged sector masters missing from the focus"}]; ok = False; Continue[]];
     G = Table[With[{m = S[[i]]}, If[KeyExistsQ[newDefs, m], Together[dvec[newDefs[m], k] + (Together[D[pref[m]^2, ders[[k]]]/(2 pref[m]^2)] /. P) H[[i]]],
         rd["Dm"][[k, First[Flatten[Position[rd["Focus"], m]]]]]]], {k, nk}, {i, Length[S]}];
     T = H[[All, Spos]]; Lam = H[[All, Lpos]]; Ti = Together[Inverse[T]];
     rows = Table[With[{AS = Together[G[[k, i, Spos]].Ti]}, Join[AS, Together[G[[k, i, Lpos]] - AS.Lam]]], {k, nk}, {i, Length[S]}];
     (* columns: the sector's masters, then the other masters of the reduction *)
     Module[{cols = Join[S, mast[[Lpos]] /. ut[x_] :> x]},
       bad = Flatten[Table[With[{f = rows[[k, i, c]], rg = PFBEpsRange[rows[[k, i, c]]]},
           If[f =!= 0 && (PFBEpsFactors[f] =!= {} || (ListQ[rg] && rg[[1]] < 0 && rg[[1]] < Lookup[allowed, Key[{ders[[k]], S[[i]], cols[[c]]}], 0])), {f}, {}]],
         {k, nk}, {i, Length[S]}, {c, Length[cols]}]];
       (* above the cap: as on the slice, an entry may reach the new slice's own power there, no higher *)
       high = If[cap === Infinity, {}, Flatten[Table[With[{d = PFBEpsDegree[rows[[k, i, c]]]},
           If[IntegerQ[d] && d > Max[cap, Lookup[allowedDeg, Key[{ders[[k]], S[[i]], cols[[c]]}], -Infinity]], {d}, {}]],
         {k, nk}, {i, Length[S]}, {c, Length[cols]}]]]];
     If[bad =!= {} || high =!= {}, ok = False];
     AppendTo[detail, {P, Which[bad =!= {}, ToString[Length[bad]] <> " entries with poles, factors " <> ToString[Union[Flatten[PFBEpsFactors /@ bad]], InputForm],
        high =!= {}, "sector rows pole-free, but " <> ToString[Length[high]] <> " entries above eps^" <> ToString[cap] <> " (up to eps^" <> ToString[Max[high]] <> ")",
        True, "sector rows pole-free"]}]],
    {rd, reds}];
  <|"Pass" -> ok && reds =!= {}, "Points" -> Count[detail, {_, "sector rows pole-free"}], "Detail" -> detail, "Ignored" -> dp["Ignored"]|>];

(* ::Section:: *)
(*The simplification phase*)


(* {a1, a2, ...} before {b1, b2, ...} lexicographically, numerically (-Infinity for no term) *)
PFBObjectiveLess[a_List, b_List] := Module[{i = 1}, While[i <= Min[Length[a], Length[b]] && a[[i]] == b[[i]], i++]; i <= Min[Length[a], Length[b]] && a[[i]] < b[[i]]];

(* PFBDegreeObjective of a degree summary (lib/PFB/Degrees.wl loads after this file) *)
objectiveOf[s_Association] := {Replace[s["Highest"], None -> -Infinity], s["Count"], s["Sum"]};

(* an eps-form block (every entry eps^1, or zero) of a sector's own rows and columns *)
epsFormBlockQ[sys_, sl_, key_] := With[{rows = Intersection[PFBSectorMasters[sys, key], sl["Labels"]]},
  rows =!= {} && MemberQ[{{1, 1}, "zero"}, PFBBlockProfile[sl, rows, rows]["Range"]]];

(* the checks of a simplification move (rung "simplify"), from those of PFBGate for kind "change": the rules, letters,
   weights, Euler relation, frozen families and the cap stay; "rows", "census" and "points" are replaced, and the
   determinant is not judged: no row gains a finite pole, the census gains no bad entry of any kind (it need not lose
   one), every eps-form block stays eps-form, and the measured kinematic degrees drop *)
epsRangeText[p_] := Replace[p, {"zero" -> "zero", {a_, a_} :> "eps^" <> ToString[a], {a_, b_} :> "eps^" <> ToString[a] <> ".." <> ToString[b]}];
epsFloorText[sl_][{k_, r_, b_, a_}] := "ut[" <> ToString[r] <> "] (d/d" <> ToString[sl["Derivatives"][[k]]] <> "): " <> epsRangeText[b] <> " -> " <> epsRangeText[a];

PFBSimplifyGate[gate0_Association, sys_Association, slOld_Association, cOld_Association, slNew_Association, ch_Association, opts_Association : <||>] := Module[{keep, cmp,
    newPoleRows, rowsCheck, censusCheck, keys, lost, epsCheck, d, ob, oa, degCheck, offCheck, checks, floors, floorCheck},
  keep = Select[gate0["Checks"], ! MemberQ[{"rows", "census", "points"}, #["Name"]] &];
  cmp = gate0["Comparison"];
  newPoleRows = Select[slNew["Labels"], KeyExistsQ[slOld["Index"], #] && rowPoleFree[slOld, #] && ! rowPoleFree[slNew, #] &];
  rowsCheck = check["rows", newPoleRows === {}, If[newPoleRows === {}, "no row gains a finite pole",
    "rows that gain finite poles: " <> ToString[ut /@ Take[newPoleRows, UpTo[20]]]]];
  censusCheck = check["census", cmp["NewBad"] === {} && cmp["NewEpsZero"] === {} && cmp["NewHigh"] === {},
    "no new pole, no new negative power of eps, no new entry above the cap (bad entries " <> ToString[Length[cOld["BadEntries"]]] <> " -> " <>
      ToString[Length[gate0["Census"]["BadEntries"]]] <> ")" <>
      If[cmp["NewBad"] === {} && cmp["NewEpsZero"] === {} && cmp["NewHigh"] === {}, "",
        ": new poles " <> ToString[Length[cmp["NewBad"]]] <> ", new negative powers " <> ToString[Length[cmp["NewEpsZero"]]] <> ", new entries above the cap " <> ToString[Length[cmp["NewHigh"]]]]];
  keys = Select[PFBSectorKeys[sys], epsFormBlockQ[sys, slOld, #] &];
  lost = Select[keys, ! epsFormBlockQ[sys, slNew, #] &];
  epsCheck = check["eps-form blocks", lost === {}, If[lost === {}, "every eps-form block of a sector's own rows (" <> ToString[Length[keys]] <> ") stays eps-form",
    "eps-form blocks that lose their form: " <> StringRiffle[PFBSectorString /@ lost, ", "]]];
  d = Lookup[opts, "Degrees", Missing[]];
  degCheck = If[! AssociationQ[d] || ! TrueQ[Lookup[d, "Measured", False]] || ! AssociationQ[Lookup[d, "Before", None]] || ! AssociationQ[Lookup[d, "After", None]],
    check["kinematic degrees", False, "no measured degrees: a simplification is accepted only when FFAllDegrees measured that {highest degree, terms at it, sum} drops"],
    ob = objectiveOf[d["Before"]]; oa = objectiveOf[d["After"]];
    check["kinematic degrees", PFBObjectiveLess[oa, ob], "{highest degree, terms at it, sum} " <> ToString[ob] <> " -> " <> ToString[oa] <>
      If[PFBObjectiveLess[oa, ob], "", " (no drop)"] <> ", measured by FFAllDegrees" <>
      If[ListQ[Lookup[d, "Jobs", None]] && d["Jobs"] =!= {}, " (jobs " <> StringRiffle[ToString /@ d["Jobs"], ", "] <> ")", ""]]];
  (* away from the slice: the eps structure the degree jobs read at their own points (the phase's offSliceCheck) *)
  offCheck = With[{o = If[AssociationQ[d], Lookup[d, "OffSlice", None], None]},
    If[AssociationQ[o], check["away from the slice", TrueQ[o["Pass"]], o["Detail"]],
      Join[check["away from the slice", True, "no degree job's point was given"], <|"NotChecked" -> True|>]]];
  (* the eps structure of every row: no lowest power of eps drops, no eps-form row loses its form (PFBEpsFloorViolations) *)
  floors = PFBEpsFloorViolations[slOld, slNew];
  floorCheck = check["eps structure", floors === {}, If[floors === {}, "no row's lowest power of eps drops, and every eps-form row stays eps-form",
    "rows whose eps structure gets worse: " <> StringRiffle[epsFloorText[slNew] /@ Take[floors, UpTo[8]], "; "]]];
  checks = Join[keep, {rowsCheck, censusCheck, epsCheck, floorCheck, degCheck, offCheck}];
  <|"Pass" -> AllTrue[checks, #["Pass"] &], "Checks" -> checks, "Census" -> gate0["Census"], "Comparison" -> cmp,
    "Message" -> StringRiffle[(#["Name"] <> ": " <> verdictWord[#] <> " (" <> #["Detail"] <> ")") & /@ checks, "\n"]|>];


End[];
EndPackage[];
