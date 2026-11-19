#!/usr/bin/env wolframscript
(* Moved poles. A correct fix of a lower sector S, I'_S = I_S + lam_1 I_1 + lam_2 I_2, changes every row r that couples
   to it by -R_rS lam: a factor of R_rS goes into new columns of row r. When row r belongs to a sector U whose rows had
   that factor before the change, the gate defers the new pole entry to U (a moved pole) if U can still change (not
   flagged, not fixed by an accepted change, no frozen family) and the census as a whole loses bad entries; U's poles
   need not factor through a proper subset of its masters. A change whose determinant is not an eps-monomial defers in
   the same way. Planted data: the one-loop massless box family of the maximal-cut-basis examples (the two bubbles, labels 1
   and 2, and s t times the box, label 3: the sector S) and the massless double box family (one master, label 4: the
   sector U, whose rows couple to the box family's masters, as through a symmetry of its subsectors), one derivative
   (d/dt). A change is planted as new masters J' = N J with a target DE R' in the new basis: the old slice is
   N^-1 R' N, and the candidate reduces to N[[3]] with the derivative N[[3]].R_old. lam carries g = 1 - 2 eps (the
   poles of the box row it removes); the double-box row has f = 1 + 4 eps in the box's column, which lam moves into the
   column of the t-bubble. Checked: the gate through PFBTryChange (accepted, refused when U never had the factor, when U
   is flagged or frozen, when the census does not lose bad entries; accepted with a determinant that is not an
   eps-monomial), PFBDeferredObligations, the
   scans, CHANGES.md and the sector page. No IBP reduction, no FiniteFlow.
   usage: bin/ws tests/moved_poles.wls        exit code 0 when every test passes *)
Get[FileNameJoin[{ParentDirectory[DirectoryName[$InputFileName]], "lib", "PoleFreeBasis.wl"}]];
$PFBVerbose = False;
exDir = FileNameJoin[{ParentDirectory[ParentDirectory[DirectoryName[$InputFileName]]], "maximal-cut-basis", "examples"}];
tmp = CreateDirectory[];
loadSystem[name_, extra_ : <||>] := (Put[{j[box, 1, 0, 1, 0], j[box, 0, 1, 0, 1], s t j[box, 1, 1, 1, 1]}, FileNameJoin[{tmp, name <> "_box.m"}]];
  Put[{s^2 t j[dbox, 1, 1, 1, 1, 1, 1, 1, 0, 0]}, FileNameJoin[{tmp, name <> "_dbox.m"}]];
  Put[Join[<|"Name" -> name, "Families" -> {<|"Name" -> "box", "Family" -> FileNameJoin[{exDir, "box-one-loop", "family.wl"}], "Masters" -> name <> "_box.m"|>,
      <|"Name" -> "dbox", "Family" -> FileNameJoin[{exDir, "doublebox-massless", "family.wl"}], "Masters" -> name <> "_dbox.m"|>}|>, extra], FileNameJoin[{tmp, name <> ".wl"}]];
  PFBReadSystem[FileNameJoin[{tmp, name <> ".wl"}]]);
