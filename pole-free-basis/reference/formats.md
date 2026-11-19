# Formats

Every input is a Mathematica file that evaluates to an Association. Paths inside a file are relative to it.
The templates are in `templates/`.

## system.wl

The families, their masters, and how the masters are numbered in the differential equation.

```mathematica
<|
 "Name" -> "two-loop example",
 "Families" -> {
   <|"Name" -> "fam1", "Family" -> "families/fam1.wl", "Masters" -> "masters/fam1.m",
     "Prefactors" -> "masters/fam1_roots.m",           (* optional: a list multiplying the masters one by one *)
     "Rules" -> {FFG -> j, j[a_, {b__}] :> j[a, b]},   (* optional: applied in turn, to bring the file to j[fam, a1, ..., aN] *)
     "ISPs" -> {8, 9},                                 (* optional: found from the masters when left out *)
     "LettersFromSOFIA" -> True,                       (* optional, only after the user's yes: SOFIA's polynomials are this family's letters *)
     "MCBRun" -> "mcb/fam1_analysis"|>,                (* optional: the maximal-cut-basis run folder that produced the masters; read only *)
   <|"Name" -> "fam1x12", "ImageOf" -> "fam1", "MomentumMap" -> {p1 -> p2, p2 -> p1}|>,
   ...},
 "LoadOrder" -> Automatic,           (* order of the definitions for LiteRed: the order of "Families" *)
 "MasterOrder" -> "Join",            (* "Join", "ReverseJoin" or {{fam, pos}, ...} *)
 "Roots" -> "roots.m",               (* {r1 -> Sqrt[...], ...}, or the list itself *)
 "SymmetryRules" -> "rules.m",       (* optional: j[...] -> combination, identities LiteRed misses (FIRE-style) *)
 "Frozen" -> {"fam2"},               (* families whose masters must not change *)
 "Letters" -> "letters.m"            (* optional: the alphabet, a list of polynomials in the invariants *)
|>
```

- **Base families** are `family.wl` files in the maximal-cut-basis format (its `reference/formats.md`). Every
  family must share the loop momenta, the external momenta and the scalar products, so LiteRed can find the
  maps between them. `bin/import_liteibp.wls` writes these files from a LiteRed/LiteIBP families file.
- **Image families** are a base family with its external momenta exchanged. Their propagators, masters,
  invariant map (for example `t -> 2 m2 + qq - s - t`) and roots follow from `"MomentumMap"`. A given
  `"InvariantMap"` is checked against the implied one. Roots are renamed with `"RootSuffix"` (default: the image
  name minus the base name, `x12`) unless `"RootMap"` says otherwise; images with the same suffix share root
  symbols. Give an image its own `"Masters"` only when its masters are not the mapped ones. A change of a base
  master carries over to the image master whose definition is the mapped one up to a constant factor, which it keeps.
- **Masters files** evaluate to a (possibly nested) list. Each element is one master:
  `eps^k root (Sum c j[...])`, where `root` is a product of root symbols (or explicit `Sqrt[...]`, matched to
  `"Roots"`; unknown radicands get new symbols `rPFB1, ...` and a warning). `Dinv[expr, x]` is the derivative of
  `expr` with respect to the invariant `x`. The roots must be an overall factor of each master.
- **Labels.** The masters of all families, in `"MasterOrder"`, are `ut[1], ut[2], ...`. These labels are the rows
  and columns of every slice. `"ReverseJoin"` is the order of a pipeline that reverses the joined list.
- **Sectors.** A master belongs to the largest sector among its integrals; images share the sector key
  `{base family, sector}` of their base. `PFBSectorKeys` lists the keys bottom-up.
- **`"MCBRun"`.** Optional, base families only: the maximal-cut-basis run folder (the one with its `run_info.m`) that
  produced the family's masters, relative to `system.wl`. It is only read, never written into. Rung 8 reads its sector
  bases, candidate steps, points and Picard-Fuchs labels; the simplification phase reads the rational elements of each
  sector (`j<pattern>/masters.m` and `basis.m`, normalisation `"rational"`) as its first rescalings
  (`PFBMCBNormalisations`, `reference/simplify.md`). `PFBReadSystem` resolves the path once (the family's `"MCBRun"`
  in the system object, which both read), and the validation checks that it is a run of the same family (name,
  propagators, kinematics). Without it, rung 8 makes this skill's own run in `<run>/maxcut/<fam>/`, and the phase
  takes no normalisations.
- **Letters.** Optional. The alphabet is this list, the `"Letters"` of the base families' `family.wl`, SOFIA's
  polynomials of the base families whose entry has `"LettersFromSOFIA" -> True`, and their images under the
  invariant maps (`PFBLetters`). With an alphabet, the gate requires every denominator factor of a new master's
  coefficients to be a letter up to a constant; without one, there is no letter check.
