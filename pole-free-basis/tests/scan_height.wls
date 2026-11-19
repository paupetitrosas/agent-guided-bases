#!/usr/bin/env wolframscript
(* The digit height in the scan key and in the ranking of the maximal-cut finalists, on planted scan results (no
   reduction, no Kira). The digit height of the sector's rows ("height", PFBRowsDigitHeight) is a free proxy for their
   kinematic degree: it orders only sets equal on every other key. Checked: PFBScanKey ends with it, so a set with a
   lower power of eps ranks first whatever its height, and equal sets go by height; PFBMaxCutRank ranks finalists by
   the full rows, then by the maximal cut's tie-breaks (eps-form on the cut, the spread, the all-dot flag), and by the
   height only after these, then the scan's order.
   usage: bin/ws tests/scan_height.wls        exit code 0 when every test passes *)
Get[FileNameJoin[{ParentDirectory[DirectoryName[$InputFileName]], "lib", "PoleFreeBasis.wl"}]];
$PFBVerbose = False;
(* a scan result that clears the sector's rows, with the keys PFBScanSets writes *)
row[extra_ : <||>] := Join[<|"bad" -> 0, "newBad" -> 0, "over" -> 0, "zero" -> 0, "high" -> 0, "deferred" -> 0, "dCensus" -> -2, "neg" -> 0, "deg" -> 1, "height" -> 40|>, extra];
verd[st_, sp_] := <|"Check" -> st, "Spread" -> sp, "AllDot" -> False, "NonDlog" -> True, "Refuses" -> False|>;
names[ents_] := Lookup[PFBMaxCutRank[ents], "Name"];
tests = {
  VerificationTest[{Last[PFBScanKey[row[]]], Last[PFBScanKey[KeyDrop[row[], "height"]]]}, {40, Infinity},
    TestID -> "PFBScanKey: the digit height is the last key, a missing one the worst"],
  VerificationTest[Lookup[SortBy[{row[<|"height" -> 12, "name" -> "deg 1, light"|>], row[<|"deg" -> 0, "height" -> 95, "name" -> "deg 0, heavy"|>],
      row[<|"height" -> 8, "name" -> "deg 1, lighter"|>]}, PFBScanKey], "name"],
    {"deg 0, heavy", "deg 1, lighter", "deg 1, light"},
    TestID -> "PFBScanKey: a lower power of eps first whatever the height; equal sets by height"],
  (* finalists: equal rows, the eps-form one heavier: eps-form first *)
  VerificationTest[names[{<|"Result" -> row[<|"height" -> 10|>], "Verdict" -> verd["eps-polynomial", 1], "Name" -> "eps-polynomial, light"|>,
      <|"Result" -> row[<|"height" -> 50|>], "Verdict" -> verd["eps-form", 0], "Name" -> "eps-form, heavy"|>}],
    {"eps-form, heavy", "eps-polynomial, light"},
    TestID -> "finalists: eps-form on the cut before the digit height"],
  (* finalists: equal rows and equal verdicts: the lighter first, against the scan's order *)
  VerificationTest[names[{<|"Result" -> row[<|"height" -> 50|>], "Verdict" -> verd["eps-form", 0], "Name" -> "heavy"|>,
      <|"Result" -> row[<|"height" -> 10|>], "Verdict" -> verd["eps-form", 0], "Name" -> "light"|>}],
    {"light", "heavy"},
    TestID -> "finalists: the digit height orders sets equal on the rows and on the cut"],
  (* finalists: a lower power of eps in the rows wins over the cut and the height *)
  VerificationTest[names[{<|"Result" -> row[<|"height" -> 10|>], "Verdict" -> verd["eps-form", 0], "Name" -> "deg 1, eps-form, light"|>,
      <|"Result" -> row[<|"deg" -> 0, "height" -> 90|>], "Verdict" -> verd["eps-polynomial", 2], "Name" -> "deg 0"|>}],
    {"deg 0", "deg 1, eps-form, light"},
    TestID -> "finalists: the full rows before the cut's tie-breaks and the height"]};
report = TestReport[tests];
Do[With[{r = report["TestResults"][id]},
    Print[If[r["Outcome"] === "Success", "PASS ", "FAIL "], r["TestID"], If[r["Outcome"] === "Success", "",
      "\n     got " <> ToString[Short[r["ActualOutput"], 3], InputForm] <> "\n     expected " <> ToString[Short[r["ExpectedOutput"], 3], InputForm]]]],
  {id, Keys[report["TestResults"]]}];
Print[report["TestsSucceededCount"], " passed, ", report["TestsFailedCount"], " failed, ", Round[report["TimeElapsed"], 0.1]];
Exit[If[report["AllTestsSucceeded"], 0, 1]];
