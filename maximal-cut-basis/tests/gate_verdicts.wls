#!/usr/bin/env wolframscript
(* The decisions of the gate on the eps structure of a maximal-cut DE (lib/MCB/DECheck.wl) and on its Euler relation
   (lib/MCB/Rules.wl): the profile of an entry (MCBEpsProfile), eps-form after a rescaling by powers of eps
   (MCBEpsFactorizedQ), a DE that is a Laurent polynomial in eps (MCBEpsPolynomialQ), the Euler relation
   Sum_X d_X X A_X = diag(weights) (MCBEulerCheck), and a reduction that leaves an integral unreduced (MCBReduceTo).
   Planted data: matrices built in this file from a known eps-form DE and known powers of eps, and a DE with planted
   weights at two kinematic points. No Kira, no BaikovPackage.
   usage: bin/ws tests/gate_verdicts.wls        exit code 0 when every test passes *)
Get[FileNameJoin[{ParentDirectory[DirectoryName[$InputFileName]], "lib", "MaximalCutBasis.wl"}]];
$MCBVerbose = False;

(* an eps-form DE eps C with every entry non-zero, so that the powers of eps that reach it are fixed up to a common
   shift; hidden behind the rescaling J_i -> eps^-k_i J_i *)
C1 = {{1, 2, -1}, {3, 1, 5}, {-2, 4, 7}}; C2 = {{2, -1, 3}, {1, 1, 1}, {5, -3, 2}};
kPlanted = {0, 1, 2};
hidden = MCBRescaleEps[eps #, -kPlanted] & /@ {C1, C2};
found = MCBEpsFactorizedQ[hidden];
(* the same DE with one matrix shifted by other powers: no single rescaling serves both *)
clash = {MCBRescaleEps[eps C1, -{0, 1, 2}], MCBRescaleEps[eps C2, -{0, 2, 1}]};

(* the Euler relation: invariants s and m2 of dimension 2, weights w; N drops out of 2 s A_s + 2 m2 A_m2 *)
dims = <|s -> 2, m2 -> 2|>;
w = {-2, 0};
nn = {{0, 3}, {1, 0}};
deAt[pt_, extra_ : {{0, 0}, {0, 0}}] := <|s -> ((DiagonalMatrix[w]/(2 s) + nn/s) /. pt) + extra, m2 -> ((-nn/m2) /. pt)|>;
pts = {{s -> 3, m2 -> 5}, {s -> 7, m2 -> 2}};

tests = {
  VerificationTest[MCBEpsProfile /@ {0, 3 eps, 1/eps + eps^2, (1 + eps)/eps^2, x/(eps^2 y), (1 - 2 eps)/(1 - 2 eps)},
    {"0", {1, 1}, {-1, 2}, {-2, -1}, {-2, -2}, {0, 0}}, TestID -> "profile: the lowest and the highest power of eps of a Laurent polynomial"],
  VerificationTest[MCBEpsProfile /@ {1/(1 - 2 eps), eps/(1 + eps), 1/(eps (1 - 2 eps))}, {"rat", "rat", "rat"},
    TestID -> "profile: a denominator that is not a power of eps is rational"],

  VerificationTest[MCBEpsFactorizedQ[{eps C1, eps C2}], {True, {0, 0, 0}}, TestID -> "eps-form as it stands: no rescaling"],
  VerificationTest[found, {True, kPlanted}, TestID -> "eps-form hidden behind powers of eps: the powers are found"],
  VerificationTest[FreeQ[MCBRescaleEps[#, found[[2]]]/eps & /@ hidden, eps], True, TestID -> "the powers found give eps times a matrix free of eps"],
  VerificationTest[First[MCBEpsFactorizedQ[clash]], False, TestID -> "two matrices that need different powers: not eps-form"],
  VerificationTest[First[MCBEpsFactorizedQ[{{{eps, eps + eps^2}, {eps, eps}}}]], False, TestID -> "an entry with two powers of eps: not eps-form"],
  VerificationTest[First[MCBEpsFactorizedQ[{{{eps, eps^2}, {eps^2, eps}}}]], False, TestID -> "monomial entries that no rescaling brings to eps: not eps-form"],
  VerificationTest[First[MCBEpsFactorizedQ[{{{1, 0}, {0, eps}}}]], False, TestID -> "a diagonal entry of order eps^0: not eps-form (a rescaling leaves the diagonal)"],
  VerificationTest[First[MCBEpsFactorizedQ[{{{eps/(1 - 2 eps), 0}, {0, eps}}}]], False, TestID -> "a factor 1/(1 - 2 eps): not eps-form"],
  VerificationTest[MCBEpsFactorizedQ[{{{eps, 0, 0}, {0, eps, eps^3}, {0, eps^-1, eps}}}], {True, {0, 0, 2}},
    TestID -> "blocks that do not talk to each other: each gets its own powers"],
  VerificationTest[MCBEpsFactorizedQ[{}], {False, {}}, TestID -> "no DE: not eps-form"],
  VerificationTest[First[MCBEpsFactorizedQ[{{{eps, 1/(eps (1 - 2 eps))}, {0, eps}}}]], False,
    TestID -> "a factor 1/(1 - 2 eps) next to a power of eps: not eps-form"],

  VerificationTest[MCBEpsPolynomialQ[hidden], {True, {-1, 3}}, TestID -> "eps-polynomial: the range of powers over every entry"],
  VerificationTest[MCBEpsPolynomialQ[{{{0, 0}, {0, 0}}}], {True, {1, 1}}, TestID -> "eps-polynomial: a vanishing DE"],
  VerificationTest[First[MCBEpsPolynomialQ[{{{eps, 1/(1 - 2 eps)}, {0, eps}}}]], False, TestID -> "eps-polynomial: a factor 1/(1 - 2 eps) is not"],

  VerificationTest[MCBEulerCheck[deAt /@ pts, pts, dims, w]["Pass"], True, TestID -> "Euler: the planted weights at two points"],
  VerificationTest[MCBEulerCheck[deAt /@ pts, pts, dims, Automatic]["Pass"], True, TestID -> "Euler: without weights, a diagonal that is the same at both points"],
  VerificationTest[With[{r = MCBEulerCheck[deAt[#, {{0, 1}, {0, 0}}] & /@ pts, pts, dims, w]}, {r["Pass"], r["OffDiagonal"][[All, 1 ;; 2]]}],
    {False, {{1, 2}, {1, 2}}}, TestID -> "Euler: an off-diagonal part is refused, with its row and column"],
  VerificationTest[MCBEulerCheck[deAt[#, {{1, 0}, {0, 0}}] & /@ pts, pts, dims, Automatic]["Pass"], False,
    TestID -> "Euler: a diagonal that changes with the kinematics is refused"],
  VerificationTest[With[{r = MCBEulerCheck[deAt /@ pts, pts, dims, {-2, 2}]}, {r["Pass"], r["Mismatch"]}], {False, {{2, 0, 2}}},
    TestID -> "Euler: a diagonal that is not the master's weight is refused"],
  VerificationTest[MCBEulerCheck[KeyTake[deAt[#], {s}] & /@ pts, pts, dims, w]["Pass"], Missing["NotChecked"],
    TestID -> "Euler: not checked without the matrix of an invariant of non-zero dimension"],

  VerificationTest[MCBReduceTo[2 j[fam, 1, 1] + s j[fam, 2, 1], {s -> 3}, {j[fam, 2, 1] -> eps j[fam, 1, 1]}, {j[fam, 1, 1]}], {2 + 3 eps},
    TestID -> "reduction: the coefficients on the masters at the point"],
  VerificationTest[Block[{Print}, MCBReduceTo[j[fam, 1, 1] + j[fam, 3, 1], {s -> 3}, {j[fam, 2, 1] -> eps j[fam, 1, 1]}, {j[fam, 1, 1]}]], $Failed,
    TestID -> "reduction: an integral left unreduced gives no result"]
};

report = TestReport[tests];
Do[With[{r = report["TestResults"][id]},
    Print[If[r["Outcome"] === "Success", "PASS ", "FAIL "], r["TestID"], If[r["Outcome"] === "Success", "",
      "\n     got " <> ToString[Short[r["ActualOutput"], 3], InputForm] <> "\n     expected " <> ToString[Short[r["ExpectedOutput"], 3], InputForm]]]],
  {id, Keys[report["TestResults"]]}];
Print[report["TestsSucceededCount"], " passed, ", report["TestsFailedCount"], " failed, ", Round[report["TimeElapsed"], 0.1]];
Exit[If[report["AllTestsSucceeded"], 0, 1]];
