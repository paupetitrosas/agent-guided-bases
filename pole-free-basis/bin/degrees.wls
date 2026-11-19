#!/usr/bin/env wolframscript
(* The degree census: the kinematic degrees of the rows of the DE at the current slice, one reduction job per sector
   subtree (the sector and its images as roots, the slice point, no pool). After learning, each job measures every entry
   of every derivative matrix of the sector's rows with FiniteFlow's FFAllDegrees, nothing reconstructed: per power of
   eps up to the cap (an entry with finite poles, or above the cap, as a whole at a generic numerical eps), the total
   degree of the numerator and of the denominator in the invariants with the unit scale set to 1, the degree in each
   invariant, and the multiplicity of each known singularity (PFBKnownSingularities, letters and SOFIA's list); what the
   probes leave is the unexplained denominator degree. reference/workflow.md, "Kinematic degrees".
   usage: degrees.wls run.wl [fam/jPATTERN ... | all] [--no-letters]   writes the jobs (all: every sector with rows in
                                                                         the slice) and prints the command that runs them
          degrees.wls run.wl --collect [fam/jPATTERN ... | all]          takes the finished jobs into the degree table of
                                                                         the current slice (degrees/degrees_NNN.m)
   A job refused for memory, or one that failed, leaves its sector "not measured". Start the printed command in the
   background (it needs a licence slot of its own) and wait for each job with bin/wait_job <job folder> --timeout S. *)
Get[FileNameJoin[{ParentDirectory[DirectoryName[$InputFileName]], "lib", "PoleFreeBasis.wl"}]];

Module[{a = Rest[$ScriptCommandLine], st, sys, sl, pos, keys, jobs, opts = <||>, cmd, r, name, s, bad},
  If[a === {}, Print["usage: degrees.wls run.wl [fam/jPATTERN ... | all] [--no-letters]  |  degrees.wls run.wl --collect [fam/jPATTERN ... | all]"];
    CoreVerdict["degrees", "usage"]];
  st = PFBStartRun[a[[1]]];
  If[st === $Failed, CoreVerdict["degrees", "usage", <|"message" -> "no run found for " <> a[[1]]|>]];
  sys = st["System"];
  sl = PFBCurrentSlice[st["Dir"], st["State"]];
  If[sl === $Failed, Print["no current slice: import one (import_slice.wls) or build it (local_slice.wls)"]; CoreVerdict["degrees", "usage", <|"message" -> "no current slice"|>]];
  pos = Select[Rest[a], ! StringStartsQ[#, "--"] &];
  keys = If[pos === {} || pos === {"all"},
    Select[PFBSectorKeys[sys], Intersection[PFBSectorMasters[sys, #], sl["Labels"]] =!= {} &],
    With[{p = StringSplit[#, "/"]}, If[Length[p] == 2, {ToExpression[p[[1]]], SectorFromName[p[[2]]]}, $Failed]] & /@ pos];
  bad = If[pos === {} || pos === {"all"}, {}, Pick[pos, MemberQ[PFBSectorKeys[sys], #] & /@ keys, False]];
  If[bad =!= {}, CoreVerdict["degrees", "usage", <|"message" -> "not sectors of the system: " <> StringRiffle[bad, ", "]|>]];
  name[k_] := "deg_" <> StringReplace[PFBSectorString[k], "/" -> "_"];
  If[MemberQ[a, "--collect"],
    jobs = Select[FileNameJoin[{st["Dir"], "jobs", name[#]}] & /@ keys, DirectoryQ];
    If[jobs === {}, Print["no degree job of these sectors: write them first (degrees.wls run.wl ...)"]; CoreVerdict["degrees", "usage", <|"message" -> "no degree jobs"|>]];
    r = PFBCollectDegrees[st, jobs];
    If[r === $Failed, CoreVerdict["degrees", "fail", <|"message" -> "the degrees could not be collected (see above)"|>]];
    Print[PFBDegreeText[r["Table"]]];
    Do[With[{sec = r["Table"]["Sectors"][k]}, Print["  ", PFBSectorString[k], ": ", If[sec["Status"] === "measured",
        With[{u = sec["Summary"]}, If[u["Highest"] === None, "no non-zero entry",
          "highest " <> ToString[u["Highest"]] <> " (" <> ToString[u["Count"]] <> " of " <> ToString[u["Terms"]] <> " terms), sum " <> ToString[u["Sum"]] <>
          If[IntegerQ[u["Unexplained"]], ", unexplained " <> ToString[u["Unexplained"]], ""]] <> "; job " <> ToString[Lookup[sec, "JobSeconds", "?"]] <> " s"],
        "not measured: " <> sec["Reason"]]]], {k, Select[keys, KeyExistsQ[r["Table"]["Sectors"], #] &]}];
    Print["table: ", r["File"]];
    s = r["Table"]["Summary"];
    CoreVerdict["degrees", If[AllTrue[keys, KeyExistsQ[r["Table"]["Sectors"], #] && r["Table"]["Sectors"][#]["Status"] === "measured" &], "pass", "fail"],
      <|"table" -> r["File"], "highest" -> Replace[s["Highest"], None -> Null], "count" -> s["Count"], "sum" -> s["Sum"], "terms" -> s["Terms"],
        "unexplained" -> Replace[s["Unexplained"], _Missing -> Null], "measured" -> s["Measured"], "notMeasured" -> (PFBSectorString /@ s["NotMeasured"]), "complete" -> s["Complete"]|>]];
  If[MemberQ[a, "--no-letters"], opts["Letters"] = False];
  jobs = PFBDegreesJob[st, #, opts] & /@ keys;
  If[MemberQ[jobs, $Failed], CoreVerdict["degrees", "fail", <|"message" -> "a job was not written (see above)"|>]];
  cmd = PFBDegreesCommand[jobs];
  Export[FileNameJoin[{st["Dir"], "jobs", "degrees_command.sh"}], cmd <> "\n", "Text"];
  Print[Length[jobs], " degree job(s): ", StringRiffle[FileNameTake /@ jobs, ", "]];
  Print["run them in the background, one after the other:\n  sh ", FileNameJoin[{st["Dir"], "jobs", "degrees_command.sh"}],
    "\nwait for each with:\n  ", FileNameJoin[{$PFBRoot, "bin", "wait_job"}], " <job folder> --timeout <seconds>\nthen: degrees.wls ", a[[1]], " --collect ",
    If[pos === {}, "all", StringRiffle[pos, " "]]];
  CoreVerdict["degrees", "pass", <|"jobs" -> jobs, "command" -> cmd|>]];
