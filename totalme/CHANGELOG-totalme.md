# CHANGELOG -- totalme

## v1.7.5 -- 23sep2026, version 16 or later; weighting options without a nominal variable

A caller running under version 15 or older -- a `version 15` line at the
top of a do-file, as in Bing Han's example files -- is now refused at once,
rc 9, with a message naming the version to set. Under such a line every
two-model comparison had stopped inside suest2 with r(509) "matrix
operators that return matrices not allowed in this context"
(`probe_bing_*_v1_0`, 22sep2026); the same pairs run at version 16 or later
(`probe_bing_checks_v1_0` B2). The suite supports version 16 or later only
(owner, 23sep2026). The check reads `_caller()`. Help: a "Stata version"
section. Nothing else moves; results at version 16 or later are unchanged.

**`weighted`, `unweighted` and `all` with no nominal focal variable.** They
were refused r(198) ("The options are only for nominal independent
variables") when every focal variable was continuous or binary; they are now
ignored for those variables, which keep their one Total ME row, as in
mecompare (owner, 23sep2026; Bing Han's question 3). Help: plain
`mi estimate:` is accepted for one model only.

## v1.7.4 -- 21sep2026, amount(range)

`amount(range)`: the change from the minimum to the maximum of the variable
in the estimation sample, ported from mecompare 1.6.0 (owner, 21sep2026) so
the two amount() lists stay identical. It rides the `trimrange` path
(`:1079-1088`): `summarize` on the estimation sample, the two values written
into the at() pair as fixed values, `start()` and centering do not apply.
Row label `min to max`, beside `p5 to p95` (`:1201-1203`). Read
case-insensitively and mixable in the list as the other keywords are.
Nothing else moves: every existing call gives the same at() strings.

Help: one row in the `amount()` table and one example. `.pkg` date
20260921. Pinned by `test_range_end_gate58_v1_0` A.9 (the gate-52
cross-command identity against `mecompare ..., totalme amount(range)`, on
a logit and on an ologit) and the regenerated `test_help_examples_v1_12`.

## v1.7.3 -- 16sep2026, factor variables found under any base level

Found by the owner on the sibling `meinequality` (v1.9.2) and measured
here with `probe_ibase_siblings_v1_0`. totalme decided that a focal
variable was nominal by looking for the text `i.name` in `e(cmdline)`, so a
model fit with `ib3.race`, `ib(3).race`, `ibn.race` or `i.(race married)`
listed race under "Continuous/Binary IV(s)" and margins stopped with
"suboption generate() not allowed with factor variables" (one model, two
models, and mi). The same text test refused `by(married)` / `over(married)`
when the model had `ib1.married`, and a typed `ib3.race` stopped with
"ib3: operator invalid". Membership was a substring test on the command
line, so `i.race2` in the model let `totalme race` through as nominal and
margins stopped with "factor race not found in list of covariates".

The checks now read the stored model's `e(b)` column names (`e(b_mi)`
under mi), captured at each `est restore` (`:229-232`, `:354-356`).
`_tm_fvtype` (`:2115-2129`) reports how a name enters them: `factor` when a
`#`-separated part is `<level>.name` under any base marker (`b`, `bn`,
`o`), `cont` when a part is `name`, `c.name`, `o.name` or `co.name`, empty
when absent. The focal loop (`:870-905`) uses it for membership (both
models with two) and for the nominal/binary-vs-continuous split (a factor
with more than two levels is nominal, as before; binary factors and
continuous variables keep their paths). `by()` (`:661-672`) and `over()`
(`:676-687`) require `factor`. A typed prefix on a focal variable or in
`by()`/`over()` is stripped with `regexr("^i[^.]*\.", "")` (`:873`,
`:662`, `:677`), so `totalme ib3.race` and `by(i.married)` run as the bare
names (the rev62 quirk of `by(i.race)` reaching `levelsof` is gone).
No number moves for a call that ran under 1.7.2.

Two models whose base levels differ for any shared factor variable are
refused before they are combined (`:437-456`), r(198): "race enters m1
as ib1.race and m2 as ib3.race. The two models are combined into one set
of estimates, which holds one base level per variable. Refit one model so
the base levels match; the total ME does not depend on the base level."
Before, suest2 refused the pair with "race: factor variable base
category conflict" (official `suest` refuses it the same way).
`_tm_bases` (`:2131-2152`) lists each variable's base as `name:ib#.name`.

The zero-by-construction Diff. row fixed in meinequality 1.9.2 cannot
arise here: totalme accepts only categorical outcomes, whose effects shift
across by()/over() groups. No change there.

Help: banner date only. Pinned by `test_ibase_siblings_v1_1` (148 / 0, 16sep2026).

## v1.7.2 -- 13sep2026, a focal variable may not be the by()/over() variable

`totalme collgrad, by(collgrad)` (or `over(collgrad)`) is now refused
r(198) at the parse (`:900-912`, after the focal list is built): "collgrad
is a focal variable and is also the by() variable. totalme does not
estimate the total marginal effect of a variable within levels of that
same variable; use mecompare for that." Design decision (owner,
13sep2026): totalme and meinequality stay focused; mecompare is the one
command that handles every case, including this one (mecompare v1.4.4,
rev61, where a focal variable in by() had flipped the sign of its own
rows). The test is an exact token match against the bare names in
`conivs` / `nomivs`, with any `i.` prefix stripped from the by()/over()
name. Nothing else moves. Help: one sentence under the subpopulation
options. Pinned by `test_focal_refuse_gate55_v1_0` (refusal with the
message for a binary and a nominal focal, by() and over(), one and two
models; controls on another by() variable and on mecompare accepting the
same call).

