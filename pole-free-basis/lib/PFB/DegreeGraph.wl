(* ::Package:: *)

(* ::Title:: *)
(*PoleFreeBasis`DegreeGraph`: degrees of the output of a FiniteFlow graph, without reconstruction*)


(* ::Text:: *)
(*The kinematic degrees of a differential equation come from FiniteFlow's FFAllDegrees only: the total degree of the*)
(*numerator and of the denominator of every output, and the highest and lowest power of every input variable in each,*)
(*from univariate reconstructions along lines, one prime, nothing reconstructed in several variables. This file needs*)
(*FiniteFlow and nothing else of the toolkit: the reduction runner (bin/subtree.wls) loads it after FiniteFlow, on the*)
(*learned IBP system, and the tests load it on graphs built from planted rational functions. The toolkit itself never*)
(*loads it (its kernel has no FiniteFlow).*)
(**)
(*A graph measured here has the input variables {eps, x1, ...} (eps first) and outputs the entries of the DE. Per output:*)
(*- zero or not (FFAlgNonZeroes);*)
(*- its eps structure at a random kinematic point: the denominator's powers of eps (per-variable degrees of a graph in eps*)
(*  alone). A denominator that is a power of eps makes it a Laurent polynomial {lo, hi}; it is measured per power of eps*)
(*  when hi <= the cap (a FiniteFlow Laurent node, FFAlgLaurent, up to eps^hi), else as a whole at a generic numerical eps*)
(*  ("whole": finite poles, or above the cap);*)
(*- the degrees of each power (or of the whole entry) in x1, ...;*)
(*- letter content: f l^M has denominator degree deg D - min(M, m) deg l when l divides D m times (l irreducible), so one*)
(*  probe with M large enough gives m; f / l^M gives the multiplicity in the numerator. A probe that is one variable is*)
(*  read off the lowest powers directly. What the probes leave is the unexplained degree.*)


BeginPackage["PoleFreeBasis`DegreeGraph`", {"FiniteFlow`"}];

PFBFFLibraryProblem::usage = "PFBFFLibraryProblem[] is None when the FiniteFlow library loaded provides every function FiniteFlow.m loads, else a String naming the functions it lacks (an older build, which can hang or abort in FFSparseSolve and breaks LiteIBP's derivatives). The toolkit's PFBFiniteFlowProblem does the same; the runner and the tests that load FiniteFlow themselves use this one.";
PFBFFDegrees::usage = "PFBFFDegrees[graph, threads, maxDegree] runs FFAllDegrees on a graph and reads its per-variable degrees back (FFDumpDegrees): one <|\"Num\", \"Den\" (total degrees), \"Vars\" -> {{numMax, numMin, denMax, denMin} per input variable}|> per output, or $Failed. A graph without output gives {}.";
PFBFFMeasure::usage = "PFBFFMeasure[graph, vars, opts] measures the kinematic degrees of every output of a FiniteFlow graph with input variables vars = {eps, x1, ...} (eps first), with FFAllDegrees only. opts: \"Cap\" (highest power of eps measured per power, default 2; Infinity for none), \"Eps\" (the generic rational eps of the whole entries), \"Point\" (rules or values for x1, ... where the eps structure is read; default random primes), \"Probes\" (irreducible polynomials in x1, ...: the known singularities whose multiplicities are measured), \"Probe\" (False: no letter content), \"Threads\", \"MaxDegree\" (300). Returns <|\"Status\" -> \"measured\" | \"failed\", \"Message\", \"Vars\" -> {x1, ...}, \"Total\" (outputs), \"Entries\" -> {<|\"Index\" (position in the output), \"Eps\" -> {\"Laurent\", lo, hi} | {\"Whole\", \"finite poles\" | \"above the cap\"}, \"Terms\" -> {<|\"Power\" -> p | \"whole\", \"Num\", \"Den\", \"VarDegrees\" (aligned with Vars), \"NumLetters\", \"DenLetters\" (<|probe -> multiplicity|>, multiplicities > 0), \"NumUnexplained\", \"DenUnexplained\" (degree the probes leave)|>, ...}|>, ...} (non-zero outputs only), \"Probes\", \"Eps\", \"Point\", \"Seconds\", \"Steps\"|>.";
PFBFFSamples::usage = "PFBFFSamples[graph, points, opts] are the exact outputs of a graph at rational points (each a list of values of its input variables, in order), by FFReconstructNumeric over as many primes as needed (opts \"MaxPrimes\", default 20): one list of rationals per point, or $Failed for a point.";
PFBFFLine::usage = "PFBFFLine[graph, vars, base, direction, eps0, tau, opts] reconstructs the outputs of a graph with input variables vars = {eps, x1, ...} along the line x = base + tau direction (values for x1, ...) at eps = eps0, as rational functions of tau (univariate). opts \"MaxDegree\" (300), \"MaxPrimes\" (20), \"Threads\". Returns the list of functions or $Failed.";
PFBFFExprGraph::usage = "PFBFFExprGraph[name, learned, <|\"DepVars\" -> nonmasters, \"IndepVars\" -> masters|>, inputs, avars, fix, exprs, columns] defines the graph name with input variables avars whose output is the reduction of each expression (a linear combination of integrals and masters, coefficients rational in the inputs) on the masters columns, row-major: Sum_j C[e, j] R[j, m] with R the output of the learned graph (dependent integrals x masters, inputs inputs = {eps, invariants}), through a sparse product. The learned graph gets inputs /. fix. Returns name, or a String saying why not.";
PFBFFTransformGraph::usage = "PFBFFTransformGraph[name, sub, avars, rows, ncols, tinv] defines the graph name with input variables avars whose output is W . tinv, W the output of the graph sub (rows x ncols, row-major) and tinv an ncols x ncols matrix of rational functions of avars: the columns of a DE after a change of basis U = tinv . U'. Returns name.";
PFBFFReplaceGraph::usage = "PFBFFReplaceGraph[name, sub, hsub, avars, rows, ncols, spos] defines the graph name with input variables avars whose output is W . T^-1: W the output of the graph sub (rows x ncols, row-major), and T the change of basis that replaces the masters at the column positions spos by the outputs of the graph hsub (Length[spos] x ncols, row-major: the new masters on the old ones) and keeps the others. T^-1 is evaluated inside the graph from the outputs of hsub (FFAlgRatExprEval), so a new master given in integrals needs no reconstruction of its reduction. Returns name.";

Begin["`Private`"];


PFBFFLibraryProblem[] := Module[{bad = Select[Names["FiniteFlow`Private`*Implem"], ToExpression[#] === $Failed &]},
  If[bad === {}, None, "the FiniteFlow library " <> ToString[ToExpression["FiniteFlow`Private`fflowlib"]] <> " lacks " <> ToString[Length[bad]] <>
    " of the functions FiniteFlow.m loads (" <> StringRiffle[StringReplace[#, {"FiniteFlow`Private`" -> "", "Implem" -> ""}] & /@ Take[bad, UpTo[3]], ", "] <>
    If[Length[bad] > 3, ", ...", ""] <> "): an older build than FiniteFlow.m; set \"FiniteFlowLibrary\" in paths.wl to the build of the same version"]];

counter = 0;
dumpFile[] := FileNameJoin[{$TemporaryDirectory, "pfb_degrees_" <> ToString[$ProcessID] <> "_" <> ToString[++counter] <> ".fflow"}];

PFBFFDegrees[g_, nth_Integer : 1, maxdeg_Integer : 300] := Module[{n, r, f, raw, nin, nout, blk, out},
  n = FFNParsOut[g];
  If[! IntegerQ[n], Return[$Failed]];
  If[n == 0, Return[{}]];
  r = FFAllDegrees[g, Max[1, nth], "MaxDegree" -> maxdeg];
  If[! ListQ[r], Return[$Failed]];
  f = dumpFile[];
  If[FFDumpDegrees[g, f] === $Failed || ! FileExistsQ[f], Return[$Failed]];
  raw = BinaryReadList[f, "UnsignedInteger64"];
  Quiet[DeleteFile[f]];
  If[Length[raw] < 2, Return[$Failed]];
  {nin, nout} = raw[[1 ;; 2]];
  blk = Partition[Drop[raw, 2], 2 + 4 nin];
  If[Length[blk] =!= nout || nout =!= Length[r], Return[$Failed]];
  out = Table[<|"Num" -> b[[1]], "Den" -> b[[2]], "Vars" -> Partition[Drop[b, 2], 4]|>, {b, blk}];
  (* the totals of the dump are those FFAllDegrees returned *)
  If[(List @@@ r) =!= ({#["Num"], #["Den"]} & /@ out), Return[$Failed]];
  out];


(* ::Section:: *)
(*Letter content*)


(* the total degree of a polynomial, and its degree in each variable *)
totDeg[p_, xs_] := Module[{lam}, Exponent[Expand[p /. Thread[xs -> lam xs]], lam]];

(* items {output, probe, "Den" | "Num", M}: M bounds the multiplicity, by the total degree and, in each variable of
   the probe, by the degree of that variable beyond its lowest power. A probe that is one variable needs no probe:
   its multiplicity is the lowest power of that variable *)
probeItems[degs_, pinfo_] := Flatten[Table[Module[{dg = degs[[o]], pi = pinfo[[q]], md, mn},
     If[pi["Mono"] > 0, {},
       md = Min[Floor[dg["Den"]/pi["Deg"]], Min[Table[If[pi["VarDeg"][[v]] == 0, Infinity, Floor[(dg["Vars"][[v, 3]] - dg["Vars"][[v, 4]])/pi["VarDeg"][[v]]]], {v, Length[pi["VarDeg"]]}]]];
       mn = Min[Floor[dg["Num"]/pi["Deg"]], Min[Table[If[pi["VarDeg"][[v]] == 0, Infinity, Floor[(dg["Vars"][[v, 1]] - dg["Vars"][[v, 2]])/pi["VarDeg"][[v]]]], {v, Length[pi["VarDeg"]]}]]];
       Join[If[md >= 1, {{o, q, "Den", md}}, {}], If[mn >= 1, {{o, q, "Num", mn}}, {}]]]], {o, Length[degs]}, {q, Length[pinfo]}], 2];

(* the multiplicities of the probes in each output of the graph g (inputs xs), from one more FFAllDegrees on the
   outputs multiplied (denominator) or divided (numerator) by l^M *)
letterContent[g_, xs_, degs_, probes0_, nth_, maxdeg_] := Module[{probes, pinfo, items, gq, iq, sq, tq, mq, pq, dq, mult, out, put},
  probes = Select[probes0, totDeg[#, xs] > 0 &];
  pinfo = Table[<|"Poly" -> p, "Deg" -> totDeg[p, xs], "VarDeg" -> (Exponent[p, #] & /@ xs),
      "Mono" -> Replace[FirstPosition[xs, _?(Expand[p - #] === 0 &), {0}, {1}], {i_} :> i]|>, {p, probes}];
  mult = Table[<|"Den" -> <||>, "Num" -> <||>|>, {Length[degs]}];
  put[o_, side_, p_, m_] := (mult[[o, side]] = Append[mult[[o, side]], p -> m]);
  (* one variable: its lowest power *)
  Do[If[pinfo[[q]]["Mono"] > 0, With[{v = pinfo[[q]]["Mono"]},
      Do[If[degs[[o]]["Vars"][[v, 4]] > 0, put[o, "Den", probes[[q]], degs[[o]]["Vars"][[v, 4]]]];
        If[degs[[o]]["Vars"][[v, 2]] > 0, put[o, "Num", probes[[q]], degs[[o]]["Vars"][[v, 2]]]], {o, Length[degs]}]]], {q, Length[pinfo]}];
  items = probeItems[degs, pinfo];
  If[items =!= {},
    FFNewGraph[gq, iq, xs];
    FFAlgSimpleSubgraph[gq, sq, {iq}, g];
    FFAlgTake[gq, tq, {sq}, {1, #} & /@ items[[All, 1]]];
    FFAlgRatFunEval[gq, mq, {iq}, xs, Table[Together[If[it[[3]] === "Den", pinfo[[it[[2]]]]["Poly"]^it[[4]], pinfo[[it[[2]]]]["Poly"]^-it[[4]]]], {it, items}]];
    FFAlgMul[gq, pq, {tq, mq}];
    FFGraphOutput[gq, pq];
    dq = PFBFFDegrees[gq, nth, maxdeg];
    FFDeleteGraph[gq];
    If[dq === $Failed, Return[$Failed]];
    Do[Module[{it = items[[i]], o, e, m},
       o = it[[1]]; e = pinfo[[it[[2]]]]["Deg"];
       m = If[it[[3]] === "Den", (degs[[o]]["Den"] - dq[[i]]["Den"])/e, (degs[[o]]["Num"] - dq[[i]]["Num"])/e];
       Which[
         ! IntegerQ[m] || m < 0 || m > it[[4]], put[o, it[[3]], pinfo[[it[[2]]]]["Poly"], Missing["Inconsistent"]],
         m > 0, put[o, it[[3]], pinfo[[it[[2]]]]["Poly"], m]]], {i, Length[items]}]];
  out = Table[With[{dm = mult[[o, "Den"]], nm = mult[[o, "Num"]], dg = pinfo[[All, "Deg"]]},
      <|"NumLetters" -> nm, "DenLetters" -> dm,
        "NumUnexplained" -> If[FreeQ[nm, _Missing], degs[[o]]["Num"] - Total[KeyValueMap[#2 totDeg[#1, xs] &, nm]], Missing["Inconsistent"]],
        "DenUnexplained" -> If[FreeQ[dm, _Missing], degs[[o]]["Den"] - Total[KeyValueMap[#2 totDeg[#1, xs] &, dm]], Missing["Inconsistent"]]|>], {o, Length[degs]}];
  out];


(* ::Section:: *)
(*Measure*)


fail[msg_String] := Throw[<|"Status" -> "failed", "Message" -> msg|>, "pfbff"];

term[p_, dg_, lc_] := Join[<|"Power" -> p, "Num" -> dg["Num"], "Den" -> dg["Den"], "VarDegrees" -> dg["Vars"]|>,
  If[AssociationQ[lc], lc, <|"NumLetters" -> Missing["NotProbed"], "DenLetters" -> Missing["NotProbed"], "NumUnexplained" -> Missing["NotProbed"], "DenUnexplained" -> Missing["NotProbed"]|>]];

PFBFFMeasure[g_, vars_List, opts_Association : <||>] := Catch[Module[{e = First[vars], xs = Rest[vars], cap = Lookup[opts, "Cap", 2], eps0 = Lookup[opts, "Eps", 1009/2027],
    nth = Lookup[opts, "Threads", 1], md = Lookup[opts, "MaxDegree", 300], probes = Lookup[opts, "Probes", {}], doProbe = TrueQ[Lookup[opts, "Probe", True]], x0, t0 = AbsoluteTime[],
    steps = {}, step, gz, iz, sz, nz, nzl, nzi, ntot, ge, ie, me, se, ed, cls, lau, who, gp, ip, sp, tp, gl, il, ln, lnz, ll, lnzl, coefIdx, dl, ll2, gw, iw, mw, sw, tw, dw,
    lcl, lcw, entries, rec},
  x0 = Replace[Lookup[opts, "Point", Automatic], {Automatic :> BlockRandom[RandomPrime[{10^4, 10^6}, Length[xs]], RandomSeeding -> 2027],
     r : {___Rule} :> (xs /. r)}];
  If[Length[x0] =!= Length[xs] || ! VectorQ[x0, NumericQ], fail["\"Point\" must give a number for every one of " <> ToString[xs, InputForm]]];
  step[name_, t_] := AppendTo[steps, <|"Step" -> name, "Seconds" -> Round[AbsoluteTime[] - t, 0.01]|>];
  (* 1. the non-zero outputs *)
  With[{t = AbsoluteTime[]},
    FFNewGraph[gz, iz, vars];
    FFAlgSimpleSubgraph[gz, sz, {iz}, g];
    FFAlgNonZeroes[gz, nz, {sz}];
    FFGraphOutput[gz, nz];
    nzl = FFNonZeroesLearn[gz];
    step["non-zero outputs", t]];
  If[! MatchQ[nzl, {___Rule}], FFDeleteGraph[gz]; fail["FFNonZeroesLearn failed: " <> ToString[nzl, InputForm]]];
  {ntot, nzi} = {"All", "NonZero"} /. nzl;
  If[nzi === {}, FFDeleteGraph[gz];
    Throw[<|"Status" -> "measured", "Vars" -> xs, "Total" -> ntot, "Entries" -> {}, "Probes" -> probes, "Eps" -> eps0, "Point" -> Thread[xs -> x0],
      "Seconds" -> Round[AbsoluteTime[] - t0, 0.01], "Steps" -> steps|>, "pfbff"]];
  (* 2. the eps structure of each output at a random kinematic point: the powers of eps in its denominator *)
  With[{t = AbsoluteTime[]},
    FFNewGraph[ge, ie, {e}];
    FFAlgRatFunEval[ge, me, {ie}, {e}, Join[{e}, x0]];
    FFAlgSimpleSubgraph[ge, se, {me}, gz];
    FFGraphOutput[ge, se];
    ed = PFBFFDegrees[ge, 1, md];
    FFDeleteGraph[ge];
    step["eps structure", t]];
  If[ed === $Failed || Length[ed] =!= Length[nzi], FFDeleteGraph[gz]; fail["the degrees in eps failed (FFAllDegrees)"]];
  cls = Table[With[{v = d["Vars"][[1]]}, If[v[[3]] == v[[4]], {"Laurent", v[[2]] - v[[4]], v[[1]] - v[[3]]}, {"Whole", "finite poles"}]], {d, ed}];
  cls = Replace[cls, {"Laurent", lo_, hi_} /; hi > cap :> {"Whole", "above the cap"}, {1}];
  lau = Flatten[Position[cls, {"Laurent", __}, {1}, Heads -> False]];
  who = Complement[Range[Length[nzi]], lau];
  entries = Table[<|"Index" -> nzi[[i]], "Eps" -> cls[[i]], "Terms" -> {}|>, {i, Length[nzi]}];
  (* 3a. no kinematic variable left (one scale, set to 1): every degree is 0; the powers of eps present come from the
     outputs as functions of eps alone *)
  If[xs === {},
    rec = FFReconstructFunction[gz, {e}, "MaxDegree" -> md];
    FFDeleteGraph[gz];
    If[! ListQ[rec], fail["the outputs as functions of eps alone could not be found: " <> ToString[rec, InputForm]]];
    Do[entries[[i, "Terms"]] = If[MemberQ[lau, i],
        Table[term[p, <|"Num" -> 0, "Den" -> 0, "Vars" -> {}|>, If[doProbe, <|"NumLetters" -> <||>, "DenLetters" -> <||>, "NumUnexplained" -> 0, "DenUnexplained" -> 0|>, None]],
          {p, Select[Range[cls[[i, 2]], cls[[i, 3]]], Together[SeriesCoefficient[rec[[i]], {e, 0, #}]] =!= 0 &]}],
        {term["whole", <|"Num" -> 0, "Den" -> 0, "Vars" -> {}|>, If[doProbe, <|"NumLetters" -> <||>, "DenLetters" -> <||>, "NumUnexplained" -> 0, "DenUnexplained" -> 0|>, None]]}],
      {i, Length[nzi]}];
    Throw[<|"Status" -> "measured", "Vars" -> xs, "Total" -> ntot, "Entries" -> entries, "Probes" -> probes, "Eps" -> eps0, "Point" -> {},
      "Seconds" -> Round[AbsoluteTime[] - t0, 0.01], "Steps" -> steps|>, "pfbff"]];
  (* 3b. per power of eps: a Laurent node up to each output's highest power *)
  If[lau =!= {},
    With[{t = AbsoluteTime[]},
      FFNewGraph[gp, ip, vars];
      FFAlgSimpleSubgraph[gp, sp, {ip}, gz];
      FFAlgTake[gp, tp, {sp}, {1, #} & /@ lau];
      FFGraphOutput[gp, tp];
      FFNewGraph[gl, il, xs];
      FFAlgLaurent[gl, ln, {il}, gp, cls[[lau, 3]], "MaxDegree" -> md];
      FFGraphOutput[gl, ln];
      ll = FFLaurentLearn[gl];
      step["Laurent learning", t]];
    If[! MatchQ[ll, {_List, _List}], FFDeleteGraph[gl]; FFDeleteGraph[gp]; FFDeleteGraph[gz]; fail["the Laurent expansion in eps failed: " <> ToString[ll, InputForm]]];
    (* the coefficients of output lau[[i]]: eps^start .. eps^order *)
    coefIdx = Flatten[Table[If[ll[[1, i]] <= ll[[2, i]], Table[{i, p}, {p, ll[[1, i]], ll[[2, i]]}], {}], {i, Length[lau]}], 1];
    FFAlgNonZeroes[gl, lnz, {ln}];
    FFGraphOutput[gl, lnz];
    lnzl = FFNonZeroesLearn[gl];
    If[! MatchQ[lnzl, {___Rule}], fail["FFNonZeroesLearn on the Laurent coefficients failed"]];
    coefIdx = coefIdx[["NonZero" /. lnzl]];
    With[{t = AbsoluteTime[]}, dl = PFBFFDegrees[gl, nth, md]; step["degrees per power of eps", t]];
    If[dl === $Failed || Length[dl] =!= Length[coefIdx], fail["FFAllDegrees failed on the coefficients of eps"]];
    lcl = Which[! doProbe, None,
      probes === {}, (<|"NumLetters" -> <||>, "DenLetters" -> <||>, "NumUnexplained" -> #["Num"], "DenUnexplained" -> #["Den"]|> &) /@ dl,
      True, With[{t = AbsoluteTime[]}, Module[{r = letterContent[gl, xs, dl, probes, nth, md]}, step["letter content per power of eps", t]; r]]];
    If[lcl === $Failed, fail["the letter probes failed on the coefficients of eps"]];
    Do[With[{i = lau[[coefIdx[[c, 1]]]]}, entries[[i, "Terms"]] = Append[entries[[i, "Terms"]], term[coefIdx[[c, 2]], dl[[c]], If[lcl === None, None, lcl[[c]]]]]],
      {c, Length[coefIdx]}];
    FFDeleteGraph[gl]; FFDeleteGraph[gp]];
  (* 3c. the whole entry at a generic eps *)
  If[who =!= {},
    With[{t = AbsoluteTime[]},
      FFNewGraph[gw, iw, xs];
      FFAlgRatFunEval[gw, mw, {iw}, xs, Join[{eps0}, xs]];
      FFAlgSimpleSubgraph[gw, sw, {mw}, gz];
      FFAlgTake[gw, tw, {sw}, {1, #} & /@ who];
      FFGraphOutput[gw, tw];
      dw = PFBFFDegrees[gw, nth, md];
      step["degrees of the whole entries", t]];
    If[dw === $Failed || Length[dw] =!= Length[who], FFDeleteGraph[gw]; FFDeleteGraph[gz]; fail["FFAllDegrees failed on the whole entries"]];
    lcw = Which[! doProbe, None,
      probes === {}, (<|"NumLetters" -> <||>, "DenLetters" -> <||>, "NumUnexplained" -> #["Num"], "DenUnexplained" -> #["Den"]|> &) /@ dw,
      True, With[{t = AbsoluteTime[]}, Module[{r = letterContent[gw, xs, dw, probes, nth, md]}, step["letter content of the whole entries", t]; r]]];
    If[lcw === $Failed, fail["the letter probes failed on the whole entries"]];
    Do[entries[[who[[w]], "Terms"]] = {term["whole", dw[[w]], If[lcw === None, None, lcw[[w]]]]}, {w, Length[who]}];
    FFDeleteGraph[gw]];
  FFDeleteGraph[gz];
  <|"Status" -> "measured", "Vars" -> xs, "Total" -> ntot, "Entries" -> entries, "Probes" -> probes, "Eps" -> eps0, "Point" -> Thread[xs -> x0],
    "Seconds" -> Round[AbsoluteTime[] - t0, 0.01], "Steps" -> steps|>], "pfbff"];


(* ::Section:: *)
(*Exact values and lines*)


PFBFFSamples[g_, points_List, opts_Association : <||>] := Table[Module[{gn, pv, sn, r},
    FFNewGraph[gn];
    FFAlgRatNumEval[gn, pv, pt];
    FFAlgSimpleSubgraph[gn, sn, {pv}, g];
    FFGraphOutput[gn, sn];
    r = FFReconstructNumeric[gn, "MaxPrimes" -> Lookup[opts, "MaxPrimes", 20]];
    FFDeleteGraph[gn];
    If[ListQ[r], r, $Failed]], {pt, points}];

PFBFFLine[g_, vars_List, base_List, dir_List, eps0_, tau_Symbol, opts_Association : <||>] := Module[{gl, il, ml, sl, r},
  If[Length[base] =!= Length[vars] - 1 || Length[dir] =!= Length[vars] - 1, Return[$Failed]];
  FFNewGraph[gl, il, {tau}];
  FFAlgRatFunEval[gl, ml, {il}, {tau}, Join[{eps0}, base + tau dir]];
  FFAlgSimpleSubgraph[gl, sl, {ml}, g];
  FFGraphOutput[gl, sl];
  r = FFParallelReconstructUnivariate[gl, {tau}, "MaxDegree" -> Lookup[opts, "MaxDegree", 300], "MaxPrimes" -> Lookup[opts, "MaxPrimes", 20],
    "NThreads" -> Lookup[opts, "Threads", Automatic]];
  FFDeleteGraph[gl];
  If[ListQ[r], r, $Failed]];


(* ::Section:: *)
(*Expressions on masters*)


(* exprs: linear combinations of integrals (dependent ones, or masters themselves), coefficients rational in avars
   after fix. The dependent integrals go through a sparse product with the rows of the learned reduction; masters among
   them add their coefficients to their own column *)
PFBFFExprGraph[name_, learned_, sol_Association, inputs_List, avars_List, fix_List, exprs0_List, mwant_List] := Module[{dep = sol["DepVars"], ind = sol["IndepVars"],
    depPos, indPos, isInt, intsOf, exprs, eInts, ints, depI, indI, cols, nE, nI, nc, rows, vals, dw, in, sub, red, tk, cf, mm, dn, tot, zr, out, nms, iPos, bad, coef},
  depPos = AssociationThread[dep -> Range[Length[dep]]]; indPos = AssociationThread[ind -> Range[Length[ind]]];
  isInt[x_] := KeyExistsQ[depPos, x] || KeyExistsQ[indPos, x];
  intsOf[e_] := Union[Cases[{e}, x_ /; isInt[x], {0, Infinity}]];
  exprs = Collect[#, _?isInt] & /@ exprs0;
  eInts = intsOf /@ exprs;
  ints = Union @@ eInts;
  depI = Select[ints, KeyExistsQ[depPos, #] &]; indI = Select[ints, KeyExistsQ[indPos, #] &];
  If[! SubsetQ[ind, mwant], Return["columns that are not masters of the reduction: " <> ToString[Complement[mwant, ind], InputForm]]];
  coef[e_, x_] := Together[Coefficient[e, x] /. fix];
  (* every expression must be linear in the integrals: one inside another head would be lost *)
  bad = Select[Range[Length[exprs]], Together[exprs[[#]] - Sum[Coefficient[exprs[[#]], x] x, {x, eInts[[#]]}]] =!= 0 &];
  If[bad =!= {}, Return["expressions that are not linear combinations of the integrals of the reduction: " <> ToString[Short[exprs0[[bad]], 3], InputForm]]];
  With[{stray = Complement[Variables[Flatten[Table[coef[exprs[[q]], x], {q, Length[exprs]}, {x, eInts[[q]]}]]], avars]},
    If[stray =!= {}, Return["coefficients that depend on " <> ToString[stray, InputForm] <> ", not only on " <> ToString[avars, InputForm]]]];
  cols = indPos /@ mwant; nE = Length[exprs]; nI = Length[depI]; nc = Length[cols];
  iPos = AssociationThread[depI -> Range[nI]];
  (* the non-zero coefficients of each row; a row without any gets one explicit zero *)
  If[nI > 0,
    {rows, vals} = Transpose[Table[With[{ts = Select[Intersection[depI, eInts[[q]]], coef[exprs[[q]], #] =!= 0 &]},
        If[ts === {}, {{1}, {0}}, {iPos /@ ts, coef[exprs[[q]], #] & /@ ts}]], {q, nE}]]];
  FFNewGraph[name, in, avars];
  FFAlgRatFunEval[name, sub, {in}, avars, inputs /. fix];
  FFAlgSimpleSubgraph[name, red, {sub}, learned];
  out = None;
  If[nI > 0,
    nms = Table[cfx[i, jm], {i, Length[dep]}, {jm, Length[ind]}];
    FFAlgTake[name, tk, {red}, {Flatten[nms]} -> Flatten[nms[[depPos /@ depI, cols]]]];
    FFAlgRatFunEval[name, cf, {in}, avars, Flatten[vals]];
    FFAlgSparseMatMul[name, mm, {cf, tk}, nE, nI, nc, rows, ConstantArray[Range[nc], nI]];
    out = mm];
  If[indI =!= {},
    dw = Table[Module[{v = ConstantArray[0, nc]}, Do[With[{c = Position[mwant, x, {1}, 1]}, If[c =!= {}, v[[c[[1, 1]]]] += coef[exprs[[q]], x]]], {x, Intersection[indI, eInts[[q]]]}]; v], {q, nE}];
    FFAlgRatFunEval[name, dn, {in}, avars, Flatten[dw]];
    If[out === None, out = dn, FFAlgAdd[name, tot, {mm, dn}]; out = tot]];
  If[out === None, FFAlgRatNumEval[name, zr, ConstantArray[0, nE nc]]; out = zr];
  FFGraphOutput[name, out];
  name];

PFBFFTransformGraph[name_, sub_, avars_List, nr_Integer, nc_Integer, tinv_List] := Module[{in, w, ti, mm},
  FFNewGraph[name, in, avars];
  FFAlgSimpleSubgraph[name, w, {in}, sub];
  FFAlgRatFunEval[name, ti, {in}, avars, Together /@ Flatten[tinv]];
  FFAlgMatMul[name, mm, {w, ti}, nr, nc, nc];
  FFGraphOutput[name, mm];
  name];

(* U' = T U with T = H on the replaced positions S and the identity elsewhere: T^-1 has the rows
   S -> H_SS^-1 (e_S - H_SR) and is the identity on the others. Its entries are rational expressions in the entries of
   H, evaluated by the graph at every point *)
PFBFFReplaceGraph[name_, sub_, hsub_, avars_List, nr_Integer, nc_Integer, spos_List] := Module[{in, w, h, ti, mm, k = Length[spos], hv, hm, hssi, pm, tinv},
  hv = Table[Unique["hv"], {k nc}];
  hm = Partition[hv, nc];
  hssi = Together[Inverse[hm[[All, spos]]]];
  pm = Table[If[MemberQ[spos, c], Boole[spos[[a]] == c], -hm[[a, c]]], {a, k}, {c, nc}];
  tinv = IdentityMatrix[nc];
  tinv[[spos]] = Together[hssi . pm];
  FFNewGraph[name, in, avars];
  FFAlgSimpleSubgraph[name, w, {in}, sub];
  FFAlgSimpleSubgraph[name, h, {in}, hsub];
  FFAlgRatExprEval[name, ti, {h}, hv, Flatten[tinv]];
  FFAlgMatMul[name, mm, {w, ti}, nr, nc, nc];
  FFGraphOutput[name, mm];
  name];


End[];
EndPackage[];
