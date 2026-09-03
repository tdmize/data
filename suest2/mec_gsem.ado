*! mec_gsem v0.2.1 Trenton Mize 2026-08-17  | history: CHANGELOG-suest2.md (repo)

program define mec_gsem, eclass
	version 16

	syntax anything(name=models) [if] [in] [fw pw iw aw/], ///
		[ GROUPS SAMPvar(name) COMMANDS QUIetly ]

	gettoken mod1 mod2 : models
	local mod2 = trim("`mod2'")
	if trim("`mod1'") == "" | "`mod2'" == "" {
		di as err "{cmd:mec_gsem} requires exactly two stored model names"
		exit 198
		}

*Read what the gsem call needs off the stored models. Everything except the
*	IV lists comes straight from e(), so nothing is reconstructed by hand.
	local i 0
	foreach nm in `mod1' `mod2' {
		local ++i
		capture quietly estimates restore `nm'
		if _rc {
			di as err "unable to restore model {bf:`nm'}"
			exit 111
			}
		local dv`i'    "`e(depvar)'"
		local cmd`i'   "`e(cmd)'"
		local issvy`i' = ("`e(prefix)'" == "svy")
		local ismi`i'  = 0
		if "`e(cmd)'" == "mi estimate"        local ismi`i' = 1
		if "`e(prefix_mi)'" == "mi estimate"  local ismi`i' = 1
		if "`e(mi)'" == "mi"                  local ismi`i' = 1
		capture confirm scalar e(M_mi)
		if !_rc                               local ismi`i' = 1
*	under mi the underlying command is in e(cmd_mi) for the saving()/plain
*	forms and in e(cmd) for post:; take whichever is populated
		if `ismi`i'' == 1 {
			if "`e(cmd_mi)'" != "" & "`e(cmd_mi)'" != "mi estimate" ///
				local cmd`i' "`e(cmd_mi)'"
			}

*v0.2.1: resolve the family name before it becomes a gsem family option.
*	e(cmd) is the command the user typed, which is not always a family gsem
*	knows: a model fitted with -logistic- reports e(cmd) as "logistic" and
*	gsem has no logistic family, so the pair exited 198 -- although logistic
*	is logit with odds-ratio reporting and is fully supported. Measured by
*	test_mecgsem_selfcontained_v1_0.do 16aug2026, on both v0.1.0 and v0.2.0,
*	so it dates from v0.1.0.
*	mecompare never hit it because it keeps the canonical name in its own
*	cmd`i' (its v0.2.72 note); this program has always read e(cmd) itself.
*	The same call as mecompare.ado:756. r() is copied out at once (rule 9).
*	No support gate is added here: the caller already owns that decision
*	(mecompare 743 and 748) and a second one would be a second mechanism.
		local graw "`e(cmd)'"
		if "`cmd`i''" != "" & "`cmd`i''" != "mi estimate"  local graw "`cmd`i''"
		_mec_canonical, cmd("`graw'") cmd2("`e(cmd2)'") model("`e(model)'") /*
			*/ distrib("`e(distrib)'") method("`e(method)'") /*
			*/ estimator("`e(estimator)'")
		local gcanon "`r(canon)'"
		if "`gcanon'" != ""  local cmd`i' "`gcanon'"

*v0.2.0: this model's predictor list, read HERE rather than passed in.
*	The strip steps and the words-3..N read are MOVED from mecompare.ado
*	(669-671 pipe, 709-710 and 725-726 prefix colon, 785-818 comma,
*	weight, if/in, words) -- same operations in the same order, so
*	engine(gsem) sees the list it always saw.
*
*	WHY NOT e(b). -mec_share ebvars- returns unique VARIABLE names: it
*	splits column names on # , so i.race##c.age comes back as
*	"ib1.race age" and gsem fits rank 4 where the model had rank 6 --
*	silently, with ll differing in the fourth decimal. Measured,
*	probe_ebvars_gsem_v1_0.do 16aug2026. That list is correct for
*	margins and wrong for a respecification.
*
*	The parse cannot read two-DV, st-set, option-borne or
*	estimator-worded command lines (the v0.2.88 note in mecompare).
*	Every such family is suest2only and is refused under engine(gsem)
*	before this program runs, so the gap is unreachable from here.
		local cl`i' "`e(cmdline)'"
*	a multilevel || group: part would be read as predictors. Before the
*	colon strip, because it carries a colon of its own.
		local gpipe = strpos("`cl`i''", "||")
		if `gpipe' != 0  local cl`i' = substr("`cl`i''", 1, `gpipe' - 1)
*	a svy: or mi estimate: prefix shifts every word position by one.
*	CONDITIONAL, as in mecompare: an unconditional strip would truncate
*	a plain model whose if-condition happens to contain a colon.
		if `issvy`i'' == 1 | `ismi`i'' == 1 {
			local gcolon = strpos("`cl`i''", ":")
			if `gcolon' > 0 ///
				local cl`i' = trim(substr("`cl`i''", `gcolon' + 1, .))
			}
