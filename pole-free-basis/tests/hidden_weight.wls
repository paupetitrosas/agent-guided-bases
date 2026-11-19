#!/usr/bin/env wolframscript
(* A hidden weight on a clean lower sector. A master of a clean sector S can carry a weight, I_m = w J_m with
   w = 1 + 4 eps and J_m honest: S's own rows stay clean, and the rows above that couple to I_m get 1/w in the columns of
   S's subtree. The census marks S ("PossibleHiddenWeight") and makes it "Next" before the sector where the poles show;
   the source test reports it; before a flag, the hidden-weight test reads the poles the attempts left; the lower-sector
   scan over S's masters, judged on the rows above with S's own rows kept pole-free, finds the honest master, and
   PFBTryChange accepts it like any other change.
   Planted data: the one-loop massless box family of the maximal-cut-basis examples with five masters: the s-bubble
   (label 1, the bottom sector), the t-bubble (label 2, a clean sector beside it), s j[box, 1, 1, 1, 0] and
   s^2 j[box, 2, 1, 1, 0] (labels 3 and 4: the triangle sector S, clean, two masters) and s t times the box (label 5:
   the top sector T), one derivative (d/dt). The honest basis J' = N I has the pole-free DE R'; the old slice is
   N^-1 R' N with N[[3]] = (1/w, 0, 1/w, 0, 0): I_3 = w J'_3 - J'_1, so the box row has 1/w in the columns of the
   s-bubble and of ut[3], both in S's subtree, and S's rows are clean. A candidate integral reduces to its planted row
   of N (its derivative: that row times the old DE). No IBP reduction, no FiniteFlow.
   usage: bin/ws tests/hidden_weight.wls        exit code 0 when every test passes *)
