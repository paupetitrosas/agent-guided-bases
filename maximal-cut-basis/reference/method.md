# Method

This is what the toolkit computes and why, written in the conventions of the code. An integral is
`j[fam, a1, ..., aN] = ∫ Π_i D_i^(-a_i)`, following Kira: a positive index is a power of a propagator, a
negative one a power in the numerator. The dimension is `d = D0 - 2 eps`.

## 1. The Baikov representation and the maximal cut

With `L` loops and `E` independent external momenta there are `L(L+1)/2 + L E` scalar products that
involve loop momenta. A family is exactly that many propagators and irreducible scalar products (ISPs),
chosen so that they are linearly independent. The "complete-basis" check of `validate_family` tests this.

The standard Baikov representation trades the loop momenta for the variables `z_i = D_i`:

    j ∝ ∫ Π dz_i  z_i^(-a_i)  B(z)^((d - L - E - 1)/2)

where `B` is the Gram determinant of the loop and external momenta written in terms of the `z`. The
loop-by-loop version integrates one loop at a time, each with the Gram determinant of the momenta that
loop actually sees. It needs fewer ISPs and usually gives fewer variables and lower-degree polynomials
(BaikovPackage, arXiv:2412.01804). Either way the result is a list of polynomials `G_k(z)` with exponents
`γ_k(d)`, times a prefactor made of Γ functions. The product `u(z) = Π_k G_k^(γ_k)` is called the twist.

To take the maximal cut of a sector `s`, whose propagators are `P = {i : s_i = 1}`, you replace the
integrals over `z_i`, `i ∈ P`, by residues at `z_i = 0`. What remains is an integral over the ISPs that the
representation keeps; the code calls them the cut variables (`cd["vars"]`). Every subsector integral
vanishes on this cut, so only the diagonal block of the differential equation survives, and that block is
what the skill tries to bring to ε-form.

A note on numbering: `z[i]` always means the propagator `D_i` of the family, whatever name BaikovPackage
gave the variable internally.

Some loop-by-loop representations are degenerate. If one loop only sees a light-like vector, its Gram
determinant is zero. `MCBRepresentations` throws away representations with a polynomial that vanishes
identically or on the cut. It adds the standard representation when no loop-by-loop one is left, when none of
them is dlog-compatible (a non-dlog verdict needs every representation), or when the standard one has at most
`$MCBMaxStandardVars` (3) cut variables; every ISP of the sector is one of them, so in a
low sector of a large family it would have eight or nine, take minutes to build and leave the leading-singularity
search nothing but timeouts. `<|"Standard" -> True|>` builds it anyway (`"Standard" -> True` in `run.wl`
`"AutoPass"` does the same for the first pass). The loop orders are searched together, by number of ISPs: an
order that needs more than one ISP above the best order is not used, since its representations would have more
variables than the others.

## 2. Cut integrands, dots and numerators

On the cut, `j[fam, a]` becomes the residue `Res_{z_P = 0} Π z^(-a) u(z)`. A dot (`a_i ≥ 2`) turns into
the derivative `∂^(a_i - 1) u/(a_i - 1)!`, and a numerator on an ISP the representation keeps becomes the
monomial `z_j^(-a_j)`. A numerator on an ISP that the representation does not keep cannot be written at
all; ask for a representation that contains it (`MCBRepresentations[..., <|"Extra" -> 1|>]`).

`MCBCutIntegrand[cd, j]` returns `R(z, eps)`, the cut integrand divided by the twist on the cut. It is a
polynomial in ε. Dots are computed through derivatives of the logarithm: `∂^α u/u` is written as a
polynomial in `Ld[β] = ∂^β log u`, and each `Ld` is evaluated on the cut once and cached. That is much
faster than differentiating the whole product, and it avoids the phase problems of `PowerExpand`.
`MCBLeadingEps` splits `R = eps^k (R0 + O(eps))`. The ε = 0 integrand that the leading-singularity
analysis works with is `R0` times the twist at ε = 0.

## 3. Splitting the twist, and the Γ prefactor

