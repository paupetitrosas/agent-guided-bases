#!/usr/bin/env wolframscript
(* The credits of a pole-free run in its ledger (citations.m, core/lib/Core/Citations.wl), without FiniteFlow, Kira or
   any other third-party tool. Planted data: the two-loop equal-mass sunrise of the maximal-cut-basis examples with two
   planted masters in the sector of the two tadpoles and one in the top sector (as in tests/simplify_records.wls), a
   planted slice, planted measured degrees, a planted maximal-cut check that marks the tools Kira's check would, a
   planted maximal-cut-basis run of the family with a ledger of its own, and a planted stand-in for FiniteFlow's solver.
   Checked: the run's context (PFBStartRun); the papers of a change that is not tried (another sector's master, an unknown
   tool in info "Tools", a simplification of masters the slice lacks), with the reason, and an entry of info "Reference"
   that is no reference; a simplification's papers and declared tools, for the sectors of its masters, with its id and
   result; tool names in any case or by their display names; PFBTryRescale's papers; the maximal-cut gate's tools on
   the sector it checks; the outcomes of an approval and of a decline; a maximal-cut-basis run's credits: nothing for
   candidates read, a sector's credits with the change the gate checked (consulted when it is rejected), and the
   family's "MCBRun" for a sector that keeps a starting master but not for one whose starting masters were all replaced
   (one tool in CITATIONS.md, imported once, the run never written into); the lines a reduction job appends
   (lib/PFB/JobCitations.wl), only into a pole-free run, and the sector key job.m keeps; conventions.wl "Credits";
   FiniteFlow credited by PFBSolveLinear only when its solver ran; and CHANGES.md, the sector pages and the summary
   showing the same tools and papers as CITATIONS.md.
   usage: bin/ws tests/citations.wls        exit code 0 when every test passes *)
