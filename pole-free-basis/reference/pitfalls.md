# Pitfalls

Each of these broke a real run silently. Check the relevant one when something misbehaves, and before changing
the toolkit.

## Conventions and calibration

- **A census of a mis-converted slice still looks plausible.** Poles and ε ranges do not depend on the root
  ratio, so a wrong frame or root order goes unnoticed until a change is applied. Calibrate before the first
  change, and again when the slice comes from a new run.
- **Root matching order.** With `"RootSymbols"`, a square root whose radicand is invariant under an image map
  (√(s(s − 4m²)) under t ↔ 2m² + q² − s − t) matches the first symbol with that radicand, often the base
  family's. `"RootOrder"` must follow the producer.
- **Master order.** Pipelines often reverse the joined list of masters. A wrong `"MasterOrder"` shuffles every
  label; the calibration fails on every row.
- **The slice basis drifts.** After an accepted change, later reductions must use the new definitions:
  `PFBStartRun` and `PFBTryChange` apply accepted changes to the system. A reduction written before a change
  does not calibrate against the new slice. `PFBSubtreeJob` refuses to reuse such a job: give it `"Replace" -> True`
  (`--replace` of `subtree_job.wls`), which keeps the identities and redoes the reductions.
- **Focus rows of changed sectors.** A reduction whose focus contains masters changed after it was written
  disagrees with the slice in those rows only; that is a stale job, not a wrong convention.

## Reductions

- **Non-ut masters.** A subtree whose masters are not system masters (a sunrise in one family where the system
  uses its image in another) gives wrong poles. Causes: missing symmetry rules (LiteRed misses some
  identifications), a missing host sector (the runner adds hosts), too few seeds in low sectors (images of
  mapped integrals stay unreduced). Raise the seeds of the low sectors with `SeedBump`, never the Map/ExtMap
  seeds: those blow up the system. A master that only a relation from a sector outside the subtree removes is not
  a reason for whole-family reductions: keep it as an extra column and remove it exactly, or find that sector once
  (`reference/workflow.md`, "Masters the system lacks").