- **LettersFromSOFIA.** Optional, `True` or `False`, on a base family (its images follow). `True` makes the
  polynomials of the run's `singularities/<fam>.m` (`bin/singularities.wls`) letters of the family. Set it only
  after the user said yes: the validation and the census offer the polynomials to a family without letters, and
  nothing uses them as letters before the key is set. `PFBStartRun` reads the cache; when the run has no usable
  cache, it prints a line and the family has no SOFIA letters.

## conventions.wl

How an external slice was written. Nothing in it is trusted until the calibration agrees exactly.

```mathematica
<| "File" -> "slice.m",                         (* Get gives {A_x1, A_x2, ...} *)
   "Derivatives" -> {s, t, qq},                 (* the invariant of each matrix *)
   "Point" -> {s -> 1423, t -> 1637, qq -> 7681, m2 -> 6229},   (* every invariant *)
   "Labels" -> "masters.m",                     (* rows/columns: All, {ut[3], ut[5], ...}, or a file with that list *)
   "Frame" -> "RootSymbols",                    (* "RootFree" | "RootSymbols" | "Rational" *)
   "RootValues" -> {r1 -> 5233, ...},           (* "RootSymbols" only *)
   "RootOrder" -> Automatic,                    (* "RootSymbols" only: definitions in the producer's matching order *)
   "Transpose" -> False, "Rules" -> {},         (* Rules: applied to the matrices as read, before "Transpose" *)
   "Degrees" -> "degrees.m",                    (* optional: the kinematic degrees of the slice's entries, below *)
   "Credits" -> {"kira", <|"reference" -> "...", "used" -> "..."|>} |>   (* optional: what produced the DE, below *)
```

| frame | the entry (r, c) of the file is |
|---|---|
| `RootFree` | R_rc: masters without their square roots, `dlog(root)` on the diagonal |
| `RootSymbols` | R_rc pref_r² / (mono_r mono_c): the producer treated each square root as a variable with the value `RootValues`; pref_r² is evaluated at the point, the root monomials at `RootValues`, each `Sqrt[...]` matched to the first symbol of `"RootOrder"` with that radicand |
| `Rational` | A_rc = R_rc pref_r / pref_c, for prefactors rational at the point |

**`"Degrees"`** (optional) names a file with the kinematic degrees of the DE the slice comes from (`reference/workflow.md`,
"Kinematic degrees"), in the slice's layout: `Get` gives one matrix per derivative, rows and columns as in the slice
(`"Transpose"` applies to it too). Each entry is `0` for an entry that is 0, `<|p -> {num, den}, ...|>` with the total
degrees of the numerator and the denominator of the coefficient of ε^p (unit scale set to 1) for an entry that is a
Laurent polynomial in ε, every power it has at the slice point given, or `<|"Whole" -> {num, den}|>` for the whole
entry at a generic ε, required for an entry with finite poles in ε. The degrees are those of the file's own entries:
in a frame other than `RootFree`, entries between masters with different square roots differ from the root-free
ones. The import refuses a file that does not fit the slice, and with it the slice; accepted, it is stored with the
slice as `degrees/degrees_NNN.m`, provenance `"user"`, without letter content.

**`"Credits"`** (optional) names what produced the DE the slice comes from, which the skill did not make: tools by
their names in the registry of `core/lib/Core/Tools.wl` (`"kira"`, `"fer64"`, `"FiniteFlow"`, `"LiteRed"`,
`"LiteIBP"`, ...; any case, or the display name such as `"Kira"`) and papers as `<|"reference" -> "authors, title, arXiv:...", "used" -> "..."|>` (`"used"` defaults
to "the starting differential equation"). `bin/import_slice.wls` records them in the run's ledger for the whole run,
step "the starting DE" (`PFBRecordSliceCredits`), and `CITATIONS.md` lists them under "Cite". A name that is not in
the registry, or an entry that is neither, refuses the import. `CITATIONS.md` always says that the starting DE came
from outside the skill, and that what produced it is to be cited by hand when `"Credits"` does not name it.

## run.wl

