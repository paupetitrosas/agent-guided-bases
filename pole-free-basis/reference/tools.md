# Tools

Nothing third-party ships with the skill. Paths are detected by the maximal-cut-basis toolkit
(`MCBLoadPaths`) or given in `paths.wl`; SOFIA is never looked for, only `paths.wl` names it.

| tool | needed for | without it |
|---|---|---|
| maximal-cut-basis skill | family objects, derivatives, tool detection, the maximal-cut gate (rung 8); `bin/ws` and the rest of the shared `core/` come with it | nothing runs: install it next to this skill, or set `PFB_MCB` to the path of its `lib/MaximalCutBasis.wl` |
| BaikovPackage | the structural reading (`MCBLoopByLoopReport`: loop-by-loop Baikov representations, twist factors, boundaries) | sectors are read from their rows only, with no loop-by-loop report to suggest candidates; rung 8 gets no candidates from the toolkit's routes and no replayed steps |
| FiniteFlow (+ its MathLink library) | every reduction, the sparse linear solver of rungs 4 and 6, the kinematic degrees (`FFAllDegrees`, `FFAlgLaurent`) and det T along a line | slices, census, source test and rung 1 still work; rungs 2 to 8 need reductions made elsewhere; degrees only as the user gives them with a slice |
| LiteRed | families, sector maps, symmetries in the reductions | no reductions |
| LiteIBP | identities, derivatives, serialization for FiniteFlow | no reductions |
| Kira, with Fermat (fer64) | the slice point of a reduction job whose subtree lies in one family (`reference/workflow.md`, "Which reducer"; degree and line jobs are FiniteFlow's at every point), and the maximal-cut gate (through maximal-cut-basis) of every change of the maximal cut: rung 8, a scanned set that mixes the sector's masters, a swap of the simplification phase | FiniteFlow reduces every point, the slice point included (it learns the whole subtree even for one point); a change of the maximal cut is not checked on the cut, and `CHANGES.md` lists it as not verified |
| SOFIA (optional) | the candidate singularities of each family (`bin/singularities.wls`), offered as letters to a family without `"Letters"` | a family's `"Letters"` are its only known singularities |

Install hints and versions are in the maximal-cut-basis `reference/tools.md`, except SOFIA's (below).

## SOFIA

SOFIA lists the candidate singularities of a Feynman graph: irreducible polynomials in the invariants and masses,
those of its subgraphs included. The list is a superset (the sheet of a singularity is not known), and SOFIA cannot
test a given polynomial. It is written in the Wolfram Language (Mathematica 13 or later), under the MIT licence.

Install it at the commit the skill was tested with, and name its `scr.m` in `paths.wl`:

```sh
git clone https://github.com/StrangeQuark007/SOFIA.git
git -C SOFIA checkout d4498b95ffcd9f43ba6bce3899c133d3487b5a65
```

```mathematica
"SOFIA" -> "/path/to/SOFIA/scr.m"      (* in paths.wl; or the environment variable MCB_SOFIA *)
```

Never name `SOFIA.m`. It is a loader that downloads `scr.m` from the main branch on GitHub at every load (and calls
`NotebookDirectory[]`), so the version would change without notice; the preflight and `bin/singularities.wls` refuse
it, and any file that loads code from the network. The repository has no release tags: the tested version is commit
`d4498b9` of 2025-12-20, whose `scr.m` has the git blob `396668c8526ec23958f3a307181265cdd87b194c`. The preflight
prints the version, the commit of a git checkout of SOFIA, and whether the file is that blob.

Only `bin/singularities.wls` loads `scr.m`, in its own kernel: SOFIA changes ``System`CenterDot`` and ``System`Wedge``,
prints a lot, and exports one-letter symbols (`s`, `t`, `m`, `M`, `mm`, `MM`, `p`, `d`, ...) that would clash with
the families' invariants. It is loaded with the context path restored afterwards and runs in a scratch context; its
results come back renamed into each family's invariants (`reference/workflow.md`, "Known singularities").
Effortless, SOFIA's construction of letters, is not needed and is not loaded.

## Citations

When results are reported, list the tools that produced them and ask the user to cite them: the run's
`CITATIONS.md` has the list. A tool is credited in the run's ledger, `citations.m`, to the sector it produced
something for, not when it was loaded:

- a reduction job (`bin/subtree.wls`, the job's `"SectorKey"`, else the whole run) credits LiteRed and LiteIBP for
  its identities and maps, FiniteFlow for a point it reduced and for what its learned system gave (learned masters,
  analytic coefficients, degrees, a line unless its check refuted it), and Kira and Fermat once Kira's reduction
  of the slice point is written. A job outside a run's `jobs/` folder appends nothing; its `status.m` keeps the record
  (`"Tools"`), which the run reads once the job is in its `jobs/` folder;
- the sparse solver of rungs 4 and 6 credits FiniteFlow when FiniteFlow solved, and `bin/singularities.wls` SOFIA,
  for the whole run, for each family it gave polynomials;
- the structural reading, rung 8 and the maximal-cut gate credit what they run through maximal-cut-basis (among
  them BaikovPackage and the Baikov representation, Kira and Fermat, the canonical-DE check) to their sector;
- a maximal-cut-basis run (`"MCBRun"`, or `<run>/maxcut/<fam>/`) is credited for a sector, with its own tools and
  papers of that sector (`PFBImportMaxCutCredits`), in two ways. A recorded change that took from it (a rung-8
  change, every sector the maximal-cut gate checked, a move (i) rescaling that took its normalisations) carries them
  with its id: cited while the change is accepted or pending, consulted otherwise. And every write of `CITATIONS.md`
  (`PFBWriteCitations`: `bin/make_reports.wls`, a change with papers, an approval, a decline, a paper recorded, the
  slice's credits) first credits the `"MCBRun"` of a family for every sector that still keeps a starting master no
  accepted change replaced (`PFBStartCredits`; a rescale, rung 1 or move (i), keeps the same integrals and replaces
  none). What is only read
  for candidates that no change takes is not credited;
- the tools that produced the starting DE are credited only when `conventions.wl` names them (`"Credits"`,
  `reference/formats.md`).

A tool you run by hand for a change goes into `PFBTryChange` (or `PFBTryRescale`) info `"Tools"`, by its name in the
registry of `core/lib/Core/Tools.wl` (`kira`, `fer64`, `FiniteFlow`, `LiteRed`, `LiteIBP`, `BaikovPackage`, `SOFIA`,
...; any case, or the display name, such as `Kira` or `Fermat`); an unknown name leaves the change not tried. Papers used along the way are not tools: they go to the same ledger (see
`SKILL.md`, "Papers and tools you use"). The references of the tools:

- BaikovPackage: H. Frellesvig, JHEP 04 (2025) 111, arXiv:2412.01804.
- FiniteFlow: T. Peraro, JHEP 07 (2019) 031, arXiv:1905.08019.
- LiteRed: R. N. Lee, arXiv:1212.2685; J. Phys. Conf. Ser. 523 (2014) 012059, arXiv:1310.1145.
- LiteIBP: the `finiteflow-mathtools` package by T. Peraro.
- Kira (slice points, rung 8): F. Lange, J. Usovitsch, Z. Wu, Comput. Phys. Commun. 322 (2026) 109999, arXiv:2505.20197;
  J. Klappert, F. Lange, P. Maierhöfer, J. Usovitsch, Comput. Phys. Commun. 266 (2021) 108024, arXiv:2008.06494;
  P. Maierhöfer, J. Usovitsch, P. Uwer, Comput. Phys. Commun. 230 (2018) 99, arXiv:1705.05610.
- Fermat (used by Kira): R. H. Lewis, Computer Algebra System Fermat, http://home.bway.net/lewis/.
- SOFIA (`bin/singularities.wls`, when a family's known singularities or letters came from it): M. Correia,
  M. Giroux, S. Mizera, "SOFIA: Singularities of Feynman Integrals Automatized", arXiv:2503.16601, Comput. Phys.
  Commun. 320 (2026) 109970.

These references were checked against INSPIRE, arXiv and CrossRef on 2026-10-15 (SOFIA's against INSPIRE on
2026-10-16); the maximal-cut-basis `reference/tools.md` has the others with their titles.
