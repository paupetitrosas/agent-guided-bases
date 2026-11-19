#!/usr/bin/env wolframscript
(* Remove, exactly, the masters that a subtree job kept although the system does not have them (non-ut integrals, a job
   with "AllowNonUT" -> True: the subtree misses a relation that a sector outside it supplies). Such a job costs a
   subtree reduction instead of a whole-family one; its rows are exact, but on one master too many.
   Without --collect: writes the expansion job <job>_x (the same points, the extra masters as its only pool, roots large
   enough to reduce them: the sector of relation.m when bin/relation_sector.wls found one, otherwise every top sector
   that contains them) and prints its command. Only the extra masters' rows are reconstructed, so its points are cheap.
   With --collect: replaces the extra masters by their expansion in every reduction of the job (raw ones kept as
   raw_<ip>.m) and calibrates the result against the current slice. After that the job calibrates, scans, fits and
   verifies at the extra points like any other.
   usage: extra_masters.wls run.wl job [--roots "{{fam, {1, 0, ...}}, ...}"] [--collect] *)
Get[FileNameJoin[{ParentDirectory[DirectoryName[$InputFileName]], "lib", "PoleFreeBasis.wl"}]];

Module[{a = Rest[$ScriptCommandLine], ctx, sys, jobDir, xs, xjob, opts = <||>, p, col, sl, cal, st},
  If[Length[a] < 2, Print["usage: extra_masters.wls run.wl job [--roots \"{{fam, {...}}, ...}\"] [--collect]"]; CoreVerdict["extra_masters", "usage"]];
  ctx = PFBStartRun[a[[1]]]; If[ctx === $Failed, CoreVerdict["extra_masters", "usage", <|"message" -> "no run found"|>]]; sys = ctx["System"];
  jobDir = FileNameJoin[{ctx["Dir"], "jobs", a[[2]]}];
  If[! DirectoryQ[jobDir], CoreVerdict["extra_masters", "usage", <|"message" -> "no job " <> a[[2]]|>]];
  xs = PFBExtraMasters[jobDir];
  Print["extra masters of ", a[[2]], ": ", xs];
  If[xs === {}, CoreVerdict["extra_masters", "pass", <|"job" -> jobDir, "extra" -> {}, "message" -> "nothing to remove"|>]];
  p = Position[a, "--roots"]; If[p =!= {}, opts["Roots"] = ToExpression[a[[p[[1, 1]] + 1]]]];
  xjob = FileNameJoin[{ctx["Dir"], "jobs", a[[2]] <> "_x"}];
  If[! MemberQ[a, "--collect"],
    xjob = PFBExpansionJob[sys, ctx["Dir"], jobDir, opts];
    If[xjob === $Failed, CoreVerdict["extra_masters", "fail", <|"message" -> "the expansion job was not written (see above)"|>]];
    Export[FileNameJoin[{xjob, "command.sh"}], PFBSubtreeCommand[xjob] <> "\n", "Text"];
    Print["expansion job: ", xjob, "\nrun it in the background, wait for it (bin/wait_job), then: extra_masters.wls run.wl ", a[[2]], " --collect\n  ", PFBSubtreeCommand[xjob]];
    CoreVerdict["extra_masters", "pass", <|"job" -> jobDir, "extra" -> ToString[xs, InputForm], "expansionJob" -> xjob, "command" -> PFBSubtreeCommand[xjob]|>]];
  st = PFBSubtreeStatus[xjob];
  If[st["Status"] =!= "done", Print["the expansion job is not done: ", st["Status"], " ", Lookup[st, "Message", ""]];
    CoreVerdict["extra_masters", "fail", <|"message" -> "expansion job " <> ToString[st["Status"]], "expansionJob" -> xjob|>]];
  (* the expansion is on the masters of the basis it was written for: it must be the job's *)
  If[Quiet@Get[FileNameJoin[{xjob, "system.m"}]] =!= Quiet@Get[FileNameJoin[{jobDir, "system.m"}]],
    Print["the expansion job was written for another basis than the job (a change was accepted in between): run extra_masters.wls run.wl ", a[[2]], " without --collect to write it again"];
    CoreVerdict["extra_masters", "fail", <|"message" -> "expansion job of another basis", "expansionJob" -> xjob|>]];
  col = PFBCollectExpansion[jobDir, xjob];
  Print["removed at points ", col["Points"], If[col["Missing"] === {}, "", "; not at " <> ToString[col["Missing"]]]];
  sl = PFBCurrentSlice[ctx["Dir"], ctx["State"]];
  cal = If[MemberQ[col["Points"], 1], PFBCalibrate[sl, PFBReadRed[jobDir, 1]], <|"Status" -> "not checked", "Message" -> "no reduction at the slice point"|>];
  Print["calibration against the current slice: ", cal["Status"], " ", cal["Message"]];
  CoreVerdict["extra_masters", If[col["Missing"] === {} && cal["Status"] === "exact", "pass", "fail"],
    <|"job" -> jobDir, "extra" -> ToString[xs, InputForm], "points" -> col["Points"], "missing" -> ToString[col["Missing"], InputForm], "calibration" -> cal["Status"]|>]];
