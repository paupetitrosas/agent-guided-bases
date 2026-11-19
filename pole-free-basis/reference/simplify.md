# The simplification phase

A pole-free basis can still have DE entries whose numerators and denominators have high degree in the invariants.
The simplification phase (workflow step 7, `bin/ws bin/simplify.wls run.wl`) lowers these degrees by changes of
basis that keep everything the pole-free work achieved. It measures with FiniteFlow's `FFAllDegrees` only and never
reconstructs an entry. The degrees, their letter content and the degree jobs are described in
`reference/workflow.md`, "Kinematic degrees".

## The loop

Run `bin/ws bin/simplify.wls run.wl` again after each thing it asks for. Each call does what it can without waiting:

| exit | `next` in its JSON | what you do |
|---|---|---|
| 4 | `jobs` | start `sh <run>/jobs/simplify_command.sh` in the background, wait for each job with `bin/wait_job <job folder> --timeout S`, then call the script again (the census, a move's own jobs, or the measurement of its candidates) |
| 4 | `budget` | show the user the proposed budget; after the answer call it with `--budget proposed` or `--budget <seconds>` (or set `"SimplifyBudget"` in `run.wl`) |
| 4 | `approval` | with `"Approval" -> True`: show the change, run `bin/ws bin/approve.wls run.wl <id>` after a yes or `bin/ws bin/approve.wls run.wl --decline <id>` after a no, then call the script again (a declined move is recorded as `declined` and the phase goes on with the next move) |
| 0 | `done` | the phase is finished (all moves tried, the budget used, or `"TargetKinDegree"` reached); run step 8. A later call says the same; `--new` starts a new phase (after more pole-free work), keeping the old record as `simplify/phase_<date>.m` |
| 1 | `refused` / `error` | the reason is printed: fix it, or tell the user |

In order, the script:

1. **Precondition.** It refuses while the census of the current slice has a bad entry (finite pole, negative power of
   ε, entry above the cap) outside flagged sectors, while a change of the pole-free work waits for approval, or when
   the slice lacks the derivative in an invariant other than the unit scale (an imported slice may hold fewer): the
   degree jobs measure the slice's derivative matrices only, so the objective would not see the others. Build the
   slice with every derivative (`bin/local_slice.wls`) or import one that has them. A hidden-weight hint of the census
   (a clean sector that may carry a weight, `reference/method.md`) never blocks the phase: its sector has no bad
   entry, and the sectors where its poles show are flagged (with `"Force"`, since `PFBFlagSector` refuses while the
   hint's lower-sector scan is not recorded). A hint whose scan was not recorded, on a sector that can still change,
   is printed as a note (`PFBSimplifyPrecondition` `"Hints"`): tell the user that the scan may still clear those poles.
2. **Degree census.** It needs a degree table of the current slice in which every sector was measured by a degree
   job of its own, with its job time and its letter content. Missing sectors get their jobs (`jobs/deg_<fam>_<jPATTERN>`),
   which the next call collects. A job that was killed, failed or was refused for memory is run once more (the call
   writes its command again; the command resumes it); a sector whose job fails a second time, or kept extra masters,
   stays **not measured**: the phase says so, works on the rest and changes nothing that would alter its rows.
3. **Budget.** From each sector's job time (the kernel's wall-clock seconds) and measurement time (the degree graphs),
   it proposes a budget for the moves: one round costs the sum over the measured sectors of (job time + 4 measurements),
   and the proposal is three rounds. Ask the user; `"SimplifyBudget"` in `run.wl` (seconds) overrides the proposal. A
   move whose estimated jobs (its own, then its measurement) do not fit what is left of the budget is not started, and
   the phase ends. A fit's job is estimated as the sector's census job plus one measurement per 100 samples, at least
   two (`PFBFitJobCost`); a reduction to scan as the census job plus two measurements.
4. **Moves**, in order (`$PFBSimplifyMoves`), each once per phase: move (i), the global letter rescaling, move (ii),
   swaps of the worst master, move (iii), shifts by lower masters, move (iv), lighter completions. `"SimplifyMoves"`
   in `run.wl` (a list of move names: `"rescale"`, `"swap"`, `"shift"`, `"completion"`) runs only those. A move that
   needs jobs of its own first (move (ii): a reduction of the sector to scan; moves (iii) and (iv): the samples of
   their fits) is **preparing**: the call writes them and stops, the next call gives the move their results, and the
   move then proposes its candidates. `"TargetKinDegree"` in `run.wl` ends the phase before a move once the highest degree is at
   or below it.

## The objective

Lexicographic, over the whole system (the measured sectors): the highest degree of a term, then the number of terms
at it, then the sum of the term degrees (`PFBDegreeObjective`; a term is an entry at one power of ε, or a whole
entry; its degree is the larger of its numerator and denominator degrees, unit scale 1). A move is accepted only when
the objective **measured** after the change is below the current one; a prediction never suffices.

## Acceptance

The chosen candidate goes through `PFBTryChange[ctx, None, <|label -> new master|>, <|"Rung" -> "simplify", ...|>,
<|"Degrees" -> <|"Before", "After", "Measured" -> True, "Jobs"|>|>]`. A simplification may change masters of several
sectors at once (key `None`). The change is applied exactly on the slice; a definition that only combines current
masters (`r ut[i]`, `ut[i] + c ut[k]`) needs no reduction, one with integrals needs `"Reds"` at the slice point. The
images of base masters come with the definitions (the move maps them). `PFBSimplifyGate` keeps the gate's rules,
letters, weights (mass dimension), Euler relation, frozen families and cap, and replaces the rows and census checks
(the determinant of the move is recorded, not judged):

- **rows**: no row gains a finite pole;
- **census**: no new finite pole, no new negative power of ε, no new entry above the cap (the census need not lose a
  bad entry);
- **eps-form blocks**: every sector whose own block (its rows and columns) is ε-form, or zero, keeps it so;
- **eps structure**: no row's lowest power of ε drops, and a row that is ε-form (every entry ε^1, or zero) stays so, in
  every derivative (`PFBEpsFloorViolations`). The phase lowers kinematic degrees only: a lower power of ε costs more
  at every order of the ε expansion than a lower degree saves. A swap, shift or completion that would put ε^0 into an
  ε-form row, or ε^-2 where a row had ε^-1, is refused on the slice before any job;
- **kinematic degrees**: the measured objective drops;
- **away from the slice**: each degree job reads the ε structure of its rows at a random point of its own; the measured
  rows of the candidate show there no finite pole, nothing above the cap, no negative power of ε that the census
  table did not show, and no row whose ε structure gets worse. The phase refuses such a candidate before the gate (the next best is taken) and gives the check
  to the gate, which records it (`not checked` for a change without a measurement at those points);
- **maximal cut**: a move that changes the maximal cut of a sector (a new master with a component on another master
  of its sector: a swap of a pair, or a swap in a sector of several masters) passes the maximal-cut-basis gate like any
  change of the maximal cut (`reference/workflow.md`, "What the gate checks"): `PFBTryChange` runs `PFBMaxCutCheck`
  (Kira on the cut at two points, the Euler relation) for each such sector once the other checks pass, a failed check
  refuses the move, Kira failing leaves it not tried, and a machine without Kira skips it (not verified). A move of
  several sectors has one check per sector, `maximal cut (fam/jPATTERN)`. Rescalings, shifts by lower masters and
  completions keep the maximal cut and need no check.

The record is that of any change (rung `"simplify"`, `"Simplify"` with the move, the candidate, the rescalings and
the objectives before, predicted and after), exported in `export/` and listed in `CHANGES.md`; with
`"Approval" -> True` it waits as pending. Once accepted, the variant's measurement becomes the degree table of the new
slice (provenance `"measured"`, with the move), so the next move starts from measured degrees. Each sector keeps the
times of its census job there (`JobWallSeconds`, `JobSeconds`), from which the budget and the fits' costs are
estimated; the variant job's own times are kept apart (`VariantJob`, `VariantJobWallSeconds`, `VariantSeconds`).

## Move (i): the global letter rescaling

U_i → r_i U_i with r_i = (unit scale)^k_i ∏_l l^a_il, l the usable letters of the master's family
(`PFBKnownSingularities`, `"Letters"`: the family's letters, SOFIA's only after the user's yes; a letter with a square
root, or one not homogeneous, is used neither here nor in the fits of moves (iii) and (iv)) and k_i fixed by the
mass dimension (r_i is dimensionless; k_i must be an integer, and k_i ≥ 0 when the unit scale is no letter, since a
letter check refuses it in a denominator). The ε structure is left alone: A_ij becomes (r_i/r_j) A_ij off the
diagonal, and the diagonal gains d log r_i at ε^0.

**Which masters.** Base-family masters; an image master follows its base master through the invariant map (a letter
whose image is not a product of known singularities is not used). A master is left alone (`PFBRescaleModel`,
`"Protected"`, with the reason) when its family or an image is frozen, its sector is flagged, its sector's own block is
ε-form or zero, or its row has no ε^0 term in some derivative (d log r_i would add an ε^0 term to its diagonal), its
rescaling would change rows of a sector that is
not measured, its image is missing from the slice, or no usable letter appears in its rows and columns.

**Prediction.** For a term of A_ij with letter content num_l, den_l (multiplicities of the probe of letter l), the net
exponent becomes num_l − den_l + a_il − a_jl, so its numerator and denominator degrees follow exactly; the part the
probes do not explain is unchanged. On the diagonal, the ε^0 term (or a whole entry) is bounded: its denominator gains
at most the letters of r_i that depend on the derivative's invariant and do not divide it already, and an entry
without an ε^0 term may gain one of at most that degree. With no rescaling the prediction equals the measured
objective.

**The program** (`PFBRescaleProgram`). An integer program over the a_il, bounded by |a_il| ≤ 2 (`--bound`; a
maximal-cut-basis normalisation outside the bounds widens them), minimises the predicted highest degree, then the
predicted sum of term degrees at that height (`LinearOptimization` with integer exponents, the positive and negative
parts of each net exponent, and a 0/1 variable for each letter on a diagonal; each stage is limited to 60 s,
`--solver-time`, and the program is skipped above 6000 variables). A coordinate search on the exact lexicographic
objective (steps of ±1 in one exponent, or in two when the mass dimension needs it) then starts from the program's
point, from no rescaling and from maximal-cut-basis's normalisations; ties go to the point closest to that
normalisation, or to no change. The search alone is a heuristic: it is what remains when the program times out.

**maximal-cut-basis's normalisations.** When the family's entry in `system.wl` has `"MCBRun"` (the folder of the
maximal-cut-basis run that produced its masters; read only), `PFBMCBNormalisations` compares each master's part on its
own sector's integrals with that run's rational elements of the sector (normalisation `"rational"`): a rational
multiple, free of ε up to a power of ε, is the rescaling the program starts from, and a candidate of its own. Without
the key, or for an element with a square root, nothing is taken.

**Candidates** (`PFBRescaleCandidates`): the program's rescaling (`ip`), the maximal-cut-basis normalisation (`mcb`),
and partial rescalings (`partial1`, ...: the masters of `ip` added one at a time, the best predicted first), those
predicted below the current objective (`mcb` whatever its prediction), at most 6. When there is none, the move ends
with `no gain` and no job.

**Verification.** Every candidate is a variant (`PFBDegreeVariant`) of the degree job of each sector whose rows it
changes (its rescaled masters' sectors and those whose rows have an entry in a rescaled column): one job per sector,
`jobs/simp<id>_<fam>_<jPATTERN>`, learned once, every candidate measured on it, the diagonal included. The measured
objective of a candidate is that of the census table with these sectors replaced by the variant's measurement. The
best candidate below the current objective goes to the gate; if the full rescaling does not measure lower, a partial
one that does is taken. A candidate whose job was refused or failed is not measured and cannot be chosen.

## The worst master

Moves (ii) to (iv) follow the worst entry. `PFBWorstMasters` ranks the masters by the terms of their row and of their
column in the degree table (an entry counted once), worst first by {highest degree, terms at it, sum}, and says
whether the worst terms sit in the master's row, its column, or both. A move takes the first master it may change
(`PFBMovableMasters`: a base-family master whose images follow by the maps; not one of a frozen family, of a flagged
sector, without its image, of a sector that is not measured, or whose change touches rows of a sector that is not
measured).

## Move (ii): swaps

The worst master is replaced by another integral of its sector, alone or together with one more master of the sector,
from the sets the scans find. Masters of a sector whose own block is ε-form or zero are left alone (a swap would put an
ε^0 term there).

**The reduction.** The scan needs a reduction of the sector at the slice point whose pool holds the sector's natural
integrals: the sector's own job (`jobs/<fam>_<jPATTERN>`) when its first point calibrates exactly against the current
slice, else a job the move writes, `jobs/simp<id>_scan_<fam>_<jPATTERN>` (the default pool, the identities of the
sector's degree job reused). The move is preparing until it is done.

**The sets** (`PFBSwapCandidates`). The master's slot alone, then pairs with each other base-family master of the
sector that may change too (`PFBMovableMasters`, option `"Partners"`), over the natural integrals of weight at most 1 in the pool (`PFBNaturalIntegrals`), at most 200 sets
(`"MaxSwapSets"`). A candidate equal to the current master is left out; the master's own integral alone is a candidate
when the master carries a lower part (a swap then drops it). Each candidate integral carries the slot's power of ε. A set is a swap
only when it keeps the census exactly on the slice: `PFBScanSets` finds the sector's rows free of finite poles, no new
pole above (nothing deferred) and nothing raised above the cap, and `PFBSimplifySliceCheck` finds no new pole,
negative power of ε or entry above the cap in the whole census, no ε-form block lost and no row whose ε structure
gets worse.

**Normalisation.** A swap must keep the master's mass dimension (the gate's weights check): the candidate integral is
multiplied by the power of the unit scale that restores it (`"unit"`), and, when the master's part on its own sector is
one integral, also by that integral's coefficient times such a power (`"inherit"`, the old master's normalisation).
Both are tried.

**Ranking.** By the digit height of the rows the swap changes on the slice (the master's rows and the rows that couple
to it; `PFBDigitHeight`: the digits of the coefficients in ε of each entry at the slice point, the helper that also
breaks the ties of the scans and of the completion solver), lowest first; the best
3 (`"MaxSwaps"`) are measured. The digit height costs nothing and follows the kinematic degree, but only the measured
objective decides.

**Measurement.** A swap's new master is written in integrals. Its variant in the degree job of each sector it touches
has `"TInverse" -> Automatic`: the job reduces the new master on the learned system and inverts T inside its graph
(`PFBFFReplaceGraph`), so nothing is reconstructed. The job of a sector above gets the whole block the swap changes,
even when its rows couple to one master of a pair: the row of T^-1 of that master, H_SS^-1 (e_S − H_SR), involves
every new master of the pair (the same for definitions in ut[k] that refer to each other). The gate gets the definitions with their images and the scan job's
reduction at the slice point (`"RedJob"`).

**Cost.** At most one reduction of the sector at the slice point (when its own job does not calibrate), the scan in
the script's kernel (each set is a change applied to the slice and, for the sets that clear the rows, a census: seconds
for a few dozen sets, not counted in the budget), and one degree job per touched sector with up to 3 variants. On the
one-loop box with a planted lower part on the box (tests/simplify_moves_example.sh) the reduction to scan takes 8 s,
5 sets are scanned and the box integral alone is the one swap.

