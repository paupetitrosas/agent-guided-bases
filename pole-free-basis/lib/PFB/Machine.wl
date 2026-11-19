(* ::Package:: *)

(* ::Title:: *)
(*PoleFreeBasis`Machine`: memory and processes of this machine (Linux /proc; macOS sysctl, vm_stat and ps)*)


(* ::Text:: *)
(*Self-contained: bin/subtree.wls loads this file without the rest of the toolkit. Linux has /proc; macOS has none, so*)
(*the memory comes from sysctl and vm_stat, a process's resident memory from ps, and whether a process runs from*)
(*kill -0 or ps -p. macOS keeps no peak resident memory of a process: a sampler started at the beginning of a phase*)
(*reads it once a second with ps. Each parser takes the text of its source (a /proc file or a command's output) as*)
(*its argument, so planted outputs test it on any system.*)


BeginPackage["PoleFreeBasis`Machine`"];

PFBParseMeminfo::usage = "PFBParseMeminfo[text] reads the text of /proc/meminfo: <|\"MemTotal\", \"MemAvailable\", \"SwapTotal\", \"SwapFree\"|> in GB, Missing[] for a field it lacks.";
PFBParseMemsize::usage = "PFBParseMemsize[text] reads the output of sysctl -n hw.memsize (bytes): the memory of the machine in GB, or Missing[].";
PFBParseVmStat::usage = "PFBParseVmStat[text] reads the output of vm_stat: the memory available in GB, the free, inactive and speculative pages times the page size it states, or Missing[].";
PFBParseSwapUsage::usage = "PFBParseSwapUsage[text] reads the output of sysctl -n vm.swapusage (\"total = 2048.00M  used = ...  free = ...\"): <|\"SwapTotal\", \"SwapFree\"|> in GB, Missing[] for a field it lacks.";
PFBParseProcStatus::usage = "PFBParseProcStatus[text, field] reads a field given in kB (\"VmRSS\", \"VmHWM\") of the text of /proc/<pid>/status: GB, or Missing[].";
PFBParsePsRSS::usage = "PFBParsePsRSS[text] reads the output of ps -o rss= -p PID (kB): the resident memory in GB, or Missing[] when it lists nothing (the process is gone).";
PFBParsePsPid::usage = "PFBParsePsPid[text, pid] is True when the output of ps -o pid= -p PID lists pid.";
PFBMachineMemory::usage = "PFBMachineMemory[] = <|\"MemTotal\", \"MemAvailable\", \"SwapTotal\", \"SwapFree\" (GB), \"Source\"|>: from /proc/meminfo (Linux), else from sysctl hw.memsize, vm_stat and sysctl vm.swapusage (macOS). A field neither can give is Missing[]; \"Source\" is \"/proc/meminfo\", \"sysctl, vm_stat\" or None.";
PFBMemAvailableGB::usage = "PFBMemAvailableGB[] is the memory available now, in GB (PFBMachineMemory), or Infinity when the system tells nothing.";
PFBProcessRSSGB::usage = "PFBProcessRSSGB[pid] is the resident memory of a process of this host in GB: VmRSS of /proc/<pid>/status, else ps -o rss=; 0. when neither can be read.";
PFBProcessAliveQ::usage = "PFBProcessAliveQ[pid] is True when the process runs on this host: /proc/<pid> exists where there is a /proc (Linux), else kill -0 succeeds (a process of this user) or ps -p lists it (any user, macOS).";
PFBResetPeak::usage = "PFBResetPeak[pid] starts a new measurement of the peak resident memory of a process: on Linux it resets VmHWM (/proc/<pid>/clear_refs); where the system keeps no peak (macOS) it (re)starts a sampler that reads the process's resident memory with ps once a second, until the process ends or the next PFBResetPeak.";
PFBPeakGB::usage = "PFBPeakGB[pid] is the peak resident memory of a process (GB) since PFBResetPeak[pid]: VmHWM on Linux, else the largest sample of the sampler and the resident memory now; Missing[] when neither is known.";
PFBStopPeakSampler::usage = "PFBStopPeakSampler[pid] stops the sampler of a process (PFBResetPeak) and deletes its file.";

Begin["`Private`"];


(* ::Section:: *)
(*Parsers*)


kbGB[n_] := N[n/1024.^2];

PFBParseMeminfo[txt_String] := Module[{get},
  get[k_] := With[{m = StringCases[txt, StartOfLine ~~ k ~~ ":" ~~ (" " | "\t") .. ~~ n : DigitCharacter .. :> ToExpression[n]]}, If[m === {}, Missing[], kbGB[First[m]]]];
  <|"MemTotal" -> get["MemTotal"], "MemAvailable" -> get["MemAvailable"], "SwapTotal" -> get["SwapTotal"], "SwapFree" -> get["SwapFree"]|>];
PFBParseMeminfo[_] := <|"MemTotal" -> Missing[], "MemAvailable" -> Missing[], "SwapTotal" -> Missing[], "SwapFree" -> Missing[]|>;

PFBParseMemsize[txt_String] := With[{t = StringTrim[txt]}, If[StringMatchQ[t, DigitCharacter ..] && t =!= "0", N[ToExpression[t]/1024.^3], Missing[]]];
PFBParseMemsize[_] := Missing[];

PFBParseVmStat[txt_String] := Module[{ps, pages},
  ps = StringCases[txt, "page size of" ~~ Whitespace ~~ n : DigitCharacter .. ~~ Whitespace ~~ "bytes" :> ToExpression[n]];
  pages[k_] := With[{m = StringCases[txt, StartOfLine ~~ "Pages " ~~ k ~~ ":" ~~ Whitespace ~~ n : DigitCharacter .. :> ToExpression[n]]}, If[m === {}, Missing[], First[m]]];
  If[ps === {} || ! IntegerQ[pages["free"]], Return[Missing[]]];
  (* inactive and speculative pages are given back on demand: memory available, as MemAvailable on Linux *)
  N[First[ps] (pages["free"] + Replace[pages["inactive"], _Missing -> 0] + Replace[pages["speculative"], _Missing -> 0])/1024.^3]];
PFBParseVmStat[_] := Missing[];

PFBParseSwapUsage[txt_String] := Module[{get},
  get[k_] := With[{m = StringCases[txt, k ~~ Whitespace ... ~~ "=" ~~ Whitespace ... ~~ x : NumberString ~~ u : ("K" | "M" | "G") :>
       ToExpression[x] Switch[u, "K", 1/1024.^2, "M", 1/1024., "G", 1.]]}, If[m === {}, Missing[], N[First[m]]]];
  <|"SwapTotal" -> get["total"], "SwapFree" -> get["free"]|>];
PFBParseSwapUsage[_] := <|"SwapTotal" -> Missing[], "SwapFree" -> Missing[]|>;

PFBParseProcStatus[txt_String, field_String] := With[{m = StringCases[txt, StartOfLine ~~ field ~~ ":" ~~ Whitespace ~~ n : DigitCharacter .. :> ToExpression[n]]},
  If[m === {}, Missing[], kbGB[First[m]]]];
PFBParseProcStatus[_, _] := Missing[];

PFBParsePsRSS[txt_String] := With[{t = StringTrim[txt]}, If[StringMatchQ[t, DigitCharacter ..], kbGB[ToExpression[t]], Missing[]]];
PFBParsePsRSS[_] := Missing[];

PFBParsePsPid[txt_String, pid_Integer] := MemberQ[StringTrim /@ StringSplit[txt, "\n"], ToString[pid]];
PFBParsePsPid[_, _] := False;


(* ::Section:: *)
(*Readers*)


(* a /proc file, or $Failed where there is none (macOS) *)
procText[rel_String] := With[{f = "/proc/" <> rel}, If[FileExistsQ[f], Replace[Quiet@Import[f, "Text"], Except[_String] -> $Failed], $Failed]];
procQ[] := DirectoryQ["/proc/self"];
(* a command's standard output, or $Failed when it cannot run *)
cmdOut[args_List] := Replace[Quiet@RunProcess[args, "StandardOutput"], Except[_String] -> $Failed];

PFBMachineMemory[] := Module[{mi = procText["meminfo"], tot, av, sw},
  If[StringQ[mi], Return[Join[PFBParseMeminfo[mi], <|"Source" -> "/proc/meminfo"|>]]];
  tot = PFBParseMemsize[cmdOut[{"sysctl", "-n", "hw.memsize"}]];
  av = PFBParseVmStat[cmdOut[{"vm_stat"}]];
  sw = PFBParseSwapUsage[cmdOut[{"sysctl", "-n", "vm.swapusage"}]];
  <|"MemTotal" -> tot, "MemAvailable" -> av, "SwapTotal" -> sw["SwapTotal"], "SwapFree" -> sw["SwapFree"],
    "Source" -> If[NumericQ[tot] || NumericQ[av], "sysctl, vm_stat", None]|>];

PFBMemAvailableGB[] := Replace[PFBMachineMemory[]["MemAvailable"], Except[_?NumericQ] -> Infinity];

PFBProcessRSSGB[pid_Integer] := Module[{st = procText[ToString[pid] <> "/status"], r},
  r = If[StringQ[st], PFBParseProcStatus[st, "VmRSS"], PFBParsePsRSS[cmdOut[{"ps", "-o", "rss=", "-p", ToString[pid]}]]];
  If[NumericQ[r], r, 0.]];

PFBProcessAliveQ[pid_Integer] := Which[
  procQ[], DirectoryQ["/proc/" <> ToString[pid]],
  (* kill -0 answers for the processes of this user; ps -p for every process *)
  Quiet@RunProcess[{"/bin/sh", "-c", "kill -0 " <> ToString[pid] <> " 2>/dev/null"}, "ExitCode"] === 0, True,
  True, PFBParsePsPid[cmdOut[{"ps", "-o", "pid=", "-p", ToString[pid]}], pid]];
PFBProcessAliveQ[_] := False;


(* ::Section:: *)
(*Peak resident memory*)


(* Linux keeps the peak (VmHWM) and resets it through clear_refs. Elsewhere a shell loop started by the kernel samples
   ps once a second and keeps the largest value in a file; it ends with the process it watches. A peak shorter than a
   second can be missed. *)
$samplers = <||>;

sampleFile[pid_] := FileNameJoin[{$TemporaryDirectory, "pfb_peak_" <> ToString[pid] <> "_" <> ToString[$ProcessID] <> ".txt"}];

PFBStopPeakSampler[pid_Integer] := Module[{s = Lookup[$samplers, pid, None]},
  If[AssociationQ[s], Quiet[KillProcess[s["Process"]]]; Quiet[DeleteFile[s["File"]]]];
  $samplers = KeyDrop[$samplers, pid]; Null];

PFBResetPeak[pid_Integer] := Module[{f, p, sh},
  If[NumericQ[PFBParseProcStatus[procText[ToString[pid] <> "/status"], "VmHWM"]],
    Quiet[RunProcess[{"/bin/sh", "-c", "echo 5 > /proc/" <> ToString[pid] <> "/clear_refs 2>/dev/null"}]]; Return[Null]];
  PFBStopPeakSampler[pid];
  f = sampleFile[pid];
  sh = "m=0; while kill -0 " <> ToString[pid] <> " 2>/dev/null; do r=$(ps -o rss= -p " <> ToString[pid] <> " 2>/dev/null | tr -d ' '); " <>
    "case \"$r\" in ''|*[!0-9]*) ;; *) if [ \"$r\" -gt \"$m\" ]; then m=$r; echo \"$m\" > '" <> f <> "'; fi ;; esac; sleep 1; done";
  p = Quiet@StartProcess[{"/bin/sh", "-c", sh}];
  If[Head[p] === ProcessObject, $samplers[pid] = <|"Process" -> p, "File" -> f|>];
  Null];

PFBPeakGB[pid_Integer] := Module[{st = procText[ToString[pid] <> "/status"], hwm, s = Lookup[$samplers, pid, None], v, now},
  hwm = If[StringQ[st], PFBParseProcStatus[st, "VmHWM"], Missing[]];
  If[NumericQ[hwm], Return[hwm]];
  If[! AssociationQ[s], Return[Missing[]]];
  v = If[FileExistsQ[s["File"]], PFBParsePsRSS[Quiet@Import[s["File"], "Text"]], Missing[]];
  now = PFBProcessRSSGB[pid];
  If[NumericQ[v], Max[v, now], now]];


End[];
EndPackage[];
