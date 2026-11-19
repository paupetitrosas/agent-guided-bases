# Method

Why poles appear in a differential equation (DE) of master integrals, why a fix has to look the way it does, and
what each rung of the ladder computes.

## Setting

∂_k I = A_k(x, ε) I for masters I_i = ε^{p_i} r_i U_i, where r_i is a product of square roots and U_i a
combination Σ c j[ν] with coefficients rational in the invariants x. The **root-free frame** works with U:
R_k[r, c] is the coefficient of U_c in (1/r_r) ∂_k (r_r U_r). R is rational, has the same ε structure entry by
entry as A (R_rc = A_rc r_c / r_r), and contains dlog(r_r) on its diagonal. Every computation of the skill
happens in this frame.

A **slice** is R at one generic rational point x₀, exact in ε. Poles are a property of ε at fixed x, so one
slice sees them all (barring an unlucky point; the gate checks fitted coefficients at more points).

- A **finite pole** is a denominator factor vanishing at some ε = e₀ ≠ 0, such as 1 − 2ε or 1 + 4ε.
- An **ε = 0 pole** is a negative power of ε in an entry.
- **Pole-free** means neither kind anywhere. The **ε profile** of an entry is {lowest, highest} power of ε; an
  ε-form DE has {1, 1} everywhere.
- The **cap** bounds the highest power (`"MaxEpsDegree"` in `run.wl`, default 2). An entry above ε^cap is a bad
  entry, like a pole: its sector is bad and is fixed bottom-up. No change may raise an entry above the cap,
  measured at ε → ∞ for entries with finite poles too; an entry above it before may keep its power until its
  sector is fixed, also when a change removes its poles (`PFBDegreeViolations`).
- **Negative powers of ε** are a pole at ε = 0. The simplest fix is a uniform ε^k on whole masters (rung 1),
  tried on the whole slice first and kept within the cap. Those left in a sector's rows towards lower masters get
  the source test like a finite pole: a new master whose relation to the old one carries 1/ε (as IBP coefficients
  often do) removes them without changing the maximal cut. Those in the sector's own block need a new maximal-cut
  basis (rung 8).

## Rules for a new master

These are hard rules, checked by the gate:

1. One power of ε per integral: every coefficient c in ε^p c j[ν] is ε-independent.
2. No (a + bε) factor, and no ε in any denominator.
3. A uniform ε^k on a whole master is allowed: it is a normalisation.
4. Coefficients may be rational in x; the master keeps its root prefactor.

**The determinant is recorded, not judged.** det T, the new masters on the ones they replace (on the maximal cut, the
new sector basis on the old one), must not vanish, or the change cannot be applied; the record keeps it. Nothing else
is asked of it. A factor such as (1 − 2ε) in det T says that, on the maximal cut, the new masters are the old ones
rescaled by (1 + aε), and which of the two carries that weight depends on a starting basis the skill cannot trust.
Whether such a change is right, the gate reads from the DE alone. A constant weight w on master m multiplies its row
by w and divides its column by w: the fix that removes a weight the old master carried creates no pole, and a
rescaling that hides the poles of row m puts 1/w into every row that couples to m, where the census shows it (the
gate may defer those poles to their sectors, as a factor the change removed from its own rows). A weight on a master
that no row couples to shows only as a higher power of ε in its row ("What pole-free does not give").

`PFBTryChange` takes the new masters of one sector per change (images belong to their base sector): the gate judges
the rows of that sector, and the extra points reduce its subtree, so a new master of another sector would be checked
by neither.

**What the rules are about: the definition, not the relation to the old basis.** Rules 1 and 2 constrain how a
master is written in the masters file. A new master defined as a single dotted integral with an ε-monomial
coefficient is honest. When it is reduced onto the old basis by IBP, I'_m = I_m + Σ_S λ_S I_S, the coefficients
λ_S may well contain 1/(1 + 2ε), 1/(1 − 2ε) or 1/(1 − ε): IBP reduction coefficients carry factors like 1/(d − 5)
even between honest integrals (a dotted one-loop bubble reduces to the undotted one with a factor (d − 3)). These
λ_S are exactly what removes the poles (fact A below). They are used to update the slice and never go into a
masters file. What the rules forbid is writing such a factor into a definition, I_m + (1/(1 + 2ε)) Σ …: expanding
1/(1 + 2ε) mixes orders of the ε expansion, so that master would not be of uniform weight. Read the same
relation the other way round, I_m = I'_m − Σ_S λ_S I_S: it is the old master that equals a good one minus
1/(1 + 2ε)-type admixtures, which is why its rows had poles although its definition was honest too.

