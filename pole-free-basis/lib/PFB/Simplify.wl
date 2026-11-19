(* ::Package:: *)

(* ::Title:: *)
(*PoleFreeBasis`Simplify`: the simplification phase, once the system is pole-free*)


(* ::Text:: *)
(*A pole-free basis can still have DE entries of high degree in the invariants. The phase (bin/simplify.wls, step 7*)
(*of the workflow in SKILL.md) lowers them by changes of basis that keep the census. Its objective is lexicographic,*)
(*{the highest degree of a term in the system, the number of terms at it, the sum over terms} (PFBDegreeObjective), as*)
(*FFAllDegrees measures it on the learned system of each sector (lib/PFB/Degrees.wl); nothing is reconstructed.*)
(**)
(*A move is a pluggable proposal ($PFBSimplifyMoves): it proposes candidate changes of basis, each written as T =*)
(*<|label -> combination of ut[k]|>; the phase measures every candidate as a variant of the degree job of each sector whose*)
(*rows it changes (one job per sector, learned once), takes the candidate with the lowest measured objective below the*)
(*current one, and sends it through PFBTryChange (rung "simplify", PFBSimplifyGate), which records it like any change.*)
(**)
(*Move (i), the global letter rescaling: U_i -> r_i U_i with r_i = (unit scale)^k_i Prod_l l^a_il, l the usable letters*)
(*(PFBKnownSingularities "Letters"), k_i fixed by the mass dimension. From the letter content of every entry (the*)
(*multiplicities of the known singularities in its numerator and denominator), the degrees after the rescaling are*)
(*predicted exactly off the diagonal (the net exponent of l in A_ij becomes num_l - den_l + a_il - a_jl) and bounded on the*)
(*diagonal (d log r_i joins the eps^0 term); an integer program over the a_il minimises the predicted objective*)
(*(PFBRescaleProgram).*)
(**)
(*The moves after (i) follow the worst entry (PFBWorstMasters: the master whose row or column carries the highest term*)
(*degrees). Move (ii), swaps: the worst master replaced by another integral of its sector, alone or with one more master,*)
(*from the sets the scans find on a reduction at the slice point that keep the census exactly (PFBSwapCandidates),*)
(*ranked by the digit height of the rows they change and measured as variants whose T^-1 the degree job evaluates*)
(*inside its graph. Move (iii), shifts: the worst row shifted by lower masters, U_i -> U_i + Sum_k c_k U_k, with c_k fitted*)
(*to a low-degree ansatz from exact samples of the learned system along lines (PFBShiftProblem, PFBShiftFit): the new*)
(*row is affine in the ansatz, every term must become N/Q of the target degree, nothing high is reconstructed. A move*)
(*may ask for jobs of its own first ("jobs": the phase records it as preparing). Move (iv), lighter completions: the*)
(*corrections of a fitted completion (rung 6) solved again the same way, with degree as the objective (PFBCompletionFit).*)
(*reference/simplify.md.*)


BeginPackage["PoleFreeBasis`Simplify`", {"PoleFreeBasis`", "PoleFreeBasis`Config`", "PoleFreeBasis`System`", "PoleFreeBasis`Singularities`", "PoleFreeBasis`Slice`",
  "PoleFreeBasis`Census`", "PoleFreeBasis`Subtree`", "PoleFreeBasis`Transform`", "PoleFreeBasis`Rungs`", "PoleFreeBasis`Gate`", "PoleFreeBasis`Records`", "PoleFreeBasis`Degrees`",
  "PoleFreeBasis`MaxCut`", "MaximalCutBasis`", "MaximalCutBasis`Rules`", "MaximalCutBasis`Sectors`", "SkillCore`Tools`", "SkillCore`Records`", "SkillCore`Pages`", "SkillCore`Citations`"}];

$PFBSimplifyMoves::usage = "$PFBSimplifyMoves is the list of the simplification phase's moves, in the order the phase tries them: each <|\"Name\", \"Title\", \"Propose\" -> f|>, f[ctx, table, phase, opts] returning <|\"Status\" -> \"proposed\" | \"no gain\" | \"skipped\" | \"jobs\", \"Message\", \"Candidates\" -> {<|\"Name\", \"T\" -> <|label -> combination of ut[k], or new definition in integrals|> (every changed master, images included), \"Predicted\" (a degree summary or Missing), \"Info\"|>, ...}, \"Info\"|>. \"jobs\" asks for jobs of the move's own first (\"Jobs\", \"Keys\" (their sectors, for the cost), \"Prep\" (what the move needs to go on), \"Cost\" (optional)): once they are done, f is called again with opts \"Record\" -> its record (with \"Prep\"); opts \"MoveId\" is the move's id. The phase measures, chooses and gates the candidates (reference/simplify.md, \"Adding a move\").";
PFBSimplifyPrecondition::usage = "PFBSimplifyPrecondition[sys, state, census, opts] says whether the simplification phase may start: no bad entry (finite pole, negative power of eps, entry above the cap) outside flagged sectors, and no change other than the phase's own waiting for approval. A hidden-weight hint of the census (a clean sector that may carry a weight, PFBCensus \"HiddenWeights\") does not block the phase: its sector has no bad entry, and the sectors where its poles show are flagged; the hints whose lower-sector scan was not recorded (opts \"Tried\": PFBHiddenWeightTried) on sectors that can still change are returned under \"Hints\" for the phase's message. Returns <|\"Pass\", \"Reasons\", \"Sectors\" (bad sectors not flagged), \"Flagged\", \"Hints\"|>.";
PFBSimplifyBudgetProposal::usage = "PFBSimplifyBudgetProposal[table, opts] proposes the budget of the simplification moves (wall-clock seconds of their degree jobs) from the measured job times of each sector in the degree table (\"JobWallSeconds\": the job's kernel; \"JobSeconds\": its degree measurement): one round costs Sum over the measured sectors of (job + V measurement) with V variants per job (opts \"Variants\", default 4), and the proposal is R rounds (opts \"Rounds\", default 3). Returns <|\"Seconds\", \"Round\", \"Variants\", \"Rounds\", \"PerSector\" -> <|key -> <|\"Job\", \"Measure\"|>|>, \"Untimed\" (measured sectors without a job time), \"Text\"|>.";
PFBMCBNormalisations::usage = "PFBMCBNormalisations[sys, key] reads the maximal-cut-basis run of the sector's base family (system.wl family entry \"MCBRun\" -> its run folder, read only) and returns, for every current master of the sector whose part on the sector's own integrals is a rational multiple of a rational element of that run (normalisation \"rational\", no square root), <|label -> <|\"Ratio\" (element / master, free of eps), \"Element\", \"Folder\"|>|>: the rescalings that move (i) tries first. <||> without a run, or when nothing matches. The run's credits of the sector are taken when a change takes such a rescaling (PFBTryChange, info \"MCBSectors\").";
PFBRescaleModel::usage = "PFBRescaleModel[ctx, table, opts] is the data of move (i) on the degree table of the current slice: the masters that may be rescaled (\"Free\": base-family masters, their images following through the maps) and why the others may not (\"Protected\" -> <|label -> reason|>: frozen families, flagged sectors, sectors whose own block is eps-form or zero, rows of a sector that is not measured, an image master missing from the slice, no usable letter), the usable letters (\"Letters\" -> <|label -> <|probe -> <|\"Letter\", \"Dim\"|>|>|>), each master's exponent of every probe as a linear form in the unknowns (\"E\"), the bounds (opts \"Bound\", default 2), the starting point of maximal-cut-basis's normalisations (\"Initial\"), and the terms: \"Off\" (multiplied by r_i/r_j: predicted exactly), \"Diag\" (the eps^0 or whole term of a rescaled master's own entry, which gains d log r_i: bounded), \"New\" (a diagonal entry without an eps^0 term, which may gain one), \"Fixed\" (the degrees of the terms nothing changes), \"Current\" (the objective of the table).";
PFBPredictDegrees::usage = "PFBPredictDegrees[model, exponents] predicts the kinematic degrees after the rescaling exponents = <|label -> <|probe -> a|>|> of free masters (their unit-scale powers follow): exact off the diagonal, an upper bound for the eps^0 term of a rescaled master's own entry. Returns <|\"Highest\", \"Count\", \"Sum\", \"Terms\", \"Objective\"|>.";
PFBRescaleProgram::usage = "PFBRescaleProgram[model, opts] minimises the predicted objective of move (i) over the integer exponents: an integer program (LinearOptimization: first the highest degree, then the sum of the term degrees at that height; each stage limited to opts \"SolverTime\" seconds, default 60, and skipped above opts \"MaxVariables\", default 6000), then a coordinate search on the exact lexicographic objective {highest, terms at it, sum} from the program's point, from no rescaling and from maximal-cut-basis's normalisations, ties going to the point closest to the starting one. Returns <|\"Status\", \"Exponents\", \"Units\", \"Predicted\", \"Objective\", \"Program\" (what each stage gave), \"Seconds\"|>.";
PFBRescaleCandidates::usage = "PFBRescaleCandidates[ctx, model, solution, opts] are the candidates of move (i) to measure: the program's rescaling (\"ip\"), maximal-cut-basis's normalisations (\"mcb\"), and partial rescalings (\"partial1\", ...: the masters of the program's solution added one at a time, best predicted first), those predicted below the current objective, at most opts \"MaxCandidates\" (default 6). Each <|\"Name\", \"Exponents\", \"Units\", \"Rescalings\" -> <|label -> r(invariants)|> (images included), \"T\" -> <|label -> r ut[label]|>, \"Predicted\", \"Objective\"|>.";
PFBRescaleFactor::usage = "PFBRescaleFactor[model, label, exponents, unit] is the rescaling factor (unit scale)^unit Prod l^a of a free master: a rational function of the invariants of mass dimension 0.";
PFBWorstMasters::usage = "PFBWorstMasters[table, opts] ranks the masters by the kinematic degrees their row and column carry in a degree table (the measured sectors): worst first, by {highest term degree, terms at it, sum} over the terms of the master's row and column (an entry counted once). Moves (ii) to (iv) follow the worst master. opts \"Labels\" (only these masters). Returns {<|\"Label\", \"Objective\", \"RowObjective\", \"ColumnObjective\", \"Worst\" -> {<|\"Matrix\", \"Row\", \"Column\", \"Power\", \"Degree\"|>, ...} (the terms at the highest), \"Side\" -> \"row\" | \"column\" | \"both\"|>, ...}.";
PFBMovableMasters::usage = "PFBMovableMasters[ctx, table, opts] lists the base-family masters that moves (ii) to (iv) may change (their images follow by the maps) and why the others may not, as for move (i): a frozen family, a flagged sector, a missing image, a sector that is not measured, rows of a sector that is not measured; with opts \"EpsForm\" -> True also a sector whose own block is eps-form or zero. Returns <|\"Free\", \"Protected\" -> <|label -> reason|>, \"Images\" -> <|label -> {image family -> label}|>|>.";
PFBSimplifySliceCheck::usage = "PFBSimplifySliceCheck[sys, slOld, censusOld, slNew, opts] is what the slice decides of a simplification before any job: no row gains a finite pole, the census gains no pole, no negative power of eps and no entry above the cap (opts \"MaxEpsDegree\"), no entry rises above the cap, and every eps-form block of a sector's own rows stays eps-form (the checks of PFBSimplifyGate on the slice). Returns <|\"Pass\", \"Reasons\", \"Census\", \"Comparison\"|>.";
PFBSwapCandidates::usage = "PFBSwapCandidates[ctx, red, cal, key, master, opts] (move (ii)) are the swaps of a master: other sets of the sector's masters that the scans find (PFBScanSets on the reduction red at the slice point, with its pool's natural integrals of the sector), with the master alone in its slot or with one more master of the sector (opts \"Pairs\", default True), that clear the sector's rows and keep the census exactly on the slice (PFBSimplifySliceCheck). Each candidate integral carries the slot's power of eps and a normalisation that keeps the master's mass dimension: a power of the unit scale (\"unit\"), or the master's coefficient on its own sector times one (\"inherit\"). Ranked by the digit height of the rows the swap changes (PFBDigitHeight), the best opts \"MaxSwaps\" (default 3) kept. opts: \"SwapWeight\" (dots plus numerator powers, default 1), \"MaxSwapSets\" (default 200), \"Partners\" (the masters a pair may take as its second master, default every base-family master of the sector; move (ii) gives the free masters of PFBMovableMasters), \"MaxEpsDegree\". Returns <|\"Candidates\" -> {<|\"Set\" (base-family definitions), \"Defs\" (images added), \"Integrals\", \"Normalisation\", \"Height\", \"HeightBefore\", \"Rows\", \"Det\", \"MaxCutChanged\"|>, ...}, \"Sets\", \"Clear\", \"Passed\", \"Seconds\", ...|>.";
PFBShiftProblem::usage = "PFBShiftProblem[ctx, table, label, opts] (move (iii)) sets up the fit of a shift of master i = label by the lower masters of its family that its row couples to (a proper subsector, coupled on the slice, not coupling back): U_i -> U_i + Sum_k c_k U_k, c_k = eps^q_k (q_k = the power of eps of master i minus that of master k, rule 1) times a combination of monomials of the invariants of total degree <= opts \"ShiftDegree\" (default 2), each of the mass dimension of U_i / U_k by a power of the unit scale, also divided by one letter of row i's terms in column k (opts \"ShiftLetters\", default True). Row i becomes A_ij + Sum_k c_k A_kj - A_ii c_j + d c_j + c_j dlog(pref_i / pref_j), affine in the unknowns. The targets: every term of row i in the columns the shift changes, at each power of eps of the Laurent range (0 or lower .. the cap), at degree <= its current highest - 1 first. The samples: points on random lines (the fit's, and one to check it), at hi - lo + 2 values of eps, for the job of rows i and k (PFBDegreesJob with \"Measure\" -> False). Bounded by opts \"MaxUnknowns\" (60: letters dropped first, then the degree, then lower masters), \"MaxSamples\" (1000), \"MaxLower\" (6). Returns the problem (\"Points\" the samples, \"Unknowns\", \"Terms\", \"Start\" the first target, ...) or a String saying why there is none.";
PFBFitJobCost::usage = "PFBFitJobCost[table, key, n] is the estimated cost (seconds) of the job of a fit with n samples of sector key, from the degree table: the sector's census job time plus its degree measurement time once per 100 samples, at least twice. Moves (iii) and (iv) give it to the phase as the cost of their own job.";
PFBShiftFit::usage = "PFBShiftFit[problem, degreesJob, opts] fits the shift of PFBShiftProblem from the job's exact samples (PFBReadDegreeJob of a samples-only degree job): for each target d (the problem's \"Start\", then lower, at most \"MaxTargets\"), every target term must be N/Q on every fit line with N of degree <= d (vanishing differences of order d + 1 at equally spaced points) and Q a product of the letters of the term's contributions of degree <= d (tried largest first); each eps^p coefficient is read from the samples at several values of eps, every value beyond the range a check. One linear solve over the rationals, the most complex unknowns set to zero while a solution remains, then the check line. Returns <|\"Status\" -> \"solved\" | \"no solution\", \"Solutions\" -> {<|\"Target\", \"Coefficients\" -> <|k -> c_k|>, \"Free\", \"Equations\"|>, ...}, \"Best\" (the lowest target), \"Message\", \"Unknowns\", \"Samples\", \"Seconds\"|>. Nothing is reconstructed: the unknowns are the ansatz's.";
PFBCompletedMasters::usage = "PFBCompletedMasters[ctx] lists the masters whose definitions an accepted completion (rung 6) wrote and no later change replaced: {<|\"Change\" (its id), \"Key\", \"Labels\" (base family, in the slice)|>, ...}.";
PFBCompletionProblem::usage = "PFBCompletionProblem[ctx, table, completion, opts] (move (iv)) sets up the fit of a completion again, with degree as the objective: completion from PFBCompletedMasters; its correction integrals w (the lower-sector integrals of the definitions, each with one power of eps) keep their powers of eps, and their coefficients change by Delta C_w, combinations of monomials of their mass dimension (degree <= opts \"CompletionDegree\", default 2, also over a letter of the old coefficient's denominator) and of the old coefficient itself (so that w may drop out). The new rows are affine in the unknowns given the samples of w and of its derivatives on the masters (a degree job with \"SampleExprs\"); targets and samples as for PFBShiftProblem, with two values of eps beyond the range. Returns the problem or a String saying why there is none.";
PFBCompletionFit::usage = "PFBCompletionFit[problem, degreesJob, opts] fits the corrections of PFBCompletionProblem from the job's samples (rows, \"Exprs\", \"DExprs\"), as PFBShiftFit does: <|\"Status\", \"Solutions\" -> {<|\"Target\", \"Corrections\" -> <|label -> <|w -> Delta C_w|>|>, ...|>, ...}, \"Best\", \"Columns\" (those the corrections reach), \"Message\", \"Unknowns\", \"Samples\", \"Seconds\"|>.";
PFBSimplifyStep::usage = "PFBSimplifyStep[ctx, opts] runs the simplification phase as far as it can without waiting (bin/simplify.wls): the precondition, the degree census of the current slice (writes the sectors' degree jobs, or collects them), the budget (run.wl \"SimplifyBudget\", or opts \"Budget\" -> seconds | \"proposed\" after the user's answer), \"TargetKinDegree\", then the moves of $PFBSimplifyMoves (those named by run.wl \"SimplifyMoves\" or opts \"Moves\", default all): a move's own jobs first when it asks for them (status \"preparing\"), then its candidates are measured in degree jobs and the best goes through PFBTryChange (rung \"simplify\"). Returns <|\"Outcome\" -> \"done\" | \"refused\" | \"jobs\" | \"budget\" | \"approval\" | \"error\", \"Message\", \"Command\", \"Jobs\", \"Proposal\", \"Phase\", \"Context\"|>; phase in simplify/phase.m.";
PFBReadPhase::usage = "PFBReadPhase[runDir] reads simplify/phase.m, the record of the simplification phase, or None.";
PFBSimplifyReport::usage = "PFBSimplifyReport[runDir, state] collects what the reports show of the kinematic degrees: \"Stages\" (the starting degrees when measured, after the pole-free work, after the simplification phase: each <|\"Stage\", \"Label\", \"Summary\"|> or Missing), \"Sectors\" (per sector: highest, terms at it, sum and the unexplained denominator degree after the pole-free work and now), \"Phase\" (simplify/phase.m), \"Phases\" (every phase of the run, oldest first: the ones --new kept as simplify/phase_<date>.m, then phase.m) and \"Moves\" (of every phase).";
PFBSimplifyMarkdown::usage = "PFBSimplifyMarkdown[runDir, sys, state] is the CHANGES.md section on the kinematic degrees and the simplification phase (\"\" when no degree was measured).";
PFBSimplifyHTML::usage = "PFBSimplifyHTML[runDir, sys, state] is the summary.html section on the kinematic degrees and the simplification phase (\"\" when no degree was measured).";

Begin["`Private`"];


(* ::Section:: *)
(*Helpers*)


