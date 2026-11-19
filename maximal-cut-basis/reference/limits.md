# Time and memory limits

Every process of both skills that can run for long or take much memory runs under a time limit and a memory
limit. A job that goes over either is stopped. Without a memory limit, a runaway kernel takes memory until the
system's out-of-memory killer stops some process, and that process may be another session's job or the agent
itself.

This page says how the limits work, which processes have them and with what defaults, and how to see and change
them. It also says what happens when a job is stopped, and how to choose a limit. It covers both skills: the
scripts are in the shared `core/` folder, and the pole-free-basis skill uses the same ones.

## How a limit works

`core/bin/limit` runs a command and checks it every 2 seconds:

- **time**: the wall-clock seconds since the command started;
- **memory**: the resident memory of the command and of every process below it, added up. That includes the
  kernel, the subkernels it launches (LiteIBP and FiniteFlow do), Kira and Fermat.

When either is over its limit, `limit` stops the command with everything below it: TERM, then KILL after
5 seconds. It writes one line on standard error that says which limit was exceeded and how to raise it, and exits with:

| exit | meaning |
|---|---|
| 124 | stopped at its time limit |
| 137 | stopped at its memory limit (also the code of a process the system's out-of-memory killer stopped) |
| anything else | the command's own exit code |

`bin/ws` runs every Wolfram script through `limit`, once the script has a licence slot: the wait for a slot does
not count. Both skills' `bin/ws` forward to `core/bin/ws`.

Three consequences of checking every 2 seconds:

- A job that ends within 2 seconds is never stopped.
- Memory that grows fast can overshoot the limit by what it gains in 2 seconds. Keep the limit below the memory
  that is actually free, not equal to it.
- The resident memory of each process counts the libraries it shares with the others (the kernel's code, for
  example), so a kernel with four subkernels shows a few hundred MB more than it really holds.

## What has limits, and the defaults

| process | time limit | memory limit | set with |
|---|---|---|---|
| any script started with `bin/ws` (every kernel of both skills) | 86400 s (24 h) | 90% of the machine's memory divided by the kernel limit of the licence, by four at most (6.9 GB on a 15.3 GB machine with 2 kernels) | `bin/ws --timeout S --memory GB`; `MCB_TIME_LIMIT`, `MCB_MEMORY_LIMIT` |
| one Kira run of maximal-cut-basis (the gate, the first pass, the recount of masters, the scaling self-test; also the maximal-cut check of pole-free rung 8, which the pole-free `run.wl` cannot set) | 3600 s | 90% of what the kernel's own job may still use | `run.wl` `"TimeLimits" -> <\|"Kira" -> S\|>` and `"MemoryLimits" -> <\|"Kira" -> GB\|>`; in a script `$MCBKiraTimeLimit`, `$MCBKiraMemoryLimit` |
| each step of the FiniteFlow check: `genIBPs.m`, `SetSDE.m` (`InvestigateDEQ.m` always gets 900 s) | 3600 s | the default of `bin/ws` | `MCB_FF_TIMELIMIT`, `MCB_FF_MEMORY`; `run.wl` `"TimeLimits"` and `"MemoryLimits"` -> `"FiniteFlow"` |
| a pole-free reduction job (the command of `PFBSubtreeCommand`) | 86400 s | `MaxGB`, else the default of `bin/ws` | `"TimeLimit"` and `"MaxGB"` in `job.m`, from the pole-free `run.wl` |
| Kira at the slice point of a pole-free reduction job | half of the time the job has left (at least 60 s) | 90% of what the job may still use | through the job's limits (`PFBKiraTimeLimit`) |

Times are in seconds (a decimal is cut to whole seconds), memory in GB. In `run.wl`, `None` means no limit and
`Automatic` the default; elsewhere, 0 means no limit.

`MCB_TIME_LIMIT` and `MCB_MEMORY_LIMIT` replace the defaults for every call of `bin/ws` (and `core/bin/limit`) that
does not give its own limit, the calls inside `bin/run_all.sh` and `bin/finiteflow_sector.sh` included. The memory
share uses the kernel limit of `bin/ws`. That is `MCB_MAX_KERNELS`, else the value `bin/preflight.wls` cached in
`~/.cache/maximal-cut-basis/max_kernels`, else 2. So when every licence slot runs a job at the default limit, the
jobs together hold at most 90% of the memory. The share is never smaller than a quarter of that: a licence with more
than four slots, or without a limit (cached as 1000), would otherwise leave each job too little to run.

Steps inside a kernel have only a time limit of their own, in `run.wl` `"TimeLimits"`: `"LS"`, `"Sector"`,
`"Baikov"` and `"PicardFuchs"` (`formats.md`). Their memory counts toward the kernel's limit. `bin/wait_job
--timeout` limits the wait for a pole-free job, not the job itself.

## Seeing the limits

`bin/ws --list`, from either skill, lists the running jobs of every session on this machine (`core/bin/limit
--list` is the same):

```
PID      running  memory  limits (time, memory)  folder and command
1843925     312s    2.1GB  86400s, 6.9GB          /home/me/box: wolframscript -file .../run_sector.wls run.wl j1111
```

`PID` is the number that `--set` and `--stop` take. A job that an older `bin/ws` started shows `-, -`. It has no
limits, and they cannot be changed.

Inside a kernel, `MCBJobLimits[]` gives the limits of the job the kernel runs in, and `MCBMemoryHeadroom[]` the
memory in GB the job may still use.

## Setting the limits when a job starts

```sh
bin/ws --timeout 7200 --memory 4 bin/run_sector.wls run.wl j1111    # one kernel: 2 h, 4 GB
MCB_TIME_LIMIT=172800 bin/run_all.sh run.wl                           # every kernel of a batch run: 48 h
MCB_FF_MEMORY=10 bin/finiteflow_sector.sh <run folder>/j1111         # each FiniteFlow step: 10 GB
core/bin/limit --timeout 600 --memory 2 -- python3 my_script.py      # any other command
```

In `run.wl`, for Kira and the FiniteFlow check; keys left out keep their defaults:

```mathematica
"TimeLimits"   -> <|"Kira" -> 7200, "FiniteFlow" -> 10800|>,
"MemoryLimits" -> <|"Kira" -> 3, "FiniteFlow" -> 10|>
```

The scripts that start from `run.wl` (`bin/run_sector.wls`, `bin/auto_pass.wls`, `bin/run_all.sh`) read these
keys and record them in the run folder's `run_info.m`, from which `bin/check_basis.wls` reads them. An
`AnalysisMasters.m` sets `$MCBKiraTimeLimit` and `$MCBKiraMemoryLimit` near its top: edit them there. A kernel of
your own sets them before the call. The FiniteFlow limits are written into `finiteflow/` with the pipeline, so for
a pipeline that already exists use `MCB_FF_TIMELIMIT` and `MCB_FF_MEMORY`, or write the pipeline again (`FORCE=1`).
To run another heavy command from a kernel under limits, use `MCBShell[MCBLimitCommand[seconds, GB] <> "command", dir]`.

**Pole-free reduction jobs.** Put `"TimeLimit"` and `"MaxGB"` in the pole-free `run.wl` for every job. `MaxGB` is
then both the runner's cap (it refuses to learn when its prediction exceeds it) and the hard limit of `bin/ws`.
To change one job, run `bin/subtree_job.wls` again with the same arguments after editing `run.wl`, or call
`PFBSubtreeJob` with the same specification and the new limits: that only updates the resource settings of
`job.m`. Then use the command it prints, since the command carries the limits. Expansion, relation and analytic
jobs take theirs from the job they come from.

## Changing the limits of a running job

```sh
bin/ws --set 1843925 --timeout 14400              # this job: 4 h in total
bin/ws --set 1843925 --memory 9                   # and 9 GB
```

The change takes effect at the next check, within 2 seconds. The time limit counts from the start of the job:
`--timeout 14400` on a job that has run for 3 hours gives it one more hour. Lowering a limit below what the job
already uses stops it at the next check.

For a pole-free job, `--set` holds for the run of the command that is going on. When the command runs again
(after host sectors were added, or after a stop), it uses the limits written in its command, so change `job.m`
too (previous section) when the change should last.

## When a job is stopped

- **`bin/ws` or `core/bin/limit`**: exit 124 or 137, and on standard error
  `limit: stopped after 7200 s, its time limit (...)` or
  `limit: stopped at 7.3 GB, above its memory limit of 6.9 GB (...)`.
- **A Kira run**: `kira.out` ends with that line, the kernel prints `!! Kira stopped at its time limit of ...`
  (or memory limit), and the check fails with "Kira failed (see <folder>)". The Kira folder is kept. In a pole-free
  reduction job, FiniteFlow reduces the slice point instead: `status.m` says why (`"KiraFallback"`), and
  `kira_fallback.m` keeps later runs of the job from trying Kira again.
- **`bin/finiteflow_sector.sh`**: a full reconstruction stopped at its time limit falls back to the eps-only
  slice, as before. A step stopped at its memory limit ends the check with exit code 3 and the message
  "SetSDE.m stopped at its memory limit (...)".
- **A pole-free reduction job**: `run.log` ends with that line. `bin/wait_job` exits with 3 and the message
  "killed: stopped at ...", and `PFBSubtreeStatus` reports `killed` with the same reason. The finished points are
  kept: run the command again and the job resumes at the first missing point. The runner also plans under its
  own memory limit. Before learning, it refuses a job whose prediction does not fit (`refused`, with `LimitGB` in
  `status.m`). Before each point, it lowers its threads until the prediction fits.

## Choosing a limit

- **Time.** Take it from a pilot: measure a small case and extrapolate (the `timing-discipline` skill). Give a
  job more time only while it makes progress, that is while its log or its status changes. A job that is stuck
  will not finish with more time.
- **Memory.** Raise a memory limit only when the machine has the memory. Check `free -g`, the memory column of
  `bin/ws --list` (other sessions' jobs included), and for reductions the memory model of the pole-free preflight.
  Never ask for more than the memory that is free plus what the job already holds, and leave room for the other
  sessions and for the agent's own process. When the memory is not there, make the job smaller instead: lower
  seeds (rank, dots), fewer points, a smaller pool, the roots split into several jobs, fewer FiniteFlow kernels.
  Or run it on a larger machine: pole-free job folders are self-contained.
- **No limit.** A memory limit of 0 leaves the machine to the out-of-memory killer. Do not set one.
- **Tell the user** whenever you change a limit, by how much, and why.
