(* ::Package:: *)

(* ::Title:: *)
(*PoleFreeBasis: loader*)


(* ::Text:: *)
(*Toolkit of the pole-free-basis skill.  Load it with*)
(*    Get["/path/to/pole-free-basis/lib/PoleFreeBasis.wl"]*)
(**)
(*It needs the maximal-cut-basis toolkit (family objects, derivatives, LiteRed/LiteIBP conversion, tool paths,*)
(*the maximal-cut gate). It is looked for, in this order: the environment variable PFB_MCB (path of*)
(*MaximalCutBasis.wl), the sibling folder ../maximal-cut-basis, then $Path.*)
(**)
(*MIT licence, see ../../LICENSE.*)


(* $PFBVerbose = False set before loading lives in the current context: take its value over, and remove that symbol so
   that it does not shadow the toolkit's *)
With[{g = $Context <> "$PFBVerbose"},
  If[Names[g] =!= {} && ! StringStartsQ[$Context, "PoleFreeBasis`"],
    If[ToExpression["ValueQ[" <> g <> "]"], PoleFreeBasis`$PFBVerbose = ToExpression[g]];
    ToExpression["Remove[" <> g <> "]"]]];

Begin["PoleFreeBasis`Loader`"];
Module[{env = Environment["PFB_MCB"], here = DirectoryName[Replace[$InputFileName, "" :> FindFile["PoleFreeBasis`"]]], cands, f},
  If[! MemberQ[$Packages, "MaximalCutBasis`"],
    cands = Select[{
        If[StringQ[env], env, Nothing],
        FileNameJoin[{ParentDirectory[ParentDirectory[here]], "maximal-cut-basis", "lib", "MaximalCutBasis.wl"}],
        Quiet@FindFile["MaximalCutBasis`"]}, StringQ[#] && FileExistsQ[#] &];
    If[cands === {},
      Print["PoleFreeBasis: the maximal-cut-basis toolkit was not found. Put the maximal-cut-basis skill next to ",
        "pole-free-basis, or set the environment variable PFB_MCB to the path of MaximalCutBasis.wl."];
      Abort[]];
    Block[{MaximalCutBasis`$MCBVerbose = False}, Get[First[cands]]]]];
End[];


BeginPackage["PoleFreeBasis`", {"MaximalCutBasis`"}];

ut::usage = "ut[k] is the k-th master of the system (global label, see reference/formats.md).";
$PFBRoot::usage = "$PFBRoot is the root directory of the pole-free-basis skill.";
$PFBVersion::usage = "$PFBVersion is the version of the PoleFreeBasis toolkit.";
$PFBVerbose::usage = "$PFBVerbose = True prints progress messages of the toolkit.";
$PFBMaxEpsDegree::usage = "$PFBMaxEpsDegree is the highest power of eps a change may leave in an entry of the DE (default 2; Infinity for no cap): the default of every \"MaxEpsDegree\" option. PFBStartRun sets it from run.wl.";

Begin["`Private`"];
End[];

EndPackage[];


PoleFreeBasis`$PFBVersion = "1.0";
If[! ValueQ[PoleFreeBasis`$PFBVerbose], PoleFreeBasis`$PFBVerbose = True];
If[! ValueQ[PoleFreeBasis`$PFBMaxEpsDegree], PoleFreeBasis`$PFBMaxEpsDegree = 2];
PoleFreeBasis`$PFBRoot = ParentDirectory[DirectoryName[Replace[$InputFileName, "" :> FindFile["PoleFreeBasis`"]]]];

Block[{PoleFreeBasis`Private`libDir = FileNameJoin[{PoleFreeBasis`$PFBRoot, "lib", "PFB"}]},
  Scan[Get[FileNameJoin[{PoleFreeBasis`Private`libDir, # <> ".wl"}]] &,
    {"Machine", "Kira", "JobCitations", "Config", "System", "Singularities", "Slice", "Census", "Residues", "Subtree", "Transform", "Rungs", "Gate", "MaxCut", "Records", "Degrees", "Simplify", "Reports"}]];
