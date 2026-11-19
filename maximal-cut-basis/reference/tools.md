# Third-party tools

None of these ships with the skill. `bin/preflight.wls` looks for each one and runs a small test with it; a
missing tool only disables the steps that need it.

Tools are looked for in this order: `paths.wl`, then an environment variable named `MCB_<TOOL>` (for example
`MCB_BAIKOVPACKAGE` or `MCB_KIRA`), then `FindFile` and the `PATH`, and finally
`$UserBaseDirectory/Applications`, `$BaseDirectory/Applications` and a few usual folders under `$HOME`
(`software`, `src`, `opt`, `.local`). When the user tells you where a tool is, call
`MCBSetPath["tool", "/path"]` or add it to `paths.wl`.

| tool | what it is used for | needed by | preflight test | where to get it |
|---|---|---|---|---|
| Wolfram Engine or Mathematica 13+ | runs the toolkit | everything | – | wolfram.com |
| BaikovPackage | loop-by-loop and standard Baikov representations | the Baikov step, all candidates | a one-loop bubble | github.com/HjalteFrellesvig/BaikovPackage (a single file) |
| Kira 3+ with Fermat | numeric reductions on the maximal cut (`cut_propagators`, `--set_value`) | the Kira check, the recount of masters, the exported DE | a tadpole on its cut at a numeric point | kira.hepforge.org; Fermat from home.bway.net/lewis (`fer64`, or set `$FERMATPATH`) |
| FiniteFlow | the analytic check of the maximal-cut DE, and the DE along a line of the Picard-Fuchs step | `finiteflow`, `picard-fuchs` | reconstructing a rational function of two variables | github.com/peraro/finiteflow; after building it, `FiniteFlow.m` is in `mathlink/` and `fflowmlink.so` in the build folder (give that folder as `"FiniteFlowLibrary"`) |
| LiteRed 2 | sector analysis and IBPs for LiteIBP | `finiteflow`, `picard-fuchs` | loading it | github.com/rnlee/LiteRed (`LiteRed2023.m`) |
| LiteIBP | IBP, Lorentz-invariance and symmetry identities on the cut | `finiteflow`, `picard-fuchs` | a one-loop family | part of **finiteflow-mathtools** (github.com/peraro/finiteflow-mathtools, `packages/LiteIBP.m`), not of FiniteFlow itself |
| DlogBasis | a cross-check of the leading singularities of the final masters | `dlogbasis-crosscheck` (optional) | the leading singularities of `1/(x(1-x))` | the ancillary files of arXiv:2002.09492 |
| INITIAL | rung 6 | `algorithms` (optional) | loading it | github.com/UT-team/INITIAL |
| Libra | rung 6 | `algorithms` (optional) | loading it | rnlee.bitbucket.io/Libra |
| Fuchsia | rung 6, for systems in one variable | `algorithms` (optional) | `--help` | a Python package; see its documentation |

**Outside the toolkit: SageMath with ore_algebra.** The toolkit never runs it. When the Picard-Fuchs step leaves
a block `unresolved` (`reference/picard-fuchs.md`), tell the user that ore_algebra's `L.factor()` factors it
completely. It needs Sage 9.0 or later, and the README installs it with
`sage -pip install --user --no-build-isolation git+https://github.com/mkauers/ore_algebra.git`. Licence: GPL,
version 2 or later. When its factorisation goes into a sector, declare it (`--tool ore_algebra`, below).

A few more things worth knowing:

- The licence line of the preflight (`$MaxLicenseProcesses`, subkernels, CPUs; kept in
  `~/.cache/maximal-cut-basis/preflight.log`) decides how many kernels `bin/ws` lets run at once, how many
  subkernels FiniteFlow may use, and the queues of a batch run without an agent (`Parallel`). The queues leave
  one kernel free for the user; `bin/ws` does not, and starts a script whenever a licence slot is free.
- Kira runs with `--parallel` set to `$MCBKiraThreads` (by default four, or fewer if there are fewer CPUs), under
  a time limit (`$MCBKiraTimeLimit`, or `"TimeLimits" -> <|"Kira" -> ...|>` in `run.wl`) and a memory limit
  (`$MCBKiraMemoryLimit`, or `"MemoryLimits" -> <|"Kira" -> ...|>`), both enforced by `core/bin/limit`.
- BaikovPackage handles three loops, and the representation search tries every loop order, but the only
  three-loop family the skill has been tested on is the banana of `examples/`.

## Citations

