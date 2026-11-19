#!/usr/bin/env wolframscript
(* The gate: check a basis for a sector on its maximal-cut DE (Kira, two rational points, every invariant).
   usage: check_basis.wls <sector folder> [basis file] [--dry-run] [--adopt] [--rung n | --tie-breaker reason] [--provenance text]
                          [--reference text ... [--used text]] [--tool name ...]

   --rung n says which rung of the ladder produced the basis (recorded in attempts.m; leave it out for a plain re-check).
   --tie-breaker reason   the basis is as good as the current one and preferred by a tie-breaker (SKILL.md): rational
     normalisations, conventions shared with related sectors (a basis with more eps-pure elements needs none: it is
     better). It is adopted unless it is worse than the current one, and recorded as a tie-breaker with its reason, not
     as a rung of the ladder.
   --reference text records a paper the basis comes from in the run's ledger of tools and papers (citations.m,
     CITATIONS.md), with the outcome of this check (adopted or not), so that its authors can be acknowledged; give it
     once per paper, as "authors, title, journal, arXiv:xxxx.xxxxx". --used text says what was taken from it (default:
     the provenance).
   --tool name   a tool you ran by hand to get the basis (INITIAL, Libra, Fuchsia, ore_algebra, ...), as named in the
     registry of core/lib/Core/Tools.wl (its key or display name, in any case); give it once per tool. It is credited
     to the sector once the basis was read and checked, adopted or not; an unknown name is a usage error that lists the
     known ones. The words of --provenance credit nothing.
   Without a basis file it re-checks masters.m and keeps its labels. A basis file holds a list whose elements are
   either expressions (as in masters.m), or <|"definition" -> J, "label" -> "...", "provenance" -> "..."|>, or J -> "label".
   --dry-run   check and print only; nothing is written (the sector's files, the run's ledger)
   --adopt     replace the current basis even if the new one is not better
   A basis from a file replaces the current one only when its status is better (eps-form > eps-polynomial >
   eps-polynomial (dlog search incomplete) > failed), or, between two eps-polynomial bases of the same status,
   when its spread of powers of eps is smaller, or, on a non-dlog sector, the same with an undotted element where every
   element of the current one is dotted (the all-dot tie-breaker), or, between two eps-form bases, when fewer of its
   elements are not eps-pure (then when more are); or with --adopt. Every check that is not a dry run is
   recorded in attempts.m, adopted or not. *)
Get[FileNameJoin[{ParentDirectory[DirectoryName[$InputFileName]], "lib", "MaximalCutBasis.wl"}]];

