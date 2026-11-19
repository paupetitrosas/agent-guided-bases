(* ::Package:: *)

(* ::Title:: *)
(*SkillCore`Tools`: the registry of tools and methods, paths, tool detection, isolated loading, preflight, kernel*)
(*budget, scratch (shared by both skills)*)


BeginPackage["SkillCore`Tools`", {"SkillCore`"}];

$MCBTools::usage = "$MCBTools is an Association with the metadata of every tool and method that can be credited: kind (\"package\", \"binary\", \"library\"; \"method\" and \"external\" are never loaded or detected), display name, file names, context, role, install hint, citation.";
$MCBPaths::usage = "$MCBPaths is the Association tool -> path currently in use (detected or set).";
MCBDetectTools::usage = "MCBDetectTools[] (or MCBDetectTools[{tools}]) searches for every tool (or those listed) and returns an Association tool -> path (or Missing[\"NotFound\"]). It changes $MCBPaths only to record FiniteFlow when no path was set, so that its library is looked for next to it.";
MCBLoadPaths::usage = "MCBLoadPaths[file] merges the Association in file (paths.wl) over the detected paths and sets $MCBPaths and $MCBPathsFile. MCBLoadPaths[Automatic] only detects.";
$MCBPathsFile::usage = "$MCBPathsFile is the paths.wl that MCBLoadPaths read last (None when the paths were only detected). The preflight log names it, since its table holds for those paths only.";
MCBToolsLine::usage = "MCBToolsLine[] is a short text on the tools of the current paths (found or missing, without the preflight's tests) and the steps they allow, with a note when the cached preflight log was made with another paths.wl.";
MCBSetPath::usage = "MCBSetPath[tool, path] sets the path of one tool (use it when the user just tells you where a tool is).";
MCBPath::usage = "MCBPath[tool] returns the path of tool, or Missing[\"NotFound\"].";
MCBAvailableQ::usage = "MCBAvailableQ[tool] is True if the path of tool is known and exists.";
MCBLoadTool::usage = "MCBLoadTool[tool] loads a Mathematica tool without putting its context on $ContextPath. Returns True on success. Loading is not a use: the code that runs the tool marks it (MCBMarkToolUsed).";
MCBQualify::usage = "MCBQualify[context, name] returns the symbol context`name (fully qualified access to third-party symbols).";
MCBSetSymbol::usage = "MCBSetSymbol[context, name, value] assigns value to context`name without evaluating the symbol first (safe for third-party inputs such as BaikovPackage`Internal).";
MCBIsolatedGet::usage = "MCBIsolatedGet[file] loads file with $ContextPath restored afterwards, so the package contexts never shadow ours.";
MCBPreflight::usage = "MCBPreflight[logfile] loads every tool, runs a smoke test for each and writes a table to logfile (by default preflight.log in MCBCacheDir[], once per machine). Returns an Association step -> True/False plus the kernel budget. It is not a use of any tool: it marks nothing and leaves no pending mark.";
MCBKernelBudget::usage = "MCBKernelBudget[] returns the licence and CPU limits, the kernels running right now (RunningKernels, FreeKernels) and the suggested number of parallel queues.";
MCBRunningKernels::usage = "MCBRunningKernels[] counts the main Wolfram kernels running on this machine now (all sessions, this one included).";
MCBShell::usage = "MCBShell[cmd, dir] runs the shell command cmd in dir with stdin closed; returns the exit code.";
MCBPrint::usage = "MCBPrint[args] prints when $MCBVerbose is True.";
MCBCitations::usage = "MCBCitations[tools] returns the citation strings of the tools and methods named (names of the registry $MCBTools, as CoreToolKey reads them; \"Method\", the name in older records, stands for Baikov and CanonicalDE). An unknown name is a message and $Failed, never dropped.";
CoreToolKey::usage = "CoreToolKey[name] is the key in the registry $MCBTools of a tool or method name: the key itself, or the key or the display \"Name\" of an entry in any case (\"Kira\" and \"KIRA\" give kira, \"Fermat\" gives fer64); $Failed for any other name.";
$MCBSkip::usage = "$MCBSkip is the list of step names the user asked to skip.";
MCBSkippedQ::usage = "MCBSkippedQ[step] is True if step is in $MCBSkip.";
$MCBSteps::usage = "$MCBSteps lists the step names that can be skipped.";
$MCBKiraThreads::usage = "$MCBKiraThreads is the value passed to kira --parallel.";
MCBLimitCommand::usage = "MCBLimitCommand[seconds, GB] is the shell prefix that runs a command under core/bin/limit with that time and memory limit (None or 0: no limit; Automatic: limit's default). Kira runs this way.";
MCBJobLimits::usage = "MCBJobLimits[] = <|\"TimeLimit\" -> seconds, \"MemoryLimitGB\" -> GB, \"Start\" -> time, \"File\" -> registry|> of the job this kernel runs in (bin/ws starts every kernel under core/bin/limit; 0 = no limit), or Missing[\"NoJob\"].";
MCBMemoryHeadroom::usage = "MCBMemoryHeadroom[] is the memory (GB) this kernel's job may still use: its memory limit minus what its processes hold now, Infinity when it has no memory limit, or 90% of the memory available when the kernel runs outside a job.";
MCBToolsUsed::usage = "MCBToolsUsed[] returns the tools and methods this kernel marked as used (MCBMarkToolUsed) since the last MCBResetToolsUsed[]. The run's ledger (CoreReadCitations) keeps every use, of every kernel.";
MCBResetToolsUsed::usage = "MCBResetToolsUsed[] empties this kernel's marks, the pending ones included (called when a new sector starts); the uses already in the ledger stay.";
MCBMarkToolUsed::usage = "MCBMarkToolUsed[tool] records that tool (a name of $MCBTools: a tool, a method or an external program) produced something in this kernel. With a citation context ($CoreCitationContext) the use is appended to the run's ledger, citations.m, at once; without one it stays pending until the next CoreCitationContext. An unknown name (\"Method\" included) is a message and $Failed. Loading a tool is not a use.";
$MCBKeepScratch::usage = "$MCBKeepScratch: when True, the working folders of Kira jobs, of the scaling self-test and of the FiniteFlow check are kept after their results have been read. False by default (run.wl \"KeepScratch\" or the environment variable MCB_KEEP_SCRATCH=1 turn it on); a folder whose step failed is always kept.";
MCBPruneScratch::usage = "MCBPruneScratch[dir] deletes the working folder dir of a step whose result has been read, and the parent folders this leaves empty, up to the sector or run folder. Does nothing when $MCBKeepScratch is True.";
$MCBFFTimeLimit::usage = "$MCBFFTimeLimit is the time limit in seconds of each step of the FiniteFlow check (run.wl \"TimeLimits\" -> \"FiniteFlow\"); MCBWriteFFPipeline passes it to finiteflow_sector.sh, where MCB_FF_TIMELIMIT overrides it.";
$MCBFFMemoryLimit::usage = "$MCBFFMemoryLimit is the memory limit in GB of each step of the FiniteFlow check (run.wl \"MemoryLimits\" -> \"FiniteFlow\"; Automatic: the default of bin/ws); MCBWriteFFPipeline passes it to finiteflow_sector.sh, where MCB_FF_MEMORY overrides it.";
$MCBPFTimeLimit::usage = "$MCBPFTimeLimit is the time limit in seconds of the Picard-Fuchs step of one sector (run.wl \"TimeLimits\" -> \"PicardFuchs\", 300 by default); a step that runs out of it leaves the sector's classification \"not computed\".";
MCBCacheDir::usage = "MCBCacheDir[] is the folder for per-machine files of the skill (the kernel limit and preflight.log): $XDG_CACHE_HOME/maximal-cut-basis, or ~/.cache/maximal-cut-basis.";

