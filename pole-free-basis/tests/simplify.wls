#!/usr/bin/env wolframscript
(* The simplification phase without FiniteFlow or IBP, on planted data: the one-loop massless box of the
   maximal-cut-basis examples (unit scale s, letters s, t, s + t, derivative d/dt), with a planted bad normalisation of
   the box master, B3 = s^2/(t (s + t)) I4. Its DE is known by hand (the bare one of tests/degrees_example.wls,
   B = D A D^-1 + (dD/dt) D^-1), and so are its degrees and letter content: the planted degree tables are computed here
   exactly, as FFAllDegrees would measure them.
   Checked: the precondition; the objective and the gate of a simplification (PFBTryChange rung "simplify": a drop of the
   measured degrees, no drop, no measurement, a change of mass dimension, an eps-form block, approval mode); the model and
   integer program of move (i) against a brute-force search (a rescaling that helps, one that cannot, eps-form and zero
   blocks left alone, the mass dimension kept, an odd letter dimension, a unit scale that is no letter), the exactness of
   the prediction off the diagonal and its bound on it; maximal-cut-basis's normalisations; the budget proposal from
   planted job times; the phase's steps that need no job (refusal, budget, over budget, target); the reports.
   usage: bin/ws tests/simplify.wls        exit code 0 when every test passes *)
Get[FileNameJoin[{ParentDirectory[DirectoryName[$InputFileName]], "lib", "PoleFreeBasis.wl"}]];
$PFBVerbose = False;
ea = PoleFreeBasis`Simplify`Private`ea;
(* associations compared as sets of rules: the order of the letters does not matter *)
sameA[a_, b_] := (a /. as_Association :> Sort[Normal[as]]) === (b /. as_Association :> Sort[Normal[as]]);

boxFile = FileNameJoin[{ParentDirectory[$PFBRoot], "maximal-cut-basis", "examples", "box-one-loop", "family.wl"}];
key3 = {box, {1, 1, 1, 1}}; key2 = {box, {0, 1, 0, 1}}; key1 = {box, {1, 0, 1, 0}};
P = {s -> 1, t -> 3/7};
(* the DE of the bare masters I2(s), I2(t), I4 (tests/degrees_example.wls checks it against FiniteFlow) *)
Abare = {{0, 0, 0}, {0, -eps/t, 0}, {-2 (1 - 2 eps)/(s t (s + t)), 2 (1 - 2 eps)/(t^2 (s + t)), -(1/t + eps s/(t (s + t)))}};
rescaled[n_] := With[{Dm = DiagonalMatrix[{1, 1, n}]}, Together[Dm . Abare . Inverse[Dm] + D[Dm, t] . Inverse[Dm]]];
g3 = s^2/(t (s + t));
Abad = rescaled[g3];
probes = {t, 1 + t};
mult[p_, q_] := Module[{m = 0}, While[PolynomialRemainder[p, q^(m + 1), t] === 0, m++]; m];
letterContent[p_] := Association[Select[Table[q -> mult[p, q], {q, probes}], #[[2]] > 0 &]];
termOf[c_, pw_] := Module[{gg = Together[c], n, d, nl, dl},
  n = Numerator[gg]; d = Denominator[gg]; nl = letterContent[n]; dl = letterContent[d];
  <|"Power" -> pw, "Num" -> Exponent[n, t], "Den" -> Exponent[d, t], "VarDegrees" -> {{Exponent[n, t], 0, Exponent[d, t], 0}}, "NumLetters" -> nl, "DenLetters" -> dl,
    "NumUnexplained" -> Exponent[n, t] - Total[KeyValueMap[#2 Exponent[#1, t] &, nl]], "DenUnexplained" -> Exponent[d, t] - Total[KeyValueMap[#2 Exponent[#1, t] &, dl]]|>];
(* the entries of a DE at s = 1 as a degree job measures them: per power of eps *)
entriesOf[A_, rows_] := Flatten[Table[With[{f = Together[A[[r, c]] /. s -> 1]}, If[f === 0, {},
     With[{rg = PFBEpsRange[f]}, {<|"Matrix" -> 1, "Derivative" -> t, "Row" -> r, "Column" -> c, "Eps" -> {"Laurent", rg[[1]], rg[[2]]},
       "Terms" -> Table[With[{cf = Together[SeriesCoefficient[f, {eps, 0, pw}]]}, If[cf === 0, Nothing, termOf[cf, pw]]], {pw, rg[[1]], rg[[2]]}]|>}]]], {r, rows}, {c, 3}], 2];
secRec[A_, rows_, wall_, meas_] := With[{ents = entriesOf[A, rows]}, <|"Status" -> "measured", "Source" -> "measured", "Job" -> "planted", "Rows" -> rows, "Entries" -> ents,
   "Summary" -> PFBDegreeSummary[ents], "Probes" -> probes, "JobSectors" -> 1, "JobWallSeconds" -> wall, "JobSeconds" -> meas|>];
tableOf[A_] := Module[{tb = <|"Keys" -> {key1, key2, key3}, "UnitScale" -> s, "Vars" -> {t}, "Provenance" -> <|"Source" -> "measured"|>,
     "Sectors" -> <|key1 -> secRec[A, {1}, 11, 1], key2 -> secRec[A, {2}, 12, 1], key3 -> secRec[A, {3}, 20, 2]|>|>}, Join[tb, <|"Summary" -> PFBDegreeSummary[tb]|>]];
objExact[A_] := PFBDegreeObjective[PFBDegreeSummary[entriesOf[A, {1, 2, 3}]]];
(* a planted run: masters, system, run.wl, a slice of the DE A at P with its census *)
newRun[dir_, A_, masters_, extra_ : <||>] := Module[{ctx, sl, st},
  CreateDirectory[dir, CreateIntermediateDirectories -> True];
  Put[masters, FileNameJoin[{dir, "masters.m"}]];
  Put[<|"Name" -> "planted", "Families" -> {Join[<|"Name" -> "box", "Family" -> boxFile, "Masters" -> "masters.m"|>, Lookup[extra, "Family", <||>]]}, "Letters" -> {s, t, s + t}|>,
    FileNameJoin[{dir, "system.wl"}]];
  Put[Join[<|"System" -> "system.wl", "OutputDir" -> FileNameJoin[{dir, "run"}], "AllowTmp" -> True, "Paths" -> Automatic|>, Lookup[extra, "Run", <||>]], FileNameJoin[{dir, "run.wl"}]];
  ctx = PFBStartRun[FileNameJoin[{dir, "run.wl"}]];
  sl = <|"R" -> {Together[A /. P]}, "Derivatives" -> {t}, "Point" -> P, "Labels" -> {1, 2, 3}, "Index" -> <|1 -> 1, 2 -> 2, 3 -> 3|>, "Frame" -> "RootFree", "History" -> {}|>;
  st = PFBStoreSlice[ctx["Dir"], ctx["State"], sl, PFBCensus[ctx["System"], sl], "planted"];
  Join[ctx, <|"State" -> st|>]];
mastersBad = {j[box, 1, 0, 1, 0], j[box, 0, 1, 0, 1], g3 j[box, 1, 1, 1, 1]};
tmp = CreateDirectory[];

(* ---- A. the precondition ---- *)
ctxPole = newRun[FileNameJoin[{tmp, "pole"}], ReplacePart[Abad, {3, 1} -> 1/(1 - 2 eps)], mastersBad];
cPole = Get[FileNameJoin[{ctxPole["Dir"], Last[ctxPole["State"]["Slices"]]["Census"]}]];
pre1 = PFBSimplifyPrecondition[ctxPole["System"], ctxPole["State"], cPole];
pre2 = PFBSimplifyPrecondition[ctxPole["System"], Join[ctxPole["State"], <|"Flagged" -> <|key3 -> <|"Reason" -> "planted"|>|>|>], cPole];
pre3 = PFBSimplifyPrecondition[ctxPole["System"], Join[ctxPole["State"], <|"Flagged" -> <|key3 -> <||>|>, "Pending" -> {<|"Id" -> 4, "Rung" -> 3|>}|>], cPole];
stepPole = PFBSimplifyStep[ctxPole, <||>];

(* ---- B. the gate of a simplification ---- *)
ctx = newRun[FileNameJoin[{tmp, "gate"}], Abad, mastersBad];
sys = ctx["System"];
r3 = t^2 (s + t)^2/s^4;
before = KeyTake[PFBDegreeSummary[entriesOf[Abad, {1, 2, 3}]], {"Highest", "Count", "Sum", "Terms"}];
after = KeyTake[PFBDegreeSummary[entriesOf[rescaled[g3 r3], {1, 2, 3}]], {"Highest", "Count", "Sum", "Terms"}];
info[n_] := <|"Rung" -> "simplify", "Name" -> "planted simplification " <> n, "Provenance" -> "planted",
  "Simplify" -> <|"MoveId" -> 1, "Move" -> "rescale", "Title" -> "global letter rescaling", "Candidate" -> "ip", "Rescalings" -> <|3 -> r3|>,
    "BeforeObjective" -> PFBDegreeObjective[before], "AfterObjective" -> PFBDegreeObjective[after], "PredictedObjective" -> {2, 2, 7}|>|>;
degs[b_, a_] := <|"Degrees" -> <|"Before" -> b, "After" -> a, "Measured" -> True, "Jobs" -> {"planted"}|>|>;
failed[r_] := Select[r["Gate"]["Checks"], ! #["Pass"] &][[All, "Name"]];
gNoDrop = PFBTryChange[ctx, None, <|3 -> r3 ut[3]|>, info["no drop"], degs[before, before]];
ctx = gNoDrop["Context"];
gNoMeas = PFBTryChange[ctx, None, <|3 -> r3 ut[3]|>, info["not measured"], <||>];
ctx = gNoMeas["Context"];
gDim = PFBTryChange[ctx, None, <|3 -> t ut[3]|>, info["dimension"], degs[before, after]];
ctx = gDim["Context"];
gEps = PFBTryChange[ctx, None, <|2 -> (t/s) ut[2]|>, info["eps-form"], degs[before, after]];
ctx = gEps["Context"];
gKey = PFBTryChange[ctx, None, <|3 -> r3 ut[3]|>, <|"Rung" -> 3|>, <||>];
(* approval mode: pending, then approved *)
ctx = Join[ctx, <|"State" -> PFBSaveState[ctx["Dir"], Join[ctx["State"], <|"Approval" -> True|>]]|>];
gOK = PFBTryChange[ctx, None, <|3 -> r3 ut[3]|>, info["accepted"], degs[before, after]];
ctx = gOK["Context"];
appr = PFBApprove[ctx["Dir"], ctx["State"], ctx["System"], gOK["Record"]["Id"]];
ctx = Join[ctx, <|"State" -> appr["State"], "System" -> appr["System"]|>];
slAfter = PFBCurrentSlice[ctx["Dir"], ctx["State"]];
recOK = SelectFirst[ctx["State"]["Accepted"], #["Id"] == gOK["Record"]["Id"] &];

(* ---- C. move (i): the model and the integer program ---- *)
ctxM = newRun[FileNameJoin[{tmp, "model"}], Abad, mastersBad];
tabBad = tableOf[Abad];
model = PFBRescaleModel[ctxM, tabBad];
(* the box row times eps: its own block is not eps-form (eps^1..eps^2), but the row has no eps^0 term, which d log r
   on its diagonal would add *)
AepsRow = ReplacePart[Abad, 3 -> eps Abad[[3]]];
modelE = PFBRescaleModel[newRun[FileNameJoin[{tmp, "epsrow"}], AepsRow, mastersBad], tableOf[AepsRow]];
sol = PFBRescaleProgram[model, <|"SolverTime" -> 30|>];
(* brute force over the bounds of the free masters *)
brute[mdl_] := Module[{free = mdl["Free"], pts, best = None, bo},
  pts = Tuples[Flatten[Table[Range[mdl["Bounds"][l][q][[1]], mdl["Bounds"][l][q][[2]]], {l, free}, {q, mdl["Allowed"][l]}], 1]];
  Do[Module[{ex = <||>, i = 0, ok = True},
     Do[ex[l] = Association[Table[q -> pt[[++i]], {q, mdl["Allowed"][l]}]];
       If[! PoleFreeBasis`Simplify`Private`feasibleQ[mdl, l, Select[ex[l], # =!= 0 &]], ok = False], {l, free}];
     If[ok, With[{o = PFBPredictDegrees[mdl, ex]["Objective"]}, If[best === None || PFBObjectiveLess[o, bo], best = ex; bo = o]]]], {pt, pts}];
  bo];
