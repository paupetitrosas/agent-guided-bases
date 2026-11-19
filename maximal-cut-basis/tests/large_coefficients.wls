#!/usr/bin/env wolframscript
(* Basis elements with large coefficients, written as prefactor x pieces: the gate's split, its derivatives at a point,
   the rules, weights and letters, and the comparisons of definitions must give what the same elements give without the
   large factor, and must not expand it or put it over a common denominator. No Kira: the derivatives are compared at
   a point, as the gate uses them.
   usage: bin/ws tests/large_coefficients.wls        exit code 0 when every test passes *)
Get[FileNameJoin[{ParentDirectory[DirectoryName[$InputFileName]], "lib", "MaximalCutBasis.wl"}]];
ex = FileNameJoin[{ParentDirectory[DirectoryName[$InputFileName]], "examples"}];
dbox = MCBReadFamily[FileNameJoin[{ex, "doublebox-massless", "family.wl"}]];
bub = MCBReadFamily[FileNameJoin[{ex, "bubble-massive", "family.wl"}]];

(* Q = Q1/Q2 is 1, written large: Q1 a sum of random fractions, Q2 its Together written expanded *)
bigOne[x_, y_, seed_] := BlockRandom[Module[{poly, q1, q2},
   poly[] := Sum[RandomInteger[{-9, 9}] x^a y^b, {a, 0, 3}, {b, 0, 3 - a}];
   q1 = Sum[poly[]/poly[], {12}];
   q2 = Together[q1];
   q1/(Expand[Numerator[q2]]/Expand[Denominator[q2]])], RandomSeeding -> seed];
Q = bigOne[s, t, 7];
Qb = bigOne[s, m2, 11];

j1 = j[dbox["Name"], 1, 1, 1, 1, 1, 1, 1, 0, 0]; j2 = j[dbox["Name"], 1, 1, 1, 1, 1, 1, 1, -1, 0];
plain = {eps^4 s^2 t j1, eps^4 s^2 j2};
big = {eps^4 Q s^2 t j1, eps^4 s^2 Q (j2 + (Q - 1) j1)};
jb = j[bub["Name"], 1, 2]; R = (4 m2 - s) s;
pt = {s -> 3/7, t -> -11/13};
ptb = {s -> 3/7, m2 -> 5/17};

dvec[fam_, J_, p_] := With[{c = MCBSplitMaster[J]}, Table[MCBDerivExprAt[fam, c["K"], X, p] + (D[c["r2"], X]/(2 c["r2"]) /. p) (c["K"] /. p), {X, fam["InvList"]}]];
sameQ[a_, b_] := Together[a - b] === (0 a);
large[f_] := First[AbsoluteTiming[f]] < 10;
SetAttributes[large, HoldAll];

