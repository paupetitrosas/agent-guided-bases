(* ::Package:: *)

(* ::Title:: *)
(*PoleFreeBasis`Records`: run state, sector records, exported masters, CHANGES.md*)


BeginPackage["PoleFreeBasis`Records`", {"PoleFreeBasis`", "PoleFreeBasis`Config`", "PoleFreeBasis`System`", "PoleFreeBasis`Singularities`", "PoleFreeBasis`Slice`",
  "PoleFreeBasis`Census`", "PoleFreeBasis`Transform`", "PoleFreeBasis`Gate`", "PoleFreeBasis`MaxCut`", "MaximalCutBasis`", "SkillCore`Tools`", "SkillCore`Records`", "SkillCore`Pages`",
  "MaximalCutBasis`Sectors`", "MaximalCutBasis`Rules`", "MaximalCutBasis`Reports`", "MaximalCutBasis`Kira`", "MaximalCutBasis`AutoPass`", "PoleFreeBasis`Rungs`",
  "SkillCore`Citations`"}];

$PFBRunDefaults::usage = "$PFBRunDefaults are the defaults of run.wl (reference/formats.md).";
PFBReadRun::usage = "PFBReadRun[file] reads run.wl, fills the defaults and makes the paths absolute.";
PFBStartRun::usage = "PFBStartRun[runFile] reads run.wl and the system, loads the tool paths, creates the run folder and its state, sets $PFBMaxEpsDegree from the run's \"MaxEpsDegree\", and sets the citation context to the whole run (CoreCitationContext: a tool used in this kernel is credited in the run's ledger, citations.m, until a sector's context is set; the step is the script's name). Returns <|\"Run\", \"System\", \"Dir\", \"State\"|>; System already has the accepted changes of earlier sessions applied.";
PFBLoadState::usage = "PFBLoadState[runDir] reads state.m.";
PFBSaveState::usage = "PFBSaveState[runDir, state] writes state.m.";
PFBCurrentSlice::usage = "PFBCurrentSlice[runDir, state] loads the slice of the current basis.";
PFBStoreSlice::usage = "PFBStoreSlice[runDir, state, sl, census, label] saves a new current slice and its census; returns the new state.";
PFBRecordChange::usage = "PFBRecordChange[runDir, state, sys, change, gate, info] records a change that passed the gate: accepted (autonomous mode) or pending (run option \"Approval\" -> True). info: Rung, Provenance, Sources, Residues, Completion, MaxCutChanged, MaxCutCheck (the maximal-cut-basis gate's verdict, PFBMaxCutSummary), ProfileBefore, ProfileAfter, Notes. Returns <|\"State\", \"System\", \"Status\" -> \"accepted\" | \"pending\" | \"rejected\"|>.";
PFBApprove::usage = "PFBApprove[runDir, state, sys, id] accepts a pending change after the user's approval, and records the outcome in the run's ledger (CoreRecordOutcome: the change's papers are then cited as accepted); returns <|\"State\", \"System\"|>.";
PFBChangeKeys::usage = "PFBChangeKeys[sys, record] are the sector keys a recorded change belongs to: its \"Key\", or, for a simplification without one (rung \"simplify\", key None: masters of several sectors), the sectors of the masters it replaces (images included, by their base sector); {} for a rescale of rung 1. Sector pages, sector statuses, the summary and CHANGES.md list a change under these sectors.";
PFBDecline::usage = "PFBDecline[runDir, state, sys, id, reason] declines a pending change after the user said no (bin/approve.wls run.wl --decline id): it leaves \"Pending\" for \"Rejected\" with \"Declined\" (the date) and \"DeclineReason\", the slice proposed with it is dropped, the sectors of the change log it in their attempts, and the run's ledger records the outcome (CoreRecordOutcome: the change's papers are then only consulted). A pending move of the simplification phase is then marked declined and the phase goes on. Returns <|\"State\", \"Record\"|> (\"Record\" None when no pending change has that id).";
PFBApplyAccepted::usage = "PFBApplyAccepted[sys, state] is the system with every accepted change applied.";
PFBSectorStatus::usage = "PFBSectorStatus[sys, state, census, key] is the status of a sector (one of $PFBStatuses).";
PFBWriteSectorRecord::usage = "PFBWriteSectorRecord[runDir, sys, state, census, key] writes the sector folder's basis.m (extended maximal-cut-basis schema) and masters.m; returns the record.";
PFBAppendAttempt::usage = "PFBAppendAttempt[runDir, key, <|\"rung\" -> n, \"what\" -> text, \"outcome\" -> text, \"time\" -> s|>] appends to the sector's attempts.m.";
PFBAppendNotes::usage = "PFBAppendNotes[runDir, key, text] appends a paragraph to the sector's notes.md.";
PFBRecordLiterature::usage = "PFBRecordLiterature[runDir, key, <|\"reference\" -> \"authors, title, journal, arXiv:xxxx.xxxxx or DOI\", \"used\" -> \"what was taken from it\", \"rung\" -> n, \"outcome\" -> text, \"result\" -> ...|>] records that a paper was used for the sector key (None for the whole run), so that its authors can be acknowledged (CoreRecordPaper: the same keys, checks and messages): the entry goes to the run's ledger citations.m, and CITATIONS.md is written again (PFBWriteCitations); the sector page, the summary and CHANGES.md show it. A paper behind a proposed change goes into the change instead (PFBTryChange, info \"Reference\"), which records its outcome. Returns the path of CITATIONS.md, or $Failed.";
PFBSliceCredits::usage = "PFBSliceCredits[conv] reads the optional \"Credits\" of conventions.wl (conv from PFBReadConventions): the tools (names of the registry $MCBTools or their display names, as CoreToolKey reads them; the registry's keys are returned) and the papers (<|\"reference\" -> ..., \"used\" -> ...|>, \"used\" optional) that produced the starting DE. Returns <|\"Tools\", \"Papers\"|>, or a String saying what is wrong (an entry that is neither, an unknown tool name: the known ones are listed).";
PFBRecordSliceCredits::usage = "PFBRecordSliceCredits[runDir, conv] records the \"Credits\" of conventions.wl (PFBSliceCredits) in the run's ledger, citations.m, for the whole run with step \"the starting DE\" (bin/import_slice.wls, once the slice is stored), and writes CITATIONS.md. Returns the entries, {} without \"Credits\", or $Failed (with a message, nothing recorded) when PFBSliceCredits refuses them.";
PFBFlagSector::usage = "PFBFlagSector[runDir, state, key, reason, tried, opts] marks a sector as flagged (rung 9) with what was tried and what is left, after the hidden-weight test (PFBHiddenWeightTest): when the test names a clean lower sector S and a factor w and S's lower-sector scan for w has not been recorded (PFBHiddenWeightTried) and S is not flagged, it refuses, says so, records the refusal in attempts.m and returns the state unchanged: open S first. opts: \"System\" (default: read from the run the state names, accepted changes applied; without a system the test cannot run and the flag is refused), \"Force\" -> True (flag whatever the test says; the test is still recorded when it can run). The flag keeps the test (\"HiddenWeight\"). PFBFlagSector[ctx, key, reason, tried, opts] takes the context of PFBStartRun. Returns the new state.";
PFBHiddenWeightTest::usage = "PFBHiddenWeightTest[sys, sl, census, key, attempts, opts] is the hidden-weight test before a sector is flagged: across the attempts recorded for it (their \"leftover\": the pole entries each left in the sector's rows, {row, column, factors}; PFBTryChange and PFBRecordScan store them), it asks whether a pole factor w that is left over always sits in columns of the subtree (PFBSubtreeMasters) of one clean sector S below it (at least one column a master of S, the lowest such S, S's masters coupled to the sector's rows, S able to change: PFBCanChangeQ). Without recorded leftovers it reads the sector's rows on the slice. opts \"Tried\" -> <|S -> {w, ...}|> (PFBHiddenWeightTried), \"Fixed\" (PFBFlaggedSectors: sectors it never names, nor those of a frozen family), \"Reopen\" (PFBReopenedSectors: a sector fixed by an accepted change is named with \"Reopens\" -> the change ids). Returns <|\"Found\", \"Sector\", \"Factor\" (of the first hit), \"Hits\" -> {<|\"Factor\", \"Sector\", \"Columns\", \"Attempts\", \"Tried\"|>..}, \"Source\" (\"attempts\" | \"slice\"), \"Attempts\" (how many were read), \"Message\"|>. PFBHiddenWeightTest[ctx, key] reads the current slice, its census and the sector's attempts from the run.";
PFBFixedSectors::usage = "PFBFixedSectors[state] lists the sectors flagged or fixed by an accepted change (those the gate never defers a pole to, its \"NoDefer\").";
PFBFlaggedSectors::usage = "PFBFlaggedSectors[state] lists the flagged sectors: the hidden-weight route never names them (the census's \"Fixed\").";
PFBReopenedSectors::usage = "PFBReopenedSectors[state] is <|sector -> {change id, ...}|> for the sectors fixed by an accepted change: the hidden-weight route names them as reopened (the census's \"Reopen\", a hint's \"Reopens\").";
PFBCensusOptions::usage = "PFBCensusOptions[runDir, state, sys] are the options of PFBCensus for a run: \"HiddenWeightTried\" (PFBHiddenWeightTried), \"Fixed\" (PFBFlaggedSectors) and \"Reopen\" (PFBReopenedSectors). PFBCensusOptions[ctx] takes the context of PFBStartRun.";
PFBHiddenWeightTried::usage = "PFBHiddenWeightTried[runDir, key] lists the factors w for which a lower-sector scan of the sector was recorded in its attempts.m (PFBHiddenWeightScan with \"RunDir\", bin/pair_scan.wls --hidden-weight), also one that could not run (no slots, too many sets, over budget: recorded with its reason); PFBHiddenWeightTried[runDir, sys] = <|key -> {w, ...}|> over every sector that has one (the census's opts \"HiddenWeightTried\").";
PFBRecordScan::usage = "PFBRecordScan[runDir, key, scan, info] records a scan in the sector's attempts.m (the scans themselves record nothing else): its best set and the pole entries that set leaves in the sector's rows (\"leftover\", which the hidden-weight test reads), and for a lower-sector scan (PFBHiddenWeightScan) \"hiddenWeight\" -> <|\"Factors\", \"Rows\", \"Before\", \"Left\", \"Clearing\", \"Sets\", \"Best\"|>. scan: the result of PFBScanSets or PFBHiddenWeightScan, or its list of results (best first). info: \"Rung\" (3), \"What\". Returns the attempt.";
PFBDeferredObligations::usage = "PFBDeferredObligations[state, key] lists the new poles that accepted changes of lower sectors deferred to this sector: <|\"Change\", \"Kind\" -> \"new\", \"Rows\", \"Sources\", \"Verified\"|> for poles of factors the change removed from its own rows, <|\"Change\", \"Kind\" -> \"moved\", \"Rows\", \"Factors\", \"Entries\"|> for moved poles (factors this sector's rows had before, carried into new columns). Its own fix must remove them too.";
PFBRungNumber::usage = "PFBRungNumber[record] is the rung of an accepted change in today's numbering ($PFBRungs). Records written before the change records stored \"RungName\" (2026-10-11) used older numberings and are translated by their date.";
PFBTryChange::usage = "PFBTryChange[ctx, key, newDefs, info, opts] runs a proposed change of the masters of a sector through the whole pipeline: calibration of the reduction against the current slice, change vectors, the image families (by the maps), exact application to the slice, checks at the extra points, the gate, the record, and (when accepted) the new current slice. ctx is the Association of PFBStartRun; newDefs = <|label -> root-free definition|> for base-family masters of the sector key (a master of another sector: not tried, since the gate and the extra points judge the rows of one sector); info: Rung, Provenance, Sources, Notes, ..., Reference (a paper, or a list of them: strings, or <|\"reference\", \"used\"|>; Used, else Provenance, says what was taken; each is recorded in the run's ledger, citations.m, for the change's sector with the change's id and result: accepted, pending, rejected, or not tried with the reason; an entry that is no reference is a message), Tools (tools or methods run by hand for the proposal, names of the registry $MCBTools or their display names, as CoreToolKey reads them: recorded for the change's sector, step \"declared\"; an unknown name leaves the change not tried), and MCBSectors (sector keys whose masters the change takes from the family's maximal-cut-basis run: move (i)'s normalisations). Once a change is recorded (accepted, pending or rejected), the credits of that maximal-cut-basis run (PFBMaxCutRunDir) go with it, stamped with its id, for the sectors it took from the run: a rung-8 change's sector, every sector the maximal-cut gate checked (it reads the run's points and classification), and MCBSectors; opts: Reds (list of reductions, the first at the slice point, the others never used by a fit: the extra points; one at the slice point or at a point already given is ignored and reported, PFBDistinctPoints), Images (True), Fitted (Automatic: True for rungs 2 to 7), MaxCutChanged (computed from the change: a new master with a component on another master of its sector; True forces it, False never switches it off), DeferPoles (True: new poles in rows above may pass when they factor through their own sector's masters), MaxEpsDegree (default the run's: the highest power of eps the change may leave in an entry, see PFBGate), MaxCutCheck (for a change that alters the maximal cut: Automatic runs the maximal-cut-basis gate, PFBMaxCutCheck, once the other checks pass, and skips it, recorded as not verified, on a machine without Kira; a verdict of PFBMaxCutCheck is recorded as it is, e.g. a finalist's from PFBReadMaxCutFinalists, only when it is Kira's on exactly this sector basis, the whole basis as it is now: any other verdict, or an Association without its fields, is not taken and the check runs again; \"NoKira\" skips it only when Kira is not available: with Kira the change is \"not tried\"), MaxCutCheckOptions (options of PFBMaxCutCheck when it runs; its \"Check\", a planted check, only in tests with AllowPlantedCheck -> True, otherwise the change is \"not tried\"). A check that cannot run (Kira failing, stopped at its time or memory limit) is no verdict: the change is \"not tried\", with the reason. The check \"maximal cut\" refuses a change whose maximal-cut DE fails the gate (the Euler relation, dependent elements, a number of elements that is not the cut's); eps-form is not required. The determinant of the new masters on the replaced ones is recorded (\"Determinant\"), not judged. The options ReferenceBasis and ReferenceSource were removed: passing them returns \"not tried\". The attempt it records keeps the pole entries the change leaves in the sector's rows (\"leftover\", for the hidden-weight test). Returns <|\"Status\", \"Gate\", \"Context\", \"Slice\", \"Record\"|>. With info \"Rung\" -> \"simplify\" (a move of the simplification phase, bin/simplify.wls) key may be None (masters of several sectors), newDefs give every changed master, images included, as combinations of ut[k] (no Reds needed) or of integrals (Reds at the slice point), the change is applied exactly on the slice and judged by PFBSimplifyGate with opts \"Degrees\" (the measured kinematic degrees before and after), and info \"Simplify\" is recorded. Such a move defers nothing; one that changes the maximal cut of a sector (a new master with a component on another master of its sector) gets the check \"maximal cut\" as above, sector by sector (\"maximal cut (fam/jPATTERN)\" for a move of several), with the same options (MaxCutCheck: one verdict for a move of one sector, or <|key -> verdict|>; MaxCutCheckOptions; AllowPlantedCheck).";
PFBTryRescale::usage = "PFBTryRescale[ctx, shifts, info] runs U_label -> eps^n U_label (rung 1, shifts from PFBRescaleSearch) through the gate and records it; info \"Reference\" and \"Tools\" are recorded as for PFBTryChange, for the sectors of the masters it rescales. Returns as PFBTryChange.";
PFBWriteCitations::usage = "PFBWriteCitations[runDir, sys, state] writes the run's CITATIONS.md (CoreWriteCitations) after crediting the maximal-cut-basis run of the families' starting masters for the sectors that keep one (PFBStartCredits): every write of CITATIONS.md of this skill goes through it (PFBTryChange, PFBApprove, PFBDecline, PFBRecordLiterature, PFBRecordSliceCredits, PFBMakeReports). PFBWriteCitations[runDir] reads the run's state.m and the system of its run.wl (accepted changes applied); without them it writes CITATIONS.md alone. Returns the path of CITATIONS.md, or Missing[\"NoCitations\"].";
PFBStartCredits::usage = "PFBStartCredits[runDir, sys, state] credits, for every sector of a family whose system.wl entry names a maximal-cut-basis run (\"MCBRun\": the run its starting masters came from), that run's tools and papers of the sector, when the sector's masters of the base family still include a starting master that no accepted change replaced (its \"Replace\", the keys of its \"NewDefs\"): PFBImportMaxCutCredits stamped with those starting labels, which the reader cites while one of them is left. PFBWriteCitations calls it before CITATIONS.md is written. Returns the entries appended.";
PFBExportMasters::usage = "PFBExportMasters[sys, state, runDir] writes export/<family>.m for every base family with an accepted change: the full master list in the family's order, changed entries commented. User files are never edited.";
PFBWriteChanges::usage = "PFBWriteChanges[sys, state, runDir, extra] writes CHANGES.md: every accepted change (old and new definitions, why, how it was found, maximal-cut changes and their eps-profile consequences, verification, and for a simplification its rescalings and its kinematic degrees before and after), the Markdown extra (default \"\": PFBMakeReports gives the kinematic degrees and the simplification phase), a section on what was not verified, and the credits: the tools, methods and papers to cite (CoreCiteMarkdown, the Cite part of CITATIONS.md).";

