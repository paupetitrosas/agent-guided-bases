(* ::Package:: *)

(* ::Title:: *)
(*PoleFreeBasis`Subtree`: subtree reductions (FiniteFlow + LiteIBP jobs)*)


BeginPackage["PoleFreeBasis`Subtree`", {"PoleFreeBasis`", "PoleFreeBasis`Config`", "PoleFreeBasis`Machine`", "PoleFreeBasis`Kira`", "PoleFreeBasis`System`", "PoleFreeBasis`Slice`",
  "MaximalCutBasis`", "SkillCore`Tools`", "SkillCore`Records`", "SkillCore`Pages`", "MaximalCutBasis`Sectors`", "MaximalCutBasis`Rules`", "MaximalCutBasis`Family`"}];

PFBSubtreeJob::usage = "PFBSubtreeJob[sys, runDir, spec] writes a reduction job folder runDir/jobs/<Name> (job.m, system.m, families.wl) and returns it. spec keys: Name, Roots (list {fam, sector}; Automatic needs SectorKey), SectorKey (kept in job.m: the sector the runner credits the job's tools to in the run's ledger, citations.m; without it, the whole run), Images (True: add the image sectors as roots), Pool, PoolSpec ({dots, numerators} on the roots and on their one-propagator subsectors; default {1, 1, 0, 0}: the roots' natural integrals and the subsectors' corners, because the time of every point grows with the pool; an automatic pool also gets the integrals of the roots' current masters; a job written with the default before 2026-10-11 ({2, 2, 2, 1}) keeps it when called again without a PoolSpec), PoolExtra (the structural reading's candidates), PoolDerivatives, Focus, FocusFamilies, Points, Derivatives, Seeds, SeedBump, Threads, TakeUsed, PreImage, Hosts, MaxHostRounds, AllowNonUT (keep masters the system lacks as extra columns instead of asking for host sectors; bin/extra_masters.wls then removes them exactly), ExtraRoots (sectors added to the roots, e.g. the sector bin/relation_sector.wls found), LearnOnly (stop after learning and report the masters: the trials of bin/relation_sector.wls), Analytic (see PFBAnalyticJob), Degrees (after the points, the kinematic degrees of focus rows with FFAllDegrees on the learned system, into degrees.m: PFBDegreeSpec, PFBDegreesJob), Line (expressions on masters along a line, into line.m: PFBDetLineJob), ReuseIds, MaxGB (cap on the whole reduction kernel: the runner refuses a job predicted above it, and bin/ws stops one that goes above it; by default the job compares its needs with the memory free when it runs, under bin/ws's default memory limit), TimeLimit (seconds, default 86400: bin/ws stops the job after it; 0 = none), Kernels, MaxPrimes, MaxDegree, Force, Replace, Reducer (the reducer at the slice point, the job's first point: Automatic, the default of run.wl \"Reducer\" (Automatic when it has none): Kira when Kira and Fermat are found and the subtree lies in one family, else FiniteFlow, with the reason in job.m \"ReducerNote\" and in run.log; \"Kira\": Kira or a refusal saying why; \"FiniteFlow\". The other points are always FiniteFlow's. Learn-only and analytic jobs use FiniteFlow unless their spec asks otherwise; degree and line jobs (Degrees, Line) evaluate the learned system and are always FiniteFlow's: \"Reducer\" -> \"Kira\" is refused for them). A job folder belongs to one specification and one system: called again with the same ones it keeps the job as it is (host rounds, status, reductions) and only updates the resource settings (MaxGB, Threads, Kernels, ...); with another specification, or after an accepted change of the basis, it refuses unless \"Replace\" -> True: then, when only the basis changed, the identities are kept and the reductions redone; when the specification changed, everything is deleted (to keep identities, give a new Name with \"ReuseIds\" -> \"<old job>/ibps\").";
PFBSubtreeCommand::usage = "PFBSubtreeCommand[jobDir] is the shell command that runs the job (with the host-round loop), for a background run or a cluster, under the job's \"TimeLimit\" and \"MaxGB\" (bin/ws --timeout, --memory; bin/ws --set changes them while it runs). Run again after the job died, it resumes at the first missing point; wait for it with bin/wait_job.";
PFBCleanJob::usage = "PFBCleanJob[jobDir] deletes the scratch of a reduction job once its sector is done: the identities (ibps*), Kira's folder (kira/), the serialized system, nonut.m, the raw reductions of a job whose extra masters were removed (raw_<ip>.m) and the memory records (after they are added to the memory model). job.m, system.m, families.wl, status.m, run.log and the reductions red_<ip>.m stay, so the job can be read and run again. Identities that another job of the run reuses (ReuseIds) are kept. Returns the files deleted.";
PFBSubtreeStatus::usage = "PFBSubtreeStatus[jobDir] reads status.m (or <|\"Status\" -> \"not run\"|>). A job that says \"running\" but whose kernel (PID, on this host) is gone is reported as \"killed\": out of memory, stopped, or the machine restarted; its command resumes at the first missing point. While its command runs again and before the new kernel writes its first status, the job is reported as \"running\" (\"Phase\" -> \"starting\", \"Previous\" -> what status.m says). To wait for a job, use bin/wait_job (no licence slot), never a loop of your own.";
PFBReadRed::usage = "PFBReadRed[jobDir, ip] reads the reduction at point ip (1 = the slice point).";
PFBRedFiles::usage = "PFBRedFiles[jobDir] lists the reduction files of a job, by point.";
PFBImportMemory::usage = "PFBImportMemory[jobDir] adds the memory measurements of a finished job to the memory model of this machine (once).";
PFBRandomPoints::usage = "PFBRandomPoints[sys, n, seed] are n random points of prime values (rules for every invariant), for fits and checks away from the slice point.";
PFBLocalSliceJob::usage = "PFBLocalSliceJob[sys, runDir, point, derivatives, opts] writes the job that computes a whole slice locally: every top sector of every family as a root, every master in the focus, no pool. The runner refuses it when the predicted memory does not fit; the job folder can then be run on a larger machine. opts as for PFBSubtreeJob.";
PFBExtraMasters::usage = "PFBExtraMasters[jobDir] lists the masters of a job's reductions that are not masters of the system (non-ut integrals, kept as extra columns by a job with \"AllowNonUT\" -> True).";
PFBEliminateExtra::usage = "PFBEliminateExtra[red, xred] removes the extra (non-ut) masters X of the reduction red exactly: xred is a reduction at the same point whose pool holds every X and whose masters are all system masters (the expansion job of PFBExpansionJob). Every row of red (Dm, Rp, dRp) is a vector on its masters; X -> its expansion makes it a vector on system masters only. Exact in eps at that point: derivatives are reduced before X is replaced, so the expansion is never differentiated. Returns the reduction with \"ExtraEliminated\" -> X, or a String saying why not.";
PFBExpansionJob::usage = "PFBExpansionJob[sys, runDir, jobDir, opts] writes the expansion job of a job with extra masters: the same points and derivatives, the extra masters as its only pool, no focus, and roots large enough to reduce them (opts \"Roots\"; by default the job's roots, the sector of relation.m when bin/relation_sector.wls found one, and otherwise every top sector of the system that contains an extra master's sector). Only the extra masters' rows are reconstructed at each point, so a point costs little even when the identities are those of the whole family. opts as for PFBSubtreeJob (Seeds, MaxGB, ReuseIds, Name). Returns the job folder.";
PFBCollectExpansion::usage = "PFBCollectExpansion[jobDir, xjobDir] removes the extra masters of every reduction of jobDir with the expansion job xjobDir (PFBEliminateExtra, point by point): the raw reductions are kept as raw_<ip>.m and red_<ip>.m become reductions on system masters only, which calibrate, scan, fit and verify like any other. Returns <|\"Points\", \"Missing\", \"Extra\"|>.";
PFBRelationTrials::usage = "PFBRelationTrials[sys, runDir, jobDir, opts] writes the trials that find which sector supplies the relation that removes a job's extra masters: one learn-only job per candidate (a sector of the same family that contains an extra master's sector and is not in the job's subtree; sectors with masters of the system first, then by size, at most \"MaxTrials\" (6)), each with the job's roots plus the candidate and the extra masters as its pool (so that each trial must reduce them), reusing the job's identities. Returns <|\"Trials\" -> {job folders}, \"Candidates\", \"Command\"|>; the command runs them one after the other.";
PFBRelationReport::usage = "PFBRelationReport[jobDir] reads the trials of PFBRelationTrials and writes relation.m in the job: per candidate the extra masters it removes, and \"Best\", the smallest candidate that removes all of them (add it with \"ExtraRoots\" to the jobs of this tower, or let PFBExpansionJob use it). Returns that association.";
PFBAnalyticJob::usage = "PFBAnalyticJob[sys, runDir, jobDir, exprs, opts] writes the job that reconstructs, as functions of eps and the invariants, the reduction of the root-free expressions exprs (integrals, ut[k] for current masters) on a few masters: by default the masters of the expressions' own sector (opts \"Masters\": labels). FiniteFlow evaluates the learned system at as many points as the reconstruction needs, each a numerical solve, so a coefficient is identified exactly instead of guessed from its values at a few reduction points. It reuses the job's roots, seeds and identities; one point (the job's first) is reduced too, and the result is checked against it. opts: \"Fix\" (rules fixing invariants, e.g. the unit scale, to make the reconstruction cheaper: the result then holds at those values only), \"Name\" (default <job>_a). The runner writes analytic.m (PFBAnalyticCoefficients). Returns the job folder.";
PFBAnalyticCoefficients::usage = "PFBAnalyticCoefficients[jobDir] reads analytic.m of an analytic job: <|\"Exprs\", \"Masters\", \"Coefficients\" (expressions x masters, factored rational functions of \"Vars\"), \"Fix\", \"Check\" (against the reduction at the first point), \"NonUT\", \"Seconds\"|>, or $Failed.";
PFBSectorRoots::usage = "PFBSectorRoots[sys, key, images] are the roots {fam, sector} of a sector key: the base sector and, with images True, its images.";

