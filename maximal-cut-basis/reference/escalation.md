# The escalation ladder

This is what to do with a sector that has no ε-form basis yet, or whose ε-form basis has an element that is not
ε-pure (`epsPure` False in `basis.m`: the sector is flagged). Go through the rungs in order and try each one at most
once per sector in a session. Stop at the first ε-form basis none of whose elements is known not to be ε-pure
(`epsPure` is not False; check an element whose verdict is not known by hand), or at an ε-polynomial basis once you
have shown that the geometry is not dlog (a curve of genus one or more in one variable, or a
non-polylogarithmic fibration; see sections 4 and 6 of `reference/method.md`). When the sector has a Picard-Fuchs
label, the label decides instead: a non-polylog label shows it, and `polylog` or `polylog (nested root)` never
allows a final ε-polynomial basis (`reference/picard-fuchs.md`). If `run.wl` sets a budget per sector, stay
within it.

Whatever the rung, do these things:

- add one entry to the history, `MCBAppendAttempt[dir, <|"rung" -> n, "what" -> "...", "outcome" -> "...", "time" -> s|>]`
  (a choice between equally good bases is not a rung: `check_basis.wls ... --tie-breaker "reason"` records it as one);
- send any basis it produces through the gate, `bin/ws bin/check_basis.wls dir file.m --rung n --provenance ...`
  (or `MCBCheckBasis` inside `AnalysisMasters.m`). It only replaces the current basis when the new one is
  better; add `--dry-run` to look without writing anything, or `--adopt` to replace it whatever the verdict
  (for a basis preferred by a tie-breaker, use `--tie-breaker` instead, above);
- write a paragraph in `notes.md` saying what you tried and why (`MCBAppendNotes`);
- record every paper you took something from, on any rung, in the run's ledger `citations.m` (`--reference` of
  `check_basis.wls`, or `MCBRecordLiterature`), so that its authors can be acknowledged, and declare every tool you
  ran by hand (`--tool NAME`, or `CoreRecordTool[dir, {"NAME"}, "declared"]`): a provenance credits nothing.

`MCBRetryHints[dir, record]` lists the rungs that have not been recorded yet, in order. That list is what
the sector's page shows under "This sector can be retried".

## Rung 1: cheap and automatic

The first pass (`MCBAutoPass`) has already tried the three best representations by score, pools with
numerator degree `nd = 2`, up to `nt = 2` dots and total weight `w = 3`, subsets of one or two pool
integrals plus a solve over the whole pool, and then a second attempt with `nd`, `nt` and `w` one higher,
3-term subsets and the standard representation (when it was built: by default only with at most three cut
variables, see `$MCBMaxStandardVars`). When the candidates were too few to form a basis, it also
tried representations with one more ISP. On a sector whose Picard-Fuchs label is not polylogarithmic it kept only
the representations with a curve or single-integral route, and skipped the dlog completions below and the
representations with one more ISP; skip that dlog-only work by hand too.
An ε-form basis does not end the pass while one of its elements is not ε-pure (`epsPure` False): the pass goes on
with the other representations, the candidates that are dlog in d dimensions and the larger pools (the representations
with one more ISP only when the candidates were too few), and
keeps an ε-form basis with fewer such elements when it finds one (`attempts.m` says so: "eps-pure elements").
All of this shares the sector's time budget (`"Sector"` in
`run.wl`); a flag on the sector's page says when the budget ran out before the pass was done. If the log
suggests there is more to gain, push further by hand, with a budget of your own. `MCBAutoPass` writes whatever
it finds into the folder it is given, so give it a scratch folder outside the run, and send the `masters.m` it
writes there through the gate (`check_basis.wls`), which keeps the better basis:

```mathematica
MCBAutoPass[fam, sector, scratch, <|"nd" -> 3, "nt" -> 3, "w" -> 5, "maxsize" -> 3, "nreps" -> 5, "maxpool" -> {40, 30, 24, 16}, "budget" -> 3600|>]
MCBRepresentations[fam, sector, <|"Extra" -> 2|>]      (* two ISPs more than the minimum *)
```

