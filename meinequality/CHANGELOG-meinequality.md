# CHANGELOG -- meinequality

## v1.9.4 -- 23sep2026, group(varname)

`group(varname)`, the spelling of the groups option in earlier versions
(the 2019 article, the Handbook chapter), is accepted again. It runs as
`groups` after checking that the named variable takes one value in each
model's sample and a different value in each model; otherwise it stops,
rc 198, naming the model. `groups(varname)` is read the same way, and
`groups` typed as well is fine. Before, `group(varname)` stopped with
r(198). The help's groups entry has one sentence. Nothing else moves
(gate 62, `test_group_var_gate62_v1_1`).

## v1.9.3 -- 23sep2026, version 16 or later; plain-mi pairs; binary with all (meineq 1.7.1)

A caller running under version 15 or older -- a `version 15` line at the
top of a do-file, as in Bing Han's example files -- is now refused at once,
rc 9, with a message naming the version to set. Under such a line every
two-model comparison had stopped inside suest2 with r(509) "matrix
operators that return matrices not allowed in this context"
(`probe_bing_*_v1_0`, 22sep2026); the same pairs run at version 16 or later
(`probe_bing_checks_v1_0` B2). The suite supports version 16 or later only
(owner, 23sep2026). The check reads `_caller()`. Help: a "Stata version"
section. Nothing else moves; results at version 16 or later are unchanged.
`meineq` hands the caller's version on to `meinequality`, so the alias
is checked too.

**Two plain `mi estimate:` models.** `models(m1 m2)` with two models pooled
without `post` was refused with "m2 is a mi estimate, which meinequality
does not support": the model-2 check handed `e(cmd)` ("mi estimate") to
`_mec_canonical` before resolving the underlying command, which the model-1
check already did (Bing Han; `probe_bing_meinequality_v1_1` L69, L82). Model
2 is now resolved the same way, so the pair reaches suest2 and gets its
message, as in totalme and mecompare: refit with `mi estimate, post:`. Help:
plain `mi estimate:` is accepted for one model only.

**A binary variable with `all`.** Its unweighted row repeated the weighted
one (a single pair, so the two are equal by construction). With `all` a
binary focal variable now shows the weighted row only -- in the table, the
Diff. rows and the returns (no `r(uwem...)`); nominal variables are
unchanged, and `unweighted` alone still gives the one unweighted row
(owner, 23sep2026; Bing Han's question 3).

## v1.9.2 -- 16sep2026, factor variables found under any base level

`reg wage ib3.race ...` then `meinequality race` was refused r(198)
"Variable race not found in the model": the nominal-variable check was a
substring test for the literal text `i.race` in `e(cmdline)`, so any other
factor syntax on the stored model -- `ib3.race`, `ibn.race`, `ib(3).race`,
`i.(race married)` -- failed it, although the statistic does not depend on
the base level (margins posts every level whatever the base). The same
test sat under `by()` and `over()`.

The check now reads the stored model's `e(b)` column names (`e(b_mi)`
under mi), captured at each `est restore` (`:220-223`, `:360-363`), and
asks whether any column is `<level>.name` alone or inside an interaction,
under any base marker (`_mei_isfv`, `:1778-1787`: `#[0-9]+[bno]*\.name#`
on each `#`-padded column). The three sites (`by()` `:711-715`, `over()`
`:726-730`, focal loop `:789-801`; two models check both lists) call it.
A typed prefix on the focal variable or in `by()`/`over()` is stripped
with `regexr("^i[^.]*\.", "")` (`:790`, `:958`, `:712`, `:727`), so
`meinequality ib3.race` and `by(i.married)` run as their bare names
(before, `levelsof` failed on them). `cmdline_m1`/`cmdline_m2` are still
read for the display and the prefix/weight checks; only the variable
lookup moved. No number moves: the margins call and the nlcom terms are
unchanged.

Two models whose base levels differ for any shared factor variable (focal
or not) are now refused before they are combined (`:413-432`), r(198):
"race enters m1 as ib1.race and m2 as ib3.race. The two models are
combined into one set of estimates, which holds one base level per
variable. Refit one model so the base levels match; the ME inequality does
not depend on the base level." Before, suest2 refused the pair with
"race: factor variable base category conflict". `_mei_bases`
(`:1789-1809`) lists each factor variable's base as `name:ib#.name`
(`ibn.name` for no base), first base-marked column wins.

