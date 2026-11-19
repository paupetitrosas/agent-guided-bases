#!/bin/sh
# Rung 8 with the maximal-cut-basis gate for real: Kira on the maximal cut of the equal-mass bubble of the
# maximal-cut-basis examples, in the kernel of tests/maxcut_kira.wls (one kernel through bin/ws). It builds the
# candidates with maximal-cut-basis's routes (BaikovPackage), checks bases on the cut (eps-form, eps-polynomial, a
# failed Euler relation), runs the finalists' checks, and lets PFBTryChange run the check itself on a planted slice.
# Needs Kira, Fermat and BaikovPackage; about a minute with a free licence slot.
#
# usage: tests/maxcut_kira.sh [paths.wl]        exit code 0 when every test passes
#        (a paths.wl for the tools, else the usual detection)
here=$(cd "$(dirname "$0")" && pwd -P)
paths=""
[ -n "${1:-}" ] && paths=$(cd "$(dirname "$1")" && pwd -P)/$(basename "$1")
# the tool paths go through the environment: wolframscript can take an argument for a script
PFB_MCK_RUN=1 PFB_MCK_PATHS="$paths" "$here/../bin/ws" "$here/maxcut_kira.wls"
