#!/usr/bin/env wolframscript
(* Rung 8, first step: the candidates of a new maximal-cut basis of a sector, and the reduction job that puts them in the
   pool. The maximal-cut-basis toolkit runs in this kernel on the family's run (system.wl "MCBRun", read only; without it
   this skill makes one in <run folder>/maxcut/<fam>/): the run's basis of the sector, its candidate steps replayed from the
   sector's AnalysisMasters.m, and the candidate routes of the first representations (dlog candidates normalised by their
   leading singularities, curve candidates, single integrals), plus the structural reading's candidates (--cands:
   integrals or root-free definitions). Before any reduction they are filtered by the hard rules 1, 2 and 4 (the
   d-dimensional candidates with coefficients rational in eps go) and by the square root of the master each would
   replace; each one that is left gets, per slot, a root-free definition with the slot's lowest power of eps.
   Writes <run>/<fam>/<jPATTERN>/maxcut_candidates.m (recorded in attempts.m) and the job <fam>_<jPATTERN>_maxcut (the
   sector's subtree at the slice point and the extra points, the candidates' integrals and their images in the pool).
   Then: run the job's command, wait for it with bin/wait_job, and scan with
     bin/ws bin/pair_scan.wls run.wl <job> fam/jPATTERN --maxcut
   usage: maxcut_candidates.wls run.wl fam/jPATTERN [--cands "{...}"] [--reps n] [--tlim seconds] [--max n]
                                [--no-routes] [--no-replay] [--no-job] [--job name] [--replace] *)
Get[FileNameJoin[{ParentDirectory[DirectoryName[$InputFileName]], "lib", "PoleFreeBasis.wl"}]];

Module[{a = Rest[$ScriptCommandLine], opt, ctx, sys, key, run, res, f, job = None, extra, showDefs},
  If[Length[a] < 2, Print["usage: maxcut_candidates.wls run.wl fam/jPATTERN [--cands \"{...}\"] [--reps n] [--tlim seconds] [--max n] [--no-routes] [--no-replay] [--no-job] [--job name] [--replace]"];
    CoreVerdict["maxcut_candidates", "usage"]];
  opt[name_, def_] := With[{p = Position[a, name]}, If[p === {} || p[[1, 1]] == Length[a], def, a[[p[[1, 1]] + 1]]]];
  ctx = PFBStartRun[a[[1]]]; If[ctx === $Failed, CoreVerdict["maxcut_candidates", "usage", <|"message" -> "no run found"|>]]; sys = ctx["System"];
  key = With[{p = StringSplit[a[[2]], "/"]}, {ToExpression[p[[1]]], SectorFromName[p[[2]]]}];
  If[! MemberQ[PFBSectorKeys[sys], key], Print["no masters in ", a[[2]]]; CoreVerdict["maxcut_candidates", "usage", <|"message" -> "no masters in " <> a[[2]]|>]];
  (* the toolkit's tools (BaikovPackage, the candidate routes) are credited to the sector; the maximal-cut-basis run's
     credits of the sector go with the change that takes a candidate (PFBTryChange) *)
  CoreCitationContext[ctx["Dir"], PFBSectorString[key], "maximal-cut candidates (rung 8)"];
  run = PFBMaxCutRun[sys, ctx["Dir"], key[[1]]];
  Print["maximal-cut-basis run: ", run["Dir"], If[run["Given"], " (system.wl \"MCBRun\": read only)", " (this run's own; maximal-cut-basis's scripts take its run.wl)"]];
  extra = Replace[opt["--cands", None], {s_String :> ToExpression[s], None -> {}}];
  res = PFBMaxCutCandidates[sys, key, <|"MCBRun" -> run["Dir"], "Extra" -> extra, "Reps" -> ToExpression[opt["--reps", "3"]], "TimeLimit" -> ToExpression[opt["--tlim", "300"]],
     "MaxCandidates" -> ToExpression[opt["--max", "30"]], "Routes" -> ! MemberQ[a, "--no-routes"], "Replay" -> ! MemberQ[a, "--no-replay"]|>];
  f = PFBWriteMaxCutCandidates[ctx["Dir"], key, res];
  Print[res["Message"]];
  If[res["Status"] =!= Missing["NotRun"], Print["the run's sector: ", res["Status"], ", Picard-Fuchs label ", Lookup[Replace[res["Classification"], Except[_Association] -> <||>], "label", "not computed"]]];
  showDefs[c_] := StringRiffle[KeyValueMap["ut[" <> ToString[#1] <> "] -> " <> With[{t = ToString[#2, InputForm]}, If[StringLength[t] > 160, StringTake[t, 157] <> "...", t]] &, c["Defs"]], "; "];
  Do[Print["  ", c["Source"], " | ", c["Label"], If[c["Dotted"], " (dotted)", ""], " | ", showDefs[c]], {c, res["Candidates"]}];
  If[res["Dropped"] =!= {}, Print[Length[res["Dropped"]], " dropped before any reduction:"];
    Do[Print["  ", d["Source"], " | ", d["Label"], " | ", StringRiffle[d["Reasons"], "; "]], {d, Take[res["Dropped"], UpTo[30]]}]];
  Print["written: ", f];
  If[res["Candidates"] === {},
    Print["no candidate is left: give the structural reading's with --cands, or more representations with --reps"];
    CoreVerdict["maxcut_candidates", "fail", <|"sector" -> a[[2]], "candidates" -> 0, "dropped" -> Length[res["Dropped"]], "file" -> f|>]];
  If[! MemberQ[a, "--no-job"],
    job = PFBMaxCutJob[ctx, key, res["Candidates"], Join[<|"Replace" -> MemberQ[a, "--replace"]|>, If[opt["--job", None] =!= None, <|"Name" -> opt["--job", None]|>, <||>]]];
    If[! StringQ[job], CoreVerdict["maxcut_candidates", "fail", <|"sector" -> a[[2]], "message" -> "the job was not written (see above)", "file" -> f|>]];
    Print["job: ", job, "\n", Lookup[Quiet@Get[FileNameJoin[{job, "job.m"}]], "ReducerNote", ""]];
    Print["run it with:\n  ", PFBSubtreeCommand[job], "\nwait for it with:\n  ", FileNameJoin[{$PFBRoot, "bin", "wait_job"}], " ", job, " --timeout <seconds>\nthen scan:\n  ",
      FileNameJoin[{$PFBRoot, "bin", "ws"}], " ", FileNameJoin[{$PFBRoot, "bin", "pair_scan.wls"}], " ", a[[1]], " ", FileNameTake[job], " ", a[[2]], " --maxcut"]];
  CoreVerdict["maxcut_candidates", "pass", <|"sector" -> a[[2]], "mcbRun" -> run["Dir"], "given" -> run["Given"], "candidates" -> Length[res["Candidates"]],
    "dropped" -> Length[res["Dropped"]], "file" -> f, "job" -> Replace[job, None -> Null], "command" -> If[StringQ[job], PFBSubtreeCommand[job], Null], "notes" -> res["Notes"]|>]];
