#!/usr/bin/env wolframscript
(* Records and reports of simplifications, which have no sector key, without FiniteFlow or IBP. Planted data: the
   two-loop equal-mass sunrise of the maximal-cut-basis examples (unit scale m2, derivative d/ds) with two planted
   masters in the sector of the two tadpoles (labels 1 and 2) and one in the top sector (label 3), a planted slice, and
   two simplifications through the gate with planted measured degrees: a swap of the two tadpole masters that changes
   their maximal cut, and a rescaling of masters of both sectors.
   Checked: the sectors of a change (PFBChangeKeys), summary.html with a change of the maximal cut that has no key, the
   sector pages and statuses of the sectors whose masters a simplification changed, CHANGES.md, and the det T job of a
   simplification (bin/det_line.wls): in the sector of the masters it replaced, or the one named when it replaced
   masters of several sectors.
   usage: bin/ws tests/simplify_records.wls        exit code 0 when every test passes *)
Get[FileNameJoin[{ParentDirectory[DirectoryName[$InputFileName]], "lib", "PoleFreeBasis.wl"}]];
$PFBVerbose = False;
sunFile = FileNameJoin[{ParentDirectory[$PFBRoot], "maximal-cut-basis", "examples", "sunrise-equal-mass", "family.wl"}];
keyLow = {sunrise, {1, 1, 0, 0, 0}}; keyTop = {sunrise, {1, 1, 1, 0, 0}};
P = {s -> 3/7, m2 -> 1};
masters = {j[sunrise, 1, 1, 0, 0, 0], m2 j[sunrise, 2, 1, 0, 0, 0], j[sunrise, 1, 1, 1, 0, 0]};
tmp = CreateDirectory[];
dir = FileNameJoin[{tmp, "run"}];
CreateDirectory[dir, CreateIntermediateDirectories -> True];
Put[masters, FileNameJoin[{dir, "masters.m"}]];
Put[<|"Name" -> "planted", "Families" -> {<|"Name" -> "sunrise", "Family" -> sunFile, "Masters" -> "masters.m"|>}, "Letters" -> {s, m2, s - m2, s - 9 m2}|>,
  FileNameJoin[{dir, "system.wl"}]];
Put[<|"System" -> "system.wl", "OutputDir" -> FileNameJoin[{dir, "out"}], "AllowTmp" -> True, "Paths" -> Automatic|>, FileNameJoin[{dir, "run.wl"}]];
ctx = PFBStartRun[FileNameJoin[{dir, "run.wl"}]];
R = {{-2 + eps, 3/5, 0}, {7/3 eps, -1 - 2 eps, 0}, {5/11 + eps, 0, -3 + eps}};
sl = <|"R" -> {R}, "Derivatives" -> {s}, "Point" -> P, "Labels" -> {1, 2, 3}, "Index" -> <|1 -> 1, 2 -> 2, 3 -> 3|>, "Frame" -> "RootFree", "History" -> {}|>;
ctx = Join[ctx, <|"State" -> PFBStoreSlice[ctx["Dir"], ctx["State"], sl, PFBCensus[ctx["System"], sl], "planted"]|>];
degs[b_, a_] := <|"Degrees" -> <|"Before" -> <|"Highest" -> b[[1]], "Count" -> b[[2]], "Sum" -> b[[3]], "Terms" -> 6|>,
    "After" -> <|"Highest" -> a[[1]], "Count" -> a[[2]], "Sum" -> a[[3]], "Terms" -> 6|>, "Measured" -> True, "Jobs" -> {"planted"}|>|>;
info[name_, move_] := <|"Rung" -> "simplify", "Name" -> name, "Provenance" -> "planted",
   "Simplify" -> <|"MoveId" -> 1, "Move" -> move, "Title" -> move, "Candidate" -> move <> "1", "BeforeObjective" -> {3, 2, 9}, "AfterObjective" -> {2, 2, 7}|>|>;
(* the swap: the second tadpole master takes a part of the first (a change of their maximal cut), so it passes the
   maximal-cut gate too: a planted verdict, as Kira would give it for an eps-form cut *)
plantedCheck[fam_, sec_, ms_, dir_, o_] := <|"points" -> Lookup[o, "Points", {}], "nMastersCut" -> Length[ms], "message" -> "planted", "status" -> "eps-form",
   "k" -> {0}, "range" -> {1, 1}, "checks" -> {<|"Name" -> "euler", "Pass" -> True, "Detail" -> "planted"|>}|>;
gSwap = PFBTryChange[ctx, None, <|2 -> ut[2] + 2 ut[1]|>, info["planted swap of the tadpoles", "swap"],
   Join[degs[{3, 2, 9}, {2, 2, 7}], <|"AllowPlantedCheck" -> True, "MaxCutCheckOptions" -> <|"Check" -> plantedCheck, "Representations" -> {}|>|>]];
