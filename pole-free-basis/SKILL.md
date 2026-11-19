---
name: pole-free-basis
description: Remove the eps poles of a Feynman-integral differential equation - denominators like 1/(1-2eps), 1/(1+4eps) or negative powers of eps - by changing master integrals without (a+b eps) factors, one family and one sector at a time, bottom-up, from an existing basis and a numerical slice of the DE. Finds which masters cause the poles (residue-column test), then subsector completions, numerator rewrites, derivative masters or a new maximal-cut basis, each checked exactly in eps. Use for pole-free or "honest" bases of a full system (several families, image families, square roots), or when the maximal-cut basis must change because of couplings to subsectors.
---

# pole-free-basis

The user has master integrals for one or more families and a differential equation (DE) for them, usually a
**slice**: the DE at one rational kinematic point, exact in ε. Some entries have finite ε poles (factors such
as 1 − 2ε in denominators) or negative powers of ε. Your job is to change the masters until the whole DE is
**pole-free**, working **bottom-up** one sector at a time, and to report the ε profile that results. ε-form
is not required; the profile says how far from it the system is. The powers of ε have a **cap**, ε² by default
(`"MaxEpsDegree"` in `run.wl`): an entry above it is a bad entry, fixed like a pole. A negative power of ε is a
pole at ε = 0, fixed the same way.

The toolkit (`lib/PoleFreeBasis.wl`, `bin/`) does the algebra and the reductions and checks every proposal.
The choices are yours: which sector next, which rung, which candidates, when to ask the user.

Every new master obeys the **hard rules**:

1. one power of ε per integral, with an ε-independent coefficient;
2. no (a + bε) factor and no ε in a denominator;
3. a uniform ε^k on a whole master is allowed;
4. coefficients rational in the invariants; the master keeps its square-root prefactor.

