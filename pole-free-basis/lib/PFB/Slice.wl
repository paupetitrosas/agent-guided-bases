(* ::Package:: *)

(* ::Title:: *)
(*PoleFreeBasis`Slice`: numerical slices of the differential equation*)


(* ::Text:: *)
(*A slice is the DE at one rational kinematic point, exact in eps. Internally it is always kept in the root-free*)
(*frame: R_k[r, c] is the coefficient of the root-free master U_c in (1/pref_r) d_k (pref_r U_r), so R is rational and*)
(*its diagonal contains dlog(pref_r). External slices are converted with the conventions file (conventions.wl).*)


BeginPackage["PoleFreeBasis`Slice`", {"MaximalCutBasis`Rules`", "PoleFreeBasis`", "PoleFreeBasis`Config`", "PoleFreeBasis`System`", "MaximalCutBasis`"}];

PFBReadConventions::usage = "PFBReadConventions[file] reads conventions.wl (see reference/formats.md) and fills the defaults.";
PFBImportSlice::usage = "PFBImportSlice[sys, conv] reads an external slice and converts it to the root-free frame. Returns the slice object <|\"R\", \"Derivatives\", \"Point\", \"Labels\", \"Index\", \"Frame\", \"Source\", \"History\"|>.";
PFBSaveSlice::usage = "PFBSaveSlice[sl, file] saves a slice (MX).";
PFBLoadSlice::usage = "PFBLoadSlice[file] loads a slice saved by PFBSaveSlice.";
PFBSliceSize::usage = "PFBSliceSize[sl] is the number of masters of the slice.";
PFBRootRatio::usage = "PFBRootRatio[sys, conv, r, c] is the factor e_rc / R_rc of the conventions' frame for rows/columns with labels r, c.";
PFBSliceFromRed::usage = "PFBSliceFromRed[sys, red] builds a slice from a reduction of the whole system (every master in the focus).";
PFBCalibrate::usage = "PFBCalibrate[sl, red] compares the rows of the focus masters of a reduction with the slice. Returns <|\"Status\" -> \"exact\" | \"mismatch\" | \"undetermined\" | \"inconsistent\", \"Checked\", \"Mismatch\", \"NonUT\", \"Mx\", \"Missing\", \"Message\"|>; Mx expands the non-ut masters of the reduction on the slice columns.";
PFBToSliceVector::usage = "PFBToSliceVector[sl, red, cal, v] maps a vector in the reduction's master coordinates to slice columns.";
PFBExprVector::usage = "PFBExprVector[sys, sl, red, cal, expr] is the vector of a root-free expression (integrals of the reduction pool and ut[k] terms) on the slice columns at the slice point.";
PFBExprDVector::usage = "PFBExprDVector[sys, sl, red, cal, expr, k, pref] is the slice row of the master pref*expr: (1/pref) d_k (pref expr) on the slice columns.";
PFBPointRules::usage = "PFBPointRules[sl] are the rules invariant -> value of the slice point.";
PFBDigitHeight::usage = "PFBDigitHeight[expr] is the digit height of an entry of a slice or of a reduction (a rational function of eps with rational coefficients, at one kinematic point): the entry written as one fraction N/D in eps (Together), the sum over the coefficients of every power of eps in N and in D of the decimal digits of their numerators and denominators (IntegerLength; a zero coefficient counts 0); for a list, the sum over its entries. The sum, not the largest: every entry and every power of eps counts, so rows lighter in one entry and equal elsewhere come out lower, and zero entries cost nothing. At a generic rational point the digits grow with the kinematic degree, so it is a free proxy for it: the last tie-break of the scans (PFBScanSets) and of the completion solver (PFBCompletionSolve), and the ranking of the swaps of the simplification phase (PFBSwapCandidates).";
PFBRowsDigitHeight::usage = "PFBRowsDigitHeight[sl, labels] is the digit height (PFBDigitHeight) of the rows of the masters labels in the slice sl: every derivative, every column.";

Begin["`Private`"];


(* ::Section:: *)
(*Conventions*)


$convDefaults = <|"File" -> None, "Derivatives" -> Automatic, "Point" -> None, "Labels" -> All, "Frame" -> "RootFree",
   "RootValues" -> {}, "RootOrder" -> Automatic, "Transpose" -> False, "Rules" -> {}|>;

