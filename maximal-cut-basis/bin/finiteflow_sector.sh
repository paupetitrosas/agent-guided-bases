#!/bin/sh
# Analytic check of one sector with FiniteFlow: IBPs on the maximal cut (genIBPs.m), reduction of the
# derivatives and reconstruction of the DE (SetSDE.m), verdict and comparison with Kira (InvestigateDEQ.m,
# which also refreshes the sector's basis.m and basis.html).
# usage: finiteflow_sector.sh <sector folder>
#   seconds per step: MCB_FF_TIMELIMIT, else run.wl "TimeLimits" -> "FiniteFlow" (written with the pipeline), else 3600
#   memory per step (GB, the kernel and its subkernels together): MCB_FF_MEMORY, else run.wl "MemoryLimits" ->
#   "FiniteFlow" (written with the pipeline), else the default of bin/ws (MCB_MEMORY_LIMIT, or a share of the machine);
#   0 = none. ws --set changes either while a step runs.
# The pipeline is written again whenever masters.m changed since it was written (or with FORCE=1).
# After a check whose verdict is eps-form or eps-polynomial and agrees with Kira, finiteflow/ keeps only verdict.m,
# DE.m and ffinfo.m (the rest is written again by the next run). Anything else keeps every file for diagnosis, and so
# do MCB_KEEP_SCRATCH=1 and run.wl "KeepScratch" -> True.
# On a timeout of the full reconstruction, SetSDE.m is rerun as an eps-only slice at Kira's point.
# Every Wolfram kernel is started through bin/ws, which waits for a free licence slot.
# Exit code: 0 the verdict agrees with Kira (or the check does not apply), 1 it does not (or the DE is rational),
# 3 the pipeline failed (a step that went over its memory limit included: the message says so). The Euler relation
# is checked by the Kira gate (bin/check_basis.wls), not here.
# The last line of output is the JSON verdict (core/README.md).
set -u
verdict() {  # verdict <outcome> <exit> <message>
  printf '{"tool":"finiteflow_sector","outcome":"%s","exit":%s,"sector":"%s","message":"%s"}\n' "$1" "$2" "${dir:-}" "$(printf %s "$3" | sed 's/["\\]/\\&/g')"
  exit "$2"
}
[ $# -ge 1 ] || { echo "usage: finiteflow_sector.sh <sector folder>"; dir=""; verdict usage 2 "no sector folder given"; }
here=$(cd "$(dirname "$0")" && pwd)
dir=$(cd "$1" && pwd)
[ -f "$dir/masters.m" ] || { echo "no masters.m in $dir"; verdict usage 2 "no masters.m in $dir"; }
# a TERM or INT to this script stops the step that is running: ws then stops its kernel (bin/ws --stop does the same)
step=""
trap '[ -n "$step" ] && kill -TERM "$step" 2>/dev/null && wait "$step"; verdict error 3 "stopped by a signal"' INT TERM HUP
run() {  # run <seconds> <script> <log>
  "$here/ws" --timeout "$1" ${MEM:+--memory "$MEM"} "$2" > "$3" 2>&1 &
  step=$!; wait "$step"; rc=$?; step=""
  [ "$rc" = 137 ] && verdict error 3 "$2 stopped at its memory limit (${MEM:-the default of bin/ws} GB; MCB_FF_MEMORY or run.wl \"MemoryLimits\" -> \"FiniteFlow\" raise it); see $3"
  return $rc
}
stale=0
if [ ! -f "$dir/finiteflow/genIBPs.m" ] || [ "${FORCE:-0}" = "1" ]; then stale=1
elif [ "$(cksum < "$dir/masters.m")" != "$(cat "$dir/finiteflow/masters.cksum" 2>/dev/null)" ]; then
  echo "masters.m changed since the pipeline was written: writing it again"; stale=1
fi
if [ "$stale" = 1 ]; then
  rm -rf "$dir/finiteflow"
  "$here/ws" "$here/write_ff.wls" "$dir" > /dev/null &
  step=$!; wait "$step" || { step=""; echo "could not write the pipeline"; verdict error 3 "could not write the pipeline"; }; step=""
  cksum < "$dir/masters.m" > "$dir/finiteflow/masters.cksum"
fi
cd "$dir/finiteflow" || verdict error 3 "no finiteflow folder"
TL=${MCB_FF_TIMELIMIT:-$(cat .timelimit 2>/dev/null)}; TL=${TL:-3600}
MEM=${MCB_FF_MEMORY:-$(cat .memorylimit 2>/dev/null)}
rm -f sysinfo.m sys.m verdict.m DE.m
echo "$(date +%H:%M:%S) genIBPs.m";  run "$TL" genIBPs.m genIBPs.log || echo "  genIBPs.m failed or timed out (see genIBPs.log)"
echo "$(date +%H:%M:%S) SetSDE.m";   run "$TL" SetSDE.m SetSDE.log; code=$?
if [ "$code" = "124" ]; then
  echo "  full reconstruction timed out: eps-only slice"
  MCB_FF_MODE=slice; export MCB_FF_MODE
  run "$TL" SetSDE.m SetSDE_slice.log
  unset MCB_FF_MODE
fi
echo "$(date +%H:%M:%S) InvestigateDEQ.m"; run 900 InvestigateDEQ.m InvestigateDEQ.log
grep -E '^(verdict|compared with Kira)' InvestigateDEQ.log || true
line=$(grep '^verdict' InvestigateDEQ.log 2>/dev/null | head -1)
agree=$(grep -c '^compared with Kira: agree' InvestigateDEQ.log 2>/dev/null)
if [ "${MCB_KEEP_SCRATCH:-0}" != "1" ] && [ ! -f .keep_scratch ] && [ -f verdict.m ] &&
   { grep -q '^verdict: not applicable' InvestigateDEQ.log ||
     { grep -q '^verdict: eps-\(form\|polynomial\)' InvestigateDEQ.log && grep -q '^compared with Kira: agree' InvestigateDEQ.log; }; }; then
  find . -mindepth 1 -maxdepth 1 ! -name verdict.m ! -name DE.m ! -name ffinfo.m -exec rm -rf {} +
fi
echo "(run bin/make_reports.wls on the run folder to refresh summary.html)"
case "$line" in
  "verdict: not applicable"*) verdict pass 0 "$line" ;;
  "verdict: eps-form"*|"verdict: eps-polynomial"*)
    if [ "${agree:-0}" -gt 0 ]; then verdict pass 0 "$line"; else verdict fail 1 "$line; not in agreement with Kira"; fi ;;
  "verdict: failed"*|"") verdict error 3 "${line:-InvestigateDEQ.m did not finish}" ;;
  *) verdict fail 1 "$line" ;;
esac
