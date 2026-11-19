(* ::Package:: *)

(* ::Title:: *)
(*MaximalCutBasis: loader*)


(* ::Text:: *)
(*Toolkit of the maximal-cut-basis skill.  Load it with*)
(*    Get["/path/to/maximal-cut-basis/lib/MaximalCutBasis.wl"]*)
(*or, with lib/ on $Path,  Needs["MaximalCutBasis`"].*)
(**)
(*The public symbols of every sub-package are put on $ContextPath.  Third-party packages*)
(*(BaikovPackage, DlogBasis, FiniteFlow, LiteRed, LiteIBP, ...) are never loaded*)
(*here: MCBLoadTool loads them on demand, without adding their contexts to $ContextPath.*)
(**)
(*MIT licence, see ../../LICENSE.*)


(* $MCBVerbose = False set before loading lives in the current context: take its value over, and remove that symbol so
   that it does not shadow the toolkit's *)
With[{g = $Context <> "$MCBVerbose"},
  If[Names[g] =!= {} && ! StringStartsQ[$Context, "MaximalCutBasis`"],
    If[ToExpression["ValueQ[" <> g <> "]"], MaximalCutBasis`$MCBVerbose = ToExpression[g]];
    ToExpression["Remove[" <> g <> "]"]]];

BeginPackage["MaximalCutBasis`"];

j::usage = "j[fam, a1, ..., aN] is the integral Int prod_i D_i^(-a_i) of the family fam (Kira sign convention: positive a_i are propagator powers, negative a_i numerator powers).";
eps::usage = "eps is the dimensional regulator: d = D0 - 2 eps.";
z::usage = "z[i] is the Baikov variable of propagator i of the family (family numbering).";
$MCBRoot::usage = "$MCBRoot is the root directory of the maximal-cut-basis skill.";
$MCBVersion::usage = "$MCBVersion is the version of the MaximalCutBasis toolkit.";
$MCBVerbose::usage = "$MCBVerbose = True prints progress messages of the toolkit.";

Begin["`Private`"];
End[];

EndPackage[];


MaximalCutBasis`$MCBVersion = "1.0";
If[! ValueQ[MaximalCutBasis`$MCBVerbose], MaximalCutBasis`$MCBVerbose = True];
MaximalCutBasis`$MCBRoot = ParentDirectory[DirectoryName[
    Replace[$InputFileName, "" :> FindFile["MaximalCutBasis`"]]]];

(* the shared core: next to this skill in the repository (through the real path, so that a skill installed as a symbolic
   link finds it), or SKILL_CORE *)
If[! MemberQ[$Packages, "SkillCore`"],
  Module[{phys = Quiet@RunProcess[{"/bin/sh", "-c", "cd \"$1\" && pwd -P", "sh", MaximalCutBasis`$MCBRoot}], cands},
    cands = Select[{Replace[Environment["SKILL_CORE"], $Failed -> Nothing],
        If[AssociationQ[phys] && phys["ExitCode"] === 0, FileNameJoin[{ParentDirectory[StringTrim[phys["StandardOutput"]]], "core"}], Nothing],
        FileNameJoin[{ParentDirectory[MaximalCutBasis`$MCBRoot], "core"}]}, FileExistsQ[FileNameJoin[{#, "lib", "SkillCore.wl"}]] &];
    If[cands === {}, Print["MaximalCutBasis: the shared core (core/lib/SkillCore.wl) was not found next to the skill; set SKILL_CORE to its folder."]; Abort[]];
    Get[FileNameJoin[{First[cands], "lib", "SkillCore.wl"}]]]];

Block[{MaximalCutBasis`Private`libDir = FileNameJoin[{MaximalCutBasis`$MCBRoot, "lib", "MCB"}]},
  Scan[Get[FileNameJoin[{MaximalCutBasis`Private`libDir, # <> ".wl"}]] &,
    {"Family", "Sectors", "Rules", "Derivatives", "Kira", "Baikov", "CutIntegrands", "LoopByLoop",
     "LeadingSingularities", "Curves", "DECheck", "Candidates", "Draw", "SectorMaps", "Reports",
     "FiniteFlow", "PicardFuchs", "AutoPass", "Fallbacks"}]];