Begin["`Private`"];


(* ::Section:: *)
(*Run*)


$PFBRunDefaults = <|"System" -> "system.wl", "Slice" -> <|"Conventions" -> "conventions.wl"|>, "OutputDir" -> Automatic, "Name" -> Automatic,
   "Approval" -> False, "Target" -> "PoleFree", "MaxEpsDegree" -> 2, "ExtraPoints" -> 2, "Seeds" -> <|"Rank" -> 3, "Dots" -> 2|>,
   "MaxGB" -> None, "TimeLimit" -> 86400, "Threads" -> Automatic, "Paths" -> Automatic, "AllowTmp" -> False, "SimplifyBudget" -> Automatic, "TargetKinDegree" -> None|>;

absPath[p_String, base_] := If[StringStartsQ[p, "/"] || StringStartsQ[p, "~"], ExpandFileName[p], FileNameJoin[{base, p}]];
absPath[p_, _] := p;

PFBReadRun[file_String] := Module[{f = ExpandFileName[file], raw, base, run},
  raw = Get[f];
  If[! AssociationQ[raw], Print["PFBReadRun: ", f, " does not evaluate to an Association."]; Return[$Failed]];
  base = DirectoryName[f];
  run = Join[$PFBRunDefaults, raw, <|"File" -> f, "Dir" -> base|>];
  run["System"] = absPath[run["System"], base];
  If[AssociationQ[run["Slice"]], run["Slice"] = Association[KeyValueMap[#1 -> If[MemberQ[{"Conventions", "File"}, #1], absPath[#2, base], #2] &, run["Slice"]]]];
  If[StringQ[run["Paths"]], run["Paths"] = absPath[run["Paths"], base]];
  If[StringQ[run["OutputDir"]], run["OutputDir"] = absPath[run["OutputDir"], base]];
  If[run["Name"] === Automatic, run["Name"] = FileBaseName[run["System"]]];
  If[! (run["MaxEpsDegree"] === Infinity || (IntegerQ[run["MaxEpsDegree"]] && run["MaxEpsDegree"] >= 1)),
    Print["PFBReadRun: \"MaxEpsDegree\" must be an integer >= 1 or Infinity, not ", run["MaxEpsDegree"]]; Return[$Failed]];
  run];

PFBStartRun[runFile_String] := Module[{run = PFBReadRun[runFile], sys, dir, state, paths},
  If[run === $Failed, Return[$Failed]];
  (* the cap on the power of eps is the default of the gate, the scans, the rescale search and the completion solver *)
  PoleFreeBasis`$PFBMaxEpsDegree = run["MaxEpsDegree"];
  paths = Which[StringQ[run["Paths"]], run["Paths"], FileExistsQ[FileNameJoin[{run["Dir"], "paths.wl"}]], FileNameJoin[{run["Dir"], "paths.wl"}], True, Automatic];
  MCBLoadPaths[paths];
  sys = PFBReadSystem[run["System"]];
  If[sys === $Failed, Return[$Failed]];
  dir = PFBRunDir[run];
  If[dir === $Failed, Return[$Failed]];
  (* SOFIA's polynomials become letters of the families whose entry says "LettersFromSOFIA" -> True (the user's yes) *)
  sys = PFBAttachSOFIALetters[sys, dir];
  KeyValueMap[Print["PFBStartRun: \"LettersFromSOFIA\" is set for ", #1, ", but its SOFIA cache is ", #2, ": run bin/singularities.wls (no SOFIA letters until then)"] &,
    sys["SOFIALettersMissing"]];
  state = PFBLoadState[dir];
  If[state === None,
    state = <|"Run" -> run["File"], "Created" -> PFBTimeStamp[], "Slices" -> {}, "Current" -> None, "Censuses" -> {}, "Accepted" -> {}, "Pending" -> {},
      "Rejected" -> {}, "Flagged" -> <||>, "Approval" -> TrueQ[run["Approval"]], "Regenerated" -> False|>;
    PFBSaveState[dir, state]];
  state["Approval"] = TrueQ[run["Approval"]];
  Put[<|"Run" -> run, "Resources" -> PFBResources[], "MemoryModel" -> PFBMemoryModel[], "Tools" -> $MCBPaths, "Date" -> PFBTimeStamp[]|>, FileNameJoin[{dir, "run_info.m"}]];
  (* a tool used in this kernel is credited to the whole run (the run's ledger, citations.m) until a sector's context is
     set (the scans, PFBTryChange, AnalysisPoles.m) *)
  CoreCitationContext[dir, "whole run", If[$ScriptCommandLine === {}, "session", FileBaseName[First[$ScriptCommandLine]]]];
  <|"Run" -> run, "System" -> PFBApplyAccepted[sys, state], "Dir" -> dir, "State" -> state|>];

PFBLoadState[dir_String] := With[{f = FileNameJoin[{dir, "state.m"}]}, If[FileExistsQ[f], Get[f], None]];
PFBSaveState[dir_String, st_Association] := (Put[st, FileNameJoin[{dir, "state.m"}]]; st);

PFBCurrentSlice[dir_String, st_Association] := If[StringQ[st["Current"]], PFBLoadSlice[FileNameJoin[{dir, st["Current"]}]], $Failed];

PFBStoreSlice[dir_String, st0_Association, sl_Association, census_Association, label_String] := Module[{st = st0, n, sf, cf},
  n = Length[st["Slices"]];
  If[! DirectoryQ[FileNameJoin[{dir, "slices"}]], CreateDirectory[FileNameJoin[{dir, "slices"}]]];
  sf = FileNameJoin[{"slices", "slice_" <> IntegerString[n, 10, 3] <> ".mx"}];
  cf = FileNameJoin[{"slices", "census_" <> IntegerString[n, 10, 3] <> ".m"}];
  PFBSaveSlice[sl, FileNameJoin[{dir, sf}]];
  Put[census, FileNameJoin[{dir, cf}]];
  st["Slices"] = Append[st["Slices"], <|"File" -> sf, "Census" -> cf, "Label" -> label, "Date" -> PFBTimeStamp[],
     "BadEntries" -> Length[census["BadEntries"]], "BadRows" -> Length[census["BadRows"]], "EpsZero" -> Length[census["EpsZero"]],
     "MaxDegree" -> Lookup[census, "MaxDegree", Missing[]], "HighDegree" -> Length[Lookup[census, "HighDegree", {}]], "DegreeCap" -> Lookup[census, "DegreeCap", Missing[]]|>];
  st["Current"] = sf; st["Censuses"] = Append[st["Censuses"], cf];
  PFBSaveState[dir, st]];


(* ::Section:: *)
(*Changes*)


fullDefs[sys_, ch_] := Association[KeyValueMap[#1 -> (PFBMaster[sys, #1]["Mono"] #2) &, ch["NewDefs"]]];

PFBApplyAccepted[sys_Association, st_Association] := Fold[PFBReplaceMasters[#1, #2["NewDefs"]] &, sys, st["Accepted"]];

PFBChangeKeys[sys_Association, rec_Association] := Which[
  ListQ[Lookup[rec, "Key", None]], {rec["Key"]},
  Lookup[rec, "Rung", None] === "simplify", Union[Cases[PFBMaster[sys, #]["SectorKey"] & /@ Select[Lookup[rec, "Replace", {}], IntegerQ], _List]],
  True, {}];

PFBRecordChange[dir_String, st0_Association, sys_Association, ch_Association, gate_Association, info_Association] := Module[{st = st0, rec, id, status},
  id = Length[st["Accepted"]] + Length[st["Pending"]] + Length[st["Rejected"]] + 1;
  rec = <|"Id" -> id, "Key" -> Lookup[ch, "Key", None], "Name" -> Lookup[ch, "Name", "change " <> ToString[id]], "Kind" -> Lookup[ch, "Kind", "change"],
    "Replace" -> Lookup[ch, "Replace", {}], "Shifts" -> Lookup[ch, "Shifts", <||>],
    "NewDefs" -> If[KeyExistsQ[ch, "NewDefs"], fullDefs[sys, ch], <||>],
    "OldDefs" -> Association[Table[l -> PFBMaster[sys, l]["Def"], {l, Lookup[ch, "Replace", {}]}]],
    "Rung" -> Lookup[info, "Rung", Missing[]], "RungName" -> If[StringQ[Lookup[info, "Rung", None]], info["Rung"], Lookup[Lookup[$PFBRungs, Lookup[info, "Rung", None], <||>], "name", Missing[]]],
    "Provenance" -> Lookup[info, "Provenance", ""], "Sources" -> Lookup[info, "Sources", Missing[]],
    "Residues" -> Lookup[info, "Residues", Missing[]], "Completion" -> Lookup[info, "Completion", Missing[]],
    "MaxCutChanged" -> TrueQ[Lookup[info, "MaxCutChanged", False]], "Determinant" -> Lookup[ch, "DetT", Missing[]],
    "ProfileBefore" -> Lookup[info, "ProfileBefore", Missing[]], "ProfileAfter" -> Lookup[info, "ProfileAfter", Missing[]],
    "Fitted" -> TrueQ[Lookup[ch, "Fitted", False]], "PointsVerified" -> Lookup[ch, "PointsVerified", 0],
    "ImagesVerified" -> Lookup[info, "ImagesVerified", Missing["NotChecked"]], "Verification" -> Lookup[info, "Verification", Missing[]],
    (* the maximal-cut-basis gate on the new basis, for a change that alters the maximal cut (PFBMaxCutSummary) *)
    "MaxCutCheck" -> Lookup[info, "MaxCutCheck", Missing["NotNeeded"]],
    "Gate" -> gate["Checks"], "Notes" -> Lookup[info, "Notes", ""], "Simplify" -> Lookup[info, "Simplify", Missing[]], "Date" -> PFBTimeStamp[]|>;
  status = Which[! TrueQ[gate["Pass"]], "rejected", TrueQ[st["Approval"]], "pending", True, "accepted"];
  Switch[status,
    "rejected", st["Rejected"] = Append[st["Rejected"], rec],
    "pending", st["Pending"] = Append[st["Pending"], rec],
    "accepted", st["Accepted"] = Append[st["Accepted"], rec]];
  PFBSaveState[dir, st];
  (* a change without a sector (a simplification of several sectors) is logged in every sector whose masters it changes,
     with the pole entries it leaves in that sector's rows: the hidden-weight test reads them before a flag *)
  Scan[PFBAppendAttempt[dir, #, <|"rung" -> rec["Rung"], "what" -> rec["Name"] <> ": " <> rec["Provenance"],
      "outcome" -> status <> If[status === "rejected", " (" <> StringRiffle[Select[gate["Checks"], ! #["Pass"] &][[All, "Name"]], ", "] <> ")", ""],
      "leftover" -> leftoverOf[Lookup[Lookup[gate, "Census", <||>], "BadEntries", {}], PFBSectorMasters[sys, #]]|>] &,
    PFBChangeKeys[sys, rec]];
  <|"State" -> st, "System" -> If[status === "accepted", PFBReplaceMasters[sys, rec["NewDefs"]], sys], "Status" -> status, "Record" -> rec|>];

PFBApprove[dir_String, st0_Association, sys_Association, id_Integer] := Module[{st = st0, rec},
  rec = SelectFirst[st["Pending"], #["Id"] == id &, None];
  If[rec === None, Print["PFBApprove: no pending change ", id]; Return[<|"State" -> st, "System" -> sys|>]];
  If[StringQ[Lookup[rec, "BaseSlice", None]] && rec["BaseSlice"] =!= st["Current"],
    Print["PFBApprove: change ", id, " was proposed on ", rec["BaseSlice"], ", but the current slice is now ", st["Current"],
      " (another change was accepted since). Its slice would undo that change: propose it again on the current slice."];
    Return[<|"State" -> st, "System" -> sys|>]];
  st["Pending"] = DeleteCases[st["Pending"], _?(#["Id"] == id &)];
  st["Accepted"] = Append[st["Accepted"], Join[rec, <|"Approved" -> PFBTimeStamp[]|>]];
  PFBSaveState[dir, st];
  (* the papers of the change are now cited (the ledger reads the latest outcome of a change) *)
  CoreRecordOutcome[dir, id, "accepted", "approved by the user"]; PFBWriteCitations[dir, sys, st];
  (* the slice proposed with the change becomes the current one *)
  If[StringQ[Lookup[rec, "SliceFile", None]],
    st = PFBStoreSlice[dir, st, PFBLoadSlice[FileNameJoin[{dir, rec["SliceFile"]}]], Get[FileNameJoin[{dir, rec["CensusFile"]}]], rec["Name"] <> " (approved)"];
    (* the pending files are now a copy of the stored slice and census *)
    Quiet[DeleteFile[FileNameJoin[{dir, #}]] & /@ {rec["SliceFile"], rec["CensusFile"]}]];
  <|"State" -> st, "System" -> PFBReplaceMasters[sys, rec["NewDefs"]]|>];

(* census entries {k, row, column, factors} of the given rows, as {row, column, factors} over every derivative *)
leftoverOf[bad_List, rows_List] := KeyValueMap[Join[#1, {Union @@ #2}] &, GroupBy[Select[bad, MemberQ[rows, #[[2]]] &], (#[[2 ;; 3]] &) -> (#[[4]] &)]];

(* Before a sector is flagged: a pole factor that every attempt left in columns of one clean lower sector's subtree is
   the pattern of a hidden weight of that sector (method.md, "A hidden weight on a clean lower sector"): the fix that
   removes the cause belongs there (a fix here would need corrections that carry 1/w and leave the weight in the basis) *)
PFBHiddenWeightTest[sys_Association, sl_Association, census_Association, key_List, attempts_List, opts_Association : <||>] := Module[{secs = census["Sectors"],
    rowsT, lefts, src = "attempts", facs, hits = {}, order = PFBSectorKeys[sys], sub, tried = Lookup[opts, "Tried", <||>], msg, fixed = Lookup[opts, "Fixed", {}], reopen = Lookup[opts, "Reopen", <||>]},
  rowsT = Intersection[PFBSectorMasters[sys, key], sl["Labels"]];
  lefts = Select[Lookup[#, "leftover", {}] & /@ attempts, MatchQ[#, {{_, _, _List} ..}] &];
  If[lefts === {}, src = "slice"; lefts = DeleteCases[{leftoverOf[census["BadEntries"], rowsT]}, {}]];
  facs = Union[Flatten[lefts[[All, All, 3]]]];
  sub[k_] := sub[k] = PFBSubtreeMasters[sys, sl, k];
  Do[Module[{colsets = DeleteCases[Function[l, Union[Cases[l, {_, c_, fs_} /; MemberQ[fs, w] :> c]]] /@ lefts, {}], all, cands, S},
     all = Union @@ colsets;
     (* a sector that cannot change (frozen family, flagged) is never named; one fixed by an accepted change is, as reopened *)
     cands = Select[order, # =!= key && KeyExistsQ[secs, #] && Lookup[secs[#], "Issues", If[secs[#]["BadRows"] === {}, {}, {"finite poles"}]] === {} &&
        IntersectingQ[all, secs[#]["Rows"]] && PFBCanChangeQ[sys, #, fixed] &];
     S = SelectFirst[cands, Function[k, SubsetQ[sub[k], all] && ! IntersectingQ[sub[k], rowsT] &&
        IntersectingQ[PFBRowsCouplingTo[sl, Intersection[secs[k]["Rows"], sl["Labels"]]], rowsT]], None];
     If[S =!= None, AppendTo[hits, Join[<|"Factor" -> w, "Sector" -> S, "Columns" -> all, "Attempts" -> Length[colsets], "Tried" -> MemberQ[Lookup[tried, Key[S], {}], w]|>,
       If[KeyExistsQ[reopen, S], <|"Reopens" -> reopen[S]|>, <||>]]]]],
    {w, facs}];
  msg = If[hits === {},
    If[lefts === {}, "no pole left over in the sector's rows to read", "no pole factor left over sits only in the columns of one clean lower sector's subtree (" <>
      ToString[Length[lefts]] <> If[src === "slice", " reading of the slice)", " attempts with their leftover poles)"]],
    StringRiffle[(If[src === "slice", "on the slice", "across " <> ToString[#["Attempts"]] <> If[#["Attempts"] == 1, " attempt", " attempts"]] <> ", " <>
       ToString[#["Factor"], InputForm] <> " is always left in the columns " <> ToString[ut /@ #["Columns"]] <> ", all in the subtree of the clean sector " <>
       PFBSectorString[#["Sector"]] <> ": a possible hidden weight of that sector" <> PFBReopenText[Lookup[#, "Reopens", None]] <>
       If[TrueQ[#["Tried"]], " (its lower-sector scan was recorded)", ": open it before flagging this one (the lower-sector scan, bin/pair_scan.wls run.wl <job> " <>
         PFBSectorString[#["Sector"]] <> " --hidden-weight)"]) & /@ hits, "; "]];
  <|"Found" -> hits =!= {}, "Sector" -> If[hits === {}, None, First[hits]["Sector"]], "Factor" -> If[hits === {}, None, First[hits]["Factor"]], "Hits" -> hits,
    "Source" -> src, "Attempts" -> If[src === "slice", 0, Length[lefts]], "Message" -> msg|>];

PFBHiddenWeightTest[ctx_Association, key_List, opts_Association : <||>] := hiddenWeightTestRun[ctx["Dir"], ctx["State"], ctx["System"], key, opts];

(* the census stored with the current slice (the last one stored), computed again only when it cannot be read *)
hiddenWeightTestRun[dir_, st_, sys_, key_, opts_ : <||>] := Module[{sl = PFBCurrentSlice[dir, st], census},
  If[! AssociationQ[sl], Return[Missing["NoSlice"]]];
  census = If[Lookup[st, "Slices", {}] =!= {} && Last[st["Slices"]]["File"] === st["Current"], Quiet[Get[FileNameJoin[{dir, Last[st["Slices"]]["Census"]}]]], $Failed];
  If[! AssociationQ[census] || ! KeyExistsQ[census, "Sectors"], census = Block[{Print}, PFBCensus[sys, sl]]];
  PFBHiddenWeightTest[sys, sl, census, key, MCBReadAttempts[PFBSectorDir[dir, key]], Join[<|"Tried" -> PFBHiddenWeightTried[dir, sys], "Fixed" -> PFBFlaggedSectors[st],
     "Reopen" -> PFBReopenedSectors[st]|>, opts]]];

PFBFixedSectors[st_Association] := Union[Keys[Lookup[st, "Flagged", <||>]], DeleteCases[Lookup[#, "Key", None] & /@ Lookup[st, "Accepted", {}], None]];
PFBFlaggedSectors[st_Association] := Keys[Lookup[st, "Flagged", <||>]];
PFBReopenedSectors[st_Association] := Module[{acc = Select[Lookup[st, "Accepted", {}], ListQ[Lookup[#, "Key", None]] &]},
  Association[KeyValueMap[#1 -> DeleteCases[Lookup[#2, "Id", None], None] &, GroupBy[acc, #["Key"] &]]]];
PFBCensusOptions[dir_String, st_Association, sys_Association] := <|"HiddenWeightTried" -> PFBHiddenWeightTried[dir, sys], "Fixed" -> PFBFlaggedSectors[st],
   "Reopen" -> PFBReopenedSectors[st]|>;
PFBCensusOptions[ctx_Association] := PFBCensusOptions[ctx["Dir"], ctx["State"], ctx["System"]];

PFBHiddenWeightTried[dir_String, key_List] := Union[Flatten[Cases[MCBReadAttempts[PFBSectorDir[dir, key]], a_ /; AssociationQ[Lookup[a, "hiddenWeight", None]] :>
   Lookup[a["hiddenWeight"], "Factors", {}]]]];
PFBHiddenWeightTried[dir_String, sys_Association] := Association[Select[Table[k -> PFBHiddenWeightTried[dir, k], {k, PFBSectorKeys[sys]}], Last[#] =!= {} &]];

PFBRecordScan[dir_String, key_List, scan_, info_Association : <||>] := Module[{res = If[AssociationQ[scan], Lookup[scan, "Results", {}], scan], best, a, hw, show, ran},
  best = If[res === {}, None, First[res]];
  show[r_] := StringRiffle[KeyValueMap["ut[" <> ToString[#1] <> "] -> " <> ToString[#2, InputForm] &, r["set"]], ", "];
  hw = AssociationQ[scan] && KeyExistsQ[scan, "Factors"];
  (* a lower-sector scan that could not run (no slots, too many sets, over budget) is recorded with its reason *)
  ran = ! AssociationQ[scan] || MemberQ[{"done", Missing[]}, Lookup[scan, "Status", Missing[]]];
  a = <|"rung" -> Lookup[info, "Rung", 3], "what" -> Lookup[info, "What", "scan"] <> If[AssociationQ[scan] && IntegerQ[Lookup[scan, "Sets", None]], ", " <> ToString[scan["Sets"]] <> " sets", ""],
    "outcome" -> Which[! ran, "not run (" <> scan["Status"] <> "): " <> Lookup[scan, "Message", ""],
      best === None, "no set",
      hw, "best: " <> show[best] <> " (" <> ToString[best["above"]] <> " of " <> ToString[scan["AboveBefore"]] <> " entries with " <> ToString[scan["Factors"], InputForm] <> " left in the rows above; " <>
        ToString[scan["Clearing"]] <> " sets clear them)",
      True, "best: " <> show[best] <> " (" <> ToString[best["bad"]] <> " pole entries left in the sector's rows" <> If[best["factors"] === {}, "", ", " <> ToString[best["factors"], InputForm]] <> ")"],
    "leftover" -> If[best === None, {}, Lookup[best, "left", {}]]|>;
  If[hw, a["hiddenWeight"] = If[ran,
    <|"Factors" -> scan["Factors"], "Rows" -> scan["Rows"], "Before" -> scan["AboveBefore"], "Left" -> If[best === None, Missing[], best["above"]],
      "Clearing" -> scan["Clearing"], "Sets" -> Lookup[scan, "Sets", Missing[]], "Best" -> If[best === None, Missing[], show[best]], "Status" -> "done"|>,
    <|"Factors" -> scan["Factors"], "Rows" -> Lookup[scan, "Rows", Missing[]], "Status" -> scan["Status"], "Reason" -> Lookup[scan, "Message", ""]|>]];
  PFBAppendAttempt[dir, key, a];
  a];

PFBDecline[dir_String, st0_Association, sys_Association, id_Integer, reason_String : "declined by the user"] := Module[{st = st0, rec},
  rec = SelectFirst[st["Pending"], #["Id"] == id &, None];
  If[rec === None, Print["PFBDecline: no pending change ", id]; Return[<|"State" -> st, "Record" -> None|>]];
  st["Pending"] = DeleteCases[st["Pending"], _?(#["Id"] == id &)];
  rec = Join[rec, <|"Declined" -> PFBTimeStamp[], "DeclineReason" -> reason|>];
  st["Rejected"] = Append[st["Rejected"], rec];
  PFBSaveState[dir, st];
  CoreRecordOutcome[dir, id, "declined", reason]; PFBWriteCitations[dir, sys, st];
  (* the slice and census proposed with it are not used *)
  Quiet[DeleteFile[FileNameJoin[{dir, #}]] & /@ Select[{Lookup[rec, "SliceFile", None], Lookup[rec, "CensusFile", None]}, StringQ]];
  Scan[PFBAppendAttempt[dir, #, <|"rung" -> Lookup[rec, "Rung", "-"], "what" -> rec["Name"], "outcome" -> "declined by the user (" <> reason <> ")"|>] &, PFBChangeKeys[sys, rec]];
  <|"State" -> st, "Record" -> rec|>];

runSystem[st_] := If[StringQ[Lookup[st, "Run", None]] && FileExistsQ[st["Run"]], Module[{run = Quiet[PFBReadRun[st["Run"]]], s},
  If[! AssociationQ[run], Return[Missing["NoSystem"], Module]];
  s = Block[{Print}, Quiet[PFBReadSystem[run["System"]]]];
  If[AssociationQ[s], PFBApplyAccepted[s, st], Missing["NoSystem"]]], Missing["NoSystem"]];

PFBFlagSector[ctx_Association, key_List, reason_String, tried_List, opts_Association : <||>] :=
  PFBFlagSector[ctx["Dir"], ctx["State"], key, reason, tried, Join[<|"System" -> ctx["System"]|>, opts]];

PFBFlagSector[dir_String, st0_Association, key_List, reason_String, tried_List, opts_Association : <||>] := Module[{st = st0, sys, test, open, force = TrueQ[Lookup[opts, "Force", False]], why},
  sys = Replace[Lookup[opts, "System", Automatic], Automatic :> runSystem[st]];
  test = If[AssociationQ[sys], hiddenWeightTestRun[dir, st, sys, key], Missing["NoSystem"]];
  If[! force,
    why = Which[
      ! AssociationQ[test], "the hidden-weight test could not run (" <> If[MissingQ[sys], "no system: pass <|\"System\" -> ctx[\"System\"]|>", "no current slice"] <>
        "); give \"Force\" -> True to flag without it",
      (open = Select[test["Hits"], ! TrueQ[#["Tried"]] && ! KeyExistsQ[st["Flagged"], #["Sector"]] &]) =!= {}, test["Message"],
      True, None];
    If[StringQ[why],
      Print["PFBFlagSector: ", PFBSectorString[key], " is not flagged: ", why];
      PFBAppendAttempt[dir, key, <|"rung" -> 9, "what" -> "flag refused (the hidden-weight test)", "outcome" -> why|>];
      Return[st]]];
  st["Flagged"][key] = <|"Reason" -> reason, "Tried" -> tried, "Date" -> PFBTimeStamp[],
    "HiddenWeight" -> If[AssociationQ[test], KeyTake[test, {"Found", "Hits", "Source", "Attempts", "Message"}], test], "Forced" -> force|>;
  PFBAppendAttempt[dir, key, <|"rung" -> 9, "what" -> "flag", "outcome" -> reason <> If[AssociationQ[test], "; hidden-weight test: " <> test["Message"], ""]|>];
  PFBSaveState[dir, st]];


(* ::Section:: *)
(*The whole pipeline of one change*)


currentCensus[dir_, st_] := Get[FileNameJoin[{dir, Last[st["Slices"]]["Census"]}]];

finish[ctx_, key_, sl_, slNew_, ch_, gate_, info_] := Module[{dir = ctx["Dir"], st = ctx["State"], sys = ctx["System"], r, rows, prof, st2},
  rows = If[key === None, Union[Keys[Lookup[ch, "Shifts", <||>]], Lookup[ch, "Replace", {}]], Intersection[PFBSectorMasters[sys, key], sl["Labels"]]];
  prof = <|"ProfileBefore" -> PFBBlockProfile[sl, rows, sl["Labels"]], "ProfileAfter" -> PFBBlockProfile[slNew, rows, slNew["Labels"]]|>;
  r = PFBRecordChange[dir, st, sys, ch, gate, Join[info, prof]];
  st2 = r["State"];
  Switch[r["Status"],
    "accepted", st2 = PFBStoreSlice[dir, st2, slNew, gate["Census"], ch["Name"]],
    "pending", Module[{f = FileNameJoin[{"slices", "pending_" <> ToString[r["Record"]["Id"]] <> ".mx"}], cf = FileNameJoin[{"slices", "pending_" <> ToString[r["Record"]["Id"]] <> "_census.m"}]},
       If[! DirectoryQ[FileNameJoin[{dir, "slices"}]], CreateDirectory[FileNameJoin[{dir, "slices"}]]];
       PFBSaveSlice[slNew, FileNameJoin[{dir, f}]]; Put[gate["Census"], FileNameJoin[{dir, cf}]];
       (* BaseSlice: the slice the change was applied to; it can only be approved while that slice is current *)
       st2["Pending"] = Append[Most[st2["Pending"]], Join[Last[st2["Pending"]], <|"SliceFile" -> f, "CensusFile" -> cf, "BaseSlice" -> st["Current"]|>]];
       PFBSaveState[dir, st2]]];
  PFBPrint["change ", ch["Name"], ": ", r["Status"], "\n", gate["Message"]];
  <|"Status" -> r["Status"], "Gate" -> gate, "Context" -> Join[ctx, <|"State" -> st2, "System" -> r["System"]|>], "Slice" -> If[r["Status"] === "accepted", slNew, sl],
    "Proposed" -> slNew, "Record" -> r["Record"]|>];

PFBDeferredObligations[st_Association, key_List] := Flatten[Table[
   With[{rc = SelectFirst[Lookup[a, "Gate", {}], #["Name"] === "rows" &, <||>]}, With[{d = Lookup[rc, "Deferred", <||>], m = Lookup[rc, "Moved", <||>]},
    {If[KeyExistsQ[d, key], <|"Change" -> a["Id"], "Kind" -> "new", "Rows" -> d[key]["Rows"], "Sources" -> d[key]["Sources"], "Verified" -> Lookup[d[key], "Verified", True]|>, Nothing],
     (* moved poles: a factor this sector's rows had, carried into new columns by the lower change *)
     If[KeyExistsQ[m, key], <|"Change" -> a["Id"], "Kind" -> "moved", "Rows" -> m[key]["Rows"], "Factors" -> m[key]["Factors"], "Entries" -> m[key]["Entries"]|>, Nothing]}]],
   {a, Lookup[st, "Accepted", {}]}]];

(* records without "RungName" were written before the pair scan became rung 3 (their rungs 3 to 8 are today's 4 to 9),
   and those dated before 2026-10-10 13:49 also before the dot move became rung 2 (their rungs 2 to 7 are today's 4 to 9) *)
PFBRungNumber[a_Association] := With[{n = Lookup[a, "Rung", Missing[]], d = Lookup[a, "Date", None]}, Which[
   ! IntegerQ[n] || ! MissingQ[Lookup[a, "RungName", Missing[]]], n,
   StringQ[d] && FromDigits[StringReplace[d, Except[DigitCharacter] -> ""]] < 202610101349 && n >= 2, n + 2,
   n >= 3, n + 1,
   True, n]];
rungName[a_] := Replace[Lookup[a, "RungName", Missing[]], _Missing :> Lookup[$PFBRungs, PFBRungNumber[a], <|"name" -> "?"|>]["name"]];

(* inside a code span of CHANGES.md: the determinant on a reference basis, for a change recorded while the gate judged
   the determinant on one (records of 2026-10-10 to 2026-10-16) *)
refDetNote[a_, tex_] := If[MissingQ[Lookup[a, "DetOnReference", Missing[]]], "",
  "` on the old basis; on the reference basis (" <> ToString[a["ReferenceSource"]] <> "): `" <> tex[a["DetOnReference"]]];

(* the reference-basis route of the determinant check (2026-10-10 to 2026-10-16) is gone, and with it the check: the
   gate records the determinant of a change and does not judge it *)
$referenceRemoved = "removed: the options ReferenceBasis and ReferenceSource no longer exist, and the gate does not judge the determinant of a change: propose the change without them";

$noKiraRefused = "\"MaxCutCheck\" -> \"NoKira\" is only for a machine without Kira, and Kira is available here: the change alters the maximal cut, so give no \"MaxCutCheck\" (PFBTryChange runs the maximal-cut-basis gate) or the verdict of PFBMaxCutCheck for these definitions";
$plantedRefused = "a planted maximal-cut check (\"MaxCutCheckOptions\" -> <|\"Check\" -> f|>, a verdict with \"Tool\" -> \"planted\") is for tests only (\"AllowPlantedCheck\" -> True): give no \"Check\", and PFBTryChange runs the maximal-cut-basis gate with Kira";

(* A verdict given with the change ("MaxCutCheck" -> PFBMaxCutCheck's result, e.g. a finalist's) is recorded as it is only
   when it is the maximal-cut gate's on exactly this sector basis: the whole basis (PFBMaxCutBasis: the new definitions and
   the sector's other masters as they are now), from Kira (MCBCheckBasis), or from a planted check under the tests'
   "AllowPlantedCheck" -> True. Anything else is not taken: why, or None *)
givenVerdictProblem[sys_, key_, base_, v_, opts_] := Which[
  ! AssociationQ[v], "not a verdict of PFBMaxCutCheck",
  ! SubsetQ[Keys[v], {"Status", "Check", "Refuses", "Basis", "Labels", "Tool"}], "it lacks the fields of a verdict of PFBMaxCutCheck (Status, Check, Refuses, Basis, Labels, Tool)",
  ! (v["Tool"] === "Kira (MCBCheckBasis)" || (v["Tool"] === "planted" && TrueQ[Lookup[opts, "AllowPlantedCheck", False]])),
    "its tool is " <> ToString[v["Tool"], InputForm] <> ", not the maximal-cut gate's (Kira, MCBCheckBasis)",
  StringQ[Lookup[v, "ToolFailure", None]], "it is no verdict: " <> v["ToolFailure"],
  v["Labels"] =!= PFBMaxCutBasis[sys, key] || ! MCBSameBasisQ[v["Basis"], PFBMaxCutBasis[sys, key, base]], "it is for another basis of the sector",
  True, None];

(* the verdict of the maximal-cut-basis gate on the new sector basis (its base family), a reason it was not checked, or a
   String: the change is not tried (a planted check outside the tests, "NoKira" with Kira there, or a check that could not
   run: Kira failing or stopped at a limit is no verdict on the basis). What the gate runs through the maximal-cut-basis
   toolkit (Kira, the representations) is credited to the sector, with step *)
maxCutVerdict[ctx_, key_, defs0_, gate_, opts_, step_String] := CoreWithCitationContext[{ctx["Dir"], PFBSectorString[key], step}, maxCutVerdictRun[ctx, key, defs0, gate, opts]];
maxCutStep[info_] := With[{r = Lookup[info, "Rung", None]}, Which[r === "simplify", "maximal-cut gate of a simplification move",
   IntegerQ[r], "maximal-cut gate of a rung-" <> ToString[r] <> " change", True, "maximal-cut gate of a change"]];

maxCutVerdictRun[ctx_, key_, defs0_, gate_, opts_] := Module[{sys = ctx["System"], given = Lookup[opts, "MaxCutCheck", Automatic], base, why = None, mo = Lookup[opts, "MaxCutCheckOptions", <||>], v},
  base = KeySelect[defs0, PFBMaster[sys, #]["Family"] === key[[1]] &];
  If[KeyExistsQ[mo, "Check"] && ! TrueQ[Lookup[opts, "AllowPlantedCheck", False]], Return[$plantedRefused]];
  If[given === "NoKira",
    Return[If[MCBKiraAvailableQ[], $noKiraRefused,
      <|"Skipped" -> "Kira is not available (\"MaxCutCheck\" -> \"NoKira\"): the maximal-cut DE of the new basis is not verified"|>]]];
  If[given =!= Automatic, why = givenVerdictProblem[sys, key, base, given, opts]; If[why === None, Return[given]]];
  v = Which[
    ! TrueQ[gate["Pass"]], <|"NotRun" -> "the gate refused the change on " <> StringRiffle[Select[gate["Checks"], ! #["Pass"] &][[All, "Name"]], ", "]|>,
    (* no Kira on this machine: the check is skipped, and the change listed as not verified *)
    ! KeyExistsQ[mo, "Check"] && ! MCBKiraAvailableQ[], <|"Skipped" -> "Kira is not available on this machine: the maximal-cut DE of the new basis is not verified"|>,
    True, PFBMaxCutCheck[sys, key, base, Join[<|"MCBRun" -> PFBMaxCutRun[sys, ctx["Dir"], key[[1]]]["Dir"]|>, mo]]];
  If[StringQ[Lookup[v, "ToolFailure", None]], Return[v["ToolFailure"] <> ": no verdict on the basis, so the change is not recorded; propose it again once Kira runs " <>
     "(its time and memory limits: reference/limits.md of maximal-cut-basis)"]];
  If[StringQ[why], v["Given"] = "the verdict given was not used (" <> why <> "): checked again"];
  v];

(* a simplification move (rung "simplify", bin/simplify.wls) may change the masters of several sectors at once: key None *)
PFBTryChange[ctx_Association, None, newDefs0_Association, info_Association, opts_Association : <||>] := withCredits[ctx, None, newDefs0, info,
  If[Lookup[info, "Rung", None] === "simplify", trySimplify[ctx, None, newDefs0, info, opts],
    <|"Status" -> "not tried", "Message" -> "a change without a sector key is a simplification move: give \"Rung\" -> \"simplify\"", "Context" -> ctx|>]];

PFBTryChange[ctx_Association, key_List, newDefs0_Association, info_Association, opts_Association] := withCredits[ctx, key, newDefs0, info, tryChange[ctx, key, newDefs0, info, opts]];

(* Whatever becomes of a proposed change, its credits go to the run's ledger (citations.m): the tools declared in info
   "Tools" (validated first: an unknown name leaves the change not tried), and the papers of info "Reference", for the
   change's sector, with its id and result (accepted, pending, rejected), or "not tried" with the reason *)
PFBTryChange::tools = "info \"Tools\" names what is not in the registry of tools and methods ($MCBTools): `1`. The known names are `2`. The change is not tried.";
PFBTryChange::reference = "An entry of info \"Reference\" is not a reference: `1`. Give the full reference as a string (authors, title, arXiv number or DOI), or <|\"reference\" -> ..., \"used\" -> ...|>; it is not recorded.";
PFBTryChange::paper = "The paper `1` of the change was not recorded (see the message above).";

declaredTools[info_] := DeleteCases[Flatten[{Lookup[info, "Tools", {}]}], None];
badTools[info_] := Select[declaredTools[info], CoreToolKey[#] === $Failed &];

SetAttributes[withCredits, HoldAll];
withCredits[ctx_, key_, defs_, info_, expr_] := Module[{bad = badTools[info], r},
  r = If[bad =!= {},
    Message[PFBTryChange::tools, StringRiffle[ToString[#, InputForm] & /@ bad, ", "], StringRiffle[Keys[$MCBTools], ", "]];
    <|"Status" -> "not tried", "Message" -> "info \"Tools\" names what is not in the registry of tools and methods ($MCBTools): " <>
      StringRiffle[ToString[#, InputForm] & /@ bad, ", "], "Context" -> ctx|>,
    expr];
  recordCredits[ctx, key, defs, info, r, bad === {}];
  r];

(* the papers of info "Reference": strings, or <|"reference", "used"|> (its own "used", else the change's) *)
paperList[refs_, used_String] := Module[{out = {}},
  Do[Which[
     StringQ[x] && StringTrim[x] =!= "", AppendTo[out, <|"reference" -> x, "used" -> used|>],
     AssociationQ[x] && StringQ[Lookup[x, "reference", None]] && StringTrim[x["reference"]] =!= "",
       AppendTo[out, <|"reference" -> x["reference"], "used" -> With[{u = Lookup[x, "used", None]}, If[StringQ[u] && StringTrim[u] =!= "", u, used]]|>],
     True, Message[PFBTryChange::reference, ToString[x, InputForm]]],
    {x, DeleteCases[Flatten[{refs}], None]}];
  out];

recordCredits[ctx_, key_, defs_, info_, r_, toolsOK_] := Module[{dir = ctx["Dir"], sys = ctx["System"], rec = Lookup[r, "Record", None], status = Lookup[r, "Status", "not tried"],
    rung = Lookup[info, "Rung", Missing[]], secs, used, papers, why},
  (* the change's sectors: its key; for a simplification or a rescale, those of the masters it replaces *)
  secs = If[ListQ[key], {key},
    Union[If[AssociationQ[rec], PFBChangeKeys[sys, rec], {}],
      Cases[PFBMaster[sys, #]["SectorKey"] & /@ Select[Keys[defs], IntegerQ[#] && 1 <= # <= Length[PFBMasters[sys]] &], _List]]];
  (* a recorded change takes the credits of the maximal-cut-basis run it took from, stamped with its id *)
  If[AssociationQ[rec] && IntegerQ[Lookup[rec, "Id", None]],
    Scan[PFBImportMaxCutCredits[PFBMaxCutRunDir[sys, dir, #[[1]]], #, dir, "Change" -> rec["Id"]] &, mcbKeys[key, info, rec]]];
  secs = Replace[PFBSectorString /@ secs, {} -> {"whole run"}];
  If[toolsOK && declaredTools[info] =!= {}, Scan[CoreRecordTool[dir, declaredTools[info], "declared", "Sector" -> #] &, secs]];
  used = Lookup[info, "Used", Lookup[info, "Provenance", ""]];
  If[! StringQ[used] || StringTrim[used] === "", used = "a change of the basis" <> Which[IntegerQ[rung], " (rung " <> ToString[rung] <> ")", StringQ[rung], " (" <> rung <> ")", True, ""]];
  papers = paperList[Lookup[info, "Reference", {}], used];
  why = Which[
    status === "not tried", Lookup[r, "Message", ""],
    status === "rejected" && AssociationQ[Lookup[r, "Gate", None]], "refused by the gate (" <> StringRiffle[Select[r["Gate"]["Checks"], ! #["Pass"] &][[All, "Name"]], ", "] <> ")",
    True, ""];
  Do[If[CoreRecordPaper[dir, Join[p, <|"sector" -> s, "rung" -> rung, "result" -> status|>, If[AssociationQ[rec], <|"change" -> rec["Id"]|>, <||>],
        If[StringQ[why] && why =!= "", <|"outcome" -> why|>, <||>]]] === $Failed,
      Message[PFBTryChange::paper, ToString[p["reference"], InputForm]]], {p, papers}, {s, secs}];
  If[papers =!= {}, With[{c = Replace[Lookup[r, "Context", ctx], Except[_Association] -> ctx]}, PFBWriteCitations[dir, c["System"], c["State"]]]]];

(* the sectors a change took from the maximal-cut-basis run: a rung-8 change's (its candidates), those whose maximal cut
   the gate checked with a verdict (the run's points and classification), and info "MCBSectors" (move (i)) *)
checkedQ[m_] := AssociationQ[m] && ! KeyExistsQ[m, "Skipped"] && ! KeyExistsQ[m, "NotRun"];
mcbKeys[key_, info_, rec_] := With[{m = Lookup[rec, "MaxCutCheck", Missing[]]}, Union[
  If[Lookup[info, "Rung", None] === 8 && ListQ[key], {key}, {}],
  Which[
    ! AssociationQ[m], {},
    AssociationQ[Lookup[m, "Sectors", None]], Keys[Select[m["Sectors"], checkedQ]],
    ! checkedQ[m], {},
    ListQ[Lookup[m, "Sector", None]], {m["Sector"]},
    ListQ[key], {key},
    True, {}],
  Cases[Flatten[{Lookup[info, "MCBSectors", {}]}, 1], {_, _List}]]];

tryChange[ctx_Association, key_List, newDefs0_Association, info_Association, opts_Association] := Module[{dir = ctx["Dir"], st = ctx["State"], sys = ctx["System"], sl, c,
    reds = opts["Reds"], cal, defs, ch, slNew, ver, gate, sr, sec, B, mcc, mcv = None, cap = Lookup[opts, "MaxEpsDegree", Lookup[ctx["Run"], "MaxEpsDegree", $PFBMaxEpsDegree]]},
  If[AnyTrue[{"ReferenceBasis", "ReferenceSource"}, KeyExistsQ[opts, #] || KeyExistsQ[info, #] &],
    Return[<|"Status" -> "not tried", "Message" -> $referenceRemoved, "Context" -> ctx|>]];
  If[Lookup[info, "Rung", None] === "simplify", Return[trySimplify[ctx, key, newDefs0, info, opts]]];
  (* the masters of one sector only (its images included): the gate judges the rows of the sector of key, and the extra
     points reduce that sector's subtree; a master of another sector would be checked by neither *)
  With[{out = Complement[Keys[newDefs0], PFBSectorMasters[sys, key]]}, If[out =!= {},
    Return[<|"Status" -> "not tried", "Message" -> "a change replaces masters of its own sector only, and " <> ToString[ut /@ out] <> " are not masters of " <>
       PFBSectorString[key] <> ": propose each sector's change on its own (the gate and the extra points judge the rows of one sector)",
      "Context" -> ctx|>]]];
  sl = PFBCurrentSlice[dir, st]; c = currentCensus[dir, st];
  cal = PFBCalibrate[sl, First[reds]];
  If[cal["Status"] =!= "exact", Return[<|"Status" -> "not tried", "Message" -> "the reduction does not calibrate exactly against the current slice: " <> cal["Message"],
     "Calibration" -> cal, "Context" -> ctx|>]];
  defs = If[TrueQ[Lookup[opts, "Images", True]], PFBImageDefs[sys, newDefs0], newDefs0];
  ch = PFBChangeVectors[sys, sl, First[reds], cal, defs];
  If[ch === $Failed, Return[<|"Status" -> "not tried", "Message" -> "the new definitions use integrals outside the reduction pool (add them with PoolExtra)", "Context" -> ctx|>]];
  (* fitted coefficients (rungs 2 to 7: normalisation of a moved dot or of a scanned pair, residue fit, numerator read from
     it, completion, derivative choice) must be confirmed at extra points; rungs 1 and 8 are exact. A change that names
     no rung counts as fitted: it is not known to be exact. An explicit "Fitted" in opts or info wins *)
  ch = Join[ch, <|"Name" -> Lookup[info, "Name", PFBSectorString[key] <> " rung " <> ToString[Lookup[info, "Rung", "?"]]], "Key" -> key, "Kind" -> "change",
     "Fitted" -> TrueQ[Replace[Lookup[opts, "Fitted", Lookup[info, "Fitted", Automatic]], Automatic :> ! MemberQ[{1, 8}, Lookup[info, "Rung", None]]]]|>];
  slNew = PFBApplyChange[sl, ch];
  If[slNew === $Failed, Return[<|"Status" -> "not tried", "Message" -> "the new masters do not replace the old ones (det T = 0)", "Context" -> ctx|>]];
  ch["DetT"] = Last[slNew["History"]]["DetT"];
  (* negative powers of eps that the new slice itself has in the sector rows are judged by the slice gate; at the extra
     points they may appear down to the same order. The same for powers above the cap: the slice gate judged them, and
     the extra points may show them up to the same power, no higher *)
  ver = If[Length[reds] > 1,
    Module[{rgs = Flatten[Table[{slNew["Derivatives"][[k]], r, c} -> PFBEpsRange[slNew["R"][[k, slNew["Index"][r], slNew["Index"][c]]]],
        {k, Length[slNew["R"]]}, {r, Intersection[PFBSectorMasters[sys, key], slNew["Labels"]]}, {c, slNew["Labels"]}], 2]},
      PFBVerifyAtPoints[sys, Rest[reds], key, defs, <||>, <|"EpsZeroAllowed" -> Association[Cases[rgs, (e_ -> {lo_, _}) /; lo < 0 :> (e -> lo)]],
        "MaxEpsDegree" -> cap, "DegreeAllowed" -> Association[Cases[rgs, (e_ -> {_, hi_}) /; hi > cap :> (e -> hi)]], "SlicePoint" -> sl["Point"]|>]],
    <|"Pass" -> False, "Points" -> 0, "Detail" -> {}, "Ignored" -> {}|>];
  (* a reduction at the slice point, or a second one at a point already checked, is no extra point: ignored, and said so *)
  ch["PointsIgnored"] = ver["Ignored"];
  If[ver["Ignored"] =!= {}, PFBPrint["PFBTryChange: ", Length[ver["Ignored"]], " of the extra reductions ignored: ", ver["Ignored"]]];
  (* fitted coefficients must hold at every extra point: one point with poles, or above the cap, refutes the fit,
     whatever the others say *)
  ch["PointsVerified"] = If[AnyTrue[ver["Detail"], StringQ[Last[#]] && StringContainsQ[Last[#], {"entries with poles", "above eps^"}] &], 0, ver["Points"]];
  (* a point that could not be checked (new masters outside the pool, masters the system lacks, a missing focus row)
     neither confirms nor refutes: the gate does not pass a fit over it *)
  ch["PointsUnchecked"] = Select[ver["Detail"], StringQ[Last[#]] && ! StringStartsQ[Last[#], "sector rows pole-free"] && ! StringContainsQ[Last[#], "entries with poles"] &];
  (* maximal cut changed: the new masters, on the sector's own masters, are more than a rescaling of the ones they replace *)
  sec = sl["Index"] /@ Intersection[PFBSectorMasters[sys, key], sl["Labels"]];
  sr = sl["Index"] /@ ch["Replace"];
  B = ch["H"][[All, sec]];
  (* "MaxCutChanged" -> True forces the check; it can never switch it off for a change that alters the maximal cut *)
  mcc = TrueQ[Lookup[opts, "MaxCutChanged", False]] ||
    ! (AllTrue[Flatten[Table[If[sec[[cc]] === sr[[i]], True, B[[i, cc]] === 0], {i, Length[sr]}, {cc, Length[sec]}]], TrueQ]);
  gate = PFBGate[sys, sl, c, slNew, Join[ch, <|"NewDefs" -> defs|>], <|"DeferPoles" -> Lookup[opts, "DeferPoles", True], "MaxEpsDegree" -> cap,
    "NoDefer" -> Union[Keys[Lookup[st, "Flagged", <||>]], DeleteCases[#["Key"] & /@ Lookup[st, "Accepted", {}], None]]|>];
  (* a change that alters the maximal cut (a rung-3 set included) passes the maximal-cut-basis gate too: the verdict given,
     or the check run here once the other checks pass; "NoKira" only where Kira is not available *)
  If[mcc,
    mcv = maxCutVerdict[ctx, key, newDefs0, gate, opts, maxCutStep[info]];
    If[StringQ[mcv], Return[<|"Status" -> "not tried", "Message" -> mcv, "Context" -> ctx|>]];
    gate = PFBMaxCutGateCheck[gate, mcv]];
  (* the papers of info "Reference" and the tools of info "Tools" are recorded by PFBTryChange (withCredits) *)
  finish[ctx, key, sl, slNew, Join[ch, <|"NewDefs" -> defs|>], gate, Join[info, <|"MaxCutChanged" -> mcc, "Verification" -> ver,
      "MaxCutCheck" -> If[AssociationQ[mcv], PFBMaxCutSummary[mcv], Missing["NotNeeded"]], "ImagesVerified" ->
      If[TrueQ[Lookup[opts, "Images", True]] && Length[defs] > Length[newDefs0], If[TrueQ[ver["Pass"]], "at the extra points", "slice point only"], Missing["NotChecked"]]|>]]];

(* a simplification move: exact on the slice. A rescaling or a shift by other masters (ut[k] terms only) needs no
   reduction, its rows come from the slice; definitions with integrals need "Reds" at the slice point. The image
   families' masters come with the definitions (the caller maps them: PFBImageDefs would keep a base ut[k] in them). The
   checks are PFBSimplifyGate's; the record and the approval mode are those of any change *)
sliceReduction[sl_] := <|"Masters" -> (ut /@ sl["Labels"]), "Labels" -> sl["Labels"], "Point" -> sl["Point"], "Focus" -> {}, "Dm" -> {}, "Pool" -> {}, "Rp" -> {},
   "dRp" -> {}, "Invariants" -> sl["Derivatives"], "Roots" -> {}|>;

trySimplify[ctx_, key_, newDefs0_, info_, opts_] := Module[{dir = ctx["Dir"], st = ctx["State"], sys = ctx["System"], sl, c, reds, red, cal, ch, slNew, defs, gate0, gate,
    cap, mcc, mccKeys, mcv = <||>, notTried = None, name},
  sl = PFBCurrentSlice[dir, st]; c = currentCensus[dir, st];
  cap = Lookup[opts, "MaxEpsDegree", Lookup[ctx["Run"], "MaxEpsDegree", $PFBMaxEpsDegree]];
  If[! SubsetQ[sl["Labels"], Keys[newDefs0]], Return[<|"Status" -> "not tried", "Message" -> "masters that are not in the slice: " <> ToString[ut /@ Complement[Keys[newDefs0], sl["Labels"]]],
     "Context" -> ctx|>]];
  reds = Lookup[opts, "Reds", Automatic];
  red = Which[ListQ[reds] && reds =!= {}, First[reds],
    FreeQ[Values[newDefs0], _j | _Dinv], sliceReduction[sl],
    True, Return[<|"Status" -> "not tried", "Message" -> "new definitions with integrals need \"Reds\" (a reduction at the slice point whose pool holds them)", "Context" -> ctx|>]];
  cal = PFBCalibrate[sl, red];
  If[cal["Status"] =!= "exact", Return[<|"Status" -> "not tried", "Message" -> "the reduction does not calibrate exactly against the current slice: " <> cal["Message"],
     "Calibration" -> cal, "Context" -> ctx|>]];
  ch = PFBChangeVectors[sys, sl, red, cal, newDefs0];
  If[ch === $Failed, Return[<|"Status" -> "not tried", "Message" -> "the new definitions use integrals outside the reduction pool", "Context" -> ctx|>]];
  name = Lookup[info, "Name", "simplify"];
  slNew = PFBApplyChange[sl, Join[ch, <|"Name" -> name|>]];
  If[slNew === $Failed, Return[<|"Status" -> "not tried", "Message" -> "the new masters do not replace the old ones (det T = 0)", "Context" -> ctx|>]];
  (* the record keeps definitions in integrals: a ut[k] term stands for master k before the change *)
  defs = Association[KeyValueMap[#1 -> (#2 /. ut[k_Integer] :> PFBMaster[sys, k]["RootFree"]) &, newDefs0]];
  ch = Join[ch, <|"Name" -> name, "Key" -> key, "Kind" -> "change", "Fitted" -> False, "NewDefs" -> defs, "DetT" -> Last[slNew["History"]]["DetT"]|>];
  gate0 = PFBGate[sys, sl, c, slNew, ch, <|"DeferPoles" -> False, "MaxEpsDegree" -> cap|>];
  gate = PFBSimplifyGate[gate0, sys, sl, c, slNew, ch, <|"Degrees" -> Lookup[opts, "Degrees", Missing[]]|>];
  (* the maximal cut of a sector changes when a new master has a component on another master of its own sector *)
  mccKeys = Union[Table[With[{l = ch["Replace"][[i]]},
      If[AnyTrue[sl["Index"] /@ Intersection[PFBSectorMasters[sys, PFBMaster[sys, l]["SectorKey"]], sl["Labels"]], # =!= sl["Index"][l] && ch["H"][[i, #]] =!= 0 &],
        PFBMaster[sys, l]["SectorKey"], Nothing]], {i, Length[ch["Replace"]]}]];
  mcc = mccKeys =!= {};
  (* such a move passes the maximal-cut-basis gate too, sector by sector, as every change of the maximal cut does
     (PFBTryChange): the verdict given for the sector ("MaxCutCheck" -> <|key -> verdict|>, or one verdict for a move of
     one sector), or the check run here once the other checks pass; "NoKira" only where Kira is not available *)
  Do[Module[{v = maxCutVerdict[ctx, k, KeySelect[newDefs0, MemberQ[PFBMaxCutBasis[sys, k], #] &], gate, sectorMaxCutOpts[opts, k, Length[mccKeys]], maxCutStep[info]]},
     If[StringQ[v], notTried = If[Length[mccKeys] > 1, PFBSectorString[k] <> ": ", ""] <> v; Break[]];
     mcv[k] = v;
     gate = sectorMaxCutGate[gate, k, v, Length[mccKeys] > 1]], {k, mccKeys}];
  If[StringQ[notTried], Return[<|"Status" -> "not tried", "Message" -> notTried, "Context" -> ctx|>]];
  finish[ctx, key, sl, slNew, ch, gate, Join[info, <|"MaxCutChanged" -> mcc, "Verification" -> <|"Pass" -> False, "Points" -> 0, "Detail" -> {}|>,
     "MaxCutCheck" -> If[mcv === <||>, Missing["NotNeeded"], maxCutRecord[mcv]], "ImagesVerified" -> Missing["NotChecked"]|>]]];

(* the options of the maximal-cut check of sector k in a simplification: a verdict given per sector (<|key -> verdict|>)
   is the sector's; one verdict counts for a move of one sector only *)
sectorMaxCutOpts[opts_, k_, n_] := With[{g = Lookup[opts, "MaxCutCheck", Automatic]}, Which[
   AssociationQ[g] && g =!= <||> && AllTrue[Keys[g], ListQ], Join[opts, <|"MaxCutCheck" -> Lookup[g, Key[k], Automatic]|>],
   AssociationQ[g] && n > 1, Join[opts, <|"MaxCutCheck" -> Automatic|>],
   True, opts]];

(* the check "maximal cut" of a move of one sector, or "maximal cut (fam/jPATTERN)" per sector of a move of several *)
sectorMaxCutGate[gate_, k_, v_, several_] := If[! several, PFBMaxCutGateCheck[gate, v],
  Module[{g = PFBMaxCutGateCheck[<|"Checks" -> {}, "Pass" -> True, "Message" -> ""|>, v], c, out = gate},
    c = Join[Last[g["Checks"]], <|"Name" -> "maximal cut (" <> PFBSectorString[k] <> ")"|>];
    out["Checks"] = Append[gate["Checks"], c];
    out["Pass"] = TrueQ[gate["Pass"]] && TrueQ[c["Pass"]];
    out["Message"] = gate["Message"] <> "\n" <> c["Name"] <> ": " <> If[c["Pass"], If[TrueQ[c["NotChecked"]], "not checked", "ok"], "FAILED"] <> " (" <> c["Detail"] <> ")";
    out]];

(* the record of the maximal-cut checks of a move: the verdict of its one sector, or for several sectors their texts
   joined (the pages read "Text", "Skipped" and "Flag") and each sector's under "Sectors" *)
maxCutRecord[mcv_Association] := If[Length[mcv] == 1, Join[PFBMaxCutSummary[First[mcv]], <|"Sector" -> First[Keys[mcv]]|>],
  Module[{sm = PFBMaxCutSummary /@ mcv, skipped, flags},
    skipped = KeyValueMap[PFBSectorString[#1] <> ": " <> #2["Skipped"] &, Select[sm, StringQ[Lookup[#, "Skipped", None]] &]];
    flags = KeyValueMap[PFBSectorString[#1] <> ": " <> #2["Flag"] &, Select[sm, StringQ[Lookup[#, "Flag", None]] &]];
    Join[<|"Text" -> StringRiffle[KeyValueMap[PFBSectorString[#1] <> ": " <> #2["Text"] &, sm], "; "], "Sectors" -> sm|>,
      If[skipped === {}, <||>, <|"Skipped" -> StringRiffle[skipped, "; "]|>], If[flags === {}, <||>, <|"Flag" -> StringRiffle[flags, "; "]|>]]]];

PFBTryRescale[ctx_Association, shifts_Association, info_Association] := withCredits[ctx, None, shifts, Join[<|"Rung" -> 1|>, info], tryRescale[ctx, shifts, info]];

tryRescale[ctx_Association, shifts_Association, info_Association] := Module[{dir = ctx["Dir"], st = ctx["State"], sys = ctx["System"], sl, c, slNew, gate, ch},
  sl = PFBCurrentSlice[dir, st]; c = currentCensus[dir, st];
  slNew = PFBRescaleSlice[sl, shifts];
  ch = <|"Name" -> Lookup[info, "Name", "rescale"], "Kind" -> "rescale", "Key" -> None, "Replace" -> Keys[shifts], "Shifts" -> shifts,
    "NewDefs" -> Association[KeyValueMap[#1 -> eps^#2 PFBMaster[sys, #1]["RootFree"] &, shifts]]|>;
  gate = PFBGate[sys, sl, c, slNew, ch, <|"MaxEpsDegree" -> Lookup[ctx["Run"], "MaxEpsDegree", $PFBMaxEpsDegree]|>];
  finish[ctx, None, sl, slNew, ch, gate, Join[<|"Rung" -> 1, "MaxCutChanged" -> False|>, info]]];


(* ::Section:: *)
(*Sector folders*)


PFBAppendAttempt[dir_String, key_List, a_Association] := MCBAppendAttempt[PFBSectorDir[dir, key], a];
PFBAppendNotes[dir_String, key_List, text_String] := (If[! DirectoryQ[PFBSectorDir[dir, key]], CreateDirectory[PFBSectorDir[dir, key], CreateIntermediateDirectories -> True]];
  MCBAppendNotes[PFBSectorDir[dir, key], text]);

(* the run's ledger (citations.m, the core's), with the sector written fam/jPATTERN, or "whole run" *)
PFBRecordLiterature[dir_String, key_, e_Association] :=
  If[CoreRecordPaper[dir, Join[DeleteMissing[e], <|"sector" -> If[ListQ[key], PFBSectorString[key], "whole run"]|>]] === $Failed, $Failed, PFBWriteCitations[dir]];

(* every write of CITATIONS.md: the starting masters' maximal-cut-basis run is credited first (decision 5) *)
PFBWriteCitations[dir_String, sys_Association, st_Association] := (PFBStartCredits[dir, sys, st]; CoreWriteCitations[dir]);
PFBWriteCitations[dir_String] := Module[{run = CoreRunFolder[dir], st, sys},
  st = PFBLoadState[run];
  sys = If[AssociationQ[st], runSystem[st], Missing["NoSystem"]];
  If[AssociationQ[sys], PFBWriteCitations[run, sys, st], CoreWriteCitations[run]]];

(* decision 5: a family whose masters came from a maximal-cut-basis run (system.wl "MCBRun") credits that run for every
   sector that still has a starting master no accepted change replaced; the stamp lets the reader demote the copies
   once accepted changes replace them all *)
PFBStartCredits[dir_String, sys_Association, st_Association] := Module[{replaced},
  (* a rescale keeps the same integrals: it replaces no starting master *)
  replaced = Union[Flatten[{Lookup[#, "Replace", {}], Keys[Replace[Lookup[#, "NewDefs", <||>], Except[_Association] -> <||>]]} & /@
    Select[Lookup[st, "Accepted", {}], AssociationQ[#] && ! CoreRescaleChangeQ[#] &]]];
  Flatten[Table[With[{run = Lookup[sys["Families"][k[[1]]], "MCBRun", None], labs = PFBMaxCutBasis[sys, k]},
      If[StringQ[run] && labs =!= {} && Complement[labs, replaced] =!= {}, PFBImportMaxCutCredits[run, k, dir, "Start" -> labs], {}]],
    {k, PFBSectorKeys[sys]}]]];

(* conventions.wl "Credits": what produced the starting DE, which came from outside the skill *)
PFBSliceCredits[conv_Association] := Module[{tools = {}, papers = {}, bad = {}, unknown},
  Do[Which[
     StringQ[x] && CoreToolKey[x] =!= $Failed, AppendTo[tools, CoreToolKey[x]],
     AssociationQ[x] && StringQ[Lookup[x, "reference", None]] && StringTrim[x["reference"]] =!= "",
       AppendTo[papers, <|"reference" -> x["reference"], "used" -> With[{u = Lookup[x, "used", None]}, If[StringQ[u] && StringTrim[u] =!= "", u, "the starting differential equation"]]|>],
     True, AppendTo[bad, x]],
    {x, DeleteCases[Flatten[{Lookup[conv, "Credits", {}]}], None]}];
  unknown = Select[bad, StringQ];
  Which[
    bad === {}, <|"Tools" -> DeleteDuplicates[tools], "Papers" -> papers|>,
    unknown === bad, "conventions.wl \"Credits\": not in the registry of tools and methods: " <> StringRiffle[ToString[#, InputForm] & /@ unknown, ", "] <>
      " (the known names are " <> StringRiffle[Keys[$MCBTools], ", "] <> ")",
    True, "conventions.wl \"Credits\": " <> StringRiffle[ToString[#, InputForm] & /@ bad, ", "] <> " is neither a tool of the registry nor <|\"reference\" -> ..., \"used\" -> ...|>" <>
      " (the known tools are " <> StringRiffle[Keys[$MCBTools], ", "] <> ")"]];

PFBRecordSliceCredits::refused = "`1`; nothing is recorded.";
PFBRecordSliceCredits[dir_String, conv_Association] := Module[{c = PFBSliceCredits[conv], out},
  If[StringQ[c], Message[PFBRecordSliceCredits::refused, c]; Return[$Failed]];
  If[c["Tools"] === {} && c["Papers"] === {}, Return[{}]];
  out = Join[If[c["Tools"] === {}, {}, CoreRecordTool[dir, c["Tools"], "the starting DE", "Sector" -> "whole run"]],
    CoreRecordPaper[dir, Join[#, <|"sector" -> "whole run", "rung" -> "the starting DE"|>]] & /@ c["Papers"]];
  PFBWriteCitations[dir];
  out];

PFBSectorStatus[sys_Association, st_Association, census_Association, key_List] := Module[{sec = Lookup[census["Sectors"], Key[key], Missing[]], acc},
  acc = Select[st["Accepted"], MemberQ[PFBChangeKeys[sys, #], key] &];
  Which[
    KeyExistsQ[st["Flagged"], key], "flagged",
    MissingQ[sec], "not in slice",
    (* done: no finite pole, no negative power of eps and nothing above the cap in its rows *)
    Lookup[sec, "Issues", If[sec["BadRows"] === {}, {}, {"finite poles"}]] === {} && AnyTrue[acc, #["MaxCutChanged"] &], "pole-free (maximal cut changed)",
    Lookup[sec, "Issues", If[sec["BadRows"] === {}, {}, {"finite poles"}]] === {}, "pole-free",
    sec["PossiblyInherited"], "inherited",
    True, "open"]];

PFBWriteSectorRecord[dir_String, sys_Association, st_Association, census_Association, key_List] := Module[{sd = PFBSectorDir[dir, key], labs, acc, sec, rec, prov},
  If[! DirectoryQ[sd], CreateDirectory[sd, CreateIntermediateDirectories -> True]];
  labs = PFBSectorMasters[sys, key];
  (* the changes of this sector, and the simplifications that changed some of its masters *)
  acc = Select[st["Accepted"], MemberQ[PFBChangeKeys[sys, #], key] &];
  sec = Lookup[census["Sectors"], Key[key], <||>];
  prov[l_] := With[{a = SelectFirst[Reverse[acc], KeyExistsQ[#["NewDefs"], l] &, None]}, If[a === None, "unchanged", "change " <> ToString[a["Id"]] <> " (rung " <> ToString[PFBRungNumber[a]] <> ")"]];
  rec = <|"status" -> PFBSectorStatus[sys, st, census, key], "name" -> SectorName[key[[2]]], "family" -> ToString[key[[1]]], "sector" -> key[[2]],
    "id" -> SectorID[key[[2]]], "images" -> ToString /@ PFBImagesOf[sys, key[[1]]],
    "masters" -> Table[With[{m = PFBMaster[sys, l]}, <|"label" -> "ut[" <> ToString[l] <> "]", "family" -> ToString[m["Family"]], "pos" -> m["Pos"],
        "definition" -> m["Def"], "oldDefinition" -> Lookup[m, "OldDef", m["Def"]], "changed" -> TrueQ[Lookup[m, "Changed", False]],
        "epsPowers" -> Union[DeleteCases[Flatten[PFBEpsPowers[m["RootFree"]][[All, 2]]], _String]], "provenance" -> prov[l]|>], {l, labs}],
    "badRows" -> Lookup[sec, "BadRows", {}], "poleFactors" -> Lookup[sec, "PoleFactors", {}], "epsZeroRows" -> Lookup[sec, "EpsZeroRows", {}],
    "possiblyInherited" -> Lookup[sec, "PossiblyInherited", False], "couplesToBadLower" -> (PFBSectorString /@ Lookup[sec, "CouplesToBadLower", {}]),
    (* the census's hidden-weight hints: on this sector (a clean one whose subtree holds every column of a factor in the
       rows above), and below it (this sector's rows show a factor that a clean lower sector may carry) *)
    "possibleHiddenWeight" -> (<|"factor" -> #["Factor"], "rows" -> #["Rows"], "columns" -> #["Columns"], "sectors" -> (PFBSectorString /@ #["Sectors"]), "tried" -> TrueQ[#["Tried"]]|> & /@
       Select[Lookup[census, "HiddenWeights", {}], #["Sector"] === key &]),
    "hiddenWeightBelow" -> (<|"factor" -> #["Factor"], "sector" -> PFBSectorString[#["Sector"]], "columns" -> #["Columns"], "tried" -> TrueQ[#["Tried"]]|> & /@
       Select[Lookup[census, "HiddenWeights", {}], MemberQ[#["Sectors"], key] &]),
    "sources" -> (Lookup[#, "Sources", Missing[]] & /@ acc), "residues" -> (Lookup[#, "Residues", Missing[]] & /@ acc),
    "completion" -> (Lookup[#, "Completion", Missing[]] & /@ acc), "maxCutChanged" -> AnyTrue[acc, #["MaxCutChanged"] &],
    "deferredHere" -> If[Lookup[sec, "BadRows", {}] === {}, {}, PFBDeferredObligations[st, key]], "determinant" -> (Lookup[#, "Determinant", Missing[]] & /@ acc), "determinantOnReference" -> (Lookup[#, "DetOnReference", Missing[]] & /@ acc),
    "maxCutCheck" -> (Lookup[#, "MaxCutCheck", Missing[]] & /@ acc),
    "verification" -> Table[<|"change" -> a["Id"], "gate" -> a["Gate"], "pointsVerified" -> a["PointsVerified"], "imagesVerified" -> a["ImagesVerified"]|>, {a, acc}],
    "profiles" -> Table[<|"change" -> a["Id"], "before" -> a["ProfileBefore"], "after" -> a["ProfileAfter"]|>, {a, acc}],
    "provenance" -> (#["Provenance"] & /@ acc), "flags" -> If[KeyExistsQ[st["Flagged"], key], {st["Flagged"][key]}, {}], "date" -> PFBTimeStamp[]|>;
  MCBWriteBasis[sd, rec];
  Put[Table[PFBMaster[sys, l]["Def"] /. PFBRootDefs[sys], {l, labs}], FileNameJoin[{sd, "masters.m"}]];
  rec];


(* ::Section:: *)
(*Export*)


(* A drop-in replacement for the family's masters file: the same order, unchanged entries exactly as written there,
   changed ones divided by the family's "Prefactors" again, with the user's root symbols and explicit Sqrt[...] for
   radicands that have none. system.wl keeps its "Rules" and "Prefactors". Image families with their own masters file
   are exported too; the others follow the maps. *)
PFBExportMasters[sys_Association, st_Association, dir_String] := Module[{ed = FileNameJoin[{dir, "export"}], changedFams, files = {}},
  If[! DirectoryQ[ed], CreateDirectory[ed]];
  changedFams = Select[Union[PFBMaster[sys, #]["Family"] & /@ Flatten[Keys[#["NewDefs"]] & /@ st["Accepted"]]], ! MissingQ[PFBRawMasters[sys, #]] &];
  Do[Module[{n = Length[Select[PFBMasters[sys], #["Family"] === fn &]], raw = PFBRawMasters[sys, fn], lines, f = FileNameJoin[{ed, ToString[fn] <> ".m"}], asWritten, entry},
     asWritten = Length[raw["Raw"]] == n;
     (* a master in the file's convention: its prefactor divided out, rPFB symbols back to Sqrt[...] *)
     entry[m_, p_] := Together[If[ListQ[raw["Prefactors"]], m["Def"]/PFBRootify[sys, raw["Prefactors"][[p]]], m["Def"]]] /. Lookup[sys, "NewRoots", {}];
     lines = Table[With[{m = PFBMaster[sys, sys["LabelOf"][{fn, p}]]},
        Which[
          TrueQ[Lookup[m, "Changed", False]], " (* pos " <> ToString[p] <> ": changed, see CHANGES.md *)\n " <> ToString[entry[m, p], InputForm],
          asWritten, " " <> ToString[raw["Raw"][[p]], InputForm],
          True, " " <> ToString[entry[m, p], InputForm]]], {p, n}];
     Export[f, "(* masters of " <> ToString[fn] <> ", exported by the pole-free-basis skill on " <> PFBTimeStamp[] <> ".\n" <>
        "   A drop-in replacement for " <> raw["File"] <> ": the same order, the same \"Rules\" and \"Prefactors\" in system.wl.\n" <>
        If[asWritten, "   Unchanged entries are as written there; changed ones are in the j[" <> ToString[fn] <> ", ...] form, which the Rules leave alone.",
          "   The file's entries could not be matched one by one: every entry is in the j[" <> ToString[fn] <> ", ...] form, prefactors divided out."] <>
        " *)\n{\n" <> StringRiffle[lines, ",\n\n"] <> "\n}\n", "Text"];
     AppendTo[files, f]], {fn, changedFams}];
  files];

tex[e_] := ToString[e, InputForm];
(* the sectors of a change in text: its key, or those of the masters a simplification replaced *)
keysText[sys_, a_, wrap_ : Identity] := With[{ks = PFBChangeKeys[sys, a]}, If[ks === {}, "-", StringRiffle[wrap[PFBSectorString[#]] & /@ ks, ", "]]];

(* the maximal-cut-basis gate on the new basis, as the record keeps it *)
maxCutNote[a_] := With[{m = Lookup[a, "MaxCutCheck", Missing[]]}, If[AssociationQ[m] && StringQ[Lookup[m, "Text", None]], "; maximal cut: " <> m["Text"], ""]];

PFBWriteChanges[sys_Association, st_Association, dir_String, extra_String : ""] := Module[{acc = st["Accepted"], out = {}, add, unver = {}, last},
  add[s__] := AppendTo[out, StringJoin[s]];
  last = If[st["Slices"] === {}, None, Last[st["Slices"]]];
  add["# Basis changes: ", sys["Name"], "\n\n"];
  add["Written by the pole-free-basis skill on ", PFBTimeStamp[], ". Run folder: `", dir, "`. Accepted changes: ", ToString[Length[acc]],
    "; pending approval: ", ToString[Length[st["Pending"]]], "; flagged sectors: ", ToString[Length[st["Flagged"]]], ".\n\n"];
  If[last =!= None, add["Current slice (", last["Label"], "): ", ToString[last["BadEntries"]], " entries with finite eps poles in ", ToString[last["BadRows"]],
     " rows, ", ToString[last["EpsZero"]], " entries with negative powers of eps",
     If[IntegerQ[Lookup[last, "MaxDegree", None]], "; highest power of eps " <> ToString[last["MaxDegree"]] <>
       If[Lookup[last, "HighDegree", 0] > 0, " (" <> ToString[last["HighDegree"]] <> " entries above the cap eps^" <> ToString[last["DegreeCap"]] <> ")", ""], ""], ".\n\n"]];
  If[AnyTrue[acc, #["MaxCutChanged"] &],
    add["## Maximal-cut basis changes\n\n"];
    Do[add["- **", keysText[sys, a], "** (change ", ToString[a["Id"]], ", rung ", ToString[PFBRungNumber[a]], "): det = `", tex[a["Determinant"]], refDetNote[a, tex],
       "`", maxCutNote[a], "; eps profile of the sector rows ", tex[a["ProfileBefore"]], " -> ", tex[a["ProfileAfter"]], ".\n"], {a, Select[acc, #["MaxCutChanged"] &]}];
    add["\n"]];
  add["## Summary\n\n| # | sector | masters | rung | maximal cut changed | determinant | extra points |\n|---|---|---|---|---|---|---|\n"];
  Do[add["| ", ToString[a["Id"]], " | ", keysText[sys, a, ("`" <> # <> "`") &], " | ",
     StringRiffle[("ut[" <> ToString[#] <> "] (pos " <> ToString[PFBMaster[sys, #]["Pos"]] <> ")") & /@ Join[a["Replace"], Keys[a["Shifts"]]], ", "], " | ",
     ToString[PFBRungNumber[a]], " | ", If[a["MaxCutChanged"], "**yes**", "no"], " | `", tex[a["Determinant"]], refDetNote[a, tex], "` | ", ToString[a["PointsVerified"]], " |\n"], {a, acc}];
  add["\n## Changes\n\n"];
  Do[
    add["### ", ToString[a["Id"]], ". ", a["Name"], "\n\n"];
    If[Lookup[a, "Rung", None] === "simplify",
      add["- Sectors: ", keysText[sys, a, ("`" <> # <> "`") &], "; the simplification phase (rung simplify).\n"],
      add["- Sector: ", If[a["Key"] === None, "-", "`" <> PFBSectorString[a["Key"]] <> "`"], "; rung ", ToString[PFBRungNumber[a]], " (", rungName[a], ").\n"]];
    add["- How it was found: ", If[a["Provenance"] === "", "not recorded", a["Provenance"]], "\n"];
    If[! MissingQ[a["Sources"]], add["- Why: source test ", tex[a["Sources"]], "\n"]];
    If[a["Shifts"] =!= <||>, add["- Rescaling U -> eps^n U: ", tex[a["Shifts"]], "\n"]];
    With[{sm = Lookup[a, "Simplify", Missing[]]}, If[AssociationQ[sm],
      add["- Simplification (", ToString[Lookup[sm, "Title", Lookup[sm, "Move", "?"]]], ", phase move ", ToString[Lookup[sm, "MoveId", "?"]], ", candidate ",
        ToString[Lookup[sm, "Candidate", "?"]], "): kinematic degrees {highest, terms at it, sum} ", ToString[Lookup[sm, "BeforeObjective", "?"]], " -> ",
        ToString[Lookup[sm, "AfterObjective", "?"]], " (measured; predicted ", ToString[Lookup[sm, "PredictedObjective", "?"]], ")",
        If[AssociationQ[Lookup[sm, "Rescalings", None]], "; rescalings " <> StringRiffle[KeyValueMap["ut[" <> ToString[#1] <> "] -> `" <> tex[#2] <> "` ut[" <> ToString[#1] <> "]" &, sm["Rescalings"]], ", "], ""],
        ".\n"]]];
    Do[add["- ut[", ToString[l], "] (", ToString[PFBMaster[sys, l]["Family"]], " pos ", ToString[PFBMaster[sys, l]["Pos"]], ")\n  - old: `", tex[a["OldDefs"][l]], "`\n  - new: `", tex[a["NewDefs"][l]], "`\n"],
      {l, a["Replace"]}];
    With[{d = Lookup[SelectFirst[a["Gate"], #["Name"] === "rows" &, <||>], "Deferred", <||>]}, If[d =!= <||>,
      add["- New poles deferred to the sectors above: ", StringRiffle[KeyValueMap["`" <> PFBSectorString[#1] <> "` rows " <> ToString[ut /@ #2["Rows"]] <>
          " (through " <> ToString[ut /@ #2["Sources"]] <> If[TrueQ[#2["Verified"]], "", ", one master: not verified"] <> ")" &, d], "; "], ". Their own fixes must remove them.\n"]]];
    With[{m = Lookup[SelectFirst[a["Gate"], #["Name"] === "rows" &, <||>], "Moved", <||>]}, If[m =!= <||>,
      add["- Moved poles deferred to the sectors above (factors their rows had before, now in new columns): ", StringRiffle[KeyValueMap["`" <> PFBSectorString[#1] <> "` rows " <>
          ToString[ut /@ #2["Rows"]] <> ", factors `" <> tex[#2["Factors"]] <> "`, entries " <> StringRiffle[("d" <> ToString[#[[1]]] <> "(ut[" <> ToString[#[[2]]] <> "], ut[" <>
            ToString[#[[3]]] <> "])") & /@ Take[#2["Entries"], UpTo[6]], ", "] &, m], "; "], ". Their own fixes must remove them.\n"]]];
    add["- Maximal cut changed: ", If[a["MaxCutChanged"], "**yes**, det = `" <> tex[a["Determinant"]] <> refDetNote[a, tex] <> "`" <> maxCutNote[a], "no"], ".\n"];
    With[{m = Lookup[a, "MaxCutCheck", Missing[]]}, Which[
      AssociationQ[m] && KeyExistsQ[m, "Skipped"], AppendTo[unver, "change " <> ToString[a["Id"]] <> ": the maximal-cut-basis gate did not run on the new basis (" <> m["Skipped"] <> ")"],
      AssociationQ[m] && StringQ[Lookup[m, "Flag", None]], AppendTo[unver, "change " <> ToString[a["Id"]] <> ": " <> m["Flag"]],
      TrueQ[a["MaxCutChanged"]] && ! KeyExistsQ[a, "MaxCutCheck"], AppendTo[unver, "change " <> ToString[a["Id"]] <> " alters the maximal cut and was recorded before PFBTryChange ran the maximal-cut-basis gate: not checked there"]]];
    add["- Gate: ", StringRiffle[(#["Name"] <> " " <> If[#["Pass"], If[TrueQ[Lookup[#, "NotChecked", False]], "not checked", "ok"], "FAILED"] <> " (" <> #["Detail"] <> ")") & /@ a["Gate"], "; "], "\n"];
    If[a["Notes"] =!= "", add["- Notes: ", a["Notes"], "\n"]];
    add["\n"];
    If[a["Fitted"] && a["PointsVerified"] < 2, AppendTo[unver, "change " <> ToString[a["Id"]] <> ": coefficients fitted, verified at " <> ToString[a["PointsVerified"]] <> " extra point(s) only"]];
    If[MissingQ[a["ImagesVerified"]] && a["Key"] =!= None && PFBImagesOf[sys, a["Key"][[1]]] =!= {},
      AppendTo[unver, "change " <> ToString[a["Id"]] <> ": the image families' copies were obtained by the maps and not checked separately"]],
    {a, acc}];
  If[! TrueQ[st["Regenerated"]], AppendTo[unver, "the full differential equation has not been regenerated with the new basis: every check above is on the numerical slice and on subtree reductions"]];
  Do[AppendTo[unver, "change " <> ToString[p["Id"]] <> " is waiting for approval"], {p, st["Pending"]}];
  Do[If[AnyTrue[Lookup[a, "ReferenceWarnings", {}], StringContainsQ[#, "vacuous"] &],
      AppendTo[unver, "change " <> ToString[a["Id"]] <> ": its reference basis equals it on the maximal cut, so the determinant check of that version rested on the reference's source (" <>
        ToString[a["ReferenceSource"]] <> ")"]], {a, acc}];
  KeyValueMap[AppendTo[unver, "sector " <> PFBSectorString[#1] <> " flagged: " <> #2["Reason"] <>
      With[{hw = Lookup[#2, "HiddenWeight", Missing[]]}, If[AssociationQ[hw], " (hidden-weight test: " <> hw["Message"] <> If[TrueQ[Lookup[#2, "Forced", False]], "; flagged with Force", ""] <> ")", ""]]] &,
    st["Flagged"]];
  (* sections of the toolkit's later modules (the kinematic degrees and the simplification phase, PFBMakeReports) *)
  If[extra =!= "", add[extra, "\n"]];
  add["## Not verified, or not known\n\n", If[unver === {}, "Nothing.\n", StringJoin[("- " <> # <> "\n") & /@ unver]], "\n"];
  (* what to cite: the Cite part of CITATIONS.md, from the run's ledger (citations.m) *)
  With[{cite = CoreCiteMarkdown[dir]},
    If[cite =!= "",
      add["## Credits\n\nCite these tools and papers when you use the new basis. `CITATIONS.md` says which sector used each one and how, ",
        "and lists the papers only consulted.\n\n", cite]]];
  Export[FileNameJoin[{dir, "CHANGES.md"}], StringJoin[out], "Text"];
  FileNameJoin[{dir, "CHANGES.md"}]];


End[];
EndPackage[];
