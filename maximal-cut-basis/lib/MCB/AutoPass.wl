(* ::Package:: *)

(* ::Title:: *)
(*MaximalCutBasis`AutoPass`: the optional automatic first pass (rung 1 of the ladder)*)


(* ::Text:: *)
(*For one sector: representations by score, the route each geometry calls for (dlog, curve, single*)
(*integrals), the recount of the masters on the cut, Kira reductions of the candidates, the basis search,*)
(*and one retry with larger pools, 3-term subsets and extra-ISP / standard representations.*)
(*It never runs the literature step or the d0 shift: those are agent rungs (escalation.md).*)


BeginPackage["MaximalCutBasis`AutoPass`", {"MaximalCutBasis`", "SkillCore`Tools`", "SkillCore`Records`", "SkillCore`Pages`", "SkillCore`Citations`", "MaximalCutBasis`Family`",
   "MaximalCutBasis`Sectors`", "MaximalCutBasis`Rules`", "MaximalCutBasis`Derivatives`", "MaximalCutBasis`Kira`", "MaximalCutBasis`Baikov`",
   "MaximalCutBasis`CutIntegrands`", "MaximalCutBasis`LeadingSingularities`", "MaximalCutBasis`Curves`",
   "MaximalCutBasis`DECheck`", "MaximalCutBasis`Candidates`", "MaximalCutBasis`Draw`", "MaximalCutBasis`SectorMaps`", "MaximalCutBasis`Reports`",
   "MaximalCutBasis`PicardFuchs`"}];

MCBAutoPass::usage = "MCBAutoPass[fam, sector, dir, opts] runs rung 1 for one sector and writes basis.m, masters.m, attempts.m, basis.html (and AnalysisMasters.m if absent). Returns the basis.m record. opts[\"budget\"] (seconds, Infinity by default) bounds the candidate searches: each one gets at most the time left, and when the budget is used up the remaining representations and the retry are skipped, the best result so far is kept and the sector is flagged. The tools it uses are credited to the sector in the run's ledger (citation context: the sector, step \"first pass\"; this kernel's marks start empty), and a basis mapped from a repeated geometry brings the credits of the sector it came from, for that basis (MCBBasisRecord).";
MCBAutoPassOptions::usage = "MCBAutoPassOptions[setup] are the options of MCBAutoPass for a run (setup from MCBRunSetup): run.wl \"AutoPass\" plus the time limits \"LS\" (tlim), \"Sector\" (budget) and \"Baikov\", the seed, the points and the file paths.";
MCBRouteFor::usage = "MCBRouteFor[cd] is \"dlog\", \"curve\" or \"single\" depending on the geometry.";
MCBCandidatesFor::usage = "MCBCandidatesFor[fam, sector, cd, opts] calls the candidate route of the geometry.";
MCBStatusFor::usage = "MCBStatusFor[check, reps, classification] maps a DE verdict and the geometry of the cut to eps-form, eps-polynomial, eps-polynomial (dlog search incomplete) or failed. The Picard-Fuchs classification (basis.m \"classification\", MCBPicardFuchs) decides when it has a label: polylog or polylog (nested root) never allows a final eps-polynomial, elliptic, genus-g, K3, CY_n or non-polylog (order k) always does. Otherwise (no classification, not computed, unresolved) the representations reps (MCBRepresentations; or one representation cd) decide: non-dlog when some representation shows a curve of genus >= 1, or none is dlog-compatible.";
MCBWriteAnalysisScript::usage = "MCBWriteAnalysisScript[fam, sector, dir, <|\"FamilyFile\", \"PathsFile\", \"RepIndex\", \"Route\", \"Steps\", \"Basis\", \"Written\", \"Rung\", \"Note\", \"Overwrite\"|>] writes a filled AnalysisMasters.m for the sector. \"Steps\" are the candidate steps it replays (MCBReplayCandidates; default: the route of the chosen representation), \"Basis\" Automatic (the search result) or a list, \"Written\" the basis it is written for (default: the current masters.m), which the script compares with when it runs. With \"Overwrite\" -> Automatic (the default) an existing script is replaced only if it is still exactly as generated; a script edited by hand is kept and the new version goes to AnalysisMasters.auto.m. \"IfUnedited\" replaces an unedited script and leaves an edited one alone; True always replaces it, False never.";
MCBReplayCandidates::usage = "MCBReplayCandidates[fam, sector, reps, steps, <|\"cd\" -> cd, \"nmi\" -> n, \"dir\" -> sectorDir|>] runs again the steps that built candidates (each candidate of MCBAutoPass carries its \"step\"): <|\"call\" -> \"route\" | \"projected\" | \"strict-target\" | \"purify\" | \"projected-purify\" | \"single\" | \"mapped\", \"rep\" -> {kind, order, isps} or Automatic (cd), \"opts\", \"from\" (the route step whose candidates purify starts from), \"map\" (MCBSectorMap, for mapped)|>. Representations not in reps are built (one more ISP, or the standard one). Returns the candidates, without duplicates.";
MCBSameBasisQ::usage = "MCBSameBasisQ[a, b] is True when two bases (lists of expressions as in masters.m) are the same, element by element.";
MCBCheckedBasisKey::usage = "MCBCheckedBasisKey[basis, old] = {same, key} for a basis bin/check_basis.wls checked (expressions as in masters.m), against the sector's basis.m record old: same is True when it is old's basis, element by element and whatever form it is written in (MCBSameBasisQ), and key is then old's key as the reader computes it from basis.m (CoreBasisKey[old]); otherwise key is that of the record the basis would be written as (Missing[\"NoBasis\"] when an element is not Sqrt[R] K). The papers of the basis are stamped with key.";
MCBPrintCutData::usage = "MCBPrintCutData[cd] prints the representation, cut polynomials, twist split, Gamma prefactor and geometry.";
MCBSectorDir::usage = "MCBSectorDir[runDir, sector] is the folder of a sector.";
MCBReadRun::usage = "MCBReadRun[file] reads run.wl and fills the defaults (reference/formats.md).";
MCBRunSetup::usage = "MCBRunSetup[spec] prepares a run from run.wl, family.wl, a run folder or a sector folder (via run_info.m): loads paths.wl, sets $MCBSkip and the time limits, reads the family, creates the output folder, writes run_info.m and sets the citation context to the whole run (CoreCitationContext). Returns <|\"run\", \"fam\", \"dir\", \"paths\"|>.";
MCBRunSectors::usage = "MCBRunSectors[setup] lists the sectors (0/1 lists) the run covers: run.wl \"Sectors\", else the user's masters, else masters_found.m.";
$MCBRunDefaults::usage = "$MCBRunDefaults are the defaults of run.wl.";

Begin["`Private`"];


MCBSectorDir[runDir_String, s_List] := FileNameJoin[{runDir, SectorName[s]}];

(* a curve found on a boundary (MCBBoundaries) with a bulk in several variables has no one-variable curve to reduce on:
   single integrals there; boundary candidates come from dots on the subloop of that boundary (MCBLoopByLoopReport) *)
MCBRouteFor[cd_Association] := Switch[cd["geometry"]["class"],
   "curve", If[Lookup[cd["geometry"], "bulk", "curve"] === "curve" && cd["geometry"]["nvars"] == 1, "curve", "single"],
   "non-polylog", "single", _, "dlog"];

MCBCandidatesFor[fam_, s_, cd_, opts_] := Switch[MCBRouteFor[cd],
   "curve", MCBCurveCandidates[fam, s, cd, opts],
   "single", MCBSingleCandidates[fam, s, cd, opts],
   _, If[genusZeroCutQ[cd], dlogAndTargets[fam, s, cd, opts], MCBDlogCandidates[fam, s, cd, opts]]];