bruteBad = brute[model];
(* the prediction against the exact rescaled DE, for every exponent in the bounds: exact off the diagonal, a bound on it *)
predVsExact = Table[Module[{ex = <|3 -> <|t -> a1, 1 + t -> a2|>|>, pr, exact, offP, offE, diagP, diagE},
    pr = PFBPredictDegrees[model, ex]["TermDegrees"];
    exact = entriesOf[rescaled[g3 t^a1 (s + t)^a2], {3}];
    offP = Sort[Transpose[{{#["Column"], #["Power"]} & /@ model["Off"], pr["Off"]}]];
    offE = Sort[Flatten[Table[If[e["Column"] =!= 3, {{e["Column"], #["Power"]}, Max[#["Num"], #["Den"]]} & /@ e["Terms"], {}], {e, exact}], 1]];
    diagP = pr["Diag"][[1]];
    diagE = Max[Append[Cases[Flatten[Table[If[e["Column"] === 3, {#["Power"], Max[#["Num"], #["Den"]]} & /@ e["Terms"], {}], {e, exact}], 1], {0, d_} :> d], 0]];
    {offP === offE, diagE <= diagP}], {a1, -2, 2}, {a2, -2, 2}];
cands = PFBRescaleCandidates[ctxM, model, sol];
(* rescaling cannot help: the basis the program finds is already optimal *)
ctxG = newRun[FileNameJoin[{tmp, "good"}], rescaled[g3 r3], {j[box, 1, 0, 1, 0], j[box, 0, 1, 0, 1], t (s + t)/s^2 j[box, 1, 1, 1, 1]}];
modelG = PFBRescaleModel[ctxG, tableOf[rescaled[g3 r3]]];
solG = PFBRescaleProgram[modelG];
candsG = PFBRescaleCandidates[ctxG, modelG, solG];
moveG = PoleFreeBasis`Simplify`Private`rescaleMove[ctxG, tableOf[rescaled[g3 r3]], <||>, <||>];
(* planted models: an odd letter dimension (only even powers keep an integer unit-scale power), a unit scale that is no letter *)
oddModel[unitLetter_] := <|"Free" -> {1}, "Allowed" -> <|1 -> {w}|>, "Letters" -> <|1 -> <|w -> <|"Letter" -> w, "Dim" -> 1|>|>|>, "UnitLetter" -> <|1 -> unitLetter|>,
   "UnitFixed" -> <|1 -> False|>, "UnitScale" -> m2, "UnitDim" -> 2, "Vars" -> {w}, "Probes" -> {w}, "ProbeDegree" -> <|w -> 1|>, "ProbeIndex" -> <|w -> 1|>,
   "E" -> <|1 -> <|w -> ea[1, 1]|>|>, "Images" -> <|1 -> {}|>, "Initial" -> <||>, "Bounds" -> <|1 -> <|w -> {-2, 2}|>|>, "Bound" -> 2,
   "Off" -> {<|"Row" -> 1, "Column" -> 2, "Power" -> 0, "Q" -> {w}, "Delta" -> <|w -> ea[1, 1]|>, "E0" -> <|w -> -1|>, "NumC" -> 0, "DenC" -> 0|>,
     <|"Row" -> 2, "Column" -> 1, "Power" -> 0, "Q" -> {w}, "Delta" -> <|w -> -ea[1, 1]|>, "E0" -> <|w -> 2|>, "NumC" -> 0, "DenC" -> 0|>},
   "Diag" -> {}, "New" -> {}, "Fixed" -> {}, "Current" -> {2, 1, 3}|>;
solOdd = PFBRescaleProgram[oddModel[True], <|"SolverTime" -> 30|>];
solOddNoUnit = PFBRescaleProgram[oddModel[False], <|"SolverTime" -> 30|>];

(* ---- maximal-cut-basis's normalisations ---- *)
mcbDir = FileNameJoin[{tmp, "mcbrun"}];
CreateDirectory[FileNameJoin[{mcbDir, "j1111"}], CreateIntermediateDirectories -> True];
Put[{eps^2 s t j[box, 1, 1, 1, 1]}, FileNameJoin[{mcbDir, "j1111", "masters.m"}]];
Put[<|"status" -> "eps-form", "masters" -> {<|"definition" -> eps^2 s t j[box, 1, 1, 1, 1], "normalisation" -> "rational"|>}|>, FileNameJoin[{mcbDir, "j1111", "basis.m"}]];
CreateDirectory[FileNameJoin[{mcbDir, "j0101"}]];
Put[{eps Sqrt[t (t - 4)] j[box, 0, 2, 0, 1]}, FileNameJoin[{mcbDir, "j0101", "masters.m"}]];
Put[<|"status" -> "eps-form", "masters" -> {<|"definition" -> eps Sqrt[t (t - 4)] j[box, 0, 2, 0, 1], "normalisation" -> t (t - 4)|>}|>, FileNameJoin[{mcbDir, "j0101", "basis.m"}]];
ctxMCB = newRun[FileNameJoin[{tmp, "mcb"}], Abad, mastersBad, <|"Family" -> <|"MCBRun" -> mcbDir|>|>];
norm3 = PFBMCBNormalisations[ctxMCB["System"], key3];
norm2 = PFBMCBNormalisations[ctxMCB["System"], key2];
normNone = PFBMCBNormalisations[ctxM["System"], key3];
modelMCB = PFBRescaleModel[ctxMCB, tabBad];
candsMCB = PFBRescaleCandidates[ctxMCB, modelMCB, PFBRescaleProgram[modelMCB]];

(* ---- D. the budget proposal from planted job times ---- *)
budTab = <|"Keys" -> {key1, key2, key3, {box, {1, 1, 1, 0}}}, "Sectors" -> <|key1 -> <|"Status" -> "measured", "JobWallSeconds" -> 20, "JobSeconds" -> 1|>,
    key2 -> <|"Status" -> "measured", "JobWallSeconds" -> 30, "JobSeconds" -> 2|>, key3 -> <|"Status" -> "measured", "JobWallSeconds" -> 40, "JobSeconds" -> 3|>,
    {box, {1, 1, 1, 0}} -> <|"Status" -> "not measured", "Reason" -> "the job is refused: memory"|>|>|>;
bud = PFBSimplifyBudgetProposal[budTab];
bud2 = PFBSimplifyBudgetProposal[Join[budTab, <|"Sectors" -> Join[budTab["Sectors"], <|key3 -> <|"Status" -> "measured", "JobSeconds" -> Missing[]|>|>]|>], <|"Variants" -> 2, "Rounds" -> 1|>];

(* ---- the phase's steps without jobs ---- *)
ctxS = newRun[FileNameJoin[{tmp, "steps"}], Abad, mastersBad];
ctxS = Join[ctxS, <|"State" -> PFBStoreDegrees[ctxS["Dir"], ctxS["State"], 1, Join[tableOf[Abad], <|"Slice" -> ctxS["State"]["Current"]|>]]|>];
stepBudget = PFBSimplifyStep[ctxS, <||>];
stepOver = PFBSimplifyStep[stepBudget["Context"], <|"Budget" -> 5|>];
phaseOver = PFBReadPhase[ctxS["Dir"]];
DeleteFile[FileNameJoin[{ctxS["Dir"], "simplify", "phase.m"}]];
stepTarget = PFBSimplifyStep[Join[ctxS, <|"Run" -> Join[ctxS["Run"], <|"TargetKinDegree" -> 5, "SimplifyBudget" -> 600|>]|>], <||>];

(* ---- E. records and reports, on the run of B with a planted phase ---- *)
ctxR = ctx;
stR = PFBStoreDegrees[ctxR["Dir"], ctxR["State"], 1, Join[tableOf[Abad], <|"Slice" -> ctxR["State"]["Slices"][[1]]["File"]|>]];
stR = PFBStoreDegrees[ctxR["Dir"], stR, Length[stR["Slices"]], Join[tableOf[rescaled[g3 r3]], <|"Slice" -> stR["Current"]|>]];
CreateDirectory[FileNameJoin[{ctxR["Dir"], "simplify"}]];
Put[<|"Created" -> "planted", "Status" -> "done", "Spent" -> 42, "Budget" -> <|"Seconds" -> 300, "Source" -> "run.wl"|>,
   "Start" -> <|"Slice" -> stR["Slices"][[1]]["File"], "Label" -> "planted", "Summary" -> KeyTake[tableOf[Abad]["Summary"], {"Highest", "Count", "Sum", "Unexplained", "Measured", "Sectors"}],
     "Sectors" -> Map[KeyTake[#["Summary"], {"Highest", "Count", "Sum", "Unexplained"}] &, tableOf[Abad]["Sectors"]]|>,
   "Moves" -> {<|"Id" -> 1, "Move" -> "rescale", "Title" -> "global letter rescaling", "Status" -> "accepted", "Message" -> "planted move", "Chosen" -> "ip", "Change" -> gOK["Record"]["Id"],
     "Candidates" -> {<|"Name" -> "ip", "Objective" -> {2, 2, 7}, "MeasuredObjective" -> {2, 1, 6}, "Info" -> <|"Rescalings" -> <|3 -> r3|>|>|>}|>}|>,
  FileNameJoin[{ctxR["Dir"], "simplify", "phase.m"}]];
summaryFile = Quiet@PFBMakeReports[ctxR["Dir"], ctxR["System"], stR];
changesText = Import[FileNameJoin[{ctxR["Dir"], "CHANGES.md"}], "Text"];
summaryText = If[StringQ[summaryFile], Import[summaryFile, "Text"], ""];
exportText = Quiet@Import[FileNameJoin[{ctxR["Dir"], "export", "box.m"}], "Text"];

(* ---- F. moves (ii) to (iv): the worst master, swaps, a move with jobs of its own ---- *)
(* a planted degree table: master 3's row and master 2's column carry degree 6 twice; the sum decides *)
termP[pw_, n_, d_] := <|"Power" -> pw, "Num" -> n, "Den" -> d, "NumLetters" -> <||>, "DenLetters" -> <||>, "NumUnexplained" -> n, "DenUnexplained" -> d|>;
entP[r_, c_, ts_] := <|"Matrix" -> 1, "Derivative" -> t, "Row" -> r, "Column" -> c, "Eps" -> {"Laurent", 0, 1}, "Terms" -> ts|>;
secP[rows_, ents_] := <|"Status" -> "measured", "Source" -> "measured", "Job" -> "planted", "Rows" -> rows, "Entries" -> ents, "Summary" -> PFBDegreeSummary[ents],
   "Probes" -> probes, "JobSectors" -> 1, "JobWallSeconds" -> 10, "JobSeconds" -> 1|>;
tabW = <|"Keys" -> {key1, key2, key3}, "UnitScale" -> s, "Vars" -> {t}, "Provenance" -> <|"Source" -> "measured"|>,
   "Sectors" -> <|key1 -> secP[{1}, {entP[1, 1, {termP[0, 1, 2]}]}], key2 -> secP[{2}, {entP[2, 1, {termP[0, 0, 3]}], entP[2, 2, {termP[1, 1, 1]}]}],
     key3 -> secP[{3}, {entP[3, 1, {termP[0, 4, 2]}], entP[3, 2, {termP[0, 6, 6], termP[1, 2, 6]}], entP[3, 3, {termP[1, 1, 1]}]}]|>|>;
tabW = Join[tabW, <|"Summary" -> PFBDegreeSummary[tabW]|>];
worstW = PFBWorstMasters[tabW];
worstW12 = PFBWorstMasters[tabW, <|"Labels" -> {1, 2}|>];
(* swaps: the box (s t times the box integral) replaced by a dotted box, three candidates planted as in tests/eps_degree.wls:
   new masters J' = M J with the target row R'[[3]] in the new basis, so that a candidate integral reduces to M[[3]] with the
   derivative R'[[3]].M. A gives a row of low degree, B one of high degree, C an entry at eps^3 (above the cap) *)
t0 = 3/7;
RoldS = Together[{{0, 0, 0}, {0, -eps/t, 0}, {-2 (1 - 2 eps)/(t (1 + t)), 2 (1 - 2 eps)/(t^2 (1 + t)), -(1/t + eps/(t (1 + t)))}} /. t -> t0];
rowA = {2 eps/(1 + t), eps/t, -eps/(1 + t)} /. t -> t0;
rowB = {eps (1 + 7 t^9)/(t^4 (1 + t)^5), (3 + 11 t^7)/(t^3 (1 + t)^4), -1/t - 1} /. t -> t0;
rowC = {eps^3, 0, -1/t} /. t -> t0;
lamA = 2 + eps; lamB = 1 - eps; lamC = 3;
Mof[l_] := {{1, 0, 0}, {0, 1, 0}, {0, l, 1}};
redS = <|"Masters" -> {ut[1], ut[2], ut[3]}, "Point" -> P, "Invariants" -> {t}, "Focus" -> {1, 2, 3}, "Dm" -> {RoldS},
   "Pool" -> {j[box, 1, 0, 1, 0], j[box, 0, 1, 0, 1], j[box, 1, 1, 1, 1], j[box, 1, 1, 1, 2], j[box, 1, 1, 2, 1], j[box, 1, 2, 1, 1]},
   "Rp" -> {{1, 0, 0}, {0, 1, 0}, {0, 0, 1/t0}, Mof[lamA][[3]], Mof[lamB][[3]], Mof[lamC][[3]]},
   "dRp" -> {{RoldS[[1]], RoldS[[2]], (RoldS[[3]] - {0, 0, 1/t0})/t0, Together[rowA . Mof[lamA]], Together[rowB . Mof[lamB]], Together[rowC . Mof[lamC]]}}|>;
mastersS = {j[box, 1, 0, 1, 0], j[box, 0, 1, 0, 1], s t j[box, 1, 1, 1, 1]};
ctxSw = newRun[FileNameJoin[{tmp, "swap"}], RoldS, mastersS];
slSw = PFBCurrentSlice[ctxSw["Dir"], ctxSw["State"]];
calSw = PFBCalibrate[slSw, redS];
swapC = PFBSwapCandidates[ctxSw, redS, calSw, key3, 3];
swapC1 = PFBSwapCandidates[ctxSw, redS, calSw, key3, 3, <|"MaxSwaps" -> 1|>];
(* the same box with a lower part in its definition: the box integral alone becomes a candidate *)
ctxLow = newRun[FileNameJoin[{tmp, "swaplow"}], RoldS, {j[box, 1, 0, 1, 0], j[box, 0, 1, 0, 1], s t j[box, 1, 1, 1, 1] + t/s j[box, 0, 1, 0, 1]}];
swapLow = PFBSwapCandidates[ctxLow, redS, PFBCalibrate[PFBCurrentSlice[ctxLow["Dir"], ctxLow["State"]], redS], key3, 3, <|"MaxSwaps" -> 10|>];
heightRow[row_] := PFBDigitHeight[row];
(* the census check on the slice: an entry raised above the cap, an eps-form block lost *)
c0Sw = PFBCensus[ctxSw["System"], slSw];
chkHigh = PFBSimplifySliceCheck[ctxSw["System"], slSw, c0Sw, Join[slSw, <|"R" -> {ReplacePart[RoldS, {3, 1} -> eps^3]}|>]];
chkEps = PFBSimplifySliceCheck[ctxSw["System"], slSw, c0Sw, Join[slSw, <|"R" -> {ReplacePart[RoldS, {2, 2} -> -1/t0]}|>]];
chkOK = PFBSimplifySliceCheck[ctxSw["System"], slSw, c0Sw, Join[slSw, <|"R" -> {ReplacePart[RoldS, {3, 1} -> 5 eps]}|>]];
(* the move on the planted run: the sector's own job calibrates, so it proposes at once *)
CreateDirectory[FileNameJoin[{ctxSw["Dir"], "jobs", "box_j1111"}], CreateIntermediateDirectories -> True];
Put[redS, FileNameJoin[{ctxSw["Dir"], "jobs", "box_j1111", "red_1.m"}]];
movW = PFBMovableMasters[ctxSw, tabW, <|"EpsForm" -> True|>];
swapM = PoleFreeBasis`Simplify`Private`swapMove[ctxSw, tabW, <||>, <|"MoveId" -> 1, "Record" -> None|>];
varInt = PFBDegreeVariant["swap", <|3 -> s^3 j[box, 1, 1, 1, 2]|>];
varUT = PFBDegreeVariant["shift", <|3 -> ut[3] + t ut[2]|>];
(* a planted move with a job of its own: the phase waits for it, counts its time once, then asks the move again *)
fakeMove[cx_, tb_, ph_, op_] := If[op["Record"] === None,
   With[{jd = FileNameJoin[{cx["Dir"], "jobs", "fake_" <> ToString[op["MoveId"]]}]}, CreateDirectory[jd, CreateIntermediateDirectories -> True];
     <|"Status" -> "jobs", "Jobs" -> {jd}, "Keys" -> {key3}, "Prep" -> <|"Stage" -> "planted"|>, "Message" -> "a planted job first"|>],
   <|"Status" -> "no gain", "Message" -> "prepared with " <> ToString[op["Record"]["Prep"]["Stage"]], "Candidates" -> {}|>];
ctxF = newRun[FileNameJoin[{tmp, "fake"}], Abad, mastersBad];
ctxF = Join[ctxF, <|"State" -> PFBStoreDegrees[ctxF["Dir"], ctxF["State"], 1, Join[tableOf[Abad], <|"Slice" -> ctxF["State"]["Current"]|>]]|>];
fakeMoves = {<|"Name" -> "fake", "Title" -> "a planted move", "Propose" -> fakeMove|>};
stepF1 = Block[{$PFBSimplifyMoves = fakeMoves}, PFBSimplifyStep[ctxF, <|"Budget" -> 600|>]];
phF1 = PFBReadPhase[ctxF["Dir"]];
stepF2 = Block[{$PFBSimplifyMoves = fakeMoves}, PFBSimplifyStep[stepF1["Context"], <||>]];
Put[<|"Status" -> "done", "Seconds" -> 7|>, FileNameJoin[{ctxF["Dir"], "jobs", "fake_1", "status.m"}]];
stepF3 = Block[{$PFBSimplifyMoves = fakeMoves}, PFBSimplifyStep[stepF2["Context"], <||>]];
phF3 = PFBReadPhase[ctxF["Dir"]];
DeleteFile[FileNameJoin[{ctxF["Dir"], "simplify", "phase.m"}]];
stepUnknown = PFBSimplifyStep[ctxF, <|"Budget" -> 600, "Moves" -> {"nonexistent"}|>];
stepNone = PFBSimplifyStep[ctxF, <|"Budget" -> 600, "Moves" -> {}|>];

(* ---- G. move (iii): shifts by lower masters, fitted from planted samples ---- *)
(* four planted masters of the box family: the two bubbles, a triangle (j1110, over the s-bubble) and the box. Bsh is a
   planted DE of low degree (d/dt); A1 is the DE after the triangle is shifted by the s-bubble with the constant c = 3/s,
   A = T B T^-1 + dT T^-1 *)
key4 = {box, {1, 1, 1, 0}};
Bsh = {{0, 0, 0, 0}, {0, -eps/t, 0, 0}, {2/(s + t), 0, -eps/(s + t) - 1/t, 0}, {1/(s t), eps/t, eps/t, -eps/(s + t)}};
shifted[B_, c_, i_, k_] := With[{T = ReplacePart[IdentityMatrix[Length[B]], {i, k} -> c]}, Together[T . B . Inverse[T] + D[T, t] . Inverse[T]]];
A1 = shifted[Bsh, 3/s, 3, 1];
entriesOfN[A_, rows_] := Flatten[Table[With[{f = Together[A[[r, c]] /. s -> 1]}, If[f === 0, {},
     With[{rg = PFBEpsRange[f]}, {<|"Matrix" -> 1, "Derivative" -> t, "Row" -> r, "Column" -> c, "Eps" -> {"Laurent", rg[[1]], rg[[2]]},
       "Terms" -> Table[With[{cf = Together[SeriesCoefficient[f, {eps, 0, pw}]]}, If[cf === 0, Nothing, termOf[cf, pw]]], {pw, rg[[1]], rg[[2]]}]|>}]]], {r, rows}, {c, Length[A]}], 2];
tableOf4[A_] := Module[{rec, tb}, rec[rows_] := With[{ents = entriesOfN[A, rows]}, <|"Status" -> "measured", "Source" -> "measured", "Job" -> "planted", "Rows" -> rows,
      "Entries" -> ents, "Summary" -> PFBDegreeSummary[ents], "Probes" -> probes, "JobSectors" -> 1, "JobWallSeconds" -> 10, "JobSeconds" -> 1|>];
  tb = <|"Keys" -> {key1, key2, key4, key3}, "UnitScale" -> s, "Vars" -> {t}, "Provenance" -> <|"Source" -> "measured"|>,
    "Sectors" -> <|key1 -> rec[{1}], key2 -> rec[{2}], key4 -> rec[{3}], key3 -> rec[{4}]|>|>;
  Join[tb, <|"Summary" -> PFBDegreeSummary[tb]|>]];
newRunN[dir_, A_, masters_] := Module[{ctx, sl, st, n = Length[masters]},
  CreateDirectory[dir, CreateIntermediateDirectories -> True];
  Put[masters, FileNameJoin[{dir, "masters.m"}]];
  Put[<|"Name" -> "planted", "Families" -> {<|"Name" -> "box", "Family" -> boxFile, "Masters" -> "masters.m"|>}, "Letters" -> {s, t, s + t}|>, FileNameJoin[{dir, "system.wl"}]];
  Put[<|"System" -> "system.wl", "OutputDir" -> FileNameJoin[{dir, "run"}], "AllowTmp" -> True, "Paths" -> Automatic|>, FileNameJoin[{dir, "run.wl"}]];
  ctx = PFBStartRun[FileNameJoin[{dir, "run.wl"}]];
  sl = <|"R" -> {Together[A /. P]}, "Derivatives" -> {t}, "Point" -> P, "Labels" -> Range[n], "Index" -> AssociationThread[Range[n] -> Range[n]], "Frame" -> "RootFree", "History" -> {}|>;
  st = PFBStoreSlice[ctx["Dir"], ctx["State"], sl, PFBCensus[ctx["System"], sl], "planted"];
  Join[ctx, <|"State" -> st|>]];
(* the samples a fit's job would write: the exact rows at the problem's points, unit scale 1 *)
samplesOf[A_, pr_] := <|"Status" -> "sampled", "Rows" -> pr["JobRows"], "Columns" -> Range[Length[A]],
   "Samples" -> Table[<|"Point" -> pt, "Values" -> <|"Base" -> {Table[A[[r, c]] /. s -> 1 /. pt, {r, pr["JobRows"]}, {c, Length[A]}]}|>|>, {pt, pr["Points"]}]|>;
(* a planted fit job: its samples, its reduction at the slice point (rows of the job's masters) and its status *)
plantFitJob[cx_, A_, pr_, name_] := Module[{jd = FileNameJoin[{cx["Dir"], "jobs", name}], ms = Union[pr["JobRows"], pr["Lower"]]},
  CreateDirectory[jd, CreateIntermediateDirectories -> True];
  Put[Join[samplesOf[A, pr], <|"Columns" -> (ut /@ Range[Length[A]])|>], FileNameJoin[{jd, "degrees.m"}]];
  Put[<|"Masters" -> (ut /@ ms), "Point" -> P, "Invariants" -> {t}, "Focus" -> pr["JobRows"], "Dm" -> {Together[A[[pr["JobRows"], ms]] /. P]}, "Pool" -> {}, "Rp" -> {}, "dRp" -> {{}}|>,
    FileNameJoin[{jd, "red_1.m"}]];
  Put[<|"Status" -> "done", "Seconds" -> 3|>, FileNameJoin[{jd, "status.m"}]];
  jd];
masters4 = {j[box, 1, 0, 1, 0], j[box, 0, 1, 0, 1], j[box, 1, 1, 1, 0] + 3/s j[box, 1, 0, 1, 0], j[box, 1, 1, 1, 1]};
ctxG = newRunN[FileNameJoin[{tmp, "shift"}], A1, masters4];
tabA1 = tableOf4[A1];
probA1 = PFBShiftProblem[ctxG, tabA1, 3];
fitA1 = PFBShiftFit[probA1, samplesOf[A1, probA1]];
jdA1 = plantFitJob[ctxG, A1, probA1, "simp1_fit_box_j1110"];
shiftA1 = PoleFreeBasis`Simplify`Private`shiftMove[ctxG, tabA1, <||>, <|"MoveId" -> 1, "Record" -> <|"Prep" -> <|"Problem" -> probA1, "Job" -> jdA1|>|>|>];
TA1 = If[shiftA1["Candidates"] =!= {}, shiftA1["Candidates"][[1]]["T"], <||>];
slA1 = PoleFreeBasis`Simplify`Private`sliceAfter[ctxG["System"], PFBCurrentSlice[ctxG["Dir"], ctxG["State"]], TA1];
(* the gate with planted measured degrees: the shift undone *)
gShift = PFBTryChange[ctxG, None, TA1, <|"Rung" -> "simplify", "Name" -> "planted shift", "Provenance" -> "planted",
    "Simplify" -> <|"MoveId" -> 1, "Move" -> "shift", "Candidate" -> "shift1"|>|>,
  degs[KeyTake[PFBDegreeSummary[entriesOfN[A1, Range[4]]], {"Highest", "Count", "Sum", "Terms"}], KeyTake[PFBDegreeSummary[entriesOfN[Bsh, Range[4]]], {"Highest", "Count", "Sum", "Terms"}]]];
(* no shift helps the planted low-degree DE: the box's row keeps a term of degree 1 at eps^1 *)
ctxB = newRunN[FileNameJoin[{tmp, "noshift"}], Bsh, {j[box, 1, 0, 1, 0], j[box, 0, 1, 0, 1], j[box, 1, 1, 1, 0], j[box, 1, 1, 1, 1]}];
tabB = tableOf4[Bsh];
probB = PFBShiftProblem[ctxB, tabB, 4];
fitB = PFBShiftFit[probB, samplesOf[Bsh, probB]];
(* a shift that lowers the triangle's row but puts eps^3 into the box's row: the triangle carries eps, so c = eps t^2 ...,
   and the box row couples to it at eps^2 *)
cBreak = 3 eps t^2/s^3;
B2 = ReplacePart[Bsh, {{4, 3} -> eps^2/t, {4, 1} -> 1/(s t) + eps^2/t cBreak}];
A2 = shifted[B2, cBreak, 3, 1];
ctxK = newRunN[FileNameJoin[{tmp, "break"}], A2, {j[box, 1, 0, 1, 0], j[box, 0, 1, 0, 1], eps j[box, 1, 1, 1, 0] + cBreak j[box, 1, 0, 1, 0], j[box, 1, 1, 1, 1]}];
tabA2 = tableOf4[A2];
probA2 = PFBShiftProblem[ctxK, tabA2, 3];
shiftA2 = PoleFreeBasis`Simplify`Private`shiftMove[ctxK, tabA2, <||>, <|"MoveId" -> 1, "Record" -> <|"Prep" -> <|"Problem" -> probA2, "Job" -> plantFitJob[ctxK, A2, probA2, "simp1_fit"]|>|>|>];
(* the caps *)
probSmall = PFBShiftProblem[ctxG, tabA1, 3, <|"MaxSamples" -> 10|>];
probFew = PFBShiftProblem[ctxG, tabA1, 3, <|"MaxUnknowns" -> 2|>];
probNone = PFBShiftProblem[ctxG, tabA1, 3, <|"MaxUnknowns" -> 0|>];
costFit = {PFBFitJobCost[tabA1, key4, 140], PFBFitJobCost[tabA1, key4, 1000], PFBFitJobCost[tabA1, {box, {1, 1, 0, 0}}, 140]};

(* ---- H. move (iv): a completion solved again with degree as the objective ---- *)
(* the box completed by a dotted t-bubble w = j[box,0,2,0,1], planted to reduce to rho U2 with rho = (1 - 2 eps)/t: the
   heavier completion has the coefficient 2 t^3/s^4 on w, the lighter one none, and its DE is the bare one (Abare) *)
wC = j[box, 0, 2, 0, 1]; rhoC = (1 - 2 eps)/t; Cold = 2 t^3/s^4;
def3C = j[box, 1, 1, 1, 1] + Cold wC;
cC = Cold rhoC;
TC = {{1, 0, 0}, {0, 1, 0}, {0, cC, 1}};
AC = Together[TC . Abare . Inverse[TC] + D[TC, t] . Inverse[TC]];
compRec = <|"Id" -> 1, "Key" -> key3, "Name" -> "planted completion", "Kind" -> "change", "Replace" -> {3}, "NewDefs" -> <|3 -> def3C|>, "OldDefs" -> <|3 -> j[box, 1, 1, 1, 1]|>,
   "Rung" -> 6, "RungName" -> "completion"|>;
ctxC = newRun[FileNameJoin[{tmp, "completion"}], AC, {j[box, 1, 0, 1, 0], j[box, 0, 1, 0, 1], def3C}];
ctxC = Join[ctxC, <|"State" -> PFBSaveState[ctxC["Dir"], Join[ctxC["State"], <|"Accepted" -> {compRec}|>]]|>];
tabC = tableOf[AC];
compsC = PFBCompletedMasters[ctxC];
compsOther = PFBCompletedMasters[Join[ctxC, <|"State" -> Join[ctxC["State"], <|"Accepted" -> {Join[compRec, <|"NewDefs" -> <|3 -> j[box, 1, 1, 1, 1] + t/s^2 wC|>|>]}|>]|>]];
probC = PFBCompletionProblem[ctxC, tabC, First[compsC]];
(* the samples of the fit's job, and its reduction at the slice point with the pool *)
samplesC[pr_] := <|"Status" -> "sampled", "Rows" -> {3}, "Columns" -> {1, 2, 3}, "Samples" -> Table[<|"Point" -> pt, "Values" -> <|"Base" -> {AC[[{3}]] /. s -> 1 /. pt},
      "Exprs" -> ({{0, rhoC, 0}} /. s -> 1 /. pt), "DExprs" -> ({{{0, D[rhoC, t] + rhoC Abare[[2, 2]], 0}}} /. s -> 1 /. pt)|>|>, {pt, pr["Points"]}]|>;
fitC = PFBCompletionFit[probC, samplesC[probC]];
redC = <|"Masters" -> {ut[1], ut[2], ut[3]}, "Point" -> P, "Invariants" -> {t}, "Focus" -> {3}, "Dm" -> {Together[AC[[{3}]] /. P]}, "Pool" -> {j[box, 1, 1, 1, 1], wC},
   "Rp" -> Together[{{0, -cC, 1}, {0, rhoC, 0}} /. P], "dRp" -> {Together[{AC[[3]] - {0, D[cC, t] + cC Abare[[2, 2]], 0}, {0, D[rhoC, t] + rhoC Abare[[2, 2]], 0}} /. P]}|>;
jdC = FileNameJoin[{ctxC["Dir"], "jobs", "simp1_comp_box_j1111"}];
CreateDirectory[jdC, CreateIntermediateDirectories -> True];
Put[Join[samplesC[probC], <|"Columns" -> {ut[1], ut[2], ut[3]}|>], FileNameJoin[{jdC, "degrees.m"}]];
Put[redC, FileNameJoin[{jdC, "red_1.m"}]];
Put[<|"Status" -> "done", "Seconds" -> 4|>, FileNameJoin[{jdC, "status.m"}]];
compM = PoleFreeBasis`Simplify`Private`compMove[ctxC, tabC, <||>, <|"MoveId" -> 1, "Record" -> <|"Prep" -> <|"Problem" -> probC, "Job" -> jdC|>|>|>];
defsC = If[compM["Candidates"] =!= {}, compM["Candidates"][[1]]["Defs"], <||>];
slC = Module[{sl0 = PFBCurrentSlice[ctxC["Dir"], ctxC["State"]], ch}, ch = PFBChangeVectors[ctxC["System"], sl0, redC, PFBCalibrate[sl0, redC], defsC];
   If[ch === $Failed, $Failed, PFBApplyChange[sl0, ch]]];
gComp = PFBTryChange[ctxC, None, defsC, <|"Rung" -> "simplify", "Name" -> "planted lighter completion", "Provenance" -> "planted",
    "Simplify" -> <|"MoveId" -> 1, "Move" -> "completion", "Candidate" -> "completion1"|>|>,
  Join[degs[KeyTake[tabC["Summary"], {"Highest", "Count", "Sum", "Terms"}], KeyTake[PFBDegreeSummary[entriesOf[Abare, {1, 2, 3}]], {"Highest", "Count", "Sum", "Terms"}]], <|"Reds" -> {redC}|>]];
compNone = PoleFreeBasis`Simplify`Private`compMove[ctxSw, tabW, <||>, <|"MoveId" -> 1, "Record" -> None|>];
probCsmall = PFBCompletionProblem[ctxC, tabC, First[compsC], <|"MaxSamples" -> 10|>];

tests = {
  (* A *)
  VerificationTest[{pre1["Pass"], pre1["Sectors"], StringContainsQ[First[pre1["Reasons"]], {"box/j1111", "finite poles"}]}, {False, {key3}, True},
    TestID -> "precondition: a bad entry outside flagged sectors refuses the phase"],
  VerificationTest[{pre2["Pass"], pre2["Flagged"]}, {True, {key3}}, TestID -> "precondition: bad entries in flagged sectors only"],
  VerificationTest[{pre3["Pass"], StringContainsQ[First[pre3["Reasons"]], "approval"]}, {False, True}, TestID -> "precondition: another change waits for approval"],
  VerificationTest[{stepPole["Outcome"], StringContainsQ[stepPole["Message"], "cannot start"]}, {"refused", True}, TestID -> "step: refused with the reason"],
  (* B *)
  VerificationTest[{PFBObjectiveLess[{2, 1, 6}, {2, 2, 7}], PFBObjectiveLess[{2, 2, 7}, {2, 2, 7}], PFBObjectiveLess[{-Infinity, 0, 0}, {0, 1, 0}], PFBObjectiveLess[{3, 1, 1}, {2, 9, 99}],
      PFBObjectiveLess[{2, 3, 5}, {2, 3, 6}]}, {True, False, True, False, True}, TestID -> "objective: lexicographic {highest, count, sum}"],
  VerificationTest[{PFBDegreeObjective[before], PFBDegreeObjective[after], objExact[rescaled[g3 r3]]}, {{5, 2, 23}, {2, 1, 6}, {2, 1, 6}},
    TestID -> "planted degrees: the bad normalisation and its undoing, by hand"],
  VerificationTest[{gNoDrop["Status"], failed[gNoDrop]}, {"rejected", {"kinematic degrees"}}, TestID -> "gate: no drop of the measured objective is refused"],
  VerificationTest[{gNoMeas["Status"], failed[gNoMeas]}, {"rejected", {"kinematic degrees"}}, TestID -> "gate: a simplification without measured degrees is refused"],
  VerificationTest[{gDim["Status"], MemberQ[failed[gDim], "weights"]}, {"rejected", True}, TestID -> "gate: a rescaling that changes the mass dimension is refused"],
  VerificationTest[{gEps["Status"], MemberQ[failed[gEps], "eps-form blocks"]}, {"rejected", True}, TestID -> "gate: a rescaling that breaks an eps-form block is refused"],
  VerificationTest[gKey["Status"], "not tried", TestID -> "gate: a change without a sector key needs rung simplify"],
  VerificationTest[{gOK["Status"], MemberQ[appr["State"]["Accepted"][[All, "Id"]], gOK["Record"]["Id"]], recOK["Rung"], recOK["RungName"], recOK["Simplify"]["Candidate"]},
    {"pending", True, "simplify", "simplify", "ip"}, TestID -> "gate: a measured drop passes; pending in approval mode, then accepted"],
  VerificationTest[{Together[slAfter["R"][[1]] - (rescaled[g3 r3] /. P)], Together[recOK["NewDefs"][3] - r3 g3 j[box, 1, 1, 1, 1]], recOK["MaxCutChanged"],
      Lookup[SelectFirst[recOK["Gate"], #["Name"] === "census" &], "Pass"]},
    {ConstantArray[0, {3, 3}], 0, False, True}, TestID -> "gate: the new slice is the hand DE of the rescaled basis, the definition is in integrals"],
  (* C *)
  VerificationTest[{model["Free"], StringContainsQ[model["Protected"][1], "zero"], StringContainsQ[model["Protected"][2], "eps-form"], Sort[model["Allowed"][3]], model["UnitLetter"][3]},
    {{3}, True, True, Sort[{t, 1 + t}], True}, TestID -> "model: eps-form and zero blocks left alone, the letters near the box"],
  VerificationTest[{modelE["Free"], StringContainsQ[Lookup[modelE["Protected"], 3, ""], "no eps^0 term"]}, {{}, True},
    TestID -> "model: a master whose row has no eps^0 term is left alone (its rescaling would lower the row's eps structure)"],
  VerificationTest[PFBPredictDegrees[model, <||>]["Objective"], {5, 2, 23}, TestID -> "model: no rescaling predicts the measured objective"],
  VerificationTest[{sol["Exponents"], sol["Units"], sol["Objective"], bruteBad, Lookup[sol["Program"], "Status", None]},
    {<|3 -> <|t -> 2, 1 + t -> 2|>|>, <|3 -> -4|>, {2, 2, 7}, {2, 2, 7}, "solved"}, TestID -> "program: the planted bad normalisation is undone, as a brute force finds", SameTest -> sameA],
  VerificationTest[Union[Flatten[predVsExact]], {True}, TestID -> "prediction: exact off the diagonal, a bound on it, for every exponent in the bounds"],
  VerificationTest[{Lookup[cands, "Name"], Together[cands[[1]]["Rescalings"][3] - r3], MaximalCutBasis`Rules`MCBWeightOf[PFBFamily[sys, box], cands[[1]]["Rescalings"][3]],
      cands[[1]]["T"]}, {{"ip"}, 0, 0, <|3 -> r3 ut[3]|>}, TestID -> "candidates: the rescaling keeps the mass dimension (unit-scale power)"],
  VerificationTest[{solG["Exponents"], solG["Objective"], modelG["Current"], candsG, moveG["Status"]}, {<||>, {2, 1, 6}, {2, 1, 6}, {}, "no gain"},
    TestID -> "program: no rescaling can help an optimal basis"],
  VerificationTest[{solOdd["Exponents"], solOdd["Units"], solOdd["Objective"]}, {<|1 -> <|w -> 2|>|>, <|1 -> -1|>, {1, 1, 1}},
    TestID -> "program: a letter of odd dimension only in even powers"],
  VerificationTest[{solOddNoUnit["Exponents"], solOddNoUnit["Objective"]}, {<||>, {2, 1, 3}}, TestID -> "program: no unit scale in a denominator when it is no letter"],
  VerificationTest[{Keys[norm3], Factor[norm3[3]["Ratio"]], norm2, normNone}, {{3}, Factor[t^2 (s + t)/s], <||>, <||>},
    TestID -> "maximal-cut-basis: rational normalisations of the run, square roots and missing runs skipped"],
  VerificationTest[{modelMCB["Initial"], Lookup[candsMCB, "Name"], Together[SelectFirst[candsMCB, #["Name"] === "mcb" &]["Rescalings"][3] - t^2 (s + t)/s^3]},
    {<|3 -> <|t -> 2, 1 + t -> 1|>|>, {"ip", "mcb"}, 0}, TestID -> "maximal-cut-basis: its normalisation is a candidate, made dimensionless", SameTest -> sameA],
  (* D *)
  VerificationTest[{bud["Round"], bud["Seconds"], bud["Untimed"], Length[bud["PerSector"]]}, {114, 342, {}, 3}, TestID -> "budget: rounds of job time plus variant measurements"],
  VerificationTest[{bud2["Round"], bud2["Seconds"], bud2["Untimed"]}, {56, 56, {key3}}, TestID -> "budget: a sector without a job time is not counted"],
  VerificationTest[{stepBudget["Outcome"], stepBudget["Proposal"]["Seconds"], StringContainsQ[stepBudget["Message"], "--budget proposed"]}, {"budget", 3 (11 + 4 + 12 + 4 + 20 + 8), True},
    TestID -> "step: the budget is proposed and the phase waits for the user"],
  VerificationTest[{stepOver["Outcome"], phaseOver["Budget"]["Seconds"], phaseOver["Moves"][[1]]["Status"], phaseOver["Moves"][[1]]["Candidates"][[1]]["Objective"],
      phaseOver["Start"]["Summary"]["Highest"]}, {"done", 5, "over budget", {2, 2, 7}, 5}, TestID -> "step: a move whose measurement exceeds the budget stops the phase"],
  VerificationTest[{stepTarget["Outcome"], StringContainsQ[stepTarget["Message"], "target"], PFBReadPhase[ctxS["Dir"]]["Moves"]}, {"done", True, {}},
    TestID -> "step: TargetKinDegree stops the phase before any move"],
  (* F *)
  VerificationTest[{Lookup[worstW, "Label"], Lookup[worstW, "Objective"], Lookup[worstW, "Side"], Lookup[worstW[[1]]["Worst"], {"Row", "Column", "Power"}]},
    {{3, 2, 1}, {{6, 2, 17}, {6, 2, 16}, {4, 1, 9}}, {"row", "column", "column"}, {{3, 2, 0}, {3, 2, 1}}}, TestID -> "worst master: row and column terms, the sum decides a tie"],
  VerificationTest[Lookup[worstW12, "Label"], {2, 1}, TestID -> "worst master: only the masters asked for"],
  VerificationTest[{PFBDigitHeight[123/45 eps + 7], PFBDigitHeight[{0, 1, {2 eps}}], PFBDigitHeight[rowA] < PFBDigitHeight[rowB]}, {10, 8, True},
    TestID -> "digit height: digits of the coefficients in eps"],
  VerificationTest[{chkHigh["Pass"], StringContainsQ[First[chkHigh["Reasons"]], "above eps^2"], chkEps["Pass"], StringContainsQ[StringRiffle[chkEps["Reasons"]], "eps-form blocks"], chkOK["Pass"]},
    {False, True, False, True, True}, TestID -> "slice check: an entry above the cap, a lost eps-form block"],
  VerificationTest[{calSw["Status"], swapC["Sets"], swapC["Clear"], swapC["Passed"], Length[swapC["Candidates"]]}, {"exact", 4, 3, 5, 3},
    TestID -> "swaps: the sets that clear the rows and keep the census (the box itself rescaled too), the one above the cap is not a swap"],
  VerificationTest[{Lookup[swapC["Candidates"], "Integrals"], OrderedQ[Lookup[swapC["Candidates"], "Height"]], swapC["Candidates"][[2]]["Height"] < swapC["Candidates"][[3]]["Height"]},
    {{<|3 -> j[box, 1, 1, 1, 2]|>, <|3 -> j[box, 1, 1, 1, 2]|>, <|3 -> j[box, 1, 1, 2, 1]|>}, True, True}, TestID -> "swaps: the low-degree set first, by digit height"],
  VerificationTest[{Sort[Lookup[swapC["Candidates"][[;; 2]], "Normalisation"][[All, 1]]], Sort[Together[Lookup[swapC["Candidates"][[;; 2]], "Set"][[All, 1]]]], swapC["Candidates"][[1]]["Det"] =!= 0},
    {{"inherit", "unit"}, Sort[Together[{s^3 j[box, 1, 1, 1, 2], s^2 t j[box, 1, 1, 1, 2]}]], True}, TestID -> "swaps: the mass dimension kept by the unit scale, or the master's own coefficient"],
  VerificationTest[{Length[swapC1["Candidates"]], swapC1["Candidates"][[1]]["Integrals"]}, {1, <|3 -> j[box, 1, 1, 1, 2]|>}, TestID -> "swaps: only the best few are kept"],
  VerificationTest[{MemberQ[Lookup[swapLow["Candidates"], "Set"], <|3 -> s t j[box, 1, 1, 1, 1]|>], MemberQ[Lookup[swapC["Candidates"], "Set"], <|3 -> s t j[box, 1, 1, 1, 1]|>]}, {True, False},
    TestID -> "swaps: a master with a lower part may be swapped for its own integral alone"],
  VerificationTest[{movW["Free"], Sort[Keys[movW["Protected"]]]}, {{3}, {1, 2}}, TestID -> "movable masters: eps-form and zero blocks left alone for a swap"],
  VerificationTest[{swapM["Status"], Lookup[swapM["Candidates"], "Name"], FileNameTake[swapM["Candidates"][[1]]["RedJob"]], Keys[swapM["Candidates"][[1]]["T"]], swapM["Info"]["Master"]},
    {"proposed", {"swap1", "swap2", "swap3"}, "box_j1111", {3}, 3}, TestID -> "move (ii): the worst master's swaps, with the sector's job for the gate"],
  VerificationTest[{varInt["TInverse"], varInt["T"], varUT["TInverse"]}, {Automatic, <|3 -> s^3 j[box, 1, 1, 1, 2]|>, <|3 -> ut[3] - t ut[2]|>},
    TestID -> "variant: new masters in integrals are inverted inside the job"],
  VerificationTest[{stepF1["Outcome"], phF1["Moves"][[1]]["Status"], FileNameTake /@ phF1["Moves"][[1]]["PrepJobs"], stepF2["Outcome"]},
    {"jobs", "preparing", {"fake_1"}, "jobs"}, TestID -> "phase: a move with a job of its own waits for it"],
  VerificationTest[{stepF3["Outcome"], phF3["Moves"][[1]]["Status"], phF3["Moves"][[1]]["Message"], phF3["Spent"], phF3["Moves"][[1]]["PrepSpent"], Length[phF3["Moves"]]},
    {"done", "no gain", "prepared with planted", 7, 7, 1}, TestID -> "phase: then the move is asked again, its job's time spent once"],
  VerificationTest[{stepUnknown["Outcome"], StringContainsQ[stepUnknown["Message"], "unknown moves"], stepNone["Outcome"], PFBReadPhase[ctxF["Dir"]]["Moves"]},
    {"refused", True, "done", {}}, TestID -> "phase: the moves named by SimplifyMoves"],
  (* G *)
  VerificationTest[{AssociationQ[probA1], probA1["Lower"], probA1["EpsPowers"], probA1["Start"], probA1["Columns"], probA1["Range"], probA1["Taus"], Length[probA1["Eps"]],
      Length[probA1["Points"]] == (probA1["FitLines"] + 1) probA1["Taus"] Length[probA1["Eps"]]},
    {True, {1}, <|1 -> 0|>, 1, {1}, {0, 2}, 5, 4, True}, TestID -> "shift: the problem (lower masters, powers of eps, target, samples)"],
  VerificationTest[{fitA1["Status"], Lookup[fitA1["Solutions"], "Target"], Together[fitA1["Best"]["Coefficients"][1] + 3/s]}, {"solved", {1}, 0},
    TestID -> "shift: the fit recovers the planted constant shift from samples, and goes no lower"],
  VerificationTest[{shiftA1["Status"], Lookup[shiftA1["Candidates"], "Name"], Together[TA1[3] - (ut[3] - 3/s ut[1])], Together[slA1["R"] - {Bsh /. P}]},
    {"proposed", {"shift1"}, 0, {ConstantArray[0, {4, 4}]}}, TestID -> "move (iii): the candidate undoes the shift exactly on the slice"],
  VerificationTest[{gShift["Status"], Together[gShift["Record"]["NewDefs"][3] - j[box, 1, 1, 1, 0]], failed[gShift]}, {"accepted", 0, {}},
    TestID -> "move (iii): the gate accepts it, the definition back in integrals"],
  VerificationTest[{AssociationQ[probB], probB["Lower"], probB["Start"], fitB["Status"]}, {True, {1, 2, 3}, 0, "no solution"}, TestID -> "shift: no shift lowers a low-degree row"],
  VerificationTest[{probA2["EpsPowers"], shiftA2["Status"], StringContainsQ[shiftA2["Message"], "refused on the slice"], StringContainsQ[StringRiffle[Flatten[Lookup[shiftA2["Info"]["Refused"], "Reasons"]]], "above eps^2"],
      Together[shiftA2["Info"]["Refused"][[1]]["Coefficients"][1] + cBreak]},
    {<|1 -> 1|>, "no gain", True, True, 0}, TestID -> "move (iii): a shift that puts eps^3 into a row above is refused"],
  VerificationTest[{StringQ[probSmall] && StringContainsQ[probSmall, "samples"], Lookup[probFew, {"Degree", "Letters"}], Length[probFew["Unknowns"]], Length[probA1["Unknowns"]] > 2,
      StringQ[probNone] && StringContainsQ[probNone, "unknowns"]}, {True, {1, False}, 2, True, True}, TestID -> "shift: the caps on samples and unknowns"],
  VerificationTest[costFit, {12, 20, 0}, TestID -> "fit job: its cost estimated from the census job, a measurement per 100 samples"],
  (* H *)
  VerificationTest[{compsC, compsOther}, {{<|"Change" -> 1, "Key" -> key3, "Labels" -> {3}|>}, {}}, TestID -> "completion: the masters a completion wrote and no later change replaced"],
  VerificationTest[{AssociationQ[probC], probC["Exprs"], probC["Corrections"], probC["Range"], Length[probC["Unknowns"]], probC["LowerColumns"]},
    {True, {wC}, <|3 -> {{wC, Cold, 0}}|>, {0, 2}, 4, {1, 2}}, TestID -> "completion: the problem (correction integrals, the old coefficient in the ansatz)"],
  VerificationTest[{fitC["Status"], fitC["Columns"], Together[fitC["Best"]["Corrections"][3][wC] + Cold]}, {"solved", {2}, 0},
    TestID -> "completion: the fit finds the lighter completion from samples of the reductions"],
  VerificationTest[{compM["Status"], Lookup[compM["Candidates"], "Name"], defsC, FileNameTake[compM["Candidates"][[1]]["RedJob"]], Together[slC["R"] - {Abare /. P}]},
    {"proposed", {"completion1"}, <|3 -> j[box, 1, 1, 1, 1]|>, "simp1_comp_box_j1111", {ConstantArray[0, {3, 3}]}}, TestID -> "move (iv): the candidate drops the correction, exactly on the slice"],
  VerificationTest[{gComp["Status"], Together[gComp["Record"]["NewDefs"][3] - j[box, 1, 1, 1, 1]], failed[gComp]}, {"accepted", 0, {}},
    TestID -> "move (iv): the gate accepts the lighter completion with the job's reduction"],
  VerificationTest[{compNone["Status"], StringContainsQ[compNone["Message"], "no master comes from a completion"], StringQ[probCsmall] && StringContainsQ[probCsmall, "samples"]},
    {"no gain", True, True}, TestID -> "move (iv): nothing to do without a completion; the cap on samples"],
  (* E *)
  VerificationTest[StringContainsQ[changesText, {"## Kinematic degrees", "| starting degrees | planted | 5 | 2 | 23", "| after the pole-free work | planted | 5 | 2 | 23",
      "| after the simplification phase |", "| 2 | 1 | 6 |", "### Simplification phase", "Move 1 (global letter rescaling): accepted", "candidate ip: predicted {2, 2, 7}, measured {2, 1, 6}"}, IgnoreCase -> False],
    True, TestID -> "CHANGES.md: the degrees by stage and the phase's moves"],
  VerificationTest[{StringContainsQ[changesText, "Simplification (global letter rescaling, phase move 1, candidate ip): kinematic degrees {highest, terms at it, sum} {5, 2, 23} -> {2, 1, 6}"],
      StringContainsQ[changesText, "| `box/j1111` | {5, 2, 22} | {2, 1, 5} | 0 |"]}, {True, True}, TestID -> "CHANGES.md: the change's degrees, and the unexplained degree per sector"],
  VerificationTest[StringContainsQ[summaryText, {"Degrees by stage", "after the simplification phase", "Simplification phase", "global letter rescaling"}], True,
    TestID -> "summary.html: the degrees by stage and the phase"],
  VerificationTest[StringQ[exportText] && StringContainsQ[exportText, "changed"], True, TestID -> "export: the rescaled family's masters"]
};

report = TestReport[tests];
Do[With[{r = report["TestResults"][id]},
    Print[If[r["Outcome"] === "Success", "PASS ", "FAIL "], r["TestID"], If[r["Outcome"] === "Success", "",
      "\n     got " <> ToString[Short[r["ActualOutput"], 6], InputForm] <> "\n     expected " <> ToString[Short[r["ExpectedOutput"], 6], InputForm]]]],
  {id, Keys[report["TestResults"]]}];
Print[report["TestsSucceededCount"], " passed, ", report["TestsFailedCount"], " failed, ", Round[report["TimeElapsed"], 0.1]];
Quiet[DeleteDirectory[tmp, DeleteContents -> True]];
Exit[If[report["AllTestsSucceeded"], 0, 1]];