ctx = gSwap["Context"];
(* a rescaling of masters of both sectors *)
gResc = PFBTryChange[ctx, None, <|1 -> (s/m2) ut[1], 3 -> (s/m2) ut[3]|>, info["planted rescaling of both sectors", "rescale"], degs[{2, 2, 7}, {2, 1, 6}]];
ctx = gResc["Context"];
st = ctx["State"]; sys = ctx["System"];
recSwap = SelectFirst[st["Accepted"], #["Id"] == gSwap["Record"]["Id"] &, <||>];
recResc = SelectFirst[st["Accepted"], #["Id"] == gResc["Record"]["Id"] &, <||>];
(* the reports *)
msgs = Block[{$MessageList = {}}, summaryFile = PFBMakeReports[ctx["Dir"], sys, st]; $MessageList];
summaryText = If[StringQ[summaryFile] && FileExistsQ[summaryFile], Import[summaryFile, "Text"], ""];
pageOf[key_] := With[{f = FileNameJoin[{PFBSectorDir[ctx["Dir"], key], "sector.html"}]}, If[FileExistsQ[f], Import[f, "Text"], ""]];
linkOf[key_] := ToString[key[[1]]] <> "/" <> SectorName[key[[2]]] <> "/sector.html";
changesText = Quiet@Import[FileNameJoin[{ctx["Dir"], "CHANGES.md"}], "Text"];
statusOf[key_] := Lookup[MCBReadBasis[PFBSectorDir[ctx["Dir"], key]], "status", None];
(* det T of the simplifications: the specification of the line job PFBDetLineJob writes (PFBSubtreeJob stands in, so
   that no tool is needed to write it) *)
lineJob[args__] := Block[{PFBSubtreeJob}, PFBSubtreeJob[_, _, spec_Association] := spec; PFBDetLineJob[args]];
jdSwap = lineJob[ctx, recSwap["Id"]];
jdResc = Block[{Print}, lineJob[ctx, recResc["Id"]]];
jdRescTop = lineJob[ctx, recResc["Id"], <|"Key" -> keyTop|>];
lineOf[jd_] := If[AssociationQ[jd], Lookup[jd, "Line", <||>], <||>];

tests = {
  VerificationTest[{gSwap["Status"], recSwap["Key"], TrueQ[recSwap["MaxCutChanged"]], gResc["Status"], TrueQ[recResc["MaxCutChanged"]]}, {"accepted", None, True, "accepted", False},
    TestID -> "the planted simplifications: a swap that changes the maximal cut, a rescaling of two sectors"],
  VerificationTest[{PFBChangeKeys[sys, recSwap], PFBChangeKeys[sys, recResc], PFBChangeKeys[sys, <|"Key" -> keyTop, "Rung" -> 6|>], PFBChangeKeys[sys, <|"Key" -> None, "Rung" -> 1, "Replace" -> {1}|>]},
    {{keyLow}, {keyLow, keyTop}, {keyTop}, {}}, TestID -> "change keys: the sectors of the masters a simplification replaced"],
  (* the summary with a change of the maximal cut that has no key *)
  VerificationTest[{StringQ[summaryFile], StringFreeQ[ToString[msgs], "Part::" | "StringJoin::"], StringContainsQ[summaryText, "Maximal-cut basis changes (1)"],
      StringContainsQ[summaryText, "<a href='" <> linkOf[keyLow] <> "'>"], StringContainsQ[summaryText, "planted swap of the tadpoles"]}, {True, True, True, True, True},
    TestID -> "summary: a simplification that changed the maximal cut links to the sector of its masters"],
  (* sector pages and statuses *)
  VerificationTest[{StringContainsQ[pageOf[keyLow], "The maximal-cut basis of this sector was changed"], StringContainsQ[pageOf[keyLow], "planted swap of the tadpoles"],
      StringContainsQ[pageOf[keyLow], "planted rescaling of both sectors"], StringContainsQ[pageOf[keyTop], "planted rescaling of both sectors"],
      StringContainsQ[pageOf[keyTop], "planted swap of the tadpoles"], statusOf[keyLow]}, {True, True, True, True, False, "pole-free (maximal cut changed)"},
    TestID -> "sector pages: a simplification appears on the pages of the sectors whose masters it changed"],
  VerificationTest[{StringQ[changesText], StringContainsQ[changesText, "- **" <> PFBSectorString[keyLow] <> "** (change " <> ToString[recSwap["Id"]]],
      StringContainsQ[changesText, "| " <> ToString[recResc["Id"]] <> " | `" <> PFBSectorString[keyLow] <> "`, `" <> PFBSectorString[keyTop] <> "` |"]}, {True, True, True},
    TestID -> "CHANGES.md: simplifications listed under the sectors of their masters"],
  (* det T along a line *)
  VerificationTest[{AssociationQ[jdSwap], lineOf[jdSwap]["Key"], lineOf[jdSwap]["Changed"], jdResc, AssociationQ[jdRescTop], lineOf[jdRescTop]["Key"], lineOf[jdRescTop]["Changed"]},
    {True, keyLow, {2}, $Failed, True, keyTop, {3}}, TestID -> "det_line: a simplification in the sector of its masters; one of several sectors needs the sector"]
};

report = TestReport[tests];
Do[With[{r = report["TestResults"][id]},
    Print[If[r["Outcome"] === "Success", "PASS ", "FAIL "], r["TestID"], If[r["Outcome"] === "Success", "",
      "\n     got " <> ToString[Short[r["ActualOutput"], 3], InputForm] <> "\n     expected " <> ToString[Short[r["ExpectedOutput"], 3], InputForm]]]],
  {id, Keys[report["TestResults"]]}];
Print[report["TestsSucceededCount"], " passed, ", report["TestsFailedCount"], " failed, ", Round[report["TimeElapsed"], 0.1]];
DeleteDirectory[tmp, DeleteContents -> True];
Exit[If[report["AllTestsSucceeded"], 0, 1]];
