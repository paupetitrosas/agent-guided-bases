#!/usr/bin/env wolframscript
(* Write a subtree reduction job for a sector (and its images) at the slice point and n extra points, and print the
   command that runs it (in the background here, or on a cluster: the job folder is self-contained). Without
   extraPoints, n is run.wl's "ExtraPoints" plus the two points of the gate, as in the sector's script
   (AnalysisPoles.m) and in rung 8's job; 0 writes a job at the slice point alone (the calibration).
   usage: subtree_job.wls run.wl fam/jPATTERN [extraPoints] [rank] [dots] [--pool d,n,sd,sn] [--pool-extra file.m] [--reducer kira|finiteflow|automatic] [--replace]
   The pool is the sector's natural integrals by default (--pool 1,1,0,0); --pool-extra adds a file with a list of
   integrals (the structural reading's candidates). Widen --pool only for a rung that needs it: every pool integral
   costs time at every point.
   The slice point is reduced by Kira when Kira and Fermat are found and the subtree lies in one family, else by
   FiniteFlow (the printed line says which, and why); the other points are FiniteFlow's. --reducer (or run.wl
   "Reducer") forces one: kira refuses a job Kira cannot reduce, finiteflow never uses Kira.
   Start the printed command from the shell, in the background: the job needs a licence slot of its own. Wait for it
   with bin/wait_job <job folder> --timeout S (no licence slot; it ends when the job ends, dies or stalls).
   The job folder is named after the sector. Called again with other points or seeds, or after an accepted change, it
   refuses, because stale identities or reductions would be reused. --replace redoes the job: after an accepted change it
   keeps the identities and redoes the reductions; with other points or seeds it starts from scratch. *)
Get[FileNameJoin[{ParentDirectory[DirectoryName[$InputFileName]], "lib", "PoleFreeBasis.wl"}]];

Module[{a = Rest[$ScriptCommandLine], st, sl, key, sys, n, job, seeds, r, opt, pos, pool, extra, reducer},
(* options with a value first, so that the positional arguments are what is left *)
opt = <||>;
Do[With[{p = Position[a, o]}, If[p =!= {} && p[[1, 1]] < Length[a], opt[o] = a[[p[[1, 1]] + 1]]; a = Delete[a, {{p[[1, 1]]}, {p[[1, 1]] + 1}}]]], {o, {"--pool", "--pool-extra", "--reducer"}}];
pos = Select[a, ! StringStartsQ[#, "--"] &];
If[Length[pos] < 2, Print["usage: subtree_job.wls run.wl fam/jPATTERN [extraPoints] [rank] [dots] [--pool d,n,sd,sn] [--pool-extra file.m] [--reducer kira|finiteflow|automatic] [--replace]"]; CoreVerdict["subtree_job", "usage"]];
st = PFBStartRun[pos[[1]]]; If[st === $Failed, CoreVerdict["subtree_job", "usage", <|"message" -> "no run found"|>]]; sys = st["System"];
sl = PFBCurrentSlice[st["Dir"], st["State"]];
If[sl === $Failed, Print["no current slice"]; CoreVerdict["subtree_job", "usage", <|"message" -> "no current slice"|>]];
key = With[{p = StringSplit[pos[[2]], "/"]}, {ToExpression[p[[1]]], SectorFromName[p[[2]]]}];
n = If[Length[pos] >= 3, ToExpression[pos[[3]]], st["Run"]["ExtraPoints"] + 2];
seeds = st["Run"]["Seeds"];
If[Length[pos] >= 5, seeds = <|"Rank" -> ToExpression[pos[[4]]], "Dots" -> ToExpression[pos[[5]]]|>];
pool = If[KeyExistsQ[opt, "--pool"], ToExpression /@ StringSplit[opt["--pool"], ","], Automatic];
If[pool =!= Automatic && ! MatchQ[pool, {_Integer, _Integer, _Integer, _Integer}], Print["--pool takes four integers: dots,numerators on the roots, dots,numerators on their subsectors"];
  CoreVerdict["subtree_job", "usage"]];
reducer = If[KeyExistsQ[opt, "--reducer"], Lookup[<|"kira" -> "Kira", "finiteflow" -> "FiniteFlow", "automatic" -> Automatic|>, ToLowerCase[opt["--reducer"]], $Failed], None];
If[reducer === $Failed, Print["--reducer takes kira, finiteflow or automatic"]; CoreVerdict["subtree_job", "usage"]];
extra = If[KeyExistsQ[opt, "--pool-extra"], Quiet@Get[ExpandFileName[opt["--pool-extra"]]], {}];
(* it becomes part of the job's specification: a bad file would need --replace, which deletes the identities *)
If[! MatchQ[extra, {___j}], Print["--pool-extra needs a file holding a list of integrals j[...]: ", opt["--pool-extra"], " gives ", Short[extra, 2]];
  CoreVerdict["subtree_job", "usage"]];
job = PFBSubtreeJob[sys, st["Dir"], Join[<|"Name" -> StringReplace[PFBSectorString[key], "/" -> "_"], "SectorKey" -> key,
   "Points" -> Join[{sl["Point"]}, PFBRandomPoints[sys, n, 1]], "Derivatives" -> sl["Derivatives"], "Seeds" -> seeds,
   "MaxGB" -> st["Run"]["MaxGB"], "TimeLimit" -> st["Run"]["TimeLimit"], "Threads" -> Replace[st["Run"]["Threads"], Automatic -> Max[1, Min[8, $ProcessorCount - 1]]],
   "PoolExtra" -> extra, "Replace" -> MemberQ[a, "--replace"]|>, If[pool === Automatic, <||>, <|"PoolSpec" -> pool|>],
   (* without --reducer the job takes run.wl's "Reducer" (Automatic when it has none) *)
   <|"Reducer" -> If[reducer === None, Lookup[st["Run"], "Reducer", Automatic], reducer]|>]];
If[job === $Failed, CoreVerdict["subtree_job", "fail", <|"message" -> "the job was not written (see above)"|>]];
Print["job: ", job];
Print[Lookup[Quiet@Get[FileNameJoin[{job, "job.m"}]], "ReducerNote", ""]];
Print["run it with:\n  ", PFBSubtreeCommand[job], "\nand wait for it with:\n  ", FileNameJoin[{$PFBRoot, "bin", "wait_job"}], " ", job, " --timeout <seconds>"];
CoreVerdict["subtree_job", "pass", <|"job" -> job, "command" -> PFBSubtreeCommand[job], "status" -> PFBSubtreeStatus[job]["Status"],
  "reducer" -> Lookup[Quiet@Get[FileNameJoin[{job, "job.m"}]], "ReducerNote", ""]|>]];
