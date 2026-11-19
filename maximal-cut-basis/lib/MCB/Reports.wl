(* ::Package:: *)

(* ::Title:: *)
(*MaximalCutBasis`Reports`: basis.m, masters.m, attempts.m, notes.md, CITATIONS.md, basis.html, summary.* *)


BeginPackage["MaximalCutBasis`Reports`", {"MaximalCutBasis`", "SkillCore`Tools`", "SkillCore`Records`", "SkillCore`Pages`", "SkillCore`Citations`", "MaximalCutBasis`Family`",
   "MaximalCutBasis`Sectors`", "MaximalCutBasis`Rules`", "MaximalCutBasis`Baikov`", "MaximalCutBasis`LeadingSingularities`", "MaximalCutBasis`DECheck`",
   "MaximalCutBasis`Draw`"}];

MCBBasisRecord::usage = "MCBBasisRecord[fam, sector, <|\"cd\", \"check\", \"cands\", \"k\", \"cut\", \"flags\", \"provenance\", \"reps\", \"tools\", \"dir\", \"definitions\", ...|>] assembles the basis.m association (see reference/formats.md). \"definitions\": the current basis.m's, verbatim, for a basis that did not change (MCBSameBasisQ), so that its key (CoreBasisKey) stays; otherwise each element is MCBMasterExpression of its candidate. Each element gets \"epsPure\", \"epsPureDetail\" and \"purityRule\": its candidate's verdict (MCBCandidatePurity) when it has one, else MCBCandidatePurity's in \"reps\" (not checked without them). \"toolsUsed\" and \"citations\" are MCBRecordCitations of the sector: what the run's ledger credits to it (the run of \"dir\", else of the citation context when that is this sector), this kernel's marks, and \"tools\", the tools run by hand (declared; an unknown name is refused). The provenance of the elements credits nothing, except that a master \"mapped from jX\" (a repeated geometry) imports the credits of jX for this basis (CoreImportCitations, \"BasisKey\"): cited while it is the sector's basis.";
MCBKnownTools::usage = "MCBKnownTools[names] is the registry keys of names (CoreToolKey: \"Kira\" gives kira, \"Fermat\" fer64), without repeats, when each is a name of the registry $MCBTools (a tool, a method or a program run outside the toolkit: SOFIA, ore_algebra, ...); otherwise a message that names the unknown ones and lists the known names, and $Failed. check_basis.wls --tool and the \"tools\" of MCBBasisRecord are checked with it.";
MCBRecordCitations::usage = "MCBRecordCitations[dir, sector, declared, key] = <|\"toolsUsed\", \"citations\"|> of a basis.m record of sector (its name, j0101...) in the run of dir, for the basis whose CoreBasisKey is key (None: the current one): the tools and methods the run's ledger cites for the sector (a credit imported for a basis counts for that basis only) (CoreSectorCitations: every kernel, every earlier record and imported credits), this kernel's marks (MCBToolsUsed) and the tools declared (run by hand), with the citations of the registered ones (MCBCitations). The declared names are checked with MCBKnownTools (an unknown one is refused and left out) and recorded in the ledger for the sector, step \"declared\". dir None: no ledger.";
MCBRetryHints::usage = "MCBRetryHints[dir, record] lists the ladder rungs not yet tried, in order, as the next things to try.";
MCBBasisHTML::usage = "MCBBasisHTML[dir, fam] writes basis.html from basis.m, attempts.m, notes.md, the run's ledger of tools and papers (CoreSectorCitationsHTML) and finiteflow/verdict.m, with a drawing of the sector. Without fam the family is read through the run folder's run_info.m.";
MCBSummaryHTML::usage = "MCBSummaryHTML[runDir, fam] writes summary.html (flagged sectors first, then what to cite), masters_all.m and CITATIONS.md.";
MCBTeX::usage = "MCBTeX[expr] is a TeX string for MathJax (integrals as j_{indices}).";
MCBReadFFVerdict::usage = "MCBReadFFVerdict[sectorDir] reads finiteflow/verdict.m. If the FiniteFlow check was written for a different basis than the current masters.m, it returns a verdict with status \"stale\" instead; Missing[\"NotRun\"] when there is none.";
MCBWrittenEpsPower::usage = "MCBWrittenEpsPower[J] = {m, mixed}: the lowest power of eps among the terms of a basis element as written, and whether its terms start at different powers.";
MCBBetterBasisQ::usage = "MCBBetterBasisQ[status, range, old, new] is True when a basis with this status and range of powers of eps should replace the current one (old: its basis.m record): a better status (eps-form > eps-polynomial > eps-polynomial (dlog search incomplete) > failed), or, between two eps-polynomial bases of the same status, a smaller spread of powers of eps; between two of the same spread on a non-dlog sector (MCBNonDlogQ), one with an undotted element replaces one whose every element is dotted (the all-dot flag), when new gives the new basis (<|\"masters\" -> its elements|>); between two eps-form bases, one with fewer elements that are not eps-pure, then with more that are, replaces the other, when new gives their purity (<|\"purity\" -> {True | False | Missing[...], ...}|>, as MCBCandidatePurity gives it) and the current record has it (\"epsPure\" of its masters). True when there is no current basis. check_basis.wls and AnalysisMasters.m use this rule.";
MCBKeptPurity::usage = "MCBKeptPurity[old, defs] gives, for each definition, the purity verdict that the record old (basis.m) has for the same element (equal at random points), <|\"pure\", \"pureDetail\"|>, when old judged it with this version's rule (\"purityRule\" -> $MCBPurityRule) and the verdict is True or False; otherwise <||>. check_basis.wls and AnalysisMasters.m keep these verdicts, so that a re-check judges an element as the pass that chose it did (with its representation and every representation it had).";
$MCBPurityRule::usage = "$MCBPurityRule is the version of the rule that judges an element eps-pure (MCBElementPurity, MCBCandidatePurity), written in basis.m with each element (\"purityRule\"); a verdict of another version is judged again.";
MCBNonDlogQ::usage = "MCBNonDlogQ[status, classification] is True for a non-dlog sector: status eps-polynomial (non-dlog geometry shown), or a Picard-Fuchs label that is not polylogarithmic. The all-dot flag applies there only.";
MCBAllDotCheck::usage = "MCBAllDotCheck[sector, masters, status, classification] is the all-dot check of a basis on a non-dlog sector (MCBNonDlogQ): <|\"Name\" -> \"all-dot\", \"Pass\" -> False when every element is dotted (MCBAllDotQ), \"Detail\"|>; Missing[\"NotApplicable\"] on a dlog sector. MCBBasisRecord puts it in basis.m \"checks\" and, when it fails, a flag in \"flags\": such a basis is likely to carry a weight between sectors.";
MCBClassificationFlags::usage = "MCBClassificationFlags[classification, status] are the flags a Picard-Fuchs classification (basis.m \"classification\") puts on a sector with this status: an unresolved block (SageMath can factor it), no frame regular at eps = 0, a Baikov or Kira check that disagrees, an eps-form basis on a non-polylog label. Each starts with \"Picard-Fuchs:\".";
MCBFlaggedQ::usage = "MCBFlaggedQ[record] is True for sectors that need attention: not eps-form and not a proven non-dlog eps-polynomial basis, an eps-form basis on a sector whose Picard-Fuchs label is not polylogarithmic, an eps-form basis with an element that is not eps-pure (\"epsPure\" False in its masters), or a Picard-Fuchs check (Baikov curve or Kira) that disagrees.";
MCBKeepClassification::usage = "MCBKeepClassification[dir, record] is record with the Picard-Fuchs classification of the basis.m in dir, when record has none and is for the same sector (a record written by an AnalysisMasters.m generated before the step existed, say), and with the status, flags and retry hints that classification implies; a change of status is recorded in attempts.m. Otherwise it is record. MCBWriteBasis applies it to every record ($CoreBasisMerge).";
$MCBRungs::usage = "$MCBRungs is the escalation ladder: rung number -> <|\"name\", \"hint\"|>.";

