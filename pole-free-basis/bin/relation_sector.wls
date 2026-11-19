#!/usr/bin/env wolframscript
(* Find which sector supplies the relation that removes a job's extra masters (masters the system does not have, kept
   by "AllowNonUT" -> True or reported by a job that stopped on them). One time per tower of sectors: once the sector is
   known, give it to the tower's jobs with "ExtraRoots" (and PFBExpansionJob uses it), so their subtrees close.
   Without --collect: writes one learn-only trial per candidate sector (a sector of the same family that contains an
   extra master's sector and is outside the subtree; sectors with system masters first, then the smallest; at most
   --max, default 6), with the extra masters as its pool, reusing the job's identities, and prints the command that
   runs them one after the other. Each trial learns and stops: no reconstruction. A trial removes an extra master when
   it can reduce it to masters of the system.
   With --collect: reads the trials and writes relation.m in the job: what each candidate removes, and the best one.
   usage: relation_sector.wls run.wl job [--max n] [--collect] *)
Get[FileNameJoin[{ParentDirectory[DirectoryName[$InputFileName]], "lib", "PoleFreeBasis.wl"}]];

Module[{a = Rest[$ScriptCommandLine], ctx, sys, jobDir, tr, rep, p},
  If[Length[a] < 2, Print["usage: relation_sector.wls run.wl job [--max n] [--collect]"]; CoreVerdict["relation_sector", "usage"]];
  ctx = PFBStartRun[a[[1]]]; If[ctx === $Failed, CoreVerdict["relation_sector", "usage", <|"message" -> "no run found"|>]]; sys = ctx["System"];
  jobDir = FileNameJoin[{ctx["Dir"], "jobs", a[[2]]}];
  If[! DirectoryQ[jobDir], CoreVerdict["relation_sector", "usage", <|"message" -> "no job " <> a[[2]]|>]];
  If[! MemberQ[a, "--collect"],
    p = Position[a, "--max"];
    tr = PFBRelationTrials[sys, ctx["Dir"], jobDir, <|"MaxTrials" -> If[p === {}, 6, ToExpression[a[[p[[1, 1]] + 1]]]]|>];
    If[tr === $Failed, CoreVerdict["relation_sector", "fail", <|"message" -> "no trial written (see above)"|>]];
    Print["candidates: ", PFBSectorString /@ tr["Candidates"]];
    Print["run them in the background (one licence slot, one after the other):\n  sh ", FileNameJoin[{jobDir, "relation_command.sh"}],
      "\nwait for them:\n  ", FileNameJoin[{$PFBRoot, "bin", "wait_job"}], " ", Last[tr["Trials"]], " --match ", FileNameJoin[{jobDir, "relation_command.sh"}], " --timeout <seconds>",
      "\nthen: relation_sector.wls run.wl ", a[[2]], " --collect"];
    CoreVerdict["relation_sector", "pass", <|"job" -> jobDir, "candidates" -> (PFBSectorString /@ tr["Candidates"]), "command" -> "sh " <> FileNameJoin[{jobDir, "relation_command.sh"}]|>]];
  rep = PFBRelationReport[jobDir];
  If[rep === $Failed, CoreVerdict["relation_sector", "usage", <|"message" -> "no trials (run without --collect first)"|>]];
  Do[Print[PFBSectorString[r["Sector"]], ": ", r["Status"], If[ListQ[r["Removed"]], ", removes " <> ToString[r["Removed"], InputForm] <>
      If[r["NewExtra"] === {}, "", ", brings " <> ToString[r["NewExtra"], InputForm]], ""]], {r, rep["Trials"]}];
  If[MissingQ[rep["Best"]],
    Print["no candidate removes every extra master: try more (--max), or keep them as extra columns and remove them with bin/extra_masters.wls"];
    CoreVerdict["relation_sector", "fail", <|"job" -> jobDir, "message" -> "no candidate removes every extra master"|>]];
  Print["best: ", PFBSectorString[rep["Best"]], ". Give it to the jobs of this tower with \"ExtraRoots\" -> {", ToString[rep["Best"], InputForm],
    "} (PFBSubtreeJob), or let bin/extra_masters.wls use it for the expansion job."];
  CoreVerdict["relation_sector", "pass", <|"job" -> jobDir, "best" -> PFBSectorString[rep["Best"]], "extra" -> ToString[rep["NonUT"], InputForm]|>]];
