#!/usr/bin/env wolframscript
(* Memory and process checks on Linux and on macOS (lib/PFB/Machine.wl). macOS has no /proc: the memory comes from
   sysctl hw.memsize, vm_stat (free + inactive + speculative pages times the page size) and sysctl vm.swapusage, a
   process's resident memory from ps -o rss=, whether a process runs from kill -0 or ps -p, and the peak of a phase
   from a sampler that reads ps once a second. Planted outputs of these commands test the parsers; "macOS" is then
   simulated on this machine by hiding /proc from the kernel and planting the outputs of sysctl and vm_stat, which
   tests the readers, PFBResources and PFBSubtreeStatus (a running job must not show as killed). Linux itself is
   checked on this machine. No reduction, no FiniteFlow.
   usage: bin/ws tests/machine.wls        exit code 0 when every test passes *)
Get[FileNameJoin[{ParentDirectory[DirectoryName[$InputFileName]], "lib", "PoleFreeBasis.wl"}]];
$PFBVerbose = False;
tmp = CreateDirectory[];

(* ---- planted outputs ---- *)
meminfo = "MemTotal:       16303716 kB\nMemFree:         1180472 kB\nMemAvailable:    9437184 kB\nBuffers:          120844 kB\nSwapTotal:       4194304 kB\nSwapFree:        3145728 kB\n";
memsize = "34359738368\n";   (* 32 GB *)
vmstat = "Mach Virtual Memory Statistics: (page size of 16384 bytes)\n" <>
  "Pages free:                               81920.\nPages active:                            306853.\nPages inactive:                          655360.\n" <>
  "Pages speculative:                         81920.\nPages throttled:                              0.\nPages wired down:                        162113.\n" <>
  "Pages purgeable:                            9372.\n\"Translation faults\":                  902418469.\nPages copy-on-write:                   18406203.\n";
(* (81920 + 655360 + 81920) pages of 16 kB = 12.5 GB *)
swapusage = "total = 2048.00M  used = 512.00M  free = 1536.00M  (encrypted)\n";
procStatus = "Name:\tWolframKernel\nVmPeak:\t 5000000 kB\nVmHWM:\t 2097152 kB\nVmRSS:\t 1048576 kB\n";