## Move (iii): shifts by lower masters

U_i → U_i + Σ_k c_k U_k, for the row with the highest terms (`PFBWorstMasters`, by its row's terms; the first of the
3 worst rows a problem can be set up for), by the lower masters k of its family that its row couples to (a proper
subsector, coupled on the slice, not coupling back; at most 6, those that carry its highest terms first).

**The shift.** With T = 1 + e_i c^T (c_i = 0, c_k zero unless k is lower) and A_ki = 0, the new DE is exactly
- row i: A'_ij = A_ij + Σ_k c_k A_kj − A_ii c_j + ∂c_j + c_j (dlog pref_i − dlog pref_j), the last term from the
  root-free frame (`PFBExprDVector` writes it so); A'_ii = A_ii, and the columns the lower rows do not reach are kept;
- rows m above (coupling to i): A'_mj = A_mj − A_mi c_j.
Row i is affine in the coefficients of c; the rows above are not fitted, the measurement judges them.

**The ansatz.** c_k = ε^q_k Σ a φ: q_k is the power of ε of master i minus that of master k (hard rule 1: master k's
integrals take master i's power), and φ runs over the monomials of the invariants of total degree at most 2
(`"ShiftDegree"`), each made of the mass dimension of U_i/U_k by a power of the unit scale, and the same divided by one
letter of row i's terms in column k (`"ShiftLetters"`). A unit scale in a denominator only when it is a letter (or there
is no alphabet). At most 60 unknowns (`"MaxUnknowns"`): above, the letters go first, then the degree, then the last
lower masters.

