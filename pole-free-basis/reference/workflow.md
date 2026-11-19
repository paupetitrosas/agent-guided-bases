# Workflow

The steps of `SKILL.md` in detail: what to look at after each one, how to size the computations, and the
function list. Steps 1 to 3 are done once per system; steps 4 and 5 once per sector, for one sector at a time
(`SKILL.md`, "One family, one sector at a time"); step 7, the simplification phase, once the pole-free work is done,
and step 8 at the end. The sections below are numbered by topic, not by those steps: section 1 is `SKILL.md`'s
setting up, section 2 its step 1, section 3 its steps 2 and 3, sections 4 and 5 its steps 4 to 6, section 6 the gate
and the approval of step 5, and sections 7 and 8 its steps 7 and 8.

## 1. Preflight

`bin/ws bin/preflight.wls [paths.wl]` runs the maximal-cut-basis preflight (tools, licence) and adds memory,
cores, the memory model and the largest reduction that fits. Reductions need FiniteFlow, its library, LiteRed
and LiteIBP. It also says whether the optional SOFIA is configured, and whether its `scr.m` is the tested
version. Tell the user what is missing and what that disables (`reference/tools.md`). The first argument may also
be a `run.wl` (its `"Paths"`), and a second one names the log file of the report (default `preflight.log` in the
maximal-cut-basis cache). It exits with 1 when a tool that reductions need is missing or the test of FiniteFlow's
sparse solver did not pass, also when that test found no free licence slot within 10 minutes (run it again then).

## 2. The system

Write `system.wl` with the user (`reference/formats.md`). `bin/ws bin/validate_system.wls system.wl` reports:

- **errors**: fix them (shared kinematics, maps, roots as an overall factor, readable masters, a `"MCBRun"` that is
  not a maximal-cut-basis run of the same family);
- **warnings**: show them to the user;
- **questions**: ambiguities such as a master spread over two sectors of equal size. Ask the user and record the
  answer in `system.wl`, never guess.

Ask the user, rather than assume: the master order of the pipeline that produced the slice, which families
are images of which, the root definitions, which families are frozen, and which maximal-cut-basis run produced each
family's masters (`"MCBRun"`: rung 8 replays its candidates and reads its points and Picard-Fuchs labels; it is never
written to).

### Known singularities (optional)

With SOFIA installed (`reference/tools.md`), run `bin/ws bin/singularities.wls run.wl [fam ...]` once, after the
system validates and before anything uses known singularities. It needs no slice and no reduction. For each base
family (all of them by default; an image follows its base through the invariant map), SOFIA runs once on each top
graph: the sectors of the family's masters that no other sector of its masters contains, usually one. Subtopologies
are included, with `SolverBound -> Infinity` and no `Substitutions` (the unit scale is not set to 1). The families
run one after the other in the script's own kernel; `--time-limit S` bounds each graph (3600 s by default, 0 for
none). The graph comes from the family's `"Graph"`, else from momentum conservation (`MCBGraph`). SOFIA takes
quadratic propagators only: a graph with linear ones, or without external momenta, is "not applicable".

SOFIA's variables (`s12`, `s23`, ..., `MM1`, `mm1`, and `s` for a graph with two legs) are renamed into the family's
invariants through its kinematics: `s12` is the square of the sum of the momenta entering SOFIA's nodes 1 and 2,
which are the graph's vertices with external momenta, so it can be any of the family's invariants. Two checks, each
of a limited reach:
- `"SymanzikCheck"` (before SOFIA runs, `PFBSOFIASymanzikCheck`): the Symanzik polynomials of the graph as SOFIA
  receives it (U from its spanning trees; F from its spanning 2-forests, with the mass labels of its edges and legs and
  SOFIA's names s<ij...> for the momenta entering several legs, all renamed) equal those of the sector's propagators
  (`MCBSymanzik`), edge by line, up to a sign. It catches a wrong line on an edge, a wrong mass label of an edge or a
  leg, and a wrong momentum at a node. For a graph built from propagators whose vertices conserve the loop momenta it
  holds by construction (the momenta at the nodes follow from the propagators, and any such graph has their U and F),
  so it guards the code that builds SOFIA's input and the renaming; it says nothing of SOFIA. A graph that fails is
  refused.
- `"KinematicsCheck"` (after SOFIA runs): SOFIA's own kinematics (`MySubstitutions`: p_i·p_j in its variables, with the
  masses it assigned to the nodes), renamed, equal the scalar products of the momenta entering the nodes. Since the
  renaming defines SOFIA's variables by those momenta, it can only fail when SOFIA's conventions differ from the
  renaming's (its s_ij, its assignment of the node masses, its elimination of the last momentum); it says nothing
  about the graph. A graph where it fails contributes nothing.
Neither check proves that SOFIA's list is complete or that its polynomials are singularities on the physical sheet. The polynomials go to `singularities/<fam>.m` with SOFIA's commit and hash, the options, the
warnings and the time, and SOFIA's output to `singularities/<fam>.log` (`reference/formats.md`). A second run keeps
a cache whose input has not changed (`--force` recomputes it); a cache whose family has changed since is "stale" and
is not used. SOFIA is credited in the run's ledger, for the whole run, for each family it gave polynomials.

Tell the user how many polynomials each family has, SOFIA's warnings (a maximal-cut contour that may be degenerate,
skipped subtopologies), and the polynomials that vanish at the family's kinematics: those kinematics are special for
the graph, and SOFIA's list may miss singularities there. The list is a superset of the singularities and says
nothing about sheets.

The known singularities of a family are its letters (the `"Letters"` of its `family.wl` and of `system.wl`) together
with SOFIA's list (`PFBKnownSingularities`). SOFIA's polynomials are never letters by default. For a family without
letters, the script, `bin/validate_system.wls run.wl` (a question) and the census (a line) offer them as its letters:
ask the user, and only after a yes set `"LettersFromSOFIA" -> True` in the family's entry of `system.wl`. The gate's
letter check then uses them (`PFBLetters`), and so does the `"Letters"` field of `PFBKnownSingularities`.

