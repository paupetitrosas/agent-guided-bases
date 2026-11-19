#!/usr/bin/env wolframscript
(* The hidden-weight hint and the lower-sector scan, at their edges:
   - a sector that cannot change (a frozen family, flagged) gets no hint, and the hidden-weight test never names it
     (PFBCanChangeQ, PFBFlaggedSectors, PFBCensusOptions); a sector fixed by an accepted change gets the hint and is
     named, as reopened (PFBReopenedSectors, "Reopens");
   - the census text and the source test say that the hint is a hint, that the scan is small, and that a recorded scan
     ends it; every census of templates/AnalysisPoles.m takes the run's options;
   - a lower-sector scan that cannot run (too many sets, no slots) is recorded with its reason, so the hint is tried and
     PFBFlagSector may flag the sector where the poles show;
   - "Clearing" counts only the sets that clear the rows above with nothing raised above the cap, as
     bin/pair_scan.wls --hidden-weight takes them ("ClearingSets").
   Planted data: as tests/hidden_weight.wls, the one-loop massless box family of the maximal-cut-basis examples with five
   masters (the s-bubble, the t-bubble, the triangle sector S with two masters, the box T); S carries a hidden weight
   w = 1 + 4 eps on ut[3], which shows only in the box row. One more candidate for S, J_3/eps^2: it clears the box row
   of w but puts eps^3 into it (above the cap). No IBP reduction, no FiniteFlow.
   usage: bin/ws tests/hidden_weight_hint.wls        exit code 0 when every test passes *)
Get[FileNameJoin[{ParentDirectory[DirectoryName[$InputFileName]], "lib", "PoleFreeBasis.wl"}]];
$PFBVerbose = False;
root = ParentDirectory[DirectoryName[$InputFileName]];
boxFile = FileNameJoin[{ParentDirectory[root], "maximal-cut-basis", "examples", "box-one-loop", "family.wl"}];
tmp = CreateDirectory[];
Put[{j[box, 1, 0, 1, 0], j[box, 0, 1, 0, 1], s j[box, 1, 1, 1, 0], s^2 j[box, 2, 1, 1, 0], s t j[box, 1, 1, 1, 1]}, FileNameJoin[{tmp, "planted.m"}]];
writeSystem[name_, extra_ : <||>] := (Put[Join[<|"Name" -> name, "Families" -> {<|"Name" -> "box", "Family" -> boxFile, "Masters" -> "planted.m"|>}|>, extra], FileNameJoin[{tmp, name <> ".wl"}]];
  PFBReadSystem[FileNameJoin[{tmp, name <> ".wl"}]]);
