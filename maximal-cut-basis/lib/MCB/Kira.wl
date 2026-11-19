(* ::Package:: *)

(* ::Title:: *)
(*MaximalCutBasis`Kira`: maximal-cut reductions at numeric points, master counting*)


(* ::Text:: *)
(*Every reduction is a Kira job on the maximal cut of one sector (cut_propagators = the sector*)
(*propagators, top_level_sectors = the sector).  The invariants are fixed with --set_value; the*)
(*dimension stays symbolic and is replaced TEXTUALLY by (D0 - 2 eps) before parsing, so that no*)
(*package symbol called d can capture it.  Kira's masters file only lists the masters needed by the*)
(*targets of that job: MCBCutMasters seeds a generous target list to recount them on the cut.*)


BeginPackage["MaximalCutBasis`Kira`", {"MaximalCutBasis`", "SkillCore`Tools`", "SkillCore`Records`", "SkillCore`Pages`", "MaximalCutBasis`Family`",
   "MaximalCutBasis`Sectors`", "MaximalCutBasis`Derivatives`"}];

MCBKiraJob::usage = "MCBKiraJob[fam, sector, ints, dir] writes the Kira config (maximal cut of sector), the target list and job.yaml into dir. Returns {rmax, smax} of the targets.";
MCBKiraReduce::usage = "MCBKiraReduce[fam, dir, point] runs Kira in dir with --set_value for every rule of point. Returns <|\"rules\" -> Dispatch, \"masters\" -> list, \"unreduced\" -> n, \"ok\" -> True/False|>.";
MCBKiraCutReduce::usage = "MCBKiraCutReduce[fam, sector, ints, dir, point] = job + reduction; returns {rules, masters}. The job folder dir is deleted once the result is read (kept when Kira failed, or with $MCBKeepScratch).";
MCBCutMasters::usage = "MCBCutMasters[fam, sector, dir, point] recounts the masters on the maximal cut of sector and compares with the user's list. Returns <|\"masters\", \"n\", \"userMasters\", \"extra\", \"rules\", \"point\"|>; \"rules\" reduce the pool it counted with (every integral of the sector with up to two dots and numerator degree two in every ISP) at the point.";
MCBPoints::usage = "MCBPoints[fam, n, seed, avoid] returns n random rational points avoiding zeros of the external Gram determinant, of the invariants and of the polynomials in avoid.";
MCBReduceTo::usage = "MCBReduceTo[expr, point, rules, masters] reduces a combination at a point onto the masters; returns the coefficient list, or $Failed when an integral of it was left unreduced.";
MCBScalingSelfTest::usage = "MCBScalingSelfTest[fam, sectors, dir] reduces the scaling residue of the corner integral (and of one dotted integral) on the maximal cut of each sector. Returns a list of <|\"sector\", \"ok\", \"residue\"|>.";
MCBFindMastersKira::usage = "MCBFindMastersKira[fam, dir, point, <|\"TopLevel\" -> id or {ids}, \"r\" -> r, \"s\" -> s|>] runs Kira on the whole family (no cut, run_initiate: masters) at a numeric point and returns the masters it finds (for families given without a masters list). The top sectors default to those of the family (family.wl \"TopSectors\", else the lines of \"Graph\", else every line), r to one more than their largest number of lines.";
MCBKiraAvailableQ::usage = "MCBKiraAvailableQ[] is True when kira (and fer64) are configured.";
$MCBKiraTimeLimit::usage = "$MCBKiraTimeLimit is the time limit (seconds) of one Kira run (run.wl \"TimeLimits\" -> \"Kira\"; None = no limit).";
$MCBKiraMemoryLimit::usage = "$MCBKiraMemoryLimit is the memory limit (GB) of one Kira run, Fermat included (run.wl \"MemoryLimits\" -> \"Kira\"; None = no limit). Automatic (the default): 90% of what this kernel's own job may still use (MCBMemoryHeadroom), so that Kira is stopped before the kernel is.";

Begin["`Private`"];

$MCBKiraTimeLimit = 3600;
$MCBKiraMemoryLimit = Automatic;

(* the memory limit of the next Kira run, in GB (Automatic: limit's default) *)
kiraMemory[] := Which[NumericQ[$MCBKiraMemoryLimit] || $MCBKiraMemoryLimit === None, $MCBKiraMemoryLimit,
  True, With[{h = MCBMemoryHeadroom[]}, Which[h === Infinity, None, NumericQ[h], Max[0.25, 0.9 h], True, Automatic]]];

MCBKiraAvailableQ[] := MCBAvailableQ["kira"];

kiraInt[j[_, a__]] := "[" <> StringRiffle[ToString /@ {a}, ","] <> "]";

MCBKiraJob[fam_Association, s_List, ints_List, dir_String] := Module[{sid = SectorID[s], rmax, smax, nm = fam["NameString"]},
  If[! DirectoryQ[dir], CreateDirectory[dir, CreateIntermediateDirectories -> True]];
  MCBToKiraYAML[fam, dir, <|"Cut" -> s|>];
  rmax = Max[1, Max[Total[Select[List @@ Rest[#], Positive]] & /@ ints]];
  smax = Max[0, Max[-Total[Select[List @@ Rest[#], Negative]] & /@ ints]];
  Export[FileNameJoin[{dir, "target"}], StringRiffle[(nm <> kiraInt[#]) & /@ ints, "\n"] <> "\n", "Text"];
  Export[FileNameJoin[{dir, "job.yaml"}], StringJoin[
    "jobs:\n",
    "  - reduce_sectors:\n",
    "      reduce:\n",
    "        - {topologies: [", nm, "], sectors: [", ToString[sid], "], r: ", ToString[rmax + 1], ", s: ", ToString[smax + 1], "}\n",
    "      select_integrals:\n",
    "        select_mandatory_list:\n",
    "          - [", nm, ", target]\n",
    "      run_initiate: true\n",
    "      run_triangular: true\n",
    "      run_back_substitution: true\n",
    "  - kira2math:\n",
    "      target:\n",
    "        - [", nm, ", target]\n"], "Text"];
  {rmax, smax}];

(* Kira output text -> expression: integrals, dimension and invariant names are all replaced by full names *)
parseKira[fam_Association, txt_String] := Module[{t = txt, rules},
  t = StringReplace[t, RegularExpression["\\b" <> fam["NameString"] <> "\\["] -> "MaximalCutBasis`Kira`Private`kint["];
  t = StringReplace[t, RegularExpression["\\bd\\b"] -> "(" <> ToString[fam["D0"]] <> "-2*MaximalCutBasis`eps)"];
  rules = Table[RegularExpression["\\b" <> MCBKiraName[fam, X] <> "\\b"] -> "(" <> (Context @@ {X}) <> SymbolName[X] <> ")", {X, fam["InvList"]}];
  t = StringReplace[t, rules];
  ToExpression[t] /. kint[a__] :> j[fam["Name"], a]];

MCBKiraReduce[fam_Association, dir_String, point_List, needTarget_ : True] := Module[{cmd, out, un, masters, res, file, mfile, nm = fam["NameString"], code, mem = kiraMemory[]},
  If[! MCBKiraAvailableQ[], Print["MCBKiraReduce: kira is not configured (MCBSetPath[\"kira\", ...])"]; Return[<|"ok" -> False|>]];
  cmd = StringJoin[
    If[MCBAvailableQ["fer64"], "FERMATPATH='" <> MCBPath["fer64"] <> "' ", ""],
    (* a time and a memory limit on Kira and Fermat: core/bin/limit stops both and exits with 124 or 137 *)
    MCBLimitCommand[$MCBKiraTimeLimit, mem],
    "'", MCBPath["kira"], "' --parallel=", ToString[$MCBKiraThreads],
    StringJoin[" --set_value=\"" <> MCBKiraName[fam, #[[1]]] <> "=" <> ToString[#[[2]], InputForm] <> "\"" & /@ point],
    " job.yaml > kira.out 2>&1"];
  code = MCBShell[cmd, dir];
  out = If[FileExistsQ[FileNameJoin[{dir, "kira.out"}]], Import[FileNameJoin[{dir, "kira.out"}], "Text"], ""];
  un = StringCases[out, "unreduced integrals: " ~~ n : DigitCharacter .. :> ToExpression[n]];
  un = If[un === {}, 0, Max[un]];
  If[un > 0, Print["!! Kira left ", un, " integrals unreduced in ", dir]];
  mfile = FileNameJoin[{dir, "results", nm, "masters"}];
  masters = If[FileExistsQ[mfile], MCBReadKiraMasters[mfile, fam], {}];
  file = FileNameJoin[{dir, "results", nm, "kira_target.m"}];
  res = If[FileExistsQ[file], parseKira[fam, Import[file, "Text"]], {}];
  If[! ListQ[res], res = {}];
  Which[
    code === 124, Print["!! Kira stopped at its time limit of ", $MCBKiraTimeLimit, " s in ", dir, " (run.wl \"TimeLimits\" -> \"Kira\", or $MCBKiraTimeLimit)"],
    code === 137, Print["!! Kira stopped at its memory limit of ", If[NumericQ[mem], ToString[NumberForm[mem, {4, 1}]] <> " GB", "the default"], " in ", dir,
      " (run.wl \"MemoryLimits\" -> \"Kira\", or $MCBKiraMemoryLimit; Automatic follows the kernel's own limit, bin/ws --memory)"],
    code =!= 0 || (needTarget && ! FileExistsQ[file]), Print["!! Kira failed in ", dir, " (exit code ", code, "); see kira.out"]];
  (* a reduction that succeeded is a use of Kira, and of Fermat when Kira was given it *)
  If[code === 0 && (FileExistsQ[file] || ! needTarget), MCBMarkToolUsed["kira"]; If[MCBAvailableQ["fer64"], MCBMarkToolUsed["fer64"]]];
  <|"rules" -> Dispatch[res], "masters" -> masters, "unreduced" -> un, "ok" -> (code === 0 && (FileExistsQ[file] || ! needTarget))|>];

(* the top sectors of the family (family.wl "TopSectors", else the lines of "Graph", else every line: MCBReadFamily) *)
topIDs[fam_Association] := SectorID /@ Select[Lookup[fam, "TopSectors", {ConstantArray[1, fam["N"]]}], ListQ];

MCBFindMastersKira[fam_Association, dir_String, point_List, opts_Association : <||>] := Module[{top, t, r, sd, nm = fam["NameString"], res, ids},
  top = Flatten[{Lookup[opts, "TopLevel", topIDs[fam]]}];
  t = Max[Total[SectorFromName[#, fam["N"]]] & /@ top];
  r = Lookup[opts, "r", t + 1]; sd = Lookup[opts, "s", 1];
  ids = StringRiffle[ToString /@ top, ", "];
  If[DirectoryQ[dir], DeleteDirectory[dir, DeleteContents -> True]];
  CreateDirectory[dir, CreateIntermediateDirectories -> True];
  MCBToKiraYAML[fam, dir, <|"TopLevel" -> top|>];
  Export[FileNameJoin[{dir, "job.yaml"}], StringJoin[
    "jobs:\n  - reduce_sectors:\n      reduce:\n",
    "        - {topologies: [", nm, "], sectors: [", ids, "], r: ", ToString[r], ", s: ", ToString[sd], "}\n",
    "      select_integrals:\n        select_mandatory_recursively:\n",
    "          - {topologies: [", nm, "], sectors: [", ids, "], r: ", ToString[r], ", s: ", ToString[sd], ", d: 1}\n",
    "      run_initiate: masters\n"], "Text"];
  res = MCBKiraReduce[fam, dir, point, False];
  If[! TrueQ[res["ok"]], Return[$Failed]];
  MCBPruneScratch[dir];   (* the masters are in memory; the job folder is kept only when Kira failed *)
  res["masters"]];

MCBKiraCutReduce[fam_Association, s_List, ints0_List, dir_String, point_List] := Module[{ints, r},
  ints = Select[Union[ints0], ! OffCutQ[s][#] &];
  If[DirectoryQ[dir], DeleteDirectory[dir, DeleteContents -> True]];
  CreateDirectory[dir, CreateIntermediateDirectories -> True];
  If[ints === {}, MCBPruneScratch[dir]; Return[{Dispatch[{}], {}}]];
  MCBKiraJob[fam, s, ints, dir];
  r = MCBKiraReduce[fam, dir, point];
  If[! TrueQ[r["ok"]], Return[{Dispatch[{}], $Failed}]];
  (* the reduction is in memory; the job folder is kept when Kira failed or left integrals unreduced *)
  If[r["unreduced"] == 0, MCBPruneScratch[dir]];
  {r["rules"], r["masters"]}];

MCBReduceTo[expr_, point_List, rules_, masters_List] := Module[{v = Collect[(expr /. point) /. rules, _j, Together], left},
  left = Complement[JIntegrals[v], masters];
  (* an integral that Kira left unreduced has no coefficients on the masters: no result, not one without that term *)
  If[left =!= {}, Print["!! not reduced onto the cut masters: ", Take[left, UpTo[5]]]; Return[$Failed]];
  Together[Coefficient[v, #]] & /@ masters];

MCBCutMasters[fam_Association, s_List, dir_String, point_List, opts_Association : <||>] := Module[{pool, rules, masters, user, extra},
  (* all integrals of the sector with up to two dots and numerator degree two in every ISP *)
  pool = MCBSectorPool[fam, s, ISPPos[s], <|"nd" -> Lookup[opts, "nd", 2], "nt" -> Lookup[opts, "nt", 2]|>];
  {rules, masters} = MCBKiraCutReduce[fam, s, pool, dir, point];
  If[masters === $Failed, Return[<|"masters" -> $Failed, "n" -> Missing["KiraFailed"]|>]];
  masters = Select[masters, SectorOf[#] === s &];
  user = Lookup[Lookup[MCBMasterSectors[fam], SectorName[s], <||>], "masters", {}];
  extra = Length[masters] - Length[user];
  <|"masters" -> masters, "n" -> Length[masters], "userMasters" -> user, "extra" -> If[user === {}, Missing["NoUserList"], extra],
    "rules" -> rules, "point" -> point|>];

MCBPoints[fam_Association, n_Integer, seed_Integer : 1, avoid_List : {}] := Module[{pts = {}, pt, tries = 0, g, bad, primes = Prime[Range[5, 60]], dens = Prime[Range[2, 15]]},
  BlockRandom[
    While[Length[pts] < n && tries < 1000, tries++;
      pt = Thread[fam["InvList"] -> Table[RandomChoice[{-1, 1}] RandomChoice[primes]/RandomChoice[dens], Length[fam["InvList"]]]];
      g = If[fam["E"] == 0, 1, Det[fam["Gram"] /. pt]];
      bad = g == 0 || AnyTrue[pt[[All, 2]], # == 0 &] || AnyTrue[avoid, TrueQ[Together[# /. pt] == 0] &] ||
        Length[DeleteDuplicates[Abs[pt[[All, 2]]]]] < Length[pt];
      If[! bad, AppendTo[pts, pt]]],
    RandomSeeding -> seed];
  pts];

MCBScalingSelfTest[fam_Association, sectors_List, dir_String] := Module[{pt = First[MCBPoints[fam, 1, 101]], out = {}},
  Do[Module[{s = sec, corner, dotted, res, ints, rules, masters, red},
      corner = MCBCornerIntegral[fam, s];
      dotted = j[fam["Name"], Sequence @@ ReplacePart[s, First[PropPos[s]] -> 2]];
      (* the derivatives the gate uses: at the point (MCBReduceCandidates), unless $MCBPointDerivatives is False *)
      res = DropOffCut[s] /@ (If[TrueQ[$MCBPointDerivatives], MCBScalingResidueAt[fam, #, pt], MCBScalingResidue[fam, #]] & /@ {corner, dotted});
      ints = JIntegrals[res];
      {rules, masters} = MCBKiraCutReduce[fam, s, ints, FileNameJoin[{dir, SectorName[s]}], pt];
      red = If[masters === $Failed, $Failed, MCBReduceTo[#, pt, rules, masters] & /@ res];
      AppendTo[out, <|"sector" -> SectorName[s], "ok" -> (red =!= $Failed && AllTrue[Flatten[red], Together[#] === 0 &]),
        "residue" -> red|>]],
    {sec, sectors}];
  out];


End[];
EndPackage[];
