#!/usr/bin/env wolframscript
(* What the simplification phase reads from the pole-free work, without FiniteFlow or IBP. Planted data: the one-loop
   massless box of the maximal-cut-basis examples (unit scale s, letters s, t, s + t, derivative d/dt), its DE with a
   planted pole 1/(1 + 4 eps) in the box's row, in the column of the s-bubble only (the census's hidden-weight hint on
   that clean sector), and a planted maximal-cut-basis run folder with a rational element of the box sector.
   Checked: the rational normalisations come from the family's "MCBRun" as PFBReadSystem resolved it (the field that
   PFBValidateSystem checks and rung 8 reads), not from the raw entry; the phase's precondition with a hidden-weight
   hint (no block; the untried hint is returned and said, also on a sector fixed by an accepted change, which the hint
   reopens; a tried one, or one on a flagged sector, is not)
   and with a bad sector that is not flagged (refused, the control).
   usage: bin/ws tests/simplify_inputs.wls        exit code 0 when every test passes *)
Get[FileNameJoin[{ParentDirectory[DirectoryName[$InputFileName]], "lib", "PoleFreeBasis.wl"}]];
$PFBVerbose = False;
boxFile = FileNameJoin[{ParentDirectory[$PFBRoot], "maximal-cut-basis", "examples", "box-one-loop", "family.wl"}];
key3 = {box, {1, 1, 1, 1}}; key2 = {box, {0, 1, 0, 1}}; key1 = {box, {1, 0, 1, 0}};
P = {s -> 1, t -> 3/7};
w = 1 + 4 eps;
(* the box's DE in the basis {I_s-bubble, I_t-bubble, s t I_box}, with 1/w put into the box row's s-bubble column *)
A = {{0, 0, 0}, {0, -eps/t, 0}, {-2 (1 - 2 eps)/(w s t (s + t)), 2 (1 - 2 eps)/(t^2 (s + t)), -(1/t + eps s/(t (s + t)))}};
masters = {j[box, 1, 0, 1, 0], j[box, 0, 1, 0, 1], s t j[box, 1, 1, 1, 1]};
tmp = CreateDirectory[];
(* a planted maximal-cut-basis run next to the run's system.wl: the box sector's element eps^2 s^2 t j[box, 1, 1, 1, 1],
   rational (s times the box master on the maximal cut) *)
mcbDir = FileNameJoin[{tmp, "mcb", "mcbrun"}];
CreateDirectory[FileNameJoin[{mcbDir, "j1111"}], CreateIntermediateDirectories -> True];
Put[{eps^2 s^2 t j[box, 1, 1, 1, 1]}, FileNameJoin[{mcbDir, "j1111", "masters.m"}]];
Put[<|"status" -> "eps-form", "masters" -> {<|"definition" -> eps^2 s^2 t j[box, 1, 1, 1, 1], "normalisation" -> "rational"|>}|>, FileNameJoin[{mcbDir, "j1111", "basis.m"}]];
newRun[name_, entry_ : <||>] := Module[{dir = FileNameJoin[{tmp, name}], ctx, sl},
  Quiet@CreateDirectory[dir, CreateIntermediateDirectories -> True];
  Put[masters, FileNameJoin[{dir, "masters.m"}]];
  Put[<|"Name" -> "planted", "Families" -> {Join[<|"Name" -> "box", "Family" -> boxFile, "Masters" -> "masters.m"|>, entry]}, "Letters" -> {s, t, s + t}|>,
    FileNameJoin[{dir, "system.wl"}]];
  Put[<|"System" -> "system.wl", "OutputDir" -> FileNameJoin[{dir, "run"}], "AllowTmp" -> True, "Paths" -> Automatic|>, FileNameJoin[{dir, "run.wl"}]];
  ctx = PFBStartRun[FileNameJoin[{dir, "run.wl"}]];
  sl = <|"R" -> {Together[A /. P]}, "Derivatives" -> {t}, "Point" -> P, "Labels" -> {1, 2, 3}, "Index" -> <|1 -> 1, 2 -> 2, 3 -> 3|>, "Frame" -> "RootFree", "History" -> {}|>;
  Join[ctx, <|"State" -> PFBStoreSlice[ctx["Dir"], ctx["State"], sl, PFBCensus[ctx["System"], sl], "planted"]|>]];
tests = {};