A Diff. row across by()/over() levels that is zero by construction is
now shown as 0 with SE 0 and no z, p-value or interval width
(`_mei_bodrows` `:1755-1785`). This happens when the model does not let
the effect vary across the groups (a linear model with no interaction):
the two level statistics are identical, and before, nlcom returned the
difference's variance as a rounding-sized number of either sign, so the
SE came back 0 in some calls and missing in others, and a missing one
triggered the "standard errors are missing ... sparse outcome
categories" note. `_mei_zero` (`:1787-1802`) runs one nlcom of both
level statistics and their difference and calls the difference zero
when its estimate is within 1e-8 of the level estimates' size and its
variance within 1e-8 of theirs; the cross-model row is zeroed when both
models' rows are. When any row is zeroed, a note prints under the table
(`:1646-1653`): "NOTE: a Diff. row shown as 0 with no z or p-value is
zero by construction: the model does not let the effect vary across the
levels of married (for example, a linear model without an interaction),
so there is nothing to test." Real differences are untouched.

Help: banner date only. Pinned by `test_ibase_v1_2` (42 / 0) and
`test_zerodiff_v1_0` (50 / 0), 16sep2026.

## v1.9.1 -- 13sep2026, a focal variable may not be the by()/over() variable

`meinequality race, by(race)` (or `over(race)`) is now refused r(198) at
the parse (`:798-809`, inside the focal-variable loop): "race is a focal
variable and is also the by() variable. meinequality does not estimate
the ME inequality of a variable within levels of that same variable; use
mecompare for that." Design decision (owner, 13sep2026): totalme and
meinequality stay focused; mecompare is the one command that handles
every case, including this one (mecompare v1.4.4, rev61). The test
compares the bare names (any `i.` prefix stripped on both sides). Nothing
else moves. Help: one sentence under the subpopulation options. Pinned by
`test_focal_refuse_gate55_v1_0`.

## v1.9.0 -- 11sep2026, Diff. rows across by()/over() levels

The same feature as `totalme` v1.7.1, built the same way so the two cannot
drift. With `by()` or `over()` the table carries, for each focal variable,
each outcome (multi-category outcome) and each pair of levels of the
by/over variable, a **Diff.** row: the ME inequality at the first level
minus that at the second, with its standard error and test -- the test of
whether the inequality differs across the groups. With two models the pair
gets three rows, Model 1 / Model 2 / Cross-Model Diff. (`Diff. Pr(...)` on
the multi-category path), as the level blocks do; weighted and unweighted
rows each get their own; under `all` on the binary-outcome one-model path
the Diff. rows sit with their weighted and unweighted blocks, as the level
rows do.

One nlcom, no new estimation: every path's `margins` call includes the
by/over variable, so all levels are posted together with their joint
covariance. The level loop keeps each level's expression per outcome
(`meiwb_`m'_`dvnum''/`meiwc_`/`meiub_`/`meiuc_`: `:993`, `:1016`,
`:1119-1120`, `:1171-1172`, `:1249`, `:1278`, `:1387-1388`, `:1448-1449`),
and after the loop each pair is formed by `_mei_bodrows` (`:1729`), which
restores the stored margins through `_mei_nlcom` and returns the 1- or
3-row block: `((a) - (b))/div` per model (div = 1 weighted, `nc`
unweighted) and `((a)/div - (ca)/div) - ((b)/div - (cb)/div)` for the
cross-model row (`:1491-1557`; the pair loop runs weighted then unweighted,
each over the outcomes, so the rows sit in the order of the level rows). Pairs are set up once (`:738-753`): all
pairs, first level minus second, in level order.

Labels: `<var> Diff.` (two levels) or `<var> Diff.1`, `<var> Diff.2`, ...
in the slot the level tag `<var>(<level>)` occupies on each path; the
levels each row subtracts are printed under the table (`:1621-1625`),
`Diff. = Not Married - Married`, from the full value labels. Returns: the
level suffix `_<level>` becomes `_d<level1>_<level2>` -- `r(wem11_d0_1)`,
`r(wem11_o2_d0_1)`, `r(wed1_d0_1)`, `r(uwem11_d0_1)` and so on. `r(table)`
gains the rows. Without `by()` or `over()` nothing changes.

