# Formats

## family.wl

One Mathematica file that evaluates to an Association. Everything else is derived from it. The template is
`templates/family.wl`; here is an abridged example with a linear (eikonal) propagator and a dependent momentum:

```mathematica
<|
 "Name"                 -> "wline",                  (* the family symbol in j[wline, ...] *)
 "LoopMomenta"          -> {k1, k2},
 "ExternalMomenta"      -> {p, k, n},                (* only the INDEPENDENT external momenta *)
 "MomentumConservation" -> {q -> p - k - n},         (* optional: dependent momenta in terms of the independent ones *)
 "ScalarProducts"       -> {p^2 -> m2, k^2 -> 0, n^2 -> 0, p k -> s/2, p n -> m2, q^2 -> q2},
 "Propagators"          -> {                          (* this order is the index order of j[wline, a1, ..., aN] *)
    <|"Type" -> "Linear",    "Momentum" -> k1, "Vector" -> n, "Constant" -> w|>,    (* k1.n - w *)
    <|"Type" -> "Quadratic", "Momentum" -> k1 - p, "Mass2" -> m2|>,                 (* (k1-p)^2 - m2 *)
    <|"Type" -> "Quadratic", "Momentum" -> k1|>,                                    (* Mass2 is 0 unless given *)
    ...},
 "Invariants"           -> <|m2 -> 2, s -> 2, q2 -> 2, w -> 2|>,   (* every symbol with its mass dimension *)
 "UnitScale"            -> m2,                        (* set to 1 in the symbolic steps (FiniteFlow, exported DE) *)
 "D0"                   -> 4,                         (* d = D0 - 2 eps *)
 "Masters"              -> "path/to/kira/results/wline/masters",   (* optional: a Kira masters file or {j[...], ...} *)
 "TopSectors"           -> {"j11110000"},             (* optional: the lines that are propagators, ISPs left out; see below *)
 "Graph"                -> {...},                     (* optional, for the drawing; see below *)
 "MomentumDimensions"   -> <|n -> 1|>,                (* optional; every momentum has dimension 1 by default *)
 "Letters"              -> {m2 - s, s - q2, ...}      (* optional: the alphabet, for the gate's letter check *)
|>
```

A few rules:

- A product of momenta means a dot product: `p k` is `p·k` and `k1^2` is `k1·k1`. The scalar-product rules may
  use dependent momenta (`q^2 -> q2` above), and together they must fix every product of two independent
  external momenta.
- The propagators plus the ISPs must number exactly `L(L+1)/2 + L E` and form a basis of the scalar products
  that involve loop momenta.
- `"TopSectors"` lists the top sectors of the family (sector names, Kira ids or 0/1 lists): the lines that are
  propagators, without the ISPs. Only the whole-family Kira run of `find_masters.wls` needs them, when there is no
  masters list. Without the key, the internal lines of `"Graph"` form the top sector; without either, every line
  does, so the ISPs count as propagators and Kira reduces a much larger family, whose sectors with ISP lines are not
  sectors of this one. The validation prints the top sectors and where they came from.
- A linear propagator is `Momentum·Vector - Constant`, which is Kira's `bilinear` convention. The momentum can
  combine loop momenta (`k1 + k2`). The constant has the same mass dimension as the product.
- Some names are reserved (`$MCBReserved`): `j`, `eps`, `z`, `d`, `x`, and the variable names of the generated
  `AnalysisMasters.m` (`fam`, `sector`, `pts`, `reps`, `cd`, `cut`, `nmi`, `cr`, `cands`, `red`, `res`, `basis`,
  `labels`, `provenance`, `check`, `record`, `rung`, `old`, `chosen`, `flags`, `adopt`, `status`, `steps`, `written`,
  `current`). Mathematica's own symbols (`E`, `I`, `N`, `D`, `K`, ...) cannot be
  used either.

`MCBReadFamily` turns the file into a family object (propagator expressions, the external scalar products
`ExtSP`, the map from loop scalar products to propagators `SPtoD`, the Gram matrix), and `MCBValidateFamily`
runs the checks listed in section 1 of `reference/workflow.md`.

### Graph (optional)

