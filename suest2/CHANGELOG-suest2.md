# CHANGELOG -- suest2 package

Version history lifted out of the `.ado` files at rev43. `which` printed
every one of these lines; each file now carries a single banner. Nothing
is edited: the blocks below are the `*!` lines verbatim, in file order,
with the leading `*!` stripped.

Files: 11. Lines moved: 289.

Route map: ROUTE-MAP.md.

---

## suest2.ado

Current banner: `*! version 0.1.93  25aug2026`

```
0.1.93 routing containment: the 0.1.90 scan admitted plain ordinal
       constituents, which made an ALL-ordinary ologit+oprobit pair
       satisfy the nclasses>1 arm and hijacked it from the working
       ordinary route into the heterogeneous one, where an all-plain
       system has no grouping variable (mec-final-gate O pair,
       measured 25aug2026; the 0.1.90 containment cell tested only
       the same-class ologit+ologit shape). The scan now requires
       mixed company for every arm, and the estimate program refuses
       all-plain systems by name as defense in depth.
0.1.92 documentation alignment release: suest2_p drops the dead
       cauchit branch (GLM-1); suest2.sthlp corrects the stale
       0.1.79 banner, the glm link list, the panel model lines
       (DOC-S2-1), and documents the 0.1.90/0.1.91 plain-ordinal
       heterogeneous support and the gologit2 version note.
0.1.91 completes 0.1.90: the estimate program's own homogeneity
       shortcut guard -- a second copy of the routing condition the
       0.1.90 scan edit relaxed -- still redirected same-class
       plain+mixed ordinal pairs to the family-specific route, which
       refuses them (test_cf1_ext_v1: meologit+ologit and
       meoprobit+oprobit r(322) homogeneous-shortcut refusals, while
       xtologit+ologit passed its full value battery including the
       1e-17 external V oracle, and melogit+ologit passed as a
       two-class system). The guard now exempts plain-with-mixed
       company, mirroring the scan.
0.1.90 CF-1 extension: ordinary ologit and oprobit are admitted as
       constituents of the heterogeneous mixed-family route, so
       xtologit+ologit, meologit+ologit and their probit twins now
       combine instead of refusing r(322). Measured groundwork
       (probe_cf1_hetero_v1): the route's scores are native and its
       me-family constituents supply them per COLUMN, while ordinary
       ordinal models supply them per EQUATION (rc 103 when asked for
       column counts), so the plain path expands equation scores to
       columns (slope columns times the covariate via fvrevar, zeros
       for omitted columns, cutpoints one to one). Plain constituents
       carry no grouping variable; they inherit the joint cluster from
       their mixed partner, exactly as the observation-layout
       alignment already sums scores within the partner's groups.
       Admission requires an unprefixed, unweighted, conventionally
       estimated store; anything else keeps today's refusals. The
       route's internal block-reproduction check gains a plain variant
       (_robust2 over the expanded scores) because the native variant
       asks predict for column-count scores, which ordinary ordinal
       models refuse. Value gate: test_cf1_ext_v1.
0.1.89 the change is in suest2_p.ado: the shared ordinary branch gains
       the family statistic gate (PRED-ORD-1). Banner + runtime only
       here.
0.1.88 the change is in suest2_p.ado: -rename- on the bridge repost,
       completing the 0.1.87 stripe merge (which was measured inert
       because repost without rename silently keeps prior column
       names -- probe_merge_localize_v2). Banner + runtime move here.
0.1.87 the change is in suest2_p.ado: the restore/repost bridge stripe
       merge fixing S2-PRED-1 and M1-PRED-1 (factor at() counterfactual
       collapse for tobit/intreg/heckman/streg and melogit/meprobit).
       Mechanism measured in probe_legacy_bridge_mech_v1 (14/0); see
       the suest2_p.ado banner. This file moves banner + runtime
       version only.
0.1.86 SKIPPED: number retired with the cancelled pre-certification
       candidate so a stale copy cannot masquerade as a release.
0.1.85 the runtime self-report was stale AGAIN. 0.1.84 moved the
       banner and left ereturn local suest2_version at "0.1.83" --
       the identical defect 0.1.83 had just been cut to fix, made one
       revision later by the person who wrote the fix. 0.1.84 was
       packed and never released.
       Caught by gate 32 v1_1 PART 0, which exists for exactly this
       and was added at 0.1.83. It worked. What did NOT work was the
       comment beside the string asking the next editor to keep it in
       step: a comment is not a mechanism. stata_preflight.py now
       checks banner against runtime string at BUILD time (E10), so
       the next occurrence is caught before a battery run rather than
       during one.
0.1.84 the Gaussian-RE bridge accuracy refusal named a number that
       cannot fix it. It said "use at least 12 quadrature points" to a
       model already fit with 12 -- minquad is the bridge FLOOR, below
       which scores are unavailable, and a model can clear that floor
       and still miss the accuracy tolerance. Anyone following the
       instruction got the identical refusal.
       The message now reports what the model HAS, the discrepancy it
       produced, the tolerance it missed, and a concrete refit to try.
       Measured (probe_xtquad_v1_0): xtlogit re on nlsw88 sits at
       ratio 3.087 at its default 12 points, 0.270 at 16, and 0.047 at
       32 -- so doubling is a sound suggestion, and it is offered as a
       suggestion rather than a promise.
0.1.83 e(suest2_version) reported "0.1.79" while the banner read
       0.1.82. The hardcoded string had not moved since 0.1.79, so
       every release from 0.1.80 onward -- including the certified
       rev 30 push candidate -- told callers the wrong version at
       RUNTIME while the file said otherwise. Nothing depended on it
       numerically, but it is the value instruments and users read to
       decide what is installed.
       Found by test_suest2_xtgre_bare_v1_1, the one instrument that
       reads e(suest2_version) and compares it; the battery's other
       version checks all read the FILE BANNER, which was correct the
       whole time. Two different claims, and only one was being
       tested. Gate 32 v1_1 now asserts they agree.
0.1.82 ivprobit and ivtobit admitted, completing parity: every family
       suest2 combines is now drivable except the six that are
       measured impossible. Needed mec_share v1.3.0 first -- the e(b)
       predictor union spans their reduced-form equation and returned
       the instrument as a predictor.
0.1.81 six families from the parked set: betareg, truncreg, hetprobit,
       zip, zinb, biprobit. Per-family capture branches supply the
       metadata each prediction needs (betareg link normalized out of
       its own dialect; zip/zinb inflation link from e(inflate)) and
       the systempred list admits all six. Gate 31.
Candidate history: CHANGELOG-suest2.md. Route map: ROUTE-MAP.md.
0.1.80 fracreg (logit and probit) joins the active-system predictor:
       the family capture reads the link from e(cmdline) word 2 (fracreg
       posts no distinguishing macro -- measured), and prediction reuses
       the glm link-inversion branch, whose logit and probit cases are
       exactly fracreg's mu. Value gate: test_suest2_fracreg_gate30_v1_0.
0.1.79 is the simplification release: no behavior change intended. One
defect fixed: suest2_xtmlogitscan declared version 17 and ran uncaptured,
so 0.1.73-0.1.78 exited r(9) on Stata 16 for every input.
```

