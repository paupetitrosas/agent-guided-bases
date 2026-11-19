# The Picard-Fuchs step

The step `picard-fuchs` finds the geometry of a sector's maximal cut from a Picard-Fuchs operator, and gives it a
label: `polylog`, `polylog (nested root)`, `elliptic`, `genus-g`, `K3`, `CY_n`, `non-polylog (order k)` or
`unresolved (order k)`.

1. It reconstructs the maximal-cut DE of the masters along a line through kinematic space, at ε = 0.
2. It splits off every piece of first order: rational functions and their roots, possibly joined by logarithms. A
   block of order 4 or 5 that is left is also split into pieces of order 2 when it has them.
3. It reads each block that is left through its Picard-Fuchs operator: its order, its logarithms and its
   p-curvature.

The label steers the first pass and decides whether `eps-polynomial` can be a sector's final status. The step never
builds or changes a basis. The operator is evidence about the geometry, and periods stay out of the skill.

## When it runs

- **In the first pass.** `run_sector.wls` (`MCBAutoPass`) runs it right after the recount of the masters, before
  any candidate search. It runs in the same kernel, with the Kira check's points, the recount's masters and Kira
  rules, and the Baikov representations already built. Its time limit is `"TimeLimits" -> <|"PicardFuchs" -> 300|>`
  in `run.wl` (seconds); when it is reached, the label is `not computed`.
- **On its own.** `bin/ws bin/picard_fuchs.wls run.wl j<pattern> [--dry-run] [--verbose]` (or a run folder in place
  of `run.wl`) runs it for a sector done before the step existed, or runs it again; `--verbose` shows FiniteFlow's
  and LiteRed's output. It recounts the masters and builds the representations itself. It writes the
  classification into `basis.m`, records the label in `attempts.m` and redraws the pages. When the label changes
  whether `eps-polynomial` can be final, it also updates the status and records the change in `attempts.m`.
- **Switched off.** `"Skip" -> {"picard-fuchs"}` gives `skipped by user`, and the Baikov geometry decides as before.
- **Not applicable.** A family with one scale has no line to vary: its DE is fixed by the mass dimension, and the
  label is `not applicable`.

**Neighbours.**
- The Baikov geometry (`geometry` in `basis.m`, `MCBGeometry`) reads the polynomials of one representation. The
  operator reads the masters that exist, so it decides when the two disagree.
- The FiniteFlow check (step 5) reconstructs the DE of the final basis in every invariant. This step reconstructs the
  DE of the cut's masters on one line, at the start of the pass.

## How it works

1. **Line.** The line starts at the first point of the Kira check (`MCBPoints[fam, 2, seed]`, `points` in `basis.m`)
   and runs in a random direction whose components are small integers. It is written in the variables of the
   FiniteFlow pipeline, with UnitScale = 1: x(t) = p0 + t v. A generic line shows the generic geometry. A line through
   a second random point would carry coefficients hundreds of digits long into everything that follows. The singular
   points on the line are algebraic numbers, so each one is handled through the irreducible factor over ℚ that it is a
   root of.
2. **DE on the line.** `MCBFFLineDE` writes the analytic check's pipeline with the masters of the cut as its basis.
   It runs `genIBPs.m` and `SetSDE.m` in line mode inside the kernel (`MCB_FF_MODE=line`, `MCB_FF_INKERNEL=1`).
   The DE comes out as A(t, ε) = Σ_k A_k(t) εᵏ: first up to ε⁰, reconstructed in t alone with every thread.
3. **A frame regular at ε = 0.** The masters Kira picks can have a DE with poles in ε. Setting ε = 0 there would lose
   exactly the masters that live on boundaries (the zero sets of O(ε) twist factors). `MCBPFRegularise` handles this
   in two ways:
   - it tries the shifts J_i → ε^{s_i} J_i first;
   - otherwise it builds the smallest lattice of the masters that is stable under the DE (`"lattice"`).

   The ε = 0 connection then has full rank. When it needs more orders of ε, FiniteFlow is asked for them, on the IBPs
   it already has.
