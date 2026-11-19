#!/usr/bin/env wolframscript
(* Minimal checks of family.wl; with --scaling also the scaling self-test (Kira) on up to three master sectors.
   usage: validate_family.wls family.wl|run.wl [--scaling] *)
Get[FileNameJoin[{ParentDirectory[DirectoryName[$InputFileName]], "lib", "MaximalCutBasis.wl"}]];

Module[{args, checks, fam, r, res, secs, setup},
args = Rest[$ScriptCommandLine];
If[args === {}, Print["usage: validate_family.wls family.wl|run.wl [--scaling]"]; CoreVerdict["validate_family", "usage"]];
setup = MCBRunSetup[First[args]];
If[setup === $Failed, CoreVerdict["validate_family", "usage", <|"message" -> "family.wl could not be read: " <> First[args]|>]];
CoreCitationContext[setup["dir"], "whole run", "scaling self-test"];   (* Kira, on up to three sectors *)
fam = setup["fam"];
If[MCBSkippedQ["validate-family"], Print["validate-family: skipped by user"]; CoreVerdict["validate_family", "pass", <|"skipped" -> True|>]];
checks = MCBValidateFamily[fam];
Print[MCBValidationReport[checks]];
If[! MCBFamilyOKQ[checks], Print["\nfix family.wl before anything else runs"];
  CoreVerdict["validate_family", "fail", <|"failed" -> Select[checks, ! TrueQ[#["pass"]] &][[All, "check"]]|>]];
If[MemberQ[args, "--scaling"],
  secs = Take[Reverse[SortBy[MCBRunSectors[setup], Total]], UpTo[3]];
  If[secs === {}, Print["scaling self-test: no sectors known yet (give Masters in family.wl or run find_masters.wls)"]; CoreVerdict["validate_family", "pass", <|"scaling" -> "no sectors yet"|>]];
  res = MCBScalingSelfTest[fam, secs, FileNameJoin[{setup["dir"], "selftest"}]];
  Do[Print["scaling self-test ", r["sector"], ": ", If[r["ok"], "PASS (residue reduces to 0)", "FAIL " <> ToString[r["residue"], InputForm]]], {r, res}];
  If[! AllTrue[res, #["ok"] &], Print["the derivatives disagree with Kira's conventions: check linear propagators (sign of the constant), masses and dimensions"];
    CoreVerdict["validate_family", "fail", <|"scaling" -> Select[res, ! #["ok"] &][[All, "sector"]]|>]]];
CoreVerdict["validate_family", "pass", <|"scaling" -> MemberQ[args, "--scaling"]|>]
];
