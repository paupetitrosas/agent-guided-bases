(* ::Package:: *)

(* ::Title:: *)
(*PoleFreeBasis`Census`: where the poles are*)


BeginPackage["PoleFreeBasis`Census`", {"PoleFreeBasis`", "PoleFreeBasis`Config`", "PoleFreeBasis`System`", "PoleFreeBasis`Slice`",
  "MaximalCutBasis`", "MaximalCutBasis`Sectors`", "MaximalCutBasis`Rules`"}];

PFBEpsFactors::usage = "PFBEpsFactors[f] lists the factors of the denominator of f that vanish at a finite eps != 0, normalised to 1 at eps = 0 (e.g. 1 - 2 eps).";
PFBFinitePoles::usage = "PFBFinitePoles[f] lists the finite eps != 0 where f has a pole (Root objects for non-linear factors).";
PFBRowEpsProfile::usage = "PFBRowEpsProfile[sl, k, r] is the range of powers of eps of the row of master r in the k-th derivative matrix of a slice, over its non-zero entries: {lowest, highest}, \"zero\" for a zero row, \"pole\" when an entry has finite eps poles.";
PFBEpsFloorViolations::usage = "PFBEpsFloorViolations[slOld, slNew] lists the rows whose eps structure a change makes worse, {k, r, before, after} (PFBRowEpsProfile): a row whose lowest power of eps drops, and an eps-form row (every entry eps^1, or zero) that loses its form. Rows with finite poles before or after are left to the pole checks. The simplification phase keeps the eps structure: its moves lower kinematic degrees only.";
PFBEpsFloorWorseQ::usage = "PFBEpsFloorWorseQ[before, after] compares two eps ranges of a row (PFBRowEpsProfile): True when an eps-form row (zero, or eps^1 only) loses its form, or another row's lowest power of eps drops; False when either has finite poles.";
PFBReopenText::usage = "PFBReopenText[reopens] is the note of a hidden-weight hint on a sector fixed by an accepted change (\"Reopens\" -> the change ids), \"\" otherwise.";
PFBEpsRange::usage = "PFBEpsRange[f] = {lowest, highest} power of eps when f is a Laurent polynomial in eps, \"pole\" when it has finite eps poles, \"zero\" for 0.";
PFBEpsOrders::usage = "PFBEpsOrders[f] = {order at eps = 0, degree at eps -> infinity} of a non-zero f, finite eps poles or not (the first is negative when f has a pole at eps = 0); {} for 0.";
PFBEpsDegree::usage = "PFBEpsDegree[f] is the highest power of eps of an entry without finite eps poles (a Laurent polynomial in eps), None for 0 or an entry with finite poles.";
PFBDegreeViolations::usage = "PFBDegreeViolations[slOld, slNew, cap, opts] lists the entries of slNew that a change raised above the cap on the power of eps: {derivative index, row, column, new power, old power or None}. The power of an entry is its degree at eps -> infinity (the highest power of eps when it has no finite pole), finite poles or not. An entry counts when its power exceeds Max[cap, its power in slOld]: an entry above the cap before may keep its power, not raise it (a pole fix may leave the power the entry had with its poles); an entry that was 0 must end at or below the cap. opts: \"Rows\" (labels, default all). Empty for cap = Infinity.";
PFBCensus::usage = "PFBCensus[sys, sl, opts] is the pole census of a slice: bad entries (finite eps poles), eps = 0 poles (negative powers of eps), the eps profile, the highest power of eps (\"MaxDegree\", entries without finite poles) and the entries above the cap (\"HighDegree\" -> {{k, row, column, power}..}, cap opts \"MaxEpsDegree\", default $PFBMaxEpsDegree), and per sector the rows with finite poles (\"BadRows\"), with negative powers of eps (\"EpsZeroRows\", own block \"SelfBlockEpsZero\") and above the cap (\"HighRows\", columns \"HighColumns\", own block \"SelfBlockHigh\"), its \"Issues\", the pole columns and the lower bad sectors it couples to. A sector is bad when it has any of the three, all fixed like poles (a negative power of eps is a pole at eps = 0, PFBSourceTest). \"BadSectors\" lists them bottom-up. \"HiddenWeights\": for a pole factor w whose every column (over all bad rows) lies in the subtree of one clean sector S (PFBSubtreeMasters; at least one column a master of S, the lowest such S, every row with w above S and coupling to S's masters), <|\"Factor\" -> w, \"Sector\" -> S, \"Columns\", \"Masters\" (S's masters among them), \"Rows\", \"Sectors\" (where the poles show), \"Tried\"|>: S possibly carries the hidden weight w (\"PossibleHiddenWeight\" -> {w, ...} of S; \"HiddenWeightBelow\" -> <|w -> S|> of the sectors where it shows). \"Next\" is the lowest bad sector that is not possibly inherited, or a sector with a possible hidden weight, whichever comes first bottom-up; a hint whose lower-sector scan was recorded (opts \"HiddenWeightTried\" -> <|S -> {w, ...}|>, PFBHiddenWeightTried) has \"Tried\" -> True and no longer makes S \"Next\". A sector that cannot change gets no hint (PFBCanChangeQ: a frozen family, or opts \"Fixed\": the flagged sectors); a sector fixed by an accepted change gets it, with \"Reopens\" -> the ids of those changes (opts \"Reopen\" -> <|S -> {id, ...}|>, PFBReopenedSectors): a hidden weight is often what such a change left. The scripts pass the options with PFBCensusOptions.";
PFBCanChangeQ::usage = "PFBCanChangeQ[sys, key, fixed] is False for a sector whose masters cannot change: of a frozen family, or in fixed (the hidden-weight route passes the flagged sectors, PFBFlaggedSectors).";
PFBSubtreeMasters::usage = "PFBSubtreeMasters[sys, sl, key] lists the masters of a sector's subtree on the slice: the sector's own masters (images included), the masters of its strict subsectors in its base family, and every master its rows reach through the couplings of the slice (symmetries into other families included). A reduction of the sector's subtree has these masters; a change of the sector's masters leaves their rows below it as they are and changes the rows above that couple to it.";
PFBCompareCensus::usage = "PFBCompareCensus[before, after] = <|\"Improved\", \"NewBad\", \"Removed\", \"NewEpsZero\", \"RemovedEpsZero\", \"NewHigh\", \"RemovedHigh\" (entries above the cap, {k, row, column}), ...|>: an accepted change must remove bad entries (finite poles, negative powers of eps or entries above the cap) and create none, except new poles in rows above that their own sector can remove (PFBDeferredPoles, the gate).";
PFBCensusText::usage = "PFBCensusText[census] is a short text summary.";
PFBProfileCounts::usage = "PFBProfileCounts[census] are the counts of the eps ranges {lo, hi} of the non-zero entries.";