## suest2_p.ado

Current banner: `*! version 0.1.93  01sep2026`

```
0.1.93 duplicate inlist() entry removed. The log-log inverse-link
       branch listed four spellings but only three distinct ones:
       "log-log", en-dash "log–log", "log_log", and en-dash
       "log–log" again. inlist() takes at most ten string arguments
       and one slot was spent twice, so an intended alternative was
       either lost or never added. Behavior-neutral: the duplicate
       could never match anything the surviving entry did not.
       No em-dash entry was added in its place -- glink reads
       e(suest2_link#), which suest2.ado:449 writes as the ASCII
       form, and there is no evidence any other dash reaches it.
       Found by inlist_audit.py, which scans the whole release; it
       is the only such call in it.
0.1.92 dead code removed with its claim: the cauchit inverse-link
       branch was unreachable (standard glm offers no cauchit link;
       measured r(198) at fit time, GLM-1) and the help claimed the
       link. Both are gone together. Behavior-neutral by measurement.
0.1.89 PRED-ORD-1: the shared linear/binary/count branch gains the
       family statistic gate every other family branch already had.
       Recognized but family-inappropriate tokens fell through to the
       family default, silently changing the estimand -- measured:
       two-model regress predict(pr) equaled default xb and poisson
       predict(pr) equaled the default mean, points AND variances,
       while native and one-model use refuse the same tokens r(198).
       Allowed now: xb for regress/anova/xtreg/ivregress; pr or xb for
       logit/logistic/probit; n or xb for poisson/nbreg. Everything
       else refuses r(198) with the family's supported list. No
       computation moved: every certified positive predict() cell used
       only the allowed tokens.
0.1.88 one word: the bridge repost gains -rename-. 0.1.87's stripe
       merge was correct but inert, and probe_merge_localize_v2
       measured why: -ereturn repost b=- WITHOUT rename posts the
       VALUES and silently keeps the PREVIOUS column names (measured:
       submitted bcf names, posted names reverted, predict gap 0).
       WITH rename the names post and the native predictor responds
       (measured end-to-end on melogit: names kept, mu-marginal gap
       .151 = the true effect). rename with an unchanged stripe is a
       no-op, so every non-margins call through this repost behaves
       exactly as before.
0.1.87 S2-PRED-1 and M1-PRED-1, one measured mechanism: margins applies
       scalar-list factor at() counterfactuals by rebinding the factor
       columns of the ACTIVE e(b) stripe to counterfactual tempvars --
       the data never change (probe_legacy_bridge_mech_v1, 14/0). Both
       restore/repost bridges (legacy and multilevel) then overwrote
       the stripe wholesale from the restored ORIGINAL result, so the
       native predictor read the real variables and every two-model
       factor counterfactual was invariant: tobit, intreg, heckman,
       streg (legacy), melogit, meprobit (multilevel -- the other me
       families route through suest2_margins' specialized path for
       at() and never hit the bridge, which is why mecloglog was a
       passing control on identical code). Fix: _s2p_mergestripe keeps
       the ORIGINAL equation names and adopts an active column name
       only where it differs AND carries the margins tempvar
       signature; anything else keeps the original name, exactly the
       old behavior. Continuous at(...=generate()) was never affected:
       margins rewrites the data for those.
0.1.86 SKIPPED. The number was used by a cancelled pre-certification
       candidate (24aug2026 handoff); it is retired so no stale copy
       of that candidate can masquerade as this release.
0.1.85 no change here; the banner moves with suest2.ado.
0.1.84 no change here; the banner moves with suest2.ado.
0.1.83 no change here; the banner moves with suest2.ado, which fixed a
       stale e(suest2_version).
0.1.82 ivprobit and ivtobit. Both native defaults are the plain linear
       index of the STRUCTURAL equation -- predict with no options
       labels them "Fitted values" and "Linear prediction" -- and both
       were value-verified exact against native predict (max reldif 0,
       probe_fam_forms_v1_1). The average-structural-function forms are
       NOT these: ivprobit pr measured .0056 against normal(xb) and
       ivtobit e()/ystar() measured .031/.047 against the plain tobit
       forms, so they are refused rather than approximated.
0.1.81 six new family branches, each returning that family NATIVE
       DEFAULT statistic. Every closed form value-verified against
       native predict (probe_fam_forms v1_0 and v1_1, 20aug2026):
         betareg   cmean = linkinv(xb#1)   0 / 0 / 0 / 8.6e-17
         truncreg  xb    = xb#1            exact
         hetprobit pr    = normal(xb#1/exp(xb#2))    0
         zip zinb  n     = (1-F(xb#2))*exp(xb#1)     0 / 2.3e-16
         biprobit  p11   = binormal(xb#1,xb#2,tanh(xb#3))  7.3e-17
       No option KEYWORD is added and no existing branch is edited,
       so no badopt list outside these six changes.
0.1.80 the glm link-inversion branch also serves fracreg (mu default,
       xb; links logit and probit from the per-model capture).
Candidate history moved to CHANGELOG-suest2.md at 0.1.75 candidate 19.
```

