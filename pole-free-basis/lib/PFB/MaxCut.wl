(* ::Package:: *)

(* ::Title:: *)
(*PoleFreeBasis`MaxCut`: rung 8 through the maximal-cut-basis toolkit*)


(* ::Text:: *)
(*The masters usually come from a maximal-cut-basis run of each family (system.wl "MCBRun", read only; without it this*)
(*skill makes one in <run>/maxcut/<fam>/). When a sector's maximal-cut basis must change (rung 8, or a set of a scan that*)
(*changes the maximal cut), this skill drives that toolkit and the DE decides:*)
(*  1. candidates, in this kernel: the run's basis, the run's candidate steps replayed (MCBReplayCandidates), the*)
(*     toolkit's candidate routes for the sector (MCBRepresentations, MCBCandidatesFor: dlog candidates normalised by*)
(*     their leading singularities, curve candidates, single integrals), and the structural reading's;*)
(*  2. a filter before any reduction: hard rules 1, 2 and 4 (MCBRuleViolations: the d-dimensional candidates with*)
(*     coefficients rational in eps go), and each candidate keeps the square root of the master it replaces;*)
(*  3. one reduction with the candidates in the pool (PoolExtra), the pair scan over the sector's slots, ranked by the*)
(*     full rows as for rung 3 (poles, cap, deferred poles, the census);*)
(*  4. the finalists (the best few sets that clear the rows) through the maximal-cut gate in this kernel (MCBCheckBasis:*)
(*     Kira on the cut at two points, the Euler relation). A failed check refuses a set (Kira failing is no verdict: the*)
(*     set is not checked); the full rows rank the sets first (PFBScanKey), and among sets they rank equal eps-form on*)
(*     the cut breaks the tie, then an eps-polynomial DE with the smaller spread, then (non-dlog sectors) a set with an*)
(*     undotted element (the all-dot flag); eps-form is never a requirement;*)
(*  5. PFBTryChange records the verdict, and runs the check itself for a change that alters the maximal cut when none is*)
(*     given (rung-3 sets included).*)


BeginPackage["PoleFreeBasis`MaxCut`", {"PoleFreeBasis`", "PoleFreeBasis`Config`", "PoleFreeBasis`System`", "PoleFreeBasis`Slice`", "PoleFreeBasis`Census`",
  "PoleFreeBasis`Subtree`", "PoleFreeBasis`Transform`", "PoleFreeBasis`Rungs`", "PoleFreeBasis`Gate`",
  "MaximalCutBasis`", "SkillCore`Tools`", "SkillCore`Records`", "MaximalCutBasis`Family`", "MaximalCutBasis`Sectors`", "MaximalCutBasis`Rules`",
  "MaximalCutBasis`Derivatives`", "MaximalCutBasis`Kira`", "MaximalCutBasis`Baikov`", "MaximalCutBasis`DECheck`", "MaximalCutBasis`Candidates`",
  "MaximalCutBasis`AutoPass`", "MaximalCutBasis`Reports`", "SkillCore`Citations`"}];

PFBMaxCutRun::usage = "PFBMaxCutRun[sys, runDir, fam, opts] is the maximal-cut-basis run of a base family (of an image: its base's): <|\"Dir\" (the run folder), \"Given\" (True for system.wl \"MCBRun\", which is only read, never written), \"Own\" (<runDir>/maxcut/<fam>/: this skill's own run, made when there is no \"MCBRun\", with a run.wl that maximal-cut-basis's scripts accept), \"Family\"|>. opts \"Paths\": the paths.wl for the own run (default the run's).";
PFBMaxCutFilter::usage = "PFBMaxCutFilter[sys, key, cands] filters candidates for a new maximal-cut basis of the sector key before any reduction. A candidate is a maximal-cut-basis candidate <|\"r2\" -> R, \"K\" -> rational combination, ...|> (J = Sqrt[R] K), an integral j[...] or a root-free definition (the structural reading's), optionally with \"source\". Hard rules 1, 2 and 4 on J (MCBRuleViolations without letters: the d-dimensional candidates with coefficients rational in eps go); J keeps the square root of the master it replaces: a slot (a master of the sector's base family) takes it only when Sqrt[R] is the slot's prefactor times a rational function, and its definition there is root-free (an overall number from the root, a phase included, dropped), with the slot's lowest power of eps as its own lowest power (as for the scans' integrals). Returns <|\"Kept\" -> {<|\"Label\", \"Source\", \"Provenance\", \"Defs\" -> <|slot -> root-free def|>, \"Integrals\", \"Dotted\", \"Priority\"|>..}, \"Dropped\" -> {<|\"Label\", \"Source\", \"Reasons\"|>..}, \"Slots\"|>.";
PFBMaxCutCandidates::usage = "PFBMaxCutCandidates[sys, key, opts] builds the candidates of a new maximal-cut basis of the sector key in this kernel and filters them (PFBMaxCutFilter): the basis of the maximal-cut-basis run (opts \"MCBRun\", a run folder), the run's candidate steps replayed from the sector's AnalysisMasters.m (MCBReplayCandidates), the toolkit's candidate routes for the first \"Reps\" (3) representations (MCBCandidatesFor, each under \"TimeLimit\" seconds, 300), and \"Extra\" (the structural reading's integrals or root-free definitions). \"Routes\" -> False and \"Replay\" -> False leave those out; \"Representations\" gives them. At most \"MaxCandidates\" (30) are kept: the run's basis, then replayed steps, the structural reading, the routes, each in maximal-cut-basis's order (MCBOrderKey). Returns <|\"Candidates\", \"Dropped\", \"Slots\", \"MCBRun\", \"Status\" and \"Classification\" (of the run's sector), \"NonDlog\", \"Representations\", \"Seconds\", \"Message\"|>.";
PFBMaxCutJob::usage = "PFBMaxCutJob[ctx, key, cands, opts] writes the reduction job of a maximal-cut scan: the sector's subtree at the slice point and the run's extra points plus two for the gate, with the candidates' integrals (and their images) in the pool (PoolExtra) besides the natural integrals (PoolSpec {1, 1, 0, 0}), and its command.sh. cands: the candidates of PFBMaxCutCandidates. opts: \"Name\" (<fam>_<jPATTERN>_maxcut), \"Replace\", \"Spec\" (more PFBSubtreeJob keys). Returns the job folder.";
PFBWriteMaxCutCandidates::usage = "PFBWriteMaxCutCandidates[runDir, key, result] writes the candidates of PFBMaxCutCandidates to the sector folder (maxcut_candidates.m) and records them in attempts.m (rung 8). Returns the file.";
PFBReadMaxCutCandidates::usage = "PFBReadMaxCutCandidates[runDir, key] reads maxcut_candidates.m of the sector (Missing[\"NotWritten\"] when bin/maxcut_candidates.wls has not run for it).";
PFBMaxCutScanCandidates::usage = "PFBMaxCutScanCandidates[result] are the candidates of a maximal-cut scan as PFBSlotSets takes them: one <|slot -> root-free def|> per candidate.";
PFBMaxCutCheck::usage = "PFBMaxCutCheck[sys, key, defs, opts] runs the maximal-cut gate on the sector's new basis (defs = <|label -> root-free def|> for base-family masters; the others unchanged; PFBMaxCutBasis): MCBCheckBasis in this kernel, Kira on the cut at two random points (those of the run's basis.m, else opts \"Points\" or MCBPoints with \"Seed\"), exactly in eps, the Euler relation. opts: \"MCBRun\" (the run folder: its points and Picard-Fuchs classification), \"Classification\", \"Representations\" (for MCBStatusFor; default computed when BaikovPackage is there), \"Dir\" (Kira's scratch; default a temporary folder, deleted unless Kira failed), \"Check\" (a function called as MCBCheckBasis[fam, sector, basis, dir, <|\"Points\" -> pts|>], for tests only: the verdict's \"Tool\" is then \"planted\", which PFBTryChange takes only with \"AllowPlantedCheck\" -> True). Returns the verdict <|\"Status\" (MCBStatusFor), \"Check\" (MCBCheckBasis's status), \"Range\", \"Spread\", \"k\", \"Euler\", \"Refuses\" (True for a failed check: the Euler relation broken, dependent elements, or a count that is not the cut's), \"ToolFailure\" (None, or why the check could not run: Kira failing or stopped at a limit, a basis it could not read; no verdict on the basis, so the set is not refused), \"AllDot\", \"NonDlog\", \"Flag\", \"Checks\", \"Points\", \"NMastersCut\", \"Message\", \"Basis\" (the whole sector basis checked, PFBMaxCutBasis), \"Labels\", \"Defs\", \"Tool\" (\"Kira (MCBCheckBasis)\" or \"planted\"), \"Date\"|>.";
PFBMaxCutAllDotQ::usage = "PFBMaxCutAllDotQ[sys, key, defs, nonDlog] is True when the sector's new basis on its base family (defs = <|label -> root-free def|>, the other masters unchanged; PFBMaxCutBasis) has every element dotted and the sector is not dlog (nonDlog: the run's status or Picard-Fuchs label, PFBMaxCutCandidates \"NonDlog\"): the all-dot flag. On a dlog sector, or when nonDlog is unknown, it is False.";
PFBMaxCutRank::usage = "PFBMaxCutRank[entries] orders the finalists of a maximal-cut scan, entries = {<|\"Result\" -> scan result (PFBScanSets), \"Verdict\" -> PFBMaxCutCheck|>..} in the scan's order: sets that clear the sector's rows (no pole left, none new, none raised above the cap) first, then sets the maximal-cut gate could not check (\"ToolFailure\"), refused sets (a failed maximal-cut check) last; within each group by the full rows, as the scan ranks them (PFBScanKey but its last key: poles, deferred poles, the census, negative powers, the power of eps), and among sets those keys rank equal, eps-form on the cut, then an eps-polynomial DE with the smaller spread of powers of eps, then, on a non-dlog sector, a set with an undotted element (the all-dot flag); then the digit height of the sector's rows (PFBScanKey's last key: it orders only sets equal on all of these); then the scan's order. Returns the entries with \"Rank\", \"Clears\", \"Refused\", \"NotChecked\" and \"TieBreak\".";
PFBMaxCutFinalists::usage = "PFBMaxCutFinalists[sys, key, results, opts] takes the best \"Finalists\" (3) sets of a scan (results: PFBScanSets's, best first) that clear the sector's rows, checks each with PFBMaxCutCheck (opts as there, once per sector for the representations), ranks them (PFBMaxCutRank), and with \"RunDir\" writes maxcut_finalists.m to the sector folder and records the checks in attempts.m. Returns <|\"Finalists\" (ranked, each with \"Defs\": the masters the set changes), \"Message\"|>.";
PFBReadMaxCutFinalists::usage = "PFBReadMaxCutFinalists[runDir, key] reads maxcut_finalists.m of the sector: the ranked finalists, each <|\"Rank\", \"Defs\", \"Verdict\", \"Result\", \"Clears\", \"Refused\", \"TieBreak\"|> (pass \"Defs\" to PFBTryChange with \"MaxCutCheck\" -> \"Verdict\"); {} when there is none.";
PFBMaxCutGateCheck::usage = "PFBMaxCutGateCheck[gate, verdict] adds the check \"maximal cut\" to a gate's result: a verdict of PFBMaxCutCheck passes unless it refuses; <|\"Skipped\" -> reason|> (Kira not available) and <|\"NotRun\" -> reason|> pass as not checked. Returns the gate with Pass and Message updated.";
PFBImportMaxCutCredits::usage = "PFBImportMaxCutCredits[mcbRun, key, runDir, opts] copies the credits of the sector of key in a maximal-cut-basis run mcbRun (system.wl \"MCBRun\", or this skill's own <run>/maxcut/<fam>; None: nothing): every tool and paper its ledger (or its older records) gives that sector, into the ledger of the pole-free run runDir (citations.m), for the sector \"fam/jPATTERN\", via \"maximal-cut-basis run <folder name>\" (CoreImportCitations), stamped with what it went into: opts \"Change\" -> the id of the recorded change that took the run's basis, steps, candidates, classification or normalisations (PFBTryChange: a rung-8 change, the maximal-cut gate, a move (i) rescaling), or \"Start\" -> the labels of the sector's starting masters (PFBStartCredits). The reader cites a copy only while that change is accepted (or pending), or a starting master is left. Without the sector's folder in mcbRun nothing is copied. Returns the entries appended.";
PFBMaxCutRunDir::usage = "PFBMaxCutRunDir[sys, runDir, fam] is the folder of the maximal-cut-basis run of a family (of an image: its base's) when there is one: system.wl \"MCBRun\", else this skill's own <runDir>/maxcut/<fam> once made (PFBMaxCutRun makes it); None otherwise. Nothing is created.";
PFBMaxCutSummary::usage = "PFBMaxCutSummary[verdict] is the verdict as change records and pages keep it (status, range, Euler relation, all-dot flag, points, tool, or why it was not checked).";

Begin["`Private`"];


(* ::Section:: *)
(*The run of a family*)


baseSlots[sys_, key_] := PFBMaxCutBasis[sys, key];
lowPow[sys_, l_] := With[{p = DeleteCases[Flatten[PFBEpsPowers[PFBMaster[sys, l]["RootFree"]][[All, 2]]], _String]}, If[p === {}, 0, Min[p]]];
sectorDirOf[run_, s_] := If[StringQ[run], FileNameJoin[{run, SectorName[s]}], None];

PFBMaxCutRun[sys_Association, runDir_, fam_, opts_Association : <||>] := Module[{fn = If[StringQ[fam], ToExpression[fam], fam], fe, own, famFile, paths},
  fe = sys["Families"][fn];
  If[fe["Image"] =!= None, Return[PFBMaxCutRun[sys, runDir, fe["Base"], opts]]];
  own = If[StringQ[runDir], FileNameJoin[{runDir, "maxcut", ToString[fn]}], None];
  If[StringQ[Lookup[fe, "MCBRun", None]], Return[<|"Dir" -> fe["MCBRun"], "Given" -> True, "Own" -> own, "Family" -> fn|>]];
  If[own === None, Return[<|"Dir" -> None, "Given" -> False, "Own" -> None, "Family" -> fn|>]];
  (* this skill's own run of the family: run.wl (maximal-cut-basis's scripts take it, e.g. run_sector.wls for a first
     pass) and the run_info.m that MCBRunSetup would write *)
  If[! FileExistsQ[FileNameJoin[{own, "run_info.m"}]],
    famFile = fe["Object"]["File"];
    paths = Replace[Lookup[opts, "Paths", Automatic], Automatic :> If[StringQ[$MCBPathsFile], $MCBPathsFile, Automatic]];
    If[! DirectoryQ[own], CreateDirectory[own, CreateIntermediateDirectories -> True]];
    Put[<|"Family" -> famFile, "OutputDir" -> own, "Paths" -> paths|>, FileNameJoin[{own, "run.wl"}]];
    Put[<|"Run" -> Join[$MCBRunDefaults, <|"Family" -> famFile, "OutputDir" -> own, "Paths" -> paths, "RunFile" -> FileNameJoin[{own, "run.wl"}]|>],
      "FamilyFile" -> famFile, "PathsFile" -> paths, "OutputDir" -> own|>, FileNameJoin[{own, "run_info.m"}]]];
  <|"Dir" -> own, "Given" -> False, "Own" -> own, "Family" -> fn|>];


(* the credits of the maximal-cut-basis run's sector go with what this run takes from it (its basis, steps, candidates,
   classification, normalisations), stamped with the change that took it, or with the starting masters it gave: what is
   only read for candidates that no change takes is never credited. CoreImportCitations does not copy an entry twice *)
