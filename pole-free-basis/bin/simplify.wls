#!/usr/bin/env wolframscript
(* The simplification phase (workflow step 7 of SKILL.md, after the pole-free work): lower the kinematic degrees of the DE by
   changes of basis that keep the census. Each call does what it can without waiting and says what is next:
   - refuses while the census has a bad entry outside flagged sectors (or another change waits for approval);
   - writes the degree census of the current slice (one timed degree job per sector), or collects it;
   - proposes a budget for the moves from the job times and stops until the user answers (--budget, or run.wl
     "SimplifyBudget"); run.wl "TargetKinDegree" stops the phase once the highest degree is at or below it;
   - runs the moves (move (i): the global letter rescaling; move (ii): swaps of the worst master; move (iii): shifts
     by lower masters; move (iv): lighter completions; run.wl "SimplifyMoves" names the ones to run): writes a move's own jobs when it needs them (a
     reduction to scan, the samples of a fit), then
     the degree jobs that measure the candidates as variants, then measures them and sends the best one that lowers
     the objective through the gate (rung "simplify").
   reference/simplify.md.
   usage: simplify.wls run.wl [--budget S | --budget proposed] [--bound N] [--solver-time S] [--new]
   --new starts a new phase (after more pole-free work): the record of the last one is kept as simplify/phase_<date>.m.
   exit codes: 0 the phase is done; 1 refused or failed; 4 jobs to run, a budget to agree or a change to approve (do
   that, then run it again); 2 usage. *)
Get[FileNameJoin[{ParentDirectory[DirectoryName[$InputFileName]], "lib", "PoleFreeBasis.wl"}]];

Module[{a = Rest[$ScriptCommandLine], ctx, opts = <||>, arg, r, out},
  If[a === {}, Print["usage: simplify.wls run.wl [--budget S | --budget proposed] [--bound N] [--solver-time S] [--new]"]; CoreVerdict["simplify", "usage"]];
  ctx = PFBStartRun[a[[1]]];
  If[ctx === $Failed, CoreVerdict["simplify", "usage", <|"message" -> "no run found for " <> a[[1]]|>]];
  arg[name_] := With[{p = Position[a, name]}, If[p === {} || p[[1, 1]] >= Length[a], None, a[[p[[1, 1]] + 1]]]];
  With[{b = arg["--budget"]}, Which[b === None, Null, b === "proposed", opts["Budget"] = "proposed",
    IntegerQ[Quiet@ToExpression[b]] && ToExpression[b] > 0, opts["Budget"] = ToExpression[b],
    True, CoreVerdict["simplify", "usage", <|"message" -> "--budget takes seconds or \"proposed\""|>]]];
  With[{b = arg["--bound"]}, If[b =!= None, If[IntegerQ[Quiet@ToExpression[b]] && ToExpression[b] >= 1, opts["Bound"] = ToExpression[b],
    CoreVerdict["simplify", "usage", <|"message" -> "--bound takes an integer >= 1"|>]]]];
  With[{b = arg["--solver-time"]}, If[b =!= None, If[NumericQ[Quiet@ToExpression[b]], opts["SolverTime"] = ToExpression[b],
    CoreVerdict["simplify", "usage", <|"message" -> "--solver-time takes seconds"|>]]]];
  With[{f = FileNameJoin[{ctx["Dir"], "simplify", "phase.m"}]}, If[MemberQ[a, "--new"] && FileExistsQ[f],
    RenameFile[f, FileNameJoin[{ctx["Dir"], "simplify", "phase_" <> DateString[{"Year", "Month", "Day", "_", "Hour", "Minute", "Second"}] <> ".m"}]];
    Print["the last phase's record is kept as ", FileNameTake[FileNames["phase_*.m", FileNameJoin[{ctx["Dir"], "simplify"}]][[-1]]]]]];
  r = PFBSimplifyStep[ctx, opts];
  Print[r["Message"]];
  out = Switch[r["Outcome"], "done", "pass", "refused" | "error", "fail", _, "rerun"];
  CoreVerdict["simplify", out, <|"next" -> r["Outcome"], "command" -> Lookup[r, "CommandFile", Null], "jobs" -> Lookup[r, "Jobs", {}],
    "budget" -> If[AssociationQ[Lookup[r, "Proposal", None]], r["Proposal"]["Seconds"], Null],
    "moves" -> If[AssociationQ[Lookup[r, "Phase", None]], (#["Move"] <> ": " <> ToString[#["Status"]]) & /@ r["Phase"]["Moves"], {}]|>]];
