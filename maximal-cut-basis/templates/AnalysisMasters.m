(* ::Package:: *)

(* ::Title:: *)
(*{{FAMILY}} sector {{SECTORNAME}} (Kira sector {{SECTORID}}): maximal-cut analysis*)


(* ::Text:: *)
(*Written by the maximal-cut-basis skill ({{DATE}}); edit it freely.  Run it with*)
(*    {{WS}} AnalysisMasters.m      (bin/ws waits for a free licence slot; keep any log of it outside the run folder)*)
(*or open it in the FrontEnd and evaluate section by section.  Every section prints what it found.*)
(*Record your reasoning in the Text cells and in notes.md: it appears in basis.html.  Record every paper you*)
(*use with MCBRecordLiterature, and every tool you ran by hand with CoreRecordTool (end of section 8), so that*)
(*their authors are acknowledged.*)
(*{{AUTONOTE}}*)


(* ::Section:: *)
(*1. Init*)


$SectorDir = DirectoryName[$InputFileName /. "" :> FileNameJoin[{NotebookDirectory[], "x"}]];
Get["{{LIBFILE}}"];
(* this kernel's marks start empty (a FrontEnd kernel's earlier marks are not this sector's), and what this script uses
   is credited to the sector in the run's ledger (citations.m) *)
MCBResetToolsUsed[];
CoreCitationContext[$SectorDir, "{{SECTORNAME}}", "AnalysisMasters.m"];
MCBLoadPaths[{{PATHSFILE}}];
$MCBSkip = {{SKIP}};

fam = MCBReadFamily["{{FAMILYFILE}}"];
sector = {{SECTOR}};
(* the points of the sector's current basis, so that the checks compare like with like; else the seed's *)
pts = Replace[Lookup[MCBReadBasis[$SectorDir], "points", {}], {} :> MCBPoints[fam, 2, {{SEED}}]];
$MCBKiraTimeLimit = {{KIRATL}}; $MCBKiraMemoryLimit = {{KIRAMEM}};
Print["sector ", SectorName[sector], ": ", Table["D" <> ToString[i] <> " = " <> MCBPropLabel[fam, i], {i, PropPos[sector]}]];


(* ::Section:: *)
(*2. Representations*)


(* ::Text:: *)
(*Loop-by-loop representations with the fewest ISPs for every loop order, plus standard Baikov, sorted by the*)
(*geometric score {variables, max square-root degree, square-root factors, ISPs}.  Choose one; say why.*)


reps = MCBRepresentations[fam, sector{{REPOPTS}}];
Print[MCBRepresentationTable[reps]];
cd = reps[[{{REPINDEX}}]];


(* ::Section:: *)
(*3. Geometry*)


Print["cut polynomials^exponents: ", Thread[{cd["cutpolys"], cd["cutpows"]}]];
Print["eps = 0 integrand = kinNorm Rz/Sqrt[Pr]: ", cd["split"]];
Print["Gamma prefactor, rational part: ", cd["prefRat"]];
Print["geometry: ", cd["geometry"]["text"]];
If[cd["geometry"]["class"] === "curve", Print["curve: ", MCBCurve[cd]]];
If[Length[cd["vars"]] >= 2, Print[TableForm[MCBFibrationTable[cd]]]];


(* ::Section:: *)
(*4. Masters on the maximal cut*)


cut = MCBCutMasters[fam, sector, FileNameJoin[{$SectorDir, "kira", "count"}], First[pts]];
Print["masters on the cut: ", cut["n"], " ", cut["masters"], "   (user list: ", Length[cut["userMasters"]], ")"];
nmi = cut["n"];


(* ::Section:: *)
(*5. Candidates*)


(* ::Text:: *)
(*Route of the chosen representation: {{ROUTE}}.  {{CANDNOTE}}*)
(*steps says how the candidates are built: each step is a representation ("rep", Automatic = cd above), a function of*)
(*the toolkit ("call") and its options, as the automatic pass ran it; MCBReplayCandidates runs them again.  Add steps,*)
(*or extend cands by hand: MCBCandidate[fam, sector, K, <|"r2" -> R, "label" -> "...", "provenance" -> "agent"|>]*)
(*stands for Sqrt[R] K.*)


steps = {{STEPS}};
cands = MCBReplayCandidates[fam, sector, reps, steps, <|"cd" -> cd, "nmi" -> nmi, "dir" -> $SectorDir|>];
Print[Length[cands], " candidates from ", Length[steps], " step(s): ", Lookup[steps, "call", {}]];


(* ::Section:: *)
(*6. Maximal-cut DE (Kira) and choice of the basis*)


red = If[cands === {}, $Failed, MCBReduceCandidates[fam, sector, cands, FileNameJoin[{$SectorDir, "kira"}], pts]];
(* a non-dlog sector: an eps-polynomial status or a label that is not polylogarithmic *)
nondlog = MCBNonDlogQ[Lookup[MCBReadBasis[$SectorDir], "status", ""], Lookup[MCBReadBasis[$SectorDir], "classification", None]];
(* on a dlog sector every candidate gets its purity verdict, so that the search puts the eps-pure ones first
   (MCBCandidatePurity); on a non-dlog sector a tie of spreads goes to a subset with an undotted element (the all-dot
   tie-breaker) *)
If[! nondlog, cands = MCBCandidatePurity[reps, cands, <|"Budget" -> 300|>]];
res = If[red === $Failed, $Failed, MCBSearchBasis[red, cands, nmi, <|"NonDlog" -> nondlog, "Sector" -> sector|>]];
Print["search: ", If[AssociationQ[res], KeyTake[res, {"status", "k", "range"}], "no candidates"]];

(* the basis: Automatic takes the search result; or write the list of expressions (as in masters.m) *)
basis = {{BASIS}};
labels = {{LABELS}};
provenance = {{PROVENANCE}};
(* the basis this script was written for (masters.m when it was generated): compared with below *)
written = {{WRITTEN}};
(* masters.m changes only when this basis is better than the current one (the rule of check_basis.wls); adopt = True
   replaces it anyway, for instance after a tie-breaker *)
adopt = False;
(* the purity verdicts of the search's elements go to basis.m with them (a written basis gets its own, checked there) *)
purity = {};
If[basis === Automatic && AssociationQ[res] && KeyExistsQ[res, "cands"],
  basis = MapThread[MCBMasterExpression, {res["cands"], Lookup[res, "k", ConstantArray[0, Length[res["cands"]]]]}];
  labels = Lookup[#, "label", ""] & /@ res["cands"]; provenance = Lookup[#, "provenance", "auto"] & /@ res["cands"];
  purity = KeyTake[#, {"pure", "pureDetail", "strict"}] & /@ res["cands"]];
If[basis === Automatic, Print["no basis: the search found none; add steps or candidates, or write the basis by hand"]; Abort[]];
check = MCBCheckBasis[fam, sector, basis, FileNameJoin[{$SectorDir, "kira", "check"}], <|"Points" -> pts|>];
Print["check: ", check["status"], "  ", check["message"]];
(* eps-form up to eps^k: write the normalised basis *)
If[check["status"] === "eps-form", basis = MapThread[eps^#2 #1 &, {basis, check["k"]}]];
MCBPrintDE[check];
(* is this the basis the script was written for, and does masters.m still hold that one? *)
current = MCBReadMasters[$SectorDir];
If[written =!= {}, Print[If[MCBSameBasisQ[basis, written], "this is the basis the script was written for",
   "NOTE: this basis differs from the one the script was written for"]]];
If[ListQ[current] && written =!= {} && ! MCBSameBasisQ[current, written] && ! MCBSameBasisQ[current, basis],
  Print["NOTE: masters.m has changed since this script was written (attempts.m says how); this script's basis replaces it only ",
    "when it is better, or with adopt = True"]];


(* ::Section:: *)
(*7. FiniteFlow (analytic confirmation)*)


(* ::Text:: *)
(*Once masters.m is written (section 8), run  bin/finiteflow_sector.sh <this folder>.  It writes finiteflow/ (IBPs*)
(*from LiteIBP on the maximal cut, FiniteFlow's sparse solver, an analytic reconstruction of the DE), compares*)
(*the matrices with Kira's, and rewrites the pipeline by itself whenever masters.m changes.*)


(* ::Section:: *)
(*8. Result and reasoning*)


(* the ladder rung this script implements: 1 while it reproduces the automatic pass; change it when you change the analysis.
   When this script only chooses between equally good bases (a tie-breaker of SKILL.md), set rung = "tie-breaker" and
   adopt = True: the history then shows a tie-breaker, not a rung of the ladder *)
rung = {{RUNG}};
chosen = MapThread[Join[MCBSplitMaster[#1], <|"label" -> #2, "provenance" -> #3|>, #4] &,
   {basis, PadRight[Flatten[{labels}], Length[basis], ""], PadRight[Flatten[{provenance}], Length[basis], "agent"],
    If[Length[purity] == Length[basis], purity, ConstantArray[<||>, Length[basis]]]}];
flags = If[cut["userMasters"] =!= {} && cut["n"] > Length[cut["userMasters"]],
   {"the maximal cut has " <> ToString[cut["n"]] <> " masters, the user list " <> ToString[Length[cut["userMasters"]]] <> ": a closed DE needs all of them"}, {}];
old = MCBReadBasis[$SectorDir];
(* the Picard-Fuchs classification of the first pass (or bin/picard_fuchs.wls) decides the non-dlog question when it has a label *)
status = MCBStatusFor[check, reps, Lookup[old, "classification", None]];
(* the purity of each element (MCBCandidatePurity): between two eps-form bases, the one with fewer elements that are
   not eps-pure is better. An element the current basis.m has judged keeps that verdict (MCBKeptPurity); one the search
   left open (a timeout) is checked again *)
chosen = MapThread[Join[If[MissingQ[Lookup[#1, "pure", Missing[]]], KeyDrop[#1, {"pure", "pureDetail"}], #1], #2] &, {chosen, MCBKeptPurity[old, basis]}];
chosen = MCBCandidatePurity[reps, chosen, <|"TimeLimit" -> 120|>];
Print["eps-pure: ", Lookup[chosen, "pure"]];
If[adopt || MCBBetterBasisQ[status, Lookup[check, "range", {}], old, <|"masters" -> basis, "purity" -> Lookup[chosen, "pure"]|>],
  MCBWriteMasters[$SectorDir, basis];
  MCBAppendAttempt[$SectorDir, <|"rung" -> rung, "what" -> "AnalysisMasters.m", "outcome" -> status|>];
  (* a basis that did not change keeps its definitions as basis.m has them, so that its key stays *)
  record = MCBBasisRecord[fam, sector, <|"cd" -> cd, "check" -> check, "cands" -> chosen, "reps" -> reps,
     "definitions" -> With[{d = Lookup[#, "definition", None] & /@ Select[Lookup[old, "masters", {}], AssociationQ]}, If[MCBSameBasisQ[basis, d], d, None]],
     "status" -> status, "flags" -> flags, "k" -> ConstantArray[0, Length[basis]], "classification" -> Lookup[old, "classification", Missing["NotRun"]],
     "dlogBasisCheck" -> Quiet@TimeConstrained[MCBDlogBasisCheckCandidates[reps, chosen], 600, {}]|>];
  If[MCBFlaggedQ[record], record["retryHints"] = MCBRetryHints[$SectorDir, record]];
  MCBWriteBasis[$SectorDir, record],
  MCBAppendAttempt[$SectorDir, <|"rung" -> rung, "what" -> "AnalysisMasters.m",
     "outcome" -> status <> " (not adopted: the current basis, " <> Lookup[old, "status", "?"] <> ", is as good or better)"|>];
  Print["not adopted: the current basis (", Lookup[old, "status", "?"], ") is as good or better; set adopt = True to replace it"]];
MCBBasisHTML[$SectorDir, fam];

(* A paper you used for this sector (a basis, a map of propagators, an idea): record it, so that its authors are
   acknowledged on the pages and in CITATIONS.md; "result" says whether its basis was adopted, and "basisKey" which
   basis that is (a later basis of the sector then lists the paper as consulted), e.g.
   MCBRecordLiterature[$SectorDir, <|"reference" -> "A. Author, B. Author, Title, JHEP 01 (2020) 001, arXiv:2001.00001",
     "used" -> "the canonical basis of their eq. (3.2), mapped by k1 -> -k1", "rung" -> 2, "outcome" -> "eps-form",
     "result" -> "adopted", "basisKey" -> CoreBasisKey[MCBReadBasis[$SectorDir]]|>]
   A tool you ran by hand for this basis (INITIAL, Libra, Fuchsia, ...: a name of $MCBTools; the provenance of an element
   credits nothing): CoreRecordTool[$SectorDir, {"INITIAL"}, "declared"] *)