Begin["`Private`"];


$MCBRungs = <|
  1 -> <|"name" -> "cheap-automatic", "hint" -> "Rung 1: larger pools (nd+1, nt+1, w+1), 3-term subsets, the whole-pool solve, extra-ISP and standard Baikov representations (MCBAutoPass with larger options)."|>,
  2 -> <|"name" -> "literature", "hint" -> "Rung 2: search arXiv/INSPIRE for a canonical/UT basis of this topology (loop number, masses, legs, known names); map the paper's propagators onto the family and check the candidates with MCBCheckBasis."|>,
  3 -> <|"name" -> "d0-shift", "hint" -> "Rung 3: redo the analysis in d = d0' - 2 eps (d0' = D0 - 2) with MCBDimensionShift; candidates are mapped back with Tarasov's relation."|>,
  4 -> <|"name" -> "agent-candidates", "hint" -> "Rung 4: build candidates by hand: inspect the cut integrand per variable (MCBCutIntegrand), cancel double poles and poles at infinity with numerators, take residues (MCBIteratedLS), use curve coordinates (MCBCurveCoordinates) and fibrations (MCBFibrationTable)."|>,
  5 -> <|"name" -> "geometric-order", "hint" -> "Rung 5: choose the master integrands by their geometry (arXiv:2511.15381, step 1): localisations on even twist factors from points up (MCBBoundaries), then pole order, then denominator powers |mu|; normalise each element by eps^-|mu| and check that the DE is F-compatible (escalation.md)."|>,
  6 -> <|"name" -> "algorithms", "hint" -> "Rung 6: export the maximal-cut DE (MCBExportDE) to INITIAL, Libra or Fuchsia and check the transformed basis with bin/check_basis.wls, declaring the tool (--tool INITIAL, --tool Libra or --tool Fuchsia) so that it is credited."|>,
  7 -> <|"name" -> "flag", "hint" -> "Rung 7: flag the sector with the best basis found."|>|>;

esc = MCBHTMLEscape;


(* ::Section:: *)
(*The basis.m record*)