The script exits with 0 when every family is done, with 1 when one is partial, timed out, failed or not
applicable, with 2 when the path is not SOFIA's `scr.m` (or a family is unknown), and with 3 when `scr.m` does not
load. Without SOFIA it says so and exits with 0; nothing else needs it.

## 3. The slice

**External slice** (the usual case: the full DE was produced elsewhere, often on a cluster). Write
`conventions.wl` with the user, then `bin/ws bin/import_slice.wls run.wl`. The import refuses wrong
dimensions or unknown roots. When the slice has a derivative in every invariant of non-zero dimension, it also
checks the Euler relation of homogeneous integrals on every row (`"euler"` in its JSON; `PFBEulerCheck`): a
failure means a wrong frame, transposition or derivative order, or a master definition that does not match the
slice. A slice without the unit scale's derivative cannot be checked this way, and nothing at import detects a
wrong master order or point. The calibration does:

1. Write a reduction job for a low sector with few masters (`bin/ws bin/subtree_job.wls run.wl fam/jPATTERN 0`).
2. Run it (below) and `bin/ws bin/calibrate.wls run.wl <job dir>`.
3. `exact` on every focus row: the conventions are right. Anything else: show the user the mismatching rows and
   ask which convention differs (frame, root order, labels, transposition, the point, the master definitions the
   producer used). Change nothing in the run until the calibration is exact. The script also checks the Euler
   relation on the reduction's own rows; a failure there points at the family files or the master definitions,
   not at the slice.

**Local slice**: `bin/ws bin/local_slice.wls run.wl` writes one job over the whole system (every top sector a
root, every master in the focus, no pool), `jobs/local_slice/`, and prints its command. Its point and derivatives
are the `"Point"` and `"Derivatives"` of the run's `conventions.wl` when it gives them, else a random point of primes
and every invariant but the unit scale. The runner counts the equations and refuses
to learn when the predicted memory does not fit; then give the user the job folder to run on a larger
machine: copy the folder and the skill there, set `"ToolPaths"` (and `"MaxGB"` if wanted) in its `job.m` for that machine,
run `bin/subtree.wls <job folder>` through its `bin/ws` (repeat while the exit code is 4), copy the folder back. Afterwards
`bin/ws bin/local_slice.wls run.wl --collect` makes it the current slice. A local slice needs no calibration:
it is computed with the system's own definitions.

**Starting degrees.** The local slice job also measures the kinematic degrees of every row on the same learned system
(below, "Kinematic degrees"), and `--collect` stores them next to the slice; `local_slice.wls run.wl --no-degrees`
writes a job without them. For an external slice the user may give them in `conventions.wl` (`"Degrees"`,
`reference/formats.md`): the import validates them against the slice (dimensions, zero entries, the powers of ε of
every entry, whole entries for those with finite poles) and refuses the whole import when they do not fit; they are
stored with provenance `"user"`, without letter content.

**Credits of the starting DE.** An external slice comes from a DE the skill did not make. Ask the user which tools
and papers produced it and name them in `conventions.wl` (`"Credits"`, `reference/formats.md`): the import records
them for the whole run, and `CITATIONS.md` lists them under "Cite". An unknown tool name refuses the import.

## 4. Census