tests = {
  VerificationTest[Q === 1, False, TestID -> "the test factor is not simplified to 1 on its own"],
  VerificationTest[MCBLargeQ[Q], True, TestID -> "the test factor counts as large"],
  VerificationTest[Sort[Keys[MCBTerms[a (j1 + b j2) + c j1]]] === Sort[{j1, j2}] && Together[MCBTerms[a (j1 + b j2) + c j1][j1] - (a + c)] === 0, True,
    TestID -> "MCBTerms reads prefactor x pieces without expanding"],
  VerificationTest[{MCBTerms[j1^2], MCBTerms[j1 j2], MCBTerms[a]}, {$Failed, $Failed, <||>}, TestID -> "MCBTerms refuses what is not linear in the integrals"],
  VerificationTest[{MCBEqualAtPointsQ[Q, 1], MCBEqualAtPointsQ[Q, 1 + s/10^6], MCBEqualAtPointsQ[Sqrt[R] Qb jb, Sqrt[R] jb]}, {True, False, True},
    TestID -> "MCBEqualAtPointsQ"],
  VerificationTest[large[MCBSplitMaster /@ big], True, TestID -> "MCBSplitMaster: a large prefactor takes no time"],
  VerificationTest[MCBSplitMaster[big[[1]]], <|"r2" -> 1, "K" -> big[[1]]|>, TestID -> "MCBSplitMaster keeps an element without roots as written"],
  VerificationTest[With[{c = MCBSplitMaster[Sqrt[R] Qb jb]}, {c["r2"], FreeQ[c["K"], Power[_, 1/2]], MCBEqualAtPointsQ[Sqrt[c["r2"]] c["K"], Sqrt[R] Qb jb]}],
    {R, True, True}, TestID -> "MCBSplitMaster: the root next to a large prefactor"],
  VerificationTest[With[{J = (Sqrt[R] Qb jb + Sqrt[R] (1 - Qb) jb)}, With[{c = MCBSplitMaster[J]}, {c["r2"], MCBEqualAtPointsQ[c["K"], jb]}]],
    {R, True}, TestID -> "MCBSplitMaster: the same root in two terms"],
  VerificationTest[Quiet[MCBSplitMaster[Sqrt[s] jb + Sqrt[m2] j[bub["Name"], 1, 1]]], $Failed, TestID -> "MCBSplitMaster: mixed roots are still refused"],
  VerificationTest[large[dvec[dbox, #, pt] & /@ big], True, TestID -> "MCBDerivExprAt: a large prefactor takes no time"],
  VerificationTest[MapThread[sameQ, {dvec[dbox, #, pt] & /@ big, dvec[dbox, #, pt] & /@ plain}], {True, True},
    TestID -> "MCBDerivExprAt: the derivatives of the large elements are those of the plain ones"],
  VerificationTest[sameQ[dvec[bub, Sqrt[R] Qb jb, ptb], dvec[bub, Sqrt[R] jb, ptb]], True, TestID -> "MCBDerivExprAt with a square root"],
  VerificationTest[MCBRuleViolations[dbox, #] & /@ big, {{}, {}}, TestID -> "rules: large and honest"],
  VerificationTest[{MCBMasterWeight[dbox, #] & /@ big, MCBMasterWeight[bub, Sqrt[R] Qb jb]}, {MCBMasterWeight[dbox, #] & /@ plain, MCBMasterWeight[bub, Sqrt[R] jb]},
    TestID -> "weights: large as plain"],
  VerificationTest[StringStartsQ[#, "rule 1"] & /@ MCBRuleViolations[dbox, eps^4 Q (1 - 2 eps) s^2 t j1], {True}, TestID -> "rule 1 seen through a large coefficient"],
  VerificationTest[StringStartsQ[#, "rule 2"] & /@ MCBRuleViolations[dbox, eps^4 Q s^2 t j1/(1 + eps)], {True}, TestID -> "rule 2 seen through a large coefficient"],
  VerificationTest[MCBRuleViolations[dbox, eps^4 Q s^2 t x j1], MCBRuleViolations[dbox, eps^4 s^2 t x j1], TestID -> "rule 4 (a stray symbol) as for the plain element"],
  VerificationTest[{MCBMasterWeight[dbox, eps^4 Q s^3 t j1], MCBMasterWeight[dbox, eps^4 Q (s + 1) j1]}, {MCBMasterWeight[dbox, eps^4 s^3 t j1], $Failed},
    TestID -> "weights: a wrong dimension and an inhomogeneous prefactor"],
  VerificationTest[{MCBRuleViolations[dbox, eps^4 Q s^2 t j1, <|"Letters" -> {s, t, s + t}|>], MCBRuleViolations[dbox, eps^4 Q s^2 t j1/(s - 2 t), <|"Letters" -> {s, t, s + t}|>]},
    {{}, MCBRuleViolations[dbox, eps^4 s^2 t j1/(s - 2 t), <|"Letters" -> {s, t, s + t}|>]}, TestID -> "letters: none missing, and a non-letter factor named"],
  VerificationTest[MCBWrittenEpsPower /@ big, {{4, False}, {4, False}}, TestID -> "MCBWrittenEpsPower of large elements"],
  VerificationTest[{MCBSameBasisQ[big, plain], MCBSameBasisQ[big, Reverse[plain]]}, {True, False}, TestID -> "MCBSameBasisQ compares at points"],
  VerificationTest[large[{MCBRulesCheck[dbox, big], MCBWrittenEpsPower /@ big, MCBSameBasisQ[big, plain]}], True, TestID -> "the checks on large elements take no time"]
};

report = TestReport[tests];
Do[With[{r = report["TestResults"][id]},
    Print[If[r["Outcome"] === "Success", "PASS ", "FAIL "], r["TestID"], If[r["Outcome"] === "Success", "",
      "\n     got " <> ToString[Short[r["ActualOutput"], 3], InputForm] <> "\n     expected " <> ToString[Short[r["ExpectedOutput"], 3], InputForm]]]],
  {id, Keys[report["TestResults"]]}];
Print[report["TestsSucceededCount"], " passed, ", report["TestsFailedCount"], " failed, ", Round[report["TimeElapsed"], 0.1]];
Exit[If[report["AllTestsSucceeded"], 0, 1]];
