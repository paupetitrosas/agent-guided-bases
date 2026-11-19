# Pitfalls

Things that go wrong, how you notice, and what to do about them.

## Masters

**Recount every sector on its maximal cut.** A Kira `masters` file only lists the masters one particular
reduction needed, so a sector can easily have one master more than the list says. You notice it when the
basis search is rank-deficient, when the gate complains that "the maximal cut has n masters", or when
`basis.m` shows `nMastersCut` larger than `nMastersList`. The automatic pass always recounts; do the same
(`MCBCutMasters`) whenever you work on a sector by hand.

**The count matters, Kira's choice does not.** Kira may pick `j[...,-2,0]` where the list had a dotted
integral. If `cutMasters` and the list contain different integrals but the same number of them, there is
nothing to fix.

## Defining the family

**Give every constant the mass dimension of its propagator.** If the constant of a linear propagator is
declared with dimension 0, the derivatives come out wrong. The "dimensions" check of `validate_family` fails,
and so does the scaling self-test.

**Write linear propagators as `Momentum·Vector - Constant`**, which is Kira's `bilinear` convention. With the
opposite sign the scaling self-test fails, with a residue proportional to the constant.

**Keep the family's symbols apart from the names your scripts use.** A script that loops with
`Do[..., {s, sectors}]` gives an invariant called `s` a list as its value for the whole loop, and every
computation inside quietly breaks: no representation is found, or the results make no sense, for a family
that validated fine. The `bin/` scripts keep their variables inside `Module`, and the validation rejects the
variable names of `AnalysisMasters.m` (`$MCBReserved`). Use `Module` in your own code as well. The family's name
is such a symbol too: `sunrise = run[...]` in a script turns every `j[sunrise, ...]` that follows into
`j[<that value>, ...]`, and FiniteFlow then fails with "seeds too small".

**Invariant names with capital letters are renamed in the Kira files.** Kira hands the invariants to Fermat,
which rejects capital letters and aborts the run ("Fermat does not like capital letters in variable names").
The toolkit therefore writes such names as `mcbinv<n>` in every Kira file and maps them back when it reads the
results, so `S12` is fine in `family.wl`. Kira files you write yourself need lowercase names.

## Representations and cut integrands

**Light-like vectors make loop-by-loop steps degenerate.** A loop that only sees a vector `n` with `n² = 0`
has a vanishing Gram determinant, so one of the Baikov polynomials is zero on the cut. `MCBRepresentations`
throws such representations away.

**Add up the exponents of each factor before splitting the twist,** and only then split half-integer
exponents as `f^(e+1/2)/Sqrt[f]`. Otherwise you get a spurious square root, a wrong `kinNorm`, and candidates
whose DE has ε⁰ terms.

**Compute dots through derivatives of the logarithm.** Applying `PowerExpand` to the whole Baikov product
produces sign and `I` mismatches between integrals with and without dots.

**Numerators only work on ISPs the representation keeps.** `MCBCutIntegrand` returns `$Failed` otherwise; use
a representation that contains that ISP (`"Extra" -> 1`).

## Leading singularities and the search

**Pick the variable order that leaves the largest dlog space,** not the first order that works.

**Take partial fractions integrand by integrand** and collect the poles afterwards. Running `Together` or
`Series` on the combined ansatz is far too slow; the symptom is the LS step hitting its time limit.

**A root of degree higher than 2 in the current variable turns into conditions,** because that piece must
vanish. Many conditions and few or no candidates suggest trying another order or representation.

**Screen numerically, solve exactly.** Exact solves over every subset of a pool never finish.

