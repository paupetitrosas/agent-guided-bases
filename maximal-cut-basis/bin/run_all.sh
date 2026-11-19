#!/bin/sh
# Whole run: preflight, validation (+ scaling self-test), sectors, automatic first pass in parallel queues, reports.
# usage: run_all.sh run.wl [queues]          (queues default: run.wl "Parallel", Automatic = the licence budget)
# Any step listed in run.wl "Skip" is still honoured inside the scripts.  FORCE=1 redoes sectors with basis.m.
set -u
[ $# -ge 1 ] || { echo "usage: run_all.sh run.wl [queues]"; exit 2; }
here=$(cd "$(dirname "$0")" && pwd)
runwl=$(cd "$(dirname "$1")" && pwd)/$(basename "$1")
cd "$(dirname "$runwl")"
# every kernel goes through bin/ws, which waits for a free licence slot (queues included)
ws() { "$here/ws" "$@"; }
echo "== preflight";        ws "$here/preflight.wls" "$runwl" | tail -4
echo "== validate family";  ws "$here/validate_family.wls" "$runwl" || { echo "family.wl needs fixing"; exit 1; }
echo "== sectors"
fm=$(ws "$here/find_masters.wls" "$runwl"); echo "$fm" | grep -v '^RUNDIR\|^QUEUES'
out=$(echo "$fm" | sed -n 's/^RUNDIR //p' | tail -1)
# the scaling self-test needs the sectors, which a family without a masters list only has now
echo "== scaling self-test"
st=$(ws "$here/validate_family.wls" "$runwl" --scaling); rc=$?
echo "$st" | grep 'scaling self-test'
[ "$rc" -eq 0 ] || { echo "$st" | tail -3; echo "family.wl needs fixing"; exit 1; }
Q=${2:-$(echo "$fm" | sed -n 's/^QUEUES //p' | tail -1)}; Q=${Q:-1}
[ -n "$out" ] && [ -f "$out/sectors.txt" ] || { echo "no sectors.txt"; exit 1; }
echo "== automatic first pass: $(wc -l < "$out/sectors.txt") sectors in $Q queue(s)"
rm -f "$out"/.queue_*
i=0
while read -r name id np; do
  [ -z "$name" ] && continue
  echo "$name" >> "$out/.queue_$((i % Q))"; i=$((i + 1))
done < "$out/sectors.txt"
rm -f "$out"/auto_pass_*.log
for f in "$out"/.queue_*; do
  [ -f "$f" ] || continue
  log="$out/auto_pass_${f##*_}.log"
  ( ws "$here/auto_pass.wls" "$runwl" $(cat "$f") > "$log" 2>&1; grep '^DONE' "$log" ) &
done
wait
rm -f "$out"/.queue_*
echo "== reports";          ws "$here/make_reports.wls" "$runwl" | tail -1