The rules constrain a master's **definition**, as written in the masters file. When a new honest master is
reduced onto the old basis, I'_m = I_m + Σ λ_S I_S, the coefficients λ_S may well contain 1/(1 + 2ε): IBP
coefficients carry such factors even between honest integrals, and λ is exactly what removes a pole. λ is what
the skill uses to update the slice; it never goes into a masters file (`reference/method.md`, "Rules for a new
master"). Nor is det T, the determinant of the new masters on the replaced ones, judged: it must not vanish, and the
record keeps it, but the DE alone decides. So a (1 + aε) weight on a master that no row shows as a pole is not
caught (`reference/method.md`, "What pole-free does not give").

Every proposal goes through `PFBTryChange` (or `PFBTryRescale` for rung 1), called **the gate** in these docs. It
accepts a change only when all of these hold (`reference/workflow.md`, "What the gate checks", has each in full):
- the new definitions obey rules 1, 2 and 4; with an alphabet (`"Letters"`) every denominator factor is a letter;
  each new master has one mass dimension, that of the master it replaces or none, and satisfies the Euler relation;
  no master of a frozen family changes; every master it replaces belongs to the sector you pass (else: not tried);
- on the slice, exactly in ε, the sector's rows are pole-free and the census loses bad entries (finite poles,
  negative powers of ε, entries above the cap). Rows above keep the poles they had; a new pole there is deferred to
  its own sector (`PFBDeferredPoles`) only when that sector can still change and the pole is a factor the change
  removed from its own rows or a moved pole (a factor that sector's rows had); any other new finite pole refuses;
- a new negative power of ε passes only where a uniform ε^k lifts it (never on the diagonal), and no entry rises
  above ε^cap (`"MaxEpsDegree"`, default 2, the degree at ε → ∞): an entry above the cap before may keep its power;
- fitted coefficients (rungs 2 to 7, and a change that names no rung, unless `"Fitted" -> False`) hold at two or
  more further points that the fit did not use, distinct from the slice point and from each other, and at every one
  of them;
- a change that alters the maximal cut (rung 8, or a scanned set that mixes the sector's masters) passes the
  maximal-cut-basis gate (Kira on the cut at two points, the Euler relation), which the gate runs unless you give its
  verdict (`"MaxCutCheck"`, taken only when it is Kira's on exactly this sector basis): a failed check refuses, Kira
  failing leaves the change not tried, a machine without Kira skips it (listed as not verified); ε-form is not needed.
A move of the simplification phase (step 7) passes the gate with the phase's checks. Nothing else changes the basis.

This skill needs the maximal-cut-basis skill next to it (`../maximal-cut-basis`), or the environment variable
`PFB_MCB` set to the path of its `lib/MaximalCutBasis.wl`.

## One family, one sector at a time

The system may hold several families, but work on one family, and inside it on one sector, at a time.

- **One sector.** Take the sector the user names, or else the lowest bad sector of the current family that the
  census does not mark as possibly inherited (the census's `"Next"` when you start). Take it through step 5 below
  until the gate has accepted a change, the census marks its poles as inherited, or the sector is flagged. Only then
  run the census again and open the next sector. Never run reductions, ladders or slot scans for two sectors at once.
- **A clean sector can be next.** When every column of a pole factor w lies in the subtree of one clean sector S (not
  flagged; one fixed by an accepted change is reopened), the census marks S and makes it `"Next"`: one of its masters
  may be w J with J honest (`reference/method.md`, "A hidden weight on a clean lower sector"). Reduce S's subtree and
  run its lower-sector scan, `bin/ws bin/pair_scan.wls run.wl <job> fam/jPATTERN --hidden-weight`; the scan is
  recorded, also when it cannot run, and when it finds nothing the sectors where the poles show come next.
- **One family.** After a fix, take the next bad sector of the same family before those of other families. Move
  to another family when this one has no bad sector left, or when its next sector waits on a lower bad sector of
  another family: fix that lower sector first, still one at a time. A change to a base family carries over to
  its image families through the maps; they are not separate work.

Bottom-up order matters because a fix in a lower sector changes the rows of every sector above it, so a sector
fixed before the sectors below it may have to be done again.

## Setting up (once per machine)

Run `bin/ws bin/preflight.wls [paths.wl]`. It reports the tools (FiniteFlow, its library, LiteRed and LiteIBP
are needed for reductions), the licence, the memory, and the memory model of this machine, which calibrates
itself from earlier runs. You are done when you can tell the user which steps are available and how large a
reduction fits. Start every Wolfram script through `bin/ws`: it waits for a free licence slot (a lock shared with
the maximal-cut-basis skill), closes stdin, and runs the script and everything below it under a time and a memory
limit (24 h and an equal share of 90% of the memory per licence slot by default; `--timeout S`, `--memory GB`;
`bin/ws --list` shows every job and its limits, `bin/ws --set PID ...` changes them). A reduction job takes
`"TimeLimit"` and `"MaxGB"` from `job.m` (from `run.wl` by default). A job stopped at a limit exits with 124 (time) or
137 (memory); raise a memory limit only when the machine has the memory, and tell the user when you change one. The
maximal-cut-basis skill's `reference/limits.md` explains the limits of both skills in full.

## What you need from the user

- `system.wl`: the families (in maximal-cut-basis `family.wl` format; `bin/import_liteibp.wls` converts LiteRed/LiteIBP
  files) and, when there is one, the maximal-cut-basis run of each that produced its masters (`"MCBRun"`), image
  families as momentum maps, the masters files, the roots, the master order, optional symmetry rules, the frozen
  families. Start from `templates/system.wl`. Any list of master definitions works as a masters file, the
  `masters.m` of a maximal-cut-basis run included.
- The slice and its `conventions.wl` (point, derivatives, labels, root frame, and `"Credits"`: the tools and papers
  that produced it), or permission to build one locally when it fits. Start from `templates/conventions.wl`.
- `run.wl` (`templates/run.wl`): output folder (persistent, never `/tmp`), `"Approval"` mode, targets, the cap on
  the power of ε (`"MaxEpsDegree"`, default 2: entries above it are fixed), seeds.

Whatever is ambiguous goes to the user as a question: conventions of the slice, master order, which families
are images, roots, what may change. The validation lists such questions; ask them instead of assuming.

## The workflow

| # | step | command | you're done when |
|---|---|---|---|
| 1 | validate the system | `bin/ws bin/validate_system.wls system.wl` | no errors, and every question has the user's answer in `system.wl` |
| 2 | import the slice | `bin/ws bin/import_slice.wls run.wl`, or build it locally with `bin/ws bin/local_slice.wls run.wl` when it fits (`reference/workflow.md`) | the run has a current slice and a census (a local slice also its starting degrees) |
| 3 | calibrate | `bin/ws bin/subtree_job.wls run.wl fam/jPATTERN 0`, run the printed command, `bin/ws bin/calibrate.wls run.wl <job folder>` | the calibration says `exact` (otherwise ask the user which convention differs; change nothing until it is exact) |
| 4 | census | `bin/ws bin/census.wls run.wl` | you know the bad sectors bottom-up, and which one is next (previous section) |
| 5 | fix that one sector | `bin/ws bin/new_sector.wls run.wl fam/jPATTERN`, then work in its `AnalysisPoles.m` | the gate accepted a change that leaves the sector's rows pole-free (entries above the cap it leaves bring the sector back as `"Next"`), or the census marks its issues as inherited, or the sector is flagged after the ladder; its jobs are cleaned (`PFBCleanJob`); the user has been told the outcome |
| 6 | repeat | back to 4, for the next sector | the census has no finite poles, no negative powers of ε and no entry above the cap, or every remaining bad sector is flagged |
| 7 | simplify | `bin/ws bin/simplify.wls run.wl`, again after each job, budget answer or approval it asks for ("The simplification phase" below) | it exits 0: every move was tried, the budget is used, or the highest degree is at or below `"TargetKinDegree"` |
| 8 | report | `bin/ws bin/make_reports.wls run.wl` | `summary.html`, `CHANGES.md`, `CITATIONS.md` and `export/` are up to date and the user has been told what changed |

Optional, after step 1: with SOFIA installed, `bin/ws bin/singularities.wls run.wl` lists each family's candidate
singularities (`reference/workflow.md`, "Known singularities"); a family without `"Letters"` takes them as letters only
after the user's yes (`"LettersFromSOFIA"` in `system.wl`).

**Kinematic degrees** are measured, never a gate rule: the degrees in the invariants (unit scale 1) of every entry's
numerator and denominator and the known singularities they contain, from `FFAllDegrees` (nothing reconstructed; degree
jobs are FiniteFlow's at every point). The local slice measures the starting degrees (`--no-degrees` skips them), or
the user gives them with an imported slice (`"Degrees"` in `conventions.wl`). Steps 1 to 6 do not need them: run
`bin/ws bin/degrees.wls run.wl [fam/jPATTERN | all]` when the user asks; step 7 runs it itself. `bin/det_line.wls`
names the spurious factors of a change's determinant (`reference/workflow.md`, "Kinematic degrees").

Step 5 in order: the source test (`PFBSourceTest`), the structural reading (next section), a reduction of the sector's
subtree at the slice point and the extra points with the pool that reading gives (the sector's natural integrals by
default, plus the reading's candidates; every pool integral costs time at every point, so widen it only for a rung that
needs it), its calibration, then the ladder, cheapest first (next sections). Kira reduces the slice point when the
subtree lies in one family (minutes, no FiniteFlow learning), FiniteFlow the other points (`reference/workflow.md`,
"Which reducer"). A job's roots include the sector's images by default (`"Images" -> True`): such a subtree spans
several families, and FiniteFlow reduces its slice point too, unless the job is written with `"Images" -> False` and no
other map brings in another family. Reductions run in the background from the shell (they need a licence slot of their
own); each job refuses to learn when its predicted memory does not fit. Wait for a job with `bin/wait_job <job folder>
--timeout S`: it holds no licence slot, always ends, and tells a finished job from a refused, killed or stalled one;
never write a wait loop of your own. A killed job resumes at its first missing point when its command runs again. When a
subtree keeps a master the system does not have, keep it as an extra column (`"AllowNonUT" -> True`) and remove it
exactly with `bin/extra_masters.wls`, or find once the sector that supplies the relation (`bin/relation_sector.wls`);
never switch a tower of sectors to whole-family reductions for it. `reference/workflow.md` covers what to read after
each step, sizing and splitting reductions, approval mode, and the function list.

## Read the structure before you compute

For each bad sector, before any reduction or search (section 2b of the template `AnalysisPoles.m` runs steps 1 and 2):

1. **Read the rows.** Which columns carry each pole factor and each entry above the cap, and so which lower
   sectors a fix must reach. `PFBSourcesByPole` gives, per factor, the smallest sets of the sector's masters whose
   replacement can remove it, and whether the sector's own block carries it; ε → ∞ counts as one more pole when
   the rows have entries above the cap, and ε = 0 (factor ε) when they have negative powers of ε. A pole, a
   negative power of ε or an entry above the cap in the own block calls for a new maximal-cut basis. Otherwise each
   source needs an honest replacement with a singular relation to it (rungs 2 to 7), even when every master of the
   sector is a source. Do not count sources by the rank of the principal parts: one source can give principal parts
   of full rank (`reference/method.md`, "The source of a pole").
2. **Read the maximal cut loop by loop.** `MCBLoopByLoopReport` (maximal-cut-basis toolkit), for every loop
   order, with the current masters and their dotted variants as `"Integrals"`. Match each factor to its source:
   the exponent of a subloop's Baikov polynomial or external Gram determinant, or the cost `n + 1 + E_v` of a
   numerator power at infinity (an ISP-power basis pays it). Compare the number of masters the representation
   sees with and without the factors whose exponent is O(ε): the difference lives on their zero sets, the
   report gives the geometry there (a curve means first-kind forms), and the integrands of those masters need a
   simple pole on that boundary.
3. **Build the candidates from that reading.** Dots on the propagators of the subloop whose polynomial produces
   the factor (one dot gives ε × a simple pole on its boundary; the report shows the boundary form it
   induces), numerators that vanish on the cut (a difference of two propagators), an extra ISP when a puncture
   of the boundary is not reached, and the subsector integrals they bring.
4. **Only then compute,** with that small pool: fix the masters the reading determines, try the remaining
   slots one at a time with `bin/slot_scan.wls`, or two or three at once with `bin/pair_scan.wls`, and send the
   result through the gate.

This reading is the main way to find candidates, not a way to order them. Large generic searches come last,
after a targeted candidate has failed and the reason is written in `notes.md`. `reference/method.md` has the
details and an example.

## The ladder

Work up from the bottom for one sector, guided by the source test, and stop at the first change the gate
accepts:

1. **rescale**: uniform ε^k on whole masters (`PFBRescaleSearch`);
2. **dot move**: a dotted source replaced by the same integral with the dot on another propagator of the sector,
   ranked exactly on the slice (`PFBDotCandidates`, `bin/slot_scan.wls`);
3. **pair scan**: the sector's natural integrals (few dots and numerators, plus the structural reading's
   candidates) in two or three slots at once, exactly on the slice (`PFBNaturalIntegrals`, `bin/pair_scan.wls`);
4. **residue fit**: the required principal part from pinched corners (`PFBResidueFit`);
5. **numerator**: integer fits read as a scalar-product numerator (`PFBNumeratorFromFit`);
6. **completion**: lower integrals, one ε power each, fitted over all points (`PFBCompletionSolve`);
7. **derivative**: sources replaced by Gram-free derivatives of clean masters, coupling rank first
   (`PFBDerivativeSearch`);
8. **maximal-cut**: a new maximal-cut basis from maximal-cut-basis's candidates (`bin/maxcut_candidates.wls`), ranked
   by the full rows (`bin/pair_scan.wls --maxcut`), the best few through its gate;
9. **flag**: record what was tried and what is left (`PFBFlagSector[ctx, key, reason, tried]`). It runs the
   hidden-weight test first and refuses while the factor the attempts left always sits in the columns of one clean
   lower sector's subtree and that sector's lower-sector scan is not recorded: open that sector instead.

**Coefficients are reconstructed, never guessed.** A normalisation or any other coefficient that depends on the
invariants is reconstructed by FiniteFlow as a function, from many cheap evaluations of the learned system
(`bin/coefficients.wls`, `PFBNormaliseCandidate`). Fitting a product of letters to its values at three expensive
reduction points is a guess.

**Cheapest first, as a rule.** Structural reading, then the scans of rungs 2 and 3, then fits and completions.
The scans take minutes, need one reduction at the slice point, and are exact. Fits and completions need
reductions at several points and can run for hours without finding anything. Start rungs 4 to 6 only when
both scans have failed and `notes.md` says which entries and factors they left. A sector of two or three
masters is scanned whole. In a real run, an hour of completion searches went to a sector that a five-minute pair
scan then solved. A set the pair scan finds can change the maximal cut: it then passes the maximal-cut gate and
is announced like a rung-8 change. Ties between sets or completions that are otherwise equal go to the smaller digit
height of the rows on the slice, a free proxy for the kinematic degree (`reference/escalation.md`).

**Entries above the cap, and negative powers of ε.** An entry above ε^cap is a bad entry, fixed bottom-up like a
pole: the source test reads it as a pole at ε → ∞ (outcome `degree-source`; corrections with an ε-monomial
coefficient may bring it down, unlike for a finite pole), rung 1 lowers it when a uniform ε^k can, the scans rank
sets by the entries they leave above the cap, and the completion solver asks for every entry at or below it. A
negative power of ε is a pole at ε = 0: run rung 1 on the whole slice first, then the source test treats those left
in a sector's rows towards lower masters like a finite pole. Either kind in the sector's own block calls for a new
maximal-cut basis (rung 8). Never raise the cap to make a change pass; raising it is the user's decision.

Log each attempt (`PFBTryChange` and the scans do, with the poles each left in the sector's rows; `PFBAppendAttempt`
for the rest, a change not tried included) and write the reasons in `notes.md` (`PFBAppendNotes`).
`reference/escalation.md` explains each rung, its cost and when to move on.

## The simplification phase

Once the census is clean outside flagged sectors (and the slice has a derivative in every invariant but the unit
scale), step 7 lowers the kinematic degrees of the DE. The objective, over the whole system: the highest degree of a
term, then the number of terms at it, then the sum. A move changes the basis only when `FFAllDegrees` measures that
the objective drops and the change keeps the census on the slice and at the degree jobs' own points (no new pole, no
entry above the cap, no new negative power of ε), the hard rules, the mass dimension, the frozen families and the ε
structure (no row's lowest power of ε drops, an ε-form row stays so); a move that changes a sector's maximal cut
passes the maximal-cut-basis gate too. It goes through `PFBTryChange` with rung `"simplify"` and the approval mode
of any change. The script first
measures every sector in a degree job of its own and proposes a budget from the job times: ask the user before giving
`--budget`. The moves: (i) rescalings by products of letters times a power of the unit scale (an integer program over
the letter content); (ii) the worst master swapped for another integral of its sector that the scans find; (iii) the
worst row shifted by lower masters and (iv) fitted completions solved again, both fitted to a low-degree ansatz from
samples of the learned system. A sector whose degree job does not fit in memory is not measured, and the phase leaves
its rows alone. `reference/simplify.md` has the details.

## Papers and tools you use

A paper can settle a sector: a known canonical or uniform-weight basis of the sector or of its subsectors, a
numerator, a derivative construction, the geometry of a cut. Put a paper behind a proposed change into the change
(`PFBTryChange` info `"Reference"`, `"Used"`), and a tool you ran by hand for it into info `"Tools"` (names from
`reference/tools.md`; an unknown one leaves the change not tried): the change records both, whatever its outcome.
Record anything else from a paper straight away, even if it led nowhere, so that its authors are acknowledged:

```mathematica
PFBRecordLiterature[runDir, {fam, sector}, <|"reference" -> "authors, title, journal, arXiv:xxxx.xxxxx",
  "used" -> "what you took and how it was mapped onto this family", "rung" -> n, "result" -> "used"|>]
```

Use `None` for the whole run, and `"result" -> "rejected"` if it led nowhere. Take the reference from arXiv or
INSPIRE, never from memory. The run's ledger, `citations.m`, also gets the toolkit's tools and the credits of the
maximal-cut-basis sectors used. Report what `CITATIONS.md` says to cite; ask the user to acknowledge the authors.

## Changes of the maximal-cut basis

The usual pipeline: maximal-cut-basis first (one run per family; the masters usually come from it), then a numerical
slice of the full DE, then this skill. Name each family's run in `system.wl` (`"MCBRun"`, only ever read); without
one, this skill makes its own in `<run>/maxcut/<fam>/`. When a sector's maximal cut must change, this skill drives
that toolkit and the DE decides: candidates from the run and the toolkit's routes, filtered by the hard rules and the
square root of the master each replaces before any reduction, ranked by the full rows, and the best few through the
maximal-cut-basis gate. A failed check refuses a set; ε-form on the cut breaks ties among the sets the full rows rank
equal (then the smaller ε-polynomial spread, then, on a non-dlog sector, a set with an undotted element, then the
digit height), and is never a requirement. `reference/escalation.md`, rung 8, has the commands.

Tell the user about every change that alters the maximal-cut basis as soon as it is proposed: which sector, the
determinant, the maximal-cut-basis gate's verdict, and the ε profile of the sector rows before and after. The summary
page and `CHANGES.md` list these changes first. With `"Approval" -> True` every change that passes the gate waits as
pending: show it to the user and accept it with `bin/ws bin/approve.wls run.wl <id>` only after a yes, while the
slice it was proposed on is current (after a no, `bin/ws bin/approve.wls run.wl --decline <id> [reason]`).

A clean master can carry a hidden weight: I_m = w J_m (w = 1 + 4ε, J_m honest) keeps its own rows clean and puts
1/w into column m of every row coupling to it (I_m = J_m / w: into row m, towards lower masters). The honest
replacement has a determinant 1/w (or w) on the old basis; the gate records it and judges the change by the DE, like
any other (`reference/method.md`, "A hidden weight on a clean lower sector").

## What comes out

What the user reads: `summary.html` (maximal-cut changes first), `CHANGES.md` (every change, why and how, what is
not verified, what to cite), `export/<fam>.m` (drop-in replacements for the changed families' masters files),
`CITATIONS.md` (what to cite), and one folder per sector with its page `sector.html` and your `notes.md`. What the
toolkit needs to carry on: `state.m`, `run_info.m`, `citations.m`, `slices/`, `degrees/`, `simplify/`,
`singularities/`, and in the sector folders `basis.m`, `masters.m`, `attempts.m` and `AnalysisPoles.m`.

The reduction jobs (`jobs/`) are the bulky part. When a sector is done, run `PFBCleanJob` on its jobs: the
identities and other scratch go, and what is needed to read or rerun the job stays. Add nothing else to the run
folder: logs of your scripts, trial basis files and other scratch work belong in a temporary folder outside it.

The user's own files change only when the user asks. Finish by recommending one regeneration of the full DE with
the exported masters and a census of it; `CHANGES.md` lists what was not verified until then.

## Where to read more

- `reference/method.md`: for every bad sector before computing anything (the structural reading), before choosing a
  rung or candidates, and for why poles appear, inherited poles, hidden weights, or what pole-free does not give.
- `reference/workflow.md`: before running a step for the first time, sizing a reduction, using approval mode, or
  for what the gate checks.
- `reference/escalation.md`: when a sector's first rung fails, or the user wants a sector pushed further.
- `reference/simplify.md`: before step 7, and when its script asks for something you do not understand.
- `reference/formats.md`: before writing `system.wl`, `conventions.wl` or `run.wl`, or reading any output.
- `reference/pitfalls.md`: when a calibration fails, a reduction misbehaves (non-ut masters, memory, licence),
  or a fix looks too good.
- `reference/tools.md`: when a tool is missing, or for the citations.
- the maximal-cut-basis `reference/limits.md`: before a large reduction, when a job was stopped at a limit, or when
  you want to change a limit.
