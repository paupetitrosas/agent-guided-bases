# core

What the maximal-cut-basis and pole-free-basis skills share: the licence-slot wrapper, tool configuration and
preflight, the sector records, the ledger of tools and papers (`citations.m`, `CITATIONS.md`), the HTML pages, and
the verdict every script ends with. It is not a skill of its own; both skills find it in `$SKILL_CORE` when that is
set, else next to them in the repository, through their real paths (so they also work when installed as symbolic
links).

| path | what it is |
|---|---|
| `bin/ws` | runs `wolframscript` when the licence has a free kernel slot, under a time and a memory limit; both skills' `bin/ws` forward to it. `--free-for N` (`MCB_WS_FREE_FOR`, default 5 s) and `--max-wait S` (`MCB_WS_MAX_WAIT`) set how it waits for a slot, `--limit K` (`MCB_MAX_KERNELS`) the kernel limit |
| `bin/limit` | runs any command under a time limit and a memory limit (the command and everything below it), both changeable while it runs (`--set`); `bin/ws` and every Kira run go through it, `--list` shows the jobs of both and `--stop PID` stops one; `--headroom` prints the memory (KB) the job it runs in may still use, from the job's registry entry in `MCB_LIMIT_JOB` |
| `lib/SkillCore.wl` | loads `lib/Core/Tools.wl` (the registry of tools and methods, paths, detection, loading, preflight, licence, scratch), `Records.wl` (sector files, run folder, verdicts), `Pages.wl` (template, badges, notes) and `Citations.wl` (the ledger of tools and papers, `CITATIONS.md`, the page blocks). Their functions keep the `MCB` names of maximal-cut-basis (`MCBLoadPaths`, `MCBLimitCommand`, `MCBJobLimits`, `MCBWriteBasis`, `MCBMarkToolUsed`, `MCBRecordLiterature`, ...), next to `CoreVerdict`, `CoreJSON`, `CoreRunFolder`, `CorePage`, `CoreBadge`, `CoreMarkdown`, the `Core...Citation...` functions below, `$CoreRoot` and `$CoreVersion` |
| `tests/citations.wls` | planted tests of the ledger, its reader and what is written from it: `core/bin/ws core/tests/citations.wls` |
| `templates/` | the page template and stylesheet of every HTML page: `CorePage` fills `{{TITLE}}`, `{{STYLE}}`, `{{BODY}}` and `{{GENERATED}}` of `page.html.tmpl`. The page loads MathJax from a CDN, so its TeX shows only with a network connection |

`MCBWriteBasis` writes every `basis.m` through the hook `$CoreBasisMerge[dir, record]`, which keeps what a skill
wants kept from the `basis.m` it replaces (by default, nothing). maximal-cut-basis sets it to
`MCBKeepClassification`: a record written without the Picard-Fuchs classification keeps the one already there. The
per-machine files (the kernel limit, `preflight.log`, the licence lock, the job registry) are in
`$XDG_CACHE_HOME/maximal-cut-basis`, else `~/.cache/maximal-cut-basis`.

## Citations