At ε = 0 the twist on the cut is written as `kinNorm · Rz(z) / Sqrt[Pr(z)]` (`MCBSplitTwist`). To get
there, the exponents of each polynomial factor are added up first (the same factor can appear in several
`G_k`), and only then is a half-integer exponent `e` split as `f^(e + 1/2)/Sqrt[f]`. `kinNorm` collects
everything that does not depend on `z` (Gram determinants of the external momenta, numbers, phases), `Pr`
is the product of the `z`-dependent factors left under the square root, and `Rz` is the rational rest.

`MCBPrefRat` gives the rational ε dependence of the Γ prefactor, measured against `Γ(1 - eps)` and
`Γ(1/2 - eps)`; for example `4/(1 - 2eps)^2`. It matters when you ask whether an integrand is ε-pure
(`SKILL.md`, "Purity"), but it plays no role in the DE check.

## 4. The geometry of a cut

`MCBGeometry[cd]` sorts every cut into one of six classes (stored in `cd["geometry"]`):

| class | meaning | what to do |
|---|---|---|
| `point` | no cut variable is left | dlog: the corner integral divided by its leading singularity |
| `rational` | `Pr = 1` | dlog |
| `sqrt-quadratic` | `Pr` has degree at most 2 in every variable | dlog, with Euler substitutions |
| `sqrt-mixed` | degree at most 2 in some variables only | dlog, integrating a low-degree variable first |
| `curve` | one variable and `deg Pr = n ≥ 3`, so `y² = Pr` has genus `⌈n/2⌉ - 1`; or such a curve on a boundary (below) | curve candidates; the target is an ε-polynomial DE |
| `non-polylog` | degree higher than 2 in every variable | single integrals; the target is an ε-polynomial DE |

The class belongs to the representation, not always to the sector: a root that looks quartic in one
representation can be quadratic in another. Before you call a sector non-dlog, look at the class of every
representation and at `MCBFibrationTable[cd]`, which shows what is left after integrating each variable first.
The Picard-Fuchs label (`classification` in `basis.m`, `reference/picard-fuchs.md`) belongs to the sector: it reads
the operator of the masters themselves, so a curve in some representation that no master sees leaves it `polylog`.
When it has a label, it decides.

The number of masters on the cut equals the number of critical points of the twist there (the Euler
characteristic of the complement of its zeros). Kira recounts them on the maximal cut (`MCBCutMasters`),
because a Kira `masters` file only lists the masters that one particular reduction happened to need.
`MCBMasterCount[cd]` counts the critical points of one representation, which says where the masters live
(next subsection).

### Boundaries: factors that the ε = 0 twist does not see

The ε = 0 twist `kinNorm · Rz / Sqrt[Pr]` drops every factor whose exponent vanishes at ε = 0, and it treats a
factor with an integer exponent as an ordinary pole or zero. Both are still boundaries of the twisted
cycle. The typical case is the Baikov polynomial of a one-loop subloop with E = d0 − 2 external momenta
(a triangle in four dimensions): its exponent is (d − E − 2)/2 = −ε. `MCBTwistFactors[cd]` lists the factors
with their exponents and kinds: `branch` (half-integer at ε = 0, part of the square root), `integer`
(regulated pole or zero) and `eps-only`.

Masters can live on these boundaries. `MCBMasterCount[cd]` gives the count with and without the eps-only
factors; when the first is larger, the difference sits on their zero sets, and a basis of integrals
without poles there (ISP numerators) cannot carry the right weight. Their integrands must have a simple
pole on the boundary: dots on the propagators of the subloop whose Baikov polynomial it is give
`R = ε × (rational with a simple pole)`, and the form they induce on the boundary is
`MCBBoundaryForm[cd, R, f]`.

The square root restricted to a boundary can be a curve even when the bulk is rational or quadratic. A
sector whose two-variable cut has a root quadratic in both variables can have an elliptic curve on the zero
set of an eps-only factor, where the masters that live there have first-kind forms. `MCBBoundaries[cd]`
restricts the root to the zero set of each non-branch factor (solved for a variable in which the factor is
linear) and classifies it; `MCBGeometry` reports the class `curve` when a boundary is a curve of genus ≥ 1,
with `"bulk"` keeping the class of the ε = 0 root and `"boundaries"` the details (punctures included, and
whether the root is rational there).

