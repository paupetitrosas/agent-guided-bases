#!/usr/bin/env wolframscript
(* Write the FiniteFlow check of a sector folder from its masters.m (called by finiteflow_sector.sh when masters.m changed).
   usage: write_ff.wls <sector folder> [--rank r] [--maxdots d] *)
Get[FileNameJoin[{ParentDirectory[DirectoryName[$InputFileName]], "lib", "MaximalCutBasis.wl"}]];

Module[{args, basis, dir, o, opt, r, rec, s, setup},
args = Rest[$ScriptCommandLine];
dir = ExpandFileName[First[args]];
setup = MCBRunSetup[dir];
If[setup === $Failed, CoreVerdict["write_ff", "usage", <|"message" -> "no run found for " <> dir|>]];
s = SectorFromName[FileNameTake[dir]];
basis = MCBReadMasters[dir];
If[! ListQ[basis], Print["no masters.m in ", dir]; CoreVerdict["write_ff", "usage", <|"message" -> "no masters.m in " <> dir|>]];
opt[name_] := With[{p = Position[args, name]}, If[p === {} || p[[1, 1]] == Length[args], Nothing, name -> ToExpression[args[[p[[1, 1]] + 1]]]]];
o = Association[{opt["--rank"], opt["--maxdots"]} /. {"--rank" -> "Rank", "--maxdots" -> "MaxDots"}];
(* Kira's first point, when basis.m describes this masters.m: the eps-only fallback then runs there *)
rec = MCBReadBasis[dir];
If[ListQ[Lookup[rec, "points", None]] && rec["points"] =!= {} && ListQ[Lookup[rec, "masters", None]] &&
   Length[rec["masters"]] == Length[basis] && AllTrue[Together[Lookup[#, "definition", 0] & /@ rec["masters"] - basis], # === 0 &],
  o["Point"] = First[rec["points"]]];
r = MCBWriteFFPipeline[setup["fam"], s, basis, FileNameJoin[{dir, "finiteflow"}], o];
(* the checksum tells finiteflow_sector.sh that this pipeline (and any seeds chosen here) belongs to masters.m *)
If[r =!= $Failed, MCBShell["(cksum < masters.m > finiteflow/masters.cksum)", dir]];
CoreVerdict["write_ff", If[r === $Failed, "error", "pass"], <|"pipeline" -> r|>]
];
