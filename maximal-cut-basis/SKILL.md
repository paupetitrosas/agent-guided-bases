---
name: maximal-cut-basis
description: Find, one sector at a time, the best basis on the maximal cut for the master sectors of a Feynman-integral family - pure dlog integrals (eps-factorised DE, every element eps-pure) or, when the geometry forbids dlog forms, eps-polynomial - using Baikov representations, leading singularities and a Kira/FiniteFlow check of the maximal-cut differential equation. Use for canonical, UT or eps-form bases; leading singularities or Baikov cuts; elliptic, hyperelliptic or non-polylogarithmic sectors; the Picard-Fuchs operator or geometry of a cut; checking a proposed basis on its maximal cut.
---

# maximal-cut-basis

The user gives you a family of Feynman integrals. For each sector that carries master integrals, your
job is to find integrals whose differential equation on the **maximal cut** is ε-factorised, that is,
dlog integrals, each of them **ε-pure**: its integrand, Γ prefactor included, is a power of ε times something free
of ε, so that it is likely uniform weight off the cut as well (a pure integral, not one hiding an (a + bε) factor
that the cut cannot see). Some sectors cannot have such a basis without periods: the cut is a curve of genus one or
higher, or a non-polylogarithmic fibration. For those, and only for those, aim for a basis whose
maximal-cut DE is a polynomial in ε of the lowest possible degree. Each sector starts with its Picard-Fuchs
operator: on a line through kinematic space at ε = 0, it labels the geometry of the cut (`polylog`, `elliptic`,
`K3`, ...), and the label tells you which of the two aims applies.

The toolkit in `lib/` and `bin/` does the mechanical work and checks it. The choices are yours: which
Baikov representation to use, which ansatz and candidates, when to try something harder, which papers to
read. You also write each sector's `AnalysisMasters.m` and explain there why you picked the basis you did.

Every basis goes through the same check, whether it came from a paper, another program or your own hands:
`bin/check_basis.wls` (or `MCBCheckBasis` inside a script). It reduces the basis and its derivatives on the
maximal cut with Kira, at two random rational kinematic points, keeping ε exact, for every invariant. The docs
call this check "the gate". The automatic pass reaches its verdict from the same reductions.
Besides the ε structure, the gate checks the Euler relation of homogeneous integrals, Σ_X d_X X A_X = diag(weights),
at both points: a basis whose DE breaks it is `failed` (an element mixes mass dimensions, or the reductions or
derivatives are wrong). It also reports, without deciding, what the pole-free skill requires of a master: one
power of ε per integral, no ε in a denominator, rational coefficients and one square root, every denominator
factor a letter when the family gives `"Letters"`, and one weight shared by the elements. A basis can be ε-form
and still break these (d-dimensional dlog candidates with 1/(1 − 2ε) between integrals), and a curve basis of
derivatives mixes weights; both are reported in `basis.m` (`checks`) and on the sector's page.

The skill only deals with the maximal cut, the diagonal blocks of the DE. Couplings to subsectors and the
periods of elliptic curves are left for later.

## One family, one sector at a time

Work on one family, and inside it on one sector, at a time.

- **One family per run.** A run folder belongs to one `family.wl`. When the user has several families, finish
  one (or stop where the user says) before starting the next, each in its own run folder.
- **One sector at a time.** Take the sector the user named, or else the next unfinished one in `sectors.txt`
  with the fewest propagators (its third column). Take it through steps 3 to 6 below until it has its final
  status and the user has been told, and only then open the next one. Never run the first pass, an escalation
  or a FiniteFlow check for two sectors at once, and do not use `bin/run_all.sh` or `bin/auto_pass.wls` with
  several sectors: those are for a user who runs the toolkit without an agent.

Working this way leaves licence slots free for the user and keeps each sector's reasoning in its own `notes.md`.
It also lets the conventions chosen in a lower sector (the normalisation of a shared square root, a numerator)
carry over to the sectors above it.

**Repeated geometry.** Some sectors are another sector of the family at mapped kinematics (the same graph and masses
at s35 instead of s12, say). `find_masters.wls` lists them and writes `geometry.m`; the earlier one comes first in
`sectors.txt`. When the automatic pass starts such a sector, it maps the earlier sector's basis over (lines and
invariants) and searches it first when it has as many elements as the cut has masters; if that is ε-form with no
element known not to be ε-pure, or ε-polynomial on a non-dlog sector whose earlier sector is `eps-polynomial` too, the
candidate searches are skipped.
A basis with numerators on ISPs does not map this way: the page says so, and you can map it by hand.