A list `{{vertexA, vertexB, propagatorIndex}, ..., {vertex, externalMomentum}, ...}` describing the graph of
the whole family: internal lines first (linear propagators included, drawn as Wilson lines), then the
external legs. A sector is drawn by contracting the lines it does not contain. Without `Graph`, the drawing
tries to rebuild each sector's graph from momentum conservation; that usually works, and the picture says
which of the two routes it took.

## paths.wl

```mathematica
<| "BaikovPackage" -> ".../BaikovPackage.m", "DlogBasis" -> ".../DlogBasis.wl",
   "FiniteFlow" -> ".../finiteflow/mathlink/FiniteFlow.m", "FiniteFlowLibrary" -> "<the folder with fflowmlink.so>",
   "LiteRed" -> ".../LiteRed2023.m", "LiteIBP" -> ".../finiteflow-mathtools/packages/LiteIBP.m",
   "INITIAL" -> ".../INITIAL.m", "Libra" -> ".../Libra.m",
   "Fuchsia" -> ".../fuchsia", "kira" -> ".../kira", "fer64" -> ".../fer64" |>
```

Anything you leave out is looked for automatically: with `FindFile`, in `$UserBaseDirectory/Applications`, in
a few usual folders under `$HOME`, on the `PATH`, in `$FERMATPATH`, and in environment variables named
`MCB_<TOOL>` (for example `MCB_BAIKOVPACKAGE`). A `paths.wl` sitting next to `run.wl` or `family.wl` is picked
up without being named. The template is `templates/paths.wl`.

## run.wl

```mathematica
<| "Family" -> "family.wl", "OutputDir" -> Automatic,      (* Automatic means <family dir>/<Name>_analysis *)
   "Sectors" -> All,                                       (* or a list like {"j011110100", 94, {0,1,1,...}} *)
   "Skip" -> {},                                           (* step names, see below *)
   "Points" -> Automatic, "Seed" -> 1,                     (* the two points of the Kira check (first pass and check_basis.wls) *)
   "TimeLimits" -> <|"LS" -> 600, "Sector" -> 900, "FiniteFlow" -> 3600, "Kira" -> 3600, "Baikov" -> 120, "PicardFuchs" -> 300|>,
   "MemoryLimits" -> <|"Kira" -> Automatic, "FiniteFlow" -> Automatic|>,   (* GB *)
   "Parallel" -> Automatic,                                (* queues of run_all.sh (runs without an agent); Automatic follows the licence *)
   "AutoPass" -> <|"nd" -> 2, "nt" -> 2, "w" -> 3|>,       (* any key of $MCBDefaultOptions; "TimeLimits" sets "tlim" and "budget" *)
   "KeepScratch" -> False,                                 (* True keeps the Kira, self-test and FiniteFlow working folders *)
   "Paths" -> Automatic |>
```

The time limits are in seconds. `"LS"` bounds one candidate search (the leading singularities get half of it),
and `"Sector"` bounds all the candidate searches of one sector in the automatic pass: each search gets at most
the time that is left, and once the budget is used up the pass keeps the best basis it has and says so in `flags`.
`"Kira"` bounds each Kira run, `"FiniteFlow"` each step of the FiniteFlow check (the environment variable
`MCB_FF_TIMELIMIT` overrides it), `"Baikov"` the
construction of the representations, and `"PicardFuchs"` the Picard-Fuchs step of one sector (its label is then
`not computed`). The memory limits are in GB, on the process and everything below it: `"Kira"` for each Kira run
(Fermat included; `Automatic` gives it 90% of what the kernel's own limit leaves, so that Kira is stopped before the
kernel is), `"FiniteFlow"` for each step of the FiniteFlow check (`MCB_FF_MEMORY` overrides it; `Automatic` is the
default of `bin/ws`); `None` means no limit. A Kira run or a step stopped at a limit says which, and the sector's
check fails with that message. The kernels themselves get their limits from `bin/ws` (`--timeout`, `--memory`,
`MCB_TIME_LIMIT`, `MCB_MEMORY_LIMIT`; `bin/ws --set` while they run); `limits.md` explains them all. Relative
paths, `"."` included, are taken relative to the folder of `run.wl`.

