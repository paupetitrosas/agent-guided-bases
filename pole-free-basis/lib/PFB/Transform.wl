(* ::Package:: *)

(* ::Title:: *)
(*PoleFreeBasis`Transform`: exact basis changes on a slice*)


(* ::Text:: *)
(*A change replaces the masters of a set of slice columns sr by new masters h_i = H_i . U (old root-free basis). With*)
(*T = H[sr] and Lam = H[rest], the new basis is {h, U_rest}; a vector v in old coordinates becomes v[sr].T^-1 on h and*)
(*v[rest] - v[sr].T^-1.Lam on the rest. Rows of other masters are re-expressed that way; the rows of the new masters*)
(*come from G_i = (1/pref_i) d(pref_i h_i) in old coordinates.*)


BeginPackage["PoleFreeBasis`Transform`", {"MaximalCutBasis`Rules`", "PoleFreeBasis`", "PoleFreeBasis`Config`", "PoleFreeBasis`System`", "PoleFreeBasis`Slice`",
  "PoleFreeBasis`Census`", "MaximalCutBasis`"}];

PFBChangeVectors::usage = "PFBChangeVectors[sys, sl, red, cal, newDefs, prefs] = <|\"Replace\", \"H\", \"G\"|> for new masters newDefs = <|label -> root-free expression|> (integrals of the reduction pool and ut[k] terms); prefs = <|label -> square-root prefactor|> (default: the old master's).";
PFBApplyChange::usage = "PFBApplyChange[sl, change] applies <|\"Name\", \"Replace\", \"H\", \"G\"|> exactly to the slice. Returns the new slice; its last History entry has the change and DetT, the determinant of the replaced block (recorded, not judged; $Failed when it is 0).";
PFBRescaleSlice::usage = "PFBRescaleSlice[sl, <|label -> n|>] is the slice after U_label -> eps^n U_label.";
PFBReplaceMasters::usage = "PFBReplaceMasters[sys, <|label -> new definition (with its root symbols)|>] is the system with these master definitions replaced; later reduction jobs then reduce onto the new basis.";
PFBImageDefs::usage = "PFBImageDefs[sys, <|label -> def|>] adds the image masters' definitions obtained by the family maps (definitions of base-family masters only). Each image master keeps its own constant normalisation relative to the mapped base master.";
PFBImageLabel::usage = "PFBImageLabel[sys, label, image] is the label of the master of the image family whose definition is the image of master label (up to a constant factor; the same position is tried first), or Missing[\"NoImage\"].";
PFBDetMonomialQ::usage = "PFBDetMonomialQ[det] is True when det is c eps^n with c a non-zero number independent of eps.";

Begin["`Private`"];


