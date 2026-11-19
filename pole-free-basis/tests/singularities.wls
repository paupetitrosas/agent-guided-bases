#!/usr/bin/env wolframscript
(* Known singularities of a family (bin/singularities.wls, SOFIA) without SOFIA. Planted data: the graphs of the
   maximal-cut-basis example families (from their "Graph" field, and from momentum conservation for the double box),
   a planted one-loop box whose invariants carry SOFIA's own names with other meanings (s12, s23, mm1, mm2: SOFIA's s12
   is this family's s23 and its mm1 this family's mm2), planted SOFIA output and kinematics to rename and check, and a
   planted stand-in for SOFIA's scr.m that returns known polynomials, prints a warning and records how it was called.
   Checked: graph extraction, renaming, the kinematics check, the cache and its provenance, the isolation of SOFIA's
   symbols, PFBKnownSingularities (images, letters, stale caches), the letters on offer and the user's key
   "LettersFromSOFIA" (validation, PFBLetters, the gate's letter check), and what happens without SOFIA.
   No IBP reduction, no FiniteFlow, no SOFIA.
   usage: bin/ws tests/singularities.wls        exit code 0 when every test passes *)
Get[FileNameJoin[{ParentDirectory[DirectoryName[$InputFileName]], "lib", "PoleFreeBasis.wl"}]];
$PFBVerbose = False;
SetEnvironment["MCB_SOFIA" -> None];
ex = FileNameJoin[{ParentDirectory[ParentDirectory[DirectoryName[$InputFileName]]], "maximal-cut-basis", "examples"}];
famOf[name_] := MCBReadFamily[FileNameJoin[{ex, name, "family.wl"}]];
tmp = CreateDirectory[];
v[n_] := PFBSOFIAVar[n];
(* the same polynomials up to a sign each *)
sameUpToSign[a_List, b_List] := Length[a] == Length[b] && AllTrue[a, Function[x, Count[b, y_ /; Expand[x - y] === 0 || Expand[x + y] === 0] == 1]];
write[file_, text_] := (Export[file, text, "Text"]; file);