## v1.7.1 -- 11sep2026, Diff. rows across by()/over() levels

With `by()` or `over()` the table now carries, for each focal variable and
each pair of levels of the by/over variable, a **Diff.** row: the total ME
(or total ME inequality) at the first level minus that at the second, with
its standard error and test -- the test of whether the effect differs
across the groups, which the Stata Journal article's section 2.3 promises
and its 7.4 example (`totalme parent, by(married)`) could until now only
point to `mecompare` + `metest` for. With two models the pair gets three
rows, Model 1 / Model 2 / Cross-Model Diff., exactly as the level blocks
do; weighted and unweighted nominal rows each get their own.

Why it is one nlcom and not a new estimation: every path's `margins`
call already includes the by/over variable (`margins by, at(...) post`,
`margins by#nomvar, post`, `over()`), so all levels are posted together
with their joint covariance, and the per-level loop only chooses which
`_b[]` cells the nlcom expression reads. The level loop now keeps each
level's expression (`tmb_`m''/`tmc_`m'' `:1239`, `:1324-1325`;
`tmwb_`/`tmwc_`/`tmub_`/`tmuc_` `:1512`, `:1560`, `:1679-1680`,
`:1758-1759`), and after the loop each pair is formed by `_tm_bodrows`
(`:1972`), which restores the same stored margins object through
`_tm_nlcom` and returns the 1- or 3-row block and its point estimates:
`((a) - (b))/div` for each model and `((a)/div1 - (ca)/div2) - ((b)/div1
- (cb)/div2)` for the cross-model row (`:1372-1395` continuous/binary;
`:1799-1843` nominal). The pairs are set up once, before the variable
loops (`:688-703`): all pairs, first level minus second, in level order.

Labels: `<var> Diff.` (two levels) or `<var> Diff.1`, `<var> Diff.2`, ...
(more), with the change label appended on the two-model rows when it fits
the label column, as the level blocks do, so the equation stays short; the levels each row subtracts are
printed under the table (`:1903-1907`), `Diff. = Not Married - Married`,
from the full value labels (or the values when there is no label).
Returns: the level suffix `_<level>` becomes `_d<level1>_<level2>` --
`r(tmcm11_d0_1)`, `r(tmcm21_d0_1)`, `r(tmcd1_d0_1)`, `r(tmwm11_d0_1)`,
`r(tmuwm11_d0_1)` and so on. `r(table)` gains the rows. Without `by()`
or `over()` nothing changes.