The step names that can be skipped (`$MCBSteps`) are `preflight`, `validate-family`, `find-masters`, `baikov`,
`picard-fuchs`, `candidates`, `kira-check`, `escalate`, `literature`, `d0-shift`, `agent-candidates`,
`algorithms`, `finiteflow`, `dlogbasis-crosscheck`, `draw` and `reports`. Skipped steps are listed in
`basis.m` under `"skipped"` and appear as "skipped by user" on the pages.

## The sector folder `j<pattern>/`

`<pattern>` is the sector's list of zeros and ones (`SectorName`); the Kira id is `Σ s_i 2^(i-1)` (`SectorID`).

| file | content |
|---|---|
| `basis.html` | the page a person reads, with a drawing of the sector |
| `masters.m` | **only** the list of basis integrals, as exact expressions `eps^k Sqrt[R] (Σ c j)` |
| `notes.md` | the reasoning behind the choices (paragraphs, `# ` headings, `` `code` ``), shown under "How this basis was found" |
| `AnalysisMasters.m` | the analysis as a readable script, written by the first pass, by `new_sector.wls` or (for an adopted basis) by `check_basis.wls`, and then edited by the agent; it replays the steps that built its candidates (`steps`, `MCBReplayCandidates`) and compares its basis with the one it was written for (`written`); `.AnalysisMasters.generated` holds the hash of the version as generated, and `AnalysisMasters.auto.m` appears when the first pass reran after the script was edited |
| `basis.m` | everything else about the basis (below) |
| `attempts.m` | the history, one Association per entry: `date`, `rung`, `what`, `outcome`, `time`; entries are only ever added. `rung` is a rung of the ladder, or `"tie-breaker"` (with a `reason`) for a choice between equally good bases |
| `finiteflow/` | after the analytic check, `verdict.m`, `DE.m` and `ffinfo.m` (below) |
| `refs/` | papers or notes the user leaves for the literature step |

Kira jobs run in `kira/` (`count/` for the recount of the masters, `pt1/` and `pt2/` for the reductions of the
candidates, `check/` for the gate) and are deleted as soon as their results are read. A job that failed or left
integrals unreduced is kept, with its `kira.out`.
With `"KeepScratch" -> True` (or `MCB_KEEP_SCRATCH=1`) every job is kept.

### masters.m

A list `{J1, J2, ...}` where each element is `eps^k Sqrt[R] K`, with `K` a rational combination of `j[...]`.
All terms of one element share the same square root. `MCBSplitMaster[J]` turns an element back into
`<|"r2" -> R, "K" -> eps^k K|>`, keeping `K` as it is written. An element may be written as prefactor × pieces,
`eps^k Sqrt[R] p (q1 j[...] + q2 j[...] + ...)`: the gate never expands `p` into the pieces or puts a coefficient
over a common denominator (see pitfalls.md, "Large coefficients").

### basis.m

