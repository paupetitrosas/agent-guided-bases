#!/usr/bin/env wolframscript
(* PFBWriteMCBBasisFile writes a sector's basis for the maximal-cut-basis toolkit, which reads integrals j[...] only
   (MCBSplitMaster): a ut[k] term of a new definition (the current master k) and Dinv[a, X] (the derivative of a in X),
   in a new definition or in an unchanged master, are written out as integrals, and each element keeps its square root.
   Planted data: the one-loop massless box of the maximal-cut-basis examples with a root on the box master and a
   bubble master defined as a derivative. No IBP reduction, no Kira.
   usage: bin/ws tests/mcb_basis_file.wls        exit code 0 when every test passes *)
Get[FileNameJoin[{ParentDirectory[DirectoryName[$InputFileName]], "lib", "PoleFreeBasis.wl"}]];
$PFBVerbose = False;
boxFile = FileNameJoin[{ParentDirectory[ParentDirectory[DirectoryName[$InputFileName]]], "maximal-cut-basis", "examples", "box-one-loop", "family.wl"}];
tmp = CreateDirectory[];
Put[{j[box, 1, 0, 1, 0], t Dinv[j[box, 0, 1, 0, 1], t], s j[box, 1, 1, 1, 0], r1 s t j[box, 1, 1, 1, 1]}, FileNameJoin[{tmp, "box.m"}]];
Put[<|"Name" -> "planted", "Families" -> {<|"Name" -> "box", "Family" -> boxFile, "Masters" -> "box.m"|>}, "Roots" -> {r1 -> Sqrt[s t]}|>, FileNameJoin[{tmp, "system.wl"}]];
sys = PFBReadSystem[FileNameJoin[{tmp, "system.wl"}]];
fo = PFBFamily[sys, box];
j1111 = j[box, 1, 1, 1, 1]; j1110 = j[box, 1, 1, 1, 0];
noWrappers[e_] := FreeQ[e, _ut | _Dinv | r1];
readBack[key_, defs_, name_] := Get[PFBWriteMCBBasisFile[sys, key, defs, FileNameJoin[{tmp, name}]]];

(* a new box master with a ut term (the triangle master, ut[3]) and a derivative term *)
newDef = s t j1111 + ut[3] + Dinv[j1111, t];
boxFileOut = readBack[{box, {1, 1, 1, 1}}, <|4 -> newDef|>, "box_new.m"];
boxJ = First[boxFileOut]["definition"];
expected = Sqrt[s t] (s t j1111 + s j1110 + MCBDerivExpr[fo, j1111, t]);
(* the unchanged t-bubble, defined as t times a derivative *)
bubOut = readBack[{box, {0, 1, 0, 1}}, <||>, "bubble.m"];
bubJ = First[bubOut]["definition"];

tests = {
  VerificationTest[sys =!= $Failed && Length[PFBMasters[sys]] == 4, True, TestID -> "the planted system loads"],
  VerificationTest[{Length[boxFileOut], First[boxFileOut]["label"], noWrappers[boxJ]}, {1, "ut[4] (new)", True},
    TestID -> "new master: one element, no ut[k], no Dinv, no root symbol left"],
  VerificationTest[MCBEqualAtPointsQ[boxJ, expected], True, TestID -> "new master: the ut term is the triangle, the derivative is written out, the root kept"],
  VerificationTest[With[{sp = MCBSplitMaster[boxJ]}, {Factor[sp["r2"]], SubsetQ[JIntegrals[sp["K"]], {j1111, j1110}], MCBEqualAtPointsQ[Sqrt[sp["r2"]] sp["K"], expected]}],
    {s t, True, True}, TestID -> "new master: maximal-cut-basis splits it into its root and the integrals"],
  VerificationTest[{First[bubOut]["provenance"], noWrappers[bubJ], MCBEqualAtPointsQ[bubJ, t MCBDerivExpr[fo, j[box, 0, 1, 0, 1], t]]}, {"unchanged", True, True},
    TestID -> "unchanged master defined as a derivative: written out as integrals"],
  VerificationTest[MCBEqualAtPointsQ[First[readBack[{box, {1, 1, 1, 1}}, <||>, "box_old.m"]]["definition"], Sqrt[s t] s t j1111], True,
    TestID -> "unchanged master: as defined, with its root"]
};

report = TestReport[tests];
Do[With[{r = report["TestResults"][id]},
    Print[If[r["Outcome"] === "Success", "PASS ", "FAIL "], r["TestID"], If[r["Outcome"] === "Success", "",
      "\n     got " <> ToString[Short[r["ActualOutput"], 3], InputForm] <> "\n     expected " <> ToString[Short[r["ExpectedOutput"], 3], InputForm]]]],
  {id, Keys[report["TestResults"]]}];
Print[report["TestsSucceededCount"], " passed, ", report["TestsFailedCount"], " failed, ", Round[report["TimeElapsed"], 0.1]];
DeleteDirectory[tmp, DeleteContents -> True];
Exit[If[report["AllTestsSucceeded"], 0, 1]];