PFBReadConventions[file_String] := Module[{f = ExpandFileName[file], raw, c},
  If[! FileExistsQ[f], Print["PFBReadConventions: ", f, " not found."]; Return[$Failed]];
  raw = Get[f];
  If[! AssociationQ[raw], Print["PFBReadConventions: ", f, " does not evaluate to an Association."]; Return[$Failed]];
  c = Join[$convDefaults, raw, <|"ConventionsFile" -> f, "Dir" -> DirectoryName[f]|>];
  If[StringQ[c["File"]] && ! StringStartsQ[c["File"], "/"], c["File"] = FileNameJoin[{c["Dir"], c["File"]}]];
  If[StringQ[c["Labels"]], c["Labels"] = Get[If[StringStartsQ[c["Labels"], "/"], c["Labels"], FileNameJoin[{c["Dir"], c["Labels"]}]]]];
  If[StringQ[c["RootValues"]], c["RootValues"] = Get[If[StringStartsQ[c["RootValues"], "/"], c["RootValues"], FileNameJoin[{c["Dir"], c["RootValues"]}]]]];
  If[AssociationQ[c["Point"]], c["Point"] = Normal[c["Point"]]];
  c];

labelsOf[sys_, All] := Range[Length[PFBMasters[sys]]];
labelsOf[sys_, l_List] := l /. ut[k_] :> k;

PFBPointRules[sl_Association] := sl["Point"];


(* ::Section:: *)
(*Root ratio of a frame*)


(* "RootSymbols": the producer treated each square root as an independent variable with the value RootValues;
   the entry of rows r, columns c is R_rc pref_r^2 / (mono_r mono_c) with pref_r^2 evaluated at the point and the
   root monomials at RootValues. Each Sqrt[...] factor of a prefactor is matched to the first root symbol of
   RootOrder whose radicand agrees. *)
monoOf[sys_, conv_, pref_] := Module[{defs = Replace[conv["RootOrder"], Automatic :> PFBRootDefs[sys]], rad},
  rad = Association[Table[Expand[d[[2, 1]]] -> d[[1]], {d, Reverse[defs]}]];
  pref /. Sqrt[a_] :> Module[{sq = sqFree2[a]}, sq[[1]] Lookup[rad, Expand[sq[[2]]], Missing["root", sq[[2]]]]]];

sqFree2[a_] := Module[{fl = FactorList[Factor[a]], out = 1, in = 1},
  Do[out *= f[[1]]^Quotient[f[[2]], 2]; in *= f[[1]]^Mod[f[[2]], 2], {f, fl}];
  {out, Expand[in]}];

PFBRootRatio[sys_Association, conv_Association, r_Integer, c_Integer] := Module[{pt = conv["Point"], pr, pc},
  Switch[conv["Frame"],
    "RootFree", 1,
    "RootSymbols",
      pr = PFBMaster[sys, r]["Pref"]; pc = PFBMaster[sys, c]["Pref"];
      If[pr === 1 && pc === 1, 1,
        Together[(pr^2 /. pt)/((monoOf[sys, conv, pr] monoOf[sys, conv, pc]) /. conv["RootValues"])]],
    "Rational",
      (* full masters whose prefactors are rational at the point: A_rc = R_rc pref_r/pref_c *)
      Together[(PFBMaster[sys, r]["Pref"]/PFBMaster[sys, c]["Pref"]) /. pt],
    _, $Failed]];


(* ::Section:: *)
(*Import*)


