#!/usr/bin/env wolframscript
(* The integration test of Kira at the slice point, run by tests/kira_vs_finiteflow.sh (mode in PFB_KVF_MODE, folder in
   PFB_KVF_DIR, tool paths in PFB_KVF_PATHS).
   write: a planted system, the one-loop massless box of the maximal-cut-basis examples with masters that are
     combinations (a dotted bubble, a bubble, the box plus both bubbles) and its image p1 <-> p2 (t -> u = -s - t) with
     masters of its own (the u-channel bubble and box); five jobs with a small pool, the derivatives in s and t:
       ff, kira            the box's subtree at the slice point and one more point, "FiniteFlow" and Automatic;
       image_ff, image_kira the image's u-channel bubble at the slice point only (Kira reduces the base family at the
                           mapped point; a job with only the slice point learns nothing);
       image_top           the image's top sector: LiteRed maps its s-channel bubble onto the base family, so the
                           subtree holds two families and the slice point falls back on FiniteFlow, saying why;
       kira_fail           image_kira with a Kira configuration that names an invariant the point lacks: Kira gives
                           no reduction, FiniteFlow reduces the point and kira_fallback.m keeps the reason; the .sh
                           runs it twice, and the second run goes to FiniteFlow at once.
   check: Kira's red_1.m equals FiniteFlow's exactly (Masters, Labels, Focus, Pool, Dm, Rp, dRp), the point after it is
     FiniteFlow's in both and FiniteFlow kept Kira's slice point, the statuses say which reducer ran where, the Kira
     reductions calibrate exactly against a slice made from FiniteFlow's and satisfy the Euler relation, the run's
     ledger (citations.m: the folder is a pole-free run, with a state.m) and status.m "Tools" credit Kira and Fermat for
     the jobs whose slice point Kira reduced, never for the fallback, LiteRed and LiteIBP for every job and FiniteFlow
     where it reduced a point, and the timings of both reducers are printed. *)
Get[FileNameJoin[{ParentDirectory[DirectoryName[$InputFileName]], "lib", "PoleFreeBasis.wl"}]];
$PFBVerbose = False;
mode = Environment["PFB_KVF_MODE"]; dir = Environment["PFB_KVF_DIR"];
If[! StringQ[dir] || ! DirectoryQ[dir], Print["kira_vs_finiteflow.wls: run it through tests/kira_vs_finiteflow.sh"]; Exit[1]];
boxFile = FileNameJoin[{ParentDirectory[ParentDirectory[DirectoryName[$InputFileName]]], "maximal-cut-basis", "examples", "box-one-loop", "family.wl"}];
P = {s -> 1409, t -> 1637}; P2 = {s -> 1013, t -> 1777};

writeSystem[] := (
  Put[{s j[box, 2, 0, 1, 0], j[box, 0, 1, 0, 1], s t j[box, 1, 1, 1, 1] + j[box, 1, 0, 1, 0] - j[box, 0, 1, 0, 1]}, FileNameJoin[{dir, "box.m"}]];
  Put[{j[boxu, 0, 1, 0, 1], -s (s + t) j[boxu, 1, 1, 1, 1]}, FileNameJoin[{dir, "boxu.m"}]];
  Put[<|"Name" -> "planted", "Families" -> {<|"Name" -> "box", "Family" -> boxFile, "Masters" -> "box.m"|>,
      <|"Name" -> "boxu", "ImageOf" -> "box", "MomentumMap" -> {p1 -> p2, p2 -> p1}, "Masters" -> "boxu.m"|>}|>, FileNameJoin[{dir, "system.wl"}]]);

