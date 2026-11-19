(* ::Package:: *)

(* ::Title:: *)
(*PoleFreeBasis`Reports`: HTML pages*)


BeginPackage["PoleFreeBasis`Reports`", {"PoleFreeBasis`", "PoleFreeBasis`Config`", "PoleFreeBasis`System`", "PoleFreeBasis`Census`",
  "PoleFreeBasis`Records`", "PoleFreeBasis`Degrees`", "PoleFreeBasis`Simplify`", "MaximalCutBasis`", "SkillCore`Tools`", "SkillCore`Records`", "SkillCore`Pages`", "SkillCore`Citations`", "MaximalCutBasis`Sectors`", "MaximalCutBasis`Rules`", "MaximalCutBasis`Reports`"}];

PFBSummaryHTML::usage = "PFBSummaryHTML[runDir, sys, state] writes summary.html: maximal-cut changes first (with their eps-profile consequences), then the census history, the sectors, what is left to do, and what to cite (CoreCitationsHTML: the run's ledger, citations.m).";
PFBSectorHTML::usage = "PFBSectorHTML[runDir, sys, state, key] writes the sector page from basis.m, attempts.m and notes.md, with the tools and papers the run's ledger (citations.m) gives the sector and its image families' copies of it (CoreSectorCitationsHTML).";
PFBMakeReports::usage = "PFBMakeReports[runDir, sys, state] writes every sector record and page, the summary, export/, CHANGES.md and CITATIONS.md (PFBWriteCitations, first: it credits the maximal-cut-basis run of the families' starting masters for the sectors that keep one). Returns the summary file.";

Begin["`Private`"];

(* the determinant on a reference basis, for a change recorded while the gate judged the determinant on one (records of
   2026-10-10 to 2026-10-16) *)
refDetHTML[a_] := If[MissingQ[Lookup[a, "DetOnReference", Missing[]]], "",
  " on the old basis; on the reference basis (" <> esc[ToString[a["ReferenceSource"]]] <> "): " <> texOf[a["DetOnReference"]]];


(* the maximal-cut-basis gate on the new basis of a change that alters the maximal cut *)
maxCutHTML[a_] := With[{m = Lookup[a, "MaxCutCheck", Missing[]]}, If[! AssociationQ[m] || ! StringQ[Lookup[m, "Text", None]], "",
  " <span class='muted'>(maximal cut: " <> esc[m["Text"]] <> ")</span>"]];

esc = MCBHTMLEscape;
(* a stored census does not know which lower-sector scans were recorded since, nor which sectors were flagged or fixed
   since: the hints are marked from attempts.m, and those on sectors that cannot change any more are dropped *)