## Three facts

- **A. A regular change cannot remove a pole.** From A' = T A T⁻¹ + (∂T) T⁻¹: if T and T⁻¹ are regular at e₀,
  A' is regular there exactly when A is. Removing a pole needs a change singular at e₀. For a unipotent change
  (new master = old + lower masters) the lower coefficients λ must have the pole.
- **B. A singular change can still give an honest master.** Two integrals of a sector with the same
  maximal-cut class differ by subsector integrals, and reducing that difference can produce finite poles. So
  λ with poles can come from an integral whose own coefficients are ε-free: a dot moved to another propagator,
  a numerator completed by propagators of the sector (N = D₈ − D₆ − D₇ + D₅, equal to D₈ on the cut).
- **C. Derivatives of honest integrals are honest.** ∂_k j[ν] has ε-free coefficients. A pole in row r means
  the basis spans the wrong lattice at e₀; any master in that row's expansion can be the culprit, not only r.

## What a change does to the rows

Take three masters: a top master T, a middle master M that is redefined, and a lower master L. The DE is block
lower-triangular:

    ∂T = a_TT T + a_TM M + a_TL L,     ∂M = a_MM M + a_ML L,     ∂L = a_LL L.

Redefine only M by adding the lower master, M' = M + λ L (λ is the reduction coefficient of the new integral,
see "What the rules are about" above), i.e. M = M' − λ L. Then:

- **row L is unchanged**: its derivative never contained M;
- **row T changes although T was not touched**: ∂T is the same function, written in the new basis,
  ∂T = a_TT T + a_TM M' + (a_TL − a_TM λ) L. Replacing one basis vector changes the components of every other
  vector along the remaining ones;
- **row M' changes by its own rule**, which involves ∂λ: ∂M' = a_MM M' + (a_ML − a_MM λ + ∂λ + λ a_LL) L.

So a change of master m touches its own row and the rows of every master that couples to it (its own sector and
the sectors above), never a lower row. If a_TL has a pole and λ has the matching one, a_TL − a_TM λ has none:
this is how fixing a lower master cures the rows above it (inherited poles, below), and the general form
A_rS − A_rm λ_S of the next section is this example with many rows and columns. Note that a slice lists its
rows in whatever order the master list has; "above" and "below" always mean higher and lower sectors, not
positions in the matrix.

## The source of a pole: residue-column factorisation

Replace master m by I'_m = I_m + Σ_S λ_S I_S. Every other row becomes A_rS − A_rm λ_S, and is regular at e₀
exactly when PP_{e₀}(A_rS) = PP_{e₀}(A_rm λ_S) for all columns S. For a simple pole: Res A_rS = A_rm(e₀) ρ_S with
ρ = Res λ. The residues of all those rows are column m times one row vector ρ, the same for every row and
every derivative. Higher-order poles use more Taylor coefficients of A_rm; several sources solve
Res A_rS = Σ_m A_rm(e₀) ρ_mS.

`PFBSourceTest` tries sources by position (the same positions in a family and its images), smallest sets
first, using the sector's other rows as test rows; then lower masters with their images. Negative powers of ε
in the rows towards lower masters are the pole e0 = 0 of the same test (key 0 of `"Poles"`). Adding integrals to a
master brings in only masters below it, never those of a sibling sector, so a lower master gets unknowns only for
the pole columns below it: those its row reaches through the couplings of the DE (symmetries included), and the
strict subsectors of its sector in its own family. Outcomes:

- **source**: masters of the sector whose replacement can fix the other rows, with the required ρ. The source's
  own row is not predicted (it involves ∂λ) and is checked after the change.
