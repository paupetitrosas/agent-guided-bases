# The ladder

Climb it for one sector at a time, bottom-up, after the source test (`PFBSourceTest`). Try each rung at most
once per sector and session unless something changed (a larger pool, more points, a lower sector fixed).
Every proposal goes through `PFBTryChange` (or `PFBTryRescale`), which runs the gate and records the attempt;
add your own attempts and reasoning with `PFBAppendAttempt` and `PFBAppendNotes`, every paper you take something
from in the change (info `"Reference"`) or with `PFBRecordLiterature`, and every tool you ran by hand in info
`"Tools"` (`SKILL.md`, "Papers and tools you use").

Before rung 2, read the sector's structure (`method.md`, "Reading a sector's structure"): the bottom-up
reading of its rows and columns, the loop-by-loop Baikov representation, the subloop behind each factor, and
the candidate and subsector integrals that follow from it. Write that reading in `notes.md`. Every rung then
works with a pool built from it; a generic pool is only for when the targeted one has failed and you have
written down why.

| rung | name | when | how | typical cost |
|---|---|---|---|---|
| 1 | rescale | negative powers of ε in rows or columns, or entries above the cap; on the whole slice first | `PFBRescaleSearch` → `PFBTryRescale` | seconds, slice only |
| 2 | dot move | outcome `source` or `degree-source` and the source's definition has a dot | `PFBDotCandidates`, `bin/slot_scan.wls`, then `PFBTryChange` | slice; one reduction with the candidates in the pool |
| 3 | pair scan | every outcome but `undecided`, `lower-source` (fix the lower master first) and `pole-free`, once the structural reading is written; always before rungs 4 to 6 | `PFBNaturalIntegrals`, `bin/pair_scan.wls`, then `PFBTryChange` | minutes on the slice; the reduction of rung 2 |
| 4 | residue fit | outcome `source`; the source's sector has subsectors with pinched corners | `PFBPinchedCandidates`, `PFBResidueFit` | one reduction (pool of pinched integrals) |
| 5 | numerator | rung 4 gave integer coefficients, or the poles follow an ISP | `PFBNumeratorFromFit`, `PFBSPToNumerator`, `PFBNumeratorIntegrals` | none beyond rung 4 |
| 6 | completion | outcome `own-row` or `degree-own-row` once rung 3 found nothing, outcome `degree-source`, or rungs 2-5 found nothing | `PFBCompletionSolve` over every reduction point | reductions at 3+ points |
| 7 | derivative | sources are second-kind masters (dots, ISP powers) and no completion exists | `PFBDerivativeSearch`, then a reduction with the derivative integrals in the pool | slice for the choice, one reduction |
| 8 | maximal-cut | outcome `maximal-cut` (poles, negative powers of ε or entries above the cap in the own block), or every completion fails | `bin/maxcut_candidates.wls`, its job, `bin/pair_scan.wls --maxcut`, then `PFBTryChange` | candidate routes and one reduction; Kira on the cut for a few finalists |
| 9 | flag | the limits are reached and the hidden-weight test names no clean lower sector left to scan | `PFBFlagSector` with what was tried and what is left; it runs the test | none |

Outcome `undecided` starts no rung: fix or flag the sectors in `"WaitFor"` first, then run the source test again.
A clean sector that the census marks as a possible hidden weight (`"Next"`, source test `"HiddenWeight"`) has no
rung of its own: its lower-sector scan comes first (`method.md`, "A hidden weight on a clean lower sector"), then the
sectors where the poles show.

**Order by cost.** The numbers say what to try first, and the cost column says why: rungs 1 to 3 are exact on the
slice and take seconds to minutes, rungs 4 to 6 fit coefficients over several reduction points and can take hours.
After the structural reading, run the scans (rung 2 for a dotted source, rung 3 always) before any fit or completion,
and start rungs 4 to 6 only when `notes.md` says which entries and factors the scans left. In a real run, an hour of
completion searches went to a sector that a five-minute pair scan then solved. On the following sectors, starting
with the pair scan took minutes each.

## 1. Rescale