PFBImportSlice[sys_Association, conv_Association] := Module[{raw, labs, n, ders, R, ratio, t0 = AbsoluteTime[], cache = <||>, key},
  If[! StringQ[conv["File"]] || ! FileExistsQ[conv["File"]], Print["PFBImportSlice: slice file not found: ", conv["File"]]; Return[$Failed]];
  If[! MatchQ[conv["Point"], {(_ -> _?NumericQ) ..}], Print["PFBImportSlice: \"Point\" must list every invariant with its rational value."]; Return[$Failed]];
  raw = If[StringEndsQ[conv["File"], ".mx"], Import[conv["File"]], Get[conv["File"]]];
  raw = raw /. conv["Rules"];
  If[TrueQ[conv["Transpose"]], raw = Transpose /@ raw];
  labs = labelsOf[sys, conv["Labels"]];
  n = Length[labs];
  ders = Replace[conv["Derivatives"], Automatic :> Take[sys["Invariants"], Length[raw]]];
  If[! ArrayQ[raw, 3] || Dimensions[raw] =!= {Length[ders], n, n},
    Print["PFBImportSlice: the slice has dimensions ", Dimensions[raw], "; expected ", {Length[ders], n, n}, " (derivatives x labels x labels)."]; Return[$Failed]];
  (* the ratio depends only on the pair of prefactors: cache by pair *)
  ratio[r_, c_] := (key = {PFBMaster[sys, labs[[r]]]["Pref"], PFBMaster[sys, labs[[c]]]["Pref"]};
     If[KeyExistsQ[cache, key], cache[key], cache[key] = PFBRootRatio[sys, conv, labs[[r]], labs[[c]]]]);
  R = Table[If[raw[[k, r, c]] === 0, 0, Together[raw[[k, r, c]]/ratio[r, c]]], {k, Length[ders]}, {r, n}, {c, n}];
  If[! FreeQ[R, Missing], Print["PFBImportSlice: some square roots of the prefactors match no root in \"RootOrder\"; check the conventions."]; Return[$Failed]];
  PFBPrint["slice ", FileNameTake[conv["File"]], ": ", Length[ders], " x ", n, " x ", n, ", frame ", conv["Frame"], ", converted in ", Round[AbsoluteTime[] - t0], " s"];
  <|"R" -> R, "Derivatives" -> ders, "Point" -> conv["Point"], "Labels" -> labs, "Index" -> AssociationThread[labs -> Range[n]],
    "Frame" -> "RootFree", "Source" -> conv["File"], "Conventions" -> conv, "History" -> {}|>];

PFBSaveSlice[sl_Association, file_String] := (Export[file, sl, "MX"]; file);
PFBLoadSlice[file_String] := Import[file];

PFBSliceSize[sl_Association] := Length[sl["Labels"]];