## _mec_canonical.ado

Current banner: `*! _mec_canonical v1.7.0 Trenton Mize 2026-08-27`

```
v1.7.0 moves melogit and meprobit from tranche A to tranche B, so
       r(spec) returns 1 for them and the mecompare crosswalk builds
       `<store>:' prefixes instead of `N._predict#'.

       This is the OTHER HALF of suest2_margins candidate 20 and must
       never be separated from it. Candidate 20 gives melogit and
       meprobit the unconditional native-constituent flag; the native
       route posts the by-equation stripe. Moving the route without the
       tranche was measured (probe_reslope_v1_1, 27aug2026) to produce
       r(111) `[1._predict#2._at] not found' on ALL TWELVE melogit and
       meprobit cells -- including the intercept-only ones that had
       worked before the patch. The route flag and the stripe dialect
       are one change.

       mixed stays alone in tranche A: it takes the fall-through route
       and still reads D1.

       This does NOT change the quantity any family reports.
       probe_mecestimand_v1_0 measured mecompare's constituent against
       eleven candidates at intpoints 3, 7 and 15: melogit (fall-through
       route at the time) and mecloglog and mepoisson (native route)
       ALL equal the centered unit change under Stata's default
       prediction, reldif 0.000e+00, nearest rival 4.6e-04.

       Closed mehetero as a side effect. The melogit+meprobit pair had
       failed r(111) in every run, with a random slope AND with a random
       intercept: it enters the native path unconditionally through
       `ismehetero' while melogit sat at spec=0. Verified, not assumed
       (probe_reslope_v2_2).

       Route map page: melogit and meprobit D1 -> D2, gate 24 v2.5.