A tool or method is credited in the run's ledger, `citations.m`, to the sector it produced something for (a
representation, a reduction, a DE, a label), not when it was loaded or tested; `CITATIONS.md`, the pages and
`basis.m` (`"toolsUsed"`, `"citations"`) are written from the ledger. A tool you run by hand is credited only when
you declare it: `bin/ws bin/check_basis.wls ... --tool NAME` (once per tool), or `CoreRecordTool[sectorDir,
{"NAME"}, "declared"]`. NAME is a key of the registry: `BaikovPackage`, `kira`, `fer64`, `FiniteFlow`, `LiteRed`,
`LiteIBP`, `DlogBasis`, `INITIAL`, `Libra`, `Fuchsia`, the methods `Baikov`, `CanonicalDE`, `Tarasov` and
`PicardFuchs`, and `SOFIA` and `ore_algebra`, which run outside the toolkit. An unknown name is refused. Papers
used along the way (a basis from the literature, a map, an idea) are not tools: they go to the same ledger (see
`SKILL.md`, "Citing and acknowledging"). The references below were checked against INSPIRE, arXiv, CrossRef and
the publishers' pages on 2026-10-15:

- BaikovPackage: H. Frellesvig, *The loop-by-loop Baikov representation – strategies and implementation*,
  JHEP 04 (2025) 111, arXiv:2412.01804.
- DlogBasis: J. Henn, B. Mistlberger, V. Smirnov, P. Wasser, *Constructing d-log integrands and computing
  master integrals for three-loop four-particle scattering*, JHEP 04 (2020) 167, arXiv:2002.09492.
- FiniteFlow: T. Peraro, *FiniteFlow: multivariate functional reconstruction using finite fields and
  dataflow graphs*, JHEP 07 (2019) 031, arXiv:1905.08019. LiteIBP belongs to finiteflow-mathtools, by the same author.
- LiteRed: R. N. Lee, arXiv:1212.2685, and *LiteRed 1.4*, J. Phys. Conf. Ser. 523 (2014) 012059, arXiv:1310.1145.
- Kira, the three papers its web page asks users to cite: F. Lange, J. Usovitsch, Z. Wu, *Kira 3: integral
  reduction with efficient seeding and optimized equation selection*, Comput. Phys. Commun. 322 (2026) 109999,
  arXiv:2505.20197; J. Klappert, F. Lange, P. Maierhöfer, J. Usovitsch, *Integral reduction with Kira 2.0 and
  finite field methods*, Comput. Phys. Commun. 266 (2021) 108024, arXiv:2008.06494; P. Maierhöfer,
  J. Usovitsch, P. Uwer, *Kira – A Feynman integral reduction program*, Comput. Phys. Commun. 230 (2018) 99,
  arXiv:1705.05610.
- Fermat: R. H. Lewis, *Computer Algebra System Fermat*.
- INITIAL: C. Dlapa, J. Henn, K. Yan, JHEP 05 (2020) 025, arXiv:2002.02340.
- Libra: R. N. Lee, Comput. Phys. Commun. 267 (2021) 108058, arXiv:2012.00279.
- Fuchsia: O. Gituliar, V. Magerya, Comput. Phys. Commun. 219 (2017) 329, arXiv:1701.04269.
- The Picard-Fuchs step, when it labelled a block with the p-curvature (`"PicardFuchs"`): N. M. Katz, *Algebraic
  solutions of differential equations (p-curvature and the Hodge filtration)*, Invent. Math. 18 (1972) 1–118,
  doi:10.1007/BF01389714, and *Nilpotent connections and the monodromy theorem: applications of a result of
  Turrittin*, Publ. Math. IHÉS 39 (1970) 175–232, doi:10.1007/BF02684688.
- For an `unresolved` Picard-Fuchs block, outside the toolkit: ore_algebra, M. Kauers, M. Jaroschek,
  F. Johansson, *Ore Polynomials in Sage*, Lect. Notes Comput. Sci. 8942 (2015) 105–125, arXiv:1306.4263; its
  factorisation, F. Chyzak, A. Goyer, M. Mezzarobba, *Symbolic-Numeric Factorization of Differential Operators*,
  Proc. ISSAC '22 (ACM, 2022) 73–82, arXiv:2205.08991.
- The methods, each where it was applied: the Baikov representation (`"Baikov"`, where Baikov representations
  were built), Baikov, arXiv:hep-ph/9611449, and Frellesvig and Papadopoulos, arXiv:1701.07356; the canonical DE
  (`"CanonicalDE"`, where a basis was checked for an ε-factorised DE), Henn, arXiv:1304.1806; and Tarasov,
  arXiv:hep-th/9606018, when the dimension shift was used.

The same text lives in the registry `$MCBTools` of `core/lib/Core/Tools.wl`, which the pages and `CITATIONS.md`
print; correct it there too.