`MCBLoopByLoopReport[fam, sector, opts]` prints all of this for every loop order: the role of each Baikov
polynomial (subloop or external Gram, and its E, read off the exponent), the twist factors, the behaviour at
infinity in each variable (a numerator `v^n` costs the IBP factor `n + 1 + E_v` when `u ~ v^E_v`: the source
of factors such as (1 − 3ε) in a basis of ISP powers), discriminants that are perfect squares, the master
counts, the bulk and boundary geometry, and, for integrals you pass, their cut integrands and boundary forms.
Read it before choosing candidates for any sector that resists.

Two cautions on the counts. A factor can carry an integer exponent with no ε part at all, when an external
Gram determinant and a subloop Baikov polynomial share it and their ε parts cancel (a light-like or on-shell
leg at a degenerate configuration). Such a factor is `unregulated`: the generic count treats it as regulated
and is then only a lower bound (the masters on its zero set are missing), and integrands with a pole there are
not regulated by ε. The report marks it and also reads the representations with one more ISP of that loop
order (`"AutoExtra"`), where the two polynomials usually separate and the count matches the reduction. A
representation with more ISPs than it needs, on the other hand, can see more critical points than the sector
has masters. Compare every count with the reduction's (`"KiraMasters"`); trust a count that matches it.

### Sectors with the same geometry

Two sectors can be the same integrals at different kinematics: a sunrise at s12 and the same sunrise at s35. Kira
keeps both, since they are different integrals. `MCBSymanzik` gives the Symanzik polynomials of a sector's lines:
with Σ x_i D_i = kᵀ M k + 2 Q·k + J, U = det M and F = Qᵀ adj(M) Q − U J. `MCBSectorMap[fam, from, to]` looks
for a permutation of the lines that keeps their masses and makes the U equal, and for a linear change of the
invariants (masses fixed) that then makes the F equal. The integrals of `to` are then those of `from` at the mapped
invariants, and `MCBMapBasis` carries a basis of dotted integrals over: the indices move along the lines, and the
coefficients and square roots are taken at the mapped invariants. Numerators on ISPs do not move with the lines, so
such a basis is left to you. `MCBGeometryGroups` groups the sectors of a run (`find_masters.wls` writes
`geometry.m`), and `MCBRepeatedGeometry` finds, for the sector at hand, the sectors of the run folder that have a
basis already; the automatic pass searches their mapped basis first.

## 5. dlog forms and leading singularities

A dlog integrand has only simple poles in each variable, taken one at a time, and its iterated residues,
the leading singularities, are algebraic functions of the kinematics. Dividing an integral by its leading
singularity (and by the right power of ε) gives a pure, uniform-transcendental function, and a basis of
such integrals has an ε-factorised differential equation `dJ = eps dA J`.

The leading-singularity engine, `MCBIteratedLS`, starts from an ansatz `Σ c_i (integrand of pool integral i)`,
linear in the coefficients `MCBc[i]`, and integrates one variable at a time:

- when the square root is quadratic in the variable `v`, it uses the Euler substitution
  `Sqrt[P] = Sqrt[a](v + t)`; when it is linear, `v = (t² - c)/b`. Both remove the root, and whatever root
  is left moves on to the next variable;
- it takes partial fractions in `t` for each integrand separately and then collects them by pole.
  Polynomial parts (poles at infinity beyond a simple one) and double poles give linear conditions on the `c_i`;
- simple poles give residues. At a quadratic factor the residue is `α ± β/Sqrt[Δ]`, so it produces two
  terms, the second with a new square root;
- a root of degree higher than 2 in the current variable cannot be removed. That piece would integrate to
  something non-polylogarithmic, so it has to vanish, which adds more conditions.

