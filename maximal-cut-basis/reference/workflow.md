# Workflow

Paths here are relative to the skill folder. A run is named by a `run.wl`, a `family.wl` (the run folder is then
`<family dir>/<Name>_analysis`), a run folder or a sector folder; the last two are found through `run_info.m`,
which the first script to see a run writes, and still work after the run folder has been moved. Each script's
first lines give what it accepts: `check_basis.wls` and `write_ff.wls` take a sector folder, `run_sector.wls`
and `new_sector.wls` a `run.wl` or `family.wl` and a sector.

Steps 0 to 2 are done once per machine or family. Steps 3 to 6 are done once per sector, for one sector at a
time: finish a sector, tell the user what it gave, then start the next (`SKILL.md`, "One family, one sector at
a time").

Start every script through `bin/ws`, for example `bin/ws bin/check_basis.wls j0101...`. `ws` counts the Wolfram
kernels running on the machine, from every session, and waits until the licence has a free slot that has
stayed free for a few seconds (`--free-for N`), so it does not grab the short gap between two jobs of
another session. It also closes stdin. Every script runs under a time limit and a memory limit (core/bin/limit:
the kernel and everything below it, Kira included): `--timeout T` (the wait does not count) and `--memory GB`, by
default `MCB_TIME_LIMIT` or 24 h and `MCB_MEMORY_LIMIT` or an equal share of 90% of the machine's memory per
licence slot; a script stopped at a limit exits with 124 or 137. `--max-wait S` gives up waiting after S seconds
(exit code 75).
`bin/ws --list` shows the running jobs started through `ws` with their limits, `bin/ws --set PID --timeout T
--memory GB` changes the limits of a running one, and `bin/ws --stop PID` stops one together with its kernels (a
signal to `wolframscript` alone would leave the kernel running). `limits.md` explains the limits in full. The limit is the one the preflight cached in
`~/.cache/maximal-cut-basis/max_kernels` (or `MCB_MAX_KERNELS`, or `--limit K`; 2 when none is set).
Each kernel start is a chance to collide
with someone else, so prefer the scripts that do several steps in one kernel (`bin/run_sector.wls`).

## 0. Preflight

`bin/ws bin/preflight.wls [paths.wl | run.wl] [log file]`

Read the table (each tool with `ok`, `FAILED` or `-`, and its path), the list of available steps and the
line about the kernel licence. It is printed, and kept in `~/.cache/maximal-cut-basis/preflight.log`
(machine-wide, so nothing is written into the user's folders). From that, decide which steps you can run and
what to ask the user to install. The table holds for the tool paths it was made with (its `tool paths:` line): a run
whose `paths.wl` points elsewhere can have tools the table calls missing. `run_sector.wls` and `find_masters.wls`
print a line for the run's own paths (found or missing, without the tests), and say when the cached table was made
with other paths; `bin/ws bin/preflight.wls run.wl` then tests them. Under WSL, the detection also searches the
Windows Mathematica's `Applications` folders (`/mnt/c/Users/*/AppData/Roaming/Mathematica/Applications`). Kira has to be version 3 or later, because the check relies on
`cut_propagators` and `--set_value`, and the preflight tests both. LiteIBP comes with finiteflow-mathtools,
not with FiniteFlow itself, so it can be missing even when FiniteFlow is there.

## 1. Validate the family

Write `family.wl` (see `reference/formats.md`, `templates/family.wl`, or copy an example), then run
`bin/ws bin/validate_family.wls family.wl --scaling`.

| check | what it catches |
|---|---|
| `read` | something in `family.wl` that could not be read (the message lists it) |
| `complete-basis` | the propagators and ISPs do not form a basis of the loop scalar products |
| `gram` | the external momenta you called independent are not |
| `dimensions` | a mass, or the constant of a linear propagator, with the wrong mass dimension |
| `symbols` | a symbol that is not declared, or a name that is reserved (`$MCBReserved`) or belongs to Mathematica |
| `momentum-conservation` | dependent momenta not written in terms of the independent ones, or scalar products that contradict each other |
| `options` | a `D0` that is not an integer, or a `UnitScale` that is not one of the invariants |
| `top-sectors` | `"TopSectors"` entries that are not sector names, Kira ids or 0/1 lists of the family's length |
| scaling self-test | derivatives that disagree with Kira's conventions (the sign of linear-propagator constants, dimensions), tested on up to three master sectors |

You are done when every line says PASS. The scaling test needs to know the sectors, so if `family.wl` has
no masters list, run step 2 first and then validate again with `--scaling`.

## 2. Find the sectors

`bin/ws bin/find_masters.wls run.wl [--kira]` writes `sectors.txt` (name, Kira id, number of propagators,
fewest propagators first). If `family.wl` has a masters list, the sectors come from it. Without one, or with `--kira`,
a numeric Kira run over the whole family (`run_initiate: masters`) finds the masters and writes
`masters_found.m`; with a masters list, `sectors.txt` still comes from that list until `"Masters"` holds the one
in `masters_found.m`: `"Masters" -> Get["<run folder>/masters_found.m"]`, or the list itself (a string there is read
as a Kira masters file, which `masters_found.m` is not).
That run goes down from the top sectors (`"TopSectors"` in `family.wl`, else the lines of
`"Graph"`); with neither, every line counts as a propagator, ISPs included, and the script says so. If the user only cares about one sector, put it in `run.wl` as
`"Sectors" -> {"j0101..."}`. The sector to start with is the one the user named, or else the one with the
fewest propagators (third column of `sectors.txt`). The script also lists the sectors that are an earlier one at
mapped kinematics (last column of its table, and `geometry.m`): do the earlier one first, and the automatic pass of
the later one starts from its basis, mapped (`reference/method.md`, "Sectors with the same geometry").

## 3. The automatic first pass on one sector

`bin/ws bin/run_sector.wls run.wl j<pattern> [--force] [--no-scaling] [--preflight]` does everything for the
sector you are working on, in one kernel: validation with the scaling self-test on that sector, the first
pass, the FiniteFlow scripts, the sector's page and the summary. The FiniteFlow check itself then needs
`bin/finiteflow_sector.sh`, run after this script has finished. With `basis.m` already there, the first pass
is skipped unless you add `--force`.

Two batch scripts exist for a user who runs the toolkit without an agent: `bin/run_all.sh run.wl [queues]`
(preflight, validation, sectors, the first pass of every sector in parallel queues, reports) and
`bin/ws bin/auto_pass.wls run.wl [j... ...] [--force]` (several sectors one after the other). As the agent,
do not use them: one sector at a time.

The candidate searches of one sector share a time budget, `"TimeLimits" -> <|"Sector" -> 900|>` in `run.wl`
(900 s by default), on top of the limit of each search (`"LS"`). Easy sectors finish in well under a minute; a
hard sector would otherwise try representation after representation, each until its own limit, and can take
an hour without producing a single candidate. An ε-form basis ends the search only when none of its elements is known not to
be ε-pure; until then the pass goes on as for a basis that is not ε-form yet. When the budget is used up, the pass
skips what is left (further representations, the representations with one more ISP, the retry with larger pools),
keeps the best result so far and says so in `flags`, so that you can push rung 1 by hand on the representation that looks most promising.
For a large family, run a few sectors of different sizes first and look at their times before choosing the
limits for the whole run.

A tool is credited to the sector it produced something for (a representation, a reduction, a DE, a label), in the
run's ledger `citations.m`, never when it was only loaded; each script and the first pass name their sector (the
citation context, `core/README.md`). The tools in a sector's `basis.m` and on its page are those the ledger credits
to it, whichever kernel ran them, so a basis checked again later keeps the tools that found it.

`MCBAutoPass` prints and records the representations with their geometry; the number of masters on the cut,
recounted by Kira (with a note when it differs from the list); the Picard-Fuchs label of the cut and the time it
took (`-- Picard-Fuchs operator: elliptic (order 2): ... --`), which steers what follows
(`reference/picard-fuchs.md`); for the best few representations the route
taken, how many candidates came out and the best DE found; a second attempt with larger pools; and finally the
result together with the DE at the first kinematic point. It writes `basis.m`, `masters.m`, `attempts.m`,
`basis.html`, and an `AnalysisMasters.m` that reproduces its choice. The Kira jobs are deleted once read.

Look at the sector's `basis.html` or `basis.m`: the `status`, the `flags`, whether each element is ε-pure
(`epsPure`), the `classification` next to the `geometry`, and `nMastersCut` against `nMastersList`.
Go on to step 4 when the sector is flagged (`SKILL.md`, "The ladder"), or when its status
is `eps-polynomial` and you do not trust the non-dlog verdict; otherwise go to step 5.

## 4. Escalate

Open `j<pattern>/AnalysisMasters.m`, or create one with `bin/new_sector.wls run.wl j<pattern>` (it keeps an
existing script unless you add `--overwrite`). It is
split into sections: setup, representations, geometry, masters on the cut, candidates, the maximal-cut DE
and the choice of basis, FiniteFlow, and the result with your reasoning. Change the representation index,
the candidate list and `basis` as you see fit, and leave a Text cell explaining each choice. Run it with
`bin/ws j<pattern>/AnalysisMasters.m` (the first lines of the file give the command). Its output
is for you: when you keep it in a log, put the log outside the run folder.

The ladder and the tools for each rung are described in `reference/escalation.md`. When a basis comes from
somewhere else (a paper, INITIAL, Libra, your own reasoning), write it to a file and run
`bin/ws bin/check_basis.wls j<pattern> file.m --rung n --provenance "..." [--reference "..." ... --used "..."]
[--tool NAME ...]` (one `--reference` per paper, which goes to the run's ledger, `citations.m`, as adopted or not
adopted; `--used` says what was taken from it; one `--tool` per tool you ran by hand). Keep the basis file
outside the run folder and delete it once it is checked: the definitions and their provenance are kept in
`masters.m`, `basis.m` and `attempts.m`. The file holds a list whose elements are expressions as in `masters.m`,
or `<|"definition" -> J, "label" -> "...", "provenance" -> "..."|>` when each element needs its own label and
provenance. The script checks the basis and records the attempt. It replaces the current basis (`masters.m`,
rescaled by the powers of ε the check found, `basis.m`, `basis.html`) only when the new status is better than the
current one (or, for two ε-polynomial bases of the same status, when its spread of powers of ε is smaller, or, on a
non-dlog sector, the same with an undotted element where every element of the current one is dotted, or, for two
ε-form bases, when fewer of its elements are not ε-pure, then when more are, as `MCBCandidatePurity` judges them);
`--adopt` replaces it anyway, and `--dry-run` only prints the verdict and writes nothing. `--tie-breaker "reason"` is
for a basis that is as good as the current one and preferred by a tie-breaker (rational normalisation, shared
conventions; a basis with more ε-pure elements needs none, it is better): it is adopted unless it is worse, and recorded as a tie-breaker with its reason rather than as
a rung. Without a file it re-checks `masters.m` and keeps its labels. A tool you ran by hand for the basis
(INITIAL, Libra, Fuchsia, ore_algebra) is credited only through `--tool` (a name of the registry in
`core/lib/Core/Tools.wl`; an unknown one is a usage error that lists the known ones): the provenance credits
nothing. `--dry-run` records no paper and no tool. Anything else you take from a paper (a map of propagators, a
normalisation, an idea for candidates) goes to the ledger with
`MCBRecordLiterature[dir, <|"reference" -> ..., "used" -> ..., "rung" -> n, "outcome" -> ..., "result" -> ...|>]`
(`"result"`: `"adopted"`, or `"not adopted"` when it led to no basis), and a tool run by hand outside
`check_basis.wls` with `CoreRecordTool[dir, {"NAME"}, "declared"]`.

The generated `AnalysisMasters.m` reproduces the automatic pass rather than copying its result: its `steps` list
how the candidates of the chosen basis were built (the representation, the function, such as the route of the
geometry, a projection or a purification, and its options, or "mapped" for a repeated geometry), section 5 runs
them again with `MCBReplayCandidates`, and section 6 searches among them with `basis = Automatic`. The script keeps
the basis it was written for (`written`) and says, when it runs, whether it found that basis again and whether
`masters.m` has changed since. When `check_basis.wls` adopts a basis from a file, it writes the script again for
that basis (no `steps`, the basis in `basis`), unless you have edited it. The script records itself as rung 1 while
it reproduces the automatic pass. When you change the analysis, set `rung` in its last section to the rung you are
working on. Like `check_basis.wls`, the
script replaces the current basis only when its own is better; set `adopt = True` in it to replace an equally good
one. It checks at the points of the current basis. Rerunning the automatic pass refreshes the script only while it
is still exactly as generated; once you have edited it, your version is kept and the new one is written to
`AnalysisMasters.auto.m`. A pass that stops before it has candidates (Kira failing, say) keeps the basis the sector
already has.

You are done with a sector when its status is `eps-form` and no element is known not to be ε-pure; or when it is
`eps-polynomial` and `notes.md`
explains why the geometry allows nothing better; or when every rung is recorded in `attempts.m` and the
sector is flagged.

## 5. The analytic check with FiniteFlow

`bin/finiteflow_sector.sh j<pattern>`. The environment variable `MCB_FF_TIMELIMIT` sets the time limit per
step (by default `run.wl` `"TimeLimits" -> "FiniteFlow"`, 3600 s), and `MCB_FF_MEMORY` the memory limit per
step in GB (by default `run.wl` `"MemoryLimits" -> "FiniteFlow"`, else the default of `bin/ws`). Both `run.wl`
values are read when the scripts are written; `InvestigateDEQ.m` always gets 900 s.
The scripts are written again whenever `masters.m` has changed since they were
written (a checksum is kept in `finiteflow/masters.cksum`), or with `FORCE=1`. While it runs, `finiteflow/`
holds the scripts (`families0.m`, `topology.wl`, `genIBPs.m`, `SetSDE.m`, `InvestigateDEQ.m`), the identities
(`ibps/`), the reduced system and the logs; the sector's `basis.m` and `basis.html` are refreshed at the end.
When the verdict is `eps-form` or `eps-polynomial` and agrees with Kira, or is `not applicable`, only `verdict.m`,
`DE.m` and `ffinfo.m` are kept, and the next run writes the rest again. Otherwise everything stays so that you can
read the logs (`MCB_KEEP_SCRATCH=1` keeps it in any case).

`InvestigateDEQ.m` also compares FiniteFlow's matrices with Kira's, entry by entry, at Kira's first point: the
unit scale is restored by homogeneity and the phases moved out for FiniteFlow are put back. Both describe the
same `masters.m` in the same rational frame (square-root ratios left out), so they must agree exactly. The
ε-only fallback runs at that same point, so the comparison works in both modes. Look at `verdict.m` (its
`status`, its `mode`, which is `full` or `eps-slice`, the `profile` and `kiraComparison`) and at the logs.
You are done when the verdict matches the Kira verdict and the comparison says `agree`. If it says
`disagree` or the verdicts differ, see "The FiniteFlow check" in `reference/pitfalls.md`. A verdict shown as
`stale` belongs to an older basis: run the script again.

## 6. Reports

`bin/ws bin/make_reports.wls <run folder> [j...]` rebuilds the `basis.html` of the sectors named (all of them
without names), copying `finiteflow/verdict.m` into `basis.m`, then `summary.html`, `masters_all.m` and
`CITATIONS.md`. When you finish a sector, tell the user its status, its basis, its `flags` and what
could be tried next, any extra masters found on the cut, the papers used (to acknowledge) and the tools to
cite. At the end of a family, add the number of sectors per status and the flagged sectors.

## Working on one sector without the first pass

The quickest route is `bin/ws bin/run_sector.wls run.wl j<pattern>`, then step 4 if the sector needs it, then
`bin/finiteflow_sector.sh`. To start from an empty script instead: steps 0 and 1 (without `--scaling` if the
family has no masters list), `bin/ws bin/new_sector.wls run.wl j<pattern>`, step 4 from the generated
script, then steps 5 and 6.

## Function reference

Load the toolkit with `Needs["MaximalCutBasis`"]` (with `lib/` on `$Path`) or
`Get[".../lib/MaximalCutBasis.wl"]`. Every function has a usage message, for example `?MCBCheckBasis`.

| area | functions |
|---|---|
| setup | `MCBLimitCommand`, `MCBJobLimits`, `MCBMemoryHeadroom`, `$MCBKiraTimeLimit`, `$MCBKiraMemoryLimit`, `$MCBFFTimeLimit`, `$MCBFFMemoryLimit`, `MCBLoadPaths`, `$MCBPathsFile`, `MCBToolsLine`, `MCBSetPath`, `MCBPath`, `MCBAvailableQ`, `MCBLoadTool`, `MCBPreflight`, `MCBKernelBudget`, `MCBRunningKernels`, `MCBRunSetup`, `MCBRunSectors`, `MCBCacheDir`, `MCBPruneScratch`, `$MCBKeepScratch`, `$MCBSkip`, `$MCBSteps` |
| family | `MCBReadFamily`, `MCBValidateFamily`, `MCBValidationReport`, `MCBPropLabel`, `MCBToKiraYAML`, `MCBToLiteIBP`, `MCBToBaikov` |
| sectors | `SectorOf`, `SectorID`, `SectorName`, `SectorFromName`, `PropPos`, `ISPPos`, `OffCutQ`, `DropOffCut`, `JIntegrals`, `JWeight`, `ComboWeight`, `MCBMasterSectors`, `MCBSectorPool`, `MCBCornerIntegral`, and for elements as written (prefactor × pieces): `MCBTerms`, `MCBCoefficients`, `MCBEqualAtPointsQ`, `MCBRandomValues`, `MCBLargeQ`, `$MCBLargeLeafCount` |
| derivatives | `MCBVectorField`, `MCBdPropdX`, `MCBDerivJ`, `MCBDerivExpr`, `MCBScalingResidue`, and the same at a numeric point: `MCBVectorFieldAt`, `MCBdPropdXAt`, `MCBDerivJAt`, `MCBDerivExprAt`, `MCBScalingResidueAt`, `$MCBPointDerivatives` |
| Kira | `MCBKiraCutReduce`, `MCBCutMasters`, `MCBPoints`, `MCBReduceTo`, `MCBScalingSelfTest`, `MCBFindMastersKira` |
| Baikov | `MCBRepresentations`, `$MCBMaxStandardVars`, `MCBCutData`, `MCBSplitTwist`, `MCBPrefRat`, `MCBGeometry`, `MCBDlogGeometryQ`, `MCBScoreRepresentation`, `MCBRepresentationTable`, `MCBTwistFactors`, `MCBBoundaryGeometry`, `MCBBoundaries` |
| loop by loop | `MCBLoopByLoopReport`, `MCBPolynomialRoles`, `MCBInfinityExponents`, `MCBRootDiscriminants`, `MCBMasterCount`, `MCBBoundaryForm` |
| cut integrands | `MCBCutIntegrand`, `MCBLeadingEps`, `MCBPoolData`, `MCBCutIntegrand0` |
| leading singularities | `MCBIteratedLS`, `MCBBestIteratedLS`, `MCBResidueStep`, `MCBSqrtClass`, `MCBBuildLSData`, `MCBScreenSubset`, `MCBSolveSubset`, `MCBEpsPurityNumeric`, `MCBElementPurity`, `MCBCandidatePurity`, `MCBKeptPurity`, `MCBDlogBasisCrossCheck` |
| curves | `MCBCurve`, `MCBCurveCoordinates`, `MCBCurveTargets`, `MCBFibrationTable` |
| candidates | `MCBDlogCandidates`, `MCBCurveCandidates`, `MCBSingleCandidates`, `MCBStrictTargetCandidates`, `MCBPurifyCandidates`, `MCBProjectedCandidates`, `MCBProjectedPurifyCandidates`, `MCBCandidate`, `MCBCandidatesFor`, `MCBReplayCandidates`, `$MCBDefaultOptions` |
| DE check | `MCBCheckBasis` (the gate), `MCBBasisChecks`, `MCBReduceCandidates`, `MCBSubsetDE`, `MCBSearchBasis`, `MCBSimplifyBasis`, `MCBEpsFactorizedQ`, `MCBEpsPolynomialQ`, `MCBSplitMaster`, `MCBMasterExpression`, `MCBPrintDE`, `MCBDottedQ`, `MCBAllDotQ` (the all-dot flag); tests of elements with large coefficients in `tests/large_coefficients.wls` |
| rules | `MCBRuleViolations`, `MCBHonestQ`, `MCBLetterQ`, `MCBRulesCheck`, `MCBWeightOf`, `MCBIntegralWeight`, `MCBMasterWeight`, `MCBWeightCheck`, `MCBEulerMatrix`, `MCBEulerCheck` (shared with the pole-free gate; large coefficients are checked at points) |
| sector maps | `MCBSymanzik`, `MCBSectorMap`, `MCBMapBasis`, `MCBGeometryGroups`, `MCBRepeatedGeometry` |
| fallbacks | `MCBDimensionShift`, `MCBTarasovLower`, `MCBSymanzikU`, `MCBSymbolicCutDE`, `MCBExportDE` |
| FiniteFlow | `MCBWriteFFPipeline`, `MCBFFLineDE` (the maximal-cut DE along a line, eps-Laurent, inside the kernel) |
| Picard-Fuchs | `MCBPicardFuchs` (the step; `bin/picard_fuchs.wls` for one finished sector), `MCBPFClassifyOperator`, `MCBPFLabel`, `MCBPFOperator`, `MCBPFRegularise`, `MCBPFLaurentMatrix`, `MCBPFPeel`, `MCBPFLocal`, `MCBPFHyperexponentialSolution`, `MCBPFPCurvature`, `MCBPFSymmetricSquareQ`, `MCBPFBaikovCheck`, `MCBPFNonPolylogQ`, `MCBPFPolylogQ`, and the operator algebra `MCBPFNormalize`, `MCBPFApply`, `MCBPFCompose`, `MCBPFAdjoint`, `MCBPFRightDivide`; tests in `tests/picard_fuchs.wls` |
| reports | `MCBWriteMasters`, `MCBWriteBasis`, `MCBBasisRecord`, `MCBAppendAttempt`, `MCBWriteNotes`, `MCBAppendNotes`, `MCBBasisHTML`, `MCBSummaryHTML`, `MCBReadFFVerdict`, `MCBWrittenEpsPower`, `MCBDrawSector`, `MCBStatusFor`, `MCBRetryHints`, `MCBSameBasisQ`, `MCBClassificationFlags`, `MCBKeepClassification` (what `MCBWriteBasis` keeps from the record it replaces), `MCBBetterBasisQ`, `MCBNonDlogQ`, `MCBAllDotCheck`; tests of the all-dot flag in `tests/all_dot.wls` |
| citations | `MCBRecordLiterature` (a paper), `MCBKnownTools` (checks registry names), `MCBRecordCitations` (`toolsUsed` and `citations` of a `basis.m` record, from the ledger), `MCBRecordFFCheck` (the FiniteFlow check's credits), `MCBMarkToolUsed`, `MCBToolsUsed`, `MCBResetToolsUsed`, `MCBCitations`, the older `MCBReadLiterature` and `MCBWriteLiterature`, and the core's `CoreCitationContext`, `CoreWithCitationContext`, `CoreRecordTool`, `CoreRecordPaper`, `CoreBasisKey`, `CoreImportCitations`, `CoreReadCitations`, `CoreSectorCitations`, `CoreWriteCitations` (`core/README.md`, "Citations"); tests in `tests/citations.wls` |

A few typical calls inside `AnalysisMasters.m`, using the double box from `examples/`:

```mathematica
reps = MCBRepresentations[fam, sector];                  (* sorted by score *)
cd = reps[[1]];  cd["geometry"]["text"]
MCBCutIntegrand[cd, j[dbox, 1,1,1,1,1,1,1,-1,0]]         (* R(z, eps) for the integral with a numerator *)
cr = MCBDlogCandidates[fam, sector, cd, <|"nmi" -> 2, "nd" -> 3|>];
red = MCBReduceCandidates[fam, sector, cr["candidates"], FileNameJoin[{$SectorDir, "kira"}], pts];
res = MCBSearchBasis[red, cr["candidates"], 2];
mine = MCBCandidate[fam, sector, s^2 t eps^4 j[dbox, 1,1,1,1,1,1,1,0,0], <|"label" -> "dlog, LS 1/(s^2 t)"|>];
check = MCBCheckBasis[fam, sector, {expr1, expr2}, FileNameJoin[{$SectorDir, "kira", "mine"}], <|"Points" -> pts|>];
```