```

```
v1.6.0 admits ivprobit and ivtobit, the last two families suest2 can
       combine that were not yet drivable. Their defaults were exact
       all along; what blocked them was the PREDICTOR LIST, fixed at
       mec_share v1.3.0 by restricting the e(b) scan to the outcome
       equation for these two. Value gate:
       test_suest2_ivpair_gate32_v1_0, which asserts the instrument is
       absent from the predictor list as well as checking values.
v1.5.0 admits six more of the parked families: betareg, truncreg,
       hetprobit, zip, zinb, biprobit. suest2 0.1.81 gives the
       active-system predictor each one NATIVE DEFAULT statistic,
       every closed form value-verified against native predict.
       Value gate: test_suest2_famsix_gate31_v1_0.
       ivprobit and ivtobit are NOT here: their defaults are exact
       too, but mec_share ebvars returns the INSTRUMENT among the
       predictors (xe x z for a one-instrument fit), because the
       e(b) union spans the reduced-form equation. Admitting them
       would put a structurally-zero row in the table. Measured
       probe_mec_admit_v1_0; needs an outcome-equation restriction
       in the shared extractor first.
v1.4.0 admits fracreg (logit and probit), the first family from the
       parked ten: suest2 0.1.80 gave the active-system predictor its
       mu (the glm link branch). Value gate:
       test_suest2_fracreg_gate30_v1_0.
