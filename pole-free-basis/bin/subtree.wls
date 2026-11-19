#!/usr/bin/env wolframscript
(* One subtree reduction of the pole-free-basis skill, at one or more kinematic points, exact in eps.
   usage: subtree.wls <job dir>        (the job dir is written by PFBSubtreeJob: job.m, system.m, families.wl)

   The IBP system covers the root sectors, their subsectors, closed under the sector maps of LiteRed, under the
   symmetry rules of the system and (PreImage) under the sectors of masters that map onto allowed sectors. The
   masters of the system whose integrals all lie in allowed sectors are added as extra integrals, so the reduction
   chooses them as masters. Output, per point ip: red_<ip>.m =
     <|"Masters", "Labels", "Point", "Focus", "Dm", "Pool", "Rp", "dRp", "Invariants", "Roots", "Allowed", "Reducer"|>
   Dm[[k, i]]: (1/pref) d_k (pref U) of the focus master i on the masters; Rp, dRp: the pool and its derivatives.

   Masters that are not masters of the system (non-ut) are kept as extra columns when job.m has "AllowNonUT" -> True
   (status.m lists them under "NonUT"; bin/extra_masters.wls removes them exactly); otherwise the runner adds host
   sectors or stops. With "LearnOnly" -> True it stops after learning and writes the masters to status.m ("learned").

   While it runs, status.m says "running" with the phase, the point and the kernel's PID (bin/wait_job waits on it
   without a licence slot). A point whose reduction is already there (same point, masters and pool) is kept, so a
   job killed by the out-of-memory killer resumes at the first missing point. Before each point the threads are
   planned again from the memory free at that moment, and a point that no longer fits stops the job ("refused", the
   finished points kept). Each point's wall-clock and CPU time go to times.m; a point that got far less CPU than
   wall-clock time (the machine slept, or other jobs took the CPU or the memory) is flagged in run.log.

   The slice point (the first point) is reduced by Kira when job.m's "Reducer" is Automatic or "Kira", the job carries
   the Kira configuration of its family (PFBSubtreeJob writes it when Kira and Fermat are found and the roots lie in one
   family) and the allowed sectors lie in that family with no symmetry rule of the system inside them: an uncut job with
   the invariants fixed and d symbolic, whose targets are the focus rows, the pool and its derivatives and the
   definitions of the masters, projected onto the system's masters (lib/PFB/Kira.wl). red_1.m then has the same keys
   and "Reducer" -> "Kira"; the other points are FiniteFlow's. A job with only the slice point needs no identities and
   no learning. Kira runs under half of the time the job has left. When Kira gives no reduction (stopped at a limit,
   integrals left unreduced, masters the system lacks), FiniteFlow reduces the point, status.m says why ("KiraFallback"),
   and kira_fallback.m keeps the reason, so a later run of the job goes to FiniteFlow at once; with "Reducer" -> "Kira"
   the job fails instead.
   A job with "Degrees", "Line", "LearnOnly" or "Analytic" evaluates FiniteFlow's learned system: FiniteFlow reduces all
   its points ("Reducer" -> "Kira" fails such a job).

   With "Analytic" -> <|"Exprs" -> {...}, "Masters" -> {...}, "Fix" -> {...}|> (PFBAnalyticJob) the runner also
   reconstructs the reduction of those expressions on those masters as functions of eps and the invariants (the ones
   not fixed), from many cheap evaluations of the learned system, writes analytic.m, and checks it against the
   reduction at the first point.
   With "Degrees" -> <|...|> (PFBDegreeSpec) it measures, after the points, the kinematic degrees of the focus rows (and
   of the variants of the DE it lists) with FFAllDegrees on the learned system, nothing reconstructed, and the exact
   rows at its sample points: degrees.m (lib/PFB/DegreeGraph.wl). With "Line" -> <|...|> (PFBDetLineJob) it reconstructs
   expressions on masters along a line at a numerical eps, univariate, checked at the first point: line.m.

   The tools that produced a result are credited in the run's ledger, <run>/citations.m (lib/PFB/JobCitations.wl), when
   the result is written, for the job's sector (job.m "SectorKey", else the whole run): LiteRed and LiteIBP, FiniteFlow
   for a point it reduced and for what its learned system gave (a line job's unless its check refuted the line), Kira
   and Fermat once Kira's reduction of the slice point is written. status.m lists them ("Tools"), every run's of the
   job; a job outside a pole-free run's jobs folder appends nothing, and its status.m keeps the record.

   Exit codes (those of the skills' core, core/README.md): 0 done (or learned); 1 refused (predicted memory above what
   is free) or non-ut masters without a fix; 4 non-ut masters, host sectors added to job.m, run again; 3 failure. The last line of
   output is the JSON verdict; status.m says what happened, memory.m records the peak memory of each phase. *)