## Setting up (once per machine)

1. Run `bin/ws bin/preflight.wls [paths.wl]`. It looks for every third-party tool, runs a small test with each
   one and prints a table, including how many Wolfram kernels the licence allows. The table and that limit
   (which `bin/ws` reads) are kept in `~/.cache/maximal-cut-basis/`, not in the user's folders. The table holds
   for the tool paths it was made with, which it names: for a run with its own `paths.wl`, run the preflight on
   that `run.wl`, or read the tools line that `run_sector.wls` and `find_masters.wls` print for the run. You are done
   when you can tell the user which steps are available. A missing tool only disables the steps that need
   it; `reference/tools.md` says how to install each one. Nothing third-party ships with the skill. Paths
   are detected automatically; the user can override them in `paths.wl`, or simply tell you where a tool
   is (then call `MCBSetPath[tool, path]`).
2. Start every Wolfram script through `bin/ws` (for example `bin/ws bin/check_basis.wls ...`). It waits
   until the licence has a free kernel slot, so you never collide with another session's jobs, and it
   closes stdin, which `wolframscript` would otherwise read. `finiteflow_sector.sh` already uses it. To stop a
   job of yours, use `bin/ws --list` and `bin/ws --stop PID` (kernels included), not `pkill`. Kernel
   starts are the scarce resource: `bin/run_sector.wls` does the validation, the first pass and the reports of
   one sector in one kernel.
3. Every heavy process runs under a time limit and a memory limit: each kernel through `bin/ws` (its memory is
   that of the kernel and everything below it, Kira included), each Kira run, each step of the FiniteFlow check.
   The defaults are 24 h and an equal share of 90% of the machine's memory for each licence slot (`bin/ws --list`
   shows the limits of every job). You may change them: `bin/ws --timeout S --memory GB script.wls` (or
   `MCB_TIME_LIMIT`, `MCB_MEMORY_LIMIT`) for a kernel, `bin/ws --set PID --timeout S --memory GB` while it runs,
   `run.wl` `"TimeLimits"` and `"MemoryLimits"` for Kira and FiniteFlow (`reference/formats.md`). A job stopped
   at a limit exits with 124 (time) or 137 (memory) and says which. Raise a memory limit only when the machine
   has the memory (other sessions use it too); otherwise make the job smaller. Tell the user when you change a
   limit. `reference/limits.md` has every process with its limits and defaults, how to set and change them, what
   happens when a job is stopped, and how to choose a limit.

## What you need from the user

- A `family.wl`: one Association that defines the family (see `reference/formats.md`; start from
  `templates/family.wl` or one of the `examples/`).
- Optionally a `run.wl` (which sectors, which steps to skip, time limits) and a list of master integrals
  (a Kira `masters` file or a list of `j[...]`). The list is only used to group the masters into sectors:
  every sector is recounted on its maximal cut, because such lists often miss a master or two.

## The workflow

Steps 1 and 2 are done once per family; steps 3 to 6 once per sector, for one sector at a time.

| # | step | command | you're done when |
|---|---|---|---|
| 1 | validate the family | `bin/ws bin/validate_family.wls family.wl --scaling` | every check and the scaling self-test say PASS (fix `family.wl` until they do) |
| 2 | find the sectors | `bin/ws bin/find_masters.wls run.wl` | `sectors.txt` lists the sectors, and you know which one comes first |
| 3 | first pass on this sector | `bin/ws bin/run_sector.wls run.wl j<pattern>` (validation with the scaling self-test on this sector, the Picard-Fuchs step, the automatic first pass, the FiniteFlow scripts and the reports, in one kernel) | the sector folder has `masters.m`, `basis.m` (with its `classification`) and `basis.html` |
| 4 | escalate | if the sector is flagged, work in `j<pattern>/AnalysisMasters.m` and climb the ladder below | the status is `eps-form` and no element is known not to be ε-pure (`epsPure` False); or `eps-polynomial` and you have shown the geometry allows nothing better; or every rung has been tried and the sector is flagged |
| 5 | analytic check | `bin/finiteflow_sector.sh <run folder>/j<pattern>` | `finiteflow/verdict.m` agrees with the Kira verdict and its comparison with Kira's matrices says `agree` |
| 6 | report | `bin/ws bin/make_reports.wls <run folder> j<pattern>` | the sector's page and `summary.html` are up to date, and you have told the user what this sector gave: its status and its Picard-Fuchs label (`reference/picard-fuchs.md` says what to add for `unresolved` and for a missing `orderDrop`); then go back to step 3 with the next sector |

