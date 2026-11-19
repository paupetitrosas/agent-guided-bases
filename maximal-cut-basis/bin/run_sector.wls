#!/usr/bin/env wolframscript
(* One sector, one kernel: validation (with the scaling self-test on this sector), the automatic first pass,
   the FiniteFlow scripts, basis.html and summary.html. Much lighter on the licence than running the steps
   one by one; the FiniteFlow check itself then needs bin/finiteflow_sector.sh (three more kernels, started
   one after the other, so run it after this script has finished).
   usage: run_sector.wls run.wl|family.wl j<pattern>|kira-id [--force] [--no-scaling] [--preflight] *)
Get[FileNameJoin[{ParentDirectory[DirectoryName[$InputFileName]], "lib", "MaximalCutBasis.wl"}]];

Module[{args, setup, fam, sec, dir, checks, st, opts, rec, basis, bin = DirectoryName[$InputFileName]},
  args = Rest[$ScriptCommandLine];
  If[Length[args] < 2, Print["usage: run_sector.wls run.wl|family.wl j<pattern>|kira-id [--force] [--no-scaling] [--preflight]"]; CoreVerdict["run_sector", "usage"]];
  setup = MCBRunSetup[args[[1]]];
  If[setup === $Failed, CoreVerdict["run_sector", "usage", <|"message" -> "no run found for " <> args[[1]]|>]];
  fam = setup["fam"];
  sec = If[StringStartsQ[args[[2]], "j"], SectorFromName[args[[2]]], SectorFromName[ToExpression[args[[2]]], fam["N"]]];
  dir = MCBSectorDir[setup["dir"], sec];
  (* what this script uses is credited to the sector: the self-test's Kira here, the first pass's own step below *)
  CoreCitationContext[dir, SectorName[sec], "scaling self-test"];
  If[MemberQ[args, "--preflight"] && ! MCBSkippedQ["preflight"], MCBPreflight[]];
  Print[MCBToolsLine[]];

  (* 1. validation *)
  If[! MCBSkippedQ["validate-family"],
    checks = MCBValidateFamily[fam];
    Print[MCBValidationReport[checks]];
    If[! MCBFamilyOKQ[checks], Print["\nfix family.wl before anything else runs"]; CoreVerdict["run_sector", "usage", <|"message" -> "family.wl does not validate"|>]];
    If[! MemberQ[args, "--no-scaling"],
      st = First[MCBScalingSelfTest[fam, {sec}, FileNameJoin[{setup["dir"], "selftest"}]]];
      Print["scaling self-test ", st["sector"], ": ", If[st["ok"], "PASS", "FAIL " <> ToString[st["residue"], InputForm]]];
      If[! st["ok"], Print["the derivatives disagree with Kira's conventions: check linear propagators, masses and dimensions"];
        CoreVerdict["run_sector", "usage", <|"message" -> "scaling self-test failed: the derivatives disagree with Kira's conventions"|>]]]];

  (* 2. the automatic first pass *)
  If[FileExistsQ[FileNameJoin[{dir, "basis.m"}]] && ! MemberQ[args, "--force"],
    Print["basis.m exists; keeping it (--force redoes the automatic pass)"],
    If[MemberQ[args, "--force"] && DirectoryQ[FileNameJoin[{dir, "kira"}]], DeleteDirectory[FileNameJoin[{dir, "kira"}], DeleteContents -> True]];
    opts = MCBAutoPassOptions[setup];   (* run.wl "AutoPass" and the time limits, including the budget per sector *)
    rec = MCBAutoPass[fam, sec, dir, opts];
    Print["DONE ", SectorName[sec], " ", rec["status"]]];

  (* 3. the FiniteFlow scripts, written here so that finiteflow_sector.sh does not need a kernel for it; a verdict for
     the current masters.m is kept *)
  basis = MCBReadMasters[dir];
  rec = MCBReadBasis[dir];
  If[ListQ[basis] && ! MCBSkippedQ["finiteflow"] && MCBAvailableQ["LiteIBP"] && MCBAvailableQ["FiniteFlow"] &&
     ! (AssociationQ[MCBReadFFVerdict[dir]] && MCBReadFFVerdict[dir]["status"] =!= "stale"),
    Quiet[DeleteDirectory[FileNameJoin[{dir, "finiteflow"}], DeleteContents -> True]];
    If[MCBWriteFFPipeline[fam, sec, basis, FileNameJoin[{dir, "finiteflow"}],
         If[ListQ[Lookup[rec, "points", None]] && rec["points"] =!= {}, <|"Point" -> First[rec["points"]]|>, <||>]] =!= $Failed,
      MCBShell["(cksum < masters.m > finiteflow/masters.cksum)", dir];
      Print["next: ", FileNameJoin[{bin, "finiteflow_sector.sh"}], " ", dir]]];

  (* 4. reports *)
  If[! MCBSkippedQ["reports"], MCBBasisHTML[dir, fam]; Print[MCBSummaryHTML[setup["dir"], fam]]];
  (* pass: the sector has a usable basis (eps-form or eps-polynomial); anything else needs the agent *)
  rec = MCBReadBasis[dir];
  CoreVerdict["run_sector", If[MemberQ[{"eps-form", "eps-polynomial"}, rec["status"]], "pass", "fail"],
    <|"sector" -> SectorName[sec], "folder" -> dir, "status" -> rec["status"], "range" -> Lookup[rec, "range", Missing[]], "flags" -> Lookup[rec, "flags", {}],
      "masters" -> FileNameJoin[{dir, "masters.m"}]|>]
];