Help: the by()/over() section and the stored-results note. Pinned by
`test_bodiff_gate53_v1_0` PART C/D: each Diff. row equals the difference
of the level rows above it, its SE equals the SE of the same difference
from `mecompare ..., by() meinequality`'s posted covariance matrix,
unweighted rows, two models and a three-level by().

## v1.8.8 -- 02sep2026, commands and details

Two display defects in the options that show the work, found by the owner
while preparing the GitHub post. Neither touches a number.

**`commands` printed "." for the margins line.** The line was read as
`di ... r(cmdline)` at display time, but between the `margins ... post` call
and the display the command calls `_mec_omitchk` at every site and
`_mec_prefix` at the two-model sites, both rclass, so `r()` was already
cleared and `display` of a missing result prints `.`. The command line is
now read into `meimargcmd` on the line after each of the four `margins`
calls (`:955`, `:1044`, `:1196`, `:1296`), before `est store` and the
helpers, and the display prints the local (`:965`, `:1080`, `:1206`,
`:1332`). `marginscmdline` holds the bare r() result name -- `cmdline`, or
`est_cmdline_margins` under mi (`:275`, `:294`) -- and the read is
`r(`marginscmdline')`, with a fallback to `e(cmdline)`, which `margins,
post` and `mimrgns, post` both set, so the line cannot come back blank.

**`details` showed the margins output but not suest2's.** The combine call
was `capture quietly suest2 ..., nowarn` whatever `details` said. Bare
`capture` is itself silent, so the first attempt -- dropping the `quietly`
-- changed nothing, and was measured to change nothing. The file's own
error path already used `capture noisily`; the fix follows it. `meishow`
(`:70-78`), set beside `quietly`, is `noisily` under `details` and `quietly`
otherwise, and prefixes the suest2 call (`:835`) and the `engine(gsem)`
call (`:853`, which also drops its `quietly` option under `details`,
matching its noisy retry). `nowarn` stays on the call: suest2 strips it at
entry and it gates only the vce(robust) note (suest2.ado:14-21, :218),
which this command prints on its own. The table comes from official
`suest` on the ordinary route (suest2.ado:167, :214) and from
`suest2_display` on the specialized and pweight routes (:829-836), and
prints under `capture noisily` on all of them.

Measured 02sep2026 (Stata 19.5, nlsw88): `commands` prints
`margins race , post` on the binary and three-outcome mlogit paths, one and
two models; `details` with `models(m1 m2)` prints "Simultaneous results for
m1, m2" and the stacked m1_union / m2_union table before the Predictive
margins table. Values unchanged (0.084 / 0.081 / 0.003, N 1878).

Help: banner to v1.8.8; no other line. `meineq.ado` and the `.pkg`
unchanged. Not measured: the mi path's `r(est_cmdline_margins)` read,
which the fallback now covers if it is wrong.

A process note from this fix, for the run lines that accompany a delivery:
Stata keeps a loaded ado-program in memory and does not re-read a file
dropped over it, so two runs were made against the superseded draft while
`which`, which reads the disk, showed the new banner. Run lines that follow
a file drop in a live session start with `discard`, which also drops
stored estimates, so they re-store the models as well.

## v1.8.7 -- 02sep2026, the estimation sample

The same defect as `mecompare` v1.0.2, first shape: the levels of the
by()/over() variable (`:715`) and of the nominal focal variable (`:916`)
were read with a bare `levelsof` over the whole dataset. A model fit with
`if` on a subset of a nominal variable's levels asked margins for a level it
never saw. Found in the source while fixing mecompare, not by a run; gate 45
part B is the first instrument to drive it.

`levsamp` (`:231`, `:379`) is the if-condition for those reads: `mod1samp == 1 &
mecshsamp` for one model, `meisamp < . & mecshsamp` for two (the union of
the two samples), and `1` when that holds no observation so the command
reads what it read before (rule 46). It sits beside `psamp1`/`psamp2`, the
sample the level PROPORTIONS were already taken over since v1.8.x -- the
proportions and the level list now agree on what the sample is.

Not changed: `levelsof `mod1dv'` at `:1196` and `:1319` reads the OUTCOME
levels for row labels over the whole dataset. An outcome category absent
from the sample is a different question (the model has no equation for it)
and no corpus task reached it.