```mathematica
<| "System" -> "system.wl", "Slice" -> <|"Conventions" -> "conventions.wl"|>,
   "OutputDir" -> Automatic,      (* <this folder>/<Name>_poles; /tmp is refused unless "AllowTmp" -> True *)
   "Name" -> Automatic,           (* Automatic: the system file's name without .wl, so system.wl gives system_poles *)
   "Approval" -> False,           (* True: changes that pass the gate wait for the user *)
   "Target" -> "PoleFree",        (* or "EpsForm": the completion solver also asks for eps^1 *)
   "MaxEpsDegree" -> 2,           (* the cap: entries above eps^2 are bad entries, and no change may raise one above it;
                                     an integer >= 1, or Infinity: no cap. Raise it only with the user's agreement *)
   "ExtraPoints" -> 2,            (* points of the fits besides the slice point; reductions add two more for the gate *)
   "Seeds" -> <|"Rank" -> 3, "Dots" -> 2|>,
   "Reducer" -> Automatic,        (* the slice point of a job: Kira when Kira and Fermat are found and the subtree lies in
                                     one family, else FiniteFlow; "Kira" or "FiniteFlow" forces one (reference/workflow.md) *)
   "MaxGB" -> None, "TimeLimit" -> 86400, "Threads" -> Automatic, "Paths" -> Automatic,
   "SimplifyBudget" -> Automatic,  (* the simplification phase: wall-clock seconds of its moves' degree jobs; Automatic:
                                     the phase proposes a budget and waits for the user's answer (bin/simplify.wls --budget) *)
   "TargetKinDegree" -> None,      (* the phase stops once the highest kinematic degree is at or below it *)
   "SimplifyMoves" -> All |>       (* or a list of the phase's moves to run: "rescale", "swap", "shift", "completion" *)
   (* MaxGB: cap on a reduction kernel, also its memory limit under bin/ws (None: bin/ws's default);
      TimeLimit: seconds a reduction job may run, 0 = none; both go to job.m, and PFBSubtreeCommand passes them to bin/ws *)
```

`paths.wl` is the maximal-cut-basis file (`templates/paths.wl`): FiniteFlow, FiniteFlowLibrary, LiteRed and
LiteIBP are the tools reductions need. The optional `"SOFIA"` is the path of SOFIA's `scr.m` (`reference/tools.md`).
With `"Paths" -> Automatic`, a `paths.wl` next to `run.wl` is used when there is one.

## Objects in memory

- **System** (`PFBReadSystem`): `"Order"`, `"Families"` (each with its maximal-cut-basis family object and, for
  images, the maps), `"RootDefs"`, `"MasterRecords"`; from `PFBStartRun` also `"SOFIALetters"` (family → SOFIA's
  polynomials accepted as letters) and `"SOFIALettersMissing"`. A master record has `Label`, `Family`, `Base`, `Pos`,
  `Def` (as written), `Mono` (root monomial), `Pref` (with the square roots), `RootFree` (roots set to 1),
  `Sector`, `SectorKey`, `Integrals`, and after a change `Changed`, `OldDef`.
- **Slice** (`PFBImportSlice`, `PFBLoadSlice`): `"R"` (one matrix per derivative, root-free frame, exact in ε),
  `"Derivatives"`, `"Point"`, `"Labels"`, `"Index"` (label → row), `"History"` (every change applied, with
  `DetT`).
- **Census** (`PFBCensus`): `"BadEntries"` `{k, r, c, factors}`, `"BadRows"`, `"EpsZero"` `{k, r, c, lo}` (every entry with a pole at ε = 0, also those with finite poles),
  `"Profile"` (`{lo, hi}` → count), `"PoleFactors"`, `"MaxDegree"` (the highest power of ε of the entries without
  finite poles), `"HighDegree"` `{k, r, c, power}` (entries above the cap: bad entries), `"HighRows"`, `"DegreeCap"`,
  `"Sectors"` (per key: `Rows`, `Issues` (finite poles, negative powers of ε, above the cap), `BadRows` (finite
  poles), `SelfBlockEpsZero` (own-block columns with negative powers of ε), `HighRows`, `HighColumns`, `SelfBlockHigh`, `PoleColumns`,
  `SelfBlockPoles`, `PoleFactors`, `EpsZeroRows`, `CouplesToBadLower`, `PossiblyInherited`, `PossibleHiddenWeight`
  (factors this clean sector may carry), `HiddenWeightBelow` (`<|w -> S|>`: factors of these rows that a clean
  lower sector S may carry)), `"BadSectors"` (bottom-up), `"HiddenWeights"` (`<|"Factor", "Sector", "Columns",
  "Masters", "Rows", "Sectors", "Tried"|>` per hint: the clean sector, the columns with the factor, those that are its
  masters, the rows and sectors where it shows, whether its lower-sector scan was recorded, and for a sector fixed by
  accepted changes `"Reopens"`, their ids), `"Next"`.
