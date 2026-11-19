#!/bin/sh
# Kira and FiniteFlow at the slice point give the same reduction (Masters, Dm, Rp, dRp, exactly in eps), on the
# one-loop box of the maximal-cut-basis examples and on an image of it. tests/kira_vs_finiteflow.wls writes the planted
# system and six jobs (the last twice), each job runs through bin/ws in its own kernel, one after the other (a kernel never waits for
# another's licence slot), and the .wls checks the reductions, the statuses and the calibration.
# Needs Kira, Fermat, FiniteFlow (a current library), LiteRed and LiteIBP; about two minutes with a free licence slot.
#
# usage: tests/kira_vs_finiteflow.sh [paths.wl]        exit code 0 when every test passes
#        (a paths.wl for the tools, else the usual detection; everything is written to a temporary folder, which is
#        deleted at the end unless PFB_KVF_KEEP=1)
here=$(cd "$(dirname "$0")" && pwd -P)
ws="$here/../bin/ws"
dir=$(mktemp -d "${TMPDIR:-/tmp}/pfb_kvf.XXXXXX")
paths=""
[ -n "${1:-}" ] && paths=$(cd "$(dirname "$1")" && pwd -P)/$(basename "$1")
# the mode and the folders go through the environment: wolframscript can take an argument for a script
PFB_KVF_MODE=write PFB_KVF_DIR="$dir" PFB_KVF_PATHS="$paths" "$ws" "$here/kira_vs_finiteflow.wls" || { echo "kira_vs_finiteflow: the jobs were not written"; rm -rf "$dir"; exit 1; }
for j in ff kira image_ff image_kira image_top kira_fail kira_fail; do
  t0=$(date +%s)
  sh "$dir/jobs/$j/command.sh"
  echo "$j $? $(( $(date +%s) - t0 ))" >> "$dir/times.txt"
done
PFB_KVF_MODE=check PFB_KVF_DIR="$dir" "$ws" "$here/kira_vs_finiteflow.wls"
rc=$?
if [ -n "${PFB_KVF_KEEP:-}" ]; then echo "kept: $dir"; else rm -rf "$dir"; fi
exit $rc