sys = loadSystem["planted"];
sysF = loadSystem["frozen", <|"Frozen" -> {"dbox"}|>];
keyS = {box, {1, 1, 1, 1}}; keyU = {dbox, {1, 1, 1, 1, 1, 1, 1, 0, 0}};
P = {s -> 1, t -> 3/7}; P2 = {s -> 1, t -> 5/11}; P3 = {s -> 1, t -> 2/13};   (* the slice point and two extra points *)
slice[R_] := <|"R" -> {R}, "Derivatives" -> {t}, "Point" -> P, "Labels" -> {1, 2, 3, 4}, "Index" -> <|1 -> 1, 2 -> 2, 3 -> 3, 4 -> 4|>, "History" -> {}|>;
checkOf[gt_, name_] := SelectFirst[gt["Checks"], #["Name"] === name &];
failing[gt_] := #["Name"] & /@ Select[gt["Checks"], ! #["Pass"] &];
oldOf[Rnew_, N_] := Together[Inverse[N] . Rnew . N];
f = 1 + 4 eps; g = 1 - 2 eps;
lam1 = 1/g; lam2 = 2/g;
nOf[n33_ : 1, l2_ : lam2] := {{1, 0, 0, 0}, {0, 1, 0, 0}, {lam1, l2, n33, 0}, {0, 0, 0, 1}};
cand = j[box, 1, 1, 1, 2]; coef = s t^2;
(* a reduction at a point with the candidate coef * cand = N[[3]] . old *)
redOf[Rold_, N_, pt_ : P] := With[{c0 = coef /. pt, dc = D[coef, t] /. pt}, <|"Masters" -> ut /@ {1, 2, 3, 4}, "Point" -> pt, "Invariants" -> {t}, "Focus" -> {1, 2, 3, 4},
   "Dm" -> {Rold}, "Pool" -> {cand}, "Rp" -> {N[[3]]/c0}, "dRp" -> {{Together[(N[[3]] . Rold - dc N[[3]]/c0)/c0]}}|>];
newRun[sysX_, Rold_, name_, flagged_ : <||>] := Module[{dir = CreateDirectory[FileNameJoin[{tmp, name}]], st, sl = slice[Rold]},
  st = <|"Run" -> "none", "Created" -> PFBTimeStamp[], "Slices" -> {}, "Current" -> None, "Censuses" -> {}, "Accepted" -> {}, "Pending" -> {},
    "Rejected" -> {}, "Flagged" -> flagged, "Approval" -> False, "Regenerated" -> False|>;
  st = PFBStoreSlice[dir, st, sl, PFBCensus[sysX, sl], "start"];
  <|"Run" -> <|"MaxEpsDegree" -> 2|>, "System" -> sysX, "Dir" -> dir, "State" -> st|>];
try[sysX_, Rold_, N_, name_, flagged_ : <||>] := PFBTryChange[newRun[sysX, Rold, name, flagged], keyS, <|3 -> coef cand|>, <|"Rung" -> 3, "Provenance" -> "planted"|>,
  <|"Reds" -> (redOf[Rold, N, #] & /@ {P, P2, P3})|>];

(* the target DE after the change: the box row clean, the double-box row with f in the box's column and, after the
   change, in the columns of both bubbles *)
A43 = eps (1 - 2 eps)/f;
Rt = {{-eps, 0, 0, 0}, {0, -2 eps, 0, 0}, {eps, eps, -3 eps, 0}, {3 eps/f, 1 - 2 eps/f, A43, -eps}};
Rm = oldOf[Rt, nOf[]];

tests = {
  VerificationTest[sys =!= $Failed && sysF =!= $Failed && Length[PFBMasters[sys]] == 4 && PFBMaster[sys, 4]["SectorKey"] === keyU, True, TestID -> "the planted systems load"],
  (* the old slice: g in the box row (removed by the change), f in the double-box row in the columns of the s-bubble and of
     the box; the t-bubble's column of that row is clean before the change and has f after it *)
  VerificationTest[{PFBCensus[sys, slice[Rm]]["BadEntries"], PFBCensus[sys, slice[Rt]]["BadEntries"]},
    {{{1, 3, 1, {g}}, {1, 3, 2, {g}}, {1, 4, 1, {f}}, {1, 4, 3, {f}}}, {{1, 4, 1, {f}}, {1, 4, 2, {f}}, {1, 4, 3, {f}}}},
    TestID -> "the planted slices: g removed from the box row, f moved into a new column of the double-box row"]
};

rM = try[sys, Rm, nOf[], "moved"];
AppendTo[tests, VerificationTest[{rM["Status"], failing[rM["Gate"]], checkOf[rM["Gate"], "rows"]["Moved"], checkOf[rM["Gate"], "rows"]["Deferred"]},
  {"accepted", {}, <|keyU -> <|"Rows" -> {4}, "Factors" -> {f}, "Entries" -> {{t, 4, 2, f}}|>|>, <||>}, TestID -> "moved pole: accepted, the new entry deferred as a moved pole"]];
AppendTo[tests, VerificationTest[StringContainsQ[checkOf[rM["Gate"], "rows"]["Detail"], "moved poles deferred to their own sectors: dbox/j111111100 rows {ut[4]} (factors {1 + 4*eps}, which its rows had before, in 1 new entry)"],
  True, TestID -> "moved pole: the gate says so"]];
AppendTo[tests, VerificationTest[PFBDeferredObligations[rM["Context"]["State"], keyU], {<|"Change" -> 1, "Kind" -> "moved", "Rows" -> {4}, "Factors" -> {f}, "Entries" -> {{t, 4, 2, f}}|>},
  TestID -> "moved pole: an obligation of the upper sector"]];

(* the upper sector never had the factor: lam_2 = 1/f carries it, and the double-box row was clean *)
lamN = 1/f;
RtN = {{-eps, 0, 0, 0}, {0, -2 eps, 0, 0}, {eps, eps, -2 eps, 0}, {1 - eps lam1, 1 - eps lamN, eps, -eps}};
RN = oldOf[RtN, nOf[1, lamN]];
rN = try[sys, RN, nOf[1, lamN], "never"];
AppendTo[tests, VerificationTest[{PFBCensus[sys, slice[RN]]["BadEntries"], rN["Status"], failing[rN["Gate"]],
    StringContainsQ[checkOf[rN["Gate"], "rows"]["Detail"], "new factors {1 + 4*eps} that the change did not remove from its own rows and that this sector's rows did not have"]},
  {{{1, 3, 1, {g}}}, "rejected", {"rows", "census"}, True}, TestID -> "a factor the upper sector never had: refused as before"]];

(* the upper sector flagged, or in a frozen family *)
AppendTo[tests, VerificationTest[With[{r = try[sys, Rm, nOf[], "flagged", <|keyU -> <|"Reason" -> "planted", "Tried" -> {}, "Date" -> "-"|>|>]},
    {r["Status"], failing[r["Gate"]], StringContainsQ[checkOf[r["Gate"], "rows"]["Detail"], "flagged, or already fixed by an accepted change"]}],
  {"rejected", {"rows", "census"}, True}, TestID -> "moved pole: refused when the upper sector is flagged"]];
AppendTo[tests, VerificationTest[With[{r = try[sysF, Rm, nOf[], "frozen"]},
    {r["Status"], failing[r["Gate"]], StringContainsQ[checkOf[r["Gate"], "rows"]["Detail"], "a frozen family: its masters never change"]}],
  {"rejected", {"rows", "census"}, True}, TestID -> "moved pole: refused when the upper sector's family is frozen"]];

(* the census as a whole must lose bad entries: here the s-bubble's column of the double-box row loses f and the
   t-bubble's gains it, 3 bad entries before and after *)
RtX = ReplacePart[Rt, {4, 1} -> 1 - eps/f]; RX = oldOf[RtX, nOf[]];
rX = try[sys, RX, nOf[], "notloses"];
AppendTo[tests, VerificationTest[{rX["Status"], failing[rX["Gate"]], StringContainsQ[checkOf[rX["Gate"], "rows"]["Detail"], "but the census as a whole does not lose bad entries (3 -> 3)"]},
  {"rejected", {"rows", "census"}, True}, TestID -> "moved pole: refused when the census does not lose bad entries"]];

(* the same change with the box master also divided by w = 1 + 3 eps, which the double-box row had in the box's column:
   det T is not an eps-monomial, and the moved pole is deferred all the same *)
w = 1 + 3 eps;
RW = oldOf[Rt, nOf[1/w]];
rW = try[sys, RW, nOf[1/w], "weight"];
AppendTo[tests, VerificationTest[{MemberQ[PFBCensus[sys, slice[RW]]["BadEntries"], {1, 4, 3, {f, w}} | {1, 4, 3, {w, f}}], rW["Status"], failing[rW["Gate"]],
    checkOf[rW["Gate"], "rows"]["Moved"], PFBDetMonomialQ[rW["Record"]["Determinant"]]},
  {True, "accepted", {}, <|keyU -> <|"Rows" -> {4}, "Factors" -> {f}, "Entries" -> {{t, 4, 2, f}}|>|>, False},
  TestID -> "moved pole: deferred the same way when the determinant is not an eps-monomial"]];

(* the scans preview the deferral *)
AppendTo[tests, VerificationTest[With[{rd = redOf[Rm, nOf[]]}, Lookup[First[PFBScanSets[sys, slice[Rm], rd, PFBCalibrate[slice[Rm], rd], keyS, {<|3 -> coef cand|>},
    <|"FullCensus" -> True|>]["Results"]], {"bad", "newBad", "deferred"}]], {0, 0, 1}, TestID -> "scan: the moved pole counted as deferred"]];

(* CHANGES.md and the upper sector's page *)
Quiet[PFBMakeReports[rM["Context"]["Dir"], rM["Context"]["System"], rM["Context"]["State"]]];
AppendTo[tests, VerificationTest[{StringContainsQ[Import[FileNameJoin[{rM["Context"]["Dir"], "CHANGES.md"}], "Text"],
      "Moved poles deferred to the sectors above (factors their rows had before, now in new columns): `dbox/j111111100` rows {ut[4]}, factors `{1 + 4*eps}`, entries dt(ut[4], ut[2])"],
    StringContainsQ[Import[FileNameJoin[{PFBSectorDir[rM["Context"]["Dir"], keyU], "sector.html"}], "Text"], "moved poles: factors {1 + 4*eps}, which these rows had before, now in 1 new entry"]},
  {True, True}, TestID -> "records: CHANGES.md and the upper sector's page show the moved pole"]];

report = TestReport[tests];
Do[With[{r = report["TestResults"][id]},
    Print[If[r["Outcome"] === "Success", "PASS ", "FAIL "], r["TestID"], If[r["Outcome"] === "Success", "",
      "\n     got " <> ToString[Short[r["ActualOutput"], 3], InputForm] <> "\n     expected " <> ToString[Short[r["ExpectedOutput"], 3], InputForm]]]],
  {id, Keys[report["TestResults"]]}];
Print[report["TestsSucceededCount"], " passed, ", report["TestsFailedCount"], " failed, ", Round[report["TimeElapsed"], 0.1]];
DeleteDirectory[tmp, DeleteContents -> True];
Exit[If[report["AllTestsSucceeded"], 0, 1]];