- **lower-source**: the poles come from a lower master; that sector is the one to fix (**inherited** poles).
- **undecided**: nothing passes, but lower sectors that are still bad (and not flagged) can change these rows
  (`"WaitFor"`): masters whose columns carry the poles (`"WaitColumns"`; adding integrals to a master never changes
  its own column, A'_rm = A_rm, but a change of its normalisation or maximal cut does), and masters the rows couple
  to whose fix reaches the pole columns through −A_rm λ (`"WaitCouplings"`). Fix or flag those sectors, then run
  the test again.
- **own-row**: no column explains them; after the pair scan (rung 3), the sector's masters need a completion
  (rung 6), or a new maximal cut.
- **maximal-cut**: the sector's own block has poles, negative powers of ε or entries above the cap; only a new
  maximal-cut basis helps (rung 8). This comes before the pole tests.

**Entries above the cap: the same test at ε → ∞.** A kept row becomes A_rS − A_rm λ_S, and its powers above ε^cap
must vanish. With λ_S = Σ_j l_j ε^j at infinity, that is a linear condition on the l_j, as for a finite pole on the
principal part. One difference: here λ may be a polynomial in ε, so an honest correction with an ε-monomial
coefficient can lower a power, where only a singular λ removes a finite pole (fact A). A sector without finite
poles whose rows have entries above the cap gets:

- **degree-source**: masters of the sector whose replacement can bring the other rows within the cap;
- **undecided**: nothing passes, and those entries sit in the columns of lower sectors that are still bad;
- **degree-own-row**: nothing passes: the pair scan (rung 3), then a completion (rung 6), a derivative (rung 7)
  or a new maximal cut.

With `undecided` and `own-row`, `"SingleColumn"` lists the poles that sit in the column of one lower master only,
in every bad row. If that master's own row is pole-free, this is the pattern of a hidden normalisation of that
master (step 4 of the structural reading below), to check before rungs 6 and 8.

`PFBSourcesByPole` runs the same factorisation pole by pole: for each factor, the smallest sets of the sector's
masters that can carry it, and whether the own block has it; ε = 0 (factor ε) is one more pole when the rows have
negative powers of ε, and ε → ∞ (factor ε^(cap+1)) when they have entries above the cap. Different poles can have different sources.

**The number of sources is not a rank.** Replacing the sector's masters by U'_S = U_S + λ U_L changes the sector's
rows towards the lower masters L into R_SL + ∂λ + λ R_LL − R_SS λ. A kept master's row (λ_r = 0) loses R_rm λ_m,
so it must factor through the sources' columns; a source's own row gains ∂λ_m, which is free. The principal parts
of R_SL can therefore have full rank with a single source: the source spreads into every other row through
R_SS, and its own row adds one more direction. Example: a sector of two masters whose residues have rank 2 at each pole,
where moving the dot of one master removes every pole of the sector. Nor does a sector
in which every master is a source need a new maximal cut: each master then needs its own honest replacement.
Only poles in the own block, or a ladder that finds no honest replacement, call for rung 8.

## Inherited poles and bottom-up order

A pole in a row can come from a lower master (fact C). Fixing a lower sector changes the rows of every sector
above it, so work **bottom-up**: the lowest bad sector first, then take a new census. The census marks a
sector **possibly inherited** when its rows couple to a lower sector that has bad rows itself; such a sector
waits. A lower sector with clean rows can be the source too, through a hidden weight on one of its masters (next
section): the census then marks that clean sector and opens it first.

A correct fix can also give the rows above new poles: they lose A_rm λ_S, and that product has the poles of λ and
those of A_rm. The gate defers them to their own sector when that sector can still change (not flagged, not fixed
by an accepted change, no frozen family) and every new pole is one of two kinds:

- a factor of λ, which the fix removed from its own rows, when all of that sector's poles, old and new, still
  factor through one proper subset of its masters;
- a **moved pole**: a factor of A_rm, which that sector's rows had before the change, now also in column S, when
  the census as a whole loses bad entries. The subset condition is not asked here: the sector had the factor
  already, and its own fix must remove it wherever it sits. In a real run a fix of a lower sector moved the upper
  sector's 1/(1 + 4ε) into a new column, and the gate refused it before this kind existed.

A factor of neither kind refuses the change.
That sector's fix must then remove the deferred poles too (`PFBDeferredObligations`, which lists moved poles
separately). The source test no longer proposes the master already
fixed as a lower source (option `"Fixed"`): what it leaves above belongs to that sector.

## A hidden weight on a clean lower sector

