#!/usr/bin/env wolframscript
(* Which third-party tools are installed, does each pass a smoke test, how many kernels may run.
   usage: preflight.wls [paths.wl | run.wl] [log file]   (with run.wl its "Paths" and "Skip" are used)
   The table is printed and written to the log file, by default preflight.log in ~/.cache/maximal-cut-basis
   (once per machine, not per run). *)
Get[FileNameJoin[{ParentDirectory[DirectoryName[$InputFileName]], "lib", "MaximalCutBasis.wl"}]];

(* the version of the configured FiniteFlow library, loaded first in a separate kernel (loading cannot hang). A library
   built before September 2025 (no $FFVersion before December 2024, 2.0 without the rational-expression parser after)
   loops on FiniteFlow's current FFAlgRatExprEval: SetSDE.m then avoids it. def: the library first on the default path,
   looked up before the toolkit puts the configured one first *)
ffVersion[def_] := If[! (MCBAvailableQ["FiniteFlow"] && MCBAvailableQ["FiniteFlowLibrary"]), "not tested (FiniteFlow missing)",
  Module[{f = FileNameJoin[{$TemporaryDirectory, "mcb_ffversion_" <> ToString[$ProcessID] <> ".wl"}], r, out},
   Export[f, "PrependTo[$LibraryPath, " <> ToString[MCBPath["FiniteFlowLibrary"], InputForm] <> "];\n$Path = Append[$Path, " <>
      ToString[DirectoryName[MCBPath["FiniteFlow"]], InputForm] <> "];\nQuiet[Needs[\"FiniteFlow`\"]];\n" <>
      "Print[\"MCBFFLIB \", FindLibrary[\"fflowmlink\"], \" MCBFFVERSION \", If[IntegerQ[$FFVersion], ToString[$FFVersion] <> \".\" <> ToString[$FFVersionMinor], \"none\"], " <>
      "\" MCBFFPARSER \", If[Head[FiniteFlow`Private`FFAlgRatExprEvalParseImplem] === LibraryFunction, \"yes\", \"no\"]];", "Text"];
   r = RunProcess[{FileNameJoin[{$MCBRoot, "bin", "ws"}], "--max-wait", "600", f}];
   Quiet[DeleteFile[f]];
   out = If[AssociationQ[r], StringCases[r["StandardOutput"], "MCBFFLIB " ~~ lib : Except[WhitespaceCharacter] .. ~~ " MCBFFVERSION " ~~ v : Except[WhitespaceCharacter] .. ~~
       " MCBFFPARSER " ~~ p : Except[WhitespaceCharacter] .. :> {lib, v, p}], {}];
   StringJoin[
     Which[out === {}, "not tested (no free licence slot, or FiniteFlow did not load)",
       out[[1, 2]] === "none", out[[1, 1]] <> ": older than 2.0. SetSDE.m falls back to Together and FFAlgRatFunEval (slower); point FiniteFlowLibrary to a current build",
       out[[1, 3]] =!= "yes", out[[1, 1]] <> ": version " <> out[[1, 2]] <> ", built before September 2025 (no rational-expression parser). SetSDE.m falls back to Together and FFAlgRatFunEval (slower); point FiniteFlowLibrary to a current build",
       True, out[[1, 1]] <> ": version " <> out[[1, 2]]],
     If[StringQ[def] && StringReplace[ExpandFileName[DirectoryName[def]], "/" .. ~~ EndOfString -> ""] =!= StringReplace[ExpandFileName[MCBPath["FiniteFlowLibrary"]], "/" .. ~~ EndOfString -> ""],
       "; another FiniteFlow library is first on the default path (" <> def <> "): the skills put the configured one first, other code may not", ""]]]];

Module[{args, paths},
args = Rest[$ScriptCommandLine];
paths = Which[Length[args] >= 1, args[[1]], FileExistsQ["paths.wl"], "paths.wl", True, Automatic];
(* a run.wl has run keys ("Family" is optional there); a paths.wl only tool names *)
If[StringQ[paths] && IntersectingQ[Keys[Replace[Quiet@Get[paths], Except[_Association] -> <||>]], Keys[$MCBRunDefaults]],
  With[{run = MCBReadRun[paths]},
    If[MemberQ[run["Skip"], "preflight"], Print["preflight: skipped by user"]; CoreVerdict["preflight", "pass", <|"skipped" -> True|>]];
    paths = run["Paths"]]];
MCBLoadPaths[paths];
With[{def = Quiet@FindLibrary["fflowmlink"]}, With[{av = MCBPreflight[If[Length[args] >= 2, args[[2]], Automatic]], ffv = ffVersion[def]},
  Print["FiniteFlow library: ", ffv];
  CoreVerdict["preflight", If[TrueQ[av["step:kira-check"]] && TrueQ[av["step:baikov"]], "pass", "fail"],
    <|"steps" -> KeyMap[StringDrop[#, 5] &, KeySelect[av, StringStartsQ[#, "step:"] &]], "finiteflowLibrary" -> ffv,
      "log" -> FileNameJoin[{MCBCacheDir[], "preflight.log"}]|>]]]
];
