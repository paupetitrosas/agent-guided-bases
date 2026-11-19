(* ::Package:: *)

(* ::Title:: *)
(*PoleFreeBasis`Residues`: Laurent coefficients, source test, required residues*)


(* ::Text:: *)
(*Replacing one master m by I_m + Sum lambda_S I_S changes every other row r into A_rS - A_rm lambda_S. Those rows become*)
(*regular at e0 exactly when the principal part of A_rS equals that of A_rm lambda_S, for every column S: the residues*)
(*of the bad rows factor through column m (residue-column factorisation). The test needs nothing but the slice.*)


BeginPackage["PoleFreeBasis`Residues`", {"PoleFreeBasis`", "PoleFreeBasis`Config`", "PoleFreeBasis`System`", "PoleFreeBasis`Slice`",
  "PoleFreeBasis`Census`", "MaximalCutBasis`"}];

PFBLaurent::usage = "PFBLaurent[f, e0, n] is the coefficient of (eps - e0)^n of f.";
PFBPoleOrder::usage = "PFBPoleOrder[f, e0] is the order of the pole of f at e0 (0 when f is regular there).";
PFBSourceTest::usage = "PFBSourceTest[sys, sl, census, key, opts] locates the master(s) whose definition causes the poles of a bad sector, or its entries above the cap on the power of eps. An own block with finite poles, negative powers of eps or entries above the cap gives \"maximal-cut\": the sector needs a new maximal-cut basis (rung 8). Negative powers of eps towards lower masters are a pole at eps = 0, tested with the finite poles (\"Poles\" has the key 0). A sector without either whose rows have entries above the cap gets the same column factorisation at eps -> infinity: \"degree-source\" (the entries above the cap factor through the columns of Sources), \"degree-own-row\" or \"undecided\". opts \"PolesOnly\" -> True: the finite poles alone (the gate's deferral). Returns <|\"Outcome\" -> \"source\" | \"lower-source\" | \"undecided\" | \"own-row\" | \"maximal-cut\" | \"degree-source\" | \"degree-own-row\" | \"pole-free\", \"Passing\" -> {...}, \"Poles\", \"PoleColumns\", \"Message\"|>; each passing entry has Sources, Rho (<|{m, c, e0, n} -> value|>, the principal part lambda must have), Free (free parameters). A lower master is tried only for the pole columns below it (reached from its row through the couplings of the DE, or a strict subsector of its sector in its family). When nothing passes: \"undecided\" if lower sectors that are still bad and not flagged can change these rows (\"WaitFor\": \"WaitColumns\", masters whose columns carry the poles, and \"WaitCouplings\", masters the rows couple to whose fix reaches the pole columns), else \"own-row\"; both carry \"SingleColumn\" -> <|e0 -> masters|> for poles that sit in the column of one lower master (with its images) only (a hidden normalisation of that master is possible). opts: MaxLowerSources (1; 0 skips the lower search and the waiting on couplings), MaxLowerCandidates (40), Flagged (sector keys that no longer count as waiting), Fixed (masters replaced by accepted changes: not proposed as lower sources). Where the census marks a possible hidden weight (PFBCensus \"HiddenWeights\": on this sector, or on a clean lower sector whose subtree holds every column of a factor of these rows), the result has \"HiddenWeight\" -> those hints and the message says which sector to open first (its lower-sector scan, PFBHiddenWeightScan).";
PFBPrincipalPart::usage = "PFBPrincipalPart[f, e0] = {c_-N, ..., c_-1}: the principal part of f at e0.";
PFBSourcesByPole::usage = "PFBSourcesByPole[sys, sl, key, opts] says, for every pole e0 in the rows of the sector towards other sectors (finite, or e0 = 0 for negative powers of eps, \"factor\" -> eps), and for eps -> infinity when its rows have entries above the cap (\"pole\" -> Infinity, \"factor\" -> eps^(cap + 1), opts \"MaxEpsDegree\", default $PFBMaxEpsDegree), which of the sector's masters must change to remove it: <|\"pole\", \"factor\", \"order\", \"rows\" (the sector's rows that carry it), \"columns\" (where a fix must reach), \"ownBlock\" (True: the sector's own block has the pole, only a new maximal-cut basis removes it), \"sources\" (the smallest sets of masters, images grouped by position, through whose columns the other rows factor), \"needed\" (their size)|>. The test is the residue-column factorisation of PFBSourceTest, pole by pole. The sources' own rows are not constrained here: they change through d lambda and the gate checks them. A count equal to the number of masters means every master needs a singular relation to its replacement; it does not by itself call for a new maximal-cut basis.";

