#!/usr/bin/env wolframscript
(* det T of a recorded change (accepted, pending or rejected) along one random line, on demand only: the job reduces the
   sector's old and new masters (its base family; ut[k] expanded with the basis before the change) on the sector's
   current masters, as functions of the line's parameter at a numerical eps with the unit scale set to 1, from
   evaluations of the learned system (a univariate reconstruction of a few entries). --collect factors det T = det(new)
   / det(old) on the maximal cut, matches each factor with the family's known singularities restricted to the line and
   names the others (spurious factors of the change). reference/workflow.md, "det T along a line".
   A simplification without a sector (rung simplify) is taken in the sector of the masters it replaced; one that
   replaced masters of several sectors needs --sector.
   usage: det_line.wls run.wl <change id> [--sector fam/jPATTERN]   writes the job and prints its command
          det_line.wls run.wl <change id> --collect                 the factors of det T (detline.m in the job folder) *)
Get[FileNameJoin[{ParentDirectory[DirectoryName[$InputFileName]], "lib", "PoleFreeBasis.wl"}]];

Module[{a = Rest[$ScriptCommandLine], st, id, job, an},
  If[Length[a] < 2 || ! StringMatchQ[a[[2]], DigitCharacter ..], Print["usage: det_line.wls run.wl <change id> [--sector fam/jPATTERN] [--collect]"]; CoreVerdict["det_line", "usage"]];
  st = PFBStartRun[a[[1]]];
  If[st === $Failed, CoreVerdict["det_line", "usage", <|"message" -> "no run found for " <> a[[1]]|>]];
  id = ToExpression[a[[2]]];
  If[MemberQ[a, "--collect"],
    an = PFBDetLineReport[st, id];
    If[StringQ[an], Print[an]; CoreVerdict["det_line", "fail", <|"message" -> an|>]];
    Print[PFBDetLineText[an]];
    Print["along ", ToString[an["Line"], InputForm], "; ", an["Check"]];
    CoreVerdict["det_line", "pass", <|"change" -> id, "det" -> ToString[an["Det"], InputForm], "spurious" -> (ToString[#["Factor"], InputForm] & /@ an["Spurious"]),
      "spuriousDegree" -> an["SpuriousDegree"], "known" -> (ToString[#["Factor"], InputForm] & /@ Select[an["Factors"], #["Known"] =!= {} &])|>]];
  job = PFBDetLineJob[st, id, With[{p = Position[a, "--sector"]}, If[p === {} || p[[1, 1]] >= Length[a], <||>,
     With[{q = StringSplit[a[[p[[1, 1]] + 1]], "/"]}, If[Length[q] == 2, <|"Key" -> {ToExpression[q[[1]]], SectorFromName[q[[2]]]}|>,
       Print["--sector takes fam/jPATTERN"]; CoreVerdict["det_line", "usage"]]]]]];
  If[job === $Failed, CoreVerdict["det_line", "fail", <|"message" -> "the job was not written (see above)"|>]];
  Export[FileNameJoin[{job, "command.sh"}], PFBSubtreeCommand[job] <> "\n", "Text"];
  Print["line job: ", job, "\nrun it in the background:\n  ", PFBSubtreeCommand[job], "\nwait for it:\n  ", FileNameJoin[{$PFBRoot, "bin", "wait_job"}], " ", job,
    " --timeout <seconds>\nthen: det_line.wls ", a[[1]], " ", a[[2]], " --collect"];
  CoreVerdict["det_line", "pass", <|"job" -> job, "command" -> PFBSubtreeCommand[job]|>]];