sys = writeSystem["planted"]; sysF = writeSystem["frozen", <|"Frozen" -> {"box"}|>];
keyS = {box, {1, 1, 1, 0}}; keyT = {box, {1, 1, 1, 1}};
P = {s -> 1, t -> 3/7};
slice[R_] := <|"R" -> {R}, "Derivatives" -> {t}, "Point" -> P, "Labels" -> Range[5], "Index" -> AssociationThread[Range[5] -> Range[5]], "History" -> {}|>;
hasAll[str_String, l_List] := AllTrue[l, StringContainsQ[str, #] &];
hasAll[_, _] := False;
w = 1 + 4 eps;
Rp = {{-eps, 0, 0, 0, 0}, {0, -2 eps, 0, 0, 0}, {eps, 0, -2 eps, eps, 0}, {2 eps, 0, 0, -3 eps, 0}, {eps + eps^2, 1 + eps, eps, 0, -1 - 2 eps}};
nHonest = {1/w, 0, 1/w, 0, 0};
Nh = ReplacePart[IdentityMatrix[5], 3 -> nHonest];
Rold = Together[Inverse[Nh] . Rp . Nh];
redOf[R_, cands_List, focus_, masters_] := <|"Masters" -> ut /@ masters, "Point" -> P, "Invariants" -> {t}, "Focus" -> focus, "Dm" -> {R[[focus, masters]]},
   "Pool" -> cands[[All, 1]], "Rp" -> Table[c[[3, masters]]/(c[[2]] /. P), {c, cands}],
   "dRp" -> {Table[With[{c0 = c[[2]] /. P, dc = D[c[[2]], t] /. P}, Together[((c[[3]] . R)[[masters]] - dc c[[3, masters]]/c0)/c0]], {c, cands}]}|>;
honest = j[box, 1, 1, 2, 0]; high = j[box, 1, 1, 3, 0];
poolS = {{j[box, 1, 1, 1, 0], s, UnitVector[5, 3]}, {j[box, 2, 1, 1, 0], s^2, UnitVector[5, 4]}, {honest, s^2, nHonest}, {high, s^2, nHonest/eps^2}};
redS = redOf[Rold, poolS, {3, 4}, {1, 3, 4}];
sl0 = slice[Rold]; calS = PFBCalibrate[sl0, redS];
newRun[sysX_, name_, flagged_ : <||>] := Module[{dir = CreateDirectory[FileNameJoin[{tmp, name}]], st, sl = slice[Rold]},
  st = <|"Run" -> "none", "Created" -> PFBTimeStamp[], "Slices" -> {}, "Current" -> None, "Censuses" -> {}, "Accepted" -> {}, "Pending" -> {},
    "Rejected" -> {}, "Flagged" -> flagged, "Approval" -> False, "Regenerated" -> False|>;
  st = PFBStoreSlice[dir, st, sl, PFBCensus[sysX, sl], "start"];
  <|"Run" -> <|"MaxEpsDegree" -> 2|>, "System" -> sysX, "Dir" -> dir, "State" -> st|>];

c0 = PFBCensus[sys, sl0];
cF = PFBCensus[sysF, sl0];
cX = PFBCensus[sys, sl0, <|"Fixed" -> {keyS}|>];
stFlag = <|"Flagged" -> <|keyS -> <|"Reason" -> "planted"|>|>, "Accepted" -> {<|"Key" -> {box, {1, 0, 1, 0}}|>, <|"Key" -> None|>}|>;
(* S fixed by an accepted change (id 4), nothing flagged: the hint reopens it *)
ctxR = Module[{c = newRun[sys, "reopen"]}, c["State"]["Accepted"] = {<|"Key" -> keyS, "Id" -> 4|>}; c];
cR = PFBCensus[sys, sl0, PFBCensusOptions[ctxR]];
tests = {
  VerificationTest[{#["Sector"] & /@ c0["HiddenWeights"], c0["Next"]}, {{keyS}, keyS}, TestID -> "the planted slice: S is a possible hidden weight and Next"],
  VerificationTest[{cF["HiddenWeights"], cF["Next"], cX["HiddenWeights"], cX["Next"], PFBCanChangeQ[sysF, keyS], PFBCanChangeQ[sys, keyS], PFBCanChangeQ[sys, keyS, {keyS}]},
    {{}, keyT, {}, keyT, False, True, False}, TestID -> "census: no hint on a sector of a frozen family, nor on a fixed one; the box is Next"],
  VerificationTest[With[{o = PFBCensusOptions[tmp, stFlag, sys]}, {PFBFixedSectors[stFlag], Sort[Keys[o]], o["Fixed"], o["Reopen"]}],
    {{{box, {1, 0, 1, 0}}, keyS}, {"Fixed", "HiddenWeightTried", "Reopen"}, {keyS}, <|{box, {1, 0, 1, 0}} -> {}|>},
    TestID -> "PFBCensusOptions: the flagged sectors are never named, those fixed by an accepted change are reopened"],
  VerificationTest[{#["Sector"] & /@ cR["HiddenWeights"], Lookup[First[cR["HiddenWeights"]], "Reopens", None], cR["Next"],
      StringContainsQ[PFBCensusText[cR], "it reopens a sector fixed by an accepted change (4)"]},
    {{keyS}, {4}, keyS, True}, TestID -> "census: a sector fixed by an accepted change gets the hint, as reopened, and is Next"],
  VerificationTest[With[{h = PFBHiddenWeightTest[ctxR, keyT]}, {h["Found"], h["Sector"], StringContainsQ[h["Message"], "reopens a sector fixed by an accepted change (4)"]}],
    {True, keyS, True}, TestID -> "hidden-weight test of a run: it names the sector fixed by an accepted change, as reopened"],
  VerificationTest[{PFBHiddenWeightTest[sysF, sl0, cF, keyT, {}]["Found"], PFBHiddenWeightTest[sys, sl0, c0, keyT, {}, <|"Fixed" -> {keyS}|>]["Found"],
      PFBHiddenWeightTest[sys, sl0, c0, keyT, {}]["Sector"]}, {False, False, keyS},
    TestID -> "hidden-weight test: it never names a frozen or fixed sector"],
  VerificationTest[{hasAll[PFBCensusText[c0], {"hints", "a small scan on one reduction of its subtree", "once it is recorded the hint ends"}],
      hasAll[PFBSourceTest[sys, sl0, c0, keyT]["Message"], {"A hint", "small: one reduction of its subtree", "once it is recorded, the hint ends"}],
      hasAll[PFBSourceTest[sys, sl0, c0, keyS]["Message"], {"a hint, which a recorded lower-sector scan ends", "a small scan on one reduction of its subtree"}]},
    {True, True, True}, TestID -> "census text and source test: a hint, a small scan, ended by a recorded scan"],
  VerificationTest[With[{t = Import[FileNameJoin[{root, "templates", "AnalysisPoles.m"}], "Text"]},
      {Length[StringCases[t, "PFBCensus["]] > 1, AllTrue[StringCases[t, "PFBCensus[" ~~ Shortest[x__] ~~ "\n" :> x], StringContainsQ[#, "PFBCensusOptions[ctx]"] &]}],
    {True, True}, TestID -> "templates/AnalysisPoles.m: every census takes the run's options (the scans recorded, the fixed sectors)"]
};

(* Clearing: the set that clears w from the box row but puts eps^3 into it does not count *)
hws = PFBHiddenWeightScan[sys, sl0, redS, calS, keyS, <|"Census" -> c0, "Candidates" -> {high}|>];
nClear = Count[hws["Results"], r_ /; r["above"] == 0 && r["newBad"] === 0 && r["over"] == 0];
AppendTo[tests, VerificationTest[{calS["Status"], hws["Clearing"] == nClear, Union[#["set"][3] & /@ hws["ClearingSets"]], AnyTrue[hws["Results"], #["set"][3] === high && #["above"] == 0 && #["over"] > 0 &],
    StringContainsQ[hws["Message"], "no new pole and nothing above the cap"]},
  {"exact", True, {honest}, True, True}, TestID -> "Clearing: only the sets that clear the rows above within the cap"]];

(* a scan that cannot run is recorded, and the flag of the box goes through *)
ctx = newRun[sys, "flag"];
hwF = PFBHiddenWeightScan[sys, sl0, redS, calS, keyS, <|"Census" -> c0, "RunDir" -> ctx["Dir"], "MaxSets" -> 1|>];
hwN = PFBHiddenWeightScan[sys, sl0, redS, calS, keyS, <|"Census" -> c0, "RunDir" -> ctx["Dir"], "Slots" -> {5}|>];
attS = MCBReadAttempts[PFBSectorDir[ctx["Dir"], keyS]];
AppendTo[tests, VerificationTest[{hwF["Status"], hwN["Status"], PFBHiddenWeightTried[ctx["Dir"], keyS], Lookup[#["hiddenWeight"], {"Status", "Factors"}] & /@ attS,
    StringStartsQ[First[attS]["outcome"], "not run (too many)"], First[PFBCensus[sys, sl0, PFBCensusOptions[ctx]]["HiddenWeights"]]["Tried"]},
  {"too many", "no slots", {w}, {{"too many", {w}}, {"no slots", {w}}}, True, True},
  TestID -> "a lower-sector scan that cannot run is recorded with its reason, and the hint is tried"]];
stF = PFBFlagSector[ctx, keyT, "nothing removed 1/(1 + 4 eps)", {"rung 3"}];
AppendTo[tests, VerificationTest[{KeyExistsQ[stF["Flagged"], keyT], First[stF["Flagged"][keyT]["HiddenWeight"]["Hits"]]["Tried"]}, {True, True},
  TestID -> "PFBFlagSector: the box is flagged once the scan of S was recorded, even one that could not run"]];

report = TestReport[tests];
Do[With[{r = report["TestResults"][id]},
    Print[If[r["Outcome"] === "Success", "PASS ", "FAIL "], r["TestID"], If[r["Outcome"] === "Success", "",
      "\n     got " <> ToString[Short[r["ActualOutput"], 3], InputForm] <> "\n     expected " <> ToString[Short[r["ExpectedOutput"], 3], InputForm]]]],
  {id, Keys[report["TestResults"]]}];
Print[report["TestsSucceededCount"], " passed, ", report["TestsFailedCount"], " failed, ", Round[report["TimeElapsed"], 0.1]];
DeleteDirectory[tmp, DeleteContents -> True];
Exit[If[report["AllTestsSucceeded"], 0, 1]];
