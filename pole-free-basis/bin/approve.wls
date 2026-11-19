#!/usr/bin/env wolframscript
(* Accept a change that is waiting for approval (run option "Approval" -> True), after the user said yes; or decline it
   after a no (--decline): it is recorded as rejected, with the date and the reason, and a pending move of the
   simplification phase is marked declined, so that bin/simplify.wls goes on.
   usage: approve.wls run.wl id
          approve.wls run.wl --decline id [reason ...] *)
Get[FileNameJoin[{ParentDirectory[DirectoryName[$InputFileName]], "lib", "PoleFreeBasis.wl"}]];

Module[{a = Rest[$ScriptCommandLine], st, r, dec, id},
If[Length[a] < 2, Print["usage: approve.wls run.wl id | approve.wls run.wl --decline id [reason ...]"]; CoreVerdict["approve", "usage"]];
st = PFBStartRun[a[[1]]]; If[st === $Failed, CoreVerdict["approve", "usage", <|"message" -> "no run found for " <> ToString[a[[1]]]|>]];
dec = a[[2]] === "--decline";
id = Quiet@ToExpression[a[[If[dec, 3, 2]]]];
If[! IntegerQ[id], Print["usage: approve.wls run.wl id | approve.wls run.wl --decline id [reason ...]"]; CoreVerdict["approve", "usage"]];
If[dec,
  r = PFBDecline[st["Dir"], st["State"], st["System"], id, If[Length[a] > 3, StringRiffle[Drop[a, 3], " "], "declined by the user"]];
  Print["declined: ", If[r["Record"] === None, "nothing (no pending change " <> ToString[id] <> ")", "change " <> ToString[id]], "; pending: ", Length[r["State"]["Pending"]]];
  CoreVerdict["approve", If[r["Record"] === None, "fail", "pass"], <|"change" -> id, "declined" -> (r["Record"] =!= None), "pending" -> Length[r["State"]["Pending"]]|>]];
r = PFBApprove[st["Dir"], st["State"], st["System"], id];
Print["accepted changes: ", Length[r["State"]["Accepted"]], "; pending: ", Length[r["State"]["Pending"]]];
Print["current slice: ", r["State"]["Current"]];
CoreVerdict["approve", If[MemberQ[r["State"]["Accepted"][[All, "Id"]], id], "pass", "fail"],
  <|"change" -> id, "accepted" -> Length[r["State"]["Accepted"]], "pending" -> Length[r["State"]["Pending"]], "slice" -> r["State"]["Current"]|>]];
