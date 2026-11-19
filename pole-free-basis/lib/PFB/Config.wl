(* ::Package:: *)

(* ::Title:: *)
(*PoleFreeBasis`Config`: resources, memory model, run folder, jobs, vocabulary*)


BeginPackage["PoleFreeBasis`Config`", {"PoleFreeBasis`", "PoleFreeBasis`Machine`", "MaximalCutBasis`", "SkillCore`Tools`", "SkillCore`Records`", "SkillCore`Pages`"}];

PFBPrint::usage = "PFBPrint[args] prints when $PFBVerbose is True.";
$PFBRungs::usage = "$PFBRungs is the ladder: rung number -> <|\"name\", \"hint\"|> (see reference/escalation.md).";
$PFBStatuses::usage = "$PFBStatuses lists the sector statuses, best first.";
$PFBRules::usage = "$PFBRules describes the hard rules every accepted basis change must satisfy (checked by the gate).";
PFBResources::usage = "PFBResources[] measures the machine: total and available memory (GB), swap, cores, licence kernels, kernels running now.";
PFBCacheDir::usage = "PFBCacheDir[] is the per-user cache folder (memory model, kernel limit).";
PFBMemoryRecords::usage = "PFBMemoryRecords[] returns the recorded peak-memory measurements of earlier reductions on this machine.";
PFBRecordMemory::usage = "PFBRecordMemory[<|\"Phase\" -> \"learn\" | \"reconstruct\", \"Equations\", \"Rows\", \"Masters\", \"Threads\", \"BaselineGB\", \"PeakGB\", \"IncrementGB\"|>] appends one measurement to the memory model of this machine.";
PFBMemoryModel::usage = "PFBMemoryModel[] = <|\"Base\", \"LearnPerEq\", \"ReconPerUnit\", \"Source\", \"Records\"|>: the coefficients (GB) of the memory model of this machine.";
PFBPredictMemory::usage = "PFBPredictMemory[equations, rows, masters, threads] predicts the peak memory (GB) of a reduction kernel: a typical kernel before learning plus the learn and reconstruction increments of PFBMemoryModel[]. Returns <|\"LearnGB\", \"ReconstructGB\", \"PeakGB\", \"Source\"|>.";
PFBPlanReconstruction::usage = "PFBPlanReconstruction[equations, rows, masters, budgetGB] returns <|\"Threads\" -> t, \"PeakGB\" -> g, \"Fits\" -> True/False|>: the largest thread count whose predicted peak stays within budgetGB.";
PFBMemoryBudget::usage = "PFBMemoryBudget[] is the memory (GB) a reduction may use now: 80% of the memory available, minus 1 GB.";
PFBRunDirPath::usage = "PFBRunDirPath[run] is the run folder of a run specification, as PFBRunDir makes it, without creating it.";
PFBRunDir::usage = "PFBRunDir[run] creates (if needed) and returns the run folder of a run specification (Association from run.wl). It refuses folders under /tmp unless \"AllowTmp\" -> True, because scratch folders can be wiped.";
PFBLoadFiniteFlow::usage = "PFBLoadFiniteFlow[] loads FiniteFlow with the configured library first on $LibraryPath (a library in the user's LibraryResources would otherwise shadow it). Returns True on success; False, with a message once, when FiniteFlow is missing or its library does not match FiniteFlow.m (PFBFiniteFlowProblem): the toolkit then solves without it, instead of hanging in FFSparseSolve.";
PFBFiniteFlowProblem::usage = "PFBFiniteFlowProblem[] checks, once FiniteFlow.m is loaded, the library it loaded: None when it provides every function FiniteFlow.m loads, else a String saying what is wrong (no library found, or the functions it lacks: an older build than FiniteFlow.m, which can hang or abort in FFSparseSolve and breaks LiteIBP's derivatives). It costs no kernel and no evaluation.";
PFBTimeStamp::usage = "PFBTimeStamp[] is the current date and time as a string.";

Begin["`Private`"];


