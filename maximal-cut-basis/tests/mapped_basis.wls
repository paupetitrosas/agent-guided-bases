#!/usr/bin/env wolframscript
(* The repeated-geometry route of the automatic pass (MCBAutoPass): a sector that is the same integrals as another
   sector of the run at mapped kinematics (MCBRepeatedGeometry) searches that sector's basis, mapped, first. When the
   mapped basis is eps-form, or eps-polynomial on a sector proven non-dlog, it is adopted and the candidate searches
   are skipped; otherwise the searches run and a later result replaces it only when it is better (a lower score, or on
   a non-dlog sector the all-dot tie-breaker: an undotted element wins a tie of spreads).
   Planted data: the equal-mass sunrise of the examples (an elliptic cut, two masters on it). The representations, the
   count of the masters on the cut, the Picard-Fuchs label, the repeated geometry, the candidate routes and the Kira
   reductions on the cut are planted (Block); the searches (MCBSearchBasis) and the choice between them are the real
   ones. The pass is stopped where it would write its record. No Kira, no BaikovPackage.
   usage: bin/ws tests/mapped_basis.wls        exit code 0 when every test passes *)
Get[FileNameJoin[{ParentDirectory[DirectoryName[$InputFileName]], "lib", "MaximalCutBasis.wl"}]];
$MCBVerbose = False;
ex = FileNameJoin[{ParentDirectory[DirectoryName[$InputFileName]], "examples"}];
sun = MCBReadFamily[FileNameJoin[{ex, "sunrise-equal-mass", "family.wl"}]];
tmp = CreateDirectory[];
sS = {1, 1, 1, 0, 0};
j111 = j[sunrise, 1, 1, 1, 0, 0]; j211 = j[sunrise, 2, 1, 1, 0, 0]; j121 = j[sunrise, 1, 2, 1, 0, 0];
pt = {s -> 3, m2 -> 1};
(* the cut masters m1, m2 have the DE A0 (powers of eps 0 and 1); a candidate is a constant row of T on them, so every
   pair of candidates has a DE with the same spread, T A0 T^-1 *)