**The signature.** A master of a clean sector S can carry a weight: I_m = w J_m, with w = 1 + 4ε (any a + bε) and
J_m honest. Every row above that couples to I_m then has 1/w in column m, and also in the lower columns that the
relation brings in (I_m = w J_m − c I_L puts 1/w into column L too). S's own rows stay clean when no other master of
S couples to I_m, which is always the case for a sector of one master. So the poles show in a sector T above, only in
columns of S's subtree. A fix inside T needs corrections whose relation to I_m carries 1/w (J_m itself, in effect),
and leaves the weight in the basis: every other row that couples to I_m keeps its 1/w. The fix that removes the
cause replaces I_m by an honest integral of S and clears every row above at once. Without a pointer to S, a search in
T that finds nothing ends with a flag. (The converse, I_m = J_m / w, puts 1/w into S's own rows towards lower
masters: S is then a bad sector, and its source test finds the source.)

**Why the maximal cut does not see it.** On S's maximal cut, I_m and J_m differ by the constant w(ε): the same
leading singularity, the same cut integrand up to that constant, and a maximal-cut DE changed by D R_SS D⁻¹ with
D = diag(w) constant in the invariants. A block of one master does not change at all, and a block whose other masters
do not couple to m stays pole-free; ε-form on the cut survives a constant rescaling. The maximal-cut-basis analysis
therefore certifies I_m and J_m alike. Only the couplings to the sectors above show the weight, as poles.

**The route.**

1. **The census hint.** For a pole factor w, when every column that carries w in the bad rows lies in the subtree
   of one clean sector S (`PFBSubtreeMasters`: S's masters, images included, those of its subsectors in its base
   family, and every master its rows reach through the couplings of the slice), at least one of those columns is a
   master of S, and every row with w lies above S and couples to S's masters, the census marks the lowest such S
   that can still change (no frozen family, not flagged: `PFBCanChangeQ`, the census option `"Fixed"`, which the
   scripts pass with `PFBCensusOptions`; a sector fixed by an accepted change is named too, with `"Reopens"` -> the
   change's id, since the weight is often what that change left, and the lower-sector scan keeps its rows pole-free)
   (`"PossibleHiddenWeight"`, `"HiddenWeights"`) and makes it `"Next"` before the sectors where the poles show. It is
   a hint: an ordinary bad sector whose pole sits only in the column of one clean lower master gets it too, and the
   lower-sector scan that settles it is small (one reduction of S's subtree at the slice point); once recorded, the hint ends. The
   source test of S and of those sectors says so (`"HiddenWeight"`). Columns spread over two unrelated clean sectors
   give no hint.
2. **The hidden-weight test, before a flag.** The scans (`PFBRecordScan`, called by `bin/pair_scan.wls` and
   `bin/slot_scan.wls`) and `PFBTryChange` record in `attempts.m` the pole entries each attempt left in the sector's
   rows. `PFBHiddenWeightTest` reads them: when a factor left over always sits in the columns of one clean lower
   sector's subtree, it names that sector and the factor. `PFBFlagSector` runs it and refuses to flag while the
   sector it names has no recorded lower-sector scan for that factor. This also catches what the census cannot see:
   a factor that sat, on the slice, also in a column the sector's own fix could clear.
3. **The lower-sector scan** (`bin/pair_scan.wls run.wl <job> fam/jS --hidden-weight`, `PFBHiddenWeightScan`). Slots:
   S's base-family masters when they are at most three, else those whose columns carry w (more than three: give
   `--slots`). Candidates: S's natural integrals, the structural reading's, and full definitions given whole (such
   as maximal-cut-basis candidates). Each set is applied to the slice and judged on the rows above that carry w:
   fewest entries with w left there first, then the usual keys of the scans. S's own rows must stay free of finite
   poles; a set that puts a pole there is ranked out. Only S's subtree is reduced: the rows above change exactly
   through S's columns, A'_rS = A_rS T⁻¹ and A'_rL = A_rL − A_rS T⁻¹ Λ for the lower columns, from the slice alone.
4. **The gate.** The winner, normalised, goes through `PFBTryChange` with S's key and two or more extra points (for
   fitted coefficients). Its determinant on the old masters is 1/w for I_m = w J_m (w for I_m = J_m / w); the gate
   records it and judges the change like any other. A set that mixes S's masters changes S's maximal cut and also
   passes the maximal-cut-basis check (Kira on the cut).