PFBChangeVectors[sys_Association, sl_Association, red_Association, cal_Association, newDefs_Association, prefs_Association : <||>] := Module[{labs = Keys[newDefs], H, G, pref},
  pref[l_] := Lookup[prefs, l, PFBMaster[sys, l]["Pref"]];
  H = Table[PFBExprVector[sys, sl, red, cal, newDefs[l]], {l, labs}];
  If[MemberQ[H, $Failed], Return[$Failed]];
  G = Table[PFBExprDVector[sys, sl, red, cal, newDefs[l], k, pref[l]], {k, Length[red["Invariants"]]}, {l, labs}];
  If[! FreeQ[G, $Failed], Return[$Failed]];
  (* order the derivatives as in the slice *)
  G = G[[Ordering[Flatten[Position[sl["Derivatives"], #] & /@ red["Invariants"]]]]];
  If[Length[G] =!= Length[sl["Derivatives"]], Print["PFBChangeVectors: the reduction does not differentiate every invariant of the slice."]; Return[$Failed]];
  <|"Replace" -> labs, "H" -> H, "G" -> G, "NewDefs" -> newDefs, "Prefs" -> Association[Table[l -> pref[l], {l, labs}]]|>];

PFBDetMonomialQ[d_] := Module[{f = Factor[d]}, f =!= 0 && (NumericQ[f] || MatchQ[f, c_. eps^n_. /; FreeQ[c, eps] && NumericQ[c]])];

PFBApplyChange[sl_Association, ch_Association] := Module[{R = sl["R"], ix = sl["Index"], n = PFBSliceSize[sl], sr, lr, T, Ti, Lam, R2, det, nk},
  nk = Length[R];
  sr = ix /@ ch["Replace"]; lr = Complement[Range[n], sr];
  T = ch["H"][[All, sr]]; Lam = ch["H"][[All, lr]];
  det = Factor[Det[T]];
  If[det === 0, Print["PFBApplyChange: the new masters are dependent on the replaced ones (det T = 0)."]; Return[$Failed]];
  Ti = Together[Inverse[T]];
  R2 = R;
  Do[Module[{row = R[[k, r]], rs},
     rs = row[[sr]];
     If[AnyTrue[rs, # =!= 0 &],
       R2[[k, r, sr]] = Together /@ (rs.Ti);
       R2[[k, r, lr]] = Together /@ (row[[lr]] - (rs.Ti).Lam)]], {k, nk}, {r, lr}];
  Do[Module[{Gk = ch["G"][[k]], AS},
     AS = Together[Gk[[All, sr]].Ti];
     R2[[k, sr, sr]] = AS;
     R2[[k, sr, lr]] = Together[Gk[[All, lr]] - AS.Lam]], {k, nk}];
  Join[sl, <|"R" -> R2, "History" -> Append[sl["History"], <|"Change" -> Lookup[ch, "Name", "change"], "Replace" -> ch["Replace"], "DetT" -> det,
      "Date" -> PFBTimeStamp[]|>]|>]];

PFBRescaleSlice[sl_Association, sh_Association] := Module[{ix = sl["Index"], v, R},
  v = ConstantArray[0, PFBSliceSize[sl]];
  KeyValueMap[(v[[ix[#1]]] = #2) &, sh];
  R = Table[If[sl["R"][[k, r, c]] === 0, 0, Together[eps^(v[[r]] - v[[c]]) sl["R"][[k, r, c]]]], {k, Length[sl["R"]]}, {r, Length[v]}, {c, Length[v]}];
  Join[sl, <|"R" -> R, "History" -> Append[sl["History"], <|"Change" -> "rescale", "Shifts" -> sh, "Date" -> PFBTimeStamp[]|>]|>]];

PFBReplaceMasters[sys0_Association, defs_Association] := Module[{sys = sys0, recs = sys0["MasterRecords"]},
  KeyValueMap[Function[{l, d}, Module[{mono, rf, r = recs[[l]]},
      {mono, rf} = PFBRootMonomial[sys, d];
      recs[[l]] = Join[r, <|"Def" -> d, "Mono" -> mono, "Pref" -> (mono /. PFBRootDefs[sys]), "RootFree" -> rf,
         "Integrals" -> Union[Cases[{d /. Dinv[a_, _] :> a}, _j, Infinity]], "Changed" -> True, "OldDef" -> Lookup[r, "OldDef", r["Def"]]|>]]], defs];
  sys["MasterRecords"] = recs;
  sys];

(* the image master that is the image of base master l: the one whose root-free definition is the mapped one up to a
   constant factor (an image with its own masters file may order or normalise them differently). Returns
   {label, factor}, or Missing *)
imageMatch[sys_Association, l_Integer, image_] := Module[{tgt = Collect[PFBImageExpr[sys, PFBMaster[sys, l]["RootFree"], image], _j], cands, ratio},
  ratio[e_] := Module[{ee = Collect[e, _j], jl = Union[Cases[{tgt}, _j, Infinity]], r},
    If[jl === {} || Union[Cases[{ee}, _j, Infinity]] =!= jl, Return[None]];
    r = Together[Coefficient[ee, First[jl]]/Coefficient[tgt, First[jl]]];
    If[FreeQ[r, eps] && Together[ee - r tgt] === 0, r, None]];
  cands = Select[PFBMasters[sys], #["Family"] === image &];
  (* the same position first: for an image without its own masters file that is the match *)
  SelectFirst[Join[Select[cands, #["Pos"] === PFBMaster[sys, l]["Pos"] &], cands],
    ratio[#["RootFree"]] =!= None &, Missing["NoImage"]] /. m_Association :> {m["Label"], ratio[m["RootFree"]]}];

PFBImageLabel[sys_Association, l_Integer, image_] := Replace[imageMatch[sys, l, image], {lab_, _} :> lab];

PFBImageDefs[sys_Association, defs_Association] := Module[{out = defs},
  KeyValueMap[Function[{l, d}, With[{fn = PFBMaster[sys, l]["Family"]},
      If[PFBBaseOf[sys, fn] === fn,
        Do[With[{m = imageMatch[sys, l, im]},
            If[MissingQ[m], PFBPrint["image ", im, " has no master matching ut[", l, "]: its copy is not changed"],
              If[! KeyExistsQ[defs, m[[1]]], out[m[[1]]] = m[[2]] PFBImageExpr[sys, d, im]]]], {im, PFBImagesOf[sys, fn]}]]]], defs];
  out];


End[];
EndPackage[];