totDeg[p_, xs_] := Module[{lam}, Exponent[Expand[p /. Thread[xs -> lam xs]], lam]];
lex = PFBObjectiveLess;
objOf[s_Association] := PFBDegreeObjective[s];
sumKeys = {"Highest", "Count", "Sum", "Terms", "Unexplained", "MaxUnexplained", "Measured", "Sectors", "NotMeasured", "Complete"};
sectorJobName[key_] := StringReplace[PFBSectorString[key], "/" -> "_"];
phaseFile[dir_] := FileNameJoin[{dir, "simplify", "phase.m"}];
PFBReadPhase[dir_String] := With[{f = phaseFile[dir]}, If[FileExistsQ[f], Get[f], None]];
savePhase[dir_, ph_] := (If[! DirectoryQ[FileNameJoin[{dir, "simplify"}]], CreateDirectory[FileNameJoin[{dir, "simplify"}]]]; Put[ph, phaseFile[dir]]; ph);
currentCensus[dir_, st_] := Get[FileNameJoin[{dir, Last[st["Slices"]]["Census"]}]];
nonZeroCols[sl_, r_] := Select[sl["Labels"], Function[c, AnyTrue[Range[Length[sl["R"]]], sl["R"][[#, sl["Index"][r], sl["Index"][c]]] =!= 0 &]]];
letterAssoc[x_] := If[AssociationQ[x], Select[x, IntegerQ], <||>];


(* ::Section:: *)
(*Precondition and budget*)


PFBSimplifyPrecondition[sys_Association, st_Association, c_Association, opts_Association : <||>] := Module[{bad, flagged, reasons = {}, pend, tried = Lookup[opts, "Tried", <||>], hints},
  flagged = Select[c["BadSectors"], KeyExistsQ[Lookup[st, "Flagged", <||>], #] &];
  bad = Complement[c["BadSectors"], flagged];
  Do[AppendTo[reasons, PFBSectorString[k] <> ": " <> StringRiffle[c["Sectors"][k]["Issues"], ", "] <> " (fix it or flag it first: the phase starts once the census is clean outside flagged sectors)"],
    {k, bad}];
  pend = Select[Lookup[st, "Pending", {}], Lookup[#, "Rung", None] =!= "simplify" &];
  If[pend =!= {}, AppendTo[reasons, "changes wait for approval: " <> StringRiffle[ToString /@ pend[[All, "Id"]], ", "] <> " (approve them, or decline them with bin/approve.wls run.wl --decline <id>, before the phase)"]];
  (* a hidden-weight hint is no bad entry: it never blocks the phase, its untried ones are said *)
  hints = Select[Lookup[c, "HiddenWeights", {}], ! TrueQ[#["Tried"]] && ! MemberQ[Lookup[tried, Key[#["Sector"]], {}], #["Factor"]] &&
     PFBCanChangeQ[sys, #["Sector"], PFBFlaggedSectors[st]] &];
  <|"Pass" -> reasons === {}, "Reasons" -> reasons, "Sectors" -> bad, "Flagged" -> flagged, "Hints" -> hints|>];

PFBSimplifyBudgetProposal[tab_Association, opts_Association : <||>] := Module[{v = Lookup[opts, "Variants", 4], rr = Lookup[opts, "Rounds", 3], secs, per, untimed, round},
  secs = Select[Lookup[tab, "Sectors", <||>], #["Status"] === "measured" &];
  per = Association[KeyValueMap[#1 -> <|"Job" -> Replace[Lookup[#2, "JobWallSeconds", Missing[]], Except[_?NumericQ] -> Lookup[#2, "JobSeconds", Missing[]]],
       "Measure" -> Lookup[#2, "JobSeconds", Missing[]]|> &, secs]];
  untimed = Keys[Select[per, ! NumericQ[#["Job"]] || ! NumericQ[#["Measure"]] &]];
  round = Total[Table[If[NumericQ[q["Job"]] && NumericQ[q["Measure"]], q["Job"] + v q["Measure"], 0], {q, Values[per]}]];
  <|"Seconds" -> Ceiling[rr round], "Round" -> Ceiling[round], "Variants" -> v, "Rounds" -> rr, "PerSector" -> per, "Untimed" -> untimed,
    "Text" -> "budget for the simplification moves: about " <> ToString[Ceiling[round]] <> " s of degree jobs per round over the " <> ToString[Length[per]] <>
      " measured sector(s) (each job: its census time plus " <> ToString[v] <> " variant measurements); proposed " <> ToString[rr] <> " rounds, " <> ToString[Ceiling[rr round]] <>
      " s (move (i) is one round; each later move measures the sectors it touches)" <>
      If[untimed === {}, "", "; no job time for " <> StringRiffle[PFBSectorString /@ untimed, ", "] <> " (not counted)"]|>];


(* ::Section:: *)
(*Maximal-cut-basis normalisations*)


intSector[jj_j, n_] := Boole[Positive[#]] & /@ Take[List @@ Rest[jj], n];

(* the part of an expression on the integrals of the sector itself (its maximal cut) *)
topPart[e_, sec_, n_] := Module[{c = Collect[Expand[e], _j]}, Sum[If[intSector[jj, n] === sec, Coefficient[c, jj] jj, 0], {jj, Union[Cases[{c}, _j, Infinity]]}]];

(* the family's maximal-cut-basis run as PFBReadSystem resolved it (system.wl "MCBRun", read only, checked by
   PFBValidateSystem); this skill's own run of rung 8 (<run>/maxcut/<fam>/) holds no normalisations of the masters *)
mcbRunDir[sys_, fam_] := With[{p = Lookup[Lookup[sys["Families"], fam, <||>], "MCBRun", None]}, If[StringQ[p], p, None]];

PFBMCBNormalisations[sys_Association, key_List] := Module[{fam = key[[1]], run, sd, ms, bas, norms, n, els, labs, out = <||>, invs},
  run = mcbRunDir[sys, fam];
  If[! StringQ[run], Return[<||>]];
  sd = FileNameJoin[{run, SectorName[key[[2]]]}];
  ms = If[DirectoryQ[sd], MCBReadMasters[sd], Missing[]];
  If[! ListQ[ms], Return[<||>]];
  bas = MCBReadBasis[sd];
  norms = Lookup[Replace[Lookup[bas, "masters", {}], Except[_List] -> {}], "normalisation", "rational"];
  If[Length[norms] =!= Length[ms], norms = ConstantArray["rational", Length[ms]]];
  n = PFBFamily[sys, fam]["N"]; invs = sys["Invariants"];
  (* rational elements only: a square root is not a rescaling by letters *)
  els = Select[Transpose[{ms, norms}], #[[2]] === "rational" && FreeQ[#[[1]], Power[_, _Rational]] &][[All, 1]];
  labs = Select[PFBSectorMasters[sys, key], PFBMaster[sys, #]["Family"] === fam &];
  Do[Module[{d = topPart[PFBMaster[sys, l]["RootFree"] /. Dinv[a_, _] :> a, key[[2]], n], hit},
     If[d === 0, Continue[]];
     hit = SelectFirst[els, Function[e, Module[{te = topPart[e, key[[2]], n], jj, rho},
        jj = First[Union[Cases[{d}, _j, Infinity]]];
        rho = Together[Coefficient[Collect[te, _j], jj]/Coefficient[Collect[d, _j], jj]];
        rho =!= 0 && Together[te - rho d] === 0]], None];
     If[hit =!= None, Module[{te = topPart[hit, key[[2]], n], jj, rho, f},
        jj = First[Union[Cases[{d}, _j, Infinity]]];
        rho = Together[Coefficient[Collect[te, _j], jj]/Coefficient[Collect[d, _j], jj]];
        (* the powers of eps are not a rescaling by letters: move (i) leaves the eps structure alone *)
        f = Together[rho /. eps -> 1];
        If[f =!= 0 && FreeQ[Together[rho/f], Alternatives @@ invs], out[l] = <|"Ratio" -> Factor[f], "Element" -> hit, "Folder" -> sd|>]]]], {l, labs}];
  out];


(* ::Section:: *)
(*Move (i): the model*)


(* the exponent of probe q in the rescaling of master m, a linear form in the unknowns ea[l, q] (exponents of the free
   masters) and eu[l] (their unit-scale powers) *)
PFBRescaleModel[ctx_Association, tab_Association, opts_Association : <||>] := Module[{sys = ctx["System"], dir = ctx["Dir"], st = ctx["State"], sl, labs, ix, nk, us, xs,
    dimUS, secs, measured, notMeasured, probes, pdeg, keyOf, cols, touch, bases, group, prot = <||>, imgs = <||>, letters = <||>, allowed = <||>, unitLetter = <||>,
    unitFixed = <||>, emap = <||>, ties, tieOf = <||>, near, a0 = <||>, mcbInfo = <||>, notes = {}, bound = Lookup[opts, "Bound", 2], bounds = <||>, off = {}, diag = {}, new = {},
    fixed = {}, varQ, dep, free, entryKeys, lets, pidx},
  sl = PFBCurrentSlice[dir, st];
  labs = sl["Labels"]; ix = sl["Index"]; nk = Length[sl["R"]];
  us = PFBUnitScale[sys]; xs = DeleteCases[sys["Invariants"], us];
  dimUS = PFBFamily[sys, First[sys["Order"]]]["Invariants"][us];
  secs = Lookup[tab, "Sectors", <||>];
  measured = Keys[Select[secs, #["Status"] === "measured" &]];
  notMeasured = Complement[Lookup[tab, "Keys", Keys[secs]], measured];
  probes = Union[Flatten[Table[Lookup[secs[k], "Probes", {}], {k, measured}]]];
  pdeg = AssociationThread[probes -> (totDeg[#, xs] & /@ probes)];
  pidx = AssociationThread[probes -> Range[Length[probes]]];
  keyOf[l_] := PFBMaster[sys, l]["SectorKey"];
  cols = Association[Table[r -> nonZeroCols[sl, r], {r, labs}]];
  (* the rows whose entries change when master m is rescaled: its own, and those with an entry in its column *)
  touch[m_] := Union[{m}, Select[labs, MemberQ[cols[#], m] &]];
  bases = Select[labs, PFBBaseOf[sys, PFBMaster[sys, #]["Family"]] === PFBMaster[sys, #]["Family"] &];
  Do[With[{fam = PFBMaster[sys, l]["Family"]}, imgs[l] = Table[im -> PFBImageLabel[sys, l, im], {im, PFBImagesOf[sys, fam]}]], {l, bases}];
  group[l_] := Join[{l}, Cases[imgs[l], (_ -> m_Integer) :> m]];
  (* the letter content near each master: the probes of the entries in its rows and columns *)
  entryKeys = Flatten[Table[{e["Row"], e["Column"], Union[Flatten[Keys[{letterAssoc[#["NumLetters"]], letterAssoc[#["DenLetters"]]}] & /@ e["Terms"]]]}, {k, measured}, {e, secs[k]["Entries"]}], 1];
  near[ls_List] := Union[Flatten[Cases[entryKeys, {r_, c_, q_} /; MemberQ[ls, r] || MemberQ[ls, c] :> q]]];
  (* usable letters of each base family: homogeneous, a single probe once the unit scale is 1 *)
  lets[fam_] := lets[fam] = Module[{fo = PFBFamily[sys, fam], out = <||>, ul = False, np = PFBDegreeProbes[sys, dir, {fam}]["NonPolynomial"]},
    Do[Which[
       Expand[L - us] === 0, ul = True,
       MemberQ[np, L], AppendTo[notes, "letter " <> ToString[L, InputForm] <> " of " <> ToString[fam] <> " is no rational function of the invariants: not used"],
       True, Module[{w = MaximalCutBasis`Rules`MCBWeightOf[fo, L], q = PFBNormalizePolynomials[{Together[L /. us -> 1]}, xs]},
         Which[! NumericQ[w], AppendTo[notes, "letter " <> ToString[L, InputForm] <> " of " <> ToString[fam] <> " is not homogeneous: not used"],
           Length[q] =!= 1, AppendTo[notes, "letter " <> ToString[L, InputForm] <> " of " <> ToString[fam] <> " is not one polynomial at unit scale 1: not used"],
           ! MemberQ[probes, q[[1]]], Null,
           True, out[q[[1]]] = <|"Letter" -> L, "Dim" -> w|>]]], {L, Lookup[PFBKnownSingularities[sys, dir, fam], "Letters", {}]}];
    <|"Letters" -> out, "UnitLetter" -> ul|>];
  (* protection: the reason a master is left alone *)
  Do[Module[{fam = PFBMaster[sys, l]["Family"], key = keyOf[l], g = group[l], rows, why = None, ls, al},
     rows = Union @@ (touch /@ g);
     why = Which[
       AnyTrue[g, PFBFrozenQ[sys, PFBMaster[sys, #]["Family"]] &], "a frozen family",
       KeyExistsQ[Lookup[st, "Flagged", <||>], key], "a flagged sector",
       MemberQ[Values[imgs[l]], _Missing], "an image family has no master that matches it",
       ! SubsetQ[labs, g], "its image master is not in the slice",
       ! MemberQ[measured, key], "its sector is not measured",
       AnyTrue[rows, ! MemberQ[measured, keyOf[#]] &], "it changes rows of a sector that is not measured: " <>
         StringRiffle[PFBSectorString /@ Union[Select[keyOf /@ rows, ! MemberQ[measured, #] &]], ", "],
       With[{rs = Intersection[PFBSectorMasters[sys, key], labs]}, MemberQ[{{1, 1}, "zero"}, PFBBlockProfile[sl, rs, rs]["Range"]]],
         "its sector's own block is " <> With[{rs = Intersection[PFBSectorMasters[sys, key], labs]}, If[PFBBlockProfile[sl, rs, rs]["Range"] === "zero", "zero", "eps-form"]] <>
         ": d log r on its diagonal would add an eps^0 term",
       AnyTrue[g, Function[m, AnyTrue[Range[Length[sl["R"]]], ! MatchQ[PFBRowEpsProfile[sl, #, m], {_?NonPositive, _}] &]]],
         "its row has no eps^0 term in every derivative: d log r on its diagonal would lower its eps structure",
       True, None];
     If[StringQ[why], prot[l] = why; Continue[]];
     ls = lets[fam];
     al = Intersection[Keys[ls["Letters"]], near[g]];
     letters[l] = KeyTake[ls["Letters"], al]; unitLetter[l] = ls["UnitLetter"]; unitFixed[l] = False;
     allowed[l] = al], {l, bases}];
  (* maximal-cut-basis's normalisations: the first rescalings to try *)
  Do[Module[{nm = PFBMCBNormalisations[sys, key]},
     KeyValueMap[Function[{l, info}, If[KeyExistsQ[allowed, l], Module[{fl = FactorList[Numerator[info["Ratio"]]], fd = FactorList[Denominator[info["Ratio"]]], v = <||>, ok = True,
          lsAll = lets[PFBMaster[sys, l]["Family"]]["Letters"]},
         Do[With[{g = f[[1]], m = s f[[2]]}, Which[
             FreeQ[g, Alternatives @@ sys["Invariants"]], Null,
             Expand[g - us] === 0 || Expand[g + us] === 0, Null,
             True, With[{q = PFBNormalizePolynomials[{Together[g /. us -> 1]}, xs]},
               If[Length[q] == 1 && KeyExistsQ[lsAll, q[[1]]] && FreeQ[Together[g/lsAll[q[[1]]]["Letter"]], Alternatives @@ sys["Invariants"]],
                 v[q[[1]]] = Lookup[v, q[[1]], 0] + m, ok = False]]]], {s, {1, -1}}, {f, If[s == 1, fl, fd]}];
         If[ok && Mod[Total[KeyValueMap[#2 lsAll[#1]["Dim"] &, v]], dimUS] == 0,
           a0[l] = v; mcbInfo[l] = info;
           allowed[l] = Union[allowed[l], Keys[v]]; letters[l] = KeyTake[lsAll, allowed[l]],
           AppendTo[notes, "the maximal-cut-basis normalisation of ut[" <> ToString[l] <> "], " <> ToString[info["Ratio"], InputForm] <> ", is not a rescaling by usable letters"]]]]],
       nm]], {key, Union[keyOf /@ Keys[allowed]]}];
  (* masters with no usable letter near them stay as they are *)
  Do[If[allowed[l] === {}, prot[l] = "no usable letter in its rows or columns"; KeyDropFrom[allowed, l]], {l, Keys[allowed]}];
  free = Keys[allowed];
  (* the images follow their base master through the invariant map; a letter whose image is not a product of probes
     cannot be used, and a unit scale whose image is not one fixes the unit-scale power to 0 *)
  ties[l_, im_] := Module[{lv = <||>, uv = <||>, ok, fac},
    fac[x_] := Module[{fl = Select[FactorList[Together[x /. us -> 1]], ! FreeQ[#[[1]], Alternatives @@ xs] &], out = <||>, good = True},
      Do[With[{q = PFBNormalizePolynomials[{f[[1]]}, xs]}, If[Length[q] == 1 && MemberQ[probes, q[[1]]], out[q[[1]]] = Lookup[out, q[[1]], 0] + f[[2]], good = False]], {f, fl}];
      If[good, out, $Failed]];
    Do[With[{v = fac[Numerator[Together[PFBImageExpr[sys, letters[l][q]["Letter"], im]]]]}, If[v === $Failed,
        AppendTo[notes, "letter " <> ToString[letters[l][q]["Letter"], InputForm] <> " of ut[" <> ToString[l] <> "]: its image in " <> ToString[im] <> " is not a product of known singularities"];
        allowed[l] = DeleteCases[allowed[l], q], lv[q] = v]], {q, allowed[l]}];
    uv = fac[PFBImageExpr[sys, us, im]];
    If[uv === $Failed, unitFixed[l] = True; uv = <||>];
    <|"Letters" -> lv, "Unit" -> uv|>];
  (* first the ties (they may drop letters), then the exponents *)
  Do[Do[tieOf[{l, im[[2]]}] = ties[l, im[[1]]], {im, imgs[l]}], {l, free}];
  Do[If[allowed[l] === {}, prot[l] = "no usable letter in its rows or columns"; KeyDropFrom[allowed, l]], {l, free}];
  free = Keys[allowed];
  letters = Association[Table[l -> KeyTake[letters[l], allowed[l]], {l, free}]];
  Do[emap[l] = Association[Table[q -> ea[l, pidx[q]], {q, allowed[l]}]];
    Do[With[{t = tieOf[{l, im[[2]]}]},
       emap[im[[2]]] = Select[Merge[Join[KeyValueMap[Function[{q, v}, Association[KeyValueMap[#1 -> #2 ea[l, pidx[q]] &, v]]], KeyTake[t["Letters"], allowed[l]]],
           {Association[KeyValueMap[#1 -> #2 eu[l] &, t["Unit"]]]}], Total], # =!= 0 &]], {im, imgs[l]}], {l, free}];
  Do[bounds[l] = Association[Table[q -> {Min[-bound, Lookup[Lookup[a0, l, <||>], q, 0]], Max[bound, Lookup[Lookup[a0, l, <||>], q, 0]]}, {q, allowed[l]}]], {l, free}];
  emap = Select[emap, Length[#] > 0 &];
  varQ[m_] := KeyExistsQ[emap, m];
  (* the probes an entry of derivative k depends on: d log of a probe free of x_k vanishes, except in the unit scale's
     derivative, where homogeneity brings every probe *)
  dep[k_] := With[{x = sl["Derivatives"][[k]]}, If[x === us, probes, Select[probes, ! FreeQ[#, x] &]]];
  (* the terms *)
  Do[Module[{ents = secs[key]["Entries"], has0 = <||>},
     Do[Module[{k = e["Matrix"], r = e["Row"], c = e["Column"], isDiag},
        isDiag = r === c;
        If[isDiag && MemberQ[Lookup[e["Terms"], "Power"], 0 | "whole"], has0[{k, r}] = True];
        Do[Module[{nl = letterAssoc[t["NumLetters"]], dl = letterAssoc[t["DenLetters"]], base},
           base = <|"Key" -> key, "Matrix" -> k, "Row" -> r, "Column" -> c, "Power" -> t["Power"], "Num" -> t["Num"], "Den" -> t["Den"], "NumL" -> nl, "DenL" -> dl|>;
           Which[
             isDiag && varQ[r] && MatchQ[t["Power"], 0 | "whole"],
               AppendTo[diag, Join[base, <|"Ys" -> Intersection[dep[k], Keys[emap[r]]],
                 "Extra" -> Association[Table[q -> If[Lookup[dl, q, 0] == 0, pdeg[q], 0], {q, probes}]], "Base" -> t["Den"] + Max[t["Num"] - t["Den"], 0]|>]],
             ! isDiag && (varQ[r] || varQ[c]), Module[{qs, dlt},
               dlt = Association[Table[q -> Expand[Lookup[Lookup[emap, r, <||>], q, 0] - Lookup[Lookup[emap, c, <||>], q, 0]], {q, Union[Keys[Lookup[emap, r, <||>]], Keys[Lookup[emap, c, <||>]]]}]];
               dlt = Select[dlt, # =!= 0 &];
               qs = Keys[dlt];
               AppendTo[off, Join[base, <|"Q" -> qs, "Delta" -> dlt, "E0" -> Association[Table[q -> Lookup[nl, q, 0] - Lookup[dl, q, 0], {q, qs}]],
                 "NumC" -> t["Num"] - Total[Lookup[nl, qs, 0] Lookup[pdeg, qs]], "DenC" -> t["Den"] - Total[Lookup[dl, qs, 0] Lookup[pdeg, qs]]|>]]],
             True, AppendTo[fixed, Max[t["Num"], t["Den"]]]]], {t, e["Terms"]}]], {e, ents}];
     (* a rescaled master's own entry without an eps^0 term (or zero) may gain d log r *)
     Do[If[! TrueQ[Lookup[has0, Key[{k, r}], False]],
         AppendTo[new, <|"Key" -> key, "Matrix" -> k, "Row" -> r, "Column" -> r, "Power" -> 0, "Ys" -> Intersection[dep[k], Keys[emap[r]]],
           "Extra" -> pdeg, "Base" -> 0|>]], {r, Select[Keys[emap], keyOf[#] === key && MemberQ[Lookup[secs[key], "Rows", {}], #] &]}, {k, nk}]], {key, measured}];
  <|"Free" -> free, "Protected" -> prot, "Allowed" -> allowed, "Letters" -> letters, "UnitLetter" -> unitLetter, "UnitFixed" -> unitFixed, "UnitScale" -> us, "UnitDim" -> dimUS,
    "Vars" -> xs, "Probes" -> probes, "ProbeDegree" -> pdeg, "ProbeIndex" -> pidx, "E" -> emap, "Images" -> imgs, "Initial" -> a0, "InitialInfo" -> mcbInfo, "Bounds" -> bounds, "Bound" -> bound,
    "Off" -> off, "Diag" -> diag, "New" -> new, "Fixed" -> fixed, "Measured" -> measured, "NotMeasured" -> notMeasured, "Current" -> objOf[PFBDegreeSummary[tab]],
    "CurrentSummary" -> KeyTake[PFBDegreeSummary[tab], sumKeys], "Notes" -> DeleteDuplicates[notes]|>];


(* ::Section:: *)
(*Move (i): prediction*)


unitOf[model_, l_, ex_] := -Total[KeyValueMap[#2 model["Letters"][l][#1]["Dim"] &, Lookup[ex, l, <||>]]]/model["UnitDim"];

(* numeric exponent of every probe of every master *)
numericE[model_, ex_] := Module[{rules = Join[Flatten[KeyValueMap[Function[{l, v}, KeyValueMap[ea[l, model["ProbeIndex"][#1]] -> #2 &, v]], ex]],
     Table[eu[l] -> unitOf[model, l, ex], {l, Keys[ex]}]]},
  Map[(# /. rules /. {ea[__] -> 0, eu[_] -> 0}) &, model["E"], {2}]];

(* the predicted degree of one term: off the diagonal from the net exponents, on it the bound, a new diagonal term only
   when some letter of the row's rescaling enters it *)
evOf[en_, m_, q_] := Lookup[Lookup[en, m, <||>], q, 0];
offDeg[t_, en_, pd_] := With[{e = Table[t["E0"][q] + evOf[en, t["Row"], q] - evOf[en, t["Column"], q], {q, t["Q"]}], dg = Lookup[pd, t["Q"]]},
  Max[t["NumC"] + Total[dg (Max[#, 0] & /@ e)], t["DenC"] + Total[dg (Max[-#, 0] & /@ e)]]];
diagDeg[t_, en_] := t["Base"] + Total[Table[If[evOf[en, t["Row"], q] =!= 0, t["Extra"][q], 0], {q, t["Ys"]}]];
newDeg[t_, en_] := With[{ys = Select[t["Ys"], evOf[en, t["Row"], #] =!= 0 &]}, If[ys === {}, Missing[], Total[Lookup[t["Extra"], ys]]]];
termDegrees[model_, en_] := <|"Off" -> (offDeg[#, en, model["ProbeDegree"]] & /@ model["Off"]), "Diag" -> (diagDeg[#, en] & /@ model["Diag"]),
   "New" -> (newDeg[#, en] & /@ model["New"])|>;

summaryOf[degs_List] := If[degs === {}, <|"Highest" -> None, "Count" -> 0, "Sum" -> 0, "Terms" -> 0|>,
  With[{h = Max[degs]}, <|"Highest" -> h, "Count" -> Count[degs, h], "Sum" -> Total[degs], "Terms" -> Length[degs]|>]];

PFBPredictDegrees[model_Association, ex_Association] := Module[{td = termDegrees[model, numericE[model, ex]], s},
  s = summaryOf[Join[model["Fixed"], td["Off"], td["Diag"], DeleteMissing[td["New"]]]];
  Join[s, <|"Objective" -> objOf[s], "TermDegrees" -> td|>]];

(* exponents that satisfy the bounds and the mass dimension: an integer unit-scale power, 0 when an image cannot
   carry it, and no unit scale in a denominator when it is not a letter *)
feasibleQ[model_, l_, v_Association] := Module[{k = unitOf[model, l, <|l -> v|>], b = model["Bounds"][l]},
  IntegerQ[k] && AllTrue[Keys[v], b[#][[1]] <= v[#] <= b[#][[2]] &] && (! TrueQ[model["UnitFixed"][l]] || k == 0) && (TrueQ[model["UnitLetter"][l]] || k >= 0)];

cleanEx[ex_] := Select[Select[#, # =!= 0 &] & /@ ex, # =!= <||> &];
distance[ex_, a0_] := Total[Flatten[Table[Abs[Lookup[Lookup[ex, l, <||>], q, 0] - Lookup[Lookup[a0, l, <||>], q, 0]],
   {l, Union[Keys[ex], Keys[a0]]}, {q, Union[Keys[Lookup[ex, l, <||>]], Keys[Lookup[a0, l, <||>]]]}]]];


(* ::Section:: *)
(*Move (i): the integer program*)


(* stage 1: the lowest highest degree; stage 2: the lowest sum of term degrees at that height. Linear in the
   exponents with u, v >= the positive and negative parts of each net exponent, and y in {0, 1} for a probe that enters
   d log r of a master's own entry *)
milp[model_, tl_, maxVars_] := Module[{free = model["Free"], al = model["Allowed"], pd = model["ProbeDegree"], vars = {}, doms = {}, ge = {}, eq = {}, add, ev, dV, hV, yV, uV, vV,
    nOff, nDiag, nNew, ys, mbig, A, b, Aeq, beq, c, x1, x2, h1, pos, sol, out, t0 = AbsoluteTime[], dTerms, yOf, maxA, maxU, pi = model["ProbeIndex"]},
  add[v_, d_] := (AppendTo[vars, v]; AppendTo[doms, d]);
  Do[Do[add[ea[l, pi[q]], Integers]; With[{bd = model["Bounds"][l][q]}, AppendTo[ge, ea[l, pi[q]] - bd[[1]]]; AppendTo[ge, bd[[2]] - ea[l, pi[q]]]], {q, al[l]}];
    add[eu[l], Integers];
    AppendTo[eq, model["UnitDim"] eu[l] + Sum[model["Letters"][l][q]["Dim"] ea[l, pi[q]], {q, al[l]}]];
    If[TrueQ[model["UnitFixed"][l]], AppendTo[eq, eu[l]]];
    If[! TrueQ[model["UnitLetter"][l]], AppendTo[ge, eu[l]]], {l, free}];
  ev[m_, q_] := Lookup[Lookup[model["E"], m, <||>], q, 0];
  nOff = Length[model["Off"]]; nDiag = Length[model["Diag"]]; nNew = Length[model["New"]];
  (* y[m, q] >= [E_m[q] != 0] *)
  ys = Union[Flatten[Table[{t["Row"], #} & /@ t["Ys"], {t, Join[model["Diag"], model["New"]]}], 1]];
  (* |E_m[q]| <= mbig y[m, q]: mbig from the bounds of the exponents and of the unit-scale powers *)
  maxA = Max[Append[Abs[Flatten[Values[Values /@ model["Bounds"]]]], 1]];
  maxU = Max[Append[Table[Ceiling[Total[Abs[model["Letters"][l][#]["Dim"]] & /@ al[l]] maxA/model["UnitDim"]], {l, free}], 1]];
  Do[With[{e = ev[y[[1]], y[[2]]]}, If[e =!= 0,
      mbig = 1 + Total[Abs[Coefficient[e, #]] If[Head[#] === eu, maxU, maxA] & /@ Union[Cases[{e}, _ea | _eu, Infinity]]];
      add[yV[y[[1]], pi[y[[2]]]], Integers]; AppendTo[ge, yV[y[[1]], pi[y[[2]]]]]; AppendTo[ge, 1 - yV[y[[1]], pi[y[[2]]]]];
      AppendTo[ge, mbig yV[y[[1]], pi[y[[2]]]] - e]; AppendTo[ge, mbig yV[y[[1]], pi[y[[2]]]] + e]]], {y, ys}];
  yOf[m_, q_] := If[MemberQ[vars, yV[m, pi[q]]], yV[m, pi[q]], 0];
  Do[With[{t = model["Off"][[i]]},
     Do[add[uV[i, pi[q]], Reals]; add[vV[i, pi[q]], Reals]; AppendTo[ge, uV[i, pi[q]]]; AppendTo[ge, vV[i, pi[q]]];
       AppendTo[ge, uV[i, pi[q]] - t["E0"][q] - t["Delta"][q]]; AppendTo[ge, vV[i, pi[q]] + t["E0"][q] + t["Delta"][q]], {q, t["Q"]}];
     add[dV[i], Reals];
     AppendTo[ge, dV[i] - t["NumC"] - Sum[pd[q] uV[i, pi[q]], {q, t["Q"]}]]; AppendTo[ge, dV[i] - t["DenC"] - Sum[pd[q] vV[i, pi[q]], {q, t["Q"]}]]], {i, nOff}];
  Do[With[{t = model["Diag"][[i]]}, add[dV[nOff + i], Reals]; AppendTo[ge, dV[nOff + i] - t["Base"] - Sum[t["Extra"][q] yOf[t["Row"], q], {q, t["Ys"]}]]], {i, nDiag}];
  Do[With[{t = model["New"][[i]]}, add[dV[nOff + nDiag + i], Reals]; AppendTo[ge, dV[nOff + nDiag + i] - Sum[t["Extra"][q] yOf[t["Row"], q], {q, t["Ys"]}]]], {i, nNew}];
  dTerms = Table[dV[i], {i, nOff + nDiag + nNew}];
  add[hV, Reals];
  AppendTo[ge, hV - Max[Append[model["Fixed"], 0]]];
  Scan[AppendTo[ge, hV - #] &, dTerms];
  If[Length[vars] > maxVars, Return[<|"Status" -> "skipped", "Message" -> ToString[Length[vars]] <> " variables (more than " <> ToString[maxVars] <> ")"|>]];
  {b, A} = CoefficientArrays[ge, vars];
  {beq, Aeq} = If[eq === {}, {{}, {}}, CoefficientArrays[eq, vars]];
  pos[v_] := First[FirstPosition[vars, v]];
  sol[cc_, extra_] := Module[{AA = A, bb = b}, If[extra =!= None, AA = SparseArray[Join[Normal[A], {extra[[1]]}]]; bb = Append[b, extra[[2]]]];
    TimeConstrained[Quiet@If[eq === {}, LinearOptimization[cc, {AA, bb}, doms], LinearOptimization[cc, {AA, bb}, {Aeq, beq}, doms]], tl, $Aborted]];
  c = SparseArray[{pos[hV] -> 1}, Length[vars]];
  x1 = sol[c, None];
  If[! VectorQ[x1, NumericQ], Return[<|"Status" -> If[x1 === $Aborted, "timeout", "failed"], "Message" -> "stage 1 (highest degree): " <> If[x1 === $Aborted, "no solution within " <> ToString[tl] <> " s", "no solution"],
     "Variables" -> Length[vars], "Seconds" -> Round[AbsoluteTime[] - t0, 0.1]|>]];
  h1 = Round[x1[[pos[hV]]]];
  out[x_] := Association[Table[l -> Association[Table[q -> Round[x[[pos[ea[l, pi[q]]]]]], {q, al[l]}]], {l, free}]];
  (* stage 2: hV <= h1, i.e. -hV + h1 >= 0 *)
  x2 = If[dTerms === {}, x1, sol[SparseArray[Table[pos[d] -> 1, {d, dTerms}], Length[vars]], {Normal[SparseArray[{pos[hV] -> -1}, Length[vars]]], h1}]];
  <|"Status" -> If[VectorQ[x2, NumericQ], "solved", "stage 1 only"], "Highest" -> h1, "Exponents" -> cleanEx[out[If[VectorQ[x2, NumericQ], x2, x1]]],
    "Variables" -> Length[vars], "Seconds" -> Round[AbsoluteTime[] - t0, 0.1]|>];

(* coordinate search on the exact predicted objective, ties to the point closest to a0. A step of master l changes the
   terms in the rows and columns of l and of its images only: those are evaluated again *)
search[model_, start_, a0_, maxRounds_ : 60] := Module[{cur = cleanEx[start], best, improved = True, n = 0, moves, try, ids, grp, cd, score, pd = model["ProbeDegree"],
    tryD},
  grp = Association[Table[l -> Join[{l}, Cases[model["Images"][l], (_ -> m_Integer) :> m]], {l, model["Free"]}]];
  ids = Association[Table[l -> <|"Off" -> Select[Range[Length[model["Off"]]], MemberQ[grp[l], model["Off"][[#]]["Row"]] || MemberQ[grp[l], model["Off"][[#]]["Column"]] &],
      "Diag" -> Select[Range[Length[model["Diag"]]], MemberQ[grp[l], model["Diag"][[#]]["Row"]] &], "New" -> Select[Range[Length[model["New"]]], MemberQ[grp[l], model["New"][[#]]["Row"]] &]|>,
    {l, model["Free"]}]];
  score[d_, ex_] := Append[objOf[summaryOf[Join[model["Fixed"], d["Off"], d["Diag"], DeleteMissing[d["New"]]]]], distance[ex, a0]];
  cd = termDegrees[model, numericE[model, cur]];
  best = score[cd, cur];
  While[improved && n < maxRounds, improved = False; n++;
    moves = Reap[Do[Module[{w = Join[Association[Table[q2 -> 0, {q2, model["Allowed"][l]}]], Lookup[cur, l, <||>]]},
        w[q] += d;
        If[feasibleQ[model, l, Select[w, # =!= 0 &]], Sow[{l, Select[w, # =!= 0 &]}],
          (* a step the mass dimension forbids: together with a step of another letter *)
          Do[If[q2 =!= q, With[{w2 = Select[ReplacePart[w, Key[q2] -> w[q2] + d2], # =!= 0 &]}, If[feasibleQ[model, l, w2], Sow[{l, w2}]]]], {q2, model["Allowed"][l]}, {d2, {1, -1}}]]],
      {l, model["Free"]}, {q, model["Allowed"][l]}, {d, {1, -1}}]][[2]];
    moves = If[moves === {}, {}, First[moves]];
    Do[Module[{ex = cleanEx[Join[cur, <|mv[[1]] -> mv[[2]]|>]], en, d = cd, o = ids[mv[[1]]], sc},
        en = numericE[model, ex];
        d["Off"] = ReplacePart[d["Off"], Thread[o["Off"] -> (offDeg[#, en, pd] & /@ model["Off"][[o["Off"]]])]];
        d["Diag"] = ReplacePart[d["Diag"], Thread[o["Diag"] -> (diagDeg[#, en] & /@ model["Diag"][[o["Diag"]]])]];
        d["New"] = ReplacePart[d["New"], Thread[o["New"] -> (newDeg[#, en] & /@ model["New"][[o["New"]]])]];
        sc = score[d, ex];
        If[lex[sc, best], best = sc; try = ex; tryD = d; improved = True]], {mv, moves}];
    If[improved, cur = try; cd = tryD]];
  <|"Exponents" -> cur, "Objective" -> Most[best], "Distance" -> Last[best], "Rounds" -> n|>];

PFBRescaleProgram[model_Association, opts_Association : <||>] := Module[{t0 = AbsoluteTime[], tl = Lookup[opts, "SolverTime", 60], mv = Lookup[opts, "MaxVariables", 6000], a0, starts, prog,
    runs, best, pred},
  If[model["Free"] === {}, Return[<|"Status" -> "no free master", "Exponents" -> <||>, "Units" -> <||>, "Predicted" -> KeyTake[PFBPredictDegrees[model, <||>], {"Highest", "Count", "Sum", "Terms"}],
     "Objective" -> PFBPredictDegrees[model, <||>]["Objective"], "Program" -> <||>, "Seconds" -> 0|>]];
  a0 = KeyTake[model["Initial"], model["Free"]];
  a0 = Association[KeyValueMap[If[feasibleQ[model, #1, #2], #1 -> #2, Nothing] &, a0]];
  prog = milp[model, tl, mv];
  starts = DeleteDuplicates[Join[{<||>, a0}, If[KeyExistsQ[prog, "Exponents"], {Association[KeyValueMap[If[feasibleQ[model, #1, #2], #1 -> #2, Nothing] &, prog["Exponents"]]]}, {}]]];
  runs = search[model, #, a0] & /@ starts;
  best = First[SortBy[runs, Append[#["Objective"], #["Distance"]] &, lex]];
  pred = PFBPredictDegrees[model, best["Exponents"]];
  <|"Status" -> "solved", "Exponents" -> best["Exponents"], "Units" -> Association[Table[l -> unitOf[model, l, best["Exponents"]], {l, Keys[best["Exponents"]]}]],
    "Predicted" -> KeyTake[pred, {"Highest", "Count", "Sum", "Terms"}], "Objective" -> pred["Objective"], "Program" -> KeyDrop[prog, "Exponents"],
    "ProgramExponents" -> Lookup[prog, "Exponents", Missing[]], "Searches" -> Table[<|"Start" -> starts[[i]], "Objective" -> runs[[i]]["Objective"], "Rounds" -> runs[[i]]["Rounds"]|>, {i, Length[runs]}],
    "Seconds" -> Round[AbsoluteTime[] - t0, 0.1]|>];


(* ::Section:: *)
(*Move (i): candidates*)


PFBRescaleFactor[model_Association, l_, v_Association, k_] := Times @@ KeyValueMap[model["Letters"][l][#1]["Letter"]^#2 &, v] model["UnitScale"]^k;

candidateOf[ctx_, model_, name_, ex0_] := Module[{sys = ctx["System"], ex = cleanEx[ex0], units, resc = <||>, pred},
  units = Association[Table[l -> unitOf[model, l, ex], {l, Keys[ex]}]];
  Do[With[{r = PFBRescaleFactor[model, l, ex[l], units[l]]}, resc[l] = r;
      Do[If[IntegerQ[im[[2]]], resc[im[[2]]] = Together[PFBImageExpr[sys, r, im[[1]]]]], {im, model["Images"][l]}]], {l, Keys[ex]}];
  pred = PFBPredictDegrees[model, ex];
  <|"Name" -> name, "Exponents" -> ex, "Units" -> units, "Masters" -> Keys[ex], "Rescalings" -> resc, "T" -> Association[KeyValueMap[#1 -> #2 ut[#1] &, resc]],
    "Predicted" -> KeyTake[pred, {"Highest", "Count", "Sum", "Terms"}], "Objective" -> pred["Objective"]|>];

PFBRescaleCandidates[ctx_Association, model_Association, sol_Association, opts_Association : <||>] := Module[{maxC = Lookup[opts, "MaxCandidates", 6], ex = sol["Exponents"], cands = {},
    order = {}, left, a0},
  If[ex =!= <||>, AppendTo[cands, candidateOf[ctx, model, "ip", ex]]];
  a0 = Association[KeyValueMap[If[feasibleQ[model, #1, #2], #1 -> #2, Nothing] &, KeyTake[model["Initial"], model["Free"]]]];
  If[cleanEx[a0] =!= <||> && cleanEx[a0] =!= ex, AppendTo[cands, candidateOf[ctx, model, "mcb", a0]]];
  (* partial rescalings: the masters of the solution one at a time, the best predicted first *)
  left = Keys[ex];
  While[Length[left] > 1 && Length[order] < Min[Length[Keys[ex]] - 1, maxC - 2],
    With[{pick = First[SortBy[left, PFBPredictDegrees[model, KeyTake[ex, Append[order, #]]]["Objective"] &, lex]]}, AppendTo[order, pick]; left = DeleteCases[left, pick]]];
  Do[AppendTo[cands, candidateOf[ctx, model, "partial" <> ToString[i], KeyTake[ex, Take[order, i]]]], {i, Length[order]}];
  (* only what may lower the objective; maximal-cut-basis's normalisation is always measured *)
  cands = Select[cands, #["Name"] === "mcb" || lex[#["Objective"], model["Current"]] &];
  Take[cands, UpTo[maxC]]];

(* the sectors whose masters a move (i) candidate rescales as the maximal-cut-basis run normalised them (the model's
   "Initial", from PFBMCBNormalisations): that run's credits go with the change (PFBTryChange, info "MCBSectors") *)
mcbSectorsOf[sys_, rec_, cd_] := Module[{ini = Lookup[Lookup[rec, "Info", <||>], "Initial", <||>], ex = Lookup[Lookup[cd, "Info", <||>], "Exponents", <||>]},
  If[! AssociationQ[ini] || ! AssociationQ[ex], {},
    Union[PFBMaster[sys, #]["SectorKey"] & /@ Select[Intersection[Keys[ini], Keys[ex]], IntegerQ[#] && Sort[Normal[ini[#]]] === Sort[Normal[ex[#]]] &]]]];

rescaleMove[ctx_, tab_, phase_, opts_] := Module[{model, sol, cands},
  model = PFBRescaleModel[ctx, tab, opts];
  sol = PFBRescaleProgram[model, opts];
  cands = PFBRescaleCandidates[ctx, model, sol, opts];
  <|"Status" -> If[cands === {}, "no gain", "proposed"],
    "Message" -> If[cands === {}, "move (i): no rescaling by letters is predicted to lower the objective " <> ToString[model["Current"]] <>
       " (" <> ToString[Length[model["Free"]]] <> " master(s) free, " <> ToString[Length[model["Protected"]]] <> " left alone)",
      "move (i): " <> ToString[Length[cands]] <> " candidate(s); the program predicts " <> ToString[sol["Objective"]] <> " from " <> ToString[model["Current"]]],
    "Candidates" -> Table[Join[KeyTake[cd, {"Name", "T", "Predicted", "Objective"}], <|"Info" -> KeyTake[cd, {"Exponents", "Units", "Masters", "Rescalings"}]|>], {cd, cands}],
    "Info" -> <|"Free" -> model["Free"], "Protected" -> model["Protected"], "Initial" -> model["Initial"], "Notes" -> model["Notes"],
      "Program" -> KeyDrop[sol, {"Searches"}], "Current" -> model["Current"]|>|>];


(* ::Section:: *)
(*Moves (ii) to (iv): the worst master, what may change, the slice's checks*)


(* the terms of a degree table by master: those of its row, and those of its column in other rows *)
PFBWorstMasters[tab_Association, opts_Association : <||>] := Module[{secs, rowT = <||>, colT = <||>, labs, out},
  secs = Select[Lookup[tab, "Sectors", <||>], #["Status"] === "measured" &];
  Do[Do[With[{rec = <|"Matrix" -> e["Matrix"], "Row" -> e["Row"], "Column" -> e["Column"], "Power" -> t["Power"], "Degree" -> Max[t["Num"], t["Den"]]|>},
       rowT[e["Row"]] = Append[Lookup[rowT, e["Row"], {}], rec];
       If[e["Column"] =!= e["Row"], colT[e["Column"]] = Append[Lookup[colT, e["Column"], {}], rec]]], {t, e["Terms"]}],
    {e, Flatten[Values[Lookup[#, "Entries", {}] & /@ secs], 1]}];
  labs = Union[Keys[rowT], Keys[colT]];
  If[ListQ[Lookup[opts, "Labels", All]], labs = Intersection[labs, opts["Labels"]]];
  out = Table[Module[{r = Lookup[rowT, l, {}], c = Lookup[colT, l, {}], s, w},
      s = summaryOf[Join[r, c][[All, "Degree"]]];
      w = Select[Join[r, c], #["Degree"] === s["Highest"] &];
      <|"Label" -> l, "Objective" -> objOf[s], "RowObjective" -> objOf[summaryOf[r[[All, "Degree"]]]], "ColumnObjective" -> objOf[summaryOf[c[[All, "Degree"]]]],
        "Worst" -> w, "Side" -> Which[AllTrue[w, #["Row"] === l &], "row", NoneTrue[w, #["Row"] === l &], "column", True, "both"]|>], {l, labs}];
  SortBy[out, {-#["Objective"][[1]], -#["Objective"][[2]], -#["Objective"][[3]], #["Label"]} &]];

PFBMovableMasters[ctx_Association, tab_Association, opts_Association : <||>] := Module[{sys = ctx["System"], st = ctx["State"], sl, labs, measured, keyOf, cols, touch, bases,
    imgs = <||>, group, prot = <||>, free = {}},
  sl = PFBCurrentSlice[ctx["Dir"], st]; labs = sl["Labels"];
  measured = Keys[Select[Lookup[tab, "Sectors", <||>], #["Status"] === "measured" &]];
  keyOf[l_] := PFBMaster[sys, l]["SectorKey"];
  cols = Association[Table[r -> nonZeroCols[sl, r], {r, labs}]];
  touch[m_] := Union[{m}, Select[labs, MemberQ[cols[#], m] &]];
  bases = Select[labs, PFBBaseOf[sys, PFBMaster[sys, #]["Family"]] === PFBMaster[sys, #]["Family"] &];
  Do[imgs[l] = Table[im -> PFBImageLabel[sys, l, im], {im, PFBImagesOf[sys, PFBMaster[sys, l]["Family"]]}], {l, bases}];
  group[l_] := Join[{l}, Cases[imgs[l], (_ -> m_Integer) :> m]];
  Do[Module[{key = keyOf[l], g = group[l], rows, why, own},
     rows = Union @@ (touch /@ g);
     own = Intersection[PFBSectorMasters[sys, key], labs];
     why = Which[
       AnyTrue[g, PFBFrozenQ[sys, PFBMaster[sys, #]["Family"]] &], "a frozen family",
       KeyExistsQ[Lookup[st, "Flagged", <||>], key], "a flagged sector",
       MemberQ[Values[imgs[l]], _Missing], "an image family has no master that matches it",
       ! SubsetQ[labs, g], "its image master is not in the slice",
       ! MemberQ[measured, key], "its sector is not measured",
       AnyTrue[rows, ! MemberQ[measured, keyOf[#]] &], "it changes rows of a sector that is not measured: " <>
         StringRiffle[PFBSectorString /@ Union[Select[keyOf /@ rows, ! MemberQ[measured, #] &]], ", "],
       TrueQ[Lookup[opts, "EpsForm", False]] && MemberQ[{{1, 1}, "zero"}, PFBBlockProfile[sl, own, own]["Range"]],
         "its sector's own block is " <> If[PFBBlockProfile[sl, own, own]["Range"] === "zero", "zero", "eps-form"],
       True, None];
     If[StringQ[why], prot[l] = why, AppendTo[free, l]]], {l, bases}];
  <|"Free" -> free, "Protected" -> prot, "Images" -> imgs|>];

rowPoleFreeQ[sl_, r_] := AllTrue[Flatten[Table[sl["R"][[k, sl["Index"][r]]], {k, Length[sl["R"]]}]], # === 0 || PFBEpsFactors[#] === {} &];
epsFormOwnQ[sys_, sl_, key_] := With[{rows = Intersection[PFBSectorMasters[sys, key], sl["Labels"]]}, rows =!= {} && MemberQ[{{1, 1}, "zero"}, PFBBlockProfile[sl, rows, rows]["Range"]]];

PFBSimplifySliceCheck[sys_Association, sl_Association, c0_Association, slNew_Association, opts_Association : <||>] := Module[{cap = Lookup[opts, "MaxEpsDegree", $PFBMaxEpsDegree],
    cO, c1, cmp, poleRows, over, lost, floors, reasons = {}},
  cO = If[Lookup[c0, "DegreeCap", None] === cap, c0, Block[{PFBPrint}, PFBCensus[sys, sl, <|"MaxEpsDegree" -> cap|>]]];
  c1 = Block[{PFBPrint}, PFBCensus[sys, slNew, <|"MaxEpsDegree" -> cap|>]];
  cmp = PFBCompareCensus[cO, c1];
  poleRows = Select[slNew["Labels"], KeyExistsQ[sl["Index"], #] && rowPoleFreeQ[sl, #] && ! rowPoleFreeQ[slNew, #] &];
  over = PFBDegreeViolations[sl, slNew, cap];
  lost = Select[PFBSectorKeys[sys], epsFormOwnQ[sys, sl, #] && ! epsFormOwnQ[sys, slNew, #] &];
  floors = PFBEpsFloorViolations[sl, slNew];
  If[poleRows =!= {}, AppendTo[reasons, "rows that gain finite poles: " <> ToString[ut /@ Take[poleRows, UpTo[12]]]]];
  If[cmp["NewBad"] =!= {}, AppendTo[reasons, ToString[Length[cmp["NewBad"]]] <> " new pole entries"]];
  If[cmp["NewEpsZero"] =!= {}, AppendTo[reasons, ToString[Length[cmp["NewEpsZero"]]] <> " new negative powers of eps"]];
  If[cmp["NewHigh"] =!= {} || over =!= {}, AppendTo[reasons, ToString[Length[Union[cmp["NewHigh"], over[[All, 1 ;; 3]]]]] <> " entries above eps^" <> ToString[cap] <> " that were not"]];
  If[lost =!= {}, AppendTo[reasons, "eps-form blocks that lose their form: " <> StringRiffle[PFBSectorString /@ lost, ", "]]];
  If[floors =!= {}, AppendTo[reasons, "rows whose eps structure gets worse (a lower power of eps, or an eps-form row that loses its form): " <>
     StringRiffle[("ut[" <> ToString[#] <> "]") & /@ Take[Union[floors[[All, 2]]], UpTo[12]], ", "]]];
  <|"Pass" -> reasons === {}, "Reasons" -> reasons, "Census" -> c1, "Comparison" -> cmp|>];



(* ::Section:: *)
(*Move (ii): swaps*)


(* the master's part on its own sector when it is one integral: {integral, its eps-free coefficient}, else None *)
ownTerm[sys_, l_] := Module[{rec = PFBMaster[sys, l], top, ints, c, r},
  top = topPart[rec["RootFree"] /. Dinv[a_, _] :> a, rec["Sector"], PFBFamily[sys, rec["Family"]]["N"]];
  ints = Union[Cases[{top}, _j, Infinity]];
  If[Length[ints] =!= 1, Return[None]];
  c = Together[Coefficient[Collect[top, _j], ints[[1]]]];
  r = Together[c /. eps -> 1];
  If[r === 0 || ! MatchQ[Together[c/r], 1 | eps | eps^_Integer], None, {ints[[1]], r}]];

PFBSwapCandidates[ctx_Association, red_Association, cal_Association, key_List, m_Integer, opts_Association : <||>] := Module[{sys = ctx["System"], st = ctx["State"], sl, cap, c0, us,
    dimUS, secBase, others, nat, cands, pow, normsOf, unitOf, curQ, okQ, singles, pairs, sets, intsOf, scan, ok, out = {}, passed, t0 = AbsoluteTime[],
    maxSets = Lookup[opts, "MaxSwapSets", 200], maxSwaps = Lookup[opts, "MaxSwaps", 3]},
  sl = PFBCurrentSlice[ctx["Dir"], st];
  cap = Lookup[opts, "MaxEpsDegree", Lookup[ctx["Run"], "MaxEpsDegree", $PFBMaxEpsDegree]];
  c0 = Block[{PFBPrint}, PFBCensus[sys, sl, <|"MaxEpsDegree" -> cap|>]];
  us = PFBUnitScale[sys]; dimUS = PFBFamily[sys, First[sys["Order"]]]["Invariants"][us];
  secBase = Select[Intersection[PFBSectorMasters[sys, key], sl["Labels"]], PFBMaster[sys, #]["Family"] === key[[1]] &];
  (* the partners of a pair: the other base-family masters of the sector that may change (opts "Partners": the move
     gives PFBMovableMasters' free masters) *)
  others = If[TrueQ[Lookup[opts, "Pairs", True]], DeleteCases[If[ListQ[Lookup[opts, "Partners", All]], Intersection[secBase, opts["Partners"]], secBase], m], {}];
  nat = PFBNaturalIntegrals[sys, red, key, <|"MaxWeight" -> Lookup[opts, "SwapWeight", 1]|>];
  cands = Select[nat["Candidates"], MatchQ[#, _j] &];
  (* each candidate integral carries the slot's own power of eps, as in the pair scan *)
  pow[l_] := With[{p = DeleteCases[Flatten[PFBEpsPowers[PFBMaster[sys, l]["RootFree"]][[All, 2]]], _String]}, If[p === {}, 0, Min[p]]];
  (* the normalisations that keep the master's mass dimension (or make it dimensionless, when the master mixes
     dimensions): a power of the unit scale, and the master's coefficient on its own sector times one *)
  normsOf[l_, c_] := normsOf[l, c] = Module[{pref = PFBMaster[sys, l]["Pref"], wOld = PFBMasterWeight[sys, PFBMaster[sys, l]["RootFree"], PFBMaster[sys, l]["Pref"]],
      own = ownTerm[sys, l], res = {}},
    Do[Module[{d0 = nm[[2]] eps^pow[l] c, w, k},
       w = PFBMasterWeight[sys, d0, pref];
       k = If[w === $Failed, $Failed, Together[If[wOld === $Failed, -(w /. eps -> 0), wOld - w]/dimUS]];
       If[IntegerQ[k], AppendTo[res, {nm[[1]], Together[us^k d0]}]]],
      {nm, If[own === None || Together[own[[2]] - 1] === 0, {{"unit", 1}}, {{"unit", 1}, {"inherit", own[[2]]}}]}];
    res];
  unitOf[l_, c_] := Replace[normsOf[l, c], {{{"unit", d_}, ___} :> d, _ :> None}];
  (* a candidate that is the current master is no swap; its own integral alone is one when the master has a lower part *)
  curQ[l_, d_] := Together[d - PFBMaster[sys, l]["RootFree"]] === 0;
  okQ[l_, c_] := With[{d = unitOf[l, c]}, d =!= None && ! curQ[l, d]];
  singles = Cases[Table[If[okQ[m, c], {<|m -> c|>, <|m -> unitOf[m, c]|>}, Nothing], {c, cands}], {_, _}];
  pairs = Flatten[Table[If[c1 =!= c2 && okQ[m, c1] && okQ[m2, c2], {{<|m -> c1, m2 -> c2|>, <|m -> unitOf[m, c1], m2 -> unitOf[m2, c2]|>}}, {}],
      {m2, others}, {c1, cands}, {c2, cands}], 3];
  sets = Take[Join[singles, pairs], UpTo[maxSets]];
  intsOf = Association[Thread[sets[[All, 2]] -> sets[[All, 1]]]];
  scan = PFBScanSets[sys, sl, red, cal, key, sets[[All, 2]], <|"Census" -> c0, "State" -> st, "MaxEpsDegree" -> cap|>];
  (* swaps keep the census exactly: pole-free rows, nothing deferred, nothing raised above the cap *)
  ok = Select[scan["Results"], #["bad"] == 0 && #["newBad"] === 0 && #["deferred"] === 0 && #["over"] == 0 &];
  Do[Module[{ints = intsOf[r["set"]], slots, combos},
     slots = Keys[ints];
     combos = Take[Select[Tuples[normsOf[#, ints[#]] & /@ slots], ! AnyTrue[Transpose[{slots, #[[All, 2]]}], curQ @@ # &] &], UpTo[4]];
     Do[Module[{base = AssociationThread[slots -> cb[[All, 2]]], defs, ch, slNew, chk, rows},
        defs = PFBImageDefs[sys, base];
        ch = Quiet[PFBChangeVectors[sys, sl, red, cal, defs]];
        If[ch === $Failed, Continue[]];
        slNew = Block[{Print}, Quiet[PFBApplyChange[sl, Join[ch, <|"Name" -> "swap"|>]]]];
        If[! AssociationQ[slNew], Continue[]];
        chk = PFBSimplifySliceCheck[sys, sl, c0, slNew, <|"MaxEpsDegree" -> cap|>];
        rows = Union[Keys[defs], PFBRowsCouplingTo[sl, Keys[defs]]];
        AppendTo[out, <|"Set" -> base, "Defs" -> defs, "Integrals" -> ints, "Normalisation" -> AssociationThread[slots -> cb[[All, 1]]], "Pass" -> chk["Pass"],
          "Reasons" -> chk["Reasons"], "Height" -> PFBRowsDigitHeight[slNew, rows], "HeightBefore" -> PFBRowsDigitHeight[sl, rows], "Rows" -> rows, "Det" -> Last[slNew["History"]]["DetT"],
          "MaxCutChanged" -> TrueQ[r["maxCut"]]|>]], {cb, combos}]], {r, ok}];
  passed = Select[out, #["Pass"] &];
  <|"Candidates" -> (KeyDrop[#, {"Pass", "Reasons"}] & /@ Take[SortBy[passed, {#["Height"], Length[#["Set"]]} &], UpTo[maxSwaps]]), "Master" -> m, "Key" -> key,
    "Sets" -> Length[sets], "Tried" -> Length[scan["Results"]], "Clear" -> Length[ok], "Passed" -> Length[passed], "Refused" -> Length[out] - Length[passed],
    "Dependent" -> scan["Dependent"], "OutsidePool" -> scan["OutsidePool"], "InPool" -> Length[cands], "NotInPool" -> Length[nat["NotInPool"]],
    "Seconds" -> Round[AbsoluteTime[] - t0, 0.1]|>];

(* the sector's own reduction job when it calibrates exactly against the current slice and its pool holds natural
   integrals of the sector; else None *)
scanJobOf[ctx_, key_] := Module[{jd = FileNameJoin[{ctx["Dir"], "jobs", sectorJobName[key]}], red},
  If[! DirectoryQ[jd] || PFBRedFiles[jd] === {}, Return[None]];
  red = Quiet@PFBReadRed[jd, 1];
  If[! AssociationQ[red] || PFBCalibrate[PFBCurrentSlice[ctx["Dir"], ctx["State"]], red]["Status"] =!= "exact", Return[None]];
  If[Length[Select[PFBNaturalIntegrals[ctx["System"], red, key]["Candidates"], MatchQ[#, _j] &]] < 2, Return[None]];
  jd];

(* a reduction of the sector's subtree at the slice point with the default pool (its natural integrals), reusing the
   identities of its degree job or of its own job *)
writeScanJob[ctx_, key_, id_] := Module[{dir = ctx["Dir"], run = ctx["Run"], sl = PFBCurrentSlice[ctx["Dir"], ctx["State"]], reuse},
  reuse = SelectFirst[{FileNameJoin[{dir, "jobs", "deg_" <> sectorJobName[key], "ibps"}], FileNameJoin[{dir, "jobs", sectorJobName[key], "ibps"}]}, DirectoryQ, None];
  PFBSubtreeJob[ctx["System"], dir, <|"Name" -> "simp" <> ToString[id] <> "_scan_" <> sectorJobName[key], "SectorKey" -> key, "Points" -> {sl["Point"]},
    "Derivatives" -> sl["Derivatives"], "Seeds" -> run["Seeds"], "MaxGB" -> run["MaxGB"], "TimeLimit" -> run["TimeLimit"],
    "Threads" -> Replace[run["Threads"], Automatic -> Max[1, Min[8, $ProcessorCount - 1]]], "ReuseIds" -> reuse, "Replace" -> True|>]];

swapMove[ctx_, tab_, ph_, opts_] := Module[{sys = ctx["System"], prep = Lookup[opts, "Record", None], id = Lookup[opts, "MoveId", 0], mv, worst, m, key, jd, red, cal, sc,
    cands, sl = PFBCurrentSlice[ctx["Dir"], ctx["State"]], info},
  mv = PFBMovableMasters[ctx, tab, <|"EpsForm" -> True|>];
  If[AssociationQ[prep],
    {m, key, jd} = Lookup[prep["Prep"], {"Master", "Key", "Job"}]; worst = Lookup[prep["Prep"], "Worst", Missing[]],
    worst = PFBWorstMasters[tab, <|"Labels" -> mv["Free"]|>];
    If[worst === {}, Return[<|"Status" -> "no gain", "Message" -> "move (ii): no master may be swapped (" <> ToString[Length[mv["Protected"]]] <> " left alone)", "Candidates" -> {},
       "Info" -> <|"Protected" -> mv["Protected"]|>|>]];
    worst = First[worst]; m = worst["Label"]; key = PFBMaster[sys, m]["SectorKey"];
    jd = scanJobOf[ctx, key];
    If[jd === None,
      jd = writeScanJob[ctx, key, id];
      If[jd === $Failed, Return[<|"Status" -> "no gain", "Message" -> "move (ii): the reduction of " <> PFBSectorString[key] <> " for the scan could not be written", "Candidates" -> {}|>]];
      Return[<|"Status" -> "jobs", "Jobs" -> {jd}, "Keys" -> {key}, "Prep" -> <|"Master" -> m, "Key" -> key, "Job" -> jd, "Worst" -> worst|>,
        "Message" -> "move (ii): the worst master is ut[" <> ToString[m] <> "] (" <> PFBSectorString[key] <> ", {highest, terms at it, sum} " <> ToString[worst["Objective"]] <>
          " in its row and column); its scan needs a reduction of the sector at the slice point with its natural integrals: " <> FileNameTake[jd]|>]]];
  red = Quiet@PFBReadRed[jd, 1];
  info = <|"Master" -> m, "Key" -> key, "Job" -> jd, "Worst" -> worst|>;
  If[! AssociationQ[red], Return[<|"Status" -> "no gain", "Message" -> "move (ii): the reduction " <> FileNameTake[jd] <> " has no result (" <> ToString[PFBSubtreeStatus[jd]["Status"]] <> ")",
     "Candidates" -> {}, "Info" -> info|>]];
  cal = PFBCalibrate[sl, red];
  If[cal["Status"] =!= "exact", Return[<|"Status" -> "no gain", "Message" -> "move (ii): the reduction " <> FileNameTake[jd] <> " does not calibrate exactly against the current slice (" <>
     cal["Status"] <> ")", "Candidates" -> {}, "Info" -> info|>]];
  (* a pair's partner must be free to change as well *)
  sc = PFBSwapCandidates[ctx, red, cal, key, m, Join[opts, <|"Partners" -> mv["Free"]|>]];
  cands = Table[With[{c = sc["Candidates"][[n]]}, <|"Name" -> "swap" <> ToString[n], "T" -> c["Defs"], "Defs" -> c["Defs"], "RedJob" -> jd, "Objective" -> Missing["NotPredicted"],
      "Info" -> KeyDrop[c, {"Defs"}]|>], {n, Length[sc["Candidates"]]}];
  <|"Status" -> If[cands === {}, "no gain", "proposed"],
    "Message" -> "move (ii): ut[" <> ToString[m] <> "] of " <> PFBSectorString[key] <> ": " <> ToString[sc["Sets"]] <> " sets scanned, " <> ToString[sc["Clear"]] <> " clear the sector's rows, " <>
      ToString[sc["Passed"]] <> " keep the census" <> If[cands === {}, "; no swap", "; " <> ToString[Length[cands]] <> " candidate(s) by digit height (" <>
        StringRiffle[ToString /@ (#["Info"]["Height"] & /@ cands), ", "] <> " against " <> ToString[sc["Candidates"][[1]]["HeightBefore"]] <> " now)"],
    "Candidates" -> cands, "Info" -> Join[info, KeyDrop[sc, {"Candidates"}]]|>];


(* ::Section:: *)
(*Moves (iii) and (iv): a low-degree fit from samples of the learned system*)


(* Exact linear algebra over the rationals. affine[A, b]: the solutions of A.x = b as {x0, N} (x = x0 + N.z), or
   $Failed when there is none. Many rows are first combined by a random integer matrix (the solution is then checked on
   every row) *)
nullOf[A_, n_] := If[A === {}, IdentityMatrix[n], With[{ns = NullSpace[A]}, If[ns === {}, ConstantArray[0, {n, 0}], Transpose[ns]]]];
affine0[A_, b_, n_] := Module[{rr, piv, x0, ok},
  If[A === {}, Return[{ConstantArray[0, n], IdentityMatrix[n]}]];
  rr = RowReduce[MapThread[Append, {A, b}]];
  piv = Table[FirstPosition[rr[[r]], x_ /; x =!= 0, {0}, {1}, Heads -> False][[1]], {r, Length[rr]}];
  If[MemberQ[piv, n + 1], Return[$Failed]];
  x0 = ConstantArray[0, n];
  Do[If[piv[[r]] > 0, x0[[piv[[r]]]] = rr[[r, n + 1]]], {r, Length[rr]}];
  {x0, nullOf[A, n]}];
affine[A_, b_, n_] := Module[{m = Length[A], R, sol},
  If[n == 0, Return[If[AllTrue[b, # === 0 &], {{}, ConstantArray[0, {0, 0}]}, $Failed]]];
  If[m <= n + 8, Return[affine0[A, b, n]]];
  R = BlockRandom[RandomInteger[{-9, 9}, {n + 8, m}], RandomSeeding -> m n];
  sol = affine0[R . A, R . b, n];
  If[sol =!= $Failed && AllTrue[A . sol[[1]] - b, # === 0 &] && AllTrue[Flatten[A . sol[[2]]], # === 0 &], sol, affine0[A, b, n]]];
(* narrow the affine space {a0, N} by the rows A.a = b; $Failed when they are inconsistent with it *)
narrow[{a0_, N_}, A_, b_] := Module[{nz = Length[First[N, {}]], s},
  If[A === {}, Return[{a0, N}]];
  If[Dimensions[N][[2]] == 0, Return[If[AllTrue[A . a0 - b, # === 0 &], {a0, N}, $Failed]]];
  s = affine[A . N, b - A . a0, Dimensions[N][[2]]];
  If[s === $Failed, $Failed, {a0 + N . s[[1]], If[Dimensions[s[[2]]][[2]] == 0, ConstantArray[0, {Length[a0], 0}], N . s[[2]]]}]];

(* the rows that say: y(tau_1), ..., y(tau_S) at equally spaced tau are a polynomial of degree <= d (vanishing differences
   of order d + 1); y affine in the unknowns, {const, vector} each *)
diffRows[ys_List, d_Integer] := Module[{S = Length[ys], w = Table[(-1)^(d + 1 - r) Binomial[d + 1, r], {r, 0, d + 1}]},
  If[S < d + 2, Return[{{}, {}}]];
  Transpose[Table[{w . ys[[s ;; s + d + 1, 2]], -(w . ys[[s ;; s + d + 1, 1]])}, {s, S - d - 1}]]];

(* the denominators a new term may take: products of the letters of its contributions (multiplicities at most their
   lcm's) of total degree at most d, the largest first, then the closest to the old term's own denominator *)
denOptions[lcm_Association, own_Association, pdeg_Association, d_Integer, maxOpt_Integer] := Module[{ls = Keys[lcm], tup, opts},
  tup = If[ls === {}, {{}}, Tuples[Range[0, #] & /@ Values[lcm]]];
  If[Length[tup] > 4096, tup = Take[tup, 4096]];
  opts = Select[Table[AssociationThread[ls -> t], {t, tup}], Total[KeyValueMap[#2 pdeg[#1] &, #]] <= d &];
  Take[SortBy[opts, {-Total[KeyValueMap[#2 pdeg[#1] &, #]], Total[Abs[Lookup[#, ls, 0] - Lookup[own, ls, 0]]]} &], UpTo[maxOpt]]];

(* the spurious factor of a term along one line: its old values ys at tau = 1 .. S (eps^p coefficient, nothing shifted)
   are N/(Lt P) with Lt its own known letters, N of its numerator degree and P of its unexplained denominator degree u (a
   null vector of the linear system N(tau) - y(tau) Lt(tau) P(tau) = 0; at least one more point than unknowns). The values
   of P at the points, or Missing when the line does not fix it *)
spurLine[pr_, ys_List, l_, t_] := Module[{sp = t["Spurious"], n, u, S = Length[ys], lt, A, ns, P},
  n = sp["Num"]; u = sp["Degree"];
  If[S < n + u + 3, Return[Missing["FewPoints"]]];
  lt = Table[Times @@ KeyValueMap[(#1 /. pr["Line"][[l, s]])^#2 &, Select[t["Own"], IntegerQ]], {s, S}];
  A = Table[Join[Table[s^a, {a, 0, n}], Table[-ys[[s]] lt[[s]] s^b, {b, 0, u}]], {s, S}];
  ns = NullSpace[A];
  If[Length[ns] =!= 1, Return[Missing["NotFixed"]]];
  P = Table[Sum[ns[[1, n + 2 + b]] s^b, {b, 0, u}], {s, S}];
  If[MemberQ[P, 0], Missing["Zero"], P]];
(* an old term's unexplained denominator degree, for the fit: <|"Degree" -> u, "Num", "Den"|> when u > 0, else None *)
spurOf[t_, xs_] := If[! AssociationQ[t], None, Module[{u = t["DenUnexplained"]},
   If[! IntegerQ[u] && AssociationQ[t["DenLetters"]] && AllTrue[t["DenLetters"], IntegerQ], u = t["Den"] - Total[KeyValueMap[#2 totDeg[#1, xs] &, t["DenLetters"]]]];
   If[IntegerQ[u] && u > 0 && IntegerQ[t["Num"]], <|"Degree" -> u, "Num" -> t["Num"], "Den" -> t["Den"]|>, None]]];
(* the points per line a term with a spurious factor needs *)
spurPoints[sp_] := If[AssociationQ[sp], sp["Num"] + sp["Degree"] + 3, 0];

(* the fit at target degree d. vals[[n]] = <|termKey -> {y0, yvec}|> at sample n; samples are ordered (line, tau, eps);
   each term {key, p} must become Q * (its eps^p coefficient) a polynomial of degree <= d on every fit line, Q a product of
   letters (denOptions), or, for a term whose own denominator has a factor no known singularity explains, that factor
   along the line times letters (spurLine); the eps dependence is the Laurent range {lo, hi}, every extra eps value a
   consistency check. Greedy over the terms, then the unknowns of highest complexity set to zero while a solution
   remains, then the check line. Returns <|"Status", "Solution", "Chosen", "Equations"|> *)
fitAt[pr_, vals_, d_Integer] := Module[{L = pr["FitLines"], S = pr["Taus"], E = Length[pr["Eps"]], lo = pr["Range"][[1]], hi = pr["Range"][[2]], nu = Length[pr["Unknowns"]],
    E0, W, idx, perPow, cons, space, nEq = 0, terms, chosen = <||>, fail = None, linePts, qAt, rowsFor, chk, spur, optsOf},
  E0 = hi - lo + 1;
  W = Inverse[Table[e^p, {e, Take[pr["Eps"], E0]}, {p, lo, hi}]];
  idx[l_, s_, e_] := ((l - 1) S + (s - 1)) E + e;
  (* the eps^p coefficient of a term at (line, tau): {const, vector} *)
  perPow[l_, s_, key_, p_] := With[{ys = Table[vals[[idx[l, s, e]]][key], {e, E0}]}, {W[[p - lo + 1]] . ys[[All, 1]], W[[p - lo + 1]] . ys[[All, 2]]}];
  (* the old term's own unexplained denominator factor on every line, fit and check lines: its values at the points *)
  spur = Association[Table[If[AssociationQ[Lookup[t, "Spurious", None]],
      With[{v = Table[spurLine[pr, Table[perPow[l, s, t["Key"], t["Power"]][[1]], {s, S}], l, t], {l, L + 1}]}, If[FreeQ[v, _Missing], {t["Key"], t["Power"]} -> v, Nothing]],
      Nothing], {t, pr["Terms"]}]];
  (* the denominators a term may take: the letters, and with its own unexplained factor *)
  optsOf[t_] := With[{tk = {t["Key"], t["Power"]}}, If[KeyExistsQ[spur, tk],
     denOptions[Append[t["Letters"], $spur -> 1], Append[t["Own"], $spur -> 1], Append[pr["ProbeDegree"], $spur -> t["Spurious"]["Degree"]], d, pr["MaxDenominators"]],
     denOptions[t["Letters"], t["Own"], pr["ProbeDegree"], d, pr["MaxDenominators"]]]];
  (* every eps value beyond the range: its value must be the Laurent polynomial's *)
  cons[l_] := With[{rows = Flatten[Table[With[{c = Table[perPow[l, s, key, p], {p, lo, hi}]}, Table[With[{y = vals[[idx[l, s, e]]][key], v = pr["Eps"][[e]]^Range[lo, hi]},
        {y[[2]] - v . c[[All, 2]], -(y[[1]] - v . c[[All, 1]])}], {e, E0 + 1, E}]], {s, S}, {key, pr["Keys"]}], 2]}, If[rows === {}, {{}, {}}, Transpose[rows]]];
  qAt[q_, l_, s_, tk_] := Times @@ KeyValueMap[If[#1 === $spur, spur[tk][[l, s]], #1 /. pr["Line"][[l, s]]]^#2 &, q];
  rowsFor[l_, key_, p_, q_] := diffRows[Table[qAt[q, l, s, {key, p}] perPow[l, s, key, p], {s, S}], d];
  space = Module[{c = Table[cons[l], {l, L}], A, b}, A = Join @@ c[[All, 1]]; b = Join @@ c[[All, 2]]; nEq += Length[A]; affine[A, b, nu]];
  If[space === $Failed, Return[<|"Status" -> "no solution", "Message" -> "the samples are not a Laurent polynomial in eps of the range " <> ToString[{lo, hi}], "Equations" -> nEq|>]];
  (* the terms above the target first, the highest first; then the others, fewest options first *)
  terms = SortBy[pr["Terms"], {-Replace[#["Degree"], None -> -1], Length[optsOf[#]]} &];
  Do[Module[{opts = optsOf[t], ok = False},
     Do[Module[{bl = Table[rowsFor[l, t["Key"], t["Power"], q], {l, L}], A, b, s2},
        A = Join @@ bl[[All, 1]]; b = Join @@ bl[[All, 2]];
        s2 = narrow[space, A, b];
        If[s2 =!= $Failed, space = s2; chosen[{t["Key"], t["Power"]}] = q; nEq += Length[A]; ok = True; Break[]]], {q, opts}];
     If[! ok, fail = t; Break[]]], {t, terms}];
  If[fail =!= None, Return[<|"Status" -> "no solution", "Message" -> "no denominator of degree <= " <> ToString[d] <> " fits the term " <> ToString[{fail["Key"], fail["Power"]}] <>
      " (current degree " <> ToString[fail["Degree"]] <> ")", "Equations" -> nEq|>]];
  (* the simplest solution: the unknowns of highest complexity set to zero while one remains *)
  Do[With[{s2 = narrow[space, {UnitVector[nu, u]}, {0}]}, If[s2 =!= $Failed, space = s2]], {u, Reverse[Ordering[pr["Complexity"]]]}];
  (* the check line: the same terms with the same denominators, and the eps consistency *)
  chk = Module[{l = L + 1, a = space[[1]], bad},
    bad = Select[pr["Terms"], Function[t, With[{r = rowsFor[l, t["Key"], t["Power"], chosen[{t["Key"], t["Power"]}]]}, r[[1]] =!= {} && ! AllTrue[r[[1]] . a - r[[2]], # === 0 &]]]];
    If[bad === {} && With[{c = cons[l]}, c[[1]] === {} || AllTrue[c[[1]] . a - c[[2]], # === 0 &]], "passed", "failed: " <> ToString[Length[bad]] <> " term(s) above the target on the check line"]];
  If[chk =!= "passed", Return[<|"Status" -> "no solution", "Message" -> "the fit does not hold on the check line (" <> chk <> ")", "Equations" -> nEq|>]];
  <|"Status" -> "solved", "Solution" -> space[[1]], "Free" -> Dimensions[space[[2]]][[2]], "Chosen" -> chosen, "Equations" -> nEq, "Check" -> chk|>];

(* lines of the fit: base + tau direction, tau = 1 .. S, positive integers (bases 20 .. 99, directions 1 .. 97); the
   last one checks the fit. No point may be a zero of a polynomial of avoid (the probes, the invariants, their
   differences and the prefactors: fitAvoid), and every one of them keeps its total degree along each direction (its top
   homogeneous part does not vanish there; with directions 1 .. 3, (x - y)^k lost its degree on a third of the lines). A
   line that fails is drawn again, at most 200 times per line; $Failed when they are not found *)
topHom[p_, xs_] := Module[{lam, e = Expand[p /. Thread[xs -> lam xs]]}, Coefficient[e, lam, Exponent[e, lam]]];
fitLines[xs_, n_, S_, seed_, avoid_List : {}] := Module[{tops = topHom[#, xs] & /@ avoid, okQ, lines = {}, k = 0},
  okQ[{b_, v_}] := AllTrue[tops, Together[# /. Thread[xs -> v]] =!= 0 &] && AllTrue[Range[S], Function[tau, AllTrue[avoid, Together[# /. Thread[xs -> b + tau v]] =!= 0 &]]];
  BlockRandom[While[Length[lines] < n && k < 200 n, k++;
      With[{c = {RandomInteger[{20, 99}, Length[xs]], RandomInteger[{1, 97}, Length[xs]]}}, If[okQ[c], AppendTo[lines, c]]]], RandomSeeding -> seed];
  If[Length[lines] < n, $Failed, Table[Thread[xs -> l[[1]] + tau l[[2]]], {l, lines}, {tau, S}]]];
(* what the points of a fit must avoid (unit scale 1): the family's known singularities as probes, the invariants, their
   differences and their differences with the unit scale, and the factors of the masters' prefactors (their dlog enters
   the rows) *)
fitAvoid[sys_, dir_, fam_, xs_, labs_List] := Module[{us = PFBUnitScale[sys], pf},
  pf = Flatten[Table[With[{p2 = Together[((PFBMaster[sys, l]["Pref"] /. PFBRootDefs[sys])^2) /. us -> 1]},
      Cases[Join[FactorList[Numerator[p2]], FactorList[Denominator[p2]]], {g_, _} /; ! FreeQ[g, Alternatives @@ xs] :> g]], {l, labs}]];
  Select[DeleteDuplicates[Join[PFBDegreeProbes[sys, dir, {fam}]["Probes"], xs, # - 1 & /@ xs, Flatten[Table[xs[[a]] - xs[[b]], {a, Length[xs]}, {b, a + 1, Length[xs]}]], pf],
     Expand[#1 - #2] === 0 || Expand[#1 + #2] === 0 &], PolynomialQ[#, xs] && ! FreeQ[#, Alternatives @@ xs] &]];
$fitEps = {1/11, 2/13, 3/17, 5/19, 7/23, 11/29, 13/31, 17/37, 19/41, 23/43};
(* the estimated cost of a fit's job: the sector's census job (identities, learning, the slice point) and its degree
   measurement once per 100 samples, at least twice (a sample is one evaluation of the learned system over a few primes;
   a measurement, FFAllDegrees along lines in every invariant, about a hundred) *)
PFBFitJobCost[tab_Association, key_, n_Integer] := With[{r = Lookup[Lookup[tab, "Sectors", <||>], Key[key], <||>]},
  With[{job = Replace[Lookup[r, "JobWallSeconds", Missing[]], Except[_?NumericQ] :> Replace[Lookup[r, "JobSeconds", 0], Except[_?NumericQ] -> 0]],
      meas = Replace[Lookup[r, "JobSeconds", 0], Except[_?NumericQ] -> 0]}, Ceiling[job + meas Max[2, n/100]]]];
samplePoints[pr_] := Flatten[Table[Join[{eps -> e}, pr["Line"][[l, s]]], {l, pr["FitLines"] + 1}, {s, pr["Taus"]}, {e, pr["Eps"]}], 2];


(* ::Section:: *)
(*Move (iii): shifts by lower masters*)


subSectorQ[a_, b_] := And @@ Thread[a <= b] && a =!= b;
powOf[sys_, l_] := With[{p = DeleteCases[Flatten[PFBEpsPowers[PFBMaster[sys, l]["RootFree"]][[All, 2]]], _String]}, If[p === {}, 0, Min[p]]];
dlogOf[p_, x_] := Together[D[p^2, x]/(2 p^2)];

(* the usable letters of a family as probes (unit scale 1): <|probe -> <|"Letter", "Dim"|>|> *)
probeLetters[sys_, dir_, fam_] := Module[{us = PFBUnitScale[sys], xs, out = <||>, np = PFBDegreeProbes[sys, dir, {fam}]["NonPolynomial"]},
  xs = DeleteCases[sys["Invariants"], us];
  (* a letter with a square root is no factor of a rational coefficient *)
  Do[If[Expand[L - us] =!= 0 && ! MemberQ[np, L], Module[{w = MaximalCutBasis`Rules`MCBWeightOf[PFBFamily[sys, fam], L], q = PFBNormalizePolynomials[{Together[L /. us -> 1]}, xs]},
      If[NumericQ[w] && Length[q] == 1, out[q[[1]]] = <|"Letter" -> L, "Dim" -> w|>]]], {L, Lookup[PFBKnownSingularities[sys, dir, fam], "Letters", {}]}];
  out];

(* the ansatz of a coefficient of mass dimension delta: monomials of the invariants of total degree <= deg, each made
   homogeneous by a power of the unit scale, and the same divided by one letter (lets); a power of the unit scale in a
   denominator only when it is a letter or there is no alphabet *)
ansatzOf[sys_, delta_, deg_Integer, lets_Association, usLetter_] := Module[{us = PFBUnitScale[sys], xs, dims, dimUS, mons, out = {}},
  xs = DeleteCases[sys["Invariants"], us];
  dims = PFBFamily[sys, First[sys["Order"]]]["Invariants"]; dimUS = dims[us];
  mons = Flatten[Table[If[Total[a] <= deg, Times @@ (xs^a), Nothing], {a, Tuples[Range[0, deg], Length[xs]]}]];
  Do[Module[{e = (delta - Total[Exponent[mo, xs] Lookup[dims, xs]] + lw[[2]])/dimUS},
     If[IntegerQ[e] && (e >= 0 || usLetter), AppendTo[out, Together[us^e mo/lw[[1]]]]]], {mo, mons}, {lw, Join[{{1, 0}}, {#["Letter"], #["Dim"]} & /@ Values[lets]]}];
  DeleteDuplicates[out, Together[#1 - #2] === 0 &]];

PFBShiftProblem[ctx_Association, tab_Association, i_Integer, opts_Association : <||>] := Module[{sys = ctx["System"], dir = ctx["Dir"], sl, ix, us, xs, ders, nk, cap, fam, secI,
    K, ents, entIdx, termsAt, degOf, ownL, q, wI, deltas, lets, usLetter, ans, dc = Lookup[opts, "ShiftDegree", 2], withL = TrueQ[Lookup[opts, "ShiftLetters", True]],
    maxU = Lookup[opts, "MaxUnknowns", 60], maxSmp = Lookup[opts, "MaxSamples", 1000], unk, cx, touched, lo, hi, terms, d0, pdeg, prefOf, phiDen, nPhi, nL, S, E, pr,
    rowsJob, lcmOf, letterAt},
  sl = PFBCurrentSlice[dir, ctx["State"]]; ix = sl["Index"];
  us = PFBUnitScale[sys]; xs = DeleteCases[sys["Invariants"], us];
  ders = sl["Derivatives"]; nk = Length[ders];
  cap = Lookup[opts, "MaxEpsDegree", Lookup[ctx["Run"], "MaxEpsDegree", $PFBMaxEpsDegree]];
  fam = PFBMaster[sys, i]["Family"]; secI = PFBMaster[sys, i]["Sector"];
  (* the lower masters it may be shifted by: its own family, a proper subsector, coupled in its row, not coupling back *)
  K = Select[sl["Labels"], Function[k, k =!= i && PFBMaster[sys, k]["Family"] === fam && subSectorQ[PFBMaster[sys, k]["Sector"], secI] &&
      AnyTrue[Range[nk], sl["R"][[#, ix[i], ix[k]]] =!= 0 &] && AllTrue[Range[nk], sl["R"][[#, ix[k], ix[i]]] === 0 &]]];
  If[K === {}, Return["ut[" <> ToString[i] <> "] couples to no lower master of its family"]];
  ents = Flatten[Values[Lookup[#, "Entries", {}] & /@ Select[Lookup[tab, "Sectors", <||>], #["Status"] === "measured" &]], 1];
  entIdx = Association[Table[{e["Row"], e["Column"], e["Matrix"]} -> e["Terms"], {e, ents}]];
  termsAt[r_, c_, d_, p_] := SelectFirst[Lookup[entIdx, Key[{r, c, d}], {}], #["Power"] === p &, None];
  degOf[t_] := If[t === None, None, Max[t["Num"], t["Den"]]];
  letterAt[t_] := If[t === None, <||>, Replace[t["DenLetters"], Except[_Association] -> <||>]];
  If[! AllTrue[Union[{i}, K], MemberQ[Lookup[Lookup[tab["Sectors"], Key[PFBMaster[sys, #]["SectorKey"]], <||>], "Rows", {}], #] &],
    Return["the rows of ut[" <> ToString[i] <> "] and of its lower masters are not all measured"]];
  (* the lower masters that carry the highest terms of its row first *)
  K = SortBy[K, -Max[Append[Cases[Flatten[Table[degOf /@ Lookup[entIdx, Key[{i, #, d}], {}], {d, nk}]], _Integer], -1]] &];
  K = Take[K, UpTo[Lookup[opts, "MaxLower", 6]]];
  (* rule 1: c_k carries the power of eps that makes master k's integrals take the shifted master's power *)
  q = Association[Table[k -> powOf[sys, i] - powOf[sys, k], {k, K}]];
  wI = PFBMasterWeight[sys, PFBMaster[sys, i]["RootFree"], PFBMaster[sys, i]["Pref"]];
  deltas = Association[Table[k -> Together[wI - PFBMasterWeight[sys, PFBMaster[sys, k]["RootFree"], PFBMaster[sys, k]["Pref"]]], {k, K}]];
  K = Select[K, NumericQ[deltas[#]] &];
  If[K === {}, Return["no lower master of ut[" <> ToString[i] <> "] has a mass dimension a rational coefficient can match"]];
  lets = probeLetters[sys, dir, fam];
  usLetter = PFBLetters[sys] === {} || MemberQ[Expand[PFBLetters[sys]], Expand[us] | Expand[-us]];
  (* every known singularity of the terms may be a factor of a fit's denominator; only letters go into the ansatz *)
  pdeg = Association[Table[pp -> totDeg[pp, xs], {pp, Union[Keys[lets], Flatten[Keys[letterAt[#]] & /@ Flatten[Values[KeySelect[entIdx, MemberQ[Union[{i}, K], #[[1]]] &]]]]]}]];
  (* the ansatz of each c_k: the letters of row i's terms in column k may divide it *)
  ans[deg_, wl_] := Association[Table[k -> ansatzOf[sys, deltas[k], deg, If[wl, KeyTake[lets, Union[Flatten[Table[Keys[letterAt[t]], {d, nk}, {t, Lookup[entIdx, Key[{i, k, d}], {}]}]]]], <||>], usLetter],
     {k, K}]];
  unk = ans[dc, withL];
  (* bounded: no letters first, then a lower degree, then fewer lower masters *)
  While[Total[Length /@ unk] > maxU,
    Which[withL, withL = False, dc > 0, dc--, Length[K] > 1, K = Most[K], True, Break[]];
    unk = KeyTake[ans[dc, withL], K]];
  If[Total[Length /@ unk] > maxU, Return["more than " <> ToString[maxU] <> " unknowns"]];
  cx = Flatten[Table[With[{f = unk[k][[n]]}, Total[Exponent[Numerator[f /. us -> 1], xs]] + 2 Boole[! FreeQ[Denominator[f /. us -> 1], Alternatives @@ xs]]], {k, K}, {n, Length[unk[k]]}]];
  unk = Flatten[Table[{k, n, unk[k][[n]]}, {k, K}, {n, Length[unk[k]]}], 1];
  (* the columns the shift changes in row i: the lower masters and the columns of their rows *)
  touched = Complement[Union[K, Select[sl["Labels"], Function[c, AnyTrue[K, Function[k, AnyTrue[Range[nk], sl["R"][[#, ix[k], ix[c]]] =!= 0 &]]]]]], {i}];
  rowsJob = Union[{i}, K];
  lo = Min[Append[Cases[Flatten[Table[Lookup[Lookup[entIdx, Key[{r, c, d}], {}], "Power"], {r, rowsJob}, {c, sl["Labels"]}, {d, nk}]], _Integer], 0]];
  hi = If[cap === Infinity, Max[Append[Cases[Flatten[Table[Lookup[Lookup[entIdx, Key[{r, c, d}], {}], "Power"], {r, rowsJob}, {c, sl["Labels"]}, {d, nk}]], _Integer], 0]] + Max[Append[Values[q], 0]], cap];
  (* the letters a term's denominator may hold: those of every contribution (A_kj c_k, A_ii c_j, d c_j, c_j dlog) *)
  prefOf[l_] := PFBMaster[sys, l]["Pref"];
  phiDen[k_] := Merge[Table[Association[Cases[FactorList[Denominator[Together[f /. us -> 1]]], {g_, m_} /; ! FreeQ[g, Alternatives @@ xs] :>
        (First[PFBNormalizePolynomials[{g}, xs]] -> m)]], {f, Cases[unk, {k, _, f_} :> f]}], Max];
  lcmOf[d_, j_, p_] := Merge[Join[{letterAt[termsAt[i, j, d, p]]},
      Table[Merge[{letterAt[termsAt[k, j, d, p - q[k]]], phiDen[k]}, Total], {k, Select[K, termsAt[#, j, d, p - q[#]] =!= None &]}],
      If[MemberQ[K, j], {Merge[{letterAt[termsAt[i, i, d, p - q[j]]], phiDen[j]}, Total], 2 phiDen[j],
        Association[Cases[FactorList[Numerator[Together[(prefOf[i]^2 prefOf[j]^2) /. us -> 1]]], {g_, m_} /; ! FreeQ[g, Alternatives @@ xs] :> (First[PFBNormalizePolynomials[{g}, xs]] -> 1)]]}, {}]], Max];
  terms = Flatten[Table[With[{t = termsAt[i, j, d, p]}, <|"Key" -> {d, j}, "Power" -> p, "Degree" -> degOf[t], "Own" -> letterAt[t],
      "Letters" -> KeySelect[lcmOf[d, j, p], KeyExistsQ[pdeg, #] &], "Spurious" -> spurOf[t, xs]|>], {d, nk}, {j, touched}, {p, lo, hi}]];
  d0 = Max[Append[Cases[Lookup[terms, "Degree"], _Integer], -1]] - 1;
  If[d0 < 0, Return["the terms the shift changes in the row of ut[" <> ToString[i] <> "] have degree 0 already"]];
  (* the samples: lines enough for the ansatz of the largest c_k, each with d0 + 1 + 3 points, at hi - lo + 2 values of eps *)
  nPhi = Max[Length[Cases[unk, {#, __}]] & /@ K];
  nL = Max[2, Ceiling[nPhi/(Max[dc, 0] + 1)] + 1];
  E = hi - lo + 2;
  (* d + 4 points per line; more when a term's own denominator has a spurious factor that the fit reads along each line,
     unless the samples would then exceed the cap *)
  S = With[{s0 = d0 + 1 + Lookup[opts, "ExtraPerLine", 3]}, With[{s1 = Max[s0, Max[spurPoints /@ Lookup[terms, "Spurious"]]]}, If[3 s1 E <= maxSmp, s1, s0]]];
  If[E > Length[$fitEps], Return["the range of powers of eps " <> ToString[{lo, hi}] <> " is too wide for the fit"]];
  While[(nL + 1) S E > maxSmp && nL > 2, nL--];
  If[(nL + 1) S E > maxSmp, Return["the fit would need " <> ToString[(nL + 1) S E] <> " samples (more than " <> ToString[maxSmp] <> ", \"MaxSamples\")"]];
  pr = <|"Row" -> i, "Key" -> PFBMaster[sys, i]["SectorKey"], "Lower" -> K, "EpsPowers" -> q, "Dimensions" -> deltas, "Unknowns" -> unk[[All, 1 ;; 2]], "Ansatz" -> unk,
    "Complexity" -> cx, "Degree" -> dc, "Letters" -> withL, "Keys" -> Union[Lookup[terms, "Key"]], "Terms" -> terms, "Range" -> {lo, hi}, "Start" -> d0, "Columns" -> touched,
    "JobRows" -> rowsJob, "Derivatives" -> ders, "Vars" -> xs, "UnitScale" -> us, "ProbeDegree" -> pdeg, "MaxDenominators" -> Lookup[opts, "MaxDenominators", 12],
    "FitLines" -> nL, "Taus" -> S, "Eps" -> Take[$fitEps, E], "Line" -> fitLines[xs, nL + 1, S, Hash[{i, d0, K}], fitAvoid[sys, dir, fam, xs, rowsJob]],
    "Prefs" -> Association[Table[l -> prefOf[l], {l, rowsJob}]], "MaxTargets" -> Lookup[opts, "MaxTargets", 4]|>;
  If[pr["Line"] === $Failed, Return["no lines of the fit avoid the known singularities (redrawn 200 times each)"]];
  Join[pr, <|"Points" -> samplePoints[pr], "Samples" -> Length[samplePoints[pr]]|>]];

(* the values at the samples of the terms of row i after the shift: A_ij + Sum_k c_k A_kj - A_ii c_j + d c_j + c_j dlog(pref_i/pref_j),
   affine in the unknowns *)
shiftValues[pr_, deg_] := Module[{rows = deg["Rows"], cols = deg["Columns"], rp, cp, i = pr["Row"], us = pr["UnitScale"], ders = pr["Derivatives"], nk, phi, dphi, dl, smp},
  rp = AssociationThread[rows -> Range[Length[rows]]]; cp = AssociationThread[cols -> Range[Length[cols]]];
  nk = Length[ders];
  phi = (#[[3]] /. us -> 1) & /@ pr["Ansatz"];
  dphi = Table[(D[u[[3]], ders[[d]]] /. us -> 1), {u, pr["Ansatz"]}, {d, nk}];
  dl = Association[Table[k -> Table[(dlogOf[pr["Prefs"][i], ders[[d]]] - dlogOf[pr["Prefs"][k], ders[[d]]]) /. us -> 1, {d, nk}], {k, pr["Lower"]}]];
  smp = deg["Samples"];
  Table[Module[{pt = smp[[n]]["Point"], R = smp[[n]]["Values"]["Base"], e, a, pv, dpv},
     e = eps /. pt;
     a[d_, r_, c_] := If[KeyExistsQ[rp, r] && KeyExistsQ[cp, c], R[[d, rp[r], cp[c]]], 0];
     pv = phi /. pt; dpv = dphi /. pt;
     Association[Flatten[Table[{d, j} -> {a[d, i, j], Table[With[{k = pr["Ansatz"][[m, 1]]},
          e^pr["EpsPowers"][k] (pv[[m]] a[d, k, j] + If[j === k, -a[d, i, i] pv[[m]] + dpv[[m, d]] + pv[[m]] (dl[k][[d]] /. pt), 0])], {m, Length[pr["Ansatz"]]}]},
       {d, nk}, {j, pr["Columns"]}]]]], {n, Length[smp]}]];

(* the targets d = "Start", "Start" - 1, ... while the fit solves (at most "MaxTargets"); sol[a] turns a solution vector
   into what the move records *)
(* the job's samples: those of the problem's points, each with exact numbers in every array (a point where the learned
   system cannot be evaluated, a singular point, gives $Failed). None when they are, else why not *)
exactArrayQ[a_] := ArrayQ[a, _, MatchQ[#, _Integer | _Rational] &];
samplesIssue[pr_, deg_, need_List : {"Base"}] := Module[{smp = Lookup[deg, "Samples", None], bad},
  Which[
    ! ListQ[smp] || Length[smp] =!= Length[pr["Points"]], "the job's samples are not those of the fit",
    (bad = Select[Range[Length[smp]], ! (AssociationQ[Lookup[smp[[#]], "Values", None]] && AllTrue[need, Function[k, exactArrayQ[Lookup[smp[[#]]["Values"], k, None]]]]) &]) =!= {},
      ToString[Length[bad]] <> " of " <> ToString[Length[smp]] <> " samples have no exact values (a singular point of the learned system, or an evaluation that failed), the first at " <>
        ToString[Lookup[smp[[First[bad]]], "Point", "?"], InputForm] <> ": the fit is not tried",
    True, None]];
fitTargets[pr_, vals_, sol_, t0_] := Module[{sols = {}, last = None, d = pr["Start"]},
  While[d >= 0 && Length[sols] < pr["MaxTargets"],
    last = fitAt[pr, vals, d];
    If[last["Status"] =!= "solved", Break[]];
    AppendTo[sols, Join[<|"Target" -> d|>, sol[last["Solution"]], <|"Free" -> last["Free"], "Equations" -> last["Equations"]|>]];
    d--];
  <|"Status" -> If[sols === {}, "no solution", "solved"], "Message" -> If[sols === {}, Lookup[Replace[last, None -> <||>], "Message", "no target"],
      "degree <= " <> ToString[Last[sols]["Target"]] <> " reached" <> If[AssociationQ[last] && last["Status"] =!= "solved", "; " <> ToString[d] <> " not: " <> last["Message"], ""]],
    "Solutions" -> sols, "Best" -> If[sols === {}, None, Last[sols]], "Unknowns" -> Length[pr["Unknowns"]], "Samples" -> Length[pr["Points"]],
    "Seconds" -> Round[AbsoluteTime[] - t0, 0.1]|>];

PFBShiftFit[pr_Association, deg_Association, opts_Association : <||>] := Module[{t0 = AbsoluteTime[], iss = samplesIssue[pr, deg]},
  If[StringQ[iss], Return[<|"Status" -> "failed", "Message" -> iss, "Solutions" -> {}, "Best" -> None, "Seconds" -> 0|>]];
  fitTargets[pr, shiftValues[pr, deg], Function[a, <|"Coefficients" -> Association[Table[k -> Together[eps^pr["EpsPowers"][k] Sum[a[[m]] pr["Ansatz"][[m, 3]],
       {m, Flatten[Position[pr["Ansatz"][[All, 1]], k]]}]], {k, pr["Lower"]}]]|>], t0]];

(* the shift with its images: ut[i] + Sum c_k ut[k], and in each image family the mapped coefficients on the images *)
shiftT[sys_, i_, cf_Association] := Catch[Module[{T = <|i -> ut[i] + Total[KeyValueMap[#2 ut[#1] &, cf]]|>, fam = PFBMaster[sys, i]["Family"]},
  Do[Module[{mi = PoleFreeBasis`Transform`Private`imageMatch[sys, i, im], mk},
     If[MissingQ[mi], Throw[$Failed, "shiftT"]];
     mk = Association[Table[k -> PoleFreeBasis`Transform`Private`imageMatch[sys, k, im], {k, Keys[cf]}]];
     If[MemberQ[Values[mk], _Missing], Throw[$Failed, "shiftT"]];
     T[mi[[1]]] = ut[mi[[1]]] + Total[KeyValueMap[Together[mi[[2]]/mk[#1][[2]] PFBImageExpr[sys, #2, im]] ut[mk[#1][[1]]] &, cf]]], {im, PFBImagesOf[sys, fam]}];
  T], "shiftT"];

(* a change in ut[k] terms applied exactly to the slice, as the gate does for a simplification *)
sliceAfter[sys_, sl_, T_] := Module[{red = <|"Masters" -> (ut /@ sl["Labels"]), "Labels" -> sl["Labels"], "Point" -> sl["Point"], "Focus" -> {}, "Dm" -> {}, "Pool" -> {}, "Rp" -> {},
     "dRp" -> {}, "Invariants" -> sl["Derivatives"], "Roots" -> {}|>, ch},
  ch = Quiet[PFBChangeVectors[sys, sl, red, PFBCalibrate[sl, red], T]];
  If[ch === $Failed, $Failed, Block[{Print}, Quiet[PFBApplyChange[sl, Join[ch, <|"Name" -> "simplify"|>]]]]]];

shiftMove[ctx_, tab_, ph_, opts_] := Module[{sys = ctx["System"], prep = Lookup[opts, "Record", None], id = Lookup[opts, "MoveId", 0], sl = PFBCurrentSlice[ctx["Dir"], ctx["State"]],
    mv, ranked, tried = <||>, pr = None, jd, deg, red, fit, c0, cands = {}, refused = {}, cap},
  cap = Lookup[ctx["Run"], "MaxEpsDegree", $PFBMaxEpsDegree];
  If[! AssociationQ[prep],
    mv = PFBMovableMasters[ctx, tab];
    (* the rows with the highest terms first *)
    ranked = SortBy[PFBWorstMasters[tab, <|"Labels" -> mv["Free"]|>], {-#["RowObjective"][[1]], -#["RowObjective"][[2]], -#["RowObjective"][[3]]} &];
    Do[With[{p = PFBShiftProblem[ctx, tab, w["Label"], opts]}, If[StringQ[p], tried[w["Label"]] = p, pr = p; Break[]]], {w, Take[ranked, UpTo[Lookup[opts, "ShiftRows", 3]]]}];
    If[pr === None, Return[<|"Status" -> "no gain", "Message" -> "move (iii): no row to shift" <> If[tried === <||>, "", " (" <> StringRiffle[KeyValueMap["ut[" <> ToString[#1] <> "]: " <> #2 &, tried], "; "] <> ")"],
       "Candidates" -> {}, "Info" -> <|"Tried" -> tried, "Protected" -> mv["Protected"]|>|>]];
    jd = PFBDegreesJob[ctx, pr["Key"], <|"Name" -> "simp" <> ToString[id] <> "_fit_" <> sectorJobName[pr["Key"]], "Rows" -> pr["JobRows"], "Samples" -> pr["Points"], "Measure" -> False,
       "Letters" -> False, "ReuseIds" -> With[{dd = FileNameJoin[{ctx["Dir"], "jobs", "deg_" <> sectorJobName[pr["Key"]], "ibps"}]}, If[DirectoryQ[dd], dd, Automatic]]|>];
    If[jd === $Failed, Return[<|"Status" -> "no gain", "Message" -> "move (iii): the job of the fit's samples could not be written", "Candidates" -> {}|>]];
    Return[<|"Status" -> "jobs", "Jobs" -> {jd}, "Keys" -> {pr["Key"]}, "Cost" -> PFBFitJobCost[tab, pr["Key"], pr["Samples"]], "Prep" -> <|"Problem" -> pr, "Job" -> jd, "Tried" -> tried|>,
      "Message" -> "move (iii): the row of ut[" <> ToString[pr["Row"]] <> "] shifted by " <> ToString[ut /@ pr["Lower"]] <> ", " <> ToString[Length[pr["Unknowns"]]] <> " unknowns, target degree " <>
        ToString[pr["Start"]] <> " and lower; " <> ToString[pr["Samples"]] <> " samples of the learned system on " <> ToString[pr["FitLines"] + 1] <> " lines: " <> FileNameTake[jd]|>]];
  pr = prep["Prep"]["Problem"]; jd = prep["Prep"]["Job"];
  deg = PFBReadDegreeJob[jd];
  red = Quiet@PFBReadRed[jd, 1];
  Which[
    ! AssociationQ[deg] || deg["Status"] =!= "sampled", Return[<|"Status" -> "no gain", "Message" -> "move (iii): the fit's job " <> FileNameTake[jd] <> " has no samples (" <>
      ToString[PFBSubtreeStatus[jd]["Status"]] <> ")", "Candidates" -> {}, "Info" -> <|"Problem" -> KeyDrop[pr, {"Points", "Line"}]|>|>],
    ! AssociationQ[red] || PFBCalibrate[sl, red]["Status"] =!= "exact", Return[<|"Status" -> "no gain", "Message" -> "move (iii): the fit's job does not calibrate exactly against the current slice",
      "Candidates" -> {}|>]];
  fit = PFBShiftFit[pr, deg, opts];
  c0 = Block[{PFBPrint}, PFBCensus[sys, sl, <|"MaxEpsDegree" -> cap|>]];
  (* the lowest target first, and the first one if it differs: each must keep the census exactly on the slice *)
  Do[Module[{T = shiftT[sys, pr["Row"], s["Coefficients"]], slNew, chk},
     If[T === $Failed, AppendTo[refused, <|"Target" -> s["Target"], "Reasons" -> {"an image family has no master that matches"}|>]; Continue[]];
     slNew = sliceAfter[sys, sl, T];
     chk = If[AssociationQ[slNew], PFBSimplifySliceCheck[sys, sl, c0, slNew, <|"MaxEpsDegree" -> cap|>], <|"Pass" -> False, "Reasons" -> {"not a change of basis"}|>];
     If[chk["Pass"],
       AppendTo[cands, <|"Name" -> "shift" <> ToString[Length[cands] + 1], "T" -> T, "Objective" -> Missing["NotPredicted"],
         "Info" -> <|"Row" -> pr["Row"], "Target" -> s["Target"], "Coefficients" -> s["Coefficients"], "Set" -> T, "Free" -> s["Free"]|>|>],
       AppendTo[refused, <|"Target" -> s["Target"], "Coefficients" -> s["Coefficients"], "Reasons" -> chk["Reasons"]|>]]],
    {s, DeleteDuplicatesBy[Select[{fit["Best"], First[fit["Solutions"], None]}, AssociationQ], #["Coefficients"] &]}];
  <|"Status" -> If[cands === {}, "no gain", "proposed"],
    "Message" -> "move (iii): ut[" <> ToString[pr["Row"]] <> "] by " <> ToString[ut /@ pr["Lower"]] <> ": " <> fit["Message"] <> " (" <> ToString[fit["Unknowns"]] <> " unknowns, " <>
      ToString[fit["Samples"]] <> " samples, fit " <> ToString[fit["Seconds"]] <> " s)" <>
      Which[cands =!= {}, "; " <> ToString[Length[cands]] <> " candidate(s)", refused =!= {}, "; refused on the slice: " <> StringRiffle[Flatten[Lookup[refused, "Reasons"]], "; "], True, ""],
    "Candidates" -> cands, "Info" -> <|"Row" -> pr["Row"], "Lower" -> pr["Lower"], "Fit" -> KeyDrop[fit, {}], "Refused" -> refused, "Job" -> jd,
      "Problem" -> KeyTake[pr, {"Unknowns", "Degree", "Letters", "Range", "Start", "Columns", "FitLines", "Taus", "Eps", "Samples"}]|>|>];

(* ::Section:: *)
(*Move (iv): lighter completions*)


(* the masters whose definitions an accepted completion (rung 6) wrote and that no later change replaced *)
PFBCompletedMasters[ctx_Association] := Module[{sys = ctx["System"], sl = PFBCurrentSlice[ctx["Dir"], ctx["State"]]},
  Select[Table[<|"Change" -> rec["Id"], "Key" -> rec["Key"],
      "Labels" -> Select[Lookup[rec, "Replace", {}], Function[l, MemberQ[sl["Labels"], l] && PFBBaseOf[sys, PFBMaster[sys, l]["Family"]] === PFBMaster[sys, l]["Family"] &&
        KeyExistsQ[Lookup[rec, "NewDefs", <||>], l] && Together[rec["NewDefs"][l] - PFBMaster[sys, l]["Def"]] === 0]]|>,
    {rec, Select[Lookup[ctx["State"], "Accepted", {}], Lookup[#, "Rung", None] === 6 && ListQ[Lookup[#, "Key", None]] &]}], #["Labels"] =!= {} &]];

(* the correction integrals of a completed master: the integrals of lower sectors of its family in its definition, each
   with its coefficient eps^n r (one power of eps, rule 1): {{w, coefficient, n}, ...} *)
correctionsOf[sys_, l_] := Module[{rec = PFBMaster[sys, l], rf, n, ints},
  rf = Collect[Expand[rec["RootFree"]], _j];
  If[! FreeQ[rf, Dinv], Return[{}]];
  n = PFBFamily[sys, rec["Family"]]["N"];
  ints = Select[Union[Cases[{rf}, _j, Infinity]], #[[1]] === rec["Family"] && subSectorQ[intSector[#, n], rec["Sector"]] &];
  Cases[Table[With[{cf = Together[Coefficient[rf, w]], pw = Lookup[Association[Rule @@@ PFBEpsPowers[rf]], w, {}]},
     If[Length[pw] == 1 && IntegerQ[pw[[1]]], {w, cf, pw[[1]]}, Nothing]], {w, ints}], {_, _, _}]];

PFBCompletionProblem[ctx_Association, tab_Association, comp_Association, opts_Association : <||>] := Module[{sys = ctx["System"], dir = ctx["Dir"], sl, us, xs, ders, nk, cap, key = comp["Key"],
    labs, corr = <||>, lets, usLetter, dc = Lookup[opts, "CompletionDegree", 2], withL = TrueQ[Lookup[opts, "ShiftLetters", True]], maxU = Lookup[opts, "MaxUnknowns", 60],
    maxSmp = Lookup[opts, "MaxSamples", 1000], ans, unk, cx, ws, lowerCols, ents, entIdx, degOf, d0, lo, hi, nL, S, E, pr, pool, phiDen, rowLetters, fam},
  sl = PFBCurrentSlice[dir, ctx["State"]];
  us = PFBUnitScale[sys]; xs = DeleteCases[sys["Invariants"], us];
  ders = sl["Derivatives"]; nk = Length[ders];
  cap = Lookup[opts, "MaxEpsDegree", Lookup[ctx["Run"], "MaxEpsDegree", $PFBMaxEpsDegree]];
  labs = comp["Labels"]; fam = key[[1]];
  Do[With[{c = correctionsOf[sys, l]}, If[c =!= {}, corr[l] = c]], {l, labs}];
  If[corr === <||>, Return["the definitions of change " <> ToString[comp["Change"]] <> " hold no correction integral of a lower sector"]];
  labs = Keys[corr];
  ents = Flatten[Values[Lookup[#, "Entries", {}] & /@ Select[Lookup[tab, "Sectors", <||>], #["Status"] === "measured" &]], 1];
  If[! AllTrue[labs, MemberQ[Lookup[Lookup[tab["Sectors"], Key[key], <||>], "Rows", {}], #] &], Return["the rows of the completed masters are not measured"]];
  entIdx = Association[Table[{e["Row"], e["Column"], e["Matrix"]} -> e["Terms"], {e, ents}]];
  degOf[t_] := If[t === None, None, Max[t["Num"], t["Den"]]];
  lets = probeLetters[sys, dir, fam];
  usLetter = PFBLetters[sys] === {} || MemberQ[Expand[PFBLetters[sys]], Expand[us] | Expand[-us]];
  (* the ansatz of each correction: monomials of its mass dimension, also over a letter of its old coefficient's
     denominator, and the old coefficient itself (so that the integral may drop out) *)
  ans[deg_, wl_] := Association[Table[l -> Table[Module[{w = cw[[1]], c = cw[[2]], p = cw[[3]], delta, ls, old},
       delta = Together[PFBMasterWeight[sys, PFBMaster[sys, l]["RootFree"], PFBMaster[sys, l]["Pref"]] - PFBMasterWeight[sys, w, PFBMaster[sys, l]["Pref"]]];
       old = Together[c/eps^p];
       ls = If[wl, KeyTake[lets, Cases[FactorList[Denominator[Together[old /. us -> 1]]], {g_, _} /; ! FreeQ[g, Alternatives @@ xs] :> First[PFBNormalizePolynomials[{g}, xs]]]], <||>];
       {w, p, If[NumericQ[delta], DeleteDuplicates[Prepend[ansatzOf[sys, delta, deg, ls, usLetter], old], Together[#1 - #2] === 0 &], {old}]}], {cw, corr[l]}], {l, labs}]];
  unk = ans[dc, withL];
  While[Total[Length[#[[3]]] & /@ Flatten[Values[unk], 1]] > maxU, Which[withL, withL = False, dc > 0, dc--, True, Break[]]; unk = ans[dc, withL]];
  If[Total[Length[#[[3]]] & /@ Flatten[Values[unk], 1]] > maxU, Return["more than " <> ToString[maxU] <> " unknowns"]];
  (* unknowns {l, w, n, phi}; the old coefficient is the simplest *)
  unk = Flatten[Table[Table[{l, a[[1]], a[[2]], a[[3, b]], b == 1}, {b, Length[a[[3]]]}], {l, labs}, {a, unk[l]}], 2];
  cx = Table[If[u[[5]], -1, Total[Exponent[Numerator[u[[4]] /. us -> 1], xs]] + 2 Boole[! FreeQ[Denominator[u[[4]] /. us -> 1], Alternatives @@ xs]]], {u, unk}];
  ws = Union[unk[[All, 2]]];
  (* the columns a correction can reach: the lower masters of the family *)
  lowerCols = Select[sl["Labels"], ! MemberQ[labs, #] && PFBMaster[sys, #]["Family"] === fam && subSectorQ[PFBMaster[sys, #]["Sector"], key[[2]]] &];
  lo = Min[Append[Cases[Flatten[Table[Lookup[Lookup[entIdx, Key[{r, c, d}], {}], "Power"], {r, labs}, {c, sl["Labels"]}, {d, nk}]], _Integer], 0]];
  hi = If[cap === Infinity, Max[Append[Cases[Flatten[Table[Lookup[Lookup[entIdx, Key[{r, c, d}], {}], "Power"], {r, labs}, {c, sl["Labels"]}, {d, nk}]], _Integer], 0]] + 1, cap];
  d0 = Max[Append[Cases[Flatten[Table[degOf /@ Lookup[entIdx, Key[{r, c, d}], {}], {r, labs}, {c, lowerCols}, {d, nk}]], _Integer], -1]] - 1;
  If[d0 < 0, Return["the rows of the completed masters have terms of degree 0 towards lower masters"]];
  (* the letters a new term's denominator may hold: its own, those of its row, those of the ansatz *)
  rowLetters[l_] := Merge[Flatten[Table[Replace[#["DenLetters"], Except[_Association] -> <||>] & /@ Lookup[entIdx, Key[{l, c, d}], {}], {c, sl["Labels"]}, {d, nk}]], Max];
  phiDen = Merge[Table[Association[Cases[FactorList[Denominator[Together[u[[4]] /. us -> 1]]], {g_, m_} /; ! FreeQ[g, Alternatives @@ xs] :> (First[PFBNormalizePolynomials[{g}, xs]] -> m)]], {u, unk}], Max];
  nL = Max[2, Ceiling[Max[Counts[unk[[All, {1, 2}]]]]/(Max[dc, 0] + 1)] + 1];
  (* two values of eps beyond the range: a correction's reduction is rational in eps, only the sum must be a polynomial *)
  E = hi - lo + 3;
  (* d + 4 points per line, more for a term with a spurious factor in its own denominator (as for a shift) *)
  S = With[{s0 = d0 + 1 + Lookup[opts, "ExtraPerLine", 3], sp = Flatten[Table[spurOf[t, xs], {l, labs}, {c, lowerCols}, {d, nk}, {t, Lookup[entIdx, Key[{l, c, d}], {}]}]]},
    With[{s1 = Max[s0, Max[Append[spurPoints /@ sp, 0]]]}, If[3 s1 E <= maxSmp, s1, s0]]];
  If[E > Length[$fitEps], Return["the range of powers of eps " <> ToString[{lo, hi}] <> " is too wide for the fit"]];
  While[(nL + 1) S E > maxSmp && nL > 2, nL--];
  If[(nL + 1) S E > maxSmp, Return["the fit would need " <> ToString[(nL + 1) S E] <> " samples (more than " <> ToString[maxSmp] <> ", \"MaxSamples\")"]];
  (* the pool of the job: the corrections and the other integrals of the definitions, with their images, for the gate *)
  pool = Union[Flatten[Table[Cases[{PFBMaster[sys, l]["RootFree"]}, _j, Infinity], {l, labs}]]];
  pool = Union[pool, Flatten[Table[PFBImageExpr[sys, w, im], {w, pool}, {im, PFBImagesOf[sys, fam]}]]];
  pr = <|"Change" -> comp["Change"], "Key" -> key, "Rows" -> labs, "Corrections" -> corr, "Exprs" -> ws, "Unknowns" -> unk[[All, 1 ;; 3]], "Ansatz" -> unk, "Complexity" -> cx,
    "Degree" -> dc, "Letters" -> withL, "Range" -> {lo, hi}, "Start" -> d0, "LowerColumns" -> lowerCols, "JobRows" -> labs, "Pool" -> pool, "Derivatives" -> ders, "Vars" -> xs,
    "UnitScale" -> us, "MaxDenominators" -> Lookup[opts, "MaxDenominators", 12], "MaxTargets" -> Lookup[opts, "MaxTargets", 4],
    "FitLines" -> nL, "Taus" -> S, "Eps" -> Take[$fitEps, E], "Line" -> fitLines[xs, nL + 1, S, Hash[{labs, d0, ws}], fitAvoid[sys, dir, fam, xs, labs]],
    "Prefs" -> Association[Table[l -> PFBMaster[sys, l]["Pref"], {l, labs}]],
    (* known when the job is done: the terms; their letters from the degree table now *)
    "EntryLetters" -> Association[Flatten[Table[{l, d, c, t["Power"]} -> Replace[t["DenLetters"], Except[_Association] -> <||>], {l, labs}, {c, lowerCols}, {d, nk},
       {t, Lookup[entIdx, Key[{l, c, d}], {}]}], 3]],
    "EntryDegrees" -> Association[Flatten[Table[{l, d, c, t["Power"]} -> degOf[t], {l, labs}, {c, lowerCols}, {d, nk}, {t, Lookup[entIdx, Key[{l, c, d}], {}]}], 3]],
    "EntrySpurious" -> Association[Flatten[Table[{l, d, c, t["Power"]} -> spurOf[t, xs], {l, labs}, {c, lowerCols}, {d, nk}, {t, Lookup[entIdx, Key[{l, c, d}], {}]}], 3]],
    "RowLetters" -> Association[Table[l -> rowLetters[l], {l, labs}]], "AnsatzLetters" -> phiDen,
    "ProbeDegree" -> Association[Table[pp -> totDeg[pp, xs], {pp, Union[Keys[lets], Keys[phiDen], Flatten[Keys /@ Table[rowLetters[l], {l, labs}]]]}]]|>;
  If[pr["Line"] === $Failed, Return["no lines of the fit avoid the known singularities (redrawn 200 times each)"]];
  Join[pr, <|"Points" -> samplePoints[pr], "Samples" -> Length[samplePoints[pr]]|>]];

(* the values at the samples of the rows of the completed masters after the new corrections Delta C_w (unknowns):
   A_lj + Sum_w [d(eps^n Delta C_w) r_w + eps^n Delta C_w (dr_w + dlog(pref_l) r_w)]_j - Sum_l' A_ll' (Sum_w eps^n Delta C'_w r_w)_j,
   r_w and dr_w the sampled vectors of the correction integral and of its derivative *)
compValues[pr_, deg_, keys_] := Module[{rows = deg["Rows"], cols = deg["Columns"], rp, cp, us = pr["UnitScale"], ders = pr["Derivatives"], nk, phi, dphi, dl, wp, smp},
  rp = AssociationThread[rows -> Range[Length[rows]]]; cp = AssociationThread[cols -> Range[Length[cols]]];
  wp = AssociationThread[pr["Exprs"] -> Range[Length[pr["Exprs"]]]];
  nk = Length[ders];
  phi = (#[[4]] /. us -> 1) & /@ pr["Ansatz"];
  dphi = Table[(D[u[[4]], ders[[d]]] /. us -> 1), {u, pr["Ansatz"]}, {d, nk}];
  dl = Association[Table[l -> Table[dlogOf[pr["Prefs"][l], ders[[d]]] /. us -> 1, {d, nk}], {l, pr["Rows"]}]];
  smp = deg["Samples"];
  Table[Module[{pt = smp[[n]]["Point"], R = smp[[n]]["Values"]["Base"], X = smp[[n]]["Values"]["Exprs"], DX = smp[[n]]["Values"]["DExprs"], e, a, pv, dpv},
     e = eps /. pt;
     a[d_, r_, c_] := If[KeyExistsQ[rp, r] && KeyExistsQ[cp, c], R[[d, rp[r], cp[c]]], 0];
     pv = phi /. pt; dpv = dphi /. pt;
     Association[Table[With[{l = ky[[1]], d = ky[[2]], j = ky[[3]]}, ky -> {a[d, l, j], Table[With[{u = pr["Ansatz"][[m]]}, With[{xa = X[[wp[u[[2]]], cp[j]]], dxa = DX[[d, wp[u[[2]]], cp[j]]]},
          e^u[[3]] (If[u[[1]] === l, dpv[[m, d]] xa + pv[[m]] (dxa + (dl[l][[d]] /. pt) xa), 0] - a[d, l, u[[1]]] pv[[m]] xa)]], {m, Length[pr["Ansatz"]]}]}], {ky, keys}]]], {n, Length[smp]}]];

PFBCompletionFit[pr_Association, deg_Association, opts_Association : <||>] := Module[{t0 = AbsoluteTime[], cols, cp, touched, nk = Length[pr["Derivatives"]], lo = pr["Range"][[1]],
    hi = pr["Range"][[2]], terms, keys, pr2},
  With[{iss = samplesIssue[pr, deg, {"Base", "Exprs", "DExprs"}]}, If[StringQ[iss], Return[<|"Status" -> "failed", "Message" -> iss, "Solutions" -> {}, "Best" -> None, "Seconds" -> 0|>]]];
  cols = deg["Columns"]; cp = AssociationThread[cols -> Range[Length[cols]]];
  (* the columns the corrections reach, read from the samples *)
  touched = Select[pr["LowerColumns"], Function[j, KeyExistsQ[cp, j] && AnyTrue[Take[deg["Samples"], UpTo[3]],
      Function[sm, AnyTrue[sm["Values"]["Exprs"][[All, cp[j]]], # =!= 0 &] || AnyTrue[Flatten[sm["Values"]["DExprs"][[All, All, cp[j]]]], # =!= 0 &]]]]];
  terms = Flatten[Table[With[{lt = Lookup[pr["EntryLetters"], Key[{l, d, j, p}], <||>]}, <|"Key" -> {l, d, j}, "Power" -> p, "Degree" -> Lookup[pr["EntryDegrees"], Key[{l, d, j, p}], None],
       "Own" -> lt, "Letters" -> KeySelect[Merge[{lt, pr["RowLetters"][l], pr["AnsatzLetters"], 2 pr["AnsatzLetters"]}, Max], KeyExistsQ[pr["ProbeDegree"], #] &],
       "Spurious" -> Lookup[Lookup[pr, "EntrySpurious", <||>], Key[{l, d, j, p}], None]|>],
     {l, pr["Rows"]}, {d, nk}, {j, touched}, {p, lo, hi}]];
  If[terms === {}, Return[<|"Status" -> "no solution", "Message" -> "the corrections reach no column", "Solutions" -> {}, "Best" -> None, "Seconds" -> 0|>]];
  keys = Union[Lookup[terms, "Key"]];
  pr2 = Join[pr, <|"Terms" -> terms, "Keys" -> keys, "Columns" -> touched|>];
  Join[fitTargets[pr2, compValues[pr2, deg, keys], Function[a, <|"Corrections" -> Association[Table[l -> Association[Table[w -> Together[Sum[a[[m]] pr["Ansatz"][[m, 4]],
         {m, Select[Range[Length[pr["Ansatz"]]], pr["Ansatz"][[#, 1]] === l && pr["Ansatz"][[#, 2]] === w &]}]], {w, Union[Cases[pr["Ansatz"], {l, w_, __} :> w]]}]], {l, pr["Rows"]}]]|>], t0],
    <|"Columns" -> touched|>]];

(* the new definitions: the old ones plus eps^n Delta C_w w, in integrals, with their images *)
completionDefs[sys_, pr_, corr_Association] := PFBImageDefs[sys, Association[KeyValueMap[Function[{l, dc}, Module[{pw = Association[(#[[1]] -> #[[3]]) & /@ pr["Corrections"][l]]},
    l -> Collect[PFBMaster[sys, l]["RootFree"] + Total[KeyValueMap[Function[{w, c}, eps^pw[w] c w], dc]], _j, Together]]], corr]]];

compMove[ctx_, tab_, ph_, opts_] := Module[{sys = ctx["System"], prep = Lookup[opts, "Record", None], id = Lookup[opts, "MoveId", 0], sl = PFBCurrentSlice[ctx["Dir"], ctx["State"]],
    comps, mv, worstOf, tried = <||>, pr = None, jd, deg, red, cal, fit, c0, cands = {}, refused = {}, cap},
  cap = Lookup[ctx["Run"], "MaxEpsDegree", $PFBMaxEpsDegree];
  If[! AssociationQ[prep],
    comps = PFBCompletedMasters[ctx];
    If[comps === {}, Return[<|"Status" -> "no gain", "Message" -> "move (iv): no master comes from a completion (rung 6)", "Candidates" -> {}|>]];
    mv = PFBMovableMasters[ctx, tab];
    comps = Select[comps, SubsetQ[mv["Free"], #["Labels"]] &];
    If[comps === {}, Return[<|"Status" -> "no gain", "Message" -> "move (iv): the completed masters may not change (" <> StringRiffle[Values[mv["Protected"]], "; "] <> ")", "Candidates" -> {}|>]];
    (* the completion whose rows carry the highest terms first *)
    worstOf[c_] := Replace[PFBWorstMasters[tab, <|"Labels" -> c["Labels"]|>], {{} -> {-Infinity, 0, 0}, w_ :> First[SortBy[Lookup[w, "RowObjective"], {-#[[1]], -#[[2]], -#[[3]]} &]]}];
    comps = SortBy[comps, {-worstOf[#][[1]], -worstOf[#][[2]], -worstOf[#][[3]]} &];
    Do[With[{p = PFBCompletionProblem[ctx, tab, c, opts]}, If[StringQ[p], tried[c["Change"]] = p, pr = p; Break[]]], {c, Take[comps, UpTo[3]]}];
    If[pr === None, Return[<|"Status" -> "no gain", "Message" -> "move (iv): no completion to solve again (" <> StringRiffle[KeyValueMap["change " <> ToString[#1] <> ": " <> #2 &, tried], "; "] <> ")",
       "Candidates" -> {}, "Info" -> <|"Tried" -> tried|>|>]];
    jd = PFBDegreesJob[ctx, pr["Key"], <|"Name" -> "simp" <> ToString[id] <> "_comp_" <> sectorJobName[pr["Key"]], "Rows" -> pr["JobRows"], "Samples" -> pr["Points"],
       "Measure" -> False, "Letters" -> False, "SampleExprs" -> pr["Exprs"], "Pool" -> pr["Pool"], "PoolDerivatives" -> True,
       "ReuseIds" -> With[{dd = FileNameJoin[{ctx["Dir"], "jobs", "deg_" <> sectorJobName[pr["Key"]], "ibps"}]}, If[DirectoryQ[dd], dd, Automatic]]|>];
    If[jd === $Failed, Return[<|"Status" -> "no gain", "Message" -> "move (iv): the job of the fit's samples could not be written", "Candidates" -> {}|>]];
    Return[<|"Status" -> "jobs", "Jobs" -> {jd}, "Keys" -> {pr["Key"]}, "Cost" -> PFBFitJobCost[tab, pr["Key"], pr["Samples"]], "Prep" -> <|"Problem" -> pr, "Job" -> jd, "Tried" -> tried|>,
      "Message" -> "move (iv): the completion of change " <> ToString[pr["Change"]] <> " (" <> ToString[ut /@ pr["Rows"]] <> ", " <> ToString[Length[pr["Exprs"]]] <> " correction integral(s)) solved again: " <>
        ToString[Length[pr["Unknowns"]]] <> " unknowns, target degree " <> ToString[pr["Start"]] <> " and lower; " <> ToString[pr["Samples"]] <> " samples: " <> FileNameTake[jd]|>]];
  pr = prep["Prep"]["Problem"]; jd = prep["Prep"]["Job"];
  deg = PFBReadDegreeJob[jd];
  red = Quiet@PFBReadRed[jd, 1];
  cal = If[AssociationQ[red], PFBCalibrate[sl, red], <|"Status" -> "no reduction"|>];
  Which[
    ! AssociationQ[deg] || deg["Status"] =!= "sampled", Return[<|"Status" -> "no gain", "Message" -> "move (iv): the fit's job " <> FileNameTake[jd] <> " has no samples (" <>
      ToString[PFBSubtreeStatus[jd]["Status"]] <> ")", "Candidates" -> {}|>],
    cal["Status"] =!= "exact", Return[<|"Status" -> "no gain", "Message" -> "move (iv): the fit's job does not calibrate exactly against the current slice", "Candidates" -> {}|>]];
  fit = PFBCompletionFit[pr, deg, opts];
  c0 = Block[{PFBPrint}, PFBCensus[sys, sl, <|"MaxEpsDegree" -> cap|>]];
  Do[Module[{defs = completionDefs[sys, pr, s["Corrections"]], ch, slNew, chk},
     ch = Quiet[PFBChangeVectors[sys, sl, red, cal, defs]];
     slNew = If[ch === $Failed, $Failed, Block[{Print}, Quiet[PFBApplyChange[sl, Join[ch, <|"Name" -> "completion"|>]]]]];
     chk = If[AssociationQ[slNew], PFBSimplifySliceCheck[sys, sl, c0, slNew, <|"MaxEpsDegree" -> cap|>],
       <|"Pass" -> False, "Reasons" -> {If[ch === $Failed, "integrals outside the job's pool", "not a change of basis"]}|>];
     If[chk["Pass"],
       AppendTo[cands, <|"Name" -> "completion" <> ToString[Length[cands] + 1], "T" -> defs, "Defs" -> defs, "RedJob" -> jd, "Objective" -> Missing["NotPredicted"],
         "Info" -> <|"Rows" -> pr["Rows"], "Target" -> s["Target"], "Corrections" -> s["Corrections"], "Set" -> KeyTake[defs, pr["Rows"]], "Free" -> s["Free"]|>|>],
       AppendTo[refused, <|"Target" -> s["Target"], "Corrections" -> s["Corrections"], "Reasons" -> chk["Reasons"]|>]]],
    {s, DeleteDuplicatesBy[Select[{fit["Best"], First[fit["Solutions"], None]}, AssociationQ], #["Corrections"] &]}];
  <|"Status" -> If[cands === {}, "no gain", "proposed"],
    "Message" -> "move (iv): the completion of change " <> ToString[pr["Change"]] <> " (" <> ToString[ut /@ pr["Rows"]] <> "): " <> fit["Message"] <> " (" <> ToString[Lookup[fit, "Unknowns", 0]] <>
      " unknowns, " <> ToString[Lookup[fit, "Samples", 0]] <> " samples, fit " <> ToString[fit["Seconds"]] <> " s)" <>
      Which[cands =!= {}, "; " <> ToString[Length[cands]] <> " candidate(s)", refused =!= {}, "; refused on the slice: " <> StringRiffle[Flatten[Lookup[refused, "Reasons"]], "; "], True, ""],
    "Candidates" -> cands, "Info" -> <|"Change" -> pr["Change"], "Rows" -> pr["Rows"], "Fit" -> fit, "Refused" -> refused, "Job" -> jd,
      "Problem" -> KeyTake[pr, {"Exprs", "Unknowns", "Degree", "Letters", "Range", "Start", "FitLines", "Taus", "Eps", "Samples"}]|>|>];


$PFBSimplifyMoves = {<|"Name" -> "rescale", "Title" -> "global letter rescaling", "Propose" -> rescaleMove|>,
   <|"Name" -> "swap", "Title" -> "swaps of the worst master", "Propose" -> swapMove|>,
   <|"Name" -> "shift", "Title" -> "shifts by lower masters", "Propose" -> shiftMove|>,
   <|"Name" -> "completion", "Title" -> "lighter completions", "Propose" -> compMove|>};


(* ::Section:: *)
(*The phase*)


finishedQ[jd_] := ! MemberQ[{"running", "not run", "nonut-hosts"}, PFBSubtreeStatus[jd]["Status"]];
(* a sector whose census job ended without a measurement that running it again may give: killed, failed, refused *)
retryQ[tab_, k_] := With[{r = Lookup[Lookup[tab, "Sectors", <||>], Key[k], None]}, AssociationQ[r] && r["Status"] =!= "measured" &&
   StringStartsQ[Lookup[r, "Reason", ""], "the job is " ~~ ("killed" | "failed" | "refused")]];
nonFinal[r_] := r["Status"] =!= "measured" && StringContainsQ[Lookup[r, "Reason", ""], {"is running", "is not run", "nonut-hosts", "calibrate"}];
(* a sector of the table is current for the phase when it was measured by its own job, timed, with letter content
   (a degree job of the sector), or when its job ended without a measurement for good (memory, failure) *)
needsCensus[tab_, keys_] := If[! AssociationQ[tab] || Lookup[Lookup[tab, "Provenance", <||>], "Source", "measured"] =!= "measured", keys,
  Select[keys, Function[k, With[{r = Lookup[tab["Sectors"], Key[k], None]}, Which[
     r === None, True,
     r["Status"] === "measured", ! (Lookup[r, "JobSectors", 0] === 1 && NumericQ[Lookup[r, "JobWallSeconds", None]]),
     True, nonFinal[r]]]]]];

cmdFile[dir_, name_] := FileNameJoin[{dir, "jobs", name}];
jobsSeconds[jobs_List] := Total[Replace[Lookup[PFBSubtreeStatus[#], "Seconds", 0], Except[_?NumericQ] -> 0] & /@ jobs];
(* a move's own jobs, from the census's job times of their sectors: the job and two measurements each *)
prepCost[prop_, keys_List] := Total[With[{q = Lookup[prop["PerSector"], Key[#], <|"Job" -> 0, "Measure" -> 0|>]},
    Replace[q["Job"], Except[_?NumericQ] -> 0] + 2 Replace[q["Measure"], Except[_?NumericQ] -> 0]] & /@ keys];
jobsOutcome[ctx_, ph_, jobs_, what_, msg_List] := Module[{cmd = PFBDegreesCommand[jobs], f = cmdFile[ctx["Dir"], "simplify_command.sh"]},
  Export[f, cmd <> "\n", "Text"];
  Throw[<|"Outcome" -> "jobs", "Message" -> StringRiffle[Append[msg, what <> ": " <> ToString[Length[jobs]] <> " degree job(s): " <> StringRiffle[FileNameTake /@ jobs, ", "] <>
       ". Run them in the background, one after the other:\n  sh " <> f <> "\nwait for each with:\n  " <> FileNameJoin[{$PFBRoot, "bin", "wait_job"}] <>
       " <job folder> --timeout <seconds>\nthen run simplify.wls again."], "\n"], "Command" -> cmd, "CommandFile" -> f, "Jobs" -> jobs, "Phase" -> ph, "Context" -> ctx|>, $simplifyTag]];

(* the table of the current slice after a candidate: the measured sectors it changes from its variant jobs. A sector
   keeps the times of its census job ("JobWallSeconds", "JobSeconds": the budget and the fits' costs are estimated from
   them); the variant job's own times are kept apart ("VariantJob", "VariantJobWallSeconds", "VariantSeconds"), since a
   variant job measures several candidates and would inflate every later estimate *)
$censusTimeKeys = {"JobWallSeconds", "JobSeconds", "JobSectors", "JobCPUSeconds", "Threads"};
keepCensusTimes[old_Association, new_Association] := Join[new, KeyTake[old, $censusTimeKeys],
   <|"VariantJob" -> Lookup[new, "Job", Missing[]], "VariantJobWallSeconds" -> Lookup[new, "JobWallSeconds", Missing[]], "VariantSeconds" -> Lookup[new, "JobSeconds", Missing[]]|>];
candidateTable[ctx_, tab_, cand_, jobs_] := Module[{secs = tab["Sectors"], reasons = {}},
  Do[With[{r = PFBJobDegreeRecords[ctx, jd, cand["Name"]]}, If[StringQ[r["Reason"]], AppendTo[reasons, FileNameTake[jd] <> ": " <> r["Reason"]],
      secs = Join[secs, Association[KeyValueMap[#1 -> keepCensusTimes[Replace[Lookup[tab["Sectors"], Key[#1], <||>], Except[_Association] -> <||>], #2] &, r["Sectors"]]]]]], {jd, jobs}];
  If[reasons =!= {}, Return[<|"Reason" -> StringRiffle[reasons, "; "]|>]];
  With[{t = Join[tab, <|"Sectors" -> secs|>]}, <|"Reason" -> None, "Table" -> Join[t, <|"Summary" -> PFBDegreeSummary[t]|>]|>]];

(* away from the slice: each degree job reads the eps structure of its rows at a random point of its own (spec
   "Point"). A candidate whose measured rows show there an entry with finite poles, above the cap or with a negative
   power of eps, that the census table did not show, is refused: the slice point alone said nothing about it *)
epsBad[e_] := Switch[Lookup[e, "Eps", None], {"Whole", "finite poles"}, "finite poles", {"Whole", "above the cap"}, "above the cap", {"Laurent", _?Negative, _}, "a negative power of eps", _, None];
(* the eps range of each measured row ({matrix, row} -> {lowest, highest}, "pole" with a whole entry, "zero" without
   entries), to compare the eps structure the way the slice check does (PFBEpsFloorViolations) *)
rowRanges[t_, k_] := Module[{sec = Lookup[t["Sectors"], Key[k], <||>], ents, mats},
  ents = Lookup[sec, "Entries", {}]; mats = Union[ents[[All, "Matrix"]]];
  Association[Flatten[Table[{m, r} -> With[{es = Select[ents, #["Matrix"] === m && #["Row"] === r &]},
      Which[es === {}, "zero", AnyTrue[es, #["Eps"][[1]] =!= "Laurent" &], "pole", True, {Min[es[[All, "Eps", 2]]], Max[es[[All, "Eps", 3]]]}]],
    {m, mats}, {r, Lookup[sec, "Rows", Union[ents[[All, "Row"]]]]}]]]];
offSliceCheck[tab_, new_, keys_List] := Module[{old, bad = {}},
  Do[old = Association[Table[{e["Matrix"], e["Row"], e["Column"]} -> epsBad[e], {e, Lookup[Lookup[tab["Sectors"], Key[k], <||>], "Entries", {}]}]];
    Do[With[{b = epsBad[e]}, If[StringQ[b] && Lookup[old, Key[{e["Matrix"], e["Row"], e["Column"]}], None] =!= b,
        AppendTo[bad, "ut[" <> ToString[e["Row"]] <> "], column ut[" <> ToString[e["Column"]] <> "] (d/d" <> ToString[Lookup[e, "Derivative", e["Matrix"]]] <> "): " <> b]]],
      {e, Lookup[Lookup[new["Sectors"], Key[k], <||>], "Entries", {}]}];
    With[{rb = rowRanges[tab, k], ra = rowRanges[new, k]}, KeyValueMap[Function[{mr, a}, With[{b = Lookup[rb, Key[mr], "zero"]},
        If[PFBEpsFloorWorseQ[b, a], AppendTo[bad, "ut[" <> ToString[mr[[2]]] <> "] (matrix " <> ToString[mr[[1]]] <> "): eps range " <>
          ToString[b] <> " -> " <> ToString[a]]]]], ra]], {k, keys}];
  <|"Pass" -> bad === {}, "Bad" -> bad, "Detail" -> If[bad === {},
     "the measured rows of " <> ToString[Length[keys]] <> " sector(s) show at their degree jobs' points no finite pole, nothing above the cap, no negative power of eps they did not have, and no row whose eps structure gets worse",
     ToString[Length[bad]] <> " entries at the degree jobs' points: " <> StringRiffle[Take[bad, UpTo[6]], "; "]]|>];

(* which sectors a change T = <|label -> combination of ut|> touches, and the part of T each sector's job sees: the keys
   of its rows and of their non-zero columns, closed over the blocks of T. The rows of T^-1 couple the keys of a block:
   two keys whose new masters refer to each other (ut[b] in T[a]) and, for a T inverted in the job's graph (new masters
   in integrals: a swap, a completion), two keys of the same family and sector, whose new masters are reduced on each
   other's old ones. A row above a pair swap {m, m2} that couples to m alone needs the row m of T^-1,
   [H_SS^-1 (e_S - H_SR)]_m, which involves the whole pair: with m alone the job would invert another change *)
touchedKeys[sys_, sl_, T_] := Union[PFBMaster[sys, #]["SectorKey"] & /@ Select[sl["Labels"], Function[r, MemberQ[Keys[T], r] || IntersectingQ[nonZeroCols[sl, r], Keys[T]]]]];
tLinkedQ[sys_, T_, inG_, a_, b_] := a =!= b && (MemberQ[Cases[{T[a]}, ut[k_Integer] :> k, {0, Infinity}], b] || MemberQ[Cases[{T[b]}, ut[k_Integer] :> k, {0, Infinity}], a] ||
   inG && PFBMaster[sys, a]["Family"] === PFBMaster[sys, b]["Family"] && PFBMaster[sys, a]["SectorKey"] === PFBMaster[sys, b]["SectorKey"]);
restrictT[sys_, sl_, T_, key_] := Module[{rows = Intersection[PFBSectorMasters[sys, key], sl["Labels"]], seen, inG = ! FreeQ[Values[T], _j | _Dinv], keep},
  seen = Intersection[Keys[T], Union[rows, Union @@ (nonZeroCols[sl, #] & /@ rows)]];
  If[seen === {}, Return[<||>]];
  keep = FixedPoint[Function[ks, Union[ks, Select[Keys[T], Function[b, AnyTrue[ks, tLinkedQ[sys, T, inG, #, b] &]]]]], seen];
  KeyTake[T, Select[Keys[T], MemberQ[keep, #] &]]];

storeTable[ctx_, tab_, prov_] := Module[{st = ctx["State"], p, sl, t},
  p = First[FirstPosition[Lookup[st["Slices"], "File"], st["Current"]]];
  sl = PFBCurrentSlice[ctx["Dir"], st];
  t = Join[tab, <|"Slice" -> st["Current"], "Point" -> sl["Point"], "Provenance" -> prov, "Date" -> PFBTimeStamp[]|>];
  t["Summary"] = PFBDegreeSummary[t];
  Join[ctx, <|"State" -> PFBStoreDegrees[ctx["Dir"], st, p, t]|>]];

summaryOf2[tab_] := KeyTake[PFBDegreeSummary[tab], sumKeys];

PFBSimplifyStep[ctx0_Association, opts_Association : <||>] := Catch[Module[{ctx = ctx0, sys, dir, st, run, sl, c, pre, ph, tab, keys, needs, budget, prop, target, msg = {},
    out, moveIndex, moves},
  sys = ctx["System"]; dir = ctx["Dir"]; st = ctx["State"]; run = ctx["Run"];
  (* every way out of the step: the outcome, the phase record and the context of the run *)
  out[o_String, m_String, extra_Association : <||>] := Throw[Join[<|"Outcome" -> o, "Message" -> StringRiffle[Append[msg, m], "\n"], "Phase" -> ph, "Context" -> ctx|>, extra], $simplifyTag];
  moveIndex[id_] := First[FirstPosition[Lookup[ph["Moves"], "Id"], id]];
  ph = Replace[PFBReadPhase[dir], None :> <|"Created" -> PFBTimeStamp[], "Moves" -> {}, "Spent" -> 0, "Status" -> "open"|>];
  sl = PFBCurrentSlice[dir, st];
  If[sl === $Failed, out["refused", "the run has no current slice"]];
  (* a move of the phase that waits for the user's approval *)
  With[{pm = SelectFirst[Reverse[ph["Moves"]], #["Status"] === "pending" &, None]},
    If[pm =!= None, Module[{id = pm["Change"], i = moveIndex[pm["Id"]]},
      Which[
        MemberQ[Lookup[st["Accepted"], "Id"], id],
          ph[["Moves", i, "Status"]] = "accepted"; savePhase[dir, ph];
          If[StringQ[Lookup[pm, "TableFile", None]] && FileExistsQ[pm["TableFile"]] && MissingQ[PFBReadDegrees[dir, st]],
            ctx = storeTable[ctx, Get[pm["TableFile"]], <|"Source" -> "measured", "Simplify" -> <|"Move" -> pm["Id"], "Candidate" -> pm["Chosen"]|>|>]; st = ctx["State"]];
          AppendTo[msg, "move " <> ToString[pm["Id"]] <> " approved: change " <> ToString[id] <> " accepted"],
        MemberQ[Lookup[st["Pending"], "Id"], id],
          out["approval", "move " <> ToString[pm["Id"]] <> " (change " <> ToString[id] <> ") waits for the user's approval: show it, then bin/ws bin/approve.wls " <>
            run["File"] <> " " <> ToString[id] <> " after a yes, or bin/ws bin/approve.wls " <> run["File"] <> " --decline " <> ToString[id] <> " after a no, and run simplify.wls again"],
        AnyTrue[Lookup[st, "Rejected", {}], #["Id"] == id && KeyExistsQ[#, "Declined"] &],
          ph[["Moves", i, "Status"]] = "declined"; savePhase[dir, ph];
          AppendTo[msg, "move " <> ToString[pm["Id"]] <> ": change " <> ToString[id] <> " was declined by the user; the phase goes on with the next move"],
        True, ph[["Moves", i, "Status"]] = "not approved"; savePhase[dir, ph]]]]];
  sl = PFBCurrentSlice[dir, st];
  c = currentCensus[dir, st];
  pre = PFBSimplifyPrecondition[sys, st, c, <|"Tried" -> PFBHiddenWeightTried[dir, sys]|>];
  If[! pre["Pass"], out["refused", "the simplification phase cannot start:\n  " <> StringRiffle[pre["Reasons"], "\n  "], <|"Precondition" -> pre|>]];
  Scan[AppendTo[msg, "note: the census's hint that the clean sector " <> PFBSectorString[#["Sector"]] <> " may carry " <> ToString[#["Factor"], InputForm] <>
      " (the poles of " <> StringRiffle[PFBSectorString /@ #["Sectors"], ", "] <> ", flagged) has no recorded lower-sector scan; it does not block the phase. " <>
      "Its scan (bin/pair_scan.wls --hidden-weight) may still clear those poles: say so to the user"] &, pre["Hints"]];
  (* the objective sees the derivative matrices of the slice only: each invariant but the unit scale must have one (the
     unit scale's follows from the others by homogeneity) *)
  With[{miss = Complement[DeleteCases[sys["Invariants"], PFBUnitScale[sys]], sl["Derivatives"]]}, If[miss =!= {},
    out["refused", "the simplification phase cannot start: the slice has the derivatives in " <> ToString[sl["Derivatives"]] <> " only, so the degrees of the DE in " <>
      ToString[miss] <> " would not be measured and the objective would not see them. Build the slice with a derivative in every invariant but the unit scale " <>
      ToString[PFBUnitScale[sys]] <> " (bin/local_slice.wls), or import one that has them", <|"MissingDerivatives" -> miss|>]]];
  (* the degree census of the current slice: one timed job per sector *)
  keys = Select[PFBSectorKeys[sys], Intersection[PFBSectorMasters[sys, #], sl["Labels"]] =!= {} &];
  tab = PFBReadDegrees[dir, st];
  needs = needsCensus[tab, keys];
  (* census jobs run once more (below) are collected again *)
  With[{cj = Lookup[ph, "Census", <||>]}, If[Lookup[cj, "Slice", None] === st["Current"],
    needs = Union[needs, Intersection[keys, Complement[Lookup[cj, "Retried", {}], Lookup[cj, "RetryCollected", {}]]]]]];
  If[needs =!= {}, Module[{cj = Lookup[ph, "Census", <||>]},
    If[Lookup[cj, "Slice", None] === st["Current"] && SubsetQ[Lookup[cj, "Keys", {}], needs] && AllTrue[Lookup[cj, "Jobs", {}], DirectoryQ],
      If[! AllTrue[cj["Jobs"], finishedQ], jobsOutcome[ctx, ph, Select[cj["Jobs"], ! finishedQ[#] &], "the degree census of the current slice is still running", msg]];
      With[{r = PFBCollectDegrees[ctx, cj["Jobs"]]}, If[r === $Failed, out["error", "the degree census could not be collected"]];
        ctx = Join[ctx, <|"State" -> r["State"]|>]; st = ctx["State"]];
      ph["Census"] = Join[cj, <|"Collected" -> PFBTimeStamp[], "RetryCollected" -> Lookup[cj, "Retried", {}]|>]; savePhase[dir, ph];
      tab = PFBReadDegrees[dir, st];
      (* a census job that was killed, failed or refused for memory is run once more (its command resumes it); a second
         time its sector stays not measured *)
      With[{again = Select[Transpose[{cj["Keys"], cj["Jobs"]}], retryQ[tab, #[[1]]] && ! MemberQ[Lookup[cj, "Retried", {}], #[[1]]] &]},
        If[again =!= {},
          ph["Census"] = Join[ph["Census"], <|"Retried" -> Union[Lookup[cj, "Retried", {}], again[[All, 1]]]|>]; savePhase[dir, ph];
          jobsOutcome[ctx, ph, again[[All, 2]], "the degree jobs of " <> StringRiffle[PFBSectorString /@ again[[All, 1]], ", "] <> " ended without a measurement (" <>
            StringRiffle[DeleteDuplicates[Lookup[Lookup[tab["Sectors"], Key[#], <||>], "Reason", "?"] & /@ again[[All, 1]]], "; "] <>
            "): they are run once more (the command resumes them); after a second failure their sectors stay not measured", msg]]];
      With[{left = Select[Lookup[ph["Census"], "Retried", {}], retryQ[tab, #] &]}, If[left =!= {},
        AppendTo[msg, "not measured after one retry: " <> StringRiffle[PFBSectorString /@ left, ", "] <> " (the phase leaves their rows alone)"]]];
      needs = needsCensus[tab, keys];
      If[needs =!= {}, out["error", "the degree census left sectors without a usable measurement: " <>
        StringRiffle[(PFBSectorString[#] <> ": " <> ToString[Lookup[Lookup[tab["Sectors"], Key[#], <||>], "Reason", "no record"]]) & /@ needs, "; "]]],
      Module[{jobs = PFBDegreesJob[ctx, #, <||>] & /@ needs},
        If[MemberQ[jobs, $Failed], out["error", "a degree job could not be written (see above)"]];
        ph["Census"] = <|"Slice" -> st["Current"], "Keys" -> needs, "Jobs" -> jobs, "Date" -> PFBTimeStamp[]|>; savePhase[dir, ph];
        jobsOutcome[ctx, ph, jobs, "the degree census of the current slice (" <> ToString[Length[needs]] <> " sector(s))", msg]]]]];
  (* after the pole-free work: where the phase starts *)
  If[! KeyExistsQ[ph, "Start"], ph["Start"] = <|"Slice" -> st["Current"], "Label" -> Last[st["Slices"]]["Label"], "Summary" -> summaryOf2[tab],
     "Sectors" -> Map[If[#["Status"] === "measured", KeyTake[#["Summary"], {"Highest", "Count", "Sum", "Unexplained"}], <|"Status" -> #["Status"]|>] &, tab["Sectors"]],
     "Date" -> PFBTimeStamp[]|>; savePhase[dir, ph]];
  (* the budget: run.wl "SimplifyBudget", else the user's answer to the proposal *)
  prop = PFBSimplifyBudgetProposal[tab, opts];
  budget = Which[
    NumericQ[Lookup[run, "SimplifyBudget", None]], <|"Seconds" -> run["SimplifyBudget"], "Source" -> "run.wl"|>,
    NumericQ[Lookup[opts, "Budget", None]], <|"Seconds" -> opts["Budget"], "Source" -> "the user"|>,
    Lookup[opts, "Budget", None] === "proposed", <|"Seconds" -> prop["Seconds"], "Source" -> "the proposal, accepted by the user"|>,
    AssociationQ[Lookup[ph, "Budget", None]] && NumericQ[ph["Budget"]["Seconds"]], ph["Budget"],
    True, None];
  If[budget === None, ph["Proposal"] = KeyDrop[prop, "PerSector"]; savePhase[dir, ph];
    out["budget", prop["Text"] <> ".\nAsk the user; then run simplify.wls with --budget proposed (or --budget <seconds>), or set \"SimplifyBudget\" in run.wl.", <|"Proposal" -> prop|>]];
  (* the budget is recorded with the proposal it answered; a recorded one stays as it was *)
  If[KeyTake[budget, {"Seconds", "Source"}] =!= KeyTake[Replace[Lookup[ph, "Budget", <||>], Except[_Association] -> <||>], {"Seconds", "Source"}], ph["Budget"] = Join[KeyTake[budget, {"Seconds", "Source"}], <|"Proposed" -> prop["Seconds"]|>]; savePhase[dir, ph]];
  target = Lookup[run, "TargetKinDegree", None];
  (* the moves to run: run.wl "SimplifyMoves" or opts "Moves" (names), default every move *)
  With[{sel = Lookup[opts, "Moves", Lookup[run, "SimplifyMoves", All]]},
    If[ListQ[sel] && ! SubsetQ[Lookup[$PFBSimplifyMoves, "Name"], sel], out["refused", "unknown moves " <> ToString[Complement[sel, Lookup[$PFBSimplifyMoves, "Name"]]] <>
      " (\"SimplifyMoves\" names some of " <> ToString[Lookup[$PFBSimplifyMoves, "Name"]] <> ")"]];
    moves = If[ListQ[sel], Select[$PFBSimplifyMoves, MemberQ[sel, #["Name"]] &], $PFBSimplifyMoves]];
  (* the moves, in order; each runs once per phase. A move may first need jobs of its own (a reduction to scan, the
     samples of a fit): it is "preparing" until they are done, and is then asked again, with its record, for its
     candidates. A tool a move uses is credited to the whole run, with the move as its step (the run's ledger) *)
  Block[{$CoreCitationContext = $CoreCitationContext}, Do[Module[{recs, rec, i, cur = summaryOf2[tab], prep = None},
     CoreCitationContext[dir, "whole run", "simplification move: " <> mv["Title"]];
     If[IntegerQ[target] && IntegerQ[cur["Highest"]] && cur["Highest"] <= target,
       AppendTo[msg, "the highest degree " <> ToString[cur["Highest"]] <> " is at or below the target \"TargetKinDegree\" -> " <> ToString[target]]; Break[]];
     recs = Select[ph["Moves"], #["Move"] === mv["Name"] &];
     rec = If[recs === {}, None, Last[recs]];
     If[rec =!= None && ! MemberQ[{"measuring", "preparing"}, rec["Status"]], Continue[]];
     If[rec =!= None && rec["Status"] === "preparing",
       i = moveIndex[rec["Id"]];
       If[rec["Slice"] =!= st["Current"], ph[["Moves", i, "Status"]] = "stale"; savePhase[dir, ph];
         AppendTo[msg, "move " <> ToString[rec["Id"]] <> ": the slice changed since its jobs were written; it is not tried"]; Continue[]];
       If[! AllTrue[rec["PrepJobs"], finishedQ], jobsOutcome[ctx, ph, Select[rec["PrepJobs"], ! finishedQ[#] &], "move " <> ToString[rec["Id"]] <> " (" <> mv["Title"] <> ") is still preparing", msg]];
       (* the time of its jobs is spent once *)
       If[! TrueQ[Lookup[rec, "PrepCounted", False]], With[{sp = jobsSeconds[rec["PrepJobs"]]},
         ph["Spent"] = ph["Spent"] + sp;
         ph[["Moves", i]] = Join[rec, <|"PrepSpent" -> Lookup[rec, "PrepSpent", 0] + sp, "PrepCounted" -> True|>]; savePhase[dir, ph]]];
       prep = ph[["Moves", i]]];
     If[rec === None || prep =!= None, Module[{id = If[prep === None, Length[ph["Moves"]] + 1, prep["Id"]], pr, jobs, cost, bykey = <||>, put},
       put[r_] := (ph["Moves"] = If[prep === None, Append[ph["Moves"], r], ReplacePart[ph["Moves"], moveIndex[id] -> r]]; savePhase[dir, ph]);
       pr = mv["Propose"][ctx, tab, ph, Join[opts, <|"MoveId" -> id, "Record" -> prep|>]];
       (* a move asks for its own jobs a few times at most *)
       If[pr["Status"] === "jobs" && Lookup[Replace[prep, None -> <||>], "PrepStages", 0] >= 4,
         pr = <|"Status" -> "no gain", "Message" -> "it asked for jobs of its own four times; it is not tried further"|>];
       rec = Join[If[prep === None, <||>, KeyTake[prep, {"PrepJobs", "PrepSpent", "Prep", "PrepStages", "PrepCost"}]],
         <|"Id" -> id, "Move" -> mv["Name"], "Title" -> mv["Title"], "Slice" -> st["Current"], "Before" -> cur, "Status" -> pr["Status"], "Message" -> pr["Message"],
         "Candidates" -> Lookup[pr, "Candidates", {}], "Info" -> Lookup[pr, "Info", <||>], "Date" -> PFBTimeStamp[]|>];
       AppendTo[msg, "move " <> ToString[id] <> " (" <> mv["Title"] <> "): " <> pr["Message"]];
       (* the move's own jobs first, against the budget like the measurements *)
       If[pr["Status"] === "jobs",
         cost = Replace[Lookup[pr, "Cost", Automatic], Except[_?NumericQ] :> prepCost[prop, Lookup[pr, "Keys", {}]]];
         If[ph["Spent"] + cost > budget["Seconds"],
           rec = Join[rec, <|"Status" -> "over budget", "Message" -> "its own jobs would cost about " <> ToString[Ceiling[cost]] <> " s; " <>
             ToString[Max[0, Floor[budget["Seconds"] - ph["Spent"]]]] <> " s of the budget are left"|>];
           put[rec]; ph["Status"] = "done"; ph["End"] = <|"Slice" -> st["Current"], "Summary" -> cur, "Spent" -> ph["Spent"], "Reason" -> "budget", "Date" -> PFBTimeStamp[]|>;
           savePhase[dir, ph];
           out["done", "move " <> ToString[id] <> ": " <> rec["Message"] <> ". The phase stops; a larger budget needs the user's agreement."]];
         rec = Join[rec, <|"Status" -> "preparing", "Prep" -> Lookup[pr, "Prep", <||>], "PrepJobs" -> pr["Jobs"], "PrepCounted" -> False,
           "PrepCost" -> Lookup[rec, "PrepCost", 0] + Ceiling[cost], "PrepStages" -> Lookup[rec, "PrepStages", 0] + 1|>];
         put[rec];
         jobsOutcome[ctx, ph, pr["Jobs"], "move " <> ToString[id] <> " (" <> mv["Title"] <> "): its own jobs first", msg]];
       If[pr["Status"] =!= "proposed", put[rec]; Continue[]];
       (* a candidate's variant in the job of each sector it touches: from T (new masters in integrals: T^-1 inside the
          job's graph), or given by the move ("Variants" -> <|key -> variant|>) *)
       Do[Do[With[{tk = restrictT[sys, sl, cd["T"], k]}, If[tk =!= <||>, bykey[k] = Append[Lookup[bykey, Key[k], {}],
           Replace[Lookup[Lookup[cd, "Variants", <||>], Key[k], Automatic], Automatic :> PFBDegreeVariant[cd["Name"], tk]]]]],
         {k, touchedKeys[sys, sl, cd["T"]]}], {cd, rec["Candidates"]}];
       If[MemberQ[Flatten[Values[bykey]], $Failed], out["error", "a candidate of move " <> ToString[id] <> " is not an invertible change of basis"]];
       (* the cost of the variant jobs, from the census's job times *)
       cost = Total[KeyValueMap[Function[{k, vs}, With[{q = Lookup[prop["PerSector"], Key[k], <|"Job" -> 0, "Measure" -> 0|>]},
           Replace[q["Job"], Except[_?NumericQ] -> 0] + (Length[vs] + 1) Replace[q["Measure"], Except[_?NumericQ] -> 0]]], bykey]];
       If[ph["Spent"] + cost > budget["Seconds"],
         rec["Status"] = "over budget";
         rec["Message"] = "its measurement would cost about " <> ToString[Ceiling[cost]] <> " s; " <> ToString[Max[0, Floor[budget["Seconds"] - ph["Spent"]]]] <> " s of the budget are left";
         put[rec]; ph["Status"] = "done"; ph["End"] = <|"Slice" -> st["Current"], "Summary" -> cur, "Spent" -> ph["Spent"], "Reason" -> "budget", "Date" -> PFBTimeStamp[]|>;
         savePhase[dir, ph];
         out["done", "move " <> ToString[id] <> ": " <> rec["Message"] <> ". The phase stops; a larger budget needs the user's agreement."]];
       jobs = KeyValueMap[Function[{k, vs}, PFBDegreesJob[ctx, k, <|"Name" -> "simp" <> ToString[id] <> "_" <> sectorJobName[k], "Variants" -> vs,
           "ReuseIds" -> With[{d = FileNameJoin[{dir, "jobs", "deg_" <> sectorJobName[k], "ibps"}]}, If[DirectoryQ[d], d, Automatic]]|>]], bykey];
       If[MemberQ[jobs, $Failed], out["error", "a variant job of move " <> ToString[id] <> " could not be written (see above)"]];
       rec = Join[rec, <|"Status" -> "measuring", "Jobs" -> jobs, "JobKeys" -> Keys[bykey], "Cost" -> Ceiling[cost]|>];
       put[rec];
       jobsOutcome[ctx, ph, jobs, "move " <> ToString[id] <> " (" <> mv["Title"] <> "): its candidates are measured as variants", msg]]];
     (* measuring: collect, choose, gate *)
     i = moveIndex[rec["Id"]];
     If[rec["Slice"] =!= st["Current"], ph[["Moves", i, "Status"]] = "stale"; savePhase[dir, ph];
       AppendTo[msg, "move " <> ToString[rec["Id"]] <> ": the slice changed since its jobs were written; it is not measured"]; Continue[]];
     If[! AllTrue[rec["Jobs"], finishedQ], jobsOutcome[ctx, ph, Select[rec["Jobs"], ! finishedQ[#] &], "move " <> ToString[rec["Id"]] <> " is still measuring", msg]];
     Module[{jobOf = AssociationThread[rec["JobKeys"], rec["Jobs"]], spent, meas, ok, chosen, r, tabs = <||>},
       spent = Total[Replace[Lookup[PFBSubtreeStatus[#], "Seconds", 0], Except[_?NumericQ] -> 0] & /@ rec["Jobs"]];
       meas = Table[Module[{ks = Intersection[touchedKeys[sys, sl, cd["T"]], rec["JobKeys"]], ct},
           ct = candidateTable[ctx, tab, cd, Lookup[jobOf, ks]];
           If[StringQ[ct["Reason"]], Join[cd, <|"Measured" -> Missing["NotMeasured"], "Reason" -> ct["Reason"]|>],
             tabs[cd["Name"]] = ct["Table"];
             Join[cd, <|"Measured" -> summaryOf2[ct["Table"]], "MeasuredObjective" -> objOf[ct["Table"]["Summary"]], "OffSlice" -> offSliceCheck[tab, ct["Table"], ks]|>]]], {cd, rec["Candidates"]}];
       (* lower than now, and nothing new at the degree jobs' points *)
       ok = Select[meas, AssociationQ[#["Measured"]] && lex[#["MeasuredObjective"], objOf[cur]] && TrueQ[#["OffSlice"]["Pass"]] &];
       chosen = If[ok === {}, None, First[SortBy[ok, Append[#["MeasuredObjective"], Length[#["T"]]] &, lex]]];
       ph["Spent"] = ph["Spent"] + spent;
       ph[["Moves", i]] = Join[rec, <|"Candidates" -> (KeyDrop[#, {"T", "Variants"}] & /@ meas), "Spent" -> spent|>];
       If[chosen === None,
         ph[["Moves", i, "Status"]] = "no gain"; ph[["Moves", i, "Message"]] = "no candidate lowered the measured objective " <> ToString[objOf[cur]] <>
           With[{off = Select[meas, AssociationQ[Lookup[#, "OffSlice", None]] && ! #["OffSlice"]["Pass"] &]}, If[off === {}, "",
             " without new poles away from the slice (refused there: " <> StringRiffle[(#["Name"] <> ", " <> #["OffSlice"]["Detail"]) & /@ off, "; "] <> ")"]];
         AppendTo[msg, "move " <> ToString[rec["Id"]] <> ": " <> ph[["Moves", i, "Message"]]]; savePhase[dir, ph]; Continue[]];
       (* the gate takes the move's definitions ("Defs", default T) and, for definitions with integrals, the reductions of a job
          ("RedJob": its folder; the first point is the slice point) *)
       r = PFBTryChange[ctx, None, Lookup[chosen, "Defs", chosen["T"]], <|"Rung" -> "simplify", "Name" -> "simplify " <> ToString[rec["Id"]] <> ": " <> mv["Title"],
           "MCBSectors" -> mcbSectorsOf[sys, rec, chosen],
           "Provenance" -> "simplification phase, move " <> ToString[rec["Id"]] <> " (" <> mv["Title"] <> "), candidate " <> chosen["Name"] <> " of " <> ToString[Length[meas]] <>
             ", measured by FFAllDegrees in " <> StringRiffle[FileNameTake /@ rec["Jobs"], ", "],
           "Simplify" -> <|"MoveId" -> rec["Id"], "Move" -> mv["Name"], "Title" -> mv["Title"], "Candidate" -> chosen["Name"],
             "Rescalings" -> Lookup[Lookup[chosen, "Info", <||>], "Rescalings", Missing[]], "Before" -> cur, "After" -> chosen["Measured"], "BeforeObjective" -> objOf[cur],
             "AfterObjective" -> chosen["MeasuredObjective"], "PredictedObjective" -> Lookup[chosen, "Objective", Missing[]], "Jobs" -> (FileNameTake /@ rec["Jobs"])|>|>,
         Join[<|"Degrees" -> <|"Before" -> cur, "After" -> chosen["Measured"], "Measured" -> True, "Jobs" -> (FileNameTake /@ rec["Jobs"]), "OffSlice" -> chosen["OffSlice"]|>|>,
           If[StringQ[Lookup[chosen, "RedJob", None]], <|"Reds" -> (Get /@ PFBRedFiles[chosen["RedJob"]])|>, <||>]]];
       ph[["Moves", i, "Chosen"]] = chosen["Name"];
       ph[["Moves", i, "Change"]] = If[AssociationQ[Lookup[r, "Record", None]], r["Record"]["Id"], Missing[]];
       ph[["Moves", i, "Status"]] = r["Status"];
       ph[["Moves", i, "Gate"]] = If[AssociationQ[Lookup[r, "Gate", None]], r["Gate"]["Message"], Lookup[r, "Message", ""]];
       AppendTo[msg, "move " <> ToString[rec["Id"]] <> ": candidate " <> chosen["Name"] <> " measured " <> ToString[chosen["MeasuredObjective"]] <> " from " <> ToString[objOf[cur]] <>
         "; the gate: " <> r["Status"] <> Which[r["Status"] === "rejected", "\n" <> r["Gate"]["Message"], r["Status"] === "not tried", " (" <> r["Message"] <> ")", True, ""]];
       Switch[r["Status"],
         "accepted",
           ctx = storeTable[r["Context"], KeyDrop[tabs[chosen["Name"]], "Summary"], <|"Source" -> "measured", "Simplify" -> <|"Move" -> rec["Id"], "Candidate" -> chosen["Name"]|>|>];
           st = ctx["State"]; sl = PFBCurrentSlice[dir, st]; tab = PFBReadDegrees[dir, st],
         "pending",
           ctx = r["Context"]; st = ctx["State"];
           ph[["Moves", i, "TableFile"]] = FileNameJoin[{dir, "simplify", "move_" <> ToString[rec["Id"]] <> "_degrees.m"}];
           Put[KeyDrop[tabs[chosen["Name"]], "Summary"], ph[["Moves", i, "TableFile"]]]; savePhase[dir, ph];
           out["approval", "change " <> ToString[ph[["Moves", i, "Change"]]] <> " waits for the user's approval: show it, then bin/ws bin/approve.wls " <> run["File"] <> " " <>
             ToString[ph[["Moves", i, "Change"]]] <> " after a yes, or bin/ws bin/approve.wls " <> run["File"] <> " --decline " <> ToString[ph[["Moves", i, "Change"]]] <>
             " after a no, and run simplify.wls again"],
         _, Null];
       savePhase[dir, ph]]], {mv, moves}]];
  ph["Status"] = "done"; ph["End"] = <|"Slice" -> st["Current"], "Summary" -> summaryOf2[tab], "Spent" -> ph["Spent"], "Date" -> PFBTimeStamp[]|>;
  savePhase[dir, ph];
  out["done", "the simplification phase is done: {highest, terms at it, sum} " <> ToString[objOf[ph["Start"]["Summary"]]] <> " -> " <> ToString[objOf[ph["End"]["Summary"]]] <> "; " <>
    ToString[Count[ph["Moves"], _?(#["Status"] === "accepted" &)]] <> " move(s) accepted, " <> ToString[Round[ph["Spent"]]] <> " s of degree jobs"]], $simplifyTag];


(* ::Section:: *)
(*Reports*)


(* every phase of the run, oldest first: those kept by --new (simplify/phase_<date>.m), then simplify/phase.m *)
phasesOf[dir_] := Join[Get /@ Sort[FileNames["phase_*.m", FileNameJoin[{dir, "simplify"}]]], With[{p = PFBReadPhase[dir]}, If[AssociationQ[p], {p}, {}]]];

PFBSimplifyReport[dir_String, st_Association] := Module[{phs = phasesOf[dir], ph, sls = Lookup[st, "Slices", {}], first, cur, stages, secs, start, now, startPh, lastDone, labelOf},
  ph = If[phs === {}, None, Last[phs]];
  labelOf[f_] := Lookup[SelectFirst[sls, #["File"] === f &, <|"Label" -> "-"|>], "Label", "-"];
  first = If[sls =!= {} && AssociationQ[Lookup[sls[[1]], "DegreeSummary", None]], <|"Stage" -> "starting degrees", "Label" -> sls[[1]]["Label"], "Summary" -> sls[[1]]["DegreeSummary"]|>,
    <|"Stage" -> "starting degrees", "Label" -> If[sls === {}, "-", sls[[1]]["Label"]], "Summary" -> Missing["NotMeasured"]|>];
  cur = PFBReadDegrees[dir, st];
  startPh = SelectFirst[phs, KeyExistsQ[#, "Start"] &, None];
  lastDone = SelectFirst[Reverse[phs], Lookup[#, "Status", "open"] === "done" && AssociationQ[Lookup[#, "End", None]] &, None];
  start = If[startPh =!= None, <|"Stage" -> "after the pole-free work", "Label" -> startPh["Start"]["Label"], "Summary" -> startPh["Start"]["Summary"]|>,
    <|"Stage" -> "after the pole-free work", "Label" -> "-", "Summary" -> Missing["NotRun"]|>];
  (* after the phase: the current degrees when the last phase is done, else what the last finished phase ended with *)
  now = Which[
    ph =!= None && Lookup[ph, "Status", "open"] === "done" && AssociationQ[cur],
      <|"Stage" -> "after the simplification phase", "Label" -> If[sls === {}, "-", Last[sls]["Label"]], "Summary" -> KeyTake[cur["Summary"], sumKeys]|>,
    lastDone =!= None, <|"Stage" -> "after the simplification phase", "Label" -> labelOf[lastDone["End"]["Slice"]], "Summary" -> lastDone["End"]["Summary"]|>,
    True, <|"Stage" -> "after the simplification phase", "Label" -> "-", "Summary" -> Missing[If[ph === None, "NotRun", "Running"]]|>];
  stages = {first, start, now};
  secs = If[AssociationQ[cur], Association[KeyValueMap[#1 -> <|"Now" -> If[#2["Status"] === "measured", KeyTake[#2["Summary"], {"Highest", "Count", "Sum", "Unexplained"}], <|"Status" -> #2["Status"]|>],
       "Start" -> If[startPh =!= None, Lookup[startPh["Start"]["Sectors"], Key[#1], Missing[]], Missing["NotRun"]]|> &, cur["Sectors"]]], <||>];
  <|"Stages" -> stages, "Sectors" -> secs, "Phase" -> ph, "Phases" -> phs, "Moves" -> Flatten[Lookup[phs, "Moves", {}], 1], "Current" -> cur|>];

(* a move in one line: its status, its message, the candidate chosen and the change it became *)
moveLine[m_] := StringRiffle[Select[{ToString[m["Status"]], ToString[Lookup[m, "Message", ""]],
    If[KeyExistsQ[m, "Chosen"], "chosen: " <> ToString[m["Chosen"]] <> If[IntegerQ[Lookup[m, "Change", None]], " (change " <> ToString[m["Change"]] <> ")", ""], ""]}, # =!= "" &], "; "];
phaseLine[ph_] := "status " <> ToString[Lookup[ph, "Status", "?"]] <> "; budget " <>
  If[AssociationQ[Lookup[ph, "Budget", None]], ToString[ph["Budget"]["Seconds"]] <> " s (" <> ToString[ph["Budget"]["Source"]] <> ")", "not set"] <>
  "; spent " <> ToString[Round[Lookup[ph, "Spent", 0]]] <> " s of degree jobs";
candLine[cd_] := "candidate " <> cd["Name"] <> ": predicted " <> ToString[Replace[Lookup[cd, "Objective", "-"], _Missing -> "-"]] <> ", measured " <>
  If[KeyExistsQ[cd, "MeasuredObjective"], ToString[cd["MeasuredObjective"]], ToString[Lookup[cd, "Reason", "-"]]];

cell[s_, k_] := If[AssociationQ[s], ToString[Replace[Lookup[s, k, "-"], {None -> "-", _Missing -> "-"}]], "-"];
stageNote[s_] := Switch[s, Missing["NotMeasured"], "not measured", Missing["NotRun"], "the phase has not run", Missing["Running"], "the phase is not finished", _, "-"];
triple[s_] := If[AssociationQ[s] && KeyExistsQ[s, "Highest"], "{" <> cell[s, "Highest"] <> ", " <> cell[s, "Count"] <> ", " <> cell[s, "Sum"] <> "}", ToString[Lookup[Replace[s, Except[_Association] -> <||>], "Status", "-"]]];

PFBSimplifyMarkdown[dir_String, sys_Association, st_Association] := Module[{rp = PFBSimplifyReport[dir, st], out = {}, add},
  add[x__] := AppendTo[out, StringJoin[x]];
  If[AllTrue[rp["Stages"], ! AssociationQ[#["Summary"]] &] && ! AssociationQ[rp["Current"]], Return[""]];
  add["## Kinematic degrees\n\nThe degree of a term (an entry at one power of eps, or a whole entry) is the larger of its numerator and denominator degrees in the invariants, ",
    "unit scale 1, as FFAllDegrees measured it. Unexplained: the denominator degree that the known singularities do not explain.\n\n",
    "| stage | slice | highest | terms at it | sum | unexplained | sectors measured |\n|---|---|---|---|---|---|---|\n"];
  Do[With[{s = g["Summary"]}, add["| ", g["Stage"], " | ", ToString[g["Label"]], " | ",
      If[AssociationQ[s], StringRiffle[{cell[s, "Highest"], cell[s, "Count"], cell[s, "Sum"], cell[s, "Unexplained"], If[KeyExistsQ[s, "Measured"], cell[s, "Measured"] <> " of " <> cell[s, "Sectors"], "-"]}, " | "],
        stageNote[s] <> " | | | | "], " |\n"]], {g, rp["Stages"]}];
  If[rp["Sectors"] =!= <||>,
    add["\nPer sector, after the pole-free work and now ({highest, terms at it, sum}; unexplained denominator degree):\n\n| sector | after the pole-free work | now | unexplained (now) |\n|---|---|---|---|\n"];
    KeyValueMap[add["| `", PFBSectorString[#1], "` | ", If[AssociationQ[#2["Start"]], triple[#2["Start"]], "-"], " | ", triple[#2["Now"]], " | ", cell[#2["Now"], "Unexplained"], " |\n"] &, rp["Sectors"]]];
  Do[With[{ph = rp["Phases"][[k]]},
     add["\n### Simplification phase", If[Length[rp["Phases"]] > 1, " " <> ToString[k], ""], "\n\n", StringReplace[phaseLine[ph], StartOfString ~~ x_ :> ToUpperCase[x]], ".\n\n"];
     Do[add["- Move ", ToString[m["Id"]], " (", m["Title"], "): ", moveLine[m], ".\n",
        StringJoin[Table["  - " <> candLine[cd] <> Which[AssociationQ[Lookup[Lookup[cd, "Info", <||>], "Rescalings", None]], "; " <> StringRiffle[KeyValueMap["ut[" <> ToString[#1] <> "] -> `" <>
             ToString[#2, InputForm] <> "` ut[" <> ToString[#1] <> "]" &, cd["Info"]["Rescalings"]], ", "],
           AssociationQ[Lookup[Lookup[cd, "Info", <||>], "Set", None]], "; " <> StringRiffle[KeyValueMap["ut[" <> ToString[#1] <> "] -> `" <> ToString[#2, InputForm] <> "`" &, cd["Info"]["Set"]], ", "],
           True, ""] <> "\n", {cd, Lookup[m, "Candidates", {}]}]]], {m, ph["Moves"]}]],
    {k, Length[rp["Phases"]]}];
  StringJoin[out]];

esc[x_] := MCBHTMLEscape[ToString[x]];

PFBSimplifyHTML[dir_String, sys_Association, st_Association] := Module[{rp = PFBSimplifyReport[dir, st]},
  If[AllTrue[rp["Stages"], ! AssociationQ[#["Summary"]] &] && rp["Phases"] === {}, Return[""]];
  StringJoin[
    "<h3>Degrees by stage</h3><div class='scroll'><table><tr><th>stage</th><th>slice</th><th>highest</th><th>terms at it</th><th>sum</th><th>unexplained</th></tr>",
    Table[With[{s = g["Summary"]}, "<tr><td>" <> esc[g["Stage"]] <> "</td><td>" <> esc[g["Label"]] <> "</td>" <>
       If[AssociationQ[s], StringJoin[("<td>" <> esc[cell[s, #]] <> "</td>") & /@ {"Highest", "Count", "Sum", "Unexplained"}], "<td colspan='4' class='muted'>" <> esc[stageNote[s]] <> "</td>"] <> "</tr>"],
      {g, rp["Stages"]}],
    "</table></div>",
    If[rp["Sectors"] === <||>, "", "<div class='scroll'><table><tr><th>sector</th><th>after the pole-free work</th><th>now</th><th>unexplained denominator degree</th></tr>" <>
      StringJoin[KeyValueMap["<tr><td><code>" <> esc[PFBSectorString[#1]] <> "</code></td><td>" <> esc[If[AssociationQ[#2["Start"]], triple[#2["Start"]], "-"]] <> "</td><td>" <>
         esc[triple[#2["Now"]]] <> "</td><td>" <> esc[cell[#2["Now"], "Unexplained"]] <> "</td></tr>" &, rp["Sectors"]]] <> "</table></div>"],
    Table[With[{ph = rp["Phases"][[k]]}, "<h3>Simplification phase" <> If[Length[rp["Phases"]] > 1, " " <> ToString[k], ""] <> "</h3><p>" <> esc[phaseLine[ph]] <> ".</p><ul class='tight'>" <>
       StringJoin[Table["<li>move " <> esc[m["Id"]] <> " (" <> esc[m["Title"]] <> "): " <> esc[moveLine[m]] <> "<ul class='tight'>" <>
          StringJoin[Table["<li>" <> esc[candLine[cd]] <> "</li>", {cd, Lookup[m, "Candidates", {}]}]] <> "</ul></li>", {m, ph["Moves"]}]] <> "</ul>"], {k, Length[rp["Phases"]]}]]];


End[];
EndPackage[];