Begin["`Private`"];


PFBLaurent[0, _, _] := 0;
PFBLaurent[f_, e0_, n_Integer] := Module[{d}, SeriesCoefficient[Together[f /. eps -> e0 + d], {d, 0, n}]];

PFBPoleOrder[0, _] := 0;
PFBPoleOrder[f_, e0_] := Module[{d, g},
  g = Together[f /. eps -> e0 + d];
  Max[0, Exponent[Expand[Denominator[g]], d, Min] - Exponent[Expand[Numerator[g]], d, Min]]];

(* Why not a rank. Replacing the sector's masters by U'_S = U_S + lambda U_L (L the lower masters) changes the sector's
   rows towards L into R_SL + d lambda + lambda R_LL - R_SS lambda. A row r whose master is kept (lambda_r = 0) must
   factor through the sources' columns, R_rL ~ Sum_m R_rm lambda_m; a source's own row has the free d lambda_m. So the
   rank of the principal parts of R_SL counts nothing: one source spreads into every row through R_SS, and its own row
   adds an independent direction. Example: a sector of two masters whose residues have rank 2 at each of its poles,
   where replacing one master (a dot moved to another propagator) removes them all. *)
PFBSourcesByPole[sys_Association, sl_Association, key_List, opts_Association : <||>] := Module[{R = sl["R"], ix = sl["Index"], nk = Length[sl["R"]], rows, cols, poles = <||>,
    own = <||>, posOf, P, ord, cap = Lookup[opts, "MaxEpsDegree", $PFBMaxEpsDegree], hiOf, hrows, hcols, inf = {}, polesOf},
  rows = Select[sl["Labels"], PFBMaster[sys, #]["SectorKey"] === key &];
  cols = Complement[sl["Labels"], rows];
  posOf[l_] := PFBMaster[sys, l]["Pos"];
  P = Union[posOf /@ rows];
  ord[r_, c_, e0_] := Max[Table[PFBPoleOrder[R[[k, ix[r], ix[c]]], e0], {k, nk}]];
  (* the finite poles of an entry, and eps = 0 when it has negative powers of eps *)
  polesOf[f_] := Join[PFBFinitePoles[f], If[PFBPoleOrder[f, 0] > 0, {0}, {}]];
  Do[With[{f = R[[k, ix[r], ix[c]]]}, If[f =!= 0, Scan[(poles[#] = Max[Lookup[poles, Key[#], 0], PFBPoleOrder[f, #]]) &, polesOf[f]]]],
    {k, nk}, {r, rows}, {c, cols}];
  Do[With[{f = R[[k, ix[r], ix[c]]]}, If[f =!= 0, Scan[(own[#] = True) &, polesOf[f]]]], {k, nk}, {r, rows}, {c, rows}];
  (* eps -> infinity: the entries above the cap, without finite poles, as one more "pole" *)
  hiOf[r_, c_] := Max[Append[Cases[Table[PFBEpsDegree[R[[k, ix[r], ix[c]]]], {k, nk}], _Integer], -Infinity]];
  If[cap =!= Infinity,
    hrows = Select[rows, Function[r, AnyTrue[sl["Labels"], hiOf[r, #] > cap &]]];
    If[hrows =!= {},
      hcols = Select[cols, Function[c, AnyTrue[rows, hiOf[#, c] > cap &]]];
      inf = {Module[{pass = {}, ownQ = AnyTrue[rows, Function[r, AnyTrue[rows, hiOf[r, #] > cap &]]]},
         If[! ownQ && hcols =!= {}, Do[pass = Select[Subsets[P, {size}], Function[ps, With[{src = Select[rows, MemberQ[ps, posOf[#]] &]},
                 factorTestInf[sl, Complement[rows, src], src, hcols, cap]["Pass"]]]];
             If[pass =!= {}, Break[]], {size, Length[P] - 1}]];
         If[pass === {} && ! ownQ, pass = {P}];
         <|"pole" -> Infinity, "factor" -> eps^(cap + 1), "order" -> Max[Table[hiOf[r, c], {r, rows}, {c, sl["Labels"]}]] - cap, "rows" -> hrows, "columns" -> hcols,
           "ownBlock" -> ownQ, "sources" -> (Function[ps, Select[rows, MemberQ[ps, posOf[#]] &]] /@ pass), "positions" -> pass,
           "needed" -> If[ownQ, Missing["OwnBlock"], Length[First[pass]]]|>]}]];
  Join[KeyValueMap[Function[{e0, nn}, Module[{bad, pcols, pass = {}, ownQ = KeyExistsQ[own, e0]},
      bad = Select[rows, Function[r, AnyTrue[cols, ord[r, #, e0] > 0 &]]];
      pcols = Select[cols, Function[c, AnyTrue[rows, ord[#, c, e0] > 0 &]]];
      (* by increasing size, stopping at the first size with a passing set: larger sets pass more easily (more
         unknowns for the same test rows) and say nothing more *)
      If[! ownQ, Do[pass = Select[Subsets[P, {size}], Function[ps, With[{src = Select[rows, MemberQ[ps, posOf[#]] &]},
              factorTest[sl, Complement[rows, src], src, pcols, e0, nn]["Pass"]]]];
          If[pass =!= {}, Break[]], {size, Length[P] - 1}];
        If[pass === {}, pass = {P}]];
      <|"pole" -> e0, "factor" -> If[e0 === 0, eps, Expand[1 - eps/e0]], "order" -> nn, "rows" -> bad, "columns" -> pcols, "ownBlock" -> ownQ,
        "sources" -> (Function[ps, Select[rows, MemberQ[ps, posOf[#]] &]] /@ pass), "positions" -> pass,
        "needed" -> If[ownQ, Missing["OwnBlock"], Length[First[pass]]]|>]], KeySort[poles]], inf]];

PFBPrincipalPart[f_, e0_] := With[{nn = PFBPoleOrder[f, e0]}, Table[PFBLaurent[f, e0, n], {n, -nn, -1}]];

(* rows r of tests, candidate sources src (labels), columns cols, pole e0 of order N: solve per column c for
   rho[m, n] (n = -N..-1):  PP(A_rc) = PP(Sum_m A_rm rho_m(eps))  with A_rm Taylor-expanded at e0 *)
factorTest[sl_, rows_, src_, cols_, e0_, nn_, allow_ : (True &)] := Module[{R = sl["R"], ix = sl["Index"], nk = Length[sl["R"]], rho = <||>, free = 0, ok = True,
    a, unk, eqs, sol, srcC},
  (* the source columns must be regular at e0 in the test rows *)
  If[AnyTrue[Flatten[Table[R[[k, ix[r], ix[m]]], {k, nk}, {r, rows}, {m, src}]], PFBPoleOrder[#, e0] > 0 &], Return[<|"Pass" -> False, "Why" -> "source column singular"|>]];
  a = Association[Flatten[Table[{k, r, m} -> Table[PFBLaurent[R[[k, ix[r], ix[m]]], e0, i], {i, 0, nn - 1}], {k, nk}, {r, rows}, {m, src}], 2]];
  Do[
    (* allow[m, c]: whether lambda of source m may have a component on column c (a lower source reaches only the columns
       below it); the sources that may not get no unknown there *)
    srcC = Select[src, allow[#, c] &];
    unk = Flatten[Table[PoleFreeBasis`Residues`Private`rv[m, n], {m, srcC}, {n, -nn, -1}]];
    eqs = Flatten[Table[
        PFBLaurent[R[[k, ix[r], ix[c]]], e0, n] - Sum[Sum[If[n - i >= -nn, a[{k, r, m}][[i + 1]] PoleFreeBasis`Residues`Private`rv[m, n - i], 0], {i, 0, nn - 1}], {m, srcC}],
        {k, nk}, {r, rows}, {n, -nn, -1}]];
    eqs = DeleteCases[Together /@ eqs, 0];
    If[eqs === {}, Do[rho[{m, c, e0, n}] = 0, {m, src}, {n, -nn, -1}]; Continue[]];
    sol = Quiet@Solve[Thread[eqs == 0], unk];
    If[sol === {}, ok = False; Break[]];
    free += Length[unk] - Length[First[sol]];
    Do[rho[{m, c, e0, n}] = zeroFree[PoleFreeBasis`Residues`Private`rv[m, n] /. First[sol]], {m, src}, {n, -nn, -1}],
    {c, cols}];
  If[ok, <|"Pass" -> True, "Rho" -> rho, "Free" -> free|>, <|"Pass" -> False, "Why" -> "no factorisation"|>]];

(* free parameters of an underdetermined solve are set to 0 (the sparsest particular solution) *)
zeroFree[x_] := x /. PoleFreeBasis`Residues`Private`rv[__] -> 0;

(* the same factorisation at eps -> infinity, for entries above the cap: replacing the sources by U_m + lambda U_L leaves a
   test row r with A_rc - Sum_m A_rm lambda_mc, whose powers above the cap must vanish. lambda has an expansion
   Sum_j l_j eps^j at infinity; only the powers j >= cap + 1 - (highest power of A_rm) reach above the cap, and powers
   above (highest of A_rc) - (lowest of A_rm) are left out (with one source they must vanish). Unlike a finite pole,
   lambda may be a polynomial in eps here: an honest correction with eps-monomial coefficients can lower a power.
   Every entry involved must be free of finite poles (fix those first) *)
factorTestInf[sl_, rows_, src_, cols_, cap_] := Module[{R = sl["R"], ix = sl["Index"], nk = Length[sl["R"]], cl, ent, sr, hc, Hm, Lm, Hc, jlo, jhi, qhi,
    free = 0, ok = True, unk, eqs, sol, lv = PoleFreeBasis`Residues`Private`lv},
  ent = Flatten[Table[R[[k, ix[r], ix[c]]], {k, nk}, {r, rows}, {c, Join[src, cols]}]];
  If[AnyTrue[ent, # =!= 0 && PFBEpsFactors[#] =!= {} &], Return[<|"Pass" -> False, "Why" -> "finite poles"|>]];
  (* the coefficients of a Laurent polynomial *)
  cl[0] = <||>;
  cl[f_] := cl[f] = With[{g = Expand[Together[f]], o = PFBEpsOrders[f]}, Association[Table[q -> Coefficient[g, eps, q], {q, o[[1]], o[[2]]}]]];
  sr = DeleteCases[Flatten[Table[R[[k, ix[r], ix[m]]], {k, nk}, {r, rows}, {m, src}]], 0];
  hc = DeleteCases[Flatten[Table[R[[k, ix[r], ix[c]]], {k, nk}, {r, rows}, {c, cols}]], 0];
  Hc = Max[Append[Last[PFBEpsOrders[#]] & /@ hc, -Infinity]];
  If[Hc <= cap, Return[<|"Pass" -> True, "Free" -> 0|>]];
  If[sr === {}, Return[<|"Pass" -> False, "Why" -> "the source columns are zero in the test rows"|>]];
  Hm = Max[Last[PFBEpsOrders[#]] & /@ sr]; Lm = Min[First[PFBEpsOrders[#]] & /@ sr];
  jlo = cap + 1 - Hm; jhi = Max[jlo, Hc - Lm]; qhi = Max[Hc, jhi + Hm];
  Do[
    unk = Flatten[Table[lv[m, j], {m, src}, {j, jlo, jhi}]];
    eqs = DeleteCases[Flatten[Table[Lookup[cl[R[[k, ix[r], ix[c]]]], q, 0] -
        Sum[Lookup[cl[R[[k, ix[r], ix[m]]]], q - j, 0] lv[m, j], {m, src}, {j, jlo, jhi}], {k, nk}, {r, rows}, {q, cap + 1, qhi}]], 0];
    If[eqs === {}, Continue[]];
    sol = Quiet@Solve[Thread[eqs == 0], unk];
    If[sol === {}, ok = False; Break[]];
    free += Length[unk] - Length[First[sol]],
    {c, cols}];
  If[ok, <|"Pass" -> True, "Free" -> free|>, <|"Pass" -> False, "Why" -> "no factorisation"|>]];

(* the hint of the census (PFBCensus, "HiddenWeights"): this sector may carry a hidden weight that shows in the rows
   above, or its poles of a factor sit only in the columns of a clean lower sector's subtree. Not for the gate's call *)
PFBSourceTest[sys_Association, sl_Association, census_Association, key_List, opts_Association : <||>] := With[{r = sourceTest[sys, sl, census, key, opts]},
  If[TrueQ[Lookup[opts, "PolesOnly", False]] || ! AssociationQ[r], r, hiddenWeightNote[census, key, r]]];

hiddenWeightNote[census_, key_, r_] := Module[{hs = Lookup[census, "HiddenWeights", {}], own, below, txt = ""},
  own = Select[hs, #["Sector"] === key &];
  below = Select[hs, MemberQ[#["Sectors"], key] &];
  If[own === {} && below === {}, Return[r]];
  If[own =!= {}, txt = txt <> ". The census marks this sector as a possible hidden weight (a hint, which a recorded lower-sector scan ends): " <> StringRiffle[(ToString[#["Factor"], InputForm] <> " is a pole of the rows of " <>
       StringRiffle[PFBSectorString /@ #["Sectors"], ", "] <> " in the columns " <> ToString[ut /@ #["Columns"]] <> " only, all in this sector's subtree" <>
       If[TrueQ[#["Tried"]], " (its lower-sector scan was recorded)", ""]) & /@ own, "; "] <>
     ". Run the lower-sector scan on it, judged on those rows: a small scan on one reduction of its subtree at the slice point (bin/pair_scan.wls run.wl <job> " <>
       PFBSectorString[key] <> " --hidden-weight; method.md, \"A hidden weight on a clean lower sector\")"];
  If[below =!= {}, txt = txt <> ". The census marks " <> StringRiffle[(PFBSectorString[#["Sector"]] <> " as a possible hidden weight of " <> ToString[#["Factor"], InputForm] <>
       If[TrueQ[#["Tried"]], " (its lower-sector scan was recorded)", ""]) & /@ below, "; "] <>
     ": every column with that factor in the bad rows lies in its subtree, and its own rows are clean. A hint: open that sector first with its lower-sector scan (small: one reduction of its subtree; bin/pair_scan.wls ... --hidden-weight); once it is recorded, the hint ends"];
  Join[r, <|"HiddenWeight" -> Join[own, below], "Message" -> r["Message"] <> txt|>]];

sourceTest[sys_Association, sl_Association, census_Association, key_List, opts_Association : <||>] := Module[{sec = census["Sectors"][key], S, nk = Length[sl["R"]],
    R = sl["R"], ix = sl["Index"], poleCols, e0s, colOrder, orders, passing = {}, lowerAll, lowerCands, maxLower = Lookup[opts, "MaxLowerSources", 1], res, posOf,
    flagged = Lookup[opts, "Flagged", {}], adj, reach, belowQ, badQ, waitCols = {}, waitCpl = {}, waitFor = {}, single = <||>, polesOnly = TrueQ[Lookup[opts, "PolesOnly", False]],
    zero, zeroQ, what},
  If[MissingQ[sec], Return[<|"Outcome" -> "pole-free", "Passing" -> {}, "Message" -> "the sector is not in the census"|>]];
  S = sec["Rows"];
  (* a negative power of eps is a pole at eps = 0: in the rows towards lower masters it gets the same residue-column test
     as a finite pole (a new master whose relation to the old one carries 1/eps removes it, the maximal cut unchanged);
     in the own block only a new maximal-cut basis removes it *)
  zero = If[polesOnly, {}, Select[census["EpsZero"], MemberQ[S, #[[2]]] &]];
  zeroQ = Select[zero, ! MemberQ[S, #[[3]]] &] =!= {};
  what = If[zeroQ, "the poles (eps = 0 included: the negative powers of eps)", "the poles"];
  If[! polesOnly,
    If[Select[zero, MemberQ[S, #[[3]]] &] =!= {},
      Return[<|"Outcome" -> "maximal-cut", "Passing" -> {}, "EpsZeroRows" -> Union[Select[zero, MemberQ[S, #[[3]]] &][[All, 2]]],
        "Message" -> "the sector's own block (its maximal-cut DE) has negative powers of eps: the maximal-cut basis must change (rung 8; a uniform eps^k within the cap, rung 1, is its simplest form)"|>]];
    If[Lookup[sec, "SelfBlockHigh", {}] =!= {},
      Return[<|"Outcome" -> "maximal-cut", "Passing" -> {}, "HighColumns" -> sec["HighColumns"],
        "Message" -> "the sector's own block (its maximal-cut DE) has entries above eps^" <> ToString[census["DegreeCap"]] <> ": the maximal-cut basis must change (rung 8)"|>]]];
  If[sec["BadRows"] === {} && ! zeroQ,
    Return[If[polesOnly || Lookup[sec, "HighRows", {}] === {}, <|"Outcome" -> "pole-free", "Passing" -> {}, "Message" -> "the sector has no bad rows"|>,
      degreeSources[sys, sl, census, key, opts]]]];
  If[sec["SelfBlockPoles"] =!= {},
    Return[<|"Outcome" -> "maximal-cut", "Passing" -> {}, "PoleColumns" -> sec["PoleColumns"],
      "Message" -> "the sector's own block (its maximal-cut DE) has finite eps poles: the maximal-cut basis must change (rung 8)"|>]];
  poleCols = Complement[Union[sec["PoleColumns"], zero[[All, 3]]], S];
  e0s = Union[Flatten[Table[PFBFinitePoles[R[[k, ix[r], ix[c]]]], {k, nk}, {r, sec["BadRows"]}, {c, poleCols}]], If[zeroQ, {0}, {}]];
  (* the order of the pole of each column at each e0, over the sector's rows and all derivatives *)
  colOrder = Association[Table[e0 -> Association[Table[c -> Max[Table[PFBPoleOrder[R[[k, ix[r], ix[c]]], e0], {k, nk}, {r, S}]], {c, poleCols}]], {e0, e0s}]];
  orders = Max[Values[#]] & /@ colOrder;
  (* (i) sources inside the sector, chosen by position: the same positions in the base family and in its images *)
  posOf[l_] := PFBMaster[sys, l]["Pos"];
  Do[With[{src = Select[S, MemberQ[ps, posOf[#]] &]}, With[{test = Complement[S, src]},
      res = Table[factorTest[sl, test, src, poleCols, e0, orders[e0]], {e0, e0s}];
      If[AllTrue[res, #["Pass"] &], AppendTo[passing, <|"Sources" -> src, "Positions" -> ps, "Kind" -> "sector", "Rho" -> Join @@ (#["Rho"] & /@ res),
         "Free" -> Total[#["Free"] & /@ res], "TestRows" -> test|>]]]],
    {ps, With[{P = Union[posOf /@ S]}, If[Length[P] > 1, Subsets[P, {1, Length[P] - 1}], {}]]}];
  (* only the minimal sets: a superset of a passing set passes trivially *)
  passing = Select[passing, Function[p, ! AnyTrue[passing, SubsetQ[p["Positions"], #["Positions"]] && #["Positions"] =!= p["Positions"] &]]];
  If[passing === {},
    (* what lies below a lower master m: what its row reaches through the couplings of the DE (symmetries included,
       which propagator counting misses), and the strict subsectors of its sector in its own family (a coupling may
       vanish at the slice point). Adding integrals to m brings in only masters below it, never a sibling sector's *)
    (* none of this is needed without the lower search (MaxLowerSources -> 0, as the gate calls it) *)
    If[maxLower > 0, adj = Association[Table[l -> Union[Flatten[Table[sl["Labels"][[Flatten[Position[R[[k, ix[l]]], x_ /; x =!= 0, {1}, Heads -> False]]]], {k, nk}]]], {l, sl["Labels"]}]]];
    reach[m_] := reach[m] = Module[{seen = <|m -> True|>, todo = {m}, l},
       While[todo =!= {}, l = First[todo]; todo = Rest[todo]; Do[If[! KeyExistsQ[seen, c], seen[c] = True; AppendTo[todo, c]], {c, adj[l]}]];
       KeyDrop[seen, m]];
    belowQ[m_, c_] := KeyExistsQ[reach[m], c] || (PFBMaster[sys, c]["Family"] === PFBMaster[sys, m]["Family"] &&
       With[{lo = PFBMaster[sys, c]["Sector"], hi = PFBMaster[sys, m]["Sector"]}, lo =!= hi && And @@ Thread[lo <= hi]]);
    (* (ii) lower sources: masters the bad rows couple to, grouped with their images, lower bad sectors first. Each
       candidate gets unknowns only for the pole columns below it *)
    lowerAll = Complement[Union[Flatten[Table[sl["Labels"][[Flatten[Position[R[[k, ix[r]]], x_ /; x =!= 0, {1}, Heads -> False]]]], {k, nk}, {r, S}]]], S];
    If[maxLower > 0,
      (* a master an accepted change already fixed is not proposed again: the poles it leaves above are this sector's *)
      lowerCands = GatherBy[Complement[lowerAll, Lookup[opts, "Fixed", {}]], {PFBMaster[sys, #]["SectorKey"], posOf[#]} &];
      lowerCands = SortBy[lowerCands, {! IntersectingQ[census["BadRows"], #] &, -Total[PFBMaster[sys, First[#]]["Sector"]] &}];
      lowerCands = Take[lowerCands, UpTo[Lookup[opts, "MaxLowerCandidates", 40]]];
      Do[With[{src = Flatten[grp]}, With[{cols = Complement[poleCols, src]},
         res = If[! AllTrue[cols, Function[c, AnyTrue[src, belowQ[#, c] &]]], {<|"Pass" -> False, "Why" -> "a pole column is below none of the candidates"|>},
           Table[factorTest[sl, S, src, cols, e0, orders[e0], belowQ], {e0, e0s}]];
         If[AllTrue[res, #["Pass"] &], AppendTo[passing, <|"Sources" -> src, "Kind" -> "lower", "Rho" -> Join @@ (#["Rho"] & /@ res), "Free" -> Total[#["Free"] & /@ res], "TestRows" -> S|>]]]],
        {grp, Subsets[lowerCands, {1, maxLower}]}]]];
  passing = SortBy[passing, {Length[#["Sources"]], #["Free"]} &];
  (* nothing passes: the poles sit in columns of lower masters (the own block is pole-free). Adding integrals to such a
     master never changes its own column (A'_rm = A_rm); a change of its normalisation or maximal cut does. A lower
     sector that is still bad (and not flagged) may get exactly that change, or a correction whose lambda reaches these
     columns through -R_rm lambda: then this sector waits. A pole that sits in the column of one lower master only, in
     every bad row, is the pattern of a hidden normalisation of that master (method.md, step 4 of the structural reading) *)
  If[passing === {},
    (* for eps = 0, any bad lower sector may still change: a uniform eps^k there (or a new maximal cut) moves the powers
       of its columns *)
    badQ[m_] := With[{k = PFBMaster[sys, m]["SectorKey"]}, With[{sk = census["Sectors"][k]}, ! MissingQ[sk] && ! MemberQ[flagged, k] &&
      If[zeroQ, Lookup[sk, "Issues", If[sk["BadRows"] === {}, {}, {"finite poles"}]] =!= {}, sk["BadRows"] =!= {}]]];
    waitCols = Select[poleCols, badQ];
    waitCpl = If[maxLower > 0, Select[Complement[lowerAll, poleCols], badQ[#] && AnyTrue[poleCols, Function[c, belowQ[#, c]]] &], {}];
    waitFor = Union[waitCols, waitCpl];
    single = Association[Table[With[{cs = Select[poleCols, colOrder[e0][#] > 0 &]},
        If[Length[Union[{PFBMaster[sys, #]["SectorKey"], posOf[#]} & /@ cs]] == 1, e0 -> cs, Nothing]], {e0, e0s}]]];
  Which[
    AnyTrue[passing, #["Kind"] === "sector" &],
      <|"Outcome" -> "source", "Passing" -> Select[passing, #["Kind"] === "sector" &], "Poles" -> orders, "PoleColumns" -> poleCols,
        "Message" -> what <> " factor through the column(s) of " <> ToString[ut /@ First[Select[passing, #["Kind"] === "sector" &]]["Sources"]] <>
          ": replace these masters (rungs 2-7) by integrals with the same maximal-cut class whose subsector part has the principal part Rho"|>,
    passing =!= {},
      <|"Outcome" -> "lower-source", "Passing" -> passing, "Poles" -> orders, "PoleColumns" -> poleCols,
        "Message" -> what <> " factor through the lower column(s) " <> ToString[ut /@ First[passing]["Sources"]] <> ": fix that master first (the poles here are inherited)"|>,
    waitFor =!= {},
      <|"Outcome" -> "undecided", "Passing" -> {}, "WaitFor" -> waitFor, "WaitColumns" -> waitCols, "WaitCouplings" -> waitCpl, "SingleColumn" -> single,
        "Poles" -> orders, "PoleColumns" -> poleCols,
        "Message" -> "no column explains the residues, but lower sectors that are still bad can change these rows" <>
          If[waitCols === {}, "", ": the poles sit in the columns of " <> ToString[ut /@ Take[waitCols, UpTo[8]]] <> " (a change of normalisation or maximal cut there changes those columns)"] <>
          If[waitCpl === {}, "", If[waitCols === {}, ": ", "; "] <> "the rows couple to " <> ToString[ut /@ Take[waitCpl, UpTo[8]]] <> ", whose fix changes them by -R_rm lambda"] <>
          ". Fix or flag those sectors first, then run this test again" <> singleNote[single]|>,
    True,
      <|"Outcome" -> "own-row", "Passing" -> {}, "SingleColumn" -> single, "Poles" -> orders, "PoleColumns" -> poleCols,
        "Message" -> "no column explains the residues: scan the sector's natural integrals first (rung 3, bin/pair_scan.wls); then its own masters need a completion (rung 6), or its maximal-cut basis must change (rung 8)" <> singleNote[single]|>]];

(* a sector without finite poles whose rows have entries above the cap, its own block within it: which of its masters to
   replace (factorTestInf), as the source test does for a finite pole; else whether lower bad sectors can still change
   those columns *)
degreeSources[sys_, sl_, census_, key_, opts_] := Module[{sec = census["Sectors"][key], S, cap = census["DegreeCap"], hcols, posOf, passing = {}, badQ, waitFor},
  S = sec["Rows"]; hcols = Complement[sec["HighColumns"], S];
  posOf[l_] := PFBMaster[sys, l]["Pos"];
  Do[With[{src = Select[S, MemberQ[ps, posOf[#]] &]}, With[{r = factorTestInf[sl, Complement[S, src], src, hcols, cap]},
      If[r["Pass"], AppendTo[passing, <|"Sources" -> src, "Positions" -> ps, "Kind" -> "sector", "Free" -> r["Free"], "TestRows" -> Complement[S, src]|>]]]],
    {ps, With[{P = Union[posOf /@ S]}, If[Length[P] > 1, Subsets[P, {1, Length[P] - 1}], {}]]}];
  passing = Select[passing, Function[p, ! AnyTrue[passing, SubsetQ[p["Positions"], #["Positions"]] && #["Positions"] =!= p["Positions"] &]]];
  passing = SortBy[passing, {Length[#["Sources"]], #["Free"]} &];
  badQ[m_] := With[{k = PFBMaster[sys, m]["SectorKey"]}, With[{sk = census["Sectors"][k]}, ! MissingQ[sk] && Lookup[sk, "Issues", {}] =!= {} && ! MemberQ[Lookup[opts, "Flagged", {}], k]]];
  waitFor = Select[hcols, badQ];
  Which[
    passing =!= {},
      <|"Outcome" -> "degree-source", "Passing" -> passing, "HighColumns" -> hcols,
        "Message" -> "the powers above eps^" <> ToString[cap] <> " factor through the column(s) of " <> ToString[ut /@ First[passing]["Sources"]] <>
          ": replace these masters (rungs 2, 3, 6, 7) by integrals whose lower part brings those powers down; corrections with an eps-monomial coefficient may do it"|>,
    waitFor =!= {},
      <|"Outcome" -> "undecided", "Passing" -> {}, "WaitFor" -> waitFor, "WaitColumns" -> waitFor, "WaitCouplings" -> {}, "HighColumns" -> hcols,
        "Message" -> "no column explains the powers above eps^" <> ToString[cap] <> ", and they sit in the columns of " <> ToString[ut /@ Take[waitFor, UpTo[8]]] <>
          ", whose sectors are still bad: fix or flag those first, then run this test again"|>,
    True,
      <|"Outcome" -> "degree-own-row", "Passing" -> {}, "HighColumns" -> hcols,
        "Message" -> "no column explains the powers above eps^" <> ToString[cap] <> ": scan the sector's natural integrals (rung 3), then a completion (rung 6, which keeps every entry at or below the cap), a derivative (rung 7) or a new maximal-cut basis (rung 8)"|>]];

singleNote[single_Association] := If[single === <||>, "",
  ". " <> StringRiffle[KeyValueMap["At eps = " <> ToString[#1, InputForm] <> " every pole sits in the column of " <> ToString[ut /@ #2] &, single], "; "] <>
    ": a master whose column carries all the poles while its own row is pole-free may have a hidden normalisation (method.md, step 4 of the structural reading)"];


End[];
EndPackage[];
