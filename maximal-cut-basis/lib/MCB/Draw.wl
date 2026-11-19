(* ::Package:: *)

(* ::Title:: *)
(*MaximalCutBasis`Draw`: topology drawing (SVG)*)


(* ::Text:: *)
(*The graph of a sector comes from the family's "Graph" field (contracting the propagators that are*)
(*not in the sector) or, if there is none, is reconstructed from momentum conservation: a vertex is a*)
(*signed set of edges whose loop momenta cancel, and every edge must enter exactly one vertex and leave*)
(*exactly one (a signed exact cover).  Linear (eikonal) propagators are edges too and are drawn as*)
(*Wilson lines.  Every cover is enumerated (up to a cap) and the drawn one has the right number of loops, is connected*)
(*when possible (a product of one-loop integrals shares a vertex) and has few external legs; tadpole lines are self-loops*)
(*in the widest free angle at their vertex.  Reconstruction is best effort: the "Graph" field is the reliable route.*)
(*The SVG is written by hand from a spring layout, so no front end is needed.*)


BeginPackage["MaximalCutBasis`Draw`", {"MaximalCutBasis`", "SkillCore`Tools`", "SkillCore`Records`", "SkillCore`Pages`", "MaximalCutBasis`Family`",
   "MaximalCutBasis`Sectors`"}];

MCBGraph::usage = "MCBGraph[fam, sector] returns <|\"ok\", \"vertices\", \"edges\" -> {{tail, head, i}}, \"legs\" -> {{v, momentum}}, \"message\"|> for the sector.";
MCBDrawSector::usage = "MCBDrawSector[fam, sector, file] draws the sector (massive lines thick, massless thin, linear lines dashed, cut marks) and exports an SVG. Returns the file name.";
MCBGraphSVG::usage = "MCBGraphSVG[fam, sector] returns the SVG text.";

Begin["`Private`"];


