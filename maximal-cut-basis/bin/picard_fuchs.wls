#!/usr/bin/env wolframscript
(* The picard-fuchs step for one sector, on its own: the Picard-Fuchs operator of the maximal cut on the line through
   the points of the Kira check, its label and the two checks (Baikov curve, Kira), written to basis.m
   ("classification") and the pages. The first pass runs the same step; this script is for sectors that were done
   before it existed, or to run it again. The status follows the label when the sector's DE verdict allows it: an
   eps-polynomial basis becomes eps-polynomial on a non-polylog label and eps-polynomial (dlog search incomplete) on a
   polylog one; any change is recorded in attempts.m.
   It recounts the masters with Kira and builds the representations, which the first pass already has.
   usage: picard_fuchs.wls run.wl|<run folder> j<pattern> [--dry-run] [--verbose]
     --dry-run   print the classification; basis.m, the pages and the run's ledger of tools are not changed *)
Get[FileNameJoin[{ParentDirectory[DirectoryName[$InputFileName]], "lib", "MaximalCutBasis.wl"}]];

Module[{args, setup, fam, sec, dir, rec, pts, reps, cls, status, old, flags, dry},
  args = Rest[$ScriptCommandLine];
  If[Length[Select[args, ! StringStartsQ[#, "--"] &]] < 2, Print["usage: picard_fuchs.wls run.wl|<run folder> j<pattern> [--dry-run] [--verbose]"]; CoreVerdict["picard_fuchs", "usage"]];
  {setup, sec} = {MCBRunSetup[args[[1]]], SelectFirst[Rest[args], StringStartsQ[#, "j"] &, None]};
  If[setup === $Failed || sec === None, CoreVerdict["picard_fuchs", "usage", <|"message" -> "no run found for " <> args[[1]] <> ", or no sector j<pattern>"|>]];
  fam = setup["fam"]; sec = SectorFromName[sec];
  dir = MCBSectorDir[setup["dir"], sec];
  dry = MemberQ[args, "--dry-run"];
  rec = MCBReadBasis[dir];
  (* what the step uses is credited to the sector; a dry run writes nothing, credits included *)
  If[dry, CoreCitationContext[None], CoreCitationContext[dir, SectorName[sec], "picard_fuchs"]];
  MCBResetToolsUsed[];
  (* the points of the Kira check: those of basis.m, else those of run.wl, else the seed's *)
  pts = Which[ListQ[Lookup[rec, "points", None]] && Length[rec["points"]] >= 2, Take[rec["points"], 2],
    ListQ[setup["run"]["Points"]], Take[setup["run"]["Points"], 2], True, MCBPoints[fam, 2, setup["run"]["Seed"]]];
  reps = Replace[Quiet@Check[MCBRepresentations[fam, sec, <|"TimeLimit" -> setup["run"]["TimeLimits"]["Baikov"]|>], {}], Except[_List] -> {}];
  cls = MCBPicardFuchs[fam, sec, <|"Points" -> pts, "Representations" -> reps, "Dir" -> FileNameJoin[{dir, "picard-fuchs"}],
     "Seed" -> setup["run"]["Seed"], "Verbose" -> MemberQ[args, "--verbose"]|>];
  Print[SectorName[sec], ": ", cls["label"], If[StringQ[Lookup[cls, "reason", None]], " (" <> cls["reason"] <> ")", ""], ", ", Lookup[cls, "time", "?"], " s"];
  Scan[If[AssociationQ[Lookup[cls, #, None]], Print["  ", #, ": ", cls[#]["status"], If[StringQ[Lookup[cls[#], "message", None]], " -- " <> cls[#]["message"], ""]]] &,
    {"baikovCheck", "kiraCheck"}];
  If[dry || ! KeyExistsQ[rec, "sector"],
    If[! dry, Print["no basis.m in ", dir, ": nothing written (bin/run_sector.wls runs the first pass, which includes this step)"]];
    CoreVerdict["picard_fuchs", If[cls["label"] === "not computed", "fail", "pass"], <|"sector" -> SectorName[sec], "label" -> cls["label"], "written" -> False|>]];
  (* the status, from the DE verdict of basis.m and the label *)
  old = rec["status"];
  status = If[AssociationQ[Lookup[rec, "kiraVerdict", None]] && KeyExistsQ[rec["kiraVerdict"], "status"] &&
      MemberQ[{"eps-form", "eps-polynomial", "eps-polynomial (dlog search incomplete)"}, old], MCBStatusFor[rec["kiraVerdict"], reps, cls], old];
  If[status =!= old, Print["status: ", old, " -> ", status]];
  MCBAppendAttempt[dir, <|"what" -> "Picard-Fuchs operator (bin/picard_fuchs.wls)", "outcome" -> cls["label"] <> If[status =!= old, "; status " <> old <> " -> " <> status, ""],
     "time" -> Lookup[cls, "time", 0]|>];
  flags = Join[Select[Lookup[rec, "flags", {}], ! (StringQ[#] && StringStartsQ[#, "Picard-Fuchs:"]) &], MCBClassificationFlags[cls, status]];
  (* toolsUsed and citations: every tool the run credits to the sector, this step's included *)
  rec = Join[rec, <|"status" -> status, "classification" -> cls, "flags" -> flags|>, MCBRecordCitations[dir, SectorName[sec]]];
  rec["retryHints"] = If[MCBFlaggedQ[rec], MCBRetryHints[dir, rec], {}];
  MCBWriteBasis[dir, rec];
  If[! MCBSkippedQ["reports"], MCBBasisHTML[dir, fam]; MCBSummaryHTML[setup["dir"], fam]];
  CoreVerdict["picard_fuchs", If[cls["label"] === "not computed", "fail", "pass"], <|"sector" -> SectorName[sec], "label" -> cls["label"], "status" -> status,
     "statusBefore" -> old, "written" -> True|>]
];