On a cut with one variable and a root of degree at most 2 (genus 0), the dlog route also matches pool
integrals directly to the dlog forms that `MCBCurveTargets` lists: `dz/y`, normalised by the square root of the
leading coefficient of `y²`, and the third-kind forms `dz/((c z + d) y)` at the linear punctures, normalised by
`c y` there so that their residue is constant. That is linear
algebra over subsets of one or two pool integrals, so it finds candidates even when the iterated leading
singularities time out or come out rank-deficient; both kinds of candidates go into the search.

When the first attempt is not in ε-form, the pass completes it. It projects the same targets onto pool
integrals modulo total derivatives (`MCBProjectedCandidates`). It also makes the dlog candidates exact in ε
(`MCBPurifyCandidates`, and `MCBProjectedPurifyCandidates` modulo total derivatives). Then it adds single
integrals. On one-variable cuts the projection is the step that most often reaches ε-form: a third-kind form
`dz/((z - p) y)` is seldom the integrand of any integral, but it is a combination of a few of them up to a
total derivative. When it fails there, check whether the twist has a quadratic factor off the square root
(section 5 of `reference/method.md`).

Things to look for in the log: "LS-failed" or "timeout" mean a variable order or a pool was too large, so
use fewer variables or a smaller pool (after either of them the automatic retry keeps the pool cap and only
raises `nd`, `nt` and `w`); a representation that times out often keeps timing out with a longer limit, so try
another representation before raising it; "rank-deficient" means too few pure candidates, so add numerators or
try other ISPs; a "rational" DE means the candidates are not dlog, so the geometry or the normalisation is off.

## Rung 2: search the literature

1. Build search queries from the sector: the number of loops; how many propagators and which masses; the
   external legs and their masses; any linear (eikonal) propagators; words such as "canonical basis",
   "uniform transcendental", "pure functions", "elliptic"; and the usual names (bubble, triangle, box,
   sunrise, kite, double box, pentabox, ladder, non-planar, "with one massive leg", "HQET", "Wilson line").
2. Search arXiv and INSPIRE with whatever web tool you have. If you have none, tell the user and ask for
   papers. Read everything in the sector's `refs/` folder, where the user may leave papers or notes.
3. Map the paper's family onto this one:
   - match the propagators by momentum and mass, allowing shifts of the loop momenta and relabelling of the
     external ones (`k → -k`, `k1 ↔ k2`, `p_i ↔ p_j`), and write the map down explicitly;
   - translate the integrals index by index (`j[fam, ...]` follows Kira: a positive index is a propagator power);
   - translate the kinematics: the Mandelstam convention (`s = (p1+p2)²` or `2 p1·p2`), the metric signature,
     the sign of the propagators (`-k²` or `k² - m²`, Euclidean or Minkowski), the `i0`;
   - overall factors such as `e^(eps γE)`, `Γ(1 + eps)`, `(-s)^eps`, `(4π)^eps` or `i π^(d/2)` do not matter
     here; powers of ε and algebraic prefactors do;
   - a basis given in `d = 2 - 2eps` has to be mapped to `4 - 2eps` with `MCBTarasovLower` (see rung 3).
4. Write the candidates as expressions in the style of `masters.m` and run them through the gate with
   `--reference "authors, title, journal, arXiv:xxxx.xxxxx"`, once per paper, and `--used "the basis of eq. (n),
   mapped by ..."`. The ledger keeps the entry either way, as adopted or not adopted; a paper whose basis was not
   adopted is listed in `CITATIONS.md` under "Also consulted". Take the reference from arXiv or INSPIRE, not from
   memory.
5. A paper that helped without giving a basis (the map of a related family, a normalisation, the geometry of the
   cut) is recorded too: `MCBRecordLiterature[dir, <|"reference" -> ..., "used" -> ..., "rung" -> 2|>]`.

Common traps: a different momentum routing changes which scalar product is the ISP; a numerator in the paper
may not be an ISP of this family, in which case rewrite it with the scalar-product map `fam["SPtoD"]`; the
signs of square roots do not matter, since the gate drops their ratios.

## Rung 3: shift the dimension

```mathematica
res = MCBDimensionShift[fam, sector, 2, FileNameJoin[{scratch, "d0shift"}]];   (* d = 2 - 2 eps; scratch outside the run *)
res["shifted"]   (* the basis found in d0' = 2, and its status there *)
res["check"]     (* the same functions written with D0 - 2 eps integrals, through the gate *)
```