**The numeric screening needs many digits.** For three or more masters the search scores each subset from
the DE at eight rational values of ε and fits a Laurent polynomial. The entries are ratios of large integers
and the masters can be nearly dependent at the sample points, so inverting the matrices costs many digits.
At 40 digits, spurious powers of ε survived the fit and ε-form subsets were scored as polynomial or rational.
The screening now works at 120 digits (`` MaximalCutBasis`DECheck`Private`$MCBScreenPrecision ``, a private
constant), and the best few subsets are always decided
exactly before the search settles for an ε-polynomial basis. A `basis.m` written before this change can say
`eps-polynomial` for a basis that is in fact in ε-form; `bin/check_basis.wls <sector folder>` re-checks
`masters.m` and corrects the status.

**With four or more invariants, start with small pools.** The leading-singularity step works on the whole
pool with symbolic kinematics, and its cost grows quickly with the pool. In a sector with five invariants, a
pool of 28 integrals timed out after 300 s, while 12 integrals (`nd = 1`, `nt = 1`, `w = 2`,
`maxpool -> {12, 10, 8, 6}`) gave ε-form in about ten seconds. Small pools solve almost every sector with one
master; for several masters they may come out rank-deficient, and that is the time to add integrals.

**Put time limits on large sectors** (`"TimeLimits"` in `run.wl`): `"LS"` for each candidate search and
`"Sector"` for all the searches of one sector. Without the budget, a hard sector can spend most of an hour on
timeouts that produce no candidate at all.

## Families with many invariants

**The derivatives are built at the check points.** The gate only needs the derivatives of the candidates at
its two kinematic points, so `MCBReduceCandidates` and the scaling self-test solve the vector field and
differentiate the propagators at each point (`MCBDerivExprAt`). Building them symbolically first, from the
inverse Gram matrix of the external momenta, took minutes with four external momenta and seven invariants: in
one such family the same reduction took 186 s symbolically and 13 s point-wise, with identical matrices. Set
`$MCBPointDerivatives = False` to go back to the symbolic derivatives; FiniteFlow always uses them.

**Large coefficients: write the element as prefactor × pieces.** An element such as
`eps^4 p (s^2 t j[..] + s^2 j[..])`, with a large rational prefactor `p` (a normalisation, a rotation by another
basis), is checked as it is written. `MCBSplitMaster` takes the square root out without expanding anything,
`MCBDerivExprAt` differentiates `p` once and evaluates it at the point before combining it with the pieces, and the
rules, weights and letters of a coefficient above `$MCBLargeLeafCount` (2000 leaves, `MCBLargeQ`) are read from its
values at random rational points. Definitions are compared at random points too (`MCBEqualAtPointsQ`). On the
double box with a prefactor of 11 000 leaves, the gate took 22 s instead of 20 s for the plain basis; before, its
first step (an `Expand` and a `Together` of every coefficient) had not finished after 600 s. The page still prints
the definition in full, and the DlogBasis cross-check, which is symbolic, is skipped for such elements.

**Expect the representations to dominate.** The Baikov representations are symbolic in every invariant, and
with seven invariants one sector took several minutes. Nothing caches them: the first pass builds them once for
its searches and the Picard-Fuchs step, and `check_basis.wls`, `picard_fuchs.wls` and `AnalysisMasters.m` build
them again. Keep to one sector at a time all the same (`SKILL.md`); the next two paragraphs make them cheaper.

**Analyse lower-point sectors in a smaller family.** A sector whose lines pinch some vertices together only
sees the momenta that enter its merged vertices. Build a family for it with those momenta as the external
ones, new names for their off-shell squares and products, and as many ISPs as the basis needs. Keep the
original loop momenta, shifted by external momenta, so that every integral of the small family is literally an
integral of the big one; each propagator of the small family is then a linear combination of the big family's
propagators, and a basis maps back by expanding the numerators. In such a family the same sector needed about
one minute for validation, the scaling self-test and the representations, instead of more than a quarter of an
hour. Check the map once at the level of integrals: send one mapped basis through the gate in the big family.

**Scan the geometry at a numeric point.** The geometry class, the degrees in the cut variables and the genus
of a curve are the same at a generic point as for symbolic kinematics. For a quick survey of many sectors,
copy `family.wl` with every invariant except the unit scale replaced by a random rational number, and look at
`MCBRepresentations` there: in one test this took 2 s per sector instead of 268 s, with the same result. Do
not build bases from such a family; leading singularities need symbolic kinematics.

## Kira

**Replace `d` in Kira's output as text** with `(D0 - 2*MaximalCutBasis`eps)` before parsing it, using full
symbol names (there is also a `BaikovPackage`d`). If you see a bare `d` in a DE entry, this step was skipped.

**"unreduced integrals: n" with n > 0** means the seeds were too small for the targets. The job uses one more
than the largest `r` and `s` among the targets; raise them by hand for stubborn sectors.

**The kinematic points are random rationals** that avoid zeros of the Gram determinant and of the invariants.
An unlucky coincidence is still possible: if one point disagrees with the other, change `"Seed"` in `run.wl`.

## The DE check

**The ratios `Sqrt[r2_i/r2_j]` are left out.** That does not affect the ε-structure, but the matrices printed
are those of the rational frame. `finiteflow/DE.m` has the actual matrices.

**ε-form with a nonzero `k`** means "multiply `J_i` by `eps^(k_i)`". The gate says so, and `check_basis.wls`
writes the rescaled basis to `masters.m`.

**Only the diagonal block is tested.** Getting the off-diagonal blocks into ε-form may require adding
subsector integrals to a master; that is the step after this skill.

## The Picard-Fuchs step

**`unresolved` with "not of geometric origin" points at the DE, not at the geometry.** An irregular point, an
irrational exponent or a p-curvature that is not nilpotent does not happen for a Picard-Fuchs operator of a
Feynman integral. Look at `kiraCheck` first: `agree` means the line DE is right and the block is genuinely odd;
otherwise the reductions or the derivatives are wrong.

**A prime can be bad for the p-curvature by accident.** On a line through random points the coefficients are
large, and singular points can coincide modulo a small prime; there the p-curvature of an elliptic operator can
vanish. The step uses primes from 29 up that divide neither the leading term nor the discriminant of the leading
coefficient, and asks every one of them for "zero" before it says `polylog (nested root)`.

**The step runs FiniteFlow, LiteRed and LiteIBP inside the toolkit's kernel.** `MCBFFLineDE` runs the pipeline's
scripts in a context of their own, with `MCB_FF_INKERNEL=1` (they end by a Throw, not Quit) and
`MCB_FF_MODE=line`, and restores the environment afterwards, even after a time limit. A script of the FiniteFlow
check started by hand with `MCB_FF_INKERNEL=1` set in the shell would not stop on a failure: leave it unset.

**Kira's default seeds can overcount the masters of a three-loop family.** On the three-loop banana,
`find_masters.wls --kira` with r = t + 1, s = 1 finds 8 masters, most of them spurious; r = 6, s = 2 gives the
right 4. The recount on the cut (`MCBCutMasters`), which the step uses, gives 3 for the top sector.

## The FiniteFlow check

**FiniteFlow only works with rational numbers.** If a basis element carries a factor `I`, the pipeline moves it
into the square root (`K → K/I`, `R → -R`). An element that mixes real and imaginary coefficients cannot be
handled, and `bin/write_ff.wls` says so.

**LiteIBP can only differentiate invariants that appear in external scalar products.** An internal mass that is
one of them (the same symbol as an external mass) is fine, because it enters the propagators through that scalar
product. Other internal masses and the constants of linear propagators would come out wrong. `SetSDE.m` therefore
uses `LIBPDeriv` for the invariants of `MCBInvariantsAsSP` (`"liteIBPInvariants"` in `ffinfo.m`). It reads the
others from `derivatives.m`, computed integral by integral by `MCBDerivJ` (`"Precomputed"`).

**No square root and no `Together` in the DE.** With J_i = √R_i K_i, the d log term is R_i′/(2R_i), which is
rational. The basis never enters the IBP system: LiteIBP writes every coefficient of the system as a ratio of
expanded polynomials, which takes `Together` on each, and that does not finish for large ones. `elements.m` keeps
each element as it is written (prefactor × pieces), `SetSDE.m` evaluates its coefficients and their derivatives as
they stand with `FFAlgRatExprEval`, and two sparse products (`FFAlgSparseMatMul`) combine them with the reductions
of its integrals. A dense solver in the graph (`FFAlgNodeDenseSolver`) then inverts the basis on the masters of the
cut. Simplifying the coefficients first (`Together`, `Simplify`, or expressions with `Sqrt`) only costs time;
FiniteFlow reconstructs the result.

**`j` is an algebra of integrands in LiteRed.** `j[f, a] j[f, b]` is `j[f, a + b]`, so `j[f, a]/j[f, a]` is
`j[f, 0, ..., 0]`, not 1. `LIBPDeriv` relies on it: it returns products (dD_k/dX) j[a + e_k], where dD_k/dX holds
`j`'s with non-positive indices (numerators, such as `j[f, 0, 0, 0, -1, 0]`). These merge into integrals only when
the product is expanded. Two traps follow:
- **Expand before eliminating zero sectors.** `LIBPEliminateZeroSectors` on the unexpanded product takes those
  numerator `j`'s for scaleless integrals and sets them to 0. Terms vanish without a message and the DE is wrong.
  Apply `Collect[..., _j]` first, as `SetSDE.m` does.
- **Read a coefficient by replacing its integral by 1, never by dividing.** A coefficient that still contains
  `j[f, 0, ..., 0]` is refused by FiniteFlow (`FF::nonratsub`).

**An old FiniteFlow library hangs `FFAlgRatExprEval`.** The evaluator of rational expressions changed in September 2025
(FiniteFlow commit 98641f0), and a library built before then loops on what the current package sends it. The loop is
inside the library, where no time limit stops it: kill the kernel by PID. The version number does not tell: a library
built before December 2024 has no `$FFVersion` (loading it prints `Set::shape`), one built from December 2024 to
September 2025 reports 2.0 like a current one. What tells is the rational-expression parser that came with the change:
its library function `FiniteFlow`Private`FFAlgRatExprEvalParseImplem` is a `LibraryFunction` only with a current
library. A copy in the user's `SystemFiles/LibraryResources` shadows the configured library for any code that appends
to `$LibraryPath`; the pipeline and the toolkit prepend the configured one. `SetSDE.m` checks the version and the parser
and falls back to `Together` and `FFAlgRatFunEval` (slower, same result), and the preflight reports both.

**LiteIBP needs one momentum-conservation rule.** The pipeline adds an auxiliary momentum that balances the
independent ones.

**"the basis is not a basis of the maximal cut"** means that the basis, its derivatives and the corner integral
reduce onto more or fewer masters than the basis has elements, and **"the basis elements are linearly dependent
on the maximal cut"** that the matrix of the basis on those masters is singular. Either way the basis is linearly
dependent or too small on the cut.

**"seeds too small"**: write the pipeline again with larger seeds,
`bin/write_ff.wls j<pattern> --rank r --maxdots d`, then run `bin/finiteflow_sector.sh j<pattern>` again
(without `FORCE`).

**When FiniteFlow and Kira disagree,** look at `kiraComparison` in `verdict.m` first: it compares the matrices
entry by entry and names the first entry that differs. Remember that FiniteFlow sets the unit scale to 1 and so
does not test the derivative with respect to it (Kira does), and that an `eps-slice` verdict only looks at one
point. Check the seeds, then the phases, then the mode, before doubting either result. If the differing entries
are off-diagonal, belong to an element normalised by a square root and differ by a rational factor, re-check the
basis with `bin/check_basis.wls <sector folder>` first: it recomputes Kira's matrices from `masters.m`, and a
`basis.m` written by an older version of the automatic pass could hold them in a different split of the root.

**A FiniteFlow verdict can belong to an older basis.** When `masters.m` changes (a new basis adopted by
`check_basis.wls`, or a rerun of `AnalysisMasters.m`), the pages show the old verdict as `stale`, and
`finiteflow_sector.sh` writes the pipeline again before running it.

## Powers of ε

**The common power of ε of a sector is not fixed by the maximal cut.** The DE check only fixes the powers of
the elements relative to each other (`k`); multiplying the whole sector by `eps^m` changes nothing on the cut.
The page shows both the written power and the relative one, and says that the common power is undetermined.
It is fixed later, when the sectors are put together (for instance by requiring a pure function of uniform
weight, or from the known ε expansion of a simple integral).

## Third-party packages

**Load third-party packages in isolation** (`MCBLoadTool` restores `$ContextPath` afterwards), call their
functions by full name, and set their inputs with `MCBSetSymbol[ctx, name, value]`. Writing
`MCBQualify[ctx, name] = value` does not set the symbol; it defines a rule for `MCBQualify`. DlogBasis
creates `Global`` symbols such as `External`.

## Wolfram Engine and the shell

**Mind the licence's kernel limit.** Start every script through `bin/ws`, which waits for a free slot: another
session may be holding them, and the error then reads "not activated or is experiencing a license-related
problem". `MCBKernelBudget[]` shows the limit and how many kernels are running now. A killed kernel keeps its
slot for a few minutes, and a polling loop that calls `wolframscript -code` takes a slot every time it runs. A
script that starts other kernels while it is still running (FiniteFlow's steps, for example) can wait forever
for a slot it is itself holding: run those one after the other, as `finiteflow_sector.sh` does.

**`wolframscript -file` reads stdin,** so always add `< /dev/null`; inside a `while read` loop it would
otherwise swallow the loop's input.

**Stop a job through `bin/ws`, never by name.** A `pkill -f <pattern>` whose pattern also matches your own shell
command kills the shell too, and a signal to `wolframscript` leaves its kernel running (it keeps a licence slot,
and it takes a `kill -9` on the kernel's PID). `bin/ws --list` shows the jobs started through `ws` (every session's)
with the PID of their `ws`, and `bin/ws --stop PID` stops one with its kernels; a TERM or INT to that `ws`, or to
`finiteflow_sector.sh`, does the same. Stop only your own jobs.

**`wolframscript` prints `InputForm[...]`, `MatrixForm[...]` and `Grid[...]` literally.** Print with
`ToString[expr, InputForm]` instead.

**`Check` also catches harmless warnings,** for example LiteRed's "Use NewDsBasis instead of NewDsBasis".
Judge success by the result.

**`Context` holds its argument,** so use `Context @@ {sym}` for a symbol you computed. And in Mathematica 13,
`ValueQ[f[x]]` returns False for down-values; test the value itself.
