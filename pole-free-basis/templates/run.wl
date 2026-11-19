(* run.wl: one pole-free-basis run (see reference/formats.md). Paths are relative to this file. *)
<|
 "System" -> "system.wl",
 "Slice" -> <|"Conventions" -> "conventions.wl"|>,    (* an external slice; a local one is built with bin/local_slice.wls (reference/workflow.md) *)
 "OutputDir" -> Automatic,          (* Automatic: <this folder>/<Name>_poles, where "Name" defaults to the system file's name; never under /tmp *)
 "Approval" -> False,               (* True: every change that passes the gate waits for the user's yes *)
 "Target" -> "PoleFree",            (* "PoleFree": no finite poles, no negative powers of eps; "EpsForm" also asks the completions for eps^1 *)
 "MaxEpsDegree" -> 2,               (* the cap: entries of the DE above eps^2 are fixed like poles; Infinity: no cap. Raise it only with the user's agreement *)
 "ExtraPoints" -> 2,                (* points of the fits besides the slice point; reductions add two more for the gate *)
 "Seeds" -> <|"Rank" -> 3, "Dots" -> 2|>,
 "Reducer" -> Automatic,            (* the slice point of a reduction: Kira when it applies (one family, Kira and Fermat found), else FiniteFlow; or "Kira", "FiniteFlow" *)
 "MaxGB" -> None,                  (* optional cap on a reduction kernel (GB), enforced by bin/ws; each job also checks the memory free when it runs *)
 "TimeLimit" -> 86400,              (* seconds a reduction job may run (bin/ws stops it after); 0 = none *)
 "Threads" -> Automatic,
 "Paths" -> Automatic,              (* or "paths.wl" *)
 "SimplifyBudget" -> Automatic,     (* step 7: seconds of degree jobs for the simplification moves; Automatic: proposed by bin/simplify.wls, then the user's answer *)
 "TargetKinDegree" -> None          (* step 7 stops once the highest kinematic degree is at or below it *)
|>
