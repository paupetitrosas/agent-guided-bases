#!/usr/bin/env wolframscript
(* Known-answer tests of lib/MCB/PicardFuchs.wl: planted operators and connections whose geometry is known; and of the
   records that keep the step's classification and flag its disagreeing checks (lib/MCB/Reports.wl).
   usage: bin/ws tests/picard_fuchs.wls        exit code 0 when every test passes *)
Get[FileNameJoin[{ParentDirectory[DirectoryName[$InputFileName]], "lib", "MaximalCutBasis.wl"}]];
SeedRandom[20261014];

label[L_, opts___] := MCBPFClassifyOperator[L, t, opts]["label"];
peeled[L_] := With[{c = MCBPFClassifyOperator[L, t]}, {c["label"], c["factors"]["block"], c["factors"]["right"] + c["factors"]["left"]}];
firstOrder[u_] := {-u, 1};                                  (* d - u *)
theta = {0, t};                                             (* t d *)
thetaPoly[c_List] := Module[{res = {0}, pw = {1}, m},       (* Sum c_k theta^k *)
  Do[If[k > 0, pw = MCBPFCompose[theta, pw, t]]; m = Max[Length[res], Length[pw]];
    res = PadRight[res, m] + c[[k + 1]] PadRight[pw, m], {k, 0, Length[c] - 1}]; res];