loopPart[fam_, q_] := Coefficient[q, #] & /@ fam["LoopMomenta"];
extPart[fam_, q_] := Expand[q - loopPart[fam, q] . fam["LoopMomenta"]];

(* from the user's Graph field: {{va, vb, i}, ...} internal lines and {{v, p}, ...} legs *)
fromGraphField[fam_, s_] := Module[{g = fam["Graph"], lines, legs, parent = <||>, find, union, keep, vs},
  lines = Cases[g, {a_, b_, i_Integer} :> {a, b, i}];
  legs = Cases[g, {a_, p_} /; ! IntegerQ[p] :> {a, p}];
  find[x_] := If[Lookup[parent, x, x] === x, x, parent[x] = find[parent[x]]];
  union[a_, b_] := With[{ra = find[a], rb = find[b]}, If[ra =!= rb, parent[ra] = rb]];
  Scan[If[s[[#[[3]]]] =!= 1, union[#[[1]], #[[2]]]] &, lines];
  keep = Select[lines, s[[#[[3]]]] === 1 &];
  vs = DeleteDuplicates[find /@ Join[keep[[All, 1]], keep[[All, 2]], legs[[All, 1]]]];
  <|"ok" -> True, "vertices" -> Length[vs],
    "edges" -> ({First@FirstPosition[vs, find[#[[1]]]], First@FirstPosition[vs, find[#[[2]]]], #[[3]]} & /@ keep),
    "legs" -> ({First@FirstPosition[vs, find[#[[1]]]], #[[2]]} & /@ legs), "message" -> "from the Graph field"|>];

(* components and cycle rank of a vertex assignment (rows: vertices, entries -1/0/1 per non-self-loop line) *)
coverShape[res_, rest_, nSelf_] := Module[{V = Length[res], ug, C},
  ug = Graph[Range[V], Table[UndirectedEdge[First@FirstPosition[res[[All, i]], -1], First@FirstPosition[res[[All, i]], 1]], {i, rest}]];
  C = Length[ConnectedComponents[ug]];
  <|"components" -> C, "loops" -> Length[rest] - V + C + nSelf|>];

reconstruct[fam_, s_] := Module[{idx = PropPos[s], al, be, nE, L, selfl, rest, sets, cover, covers, count = 0, shape, best, res, V, verts, edges, legs, note},
  al = loopPart[fam, fam["Propagators"][[#]]["Momentum"]] & /@ idx;
  be = extPart[fam, fam["Propagators"][[#]]["Momentum"]] & /@ idx;
  nE = Length[idx];
  If[nE == 0 || nE > 12, Return[<|"ok" -> False, "message" -> "reconstruction only for 1..12 lines"|>]];
  L = MatrixRank[al];
  (* signed sets with cancelling loop momenta *)
  sets = Select[Tuples[{-1, 0, 1}, nE], ! AllTrue[#, # == 0 &] && AllTrue[# . al, # == 0 &] &];
  (* lines in no balanced set are self-loops (tadpole lines) *)
  selfl = Select[Range[nE], Function[i, NoneTrue[sets, #[[i]] != 0 &]]];
  rest = Complement[Range[nE], selfl];
  sets = SortBy[Select[sets, Function[st, AllTrue[selfl, st[[#]] == 0 &]]], Count[#, Except[0]] &];
  (* every signed exact cover, up to a cap: the first one found is often a set of disjoint bubbles (one loop too many,
     or a product drawn as separate pieces), so the covers are compared below *)
  cover[chosen_, need_] := Module[{e, sg},
    If[need === {}, Sow[chosen]; count++; If[count >= 3000, Throw[Null, "mcbcap"]],
      {e, sg} = First[need];
      Do[If[st[[e]] == sg && AllTrue[Range[nE], Function[i, st[[i]] == 0 || MemberQ[need, {i, st[[i]]}]]],
          cover[Append[chosen, st], DeleteCases[need, {i_, sgn_} /; st[[i]] == sgn]]],
        {st, sets}]]];
  covers = If[rest === {}, {{}}, Flatten[Reap[Catch[cover[{}, Flatten[Table[{{i, 1}, {i, -1}}, {i, rest}], 1]], "mcbcap"]][[2]], 1]];
  If[covers === {}, Return[<|"ok" -> False, "message" -> "no vertex assignment found (not a graph, or ISPs in the sector)"|>]];
  (* the right number of loops first, then connected, then few external legs *)
  shape[c_] := If[c === {}, <|"components" -> 1, "loops" -> Length[selfl]|>, coverShape[c, rest, Length[selfl]]];
  best = First[MinimalBy[covers, With[{sh = shape[#]}, {Boole[sh["loops"] =!= L], sh["components"], If[# === {}, 0, Count[Expand[# . be], Except[0]]]}] &]];
  res = best;
  note = With[{sh = shape[res]}, Which[sh["loops"] =!= L, " (best effort: " <> ToString[sh["loops"]] <> " loops drawn)",
    sh["components"] > 1, " (factorised: " <> ToString[sh["components"]] <> " pieces)", True, ""]];
  V = Max[1, Length[res]];
  edges = Table[{If[rest === {} || ! MemberQ[rest, i], 1, First@FirstPosition[res[[All, i]], -1]],
      If[rest === {} || ! MemberQ[rest, i], 1, First@FirstPosition[res[[All, i]], 1]], idx[[i]]}, {i, nE}];
  (* self-loops: attach to the vertex with most lines *)
  If[selfl =!= {} && res =!= {}, With[{vmax = First@Ordering[-Table[Count[r, Except[0]], {r, res}], 1]},
     edges = ReplacePart[edges, Table[i -> {vmax, vmax, idx[[i]]}, {i, selfl}]]]];
  legs = DeleteCases[Table[{v, Expand[-res[[v]] . be]}, {v, Length[res]}], {_, 0}];
  If[res === {}, legs = {}];
  <|"ok" -> True, "vertices" -> V, "edges" -> edges, "legs" -> legs,
    "message" -> "graph from momentum conservation" <> note|>];

MCBGraph[fam_Association, s_List] := If[ListQ[fam["Graph"]], fromGraphField[fam, s], reconstruct[fam, s]];


(* ::Section:: *)
(*SVG*)


esc[s_String] := StringReplace[s, {"&" -> "&amp;", "<" -> "&lt;", ">" -> "&gt;"}];
num[x_] := ToString[NumberForm[N[x], {6, 1}]];

(* straight-segment crossings and the closest pair of nodes: among several layouts, the one with the fewest crossings
   (and no nodes on top of each other) is drawn *)
segCross[{p1_, p2_}, {q1_, q2_}] := Module[{o},
  o[a_, b_, c_] := Sign[(b - a)[[1]] (c - a)[[2]] - (b - a)[[2]] (c - a)[[1]]];
  o[p1, p2, q1] o[p1, p2, q2] < 0 && o[q1, q2, p1] o[q1, q2, p2] < 0];

(* distance of point x from the segment {a, b} *)
segDist[x_, {a_, b_}] := With[{t = Clip[If[Norm[b - a] < 10^-9, 0, (x - a) . (b - a)/((b - a) . (b - a))], {0, 1}]}, Norm[x - (a + t (b - a))]];

layoutScore[c_, segs_, nv_] := Module[{cr = 0, n = Length[c], lens, med, dmin, near, cen, legBad},
  (* two propagators crossing count double: a crossing with an external leg reads better (a vertex inside a face
     whose leg must leave it) *)
  Do[If[Intersection[segs[[i]], segs[[j]]] === {} && segCross[c[[segs[[i]]]], c[[segs[[j]]]]],
      cr += If[Max[segs[[i]]] <= nv && Max[segs[[j]]] <= nv, 2, 1]], {i, Length[segs]}, {j, i + 1, Length[segs]}];
  lens = If[segs === {}, {1.}, Norm[c[[#[[1]]]] - c[[#[[2]]]]] & /@ segs];
  med = Max[Median[lens], 10^-6];
  dmin = If[n < 2, 1., Min[Norm[c[[#[[1]]]] - c[[#[[2]]]]] & /@ Subsets[Range[n], {2}]]/med];
  (* nodes close to a line they do not belong to *)
  near = Flatten[Table[If[MemberQ[sg, k], Infinity, segDist[c[[k]], c[[sg]]]/med], {k, n}, {sg, segs}]];
  (* external legs should point away from the middle of the graph *)
  cen = Mean[c[[1 ;; nv]]];
  legBad = Total[Table[With[{sg = SelectFirst[segs, MemberQ[#, k] &]}, If[MissingQ[sg], 0,
      With[{v = First[DeleteCases[sg, k]]}, If[Norm[c[[v]] - cen] < 10^-6 Max[med, 1], 0, 1 - Normalize[c[[k]] - c[[v]]] . Normalize[c[[v]] - cen]]]]], {k, nv + 1, n}]];
  (* crossings and nodes on lines first, then the shape: even line lengths, nodes clear of the lines, legs outwards *)
  {cr + Count[near, x_ /; x < 0.15] + If[dmin < 0.3, 1, 0], Max[lens]/Max[Min[lens], 10^-6] + 3 Count[near, x_ /; x < 0.35] + 2 legBad}];

MCBGraphSVG[fam_Association, s_List] := Module[{g = MCBGraph[fam, s], V, edges, legs, gr, nodes, segs, cands, coords, xs, ys, sc, ox, oy, W = 360, H = 280, pad,
    P, out = {}, groups, legEnd, selfDirs = <||>, ctrlOf, labs = {}, fixed, msg, line2, withLegs, segsAll, drawn = {}},
  If[! TrueQ[g["ok"]],
    Return[StringJoin["<svg xmlns='http://www.w3.org/2000/svg' width='360' height='", ToString[40 + 18 Total[s]], "' class='topology'>",
      "<text x='10' y='22' font-size='13' fill='currentColor'>", esc[SectorName[s]], ": ", esc[g["message"]], "</text>",
      Table["<text x='10' y='" <> ToString[42 + 18 k] <> "' font-size='12' fill='currentColor'>D" <> ToString[PropPos[s][[k]]] <> " = " <>
        esc[MCBPropLabel[fam, PropPos[s][[k]]]] <> "</text>", {k, Length[PropPos[s]]}], "</svg>"]]];
  V = g["vertices"]; edges = g["edges"]; legs = g["legs"];
  pad = If[MemberQ[edges, {a_, a_, _}], 70, 40];
  (* layout of the internal graph (vertices 1..V); the legs (nodes V+1..) are added afterwards, each in the free
     direction closest to the outward one, so that a leg never drags the graph into a stretched shape *)
  segs = DeleteDuplicates[Sort /@ Select[edges[[All, 1 ;; 2]], #[[1]] =!= #[[2]] &]];
  gr = Graph[Range[V], UndirectedEdge @@@ segs];
  cands = If[V == 1, {{{0., 0.}}},
    Select[Join[Quiet[Check[N[GraphEmbedding[gr, #]], $Failed]] & /@
        {"SpringElectricalEmbedding", "TutteEmbedding", "PlanarEmbedding", "SpringEmbedding", "CircularEmbedding"},
      Table[Module[{perm = BlockRandom[SeedRandom[q]; RandomSample[Range[V]]], emb},
          emb = Quiet[Check[N[GraphEmbedding[Graph[Range[V], UndirectedEdge @@@ (segs /. Thread[Range[V] -> perm])], "SpringElectricalEmbedding"]], $Failed]];
          If[MatrixQ[emb, NumericQ], emb[[perm]], $Failed]], {q, 6}]],
     MatrixQ[#, NumericQ] && Length[#] == V &]];
  If[cands === {}, cands = {N[CirclePoints[V]]}];
  nodes = V + Length[legs];
  (* every candidate gets its legs, and the whole drawing is scored (a vertex inside a face has a leg that crosses
     a line; a layout with that vertex outside is preferred) *)
  withLegs[c0_] := Module[{c = c0, cen = Mean[c0], med = If[segs === {}, 1., Max[Median[Norm[c0[[#[[1]]]] - c0[[#[[2]]]]] & /@ segs], 10^-6]], placed = <||>},
    Do[Module[{v = legs[[k, 1]], out, used, angs, gaps, best},
       out = If[Norm[c[[v]] - cen] < 10^-6, {0., 1.}, Normalize[c[[v]] - cen]];
       used = Join[(c[[If[#[[1]] === v, #[[2]], #[[1]]]]] - c[[v]]) & /@ Select[segs, MemberQ[#, v] &], Lookup[placed, v, {}]];
       used = Select[used, Norm[#] > 10^-9 &];
       best = If[used === {}, ArcTan @@ out,
         angs = DeleteDuplicates[Sort[Mod[ArcTan @@ #, 2 Pi] & /@ used], Abs[#1 - #2] < 10^-6 &];
         gaps = Table[{angs[[q]], With[{d = Mod[angs[[Mod[q, Length[angs]] + 1]] - angs[[q]], 2 Pi]}, If[d < 10^-9, 2 Pi, d]]}, {q, Length[angs]}];
         (* the bisector of a wide gap, as close as possible to the outward direction *)
         With[{g = First[MaximalBy[gaps, Function[gp, gp[[2]] + 1.5 Cos[gp[[1]] + gp[[2]]/2 - ArcTan @@ out]]]]}, g[[1]] + g[[2]]/2]];
       AppendTo[c, c[[v]] + 0.9 med {Cos[best], Sin[best]}];
       placed[v] = Append[Lookup[placed, v, {}], {Cos[best], Sin[best]}]], {k, Length[legs]}];
    c];
  segsAll = Join[segs, Table[{legs[[k, 1]], V + k}, {k, Length[legs]}]];
  coords = First[MinimalBy[withLegs /@ cands, layoutScore[#, segsAll, V] &]];
  xs = coords[[All, 1]]; ys = coords[[All, 2]];
  sc = Min[(W - 2 pad)/Max[Max[xs] - Min[xs], 10^-6], (H - 2 pad)/Max[Max[ys] - Min[ys], 10^-6]];
  sc = Min[sc, 140];
  ox = W/2 - sc (Max[xs] + Min[xs])/2; oy = H/2 + sc (Max[ys] + Min[ys])/2;
  P[k_] := {ox + sc coords[[k, 1]], oy - sc coords[[k, 2]]};
  (* control point of each line (multi-edges are arcs), as drawn below *)
  groups = GatherBy[Range[Length[edges]], Sort[edges[[#, 1 ;; 2]]] &];
  Do[Do[With[{e = edges[[grp[[r]]]], off = (r - (Length[grp] + 1)/2) 34},
       If[e[[1]] =!= e[[2]], ctrlOf[grp[[r]]] = (P[e[[1]]] + P[e[[2]]])/2 + 2 off With[{pa = P[Min[e[[1 ;; 2]]]], pb = P[Max[e[[1 ;; 2]]]]}, Normalize[{-(pb - pa)[[2]], (pb - pa)[[1]]}]]]],
     {r, Length[grp]}], {grp, groups}];
  (* self-loops (tadpole lines) in the widest free angle at their vertex, spread out when there are several *)
  Do[Module[{loops = Select[Range[Length[edges]], edges[[#, 1]] === v && edges[[#, 2]] === v &], dirs, angs, gaps, n},
     If[loops =!= {},
       dirs = Select[Join[
          (ctrlOf[#] - P[v]) & /@ Select[Range[Length[edges]], MemberQ[edges[[#, 1 ;; 2]], v] && edges[[#, 1]] =!= edges[[#, 2]] &],
          (P[V + #] - P[v]) & /@ Flatten[Position[legs[[All, 1]], v]]], Norm[#] > 10^-6 &];
       n = Length[loops];
       If[dirs === {},
         angs = Table[-Pi/2 + 2 Pi (q - 1)/n, {q, n}],
         angs = DeleteDuplicates[Sort[Mod[ArcTan[#[[1]], #[[2]]], 2 Pi] & /@ dirs], Abs[#1 - #2] < 10^-6 &];
         gaps = Table[{angs[[q]], With[{d = Mod[angs[[Mod[q, Length[angs]] + 1]] - angs[[q]], 2 Pi]}, If[d < 10^-9, 2 Pi, d]]}, {q, Length[angs]}];
         (* each self-loop goes to the gap with the most room left, then the loops of a gap are spread evenly *)
         Module[{cnt = ConstantArray[0, Length[gaps]]},
           Do[cnt[[First[Ordering[-Table[gaps[[q, 2]]/(cnt[[q]] + 1), {q, Length[gaps]}], 1]]]]++, {n}];
           angs = Flatten[Table[gaps[[q, 1]] + gaps[[q, 2]] t/(cnt[[q]] + 1), {q, Length[gaps]}, {t, cnt[[q]]}]]]];
       Do[selfDirs[loops[[q]]] = {Cos[angs[[q]]], Sin[angs[[q]]]}, {q, n}]]], {v, V}];
  (* multi-edges between the same pair are drawn as arcs *)
  Do[With[{m = Length[grp]},
      Do[Module[{e = edges[[grp[[r]]]], a, b, mid, nrm, off, ctrl, i, p = fam["Propagators"][[edges[[grp[[r]], 3]]]], sw, dash, tick},
          i = e[[3]]; a = P[e[[1]]]; b = P[e[[2]]];
          sw = Which[p["Type"] === "Linear", "1.6", TrueQ[p["Mass2"] == 0], "1.4", True, "3.6"];
          dash = If[p["Type"] === "Linear", " stroke-dasharray='6 3'", ""];
          If[e[[1]] === e[[2]],
            (* self-loop: a circle touching the vertex *)
            Module[{dir = selfDirs[grp[[r]]], c, rad = If[m > 2, 18, 24]},
              c = a + rad dir;
              AppendTo[out, "<circle cx='" <> num[c[[1]]] <> "' cy='" <> num[c[[2]]] <> "' r='" <> num[rad] <> "' fill='none' stroke='currentColor' stroke-width='" <> sw <> "'" <> dash <> "/>"];
              mid = c + rad dir; nrm = dir],
            off = (r - (m + 1)/2) 34;
            (* one orientation for the whole group, so that the arcs of a multi-edge do not coincide *)
            nrm = With[{pa = P[Min[e[[1 ;; 2]]]], pb = P[Max[e[[1 ;; 2]]]]}, Normalize[{-(pb - pa)[[2]], (pb - pa)[[1]]}]];
            ctrl = (a + b)/2 + 2 off nrm;
            mid = (a + b)/2 + off nrm;
            drawn = Join[drawn, If[off == 0, {{a, b}}, {{a, mid}, {mid, b}}]];
            AppendTo[out, "<path d='M " <> num[a[[1]]] <> " " <> num[a[[2]]] <> If[off == 0, " L ", " Q " <> num[ctrl[[1]]] <> " " <> num[ctrl[[2]]] <> " "] <>
              num[b[[1]]] <> " " <> num[b[[2]]] <> "' fill='none' stroke='currentColor' stroke-width='" <> sw <> "'" <> dash <> "/>"];
            If[p["Type"] === "Linear",
              AppendTo[out, "<path d='M " <> num[a[[1]] + 3 nrm[[1]]] <> " " <> num[a[[2]] + 3 nrm[[2]]] <> If[off == 0, " L ", " Q " <> num[ctrl[[1]] + 3 nrm[[1]]] <> " " <> num[ctrl[[2]] + 3 nrm[[2]]] <> " "] <>
                num[b[[1]] + 3 nrm[[1]]] <> " " <> num[b[[2]] + 3 nrm[[2]]] <> "' fill='none' stroke='currentColor' stroke-width='1.2'" <> dash <> "/>"]];
            (* the outer arcs of a group carry their label outside *)
            If[off < 0, nrm = -nrm]];
          (* cut mark *)
          tick = Normalize[nrm] 7;
          AppendTo[out, "<line x1='" <> num[mid[[1]] - tick[[2]] - tick[[1]]] <> "' y1='" <> num[mid[[2]] + tick[[1]] - tick[[2]]] <> "' x2='" <> num[mid[[1]] + tick[[2]] + tick[[1]]] <> "' y2='" <>
            num[mid[[2]] - tick[[1]] + tick[[2]]] <> "' stroke='#d33' stroke-width='2'/>"];
          AppendTo[labs, {mid + 14 Normalize[nrm], Normalize[nrm], ToString[i]}]],
        {r, m}]], {grp, groups}];
  Do[With[{a = P[legs[[k, 1]]], lp = P[V + k]},
      legEnd = a + 0.8 (lp - a); AppendTo[drawn, {a, legEnd}];
      AppendTo[out, "<line x1='" <> num[a[[1]]] <> "' y1='" <> num[a[[2]]] <> "' x2='" <> num[legEnd[[1]]] <> "' y2='" <> num[legEnd[[2]]] <> "' stroke='currentColor' stroke-width='1.2'/>"];
      AppendTo[out, "<text x='" <> num[lp[[1]]] <> "' y='" <> num[lp[[2]] + 4] <> "' font-size='11' text-anchor='middle' fill='currentColor'>" <> esc[ToString[legs[[k, 2]], InputForm]] <> "</text>"]],
    {k, Length[legs]}];
  (* line labels: pushed outwards until they are clear of each other, of the vertices and of the leg labels *)
  fixed = Join[Table[P[k], {k, V}], Table[P[V + k], {k, Length[legs]}]];
  Do[Do[With[{pi = labs[[q, 1]]},
       If[AnyTrue[Join[Delete[labs[[All, 1]], q], fixed], Norm[# - pi] < 15 &] || AnyTrue[drawn, segDist[pi, #] < 8 &], labs[[q, 1]] = pi + 3 labs[[q, 2]]]],
       {q, Length[labs]}], {iter, 20}];
  Do[AppendTo[out, "<text x='" <> num[l[[1, 1]]] <> "' y='" <> num[l[[1, 2]] + 4] <> "' font-size='11' text-anchor='middle' fill='currentColor'>" <> l[[3]] <> "</text>"], {l, labs}];
  Do[With[{a = P[k]}, AppendTo[out, "<circle cx='" <> num[a[[1]]] <> "' cy='" <> num[a[[2]]] <> "' r='3' fill='currentColor'/>"]], {k, V}];
  msg = g["message"]; line2 = "red ticks: cut lines";
  StringJoin["<svg xmlns='http://www.w3.org/2000/svg' width='", ToString[W], "' height='", ToString[H], "' viewBox='0 0 ", ToString[W], " ", ToString[H], "' class='topology'>",
    "<title>", esc[SectorName[s]], "</title>", out,
    If[StringLength[msg] + StringLength[line2] > 62,
      {"<text x='6' y='", ToString[H - 18], "' font-size='10' fill='currentColor' opacity='0.6'>", esc[msg], "</text>",
       "<text x='6' y='", ToString[H - 6], "' font-size='10' fill='currentColor' opacity='0.6'>", line2, "</text>"},
      {"<text x='6' y='", ToString[H - 6], "' font-size='10' fill='currentColor' opacity='0.6'>", esc[msg], "; ", line2, "</text>"}], "</svg>"]];

MCBDrawSector[fam_Association, s_List, file_String] := Module[{svg},
  If[MCBSkippedQ["draw"], Return[Missing["Skipped"]]];
  svg = Quiet@Check[MCBGraphSVG[fam, s], $Failed];
  If[! StringQ[svg], Return[$Failed]];
  Export[file, svg, "Text"];
  file];


End[];
EndPackage[];
