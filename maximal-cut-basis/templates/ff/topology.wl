(* ::Package:: *)

(* LiteRed / LiteIBP definition of {{FAMILY}} on the maximal cut of {{SECTORNAME}}.
   The layout follows the differential-equations example of finiteflow-mathtools by T. Peraro
   (github.com/peraro/finiteflow-mathtools).
   Written by MaximalCutBasis.
   CutDs puts the reduction on the maximal cut: every subsector integral vanishes. *)

Get["families0.m"];
SetDim[{{D0}} - 2 eps];

Internal = {{LOOP}};
External = {{EXTERNAL}};
(* LiteIBP needs one momentum-conservation rule: an auxiliary momentum balancing the independent ones *)
MomentumConservation = {{MOMCONS}};
Replacements = Kinematics0;
(* the invariants that appear in external scalar products: SetSDE.m differentiates them with LIBPDeriv, the others
   (internal masses that are not among them, constants of linear propagators) come from derivatives.m *)
Invariants = {{INVARIANTS}};

props = Propagators[1];
LIBPFamilyLite[{{FAMILY}}, props /. MomentumConservation /. Replacements // Expand, Internal, External,
  MomentumConservation, Replacements, Invariants];
Quiet[Declare[{{ALLINV}}, Number]];
NewBasis[{{FAMILY}}, LIBPToLiteRed[props], LIBPLoopMomenta[{{FAMILY}}], GenerateIBP -> True];
AnalyzeSectors[{{FAMILY}}, {{SECTORPATTERN}}, CutDs -> {{CUT}}];
Quiet@Check[FindExtSymmetries[{{FAMILY}}, EMs -> LIBPEMs[{{FAMILY}}]], Null];
Quiet@Check[LIBPFindSymmetries[{{FAMILY}}, EMs -> LIBPEMs[{{FAMILY}}]], Null];