A master with a missing (or extra) uniform ε^k shows up as negative powers of ε in its row and high powers in
its column. Run it on the whole slice before the first sector. `PFBRescaleSearch` solves the difference constraints
for integer shifts with the smallest total, frozen families pinned, trying the tightest bound on the highest power
first (1, 2, up to the cap). It first asks every entry to end at or below the cap, entries above it included
(`"Strict" -> True`); when that is impossible it lifts the negative powers without raising any entry
(`"Strict" -> False`, `"AboveCapLeft"` counts the entries still above the cap). An entry with finite poles, measured
at ε → ∞ as the gate does, must in both cases end at or below the cap, or not rise when it is above it already. An infeasible bound returns a cycle
of couplings whose shifts contradict each other: those mixed powers are not a normalisation issue. Negative powers
that rung 1 leaves are poles at ε = 0 for the source test, sector by sector, bottom-up (rung 8 when they sit in a
sector's own block). `"MinimalCap"` says which cap
would have let a rescale lift them; it is information for the user, not a step.

## 2. Move a dot

For a source whose definition contains a dot. Two integrals of the sector with the same maximal-cut class differ
only by subsector integrals, and the IBP reduction of that difference can carry exactly the finite poles the rows
need (`method.md`, fact B). Moving the dot to another propagator of the sector is the cheapest way to get such an
integral, and it needs no fitted completion.

1. `PFBDotCandidates[sys, red, source]` lists the source's dotted integrals with one dot moved to each other
   propagator of the sector, numerators unchanged, and which of them are not in the reduction pool (add those
   with `PoolExtra`).
2. The structural reading usually says which dot to try first: a dot on a propagator of the subloop whose
   exponent produces the factor brings that factor, and a dot at a vertex whose subloop is clean does not.
   Sums of dotted integrals that are equal on the maximal cut belong to rung 8.
3. `bin/slot_scan.wls` ranks the candidates in the source's slot exactly on the slice: pole entries left in the
   sector rows, change of the census, entries raised above the cap, entries of the sector rows left above it and
   the highest power of ε there. A candidate that works leaves no pole in the sector rows and raises no entry above
   the cap; for a sector without poles, it leaves
   fewer entries above the cap. Candidates equal on all of these come in order of the digit height of the sector
   rows on the new slice (`PFBDigitHeight`: the decimal digits of their coefficients in ε at the slice point, summed
   over every entry; printed as `digit height`), lowest first: it costs nothing and grows with the kinematic degree.
   When its coefficient on the sector's other masters is zero, its maximal-cut class is the source's own.
4. Normalise the winner to the source's maximal-cut class: divide by its coefficient on the source, a power of ε
   times a rational function of the invariants. Reconstruct that coefficient, do not guess it:
   `bin/ws bin/coefficients.wls run.wl job "{candidate}"` writes an analytic job that reuses the job's identities.
   FiniteFlow then evaluates the learned system at as many points as it needs, each one a numerical solve, and
   returns the coefficient as a function of ε and the invariants, checked against the reduction at the first point.
   `--collect --source k` prints the normalised candidate (`PFBNormaliseCandidate`), or the factor such as
   (1 − 2ε) that makes it a hidden weight. Reading a product of letters off the values at three expensive reduction
   points is a guess, and a wrong guess costs a full round of reductions. Then propose the candidate with
   `PFBTryChange` and `"Rung" -> 2`. The normalisation still counts as fitted, so the gate confirms it at the extra
   points.

If no candidate removes the poles, go on to rung 3.

## 3. Pair scan

The sources need replacing together, or the right replacement is not a moved dot. Try the sector's natural
integrals in two or three slots at once, exactly on the slice. It costs minutes, so it comes before every fit.

1. Slots: the sector's masters when it has at most three (the default of `bin/pair_scan.wls`), otherwise the
   sources of the source test or of `PFBSourcesByPole` (`--slots`). Each slot may also keep its current master, so
   single replacements are scanned too.
2. Candidates: `PFBNaturalIntegrals`, the sector's own integrals with at most one extra dot or numerator power
   (`--weight 2` for more), and the candidates of the structural reading (`--cands`: dots on the subloop that
   produces the factor, differences of propagators, an extra ISP). Each integral carries the power of ε of the
   master it replaces. Natural integrals that the job's pool lacks are listed: add them with `PoolExtra` first.
3. The script counts the sets (at most `--max`, default 3000), times a pilot of five, and stops when the whole
   scan would exceed `--budget` minutes (default 30). Slots with the same prefactor and power of ε are
   interchangeable, so only one order of their candidates is tried.
4. Read the ranking: pole entries left in the sector's rows, whether the set changes the maximal cut, the entries
   raised above the cap (the gate refuses them), the entries of the sector's rows left above the cap (fewest first) and the highest
   power of ε there (lowest first among sets that are otherwise equal), and for sets that clear the rows, the census, new poles above (deferred or not) and negative
   powers of ε. Sets equal on every one of these come lowest digit height of the sector's rows first, as in rung 2.
5. Normalise the winner as in rung 2, step 4, and propose it with `PFBTryChange` and `"Rung" -> 3` (fitted by
   default). A set that changes the maximal cut is a maximal-cut change: `PFBTryChange` runs the maximal-cut-basis
   gate on it (rung 8), and you announce it to the user with the ε profile of the sector rows before and after.

No set clears the rows: write in `notes.md` which entries and factors stay, for the best sets, and go on to rung 4.
The scan records its best set and the poles it left in `attempts.m` (as `bin/slot_scan.wls` and `PFBTryChange` do):
the hidden-weight test reads them before a flag.

## 4. Residue fit

The sources and the required principal part come from the source test. Candidates: pool integrals of the
source's family in subsectors with one pinched propagator (`"MaxPinched" -> 2` for more; the default pool has only
their corners, so give this job `"PoolSpec" -> {1, 1, 2, 1}` for pinched integrals with dots). The fit is exact at the
slice point; the coefficients are numbers. Integer coefficients usually mean constants: read them as one
numerator (rung 5) and propose the master with that numerator. Non-integer coefficients need an x-dependent
ansatz: go to rung 6 with the same pool.