**The fit** (`PFBShiftProblem`, `PFBShiftFit`). Nothing is reconstructed. The targets are every term of row i in the
columns the shift changes, at each power of ε of the Laurent range (from 0, or the lowest power the rows have, to the
cap): each must reach degree at most d, first d = (its highest term) − 1, then lower while a solution exists (at most
4 targets). On a random line x = base + τ v (positive integers: bases 20 to 99, directions 1 to 97), a term is N/Q
with N of degree at most d (its differences of order d + 1 vanish at equally spaced τ) and Q a product of the letters
of its contributions (A_ij, A_kj c_k, A_ii c_j, ∂c_j, the roots' dlog) of degree at most d, tried largest first. A term
whose old denominator has a factor no known singularity explains (its unexplained degree u > 0 in the degree table)
may also keep that factor: on each line the fit reads the old term's own denominator from its samples (a null vector
of N(τ) − A(τ) L(τ) P(τ) = 0, L its known letters, P of degree u; it needs its numerator degree + u + 3 points per
line, which the problem then takes unless the samples would exceed the cap) and tries Q = P times letters of degree at
most d − u. Only the term's own factor is used: a spurious factor that another contribution brings in is not. Each
ε^p coefficient comes from the samples at hi − lo + 1 values of ε; one more value checks that the samples agree with a
Laurent polynomial of that range at the sample points. That check is necessary only: it would see a pole in ε, or a
power above the cap, at those points almost surely, but says nothing elsewhere; the slice check and the measured rows
decide. The terms are taken in turn (the highest first), each narrowing
the solutions of one linear system over the rationals; the most complex unknowns (high degree, a letter below) are then
set to zero while a solution remains, and a last line, not used by the fit, checks it. The samples come from one job
(`jobs/simp<id>_fit_<fam>_<jPATTERN>`, a degree job of rows i and k with `"Measure" -> False`): enough lines for the
ansatz (at least 2, plus the check line), d + 4 points each, at hi − lo + 2 values of ε; at most 1000 samples
(`"MaxSamples"`). No point of a line is a zero of a known singularity, of an invariant, of a difference of two of them
(the unit scale included) or of a factor of a master's prefactor, and each of these keeps its total degree along the
line's direction: lines that fail are drawn again before the job is written. A sample without exact values (the
learned system could not be evaluated there) stops the fit with the reason.