This redoes the representation, the candidates and the basis search in `d = d0' - 2eps`, then maps the best
basis back with Tarasov's relation, `I^(d-2) = (-1)^L U(a_1 A_1^+, ..., a_N A_N^+) I^(d)`. Here `U` is the first
Symanzik polynomial (`MCBSymanzikU`) and the relation is applied `(D0 - d0')/2` times (`MCBTarasovLower`).
Only shifts down, and by an even number, are supported. Cuts of sunrise, kite and banana type are usually
simpler in `d0' = 2`, where the maximal-cut integrand is directly a form of the first kind. The shift credits
Tarasov's relation to the sector of the citation context (the sector in its `AnalysisMasters.m`); run from a script
of your own, pass `--tool Tarasov` to `check_basis.wls` with its basis.

## Rung 4: agent-built candidates

The building blocks are `MCBCutIntegrand[cd, j]` (which gives `R(z, eps)`), `MCBCutIntegrand0`,
`MCBIteratedLS[vec, Pr, order]`, `MCBCurveCoordinates[W, P, z]`, `MCBCurveTargets[cd]`, `MCBFibrationTable[cd]`
and `MCBCandidate`.

0. Run `MCBLoopByLoopReport[fam, sector, <|"KiraMasters" -> n, "Integrals" -> {...}|>]` with the current basis
   and a few dotted integrals in `"Integrals"`, for every loop order. If the representation sees fewer masters
   without its O(ε) factors than with them, the missing ones live on those boundaries: build them from dots on
   the propagators of the subloop whose Baikov polynomial vanishes there (one dot gives
   `R = ε × rational` with a simple pole on the boundary), pick the boundary forms you need with
   `MCBBoundaryForm` (on a boundary curve: first, second and third kind at the punctures), and complete the
   set with integrals whose numerators the representation does not keep (an extra ISP) when a puncture is not
   reached. Avoid numerator powers whose cost at infinity (`n + 1 + E_v` in the report) is not an ε-monomial.
1. Print the ε = 0 cut integrand of the corner integral and look at it one variable at a time. Where are
   the poles? Which are double? Is there a pole at infinity? Which factors sit under the square root?
2. Choose numerators that cancel the double poles or the poles at infinity: a numerator that vanishes at
   the double pole, or a lower power of a variable that grows at infinity. Dots move poles onto the cut
   propagators; use them when a numerator cannot reach a pole.
3. Take the residues, by hand or with `MCBIteratedLS` on a single integrand, and divide by the leading
   singularity. With square roots, make sure every term has the same one.
4. On curves, write each candidate's cut differential in curve coordinates. Build the first-kind combination
   (it cancels every other coordinate), then the second- and third-kind ones; for genus 2, follow section 9
   of `reference/method.md`. A combination whose numerator cancels the curve part completely is dlog.
5. On cuts with several variables, look for a fibration (`MCBFibrationTable`): integrate first the variable
   whose root is quadratic, and the discriminant then defines the curve in the remaining variable.
6. A target that no integral gives directly can still be reached up to a total derivative. Give your own
   candidates (dlog at ε = 0) to `MCBProjectedPurifyCandidates[fam, sector, cd, cands, <|"nmi" -> n|>]`, in
   the representation `cd` they were made in. It returns them as combinations of pool integrals with
   coefficients rational in ε.
7. Send every idea through the gate, keep whatever improves the ε-structure, and write down why in `notes.md`.

**An element that is not ε-pure.** The page names the factor it carries (`epsPureDetail`), for instance
`(-1 + 2 eps)^-1`: it comes from the Γ prefactor of the representation or from a numerator power. Replace the element
by the natural integrand of the subloop that carries the factor (`MCBLoopByLoopReport`): a dot on its massive tadpole or
bubble line (one dot gives ε × a simple pole), no dots on triangles and boxes, a numerator equal to its Baikov variable
rather than a power of an ISP. For an undotted massless bubble, s times the bubble with one dot is pure. A dlog
candidate whose integrand depends on ε can be made exact in ε (`MCBPurifyCandidates[fam, sector, cd, cands]`, or
`MCBProjectedPurifyCandidates` modulo total derivatives); its verdict is then `True` "as built". `check_basis.wls` prints
the verdict of each element and adopts an ε-form basis with fewer elements that are not ε-pure without `--adopt`.