PFBSliceFromRed[sys_Association, red_Association] := Module[{mast = red["Masters"], labs, idx, rows},
  If[! AllTrue[mast, MatchQ[#, _ut] &], Print["PFBSliceFromRed: the reduction has non-ut masters ", Select[mast, ! MatchQ[#, _ut] &]]; Return[$Failed]];
  labs = mast /. ut[k_] :> k;
  (* the surviving masters are the slice: each needs its row; focus masters that reduce to others are dropped *)
  If[! SubsetQ[red["Focus"], labs], Print["PFBSliceFromRed: masters without a row (not in the focus): ", ut /@ Complement[labs, red["Focus"]]]; Return[$Failed]];
  idx = AssociationThread[labs -> Range[Length[labs]]];
  rows = Table[Position[red["Focus"], l][[1, 1]], {l, labs}];
  <|"R" -> Table[red["Dm"][[k, rows]], {k, Length[red["Invariants"]]}], "Derivatives" -> red["Invariants"], "Point" -> red["Point"],
    "Labels" -> labs, "Index" -> idx, "Frame" -> "RootFree", "Source" -> "local reduction", "History" -> {}|>];


(* ::Section:: *)
(*Calibration*)


(* the slice and a local reduction must agree exactly on every focus row. Non-ut masters of the reduction (allowed when
   the subtree could not be closed) get their expansion on the slice columns from the same rows; the rows that fix them
   are then not an independent check, which the result reports. *)
PFBCalibrate[sl_Association, red_Association] := Module[{mast = red["Masters"], upos, npos, ucols, miss, nM = PFBSliceSize[sl], eqs = {}, unk, Mx, undet = {},
    checked = {}, mism = {}, focus = red["Focus"], Dm = red["Dm"], kmap, status = "exact", msg = ""},
  If[red["Point"] =!= sl["Point"] && Sort[red["Point"]] =!= Sort[sl["Point"]],
    Return[<|"Status" -> "inconsistent", "Message" -> "the reduction is not at the slice point"|>]];
  kmap = Flatten[Position[sl["Derivatives"], #] & /@ red["Invariants"]];
  If[Length[kmap] =!= Length[red["Invariants"]], Return[<|"Status" -> "inconsistent", "Message" -> "the reduction differentiates invariants the slice lacks"|>]];
  (* masters of the reduction that are not columns of the slice (non-ut integrals, or system masters the slice
     eliminated, e.g. duplicates of masters of another family) get their expansion on the slice from the focus rows *)
  upos = Flatten[Position[mast, ut[k_] /; KeyExistsQ[sl["Index"], k]]]; npos = Complement[Range[Length[mast]], upos];
  miss = Cases[mast[[npos]], ut[k_] :> k];
  ucols = sl["Index"] /@ (mast[[upos]] /. ut[k_] :> k);
  unk = Table[PoleFreeBasis`Slice`Private`mx[a, c], {a, Length[npos]}, {c, nM}];
  Do[With[{r = Lookup[sl["Index"], focus[[q]], None], row = Dm[[kk, q]]},
     If[r =!= None, Module[{w = ConstantArray[0, nM]}, w[[ucols]] = row[[upos]];
       AppendTo[eqs, {focus[[q]], kk, Together[sl["R"][[kmap[[kk]], r]] - w], row[[npos]]}]]]], {kk, Length[red["Invariants"]]}, {q, Length[focus]}];
  Mx = ConstantArray[0, {Length[npos], nM}];
  If[npos === {},
    Do[If[AllTrue[e[[3]], # === 0 &], AppendTo[checked, e[[1 ;; 2]]], AppendTo[mism, {e[[1]], e[[2]], sl["Labels"][[Flatten[Position[e[[3]], x_ /; x =!= 0, {1}, Heads -> False]]]]}]], {e, eqs}],
    Do[Module[{ee = Table[e[[3, c]] - e[[4]].unk[[All, c]], {e, eqs}], sol, used},
       If[AllTrue[ee, # === 0 &], Continue[]];
       sol = Quiet@Solve[Thread[ee == 0], unk[[All, c]]];
       If[sol === {}, AppendTo[mism, {"column", sl["Labels"][[c]]}]; Continue[]];
       (* an expansion left free by the rows is not determined: the calibration cannot be exact *)
       used = Select[unk[[All, c]], ! FreeQ[ee, #] &];
       If[! SubsetQ[First[sol][[All, 1]], used] || ! FreeQ[used /. First[sol], PoleFreeBasis`Slice`Private`mx], AppendTo[undet, sl["Labels"][[c]]]];
       Mx[[All, c]] = unk[[All, c]] /. First[sol] /. PoleFreeBasis`Slice`Private`mx[__] -> 0], {c, nM}];
    checked = eqs[[All, 1 ;; 2]]];
  If[mism =!= {}, status = "mismatch"; msg = "rows or columns where the reduction and the slice disagree: " <> ToString[Short[mism, 3]]];
  If[undet =!= {} && status === "exact", status = "undetermined";
    msg = "the expansion of " <> ToString[mast[[npos]]] <> " on the slice is not fixed by the focus rows (columns " <> ToString[Take[undet, UpTo[10]]] <>
      "): add the sectors whose masters they duplicate as roots, or more focus rows"];
  (* the reduction has focus rows and none of them is a row of the slice: nothing was compared, which is no agreement.
     (A reduction without focus rows has nothing to compare: the slice's own, of a simplification move.) *)
  If[focus =!= {} && eqs === {} && status === "exact", status = "undetermined"; msg = "no focus row of the reduction is a row of the slice: nothing was compared"];
  If[npos =!= {} && status === "exact", msg = ToString[mast[[npos]]] <> " (not columns of the slice) were expanded on the slice from the focus rows; those rows are fitted as well as checked"];
  <|"Status" -> status, "Checked" -> checked, "Mismatch" -> mism, "NonUT" -> mast[[npos]], "AbsentFromSlice" -> miss, "Undetermined" -> undet, "Mx" -> Mx, "Upos" -> upos, "Npos" -> npos, "Ucols" -> ucols,
    "KMap" -> kmap, "Message" -> msg|>];

PFBToSliceVector[sl_Association, red_Association, cal_Association, v_List] := Module[{w = ConstantArray[0, PFBSliceSize[sl]]},
  w[[cal["Ucols"]]] = v[[cal["Upos"]]];
  Together[w + If[cal["Npos"] === {}, 0, v[[cal["Npos"]]].cal["Mx"]]]];


(* ::Section:: *)
(*Vectors of expressions*)


jPart[ex_] := Expand[ex] /. ut[_] -> 0;
utTerms[ex_] := Module[{e = Collect[Expand[ex], _ut]}, Table[{u, Coefficient[e, u]}, {u, Union[Cases[{e}, _ut, Infinity]]}]];

poolIndex[red_] := AssociationThread[red["Pool"] -> Range[Length[red["Pool"]]]];

poolVec[sl_, red_, cal_, ex_, k_] := Module[{e = Collect[jPart[ex], _j], jl, idx = poolIndex[red], rules = sl["Point"], inv = red["Invariants"]},
  jl = Union[Cases[{e}, _j, Infinity]];
  If[jl === {}, Return[ConstantArray[0, PFBSliceSize[sl]]]];
  If[! SubsetQ[red["Pool"], jl], Print["PFBExprVector: integrals outside the reduction pool: ", Short[Complement[jl, red["Pool"]], 3]]; Return[$Failed]];
  PFBToSliceVector[sl, red, cal, Together[If[k === 0,
     Sum[(Coefficient[e, jj] /. rules) red["Rp"][[idx[jj]]], {jj, jl}],
     Sum[(D[Coefficient[e, jj], inv[[k]]] /. rules) red["Rp"][[idx[jj]]] + (Coefficient[e, jj] /. rules) red["dRp"][[k, idx[jj]]], {jj, jl}]]]]];

PFBExprVector[sys_Association, sl_Association, red_Association, cal_Association, ex_] := Module[{w = poolVec[sl, red, cal, ex, 0]},
  If[w === $Failed, Return[$Failed]];
  Do[w[[sl["Index"][u[[1, 1]]]]] += (u[[2]] /. sl["Point"]), {u, utTerms[ex]}];
  Together[w]];

(* row of the new master pref*ex in the root-free frame: d ex + dlog(pref) ex; a ut[c] term contributes its own row
   minus its own dlog (R rows already contain dlog(pref_c)) *)
PFBExprDVector[sys_Association, sl_Association, red_Association, cal_Association, ex_, k_Integer, pref_] := Module[{x = red["Invariants"][[k]], ks, w, h, dl},
  ks = First[Flatten[Position[sl["Derivatives"], x]]];
  w = poolVec[sl, red, cal, ex, k];
  If[w === $Failed, Return[$Failed]];
  dl[p_] := Together[D[p^2, x]/(2 p^2)] /. sl["Point"];
  h = PFBExprVector[sys, sl, red, cal, ex];
  w = w + dl[pref] h;
  Do[With[{c = u[[1, 1]], co = u[[2]]},
     w += (D[co, x] /. sl["Point"]) UnitVector[PFBSliceSize[sl], sl["Index"][c]] +
       (co /. sl["Point"]) (sl["R"][[ks, sl["Index"][c]]] - dl[PFBMaster[sys, c]["Pref"]] UnitVector[PFBSliceSize[sl], sl["Index"][c]])], {u, utTerms[ex]}];
  Together[w]];


(* ::Section:: *)
(*Digit height*)


digitsOf[q_] := Which[q === 0, 0, MatchQ[q, _Integer | _Rational], IntegerLength[Numerator[q]] + IntegerLength[Denominator[q]], True, LeafCount[q]];
PFBDigitHeight[l_List] := Total[PFBDigitHeight /@ Flatten[l]];
PFBDigitHeight[x_] := With[{f = Together[x]}, If[f === 0, 0, Total[digitsOf /@ Flatten[{CoefficientList[Numerator[f], eps], CoefficientList[Denominator[f], eps]}]]]];
PFBRowsDigitHeight[sl_Association, rows_List] := PFBDigitHeight[Table[sl["R"][[k, sl["Index"][r]]], {k, Length[sl["R"]]}, {r, rows}]];


End[];
EndPackage[];