Begin["`Private`"];


(* ::Section:: *)
(*Tool metadata*)


$MCBTools = <|
  "BaikovPackage" -> <|"Kind" -> "package", "Files" -> {"BaikovPackage.m"}, "Context" -> "BaikovPackage`",
     "Role" -> "loop-by-loop and standard Baikov representations (required for the Baikov steps)",
     "Install" -> "https://github.com/HjalteFrellesvig/BaikovPackage (single file BaikovPackage.m)",
     "Citation" -> "H. Frellesvig, The loop-by-loop Baikov representation - strategies and implementation, JHEP 04 (2025) 111, arXiv:2412.01804."|>,
  "DlogBasis" -> <|"Kind" -> "package", "Files" -> {"DlogBasis.wl"}, "Context" -> "DlogBasis`",
     "Role" -> "optional cross-check of the leading singularities of the final masters",
     "Install" -> "ancillary files of arXiv:2002.09492 (DlogBasis.wl)",
     "Citation" -> "J. Henn, B. Mistlberger, V. Smirnov, P. Wasser, Constructing d-log integrands and computing master integrals for three-loop four-particle scattering, JHEP 04 (2020) 167, arXiv:2002.09492."|>,
  "FiniteFlow" -> <|"Kind" -> "package", "Files" -> {"FiniteFlow.m"}, "Context" -> "FiniteFlow`",
     "Role" -> "analytic check of the maximal-cut DE, and the DE along a line of the picard-fuchs step (IBPs from LiteIBP, sparse solver and reconstruction)",
     "Install" -> "https://github.com/peraro/finiteflow (build it; FiniteFlow.m is in mathlink/, fflowmlink.so in the build dir)",
     "Citation" -> "T. Peraro, FiniteFlow: multivariate functional reconstruction using finite fields and dataflow graphs, JHEP 07 (2019) 031, arXiv:1905.08019."|>,
  "FiniteFlowLibrary" -> <|"Kind" -> "library", "Files" -> {"fflowmlink.so", "fflowmlink.dylib", "fflowmlink.dll"},
     "Role" -> "the MathLink library of FiniteFlow (directory added to $LibraryPath)",
     "Install" -> "built together with FiniteFlow", "Citation" -> None|>,
  "LiteRed" -> <|"Kind" -> "package", "Files" -> {"LiteRed2023.m", "LiteRed2024.m", "LiteRed.m"}, "Context" -> "LiteRed`",
     "Role" -> "sector analysis and IBP generation for the FiniteFlow pipeline (through LiteIBP)",
     "Install" -> "https://github.com/rnlee/LiteRed (LiteRed 2)",
     "Citation" -> "R. N. Lee, Presenting LiteRed: a tool for the Loop InTEgrals REDuction, arXiv:1212.2685; R. N. Lee, LiteRed 1.4: a powerful tool for reduction of multiloop integrals, J. Phys. Conf. Ser. 523 (2014) 012059, arXiv:1310.1145."|>,
  "LiteIBP" -> <|"Kind" -> "package", "Files" -> {"LiteIBP.m"}, "Context" -> "LiteIBP`",
     "Role" -> "IBP identities on the maximal cut for FiniteFlow (part of finiteflow-mathtools, not of FiniteFlow itself)",
     "Install" -> "https://github.com/peraro/finiteflow-mathtools (packages/LiteIBP.m)",
     "Citation" -> "T. Peraro, finiteflow-mathtools, https://github.com/peraro/finiteflow-mathtools (with arXiv:1905.08019)."|>,
  "INITIAL" -> <|"Kind" -> "package", "Files" -> {"INITIAL.m"}, "Context" -> "INITIAL`",
     "Role" -> "optional rung 6: canonical DE from one uniform-weight seed integral",
     "Install" -> "https://github.com/UT-team/INITIAL",
     "Citation" -> "C. Dlapa, J. Henn, K. Yan, Deriving canonical differential equations for Feynman integrals from a single uniform weight integral, JHEP 05 (2020) 025, arXiv:2002.02340."|>,
  "Libra" -> <|"Kind" -> "package", "Files" -> {"Libra.m", "Libra.wl"}, "Context" -> "Libra`",
     "Role" -> "optional rung 6: Lee's algorithm (reduction to eps-form)",
     "Install" -> "https://rnlee.bitbucket.io/Libra/",
     "Citation" -> "R. N. Lee, Libra: a package for transformation of differential systems for multiloop integrals, Comput. Phys. Commun. 267 (2021) 108058, arXiv:2012.00279."|>,
  "Fuchsia" -> <|"Kind" -> "binary", "Files" -> {"fuchsia"},
     "Role" -> "optional rung 6: univariate reduction to eps-form",
     "Install" -> "pip install fuchsia (Python, needs SageMath/SymPy per its docs)",
     "Citation" -> "O. Gituliar, V. Magerya, Fuchsia: a tool for reducing differential equations for Feynman master integrals to epsilon form, Comput. Phys. Commun. 219 (2017) 329, arXiv:1701.04269."|>,
  "kira" -> <|"Kind" -> "binary", "Name" -> "Kira", "Files" -> {"kira"},
     "Role" -> "numeric maximal-cut reductions (cut_propagators, --set_value); needs Kira >= 3",
     "Install" -> "https://kira.hepforge.org (Kira 3.x)",
     "Citation" -> "F. Lange, J. Usovitsch, Z. Wu, Kira 3: integral reduction with efficient seeding and optimized equation selection, Comput. Phys. Commun. 322 (2026) 109999, arXiv:2505.20197; J. Klappert, F. Lange, P. Maierhoefer, J. Usovitsch, Integral reduction with Kira 2.0 and finite field methods, Comput. Phys. Commun. 266 (2021) 108024, arXiv:2008.06494; P. Maierhoefer, J. Usovitsch, P. Uwer, Kira - A Feynman integral reduction program, Comput. Phys. Commun. 230 (2018) 99, arXiv:1705.05610."|>,
  "Baikov" -> <|"Kind" -> "method", "Name" -> "Baikov representation", "Files" -> {},
     "Role" -> "the Baikov representation and its cuts; cited where Baikov representations were built",
     "Install" -> "nothing to install",
     "Citation" -> "P. A. Baikov, Explicit solutions of the multiloop integral recurrence relations and its application, Nucl. Instrum. Meth. A 389 (1997) 347, arXiv:hep-ph/9611449; H. Frellesvig, C. G. Papadopoulos, Cuts of Feynman integrals in Baikov representation, JHEP 04 (2017) 083, arXiv:1701.07356."|>,
  "CanonicalDE" -> <|"Kind" -> "method", "Name" -> "Canonical differential equation", "Files" -> {},
     "Role" -> "the eps-factorised differential equation a basis is checked for; cited where a basis was checked for it",
     "Install" -> "nothing to install",
     "Citation" -> "J. M. Henn, Multiloop integrals in dimensional regularization made simple, Phys. Rev. Lett. 110 (2013) 251601, arXiv:1304.1806."|>,
  "Tarasov" -> <|"Kind" -> "method", "Name" -> "Dimension shift (Tarasov)", "Files" -> {},
     "Role" -> "dimensional recurrence used by the d0 shift (rung 3); cited only when the shift was used",
     "Install" -> "nothing to install",
     "Citation" -> "O. V. Tarasov, Connection between Feynman integrals having different values of the space-time dimension, Phys. Rev. D 54 (1996) 6479, arXiv:hep-th/9606018."|>,
  "PicardFuchs" -> <|"Kind" -> "method", "Name" -> "Picard-Fuchs classification (p-curvature)", "Files" -> {},
     "Role" -> "the p-curvature criteria of the picard-fuchs step (nilpotent for operators of geometric origin, zero for algebraic solutions); cited when the step labelled the sector",
     "Install" -> "nothing to install",
     "Citation" -> "N. M. Katz, Algebraic solutions of differential equations (p-curvature and the Hodge filtration), Invent. Math. 18 (1972) 1-118, doi:10.1007/BF01389714; N. M. Katz, Nilpotent connections and the monodromy theorem: applications of a result of Turrittin, Publ. Math. IHES 39 (1970) 175-232, doi:10.1007/BF02684688."|>,
  "fer64" -> <|"Kind" -> "binary", "Name" -> "Fermat", "Files" -> {"fer64", "ferl64"},
     "Role" -> "Fermat, used by Kira for rational-function arithmetic (FERMATPATH)",
     "Install" -> "http://home.bway.net/lewis/ (Fermat)",
     "Citation" -> "R. H. Lewis, Computer Algebra System Fermat, http://home.bway.net/lewis/."|>,
  (* programs that run outside this kernel: credited when declared or recorded, never detected or loaded here *)
  "SOFIA" -> <|"Kind" -> "external", "Files" -> {},
     "Role" -> "candidate singularities of each family (pole-free-basis bin/singularities.wls, in its own kernel)",
     "Install" -> "https://github.com/StrangeQuark007/SOFIA at the commit of pole-free-basis reference/tools.md; \"SOFIA\" -> its scr.m in paths.wl",
     "Citation" -> "M. Correia, M. Giroux, S. Mizera, SOFIA: Singularities of Feynman Integrals Automatized, Comput. Phys. Commun. 320 (2026) 109970, arXiv:2503.16601."|>,
  "ore_algebra" -> <|"Kind" -> "external", "Files" -> {},
     "Role" -> "factorisation of an unresolved Picard-Fuchs block (SageMath, run by the user outside the toolkit)",
     "Install" -> "sage -pip install --user --no-build-isolation git+https://github.com/mkauers/ore_algebra.git",
     "Citation" -> "M. Kauers, M. Jaroschek, F. Johansson, Ore Polynomials in Sage, Lect. Notes Comput. Sci. 8942 (2015) 105-125, arXiv:1306.4263; F. Chyzak, A. Goyer, M. Mezzarobba, Symbolic-Numeric Factorization of Differential Operators, Proc. ISSAC '22 (ACM, 2022) 73-82, arXiv:2205.08991."|>