v1.3.0 admitted xtpoisson re-gamma, closing the parity holdouts.
v1.3.0 admits xtpoisson re-gamma, closing the parity holdouts: cre is
       measured-impossible in ALL call shapes and xtnbreg fe has no
       scores to build a sandwich from (probe_xt_holdouts_v1_0).
v1.2.0 added tranches J and K, the xt parity arc (probe_xt_parity_v1_0;
       value gate test_mecompare_gate28_xtparity).
v1.2.0 adds tranches J and K, the xt parity arc. Measured 19aug2026
       (probe_xt_parity_v1_0): thirteen candidate cells fitted; twelve
       combine at rc 0 and post layouts the crosswalk already drives.
       Value gate: test_mecompare_gate28_xtparity_v1_0.
v1.1.0 admits xtcloglog re to tranche H. Measured 18aug2026: fitted with
       intpoints(24) the pair combines and margins posts. It was excluded
       because suest2 rejects it at the default 12 points, which is a
       quadrature question, not a support one.
Extracted VERBATIM from mecompare.ado v0.3.5 lines 4062-4355. The body
below is byte-identical to the subprogram it replaces; the extraction is
asserted byte for byte by patch_extract_canonical.py and measured
against the inline original by test_canonical_extract_v1_0.do.

Ships with suest2, which is a prerequisite for mecompare, meinequality
and totalme. It lives here rather than in mecompare because all three
post-estimation commands must agree on which models the suite supports,
and a subprogram inside one of them cannot be that agreement. A second
copy anywhere would shadow this one depending on load order -- rule 49.

Candidate history for the model-support tranches: CHANGELOG-mecompare.md.
```

## suest2_cleanup.ado

Current banner: `*! version 0.1.75  06aug2026`

```
CHANGED WITHIN 0.1.75 (was 0.1.59). A file banner carries the PACKAGE
release at which that file last changed -- suest2_mi.ado still reads
0.1.59 for exactly that reason -- so this reads 0.1.75. Nothing has been
released past 0.1.75, e(suest2_version) stays there deliberately, and 35
suite members assert it.
Restore an EMPTY e() on exit, not just a populated one.
  The discovery loop below does `estimates restore' on every stored
  result in turn. The active result is saved and put back afterwards --
  but ONLY when e(b) existed on entry. With an empty e() and any stores
  in memory, the loop therefore left the LAST result it restored sitting
  in e(), silently handing whatever ran next a model it never asked for.
  Measured (diag_mec0295_P3, 06aug2026): mecompare calls
  `capture suest2_cleanup, force' before its own syntax statement, and
  with e() cleared it was handed a logit from the store list; with the
  stores dropped as well, e() stayed empty and the caller behaved
  correctly. Latent since mecompare v0.2.80 added that call, and harmless
  until mecompare v0.2.95 became the first caller to READ e().
List or remove private estimates and composite weights created by suest2.
```

## _mec_prefix.ado

Current banner: `*! _mec_prefix v1.0.0 Trenton Mize 2026-08-18`

```
Extracted VERBATIM from meinequality.ado v1.3.6, where it was
_mei_prefix. The body below is byte-identical to the subprogram it
replaces apart from the program name; the extraction is asserted by
patch_extract_mec_helpers.py and measured against the inline original by
test_mec_helpers_extract_v1_0.do.

Ships with suest2, which is a prerequisite for mecompare, meinequality
and totalme. totalme needs the same read: its statistic sums over
outcome categories, so it addresses every model x outcome x level cell
and cannot use a prefix rule that is one measurement behind.
A rule can be wrong about a layout. A read cannot.
```

## _mec_omitchk.ado

Current banner: `*! _mec_omitchk v1.0.0 Trenton Mize 2026-08-18`

```
Extracted VERBATIM from meinequality.ado v1.3.6, where it was
_mei_omitchk. The body below is byte-identical to the subprogram it
replaces apart from the program name; the extraction is asserted by
patch_extract_mec_helpers.py and measured against the inline original by
test_mec_helpers_extract_v1_0.do.