sym2[{b_, a_, 1}] := {4 a b + 2 D[b, t], 2 a^2 + D[a, t] + 4 b, 3 a, 1};    (* Sym^2 of d^2 + a d + b *)
companion[L_] := With[{a = Together[#/Last[L]] & /@ L, n = Length[L] - 1},
  Table[If[i < n, If[jj == i + 1, 1, 0], -a[[jj]]], {i, n}, {jj, n}]];

(* planted geometries *)
legendre = {-1/4, 1 - 2 t, t (1 - t)};                       (* periods of y^2 = x(x-1)(x-t): elliptic *)
k3 = sym2[Together[legendre/Last[legendre]]];                (* its symmetric square: K3 *)
quintic = Module[{e = CoefficientList[Expand[(5 x + 1) (5 x + 2) (5 x + 3) (5 x + 4)], x]},
  PadRight[thetaPoly[{0, 0, 0, 0, 1}], 5] - 5 t PadRight[thetaPoly[e], 5]];   (* the mirror quintic: CY_3 *)
(* Sqrt[1 + Sqrt[t]] and Sqrt[1 - Sqrt[t]]: a dihedral pair, algebraic but no root of a rational function *)
nested = Module[{c, a, u, fs, eqs, ns},
  a = Table[Sum[c[k, i] t^i, {i, 0, 3}], {k, 0, 2}];
  fs = {Sqrt[1 + u], Sqrt[1 - u]};
  eqs = Flatten[Table[With[{f1 = D[f, u]/(2 u)}, CoefficientList[Normal[Series[
      u^4 ((a[[3]] D[f1, u]/(2 u) + a[[2]] f1 + a[[1]] f) /. t -> u^2), {u, 0, 28}]], u]], {f, fs}]];
  ns = NullSpace[Normal[CoefficientArrays[eqs, Flatten[Table[c[k, i], {k, 0, 2}, {i, 0, 3}]]][[2]]]];
  MCBPFNormalize[a /. Thread[Flatten[Table[c[k, i], {k, 0, 2}, {i, 0, 3}]] -> First[ns]], t]];
polylog = MCBPFCompose[MCBPFCompose[firstOrder[1/(2 t)], firstOrder[1/(1 - t)], t], theta, t];   (* includes log t *)

(* a connection: the Legendre system extended by t^(1/3), in a random rational frame *)
gaugeTest = Module[{A, G},
  A = ArrayFlatten[{{companion[legendre], {{0}, {0}}}, {{{1/(t - 2), 0}}, {{1/(3 t)}}}}];
  G = Table[RandomInteger[{-3, 3}] + RandomInteger[{-2, 2}] t, {3}, {3}];
  While[Det[G] === 0, G = Table[RandomInteger[{-3, 3}] + RandomInteger[{-2, 2}] t, {3}, {3}]];
  Together[G . A . Inverse[G] + D[G, t] . Inverse[G]]];

(* eps: a connection regular at eps = 0, the same after a diagonal gauge eps^g, and after I + (t/eps) E13, which puts a
   pole on the diagonal that no diagonal shift removes *)
aBase = ArrayFlatten[{{companion[legendre], {{0}, {0}}}, {{{1/(t - 2), 0}}, {{1/(3 t)}}}}];
aEps = {{1/(t + 1), 0, 2}, {t, -1, 0}, {0, 3/(t - 5), 1}};
aSer = MCBPFLaurentMatrix[{aBase, aEps, aEps/7, 0 aEps, 0 aEps}, 0, eps];
aDiag = Table[eps^({2, 0, -1}[[i]] - {2, 0, -1}[[jj]]) aSer[[i, jj]], {i, 3}, {jj, 3}];
gL = IdentityMatrix[3] + (t/eps) {{0, 0, 1}, {0, 0, 0}, {0, 0, 0}};
aLat = Map[Together, gL . aSer . Inverse[gL] + D[gL, t] . Inverse[gL], {2}];
regLabel[A_] := With[{r = MCBPFRegularise[A, t, eps]}, {r["status"], r["method"], label[MCBPFOperator[r["A0"], t, RandomInteger[{1, 9}, 3]]]}];

(* connections: the classifier that never forms the order-n operator *)
conn[A_] := With[{c = MCBPFClassifyConnection[A, t]}, {c["label"], c["factors"]["firstOrder"], c["factors"]["blocks"]}];
legendre2 = legendre /. t -> t/3;                              (* another elliptic family, singular at 0, 3, infinity *)

(* a dense constant frame that hides the zero pattern *)
dense[A_] := Module[{G = RandomInteger[{-3, 3}, {Length[A], Length[A]}]},
  While[Det[G] == 0, G = RandomInteger[{-3, 3}, {Length[A], Length[A]}]];
  Together[G . A . Inverse[G]]];
(* pieces of order 2: blocks glued so that no piece of first order splits them, in a dense frame *)
glued[sub_, quo_, c_] := ArrayFlatten[{{sub, c}, {0, quo}}];
ellEll = dense[glued[companion[legendre], companion[legendre2], {{1/(t - 5), 0}, {0, 0}}]];
(* the nested root times a logarithmic extension: no first-order piece, logarithms, and still polylogarithmic *)
nestedLog = dense[KroneckerProduct[companion[nested], IdentityMatrix[2]] + KroneckerProduct[IdentityMatrix[2], {{0, 0}, {1/(t - 2), 0}}]];
ellK3 = dense[glued[companion[legendre], companion[k3], {{0, 0, 0}, {1/(t - 5), 0, 0}}]];       (* order 5, a sub of order 2 *)
k3Ell = dense[glued[companion[k3], companion[legendre], {{0, 0}, {0, 0}, {1/(t - 5), 0}}]];      (* order 5, a quotient of order 2 *)
conn2[A_, opts___] := With[{c = MCBPFClassifyConnection[A, t, opts]}, {c["label"], c["factors"]["firstOrder"], Sort[c["factors"]["blocks"]]}];
(* labels that need more than a log: Sym^3 of an elliptic block has only logs of power 3, 2F1(1/5, 4/5; 1) the exponents
   1/5 and 4/5 at infinity, which no family of elliptic curves has *)
sym3[C_] := Module[{n = Length[C], mons, pos, S},                 (* Sym^3 of the system Y' = C Y *)
  mons = Select[Tuples[Range[n], 3], OrderedQ];
  pos[m_] := First[FirstPosition[mons, Sort[m]]];
  S = ConstantArray[0, {Length[mons], Length[mons]}];
  Do[With[{m = mons[[r]]}, Do[S[[r, pos[ReplacePart[m, a -> kk]]]] += C[[m[[a]], kk]], {a, 3}, {kk, n}]], {r, Length[mons]}];
  Together /@ S];
hyp[a_, b_, c_] := {-a b, c - (a + b + 1) t, t (1 - t)};   (* 2F1(a, b; c; t) *)
rational[A_] := Module[{G = Table[RandomInteger[{-2, 2}] + RandomInteger[{-1, 1}] t, {Length[A]}, {Length[A]}]},
  While[Det[G] === 0, G = Table[RandomInteger[{-2, 2}] + RandomInteger[{-1, 1}] t, {Length[A]}, {Length[A]}]];
  Together[G . A . Inverse[G] + D[G, t] . Inverse[G]]];
sameTwice = rational[ArrayFlatten[{{companion[legendre], 0}, {0, companion[legendre]}}]];   (* one elliptic curve, seen twice *)

(* records: basis.m keeps its classification when a record written without one replaces it (an AnalysisMasters.m older
   than the step), and the status follows the label *)
recDir = CreateDirectory[];
keep[oldLabel_, newRec_] := Module[{},
  Put[<|"sector" -> {1, 1, 0}, "status" -> "eps-polynomial", "classification" -> <|"label" -> oldLabel, "reason" -> "planted"|>|>, FileNameJoin[{recDir, "basis.m"}]];
  MCBWriteBasis[recDir, newRec];
  Lookup[MCBReadBasis[recDir], {"status", "classification"}] /. c_Association :> Lookup[c, "label", c]];
newRec[st_, s_ : {1, 1, 0}] := <|"sector" -> s, "status" -> st, "flags" -> {}, "geometry" -> <|"class" -> "curve"|>, "kiraVerdict" -> <|"status" -> "eps-polynomial"|>|>;
flagged[check_] := MCBFlaggedQ[<|"status" -> "eps-polynomial", "geometry" -> <|"class" -> "curve"|>,
   "classification" -> <|"label" -> "elliptic", "baikovCheck" -> <|"status" -> check, "message" -> "planted"|>, "kiraCheck" -> <|"status" -> "agree"|>|>|>];

tests = {
  VerificationTest[conn[gaugeTest], {"elliptic", 1, {2}}, TestID -> "connection: a dense random frame of Legendre + t^(1/3)"],
  VerificationTest[conn[ConstantArray[0, {3, 3}]], {"polylog", 3, {}}, TestID -> "connection: zero (an eps-form frame at eps = 0)"],
  VerificationTest[conn[{{0, 0}, {1/t, 0}}], {"polylog", 2, {}}, TestID -> "connection: a logarithmic extension of trivial pieces"],
  VerificationTest[conn[companion[polylog]], {"polylog", 3, {}}, TestID -> "connection: companion of a product of first-order operators"],
  VerificationTest[conn[ArrayFlatten[{{companion[legendre], 0}, {0, companion[legendre2]}}]], {"elliptic", 0, {2, 2}}, TestID -> "connection: two elliptic blocks stay apart"],
  VerificationTest[conn[companion[k3]], {"K3", 0, {3}}, TestID -> "connection: K3"],
  (* the symmetric square decided on the system: an invariant quadratic form, whatever the frame *)
  VerificationTest[conn[dense[companion[k3]]], {"K3", 0, {3}}, TestID -> "connection: K3 in a dense frame"],
  VerificationTest[MaximalCutBasis`PicardFuchs`Private`sym2System[companion[{1, t, 2, t (t - 1) (t + 2)}], t, 60], False,
    TestID -> "a generic order-3 system has no invariant quadratic form"],
  VerificationTest[conn[companion[quintic]], {"CY_3", 0, {4}}, TestID -> "connection: CY_3"],
  VerificationTest[conn[companion[nested]], {"polylog (nested root)", 0, {2}}, TestID -> "connection: nested root"],
  VerificationTest[conn2[ellEll], {"elliptic", 0, {2, 2}}, TestID -> "order 2: two elliptic blocks glued, in a dense frame"],
  VerificationTest[conn2[ellEll, "SecondOrderMaxOrder" -> 3], {"unresolved (order 4)", 0, {4}}, TestID -> "order 2: the same block without the search"],
  VerificationTest[conn2[nestedLog], {"polylog (nested root)", 0, {2, 2}}, TestID -> "order 2: nested root times a log is polylog"],
  VerificationTest[conn2[ellK3], {"K3", 0, {2, 3}}, TestID -> "order 2: a sub of order 2 in a block of order 5"],
  VerificationTest[conn2[k3Ell], {"K3", 0, {2, 3}}, TestID -> "order 2: a quotient of order 2 in a block of order 5"],
  VerificationTest[First[MCBPFClassifyConnection[companion[quintic], t]["blocks"]]["secondOrder"], "invariant form",
    TestID -> "order 2: the quintic keeps its symplectic form and does not split"],
  (* a known limit: the net of invariant bivectors of V + V is not searched for a plane (reference/picard-fuchs.md) *)
  VerificationTest[With[{c = MCBPFClassifyConnection[sameTwice, t]}, {c["label"], First[c["blocks"]]["secondOrder"]}], {"unresolved (order 4)", "invariant forms"},
    TestID -> "order 2: the same elliptic curve twice is not split, and says so"],
  VerificationTest[conn2[sym3[companion[legendre]]], {"non-polylog (order 4)", 0, {4}}, TestID -> "label: Sym^3 of Legendre is not shown Calabi-Yau"],
  VerificationTest[label[hyp[1/5, 4/5, 1]], "non-polylog (order 2)", TestID -> "label: 2F1(1/5, 4/5; 1) is not elliptic"],
  VerificationTest[label[sym2[Together[hyp[1/5, 4/5, 1]/Last[hyp[1/5, 4/5, 1]]]]], "non-polylog (order 3)", TestID -> "label: Sym^2 of 2F1(1/5, 4/5; 1) is not K3"],
  (* the cubic, quartic and sextic families: exponent differences 1/3, 1/2 and 2/3 at infinity *)
  VerificationTest[label /@ {hyp[1/3, 2/3, 1], hyp[1/4, 3/4, 1], hyp[1/6, 5/6, 1]}, {"elliptic", "elliptic", "elliptic"}, TestID -> "label: the elliptic 2F1 families are elliptic"],
  VerificationTest[keep["polylog", newRec["eps-polynomial"]], {"eps-polynomial (dlog search incomplete)", "polylog"}, TestID -> "records: a polylog label kept, the status lowered"],
  VerificationTest[keep["elliptic", newRec["eps-polynomial (dlog search incomplete)"]], {"eps-polynomial", "elliptic"}, TestID -> "records: a non-polylog label kept, the status raised"],
  VerificationTest[keep["polylog", newRec["eps-polynomial", {1, 0, 1}]], {"eps-polynomial", Missing["KeyAbsent", "classification"]}, TestID -> "records: another sector's classification is not taken"],
  VerificationTest[keep["polylog", Join[newRec["eps-polynomial"], <|"classification" -> <|"label" -> "elliptic"|>|>]], {"eps-polynomial", "elliptic"}, TestID -> "records: a record's own classification wins"],
  VerificationTest[{flagged["disagree"], flagged["agree"]}, {True, False}, TestID -> "records: a Picard-Fuchs check that disagrees flags the sector"],
  (* two Jordan blocks of size 2 at t = 0: highest log power exactly 1, from the count of solutions phi0 + log phi1 *)
  VerificationTest[SelectFirst[MCBPFLocal[MCBPFOperator[ArrayFlatten[{{companion[legendre], 0}, {0, companion[legendre2]}}], t, {2, 3, 5, 7}], t],
      #["point"] === t &]["logPower"], {1, 1}, TestID -> "two Jordan blocks of size 2: log power exactly 1"],
  VerificationTest[regLabel[aSer], {"regular", "none", "elliptic"}, TestID -> "eps: already regular"],
  VerificationTest[regLabel[aDiag], {"regular", "diagonal", "elliptic"}, TestID -> "eps: poles removed by diagonal shifts"],
  VerificationTest[regLabel[aLat], {"regular", "lattice", "elliptic"}, TestID -> "eps: a pole on the diagonal, removed by the lattice"],
  VerificationTest[Lookup[MCBPFRegularise[MCBPFLaurentMatrix[{aBase}, 0, eps], t, eps], {"status", "method"}], {"regular", "none"}, TestID -> "eps: an eps-free matrix is regular"],
  VerificationTest[MCBPFRegularise[Map[# + O[eps]^1 &, Map[Normal, aLat, {2}], {2}], t, eps]["status"], "needOrder", TestID -> "eps: too few orders give needOrder"],
  VerificationTest[MCBPFOperator[companion[legendre], t, {1, 0}], MCBPFNormalize[legendre, t], TestID -> "cyclic vector of a companion system"],
  VerificationTest[Together[MCBPFApply[k3, Hypergeometric2F1[1/2, 1/2, 1, t]^2, t] /. t -> 1/7] // N // Chop, 0, TestID -> "planted Sym^2 annihilates K(t)^2"],
  VerificationTest[Lookup[MCBPFLocal[legendre, t], "logPower"], {{1, 1}, {1, 1}, {1, 1}}, TestID -> "Legendre: a log at 0, 1 and infinity"],
  VerificationTest[First[MCBPFLocal[quintic, t]][["exponents"]], {{0, 4}}, TestID -> "quintic: exponent 0, multiplicity 4, at t = 0"],
  VerificationTest[MCBPFPCurvature[legendre, t, 31], "nilpotent", TestID -> "p-curvature of Legendre: nilpotent, not zero"],
  VerificationTest[MCBPFPCurvature[nested, t, 31], "zero", TestID -> "p-curvature of the nested root: zero"],
  VerificationTest[MCBPFSymmetricSquareQ[k3, t], True, TestID -> "Sym^2 of Legendre is a symmetric square"],
  VerificationTest[MCBPFSymmetricSquareQ[{1, t, 2, t (t - 1) (t + 2)}, t], False, TestID -> "a generic third-order operator is not"],
  VerificationTest[label[legendre], "elliptic", TestID -> "label: elliptic"],
  VerificationTest[label[k3], "K3", TestID -> "label: K3"],
  VerificationTest[label[quintic], "CY_3", TestID -> "label: CY_3"],
  VerificationTest[label[nested], "polylog (nested root)", TestID -> "label: nested root"],
  VerificationTest[label[polylog], "polylog", TestID -> "label: polylog, with a logarithmic extension"],
  VerificationTest[peeled[MCBPFCompose[legendre, firstOrder[1/(2 t)], t]], {"elliptic", 2, 1}, TestID -> "peel a first-order factor on the right"],
  (* (t d - 3) o L also has a polynomial solution (L maps polynomials of degree m onto degree m), so either side may give the factor *)
  VerificationTest[peeled[MCBPFCompose[{-3, t}, legendre, t]], {"elliptic", 2, 1}, TestID -> "peel a first-order factor on the left"],
  VerificationTest[label[MCBPFOperator[gaugeTest, t, RandomInteger[{1, 9}, 3]]], "elliptic", TestID -> "a random frame and a random seed: still elliptic"],
  VerificationTest[StringStartsQ[label[legendre + {1/(3 (t - 5)), 0, 0}], "unresolved"], True, TestID -> "a corrupted Legendre operator is unresolved"],
  VerificationTest[First[MCBPFLabel[4, {{1, 1}, {0, 0}}, {"nilpotent", "nilpotent"}, Missing[], 2, <|"secondOrder" -> "invariant form"|>]], "genus-2", TestID -> "label rule: genus-2 with the Baikov genus"],
  VerificationTest[First /@ {MCBPFLabel[4, {{1, 1}, {0, 0}}, {"nilpotent", "nilpotent"}, Missing[], 2, <|"secondOrder" -> "time limit"|>],
      MCBPFLabel[4, {{1, 1}, {0, 0}}, {"nilpotent", "nilpotent"}, Missing[], 2]}, {"unresolved (order 4)", "unresolved (order 4)"},
    TestID -> "label rule: genus-2 needs the search for pieces of order 2 to finish"],
  VerificationTest[First[MCBPFLabel[4, {{1, 1}, {0, 0}}, {"nilpotent", "nilpotent"}, Missing[], None]], "unresolved (order 4)", TestID -> "label rule: genus-2 needs the Baikov genus"],
  VerificationTest[First[MCBPFLabel[2, {{0, 0}}, {"nilpotent", "nilpotent"}, Missing[], None]], "unresolved (order 2)", TestID -> "label rule: no logs, nonzero p-curvature"]
};

report = TestReport[tests];
Quiet[DeleteDirectory[recDir, DeleteContents -> True]];
Do[With[{r = report["TestResults"][id]},
    Print[If[r["Outcome"] === "Success", "PASS ", "FAIL "], r["TestID"], If[r["Outcome"] === "Success", "",
      "\n     got " <> ToString[Short[r["ActualOutput"], 3], InputForm] <> "\n     expected " <> ToString[Short[r["ExpectedOutput"], 3], InputForm]]]],
  {id, Keys[report["TestResults"]]}];
Print[report["TestsSucceededCount"], " passed, ", report["TestsFailedCount"], " failed, ", Round[report["TimeElapsed"], 0.1]];
Exit[If[report["AllTestsSucceeded"], 0, 1]];