`bin/ws bin/census.wls run.wl` (`--sector fam/jPATTERN` adds that sector's rows in detail). Read:

- the bad entries per pole factor, the bad rows, the negative powers of ε;
- the highest power of ε and the entries above the cap (`"MaxEpsDegree"`): bad entries, like poles;
- per bad sector its `"Issues"`: finite poles, negative powers of ε, entries above the cap;
- the bad sectors bottom-up, and which are **possibly inherited**;
- the **possible hidden weights**: a clean sector S whose subtree holds every column of a pole factor w in the bad
  rows (`"HiddenWeights"`; `reference/method.md`, "A hidden weight on a clean lower sector"). S is opened before the
  sectors where the poles show, for its lower-sector scan; once that scan is recorded the census says so and moves on
  (`census.wls` reads the sectors' `attempts.m`). S is never flagged or of a frozen family; a sector fixed by an
  accepted change is named too, as reopened (`"Reopens"`: the ids of those changes);
- `"Next"`: the lowest bad sector that is not possibly inherited, or a sector with a possible hidden weight, whichever
  comes first bottom-up. Work on it, or on the lowest such sector of the family you are already working on.

Before the first sector, try rung 1 on the whole slice: it lifts negative powers and brings entries above the cap
down where a uniform ε^k can. The negative powers it leaves are poles at ε = 0, fixed sector by sector, bottom-up
like the rest (a new maximal-cut basis when they sit in a sector's own block).

## 5. One sector

1. `bin/ws bin/new_sector.wls run.wl fam/jPATTERN` writes the sector's `AnalysisPoles.m`; work in it. It refuses to
   overwrite an existing one unless given `--force`.
2. Source test (section 2 of the script). Its outcome picks the first rung (`reference/escalation.md`).
3. Structural reading (`reference/method.md`, "Reading a sector's structure"; section 2b of the script):
   which rows and columns carry each factor and which masters must change for it (`PFBSourcesByPole`), the
   loop-by-loop report of every loop order (`MCBLoopByLoopReport`: subloops, twist factors, costs at infinity,
   masters with and without the O(ε) factors, boundary geometry, cut integrands of the current masters and
   their dotted variants), the candidate and the subsector integrals it brings. Write it in `notes.md`; it
   sets the pool of the reduction. Do not skip this step for a sector whose own basis is suspect.
4. A reduction of the sector's subtree at the slice point, the points of the fits (`"ExtraPoints"`) and two more
   that only the gate uses (section 4: `fitReds` for the rungs, `checkReds` for `PFBTryChange`; a reduction at the slice
   point, or a second one at a point already given, is no extra point: the gate ignores it and says so). It must calibrate
   exactly against the current slice before anything else uses it. A job folder belongs to one specification and one
   basis: written again with other points or seeds, or after an accepted change, it is refused unless
   `"Replace" -> True`.
5. Climb the ladder; each proposal through `PFBTryChange`. To choose among candidates for one master with the
   others fixed, `bin/ws bin/slot_scan.wls run.wl job "<|...|>" label` runs each pool integral exactly on the slice;
   for two or three masters at once, `bin/ws bin/pair_scan.wls run.wl job fam/jPATTERN` (rung 3). Run the scans
   before any fit or completion (`reference/escalation.md`, "Order by cost"). Both record their best set and the
   poles it left in the sector's `attempts.m`, which the hidden-weight test reads before a flag.
   For a clean sector the census marks as a possible hidden weight, the source test says `pole-free` with
   `"HiddenWeight"`: reduce its subtree as above and run `bin/ws bin/pair_scan.wls run.wl job fam/jPATTERN
   --hidden-weight` (`--factor "1 + 4 eps"` when the hint came from `PFBHiddenWeightTest` instead of the census). It
   ranks sets of the sector's masters by the entries with the factor left in the rows above, keeps the sector's own rows
   pole-free (other sets are ranked out) and records the scan; the template's section 6b does the same in the kernel
   (`PFBHiddenWeightScan`).
   Rung 8 (a new maximal-cut basis) is three commands: `bin/ws bin/maxcut_candidates.wls run.wl fam/jPATTERN` (the
   maximal-cut-basis toolkit's candidates in this skill's kernel, filtered, and the job with them in the pool), the
   job, and `bin/ws bin/pair_scan.wls run.wl <job> fam/jPATTERN --maxcut` (the scan by the full rows and the
   finalists through the maximal-cut-basis gate); then `PFBTryChange` with the first finalist's verdict
   (`reference/escalation.md`, rung 8). Every change that alters the maximal cut passes that gate in `PFBTryChange`.
6. After an accepted change: the census of the new slice is the starting point of the next sector. Sectors
   above may have become pole-free (inherited poles), or received deferred poles that their own fix must remove
   (the gate's rows check, `PFBDeferredObligations`; moved poles are factors those rows had, now in new columns). Tell the user what the sector gave before you open the
   next one, and record any paper you used outside a change (`PFBRecordLiterature`).
7. Before flagging a sector, the hidden-weight test (`PFBHiddenWeightTest[ctx, key]`; `PFBFlagSector[ctx, key, reason,
   tried]` runs it and refuses while it names a clean lower sector whose lower-sector scan is not recorded;
   `reference/escalation.md`, "Before the flag").
8. When the sector is done (a change accepted, its poles inherited, or flagged), delete the scratch of its jobs with
   `PFBCleanJob[<job folder>]`: the identities and the serialized system go, the job's specification, status, log
   and reductions stay. Identities another job reuses are kept.

### Reductions

`PFBSubtreeJob` writes `jobs/<name>/`; the command from `PFBSubtreeCommand` runs it through `bin/ws` and
repeats it when host sectors are added (exit code 4). Start it from the shell, in the background
(`sh -c "<command>"`): it needs a licence slot of its own, and a kernel waiting for it would hold another. The
scripts that take a job (`slot_scan.wls`, `pair_scan.wls`, `coefficients.wls`, `extra_masters.wls`,
`relation_sector.wls`) take its name, the folder under `jobs/`; `calibrate.wls`, `bin/wait_job` and `PFBCleanJob`
take the path of the folder.

**Which reducer.** The slice point, the job's first point, is reduced by Kira when Kira and Fermat are found and the
subtree lies in one family. An image family counts as one: Kira reduces it as its base family at the image's mapped
point (the image's propagators are the base's with the momentum map applied). The other points are always
FiniteFlow's, and so are the jobs that evaluate FiniteFlow's learned system, at every point: learn-only and analytic
jobs (`bin/coefficients.wls`, `bin/relation_sector.wls`), and degree and line jobs (`job.m` `"Degrees"`, `"Line"`:
the degree census, the starting degrees of a local slice, the simplification phase's variants, samples and fits,
`bin/det_line.wls`). Kira
reduces the focus rows, the pool, its derivatives and the definitions of the masters with the invariants fixed and d
symbolic (an uncut job with maximal-cut-basis's Kira configuration of the family, in `job.m`), and the runner projects
every row onto the system's masters, so `red_1.m` has the same keys as FiniteFlow's and `"Reducer" -> "Kira"`. A job
with only the slice point, which is all the scans need, then generates no identities and learns nothing: in a real
run, Kira took about three minutes where the FiniteFlow job took hours and swapped a 16 GB machine. FiniteFlow reduces
the slice point instead, and `run.log` says why, when
- the subtree holds integrals of several families: its roots do (a sector with its images, the default), LiteRed maps
  some of its sectors into another family, or it takes in the sectors of another family's masters that map onto its
  own (`"PreImage"`). A job with `"Images" -> False` holds one family only when none of these maps exists: in a system
  whose image families have masters on mapped sectors, most jobs are FiniteFlow's;
- symmetry rules of the system apply inside the subtree (Kira does not read them);
- Kira gives no reduction: stopped at its limit, integrals left unreduced (raise the seeds), or masters the system
  lacks (FiniteFlow's host sectors and extra columns handle them). `status.m` then has `"KiraFallback"`, and the job
  folder `kira_fallback.m`: later runs of the job (a rerun, a round with host sectors) go to FiniteFlow at once.

Force a reducer with `run.wl`'s `"Reducer"` (every plain job: not the jobs above, which stay FiniteFlow's),
`PFBSubtreeJob`'s `"Reducer"`, or `subtree_job.wls --reducer kira|finiteflow`: `"Kira"` refuses or fails a job that
Kira cannot reduce instead of falling back (a degree or line job included), and `"FiniteFlow"` never uses Kira. Kira runs under a time and memory limit of its own inside the job's: half of what is left of `"TimeLimit"` (FiniteFlow
has the other half when Kira stops at its limit),
and 90% of the memory the job's limit leaves. `status.m` lists the reducer of every point (`"Reducers"`), and
`tests/kira_vs_finiteflow.sh` checks that both reducers give the same reduction.

**Its limits.** The command runs the job under `job.m`'s `"TimeLimit"` (seconds, 24 h by default) and `"MaxGB"`
(its memory with every subkernel; by default the share of `bin/ws`), both from `run.wl`. Set them there before
writing the job, change a running job with `bin/ws --set PID --timeout S --memory GB` (`bin/ws --list` gives the
PID), and make a change last by running `bin/subtree_job.wls` again with the same arguments, which updates `job.m`
and prints the new command. A job stopped at a limit keeps its finished points (below). The maximal-cut-basis
`reference/limits.md` explains the limits in full.

**Waiting for it.** `bin/wait_job <job folder> --timeout S [--stall S]` waits without a kernel and always ends. It
prints the phase and the point as they change. It exits 0 when the job is done, 1 when the job refused (memory,
masters the system lacks), 3 when it failed or was killed, 4 when host sectors were added (run the command again),
and 124 at the timeout or when `run.log` stalls (the job goes on). Take the timeout from a pilot (`timing-discipline`)
and the stall limit from the time of one point. Do not write your own wait loop: the loops written by hand in a real
run never ended when a job died, and nothing noticed the death. `PFBSubtreeStatus` says `killed` too. `--every S`
sets how often it reads `status.m` (30 s by default), and `--match PATTERN` the command line that counts as the job
(`relation_sector.wls` prints it for its trials, which run under one command).

**When a job dies.** The runner keeps every finished point. Run the same command again: points whose reduction is
already there (same point, masters and pool) are kept, and the job resumes at the first missing one. An
out-of-memory kill at point 4 costs the identities' reload and point 4, not points 1 to 3. Before each point the
runner plans its threads again from the memory free at that moment. When even one thread no longer fits, it stops
with `refused`, names the other processes that hold the memory, and keeps the finished points; rerun when the
memory is back.

**Timings you can trust.** `times.m` (and `"PointTimes"` in `status.m`) has the wall-clock and CPU seconds of each
point. A point with far less CPU than wall-clock time (`"Starved"`, also in `run.log`) did not run most of the time:
the machine slept, or other jobs took the CPU or pushed it into swap. In a real run, two points of 15 minutes showed
3 hours that way. Plan from the other points, not from those.

What the runner does, so you can read `run.log`:

- **allowed sectors**: the roots, their subsectors, closed under LiteRed's maps (into other families too),
  under the symmetry rules, and under the sectors of system masters that map onto allowed sectors
  (`PreImage`);
- **seeds**: (rank, dots) on the roots and on sectors one propagator below the top; one more of each lower,
  two more dots for very low sectors, so the images of mapped integrals are reduced; `SeedBump` overrides
  one sector;
- **masters**: every system master whose integrals lie in the allowed sectors is an extra integral, so the
  reduction picks them as masters. A non-ut master means the subtree misses a host: the runner adds the
  sectors of system masters that map onto the same unique sector as roots and asks for a rerun (exit 4).
  When none exists, see "Masters the system lacks" below;
- **memory gate**: before learning, the equations are counted and the increment over the kernel's current
  memory predicted from the memory model; above 85% of the memory free at that moment (or the kernel would pass
  `MaxGB`) the job is refused (`status.m` says how much). Then lower the seeds, split the roots (one family at a time, images
  separately: `"Images" -> False` and its own job for the image), shrink the pool, or run elsewhere;
- **reconstruction**: only the rows of used integrals (`TakeUsed`), with the most threads the free memory allows.

- **pool**: what the structural reading needs, no more. Every pool integral and its derivatives are reconstructed at
  every point, so the time of a point grows with the pool; in a real run, with a generic pool, the FiniteFlow step
  took as long as the IBP reduction itself. By default (`"PoolSpec" -> {1, 1, 0, 0}`) it holds the root sectors' natural
  integrals (one dot or one numerator power, the pair scan's candidates) and the corners of their one-propagator
  subsectors; the runner adds to it the integrals of the root sectors' current masters, whatever their weight (a scan
  keeps a slot's master, and the checks at other points expand the sector's `ut[k]`; masters of lower sectors in a
  new definition need the wider pool of their rung). Add the structural reading's candidates and rung 2's dot moves
  (with their images) with `"PoolExtra"` (`--pool-extra` of `subtree_job.wls`; the template does both). A job
  written with the old default (`{2, 2, 2, 1}`) keeps its pool when it is called again without a `PoolSpec`. A
  rung that needs more widens the pool for its own job: pinched integrals with dots for the residue fit
  (`{1, 1, 2, 1}`), lower integrals for the completion solver (`{2, 2, 2, 1}`, the old default). Each integral's dots
  plus numerators are capped at the larger of the two. The runner warns above 150 pool integrals (`"PoolWarn"`).
  The seeds of every sector grow to reduce the pool, the masters and their derivatives (one more dot and numerator,
  plus one dot of margin), in the sector itself and in the sector it maps onto.

### Coefficients as functions

`bin/coefficients.wls run.wl job "{expr, ...}"` writes the analytic job `<job>_a`, which reuses the job's roots, seeds
and identities. It reconstructs the reduction of the expressions on a few masters (by default those of their own
sector, `--masters` for others) as functions of ε and the invariants. FiniteFlow samples the learned system as often
as the reconstruction needs, and each sample is one numerical solve, with no new identities. The runner checks the
result against the reduction at the job's first point and writes `analytic.m`. `--fix "{m2 -> 1}"` fixes the unit
scale to make it cheaper; the result then holds at that value only, and nothing is normalised from it. Use it for
every coefficient whose dependence on the invariants matters: the normalisation of a moved dot or of a scanned pair,
the denominators a completion's ansatz needs.

### Masters the system lacks

A subtree can miss a relation that only a sector outside it supplies. Its reduction then keeps a master that the
system does not have, an integral X of a lower sector, and every sector that contains X's sector inherits the
problem. Do not fall back on whole-family reductions for that tower: at every point they cost several times a
subtree reduction, for an answer you can get exactly another way.

1. **Keep X as an extra column.** `"AllowNonUT" -> True` in `PFBSubtreeJob`: the job stays a subtree job and
   `status.m` lists X under `"NonUT"`. It is part of the job's specification: for a job that already ran, write a
   new one (a new `"Name"`, with `"ReuseIds" -> "<old job>/ibps"`), since `"Replace"` would delete its identities. Its rows are exact, on one master too many. At the slice point that is
   already enough: the calibration expands X on the slice columns from the focus rows, so the slot and pair scans
   work as they are.
2. **Remove X exactly for everything else** (fits over several points, the gate's extra points, the completion
   solver): `bin/ws bin/extra_masters.wls run.wl job` writes the expansion job `<job>_x`, with the same points and X
   as its only pool, and roots large enough to reduce it. Run it, then `bin/ws bin/extra_masters.wls run.wl job
   --collect`: every reduction becomes one on system masters only. The raw ones stay as `raw_<ip>.m`, and the result
   is calibrated against the slice. Replacing X by its expansion is exact in ε at each point, because the rows are
   derivatives that were already reduced, so the expansion is never differentiated. The expansion job learns the
   large system once and reconstructs only X's rows at each point, so its points are cheap.
3. **Or close the subtrees once.** `bin/ws bin/relation_sector.wls run.wl job` writes learn-only trials, one per
   sector that contains X's sector and lies outside the subtree. Each trial adds that sector to the roots, asks for X
   (its only pool) and stops after learning: the sector removes X when X reduces to masters of the system. `--collect` writes `relation.m` with the smallest sector that removes every X. Give that sector to
   the tower's jobs with `"ExtraRoots"`; `extra_masters.wls` also uses it for the expansion job.

Reuse identities between jobs of overlapping subtrees: `"ReuseIds" -> "<job>/ibps"`; a sector is regenerated when
the earlier seeds were smaller (`ibps/seedsizes.m`). A job that is reused this way keeps its identities when it is
cleaned. A reconstruction that fails at a point other than the first leaves that point out: `status.m` lists it
under `"FailedPoints"`.

## 6. Changes and approval

### What the gate checks

`PFBTryChange` (`PFBTryRescale` for rung 1) accepts a change only when every check of `PFBGate` passes:

- **rules, letters, weights, Euler, frozen.** Rules 1, 2 and 4 on the new definitions (`ut[k]` terms through the
  integrals they stand for); with an alphabet (`"Letters"`), every denominator factor of a new coefficient is a
  letter; each new master has one mass dimension and keeps that of the master it replaces or is dimensionless; its
  rows satisfy the Euler relation of homogeneous integrals (checked when the slice has a derivative in every
  invariant of non-zero dimension); no master of a frozen family changes.
- **rows.** On the slice, exactly in ε, the sector's rows are free of finite poles. Rows above may keep the poles
  they had (their own sources come later, bottom-up). A correct fix of a lower master adds −R_rm λ to every row
  coupling to it, so they may also gain poles, which the gate defers to their own sector (`PFBDeferredPoles`) only
  when that sector can still change (not flagged, not fixed by an accepted change, no frozen family) and each new
  pole is one of these: a factor the change removed from its own rows, when all of that sector's poles, old and new,
  still factor through one proper subset of its masters (a sector of one master: unverified); or a moved pole, a
  factor that sector's rows had before the change (−R_rm λ carries the factors of R_rm into new columns), when the
  census as a whole loses bad entries. This is a necessary condition for that sector's own fix, not a guarantee.
  Any other new finite pole refuses the change, and `"DeferPoles" -> False` refuses them all. Deferred poles are
  shown on the sector's page, by `bin/sources.wls` and in `CHANGES.md` (`PFBDeferredObligations`), moved poles as
  such. A rescale (rung 1) cannot move a finite pole, so its rows only must not gain one.
- **census.** It loses bad entries (finite poles, negative powers of ε or entries above the cap) and gains no finite
  pole except deferred ones. New negative powers of ε pass only when some uniform ε^k lifts them without pushing
  any other entry below order 0 (entries that were already negative: below where they were), so never on the
  diagonal, and without lifting an entry above the cap.
- **degree.** No entry rises above ε^cap (`"MaxEpsDegree"`, default 2), its power being its degree at ε → ∞, finite
  poles or not: an entry above the cap before may keep its power until its own sector brings it down, but not raise
  it, also when a change removes its poles.
- **points.** Fitted coefficients (rungs 2 to 7, and a change that names no rung, unless `"Fitted" -> False`) hold
  at two or more further kinematic points that the fit did not use, distinct from the slice point and from each
  other, and at every one of them. A reduction at the slice point, or a second one at a point already given, is
  ignored and reported. A reduction that cannot be checked (integrals of the new masters outside its pool, masters
  the system lacks) refuses the change: leave it out, or reduce that point again.
- **maximal cut.** A change that alters the maximal cut (rung 8, or a scanned set that mixes the sector's masters)
  passes the maximal-cut-basis gate (Kira on the cut at two points, the Euler relation). A verdict given with
  `"MaxCutCheck"` is taken when it is Kira's on exactly this sector basis (the whole basis as it is now); otherwise
  the gate runs the check. A failed check refuses the change; Kira failing is no verdict, and the change comes back
  not tried; a machine without Kira skips the check, and `CHANGES.md` lists the change as not verified. ε-form on the
  cut is not required.

The determinant det T of the new masters on the replaced ones is recorded (`Determinant`), not judged: it only has to
be non-zero. A change takes the masters of one sector (a change with masters of another sector is not tried), since
these checks and the extra points cover the rows of that sector.

A move of the simplification phase (rung `"simplify"`, step 7) is judged by `PFBSimplifyGate` instead
(`reference/simplify.md`, "Acceptance"): the same rules, weights, frozen families, cap and maximal-cut check (one per
sector whose maximal cut it changes); no deferral and no new bad entry anywhere; the ε structure of every row (its
lowest power of ε does not drop, and an ε-form row or ε-form block stays so); and the measured kinematic degrees must
drop. Its extra points are the degree jobs' own points, not the reductions of the points check.

### Approval

`PFBTryChange` (and `PFBTryRescale`) record every attempt that reaches the gate; a change that comes back "not
tried" is not recorded (log it with `PFBAppendAttempt`). With `"Approval" -> False` (the default) a change that
passes the gate is accepted and its slice becomes current. With `"Approval" -> True` it is **pending**: stop, show
the user the change (its definitions, its gate, its ε-profile consequences, whether the maximal cut changed) and run
`bin/ws bin/approve.wls run.wl <id>` after a yes, or `bin/ws bin/approve.wls run.wl --decline <id> [reason]` after a
no (`PFBDecline`: the change goes to the rejected ones with the date and the reason, its slice is dropped, and its
sectors log it). A pending change is approved only while the slice it was proposed on is still the current one: once
another change has been accepted, `approve.wls` refuses it (exit 1), and it must be proposed again on the current
slice. Either way, a change of the maximal-cut basis is announced to the user when it happens, with the ε profile of
the sector rows before and after.

## Kinematic degrees

A pole-free basis can still have entries whose numerators and denominators have high degree in the invariants. The
degree census measures these degrees. It is not a gate rule and not a cap: the pole-free work never waits for it, and
the simplification phase (step 7, below) is where it is used. Run it when the user asks for degrees; the phase runs it
itself, and the starting degrees come with the slice (above). Its jobs are FiniteFlow's at every point, the slice
point included, whatever `"Reducer"` says ("Which reducer", above): they evaluate the learned system.

**What it measures.** For every entry of every derivative matrix in a sector's rows, a **term** is the entry at one
power of ε when it is a Laurent polynomial in ε with no power above the cap, and otherwise (finite poles, or a power
above the cap) the whole entry at one generic numerical ε, marked `"whole"`. For each term:

- the total degree of the numerator and of the denominator in the invariants, with the unit scale set to 1 (the
  `"UnitScale"` of the first family, as the reduction jobs use it), and the highest and lowest power of each invariant
  in both;
- the multiplicity of every known singularity of the sector's families (`PFBKnownSingularities`, `"Known"`: the
  letters and SOFIA's list, the unit scale set to 1) in the numerator and in the denominator. A known singularity that
  is the unit scale alone becomes a constant and is not seen;
- the **unexplained** degree: what the known singularities leave of the denominator (and of the numerator). It is a
  spurious factor of known total degree, without a name.

The summary, per sector and for the system: the degree of a term is the larger of its numerator and denominator
degrees; the highest degree, the number of terms at it, and the sum over terms (`PFBDegreeSummary`; compared in this
order, `PFBDegreeObjective`).

**How.** Only FiniteFlow's `FFAllDegrees`: nothing is reconstructed in several variables. A degree job learns the
sector's subtree like any reduction job (the sector and its images as roots, the slice point, no pool, the sector's
rows as focus), reduces the slice point (so that the collection can calibrate it), and then runs `FFAllDegrees` on
graphs built on the learned system (`lib/PFB/DegreeGraph.wl`): the rows in ε alone at a random point, which says which
entries are Laurent polynomials (their denominator is a power of ε); a FiniteFlow Laurent node up to each entry's
highest power; the whole entries at the numerical ε; and one more pass with each term multiplied (or divided) by a
power of each known singularity, which lowers the denominator (numerator) degree by its multiplicity. A known
singularity that is one invariant needs no pass: the lowest power of that invariant is its multiplicity. A known
singularity that is no rational function of the invariants (a letter with a square root) cannot be evaluated in a
graph: it is no probe (`PFBDegreeProbes`, `"NonPolynomial"`, said in the job's specification, the sector records and
the census text), and the moves of the simplification phase do not use it.

**Running it.** `bin/ws bin/degrees.wls run.wl [fam/jPATTERN ... | all]` writes one degree job per sector
(`jobs/deg_<fam>_<jPATTERN>`) at the current slice and prints one command that runs them one after the other. Start
it in the background, wait for each job with `bin/wait_job`, then `bin/ws bin/degrees.wls run.wl --collect [the same
sectors]`. The collection writes `degrees/degrees_NNN.m` next to `slices/slice_NNN.mx` and indexes it in `state.m`;
`census.wls` prints its summary and `summary.html` has a table per slice. A job refused for memory (before learning,
or before its degree graphs), one that failed, and one whose reduction does not calibrate exactly against the current
slice leave their sector **not measured**, with the reason. After an accepted change, measure again: the jobs are
written anew for the new slice and keep their identities.

**Cost.** A degree job costs a sector job at one point (identities, learning, the slice point) plus the degree graphs.
`FFAllDegrees` evaluates the learned system along lines: for the total degree and for each invariant, a few more
evaluations than the highest numerator degree plus denominator degree among the terms. An evaluation of the terms per
power of ε costs as many numerical solves as the entries' degree in ε needs (the Laurent node), one of the whole
entries one solve; the letter pass costs about as much again, and `--no-letters` skips it. One evaluation gives every
term, so the number of terms adds little beyond the univariate fits. On the one-loop box example a degree job takes
about 14 s, almost all of it loading LiteRed and the identities; the degrees themselves take less than a second. Before measuring every sector of a large system, measure one and time it (`timing-discipline`); a local
slice measures the whole system in one job, which can cost more than the slice itself.

**Probes on the same learned system.** `PFBDegreesJob[ctx, key, opts]` writes the job of one sector. With
`"Variants"` (each from `PFBDegreeVariant[name, <|label -> combination of ut[m]|>]`: a rescaling `r ut[i]`, a shift
`ut[i] + c ut[k]`, or a new master in integrals, a swap, which the job reduces and inverts inside its graph) the job
measures the DE after each change of basis on the same learned system, without learning again; with `"Samples"` (points: rules for ε and the invariants) it writes the exact rows of the DE, and of each
variant, at those points (`FFReconstructNumeric`, a few primes per point), at unit scale 1. `PFBReadDegreeJob` reads
both. Each variant costs a degree measurement of its own.

**det T along a line.** On demand only, never by default. `bin/ws bin/det_line.wls run.wl <change id>` writes a job
for a recorded change (accepted, pending or rejected): the sector's old and new masters of its base family, root-free,
reduced on the sector's current masters as functions of the parameter of one random line, at a numerical ε, with the
unit scale set to 1 (a univariate reconstruction of a few entries, checked at the line's base point). After the job,
`--collect` factors det T = det(new) / det(old) on the maximal cut, matches each factor with the family's known
singularities restricted to the line, and names the others as **spurious**: factors that the change brought and that
no known singularity explains (`detline.m` in the job folder). A simplification of the phase (rung `simplify`, no
sector key) is taken in the sector of the masters it replaced (a swap, a completion, a shift); one that replaced masters
of several sectors (a rescaling by letters) needs `--sector fam/jPATTERN`.

## 7. The simplification phase

Step 7 of `SKILL.md`, once the census has no bad entry outside flagged sectors, no change of the pole-free work
waits for approval and the slice has a derivative in every invariant but the unit scale: `bin/ws bin/simplify.wls
run.wl` refuses before that, with the reason (a hidden-weight hint on a clean sector does not block it: it is printed
as a note). It measures the degree
census of the current slice with one degree job per sector (it writes the jobs and the command; start it in the
background, wait for each job with `bin/wait_job`, then call the script again), proposes a budget for the moves from
the job times, and stops until the user answers: then `--budget proposed`, `--budget <seconds>`, or `"SimplifyBudget"`
in `run.wl`. Each move (some first write jobs of their own, such as a reduction to scan) then writes degree jobs that
measure its candidates as variants of the current basis, and the next call measures them and sends the best one that lowers the objective through the gate (rung `"simplify"`). Exit
code 4 always means: do what it printed, then call it again; 0 means the phase is done. `reference/simplify.md`
explains the objective, the moves, the gate, the records and how to add a move.

## 8. Finish

`bin/ws bin/make_reports.wls run.wl` writes the sector pages, `summary.html`, `export/`, `CHANGES.md` and
`CITATIONS.md` (what to cite, from the run's ledger `citations.m`; `CHANGES.md` repeats its "Cite" part). The
user's files stay untouched: `export/<fam>.m` are drop-in replacements for the masters files of the changed families
(point `"Masters"` in `system.wl` at them); editing the user's own files is done
only when the user asks. Then recommend regenerating the full DE once with the exported masters and running
the census on it; until that has happened, `CHANGES.md` says so. To record it, point `"File"` of `conventions.wl`
at the regenerated slice and import it with `bin/ws bin/import_slice.wls run.wl --regenerated`: the run is marked
as regenerated (`"Regenerated" -> True` in `state.m`) when the census of that slice is clean outside the flagged
sectors.

## Functions

| area | functions |
|---|---|
| run | `PFBStartRun`, `PFBReadRun`, `PFBLoadState`, `PFBSaveState`, `PFBCurrentSlice`, `PFBStoreSlice`, `PFBApprove` |
| system | `PFBReadSystem`, `PFBValidateSystem`, `PFBMasters`, `PFBMaster`, `PFBFamily`, `PFBImagesOf`, `PFBImageExpr`, `PFBSectorKeys`, `PFBSectorMasters`, `PFBRootDefs`, `PFBEpsPowers`, `PFBRuleViolations`, `PFBLetters`, `PFBMasterWeight`, `PFBMasterWeights`, `PFBEulerCheck`, `PFBImportLiteIBPFamilies` |
| slice | `PFBReadConventions`, `PFBImportSlice`, `PFBSaveSlice`, `PFBLoadSlice`, `PFBCalibrate`, `PFBSliceFromRed`, `PFBExprVector`, `PFBExprDVector`, `PFBDigitHeight`, `PFBRowsDigitHeight` |
| census | `PFBCensus`, `PFBCensusText`, `PFBCompareCensus`, `PFBEpsRange`, `PFBEpsOrders`, `PFBEpsFactors`, `PFBFinitePoles`, `PFBProfileCounts`, `PFBEpsDegree`, `PFBDegreeViolations`, `PFBSubtreeMasters`, `PFBCanChangeQ`, `PFBReopenText`, `PFBRowEpsProfile`, `PFBEpsFloorViolations`, `PFBEpsFloorWorseQ`; tests of the cap in `tests/eps_degree.wls` |
| residues | `PFBSourceTest`, `PFBSourcesByPole`, `PFBLaurent`, `PFBPoleOrder`, `PFBPrincipalPart` |
| structure (maximal-cut-basis toolkit) | `MCBLoopByLoopReport`, `MCBTwistFactors`, `MCBBoundaries`, `MCBMasterCount`, `MCBInfinityExponents`, `MCBBoundaryForm`, `MCBCutIntegrand` |
| reductions | `PFBSubtreeJob`, `PFBReducerChoice` (the Kira helpers of `lib/PFB/Kira.wl`, tests in `tests/kira_slice.wls`), `PFBSubtreeCommand`, `PFBSubtreeStatus`, `PFBCleanJob`, `PFBExtraMasters`, `PFBEliminateExtra`, `PFBExpansionJob`, `PFBCollectExpansion`, `PFBRelationTrials`, `PFBRelationReport`, `PFBAnalyticJob`, `PFBAnalyticCoefficients`, `PFBReadRed`, `PFBRedFiles`, `PFBImportMemory`, `PFBRandomPoints` |
| changes | `PFBChangeVectors`, `PFBApplyChange`, `PFBRescaleSlice`, `PFBReplaceMasters`, `PFBImageDefs`, `PFBDetMonomialQ` |
| rungs | `PFBRescaleSearch`, `PFBDotCandidates`, `PFBNormaliseCandidate`, `PFBNaturalIntegrals`, `PFBPinchedCandidates`, `PFBResidueFit`, `PFBNumeratorFromFit`, `PFBSPToNumerator`, `PFBNumeratorIntegrals`, `PFBCompletionSolve`, `PFBMonomialDegree`, `PFBGramFreeOperators`, `PFBApplyOperator`, `PFBOperatorVector`, `PFBDerivativeSearch`, `PFBWriteMCBBasisFile`, `PFBSolveLinear`; the tie-breaks of the scans and of the completion solver in `tests/tie_breaks.wls` |
| maximal cut (rung 8) | `PFBMaxCutRun`, `PFBMaxCutCandidates`, `PFBMaxCutFilter`, `PFBMaxCutJob`, `PFBWriteMaxCutCandidates`, `PFBReadMaxCutCandidates`, `PFBMaxCutScanCandidates`, `PFBMaxCutCheck`, `PFBMaxCutRank`, `PFBScanKey`, `PFBMaxCutAllDotQ`, `PFBMaxCutFinalists`, `PFBReadMaxCutFinalists`, `PFBMaxCutGateCheck`, `PFBMaxCutSummary`, `PFBMaxCutBasis`; tests in `tests/maxcut_rung8.wls` and `tests/maxcut_verdicts.wls` (planted), `tests/maxcut_kira.sh` (Kira on the cut), `tests/mcb_basis_file.wls`, and of the finalists' ranking (digit height last) in `tests/scan_height.wls` |
| gate | `PFBTryChange`, `PFBTryRescale`, `PFBGate`, `PFBScanSets`, `PFBSlotSets`, `PFBHiddenWeightScan`, `PFBDeferredPoles`, `PFBDeferredObligations`, `PFBVerifyAtPoints`, `PFBDistinctPoints`, `PFBBlockProfile`, `PFBRowsCouplingTo`; tests of the determinant, recorded and not judged, in `tests/determinant.wls`, of moved poles in `tests/moved_poles.wls`, of the extra points in `tests/extra_points.wls`, of one sector's masters per change in `tests/one_sector.wls` |
| records | `PFBRecordChange`, `PFBChangeKeys`, `PFBDecline`, `PFBWriteSectorRecord`, `PFBAppendAttempt`, `PFBRecordScan`, `PFBAppendNotes`, `PFBHiddenWeightTest`, `PFBHiddenWeightTried`, `PFBFixedSectors`, `PFBFlaggedSectors`, `PFBReopenedSectors`, `PFBCensusOptions`, `PFBFlagSector`, `PFBExportMasters`, `PFBWriteChanges`, `PFBMakeReports`; tests of the hidden weight on a clean lower sector (census hint, test, scan, flag) in `tests/hidden_weight.wls`, its edges (sectors that cannot change, a scan that cannot run, the clearing sets) in `tests/hidden_weight_hint.wls` |
| citations | `PFBRecordLiterature` (a paper outside a change), `PFBSliceCredits` and `PFBRecordSliceCredits` (`conventions.wl` `"Credits"`), `PFBImportMaxCutCredits` (a maximal-cut-basis run's credits of a sector, stamped with the change or the starting masters they went into), `PFBMaxCutRunDir`, `PFBStartCredits` (the `"MCBRun"` of the starting masters, for the sectors that keep one), `PFBWriteCitations` (every write of `CITATIONS.md`, the start credits first); in the reduction runner `lib/PFB/JobCitations.wl` (`PFBJobSector`, `PFBJobStep`, `PFBJobTools`, `PFBJobCitationEntries`, `PFBJobRunFolder`, `PFBAppendJobCitations`); the core's ledger (`CoreCitationContext`, `CoreRecordTool`, `CoreRecordPaper`, `CoreRecordOutcome`, `CoreImportCitations`, `CoreReadCitations`, `CoreSectorCitations`, `CoreWriteCitations`, `CoreCiteMarkdown`: `core/README.md`, "Citations"); tests in `tests/citations.wls` |
| degrees | `PFBDegreesJob`, `PFBDegreesCommand`, `PFBDegreeSpec`, `PFBDegreeProbes`, `PFBDegreeVariant`, `PFBReadDegreeJob`, `PFBJobDegreeRecords`, `PFBCollectDegrees`, `PFBReadDegrees`, `PFBStoreDegrees`, `PFBDegreeSummary`, `PFBDegreeObjective`, `PFBDegreeText`, `PFBImportDegrees`, `PFBUnitScale`, `PFBDetLineJob`, `PFBDetLineReport`, `PFBDetLineAnalysis`, `PFBDetLineText`; in the reduction runner `lib/PFB/DegreeGraph.wl` (`PFBFFMeasure`, `PFBFFDegrees`, `PFBFFExprGraph`, `PFBFFTransformGraph`, `PFBFFReplaceGraph`, `PFBFFSamples`, `PFBFFLine`); tests in `tests/degrees.wls` and `tests/degrees_example.sh`, and of the jobs' reducer (FiniteFlow at every point) in `tests/degree_reducer.wls` |
| simplification | `PFBSimplifyStep`, `PFBSimplifyPrecondition`, `PFBSimplifyBudgetProposal`, `$PFBSimplifyMoves`, `PFBWorstMasters`, `PFBMovableMasters`, `PFBSimplifySliceCheck`, `PFBSwapCandidates`, `PFBShiftProblem`, `PFBShiftFit`, `PFBFitJobCost`, `PFBCompletedMasters`, `PFBCompletionProblem`, `PFBCompletionFit`, `PFBRescaleModel`, `PFBPredictDegrees`, `PFBRescaleProgram`, `PFBRescaleCandidates`, `PFBRescaleFactor`, `PFBMCBNormalisations`, `PFBSimplifyGate`, `PFBObjectiveLess`, `PFBReadPhase`, `PFBSimplifyReport`, `PFBSimplifyMarkdown`, `PFBSimplifyHTML`; tests in `tests/simplify.wls`, `tests/simplify_swaps.wls`, `tests/simplify_fits.wls`, `tests/simplify_records.wls`, `tests/simplify_phase.wls`, `tests/simplify_maxcut.wls`, `tests/simplify_inputs.wls`, `tests/eps_structure.wls` (planted), `tests/simplify_example.sh` and `tests/simplify_moves_example.sh` (FiniteFlow jobs) |
| singularities | `PFBKnownSingularities`, `PFBRunSingularities`, `PFBReadSingularities`, `PFBSingularitiesFile`, `PFBSingularityOffers`, `PFBAttachSOFIALetters`, `PFBSingularityGraphs`, `PFBSOFIAGraph`, `PFBSOFIARename`, `PFBSOFIASymanzikCheck`, `PFBSOFIAKinematicsCheck`, `PFBNormalizePolynomials`, `PFBSOFIAPath`, `PFBSOFIAInfo`, `PFBSOFIALine`; tests in `tests/singularities.wls` |
| machine | `PFBResources`, `PFBMemoryBudget`, `PFBMemoryModel`, `PFBPredictMemory`, `PFBPlanReconstruction`, `PFBRecordMemory`, `PFBRunDir`, `PFBRunDirPath`; Linux and macOS readers (`lib/PFB/Machine.wl`, tests in `tests/machine.wls`): `PFBMachineMemory`, `PFBMemAvailableGB`, `PFBProcessRSSGB`, `PFBProcessAliveQ`, `PFBResetPeak`, `PFBPeakGB` |

Each has a `::usage` message.