Get[FileNameJoin[{ParentDirectory[DirectoryName[$InputFileName]], "lib", "PoleFreeBasis.wl"}]];
$PFBVerbose = False;
sunFile = FileNameJoin[{ParentDirectory[$PFBRoot], "maximal-cut-basis", "examples", "sunrise-equal-mass", "family.wl"}];
keyLow = {sunrise, {1, 1, 0, 0, 0}}; keyTop = {sunrise, {1, 1, 1, 0, 0}};
low = PFBSectorString[keyLow]; top = PFBSectorString[keyTop];
P = {s -> 3/7, m2 -> 1};
masters = {j[sunrise, 1, 1, 0, 0, 0], m2 j[sunrise, 2, 1, 0, 0, 0], j[sunrise, 1, 1, 1, 0, 0]};
R = {{-2 + eps, 3/5, 0}, {7/3 eps, -1 - 2 eps, 0}, {5/11 + eps, 0, -3 + eps}};
sl = <|"R" -> {R}, "Derivatives" -> {s}, "Point" -> P, "Labels" -> {1, 2, 3}, "Index" -> <|1 -> 1, 2 -> 2, 3 -> 3|>, "Frame" -> "RootFree", "History" -> {}|>;
tmp = CreateDirectory[];
(* a planted maximal-cut-basis run of the family, with a ledger of its own: the top sector's basis and credits, and a
   tool of the tadpoles' sector *)
mcb = FileNameJoin[{tmp, "sunrise_analysis"}];
CreateDirectory[FileNameJoin[{mcb, "j11100"}], CreateIntermediateDirectories -> True]; CreateDirectory[FileNameJoin[{mcb, "j11000"}]];
Put[<|"Run" -> <||>, "FamilyFile" -> sunFile, "OutputDir" -> mcb|>, FileNameJoin[{mcb, "run_info.m"}]];
Put[{eps^2 j[sunrise, 1, 1, 1, 0, 0]}, FileNameJoin[{mcb, "j11100", "masters.m"}]];
Put[<|"status" -> "eps-form", "sector" -> {1, 1, 1, 0, 0}, "masters" -> {<|"definition" -> eps^2 j[sunrise, 1, 1, 1, 0, 0], "label" -> "dlog"|>},
   "classification" -> <|"label" -> "polylog"|>|>, FileNameJoin[{mcb, "j11100", "basis.m"}]];
refG = "A. Author, B. Author, Planted paper G, JHEP 01 (2021) 001, arXiv:2104.00007";
Scan[PutAppend[#, FileNameJoin[{mcb, "citations.m"}]] &, {
   <|"kind" -> "tool", "tool" -> "BaikovPackage", "sector" -> "j11100", "step" -> "first pass", "date" -> "2026-01-01"|>,
   <|"kind" -> "tool", "tool" -> "Baikov", "sector" -> "j11100", "step" -> "first pass", "date" -> "2026-01-01"|>,
   <|"kind" -> "paper", "reference" -> refG, "id" -> "2104.00007", "sector" -> "j11100", "used" -> "the dlog form of the top sector", "result" -> "adopted", "date" -> "2026-01-01"|>,
   <|"kind" -> "tool", "tool" -> "DlogBasis", "sector" -> "j11000", "step" -> "first pass", "date" -> "2026-01-01"|>}];
mcbBefore = Sort[FileNames["*", mcb, Infinity]];
newRun[name_, approval_, run_ : None] := Module[{d = FileNameJoin[{tmp, name}], c},
  CreateDirectory[d, CreateIntermediateDirectories -> True];
  Put[masters, FileNameJoin[{d, "masters.m"}]];
  Put[<|"Name" -> "planted", "Families" -> {Join[<|"Name" -> "sunrise", "Family" -> sunFile, "Masters" -> "masters.m"|>, If[StringQ[run], <|"MCBRun" -> run|>, <||>]]},
     "Letters" -> {s, m2, s - m2, s - 9 m2}|>, FileNameJoin[{d, "system.wl"}]];
  Put[<|"System" -> "system.wl", "OutputDir" -> FileNameJoin[{d, "out"}], "AllowTmp" -> True, "Paths" -> Automatic, "Approval" -> approval|>, FileNameJoin[{d, "run.wl"}]];
  c = PFBStartRun[FileNameJoin[{d, "run.wl"}]];
  Join[c, <|"State" -> PFBStoreSlice[c["Dir"], c["State"], sl, PFBCensus[c["System"], sl], "planted"]|>]];
degs[b_, a_] := <|"Degrees" -> <|"Before" -> <|"Highest" -> b[[1]], "Count" -> b[[2]], "Sum" -> b[[3]], "Terms" -> 6|>,
    "After" -> <|"Highest" -> a[[1]], "Count" -> a[[2]], "Sum" -> a[[3]], "Terms" -> 6|>, "Measured" -> True, "Jobs" -> {"planted"}|>|>;
info[name_, move_, extra_ : <||>] := Join[<|"Rung" -> "simplify", "Name" -> name, "Provenance" -> "planted",
   "Simplify" -> <|"MoveId" -> 1, "Move" -> move, "Title" -> move, "Candidate" -> move <> "1", "BeforeObjective" -> {3, 2, 9}, "AfterObjective" -> {2, 2, 7}|>|>, extra];
ref[n_String, what_String] := "A. Author, B. Author, " <> what <> ", JHEP 01 (2021) 001, arXiv:" <> n;
(* the maximal-cut check Kira would make, planted: it marks the tools MCBCheckBasis marks when it obtains a DE *)
plantedCheck[fam_, sec_, ms_, dir_, o_] := (MCBMarkToolUsed["kira"]; MCBMarkToolUsed["CanonicalDE"];
  <|"points" -> Lookup[o, "Points", {}], "nMastersCut" -> Length[ms], "message" -> "planted", "status" -> "eps-form", "k" -> {0}, "range" -> {1, 1},
    "checks" -> {<|"Name" -> "euler", "Pass" -> True, "Detail" -> "planted"|>}|>);

tests = {};
SetAttributes[add, HoldAll];
add[args__] := AppendTo[tests, VerificationTest[args]];
ledger[d_] := CoreReadCitations[d];
toolRows[d_, s_] := Sort[Lookup[Select[ledger[d], #["kind"] === "tool" && #["sector"] === s &], {"tool", "step"}]];
usesOf[d_, r_String] := Select[ledger[d], #["kind"] === "paper" && #["id"] === CorePaperId[r] &];
lineCount[d_] := With[{f = FileNameJoin[{d, "citations.m"}]}, If[FileExistsQ[f], Length[ReadList[f]], 0]];
listing[d_] := Sort[FileNames["*", d, Infinity]];


(* ::Section:: *)
(*The run's context*)


ctx = newRun["run", False]; dir = ctx["Dir"];
add[Lookup[$CoreCitationContext, {"Dir", "Sector"}], {ExpandFileName[dir], "whole run"}, TestID -> "PFBStartRun: the citation context is the whole run"];


(* ::Section:: *)
(*Changes that are not tried*)


refA = ref["2101.00001", "Planted paper A"]; refB = ref["2101.00002", "Planted paper B"]; refJ = ref["2101.00010", "Planted paper J"];
rN = PFBTryChange[ctx, keyTop, <|1 -> j[sunrise, 1, 1, 0, 0, 0]|>, <|"Rung" -> 4, "Provenance" -> "", "Reference" -> refA|>, <|"Reds" -> {}|>];
add[With[{u = usesOf[dir, refA]}, {rN["Status"], Length[u], Lookup[First[u], {"sector", "rung", "result", "part", "used"}], StringContainsQ[First[u]["outcome"], "own sector only"]}],
  {"not tried", 1, {top, 4, "not tried", "consulted", "a change of the basis (rung 4)"}, True},
  TestID -> "a change not tried (another sector's master): its paper is recorded, consulted, with the reason; an empty Provenance gives the rung"];
add[With[{rT = PFBTryChange[ctx, keyTop, <|3 -> j[sunrise, 1, 1, 1, 0, 0]|>, <|"Rung" -> 4, "Provenance" -> "planted", "Tools" -> {"NotATool"}, "Reference" -> {refB, 42}|>,
      <|"Reds" -> {}|>]}, With[{u = usesOf[dir, refB]}, {rT["Status"], StringContainsQ[rT["Message"], "NotATool"], Lookup[u, "result"], Lookup[u, "part"],
    StringContainsQ[First[u]["outcome"], "NotATool"], MemberQ[Lookup[Select[ledger[dir], #["kind"] === "tool" &], "tool"], "NotATool"]}]],
  {"not tried", True, {"not tried"}, {"consulted"}, True, False}, {PFBTryChange::tools, PFBTryChange::reference},
  TestID -> "an unknown tool in info \"Tools\": not tried, said, nothing recorded for it; its paper recorded; an entry that is no reference is a message"];
rS = PFBTryChange[ctx, None, <|99 -> ut[1]|>, <|"Rung" -> "simplify", "Name" -> "planted", "Provenance" -> "planted", "Reference" -> refJ|>];
add[Lookup[usesOf[dir, refJ], {"sector", "result", "rung"}], {{"whole run", "not tried", "simplify"}},
  TestID -> "a simplification not tried (a master the slice lacks): its paper is recorded for the whole run"];


(* ::Section:: *)
(*A simplification: its papers, its declared tools, the maximal-cut gate's tools*)


refS = ref["2102.00003", "Planted paper S"]; refC = ref["2102.00004", "Planted paper C"];
refD = "D. Author, Planted paper D, Nucl. Phys. B 900 (2015) 1, doi:10.1016/j.nuclphysb.2015.01.001";
gSwap = PFBTryChange[ctx, None, <|2 -> ut[2] + 2 ut[1]|>, info["planted swap of the tadpoles", "swap", <|"Reference" -> refS|>],
   Join[degs[{3, 2, 9}, {2, 2, 7}], <|"AllowPlantedCheck" -> True, "MaxCutCheckOptions" -> <|"Check" -> plantedCheck, "Representations" -> {}|>|>]];
ctx = gSwap["Context"];
gResc = PFBTryChange[ctx, None, <|1 -> (s/m2) ut[1], 3 -> (s/m2) ut[3]|>,
   info["planted rescaling of both sectors", "rescale", <|"Reference" -> {refC, <|"reference" -> refD, "used" -> "the letters of the rescaling"|>}, "Tools" -> {"Libra", "fermat"}|>],
   degs[{2, 2, 7}, {2, 1, 6}]];
ctx = gResc["Context"];
add[{gSwap["Status"], gResc["Status"]}, {"accepted", "accepted"}, TestID -> "the planted simplifications are accepted"];
add[Sort[Lookup[usesOf[dir, refC], {"sector", "result", "change", "part", "rung"}]],
  {{low, "accepted", gResc["Record"]["Id"], "cite", "simplify"}, {top, "accepted", gResc["Record"]["Id"], "cite", "simplify"}},
  TestID -> "a simplification records its reference for the sectors of its masters, with its id and result"];
add[Sort[Lookup[usesOf[dir, refD], {"sector", "used"}]], {{low, "the letters of the rescaling"}, {top, "the letters of the rescaling"}},
  TestID -> "a reference given as <|\"reference\", \"used\"|> keeps its own \"used\""];
add[{Lookup[usesOf[dir, refS], {"sector", "result", "change"}], SubsetQ[toolRows[dir, low], {{"Libra", "declared"}, {"fer64", "declared"}}],
    SubsetQ[toolRows[dir, top], {{"Libra", "declared"}, {"fer64", "declared"}}]},
  {{{low, "accepted", gSwap["Record"]["Id"]}}, True, True}, TestID -> "the tools declared in info \"Tools\" (a display name too) are credited to the change's sectors"];
refR = ref["2102.00013", "Planted paper R"];
gEps = PFBTryRescale[ctx, <|1 -> 1|>, <|"Name" -> "planted eps rescaling", "Provenance" -> "planted", "Reference" -> refR|>];
If[gEps["Status"] === "accepted", ctx = gEps["Context"]];
add[{MemberQ[{"accepted", "rejected"}, gEps["Status"]], Lookup[usesOf[dir, refR], {"sector", "rung", "change", "result"}]},
  {True, {{low, 1, gEps["Record"]["Id"], gEps["Status"]}}}, TestID -> "PFBTryRescale records its reference for the sectors of the masters it rescales, with its id and result"];
add[{SubsetQ[toolRows[dir, low], {{"kira", "maximal-cut gate of a simplification move"}, {"CanonicalDE", "maximal-cut gate of a simplification move"}}],
    MemberQ[Lookup[Select[ledger[dir], #["kind"] === "tool" && #["sector"] =!= low &], "tool"], "kira"]},
  {True, False}, TestID -> "the maximal-cut gate's tools are credited to the sector it checks, not to the run"];
refW = ref["2102.00009", "Planted paper W"];
add[{FileNameTake[PFBRecordLiterature[dir, None, <|"reference" -> refW, "used" -> "a planted use for the whole system"|>]], Lookup[usesOf[dir, refW], "sector"]},
  {"CITATIONS.md", {"whole run"}}, TestID -> "PFBRecordLiterature with key None: the whole run"];


(* ::Section:: *)
(*Approval and decline*)


ctx2 = newRun["approval", True]; dir2 = ctx2["Dir"];
refE = ref["2103.00005", "Planted paper E"]; refF = ref["2103.00006", "Planted paper F"];
gA = PFBTryChange[ctx2, None, <|1 -> (s/m2) ut[1], 3 -> (s/m2) ut[3]|>, info["planted rescaling A", "rescale", <|"Reference" -> refE|>], degs[{3, 2, 9}, {2, 1, 6}]];
ctx2 = gA["Context"];
gB = PFBTryChange[ctx2, None, <|3 -> (s/m2) ut[3]|>, info["planted rescaling B", "rescale", <|"Reference" -> refF|>], degs[{3, 2, 9}, {2, 2, 8}]];
ctx2 = gB["Context"];
before = {Lookup[usesOf[dir2, refE], {"result", "part"}], Lookup[usesOf[dir2, refF], {"result", "part"}]};
ap = PFBApprove[dir2, ctx2["State"], ctx2["System"], gA["Record"]["Id"]];
dc = PFBDecline[dir2, ap["State"], ap["System"], gB["Record"]["Id"], "the user said no (planted)"];
add[{gA["Status"], gB["Status"], before}, {"pending", "pending", {{{"pending", "cite"}, {"pending", "cite"}}, {{"pending", "cite"}}}},
  TestID -> "pending changes: their papers are cited as pending"];
add[{Union[Lookup[usesOf[dir2, refE], {"result", "part"}]], Union[Lookup[usesOf[dir2, refF], {"result", "part", "outcome"}]],
    Sort[Lookup[Select[ReadList[FileNameJoin[{dir2, "citations.m"}]], #["kind"] === "outcome" &], {"change", "result"}]]},
  {{{"accepted", "cite"}}, {{"declined", "consulted", "the user said no (planted)"}}, Sort[{{gA["Record"]["Id"], "accepted"}, {gB["Record"]["Id"], "declined"}}]},
  TestID -> "PFBApprove and PFBDecline append the outcomes: the approved change's papers cited, the declined one's consulted"];


(* ::Section:: *)
(*A maximal-cut-basis run's credits*)


via = "maximal-cut-basis run sunrise_analysis";
viaOf[d_] := Select[ledger[d], Lookup[#, "via", None] === via &];
(* candidates read from the run credit nothing by themselves: only a change that takes one does *)
CoreCitationContext[dir, top, "maximal-cut candidates (rung 8)"];
cands = PFBMaxCutCandidates[ctx["System"], keyTop, <|"MCBRun" -> mcb, "Representations" -> {}, "Routes" -> False, "Replay" -> False|>];
CoreCitationContext[dir, "whole run", "tests"];
add[{AssociationQ[cands], viaOf[dir]}, {True, {}}, TestID -> "rung 8: candidates read from a maximal-cut-basis run credit nothing by themselves"];
(* a run whose family names the maximal-cut-basis run its masters came from: a swap of the tadpoles that the maximal-cut
   gate refuses, and the top master rescaled (every starting master of the top sector replaced) *)
ctx3 = newRun["fromrun", False, mcb]; dir3 = ctx3["Dir"];
norm3 = PFBMCBNormalisations[ctx3["System"], keyTop];
add[{AssociationQ[norm3], viaOf[dir3]}, {True, {}}, TestID -> "move (i): the run's normalisations read credit nothing by themselves"];
plantedRefuse[fam_, sec_, ms_, d_, o_] := <|"points" -> Lookup[o, "Points", {}], "nMastersCut" -> Length[ms], "status" -> "failed",
   "message" -> "the maximal-cut DE breaks the Euler relation of homogeneous integrals", "checks" -> {<|"Name" -> "euler", "Pass" -> False, "Detail" -> "planted"|>}|>;
gRef = PFBTryChange[ctx3, None, <|2 -> ut[2] + 2 ut[1]|>, info["planted swap refused on the cut", "swap"],
   Join[degs[{3, 2, 9}, {2, 2, 7}], <|"AllowPlantedCheck" -> True, "MaxCutCheckOptions" -> <|"Check" -> plantedRefuse, "Representations" -> {}|>|>]];
ctx3 = gRef["Context"];
gTop = PFBTryChange[ctx3, None, <|3 -> (s/m2) ut[3]|>, info["planted rescaling of the top master", "rescale"], degs[{3, 2, 9}, {2, 2, 8}]];
ctx3 = gTop["Context"];
PFBMakeReports[dir3, ctx3["System"], ctx3["State"]];
n3 = lineCount[dir3];
PFBMakeReports[dir3, ctx3["System"], ctx3["State"]];
md3 = Import[FileNameJoin[{dir3, "CITATIONS.md"}], "Text"];
add[{gRef["Status"], gTop["Status"]}, {"rejected", "accepted"}, TestID -> "the planted changes of the run with \"MCBRun\": the swap refused on the cut, the top master rescaled"];
add[Lookup[Select[viaOf[dir3], KeyExistsQ[#, "change"] &], {"tool", "sector", "change", "part"}], {{"DlogBasis", low, gRef["Record"]["Id"], "consulted"}},
  TestID -> "the maximal-cut gate: the run's credits of the sector it checked go with the change, consulted when the change is rejected"];
add[{Lookup[Select[viaOf[dir3], KeyExistsQ[#, "start"] && #["sector"] === low &], {"tool", "sector", "start", "part"}],
    With[{t = Select[viaOf[dir3], #["sector"] === top &]}, t =!= {} && AllTrue[t, KeyExistsQ[#, "start"] && #["part"] === "cite" &]]},
  {{{"DlogBasis", low, {1, 2}, "cite"}}, True},
  TestID -> "decision 5: the family's MCBRun is credited for a sector that keeps its starting masters, a rescaled one included"];
(* the same run, but the top master replaced by a change that is not a rescale: no start credit for the top sector *)
ctx4 = newRun["fromrun4", False, mcb]; dir4 = ctx4["Dir"];
PFBStartCredits[dir4, ctx4["System"], Join[ctx4["State"], <|"Accepted" -> {<|"Id" -> 1, "Kind" -> "change", "Replace" -> {3}, "NewDefs" -> <|3 -> ut[3] + ut[1]|>|>}|>]];
add[{Select[viaOf[dir4], #["sector"] === top &], Union[Lookup[Select[viaOf[dir4], #["sector"] === low &], "tool"]]}, {{}, {"DlogBasis"}},
  TestID -> "decision 5: no start credit for a sector whose starting masters were all replaced"];
(* every write of CITATIONS.md credits the starting masters' run first: here a change with a paper, before any report *)
ctx5 = newRun["fromrun5", False, mcb]; dir5 = ctx5["Dir"];
g5 = PFBTryChange[ctx5, None, <|3 -> (s/m2) ut[3]|>, info["planted rescaling with a paper", "rescale", <|"Reference" -> ref["2107.00014", "Planted paper T"]|>],
   degs[{3, 2, 9}, {2, 2, 8}]];
md5 = Quiet@Import[FileNameJoin[{dir5, "CITATIONS.md"}], "Text"];
add[{g5["Status"], FileExistsQ[FileNameJoin[{dir5, "summary.html"}]], StringQ[md5] && AllTrue[{"- **BaikovPackage**", "- **DlogBasis**", via}, StringContainsQ[md5, #] &]},
  {"accepted", False, True}, TestID -> "every write of CITATIONS.md credits the family's MCBRun first: after a change, before any report"];
add[{n3 === lineCount[dir3], Length[StringCases[md3, "- **DlogBasis**"]], StringContainsQ[First[StringSplit[md3, "## Also consulted"]], "- **DlogBasis**"],
    Sort[FileNames["*", mcb, Infinity]] === mcbBefore},
  {True, 1, True, True}, TestID -> "a sector's start import and change import are one tool in CITATIONS.md, cited; a report imports nothing twice; the given run is never written into"];


(* ::Section:: *)
(*The lines of a reduction job*)


jobT = <|"Name" -> "sunrise_j11100", "SectorKey" -> keyTop|>;
add[PFBJobCitationEntries[jobT, PFBJobTools["Kira"], "2026-01-02"],
  (<|"kind" -> "tool", "tool" -> #, "sector" -> top, "step" -> "reduction job sunrise_j11100", "date" -> "2026-01-02"|> &) /@ {"kira", "fer64", "LiteRed", "LiteIBP"},
  TestID -> "job lines: a point Kira reduced credits Kira, Fermat, LiteRed and LiteIBP to the job's sector"];
add[{PFBJobTools["FiniteFlow"], PFBJobTools["Identities"], PFBJobTools["a fallback"], PFBJobSector[<|"Name" -> "local_slice", "SectorKey" -> None|>],
    PFBJobStep[<|"Name" -> "x_rel1", "LearnOnly" -> True|>], PFBJobStep[<|"Name" -> "deg_x", "Degrees" -> <||>|>], PFBJobStep[<|"Name" -> "detline_1", "Line" -> <||>|>],
    PFBJobStep[<|"Name" -> "x_a", "Analytic" -> <||>|>]},
  {{"FiniteFlow", "LiteRed", "LiteIBP"}, {"LiteRed", "LiteIBP"}, {}, "whole run", "learn-only job x_rel1", "degree job deg_x", "line job detline_1", "analytic job x_a"},
  TestID -> "job lines: the tools of FiniteFlow's points and of identities, the whole run without a sector, the step names the job"];
jd = FileNameJoin[{dir, "jobs", "sunrise_j11100"}]; CreateDirectory[jd, CreateIntermediateDirectories -> True];
jdOut = FileNameJoin[{tmp, "norun", "jobs", "x"}]; CreateDirectory[jdOut, CreateIntermediateDirectories -> True];
add[{FileNameTake[PFBAppendJobCitations[jd, PFBJobCitationEntries[jobT, PFBJobTools["FiniteFlow"]]]], PFBAppendJobCitations[FileNameJoin[{tmp, "elsewhere"}], {}],
    PFBAppendJobCitations[jdOut, PFBJobCitationEntries[jobT, PFBJobTools["FiniteFlow"]]], FileExistsQ[FileNameJoin[{tmp, "norun", "citations.m"}]],
    Select[toolRows[dir, top], #[[2]] === "reduction job sunrise_j11100" &]},
  {"citations.m", None, None, False, Sort[{{"FiniteFlow", "reduction job sunrise_j11100"}, {"LiteIBP", "reduction job sunrise_j11100"}, {"LiteRed", "reduction job sunrise_j11100"}}]},
  TestID -> "job lines: appended to <run>/citations.m (the job folder's grandparent, a pole-free run) and read back for the sector; nothing outside a run"];
(* the runner's credits, as it makes them (PFBJobCredit): Kira writes red_1.m, then FiniteFlow reduces point 1 again;
   the run ends with exit 4, and the rerun starts from status.m "Tools" *)
jobK = <|"Name" -> "sunrise_j11100_k", "SectorKey" -> keyTop|>;
jk = FileNameJoin[{dir4, "jobs", "sunrise_j11100_k"}]; CreateDirectory[jk, CreateIntermediateDirectories -> True];
c0 = PFBJobPreviousTools[jk];
c1 = PFBJobCredit[jk, jobK, c0, "Kira"];
c2 = PFBJobCredit[jk, jobK, c1, "FiniteFlow"];
Put[<|"Status" -> "nonut-hosts", "Tools" -> c2|>, FileNameJoin[{jk, "status.m"}]];
c3 = PFBJobCredit[jk, jobK, PFBJobPreviousTools[jk], "FiniteFlow"];
rowsK = Lookup[Select[ReadList[FileNameJoin[{dir4, "citations.m"}]], #["kind"] === "tool" && #["step"] === "reduction job sunrise_j11100_k" &], "tool"];
add[{c0, c1, c2, c3, Sort[rowsK]}, {{}, {"kira", "fer64", "LiteRed", "LiteIBP"}, {"kira", "fer64", "LiteRed", "LiteIBP", "FiniteFlow"},
    {"kira", "fer64", "LiteRed", "LiteIBP", "FiniteFlow"}, Sort[{"kira", "fer64", "LiteRed", "LiteIBP", "FiniteFlow"}]},
  TestID -> "a job's credits: Kira once its red_1.m is written, FiniteFlow when it reduces point 1 again, each once; a rerun keeps the earlier run's in status.m"];
(* job.m keeps the sector key for the runner (no tool runs: their paths are planted) *)
jw = Block[{$MCBPaths = Join[KeyDrop[$MCBPaths, {"kira", "fer64"}], <|"FiniteFlow" -> $InputFileName, "LiteRed" -> $InputFileName, "LiteIBP" -> $InputFileName|>]},
   PFBSubtreeJob[ctx["System"], dir, <|"Name" -> "planted_job", "SectorKey" -> keyTop, "Points" -> {P}, "Derivatives" -> {s}, "Reducer" -> "FiniteFlow"|>]];
add[With[{jm = Quiet@Get[FileNameJoin[{jw, "job.m"}]]}, {jm["SectorKey"], PFBJobSector[jm]}], {keyTop, top}, TestID -> "job.m keeps \"SectorKey\": the runner credits that sector"];


(* ::Section:: *)
(*conventions.wl "Credits"*)


refH = ref["2105.00008", "Planted paper H"]; refI = ref["2105.00011", "Planted paper I"];
convFile = FileNameJoin[{tmp, "conventions.wl"}];
Put[<|"File" -> "slice.m", "Derivatives" -> {s}, "Credits" -> {"Kira", <|"reference" -> refH, "used" -> "the DE of the planted family"|>, <|"reference" -> refI|>}|>, convFile];
conv = PFBReadConventions[convFile];
add[PFBSliceCredits[conv], <|"Tools" -> {"kira"}, "Papers" -> {<|"reference" -> refH, "used" -> "the DE of the planted family"|>,
    <|"reference" -> refI, "used" -> "the starting differential equation"|>}|>, TestID -> "conventions.wl \"Credits\": tools (a display name too) and papers read"];
add[{AllTrue[{"NotATool", "FiniteFlow"}, StringContainsQ[PFBSliceCredits[<|"Credits" -> {"NotATool"}|>], #] &], PFBRecordSliceCredits[dir, <|"Credits" -> {"NotATool", 7}|>]},
  {True, $Failed}, {PFBRecordSliceCredits::refused}, TestID -> "conventions.wl \"Credits\": an unknown name refuses them, with the known names"];
PFBRecordSliceCredits[dir, conv];
add[{MemberQ[toolRows[dir, "whole run"], {"kira", "the starting DE"}], Sort[Lookup[Join[usesOf[dir, refH], usesOf[dir, refI]], {"sector", "rung", "part"}]]},
  {True, {{"whole run", "the starting DE", "cite"}, {"whole run", "the starting DE", "cite"}}}, TestID -> "conventions.wl \"Credits\": credited to the whole run, the starting DE"];


(* ::Section:: *)
(*FiniteFlow in this kernel*)


CoreCitationContext[dir, low, "planted residue fit"];
r1 = Block[{PFBLoadFiniteFlow}, PFBLoadFiniteFlow[] := False; PFBSolveLinear[{x1 + x2 - 1, x1 - x2}, {x1, x2}]];
ff1 = MemberQ[toolRows[dir, low], {"FiniteFlow", "planted residue fit"}];
r2 = Block[{PFBLoadFiniteFlow, FiniteFlow`FFSparseSolve}, PFBLoadFiniteFlow[] := True; FiniteFlow`FFSparseSolve[e_, v_, ___] := First[Solve[e, v]];
   PFBSolveLinear[{x1 + x2 - 1, x1 - x2}, {x1, x2}]];
CoreCitationContext[dir, "whole run", "tests"];
add[{r1["Solution"], ff1, r2["Solution"], MemberQ[toolRows[dir, low], {"FiniteFlow", "planted residue fit"}]}, {{x1 -> 1/2, x2 -> 1/2}, False, {x1 -> 1/2, x2 -> 1/2}, True},
  TestID -> "PFBSolveLinear: FiniteFlow is credited to the context's sector when its solver ran, not for the fallback"];


(* ::Section:: *)
(*CITATIONS.md, CHANGES.md, the pages*)


st = ctx["State"]; sys = ctx["System"];
summaryFile = PFBMakeReports[dir, sys, st];
md = Import[FileNameJoin[{dir, "CITATIONS.md"}], "Text"];
changes = Import[FileNameJoin[{dir, "CHANGES.md"}], "Text"];
summary = Import[summaryFile, "Text"];
cite = CoreCiteMarkdown[dir];
add[{cite =!= "", StringContainsQ[md, "## Cite\n\n" <> cite], StringContainsQ[changes, "## Credits"], StringContainsQ[changes, StringTrim[cite]], StringFreeQ[changes, "Literature used"],
    StringContainsQ[md, "## Not covered by this file"], FileExistsQ[FileNameJoin[{dir, "LITERATURE.md"}]]},
  {True, True, True, True, True, True, False}, TestID -> "CHANGES.md: its Credits are the Cite part of CITATIONS.md"];
(* CITATIONS.md read back per sector: the tools whose sectors include s, the papers with a use in s *)
blocks[t_] := Module[{out = {}, cur = None},
  Do[Which[StringStartsQ[l, "- "], If[cur =!= None, AppendTo[out, cur]]; cur = {StringDrop[l, 2], {}},
     StringStartsQ[l, "  - "] && cur =!= None, cur[[2]] = Append[cur[[2]], StringDrop[l, 4]]], {l, StringSplit[t, "\n"]}];
  If[cur =!= None, AppendTo[out, cur]]; out];
mdTools[s_] := Sort[Cases[blocks[md], {h_String /; StringStartsQ[h, "**"] && StringContainsQ[Last[StringSplit[h, "Sectors: "]], s], _} :>
   First[StringCases[h, "**" ~~ t : Shortest[__] ~~ "**" :> t]]]];
mdPapers[s_] := Union[Cases[blocks[md], {h_String /; ! StringStartsQ[h, "**"], u_ /; AnyTrue[u, StringStartsQ[#, s] &]} :> h]];
pageOf[k_] := Import[FileNameJoin[{PFBSectorDir[dir, k], "sector.html"}], "Text"];
citesOf[pg_] := With[{p = StringSplit[pg, "<h2>Citations</h2>"]}, If[Length[p] < 2, "", First[StringSplit[p[[2]], "<p><a href="]]]];
pageTools[k_] := Sort[StringCases[citesOf[pageOf[k]], "<li><b>" ~~ t : Shortest[__] ~~ "</b>" :> t]];
pagePapers[k_] := Union[StringCases[citesOf[pageOf[k]], "<li>" ~~ r : (Except["<"] ~~ Shortest[___]) ~~ " &mdash; " :> r]];
add[{pageTools[keyLow] === mdTools[low], pageTools[keyTop] === mdTools[top], MemberQ[pageTools[keyLow], "Kira"], MemberQ[pageTools[keyTop], "Kira"]},
  {True, True, True, False}, TestID -> "sector pages: the tools of CITATIONS.md for the sector, no other's"];
add[{pagePapers[keyLow] === mdPapers[low], pagePapers[keyTop] === mdPapers[top], SubsetQ[pagePapers[keyTop], {refA, refB, refC, refD}], MemberQ[pagePapers[keyTop], refS]},
  {True, True, True, False}, TestID -> "sector pages: the papers of CITATIONS.md for the sector, cited and consulted"];
add[{StringContainsQ[summary, "Cite &mdash;"], StringContainsQ[summary, refC], StringContainsQ[summary, "Also consulted"], StringContainsQ[summary, "CITATIONS.md"]},
  {True, True, True, True}, TestID -> "summary: what to cite and what was consulted, pointing to CITATIONS.md"];

report = TestReport[tests];
Do[With[{r = report["TestResults"][id]},
    Print[If[r["Outcome"] === "Success", "PASS ", "FAIL "], r["TestID"], If[r["Outcome"] === "Success", "",
      "\n     got " <> ToString[Short[r["ActualOutput"], 3], InputForm] <> "\n     expected " <> ToString[Short[r["ExpectedOutput"], 3], InputForm] <>
        If[r["Outcome"] === "MessagesFailure", "\n     messages " <> ToString[r["ActualMessages"], InputForm], ""]]]],
  {id, Keys[report["TestResults"]]}];
Print[report["TestsSucceededCount"], " passed, ", report["TestsFailedCount"], " failed, ", Round[report["TimeElapsed"], 0.1]];
DeleteDirectory[tmp, DeleteContents -> True];
Exit[If[report["AllTestsSucceeded"], 0, 1]];
