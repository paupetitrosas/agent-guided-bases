(* run.wl: one run of the skill over a family (see reference/formats.md). *)
<|
 "Family"     -> "family.wl",
 "OutputDir"  -> Automatic,          (* <family dir>/<Name>_analysis *)
 "Sectors"    -> All,                (* or {"j0101...", kira-id, ...} *)
 "Skip"       -> {},                 (* step names, e.g. {"finiteflow", "d0-shift"} *)
 "Points"     -> Automatic, "Seed" -> 1,
 "TimeLimits" -> <|"LS" -> 600,      (* one candidate search, in seconds *)
                  "Sector" -> 900,  (* all the candidate searches of one sector in the automatic pass *)
                  "FiniteFlow" -> 3600, "Kira" -> 3600, "Baikov" -> 120, "PicardFuchs" -> 300|>,
 "MemoryLimits" -> <|"Kira" -> Automatic,        (* GB, one Kira run; Automatic: what the kernel's own limit leaves *)
                    "FiniteFlow" -> Automatic|>, (* GB, each step of the FiniteFlow check; Automatic: bin/ws's default *)
 "Parallel"   -> Automatic,          (* queues of run_all.sh; Automatic: from the licence *)
 "AutoPass"   -> <|"nd" -> 2, "nt" -> 2, "w" -> 3|>
|>
