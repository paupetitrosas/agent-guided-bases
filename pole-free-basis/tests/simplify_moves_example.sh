#!/bin/sh
# Integration test of the simplification phase's later moves on the one-loop massless box
# (tests/simplify_moves_example.wls): a planted shift of the box by the t-bubble, undone with real jobs twice, in two
# runs: by move (iii) (census jobs, budget, the fit's samples, its candidate, its measurement and the gate) and by move
# (ii) (the same with a reduction to scan instead of the fit's samples, and a variant in integrals). Ten jobs, one
# kernel at a time, each through bin/ws. Needs FiniteFlow, LiteRed and LiteIBP; a few minutes.
# usage: [PFB_TEST_PATHS=paths.wl] [PFB_KEEP_SCRATCH=1] tests/simplify_moves_example.sh [paths.wl]   exit code 0 when every test passes
here=$(cd "$(dirname "$0")" && pwd -P)
ws="$here/../bin/ws"
[ -z "${PFB_TEST_PATHS:-}" ] && [ -n "${1:-}" ] && export PFB_TEST_PATHS="$1"
top=$(mktemp -d) || exit 2
start=$(date +%s)
fail() { echo "simplify_moves_example: $1 (scratch kept in $top)"; exit 1; }
# bin/simplify.wls, expecting the exit code $1 (4: something to do, then again; 0: done)
simplify() { want=$1; shift
  "$ws" --timeout 900 "$here/../bin/simplify.wls" "$dir/run.wl" "$@" > "$dir/simplify_$n.log" 2>&1; rc=$?
  [ $rc -eq "$want" ] || { cat "$dir/simplify_$n.log"; fail "bin/simplify.wls $* exited with $rc, not $want"; }
  n=$((n+1)); }
runjobs() { sh "$dir/run/jobs/simplify_command.sh" || fail "$1 failed (see $dir/run/jobs/*/run.log)"; }
rc=0
for move in shift swap; do
  dir="$top/$move"; mkdir -p "$dir"; n=1
  export PFB_EXAMPLE_DIR="$dir" PFB_EXAMPLE_MOVE="$move"
  PFB_EXAMPLE_PHASE=prepare "$ws" --timeout 900 "$here/simplify_moves_example.wls" || fail "phase prepare failed ($move)"
  simplify 4; runjobs "a census job"           # the degree census of the current slice
  simplify 4                                   # collects it and proposes a budget
  simplify 4 --budget proposed; runjobs "the move's own job"   # the fit's samples, or the reduction to scan
  simplify 4; runjobs "a variant job"          # the move's candidates, the job that measures them
  simplify 0                                   # measures them and gates the best
  PFB_EXAMPLE_PHASE=check "$ws" --timeout 900 "$here/simplify_moves_example.wls" || rc=1
done
echo "simplify_moves_example: $(( $(date +%s) - start )) s in all"
# PFB_KEEP_SCRATCH=1 keeps the run folders to read their reports
if [ $rc -eq 0 ] && [ -z "${PFB_KEEP_SCRATCH:-}" ]; then rm -rf "$top"; else echo "simplify_moves_example: scratch in $top"; fi
exit $rc
