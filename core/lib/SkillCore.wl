(* ::Package:: *)

(* ::Title:: *)
(*SkillCore: the core shared by the maximal-cut-basis and pole-free-basis skills*)


(* ::Text:: *)
(*Tools (the registry, paths, detection, loading, preflight, licence, scratch), records (sector files, JSON verdicts and*)
(*exit codes), pages (one HTML template and stylesheet) and citations (the run's ledger of tools and papers,*)
(*CITATIONS.md). Loaded by both toolkits; see core/README.md.*)
(*MIT licence, see ../../LICENSE.*)


BeginPackage["SkillCore`"];
$CoreRoot::usage = "$CoreRoot is the root directory of the shared core (core/).";
$CoreVersion::usage = "$CoreVersion is the version of the shared core.";
EndPackage[];

SkillCore`$CoreVersion = "1.0";
SkillCore`$CoreRoot = ParentDirectory[DirectoryName[Replace[$InputFileName, "" :> FindFile["SkillCore`"]]]];
Scan[Get[FileNameJoin[{SkillCore`$CoreRoot, "lib", "Core", # <> ".wl"}]] &, {"Tools", "Records", "Pages", "Citations"}];
$ContextPath = DeleteDuplicates[Join[{"SkillCore`Tools`", "SkillCore`Records`", "SkillCore`Pages`", "SkillCore`Citations`", "SkillCore`"}, $ContextPath]];