*	options after the comma
		local gcomma = strpos("`cl`i''", ",")
		if `gcomma' > 0  local cl`i' = substr("`cl`i''", 1, `gcomma' - 1)
*	a [weight] precedes the comma and so survives the strip above
		local cl`i' = regexr("`cl`i''", "\[[^]]*\]", "")
*	if/in and their variables are not predictors. The refit necessarily
*	loses the restriction; mecompare warns about that at its ~986.
		local gif = strpos("`cl`i''", " if ")
		local gin = strpos("`cl`i''", " in ")
		if `gif' > 0       local cl`i' = substr("`cl`i''", 1, `gif' - 1)
		else if `gin' > 0  local cl`i' = substr("`cl`i''", 1, `gin' - 1)
*	words 3..N: word 1 is the command, word 2 the dependent variable
		local gnw : word count `cl`i''
		local ivs`i' " "
		forvalues b = 3/`gnw' {
			local gv : word `b' of `cl`i''
			local ivs`i' "`ivs`i'' `gv'"
			}
		if trim("`ivs`i''") == "" {
			di as err "{cmd:mec_gsem} read no predictors from the stored "  /*
			*/ "model {bf:`nm'}. Its command line was: `e(cmdline)'"
			exit 198
			}
		}

	local issvy = (`issvy1' == 1 | `issvy2' == 1)
	local ismi  = (`ismi1'  == 1 | `ismi2'  == 1)

*The prefix, exactly as mecompare built it. mi is the OUTER prefix when both
*	are present, as the manual specifies.
	local gsemprefix ""
	if `ismi' == 1 & `issvy' == 1  local gsemprefix "mi estimate, cmdok: svy: "
	else if `ismi' == 1           local gsemprefix "mi estimate, cmdok: "
	else if `issvy' == 1          local gsemprefix "svy: "

*svy carries its own variance and weights; anything else uses the robust
*	sandwich, which is what makes the joint fit comparable to suest.
	local vcespec "vce(robust)"
	local weightspec ""
	if `issvy' == 1 {
		local vcespec ""
		}
	else if "`weight'" != "" {
		local weightspec "[`weight' = `exp']"
		}

*listwise only when the two models share a sample; with groups they are
*	disjoint by construction and listwise would empty the fit.
	local listwise "listwise"
	if "`groups'" != ""  local listwise ""

*DV cloning. This is the whole reason the gsem path needs the data at all:
*	gsem cannot fit two equations on disjoint samples, and it needs distinct
*	DV names when both models share one. suest2 needs neither, which is why
*	this moved out of mecompare rather than being shared.
	local mecdv1 ""
	local mecdv2 ""
	local dv1clone = "_mec1_" + substr("`dv1'",1,26)
	local dv2clone = "_mec2_" + substr("`dv2'",1,26)
	if "`groups'" == "" {
		if "`dv1'" == "`dv2'" {
			capture drop `dv2clone'
			quietly clonevar `dv2clone' = `dv2'
			local dv2 `dv2clone'
			local mecdv2 "`dv2clone'"
			}
		}
	else {
		if "`sampvar'" == "" {
			di as err "{cmd:mec_gsem} needs {opt sampvar()} with {opt groups}:"
			di as err "the variable marking which model each observation belongs to"
			exit 198
			}
		capture confirm variable `sampvar'
		if _rc {
			di as err "{opt sampvar(`sampvar')} does not exist"
			exit 111
			}
		capture drop `dv1clone'
		quietly clonevar `dv1clone' = `dv1'
		quietly replace `dv1clone' = . if `sampvar' != 1
		capture drop `dv2clone'
		quietly clonevar `dv2clone' = `dv2'
		quietly replace `dv2clone' = . if `sampvar' != 2
		local dv1 `dv1clone'
		local dv2 `dv2clone'
		local mecdv1 "`dv1clone'"
		local mecdv2 "`dv2clone'"
		}

	local cmdqui "quietly"
	if "`quietly'" == ""  local cmdqui ""

	if "`commands'" != "" {
		di _newline(1)
		di as text "gsem model is: "
		di as result "    `gsemprefix'gsem (`dv1' <- `ivs1', `cmd1') " /*
		*/ "(`dv2' <- `ivs2', `cmd2') `weightspec', nocapslatent " /*
		*/ "`vcespec' `listwise'"
		}

	`cmdqui' `gsemprefix'gsem (`dv1' <- `ivs1', `cmd1') ///
		(`dv2' <- `ivs2', `cmd2') ///
		`weightspec' ///
		, nocapslatent `vcespec' `listwise'

*Report the clone names back through c_local rather than ereturn. mecompare
*	returns them in e(mec_dv1)/e(mec_dv2) from its own locals, and touching
*	e() here would mean modifying a freshly posted estimation result for no
*	reason -- the gsem results are what mecompare stores as mec_gsem.
	c_local mec_gsem_dv1 "`mecdv1'"
	c_local mec_gsem_dv2 "`mecdv2'"
end
