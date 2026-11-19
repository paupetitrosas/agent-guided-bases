#!/usr/bin/env wolframscript
(* Swaps of the simplification phase on a sector of two masters, without FiniteFlow or IBP. Planted data: the two-loop
   equal-mass sunrise of the maximal-cut-basis examples (unit scale m2, derivative d/ds) with two planted masters in the
   sector of the two tadpoles (labels 1 and 2) and one in the top sector (label 3); planted slices and reductions.
   Checked: the part of a change that the degree job of a sector above sees (a pair swap whose rows above couple to one
   master of the pair: the job must invert the whole pair, as T^-1 = H_SS^-1 (e_S - H_SR) needs it; coupled
   combinations of masters; uncoupled rescalings stay restricted), the variant built from it, and the partner of a pair
   swap (only a master that may change).
   usage: bin/ws tests/simplify_swaps.wls        exit code 0 when every test passes *)
Get[FileNameJoin[{ParentDirectory[DirectoryName[$InputFileName]], "lib", "PoleFreeBasis.wl"}]];
$PFBVerbose = False;
sunFile = FileNameJoin[{ParentDirectory[$PFBRoot], "maximal-cut-basis", "examples", "sunrise-equal-mass", "family.wl"}];
keyLow = {sunrise, {1, 1, 0, 0, 0}}; keyTop = {sunrise, {1, 1, 1, 0, 0}};
P = {s -> 3/7, m2 -> 1};
masters = {j[sunrise, 1, 1, 0, 0, 0], m2 j[sunrise, 2, 1, 0, 0, 0], j[sunrise, 1, 1, 1, 0, 0]};
newRun[dir_, R_] := Module[{ctx, sl, st},
  CreateDirectory[dir, CreateIntermediateDirectories -> True];
  Put[masters, FileNameJoin[{dir, "masters.m"}]];
  Put[<|"Name" -> "planted", "Families" -> {<|"Name" -> "sunrise", "Family" -> sunFile, "Masters" -> "masters.m"|>}, "Letters" -> {s, m2, s - m2, s - 9 m2}|>,
    FileNameJoin[{dir, "system.wl"}]];
  Put[<|"System" -> "system.wl", "OutputDir" -> FileNameJoin[{dir, "run"}], "AllowTmp" -> True, "Paths" -> Automatic|>, FileNameJoin[{dir, "run.wl"}]];
  ctx = PFBStartRun[FileNameJoin[{dir, "run.wl"}]];
  sl = <|"R" -> {R}, "Derivatives" -> {s}, "Point" -> P, "Labels" -> {1, 2, 3}, "Index" -> <|1 -> 1, 2 -> 2, 3 -> 3|>, "Frame" -> "RootFree", "History" -> {}|>;
  Join[ctx, <|"State" -> PFBStoreSlice[ctx["Dir"], ctx["State"], sl, PFBCensus[ctx["System"], sl], "planted"]|>]];
tmp = CreateDirectory[];
restrictT = PoleFreeBasis`Simplify`Private`restrictT;
touchedKeys = PoleFreeBasis`Simplify`Private`touchedKeys;

(* ---- the rows above a pair swap ---- *)
(* the top row couples to master 1 only: column 2 is zero *)
R1 = {{-2 + eps, 3/5, 0}, {7/3 eps, -1 - 2 eps, 0}, {5/11 + eps, 0, -3 + eps}};
ctx1 = newRun[FileNameJoin[{tmp, "pair"}], R1];
sys1 = ctx1["System"]; sl1 = PFBCurrentSlice[ctx1["Dir"], ctx1["State"]];
(* a pair swap of the two tadpole masters, in integrals: the job inverts it in its graph *)
Tswap = <|1 -> j[sunrise, 1, 1, 0, -1, 0]/m2, 2 -> m2 j[sunrise, 3, 1, 0, 0, 0]|>;
topSwap = restrictT[sys1, sl1, Tswap, keyTop];
lowSwap = restrictT[sys1, sl1, Tswap, keyLow];
varTop = PFBDegreeVariant["swap", topSwap];
(* the reviewer's scenario in numbers: new masters on the old ones (H, rows 1 and 2 of T) and the top row W. The runner's
   graph inverts T on the keys of the variant as PFBFFReplaceGraph does: T^-1 rows S -> H_SS^-1 (e_S - H_SR) *)