Module[{args, dir, setup, fam, sec, opt, opts, flag, file, fromFile, raw, entries, basis, old, oldDefs, cd, reps, pts, chk, finalBasis,
    cands, status, adopt, flags, rec, what, user, rungKey, cite, verdict, tie, declared, pcands, newPurity, newDesc},
  args = Rest[$ScriptCommandLine];
  If[args === {}, Print["usage: check_basis.wls <sector folder> [basis file] [--dry-run] [--adopt] [--rung n | --tie-breaker reason] [--provenance text] [--reference text ... [--used text]] [--tool name ...]"]; CoreVerdict["check_basis", "usage"]];
  dir = ExpandFileName[First[args]];
  setup = MCBRunSetup[dir];
  If[setup === $Failed, CoreVerdict["check_basis", "usage", <|"message" -> "no run found for " <> First[args]|>]];
  fam = setup["fam"];
  sec = SectorFromName[FileNameTake[dir]];
  MCBResetToolsUsed[];
  opt[name_, def_] := With[{p = Position[args, name]}, If[p === {} || p[[1, 1]] == Length[args], def, args[[p[[1, 1]] + 1]]]];
  (* every value of an option that may be repeated (--reference) *)
  opts[name_] := Table[args[[p + 1]], {p, Select[Flatten[Position[args, name]], # < Length[args] &]}];
  flag[name_] := MemberQ[args, name];
  (* the tools run by hand are names of the registry; papers need a reference and a use *)
  declared = MCBKnownTools[opts["--tool"]];
  If[declared === $Failed, Print["--tool takes a name of the registry of tools and methods: ", StringRiffle[Keys[$MCBTools], ", "]];
    CoreVerdict["check_basis", "usage", <|"message" -> "unknown --tool: " <> StringRiffle[Select[opts["--tool"], CoreToolKey[#] === $Failed &], ", "]|>]];
  If[AnyTrue[Join[opts["--reference"], If[flag["--used"], {opt["--used", ""]}, {}]], StringTrim[#] === "" &],
    CoreVerdict["check_basis", "usage", <|"message" -> "an empty --reference or --used"|>]];
  (* an argument that is neither an option nor an option's value is the basis file: when it is no file, stop, instead
     of checking masters.m under its name *)
  With[{bad = SelectFirst[Range[2, Length[args]], ! StringStartsQ[args[[#]], "--"] &&
        ! MemberQ[{"--provenance", "--rung", "--used", "--tie-breaker", "--reference", "--tool"}, args[[# - 1]]] &&
        (! FileExistsQ[args[[#]]] || DirectoryQ[args[[#]]]) &, None]},
    If[bad =!= None, Print["basis file not found: ", args[[bad]]];
      CoreVerdict["check_basis", "usage", <|"message" -> "basis file not found: " <> args[[bad]]|>]]];
  (* what the check uses is credited to the sector; a dry run writes nothing, credits included *)
  If[flag["--dry-run"], CoreCitationContext[None], CoreCitationContext[dir, SectorName[sec], "check_basis"]];
  file = SelectFirst[Rest[args], ! StringStartsQ[#, "--"] && FileExistsQ[#] && ! DirectoryQ[#] &&
     ! MemberQ[Join[{opt["--provenance", ""], opt["--rung", ""], opt["--used", ""], opt["--tie-breaker", ""]}, opts["--reference"], opts["--tool"]], #] &, None];
  fromFile = file =!= None;
  If[! fromFile, file = FileNameJoin[{dir, "masters.m"}]];
  raw = Get[file];
  If[! ListQ[raw], Print[file, " does not contain a list"]; CoreVerdict["check_basis", "usage", <|"message" -> file <> " does not contain a list"|>]];
  old = MCBReadBasis[dir];
  oldDefs = Lookup[#, "definition", None] & /@ Lookup[old, "masters", {}];
  (* elements, labels and provenance: from the file, else from the current basis.m when the definition matches *)
  entries = Table[Which[
      AssociationQ[e], <|"definition" -> e["definition"], "label" -> Lookup[e, "label", None], "provenance" -> Lookup[e, "provenance", None]|>,
      MatchQ[e, _Rule], <|"definition" -> e[[1]], "label" -> ToString[e[[2]]], "provenance" -> None|>,
      True, <|"definition" -> e, "label" -> None, "provenance" -> None|>], {e, raw}];
  Do[With[{pos = FirstPosition[oldDefs, d_ /; MCBEqualAtPointsQ[d, entries[[i]]["definition"]], None, {1}]},
      If[pos =!= None,
        If[entries[[i]]["label"] === None, entries[[i, "label"]] = Lookup[old["masters"][[First[pos]]], "label", ""]];
        If[entries[[i]]["provenance"] === None, entries[[i, "provenance"]] = Lookup[old["masters"][[First[pos]]], "provenance", None]]]],
    {i, Length[entries]}];
  (* an element the current basis.m has judged keeps that verdict (MCBKeptPurity): the pass judged it in the
     representation it was built in, which a re-check does not know, and one built eps-pure need not show it in its
     integrand alone *)
  entries = MapThread[Join, {entries, MCBKeptPurity[old, entries[[All, "definition"]]]}];
  tie = opt["--tie-breaker", None];
  entries = Table[Join[e, <|"label" -> Replace[e["label"], None -> ""], "provenance" -> Replace[e["provenance"],
      None -> opt["--provenance", If[StringQ[tie], "agent: tie-breaker (" <> tie <> ")", "agent"]]]|>], {e, entries}];
  basis = entries[[All, "definition"]];
  reps = Replace[Quiet@Check[MCBRepresentations[fam, sec, <|"TimeLimit" -> setup["run"]["TimeLimits"]["Baikov"]|>], {}], Except[_List] -> {}];
  cd = If[reps === {}, Missing[], First[reps]];
  (* the points of the current basis, else those of run.wl, else the seed's *)
  pts = Which[ListQ[Lookup[old, "points", None]] && old["points"] =!= {}, old["points"],
    ListQ[setup["run"]["Points"]], setup["run"]["Points"], True, MCBPoints[fam, 2, setup["run"]["Seed"]]];
  chk = MCBCheckBasis[fam, sec, basis, FileNameJoin[{dir, "kira", "check"}], <|"Points" -> pts|>];
  Print["check: ", chk["status"], "  ", Lookup[chk, "message", ""]];
  Scan[Print["  ", #["Name"], ": ", Which[#["Pass"] === True, "pass", #["Pass"] === False, "FAIL", True, "not checked"], " (", #["Detail"], ")"] &,
    Lookup[chk, "checks", {}]];
  MCBPrintDE[chk];
  (* a check that did not run is no verdict on the basis: when Kira failed, or a plain re-check finds the Kira check
     skipped, nothing is written, so that a good record is not replaced by "failed" *)
  If[StringStartsQ[Lookup[chk, "message", ""], "Kira failed"] || (! fromFile && chk["status"] === "skipped by user"),
    Print["the check did not run: nothing is written"];
    CoreVerdict["check_basis", "error", <|"sector" -> FileNameTake[dir],
      "message" -> "the check did not run: " <> Lookup[chk, "message", "the Kira check is skipped (run.wl \"Skip\")"]|>]];
  (* the tools run by hand, once the basis they gave was read and checked *)
  If[! flag["--dry-run"] && declared =!= {}, CoreRecordTool[dir, declared, "declared", "Sector" -> SectorName[sec]]];
  status = MCBStatusFor[chk, reps, Lookup[old, "classification", None]];
  (* the purity of an eps-form basis's elements (MCBCandidatePurity) decides between two eps-form bases, and goes to the
     record *)
  pcands = If[status =!= "eps-form", None,
    With[{sp = Table[With[{x = MCBSplitMaster[basis[[i]]]}, If[AssociationQ[x], Join[x, KeyTake[entries[[i]], {"pure", "pureDetail"}]], None]], {i, Length[basis]}]},
      If[MemberQ[sp, None], None, MCBCandidatePurity[reps, sp, <|"TimeLimit" -> 120|>]]]];
  newPurity = If[ListQ[pcands], pcands[[All, "pure"]], None];
  If[ListQ[newPurity], Print["eps-pure: ", StringRiffle[MapIndexed["J" <> ToString[First[#2]] <> " " <> Which[TrueQ[#1], "yes", #1 === False, "no", True, "not known"] &, newPurity], ", "]]];
  newDesc = Join[<|"masters" -> basis|>, If[ListQ[newPurity], <|"purity" -> newPurity|>, <||>]];
  (* a better status, or for two eps-polynomial bases of the same status a smaller spread of powers of eps *)
  (* a tie-breaker replaces an equally good basis, never a better one *)
  (* on a non-dlog sector, between two bases of the same spread, one with an undotted element wins (the all-dot flag) *)
  (* between two eps-form bases, the one with fewer elements that are not eps-pure *)
  adopt = ! fromFile || flag["--adopt"] || MCBBetterBasisQ[status, Lookup[chk, "range", {}], old, newDesc] ||
    (StringQ[tie] && ! MCBBetterBasisQ[Lookup[old, "status", "not run"], Lookup[old, "range", {}],
       Join[newDesc, <|"status" -> status, "range" -> Lookup[chk, "range", {}], "sector" -> sec, "classification" -> Lookup[old, "classification", None]|>],
       <|"masters" -> Lookup[old, "masters", {}]|>]);
  (* without --rung the attempt carries no rung, so it does not hide a rung from the retry hints; a tie-breaker is not a
     rung of the ladder and does not count as one *)
  rungKey = Which[StringQ[tie], <|"rung" -> "tie-breaker", "reason" -> tie|>,
    opt["--rung", None] === None, <||>, True, <|"rung" -> ToExpression[opt["--rung", None]]|>];
  (* pass: the basis checked here is usable (eps-form or eps-polynomial); the JSON says whether it replaced the current one *)
  verdict[what_, adopted_] := CoreVerdict["check_basis", If[MemberQ[{"eps-form", "eps-polynomial"}, status], "pass", "fail"],
    <|"sector" -> FileNameTake[dir], "status" -> status, "range" -> Lookup[chk, "range", Missing[]], "k" -> Lookup[chk, "k", Missing[]],
      "adopted" -> adopted, "action" -> what, "message" -> Lookup[chk, "message", ""], "checks" -> (KeyTake[#, {"Name", "Pass", "Detail"}] & /@ Lookup[chk, "checks", {}])|>];
  what = "check_basis.wls " <> FileNameTake[file] <> " (" <> StringRiffle[DeleteDuplicates[entries[[All, "provenance"]]], ", "] <> ")" <>
    If[StringQ[tie], "; tie-breaker: " <> tie, ""];
  (* the papers the basis comes from go to the run's ledger, adopted or not: they were used either way. Each entry says
     whether the basis was adopted, and which basis it is (its key: a later basis of the sector makes it consulted) *)
  cite[result_, outcome_, key_] := With[{r = Table[MCBRecordLiterature[dir, Join[rungKey, <|"reference" -> ref,
       "used" -> opt["--used", "the basis in " <> FileNameTake[file] <> " (" <> StringRiffle[DeleteDuplicates[entries[[All, "provenance"]]], ", "] <> ")"],
       "result" -> result, "outcome" -> outcome, "basisKey" -> key|>]], {ref, opts["--reference"]}]},
    If[MemberQ[r, $Failed], Print["a --reference could not be recorded (the message above says why)"]]];
  (* eps-form up to eps^k: the normalised basis is what gets written *)
  finalBasis = If[chk["status"] === "eps-form", MapThread[eps^#2 #1 &, {basis, chk["k"]}], basis];
  If[flag["--dry-run"],
    Print["dry run: nothing written. ", If[adopt, "This basis would replace the current one.",
      "The current basis (" <> Lookup[old, "status", "not run"] <> ") would be kept; --adopt replaces it anyway."]];
    verdict["dry run", False]];
  If[! adopt,
    MCBAppendAttempt[dir, Join[rungKey, <|"what" -> what,
       "outcome" -> status <> " (not adopted: the current basis, " <> Lookup[old, "status", "?"] <> ", is as good or better)"|>]];
    (* the same basis as the current one, however it is written (a re-check from a file): its papers are behind the
       final result, stamped with the key the reader computes from basis.m *)
    With[{sk = MCBCheckedBasisKey[finalBasis, old]}, If[First[sk],
      cite["adopted", status <> "; the same basis as the current one", Last[sk]],
      cite["not adopted", status <> "; the current basis (" <> Lookup[old, "status", "?"] <> ") is as good or better", Last[sk]]]];
    MCBBasisHTML[dir, fam];   (* the page shows the new attempt and the papers *)
    Print["not adopted: the current basis (", Lookup[old, "status", "?"], ") is as good or better; use --adopt to replace it"];
    verdict["not adopted", False]];
  cands = MapThread[If[AssociationQ[MCBSplitMaster[#1]], Join[MCBSplitMaster[#1], <|"label" -> #2["label"], "provenance" -> #2["provenance"]|>,
       KeyTake[#2, {"pure", "pureDetail"}], KeyTake[#3, {"pure", "pureDetail"}]], $Failed] &,
     {finalBasis, entries, If[ListQ[pcands], pcands, ConstantArray[<||>, Length[entries]]]}];
  If[MemberQ[cands, $Failed], Print["a basis element is not of the form Sqrt[R] (rational combination)"];
    cite["not tried", "a basis element is not of the form Sqrt[R] (rational combination): the basis was not checked", Missing["NoBasis"]];
    CoreVerdict["check_basis", "fail", <|"sector" -> FileNameTake[dir], "message" -> "a basis element is not of the form Sqrt[R] (rational combination)"|>]];
  MCBWriteMasters[dir, finalBasis];
  user = Lookup[Lookup[MCBMasterSectors[fam], SectorName[sec], <||>], "masters", {}];
  flags = If[user =!= {} && IntegerQ[Lookup[chk, "nMastersCut", None]] && chk["nMastersCut"] > Length[user],
    {"the maximal cut has " <> ToString[chk["nMastersCut"]] <> " masters, the user list " <> ToString[Length[user]] <> ": a closed DE needs all of them"}, {}];
  MCBAppendAttempt[dir, Join[rungKey, <|"what" -> what, "outcome" -> status|>]];
  (* a basis that did not change (a re-check, or the same basis from a file) keeps its definitions as basis.m has them,
     so that its key, and what is stamped with it, stays *)
  rec = MCBBasisRecord[fam, sec, <|"cd" -> cd, "check" -> chk, "cands" -> cands, "k" -> ConstantArray[0, Length[cands]], "status" -> status, "reps" -> reps,
     "flags" -> flags, "classification" -> Lookup[old, "classification", Missing["NotRun"]],
     "dlogBasisCheck" -> Quiet@TimeConstrained[MCBDlogBasisCheckCandidates[reps, cands], 600, {}],
     "definitions" -> If[MCBSameBasisQ[finalBasis, oldDefs], oldDefs, None]|>];
  If[MCBFlaggedQ[rec], rec["retryHints"] = MCBRetryHints[dir, rec]];
  MCBWriteBasis[dir, rec];
  (* the key of the basis.m just written, as the reader of the ledger compares it *)
  cite["adopted", status, CoreBasisKey[MCBReadBasis[dir]]];
  MCBBasisHTML[dir, fam];
  (* AnalysisMasters.m must describe the basis in masters.m: an unedited script is written again for the adopted basis;
     an edited one is left alone, and says when it runs that masters.m has changed *)
  If[fromFile,
    MCBWriteAnalysisScript[fam, sec, dir, <|"FamilyFile" -> setup["run"]["Family"], "PathsFile" -> setup["paths"], "Seed" -> setup["run"]["Seed"],
      "Route" -> If[AssociationQ[cd], MCBRouteFor[cd], "dlog"], "Steps" -> {}, "Basis" -> finalBasis, "Written" -> finalBasis,
      "Labels" -> entries[[All, "label"]], "Provenance" -> entries[[All, "provenance"]], "Rung" -> Lookup[rungKey, "rung", 4],
      "CandNote" -> "No candidate search: the basis in section 6 was adopted by check_basis.wls.",
      "Note" -> "check_basis.wls adopted this basis from " <> FileNameTake[file] <> " (" <> StringRiffle[DeleteDuplicates[entries[[All, "provenance"]]], ", "] <>
        ") on " <> DateString[{"Year", "-", "Month", "-", "Day"}] <> "; this file checks it again.", "Overwrite" -> "IfUnedited"|>]];
  Print["adopted: ", status, If[fromFile, " (from " <> FileNameTake[file] <> ")", ""]];
  verdict["adopted", True]
];
