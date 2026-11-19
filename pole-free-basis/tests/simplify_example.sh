#!/bin/sh
# Integration test of the simplification phase on the one-loop massless box (tests/simplify_example.wls): a planted
# run, bin/simplify.wls six times (census jobs, budget, move (i), its measurement and the gate, done, a new phase), four degree jobs, one
# kernel at a time, each through bin/ws. Needs FiniteFlow, LiteRed and LiteIBP; a few minutes.
# usage: [PFB_TEST_PATHS=paths.wl] [PFB_KEEP_SCRATCH=1] tests/simplify_example.sh [paths.wl]   exit code 0 when every test passes
here=$(cd "$(dirname "$0")" && pwd -P)
ws="$here/../bin/ws"
[ -z "${PFB_TEST_PATHS:-}" ] && [ -n "${1:-}" ] && export PFB_TEST_PATHS="$1"
dir=$(mktemp -d) || exit 2
export PFB_EXAMPLE_DIR="$dir"
start=$(date +%s)
fail() { echo "simplify_example: $1 (scratch kept in $dir)"; exit 1; }
# bin/simplify.wls, expecting the exit code $1 (4: something to do, then again; 0: done)
simplify() { want=$1; shift
  "$ws" --timeout 900 "$here/../bin/simplify.wls" "$dir/run.wl" "$@" > "$dir/simplify_$n.log" 2>&1; rc=$?
  [ $rc -eq "$want" ] || { cat "$dir/simplify_$n.log"; fail "bin/simplify.wls $* exited with $rc, not $want"; }
  n=$((n+1)); }
n=1
PFB_EXAMPLE_PHASE=prepare "$ws" --timeout 900 "$here/simplify_example.wls" || fail "phase prepare failed"
simplify 4                                   # writes the degree census of the current slice
sh "$dir/run/jobs/simplify_command.sh" || fail "a census job failed (see $dir/run/jobs/deg_*/run.log)"
simplify 4                                   # collects it and proposes a budget
simplify 4 --budget proposed                 # move (i): the program and its variant jobs
sh "$dir/run/jobs/simplify_command.sh" || fail "a variant job failed (see $dir/run/jobs/simp*/run.log)"
simplify 0                                   # measures the candidates and gates the best
simplify 0                                   # a phase that is done stays done
simplify 4 --new                             # a new phase: the census is current, it asks for a budget
PFB_EXAMPLE_PHASE=check "$ws" --timeout 900 "$here/simplify_example.wls"
rc=$?
echo "simplify_example: $(( $(date +%s) - start )) s in all"
# PFB_KEEP_SCRATCH=1 keeps the run folder to read its reports
if [ $rc -eq 0 ] && [ -z "${PFB_KEEP_SCRATCH:-}" ]; then rm -rf "$dir"; else echo "simplify_example: scratch in $dir"; fi
exit $rc
