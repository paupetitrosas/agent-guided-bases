(* ::Package:: *)

(* FiniteFlow check of {{FAMILY}} {{SECTORNAME}}, step 1 of 3: IBP, Lorentz-invariance and symmetry identities
   on the maximal cut. The basis is not part of the system: SetSDE.m evaluates its coefficients as they stand and
   combines them with the reductions (elements.m).
   The layout (topology.wl, the seeds, LIBPFastGenIds, the serialised identities) follows the differential-equations
   example of finiteflow-mathtools by T. Peraro (github.com/peraro/finiteflow-mathtools).
   Written by MaximalCutBasis.  Run: wolframscript -file genIBPs.m < /dev/null *)

{{PATHS}}
(* MaximalCutBasis also runs this file inside its own kernel (MCB_FF_INKERNEL=1, for the Picard-Fuchs line): the
   packages are then loaded already, and the script ends by a Throw instead of Quit *)
finish[] := If[Environment["MCB_FF_INKERNEL"] === "1", Throw[Null, "mcbff"], Quit[]];
If[! MemberQ[$Packages, "FiniteFlow`"], Get["FiniteFlow`"]];
If[! MemberQ[$Packages, "LiteRed`"], Get["{{LITEREDFILE}}"]];
If[! MemberQ[$Packages, "LiteIBP`"], Get["LiteIBP`"]];
Get["topology.wl"];

(* seeds: one more than the largest rank and number of dots among the masters and their derivatives *)
rank = {{RANK}};
maxdots = {{MAXDOTS}};
GetSeeds["IBP"][sector_] := LIBPGenerateSeeds[sector, {0, maxdots}, 0, rank];
GetSeeds["LI"][sector_] := LIBPGenerateSeeds[sector, {0, maxdots}, 0, rank];
GetSeeds["SR"][sector_] := LIBPGenerateSeeds[sector, {0, 0}, 0, rank];
GetSeeds["Map"][sector_] := LIBPGenerateSeeds[sector, {0, maxdots + 1}, 0, rank];
GetSeeds["ExtMap"][sector_] := LIBPGenerateSeeds[sector, {0, maxdots + 1}, 0, rank];

If[! DirectoryQ["ibps"], CreateDirectory["ibps"]];
LIBPFastGenIds[{{FAMILY}}, GetSeeds, "Directory" -> "ibps", "LaunchKernels" -> {{NKERNELS}}];

LIBPSerializeFastIds[FileNames["ibps/ids_*.mx"], {{SUBST}}, {{VARIABLES}}];
finish[];