A0 = {{eps, 1}, {eps, 2 eps}};
rowOf = <|j211 -> {1, 0}, j121 -> {0, 1}, j111 -> {1, 1}|>;
reduced = {};
plantedReduce[fam_, s_, cands_, dir_, pts_] := Module[{T = Lookup[rowOf, #["K"], Missing[]] & /@ cands},
  AppendTo[reduced, #["K"] & /@ cands];
  If[cands === {} || MemberQ[T, _Missing], $Failed,
    {<|"point" -> pt, "masters" -> {m1, m2}, "invariants" -> {s}, "T" -> T, "D" -> {T . A0}, "g" -> {ConstantArray[0, Length[cands]]}|>}]];
rep = <|"kind" -> "planted", "order" -> {1}, "isp" -> {}, "id" -> 1, "vars" -> {z}, "geometry" -> <|"class" -> "curve", "nvars" -> 1, "text" -> "planted elliptic curve"|>|>;
cand[K_] := <|"r2" -> 1, "K" -> K, "label" -> "planted route", "provenance" -> "planted", "strict" -> False, "priority" -> 5, "weight" -> {1, 0, 0}|>;
routeCalls = 0;

(* one pass: the mapped basis (from a sector of status st) and the candidates the route gives; stopped where the record
   is assembled, with the best search result *)
pass[name_, mapped_List, st_String, routeCands_List] := Module[{dir = FileNameJoin[{tmp, name, "sun_analysis", SectorName[sS]}], out},
  CreateDirectory[dir, CreateIntermediateDirectories -> True];
  Put[<|"FamilyFile" -> FileNameJoin[{ex, "sunrise-equal-mass", "family.wl"}]|>, FileNameJoin[{ParentDirectory[dir], "run_info.m"}]];
  routeCalls = 0; reduced = {};
  out = Catch[Block[{MCBRepresentations, MCBPrintCutData, MCBCutMasters, MCBPicardFuchs, MCBRepeatedGeometry, MCBReduceCandidates, MCBCandidatesFor,
       MCBSingleCandidates, MCBStatusFor, MaximalCutBasis`AutoPass`Private`verdictFromSearch},
      MCBRepresentations[___] := {rep};
      MCBPrintCutData[___] := Null;
      MCBCutMasters[___] := <|"masters" -> {m1, m2}, "n" -> 2, "rules" -> None|>;
      MCBPicardFuchs[___] := <|"label" -> "elliptic", "reason" -> "planted", "time" -> 0|>;
      MCBRepeatedGeometry[___] := {<|"from" -> "j11101", "status" -> st, "map" -> <|"lines" -> {1, 2, 3}, "invariants" -> {}|>, "basis" -> mapped|>};
      MCBReduceCandidates[a___] := plantedReduce[a];
      MCBCandidatesFor[___] := (routeCalls++; <|"status" -> "ok", "candidates" -> (cand /@ routeCands)|>);
      MCBSingleCandidates[___] := <|"status" -> "ok", "candidates" -> {}|>;
      MaximalCutBasis`AutoPass`Private`verdictFromSearch[red_, res_, fam_] := Throw[<|"Best" -> res|>, "stop"];
      MCBStatusFor[chk_, ___] := Throw[<|"Best" -> None, "Check" -> chk|>, "stop"];
      Block[{Print}, MCBAutoPass[sun, sS, dir, <|"Points" -> {pt}|>]]], "stop"];
  Join[out, <|"Attempts" -> MCBReadAttempts[dir], "RouteCalls" -> routeCalls, "Reduced" -> reduced|>]];
kOf[r_] := If[AssociationQ[r["Best"]], #["K"] & /@ r["Best"]["cands"], None];
mappedAttempt[r_] := Lookup[SelectFirst[r["Attempts"], StringContainsQ[Lookup[#, "what", ""], "mapped (repeated geometry)"] &, <||>], "outcome", None];

(* an eps-polynomial basis of a non-dlog sector, mapped: adopted, the searches skipped *)
rA = pass["adopted", {j111, j211}, "eps-polynomial", {j121}];
(* a mapped basis whose every element is dotted, from an eps-form sector: the searches run, and the route's undotted
   candidate, at the same spread, wins the tie *)
rB = pass["tie", {j211, j121}, "eps-form", {j111}];

tests = {
  VerificationTest[{mappedAttempt[rA], rA["RouteCalls"], kOf[rA], rA["Best"]["status"], rA["Best"]["range"], rA["Reduced"]},
    {"eps-polynomial {0, 1}; the candidate searches are skipped", 0, {j111, j211}, "eps-polynomial", {0, 1}, {{j111, j211}}},
    TestID -> "mapped basis: searched first, adopted, and the candidate searches skipped (eps-polynomial on a non-dlog sector)"],
  VerificationTest[{mappedAttempt[rB], rB["RouteCalls"], Length[rB["Reduced"]], MemberQ[kOf[rB], j111], rB["Best"]["range"]},
    {"eps-polynomial {0, 1}", 1, 2, True, {0, 1}},
    TestID -> "mapped basis of dotted elements: adopted first, then replaced by a search at the same spread with an undotted element"]
};

report = TestReport[tests];
Do[With[{r = report["TestResults"][id]},
    Print[If[r["Outcome"] === "Success", "PASS ", "FAIL "], r["TestID"], If[r["Outcome"] === "Success", "",
      "\n     got " <> ToString[Short[r["ActualOutput"], 3], InputForm] <> "\n     expected " <> ToString[Short[r["ExpectedOutput"], 3], InputForm]]]],
  {id, Keys[report["TestResults"]]}];
Print[report["TestsSucceededCount"], " passed, ", report["TestsFailedCount"], " failed, ", Round[report["TimeElapsed"], 0.1]];
DeleteDirectory[tmp, DeleteContents -> True];
Exit[If[report["AllTestsSucceeded"], 0, 1]];