- **Reduction** (`PFBReadRed`, one per point): `"Masters"` (subtree masters, `ut[k]` or non-ut `j`), `"Labels"`,
  `"Point"`, `"Focus"`, `"Dm"` (`Dm[[k, i]]` = (1/pref) d_k (pref U) of focus master i on the masters), `"Pool"`,
  `"Rp"`, `"dRp"`, `"Invariants"`, `"Roots"`, `"Allowed"`, `"Reducer"` (`"Kira"` or `"FiniteFlow"`; absent in a
  reduction written before 2026-10-16, which is FiniteFlow's). Both reducers give the same keys and the same values.
- **Change** (`PFBChangeVectors`): `"Replace"`, `"H"` (new masters on the old root-free basis, at the slice
  point), `"G"` (their rows), `"NewDefs"`, `"Prefs"`.

## The run folder

| path | content |
|---|---|
| `state.m` | the run: `Run` (the `run.wl`), `Created`, slices in order (each with `File`, `Census`, `Label`, `Date`, the census counts and, once its degrees are measured or given, `Degrees` (the file), `DegreeSummary` and `DegreeSource`), `Current`, `Censuses` (their census files), `Accepted`, `Pending`, `Rejected`, `Flagged` (per sector `Reason`, `Tried`, `Date`, `HiddenWeight`: the hidden-weight test at the flag, `Forced`), `Approval`, `Regenerated` |
| `slices/slice_NNN.mx`, `census_NNN.m` | every current slice and its census; `pending_<id>.mx` and `pending_<id>_census.m` while a change waits for approval |
| `degrees/degrees_NNN.m` | the kinematic degrees of slice NNN (below): `bin/degrees.wls --collect`, the local slice, or the user's `"Degrees"` |
| `jobs/<name>/` | reduction jobs: `job.m`, `system.m`, `families.wl`, `command.sh`, `run.log`, `status.m`, `times.m`, `red_<ip>.m`, and `kira.log` when Kira reduced the slice point (`kira_fallback.m`, the reason, when Kira gave no reduction of it: later runs of the job skip Kira); while the sector is open also the scratch (`ibps*/`, `system.json`, `nonut.m`, `memory.m`, `kira/` when Kira gave no reduction, and `raw_<ip>.m` once extra masters were removed), which `PFBCleanJob` deletes when it is done. A job with extra masters may also hold `relation_trials.m`, `relation_command.sh` and `relation.m` (`bin/relation_sector.wls`); its expansion job is `jobs/<name>_x/`, its trials `jobs/<name>_rel<k>/`. An analytic job is `jobs/<name>_a/` (`bin/coefficients.wls`), a maximal-cut scan's job `jobs/<fam>_<jPATTERN>_maxcut/` (`bin/maxcut_candidates.wls`), the local slice's job `jobs/local_slice/`. A job with `"Degrees"` also holds `degrees.m`, one with `"Line"` `line.m` and, once collected, `detline.m` (below). Degree jobs are `jobs/deg_<fam>_<jPATTERN>/` (their command for all sectors `jobs/degrees_command.sh`), line jobs `jobs/detline_<id>/` |
| `<fam>/<jPATTERN>/` | per sector: `basis.m`, `masters.m`, `attempts.m` (below), `notes.md`, `sector.html`, `AnalysisPoles.m`; for rung 8 `maxcut_candidates.m` (`PFBMaxCutCandidates`: `Candidates`, each with `Label`, `Source`, `Provenance`, `Defs` (slot → root-free definition), `Integrals`, `Dotted`; `Dropped` with `Reasons`; `Slots`, `MCBRun`, the run sector's `Status` and `Classification`) and `maxcut_finalists.m` (the ranked finalists: `Rank`, `Defs`, `Verdict` of `PFBMaxCutCheck`, `Result` of the scan, `Clears`, `Refused`, `NotChecked` (Kira failed: `Verdict` `ToolFailure`), `TieBreak`) |
| `maxcut/<fam>/` | this skill's own maximal-cut-basis run of a family without `"MCBRun"`: `run.wl` (maximal-cut-basis's scripts take it) and `run_info.m` |
| `export/<fam>.m` | a drop-in replacement for the family's masters file: the same order and the same `"Rules"` and `"Prefactors"` in `system.wl`; unchanged entries as written there, changed ones (commented) in the `j[fam, ...]` form with the prefactor divided out, your root symbols, and `Sqrt[...]` for radicands without one. Every family with its own masters file and a changed master, images included |
| `CHANGES.md` | every change, why and how, what is not verified, and "Credits": the tools, methods and papers to cite (the "Cite" part of `CITATIONS.md`) |
| `summary.html` | maximal-cut changes first, census history, sectors, what to cite and the papers only consulted |
| `citations.m`, `CITATIONS.md` | the run's ledger: every use of a tool, a method or a paper, with its sector (`fam/jPATTERN` or "whole run"), step and outcome (the core's format: `core/README.md`, "Citations", and the maximal-cut-basis `reference/formats.md`); and what to cite, written from it: "Cite" (every tool and method that ran, every paper behind the final basis) and "Also consulted" (the papers of changes rejected, declined, not tried or not in the final basis, with the outcome), papers grouped by arXiv id or DOI. An older run's `literature.m` is read in |
| `run_info.m` | settings, resources, memory model, tool paths of the session |
| `simplify/phase.m` | the simplification phase (`bin/simplify.wls`, `reference/simplify.md`, "Records and reports"): its census jobs, its start (after the pole-free work), the budget, the time spent, every move with its candidates (predicted and measured objectives), the change it led to and the gate's message; `simplify/move_<id>_degrees.m` holds the measured degree table of a move waiting for approval. Its degree jobs are `jobs/simp<id>_<fam>_<jPATTERN>/` (the census `jobs/deg_<fam>_<jPATTERN>/`), a move's own jobs `jobs/simp<id>_<what>_<fam>_<jPATTERN>/` (move (ii)'s reduction to scan: `scan`; move (iii)'s samples: `fit`; move (iv)'s: `comp`), their command `jobs/simplify_command.sh` |
| `singularities/<fam>.m`, `<fam>.log` | per base family: SOFIA's candidate singularities in the family's invariants, with their provenance (below), and SOFIA's output (`bin/singularities.wls`) |

### Change records

`state.m`'s `Accepted`, `Pending` and `Rejected` hold one record per change: `Id`, `Key` (the sector, or `None` for a
rescale of rung 1 and for a simplification of several sectors), `Name`, `Kind`, `Replace`, `NewDefs`, `OldDefs`,
`Rung` and `RungName`, `Provenance`, `Determinant`, `MaxCutChanged`, the profiles, `Gate` (its checks), `Notes`,
`Date`; also `Shifts` (rung 1), `Sources`, `Residues`, `Completion`, `Fitted`, `PointsVerified`, `ImagesVerified`,
`Verification` and `MaxCutCheck` (the maximal-cut-basis gate's verdict, `PFBMaxCutSummary`). A pending change
also has `SliceFile` and `CensusFile` (its proposed slice and census in `slices/`) and `BaseSlice` (the slice it was
proposed on: it is approved only while that slice is current); an approved one has `Approved` (the date).
A simplification (`bin/simplify.wls`) has `"Rung" -> "simplify"` and `Simplify`: `MoveId` (in
`simplify/phase.m`), `Move`, `Title`, `Candidate`, `Rescalings` (label → r, for move (i)), `Before` and `After` (degree
summaries), `BeforeObjective`, `PredictedObjective`, `AfterObjective`, `Jobs`. A change the user declined
(`bin/approve.wls run.wl --decline id`, `PFBDecline`) is in `Rejected` with `Declined` (the date) and `DeclineReason`.
The sectors of a change are `PFBChangeKeys`: its `Key`, or those of the masters a simplification replaced.
The papers and the declared tools of a change (`PFBTryChange` info `"Reference"`, `"Used"`, `"Tools"`) are not in
the record: they go to the run's ledger for each sector of the change, the tools with step "declared", each paper
with `change` (the `Id`), `rung` and `result` (`accepted`, `pending` or `rejected`; `not tried`, without `change`,
with the reason as `outcome`). `PFBApprove` and `PFBDecline` append the later outcome, which the reader applies to
the change's papers.

### basis.m (sector record)

The maximal-cut-basis schema, extended: `status` (`pole-free`, `pole-free (maximal cut changed)`, `inherited`,
`open`, `flagged`, `not in slice` (its masters are eliminated from the slice)), `name`, `family`, `sector`, `id`, `images`, `masters` (`label`, `family`, `pos`,
`definition`, `oldDefinition`, `changed`, `epsPowers`, `provenance`), `badRows`, `poleFactors`,
`epsZeroRows`, `possiblyInherited`, `couplesToBadLower`, `possibleHiddenWeight` (the census's hints on this clean
sector: `factor`, `rows`, `columns`, `sectors`, `tried`), `hiddenWeightBelow` (hints on a clean lower sector for the
factors of these rows: `factor`, `sector`, `columns`, `tried`), `sources`, `residues`, `completion`, `maxCutChanged`,
`deferredHere` (poles deferred to this sector by accepted changes below it, while it still has bad rows; `Kind`
`moved` for moved poles, factors its rows had before, with their `Factors` and `Entries`),
`determinant` (per accepted change: det T, recorded, not judged), `determinantOnReference` (changes recorded by an
earlier version that judged the determinant on a reference basis), `maxCutCheck` (per accepted change that alters the
maximal cut: the maximal-cut-basis gate's verdict, `PFBMaxCutSummary`: `Status`, `Check`, `Range`, `Euler`, `AllDot`,
`Points`, `Tool`, `Text`, `Given` when a given verdict was not used, or `Skipped` with the reason), `verification`,
`profiles`, `provenance`, `flags`, `date`.

### attempts.m (per sector)

One association per line (`MCBAppendAttempt`): `date`, `rung`, `what`, `outcome`, and where they apply `leftover`
(the pole entries the attempt left in the sector's rows, `{row, column, factors}`: written by `PFBTryChange` and by
the scans through `PFBRecordScan`; the hidden-weight test reads them) and `hiddenWeight` (a lower-sector scan:
`Factors`, `Rows` above, `Before` and `Left` (entries with the factors in those rows before and after the best set),
`Clearing` (sets that clear them within the cap), `Sets`, `Best`, `Status`
`done`; a scan that could not run: `Factors`, `Rows`, `Status` (`no slots`, `too many`, `over budget`) and `Reason`).
A refused flag is recorded as `flag refused (the hidden-weight test)`.

### job.m of a job

`PFBSubtreeJob` writes it; the keys of `PFBSubtreeJob`'s `::usage` are the specification (points, seeds, roots, pool,
focus: changing one needs a new job or `"Replace" -> True`) or resources (threads, limits). `"SectorKey"`
(`{fam, sector}`, or `None` for the whole run) is the sector the runner credits the job's tools to in the run's
ledger. The reducer is a resource:
`"Reducer"` (Automatic, `"Kira"` or `"FiniteFlow"`; from the spec, else from `run.wl`; learn-only and analytic jobs
`"FiniteFlow"`; degree and line jobs Automatic, which their note resolves to FiniteFlow, and `"Kira"` is refused for
them), `"ReducerNote"` (the reducer
chosen for the slice point when the job was written, and why), `"Kira"` (`None`, or the configuration Kira needs:
`Family` (the family of the roots), `KiraFamily` (the family Kira reduces: the base of an image), `D0`, `InvariantMap`
(an image's, for its mapped point), `Names` (the invariants' names in Kira's files), `IntegralFamilies` and
`Kinematics` (the texts of Kira's `config/`, written by maximal-cut-basis; the top-level sectors are filled in when the
job runs)), and `"ToolPaths"` (FiniteFlow, its library, LiteRed, LiteIBP, `kira`, `fer64` and `limit`, core's
`bin/limit`; set them for another machine). The runner decides again when it runs, from the sectors the subtree
really holds.

### singularities/<fam>.m

Written by `bin/singularities.wls` (`PFBRunSingularities`), read through `PFBKnownSingularities`.

- `"Status"`: `done` (every top graph), `partial` (some), `timeout`, `failed`, `not applicable` (no graph SOFIA
  takes). `"Polynomials"`: the irreducible polynomials of the graphs that are done, in `"Invariants"` (the family's),
  each with coprime integer coefficients and a positive leading coefficient, up to constant factors
  (`PFBNormalizePolynomials`).
- `"Graphs"`: one record per top graph: `Sector`, `Name`, `Input` (SOFIA's input in its own notation:
  `{{{{a, b}, mass}, ...}, {{node, mass}, ...}}`, masses `0`, `Subscript[m, k]`, `Subscript[M, i]`), `Edges`, `Nodes`,
  `Lines` (the propagator of each edge), `Momenta` (entering each node), `Masses` (`"m<k>"` → mass²), `ExternalMasses`
  (`"M<i>"` → p²), `Loops`, `Source`, `Status` (`done`, `failed`, `timeout`, `not applicable`, `kinematics
  mismatch`), `Message`, `Seconds`, `Warnings` (SOFIA's warnings and the kernel's messages from the log); after a
  run also `Raw` (SOFIA's polynomials in its names, as strings), `Rename` (SOFIA's name → invariant expression),
  `Polynomials`, `Vanishing` (SOFIA's polynomials that vanish at the family's kinematics), `Unrenamed` (those with a
  name the renaming does not know, or not polynomial after it) and `KinematicsCheck` (`"agrees"`, `"not available"`, or the mismatches
  `{{i, j}, SOFIA's, the family's}`: SOFIA's conventions against the renaming), and, for a graph that was run,
  `SymanzikCheck` (`"agrees"`: the graph's Symanzik polynomials are the propagators'; a graph that does not agree is
  "not applicable" with the reason, `reference/workflow.md`, "Known singularities").
- Provenance: `"SOFIA"` (`Path`, `Version`, `Commit` of a git checkout of SOFIA, `Modified`, `Blob`, `Pinned`,
  `SHA256`), `"Options"`, `"TimeLimit"` (seconds per graph), `"Seconds"`, `"Warnings"`, `"Log"`, `"Date"`,
  `"Mathematica"`; `"GraphsDigest"` (a hash of the graphs and their renaming: when the current family gives another
  value, the cache is stale) and `"Digest"` (that hash with SOFIA's and the options: when a second run gives the
  same value, it keeps the cache).

### status.m of a job

Every status has `Date`, `Seconds` (since the kernel started), `PID` and `Host`, and, once the job has credited a
tool, `Tools` (`"kira"`, `"fer64"`, `"FiniteFlow"`, `"LiteRed"`, `"LiteIBP"`; every run's, as a rerun starts from the
earlier status). A job in `<run>/jobs/` of a
pole-free run (one with `state.m`) also appends them to the run's ledger; elsewhere `Tools` is the only record, which
the run's reader takes once the job is in its `jobs/` folder.
`"Status"`: `running` (`Phase`:
`kira` (the slice point, with `Point` and `Of`), `identities`, `learning`, `reconstructing` with `Point`, `Of`
and `Kept`, and `analytic`, `degrees` or `line` where the job has them; `PFBSubtreeStatus` reports `killed` when its
PID is gone, and `running` with `Phase` `starting` and `Previous` while the job's command runs again before the new
kernel writes its first status), `done` (with `NonUT` when `"AllowNonUT" -> True` kept extra masters, `Kept`: points reused from an
earlier run, `PointTimes`, `Reducers`: the reducer of each point, and `KiraFallback`: why Kira gave no reduction of the
slice point when FiniteFlow reduced it instead), `refused` (predicted increment above the free memory, above `MaxGB`, or above the job's memory limit under `bin/ws`: `Equations`, `KernelGB`, `PredictedGB`, `FreeGB`, `MaxGB`, `LimitGB`, `Reducers`: a slice point Kira reduced is kept),
`nonut-hosts` (host sectors added to `job.m`; the command reruns it), `nonut` (`NonUT`, `Sectors`),
`learned` (a `"LearnOnly"` job: `Masters`, `NonUT`, `Equations`, `Allowed`), `failed` (`Message`, `Missing`), `not run`. A
`refused` written before a point (the memory free no longer fits it) has `Point`, `FreeGB`, `PredictedGB` and `Others`
(the processes above 1 GB).

`analytic.m` of an analytic job (`PFBAnalyticCoefficients`): `Exprs`, `Masters`, `Coefficients` (expressions × masters,
factored functions of `Vars`), `Vars` (ε and the invariants not fixed), `Fix`, `Check` (against the reduction at the first
point), `NonUT` (masters the system lacks, when the job kept them: then only the coefficients on masters of the
expressions' own sector are on system masters), `Seconds`.

`times.m` of a job: one record per reconstructed point, `Point`, `Date`, `WallSeconds`, `CPUSeconds` (every thread of
the kernel and the processes it waited for, Kira and Fermat included), `Threads`, `Reducer`, `Starved` (more than 2 minutes of wall-clock time with less than a quarter of it as CPU time).

A reduction whose extra masters were removed (`PFBCollectExpansion`) has only `ut[k]` masters, and
`"ExtraEliminated"` (the integrals removed) and `"ExpansionJob"`. `relation.m`: `"NonUT"`, `"Trials"` (per candidate
sector: `Sector`, `Status`, `Removed`, `NewExtra`), `"Best"` (the smallest sector that removes every extra master,
or `Missing`).

### Degree jobs: job.m, degrees.m, line.m

`job.m` `"Degrees"` (written by `PFBDegreeSpec`, through `PFBDegreesJob`, `bin/degrees.wls` and `bin/local_slice.wls`):
`Keys` (the sectors measured), `Rows` (labels of the focus rows measured, or `Automatic`: the whole focus), `Fix`
(`{unit scale -> 1}`), `Cap` (the run's `"MaxEpsDegree"`), `Eps` (the numerical ε of whole entries), `Point` (where the
ε structure is read), `Probes` (the known singularities, unit scale set to 1, as irreducible polynomials in the other
invariants), `ProbeSources` (probe → the known singularities it comes from), `UnitScaleOnly`, `NonPolynomial` (only when
some known singularity is no rational function of the invariants: those, not probed), `Probe` (letter content,
default `True`), `Variants` (each `<|"Name", "T" -> <|label -> combination of ut[m]|>, "TInverse" -> <|label ->
combination of ut[m]|>, "Rows", "Probe"|>`: the DE after U' = T U, with U = T^-1 U'; a `T` whose new masters are
definitions in integrals, a swap, has `"TInverse" -> Automatic`: the runner reduces them and inverts T inside its
graph, and seeds their integrals), `Samples` (points: rules for ε and the invariants), `Measure` (only when `False`:
no degree measurement of the rows, the samples alone, for a fit), `SampleExprs` (expressions in integrals whose vectors
on the masters, and those of their derivatives, the samples also give).

`degrees.m` (`PFBReadDegreeJob`, columns read back as labels): `Status` (`measured`, or `sampled` with `"Measure" -> False`: no `Entries`), `Rows`, `Columns` (the masters of
the reduction), `Derivatives`, `Vars` (the invariants left), `Fix`, `Cap`, `Eps`, `Point`, `Probes`, `Outputs`, and
`Entries`: one per non-zero entry, `<|"Matrix" (derivative index), "Derivative", "Row", "Column", "Eps" -> {"Laurent", lo,
hi} | {"Whole", "finite poles" | "above the cap"}, "Terms"|>`, each term `<|"Power" -> p | "whole", "Num", "Den" (total
degrees), "VarDegrees" (per invariant of Vars: {numerator highest, lowest, denominator highest, lowest}), "NumLetters",
"DenLetters" (probe → multiplicity, multiplicities > 0), "NumUnexplained", "DenUnexplained"|>`. Also `Variants` (name →
`<|"Status", "Rows", "T", "TInverse", "Entries", "Seconds"|>`), `Samples` (`<|"Point", "Values" -> <|"Base" | name ->
{derivative, row, column} array of exact values, columns in the order of Columns, and with `SampleExprs` also "Exprs"
({expression, column}) and "DExprs" ({derivative, expression, column})|>|>`), `Steps` (seconds of each
step), `Seconds`, `CPUSeconds`, `Threads`, `Hash` (a job run again with the same specification keeps it). `status.m`
of a finished job has `"Degrees" -> <|"Status", "Seconds", "Entries"|>`; a job whose memory no longer fits its degree
graphs stops `refused` with `"Phase" -> "degrees"`.

`job.m` `"Line"` (`PFBDetLineJob`): `Change`, `Key`, `Labels` (the sector's base-family masters before the change),
`Changed`, `Exprs` (their old, then their new root-free definitions), `Masters` (the sector's current masters), `Base`
and `Direction` (the line, rules for the invariants left), `Eps`, `Fix`. `line.m`: the same, with `Status`,
`Coefficients` (expressions × masters, functions of `Variable` along the line), `Check` (at the base point, the job's
first point), `Seconds`. `detline.m` (`PFBDetLineReport`): `Det` (factored), `Factors` (`<|"Factor" (monic), "Power",
"Degree", "Known" (the known singularities whose restriction to the line contains it)|>`), `Spurious`,
`SpuriousDegree`, `Line`, `Variable`, `Probes`, `Check`.

### degrees/degrees_NNN.m

The degree table of one slice (`PFBReadDegrees`): `Slice`, `Point`, `Derivatives`, `UnitScale`, `Vars`, `Keys` (the sectors
with rows in the slice), `Provenance` (`Source` `measured` or `user`; a user's file also `File`, `Frame`), `Date`,
`Summary` (`PFBDegreeSummary` of the table: `Highest`, `Count`, `Sum`, `Terms`, `Entries`, `Whole`, `Unexplained`,
`MaxUnexplained`, `Measured`, `NotMeasured` (keys), `Sectors`, `Complete`), and `Sectors`: per sector key either
`<|"Status" -> "not measured", "Reason", "Job"|>` or `<|"Status" -> "measured", "Source", "Rows", "Entries" (as in
`degrees.m`, on slice labels and the slice's derivative indices), "Summary", "Job", "JobSeconds" (its degree
measurement), "JobWallSeconds" (the job's kernel, status.m), "JobSectors" (the sectors the job measured), "JobCPUSeconds",
"Threads", "Steps", "Vars", "Fix", "Cap", "Eps", "Probes", "ProbeSources", "UnitScaleOnly", "NonPolynomial"|>`. A table that a
simplification wrote for its new slice has the `Provenance` `"Simplify" -> <|"Move", "Candidate"|>` and the variant's
measurements of the sectors it changed; those sectors keep the job times of their census job (`JobWallSeconds`,
`JobSeconds`, `JobSectors`, `JobCPUSeconds`, `Threads`) and have the variant job's apart: `VariantJob`,
`VariantJobWallSeconds`, `VariantSeconds`.

### The memory model

`~/.cache/pole-free-basis/memory.m` holds one record per phase of every job on this machine: `Equations`, `Rows`,
`Masters`, `Threads`, `BaselineGB` (the kernel's resident memory before the phase), `PeakGB` (its peak during the
phase), `IncrementGB`. `PFBMemoryModel` fits `increment = a·equations` (learning) and
`increment = b·rows·masters·threads` (reconstruction) by least squares once three records of a phase exist;
before that it uses a = 2e-6 and b = 5e-6 GB. A job compares the predicted increment with the memory free when it
runs, so a kernel that already holds many families and identities is accounted for.