4. **Pieces of first order.** `MCBPFClassifyConnection` works on the system itself. Its zero pattern splits it into
   blocks. In each block, a solution h·R of the system or of its dual is split off by a change of frame, until none is
   left; h is a product of powers of the singular factors and R is a polynomial vector. Each such piece is a rational
   function, a root of one, or a logarithm through an extension.

   The order-n operator of the whole DE is never formed. A random cyclic vector would give it apparent singularities
   of high degree and coefficients thousands of digits long.

   **Pieces of order 2.** A block of order 4 or 5 that keeps no first-order piece can still be two pieces glued
   together: two elliptic curves, or an algebraic block under an elliptic one. A plane of solutions of the system is a
   solution of its exterior square (a system of order 6 for a block of order 4, 10 for order 5) whose Plücker
   relations vanish. The same search for h·R finds it, and a change of frame splits the block along the plane. For
   order 5 the dual is searched too, for a quotient of order 2. The pieces are peeled again. Order 3 needs no such
   search: a piece of order 2 there would leave one of first order. Each block records the outcome in `secondOrder`:
   - `not needed` (order 2 or 3) or `none`;
   - `invariant form`: one invariant bivector, and it is not a plane. For order 4 it is a symplectic form, as the
     periods of a genus-2 curve have;
   - `invariant forms`: several independent invariant bivectors, and no plane among those the search tries;
   - why the search stopped: `too large`, `time limit`, `no cyclic vector`, `not split`, `not searched (order above 5)`.

   **A limit: the same elliptic curve twice.** A block of order 4 made of two copies of one order-2 piece, V ⊕ V (one
   elliptic curve seen by two pairs of masters, say), has planes of solutions, but the search does not find them. Its
   exterior square has a net of invariant bivectors with the same character, three independent ones, and the planes
   are the members of the net on a conic (the Plücker relation). The search looks for a decomposable bivector among
   the solutions it finds one by one, or in a pencil of two. Such a block stays `unresolved (order 4)` with
   `secondOrder` `invariant forms`, and its reason says that the same elliptic curve seen twice does this. In a frame
   with constant entries the search may stop earlier, with `no cyclic vector`: the seeds, linear in t, are not cyclic
   for a character that appears three times. SageMath's `L.factor()` splits such a block. One elliptic curve glued to
   itself by a logarithm (V ⊗ U, U unipotent) has one plane and is split.

   The search has its own limits, `"SecondOrderTime" -> 120` seconds per block and `"SecondOrderMaxOrder" -> 5`
   (options of `MCBPFClassifyConnection`; 3 switches it off).
5. **The blocks that are left.** Each one is read through the operator of a cyclic vector, of the block's own small
   order (`MCBPFClassifyOperator`). That operator has no first-order factor left: a right one would be a solution of
   the system, a left one a solution of its dual, and step 4 searched both. Only when that search stopped early
   (too many choices of exponents, no cyclic vector, a solution it could not split off) does the operator get a
   search of its own (`MCBPFPeel`), which costs minutes for a block of order 4. Then:
   - **Singular points.** Each one comes with its rational local exponents and the highest power m of log in the
     solutions there (`MCBPFLocal`). Only the system's own singular points are read; the others are apparent. When
     an exponent has several Jordan blocks, the solutions with one log are counted too, so that m = 1 is exact
     (genus g needs it).
   - **The p-curvature at three primes** (`MCBPFPCurvature`). It is nilpotent for an operator of geometric origin,
     and zero when the solutions are algebraic (Katz).
   - **For order 3, an invariant quadratic form.** It is decided on the system first. Sym² of the block's system
     has a hyperexponential solution exactly when the block is a symmetric square. Only the system's own singular
     points are read, so this takes seconds in any frame, the frame of a split included. When that search cannot
     decide, the operator is tested (`MCBPFSymmetricSquareQ`): directly, then through the operators of the block's
     unit vectors, then with a module test of up to 60 s.