If[mode === "write",
  With[{p = Environment["PFB_KVF_PATHS"]}, MCBLoadPaths[If[StringQ[p] && p =!= "", p, Automatic]]];
  If[! AllTrue[{"FiniteFlow", "FiniteFlowLibrary", "LiteRed", "LiteIBP", "kira", "fer64"}, MCBAvailableQ],
    Print["kira_vs_finiteflow: tools missing: ", Select[{"FiniteFlow", "FiniteFlowLibrary", "LiteRed", "LiteIBP", "kira", "fer64"}, ! MCBAvailableQ[#] &]]; Exit[1]];
  writeSystem[];
  (* a pole-free run folder (state.m): the jobs append the tools they credit to its ledger *)
  Put[<|"Created" -> PFBTimeStamp[], "Slices" -> {}, "Current" -> None, "Accepted" -> {}, "Pending" -> {}, "Rejected" -> {}, "Flagged" -> <||>|>, FileNameJoin[{dir, "state.m"}]];
  Module[{sys = PFBReadSystem[FileNameJoin[{dir, "system.wl"}]], common, jobs},
    common = <|"Derivatives" -> {s, t}, "TimeLimit" -> 900, "Threads" -> 2, "Kernels" -> 1, "Seeds" -> <|"Rank" -> 2, "Dots" -> 1|>|>;
    jobs = {
      PFBSubtreeJob[sys, dir, Join[common, <|"Name" -> "ff", "Roots" -> {{box, {1, 1, 1, 1}}}, "Points" -> {P, P2}, "Reducer" -> "FiniteFlow", "PoolExtra" -> {j[box, 2, 2, 1, 1]}|>]],
      PFBSubtreeJob[sys, dir, Join[common, <|"Name" -> "kira", "Roots" -> {{box, {1, 1, 1, 1}}}, "Points" -> {P, P2}, "PoolExtra" -> {j[box, 2, 2, 1, 1]}|>]],
      PFBSubtreeJob[sys, dir, Join[common, <|"Name" -> "image_ff", "Roots" -> {{boxu, {0, 1, 0, 1}}}, "Points" -> {P}, "Reducer" -> "FiniteFlow"|>]],
      PFBSubtreeJob[sys, dir, Join[common, <|"Name" -> "image_kira", "Roots" -> {{boxu, {0, 1, 0, 1}}}, "Points" -> {P}|>]],
      PFBSubtreeJob[sys, dir, Join[common, <|"Name" -> "image_top", "Roots" -> {{boxu, {1, 1, 1, 1}}}, "Points" -> {P}|>]],
      PFBSubtreeJob[sys, dir, Join[common, <|"Name" -> "kira_fail", "Roots" -> {{boxu, {0, 1, 0, 1}}}, "Points" -> {P}|>]]};
    If[MemberQ[jobs, $Failed], Print["kira_vs_finiteflow: a job was not written"]; Exit[1]];
    With[{f = FileNameJoin[{Last[jobs], "job.m"}]}, Module[{jb = Get[f]}, jb["Kira"]["Names"] = Append[jb["Kira"]["Names"], "zz" -> "zz"]; Put[jb, f]]];
    Scan[Export[FileNameJoin[{#, "command.sh"}], PFBSubtreeCommand[#] <> "\n", "Text"] &, jobs]];
  Exit[0]];

(* ---- check ---- *)
sys = PFBReadSystem[FileNameJoin[{dir, "system.wl"}]];
jd[n_] := FileNameJoin[{dir, "jobs", n}];
red[n_, ip_] := Replace[PFBReadRed[jd[n], ip], Except[_Association] -> <||>];
status[n_] := PFBSubtreeStatus[jd[n]];
log[n_] := Replace[Quiet@Import[FileNameJoin[{jd[n], "run.log"}], "Text"], Except[_String] -> ""];
zeroQ[x_] := AllTrue[Flatten[{Together[x]}], # === 0 &];
(* the same reduction: the same masters, rows and pool, and every entry equal exactly in eps *)
sameRed[a_, b_] := And[Length[a] > 0, Length[b] > 0, Sequence @@ (a[#] === b[#] & /@ {"Masters", "Labels", "Focus", "Pool", "Point", "Invariants"}),
   Sequence @@ (Dimensions[a[#]] === Dimensions[b[#]] && zeroQ[a[#] - b[#]] & /@ {"Dm", "Rp", "dRp"})];
times = Association[Rule @@@ Cases[StringSplit /@ StringSplit[Replace[Quiet@Import[FileNameJoin[{dir, "times.txt"}], "Text"], Except[_String] -> ""], "\n"],
     {n_, rc_, sec_} :> {n, ToExpression /@ {rc, sec}}]];
pointTime[n_, ip_] := Lookup[SelectFirst[Replace[Quiet@Get[FileNameJoin[{jd[n], "times.m"}]], Except[_List] -> {}], #["Point"] === ip &, <||>], {"WallSeconds", "Reducer"}, Missing[]];
{ff1, ff2, k1, k2, iff1, ik1, it1} = {red["ff", 1], red["ff", 2], red["kira", 1], red["kira", 2], red["image_ff", 1], red["image_kira", 1], red["image_top", 1]};
kf1 = red["kira_fail", 1]; kfMark = Quiet@Get[FileNameJoin[{jd["kira_fail"], "kira_fallback.m"}]];
(* the run's ledger: the tools each job credited, by its step *)
ledgerTools = Select[Replace[Quiet@ReadList[FileNameJoin[{dir, "citations.m"}]], Except[_List] -> {}], AssociationQ[#] && Lookup[#, "kind", None] === "tool" &];
creditedBy[n_] := Sort[DeleteDuplicates[Lookup[Select[ledgerTools, #["step"] === "reduction job " <> n &], "tool"]]];
withKiraTools = Sort[{"kira", "fer64", "FiniteFlow", "LiteRed", "LiteIBP"}]; kiraOnlyTools = Sort[{"kira", "fer64", "LiteRed", "LiteIBP"}];
ffTools = Sort[{"FiniteFlow", "LiteRed", "LiteIBP"}];

Print["job (exit code, seconds with its kernel and the licence wait): ", times];
Print["slice point, wall-clock seconds {seconds, reducer}: FiniteFlow ", pointTime["ff", 1], ", Kira ", pointTime["kira", 1],
  "; image: FiniteFlow ", pointTime["image_ff", 1], ", Kira ", pointTime["image_kira", 1]];

tests = {
  VerificationTest[Lookup[times, #, {"?"}][[1]] & /@ {"ff", "kira", "image_ff", "image_kira", "image_top", "kira_fail"}, {0, 0, 0, 0, 0, 0}, TestID -> "every job exits with 0"],
  VerificationTest[status[#]["Status"] & /@ {"ff", "kira", "image_ff", "image_kira", "image_top", "kira_fail"}, ConstantArray["done", 6], TestID -> "every job is done"],
  VerificationTest[{AssociationQ[kfMark] && StringContainsQ[kfMark["Reason"], "no value to the invariant(s) zz"], Lookup[kf1, "Reducer", None], sameRed[kf1, iff1],
      StringContainsQ[Lookup[status["kira_fail"], "KiraFallback", ""], "in an earlier run of this job (kira_fallback.m)"], status["kira_fail"]["Reducers"]},
    {True, "FiniteFlow", True, True, {"FiniteFlow"}},
    TestID -> "Kira without a reduction: FiniteFlow reduces the point, kira_fallback.m keeps why, and the job's next run skips Kira"],
  VerificationTest[Lookup[#, "Reducer", None] & /@ {ff1, ff2, k1, k2, iff1, ik1, it1}, {"FiniteFlow", "FiniteFlow", "Kira", "FiniteFlow", "FiniteFlow", "Kira", "FiniteFlow"},
    TestID -> "red_<ip>.m says which reducer made it"],
  VerificationTest[{status["kira"]["Reducers"], status["image_kira"]["Reducers"]}, {{"Kira", "FiniteFlow"}, {"Kira"}}, TestID -> "status.m lists the reducer of every point"],
  VerificationTest[{k1["Masters"], k1["Focus"], Length[k1["Pool"]] > 5, Length[k1["dRp"]]}, {{ut[1], ut[2], ut[3]}, {1, 2, 3}, True, 2}, TestID -> "the box: Kira's reduction has the system's masters"],
  VerificationTest[sameRed[k1, ff1], True, TestID -> "the box: Kira's slice point equals FiniteFlow's exactly"],
  VerificationTest[sameRed[k2, ff2], True, TestID -> "the box: the point after it is FiniteFlow's in both jobs"],
  VerificationTest[{StringContainsQ[log["kira"], "point 1: Kira's reduction (the same masters and pool as FiniteFlow's)"], status["kira"]["Kept"]}, {True, {}},
    TestID -> "the box: FiniteFlow keeps Kira's slice point and reduces only the next point"],
  VerificationTest[sameRed[ik1, iff1], True, TestID -> "the image: Kira at the mapped point equals FiniteFlow exactly"],
  VerificationTest[{StringContainsQ[log["image_kira"], "as box at the mapped point"], DirectoryQ[FileNameJoin[{jd["image_kira"], "ibps"}]], FileExistsQ[FileNameJoin[{jd["image_kira"], "memory.m"}]],
      DirectoryQ[FileNameJoin[{jd["image_kira"], "kira"}]], FileExistsQ[FileNameJoin[{jd["image_kira"], "kira.log"}]]},
    {True, False, False, False, True}, TestID -> "the image: no identities and no learning for a job with only the slice point; Kira's folder removed, its log kept"],
  VerificationTest[{StringContainsQ[log["image_top"], "slice point: FiniteFlow (the subtree's integrals lie in 2 families (box, boxu)"], MemberQ[it1["Masters"], ut[1]]},
    {True, True}, TestID -> "the image's top sector: two families, FiniteFlow, saying why"],
  VerificationTest[PFBCalibrate[PFBSliceFromRed[sys, ff1], k1]["Status"], "exact", TestID -> "the box: Kira's reduction calibrates exactly"],
  VerificationTest[PFBCalibrate[PFBSliceFromRed[sys, iff1], ik1]["Status"], "exact", TestID -> "the image: Kira's reduction calibrates exactly"],
  VerificationTest[{PFBEulerCheck[sys, k1]["Pass"], PFBEulerCheck[sys, ik1]["Pass"]}, {True, True}, TestID -> "Kira's reductions satisfy the Euler relation"],
  VerificationTest[creditedBy /@ {"kira", "image_kira", "kira_fail", "ff", "image_ff", "image_top"}, {withKiraTools, kiraOnlyTools, ffTools, ffTools, ffTools, ffTools},
    TestID -> "the ledger: Kira and Fermat for the jobs whose slice point Kira reduced, not for the fallback; LiteRed and LiteIBP always; FiniteFlow where it reduced"],
  VerificationTest[{Union[Lookup[ledgerTools, "sector"]], Sort[Lookup[status[#], "Tools", {}]] & /@ {"kira", "image_kira", "kira_fail", "ff"}},
    {{"whole run"}, {withKiraTools, kiraOnlyTools, ffTools, ffTools}}, TestID -> "status.m \"Tools\" says the same; jobs without a sector key credit the whole run"],
  VerificationTest[With[{es = Select[CoreReadCitations[dir], #["kind"] === "tool" &]}, {Sort[DeleteDuplicates[Lookup[es, "tool"]]], Union[Lookup[es, "part"]]}],
    {withKiraTools, {"cite"}}, TestID -> "the run's reader: every tool the jobs ran is cited"]
};

report = TestReport[tests];
Print["kira_vs_finiteflow: ", report["TestsSucceededCount"], " passed, ", report["TestsFailedCount"], " failed"];
Do[If[r["Outcome"] =!= "Success", Print["FAILED: ", r["TestID"], "\n  expected ", r["ExpectedOutput"], "\n  got      ", Short[r["ActualOutput"], 5]]], {r, Values[report["TestResults"]]}];
If[report["TestsFailedCount"] > 0, Do[Print["---- ", n, " run.log (end)\n", StringTake[log[n], -UpTo[3000]]], {n, {"kira", "image_kira", "image_top"}}]];
Exit[If[report["TestsFailedCount"] == 0, 0, 1]];