Help: the by()/over() section and the stored-results note. Pinned by
`test_bodiff_gate53_v1_0`: on the article's 7.4 model each Diff. row equals
the difference of the level rows above it (reldif 1e-10), its SE equals
the SE of the same difference formed from `mecompare ..., by() totalme`'s
posted covariance matrix (1e-6), the footnote prints once, the returns
exist and equal the rows; two models, `over()`, nominal weighted and
unweighted, and a three-level by() (three Diff.# rows) are covered.
`test_amount_display_gate52` re-cut to v1.1 for the new row counts.

## v1.7.0 -- 10sep2026, amount(2sd), amount(trimrange), amount(rate); one header per IV with two models

Four items from the Stata Journal article session, plus one defect found on
the way. Existing `amount(one)`, `amount(sd)` and `amount(#)` calls give the
same at() specifications as v1.6.9, byte for byte.

**`amount()` gains `2sd`, `trimrange` and `rate`** (`:998-1035`), the three
values `mecompare` already takes, mixable in the list exactly as `one sd #`
are. Keywords are read case-insensitively; `twosd`, `slope` and `dydx` are
synonyms. `2sd` sets the amount to 2*SD and rides the existing numeric path,
so `centered` (the default) gives x - SD to x + SD and `uncentered` gives x
to x + 2SD, with `start()` honoured as for `sd`. `rate` sets the amount to a
step of (max - min)/1000, forces centering for that variable (`vcent`,
`:1006`, `:1019`; the option local is untouched so other variables in the
call keep the user's choice) and divides the step out of the summed term
before `nlcom` (`:1220` one model; `:1301-1304` both models) -- the same
step, the same centering and the same order of operations as `mecompare`'s
`totalme` option under `amount(rate)`, so the two commands agree to rounding.
`trimrange` sets the two at() values to the 5th and 95th percentiles from
`_pctile` on the estimation sample (`:1027-1035`); `start()` and centering
do not apply, as in `mecompare`. Row labels: `+ 2SD (centered)`, `p5 to
p95`, `d/dx` (`:1142-1150`). SD, range and percentiles come from `summarize`
/ `_pctile` on the estimation sample without weights, as `amount(sd)`
already did.

**Two models, continuous or binary IV: the header printed above every
row.** The equation part of the three row names was
`<var>,<change> <bylevel>` (`:1285-1287` in v1.6.9), which for a binary IV
with value labels ran to 39 characters and, with no `by()`, ended in a
space; matlist printed it, truncated, above each of the three rows. Now one
equation per IV (`:1334-1339`): `<var><bylevel> <change>` when that fits
the label column (`age + SD (centered)`), else `<var><bylevel>` alone
(`college`), so the header prints once and reads like the one-model
display. The nominal two-model rows had no trailing space and were not
affected; their unweighted label `toal Unwgt MEIneq` is now `Unwgt total
MEIneq` (`:1734-1736`). Values unchanged.

**`by()`/`over()` with more than one amount read the wrong amount.** The
amount-list counter advanced once per by-level rather than once per
variable (`local ++cnum` inside the level loop), so `amount(sd 5) by(woman)`
gave the first variable `sd` at level 1 and `5` at level 2, and the second
variable an empty amount. It now advances on the last level only
(`:1156`). Found reading the loop for item 1; not in any earlier gate.

**A stray `di` in the `start()` path** printed the variable's position in
the `start()` list (`:1047` in v1.6.9). Removed.

Help: three rows in the `amount()` table, three examples, Gelman (2008)
added to the references, and `r(n_mods)` and `r(n_vars)` added to the
stored-results table (both were returned since v1.0.x and never listed;
mirrors `meinequality.sthlp`). `.pkg` date. Pinned by
`test_amount_display_gate52_v1_0` on the article's GSS models: each new
amount against `mecompare ..., totalme amount()` on the same model, the
`amount(sd)` value 0.051 / 0.003 as a regression check, `uncentered` for
`2sd`, the amount-list-with-by() cell, and the 7.2 header counted from a
captured log.

## v1.6.9 -- 02sep2026, commands and details

The same two display defects as `meinequality` v1.8.8, fixed the same way
so the two cannot drift. Neither touches a number.

**`commands` printed "." for the margins line with two models.** The line
was read as `di ... r(cmdline)` at display time, after `_mec_prefix`
(`:1228`, `:1503`) and `_mec_omitchk` (`:1502`), both rclass, had cleared
`r()`; `display` of a missing result prints `.`. The one-model NOMINAL path
has the same shape (`:1362-1363`) and printed "." too; the one-model
continuous/binary path has only `est store` between the call and the
display, which is why one model looked correct. The command line is now
read into `tmmargcmd` on the line after each of the four `margins` calls
(`:1154`, `:1222`, `:1357`, `:1497`), before `est store` and the helpers,
and the display prints the local (`:1163`, `:1240`, `:1369`, `:1513`).
`marginscmdline` holds the bare r() result name -- `cmdline`, or
`est_cmdline_margins` under mi (`:283`, `:302`) -- and the read is
`r(`marginscmdline')`, with a fallback to `e(cmdline)`, which `margins,
post` and `mimrgns, post` both set, so the line cannot come back blank.

**`details` showed the margins output but not suest2's.** The combine call
was `capture quietly suest2 ..., nowarn` whatever `details` said, and bare
`capture` is itself silent. `tmshow` (`:75-83`), set beside `quietly`, is
`noisily` under `details` and `quietly` otherwise, and prefixes the suest2
call (`:740`) and the `engine(gsem)` call (`:757`, which also drops its
`quietly` option under `details`, matching its noisy retry). `nowarn`
stays: suest2 strips it at entry and it gates only the vce(robust) note
(suest2.ado:14-21, :218), which this command prints on its own; the table
comes from official `suest` on the ordinary route (suest2.ado:167, :214)
and from `suest2_display` on the specialized routes (:829-836), and prints
under `capture noisily` on all of them -- measured in `meinequality`
v1.8.8 on 02sep2026 with the identical call.

Help: banner to v1.6.9; no other line. The `.pkg` unchanged. Not measured
here: the mi path's `r(est_cmdline_margins)` read, which the fallback now
covers if it is wrong.

Run lines after a file drop in a live session start with `discard` --
Stata does not re-read an ado-file already loaded -- and `discard` also
drops stored estimates, so they re-store the models.

## v1.6.8 -- 02sep2026, the estimation sample

The same defect as `mecompare` v1.0.2, first shape, in five reads: the
by()/over() levels (`:665`), the level count that classifies each IV as
nominal or continuous/binary (`:853`), the binary focal levels (`:1110`,
`:1115`), the nominal focal levels (`:1312`), and the `fvexpand` that sets
the binary path's category count (`:960`) -- all over the whole dataset. A
variable with three levels in the data and two in the model's sample was
classified nominal and asked margins for the third level.

`levsamp` is the if-condition for all six, defined beside `psamp1`/`psamp2`
(`:240`) and redefined for two models (`:372`), `1` when the sample holds no
observation (rule 46). Same shape and name as `meinequality` v1.8.7 so the
two cannot drift.

Covered by `test_sample_scope_gate45_v1_1` part C on an mlogit with the
outcome in three bands: by(race) with a binary focal, `race` itself with two
levels in the sample, and a four-level `grade4` with three in the sample,
each paired with the keep-data control and asserted equal to it.

## v1.6.7 -- 31aug2026, long variable names

The same defect as `mecompare` v1.0.1, in two shapes: `change`v'' (four
sites) and `contrast`v''/`contrast`nomvar'' (two). A focal variable past
about 23 characters exited r(198) naming a macro the user never wrote.
`contrast<var>` is written and never read, but it still aborted the command,
so it is re-keyed rather than left.

`vnum' was already here for exactly this reason -- `:953` and `:1307` set it
because the inner loops at `:1370` and `:1423` clobber `i'. The fix uses it
for the macro names too. `mecompare` v1.0.1 adopts the same idiom rather
than inventing a second one.

Nothing user-facing moved. Covered by `test_longname_gate_v1_0` PART D,
which drives 27 and 32-character nominal names and a 30-character
`conivs()` variable, each paired with a short-name control.

## rev48 -- 31aug2026, comments only (v1.6.6 unchanged)

Comment compression to the owner's one-line rule (HANDOFF rule 115);
no code line moved (verified token-identical). Removed text preserved
verbatim in COMMENT-HISTORY-rev48.md.

## totalme.sthlp -- 30aug2026, help only (v1.6.6 unchanged)

The example dataset line `{stata use "https://...", clear}` was unquoted,
so SMCL split at the colon in `https:` and clicking ran `use "https`. Quoted
now. The bootstrap example named the returned scalar `w_mei` where
`boot_tot` returns `w_tot` (copied from meinequality's example). Both found
by `test_help_examples_v1_0`.

## v1.6.6 -- 30aug2026

Pre-release audit. Three defects, all gsem-era leftovers that `meinequality`
shed at v1.1.0/v1.4.0 and this file had not:

**Every two-model call cloned the dependent variable into the user's data**
as `<dv>_COPY1` and `<dv>_COPY2` (when both models share a DV name, which
is nearly always) and left them there. Nothing read them. Removed, with the
`mod1ivs`/`mod2ivs` builders that fed nothing.

**`total_me_mod_samp` was a persistent variable**, never dropped. Now a
tempvar; the four literal coefficient prefixes are built from it.

**`engine(gsem)` could not run.** The call passed `vce(robust)` and
`listwise`, neither of which `mec_gsem` accepts, so the fallback exited
r(198) on every call. The call is now the one `meinequality` makes
(`groups` and `sampvar()` when `groups` is given). The engine gate drove
this arm and reported its rc without asserting it; arm G of
`test_totalme_engine` now measures something.

Also:
- The sample-size note claimed `totalme` "uses listwise deletion across the
  models". Under the default engine nothing is refit; each model keeps its
  own sample. Now the same NOTE `meinequality` prints.
- The zero-observation branch printed an error and fell through (no exit),
  and pointed at `help groups`, which does not exist. Now exits 2000 with
  the `meinequality` wording.
- Syntax: `Details` -> `DETAILs`, `UNWEIghted` -> `UNWeighted`, matching
  the siblings and the abbreviations this file's own help already showed.
- `version 15` -> `version 16` (main program and `_tm_norefuse`).
- Dead locals: `vcespec`, `listwise`, `predictspec`, `changelbl` (init),
  `mod1varnum`, `mod1dv`, `mod2dv` (the last two fed only the clone).
- Help: `atmean:s`, `unw:eighted` underlines match syntax; `L-1` in ASCII;
  the `[weight]` paragraph said weights apply only with two models, which
  was wrong -- one-model weights are accepted and checked against the
  model's own -- and now carries `meinequality`'s text; `ci` text names
  `level()`; three version-history sentences dropped; one typo.

Header version notes relocated to `COMMENT-HISTORY-rev46.md`.

## v1.6.5 -- 29aug2026

**The stored system is named for the engine that built it.** `engine()` has
defaulted to `suest2` since v1.1.0, but the combined system was still stored
under `totalme_gsem` -- the fallback engine's name, which nothing reaches by
default. It is now `totalme_suest2` under the default engine and `totalme_gsem` only
under `engine(gsem)`, and the name **not** in use is dropped at store time so
a session that switches engines cannot leave a second, stale system
restorable. The help file documented the old name and is updated with it, and
now carries a version stamp -- neither sibling help had one, which is why
`sthlp_lint` H6 has never had anything to compare against on these two files.

**Estimation-sample markers are labelled.** `_est_totalme_suest2`,
`_est_totalme_margins`, `_est_totalme_mod1` and suest2's private copies each get a
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

## v1.6.2 -- 29aug2026

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

## v1.6.1 -- 26aug2026

Two defects, both found by the claims gate and the probe series, both
present in `meinequality` and `totalme` alike.

- **NLCOM-1.** `_tm_nlcom` captured its first `nlcom` and retried scaled by
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

## Earlier history (verbatim, as it stood in the .ado header at v1.6.5)

Moved here 30aug2026. The banner line itself is omitted.

```
*
*  v1.6.0 propagates mecompare's v0.4.4/v0.4.5 fixes (PW-ME-1 and
*  RS-VAL-1), both MEASURED in this command by probe_sib_pwme_rsval_v1_0
*  on 25aug2026 before any edit:
*  - PW-ME-1: a pweighted multilevel model without a stage weight ran
*    the one-model native-margins route (rc 0) while the identical pair
*    was refused 198 two-model by suest2's own gate. The one-model path
*    now carries the same gate and message (svy: exempt).
*  - RS-VAL-1: labwidth(19) died r(125) in the syntax numlist before the
*    guard; decimals(8) ran; decimals(-1) died r(120) in the format
*    builder. Both documented ranges are now enforced up front with
*    r(198); the bounds moved out of the syntax line.
*  Also v1.6.0: the commands echo under two models printed the literal
*  'gsem model is:' whichever engine ran (stale since the v1.1.0 engine
*  swap); it now names `engine', matching meinequality.
*
*  v1.5.1 strips a multilevel `||' part before the prefix-colon strip.
*  Without it EVERY two-model call with a multilevel model was refused 198
*  with a message that was false.
*
*  MEASURED probe_totalme_mepair_v1_0 (24aug2026), which reproduced the
*  two strips outside this file on the same e(cmdline) this file reads:
*
*     e(cmdline)        melogit y i.g c.x || pid:, nolog
*     after comma-strip melogit y i.g c.x || pid:
*     after colon-strip <empty>
*
*  The colon in `|| pid:' is a random-effects SEPARATOR, not an `svy :' or
*  `mi estimate :' prefix, so the prefix strip took everything after it and
*  left nothing. The focal-variable check then searched an empty string and
*  reported the variable missing from a model that contains it. The word
*  count at the predictor read was 0 for the same reason.
*
*  Measured: melogit, meprobit, mecloglog, meologit and meoprobit pairs all
*  refused 198; xtologit and xtlogit pairs (no `||', no colon) passed; the
*  same five pairs passed through MEINEQUALITY, which has carried this
*  strip since 17aug2026; single models passed, the block being inside the
*  two-model branch.
*
*  THE FIX IS NOT NEW. mecompare and meinequality took it on 17aug2026
*  after a correct mecloglog pair was refused 198 -- see
*  meinequality.ado:586. totalme was not checked against its siblings at
*  that time and kept the defect for seven weeks. A fix applied to one
*  command in this suite is not applied to the suite.
*
*  cmdline_m1/2 feed only the DV and predictor NAME reads; the refit at the
*  vce(robust) block uses cmdline_m1_show, which is set BEFORE any strip
*  and so keeps the `||' part. Same arrangement as meinequality.
*
*  v1.5.0 admits hetprobit and gives biprobit and ivprobit an accurate
*  refusal. Measured probe_meitm_admit_v1_1 (24aug2026), which drove every
*  resolver-admitted family through this command for the first time.
*
*  hetprobit has a plain binary outcome and was off tm_catmods only
*  because the list predates the family's admission to the suite. It was
*  refused 198 with the non-categorical message, which was wrong about it.
*
*  biprobit and ivprobit STAY REFUSED, but the old message told them their
*  outcome was not nominal or ordinal and that is false for both -- each
*  has a binary outcome. The real reasons are different from each other
*  and from the tm_catmods rule:
*    biprobit  the default statistic is p11, a JOINT probability over TWO
*              outcomes, so there is no single outcome whose categories
*              can be summed
*    ivprobit  suest2 supplies the STRUCTURAL LINEAR INDEX, not a
*              probability (measured exact against native predict,
*              probe_fam_forms_v1_1), so there are no category
*              probabilities to sum. ivprobit's native pr is an average
*              structural function and is NOT normal(xb) -- measured
*              wrong at reldif .0056, recorded so nobody re-derives it.
*  Both now say so. A refusal that gives a false reason is worse than a
*  refusal, because the user changes the wrong thing.
*
*  v1.4.0 is a simplification release: the eleven inline nlcom rescue
*  sites became one helper (_tm_nlcom) and dead code went (the dvnum2,
*  i2, dvlevels, tot_n, tm_spec1/2, svyspec, gsemprefix and mod*dv_use
*  locals, one bare levelsof, and the redundant translation layer under
*  decimals() -- the option itself is LIVE: the table's matlist reads
*  `decimals' directly). The calculation is unchanged. Per-version
*  history through v1.3.0 was relocated verbatim to
*  COMMENT-HISTORY-totalme-130-to-140.md and the session records.
```
