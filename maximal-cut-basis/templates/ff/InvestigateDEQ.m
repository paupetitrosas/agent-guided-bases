(* ::Package:: *)

(* FiniteFlow check of {{FAMILY}} {{SECTORNAME}}, step 3 of 3: read sys.m, write DE.m (per-invariant A
   matrices of J_i = Sqrt[prefacts_i] ut_i) and verdict.m (eps-form / eps-polynomial / rational), compare the
   matrices with Kira's at Kira's first point, refresh the sector's basis.m and basis.html, and credit FiniteFlow,
   LiteRed and LiteIBP in the run's citations.m when the DE was reconstructed.
   Written by MaximalCutBasis. *)

Get["{{LIBFILE}}"];
sectorDir = ParentDirectory[Directory[]];
info = Get["ffinfo.m"];
sysinfo = If[FileExistsQ["sysinfo.m"], Get["sysinfo.m"], <|"status" -> "failed", "message" -> "SetSDE.m did not finish"|>];

(* the credits first, so that the page shows them *)
refresh[v_] := Module[{rec = MCBReadBasis[sectorDir]},
  MCBRecordFFCheck[sectorDir, v];
  If[KeyExistsQ[rec, "sector"], rec["finiteflowVerdict"] = v; MCBWriteBasis[sectorDir, rec]; Quiet@MCBBasisHTML[sectorDir]]];

If[sysinfo["status"] =!= "ok",
  verdict = <|"status" -> If[sysinfo["status"] === "not applicable", "not applicable", "failed"], "message" -> Lookup[sysinfo, "message", "?"],
    "mode" -> Lookup[sysinfo, "mode", "?"]|>;
  Export["verdict.m", verdict]; refresh[verdict];
  Print["verdict: ", verdict["status"], " (", Lookup[sysinfo, "message", "?"], ")"]; Quit[]];

deqe = Get["sys.m"];
prefacts = Get["prefacts.m"];
invariants = sysinfo["invariants"];
n = Length[prefacts];

(* lowest and highest power of eps in every entry *)
profile = Map[MCBEpsProfile, deqe, {3}];
ef = MCBEpsFactorizedQ[deqe];
poly = MCBEpsPolynomialQ[deqe];
kv = If[ef[[1]], ef[[2]], ConstantArray[0, n]];

(* the DE of J = Sqrt[prefacts] ut, eps^k rescaled *)
conj = Table[Sqrt[prefacts[[i]]]/Sqrt[prefacts[[jj]]], {i, n}, {jj, n}];
Export["DE.m", AssociationThread[invariants -> Table[conj MCBRescaleEps[deqe[[x]], kv], {x, Length[invariants]}]]];

(* Kira's matrices are in the same rational frame and describe the same masters.m, so they must agree exactly:
   A_Kira_ij(u, x) = u^(alpha_i - alpha_j - beta_X) (phase_i/phase_j) A_FF_ij(x/u^beta)   (u = UnitScale) *)
compareWithKira[] := Module[{rec = MCBReadBasis[sectorDir], kvK, AK, pt, defs, us = info["unitScale"], u, xhat, bad = {}, total = 0, pred},
  kvK = Lookup[rec, "kiraVerdict", <||>];
  AK = Lookup[kvK, "A", None];
  If[! AssociationQ[AK], Return[<|"status" -> "not compared", "message" -> "basis.m has no Kira matrices; rerun the Kira check (bin/check_basis.wls)"|>]];
  defs = Lookup[#, "definition", None] & /@ Lookup[rec, "masters", {}];
  If[Length[defs] != Length[info["masters"]] || ! AllTrue[MapThread[MCBEqualAtPointsQ, {defs, info["masters"]}], TrueQ],
    Return[<|"status" -> "not compared", "message" -> "basis.m describes a different basis than this FiniteFlow check"|>]];
  If[sysinfo["mode"] =!= "full" && ! TrueQ[info["sliceFromKiraPoint"]],
    Return[<|"status" -> "not compared", "message" -> "the eps-only slice is not at Kira's point"|>]];
  If[us =!= None && ! AllTrue[info["alpha"], NumericQ],
    Return[<|"status" -> "not compared", "message" -> "the basis elements are not homogeneous in the unit scale"|>]];
  pt = First[rec["points"]];
  u = If[us === None, 1, us /. pt];
  xhat = Table[X -> If[us === None, X /. pt, (X /. pt)/u^info["beta"][X]], {X, invariants}];
  Do[
    If[! KeyExistsQ[AK, invariants[[x]]], Continue[]];
    (* no eps^k here: masters.m, which FiniteFlow reduced, already carries the powers the Kira check asked for, and
       basis.m stores Kira's matrices for exactly those expressions *)
    pred = Table[If[us === None, 1, u^(info["alpha"][[i]] - info["alpha"][[jj]] - info["beta"][invariants[[x]]])] (info["phases"][[i]]/info["phases"][[jj]]) *
        (deqe[[x, i, jj]] /. xhat), {i, n}, {jj, n}];
    Do[total++; If[! PossibleZeroQ[Together[AK[invariants[[x]]][[i, jj]] - pred[[i, jj]]]], AppendTo[bad, {invariants[[x]], i, jj}]], {i, n}, {jj, n}],
    {x, Length[invariants]}];
  If[bad === {},
    <|"status" -> "agree", "message" -> "all " <> ToString[total] <> " entries of A_X, X in " <> ToString[invariants] <> ", agree at " <> ToString[pt, InputForm] <>
        If[us === None, "", " (" <> ToString[us] <> " is set to 1 in FiniteFlow, so its derivative is only checked by Kira)"]|>,
    <|"status" -> "disagree", "message" -> ToString[Length[bad]] <> " of " <> ToString[total] <> " entries differ, the first in A_" <>
        ToString[bad[[1, 1]]] <> "[[" <> ToString[bad[[1, 2]]] <> ", " <> ToString[bad[[1, 3]]] <> "]]", "entries" -> bad|>]];

cmp = Quiet@Check[compareWithKira[], <|"status" -> "not compared", "message" -> "the comparison failed"|>];

verdict = <|
  "status" -> Which[ef[[1]], "eps-form", poly[[1]], "eps-polynomial", True, "rational"],
  "k" -> kv, "range" -> If[ef[[1]], {1, 1}, poly[[2]]], "profile" -> profile, "mode" -> sysinfo["mode"],
  "invariants" -> invariants, "slicePoint" -> sysinfo["slicePoint"], "kiraComparison" -> cmp,
  "message" -> StringJoin[
    Which[ef[[1]], "eps-factorised" <> If[AllTrue[kv, # == 0 &], "", " after J_i -> eps^k_i J_i, k = " <> ToString[kv]],
      poly[[1]], "Laurent polynomial in eps, powers " <> ToString[poly[[2]]], True, "rational eps dependence"],
    If[sysinfo["mode"] === "full", " (analytic in " <> ToString[invariants] <> ", UnitScale = 1)",
      " (eps-only slice at " <> ToString[sysinfo["slicePoint"], InputForm] <> ")"]]|>;
Export["verdict.m", verdict];
refresh[verdict];
Print["verdict: ", verdict["status"], "  ", verdict["message"]];
Print["compared with Kira: ", cmp["status"], "  ", cmp["message"]];
Quit[];