jobDir = $ScriptCommandLine[[2]];
(* the toolkit's self-contained modules, found from this script before the job folder becomes the directory *)
skillLib = FileNameJoin[{ParentDirectory[DirectoryName[ExpandFileName[$InputFileName]]], "lib", "PFB"}];
SetDirectory[jobDir];
jobAbs = Directory[];
(* only the tool paths now; job.m and system.m are read again once the families are defined *)
job0 = Get["job.m"];
t0 = AbsoluteTime[];
say[x___] := (WriteString["stdout", StringJoin[ToString[#, OutputForm] & /@ {x}], "\n"]);
(* "Tools": the tools this job credited in the run's ledger, its earlier runs' included (credit, below) *)
credited = {};
(* PID and host let bin/wait_job and PFBSubtreeStatus tell a running job from one whose kernel was killed *)
setStatus[s_String, extra_Association : <||>] := Put[Join[<|"Status" -> s, "Date" -> DateString[], "Seconds" -> Round[AbsoluteTime[] - t0],
    "PID" -> $ProcessID, "Host" -> $MachineName|>, extra, If[credited === {}, <||>, <|"Tools" -> credited|>]], "status.m"];
(* the runner loads none of the skills' libraries (only the toolkit's self-contained modules), so the JSON verdict is written here *)
finish[code_Integer] := With[{st = Replace[Quiet@Get["status.m"], Except[_Association] -> <||>]},
  Print[ExportString[<|"tool" -> "subtree", "outcome" -> Switch[code, 0, "pass", 1, "fail", 4, "rerun", _, "error"], "exit" -> code,
     "job" -> jobDir, "status" -> ToString[Lookup[st, "Status", "?"]], "message" -> ToString[Lookup[st, "Message", ""]]|>, "RawJSON", "Compact" -> True]];
  Exit[code]];
memRecs = If[FileExistsQ["memory.m"], Get["memory.m"], {}];
(* the memory and process readers of the toolkit (lib/PFB/Machine.wl, self-contained): /proc on Linux; sysctl, vm_stat
   and ps on macOS, where the peak of a phase is sampled once a second *)
Get[FileNameJoin[{skillLib, "Machine.wl"}]];
Get[FileNameJoin[{skillLib, "Kira.wl"}]];
Get[FileNameJoin[{skillLib, "JobCitations.wl"}]];
credited = PFBJobPreviousTools[jobAbs];
hwm[] := PFBPeakGB[$ProcessID];
rss[] := PFBProcessRSSGB[$ProcessID];
memAvail[] := PFBMemAvailableGB[];
(* the peak resident memory is reset before each phase, so that each record measures that phase *)
resetHWM[] := PFBResetPeak[$ProcessID];
(* CPU time of this kernel, every thread (FiniteFlow's included), and of the processes it waited for (Kira, Fermat),
   from /proc: utime + stime + cutime + cstime *)
clkTck = Replace[Quiet@ToExpression[StringTrim[RunProcess[{"getconf", "CLK_TCK"}, "StandardOutput"]]], Except[_Integer?Positive] -> 100];
cpuSeconds[] := Module[{t = Quiet@Import["/proc/" <> ToString[$ProcessID] <> "/stat", "Text"], f},
   If[! StringQ[t], Return[Missing[]]];
   f = StringSplit[Last[StringSplit[t, ")"]]];
   If[Length[f] < 15, Missing[], N[Total[ToExpression /@ f[[12 ;; 15]]]/clkTck]]];
(* other processes above 1 GB: what competes for the memory *)
heavyOthers[] := Module[{rows = Quiet@StringSplit[StringSplit[RunProcess[{"ps", "-eo", "pid=,rss=,comm="}, "StandardOutput"], "\n"]]},
   If[! ListQ[rows], Return[{}]];
   Select[Cases[rows, {pid_, rss_, comm__} :> {ToExpression[pid], ToExpression[rss]/1024.^2, StringRiffle[{comm}]}], #[[2]] > 1 && #[[1]] =!= $ProcessID &] //
    Map[#[[3]] <> " (pid " <> ToString[#[[1]]] <> ", " <> ToString[NumberForm[#[[2]], {3, 1}]] <> " GB)" &]];
(* the job's own memory limit (GB) when it runs under bin/ws (core/bin/limit, registry in $MCB_LIMIT_JOB): the kernel and
   everything below it are stopped above it, so the plans below stay under it too; Infinity outside such a job *)
hardGB[] := Module[{f = Environment["MCB_LIMIT_JOB"], l},
   If[! StringQ[f] || ! FileExistsQ[f], Return[Infinity]];
   l = Quiet@Check[ReadList[f, String], {}];
   l = If[Length[l] >= 2, StringSplit[l[[2]]], {}];
   If[Length[l] >= 3 && l[[1]] === "limits" && StringMatchQ[l[[3]], DigitCharacter ..] && l[[3]] =!= "0", N[ToExpression[l[[3]]]/1024.^2], Infinity]];
recordMem[rec_Association] := (AppendTo[memRecs, Join[<|"Date" -> DateString[], "Host" -> $MachineName, "Job" -> FileNameTake[jobDir]|>, rec]]; Put[memRecs, "memory.m"]);

(* ---- tools ---- *)
tp = job0["ToolPaths"];
dirOf[p_String] := If[DirectoryQ[p], p, DirectoryName[p]];
If[StringQ[tp["FiniteFlowLibrary"]], PrependTo[$LibraryPath, tp["FiniteFlowLibrary"]]];
Do[If[StringQ[tp[t]], $Path = DeleteDuplicates[Append[$Path, dirOf[tp[t]]]]], {t, {"FiniteFlow", "LiteRed", "LiteIBP"}}];
Needs["FiniteFlow`"];
Get[If[StringQ[tp["LiteRed"]], If[DirectoryQ[tp["LiteRed"]], FileNameJoin[{tp["LiteRed"], "LiteRed2023.m"}], tp["LiteRed"]], "LiteRed2023`"]];
Needs["LiteIBP`"];
If[! MemberQ[$Packages, "LiteIBP`"], setStatus["failed", <|"Message" -> "LiteIBP could not be loaded"|>]; finish[3]];
(* the degrees of the DE without reconstruction (job.m "Degrees") and the expressions along a line ("Line"): FiniteFlow
   only, from the skill's own lib (the job folder holds no code) *)
Get[FileNameJoin[{skillLib, "DegreeGraph.wl"}]];
(* a library older than FiniteFlow.m loads, then writes $Failed into LiteIBP's derivative rows or hangs: stop now *)
With[{pb = PFBFFLibraryProblem[]}, If[StringQ[pb], setStatus["failed", <|"Message" -> pb|>]; finish[3]]];


(* ---- families, then the job and the masters (their j[...] must be LiteRed's, read once the families exist) ---- *)
Get["families.wl"];
fams = PFBFamilyOrder;
job = Get["job.m"]; sysd = Get["system.m"];
(* the run's ledger (<run>/citations.m): the tools that produced what was just written (PFBJobTools: "Kira", "FiniteFlow",
   "Identities"), each once (PFBJobCredit) *)
credit[what_String] := (credited = PFBJobCredit[jobAbs, job, credited, what]);
With[{heads = Union[Cases[sysd["Masters"][[All, "Def"]], h_[f_Symbol /; MemberQ[fams, f], __Integer] :> h, Infinity]]},
  If[heads =!= {} && heads =!= {j}, setStatus["failed", <|"Message" -> "the integrals of system.m are not LiteRed's j (context clash): " <> ToString[heads]|>]; finish[3]]];
invs = sysd["Invariants"]; ders = job["Derivatives"];
vars = Join[{eps}, invs];
say["families loaded in ", Round[AbsoluteTime[] - t0], " s: ", fams];
setStatus["running", <|"Phase" -> "identities"|>];

secOf[x_] := Boole[Positive[#]] & /@ (List @@ Rest[x]);
nzs[f_] := nzs[f] = secOf /@ NonZeroSectors[f];
subOf[v_, w_] := And @@ Thread[v <= w];
listOr[x_] := If[ListQ[x], x, {}];
imageOf[f_, v_] := Module[{jz = js @@ Join[{f}, v]},
   Which[MemberQ[listOr[ExtMappedSectors[f]], jz], With[{im = LIBPExtMapped[jz]}, {im[[1]], secOf[im]}],
     MemberQ[listOr[MappedSectors[f]], jz], {f, secOf[jz /. SectorsMappings[f]]},
     True, None]];
termImage[fv_] := termImage[fv] = Module[{cur = fv, nxt, k = 0}, While[(nxt = imageOf @@ cur) =!= None && k < 10, cur = nxt; k++]; cur];
masters = sysd["Masters"];
mKey[m_] := {m["Family"], m["Sector"]};

(* ---- allowed sectors ---- *)
roots = DeleteDuplicates[Join[job["Roots"], Lookup[job, "HostRoots", {}]]];
symPairs = DeleteDuplicates[Flatten[Table[Module[{l = {r[[1, 1]], secOf[r[[1]]]}, rs = {#[[1]], secOf[#]} & /@ Cases[{r[[2]]}, _j, Infinity]},
      {l, #} & /@ rs], {r, sysd["SymmetryRules"]}], 1]];
done = <||>; queue = {};
push[x_] := If[! KeyExistsQ[done, x], AppendTo[queue, x]];
closeSym[] := Do[If[KeyExistsQ[done, pr[[1]]], push[pr[[2]]]]; If[KeyExistsQ[done, pr[[2]]], push[pr[[1]]]], {pr, symPairs}];
drain[] := While[queue =!= {} || (closeSym[]; queue =!= {}),
   Module[{it = First[queue], im, base},
    queue = Rest[queue];
    If[! KeyExistsQ[done, it] && MemberQ[nzs[it[[1]]], it[[2]]],
     done[it] = True;
     im = imageOf @@ it;
     base = If[im === None, it, (push[im]; im)];
     Scan[push[{base[[1]], #}] &, Select[nzs[base[[1]]], subOf[#, base[[2]]] && # =!= base[[2]] &]]]]];
Scan[Function[r, Scan[push[{r[[1]], #}] &, Select[nzs[r[[1]]], subOf[#, r[[2]]] &]]], roots];
drain[];
If[TrueQ[Lookup[job, "PreImage", True]],
  Do[Module[{added = False},
     Do[With[{fv = mKey[m]}, If[MemberQ[nzs[fv[[1]]], fv[[2]]] && ! KeyExistsQ[done, fv] && KeyExistsQ[done, termImage[fv]], push[fv]; added = True]], {m, masters}];
     If[! added, Break[]]; drain[]], {5}]];
allowed = Association[Table[f -> Union[Cases[Keys[done], {f, v_} :> v]], {f, fams}]];
famsUsed = Select[fams, allowed[#] =!= {} &];
say["allowed sectors: ", Select[Table[f -> Length[allowed[f]], {f, fams}], #[[2]] > 0 &]];
okSector[jz_] := MemberQ[allowed[jz[[1]]], secOf[jz]];

(* ---- the pool (before the seeds: the seeds must reduce it and its derivatives) ---- *)
(* integrals of sector v with at most nd dots, nr numerator powers, and nd + nr capped at Max[nd, nr]: an integral
   with both many dots and many numerators would put its derivative at the corner of the seeds, unreduced *)
poolGen[f_, v_, nd_, nr_] := Module[{isp = Flatten@Position[v, 0], prp = Flatten@Position[v, 1], n = Length[v], wmax = Max[nd, nr]},
   Flatten[Table[If[Total[nv] + Total[dv] > wmax, Nothing, j[f, Sequence @@ (v - Sum[nv[[q]] UnitVector[n, isp[[q]]], {q, Length[isp]}] + Sum[dv[[q]] UnitVector[n, prp[[q]]], {q, Length[prp]}])]],
     {nv, Select[Tuples[Range[0, nr], Length[isp]], Total[#] <= nr &]}, {dv, Select[Tuples[Range[0, nd], Length[prp]], Total[#] <= nd &]}]]];
subsOne[f_, v_] := Select[Table[v - UnitVector[Length[v], q], {q, Flatten@Position[v, 1]}], MemberQ[nzs[f], #] &];
poolSpec = Lookup[job, "PoolSpec", {1, 1, 0, 0}];
(* the integrals of the roots' own masters, whatever their weight: the scans keep a slot's current master, and the
   checks expand ut[k] into its definition *)
rootMasterInts = Flatten[Table[If[MemberQ[job["Roots"], mKey[m]], Cases[{m["Def"] /. Dinv[a_, _] :> a}, _j, Infinity], {}], {m, masters}]];
pool0 = Replace[Lookup[job, "Pool", Automatic], Automatic :> Join[Flatten[Table[Join[poolGen[r[[1]], r[[2]], poolSpec[[1]], poolSpec[[2]]],
       Flatten[poolGen[r[[1]], #, poolSpec[[3]], poolSpec[[4]]] & /@ subsOne @@ r]], {r, job["Roots"]}]], rootMasterInts]];
pool0 = DeleteDuplicates[Join[pool0, Lookup[job, "PoolExtra", {}]]];
pool0 = DeleteDuplicates[Select[LIBPEliminateZeroSectors /@ pool0, MatchQ[#, _j] &]];

(* ---- masters of the system inside the subtree (before the identities when Kira reduces the slice point) ---- *)
DerF[ex_, x_] := Module[{e = Collect[ex, _j], jl}, jl = Cases[Variables[e], _j];
   Collect[Sum[D[Coefficient[e, jj], x] jj + Coefficient[e, jj] LIBPDeriv[jj, x], {jj, jl}], _j, Together]];
intOK[jj_] := ! MemberQ[nzs[jj[[1]]], secOf[jj]] || MemberQ[allowed[jj[[1]]], secOf[jj]];
expandDef[d_] := LIBPEliminateZeroSectors[Collect[d /. Dinv[a_, x_] :> DerF[a, x], _j, Together]];
dlog[p_, x_] := Together[D[p^2, x]/(2 p^2)];
prepareMasters[] := (
  Do[LIBPComputeDerivatives[f], {f, famsUsed}];
  inSub = Select[masters, MemberQ[fams, #["Family"]] && AllTrue[Cases[{#["Def"] /. Dinv[a_, _] :> a}, _j, Infinity], intOK] &];
  utdefs = Association[Table[m["Label"] -> expandDef[m["Def"]], {m, inSub}]];
  prefOf = Association[Table[m["Label"] -> m["Pref"], {m, masters}]];
  utints = KeyValueMap[ut[#1] -> #2 &, utdefs];
  utIn = Keys[utdefs];
  (* default focus: the masters of the root sectors and of their subsectors (the subsector rows calibrate the slice) *)
  masterOf = Association[Table[m["Label"] -> m, {m, masters}]];
  focus = Replace[Lookup[job, "Focus", Automatic], Automatic :>
      Select[utIn, Function[u, AnyTrue[job["Roots"], #[[1]] === masterOf[u]["Family"] && subOf[masterOf[u]["Sector"], #[[2]]] &]]]];
  focus = Select[focus, MemberQ[utIn, #] &];
  If[ListQ[Lookup[job, "FocusFamilies", All]], focus = Select[focus, MemberQ[job["FocusFamilies"], masterOf[#]["Family"]] &]];
  say["masters in the subtree: ", Length[utIn], "; focus: ", focus];
  (* the focus rows: (1/pref) d_x (pref U) *)
  dfocus = Table[LIBPEliminateZeroSectors[DerF[utdefs[u], x] + dlog[prefOf[u], x] utdefs[u]], {x, ders}, {u, focus}];
  mastersReady = True);
symr = Select[sysd["SymmetryRules"], okSector[#[[1]]] && AllTrue[Cases[{#[[2]]}, _j, Infinity], intOK] &];

(* ---- the reducer of the slice point ---- *)
pts = job["Points"];
kiraCfg = Lookup[job, "Kira", None];
reducerWant = Lookup[job, "Reducer", Automatic];
choice = Which[
  reducerWant === "FiniteFlow" || ! AssociationQ[kiraCfg],
    <|"Reducer" -> "FiniteFlow", "Reason" -> If[reducerWant === "FiniteFlow", "\"Reducer\" -> \"FiniteFlow\"",
       StringReplace[Lookup[job, "ReducerNote", "the job carries no Kira configuration"], "slice point: FiniteFlow (" ~~ r___ ~~ ")" ~~ EndOfString :> r]], "Refused" -> False|>,
  True, PFBReducerChoice[reducerWant, <|"KiraAvailable" -> AllTrue[{Lookup[tp, "kira", None], Lookup[tp, "fer64", None]}, StringQ[#] && FileExistsQ[#] &],
     "Families" -> famsUsed, "KiraFamily" -> kiraCfg["Family"], "SymmetryRules" -> Length[symr],
     "LearnOnly" -> TrueQ[Lookup[job, "LearnOnly", False]], "Analytic" -> AssociationQ[Lookup[job, "Analytic", None]],
     "Degrees" -> (AssociationQ[Lookup[job, "Degrees", None]] || AssociationQ[Lookup[job, "Line", None]])|>]];
say["slice point: ", choice["Reducer"], " (", choice["Reason"], ")"];
If[TrueQ[choice["Refused"]], setStatus["failed", <|"Message" -> "\"Reducer\" -> \"Kira\", but Kira cannot reduce this job at its slice point: " <> choice["Reason"]|>]; finish[3]];
reducers = <||>; kiraNow = False; kiraFallback = None;
pointTimes = If[FileExistsQ["times.m"], Replace[Quiet@Get["times.m"], Except[_List] -> {}], {}]; kept = {};
reducerList[] := Table[Lookup[reducers, ip, Missing[]], {ip, Length[pts]}];

(* core/bin/limit, for Kira's own time and memory limit inside the job's *)
limitPath = SelectFirst[{Lookup[tp, "limit", None], FileNameJoin[{ParentDirectory[ParentDirectory[ParentDirectory[skillLib]]], "core", "bin", "limit"}]},
   StringQ[#] && FileExistsQ[#] &, None];
(* time: half of what is left of the job's own limit (its registry, line 2: limits <seconds> <KB> <start>), else of the
   job's "TimeLimit", so that FiniteFlow can still reduce the point when Kira stops at its limit (PFBKiraTimeLimit);
   memory: 90% of what the job's limit leaves (limit --headroom, in KB), as maximal-cut-basis gives Kira *)
kiraLimits[] := Module[{f = Environment["MCB_LIMIT_JOB"], l = {}, tl = Lookup[job, "TimeLimit", 86400], left = None, hr, mem = Automatic},
  If[StringQ[f] && FileExistsQ[f], l = Quiet@Check[ReadList[f, String], {}]; l = If[Length[l] >= 2, StringSplit[l[[2]]], {}]];
  If[Length[l] >= 4 && l[[1]] === "limits" && AllTrue[l[[{2, 4}]], StringMatchQ[#, DigitCharacter ..] &] && l[[2]] =!= "0",
    left = ToExpression[l[[2]]] - (UnixTime[] - ToExpression[l[[4]]]) - 30];
  tl = Which[NumericQ[left], PFBKiraTimeLimit[Max[0, left]], NumericQ[tl] && tl > 0, PFBKiraTimeLimit[tl], True, 0];
  If[StringQ[limitPath],
    hr = Quiet@RunProcess[{limitPath, "--headroom"}, "StandardOutput"]; hr = If[StringQ[hr], StringTrim[hr], ""];
    mem = Which[hr === "none", 0, StringMatchQ[hr, DigitCharacter ..], Max[0.25, 0.9 ToExpression[hr]/1024.^2], True, Automatic]];
  {tl, mem}];
quoteSh[x_String] := "'" <> StringReplace[x, "'" -> "'\\''"] <> "'";
readText[f_String] := If[FileExistsQ[f], Replace[Quiet@Import[f, "Text"], Except[_String] -> ""], None];

(* Kira at the slice point: the reduction of red_1.m, or a String saying why there is none *)
kiraSlicePoint[] := Module[{cfg = kiraCfg, fam = First[famsUsed], P = pts[[1]], Pk, poolK, dpoolK, needK, entries, kdir = FileNameJoin[{Directory[], "kira"}],
    kfam = kiraCfg["KiraFamily"], vals, tl, mem, cmd, code, rd, vecs, nK, U, V, W, nF, nP, pr, Dm, Rp, dRp, old, w0 = AbsoluteTime[], c0 = cpuSeconds[], wall, cpu, nthr, red},
  poolK = Select[pool0, intOK];
  (* resume: a reduction of the slice point with the same pool, focus and masters of the subtree is kept *)
  old = If[FileExistsQ["red_1.m"], Quiet@Get["red_1.m"], None];
  If[AssociationQ[old] && Sort[old["Point"]] === Sort[P] && old["Pool"] === poolK && old["Focus"] === focus && Lookup[old, "Labels", None] === utIn && FreeQ[old, $Failed],
    say["point 1 kept from an earlier run"]; kiraKept = True; Return[old]];
  setStatus["running", <|"Phase" -> "kira", "Point" -> 1, "Of" -> Length[pts]|>];
  dpoolK = If[TrueQ[Lookup[job, "PoolDerivatives", True]], Table[LIBPEliminateZeroSectors[DerF[pp, x]], {x, ders}, {pp, poolK}], {}];
  needK = Union[LIBPIntegralsIn[dfocus], poolK, LIBPIntegralsIn[dpoolK], LIBPIntegralsIn[utints]];
  If[! AllTrue[needK, #[[1]] === fam &], Return["integrals of another family are needed: " <> ToString[Take[Select[needK, #[[1]] =!= fam &], UpTo[3]], InputForm]]];
  (* an image family is reduced as its base family at the image's mapped point *)
  Pk = PFBKiraMappedPoint[P, cfg["InvariantMap"]];
  entries = PFBKiraSeeds[List @@ Rest[#] & /@ needK, Cases[roots, {fam, v_} :> v], job["Seeds"]["Rank"], job["Seeds"]["Dots"]];
  If[DirectoryQ[kdir], DeleteDirectory[kdir, DeleteContents -> True]];
  CreateDirectory[FileNameJoin[{kdir, "config"}], CreateIntermediateDirectories -> True];
  Export[FileNameJoin[{kdir, "config", "integralfamilies.yaml"}],
    StringReplace[cfg["IntegralFamilies"], "@TOPLEVEL@" -> StringRiffle[ToString[PFBKiraSectorID[#[[1]]]] & /@ entries, ", "]], "Text"];
  Export[FileNameJoin[{kdir, "config", "kinematics.yaml"}], cfg["Kinematics"], "Text"];
  Export[FileNameJoin[{kdir, "target"}], PFBKiraTargetText[kfam, List @@ Rest[#] & /@ needK], "Text"];
  Export[FileNameJoin[{kdir, "job.yaml"}], PFBKiraJobYAML[kfam, entries], "Text"];
  vals = PFBKiraValues[Pk, cfg["Names"]];
  If[StringQ[vals], Return[vals]];
  {tl, mem} = kiraLimits[];
  nthr = Max[1, Min[4, Lookup[job, "Threads", 1]]];
  cmd = PFBKiraCommand[<|"Kira" -> tp["kira"], "Fermat" -> tp["fer64"], "Limit" -> limitPath, "Threads" -> nthr, "TimeLimit" -> tl, "MemoryGB" -> mem,
     "Values" -> vals|>];
  say["Kira at the slice point", If[cfg["InvariantMap"] === {}, "", " (as " <> kfam <> " at the mapped point " <> ToString[Pk, InputForm] <> ")"], ": ",
    Length[needK], " integrals, sectors ", {PFBKiraSectorID[#[[1]]], #[[2]], #[[3]]} & /@ entries, " (id, r, s), ", nthr, " thread(s), limits ", tl, " s, ",
    Replace[mem, {0 -> "no memory limit", Automatic -> "the default memory limit", x_?NumericQ :> ToString[NumberForm[x, {4, 1}]] <> " GB"}]];
  code = Quiet@RunProcess[{"/bin/sh", "-c", "cd " <> quoteSh[kdir] <> " && " <> cmd <> " < /dev/null"}, "ExitCode"];
  rd = PFBKiraResult[<|"ExitCode" -> code, "Log" -> readText[FileNameJoin[{kdir, "kira.out"}]],
     "Results" -> readText[FileNameJoin[{kdir, "results", kfam, "kira_target.m"}]], "MastersText" -> readText[FileNameJoin[{kdir, "results", kfam, "masters"}]],
     "Family" -> kfam, "Integral" -> (j[fam, Sequence @@ #] &), "Dimension" -> cfg["D0"] - 2 eps, "TimeLimit" -> tl, "MemoryGB" -> mem|>];
  If[StringQ[rd], Return[rd]];
  vecs = PFBKiraVectors[needK, rd["Rules"], rd["Masters"]];
  If[StringQ[vecs], Return[vecs]];
  nK = Length[rd["Masters"]];
  (* the system's masters on Kira's, and every row (focus rows, pool, its derivatives) on Kira's, then on the system's *)
  U = PFBKiraExprVector[#, P, vecs, nK] & /@ Values[utdefs];
  If[MemberQ[U, $Failed], Return["a definition of a master holds integrals Kira did not reduce"]];
  V = PFBKiraExprVector[#, P, vecs, nK] & /@ Join[Flatten[dfocus, 1], poolK, Flatten[dpoolK, 1]];
  If[MemberQ[V, $Failed], Return["a row holds integrals Kira did not reduce"]];
  pr = PFBKiraProject[U, V, nK];
  If[StringQ[pr], Return[pr]];
  W = pr["Rows"]; nF = Length[focus]; nP = Length[poolK];
  Dm = Table[W[[(k - 1) nF + q]], {k, Length[ders]}, {q, nF}];
  Rp = Table[W[[Length[ders] nF + q]], {q, nP}];
  dRp = If[dpoolK === {}, {}, Table[W[[Length[ders] nF + nP + (k - 1) nP + q]], {k, Length[ders]}, {q, nP}]];
  red = <|"Masters" -> (ut /@ utIn[[pr["Selected"]]]), "Labels" -> utIn, "Point" -> P, "Focus" -> focus, "Dm" -> Dm, "Pool" -> poolK, "Rp" -> Rp, "dRp" -> dRp,
    "Invariants" -> ders, "Roots" -> roots, "Allowed" -> allowed, "Reducer" -> "Kira"|>;
  (* Kira's folder is scratch once read (kept when Kira gave no reduction); its log stays as kira.log *)
  If[FileExistsQ[FileNameJoin[{kdir, "kira.out"}]], CopyFile[FileNameJoin[{kdir, "kira.out"}], "kira.log", OverwriteTarget -> True]];
  DeleteDirectory[kdir, DeleteContents -> True];
  wall = Round[AbsoluteTime[] - w0]; cpu = If[NumericQ[c0], Round[cpuSeconds[] - c0], Missing[]];
  AppendTo[pointTimes, <|"Point" -> 1, "Date" -> DateString[], "WallSeconds" -> wall, "CPUSeconds" -> cpu, "Threads" -> nthr, "Reducer" -> "Kira",
     "Starved" -> (NumericQ[cpu] && wall > 120 && cpu < 0.25 wall)|>];
  Put[pointTimes, "times.m"];
  say["point 1 done by Kira in ", wall, " s wall-clock (", cpu, " s CPU): ", nK, " masters, ", Length[rd["Rules"]], " reduced integrals"];
  red];

(* a Kira run of this job that gave no reduction is not repeated (kira_fallback.m; PFBSubtreeJob deletes it with the
   job's results when it rewrites the job): FiniteFlow reduces the point, in this run and the next ones *)
kiraPrev = If[FileExistsQ["kira_fallback.m"], Quiet@Get["kira_fallback.m"], None];
If[choice["Reducer"] === "Kira" && reducerWant =!= "Kira" && AssociationQ[kiraPrev],
  kiraFallback = "in an earlier run of this job (kira_fallback.m): " <> ToString[Lookup[kiraPrev, "Reason", "?"]];
  say["Kira gave no reduction of the slice point ", kiraFallback, ": FiniteFlow reduces it"];
  choice["Reducer"] = "FiniteFlow"];
If[choice["Reducer"] === "Kira", Module[{r},
   prepareMasters[];
   kiraKept = False;
   r = kiraSlicePoint[];
   If[AssociationQ[r],
     If[kiraKept, AppendTo[kept, 1], Put[r, "red_1.m"]; kiraNow = True; credit["Kira"]];
     reducers[1] = Lookup[r, "Reducer", "FiniteFlow"],
     If[reducerWant === "Kira", setStatus["failed", <|"Message" -> "Kira at the slice point gave no reduction: " <> r|>]; finish[3]];
     kiraFallback = r; Put[<|"Reason" -> r, "Date" -> DateString[]|>, "kira_fallback.m"];
     say["Kira at the slice point gave no reduction (", r, "): FiniteFlow reduces it"]]]];
(* a job with only the slice point, which Kira reduced: no identities, no learning (a degree or line job is never Kira's) *)
If[KeyExistsQ[reducers, 1] && Length[pts] == 1 && ! AssociationQ[Lookup[job, "Degrees", None]] && ! AssociationQ[Lookup[job, "Line", None]],
  credit[reducers[1]];
  setStatus["done", <|"Masters" -> Get["red_1.m"]["Masters"], "Points" -> 1, "PoolDropped" -> Complement[pool0, Select[pool0, intOK]], "Kept" -> kept,
    "PointTimes" -> pointTimes, "FailedPoints" -> {}, "Reducers" -> reducerList[]|>];
  finish[0]];

(* ---- seeds and identities ---- *)
rank = job["Seeds"]["Rank"]; maxdots = job["Seeds"]["Dots"];
(* what each sector must reduce: the pool and the integrals of the masters of the roots, each with one more dot and
   one more numerator power for its derivative (two for a Dinv) *)
intDots[jj_] := Total[Select[List @@ Rest[jj], # > 0 &] - 1];
intRank[jj_] := -Total[Select[List @@ Rest[jj], # < 0 &]];
(* a degree job's variants with new masters in integrals (a swap) and its sampled expressions (a fit) need those
   integrals and their derivatives *)
degNeedInts = With[{dg = Replace[Lookup[job, "Degrees", None], Except[_Association] -> <||>]},
   Select[Union[Cases[{Values /@ Select[Lookup[Replace[Lookup[dg, "Variants", {}], Except[_List] -> {}], "T", <||>], AssociationQ], Lookup[dg, "SampleExprs", {}]} /. Dinv[a_, _] :> a,
     _j, Infinity]], MemberQ[fams, #[[1]]] &]];
needRD = Module[{dd = If[TrueQ[Lookup[job, "PoolDerivatives", True]], 1, 0], items},
   items = Join[{#, dd} & /@ pool0, {#, 1} & /@ degNeedInts,
     Flatten[Table[If[AnyTrue[roots, #[[1]] === m["Family"] && subOf[m["Sector"], #[[2]]] &],
         Join[{#, 1} & /@ Cases[{m["Def"] /. Dinv[_, _] -> 0}, _j, Infinity], {#, 2} & /@ Cases[Cases[{m["Def"]}, Dinv[a_, _] :> a, Infinity], _j, Infinity]], {}],
       {m, masters}], 1]];
   (* one dot more than needed: integrals at the dots boundary of the seeds stay unreduced *)
   Merge[Table[{it[[1, 1]], secOf[it[[1]]]} -> {intRank[it[[1]]] + it[[2]], intDots[it[[1]]] + it[[2]] + 1}, {it, items}], {Max[#[[All, 1]]], Max[#[[All, 2]]]} &]];
(* the integrals of a mapped sector are reduced in its image: the image needs the same seeds *)
needRD = Merge[{needRD, Association[KeyValueMap[With[{im = termImage[#1]}, If[im =!= #1 && MemberQ[nzs[im[[1]]], im[[2]]], im -> #2, Nothing]] &, needRD]]},
   {Max[#[[All, 1]]], Max[#[[All, 2]]]} &];
bump = Lookup[job, "SeedBump", <||>];
nProps[f_] := sysd["N"][f] - Length[Lookup[sysd["ISPs"], f, {}]];
isRoot[jz_] := MemberQ[roots, {jz[[1]], secOf[jz]}];
(* roots and sectors one propagator below the top: (rank, dots); low sectors one more of each, very low sectors two more
   dots, so that the images of mapped integrals (one more dot and rank) are reduced *)
seedRD[jz_] := Module[{n = Total[secOf[jz]], top = nProps[jz[[1]]], k = {jz[[1]], secOf[jz]}}, Lookup[bump, Key[k],
    MapThread[Max, {Which[isRoot[jz] || n >= top - 1, {rank, maxdots}, n <= top - 4, {rank + 1, maxdots + 2}, True, {rank + 1, maxdots + 1}],
      Lookup[needRD, Key[k], {0, 0}]}]]];
GetSeeds[type_][sector_] := If[! okSector[sector], {},
   With[{rd = seedRD[sector]}, Switch[type,
     "SR", LIBPGenerateSeeds[sector, {0, 0}, 0, rd[[1]]],
     "Map" | "ExtMap", With[{nd = Lookup[needRD, Key[{sector[[1]], secOf[sector]}], {0, 0}]}, LIBPGenerateSeeds[sector, {0, Max[maxdots + 1, nd[[2]]]}, 0, Max[rank + 1, nd[[1]]]]],
     _, LIBPGenerateSeeds[sector, {0, rd[[2]]}, 0, rd[[1]]]]]];
reuseDir = Replace[Lookup[job, "ReuseIds", None], s_String /; ! DirectoryQ[s] -> None];
If[! FileExistsQ["ibps/ids.done"],
  If[DirectoryQ["ibps"], DeleteDirectory["ibps", DeleteContents -> True]];
  CreateDirectory["ibps"];
  If[reuseDir === None, GetSeedsUse[type_][sector_] := GetSeeds[type][sector]];
  If[reuseDir =!= None,
   CreateDirectory["ibps/prior"];
   (* identity, integral and seed files of the earlier run (and of the runs it reused), linked, not copied *)
   Do[Run["for f in '" <> sub <> "'/ids_*.mx '" <> sub <> "'/ints_*.mx '" <> sub <> "'/seeds_*.mx; do [ -e \"$f\" ] && ln -sf \"$(readlink -f \"$f\")\" ibps/prior/; done"],
     {sub, {reuseDir, reuseDir <> "/new", reuseDir <> "/prior"}}];
   DeleteFile /@ Select[FileNames["ibps/prior/*.mx"], StringContainsQ[FileNameTake[#], "utints" | "symrules"] &];
   (* drop only the chunks with no integral in an allowed sector: a chunk mixes the seeds of several sectors, and
      dropping one whose seeds count as covered would leave identities missing; extra identities only cost memory *)
   Do[Module[{ints = Quiet[Import[StringReplace[fl, "/ids_" -> "/ints_"]]], fam},
      If[! ListQ[ints] || ints === {}, Continue[]];
      fam = ToExpression[StringCases[FileNameTake[fl], "ids_" ~~ f : Except["_"] .. ~~ "_" :> f][[1]]];
      If[! KeyExistsQ[allowed, fam] || ! AnyTrue[Select[ints, #[[1]] === fam &], MemberQ[allowed[fam], secOf[#]] &],
        DeleteFile[fl]; DeleteFile[StringReplace[fl, "/ids_" -> "/ints_"]]]],
    {fl, FileNames["ibps/prior/ids_*.mx"]}];
   covered = Association[Thread[StringReplace[FileNameTake /@ FileNames["ibps/prior/seeds_*.mx"],
        {"seeds_" -> "", RegularExpression["_[0-9]+\\.mx$"] -> ""}] -> True]];
   say["reusing ", Length[FileNames["ibps/prior/ids_*.mx"]], " identity files of ", reuseDir];
   (* covered only when the earlier seeds were at least as large (seedsizes.m of that run; without it, the default sizes) *)
   priorSizes = If[FileExistsQ[reuseDir <> "/seedsizes.m"], Get[reuseDir <> "/seedsizes.m"], <||>];
   bigEnough[sector_] := With[{k = {sector[[1]], secOf[sector]}, rd = seedRD[sector]},
     If[KeyExistsQ[priorSizes, k], And @@ Thread[priorSizes[k] >= rd], And @@ Thread[Lookup[needRD, Key[k], {0, 0}] <= {rank, maxdots}]]];
   GetSeedsUse[type_][sector_] := If[KeyExistsQ[covered, type <> "_" <> ToString[sector[[1]]] <> StringJoin[ToString /@ (List @@ Rest[sector])]] && bigEnough[sector],
     {}, GetSeeds[type][sector]]];
  Quiet[If[Length[Kernels[]] == 0, LaunchKernels[Lookup[job, "Kernels", 2]]]];
  CreateDirectory["ibps/new"];
  Do[LIBPFastGenIds[f, GetSeedsUse, "Directory" -> FileNameJoin[{Directory[], "ibps", "new"}], "LaunchKernels" -> 0], {f, famsUsed}];
  (* the seed sizes of every allowed sector, for later jobs that reuse these identities *)
  Put[Merge[{If[reuseDir =!= None && FileExistsQ[reuseDir <> "/seedsizes.m"], Get[reuseDir <> "/seedsizes.m"], <||>],
      Association[Flatten[Table[{f, v} -> seedRD[js @@ Join[{f}, v]], {f, famsUsed}, {v, allowed[f]}], 1]]}, MapThread[Max, #] &], "ibps/seedsizes.m"];
  Export["ibps/ids.done", "ok", "Text"];
  credit["Identities"]];
idDirs = Select[{"ibps", "ibps/prior", "ibps/new"}, DirectoryQ];
globIds[pat_] := Flatten[FileNames[# <> "/" <> pat] & /@ idDirs];
say["identities ready in ", Round[AbsoluteTime[] - t0], " s"];

(* ---- masters of the system inside the subtree ---- *)
If[! TrueQ[mastersReady], prepareMasters[]];
Export["ibps/utints_def.m", utints];
Export["ibps/ids_utints.mx", (-#[[1]] + #[[2]]) & /@ utints, "MX"];
Export["ibps/ints_utints.mx", LIBPIntegralsIn[utints], "MX"];
If[symr =!= {}, Export["ibps/ids_family_symrules.mx", (-#[[1]] + #[[2]]) & /@ symr, "MX"]; Export["ibps/ints_family_symrules.mx", LIBPIntegralsIn[symr], "MX"]];
If[! FileExistsQ["ibps/posints_utints.mx"],
  LIBPSerializeFastIds[globIds["ids_*.mx"], invs[[1]] -> invs[[1]], vars, "ExtraInts" -> (First /@ utints)]];
CloseKernels[];
integrals = Join[LIBPGetAllInts[globIds["ints_*.mx"]], First /@ utints];
If[! And @@ ((integrals[[#[[2]] + 1]] === #[[1]]) & /@ Import["ibps/posints_utints.mx"]),
  setStatus["failed", <|"Message" -> "the integral index map does not match the serialized identities (load order or ID files changed)"|>]; finish[3]];

(* ---- the rows of the degree census (job.m "Degrees"), the rows of its variants, and the expressions of a line (job.m
   "Line"): their integrals must be solved for, so they join the needed integrals before learning ---- *)
degSpec = Replace[Lookup[job, "Degrees", None], Except[_Association] -> None];
lineSpec = Replace[Lookup[job, "Line", None], Except[_Association] -> None];
degExtra = {}; degRows = {}; degBase = {}; degVariants = {}; lineExprs = {}; degSampleExprs = {}; degSampleD = {};
focusRow[k_, r_] := dfocus[[k, First[FirstPosition[focus, r]]]];
(* a variant is the DE after U' = T U on some masters (T: label -> combination of ut[m], coefficients rational in eps and
   the invariants), with U = TInverse . U' (label -> combination of ut[m]; the identity where it says nothing): the row
   of a changed master is (1/pref) d(pref T U), reduced like any row, and its columns are taken through TInverse. With
   "TInverse" -> Automatic (new masters in integrals, a swap) the new masters are reduced too ("HExprs": their vectors on
   the masters) and T is inverted inside the graph (PFBFFReplaceGraph) *)
variantOf[v_Association] := Module[{name = ToString[Lookup[v, "Name", "variant"]], rows, T = Lookup[v, "T", <||>], TI = Lookup[v, "TInverse", <||>], used, tiA},
  rows = Replace[Lookup[v, "Rows", Automatic], Automatic -> degRows];
  tiA = If[AssociationQ[TI], TI, <||>];
  used = Union[Keys[T], Keys[tiA], Cases[{Values[T], Values[tiA]}, ut[k_] :> k, Infinity]];
  If[! SubsetQ[utIn, used], Return["variant " <> name <> ": masters outside the subtree " <> ToString[ut /@ Complement[used, utIn]]]];
  If[! SubsetQ[focus, Complement[rows, Keys[T]]], Return["variant " <> name <> ": rows that it does not change and that are not in the focus " <> ToString[Complement[rows, Keys[T], focus]]]];
  If[! (AssociationQ[TI] || TI === Automatic), Return["variant " <> name <> ": TInverse must be an Association or Automatic"]];
  <|"Name" -> name, "Rows" -> rows, "T" -> T, "TInverse" -> TI, "Probe" -> Lookup[v, "Probe", Lookup[degSpec, "Probe", True]],
    "Exprs" -> Flatten[Table[If[KeyExistsQ[T, r],
        With[{nd = expandDef[T[r] /. ut[m_Integer] :> utdefs[m]]}, LIBPEliminateZeroSectors[DerF[nd, ders[[k]]] + dlog[prefOf[r], ders[[k]]] nd]],
        focusRow[k, r]], {k, Length[ders]}, {r, rows}]],
    "HExprs" -> If[TI === Automatic, Table[expandDef[T[l]], {l, Keys[T]}], {}]|>];
If[degSpec =!= None,
  degRows = Replace[Lookup[degSpec, "Rows", Automatic], Automatic -> focus];
  If[! SubsetQ[focus, degRows], setStatus["failed", <|"Message" -> "degrees: rows that are not in the focus of the job: " <> ToString[ut /@ Complement[degRows, focus]]|>]; finish[3]];
  degBase = Flatten[Table[focusRow[k, r], {k, Length[ders]}, {r, degRows}]];
  degVariants = variantOf /@ Lookup[degSpec, "Variants", {}];
  If[MemberQ[degVariants, _String], setStatus["failed", <|"Message" -> "degrees: " <> First[Cases[degVariants, _String]]|>]; finish[3]];
  (* expressions sampled with their derivatives (the pool of a fit: vectors on the masters at the sample points) *)
  degSampleExprs = expandDef /@ Lookup[degSpec, "SampleExprs", {}];
  degSampleD = Flatten[Table[LIBPEliminateZeroSectors[DerF[e, x]], {x, ders}, {e, degSampleExprs}]];
  degExtra = LIBPIntegralsIn[Flatten[Join[Lookup[degVariants, "Exprs", {}], Lookup[degVariants, "HExprs", {}], degSampleExprs, degSampleD]]]];
If[lineSpec =!= None,
  lineExprs = expandDef /@ lineSpec["Exprs"];
  degExtra = Join[degExtra, Union[Cases[lineExprs, _j, Infinity]]]];
(* ---- the pool (the focus rows, dfocus, come from prepareMasters) ---- *)
pool = pool0;
dropped = Select[pool, ! MemberQ[integrals, #] &];
pool = Select[pool, MemberQ[integrals, #] &];
dpool = If[TrueQ[Lookup[job, "PoolDerivatives", True]], Table[LIBPEliminateZeroSectors[DerF[pp, x]], {x, ders}, {pp, pool}], {}];
need = Union[LIBPIntegralsIn[dfocus], pool, LIBPIntegralsIn[dpool], LIBPIntegralsIn[utints], degExtra];
missing = Complement[need, integrals];
say["pool ", Length[pool], " (", Length[dropped], " outside the identities); needed integrals ", Length[need]];
(* every pool integral and its derivatives are reconstructed at every point: a large pool makes every point slow *)
If[Length[pool] > Lookup[job, "PoolWarn", 150], say["the pool has ", Length[pool], " integrals (", Length[pool] (1 + Length[ders]),
   " rows to reconstruct at every point with their derivatives): the time of each point grows with it. Keep the pool to the structural reading's candidates (PoolSpec {1, 1, 0, 0} and PoolExtra) unless a rung needs more"]];
If[missing =!= {}, setStatus["failed", <|"Message" -> "integrals needed by the focus rows or the pool derivatives are not covered by the seeds; raise the seeds",
    "Missing" -> Take[missing, UpTo[50]], "PoolDropped" -> dropped|>]; finish[3]];

(* ---- memory gate ---- *)
(* what learning adds to what this kernel holds now (families, identities), against the memory free right now; an
   explicit "MaxGB" caps the whole kernel, and so does the job's own limit under bin/ws (hardGB) *)
neq = Total[Table[Quiet@Check[ToExpression[First[StringCases[ReadString[f, ","] /. EndOfFile -> "", DigitCharacter ..]]], 0], {f, globIds["sids_*.json"]}]];
model = job["MemoryModel"];
resetHWM[]; base0 = rss[]; avail0 = memAvail[];
learnGB = model["LearnPerEq"] neq;
maxGB = Lookup[job, "MaxGB", None];
hard = hardGB[];
say["equations ", neq, "; kernel ", NumberForm[base0, {4, 1}], " GB, learning adds ~", NumberForm[learnGB, {4, 1}], " GB, free ", NumberForm[avail0, {4, 1}],
  " GB (model ", model["Source"], ")"];
If[! TrueQ[Lookup[job, "Force", False]] && (learnGB > 0.85 avail0 - 0.5 || (NumericQ[maxGB] && base0 + learnGB > maxGB) || base0 + learnGB > 0.95 hard),
  setStatus["refused", <|"Equations" -> neq, "KernelGB" -> base0, "PredictedGB" -> learnGB, "FreeGB" -> avail0, "MaxGB" -> maxGB, "LimitGB" -> hard, "Reducers" -> reducerList[],
    "Message" -> If[base0 + learnGB > 0.95 hard && ! (learnGB > 0.85 avail0 - 0.5),
      "predicted memory above the job's memory limit of " <> ToString[NumberForm[hard, {4, 1}]] <> " GB (bin/ws --memory, MaxGB in job.m): raise it if the machine has the memory, lower the seeds (rank, dots), or split the roots or the pool",
      "predicted memory above what is free: lower the seeds (rank, dots), split the roots or the pool, or run on a larger machine"]|>];
  finish[1]];

(* ---- learn ---- *)
setStatus["running", <|"Phase" -> "learning", "Equations" -> neq|>];
With[{o = heavyOthers[]}, If[o =!= {}, say["other processes above 1 GB: ", StringRiffle[o, ", "]]]];
LIBPWriteSystemJSON[globIds["sids_*.json"], integrals, need, vars, "FileName" -> "system.json"];
FFNewGraph[g, in, vars];
FFAlgJSONSparseSolver[g, ibps, {in}, "system.json"];
FFSolverOnlyHomogeneous[g, ibps];
FFGraphOutput[g, ibps];
learn = FFSparseSolverLearn[g, integrals];
{nonm, mast} = {"DepVars", "IndepVars"} /. learn;
recordMem[<|"Phase" -> "learn", "Equations" -> neq, "BaselineGB" -> base0, "PeakGB" -> hwm[], "IncrementGB" -> hwm[] - base0|>];
say["masters (", Length[mast], "): ", mast];
nonut = Select[mast, ! MatchQ[#, _ut] &];
(* learn only (bin/relation_sector.wls): which masters this subtree leaves, without any reconstruction *)
If[TrueQ[Lookup[job, "LearnOnly", False]],
  credit["FiniteFlow"];
  setStatus["learned", <|"Masters" -> mast, "NonUT" -> nonut, "Equations" -> neq, "Allowed" -> allowed|>];
  say["learned: ", Length[mast], " masters, ", Length[nonut], " not masters of the system ", nonut];
  finish[0]];
If[nonut =!= {} && TrueQ[Lookup[job, "AllowNonUT", False]], say["kept as extra columns (not masters of the system): ", nonut]];
If[nonut =!= {} && ! TrueQ[Lookup[job, "AllowNonUT", False]],
  Module[{xs = Union[{#[[1]], secOf[#]} & /@ nonut], hosts, round = Lookup[job, "HostRound", 0]},
   hosts = DeleteDuplicates[Select[mKey /@ Select[masters, ! MemberQ[utIn, #["Label"]] &],
       Function[fv, MemberQ[nzs[fv[[1]]], fv[[2]]] && MemberQ[termImage /@ xs, termImage[fv]]]]];
   hosts = Complement[hosts, roots];
   If[hosts =!= {} && round < Lookup[job, "MaxHostRounds", 3] && Lookup[job, "Hosts", Automatic] =!= None,
    Module[{j2 = job, keep = "ibps_round" <> ToString[round]},
     If[DirectoryQ[keep], DeleteDirectory[keep, DeleteContents -> True]];
     RenameDirectory["ibps", keep];
     j2["HostRoots"] = Join[Lookup[job, "HostRoots", {}], hosts]; j2["HostRound"] = round + 1;
     j2["ReuseIds"] = FileNameJoin[{Directory[], keep}];
     Put[j2, "job.m"];
     setStatus["nonut-hosts", <|"NonUT" -> nonut, "Sectors" -> xs, "HostRoots" -> hosts,
       "Message" -> "masters that are not masters of the system were found; the sectors of system masters mapping onto them were added as roots: run the job again"|>];
     finish[4]]];
   Put[xs, "nonut.m"];
   setStatus["nonut", <|"NonUT" -> nonut, "Sectors" -> xs, "Message" ->
      "masters that are not masters of the system and no host sector to add: keep them as extra columns (\"AllowNonUT\" -> True, then bin/extra_masters.wls removes them exactly), find the sector that supplies the missing relation (bin/relation_sector.wls), raise the seeds of these sectors (SeedBump), check the symmetry rules, or check that the masters list covers these sectors"|>];
   finish[1]]];
FFSparseSolverMarkAndSweepEqs[g, ibps];
FFSparseSolverDeleteUnneededEqs[g, ibps];

(* ---- reconstruction at each point ---- *)
(* a line job's points serve its line: FiniteFlow is credited there, unless the line's check refuted it *)
pointCredit[r_] := If[lineSpec === None || r =!= "FiniteFlow", credit[r]];
used = Union[LIBPIntegralsIn[dfocus], pool, LIBPIntegralsIn[dpool]];
keepIdx = If[TrueQ[Lookup[job, "TakeUsed", True]], Sort[Flatten[Position[nonm, #, {1}, 1] & /@ used]], Range[Length[nonm]]];
resetHWM[]; base1 = rss[]; avail1 = memAvail[];
threads = Module[{tmax = Lookup[job, "Threads", 4], t},
   t = tmax; While[t > 1 && (model["ReconPerUnit"] Length[keepIdx] Length[mast] t > 0.85 avail1 - 0.5 || base1 + model["ReconPerUnit"] Length[keepIdx] Length[mast] t > 0.95 hard), t--]; t];
say["reconstructing ", Length[keepIdx], " of ", Length[nonm], " rows with ", threads, " threads"];
(* ---- analytic coefficients: the reduction of a few expressions on a few masters, as functions of eps and the
   invariants, from many evaluations of the learned system (each one a numerical solve, no new identities) ---- *)
anaInfo = None;
If[AssociationQ[Lookup[job, "Analytic", None]],
  Module[{an = job["Analytic"], exprs, fix, avars, ints, nonmI, mastI, mwant, C, Dw, ga, ina, sub, red, tk, cf, mm, dn, tot, out, rec, nms, ta = AbsoluteTime[], cols, E0},
    setStatus["running", <|"Phase" -> "analytic"|>];
    exprs = Collect[#, _j] & /@ an["Exprs"]; fix = Lookup[an, "Fix", {}];
    avars = Join[{eps}, Complement[invs, fix[[All, 1]]]];
    ints = Union[Cases[exprs, _j, Infinity]];
    nonmI = Select[ints, MemberQ[nonm, #] &]; mastI = Select[ints, MemberQ[mast, #] &];
    mwant = Replace[Lookup[an, "Masters", Automatic], Automatic -> mast];
    If[Complement[ints, nonmI, mastI] =!= {} || ! SubsetQ[mast, mwant],
      setStatus["failed", <|"Message" -> "analytic: integrals outside the reduction " <> ToString[Complement[ints, nonmI, mastI], InputForm] <>
         " or masters that are not masters of this reduction " <> ToString[Complement[mwant, mast], InputForm]|>]; finish[3]];
    (* each expression must be a linear combination of integrals: one inside another head (a derivative master's
       Dinv[j[...], s]) has coefficient 0 here and in the check below, and its term would be lost silently *)
    With[{nonlin = Select[exprs, Together[# - Sum[Coefficient[#, jj] jj, {jj, Union[Cases[{#}, _j, Infinity]]}]] =!= 0 &]},
      If[nonlin =!= {}, setStatus["failed", <|"Message" -> "analytic: expressions that are not linear combinations of integrals (derivatives such as Dinv?): " <>
         ToString[nonlin, InputForm] <> ". Give their integrals instead"|>]; finish[3]]];
    cols = Flatten[Position[mast, #] & /@ mwant]; E0 = Length[exprs];
    C = Table[Together[Coefficient[e, jj] /. fix], {e, exprs}, {jj, nonmI}];
    (* integrals of the expressions that are masters themselves: their coefficient goes straight to that master's column *)
    Dw = Table[Module[{v = ConstantArray[0, Length[cols]]},
        Do[With[{c = Position[mwant, mastI[[q]]]}, If[c =!= {}, v[[c[[1, 1]]]] += Together[Coefficient[e, mastI[[q]]] /. fix]]], {q, Length[mastI]}]; v], {e, exprs}];
    FFNewGraph[ga, ina, avars];
    (* the learned solver takes {eps, invariants}: the fixed ones get their values *)
    FFAlgRatFunEval[ga, sub, {ina}, avars, Join[{eps}, invs /. fix]];
    FFAlgSimpleSubgraph[ga, red, {sub}, g];
    nms = Table[cfx[i, jm], {i, Length[nonm]}, {jm, Length[mast]}];
    out = None;
    If[nonmI =!= {},
      FFAlgTake[ga, tk, {red}, {Flatten[nms]} -> Flatten[nms[[Flatten[Position[nonm, #] & /@ nonmI], cols]]]];
      FFAlgRatFunEval[ga, cf, {ina}, avars, Flatten[C]];
      (* (expressions x integrals) . (integrals x masters) *)
      FFAlgMatMul[ga, mm, {cf, tk}, E0, Length[nonmI], Length[cols]]; out = mm];
    If[mastI =!= {},
      FFAlgRatFunEval[ga, dn, {ina}, avars, Flatten[Dw]];
      If[out === None, out = dn, FFAlgAdd[ga, tot, {mm, dn}]; out = tot]];
    FFGraphOutput[ga, out];
    rec = FFReconstructFunction[ga, avars, {"NThreads" -> threads, "MaxPrimes" -> Lookup[job, "MaxPrimes", 200], "MaxDegree" -> Lookup[job, "MaxDegree", 300]}];
    FFDeleteGraph[ga];
    If[! ListQ[rec], setStatus["failed", <|"Message" -> "analytic reconstruction failed: " <> ToString[rec]|>]; finish[3]];
    (* with masters the system lacks (AllowNonUT), coefficients on masters of lower sectors are on that larger basis *)
    anaInfo = <|"Exprs" -> an["Exprs"], "Masters" -> mwant, "Coefficients" -> Map[Factor, ArrayReshape[rec, {E0, Length[cols]}], {2}], "Vars" -> avars,
      "Fix" -> fix, "Seconds" -> Round[AbsoluteTime[] - ta], "Check" -> "not checked", "NonUT" -> nonut|>;
    Put[anaInfo, "analytic.m"]; credit["FiniteFlow"];
    say["analytic coefficients of ", E0, " expression(s) on ", Length[cols], " master(s) in ", Round[AbsoluteTime[] - ta], " s"]]];

Do[Module[{P = pts[[ip]], gs, e, subn, red, tk, rec, Rm, pos, vecOf, nms, Dm, Rp, dRp, old, availP, tP, w0, c0, wall, cpu},
   (* resume: a reduction of this point with the same masters and pool is kept (raw_<ip>.m when extra masters were
      removed), unless it holds $Failed (a derivative solve that failed, e.g. with an old FiniteFlow library) *)
   old = SelectFirst[{"raw_" <> ToString[ip] <> ".m", "red_" <> ToString[ip] <> ".m"}, FileExistsQ, None];
   If[old =!= None, old = Quiet@Get[old];
     If[AssociationQ[old] && Sort[old["Point"]] === Sort[P] && old["Masters"] === mast && old["Pool"] === pool && old["Focus"] === focus && FreeQ[old, $Failed],
       reducers[ip] = Lookup[old, "Reducer", "FiniteFlow"]; pointCredit[reducers[ip]];
       If[ip == 1 && kiraNow, say["point 1: Kira's reduction (the same masters and pool as FiniteFlow's)"],
         If[! MemberQ[kept, ip], AppendTo[kept, ip]]; say["point ", ip, " kept from an earlier run"]]; Continue[]]];
   If[ip == 1 && kiraNow, say["point 1: Kira's reduction has other masters or another pool than FiniteFlow's (", Lookup[Quiet@Get["red_1.m"], "Masters", "?"], " against ", mast,
     "); FiniteFlow reduces it again"]];
   setStatus["running", <|"Phase" -> "reconstructing", "Point" -> ip, "Of" -> Length[pts], "Kept" -> kept|>];
   (* other jobs may have started since learning: plan the threads again from the memory free now *)
   availP = memAvail[];
   tP = Module[{t = threads}, While[t > 1 && (model["ReconPerUnit"] Length[keepIdx] Length[mast] t > 0.85 availP - 0.5 || rss[] + model["ReconPerUnit"] Length[keepIdx] Length[mast] t > 0.95 hardGB[]), t--]; t];
   If[! TrueQ[Lookup[job, "Force", False]] && model["ReconPerUnit"] Length[keepIdx] Length[mast] > 0.85 availP - 0.5,
     setStatus["refused", <|"Point" -> ip, "FreeGB" -> availP, "PredictedGB" -> model["ReconPerUnit"] Length[keepIdx] Length[mast], "Others" -> heavyOthers[],
       "Message" -> "point " <> ToString[ip] <> ": the memory free now no longer fits the reconstruction, even with one thread (other processes took it: see Others). Run the command again when memory is free: the finished points are kept"|>];
     finish[1]];
   If[tP < threads, say["point ", ip, ": ", tP, " thread(s) instead of ", threads, ", ", NumberForm[availP, {4, 1}], " GB free; other processes above 1 GB: ",
     StringRiffle[heavyOthers[], ", "]]];
   w0 = AbsoluteTime[]; c0 = cpuSeconds[];
   FFNewGraph[gs]; FFGraphInputVars[gs, e, {eps}];
   FFAlgRatFunEval[gs, subn, {e}, {eps}, Join[{eps}, invs /. P]];
   FFAlgSimpleSubgraph[gs, red, {subn}, g];
   nms = Table[cfx[i, jm], {i, Length[nonm]}, {jm, Length[mast]}];
   FFAlgTake[gs, tk, {red}, {Flatten[nms]} -> Flatten[nms[[keepIdx]]]];
   FFGraphOutput[gs, tk];
   rec = FFReconstructFunction[gs, {eps}, {"NThreads" -> tP, "MaxPrimes" -> Lookup[job, "MaxPrimes", 200], "MaxDegree" -> Lookup[job, "MaxDegree", 300]}];
   If[! ListQ[rec], say["reconstruction failed at point ", ip, ": ", rec]; FFDeleteGraph[gs];
     If[ip == 1, setStatus["failed", <|"Message" -> "reconstruction failed at the first point: " <> ToString[rec]|>]; finish[3]]; Continue[]];
   Rm = Join[ArrayReshape[rec, {Length[keepIdx], Length[mast]}], IdentityMatrix[Length[mast]]];
   pos = AssociationThread[Join[nonm[[keepIdx]], mast] -> Range[Length[keepIdx] + Length[mast]]];
   vecOf[ex_] := Module[{ee = Collect[ex /. P, _j | _ut], jl},
     jl = Cases[Variables[ee], _j | _ut];
     If[jl === {}, 0 Rm[[1]], Sum[Coefficient[ee, jj] Rm[[pos[jj]]], {jj, jl}]]];
   Dm = Table[vecOf /@ dfocus[[k]], {k, Length[ders]}];
   Rp = vecOf /@ pool;
   dRp = If[dpool === {}, {}, Table[vecOf /@ dpool[[k]], {k, Length[ders]}]];
   Put[<|"Masters" -> mast, "Labels" -> utIn, "Point" -> P, "Focus" -> focus, "Dm" -> Dm, "Pool" -> pool, "Rp" -> Rp, "dRp" -> dRp,
     "Invariants" -> ders, "Roots" -> roots, "Allowed" -> allowed, "Reducer" -> "FiniteFlow"|>, "red_" <> ToString[ip] <> ".m"];
   reducers[ip] = "FiniteFlow"; pointCredit["FiniteFlow"];
   (* a raw reduction left by an earlier collection of extra masters belonged to the reduction this one replaces *)
   If[FileExistsQ["raw_" <> ToString[ip] <> ".m"], DeleteFile["raw_" <> ToString[ip] <> ".m"]];
   recordMem[<|"Phase" -> "reconstruct", "Equations" -> neq, "Rows" -> Length[keepIdx], "Masters" -> Length[mast], "Threads" -> tP,
     "BaselineGB" -> base1, "PeakGB" -> hwm[], "IncrementGB" -> hwm[] - base1|>];
   FFDeleteGraph[gs];
   (* a point that got far less CPU than wall-clock time did not run most of the time: sleep, or competition *)
   wall = Round[AbsoluteTime[] - w0]; cpu = If[NumericQ[c0], Round[cpuSeconds[] - c0], Missing[]];
   AppendTo[pointTimes, <|"Point" -> ip, "Date" -> DateString[], "WallSeconds" -> wall, "CPUSeconds" -> cpu, "Threads" -> tP, "Reducer" -> "FiniteFlow",
     "Starved" -> (NumericQ[cpu] && wall > 120 && cpu < 0.25 wall)|>];
   Put[pointTimes, "times.m"];
   say["point ", ip, " done in ", Round[AbsoluteTime[] - t0], " s (", wall, " s wall-clock, ", cpu, " s CPU)"];
   If[Last[pointTimes]["Starved"], say["point ", ip, ": ", wall, " s wall-clock for ", cpu,
     " s of CPU: the machine slept, or other jobs took the CPU or the memory (swap). This timing is not the job's cost; do not plan from it"]]],
  {ip, Length[pts]}];
(* the analytic coefficients against the reduction at the first point (only when no invariant was fixed to another value) *)
If[AssociationQ[anaInfo] && FileExistsQ["red_1.m"], Module[{r1 = Get["red_1.m"], P1, num, ok},
    P1 = r1["Point"];
    If[AllTrue[anaInfo["Fix"], (#[[1]] /. P1) === #[[2]] &],
      num = Table[With[{e = Collect[ex, _j]}, Together[Sum[(Coefficient[e, jj] /. P1) r1["Rp"][[Position[r1["Pool"], jj][[1, 1]]]], {jj, Union[Cases[{e}, _j, Infinity]]}]]][[
          Flatten[Position[r1["Masters"], #] & /@ anaInfo["Masters"]]]], {ex, anaInfo["Exprs"]}];
      ok = Together[(anaInfo["Coefficients"] /. P1) - num] === ConstantArray[0, Dimensions[num]];
      anaInfo["Check"] = If[ok, "agrees with the reduction at the first point", "DISAGREES with the reduction at the first point"];
      Put[anaInfo, "analytic.m"]; say["analytic coefficients: ", anaInfo["Check"]];
      If[! ok, setStatus["failed", <|"Message" -> "the analytic coefficients disagree with the reduction at the first point"|>]; finish[3]]]]];

(* ---- kinematic degrees (job.m "Degrees", bin/degrees.wls, bin/local_slice.wls): the degrees of the rows of the DE in
   the invariants, unit scale fixed, per power of eps or as a whole entry, with their letter content, from FFAllDegrees
   on the learned system (lib/PFB/DegreeGraph.wl); nothing is reconstructed. Then the same for each variant (the DE
   after a change of basis, on the same learned system) and the exact rows at the sample points. degrees.m ---- *)
degInfo = None;
If[degSpec =!= None, Module[{fix = Lookup[degSpec, "Fix", {}], xs, avars, nk = Length[ders], nc = Length[mast], sol = <|"DepVars" -> nonm, "IndepVars" -> mast|>,
    hash, prev, availD, tD, mopts, toEntries, gb, res, vres = <||>, vgraphs = <||>, smp, w0 = AbsoluteTime[], c0 = cpuSeconds[], reshape, rnd},
    xs = Select[invs, ! MemberQ[fix[[All, 1]], #] &]; avars = Join[{eps}, xs];
    hash = Hash[{KeyDrop[degSpec, {"Threads"}], mast, degRows, ders, focus}];
    prev = If[FileExistsQ["degrees.m"], Quiet@Get["degrees.m"], None];
    If[AssociationQ[prev] && Lookup[prev, "Hash", None] === hash && prev["Status"] === "measured",
      say["degrees kept from an earlier run"]; degInfo = prev; credit["FiniteFlow"],
      setStatus["running", <|"Phase" -> "degrees", "Kept" -> kept|>];
      (* the degree graph evaluates the learned system like a point does: the same memory per thread *)
      availD = memAvail[];
      If[! TrueQ[Lookup[job, "Force", False]] && model["ReconPerUnit"] Length[keepIdx] Length[mast] > 0.85 availD - 0.5,
        setStatus["refused", <|"Phase" -> "degrees", "FreeGB" -> availD, "PredictedGB" -> model["ReconPerUnit"] Length[keepIdx] Length[mast], "Others" -> heavyOthers[],
          "Message" -> "the degrees: the memory free now does not fit one thread (other processes took it: see Others). Run the command again when memory is free: the finished points are kept"|>];
        finish[1]];
      tD = Module[{t = threads}, While[t > 1 && (model["ReconPerUnit"] Length[keepIdx] Length[mast] t > 0.85 availD - 0.5 || rss[] + model["ReconPerUnit"] Length[keepIdx] Length[mast] t > 0.95 hardGB[]), t--]; t];
      mopts = <|"Cap" -> Lookup[degSpec, "Cap", 2], "Eps" -> Lookup[degSpec, "Eps", 1009/2027], "Point" -> Lookup[degSpec, "Point", Automatic], "Probes" -> Lookup[degSpec, "Probes", {}],
        "Probe" -> Lookup[degSpec, "Probe", True], "Threads" -> Max[1, Min[tD, Length[xs] + 1]], "MaxDegree" -> Lookup[job, "MaxDegree", 300]|>;
      (* output i of a graph of rows rl, row-major over (derivative, row, column) *)
      toEntries[r_, rl_] := Table[With[{i = en["Index"] - 1, nr = Length[rl]}, Join[<|"Matrix" -> Quotient[i, nr nc] + 1, "Derivative" -> ders[[Quotient[i, nr nc] + 1]],
           "Row" -> rl[[Quotient[Mod[i, nr nc], nc] + 1]], "Column" -> mast[[Mod[i, nc] + 1]]|>, KeyDrop[en, "Index"]]], {en, r["Entries"]}];
      reshape[v_, nr_] := If[ListQ[v] && Length[v] == nk nr nc, ArrayReshape[v, {nk, nr, nc}], $Failed];
      gb = PFBFFExprGraph[degBaseGraph, g, sol, vars, avars, fix, degBase, mast];
      If[StringQ[gb], setStatus["failed", <|"Phase" -> "degrees", "Message" -> "degrees: the graph of the rows: " <> gb|>]; finish[3]];
      say["degrees of ", Length[degRows], " rows x ", nc, " columns x ", nk, " derivatives in ", xs, " (", mopts["Threads"], " threads)"];
      (* "Measure" -> False: only the exact rows at the sample points (the samples of a fit), no FFAllDegrees on the rows *)
      res = If[TrueQ[Lookup[degSpec, "Measure", True]], PFBFFMeasure[gb, avars, mopts],
        <|"Status" -> "measured", "Entries" -> {}, "Total" -> nk Length[degRows] nc, "Eps" -> mopts["Eps"], "Point" -> Missing["NotMeasured"], "Probes" -> {}, "Steps" -> {}, "Seconds" -> 0|>];
      If[res["Status"] =!= "measured", setStatus["failed", <|"Phase" -> "degrees", "Message" -> "degrees: " <> res["Message"]|>]; finish[3]];
      say[If[TrueQ[Lookup[degSpec, "Measure", True]], "degrees measured in " <> ToString[Round[res["Seconds"]]] <> " s: " <> ToString[Length[res["Entries"]]] <> " non-zero entries",
        "no degrees measured (samples only)"]];
      (* variants: their rows reduced on the same learned system, their columns through T^-1 *)
      Do[Module[{nm = v["Name"], nr = Length[v["Rows"]], tim, tm, mat, rndp, gw, gv, rr, inG = v["TInverse"] === Automatic, gh},
         (* T and T^-1 as matrices on the masters of the reduction, the identity where they say nothing *)
         mat[a_] := Module[{m = IdentityMatrix[nc]}, Do[m[[First[FirstPosition[mast, ut[c]]]]] = Table[Together[Coefficient[Collect[a[c], _ut], mm]], {mm, mast}], {c, Keys[a]}]; m];
         rndp = Thread[Join[{eps}, invs] -> RandomPrime[{10^3, 10^5}, Length[invs] + 1]];
         Which[
           ! SubsetQ[mast, ut /@ Join[Keys[v["T"]], If[inG, {}, Keys[v["TInverse"]]]]],
             vres[nm] = <|"Status" -> "failed", "Message" -> "T or TInverse changes masters that are not masters of the reduction"|>,
           ! inG && (tm = mat[v["T"]]; tim = mat[v["TInverse"]]; ! AllTrue[Flatten[Together[(tm /. rndp) . (tim /. rndp) - IdentityMatrix[nc]]], # === 0 &]),
             vres[nm] = <|"Status" -> "failed", "Message" -> "TInverse is not the inverse of T on the masters of the reduction"|>,
           StringQ[gw = PFBFFExprGraph[Unique["degVariantRows"], g, sol, vars, avars, fix, v["Exprs"], mast]],
             vres[nm] = <|"Status" -> "failed", "Message" -> "the graph of the rows: " <> gw|>,
           (* new masters in integrals: their vectors on the masters, and T^-1 inside the graph *)
           inG && StringQ[gh = PFBFFExprGraph[Unique["degVariantNew"], g, sol, vars, avars, fix, v["HExprs"], mast]],
             vres[nm] = <|"Status" -> "failed", "Message" -> "the graph of the new masters: " <> gh|>,
           True,
             gv = Which[inG, PFBFFReplaceGraph[Unique["degVariant"], gw, gh, avars, nk nr, nc, First[FirstPosition[mast, ut[#]]] & /@ Keys[v["T"]]],
               tim === IdentityMatrix[nc], gw, True, PFBFFTransformGraph[Unique["degVariant"], gw, avars, nk nr, nc, tim /. fix]];
             rr = PFBFFMeasure[gv, avars, Join[mopts, <|"Probe" -> v["Probe"]|>]];
             vgraphs[nm] = {gv, nr};
             vres[nm] = If[rr["Status"] === "measured", <|"Status" -> "measured", "Rows" -> v["Rows"], "T" -> v["T"], "TInverse" -> v["TInverse"],
                 "Entries" -> toEntries[rr, v["Rows"]], "Outputs" -> rr["Total"], "Seconds" -> rr["Seconds"]|>, <|"Status" -> "failed", "Message" -> rr["Message"]|>]];
         say["variant ", nm, ": ", vres[nm]["Status"], If[KeyExistsQ[vres[nm], "Seconds"], " in " <> ToString[Round[vres[nm]["Seconds"]]] <> " s", ""]]], {v, degVariants}];
      (* the sampled expressions and their derivatives on the masters *)
      {gX, gDX} = If[degSampleExprs === {}, {None, None},
        {PFBFFExprGraph[degSampleX, g, sol, vars, avars, fix, degSampleExprs, mast], PFBFFExprGraph[degSampleDX, g, sol, vars, avars, fix, degSampleD, mast]}];
      If[StringQ[gX] || StringQ[gDX], setStatus["failed", <|"Phase" -> "degrees", "Message" -> "degrees: the graph of the sampled expressions: " <> First[Select[{gX, gDX}, StringQ]]|>]; finish[3]];
      (* the exact rows at sample points (eps and the invariants left, at the fixed unit scale), for fits *)
      smp = Table[With[{vals = Join[{eps}, xs] /. pt}, If[! VectorQ[vals, NumericQ],
          <|"Point" -> pt, "Message" -> "the point does not give eps and every one of " <> ToString[xs]|>,
          <|"Point" -> pt, "Values" -> Join[<|"Base" -> reshape[First[PFBFFSamples[gb, {vals}]], Length[degRows]]|>,
             Association[KeyValueMap[#1 -> reshape[First[PFBFFSamples[#2[[1]], {vals}]], #2[[2]]] &, vgraphs]],
             If[gX === None, <||>, <|"Exprs" -> ArrayReshape[First[PFBFFSamples[gX, {vals}]], {Length[degSampleExprs], nc}],
               "DExprs" -> ArrayReshape[First[PFBFFSamples[gDX, {vals}]], {nk, Length[degSampleExprs], nc}]|>]]|>]], {pt, Lookup[degSpec, "Samples", {}]}];
      degInfo = <|"Status" -> If[TrueQ[Lookup[degSpec, "Measure", True]], "measured", "sampled"], "Hash" -> hash, "Rows" -> degRows, "Columns" -> mast, "Derivatives" -> ders, "Vars" -> xs, "Fix" -> fix,
        "Cap" -> mopts["Cap"], "Eps" -> res["Eps"], "Point" -> res["Point"], "Probes" -> res["Probes"], "Entries" -> toEntries[res, degRows], "Outputs" -> res["Total"],
        "Steps" -> res["Steps"], "Variants" -> vres, "Samples" -> smp, "Threads" -> mopts["Threads"], "NonUT" -> nonut,
        "Seconds" -> Round[AbsoluteTime[] - w0], "CPUSeconds" -> If[NumericQ[c0], Round[cpuSeconds[] - c0], Missing[]], "Date" -> DateString[]|>;
      Put[degInfo, "degrees.m"]; credit["FiniteFlow"]]]];

(* ---- expressions along a line (job.m "Line", bin/det_line.wls): their reduction on a few masters as functions of the
   line's parameter, at a numerical eps, from evaluations of the learned system; checked at the line's base point, the
   job's first point. line.m ---- *)
lineInfo = None;
If[lineSpec =!= None, Module[{fix = Lookup[lineSpec, "Fix", {}], xs, avars, gL, co, nE = Length[lineExprs], ms = lineSpec["Masters"], r1, P1, e0 = lineSpec["Eps"], num, ok, w0 = AbsoluteTime[]},
    setStatus["running", <|"Phase" -> "line"|>];
    xs = Select[invs, ! MemberQ[fix[[All, 1]], #] &]; avars = Join[{eps}, xs];
    gL = PFBFFExprGraph[lineGraph, g, <|"DepVars" -> nonm, "IndepVars" -> mast|>, vars, avars, fix, lineExprs, ms];
    If[StringQ[gL], setStatus["failed", <|"Phase" -> "line", "Message" -> "line: " <> gL|>]; finish[3]];
    co = PFBFFLine[gL, avars, xs /. lineSpec["Base"], xs /. lineSpec["Direction"], e0, lineT, <|"MaxDegree" -> Lookup[job, "MaxDegree", 300], "Threads" -> threads|>];
    If[! ListQ[co], setStatus["failed", <|"Phase" -> "line", "Message" -> "the reconstruction along the line failed"|>]; finish[3]];
    co = ArrayReshape[co, {nE, Length[ms]}];
    (* at the base of the line (the job's first point) the expressions at eps0 are those of the reduction there *)
    r1 = If[FileExistsQ["red_1.m"], Get["red_1.m"], None];
    (* the integrals of a derivative master (Dinv) are not in the pool: such a line is not checked *)
    ok = Which[! AssociationQ[r1], Missing["NoReduction"],
      ! SubsetQ[r1["Pool"], Union[Cases[lineExprs, _j, Infinity]]], Missing["NotInPool"],
      True, P1 = r1["Point"];
        num = Table[Together[Sum[(Coefficient[e, jj] /. P1) r1["Rp"][[First[FirstPosition[r1["Pool"], jj]]]], {jj, Union[Cases[{e}, _j, Infinity]]}]][[
            Flatten[Position[r1["Masters"], #] & /@ ms]]], {e, lineExprs}] /. eps -> e0;
        AllTrue[Flatten[Together[(co /. lineT -> 0) - num]], # === 0 &]];
    lineInfo = <|"Status" -> If[ok === False, "failed", "done"], "Exprs" -> lineSpec["Exprs"], "Masters" -> ms, "Coefficients" -> co, "Variable" -> lineT,
      "Base" -> lineSpec["Base"], "Direction" -> lineSpec["Direction"], "Eps" -> e0, "Fix" -> fix,
      "Check" -> Which[ok === True, "agrees with the reduction at the base point", ok === False, "DISAGREES with the reduction at the base point", True, "not checked"],
      "Seconds" -> Round[AbsoluteTime[] - w0], "Date" -> DateString[]|>;
    Put[Join[lineInfo, KeyDrop[lineSpec, Keys[lineInfo]]], "line.m"]; If[ok =!= False, credit["FiniteFlow"]];
    say["line: ", nE, " expression(s) on ", Length[ms], " master(s) in ", lineInfo["Seconds"], " s; ", lineInfo["Check"]];
    If[ok === False, setStatus["failed", <|"Phase" -> "line", "Message" -> "the expressions along the line disagree with the reduction at its base point"|>]; finish[3]]]];

(* a point whose reconstruction failed has no red_<ip>.m: say which, so that nobody counts on it *)
With[{missing = Select[Range[Length[pts]], ! FileExistsQ["red_" <> ToString[#] <> ".m"] &]},
  setStatus["done", <|"Masters" -> mast, "Equations" -> neq, "Points" -> Length[pts], "PoolDropped" -> dropped, "Threads" -> threads,
    "Kept" -> kept, "PointTimes" -> pointTimes, "Reducers" -> reducerList[], If[StringQ[kiraFallback], "KiraFallback" -> kiraFallback, Nothing],
    If[nonut === {}, Nothing, "NonUT" -> nonut],
    If[AssociationQ[degInfo], "Degrees" -> <|"Status" -> degInfo["Status"], "Seconds" -> degInfo["Seconds"], "Entries" -> Length[degInfo["Entries"]]|>, Nothing],
    If[AssociationQ[lineInfo], "Line" -> lineInfo["Check"], Nothing],
    "FailedPoints" -> missing, If[missing === {}, Nothing, "Message" -> "reconstruction failed at point(s) " <> ToString[missing] <> "; their reductions are missing"]|>]];
finish[0];