| key | content |
|---|---|
| `sector`, `name`, `id`, `family`, `props` | the sector as a 0/1 list, its name `j<pattern>`, its Kira id, the family's name, and its propagators as text |
| `status` | `eps-form`, `eps-polynomial`, `eps-polynomial (dlog search incomplete)`, `failed` or `skipped by user` |
| `range` | the lowest and highest power of ε in the maximal-cut DE (`{1, 1}` for ε-form) |
| `geometry` | `class`, `text`, `nvars`, `degrees`, `genus`; for curves also `P`, `degree`, `punctures` |
| `representation` | `kind`, `order`, `isp`, `vars`, `cutpolys`, `cutpows`, `kinNorm`, `Rz`, `Pr`, `prefRat`, `D0` |
| `masters` | for each element: `definition`, `normalisation` (`"rational"` or the radicand), `epsPure` and `epsPureDetail` (whether its integrand times the rational part of the Γ prefactor is ε^m times something free of ε, `MCBElementPurity`, or, for an element built ε-pure, "eps-pure as built": `SKILL.md`, "Purity"; `check_basis.wls` and `AnalysisMasters.m` keep the verdict of an element whose definition is unchanged, `MCBKeptPurity`; `True`, `False` or `Missing`), `purityRule` (the version of that rule, `$MCBPurityRule`: a verdict of another version is judged again), `epsPowerWritten` (the lowest power of ε among its terms as written), `epsPowerMixed` (True when its terms start at different powers), `epsPowerRelative` (the relative power `k` the DE check asked for, already included in `definition`; 0 when the basis was given normalised), `label`, `provenance` |
| `epsPowerCommon` | always "undetermined": the maximal cut fixes the powers of ε only relative to each other, so the common power of the sector is a convention |
| `nMastersCut`, `nMastersList`, `extraMasters`, `cutMasters` | the recount on the cut compared with the user's list |
| `points` | the kinematic points of the Kira check |
| `kiraVerdict` | `status`, `k`, `range`, `pattern` (the ε profile of every entry, per invariant), `invariants` (their order in `pattern`), `message`, and `A`: the DE matrices at the first point, `<|X -> A_X|>`, in the rational frame, for exactly the expressions in `masters.m` |
| `finiteflowVerdict` | a copy of `finiteflow/verdict.m`, or `Missing["NotRun"]` |
| `checks` | the gate's checks (`MCBBasisChecks`), each `<|"Name", "Pass", "Detail"|>`: `rules` (one power of ε per integral, no ε denominator, rational coefficients, one square root), `letters` (with `"Letters"`), `weights` (one mass dimension shared by the elements; the entry also holds `Weights`), `euler` (Σ_X d_X X A_X = diag(weights) at every point), and on a non-dlog sector (status `eps-polynomial`, or a Picard-Fuchs label that is not polylogarithmic) `all-dot` (fails when every element is dotted: such a basis is likely to carry a weight between sectors; `flags` then says so, and a basis with an undotted element wins a tie, `MCBAllDotCheck`). Only `euler` decides: a DE that breaks it is `failed`. The others are reported for the pole-free skill |
| `classification` | the Picard-Fuchs step's record: `label`, `reason`, the operator and its block, the singular points, the checks against the Baikov curve and Kira; every key is in `reference/picard-fuchs.md` ("Output"). `Missing["NotRun"]` for a sector done before the step existed (`bin/picard_fuchs.wls` adds it). A record written without one keeps the one already in `basis.m` (`MCBKeepClassification`) |
| `repeatedGeometry` | when the sector is another one at mapped kinematics (`MCBRepeatedGeometry`): `sameAs`, its `status`, `lines`, `invariants`, `mapped` (whether its basis could be mapped), `outcome` (what the mapped basis gave) or `note` (why it was not mapped) |
| `dlogBasisCheck` | the DlogBasis cross-check, when it ran: per element `label`, `LS`, `normalisation`, each in the representation the element was built in (else the first rational one that expresses it; "not checked" when none does) |
| `flags`, `retryHints` | notes on what needs attention, and, for a flagged sector (`MCBFlaggedQ`, `SKILL.md`), the rungs not tried yet |
| `skipped`, `toolsUsed`, `citations`, `time`, `date` | `toolsUsed`: every tool and method the run's ledger credits to the sector (any kernel, earlier records, imported and declared ones included); `citations`: their references. Both are kept for older readers: the pages and `CITATIONS.md` read the ledger (below), where the papers are too |

### A basis file for `check_basis.wls`

A list. Each element is either an expression as in `masters.m`; or `J -> "label"`; or
`<|"definition" -> J, "label" -> "...", "provenance" -> "..."|>` to give each element its own label and provenance.
Elements without a label keep the one they have in the current `basis.m`, if the definition matches.

### Candidates in memory

`<|"r2" -> R, "K" -> combination, "label" -> ..., "strict" -> True | False, "weight" -> {n, max, total},
"provenance" -> "auto" | "agent" | "literature ..." | "INITIAL" | ..., "priority" -> n|>` stands for
`Sqrt[R] K`. Before a search, `MCBCandidatePurity` adds `"pure"` (`True`, `False` or `Missing[...]`) and
`"pureDetail"`: `MCBElementPurity`'s verdict, except that a `"strict"` candidate is `True`, "as built" when its
integrand alone does not show it, provided the Γ prefactor of its representation is a power of ε times a number. The search puts
the ε-pure candidates first (`MCBOrderKey`), and `basis.m` takes its `epsPure` from the same verdict. Build your own with `MCBCandidate[fam, sector, K, <|"r2" -> R, "label" -> ...|>]`.

## Files of a whole run

