(* ::Package:: *)

(* ::Title:: *)
(*MaximalCutBasis`PicardFuchs`: the geometry of a maximal cut from its Picard-Fuchs operator*)


(* ::Text:: *)
(*The maximal-cut DE at eps = 0, restricted to a line x(t) through kinematic space, is a connection*)
(*d/dt J = A0(t) J (made regular at eps = 0 first, MCBPFRegularise).  MCBPFClassifyConnection reads it:*)
(*  - its zero pattern splits it into blocks; in each block every rank-one piece whose solution is Prod p^e R (rational*)
(*    functions and their roots), of the system or of its dual, is split off by a change of frame;*)
(*  - each block that is left is turned into one scalar operator L = Sum_k a_k(t) (d/dt)^k by a cyclic vector*)
(*    (MCBPFOperator), of the block's small order; first-order factors of L (MCBPFPeel) are a second chance; what is*)
(*    left is one block B of order k;*)
(*  - at each singular point of B, one per irreducible factor over Q of the leading coefficient plus infinity: the*)
(*    local exponents and the highest power of log in the solutions (MCBPFLocal);*)
(*  - the p-curvature of B at a few primes (MCBPFPCurvature): nilpotent for an operator of geometric origin (Katz),*)
(*    zero when its solutions are algebraic;*)
(*  - for k = 3, whether B carries an invariant quadratic form, as a symmetric square does (MCBPFSymmetricSquareQ).*)
(*MCBPFClassifyOperator turns these into a label per block, MCBPFClassifyConnection into the sector's;*)
(*reference/picard-fuchs.md has the table. The order-n operator of the whole DE is never formed: a random cyclic vector*)
(*gives it apparent singularities of high degree and coefficients thousands of digits long (7 masters of a two-loop*)
(*five-point sector).*)
(*Operators are lists of coefficients {a_0, ..., a_n} in a variable given as an argument; records store them in*)
(*\[FormalT], which has no context to lose when basis.m is read back.*)
(*The factoriser is restricted on purpose: it finds pieces of first order over Q(t), and in blocks of order 4 and 5 pieces*)
(*of order 2 (two elliptic curves glued in one order-4 block, say), through the exterior square. A block that splits only*)
(*into larger pieces stays one block; SageMath's ore_algebra (L.factor()) can split it, and the skill points the user to it.*)


BeginPackage["MaximalCutBasis`PicardFuchs`", {"MaximalCutBasis`", "SkillCore`Tools`", "MaximalCutBasis`Family`", "MaximalCutBasis`Sectors`",
   "MaximalCutBasis`Rules`", "MaximalCutBasis`Derivatives`", "MaximalCutBasis`Kira`", "MaximalCutBasis`Baikov`", "MaximalCutBasis`Curves`",
   "MaximalCutBasis`FiniteFlow`"}];

MCBPicardFuchs::usage = "MCBPicardFuchs[fam, sector, opts] is the picard-fuchs step of one sector: the maximal-cut DE of its masters along a line through the first point of the Kira check in a random direction of small integers (FiniteFlow, MCBFFLineDE), a frame regular at eps = 0 (MCBPFRegularise), the label (MCBPFClassifyConnection) and the order of the corner integral's operator, and two checks: the log points against the Baikov curve on the same line (MCBPFBaikovCheck) and the line DE at t = 0 against Kira's reduction at the first point. Returns the record basis.m keeps under \"classification\". opts: \"Points\" (default MCBPoints[fam, 2, 1], the Kira check's), \"Masters\" and \"KiraRules\" (MCBCutMasters; recounted when absent), \"Representations\" (MCBRepresentations; built when absent), \"Dir\" (working folder, deleted afterwards), \"TimeLimit\" (default $MCBPFTimeLimit), \"Seed\", \"Verbose\" (FiniteFlow's and LiteRed's output).";
MCBPFBaikovCheck::usage = "MCBPFBaikovCheck[classification, cd, line, fam] compares the log points of the block with the points of the line where the Baikov curve of the one-variable representation cd degenerates: the poles of its j-invariant for genus 1, the zeros of its discriminant for higher genus. Returns <|\"status\" -> \"agree\" | \"disagree\" | \"not applicable\", \"genus\", \"curvePoints\", \"logPoints\", \"infinity\" -> {curve, operator}, \"message\"|>.";
MCBPFNonPolylogQ::usage = "MCBPFNonPolylogQ[label] is True for the labels of non-polylogarithmic geometry (elliptic, genus-g, K3, CY_n, and non-polylog (order k) for a block shown not polylogarithmic that no row names); MCBPFPolylogQ[label] for polylog and polylog (nested root).";
MCBPFPolylogQ::usage = "MCBPFPolylogQ[label] is True for polylog and polylog (nested root).";

MCBPFNormalize::usage = "MCBPFNormalize[L, t] clears the denominators of the operator L = {a_0, ..., a_n} and divides by the content: polynomial coefficients with coprime integer coefficients and a positive leading term.";
MCBPFApply::usage = "MCBPFApply[L, f, t] applies the operator L = {a_0, ..., a_n} to the function f.";
MCBPFCompose::usage = "MCBPFCompose[L1, L2, t] is the operator L1 o L2.";
MCBPFAdjoint::usage = "MCBPFAdjoint[L, t] is the formal adjoint Sum_k (-1)^k (d/dt)^k o a_k.";
MCBPFRightDivide::usage = "MCBPFRightDivide[L, R, t] returns {Q, rem} with L = Q o R + rem and ord rem < ord R.";
MCBPFOperator::usage = "MCBPFOperator[A, t, seed] is the operator {a_0, ..., a_k} (MCBPFNormalize'd) of least order that annihilates seed.J for the connection d/dt J = A J (A a matrix of rational functions of t, seed a row vector of them). k is the dimension of the cyclic module of the seed: Length[A] for a cyclic seed.";
MCBPFLaurentMatrix::usage = "MCBPFLaurentMatrix[{A_kmin, ..., A_K}, kmin, eps] is the matrix of Laurent series Sum_k A_k eps^k + O[eps]^(K+1).";
MCBPFRegularise::usage = "MCBPFRegularise[A, t, eps] finds a frame in which the connection d/dt J = A J (A a matrix of eps-Laurent series, MCBPFLaurentMatrix) is regular at eps = 0: diagonal shifts J_i -> eps^s_i J_i when they suffice, else the smallest stable lattice that contains the masters. Returns <|\"status\" -> \"regular\" | \"needOrder\" | \"failed\", \"method\" -> \"none\" | \"diagonal\" | \"lattice\", \"A0\" (the eps = 0 connection, rank Length[A]), \"gauge\" (B with J = B Jhat, Jhat the regular frame), \"order\" (needOrder: the highest power of eps the DE is needed to)|>.";
MCBPFLocal::usage = "MCBPFLocal[L, t, sing] analyses every singular point of L, one per irreducible factor over Q of the leading coefficient plus Infinity (only the factors in the list sing, when given: the others are apparent): <|\"point\", \"degree\", \"fuchsian\", \"exponents\" -> {{e, multiplicity}, ...}, \"irrational\" (exponents not in Q), \"groups\" (exponents modulo integers), \"logPower\" -> {lo, hi} (bounds on the highest power of log), \"apparent\"|> each.";
MCBPFHyperexponentialSolution::usage = "MCBPFHyperexponentialSolution[L, t, local, sing] is a solution of L of the form Prod_i p_i^e_i P (p_i the singular factors, e_i rational, P a polynomial), or None; Missing[\"TooMany\"] when the choices of exponents exceed $MCBPFMaxTuples. sing restricts the singular points as in MCBPFLocal.";
MCBPFPeel::usage = "MCBPFPeel[L, t, sing] removes every first-order factor from the right and then from the left of L: <|\"right\" -> {R_1, ...}, \"left\" -> {..}, \"block\" -> B, \"singular\", \"search\" -> \"complete\" | \"too large\"|>, with L = (left factors) o B o (right factors) up to rational factors. B = {1} when L is a product of first-order operators. sing (the system's singular factors) keeps apparent points out of the right peeling.";
MCBPFPCurvature::usage = "MCBPFPCurvature[L, t, p] is the p-curvature of L modulo the prime p: \"zero\", \"nilpotent\", \"not nilpotent\" or \"bad prime\" (p divides the leading term, or p <= ord L).";
MCBPFSymmetricSquareQ::usage = "MCBPFSymmetricSquareQ[L, t, others, tlim] is True when the third-order operator L is a symmetric square up to a rank-one twist: its module carries an invariant quadratic form. Tested on L itself and on the third-order operators others of the same module (cheap: their coefficients), then on the symmetric square of the module (an order-6 operator, within tlim seconds, default 60). Missing[\"TimedOut\"] when that last test runs out of time.";
MCBPFClassifyOperator::usage = "MCBPFClassifyOperator[L, t, opts] classifies the geometry of the operator L: <|\"label\", \"reason\", \"order\", \"factors\", \"operator\", \"block\", \"local\", \"logPower\", \"pCurvature\", \"symmetricSquare\", \"secondOrder\"|>, operators in \[FormalT]. Options: \"BaikovGenus\" -> g (genus of the Baikov curve on the same line, needed for the genus-g label), \"Primes\" -> Automatic (three good primes from 29 up) or a list, \"Companions\" (other operators of the module, for the symmetric-square test), \"Singular\" (the singular factors of the system L comes from; the other roots of its leading coefficient are apparent and left alone), \"Peeled\" -> True (L is known to have no first-order factor, e.g. from the system: the search for them is skipped), \"SymmetricSquare\" -> True | False (the answer of a test on the system, for order 3; Automatic tests the operator), \"SecondOrder\" (the outcome of the system's search for pieces of order 2, as in MCBPFClassifyConnection; Automatic searches the companion system of a block of order 4 or 5, within \"SecondOrderTime\" -> 120 seconds).";
MCBPFClassifyConnection::usage = "MCBPFClassifyConnection[A0, t, opts] classifies the geometry of the connection d/dt J = A0 J (the eps = 0 maximal-cut DE on a line): its zero pattern splits it into blocks, every rank-one piece with a solution Prod p^e R (of the system or of its dual) is split off by a change of frame, a block of order 4 or 5 is split along a plane of solutions (a piece of order 2) when it has one, and each block that is left is read through the operator of a cyclic vector (MCBPFClassifyOperator). Returns <|\"label\", \"reason\", \"order\" -> n, \"factors\" -> <|\"firstOrder\", \"blocks\" -> {orders}|>, \"blocks\" (each block's classification), \"search\", and the operator, block, local data, log power, p-curvature and symmetric-square test of the block that decides the label|>. Options: \"BaikovGenus\", \"Primes\", \"SymmetricSquareTime\", \"SecondOrderTime\" -> 120 (seconds per block for the search for pieces of order 2), \"SecondOrderMaxOrder\" -> 5 (the largest block searched; 3 switches the search off).";
MCBPFLabel::usage = "MCBPFLabel[k, logPower, pCurvature, symmetricSquare, baikovGenus, extra] applies the label table to a block of order k: {label, reason}. logPower is a list of {lo, hi} per singular point, pCurvature a list of MCBPFPCurvature results. extra (optional): <|\"local\" -> MCBPFLocal data (the exponents tested for elliptic and K3), \"secondOrder\" -> the outcome of the search for pieces of order 2 (needed for order 4 and 5: genus-2 and CY_3 need \"invariant form\", CY_4 a finished search)|>; without them the exponents are not tested and a block of order 4 or 5 counts as not searched.";

Begin["`Private`"];


(* ::Section:: *)
(*Operators*)


trim[L_List] := Module[{l = Together /@ L}, While[Length[l] > 1 && Last[l] === 0, l = Most[l]]; l];

MCBPFNormalize[L_List, t_] := Module[{l = trim[L], den, num, ints, g},
  If[l === {0}, Return[{0}]];
  den = PolynomialLCM @@ (Denominator /@ l);
  num = Expand[Together[# den]] & /@ l;
  ints = LCM @@ Join[{1}, Denominator /@ Flatten[CoefficientList[#, t] & /@ num]];
  num = Expand[ints num];
  g = PolynomialGCD @@ DeleteCases[num, 0];
  num = Expand[Cancel[#/g]] & /@ num;
  If[Coefficient[Last[num], t, Exponent[Last[num], t]] < 0, -num, num]];

MCBPFApply[L_List, f_, t_] := Sum[L[[k + 1]] D[f, {t, k}], {k, 0, Length[L] - 1}];

(* d^i o b = Sum_l Binomial[i, l] b^(i-l) d^l *)
MCBPFCompose[L1_List, L2_List, t_] := Module[{n1 = Length[L1] - 1, n2 = Length[L2] - 1, res},
  res = ConstantArray[0, n1 + n2 + 1];
  Do[If[L1[[i + 1]] =!= 0,
     Do[If[L2[[jj + 1]] =!= 0,
        Do[res[[jj + l + 1]] += L1[[i + 1]] Binomial[i, l] D[L2[[jj + 1]], {t, i - l}], {l, 0, i}]], {jj, 0, n2}]], {i, 0, n1}];
  trim[res]];

MCBPFAdjoint[L_List, t_] := Module[{n = Length[L] - 1, res},
  res = ConstantArray[0, n + 1];
  Do[Do[res[[l + 1]] += (-1)^k Binomial[k, l] D[L[[k + 1]], {t, k - l}], {l, 0, k}], {k, 0, n}];
  trim[res]];

MCBPFRightDivide[L_List, R_List, t_] := Module[{rem = trim[L], r = trim[R], nr, q, k, c, m},
  nr = Length[r] - 1;
  q = ConstantArray[0, Max[1, Length[rem] - nr]];
  While[Length[rem] - 1 >= nr && rem =!= {0},
    k = Length[rem] - 1 - nr; c = Together[Last[rem]/Last[r]];
    q[[k + 1]] = Together[q[[k + 1]] + c];
    m = Length[rem];
    rem = trim[rem - PadRight[MCBPFCompose[Append[ConstantArray[0, k], c], r, t], m]]];
  {trim[q], rem}];

(* h^-1 o L o h with h'/h = u: every d becomes d + u *)
conj[L_List, u_, t_] := Module[{O = {1}, res = {0}, m},
  Do[If[k > 0, O = MCBPFCompose[{u, 1}, O, t]];
    m = Max[Length[res], Length[O]];
    res = PadRight[res, m] + L[[k + 1]] PadRight[O, m], {k, 0, Length[L] - 1}];
  trim[res]];

opOrder[L_List] := Length[trim[L]] - 1;


(* ::Section:: *)
(*Cyclic vector*)


randomPoints[k_] := Table[RandomInteger[{10^5, 10^6}]/RandomInteger[{10^3, 10^4}], {k}];

MCBPFOperator[A_?MatrixQ, t_, seed_List] := Module[{n = Length[A], vs, v, pts = randomPoints[2], k, rows, M, sol},
  vs = {Together /@ seed}; v = First[vs]; k = n;
  If[AllTrue[v, # === 0 &], Return[{1}]];
  If[Max[MatrixRank[{v} /. t -> #] & /@ pts] == 0, Return[{1}]];
  Do[v = Together /@ (D[v, t] + v . A); AppendTo[vs, v];
    If[Max[MatrixRank[vs /. t -> #] & /@ pts] < Length[vs], k = Length[vs] - 1; Break[]], {n}];
  (* Sum_{i<k} a_i v_i + v_k = 0, solved on k components that are independent at a random point *)
  M = Transpose[vs[[1 ;; k]]];
  rows = pivotColumns[Transpose[M /. t -> First[pts]]];
  sol = Together /@ LinearSolve[M[[rows]], -vs[[k + 1]][[rows]]];
  If[! AllTrue[Together[M . sol + vs[[k + 1]]], # === 0 &], Return[$Failed]];
  MCBPFNormalize[Append[sol, 1], t]];

(* the pivot columns of a numeric matrix: the first independent columns *)
pivotColumns[m_] := Module[{rr = RowReduce[m]},
  DeleteCases[Table[FirstPosition[rr[[i]], x_ /; x != 0, {Missing[]}, {1}, Heads -> False][[1]], {i, Length[rr]}], _Missing]];


(* ::Section:: *)
(*A frame regular at eps = 0*)


(* Laurent series in eps are SeriesData objects, which carry their own precision. sdVal is the valuation (Infinity
   when nothing is known to be non-zero), sdPrec the order up to which the coefficients are known. *)
sdClean[x_SeriesData] := ReplacePart[x, 3 -> (Together /@ x[[3]])];
sdClean[x_] := Together[x];
sdVal[x_SeriesData] := With[{p = FirstPosition[Together /@ x[[3]], c_ /; c =!= 0, None, {1}, Heads -> False]}, If[p === None, Infinity, x[[4]] + First[p] - 1]];
sdVal[x_] := If[Together[x] === 0, Infinity, 0];   (* only eps-free entries arrive here *)
sdPrec[x_SeriesData] := x[[5]];
sdPrec[_] := Infinity;
sdCoef[x_SeriesData, k_] := If[k < x[[5]], Together[SeriesCoefficient[x, k]], Indeterminate];
sdCoef[x_, k_] := If[k == 0, x, 0];

MCBPFLaurentMatrix[coeffs_List, kmin_Integer, eps_] := Module[{K = kmin + Length[coeffs] - 1},
  Table[Sum[coeffs[[k - kmin + 1, i, jj]] eps^k, {k, kmin, K}] + O[eps]^(K + 1), {i, Length[First[coeffs]]}, {jj, Length[First[coeffs]]}]];

(* an O-basis (O = Q(t)[[eps]]) of the module generated by the vectors: pivots of least valuation, one row at a time *)
colBasis[vs0_List, n_Integer] := Module[{vs = vs0, res = {}, rows = Range[n], cand, k, r, v, p},
  While[rows =!= {} && vs =!= {},
    cand = Select[Flatten[Table[{sdVal[vs[[a, b]]], a, b}, {a, Length[vs]}, {b, rows}], 1], #[[1]] < Infinity &];
    If[cand === {}, Break[]];
    {k, r} = Rest[First[SortBy[cand, First]]];
    v = vs[[k]]; p = v[[r]];
    vs = Table[With[{c = sdClean[u[[r]]/p]}, sdClean /@ (u - c v)], {u, Delete[vs, k]}];
    rows = DeleteCases[rows, r];
    vs = Select[vs, Function[u, AnyTrue[u[[rows]], sdVal[#] < Infinity &]]];
    AppendTo[res, v]];
  res];

(* Gauss-Jordan over the Laurent series, pivots of least valuation *)
sdInverse[M_] := Module[{n = Length[M], a, r, piv},
  a = MapThread[Join, {M, IdentityMatrix[n]}];
  Do[
    r = First[SortBy[Select[Range[c, n], sdVal[a[[#, c]]] < Infinity &], sdVal[a[[#, c]]] &], None];
    If[r === None, Return[$Failed, Module]];
    a[[{c, r}]] = a[[{r, c}]];
    piv = a[[c, c]];
    a[[c]] = sdClean /@ (a[[c]]/piv);
    Do[If[i != c, a[[i]] = sdClean /@ (a[[i]] - a[[i, c]] a[[c]])], {i, n}],
    {c, n}];
  a[[All, n + 1 ;;]]];

(* integer shifts J_i -> eps^s_i J_i with s_j - s_i <= val(A_ij): a system of difference constraints (Bellman-Ford) *)
diagonalShifts[A_] := Module[{n = Length[A], ord, s, changed = True, it = 0},
  ord = Map[sdVal, A, {2}];
  If[AnyTrue[Table[ord[[i, i]], {i, n}], # < 0 &], Return[$Failed]];
  s = ConstantArray[0, n];
  While[changed && it <= n, changed = False; it++;
    Do[If[i != jj && ord[[i, jj]] < Infinity && s[[jj]] > s[[i]] + ord[[i, jj]], s[[jj]] = s[[i]] + ord[[i, jj]]; changed = True], {i, n}, {jj, n}]];
  If[changed, $Failed, s - Min[s]]];

regularQ[A_] := AllTrue[Flatten[A], sdVal[#] >= 0 &];

Options[MCBPFRegularise] = {"MaxSteps" -> Automatic};
MCBPFRegularise[A_?MatrixQ, t_, eps_, opts : OptionsPattern[]] := Module[{n = Length[A], Ah = A, s, C, Ci, steps = 0, method = "none", K, gauge, need},
  K = Min[sdPrec /@ Flatten[A]];
  gauge = IdentityMatrix[n];
  If[! regularQ[Ah],
    s = diagonalShifts[Ah];
    If[ListQ[s],
      method = "diagonal";
      Ah = Table[sdClean[eps^(s[[i]] - s[[jj]]) Ah[[i, jj]]], {i, n}, {jj, n}];
      gauge = DiagonalMatrix[eps^(-s)]]];
  (* the smallest lattice that contains the one of the masters and is stable: L -> L + (A - d/dt) L, until A is regular *)
  While[! regularQ[Ah] && steps < Replace[OptionValue["MaxSteps"], Automatic -> 4 n + 4],
    method = "lattice"; steps++;
    C = colBasis[Join[IdentityMatrix[n], Transpose[Ah]], n];
    If[Length[C] != n, Return[<|"status" -> "failed", "method" -> method, "message" -> "the lattice lost rank (not enough orders in eps?)"|>, Module]];
    C = Transpose[C];
    Ci = sdInverse[C];
    If[Ci === $Failed, Return[<|"status" -> "failed", "method" -> method, "message" -> "the lattice basis is singular"|>, Module]];
    Ah = Map[sdClean, Ci . (Ah . C - D[C, t]), {2}];
    gauge = gauge . C];
  Which[
    ! regularQ[Ah], <|"status" -> "failed", "method" -> method, "steps" -> steps, "message" -> "no frame regular at eps = 0 after " <> ToString[steps] <> " lattice steps"|>,
    Min[sdPrec /@ Flatten[Ah]] < 1,
      need = K + 1 - Min[sdPrec /@ Flatten[Ah]];
      <|"status" -> "needOrder", "method" -> method, "order" -> need, "message" -> "the eps^0 part needs the DE up to eps^" <> ToString[need]|>,
    True, <|"status" -> "regular", "method" -> method, "steps" -> steps, "A0" -> Map[sdCoef[#, 0] &, Ah, {2}],
      "shifts" -> If[ListQ[s], s, ConstantArray[0, n]], "gauge" -> gauge|>]];


(* ::Section:: *)
(*Local analysis*)


(* x (x - 1) ... (x - k + 1), expanded *)
fall[x_, k_] := Product[x - i, {i, 0, k - 1}];

(* multiplicity of the irreducible polynomial p in a *)
mult[a_, p_, t_] := Module[{m = 0, q = a},
  If[q === 0, Return[Infinity]];
  While[PolynomialRemainder[q, p, t] === 0, q = PolynomialQuotient[q, p, t]; m++];
  m];

(* elements of Q(al), al a root of P, are polynomials in al of degree < deg P *)
nfRed[x_, P_, al_] := PolynomialRemainder[Expand[x], P, al];
mulMatrix[x_, P_, al_, d_] := Transpose[Table[PadRight[CoefficientList[nfRed[x al^i, P, al], al], d], {i, 0, d - 1}]];

(* the operator in s = 1/t, written in the same variable *)
atInfinity[L_List, t_] := Module[{th = {0, -t^2}, pw = {1}, res = {0}, m},
  Do[If[k > 0, pw = MCBPFCompose[th, pw, t]];
    m = Max[Length[res], Length[pw]];
    res = PadRight[res, m] + (L[[k + 1]] /. t -> 1/t) PadRight[pw, m], {k, 0, Length[L] - 1}];
  MCBPFNormalize[res, t]];

localAt[L_List, t_, p_] := Module[{n = Length[L] - 1, d, P, al, s, lam, ms, delta, coef, f, fd, rankQ, I0, Ijs, G, exps = {}, irr, groups},
  d = Exponent[p, t]; P = p /. t -> al;
  ms = Table[mult[L[[k + 1]], p, t], {k, 0, n}];
  delta = Min[Table[ms[[k + 1]] - k, {k, 0, n}]];
  If[delta != ms[[n + 1]] - n, Return[<|"point" -> p, "degree" -> d, "fuchsian" -> False, "logPower" -> {0, Infinity}, "apparent" -> False|>]];
  (* the Taylor coefficients a_k^(i)(al)/i! in Q(al), only those asked for: the operators of large blocks have coefficients of
     degree in the hundreds, and expanding them whole at an algebraic point is what used to cost minutes *)
  coef[k_, i_] := coef[k, i] = If[i < 0 || L[[k + 1]] === 0 || i > Exponent[L[[k + 1]], t], 0,
    nfRed[(D[L[[k + 1]], {t, i}] /. t -> al)/i!, P, al]];
  (* L s^x = Sum_j f_j(x) s^(x + delta + j) near the point *)
  f[jj_, x_] := nfRed[Sum[coef[k, delta + k + jj] fall[x, k], {k, 0, n}], P, al];
  (* its derivative in the exponent: L (s^x log s) = Sum_j (f_j'(x) + f_j(x) log s) s^(x + delta + j) *)
  fd[jj_, x_] := nfRed[D[Sum[coef[k, delta + k + jj] fall[lam, k], {k, 0, n}], lam] /. lam -> x, P, al];
  rankQ[m_] := If[d == 1, MatrixRank[m], MatrixRank[ArrayFlatten[Map[mulMatrix[#, P, al, d] &, m, {2}]]]/d];
  I0 = f[0, lam];
  (* a rational exponent is a common root of the coefficients of every power of al *)
  Ijs = DeleteCases[CoefficientList[I0, al], 0];
  G = PolynomialGCD @@ Ijs;
  Do[If[Exponent[fc[[1]], lam] == 1,
      AppendTo[exps, {-Coefficient[fc[[1]], lam, 0]/Coefficient[fc[[1]], lam, 1], fc[[2]]}]], {fc, FactorList[G]}];
  exps = SortBy[exps, First];
  irr = n - Total[Last /@ exps, {1}];
  groups = Table[Module[{vals = Sort[First /@ grp], mus, e0, nn, M, Md, lf, l1, mu},
      mus = Last /@ SortBy[grp, First]; e0 = First[vals]; nn = Last[vals] - e0; mu = Total[mus];
      (* truncated Frobenius system: s^e0 (c_0 + ... + c_nn s^nn) solves L up to s^(e0 + delta + nn) *)
      M = Table[If[i <= m, f[m - i, e0 + i], 0], {m, 0, nn}, {i, 0, nn}];
      lf = nn + 1 - rankQ[M];
      (* with several Jordan blocks, count the solutions phi0 + log phi1 as well: L phi1 = 0 and L phi0 + (d/dx L) phi1 = 0;
         when they fill the group, no solution has log^2 *)
      l1 = If[1 < lf < mu,
        Md = Table[If[i <= m, fd[m - i, e0 + i], 0], {m, 0, nn}, {i, 0, nn}];
        2 (nn + 1) - rankQ[ArrayFlatten[{{M, Md}, {0, M}}]], None];
      <|"values" -> vals, "multiplicity" -> mu, "logFree" -> lf,
        "logPower" -> Which[lf >= mu, {0, 0}, lf == 1, {mu - 1, mu - 1}, l1 === mu, {1, 1},
          True, {Max[2, Ceiling[mu/lf] - 1], mu - lf}]|>],
    {grp, GatherBy[exps, Mod[First[#], 1] &]}];
  <|"point" -> p, "degree" -> d, "fuchsian" -> True, "exponents" -> exps, "irrational" -> irr, "groups" -> groups,
    "logPower" -> If[groups === {}, {0, 0}, {Max[#[[1]] & /@ (Lookup[groups, "logPower"])], Max[#[[2]] & /@ (Lookup[groups, "logPower"])]}],
    "apparent" -> (irr == 0 && AllTrue[exps, IntegerQ[#[[1]]] && #[[1]] >= 0 && #[[2]] == 1 &] && Total[Lookup[groups, "logFree"]] == n)|>];

(* sing: the irreducible factors to analyse (the singular points of the system the operator comes from); the other roots of
   the leading coefficient are apparent singularities a cyclic vector brings in, and are left alone *)
MCBPFLocal[L_List, t_, sing_ : Automatic] := Module[{l = MCBPFNormalize[L, t], facs},
  If[Length[l] < 2, Return[{}]];
  facs = If[sing === Automatic, Select[First /@ FactorList[Last[l]], ! FreeQ[#, t] &],
    Select[DeleteDuplicates[sing], ! FreeQ[#, t] && PolynomialRemainder[Last[l], #, t] === 0 &]];
  Append[localAt[l, t, #] & /@ facs, Join[localAt[atInfinity[l, t], t, t], <|"point" -> Infinity|>]]];


(* ::Section:: *)
(*First-order factors*)


$MCBPFMaxTuples = 20000;

MCBPFHyperexponentialSolution[L_List, t_, local_ : Automatic, sing_ : Automatic] := Module[{l = MCBPFNormalize[L, t], loc, fin, inf, opts, lamInf, S, Ns, nmax, u, ltw,
    cc, c, P, eqs, ns},
  If[Length[l] < 2, Return[None]];
  loc = If[local === Automatic, MCBPFLocal[l, t, sing], local];
  fin = Select[loc, #["point"] =!= Infinity &];
  inf = SelectFirst[loc, #["point"] === Infinity &];
  If[! TrueQ[inf["fuchsian"]], Return[None]];
  (* the order of a solution at a singular point is an exponent there: one choice per class modulo integers, the polynomial
     factor P supplies the integer shift; at an apparent (or irregular) point P alone carries it *)
  opts = Table[If[TrueQ[pt["apparent"]] || ! TrueQ[pt["fuchsian"]], {0}, Union[Min[#["values"]] & /@ pt["groups"]]], {pt, fin}];
  lamInf = Union[First /@ inf["exponents"]];
  If[Times @@ (Length /@ opts) > $MCBPFMaxTuples, Return[Missing["TooMany"]]];
  Do[
    S = Total[MapThread[#1 Exponent[#2["point"], t] &, {tup, fin}]];
    (* at infinity the solution is t^(S + deg P) = s^(-S - deg P): -S - deg P is an exponent there *)
    Ns = Select[-lamInf - S, IntegerQ[#] && # >= 0 &];
    If[Ns === {}, Continue[]];
    nmax = Max[Ns];
    u = Total[MapThread[#1 D[#2["point"], t]/#2["point"] &, {tup, fin}]];
    ltw = MCBPFNormalize[conj[l, u, t], t];
    c = Table[cc[i], {i, 0, nmax}];
    P = c . t^Range[0, nmax];
    eqs = DeleteCases[CoefficientList[Expand[MCBPFApply[ltw, P, t]], t], 0];
    ns = If[eqs === {}, {UnitVector[nmax + 1, 1]}, NullSpace[Normal[CoefficientArrays[eqs, c][[2]]]]];
    If[ns =!= {},
      Return[Times @@ MapThread[#2["point"]^#1 &, {tup, fin}] (First[ns] . t^Range[0, nmax]), Module]],
    {tup, Tuples[opts]}];
  None];

(* a quotient L = Q o R is singular where R's coefficients are: those factors join the singular set *)
peelRight[B0_List, t_, sing0_ : Automatic] := Module[{B = MCBPFNormalize[B0, t], fs = {}, y, R, q, rem, sing = sing0, st = "complete"},
  While[Length[B] > 1,
    y = MCBPFHyperexponentialSolution[B, t, Automatic, sing];
    If[MissingQ[y], st = "too large"; Break[]];
    If[y === None, Break[]];
    R = MCBPFNormalize[{-Together[D[y, t]/y], 1}, t];
    {q, rem} = MCBPFRightDivide[B, R, t];
    If[rem =!= {0}, Break[]];
    AppendTo[fs, R]; B = MCBPFNormalize[q, t];
    If[sing =!= Automatic, sing = Union[sing, Select[First /@ FactorList[Last[R]], ! FreeQ[#, t] &]]]];
  {fs, B, sing, st}];

MCBPFPeel[L_List, t_, sing_ : Automatic] := Module[{right, left, B, Bs, sing1, sing2, st1, st2},
  {right, B, sing1, st1} = peelRight[L, t, sing];
  If[Length[B] < 2, Return[<|"right" -> right, "left" -> {}, "block" -> {1}, "singular" -> sing1, "search" -> st1|>]];
  (* a left factor of B is the adjoint of a right factor of B*; the apparent points of B carry poles in B*, so B* has
     all its points analysed *)
  {left, Bs, sing2, st2} = peelRight[MCBPFAdjoint[B, t], t, Automatic];
  <|"right" -> right, "left" -> Reverse[MCBPFNormalize[MCBPFAdjoint[#, t], t] & /@ left],
    "block" -> If[Length[Bs] < 2, {1}, MCBPFNormalize[MCBPFAdjoint[Bs, t], t]],
    "singular" -> If[sing1 === Automatic, Automatic, Union[sing1, Flatten[Select[First /@ FactorList[Last[#]], ! FreeQ[#, t] &] & /@ left]]],
    "search" -> If[st1 === "complete" && st2 === "complete", "complete", "too large"]|>];


(* ::Section:: *)
(*p-curvature*)


(* polynomials modulo p as coefficient lists *)
pTrim[a_List] := Module[{b = a}, While[b =!= {} && Last[b] == 0, b = Most[b]]; b];
pAdd[a_List, b_List, p_] := With[{m = Max[Length[a], Length[b]]}, pTrim[Mod[PadRight[a, m] + PadRight[b, m], p]]];
pMul[a_List, b_List, p_] := If[a === {} || b === {}, {}, pTrim[Mod[ListConvolve[a, b, {1, -1}, 0], p]]];
pDer[a_List, p_] := If[Length[a] <= 1, {}, pTrim[Mod[Rest[a] Range[Length[a] - 1], p]]];
pMatMul[A_, B_, p_] := Table[Fold[pAdd[#1, #2, p] &, {}, Table[pMul[A[[i, k]], B[[k, jj]], p], {k, Length[B]}]], {i, Length[A]}, {jj, Length[First[B]]}];

(* the system Y' = C Y of Y = (y, y', ..., y^(k-1)) has the connection d - C; its p-curvature (d - C)^p on constant
   vectors: M_1 = -C, M_(j+1) = M_j' - C M_j. With -C = Cn/b and M_j = N_j/b^j: N_(j+1) = b N_j' - j b' N_j + Cn N_j *)
MCBPFPCurvature[L_List, t_, p_Integer] := Module[{l = MCBPFNormalize[L, t], k, cl, b, db, Cn, N, CN, zero},
  k = Length[l] - 1;
  If[k < 1 || p <= k, Return["bad prime"]];
  cl = Mod[CoefficientList[#, t], p] & /@ l;
  b = pTrim[Last[cl]];
  If[b === {} || Length[b] != Length[CoefficientList[Last[l], t]], Return["bad prime"]];
  db = pDer[b, p];
  Cn = Table[Which[i < k && jj == i + 1, pTrim[Mod[-b, p]], i < k, {}, True, pTrim[cl[[jj]]]], {i, k}, {jj, k}];
  N = Cn;
  Do[CN = pMatMul[Cn, N, p];
    N = Table[pAdd[pAdd[pMul[b, pDer[N[[i, jj]], p], p], pMul[Mod[{-j}, p], pMul[db, N[[i, jj]], p], p], p], CN[[i, jj]], p], {i, k}, {jj, k}],
    {j, 1, p - 1}];
  zero[m_] := AllTrue[Flatten[m, 1], # === {} &];
  Which[zero[N], "zero",
    zero[Nest[pMatMul[#, N, p] &, N, k - 1]], "nilpotent",
    True, "not nilpotent"]];


(* ::Section:: *)
(*Symmetric square*)


(* the symmetric square of the system Y' = C Y, on the monomials Y_i Y_j (i <= j) *)
sym2Matrix[C_] := Module[{n = Length[C], mons, pos, S},
  mons = Select[Tuples[Range[n], 2], #[[1]] <= #[[2]] &];
  pos[{i_, jj_}] := First[FirstPosition[mons, Sort[{i, jj}]]];
  S = ConstantArray[0, {Length[mons], Length[mons]}];
  Do[With[{i = mons[[r, 1]], jj = mons[[r, 2]]},
     Do[S[[r, pos[{kk, jj}]]] += C[[i, kk]]; S[[r, pos[{i, kk}]]] += C[[jj, kk]], {kk, n}]], {r, Length[mons]}];
  Together /@ S];

(* with the d^2 term removed, Sym^2(d^2 + r) = d^3 + 4 r d + 2 r' *)
literalSym2Q[L_List, t_] := Module[{a, lt},
  If[Length[L] != 4, Return[False]];
  a = Together[#/L[[4]]] & /@ L;
  lt = conj[a, -a[[3]]/3, t];
  lt = Together[#/Last[lt]] & /@ lt;
  Together[lt[[1]] - D[lt[[2]], t]/2] === 0];

MCBPFSymmetricSquareQ[L_List, t_, others_List : {}, tlim_ : 60] := Module[{l = MCBPFNormalize[L, t], a, C, S, r},
  If[Length[l] != 4, Return[False]];
  If[AnyTrue[Prepend[others, l], literalSym2Q[#, t] &], Return[True]];
  (* another cyclic vector of the same module: an invariant quadratic form is a hyperexponential solution of Sym^2 of the module *)
  a = Together[#/l[[4]]] & /@ l;
  C = {{0, 1, 0}, {0, 0, 1}, -a[[1 ;; 3]]};
  S = sym2Matrix[C];
  r = TimeConstrained[With[{op = MCBPFOperator[S, t, RandomInteger[{1, 9}, Length[S]]]},
      op =!= $Failed && MCBPFHyperexponentialSolution[op, t] =!= None], tlim, Missing["TimedOut"]];
  r];


(* ::Section:: *)
(*Labels*)


(* The search for pieces of order 2 of a block of order 4 or 5 ran to its end and found no plane: with no first-order
   piece either, the block is irreducible. Blocks of order 2 and 3 need no search; blocks above 5 are not searched *)
searchedQ[k_, so_] := Which[k <= 3, True, k <= 5, MemberQ[{"none", "invariant form"}, so], True, False];

(* The local monodromies of a family of elliptic curves lie in SL2(Z): of finite order 1, 2, 3, 4 or 6, or unipotent up to
   sign. Up to a rank-one twist, which shifts every exponent at a point by the same amount, the two exponents at a point
   then differ by 0, 1/2, 1/3 or 2/3 modulo 1, and the three of Sym^2 of such a block are c - d, c, c + d. Returns the
   first point where this fails, {point, exponents}, or None (also when no local data are given). A necessary condition:
   2F1(1/5, 4/5; 1; t) fails it at infinity (exponents 1/5, 4/5) *)
$ellipticDiffs = {0, 1/2, 1/3, 2/3};
ellipticExponentsQ[vals_List] := Switch[Length[vals],
  2, MemberQ[$ellipticDiffs, Mod[vals[[2]] - vals[[1]], 1]],
  3, AnyTrue[Range[3], With[{c = vals[[#]], o = Delete[vals, #]}, Mod[Total[o] - 2 c, 1] == 0 && MemberQ[$ellipticDiffs, Mod[o[[1]] - c, 1]]] &],
  _, True];
ellipticExponentFailure[k_, local_List] := Module[{pts},
  pts = Select[local, AssociationQ[#] && TrueQ[Lookup[#, "fuchsian", False]] && ListQ[Lookup[#, "exponents", None]] &];
  pts = {#["point"], Flatten[ConstantArray[#[[1]], #[[2]]] & /@ #["exponents"]]} & /@ pts;
  SelectFirst[pts, Length[#[[2]]] == k && ! ellipticExponentsQ[#[[2]]] &, None]];
pointText[Infinity] = "infinity";
pointText[p_] := If[LeafCount[p] < 40, "the root of " <> ToString[p, InputForm], "a root of a factor of degree " <> ToString[Exponent[p, First[Variables[p]]]]];

MCBPFLabel[k_Integer, logPower_List, pCurv_List, sym2_, baikovGenus_, extra_Association : <||>] := Module[{lo, hi, good = DeleteCases[pCurv, "bad prime"], exact,
    so = Lookup[extra, "secondOrder", Automatic], searched, mid, ellBad, ks = ToString[k], km = ToString[k - 1], np, unres},
  If[k == 0, Return[{"polylog", "every factor is of first order: the solutions are rational functions and their roots (and logarithms of them)"}]];
  If[good === {}, Return[{"unresolved (order " <> ks <> ")", "every prime tried is bad for the p-curvature"}]];
  If[MemberQ[good, "not nilpotent"],
    Return[{"unresolved (order " <> ks <> ")", "the p-curvature is not nilpotent: the block is not of geometric origin (check the DE)"}]];
  lo = Max[First /@ logPower]; hi = Max[Last /@ logPower];
  exact[m_] := MemberQ[logPower, {m, m}];
  searched = searchedQ[k, so];
  (* Sym^(k-1) of a block of order 2 has a log of power 0 or k - 1 at every point: a power in between rules it out *)
  mid = AnyTrue[logPower, #[[1]] >= 1 && #[[2]] <= k - 2 &];
  ellBad = If[MemberQ[{2, 3}, k], ellipticExponentFailure[k, Lookup[extra, "local", {}]], None];
  (* an irreducible block with a log has infinite monodromy, so it is not polylogarithmic, even when no row names it *)
  np[why_] := {"non-polylog (order " <> ks <> ")", why};
  unres[why_] := {"unresolved (order " <> ks <> ")", why};
  Which[
    hi == 0 && AllTrue[good, # === "zero" &],
      {"polylog (nested root)", "an irreducible block of order " <> ks <> " with finite monodromy (zero p-curvature): algebraic solutions that are not roots of rational functions, such as Sqrt[A + B Sqrt[D]]"},
    hi == 0,
      unres["no logarithm at any singular point, but the p-curvature is not zero: infinite monodromy without degenerations"],
    so === "split",
      unres["the block splits into pieces of order 2: MCBPFClassifyConnection on its system labels them"],
    k == 2 && ellBad === None,
      {"elliptic", "an irreducible block of order 2 with a logarithm at a singular point, and at every point the exponents of a family of elliptic curves (differences 0, 1/2, 1/3 or 2/3 modulo 1)"},
    k == 2,
      np["an irreducible block of order 2 with a logarithm, so not polylogarithmic; but its exponents " <> ToString[ellBad[[2]], InputForm] <> " at " <>
        pointText[ellBad[[1]]] <> " are not those of a family of elliptic curves (differences 0, 1/2, 1/3 or 2/3 modulo 1): an order-2 piece of the periods of a curve of higher genus, say"],
    k == 3 && exact[2] && TrueQ[sym2] && ellBad === None,
      {"K3", "an order-3 block with a point of maximal unipotent monodromy (log^2) that is a symmetric square, with the exponents of the symmetric square of a family of elliptic curves"},
    k == 3 && exact[2] && TrueQ[sym2],
      np["an order-3 block with a point of maximal unipotent monodromy (log^2) that is a symmetric square, so not polylogarithmic; but its exponents " <>
        ToString[ellBad[[2]], InputForm] <> " at " <> pointText[ellBad[[1]]] <> " are not those of the symmetric square of a family of elliptic curves"],
    k == 3 && exact[2] && MissingQ[sym2],
      unres["an order-3 block with a point of maximal unipotent monodromy (log^2); the symmetric-square test ran out of time"],
    k >= 4 && exact[k - 1] && searched && mid && (k != 4 || so === "invariant form"),
      {"CY_" <> km, "an irreducible order-" <> ks <> " block with a point of maximal unipotent monodromy (log^" <> km <> ") and a point with a log of lower power, so not a symmetric power of an order-2 block" <>
        Switch[k, 4, "; it keeps an invariant symplectic form", 5, " (an invariant quadratic form is not tested)", _, ""]},
    (* a point of maximal unipotent monodromy needs a single Jordan block of size k, which no polylogarithmic block without
       first-order pieces has: its unipotent part would vanish on each piece of finite monodromy, of which there are at most k - 2 *)
    k >= 4 && exact[k - 1],
      np["a point of maximal unipotent monodromy (log^" <> km <> "), so not polylogarithmic; Calabi-Yau is not shown: " <> Which[
         k > 5, "a block of order above 5 is not searched for smaller pieces",
         ! searched, "the search for pieces of order 2 did not finish (" <> ToString[so] <> ")",
         k == 4 && so =!= "invariant form", "the block keeps no invariant symplectic form",
         True, "every log point has that power, as in the symmetric power Sym^" <> km <> " of an elliptic block"]],
    EvenQ[k] && k > 2 && lo == 1 && hi == 1 && baikovGenus === k/2 && searched && (k != 4 || so === "invariant form"),
      {"genus-" <> ToString[k/2], "an irreducible order-" <> ks <> " block with simple logarithms only and an invariant symplectic form, and the Baikov curve on the line has genus " <> ToString[k/2]},
    True,
      unres["a block of order " <> ks <> " with logarithms up to power " <>
        If[lo == hi, ToString[hi], ToString[lo] <> "-" <> ToString[hi]] <> " that matches no row of the table" <>
        If[EvenQ[k] && hi == 1, " (genus " <> ToString[k/2] <> " needs " <> Which[
            baikovGenus =!= k/2, "a Baikov curve of that genus on the line",
            k > 5, "a block searched for smaller pieces, and blocks above order 5 are not",
            True, "an irreducible block with one invariant symplectic form"] <> ")", ""] <>
        "; SageMath's ore_algebra (L.factor()) can split it"]]];

(* primes above the order that keep the singular points apart: p divides neither the leading term nor the discriminant
   of the square-free leading coefficient (on a random line the numbers are large, and small primes often collide) *)
goodPrimes[L_List, t_, n_Integer] := Module[{b = Last[L], sq, lc, disc, ps = {}, p = 29},
  sq = Times @@ Select[First /@ FactorList[b], ! FreeQ[#, t] &];
  lc = Coefficient[b, t, Exponent[b, t]];
  disc = If[Exponent[sq, t] > 1, Discriminant[sq, t], 1];
  While[Length[ps] < n && p < 10^4,
    If[p > Length[L] - 1 && Mod[Numerator[lc], p] != 0 && Mod[Numerator[disc], p] != 0, AppendTo[ps, p]];
    p = NextPrime[p]];
  ps];

Options[MCBPFClassifyOperator] = {"BaikovGenus" -> None, "Primes" -> Automatic, "Companions" -> {}, "SymmetricSquareTime" -> 60, "Singular" -> Automatic,
  "Peeled" -> False, "SymmetricSquare" -> Automatic, "SecondOrder" -> Automatic, "SecondOrderTime" -> 120};
MCBPFClassifyOperator[L_List, t_, opts : OptionsPattern[]] := Module[{l = MCBPFNormalize[L, t], peel, B, k, loc = {}, pc = {}, sym2 = Missing["NotApplicable"],
    lab, ft = \[FormalT], bad, comps, so = OptionValue["SecondOrder"]},
  peel = If[TrueQ[OptionValue["Peeled"]],
    <|"right" -> {}, "left" -> {}, "block" -> l, "singular" -> OptionValue["Singular"], "search" -> "complete"|>,
    MCBPFPeel[l, t, OptionValue["Singular"]]];
  B = peel["block"]; k = Length[B] - 1;
  If[k > 0,
    loc = MCBPFLocal[B, t, peel["singular"]];
    pc = AssociationMap[MCBPFPCurvature[B, t, #] &, Replace[OptionValue["Primes"], Automatic :> goodPrimes[B, t, 3]]];
    (* other operators of the module (the corner integral's): their order-3 blocks are tried for the cheap test first *)
    (* the answer of the system's own test (classifyBlock), when it has one *)
    If[k == 3 && BooleanQ[OptionValue["SymmetricSquare"]], sym2 = OptionValue["SymmetricSquare"],
      comps = If[k == 3, Select[If[TrueQ[OptionValue["Peeled"]], MCBPFNormalize[#, t] &, MCBPFPeel[#, t]["block"] &] /@ OptionValue["Companions"], Length[#] == 4 &], {}];
      If[k == 3, sym2 = MCBPFSymmetricSquareQ[B, t, comps, OptionValue["SymmetricSquareTime"]]]]];
  bad = Which[
    peel["search"] =!= "complete", "the search for first-order factors has too many choices of exponents",
    k > 0 && ! AllTrue[loc, TrueQ[#["fuchsian"]] &], "the block has an irregular singular point: not of geometric origin (check the DE)",
    k > 0 && AnyTrue[loc, #["irrational"] > 0 &], "the block has exponents that are not rational: not of geometric origin (check the DE)",
    True, None];
  (* an operator classified on its own (no system to say it) is searched for pieces of order 2 on its companion system *)
  If[bad === None && so === Automatic && 4 <= k <= 5,
    so = TimeConstrained[secondOrderSplit[companionOf[B, t], t], OptionValue["SecondOrderTime"], <|"status" -> "time limit"|>]["status"]];
  If[so === Automatic, so = If[k <= 3, "not needed", "not searched"]];
  lab = If[bad =!= None, {"unresolved (order " <> ToString[k] <> ")", bad},
    MCBPFLabel[k, Lookup[loc, "logPower", {}], If[k > 0, Values[pc], {}], sym2, OptionValue["BaikovGenus"], <|"local" -> loc, "secondOrder" -> so|>]];
  <|"label" -> lab[[1]], "reason" -> lab[[2]], "order" -> Length[l] - 1,
    "factors" -> <|"right" -> Length[peel["right"]], "block" -> k, "left" -> Length[peel["left"]]|>,
    "operator" -> (l /. t -> ft), "block" -> (B /. t -> ft),
    "local" -> (KeyDrop[#, {"groups"}] & /@ loc /. t -> ft), "logPower" -> If[loc === {}, {0, 0}, {Max[First /@ Lookup[loc, "logPower"]], Max[Last /@ Lookup[loc, "logPower"]]}],
    "pCurvature" -> pc, "symmetricSquare" -> sym2, "secondOrder" -> so|>];

(* the companion system Y' = C Y of Y = (y, y', ..., y^(k-1)) *)
companionOf[L_List, t_] := With[{a = Together[#/Last[L]] & /@ L, n = Length[L] - 1},
  Table[If[i < n, If[jj == i + 1, 1, 0], -a[[jj]]], {i, n}, {jj, n}]];


(* ::Section:: *)
(*The connection: blocks and first-order pieces*)


(* The eps = 0 connection of n masters, read without ever forming its order-n operator, whose coefficients a random cyclic
   vector makes huge (apparent singularities): the zero pattern splits it into blocks (strongly connected components, the
   pieces of a triangular form); in each block, a solution h R of the system or of its dual (h = Prod p^e, R a polynomial
   vector) splits off a rank-one piece by a change of frame, until none is left; what remains is read through the
   operator of a small system. *)

sysSingular[A_, t_] := Union[Select[First /@ FactorList[PolynomialLCM @@ (Denominator[Together[#]] & /@ Flatten[A])], ! FreeQ[#, t] &]];

(* a seed with a part linear in t is cyclic even for a connection that is zero; it shifts the exponent at infinity by
   at most one, which only makes the degree bound below larger. Its exponents at the singular points are those of the
   system unless seed.R vanishes there by accident: large random integers make that negligible (with 1..9 it happened) *)
cyclicSeed[k_, i_] := BlockRandom[RandomInteger[{1, 10^6}, k] + t0 RandomInteger[{1, 10^6}, k], RandomSeeding -> 101 + i];

(* a solution Prod p^e R of Y' = A Y: the exponents are those of a cyclic operator at the singular points of A *)
(* "accept" picks a solution from the null space of one choice of exponents (First), or None to go on; every null space
   found is also sown with the tag "hyperexp" *)
vectorHyperexp[A_, t_, sing_, try_, accept_ : First] := Module[{k = Length[A], L, loc, fin, inf, opts, lamInf, S, Ns, nmax, u, M, D0, rr, R, eqs, ns, cc,
    rs, pick},
  L = MCBPFOperator[A, t, cyclicSeed[k, try] /. t0 -> t];
  If[L === $Failed || Length[L] - 1 < k, Return[$Failed]];
  loc = MCBPFLocal[L, t, sing];
  fin = Select[loc, #["point"] =!= Infinity &]; inf = SelectFirst[loc, #["point"] === Infinity &];
  If[! TrueQ[inf["fuchsian"]], Return[None]];
  opts = Table[If[TrueQ[pt["apparent"]] || ! TrueQ[pt["fuchsian"]], {0}, Union[Min[#["values"]] & /@ pt["groups"]]], {pt, fin}];
  lamInf = Union[First /@ inf["exponents"]];
  If[Times @@ (Length /@ opts) > $MCBPFMaxTuples, Return[Missing["TooMany"]]];
  Do[
    S = Total[MapThread[#1 Exponent[#2["point"], t] &, {tup, fin}]];
    Ns = Select[-lamInf - S, IntegerQ[#] && # >= 0 &];
    If[Ns === {}, Continue[]];
    nmax = Max[Ns];
    u = Total[MapThread[#1 D[#2["point"], t]/#2["point"] &, {tup, fin}]];
    (* R' = (A - u) R, times a common denominator *)
    M = Together[A - u IdentityMatrix[k]];
    D0 = PolynomialLCM @@ (Denominator /@ Flatten[M]);
    rr = Table[cc[i, d], {i, k}, {d, 0, nmax}];
    R = rr . t^Range[0, nmax];
    eqs = DeleteCases[Flatten[CoefficientList[Expand[D0 D[R, t] - Together[D0 M] . R], t]], 0];
    ns = If[eqs === {}, {UnitVector[k (nmax + 1), 1]}, NullSpace[Normal[CoefficientArrays[eqs, Flatten[rr]][[2]]]]];
    If[ns =!= {},
      rs = Expand[Partition[#, nmax + 1] . t^Range[0, nmax]] & /@ ns;
      Sow[rs, "hyperexp"];
      pick = accept[rs];
      If[pick =!= None, Return[<|"u" -> u, "R" -> pick|>, Module]]],
    {tup, Tuples[opts]}];
  None];

(* the entry of R used for the new frame: non-zero, of lowest degree *)
pivotOf[R_, t_] := First[SortBy[Select[Range[Length[R]], Together[R[[#]]] =!= 0 &], Exponent[R[[#]], t] &]];

(* Y = h R: in the frame Y = T Z with T e_1 = R, the first column of the new matrix is u e_1; the rest is a closed system *)
splitQuotient[A_, t_, R_] := Module[{k = Length[A], i, T, At},
  i = pivotOf[R, t];
  T = IdentityMatrix[k]; T[[All, i]] = R;
  T = T[[All, Prepend[Delete[Range[k], i], i]]];
  At = Together[Inverse[T] . (A . T - D[T, t])];
  If[! AllTrue[At[[2 ;;, 1]], # === 0 &], $Failed, At[[2 ;;, 2 ;;]]]];

(* a solution h R of the dual Y' = -A^T Y is a linear form R.Y with (R.Y)' = -u R.Y: in the frame Z = S Y with first row
   R, the first row of the new matrix is (-u, 0, ...) and the rest is the block below *)
splitSub[A_, t_, R_] := Module[{k = Length[A], i, S, At},
  i = pivotOf[R, t];
  S = IdentityMatrix[k]; S[[i]] = R;
  S = S[[Prepend[Delete[Range[k], i], i]]];
  At = Together[(D[S, t] + S . A) . Inverse[S]];
  If[! AllTrue[At[[1, 2 ;;]], # === 0 &], $Failed, At[[2 ;;, 2 ;;]]]];

(* "search": "complete" when both sides were searched and nothing was found, so that the block left has no first-order
   factor on either side of any cyclic operator; "no cyclic vector" or "not split" when a side was left open *)
peelSystem[A0_, t_] := Module[{A = A0, first = 0, sing, r, st = "complete", next},
  While[Length[A] >= 1,
    sing = sysSingular[A, t];
    next = None; st = "complete";
    Do[
      r = vectorHyperexp[If[side === 1, A, -Transpose[A]], t, sing, 1];
      If[r === $Failed, r = vectorHyperexp[If[side === 1, A, -Transpose[A]], t, sing, 2]];
      If[r === $Failed, st = "no cyclic vector"];
      If[MissingQ[r], st = "too large"; Break[]];
      If[AssociationQ[r], next = If[side === 1, splitQuotient, splitSub][A, t, r["R"]]; If[next =!= $Failed, Break[]]; st = "not split"],
      {side, {1, 2}}];
    If[! MatrixQ[next] && next =!= {}, Break[]];
    A = next; first++];
  <|"firstOrder" -> first, "rest" -> A, "search" -> st|>];

(* Pieces of order 2. A plane of solutions of Y' = B Y (a sub-block of order 2) is a solution W = Y ^ Z of the exterior
   square W' = B W + W B^T that is decomposable: its Pluecker relations vanish. A plane of solutions of the dual -B^T is a
   quotient of order 2. Only order 4 and 5 are searched: in a block of order 3 a piece of order 2 leaves one of order 1,
   which peelSystem has excluded; in order 4 a sub of order 2 has a quotient of order 2, so one side suffices. *)
wedgeSquare[A_, t_] := Module[{k = Length[A], pairs, W, rhs, w},
  pairs = Subsets[Range[k], {2}];
  W = Table[Which[i < j, w[i, j], i > j, -w[j, i], True, 0], {i, k}, {j, k}];
  rhs = A . W + W . Transpose[A];
  Together[Table[Coefficient[rhs[[Sequence @@ p]], w @@ q], {p, pairs}, {q, pairs}]]];

bivector[r_List, k_] := Module[{P = ConstantArray[0, {k, k}]},
  MapThread[(P[[#1[[1]], #1[[2]]]] = #2; P[[#1[[2]], #1[[1]]]] = -#2) &, {Subsets[Range[k], {2}], r}];
  P];
pluecker[r_List, k_] := With[{P = bivector[r, k]},
  Expand[P[[#[[1]], #[[2]]]] P[[#[[3]], #[[4]]]] - P[[#[[1]], #[[3]]]] P[[#[[2]], #[[4]]]] + P[[#[[1]], #[[4]]]] P[[#[[2]], #[[3]]]]] & /@
    Subsets[Range[k], {4}]];

(* a decomposable vector in the span of rs: one of them, or, for a span of two, x r1 + r2 with x rational (two separate
   planes with the same character give a pencil whose generic member is a symplectic form) *)
decomposableIn[rs_List, k_, t_] := Module[{x, eqs, xs},
  Do[If[AllTrue[pluecker[r, k], # === 0 &], Return[r, Module]], {r, rs}];
  If[Length[rs] =!= 2, Return[None]];
  eqs = DeleteCases[Flatten[CoefficientList[#, t] & /@ pluecker[x rs[[1]] + rs[[2]], k]], 0];
  xs = Select[x /. Solve[Thread[eqs == 0], x], MatchQ[#, _Integer | _Rational] &];
  If[xs === {}, None, Expand[First[xs] rs[[1]] + rs[[2]]]]];

(* the frame of a plane given by its Pluecker vector r: two rows of the bivector span it, unit vectors complete them.
   Side 1 (solutions of B): T has the plane as its first columns, and B becomes block upper-triangular. Side 2 (solutions
   of -B^T, linear forms on the solutions): S has the plane as its first rows, and B becomes block lower-triangular.
   Returns {sub, quotient}, or $Failed *)
splitPlane[B_, t_, r_, side_] := Module[{k = Length[B], P, pts = {1009/17, -2003/31}, pt, rows, v, others, T, At},
  P = bivector[r, k];
  pt = SelectFirst[pts, MatrixRank[P /. t -> #] == 2 &, None];
  If[pt === None, Return[$Failed]];
  rows = SelectFirst[Subsets[Range[k], {2}], MatrixRank[P[[#]] /. t -> pt] == 2 &];
  v = P[[rows]];
  others = SelectFirst[Subsets[Range[k], {k - 2}], Det[Join[v, IdentityMatrix[k][[#]]] /. t -> pt] =!= 0 &];
  If[side === 1,
    T = Transpose[Join[v, IdentityMatrix[k][[others]]]];
    At = Together[Inverse[T] . (B . T - D[T, t])];
    If[AllTrue[Flatten[At[[3 ;;, 1 ;; 2]]], # === 0 &], {At[[1 ;; 2, 1 ;; 2]], At[[3 ;;, 3 ;;]]}, $Failed],
    T = Join[v, IdentityMatrix[k][[others]]];
    At = Together[(D[T, t] + T . B) . Inverse[T]];
    If[AllTrue[Flatten[At[[1 ;; 2, 3 ;;]]], # === 0 &], {At[[3 ;;, 3 ;;]], At[[1 ;; 2, 1 ;; 2]]}, $Failed]]];

(* <|"status" -> "split", "pieces" -> {sub, quotient}|>, or the status of a search that split nothing: "none", "invariant
   form" (one invariant bivector, and it is no plane: for order 4 a symplectic form, as the periods of a genus-2 curve
   have), "invariant forms" (several independent ones and no plane among those tried: the same elliptic curve twice,
   V + V, has a net of them, whose decomposable members decomposableIn does not look for), "too large" (more than
   $MCBPFMaxTuples choices of exponents), "no cyclic vector", "not split" *)
secondOrderSplit[B_, t_] := Module[{k = Length[B], L2, sing, r, sown, nInv = 0, st = "none", pc},
  Do[
    L2 = wedgeSquare[If[side === 1, B, -Transpose[B]], t];
    sing = sysSingular[L2, t];
    {r, sown} = Reap[vectorHyperexp[L2, t, sing, 1, decomposableIn[#, k, t] &], "hyperexp"];
    If[r === $Failed, {r, sown} = Reap[vectorHyperexp[L2, t, sing, 2, decomposableIn[#, k, t] &], "hyperexp"]];
    (* the solutions found, one null space per choice of exponents: different choices are different characters *)
    If[sown =!= {}, nInv = Max[nInv, Total[Length /@ First[sown]]]];
    Which[
      MissingQ[r], st = "too large",
      r === $Failed, If[st === "none", st = "no cyclic vector"],
      AssociationQ[r],
        pc = splitPlane[B, t, r["R"], side];
        If[pc =!= $Failed, Return[<|"status" -> "split", "pieces" -> pc|>, Module]];
        st = "not split"],
    {side, If[k == 4, {1}, {1, 2}]}];
  <|"status" -> Which[st =!= "none" || nInv == 0, st, nInv == 1, "invariant form", True, "invariant forms"]|>];

(* the blocks of a block with no first-order piece: split along planes while there are any, each piece peeled again.
   Returns {pieces of first order, {<|"rest", "search", "secondOrder"|>, ...}} *)
secondOrderPieces[B_, search_, t_, {tmax_, kmax_}] := Module[{k = Length[B], r, first = 0, out = {}, part, sub},
  If[k < 4, Return[{0, {<|"rest" -> B, "search" -> search, "secondOrder" -> "not needed"|>}}]];
  If[k > kmax, Return[{0, {<|"rest" -> B, "search" -> search, "secondOrder" -> "not searched (order above " <> ToString[kmax] <> ")"|>}}]];
  r = TimeConstrained[secondOrderSplit[B, t], tmax, <|"status" -> "time limit"|>];
  If[r["status"] =!= "split", Return[{0, {<|"rest" -> B, "search" -> search, "secondOrder" -> r["status"]|>}}]];
  Do[
    part = peelSystem[piece, t];
    first += part["firstOrder"];
    If[MatrixQ[part["rest"]] && Length[part["rest"]] > 0,
      sub = secondOrderPieces[part["rest"], part["search"], t, {tmax, kmax}];
      first += sub[[1]]; out = Join[out, sub[[2]]]],
    {piece, r["pieces"]}];
  {first, out}];

secondOrderText["invariant form"] = "; no piece of order 2: the block keeps an invariant symplectic form, as the periods of a genus-2 curve (or of an abelian surface) do";
secondOrderText["invariant forms"] = "; no piece of order 2 found, but the block keeps several invariant bivectors, as the same elliptic curve seen twice does (a split the search does not find)";
secondOrderText["none"] = "; no piece of order 2";
secondOrderText[s_String] := If[StringStartsQ[s, "not searched"] || MemberQ[{"too large", "time limit", "no cyclic vector", "not split"}, s],
  "; the search for pieces of order 2 did not finish (" <> s <> ")", ""];

(* a block that keeps no first-order piece: the operator of a cyclic vector (small: the order of the block), and for the
   symmetric-square test the operators of its unit vectors. "peeled": the system's search was complete, so these operators
   have no first-order factor and their own search (minutes for a block of order 4, whose operator has apparent points of
   degree near 100 and coefficients of hundreds of digits) is skipped *)
(* an order-3 block with no first-order piece is a symmetric square (up to a character) exactly when Sym^2 of its system has
   a hyperexponential solution: an invariant quadratic form, non-degenerate since a kernel would be a smaller piece. The
   system's own singular points are the only ones read, so a block in the frame of a split (apparent points of high degree
   in its operator) is decided in seconds. True, False, or Automatic (undecided: the operator's test runs) *)
sym2System[B_, t_, tlim_] := Module[{S = sym2Matrix[B]},
  TimeConstrained[
    Module[{x = vectorHyperexp[S, t, sysSingular[S, t], 1]},
      If[x === $Failed, x = vectorHyperexp[S, t, sysSingular[S, t], 2]];
      Which[AssociationQ[x], True, x === None, False, True, Automatic]],
    tlim, Automatic]];

classifyBlock[B_, t_, opts_List, peeled_ : False] := Module[{k = Length[B], op, comps, sing = sysSingular[B, t], s2 = Automatic},
  op = MCBPFOperator[B, t, cyclicSeed[k, 1] /. t0 -> t];
  If[op === $Failed || Length[op] - 1 < k, op = MCBPFOperator[B, t, cyclicSeed[k, 2] /. t0 -> t]];
  If[op === $Failed, Return[<|"label" -> "unresolved (order " <> ToString[k] <> ")", "reason" -> "no cyclic vector for a block", "order" -> k|>]];
  If[k == 3, s2 = sym2System[B, t, Lookup[opts, "SymmetricSquareTime", 60]]];
  comps = If[k == 3 && ! BooleanQ[s2], Select[Quiet[MCBPFOperator[B, t, #] & /@ IdentityMatrix[3]], ListQ[#] && Length[#] == 4 &], {}];
  MCBPFClassifyOperator[op, t, "Singular" -> sing, "Companions" -> comps, "Peeled" -> peeled, "SymmetricSquare" -> s2, Sequence @@ opts]];

blockRank["polylog"] = 0; blockRank["polylog (nested root)"] = 1;
blockRank[l_String] := Which[MCBPFNonPolylogQ[l], 3, StringStartsQ[l, "unresolved"], 2, True, 2];

Options[MCBPFClassifyConnection] = {"BaikovGenus" -> None, "Primes" -> Automatic, "SymmetricSquareTime" -> 60, "SecondOrderTime" -> 120,
  "SecondOrderMaxOrder" -> 5};
MCBPFClassifyConnection[A0_?MatrixQ, t_, opts : OptionsPattern[]] := Module[{n = Length[A0], g, comps, parts, first = 0, rests = {}, recs, st = "complete",
    labs, geomBad, nonpoly, pick, out, ft = \[FormalT], cOpts},
  cOpts = {"BaikovGenus" -> OptionValue["BaikovGenus"], "Primes" -> OptionValue["Primes"], "SymmetricSquareTime" -> OptionValue["SymmetricSquareTime"]};
  g = Graph[Range[n], Flatten[Table[If[i != jj && Together[A0[[i, jj]]] =!= 0, DirectedEdge[i, jj], Nothing], {i, n}, {jj, n}]]];
  comps = ConnectedComponents[g];
  parts = Table[peelSystem[A0[[c, c]], t], {c, comps}];
  first = Total[Lookup[parts, "firstOrder"]];
  If[MemberQ[Lookup[parts, "search"], "too large"], st = "too large"];
  rests = {};
  Do[If[MatrixQ[p["rest"]] && Length[p["rest"]] > 0,
      With[{sp = secondOrderPieces[p["rest"], p["search"], t, {OptionValue["SecondOrderTime"], OptionValue["SecondOrderMaxOrder"]}]},
        first += sp[[1]]; rests = Join[rests, sp[[2]]]]],
    {p, parts}];
  recs = Table[Module[{rec = classifyBlock[p["rest"], t, Append[cOpts, "SecondOrder" -> p["secondOrder"]], p["search"] === "complete"]},
      If[StringStartsQ[rec["label"], "unresolved"] && ! StringContainsQ[Lookup[rec, "reason", ""], "check the DE"],
        rec["reason"] = StringReplace[rec["reason"], "; SageMath" -> secondOrderText[p["secondOrder"]] <> "; SageMath"]];
      Join[rec, <|"size" -> Length[p["rest"]], "secondOrder" -> p["secondOrder"]|>]],
    {p, rests}];
  labs = Lookup[recs, "label", {}];
  geomBad = SelectFirst[recs, StringStartsQ[#["label"], "unresolved"] && StringContainsQ[Lookup[#, "reason", ""], "check the DE"] &, None];
  nonpoly = Select[recs, MCBPFNonPolylogQ[#["label"]] &];
  (* the label of the sector: polylog when every piece is of first order; a block that is not of geometric origin makes
     it unresolved; otherwise the non-polylog block of largest order, then an unresolved block, then a nested root *)
  pick = Which[
    recs === {}, None,
    geomBad =!= None, geomBad,
    nonpoly =!= {}, Last[SortBy[nonpoly, #["size"] &]],
    True, Last[SortBy[recs, {blockRank[#["label"]], #["size"]} &]]];
  out = Which[
    st =!= "complete" && pick === None,
      <|"label" -> "unresolved (order " <> ToString[n] <> ")", "reason" -> "the search for first-order pieces has too many choices of exponents"|>,
    pick === None,
      <|"label" -> "polylog", "reason" -> "every piece is of first order: the solutions are rational functions and their roots (and logarithms of them)"|>,
    True, KeyTake[pick, {"label", "reason"}]];
  If[Length[recs] > 1, out["reason"] = out["reason"] <> "; blocks: " <> StringRiffle[(#["label"] <> " (order " <> ToString[#["size"]] <> ")") & /@ recs, ", "]];
  Join[out, <|"order" -> n, "factors" -> <|"firstOrder" -> first, "blocks" -> Lookup[recs, "size", {}]|>,
    "blocks" -> (KeyDrop[#, {"order"}] & /@ recs), "search" -> st,
    "operator" -> If[AssociationQ[pick], Lookup[pick, "operator", {}], {}], "block" -> If[AssociationQ[pick], Lookup[pick, "block", {1}], {1}],
    "local" -> If[AssociationQ[pick], Lookup[pick, "local", {}], {}], "logPower" -> If[AssociationQ[pick], Lookup[pick, "logPower", {0, 0}], {0, 0}],
    "pCurvature" -> If[AssociationQ[pick], Lookup[pick, "pCurvature", <||>], <||>],
    "symmetricSquare" -> If[AssociationQ[pick], Lookup[pick, "symmetricSquare", Missing["NotApplicable"]], Missing["NotApplicable"]]|>]];


(* the order of the operator of seed.J: the first k at which seed, its derivatives up to order k are dependent (random points) *)
krylovOrder[A_, seed_, t_] := Module[{v = Together /@ seed, vs, pts = randomPoints[2]},
  vs = {v};
  If[Max[MatrixRank[{v} /. t -> #] & /@ pts] == 0, Return[0]];
  Do[v = Together /@ (D[v, t] + v . A); AppendTo[vs, v];
    If[Max[MatrixRank[vs /. t -> #] & /@ pts] < Length[vs], Return[Length[vs] - 1, Module]], {Length[A]}];
  Length[A]];


(* ::Section:: *)
(*The step*)


MCBPFNonPolylogQ[l_String] := StringMatchQ[l, "elliptic" | ("genus-" ~~ DigitCharacter ..) | "K3" | ("CY_" ~~ DigitCharacter ..) | ("non-polylog (order " ~~ DigitCharacter .. ~~ ")")];
MCBPFNonPolylogQ[_] := False;
MCBPFPolylogQ[l_String] := StringStartsQ[l, "polylog"];
MCBPFPolylogQ[_] := False;

(* an irreducible polynomial of a point, primitive over Z with a positive leading coefficient *)
normPoly[p_, t_] := Module[{q = Expand[p], cs},
  cs = CoefficientList[q, t];
  q = Expand[q LCM @@ (Denominator /@ cs)];
  q = Expand[q/(GCD @@ CoefficientList[q, t])];
  If[Coefficient[q, t, Exponent[q, t]] < 0, -q, q]];

(* the branch points of y^2 = P(z) at a root of q (numerically): the roots of P and infinity, as a form of degree nb = 2g + 2;
   True when two of them, and not more, meet somewhere *)
nodeQ[P_, z_, q_, t_, nb_] := Module[{t1, cs, deg, rts, clusters, infm},
  t1 = First[t /. NSolve[q == 0, t, WorkingPrecision -> 60]];
  cs = CoefficientList[P, z];
  (* the degree at t1, exactly: drop leading coefficients that vanish on q *)
  deg = Length[cs] - 1;
  While[deg > 0 && PolynomialRemainder[cs[[deg + 1]], q, t] === 0, deg--];
  infm = nb - deg;
  rts = z /. NSolve[(Take[cs, deg + 1] /. t -> t1) . z^Range[0, deg] == 0, z, WorkingPrecision -> 60];
  clusters = Length /@ Gather[rts, Abs[#1 - #2] < 10^-12 (1 + Abs[#1]) &];
  MemberQ[Append[clusters, infm], 2]];

MCBPFBaikovCheck[cls_Association, cd_, line_Association, fam_Association] := Module[{t = \[FormalT], us = fam["UnitScale"], z, sub, P, n, g, cs, a, b, c, d, e,
    i4, j4, jr, curve, infCurve, logs, infLog, ok},
  If[! AssociationQ[cd], Return[<|"status" -> "not applicable", "message" -> "no Baikov representation of this cut is a curve in one variable"|>]];
  z = First[cd["vars"]];
  sub = Join[If[us === None, {}, {us -> 1}], Thread[line["variables"] -> line["p0"] + t line["v"]]];
  P = Numerator[Together[cd["split"]["Pr"] /. sub]];
  (* a factor of t alone rescales y and leaves the curve as it is *)
  P = Expand[Cancel[P/PolynomialGCD @@ CoefficientList[P, z]]];
  n = Exponent[P, z]; g = Ceiling[n/2] - 1;
  If[n < 3, Return[<|"status" -> "not applicable", "genus" -> 0, "message" -> "the Baikov polynomial has degree " <> ToString[n] <> " on the line"|>]];
  If[n <= 4,
    (* y^2 = a z^4 + b z^3 + c z^2 + d z + e (a = 0 for a cubic, a root at infinity): j = 1728 4 I^3/(4 I^3 - J^2) *)
    {a, b, c, d, e} = PadLeft[Reverse[CoefficientList[P, z]], 5];
    i4 = 12 a e - 3 b d + c^2; j4 = 72 a c e + 9 b c d - 27 a d^2 - 27 e b^2 - 2 c^3;
    jr = Together[i4^3/(4 i4^3 - j4^2)];
    curve = normPoly[#, t] & /@ Select[First /@ FactorList[Denominator[jr]], ! FreeQ[#, t] &];
    infCurve = Exponent[Numerator[jr], t] > Exponent[Denominator[jr], t],
    (* higher genus: the zeros of the discriminant where two branch points meet (a node, monodromy with a log); where three
       or more meet (a cusp) the monodromy has finite order *)
    curve = normPoly[#, t] & /@ Select[Select[First /@ FactorList[Discriminant[P, z]], ! FreeQ[#, t] &], nodeQ[P, z, #, t, 2 g + 2] &];
    infCurve = Missing["NotCompared"]];
  logs = normPoly[#["point"], t] & /@ Select[cls["local"], #["point"] =!= Infinity && Last[#["logPower"]] >= 1 &];
  infLog = AnyTrue[cls["local"], #["point"] === Infinity && Last[#["logPower"]] >= 1 &];
  ok = Sort[curve] === Sort[logs] && (MissingQ[infCurve] || infCurve === infLog);
  <|"status" -> If[ok, "agree", "disagree"], "genus" -> g, "curvePoints" -> curve, "logPoints" -> logs, "infinity" -> {infCurve, infLog},
    "representation" -> {cd["kind"], cd["order"], cd["isp"]},
    "message" -> If[ok, "the log points of the block are the points where the Baikov curve (genus " <> ToString[g] <> ") degenerates" <>
         If[g == 1, " (poles of j)", " (zeros of the discriminant)"],
       "the log points of the block (" <> ToString[Length[logs]] <> " finite) and the degenerations of the Baikov curve (" <> ToString[Length[curve]] <> " finite) differ"]|>];

(* the line DE at t = 0 from Kira's reduction at the first point: A_FF_X(xhat) = u^-(alpha_i - alpha_j - beta_X) A_Kira_X(x) *)
(* the recount's rules reduce a fixed pool; when the derivatives leave it, one Kira run on the cut reduces exactly them *)
kiraCheck[fam_, s_, masters_, rules0_, pt_, line_, dir_] := Module[{dv = line["variables"], n = Length[masters], derivs, vals, left, rules = rules0,
    ax, u, pred, bad = {}, total = 0, al = line["alpha"], be = line["beta"], kr, extra = False},
  If[! ListQ[pt], Return[<|"status" -> "not compared", "message" -> "no first point"|>]];
  (* at the point, as the gate does ($MCBPointDerivatives): much cheaper with many invariants *)
  derivs = Table[DropOffCut[s][If[TrueQ[$MCBPointDerivatives], MCBDerivExprAt[fam, m, X, pt], MCBDerivExpr[fam, m, X] /. pt]], {X, dv}, {m, masters}];
  left = If[rules === None, JIntegrals[derivs], Complement[JIntegrals[Collect[derivs /. rules, _j, Together]], masters]];
  If[left =!= {},
    kr = TimeConstrained[MCBKiraCutReduce[fam, s, JIntegrals[derivs], FileNameJoin[{dir, "kira-check"}], pt], 120, {None, $Failed}];
    If[kr[[2]] === $Failed || Sort[kr[[2]]] =!= Sort[masters],
      Return[<|"status" -> "not compared", "message" -> "Kira could not reduce the derivatives of the masters at the first point" <>
         If[ListQ[kr[[2]]], " onto the same masters (" <> ToString[kr[[2]], InputForm] <> ")", ""]|>, Module]];
    rules = kr[[1]]; extra = True];
  vals = Collect[derivs /. rules, _j, Together];
  left = Complement[JIntegrals[vals], masters];
  If[left =!= {}, Return[<|"status" -> "not compared", "message" -> "Kira left integrals unreduced, e.g. " <> ToString[First[left], InputForm]|>]];
  ax = Table[Together[Coefficient[vals[[x, i]], masters[[jj]]]], {x, Length[dv]}, {i, n}, {jj, n}];
  u = If[line["unitScale"] === None, 1, line["unitScale"] /. pt];
  pred = Sum[line["v"][[x]] Table[u^(-(al[[i]] - al[[jj]] - be[dv[[x]]])) ax[[x, i, jj]], {i, n}, {jj, n}], {x, Length[dv]}];
  Do[With[{ff = line["A"][[k - line["kmin"] + 1]] /. \[FormalT] -> 0},
      Do[total++; If[Together[SeriesCoefficient[pred[[i, jj]], {eps, 0, k}] - ff[[i, jj]]] =!= 0, AppendTo[bad, {k, i, jj}]], {i, n}, {jj, n}]],
    {k, line["kmin"], line["order"]}];
  If[bad === {}, <|"status" -> "agree", "message" -> "the line DE at t = 0 agrees with Kira at the first point (" <> ToString[total] <> " eps coefficients" <>
       If[extra, "; one Kira run for the derivatives", "; the recount's reduction"] <> ")"|>,
    <|"status" -> "disagree", "message" -> ToString[Length[bad]] <> " of " <> ToString[total] <> " eps coefficients differ from Kira at the first point, the first eps^" <>
       ToString[bad[[1, 1]]] <> " A[[" <> ToString[bad[[1, 2]]] <> ", " <> ToString[bad[[1, 3]]] <> "]]"|>]];

MCBPicardFuchs[fam_Association, s_List, opts_Association : <||>] := Module[{t0 = AbsoluteTime[], tl = Lookup[opts, "TimeLimit", $MCBPFTimeLimit], dir, res},
  dir = Lookup[opts, "Dir", FileNameJoin[{$TemporaryDirectory, "mcb-picard-fuchs-" <> SectorName[s] <> "-" <> ToString[$ProcessID]}]];
  res = Which[
    MCBSkippedQ["picard-fuchs"], <|"label" -> "skipped by user", "reason" -> "picard-fuchs is in run.wl \"Skip\""|>,
    True, TimeConstrained[pfStep[fam, s, dir, opts], tl,
      <|"label" -> "not computed", "reason" -> "the step ran out of its time limit of " <> ToString[tl] <> " s (run.wl \"TimeLimits\" -> \"PicardFuchs\")"|>]];
  (* Katz's p-curvature criteria, cited when they labelled the sector: a step that ends "not computed" (a time limit
     after the classification, say) labelled nothing *)
  If[! MemberQ[{"not computed", "not applicable", "skipped by user"}, res["label"]] && ListQ[Lookup[res, "blocks", None]] && res["blocks"] =!= {},
    MCBMarkToolUsed["PicardFuchs"]];
  If[DirectoryQ[dir] && ! TrueQ[$MCBKeepScratch], Quiet[DeleteDirectory[dir, DeleteContents -> True]]];
  Join[res, <|"time" -> Round[AbsoluteTime[] - t0]|>]];

pfStep[fam_, s_, dir_, opts_] := Module[{t = \[FormalT], dv, pts, masters, rules, n, K = 0, tries = 0, line, A, reg, crow, cg, v, cop, dirv,
    reps, cd, genus, cls, bc, kc, lab, reason, tm = <||>, clock = AbsoluteTime[], lap},
  lap[k_] := (tm[k] = Round[AbsoluteTime[] - clock, 0.1]; clock = AbsoluteTime[]);
  If[! AllTrue[{"FiniteFlow", "LiteRed", "LiteIBP"}, MCBAvailableQ], Return[<|"label" -> "not computed", "reason" -> "the step needs FiniteFlow, LiteRed and LiteIBP (bin/preflight.wls)"|>]];
  dv = DeleteCases[fam["InvList"], fam["UnitScale"]];
  If[dv === {}, Return[<|"label" -> "not applicable", "reason" -> "the family depends on one scale only: its DE is fixed by the mass dimension"|>]];
  pts = Lookup[opts, "Points", MCBPoints[fam, 2, Lookup[opts, "Seed", 1]]];
  masters = Lookup[opts, "Masters", Automatic]; rules = Lookup[opts, "KiraRules", None];
  If[masters === Automatic,
    With[{cm = MCBCutMasters[fam, s, FileNameJoin[{dir, "count"}], First[pts]]}, masters = cm["masters"]; rules = Lookup[cm, "rules", None]]];
  If[! ListQ[masters] || masters === {}, Return[<|"label" -> "not computed", "reason" -> "no masters on the maximal cut (the Kira recount failed or found none)"|>]];
  n = Length[masters]; lap["recount"];
  (* the line starts at the first point of the Kira check (t = 0 is compared with Kira) and runs in a random direction
     of small integers: a line through a second random point has coefficients hundreds of digits long *)
  dirv = BlockRandom[RandomChoice[{-3, -2, -1, 1, 2, 3}, Length[dv]], RandomSeeding -> 7 + Lookup[opts, "Seed", 1]];
  (* the DE on the line, in a frame regular at eps = 0; more orders of eps when that frame needs them *)
  While[True,
    line = MCBFFLineDE[fam, s, masters, FileNameJoin[{dir, "line"}], <|"p0" -> pts[[1]], "v" -> dirv|>, <|"Order" -> K, "Variable" -> t, "Reuse" -> tries > 0,
       "Verbose" -> TrueQ[Lookup[opts, "Verbose", False]]|>];
    If[line["status"] =!= "ok", Return[<|"label" -> Replace[line["status"], "failed" -> "not computed"], "reason" -> "FiniteFlow along the line: " <> line["message"]|>, Module]];
    A = MCBPFLaurentMatrix[line["A"], line["kmin"], eps];
    reg = MCBPFRegularise[A, t, eps];
    (* eps^0 suffices when the masters' DE is regular there; a frame that needs more orders asks for them *)
    If[reg["status"] === "needOrder" && tries < 3 && reg["order"] <= 12, K = Max[K + 1, reg["order"]]; tries++; Continue[]];
    Break[]];
  lap["line"];
  kc = kiraCheck[fam, s, masters, rules, pts[[1]], line, dir];
  lap["kiraCheck"];
  If[reg["status"] =!= "regular",
    Return[<|"label" -> "unresolved (order " <> ToString[n] <> ")", "reason" -> "no frame regular at eps = 0 (" <> reg["message"] <> "): at eps = 0 the operator would see only part of the sector",
      "order" -> n, "orderDrop" -> Missing["RegularisationFailed"], "masters" -> masters, "kiraCheck" -> kc,
      "line" -> <|"points" -> pts, "variables" -> dv, "p0" -> line["p0"], "v" -> line["v"]|>|>, Module]];
  (* the corner integral in the regular frame: its row times the gauge, lowest power of eps; only the order of its operator
     is needed (the papers quote it) *)
  crow = Table[Sum[line["corner"][[k - line["kmin"] + 1, i]] eps^k, {k, line["kmin"], line["order"]}] + O[eps]^(line["order"] + 1), {i, n}];
  cg = crow . reg["gauge"];
  v = Min[sdVal /@ cg];
  cop = If[v === Infinity, 0, Quiet@TimeConstrained[krylovOrder[reg["A0"], sdCoef[#, v] & /@ cg, t], 60, Missing["TimedOut"]]];
  (* the Baikov curve on the same line: its genus enters the genus-g row, its degenerations the check *)
  reps = Lookup[opts, "Representations", Automatic];
  If[reps === Automatic, reps = Quiet@Check[MCBRepresentations[fam, s, <|"TimeLimit" -> 120|>], {}]];
  cd = SelectFirst[reps, #["geometry"]["class"] === "curve" && Length[#["vars"]] == 1 &, None];
  genus = If[AssociationQ[cd], Quiet@Check[MCBCurve[cd]["genus"], None], None];
  cls = MCBPFClassifyConnection[reg["A0"], t, "BaikovGenus" -> genus];
  bc = Which[
    MCBPFNonPolylogQ[cls["label"]] && StringMatchQ[cls["label"], "elliptic" | ("genus-" ~~ __)], MCBPFBaikovCheck[cls, cd, line, fam],
    AssociationQ[cd] && MCBPFPolylogQ[cls["label"]],
      <|"status" -> "mismatch", "genus" -> genus, "message" -> "the operator is polylogarithmic, but the Baikov representation " <> ToString[{cd["kind"], cd["order"], cd["isp"]}] <>
         " shows a curve of genus " <> ToString[genus] <> ": no master sees its periods, and the operator decides"|>,
    True, <|"status" -> "not applicable"|>];
  lap["analysis"];
  {lab, reason} = {cls["label"], cls["reason"]};
  If[kc["status"] === "disagree",
    {lab, reason} = {"unresolved (order " <> ToString[cls["order"]] <> ")", "the line DE disagrees with Kira at the first point (" <> kc["message"] <> "); the label would have been " <> cls["label"]}];
  Join[KeyDrop[cls, {"label", "reason"}], <|"label" -> lab, "reason" -> reason, "cornerOrder" -> cop, "masters" -> masters,
    "line" -> <|"points" -> pts, "variables" -> dv, "p0" -> line["p0"], "v" -> line["v"]|>, "epsOrders" -> {line["kmin"], line["order"]},
    "regularisation" -> reg["method"], "orderDrop" -> 0, "baikovGenus" -> genus, "baikovCheck" -> bc, "kiraCheck" -> kc, "timing" -> tm|>]];


End[];
EndPackage[];
