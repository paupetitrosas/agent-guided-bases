(* ::Package:: *)

(* ::Title:: *)
(*PoleFreeBasis`Kira`: Kira at the slice point of a subtree job*)


(* ::Text:: *)
(*Self-contained: bin/subtree.wls loads this file without the rest of the toolkit. The job writer (PFBSubtreeJob)*)
(*puts the uncut Kira configuration of the family into job.m, written by maximal-cut-basis (MCBToKiraYAML); the runner*)
(*writes the targets and the job file, runs Kira with the invariants fixed (--set_value) and d symbolic, and reads the*)
(*result back with these functions. Kira's masters are its own choice: the definitions of the system's masters are*)
(*reduced too, and every row is projected onto those masters (Kira's preferred_masters takes single integrals only,*)
(*while a master of the system is a combination of integrals with coefficients in eps and the invariants).*)
(*An image family is reduced as its base family at the image's mapped point: the image's propagators are the base's*)
(*with the momentum map applied, so j[image, a] at a point equals j[base, a] at the point whose invariants are those of*)
(*the invariant map there.*)


BeginPackage["PoleFreeBasis`Kira`"];

PFBReducerChoice::usage = "PFBReducerChoice[want, facts] decides which reducer reduces a job at its slice point. want: Automatic (Kira when it is available and applicable, else FiniteFlow), \"Kira\" or \"FiniteFlow\". facts (keys optional): \"KiraAvailable\" (Kira and Fermat found), \"Families\" (the families whose integrals the subtree holds: the roots' at writing time, the allowed sectors' when the job runs), \"KiraFamily\" (the family the job's Kira configuration describes), \"SymmetryRules\" (how many of the system's symmetry rules apply inside the subtree), \"LearnOnly\", \"Analytic\", \"Degrees\" (a degree or line job, job.m \"Degrees\" or \"Line\": it measures or samples FiniteFlow's learned system, so it is FiniteFlow's). Returns <|\"Reducer\" -> \"Kira\" | \"FiniteFlow\", \"Reason\", \"Requested\" -> want, \"Refused\" -> True when want is \"Kira\" and Kira does not apply|>.";
PFBKiraMappedPoint::usage = "PFBKiraMappedPoint[point, invariantMap] is the point at which the base family is reduced for an image family: every invariant X gets the value of (X /. invariantMap) at point. With an empty map it is the point itself.";
PFBKiraSeeds::usage = "PFBKiraSeeds[targets, roots, rank, dots] lists the sectors Kira reduces, {sector, r, s}: the roots and the sectors of the targets (index lists) that lie in no other of them, with r = the larger of the sector's lines plus dots and one more than the largest sum of positive indices of a target inside it, s = the larger of rank and one more than the largest numerator rank of such a target.";
PFBKiraJobYAML::usage = "PFBKiraJobYAML[family, seeds] is the text of Kira's job.yaml: reduce the sectors of PFBKiraSeeds, the integrals of the file target as mandatory, and write the result for Mathematica (kira2math).";
PFBKiraTargetText::usage = "PFBKiraTargetText[family, targets] is the text of Kira's target file, one integral family[a1,...,aN] per line, for index lists targets.";
PFBKiraSectorID::usage = "PFBKiraSectorID[sector] is Kira's id of a sector given as a 0/1 list: Sum s_i 2^(i-1).";
PFBKiraCommand::usage = "PFBKiraCommand[<|\"Kira\", \"Fermat\", \"Limit\", \"Threads\", \"TimeLimit\" (s, 0: none), \"MemoryGB\" (0: none; Automatic: the default of core/bin/limit), \"Values\" -> {kiraName -> value}|>] is the shell command that runs kira job.yaml in its folder under core/bin/limit, with FERMATPATH and --set_value for every invariant, writing kira.out.";
PFBKiraParse::usage = "PFBKiraParse[text, family, integral, dim] reads the text of Kira's results/<family>/kira_target.m: a list of rules integral -> combination, where integral[{a1, ..., aN}] makes the integral of family[a1, ..., aN] and Kira's d becomes dim. Parsed in a context of its own, so no symbol of the session is touched. $Failed when the text is not a list of rules.";
PFBKiraMasters::usage = "PFBKiraMasters[text, family, integral] reads the text of Kira's results/<family>/masters (lines family[a1,...]  # id): the list of integral[{a1, ...}].";
PFBKiraUnreduced::usage = "PFBKiraUnreduced[log] is the number of integrals Kira left unreduced, from its output (\"unreduced integrals: n\"; 0 when it says nothing).";
PFBKiraResult::usage = "PFBKiraResult[<|\"ExitCode\", \"Log\", \"Results\", \"MastersText\", \"Family\", \"Integral\", \"Dimension\", \"TimeLimit\", \"MemoryGB\"|>] reads one Kira run: <|\"Rules\", \"Masters\"|>, or a String saying why it gives no reduction (stopped at a limit, failed, integrals left unreduced, no result).";
PFBKiraVectors::usage = "PFBKiraVectors[targets, rules, masters] is <|integral -> vector on masters|> for every target (a master: its unit vector), or a String naming the targets Kira did not reduce or the integrals of its result outside its masters.";
PFBKiraExprVector::usage = "PFBKiraExprVector[expr, point, vectors, n] is the vector on Kira's n masters of a linear combination of integrals (coefficients evaluated at point), from the vectors of PFBKiraVectors; $Failed when an integral of it has no vector.";
PFBKiraValues::usage = "PFBKiraValues[point, names] is the \"Values\" of PFBKiraCommand: {kiraName -> value} for every invariant of the family Kira reduces (names: {invariant name -> Kira's name}, the job's Kira configuration), and nothing for a point's other entries (Kira 3 hangs on a --set_value of a variable it does not know). A String when an invariant of the family has no value at the point.";
PFBKiraTimeLimit::usage = "PFBKiraTimeLimit[left] is Kira's own time limit, in seconds, inside a job with left seconds still to run: half of them (at least 60), so that FiniteFlow can still reduce the slice point when Kira stops at its limit.";
PFBKiraProject::usage = "PFBKiraProject[U, V] chooses the system's masters among the rows of U (each row: a master of the system, i.e. its definition on Kira's masters) and puts the rows of V (vectors on Kira's masters) on them: <|\"Selected\" -> row positions, \"Rows\" -> W|> with W . U[[Selected]] = V, exactly in eps, solved block by block (block triangular form) without the inverse of the whole matrix. Every row of U is a master (U has as many rows as Kira has masters). A String, and FiniteFlow reduces the point instead, when the rows do not span Kira's masters (the subtree has masters the system lacks), when the system has more masters in the subtree than Kira (some are related there: which to keep is FiniteFlow's choice, as at the other points), or when a master of the system reduces to zero. PFBKiraProject[U, V, nK] gives the number of Kira's masters (U's rows have that length): a subtree that holds none of the system's masters (U = {}) while Kira finds masters is a String too.";

Begin["`Private`"];


(* ::Section:: *)
(*The choice*)


PFBReducerChoice[want_, facts_Association : <||>] := Module[{fams = Lookup[facts, "Families", {}], kf = Lookup[facts, "KiraFamily", Automatic], nsym = Lookup[facts, "SymmetryRules", 0], why},
  If[want === "FiniteFlow", Return[<|"Reducer" -> "FiniteFlow", "Reason" -> "FiniteFlow was asked for (\"Reducer\" -> \"FiniteFlow\")", "Requested" -> want, "Refused" -> False|>]];
  why = Which[
    ! TrueQ[Lookup[facts, "KiraAvailable", False]], "Kira or Fermat (fer64) is not found (preflight, paths.wl)",
    TrueQ[Lookup[facts, "LearnOnly", False]], "a learn-only job needs FiniteFlow's learning",
    TrueQ[Lookup[facts, "Analytic", False]], "an analytic job reconstructs its coefficients from FiniteFlow's learned system",
    TrueQ[Lookup[facts, "Degrees", False]], "a degree or line job (job.m \"Degrees\", \"Line\") measures or samples FiniteFlow's learned system",
    Length[fams] =!= 1, "the subtree's integrals lie in " <> ToString[Length[fams]] <> " families (" <> StringRiffle[ToString /@ fams, ", "] <>
      "), and Kira reduces one family at a time",
    kf =!= Automatic && kf =!= First[fams], "the job's Kira configuration is for the family " <> ToString[kf] <> ", the subtree's integrals lie in " <> ToString[First[fams]],
    nsym > 0, ToString[nsym] <> " symmetry rule(s) of the system apply inside the subtree, and Kira does not read them",
    True, None];
  Which[
    why === None, <|"Reducer" -> "Kira", "Reason" -> "one family (" <> ToString[First[fams]] <> "), Kira and Fermat found", "Requested" -> want, "Refused" -> False|>,
    want === "Kira", <|"Reducer" -> "FiniteFlow", "Reason" -> why, "Requested" -> want, "Refused" -> True|>,
    True, <|"Reducer" -> "FiniteFlow", "Reason" -> why, "Requested" -> want, "Refused" -> False|>]];


(* ::Section:: *)
(*The job*)


PFBKiraValues[pt_List, names_List] := Module[{nm = Association[names], vals = Association[Table[SymbolName[r[[1]]] -> r[[2]], {r, pt}]], miss},
  miss = Select[Keys[nm], ! KeyExistsQ[vals, #] &];
  If[miss =!= {}, Return["the point gives no value to the invariant(s) " <> StringRiffle[miss, ", "] <> " of the family Kira reduces"]];
  KeyValueMap[nm[#1] -> vals[#1] &, KeySelect[vals, KeyExistsQ[nm, #] &]]];

PFBKiraTimeLimit[left_?NumericQ] := Max[60, Floor[left/2]];

PFBKiraMappedPoint[pt_List, {}] := pt;
PFBKiraMappedPoint[pt_List, imap_List] := Table[r[[1]] -> ((r[[1]] /. imap) /. pt), {r, pt}];

PFBKiraSectorID[sec_List] := Total[sec 2^Range[0, Length[sec] - 1]];

secOf[idx_List] := Boole[Positive[#]] & /@ idx;
subQ[a_, b_] := And @@ Thread[a <= b];
rPos[idx_] := Total[Select[idx, Positive]];
sNeg[idx_] := -Total[Select[idx, Negative]];

PFBKiraSeeds[targets_List, roots_List, rank_Integer, dots_Integer] := Module[{secs, tops},
  secs = DeleteDuplicates[Join[roots, secOf /@ targets]];
  tops = Select[secs, Function[a, ! AnyTrue[secs, # =!= a && subQ[a, #] &]]];
  tops = SortBy[tops, {-Total[#], PFBKiraSectorID[#]} &];
  Table[With[{in = Select[targets, subQ[secOf[#], top] &]},
     {top, Max[Total[top] + dots, If[in === {}, 0, Max[rPos /@ in] + 1]], Max[rank, If[in === {}, 0, Max[sNeg /@ in] + 1]]}], {top, tops}]];

PFBKiraTargetText[fam_String, targets_List] := StringJoin[(fam <> "[" <> StringRiffle[ToString /@ #, ","] <> "]\n") & /@ targets];

PFBKiraJobYAML[fam_String, seeds_List] := StringJoin[
  "jobs:\n",
  "  - reduce_sectors:\n",
  "      reduce:\n",
  Table["        - {topologies: [" <> fam <> "], sectors: [" <> ToString[PFBKiraSectorID[e[[1]]]] <> "], r: " <> ToString[e[[2]]] <> ", s: " <> ToString[e[[3]]] <> "}\n", {e, seeds}],
  "      select_integrals:\n",
  "        select_mandatory_list:\n",
  "          - [", fam, ", target]\n",
  "      run_initiate: true\n",
  "      run_triangular: true\n",
  "      run_back_substitution: true\n",
  "  - kira2math:\n",
  "      target:\n",
  "        - [", fam, ", target]\n"];

quote[s_String] := "'" <> StringReplace[s, "'" -> "'\\''"] <> "'";
num[x_] := ToString[x, InputForm];

PFBKiraCommand[c_Association] := Module[{t = Lookup[c, "TimeLimit", 0], m = Lookup[c, "MemoryGB", Automatic], lim = Lookup[c, "Limit", None]},
  StringJoin[
    If[StringQ[c["Fermat"]], "FERMATPATH=" <> quote[c["Fermat"]] <> " ", ""],
    If[StringQ[lim], quote[lim] <> " --timeout " <> ToString[If[NumericQ[t] && t > 0, Round[t], 0]] <>
       If[m === Automatic, "", " --memory " <> If[NumericQ[m] && m > 0, ToString[N[Round[m, 0.01]], InputForm], "0"]] <> " -- ", ""],
    quote[c["Kira"]], " --parallel=", ToString[Lookup[c, "Threads", 1]],
    StringJoin[" --set_value=" <> quote[#[[1]] <> "=" <> num[#[[2]]]] & /@ c["Values"]],
    " job.yaml > kira.out 2>&1"]];


(* ::Section:: *)
(*Reading the result*)


$parseContext = "PoleFreeBasis`Kira`Parse`";

(* the text with the integrals of fam as kiraint[...], parsed in a context of its own: <|"Rules" -> raw rules, "kint", "d"|> *)
parseRaw[txt_String, fam_String] := Module[{t, e, kint, d},
  t = StringReplace[txt, RegularExpression["\\b" <> fam <> "\\["] -> "kiraint["];
  e = Block[{$Context = $parseContext, $ContextPath = {"System`"}}, Quiet@ToExpression[t]];
  kint = Symbol[$parseContext <> "kiraint"]; d = Symbol[$parseContext <> "d"];
  If[! MatchQ[e, {___Rule}], Return[$Failed]];
  (* nothing but integrals and d may be left: the invariants were fixed with --set_value *)
  If[! FreeQ[e /. {kint[___] -> 1, d -> 1}, x_Symbol /; Context[x] === $parseContext], Return[$Failed]];
  <|"Rules" -> e, "kint" -> kint, "d" -> d|>];

PFBKiraParse[txt_String, fam_String, intOf_, dim_] := With[{r = parseRaw[txt, fam]},
  If[r === $Failed, $Failed, r["Rules"] /. {r["kint"][a___] :> intOf[{a}], r["d"] -> dim}]];
PFBKiraParse[_, _, _, _] := $Failed;

PFBKiraMasters[txt_String, fam_String, intOf_] := Module[{ls},
  ls = Select[StringTrim[StringReplace[#, "#" ~~ ___ -> ""]] & /@ StringSplit[txt, "\n"], # =!= "" &];
  Flatten[StringCases[#, fam ~~ "[" ~~ a : Except["]"] .. ~~ "]" :> intOf[ToExpression["{" <> a <> "}"]]] & /@ ls]];
PFBKiraMasters[_, _, _] := {};

PFBKiraUnreduced[log_String] := With[{u = StringCases[log, "unreduced integrals:" ~~ Whitespace ... ~~ n : DigitCharacter .. :> ToExpression[n]]}, If[u === {}, 0, Max[u]]];
PFBKiraUnreduced[_] := 0;

PFBKiraResult[r_Association] := Module[{code = r["ExitCode"], log = Lookup[r, "Log", ""], un, raw, rules, masters, rhs},
  Which[
    code === 124, Return["Kira stopped at its time limit (" <> ToString[Lookup[r, "TimeLimit", "?"]] <> " s, half of what was left of the job's \"TimeLimit\")"],
    code === 137, Return["Kira stopped at its memory limit (" <> ToString[Lookup[r, "MemoryGB", "?"]] <> " GB, 90% of what the job's memory limit leaves)"],
    code =!= 0, Return["Kira failed (exit code " <> ToString[code] <> "); see kira/kira.out"]];
  un = PFBKiraUnreduced[log];
  If[un > 0, Return["Kira left " <> ToString[un] <> " integral(s) unreduced: raise the seeds (rank, dots)"]];
  (* a job whose targets are all masters has an empty result *)
  raw = If[StringQ[r["Results"]], parseRaw[r["Results"], r["Family"]], parseRaw["{}", r["Family"]]];
  If[raw === $Failed, Return["Kira's result could not be read (kira/results/" <> r["Family"] <> "/kira_target.m)"]];
  rules = raw["Rules"] /. {raw["kint"][a___] :> r["Integral"][{a}], raw["d"] -> r["Dimension"]};
  rhs = Union[Cases[raw["Rules"][[All, 2]], raw["kint"][___], Infinity]] /. raw["kint"][a___] :> r["Integral"][{a}];
  (* the masters file lists the masters the targets need; the integrals of the result are masters too *)
  masters = DeleteDuplicates[Join[PFBKiraMasters[Lookup[r, "MastersText", ""], r["Family"], r["Integral"]], rhs]];
  <|"Rules" -> rules, "Masters" -> masters|>];

PFBKiraVectors[targets_List, rules_List, masters_List] := Module[{n = Length[masters], pos = AssociationThread[masters -> Range[Length[masters]]], rl = Association[rules], vec, missing = {}, outside = {}, out},
  vec[rhs_] := Module[{e = Expand[rhs], ints, v = ConstantArray[0, n]},
    ints = Union[Cases[{e}, x_ /; KeyExistsQ[pos, x], Infinity]];
    Do[v[[pos[m]]] = Together[Coefficient[e, m]], {m, ints}];
    If[Together[e - v . masters] =!= 0, AppendTo[outside, rhs]];
    v];
  out = Association[Table[t -> Which[KeyExistsQ[pos, t], UnitVector[n, pos[t]], KeyExistsQ[rl, t], vec[rl[t]], True, (AppendTo[missing, t]; Nothing)], {t, targets}]];
  Which[
    missing =!= {}, "Kira's result lacks " <> ToString[Length[missing]] <> " target(s), e.g. " <> ToString[First[missing], InputForm],
    outside =!= {}, "Kira's result holds integrals outside its masters, e.g. in " <> ToString[Short[First[outside], 2], InputForm],
    True, out]];

PFBKiraExprVector[ex_, pt_List, vecs_Association, n_Integer] := Module[{e = Expand[ex /. pt], ints},
  ints = Union[Cases[{e}, x_ /; KeyExistsQ[vecs, x], Infinity]];
  If[Together[e - Sum[Coefficient[e, x] x, {x, ints}]] =!= 0, Return[$Failed]];
  If[ints === {}, ConstantArray[0, n], Sum[Coefficient[e, x] vecs[x], {x, ints}]]];

(* The rank is that of the rows at two random rational values of eps: exact, and generic. The rows are then solved
   block by block, never through the inverse of the whole matrix: with a perfect matching of masters to Kira's masters,
   the strongly connected components of the matched pattern put US into block triangular form (blocks: the masters of
   one sector, mostly), and each block is solved from the blocks before it. Every intermediate quantity is then a row
   of the final reduction or an input: an inverse of the whole matrix grows far larger than either (a 20 x 20 case took
   minutes). *)
numericValues[U_] := Module[{syms = Union[Cases[U, x_Symbol /; ! NumericQ[x], Infinity]], ok},
  ok = Select[{7919/104729, -3571/15485863, 104723/1299709, -15485857/32452843}, Function[v,
     AllTrue[Flatten[Quiet[U /. Thread[syms -> v]]], NumericQ[#] && # =!= ComplexInfinity &]]];
  Quiet[U /. Thread[syms -> #]] & /@ Take[ok, UpTo[2]]];

PFBKiraProject[U_List, V_List, nKira_ : Automatic] := Module[{nK = Replace[nKira, Automatic :> If[U === {}, If[V === {}, 0, Length[First[V]]], Length[First[U]]]], zero, Un, rk, sel = {}, US, nz, match, sigma, dg, comps, blockOf, order, W, cedges},
  (* no master of the system in the subtree: right only when Kira finds none either (every row is zero) *)
  If[U === {}, Return[If[nK == 0, <|"Selected" -> {}, "Rows" -> ConstantArray[{}, Length[V]]|>,
     "none of the system's masters lies in the subtree, where Kira finds " <> ToString[nK] <> " master(s): the subtree has masters the system lacks (FiniteFlow adds host sectors or keeps them as extra columns)"]]];
  zero = Flatten[Position[U, r_ /; AllTrue[r, Together[#] === 0 &], {1}, Heads -> False]];
  If[zero =!= {}, Return["Kira reduces the master(s) of the system at position(s) " <> ToString[zero] <> " of the subtree to zero"]];
  Un = numericValues[U];
  If[Un === {}, Return["no value of eps where Kira's coefficients are all finite"]];
  rk[rows_] := Max[MatrixRank[#[[rows]]] & /@ Un];
  If[rk[Range[Length[U]]] < nK, Return["the system's masters of the subtree span " <> ToString[rk[Range[Length[U]]]] <> " of Kira's " <> ToString[nK] <>
     " masters: the subtree has masters the system lacks (FiniteFlow adds host sectors or keeps them as extra columns)"]];
  (* more masters of the system in the subtree than Kira's: some of them are related there (two equal masters, or a
     symmetry Kira uses). Which of them to keep is FiniteFlow's choice at the other points: choosing here could pick
     another subset than they do, so FiniteFlow reduces the slice point too *)
  If[Length[U] > nK, Return["Kira finds " <> ToString[nK] <> " masters in the subtree, the system has " <> ToString[Length[U]] <>
     " there: some of the system's masters are related in it (equal masters, or a symmetry Kira uses), and FiniteFlow, which reduces the other points, chooses among them"]];
  (* as many masters as Kira's (the usual case): all of them *)
  sel = Range[nK];
  sel = Sort[sel];
  US = Map[Together, U[[sel]], {2}];
  nz = Map[# =!= 0 &, US, {2}];
  (* rows 1..nK, Kira's masters nK+1..2nK *)
  match = FindIndependentEdgeSet[Graph[Range[2 nK], Flatten[Table[If[nz[[i, k]], UndirectedEdge[i, nK + k], Nothing], {i, nK}, {k, nK}]]]];
  sigma = Association[Table[With[{a = Min[List @@ e], b = Max[List @@ e]}, a -> b - nK], {e, match}]];
  If[Length[sigma] < nK, Return["the masters of the system could not be matched to Kira's (a singular matrix)"]];
  dg = Graph[Range[nK], Flatten[Table[If[i =!= i2 && nz[[i, sigma[i2]]], DirectedEdge[i, i2], Nothing], {i, nK}, {i2, nK}]]];
  comps = ConnectedComponents[dg];
  blockOf = Association[Flatten[Table[Thread[comps[[b]] -> b], {b, Length[comps]}]]];
  cedges = DeleteDuplicates[Cases[EdgeList[dg], DirectedEdge[a_, b_] /; blockOf[a] =!= blockOf[b] :> DirectedEdge[blockOf[a], blockOf[b]]]];
  order = TopologicalSort[Graph[Range[Length[comps]], cedges]];
  W = ConstantArray[0, {Length[V], nK}];
  Do[Module[{B = Sort[comps[[b]]], cols, preds, rhs},
     cols = sigma /@ B;
     preds = Complement[Select[Range[nK], Function[i, AnyTrue[cols, nz[[i, #]] &]]], B];
     rhs = V[[All, cols]] - If[preds === {} || V === {}, 0, W[[All, preds]] . US[[preds, cols]]];
     If[V =!= {}, W[[All, B]] = Map[Together, rhs . Map[Together, Inverse[US[[B, cols]]], {2}], {2}]]], {b, order}];
  <|"Selected" -> sel, "Rows" -> W|>];


End[];
EndPackage[];