## 5. Numerator

Rewrite an ISP numerator as a scalar product linear in a loop momentum, or as the loop-by-loop Baikov variable,
completed by propagators of the sector so that it equals the ISP on the maximal cut. `PFBSPToNumerator` turns
a scalar product into propagators, `PFBNumeratorIntegrals` the numerator into integrals.

## 6. Completion solver

Give a pool that contains the candidate lower integrals (`PoolSpec`, `PoolExtra` of the job; the default pool has only
the corners of the subsectors, so widen it for this job, for example `"PoolSpec" -> {2, 2, 2, 1}`) and reductions at
3 or more points (the slice point first) for the fit, plus two that the fit never sees, for the gate: the template's
`fitReds` and `checkReds`. A fit checked on its own points always passes. `PFBTryChange` treats rungs 2 to 7 as
fitted (pass `"Fitted" -> False` for an exact candidate). A different base basis (`"Base"`) may mix the sector's
masters, as long as its own block is free of finite poles; corrections may carry negative powers of ε when the master
itself is written with one. The solver tries the lightest configurations first: integrals of weight
(dots + numerator powers) 0, 1, 2, ..., and for each weight one power of ε for all corrections of a master (its
own lowest power, then one below), so that every integral carries a single power of ε. It then drops the
heaviest integrals of the solution while a solution remains. Among unknowns otherwise equal it uses the monomials of
the ansatz of lowest degree in the invariants first (unit scale set to 1, `PFBMonomialDegree`), and of the
completions of equal weight it meets (its first solution and those it reaches while dropping integrals) it returns
the one whose new rows have the smallest digit height at the first reduction point, the slice point (`"Height"`).
Corrections use the master's own family unless `"SameFamily" -> False`. Many completions have the same effect on the DE (integrals with the same reduction are
indistinguishable); the lightest is the one returned. Its new rows end at or below the cap (`"MaxEpsDegree"`,
default the run's), entries above it now included, so a heavier configuration wins when the lightest would leave
an entry above it. A correction with an ε-monomial coefficient can bring a power down, so the solver also serves a
sector whose only bad entries are above the cap. When nothing brings every entry within the cap, it removes the
poles alone and keeps the powers above the cap the rows already have (`"AboveCapKept" -> True`): the sector stays
bad. `"Monomials"` sets the ansatz φ_b(x) (default: every
monomial of the right mass dimension), `"MaxPool"` caps the pool. No solution: enlarge the pool (dots first,
then numerators, then a second pinched propagator), then add points. A solution is accepted only after the
gate's extra-point check.

Choose the ansatz from what the coefficients are, not by enlarging it over more expensive points. When it is unclear
which denominators the φ_b need (a letter, a Gram determinant), reconstruct the reduction of a candidate correction
on the lower masters analytically (`bin/coefficients.wls` with `--masters` those masters) and read its denominators.
Then give `"Monomials"` accordingly. The analytic job reuses the job's identities and reconstructs only those few
entries; time a first one before relying on it for many.

## 7. Derivative construction

`PFBDerivativeSearch` lists the Gram-free operators (`PFBGramFreeOperators`, degree 1 by default) on each clean
master of the sector and keeps the combinations whose determinant on the sector block is not zero, fewest and
smallest operators first. Put the integrals of the chosen `"Defs"` in the pool of a new reduction (`PoolExtra`) and try them. The coupling rank decides first: when
every determinant is zero, derivatives cannot replace these sources.

## 8. Maximal-cut change

The maximal-cut-basis toolkit makes the candidates and checks the finalists; the full rows rank them. It works on the
family's run (`system.wl` `"MCBRun"`, only ever read; without one, this skill's own in `<run>/maxcut/<fam>/`, whose
`run.wl` maximal-cut-basis's scripts accept, e.g. `run_sector.wls` for a first pass with its Picard-Fuchs label).
The change that takes a candidate, or that the maximal-cut gate checks, brings that run's tools and papers of the
sector into this run's ledger with its id (`PFBImportMaxCutCredits`): cited while the change is accepted or pending,
consulted when it is rejected or declined. Candidates that no change takes bring nothing. The toolkit's tools used
here are credited to the sector too.

1. `bin/ws bin/maxcut_candidates.wls run.wl fam/jPATTERN [--cands "{...}"]`, in its own kernel: the run's basis of the
   sector, its candidate steps replayed from its `AnalysisMasters.m` (`MCBReplayCandidates`), the toolkit's candidate
   routes for the first representations (`--reps`, default 3: dlog candidates normalised by their leading
   singularities, curve candidates, single integrals; `--tlim` seconds each), and the structural reading's candidates
   (`--cands`: integrals, or root-free definitions such as a paper's canonical basis mapped onto the family; record
   the paper). Before any reduction it drops the candidates that break hard rule 1, 2 or 4 (the d-dimensional ones
   with coefficients rational in ε go) and those whose square root is not that of the master they would replace;
   each one left gets a root-free definition per slot, with the slot's lowest power of ε. At most `--max` (30) are
   kept: the run's basis first, then the replayed steps, the structural reading's and the routes. It writes
   `maxcut_candidates.m` to the sector folder (and `attempts.m`) and the job `<fam>_<jPATTERN>_maxcut`: the sector's
   subtree at the slice point and the extra points, the candidates' integrals and their images in the pool.
2. Run the job's command and wait for it with `bin/wait_job`.
3. `bin/ws bin/pair_scan.wls run.wl <job> fam/jPATTERN --maxcut`: the pair scan of rung 3 with these candidates
   besides the corner (each slot takes only those that keep its square root), ranked by the full rows (poles, the cap,
   deferred poles, the census); on a non-dlog sector (an ε-polynomial status or a Picard-Fuchs label
   that is not polylogarithmic) a set whose new sector basis has every element dotted is marked `all-dot`. The best
   `--finalists` (3) sets that clear the sector's rows go through the maximal-cut-basis gate in the same kernel
   (`PFBMaxCutCheck`: `MCBCheckBasis`, Kira on the cut at two points, exactly in ε, the Euler relation). A failed check
   (the Euler relation broken, dependent elements, a number of elements that is not the cut's) refuses a set; Kira
   failing or stopped at a limit is no verdict: the set is marked not checked and ranks after the checked ones. A DE
   rational in ε on the cut is not refused. The finalists are ranked by the full rows first, as the scan ranked them
   (`PFBScanKey`: poles, deferred poles, the census, negative powers of ε, the power of ε); among sets
   those keys rank equal, ε-form on the cut wins, then an ε-polynomial DE with the smaller spread of powers, then, on
   a non-dlog sector, a set with an undotted element, and last the smaller digit height of the rows (the scan key's
   last key, a free proxy that orders only sets equal on everything else). ε-form is never a requirement: the DE
   decides. The ranked
   finalists go to `maxcut_finalists.m` (`PFBReadMaxCutFinalists`) and `attempts.m`.
4. Send the first finalist through `PFBTryChange` with `"Rung" -> 8`, the job's reductions as `checkReds` and
   `"MaxCutCheck" -> fin[[1]]["Verdict"]`: the gate records that verdict as its check `maximal cut` when it is Kira's on
   exactly this sector basis (the whole basis as it is now); any other verdict, or an Association without its fields,
   is not taken and the check runs again (the record says why). Without a verdict, `PFBTryChange` runs the check itself
   for every change that alters the maximal cut (a rung-3 set that mixes the sector's masters included;
   `"MaxCutChanged" -> True` forces it, `False` never switches it off), once the other checks pass. Kira
   failing is no verdict: the change comes back `"not tried"` with the reason and is not recorded. On a machine
   without Kira the check is skipped by itself (`"MaxCutCheck" -> "NoKira"` says the same, and is refused where Kira
   is there); `CHANGES.md` then lists the change as not verified.

A determinant like (1 − 4ε) on a candidate the structural reading says is uniform weight means that the old basis
may carry that weight; the gate records it and judges the change by the DE (`method.md`, "Rules for a new master"). A
change of the maximal cut is always reported prominently, with the ε profile of the sector rows before and after and
the gate's verdict on the cut. A clean lower sector with a hidden weight (below) often needs a new maximal-cut basis:
run step 1 for it, and its lower-sector scan takes the candidates too.

## Before the flag: the hidden-weight test

A pole factor that no rung removes may not be this sector's: a master of a clean lower sector S can carry it as a
hidden weight, I_m = w J_m, which shows only in the rows above, in the columns of S's subtree (`method.md`, "A hidden
weight on a clean lower sector"). `PFBHiddenWeightTest[ctx, key]` reads the poles the recorded attempts left in the
sector's rows (the slice's rows when none recorded them): when a factor w left over always sits in the columns of
one clean lower sector's subtree, it names S and w. Then:

1. Reduce S's subtree at the slice point and the extra points (S's own job), and run the lower-sector scan:
   `bin/ws bin/pair_scan.wls run.wl <job> fam/jS --hidden-weight --factor "<w>"` (the factor is needed when the
   census has no hint of its own). Its candidates are S's natural integrals, `--cands` for the structural reading's,
   and S's maximal-cut-basis candidates when `bin/maxcut_candidates.wls` wrote them (rung 8, step 1; use its job).
