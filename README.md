# maximal-cut-basis and pole-free-basis

[![arXiv](https://img.shields.io/badge/arXiv-2611.26688-b31b1b.svg)](https://arxiv.org/abs/2611.26688)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](LICENSE)

> **Paper:** [*Agent-guided construction of Feynman integral bases*](https://arxiv.org/pdf/2611.26688),
> Pau Petit Rosàs and William J. Torres Bobadilla, arXiv:2611.26688.
> It describes both skills and what they produced for a two-loop five-point family with two masses and for a
> two-loop jet-function family. [How to cite it](#citing-and-acknowledging)

Two agent skills for choosing master integrals of Feynman-integral families with their differential
equations (DEs) in mind. They work with any agent that reads `SKILL.md` files.

- **maximal-cut-basis** handles the diagonal blocks of the DE. For each sector that has master integrals, it
  looks for a basis whose DE on the maximal cut is ε-factorised and whose elements are ε-pure. When the cut is an elliptic, hyperelliptic, or worse, no such basis exists
  without periods. For those sectors it looks for the basis whose DE is the simplest polynomial in ε instead,
  and says so.
- **pole-free-basis** handles the couplings between sectors. It starts from an existing basis and the DE at one
  rational kinematic point, exact in ε (a *slice*). It changes masters sector by sector, from the bottom up,
  until no entry of the DE has a pole at finite ε, such as 1/(1 − 2ε), or a negative power of ε.

Each skill is a toolkit plus instructions. The Mathematica code does the mechanical, checkable
parts: Baikov representations, leading singularities, reductions with Kira, LiteIBP and FiniteFlow, and the ε
structure of the DE. The agent makes the judgement calls and writes down why it made each one. Every basis or
change, wherever it came from, has to pass the same exact check before it is accepted; the skills call this check
"the gate".

## How the agent works

Both skills ask the agent to work the same way:

- **One family and one sector at a time.** 
- **The reasoning is written down**
- **The tools and papers it uses are recorded.** 
- **Only the files you need are kept.**
- **Your own files are not edited** 

## Requirements

A machine where the agent can run commands, with **Wolfram Engine or Mathematica 13 or later**, and:

| tool | maximal-cut-basis | pole-free-basis |
|---|---|---|
| **Kira 3** with **Fermat** | required: every reduction on the maximal cut | optional: the slice point of a reduction whose subtree lies in one family, and the check of a new maximal-cut basis |
| **BaikovPackage** | required: the Baikov representations | for the structural reading of a sector and the candidates of a new maximal-cut basis |
| **FiniteFlow**, **LiteRed 2**, **LiteIBP** (finiteflow-mathtools) | optional: the Picard-Fuchs step (without them a sector gets no geometry label) and an analytic check of each sector's DE | required for the reductions |
| **DlogBasis** | optional: a cross-check of leading singularities | – |
| **INITIAL**, **Libra**, **Fuchsia** | optional: the skill exports DEs for them | – |
| **SOFIA** | – | optional: the candidate singularities of each family |

pole-free-basis also needs maximal-cut-basis next to it (or `PFB_MCB` set to the path of its
`lib/MaximalCutBasis.wl`). FiniteFlow's library must be the build of the same version as its `FiniteFlow.m`:
pole-free-basis refuses an older one, and the maximal-cut-basis pipeline falls back to a slower path for one built
before September 2025 (`reference/pitfalls.md` of each skill). None of these tools is included;
`maximal-cut-basis/reference/tools.md` says where to get each one (SOFIA: `pole-free-basis/reference/tools.md`).
Everything runs locally, so the skills cannot work in a hosted sandbox that lacks this software (for example
Claude.ai or the Claude API's code execution).

## Installing

**Claude Code.** Put both folders, or symbolic links to them, where Claude Code looks for skills:

```sh
ln -s /path/to/maximal-cut-basis ~/.claude/skills/maximal-cut-basis        # for yourself
ln -s /path/to/pole-free-basis   ~/.claude/skills/pole-free-basis
# or copy them, with core/, into <your project>/.claude/skills/ to share them with a project
```

Both skills use the shared folder `core/` of this repository and look for it next to themselves; a symbolic link
is followed back to the repository, so linked skills find it there. When you copy the skills, copy `core/` into the
same folder too (`<your project>/.claude/skills/core/`), or set `SKILL_CORE` to wherever `core/` is (when set, it
is used first). Without it, `bin/ws` stops with "the shared core was not found next to the skill".

Claude then uses them on its own when you ask for canonical or ε-form bases, dlog integrals, leading
singularities, elliptic sectors, or a DE without ε poles. You can also call them explicitly, with
`/maximal-cut-basis` or `/pole-free-basis`.

**Other agents.** `SKILL.md` follows the open Agent Skills format (agentskills.io), so agents that support
skills should pick it up from their own skills folder. For an agent without skill support, a line in its
`AGENTS.md` pointing to `SKILL.md` is enough. The skills have only been tested with Claude Code so far.

**Without an agent.** The toolkits work on their own: `Get["/path/to/maximal-cut-basis/lib/MaximalCutBasis.wl"]`
and `Get["/path/to/pole-free-basis/lib/PoleFreeBasis.wl"]` load every function into a notebook, and
`maximal-cut-basis/bin/run_all.sh run.wl` runs the automatic pass over a whole family.

**Before the first run**, tell the skills where your tools are unless they are in the usual places: copy
`maximal-cut-basis/templates/paths.wl` next to your family and fill it in. Then run `bin/ws bin/preflight.wls
paths.wl` (from either skill) to see what was found. `bin/ws` is a small wrapper around `wolframscript`: it
waits until the Wolfram licence has a free kernel slot before starting, so runs never collide with other jobs on
the same machine, and it runs the script under a time limit and a memory limit (24 h and a share of the machine's
memory by default; `--timeout`, `--memory`, or `bin/ws --set` while it runs). Kira runs and the FiniteFlow steps
have limits of their own (in maximal-cut-basis's `run.wl`; Kira inside a pole-free reduction job gets half of the
time the job has left); `maximal-cut-basis/reference/limits.md` explains them all. The skills use `bin/ws` for every
kernel they start; use it yourself when you run the scripts by hand.

## maximal-cut-basis

### Getting started

1. Describe the family in one Mathematica file. Start from `templates/family.wl` or one of the `examples/`.
   The equal-mass sunrise, for instance, looks like this:

   ```mathematica
   <|
    "Name" -> "sunrise",
    "LoopMomenta" -> {k1, k2},
    "ExternalMomenta" -> {p},
    "ScalarProducts" -> {p^2 -> s},
    "Propagators" -> {
      <|"Type" -> "Quadratic", "Momentum" -> k1, "Mass2" -> m2|>,
      <|"Type" -> "Quadratic", "Momentum" -> k2, "Mass2" -> m2|>,
      <|"Type" -> "Quadratic", "Momentum" -> k1 + k2 - p, "Mass2" -> m2|>,
      <|"Type" -> "Quadratic", "Momentum" -> k1 - p|>,       (* irreducible scalar product *)
      <|"Type" -> "Quadratic", "Momentum" -> k2 - p|>        (* irreducible scalar product *)
    },
    "Invariants" -> <|s -> 2, m2 -> 2|>,                   (* mass dimensions *)
    "UnitScale" -> m2,
    "D0" -> 4,
    "Masters" -> {j[sunrise, 1, 1, 0, 0, 0], j[sunrise, 1, 1, 1, 0, 0], j[sunrise, 2, 1, 1, 0, 0]}
   |>
   ```

   Linear (eikonal) propagators are written `<|"Type" -> "Linear", "Momentum" -> k1, "Vector" -> n, "Constant" -> w|>`,
   meaning `k1·n - w`. The masters list is optional and only used to find the sectors; every sector is
   recounted on its maximal cut anyway.
2. Ask your agent, for example: "Find the maximal-cut bases for the family in `family.wl`", "Only look at
   sector j11100", or "Check the basis in `mybasis.m` for sector j11100". For a whole family it goes through
   the sectors one at a time, starting with the fewest propagators, and reports after each.
3. Open `<Name>_analysis/summary.html`, and from there each sector's page.

To run a sector yourself instead: `bin/ws bin/run_sector.wls run.wl j11100`, then
`bin/finiteflow_sector.sh <run folder>/j11100`, with a `run.wl` like `templates/run.wl`.

### What you get

For every sector, a folder `j0101...` with:

- `basis.html`: the page to review it. It shows a drawing of the topology, the Baikov representation, the
  geometry of the cut with its Picard-Fuchs label, and the basis in TeX. It gives both verdicts on the DE (Kira, and FiniteFlow with an
  entry-by-entry comparison of their matrices) and the master count compared with your list. It also has the
  history of what was tried, the agent's reasoning, and the papers and tools to cite. Sectors left unfinished
  say so and list what could be tried next;
- `masters.m`: the basis itself, as exact expressions with their square roots, prefactors and powers of ε. Only
  the powers of ε relative to each other are fixed by the maximal cut; the common power of a sector is a
  convention, and the page says so;
- `notes.md`, the agent's reasoning, and `AnalysisMasters.m`, a readable script that reproduces the analysis and
  that you can edit and rerun;
- `basis.m` and `attempts.m`, the same information in machine-readable form, and, after the analytic check,
  `finiteflow/` with the verdict and the analytic maximal-cut DE (`DE.m`).

For the whole family, `summary.html` lists the sectors that need attention first, then everything else;
`masters_all.m` collects every basis integral, and `CITATIONS.md` lists the tools, methods and papers to cite.

Each sector ends with one of four statuses: `eps-form`; `eps-polynomial` (the geometry allows nothing better);
`eps-polynomial (dlog search incomplete)` (nothing better was found, but nothing better was ruled out either);
or `failed`.

### How it works, briefly

1. **Validation.** `family.wl` is checked: the propagators must form a basis of the scalar products, the
   external momenta must be independent, the masses and constants must have consistent dimensions, and every
   symbol must be declared. A scaling self-test then compares the derivatives with Kira's conventions.
2. **Masters.** Kira recounts the masters on the sector's maximal cut. 
3. **Representations.** Loop-by-loop Baikov representations are generated for every loop order. The standard
   representation is added only when its cut has at most three variables, or when no loop-by-loop
   representation is dlog-compatible (or there is none); with more variables it is slow to build and the
   leading-singularity search does not finish in it. They are ranked by how simple the cut looks: fewer
   variables, lower-degree square roots, fewer square roots. A loop-by-loop report
   shows which subloop each Baikov polynomial belongs to, the twist exponents, and how many masters live on
   the boundaries where an O(ε) factor vanishes.
4. **Geometry.** FiniteFlow reconstructs the maximal-cut DE of the masters along a line through kinematic
   space. At ε = 0 it becomes one Picard-Fuchs operator, whose factors, logarithms, exponents and p-curvature label
   the geometry: polylogarithmic (possibly with nested square roots), elliptic, genus 2, K3, Calabi-Yau, or
   non-polylogarithmic of a type it cannot name. The label
   is checked against Kira and against the Baikov curve, and it decides whether the search aims at ε-form or at
   an ε-polynomial DE.
5. **Candidates.** A sector with the same geometry as one done earlier in the run (its integrals are that
   sector's at mapped invariants, found from the Symanzik polynomials) starts from that sector's basis, mapped:
   when it gives ε-form with ε-pure elements, or is the ε-polynomial basis of a sector proven non-dlog, the
   searches below are skipped.
   Otherwise, depending on the geometry: dlog candidates from an ansatz whose leading singularities are
   computed by iterated residues, with Euler substitutions for square roots, and dlog forms projected onto
   integrals modulo total derivatives; for curves, combinations matched to differentials of the first, second
   and third kind after a Hermite reduction; for worse cases, simple single integrals.
6. **The gate.** Kira reduces the candidates and their derivatives on the cut at two rational points, with ε
   kept exact, for every invariant, and the best set is chosen: an ε-form basis of ε-pure elements (an integrand,
   Γ prefactor included, that is a power of ε times something free of ε) when the search finds one, then ε-form,
   otherwise the lowest-degree polynomial in ε. Each candidate's purity is checked before the search, which tries
   the ε-pure ones first and searches on past an ε-form basis that is not. The gate also checks the Euler relation
   of homogeneous integrals, Σ_X d_X X A_X = diag(weights), at both points: a basis whose DE breaks it is `failed` (an element mixes mass
   dimensions, or the reductions or derivatives are wrong).
7. **Harder sectors.** The agent works through a fixed ladder: bigger searches, the literature, a shift of
   the dimension (with Tarasov's relation), candidates it builds by hand, master integrands chosen by their
   geometry as in arXiv:2511.15381 (designed to give an ε-polynomial DE), and finally INITIAL, Libra or
   Fuchsia. Sectors that still resist, an ε-form sector with an element that is not ε-pure included, are flagged
   and can be retried later.
8. **Confirmation.** Optionally, FiniteFlow reconstructs the sector's DE analytically from IBP identities
   generated by LiteIBP on the maximal cut, and compares it with Kira's.

`maximal-cut-basis/reference/method.md` explains the mathematics in detail.

## pole-free-basis

### Getting started

1. Describe the system in `system.wl`, starting from `templates/system.wl`. Families use the maximal-cut-basis
   `family.wl` format, and `bin/import_liteibp.wls` writes these files from a LiteRed/LiteIBP families file. The
   system can mix several families, image families obtained by exchanging external momenta, and square roots.
2. Describe the slice in `conventions.wl`: its point, the order of its derivatives and masters, and how its
   square roots were treated. The slice is often computed on a cluster; when it fits on your machine, the skill
   can build it locally.
3. Ask your agent, for example: "Make the differential equation in `run.wl` pole-free", or "Which masters
   cause the 1/(1 − 2ε) poles in sector `fam/j111011100`?". It asks you whenever a convention is unclear,
   instead of guessing, and calibrates the slice against its own reductions before changing anything.

### What you get

A run folder with one page per sector (old and new definitions, the source test, every attempt, the agent's
reasoning). It also holds `summary.html`, which lists the changes of the maximal-cut basis first, and
`CHANGES.md`, with every change, why and how it was found, and what was not verified. `export/<family>.m` has the
new masters files in their original order, and `CITATIONS.md` says what to cite. No master is multiplied by
an (a + bε) factor, and the entries of the DE end at most at ε² (the cap, `"MaxEpsDegree"` in `run.wl`): entries
above it are fixed like poles. The result is pole-free, not necessarily ε-form, and the skill reports the ε profile
that remains. Step 7 of `SKILL.md`, the simplification phase, then lowers the kinematic degrees of the DE where it
can, keeping it pole-free. The last step, after that one, is yours: regenerate the full DE once with the exported
masters.

### How it works, briefly

- **Census.** Every entry of the slice is classified by its poles and powers of ε, and the sectors with bad
   rows (finite poles, negative powers of ε, entries above ε²) are listed bottom-up. A sector whose bad entries may
   come from a lower bad sector waits for it.
- **Source.** A residue test on the slice finds which masters' definitions cause a sector's poles, and the same
   test at ε → ∞ which ones cause its entries above ε²; a negative power of ε is a pole at ε = 0. A maximal-cut
   block with poles, negative powers of ε or entries above ε² needs a new maximal-cut basis. The test needs no new
   computation.
- **Structure.** Before computing anything, the agent reads the sector's rows and its loop-by-loop Baikov
   representation, to see which subloop produces each pole factor and which integrands should replace the
   source masters.
- **Ladder.** For that sector the agent tries, in order, cheapest first:
   - a uniform ε^k on whole masters;
   - moving the dot of a dotted source to another propagator, ranked exactly on the slice;
   - the sector's natural integrals (few dots and numerators) in two or three slots at once, exactly on the
     slice, which takes minutes;
   - a fit of the required residue with pinched corner integrals (integer coefficients are read as a
     scalar-product numerator);
   - a completion by lower integrals, one power of ε each, fitted over several kinematic points;
   - replacing the source masters by derivatives of clean masters, with operators that keep the coefficients
     polynomial;
   - a new maximal-cut basis, checked with maximal-cut-basis;
   - flagging the sector.
- **The gate.** Every change is applied exactly to the slice. It is accepted only when:
   - the sector's rows are pole-free, and no new pole appears except in rows above, deferred to their own sector
     when that sector's fix can still remove them (factors the change removed from its own rows, or factors that
     sector's rows already had);
   - coefficients that were fitted hold at two more kinematic points;
   - each new master carries one power of ε per integral, with no ε in a denominator;
   - no entry rises above ε² (the cap, at ε → ∞ for an entry with poles too; an entry above it before may keep its
     power until its sector is fixed, not raise it);
   - a change of the maximal-cut basis also passes the maximal-cut-basis check (Kira on the cut at two points, the
     Euler relation). Its determinant on the old basis is recorded, not judged: the DE alone decides. Such changes
     are always reported first.
- **Reductions.** The IBP reductions of a sector's subtree run with LiteIBP and FiniteFlow (Kira reduces the slice
   point when the subtree lies in one family; a job includes the sector's image sectors by default, and then spans
   several families), at the slice point and at extra points, and are calibrated entry by
   entry against the slice before they are used. Each job predicts its memory from a model that calibrates itself
   on the machine, and refuses to start learning when the job will not fit. Job folders are self-contained, so a
   large one can run on a bigger machine.
- **Simplification.** Once the census is clean outside flagged sectors, step 7 of `SKILL.md` lowers the kinematic
   degrees of the DE by changes that keep the census, each through the gate. It asks you for a time budget first
   (`pole-free-basis/reference/simplify.md`).


## What is in the repository

| path | what it is |
|---|---|
| `maximal-cut-basis/SKILL.md`, `pole-free-basis/SKILL.md` | the instructions each agent reads first |
| `core/` | what both skills share, found next to them (or in `SKILL_CORE`): `bin/ws` and `bin/limit` (licence slots, time and memory limits), the tool paths and preflight, the sector records, the ledger of tools and papers behind `CITATIONS.md`, the HTML pages and the JSON verdict the scripts end with (`core/README.md`) |
| `*/reference/` | the method, the workflow, the escalation ladder, file formats, known pitfalls, the third-party tools; `maximal-cut-basis/reference/limits.md` has the time and memory limits of both skills, `maximal-cut-basis/reference/picard-fuchs.md` the Picard-Fuchs step and `pole-free-basis/reference/simplify.md` the simplification phase |
| `maximal-cut-basis/lib/` | the Mathematica toolkit: `MaximalCutBasis.wl` loads the nineteen packages in `lib/MCB/` |
| `pole-free-basis/lib/` | the Mathematica toolkit: `PoleFreeBasis.wl` loads eighteen of the nineteen packages in `lib/PFB/`; the nineteenth, `DegreeGraph.wl`, is loaded by the reduction runner, which also loads the self-contained `Machine.wl`, `Kira.wl` and `JobCitations.wl` |
| `maximal-cut-basis/bin/` | `ws` (starts `wolframscript` when a licence slot is free), `preflight.wls`, `validate_family.wls`, `find_masters.wls`, `run_sector.wls` (one sector in one kernel), `new_sector.wls`, `check_basis.wls` (the gate), `finiteflow_sector.sh`, `write_ff.wls`, `picard_fuchs.wls` (the Picard-Fuchs step of one finished sector), `make_reports.wls`; for runs without an agent, `auto_pass.wls` and `run_all.sh` |
| `pole-free-basis/bin/` | `preflight.wls`, `validate_system.wls`, `singularities.wls` (SOFIA's candidate singularities, optional), `import_liteibp.wls`, `import_slice.wls`, `local_slice.wls`, `census.wls`, `sources.wls`, `subtree_job.wls`, `subtree.wls` (the reduction runner), `calibrate.wls`, `new_sector.wls`, `slot_scan.wls`, `pair_scan.wls`, `maxcut_candidates.wls` (rung 8), `extra_masters.wls`, `relation_sector.wls`, `coefficients.wls`, `degrees.wls` (the kinematic degrees of the DE), `det_line.wls` (det T of a change along a line), `simplify.wls` (the simplification phase), `wait_job` (waits for a reduction without a licence slot), `approve.wls`, `make_reports.wls`, and `ws` (shared with maximal-cut-basis) |
| `*/templates/` | input files to start from, the per-sector analysis scripts (`AnalysisMasters.m`, `AnalysisPoles.m`), the FiniteFlow check's scripts (`maximal-cut-basis/templates/ff/`); the HTML page template is in `core/templates/` |
| `*/tests/` | the tests, run from the skill's folder: `bin/ws tests/<name>.wls`, or `tests/<name>.sh` for an integration test (it starts its kernels through `bin/ws`); exit code 0 when every test passes. Most run on planted data and need no third-party tool; the header of a test that does names the tools (Kira, FiniteFlow, LiteRed, LiteIBP, BaikovPackage) and where it takes their paths (a `paths.wl` argument or `PFB_TEST_PATHS`; else the usual detection) |
| `maximal-cut-basis/examples/` | five public families and what to expect from each |

## Citing and acknowledging

If you use the skills, please cite the paper:

```bibtex
@article{PetitRosas:XXXX,
    author        = "Petit Ros{\`a}s, Pau and Torres Bobadilla, William J.",
    title         = "{Agent-guided construction of Feynman integral bases}",
    eprint        = "2611.26688",
    archivePrefix = "arXiv",
    year          = "2026"
}
```

If you use results from either skill in a paper, also cite what the run's `CITATIONS.md` lists under "Cite": the tools
and methods that ran, and the papers behind the final bases, whose authors you should also acknowledge. It says
which sector used each one and how. The papers under "Also consulted" went only into attempts that are not in the
result (rejected, declined, not adopted, not tried, or replaced later). The pages show the same lists, and
`reference/tools.md` has the full references of the tools, checked against INSPIRE, arXiv and CrossRef. A
pole-free-basis run starts from a DE made outside the skill: cite the tools that produced it too (`CITATIONS.md`
lists them when its `conventions.wl` names them under `"Credits"`).

## Licence

MIT, see `LICENSE`. The third-party tools have their own licences.
