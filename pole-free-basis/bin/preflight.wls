#!/usr/bin/env wolframscript
(* Tools, licence, memory and the memory model of this machine.
   usage: preflight.wls [paths.wl | run.wl] [log file]
   The report is printed and kept in ~/.cache/maximal-cut-basis/preflight.log (once per machine), unless a log file is given.
   Runs the maximal-cut-basis preflight (FiniteFlow, LiteRed, LiteIBP, Kira, ...) and adds what this skill needs:
   memory, cores, kernels, the memory model calibrated from earlier runs, whether a local slice is likely to fit, and the
   optional SOFIA ("SOFIA" in paths.wl, the path of its scr.m; never loaded here). *)
Get[FileNameJoin[{ParentDirectory[DirectoryName[$InputFileName]], "lib", "PoleFreeBasis.wl"}]];

Module[{args = Rest[$ScriptCommandLine], paths, log, res, mm, txt, probe, def, sofia},
paths = Which[Length[args] >= 1, args[[1]], FileExistsQ["paths.wl"], "paths.wl", True, Automatic];
If[StringQ[paths] && KeyExistsQ[Replace[Quiet@Get[paths], Except[_Association] -> <||>], "System"],
  paths = Replace[PFBReadRun[paths]["Paths"], Automatic -> Automatic]];
log = If[Length[args] >= 2, args[[2]], FileNameJoin[{MCBCacheDir[], "preflight.log"}]];
MCBLoadPaths[paths];
(* the library first on the default path, before the toolkit puts the configured one first *)
def = Quiet@FindLibrary["fflowmlink"];
MCBPreflight[log];
res = PFBResources[]; mm = PFBMemoryModel[];
(* the sparse solver of the rungs, in a separate kernel: a stale FiniteFlow library can abort the kernel there *)
probe = If[! (MCBAvailableQ["FiniteFlow"] && MCBAvailableQ["FiniteFlowLibrary"]), "not tested (FiniteFlow missing)",
  Module[{f = FileNameJoin[{$TemporaryDirectory, "pfb_ffprobe_" <> ToString[$ProcessID] <> ".wl"}], r},
   Export[f, "PrependTo[$LibraryPath, " <> ToString[MCBPath["FiniteFlowLibrary"], InputForm] <> "];\n$Path = Append[$Path, " <>
      ToString[DirectoryName[MCBPath["FiniteFlow"]], InputForm] <> "];\nNeeds[\"FiniteFlow`\"];\n" <>
      "Print[If[FFSparseSolve[{x[1] + 2 x[2] == 3, x[1] - x[2] == 0}, {x[1], x[2]}, \"Parameters\" -> {}] === {x[1] -> 1, x[2] -> 1}, \"PFBPROBEOK\", \"PFBPROBEWRONG\"]];", "Text"];
   r = RunProcess[{FileNameJoin[{$PFBRoot, "bin", "ws"}], "--max-wait", "600", f}];
   Quiet[DeleteFile[f]];
   Which[! AssociationQ[r], "not tested", StringContainsQ[r["StandardOutput"], "PFBPROBEOK"], "ok",
     StringContainsQ[r["StandardOutput"], "PFBPROBEWRONG"], "WRONG RESULT",
     (* 75: bin/ws gave up waiting for a licence slot, so the probe never ran *)
     r["ExitCode"] === 75, "not tested (no free licence slot within 10 minutes; rerun the preflight when one is free)", True,
     "CRASHED (exit " <> ToString[r["ExitCode"]] <> "): this FiniteFlow library aborts in FFSparseSolve; point FiniteFlowLibrary to a current build"]]];
sofia = PFBSOFIALine[];
txt = StringJoin[
  "\n-- pole-free-basis --\n",
  "memory: ", ToString[res["MemTotalGB"]], " GB total, ", ToString[res["MemAvailableGB"]], " GB available, swap ", ToString[res["SwapGB"]], " GB\n",
  "cores: ", ToString[res["Cores"]], "; licence kernels: ", ToString[res["LicenceKernels"]], " (", ToString[res["RunningKernels"]], " running)\n",
  "budget for one reduction now: ", ToString[PFBMemoryBudget[]], " GB\n",
  "memory model (", mm["Source"], ", ", ToString[mm["Records"]], " records): peak GB = ", ToString[mm["Base"]], " + ", ToString[ScientificForm[mm["LearnPerEq"], 3]],
  " x equations + ", ToString[ScientificForm[mm["ReconPerUnit"], 3]], " x rows x masters x threads\n",
  "a reduction learns at most ~", ToString[Round[(PFBMemoryBudget[] - mm["Base"])/mm["LearnPerEq"]/10^6, 0.1]], " million equations within the budget\n",
  "FiniteFlow sparse solver (rungs 4 and 6): ", probe, "\n",
  If[StringQ[def] && MCBAvailableQ["FiniteFlowLibrary"] &&
      StringReplace[ExpandFileName[DirectoryName[def]], "/" .. ~~ EndOfString -> ""] =!= StringReplace[ExpandFileName[MCBPath["FiniteFlowLibrary"]], "/" .. ~~ EndOfString -> ""],
    "note: another FiniteFlow library is first on the default path (" <> def <> "); the toolkit puts the configured one first, other code may not\n", ""],
  "SOFIA (optional, known singularities: bin/singularities.wls): ", sofia["Text"], "\n",
  "required for reductions: FiniteFlow, FiniteFlowLibrary, LiteRed, LiteIBP: ",
  If[AllTrue[{"FiniteFlow", "FiniteFlowLibrary", "LiteRed", "LiteIBP"}, MCBAvailableQ], "found", "MISSING " <> ToString[Select[{"FiniteFlow", "FiniteFlowLibrary", "LiteRed", "LiteIBP"}, ! MCBAvailableQ[#] &]]], "\n"];
Print[txt];
Export[log, If[FileExistsQ[log], Import[log, "Text"], ""] <> txt, "Text"];
CoreVerdict["preflight", If[AllTrue[{"FiniteFlow", "FiniteFlowLibrary", "LiteRed", "LiteIBP"}, MCBAvailableQ] && probe === "ok", "pass", "fail"],
  <|"reductions" -> AllTrue[{"FiniteFlow", "FiniteFlowLibrary", "LiteRed", "LiteIBP"}, MCBAvailableQ], "sparseSolver" -> probe,
    "budgetGB" -> PFBMemoryBudget[], "sofia" -> sofia["Status"], "log" -> log|>]];