- **Kira's masters are its own.** Kira picks its masters (its `preferred_masters` take single integrals, not the
  system's combinations), so the runner reduces the system's masters too and solves every row onto them. When they do
  not span Kira's masters (a relation from outside the subtree is missing, or Kira and LiteRed disagree on a zero
  sector), when the system has more masters in the subtree than Kira (some of them are related there: equal masters,
  or a symmetry Kira uses; which to keep is FiniteFlow's choice, as at the other points), or Kira reduces a master
  of the system to zero, FiniteFlow reduces the slice point instead and `"KiraFallback"` in `status.m` says which;
  FiniteFlow's host sectors and extra columns then handle such masters. The same happens when Kira stops at its own
  limit (half of the time the job has left), leaves integrals unreduced, or finds no value at the point for an
  invariant of its family. `kira_fallback.m` in the job folder keeps the reason, and later runs of the job (reruns,
  host rounds) skip Kira until the job is rewritten for a new basis or specification (`"Replace" -> True`), which
  deletes the file with the job's results.
  Kira does not read the system's symmetry rules either: a subtree they apply to is FiniteFlow's.
- **Rows on an extra master used as they are.** The sector rows of a reduction that keeps an extra master X are
  pole-free or not in a basis the system does not have: X's expansion on system masters can carry poles of its own.
  Remove X (`bin/extra_masters.wls`) before anything compares rows at points away from the slice;
  `PFBVerifyAtPoints` and `PFBCompletionSolve` refuse such reductions.
- **The integral index map.** The serialized identities and `LIBPGetAllInts` must agree on the order of the
  integrals; the runner stops when they do not. Changing the family load order or mixing identity files from
  another system breaks it.
- **Root prefactors in rows.** A new master's row is d h + dlog(root) h. Forgetting dlog makes sectors with
  roots look impossible to fix. `PFBExprDVector` adds it; hand-written rows must too.
- **Spurious completions.** A fit at few points can satisfy every equation and fail elsewhere. Fitted changes
  need the gate's extra points.
- **Memory.** A reduction with millions of equations and many reconstructed rows ran out of memory even
  though the learning phase fitted: reconstruction memory grows with rows × masters × threads. The runner plans
  the threads; `TakeUsed` keeps the rows to what is needed.

- **A FiniteFlow library that loads but aborts.** An old build can pass FiniteFlow's own tests and still abort the
  kernel in `FFSparseSolve` (`free(): invalid pointer`). The preflight runs that solver in a separate kernel;
  point `FiniteFlowLibrary` to a current build when it crashes. A copy in the user's
  `SystemFiles/LibraryResources` shadows the configured library for any code that appends to `$LibraryPath`; the
  toolkit prepends it (`PFBLoadFiniteFlow`, the runner), and the preflight reports such a copy.
- **A FiniteFlow library older than FiniteFlow.m.** It loads without an error, since FiniteFlow.m only gets `$Failed`
  for each function the library lacks (a build a year older lacks 18, among them the sparse solver's), then writes
  `$Failed` into LiteIBP's derivative rows or hangs in `FFSparseSolve` (a test ran 31 minutes). After loading,
  `PFBLoadFiniteFlow` checks that every such function loaded (`PFBFiniteFlowProblem`, no kernel, no evaluation): it
  refuses the library with the reason, once, and `PFBSolveLinear` solves without it; the runner stops the job
  (`failed`, exit 3) with the same message (`PFBFFLibraryProblem`), and so does `tests/degrees.wls`. Set
  `"FiniteFlowLibrary"` to the build of the same version as `FiniteFlow.m`.

## Kernels and files

- **Licence errors that are not licence errors.** "No valid password" or "license error" right after a kernel
  was killed is usually out-of-memory; with every slot busy it is the licence limit. Wait for a slot
  (`bin/ws` does), shrink the job for the first.
- **Parallel sessions.** Two sessions share the licence, the kernels, the CPU and the memory. Check what runs
  (`ps`, other agents) before starting a reduction, keep each session's files in its own folder, and agree on
  who writes the deliverables. Another session's Kira or Wolfram jobs can start after yours has passed its memory
  gate: the runner checks the free memory again before each point (it names the processes above 1 GB), but a job
  that grows fast can still be killed. Rerun it: finished points are kept. Subkernels of another session's job
  hold licence slots that `bin/ws` does not count.
- **The machine sleeps.** A laptop or WSL host that sleeps stops every job, and the wall-clock time keeps running:
  a 15-minute point shows hours. `times.m` flags such points (`"Starved"`: little CPU for its wall-clock time) and
  `bin/wait_job` reports jumps of the clock. Keep the machine awake during long reductions, and never plan the next
  run from a starved timing.
- **macOS has no `/proc`.** There the toolkit reads the machine's memory from `sysctl -n hw.memsize`, the memory
  available from `vm_stat` (free, inactive and speculative pages times the page size), the swap from
  `sysctl -n vm.swapusage`, a process's resident memory from `ps -o rss=`, and whether a job's kernel still runs
  from `kill -0` or `ps -p` (`lib/PFB/Machine.wl`). Before, a job on macOS was never refused for memory, the memory
  model never learned, and a running job showed as killed. macOS keeps no peak memory of a process: the runner
  samples `ps` once a second during each phase, so a peak shorter than a second is missed and the model can learn
  a little low. The CPU time of a point is not measured there (`times.m` has no `CPUSeconds`, and no point is
  flagged as starved).
- **Wait loops that never end.** A loop that polls for `red_<ip>.m` or for "done" never ends when the job dies.
  Use `bin/wait_job`: it ends on a dead process, a stalled `run.log` or its timeout.
- **Scratch folders vanish.** `/tmp` can be wiped mid-run; the run folder must be persistent (the toolkit
  refuses `/tmp` unless told otherwise).
- **Protected symbols.** `E`, `O`, `D`, `N`, `I`, `C`, `K` cannot be variables in scripts; loop variables named
  like invariants (`t`, `s`) recurse.
- **Module initialisers.** In `Module[{d, g = f[d]}, ...]` the `d` in the initialiser is the global one; assign
  `g` in the body.
- **Aliases.** After `f = g`, a definition `f[x_][y_] := ...` is a definition of `g`: if it calls `g`, it recurses
  until the iteration limit, and LiteIBP then writes thousands of junk identity files (`ids_IterationLimit_*`).
  Define the alternative directly instead of aliasing first.
- **Reading master files too early.** LiteRed's `j[fam, ...]` must exist when a file with integrals is read: read
  such files after the families are defined, or they get another `j` (or trigger LiteRed on undefined bases).

## Basis rules

- **A hidden weight.** A pole-free master whose transformation to the old one has determinant (1 − 2ε) may not be
  uniform weight. Typical source: high powers of ISPs (x₉² behaves as curve form/(1 − 2ε)). The converse happens
  too: when the old basis carries the weight, the right new master shows (1 − 4ε), say, on it. The gate records the
  determinant and does not judge it: the DE decides, through the poles a weight puts into the rows that couple to
  its master (`method.md`, "Rules for a new master"). A weight on a master that nothing couples to is not seen.
- **Mixed ε powers.** ε^p (a + bε) j and terms with different powers of ε on the same integral violate rule 1
  even when the DE looks fine.
- **ε² couplings after derivatives.** Derivative (second-kind) masters remove poles but bring pure ε² couplings;
  a uniform rescaling cannot always remove them. That is a property of the sector, not a failure of the
  change.
