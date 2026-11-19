#!/usr/bin/env wolframscript
(* Kira at the slice point (lib/PFB/Kira.wl, PFBSubtreeJob), without Kira or FiniteFlow: the choice of the reducer
   (Automatic: Kira when Kira and Fermat are found and the subtree lies in one family, FiniteFlow otherwise, with the
   reason; "Kira" refuses where Kira does not apply), the job's Kira configuration (uncut, written by maximal-cut-basis;
   an image family as its base at the mapped point), the seeds, the job and target files, the command, and the reading
   of Kira's output: planted outputs in Kira's format (rules, masters, unreduced integrals, limits), the vectors on
   Kira's masters, and the projection onto the system's masters (chosen as FiniteFlow chooses them, the later first),
   with planted relations whose answer is known. The tool paths are planted files: no tool runs.
   The comparison with FiniteFlow on a real reduction is tests/kira_vs_finiteflow.sh.
   usage: bin/ws tests/kira_slice.wls        exit code 0 when every test passes *)
Get[FileNameJoin[{ParentDirectory[DirectoryName[$InputFileName]], "lib", "PoleFreeBasis.wl"}]];
$PFBVerbose = False;
boxFile = FileNameJoin[{ParentDirectory[ParentDirectory[DirectoryName[$InputFileName]]], "maximal-cut-basis", "examples", "box-one-loop", "family.wl"}];
tmp = CreateDirectory[];

(* ---- planted tools: files that exist, nothing runs ---- *)
Do[With[{f = FileNameJoin[{tmp, "tools", t}]}, Quiet@CreateDirectory[DirectoryName[f], CreateIntermediateDirectories -> True]; Export[f, "", "Text"]; MCBSetPath[t, f]],
  {t, {"FiniteFlow", "FiniteFlowLibrary", "LiteRed", "LiteIBP", "kira", "fer64"}}];

(* ---- a planted system: the one-loop box and its image p1 <-> p2 (t -> u = -s - t), with the image's own masters
   (the u-channel bubble and box) ---- *)
Put[{s j[box, 2, 0, 1, 0], j[box, 0, 1, 0, 1], s t j[box, 1, 1, 1, 1] + j[box, 1, 0, 1, 0] - j[box, 0, 1, 0, 1]}, FileNameJoin[{tmp, "box.m"}]];
Put[{j[boxu, 0, 1, 0, 1], -s (s + t) j[boxu, 1, 1, 1, 1]}, FileNameJoin[{tmp, "boxu.m"}]];
Put[<|"Name" -> "planted", "Families" -> {<|"Name" -> "box", "Family" -> boxFile, "Masters" -> "box.m"|>,
    <|"Name" -> "boxu", "ImageOf" -> "box", "MomentumMap" -> {p1 -> p2, p2 -> p1}, "Masters" -> "boxu.m"|>}|>, FileNameJoin[{tmp, "system.wl"}]];
