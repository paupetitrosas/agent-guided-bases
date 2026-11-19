(* ::Package:: *)

(* ::Title:: *)
(*PoleFreeBasis`Degrees`: the kinematic degrees of the DE (degree census), starting degrees, det T on a line*)


(* ::Text:: *)
(*A pole-free basis can still have DE entries whose numerators and denominators have high degree in the invariants. The*)
(*degree census measures, for every entry of every derivative matrix of a sector's rows, per power of eps (or as a whole*)
(*entry at a generic numerical eps when the entry has finite poles or powers above the cap), the total degree of the*)
(*numerator and of the denominator in the invariants with the unit scale set to 1, their degree in each invariant, and*)
(*the multiplicity of every known singularity (PFBKnownSingularities) in each. Only FiniteFlow's FFAllDegrees is used, on*)
(*the learned system of a reduction job (bin/subtree.wls with job.m "Degrees", lib/PFB/DegreeGraph.wl): nothing is*)
(*reconstructed. Degrees are not a gate rule; they are measured and recorded, per slice, in degrees/degrees_NNN.m.*)


BeginPackage["PoleFreeBasis`Degrees`", {"PoleFreeBasis`", "PoleFreeBasis`Config`", "PoleFreeBasis`System`", "PoleFreeBasis`Singularities`", "PoleFreeBasis`Slice`",
  "PoleFreeBasis`Census`", "PoleFreeBasis`Subtree`", "PoleFreeBasis`Transform`", "PoleFreeBasis`Records`", "MaximalCutBasis`", "SkillCore`Tools`", "MaximalCutBasis`Sectors`"}];

PFBUnitScale::usage = "PFBUnitScale[sys] is the unit scale of the system: the \"UnitScale\" of the first family in load order, as the reduction jobs and the local slice use it. The degree census sets it to 1.";
PFBDegreeProbes::usage = "PFBDegreeProbes[sys, runDir, fams] are the probes of the degree census for families fams: the known singularities of each (PFBKnownSingularities, \"Known\") with the unit scale set to 1, as irreducible polynomials in the other invariants (PFBNormalizePolynomials). Returns <|\"Probes\", \"Sources\" (probe -> the known singularities it comes from), \"UnitScaleOnly\" (known singularities that become constants: their multiplicity cannot be seen), \"NonPolynomial\" (known singularities that are no rational function of the invariants, such as a letter with a square root: a FiniteFlow graph cannot evaluate them, so they are not probed), \"Vars\", \"UnitScale\"|>.";
PFBDegreeSpec::usage = "PFBDegreeSpec[ctx, keys, rows, fams, opts] is the \"Degrees\" entry of a job.m: <|\"Keys\" (the sectors it measures), \"Rows\" (labels, or Automatic: the job's focus), \"Fix\" -> {unit scale -> 1}, \"Cap\" (the run's \"MaxEpsDegree\"), \"Eps\" (the generic numerical eps of whole entries), \"Point\" (where the eps structure is read), \"Probes\", \"ProbeSources\", \"Probe\" (letter content, default True), \"Variants\", \"Samples\"|>. opts: \"Probes\" (more polynomials, in the invariants), \"Letters\" (False: no letter content), \"Variants\", \"Samples\", \"Cap\", \"Measure\" (False: no FFAllDegrees on the rows, only the samples: the samples of a fit, degrees.m \"Status\" -> \"sampled\"), \"SampleExprs\" (root-free expressions in integrals whose vectors on the masters, and those of their derivatives, the samples also give: \"Exprs\", \"DExprs\").";
PFBDegreesJob::usage = "PFBDegreesJob[ctx, key, opts] writes the degree job of one sector at the current slice (bin/degrees.wls): the sector and its images as roots, the slice point, no pool, the sector's rows in the slice as focus and job.m \"Degrees\" (PFBDegreeSpec). The runner refuses it like any job when the memory does not fit; the sector is then not measured. opts: \"Rows\", \"Name\" (default deg_<fam>_<jPATTERN>), \"Variants\" (each <|\"Name\", \"T\" -> <|label -> combination of ut[m]|>, \"TInverse\" -> <|label -> combination of ut[m]|>, \"Rows\", \"Probe\"|>: the DE after U' = T U, U = TInverse . U', measured on the same learned system; PFBDegreeVariant builds one), \"Samples\" (points: rules for eps and the invariants; the runner writes the exact rows there), \"Measure\" (False: samples only), \"SampleExprs\", \"Pool\" and \"PoolDerivatives\" (default {} and False: a pool reduced at the slice point, for a change in integrals), \"Probes\", \"Letters\", \"Seeds\", \"ReuseIds\" (Automatic: the identities of the sector's own job when it has them), \"AllowNonUT\", \"Replace\" (True). Returns the job folder.";
PFBDegreesCommand::usage = "PFBDegreesCommand[jobDirs] is one shell command that runs the degree jobs one after the other (each through PFBSubtreeCommand).";
PFBDegreeVariant::usage = "PFBDegreeVariant[name, T, opts] is a variant for PFBDegreesJob: T = <|label -> new master as a combination of ut[m] with coefficients rational in eps and the invariants|> (a rescaling r ut[i], a shift ut[i] + c ut[k], ...); TInverse is computed exactly on the masters T involves. A T whose new masters contain integrals (a swap: root-free definitions, ut[m] terms allowed) gets \"TInverse\" -> Automatic: the job reduces the new masters and inverts T inside its graph (PFBFFReplaceGraph), nothing reconstructed. opts: \"Rows\" (labels whose rows are measured, default the job's), \"Probe\" (False: no letter content). Returns <|\"Name\", \"T\", \"TInverse\", ...|>, or $Failed when T is not invertible.";
PFBReadDegreeJob::usage = "PFBReadDegreeJob[jobDir] reads degrees.m of a degree job, columns as slice labels: <|\"Status\", \"Rows\", \"Columns\" (the order of the sample arrays), \"Derivatives\", \"Vars\", \"Fix\", \"Cap\", \"Eps\", \"Point\", \"Probes\", \"Entries\", \"Variants\" (name -> <|\"Status\", \"Rows\", \"T\", \"TInverse\", \"Entries\", \"Seconds\"|>), \"Samples\" ({<|\"Point\", \"Values\" -> <|\"Base\" | name -> {derivative, row, column} array of exact values|>|>}), \"Seconds\", \"CPUSeconds\", \"Threads\", \"Steps\"|>, or $Failed.";
PFBJobDegreeRecords::usage = "PFBJobDegreeRecords[ctx, jobDir, which] reads one degree job's measurement of its base rows (which = \"Base\", the default) or of one of its variants (which = the variant's name), checked like PFBCollectDegrees (the job done, its reduction calibrating exactly against the current slice): <|\"Keys\" (the job's sectors), \"Reason\" (None, or why its sectors are not measured), \"Sectors\" -> <|key -> sector record as in the degree table, with \"JobWallSeconds\" (the job's kernel, status.m) and \"JobSeconds\" (the degree measurement)|>|>.";
PFBCollectDegrees::usage = "PFBCollectDegrees[ctx, jobDirs] takes the measurements of degree jobs into the table of the current slice (degrees/degrees_NNN.m, indexed in state.m next to the slice): per sector its entries, the summary and the job's time; a sector whose job refused, failed, or whose reduction does not calibrate exactly against the current slice is \"not measured\" with the reason. Returns <|\"State\", \"Table\", \"File\"|>.";
PFBDegreeSummary::usage = "PFBDegreeSummary[entries] summarises measured entries: a term is an entry at one power of eps (or a whole entry), its degree the larger of its numerator and denominator degrees. <|\"Highest\", \"Count\" (terms at the highest), \"Sum\", \"Terms\", \"Entries\", \"Whole\", \"Unexplained\" (denominator degree left by the probes, summed), \"MaxUnexplained\"|>. PFBDegreeSummary[table] does it for a whole degrees table, with \"Measured\", \"NotMeasured\" (sector keys) and \"Complete\".";
PFBDegreeObjective::usage = "PFBDegreeObjective[summary] = {highest degree, terms at it, sum}: the objective of the simplification phase, compared lexicographically.";
PFBReadDegrees::usage = "PFBReadDegrees[runDir, state, p] reads the degrees table of slice p of state[\"Slices\"] (default Automatic: the current slice), or Missing[\"NotMeasured\"].";
PFBStoreDegrees::usage = "PFBStoreDegrees[runDir, state, p, table] writes the degrees table of slice p (degrees/degrees_NNN.m, as slices/slice_NNN.mx) and indexes it in state.m (\"Degrees\" and \"DegreeSummary\" of the slice). Returns the new state.";
PFBDegreeText::usage = "PFBDegreeText[table] is a short text summary of a degrees table.";
PFBImportDegrees::usage = "PFBImportDegrees[sys, sl, conv] reads and validates the degrees the user supplied with an imported slice (conventions.wl \"Degrees\" -> file; reference/formats.md): one matrix per derivative in the slice's layout (with its \"Transpose\"), each entry 0, <|p -> {num, den}, ...|> per power of eps (a Laurent polynomial in eps; every power present in the slice entry), or <|\"Whole\" -> {num, den}|>. Returns <|\"Status\" -> \"ok\" | \"refused\", \"Errors\", \"Warnings\", \"Table\" (provenance \"user\")|>.";
PFBDetLineJob::usage = "PFBDetLineJob[ctx, id, opts] writes the job for det T of a recorded change (accepted, pending or rejected) along one random line (bin/det_line.wls): the reduction of the old and the new masters of the sector's base family (root-free; ut[k] expanded with the basis before the change) on the sector's current masters, as functions of the line's parameter at a numerical eps, with the unit scale set to 1. A simplification (key None) is taken in the sector of the masters it replaced (PFBChangeKeys); when it replaced masters of several sectors, opts \"Key\" names one. opts: \"Key\", \"Base\", \"Direction\" (rules for the invariants left), \"Eps\", \"Name\", \"ReuseIds\". Returns the job folder.";
PFBDetLineReport::usage = "PFBDetLineReport[ctx, id] reads the line job of change id and factors det T = det(new on the maximal cut) / det(old on the maximal cut) along the line (PFBDetLineAnalysis with the family's known singularities); writes detline.m in the job folder. Returns the analysis with \"Change\", \"Key\", \"Check\", or a String saying why not.";
PFBDetLineAnalysis::usage = "PFBDetLineAnalysis[det, probes, base, direction, tau] factors det, a rational function of the line's parameter tau, and matches each factor with the probes (polynomials in the invariants) restricted to the line x = base + tau direction (rules): <|\"Det\" (factored), \"Factors\" -> {<|\"Factor\" (monic in tau), \"Power\" (negative in the denominator), \"Degree\", \"Known\" (the probes whose restriction contains it)|>}, \"Spurious\" (the factors no probe explains), \"SpuriousDegree\"|>. Constant factors (numbers, the numerical eps) are left out.";
PFBDetLineText::usage = "PFBDetLineText[analysis] is a short text of a det T analysis.";

Begin["`Private`"];


(* ::Section:: *)
(*Probes and specifications*)


PFBUnitScale[sys_Association] := PFBFamily[sys, First[sys["Order"]]]["UnitScale"];

(* a known singularity that is a rational function of the invariants (no root, no other symbol): only those can be
   probed, since the probes are evaluated inside FiniteFlow graphs *)
rationalSingularityQ[k_, xs_] := With[{f = Together[k]}, FreeQ[f, Power[_, _Rational] | _Complex] && PolynomialQ[Numerator[f], xs] && PolynomialQ[Denominator[f], xs] &&
   Complement[Variables[{Numerator[f], Denominator[f]}], xs] === {}];
PFBDegreeProbes[sys_Association, dir_, fams_List] := Module[{us = PFBUnitScale[sys], xs, known, src = <||>, probes, nonPoly},
  xs = DeleteCases[sys["Invariants"], us];
  known = DeleteDuplicates[Flatten[Lookup[PFBKnownSingularities[sys, dir, #], "Known", {}] & /@ DeleteDuplicates[fams]]];
  nonPoly = Select[known, ! rationalSingularityQ[# /. us -> 1, xs] &];
  known = Complement[known, nonPoly];
  Do[Scan[(src[#] = Append[Lookup[src, Key[#], {}], k]) &, PFBNormalizePolynomials[{Together[k /. us -> 1]}, xs]], {k, known}];
  probes = PFBNormalizePolynomials[Keys[src], xs];
  <|"Probes" -> probes, "Sources" -> Association[Table[p -> Lookup[src, Key[p], {}], {p, probes}]],
    "UnitScaleOnly" -> Select[known, PFBNormalizePolynomials[{Together[# /. us -> 1]}, xs] === {} &], "NonPolynomial" -> nonPoly, "Vars" -> xs, "UnitScale" -> us|>];

(* the random point of the eps structure and the generic eps of whole entries: fixed by the sectors, so that a job
   written again for the same sectors has the same specification *)
PFBDegreeSpec[ctx_Association, keys_List, rows_, fams_List, opts_Association : <||>] := Module[{sys = ctx["System"], us, xs, pr, extra, pt, e0},
  us = PFBUnitScale[sys]; xs = DeleteCases[sys["Invariants"], us];
  (* one scale for the whole system, as the reduction jobs and the local slice set it *)
  With[{other = Select[DeleteDuplicates[PFBBaseOf[sys, #] & /@ sys["Order"]], PFBFamily[sys, #]["UnitScale"] =!= us &]},
    If[other =!= {}, PFBPrint["degrees: the unit scale is ", us, " (the first family's) for every family; ", other, " name another in family.wl"]]];
  pr = PFBDegreeProbes[sys, ctx["Dir"], fams];
  If[pr["NonPolynomial"] =!= {}, PFBPrint["degrees: not probed (no rational function of the invariants): ", pr["NonPolynomial"]]];
  extra = PFBNormalizePolynomials[Together[Lookup[opts, "Probes", {}] /. us -> 1], xs];
  {pt, e0} = BlockRandom[{RandomPrime[{10^4, 10^6}, Length[xs]], RandomPrime[{100, 1000}]/RandomPrime[{1000, 10000}]}, RandomSeeding -> Hash[keys]];
  Join[<|"Keys" -> keys, "Rows" -> rows, "Fix" -> {us -> 1}, "Cap" -> Lookup[opts, "Cap", Lookup[ctx["Run"], "MaxEpsDegree", $PFBMaxEpsDegree]], "Eps" -> e0,
    "Point" -> Thread[xs -> pt], "Probes" -> PFBNormalizePolynomials[Join[pr["Probes"], extra], xs],
    "ProbeSources" -> Join[pr["Sources"], Association[Table[p -> Lookup[pr["Sources"], Key[p], {"given"}], {p, Complement[extra, pr["Probes"]]}]]],
    "UnitScaleOnly" -> pr["UnitScaleOnly"], "Probe" -> TrueQ[Lookup[opts, "Letters", True]], "Variants" -> Lookup[opts, "Variants", {}], "Samples" -> Lookup[opts, "Samples", {}]|>,
    (* only when asked: a job written before keeps its specification *)
    If[Lookup[opts, "Measure", True] === False, <|"Measure" -> False|>, <||>], If[Lookup[opts, "SampleExprs", {}] =!= {}, <|"SampleExprs" -> opts["SampleExprs"]|>, <||>],
    If[pr["NonPolynomial"] =!= {}, <|"NonPolynomial" -> pr["NonPolynomial"]|>, <||>]]];

sectorJobName[key_] := StringReplace[PFBSectorString[key], "/" -> "_"];

PFBDegreesJob[ctx_Association, key_List, opts_Association : <||>] := Module[{sys = ctx["System"], dir = ctx["Dir"], st = ctx["State"], run = ctx["Run"], sl, rows, roots, spec,
    name, reuse, vrows},
  sl = PFBCurrentSlice[dir, st];
  If[sl === $Failed, Print["PFBDegreesJob: the run has no current slice."]; Return[$Failed]];
  rows = Replace[Lookup[opts, "Rows", Automatic], Automatic :> Intersection[PFBSectorMasters[sys, key], sl["Labels"]]];
  If[rows === {}, Print["PFBDegreesJob: ", PFBSectorString[key], " has no rows in the current slice."]; Return[$Failed]];
  roots = PFBSectorRoots[sys, key, True];
  spec = PFBDegreeSpec[ctx, {key}, rows, DeleteDuplicates[roots[[All, 1]]], opts];
  (* a variant's rows that it does not change are rows of the job *)
  vrows = Flatten[Replace[Lookup[#, "Rows", Automatic], Automatic -> {}] & /@ spec["Variants"]];
  name = Lookup[opts, "Name", "deg_" <> sectorJobName[key]];
  reuse = Replace[Lookup[opts, "ReuseIds", Automatic], Automatic :> With[{d = FileNameJoin[{dir, "jobs", sectorJobName[key], "ibps"}]}, If[DirectoryQ[d], d, None]]];
  PFBSubtreeJob[sys, dir, <|"Name" -> name, "SectorKey" -> key, "Roots" -> roots, "Points" -> {sl["Point"]}, "Derivatives" -> sl["Derivatives"],
    "Seeds" -> Lookup[opts, "Seeds", run["Seeds"]], "Pool" -> Lookup[opts, "Pool", {}], "PoolExtra" -> {}, "PoolDerivatives" -> TrueQ[Lookup[opts, "PoolDerivatives", False]],
    "Focus" -> Union[rows, vrows], "Degrees" -> spec,
    "MaxGB" -> run["MaxGB"], "TimeLimit" -> run["TimeLimit"], "Threads" -> Replace[run["Threads"], Automatic -> Max[1, Min[8, $ProcessorCount - 1]]],
    "ReuseIds" -> reuse, "AllowNonUT" -> Lookup[opts, "AllowNonUT", False], "Replace" -> Lookup[opts, "Replace", True]|>]];

quote[s_String] := "'" <> StringReplace[s, "'" -> "'\\''"] <> "'";
PFBDegreesCommand[jobs_List] := StringRiffle[("(" <> PFBSubtreeCommand[#] <> ")") & /@ jobs, "; "];

PFBDegreeVariant[name_, T_Association, opts_Association : <||>] := Module[{labs, M, Mi, n},
  (* new masters given in integrals (a swap): the job reduces them and inverts T inside its graph *)
  If[! FreeQ[Values[T], _j | _Dinv], Return[Join[<|"Name" -> ToString[name], "T" -> T, "TInverse" -> Automatic|>, KeyTake[opts, {"Rows", "Probe"}]]]];
  labs = Union[Keys[T], Cases[Values[T], ut[k_Integer] :> k, Infinity]];
  n = Length[labs];
  M = Table[If[KeyExistsQ[T, labs[[r]]], Together[Coefficient[Collect[T[labs[[r]]], _ut], ut[labs[[c]]]]], Boole[r == c]], {r, n}, {c, n}];
  If[Together[Det[M]] === 0, Print["PFBDegreeVariant: T is not invertible."]; Return[$Failed]];
  Mi = Together[Inverse[M]];
  Join[<|"Name" -> ToString[name], "T" -> T,
     "TInverse" -> Association[Table[If[Mi[[r]] === UnitVector[n, r], Nothing, labs[[r]] -> Sum[Mi[[r, c]] ut[labs[[c]]], {c, n}]], {r, n}]]|>,
    KeyTake[opts, {"Rows", "Probe"}]]];

(* the runner writes the columns as the masters of its reduction (ut[k]); read back, they are slice labels k *)
relabel[e_Association] := If[KeyExistsQ[e, "Column"], Join[e, <|"Column" -> (e["Column"] /. ut[k_Integer] :> k)|>], e];
relabelVariant[v_Association] := If[ListQ[Lookup[v, "Entries", None]], Join[v, <|"Entries" -> (relabel /@ v["Entries"])|>], v];
PFBReadDegreeJob[jobDir_String] := Module[{f = FileNameJoin[{jobDir, "degrees.m"}], d},
  d = If[FileExistsQ[f], Quiet@Get[f], $Failed];
  If[! AssociationQ[d] || ! MemberQ[{"measured", "sampled"}, d["Status"]], Return[d]];
  Join[d, <|"Columns" -> (d["Columns"] /. ut[k_Integer] :> k), "Entries" -> (relabel /@ d["Entries"]), "Variants" -> (relabelVariant /@ Lookup[d, "Variants", <||>])|>]];


(* ::Section:: *)
(*Tables*)


currentIndex[st_Association] := Replace[FirstPosition[Lookup[st["Slices"], "File"], st["Current"]], {{p_} :> p, _ :> Missing["NoSlice"]}];
sliceIndex[st_, Automatic] := currentIndex[st];
sliceIndex[st_, p_Integer] := If[1 <= p <= Length[st["Slices"]], p, Missing["NoSlice"]];

degreesFile[st_, p_] := StringReplace[st["Slices"][[p]]["File"], {"slices/slice_" -> "degrees/degrees_", ".mx" -> ".m"}];

PFBReadDegrees[dir_String, st_Association, which_ : Automatic] := Module[{p = sliceIndex[st, which], f},
  If[MissingQ[p], Return[Missing["NotMeasured"]]];
  f = Lookup[st["Slices"][[p]], "Degrees", None];
  If[StringQ[f] && FileExistsQ[FileNameJoin[{dir, f}]], Get[FileNameJoin[{dir, f}]], Missing["NotMeasured"]]];

PFBStoreDegrees[dir_String, st0_Association, p_Integer, tab_Association] := Module[{st = st0, f = degreesFile[st0, p], sls},
  If[! DirectoryQ[FileNameJoin[{dir, "degrees"}]], CreateDirectory[FileNameJoin[{dir, "degrees"}]]];
  Put[tab, FileNameJoin[{dir, f}]];
  sls = st["Slices"];
  sls[[p]] = Join[sls[[p]], <|"Degrees" -> f, "DegreeSummary" -> Lookup[tab, "Summary", Missing[]], "DegreeSource" -> Lookup[Lookup[tab, "Provenance", <||>], "Source", "measured"]|>];
  st["Slices"] = sls;
  PFBSaveState[dir, st]];

termDegree[t_] := Max[t["Num"], t["Den"]];

PFBDegreeSummary[entries_List] := Module[{terms = Flatten[Lookup[entries, "Terms", {}], 1], deg, h, un},
  If[terms === {}, Return[<|"Highest" -> None, "Count" -> 0, "Sum" -> 0, "Terms" -> 0, "Entries" -> Length[entries], "Whole" -> 0, "Unexplained" -> 0, "MaxUnexplained" -> None|>]];
  deg = termDegree /@ terms; h = Max[deg];
  un = Cases[Lookup[terms, "DenUnexplained", Missing[]], _Integer];
  <|"Highest" -> h, "Count" -> Count[deg, h], "Sum" -> Total[deg], "Terms" -> Length[terms], "Entries" -> Length[entries],
    "Whole" -> Count[Lookup[terms, "Power"], "whole"], "Unexplained" -> If[un === {}, Missing["NotProbed"], Total[un]], "MaxUnexplained" -> If[un === {}, Missing["NotProbed"], Max[un]]|>];

PFBDegreeSummary[tab_Association] := Module[{secs = Lookup[tab, "Sectors", <||>], meas, s},
  meas = Select[secs, #["Status"] === "measured" &];
  s = PFBDegreeSummary[Flatten[Values[Lookup[#, "Entries", {}] & /@ meas], 1]];
  Join[s, <|"Measured" -> Length[meas], "NotMeasured" -> Keys[Select[secs, #["Status"] =!= "measured" &]], "Sectors" -> Length[Lookup[tab, "Keys", Keys[secs]]],
    "Complete" -> (Length[meas] == Length[Lookup[tab, "Keys", Keys[secs]]])|>]];

PFBDegreeObjective[s_Association] := {Replace[s["Highest"], None -> -Infinity], s["Count"], s["Sum"]};

newTable[sys_, sl_, st_, p_] := <|"Slice" -> st["Slices"][[p]]["File"], "Point" -> sl["Point"], "Derivatives" -> sl["Derivatives"], "UnitScale" -> PFBUnitScale[sys],
   "Vars" -> DeleteCases[sys["Invariants"], PFBUnitScale[sys]], "Keys" -> Select[PFBSectorKeys[sys], Intersection[PFBSectorMasters[sys, #], sl["Labels"]] =!= {} &],
   "Sectors" -> <||>, "Provenance" -> <|"Source" -> "measured"|>, "Date" -> PFBTimeStamp[]|>;

(* the measured entries of a job, on slice labels and derivative indices, grouped by the sector of their row *)
sectorRecords[sys_, sl_, deg_, jobDir_, spec_, wall_] := Module[{kmap, ents, byKey},
  kmap = AssociationThread[deg["Derivatives"] -> (First[FirstPosition[sl["Derivatives"], #]] & /@ deg["Derivatives"])];
  ents = Table[Join[KeyDrop[e, {"Matrix", "Derivative", "Column"}], <|"Matrix" -> kmap[e["Derivative"]], "Derivative" -> e["Derivative"], "Column" -> e["Column"]|>], {e, deg["Entries"]}];
  byKey = GroupBy[ents, PFBMaster[sys, #["Row"]]["SectorKey"] &];
  Association[Table[k -> <|"Status" -> "measured", "Source" -> "measured", "Job" -> FileNameTake[jobDir],
      "Rows" -> Select[deg["Rows"], PFBMaster[sys, #]["SectorKey"] === k &], "Entries" -> Lookup[byKey, Key[k], {}], "Summary" -> PFBDegreeSummary[Lookup[byKey, Key[k], {}]],
      "Vars" -> deg["Vars"], "Fix" -> deg["Fix"], "Cap" -> deg["Cap"], "Eps" -> deg["Eps"], "Probes" -> deg["Probes"], "ProbeSources" -> Lookup[spec, "ProbeSources", <||>],
      "UnitScaleOnly" -> Lookup[spec, "UnitScaleOnly", {}], "NonPolynomial" -> Lookup[spec, "NonPolynomial", {}], "JobSeconds" -> deg["Seconds"], "JobWallSeconds" -> wall, "JobSectors" -> Length[spec["Keys"]], "JobCPUSeconds" -> deg["CPUSeconds"], "Threads" -> deg["Threads"],
      "Steps" -> deg["Steps"], "Date" -> PFBTimeStamp[]|>, {k, Union[Keys[byKey], Intersection[spec["Keys"], Union[PFBMaster[sys, #]["SectorKey"] & /@ deg["Rows"]]]]}]]];

(* a degree job's measurement of the base rows ("Base") or of one of its variants, checked against the current slice *)
PFBJobDegreeRecords[ctx_Association, jd_String, which_ : "Base"] := Module[{sys = ctx["System"], sl, job, spec, keys, status, deg, var = None, red, cal, reason},
  sl = PFBCurrentSlice[ctx["Dir"], ctx["State"]];
  job = Replace[Quiet@Get[FileNameJoin[{jd, "job.m"}]], Except[_Association] -> <||>];
  spec = Lookup[job, "Degrees", None];
  keys = If[AssociationQ[spec], spec["Keys"], {}];
  status = PFBSubtreeStatus[jd];
  deg = PFBReadDegreeJob[jd];
  If[which =!= "Base" && AssociationQ[deg] && deg["Status"] === "measured", var = Lookup[deg["Variants"], which, None]];
  reason = Which[
    sl === $Failed, "the run has no current slice",
    ! AssociationQ[spec], "not a degree job",
    status["Status"] =!= "done", "the job is " <> ToString[status["Status"]] <> If[StringQ[Lookup[status, "Message", None]], ": " <> status["Message"], ""],
    ! AssociationQ[deg], "the job has no degrees.m",
    deg["Status"] =!= "measured", "the degrees were not measured: " <> ToString[Lookup[deg, "Message", deg["Status"]]],
    ! AllTrue[deg["Columns"], IntegerQ], "the job kept masters the system lacks as extra columns: its rows are not on the slice's basis",
    which =!= "Base" && ! AssociationQ[var], "the job has no variant " <> ToString[which],
    which =!= "Base" && var["Status"] =!= "measured", "the variant " <> ToString[which] <> " was not measured: " <> ToString[Lookup[var, "Message", var["Status"]]],
    True, red = PFBReadRed[jd, 1];
      cal = If[AssociationQ[red], PFBCalibrate[sl, red], <|"Status" -> "no reduction", "Message" -> "red_1.m is missing"|>];
      If[cal["Status"] === "exact", None, "its reduction does not calibrate exactly against the current slice (" <> ToString[cal["Status"]] <> ": " <> ToString[cal["Message"]] <>
        "): it measured another basis or point; write the job again (PFBDegreesJob replaces it)"]];
  If[StringQ[reason], Return[<|"Keys" -> keys, "Reason" -> reason, "Sectors" -> <||>|>]];
  <|"Keys" -> keys, "Reason" -> None, "Sectors" -> sectorRecords[sys, sl,
     If[var === None, deg, Join[deg, <|"Entries" -> var["Entries"], "Rows" -> var["Rows"], "Seconds" -> Lookup[var, "Seconds", deg["Seconds"]]|>]], jd, spec,
     Lookup[status, "Seconds", Missing["NotRecorded"]]]|>];

PFBCollectDegrees[ctx_Association, jobDirs_List] := Module[{sys = ctx["System"], dir = ctx["Dir"], st = ctx["State"], sl, p, tab, st2},
  sl = PFBCurrentSlice[dir, st]; p = currentIndex[st];
  If[sl === $Failed || MissingQ[p], Print["PFBCollectDegrees: the run has no current slice."]; Return[$Failed]];
  tab = Replace[PFBReadDegrees[dir, st, p], _Missing :> newTable[sys, sl, st, p]];
  Do[Module[{r = PFBJobDegreeRecords[ctx, jd], keys},
     keys = r["Keys"];
     If[StringQ[r["Reason"]],
       Do[tab["Sectors"][k] = <|"Status" -> "not measured", "Reason" -> r["Reason"], "Job" -> FileNameTake[jd], "Date" -> PFBTimeStamp[]|>, {k, keys}];
       PFBPrint["degrees of ", StringRiffle[PFBSectorString /@ keys, ", "], ": not measured, ", r["Reason"]],
       tab["Sectors"] = Join[tab["Sectors"], r["Sectors"]]]], {jd, jobDirs}];
  tab["Summary"] = PFBDegreeSummary[tab];
  st2 = PFBStoreDegrees[dir, st, p, tab];
  <|"State" -> st2, "Table" -> tab, "File" -> FileNameJoin[{dir, degreesFile[st, p]}]|>];

PFBDegreeText[tab_Association] := Module[{s = Replace[Lookup[tab, "Summary", None], None :> PFBDegreeSummary[tab]], src = Lookup[Lookup[tab, "Provenance", <||>], "Source", "measured"]},
  StringJoin["kinematic degrees (", src, ", unit scale ", ToString[Lookup[tab, "UnitScale", "?"]], " = 1): ",
    If[s["Highest"] === None, "no non-zero entry measured",
      "highest " <> ToString[s["Highest"]] <> " (" <> ToString[s["Count"]] <> " of " <> ToString[s["Terms"]] <> " terms), sum " <> ToString[s["Sum"]] <>
       If[IntegerQ[s["Unexplained"]], ", unexplained denominator degree " <> ToString[s["Unexplained"]] <> " (at most " <> ToString[s["MaxUnexplained"]] <> " in one term)", ""]],
    "; sectors measured ", ToString[s["Measured"]], " of ", ToString[s["Sectors"]],
    If[s["NotMeasured"] === {}, "", " (not measured: " <> StringRiffle[PFBSectorString /@ s["NotMeasured"], ", "] <> ")"],
    With[{np = Union @@ Lookup[Values[Lookup[tab, "Sectors", <||>]], "NonPolynomial", {}]}, If[np === {}, "",
      "; not probed (no rational function of the invariants): " <> StringRiffle[ToString[#, InputForm] & /@ np, ", "]]]]];


(* ::Section:: *)
(*Degrees given with an imported slice*)


pairQ[x_] := MatchQ[x, {_Integer?NonNegative, _Integer?NonNegative}];
zeroQ[x_] := MatchQ[x, 0 | None | Null | <||>];

PFBImportDegrees[sys_Association, sl_Association, conv_Association] := Module[{f = conv["Degrees"], raw, nk = Length[sl["R"]], n = Length[sl["Labels"]], errs = {}, warns = {},
    ents = {}, err, tab, keys, byKey},
  If[StringQ[f] && ! StringStartsQ[f, "/"], f = FileNameJoin[{conv["Dir"], f}]];
  If[! StringQ[f] || ! FileExistsQ[f], Return[<|"Status" -> "refused", "Errors" -> {"the degrees file " <> ToString[f] <> " does not exist"}, "Warnings" -> {}|>]];
  raw = Quiet@Get[f];
  If[TrueQ[conv["Transpose"]] && ArrayQ[raw, 3], raw = Transpose /@ raw];
  If[! (ListQ[raw] && Length[raw] == nk && AllTrue[raw, MatrixQ[#, True &] && Dimensions[#] == {n, n} &]),
    Return[<|"Status" -> "refused", "Errors" -> {"the degrees file must hold one " <> ToString[n] <> " x " <> ToString[n] <> " matrix per derivative (" <> ToString[nk] <>
       "), in the slice's layout; it has dimensions " <> ToString[Dimensions[raw]]}, "Warnings" -> {}|>]];
  err[k_, r_, c_, m_] := AppendTo[errs, "derivative " <> ToString[sl["Derivatives"][[k]]] <> ", row ut[" <> ToString[sl["Labels"][[r]]] <> "], column ut[" <> ToString[sl["Labels"][[c]]] <> "]: " <> m];
  Do[Module[{v = sl["R"][[k, r, c]], d = raw[[k, r, c]], rg, pw},
     Which[
       v === 0 && zeroQ[d], Null,
       v === 0, err[k, r, c, "degrees given for an entry that is 0 in the slice"],
       zeroQ[d], err[k, r, c, "no degrees for an entry that is not 0"],
       ! AssociationQ[d], err[k, r, c, "not an Association"],
       KeyExistsQ[d, "Whole"],
         If[Length[d] == 1 && pairQ[d["Whole"]],
           AppendTo[ents, <|"Matrix" -> k, "Derivative" -> sl["Derivatives"][[k]], "Row" -> sl["Labels"][[r]], "Column" -> sl["Labels"][[c]],
             "Eps" -> With[{g = PFBEpsRange[v]}, If[g === "pole", {"Whole", "finite poles"}, {"Whole", "given whole"}]],
             "Terms" -> {<|"Power" -> "whole", "Num" -> d["Whole"][[1]], "Den" -> d["Whole"][[2]], "VarDegrees" -> Missing["NotGiven"], "NumLetters" -> Missing["NotGiven"],
               "DenLetters" -> Missing["NotGiven"], "NumUnexplained" -> Missing["NotGiven"], "DenUnexplained" -> Missing["NotGiven"]|>}|>],
           err[k, r, c, "\"Whole\" must be the only key, with {numerator degree, denominator degree} (non-negative integers)"]],
       AllTrue[Keys[d], IntegerQ] && AllTrue[Values[d], pairQ],
         rg = PFBEpsRange[v];
         If[rg === "pole", err[k, r, c, "degrees per power of eps for an entry with finite poles in eps: give it as <|\"Whole\" -> {num, den}|>"],
           pw = Select[Range[rg[[1]], rg[[2]]], Together[SeriesCoefficient[v, {eps, 0, #}]] =!= 0 &];
           If[Complement[pw, Keys[d]] =!= {}, err[k, r, c, "no degrees for the powers of eps " <> ToString[Complement[pw, Keys[d]]] <> " that the entry has"],
             If[Complement[Keys[d], pw] =!= {}, AppendTo[warns, "derivative " <> ToString[sl["Derivatives"][[k]]] <> ", row ut[" <> ToString[sl["Labels"][[r]]] <> "], column ut[" <>
                 ToString[sl["Labels"][[c]]] <> "]: degrees for powers of eps " <> ToString[Complement[Keys[d], pw]] <> " whose coefficient is 0 at the slice point"]];
             AppendTo[ents, <|"Matrix" -> k, "Derivative" -> sl["Derivatives"][[k]], "Row" -> sl["Labels"][[r]], "Column" -> sl["Labels"][[c]], "Eps" -> {"Laurent", rg[[1]], rg[[2]]},
               "Terms" -> Table[<|"Power" -> p, "Num" -> d[p][[1]], "Den" -> d[p][[2]], "VarDegrees" -> Missing["NotGiven"], "NumLetters" -> Missing["NotGiven"],
                 "DenLetters" -> Missing["NotGiven"], "NumUnexplained" -> Missing["NotGiven"], "DenUnexplained" -> Missing["NotGiven"]|>, {p, Sort[Keys[d]]}]|>]]],
       True, err[k, r, c, "the keys must be powers of eps (integers) or \"Whole\", the values {numerator degree, denominator degree} (non-negative integers)"]]],
    {k, nk}, {r, n}, {c, n}];
  If[conv["Frame"] =!= "RootFree", AppendTo[warns, "the slice's frame is " <> ToString[conv["Frame"]] <> ": the degrees are those of the file's entries, which differ from the root-free frame's between masters with different square roots"]];
  If[errs =!= {}, Return[<|"Status" -> "refused", "Errors" -> Take[errs, UpTo[20]], "ErrorCount" -> Length[errs], "Warnings" -> warns|>]];
  keys = Select[PFBSectorKeys[sys], Intersection[PFBSectorMasters[sys, #], sl["Labels"]] =!= {} &];
  byKey = GroupBy[ents, PFBMaster[sys, #["Row"]]["SectorKey"] &];
  tab = <|"Slice" -> Missing["NotStored"], "Point" -> sl["Point"], "Derivatives" -> sl["Derivatives"], "UnitScale" -> PFBUnitScale[sys], "Vars" -> DeleteCases[sys["Invariants"], PFBUnitScale[sys]],
    "Keys" -> keys, "Sectors" -> Association[Table[k -> <|"Status" -> "measured", "Source" -> "user", "Rows" -> Intersection[PFBSectorMasters[sys, k], sl["Labels"]],
        "Entries" -> Lookup[byKey, Key[k], {}], "Summary" -> PFBDegreeSummary[Lookup[byKey, Key[k], {}]]|>, {k, keys}]],
    "Provenance" -> <|"Source" -> "user", "File" -> f, "Frame" -> conv["Frame"], "Date" -> PFBTimeStamp[]|>, "Date" -> PFBTimeStamp[]|>;
  tab["Summary"] = PFBDegreeSummary[tab];
  <|"Status" -> "ok", "Errors" -> {}, "Warnings" -> warns, "Table" -> tab|>];


(* ::Section:: *)
(*det T of a recorded change along a line*)


findChange[st_, id_] := SelectFirst[Join[Lookup[st, "Accepted", {}], Lookup[st, "Pending", {}], Lookup[st, "Rejected", {}]], #["Id"] == id &, None];

PFBDetLineJob[ctx_Association, id_Integer, opts_Association : <||>] := Module[{sys = ctx["System"], dir = ctx["Dir"], st = ctx["State"], run = ctx["Run"], rec, key, fam,
    sys0, sysB, labs, changed, expand, old, new, cur, us, xs, p0, v, e0, ints, sl},
  rec = findChange[st, id];
  If[rec === None, Print["PFBDetLineJob: no recorded change ", id, "."]; Return[$Failed]];
  key = rec["Key"];
  (* a simplification has no key: the sector of the masters it replaced (a swap, a completion, a shift), or the one
     opts "Key" names when it changed masters of several sectors (a rescaling by letters) *)
  If[key === None, Module[{ks = PFBChangeKeys[sys, rec]},
    key = Which[
      ks === {}, Print["PFBDetLineJob: change ", id, " is a rescale; its det T is a power of eps."]; Return[$Failed],
      ListQ[Lookup[opts, "Key", None]] && MemberQ[ks, opts["Key"]], opts["Key"],
      ListQ[Lookup[opts, "Key", None]], Print["PFBDetLineJob: change ", id, " replaced no master of ", PFBSectorString[opts["Key"]], " (its sectors: ",
        StringRiffle[PFBSectorString /@ ks, ", "], ")."]; Return[$Failed],
      Length[ks] == 1, First[ks],
      True, Print["PFBDetLineJob: change ", id, " replaced masters of ", Length[ks], " sectors (", StringRiffle[PFBSectorString /@ ks, ", "],
        "): name one (opts \"Key\", det_line.wls --sector fam/jPATTERN)."]; Return[$Failed]]]];
  fam = key[[1]];
  (* the basis just before the change: the accepted changes recorded before it *)
  sys0 = PFBReadSystem[run["System"]];
  If[sys0 === $Failed, Return[$Failed]];
  sysB = PFBApplyAccepted[sys0, <|"Accepted" -> Select[st["Accepted"], #["Id"] < id &]|>];
  labs = Select[PFBSectorMasters[sysB, key], PFBMaster[sysB, #]["Family"] === fam &];
  changed = Intersection[rec["Replace"], labs];
  If[changed === {}, Print["PFBDetLineJob: change ", id, " replaces no master of ", fam, " in ", PFBSectorString[key], "."]; Return[$Failed]];
  expand[x_] := FixedPoint[(# /. ut[k_Integer] :> PFBMaster[sysB, k]["RootFree"]) &, x, 20];
  old = Table[expand[PFBMaster[sysB, l]["RootFree"]], {l, labs}];
  new = Table[If[MemberQ[changed, labs[[i]]], expand[Last[PFBRootMonomial[sysB, rec["NewDefs"][labs[[i]]]]]], old[[i]]], {i, Length[labs]}];
  If[! FreeQ[{old, new}, _ut], Print["PFBDetLineJob: the definitions still refer to masters after expansion."]; Return[$Failed]];
  cur = Select[PFBSectorMasters[sys, key], PFBMaster[sys, #]["Family"] === fam &];
  us = PFBUnitScale[sys]; xs = DeleteCases[sys["Invariants"], us];
  If[xs === {}, Print["PFBDetLineJob: no invariant is left once the unit scale is 1: there is no line."]; Return[$Failed]];
  {p0, v, e0} = BlockRandom[{RandomPrime[{10^3, 10^5}, Length[xs]], RandomChoice[{-1, 1}, Length[xs]] RandomInteger[{1, 9}, Length[xs]],
     RandomPrime[{100, 1000}]/RandomPrime[{1000, 10000}]}, RandomSeeding -> 1000 + id];
  p0 = Replace[Lookup[opts, "Base", Automatic], {Automatic -> p0, r_List :> (xs /. r)}];
  v = Replace[Lookup[opts, "Direction", Automatic], {Automatic -> v, r_List :> (xs /. r)}];
  e0 = Lookup[opts, "Eps", e0];
  ints = Union[Cases[{Join[old, new] /. Dinv[a_, _] :> a}, _j, Infinity]];
  sl = PFBCurrentSlice[dir, st];
  PFBSubtreeJob[sys, dir, <|"Name" -> Lookup[opts, "Name", "detline_" <> ToString[id]], "SectorKey" -> key, "Roots" -> {{fam, key[[2]]}}, "Points" -> {Join[Thread[xs -> p0], {us -> 1}]},
    "Derivatives" -> If[sl === $Failed, xs, sl["Derivatives"]], "Seeds" -> run["Seeds"], "Pool" -> ints, "PoolExtra" -> {}, "PoolDerivatives" -> ! FreeQ[{old, new}, Dinv],
    "Focus" -> {}, "Line" -> <|"Change" -> id, "Key" -> key, "Labels" -> labs, "Changed" -> changed, "Exprs" -> Join[old, new], "Masters" -> (ut /@ cur),
      "Base" -> Thread[xs -> p0], "Direction" -> Thread[xs -> v], "Eps" -> e0, "Fix" -> {us -> 1}|>,
    "MaxGB" -> run["MaxGB"], "TimeLimit" -> run["TimeLimit"], "Threads" -> Replace[run["Threads"], Automatic -> Max[1, Min[8, $ProcessorCount - 1]]],
    "ReuseIds" -> Lookup[opts, "ReuseIds", None], "Replace" -> True|>]];

monicIn[f_, tau_] := Expand[f/Coefficient[f, tau, Exponent[f, tau]]];

PFBDetLineAnalysis[det_, probes_List, base_List, dir_List, tau_Symbol] := Module[{xs = base[[All, 1]], line, known, fl, facs, sp},
  line = Thread[xs -> (xs /. base) + tau (xs /. dir)];
  known = Flatten[Table[{monicIn[#[[1]], tau], l} & /@ Select[FactorList[Expand[l /. line]], ! FreeQ[#[[1]], tau] &], {l, probes}], 1];
  fl = Select[FactorList[Factor[Together[det]]], ! FreeQ[#[[1]], tau] &];
  facs = Table[With[{f = monicIn[x[[1]], tau]}, <|"Factor" -> f, "Power" -> x[[2]], "Degree" -> Exponent[f, tau], "Known" -> DeleteDuplicates[Cases[known, {f, l_} :> l]]|>], {x, fl}];
  sp = Select[facs, #["Known"] === {} &];
  <|"Det" -> Factor[Together[det]], "Factors" -> facs, "Spurious" -> sp, "SpuriousDegree" -> Total[Abs[#["Power"]] #["Degree"] & /@ sp], "Variable" -> tau, "Line" -> line|>];

PFBDetLineReport[ctx_Association, id_Integer, opts_Association : <||>] := Module[{dir = ctx["Dir"], sys = ctx["System"], jd, st, ln, n, co, tau, dO, det, probes, an, key},
  jd = FileNameJoin[{dir, "jobs", Lookup[opts, "Name", "detline_" <> ToString[id]]}];
  st = PFBSubtreeStatus[jd];
  If[st["Status"] =!= "done", Return["the line job " <> FileNameTake[jd] <> " is " <> ToString[st["Status"]] <> If[StringQ[Lookup[st, "Message", None]], ": " <> st["Message"], ""]]];
  ln = Quiet@Get[FileNameJoin[{jd, "line.m"}]];
  If[! AssociationQ[ln] || ln["Status"] =!= "done", Return["the line job has no result (line.m)"]];
  n = Length[ln["Labels"]]; co = ln["Coefficients"]; tau = ln["Variable"]; key = ln["Key"];
  dO = Together[Det[co[[1 ;; n]]]];
  If[dO === 0, Return["the old masters are not a basis of the maximal cut along the line (their determinant on the current masters is 0)"]];
  det = Together[Det[co[[n + 1 ;; 2 n]]]/dO];
  If[det === 0, Return["the new masters are not a basis of the maximal cut along the line (det T = 0)"]];
  probes = PFBDegreeProbes[sys, dir, {key[[1]]}]["Probes"];
  an = Join[PFBDetLineAnalysis[det, probes, ln["Base"], ln["Direction"], tau], <|"Change" -> id, "Key" -> key, "Changed" -> ln["Changed"], "Eps" -> ln["Eps"], "Fix" -> ln["Fix"],
     "Check" -> ln["Check"], "Probes" -> probes, "Job" -> jd, "Date" -> PFBTimeStamp[]|>];
  Put[an, FileNameJoin[{jd, "detline.m"}]];
  an];

powText[f_] := ToString[f["Factor"], InputForm] <> If[f["Power"] == 1, "", "^" <> ToString[f["Power"]]];
PFBDetLineText[an_Association] := StringJoin["det T of change ", ToString[Lookup[an, "Change", "?"]], " along the line (", ToString[an["Variable"]], ", eps = ", ToString[Lookup[an, "Eps", "?"], InputForm],
  "): ", ToString[Length[an["Factors"]]], " factor(s); ",
  If[an["Spurious"] === {}, "every factor is a known singularity on the line",
    ToString[Length[an["Spurious"]]] <> " spurious (no known singularity), total degree " <> ToString[an["SpuriousDegree"]] <> ": " <>
     StringRiffle[powText /@ an["Spurious"], ", "]],
  If[an["Factors"] =!= an["Spurious"], "; known: " <> StringRiffle[(powText[#] <> " (" <> StringRiffle[ToString[#, InputForm] & /@ #["Known"], ", "] <> ")") & /@
      Select[an["Factors"], #["Known"] =!= {} &], ", "], ""]];


End[];
EndPackage[];