Begin["`Private`"];


PFBSectorRoots[sys_Association, {fn_, sec_List}, images_ : True] := Join[{{fn, sec}}, If[TrueQ[images], {#, sec} & /@ PFBImagesOf[sys, fn], {}]];

PFBRandomPoints[sys_Association, n_Integer, seed_Integer : 7] := BlockRandom[
  Table[Thread[sys["Invariants"] -> RandomSample[Prime[Range[200, 2000]], Length[sys["Invariants"]]]], {n}], RandomSeeding -> seed];

(* FiniteFlow, its library, LiteRed and LiteIBP for every job; Kira, Fermat and core/bin/limit (Kira's time and memory
   limit) for the slice point *)
toolPaths[] := Join[Association[Table[t -> Replace[MCBPath[t], _Missing -> None], {t, {"FiniteFlow", "FiniteFlowLibrary", "LiteRed", "LiteIBP", "kira", "fer64"}}]],
  <|"limit" -> With[{f = FileNameJoin[{SkillCore`$CoreRoot, "bin", "limit"}]}, If[FileExistsQ[f], f, None]]|>];

(* the reducer of a job written without "Reducer": run.wl's "Reducer", read from run_info.m (PFBStartRun writes it) *)
runReducer[runDir_String] := Module[{ri = Quiet@Get[FileNameJoin[{runDir, "run_info.m"}]]},
  If[AssociationQ[ri] && AssociationQ[Lookup[ri, "Run", None]], Lookup[ri["Run"], "Reducer", Automatic], Automatic]];

(* Kira at the slice point: the uncut configuration of the family the roots lie in, written by maximal-cut-basis
   (MCBToKiraYAML), with a placeholder for the top-level sectors, which the runner fills with the sectors it reduces.
   An image family is reduced as its base family at the image's mapped point (PFBKiraMappedPoint): the image's
   propagators are the base's with the momentum map applied, and its invariant map is the one that map induces *)
kiraConfig[sys_Association, fam_, dir_String] := Module[{base = PFBBaseOf[sys, fam], fo, tmp = FileNameJoin[{dir, "kira_config"}], out},
  fo = PFBFamily[sys, base];
  If[DirectoryQ[tmp], DeleteDirectory[tmp, DeleteContents -> True]];
  MCBToKiraYAML[fo, tmp, <|"TopLevel" -> {"@TOPLEVEL@"}|>];
  out = <|"Family" -> fam, "KiraFamily" -> fo["NameString"], "D0" -> fo["D0"],
    "InvariantMap" -> If[fam === base, {}, sys["Families"][fam]["Image"]["InvariantMap"]],
    "Names" -> Table[SymbolName[X] -> MCBKiraName[fo, X], {X, fo["InvList"]}],
    "IntegralFamilies" -> Import[FileNameJoin[{tmp, "config", "integralfamilies.yaml"}], "Text"],
    "Kinematics" -> Import[FileNameJoin[{tmp, "config", "kinematics.yaml"}], "Text"]|>;
  DeleteDirectory[tmp, DeleteContents -> True];
  out];

(* the default pool: the root sectors' natural integrals (one dot or one numerator power) and the corners of their
   one-propagator subsectors. Every pool integral and its derivatives are reconstructed at every point, so the time of
   a point grows with the pool: the structural reading's candidates come through PoolExtra, and a rung that needs more
   (the residue fit's pinched integrals, the completion's lower integrals) widens it for its own job *)
$PFBPoolSpec = {1, 1, 0, 0};

(* what a job computes; the other keys of job.m are resources (threads, memory caps) or written by the runner *)
$specKeys = {"Roots", "Points", "Derivatives", "Seeds", "SeedBump", "Pool", "PoolSpec", "PoolExtra", "PoolDerivatives", "Focus",
   "FocusFamilies", "PreImage", "Hosts", "AllowNonUT", "TakeUsed", "LearnOnly", "Analytic", "Degrees", "Line"};
(* keys added after jobs were written: an older job.m without them has their default *)
$specDefaults = <|"LearnOnly" -> False, "Analytic" -> None, "Degrees" -> None, "Line" -> None|>;

(* a degree job (its variants and samples included) and a line job evaluate FiniteFlow's learned system: never Kira's *)
ffMeasureQ[spec_] := AssociationQ[Lookup[spec, "Degrees", None]] || AssociationQ[Lookup[spec, "Line", None]];

PFBSubtreeJob[sys_Association, runDir_String, spec_Association] := Module[{name = Lookup[spec, "Name", "job"], dir, roots, job, model, pts, ders, reducer, choice},
  dir = FileNameJoin[{runDir, "jobs", name}];
  If[! DirectoryQ[dir], CreateDirectory[dir, CreateIntermediateDirectories -> True]];
  roots = Replace[Lookup[spec, "Roots", Automatic], Automatic :> PFBSectorRoots[sys, spec["SectorKey"], Lookup[spec, "Images", True]]];
  roots = DeleteDuplicates[Join[roots, Lookup[spec, "ExtraRoots", {}]]];
  pts = Lookup[spec, "Points", None];
  If[! MatchQ[pts, {{(_ -> _?NumericQ) ..} ..}], Print["PFBSubtreeJob: \"Points\" must be a list of points (rules for every invariant); the first is the slice point."]; Return[$Failed]];
  ders = Lookup[spec, "Derivatives", Automatic];
  If[ders === Automatic, Print["PFBSubtreeJob: give \"Derivatives\" (the invariants of the slice, in its order)."]; Return[$Failed]];
  model = PFBMemoryModel[];
  (* the reducer of the slice point; learn-only and analytic jobs need FiniteFlow's learned system, and so do degree and
     line jobs: run.wl's "Reducer" is not their default, and the choice says why they are FiniteFlow's *)
  reducer = Lookup[spec, "Reducer", Which[TrueQ[Lookup[spec, "LearnOnly", False]] || AssociationQ[Lookup[spec, "Analytic", None]], "FiniteFlow",
    ffMeasureQ[spec], Automatic, True, runReducer[runDir]]];
  If[! MemberQ[{Automatic, "Kira", "FiniteFlow"}, reducer], Print["PFBSubtreeJob: \"Reducer\" is Automatic, \"Kira\" or \"FiniteFlow\", not ", reducer, "."]; Return[$Failed]];
  choice = PFBReducerChoice[reducer, <|"KiraAvailable" -> (MCBAvailableQ["kira"] && MCBAvailableQ["fer64"]), "Families" -> Union[roots[[All, 1]]],
     "LearnOnly" -> TrueQ[Lookup[spec, "LearnOnly", False]], "Analytic" -> AssociationQ[Lookup[spec, "Analytic", None]], "Degrees" -> ffMeasureQ[spec]|>];
  If[TrueQ[choice["Refused"]], Print["PFBSubtreeJob: \"Reducer\" -> \"Kira\", but Kira cannot reduce this job: ", choice["Reason"], "."]; Return[$Failed]];
  (* "SectorKey": the sector the runner credits the job's tools to in the run's ledger (lib/PFB/JobCitations.wl) *)
  job = <|"Name" -> name, "Created" -> PFBTimeStamp[], "SectorKey" -> Lookup[spec, "SectorKey", None], "Roots" -> roots, "Points" -> pts, "Derivatives" -> ders,
    "Seeds" -> Lookup[spec, "Seeds", <|"Rank" -> 3, "Dots" -> 2|>], "SeedBump" -> Lookup[spec, "SeedBump", <||>],
    "Pool" -> Lookup[spec, "Pool", Automatic], "PoolSpec" -> Lookup[spec, "PoolSpec", $PFBPoolSpec], "PoolExtra" -> Lookup[spec, "PoolExtra", {}],
    "PoolDerivatives" -> Lookup[spec, "PoolDerivatives", True], "Focus" -> Lookup[spec, "Focus", Automatic],
    "FocusFamilies" -> Lookup[spec, "FocusFamilies", All], "Threads" -> Lookup[spec, "Threads", Max[1, Min[8, $ProcessorCount - 1]]],
    "TakeUsed" -> Lookup[spec, "TakeUsed", True], "PreImage" -> Lookup[spec, "PreImage", True], "Hosts" -> Lookup[spec, "Hosts", Automatic],
    "MaxHostRounds" -> Lookup[spec, "MaxHostRounds", 3], "AllowNonUT" -> Lookup[spec, "AllowNonUT", False], "LearnOnly" -> Lookup[spec, "LearnOnly", False], "Analytic" -> Lookup[spec, "Analytic", None],
    "Degrees" -> Lookup[spec, "Degrees", None], "Line" -> Lookup[spec, "Line", None],
    "ReuseIds" -> Lookup[spec, "ReuseIds", None], "MemoryModel" -> model, "MaxGB" -> Lookup[spec, "MaxGB", None], "TimeLimit" -> Lookup[spec, "TimeLimit", 86400],
    "Kernels" -> Lookup[spec, "Kernels", 2], "MaxPrimes" -> Lookup[spec, "MaxPrimes", 200], "MaxDegree" -> Lookup[spec, "MaxDegree", 300],
    "Force" -> Lookup[spec, "Force", False], "ToolPaths" -> toolPaths[],
    "Reducer" -> reducer, "ReducerNote" -> "slice point: " <> choice["Reducer"] <> " (" <> choice["Reason"] <> ")",
    "Kira" -> If[choice["Reducer"] === "Kira", kiraConfig[sys, First[roots][[1]], dir], None]|>;
  If[MemberQ[Values[job["ToolPaths"]][[{1, 3, 4}]], None], Print["PFBSubtreeJob: FiniteFlow, LiteRed and LiteIBP must be found (preflight)."]; Return[$Failed]];
  (* an existing job: the runner skips identities it has already generated (ibps/ids.done), so identities and
     reductions of another specification or of an older basis would be reused silently *)
  If[FileExistsQ[FileNameJoin[{dir, "job.m"}]],
    Module[{old = Quiet@Get[FileNameJoin[{dir, "job.m"}]], oldSys = Quiet@Get[FileNameJoin[{dir, "system.m"}]], sameSpec, sameSys, results},
      (* a job written with the default pool before 2026-10-11 keeps it when no PoolSpec is given (it contains the new default) *)
      If[AssociationQ[old] && ! KeyExistsQ[spec, "PoolSpec"] && Lookup[old, "PoolSpec", None] === {2, 2, 2, 1}, job["PoolSpec"] = old["PoolSpec"]];
      sameSpec = AssociationQ[old] && KeyTake[Join[$specDefaults, old], $specKeys] === KeyTake[job, $specKeys];
      sameSys = oldSys === PFBSystemData[sys];
      results[] := Join[FileNames[{"red_*.m", "raw_*.m"}, dir], Select[FileNameJoin[{dir, #}] & /@ {"status.m", "system.json", "nonut.m", "relation.m", "analytic.m", "times.m", "degrees.m", "line.m", "kira_fallback.m"}, FileExistsQ]];
      Which[
        sameSpec && sameSys,
          (* the same job: keep what the runner added (host sectors) and its status; the resource settings may change *)
          job = Join[job, KeyTake[old, {"Created", "HostRoots", "HostRound", "ReuseIds"}]],
        ! TrueQ[Lookup[spec, "Replace", False]],
          Print["PFBSubtreeJob: the job ", name, " exists ", If[sameSpec, "for an older basis (a change was accepted since it was written)",
              "for another specification (points, seeds, roots or pool)"], "; its reductions would be stale. Give a new \"Name\" (with \"ReuseIds\" -> \"",
            FileNameJoin[{dir, "ibps"}], "\" to keep its identities), or \"Replace\" -> True."];
          Return[$Failed],
        sameSpec,
          (* only the masters changed: the identities still hold; the serialized system (which contains the old
             master definitions), the reductions and the status do not *)
          PFBImportMemory[dir];
          job = Join[job, KeyTake[old, {"Created", "HostRoots", "HostRound", "ReuseIds"}]];
          Quiet[DeleteFile /@ Join[results[], FileNames[{"posints_*.mx", "sids_*.json"}, FileNameJoin[{dir, "ibps"}], Infinity]]],
        True,
          (* another specification: everything goes; identities can be kept through a new job with ReuseIds instead *)
          PFBImportMemory[dir];
          Quiet[DeleteDirectory[#, DeleteContents -> True]] & /@ Select[FileNames["ibps*", dir], DirectoryQ];
          Quiet[DeleteFile /@ Join[results[], Select[FileNameJoin[{dir, #}] & /@ {"memory.m", "memory.imported"}, FileExistsQ]]]]]];
  Put[job, FileNameJoin[{dir, "job.m"}]];
  Put[PFBSystemData[sys], FileNameJoin[{dir, "system.m"}]];
  Export[FileNameJoin[{dir, "families.wl"}], PFBFamiliesCode[sys], "Text"];
  PFBPrint["job ", name, ": roots ", PFBSectorString /@ roots, ", ", Length[pts], " point(s), seeds ", job["Seeds"], ", ", job["ReducerNote"],
    If[NumericQ[job["MaxGB"]], ", kernel capped at " <> ToString[job["MaxGB"]] <> " GB", ""], ", time limit ", job["TimeLimit"], " s"];
  dir];

PFBLocalSliceJob[sys_Association, runDir_String, point_List, ders_List, opts_Association : <||>] := Module[{keys = PFBSectorKeys[sys], tops, roots},
  (* top sectors: not contained in another sector of the same family *)
  tops = Select[keys, Function[k, ! AnyTrue[keys, #[[1]] === k[[1]] && # =!= k && And @@ Thread[k[[2]] <= #[[2]]] &]]];
  roots = Flatten[Table[Join[{t}, {#, t[[2]]} & /@ PFBImagesOf[sys, t[[1]]]], {t, tops}], 1];
  PFBSubtreeJob[sys, runDir, Join[<|"Name" -> "local_slice", "Roots" -> roots, "Points" -> {point}, "Derivatives" -> ders,
      "Pool" -> {}, "PoolDerivatives" -> False, "Focus" -> Automatic|>, opts]]];

quote[s_String] := "'" <> StringReplace[s, "'" -> "'\\''"] <> "'";

(* the job's limits for bin/ws: "TimeLimit" (seconds, 0 = none) and "MaxGB" (else bin/ws's default memory limit) *)
wsLimits[jobDir_String] := Module[{job = Replace[Quiet@Get[FileNameJoin[{jobDir, "job.m"}]], Except[_Association] -> <||>], t, m},
  t = Lookup[job, "TimeLimit", 86400]; m = Lookup[job, "MaxGB", None];
  StringJoin[If[NumericQ[t] || t === None, " --timeout " <> ToString[If[NumericQ[t], Round[t], 0]], ""],
    If[NumericQ[m], " --memory " <> ToString[N[m], InputForm], ""]]];

PFBSubtreeCommand[jobDir_String] := Module[{ws = FileNameJoin[{PoleFreeBasis`$PFBRoot, "bin", "ws"}], sc = FileNameJoin[{PoleFreeBasis`$PFBRoot, "bin", "subtree.wls"}]},
  "cd " <> quote[jobDir] <> " && n=0; while :; do " <> quote[ws] <> wsLimits[jobDir] <> " " <> quote[sc] <> " " <> quote[jobDir] <> " >> run.log 2>&1; rc=$?; " <>
   "n=$((n+1)); [ $rc -eq 4 ] && [ $n -lt 6 ] || break; done; exit $rc"];

PFBCleanJob[jobDir_String] := Module[{jobs = Select[FileNames["*", DirectoryName[ExpandFileName[jobDir]]], DirectoryQ], users, gone},
  (* jobs whose ReuseIds points into this one still need its identities *)
  users = Select[DeleteCases[jobs, ExpandFileName[jobDir]], Function[o, With[{r = Lookup[Replace[Quiet@Get[FileNameJoin[{o, "job.m"}]], Except[_Association] -> <||>], "ReuseIds", None]},
      StringQ[r] && StringStartsQ[ExpandFileName[r], ExpandFileName[jobDir]]]]];
  PFBImportMemory[jobDir];
  gone = Join[If[users === {}, Select[FileNames["ibps*", jobDir], DirectoryQ], {}], Select[{FileNameJoin[{jobDir, "kira"}]}, DirectoryQ],
    Select[FileNameJoin[{jobDir, #}] & /@ {"system.json", "nonut.m", "memory.m", "memory.imported"}, FileExistsQ], FileNames["raw_*.m", jobDir]];
  Quiet[If[DirectoryQ[#], DeleteDirectory[#, DeleteContents -> True], DeleteFile[#]]] & /@ gone;
  If[users =!= {}, PFBPrint["job ", FileNameTake[jobDir], ": identities kept, reused by ", FileNameTake /@ users]];
  gone];

(* a process of this host runs the job: its command line names "subtree.wls <job folder>" (bin/ws and wolframscript
   do; the kernel does not), followed by a space, a slash or the end (job k374 is not job k374w) *)
jobRunningQ[jobDir_String] := Module[{out = Quiet@RunProcess[{"ps", "-ww", "-eo", "args="}, "StandardOutput"], dirs},
  If[! StringQ[out], Return[False]];
  dirs = DeleteDuplicates[StringReplace[#, "/" .. ~~ EndOfString -> ""] & /@ {jobDir, ExpandFileName[jobDir]}];
  AnyTrue[StringSplit[out, "\n"], Function[l, ! StringContainsQ[l, "wait_job"] && AnyTrue[dirs, Function[d,
      AnyTrue[StringPosition[l, "subtree.wls " <> d], #[[2]] == StringLength[l] || MemberQ[{" ", "/"}, StringTake[l, {#[[2]] + 1}]] &]]]]]];

PFBSubtreeStatus[jobDir_String] := Module[{f = FileNameJoin[{jobDir, "status.m"}], st, here, writerGone},
  st = If[FileExistsQ[f], Replace[Quiet@Get[f], Except[_Association] -> <|"Status" -> "unreadable"|>], <|"Status" -> "not run"|>];
  here = Lookup[st, "Host", $MachineName] === $MachineName;
  (* /proc/<pid> on Linux; kill -0 or ps -p where there is no /proc (macOS) *)
  writerGone = ! (IntegerQ[Lookup[st, "PID", None]] && PFBProcessAliveQ[st["PID"]]);
  Which[
    (* the job runs again (or for the first time) while status.m still holds what the previous run wrote: the runner
       writes "running" only once its kernel has started and loaded the packages (a "running" without a PID was
       written by an older runner, which may still be running it) *)
    here && writerGone && ! (st["Status"] === "running" && ! IntegerQ[Lookup[st, "PID", None]]) && jobRunningQ[jobDir],
      st = Join[st, <|"Status" -> "running", "Phase" -> "starting", "Previous" -> st["Status"],
         "Message" -> "the job runs again (waiting for a licence slot, or loading); status.m still holds the previous run's \"" <> ToString[st["Status"]] <> "\""|>],
    (* a running job whose kernel is gone was killed (the runner writes its final status itself) *)
    st["Status"] === "running" && here && IntegerQ[Lookup[st, "PID", None]] && writerGone,
      st = Join[st, <|"Status" -> "killed", "Message" -> "the job's kernel is gone without a final status during " <>
         ToString[Lookup[st, "Phase", "?"]] <> If[KeyExistsQ[st, "Point"], " of point " <> ToString[st["Point"]], ""] <> ": " <>
         With[{lim = limitStop[jobDir]}, If[StringQ[lim], lim <> " (job.m \"TimeLimit\" and \"MaxGB\", or PFBSubtreeJob with them, raise the limits)",
           "killed by the out-of-memory killer, stopped, or the machine restarted"]] <>
         "; run its command again: the finished points are kept"|>]];
  st];

(* the line bin/ws (core/bin/limit) writes to run.log when it stops the job at its time or memory limit: among the
   last lines when the last run ended that way *)
limitStop[jobDir_String] := Module[{f = FileNameJoin[{jobDir, "run.log"}], ls},
  If[! FileExistsQ[f], Return[None]];
  ls = Take[Select[Quiet@Check[ReadList[f, String], {}], StringTrim[#] =!= "" &], -UpTo[3]];
  ls = Select[ls, StringStartsQ[#, "limit: stopped"] &];
  If[ls === {}, None, StringTrim[StringDrop[Last[ls], 7]]]];

(* reading a job's results also feeds its memory measurements to the model of this machine (once per record) *)
PFBRedFiles[jobDir_String] := (PFBImportMemory[jobDir]; SortBy[FileNames["red_*.m", jobDir], ToExpression[StringCases[FileNameTake[#], DigitCharacter ..][[1]]] &]);

PFBReadRed[jobDir_String, ip_Integer : 1] := With[{f = FileNameJoin[{jobDir, "red_" <> ToString[ip] <> ".m"}]}, If[FileExistsQ[f], Get[f], $Failed]];

PFBImportMemory[jobDir_String] := Module[{f = FileNameJoin[{jobDir, "memory.m"}], g = FileNameJoin[{jobDir, "memory.imported"}], recs, n0},
  If[! FileExistsQ[f], Return[0]];
  recs = Get[f];
  n0 = If[FileExistsQ[g], ToExpression[Import[g, "Text"]], 0];
  Scan[PFBRecordMemory, Select[Drop[recs, n0], NumericQ[#["PeakGB"]] &]];
  Export[g, ToString[Length[recs]], "Text"];
  Length[recs] - n0];


(* ::Section:: *)
(*Masters the system lacks: extra columns, removed exactly*)


(* A subtree can miss a relation that only a sector outside it supplies: the reduction then has a master the system
   does not have (an integral X). With "AllowNonUT" -> True the job keeps X as an extra column, at the cost of a subtree
   reduction. X is removed afterwards with its expansion on system masters at the same point, from a job whose pool is
   just X: every row of the subtree job is a vector on its masters, and replacing X by its expansion is exact in eps
   (the rows are derivatives already reduced; the expansion itself is never differentiated). *)
(* from the reductions (raw ones once removed), or from the status of a job that stopped on them *)
PFBExtraMasters[jobDir_String] := Module[{fromReds, st},
  fromReds = Flatten[Cases[Lookup[Get[#], "Masters", {}] & /@ Join[PFBRedFiles[jobDir], FileNames["raw_*.m", jobDir]], _List]];
  st = Lookup[PFBSubtreeStatus[jobDir], "NonUT", {}];
  Union[Select[Join[fromReds, If[ListQ[st], st, {}]], ! MatchQ[#, _ut] &]]];

PFBEliminateExtra[red_Association, xred_Association] := Module[{mast = red["Masters"], xs, us, xmast = xred["Masters"], xpos, new, pos, Tm, apply},
  If[Sort[red["Point"]] =!= Sort[xred["Point"]], Return["the expansion is not at the reduction's point"]];
  xs = Select[mast, ! MatchQ[#, _ut] &];
  If[xs === {}, Return[red]];
  If[! AllTrue[xmast, MatchQ[#, _ut] &], Return["the expansion has masters the system lacks itself: " <> ToString[Select[xmast, ! MatchQ[#, _ut] &], InputForm] <>
     " (give its job larger roots: bin/relation_sector.wls says which sector supplies the relation)"]];
  If[! SubsetQ[xred["Pool"], xs], Return["the expansion's pool lacks " <> ToString[Complement[xs, xred["Pool"]], InputForm]]];
  xpos = AssociationThread[xred["Pool"] -> Range[Length[xred["Pool"]]]];
  us = Select[mast, MatchQ[#, _ut] &];
  (* the system masters the expansions bring that the reduction did not have go after its own *)
  new = Join[us, Complement[Union @@ (xmast[[Flatten[Position[xred["Rp"][[xpos[#]]], c_ /; c =!= 0, {1}, Heads -> False]]]] & /@ xs), us]];
  pos = AssociationThread[new -> Range[Length[new]]];
  (* Tm[[a]]: old master a on the new masters *)
  Tm = Table[If[MatchQ[mast[[a]], _ut], UnitVector[Length[new], pos[mast[[a]]]],
      Module[{v = ConstantArray[0, Length[new]], row = xred["Rp"][[xpos[mast[[a]]]]]}, Do[If[row[[b]] =!= 0, v[[pos[xmast[[b]]]]] += row[[b]]], {b, Length[xmast]}]; v]],
    {a, Length[mast]}];
  apply[v_List] := Together[v . Tm];
  Join[red, <|"Masters" -> new, "Dm" -> Map[apply, red["Dm"], {2}], "Rp" -> apply /@ red["Rp"],
    "dRp" -> If[red["dRp"] === {}, {}, Map[apply, red["dRp"], {2}]], "ExtraEliminated" -> xs|>]];

(* the top sectors of the system that contain sector sec of family fn, as roots in fn itself (sector keys use the base
   family; an image family has the same sectors) *)
topKeysContaining[sys_, fn_, sec_] := Module[{keys = Select[PFBSectorKeys[sys], #[[1]] === PFBBaseOf[sys, fn] &], tops},
  tops = Select[keys, Function[k, ! AnyTrue[keys, # =!= k && And @@ Thread[k[[2]] <= #[[2]]] &]]];
  {fn, #[[2]]} & /@ Select[tops, And @@ Thread[sec <= #[[2]]] &]];

PFBExpansionJob[sys_Association, runDir_String, jobDir_String, opts_Association : <||>] := Module[{job = Quiet@Get[FileNameJoin[{jobDir, "job.m"}]], xs, roots, rel, pts, red1},
  xs = PFBExtraMasters[jobDir];
  If[xs === {}, Print["PFBExpansionJob: the job has no extra masters."]; Return[$Failed]];
  If[! AssociationQ[job], job = <||>];
  red1 = PFBReadRed[jobDir, 1];
  pts = Lookup[job, "Points", If[AssociationQ[red1], {red1["Point"]}, None]];
  rel = Quiet@Get[FileNameJoin[{jobDir, "relation.m"}]];
  roots = Replace[Lookup[opts, "Roots", Automatic], Automatic :> DeleteDuplicates[Join[Lookup[job, "Roots", {}], Lookup[job, "HostRoots", {}],
       If[AssociationQ[rel] && ListQ[Lookup[rel, "Best", None]], {rel["Best"]},
         Flatten[topKeysContaining[sys, #[[1]], Boole[Positive[List @@ Rest[#]]]] & /@ xs, 1]]]]];
  PFBSubtreeJob[sys, runDir, Join[<|"Name" -> FileNameTake[jobDir] <> "_x", "SectorKey" -> Lookup[job, "SectorKey", None], "Roots" -> roots, "Points" -> pts,
      "Derivatives" -> Lookup[job, "Derivatives", If[AssociationQ[red1], red1["Invariants"], Automatic]], "Seeds" -> Lookup[job, "Seeds", <|"Rank" -> 3, "Dots" -> 2|>],
      "Pool" -> xs, "PoolExtra" -> {}, "PoolDerivatives" -> False, "Focus" -> {}, "MaxGB" -> Lookup[job, "MaxGB", None], "TimeLimit" -> Lookup[job, "TimeLimit", 86400],
      (* the expansions are on the system's masters: after a change of the basis the old ones are wrong, so the job is
         written again (identities kept when only the basis changed) *)
      "Replace" -> True|>,
    KeyDrop[opts, {"Roots"}]]]];

PFBCollectExpansion[jobDir_String, xjobDir_String] := Module[{files = PFBRedFiles[jobDir], done = {}, missing = {}, xs = PFBExtraMasters[jobDir]},
  Do[Module[{ip = ToExpression[StringCases[FileNameTake[f], DigitCharacter ..][[1]]], raw, red, xred, out, fresh},
     raw = FileNameJoin[{jobDir, "raw_" <> ToString[ip] <> ".m"}];
     (* red_<ip>.m is the raw reduction unless an earlier collection eliminated it: a second collection starts again
        from raw_<ip>.m. A raw file beside a reduction the runner wrote since is stale and is replaced *)
     red = Quiet@Get[f];
     fresh = AssociationQ[red] && ! KeyExistsQ[red, "ExtraEliminated"];
     If[! fresh, red = If[FileExistsQ[raw], Quiet@Get[raw], $Failed]];
     If[! AssociationQ[red], AppendTo[missing, {ip, "the reduction (or the raw one it was collected from) cannot be read"}]; Continue[]];
     xred = PFBReadRed[xjobDir, ip];
     If[! AssociationQ[xred], AppendTo[missing, {ip, "no expansion at this point"}]; Continue[]];
     out = PFBEliminateExtra[red, xred];
     If[StringQ[out], AppendTo[missing, {ip, out}]; Continue[]];
     If[fresh, If[FileExistsQ[raw], DeleteFile[raw]]; CopyFile[f, raw]];
     Put[Join[out, <|"ExpansionJob" -> xjobDir|>], f];
     AppendTo[done, ip]], {f, files}];
  <|"Points" -> done, "Missing" -> missing, "Extra" -> xs|>];

PFBRelationTrials[sys_Association, runDir_String, jobDir_String, opts_Association : <||>] := Module[{job = Quiet@Get[FileNameJoin[{jobDir, "job.m"}]], xs, red1, allowed,
    keys, cands, trials, n = Lookup[opts, "MaxTrials", 6], ws = FileNameJoin[{PoleFreeBasis`$PFBRoot, "bin", "ws"}], sc = FileNameJoin[{PoleFreeBasis`$PFBRoot, "bin", "subtree.wls"}],
    cmd, base},
  xs = PFBExtraMasters[jobDir];
  If[xs === {}, Print["PFBRelationTrials: the job has no extra masters."]; Return[$Failed]];
  If[! AssociationQ[job], job = <||>];
  red1 = PFBReadRed[jobDir, 1];
  allowed = If[AssociationQ[red1], Lookup[red1, "Allowed", <||>], <||>];
  base = DeleteDuplicates[Join[Lookup[job, "Roots", {}], Lookup[job, "HostRoots", {}]]];
  keys = PFBSectorKeys[sys];
  (* sectors that contain an extra master's sector and are outside the subtree: those with system masters (certainly
     non-zero) first, then every other superset, smallest first *)
  cands = DeleteDuplicates[Flatten[Table[Module[{fn = x[[1]], sec = Boole[Positive[List @@ Rest[x]]], zer, sup},
       (* propagators of the family that the sector lacks (an ISP is never a propagator) *)
       zer = Complement[Flatten[Position[sec, 0]], Lookup[sys["ISPs"], fn, {}]];
       sup = Table[sec + Total[UnitVector[Length[sec], #] & /@ z], {z, Rest[Subsets[zer]]}];
       (* a sector inside a root is in the subtree already (a job that stopped at "nonut" has no reduction that lists
          its allowed sectors) *)
       sup = Select[sup, Function[s, ! MemberQ[Lookup[allowed, fn, {}], s] && ! AnyTrue[base, #[[1]] === fn && And @@ Thread[s <= #[[2]]] &]]];
       {fn, #} & /@ sup], {x, xs}], 1]];
  cands = Take[SortBy[cands, {! MemberQ[keys, #] &, Total[#[[2]]] &}], UpTo[n]];
  If[cands === {}, Print["PFBRelationTrials: every sector that contains the extra masters is already in the subtree."]; Return[$Failed]];
  trials = Table[PFBSubtreeJob[sys, runDir, <|"Name" -> FileNameTake[jobDir] <> "_rel" <> ToString[i], "SectorKey" -> Lookup[job, "SectorKey", None], "Roots" -> Append[base, cands[[i]]],
      "Points" -> Take[Lookup[job, "Points", {red1["Point"]}], 1], "Derivatives" -> Lookup[job, "Derivatives", red1["Invariants"]],
      "Seeds" -> Lookup[job, "Seeds", <|"Rank" -> 3, "Dots" -> 2|>], "SeedBump" -> Lookup[job, "SeedBump", <||>], "Pool" -> xs, "PoolDerivatives" -> False, "Focus" -> {}, "LearnOnly" -> True,
      (* the job's own PreImage: a trial with more sectors than the job allows would credit the candidate with relations
         that the job, given the candidate as an extra root, still would not have *)
      "AllowNonUT" -> True, "Hosts" -> None, "PreImage" -> Lookup[job, "PreImage", True], "Images" -> False, "MaxGB" -> Lookup[job, "MaxGB", None], "TimeLimit" -> Lookup[job, "TimeLimit", 86400],
      "ReuseIds" -> If[DirectoryQ[FileNameJoin[{jobDir, "ibps"}]], FileNameJoin[{jobDir, "ibps"}], None], "Replace" -> True|>], {i, Length[cands]}];
  If[MemberQ[trials, $Failed], Return[$Failed]];
  cmd = StringRiffle[("(cd " <> quote[#] <> " && " <> quote[ws] <> wsLimits[#] <> " " <> quote[sc] <> " " <> quote[#] <> " >> run.log 2>&1)") & /@ trials, "; "];
  Put[<|"NonUT" -> xs, "Candidates" -> cands, "Trials" -> trials|>, FileNameJoin[{jobDir, "relation_trials.m"}]];
  Export[FileNameJoin[{jobDir, "relation_command.sh"}], cmd <> "\n", "Text"];
  <|"Trials" -> trials, "Candidates" -> cands, "Command" -> cmd|>];

PFBRelationReport[jobDir_String] := Module[{t = Quiet@Get[FileNameJoin[{jobDir, "relation_trials.m"}]], rows, best, out},
  If[! AssociationQ[t], Print["PFBRelationReport: no trials in ", jobDir, " (PFBRelationTrials)."]; Return[$Failed]];
  rows = MapThread[Function[{c, d}, With[{st = PFBSubtreeStatus[d]}, <|"Sector" -> c, "Status" -> st["Status"],
       "Removed" -> If[st["Status"] === "learned", Complement[t["NonUT"], Lookup[st, "NonUT", {}]], Missing["NotRun"]],
       "NewExtra" -> If[st["Status"] === "learned", Complement[Lookup[st, "NonUT", {}], t["NonUT"]], Missing["NotRun"]]|>]], {t["Candidates"], t["Trials"]}];
  (* the smallest sector that removes them all (the trials ran with sectors of system masters first, which says nothing
     about their size): the jobs of the tower take it as an extra root, so a larger one makes every point dearer *)
  best = With[{ok = Select[rows, ListQ[#["Removed"]] && Sort[#["Removed"]] === Sort[t["NonUT"]] && #["NewExtra"] === {} &]},
    If[ok === {}, None, First[MinimalBy[ok, Total[#["Sector"][[2]]] &]]]];
  out = <|"NonUT" -> t["NonUT"], "Trials" -> rows, "Best" -> If[best === None, Missing["NotFound"], best["Sector"]], "Date" -> PFBTimeStamp[]|>;
  Put[out, FileNameJoin[{jobDir, "relation.m"}]];
  out];


(* ::Section:: *)
(*Analytic coefficients*)


PFBAnalyticJob[sys_Association, runDir_String, jobDir_String, exprs0_List, opts_Association : <||>] := Module[{job = Quiet@Get[FileNameJoin[{jobDir, "job.m"}]],
    exprs, ints, top, fam, key, labs, masters, red1},
  If[! AssociationQ[job], job = <||>];
  red1 = PFBReadRed[jobDir, 1];
  exprs = Collect[# /. ut[k_Integer] :> PFBMaster[sys, k]["RootFree"], _j] & /@ exprs0;
  ints = Union[Cases[exprs, _j, Infinity]];
  If[ints === {}, Print["PFBAnalyticJob: the expressions contain no integral."]; Return[$Failed]];
  (* the expressions' own sector: that of their integral with the most propagators *)
  top = First[MaximalBy[ints, Total[Boole[Positive[List @@ Rest[#]]]] &]];
  fam = top[[1]]; key = {PFBBaseOf[sys, fam], Boole[Positive[List @@ Rest[top]]]};
  labs = Replace[Lookup[opts, "Masters", Automatic], {Automatic :> Select[PFBSectorMasters[sys, key], PFBMaster[sys, #]["Family"] === fam &],
     l_List :> (l /. ut[k_] :> k)}];
  If[labs === {}, Print["PFBAnalyticJob: no master to reconstruct on (give \"Masters\")."]; Return[$Failed]];
  masters = ut /@ labs;
  PFBSubtreeJob[sys, runDir, <|"Name" -> Lookup[opts, "Name", FileNameTake[jobDir] <> "_a"], "SectorKey" -> key,
    "Roots" -> DeleteDuplicates[Join[Lookup[job, "Roots", {}], Lookup[job, "HostRoots", {}]]],
    "Points" -> Take[Lookup[job, "Points", If[AssociationQ[red1], {red1["Point"]}, {}]], UpTo[1]],
    "Derivatives" -> Lookup[job, "Derivatives", If[AssociationQ[red1], red1["Invariants"], Automatic]],
    "Seeds" -> Lookup[job, "Seeds", <|"Rank" -> 3, "Dots" -> 2|>], "SeedBump" -> Lookup[job, "SeedBump", <||>],
    "Pool" -> ints, "PoolExtra" -> {}, "PoolDerivatives" -> False, "Focus" -> {}, "AllowNonUT" -> Lookup[job, "AllowNonUT", False],
    "Analytic" -> <|"Exprs" -> exprs, "Masters" -> masters, "Fix" -> Lookup[opts, "Fix", {}]|>, "MaxGB" -> Lookup[job, "MaxGB", None], "TimeLimit" -> Lookup[job, "TimeLimit", 86400],
    "ReuseIds" -> If[DirectoryQ[FileNameJoin[{jobDir, "ibps"}]], FileNameJoin[{jobDir, "ibps"}], None], "Replace" -> Lookup[opts, "Replace", True]|>]];

PFBAnalyticCoefficients[jobDir_String] := With[{f = FileNameJoin[{jobDir, "analytic.m"}]}, If[FileExistsQ[f], Get[f], $Failed]];


End[];
EndPackage[];