sys = PFBReadSystem[FileNameJoin[{tmp, "system.wl"}]];
P = {s -> 1409, t -> 1637};
writeJob[name_, spec_, run_ : tmp] := PFBSubtreeJob[sys, run, Join[<|"Name" -> name, "Points" -> {P}, "Derivatives" -> {s, t}|>, spec]];
jobOf[d_] := If[StringQ[d], Get[FileNameJoin[{d, "job.m"}]], d];
baseJob = jobOf[writeJob["base", <|"Roots" -> {{box, {1, 1, 1, 1}}}|>]];
imageJob = jobOf[writeJob["image", <|"Roots" -> {{boxu, {0, 1, 0, 1}}}|>]];
bothJob = jobOf[writeJob["both", <|"SectorKey" -> {box, {1, 1, 1, 1}}|>]];
forced = writeJob["forced", <|"SectorKey" -> {box, {1, 1, 1, 1}}, "Reducer" -> "Kira"|>];
learnJob = jobOf[writeJob["learn", <|"Roots" -> {{box, {1, 1, 1, 1}}}, "LearnOnly" -> True|>]];
ffJob = jobOf[writeJob["ff", <|"Roots" -> {{box, {1, 1, 1, 1}}}, "Reducer" -> "FiniteFlow"|>]];
(* run.wl's "Reducer", through run_info.m, is the default of a job written without one *)
runDir = FileNameJoin[{tmp, "run"}]; CreateDirectory[runDir];
Put[<|"Run" -> <|"Reducer" -> "FiniteFlow"|>|>, FileNameJoin[{runDir, "run_info.m"}]];
runDefaultJob = jobOf[writeJob["rundefault", <|"Roots" -> {{box, {1, 1, 1, 1}}}|>, runDir]];
noKiraJob = Block[{}, MCBSetPath["kira", FileNameJoin[{tmp, "tools", "nokira"}]];
  With[{r = jobOf[writeJob["nokira", <|"Roots" -> {{box, {1, 1, 1, 1}}}|>]]}, MCBSetPath["kira", FileNameJoin[{tmp, "tools", "kira"}]]; r]];

(* ---- Kira's output, planted in its format: the box at s = 1409, t = 1637, d symbolic ---- *)
kiraTarget = "{\nbox[2,1,1,1] -> \n + box[1,1,1,1]*((-d+5)/1409)\n + box[0,1,0,1]*((4*d^2-32*d+60)/(3775794521*d-22654767126))\n,\n" <>
  "box[1,1,1,0] -> \n + box[1,0,1,0]*((-2*d+6)/(1409*d-5636))\n,\nbox[2,0,1,0] -> \n + box[1,0,1,0]*((-d+3)/1409)\n}\n";
kiraMasters = "box[1,0,1,0] #  5\nbox[0,1,0,1] # 10\nbox[1,1,1,1] # 15\n";
kiraLog = "This requested integral is a master integral: box[1,0,1,0] # 5\nunreduced integrals: 0.\n\nTotal time:\n( 4.6 s )\n";
intOf = (j[box, Sequence @@ #] &);
res = PFBKiraResult[<|"ExitCode" -> 0, "Log" -> kiraLog, "Results" -> kiraTarget, "MastersText" -> kiraMasters, "Family" -> "box", "Integral" -> intOf,
   "Dimension" -> 4 - 2 eps|>];
targets = {j[box, 2, 1, 1, 1], j[box, 1, 1, 1, 0], j[box, 2, 0, 1, 0], j[box, 1, 0, 1, 0], j[box, 0, 1, 0, 1], j[box, 1, 1, 1, 1]};
vecs = PFBKiraVectors[targets, res["Rules"], res["Masters"]];
(* the masters of the system on Kira's masters at P: their definitions, with eps in the coefficients of the reductions *)
defs = {s j[box, 2, 0, 1, 0], j[box, 0, 1, 0, 1], s t j[box, 1, 1, 1, 1] + j[box, 1, 0, 1, 0] - j[box, 0, 1, 0, 1]};
U = PFBKiraExprVector[#, P, vecs, 3] & /@ defs;
(* the masters on themselves, and a dotted box on the system's masters, from its planted reduction *)
dottedK = PFBKiraExprVector[j[box, 2, 1, 1, 1], P, vecs, 3];
pr = PFBKiraProject[U, Append[U, dottedK]];
dotted = Last[pr["Rows"]];
(* planted projections: four masters of the system on three of Kira's, the first a copy of the last: FiniteFlow keeps
   the later one *)
Ua = {{2, 0, 0}, {0, 1 + eps, 0}, {eps, 0, 1/(1 - 2 eps)}};
Ub = Append[Ua, Ua[[1]] (3 + eps)];
(* a planted block structure: 5 masters of the system on 5 of Kira's, rows and columns shuffled, blocks of sizes 2, 1
   and 2 coupled downwards; rows planted on the masters, W0, give V = W0 . U, which the projection must give back *)
Ublk = Module[{m = {{1 + eps, 2, 0, 0, 0}, {eps, 3 - eps, 0, 0, 0}, {1/(1 - 2 eps), 0, 2 + eps, 0, 0}, {0, eps^2, 1, 1, 1 + eps}, {5, 0, 0, 2, 1/(1 + eps)}}},
   m[[{4, 1, 5, 3, 2}, {2, 5, 1, 4, 3}]]];
W0 = {{1, 0, eps, 0, 2/(1 + 3 eps)}, {0, 1/(2 - eps), 0, eps^2, 1}, {3, 0, 0, 0, 0}};

tests = {
  (* the choice *)
  VerificationTest[PFBReducerChoice[Automatic, <|"KiraAvailable" -> True, "Families" -> {box}|>][[{"Reducer", "Refused"}]], <|"Reducer" -> "Kira", "Refused" -> False|>,
    TestID -> "choice: Automatic, one family, Kira found -> Kira"],
  VerificationTest[With[{c = PFBReducerChoice[Automatic, <|"KiraAvailable" -> False, "Families" -> {box}|>]}, {c["Reducer"], StringContainsQ[c["Reason"], "Fermat"], c["Refused"]}],
    {"FiniteFlow", True, False}, TestID -> "choice: no Kira or Fermat -> FiniteFlow, saying why"],
  VerificationTest[With[{c = PFBReducerChoice[Automatic, <|"KiraAvailable" -> True, "Families" -> {box, boxu}|>]}, {c["Reducer"], StringContainsQ[c["Reason"], "2 families (box, boxu)"]}],
    {"FiniteFlow", True}, TestID -> "choice: two families -> FiniteFlow, saying why"],
  VerificationTest[With[{c = PFBReducerChoice[Automatic, <|"KiraAvailable" -> True, "Families" -> {box}, "SymmetryRules" -> 2|>]}, {c["Reducer"], StringContainsQ[c["Reason"], "symmetry rule"]}],
    {"FiniteFlow", True}, TestID -> "choice: symmetry rules inside the subtree -> FiniteFlow"],
  VerificationTest[PFBReducerChoice[Automatic, <|"KiraAvailable" -> True, "Families" -> {box}, #|>]["Reducer"] & /@ {"LearnOnly" -> True, "Analytic" -> True},
    {"FiniteFlow", "FiniteFlow"}, TestID -> "choice: learn-only and analytic jobs -> FiniteFlow"],
  VerificationTest[PFBReducerChoice[Automatic, <|"KiraAvailable" -> True, "Families" -> {boxu}, "KiraFamily" -> box|>]["Reducer"], "FiniteFlow",
    TestID -> "choice: a Kira configuration of another family -> FiniteFlow"],
  VerificationTest[PFBReducerChoice["Kira", <|"KiraAvailable" -> True, "Families" -> {box, boxu}|>][[{"Reducer", "Refused"}]], <|"Reducer" -> "FiniteFlow", "Refused" -> True|>,
    TestID -> "choice: \"Kira\" where Kira does not apply is refused"],
  VerificationTest[PFBReducerChoice["FiniteFlow", <|"KiraAvailable" -> True, "Families" -> {box}|>][[{"Reducer", "Refused"}]], <|"Reducer" -> "FiniteFlow", "Refused" -> False|>,
    TestID -> "choice: \"FiniteFlow\" is FiniteFlow"],
  (* the job writer *)
  VerificationTest[{baseJob["Reducer"], baseJob["ReducerNote"], KeyTake[baseJob["Kira"], {"Family", "KiraFamily", "D0", "InvariantMap", "Names"}],
      Lookup[baseJob["ToolPaths"], {"kira", "fer64"}] === {MCBPath["kira"], MCBPath["fer64"]}},
    {Automatic, "slice point: Kira (one family (box), Kira and Fermat found)", <|"Family" -> box, "KiraFamily" -> "box", "D0" -> 4, "InvariantMap" -> {}, "Names" -> {"s" -> "s", "t" -> "t"}|>, True},
    TestID -> "job: one family -> Kira, with its configuration and tool paths"],
  VerificationTest[With[{yf = baseJob["Kira"]["IntegralFamilies"]}, {StringContainsQ[yf, "top_level_sectors: [@TOPLEVEL@]"], StringContainsQ[yf, "cut_propagators"],
      StringContainsQ[yf, "(k + p1 + p2 + p3)^2"], StringContainsQ[baseJob["Kira"]["Kinematics"], "[[p1, p2], \"s/2\"]"]}],
    {True, False, True, True}, TestID -> "job: the configuration is the uncut family of maximal-cut-basis"],
  VerificationTest[KeyTake[imageJob["Kira"], {"Family", "KiraFamily", "InvariantMap"}], <|"Family" -> boxu, "KiraFamily" -> "box", "InvariantMap" -> {t -> -s - t}|>,
    TestID -> "job: an image family is reduced as its base, with the invariant map"],
  VerificationTest[{bothJob["Kira"], StringContainsQ[bothJob["ReducerNote"], "2 families"]}, {None, True}, TestID -> "job: a sector with its image -> FiniteFlow"],
  VerificationTest[forced, $Failed, TestID -> "job: \"Kira\" for a job of two families is refused"],
  VerificationTest[{learnJob["Reducer"], learnJob["Kira"], ffJob["Kira"], runDefaultJob["Reducer"], runDefaultJob["Kira"]}, {"FiniteFlow", None, None, "FiniteFlow", None},
    TestID -> "job: learn-only, \"FiniteFlow\" and run.wl's \"Reducer\""],
  VerificationTest[{noKiraJob["Kira"], StringContainsQ[noKiraJob["ReducerNote"], "not found"]}, {None, True}, TestID -> "job: without Kira -> FiniteFlow, saying why"],
  (* the files *)
  VerificationTest[PFBKiraMappedPoint[P, {t -> -s - t}], {s -> 1409, t -> -3046}, TestID -> "the mapped point of an image"],
  VerificationTest[PFBKiraMappedPoint[P, {}], P, TestID -> "the point of a base family"],
  VerificationTest[PFBKiraSeeds[{{2, 1, 1, 1}, {1, 1, 1, 0}, {1, 0, 1, -2}, {0, 1, 0, 3}}, {{1, 1, 1, 1}}, 3, 2], {{{1, 1, 1, 1}, 6, 3}},
    TestID -> "seeds: one root, r and s above the targets'"],
  VerificationTest[PFBKiraSeeds[{{1, 1, 0, 0}, {3, 0, 1, -1}, {0, 1, 0, 1}}, {{1, 1, 0, 0}}, 1, 1], {{{1, 1, 0, 0}, 3, 1}, {{1, 0, 1, 0}, 5, 2}, {{0, 1, 0, 1}, 3, 1}},
    TestID -> "seeds: the sectors of the targets outside the roots"],
  VerificationTest[{PFBKiraSectorID[{1, 0, 1, 1}], StringContainsQ[PFBKiraJobYAML["box", {{{1, 1, 1, 1}, 6, 3}}], {"{topologies: [box], sectors: [15], r: 6, s: 3}", "select_mandatory_list", "kira2math"}],
      PFBKiraTargetText["box", {{2, 1, 1, 1}, {1, 0, 1, -1}}]}, {13, True, "box[2,1,1,1]\nbox[1,0,1,-1]\n"}, TestID -> "job.yaml and the target file"],
  VerificationTest[PFBKiraCommand[<|"Kira" -> "/k/kira", "Fermat" -> "/k/fer64", "Limit" -> "/c/limit", "Threads" -> 2, "TimeLimit" -> 3600, "MemoryGB" -> 4.5,
      "Values" -> {"s" -> 1409, "mcbinv2" -> 3/7}|>],
    "FERMATPATH='/k/fer64' '/c/limit' --timeout 3600 --memory 4.5 -- '/k/kira' --parallel=2 --set_value='s=1409' --set_value='mcbinv2=3/7' job.yaml > kira.out 2>&1",
    TestID -> "the command: limits, Fermat and --set_value"],
  (* reading Kira's output *)
  VerificationTest[{res["Masters"], Sort[res["Rules"][[All, 1]]]}, {{j[box, 1, 0, 1, 0], j[box, 0, 1, 0, 1], j[box, 1, 1, 1, 1]}, Sort[{j[box, 2, 1, 1, 1], j[box, 1, 1, 1, 0], j[box, 2, 0, 1, 0]}]},
    TestID -> "result: the masters and the reduced targets"],
  VerificationTest[Together[(j[box, 2, 0, 1, 0] /. res["Rules"]) - (-(4 - 2 eps) + 3)/1409 j[box, 1, 0, 1, 0]], 0, TestID -> "result: d is 4 - 2 eps"],
  VerificationTest[PFBKiraParse["{\nbox[1,1] -> box[1,0]*(s - d)\n}", "box", intOf, 4 - 2 eps], $Failed, TestID -> "result: an invariant left in the result is refused"],
  VerificationTest[StringQ /@ {PFBKiraResult[<|"ExitCode" -> 124, "Family" -> "box"|>], PFBKiraResult[<|"ExitCode" -> 137, "Family" -> "box"|>], PFBKiraResult[<|"ExitCode" -> 1, "Family" -> "box"|>],
      PFBKiraResult[<|"ExitCode" -> 0, "Log" -> "unreduced integrals: 3.", "Results" -> kiraTarget, "Family" -> "box", "Integral" -> intOf, "Dimension" -> 4 - 2 eps|>]},
    {True, True, True, True}, TestID -> "result: limits, failures and unreduced integrals give no reduction"],
  VerificationTest[StringContainsQ[PFBKiraResult[<|"ExitCode" -> 124, "Family" -> "box", "TimeLimit" -> 60|>], "time limit (60 s"], True, TestID -> "result: the time limit is named"],
  VerificationTest[{vecs[j[box, 1, 0, 1, 0]], Together[vecs[j[box, 2, 1, 1, 1]] - {0, (4 (4 - 2 eps)^2 - 32 (4 - 2 eps) + 60)/(3775794521 (4 - 2 eps) - 22654767126), (-(4 - 2 eps) + 5)/1409}]},
    {{1, 0, 0}, {0, 0, 0}}, TestID -> "vectors: a master and a reduced target"],
  VerificationTest[StringQ[PFBKiraVectors[Append[targets, j[box, 3, 1, 1, 1]], res["Rules"], res["Masters"]]], True, TestID -> "vectors: a target Kira did not reduce"],
  (* the projection onto the system's masters *)
  VerificationTest[{pr["Selected"], Most[pr["Rows"]]}, {{1, 2, 3}, IdentityMatrix[3]}, TestID -> "projection: the system's masters on themselves"],
  VerificationTest[{U[[1]], Together[dotted . U - dottedK]}, {{2 eps - 1, 0, 0}, {0, 0, 0}},
    TestID -> "projection: a row on the system's masters gives back its reduction"],
  VerificationTest[With[{p = PFBKiraProject[Ub, Ua]}, {StringQ[p], AllTrue[{"Kira finds 3 masters in the subtree, the system has 4", "FiniteFlow"}, StringContainsQ[p, #] &]}], {True, True},
    TestID -> "projection: fewer masters of Kira than of the system (two equal masters): no subset chosen, FiniteFlow reduces the point"],
  VerificationTest[With[{p = PFBKiraProject[Ublk, Together[W0 . Ublk]]}, {p["Selected"], Together[p["Rows"] - W0]}], {Range[5], ConstantArray[0, {3, 5}]},
    TestID -> "projection: block by block, a shuffled block triangular matrix"],
  VerificationTest[StringContainsQ[PFBKiraProject[Take[Ua, 2], {}], "masters the system lacks"], True, TestID -> "projection: masters the system lacks"],
  VerificationTest[StringContainsQ[PFBKiraProject[ReplacePart[Ua, 2 -> {0, 0, 0}], {}], "to zero"], True, TestID -> "projection: a master of the system reduced to zero"],
  VerificationTest[{StringContainsQ[PFBKiraProject[{}, {{1, 0}, {0, 1}}, 2], "none of the system's masters"], PFBKiraProject[{}, {{}, {}}, 0]["Rows"],
      StringContainsQ[PFBKiraProject[{{}, {}}, {}, 0], "to zero"]}, {True, {{}, {}}, True},
    TestID -> "projection: no master of the system in a subtree where Kira finds masters, and masters of the system where Kira finds none"],
  (* the values Kira is given, and its share of the time *)
  VerificationTest[PFBKiraValues[{s -> 1409, t -> 3/7, m2 -> 5}, {"s" -> "s", "t" -> "mcbinv2"}], {"s" -> 1409, "mcbinv2" -> 3/7},
    TestID -> "values: only the invariants of the family Kira reduces (Kira hangs on a variable it does not know)"],
  VerificationTest[StringContainsQ[PFBKiraValues[{s -> 1409}, {"s" -> "s", "t" -> "t"}], "no value to the invariant(s) t"], True,
    TestID -> "values: an invariant of the family without a value at the point"],
  VerificationTest[PFBKiraTimeLimit /@ {86400, 1000, 30, 0}, {43200, 500, 60, 60}, TestID -> "Kira's time: half of what the job has left, at least 60 s"]
};

report = TestReport[tests];
Print["kira_slice: ", report["TestsSucceededCount"], " passed, ", report["TestsFailedCount"], " failed"];
Do[If[r["Outcome"] =!= "Success", Print["FAILED: ", r["TestID"], "\n  expected ", r["ExpectedOutput"], "\n  got      ", Short[r["ActualOutput"], 5]]], {r, Values[report["TestResults"]]}];
Quiet[DeleteDirectory[tmp, DeleteContents -> True]];
Exit[If[report["TestsFailedCount"] == 0, 0, 1]];
