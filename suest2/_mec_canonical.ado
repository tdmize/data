*! _mec_canonical v1.7.0 Trenton Mize 2026-08-27  | history: CHANGELOG-suest2.md (repo)

capture program drop _mec_canonical
program define _mec_canonical, rclass
	*v0.2.72: resolve a stored model to a canonical name, and say whether
	*	mecompare supports it. A command name alone is not enough: one
	*	command fits several models and posts different e(cmd) values for
	*	each. Measured (diag_supmods_trancheA PART D):
	*
	*	  xtlogit, fe  -> e(cmd) clogit, e(cmd2) xtlogit, e(model) fe
	*	  xtlogit, re  -> e(cmd) xtlogit, e(cmd2) empty
	*	  xtlogit, pa  -> e(cmd) xtgee,  e(cmd2) xtlogit, e(model) pa
	*	  xtreg        -> e(cmd) xtreg for all of fe/re/be/ml
	*
	*	so the identity is the (e(cmd), e(cmd2), e(model)) triple. Callers
	*	pass what they read off the restored model; this returns r(canon),
	*	a single name used for messages and for the outcome-category logic,
	*	and r(ok), whether mecompare supports it.
	version 16.0
	syntax, CMD(string) [CMD2(string) MODel(string) ENGine(string) /*
		*/ DISTrib(string) METHod(string) ESTimator(string)]
	local cmd  = lower(trim("`cmd'"))
	local cmd2 = lower(trim("`cmd2'"))
	local mod  = lower(trim("`model'"))
	local dist = lower(trim("`distrib'"))
	local meth = lower(trim("`method'"))
	local esti = lower(trim("`estimator'"))

	*	the nine ordinary models, supported on both engines
	local ordinary "regress logit probit mlogit ologit oprobit gologit2 poisson nbreg"
	*	tranche A: suest2 only. These take suest2's FALL-THROUGH margins
	*	route, whose label stripe is byte-identical to the ordinary case
	*	(measured, PART A), so the crosswalk needs no change for them.
	*v1.7.0: melogit and meprobit LEFT this tranche. They are in B below.
	*	suest2_margins candidate 20 gave them the unconditional native
	*	constituent flag their siblings already had, because reaching it
	*	only through (`hasdydx' & `allme') meant mecompare -- which emits
	*	an at() unit shift and never the literal "dydx(" -- exited r(133),
	*	"unknown function var()", on EVERY random-slope system while nine
	*	sibling families ran (measured, probe_reslope_v1_0 27aug2026).
	*	Moving the route without moving the tranche is a HALF fix: the
	*	native route posts the by-equation stripe, r(spec)=0 told the
	*	crosswalk to build "1._predict#", and probe_reslope_v1_1 measured
	*	r(111) "[1._predict#2._at] not found" on all twelve melogit and
	*	meprobit cells -- including the intercept-only ones that had
	*	worked. The route flag and the stripe dialect are one change.
	local trancheA "mixed"
	*v0.2.74: tranche B. Same suest2-only status, but these take suest2's
	*	SPECIALIZED margins route, which labels models by equation rather
	*	than by a N._predict# prefix. r(spec) tells the crosswalk which
	*	prefix form to build. (v0.2.81: the route handles over() and
	*	groups; the old refusal and its r(nogroups) note are gone.)
	*v1.7.0: melogit and meprobit joined this tranche, see the note above.
	*	This does NOT change the quantity any of them reports.
	*	probe_mecestimand_v1_0 measured mecompare's constituent against
	*	eleven candidates at intpoints 3, 7 and 15: melogit (fall-through
	*	route) and mecloglog and mepoisson (native route) ALL equal the
	*	centered unit change under Stata's default prediction, reldif
	*	0.000e+00, nearest rival 4.6e-04. Both routes compute one thing.
	local trancheB "melogit meprobit mecloglog mepoisson menbreg"
	*v0.2.82: tranche C. Specialized route like tranche B; multi-outcome
	*	(ordinal) models, whose crosswalk branch is at the prnum block.
	local trancheC "meologit meoprobit xtologit xtoprobit"
	*v0.2.86: tranche D -- ordinary single-level families that suest2 already
	*	combined but mecompare refused. suest2-only (gsem cannot fit them as a
	*	two-equation system) and spec=0: MEASURED 03aug2026
	*	(diag_supmods_parityB1) that each takes suest2's fall-through margins
	*	route, stripe "1bn._predict 2._predict", exactly like tranche A, so the
	*	crosswalk needs no change. Outcome categories are 1 for all three: their
	*	e(k_eq) of 1/1/2 counts ANCILLARY equations (tobit's /var(e.DV)), not
	*	outcome categories, so the existing else-branch is already right.
	*	ONLY these three of the seven ordinary parity-arc families are here.
	*	intreg, streg and ivregress are held back because mecompare reads a
	*	model's predictors positionally out of e(cmdline) -- words 3..N, with
	*	word 2 taken as the DV -- and that shape fails for them (measured,
	*	diag_supmods_parityB1b): intreg has TWO DVs so the second is read as a
	*	predictor; streg is st-set so it has NO DV in the cmdline and its first
	*	predictor is eaten as one; ivregress puts the ESTIMATOR name in word 2
	*	and parenthesises its varlist. heckman parses its main equation
	*	correctly but silently drops the four select() predictors. Those four
	*	wait on sourcing the predictor list from e(b) instead.
	local trancheD "glm cloglog tobit"

	*v0.2.90: ivregress 2sls posts a VERSION-SUFFIXED e(cmd2) (ivregress_18
	*	today, something else at the next Stata release), and its liml and
	*	gmm siblings post none (measured, diag_supmods_parityB1 and
	*	diag_admit_parityB5). Normalize the suffix away so canon resolves
	*	to ivregress for all three and the estimator() gate below decides.
	if regexm("`cmd2'", "^ivregress_[0-9]+$")  local cmd2 "ivregress"

	*v0.3.4: logistic posts e(cmd) "logistic" and no e(cmd2), so canon
	*	resolved to "logistic", which is in none of the tranche lists --
	*	`ordinary' holds logit but not logistic. mecompare therefore
	*	REFUSED a logistic pair 198 with a message that LISTS logistic as
	*	supported, while mecompare.sthlp 54 and 576 claimed it. Measured
	*	by probe_claims_v1.do 15aug2026 on all three documented scopes
	*	(plain, pweighted, mi -- 198 on each, logit pair control at 0),
	*	after the claim-coverage audit found the claim had no instrument.
	*	logistic IS logit: same likelihood, same predict, same margins,
	*	differing only in displaying odds ratios. Normalizing here rather
	*	than adding it to `ordinary' means every downstream branch -- the
	*	outcome-category logic, the crosswalk, the prediction labels --
	*	treats it as the logit it is, and no new path exists to diverge.
	*	The user still sees logistic in the model echo, which is built
	*	from e(cmdline). suest2 already combined logistic pairs at rc 0,
	*	so this was mecompare's gate alone.
	if "`cmd'" == "logistic"  local cmd "logit"

	local canon "`cmd'"
	*	a command that posts under another name is identified by cmd2
	if "`cmd2'" != "" & "`cmd2'" != "`cmd'"  local canon "`cmd2'"

	local ok = 0
	local suest2only = 0
	foreach t of local ordinary {
		if "`t'" == "`canon'"  local ok = 1
		}
	local spec = 0
	foreach t of local trancheA {
		if "`t'" == "`canon'" {
			local ok = 1
			local suest2only = 1
			}
		}
	foreach t of local trancheB {
		if "`t'" == "`canon'" {
			local ok = 1
			local suest2only = 1
			local spec = 1
			}
		}
	foreach t of local trancheC {
		if "`t'" == "`canon'" {
			local ok = 1
			local suest2only = 1
			local spec = 1
			}
		}
	foreach t of local trancheD {
		if "`t'" == "`canon'" {
			local ok = 1
			local suest2only = 1
			}
		}

	*v0.2.87: tranche E. These CANNOT be matched on the canonical name alone:
	*	the name is shared with estimators nobody has validated, and admitting
	*	them silently is the failure shape this command treats as worst. The
	*	model() argument this program has always accepted, and never used, is
	*	the hook; e(distrib) is added because model() alone does not separate
	*	xtpoisson's two random-effects distributions. Measured 03aug2026
	*	(diag_supmods_parityB2c):
	*
	*	  xtreg      fe / be / re -> model fe/be/re, distrib empty
	*	             mle          -> model ml,  distrib Gaussian   VALIDATED
	*	  xtpoisson  fe           -> model fe,  distrib empty
	*	             re (gamma)   -> model re,  distrib Gamma
	*	             re normal    -> model re,  distrib Gaussian   VALIDATED
	*	  meglm      gaussian-identity -> model linear             VALIDATED
	*	             gamma-log         -> model gamma              VALIDATED
	*
	*	meglm is gated on the two links MEASURED rather than admitted
	*	wholesale as glm was: a generic meglm can carry an ordinal family,
	*	which is multi-outcome and would need the k_cat branch. Widen only
	*	after measuring the link in question.
	*
	*	Routes measured on the same run: xtreg mle takes the ORDINARY stripe
	*	(1bn._predict 2._predict) so spec stays 0; xtpoisson and meglm take
	*	the equation-prefixed stripe, so spec=1.
	if "`canon'" == "xtreg" & "`mod'" == "ml" {
		local ok = 1
		local suest2only = 1
		}
	if "`canon'" == "xtpoisson" & "`mod'" == "re" & "`dist'" == "gaussian" {
		local ok = 1
		local suest2only = 1
		local spec = 1
		}
	if "`canon'" == "meglm" & ("`mod'" == "linear" | "`mod'" == "gamma") {
		local ok = 1
		local suest2only = 1
		local spec = 1
		}

	*v0.2.90: tranche F -- four of the five families the e(b)-sourced
	*	predictor lists (v0.2.88/89) unblocked; mestreg, the fifth, waits
	*	on tranche G because its specialized-route values need their own
	*	truth design. All four take suest2's ORDINARY stripe (measured,
	*	diag_supmods_parityB1), so spec stays 0. Discriminators measured
	*	in diag_admit_parityB5 (04aug2026):
	*
	*	  heckman    ml       -> method ml                    VALIDATED
	*	             twostep  -> method two-step: no ML joint VCE to combine
	*	  ivregress  2sls     -> estimator 2sls               VALIDATED
	*	             liml/gmm -> estimator liml/gmm, unvalidated
	*	  streg      ALL parametric distributions: e(cmd) varies by
	*	             distribution (weibull/ereg/lnormal...) but e(cmd2)
	*	             is constant at streg, so canon lands here VALIDATED
	*	  intreg     no siblings                              VALIDATED
	if "`canon'" == "intreg" {
		local ok = 1
		local suest2only = 1
		}
	if "`canon'" == "streg" {
		local ok = 1
		local suest2only = 1
		}
	if "`canon'" == "heckman" & "`meth'" == "ml" {
		local ok = 1
		local suest2only = 1
		}
	*v0.2.97: spec=1. suest2's ivregress bridge posts the equation-named
	*	stripe, measured identical with and without mi (diag_iv_P1):
	*	    coleq __ma __ma __mb __mb / colnames 1bn._at 2._at ...
	*	spec=0 addressed _b[1._predict#2._at], which is not a column in
	*	that stripe, so every ivregress ME died rc 111 on BOTH routes.
	*	Same one-line correction tranche G made for mestreg, and for the
	*	same reason: the specialized suest2 route is what decides this,
	*	not the family's own margins behaviour.
	if "`canon'" == "ivregress" & "`esti'" == "2sls" {
		local ok = 1
		local suest2only = 1
		local spec = 1
		}

	*v0.2.91: tranche G -- mestreg, the fifth e(b)-unblocked family. All
	*	parametric distributions ride the constant e(cmd2)==mestreg (B5).
	*	Specialized route: B2 measured the equation-prefixed stripe, and
	*	diag_mestreg_G1 measured the combination itself (store-name
	*	equation prefixes, model-major at() layout, the candidate-18
	*	filter serving differing predictors). Values verified against the
	*	hand-driven suest2 + margins pipeline in probe MEC0291 -- native
	*	margins is NOT a valid truth here (marginal vs conditional
	*	defaults).
	if "`canon'" == "mestreg" {
		local ok = 1
		local suest2only = 1
		local spec = 1
		}

	*v0.2.92: tranche H -- xtlogit re and xtprobit re. B2c refused them on a
	*	400-sparse-panel fixture and suspected the fixture; diag_xtre_H1
	*	(04aug2026, 300 balanced panels, 30 points) confirms: suest2's
	*	bridge guard passes both. Discriminators, same species as tranche
	*	E (fe and pa share the canon via cmd2):
	*
	*	  xtlogit    re -> cmd xtlogit, model re, distrib Gaussian VALIDATED
	*	             fe -> cmd clogit, cmd2 xtlogit, model fe
	*	             pa -> cmd xtgee,  cmd2 xtlogit, model pa
	*	  xtprobit   re -> cmd xtprobit, model re, distrib Gaussian VALIDATED
	*	             pa -> cmd xtgee,  cmd2 xtprobit, model pa
	*
	*	Quadrature adequacy stays suest2's call: a fit its bridge guard
	*	rejects surfaces suest2's own error, as suest2-direct always did.
	if "`canon'" == "xtlogit" & "`mod'" == "re" & "`dist'" == "gaussian" {
		local ok = 1
		local suest2only = 1
		local spec = 1
		}
	if "`canon'" == "xtprobit" & "`mod'" == "re" & "`dist'" == "gaussian" {
		local ok = 1
		local suest2only = 1
		local spec = 1
		}

	*v1.1.0: tranche H gains xtcloglog re. Measured 18aug2026
	*	(probe_meineq_xtcloglog_v1_1 PART B): fitted with intpoints(24) the
	*	pair combines at rc 0 and margins posts 6 columns for a binary
	*	outcome. It was left out because suest2's bridge guard rejects it
	*	at the DEFAULT 12 points -- minquad is 24 for this family alone --
	*	which is a quadrature question and not a support question. Same
	*	division as the rest of tranche H: adequacy stays suest2's call,
	*	and suest2 0.1.78 names the remedy in its message.
	*
	*	  xtcloglog  re -> cmd xtcloglog, model re, distrib Gaussian
	*	             pa -> cmd xtgee, cmd2 xtcloglog, model pa
	if "`canon'" == "xtcloglog" & "`mod'" == "re" & "`dist'" == "gaussian" {
		local ok = 1
		local suest2only = 1
		local spec = 1
		}

	*v0.2.94: tranche I -- xtmlogit, fe and re. Discriminators measured
	*	(diag_xtmlogit_X1 PART D, diag_xtmlogit_X2 section 3):
	*
	*	  xtmlogit  re -> cmd gsem,     cmd2 xtmlogit, model re  VALIDATED
	*	            fe -> cmd xtmlogit, cmd2 EMPTY,    model fe  VALIDATED
	*
	*	Both resolve to canon xtmlogit -- re through cmd2, fe through cmd
	*	with cmd2 empty -- and xtmlogit has no pa sibling to gate out, so
	*	unlike tranches E and H the model() test admits rather than
	*	restricts. It is still written out rather than left implicit: a
	*	third estimator appearing in a later Stata would otherwise be
	*	admitted silently, which is the failure shape this command treats
	*	as worst.
	*
	*	SPECIALIZED ROUTE, multi-outcome, so spec=1 and the crosswalk's
	*	prnum branch applies UNCHANGED. Measured (diag_xtmlogit_X3d): under
	*	the call this command actually builds -- at() with NO predict(),
	*	see :2294 -- xtmlogit, xtologit and meologit return a byte-identical
	*	stripe, <store>:<k>._predict#<L>._at, twelve columns for two
	*	three-outcome models. Each model's predicts are numbered 1..k within
	*	its OWN equation (model 2 is 1bn._predict again, NOT k+1..2k), which
	*	is the v0.2.82 finding holding for this family too.
	*
	*	And the numbering MEANS what the crosswalk assumes: column
	*	<store>:<k>._predict#<L>._at equals the pinned outcome(k) value at
	*	that at(), 18 of 18 combinations at exactly 0.00e+00 across re, fe
	*	and the xtologit reference. Had it not, the table would have been
	*	labelled with the wrong outcome and never said so.
	*
	*	Outcome COUNT comes from e(k_out), not e(k_eq): re posts k_eq==4
	*	against three outcomes because of the / variance block
	*	(var(u2) var(u3)). fe happens to post k_eq==3, but only because a
	*	conditional likelihood carries no ancillary block -- a coincidence,
	*	not a rule, and not relied on. See the mod`i'cats branches above.
	*
	*	The predictor list needs nothing: _mec_ebvars already skips columns
	*	whose equation begins "/" AND columns whose name contains "(", and
	*	var(u2)/var(u3) trip both.
	if "`canon'" == "xtmlogit" & ("`mod'" == "fe" | "`mod'" == "re") {
		local ok = 1
		local suest2only = 1
		local spec = 1
		}

	*v1.2.0: tranche J -- xtreg fe, be and re, the aggregate estimators.
	*	Measured 19aug2026 (probe_xt_parity_v1_0 PARTS A-C): all three post
	*	e(cmd) xtreg with e(model) fe/be/re and EMPTY e(distrib) -- the quad
	*	tranche E measured 03aug2026 -- and the combined system takes the
	*	ORDINARY stripe under both of mecompare's default call shapes
	*	(eqs "_", 1bn._predict#1bn._at .. 2._predict#2._at, k=4),
	*	byte-identical to the admitted xtreg mle reference. spec stays 0.
	*	mle keeps its tranche E entry; cre stays out. Measured-impossible in
	*	EVERY call shape: the default two-selector call (gate 24 PART 5) AND
	*	the explicit predict(model() xb) two-selector form, factor and
	*	continuous alike (probe_xt_holdouts_v1_0 PART C) -- CRE margins
	*	accepts exactly one selector per call, and one call per model cannot
	*	carry the cross-model covariance the Difference needs.
	if "`canon'" == "xtreg" & ("`mod'" == "fe" | "`mod'" == "be" | "`mod'" == "re") {
		local ok = 1
		local suest2only = 1
		}
	*v1.2.0: tranche K -- the population-averaged (xtgee) estimators of all
	*	six xt families, plus xtlogit fe, xtpoisson fe and xtnbreg re.
	*	Measured 19aug2026 (probe_xt_parity_v1_0): every quad is distinct
	*	(pa -> cmd xtgee, cmd2 the family; xtlogit fe -> cmd clogit;
	*	xtpoisson fe -> cmd xtpoisson; xtnbreg re -> distrib Beta), every
	*	pair combines at rc 0, and every combined system posts the
	*	SINGLE-OUTCOME SPECIALIZED stripe -- equation = store name,
	*	1bn._at/2._at, no _predict dimension -- the tranche H layout, so
	*	spec = 1.
	*	NOT here, with the reason now fully measured: xtnbreg fe. Stata's
	*	conditional-FE negbin exposes NO -predict, scores- in either form
	*	(both rc 198, probe_xt_holdouts_v1_0 PART N), so no sandwich exists;
	*	suest2's rc 498 is its own DESIGNED guard ('conditional-negative-
	*	binomial parameter scores are not centered'), and suest2.sthlp
	*	un-claimed the estimator 19aug2026.
	if "`mod'" == "pa" & ("`canon'" == "xtreg" | "`canon'" == "xtlogit" ///
		| "`canon'" == "xtprobit" | "`canon'" == "xtcloglog" ///
		| "`canon'" == "xtpoisson" | "`canon'" == "xtnbreg") {
		local ok = 1
		local suest2only = 1
		local spec = 1
		}
	if "`canon'" == "xtlogit" & "`mod'" == "fe" {
		local ok = 1
		local suest2only = 1
		local spec = 1
		}
	if "`canon'" == "xtpoisson" & "`mod'" == "fe" {
		local ok = 1
		local suest2only = 1
		local spec = 1
		}
	if "`canon'" == "xtnbreg" & "`mod'" == "re" & "`dist'" == "beta" {
		local ok = 1
		local suest2only = 1
		local spec = 1
		}
	*v1.3.0: xtpoisson re with the GAMMA distribution -- the cell rev 25
	*	left unmeasured after its nlswork-sized fit was broken off. Measured
	*	19aug2026 (probe_xt_holdouts_v1_0 PART P, 300x6 synthetic panel):
	*	quad xtpoisson / - / re / Gamma, combines rc 0, and both default
	*	call shapes post the specialized stripe. The tranche E gaussian
	*	entry stands; this admits the other distribution.
	if "`canon'" == "xtpoisson" & "`mod'" == "re" & "`dist'" == "gamma" {
		local ok = 1
		local suest2only = 1
		local spec = 1
		}
	*v1.4.0: fracreg, both estimators. suest2 0.1.80 implements the
	*	active-system mu (glm link branch; links captured from e(cmdline)
	*	word 2). Ordinary stripe expected; gate 30 measures and
	*	value-verifies both variants.
	if "`canon'" == "fracreg" {
		local ok = 1
		local suest2only = 1
		}
	*v1.5.0: six more from the parked ten. suest2 0.1.81 implements each
	*	family NATIVE DEFAULT statistic in the active-system predictor,
	*	and every closed form was value-verified against native predict
	*	before any of this was written (probe_fam_forms v1_0 and v1_1):
	*	  betareg   cmean, all four links   0 / 0 / 0 / 8.6e-17
	*	  truncreg  xb (its own default)    exact
	*	  hetprobit pr                      0
	*	  zip zinb  n, both inflation links 0 / 0 / 2.3e-16
	*	  biprobit  p11                     7.3e-17
	*	All six are single-quantity: the category-count branch reads a
	*	command-name whitelist none of them is on, so each resolves to
	*	cats 1, which is correct even where e(k_eq) is 3 (zinb,
	*	biprobit) or e(k_eq_model) is 2 (betareg, biprobit). Ordinary
	*	stripe, so spec stays 0. Measured probe_mec_admit_v1_0.
	if inlist("`canon'","betareg","truncreg","hetprobit","zip","zinb","biprobit") {
		local ok = 1
		local suest2only = 1
		}
	*v1.6.0: the iv pair. suest2 0.1.82 returns the structural linear index,
	*	which is each one NATIVE default (predict with no options labels
	*	them "Fitted values" and "Linear prediction"), value-verified at
	*	max reldif 0 against native predict. Admission waited on
	*	mec_share v1.3.0, not on the prediction: the e(b) predictor union
	*	spans their reduced-form equation, so before that fix the list
	*	came back as xe x z and the instrument would have taken a row.
	if inlist("`canon'","ivprobit","ivtobit") {
		local ok = 1
		local suest2only = 1
		}
	return local canon      "`canon'"
	return local model      "`mod'"
	return local distrib    "`dist'"
	return scalar ok        = `ok'
	return scalar suest2only = `suest2only'
	return scalar spec      = `spec'
end