H = {{2, 3, 5}, {7, 11, 13}};
W = R1[[3]];
replaceTinv[Hk_, spos_, nc_] := Module[{k = Length[spos], pm, ti = IdentityMatrix[nc]},
  pm = Table[If[MemberQ[spos, c], Boole[spos[[a]] == c], -Hk[[a, c]]], {a, k}, {c, nc}];
  ti[[spos]] = Inverse[Hk[[All, spos]]] . pm; ti];
Tfull = Join[H, {{0, 0, 1}}];
exactW = Together[W . Inverse[Tfull]];
measuredW[keys_] := Together[W . replaceTinv[H[[keys]], keys, 3]];
(* coupled combinations of masters (no integrals): T^-1 on the pair, computed exactly by PFBDegreeVariant *)
Tcomb = <|1 -> ut[1] + (s/m2) ut[2], 2 -> 3 ut[2]|>;
topComb = restrictT[sys1, sl1, Tcomb, keyTop];
varComb = PFBDegreeVariant["comb", topComb];
exactComb = Together[Inverse[{{1, s/m2, 0}, {0, 3, 0}, {0, 0, 1}}]];
(* rescalings do not couple: the top job keeps master 1 only *)
Tresc = <|1 -> s/m2 ut[1], 2 -> (s - m2)/m2 ut[2]|>;
topResc = restrictT[sys1, sl1, Tresc, keyTop];

(* ---- the partner of a pair swap ---- *)
(* the top row couples to master 2 only, and the top sector is not measured: master 2 may not change (its column
   reaches rows of a sector that is not measured), master 1 may *)
R2 = {{-2 + eps, 3/5, 0}, {7/3 eps, -1 - 2 eps, 0}, {0, 5/11 + eps, -3 + eps}};
ctx2 = newRun[FileNameJoin[{tmp, "partner"}], R2];
sys2 = ctx2["System"]; sl2 = PFBCurrentSlice[ctx2["Dir"], ctx2["State"]];
termP[pw_, n_, d_] := <|"Power" -> pw, "Num" -> n, "Den" -> d, "NumLetters" -> <||>, "DenLetters" -> <||>, "NumUnexplained" -> n, "DenUnexplained" -> d|>;
entP[r_, c_, ts_] := <|"Matrix" -> 1, "Derivative" -> s, "Row" -> r, "Column" -> c, "Eps" -> {"Laurent", 0, 1}, "Terms" -> ts|>;
ents2 = {entP[1, 1, {termP[0, 3, 2]}], entP[1, 2, {termP[0, 1, 1]}], entP[2, 1, {termP[1, 1, 1]}], entP[2, 2, {termP[0, 1, 1], termP[1, 0, 0]}]};
tab2 = <|"Keys" -> {keyLow, keyTop}, "UnitScale" -> m2, "Vars" -> {s}, "Provenance" -> <|"Source" -> "measured"|>,
   "Sectors" -> <|keyLow -> <|"Status" -> "measured", "Source" -> "measured", "Job" -> "planted", "Rows" -> {1, 2}, "Entries" -> ents2, "Summary" -> PFBDegreeSummary[ents2],
       "Probes" -> {s, s - 1, s - 9}, "JobSectors" -> 1, "JobWallSeconds" -> 10, "JobSeconds" -> 1|>,
     keyTop -> <|"Status" -> "not measured", "Reason" -> "planted: the job was refused for memory"|>|>|>;
tab2 = Join[tab2, <|"Summary" -> PFBDegreeSummary[tab2]|>];
mv2 = PFBMovableMasters[ctx2, tab2, <|"EpsForm" -> True|>];
(* a reduction of the sector at the slice point whose pool holds natural integrals of the tadpole sector *)
pool = {j[sunrise, 1, 1, 0, 0, 0], j[sunrise, 2, 1, 0, 0, 0], j[sunrise, 1, 1, 1, 0, 0], j[sunrise, 1, 2, 0, 0, 0], j[sunrise, 1, 1, 0, -1, 0]};
red2 = <|"Masters" -> {ut[1], ut[2], ut[3]}, "Point" -> P, "Invariants" -> {s}, "Focus" -> {1, 2, 3}, "Dm" -> {R2}, "Pool" -> pool,
   "Rp" -> {{1, 0, 0}, {0, 1, 0}, {0, 0, 1}, {0, 1, 0}, {1/3, 1/5, 0}},
   "dRp" -> {{R2[[1]], R2[[2]], R2[[3]], R2[[2]], Together[{1/3, 1/5, 0} . R2 + {1/7, 0, 0}]}}|>;