Every use of a tool, a method or a paper is appended, when it happens, to the run's ledger `<run>/citations.m`
(the run folder is `CoreRunFolder[dir]`), one Association per line, and nothing in it is ever rewritten: rewriting
`basis.m`, resetting a kernel's marks or running in another process cannot lose a credit. `CoreReadCitations[run]`
is the one reader: it dedupes, reads the records of older runs (`literature.m`, the `toolsUsed` of `j*/basis.m`, and
the `status.m` of a pole-free run's jobs), applies the later outcomes of pole-free changes, and puts each paper under
"cite" (behind the final result) or "consulted" (rejected, declined, not adopted, not tried, replaced by a later
basis). It is memoised on the dates and sizes of the files it reads. `CoreWriteCitations[run]` writes
`CITATIONS.md` from it, with the same two parts, and removes the skill's own older `LITERATURE.md`;
`CoreCitationsHTML` and `CoreSectorCitationsHTML` are the blocks of the pages.

- A tool is credited when it produced something, not when it was loaded (`MCBLoadTool` and `MCBPreflight` mark
  nothing). `MCBMarkToolUsed[tool]` appends a use to the run and sector of `$CoreCitationContext`
  (`CoreCitationContext[dir, sector, step]`, scoped with `CoreWithCitationContext`); without a context the mark waits
  for the first one. A job or a program run elsewhere is recorded with `CoreRecordTool[dir, tool, step]`, a paper with
  `CoreRecordPaper[dir, <|"reference", "used", ...|>]` (`MCBRecordLiterature` is the older name), the outcome of a
  pole-free change with `CoreRecordOutcome`, and the credits of a sector taken from another run (or from another
  sector) with `CoreImportCitations`.
- The names are those of the registry `$MCBTools`: tools, the methods (Baikov, CanonicalDE, Tarasov, PicardFuchs)
  and the programs that run outside the toolkit (kind `"external"`: SOFIA, ore_algebra). `CoreToolKey` reads a
  name in any case or by its display name ("Kira", "Fermat"); an unknown name is refused with the list of known
  ones, never dropped. Its citations are the checked ones; correct them there.
- An imported credit follows what it went into: `CoreImportCitations[..., "BasisKey" -> key]` (a maximal-cut-basis
  record), `"Change" -> id` (a pole-free change) or `"Start" -> labels` (a pole-free sector's starting masters) stamps
  every copy, tools included, and the reader cites it only while that basis is current, that change accepted (or
  pending) or one of those masters left; otherwise it is under "Also consulted", with the reason. The tools a run ran
  itself are always cited.
- An entry is `<|"kind" -> "tool", "tool", "sector", "step", "date"|>`, `<|"kind" -> "paper", "reference", "id",
  "sector", "used", "result", "date"|>` (optional `"rung"`, `"outcome"`, `"change"`, `"basisKey"`) or `<|"kind" ->
  "outcome", "change", "result", "outcome", "date"|>`; an imported one has `"via"`, and the stamps `"basisKey"`,
  `"change"` or `"start"` of what it went into. The sector is `j0101`
  (maximal-cut-basis), `fam/j0101` (pole-free-basis, `CoreCitationSector[dir]` gives either) or "whole run". A
  pole-free reduction job, which runs without the core, appends lines of the same form
  (`pole-free-basis/lib/PFB/JobCitations.wl`).
- Papers are grouped by `CorePaperId` (the arXiv id, else the DOI, else the reference normalised; references that
  share any id are one paper, except that a reference naming two papers links neither), and one that shares an id with
  a cited tool or method is shown under it. `CoreBasisKey` is the key of a maximal-cut basis a paper entry
  may carry. `CoreSectorCitations[run, sector]` gives one sector's entries, `CoreCitationGroups[run]` what
  `CITATIONS.md` shows and `CoreCiteMarkdown[run]` its "Cite" part (for `CHANGES.md`). The older names
  `CoreLiteratureSummary`, `CoreLiteratureList`, `MCBReadLiterature` and `MCBWriteLiterature` still work.

## The verdict

Every script of both skills except `bin/run_all.sh` ends with one line of JSON on standard output and an exit code
that matches it:

```json
{"tool": "check_basis", "outcome": "pass", "exit": 0, "sector": "j11100", "status": "eps-polynomial", ...}
```

The other fields depend on the tool; values that are not plain JSON are written in Mathematica `InputForm`, missing
ones as `null`. In a script, `CoreVerdict[tool, outcome, data]` prints the line and exits.

| outcome | exit | meaning |
|---|---|---|
| `pass` | 0 | the step did what it is for: a usable basis, an exact calibration, a pole-free census, a written job |
| `fail` | 1 | the step ran, and the answer is no: a basis that fails a check, a refused slice, a census with poles, a job refused for memory |
| `usage` | 2 | bad input: arguments, files, a missing run or slice |
| `error` | 3 | a tool failed: Kira, FiniteFlow, a reconstruction |
| `rerun` | 4 | do what the message asks, then run the same command again (a reduction that added host sectors; for `simplify.wls`, jobs to run, a budget to agree or a change to approve) |
| `timeout` | 124 | `bin/wait_job` only: the wait ended at its `--timeout` or `--stall` limit, and the job goes on |

`bin/ws` itself exits with 75 when it gave up waiting for a licence slot (`--max-wait`), 124 when the script went
over its time limit and 137 when it went over its memory limit (`bin/limit` stopped it; a line on standard error
says which, and how to raise it). `bin/ws` and `bin/limit` exit with 130 or 143 when a signal stopped them, and the
job with them.

## Time and memory limits

`bin/limit` runs a command under a time limit and a memory limit, the memory of the command and of everything below
it added up, and stops the whole tree at either. `bin/ws` runs every Wolfram script through it (24 h and an equal
share of 90% of the machine's memory per licence slot by default), and so do Kira runs and pole-free reduction jobs,
with limits of their own. `bin/ws --list` shows every job with its limits, `--timeout` and `--memory` (or
`MCB_TIME_LIMIT`, `MCB_MEMORY_LIMIT`) set them, and `bin/ws --set PID` changes them while a job runs.
`maximal-cut-basis/reference/limits.md` describes them in full: every process and its defaults, how to set and
change them, what a stopped job leaves behind, and how to choose a limit.