For the user: `summary.html` (flagged sectors first), `masters_all.m` (`{sector, i, J}` for every basis
integral) and `CITATIONS.md` (what to cite, below). Bookkeeping: `run_info.m` (the resolved settings, through
which scripts find the run from a sector folder), `sectors.txt` (name, Kira id and number of propagators of each
sector, fewest propagators first), `geometry.m` (the sectors that are an earlier one at mapped kinematics:
`<|name -> <|"sameAs", "lines" -> {line -> line, ...}, "invariants" -> {X -> Y(X), ...}|>|>`, from
`MCBGeometryGroups`), `citations.m` (the ledger, below), and `masters_found.m` when Kira had to find the masters. A
batch run with `run_all.sh` adds `auto_pass_*.log`. The scaling self-test runs in `selftest/` and the
whole-family Kira run in `kira_masters/`; both are deleted once read. The preflight's table is kept per machine,
in `~/.cache/maximal-cut-basis/preflight.log`.

### The ledger of tools and papers

`citations.m` holds one Association per line, appended when a use happens, in whichever kernel or process, and
never rewritten (`core/README.md`, "Citations"; readers drop repeats):

- a tool or method: `kind` "tool", `tool` (a name of the registry `$MCBTools`), `sector` (a sector name, or "whole
  run"), `step` (what ran: "first pass", "check_basis", "picard_fuchs", "FiniteFlow check", "declared", ...), the
  `date`, and `via` for a credit imported from another sector ("mapped from j0101", a repeated geometry);
- a paper: `kind` "paper", `reference` (authors, title, journal, arXiv number or DOI), `id` (its arXiv id, else its
  DOI), `sector`, `used` (what was taken from the paper and where it went), `result` ("used", the default,
  "adopted", "not adopted" or "not tried"), the `date`, and optionally `rung`, `outcome`, `basisKey`
  (`CoreBasisKey` of the basis it went into) and `via`.

`MCBRecordLiterature` adds a paper and writes `CITATIONS.md` again; `check_basis.wls --reference` adds one with its
`result` and `basisKey`, `--tool` a declared tool. `CITATIONS.md` has two parts. "Cite": every tool and method that
ran, and every paper behind a final basis. "Also consulted": the papers used only for a basis that was not adopted
or not tried, or that a later basis replaced (its `basisKey` is not the sector's `basis.m` any more), each with its
outcome. Papers are grouped by arXiv id or DOI, and a paper that a tool or method of the run cites is listed under
it. The sector pages show the entries of their sector, and the summary both parts. A run made before the ledger
keeps its credits: its `literature.m` and the `toolsUsed` of its `basis.m` files are read in, and its own
`LITERATURE.md` is removed when `CITATIONS.md` is first written.

## finiteflow/

After a check whose verdict is `eps-form` or `eps-polynomial` and agrees with Kira, or is `not applicable`, the
folder keeps `verdict.m`, `DE.m` and `ffinfo.m`; the scripts, the identities and the logs are deleted and written
again by the next run. Any other check keeps everything, among it
`elements.m` (each element as `{{integral, coefficient as written}, ...}`, its square root and phase taken out),
`prefacts.m` (the radicands) and `derivatives.m` (the derivatives of single integrals that LiteIBP cannot take).

`verdict.m`: `<|"status" -> "eps-form" | "eps-polynomial" | "rational" | "failed" | "not applicable" (no invariant left once the unit scale is 1), "k", "range", "profile",
"mode" -> "full" | "eps-slice", "invariants", "slicePoint", "kiraComparison", "message"|>`. `kiraComparison`
is `<|"status" -> "agree" | "disagree" | "not compared", "message", "entries"|>`, the entry-by-entry
comparison with Kira's matrices at Kira's first point. When the verdict belongs to an older basis,
`MCBReadFFVerdict` (and so every page) reports it as `<|"status" -> "stale", ...|>` instead.

`DE.m` holds `<|X -> A_X|>` for `J = Sqrt[prefacts] ut`, with the unit scale set to 1. `ffinfo.m` records what the
scripts were written for: `masters` (the basis, used to detect a stale verdict), `variables`, `unitScale`,
`phases` (1, or `I` when a phase was moved into the square root), `alpha` (each element's mass dimension over
that of the unit scale), `beta` (the same for each invariant), `kiraPoint`, `slicePoint`. While the scripts exist,
`masters.cksum` is the checksum of `masters.m` when they were written.