## Rung 5: master integrands chosen by their geometry (the ε-collaboration's step 1)

Bree et al. (arXiv:2511.15381, sections 3 to 4.2; first outlined in arXiv:2506.09124) choose the master integrands
of a sector on its maximal cut by the poles and residues of their integrands. They observe that the resulting
maximal-cut DE is a Laurent polynomial in ε with a fixed structure, using rational functions only (plus the leading
singularities of the top-weight elements). The paper builds this order into a Laporta reduction. Here you apply it
by hand with the toolkit's cut integrands, and send the basis through the gate. It is the principled route to the
ε-polynomial basis of a non-dlog sector, and on a polylogarithmic sector it ends in ε-form. Record the paper with
`--reference` whatever the outcome.

**What it gives.** Order the elements by |µ| (below). The DE is then F-compatible: the entry `A_ij` only has powers
`eps^m` with `|µ|_j - |µ|_i <= m <= 1`. So it vanishes when `|µ|_j > |µ|_i + 1`, the blocks of equal |µ| are
`A0 + eps A1`, and an entry k levels below the diagonal starts at `eps^(-k)`. The paper sees this in every example
and knows no counterexample, but does not prove it. When every element is localised on points (top weight), the DE
is ε-form.

**The representation.** Use a good one: every twist factor regulated, so `MCBTwistFactors[cd]` shows no
`unregulated` factor (the standard representation is always good, `MCBRepresentations[fam, sector, <|"Standard" -> True|>]`
builds it when it has many variables; a loop-by-loop one with an extra ISP often is).
The paper's divisors are the twist factors plus infinity:

- odd divisors, the `branch` factors (half-integer exponent at ε = 0), define the geometry (the curve or surface);
- even divisors, the `eps-only` factors and the `integer` ones (their integer part moved into the integrand), are
  where residues can be taken. Their zero sets and intersections are the localisations; `MCBBoundaries[cd]`
  classifies the zero set of each one (point, rational, curve of genus g);
- infinity is one more divisor (the paper works in projective space), even or odd by the parity of the summed
  degree of the branch factors. A numerator power that leaves a pole at infinity counts as a denominator power
  there; `MCBInfinityExponents[cd]` gives the behaviour at large values of each variable.

**The data of an integrand.** Read them from `MCBCutIntegrand[cd, j]` (the cut integrand over the twist) and
`MCBCutIntegrand0` (its ε = 0 form), with n the number of cut variables:

- |µ|: the total denominator power of the integrand on all divisors, infinity included;
- o, the pole order, at ε = 0: `dz z^(-α)` at z = 0 has order ⌊α⌋ (`dz/z`: 1, `dz/Sqrt[z]`: 0), orders add at
  normal crossings (`dz1/z1 dz2/z2^2`: 3), and o is the maximum over points. Where divisors cross non-normally
  (tangent, or three through one point in two variables) blow up first, as in sector decomposition; that can
  raise the order;
- r: the number of consecutive non-zero residues on even divisors, and the weight w = n + r.

They are compared in the order (a, w, o, |µ|), lexicographically, the smaller being the simpler and so the master:
first the preferred candidates that lower-dimensional localisations supplied (a = −w), then lower weight, then lower
pole order (holomorphic forms before forms with poles), then smaller |µ|.