`reference/workflow.md` says what to look at after each step, how to work on a sector without the first pass,
and lists the functions. Every script ends with one line of JSON and an exit code (`core/README.md`, "The
verdict"). Exit code 1 can be a recorded result, not a crash: `run_sector.wls` exits 1 on a sector that ends
`eps-polynomial (dlog search incomplete)`.

## Choices that are yours

- **Read the loop-by-loop structure first.** For any sector that the first pass does not settle, run
  `MCBLoopByLoopReport[fam, sector, <|"KiraMasters" -> n|>]` before choosing candidates. It shows, for every
  loop order, which subloop each Baikov polynomial belongs to, the twist factors and their exponents, what a
  numerator power costs at infinity, how many masters the representation sees with and without the factors
  whose exponent is O(ε), and the geometry of the bulk and of every boundary. Masters that live on the zero
  set of an O(ε) factor need integrands with a simple pole there (dots on that subloop's propagators); a
  basis of ISP numerators cannot have the right weight. `reference/method.md` (section 4) explains it.
- **Representation.** `MCBRepresentations` returns the loop-by-loop and standard Baikov representations
  sorted by a geometric score: number of cut variables, then the highest degree under a square root, then the
  number of square-root factors, then the number of ISPs. Representations with a root of degree above two in
  every variable come last, since another representation of the same cut can be rational. Look at the
  geometry of the first few. A curve of genus one or more in one variable is a property of the cut; a root of
  high degree in every variable of one representation is not. The standard representation is built only when it
  has at most three cut variables, or no loop-by-loop representation is dlog-compatible; `<|"Standard" -> True|>`
  asks for it.
- **Route.** Use dlog candidates (`MCBDlogCandidates`) for cuts that are points, rational or have square
  roots; curve candidates (`MCBCurveCandidates`) for one-variable curves; simple single integrals for
  non-polylogarithmic cuts.
- **Purity.** An ε-form basis is final only when every element is ε-pure: the DE on the cut cannot see an
  (a + bε) factor on an element, and such a factor shows up later as poles in the full DE. Read the loop-by-loop
  representation: each subloop has its natural uniform-weight integrand (a dot on a massive tadpole or bubble line,
  no dots on triangles and boxes, a numerator equal to the subloop's Baikov variable). The sector's page says,
  element by element, whether it is ε-pure off the cut and which factor it carries if not (`epsPure` in `basis.m`).
  The toolkit searches for purity itself: every candidate gets a purity verdict before the search
  (`MCBCandidatePurity`); the search tries the ε-pure ones alone first and puts them first in every order
  (`MCBOrderKey`), before a mapped basis or a target of the route, and never gives up an ε-pure element for one that
  is not; the automatic pass searches on past an ε-form
  basis with an element that is not ε-pure (other representations, candidates that are dlog in d dimensions, larger
  pools);
  `check_basis.wls` and `AnalysisMasters.m` adopt an ε-form basis with fewer such elements by themselves; and a
  sector whose ε-form basis still has one is flagged.
- **Tie-breakers**, between bases that are equally good (ε-form and as ε-pure): prefer rational normalisations over
  square roots; then conventions that agree across related sectors (the same normalisation of a shared square root,
  the same numerators). The search orders its candidates the same way after purity.
  On a non-dlog sector (status `eps-polynomial`, or a Picard-Fuchs label that is not polylogarithmic), among bases
  with the same spread of powers of ε, prefer one with at least one undotted element: a basis whose every element
  is dotted is likely to carry a weight between sectors, which the maximal cut cannot see. It gets a note (`all-dot`
  in `basis.m` `checks` and `flags`), and the search, the automatic pass and `check_basis.wls` apply this
  tie-breaker themselves.
  Adopt a basis chosen by a tie-breaker with `bin/ws bin/check_basis.wls j<pattern> file.m --tie-breaker "reason"`:
  it replaces an equally good basis (never a better one) and is recorded as a tie-breaker, not as a rung.
- **Calling a sector non-dlog.** The Picard-Fuchs label decides when it has one: `elliptic`, `genus-g`, `K3`,
  `CY_n` or `non-polylog (order k)` shows non-dlog geometry and allows the status `eps-polynomial`; `polylog` and `polylog (nested root)`
  never do, even next to a Baikov curve that no master sees. Without a label (`not computed`, `unresolved`,
  `not applicable`, skipped), give the status `eps-polynomial` only when the geometry shows it: a curve
  of genus one or more in one variable, or on a boundary that carries masters (an O(ε) factor's zero set),
  or a root of degree higher than two in every variable of every representation. If you have not shown that, the status is `eps-polynomial (dlog search incomplete)`.
  `bin/ws bin/picard_fuchs.wls run.wl j<pattern>` labels a sector that was done before the step existed.

## The ladder

When a sector has no ε-form basis yet, or its ε-form basis has an element that is not ε-pure, try these in order,
each at most once per sector and session, and stop at the first ε-form basis none of whose elements is known not to
be ε-pure. Record every attempt with `MCBAppendAttempt`. `reference/escalation.md` explains
each rung.

1. Cheap and automatic: what the first pass does (larger pools, 3-term subsets, extra-ISP and standard
   Baikov representations), pushed further if the log suggests it.
2. Literature search on arXiv and INSPIRE, with whatever web tool you have, plus anything the user put in
   the sector's `refs/` folder. Record every paper you use (see "Citing and acknowledging").
3. A shift of the dimension, d₀ → d₀ − 2 (`MCBDimensionShift`).
4. Candidates you build yourself (cut integrand per variable, numerators, residues, curve coordinates,
   cohomology analysis).
5. Master integrands chosen by their geometry, the first step of the ε-collaboration's algorithm
   (arXiv:2511.15381): localisations from points up, then pole order, each element normalised by ε^(−|µ|). It needs
   rational functions only and is meant to give an ε-polynomial DE of a fixed structure (F-compatible).
6. Other algorithms, INITIAL, Libra or Fuchsia, fed through `MCBExportDE` (declare the one you ran: `--tool`).
7. Flag the sector. Its page then says that it can be retried and lists the rungs not yet tried.

On a sector whose Picard-Fuchs label is not polylogarithmic, skip the dlog-only work: the larger dlog pools of
rung 1 and the dlog candidates of rung 4. The first pass already does.

A sector ends with one of four statuses: `eps-form`, `eps-polynomial` (non-dlog geometry shown),
`eps-polynomial (dlog search incomplete)` or `failed`. It is flagged, that is, it needs step 4, comes first in
`summary.html` and lists retry hints on its page, when its status is neither `eps-form` nor `eps-polynomial`, when
a Picard-Fuchs check (Baikov curve or Kira) disagrees, when it is `eps-form` under a label that is not
polylogarithmic, or when it is `eps-form` with an element that is not ε-pure (`epsPure` False; `MCBFlaggedQ`). A note in `basis.m` `flags` alone does not flag it.

## What comes out

Only the files the user reads, and those the toolkit needs to carry on, stay. Each sector folder `j<pattern>/`
holds:

- `basis.html`: the page the user reads (drawing, representation, geometry, basis, both DE verdicts, the
  history, your reasoning, the papers and tools to cite, what could be retried);
- `masters.m`: just the basis, exact expressions with their square roots, prefactors and powers of ε. The
  maximal cut only fixes the powers of ε relative to each other, so tell the user that the common power of
  each sector is still a convention;
- `notes.md`: your reasoning, shown on the page;
- `AnalysisMasters.m`: the analysis as a script the user can rerun and edit;
- `basis.m` and `attempts.m`: the record (the Picard-Fuchs `classification` included) and the history,
  machine-readable (the pages and scripts read them);
- `finiteflow/`, after the analytic check: `verdict.m`, `DE.m` (the analytic maximal-cut DE) and `ffinfo.m`.

The run folder holds `summary.html` (flagged sectors first), `masters_all.m` (every basis integral),
`CITATIONS.md` (what to cite), and the bookkeeping files `run_info.m`, `sectors.txt`, `geometry.m`,
`citations.m` (the ledger of tools and papers) and, when Kira had to find the masters, `masters_found.m`.
Working folders (Kira jobs, the scaling self-test, FiniteFlow's identities and logs) are
deleted as soon as their results have been read. A folder whose step failed stays, so that you can read its
`kira.out` or log. `"KeepScratch" -> True` in `run.wl` (or `MCB_KEEP_SCRATCH=1`) keeps everything for
debugging.

Add nothing else to the run folder. Logs of the scripts you run, trial basis files and other scratch work
belong in a temporary folder outside it, and are deleted once their content is in `attempts.m`, `notes.md` or
the ledger.

Whenever a choice was yours, write the reason in `notes.md` (`MCBWriteNotes`, `MCBAppendNotes`); it shows
up on the sector's page.

To compare a basis with the current one without replacing it, use `bin/check_basis.wls ... --dry-run`. A
basis from a file only replaces the current one when its status is better (or, for two ε-polynomial bases, its spread
of powers of ε is smaller, or the same with an undotted element where the current one is all-dot; for two ε-form bases,
fewer of its elements are not ε-pure), unless you pass `--adopt`; its file can give a label and a provenance for each element.
`AnalysisMasters.m` follows the same rule (`adopt = True` in the script). The FiniteFlow check notices by itself when `masters.m`
has changed: its old verdict is then shown as "stale" and `finiteflow_sector.sh` rewrites the pipeline.

## Skipping steps

If the user asks you to skip a step, or lists it under `"Skip"` in `run.wl` (it ends up in `$MCBSkip`),
leave it out; the reports mark it as "skipped by user". The step names are in `$MCBSteps` and in
`reference/formats.md`.

## Citing and acknowledging

**Papers.** Whenever something from a paper goes into a sector, record it straight away, so that its authors
can be acknowledged. This covers a basis or candidates, a map of propagators or kinematics, a normalisation, a
choice of representation, or a construction on a curve. Record it even if the basis it led to was not adopted.

- A basis from a paper: `bin/ws bin/check_basis.wls j<pattern> file.m --rung 2 --provenance "..." --reference
  "authors, title, journal, arXiv:xxxx.xxxxx" --used "what you took, e.g. the basis of eq. (3.4), mapped by
  k1 -> -k1"`, once per paper.
- Anything else: `MCBRecordLiterature[sectorDir, <|"reference" -> "...", "used" -> "...", "rung" -> n,
  "outcome" -> "...", "result" -> "adopted" | "not adopted"|>]`.

Take the authors, title and arXiv number or DOI from arXiv or INSPIRE, never from memory. Each entry goes to
the run's ledger `citations.m`. `CITATIONS.md` groups the entries by paper (arXiv id or DOI): under "Cite" the
papers behind the final bases, under "Also consulted" those of a basis not adopted or replaced later, with the
outcome. The sector's page and the summary show the same.

**Tools.** A tool or method is credited to the sector when it produced something there (a representation, a
reduction, a DE, a label), not when it was loaded, whichever kernel ran it; `basis.m` (`"toolsUsed"`,
`"citations"`), the pages and `CITATIONS.md` list what the ledger credits, with the references of
`reference/tools.md`. A tool you ran by hand (INITIAL, Libra, Fuchsia, ore_algebra, ...) is credited only when you
declare it: `check_basis.wls ... --tool NAME`, once per tool, or `CoreRecordTool[sectorDir, {"NAME"}, "declared"]`.
The names are those of the registry in `core/lib/Core/Tools.wl`; an unknown one is refused, and the words of a
provenance credit nothing.

When you report to the user, list the tools and papers to cite for the sector (or the run, from `CITATIONS.md`)
and ask them to acknowledge the authors of the papers.

## Where to read more

- `reference/method.md`: before choosing representations or candidates, and for any question about
  curves, non-polylogarithmic cuts or the ε-structure (Baikov, the twist, dlog forms, UT normalisation,
  Hermite reduction, how the DE check works, the examples, a genus-2 walk-through).
- `reference/workflow.md`: before running a step for the first time, or when working on one sector by hand.
- `reference/escalation.md`: when a sector is flagged, or the user wants a sector pushed further.
- `reference/picard-fuchs.md`: what a Picard-Fuchs label means and how it steers, an `unresolved` block
  (SageMath can factor it), and the checks behind a label.
- `reference/formats.md`: before writing `family.wl`, `run.wl` or `paths.wl`, or reading any output file.
- `reference/pitfalls.md`: when something misbehaves (wrong master counts, rational ε dependence, Kira or
  licence errors, symbol clashes), and before you change the toolkit.
- `reference/tools.md`: when a tool is missing, or when you write the citations.
- `reference/limits.md`: before a long or large job, when a job was stopped at a limit (exit code 124 or 137),
  or when you want to change a limit.
- `examples/`: five public families and what to expect from each.