5. **When the scan finds nothing**, or cannot run (no slots, too many sets, over budget), it is still recorded, the
   latter with its reason: the census no longer makes S `"Next"` for w (`"Tried"`), the sectors where the poles show
   come next, and `PFBFlagSector` may then flag them. A scan that could not run can be narrowed and run again.

## Building the replacement

The new masters are honest integrals with the same maximal-cut class as the old ones (rungs 2 to 7), or a
new maximal-cut basis (rung 8).

- **Dot move (rung 2).** When the source's definition contains a dot. Candidates: the same integrals with one
  dot moved to another propagator of the sector, numerators unchanged (`PFBDotCandidates`). The structural
  reading says which dot to try first: a dot on a propagator of the subloop whose exponent produces the factor
  brings that factor; a dot at a vertex whose subloop is clean does not. `bin/slot_scan.wls` ranks the candidates
  exactly on the slice. The one that works has the source's maximal-cut class (an ε-monomial coefficient on the
  source, none on the sector's other masters), and its reduction carries λ with exactly the required residues
  (fact B), so no completion is fitted. Normalise it by its coefficient on the source, a power of ε times a
  rational function of the invariants. FiniteFlow reconstructs that coefficient as a function, over many cheap
  evaluations of the learned system (`bin/coefficients.wls`, `PFBNormaliseCandidate`), instead of it being guessed
  from a few reduction points. The gate still confirms the normalisation at the extra points.
- **Pair scan (rung 3).** When the sources must be replaced together, or the replacement is not a moved dot:
  the sector's natural integrals (its own integrals with at most one extra dot or numerator power, and the
  candidates of the structural reading) in two or three slots at once, each slot also allowed to keep its master
  (`PFBNaturalIntegrals`, `bin/pair_scan.wls`). Every set is applied exactly to the slice, as for rung 2, so a
  sector of two or three masters is searched whole in minutes. A set with pole-free sector rows is the
  replacement (fact B); a set that mixes the sector's masters changes the maximal cut and is
  judged as in rung 8.
- **Residue fit (rung 4).** Unknowns c: I'_m = I_m + Σ c ε^p v, with v pool integrals of the sector with one
  or more propagators pinched (subsector integrals). Conditions: the principal parts of the test rows vanish,
  at the slice point. The solution is numbers at x₀. When they are integers they usually are constants, and
  single pinches of the corner read as one numerator Σ c_i D_i: a scalar product such as 2(k₁+k₂)·p₄ − q²
  (rung 5 rewrites it). Anything fitted is confirmed at other points.
- **Completion solver (rung 6).** Unknowns c[i, a, b, n]: h_i = base_i + Σ c ε^n φ_b(x) w_a, with w_a lower
  pool integrals, φ_b monomials of the right mass dimension, n the master's own lowest power of ε or one below
  (negative only when the master itself is written with 1/ε^k). For each entry of the new rows towards
  lower masters, at every reduction point: no principal part at any finite pole, no negative power of ε (and,
  with `"Target" -> "EpsForm"`, only ε¹). The unknowns are x-independent, so all points enter one linear
  system; a solution with few points can be spurious, which the gate catches.
- **Derivative construction (rung 7).** When the source is a second-kind master (a dot, a high power of an
  ISP) and no completion exists, replace the sources by derivatives O(U_c) of clean masters c of the sector,
  with O = Σ a_k(x) ∂_k. Choose O **Gram-free**: O(U_c) has polynomial coefficients, so the new master is
  honest; for example (m² − t)∂_t − (q² − s)∂_{q²} for a corner integral. The candidate's maximal-cut part is
  Σ a_k(x₀) R_k[c] on the slice itself, so the **coupling rank** (the new set must replace the sources:
  determinant on the sector block not zero) is decided before any reduction. Derivative masters often bring ε²
  couplings: pole-free, not ε-form.