Get[FileNameJoin[{ParentDirectory[DirectoryName[$InputFileName]], "lib", "PoleFreeBasis.wl"}]];
$PFBVerbose = False;
boxFile = FileNameJoin[{ParentDirectory[ParentDirectory[DirectoryName[$InputFileName]]], "maximal-cut-basis", "examples", "box-one-loop", "family.wl"}];
tmp = CreateDirectory[];
Put[{j[box, 1, 0, 1, 0], j[box, 0, 1, 0, 1], s j[box, 1, 1, 1, 0], s^2 j[box, 2, 1, 1, 0], s t j[box, 1, 1, 1, 1]}, FileNameJoin[{tmp, "planted.m"}]];
Put[<|"Name" -> "planted", "Families" -> {<|"Name" -> "box", "Family" -> boxFile, "Masters" -> "planted.m"|>}|>, FileNameJoin[{tmp, "planted.wl"}]];
sys = PFBReadSystem[FileNameJoin[{tmp, "planted.wl"}]];
keyB = {box, {1, 0, 1, 0}}; keyB2 = {box, {0, 1, 0, 1}}; keyS = {box, {1, 1, 1, 0}}; keyT = {box, {1, 1, 1, 1}};
P = {s -> 1, t -> 3/7}; P2 = {s -> 1, t -> 5/11}; P3 = {s -> 1, t -> 2/13};   (* the slice point and two extra points *)
slice[R_] := <|"R" -> {R}, "Derivatives" -> {t}, "Point" -> P, "Labels" -> Range[5], "Index" -> AssociationThread[Range[5] -> Range[5]], "History" -> {}|>;
checkOf[g_, name_] := SelectFirst[g["Checks"], #["Name"] === name &];
hasAll[str_String, l_List] := AllTrue[l, StringContainsQ[str, #] &];
hasAll[_, _] := False;
w = 1 + 4 eps;

(* the honest basis: pole-free; S's second master does not couple to ut[3], and the box does not couple to ut[4] *)
Rp = {{-eps, 0, 0, 0, 0}, {0, -2 eps, 0, 0, 0}, {eps, 0, -2 eps, eps, 0}, {2 eps, 0, 0, -3 eps, 0}, {eps + eps^2, 1 + eps, eps, 0, -1 - 2 eps}};
nHonest = {1/w, 0, 1/w, 0, 0};
Nh = ReplacePart[IdentityMatrix[5], 3 -> nHonest];
Rold = Together[Inverse[Nh] . Rp . Nh];
(* a decoy: 1/w also in the t-bubble's column, so the columns with w lie in no single clean sector's subtree *)
Rdec = ReplacePart[Rold, {5, 2} -> (1 + eps)/w];

(* a reduction at the slice point: masters, focus rows of the old DE, and candidates {integral, coefficient, row of N}
   whose definition coefficient * integral is the new master N-row . old (its derivative N-row . R_old) *)
redOf[R_, cands_List, focus_, masters_, pt_ : P] := <|"Masters" -> ut /@ masters, "Point" -> pt, "Invariants" -> {t}, "Focus" -> focus, "Dm" -> {R[[focus, masters]]},
   "Pool" -> cands[[All, 1]], "Rp" -> Table[c[[3, masters]]/(c[[2]] /. pt), {c, cands}],
   "dRp" -> {Table[With[{c0 = c[[2]] /. pt, dc = D[c[[2]], t] /. pt}, Together[((c[[3]] . R)[[masters]] - dc c[[3, masters]]/c0)/c0]], {c, cands}]}|>;
honest = j[box, 1, 1, 2, 0]; spoiler = j[box, 1, 2, 1, 0];
(* the reduction of S's subtree (the s-bubble and S): the integrals of S's masters, the honest candidate, and a candidate
   that, put in the slot of ut[4], clears the box row together with the honest one but gives S's own rows a pole *)
poolS = {{j[box, 1, 1, 1, 0], s, UnitVector[5, 3]}, {j[box, 2, 1, 1, 0], s^2, UnitVector[5, 4]}, {honest, s^2, nHonest}, {spoiler, s^2, {1/w, 0, 0, 1, 0}}};
redS[R_, pt_ : P] := redOf[R, poolS, {3, 4}, {1, 3, 4}, pt];
(* the reduction of the box's subtree, with a candidate for the box that only doubles it: its rows keep 1/w *)
candT = j[box, 1, 1, 1, 2];
redT[R_] := redOf[R, {{candT, s t^2, 2 UnitVector[5, 5]}}, {5}, Range[5]];

newRun[R_, name_, approval_ : False] := Module[{dir = CreateDirectory[FileNameJoin[{tmp, name}]], st, sl = slice[R]},
  st = <|"Run" -> "none", "Created" -> PFBTimeStamp[], "Slices" -> {}, "Current" -> None, "Censuses" -> {}, "Accepted" -> {}, "Pending" -> {},
    "Rejected" -> {}, "Flagged" -> <||>, "Approval" -> approval, "Regenerated" -> False|>;
  st = PFBStoreSlice[dir, st, sl, PFBCensus[sys, sl], "start"];
  <|"Run" -> <|"MaxEpsDegree" -> 2|>, "System" -> sys, "Dir" -> dir, "State" -> st|>];

c0 = PFBCensus[sys, slice[Rold]];
cDec = PFBCensus[sys, slice[Rdec]];
tests = {
  VerificationTest[sys =!= $Failed && (PFBMaster[sys, #]["SectorKey"] & /@ Range[5]) === {keyB, keyB2, keyS, keyS, keyT}, True, TestID -> "the planted system loads: three sectors in a line and one beside"],
  VerificationTest[{c0["BadEntries"], c0["Sectors"][keyS]["Issues"], c0["BadSectors"]}, {{{1, 5, 1, {w}}, {1, 5, 3, {w}}}, {}, {keyT}},
    TestID -> "the planted slice: S is clean, the box row has 1/w in the columns of the s-bubble and of ut[3]"],
  VerificationTest[{PFBSubtreeMasters[sys, slice[Rold], keyS], PFBSubtreeMasters[sys, slice[Rold], keyB2], PFBSubtreeMasters[sys, slice[Rold], keyT]}, {{1, 3, 4}, {2}, {1, 2, 3, 4, 5}},
    TestID -> "subtree: S's masters and its subsector's, not the t-bubble"],
  (* (a) the census hint *)
  VerificationTest[{c0["Sectors"][keyS]["PossibleHiddenWeight"], c0["Sectors"][keyT]["HiddenWeightBelow"], c0["Next"],
      KeyTake[First[c0["HiddenWeights"]], {"Factor", "Sector", "Columns", "Masters", "Rows", "Sectors", "Tried"}]},
    {{w}, <|w -> keyS|>, keyS, <|"Factor" -> w, "Sector" -> keyS, "Columns" -> {1, 3}, "Masters" -> {3}, "Rows" -> {5}, "Sectors" -> {keyT}, "Tried" -> False|>},
    TestID -> "census: S marked as a possible hidden weight and Next, before the box"],
  VerificationTest[hasAll[PFBCensusText[c0], {"possible hidden weights (hints", "box/j1110 (1 + 4*eps, in the rows of box/j1111)"}], True, TestID -> "census text: the hint"],
  VerificationTest[{cDec["HiddenWeights"], cDec["Sectors"][keyS]["PossibleHiddenWeight"], cDec["Next"]}, {{}, {}, keyT},
    TestID -> "decoy: w also in the t-bubble's column, no hint, the box is Next"],
  VerificationTest[With[{c = PFBCensus[sys, slice[Rold], <|"HiddenWeightTried" -> <|keyS -> {w}|>|>]}, {First[c["HiddenWeights"]]["Tried"], c["Next"]}], {True, keyT},
    TestID -> "census: once S's lower-sector scan is recorded, the box is Next"],
  (* the source test reports the hint, on S and on the box *)
  VerificationTest[With[{r = PFBSourceTest[sys, slice[Rold], c0, keyS]}, {r["Outcome"], #["Sector"] & /@ r["HiddenWeight"], hasAll[r["Message"], {"possible hidden weight", "--hidden-weight"}]}],
    {"pole-free", {keyS}, True}, TestID -> "source test of S: pole-free, with the hint and the scan to run"],
  VerificationTest[With[{r = PFBSourceTest[sys, slice[Rold], c0, keyT]}, {#["Sector"] & /@ r["HiddenWeight"], hasAll[r["Message"], {"box/j1110 as a possible hidden weight of 1 + 4*eps", "open that sector first"}]}],
    {{keyS}, True}, TestID -> "source test of the box: names S"],
  VerificationTest[KeyExistsQ[PFBSourceTest[sys, slice[Rdec], cDec, keyT], "HiddenWeight"], False, TestID -> "source test of the decoy: no hint"]
};

(* the lower-sector scan of S, with the reduction of S's subtree only *)
sl0 = slice[Rold]; calS = PFBCalibrate[sl0, redS[Rold]];
hws = PFBHiddenWeightScan[sys, sl0, redS[Rold], calS, keyS, <|"Census" -> c0|>];
AppendTo[tests, VerificationTest[{calS["Status"], hws["Status"], hws["Factors"], hws["Rows"], hws["Slots"], hws["AboveBefore"]}, {"exact", "done", {w}, {5}, {3, 4}, 2},
  TestID -> "lower-sector scan: S's slots, judged on the box row, from S's subtree reduction"]];
AppendTo[tests, VerificationTest[With[{b = First[hws["Results"]]}, {b["set"][3], b["above"], b["bad"], b["newBad"], hws["Clearing"] >= 1}],
  {honest, 0, 0, 0, True}, TestID -> "lower-sector scan: the honest candidate first, w gone from the rows above"]];
AppendTo[tests, VerificationTest[{AnyTrue[hws["RankedOut"], #["set"][3] === honest && #["set"][4] === spoiler && #["above"] == 0 && #["bad"] > 0 &],
    NoneTrue[hws["Results"], #["set"][4] === spoiler &], Last[hws["Results"]]["above"]},
  {True, True, 2}, TestID -> "lower-sector scan: a set that clears the rows above but puts a pole into S's rows is ranked out"]];
AppendTo[tests, VerificationTest[PFBHiddenWeightScan[sys, slice[Rdec], redS[Rdec], PFBCalibrate[slice[Rdec], redS[Rdec]], keyS, <|"Census" -> cDec|>]["Status"], "no factor",
  TestID -> "lower-sector scan: without a hint it asks for the factor"]];
AppendTo[tests, VerificationTest[With[{r = PFBHiddenWeightScan[sys, sl0, redS[Rold], calS, keyS, <|"Census" -> cDec, "Factors" -> {w}|>]}, {r["Status"], r["Rows"], First[r["Results"]]["set"][3]}],
  {"done", {5}, honest}, TestID -> "lower-sector scan: the factor given, the rows found"]];

(* PFBTryChange: the winner, normalised, through the gate with S's subtree reductions. Its determinant on the old master
   is 1/w; it is recorded, not judged, and the change does not alter S's maximal cut (no component on ut[4]) *)
rA = PFBTryChange[newRun[Rold, "hidden"], keyS, <|3 -> s^2 honest|>, <|"Rung" -> 3, "Provenance" -> "lower-sector scan"|>, <|"Reds" -> {redS[Rold], redS[Rold, P2], redS[Rold, P3]}|>];
AppendTo[tests, VerificationTest[{rA["Status"], rA["Gate"]["Pass"], Together[rA["Record"]["Determinant"] - 1/w], rA["Record"]["MaxCutChanged"], rA["Record"]["PointsVerified"]},
  {"accepted", True, 0, False, 2}, TestID -> "the honest master: accepted, its determinant 1/w recorded"]];
AppendTo[tests, VerificationTest[With[{c = PFBCensus[sys, PFBCurrentSlice[rA["Context"]["Dir"], rA["Context"]["State"]]]}, {c["BadEntries"], c["HiddenWeights"], c["Next"]}], {{}, {}, None},
  TestID -> "accepted: the census is clean, no hint left"]];

(* (b) the hidden-weight test on the attempts recorded for the box, and PFBFlagSector *)
ctxF = newRun[Rold, "flag"];
rT = PFBTryChange[ctxF, keyT, <|5 -> s t^2 candT|>, <|"Rung" -> 3, "Provenance" -> "a box candidate"|>, <|"Reds" -> {redT[Rold]}|>];
ctxF = rT["Context"];
scT = PFBScanSets[sys, sl0, redT[Rold], PFBCalibrate[sl0, redT[Rold]], keyT, {<|5 -> candT|>}, <|"Census" -> c0|>];
PFBRecordScan[ctxF["Dir"], keyT, scT, <|"What" -> "planted pair scan"|>];
attT = MCBReadAttempts[PFBSectorDir[ctxF["Dir"], keyT]];
AppendTo[tests, VerificationTest[{rT["Status"], Lookup[#, "leftover"] & /@ attT, First[scT["Results"]]["left"]},
  {"rejected", {{{5, 1, {w}}, {5, 3, {w}}}, {{5, 1, {w}}, {5, 3, {w}}}}, {{5, 1, {w}}, {5, 3, {w}}}}, TestID -> "attempts keep the poles they left in the box rows (a change and a scan)"]];
hwt = PFBHiddenWeightTest[ctxF, keyT];
AppendTo[tests, VerificationTest[{hwt["Found"], hwt["Sector"], hwt["Factor"], hwt["Source"], hwt["Attempts"], First[hwt["Hits"]]["Columns"], First[hwt["Hits"]]["Tried"],
    hasAll[hwt["Message"], {"across 2 attempts", "the clean sector box/j1110", "open it before flagging"}]},
  {True, keyS, w, "attempts", 2, {1, 3}, False, True}, TestID -> "hidden-weight test: the attempts name S and w"]];
(* the decoy, and the case the census cannot see: the slice has w in the t-bubble's column as well, but every attempt
   removed that one and left w in S's columns only *)
AppendTo[tests, VerificationTest[{PFBHiddenWeightTest[sys, slice[Rdec], cDec, keyT, {<|"leftover" -> {{5, 2, {w}}}|>, <|"leftover" -> {{5, 3, {w}}}|>}]["Found"],
    PFBHiddenWeightTest[sys, slice[Rdec], cDec, keyT, {}]["Found"],
    Lookup[PFBHiddenWeightTest[sys, slice[Rdec], cDec, keyT, {<|"leftover" -> {{5, 3, {w}}}|>, <|"leftover" -> {{5, 1, {w}}, {5, 3, {w}}}|>, <|"what" -> "no leftover"|>}], {"Found", "Sector", "Attempts"}]},
  {False, False, {True, keyS, 2}}, TestID -> "hidden-weight test: columns in two unrelated sectors name nothing; the attempts can show what the slice does not"]];
stF = PFBFlagSector[ctxF, keyT, "nothing removed 1/(1 + 4 eps)", {"rung 3"}];
AppendTo[tests, VerificationTest[{KeyExistsQ[stF["Flagged"], keyT], Last[MCBReadAttempts[PFBSectorDir[ctxF["Dir"], keyT]]]["what"]}, {False, "flag refused (the hidden-weight test)"},
  TestID -> "PFBFlagSector: refused while S's lower-sector scan is not recorded"]];
AppendTo[tests, VerificationTest[{KeyExistsQ[PFBFlagSector[ctxF["Dir"], ctxF["State"], keyT, "why", {}]["Flagged"], keyT],
    KeyExistsQ[PFBFlagSector[ctxF["Dir"], ctxF["State"], keyT, "why", {}, <|"Force" -> True|>]["Flagged"], keyT]}, {False, True},
  TestID -> "PFBFlagSector: without a system the test cannot run and the flag is refused, unless forced"]];
hwsF = PFBHiddenWeightScan[sys, sl0, redS[Rold], calS, keyS, <|"Census" -> c0, "RunDir" -> ctxF["Dir"]|>];
AppendTo[tests, VerificationTest[{PFBHiddenWeightTried[ctxF["Dir"], keyS], PFBHiddenWeightTried[ctxF["Dir"], sys],
    Lookup[Last[MCBReadAttempts[PFBSectorDir[ctxF["Dir"], keyS]]]["hiddenWeight"], {"Factors", "Rows", "Before", "Left"}],
    PFBCensus[sys, sl0, <|"HiddenWeightTried" -> PFBHiddenWeightTried[ctxF["Dir"], sys]|>]["Next"]},
  {{w}, <|keyS -> {w}|>, {{w}, {5}, 2, 0}, keyT}, TestID -> "the lower-sector scan is recorded in S's attempts, and the census moves on"]];
stF2 = PFBFlagSector[ctxF, keyT, "nothing removed 1/(1 + 4 eps)", {"rung 3"}];
AppendTo[tests, VerificationTest[With[{f = stF2["Flagged"][keyT]}, {f["Reason"], f["HiddenWeight"]["Found"], First[f["HiddenWeight"]["Hits"]]["Tried"]}],
  {"nothing removed 1/(1 + 4 eps)", True, True}, TestID -> "PFBFlagSector: flags once S was scanned, with the test recorded"]];

(* pages: S's page and the summary show the hint, the box's page and the flag show the test *)
stR = stF2;
Quiet[PFBMakeReports[ctxF["Dir"], sys, stR]];
pageS = Import[FileNameJoin[{PFBSectorDir[ctxF["Dir"], keyS], "sector.html"}], "Text"];
pageT = Import[FileNameJoin[{PFBSectorDir[ctxF["Dir"], keyT], "sector.html"}], "Text"];
summary = Import[FileNameJoin[{ctxF["Dir"], "summary.html"}], "Text"];
AppendTo[tests, VerificationTest[{StringContainsQ[pageS, "Possible hidden weight."], StringContainsQ[summary, "Possible hidden weights"],
    StringContainsQ[summary, "lower-sector scan recorded"], StringContainsQ[pageS, "its lower-sector scan was recorded"],
    StringContainsQ[pageT, "a possible hidden weight of that sector"], StringContainsQ[pageT, "hidden-weight test:"], StringContainsQ[pageT, "left in the sector&#39;s rows"] || StringContainsQ[pageT, "left in the sector's rows"],
    Lookup[MCBReadBasis[PFBSectorDir[ctxF["Dir"], keyS]], "possibleHiddenWeight", {}][[All, "factor"]]},
  {True, True, True, True, True, True, True, {w}}, TestID -> "pages: the hint on S's page and the summary (its scan recorded), the test on the box's page"]];

report = TestReport[tests];
Do[With[{r = report["TestResults"][id]},
    Print[If[r["Outcome"] === "Success", "PASS ", "FAIL "], r["TestID"], If[r["Outcome"] === "Success", "",
      "\n     got " <> ToString[Short[r["ActualOutput"], 3], InputForm] <> "\n     expected " <> ToString[Short[r["ExpectedOutput"], 3], InputForm]]]],
  {id, Keys[report["TestResults"]]}];
Print[report["TestsSucceededCount"], " passed, ", report["TestsFailedCount"], " failed, ", Round[report["TimeElapsed"], 0.1]];
DeleteDirectory[tmp, DeleteContents -> True];
Exit[If[report["AllTestsSucceeded"], 0, 1]];