6. **Label.** Each block gets a label from the table below (`MCBPFLabel`), from its log powers, p-curvature,
   symmetric-square test, local exponents and the outcome of the search for pieces of order 2. An operator classified on
   its own (`MCBPFClassifyOperator`, no system) is searched for pieces of order 2 on its companion system when its block
   has order 4 or 5. The sector's label comes from its blocks:
   - `polylog` when no block is left;
   - otherwise the non-polylog block of largest order;
   - otherwise an unresolved block;
   - otherwise a nested root.

   A block that is not of geometric origin makes the whole sector `unresolved`. Two elliptic curves stay two blocks.
   The order of the corner integral's operator (`cornerOrder`) comes from the rank of its derivatives, without
   forming that operator.
7. **Checks.** Two:
   - **Kira.** The line DE at t = 0 must equal Kira's at the first point. It uses one small Kira run when the
     recount's rules do not reach the derivatives. A disagreement makes the label `unresolved`.
   - **Baikov curve.** For `elliptic` and `genus-g`, the log points of the deciding block must be the points where the
     curve of a one-variable representation degenerates on the same line. For genus 1 these are the poles of j.
     Above that they are the zeros of the discriminant where two branch points meet (nodes). Where three meet (a
     cusp) the monodromy has finite order and the operator has no log, so those zeros are left out.

## Labels

Let B be a block left after the pieces of first order (and of order 2, for blocks of order 4 and 5), of order k, and
m the highest power of log at any of its singular points.

Blocks of order 2 and 3 are irreducible once the pieces of first order are gone. A block of order 4 or 5 is irreducible
when the search for pieces of order 2 ran to its end without a plane (`secondOrder` `none` or `invariant form`); a
block of order 6 or more is never searched, so it is never known to be irreducible. "The exponents of an elliptic
family" means that at every point the two exponents differ by 0, 1/2, 1/3 or 2/3 modulo 1 (for Sym², the three are
c − d, c, c + d with such a d). These are the local monodromies of SL₂(ℤ), up to a rank-one twist. The condition is
necessary, not sufficient: 2F1(1/5, 4/5; 1; t), an order-2 piece of the periods of a curve of genus 2, fails it at
infinity.

| block | label | what it says |
|---|---|---|
| none (k = 0) | `polylog` | every solution is a rational function, a root of one, or a logarithm of those; the skill then expects a dlog basis, which this step does not construct or prove |
| m = 0 and zero p-curvature at every prime | `polylog (nested root)` | finite monodromy, solutions algebraic but not roots of rational functions (√(A + B√D)) |
| k = 2, a log somewhere, the exponents of an elliptic family | `elliptic` | the monodromy of a family of elliptic curves |
| k = 3, m = 2 at some point, invariant quadratic form, the exponents of Sym² of an elliptic family | `K3` | a symmetric square of an elliptic family |
| k = 4 or 5, irreducible, m = k − 1 at some point and 0 < m < k − 1 at another; for k = 4 one invariant symplectic form (`secondOrder` `invariant form`) | `CY_(k−1)` | a point of maximal unipotent monodromy, and not a symmetric power Sym^(k−1) of an order-2 block (whose log points all have m = k − 1). For k = 5 no invariant quadratic form is tested |
| k = 4, irreducible, one invariant symplectic form, m = 1, Baikov curve of genus 2 on the line | `genus-2` | a curve of genus 2 |
| k = 2 with a log, or k = 3 with m = 2 at some point and an invariant quadratic form, but not the exponents above (any other block of order 3 with a log is `unresolved`); k ≥ 4 with m = k − 1 somewhere but not the CY row | `non-polylog (order k)` | not polylogarithmic (an irreducible block with a log, or a point of maximal unipotent monodromy, which no polylogarithmic block without first-order pieces has), of a type the table does not name; the reason says what is missing: the exponents of an elliptic family, a finished search, the symplectic form, or a log point of lower power (Sym³ of an elliptic block, for instance) |
| anything else | `unresolved (order k)` | see below |

`genus-g` for g ≥ 3 would need a block of order 6 or more known to be irreducible, which the step cannot show: such a
block is `unresolved`, and its reason says so. An irregular singular point, an irrational exponent or a p-curvature
that is not nilpotent also gives `unresolved`, with that reason. These mark a block that is not of geometric origin,
which usually means a wrong DE.
The other outcomes are `not computed` (time limit, a missing tool, FiniteFlow failing), `not applicable` and
`skipped by user`.

## What the label does