What comes out is a list of terms `F(c)/Sqrt[K(kinematics)]`, the leading singularities, together with
the conditions. `MCBBestIteratedLS` tries every variable order (for up to three variables) and keeps the
one that leaves the largest space of dlog integrands, that is, the size of the ansatz minus the rank of
the conditions. A candidate is a combination whose leading singularities are constant for one square root
`K` and zero for all others. `MCBScreenSubset` looks for them numerically at a few kinematic points and
`MCBSolveSubset` then solves exactly. The candidate is `J = Sqrt[K]/kinNorm · Σ c_i eps^(-k_i) j_i`,
stored with `r2 = K/kinNorm²`.

Square roots are compared up to numbers and signs (`MCBSqrtClass`), so `Sqrt[-4 s]` and `Sqrt[s]` count as one.

If a candidate's full integrand, `PrefRat · Σ c_i eps^(-k_i) R_i(z, eps)`, does not depend on ε at any
order, it is marked `strict`. Such integrals are more likely to be UT away from the cut as well, which is
what the skill asks of every element (`SKILL.md`, "Purity"). Before the search every candidate gets the verdict of
`MCBElementPurity` (`MCBCandidatePurity`), so that a single integral or a curve target that happens to be ε-pure
counts as one, and the search (`MCBOrderKey`) puts the ε-pure candidates before every other one. The d-dimensional
candidates below are also marked `strict`, but for them it means that `Rz Σ c_i(ε) R_i` is free of ε, without the
prefactor: such a candidate is ε-pure "as built" only when `PrefRat` of its representation is a power of ε times a
number, and under a prefactor such as `2/(1 - 2eps)` it is not ε-pure.

### Dlog in d dimensions: coefficients that depend on ε

The leading singularities are computed at ε = 0, and a candidate gives each pool integral one power of ε,
`eps^(-k_i)`. That is not always enough. A massless bubble inserted in a line, for example, brings a factor
`1/(1 - 2 eps)` between a dotted integral and one with a numerator, and no choice of powers of ε removes it;
the DE of such candidates then stays `A₀ + ε A₁`.

The cure is to ask for more than dlog at ε = 0. On the cut, `j = ∫ R_j(z, ε) u(z, ε) dz` with the twist `u`.
If a combination `Σ c_i(ε) j_i`, with coefficients rational in ε and the kinematics, satisfies
`Rz Σ c_i(ε) R_i(z, ε) = W(z)` identically in `z` and ε, and `W dz/Sqrt[Pr]` is a dlog form, then its
integrand is that dlog form times ε-powers of the twist: it is dlog in d dimensions. Two functions build such
candidates, and both are linear algebra (subsets of the pool screened at random rational points, then solved
exactly):

- `MCBStrictTargetCandidates` matches pool integrals to the dlog forms of a one-variable cut with a root of
  degree at most 2: `dz/y` (normalised at infinity), the third-kind forms at the linear punctures and, on a
  rational cut, `d log g` and `Sqrt[disc] dz/g` at a quadratic factor `g`;
- `MCBPurifyCandidates` takes candidates that are dlog at ε = 0, in any number of cut variables, and adds
  ε-dependent multiples of pool integrals until the cut integrand no longer depends on ε.

Exact matching asks too much. Two integrands give the same integral when they differ by a total derivative,
`Σ_i (∂_i ξ_i + ξ_i ω_i)` with `ω_i = ∂_i log ut` and `ut = u/(kinNorm Rz)`, for any rational `ξ_i`. Often no
pool integral, or combination of pool integrals, has the integrand `1/((z - p) y)` of a third-kind form, but some
combination equals it up to a total derivative. Two functions use this:

- `MCBProjectedCandidates` (one-variable cut with a root of degree at most 2) takes the same targets as
  `MCBStrictTargetCandidates`. It picks as many independent targets as there are masters, and as many
  independent pool integrands, the smallest first. It then writes each of those integrands in the targets
  modulo total derivatives. Inverting that matrix gives every target as a combination of pool integrals.
  The total derivatives are `ξ = N(z) pref`, where `N` is a polynomial and `pref` cancels the poles the
  derivative would otherwise create. The linear system comes from the coefficients in `z`.