Begin["`Private`"];


PFBEpsFactors[0] := {};
PFBEpsFactors[f_] := Module[{den = Denominator[Together[f]]},
  If[FreeQ[den, eps], Return[{}]];
  DeleteDuplicates[Cases[FactorList[den], {g_, m_} /; ! FreeQ[g, eps] && (g /. eps -> 0) =!= 0 :> Expand[g/(g /. eps -> 0)]]]];

PFBFinitePoles[f_] := Union[Flatten[Table[eps /. Solve[g == 0, eps], {g, PFBEpsFactors[f]}]]];

PFBEpsOrders[0] := {};
PFBEpsOrders[f_] := Module[{t = Together[f], num, den},
  num = Expand[Numerator[t]]; den = Expand[Denominator[t]];
  {Exponent[num, eps, Min] - Exponent[den, eps, Min], Exponent[num, eps] - Exponent[den, eps]}];

PFBEpsDegree[0] := None;
PFBEpsDegree[f_] := If[PFBEpsFactors[f] =!= {}, None, Last[PFBEpsOrders[f]]];

(* an entry the change left as it was cannot have risen: only the others are measured. Every non-zero entry is measured
   by its degree at eps -> infinity, with finite poles or not: a pole entry that the gate did not judge could rise, and
   its own sector's fix would then keep that power *)
PFBDegreeViolations[slOld_Association, slNew_Association, cap_, opts_Association : <||>] := Module[{ixO = slOld["Index"], ixN = slNew["Index"], out = {}},
  If[cap === Infinity, Return[{}]];
  Do[With[{f = slNew["R"][[k, ixN[r], ixN[c]]], f0 = If[KeyExistsQ[ixO, r] && KeyExistsQ[ixO, c], slOld["R"][[k, ixO[r], ixO[c]]], 0]},
     If[f =!= 0 && f =!= f0, With[{d = Last[PFBEpsOrders[f]], d0 = If[f0 === 0, None, Last[PFBEpsOrders[f0]]]},
        If[d > Max[cap, Replace[d0, None -> -Infinity]], AppendTo[out, {k, r, c, d, d0}]]]]],
    {k, Length[slNew["R"]]}, {r, Lookup[opts, "Rows", slNew["Labels"]]}, {c, slNew["Labels"]}];
  out];

PFBEpsRange[0] := "zero";
PFBEpsRange[f_] := Module[{t = Together[f], num, den, d0},
  If[PFBEpsFactors[t] =!= {}, Return["pole"]];
  num = Expand[Numerator[t]]; den = Expand[Denominator[t]];
  d0 = Exponent[den, eps, Min];
  {Exponent[num, eps, Min] - d0, Exponent[num, eps] - Exponent[den, eps]}];

PFBRowEpsProfile[sl_Association, k_Integer, r_] := Module[{rg = PFBEpsRange /@ DeleteCases[sl["R"][[k, sl["Index"][r]]], 0]},
  Which[rg === {}, "zero", MemberQ[rg, "pole"], "pole", True, {Min[rg[[All, 1]]], Max[rg[[All, 2]]]}]];

(* an eps-form row (zero, or eps^1 only) stays so; any other row keeps its lowest power of eps or a higher one *)
PFBEpsFloorWorseQ[before_, after_] := Which[
  before === "pole" || after === "pole", False,
  before === "zero" || before === {1, 1}, ! (after === "zero" || after === {1, 1}),
  after === "zero", False,
  True, after[[1]] < before[[1]]];

PFBEpsFloorViolations[slOld_Association, slNew_Association] := Module[{rows = Select[slNew["Labels"], KeyExistsQ[slOld["Index"], #] &]},
  Flatten[Table[With[{b = PFBRowEpsProfile[slOld, k, r], a = PFBRowEpsProfile[slNew, k, r]}, If[PFBEpsFloorWorseQ[b, a], {{k, r, b, a}}, {}]],
    {k, Min[Length[slOld["R"]], Length[slNew["R"]]]}, {r, rows}], 2]];

PFBCensus[sys_Association, sl_Association, opts_Association : <||>] := Module[{R = sl["R"], labs = sl["Labels"], n, nk, bad = {}, zero = {}, prof = <||>,
    keyOf, rowsOf, secs, perSec, badRows, badSecs, next, t0 = AbsoluteTime[], factorCounts = <||>, cap = Lookup[opts, "MaxEpsDegree", $PFBMaxEpsDegree], high = {}, top = None,
    anyBad, hints},
  n = Length[labs]; nk = Length[R];
  Do[With[{f = R[[k, r, c]]}, If[f =!= 0, Module[{rg = PFBEpsRange[f]},
       If[rg === "pole",
         Module[{fs = PFBEpsFactors[f], lo = First[PFBEpsOrders[f]]}, AppendTo[bad, {k, labs[[r]], labs[[c]], fs}]; Scan[(factorCounts[#] = Lookup[factorCounts, #, 0] + 1) &, fs];
           (* an entry with finite poles can have a pole at eps = 0 as well: it counts among the negative powers too *)
           If[lo < 0, AppendTo[zero, {k, labs[[r]], labs[[c]], lo}]]],
         prof[rg] = Lookup[prof, Key[rg], 0] + 1;
         top = Max[DeleteCases[{top, rg[[2]]}, None]];
         If[rg[[2]] > cap, AppendTo[high, {k, labs[[r]], labs[[c]], rg[[2]]}]];
         If[rg[[1]] < 0, AppendTo[zero, {k, labs[[r]], labs[[c]], rg[[1]]}]]]]]], {k, nk}, {r, n}, {c, n}];
  keyOf = Association[Table[l -> PFBMaster[sys, l]["SectorKey"], {l, labs}]];
  badRows = Union[bad[[All, 2]]];
  secs = Union[Values[keyOf]];
  (* rows with any of the three issues: finite poles, negative powers of eps, entries above the cap *)
  anyBad = Union[badRows, zero[[All, 2]], high[[All, 2]]];
  perSec = Association[Table[Module[{rows = Select[labs, keyOf[#] === key &], br, pcols, self, coupled, zr, zself, hr, hcols},
       br = Intersection[rows, badRows];
       pcols = Union[Cases[bad, {_, r_, c_, _} /; MemberQ[rows, r] :> c]];
       self = Intersection[pcols, rows];
       zr = Union[Cases[zero, {_, r_, _, _} /; MemberQ[rows, r] :> r]];
       zself = Union[Cases[zero, {_, r_, c_, _} /; MemberQ[rows, r] && MemberQ[rows, c] :> c]];
       hr = Union[Cases[high, {_, r_, _, _} /; MemberQ[rows, r] :> r]];
       hcols = Union[Cases[high, {_, r_, c_, _} /; MemberQ[rows, r] :> c]];
       (* lower sectors with bad rows of any kind that this sector's rows couple to: their fix may change these rows *)
       coupled = Union[Table[keyOf[labs[[c]]], {k, nk}, {r, rows}, {c, Flatten[Position[R[[k, sl["Index"][r]]], x_ /; x =!= 0, {1}, Heads -> False]]}] // Flatten[#, 2] &];
       coupled = Select[DeleteCases[coupled, key], Intersection[Select[labs, Function[l, keyOf[l] === #]], anyBad] =!= {} &];
       key -> <|"Key" -> key, "Name" -> PFBSectorString[key], "Rows" -> rows, "BadRows" -> br, "PoleColumns" -> pcols, "SelfBlockPoles" -> self,
         "PoleFactors" -> Union[Flatten[Cases[bad, {_, r_, _, fs_} /; MemberQ[rows, r] :> fs]]],
         "EpsZeroRows" -> zr, "SelfBlockEpsZero" -> zself, "HighRows" -> hr, "HighColumns" -> hcols, "SelfBlockHigh" -> Intersection[hcols, rows],
         "Issues" -> Join[If[br =!= {}, {"finite poles"}, {}], If[zr =!= {}, {"negative powers of eps"}, {}], If[hr =!= {}, {"above eps^" <> ToString[cap]}, {}]],
         "CouplesToBadLower" -> coupled, "PossiblyInherited" -> (Intersection[rows, anyBad] =!= {} && coupled =!= {}),
         "PossibleHiddenWeight" -> {}, "HiddenWeightBelow" -> <||>|>], {key, secs}]];
  badSecs = Select[PFBSectorKeys[sys], KeyExistsQ[perSec, #] && perSec[#]["Issues"] =!= {} &];
  (* a pole factor that sits only in the columns of one clean sector's subtree: that sector may carry it as a hidden
     weight (method.md, "A hidden weight on a clean lower sector"), and it comes before the sectors where the poles show *)
  hints = hiddenWeightHints[sys, sl, bad, perSec, keyOf, Lookup[opts, "HiddenWeightTried", <||>], Lookup[opts, "Fixed", {}], Lookup[opts, "Reopen", <||>]];
  Do[perSec[h["Sector"]]["PossibleHiddenWeight"] = Union[Append[perSec[h["Sector"]]["PossibleHiddenWeight"], h["Factor"]]];
    Do[perSec[k]["HiddenWeightBelow"] = Append[perSec[k]["HiddenWeightBelow"], h["Factor"] -> h["Sector"]], {k, h["Sectors"]}], {h, hints}];
  next = SelectFirst[PFBSectorKeys[sys], (MemberQ[badSecs, #] && ! perSec[#]["PossiblyInherited"]) ||
      AnyTrue[hints, Function[h, h["Sector"] === # && ! h["Tried"]]] &, If[badSecs === {}, None, First[badSecs]]];
  PFBPrint["census: ", Length[bad], " entries with finite eps poles in ", Length[badRows], " rows, ", Length[zero], " entries with negative powers of eps",
    If[high === {}, "", ", " <> ToString[Length[high]] <> " above eps^" <> ToString[cap]], " (", Round[AbsoluteTime[] - t0], " s)"];
  <|"BadEntries" -> bad, "BadRows" -> badRows, "EpsZero" -> zero, "EpsZeroRows" -> Union[zero[[All, 2]]], "Profile" -> prof, "PoleFactors" -> factorCounts,
    "MaxDegree" -> top, "HighDegree" -> high, "HighRows" -> Union[high[[All, 2]]], "DegreeCap" -> cap,
    "Sectors" -> perSec, "BadSectors" -> badSecs, "HiddenWeights" -> hints, "Next" -> next, "Size" -> n, "Derivatives" -> sl["Derivatives"], "Date" -> PFBTimeStamp[]|>];

(* the columns each row of the slice couples to, over every derivative *)
couplingsOf[sl_Association] := Association[Table[l -> Union[Flatten[Table[sl["Labels"][[Flatten[Position[sl["R"][[k, sl["Index"][l]]], x_ /; x =!= 0, {1}, Heads -> False]]]],
     {k, Length[sl["R"]]}]]], {l, sl["Labels"]}]];

subtreeOf[sys_, labs_List, adj_Association, key_List] := Module[{own = Intersection[PFBSectorMasters[sys, key], labs], sub, seen, todo, l},
  sub = Select[labs, With[{k2 = PFBMaster[sys, #]["SectorKey"]}, k2[[1]] === key[[1]] && k2 =!= key && And @@ Thread[k2[[2]] <= key[[2]]]] &];
  seen = Association[Thread[own -> True]]; todo = own;
  While[todo =!= {}, l = First[todo]; todo = Rest[todo]; Do[If[! KeyExistsQ[seen, c], seen[c] = True; AppendTo[todo, c]], {c, Lookup[adj, l, {}]}]];
  Union[own, sub, Keys[seen]]];

PFBSubtreeMasters[sys_Association, sl_Association, key_List] := subtreeOf[sys, sl["Labels"], couplingsOf[sl], key];

(* Per pole factor w: the columns that carry it in the bad rows. When they all lie in the subtree of one clean sector S
   and one of them is a master of S, S may carry w as a hidden weight, I_m = w J_m: every row coupling to I_m then has
   1/w in column m (and in the lower columns its relation brings in), while S's own rows stay clean. The rows with w
   must lie above S and couple to S's masters: a change of S's masters alters no other row. The lowest such S that can
   still change: not of a frozen family, not flagged ("Fixed"). A sector fixed by an accepted change is named too, as
   reopened ("Reopen" -> <|S -> change ids|>): the weight is often what that change left, and the lower-sector scan
   keeps S's rows pole-free *)
PFBReopenText[ids_List] := "; it reopens a sector fixed by an accepted change" <> If[ids === {}, "", " (" <> StringRiffle[ToString /@ ids, ", "] <> ")"];
PFBReopenText[_] := "";
PFBCanChangeQ[sys_Association, key_List, fixed_List : {}] := ! MemberQ[fixed, key] && ! PFBFrozenQ[sys, key[[1]]] &&
   NoneTrue[PFBSectorMasters[sys, key], PFBFrozenQ[sys, PFBMaster[sys, #]["Family"]] &];
hiddenWeightHints[sys_, sl_, bad_List, perSec_Association, keyOf_Association, tried_Association, fixed_List : {}, reopen_Association : <||>] := Module[{adj = None, sub, out = {}, order = PFBSectorKeys[sys]},
  sub[k_] := sub[k] = subtreeOf[sys, sl["Labels"], adj, k];
  Do[Module[{ents = Select[bad, MemberQ[#[[4]], w] &], rows, cols, cands, S},
     rows = Union[ents[[All, 2]]]; cols = Union[ents[[All, 3]]];
     cands = Select[order, KeyExistsQ[perSec, #] && perSec[#]["Issues"] === {} && IntersectingQ[cols, perSec[#]["Rows"]] && PFBCanChangeQ[sys, #, fixed] &];
     If[cands =!= {} && adj === None, adj = couplingsOf[sl]];
     S = SelectFirst[cands, Function[k, SubsetQ[sub[k], cols] && ! IntersectingQ[sub[k], rows] &&
        AllTrue[rows, Function[r, IntersectingQ[adj[r], perSec[k]["Rows"]]]]], None];
     If[S =!= None, AppendTo[out, Join[<|"Factor" -> w, "Sector" -> S, "Columns" -> cols, "Masters" -> Intersection[cols, perSec[S]["Rows"]], "Rows" -> rows,
       "Sectors" -> Select[order, MemberQ[Union[keyOf /@ rows], #] &], "Tried" -> MemberQ[Lookup[tried, Key[S], {}], w]|>,
       If[KeyExistsQ[reopen, S], <|"Reopens" -> reopen[S]|>, <||>]]]]],
    {w, Union[Flatten[bad[[All, 4]]]]}];
  out];

PFBProfileCounts[c_Association] := ReverseSortBy[Normal[c["Profile"]], Last];

entryKey[e_] := Join[e[[1 ;; 3]], {#}] & /@ e[[4]];

PFBCompareCensus[c1_Association, c2_Association] := Module[{b1 = Flatten[entryKey /@ c1["BadEntries"], 1], b2 = Flatten[entryKey /@ c2["BadEntries"], 1],
    z1 = c1["EpsZero"][[All, 1 ;; 3]], z2 = c2["EpsZero"][[All, 1 ;; 3]], newBad, removed, newZero,
    h1 = Lookup[c1, "HighDegree", {}][[All, 1 ;; 3]], h2 = Lookup[c2, "HighDegree", {}][[All, 1 ;; 3]]},
  newBad = Complement[b2, b1]; removed = Complement[b1, b2];
  (* an entry that had a finite pole before and now only a negative power of eps has improved; it is not new. An entry
     that keeps its finite pole and gains a negative power of eps is new *)
  newZero = Complement[z2, z1, Complement[c1["BadEntries"][[All, 1 ;; 3]], c2["BadEntries"][[All, 1 ;; 3]]]];
  <|"Improved" -> (newBad === {} && (removed =!= {} || (b1 === {} && Length[z2] < Length[z1]) || Complement[h1, h2] =!= {}) && newZero === {} && Complement[h2, h1] === {}),
    "NewBad" -> newBad, "Removed" -> removed, "NewEpsZero" -> newZero, "RemovedEpsZero" -> Complement[z1, z2],
    (* entries above the cap: an entry that had a finite pole before and is above the cap now is not removed, and is
       new; the gate's degree check judges how far an entry rose *)
    "NewHigh" -> Complement[h2, h1], "RemovedHigh" -> Complement[h1, h2],
    "BadRowsBefore" -> Length[c1["BadRows"]], "BadRowsAfter" -> Length[c2["BadRows"]],
    "NewBadRows" -> Complement[c2["BadRows"], c1["BadRows"]]|>];

PFBCensusText[c_Association] := StringJoin[
  ToString[Length[c["BadEntries"]]], " entries with finite eps poles in ", ToString[Length[c["BadRows"]]], " of ", ToString[c["Size"]], " rows",
  If[c["PoleFactors"] =!= <||>, " (factors " <> StringRiffle[KeyValueMap[ToString[#1, InputForm] <> " x" <> ToString[#2] &, c["PoleFactors"]], ", "] <> ")", ""],
  "; ", ToString[Length[c["EpsZero"]]], " entries with negative powers of eps",
  With[{m = Length[Intersection[c["EpsZero"][[All, 1 ;; 3]], c["BadEntries"][[All, 1 ;; 3]]]]}, If[m > 0, " (" <> ToString[m] <> " of them also with finite poles)", ""]],
  If[IntegerQ[Lookup[c, "MaxDegree", None]], "; highest power of eps " <> ToString[c["MaxDegree"]] <>
    If[Lookup[c, "HighDegree", {}] === {}, "", " (" <> ToString[Length[c["HighDegree"]]] <> " entries above the cap eps^" <> ToString[c["DegreeCap"]] <> ")"], ""],
  If[c["BadSectors"] =!= {}, "; bad sectors bottom-up: " <> StringRiffle[(c["Sectors"][#]["Name"] <> " [" <> StringRiffle[Lookup[c["Sectors"][#], "Issues", {"finite poles"}], ", "] <> "]" <>
      If[c["Sectors"][#]["PossiblyInherited"], " (possibly inherited)", ""]) & /@ c["BadSectors"], ", "], ""],
  If[Lookup[c, "HiddenWeights", {}] === {}, "", "; possible hidden weights (hints: the lower-sector scan of the sector named, a small scan on one reduction of its subtree, settles each, and once it is recorded the hint ends): " <>
    StringRiffle[(PFBSectorString[#["Sector"]] <> " (" <> ToString[#["Factor"], InputForm] <>
      ", in the rows of " <> StringRiffle[PFBSectorString /@ #["Sectors"], ", "] <> PFBReopenText[Lookup[#, "Reopens", None]] <>
      If[TrueQ[#["Tried"]], "; its lower-sector scan was recorded", ""] <> ")") & /@ c["HiddenWeights"], ", "]],
  "; eps profile {lo, hi} -> count: ", ToString[Take[PFBProfileCounts[c], UpTo[8]], InputForm]];


End[];
EndPackage[];