Ships with suest2, which is a prerequisite for mecompare, meinequality
and totalme. It lives here because totalme needs the same guard and a
second copy would shadow this one depending on load order -- rule 49.
Same reasoning, and the same move, as _mec_canonical at 1.0.0.
```

## mec_gsem.ado

Current banner: `*! mec_gsem v0.2.1 Trenton Mize 2026-08-17`

```
v0.2.1 resolve the family through _mec_canonical. A logistic model
       reached gsem as "logistic", which is not a gsem family, and the
       pair exited 198 -- although logistic IS supported and is only
       logit with odds-ratio reporting.
v0.2.0 self-contained: the predictor lists are read from each stored
       model here instead of arriving in ivs1()/ivs2(), so any caller
       can combine two models with two store names. meinequality and
       totalme could not build those lists and so could not reach this
       engine at all.
Candidate history moved to CHANGELOG-suest2.md at 0.1.75 candidate 19.
```

## suest2_xtregmle_p.ado

Current banner: `*! version 0.1.73  30jul2026`

```
Score predictor for private xtreg, mle analytic-score bridge estimates.
Renamed from the xtmlbridge stem at 0.1.75 candidate 18: the old name
said xtmlogit, a different family. Contents unchanged apart from the
program name, which must match the filename for Stata to find it.
```

## suest2_margins.ado

Current banner: `*! version 0.1.75  03aug2026`  (line 2: `* Candidate 21.`)

```
Candidate history moved to CHANGELOG-suest2.md at 0.1.75 candidate 19.

candidate 21 (29aug2026) -- LABEL-1. predict_label was the hardcoded
       string "Predicted mean, fixed portion only", posted at two sites
       and never value-checked by any instrument. It was FALSE.
       probe_mecestimand_v1_0 separated the candidates by value:
       mepoisson at intpoints 15 returned 0.3894204848584 through
       mecompare, against 0.3641712595445 for the fixed-portion form and
       0.4380523857817 for the marginal form -- matching the DEFAULT and
       neither of the others. probe_meroute_v1_0 then measured that for
       every me family the default IS the marginal prediction: default
       and predict(mu marginal) agreed to every printed digit in all
       eight nonlinear cells.

       Replaced with "Default prediction for each model", deliberately
       family-agnostic: this path also serves eight xt families and
       ivregress, where "random effects integrated out" would be wrong
       or meaningless. What the default MEANS per family belongs in the
       help file, and mecompare.sthlp now states it.