|>;

(* kinds that are credited but never detected, loaded or tested *)
creditOnlyQ[tool_String] := MemberQ[{"method", "external"}, Lookup[Lookup[$MCBTools, tool, <||>], "Kind", None]];


(* ::Section:: *)
(*Small helpers*)


MCBPrint[args___] := If[TrueQ[MaximalCutBasis`$MCBVerbose], Print[args]];

MCBQualify[ctx_String, name_String] := Symbol[StringTrim[ctx, "`"] <> "`" <> name];

MCBSetSymbol[ctx_String, name_String, value_] := ToExpression[StringTrim[ctx, "`"] <> "`" <> name, InputForm, Function[sym, sym = value, HoldFirst]];

MCBIsolatedGet[file_String] := Block[{$ContextPath = $ContextPath}, Quiet[Get[file]]];

$MCBSkip = {};
$MCBSteps = {"preflight", "validate-family", "find-masters", "baikov", "picard-fuchs", "candidates", "kira-check",
   "escalate", "literature", "d0-shift", "agent-candidates", "algorithms",
   "finiteflow", "dlogbasis-crosscheck", "draw", "reports"};
MCBSkippedQ[step_String] := MemberQ[$MCBSkip, step];

$MCBKiraThreads = Max[1, Min[4, $ProcessorCount]];

(* every heavy process runs under core/bin/limit: a time limit and a memory limit on it and everything below it *)
limitScript[] := FileNameJoin[{SkillCore`$CoreRoot, "bin", "limit"}];
limitArg[x_] := Which[x === Automatic, None, x === None || x === Infinity, "0", NumericQ[x], ToString[Round[x, 0.01] // N, InputForm], True, None];
MCBLimitCommand[t_, m_] := StringJoin[quote[limitScript[]],
  With[{a = limitArg[t]}, If[a === None, "", " --timeout " <> ToString[Round[ToExpression[a]]]]],
  With[{a = limitArg[m]}, If[a === None, "", " --memory " <> a]], " -- "];

MCBJobLimits[] := Module[{f = Environment["MCB_LIMIT_JOB"], lines, l},
  If[! StringQ[f] || ! FileExistsQ[f], Return[Missing["NoJob"]]];
  lines = Quiet@Check[ReadList[f, String], {}];
  l = If[ListQ[lines] && Length[lines] >= 2, StringSplit[lines[[2]]], {}];
  If[Length[l] < 4 || l[[1]] =!= "limits", Return[Missing["NoJob"]]];
  <|"TimeLimit" -> ToExpression[l[[2]]], "MemoryLimitGB" -> N[ToExpression[l[[3]]]/1048576], "Start" -> ToExpression[l[[4]]], "File" -> f|>];

MCBMemoryHeadroom[] := Module[{r = Quiet@RunProcess[{limitScript[], "--headroom"}], v},
  If[! AssociationQ[r] || r["ExitCode"] =!= 0, Return[Missing["Unknown"]]];
  v = StringTrim[r["StandardOutput"]];
  Which[v === "none", Infinity, StringMatchQ[v, DigitCharacter ..], N[ToExpression[v]/1048576], True, Missing["Unknown"]]];

(* MCBMarkToolUsed, MCBToolsUsed and MCBResetToolsUsed are defined with the ledger, in Citations.wl *)

(* a name as the user or the agent writes it: the key, or the key or the display name in another case *)
CoreToolKey[name_String] := If[KeyExistsQ[$MCBTools, name], name, With[{n = ToLowerCase[StringTrim[name]]},
  SelectFirst[Keys[$MCBTools], ToLowerCase[#] === n || ToLowerCase[Lookup[$MCBTools[#], "Name", #]] === n &, $Failed]]];
CoreToolKey[_] := $Failed;

MCBCitations::unknown = "Not in the registry of tools and methods ($MCBTools): `1`. The known names are `2`.";
MCBCitations[tools_List] := Module[{names = Flatten[Replace[tools, "Method" -> {"Baikov", "CanonicalDE"}, {1}]], keys},
  keys = CoreToolKey /@ names;
  If[MemberQ[keys, $Failed], Message[MCBCitations::unknown, StringRiffle[ToString[#, InputForm] & /@ DeleteDuplicates[Pick[names, keys, $Failed]], ", "],
      StringRiffle[Keys[$MCBTools], ", "]]; Return[$Failed]];
  DeleteDuplicates[DeleteCases[Lookup[$MCBTools[#], "Citation", None] & /@ keys, None]]];

(* Working folders of Kira jobs and the self-test are read into memory and never looked at again; they make up most
   of the files of a run, so they are deleted once read. A folder whose step failed is kept for diagnosis. *)
$MCBKeepScratch = Environment["MCB_KEEP_SCRATCH"] === "1";
$MCBFFTimeLimit = 3600;
$MCBFFMemoryLimit = Automatic;
$MCBPFTimeLimit = 300;
MCBPruneScratch[dir_String] := Module[{d},
  If[TrueQ[$MCBKeepScratch] || ! DirectoryQ[dir], Return[Null]];
  Quiet@DeleteDirectory[dir, DeleteContents -> True];
  (* empty parents go too (kira/check/pt1 -> kira/check -> kira), never a sector folder; DeleteDirectory without
     DeleteContents fails on a folder that still holds anything, which ends the walk *)
  d = FileNameDrop[ExpandFileName[dir], -1];
  While[DirectoryQ[d] && ! StringMatchQ[FileNameTake[d], RegularExpression["j[01]+"]] && Quiet[DeleteDirectory[d]] === Null,
    d = FileNameDrop[d, -1]];
  Null];

MCBCacheDir[] := FileNameJoin[{Replace[Environment["XDG_CACHE_HOME"], $Failed :> FileNameJoin[{$HomeDirectory, ".cache"}]], "maximal-cut-basis"}];

MCBShell[cmd_String, dir_String : "."] := Module[{r},
  r = RunProcess[{"/bin/sh", "-c", "cd " <> quote[dir] <> " && " <> cmd <> " < /dev/null"}];
  If[AssociationQ[r], r["ExitCode"], -1]];

quote[s_String] := "'" <> StringReplace[s, "'" -> "'\\''"] <> "'";


(* ::Section:: *)
(*Detection*)


$searchRoots := DeleteDuplicates@Select[Join[
     {FileNameJoin[{$UserBaseDirectory, "Applications"}], FileNameJoin[{$BaseDirectory, "Applications"}]},
     FileNameJoin[{$HomeDirectory, #}] & /@ {"software", "src", "opt", "local", ".local", "Mathematica", "packages"},
     {"/opt", "/usr/local/share"}], DirectoryQ];

(* under WSL, packages are often installed with the Windows Mathematica: its Applications folders (found once per
   kernel). The Windows file system is slow from Linux, so they are searched last, for packages only, and less deep *)
$wslApplications := $wslApplications = If[$OperatingSystem === "Unix" && DirectoryQ["/mnt/c/Users"] &&
     (FileExistsQ["/proc/sys/fs/binfmt_misc/WSLInterop"] || StringContainsQ[Quiet[Import["/proc/version", "Text"]], "microsoft", IgnoreCase -> True]),
   Quiet@FileNames["*/AppData/Roaming/Mathematica/Applications", "/mnt/c/Users"], {}];

envName[tool_String] := "MCB_" <> ToUpperCase[StringReplace[tool, Except[WordCharacter] -> "_"]];

findFileIn[names_List, roots_List, depth_Integer] := Module[{hits},
  Do[
    hits = Quiet@FileNames[nm, roots, depth];
    If[hits =!= {}, Return[First[SortBy[hits, StringLength]], Module]],
    {nm, names}];
  Missing["NotFound"]];

which[prog_String] := Module[{r = Quiet@RunProcess[{"/bin/sh", "-c", "command -v " <> prog}]},
  If[AssociationQ[r] && r["ExitCode"] === 0 && StringTrim[r["StandardOutput"]] =!= "",
    StringTrim[r["StandardOutput"]], Missing["NotFound"]]];

detectOne[tool_String] := Module[{meta = $MCBTools[tool], env, ff, p},
  If[creditOnlyQ[tool], Return[Missing["NotApplicable"]]];
  env = Environment[envName[tool]];
  If[StringQ[env] && (FileExistsQ[env]), Return[ExpandFileName[env]]];
  Switch[meta["Kind"],
    "binary",
      If[tool === "fer64", env = Environment["FERMATPATH"]; If[StringQ[env] && FileExistsQ[env], Return[ExpandFileName[env]]]];
      Do[p = which[f]; If[StringQ[p], Return[p, Module]], {f, meta["Files"]}];
      findFileIn[meta["Files"], FileNameJoin[{$HomeDirectory, #}] & /@ {"bin", "software/bin", ".local/bin"} // Select[DirectoryQ], 1],
    "library",
      p = MCBPath["FiniteFlow"];
      If[StringQ[p],
        ff = findFileIn[meta["Files"], Select[{DirectoryName[p], ParentDirectory[DirectoryName[p]]}, DirectoryQ], 2];
        If[StringQ[ff], Return[DirectoryName[ff], Module]]];
      ff = findFileIn[meta["Files"], Join[$LibraryPath, $searchRoots] // Select[DirectoryQ], 4];
      If[StringQ[ff], DirectoryName[ff], Missing["NotFound"]],
    "package",
      ff = Quiet@FindFile[meta["Context"]];
      If[StringQ[ff] && (tool =!= "LiteRed" || StringContainsQ[FileBaseName[ff], "LiteRed"]), Return[ff, Module]];
      Do[ff = Quiet@FindFile[f]; If[StringQ[ff], Return[ff, Module]], {f, meta["Files"]}];
      ff = findFileIn[meta["Files"], Join[Select[$Path, DirectoryQ[#] && # =!= "." &], $searchRoots], 4];
      If[StringQ[ff] || $wslApplications === {}, ff, findFileIn[meta["Files"], $wslApplications, 3]]]];

MCBDetectTools[tools_ : All] := Module[{res = <||>},
  (* FiniteFlow first: the library is searched next to it *)
  Do[res[t] = detectOne[t]; If[t === "FiniteFlow" && StringQ[res[t]] && ! StringQ[$MCBPaths[t]], $MCBPaths[t] = res[t]],
    {t, If[tools === All, Keys[$MCBTools], Select[Keys[$MCBTools], MemberQ[tools, #] &]]}];
  res];

If[! AssociationQ[$MCBPaths], $MCBPaths = <||>];
If[! ValueQ[$MCBPathsFile], $MCBPathsFile = None];

MCBLoadPaths[Automatic] := ($MCBPathsFile = None; $MCBPaths = Join[MCBDetectTools[], Select[$MCBPaths, StringQ]]; $MCBPaths);
MCBLoadPaths[file_String] := Module[{user},
  user = If[FileExistsQ[file], Get[file], <||>];
  $MCBPathsFile = If[FileExistsQ[file], ExpandFileName[file], None];
  If[! AssociationQ[user], Print["MCBLoadPaths: ", file, " does not evaluate to an Association; ignored."]; user = <||>];
  (* relative paths are relative to paths.wl: Kira runs in its job folders, where a path relative to the launch folder fails *)
  user = Map[If[StringQ[#] && ! StringStartsQ[#, "/" | "~"] && ! StringMatchQ[#, RegularExpression["[A-Za-z]:.*"]],
      ExpandFileName[FileNameJoin[{DirectoryName[ExpandFileName[file]], #}]], If[StringQ[#], ExpandFileName[#], #]] &, user];
  (* user entries first, so that the library is searched next to a user-given FiniteFlow *)
  $MCBPaths = Select[user, StringQ];
  (* only the tools paths.wl leaves out are looked for: detection costs seconds at every kernel start *)
  $MCBPaths = Join[MCBDetectTools[Complement[Keys[$MCBTools], Keys[$MCBPaths]]], $MCBPaths];
  $MCBPaths];

MCBSetPath[tool_String, path_String] := ($MCBPaths[tool] = ExpandFileName[path]; $loaded = KeyDrop[$loaded, tool]; path);

MCBPath[tool_String] := Lookup[$MCBPaths, tool, Missing["NotFound"]];

MCBAvailableQ[tool_String] := With[{p = MCBPath[tool]}, StringQ[p] && (FileExistsQ[p] || DirectoryQ[p])];


(* ::Section:: *)
(*Isolated loading*)


$loaded = <||>;

dirOf[p_String] := If[DirectoryQ[p], p, DirectoryName[p]];

MCBLoadTool[tool_String] := Module[{p = MCBPath[tool], ok = False, ctx},
  If[TrueQ[$loaded[tool]], Return[True]];
  If[creditOnlyQ[tool] || ! MCBAvailableQ[tool], Return[False]];
  ctx = Lookup[$MCBTools[tool], "Context", None];
  Switch[tool,
    "FiniteFlow",
      (* first on $LibraryPath: a copy in the user's SystemFiles/LibraryResources would otherwise shadow the configured library *)
      If[MCBAvailableQ["FiniteFlowLibrary"], $LibraryPath = DeleteDuplicates[Prepend[$LibraryPath, MCBPath["FiniteFlowLibrary"]]]];
      $Path = DeleteDuplicates[Append[$Path, dirOf[p]]];
      Block[{$ContextPath = $ContextPath}, Quiet[Needs["FiniteFlow`", FileNameJoin[{dirOf[p], "FiniteFlow.m"}]]]],
    "LiteIBP",
      If[! (MCBLoadTool["FiniteFlow"] && MCBLoadTool["LiteRed"]), Return[False]];
      $Path = DeleteDuplicates[Append[$Path, dirOf[p]]];
      Block[{$ContextPath = $ContextPath}, Quiet[Needs["LiteIBP`", FileNameJoin[{dirOf[p], "LiteIBP.m"}]]]],
    "LiteRed",
      $Path = DeleteDuplicates[Append[$Path, dirOf[p]]];
      Block[{$ContextPath = $ContextPath}, Quiet[Get[If[DirectoryQ[p], FileNameJoin[{p, "LiteRed2023.m"}], p]]]],
    _,
      If[ctx === None, Return[False]];
      Block[{Print = (Null &)}, MCBIsolatedGet[p]]];
  ok = ctx =!= None && MemberQ[$Packages, ctx];
  If[ok, $loaded[tool] = True];
  ok];


(* ::Section:: *)
(*Kernel budget*)


(* main Wolfram kernels running on this machine now (subkernels excluded), this one included *)
MCBRunningKernels[] := Module[{r = Quiet@RunProcess[{"/bin/sh", "-c",
      "ps -eo ucomm=,args= | awk '$1 ~ /(WolframKernel|MathKernel)$/ && $0 !~ /-subkernel/' | wc -l"}]},
  If[AssociationQ[r] && r["ExitCode"] === 0, ToExpression[StringTrim[r["StandardOutput"]]], Missing["Unknown"]]];

MCBKernelBudget[] := Module[{lic = $MaxLicenseProcesses, sub = $MaxLicenseSubprocesses, cpu = $ProcessorCount, run = MCBRunningKernels[]},
  <|"MaxLicenseProcesses" -> lic, "MaxLicenseSubprocesses" -> sub, "ProcessorCount" -> cpu,
    "RunningKernels" -> run, "FreeKernels" -> If[NumericQ[lic] && IntegerQ[run], Max[0, lic - run], Missing["Unknown"]],
    (* one kernel is left free for the user; each queue also runs Kira with $MCBKiraThreads threads *)
    "Parallel" -> Max[1, Min[If[NumericQ[lic], lic - 1, 8], Floor[cpu/$MCBKiraThreads]]],
    "FiniteFlowKernels" -> Max[1, Min[If[NumericQ[sub], sub, 4], cpu, 4]]|>];


(* ::Section:: *)
(*Preflight*)


tryTest[f_] := Quiet[TimeConstrained[f[], 300, "timeout"]];

smoke["BaikovPackage"] := Function[{}, Module[{r},
   Block[{Print = (Null &)},
     MCBSetSymbol["BaikovPackage", "Internal", {MCBpfk}];
     MCBSetSymbol["BaikovPackage", "External", {MCBpfp}];
     MCBSetSymbol["BaikovPackage", "Replacements", {MCBpfp^2 -> MCBpfs}];
     MCBSetSymbol["BaikovPackage", "Propagators", {MCBpfk^2 - MCBpfm, (MCBpfk + MCBpfp)^2 - MCBpfm}];
     MCBSetSymbol["BaikovPackage", "PropagatorsExtra", {}];
     r = MCBQualify["BaikovPackage", "BaikovLBL"][]];
   ListQ[r] && Length[r] == 4 && ! FreeQ[r[[1]], MCBQualify["BaikovPackage", "x"]]]];

smoke["DlogBasis"] := Function[{}, Module[{r, x},
   r = Block[{Print = (Null &)}, MCBQualify["DlogBasis", "LeadingSingularities"][1/(x (1 - x)), {x}]];
   ! FreeQ[r, 1] && FreeQ[r, x]]];

smoke["FiniteFlow"] := Function[{}, Module[{g, in, n, rec, x, y, f},
   f = (x + 2 y)/(x - y)^2;
   MCBQualify["FiniteFlow", "FFNewGraph"][g, in, {x, y}];
   MCBQualify["FiniteFlow", "FFAlgRatFunEval"][g, n, {in}, {x, y}, {f}];
   MCBQualify["FiniteFlow", "FFGraphOutput"][g, n];
   rec = MCBQualify["FiniteFlow", "FFReconstructFunction"][g, {x, y}];
   MCBQualify["FiniteFlow", "FFDeleteGraph"][g];
   ListQ[rec] && Together[First[rec] - f] === 0]];

smoke["LiteIBP"] := Function[{}, Module[{code},
   code = "Module[{},
     LIBPFamilyLite[mcbpffam, {mmp[mcbpfk,mcbpfk] - mcbpfm, mp2[mm[mcbpfk]+mm[mcbpfp]] - mcbpfm}, {mcbpfk}, {mcbpfp, mcbpfq},
       {mm[mcbpfq] -> -mm[mcbpfp]}, {mmp[mcbpfp,mcbpfp] -> mcbpfs}, {mcbpfs -> mmp[mcbpfp,mcbpfp]}];
     NewBasis[mcbpffam, LIBPToLiteRed[{mmp[mcbpfk,mcbpfk] - mcbpfm, mp2[mm[mcbpfk]+mm[mcbpfp]] - mcbpfm}], {mcbpfk}, GenerateIBP -> True];
     MatchQ[LIBPDenoms[mcbpffam], {__Rule}]]";
   Block[{$ContextPath = Join[{"LiteIBP`", "LiteRed`", "LiteMomentum`", "FiniteFlow`", "Vectors`", "Types`"}, $ContextPath],
          $Context = "MCBPreflightScratch`", Print = (Null &)},
     TrueQ[ToExpression[code]]]]];

smoke["kira"] := Function[{}, Module[{dir, res, txt},
   dir = CreateDirectory[];
   CreateDirectory[FileNameJoin[{dir, "config"}]];
   Export[FileNameJoin[{dir, "config", "integralfamilies.yaml"}],
     "integralfamilies:\n  - name: \"tad\"\n    loop_momenta: [k]\n    top_level_sectors: [1]\n    cut_propagators: [1]\n    propagators:\n      - [\"k^2\", \"msq\"]\n", "Text"];
   Export[FileNameJoin[{dir, "config", "kinematics.yaml"}],
     "kinematics:\n  incoming_momenta: []\n  kinematic_invariants:\n    - [msq, 2]\n  scalarproduct_rules: []\n", "Text"];
   Export[FileNameJoin[{dir, "target"}], "tad[2]\n", "Text"];
   Export[FileNameJoin[{dir, "job.yaml"}], "jobs:\n  - reduce_sectors:\n      reduce:\n        - {topologies: [tad], sectors: [1], r: 3, s: 0}\n      select_integrals:\n        select_mandatory_list:\n          - [tad, target]\n      run_initiate: true\n      run_triangular: true\n      run_back_substitution: true\n  - kira2math:\n      target:\n        - [tad, target]\n", "Text"];
   MCBShell[If[MCBAvailableQ["fer64"], "FERMATPATH=" <> quote[MCBPath["fer64"]] <> " ", ""] <> quote[MCBPath["kira"]] <>
     " --set_value=\"msq=3/7\" job.yaml > kira.out 2>&1", dir];
   res = FileNameJoin[{dir, "results", "tad", "kira_target.m"}];
   txt = If[FileExistsQ[res], Import[res, "Text"], ""];
   DeleteDirectory[dir, DeleteContents -> True];
   (* tad[2] = (d-2)/(2 msq) tad[1]  at msq = 3/7 *)
   txt =!= "" && Module[{e = Quiet@ToExpression[StringReplace[txt, {RegularExpression["\\bd\\b"] -> "SkillCore`Tools`Private`MCBpfd",
         RegularExpression["\\btad\\["] -> "SkillCore`Tools`Private`MCBpftad["}]]},
      ListQ[e] && e =!= {} && Together[(e[[1, 2]] /. MCBpftad[1] -> 1) - (MCBpfd - 2)/(2 3/7)] === 0]]];

smoke["kira-version"] := Function[{}, Module[{tmp = CreateDirectory[], r, v},
   (* Kira writes kira.log into the folder it runs in, even for --version *)
   r = Quiet@RunProcess[{MCBPath["kira"], "--version"}, ProcessDirectory -> tmp];
   Quiet@DeleteDirectory[tmp, DeleteContents -> True];
   If[! AssociationQ[r], Return["?"]];
   v = StringCases[r["StandardOutput"] <> r["StandardError"], "version:" ~~ Whitespace ~~ ver : (DigitCharacter | ".") .. :> ver];
   If[v === {}, "?", First[v]]]];

smoke["Fuchsia"] := Function[{}, MCBShell[quote[MCBPath["Fuchsia"]] <> " --help > /dev/null 2>&1"] === 0];

$stepNames = {"baikov", "kira-check", "finiteflow", "dlogbasis-crosscheck", "algorithms"};
stepsFrom[avail_Association] := <|
   "step:baikov" -> TrueQ[avail["BaikovPackage"]],
   "step:kira-check" -> TrueQ[avail["kira"]],
   "step:finiteflow" -> AllTrue[{"FiniteFlow", "LiteRed", "LiteIBP"}, TrueQ[avail[#]] &],
   "step:picard-fuchs" -> AllTrue[{"FiniteFlow", "LiteRed", "LiteIBP"}, TrueQ[avail[#]] &],
   "step:dlogbasis-crosscheck" -> TrueQ[avail["DlogBasis"]],
   "step:algorithms" -> AnyTrue[{"INITIAL", "Libra", "Fuchsia"}, TrueQ[avail[#]] &]|>;

pathsText[] := If[StringQ[$MCBPathsFile], $MCBPathsFile <> " (the rest auto-detected)", "auto-detected (no paths.wl)"];

(* The preflight's table is kept per machine, but it holds for the paths it was made with: a run with its own paths.wl
   can have tools the table calls missing, or the other way round. This line is for the paths in use now; it only looks
   for the files (no tests), and says when the cached table belongs to other paths. *)
MCBToolsLine[] := Module[{tools = Select[Keys[$MCBTools], ! creditOnlyQ[#] &], av, st, log, cached},
  av = AssociationMap[MCBAvailableQ, tools];
  st = stepsFrom[av];
  log = FileNameJoin[{MCBCacheDir[], "preflight.log"}];
  cached = If[FileExistsQ[log], StringCases[Import[log, "Text"], "tool paths: " ~~ p : Except["\n"] .. :> p], {}];
  StringJoin["tools (", pathsText[], "): found ", StringRiffle[Select[tools, av[#] &], ", "],
    If[MemberQ[Values[av], False], "; missing " <> StringRiffle[Select[tools, ! av[#] &], ", "], ""],
    ". Steps available: ", StringRiffle[Select[$stepNames, st["step:" <> #] &], ", "],
    If[AnyTrue[$stepNames, ! st["step:" <> #] &], "; not available: " <> StringRiffle[Select[$stepNames, ! st["step:" <> #] &], ", "], ""], ".",
    Which[! FileExistsQ[log], " No preflight has run on this machine yet (bin/preflight.wls).",
      cached === {} || First[cached] =!= pathsText[],
        " The cached preflight log (" <> log <> ") was made with other tool paths (" <> If[cached === {}, "not recorded", First[cached]] <>
          "); bin/preflight.wls run.wl tests these.", True, ""]]];

(* loading and testing a tool is not a use of it: whatever the tests mark is dropped, and nothing is left pending *)
MCBPreflight[logfile_ : Automatic] := SkillCore`Citations`CoreWithCitationContext[None, preflight[logfile]];

preflight[logfile_] := Module[{rows = {}, avail = <||>, row, t, ok, ver, budget, txt},
  If[! StringQ[MCBPath["kira"]] && Length[$MCBPaths] == 0, MCBLoadPaths[Automatic]];
  row[tool_, found_, test_, note_] := AppendTo[rows, {tool, found, test, note}];
  Do[
    t = tool;
    Which[
      creditOnlyQ[t], Null,
      ! MCBAvailableQ[t], row[t, "-", "missing", $MCBTools[t]["Install"]]; avail[t] = False,
      t === "FiniteFlowLibrary", row[t, MCBPath[t], "found", "no test of its own; FiniteFlow's test loads it"]; avail[t] = True,
      t === "fer64", row[t, MCBPath[t], "found", "no test of its own; used by Kira through FERMATPATH"]; avail[t] = True,
      t === "kira",
        ver = tryTest[smoke["kira-version"]];
        ok = TrueQ[tryTest[smoke["kira"]]];
        row[t, MCBPath[t], If[ok, "ok", "FAILED"], "version " <> ToString[ver] <> "; cut_propagators + --set_value tadpole test"];
        avail[t] = ok,
      t === "Fuchsia",
        ok = TrueQ[tryTest[smoke["Fuchsia"]]]; row[t, MCBPath[t], If[ok, "ok", "FAILED"], "--help"]; avail[t] = ok,
      True,
        ok = MCBLoadTool[t];
        If[ok && MemberQ[{"BaikovPackage", "DlogBasis", "FiniteFlow", "LiteIBP"}, t], ok = TrueQ[tryTest[smoke[t]]]];
        row[t, MCBPath[t], If[ok, "ok", "FAILED"], Switch[t,
            "BaikovPackage", "one-loop bubble LBL", "DlogBasis", "LS of 1/(x(1-x))",
            "FiniteFlow", "reconstruction of a 2-variable rational function", "LiteIBP", "one-loop family",
            _, "load only"]];
        avail[t] = ok],
    {tool, Keys[$MCBTools]}];
  budget = MCBKernelBudget[];
  avail = Join[avail, stepsFrom[avail], <|"budget" -> budget|>];
  txt = StringJoin[
    "maximal-cut-basis preflight, ", DateString[], "\n", "Mathematica ", $Version, "\n",
    "tool paths: ", pathsText[], "\n\n",
    StringRiffle[Table[StringRiffle[{StringPadRight[r[[1]], 18], StringPadRight[ToString[r[[3]]], 7], ToString[r[[2]]], If[r[[4]] =!= "", "  (" <> r[[4]] <> ")", ""]}, " "], {r, rows}], "\n"],
    "\n\nkernel licence: ", ToString[budget["MaxLicenseProcesses"]], " kernels (", ToString[budget["RunningKernels"]], " running now, this one included), ", ToString[budget["MaxLicenseSubprocesses"]],
    " subkernels; ", ToString[budget["ProcessorCount"]], " CPUs -> ", ToString[budget["Parallel"]], " parallel queue(s), kira --parallel=", ToString[$MCBKiraThreads], "\n",
    "steps available: ", StringRiffle[Select[$stepNames, TrueQ[avail["step:" <> #]] &], ", "], "\n",
    "steps NOT available: ", Replace[StringRiffle[Select[$stepNames, ! TrueQ[avail["step:" <> #]] &], ", "], "" -> "none"], "\n"];
  (* the log and the kernel limit belong to the machine, not to a run: both go to the cache folder; bin/ws reads the
     limit from there, so that it can wait for a free slot without starting a kernel *)
  Quiet@Module[{cache = MCBCacheDir[]},
    If[! DirectoryQ[cache], CreateDirectory[cache, CreateIntermediateDirectories -> True]];
    (* an unlimited licence (Infinity) gets a large number, which bin/ws can compare *)
    Which[IntegerQ[budget["MaxLicenseProcesses"]], Export[FileNameJoin[{cache, "max_kernels"}], ToString[budget["MaxLicenseProcesses"]], "Text"],
      budget["MaxLicenseProcesses"] === Infinity, Export[FileNameJoin[{cache, "max_kernels"}], "1000", "Text"]]];
  Export[Replace[logfile, Automatic | None :> FileNameJoin[{MCBCacheDir[], "preflight.log"}]], txt, "Text"];
  Print[txt];
  avail];


End[];
EndPackage[];