PFBPrint[args___] := If[TrueQ[PoleFreeBasis`$PFBVerbose], Print[args]];

PFBTimeStamp[] := DateString[{"Year", "-", "Month", "-", "Day", " ", "Hour", ":", "Minute"}];


(* ::Section:: *)
(*Vocabulary*)


$PFBRungs = <|
  1 -> <|"name" -> "rescale", "hint" -> "a uniform eps^k on whole masters (missing or extra powers of eps; poles at eps = 0)"|>,
  2 -> <|"name" -> "dot-move", "hint" -> "replace a dotted source by the same integral with the dot on another propagator of the sector (same maximal-cut class; its reduction carries the required poles)"|>,
  3 -> <|"name" -> "pair-scan", "hint" -> "try the sector's natural integrals (few dots and numerators, the structural reading's candidates) in two or three slots at once, exactly on the slice (bin/pair_scan.wls): minutes, before any fit"|>,
  4 -> <|"name" -> "residue-fit", "hint" -> "fit the required residue with pinched corners and their numerators; integer coefficients reveal a scalar-product numerator"|>,
  5 -> <|"name" -> "numerator", "hint" -> "rewrite an ISP numerator as a scalar product linear in the loop momenta, or in loop-by-loop Baikov variables"|>,
  6 -> <|"name" -> "completion", "hint" -> "completion solver: one eps power per subsector integral, rational coefficients fitted at many points"|>,
  7 -> <|"name" -> "derivative", "hint" -> "replace the sources by derivatives of clean masters (check the coupling rank and the eps structure first)"|>,
  8 -> <|"name" -> "maximal-cut", "hint" -> "change the maximal-cut basis (undotted low-rank forms, derivatives); check it with the maximal-cut gate"|>,
  9 -> <|"name" -> "flag", "hint" -> "nothing worked within the limits: after the hidden-weight test (a clean lower sector that may carry the factor is scanned first), flag the sector and list what is left to try"|>|>;

$PFBStatuses = {"pole-free", "pole-free (maximal cut changed)", "inherited", "open", "flagged", "not in slice"};

$PFBRules = {
  "every integral of a new master carries a single power of eps, with an eps-independent coefficient",
  "no (a+b eps) factor and no eps in a denominator, in any coefficient",
  "a uniform eps^k on a whole master is allowed",
  "coefficients may be rational functions of the invariants (and keep the master's square-root prefactor)"};


(* ::Section:: *)
(*Resources*)


PFBCacheDir[] := Module[{d = FileNameJoin[{Replace[Environment["XDG_CACHE_HOME"], Except[_String] :> FileNameJoin[{$HomeDirectory, ".cache"}]], "pole-free-basis"}]},
  If[! DirectoryQ[d], Quiet@CreateDirectory[d, CreateIntermediateDirectories -> True]];
  d];

(* /proc/meminfo on Linux, sysctl and vm_stat on macOS (PoleFreeBasis`Machine`); the kernel's own idea of the memory
   only when neither can be read *)
PFBResources[] := Module[{mi = PFBMachineMemory[], kb = Quiet@MCBKernelBudget[], tot, av},
  tot = Replace[mi["MemTotal"], _Missing :> N[$SystemMemory/1024.^3]];
  av = Replace[mi["MemAvailable"], _Missing :> N[Quiet@MemoryAvailable[]/1024.^3]];
  <|"MemTotalGB" -> r1[tot], "MemAvailableGB" -> r1[av],
    "SwapGB" -> If[NumericQ[mi["SwapTotal"]], r1[mi["SwapTotal"]], 0], "Cores" -> $ProcessorCount,
    "LicenceKernels" -> Lookup[kb, "MaxLicenseProcesses", Missing[]], "RunningKernels" -> Lookup[kb, "RunningKernels", Missing[]],
    "FreeKernels" -> Lookup[kb, "FreeKernels", Missing[]]|>];

PFBMemoryBudget[] := r1[Max[1., 0.8 PFBResources[]["MemAvailableGB"] - 1.]];


(* ::Section:: *)
(*Memory model*)


memFile[] := FileNameJoin[{PFBCacheDir[], "memory.m"}];

PFBMemoryRecords[] := With[{f = memFile[]}, If[FileExistsQ[f], Replace[Quiet@Get[f], Except[_List] -> {}], {}]];

PFBRecordMemory[rec_Association] := Module[{all = PFBMemoryRecords[]},
  AppendTo[all, Join[<|"Date" -> PFBTimeStamp[], "Host" -> $MachineName|>, rec]];
  Put[all, memFile[]];
  Length[all]];

r1[x_] := N[Round[10 x]/10];

(* what a phase adds to the kernel's memory: learning ~ a * equations, reconstruction ~ b * rows * masters * threads.
   The runner measures the increments (peak minus the memory before the phase); with three records of a phase on this
   machine the coefficient is the least-squares fit, before that a conservative default. "Base" is a typical kernel
   size before learning (families and identities loaded), for planning only. *)
$learnPerEq = 2.*^-6; $reconPerUnit = 5.*^-6; $base = 3.;

PFBMemoryModel[] := Module[{recs = Select[PFBMemoryRecords[], Lookup[#, "Host", $MachineName] === $MachineName && NumericQ[Lookup[#, "IncrementGB", None]] &],
    a = $learnPerEq, b = $reconPerUnit, c = $base, src, srcL = "default", srcR = "default", fitL, fitR},
  fitL = Select[recs, #["Phase"] === "learn" && #["Equations"] > 0 &];
  fitR = Select[recs, #["Phase"] === "reconstruct" && #["Rows"] #["Masters"] #["Threads"] > 0 &];
  If[Length[fitL] >= 3,
    a = Max[0.25 $learnPerEq, Total[(Max[#["IncrementGB"], 0.] #["Equations"]) & /@ fitL]/Total[#["Equations"]^2 & /@ fitL]];
    c = Median[N[#["BaselineGB"]] & /@ fitL]; srcL = "fitted"];
  If[Length[fitR] >= 3,
    b = Max[0.1 $reconPerUnit, Total[(Max[#["IncrementGB"], 0.] #["Rows"] #["Masters"] #["Threads"]) & /@ fitR]/Total[(#["Rows"] #["Masters"] #["Threads"])^2 & /@ fitR]];
    srcR = "fitted"];
  src = "learning " <> srcL <> ", reconstruction " <> srcR;
  <|"Base" -> c, "LearnPerEq" -> a, "ReconPerUnit" -> b, "Source" -> src, "Records" -> Length[recs]|>];

PFBPredictMemory[neq_, rows_, masters_, threads_] := Module[{m = PFBMemoryModel[], learn, recon},
  learn = m["Base"] + m["LearnPerEq"] neq;
  recon = learn + m["ReconPerUnit"] rows masters threads;
  <|"LearnGB" -> r1[learn], "ReconstructGB" -> r1[recon], "PeakGB" -> r1[Max[learn, recon]], "Source" -> m["Source"]|>];

PFBPlanReconstruction[neq_, rows_, masters_, budget_] := Module[{t, p},
  Do[p = PFBPredictMemory[neq, rows, masters, t];
    If[p["PeakGB"] <= budget, Return[<|"Threads" -> t, "PeakGB" -> p["PeakGB"], "Fits" -> True, "Model" -> p["Source"]|>, Module]],
    {t, Reverse[Range[1, Max[1, Min[8, $ProcessorCount]]]]}];
  p = PFBPredictMemory[neq, rows, masters, 1];
  <|"Threads" -> 1, "PeakGB" -> p["PeakGB"], "Fits" -> False, "Model" -> p["Source"]|>];


(* ::Section:: *)
(*Run folder*)


PFBRunDirPath[run_Association] := Module[{d = Lookup[run, "OutputDir", Automatic]},
  If[d === Automatic, d = FileNameJoin[{Lookup[run, "Dir", Directory[]], Lookup[run, "Name", "pfb"] <> "_poles"}]];
  ExpandFileName[d]];

PFBRunDir[run_Association] := Module[{d = PFBRunDirPath[run]},
  If[StringStartsQ[d, "/tmp/"] && ! TrueQ[Lookup[run, "AllowTmp", False]],
    Print["PFBRunDir: ", d, " is under /tmp, which can be wiped between sessions; choose a persistent \"OutputDir\" (or set \"AllowTmp\" -> True)."];
    Return[$Failed]];
  If[! DirectoryQ[d], CreateDirectory[d, CreateIntermediateDirectories -> True]];
  d];


(* ::Section:: *)
(*Jobs*)


(* FiniteFlow.m loads each function of its library with LibraryFunctionLoad, which gives $Failed for a function the
   library lacks: a library older than FiniteFlow.m lacks the newer ones (18 for a build a year older), loads without
   an error, and later hangs or aborts in FFSparseSolve. The same check is in bin/subtree.wls (PFBFFLibraryProblem) *)
PFBFiniteFlowProblem[] := Module[{lib, bad},
  If[! MemberQ[$Packages, "FiniteFlow`"], Return["FiniteFlow is not loaded"]];
  lib = ToExpression["FiniteFlow`Private`fflowlib"];
  If[! StringQ[lib], Return["FiniteFlow.m found no library (fflowmlink): set \"FiniteFlowLibrary\" in paths.wl"]];
  bad = Select[Names["FiniteFlow`Private`*Implem"], ToExpression[#] === $Failed &];
  If[bad === {}, None, "the FiniteFlow library " <> lib <> " lacks " <> ToString[Length[bad]] <> " of the functions FiniteFlow.m loads (" <>
    StringRiffle[StringReplace[#, {"FiniteFlow`Private`" -> "", "Implem" -> ""}] & /@ Take[bad, UpTo[3]], ", "] <> If[Length[bad] > 3, ", ...", ""] <>
    "): an older build than FiniteFlow.m, which can hang or abort in FFSparseSolve. Set \"FiniteFlowLibrary\" in paths.wl to the build of the same version"]];

$ffProblemSaid = None;
PFBLoadFiniteFlow[] := Module[{pb},
  If[MCBAvailableQ["FiniteFlowLibrary"], $LibraryPath = DeleteDuplicates[Prepend[$LibraryPath, MCBPath["FiniteFlowLibrary"]]]];
  If[! TrueQ[MCBLoadTool["FiniteFlow"]], Return[False]];
  pb = PFBFiniteFlowProblem[];
  If[StringQ[pb], If[pb =!= $ffProblemSaid, $ffProblemSaid = pb; Print["PFBLoadFiniteFlow: FiniteFlow is not used: ", pb]]; Return[False]];
  True];


End[];
EndPackage[];
