(* ::Package:: *)

(* ::Title:: *)
(*PoleFreeBasis`Singularities`: known singularities of a family (its letters and SOFIA's candidate list)*)


(* ::Text:: *)
(*SOFIA (M. Correia, M. Giroux, S. Mizera, arXiv:2503.16601) lists the candidate singularities of one Feynman graph:*)
(*irreducible polynomials in the invariants and masses, subtopologies included. The list is a superset (the sheet of each*)
(*singularity is unknown), and SOFIA cannot test a given polynomial. It is an optional tool: "SOFIA" in paths.wl names its*)
(*scr.m (never the loader SOFIA.m, which downloads scr.m from GitHub on every load). bin/singularities.wls runs it in a*)
(*kernel of its own, since scr.m changes System`CenterDot and System`Wedge, prints a lot and exports one-letter symbols*)
(*(s, t, m, M, mm, MM, p, d, ...). It is loaded with $ContextPath restored afterwards and runs in a scratch context, so*)
(*that its run-time names (s12, MM1, mm1, built with ToExpression) never meet the family's invariants: the results come*)
(*back as PFBSOFIAVar["s12"], ... and are renamed through the family's kinematics. The graph comes from MCBGraph (the*)
(*family's "Graph", else momentum conservation); vertices with external momenta come first, as SOFIA's own drawing tool*)
(*numbers them. Its variables: s<ij...> = (p_i + p_j + ...)^2 of the momenta entering the nodes i, j, ...; MM<i> an external*)
(*mass squared; mm<k> an internal one; s alone the p^2 of a two-point graph.*)


BeginPackage["PoleFreeBasis`Singularities`", {"PoleFreeBasis`", "PoleFreeBasis`Config`", "PoleFreeBasis`System`", "MaximalCutBasis`",
  "SkillCore`Tools`", "SkillCore`Citations`", "MaximalCutBasis`Family`", "MaximalCutBasis`Sectors`", "MaximalCutBasis`Draw`"}];

PFBSOFIAVar::usage = "PFBSOFIAVar[name] is SOFIA's variable name (\"s12\", \"MM1\", \"mm1\", \"s\") in a polynomial brought back from SOFIA, before the renaming into the family's invariants.";
$PFBSOFIAPinned::usage = "$PFBSOFIAPinned is the version of SOFIA the skill was tested with: <|\"Commit\", \"Date\", \"Blob\" (git blob of its scr.m)|> (reference/tools.md).";
PFBSOFIAPath::usage = "PFBSOFIAPath[] is the path of SOFIA's scr.m: \"SOFIA\" in paths.wl, else the environment variable MCB_SOFIA, else Missing[\"NotConfigured\"]. It is never searched for.";
PFBSOFIAInfo::usage = "PFBSOFIAInfo[path] checks that path is SOFIA's scr.m and not its loader SOFIA.m (which downloads scr.m on every load), and that it loads nothing from the network: <|\"OK\", \"Path\", \"Message\", \"Version\", \"Commit\" (the git commit of a SOFIA checkout holding it, or Missing), \"Modified\" (local changes to scr.m in that checkout), \"Blob\" (git blob hash), \"Pinned\" (the blob of $PFBSOFIAPinned), \"SHA256\"|>.";
PFBSOFIALine::usage = "PFBSOFIALine[] = <|\"Status\" -> \"found\" | \"not configured\" | \"refused\", \"Text\"|>: the preflight's line on SOFIA.";
PFBSOFIAGraph::usage = "PFBSOFIAGraph[fam, sector] is SOFIA's input for the graph of a sector of a family object: <|\"OK\", \"Message\", \"Sector\", \"Name\", \"Edges\" -> {{{a, b}, mass}, ...}, \"Nodes\" -> {{v, mass}, ...}, \"Lines\" (the propagator of each edge), \"Momenta\" (the momentum entering each node), \"Masses\" -> <|\"m1\" -> Mass2, ...|>, \"ExternalMasses\" -> <|\"M1\" -> p^2, ...|>, \"Loops\", \"Source\", \"Input\" (in SOFIA's notation)|>. A mass is 0, \"m<k>\" (internal mass squared k, also for an external leg of that mass) or \"M<i>\" (an external mass squared); the vertices with external momenta come first. The graph is MCBGraph's: the family's \"Graph\", else momentum conservation. Quadratic propagators only.";
PFBSOFIARename::usage = "PFBSOFIARename[fam, graph, name] is SOFIA's variable name in the family's invariants, for a graph of PFBSOFIAGraph: s<ij...> -> (sum of the momenta entering nodes i, j, ...)^2, MM<i> and mm<k> -> the squared masses, s (two nodes) -> p^2; Missing[\"Unknown\", name] otherwise. PFBSOFIARename[fam, graph, polys] renames polynomials in PFBSOFIAVar[name]: <|\"Polynomials\" (their irreducible factors in the invariants, PFBNormalizePolynomials), \"Vanishing\" (those that vanish at the family's kinematics), \"Unrenamed\" (unknown variables, or not polynomial after renaming), \"Rules\" (name -> expression)|>.";
PFBSOFIASymanzikCheck::usage = "PFBSOFIASymanzikCheck[fam, graph] checks the graph SOFIA receives (PFBSOFIAGraph) against the family's propagators, independently of SOFIA: the Symanzik polynomials of the graph in SOFIA's terms (U from its spanning trees, F from its spanning 2-forests, with the mass labels of its edges and legs and SOFIA's names s<ij...> for the momenta entering several legs, renamed by PFBSOFIARename) against those of the sector computed from its propagators in momentum space (MCBSymanzik), each edge standing for its line. \"agrees\" when both are equal up to a sign each, else a String saying which differs (a wrong edge, mass or momentum). PFBSOFIAGraph refuses a graph that does not agree.";
PFBSOFIAKinematicsCheck::usage = "PFBSOFIAKinematicsCheck[fam, graph, subs] compares SOFIA's kinematics, subs = {{i, j} -> p_i.p_j in PFBSOFIAVar names} (from SOFIA`MySubstitutions), renamed into the invariants, with the scalar products of the momenta entering the nodes: the mismatches {{i, j}, SOFIA's renamed, the family's}; {} when they agree. The renaming defines SOFIA's variables by those momenta, so this checks SOFIA's conventions (its s_ij, the masses it gives the nodes) against the renaming, not the graph (PFBSOFIASymanzikCheck does that).";
PFBNormalizePolynomials::usage = "PFBNormalizePolynomials[polys, vars] are the distinct irreducible factors of polys that depend on vars, each with integer coprime coefficients and a positive leading coefficient (degree-reverse-lexicographic in vars), identified up to constant factors and sorted by total degree; a factor that is no polynomial in vars (a letter with a square root) is kept as it is, after the others.";
PFBSingularityGraphs::usage = "PFBSingularityGraphs[sys, fam] lists the top sectors of a base family on which SOFIA runs, one graph each: the sectors of its masters that no other sector of its masters contains (family.wl \"TopSectors\" or the lines of \"Graph\" when it has no masters).";
PFBRunSingularities::usage = "PFBRunSingularities[ctx, fams, opts] (through bin/singularities.wls: scr.m changes System`CenterDot and System`Wedge in the kernel that loads it) runs SOFIA on the top graphs of each base family in fams (All: every base family; an image means its base), one after the other in this kernel, with subtopologies, SolverBound -> Infinity and no Substitutions, and writes singularities/<fam>.m and singularities/<fam>.log in the run folder (bin/singularities.wls); SOFIA is credited in the run's ledger, citations.m (whole run, step \"candidate singularities of <fam>\"), for each family done or partial. ctx from PFBStartRun. opts: \"SOFIA\" (path of scr.m, default PFBSOFIAPath[]), \"TimeLimit\" (seconds per graph, default 3600; Infinity for none), \"Force\" (recompute a cache whose input has not changed). Returns <|\"Status\" -> \"done\" | \"skipped\" (SOFIA not configured: nothing written) | \"refused\" (not scr.m) | \"error\" (scr.m did not load), \"Message\", \"Families\" -> <|fam -> cache|>|>.";
PFBSingularitiesFile::usage = "PFBSingularitiesFile[runDir, fam] is the cache of SOFIA's polynomials of a base family: <run>/singularities/<fam>.m (reference/formats.md).";
PFBReadSingularities::usage = "PFBReadSingularities[runDir, fam] reads the cache of a base family, or Missing[\"NotRun\"].";
PFBKnownSingularities::usage = "PFBKnownSingularities[ctx, fam] (ctx from PFBStartRun) or PFBKnownSingularities[sys, runDir, fam] are the known singularities of a family, an image's through its invariant map: <|\"Family\", \"Base\", \"Invariants\", \"Known\" (the family's letters together with SOFIA's polynomials: irreducible, in the family's invariants, PFBNormalizePolynomials), \"Sources\" (for each element of Known: {\"Letters\"}, {\"SOFIA\"} or both), \"Letters\" (the alphabet the gate's letter check and the rescalings may use: the family.wl and system.wl \"Letters\", and SOFIA's polynomials only when the user set \"LettersFromSOFIA\" -> True), \"SOFIA\" (SOFIA's polynomials, {} unless the cache is usable), \"SOFIAStatus\" (done, partial, failed, timeout, not applicable, stale, not run), \"Accepted\", \"Offer\" (the family has no letters and SOFIA's polynomials wait for the user's yes), \"Provenance\" (file, date, SOFIA's commit and hash, options, warnings, graphs)|>. fam All: an Association over every family.";
PFBSingularityOffers::usage = "PFBSingularityOffers[sys, runDir] lists the base families without \"Letters\" whose SOFIA cache holds polynomials that the user has not accepted as letters: <|\"Family\", \"Count\", \"File\", \"Message\"|>; the message says how to accept them.";
PFBAttachSOFIALetters::usage = "PFBAttachSOFIALetters[sys, runDir] puts SOFIA's polynomials of every base family whose system.wl entry has \"LettersFromSOFIA\" -> True into sys[\"SOFIALetters\"], where PFBLetters finds them; families with the key and no usable cache go to sys[\"SOFIALettersMissing\"] (family -> status). PFBStartRun calls it.";

Begin["`Private`"];


(* ::Section:: *)
(*The tool*)


$PFBSOFIAPinned = <|"Commit" -> "d4498b95ffcd9f43ba6bce3899c133d3487b5a65", "Date" -> "2025-12-20", "Blob" -> "396668c8526ec23958f3a307181265cdd87b194c"|>;

(* the options of every run: subtopologies, no bound on the solver, no substitution (the unit scale is not set to 1) *)
$sofiaOptions = {"IncludeSubtopologies" -> True, "SolverBound" -> Infinity, "Substitutions" -> {}};

sofiaSym[name_String] := Symbol["SOFIA`" <> name];

PFBSOFIAPath[] := Module[{p = MCBPath["SOFIA"], env = Environment["MCB_SOFIA"]},
  Which[StringQ[p], p, StringQ[env] && env =!= "", ExpandFileName[env], True, Missing["NotConfigured"]]];

$notConfigured = "SOFIA is not configured: the step is optional and computed nothing. To use it, install SOFIA's scr.m at the pinned commit and add \"SOFIA\" -> \"/path/to/SOFIA/scr.m\" to paths.wl (reference/tools.md).";

git[dir_, args_List] := Module[{r = Quiet@RunProcess[Join[{"git", "-C", dir}, args]]},
  If[AssociationQ[r] && r["ExitCode"] === 0, StringTrim[r["StandardOutput"]], $Failed]];

PFBSOFIAInfo[_Missing] := <|"OK" -> False, "Path" -> None, "Message" -> $notConfigured|>;
PFBSOFIAInfo[path_String] := Module[{f = ExpandFileName[path], txt, ver, dir, top, origin, commit, modified, blob, sha, out},
  If[! FileExistsQ[f] || DirectoryQ[f], Return[<|"OK" -> False, "Path" -> f, "Message" -> f <> " does not exist: \"SOFIA\" in paths.wl must be the path of SOFIA's scr.m"|>]];
  txt = Quiet@ReadString[f];
  If[! StringQ[txt], Return[<|"OK" -> False, "Path" -> f, "Message" -> f <> " cannot be read"|>]];
  Which[
    StringContainsQ[txt, "raw.githubusercontent.com"] && StringFreeQ[txt, "BeginPackage[\"SOFIA`\"]"],
      Return[<|"OK" -> False, "Path" -> f, "Message" -> f <> " is SOFIA's loader (SOFIA.m), which downloads scr.m from GitHub on every load: name the scr.m of a checkout at the pinned commit instead (reference/tools.md)"|>],
    StringFreeQ[txt, "BeginPackage[\"SOFIA`\"]"],
      Return[<|"OK" -> False, "Path" -> f, "Message" -> f <> " is not SOFIA's scr.m (no BeginPackage[\"SOFIA`\"])"|>],
    StringContainsQ[txt, RegularExpression["(Get|Import|URLRead|URLExecute|URLFetch|URLDownload|URLSave)\\[\\s*\"https?:"]],
      Return[<|"OK" -> False, "Path" -> f, "Message" -> f <> " loads code from the network; use the scr.m of a checkout at the pinned commit (reference/tools.md)"|>]];
  ver = StringCases[txt, "Automatized (v" ~~ v : Except[")"] .. ~~ ")" :> StringTrim[v, "."], 1];
  dir = DirectoryName[f];
  top = git[dir, {"rev-parse", "--show-toplevel"}];
  origin = git[dir, {"config", "--get", "remote.origin.url"}];
  (* a commit only for a checkout of SOFIA itself: scr.m inside another repository says nothing about its version *)
  {commit, modified} = If[StringQ[top] && StringQ[origin] && StringContainsQ[origin, "SOFIA", IgnoreCase -> True] &&
       ExpandFileName[top] === ExpandFileName[StringReplace[dir, "/" .. ~~ EndOfString -> ""]],
    {git[dir, {"rev-parse", "HEAD"}], With[{st = git[dir, {"status", "--porcelain", "--", FileNameTake[f]}]}, StringQ[st] && st =!= ""]},
    {Missing["NotASOFIACheckout"], Missing["NotASOFIACheckout"]}];
  blob = Replace[git[dir, {"hash-object", f}], $Failed -> Missing["NoGit"]];
  sha = IntegerString[FileHash[f, "SHA256"], 16, 64];
  out = <|"OK" -> True, "Path" -> f, "Version" -> If[ver === {}, Missing["Unknown"], First[ver]], "Commit" -> Replace[commit, $Failed -> Missing["Unknown"]],
    "Modified" -> modified, "Blob" -> blob, "Pinned" -> (blob === $PFBSOFIAPinned["Blob"]), "SHA256" -> sha|>;
  out["Message"] = "SOFIA's scr.m " <> f <> " (" <> If[StringQ[out["Version"]], "v" <> out["Version"], "version unknown"] <> ", " <>
    Which[StringQ[out["Commit"]], "commit " <> StringTake[out["Commit"], UpTo[12]] <> If[TrueQ[out["Modified"]], " with local changes", ""], True, "not in a git checkout of SOFIA"] <> "; " <>
    If[out["Pinned"], "the pinned version", "not the pinned version: the skill was tested with commit " <> StringTake[$PFBSOFIAPinned["Commit"], 12]] <> ")";
  out];

PFBSOFIALine[] := Module[{p = PFBSOFIAPath[], i},
  If[! StringQ[p], Return[<|"Status" -> "not configured", "Text" -> "not configured (optional, for bin/singularities.wls: \"SOFIA\" -> path of scr.m in paths.wl; reference/tools.md)"|>]];
  i = PFBSOFIAInfo[p];
  If[i["OK"], <|"Status" -> "found", "Text" -> i["Message"]|>, <|"Status" -> "refused", "Text" -> "REFUSED: " <> i["Message"]|>]];


(* ::Section:: *)
(*The graph*)


loopPart[fam_, q_] := Coefficient[Expand[q], #] & /@ fam["LoopMomenta"];
sq[fam_, q_] := Together[MCBToSP[fam, Expand[q^2]]];
dot[fam_, a_, b_] := Together[MCBToSP[fam, Expand[a b]]];

graphFail[sec_, msg_] := <|"OK" -> False, "Sector" -> sec, "Name" -> SectorName[sec], "Message" -> msg|>;

(* the direction of each line (+1: its momentum flows from tail to head) that conserves the loop momenta at every vertex *)
orientations[fam_, lines_] := Module[{n = Length[lines], al, verts, inc, ok, go},
  al = loopPart[fam, fam["Propagators"][[#[[3]]]]["Momentum"]] & /@ lines;
  verts = Union[Flatten[lines[[All, 1 ;; 2]]]];
  inc = Association[Table[v -> Select[Range[n], lines[[#, 1]] =!= lines[[#, 2]] && MemberQ[lines[[#, 1 ;; 2]], v] &], {v, verts}]];
  ok[s_, v_] := With[{es = inc[v]}, es === {} || AnyTrue[es, s[[#]] == 0 &] ||
     AllTrue[Total[Table[s[[e]] (Boole[lines[[e, 1]] === v] - Boole[lines[[e, 2]] === v]) al[[e]], {e, es}]], # === 0 &]];
  go[s_, k_] := Which[k > n, Throw[s, "pfbsig"],
    lines[[k, 1]] === lines[[k, 2]], go[ReplacePart[s, k -> 1], k + 1],
    True, Do[With[{s2 = ReplacePart[s, k -> sg]}, If[ok[s2, lines[[k, 1]]] && ok[s2, lines[[k, 2]]], go[s2, k + 1]]], {sg, {1, -1}}]];
  Catch[go[ConstantArray[0, n], 1]; $Failed, "pfbsig"]];

massStr[0] = "0";
massStr[x_String] := "Subscript[" <> StringTake[x, 1] <> ", " <> StringDrop[x, 1] <> "]";
inputString[edges_, nodes_] := "{{" <> StringRiffle[("{{" <> ToString[#[[1, 1]]] <> ", " <> ToString[#[[1, 2]]] <> "}, " <> massStr[#[[2]]] <> "}") & /@ edges, ", "] <>
  "}, {" <> StringRiffle[("{" <> ToString[#[[1]]] <> ", " <> massStr[#[[2]]] <> "}") & /@ nodes, ", "] <> "}}";

PFBSOFIAGraph[fam_Association, sec_List] := Module[{g, lines, props, V, sig, q, P, legV, intV, idx, n, edges, masses = {}, mlab, nodes, ext = <||>, X, pos, lab, loops, lin, out},
  g = Quiet@Check[MCBGraph[fam, sec], <|"ok" -> False, "message" -> "MCBGraph failed"|>];
  If[! TrueQ[g["ok"]], Return[graphFail[sec, "no graph of the sector (" <> ToString[g["message"]] <> "): give the family a \"Graph\" in family.wl"]]];
  lines = g["edges"];
  If[lines === {}, Return[graphFail[sec, "the sector has no lines"]]];
  props = fam["Propagators"][[#[[3]]]] & /@ lines;
  lin = Select[Transpose[{lines[[All, 3]], props}], #[[2]]["Type"] =!= "Quadratic" &][[All, 1]];
  If[lin =!= {}, Return[graphFail[sec, "SOFIA takes quadratic propagators only; lines " <> ToString[lin] <> " are linear"]]];
  V = g["vertices"];
  sig = orientations[fam, lines];
  If[sig === $Failed, Return[graphFail[sec, "the loop momenta of the lines are not conserved at the vertices of the graph (" <> g["message"] <> ")"]]];
  q = #["Momentum"] & /@ props;
  (* the external momentum entering each vertex: what leaves it through the lines minus what enters *)
  P = Table[Expand[Sum[If[lines[[e, 1]] === lines[[e, 2]], 0, sig[[e]] q[[e]] (Boole[lines[[e, 1]] === v] - Boole[lines[[e, 2]] === v])], {e, Length[lines]}]], {v, V}];
  If[! FreeQ[P, Alternatives @@ fam["LoopMomenta"]], Return[graphFail[sec, "a loop momentum enters a vertex from outside"]]];
  legV = Select[Range[V], P[[#]] =!= 0 &]; intV = Complement[Range[V], legV];
  n = Length[legV];
  If[n < 2, Return[graphFail[sec, "a vacuum graph (no external momentum): SOFIA needs external legs"]]];
  If[n > 9, Return[graphFail[sec, ToString[n] <> " vertices with external momenta: SOFIA's names s<ij...> would be ambiguous above 9"]]];
  loops = Length[lines] - V + 1;
  If[loops =!= fam["L"], Return[graphFail[sec, "the graph has " <> ToString[loops] <> " loops, the family " <> ToString[fam["L"]] <> " (" <> g["message"] <> ")"]]];
  idx = AssociationThread[Join[legV, intV] -> Range[V]];
  mlab[m2_] := If[Together[m2] === 0, 0,
    pos = FirstPosition[masses, x_ /; Together[x - m2] === 0, None, {1}];
    If[pos === None, AppendTo[masses, m2]; "m" <> ToString[Length[masses]], "m" <> ToString[First[pos]]]];
  edges = Table[{Sort[{idx[lines[[e, 1]]], idx[lines[[e, 2]]]}], mlab[props[[e]]["Mass2"]]}, {e, Length[lines]}];
  (* a leg's mass: 0, an internal mass it equals, an earlier leg's mass it equals, or its own M<i> *)
  nodes = Table[X = sq[fam, P[[legV[[i]]]]];
    {i, Which[
      X === 0, 0,
      (pos = FirstPosition[masses, x_ /; Together[x - X] === 0, None, {1}]) =!= None, "m" <> ToString[First[pos]],
      (lab = SelectFirst[Keys[ext], Together[ext[#] - X] === 0 &, None]) =!= None, lab,
      True, ext["M" <> ToString[i]] = X; "M" <> ToString[i]]}, {i, n}];
  out = <|"OK" -> True, "Message" -> ToString[Length[lines]] <> " lines, " <> ToString[V] <> " vertices, " <> ToString[n] <> " with external momenta, " <> ToString[loops] <> " loops (" <> g["message"] <> ")",
    "Sector" -> sec, "Name" -> SectorName[sec], "Edges" -> edges, "Nodes" -> nodes, "Lines" -> lines[[All, 3]], "Momenta" -> P[[legV]],
    "Masses" -> AssociationThread[Table["m" <> ToString[k], {k, Length[masses]}] -> masses], "ExternalMasses" -> ext, "Loops" -> loops,
    "Source" -> g["message"], "Input" -> inputString[edges, nodes]|>;
  (* the graph must be the sector's: its Symanzik polynomials are those of the propagators *)
  With[{chk = PFBSOFIASymanzikCheck[fam, out]}, If[chk === "agrees", Join[out, <|"SymanzikCheck" -> chk|>],
    graphFail[sec, "the graph does not match the sector's propagators: " <> chk <> " (" <> g["message"] <> "): give the family a \"Graph\" in family.wl that does"]]]];


(* ::Section:: *)
(*Renaming*)


PFBSOFIARename[fam_Association, g_Association, name_String] := Module[{n = Length[g["Nodes"]], d},
  Which[
    name === "s" && n == 2, sq[fam, g["Momenta"][[1]]],
    StringMatchQ[name, "s" ~~ DigitCharacter ..] && n >= 3,
      d = ToExpression /@ Characters[StringDrop[name, 1]];
      If[DuplicateFreeQ[d] && AllTrue[d, 1 <= # <= n &], sq[fam, Total[g["Momenta"][[d]]]], Missing["Unknown", name]],
    StringMatchQ[name, "MM" ~~ DigitCharacter ..], Lookup[g["ExternalMasses"], "M" <> StringDrop[name, 2], Missing["Unknown", name]],
    StringMatchQ[name, "mm" ~~ DigitCharacter ..], Lookup[g["Masses"], "m" <> StringDrop[name, 2], Missing["Unknown", name]],
    True, Missing["Unknown", name]]];

namesIn[e_] := Union[Cases[{e}, PFBSOFIAVar[n_String] :> n, {0, Infinity}]];

(* an expression in PFBSOFIAVar names, renamed; Missing when a name is unknown *)
renameExpr[fam_, g_, e_] := Module[{r = AssociationMap[PFBSOFIARename[fam, g, #] &, namesIn[e]]},
  If[AnyTrue[Values[r], MissingQ], Missing["Unknown", Select[Keys[r], MissingQ[r[#]] &]], Together[e /. PFBSOFIAVar[n_String] :> r[n]]]];

sofiaString[e_] := StringReplace[ToString[e /. PFBSOFIAVar[n_String] :> Symbol["PFBSOFIAName`" <> n], InputForm], "PFBSOFIAName`" -> ""];

PFBSOFIARename[fam_Association, g_Association, polys_List] := Module[{invs = fam["InvList"], rules, out = {}, van = {}, unr = {}},
  rules = AssociationMap[PFBSOFIARename[fam, g, #] &, namesIn[polys]];
  Do[With[{unk = Select[namesIn[p], MissingQ[rules[#]] &]},
     If[unk =!= {}, AppendTo[unr, <|"Polynomial" -> sofiaString[p], "Reason" -> "unknown variables " <> StringRiffle[unk, ", "]|>],
       With[{r = Together[p /. PFBSOFIAVar[n_String] :> rules[n]]},
         Which[
           r === 0, AppendTo[van, sofiaString[p]],
           ! PolynomialQ[Numerator[r], invs] || Complement[Variables[Numerator[r]], invs] =!= {},
             AppendTo[unr, <|"Polynomial" -> sofiaString[p], "Reason" -> "not a polynomial in the invariants after renaming: " <> ToString[r, InputForm]|>],
           True, AppendTo[out, Numerator[r]]]]]], {p, polys}];
  <|"Polynomials" -> PFBNormalizePolynomials[out, invs], "Vanishing" -> van, "Unrenamed" -> unr,
    "Rules" -> KeyValueMap[#1 -> #2 &, Select[rules, ! MissingQ[#] &]]|>];

(* the graph against the propagators: the Symanzik polynomials of its spanning trees and 2-forests, edge e standing for
   line g["Lines"][[e]], against MCBSymanzik's of the sector (momentum space). Conventions differ by a sign at most *)
forestOf[es_List, nv_Integer] := Module[{par = Range[nv], find, ok = True},
  find[v_] := If[par[[v]] == v, v, par[[v]] = find[par[[v]]]];
  Do[With[{a = find[e[[1]]], b = find[e[[2]]]}, If[a == b, ok = False; Break[], par[[a]] = b]], {e, es}];
  If[ok, find /@ Range[nv], $Failed]];
PFBSOFIASymanzikCheck[fam_Association, g_Association] := Module[{sy, edges, ne, nv, nl, y, lineX, up, fp, ug = 0, f0 = 0, fg, mass, legMass, sOf, sameQ},
  sy = Quiet@MaximalCutBasis`SectorMaps`MCBSymanzik[fam, g["Sector"]];
  If[! AssociationQ[sy], Return["no Symanzik polynomials of the sector (its lines do not depend on every loop momentum)"]];
  edges = g["Edges"]; ne = Length[edges]; nv = Max[Flatten[edges[[All, 1]]], Length[g["Nodes"]]];
  If[Sort[sy["lines"]] =!= Sort[g["Lines"]], Return["the graph's lines " <> ToString[Sort[g["Lines"]]] <> " are not the sector's " <> ToString[Sort[sy["lines"]]]]];
  y = Array[PFBSymanzikY, ne];
  lineX = Thread[sy["x"] -> (y[[First[FirstPosition[g["Lines"], #]]]] & /@ sy["lines"])];
  up = Expand[sy["U"] /. lineX]; fp = Expand[sy["F"] /. lineX];
  (* in SOFIA's terms, renamed: the edges' mass labels, a node's own mass label for a tree with one leg, s<ij...> for
     a tree with several (SOFIA's nodes 1 .. nl are the legs) *)
  nl = Length[g["Nodes"]];
  mass[e_] := Replace[edges[[e, 2]], {0 -> 0, m_String :> g["Masses"][m]}];
  legMass[i_] := Replace[g["Nodes"][[i, 2]], {0 -> 0, m_String /; StringStartsQ[m, "m"] :> g["Masses"][m], m_String :> g["ExternalMasses"][m]}];
  sOf[legs_] := Which[legs === {} || Length[legs] == nl, 0, Length[legs] == 1, legMass[First[legs]], Length[legs] == nl - 1, legMass[First[Complement[Range[nl], legs]]],
    True, PFBSOFIARename[fam, g, "s" <> StringJoin[ToString /@ Sort[legs]]]];
  Do[If[forestOf[edges[[S, 1]], nv] =!= $Failed, ug += Times @@ y[[Complement[Range[ne], S]]]], {S, Subsets[Range[ne], {nv - 1}]}];
  Do[With[{cmp = forestOf[edges[[S, 1]], nv]}, If[cmp =!= $Failed,
      f0 += (Times @@ y[[Complement[Range[ne], S]]]) sOf[Select[Range[nl], cmp[[#]] == cmp[[1]] &]]]], {S, Subsets[Range[ne], {nv - 2}]}];
  If[! FreeQ[f0, _Missing], Return["F: SOFIA's names of the graph cannot all be renamed"]];
  fg = Expand[f0 - ug Sum[y[[e]] mass[e], {e, ne}]];
  sameQ[a_, b_] := Together[a - b] === 0 || Together[a + b] === 0;
  Which[
    ! sameQ[ug, up], "U differs: the graph's edges are not the sector's lines (graph " <> ToString[ug, InputForm] <> ", propagators " <> ToString[up, InputForm] <> ")",
    ! sameQ[fg, fp], "F differs: the masses of the edges or the momenta entering the nodes are not the sector's (graph " <> ToString[fg, InputForm] <> ", propagators " <>
      ToString[fp, InputForm] <> ")",
    True, "agrees"]];

PFBSOFIAKinematicsCheck[fam_Association, g_Association, subs_List] := Module[{bad = {}},
  Do[With[{ij = r[[1]], a = renameExpr[fam, g, r[[2]]]},
     With[{b = dot[fam, g["Momenta"][[ij[[1]]]], g["Momenta"][[ij[[2]]]]]},
       If[MissingQ[a] || Together[a - b] =!= 0, AppendTo[bad, {ij, a, b}]]]],
    {r, Select[subs, MatchQ[#, {i_Integer, j_Integer} -> _] && 1 <= #[[1, 1]] <= Length[g["Nodes"]] && 1 <= #[[1, 2]] <= Length[g["Nodes"]] &]}];
  bad];

normOne[f_, vars_] := Module[{e = Expand[f], lc},
  lc = First[CoefficientRules[e, vars, "DegreeReverseLexicographic"]][[2]];
  Expand[If[TrueQ[Negative[lc]], -e, e]]];

totalDegree[f_, vars_] := Max[Total /@ CoefficientRules[f, vars][[All, 1]]];

(* a factor that is no polynomial (a letter with a square root) is kept as it is, after the polynomials: a probe of the
   degree census cannot be made of it (PFBDegreeProbes leaves it out with a note) *)
PFBNormalizePolynomials[polys_List, vars_List] := Module[{facs, poly},
  facs = Flatten[Table[Select[FactorList[Factor[Expand[p]]][[All, 1]], ! FreeQ[#, Alternatives @@ vars] &], {p, polys}]];
  poly = Select[facs, PolynomialQ[#, vars] &];
  facs = Join[SortBy[DeleteDuplicates[normOne[#, vars] & /@ poly], {totalDegree[#, vars] &, LeafCount, Identity}], DeleteDuplicates[Complement[facs, poly]]];
  facs];


(* ::Section:: *)
(*Graphs of a family*)


famSym[f_String] := ToExpression[f];
famSym[f_] := f;

PFBSingularityGraphs[sys_Association, fam0_] := Module[{fn = PFBBaseOf[sys, famSym[fam0]], secs, fo},
  secs = Union[Select[PFBSectorKeys[sys], #[[1]] === fn &][[All, 2]]];
  If[secs === {},
    fo = PFBFamily[sys, fn];
    Return[If[MemberQ[{"family.wl", "Graph"}, fo["TopSectorsSource"]], Select[fo["TopSectors"], ListQ], {}]]];
  Select[secs, Function[s, NoneTrue[secs, # =!= s && AllTrue[# - s, NonNegative] &]]]];


(* ::Section:: *)
(*Running SOFIA*)


PFBSingularitiesFile[dir_String, fam_] := FileNameJoin[{dir, "singularities", ToString[famSym[fam]] <> ".m"}];

PFBReadSingularities[dir_String, fam_] := With[{f = PFBSingularitiesFile[dir, fam]},
  If[FileExistsQ[f], Replace[Quiet@Get[f], Except[_Association] -> Missing["Unreadable"]], Missing["NotRun"]]];

hashString[s_String] := IntegerString[Hash[s, "SHA256"], 16, 64];
graphsDigest[graphs_List] := hashString[ToString[Table[If[TrueQ[g["OK"]],
     {g["Sector"], g["Edges"], g["Nodes"], Normal[g["Masses"]], Normal[g["ExternalMasses"]], g["Momenta"]}, {g["Sector"], g["Message"]}], {g, graphs}], InputForm]];
runDigest[gd_String, sha_String] := hashString[gd <> sha <> ToString[$sofiaOptions, InputForm]];

$loadedSOFIA = None;

(* scr.m reads Global`SOFIAoptionEffortlessPath (Effortless, for letters only): an empty local file, so that nothing loads
   from the network. It is loaded with $ContextPath restored afterwards (its public one-letter symbols never shadow
   anything) and its output goes to the log *)
loadSOFIA[path_String, log_] := Module[{empty = FileNameJoin[{$TemporaryDirectory, "pfb_sofia_noeffortless_" <> ToString[$ProcessID] <> ".m"}]},
  If[$loadedSOFIA === path, Return[True]];
  If[$loadedSOFIA =!= None, Return[False]];
  Export[empty, "Null", "Text"];
  Global`SOFIAoptionEffortlessPath = empty; Global`SOFIAoptionFiniteFlow = False; Global`SOFIAoptionJulia = False;
  Block[{$ContextPath = {"System`"}, $Context = "PFBSOFIALoad`", $Output = {log}, $Messages = {log}}, Quiet[Get[path]]];
  Quiet[DeleteFile[empty]];
  If[MemberQ[$Packages, "SOFIA`"] && DownValues[Evaluate[sofiaSym["SOFIA"]]] =!= {}, $loadedSOFIA = path; True, False]];

sofiaMass[0] := 0;
sofiaMass[x_String] := Subscript[sofiaSym[StringTake[x, 1]], ToExpression[StringDrop[x, 1]]];

(* SOFIA's run-time symbols (s12, MM1, x1, ...), made with ToExpression in the current context, become PFBSOFIAVar names *)
named[e_] := e /. x_Symbol /; Context[x] =!= "System`" :> PFBSOFIAVar[SymbolName[x]];

$warningPattern = RegularExpression["(?i)(warning|cannot|degenerate|skipped|something is wrong|reconsider|\\$Failed|::)"];

runGraph[fam_, g_, limit_, logFile_] := Module[{diag, opts, str, t, res, subs, raw, txt, warn},
  diag = {{#[[1]], sofiaMass[#[[2]]]} & /@ g["Edges"], {#[[1]], sofiaMass[#[[2]]]} & /@ g["Nodes"]};
  opts = (sofiaSym[#[[1]]] -> #[[2]]) & /@ $sofiaOptions;
  str = OpenWrite[logFile, PageWidth -> Infinity];
  {t, res, raw, subs} = Block[{$Output = {str}, $Messages = {str}, $Context = "PFBSOFIAOut`", $ContextPath = {"SOFIA`", "System`"}},
    Module[{tt, rr, hk = sofiaSym["homogeneizeKin"], ms},
      {tt, rr} = AbsoluteTiming[TimeConstrained[CheckAbort[sofiaSym["SOFIA"][diag, Sequence @@ opts], $Aborted], limit, $timedOut]];
      ms = Quiet[sofiaSym["MySubstitutions"]];
      {tt, rr, If[ListQ[rr], named[hk[rr]], None],
       If[ListQ[ms], Cases[ms, Rule[CenterDot[Subscript[_, i_Integer], Subscript[_, j_Integer]], v_] :> ({i, j} -> named[hk[v]])], {}]}]];
  Close[str];
  txt = Quiet@ReadString[logFile]; If[! StringQ[txt], txt = ""];
  warn = Take[DeleteDuplicates[StringTake[#, UpTo[300]] & /@ Select[StringTrim /@ StringSplit[txt, "\n"], StringContainsQ[#, $warningPattern] &]], UpTo[30]];
  <|"Seconds" -> N[Round[10 t]/10], "Result" -> res, "Raw" -> raw, "Subs" -> subs, "Warnings" -> warn, "LogText" -> txt|>];

graphRecord[fam_, g_, r_] := Module[{rec = KeyTake[g, {"Sector", "Name", "Input", "Edges", "Nodes", "Lines", "Momenta", "Masses", "ExternalMasses", "Loops", "Source", "SymanzikCheck"}], ren, chk},
  rec["Seconds"] = r["Seconds"]; rec["Warnings"] = r["Warnings"];
  Which[
    r["Result"] === $timedOut, rec["Status"] = "timeout"; rec["Message"] = "SOFIA did not finish within the time limit (--time-limit S, 0 for none)",
    ! ListQ[r["Raw"]], rec["Status"] = "failed"; rec["Message"] = "SOFIA returned " <> ToString[Short[r["Result"], 2], InputForm] <> " instead of a list of polynomials (see the log)",
    True,
      ren = PFBSOFIARename[fam, g, r["Raw"]];
      chk = If[r["Subs"] === {}, "not available", PFBSOFIAKinematicsCheck[fam, g, r["Subs"]]];
      rec["Raw"] = sofiaString /@ r["Raw"];
      rec["Rename"] = ren["Rules"]; rec["Vanishing"] = ren["Vanishing"]; rec["Unrenamed"] = ren["Unrenamed"];
      rec["KinematicsCheck"] = If[chk === {}, "agrees", chk];
      If[ListQ[chk] && chk =!= {},
        rec["Status"] = "kinematics mismatch"; rec["Polynomials"] = {};
        rec["Message"] = "SOFIA's kinematics differ from the family's at " <> ToString[chk[[All, 1]]] <> ": its polynomials are not used",
        rec["Status"] = "done"; rec["Polynomials"] = ren["Polynomials"];
        rec["Message"] = ToString[Length[ren["Polynomials"]]] <> " irreducible polynomials" <>
          If[ren["Vanishing"] === {}, "", "; " <> ToString[Length[ren["Vanishing"]]] <> " of SOFIA's polynomials vanish at the family's kinematics (special kinematics for this graph: the list may miss singularities there)"] <>
          If[ren["Unrenamed"] === {}, "", "; " <> ToString[Length[ren["Unrenamed"]]] <> " could not be renamed"] <>
          If[chk === "not available", "; SOFIA's kinematics could not be read back (not checked)", ""]]];
  rec];

capLog[s_String] := If[StringLength[s] <= 4*^6, s, StringTake[s, 10^6] <> "\n[... " <> ToString[StringLength[s] - 4*^6] <> " characters left out ...]\n" <> StringTake[s, -3*^6]];

runFamily[sys_, dir_, fn_, info_, opts_] := Module[{fo = PFBFamily[sys, fn], secs, graphs, gd, rd, old, cdir, file, logf, logs = "", recs = {}, r, tmp, limit, st, polys, cache, t0 = AbsoluteTime[]},
  secs = PFBSingularityGraphs[sys, fn];
  graphs = PFBSOFIAGraph[fo, #] & /@ secs;
  gd = graphsDigest[graphs]; rd = runDigest[gd, info["SHA256"]];
  cdir = FileNameJoin[{dir, "singularities"}];
  file = PFBSingularitiesFile[dir, fn]; logf = FileNameJoin[{cdir, ToString[fn] <> ".log"}];
  old = PFBReadSingularities[dir, fn];
  If[AssociationQ[old] && Lookup[old, "Digest", None] === rd && Lookup[old, "Status", None] === "done" && ! TrueQ[Lookup[opts, "Force", False]],
    Print["  ", fn, ": unchanged since ", old["Date"], " (", Length[old["Polynomials"]], " polynomials); --force recomputes"];
    Return[Join[old, <|"Reused" -> True|>]]];
  If[! DirectoryQ[cdir], CreateDirectory[cdir, CreateIntermediateDirectories -> True]];
  limit = Replace[Lookup[opts, "TimeLimit", 3600], 0 | None -> Infinity];
  Do[
    If[! TrueQ[g["OK"]],
      Print["  ", fn, "/", g["Name"], ": not applicable: ", g["Message"]];
      AppendTo[recs, <|"Sector" -> g["Sector"], "Name" -> g["Name"], "Status" -> "not applicable", "Message" -> g["Message"]|>]; Continue[]];
    Print["  ", fn, "/", g["Name"], ": SOFIA on ", g["Input"]];
    tmp = FileNameJoin[{cdir, ToString[fn] <> "_" <> g["Name"] <> ".tmp"}];
    r = runGraph[fo, g, limit, tmp];
    Quiet[DeleteFile[tmp]];
    logs = logs <> "==== " <> ToString[fn] <> "/" <> g["Name"] <> " " <> g["Input"] <> " ====\n" <> r["LogText"] <> "\n";
    AppendTo[recs, graphRecord[fo, g, r]];
    Print["  ", fn, "/", g["Name"], ": ", Last[recs]["Status"], ", ", Last[recs]["Message"], " (", r["Seconds"], " s, ", Length[r["Warnings"]], " warnings)"],
    {g, graphs}];
  st = Which[
    recs === {}, "not applicable",
    AllTrue[recs, #["Status"] === "done" &], "done",
    AnyTrue[recs, #["Status"] === "done" &], "partial",
    AllTrue[recs, #["Status"] === "not applicable" &], "not applicable",
    AnyTrue[recs, #["Status"] === "timeout" &], "timeout",
    True, "failed"];
  polys = PFBNormalizePolynomials[Flatten[Lookup[Select[recs, #["Status"] === "done" &], "Polynomials", {}]], fo["InvList"]];
  Export[logf, capLog[logs], "Text"];
  cache = <|"Family" -> ToString[fn], "Date" -> PFBTimeStamp[], "Status" -> st, "Polynomials" -> polys, "Invariants" -> fo["InvList"],
    "Graphs" -> recs, "SOFIA" -> KeyDrop[info, {"OK", "Message"}], "Options" -> (ToString[#[[1]]] <> " -> " <> ToString[#[[2]], InputForm] & /@ $sofiaOptions),
    "TimeLimit" -> limit, "Seconds" -> N[Round[10 (AbsoluteTime[] - t0)]/10], "Warnings" -> Flatten[Table[(rr["Name"] <> ": " <> #) & /@ Lookup[rr, "Warnings", {}], {rr, recs}]],
    "Log" -> FileNameJoin[{"singularities", ToString[fn] <> ".log"}], "GraphsDigest" -> gd, "Digest" -> rd, "Mathematica" -> $Version|>;
  Put[cache, file];
  cache];

PFBRunSingularities[ctx_Association, fams_ : All, opts_Association : <||>] := Module[{sys = ctx["System"], dir = ctx["Dir"], path, info, list, out = <||>, log, ok, lf},
  path = Lookup[opts, "SOFIA", PFBSOFIAPath[]];
  If[! StringQ[path], Return[<|"Status" -> "skipped", "Message" -> $notConfigured, "Families" -> <||>|>]];
  info = PFBSOFIAInfo[path];
  If[! info["OK"], Return[<|"Status" -> "refused", "Message" -> info["Message"], "Families" -> <||>|>]];
  list = DeleteDuplicates[PFBBaseOf[sys, #] & /@ If[fams === All, sys["Order"], famSym /@ Flatten[{fams}]]];
  Print["SOFIA: ", info["Message"]];
  If[! DirectoryQ[FileNameJoin[{dir, "singularities"}]], CreateDirectory[FileNameJoin[{dir, "singularities"}], CreateIntermediateDirectories -> True]];
  lf = FileNameJoin[{dir, "singularities", "load.log"}];
  log = OpenWrite[lf, PageWidth -> Infinity];
  ok = loadSOFIA[path, log];
  Close[log];
  If[! ok, Return[<|"Status" -> "error", "Message" -> "SOFIA did not load from " <> path <> " (its output is in singularities/load.log)", "Families" -> <||>|>]];
  Quiet[DeleteFile[lf]];
  (* SOFIA is credited in the run's ledger for each family whose polynomials it gave (a cache kept unchanged included) *)
  Do[out[fn] = runFamily[sys, dir, fn, info, opts];
    If[MemberQ[{"done", "partial"}, Lookup[out[fn], "Status", None]],
      CoreRecordTool[dir, "SOFIA", "candidate singularities of " <> ToString[fn], "Sector" -> "whole run"]], {fn, list}];
  <|"Status" -> "done", "Message" -> ToString[Length[list]] <> " families", "Families" -> out, "SOFIA" -> info|>];


(* ::Section:: *)
(*Known singularities*)


familyLetters[sys_, base_] := DeleteDuplicates[Join[Lookup[sys, "Letters", {}], Lookup[PFBFamily[sys, base], "Letters", {}]]];

acceptedQ[sys_, base_] := TrueQ[Lookup[sys["Families"][base]["Entry"], "LettersFromSOFIA", False]];

PFBKnownSingularities[ctx_Association, fam_] := PFBKnownSingularities[ctx["System"], ctx["Dir"], fam];
PFBKnownSingularities[sys_Association, dir_, All] := Association[Table[fn -> PFBKnownSingularities[sys, dir, fn], {fn, sys["Order"]}]];
PFBKnownSingularities[sys_Association, dir_, fam0_] := Module[{fn = famSym[fam0], base, im, fo, invs, lets, cache, sofia = {}, status, acc, letters, known, src, prov},
  base = PFBBaseOf[sys, fn]; im = sys["Families"][fn]["Image"];
  fo = PFBFamily[sys, fn]; invs = fo["InvList"];
  lets = familyLetters[sys, base];
  cache = If[StringQ[dir], PFBReadSingularities[dir, base], Missing["NotRun"]];
  status = Which[
    ! AssociationQ[cache], "not run",
    Lookup[cache, "GraphsDigest", None] =!= graphsDigest[PFBSOFIAGraph[PFBFamily[sys, base], #] & /@ PFBSingularityGraphs[sys, base]], "stale",
    True, cache["Status"]];
  If[MemberQ[{"done", "partial"}, status], sofia = cache["Polynomials"]];
  If[im =!= None, lets = lets /. im["InvariantMap"]; sofia = sofia /. im["InvariantMap"]];
  lets = PFBNormalizePolynomials[lets, invs]; sofia = PFBNormalizePolynomials[sofia, invs];
  acc = acceptedQ[sys, base];
  known = DeleteDuplicates[Join[lets, sofia]];
  src = Table[Join[If[MemberQ[lets, p], {"Letters"}, {}], If[MemberQ[sofia, p], {"SOFIA"}, {}]], {p, known}];
  letters = If[acc, DeleteDuplicates[Join[lets, sofia]], lets];
  prov = If[AssociationQ[cache],
    <|"File" -> PFBSingularitiesFile[dir, base], "Date" -> cache["Date"], "Status" -> cache["Status"], "SOFIA" -> cache["SOFIA"], "Options" -> cache["Options"],
      "Warnings" -> cache["Warnings"], "Graphs" -> ({#["Name"], #["Status"]} & /@ cache["Graphs"])|>, <||>];
  <|"Family" -> fn, "Base" -> base, "Invariants" -> invs, "Known" -> known, "Sources" -> src, "Letters" -> letters, "SOFIA" -> sofia,
    "SOFIAStatus" -> status, "Accepted" -> acc, "Offer" -> (lets === {} && sofia =!= {} && ! acc), "Provenance" -> prov|>];

listText[l_List, n_Integer] := StringRiffle[ToString[#, InputForm] & /@ Take[l, UpTo[n]], ", "] <> If[Length[l] > n, ", ... (" <> ToString[Length[l] - n] <> " more)", ""];

PFBSingularityOffers[sys_Association, dir_] := Module[{out = {}, k},
  If[! StringQ[dir], Return[{}]];
  Do[If[sys["Families"][fn]["Image"] === None && FileExistsQ[PFBSingularitiesFile[dir, fn]] && familyLetters[sys, fn] === {} && ! acceptedQ[sys, fn],
      k = PFBKnownSingularities[sys, dir, fn];
      If[TrueQ[k["Offer"]], AppendTo[out, <|"Family" -> fn, "Count" -> Length[k["SOFIA"]], "File" -> PFBSingularitiesFile[dir, fn],
         "Message" -> "family " <> ToString[fn] <> " has no \"Letters\"; SOFIA lists " <> ToString[Length[k["SOFIA"]]] <> " candidate singularities (" <>
           FileNameJoin[{"singularities", ToString[fn] <> ".m"}] <> "): " <> listText[k["SOFIA"], 8] <>
           ". Use them as its letters (the gate's letter check, and every use of the family's letters)? Only with the user's yes, set \"LettersFromSOFIA\" -> True in the family's entry of system.wl."|>]]],
    {fn, sys["Order"]}];
  out];

PFBValidateSystem[sys_Association, dir_] := Module[{v = PFBValidateSystem[sys], att},
  If[! StringQ[dir] || ! DirectoryQ[dir], Return[v]];
  att = PFBAttachSOFIALetters[sys, dir];
  v["Warnings"] = Join[v["Warnings"], KeyValueMap[ToString[#1] <> ": \"LettersFromSOFIA\" is set, but its SOFIA cache is " <> #2 <> ": run bin/singularities.wls" &, att["SOFIALettersMissing"]]];
  v["Questions"] = Join[v["Questions"], #["Message"] & /@ PFBSingularityOffers[sys, dir]];
  v];

PFBAttachSOFIALetters[sys0_Association, dir_] := Module[{sys = sys0, got = <||>, miss = <||>, k},
  Do[If[sys["Families"][fn]["Image"] === None && acceptedQ[sys, fn],
      k = PFBKnownSingularities[sys0, dir, fn];
      If[k["SOFIA"] =!= {}, got[fn] = k["SOFIA"], miss[fn] = k["SOFIAStatus"]]],
    {fn, sys["Order"]}];
  sys["SOFIALetters"] = got; sys["SOFIALettersMissing"] = miss;
  sys];


End[];
EndPackage[];