knownToolQ[t_] := CoreToolKey[t] =!= $Failed;
MCBKnownTools::unknown = "Not in the registry of tools and methods ($MCBTools): `1`. The known names are `2`.";
MCBKnownTools[names_List] := With[{keys = CoreToolKey /@ names},
  If[FreeQ[keys, $Failed], DeleteDuplicates[keys],
    Message[MCBKnownTools::unknown, StringRiffle[ToString[#, InputForm] & /@ DeleteDuplicates[Pick[names, keys, $Failed]], ", "], StringRiffle[Keys[$MCBTools], ", "]];
    $Failed]];

(* A record lists every tool the run credits to the sector, whichever kernel used it and whenever: a basis.m written
   again (bin/check_basis.wls, an AnalysisMasters.m) keeps the tools that found the earlier basis. Tools run by hand
   (INITIAL, Libra, Fuchsia, ore_algebra, ...) are declared; the words of a provenance credit nothing. A credit imported
   for a basis (a repeated geometry's) counts for the record of that basis only, cited or not yet (the basis.m it
   replaces is still there), unless it came in consulted itself (a credit the sector it came from no longer uses);
   the others count while they are cited. A name the ledger holds that the registry does not
   (an older run's) stays in toolsUsed, without a citation *)
MCBRecordCitations[dir_, name_String, declared0_List : {}, key_ : None] := Module[{declared = DeleteDuplicates[declared0], keep, ledger, tools},
  declared = Replace[MCBKnownTools[declared], $Failed :> DeleteDuplicates[DeleteCases[CoreToolKey /@ declared, $Failed]]];
  If[StringQ[dir] && declared =!= {}, CoreRecordTool[dir, declared, "declared", "Sector" -> name]];
  keep[e_] := With[{b = Lookup[e, "basisKey", None]},
    If[StringQ[key] && StringQ[b], b === key && ! MemberQ[{"not adopted", "rejected", "declined", "not tried"}, Lookup[e, "result", None]] &&
      (e["part"] === "cite" || Lookup[e, "outcome", None] === "replaced by a later basis"), e["part"] === "cite"]];
  ledger = If[StringQ[dir], #["tool"] & /@ Select[CoreSectorCitations[CoreRunFolder[dir], name]["tools"], keep], {}];
  tools = Union[ledger, MCBToolsUsed[], declared];
  <|"toolsUsed" -> tools, "citations" -> MCBCitations[Select[tools, knownToolQ]]|>];

(* the run of a record: "dir", else that of the citation context when the context is this sector's *)
recordDir[info_Association, s_List] := Lookup[info, "dir",
  With[{c = $CoreCitationContext}, If[AssociationQ[c] && Lookup[c, "Sector", None] === SectorName[s], c["Dir"], None]]];

MCBBasisRecord[fam_Association, s_List, info_Association] := Module[{cd = Lookup[info, "cd", Missing[]], chk = Lookup[info, "check", <||>],
    cands = Lookup[info, "cands", {}], k, defs, masters, user, cutm, status, rec, tools, dir, key},
  k = Lookup[info, "k", Lookup[chk, "k", ConstantArray[0, Length[cands]]]];
  If[! ListQ[k] || Length[k] != Length[cands], k = ConstantArray[0, Length[cands]]];
  (* a basis that did not change keeps its definitions as its basis.m writes them ("definitions"): the same basis
     rebuilt can be written another way (eps^k inside a sum or outside it), and its key, with what is stamped with it,
     would change *)
  defs = Lookup[info, "definitions", None];
  If[! ListQ[defs] || Length[defs] != Length[cands], defs = MapThread[MCBMasterExpression, {cands, k}]];
  (* the purity verdict the search gave the candidate (MCBCandidatePurity), or one built eps-pure; otherwise it is
     checked here. A verdict the search left open (a timeout) is checked again, with more time *)
  masters = Table[With[{c = cands[[i]], sr = MCBSplitRoot[cands[[i]]["r2"], 1][[1]],
       pu = With[{c0 = If[MissingQ[Lookup[cands[[i]], "pure", Missing[]]], KeyDrop[cands[[i]], {"pure", "pureDetail"}], cands[[i]]]},
         If[KeyExistsQ[c0, "pure"] || TrueQ[Lookup[c0, "strict", False]] || ListQ[Lookup[info, "reps", None]],
           First[MCBCandidatePurity[Replace[Lookup[info, "reps", {}], Except[_List] -> {}], {c0}, <|"TimeLimit" -> 120|>]],
           <|"pure" -> Missing["NotChecked"], "pureDetail" -> "not checked"|>]]},
      <|"definition" -> defs[[i]], "normalisation" -> If[sr === 1 || NumericQ[sr], "rational", sr],
        "epsPowerRelative" -> k[[i]],
        "epsPowerWritten" -> MCBWrittenEpsPower[defs[[i]]][[1]],
        "epsPowerMixed" -> MCBWrittenEpsPower[defs[[i]]][[2]],
        "epsPure" -> pu["pure"], "epsPureDetail" -> Lookup[pu, "pureDetail", ""], "purityRule" -> $MCBPurityRule,
        "label" -> Lookup[c, "label", ""], "provenance" -> Lookup[c, "provenance", "agent"]|>], {i, Length[cands]}];
  user = Lookup[Lookup[MCBMasterSectors[fam], SectorName[s], <||>], "masters", {}];
  cutm = Lookup[chk, "cutMasters", Lookup[info, "cutMasters", {}]];
  status = Lookup[info, "status", Lookup[chk, "status", "failed"]];
  dir = recordDir[info, s];
  key = If[masters === {}, None, CoreBasisKey[masters[[All, "definition"]]]];
  (* a master mapped from a repeated geometry: the credits of the sector it came from count for this basis, and only
     while it is the sector's basis *)
  If[StringQ[dir] && StringQ[key],
    Scan[CoreImportCitations[dir, CoreRunFolder[dir], #, SectorName[s], "mapped from " <> #, "BasisKey" -> key] &,
      DeleteCases[DeleteDuplicates[Flatten[StringCases[Select[masters[[All, "provenance"]], StringQ], RegularExpression["mapped from (j[01]+)"] -> "$1"]]],
        SectorName[s]]]];
  tools = MCBRecordCitations[dir, SectorName[s], Flatten[{Lookup[info, "tools", {}]}], key];
  rec = <|
    "sector" -> s, "name" -> SectorName[s], "id" -> SectorID[s], "family" -> fam["NameString"],
    "props" -> Table["D" <> ToString[i] <> " = " <> MCBPropLabel[fam, i], {i, PropPos[s]}],
    "status" -> status, "range" -> Lookup[chk, "range", {1, 1}],
    "geometry" -> If[AssociationQ[cd], Join[cd["geometry"], Lookup[info, "curve", <||>]], Lookup[info, "geometry", <|"class" -> "unknown", "text" -> "not computed"|>]],
    "representation" -> If[AssociationQ[cd], <|"kind" -> cd["kind"], "order" -> cd["order"], "isp" -> cd["isp"], "vars" -> cd["vars"],
        "cutpolys" -> cd["cutpolys"], "cutpows" -> cd["cutpows"], "kinNorm" -> cd["split"]["kinNorm"], "Rz" -> cd["split"]["Rz"],
        "Pr" -> cd["split"]["Pr"], "prefRat" -> cd["prefRat"], "D0" -> cd["D0"]|>, Missing["NotComputed"]],
    "masters" -> masters,
    "nMastersCut" -> Lookup[chk, "nMastersCut", Length[cutm]], "nMastersList" -> Length[user],
    "extraMasters" -> If[user === {} || Length[cutm] <= Length[user], {}, Complement[cutm, user]],
    "cutMasters" -> cutm,
    "points" -> Lookup[chk, "points", {}],
    (* "A": the DE matrices at the first point, rational frame, for exactly the expressions in masters.m *)
    "kiraVerdict" -> KeyTake[chk, {"status", "k", "range", "pattern", "message", "A", "invariants"}],
    (* MCBBasisChecks: rules, letters, weights (reported) and the Euler relation (decides) *)
    "checks" -> withAllDot[Lookup[chk, "checks", {}], s, masters[[All, "definition"]], status, Lookup[info, "classification", None]],
    "epsPowerCommon" -> "undetermined: the maximal cut only fixes the powers of eps relative to each other",
    "finiteflowVerdict" -> Lookup[info, "finiteflowVerdict", Missing["NotRun"]],
    "dlogBasisCheck" -> Lookup[info, "dlogBasisCheck", {}],
    "classification" -> Lookup[info, "classification", Missing["NotRun"]],
    "flags" -> Join[Lookup[info, "flags", {}], MCBClassificationFlags[Lookup[info, "classification", None], status], allDotFlags[s, masters[[All, "definition"]], status, Lookup[info, "classification", None]],
      (* an eps-form basis whose elements are not eps-pure off the cut is likely to give poles later: the sector is
         flagged (MCBFlaggedQ) *)
      With[{np = impureElements[masters]},
        If[np =!= {} && status === "eps-form",
          {"not eps-pure off the cut (Gamma prefactor included): " <> StringRiffle[("J" <> ToString[#]) & /@ np, ", "] <>
            "; an eps-form basis is final only when every element is eps-pure, so the sector needs step 4 (dots on massive tadpole or bubble lines, see the column on the page)"}, {}]]],
    "retryHints" -> Lookup[info, "retryHints", {}],
    "skipped" -> Intersection[$MCBSkip, $MCBSteps],
    (* kept for older readers; the pages and CITATIONS.md read the run's ledger *)
    "toolsUsed" -> tools["toolsUsed"],
    "citations" -> tools["citations"],
    "time" -> Lookup[info, "time", Missing[]], "date" -> DateString[]|>;
  (* MCBAutoPass: the sector is the same integrals as another one at mapped kinematics (MCBRepeatedGeometry) *)
  If[AssociationQ[Lookup[info, "repeatedGeometry", None]], rec["repeatedGeometry"] = info["repeatedGeometry"]];
  rec];

(* a large coefficient (MCBLargeQ) is read at a random point of the invariants, eps kept *)
MCBWrittenEpsPower[J_] := Module[{cs = MCBCoefficients[J], ords},
  ords = Table[With[{c = Together[If[MCBLargeQ[cs[jj]], cs[jj] /. MCBRandomValues[cs[jj], 5000, {eps}], cs[jj]]]},
      If[c === 0, Nothing, Exponent[Expand[Numerator[c]], eps, Min] - Exponent[Expand[Denominator[c]], eps, Min]]], {jj, Keys[cs]}];
  If[ords === {}, {Missing["NoIntegrals"], False}, {Min[ords], Length[Union[ords]] > 1}]];

MCBReadFFVerdict[sdir_String] := Module[{vf = FileNameJoin[{sdir, "finiteflow", "verdict.m"}], inf = FileNameJoin[{sdir, "finiteflow", "ffinfo.m"}],
    mf = FileNameJoin[{sdir, "masters.m"}], v, old, cur},
  If[! FileExistsQ[vf], Return[Missing["NotRun"]]];
  v = Quiet@Get[vf];
  If[! AssociationQ[v], Return[Missing["NotRun"]]];
  old = If[FileExistsQ[inf], Lookup[Quiet@Get[inf], "masters", None], None];
  cur = If[FileExistsQ[mf], Quiet@Get[mf], None];
  If[ListQ[old] && ListQ[cur] && (Length[old] != Length[cur] || ! AllTrue[MapThread[MCBEqualAtPointsQ, {old, cur}], TrueQ]),
    Return[<|"status" -> "stale", "mode" -> Lookup[v, "mode", "?"], "staleStatus" -> v["status"],
      "message" -> "this verdict (" <> ToString[v["status"]] <> ") was for a different basis than the current masters.m; rerun bin/finiteflow_sector.sh"|>]];
  v];

statusRank[st_] := Switch[st, "eps-form", 4, "eps-polynomial", 3, "eps-polynomial (dlog search incomplete)", 2, "failed" | "rational", 1, _, 0];
rangeSpread[r_] := If[MatchQ[r, {_?NumericQ, _?NumericQ}], r[[2]] - r[[1]], Infinity];
MCBBetterBasisQ[status_, range_, old_Association, new_Association : <||>] := With[{os = Lookup[old, "status", "not run"], s = Lookup[old, "sector", Lookup[new, "sector", None]]},
  statusRank[status] > statusRank[os] ||
   (statusRank[status] == statusRank[os] && MemberQ[{2, 3}, statusRank[status]] && rangeSpread[range] < rangeSpread[Lookup[old, "range", {}]]) ||
   (* the all-dot tie-breaker, on a non-dlog sector: an undotted element beats a basis of dotted elements *)
   (statusRank[status] == statusRank[os] && MemberQ[{2, 3}, statusRank[status]] && rangeSpread[range] == rangeSpread[Lookup[old, "range", {}]] &&
     KeyExistsQ[new, "masters"] && ListQ[s] && MCBNonDlogQ[status, Lookup[old, "classification", None]] &&
     MCBAllDotQ[mastersOf[old], s] && ! MCBAllDotQ[mastersOf[new], s]) ||
   (* between two eps-form bases, the one with fewer elements that are not eps-pure, then with more that are *)
   (statusRank[status] == statusRank[os] == 4 && ListQ[purityOf[new]] && ListQ[purityOf[old]] &&
     purityRank[purityOf[new]] =!= purityRank[purityOf[old]] && OrderedQ[{purityRank[purityOf[new]], purityRank[purityOf[old]]}])];

$MCBPurityRule = 2;
MCBKeptPurity[old_Association, defs_List] := With[{ms = Select[Flatten[{Lookup[old, "masters", {}]}], AssociationQ[#] && Lookup[#, "purityRule", 0] === $MCBPurityRule &&
      BooleanQ[Lookup[#, "epsPure", Missing[]]] && KeyExistsQ[#, "definition"] &]},
  Table[With[{m = SelectFirst[ms, TrueQ[MCBEqualAtPointsQ[#["definition"], d]] &, None]},
    If[m === None, <||>, <|"pure" -> m["epsPure"], "pureDetail" -> Lookup[m, "epsPureDetail", ""]|>]], {d, defs}]];

(* the purity of a basis's elements: "purity" (a list of verdicts), else "epsPure" of its masters when the record has it *)
purityOf[x_Association] := Which[ListQ[Lookup[x, "purity", None]], x["purity"],
   With[{m = Lookup[x, "masters", {}]}, ListQ[m] && m =!= {} && AllTrue[m, AssociationQ[#] && KeyExistsQ[#, "epsPure"] &]], Lookup[x["masters"], "epsPure"],
   True, None];
purityRank[ps_List] := {Count[ps, False], -Count[ps, True]};

(* the all-dot flag: on a non-dlog sector a basis whose every element is dotted is likely to carry an (a + b eps) weight
   between sectors, which the maximal cut cannot see; an undotted element wins a tie (SKILL.md, tie-breakers) *)
MCBNonDlogQ[status_, cls_ : None] := status === "eps-polynomial" || nonPolylogLabel[If[AssociationQ[cls], Lookup[cls, "label", ""], ""]];
$allDotFlag = "all-dot: every element is dotted; on a non-dlog sector such a basis is likely to carry a weight between sectors (an (a + b eps) factor the maximal cut cannot see, which shows as poles in the DE above it): a basis with an undotted element wins a tie";
MCBAllDotCheck[s_List, ms_List, status_, cls_ : None] := If[! MCBNonDlogQ[status, cls] || ms === {}, Missing["NotApplicable"],
  With[{dot = MCBDottedQ[#, s] & /@ ms},
    <|"Name" -> "all-dot", "Pass" -> ! AllTrue[dot, TrueQ],
      "Detail" -> If[AllTrue[dot, TrueQ], "every element is dotted: likely to carry a weight between sectors; a basis with an undotted element wins a tie",
        "undotted: " <> StringRiffle[("J" <> ToString[#]) & /@ Flatten[Position[dot, False]], ", "] <> " (non-dlog sector)"]|>]];
withAllDot[checks_List, s_, ms_, status_, cls_] := With[{c = MCBAllDotCheck[s, ms, status, cls]},
  Join[Select[checks, Lookup[#, "Name", ""] =!= "all-dot" &], If[AssociationQ[c], {c}, {}]]];
allDotFlags[s_, ms_, status_, cls_] := With[{c = MCBAllDotCheck[s, ms, status, cls]}, If[AssociationQ[c] && ! c["Pass"], {$allDotFlag}, {}]];
mastersOf[rec_] := Replace[Lookup[rec, "masters", {}], m_Association :> Lookup[m, "definition", Missing[]], {1}];

MCBFlaggedQ[rec_Association] := ! (rec["status"] === "eps-form" || rec["status"] === "eps-polynomial") ||
   (rec["status"] === "eps-form" && nonPolylogLabel[pfLabel[rec]]) || pfDisagreeing[rec] =!= {} ||
   (rec["status"] === "eps-form" && impureElements[Lookup[rec, "masters", {}]] =!= {});

(* the elements of a record (basis.m "masters") known not to be eps-pure (epsPure False) *)
impureElements[ms_List] := Flatten[Position[Lookup[#, "epsPure", Missing[]] & /@ Replace[ms, Except[_Association] -> <||>, {1}], False]];
impureElements[_] := {};

(* the Picard-Fuchs classification (MCBPicardFuchs, loaded after this file: its predicates are called by full name) *)
pfLabel[rec_Association] := With[{c = Lookup[rec, "classification", None]}, If[AssociationQ[c], Lookup[c, "label", ""], ""]];
nonPolylogLabel[l_] := TrueQ[MaximalCutBasis`PicardFuchs`MCBPFNonPolylogQ[l]];
polylogLabel[l_] := TrueQ[MaximalCutBasis`PicardFuchs`MCBPFPolylogQ[l]];
(* the checks of the classification that disagree with it: {name -> message, ...} *)
pfChecks = {"baikovCheck" -> "Baikov curve", "kiraCheck" -> "Kira"};
pfDisagreeing[rec_Association] := With[{c = Lookup[rec, "classification", None]},
  If[! AssociationQ[c], {},
    Cases[pfChecks, (key_ -> name_) /; AssociationQ[Lookup[c, key, None]] && Lookup[c[key], "status", ""] === "disagree" :> (name -> Lookup[c[key], "message", ""])]]];

(* basis.m keeps its classification: the step's label describes the cut, not the basis, and a script written before the
   step existed (an old AnalysisMasters.m) writes its record without one. The status follows the label as MCBStatusFor
   decides it: polylog never allows a final eps-polynomial, a non-polylog label always does *)
MCBKeepClassification[dir_String, rec_Association] := Module[{old, cls, r = rec, st0 = Lookup[rec, "status", None], st, l, epsPoly},
  If[AssociationQ[Lookup[rec, "classification", None]], Return[rec]];
  old = MCBReadBasis[dir]; cls = Lookup[old, "classification", None];
  If[! AssociationQ[cls] || Lookup[old, "sector", None] =!= Lookup[rec, "sector", Missing[]], Return[rec]];
  r["classification"] = cls; l = Lookup[cls, "label", ""];
  epsPoly = MemberQ[{"eps-polynomial", "eps-polynomial (dlog search incomplete)"}, st0];
  st = Which[epsPoly && nonPolylogLabel[l], "eps-polynomial", epsPoly && polylogLabel[l], "eps-polynomial (dlog search incomplete)", True, st0];
  If[st =!= st0,
    MCBAppendAttempt[dir, <|"what" -> "basis.m kept its Picard-Fuchs classification (" <> l <> ")", "outcome" -> "status " <> st0 <> " -> " <> st|>];
    r["status"] = st];
  r["flags"] = Join[Select[Lookup[r, "flags", {}], ! (StringQ[#] && (StringStartsQ[#, "Picard-Fuchs:"] || StringStartsQ[#, "all-dot:"])) &], MCBClassificationFlags[cls, st],
    If[ListQ[Lookup[r, "sector", None]], allDotFlags[r["sector"], mastersOf[r], st, cls], {}]];
  If[ListQ[Lookup[r, "sector", None]] && ListQ[Lookup[r, "checks", None]], r["checks"] = withAllDot[r["checks"], r["sector"], mastersOf[r], st, cls]];
  r["retryHints"] = Which[! MCBFlaggedQ[r], {}, KeyExistsQ[r, "geometry"], MCBRetryHints[dir, r], True, Lookup[r, "retryHints", {}]];
  r];
SkillCore`Records`$CoreBasisMerge = MCBKeepClassification;

MCBClassificationFlags[cls_Association, status_] := Module[{l = Lookup[cls, "label", ""], bc = Lookup[cls, "baikovCheck", <||>], kc = Lookup[cls, "kiraCheck", <||>], out = {}},
  If[StringQ[l] && StringStartsQ[l, "unresolved"],
    AppendTo[out, "Picard-Fuchs: " <> l <> " (" <> ToString[Lookup[cls, "reason", ""]] <> "); tell the user that SageMath's ore_algebra can factor the block (L.factor(); the block is in basis.m under \"classification\")"]];
  If[MissingQ[Lookup[cls, "orderDrop", 0]],
    AppendTo[out, "Picard-Fuchs: no frame regular at eps = 0 was found, so the eps = 0 operator would see only part of the sector (orderDrop); tell the user"]];
  If[AssociationQ[bc] && Lookup[bc, "status", ""] === "disagree", AppendTo[out, "Picard-Fuchs: " <> bc["message"]]];
  If[AssociationQ[kc] && Lookup[kc, "status", ""] === "disagree", AppendTo[out, "Picard-Fuchs: " <> kc["message"]]];
  If[status === "eps-form" && nonPolylogLabel[l],
    AppendTo[out, "Picard-Fuchs: an eps-form basis on a sector whose operator is " <> l <> ": that cannot be, check the DE and the picard-fuchs step"]];
  out];
MCBClassificationFlags[_, _] := {};

frameText["none"] = "the masters' own, regular at \[Epsilon] = 0"; frameText["diagonal"] = "the masters rescaled by powers of \[Epsilon]";
frameText["lattice"] = "a lattice of the masters regular at \[Epsilon] = 0"; frameText[x_] := ToString[x];

pfSection[rec_Association] := Module[{c = Lookup[rec, "classification", None], f, bc, kc},
  If[! AssociationQ[c], Return["<h2>Picard-Fuchs operator</h2><p class='muted'>not computed (bin/picard_fuchs.wls computes it for a finished sector)</p>"]];
  f = Lookup[c, "factors", <||>]; bc = Lookup[c, "baikovCheck", <||>]; kc = Lookup[c, "kiraCheck", <||>];
  StringJoin["<h2>Picard-Fuchs operator</h2><p><b>", esc[ToString[c["label"]]], "</b>", If[StringQ[Lookup[c, "reason", None]], ": " <> esc[c["reason"]], ""], "</p>",
    If[IntegerQ[Lookup[c, "order", None]],
      "<p>On a line through the first point of the Kira check, at &epsilon; = 0 (frame: " <> esc[frameText[Lookup[c, "regularisation", "?"]]] <>
        "), the DE of the " <> ToString[c["order"]] <> " masters has " <>
        Which[AssociationQ[f] && KeyExistsQ[f, "firstOrder"],
            ToString[f["firstOrder"]] <> " piece(s) of first order" <> If[f["blocks"] === {}, "", " and block(s) of order " <> StringRiffle[ToString /@ f["blocks"], ", "]],
          AssociationQ[f] && KeyExistsQ[f, "block"], ToString[f["right"] + f["left"]] <> " first-order factor(s) and a block of order " <> ToString[f["block"]],
          True, "?"] <>
        "; the corner integral's operator has order " <> ToString[Lookup[c, "cornerOrder", "?"]] <> ".</p>", ""],
    If[AssociationQ[bc] && KeyExistsQ[bc, "status"] && bc["status"] =!= "not applicable",
      "<p>Baikov curve: <b>" <> esc[bc["status"]] <> "</b>" <> If[StringQ[Lookup[bc, "message", None]], " &mdash; " <> esc[bc["message"]], ""] <> "</p>", ""],
    If[AssociationQ[kc] && KeyExistsQ[kc, "status"],
      "<p>Kira at the first point: <b>" <> esc[kc["status"]] <> "</b>" <> If[StringQ[Lookup[kc, "message", None]], " &mdash; " <> esc[kc["message"]], ""] <> "</p>", ""],
    (* the exponents, log powers and p-curvature stay in basis.m as evidence; the page shows the label *)
    If[NumericQ[Lookup[c, "time", None]], "<p class='muted'>" <> ToString[c["time"]] <> " s</p>", ""]]];

MCBRetryHints[dir_String, rec_Association] := Module[{tried = Union[Cases[MCBReadAttempts[dir], a_ /; KeyExistsQ[a, "rung"] :> a["rung"]]], hints},
  hints = Table[$MCBRungs[r]["hint"], {r, Complement[Range[2, 6], tried]}];
  If[MemberQ[{"curve", "non-polylog"}, Lookup[rec["geometry"], "class", ""]] || nonPolylogLabel[pfLabel[rec]],
    AppendTo[hints, "Non-dlog geometry: an eps-factorised form needs periods of the curve or of the fibration (out of scope of this skill; see method.md)."]];
  If[pfLabel[rec] === "polylog (nested root)",
    AppendTo[hints, "\[Epsilon]-form needs \[Sqrt](A + B \[Sqrt]D), not built: the Picard-Fuchs operator has algebraic solutions that are not roots of rational functions, and the skill's bases use rational and single-root normalisations only."]];
  If[StringStartsQ[pfLabel[rec], "unresolved"],
    AppendTo[hints, "The Picard-Fuchs block is unresolved: SageMath's ore_algebra can factor it (L.factor() on the block in basis.m, \"classification\"); ask the user."]];
  Scan[AppendTo[hints, "The Picard-Fuchs " <> #[[1]] <> " check disagrees (" <> #[[2]] <> "): find which side is wrong (the line DE, the masters, the curve) before relying on the label, and tell the user."] &,
    pfDisagreeing[rec]];
  If[rec["status"] === "eps-form" && impureElements[Lookup[rec, "masters", {}]] =!= {},
    AppendTo[hints, "Not eps-pure: " <> StringRiffle[("J" <> ToString[#]) & /@ impureElements[rec["masters"]], ", "] <>
      " (the factor is on the page). Look for eps-pure replacements: the natural integrand of the subloop whose prefactor carries the factor (MCBLoopByLoopReport: a dot on its massive tadpole or bubble line, a numerator equal to its Baikov variable), the dlog candidates made exact in eps (MCBPurifyCandidates, MCBProjectedPurifyCandidates), a uniform-weight basis from the literature (rung 2), the dimension shift (rung 3). check_basis.wls adopts an eps-form basis with fewer elements that are not eps-pure by itself."]];
  hints];


(* ::Section:: *)
(*TeX and small SVGs*)


MCBTeX[expr_] := Module[{e},
  e = expr /. j[_, a__] :> Subscript["j", StringRiffle[ToString /@ {a}, ","]] /. z[i_] :> Subscript["z", i] /. eps -> "MCBEPSPH";
  StringReplace[Quiet@Check[ToString[TeXForm[e]], ToString[e, InputForm]], "\\text{MCBEPSPH}" -> "\\epsilon "]];

patternSVG[pat_List, label_] := Module[{n = Length[pat], c = 14, cells},
  cells = Table[With[{v = pat[[r, q]]},
      "<rect x='" <> ToString[(q - 1) c] <> "' y='" <> ToString[(r - 1) c] <> "' width='" <> ToString[c - 1] <> "' height='" <> ToString[c - 1] <>
        "' rx='2' fill='" <> Which[v === "0", "var(--cell-zero)", v === "rat", "var(--cell-rat)", v === {1, 1}, "var(--cell-eps1)",
          v === {0, 0}, "var(--cell-eps0)", True, "var(--cell-poly)"] <> "' stroke='var(--line)'><title>" <> esc[ToString[v]] <> "</title></rect>"],
     {r, n}, {q, n}];
  "<figure><svg width='" <> ToString[n c] <> "' height='" <> ToString[n c] <> "'>" <> StringJoin[Flatten[cells]] <> "</svg><figcaption>A_" <> esc[ToString[label]] <> "</figcaption></figure>"];

badge = CoreBadge;

epsCell[m_] := Module[{w = Lookup[m, "epsPowerWritten", Missing[]], r = Lookup[m, "epsPowerRelative", Lookup[m, "epsPower", "?"]]},
  If[MissingQ[w], "? / " <> ToString[r],
    "&epsilon;<sup>" <> ToString[w] <> "</sup>" <> If[TrueQ[Lookup[m, "epsPowerMixed", False]], " (lowest; terms differ)", ""] <> " / " <> ToString[r]]];

(* whether an element is eps-pure off the cut (MCBElementPurity), with the reason as a tooltip *)
pureCell[m_] := With[{p = Lookup[m, "epsPure", Missing["NotChecked"]], d = Lookup[m, "epsPureDetail", ""]},
  "<span title='" <> esc[d] <> "'>" <> Which[p === True, "yes", p === False,
     "<b>no</b>" <> If[StringContainsQ[d, "carries "], ": " <> esc[StringReplace[d, {__ ~~ "carries " -> "", " (up to" ~~ __ -> ""}]], ""], True, "not checked"] <> "</span>"];

generator[] := "the maximal-cut-basis skill (MaximalCutBasis " <> $MCBVersion <> ")";


(* ::Section:: *)
(*basis.html*)


(* the family of a sector or run folder, through run_info.m (for callers that do not have it, such as InvestigateDEQ.m) *)
familyOf[dir_String] := Module[{info = SelectFirst[{FileNameJoin[{dir, "run_info.m"}], FileNameJoin[{ParentDirectory[dir], "run_info.m"}]}, FileExistsQ, None], f},
  If[info === None, Return[<||>]];
  f = Lookup[Replace[Quiet@Get[info], Except[_Association] -> <||>], "FamilyFile", None];
  If[StringQ[f] && FileExistsQ[f], Replace[Quiet@MCBReadFamily[f], Except[_Association] -> <||>], <||>]];

MCBBasisHTML[dir_String, fam0_Association : <||>] := Module[{rec = MCBReadBasis[dir], att = MCBReadAttempts[dir], fam = fam0, svg, notes, ff, body, rep, geo, hints, cites},
  If[rec["status"] === "not run" && ! KeyExistsQ[rec, "sector"], Return[$Failed]];
  If[! KeyExistsQ[fam, "Propagators"], fam = familyOf[dir]];
  svg = If[KeyExistsQ[fam, "Propagators"] && ! MCBSkippedQ["draw"], Replace[Quiet@Check[MCBGraphSVG[fam, rec["sector"]], ""], Except[_String] -> ""], ""];
  (* the tools, methods and papers the run's ledger credits to the sector *)
  cites = CoreSectorCitationsHTML[CoreRunFolder[dir], rec["name"]];
  notes = With[{f = FileNameJoin[{dir, "notes.md"}]}, If[FileExistsQ[f], Import[f, "Text"], ""]];
  ff = MCBReadFFVerdict[dir];
  rep = rec["representation"]; geo = rec["geometry"];
  (* from attempts.m every time: a rung tried since basis.m was written (a check that was not adopted) is no longer advised *)
  hints = If[MCBFlaggedQ[rec], MCBRetryHints[dir, rec], {}];
  body = StringJoin[
    (* 1. header *)
    "<div class='header'><div class='meta'><h1>", esc[rec["family"]], " &middot; ", esc[rec["name"]], "</h1>",
    "<p class='muted'>Kira sector ", ToString[rec["id"]], " &middot; ", ToString[Length[rec["props"]]], " propagators</p>",
    "<p>", badge[rec["status"]], If[rec["status"] === "eps-polynomial", " <span class='muted'>&epsilon;-powers " <> esc[ToString[rec["range"]]] <> "</span>", ""], "</p>",
    "<ul class='tight'>", Table["<li><code>" <> esc[p] <> "</code></li>", {p, rec["props"]}], "</ul></div>",
    "<div class='card'>", svg, "</div></div>",
    (* 2. representation *)
    "<h2>Representation on the maximal cut</h2>",
    If[AssociationQ[rep],
      StringJoin["<p>", esc[rep["kind"]], " Baikov, loop order <code>", esc[rep["order"]], "</code>, ISPs <code>", esc[rep["isp"]],
        "</code>, cut variables <code>", esc[rep["vars"]], "</code>, d = ", ToString[rep["D0"]], " &minus; 2&epsilon;</p>",
        "<p>&epsilon; = 0 integrand = kinNorm &middot; R(z) / &radic;P(z) with \\(\\text{kinNorm} = ", MCBTeX[rep["kinNorm"]], "\\), \\(R = ", MCBTeX[rep["Rz"]],
        "\\), \\(P = ", MCBTeX[Factor[rep["Pr"]]], "\\); rational part of this representation's &Gamma; prefactor \\(", MCBTeX[rep["prefRat"]],
        "\\) (whether each element is &epsilon;-pure with it: the basis table).</p>",
        "<details><summary>cut Baikov polynomials and exponents</summary><pre>", esc[ToString[Thread[{rep["cutpolys"], rep["cutpows"]}], InputForm]], "</pre></details>"],
      "<p class='muted'>not computed</p>"],
    (* 3. geometry *)
    "<h2>Geometry</h2><p><b>", esc[Lookup[geo, "class", "?"]], "</b>: ", esc[Lookup[geo, "text", ""]], "</p>",
    If[KeyExistsQ[geo, "P"], "<p>curve \\(y^2 = " <> MCBTeX[geo["P"]] <> "\\), genus " <> ToString[geo["genus"]] <> "</p>", ""],
    If[AssociationQ[Lookup[rec, "repeatedGeometry", None]], With[{r = rec["repeatedGeometry"]},
      "<p><b>Repeated geometry</b>: the same integrals as <a href='../" <> r["sameAs"] <> "/basis.html'><code>" <> esc[r["sameAs"]] <> "</code></a> (" <>
        esc[r["status"]] <> "), with the lines <code>" <> esc[ToString[r["lines"], InputForm]] <> "</code> and the invariants <code>" <>
        esc[ToString[r["invariants"], InputForm]] <> "</code>. " <>
        If[TrueQ[Lookup[r, "mapped", False]], "Its basis, mapped, was tried first: " <> esc[Lookup[r, "outcome", "?"]] <> ".",
          "Its basis was not mapped: " <> esc[ToString[Lookup[r, "note", "?"]]] <> "."] <> "</p>"], ""],
    pfSection[rec],
    (* 4. masters *)
    "<h2>Basis on the maximal cut</h2><div class='scroll'><table><tr><th>#</th><th>definition</th><th>normalisation</th><th>power of &epsilon;<br><span class='muted'>written / relative</span></th><th>&epsilon;-pure off the cut<br><span class='muted'>&Gamma; prefactor included</span></th><th>label</th><th>provenance</th></tr>",
    Table[With[{m = rec["masters"][[i]]},
       "<tr><td>J<sub>" <> ToString[i] <> "</sub></td><td class='def'><div class='tex'>\\(" <> MCBTeX[m["definition"]] <> "\\)</div><details><summary>plain text</summary><pre>" <>
         esc[ToString[m["definition"], InputForm]] <> "</pre></details></td><td>" <>
         Which[m["normalisation"] === "rational", "rational",
           StringLength[MCBTeX[m["normalisation"]]] < 60, "\\(\\sqrt{" <> MCBTeX[m["normalisation"]] <> "}\\)",
           True, "square root<details><summary>\\(R_{" <> ToString[i] <> "}\\)</summary><div class='tex'>\\(R_{" <> ToString[i] <> "} = " <> MCBTeX[Factor[m["normalisation"]]] <> "\\)</div></details>"] <>
         "</td><td>" <> epsCell[m] <> "</td><td>" <> pureCell[m] <> "</td><td class='label'>" <> esc[m["label"]] <> "</td><td>" <> esc[m["provenance"]] <> "</td></tr>"], {i, Length[rec["masters"]]}],
    "</table></div>",
    "<p class='muted'>Common power of &epsilon; undetermined: the maximal cut only fixes the powers of &epsilon; relative to each other. ",
    "The written powers are a convention, to be fixed when the sectors are put together.</p>",
    If[Lookup[rec, "flags", {}] =!= {}, "<div class='card'><b>Flags</b><ul class='tight'>" <> StringJoin[Table["<li>" <> esc[f] <> "</li>", {f, rec["flags"]}]] <> "</ul></div>", ""],
    (* 5. DE verdicts *)
    "<h2>Maximal-cut differential equation</h2>",
    "<p><b>Kira</b> (numeric, exact in &epsilon;, ", ToString[Length[rec["points"]]], " rational points): ", badge[Lookup[rec["kiraVerdict"], "status", "not run"]], " ",
      esc[Lookup[rec["kiraVerdict"], "message", ""]], "</p>",
    If[ListQ[rec["points"]] && rec["points"] =!= {}, "<details><summary>points</summary><pre>" <> esc[ToString[rec["points"], InputForm]] <> "</pre></details>", ""],
    If[ListQ[Lookup[rec, "checks", None]] && rec["checks"] =!= {},
      "<p><b>Checks</b> (the Euler relation decides; the hard rules on masters and the shared weight are what the pole-free skill needs, reported here):</p><ul class='tight'>" <>
        StringJoin[Table["<li>" <> esc[c["Name"]] <> ": " <> Which[c["Pass"] === True, "pass", c["Pass"] === False, "<b>fail</b>", True, "not checked"] <> " &mdash; " <>
          esc[c["Detail"]] <> "</li>", {c, rec["checks"]}]] <> "</ul>", ""],
    "<p><b>FiniteFlow</b> (analytic reconstruction from IBPs on the maximal cut): ", If[AssociationQ[ff], badge[Lookup[ff, "status", "?"]] <> " " <> esc[Lookup[ff, "message", ""]],
       badge[If[MCBSkippedQ["finiteflow"], "skipped by user", "not run"]]], "</p>",
    If[AssociationQ[ff] && AssociationQ[Lookup[ff, "kiraComparison", None]],
      "<p><b>FiniteFlow against Kira</b> (the matrices at Kira's first point): " <> badge[ff["kiraComparison"]["status"]] <> " " <>
        esc[Lookup[ff["kiraComparison"], "message", ""]] <> "</p>", ""],
    If[ListQ[Lookup[rec, "dlogBasisCheck", None]] && rec["dlogBasisCheck"] =!= {},
      "<details><summary>DlogBasis cross-check of the leading singularities (expected: constants times 1/normalisation)</summary><ul class='tight'>" <>
        StringJoin[Table["<li>" <> esc[c["label"]] <> ": LS <code>" <> esc[c["LS"]] <> "</code>, normalisation <code>" <> esc[c["normalisation"]] <> "</code></li>", {c, rec["dlogBasisCheck"]}]] <>
        "</ul></details>", ""],
    If[ListQ[Lookup[rec["kiraVerdict"], "pattern", None]],
      StringJoin["<p class='muted'>&epsilon;-structure of A<sub>X</sub> at the first point:</p><div class='grid-wrap'>",
        MapThread[patternSVG, {rec["kiraVerdict"]["pattern"], Take[Lookup[rec["kiraVerdict"], "invariants",
          If[AssociationQ[Lookup[rec["kiraVerdict"], "A", None]], Keys[rec["kiraVerdict"]["A"]], Lookup[fam, "InvList", Range[Length[rec["kiraVerdict"]["pattern"]]]]]],
          UpTo[Length[rec["kiraVerdict"]["pattern"]]]]}],
        "</div><p class='legend'><span><i style='background:var(--cell-eps1)'></i>&epsilon;<sup>1</sup></span><span><i style='background:var(--cell-eps0)'></i>&epsilon;<sup>0</sup></span>",
        "<span><i style='background:var(--cell-poly)'></i>other Laurent polynomial</span><span><i style='background:var(--cell-rat)'></i>rational in &epsilon;</span></p>"], ""],
    (* 6. counts *)
    "<h2>Master counts</h2><p>maximal cut (Kira recount): <b>", ToString[rec["nMastersCut"]], "</b>; user list: <b>", ToString[rec["nMastersList"]], "</b>",
    If[rec["extraMasters"] =!= {}, ". The cut has more masters than the list; a closed DE needs them (Kira's choice among " <> esc[rec["cutMasters"]] <> "): <code>" <> esc[rec["extraMasters"]] <> "</code>", ""],
    ". <span class='muted'>Kira may choose different master integrals than the list; the count is what matters.</span></p>",
    (* 7. history *)
    "<h2>How this basis was found</h2>",
    If[att === {}, "<p class='muted'>no attempts recorded</p>",
      StringJoin["<div class='scroll'><table><tr><th>date</th><th>rung</th><th>what</th><th>outcome</th><th>time</th></tr>",
        Table["<tr><td>" <> esc[Lookup[a, "date", ""]] <> "</td><td>" <> esc[ToString[Lookup[a, "rung", ""]]] <> "</td><td>" <> esc[ToString[Lookup[a, "what", ""]]] <>
          "</td><td>" <> esc[ToString[Lookup[a, "outcome", ""]]] <> "</td><td>" <> esc[ToString[Lookup[a, "time", ""]]] <> "</td></tr>", {a, att}], "</table></div>"]],
    If[notes =!= "", "<div class='card'>" <> CoreMarkdown[notes] <> "</div>", ""],
    If[rec["skipped"] =!= {}, "<p class='muted'>skipped by user: " <> esc[StringRiffle[rec["skipped"], ", "]] <> "</p>", ""],
    (* 8. references *)
    "<h2>References and tools</h2>",
    If[cites === "", "<p class='muted'>No tool, method or paper is recorded for this sector (every one of the run: <code>CITATIONS.md</code>).</p>", cites],
    (* 9. retry *)
    If[hints =!= {}, "<h2>This sector can be retried</h2><div class='card retry'><p>Next things to try, in order:</p><ol>" <>
       StringJoin[Table["<li>" <> esc[h] <> "</li>", {h, hints}]] <> "</ol></div>", ""]];
  CorePage[FileNameJoin[{dir, "basis.html"}], rec["family"] <> " " <> rec["name"], body, generator[]]];


(* ::Section:: *)
(*summary.html, masters_all.m*)


plural[n_Integer, word_String] := ToString[n] <> " " <> word <> If[n == 1, "", "s"];

(* the family name, else the name of the run folder with "." and ".." resolved (a run folder given as "." has a real name) *)
runTitle[runDir_String, fam_Association] := If[KeyExistsQ[fam, "NameString"], fam["NameString"],
    Last[Fold[Which[#2 === "." || #2 === "", #1, #2 === ".." && #1 =!= {}, Most[#1], True, Append[#1, #2]] &, {}, FileNameSplit[ExpandFileName[runDir]]], "run"]] <>
   ": maximal-cut bases";

MCBSummaryHTML[runDir_String, fam_Association : <||>] := Module[{dirs, recs, rows, flagged, ok, allJ, counts, body, ffOf},
  dirs = Select[FileNames["j*", runDir], DirectoryQ[#] && StringMatchQ[FileNameTake[#], RegularExpression["j[01]+"]] &];
  recs = Table[Join[MCBReadBasis[d], <|"dir" -> d|>], {d, dirs}];
  recs = Select[recs, KeyExistsQ[#, "name"] || #["status"] === "not run" &];
  recs = Table[If[KeyExistsQ[r, "name"], r, Join[r, <|"name" -> FileNameTake[r["dir"]], "sector" -> SectorFromName[FileNameTake[r["dir"]]],
       "id" -> SectorID[SectorFromName[FileNameTake[r["dir"]]]], "masters" -> {}, "geometry" -> <|"class" -> "?"|>, "nMastersCut" -> "?", "nMastersList" -> "?"|>]], {r, recs}];
  recs = SortBy[recs, {Total[#["sector"]], #["id"]} &];
  ffOf[r_] := With[{v = MCBReadFFVerdict[r["dir"]]}, If[AssociationQ[v], Lookup[v, "status", "?"], "not run"]];
  flagged = Select[recs, MCBFlaggedQ]; ok = Select[recs, ! MCBFlaggedQ[#] &];
  allJ = Flatten[Table[Table[{r["name"], i, r["masters"][[i]]["definition"]}, {i, Length[r["masters"]]}], {r, recs}], 1];
  Put[allJ, FileNameJoin[{runDir, "masters_all.m"}]];
  counts = Counts[#["status"] & /@ recs];
  (* CITATIONS.md, from the run's ledger, like the block of this page *)
  CoreWriteCitations[runDir];
  rows[list_] := StringJoin[Table[
      "<tr><td><a href='" <> r["name"] <> "/basis.html'><code>" <> r["name"] <> "</code></a></td><td>" <> ToString[r["id"]] <> "</td><td>" <>
        ToString[Total[r["sector"]]] <> "</td><td>" <> ToString[r["nMastersList"]] <> " / " <> ToString[r["nMastersCut"]] <> "</td><td>" <>
        If[pfLabel[r] =!= "", esc[pfLabel[r]] <> "<br><span class='muted'>Baikov: " <> esc[Lookup[r["geometry"], "class", "?"]] <> "</span>",
          esc[Lookup[r["geometry"], "class", "?"]]] <> "</td><td>" <> badge[r["status"]] <>
        If[r["status"] === "eps-polynomial", " <span class='muted'>" <> esc[ToString[Lookup[r, "range", ""]]] <> "</span>", ""] <> "</td><td>" <> esc[ffOf[r]] <> "</td></tr>",
      {r, list}]];
  body = StringJoin[
    "<h1>", esc[runTitle[runDir, fam]], "</h1>",
    "<p class='muted'>", plural[Length[recs], "sector"], ", ", plural[Length[allJ], "basis integral"], "</p>",
    "<div class='totals'>", KeyValueMap["<div class='card'><b>" <> ToString[#2] <> "</b>" <> badge[#1] <> "</div>" &, counts], "</div>",
    If[flagged =!= {}, "<h2>Sectors that need attention (" <> ToString[Length[flagged]] <> ")</h2><p class='muted'>Each can be retried: its page lists what to try next.</p>" <>
       "<div class='scroll'><table><tr><th>sector</th><th>id</th><th>props</th><th>masters list/cut</th><th>geometry</th><th>status</th><th>FiniteFlow</th></tr>" <> rows[flagged] <> "</table></div>", ""],
    "<h2>Sectors with a basis (", ToString[Length[ok]], ")</h2>",
    "<div class='scroll'><table><tr><th>sector</th><th>id</th><th>props</th><th>masters list/cut</th><th>geometry</th><th>status</th><th>FiniteFlow</th></tr>", rows[ok], "</table></div>",
    CoreCitationsHTML[runDir],
    "<p class='muted'>Every basis integral, sector by sector: <code>masters_all.m</code>.</p>"];
  CorePage[FileNameJoin[{runDir, "summary.html"}], runTitle[runDir, fam], body, generator[]]];


End[];
EndPackage[];
