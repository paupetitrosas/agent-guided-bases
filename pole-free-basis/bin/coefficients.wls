#!/usr/bin/env wolframscript
(* Identify coefficients by reconstruction, not by guessing. Writes the analytic job <job>_a of a reduction job: the
   reduction of the given root-free expressions (candidates, ut[k] for current masters) on a few masters (by default the
   masters of their own sector), reconstructed by FiniteFlow as functions of eps and the invariants from as many cheap
   evaluations of the learned system as it needs. It reuses the job's roots, seeds and identities, and checks the
   result against the reduction at the job's first point.
   With --collect: prints the coefficients, factored; with --source k, also each expression normalised to coefficient 1
   on ut[k] when that coefficient is a monomial in eps times a rational function (rungs 2 and 3), or the eps factor
   that makes it a hidden weight.
   usage: coefficients.wls run.wl job "{expr, ...}" [--masters "{k, ...}"] [--fix "{m2 -> 1}"]
          coefficients.wls run.wl job --collect [--source k] *)
Get[FileNameJoin[{ParentDirectory[DirectoryName[$InputFileName]], "lib", "PoleFreeBasis.wl"}]];

Module[{a = Rest[$ScriptCommandLine], opt, ctx, sys, jobDir, ajob, opts = <||>, an, src, norm},
  If[Length[a] < 3, Print["usage: coefficients.wls run.wl job \"{expr, ...}\" [--masters \"{k, ...}\"] [--fix \"{m2 -> 1}\"]  |  run.wl job --collect [--source k]"];
    CoreVerdict["coefficients", "usage"]];
  opt[name_] := With[{p = Position[a, name]}, If[p === {} || p[[1, 1]] == Length[a], None, a[[p[[1, 1]] + 1]]]];
  ctx = PFBStartRun[a[[1]]]; If[ctx === $Failed, CoreVerdict["coefficients", "usage", <|"message" -> "no run found"|>]]; sys = ctx["System"];
  jobDir = FileNameJoin[{ctx["Dir"], "jobs", a[[2]]}];
  If[! DirectoryQ[jobDir], CoreVerdict["coefficients", "usage", <|"message" -> "no job " <> a[[2]]|>]];
  ajob = FileNameJoin[{ctx["Dir"], "jobs", a[[2]] <> "_a"}];
  If[! MemberQ[a, "--collect"],
    If[opt["--masters"] =!= None, opts["Masters"] = ToExpression[opt["--masters"]]];
    If[opt["--fix"] =!= None, opts["Fix"] = ToExpression[opt["--fix"]]];
    ajob = PFBAnalyticJob[sys, ctx["Dir"], jobDir, ToExpression[a[[3]]], opts];
    If[ajob === $Failed, CoreVerdict["coefficients", "fail", <|"message" -> "the analytic job was not written (see above)"|>]];
    Export[FileNameJoin[{ajob, "command.sh"}], PFBSubtreeCommand[ajob] <> "\n", "Text"];
    Print["analytic job: ", ajob, "\nrun it in the background:\n  ", PFBSubtreeCommand[ajob], "\nwait for it:\n  ",
      FileNameJoin[{$PFBRoot, "bin", "wait_job"}], " ", ajob, " --timeout <seconds>\nthen: coefficients.wls run.wl ", a[[2]], " --collect [--source k]"];
    CoreVerdict["coefficients", "pass", <|"job" -> ajob, "command" -> PFBSubtreeCommand[ajob]|>]];
  (* analytic.m is written before the check at the first point: only a finished job's coefficients count *)
  With[{st = PFBSubtreeStatus[ajob]}, If[st["Status"] =!= "done", Print["the analytic job is not done: ", st["Status"], " ", Lookup[st, "Message", ""]];
    CoreVerdict["coefficients", "fail", <|"message" -> "analytic job " <> ToString[st["Status"]], "job" -> ajob|>]]];
  an = PFBAnalyticCoefficients[ajob];
  If[! AssociationQ[an], Print["no analytic.m in ", ajob, ": ", PFBSubtreeStatus[ajob]["Status"], " ", Lookup[PFBSubtreeStatus[ajob], "Message", ""]];
    CoreVerdict["coefficients", "fail", <|"message" -> "no analytic coefficients yet", "job" -> ajob|>]];
  Print["reconstructed in ", an["Seconds"], " s in ", an["Vars"], If[an["Fix"] === {}, "", ", with " <> ToString[an["Fix"], InputForm] <> " fixed"], "; ", an["Check"],
    If[Lookup[an, "NonUT", {}] =!= {}, "; masters the system lacks were kept: coefficients on lower-sector masters are on that larger basis", ""]];
  Do[Print["expression ", i, ": ", InputForm[an["Exprs"][[i]]]];
    Do[If[an["Coefficients"][[i, m]] =!= 0, Print["  on ", an["Masters"][[m]], ": ", InputForm[an["Coefficients"][[i, m]]]]], {m, Length[an["Masters"]]}], {i, Length[an["Exprs"]]}];
  src = opt["--source"];
  norm = If[src === None, {}, Table[With[{r = PFBNormaliseCandidate[sys, an, i, ToExpression[src]]},
      Print["expression ", i, " on ut[", src, "]: ", r["Message"], If[! MissingQ[r["Def"]], "\n  normalised: " <> ToString[r["Def"], InputForm], ""],
        If[Lookup[r, "SameClass", True] === False, "\n  it also has components on other masters of the sector: the maximal cut changes", ""]]; r], {i, Length[an["Exprs"]]}]];
  CoreVerdict["coefficients", If[StringStartsQ[an["Check"], "agrees"] || an["Check"] === "not checked", "pass", "fail"],
    <|"job" -> ajob, "check" -> an["Check"], "masters" -> ToString[an["Masters"], InputForm],
      "normalised" -> (If[MissingQ[#["Def"]], Null, ToString[#["Def"], InputForm]] & /@ norm)|>]];