- `MCBProjectedPurifyCandidates` does the same in any number of variables, with the ε = 0 integrands of the
  dlog candidates as targets. Here the system comes from random sample points `z`. Independence is screened
  modulo a prime, and the degree of `N` goes up while the dimension the integrands span keeps falling. In
  several variables `ξ_i` must not be forced to vanish on the twist factors. Only `Σ_i ξ_i ∂_i G` has to
  (a syzygy), and the sampled equations impose that. The dimension can stay above the number of masters,
  because symmetry relations of the sector are not total derivatives. The function then works with a basis
  of the dimension found: identities modulo total derivatives are exact all the same. The exact step grows
  fast with the number of columns, n times the number of monomials of degree K. With five invariants, 105
  columns took 100 s to set up, and FiniteFlow then needed more than 4 GB. So above `"maxcols"` (60) the
  function gives up, which in practice limits it to two variables and small three-variable cuts.

Both reconstruct the coefficients with FiniteFlow, which only rebuilds the unknowns that are needed. An exact
`LinearSolve` with five invariants and ε can take minutes where FiniteFlow takes a fraction of a second. The
one-variable function falls back to `LinearSolve` without FiniteFlow; the other one then returns nothing.

On one-variable cuts the projection reaches ε-form much more often than exact matching. It fails when the
targets do not span the cut. A quadratic factor `g = α z² + β z + γ` of the twist that does not divide `Pr`
needs care. Its dlog forms `Sqrt[Pr(r)] dz/((z - r) y)`, at the roots `r` of `g`, have `Pr(r) = A ± B Sqrt[D]`
with `D` the discriminant of `g`: a nested square root. It denests when `N² = A² - B² D = Pr(r₁) Pr(r₂)` is a
perfect square. Then the sum and the difference of the two forms are

    [2α (A ± N) z + β (A ± N) + B D]/g · dz/y,   normalised by 1/Sqrt[2 (A ± N)],

rational forms with a single square root, and `MCBProjectedCandidates` adds them to the targets. `A` and `B D`
come from the remainder of `Pr` modulo `g`. In the families tried so far, Feynman integrals denested every
time. When `N²` is not a square, the sector keeps an ε-polynomial basis.

The automatic pass uses all four when its first attempt does not reach ε-form, or reaches it with an element that is
not ε-pure.

## 6. When dlog is impossible: the ε-polynomial target

If the cut is a curve of genus one or higher, or a non-polylogarithmic fibration, no rational or algebraic
normalisation can make the DE ε-factorised; that takes periods, which this skill does not compute. The
goal is then a basis whose maximal-cut DE is a Laurent polynomial in ε with the smallest possible spread of
powers, typically `A0 + eps A1`, built from integrals that match the natural differentials of the geometry.
Rung 5 of the ladder (`reference/escalation.md`) chooses such a basis systematically, by the poles and residues of
the integrands (arXiv:2511.15381): its DE is expected to be F-compatible, a Laurent polynomial whose entries only
have powers of ε between the difference of the elements' denominator powers and 1.

### Curves: kinds of differentials and Hermite reduction

On a curve `y² = P(z)` with `deg P = n` and genus `g = ⌈n/2⌉ - 1`, every cut differential `W(z) dz/y` can be
reduced, up to exact forms, to a standard shape (`MCBCurveCoordinates`):

    W dz/y = Σ_{k=0}^{n-2} a_k z^k dz/y + Σ_punctures N_g(z)/(g(z) y) dz + d(...)

Poles at branch points (factors `f` that divide `P`) are removed with exact forms `d(h y/f^m)`. Poles of
order two or more at punctures (factors of the twist, or poles of `Rz`, that do not divide `P`) are lowered
with `d(h y/f^(m-1))`, where `h` is a polynomial ansatz solved before differentiating. The polynomial part
is brought down to degree `n - 2` with `d(z^m y)`.

The forms `z^k dz/y` are of the first kind (holomorphic) for `k ≤ g - 1` and of the second kind (poles at
infinity, no residue) for `g ≤ k ≤ 2g - 1`. When `n = 2g + 2` is even, `z^(2g) dz/y` has residues at the two
points at infinity, so it is of the third kind. A term `N/(g y)` at a puncture is of the third kind too; it
is normalised by its residue, `c y(p)` for a puncture `c z + d`, which brings a new square root (`MCBCurveTargets` lists
the forms at the linear punctures). For
`n = 2g + 1` the `2g` forms span the first cohomology of the curve; for `n = 2g + 2` there is one more.