**Candidates.** The solution at the lowest target, and the first one when it differs, with the images (the mapped
coefficients on the image masters). Each is applied exactly to the slice (`PFBSimplifySliceCheck`: no new pole, no new
negative power of ε, nothing raised above the cap, ε-form blocks kept); one that fails is refused, with the reason in
the move's `Info` (`"Refused"`), and a move whose candidates are all refused ends with `no gain`. The measured objective
decides as for any move.

**Cost.** One degree job of the sector's subtree without degree measurement: its identities (reused from the census
job), its learning and the slice point, then the samples, each a numerical evaluation of the learned system
(`FFReconstructNumeric`, a few primes). The fit itself is a linear solve of the size of the unknowns (seconds). On the
one-loop box (tests/simplify_moves_example.sh) the job takes 6 to 7 s for 140 samples, the fit 0.1 to 0.2 s for 14
unknowns, and each run of that test (census, budget, the move, its measurement) a little over two minutes.

## Move (iv): lighter completions

A completion (rung 6) fitted its coefficients for the poles, not for the degrees. Move (iv) takes the masters an
accepted completion wrote and no later change replaced (`PFBCompletedMasters`), those whose rows carry the highest
terms first, and solves their corrections again with degree as the objective.

**Same pool.** The correction integrals w are the lower-sector integrals of the current definitions, each keeping its
power of ε (hard rule 1). Their coefficients change by ΔC_w: a combination of monomials of the coefficient's mass
dimension (degree at most 2, `"CompletionDegree"`, also over a letter of the old coefficient's denominator) and of the
old coefficient itself, so that w may also drop out. A wider pool is rung 6's work, not the phase's.

**The fit** (`PFBCompletionProblem`, `PFBCompletionFit`) is that of move (iii) with the shift written in integrals: the
new master is U_l + Σ_w ε^n ΔC_w w, and its row is A_lj + Σ_w [∂(ε^n ΔC_w) r_w + ε^n ΔC_w (dr_w + dlog pref_l r_w)]_j
− Σ_l' A_ll' (Σ_w ε^n ΔC'_w r_w)_j over the completed masters l' of the change, with r_w and dr_w the vectors of w and
of its derivatives on the masters. One degree job of the completed rows gives the samples of the rows, r_w and dr_w
(`"SampleExprs"`), and reduces the pool at the slice point for the gate (`jobs/simp<id>_comp_<fam>_<jPATTERN>`). Each r_w
is rational in ε (an IBP reduction): only the sum must be a polynomial in ε of the range, so two values of ε beyond
the range check it. The targets are the terms of the completed rows in the columns the corrections reach (read from
the samples); their denominators are taken from the letters of the term, of its row and of the ansatz.

**Candidates** are the new definitions in integrals, with their images, applied exactly to the slice with the job's
reduction and checked by `PFBSimplifySliceCheck`; the measurement inverts them inside the degree jobs, as for a swap.

**Cost.** One degree job of the completed sector, as for move (iii), with the pool reduced at the slice point and two
graphs more for r_w and dr_w; the fit has the size of the corrections' ansatz (4 unknowns for one correction on the
planted box of tests/simplify.wls).

## Records and reports

`simplify/phase.m`: `Created`, `Status` (`open`, `done`), `Census` (the census jobs of the slice the phase started on, and `Retried`: the sectors whose jobs were run once more),
`Start` (after the pole-free work: slice, summary, per sector), `Proposal`, `Budget` (`Seconds`, `Source`, `Proposed`),
`Spent` (seconds of the moves' jobs, their own jobs included), `Moves` (each `Id`, `Move`, `Title`, `Slice`, `Before`,
`Status` (`no gain`, `skipped`, `over budget`, `preparing`, `measuring`, `accepted`, `pending`, `declined`, `not approved`, `rejected`, `not tried`, `stale`),
`Message`, `Candidates` (with `Objective` predicted and `MeasuredObjective`, or `Reason`), `Info`, `Jobs`, `Chosen`,
`Change`, `Gate`; a move with jobs of its own also `Prep` (what it needs to go on), `PrepJobs` (the last ones),
`PrepSpent`, `PrepCost` (estimated), `PrepStages`), `End`.
A simplification has no sector key: `PFBChangeKeys` gives the sectors of the masters it replaced, and its record
appears on their sector pages (with their status `pole-free (maximal cut changed)` when it changed their maximal cut),
in the summary's table of maximal-cut changes and in `CHANGES.md` under those sectors.
`summary.html` and `CHANGES.md` show the degrees by stage (the starting degrees when they were measured, after the
pole-free work, after the phase), per sector the degrees after the pole-free work and now with the unexplained
denominator degree, and the phase's moves with their candidates.
In the run's ledger (`citations.m`), each job of the phase credits its tools to its sector, the maximal-cut gate of
a move to the sector it checks, and anything else a move runs in the phase's kernel to the whole run, with step
"simplification move: <title>". A `PFBTryChange` with rung `"simplify"` records the papers of its info `"Reference"`
as any change does.

## Cost

A move costs one degree job per sector it touches: the sector's census job time (identities, learning, the slice
point) plus one measurement per candidate. The program and the predictions take seconds for a sector of a few masters.
On the one-loop box example (tests/simplify_example.sh) the whole phase takes about two minutes, mostly kernel starts.

