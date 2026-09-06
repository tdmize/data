# CHANGELOG -- mecompare

Version history lifted out of `mecompare.ado` at v0.4.7. `which
mecompare` printed all 87 of these lines (surface gate v1.1, cell
1.mecompare); the `.ado` now carries one banner line, matching
`meinequality.ado` and `totalme.ado`.

## v1.4.2 -- 05sep2026, factor syntax is optional and must agree with the model

A prefix on a variable in the varlist or in `by()`/`over()` is for clarity
only: the stored model(s) decide whether a variable is continuous or a
factor and which level is the base, and a prefix that says otherwise is
refused r(198) with a message naming both sides. `c.married` on a model
that entered `i.married`: "c.married contradicts the stored model(s):
married was entered as a factor variable (ib0.married), not as continuous.
Factor syntax is optional in mecompare but must match the model(s); type
i.married or married, or refit with c.married." `i.age` on a continuous
age: "entered as a continuous variable, not with a factor prefix".
`ib2.race` or `ibn.race` on a model with base 1: "entered with base level 1
(ib1.race). The base level is set on the stored model(s)". A prefix other
than `c.`, `i.`, `ib#.`, `ib(#).`, `ibn.` (`2.race`, `o.race`,
`ib(first).race`) is refused with a message saying which prefixes are read.
Bare names, and prefixes that agree with the model (`i.`, `c.`, `ib#.` at
the model's base, `ib(#).`, abbreviated names), give the same e(b), e(V)
and names as v1.4.0, byte for byte. A term with `#` in the varlist
(`i.married#c.age`) passes through unchanged and is refused by the
existing predictor check, r(111), as before. A variable in neither model
is still refused by that check.

Before: `_mec_annotate` stripped the literal strings `i.` and `c.` from each
user token and returned the model's own token for the bare name, so `c.` on
a factor and `i.` on a continuous variable were silently dropped and the
model's type used; `ib2.race` against base 1 survived the strip, missed the
model list and was refused as "is not a predictor in the model(s)", which
it is; `by()`/`over()` stripped `i.` only, so `by(ib2.race)` was refused as
"not found as a nominal (i.) predictor".

Implementation. `_mec_annotate` (`:4153-4247`) splits the user prefix from
the name at the first `.`, classifies it (`c.` continuous; `i.` factor;
`ibn.` factor with no base; `ib#.` / `ib(#).` factor with base #, read with
`confirm integer number`), finds the first factor token and/or the bare
name for that name in the model list, and refuses a contradiction before
returning what v1.4.0 returned. The `by()`/`over()` branch (`:1288-1295`)
hands its tokens to the same routine against the same model list the
nominal check reads (`clean_list1b fvivs1 fvivs2`) and strips the returned
prefix back to the bare names every downstream reader expects, replacing
the `subinstr(..., "i.", "")` strip. Measured first (gate 51 v1.0 on the
first cut, v1.4.1, 54 / 3: A.1, A.7, C.2, every varlist `c.` cell):
`syntax varlist(fv)` normalizes a lone `c.x` to `x` before the program
sees `varlist`, while `i.`, `ib#.`, `ibn.`, `2.` survive it (`2.race` comes
back as `i2.race`, `ib(2).race` as `ib2.race`, so those two refusal
messages show the normalized token). So the `c.` prefixes are read off the
raw command line before `syntax` (`:71-83`: the text before the first
comma, walked up to `if`, `in` or `[`; each `c.name` without `#` expanded
with `unab`) and restored on the list the two `_mec_annotate` calls take
(`:96-103`, `:773`, `:1069`); `varlist` itself is untouched. Not a second
`syntax` call (HANDOFF rule 134). v1.4.1 (05sep2026) was that first cut and
was never posted.

Help: one sentence added to the varlist paragraph.

Covered by `test_fvcheck_gate51_v1_2` (61 / 0 on v1.4.2, alone and inside
`run_rev59_mecompare` v1.3, 25 / 25 gates PASSED, 05sep2026; v1_3 is the
same gate writing one log, 61 / 0): every refusal above on one model, two
models, `by()` and `over()`, each with its rc and message fragments, and
each paired with a control whose e(b) and e(V) equal the bare-name call
(shape, names, equations, mreldif 0) -- `i.married c.age i.race`,
`ib0.married age ib1.race`, `ib(1).race`, `i.race` and `ib2.race` on a
base-2 model, `c.married` on a model that entered married continuous, no
varlist, `c.ag i.marr`, `by(i.race)`, `by(ib1.race)`, `over(i.race)`,
`by(i.race i.married)`, two-model `by(i.race)`; `by(age)` still gets the
nominal-check message; `i.collgrad` (not in the model) and
`i.married#c.age` still get the predictor check.

## v1.4.0 -- 02sep2026, more than one variable in over()

`over(w1 w2 ...)` hands every variable to margins `over()` and reports one
row set per combination of levels, first variable slowest -- the order
margins posts them (`probe_overlayout_v1_0.log`: columns
`k._at#l.race#m.collgrad`; two models `_predict#_at#race#collgrad`) --
labelled with every level (`White College grad`) and named
`var_w1_a_w2_b`. Each `over()` variable is validated as `by()` variables
are (nominal in the model(s); a variable twice refused; levels from the
estimation sample). A combination of levels with no observations in the
estimation sample has no margins group and no posted column (probe A6:
`[1._at#3.race#1.collgrad] not found`, rc 111), so it is dropped from the
table before margins is read; `by()` is a counterfactual and keeps it.
With one variable the scaffold is what it was: `over(race)` posts the same
names and values as rev57. The `over()`/`by()` asymmetry of v1.2.0 is
closed.

Implementation: the over branch sets the variable list where the by
branch does (`:1262-1270`), the one-variable level scaffold is gone, the
margins line carries `over(`byvars')` (`:1947`), and the over cells are the
product of the per-variable level lists grown one variable at a time
(`:2096-2148`), each cell carrying its `#l.v` suffix for the column name,
its label, its name token and a sample condition; cells are kept only if
`count if <sample> & <cell>` is positive, and only when more than one
variable is named, so the one-variable path is byte-equivalent in effect.

Covered by `test_multiover_gate50_v1_0` (37 / 0): every `over(race
collgrad)` cell equals `lincom` on a hand `margins, at() at() over(race
collgrad) post` (reldif 0) on one model, two models (m1, m2, Difference)
and a binary focal variable; `over(collgrad race)` maps onto it by index;
`metest 2 - 1` equals the hand second difference; the empty-combination
case on a cut sample (five rows, against the hand call) with `by()` keeping
six as the control; the `commands` echo; refusals with controls; `over(race)`
alone on the rev57 names and the hand value.

## v1.3.1 -- 02sep2026, atmeans by itself

`atmeans` (abbreviation `atm`) may be given as an option on its own and
means exactly `covariates(atmeans)`: the option is folded into the
`covariates()` string before anything reads it (`:146-149`), so the
value-list parser, the margins line, `by()`, two models and the header all
see one form. Both spellings together are one `atmeans`; `start(atmeans)`
is unchanged and remains a different thing (the focal variable starts at
its mean). The `marginsopt(atmeans)` refusal now points to either spelling.

Covered by `test_atmeans_gate49_v1_0` (21 / 0): the bare call equals the
`covariates(atmeans)` call element for element (mreldif 0, the same
margins call) on the plain call, under `by(race)`, with a covariate value,
with a value list and with two models; both differ from as-observed; the
age row equals a hand `margins, at() at() atmeans`; the `commands` line
carries `atmeans`; the refusal and its message; `start(atmeans)` against
its controls.

## v1.3.0 -- 02sep2026, marginsopt(): a pass-through to margins

`marginsopt(string)` passes *string* to `margins` exactly as typed,
after the options the command sets itself and before `post`, and prints
it in the `commands` line. The command does not check that the result
means anything; the user does, with `commands` and `details`. What it
exists for is `expression()` on one model: dollar-scale effects after a
regression of log wages (cda-02 2.8, cda-10 10.1),
`marginsopt(expression(exp(predict(xb))))`; effects in percentage points,
`expression(100*predict(pr))`; and, measured along the way,
`vce(unconditional)` and `subpop()` on the counterfactual at() layout.

Measured before a line moved (`probe_marginsopt_v1_0.log`): on the
command's at() layout `expression()` leaves every coefficient name as it
was and empties every predict label, with the text in `e(expression)`; it
removes the `_predict` dimension, so it is a single quantity exactly as
`predict(outcome(#))` already is on the one-model path and cannot feed the
two-model table; margins itself refuses `predict()` next to
`expression()`; `vce(unconditional)`, `subpop()` and `over()` change no
name; under suest2 `vce(unconditional)` fails with margins' own message.

So: the string is walked with `gettoken ... , bind`; an `expression()`
token is set aside and everything else is tested, after every
parenthesised argument has been blanked, for the tokens the command sets
or reads -- `at()`, `over()`, `predict()`, `post`, `atmeans`, the `dydx()`
family, `contrast`, `pwcompare`, `mcompare()`, `within()`, `nose` -- each
refused with a message that says why and what to use instead. A word
inside `subpop()` or `vce()` is not read as an option (a variable named
`post` is fine); `noatlegend` is not `at()`. `expression()` is refused
with two models and next to `predict()`; with one model it resets the
outcome count to one (the `predict(outcome(#))` mechanism), and the header
prints "Predicting: <expression>" from `e(expression)` when every predict
label is empty. On the mi path `predict(default)` is dropped under an
expression as it is under `predict()`. `vce(unconditional)` relabels the SE
column `Uncond SE`. `e(marginsopt)` holds the string. The `groupme` summary
call does not carry it.

Not a second `syntax` call: the first draft split the expression out with
an inner `syntax , [EXPression(string asis) *]`, and the first run of gate
48 (63 / 16) showed that a second `syntax` clears the `varlist` the first
one set -- every marginsopt() call computed all predictors. HANDOFF rule
134.

Covered by `test_marginsopt_gate48_v1_1` (v1.0 79 / 0 on this build; v1.1
tightens one control floor): every marginal effect through the
pass-through equals `lincom` on a hand `margins` (or `mimrgns`) call
carrying the same option, at reldif 0 measured -- plain, `by(race)`,
`covariates(ttl_exp=(5 20))`, binary and nominal focal variables, `svy:`,
mlogit with `expression(100*predict(outcome(2)))` (also equal to 100 x the
`predict(pr outcome(2))` call), `over(race)`, and `mi estimate`; `metest`
across `by()` rows equals the hand second difference; `level(90)` and
`noatlegend` leave e(b) identical; `vce(unconditional)` leaves the
estimates identical and changes the SE; fourteen refusals with their
messages and controls; two models with `vce(unconditional)` show margins'
message at rc 322; the `commands` line, the header, `e(marginsopt)` and
`e(predict_label)`.

## v1.2.0 -- 02sep2026, more than one variable in by()

`by(w1 w2 ...)` reports one set of rows per combination of the levels of
the named variables, the first variable varying slowest, each row labelled
with all its levels (`Married White`) and named `var_w1_a_w2_b`. `metest`
then tests a second or third difference directly (`metest 4 - 1` on
`by(married race)` is the interaction of marriage with the age effect
among Whites). Three-way interactions that took two `covariates()` calls
with the third difference spanning them (S3.5.c, cda-10 10.7) are one call.

Built on the cell scaffold of v1.1.0 rather than as a second mechanism:
each `by()` variable is a dimension, the `covariates()` list is the last
dimension, and the cells are the product, grown one dimension at a time
(`:1240-1290`). A `by(w)` with one variable goes through the same loop
with one dimension and produces the rev54 names and values unchanged.
Every `by()` variable is validated on its own (`:1159-1197`): it must be a
nominal (`i.`) term in the model(s), and its levels are read from the
estimation sample with `meclevif`. `over()` keeps its one-variable scaffold
(`:1153`, `:1198`) and its message says so. Refused, each with a control in
the gate: a variable named twice in `by()`; a continuous variable in
`by()`; two variables in `over()`; a `covariates()` value list on any
`by()` variable (`:1221`). Every `by()` variable joins `mecfixvars`
(`:1345`) so the fixed-variable check covers all of them.

Help: `by(varlist)`; the sentence that said `by()` and `over()` "may each
name only one variable" now says `over()` may name one and `by()` several.

Covered by `test_multiby_gate47_v1_0` (50 / 0 on this build): every
`by(married race)` cell equals the single `covariates(married=a race=b)`
call and the hand `margins, at()` + `lincom`; the six cells map onto
`by(race) covariates(married=(0 1))` in the documented order; three
variables (12 cells); crossed with a `covariates()` list and a `start()`
list; two models (18 rows); a binary focal variable; the four refusals; and
`by(race)` alone on the rev54 names.

## v1.1.0 -- 02sep2026, value lists in start() and covariates()

`covariates(z=(numlist))` reports the marginal effect of each focal
variable with the whole sample set to each listed value of `z`, one set of
rows per value, labelled `z=25` and named `var_z_25`; `start(x=(numlist))`
reports the effect of the focal variable `x` from each listed starting
value, labelled `at 30` and named `var_at30`. Both are counterfactuals
(`at()` in one `margins` call), so `metest` tests the differences between
the rows: whether the effect of X differs at Z = 25, 44, 72 (S3 Table 4,
cda-02 2.4.c, cda-07 7.5), the effect of age + 5 starting at 20, 30 and 60
(S3 Table 2, cme-6_1, cda-03 3.18), and the same by gender
(`start(age=(20 30 60)) by(woman)`), each one call where each was three
to six. `covariates(z=(10(10)90))` with `store()` gives `coefplot` the
effect of X across the range of Z.

The parser (`:159-257`) reads each `covariates()` and `start()` entry with
`gettoken ... , bind` so a stepped numlist keeps its parentheses; an entry
of the form `name=(numlist)` is a value list, `name=value` is what it was,
and any other entry is passed through unchanged, so nothing that ran before
is refused now. One list per option; the listed covariate may not be a
focal variable (its values come from `start()`), and a value list cannot
be combined with `over()`, which splits the sample rather than setting it,
or with `groups`.

**The cell scaffold.** `by()` had been a level scaffold: every focal
variable's at() block repeated once per level, with `w=level` written
inside each at(), and the table loop read a block by
`atnum + bymult_bo * nc_at`. That scaffold is now a list of cells, each
with an at() assignment string, a label and a name token; `by()` levels
and the `covariates()` list are its dimensions, and with neither there is
one cell with an empty assignment, which is the rev54 path. A `start()`
list is the inner dimension of the one variable it names: the continuous
at() builder writes one (start, end) pair per cell and per base
(`:1697-1704`), the table loop temporarily expands the cells to cells x
bases for that variable (`:2081-2113`) and restores them after it
(`:2335`), and the row-specification builder sizes each variable's rows
from its own count (`nlv_i = nlev_me x nsl_i`, `:3163-3171`) rather than
from a global one -- the defect the first run of gate 46 found (84 / 23,
"too few specifications in rspec()") and the second run closed (107 / 0).
Row labels are capped at 28 characters so that the `{sf}` prefix keeps
every coefficient name within Stata's 32.

Covered by `test_valuelist_gate46_v1_0` (107 / 0): each list row equals the
single-value call that names the same value, and the hand `margins, at()`
+ `lincom`; `metest` across list rows equals `lincom` on the hand margins;
lists on a binary moderator equal `by()`; mixed varlists with the list on
one variable; two models; mlogit with `totalme`; the refusals with their
controls. Corpus A 130 / 0, B 153 / 0, D 78 / 5 on this build (the five are
the same reference-only cells as on rev54).

## v1.0.2 -- 02sep2026, the estimation sample

Three defects, all found by the corpus run of the lecture and chapter
do-files (531 pass / 11 FAIL / 0 NOREF against rev53).

**Levels and category counts come from the estimation sample.** The levels
of the by()/over() variable (`:1109`) and of a binary or nominal focal
variable (`:1492`, `:1537`, `:2297`, `:2940`) were read with a bare
`levelsof`, and the category count that picks the binary or nominal path,
with the base level, came from a bare `fvexpand` (`:1249`, `:1524`, `:1856`,
`:2886`) -- all over the whole dataset in memory. A model fit with `if` on a
subset of the levels of a nominal variable then asked margins for a level it
never saw:

    invalid at() option; at level for factor country not present during estimation
    [2._at#12.country] not found

(corpus B28 and B29, `regress ... i.country if country == 276 | country ==
566` on lvm_wvs6, which holds many countries; the control B29c, the same
model on data restricted to the two countries, passed with the 2024 values).
A variable with three levels in the data and two in the sample took the
nominal path and asked for the third.

One if-condition now serves every one of those reads: `meclevif`, defined
where `mec_sample` is built on each of the two paths (`:513`, `:979`), and
empty when that sample holds no observation so the command does what it did
before rather than reading nothing (rule 46). `fvexpand` accepts if/in. The
continuous-detection `fvexpand` at `:1231` is unchanged: a factor variable
is a factor variable whatever the sample, and a one-level factor is refused
by the guard at `:1268` before its count matters.

The two-model path reads the levels present in the union of the two samples
(suest2's posted esample), which is per system rather than per model: a
level present in only one model's sample is still requested from both. That
is strictly narrower than before and is left as a note, not a claim.

**A continuous focal variable present only in model 2.** `mecompare
occprest, models(m3 m4)` with occprest absent from m3 (corpus C09, cme-6_2
#6) stopped with `matrix _mlincom does not exist`: the blank model-1 row was
added with `_mec_addz` before anything had created the matrix. The binary
(`:2113`) and nominal (`:2339`) paths carry a faux init for the first table
row; the continuous path now carries the same one (`:2016`), gated on
`confirm matrix _mlincom` rather than on the row position, because that is
the condition the failure actually depends on. Blank rows are not posted,
so e(b) holds one estimate for that variable and metest numbering is
unchanged.

**One model with by()/over() and a continuous focal variable labels its rows
with the level.** `mecompare age, models(opintmod) by(woman)` printed
`opintmod / opintmod` (corpus B01); the binary and nominal paths print the
level. The continuous path passed the model name into `_mec_rowlab` in the
single-model case (`:1995`); it now passes the level label, which is what
`bolab_` already holds, and which equals the model name when there is no
by()/over(), so the no-level table is unchanged. Display only: coefficient
names in e(b) come from `MEC_eqn`/`MEC_rol`/`MEC_lev` and did not move.

Covered by `test_sample_scope_gate45_v1_1` parts A, D and E; every defect
cell is paired with a control on the kept data and, where a value comes out,
asserted equal to it.

## v1.0.1 -- 31aug2026, long variable names

`mecompare` refused any focal variable whose name ran past about 25
characters, and the nominal path refused past about 17. Stata permits 32.
The message named a macro the user never wrote:

    _changeoccupational_prestige_score invalid name

Stata caps a local macro NAME at 31 characters, and thirteen per-variable
macros built their name out of the variable name -- `change`varname'',
`mcineqL_`varname'', `mcineqpos_`varname'_`vp'', `mcineqn`mm'_`varname'_`vp'',
`mcineqN`mm'_`varname'', `mcctrlo_/hi_/lab_`varname'_`nc'' and
`mcncontr_`varname''. Eleven shapes here, two in `totalme.ado`, none in
`meinequality.ado`. Found incidentally by a probe that was measuring
something else; scanned for the defect afterwards rather than fixing the one
instance that surfaced.

**The name was never needed in the key.** Both regions that WRITE these
macros and both that READ them are `forvalues i = 1/`numvars'' over
`list_ivs', so position `i' identifies the same variable in all four. The
key is now the position, held in `vnum' -- which is `totalme`'s existing
idiom (`totalme.ado:953`, `:1307`), put there because inner loops clobber
`i'. mecompare's do not today, but a key resting on that is a key that
breaks quietly later.

`change`varname'`h'' gains a separator, `change`vnum'_`h'', because without
one i=1,h=2 and i=12 would both read change12.

Nothing user-facing moved: the tables still print the variable name. A
Stata variable name cannot begin with a digit, so the new keys cannot
collide with the old ones; checked that no literal `change<digit>`,
`mcctrlo_<digit>`, `mcineqL_<digit>` or `mcncontr_<digit>` exists in either
file. `sibling_audit` reports 135 divergences before and after.

`test_longname_gate_v1_0` drives 25, 27, 30 and 32-character names through
every path that carried one of the thirteen shapes, each paired with the
identical short-name call and required to agree to 1e-12 -- so it fails
whether the long name aborts or runs and computes something else.

## v0.3.1 -- 01sep2026, tighter labels

Parentheses and commas bind tight in the row label: `abs(ttl_exp)` not
`abs ( ttl_exp )`, `min(age,ttl_exp)` not `min ( age , ttl_exp )`,
`(age~1 - age~2) - (mar~1 - mar~2)` not the padded form. Binary operators
keep their spaces. Every label carrying a parenthesis gets shorter -- 21 to
18, 21 to 16, 22 to 16 -- in the column the row-label work of v0.2.0 was
about.

Display only. The label block never reads or writes `lcstr`, which is what
goes to `nlcom` and `test`; gate cell F.15 pins that by VALUE, re-running
`1 - abs(2)` after the change and requiring the estimate to still match
`b1 - abs(b2)` from `e(b)`.

Checked before the change that no label crosses the 32-character boundary
and silently takes a different rung of the abbreviation ladder. The nested
case goes 37 to 33 -- still over, so it still falls back to the expression
and C.6b/C.6c/C.6d are unmoved.

## v0.3.0 -- 01sep2026, nonlinear functions

`metest 1 - abs(2)` returned "abs is neither a marginal effect number nor a
coefficient name" while `nlcom _b[age] - abs(_b[ttl_exp])` ran. The help had
claimed functions since the file was written -- `:25` and `:200` -- and no
instrument ever drove one. The claims gate covers `1 / 2` and
`(1 + 2) / #2`, which are arithmetic. The claim sat beside true neighbours
and went in untested.

TWO CAUSES. The decoder sorted every token into operator, number, or
coefficient name, with no fourth category, so `abs` fell to the name branch.
Separately, a multi-argument function could not be TYPED: the gatherer split
on the first comma to find the options, so `metest min(1,2)` sent `min(1` to
the decoder and `2)` to `syntax`.

BOTH FIXES ARE nlcom's. `gettoken ..., bind` (`nlcom.ado:75`) keeps a
parenthesised group whole, so an internal comma no longer ends the
expression. A token immediately followed by `(` is a function name and is
passed to `nlcom` verbatim -- `metest` keeps no list of Stata's functions
and does not want one: `nlcom` already rejects what does not exist, and a
list would go stale. `,` joins the operators, so `min(1,2)` resolves both
arguments as ME numbers.

`bind` returns a parenthesised group WITH its spaces, which would have put
`(1 - 2)` into `r(expression)` spaced where it never was. The gatherer
strips spaces, so the macro is exactly what it has always been.

An expression with `=` goes to `test`, which is linear-only; a function
there is refused with a message naming which half cannot do it, rather than
letting `test` produce its own.

Certified by `test_metest_rev49_v1_3`, 52 cells. PART F asserts VALUES: the
result of `1 - abs(2)` is checked against `e(b)` by hand AND against `nlcom`
run directly, `min(1,2)` against `min(b1,b2)`, and `exp(ln(2))` against an
identity that does not depend on the data. The controls are what make those
mean anything -- F.8 requires a bare unknown name to still be refused, since
a build that passed every token through untouched would satisfy the rest.

## rev49 -- 31aug2026, metest v0.1.6 -> v0.2.0

Three defects reported by the owner, and one change that was not asked for.

**`clear` is an option.** `metest, clear` is unchanged. `metest clear` --
the bare word, which every previous version accepted and the help
documented -- now refuses r(198) and names the form that works. Measured
before the change (`probe_metest_label_v1_0`, 6a): the bare form returned
rc 0.

**`metest` on its own redisplays the saved table.** It returned r(198) in
every shape tried -- nothing saved, two rows saved, both matrices saved,
with `title()`, with `decimals()`/`width()` (probe 6c-6g, 7b) -- so a loop
of `qui metest ..., add` had no way to show its result at the end. It now
redisplays whatever is saved, honouring `title()`, `decimals()`,
`width()`, `labwidth()` and `notable`, and refuses only when nothing is
saved. Table sizing moved into `_metest_show`, one table at a time,
because a replay has no `newmat` to size from; that also fixes
`stat(all)` followed by `1 = 2, add`, which sized the six-column estimate
table from the three-column test matrix.

**Row labels factor whatever every term shares.** Same-variable
expressions already split at the colon. Cross-variable ones did not -- the
colon was converted to `_` and everything was jammed into 32 characters:

| expression | before | after |
|---|---|---|
| `1 - 4` | `age_m1 - married_m1` | `m1` / `age - married` |
| `3 - 6` | `age_Difference - married_Diff~e` | `Difference` / `age - married` |
| `1 = 4` | `age_m1 = married_m1` | `m1` / `age = married` |
| `(1 - 2) - (4 - 5)` | `( age~1 - age~2 ) - ( mar~1 - ..` | `(1-2)-(4-5)` |

All four share their MODEL, not their variable, so none got a heading row.
The label now factors the variable when the terms come from one variable
and the model otherwise, and falls back to the expression when they share
neither. Two grammar facts settled by probe PART 1 and relied on here: the
32-character cap binds on the NAME side only, and the space after the
colon is not needed.

Also repaired: `eqlist` collected only non-empty equation parts, so a mix
of named and unnamed terms could look uniform and factor a variable the
expression did not share.

**Not asked for.** `metest 1 - 2` then `metest 4 - 5, add stat(all)`
stacked a 1x3 onto a 1x6 and aborted r(503) raw inside `matrix`. mlincom
guards this; metest guarded only the chi2-versus-F case. It now refuses
r(198) and says which statistics do not match.

`melincom.ado` and `melincom.sthlp`: the retirement notice told the reader
to type the form this release retired. Both repointed.

`mecompare.sthlp`: the owner's revision, adopted verbatim except for one
run-together sentence break (`(multiply-imputed data).For`). Note for the
record: the by()/over() paragraph no longer lists `ibn.`, which is the
owner's intent, but `mecompare.ado:1099` still ACCEPTS it
(`^i(b[0-9]+|bn)?\.`) and the comment above it says so deliberately. The
code is wider than the documentation, on purpose.

Certified 31aug2026: 30 gates (29 in the battery run plus the claims gate
re-run at v1.11), 150/150 help examples, `test_metest_rev49_v1_1` 37/0.

## rev48 -- 31aug2026, comments only (v1.0.0 unchanged)

Comment compression to the owner's one-line rule (HANDOFF rule 115);
no code line moved (verified token-identical). Removed text preserved
verbatim in COMMENT-HISTORY-rev48.md.

## v1.0.0 -- 30aug2026

Public release. No code change from v0.4.16; the version is promoted so
the number says what the release is. `suest2` goes to 1.0.0 the same day.

Help: two example directives repaired. The Examples section opened with
`sysuse nlsw88` and no `, clear`, which fails r(4) for anyone who clicked
the plotting section's examples first; and the plotting section's own
`sysuse` label omitted the `, clear` its command carries. Found by
`test_help_examples_v1_0`, which runs every clickable example in the five
help files from the shipped copies.

## metest.sthlp -- 30aug2026, help only

Two examples put a colon inside an unquoted `{stata}` command
(`metest age:m1`). SMCL splits at the first colon, so clicking ran
`metest age` and displayed the rest as the label. Both are quoted now.

## v0.4.16 -- 30aug2026

Pre-release audit. No computation change.

- Dead locals removed: `N` (set from the if/in count, never read), `nn_all`,
  `nvendspec` (three sites), `rownms` in `matinsert`.
- Header version notes (v0.3.8, v0.3.9, v0.2.99) and an orphaned note about
  the retired `me__#` globals relocated to `COMMENT-HISTORY-rev46.md`. The
  v0.2.99 note pointed at `suest2-mecompare-TODO.md`, which ships nowhere.
- Help: `group:s`, `groupn:ames`, `groupm:e` underlines now match the
  syntax line's minimum abbreviations.

Sibling changes of the same session: `meinequality` v1.8.6, `totalme`
v1.6.6. `metest.ado` and `mecomp.ado` are unchanged in code; their banners
now name this changelog, and `metest`'s revision notes live below.

## v0.4.15 -- 29aug2026

Two changes to what `mecompare` leaves in the user's session, and one repair
to the first attempt at the second of them.

### The stored system is named for the engine that built it

`engine()` has defaulted to `suest2` since v0.2.71, but the combined system
was still stored under `mec_gsem` -- the fallback engine's name, which
nothing reaches by default. It is now `mec_suest2` under the default engine
and `mec_gsem` only under `engine(gsem)`, and the name **not** in use is
dropped at store time, so a session that switches engines cannot leave a
second, stale system restorable under the other name.

`mec-final-gate.do` and `mec-final-gate-suest2.do` both drive
`est restore <system>` then `margins` and value-check the result; both are
re-pinned. `meinequality` v1.8.4 and `totalme` v1.6.4 take the same change.

### Estimation-sample markers are labelled -- at the END of the command

`estimates store` writes an `_est_<name>` variable to record `e(sample)` and
gives every one of them the same stock label. A user who had run the
help-file examples saw six, four of them the package's, with no way to tell
which was which.

The first attempt labelled each marker beside its store, and **failed**:
surface gate v1.12 cells 6.4, 6.5 and 6.7 came back with the stock label.
`probe_estlabel_v1_0` measured why -- 16 cells, no exception:

> `estimates restore NAME` rewrites `_est_NAME` and puts the stock label
> back, but **only when it actually swaps the active results**. Restoring
> what is already active leaves the variable alone.

    6b  est restore QMARG while QMARG active  -> KEPT
    6c  est restore QSYS  while QMARG active  -> RESET
    3a  est restore PSYS  while PSYS active,
        then margins, post                    -> KEPT

so `margins` is not implicated; the swapping restore is. `mecompare` restores
`mec_margins` eight times and `suest2_margins` restores each private copy by
name, all after the stores.

The labels now sit in the last executable block of the program. Hold names
are captured at the system store, where `e(suest2_holds)` is readable, and
used at the end, where it is not -- by then `e()` holds `mecompare`'s own
table. The probe found that too: PART 7 read `e(suest2_holds)` at the end,
got nothing, and silently relabelled nothing.

| variable | label |
|---|---|
| `_est_mec_suest2` (or `_est_mec_gsem`) | mecompare: est. sample for stored system ... |
| `_est_mec_margins` | mecompare: est. sample for stored margins mec_margins |
| `_est__mec_src` | mecompare: est. sample for source-model stash _mec_src |
| `_est___s2_<runid>_<i>` | suest2: est. sample for private copy of `<model>` |

**Known limit, stated rather than papered over.** The same Stata behaviour
means the user's own `estimates restore mec_suest2` puts the stock label
back. Nothing inside the command can prevent it. What is guaranteed is the
label at the moment the command returns, which is when `codebook` gets run --
the question that started this. Gate cells 6.16-6.17 assert the limit so it
cannot later be mistaken for a regression.

**One thing not established.** Cell 6.4 -- `mec_suest2` -- is not explained
by the measured mechanism: nothing on that path restores it by name. The
repair is positional rather than causal, which is why it does not depend on
knowing what did it, and PART 6 of the gate is what confirms or refuses that.

### Instrument

Surface gate v1.11 -> v1.13, PART 6, 28 cells: the stored names, the labels,
the alternate name dropped in both directions, the `_est_*` footprint flat
over four runs, the known limit, and the same assertions on both siblings.

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

## v0.4.12 -- 29aug2026

The mlogit `predict()` block was DELETED and then RESTORED unchanged. No
behaviour change ships at this version; what ships is the reason it must
stay, written beside it.

It was read as a v0.3-era family-name check superseded by the v0.4.1 rewrite
to category counts, on the grounds that it carries no `predlin` guard while
the category-count block six lines below explicitly permits `xb` and `eta`.
That reading was wrong and the missing guard is deliberate. Measured with the
block removed (probe_predmlogit_v1_0, 29aug2026):

- two models, `predict(xb)` -> r(198) `option outcome() is required after
  mlogit`, from official margins rather than from us, so the user gets
  Stata's error in place of ours
- one model, `predict(xb)` -> **rc 0 and a silently wrong answer**:
  `Predicting: Linear prediction, grp==1`, estimate 0.000, SE 0.000, p
  missing

mlogit normalises the base outcome to zero, so `xb` for the base category is
identically zero. mlogit is the one multi-category family whose linear
predictor is one per outcome EQUATION rather than a single index, which is
why the category-count rule -- right for ologit, oprobit, meologit,
xtoprobit -- is wrong for it. A refusal replaced by zeros is the worst
available outcome and this block is what prevents it.

Verified probe_predmlogit_v1_1, 16/16: three illegal forms still refused,
`predict(pr outcome(2))` still runs, and the refusal is asserted to be the
mlogit-named message rather than the generic one.

## v0.4.11 -- 29aug2026

**The two-model echo no longer claims a refit that does not happen.**

`mod1specs`/`mod2specs` appended `, vce(robust)` to each model's echoed
command line. The gsem-era engine really did refit each model that way;
suest2 refits nothing -- it reads the stored estimates and builds the joint
VCE from their scores. The line therefore attributed an option to the user's
model that the user never wrote, on every two-model table.

Measured 25aug2026, g41_cmd.txt and g42_cmd.txt: `p_logit` was fitted as
`logit y i.g c.x` with no `vce()` and echoed as `logit y i.g c.x,
vce(robust)`. Nothing in the testing tree asserts this text and
`mecompare.sthlp` never quotes it, so the echo is display-only in the strict
sense. Same line removed from `meinequality` v1.8.2 and `totalme` v1.6.2 in
the same pass -- fixing one and not its siblings is the propagation failure
this project already has a rule about.

The separate vce(robust) RECOMMENDATION printed above the echo is CORRECT and
stays: a constituent fitted without vce(robust) really does give different
standard errors from the ones this command reports. The gate asserts the
recommendation is still present as well as that the false echo is gone,
because deleting both would have made a one-sided check pass.

## v0.4.10 -- 29aug2026

**`e(predict_label)` is posted.** It reached the screen and nowhere else:
`plab1`/`plab2` were read from `r()` at the crosswalk, printed on the
`Predicting:` line, and discarded. No instrument and no downstream command
could read which quantity produced a table.

That also made the first version of the label check pass VACUOUSLY -- an
empty string is trivially not the old string, so `5a_old_gone` could not
fail. Measured probe_reslope_v2_2: `e(predict_label)` came back empty in all
three cells while the banner printed normally.

Posted now, with `e(predict1_label)`/`e(predict2_label)` when the two models
disagree, mirroring what the display already does. `check_eretnames`: 3
gained, 0 lost. `sibling_audit` 130 -> 133; the three new divergences are
mecompare-only and judged, since neither sibling displays a prediction label
at all. Documented under Stored results in `mecompare.sthlp`.

## v0.4.9 -- 26aug2026

Option C, chosen over adding a `post` option. `mecompare` keeps posting to
`e()` like `margins, post` — `metest`, `lincom`, `nlcom`, `test`, `mlincom`,
`coefplot`/`esttab` from `e(b)`, replay and the whole Saved-results section
all depend on it — and additionally **stashes the source model** so a
consecutive `models()`-omitted call recovers it instead of refusing.

- One-model runs stash the source under the reserved store `_mec_src`,
  alongside `mec_gsem` which the package already reserves and documents.
- Two-model runs **drop** the stash. `_mec_src` holds one model; recovering it
  for a two-model call would silently answer a different question. Absent
  stash means refusal by name, never a guess.
- Recovery is **announced**, naming the model being reused and pointing at
  bare `mecompare` for replay. Silently reusing a model the user doesn't
  remember naming was the standing objection to this design; saying so is the
  answer to it.

### Staleness guard

Stored estimates survive `clear`, so the stash can outlive the data it was
fit on:

```
logit y x  /  mecompare  /  use otherdata, clear  /  mecompare age
```

`_N` and the dependent variable name are recorded at stash time and must
still hold at recovery. Either failing is a refusal, not a fallback — a wrong
model quietly reused is worse than an error.

**Known limit, stated rather than papered over.** The guard is deliberately
not a `datasignature`: generating a new covariate between calls is ordinary
and harmless and would trip an exact signature every time. It therefore does
not catch a different dataset that happens to carry the same observation
count and a same-named dependent variable.

### Instrumented by

Surface gate v1.5 PART 2S. The recovery cells are the easy half; the ones
that matter are 2S.6/2S.7 (two-model run invalidates the stash) and
2S.8/2S.9 (moved data refuses rather than recomputes). 2S.5 value-checks a
recovered run against a freshly fitted one at mreldif < 1e-12 — recovery that
quietly returned different numbers would be worse than the refusal it
replaced.

## v0.4.8 -- 26aug2026

- **SELF-1.** `mecompare` is e-class: it posts its own table to `e()`. A
  second call with `models()` omitted therefore read that table as if it were
  a model, stored it under a tempname, and the family resolver refused it with
  `__000003 is a mecompare` followed by the list of supported estimation
  commands. Correct refusal, incomprehensible message.

  Reachable long before rev43, by typing `mecompare <varlist>` twice. v0.4.7
  made bare `mecompare` work, which made it the natural next keystroke and is
  how it surfaced (user report, 26aug2026: `logit` → `mecompare` →
  `mecompare age`).

  The models()-omitted branch now detects a prior `mecompare` in `e()` and
  says so, naming both remedies: refit, or replay with bare `mecompare`.

  **Why no instrument caught it.** Every gate cell refits the model
  immediately before the command under test, so `e()` was never a prior
  `mecompare`. Users fit once and run the command repeatedly. Surface gate
  v1.4 PART 2S drives consecutive calls without an intervening fit, for all
  three commands.

## v0.4.7 -- 26aug2026

Three defects found by the surface gate, an axis the battery did not
previously have. None was a model-family defect.

- BANNER: the 87-line `*!` history moved here. `which mecompare` now
  prints one line.
- REPLAY-1: the replay guard refused every bare `mecompare` after an
  ordinary estimation command with r(301), although the varlist-less
  form is documented in Overview and in `e(n_vars)`. Bare `mecompare`
  now falls through to the ordinary path when `e(cmd)` is not
  `mecompare`. `coeflegend` without a prior `mecompare` table is still
  refused, now by name. An empty `e()` still exits 301.
  Measured: cells 2.3a (was rc 301), 2.3b (varlist-less compute path
  sound, rc 0), 2.3c, 2.3d and 2.3e.
- LEAK-1: `est restore` in the one-model branch was the only unquieted
  restore in the file and printed `(results __000003 are active now)`
  above every one-model table. Measured: cell 2T.1.

## metest.ado

Current banner: `*! metest v0.1.6 Trenton Mize 2026-07-30`. Revision notes
moved here from the file header on 30aug2026, verbatim.

```
v0.1.6 added `capture program drop metest' -- without it, running the file
       a second time in a session failed with r(110), and every other
       command in the suite already had it.
v0.1.5 labwidth() capped at 32 (Stata rejects a longer row name).
v0.1.4 labwidth() option, matching mecompare, to widen the leftmost
       column. Default still sizes the table to 80 columns.
v0.1.3 a label too long even at maximum abbreviation is now cut at a token
       boundary and marked "..", instead of mid-name.
v0.1.2 labels from factor-variable names (1.collgrad, normal after margins,
       post) were rejected by matrix rowname; now applied defensively.
v0.1.1 no longer restricted to mecompare; message wording follows the
       originating command; chi2 and F tables cannot be stacked.
v0.1.0 initial version.
```

Help (30aug2026): `rown:ame` and `l:evel` underlines now match the syntax
line.

## mecomp.ado

`*! mecomp v1.0.0 Trenton Mize 2026-07-30`. Short-name alias; hands
everything to `mecompare` unchanged. Banner names this changelog as of
30aug2026; no other change.

## mec_mlincom.ado -- rev43, banner only

`which mec_mlincom` printed two `*!` lines. One is this file's own banner; the
other is the upstream attribution for Long & Freese's `mlincom` 1.0.3, which
`mec_mlincom` adapts. Upstream credit is not this file's version history, so it
was NOT moved here: line 9 was demoted from `*!` to `*` and left exactly where
it sits, beside the three upstream version lines that were already plain
comments. The source still carries the credit in full; `which` now shows one
line. No code line moved.

## Earlier history (verbatim, as it stood in the .ado at v0.4.6)

```
*! mecompare v0.4.6 Trenton Mize 2026-08-25
*! v0.4.6 PRED-MCAT-1 extension: with ONE model, predict() may carry an
*!        outcome(#) selection on multi-category models (ologit-kin,
*!        mlogit-kin, and their panel/multilevel counterparts). An
*!        outcome() selection returns a single quantity, so the same
*!        category-count reset the certified xb/eta path uses makes the
*!        whole downstream table machinery valid; the prediction itself
*!        passes through to native margins unchanged (one-model predspec
*!        is a passthrough). Two-model multi-category predict() remains
*!        xb/eta only, and one-per-category predictions (bare pr) remain
*!        refused; the refusal now names the one-model outcome() form.
*!        Value gate: test_predmcat_ext_v1.
*! v0.4.5 the syntax line's own numlist bounds (labwidth >19, statwidth
*!        >7) intercepted out-of-range values below the bound with
*!        Stata's r(125) before the v0.4.4 range guard could refuse
*!        r(198) with the actionable message (measured: labwidth(19)
*!        rc 125 in test_mech_batch_fix_v1 D). The bounds are removed
*!        from syntax; the guard owns the full documented ranges.
*! v0.4.4 five measured fixes, no new features:
*!        ENG-XB-1: same-DV engine(gsem) explicit predict() selectors now
*!        use the equation names mec_gsem actually returns (the clone when
*!        one was made); both selectors previously addressed the first
*!        gsem equation and model 2 collapsed onto model 1 exactly
*!        (measured, cert baseline E6).
*!        PW-ME-1: the one-model path now applies the same stage-weight
*!        gate suest2 applies to systems; a pweighted multilevel model
*!        with empty e(pweight1) was accepted one-model while the
*!        documented contract and the two-model route both refuse it
*!        (measured, cert baseline D2/D3).
*!        RS-MAT-1: e(table) is posted with copy, so the documented
*!        _mecompare matrix now actually persists (ereturn matrix MOVES
*!        without copy -- measured, cert baseline F2).
*!        RS-VAL-1: decimals() 0-7, statwidth() 9-20 and the labwidth()
*!        lower bound are now enforced up front with r(198), as the help
*!        documents (measured, cert baseline G1-G3, G5: labwidth(19)
*!        surfaced rc 125 from deep inside the table builder).
*!        CF-2: with two models, multi-category outcome rows are labeled
*!        from MODEL 1's value labels for every row, as the differing-
*!        label note has always promised; model-2 rows previously kept
*!        model-2 labels (measured, cert baseline J2).
*! v0.4.3 message text only. The vce(robust) warning promised that
*!        refitting with vce(robust) would make mecompare's results
*!        match the constituent models "exactly". Measured 21aug2026
*!        (mec-CME_examples-02/03.log, probe_mec_regress_se_v1_0.log):
*!        they do not, in two cases, and both are convention rather
*!        than defect. A `regress' constituent differs by
*!        sqrt((N-1)/(N-k)) -- regress corrects its robust VCE by
*!        N/(N-k) and suest2's sandwich by N/(N-1), the ML
*!        convention. Under `groups' each model differs by
*!        sqrt(Ng/(Ng-1))/sqrt(Np/(Np-1)) -- the same convention at
*!        the pooled N rather than the group's. Both measured to
*!        1e-13. A stacked system has one N and one sandwich, and no
*!        per-equation k, so a single convention is the only well
*!        defined choice. The promise is REMOVED rather than
*!        qualified: the recommendation to refit with vce(robust)
*!        stands on its own and does not need a guarantee attached.
*!        No control flow, no computation, no e() name changes.
*! v0.4.2 message-list only: fracreg (logit and probit), admitted at
*!        _mec_canonical v1.4.0 over suest2 0.1.80's predictor.
*! v0.4.1 category-count predict guard; stripe-assuming guard deleted.
*! v0.4.1 the multi-quantity predict() guard moves UPFRONT and is keyed on
*!        the outcome-category counts rather than a family-name list --
*!        which also closes a hole (xtologit and its kin were not in the
*!        old ordmod list) -- and the post-margins _predict-token guard is
*!        DELETED: it assumed the ordinary stripe's naming and fired
*!        falsely on specialized-stripe pairs (probe_predict_parity_v1_1:
*!        xtlogit-re pr/pu0, both actually sound). Wrapper-vocabulary
*!        limits (ir, streg time statistics, tobit pr->prrange) surface
*!        with suest2's own actionable messages and are documented.
*! v0.4.0 two changes, both measured first:
*!        COMPARABILITY: the cross-family pair whitelist is gone. Two
*!        models are comparable when they return the same number of
*!        predictions; multi-category pairs must also agree on outcome
*!        values. The stripes need not match: prefixes are READ off e(b)
*!        per model. Value gate: test_mecompare_gate29_combos_v1_0.
*!        predict(): with two models the user's statistic passes through
*!        as per-model selectors -- probe_predict2_v1_0 measured pr and n
*!        posting the same layout as xb -- guarded by the family refusals
*!        and a post-margins one-quantity-per-model check.
*! v0.3.11 message-list only: xtpoisson (re) covers both RE distributions.
*! v0.3.11 message-list only: xtpoisson (re) now covers both RE
*!         distributions (_mec_canonical v1.3.0 admits the gamma one).
*! v0.3.10 message-list only: tranche J/K estimators and xtcloglog (re).
*! v0.3.10 message-list only: the supported-commands message now names the
*!         tranche J/K estimators (_mec_canonical v1.2.0) and xtcloglog
*!         (re), which resolver v1.1.0 admitted but the message never
*!         gained. No code path moved.
```