`MCBCurveCandidates` builds pool combinations that match each of these targets, adds the single pool
integrals labelled by their reduced differential, and adds `∂_X J1` and `∂_X J1/eps` for the first-kind
candidate. The basis search then picks the set with the smallest spread of powers of ε, and among sets with the same
spread one with an undotted element: a basis whose every element is dotted is likely to carry a weight between
sectors (the all-dot flag).

### Non-polylogarithmic cuts in several variables

When the root has degree higher than 2 in every variable, integrate first the variable that leaves the
simplest root (`MCBFibrationTable` shows the options). Very often what remains is an elliptic curve fibred
over the other variables. The automatic pass only tries simple single integrals here; better bases
usually come from thinking about the fibre (rung 4 of the ladder).

## 7. How the maximal-cut DE check works

The candidates are `J_i = Sqrt[r2_i] K_i`, where each `K_i` is a rational combination of integrals.

1. **Derivatives.** A derivative with respect to an invariant `X` acts on the external momenta through a
   vector field `O_X = Σ c_ab p_a·∂/∂p_b`, chosen so that `O_X(p_c·p_d) = ∂(p_c·p_d)/∂X` for every pair of
   independent externals (`MCBVectorField`; the coefficients left free by Lorentz invariance are set to
   zero). The explicit dependence of masses and of the constants of linear propagators is added on top
   (`MCBdPropdX`).
2. **Reduction.** Kira reduces every `K_i` and every `∂_X K_i` on the maximal cut of the sector (with
   `cut_propagators`), at two random rational points, with ε kept symbolic. This gives `K = T·M` and
   `∂_X K = D·M` in terms of the masters `M` on the cut.
3. **The matrix.** `A_X = D T⁻¹ + diag(∂_X log Sqrt[r2])`, up to a conjugation by the ratios
   `Sqrt[r2_i/r2_j]`. Those ratios do not depend on ε, so they cannot change the ε-structure and are dropped.
4. **The verdict.** The DE is in ε-form if every entry of every `A_X` is a number times `eps^(m_ij)` with
   `m_ij + k_i - k_j = 1` for some integers `k` (found by a breadth-first search; a nonzero `k_i` means
   "multiply `J_i` by `eps^(k_i)`"). It is ε-polynomial if every entry is a Laurent polynomial in ε, and
   rational otherwise.

The scaling self-test checks the first two steps. The combination `Σ_X [X] X ∂_X j - (L d - Σ a_i [D_i]) j`,
with `[·]` the mass dimension, has to reduce to zero. It fails when a mass dimension is wrong, or when the
sign convention of a linear-propagator constant disagrees with Kira's.

`bin/finiteflow_sector.sh` repeats the check analytically. LiteRed and LiteIBP generate IBP,
Lorentz-invariance and symmetry identities for the sector with every subsector set to zero (LiteRed's
`AnalyzeSectors` with the `CutDs` option). The basis does not enter that system. FiniteFlow's sparse solver
reduces the integrals of the basis and their derivatives onto the masters `M` of the cut. Each element, with
its square root stripped off, is kept as it is written, `ut_i = Σ_a c_ia j_a`, and FiniteFlow evaluates the
coefficients `c_ia` and their derivatives numerically, as they stand. Two sparse products combine them with the
reductions: `ut = T M` and `∂_X ut = D_X M`. A linear solver in the graph inverts `T`, so the graph returns
`A_X = D_X T⁻¹`. The DE is reconstructed as a rational function of ε and all invariants, with the unit scale set
to 1. When that takes longer than the time limit, the script falls back to reconstructing only the ε
dependence at one numeric point.

## 8. The examples (`examples/`)

What each example should show (`examples/README.md` says which of these were actually run):

- **Massive bubble** (`bubble-massive`). The maximal cut of `j[bub,1,1]` is a point and `kinNorm` contains
  the Gram-type root `Sqrt[s(s - 4 m2)]`. The ε-form element should be a dotted bubble divided by it.
