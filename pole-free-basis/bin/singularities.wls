#!/usr/bin/env wolframscript
(* Known singularities of the families, with SOFIA (optional; reference/tools.md and reference/workflow.md, "Known
   singularities"): SOFIA's candidate singularities of the top graph of each base family (of each top graph, when a
   family has several), subtopologies included, SolverBound -> Infinity, no Substitutions, one family after the other in
   this kernel. scr.m is loaded here only: it changes System`CenterDot and System`Wedge and exports one-letter symbols.
   Each family's polynomials, renamed into its invariants, go to singularities/<fam>.m of the run folder with their
   provenance (SOFIA's commit and hash, options, warnings, time); SOFIA's output to singularities/<fam>.log. A cache
   whose input has not changed is kept (--force recomputes). SOFIA is credited in the run's ledger (citations.m, for the
   whole run) for each family it gave polynomials.
   usage: singularities.wls run.wl [fam ...] [--time-limit S] [--force]      (S per graph, default 3600; 0: none)
   Exit code 0 when every family is done, 1 when one is partial, timed out, failed or not applicable (no graph SOFIA
   takes), 2 when the path is not SOFIA's scr.m, 3 when scr.m does not load. Without "SOFIA" in paths.wl it says so
   and exits with 0: nothing is computed, and nothing else needs it. *)
Get[FileNameJoin[{ParentDirectory[DirectoryName[$InputFileName]], "lib", "PoleFreeBasis.wl"}]];

Module[{a = Rest[$ScriptCommandLine], st, opts = <||>, p, fams, bad, r, fr, offers},
If[a === {}, Print["usage: singularities.wls run.wl [fam ...] [--time-limit S] [--force]"]; CoreVerdict["singularities", "usage", <|"message" -> "no run.wl"|>]];
p = Position[a, "--time-limit"];
If[p =!= {}, If[p[[1, 1]] < Length[a] && StringMatchQ[a[[p[[1, 1]] + 1]], DigitCharacter ..],
    opts["TimeLimit"] = Replace[ToExpression[a[[p[[1, 1]] + 1]]], 0 -> Infinity]; a = Drop[a, {p[[1, 1]], p[[1, 1]] + 1}],
    CoreVerdict["singularities", "usage", <|"message" -> "--time-limit needs a number of seconds"|>]]];
If[MemberQ[a, "--force"], opts["Force"] = True; a = DeleteCases[a, "--force"]];
st = PFBStartRun[a[[1]]];
If[st === $Failed, CoreVerdict["singularities", "usage", <|"message" -> "no run found for " <> a[[1]]|>]];
fams = If[Length[a] >= 2, Rest[a], All];
If[ListQ[fams],
  bad = Select[fams, ! MemberQ[ToString /@ st["System"]["Order"], #] &];
  If[bad =!= {}, CoreVerdict["singularities", "usage", <|"message" -> "unknown families " <> StringRiffle[bad, ", "] <> "; the system has " <> StringRiffle[ToString /@ st["System"]["Order"], ", "]|>]]];
r = PFBRunSingularities[st, fams, opts];
If[r["Status"] =!= "done",
  Print[r["Message"]];
  CoreVerdict["singularities", Switch[r["Status"], "skipped", "pass", "refused", "usage", _, "error"],
    <|"skipped" -> (r["Status"] === "skipped"), "status" -> r["Status"], "message" -> r["Message"]|>]];
fr = r["Families"];
Print["\nknown singularities (singularities/<fam>.m):"];
KeyValueMap[Print["  ", #1, ": ", #2["Status"], ", ", Length[#2["Polynomials"]], " polynomials", If[TrueQ[#2["Reused"]], " (unchanged)", ""],
    If[#2["Warnings"] === {}, "", "; warnings: " <> StringRiffle[#2["Warnings"], " | "]]] &, fr];
offers = PFBSingularityOffers[st["System"], st["Dir"]];
Scan[Print["\nletters on offer: ", #["Message"]] &, offers];
CoreVerdict["singularities", If[AllTrue[Values[fr], #["Status"] === "done" &], "pass", "fail"],
  <|"families" -> Association[KeyValueMap[ToString[#1] -> <|"status" -> #2["Status"], "polynomials" -> Length[#2["Polynomials"]],
       "warnings" -> Length[#2["Warnings"]], "file" -> PFBSingularitiesFile[st["Dir"], #1]|> &, fr]],
    "sofia" -> KeyTake[r["SOFIA"], {"Path", "Version", "Commit", "Pinned"}], "offers" -> (ToString[#["Family"]] & /@ offers)|>]];