(* ---- macOS on this machine: no /proc, and the outputs of sysctl and vm_stat planted ---- *)
SetAttributes[asMac, HoldFirst];
asMac[expr_] := Internal`InheritedBlock[{DirectoryQ, FileExistsQ, Import, RunProcess},
  Unprotect[DirectoryQ, FileExistsQ, Import, RunProcess];
  DirectoryQ[p_String /; StringStartsQ[p, "/proc"]] := False;
  FileExistsQ[p_String /; StringStartsQ[p, "/proc"]] := False;
  Import[p_String /; StringStartsQ[p, "/proc"], ___] := $Failed;
  RunProcess[{"sysctl", "-n", "hw.memsize"}, "StandardOutput"] := memsize;
  RunProcess[{"vm_stat"}, "StandardOutput"] := vmstat;
  RunProcess[{"sysctl", "-n", "vm.swapusage"}, "StandardOutput"] := swapusage;
  expr];

(* a process that has ended: the shell RunProcess waited for *)
deadPid = ToExpression[StringTrim[RunProcess[{"/bin/sh", "-c", "echo $$"}, "StandardOutput"]]];

(* a job folder whose status says "running", with this kernel's PID (alive) or a dead one *)
jobWith[pid_, name_] := Module[{d = FileNameJoin[{tmp, name}]},
  CreateDirectory[d];
  Put[<|"Status" -> "running", "Phase" -> "learning", "Date" -> DateString[], "Seconds" -> 5, "PID" -> pid, "Host" -> $MachineName|>, FileNameJoin[{d, "status.m"}]];
  d];
liveJob = jobWith[$ProcessID, "live"]; deadJob = jobWith[deadPid, "dead"];

(* the sampler of the peak on macOS: about 0.4 GB held for three seconds of samples *)
macPeak = asMac[Module[{x, base, pk},
   PFBResetPeak[$ProcessID]; base = PFBProcessRSSGB[$ProcessID];
   x = RandomReal[1, 5*10^7]; Pause[3]; pk = PFBPeakGB[$ProcessID]; x = 0; PFBStopPeakSampler[$ProcessID];
   {base, pk}]];

tests = {
  (* parsers *)
  VerificationTest[PFBParseMeminfo[meminfo], <|"MemTotal" -> 16303716/1024.^2, "MemAvailable" -> 9., "SwapTotal" -> 4., "SwapFree" -> 3.|>,
    TestID -> "/proc/meminfo"],
  VerificationTest[{PFBParseMemsize[memsize], PFBParseMemsize[""], PFBParseMemsize[$Failed]}, {32., Missing[], Missing[]}, TestID -> "sysctl -n hw.memsize"],
  VerificationTest[{PFBParseVmStat[vmstat], PFBParseVmStat["no such command"], PFBParseVmStat[$Failed]}, {12.5, Missing[], Missing[]},
    TestID -> "vm_stat: free, inactive and speculative pages times the page size"],
  VerificationTest[PFBParseSwapUsage[swapusage], <|"SwapTotal" -> 2., "SwapFree" -> 1.5|>, TestID -> "sysctl -n vm.swapusage"],
  VerificationTest[{PFBParseProcStatus[procStatus, "VmRSS"], PFBParseProcStatus[procStatus, "VmHWM"], PFBParseProcStatus[procStatus, "VmSwap"]}, {1., 2., Missing[]},
    TestID -> "/proc/<pid>/status"],
  VerificationTest[{PFBParsePsRSS["  524288\n"], PFBParsePsRSS[""], PFBParsePsRSS[$Failed]}, {0.5, Missing[], Missing[]}, TestID -> "ps -o rss="],
  VerificationTest[{PFBParsePsPid["  4321\n", 4321], PFBParsePsPid["", 4321], PFBParsePsPid["  43210\n", 4321]}, {True, False, False}, TestID -> "ps -o pid= -p"],
  (* macOS, simulated *)
  VerificationTest[asMac[PFBMachineMemory[]], <|"MemTotal" -> 32., "MemAvailable" -> 12.5, "SwapTotal" -> 2., "SwapFree" -> 1.5, "Source" -> "sysctl, vm_stat"|>,
    TestID -> "macOS: the memory from sysctl and vm_stat"],
  VerificationTest[asMac[PFBMemAvailableGB[]], 12.5, TestID -> "macOS: the memory available is not Infinity (jobs can be refused)"],
  VerificationTest[asMac[Lookup[PFBResources[], {"MemTotalGB", "MemAvailableGB", "SwapGB"}]], {32., 12.5, 2.}, TestID -> "macOS: PFBResources"],
  VerificationTest[asMac[PFBProcessRSSGB[$ProcessID]] > 0.05, True, TestID -> "macOS: the resident memory of the kernel from ps"],
  VerificationTest[asMac[{PFBProcessAliveQ[$ProcessID], PFBProcessAliveQ[deadPid]}], {True, False}, TestID -> "macOS: a process runs, or has ended (kill -0, ps -p)"],
  VerificationTest[asMac[PFBSubtreeStatus[liveJob]["Status"]], "running", TestID -> "macOS: a running job shows as running, not killed"],
  VerificationTest[asMac[PFBSubtreeStatus[deadJob]["Status"]], "killed", TestID -> "macOS: a job whose kernel is gone shows as killed"],
  VerificationTest[NumericQ[macPeak[[2]]] && macPeak[[2]] > macPeak[[1]] + 0.2, True, TestID -> "macOS: the sampler sees the peak of a phase"],
  VerificationTest[asMac[PFBPeakGB[$ProcessID]], Missing[], TestID -> "macOS: no peak without a sampler"],
  (* Linux, this machine *)
  VerificationTest[If[DirectoryQ["/proc/self"], {PFBMachineMemory[]["Source"], NumericQ[PFBMemAvailableGB[]], NumericQ[PFBPeakGB[$ProcessID]],
      PFBProcessAliveQ[$ProcessID], PFBProcessAliveQ[deadPid], PFBSubtreeStatus[liveJob]["Status"]}, "not Linux"],
    If[DirectoryQ["/proc/self"], {"/proc/meminfo", True, True, True, False, "running"}, "not Linux"], TestID -> "Linux: /proc"]
};

report = TestReport[tests];
Print["machine: ", report["TestsSucceededCount"], " passed, ", report["TestsFailedCount"], " failed"];
Do[If[r["Outcome"] =!= "Success", Print["FAILED: ", r["TestID"], "\n  expected ", r["ExpectedOutput"], "\n  got      ", r["ActualOutput"]]], {r, Values[report["TestResults"]]}];
Quiet[DeleteDirectory[tmp, DeleteContents -> True]];
Exit[If[report["TestsFailedCount"] == 0, 0, 1]];