cal2 = PFBCalibrate[sl2, red2];
nSingles = PFBSwapCandidates[ctx2, red2, cal2, keyLow, 1, <|"Pairs" -> False|>]["Sets"];
nAll = PFBSwapCandidates[ctx2, red2, cal2, keyLow, 1]["Sets"];
nFree = PFBSwapCandidates[ctx2, red2, cal2, keyLow, 1, <|"Partners" -> mv2["Free"]|>]["Sets"];
(* the move: the sector's own job calibrates, so it scans at once *)
With[{jd = FileNameJoin[{ctx2["Dir"], "jobs", PoleFreeBasis`Simplify`Private`sectorJobName[keyLow]}]}, CreateDirectory[jd, CreateIntermediateDirectories -> True];
  Put[red2, FileNameJoin[{jd, "red_1.m"}]]];
swapM2 = PoleFreeBasis`Simplify`Private`swapMove[ctx2, tab2, <||>, <|"MoveId" -> 1, "Record" -> None|>];

tests = {
  VerificationTest[{PFBCensus[sys1, sl1]["BadEntries"], PFBMaster[sys1, 1]["SectorKey"], PFBMaster[sys1, 2]["SectorKey"], PFBMaster[sys1, 3]["SectorKey"], touchedKeys[sys1, sl1, Tswap]},
    {{}, keyLow, keyLow, keyTop, {keyLow, keyTop}}, TestID -> "the planted run: two masters in the tadpole sector, the top row couples to the first"],
  (* the blocker: the top job must invert the whole pair *)
  VerificationTest[{Keys[topSwap], Keys[lowSwap], varTop["TInverse"], Keys[varTop["T"]]}, {{1, 2}, {1, 2}, Automatic, {1, 2}},
    TestID -> "pair swap: a sector above that couples to one master of the pair sees the whole pair"],
  VerificationTest[{measuredW[Keys[topSwap]] === exactW, measuredW[{1}] === exactW}, {True, False},
    TestID -> "pair swap: inverting the pair gives the DE after the change in the row above; one master alone would not"],
  VerificationTest[{Keys[topComb], Together[Coefficient[varComb["TInverse"][1], {ut[1], ut[2]}]]}, {{1, 2}, {1, Together[exactComb[[1, 2]]]}},
    TestID -> "coupled combinations: the row above gets the row of T^-1 of the whole block"],
  VerificationTest[{Keys[topResc], varComb === $Failed}, {{1}, False}, TestID -> "rescalings: a row above sees only the masters it couples to"],
  (* the partner of a pair *)
  VerificationTest[{mv2["Free"], Sort[Keys[mv2["Protected"]]], StringContainsQ[mv2["Protected"][2], "not measured"]}, {{1}, {2, 3}, True},
    TestID -> "partner: master 2 may not change (its column reaches rows of a sector that is not measured)"],
  VerificationTest[{cal2["Status"], nSingles > 0, nAll > nSingles, nFree}, {"exact", True, True, nSingles},
    TestID -> "partner: PFBSwapCandidates pairs a master only with the partners it is given"],
  VerificationTest[{Lookup[swapM2["Info"], "Master", None], Lookup[swapM2["Info"], "Sets", None]}, {1, nSingles},
    TestID -> "partner: move (ii) gives the free masters as partners: no pair with a master that may not change"]
};

report = TestReport[tests];
Do[With[{r = report["TestResults"][id]},
    Print[If[r["Outcome"] === "Success", "PASS ", "FAIL "], r["TestID"], If[r["Outcome"] === "Success", "",
      "\n     got " <> ToString[Short[r["ActualOutput"], 3], InputForm] <> "\n     expected " <> ToString[Short[r["ExpectedOutput"], 3], InputForm]]]],
  {id, Keys[report["TestResults"]]}];
Print[report["TestsSucceededCount"], " passed, ", report["TestsFailedCount"], " failed, ", Round[report["TimeElapsed"], 0.1]];
DeleteDirectory[tmp, DeleteContents -> True];
Exit[If[report["AllTestsSucceeded"], 0, 1]];