**The procedure** (the paper's algorithms 1 to 3), from points up:

1. Points (n residues, top weight w = 2n). A localisation on N points has N masters: the simplest integrands whose
   matrix of n-fold residues at those points is non-degenerate. `MCBIteratedLS` on a pool gives the residues.
   Normalise each by its leading singularity (the paper's section 4.4): these are the dlog elements of rung 4.
2. Each one-dimensional localisation (n − 1 residues). The point masters on it are preferred; complete them in
   the order above. On a localisation that is a curve, the holomorphic form (first kind) comes first, then pole
   order 2 (second kind). `MCBBoundaryForm[cd, R, f]` gives the form an integral induces there, and
   `MCBCurveCoordinates` its kind. Keep the pole order on the whole cut, after blow-ups, at what the localisation
   needs: the paper drops a candidate whose order jumps to 3 at a tangency.
3. Merge: an integrand that is a master on two intersecting localisations, with residues on both, counts once.
4. Continue dimension by dimension up to the whole cut (r = 0), whose remaining masters again come by pole order,
   then |µ|.
5. Compare the count with Kira's (`nMastersCut`). Twisted cohomology can count more (`MCBMasterCount`): drop the
   integrands of super-sectors (a pole on the variable of an uncut propagator puts it in a sector above), and in
   each symmetry relation of the sector eliminate the element with the largest |µ|.

**The powers of ε.** The paper normalises each integrand with `eps^(-|µ|)` (its clutch factor, eq. 59), on top of
factors that remove the ε which integration by parts produces (the relative prefactor, eq. 57: for instance the ε
that a dot on an `eps-only` factor brings) and a common factor that makes the Baikov prefactor pure. Relative to
each other, an element with one more denominator power carries one power of ε less. In the three-loop banana with
one massless line in d = 2 − 2ε (section 5.5), `-2 eps^3 I[1,1,1,1,0,0,0,0,0]` has |µ| = 1 and
`eps^2 I[1,1,1,2,0,0,0,0,0]` has |µ| = 2: the dot gives a pole on a `branch` factor. A dot on an `eps-only` factor
instead brings its own ε, which the relative prefactor takes out: `2 eps^3 I[2,0,0,1,1,1,0,0,0]` and
`-eps^2 I[2,0,0,1,1,2,0,0,0]` (section 4.4) both have |µ| = 1. Write the elements with these powers and their
leading-singularity normalisations, and check them with the gate (`--rung 5`).

**You are done** when the gate says `eps-form`, or `eps-polynomial` with a profile (`pattern` in `basis.m`, the grid
on the page) that is F-compatible once the elements are ordered by |µ|. An entry with a power above 1, or below
`|µ|_j - |µ|_i`, means that an element's |µ| or power of ε is off by that difference. The gate keeps an
ε-polynomial basis with a smaller spread of powers: adopt the F-compatible one with `--adopt` when the current basis
is not F-compatible, and say why in `notes.md`. The reference for the ledger (checked on arXiv on 2026-10-12):
"I. Bree, F. Gasparotto, A. Matijašić, P. Mazloumi, D. Melnichenko, S. Pögel, T. Teschke, X. Wang, S. Weinzierl,
K. Wu, X. Xu, New algorithms for Feynman integral reduction and ε-factorised differential equations,
arXiv:2511.15381".

## Rung 6: other algorithms

The skill does not run these tools itself; it only prepares their input. Export the maximal-cut DE of a
rational start basis (square roots stripped):

```mathematica
sde = MCBSymbolicCutDE[fam, sector, startBasis, FileNameJoin[{scratch, "symbolic"}], {x1, x2}];   (* invariants kept symbolic *)
MCBExportDE[FileNameJoin[{scratch, "export"}], "INITIAL" | "Libra" | "Fuchsia", sde["A"]]   (* scratch outside the run *)
```

If the FiniteFlow check has run, `finiteflow/DE.m` works as well.

- **INITIAL** (arXiv:2002.02340) builds the canonical DE from one uniform-weight seed integral, such as a
  good dlog candidate of the sector. It is the right choice when one pure integral is known and the others are not.
- **Libra** (arXiv:2012.00279) implements Lee's algorithm: first a Fuchsian form, then ε-form, one variable at
  a time. It suits blocks with one variable, or with the other invariants fixed.
- **Fuchsia** (arXiv:1701.04269) does the same for systems in one variable. It is a Python tool and reads
  Matrix Market files.

Bring the transformed basis back as expressions in `j[...]` and run it through the gate with `--tool INITIAL` (or
`Libra`, `Fuchsia`), so that the tool is credited to the sector; naming it in the provenance credits nothing.

## Rung 7: flag the sector

The status becomes `eps-polynomial (dlog search incomplete)` if the best basis has a Laurent-polynomial DE,
and `failed` otherwise; an ε-form basis with an element that is not ε-pure stays `eps-form`, flagged. Write in `notes.md` what each rung found and what you would try next. The page
prints "This sector can be retried" with the rungs not tried yet (`MCBRetryHints`). Tell the user.

For sectors that really are not dlog (status `eps-polynomial`), the next step lies outside this skill: the
periods of the curve, or of the fibration, are needed to make the block ε-factorised.