withTried[dir_, c_Association, sys_ : None, st_ : None] := If[Lookup[c, "HiddenWeights", {}] === {}, c,
  Join[c, <|"HiddenWeights" -> (Join[#, <|"Tried" -> (TrueQ[#["Tried"]] || MemberQ[PFBHiddenWeightTried[dir, #["Sector"]], #["Factor"]])|>,
       If[AssociationQ[st] && KeyExistsQ[PFBReopenedSectors[st], #["Sector"]], <|"Reopens" -> PFBReopenedSectors[st][#["Sector"]]|>, <||>]] & /@
     If[AssociationQ[sys] && AssociationQ[st], Select[c["HiddenWeights"], PFBCanChangeQ[sys, #["Sector"], PFBFlaggedSectors[st]] &], c["HiddenWeights"]])|>]];
withTried[_, c_, ___] := c;
(* the pole entries an attempt left in the sector's rows, by factor: what the hidden-weight test reads *)
leftText[l_List] := If[! MatchQ[l, {{_, _, _List} ..}], "", " <span class='muted'>(left in the sector's rows: " <>
   esc[StringRiffle[KeyValueMap[ToString[#1, InputForm] <> " in " <> ToString[ut /@ Union[#2]] &, GroupBy[Flatten[Function[e, {#, e[[2]]} & /@ e[[3]]] /@ l, 1], First -> Last]], "; "]] <> ")</span>"];
leftText[_] := "";
badge = CoreBadge;
page[file_, title_, body_] := CorePage[file, title, body, "the pole-free-basis skill (PoleFreeBasis " <> PoleFreeBasis`$PFBVersion <> ")"];
texOf[e_] := "\\(" <> MCBTeX[e] <> "\\)";
plural[n_Integer, w_String] := ToString[n] <> " " <> w <> If[n == 1, "", "s"];

(* a slice of the history: its highest power of eps (entries without finite poles) and how many entries are above the
   cap; slices stored before the cap was recorded show "-" *)
degreeText[h_] := With[{d = Lookup[h, "MaxDegree", Missing[]], n = Lookup[h, "HighDegree", 0]},
  If[IntegerQ[d], ToString[d] <> If[n > 0, " <span class='muted'>(" <> ToString[n] <> " above &epsilon;<sup>" <> ToString[Lookup[h, "DegreeCap", "?"]] <> "</sup>)</span>", ""], "-"]];
profileText[p_] := Which[MissingQ[p], "not recorded", AssociationQ[p], esc[p["Range"]] <> " <span class='muted'>(" <> esc[Normal[p["Counts"]]] <> ")</span>", True, esc[p]];



PFBSectorHTML[dir_String, sys_Association, st_Association, key_List] := Module[{sd = PFBSectorDir[dir, key], rec, att, notes, acc, body, cites},
  rec = MCBReadBasis[sd];
  If[! KeyExistsQ[rec, "name"], Return[$Failed]];
  att = MCBReadAttempts[sd];
  notes = With[{f = FileNameJoin[{sd, "notes.md"}]}, If[FileExistsQ[f], Import[f, "Text"], ""]];
  (* the changes of this sector, and the simplifications that changed some of its masters *)
  acc = Select[st["Accepted"], MemberQ[PFBChangeKeys[sys, #], key] &];
  (* the sector's tools and papers in the run's ledger; an image family's copy of the sector belongs to this page *)
  cites = StringJoin[Table[With[{h = CoreSectorCitationsHTML[dir, PFBSectorString[k]]},
      If[h === "", "", If[k === key, "", "<p class='muted'>Image family " <> esc[ToString[k[[1]]]] <> ":</p>"] <> h]],
    {k, Prepend[{#, key[[2]]} & /@ PFBImagesOf[sys, key[[1]]], key]}]];
  body = StringJoin[
    "<h1>", esc[rec["family"]], " &middot; ", esc[rec["name"]], "</h1>",
    "<p class='muted'>sector id ", ToString[rec["id"]], If[rec["images"] =!= {}, " &middot; images " <> StringRiffle[rec["images"], ", "], ""], "</p>",
    "<p>", badge[rec["status"]], "</p>",
    If[TrueQ[rec["maxCutChanged"]],
      "<div class='card retry'><b>The maximal-cut basis of this sector was changed.</b> " <>
        StringJoin[Table["<p>change " <> ToString[a["Id"]] <> ": det = " <> texOf[a["Determinant"]] <> refDetHTML[a] <> maxCutHTML[a] <> "; eps profile of the sector rows " <>
          profileText[a["ProfileBefore"]] <> " &rarr; " <> profileText[a["ProfileAfter"]] <> "</p>", {a, Select[acc, #["MaxCutChanged"] &]}]] <> "</div>", ""],
    (* new poles that changes of lower sectors deferred to this sector *)
    If[Lookup[rec, "deferredHere", {}] === {}, "",
      "<div class='card retry'><b>Poles deferred to this sector by changes below it.</b> Its fix must remove them too." <>
        StringJoin[Table["<p>change " <> ToString[o["Change"]] <> ": rows " <> esc[ToString[ut /@ o["Rows"]]] <>
          If[Lookup[o, "Kind", "new"] === "moved",
            ", moved poles: factors " <> esc[ToString[o["Factors"], InputForm]] <> ", which these rows had before, now in " <> ToString[Length[o["Entries"]]] <> If[Length[o["Entries"]] == 1, " new entry", " new entries"],
            ", through " <> esc[ToString[ut /@ o["Sources"]]] <> If[TrueQ[o["Verified"]], "", " (one master: not verified)"]] <> "</p>", {o, rec["deferredHere"]}]] <> "</div>"],
    (* the census's hint: a clean sector that may carry a hidden weight, which shows in the rows above *)
    If[Lookup[rec, "possibleHiddenWeight", {}] === {}, "",
      "<div class='card retry'><b>Possible hidden weight.</b> The rows of the sectors above carry a pole only in the columns of this sector's subtree, while its own rows are clean: one of its masters may carry the factor as a hidden weight (I = w J with J honest). Open this sector before those above: the lower-sector scan (<code>bin/pair_scan.wls run.wl &lt;job&gt; " <>
        esc[PFBSectorString[key]] <> " --hidden-weight</code>), judged on those rows." <>
        StringJoin[Table["<p>" <> texOf[h["factor"]] <> ": rows " <> esc[ToString[ut /@ h["rows"]]] <> " (" <> esc[StringRiffle[h["sectors"], ", "]] <> "), columns " <>
          esc[ToString[ut /@ h["columns"]]] <> If[TrueQ[h["tried"]], " <span class='muted'>(its lower-sector scan was recorded: see the attempts)</span>", ""] <> "</p>", {h, rec["possibleHiddenWeight"]}]] <> "</div>"],
    "<h2>Masters</h2><div class='scroll'><table><tr><th>label</th><th>pos</th><th>definition</th><th>&epsilon; powers</th><th>provenance</th></tr>",
    Table["<tr><td><code>" <> esc[m["label"]] <> "</code></td><td>" <> esc[m["family"]] <> " " <> ToString[m["pos"]] <> "</td><td class='def'><div class='tex'>" <>
       texOf[m["definition"]] <> "</div>" <> If[TrueQ[m["changed"]], "<details><summary>old definition</summary><div class='tex'>" <> texOf[m["oldDefinition"]] <> "</div></details>", ""] <>
       "</td><td>" <> esc[m["epsPowers"]] <> "</td><td class='label'>" <> esc[m["provenance"]] <> "</td></tr>", {m, rec["masters"]}],
    "</table></div>",
    "<h2>Poles</h2>",
    If[rec["badRows"] === {}, "<p>No finite &epsilon; poles in the rows of this sector.</p>",
      "<p>Rows with finite poles: <code>" <> esc[ut /@ rec["badRows"]] <> "</code>, factors <code>" <> esc[rec["poleFactors"]] <> "</code>" <>
       If[TrueQ[rec["possiblyInherited"]], "; possibly inherited from " <> esc[rec["couplesToBadLower"]], ""] <> ".</p>" <>
       StringJoin[Table["<p>" <> texOf[h["factor"]] <> " sits only in the columns " <> esc[ToString[ut /@ h["columns"]]] <> ", all in the subtree of the clean sector <code>" <>
         esc[h["sector"]] <> "</code>: a possible hidden weight of that sector, to open first" <> If[TrueQ[h["tried"]], " (its lower-sector scan was recorded)", ""] <> ".</p>",
         {h, Lookup[rec, "hiddenWeightBelow", {}]}]]],
    If[rec["epsZeroRows"] =!= {}, "<p>Rows with negative powers of &epsilon;: <code>" <> esc[ut /@ rec["epsZeroRows"]] <> "</code></p>", ""],
    If[acc =!= {}, "<h2>Accepted changes</h2>" <> StringJoin[Table[
        "<div class='card'><b>" <> ToString[a["Id"]] <> ". " <> esc[a["Name"]] <> "</b> &middot; rung " <> ToString[PFBRungNumber[a]] <> "<p>" <> esc[a["Provenance"]] <> "</p><ul class='tight'>" <>
         StringJoin[Table["<li>" <> esc[c["Name"]] <> ": " <> If[c["Pass"], "ok", "FAILED"] <> " &mdash; " <> esc[c["Detail"]] <> "</li>", {c, a["Gate"]}]] <> "</ul></div>", {a, acc}]], ""],
    If[notes =!= "", "<h2>How this basis was found</h2>" <> CoreMarkdown[notes], ""],
    "<h2>Attempts</h2>", If[att === {}, "<p class='muted'>none recorded</p>",
      "<div class='scroll'><table><tr><th>date</th><th>rung</th><th>what</th><th>outcome</th></tr>" <>
       StringJoin[Table["<tr><td>" <> esc[Lookup[a, "date", ""]] <> "</td><td>" <> esc[Lookup[a, "rung", ""]] <> "</td><td>" <> esc[Lookup[a, "what", ""]] <> "</td><td>" <>
          esc[Lookup[a, "outcome", ""]] <> leftText[Lookup[a, "leftover", {}]] <> "</td></tr>", {a, att}]] <> "</table></div>"],
    If[rec["flags"] =!= {}, "<h2>Flagged</h2>" <> StringJoin[Table["<div class='card retry'><p>" <> esc[f["Reason"]] <> "</p><p class='muted'>tried: " <> esc[f["Tried"]] <> "</p>" <>
        With[{hw = Lookup[f, "HiddenWeight", Missing[]]}, If[AssociationQ[hw], "<p class='muted'>hidden-weight test: " <> esc[hw["Message"]] <>
          If[TrueQ[Lookup[f, "Forced", False]], " (flagged with Force)", ""] <> "</p>", ""]] <> "</div>", {f, rec["flags"]}]], ""],
    If[cites =!= "", "<h2>Citations</h2>" <> cites, ""],
    "<p><a href='../../summary.html'>&larr; summary</a></p>"];
  page[FileNameJoin[{sd, "sector.html"}], rec["family"] <> " " <> rec["name"], body];
  FileNameJoin[{sd, "sector.html"}]];


(* the sector pages of a change: its sector, or the sectors whose masters a simplification changed (key None) *)
sectorLinks[sys_, a_] := With[{ks = PFBChangeKeys[sys, a]}, If[ks === {}, "-",
   StringRiffle[("<a href='" <> ToString[#[[1]]] <> "/" <> SectorName[#[[2]]] <> "/sector.html'><code>" <> esc[PFBSectorString[#]] <> "</code></a>") & /@ ks, ", "]]];

PFBSummaryHTML[dir_String, sys_Association, st_Association] := Module[{keys = PFBSectorKeys[sys], recs, body, mc, hist, census, counts, last},
  recs = Select[Table[Join[MCBReadBasis[PFBSectorDir[dir, k]], <|"key" -> k|>], {k, keys}], KeyExistsQ[#, "name"] &];
  mc = Select[st["Accepted"], #["MaxCutChanged"] &];
  hist = st["Slices"];
  census = If[hist === {}, None, withTried[dir, Get[FileNameJoin[{dir, Last[hist]["Census"]}]], sys, st]];
  counts = Counts[#["status"] & /@ recs];
  body = StringJoin[
    "<h1>", esc[sys["Name"]], ": pole-free basis</h1>",
    "<p class='muted'>", plural[Length[PFBMasters[sys]], "master"], ", ", ToString[Length[sys["Order"]]] <> If[Length[sys["Order"]] == 1, " family", " families"], ", ",
      plural[Length[st["Accepted"]], "accepted change"], If[st["Pending"] =!= {}, ", " <> plural[Length[st["Pending"]], "change"] <> " awaiting approval", ""], "</p>",
    "<div class='totals'>", KeyValueMap["<div class='card'><b>" <> ToString[#2] <> "</b>" <> badge[#1] <> "</div>" &, counts], "</div>",
    (* maximal-cut changes come first *)
    "<h2>Maximal-cut basis changes (", ToString[Length[mc]], ")</h2>",
    If[mc === {}, "<p>None: every change kept the maximal-cut class of the masters it replaced.</p>",
      "<div class='card retry'><p>These changes alter the masters on the maximal cut. The determinant of the new masters on the old ones is shown (a change recorded by an earlier version may show it on a reference basis too); the &epsilon; profile of the sector rows changes as shown.</p><div class='scroll'><table><tr><th>sector</th><th>change</th><th>det</th><th>&epsilon; profile before</th><th>after</th></tr>" <>
        StringJoin[Table["<tr><td>" <> sectorLinks[sys, a] <> "</td><td>" <>
           ToString[a["Id"]] <> ". " <> esc[a["Name"]] <> "</td><td>" <> texOf[a["Determinant"]] <> refDetHTML[a] <> maxCutHTML[a] <> "</td><td>" <> profileText[a["ProfileBefore"]] <> "</td><td>" <>
           profileText[a["ProfileAfter"]] <> "</td></tr>", {a, mc}]] <> "</table></div></div>"],
    If[st["Pending"] =!= {}, "<h2>Awaiting approval</h2><ul class='tight'>" <> StringJoin[Table["<li>" <> ToString[p["Id"]] <> ". " <> esc[p["Name"]] <>
        If[p["MaxCutChanged"], " <b>(maximal cut changes)</b>", ""] <> "</li>", {p, st["Pending"]}]] <> "</ul>", ""],
    "<h2>Census</h2>",
    If[hist === {}, "<p class='muted'>no slice yet</p>",
      "<div class='scroll'><table><tr><th>slice</th><th>entries with finite poles</th><th>bad rows</th><th>negative &epsilon; powers</th><th>highest &epsilon; power</th><th>date</th></tr>" <>
       StringJoin[Table["<tr><td>" <> esc[h["Label"]] <> "</td><td>" <> ToString[h["BadEntries"]] <> "</td><td>" <> ToString[h["BadRows"]] <> "</td><td>" <> ToString[h["EpsZero"]] <>
          "</td><td>" <> degreeText[h] <> "</td><td>" <> esc[h["Date"]] <> "</td></tr>", {h, hist}]] <> "</table></div>"],
    If[census =!= None, "<p>&epsilon; profile of the current slice ({lowest, highest} power &rarr; entries): <code>" <> esc[Take[PFBProfileCounts[census], UpTo[10]]] <> "</code></p>" <>
       If[census["PoleFactors"] =!= <||>, "<p>Pole factors: <code>" <> esc[Normal[census["PoleFactors"]]] <> "</code></p>", ""], ""],
    (* the census's hidden-weight hints: clean sectors to open before the sectors where the poles show *)
    If[census === None || Lookup[census, "HiddenWeights", {}] === {}, "",
      "<h2>Possible hidden weights</h2><div class='card retry'><p>A pole factor sits only in the columns of one clean sector's subtree: that sector may carry it as a hidden weight, and is opened before the sectors where the poles show (its lower-sector scan).</p><ul class='tight'>" <>
        StringJoin[Table["<li><a href='" <> ToString[h["Sector"][[1]]] <> "/" <> SectorName[h["Sector"][[2]]] <> "/sector.html'><code>" <> esc[PFBSectorString[h["Sector"]]] <> "</code></a>: " <>
          texOf[h["Factor"]] <> " in the rows " <> esc[ToString[ut /@ h["Rows"]]] <> " of " <> esc[StringRiffle[PFBSectorString /@ h["Sectors"], ", "]] <> ", columns " <> esc[ToString[ut /@ h["Columns"]]] <>
          esc[PFBReopenText[Lookup[h, "Reopens", None]]] <> If[TrueQ[h["Tried"]], " <span class='muted'>(lower-sector scan recorded)</span>", ""] <> "</li>", {h, census["HiddenWeights"]}]] <> "</ul></div>"],
    (* the kinematic degrees of the slices that have a degree table (bin/degrees.wls, the local slice, or the user's) *)
    With[{dh = Select[hist, AssociationQ[Lookup[#, "DegreeSummary", None]] &]},
      If[dh === {}, "",
        "<h2>Kinematic degrees</h2><p>Per slice with a degree table: the highest degree of a term (an entry at one power of &epsilon;, or a whole entry; " <>
         "the larger of its numerator and denominator degrees in the invariants, unit scale 1), the terms at it, the sum over terms, and the denominator degree " <>
         "the known singularities do not explain.</p><div class='scroll'><table><tr><th>slice</th><th>source</th><th>highest</th><th>terms at it</th><th>sum</th>" <>
         "<th>unexplained</th><th>sectors measured</th></tr>" <>
         StringJoin[Table[With[{s = h["DegreeSummary"]}, "<tr><td>" <> esc[h["Label"]] <> "</td><td>" <> esc[Lookup[h, "DegreeSource", "measured"]] <> "</td><td>" <>
            esc[Replace[s["Highest"], None -> "-"]] <> "</td><td>" <> ToString[s["Count"]] <> "</td><td>" <> ToString[s["Sum"]] <> "</td><td>" <>
            esc[Replace[s["Unexplained"], _Missing -> "-"]] <> "</td><td>" <> ToString[s["Measured"]] <> " of " <> ToString[s["Sectors"]] <> "</td></tr>"], {h, dh}]] <>
         "</table></div>"]],
    (* the stages (starting degrees, after the pole-free work, after the simplification phase), per sector, and the phase's moves *)
    With[{sh = PFBSimplifyHTML[dir, sys, st]}, If[sh === "", "", If[Select[hist, AssociationQ[Lookup[#, "DegreeSummary", None]] &] === {}, "<h2>Kinematic degrees</h2>", ""] <> sh]],
    "<h2>Sectors</h2><div class='scroll'><table><tr><th>sector</th><th>masters</th><th>status</th><th>bad rows</th><th>changes</th></tr>",
    Table["<tr><td><a href='" <> r["family"] <> "/" <> r["name"] <> "/sector.html'><code>" <> esc[PFBSectorString[r["key"]]] <> "</code></a></td><td>" <>
       ToString[Length[r["masters"]]] <> "</td><td>" <> badge[r["status"]] <> If[Lookup[r, "possibleHiddenWeight", {}] === {}, "", " <span class='muted'>possible hidden weight " <>
         esc[StringRiffle[ToString[#["factor"], InputForm] & /@ r["possibleHiddenWeight"], ", "]] <> "</span>"] <> "</td><td>" <> ToString[Length[r["badRows"]]] <> "</td><td>" <>
       ToString[Count[st["Accepted"], _?(MemberQ[PFBChangeKeys[sys, #], r["key"]] &)]] <> "</td></tr>", {r, recs}],
    "</table></div>",
    "<h2>Before using the new basis</h2><p>Every check here is exact in &epsilon; but made on the numerical slice and on subtree reductions. ",
    If[TrueQ[st["Regenerated"]], "The full differential equation was regenerated with the new basis.", "<b>Regenerate the full differential equation once with the exported masters</b> and run the census on it."],
    "</p>",
    CoreCitationsHTML[dir],
    "<p class='muted'>Read next: <code>CHANGES.md</code> (every change and what is not verified) and <code>export/</code> (the new masters files).</p>"];
  page[FileNameJoin[{dir, "summary.html"}], sys["Name"] <> " pole-free basis", body];
  FileNameJoin[{dir, "summary.html"}]];

PFBMakeReports[dir_String, sys_Association, st_Association] := Module[{census, keys},
  (* CITATIONS.md first, with the maximal-cut-basis run of the families' starting masters credited for the sectors that
     keep one: the pages read the same ledger *)
  PFBWriteCitations[dir, sys, st];
  census = If[st["Slices"] === {}, <|"Sectors" -> <||>|>, withTried[dir, Get[FileNameJoin[{dir, Last[st["Slices"]]["Census"]}]], sys, st]];
  keys = PFBSectorKeys[sys];
  Do[PFBWriteSectorRecord[dir, sys, st, census, k]; PFBSectorHTML[dir, sys, st, k], {k, keys}];
  PFBExportMasters[sys, st, dir];
  PFBWriteChanges[sys, st, dir, PFBSimplifyMarkdown[dir, sys, st]];
  PFBSummaryHTML[dir, sys, st]];


End[];
EndPackage[];