(* the planted box: legs 1 and 4 of mass^2 M2, lines 1 and 2 of mass^2 mm2, line 4 of mass^2 mm1, invariants named s12 =
   (p1+p2)^2 and s23 = (p2+p3)^2. SOFIA numbers the legs from the vertex where line 4 enters line 1: its s12 is this
   family's s23, its s23 this family's s12, its first internal mass this family's mm2 *)
boxcText[d3_] := "<|\"Name\" -> \"boxc\", \"LoopMomenta\" -> {k}, \"ExternalMomenta\" -> {p1, p2, p3},
 \"ScalarProducts\" -> {p1^2 -> M2, p2^2 -> 0, p3^2 -> 0, p1 p2 -> (s12 - M2)/2, p2 p3 -> s23/2, p1 p3 -> (M2 - s12 - s23)/2},
 \"Propagators\" -> {<|\"Type\" -> \"Quadratic\", \"Momentum\" -> k, \"Mass2\" -> mm2|>, <|\"Type\" -> \"Quadratic\", \"Momentum\" -> k + p1, \"Mass2\" -> mm2|>,
   <|\"Type\" -> \"Quadratic\", \"Momentum\" -> k + p1 + p2, \"Mass2\" -> " <> d3 <> "|>, <|\"Type\" -> \"Quadratic\", \"Momentum\" -> k + p1 + p2 + p3, \"Mass2\" -> mm1|>},
 \"Invariants\" -> <|s12 -> 2, s23 -> 2, M2 -> 2, mm1 -> 2, mm2 -> 2|>, \"UnitScale\" -> s12, \"D0\" -> 4,
 \"Graph\" -> {{1, 2, 1}, {2, 3, 2}, {3, 4, 3}, {4, 1, 4}, {1, p4}, {2, p1}, {3, p2}, {4, p3}}|>";
boxcFile = write[FileNameJoin[{tmp, "boxc.wl"}], boxcText["0"]];
boxcFam = MCBReadFamily[boxcFile];
write[FileNameJoin[{tmp, "boxc_masters.m"}], "{j[boxc, 1, 0, 1, 0], j[boxc, 0, 1, 0, 1], j[boxc, 1, 1, 1, 1]}"];
systemText[extra_String, sysExtra_String] := "<|\"Name\" -> \"planted\", \"Families\" -> {<|\"Name\" -> \"boxc\", \"Family\" -> \"boxc.wl\", \"Masters\" -> \"boxc_masters.m\"" <> extra <> "|>}" <> sysExtra <> "|>";
sysFile = write[FileNameJoin[{tmp, "system.wl"}], systemText["", ""]];
sys = PFBReadSystem[sysFile];

(* a planted stand-in for SOFIA's scr.m: SOFIA's public symbols, its renaming homogeneizeKin, its kinematics for four legs
   in MySubstitutions (p_i.p_j = (s_ij - M_i^2 - M_j^2)/2, s34 = s12, s14 = s23, s13 = s24 = Sum M_i^2 - s12 - s23), a
   warning in SOFIA's words, and planted polynomials *)
sofiaDir = CreateDirectory[FileNameJoin[{tmp, "sofia"}]];
fake = write[FileNameJoin[{sofiaDir, "scr.m"}], "BeginPackage[\"SOFIA`\"]
SOFIA::usage = \"planted stand-in\"; MySubstitutions::usage = \"\"; homogeneizeKin::usage = \"\"; lastCall::usage = \"\";
s::usage = \"\"; t::usage = \"\"; m::usage = \"\"; M::usage = \"\"; mm::usage = \"\"; MM::usage = \"\"; p::usage = \"\";
IncludeSubtopologies::usage = \"\"; SolverBound::usage = \"\"; Substitutions::usage = \"\";
Begin[\"`Private`\"]
Print[\"Singularities of Feynman Integrals Automatized (v0.9.9.)\"];
homogeneizeKin[arg_] := arg //. Subscript[s, a___] :> ToExpression[\"s\" <> StringJoin[ToString /@ {a}]] //. Subscript[M, i_] :> Sqrt[ToExpression[\"MM\" <> ToString[i]]] //. Subscript[m, i_] :> Sqrt[ToExpression[\"mm\" <> ToString[i]]];
Options[SOFIA] = {IncludeSubtopologies -> True, SolverBound -> 100, Substitutions -> {}};
SOFIA[{edges_, nodes_}, opts : OptionsPattern[]] := Module[{m2 = nodes[[All, 2]]^2, sv},
  lastCall = {{edges, nodes}, {opts}};
  sv[i_, j_] := Which[MemberQ[{{1, 2}, {3, 4}}, Sort[{i, j}]], Subscript[s, 1, 2], MemberQ[{{2, 3}, {1, 4}}, Sort[{i, j}]], Subscript[s, 2, 3], True, Total[m2] - Subscript[s, 1, 2] - Subscript[s, 2, 3]];
  MySubstitutions = Flatten[Table[CenterDot[Subscript[p, i], Subscript[p, j]] -> If[i == j, m2[[i]], (sv[i, j] - m2[[i]] - m2[[j]])/2], {i, 4}, {j, 4}]];
  Print[Style[\"The maximal cut integration contour of this diagram may be degenerate (a planted warning).\", Bold, Orange]];
  homogeneizeKin[{Subscript[s, 1, 2] Subscript[s, 2, 3] - Subscript[M, 1]^2 Subscript[m, 2]^2, Subscript[m, 1]^2, Subscript[s, 2, 3] - 4 Subscript[m, 1]^2,
    (Subscript[M, 1]^2 - Subscript[m, 1]^2 - Subscript[m, 2]^2)^2 - 4 Subscript[m, 1]^2 Subscript[m, 2]^2, 2 Subscript[s, 1, 2]}]];
End[]
EndPackage[]
"];
loader = write[FileNameJoin[{sofiaDir, "SOFIA.m"}], "If[! ValueQ[SOFIAoptionJulia], SOFIAoptionJulia = False];\nSetDirectory[NotebookDirectory[]]\nGet[\"https://raw.githubusercontent.com/StrangeQuark007/SOFIA/main/scr.m\"]\n"];
other = write[FileNameJoin[{sofiaDir, "other.m"}], "x = 1;\n"];
(* what the planted SOFIA returns for boxc, in boxc's invariants *)
boxcExpected = {mm2, s23, s12 - 4 mm2, s12 s23 - M2 mm1, (M2 - mm1 - mm2)^2 - 4 mm1 mm2};
runDir = CreateDirectory[FileNameJoin[{tmp, "run"}]];
(* two top graphs: the masters of two triangles, neither inside the other *)
write[FileNameJoin[{tmp, "two.m"}], "{j[boxc, 1, 0, 1, 0], j[boxc, 1, 1, 1, 0], j[boxc, 0, 1, 1, 1]}"];
twoFile = write[FileNameJoin[{tmp, "two.wl"}], "<|\"Name\" -> \"two\", \"Families\" -> {<|\"Name\" -> \"boxc\", \"Family\" -> \"boxc.wl\", \"Masters\" -> \"two.m\"|>}|>"];
ctx = <|"System" -> sys, "Dir" -> runDir|>;

tests = {
  (* graph extraction: the example families' "Graph" fields *)
  VerificationTest[With[{g = PFBSOFIAGraph[famOf["box-one-loop"], {1, 1, 1, 1}]}, Lookup[g, {"OK", "Edges", "Nodes", "Lines", "Momenta", "Loops", "Input"}]],
    {True, {{{1, 2}, 0}, {{2, 3}, 0}, {{3, 4}, 0}, {{1, 4}, 0}}, {{1, 0}, {2, 0}, {3, 0}, {4, 0}}, {1, 2, 3, 4}, {-p1 - p2 - p3, p1, p2, p3}, 1,
      "{{{{1, 2}, 0}, {{2, 3}, 0}, {{3, 4}, 0}, {{1, 4}, 0}}, {{1, 0}, {2, 0}, {3, 0}, {4, 0}}}"},
    TestID -> "graph: the massless box, legs from the vertices"],
  VerificationTest[With[{f = famOf["box-one-loop"]}, With[{g = PFBSOFIAGraph[f, {1, 1, 1, 1}]}, PFBSOFIARename[f, g, #] & /@ {"s12", "s23", "s13", "MM1", "s", "s15"}]],
    {t, s, -s - t, Missing["Unknown", "MM1"], Missing["Unknown", "s"], Missing["Unknown", "s15"]}, TestID -> "rename: the massless box, s12 -> t, s23 -> s"],
  VerificationTest[With[{f = famOf["bubble-massive"]}, With[{g = PFBSOFIAGraph[f, {1, 1}]},
      {Lookup[g, {"Edges", "Nodes", "Masses", "ExternalMasses", "Input"}], PFBSOFIARename[f, g, #] & /@ {"s", "mm1", "MM1"}}]],
    {{{{{1, 2}, "m1"}, {{1, 2}, "m1"}}, {{1, "M1"}, {2, "M1"}}, <|"m1" -> m2|>, <|"M1" -> s|>,
      "{{{{1, 2}, Subscript[m, 1]}, {{1, 2}, Subscript[m, 1]}}, {{1, Subscript[M, 1]}, {2, Subscript[M, 1]}}}"}, {s, m2, s}},
    TestID -> "graph and rename: the massive bubble (two legs: SOFIA's s is p^2)"],
  VerificationTest[Lookup[PFBSOFIAGraph[famOf["sunrise-equal-mass"], {1, 1, 1, 0, 0}], {"Edges", "Nodes", "Loops", "ExternalMasses"}],
    {{{{1, 2}, "m1"}, {{1, 2}, "m1"}, {{1, 2}, "m1"}}, {{1, "M1"}, {2, "M1"}}, 2, <|"M1" -> s|>}, TestID -> "graph: the sunrise"],
  VerificationTest[Lookup[PFBSOFIAGraph[famOf["banana-three-loop"], {1, 1, 1, 1, 0, 0, 0, 0, 0}], {"OK", "Loops", "Nodes", "Masses"}],
    {True, 3, {{1, "M1"}, {2, "M1"}}, <|"m1" -> m2|>}, TestID -> "graph: the three-loop banana"],
  (* the double box has no "Graph": momentum conservation gives it; the legs come first *)
  VerificationTest[With[{f = famOf["doublebox-massless"]}, With[{g = PFBSOFIAGraph[f, {1, 1, 1, 1, 1, 1, 1, 0, 0}]},
      {g["OK"], Length[g["Edges"]], Union[g["Edges"][[All, 2]]], g["Nodes"], g["Loops"], Max[Flatten[g["Edges"][[All, 1]]]], StringContainsQ[g["Source"], "momentum conservation"],
       Sort[Expand[PFBSOFIARename[f, g, #] & /@ {"s12", "s23", "s13"}]], Expand[Total[g["Momenta"]]]}]],
    {True, 7, {0}, {{1, 0}, {2, 0}, {3, 0}, {4, 0}}, 2, 6, True, Sort[{s, t, -s - t}], 0}, TestID -> "graph: the double box from momentum conservation"],
  VerificationTest[With[{f = MCBReadFamily[<|"Name" -> "lin", "LoopMomenta" -> {k}, "ExternalMomenta" -> {p, n},
       "ScalarProducts" -> {p^2 -> s, n^2 -> 0, p n -> w},
       "Propagators" -> {<|"Momentum" -> k|>, <|"Momentum" -> k + p|>, <|"Type" -> "Linear", "Momentum" -> k, "Vector" -> n|>},
       "Invariants" -> <|s -> 2, w -> 2|>, "Graph" -> {{1, 2, 1}, {2, 1, 2}, {1, 1, 3}, {1, p}, {2, p}}|>]},
      Lookup[PFBSOFIAGraph[f, {1, 1, 1}], {"OK", "Message"}]], {False, "SOFIA takes quadratic propagators only; lines {3} are linear"},
    TestID -> "graph: linear propagators are refused"],
  VerificationTest[With[{f = MCBReadFamily[<|"Name" -> "tad", "LoopMomenta" -> {k}, "ExternalMomenta" -> {}, "Propagators" -> {<|"Momentum" -> k, "Mass2" -> m2|>},
       "Invariants" -> <|m2 -> 2|>, "Graph" -> {{1, 1, 1}}|>]}, {PFBSOFIAGraph[f, {1}]["OK"], StringContainsQ[PFBSOFIAGraph[f, {1}]["Message"], "vacuum"]}],
    {False, True}, TestID -> "graph: a vacuum graph is refused"],
  (* the planted box: SOFIA's names mean other invariants of this family *)
  VerificationTest[With[{g = PFBSOFIAGraph[boxcFam, {1, 1, 1, 1}]}, {Lookup[g, {"Edges", "Nodes", "Masses", "ExternalMasses"}],
      PFBSOFIARename[boxcFam, g, #] & /@ {"s12", "s23", "MM1", "mm1", "mm2"}}],
    {{{{{1, 2}, "m1"}, {{2, 3}, "m1"}, {{3, 4}, 0}, {{1, 4}, "m2"}}, {{1, "M1"}, {2, "M1"}, {3, 0}, {4, 0}}, <|"m1" -> mm2, "m2" -> mm1|>, <|"M1" -> M2|>},
     {s23, s12, M2, mm2, mm1}}, TestID -> "graph and rename: SOFIA's names are not the family's"],
  VerificationTest[With[{g = PFBSOFIAGraph[boxcFam, {1, 1, 1, 0}]}, {g["OK"], Length[g["Edges"]], Count[g["Nodes"][[All, 2]], 0], Sort[Values[g["ExternalMasses"]]],
      Sort[PFBSOFIARename[boxcFam, g, "M" <> #] & /@ Keys[g["ExternalMasses"]]]}],
    {True, 3, 1, Sort[{M2, s12}], Sort[{M2, s12}]}, TestID -> "graph: a subsector, legs merged by the contraction"],
  VerificationTest[With[{r = PFBSOFIARename[boxcFam, PFBSOFIAGraph[boxcFam, {1, 1, 1, 1}], {v["s12"] v["s23"] - v["MM1"] v["mm2"], v["mm1"], v["s23"] - 4 v["mm1"],
       (v["MM1"] - v["mm1"] - v["mm2"])^2 - 4 v["mm1"] v["mm2"], 2 v["s12"], v["s12"] + v["s23"] + v["s13"] - 2 v["MM1"], v["x7"] + v["s12"]}]},
      {sameUpToSign[r["Polynomials"], boxcExpected], r["Vanishing"], Length[r["Unrenamed"]], StringContainsQ[r["Unrenamed"][[1, "Reason"]], "x7"],
       Expand[Lookup[Association[r["Rules"]], {"MM1", "mm1", "s12", "s13"}]]}],
    {True, {"-2*MM1 + s12 + s13 + s23"}, 1, True, {M2, mm2, s23, 2 M2 - s12 - s23}}, TestID -> "rename: planted SOFIA output, a polynomial that vanishes, an unknown name"],
  (* SOFIA's kinematics, read back and renamed, must be the family's *)
  VerificationTest[With[{g = PFBSOFIAGraph[boxcFam, {1, 1, 1, 1}], subs = {{1, 1} -> v["MM1"], {2, 2} -> v["MM1"], {3, 3} -> 0, {4, 4} -> 0,
       {1, 2} -> (v["s12"] - 2 v["MM1"])/2, {2, 3} -> (v["s23"] - v["MM1"])/2, {3, 4} -> v["s12"]/2, {1, 4} -> (v["s23"] - v["MM1"])/2,
       {1, 3} -> (v["MM1"] - v["s12"] - v["s23"])/2, {2, 4} -> (v["MM1"] - v["s12"] - v["s23"])/2}},
      {PFBSOFIAKinematicsCheck[boxcFam, g, subs], PFBSOFIAKinematicsCheck[boxcFam, g, ReplacePart[subs, 5 -> ({1, 2} -> (v["s23"] - 2 v["MM1"])/2)]][[All, 1]]}],
    {{}, {{1, 2}}}, TestID -> "kinematics check: SOFIA's p_i.p_j agree, and a swapped invariant is caught"],
  VerificationTest[PFBNormalizePolynomials[{2 s t, -(s - 4 m2), s^2 (s - 4 m2), 3}, {s, t, m2}], {s, t, s - 4 m2}, TestID -> "normalisation: irreducible, primitive, up to sign"],
  (* the tool: scr.m only, never the network loader *)
  VerificationTest[With[{i = PFBSOFIAInfo[fake]}, {i["OK"], i["Version"], i["Pinned"], MissingQ[i["Commit"]], StringLength[i["SHA256"]]}], {True, "0.9.9", False, True, 64},
    TestID -> "tool: a scr.m is accepted, with its version and hash"],
  VerificationTest[{PFBSOFIAInfo[loader]["OK"], StringContainsQ[PFBSOFIAInfo[loader]["Message"], "loader"], PFBSOFIAInfo[other]["OK"],
      StringContainsQ[PFBSOFIAInfo[FileNameJoin[{tmp, "none.m"}]]["Message"], "does not exist"]}, {False, True, False, True},
    TestID -> "tool: the loader SOFIA.m, another file and a missing file are refused"],
  VerificationTest[{Block[{$MCBPaths = <|"SOFIA" -> fake|>}, PFBSOFIAPath[]], Block[{$MCBPaths = <||>}, {PFBSOFIAPath[], PFBSOFIALine[]["Status"]}],
      Block[{$MCBPaths = <|"SOFIA" -> loader|>}, PFBSOFIALine[]["Status"]]}, {fake, {Missing["NotConfigured"], "not configured"}, "refused"},
    TestID -> "tool: paths.wl \"SOFIA\", and the preflight's line"],
  (* without SOFIA the step says so and writes nothing *)
  VerificationTest[With[{r = Block[{$MCBPaths = <||>}, PFBRunSingularities[ctx]]}, {r["Status"], StringContainsQ[r["Message"], {"not configured", "paths.wl"}], DirectoryQ[FileNameJoin[{runDir, "singularities"}]]}],
    {"skipped", True, False}, TestID -> "without SOFIA: skipped, nothing written"],
  VerificationTest[Lookup[PFBRunSingularities[ctx, All, <|"SOFIA" -> loader|>], {"Status"}], {"refused"}, TestID -> "the loader is refused by the run too"],
  VerificationTest[With[{k = PFBKnownSingularities[sys, runDir, "boxc"]}, Lookup[k, {"SOFIAStatus", "SOFIA", "Known", "Letters", "Offer"}]], {"not run", {}, {}, {}, False},
    TestID -> "known singularities before any run"],
  VerificationTest[{PFBSingularityGraphs[sys, "boxc"], PFBSingularityGraphs[PFBReadSystem[twoFile], "boxc"]},
    {{{1, 1, 1, 1}}, {{0, 1, 1, 1}, {1, 1, 1, 0}}}, TestID -> "top graphs: the maximal sectors of the family's masters"]
};

(* the run, with the planted SOFIA *)
res1 = PFBRunSingularities[ctx, All, <|"SOFIA" -> fake|>];
cache = PFBReadSingularities[runDir, "boxc"];
AppendTo[tests, VerificationTest[{res1["Status"], cache["Status"], sameUpToSign[cache["Polynomials"], boxcExpected], cache["Graphs"][[1, "KinematicsCheck"]],
    cache["Graphs"][[1, "Status"]], cache["Graphs"][[1, "Raw"]][[1]]},
  {"done", "done", True, "agrees", "done", "-(MM1*mm2) + s12*s23"}, TestID -> "run: the planted SOFIA's polynomials, renamed into the family's invariants"]];
AppendTo[tests, VerificationTest[{cache["Options"], Symbol["SOFIA`lastCall"][[2]],
    Symbol["SOFIA`lastCall"][[1]] === {{{{1, 2}, Subscript[Symbol["SOFIA`m"], 1]}, {{2, 3}, Subscript[Symbol["SOFIA`m"], 1]}, {{3, 4}, 0}, {{1, 4}, Subscript[Symbol["SOFIA`m"], 2]}},
      {{1, Subscript[Symbol["SOFIA`M"], 1]}, {2, Subscript[Symbol["SOFIA`M"], 1]}, {3, 0}, {4, 0}}}},
  {{"IncludeSubtopologies -> True", "SolverBound -> Infinity", "Substitutions -> {}"},
   {Symbol["SOFIA`IncludeSubtopologies"] -> True, Symbol["SOFIA`SolverBound"] -> Infinity, Symbol["SOFIA`Substitutions"] -> {}}, True},
  TestID -> "run: SOFIA gets subtopologies, no solver bound, no substitutions, and the graph in its symbols"]];
AppendTo[tests, VerificationTest[{cache["SOFIA"]["SHA256"] === PFBSOFIAInfo[fake]["SHA256"], cache["SOFIA"]["Version"], AnyTrue[cache["Warnings"], StringContainsQ[#, "planted warning"] &],
    StringContainsQ[Import[FileNameJoin[{runDir, cache["Log"]}], "Text"], "planted warning"], NumericQ[cache["Graphs"][[1, "Seconds"]]], cache["Graphs"][[1, "Input"]]},
  {True, "0.9.9", True, True, True, "{{{{1, 2}, Subscript[m, 1]}, {{2, 3}, Subscript[m, 1]}, {{3, 4}, 0}, {{1, 4}, Subscript[m, 2]}}, {{1, Subscript[M, 1]}, {2, Subscript[M, 1]}, {3, 0}, {4, 0}}}"},
  TestID -> "run: provenance, the warning and the log"]];
(* SOFIA's symbols stay in their contexts: its run-time names (s12, MM1) never reach Global`, its one-letter symbols never
   shadow the family's *)
AppendTo[tests, VerificationTest[{MemberQ[$Packages, "SOFIA`"], MemberQ[$ContextPath, "SOFIA`"], Context[Evaluate[ToExpression["s"]]], Context[s12], Names["Global`MM1"], Names["Global`x1"],
    ListQ[cache["Polynomials"]] && FreeQ[cache["Polynomials"], x_Symbol /; ! MemberQ[{"Global`", "System`"}, Context[x]]]},
  {True, False, "Global`", "Global`", {}, {}, True}, TestID -> "run: SOFIA's symbols never meet the family's"]];
AppendTo[tests, VerificationTest[{TrueQ[PFBRunSingularities[ctx, {"boxc"}, <|"SOFIA" -> fake|>]["Families"][boxc]["Reused"]],
    TrueQ[PFBRunSingularities[ctx, {"boxc"}, <|"SOFIA" -> fake, "Force" -> True|>]["Families"][boxc]["Reused"]]}, {True, False},
  TestID -> "run: an unchanged cache is kept, Force recomputes"]];

(* the letters on offer: the family has none, SOFIA's polynomials wait for the user's yes *)
k0 = PFBKnownSingularities[ctx, "boxc"];
AppendTo[tests, VerificationTest[{Lookup[k0, {"SOFIAStatus", "Offer", "Accepted", "Letters"}], sameUpToSign[k0["Known"], boxcExpected], k0["SOFIA"] === k0["Known"], Union[k0["Sources"]],
    k0["Provenance"]["Graphs"], Length[PFBSingularityOffers[sys, runDir]], StringContainsQ[PFBSingularityOffers[sys, runDir][[1, "Message"]], "\"LettersFromSOFIA\" -> True"],
    AnyTrue[PFBValidateSystem[sys, runDir]["Questions"], StringContainsQ[#, "LettersFromSOFIA"] &], PFBValidateSystem[sys]["Questions"]},
  {{"done", True, False, {}}, True, True, {{"SOFIA"}}, {{"j1111", "done"}}, 1, True, True, {}}, TestID -> "offer: no letters, SOFIA's list waits for the user"]];
AppendTo[tests, VerificationTest[{PFBLetters[PFBAttachSOFIALetters[sys, runDir]], PFBRuleViolations[PFBAttachSOFIALetters[sys, runDir], j[boxc, 1, 1, 1, 1]/(s12 + mm1)]},
  {{}, {}}, TestID -> "offer: not letters before the user's yes (no letter check)"]];
(* the user's yes *)
write[sysFile, systemText[", \"LettersFromSOFIA\" -> True", ""]];
sysA = PFBAttachSOFIALetters[PFBReadSystem[sysFile], runDir];
kA = PFBKnownSingularities[sysA, runDir, "boxc"];
AppendTo[tests, VerificationTest[{Lookup[kA, {"Accepted", "Offer"}], sameUpToSign[kA["Letters"], boxcExpected], sameUpToSign[PFBLetters[sysA], boxcExpected],
    PFBSingularityOffers[sysA, runDir], PFBValidateSystem[sysA, runDir]["Questions"], PFBValidateSystem[sysA, runDir]["Errors"]},
  {{True, False}, True, True, {}, {}, {}}, TestID -> "accepted: \"LettersFromSOFIA\" -> True makes them letters"]];
AppendTo[tests, VerificationTest[{PFBRuleViolations[sysA, j[boxc, 1, 1, 1, 1]/(s12 - 4 mm2)], StringStartsQ[First[PFBRuleViolations[sysA, j[boxc, 1, 1, 1, 1]/(s12 + mm1)], ""], "letters"]},
  {{}, True}, TestID -> "accepted: the gate's letter check uses them"]];
(* PFBStartRun attaches them, and PFBKnownSingularities takes its context *)
pathsFile = write[FileNameJoin[{tmp, "paths.wl"}], ToString[Join[Association[(# -> "/nonexistent/" <> #) & /@ Keys[$MCBTools]], <|"SOFIA" -> fake|>], InputForm]];
runFile = write[FileNameJoin[{tmp, "run.wl"}], "<|\"System\" -> \"system.wl\", \"OutputDir\" -> " <> ToString[runDir, InputForm] <> ", \"AllowTmp\" -> True, \"Paths\" -> \"paths.wl\"|>"];
st = PFBStartRun[runFile];
AppendTo[tests, VerificationTest[{Keys[st["System"]["SOFIALetters"]], sameUpToSign[PFBLetters[st["System"]], boxcExpected], PFBKnownSingularities[st, "boxc"]["Accepted"], PFBSOFIAPath[] === fake},
  {{boxc}, True, True, True}, TestID -> "PFBStartRun attaches the accepted letters"]];
(* the family's own letters (here system.wl's) come with SOFIA's: no offer, and the sources say which is which *)
write[sysFile, systemText["", ", \"Letters\" -> {s12, s23, mm1 + mm2}"]];
kL = PFBKnownSingularities[PFBReadSystem[sysFile], runDir, "boxc"];
AppendTo[tests, VerificationTest[{kL["Offer"], kL["Letters"], Length[kL["Known"]], kL["Sources"][[Flatten[Position[kL["Known"], s23, {1}]]]], kL["Sources"][[Flatten[Position[kL["Known"], mm1 + mm2, {1}]]]]},
  {False, {s12, s23, mm1 + mm2}, 7, {{"Letters", "SOFIA"}}, {{"Letters"}}}, TestID -> "letters given: known = letters together with SOFIA's list"]];
(* the key: True or False, on a base family; set without a cache it warns *)
write[sysFile, systemText[", \"LettersFromSOFIA\" -> \"yes\"", ""]];
AppendTo[tests, VerificationTest[AnyTrue[PFBValidateSystem[PFBReadSystem[sysFile]]["Errors"], StringContainsQ[#, "must be True or False"] &], True, TestID -> "key: not a boolean"]];
write[sysFile, "<|\"Name\" -> \"planted\", \"Families\" -> {<|\"Name\" -> \"boxc\", \"Family\" -> \"boxc.wl\", \"Masters\" -> \"boxc_masters.m\"|>, " <>
  "<|\"Name\" -> \"boxcx\", \"ImageOf\" -> \"boxc\", \"MomentumMap\" -> {p2 -> p3, p3 -> p2}, \"LettersFromSOFIA\" -> True|>}|>"];
AppendTo[tests, VerificationTest[AnyTrue[PFBValidateSystem[PFBReadSystem[sysFile]]["Errors"], StringContainsQ[#, "belongs on the base family boxc"] &], True, TestID -> "key: not on an image"]];
write[sysFile, systemText[", \"LettersFromSOFIA\" -> True", ""]];
emptyRun = CreateDirectory[FileNameJoin[{tmp, "empty"}]];
AppendTo[tests, VerificationTest[{PFBAttachSOFIALetters[PFBReadSystem[sysFile], emptyRun]["SOFIALettersMissing"],
    AnyTrue[PFBValidateSystem[PFBReadSystem[sysFile], emptyRun]["Warnings"], StringContainsQ[#, "SOFIA cache is not run"] &]},
  {<|boxc -> "not run"|>, True}, TestID -> "key: set without a cache warns"]];
(* a changed family makes the cache stale: its polynomials are not used *)
write[boxcFile, boxcText["mm1"]];
kS = PFBKnownSingularities[PFBReadSystem[sysFile], runDir, "boxc"];
AppendTo[tests, VerificationTest[Lookup[kS, {"SOFIAStatus", "SOFIA", "Letters", "Offer"}], {"stale", {}, {}, False}, TestID -> "stale: a changed family ignores its old cache"]];
write[boxcFile, boxcText["0"]];

(* an image follows its base by the invariant map: the massless box, its image with p1 <-> p2 (t -> -s - t) *)
boxFam = FileNameJoin[{ex, "box-one-loop", "family.wl"}];
write[FileNameJoin[{tmp, "box_masters.m"}], "{j[box, 1, 0, 1, 0], j[box, 0, 1, 0, 1], j[box, 1, 1, 1, 1]}"];
sys2File = write[FileNameJoin[{tmp, "system2.wl"}], "<|\"Name\" -> \"images\", \"Families\" -> {<|\"Name\" -> \"box\", \"Family\" -> " <> ToString[boxFam, InputForm] <>
  ", \"Masters\" -> \"box_masters.m\"|>, <|\"Name\" -> \"boxx\", \"ImageOf\" -> \"box\", \"MomentumMap\" -> {p1 -> p2, p2 -> p1}|>}|>"];
sys2 = PFBReadSystem[sys2File];
run2 = CreateDirectory[FileNameJoin[{tmp, "run2"}]];
res2 = PFBRunSingularities[<|"System" -> sys2, "Dir" -> run2|>, {"boxx"}, <|"SOFIA" -> fake|>];
AppendTo[tests, VerificationTest[{Keys[res2["Families"]], PFBKnownSingularities[sys2, run2, "box"]["SOFIA"], PFBKnownSingularities[sys2, run2, "boxx"]["SOFIA"],
    Length[PFBReadSingularities[run2, "box"]["Graphs"][[1, "Unrenamed"]]], FileExistsQ[PFBSingularitiesFile[run2, "boxx"]]},
  {{box}, {t}, {s + t}, 4, False}, TestID -> "images: the base family runs, the image maps its list"]];


(* ---- the graph against the propagators (Symanzik polynomials), independent of SOFIA ---- *)
symOf[f_, sec_] := PFBSOFIASymanzikCheck[f, PFBSOFIAGraph[f, sec]];
symGood = {symOf[famOf["box-one-loop"], {1, 1, 1, 1}], symOf[famOf["bubble-massive"], {1, 1}], symOf[famOf["sunrise-equal-mass"], {1, 1, 1, 0, 0}],
   symOf[famOf["banana-three-loop"], {1, 1, 1, 1, 0, 0, 0, 0, 0}], symOf[famOf["doublebox-massless"], {1, 1, 1, 1, 1, 1, 1, 0, 0}], symOf[boxcFam, {1, 1, 1, 1}], symOf[boxcFam, {1, 1, 1, 0}]};
(* a box whose "Graph" puts lines 2 and 3 on each other's edges: momentum conservation then makes two of its legs
   massive (p1 + p2 and p2 + p3 enter there), and the graph is another routing of the same integral, with the same U and
   F. A graph record whose lines or masses do not match its edges is caught *)
swapFam = MCBReadFamily[Join[Get[FileNameJoin[{ex, "box-one-loop", "family.wl"}]], <|"Graph" -> {{1, 2, 1}, {2, 3, 3}, {3, 4, 2}, {4, 1, 4}, {1, p1}, {2, p2}, {3, p3}, {4, p4}}|>]];
swapGraph = PFBSOFIAGraph[swapFam, {1, 1, 1, 1}];
boxGraph = PFBSOFIAGraph[famOf["box-one-loop"], {1, 1, 1, 1}];
boxcGraph = PFBSOFIAGraph[boxcFam, {1, 1, 1, 1}];
badLines = PFBSOFIASymanzikCheck[famOf["box-one-loop"], Join[boxGraph, <|"Lines" -> {1, 3, 2, 4}|>]];
badMasses = PFBSOFIASymanzikCheck[boxcFam, Join[boxcGraph, <|"Masses" -> <|"m1" -> mm1, "m2" -> mm2|>|>]];
badMomenta = PFBSOFIASymanzikCheck[boxcFam, Join[boxcGraph, <|"Momenta" -> RotateLeft[boxcGraph["Momenta"]]|>]];
badLeg = PFBSOFIASymanzikCheck[boxcFam, Join[boxcGraph, <|"Nodes" -> ReplacePart[boxcGraph["Nodes"], {3, 2} -> "M1"]|>]];
AppendTo[tests, VerificationTest[{symGood, boxGraph["SymanzikCheck"]}, {ConstantArray["agrees", 7], "agrees"},
  TestID -> "Symanzik check: the example graphs (their \"Graph\", momentum conservation, masses) have the Symanzik polynomials of their propagators"]];
AppendTo[tests, VerificationTest[{swapGraph["OK"], swapGraph["SymanzikCheck"], swapGraph["Momenta"], StringTake[badLines, 9], StringTake[badMasses, 9], StringTake[badMomenta, 9]},
  {True, "agrees", {-p1 - p2 - p3, p1 + p2, -p2, p2 + p3}, "F differs", "F differs", "F differs"},
  TestID -> "Symanzik check: another routing of the same integral agrees; wrong lines, masses or momenta of a graph record are caught"]];
AppendTo[tests, VerificationTest[StringTake[badLeg, 9], "F differs", TestID -> "Symanzik check: a leg given to SOFIA with a wrong mass label is caught"]];

(* ---- a letter that is no rational function of the invariants ---- *)
write[FileNameJoin[{tmp, "alg_masters.m"}], "{j[box, 1, 0, 1, 0], j[box, 0, 1, 0, 1], j[box, 1, 1, 1, 1]}"];
algSysFile = write[FileNameJoin[{tmp, "alg.wl"}], "<|\"Name\" -> \"alg\", \"Families\" -> {<|\"Name\" -> \"box\", \"Family\" -> \"" <> FileNameJoin[{ex, "box-one-loop", "family.wl"}] <>
   "\", \"Masters\" -> \"alg_masters.m\"|>}, \"Letters\" -> {s, t, s + t, s + Sqrt[s^2 + 4 s t]}|>"];
algSys = PFBReadSystem[algSysFile];
algKnown = PFBKnownSingularities[algSys, None, box];
algProbes = PFBDegreeProbes[algSys, None, {box}];
algSpec = Block[{PFBPrint}, PFBDegreeSpec[<|"System" -> algSys, "Dir" -> None, "Run" -> <|"MaxEpsDegree" -> 2|>|>, {{box, {1, 1, 1, 1}}}, Automatic, {box}]];
AppendTo[tests, VerificationTest[{MemberQ[algKnown["Letters"], s + Sqrt[s (s + 4 t)]], algProbes["Probes"], algProbes["NonPolynomial"], algSpec["Probes"], algSpec["NonPolynomial"]},
  {True, {t, 1 + t}, {s + Sqrt[s (s + 4 t)]}, {t, 1 + t}, {s + Sqrt[s (s + 4 t)]}}, TestID -> "probes: a letter with a square root is no probe, and the degree job says so"]];

report = TestReport[tests];
Do[With[{r = report["TestResults"][id]},
    Print[If[r["Outcome"] === "Success", "PASS ", "FAIL "], r["TestID"], If[r["Outcome"] === "Success", "",
      "\n     got " <> ToString[Short[r["ActualOutput"], 5], InputForm] <> "\n     expected " <> ToString[Short[r["ExpectedOutput"], 5], InputForm]]]],
  {id, Keys[report["TestResults"]]}];
Print[report["TestsSucceededCount"], " passed, ", report["TestsFailedCount"], " failed, ", Round[report["TimeElapsed"], 0.1]];
DeleteDirectory[tmp, DeleteContents -> True];
Exit[If[report["AllTestsSucceeded"], 0, 1]];