(* One cut variable and a root of degree at most 2: the dlog forms are known explicitly (dz/y, normalised at
   infinity, and the third-kind forms at the punctures, MCBCurveTargets), and matching pool integrals to them is
   linear algebra. That finds candidates even when the iterated leading singularities time out or come out
   rank-deficient, so both are used; the matching runs first because it is cheap. *)
genusZeroCutQ[cd_Association] := Length[cd["vars"]] == 1 && Exponent[cd["split"]["Pr"], First[cd["vars"]]] <= 2;

dlogAndTargets[fam_, s_, cd_, opts_] := Module[{tc, dl, tl = Lookup[opts, "tlim", 600]},
  tc = TimeConstrained[MCBCurveCandidates[fam, s, cd, opts], tl/4, <|"candidates" -> {}|>];
  dl = TimeConstrained[MCBDlogCandidates[fam, s, cd, opts], 3 tl/4, <|"status" -> "timeout", "candidates" -> {}|>];
  <|"status" -> If[tc["candidates"] === {} && dl["candidates"] === {}, Lookup[dl, "status", "timeout"], "ok"], "route" -> "dlog",
    "npool" -> Lookup[dl, "npool", Lookup[tc, "npool", 0]],
    "candidates" -> DeleteDuplicatesBy[Join[dl["candidates"], tc["candidates"]], {#["K"], #["r2"]} &]|>];

MCBStatusFor[chk_Association, reps_List, cls_ : None] := Module[{st = Lookup[chk, "status", "failed"], nondlog},
  (* the same test as the automatic pass: the curve may show up in another representation than the first *)
  nondlog = reps =!= {} && (AnyTrue[reps, #["geometry"]["class"] === "curve" &] || NoneTrue[reps, MCBDlogGeometryQ]);
  statusOf[st, pfNonDlog[cls, nondlog]]];
MCBStatusFor[chk_Association, cd_, cls_ : None] := statusOf[Lookup[chk, "status", "failed"], pfNonDlog[cls, AssociationQ[cd] && ! MCBDlogGeometryQ[cd]]];
(* the operator decides when it has a label (it describes the masters that exist; a Baikov curve may lie in a direction
   no master uses), the Baikov geometry otherwise *)
pfNonDlog[cls_, baikov_] := With[{l = If[AssociationQ[cls], Lookup[cls, "label", ""], ""]},
  Which[MCBPFNonPolylogQ[l], True, MCBPFPolylogQ[l], False, True, baikov]];
statusOf[st_, nondlog_] := Module[{},
  Which[
    st === "eps-form", "eps-form",
    st === "eps-polynomial" && nondlog, "eps-polynomial",
    st === "eps-polynomial", "eps-polynomial (dlog search incomplete)",
    StringQ[st] && StringContainsQ[st, "skipped"], st,
    True, "failed"]];

MCBPrintCutData[cd_Association] := (
  Print["  ", cd["kind"], " order ", cd["order"], "  ISPs ", cd["isp"], "  -> cut variables ", cd["vars"], "   score ", cd["score"]];
  Print["     cut Baikov polynomials^exponents : ", Thread[{cd["cutpolys"], cd["cutpows"]}]];
  Print["     eps = 0 integrand = kinNorm Rz/Sqrt[Pr]:  kinNorm = ", cd["split"]["kinNorm"], ",  Rz = ", cd["split"]["Rz"], ",  Pr = ", Factor[cd["split"]["Pr"]]];
  Print["     Gamma prefactor, rational part: ", cd["prefRat"]];
  Print["     geometry: ", cd["geometry"]["text"]]);

(* a check-like verdict from a search result, without another Kira run *)
verdictFromSearch[red_, res0_, fam_] := Module[{nx = Length[fam["InvList"]], k, As, rat, res = res0, ef, checks, euler},
  If[! AssociationQ[res] || ! KeyExistsQ[res, "A"], Return[<|"status" -> "failed", "message" -> "no invertible subset of candidates"|>]];
  (* never record an eps-form basis as anything less: test the matrices of the chosen subset exactly once more *)
  If[res["status"] =!= "eps-form",
    ef = Quiet@MCBEpsFactorizedQ[res["A"]];
    If[ListQ[ef] && TrueQ[First[ef]], res = Join[res, <|"status" -> "eps-form", "k" -> ef[[2]], "range" -> {1, 1}|>]]];
  k = If[res["status"] === "eps-form", res["k"], ConstantArray[0, Length[res["sub"]]]];
  (* the same checks as MCBCheckBasis, on the expressions that go to masters.m; a DE that breaks the Euler relation fails *)
  checks = If[KeyExistsQ[res, "cands"], MCBBasisChecks[fam, MapThread[MCBMasterExpression, {res["cands"], k}], res["A"], red[[All, "point"]]], {}];
  euler = SelectFirst[checks, #["Name"] === "euler" &, <|"Pass" -> Missing["NotChecked"]|>];
  If[euler["Pass"] === False, res["status"] = "failed"];
  As = Take[res["A"], nx];
  (* The search uses each candidate's own split Sqrt[r2] K, but masters.m is written after MCBSplitRoot has moved
     the square factors of r2 into K (K -> rat K). In the rational frame that is a conjugation by rat_i/rat_j at
     the first point; apply it, so that the stored matrices describe exactly the expressions in masters.m. *)
  If[KeyExistsQ[res, "cands"] && Length[res["cands"]] == Length[First[As]],
    rat = (MCBSplitRoot[#["r2"], 1][[2]] /. red[[1]]["point"]) & /@ res["cands"];
    If[AllTrue[rat, NumericQ[#] && # != 0 &],
      As = Table[Table[A[[i, jj]] rat[[i]]/rat[[jj]], {i, Length[rat]}, {jj, Length[rat]}], {A, As}]]];
  <|"status" -> res["status"], "k" -> k, "range" -> Lookup[res, "range", {1, 1}], "points" -> red[[All, "point"]],
    "nMastersCut" -> Length[red[[1]]["masters"]], "cutMasters" -> red[[1]]["masters"], "invariants" -> fam["InvList"],
    "A" -> AssociationThread[fam["InvList"] -> (MCBRescaleEps[#, k] & /@ As)],
    "pattern" -> Map[MCBEpsProfile, MCBRescaleEps[#, k] & /@ As, {3}], "checks" -> checks,
    "message" -> Which[euler["Pass"] === False, "the maximal-cut DE breaks the Euler relation of homogeneous integrals: " <> euler["Detail"] <>
         " (a candidate mixes mass dimensions, or the reductions or derivatives are wrong: run validate_family.wls --scaling)",
       res["status"] === "eps-form", "eps-factorised at every point and invariant",
       res["status"] === "eps-polynomial", "Laurent polynomial in eps, powers " <> ToString[res["range"]], True, "rational eps dependence"]|>];

(* every candidate of the pass carries the step that built it, so that AnalysisMasters.m can run exactly those steps
   again (MCBReplayCandidates) instead of writing the basis down *)
repKey[cd_Association] := {cd["kind"], cd["order"], cd["isp"]};
stepOpts[o_Association] := KeyDrop[o, {"FamilyFile", "PathsFile", "Points", "Seed", "budget", "BaikovTimeLimit", "Standard"}];
stepTag[cands_List, step_Association] := (Append[#, "step" -> step] & /@ cands);

(* compared at random points (MCBEqualAtPointsQ): elements with large coefficients are never put over a common denominator *)
MCBSameBasisQ[a_List, b_List] := Length[a] == Length[b] && AllTrue[MapThread[MCBEqualAtPointsQ, {a, b}], TrueQ];
MCBSameBasisQ[_, _] := False;

(* a record rebuilds its elements (MCBMasterExpression of the split ones), and the first pass writes eps^k outside a
   sum that the rebuilt element has inside: the same basis can have two keys, so "the same basis" is decided on values *)
MCBCheckedBasisKey[b_List, old_Association] := With[{defs = Lookup[#, "definition", None] & /@ Select[Flatten[{Lookup[old, "masters", {}]}], AssociationQ]},
  If[MCBSameBasisQ[b, defs] && StringQ[CoreBasisKey[old]], {True, CoreBasisKey[old]},
    {False, With[{c = MCBSplitMaster /@ b}, If[MemberQ[c, $Failed], Missing["NoBasis"], CoreBasisKey[MCBMasterExpression[#, 0] & /@ c]]]}]];

MCBReplayCandidates[fam_Association, s_List, reps_List, steps_List, o_Association : <||>] := Module[{ext = None, std = None, findRep, run, mine, out},
  findRep[Automatic] := Lookup[o, "cd", First[reps, Missing[]]];
  findRep[key_] := Module[{pick, c},
    pick[l_] := SelectFirst[l, repKey[#] === key &, Missing[]];
    c = pick[reps]; If[! MissingQ[c], Return[c, Module]];
    If[ext === None, ext = MCBRepresentations[fam, s, <|"Extra" -> 1, "Standard" -> False|>]];
    c = pick[ext]; If[! MissingQ[c], Return[c, Module]];
    If[std === None, std = Select[MCBRepresentations[fam, s, <|"Standard" -> True|>], #["kind"] === "standard" &]];
    pick[std]];
  (* the options of a step, with nmi filled in when it was left Automatic (new_sector.wls) *)
  mine[st_] := With[{op = Lookup[st, "opts", <||>]}, If[Lookup[op, "nmi", Automatic] === Automatic, Join[op, <|"nmi" -> Lookup[o, "nmi", 1]|>], op]];
  run[st_] := run[st] = Module[{cd = If[KeyExistsQ[st, "rep"], findRep[st["rep"]], Missing[]], op = mine[st], base, ref},
    If[KeyExistsQ[st, "rep"] && MissingQ[cd], Print["  replay: representation ", st["rep"], " not found"]; Return[{}, Module]];
    Switch[st["call"],
      "route", Lookup[MCBCandidatesFor[fam, s, cd, op], "candidates", {}],
      "projected", Replace[MCBProjectedCandidates[fam, s, cd, op], Except[_List] -> {}],
      "strict-target", Lookup[Replace[MCBStrictTargetCandidates[fam, s, cd, op], Except[_Association] -> <||>], "candidates", {}],
      "purify" | "projected-purify",
        base = Select[run[st["from"]], Lookup[#, "rep", None] === {cd["order"], cd["isp"], cd["kind"]} &];
        If[base === {}, {}, Replace[If[st["call"] === "purify", MCBPurifyCandidates[fam, s, cd, base, op], MCBProjectedPurifyCandidates[fam, s, cd, base, op]],
          Except[_List] -> {}]],
      "single", Lookup[MCBSingleCandidates[fam, s, cd, op], "candidates", {}],
      "mapped",
        ref = FileNameJoin[{CoreRunFolder[Lookup[o, "dir", Directory[]]], st["from"]}];
        With[{mb = MCBMapBasis[fam, st["map"], Replace[MCBReadMasters[ref], Except[_List] -> {}]], labs = Lookup[Lookup[MCBReadBasis[ref], "masters", {}], "label", ""]},
          If[! ListQ[mb], Print["  replay: the basis of ", st["from"], " does not map"]; {},
            Table[With[{sp = MCBSplitMaster[mb[[i]]]}, If[AssociationQ[sp], MCBCandidate[fam, s, sp["K"], <|"r2" -> sp["r2"], "priority" -> 1,
                "provenance" -> "mapped from " <> st["from"] <> " (repeated geometry)", "label" -> If[i <= Length[labs], labs[[i]], ""]|>], Nothing]],
              {i, Length[mb]}]]],
      _, Print["  replay: unknown step ", st["call"]]; {}]];
  out = Join @@ (stepTag[run[#], #] & /@ steps);
  DeleteDuplicatesBy[out, {#["K"], #["r2"]} &]];

score[res_] := Which[! AssociationQ[res] || ! KeyExistsQ[res, "status"], 1000, res["status"] === "eps-form", -1,
   res["status"] === "eps-polynomial", res["range"][[2]] - res["range"][[1]], res["status"] === "rational", 500, True, 900];
(* {elements not eps-pure, minus the elements eps-pure} of a search result (the candidates' verdicts, MCBCandidatePurity) *)
purityKey[res_] := If[AssociationQ[res] && ListQ[Lookup[res, "cands", None]],
   {Count[res["cands"], c_ /; Lookup[c, "pure", Missing[]] === False], -Count[res["cands"], c_ /; TrueQ[Lookup[c, "pure", Missing[]]]]}, {0, 0}];
impureElements[res_] := If[AssociationQ[res] && ListQ[Lookup[res, "cands", None]],
   Flatten[Position[Lookup[res["cands"], "pure", Missing[]], False]], {}];

MCBAutoPass[fam_Association, s_List, dir_String, opts0_Association : <||>] := Module[{opts = Join[$MCBDefaultOptions, opts0], t0 = AbsoluteTime[],
    km, nmi, reps, reps0, pts, cm, allc = {}, red = $Failed, res = $Failed, rc, attempt = 1, best = $Failed, bestRed = $Failed, bestCd = Missing[], flags = {},
    chk, cands, k, rec, status, cdUsed = Missing[], nondlog, tried, ext = {}, runRep, repRef, p, early, kdir, dlogCheck, budget, left, stopped = False, stop, tag, lsTrouble = {},
    rg, repeated = Missing[], mappedDone = False, routeStep = <||>, scriptSteps, pf = Missing["NotRun"], noRoute = False, better, search, purity = <||>, withPurity, pkey,
    done, impureNote, noted = False, recheck, rechecked = {}},
  If[! DirectoryQ[dir], CreateDirectory[dir, CreateIntermediateDirectories -> True]];
  (* the time budget of the candidate searches: each search gets at most the time that is left *)
  budget = Lookup[opts, "budget", Infinity];
  left[] := budget - (AbsoluteTime[] - t0);
  stop[what_] := (If[! stopped, Print["  time budget of ", budget, " s used up: ", what, " skipped"]]; stopped = True);
  tag[] := If[stopped, " (time budget reached)", ""];
  (* a pass that stops before it has candidates (no representation, Kira failing, no master) keeps a basis the sector
     already has; otherwise it writes its record and removes a masters.m that no longer matches it *)
  early[r_] := Module[{old = MCBReadBasis[dir]},
    If[MemberQ[{"eps-form", "eps-polynomial", "eps-polynomial (dlog search incomplete)"}, Lookup[old, "status", "not run"]],
      MCBAppendAttempt[dir, <|"rung" -> 1, "what" -> "automatic pass", "outcome" -> "stopped early (" <> StringRiffle[ToString /@ Lookup[r, "flags", {}], "; "] <>
         "); the existing basis is kept", "time" -> Round[AbsoluteTime[] - t0]|>];
      Print["  the automatic pass stopped early; the existing basis (", old["status"], ") is kept"]; old,
      Quiet@DeleteFile[FileNameJoin[{dir, "masters.m"}]]; MCBWriteBasis[dir, r]; r]];
  (* this kernel's marks start empty (a use it made before, without a context, is not this sector's), and what the pass
     uses is credited to the sector in the run's ledger *)
  MCBResetToolsUsed[];
  CoreCitationContext[dir, SectorName[s], "first pass"];
  MCBClearCutCache[];    (* cut integrands of other sectors are not needed again *)
  kdir = FileNameJoin[{dir, "kira"}];
  km = Lookup[Lookup[MCBMasterSectors[fam], SectorName[s], <||>], "masters", {}];
  Print["======================================================================"];
  Print[fam["NameString"], " sector ", SectorName[s], "   (Kira id ", SectorID[s], ")"];
  Print["  propagators : ", StringRiffle[Table["D" <> ToString[i] <> " = " <> MCBPropLabel[fam, i], {i, PropPos[s]}], ", "]];
  Print["  user masters: ", km];
  Print["======================================================================"];
  If[MCBSkippedQ["candidates"],
    rec = MCBBasisRecord[fam, s, <|"status" -> "skipped by user", "flags" -> {"candidates skipped by user"}|>];
    Return[early[rec]]];
  (* representations *)
  reps = If[MCBSkippedQ["baikov"], {}, MCBRepresentations[fam, s, <|"TimeLimit" -> Lookup[opts, "BaikovTimeLimit", 120], "Standard" -> opts["Standard"]|>]];
  reps0 = reps;   (* reps is narrowed for the retry; the status and the generated script refer to the full list *)
  Print["\n-- Baikov representations on the maximal cut (sorted by score) --"];
  Scan[MCBPrintCutData, reps];
  MCBAppendAttempt[dir, <|"rung" -> 1, "what" -> "Baikov representations", "outcome" -> ToString[Length[reps]] <> " found", "time" -> Round[AbsoluteTime[] - t0]|>];
  If[reps === {},
    rec = MCBBasisRecord[fam, s, <|"status" -> "failed", "flags" -> {"no Baikov representation (BaikovPackage missing, or every representation degenerate)"}|>];
    Return[early[rec]]];
  (* non-dlog when a representation shows a curve of genus >= 1 (a property of the cut), or when none is
     dlog-compatible; a root of high degree in every variable of one representation decides nothing *)
  nondlog = AnyTrue[reps, #["geometry"]["class"] === "curve" &] || NoneTrue[reps, MCBDlogGeometryQ];
  (* masters on the cut *)
  pts = Lookup[opts, "Points", MCBPoints[fam, 2, Lookup[opts, "Seed", 1]]];
  cm = MCBCutMasters[fam, s, FileNameJoin[{kdir, "count"}], First[pts]];
  If[cm["masters"] === $Failed,
    rec = MCBBasisRecord[fam, s, <|"cd" -> First[reps], "status" -> "failed", "flags" -> {"Kira failed while counting the masters on the cut"}|>];
    Return[early[rec]]];
  nmi = cm["n"];
  Print["\n-- masters on the maximal cut (Kira recount): ", nmi, " ", cm["masters"], " --"];
  If[km =!= {} && nmi != Length[km],
    AppendTo[flags, "the maximal cut has " <> ToString[nmi] <> " masters, the user list " <> ToString[Length[km]] <> ": a closed DE needs all of them"];
    Print["   NOTE: ", Last[flags]]];
  If[nmi == 0,
    rec = MCBBasisRecord[fam, s, <|"cd" -> First[reps], "status" -> "failed", "flags" -> Append[flags, "no master on the maximal cut (zero or mapped sector)"]|>];
    Return[early[rec]]];
  opts["nmi"] = nmi;
  (* the Picard-Fuchs operator of the cut, on the line through the Kira points: its label steers the searches. Not
     polylogarithmic: only the curve and single-integral routes (the dlog searches cannot succeed), and a final
     eps-polynomial is allowed. Polylogarithmic: an eps-polynomial basis is never final. Otherwise the Baikov
     geometry decides, as before *)
  pf = MCBPicardFuchs[fam, s, <|"Points" -> pts, "Masters" -> cm["masters"], "KiraRules" -> Lookup[cm, "rules", None], "Representations" -> reps,
     "Dir" -> FileNameJoin[{dir, "picard-fuchs"}], "Seed" -> Lookup[opts, "Seed", 1]|>];
  Print["\n-- Picard-Fuchs operator: ", pf["label"], If[IntegerQ[Lookup[pf, "order", None]], " (order " <> ToString[pf["order"]] <> ")", ""],
    If[StringQ[Lookup[pf, "reason", None]], ": " <> pf["reason"], ""], " (", Lookup[pf, "time", "?"], " s) --"];
  MCBAppendAttempt[dir, <|"rung" -> 1, "what" -> "Picard-Fuchs operator (picard-fuchs step)", "outcome" -> pf["label"], "time" -> Round[AbsoluteTime[] - t0]|>];
  Which[
    MCBPFNonPolylogQ[pf["label"]],
      nondlog = True;
      With[{keep = Select[reps, MCBRouteFor[#] =!= "dlog" &]},
        If[keep === {}, noRoute = True; Print["   no representation has a curve or single-integral route: single integrals only"], reps = keep]],
    MCBPFPolylogQ[pf["label"]], nondlog = False];
  (* a result r replaces the best so far when its score is lower; between two eps-form results, when fewer of its
     elements are not eps-pure (then when more are); on a non-dlog sector also at an equal eps-polynomial score when
     every element of the best is dotted and one of r's is not (the all-dot tie-breaker, SKILL.md). Both are defined
     before the first search, the mapped basis of a repeated geometry, and read nondlog when they run *)
  better[r_] := score[r] < score[best] ||
    (score[r] == score[best] == -1 && purityKey[r] =!= purityKey[best] && OrderedQ[{purityKey[r], purityKey[best]}]) ||
    (nondlog && score[r] == score[best] && 0 <= score[r] < 500 && AssociationQ[r] && AssociationQ[best] && KeyExistsQ[r, "cands"] && KeyExistsQ[best, "cands"] &&
     MCBAllDotQ[#["K"] & /@ best["cands"], s] && ! MCBAllDotQ[#["K"] & /@ r["cands"], s]);
  (* the pass is done with an eps-form basis none of whose elements is known not to be eps-pure; while one is, it searches
     on: the other representations, the candidates that are dlog in d dimensions, the larger pools. An element whose
     verdict the purity budget left open is checked again first, once, with the full time: a basis is not done because
     its purity was not known *)
  recheck[] := If[! nondlog && score[best] < 0 && ListQ[Lookup[best, "cands", None]],
    With[{open = Select[Range[Length[best["cands"]]], MissingQ[Lookup[best["cands"][[#]], "pure", Missing[]]] && ! MemberQ[rechecked, pkey[best["cands"][[#]]]] &]},
      If[open =!= {},
        rechecked = Join[rechecked, pkey /@ best["cands"][[open]]];
        With[{got = MCBCandidatePurity[Join[reps0, ext], KeyDrop[#, {"pure", "pureDetail"}] & /@ best["cands"][[open]], <|"TimeLimit" -> 120|>]},
          Do[best[["cands", open[[i]]]] = got[[i]]; purity[pkey[got[[i]]]] = KeyTake[got[[i]], {"pure", "pureDetail"}], {i, Length[open]}]]]]];
  done[] := (recheck[]; score[best] < 0 && First[purityKey[best]] == 0);
  impureNote[] := If[score[best] < 0 && ! done[] && ! noted, noted = True;
    With[{what = "eps-form with elements that are not eps-pure (" <> StringRiffle[("J" <> ToString[#]) & /@ impureElements[best], ", "] <> "): " <>
        If[stopped || left[] < 20, "the time budget is used up, so the pass keeps it", "the pass searches on"]},
      Print["\n-- the ", what, " --"];
      MCBAppendAttempt[dir, <|"rung" -> 1, "what" -> "eps-pure elements", "outcome" -> what, "time" -> Round[AbsoluteTime[] - t0]|>]]];
  (* every candidate gets its purity verdict before it is searched (MCBCandidatePurity, in every representation the pass
     has built), so that the search puts the eps-pure ones first; each candidate is checked once (a strict twin of a
     candidate, or the same one built in another representation, is another candidate). Not on a non-dlog sector, where
     purity decides nothing: the record judges the elements of its basis *)
  pkey[c_] := {c["K"], c["r2"], TrueQ[Lookup[c, "strict", False]], Lookup[c, "rep", None]};
  withPurity[cs_] := If[nondlog, cs, Module[{todo = Select[cs, ! KeyExistsQ[purity, pkey[#]] &], got},
    If[todo =!= {},
      got = MCBCandidatePurity[Join[reps0, ext], todo, <|"Budget" -> Max[10, Min[120, left[]/4]]|>];
      Scan[(purity[pkey[#]] = KeyTake[#, {"pure", "pureDetail"}]) &, got];
      Print["     purity of ", Length[todo], " new candidate(s): ", Count[got, c_ /; TrueQ[c["pure"]]], " eps-pure, ",
        Count[got, c_ /; c["pure"] === False], " not, ", Count[got, c_ /; MissingQ[c["pure"]]], " not known"]];
    Join[#, purity[pkey[#]]] & /@ cs]];
  search[rd_, cs_] := MCBSearchBasis[rd, withPurity[cs], nmi, <|"NonDlog" -> nondlog, "Sector" -> s|>];
  (* repeated geometry: a sector of this run that has a basis and is the same integrals at mapped kinematics
     (MCBRepeatedGeometry). Its basis, mapped, is searched first; when that gives eps-form with no element known not to
     be eps-pure, or the eps-polynomial basis of a sector proven non-dlog, the candidate searches are skipped *)
  rg = Quiet@Check[MCBRepeatedGeometry[fam, s, CoreRunFolder[dir]], {}];
  If[rg =!= {},
    Module[{use = SelectFirst[rg, ListQ[#["basis"]] &, None], ref, labs, mc, mred, mres},
      Print["\n-- repeated geometry: the same integrals as ", StringRiffle[(#["from"] <> " (" <> #["status"] <> ")") & /@ rg, ", "], " at mapped invariants --"];
      ref = If[use === None, First[rg], use];
      repeated = <|"sameAs" -> ref["from"], "status" -> ref["status"], "lines" -> ref["map"]["lines"], "invariants" -> ref["map"]["invariants"]|>;
      Print["   lines ", ref["map"]["lines"], ", invariants ", ref["map"]["invariants"]];
      If[use === None,
        repeated["mapped"] = False; repeated["note"] = First[First[rg]["basis"]];
        Print["   its basis does not map: ", repeated["note"]],
        labs = Lookup[Lookup[MCBReadBasis[FileNameJoin[{CoreRunFolder[dir], use["from"]}]], "masters", {}], "label", ""];
        mc = Table[With[{sp = MCBSplitMaster[use["basis"][[i]]]},
            If[AssociationQ[sp], MCBCandidate[fam, s, sp["K"], <|"r2" -> sp["r2"], "priority" -> 1, "provenance" -> "mapped from " <> use["from"] <> " (repeated geometry)",
               "label" -> If[i <= Length[labs] && StringQ[labs[[i]]] && labs[[i]] =!= "", labs[[i]], "mapped J" <> ToString[i]]|>], Nothing]],
          {i, Length[use["basis"]]}];
        mc = stepTag[mc, <|"call" -> "mapped", "from" -> use["from"], "map" -> use["map"]|>];
        mred = If[Length[mc] == nmi, MCBReduceCandidates[fam, s, mc, kdir, pts], $Failed];
        mres = If[mred === $Failed, $Failed, search[mred, mc]];
        repeated["mapped"] = True;
        repeated["outcome"] = If[AssociationQ[mres], mres["status"] <> If[KeyExistsQ[mres, "range"], " " <> ToString[mres["range"]], ""], "not a basis on this cut"];
        Print["   its basis, mapped: ", repeated["outcome"]];
        If[better[mres], best = mres; bestRed = mred; bestCd = First[reps]; allc = mc];
        mappedDone = done[] || (use["status"] === "eps-polynomial" && nondlog && AssociationQ[best] && best["status"] === "eps-polynomial");
        MCBAppendAttempt[dir, <|"rung" -> 1, "what" -> "basis of " <> use["from"] <> " mapped (repeated geometry)",
          "outcome" -> repeated["outcome"] <> If[mappedDone, "; the candidate searches are skipped", ""], "time" -> Round[AbsoluteTime[] - t0]|>]]]];
  (* candidates and search *)
  runRep[cd_, o_] := Module[{r, tl = Min[o["tlim"], left[]]},
    If[tl < 20, stop["the remaining candidate searches are"]; Return[$Failed, Module]];
    r = TimeConstrained[MCBCandidatesFor[fam, s, cd, Join[o, <|"tlim" -> tl|>]], tl, <|"status" -> "timeout", "candidates" -> {}|>];
    If[MemberQ[{"timeout", "LS-failed"}, r["status"]], AppendTo[lsTrouble, {cd["kind"], cd["order"], cd["isp"]}]];
    Print["  rep ", cd["kind"], cd["order"], cd["isp"], " route ", MCBRouteFor[cd], ": ", r["status"], ", ", Length[r["candidates"]], " candidates",
      If[KeyExistsQ[r, "npool"], " (pool " <> ToString[r["npool"]] <> ")", ""]];
    If[r["status"] =!= "ok" || r["candidates"] === {}, Return[$Failed, Module]];
    With[{st = <|"call" -> "route", "rep" -> repKey[cd], "opts" -> stepOpts[Join[o, <|"tlim" -> tl|>]]|>},
      If[attempt == 1, routeStep[repKey[cd]] = st];
      allc = DeleteDuplicatesBy[Join[allc, stepTag[r["candidates"], st]], {#["K"], #["r2"]} &]];
    red = MCBReduceCandidates[fam, s, allc, kdir, pts];
    If[red === $Failed, Print["     Kira failed"]; Return[$Failed, Module]];
    res = search[red, allc];
    Print["     -> ", If[res === $Failed, "no invertible subset", res["status"] <> If[KeyExistsQ[res, "range"], " " <> ToString[res["range"]], ""]]];
    If[better[res], best = res; bestRed = red; bestCd = cd];
    res];
  Label[retry];
  If[! mappedDone && ! noRoute,
    Print["\n-- candidates, attempt ", attempt, " (nd = ", opts["nd"], ", nt = ", opts["nt"], ", w = ", opts["w"], ", subsets <= ", opts["maxsize"], ") --"];
    Do[
      runRep[cd, opts];
      If[done[] || stopped, Break[]];
      If[nondlog && AssociationQ[best] && best["status"] === "eps-polynomial" && best["range"][[2]] - best["range"][[1]] <= 1, Break[]],
      {cd, Take[reps, UpTo[opts["nreps"]]]}];
    MCBAppendAttempt[dir, <|"rung" -> 1, "what" -> "auto pass attempt " <> ToString[attempt] <> " (nd " <> ToString[opts["nd"]] <> ", nt " <> ToString[opts["nt"]] <> ", w " <> ToString[opts["w"]] <> ")",
       "outcome" -> If[AssociationQ[best], best["status"], "nothing"] <> tag[], "time" -> Round[AbsoluteTime[] - t0]|>]];
  impureNote[];
  (* not eps-form yet, or eps-form with an element that is not eps-pure: complete the dlog candidates with single pool
     integrals of the best representation and search again. It costs one more reduction and no leading singularities.
     With too few independent dlog candidates (rank-deficient), a basis that mixes them with simple integrals is often
     already in eps-form; otherwise it is at least the best eps-polynomial basis at hand. *)
  If[attempt == 1 && ! nondlog && ! done[] && ! stopped && left[] >= 20,
    Module[{sc = stepTag[MCBSingleCandidates[fam, s, First[reps], opts]["candidates"], <|"call" -> "single", "rep" -> repKey[First[reps]], "opts" -> stepOpts[opts]|>],
        all2, red2, res2, c1, dd = {}, tcap},
      (* candidates that are dlog in d dimensions (coefficients rational in eps): on a genus-0 one-variable cut,
         the dlog targets written through pool integrals modulo total derivatives, and exact matching; and the
         dlog candidates found so far made exact in eps (modulo total derivatives, and exactly), each in its own
         representation *)
      tcap = Max[10, Min[180, left[]/3]];
      c1 = SelectFirst[reps, genusZeroCutQ, Missing[]];
      If[! MissingQ[c1],
        dd = Join[stepTag[Replace[TimeConstrained[MCBProjectedCandidates[fam, s, c1, Join[opts, <|"nmi" -> nmi|>]], tcap, {}], Except[_List] -> {}],
            <|"call" -> "projected", "rep" -> repKey[c1], "opts" -> stepOpts[Join[opts, <|"nmi" -> nmi|>]]|>],
          stepTag[Lookup[Replace[TimeConstrained[MCBStrictTargetCandidates[fam, s, c1, KeyDrop[opts, {"maxsize", "cap", "cap3"}]], tcap, <||>], Except[_Association] -> <||>], "candidates", {}],
            <|"call" -> "strict-target", "rep" -> repKey[c1], "opts" -> stepOpts[KeyDrop[opts, {"maxsize", "cap", "cap3"}]]|>]]];
      Do[With[{mine = Select[allc, Lookup[#, "rep", None] === {cd["order"], cd["isp"], cd["kind"]} &], from = Lookup[routeStep, Key[repKey[cd]], None]},
          If[mine =!= {} && from =!= None, dd = Join[dd,
            stepTag[Replace[TimeConstrained[MCBProjectedPurifyCandidates[fam, s, cd, mine, Join[opts, <|"nmi" -> nmi|>]], tcap, {}], Except[_List] -> {}],
              <|"call" -> "projected-purify", "rep" -> repKey[cd], "from" -> from, "opts" -> stepOpts[Join[opts, <|"nmi" -> nmi|>]]|>],
            stepTag[Replace[TimeConstrained[MCBPurifyCandidates[fam, s, cd, mine, opts], tcap, {}], Except[_List] -> {}],
              <|"call" -> "purify", "rep" -> repKey[cd], "from" -> from, "opts" -> stepOpts[opts]|>]]]],
        {cd, Take[reps, UpTo[opts["nreps"]]]}];
      If[dd =!= {}, Print["\n-- ", Length[dd], " candidate(s) that are dlog in d dimensions --"]];
      all2 = DeleteDuplicatesBy[Join[dd, allc, sc], {#["K"], #["r2"]} &];
      red2 = MCBReduceCandidates[fam, s, all2, kdir, pts];
      res2 = If[red2 === $Failed, $Failed, search[red2, all2]];
      Print["\n-- dlog candidates completed with ", Length[sc], " single integrals: ",
        If[AssociationQ[res2], res2["status"] <> If[KeyExistsQ[res2, "range"], " " <> ToString[res2["range"]], ""], "no invertible subset"], " --"];
      If[better[res2], best = res2; bestRed = red2; bestCd = First[reps]];
      MCBAppendAttempt[dir, <|"rung" -> 1, "what" -> "dlog candidates completed with single integrals",
        "outcome" -> If[AssociationQ[res2], res2["status"], "nothing"], "time" -> Round[AbsoluteTime[] - t0]|>]]];
  (* too few independent candidates: representations with one more ISP *)
  If[attempt == 1 && ! nondlog && ! done[] && AssociationQ[res] && Lookup[res, "status", ""] === "rank-deficient",
    If[left[] < 20, stop["the representations with one more ISP are"];
      MCBAppendAttempt[dir, <|"rung" -> 1, "what" -> "extra-ISP representations", "outcome" -> "skipped: time budget used up", "time" -> Round[AbsoluteTime[] - t0]|>],
      ext = MCBRepresentations[fam, s, <|"Extra" -> 1, "Standard" -> False|>];
      Print["\n-- rank-deficient: ", Length[ext], " representation(s) with one more ISP --"];
      Do[runRep[cd, opts]; If[done[] || stopped, Break[]], {cd, Take[ext, UpTo[4]]}];
      MCBAppendAttempt[dir, <|"rung" -> 1, "what" -> "extra-ISP representations", "outcome" -> If[AssociationQ[best], best["status"], "nothing"] <> tag[], "time" -> Round[AbsoluteTime[] - t0]|>]]];
  If[! done[] && attempt == 1 && ! (nondlog && AssociationQ[best] && best["status"] === "eps-polynomial"),
    If[left[] < 20, stop["the retry with larger pools is"];
      MCBAppendAttempt[dir, <|"rung" -> 1, "what" -> "auto pass attempt 2 (larger pools)", "outcome" -> "skipped: time budget used up", "time" -> Round[AbsoluteTime[] - t0]|>],
      attempt = 2;
      (* a larger pool only helps when the leading singularities could be computed: if they timed out or failed on
         the representation the retry starts from (the best one), keep the cap and raise only nd, nt and w.
         A timeout on another representation (an extra-ISP one, say) says nothing about this one. *)
      opts = Join[opts, <|"nd" -> opts["nd"] + 1, "nt" -> opts["nt"] + 1, "w" -> opts["w"] + 1, "maxsize" -> 3, "enough" -> 60, "nreps" -> 1,
         "maxpool" -> If[MemberQ[lsTrouble, {#["kind"], #["order"], #["isp"]} &[First[reps]]], opts["maxpool"], opts["maxpool"] + {10, 8, 4, 2}]|>];
      (* the standard representation joins the retry, after the best one *)
      reps = DeleteDuplicates[Join[Take[reps, UpTo[1]], Select[reps, #["kind"] === "standard" &]]];
      opts["nreps"] = Length[reps];
      Goto[retry]]];
  (* non-dlog geometry: best eps-polynomial basis among single integrals *)
  If[nondlog && ! (AssociationQ[best] && best["status"] === "eps-polynomial" && best["range"][[2]] - best["range"][[1]] <= 1),
    Module[{sc = MCBSingleCandidates[fam, s, First[reps], opts], red2, res2},
      sc["candidates"] = stepTag[sc["candidates"], <|"call" -> "single", "rep" -> repKey[First[reps]], "opts" -> stepOpts[opts]|>];
      Print["\n-- non-dlog geometry: best eps-polynomial basis among ", Length[sc["candidates"]], " single integrals --"];
      red2 = MCBReduceCandidates[fam, s, sc["candidates"], kdir, pts];
      res2 = If[red2 === $Failed, $Failed, search[red2, sc["candidates"]]];
      Print["     -> ", If[res2 === $Failed, "no invertible subset", res2["status"]]];
      If[better[res2], best = res2; bestRed = red2; bestCd = First[reps]];
      MCBAppendAttempt[dir, <|"rung" -> 1, "what" -> "single integrals (non-dlog geometry)", "outcome" -> If[AssociationQ[res2], res2["status"], "nothing"], "time" -> Round[AbsoluteTime[] - t0]|>]]];
  (* result *)
  If[! AssociationQ[best] || ! KeyExistsQ[best, "cands"],
    chk = <|"status" -> "failed", "message" -> If[AssociationQ[best], "rank-deficient: " <> ToString[Lookup[best, "rank", "?"]] <> " independent candidates for " <> ToString[nmi] <> " masters", "no invertible subset of candidates"],
      "cutMasters" -> cm["masters"], "nMastersCut" -> nmi, "points" -> pts|>;
    cands = {}; k = {},
    chk = verdictFromSearch[bestRed, best, fam];
    cands = best["cands"]; k = chk["k"]];
  cdUsed = If[MissingQ[bestCd], First[reps], bestCd];
  status = MCBStatusFor[chk, reps0, pf];
  If[status =!= "eps-form" && ! nondlog, AppendTo[flags, "no eps-form basis among the automatic candidates"]];
  If[stopped && (status =!= "eps-form" || ! done[]),
    AppendTo[flags, "the automatic pass used up its time budget of " <> ToString[budget] <> " s (run.wl \"TimeLimits\" -> \"Sector\")" <>
      If[status === "eps-form", " before it found an eps-pure basis", ""] <> "; rung 1 can be pushed further by hand"]];
  (* before the record: the cross-check runs DlogBasis, which must then appear in toolsUsed and citations *)
  dlogCheck = If[cands =!= {} && MCBRouteFor[cdUsed] === "dlog",
    Quiet@TimeConstrained[MCBDlogBasisCheckCandidates[Join[{cdUsed}, reps0, ext], cands], 600, {}], {}];
  (* a pass run again that finds the basis basis.m already has keeps its definitions as written there (another writer may
     have written them another way), so that its key stays *)
  rec = MCBBasisRecord[fam, s, <|"cd" -> cdUsed, "check" -> chk, "cands" -> cands, "k" -> k, "status" -> status, "flags" -> flags,
     "reps" -> Join[{cdUsed}, reps0, ext],
     "definitions" -> With[{d = Lookup[#, "definition", None] & /@ Select[Lookup[MCBReadBasis[dir], "masters", {}], AssociationQ]},
       If[cands =!= {} && MCBSameBasisQ[MapThread[MCBMasterExpression, {cands, k}], d], d, None]],
     "dlogBasisCheck" -> dlogCheck, "repeatedGeometry" -> repeated, "classification" -> pf,
     "curve" -> If[MCBRouteFor[cdUsed] === "curve", KeyTake[MCBCurve[cdUsed], {"P", "genus", "degree", "punctures"}], <||>],
     "time" -> Round[AbsoluteTime[] - t0]|>];
  If[MCBFlaggedQ[rec], rec["retryHints"] = MCBRetryHints[dir, rec]];
  If[cands =!= {}, MCBWriteMasters[dir, MapThread[MCBMasterExpression, {cands, k}]]];
  MCBWriteBasis[dir, rec];
  Print["\n-- result: ", status, If[status =!= "eps-form", "  " <> Lookup[chk, "message", ""], ""], " --"];
  Do[Print["  J", i, " = ", ToString[MCBMasterExpression[cands[[i]], k[[i]]], InputForm], "   [", cands[[i]]["label"], "]"], {i, Length[cands]}];
  If[KeyExistsQ[chk, "A"], MCBPrintDE[chk]];
  If[! MCBSkippedQ["reports"], Quiet@MCBBasisHTML[dir, fam]];
  (* where the script finds the representation used: in the default list, or among those with one more ISP *)
  repRef = Which[
    (p = FirstPosition[reps0[[All, "id"]], cdUsed["id"], None, {1}]) =!= None, {First[p], ""},
    ext =!= {} && (p = FirstPosition[ext[[All, "id"]], cdUsed["id"], None, {1}]) =!= None, {First[p], ", <|\"Extra\" -> 1, \"Standard\" -> False|>"},
    True, {1, ""}];
  (* the script runs again the steps that built the chosen candidates and searches among them, so that it derives the
     basis instead of writing it down; without a basis, the routes that were tried *)
  scriptSteps = If[cands =!= {}, DeleteDuplicates[DeleteMissing[Lookup[cands, "step", Missing[]]]], Values[routeStep]];
  MCBWriteAnalysisScript[fam, s, dir, <|"RepIndex" -> repRef[[1]], "RepOptions" -> repRef[[2]], "Route" -> MCBRouteFor[cdUsed],
     "Steps" -> scriptSteps, "Basis" -> Automatic, "Written" -> If[cands =!= {}, MapThread[MCBMasterExpression, {cands, k}], {}], "Rung" -> 1,
     "Note" -> "The automatic first pass (rung 1) ended with status " <> status <> "; this file runs again the steps that built its candidates and searches among them.",
     "FamilyFile" -> Lookup[opts0, "FamilyFile", Replace[fam["File"], None -> "family.wl"]], "PathsFile" -> Lookup[opts0, "PathsFile", Automatic],
     "Seed" -> Lookup[opts0, "Seed", 1]|>];
  Print["\n(time ", Round[AbsoluteTime[] - t0], " s)"];
  rec];


(* ::Section:: *)
(*Runs*)


$MCBRunDefaults = <|"Family" -> "family.wl", "OutputDir" -> Automatic, "Sectors" -> All, "Skip" -> {}, "Points" -> Automatic, "Seed" -> 1,
   "TimeLimits" -> <|"LS" -> 600, "Sector" -> 900, "FiniteFlow" -> 3600, "Kira" -> 3600, "Baikov" -> 120, "PicardFuchs" -> 300|>,
   "MemoryLimits" -> <|"Kira" -> Automatic, "FiniteFlow" -> Automatic|>, "Parallel" -> Automatic,
   "AutoPass" -> <|"nd" -> 2, "nt" -> 2, "w" -> 3|>, "Paths" -> Automatic, "KeepScratch" -> False|>;

(* "." and ".." are resolved, so that a run folder given as "." gets its real name *)
normPath[p_String] := FileNameJoin[Fold[Which[#2 === ".", #1, #2 === ".." && Length[#1] > 1, Most[#1], True, Append[#1, #2]] &, {}, FileNameSplit[p]]];
absPath[p_String, base_String] := normPath[If[StringStartsQ[p, "/"] || StringMatchQ[p, RegularExpression["[A-Za-z]:.*"]], p, FileNameJoin[{base, p}]]];

MCBAutoPassOptions[setup_Association] := Module[{run = setup["run"], tl = setup["run"]["TimeLimits"]},
  Join[run["AutoPass"], <|"tlim" -> tl["LS"], "budget" -> Lookup[tl, "Sector", Infinity], "BaikovTimeLimit" -> tl["Baikov"],
     "Seed" -> run["Seed"], "FamilyFile" -> run["Family"], "PathsFile" -> setup["paths"]|>,
    If[ListQ[run["Points"]], <|"Points" -> run["Points"]|>, <||>]]];

MCBReadRun[file_String] := Module[{raw = Get[file], base = DirectoryName[ExpandFileName[file]], run},
  If[! AssociationQ[raw], Print["MCBReadRun: ", file, " is not an Association"]; Return[$Failed]];
  run = Join[$MCBRunDefaults, raw];
  run["TimeLimits"] = Join[$MCBRunDefaults["TimeLimits"], Lookup[raw, "TimeLimits", <||>]];
  run["MemoryLimits"] = Join[$MCBRunDefaults["MemoryLimits"], Lookup[raw, "MemoryLimits", <||>]];
  run["AutoPass"] = Join[$MCBRunDefaults["AutoPass"], Lookup[raw, "AutoPass", <||>]];
  run["Family"] = absPath[run["Family"], base];
  If[StringQ[run["Paths"]], run["Paths"] = absPath[run["Paths"], base],
    run["Paths"] = If[FileExistsQ[FileNameJoin[{base, "paths.wl"}]], FileNameJoin[{base, "paths.wl"}], Automatic]];
  If[StringQ[run["OutputDir"]], run["OutputDir"] = absPath[run["OutputDir"], base]];
  run["RunFile"] = ExpandFileName[file];
  run];

MCBRunSetup[spec_String] := Module[{info, run, fam, out, raw, f = ExpandFileName[spec], found = None},
  Which[
    DirectoryQ[f],
      info = SelectFirst[{FileNameJoin[{f, "run_info.m"}], FileNameJoin[{ParentDirectory[f], "run_info.m"}]}, FileExistsQ, None];
      If[info === None, Print["MCBRunSetup: no run_info.m in ", f, " or its parent"]; Return[$Failed]];
      run = Get[info]["Run"];
      (* the run is where run_info.m was found, even when the folder was moved or copied since it was written *)
      found = DirectoryName[info],
    FileExistsQ[f],
      raw = Quiet@Get[f];
      run = If[AssociationQ[raw] && KeyExistsQ[raw, "Propagators"],
        Join[$MCBRunDefaults, <|"Family" -> f, "Paths" -> If[FileExistsQ[FileNameJoin[{DirectoryName[f], "paths.wl"}]], FileNameJoin[{DirectoryName[f], "paths.wl"}], Automatic], "RunFile" -> None|>],
        MCBReadRun[f]],
    True, Print["MCBRunSetup: ", spec, " not found"]; Return[$Failed]];
  If[run === $Failed, Return[$Failed]];
  MCBLoadPaths[run["Paths"]];
  $MCBSkip = run["Skip"];
  $MCBKiraTimeLimit = run["TimeLimits"]["Kira"];
  If[TrueQ[Lookup[run, "KeepScratch", False]], $MCBKeepScratch = True];
  $MCBFFTimeLimit = Lookup[run["TimeLimits"], "FiniteFlow", 3600];
  $MCBPFTimeLimit = Lookup[run["TimeLimits"], "PicardFuchs", 300];
  $MCBKiraMemoryLimit = Lookup[Lookup[run, "MemoryLimits", <||>], "Kira", Automatic];
  $MCBFFMemoryLimit = Lookup[Lookup[run, "MemoryLimits", <||>], "FiniteFlow", Automatic];
  fam = MCBReadFamily[run["Family"]];
  If[fam === $Failed, Return[$Failed]];
  out = normPath[Which[StringQ[found], found, StringQ[run["OutputDir"]], run["OutputDir"], True, FileNameJoin[{fam["Dir"], fam["NameString"] <> "_analysis"}]]];
  run["OutputDir"] = out;
  If[! DirectoryQ[out], CreateDirectory[out, CreateIntermediateDirectories -> True]];
  Put[<|"Run" -> run, "FamilyFile" -> run["Family"], "PathsFile" -> run["Paths"], "OutputDir" -> out|>, FileNameJoin[{out, "run_info.m"}]];
  (* uses are credited to the whole run until a script or the first pass names its sector *)
  CoreCitationContext[out, "whole run", ""];
  <|"run" -> run, "fam" -> fam, "dir" -> out, "paths" -> run["Paths"]|>];

MCBRunSectors[setup_Association] := Module[{run = setup["run"], fam = setup["fam"], sel = setup["run"]["Sectors"], found},
  Which[
    ListQ[sel], Table[Which[StringQ[x], SectorFromName[x], IntegerQ[x], SectorFromName[x, fam["N"]], ListQ[x], x, True, Nothing], {x, sel}],
    MCBMasterSectors[fam] =!= <||>, Values[MCBMasterSectors[fam]][[All, "sector"]],
    FileExistsQ[FileNameJoin[{setup["dir"], "masters_found.m"}]],
      found = Get[FileNameJoin[{setup["dir"], "masters_found.m"}]];
      SortBy[DeleteDuplicates[SectorOf /@ found], {Total[#], SectorID[#]} &],
    True, {}]];


(* ::Section:: *)
(*The per-sector script*)


(* the hash of the script as generated is kept next to it: an unedited script may be refreshed, an edited one never *)
scriptHash[f_] := If[FileExistsQ[f], Hash[Import[f, "Text"], "SHA256", "HexString"], None];
editedQ[dir_] := Module[{f = FileNameJoin[{dir, "AnalysisMasters.m"}], h = FileNameJoin[{dir, ".AnalysisMasters.generated"}]},
  FileExistsQ[f] && ! (FileExistsQ[h] && StringTrim[Import[h, "Text"]] === scriptHash[f])];

MCBWriteAnalysisScript[fam_Association, s_List, dir_String, o_Association : <||>] := Module[{file = FileNameJoin[{dir, "AnalysisMasters.m"}], tmpl, route, txt, famFile, paths,
    ow = Lookup[o, "Overwrite", Automatic]},
  (* Overwrite: True always, False never, Automatic only when the existing script is still exactly as generated;
     an edited script is kept and the new one goes to AnalysisMasters.auto.m *)
  Which[
    ! FileExistsQ[file] || ow === True, Null,
    ow === False, Return[file],
    ow === "IfUnedited" && editedQ[dir],
      Print["   AnalysisMasters.m was edited by hand and is left as it is (when run, it says that masters.m has changed)"]; Return[file],
    editedQ[dir], file = FileNameJoin[{dir, "AnalysisMasters.auto.m"}];
      Print["   AnalysisMasters.m was edited by hand: the automatic pass's version goes to AnalysisMasters.auto.m"]];
  If[! DirectoryQ[dir], CreateDirectory[dir, CreateIntermediateDirectories -> True]];
  tmpl = Import[FileNameJoin[{$MCBRoot, "templates", "AnalysisMasters.m"}], "Text"];
  route = Lookup[o, "Route", "dlog"];
  famFile = Lookup[o, "FamilyFile", Replace[fam["File"], None -> "family.wl"]];
  paths = Lookup[o, "PathsFile", Automatic];
  If[paths === Automatic && FileExistsQ[FileNameJoin[{DirectoryName[famFile], "paths.wl"}]], paths = FileNameJoin[{DirectoryName[famFile], "paths.wl"}]];
  txt = StringReplace[tmpl, {
     "{{FAMILY}}" -> fam["NameString"], "{{SECTORNAME}}" -> SectorName[s], "{{SECTORID}}" -> ToString[SectorID[s]],
     "{{DATE}}" -> DateString[{"Year", "-", "Month", "-", "Day"}],
     "{{AUTONOTE}}" -> Lookup[o, "Note", ""],
     "{{LIBFILE}}" -> FileNameJoin[{$MCBRoot, "lib", "MaximalCutBasis.wl"}],
     "{{WS}}" -> FileNameJoin[{$MCBRoot, "bin", "ws"}],
     "{{PATHSFILE}}" -> If[StringQ[paths], "\"" <> paths <> "\"", "Automatic"], "{{FAMILYFILE}}" -> famFile,
     "{{SKIP}}" -> ToString[$MCBSkip, InputForm],
     "{{SECTOR}}" -> ToString[s], "{{SEED}}" -> ToString[Lookup[o, "Seed", 1]], "{{KIRATL}}" -> ToString[$MCBKiraTimeLimit, InputForm], "{{KIRAMEM}}" -> ToString[$MCBKiraMemoryLimit, InputForm],
     "{{REPINDEX}}" -> ToString[Lookup[o, "RepIndex", 1]], "{{REPOPTS}}" -> Lookup[o, "RepOptions", ""],
     "{{ROUTE}}" -> route,
     "{{CANDNOTE}}" -> Lookup[o, "CandNote", ""],
     "{{STEPS}}" -> ToString[Lookup[o, "Steps", {<|"call" -> "route", "rep" -> Automatic, "opts" -> <|"nmi" -> Automatic|>|>}], InputForm],
     "{{WRITTEN}}" -> ToString[Lookup[o, "Written", Replace[MCBReadMasters[dir], Except[_List] -> {}]], InputForm],
     "{{BASIS}}" -> ToString[Lookup[o, "Basis", Automatic], InputForm],
     "{{LABELS}}" -> ToString[Lookup[o, "Labels", {}], InputForm],
     "{{PROVENANCE}}" -> ToString[Lookup[o, "Provenance", {}], InputForm],
     "{{RUNG}}" -> ToString[Lookup[o, "Rung", 1], InputForm]}];
  Export[file, txt, "Text"];
  If[FileNameTake[file] === "AnalysisMasters.m", Export[FileNameJoin[{dir, ".AnalysisMasters.generated"}], scriptHash[file], "Text"]];
  file];


End[];
EndPackage[];