Options[PFBImportMaxCutCredits] = {"Change" -> None, "Start" -> False};
PFBImportMaxCutCredits[run_, key_List, dir_String, OptionsPattern[]] := If[! StringQ[run] || ! DirectoryQ[FileNameJoin[{run, SectorName[key[[2]]]}]], {},
  CoreImportCitations[dir, run, SectorName[key[[2]]], PFBSectorString[key], "maximal-cut-basis run " <> FileNameTake[ExpandFileName[run]],
    "Change" -> OptionValue["Change"], "Start" -> OptionValue["Start"]]];
PFBImportMaxCutCredits[___] := {};

PFBMaxCutRunDir[sys_Association, runDir_, fam_] := Module[{b = PFBBaseOf[sys, fam], given, own},
  given = Lookup[sys["Families"][b], "MCBRun", None];
  own = If[StringQ[runDir], FileNameJoin[{runDir, "maxcut", ToString[b]}], None];
  Which[StringQ[given], given, StringQ[own] && FileExistsQ[FileNameJoin[{own, "run_info.m"}]], own, True, None]];


(* ::Section:: *)
(*Candidates*)


(* Sqrt[R] is the slot's prefactor times a rational function and a number when R / pref^2 has only even powers of its
   factors that depend on the invariants; the rational function (the number goes: an overall constant, a phase from a
   sign under the root included, changes nothing in the DE, as maximal-cut-basis drops it from its normalisations), or
   None *)