| label | route of the first pass | final `eps-polynomial` | ladder |
|---|---|---|---|
| `polylog`, `polylog (nested root)` | as the representations say | never; the sector ends `eps-polynomial (dlog search incomplete)` at best | unchanged |
| `elliptic`, `genus-g`, `K3`, `CY_n`, `non-polylog (order k)` | curve and single-integral routes only (single integrals when no representation has one) | allowed | skip the dlog-only work: the larger dlog pools of rung 1, the dlog candidates of rung 4 |
| `not computed`, `unresolved`, `not applicable`, `skipped by user` | as before | as the Baikov geometry says | unchanged |

A `polylog (nested root)` sector that has no ε-form basis keeps the retry hint "ε-form needs √(A+B√D), not built".
The skill's bases use rational and single-root normalisations only. `MCBStatusFor[check, reps, classification]`
applies the middle column everywhere a status is decided: the first pass, `check_basis.wls`, `AnalysisMasters.m`
and `picard_fuchs.wls`.

## Output: `basis.m` → `classification`

| key | content |
|---|---|
| `label`, `reason` | the label and why |
| `order`, `factors` | the number of masters; `<|"firstOrder", "blocks"|>`: how many pieces of first order were split off, and the orders of the blocks left |
| `blocks` | each block's own classification (label, reason, operator, local data, p-curvature, symmetric-square test, size, `secondOrder`) |
| `cornerOrder` | the order of the corner integral's operator |
| `operator`, `block` | the deciding block's operator and what is left of it after its first-order factors: coefficient lists {a₀, …, a_n} in `\[FormalT]`, the line variable |
| `local` | per singular point of the deciding block: `point` (an irreducible polynomial in `\[FormalT]`, or `Infinity`), `exponents` ({e, multiplicity}), `logPower` ({lower, upper} bound on m), `apparent`, `fuchsian`, `irrational` |
| `logPower`, `pCurvature`, `symmetricSquare` | the largest log power, the p-curvature per prime, the quadratic-form test (k = 3) |
| `masters`, `line`, `search` | the masters of the cut (Kira's recount); the line: `points` (of the Kira check), `variables`, `p0`, `v`; `"complete"`, or `"too large"` when a search for first-order pieces had more than 20000 choices of exponents (`` MaximalCutBasis`PicardFuchs`Private`$MCBPFMaxTuples ``, a private constant) |
| `epsOrders`, `regularisation`, `orderDrop` | the orders of ε used, the frame (`none`, `diagonal`, `lattice`), and 0, or `Missing["RegularisationFailed"]` |
| `baikovGenus`, `baikovCheck` | the genus of the first one-variable Baikov curve, and the check of its degenerations: `status` is `agree`, `disagree`, `mismatch` (a polylog operator next to a Baikov curve that no master sees) or `not applicable` |
| `kiraCheck` | `agree`, `disagree` or `not compared`, with a message |
| `timing`, `time` | seconds spent on the recount (standalone only), the line DE, the Kira check and the analysis, and in all |

The sector page has a "Picard-Fuchs operator" section (label, order and factors, corner order, both checks; the exponents and log powers stay in `basis.m`), and `summary.html` shows the label in the geometry column
with the Baikov class under it. `MCBClassificationFlags` turns a classification into flags. Each one starts with
"Picard-Fuchs:" and covers one of these: an unresolved block, no regular frame, a check that disagrees, or an
ε-form basis on a non-polylog label. A check that disagrees and the ε-form contradiction flag the sector
(`MCBFlaggedQ`): `summary.html` lists it with the sectors that need attention, and its retry hints say to find which
side is wrong before relying on the label.

`basis.m` keeps its classification. A record written without one, by an `AnalysisMasters.m` generated before the step
existed, say, takes the one in `basis.m` (`MCBKeepClassification`, which `MCBWriteBasis` applies to every record), and
its status, flags and retry hints then follow the label as above. A change of status is recorded in `attempts.m`.

## Telling the user

Report the label of every sector you finish, together with what it did to the route and the status. Two cases need
more than the label.

- **`unresolved (order k)`.** The restricted factoriser could not label the block. A block of order 4 or 5 has
  already been searched for pieces of order 2, and the block's `secondOrder` says what that search found. What can
  remain:
  - a block that splits only into larger pieces;
  - a search that stopped early;
  - a block of order 4 with an `invariant form` and no Baikov curve of genus 2 on the line. Its periods are those of
    a genus-2 curve or of an abelian surface;
  - a block of order 4 with `invariant forms`: most likely the same elliptic curve twice (see step 4);
  - a block of order 6 or more, which is never searched for smaller pieces.

  Tell the user that SageMath's `ore_algebra` can factor it completely; `L.factor()` uses a symbolic-numeric
  algorithm. The skill does not run Sage. To hand the block over:
  `StringRiffle[ToString[#, InputForm] & /@ (MCBReadBasis[dir]["classification"]["block"] /. \[FormalT] -> t), ", "]`
  prints its coefficients. Then, in Sage:

  ```
  from ore_algebra import DifferentialOperators
  Dops, t, Dt = DifferentialOperators(QQ, 't')
  a = [ ... ]                       # the coefficients printed above, a_0 first
  L = sum(c*Dt^k for k, c in enumerate(a))
  L.factor()                        # irreducible factors; L.local_basis_monomials(pt) gives exponents and logs
  ```

- **`non-polylog (order k)`.** The sector is not polylogarithmic, and it is steered as the other non-polylog labels
  are, but the step cannot name the geometry. Say what the reason says is missing. Sage can factor the block and give
  its local data, as above.
- **`orderDrop` missing** (no frame regular at ε = 0). The ε = 0 operator would see only part of the sector, so
  geometry on a boundary could be missed. Say so. The Baikov boundary geometry on the page (`geometry` →
  `boundaries`) shows what may hide there.

## Believe it when

- `bin/ws tests/picard_fuchs.wls` passes. It runs 53 known-answer tests, in about 25 s:
  - planted operators: Legendre gives elliptic; its symmetric square gives K3; the mirror quintic gives CY₃;
    √(1 ± √t) gives nested root; products of first-order operators give polylog; two Legendre blocks at one point
    give log power exactly 1;
  - first-order factors on either side, and a random frame and seed;
  - a corrupted operator, which must give `unresolved`;
  - the ε regularisation: diagonal, lattice, and too few orders;
  - connections: a dense random frame, the zero connection, a log extension, two separate elliptic blocks, K3,
    CY₃, nested root;
  - pieces of order 2, in dense frames: two elliptic blocks glued (and the same block with the search switched off,
    which must give `unresolved (order 4)`); a nested root times a log extension, which must give
    `polylog (nested root)`; a K3 block
    glued to an elliptic one on either side (order 5); the quintic, which keeps its symplectic form and must not
    split;
  - the symmetric square decided on the system: K3 in a dense frame, and a generic order-3 system without one;
  - labels that need more than a log: the cubic, quartic and sextic 2F1 families give elliptic; 2F1(1/5, 4/5; 1) and
    its symmetric square give `non-polylog (order 2)` and `(order 3)`; Sym³ of Legendre gives `non-polylog (order 4)`;
    genus-2 needs a finished search for pieces of order 2;
  - the known limit: the same elliptic curve twice, in a rational frame, stays `unresolved (order 4)` with
    `invariant forms`;
  - records: a record written without a classification keeps the one in `basis.m` (and the status follows it), but
    not another sector's; a check that disagrees flags the sector.
- `bin/ws tests/picard_fuchs_examples.wls [paths.wl]` passes. It runs the whole step on the sunrise and the banana,
  in about 2 minutes, with the controls on the sunrise's real DE: a random change of frame keeps the label, and a
  perturbed DE gives `unresolved`.
- On the sector, `kiraCheck` is `agree`. For `elliptic` and `genus-g`, `baikovCheck` is `agree` as well.
- It was checked on four two-loop four-point families with massive internal lines (2026-10-14 and 15). Every sector
  whose geometry was known got that label: elliptic, genus 2 (with the Baikov check agreeing), polylog and nested
  root. A sector whose order-4 block is a nested root under an elliptic piece comes out `elliptic` through the
  search for pieces of order 2.
- It can say `elliptic` where a leading-singularity analysis of the scalar integral finds no curve. In those sectors
  the numerical monodromy of the block was irreducible: two log points have different fixed lines. In one of them
  the curve lies on the zero set of a loop-by-loop Baikov polynomial whose exponent is O(ε). An analysis of the
  integrand at ε = 0 drops that polynomial; there the curve is the double cover of that zero set branched where the
  other polynomial vanishes. The poles of its j-invariant are exactly the log points of the block.
- On the examples:
  - `sunrise-equal-mass` gives `elliptic`; the Baikov degenerations are the four log points, ∞ included.
  - `banana-three-loop` gives `K3`.
  - `box-one-loop`, `doublebox-massless` and `bubble-massive` give `polylog` in every sector. `not applicable`
    depends on the family, not the sector, and each of these families has two invariants.

## Cost

The line costs about what the eps-only slice of the FiniteFlow check costs: IBPs on the cut once, then a
reconstruction in one variable. The Kira check is one small Kira run at one point. The analysis forms operators
only of the blocks' own orders. It takes seconds for blocks of order 2 or 3, apart from the module test for a
symmetric square, which has a 60 s limit. A block of order 4 whose singular factors have high degree takes about a
minute. The search for pieces of order 2 adds 10–40 s to a block of order 4 (the operator of its exterior square has
order 6), within its own limit of 120 s; for order 5 it searches two systems of order 10.

These times were measured on 2026-10-14 and 15 (`timing` in the record). They start with the step, with the recount and
the representations already done, as in the first pass. They vary by a factor of 2 to 4 with the load on the machine,
because FiniteFlow uses every thread.

| sector | masters | line | Kira check | analysis | in all |
|---|---|---|---|---|---|
| box, double box, bubble (examples) | 1–2 | | | | 5–10 s |
| sunrise `j11100` | 2 | 14–26 s | 8 s | 1 s | 23–35 s |
| banana `j111100000` | 3 | 31–125 s | 6–12 s | 3–6 s | 45–145 s |
| a two-loop five-point sector (6 dimensionless invariants) | 7 | 126 s | 15 s | 40 s | 181 s |
| a two-loop four-point sector whose order-4 block splits as 2 + 2 | 7 | 11 s | 6 s | 56 s | 73 s |
| a non-planar two-loop four-point sector | 6 | 46 s | 7 s | 62 s | 116 s |
| a two-loop four-point sector with a genus-2 block | 7 | 11 s | 6 s | 22 s | 39 s |

The five-point sector is the largest of its family, and the default limit of 300 s holds there. For a larger family, time
one large sector with `bin/picard_fuchs.wls --dry-run` first, then set `"TimeLimits" -> <|"PicardFuchs" -> ...|>`
in `run.wl`.

## References

The references below were checked against INSPIRE, CrossRef and zbMATH on 2026-10-14.

- p-curvature: N. M. Katz, *Algebraic solutions of differential equations (p-curvature and the Hodge filtration)*,
  Invent. Math. 18 (1972) 1–118, doi:10.1007/BF01389714 (zero p-curvature and algebraic solutions for Gauss-Manin
  connections); N. M. Katz, *Nilpotent connections and the monodromy theorem: applications of a result of
  Turrittin*, Publ. Math. IHÉS 39 (1970) 175–232, doi:10.1007/BF02684688 (nilpotent p-curvature and regular
  singularities with rational exponents for operators of geometric origin).
- Operators of banana integrals and their geometry: P. Vanhove, *The physics and the mixed Hodge structure of
  Feynman integrals*, Proc. Symp. Pure Math. 88 (2014) 161–194, arXiv:1401.6438; K. Bönisch, C. Duhr,
  F. Fischbach, A. Klemm, C. Nega, *Feynman integrals in dimensional regularization and extensions of Calabi-Yau
  motives*, JHEP 09 (2022) 156, arXiv:2108.05310.
- The line DE: T. Peraro, *FiniteFlow: multivariate functional reconstruction using finite fields and dataflow
  graphs*, JHEP 07 (2019) 031, arXiv:1905.08019.
- Full factorisation, for an `unresolved` block: `reference/tools.md` (ore_algebra).