2. A set that clears the rows above with S's rows pole-free goes through `PFBTryChange` with S's key, normalised, with
   `checkReds`. Its determinant usually carries w (1/w for I_m = w J_m); the gate records it. A set that mixes S's
   masters changes S's maximal cut, and the gate runs the maximal-cut-basis check on it (Kira on the cut, step 4 of
   rung 8).
3. Nothing clears them: the scan is recorded in S's `attempts.m`, and the flag of this sector goes through. A scan
   that cannot run (no slots, too many sets, over budget) is recorded too, with its reason, and the flag goes through
   as well; narrow it (`--slots`, `--cands`, `--keep`) and run it again when it should run.

`PFBFlagSector` runs the test itself and refuses, with the reason in `attempts.m`, while it names a sector whose
lower-sector scan for w is not recorded (and that is not flagged), and when the test cannot run (no system, no current
slice). The test never names a sector that cannot change (a frozen family, flagged); a sector fixed by an accepted
change is named, as reopened. `"Force" -> True` flags anyway; the test is recorded with the flag.

## 9. Flag

Record the reason and what is left to try (larger pools, more points, a different maximal cut, a cluster run
with larger seeds): `PFBFlagSector[ctx, key, reason, tried]`, after the hidden-weight test above. The summary lists
flagged sectors, and the sector page shows the test.

## Limits to respect

- Memory: every job checks its predicted memory before the learning step and refuses when it does not fit;
  split the roots, lower the seeds, or shrink the pool. `reference/workflow.md` says how.
- Licence: reductions run through `bin/ws`, one at a time unless the licence allows more.
- Frozen families never change.
- Compute: no search over large pools, many-term combinations or fitted ansätze before the structural reading
  is written down and a targeted candidate has failed. Time a pilot first.