- **One-loop box** (`box-one-loop`). Every cut is a point; the box is normalised by `s t` and the two bubbles
  by `s` and `t`, with whatever power of ε the DE asks for.
- **Massless double box** (`doublebox-massless`). The loop-by-loop maximal cut of the top sector has one
  rational variable. The two dlog integrals are `s² t eps⁴ j[...,0,0]` and one with the numerator `(k1 + p4)²`.
- **Equal-mass sunrise** (`sunrise-equal-mass`). One variable and `y² = z (4 m2 - z) Q(z)` with `Q`
  quadratic: an elliptic curve. The best basis gives `A = A0 + eps A1`. The analysis in `d0 = 2`
  (`MCBDimensionShift`) is the natural place to see the first-kind form.
- **Three-loop equal-mass banana** (`banana-three-loop`), in `d = 2 - 2 eps`. Three masters on the maximal cut of
  the top sector, whose Picard-Fuchs operator at ε = 0 has order 3 and is a symmetric square: a K3 surface. The
  best basis gives `A = A0 + eps A1`.

## 9. A genus-2 example

Consider a two-loop sector with seven propagators whose maximal cut, in standard Baikov, leaves two ISPs
`x8` and `x9`. This is the kind of reasoning rung 4 asks for when the cut is hyperelliptic.

1. **The cut.** The Baikov polynomial on the cut, `B(x8, x9)`, is quadratic in `x9` and quartic in `x8`:
   `B = A2(x8) (x9² - c(x8) x9) + A0(x8)`.
2. **The first integration.** In `x9` the integrand `N/B` has two simple poles, `x9± = c/2 ± Y/(2 A2)`, with
   `Y² = P6(x8) = A1² - 4 A0 A2`. When this sextic has six distinct roots the curve has genus 2. The two
   residues combine into a part that is odd in `Y`, `(N(x9+) + N(x9-))/Y`, which lives on the curve, and a
   part that is even in `Y`, which is rational and has poles only at the zeros of `A2`.
3. **Counting.** The curve part is the first cohomology of the genus-2 curve with its two points at
   infinity removed: `2g + 1 = 5` forms, `{1, x8, x8², x8³, x8⁴} dx8/Y`. The rational part has one form per
   zero of `A2`, two in this case. Five plus two gives seven, the number of masters (the critical points of `B`).
4. **The basis.** Two dlog masters come from numerators `N = R(x8)(x9 - c/2)`, which cancel the curve part
   completely; their leading singularities are numbers. The curve block uses `x8^k dx8/Y` for `k = 0..4`:
   `k = 0, 1` are of the first kind, `k = 2, 3` of the second kind (they have double poles at infinity, which
   no choice can avoid; DlogBasis reports them as `DoublePole`), and `k = 4` is of the third kind at infinity.
   The leading coefficient of `P6` is the natural algebraic normalisation for the whole block.
5. **Checks.** The curve coordinates of every candidate (`MCBCurveCoordinates` with `n = 6`) form a
   matrix; if its determinant for the proposed basis does not depend on the kinematics, that is a quick
   sign the basis is sensible, before running the full DE check. Releasing one propagator (a
   next-to-maximal cut) often lowers the genus, from 2 to 1 here.
6. **The outcome.** A maximal-cut DE that is polynomial in ε. Making the curve block ε-factorised would need
   the periods of the genus-2 curve, which is the natural next step beyond this skill.

## 10. Further reading

Henn, arXiv:1304.1806 (canonical differential equations); Frellesvig and Papadopoulos, arXiv:1701.07356
(cuts in Baikov representation); Frellesvig, arXiv:2412.01804 (loop-by-loop Baikov); Henn, Mistlberger,
Smirnov and Wasser, arXiv:2002.09492 (dlog integrands); Lee, arXiv:1411.0911 (the algorithm behind Libra);
Görges, Nega, Tancredi and Wagner, arXiv:2305.14090 (ε-factorised equations beyond polylogarithms, using
periods). Check these references before quoting them in a paper.
