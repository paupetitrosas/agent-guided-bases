(* ::Package:: *)

(* ::Title:: *)
(*MaximalCutBasis`FiniteFlow`: writes the analytic FiniteFlow check of one sector*)


(* ::Text:: *)
(*The pipeline lives in finiteflow/ inside the sector folder and has three scripts, run in order by*)
(*bin/finiteflow_sector.sh:*)
(*  genIBPs.m      LiteRed/LiteIBP define the family on the maximal cut of the sector (AnalyzeSectors with*)
(*                 CutDs, so every subsector integral is zero) and generate IBP, Lorentz-invariance and*)
(*                 symmetry identities from seeds one rank and one dot above what the basis needs;*)
(*  SetSDE.m       reduces the integrals of the basis (its pieces) and their derivatives onto the masters of the*)
(*                 cut, combines them with the coefficients of the basis (sparse products), inverts the basis*)
(*                 matrix in the graph, and reconstructs the DE analytically in eps and the invariants; if that*)
(*                 is too slow it falls back to eps only, at a numeric point;*)
(*  InvestigateDEQ.m  reads the DE, writes DE.m and verdict.m (eps-form, eps-polynomial or rational).*)
(*The derivatives with respect to the invariants of the external scalar products come from LiteIBP's LIBPDeriv,*)
(*inside SetSDE.m (fast: the derivative of every propagator is computed once). LiteIBP cannot differentiate*)
(*internal masses that are not such invariants, or the constants of linear propagators: those derivatives are*)
(*computed here, integral by integral (MCBDerivJ), and written to derivatives.m. The square root of a basis element*)
(*never appears: with J_i = Sqrt[R_i] K_i, the d log term is R_i'/(2 R_i), rational. The basis never enters the IBP*)
(*system, where LiteIBP would put every coefficient over a common denominator: elements.m keeps each element as it is*)
(*written (prefactor x pieces, MCBCoefficients), and FiniteFlow evaluates every coefficient as it stands*)
(*(FFAlgRatExprEval), with no Expand, Together or Simplify.*)


BeginPackage["MaximalCutBasis`FiniteFlow`", {"MaximalCutBasis`", "SkillCore`Tools`", "SkillCore`Records`", "SkillCore`Pages`", "SkillCore`Citations`", "MaximalCutBasis`Family`",
   "MaximalCutBasis`Sectors`", "MaximalCutBasis`Rules`", "MaximalCutBasis`Derivatives`", "MaximalCutBasis`Kira`", "MaximalCutBasis`DECheck`"}];

MCBWriteFFPipeline::usage = "MCBWriteFFPipeline[fam, sector, masters, dir, <|\"Kernels\" -> n, \"Rank\" -> r, \"MaxDots\" -> d, \"Point\" -> kiraPoint|>] writes the FiniteFlow pipeline for the maximal cut of sector and the basis masters (as in masters.m) into dir. With \"Point\" (the first point of the Kira check), the eps-only fallback is evaluated at that point rescaled to UnitScale = 1, so both modes can be compared with Kira. Returns dir.";
MCBFFLineDE::usage = "MCBFFLineDE[fam, sector, masters, dir, <|\"p0\" -> point, \"p1\" -> point | \"v\" -> direction|>, <|\"Order\" -> K, \"Variable\" -> t, \"Reuse\" -> False|>] reconstructs the maximal-cut DE of the masters (j's of the cut, the basis of the FiniteFlow pipeline written in dir) along the line through p0 towards p1 (or along the direction v, given in the pipeline's variables), in the variables of the pipeline (UnitScale = 1): d/dt J = A(t, eps) J with x(t) = p0 + t v, as eps-Laurent coefficients up to eps^K, and the row of the corner integral. It runs genIBPs.m and SetSDE.m (MCB_FF_MODE=line) inside this kernel; with \"Reuse\" -> True only SetSDE.m runs again, on the IBPs already in dir (for more orders of eps). Returns <|\"status\" -> \"ok\" | \"not applicable\" | \"not computed\" | \"failed\", \"kmin\", \"order\", \"A\" -> {A_kmin, ..., A_K}, \"corner\" -> {rows}, \"masters\", \"p0\", \"v\", \"variables\", \"alpha\", \"beta\"|>. A line DE (\"ok\") is a use of FiniteFlow, LiteRed and LiteIBP (MCBMarkToolUsed).";
MCBRecordFFCheck::usage = "MCBRecordFFCheck[sectorDir, verdict] credits FiniteFlow, LiteRed and LiteIBP to the sector in the run's ledger (citations.m, step \"FiniteFlow check\") when the verdict of the FiniteFlow check comes from a reconstructed DE (eps-form, eps-polynomial or rational); a failed or not applicable check credits nothing. InvestigateDEQ.m, which runs in a kernel of its own, calls it when it writes verdict.m. Returns the entries appended, or {}.";


Begin["`Private`"];


(* the FiniteFlow check runs in kernels of its own (bin/finiteflow_sector.sh): its verdict is recorded explicitly *)
MCBRecordFFCheck[sdir_String, v_Association] := If[MemberQ[{"eps-form", "eps-polynomial", "rational"}, Lookup[v, "status", None]],
  CoreRecordTool[sdir, {"FiniteFlow", "LiteRed", "LiteIBP"}, "FiniteFlow check"], {}];
MCBRecordFFCheck[_, _] := {};


tmpl[name_] := Import[FileNameJoin[{$MCBRoot, "templates", "ff", name}], "Text"];
fillT[t_String, slots_Association] := StringReplace[t, KeyValueMap[("{{" <> #1 <> "}}") -> ToString[#2] &, slots]];

pathsBlock[] := StringJoin[
  (* first on $LibraryPath: a copy of the library in the user's SystemFiles/LibraryResources would otherwise shadow it *)
  If[MCBAvailableQ["FiniteFlowLibrary"], "PrependTo[$LibraryPath, \"" <> MCBPath["FiniteFlowLibrary"] <> "\"];\n", ""],
  Table[If[MCBAvailableQ[t], "$Path = Join[$Path, {\"" <> If[DirectoryQ[MCBPath[t]], MCBPath[t], DirectoryName[MCBPath[t]]] <> "\"}];\n", ""], {t, {"FiniteFlow", "LiteIBP", "LiteRed"}}]];

liteRedFile[] := With[{p = MCBPath["LiteRed"]}, If[DirectoryQ[p], FileNameJoin[{p, "LiteRed2023.m"}], p]];

rankDots[ints_List, s_List] := {Max[0, Max[(-Total[Select[List @@ Rest[#], Negative]]) & /@ ints]],
   Max[0, Max[(Total[(List @@ Rest[#])[[PropPos[s]]]] - Total[s]) & /@ ints]]};

(* mass dimension of a rational combination of integrals (the eps part of the dimension is common to all
   integrals and dropped), from the coefficient of its first integral as written (a large one is read at points,
   MCBWeightOf); $Failed if it cannot be read off *)
dimK[fam_, cs_Association] := Module[{jj, c, dc},
  If[cs === <||>, Return[$Failed]];
  {jj, c} = First[Normal[cs]] /. Rule -> List;
  dc = If[MCBLargeQ[c], MCBWeightOf[fam, c], MCBDimensionOf[fam, c]];
  If[! NumericQ[dc], Return[$Failed]];
  dc + fam["L"] fam["D0"] - Total[(List @@ Rest[jj]) fam["PropDims"]]];

(* the phase of an element whose coefficients are all real or all imaginary, from their values at a random point:
   1, I, or $Failed when they mix *)
phaseOf[cs_Association] := Module[{v = Values[cs] /. MCBRandomValues[Values[cs], 6001]},
  Which[AllTrue[v, Im[#] == 0 &], 1, AllTrue[v, Re[#] == 0 &], I, True, $Failed]];

(* ::Section:: *)
(*The DE along a line, inside this kernel (the Picard-Fuchs step)*)


(* The same pipeline, with the masters of the cut as the basis (ut[i] = j_i): genIBPs.m and SetSDE.m in line mode run
   here, in a context of their own (MCB_FF_INKERNEL=1 makes them end by a Throw), so the step costs no kernel start *)
MCBFFLineDE[fam_Association, s_List, masters_List, dir_String, line_Association, opts_Association : <||>] := Module[{info, dv, us, resc, p0, v,
    ctx, cpath, before, sysinfo, read, K = Lookup[opts, "Order", 2], t = Lookup[opts, "Variable", \[FormalT]], tw, r, gtxt, rk, dt,
    ctxFile = FileNameJoin[{dir, ".ffcontext"}],
    reuse = TrueQ[Lookup[opts, "Reuse", False]] && DirectoryQ[FileNameJoin[{dir, "ibps"}]] && FileExistsQ[FileNameJoin[{dir, ".ffcontext"}]]},
  If[! TrueQ[Quiet[MCBLoadTool["LiteIBP"]]], Return[<|"status" -> "not computed", "message" -> "FiniteFlow, LiteRed or LiteIBP is not available (bin/preflight.wls)"|>]];
  (* "Reuse": the pipeline and its IBPs from a previous call with the same masters; only SetSDE.m runs again *)
  If[! reuse,
    If[DirectoryQ[dir], DeleteDirectory[dir, DeleteContents -> True]];
    If[MCBWriteFFPipeline[fam, s, masters, dir, Join[<|"Kernels" -> Lookup[opts, "Kernels", MCBKernelBudget[]["FiniteFlowKernels"]]|>, KeyTake[opts, {"Rank", "MaxDots"}]]] === $Failed,
      Return[<|"status" -> "failed", "message" -> "could not write the FiniteFlow pipeline for the masters " <> ToString[masters, InputForm]|>]]];
  info = Get[FileNameJoin[{dir, "ffinfo.m"}]];
  dv = info["derivativeVariables"]; us = info["unitScale"];
  If[dv === {}, Return[<|"status" -> "not applicable", "message" -> "the sector depends on one scale only: its dependence is fixed by its mass dimension"|>]];
  (* the line in the variables of the pipeline (UnitScale = 1): x(t) = p0 + t v through the two points, rescaled *)
  resc[pt_] := Table[If[us === None, X /. pt, (X /. pt)/((us /. pt)^info["beta"][X])], {X, dv}];
  (* a "v" given in the pipeline's variables (small integers keep the numbers on the line small), else towards "p1" *)
  p0 = resc[line["p0"]]; v = If[ListQ[Lookup[line, "v", None]], line["v"], resc[line["p1"]] - p0];
  Export[FileNameJoin[{dir, "ffline.m"}], "<|\"p0\" -> " <> ToString[p0, InputForm] <> ", \"v\" -> " <> ToString[v, InputForm] <> ", \"order\" -> " <> ToString[K] <>
     ", \"corner\" -> " <> ToString[MCBCornerIntegral[fam, s], InputForm] <> "|>\n", "Text"];
  Quiet[DeleteFile[FileNameJoin[{dir, #}]] & /@ {"sysinfo.m", "sysline.m"}];
  (* a context of its own; a run on the IBPs already generated keeps the context they were written in, since the files
     hold integrals of that context's family symbol *)
  ctx = If[reuse, StringTrim[Import[ctxFile, "Text"]], "MCBFFLine" <> ToString[$ModuleNumber] <> "`"];
  If[! reuse, Export[ctxFile, ctx, "Text"]];
  cpath = {"LiteIBP`", "LiteRed`", "LiteMomentum`", "FiniteFlow`", "Vectors`", "Types`", "LinearFunctions`", "Numbers`", "System`"};
  (* the cleanup runs even when a time limit aborts the step: the environment, the directory and the parallel kernels
     LiteIBP launches and leaves running are restored *)
  Internal`WithLocalSettings[
    before = Quiet[Kernels[]];
    SetEnvironment[{"MCB_FF_INKERNEL" -> "1", "MCB_FF_MODE" -> "line"}];
    SetDirectory[dir],
    Block[{$Context = ctx, $ContextPath = Select[cpath, MemberQ[$Packages, #] &]},
      (* LiteRed's messages (no front end, NewDsBasis warnings, its basis read twice in one kernel) mean nothing here;
         a failure shows in sysinfo.m. "Verbose" -> True shows them *)
      (* (Block[{Print = Print}] would leave Print with itself as its value, and nothing printed) *)
      If[TrueQ[Lookup[opts, "Verbose", False]],
        If[! reuse, Catch[Get["genIBPs.m"], "mcbff"]]; Catch[Get["SetSDE.m"], "mcbff"],
        Quiet[Block[{Print = (Null &)}, If[! reuse, Catch[Get["genIBPs.m"], "mcbff"]]; Catch[Get["SetSDE.m"], "mcbff"]]]]],
    ResetDirectory[];
    SetEnvironment[{"MCB_FF_INKERNEL" -> None, "MCB_FF_MODE" -> None}];
    Quiet[CloseKernels[Complement[Kernels[], before]]]];
  (* the files are read in a context of their own: ut, tt and eps there are not the toolkit's *)
  read[f_] := If[FileExistsQ[FileNameJoin[{dir, f}]],
    Block[{$Context = ctx <> "Read`", $ContextPath = {"System`"}}, ToExpression[Import[FileNameJoin[{dir, f}], "Text"]]], $Failed];
  sysinfo = read["sysinfo.m"];
  (* the seeds of the pipeline (one rank and one dot above the masters and their derivatives) can be too small, e.g. for
     masters with numerators in a non-planar family: raise both and generate the IBPs again, at most twice *)
  If[AssociationQ[sysinfo] && sysinfo["status"] === "failed" && StringContainsQ[Lookup[sysinfo, "message", ""], "seeds too small"] &&
     Lookup[opts, "SeedTries", 0] < 2,
    gtxt = Import[FileNameJoin[{dir, "genIBPs.m"}], "Text"];
    rk = ToExpression[First[StringCases[gtxt, "rank = " ~~ x : DigitCharacter .. :> x], "1"]];
    dt = ToExpression[First[StringCases[gtxt, "maxdots = " ~~ x : DigitCharacter .. :> x], "1"]];
    (* this Return leaves MCBFFLineDE's own Module: no Module may sit in between *)
    Return[MCBFFLineDE[fam, s, masters, dir, line, Join[opts, <|"Rank" -> rk + 1, "MaxDots" -> dt + 1, "Reuse" -> False,
       "SeedTries" -> Lookup[opts, "SeedTries", 0] + 1|>]], Module]];
  If[! AssociationQ[sysinfo] || sysinfo["status"] =!= "ok",
    Return[<|"status" -> If[AssociationQ[sysinfo] && sysinfo["status"] === "not applicable", "not applicable", "failed"],
      "message" -> If[AssociationQ[sysinfo], Lookup[sysinfo, "message", "?"], "SetSDE.m in line mode did not finish (see " <> dir <> ")"]|>]];
  r = read["sysline.m"];
  If[! AssociationQ[r], Return[<|"status" -> "failed", "message" -> "no sysline.m in " <> dir|>]];
  tw = Symbol[ctx <> "Read`tt"];
  (* a line DE: LiteRed and LiteIBP gave the IBPs, FiniteFlow reduced and reconstructed *)
  MCBMarkToolUsed["FiniteFlow"]; MCBMarkToolUsed["LiteRed"]; MCBMarkToolUsed["LiteIBP"];
  <|"status" -> "ok", "kmin" -> r["kmin"], "order" -> r["order"], "A" -> (r["A"] /. tw -> t), "corner" -> (r["corner"] /. tw -> t),
    "masters" -> masters, "p0" -> p0, "v" -> v, "variables" -> dv, "unitScale" -> us, "alpha" -> info["alpha"], "beta" -> info["beta"]|>];

MCBWriteFFPipeline[fam_Association, s_List, masters_List, dir_String, opts_Association : <||>] := Module[{cands, us = fam["UnitScale"], sub, vars, dvars,
    derivs, lib, slots, rk, dt, pt, nk, phases, alpha, beta, kpt, fromKira = False, liteX, restX, terms, pieces},
  If[! DirectoryQ[dir], CreateDirectory[dir, CreateIntermediateDirectories -> True]];
  (* run.wl settings for finiteflow_sector.sh, which has no kernel of its own to read them *)
  Export[FileNameJoin[{dir, ".timelimit"}], ToString[Round[$MCBFFTimeLimit]], "Text"];
  Quiet[DeleteFile[FileNameJoin[{dir, ".memorylimit"}]]];
  If[NumericQ[$MCBFFMemoryLimit] || $MCBFFMemoryLimit === None,
    Export[FileNameJoin[{dir, ".memorylimit"}], If[NumericQ[$MCBFFMemoryLimit], ToString[N[$MCBFFMemoryLimit], InputForm], "0"], "Text"]];
  If[TrueQ[$MCBKeepScratch], Export[FileNameJoin[{dir, ".keep_scratch"}], "1", "Text"]];
  cands = MCBSplitMaster /@ masters;
  If[MemberQ[cands, $Failed], Print["MCBWriteFFPipeline: a basis element is not Sqrt[R] (rational combination)"]; Return[$Failed]];
  (* each element as it is written, prefactor x pieces: its integrals on the cut and their coefficients, never
     expanded or put over a common denominator *)
  terms = MCBCoefficients[DropOffCut[s][#["K"]]] & /@ cands;
  If[MemberQ[terms, <||>], Print["MCBWriteFFPipeline: a basis element vanishes on the maximal cut"]; Return[$Failed]];
  (* FiniteFlow works over the rationals: a phase I of an element moves into its square root, K -> K/I, R -> -R *)
  phases = phaseOf /@ terms;
  If[MemberQ[phases, $Failed], Print["MCBWriteFFPipeline: element ", First[FirstPosition[phases, $Failed]], " mixes real and imaginary coefficients"]; Return[$Failed]];
  alpha = If[us === None, ConstantArray[0, Length[cands]], (dimK[fam, #] & /@ terms)/fam["Invariants"][us]];
  beta = If[us === None, <||>, Association[Table[X -> fam["Invariants"][X]/fam["Invariants"][us], {X, fam["InvList"]}]]];
  terms = MapThread[If[#2 === 1, #1, Map[Function[c, With[{d = -I c}, If[FreeQ[d, Complex], d, Expand[d]]]], #1]] &, {terms, phases}];
  If[! FreeQ[terms, Complex], Print["MCBWriteFFPipeline: an element has complex coefficients FiniteFlow cannot take"]; Return[$Failed]];
  cands = MapThread[If[#2 === 1, #1, Join[#1, <|"r2" -> -#1["r2"]|>]] &, {cands, phases}];
  sub = If[us === None, {}, {us -> 1}];
  dvars = If[us === None, fam["InvList"], DeleteCases[fam["InvList"], us]];
  vars = Join[{eps}, dvars];
  terms = Map[(# /. sub) &, terms, {2}];
  pieces = Union[Flatten[Keys /@ terms]];
  (* LiteIBP differentiates the invariants of the external scalar products (an internal mass that is one of them
     included: it enters the propagators through the same scalar product); SetSDE.m does those with LIBPDeriv *)
  liteX = Select[dvars, MemberQ[Keys[MCBInvariantsAsSP[fam]], #] &];
  restX = Complement[dvars, liteX];
  (* the others here, integral by integral (small coefficients), then UnitScale -> 1; SetSDE.m differentiates the
     coefficients of the basis *)
  derivs = Association[Table[X -> Association[Table[jj -> (DropOffCut[s][MCBDerivJ[fam, jj, X]] /. sub), {jj, pieces}]], {X, restX}]];
  (* seeds: a derivative raises the dots and the rank by one at most (one propagator squared, times its derivative,
     which is linear in the loop momenta); the derivatives computed here are counted as they are *)
  {rk, dt} = MapThread[Max, {rankDots[JIntegrals[{pieces, Values /@ Values[derivs]}], s], If[liteX === {}, {0, 0}, rankDots[pieces, s] + 1]}];
  (* the eps-only fallback uses the Kira point rescaled to UnitScale = 1, when that point is rational *)
  kpt = Lookup[opts, "Point", None];
  pt = Which[
    ! ListQ[kpt], None,
    us === None, Select[kpt, MemberQ[dvars, #[[1]]] &],
    True, With[{u = us /. kpt}, Table[X -> ((X /. kpt)/u^beta[X]), {X, dvars}]]];
  If[ListQ[pt] && AllTrue[pt[[All, 2]], MatchQ[#, _Integer | _Rational] &], fromKira = True,
    pt = Select[First[MCBPoints[fam, 1, 7]], MemberQ[dvars, #[[1]]] &]];
  nk = Lookup[opts, "Kernels", MCBKernelBudget[]["FiniteFlowKernels"]];
  lib = FileNameJoin[{$MCBRoot, "lib", "MaximalCutBasis.wl"}];
  With[{lit = MCBToLiteIBP[fam, s]},
    Export[FileNameJoin[{dir, "families0.m"}], fillT[tmpl["families0.m"], <|"FAMILY" -> fam["NameString"],
       "KINEMATICS" -> lit["KINEMATICS"], "PROPAGATORS" -> lit["PROPAGATORS"]|>], "Text"];
    slots = <|"FAMILY" -> fam["NameString"], "SECTORNAME" -> SectorName[s], "D0" -> fam["D0"], "LOOP" -> lit["LOOP"], "EXTERNAL" -> lit["EXTERNAL"],
      "MOMCONS" -> lit["MOMCONS"], "INVARIANTS" -> lit["INVARIANTS"], "ALLINV" -> lit["ALLINV"], "SECTORPATTERN" -> lit["SECTORPATTERN"], "CUT" -> lit["CUT"],
      "PATHS" -> pathsBlock[], "LITEREDFILE" -> liteRedFile[], "LIBFILE" -> lib,
      "RANK" -> Lookup[opts, "Rank", rk + 1], "MAXDOTS" -> Lookup[opts, "MaxDots", dt + 1], "NKERNELS" -> nk,
      "SUBST" -> If[us === None, ToString[First[fam["InvList"]] -> First[fam["InvList"]], InputForm], ToString[us -> 1, InputForm]],
      "VARIABLES" -> ToString[vars, InputForm]|>;
    Do[Export[FileNameJoin[{dir, f}], fillT[tmpl[f], slots], "Text"], {f, {"topology.wl", "genIBPs.m", "SetSDE.m", "InvestigateDEQ.m"}}]];
  Export[FileNameJoin[{dir, "elements.m"}], "(* element i: {{integral, coefficient as written}, ...}, square root and phase taken out, UnitScale -> 1 *)\n{\n" <>
     StringRiffle[Table[ToString[List @@@ Normal[t], InputForm], {t, terms}], ",\n"] <> "\n}\n", "Text"];
  Export[FileNameJoin[{dir, "derivatives.m"}], "(* \"LiteIBP\": the invariants SetSDE.m differentiates with LIBPDeriv; \"Precomputed\": X -> <|j -> dj/dX|>\n   for the others (MCBDerivJ), UnitScale -> 1 *)\n" <>
     ToString[<|"LiteIBP" -> liteX, "Precomputed" -> derivs|>, InputForm] <> "\n", "Text"];
  Put[(#["r2"] /. sub) & /@ cands, FileNameJoin[{dir, "prefacts.m"}]];
  (* phases, alpha and beta let InvestigateDEQ.m compare with Kira: A_Kira_ij(u, x) = u^(alpha_i - alpha_j - beta_X) (phase_i/phase_j) A_FF_ij(x/u^beta) *)
  Put[<|"variables" -> vars, "derivativeVariables" -> dvars, "liteIBPInvariants" -> liteX, "unitScale" -> us, "slicePoint" -> (pt[[All, 2]]), "slicePointRules" -> pt,
     "sliceFromKiraPoint" -> fromKira, "kiraPoint" -> kpt, "phases" -> phases, "alpha" -> alpha, "beta" -> beta,
     "masters" -> masters, "sector" -> s|>, FileNameJoin[{dir, "ffinfo.m"}]];
  (* writing the scripts is no use of the tools: the check credits them when it gives a verdict (MCBRecordFFCheck) *)
  dir];



End[];
EndPackage[];