rootRatio[R_, pref_] := Module[{q = Factor[Together[R/pref^2]], fl, ev},
  fl = Join[FactorList[Numerator[q]], {#[[1]], -#[[2]]} & /@ FactorList[Denominator[q]]];
  ev = Select[fl, ! NumericQ[#[[1]]] &];
  If[AnyTrue[ev, OddQ[#[[2]]] &], None, Times @@ (#[[1]]^(#[[2]]/2) & /@ ev)]];

labelOf[c_] := Which[AssociationQ[c], Lookup[c, "label", ""], True, With[{t = ToString[c, InputForm]}, If[StringLength[t] > 120, StringTake[t, 117] <> "...", t]]];
sourceOf[c_] := If[AssociationQ[c], Lookup[c, "source", "maximal-cut-basis"], "structural reading"];
(* the structural reading's candidates may come wrapped with a source: <|"Def" -> expr, "source" -> ...|> *)
plainOf[c_] := If[AssociationQ[c] && KeyExistsQ[c, "Def"] && ! KeyExistsQ[c, "K"], c["Def"], c];

PFBMaxCutFilter[sys_Association, key_List, cands_List, opts_Association : <||>] := Module[{fo = PFBFamily[sys, key[[1]]], s = key[[2]], slots = baseSlots[sys, key], kept = {}, dropped = {}},
  Do[Module[{c = plainOf[c0], why = {}, defs = <||>, J, R, Krat, low, viol, ints},
     If[AssociationQ[c] && KeyExistsQ[c, "K"],
       (* a maximal-cut-basis candidate J = Sqrt[R] K, as MCBMasterExpression writes it *)
       {R, Krat} = MCBSplitRoot[c["r2"], c["K"]];
       J = If[R === 1, Krat, Sqrt[R] Krat];
       viol = MCBRuleViolations[fo, J, <|"Letters" -> {}|>];
       If[viol =!= {}, why = viol,
         low = MCBWrittenEpsPower[J][[1]];
         Do[With[{rr = rootRatio[R, PFBMaster[sys, l]["Pref"]]}, If[rr =!= None,
             defs[l] = If[MCBLargeQ[Krat], eps^(lowPow[sys, l] - low) rr Krat, Collect[eps^(lowPow[sys, l] - low) rr Krat, _j, Together]]]], {l, slots}];
         If[defs === <||>, why = {"root: Sqrt[" <> ToString[R, InputForm] <> "] is not the square root of a master it could replace (" <>
           StringRiffle[("ut[" <> ToString[#] <> "]: " <> ToString[PFBMaster[sys, #]["Pref"], InputForm]) & /@ slots, ", "] <> ")"}]],
       (* the structural reading's: an integral carries the slot's power of eps, a root-free definition is used as given *)
       viol = If[MatchQ[c, _j], {}, PFBRuleViolations[sys, c, <|"Letters" -> {}|>]];
       If[viol =!= {}, why = viol, defs = Association[Table[l -> If[MatchQ[c, _j], eps^lowPow[sys, l] c, c], {l, slots}]]]];
     If[why =!= {},
       AppendTo[dropped, <|"Label" -> labelOf[c0], "Source" -> sourceOf[c0], "Reasons" -> why|>],
       ints = Union[Cases[Values[defs] /. ut[k_Integer] :> PFBMaster[sys, k]["RootFree"] /. Dinv[a_, _] :> a, _j, Infinity]];
       AppendTo[kept, <|"Label" -> labelOf[c0], "Source" -> sourceOf[c0], "Provenance" -> If[AssociationQ[c], Lookup[c, "provenance", "maximal-cut-basis"], "structural reading"],
         "Defs" -> defs, "Integrals" -> ints, "Dotted" -> MCBDottedQ[First[Values[defs]] /. ut[k_Integer] :> PFBMaster[sys, k]["RootFree"], s],
         "Priority" -> MCBOrderKey[Join[<|"r2" -> 1, "strict" -> False, "priority" -> 5, "weight" -> {0, 0, 0}|>, If[AssociationQ[c], c, <||>]]]|>]]],
    {c0, cands}];
  (* the same definitions twice: the first is kept *)
  kept = DeleteDuplicatesBy[kept, Function[k, Collect[Values[k["Defs"]], _j, Together]]];
  <|"Kept" -> kept, "Dropped" -> dropped, "Slots" -> slots|>];

(* the steps of the run's AnalysisMasters.m: steps = {...}, cd = reps[[n]], reps = MCBRepresentations[fam, sector, opts],
   read as held expressions (nothing in the script runs) *)
scriptSteps[sd_String] := Module[{f = FileNameJoin[{sd, "AnalysisMasters.m"}], held, nameQ, steps, idx, ropts},
  If[! FileExistsQ[f], Return[<|"Steps" -> {}, "RepIndex" -> 1, "RepOptions" -> <||>|>]];
  held = Block[{$Context = "PoleFreeBasis`MaxCut`Script`", $ContextPath = {"System`", "MaximalCutBasis`", "Global`"}},
    Quiet@Check[ImportString[Import[f, "Text"], {"Package", "HeldExpressions"}], {}]];
  SetAttributes[nameQ, HoldFirst]; nameQ[x_Symbol, n_] := SymbolName[Unevaluated[x]] === n; nameQ[_, _] := False;
  steps = Cases[held, HoldPattern[Set[x_Symbol, rhs_List]] /; nameQ[x, "steps"] :> rhs, Infinity];
  idx = Cases[held, HoldPattern[Set[x_Symbol, Part[_, n_Integer]]] /; nameQ[x, "cd"] :> n, Infinity];
  ropts = Cases[held, HoldPattern[Set[x_Symbol, _[_, _, o_Association]]] /; nameQ[x, "reps"] :> o, Infinity];
  <|"Steps" -> If[steps === {}, {}, Select[First[steps], AssociationQ]], "RepIndex" -> If[idx === {}, 1, First[idx]], "RepOptions" -> If[ropts === {}, <||>, First[ropts]]|>];

tag[cs_List, src_String] := (Append[#, "source" -> src] & /@ Select[cs, AssociationQ[#] && KeyExistsQ[#, "K"] &]);
sourceRank = <|"the run's basis" -> 0, "replay" -> 1, "structural reading" -> 2|>;

PFBMaxCutCandidates[sys_Association, key_List, opts_Association : <||>] := Module[{fn = key[[1]], s = key[[2]], fo, slots, nmi, run, sd, old, reps, raw = {}, msgs = {},
    tl = Lookup[opts, "TimeLimit", 300], t0 = AbsoluteTime[], res, kept, info, apo, cap = Lookup[opts, "MaxCandidates", 30], routes = TrueQ[Lookup[opts, "Routes", True]], sc},
  fo = PFBFamily[sys, fn]; slots = baseSlots[sys, key]; nmi = Length[slots];
  run = Lookup[opts, "MCBRun", None]; sd = sectorDirOf[run, s];
  old = If[StringQ[sd] && DirectoryQ[sd], MCBReadBasis[sd], <||>];
  info = If[StringQ[run], Quiet[Get[FileNameJoin[{run, "run_info.m"}]]], None];
  (* the run's own options for the candidate routes (run.wl "AutoPass": nd, nt, w) *)
  apo = If[AssociationQ[info], Lookup[Lookup[info, "Run", <||>], "AutoPass", <||>], <||>];
  sc = If[StringQ[sd], scriptSteps[sd], <|"Steps" -> {}, "RepIndex" -> 1, "RepOptions" -> <||>|>];
  reps = Replace[Lookup[opts, "Representations", Automatic], Automatic :> If[routes || (TrueQ[Lookup[opts, "Replay", True]] && sc["Steps"] =!= {}),
      Replace[Quiet@Check[TimeConstrained[MCBRepresentations[fo, s, Join[<|"TimeLimit" -> 120|>, sc["RepOptions"]]], 600, {}], {}], Except[_List] -> {}], {}]];
  If[reps === {} && (routes || sc["Steps"] =!= {}), AppendTo[msgs, "no Baikov representation (BaikovPackage missing, or every representation degenerate): no routes and no replay"]];
  (* 1. the run's basis: the masters it chose for this sector *)
  If[StringQ[sd] && ListQ[Quiet[MCBReadMasters[sd]]], With[{ms = MCBReadMasters[sd]},
    raw = Join[raw, tag[Table[With[{sp = MCBSplitMaster[ms[[i]]]}, If[AssociationQ[sp], Join[sp, <|"label" -> "the run's J" <> ToString[i],
        "provenance" -> "the basis of the maximal-cut-basis run", "priority" -> 0|>], Nothing]], {i, Length[ms]}], "the run's basis"]]]];
  (* 2. the run's steps, replayed *)
  If[TrueQ[Lookup[opts, "Replay", True]] && sc["Steps"] =!= {} && reps =!= {},
    raw = Join[raw, tag[Replace[Quiet@TimeConstrained[MCBReplayCandidates[fo, s, reps, sc["Steps"],
        <|"cd" -> reps[[Min[sc["RepIndex"], Length[reps]]]], "nmi" -> nmi, "dir" -> sd|>], tl Length[sc["Steps"]], {}], Except[_List] -> {}], "replay"]]];
  (* 3. the routes of the first representations *)
  If[routes, Do[With[{r = Quiet@TimeConstrained[MCBCandidatesFor[fo, s, cd, Join[$MCBDefaultOptions, apo, <|"nmi" -> nmi, "tlim" -> tl|>]], tl, <|"status" -> "timeout", "candidates" -> {}|>]},
      If[! AssociationQ[r] || Lookup[r, "candidates", {}] === {}, AppendTo[msgs, "route " <> MCBRouteFor[cd] <> " of " <> cd["kind"] <> " " <> ToString[cd["order"]] <> ": " <>
          If[AssociationQ[r], ToString[Lookup[r, "status", "no candidates"]], "failed"]]];
      raw = Join[raw, tag[If[AssociationQ[r], Lookup[r, "candidates", {}], {}], "route " <> MCBRouteFor[cd] <> " (" <> cd["kind"] <> " " <> ToString[cd["order"], InputForm] <> ")"]]],
    {cd, Take[reps, UpTo[Lookup[opts, "Reps", 3]]]}]];
  (* 4. the structural reading's *)
  raw = Join[raw, Lookup[opts, "Extra", {}]];
  res = PFBMaxCutFilter[sys, key, raw];
  kept = SortBy[res["Kept"], {Lookup[sourceRank, #["Source"], 3], #["Priority"]} &];
  If[Length[kept] > cap, AppendTo[msgs, ToString[Length[kept] - cap] <> " candidates beyond \"MaxCandidates\" (" <> ToString[cap] <> ") left out"]; kept = Take[kept, cap]];
  <|"Candidates" -> kept, "Dropped" -> res["Dropped"], "Slots" -> slots, "MCBRun" -> run, "Status" -> Lookup[old, "status", Missing["NotRun"]],
    "Classification" -> Lookup[old, "classification", Missing["NotRun"]], "NonDlog" -> If[old === <||>, Missing["NoRun"], MCBNonDlogQ[Lookup[old, "status", ""], Lookup[old, "classification", None]]],
    "Representations" -> Length[reps], "Seconds" -> Round[AbsoluteTime[] - t0], "Notes" -> msgs,
    "Message" -> PFBSectorString[key] <> ": " <> ToString[Length[kept]] <> " candidates for the slots " <> ToString[ut /@ slots] <> " (" <>
      StringRiffle[KeyValueMap[ToString[#2] <> " " <> #1 &, Counts[kept[[All, "Source"]]]], ", "] <> "), " <> ToString[Length[res["Dropped"]]] <> " dropped by the hard rules or the square root" <>
      If[msgs === {}, "", "; " <> StringRiffle[msgs, "; "]]|>];

PFBMaxCutScanCandidates[res_Association] := #["Defs"] & /@ Lookup[res, "Candidates", {}];

candFile[dir_, key_] := FileNameJoin[{PFBSectorDir[dir, key], "maxcut_candidates.m"}];
PFBWriteMaxCutCandidates[dir_String, key_List, res_Association] := Module[{f = candFile[dir, key]},
  If[! DirectoryQ[PFBSectorDir[dir, key]], CreateDirectory[PFBSectorDir[dir, key], CreateIntermediateDirectories -> True]];
  Put[Join[res, <|"Key" -> key, "Date" -> PFBTimeStamp[]|>], f];
  MCBAppendAttempt[PFBSectorDir[dir, key], <|"rung" -> 8, "what" -> "maximal-cut candidates (maximal-cut-basis toolkit)", "outcome" -> res["Message"]|>];
  f];
PFBReadMaxCutCandidates[dir_String, key_List] := With[{f = candFile[dir, key]}, If[FileExistsQ[f], Get[f], Missing["NotWritten"]]];

(* Records loads after this file: its function by full name *)
PFBMaxCutJob[ctx_Association, key_List, cands_List, opts_Association : <||>] := Module[{sys = ctx["System"], sl = PoleFreeBasis`Records`PFBCurrentSlice[ctx["Dir"], ctx["State"]], ints, extra, job, run = ctx["Run"]},
  ints = Union[Flatten[Lookup[cands, "Integrals", {}]]];
  (* the image families' copies too: the scans map every definition onto the images *)
  extra = Union[Flatten[Table[Prepend[Table[j[im, Sequence @@ Rest[c]], {im, PFBImagesOf[sys, c[[1]]]}], c], {c, ints}]]];
  job = PFBSubtreeJob[sys, ctx["Dir"], Join[<|"Name" -> Lookup[opts, "Name", StringReplace[PFBSectorString[key], "/" -> "_"] <> "_maxcut"], "SectorKey" -> key,
     "Points" -> Join[{sl["Point"]}, PFBRandomPoints[sys, Lookup[run, "ExtraPoints", 2] + 2, 1]], "Derivatives" -> sl["Derivatives"],
     "Seeds" -> Lookup[run, "Seeds", <|"Rank" -> 3, "Dots" -> 2|>], "MaxGB" -> Lookup[run, "MaxGB", None], "TimeLimit" -> Lookup[run, "TimeLimit", 86400],
     "Threads" -> Replace[Lookup[run, "Threads", Automatic], Automatic -> Max[1, Min[8, $ProcessorCount - 1]]], "Reducer" -> Lookup[run, "Reducer", Automatic],
     "PoolSpec" -> {1, 1, 0, 0}, "PoolExtra" -> extra, "Replace" -> TrueQ[Lookup[opts, "Replace", False]]|>, Lookup[opts, "Spec", <||>]]];
  If[StringQ[job] && DirectoryQ[job], Export[FileNameJoin[{job, "command.sh"}], PFBSubtreeCommand[job] <> "\n", "Text"]];
  job];


(* ::Section:: *)
(*The maximal-cut gate*)


(* the masters a set changes: entries equal to the current master are left out *)
changed[sys_, defs_] := KeySelect[defs, Function[l, Together[defs[l] - PFBMaster[sys, l]["RootFree"]] =!= 0]];

eulerOf[chk_] := Lookup[SelectFirst[Lookup[chk, "checks", {}], Lookup[#, "Name", ""] === "euler" &, <||>], "Pass", Missing["NotChecked"]];

PFBMaxCutCheck[sys_Association, key_List, defs0_Association, opts_Association : <||>] := Module[{fo = PFBFamily[sys, key[[1]]], s = key[[2]], labs, defs, basis, run, sd, old, pts,
    dir, tmpQ = False, chk, reps, cls, status, rng, nd, ad, spread, fun, tool},
  labs = baseSlots[sys, key];
  defs = KeySelect[defs0, MemberQ[labs, #] &];
  basis = PFBMaxCutBasis[sys, key, defs];
  run = Lookup[opts, "MCBRun", None]; sd = sectorDirOf[run, s];
  old = If[StringQ[sd] && DirectoryQ[sd], MCBReadBasis[sd], <||>];
  pts = Replace[Lookup[opts, "Points", Automatic], Automatic :> If[ListQ[Lookup[old, "points", None]] && old["points"] =!= {}, old["points"], MCBPoints[fo, 2, Lookup[opts, "Seed", 1]]]];
  dir = Lookup[opts, "Dir", Automatic];
  If[dir === Automatic, dir = CreateDirectory[]; tmpQ = True];
  fun = Lookup[opts, "Check", MCBCheckBasis];
  chk = Replace[fun[fo, s, basis, dir, <|"Points" -> pts|>], Except[_Association] -> <|"status" -> "failed", "message" -> "the maximal-cut check returned nothing"|>];
  (* the check could not run (Kira failing, stopped at its time or memory limit, missing; a basis it could not read):
     no verdict on the basis. Only a verdict refuses: the Euler relation broken, dependent elements, the wrong count *)
  tool = Which[
    chk["status"] === "skipped by user", "the Kira check is skipped (run.wl \"Skip\" or $MCBSkip: \"kira-check\")",
    chk["status"] =!= "failed", None,
    StringStartsQ[Lookup[chk, "message", ""], {"Kira failed", "the maximal-cut check returned nothing", "a basis element is not of the form"}],
      "the maximal-cut check could not run: " <> Lookup[chk, "message", "no message"],
    True, None];
  (* the scratch goes, unless Kira failed: its folder holds kira.out *)
  If[tmpQ && ! StringContainsQ[Lookup[chk, "message", ""], "Kira failed"], Quiet@DeleteDirectory[dir, DeleteContents -> True]];
  reps = Replace[Lookup[opts, "Representations", Automatic], Automatic :> Replace[Quiet@Check[TimeConstrained[MCBRepresentations[fo, s], 600, {}], {}], Except[_List] -> {}]];
  cls = Replace[Lookup[opts, "Classification", Automatic], Automatic :> Lookup[old, "classification", None]];
  status = MCBStatusFor[chk, reps, cls];
  rng = Lookup[chk, "range", Missing[]];
  spread = Which[chk["status"] === "eps-form", 0, MatchQ[rng, {_?NumericQ, _?NumericQ}], rng[[2]] - rng[[1]], True, Infinity];
  nd = MCBNonDlogQ[status, cls];
  ad = MCBAllDotQ[basis, s];
  <|"Status" -> status, "Check" -> chk["status"], "Range" -> rng, "Spread" -> spread, "k" -> Lookup[chk, "k", Missing[]], "Euler" -> eulerOf[chk],
    "Refuses" -> (tool === None && ! MemberQ[{"eps-form", "eps-polynomial", "rational"}, chk["status"]]), "ToolFailure" -> tool, "AllDot" -> ad, "NonDlog" -> nd,
    "Flag" -> If[nd && ad, "all-dot: every element is dotted on a non-dlog sector: likely to carry a weight between sectors", None],
    "Checks" -> (KeyTake[#, {"Name", "Pass", "Detail"}] & /@ Lookup[chk, "checks", {}]), "Points" -> Lookup[chk, "points", pts], "NMastersCut" -> Lookup[chk, "nMastersCut", Missing[]],
    "Message" -> Lookup[chk, "message", ""], "Basis" -> basis, "Labels" -> labs, "Defs" -> defs, "Tool" -> If[fun === MCBCheckBasis, "Kira (MCBCheckBasis)", "planted"],
    "ScratchKept" -> If[tmpQ && DirectoryQ[dir], dir, None], "Date" -> PFBTimeStamp[]|>];

verdictText[v_Association] := Which[
  KeyExistsQ[v, "Skipped"], "not checked: " <> v["Skipped"],
  KeyExistsQ[v, "NotRun"], "not run: " <> v["NotRun"],
  StringQ[Lookup[v, "ToolFailure", None]], "not checked: " <> v["ToolFailure"],
  True, "maximal-cut-basis gate, " <> v["Tool"] <> ", " <> ToString[Length[Lookup[v, "Points", {}]]] <> " points: " <>
    Switch[v["Check"], "eps-polynomial", v["Status"] <> " " <> ToString[v["Range"]], "rational", "rational in eps on the cut (not refused: eps-form is a tie-breaker only)", _, v["Status"]] <> "; Euler relation " <> Which[v["Euler"] === True, "ok", v["Euler"] === False, "FAILED", True, "not checked"] <>
    If[TrueQ[v["Refuses"]], "; refused: " <> v["Message"], ""] <> If[StringQ[v["Flag"]], "; " <> v["Flag"], ""]];

PFBMaxCutSummary[v_Association] := Join[KeyTake[v, {"Status", "Check", "Range", "Spread", "k", "Euler", "Refuses", "ToolFailure", "AllDot", "NonDlog", "Flag", "Points", "Message", "Tool",
    "Skipped", "NotRun", "Given", "Date"}],
  <|"Text" -> verdictText[v]|>];

PFBMaxCutGateCheck[gate_Association, v_Association] := Module[{c, g = gate},
  c = <|"Name" -> "maximal cut", "Pass" -> (KeyExistsQ[v, "Skipped"] || KeyExistsQ[v, "NotRun"] || ! TrueQ[v["Refuses"]]),
    "Detail" -> verdictText[v], "NotChecked" -> (KeyExistsQ[v, "Skipped"] || KeyExistsQ[v, "NotRun"])|>;
  g["Checks"] = Append[Select[gate["Checks"], #["Name"] =!= "maximal cut" &], c];
  g["Pass"] = TrueQ[gate["Pass"]] && c["Pass"];
  g["Message"] = gate["Message"] <> "\nmaximal cut: " <> If[c["Pass"], If[c["NotChecked"], "not checked", "ok"], "FAILED"] <> " (" <> c["Detail"] <> ")";
  g];


(* ::Section:: *)
(*Finalists*)


clearsQ[r_] := Lookup[r, "bad", 1] == 0 && Lookup[r, "newBad", 1] === 0 && Lookup[r, "over", 1] == 0;
epsRank[v_] := Switch[Lookup[v, "Check", ""], "eps-form", 0, "eps-polynomial", 1, _, 2];

(* the full rows decide first, as the scan ranked the sets (PFBScanKey without its last key); the maximal cut breaks
   ties among them; then the digit height of the rows (the scan key's last), a free proxy that orders only sets equal
   on everything else, the maximal cut's tie-breaks included *)
toolFailedQ[v_] := StringQ[Lookup[v, "ToolFailure", None]];
PFBMaxCutRank[entries_List] := Module[{keyOf, ord},
  keyOf[i_] := With[{r = entries[[i]]["Result"], v = entries[[i]]["Verdict"]}, With[{cl = clearsQ[r], rf = TrueQ[Lookup[v, "Refuses", False]], tf = toolFailedQ[v], sk = PFBScanKey[r]},
    {Which[rf, 3, ! cl, 1, tf, 2, True, 0], Most[sk],
     If[cl && ! rf && ! tf, {epsRank[v], Lookup[v, "Spread", Infinity], If[TrueQ[Lookup[v, "NonDlog", False]] && TrueQ[Lookup[v, "AllDot", False]], 1, 0]}, {2, Infinity, 0}],
     Last[sk], i}]];
  ord = SortBy[Range[Length[entries]], keyOf];
  MapIndexed[Join[entries[[#1]], <|"Rank" -> First[#2], "Clears" -> clearsQ[entries[[#1]]["Result"]], "Refused" -> TrueQ[Lookup[entries[[#1]]["Verdict"], "Refuses", False]],
     "NotChecked" -> toolFailedQ[entries[[#1]]["Verdict"]], "TieBreak" -> keyOf[#1][[3]]|>] &, ord]];

PFBMaxCutAllDotQ[sys_Association, key_List, defs_Association, nonDlog_] := TrueQ[nonDlog] &&
  MCBAllDotQ[PFBMaxCutBasis[sys, key, KeySelect[defs, MemberQ[PFBMaxCutBasis[sys, key], #] &]], key[[2]]];

finFile[dir_, key_] := FileNameJoin[{PFBSectorDir[dir, key], "maxcut_finalists.m"}];

PFBMaxCutFinalists[sys_Association, key_List, results_List, opts_Association : <||>] := Module[{pick, reps, run, sd, cls, ents, ranked, msg, dir = Lookup[opts, "RunDir", None]},
  pick = Take[Select[results, clearsQ], UpTo[Lookup[opts, "Finalists", 3]]];
  If[pick === {}, Return[<|"Finalists" -> {}, "Message" -> "no set clears the sector's rows: nothing to check on the maximal cut"|>]];
  run = Lookup[opts, "MCBRun", None]; sd = sectorDirOf[run, key[[2]]];
  reps = Replace[Lookup[opts, "Representations", Automatic], Automatic :> Replace[Quiet@Check[TimeConstrained[MCBRepresentations[PFBFamily[sys, key[[1]]], key[[2]]], 600, {}], {}], Except[_List] -> {}]];
  cls = Replace[Lookup[opts, "Classification", Automatic], Automatic :> If[StringQ[sd] && DirectoryQ[sd], Lookup[MCBReadBasis[sd], "classification", None], None]];
  ents = Table[With[{d = changed[sys, r["set"]]}, <|"Defs" -> d, "Result" -> KeyDrop[r, {"set", "left"}],
      "Verdict" -> PFBMaxCutCheck[sys, key, d, Join[KeyDrop[opts, {"RunDir", "Finalists"}], <|"Representations" -> reps, "Classification" -> cls|>]]|>], {r, pick}];
  ranked = PFBMaxCutRank[ents];
  msg = PFBSectorString[key] <> ": " <> ToString[Length[ranked]] <> " finalists through the maximal-cut gate; first: " <>
    StringRiffle[("ut[" <> ToString[#] <> "]") & /@ Keys[First[ranked]["Defs"]], ", "] <> " (" <> verdictText[First[ranked]["Verdict"]] <> ")" <>
    If[AllTrue[ranked, #["Refused"] &], "; every finalist is refused by the maximal-cut gate", ""] <>
    With[{nc = Count[ranked, f_ /; f["NotChecked"]]}, If[nc > 0, "; " <> ToString[nc] <> " not checked: " <> First[Select[ranked, #["NotChecked"] &]]["Verdict"]["ToolFailure"], ""]];
  If[StringQ[dir],
    If[! DirectoryQ[PFBSectorDir[dir, key]], CreateDirectory[PFBSectorDir[dir, key], CreateIntermediateDirectories -> True]];
    Put[ranked, finFile[dir, key]];
    MCBAppendAttempt[PFBSectorDir[dir, key], <|"rung" -> 8, "what" -> "maximal-cut gate on the finalists of the scan", "outcome" -> msg|>]];
  <|"Finalists" -> ranked, "Message" -> msg|>];

PFBReadMaxCutFinalists[dir_String, key_List] := With[{f = finFile[dir, key]}, If[FileExistsQ[f], Get[f], {}]];


End[];
EndPackage[];