## Adding a move

A move is an entry of `$PFBSimplifyMoves`: `<|"Name", "Title", "Propose" -> f|>`, with `f[ctx, table, phase, opts]`
returning `<|"Status" -> "proposed" | "no gain" | "skipped" | "jobs", "Message", "Candidates", "Info"|>`. Each candidate
is `<|"Name", "T" -> <|label -> new master|>, "Predicted", "Objective", "Info"|>`, with every changed master in `T`,
images included, as a combination of `ut[k]` or as a definition in integrals. The phase does the rest: the variant jobs
of the sectors `T` touches (their cost against the budget), the measured objective, the choice, `PFBTryChange` with
rung `"simplify"`, the records. Optional keys of a candidate: `"Variants" -> <|sector key -> variant|>` (a
`PFBDegreeVariant` or an explicit `<|"Name", "T", "TInverse", "Rows", "Probe"|>` for that sector's job, instead of the
one built from `T`), `"Defs"` (the new definitions the gate gets, default `T`) and `"RedJob"` (a reduction job whose
first point is the slice point and whose pool holds the integrals of `"Defs"`). A move whose new masters are integrals
(a swap) needs `"RedJob"`; its variants invert T inside the job (`"TInverse" -> Automatic`).

A move that needs jobs before it can propose returns `"Status" -> "jobs"` with `"Jobs"` (job folders), `"Keys"` (their
sectors, for the estimated cost: each the sector's census job time and two measurements, or `"Cost"` in seconds) and
`"Prep"` (what it needs to go on). The phase records it as preparing, checks the budget, writes the command, and once
the jobs are done calls `f` again with `opts` `"Record"` (the move's record, with `"Prep"`); `opts` `"MoveId"` is the
move's id, for naming its jobs (`jobs/simp<id>_...`). A move may ask for jobs four times at most.