(* ---- the maximal-cut-basis run: one reader ---- *)
(* "MCBRun" relative to system.wl: PFBReadSystem resolves it once *)
ctxM = newRun["mcb", <|"MCBRun" -> "mcbrun"|>];
sysM = ctxM["System"];
normM = PFBMCBNormalisations[sysM, key3];
(* the system object as the readers see it: the resolved run, while the raw entry names another folder *)
sysX = ReplacePart[sysM, {"Families", Key[box], "Entry", "MCBRun"} -> "no-such-folder"];
normX = PFBMCBNormalisations[sysX, key3];
sysN = ReplacePart[sysM, {"Families", Key[box], "MCBRun"} -> None];
normN = PFBMCBNormalisations[sysN, key3];
AppendTo[tests, VerificationTest[{sysM["Families"][box]["MCBRun"] === mcbDir, Keys[normM], Together[normM[3]["Ratio"]]},
  {True, {3}, s}, TestID -> "MCBRun: the box's rational element, read from the run PFBReadSystem resolved"]];
AppendTo[tests, VerificationTest[{Keys[normX], normN}, {{3}, <||>},
  TestID -> "MCBRun: the phase reads the resolved run (as rung 8 and the validation do), not the raw entry"]];

(* ---- the precondition and the hidden-weight hint ---- *)
ctxH = newRun["hint"];
cH = Get[FileNameJoin[{ctxH["Dir"], Last[ctxH["State"]["Slices"]]["Census"]}]];
hint = SelectFirst[Lookup[cH, "HiddenWeights", {}], #["Sector"] === key1 &, None];
stFlag = Join[ctxH["State"], <|"Flagged" -> <|key3 -> <|"Reason" -> "planted", "Tried" -> {}, "Date" -> "planted", "Forced" -> True|>|>|>];
preOpen = PFBSimplifyPrecondition[ctxH["System"], ctxH["State"], cH];
preHint = PFBSimplifyPrecondition[ctxH["System"], stFlag, cH];
preTried = PFBSimplifyPrecondition[ctxH["System"], stFlag, cH, <|"Tried" -> <|key1 -> {w}|>|>];
preFixed = PFBSimplifyPrecondition[ctxH["System"], Join[stFlag, <|"Accepted" -> {<|"Id" -> 1, "Key" -> key1, "NewDefs" -> <||>|>}|>], cH];
preFlag1 = PFBSimplifyPrecondition[ctxH["System"], Join[stFlag, <|"Flagged" -> Append[stFlag["Flagged"], key1 -> <|"Reason" -> "planted", "Tried" -> {}, "Date" -> "planted"|>]|>], cH];
AppendTo[tests, VerificationTest[{AssociationQ[hint], hint["Factor"], cH["BadSectors"], preOpen["Pass"]}, {True, w, {key3}, False},
  TestID -> "planted data: the census hints a hidden weight on the clean s-bubble, and the box's open poles refuse the phase"]];
AppendTo[tests, VerificationTest[{preHint["Pass"], #["Sector"] & /@ Lookup[preHint, "Hints", Missing[]], Lookup[preTried, "Hints", Missing[]],
    #["Sector"] & /@ Lookup[preFixed, "Hints", Missing[]], Lookup[preFlag1, "Hints", Missing[]]},
  {True, {key1}, {}, {key1}, {}},
  TestID -> "precondition: a hidden-weight hint does not block the phase; untried hints are returned, also on a sector fixed by an accepted change (reopened), not on a flagged one"]];
(* the phase says so: its message carries the note (the degree jobs are not written here) *)
stepH = Block[{PFBDegreesJob = ($Failed &)}, PFBSimplifyStep[Join[ctxH, <|"State" -> PFBSaveState[ctxH["Dir"], stFlag]|>]]];
AppendTo[tests, VerificationTest[{stepH["Outcome"], StringContainsQ[stepH["Message"], "may carry " <> ToString[w, InputForm]],
    StringContainsQ[stepH["Message"], "does not block the phase"]},
  {"error", True, True}, TestID -> "the phase's message says that an untried hint does not block it"]];

report = TestReport[tests];
Do[With[{r = report["TestResults"][id]},
    Print[If[r["Outcome"] === "Success", "PASS ", "FAIL "], r["TestID"], If[r["Outcome"] === "Success", "",
      "\n     got " <> ToString[Short[r["ActualOutput"], 3], InputForm] <> "\n     expected " <> ToString[Short[r["ExpectedOutput"], 3], InputForm]]]],
  {id, Keys[report["TestResults"]]}];
Print[report["TestsSucceededCount"], " passed, ", report["TestsFailedCount"], " failed, ", Round[report["TimeElapsed"], 0.1]];
Quiet[DeleteDirectory[tmp, DeleteContents -> True]];
Exit[If[report["AllTestsSucceeded"], 0, 1]];
