#!/bin/sh
# Integration test of the degree census on the one-loop massless box (tests/degrees_example.wls): three short kernels
# and three reduction jobs, one at a time, each through bin/ws. Needs FiniteFlow, LiteRed and LiteIBP; a few minutes.
# usage: [PFB_TEST_PATHS=paths.wl] tests/degrees_example.sh        exit code 0 when every test passes
here=$(cd "$(dirname "$0")" && pwd -P)
ws="$here/../bin/ws"
dir=$(mktemp -d) || exit 2
export PFB_EXAMPLE_DIR="$dir"
start=$(date +%s)
step() { PFB_EXAMPLE_PHASE=$1 "$ws" --timeout 900 "$here/degrees_example.wls" || { echo "degrees_example: phase $1 failed (scratch kept in $dir)"; exit 1; }; }
step prepare
sh "$dir/cmd1.sh" || { echo "degrees_example: the local slice job failed (see $dir/run/jobs/local_slice/run.log)"; exit 1; }
step middle
sh "$dir/cmd2.sh" || { echo "degrees_example: a job failed (see $dir/run/jobs/*/run.log)"; exit 1; }
PFB_EXAMPLE_PHASE=check "$ws" --timeout 900 "$here/degrees_example.wls"
rc=$?
echo "degrees_example: $(( $(date +%s) - start )) s in all"
[ $rc -eq 0 ] && rm -rf "$dir"
exit $rc