candidate 20 (27aug2026) -- ROUTE-1. Adds `allmelogit' and `allmeprobit'
       and puts them in the UNCONDITIONAL arm of the native-constituent
       gate, alongside allmecount, allmeologit, allmeoprobit and
       allmecloglog. melogit and meprobit reached that path only through
       (`hasdydx' & `allme'), and `hasdydx' is a string search for
       "dydx(" in the margins call. mecompare emits an at() unit shift
       and never dydx(, so for those two the gate never opened and every
       random-slope system exited r(133) "unknown function var()" while
       nine sibling families ran.

       The mechanism was already documented at line 72: mixed-effects
       systems carry ancillary var()/cov() stripes, official margins
       parses those function-like names, and the native path exists to
       dodge exactly that.

       Isolated on one system, probe_meroute_v1_0 PART 2: dydx alone
       rc 0, at() alone rc 133, dydx WITH at() rc 0, at() with an
       explicit predict() rc 133. Intercept-only control ran all four.

       `allme' is deliberately LEFT inside its conjunction: it also
       covers eight xt families that are not implicated.

       REQUIRES _mec_canonical v1.7.0 in the same pass. See that file.

       Verified probe_reslope_v2_1: melogit and meprobit 12/12 cells,
       points at 1e-7 and robust SEs at 1e-6, across all five
       random-effects shapes -- intercept, one slope,
       covariance(unstructured), two slopes, nested two-level with the
       slope inner -- and with the focal variable outside the random
       part.
```

## suest2_mi.ado

Current banner: `*! version 0.1.59  26jul2026`

```
Internal engine: re-estimate labeled models within mi estimate and call suest2.
```

## suest2_marg_check.ado

Current banner: `*! version 0.1.59  26jul2026`

```
Estimability hook used by official margins after suest2.
```

---

## mec_share.ado

Added 30aug2026. Current banner: `*! mec_share v1.3.0 Trenton Mize 2026-08-20`.
Revision notes moved here from the file header, verbatim. The header had
pointed at `suest2-mecompare-TODO.md`, which ships nowhere.

```
v1.3.0 _mec_ebvars restricts its scan to the OUTCOME equation for
       ivprobit and ivtobit. Those two carry a reduced-form equation
       alongside the structural one, so the e(b) union returned the
       INSTRUMENT as a predictor (xe x z for a one-instrument fit,
       measured probe_mec_admit_v1_0). z appears in no structural
       equation, so a marginal effect on it is zero by construction and
       would have put a meaningless row in every comparison table.
       The rule lives HERE rather than at the two mecompare call sites
       because the model is live in e() at both, so the extractor can
       read e(cmd) itself and the two sites cannot desync. Behaviour for
       every other family is byte-identical: the limit is empty unless
       e(cmd) is one of the two. suest2_margins_ebvars, the separate
       copy in suest2_margins.ado, is deliberately NOT changed.
v1.2.0 _mec_ebvars also returns s(fvvars), the factor-dialect list
       (ib<base>.name reconstructed from e(b) level markers) that
       mecompare's annotator and ME code require. s(vars) unchanged.
v1.1.0 _mec_ebvars, the e(b)-sourced predictor list (parity-arc port),
       and the -mec_share ebvars- autoload entry. Level shares unchanged.
v1.0.0 level shares, one implementation for the three commands.
```

## mec_wcheck.ado

Added 30aug2026. Current banner: `*! mec_wcheck v1.0.0 Trenton Mize 2026-07-31`.

```
v1.0.0 weight validation shared by mecompare, meinequality and totalme:
       a weight given on the command must match the stored model's, and a
       weight given alongside svy: is refused.
```

## suest2.sthlp -- 30aug2026, help only

`cl:uster`, `r:obust`, `l:evel`, `ef:orm` underlines now match the syntax
lines' minimum abbreviations, and `nowarn` -- the option the three commands
pass and `mecompare` echoes under `commands` -- has a row. No `.ado` moved.

---

## suest2.ado 1.0.0 -- 30aug2026

Public release. The banner and `e(suest2_version)` move from 0.1.93 to
1.0.0; no other line changes. The 36-suite regression is re-run because an
executable line moved (BATTERY.md's rule), not because anything it measures
could have changed. The suites' own floors are component-wise minimums
(`needs 0.1.75 or later`, encoded 1075), so 1.0.0 passes them without a
repin; the battery runner's EXACT pin moves to 1.0.0.

## suest2.ado 1.0.1 -- 23sep2026

A caller running under version 15 or older -- a `version 15` line at the
top of a do-file, as in Bing Han's example files -- is now refused at once,
rc 9, with a message naming the version to set. Under such a line every
two-model comparison had stopped inside suest2 with r(509) "matrix
operators that return matrices not allowed in this context"
(`probe_bing_*_v1_0`, 22sep2026); the same pairs run at version 16 or later
(`probe_bing_checks_v1_0` B2). The suite supports version 16 or later only
(owner, 23sep2026). The check reads `_caller()`. Help: a "Stata version"
section. Nothing else moves; results at version 16 or later are unchanged.
The banner and `e(suest2_version)` move to 1.0.1; the 36-suite regression
is re-run because an executable line moved, and the battery runner's EXACT
pin moves to 1.0.1.