## rev48 -- 31aug2026, comments only (v1.8.6 unchanged)

Comment compression to the owner's one-line rule (HANDOFF rule 115);
no code line moved (verified token-identical). Removed text preserved
verbatim in COMMENT-HISTORY-rev48.md.

## v1.8.6 -- 30aug2026

Pre-release audit.

**The group-membership marker is a tempvar.** `me_inequality_mod_samp` was a
persistent variable written into the user's data on every two-model call
and never dropped. It is now a tempvar, and the coefficient prefixes that
named it (`1.me_inequality_mod_samp#`) are built from the tempvar. No
instrument referenced the old name.

**Dead code from the gsem era removed:** `gsemprefix`, `svyspec` (four
sites), `vcespec` (two), `predictspec`, `mod1varnum`, `mod2dv`, and `tot_n`
with the `count` that fed only it. Sibling `totalme` shed most of these at
v1.4.0; this file had not.

**`version 15` -> `version 16`** in the main program. Every other program
in the suite, including the prerequisite `suest2`, declares 16.

**Message text:** the `groups`-with-one-model refusal carried an em-dash;
now ` -- `, matching `totalme`.

**Help:** `atmean:s` underline matches syntax; `L-1` in ASCII; two
version-history sentences (v0.4.0, v1.3.0) dropped.

Header version notes relocated to `COMMENT-HISTORY-rev46.md`.

## v1.8.5 -- 29aug2026

**The stored system is named for the engine that built it.** `engine()` has
defaulted to `suest2` since v1.1.0, but the combined system was still stored
under `meineq_gsem` -- the fallback engine's name, which nothing reaches by
default. It is now `meineq_suest2` under the default engine and `meineq_gsem` only
under `engine(gsem)`, and the name **not** in use is dropped at store time so
a session that switches engines cannot leave a second, stale system
restorable. The help file documented the old name and is updated with it, and
now carries a version stamp -- neither sibling help had one, which is why
`sthlp_lint` H6 has never had anything to compare against on these two files.

**Estimation-sample markers are labelled.** `_est_meineq_suest2`,
`_est_meineq_margins`, `_est_meineq_mod1` and suest2's private copies each get a
label naming what they are, instead of Stata's stock
`esample() from estimates store`. Applied in the last executable block of the
program, not beside each store: `estimates restore NAME` rewrites `_est_NAME`
and restores the stock label whenever it swaps the active results (measured
29aug2026, `probe_estlabel_v1_0`, 16 cells), and this command restores its
margins object repeatedly. Known limit: a user's own `estimates restore` puts
the stock label back, and nothing in here can prevent that.

Same change as `mecompare` v0.4.14, asserted by surface gate v1.13 cells
6.18-6.27 so the three cannot drift apart.

### The return code, and a defect the first version of this shipped

`capture` sets `_rc`, `_rc` is global, and it is what the **caller** reads
after this command returns. The label block ends in `capture` statements,
and several of the markers do not exist on every path -- there is no
`<cmd>_mod1` when `models()` was given -- so a failing `capture` here handed
the caller a 111 it never earned.

Caught by `mec-final-gate` and `mec-final-gate-suest2`, both of which drove

    qui meinequality i.race if age > 40, models(o_l1)

then asserted `_rc == 0`. Both FAILED on cells that were green in rev44. The
command had run correctly; the return code was the label block's.

`_rc` is now saved before the block and restored after with `capture error`,
so the block is invisible to the return code whatever it does.

`mecompare` was never observed leaking, because `_est__mec_src` is stashed on
any `nummods == 1` run and its `capture` succeeds -- but the same guard is
applied to all three rather than only where a gate happened to look.

Surface gate v1.15 cells 6.29-6.32 assert `_rc` after each command. PART 6
had read every label and no return code: a gate that checks what a command
leaves behind has to count the return code among the things left behind.

## v1.8.2 -- 29aug2026

**The two-model echo no longer claims a refit that does not happen**, and the
options warning no longer describes one.