- **Maximal-cut change (rung 8).** When the sector's own block, or every completion, fails. Start from the
  structural reading below: the subloop that produces the factor says which integrand is uniform weight. Dots rather than
  ISP powers (the twist F^{-1-ε} makes high ISP powers cost factors like (m − 2ε)); dots at a vertex that is
  clean on every released cut; sums of dotted integrals that are equal on the maximal cut. The maximal-cut-basis
  toolkit adds its own candidates (its run's basis and steps, its dlog, curve and single-integral routes), the full
  rows rank them, and its gate (Kira on the cut, the Euler relation) checks the finalists; ε-form on the cut only
  breaks ties, since the DE above the sector decides (`reference/escalation.md`, rung 8). On a non-dlog sector a
  basis whose every element is dotted is likely to carry a weight between sectors: an undotted element wins a tie.

## Reading a sector's structure (before any computation)

Do this for every bad sector, after the source test and before any reduction, fit or search. It costs minutes
of reading and usually names the candidate; generic searches (large pools, many-term combination scans,
rational ansätze fitted over many points) cost hours and often find nothing, because the right candidate was
never in their pool.

1. **Read the DE bottom-up.** On the slice, list for each bad row of the sector the columns that carry each
   pole factor, and group them by factor. The lowest sector among the columns is where the pole enters: the
   fix goes into the row of that sector's masters, or into the rows above as a correction from that sector.
   Note which entries must change (rows) and which lower masters they point to (columns): this is the list of
   subsector contributions a fix must supply. `PFBSourcesByPole[sys, sl, key]` adds, for
   each factor, the smallest sets of the sector's masters whose replacement can remove it, and whether the
   sector's own block carries it (then the maximal-cut basis must change). A dotted source points to rung 2,
   a master the maximal-cut analysis never certified to step 4. Read the number of sources from this test, never
   from a rank of the principal parts ("The source of a pole", above).
2. **Write the sector's loop-by-loop Baikov representation**, and the standard one when it is simpler
   (`MCBRepresentations` of the maximal-cut-basis skill). For each one-loop subloop with E external momenta,
   the Gram G(k, p₁..p_E) carries the power (d − E − 2)/2 and the external Gram (E + 1 − d)/2. IBP reduction
   divides by these exponents and their integer shifts, so a factor sits where one of them vanishes: 1 + 2ε at
   d = 5 (E = 3), 1 − 2ε at d = 3 (E = 1), 1 − ε at d = 2. Match each pole factor of step 1 to the subloop
   whose exponent produces it. Massless or degenerate subloops (zero external mass, equal internal masses,
   linear propagators) shift these values and are the usual suspects.
   `MCBLoopByLoopReport[fam, sector, <|"KiraMasters" -> n, "Integrals" -> {...}|>]` does this reading for every
   loop order and prints what to look at: the role and E of each polynomial, read off its exponent; the twist
   factors with their kinds (square-root branch, integer, O(ε) only); the behaviour at infinity in each cut
   variable, u ~ v^(E_v), which makes a numerator v^n cost the factor n + 1 + E_v (a basis of ISP powers pays
   these: v^1 and v^2 with E_v = −1 − 3ε give 1 − 3ε and 2 − 3ε); perfect-square discriminants; the number of
   masters the representation sees with and without the O(ε) factors; and the geometry of the bulk and of the
   zero set of every non-branch factor. When the count without the O(ε) factors is lower, the missing masters
   live on those zero sets. A typical case is a one-loop subloop with E = d0 − 2 (a triangle in four
   dimensions), whose Baikov polynomial has exponent −ε: its zero set is a boundary that the ε = 0 twist does not
   see, the restricted square root there can be a curve (an elliptic curve with rational punctures, for
   example), and integrands without a pole there (numerators on ISPs) cannot give those masters the right
   weight.
3. **Build the candidate from that subloop.** The integrand that removes the factor is the natural one for
   that subloop: a dot on its massive line, or a numerator equal to its Baikov variable, completed by
   propagators of the sector (fact B). Expanding the completed numerator gives the subsector integrals it
   brings, which must match the columns of step 1. For masters on the boundary of an O(ε) factor: one dot on a
   propagator of that subloop gives a cut integrand ε × (rational with a simple pole on the boundary), with no
   (a + bε) factor, and the report prints the form it induces there (first kind, third kind at a puncture, ...);
   choose dots that give independent forms, and reach a puncture that no dot reaches with a numerator on an ISP
   outside the minimal representation. Example: a sector whose inner subloop is an equal-mass
   bubble at zero external momentum, attached to a massless one-loop subloop, has a factor 1 − ε that no dot
   removes. The difference of the two equal-mass propagators, D_a − D_b = 2k·(l − p), is linear in the inner
   loop momentum; as a numerator it is zero on the maximal cut, and its reduction gives exactly two single
   pinches, one with D_a removed and one with D_b removed. Those two integrals are the correction to test.
4. **Look for hidden normalisations.** A master the maximal-cut analysis never certified (a sector without
   kinematic dependence, an extra master found only by the reduction) can carry a factor (a + bε). It shows
   up as finite poles in its column in the rows above, in no other column of those rows, and nowhere in its
   own row. The fix is a different integral for that master, chosen from its structure (the uniform-weight
   choice for that sub-topology), not a completion of the rows above. Its determinant on the old master carries
   the factor; the gate records it, and the rows above, which had the factor in that column, lose it. When that
   master's sector is clean, this is a hidden weight on a clean lower sector ("A hidden weight on a clean lower
   sector", above): open that sector and run its lower-sector scan.
5. **Only then compute**, with a small targeted pool (fix the masters the reading determines and try the
   remaining slots one at a time with `bin/slot_scan.wls`, or two or three at once with `bin/pair_scan.wls`; both
   run every candidate exactly on the slice and rank them): the candidate of step 3 and the subsector integrals it
   brings, the integral of step 4. A reduction with this pool answers the question at one point; the gate
   then decides. If the targeted candidate fails, say why (which entry stays, which factor), revise the
   reading, and only after that widen the pool.

The structural reading proposes; the gate proves. A generic search is the last step before a flag, never the
first, and goes through a timed pilot.

## What pole-free does not give

- Pole-free and honest is not ε-form. Elliptic and higher-genus sectors keep ε⁰ pieces; second-kind and
  derivative masters give ε² couplings. A uniform ε^k cannot remove mixed ε¹/ε² couplings when the shifts are
  inconsistent around a cycle (`PFBRescaleSearch` reports the cycle).
- Pole-free and honest is not uniform weight. The gate does not judge det T: a (1 + aε) weight on a master shows only
  where the DE shows it, as poles in the rows that couple to that master. A weight on a master that no row couples to
  (a top sector's, say) raises the powers of ε in its row and nothing else, and passes; a weight the starting basis
  carried there stays unseen too.
- A uniform ε^k shifts all powers of an entry together, so it cannot bring an entry spanning ε⁻¹ to ε² within
  [ε⁰, ε²]: lifting the negative power puts it at ε³. Only new masters narrow the span. In real systems such
  entries made rung 1 infeasible within ε² where the uncapped search needed ε⁵; those rows go to the source test
  (ε = 0 as a pole), and to rung 8 when the negative powers sit in the own block. `PFBRescaleSearch` still reports the smallest cap that would do (`"MinimalCap"`), for the user.
- A pole-free maximal-cut block does not certify the maximal-cut basis: several maximal-cut bases related by
  ε-dependent changes all have pole-free blocks, and only some extend to a pole-free DE.
- Test against the actual lower bases, never stand-ins: a check against other lower masters can pass while
  the real system fails.

## Verification

A change touches the slice exactly: rows of other masters through A_rS − A_rm λ_S (in general, re-expressed in
the new basis), the rows of the new masters from the reduction of their derivatives. The slice is never
regenerated during a run. The full DE is regenerated once at the end, with the exported masters, and its
census confirms the result.

The integrals are homogeneous, so every master I = ρU of one mass dimension w satisfies Σ_X d_X X ∂_X I = w I
(d_X the dimension of the invariant X). On a slice this reads Σ_X d_X X R_X = diag(w): the root-free frame leaves
the off-diagonal entries as they are and its diagonal carries dlog ρ, so w is the weight of the full master. The
gate checks it on the rows of the new masters, and `import_slice.wls`, `local_slice.wls` and `calibrate.wls` on
the slice or the reduction (`PFBEulerCheck`). It needs the derivative in every invariant of non-zero dimension, so
a slice with the unit scale set to 1 cannot be checked this way. What can always be checked is the weight of each
definition (`PFBMasterWeight`): a master that mixes mass dimensions has a missing or wrong prefactor.