`mod1specs`/`mod2specs` appended `, vce(robust)` to each model's echoed
command line, and the accompanying warning said options were "removed for
estimation". Both are gsem-era: that engine refitted each model with
vce(robust) after stripping its options. suest2 refits nothing and discards
nothing -- it reads the stored estimates and builds the joint VCE from their
scores. Only the DISPLAY drops the options.

Measured 25aug2026, g41_cmd.txt and g42_cmd.txt: `p_logit` was fitted as
`logit y i.g c.x` with no `vce()` and echoed as `logit y i.g c.x,
vce(robust)`. Nothing in the testing tree asserts either string.

Identical change in `mecompare` v0.4.11 and in the other sibling in the same
pass. The separate vce(robust) RECOMMENDATION above the echo is CORRECT and
stays -- a constituent fitted without vce(robust) really does give different
standard errors from the ones this command reports. Verified
probe_predmlogit_v1_1, 16/16, which asserts the recommendation is still
present as well as that the false echo and the false warning are gone.

## v1.8.1 -- 26aug2026

Two defects, both found by the claims gate and the probe series, both
present in `meinequality` and `totalme` alike.

- **NLCOM-1.** `_mei_nlcom` captured its first `nlcom` and retried scaled by
  1000 on failure, but the retry was not captured. When it failed too,
  `nlcom`'s own error escaped raw — "Maximum number of iterations
  exceeded", r(498) — naming neither the quantity nor a remedy. The
  helper restores the margins object into `e()` before each attempt, so
  the abort left that margins result in `e()` and the user's fitted model
  was gone; every subsequent command then refused. Measured:
  `probe_totalme_all_v3_0` section 4 (`e(cmd)` mlogit → margins).
  Both retries are captured, the model is restored, and the message names
  the quantity, both return codes, and the usual cause. rc stays 498.

- **SE-1.** With two empty outcome × focal cells the command returned
  rc 0 and printed a point estimate whose standard error, z, p and both
  CI limits were missing, with no warning and no flag. Measured:
  `probe_totalme_all_v5_0` section 3 — `r(table)` 1×6, column 1
  populated, columns 2–6 missing. Missing standard errors are now
  counted, returned as `r(se_missing)`, and noted under the table.

### Why no up-front threshold guard

`probe_totalme_all_v5_0` measured where this begins. On synthetic data
(3 outcomes, 3-level focal, N=3000) every quantity computes down to 25
observations in the smallest outcome category and fails at 12 and below —
in the weighted branch as well as the unweighted one. On nlsw88 the
unweighted branch survives to 17 and fails at 4 while the weighted one
still runs. The boundary depends on the fit, not on a constant, so a
hardcoded minimum would assert something no measurement supports.

## Earlier history (verbatim, as it stood in the .ado header at v1.8.5)

Moved here 30aug2026. The banner line itself is omitted.

```
*
*  v1.8.0 propagates mecompare's v0.4.4/v0.4.5 fixes (PW-ME-1 and
*  RS-VAL-1), both MEASURED in this command by probe_sib_pwme_rsval_v1_0
*  on 25aug2026 before any edit:
*  - PW-ME-1: a pweighted multilevel model without a stage weight ran
*    the one-model native-margins route (rc 0) while the identical pair
*    was refused 198 two-model by suest2's own gate. The one-model path
*    now carries the same gate and message (svy: exempt -- the design
*    travels with the prefix).
*  - RS-VAL-1: labwidth(19) died r(125) in the syntax numlist before the
*    guard; decimals(8) ran; decimals(-1) died r(120) in the format
*    builder. Both documented ranges are now enforced up front with
*    r(198); the bounds moved out of the syntax line. The vestigial
*    dead `dec' local went with them.
*
*  v1.7.0 is a simplification release: the twelve inline ME-inequality
*  term loops became one builder (_mei_terms), the four outcome-label
*  blocks became _mei_dvlab, and dead code went (two nummods==2 blocks
*  unreachable inside the nummods==1 cells, the dvnum2 and levels_dv
*  locals, three bare levelsof calls). The calculation is unchanged.
*  Per-version history through v1.6.0 was relocated verbatim to
*  COMMENT-HISTORY-meinequality-160-to-170.md and the session records.
```

## meineq.ado

`*! meineq v1.7.0 Bing Han & Trenton Mize 2026-08-21`. One-line abbreviation
shim; carries its own version statement (16). Banner names this changelog
as of 30aug2026; no other change.
