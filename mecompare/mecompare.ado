*******************
// mecompare.ado //
*******************

capture program drop mecompare
*! mecompare v1.4.0 Trenton Mize 2026-09-02  | history: CHANGELOG-mecompare.md (repo)

program define mecompare, eclass 
	version 16.0

*Replay allows a plain mecompare call to reshow table of results
	if replay() {
		capture syntax [, coeflegend]
		if _rc == 0 {
		if "`e(cmd)'" == "mecompare" {
			if "`coeflegend'" != "" {
				ereturn display, coeflegend
				}
			else {
				matlist e(table), title(`"`e(dtitle)'"') 	///
					cspec(`"`e(dcspec)'"') rspec(`"`e(drspec)'"') 	///
					nodotz underscore
				}
			exit
			}

*If no mecompare results active, a bare varlist calculates MEs for all IVs
		capture confirm matrix e(b)
		if _rc {
			di as err "{cmd:mecompare} found no estimation results to " /*
			*/ "replay and none to use. Fit a model, or name stored " /*
			*/ "estimates in {opt models( )}."
			exit 301
			}

*coeflegend shows the names of estimates
		if "`coeflegend'" != "" {
			di as err "{opt coeflegend} shows the coefficient names of a " /*
			*/ "previous {cmd:mecompare} table, and there is none in " /*
			*/ "memory. Run {cmd:mecompare} first, then replay it with " /*
			*/ "{cmd:mecompare, coeflegend}."
			exit 301
			}
			}
		}

*clean up stores from previous suest2 and/or mecompare calls if necessary
	capture suest2_cleanup, force

*Stata matches option names case sensitively: normalise these before syntax sees them
	foreach mecopt in groupsd groupme {
		local 0 = ustrregexra(`"`0'"', "\b`mecopt'\b", "`mecopt'", 1)
		}

*meinequality and totalme may be given bare to mean the default (weighted)
	local meccom = strpos(`"`0'"', ",")
	if `meccom' > 0 {
		local mecvl = substr(`"`0'"', 1, `meccom')
		local mecop = substr(`"`0'"', `meccom' + 1, .)
		local mecop = ustrregexra(`"`mecop'"', "\bmeineq[a-z]*[ ]*\([ ]*\)", " meinequality(weighted) ", 1)
		local mecop = ustrregexra(`"`mecop'"', "\btotal[a-z]*[ ]*\([ ]*\)", " totalme(weighted) ", 1)
		local mecop = ustrregexra(`"`mecop'"', "\bmeineq[a-z]*[ ]*\(", "MECqA(", 1)
		local mecop = ustrregexra(`"`mecop'"', "\btotal[a-z]*[ ]*\(", "MECqB(", 1)
		local mecop = ustrregexra(`"`mecop'"', "\bmeineq[a-z]*\b", " meinequality(weighted) ", 1)
		local mecop = ustrregexra(`"`mecop'"', "\btotalme[a-z]*\b", " totalme(weighted) ", 1)
		local mecop = subinstr(`"`mecop'"', "MECqA(", "meinequality(", .)
		local mecop = subinstr(`"`mecop'"', "MECqB(", "totalme(", .)
		local 0 `"`mecvl'`mecop'"'
		}

	syntax [varlist(default=none fv)] [if] [in] [fweight pweight iweight] ///
		/// models() optional, so the comma sits INSIDE the bracket.
		[, MODels(string) ///
		STATistics(string) amount(string) CENTERed UNCENTered COMMANDs DETAILs ///
		GROUPs GROUPNames(string) GROUPMe GROUPSD start(string) COVariates(string) ///
		DECimals(string) MOD1name(string) MOD2name(string) NOROWnum ///
		STORE(name) BY(string) OVER(string) PWCompare MEINEQuality(string) ///
		PREDict(string) ENGine(string) ///
		TOTALme(string) MARGINSopt(string asis) ATMeans ///
		LABWidth(numlist integer) STATWidth(numlist integer)]  

*Error out if if/in qualifiers specify no obs; store N
marksample touse
tempvar mectouse
marksample mectouse, novarlist
qui count if `touse'
	if `r(N)' == 0 {
		error 2000
		}
	
*The suest2 package is a PREREQUISITE and must be installed
local mecmissing ""
foreach mecreq in suest2 _mec_canonical mec_share mec_wcheck mec_gsem {
	capture which `mecreq'
	if _rc  local mecmissing "`mecmissing' `mecreq'"
	}
if "`mecmissing'" != "" {
	di _newline(1)
	di as err "{cmd:mecompare} requires the {cmd:suest2} package, which is "  /*
	*/ "missing or incomplete. Not found:`mecmissing'. Install or update "  /*
	*/ "{cmd:suest2} and try again."
	exit 199
	}

*Check that SPost13 is installed
capture which mlincom
    if (_rc) {
    di _newline(1)
	di as err "{cmd:mecompare} requires the user-written package " /*
	*/ "{cmd:SPost13}. Click on the link below to search for " /*
	*/ "and install {cmd:SPost13}: {stata search spost13:  {bf:spost13}}"
	exit
	}

*Sub-option by any unambiguous prefix: w/u/a are already unique.
local meineqtype ""
if "`meinequality'" != "" {
	local meineqtype = lower(strtrim("`meinequality'"))
	local mecn = length("`meineqtype'")
	if "`meineqtype'" == "" | substr("weighted",1,`mecn') == "`meineqtype'"  local meineqtype "weighted"
	else if substr("unweighted",1,`mecn') == "`meineqtype'"  local meineqtype "unweighted"
	else if substr("all",1,`mecn') == "`meineqtype'" | "`meineqtype'" == "both"  local meineqtype "all"
	else {
		di _newline(1)
		di as err "{opt meinequality()} must be {opt weighted}, {opt unweighted}, or {opt all}."
		exit 198
		}
	}

*weighted/unweighted affect NOMINAL focal variables only
local totmetype ""
if "`totalme'" != "" {
	local totmetype = lower(strtrim("`totalme'"))
	local mecn = length("`totmetype'")
	if "`totmetype'" == "" | substr("weighted",1,`mecn') == "`totmetype'"  local totmetype "weighted"
	else if substr("unweighted",1,`mecn') == "`totmetype'"  local totmetype "unweighted"
	else if substr("all",1,`mecn') == "`totmetype'" | "`totmetype'" == "both"  local totmetype "all"
	else {
		di _newline(1)
		di as err "{opt totalme()} must be {opt weighted}, {opt unweighted}, or {opt all}."
		exit 198
		}
	}

*A bare atmeans is covariates(atmeans); folded in here so every later read sees one form
if "`atmeans'" != "" {
	local mecatmin : list posof "atmeans" in covariates
	if `mecatmin' == 0  local covariates = trim("`covariates' atmeans")
	}

*covariates( ) and start( ) hold one value per variable
local mecsupp "regress, logit, logistic, probit, mlogit, ologit, oprobit, "
local mecsupp "`mecsupp'gologit2, poisson, nbreg, glm, cloglog, tobit, "
local mecsupp "`mecsupp'intreg, streg, heckman (ml), ivregress (2sls); "
local mecsupp "`mecsupp'mixed, melogit, meprobit, mecloglog, mepoisson, "
local mecsupp "`mecsupp'menbreg, meologit, meoprobit, mestreg, meglm "
local mecsupp "`mecsupp'(gaussian-identity and gamma-log); fracreg "
local mecsupp "`mecsupp'(logit and probit); xtologit, "
local mecsupp "`mecsupp'xtoprobit, xtlogit (re, fe, pa), xtprobit (re, pa), "
local mecsupp "`mecsupp'xtreg (mle, fe, be, re, pa), "
local mecsupp "`mecsupp'xtpoisson (re, fe, pa), xtcloglog (re, pa), "
local mecsupp "`mecsupp'xtnbreg (re, pa) and xtmlogit (fe and re)"

*covariates() and start(): varname=# or varname=(numlist); one list per option is lifted out
local vlcovariatesvar ""
local vlcovariatesvals ""
local vlcovariatesn = 0
local vlstartvar ""
local vlstartvals ""
local vlstartn = 0
foreach optn in covariates start {
	local optstr "``optn''"
	if "`optstr'" != "" {
		local keepatm : list posof "atmeans" in optstr
		local vchk = subinword("`optstr'", "atmeans", "", .)
		local vchk = subinstr("`vchk'", char(9), " ", .)
		local vchk = itrim(trim("`vchk'"))
		local vchk = subinstr("`vchk'", " =", "=", .)
		local vchk = subinstr("`vchk'", "= ", "=", .)
		local vchk = subinstr("`vchk'", "( ", "(", .)
		local vchk = subinstr("`vchk'", " )", ")", .)
		local rebuilt ""
		local seenv ""
		local verr = 0
		local vbad ""
		while "`vchk'" != "" & `verr' == 0 {
			gettoken tok vchk : vchk, bind
			local vchk = trim("`vchk'")
			if regexm("`tok'", "^([a-zA-Z_][a-zA-Z0-9_]*)=\((.*)\)$") {
				local lvar = regexs(1)
				local lvals = regexs(2)
				capture numlist "`lvals'"
				if _rc {
					local verr = 1
					local vbad "`lvar'"
					}
				else {
					local lvals "`r(numlist)'"
					local nlv : word count `lvals'
					local ulv : list uniq lvals
					local nulv : word count `ulv'
					if `nulv' != `nlv' {
						local verr = 2
						local vbad "`lvar'"
						}
					else if `nlv' == 1  local rebuilt "`rebuilt' `lvar'=`lvals'"
					else if "`vl`optn'var'" != "" {
						local verr = 3
						local vbad "`lvar'"
						}
					else {
						local vl`optn'var "`lvar'"
						local vl`optn'vals "`lvals'"
						local vl`optn'n = `nlv'
						}
					}
				}
			else if regexm("`tok'", "^([a-zA-Z_][a-zA-Z0-9_]*)=(.+)$") {
				local lvar = regexs(1)
				local lval = regexs(2)
				local rebuilt "`rebuilt' `lvar'=`lval'"
				}
			else {
				local verr = 1
				local vbad "`tok'"
				}
			if `verr' == 0 {
				local dupv : list posof "`lvar'" in seenv
				if `dupv' > 0 {
					local verr = 4
					local vbad "`lvar'"
					}
				local seenv "`seenv' `lvar'"
				}
			}
		if `verr' == 1 {
			di as err "Invalid specification in {opt `optn'( )} at {bf:`vbad'}: each " /*
			*/ "entry must be {it:varname}=# or {it:varname}=({it:numlist}). See " /*
			*/ "{help mecompare##`optn'}."
			exit 198
			}
		if `verr' == 2 {
			di as err "The value list for {bf:`vbad'} in {opt `optn'( )} repeats a value."
			exit 198
			}
		if `verr' == 3 {
			di as err "Only one variable in {opt `optn'( )} may carry a value list; " /*
			*/ "both {bf:`vl`optn'var'} and {bf:`vbad'} do."
			exit 198
			}
		if `verr' == 4 {
			di as err "{bf:`vbad'} is listed twice in {opt `optn'( )}."
			exit 198
			}
		local `optn' = trim("`rebuilt'")
		if `keepatm' > 0  local `optn' = trim("``optn'' atmeans")
		}
	}
local covlistvar  "`vlcovariatesvar'"
local covlistvals "`vlcovariatesvals'"
local ncovlist = `vlcovariatesn'
local stlistvar  "`vlstartvar'"
local stlistvals "`vlstartvals'"
local nstlist = `vlstartn'
local stlistseen = 0

*marginsopt(): expression() comes out whole (gettoken bind keeps parentheses together); the rest is tested at the top level
local mecexpr ""
local mecmorest ""
if `"`marginsopt'"' != "" {
	local mecmowork `"`marginsopt'"'
	local mecmoguard = 0
	while `"`mecmowork'"' != "" & `mecmoguard' < 200 {
		gettoken mectok mecmowork : mecmowork, bind
		local ++mecmoguard
		if regexm(`"`mectok'"', "^exp[a-z]*\((.*)\)$")  local mecexpr = regexs(1)
		else  local mecmorest `"`mecmorest' `mectok'"'
		}
	local mecmorest = trim(`"`mecmorest'"')
*Parenthesised arguments are blanked innermost first, so a token inside subpop() or vce() is not read as an option
	local mecmotest = " " + `"`mecmorest'"' + " "
	local mecmoguard = 0
	while regexm(`"`mecmotest'"', "\([^()]*\)") & `mecmoguard' < 50 {
		local mecmotest = regexr(`"`mecmotest'"', "\([^()]*\)", "<>")
		local ++mecmoguard
		}
	foreach mectok in at over predict dydx dyex eydx eyex mcompare within {
		if regexm(`"`mecmotest'"', "[ ,]`mectok'<>") {
			di _newline(1)
			if "`mectok'" == "at" {
				di as err "{opt marginsopt()} may not carry {opt at()}: {cmd:mecompare} " /*
				*/ "builds every at() set from the varlist, {opt start()}, " /*
				*/ "{opt covariates()} and {opt by()}; a further at() would shift " /*
				*/ "the sets the table reads."
				}
			else if "`mectok'" == "over" {
				di as err "{opt marginsopt()} may not carry {opt over()}: use the " /*
				*/ "{opt over()} option of {cmd:mecompare}."
				}
			else if "`mectok'" == "predict" {
				di as err "{opt marginsopt()} may not carry {opt predict()}: use the " /*
				*/ "{opt predict()} option of {cmd:mecompare}, which builds one " /*
				*/ "selector per model. Inside {opt expression()} predict() is allowed."
				}
			else if inlist("`mectok'", "dydx", "dyex", "eydx", "eyex") {
				di as err "{opt marginsopt()} may not carry {opt `mectok'()}: " /*
				*/ "{cmd:mecompare} computes discrete changes from at() sets, " /*
				*/ "not derivatives."
				}
			else {
				di as err "{opt marginsopt()} may not carry {opt `mectok'()}: it " /*
				*/ "changes what margins posts and the table could not be read. " /*
				*/ "For pairwise contrasts of a nominal focal variable use the " /*
				*/ "{opt pwcompare} option of {cmd:mecompare}."
				}
			exit 198
			}
		}
	foreach mectok in post contrast pwcompare nose atmeans {
		if regexm(`"`mecmotest'"', "[ ,]`mectok'[ ,<]") {
			di _newline(1)
			if "`mectok'" == "post" {
				di as err "{opt marginsopt()} may not carry {opt post}: {cmd:mecompare} " /*
				*/ "posts the margins results itself."
				}
			else if "`mectok'" == "nose" {
				di as err "{opt marginsopt()} may not carry {opt nose}: every standard " /*
				*/ "error, p-value and {cmd:metest} needs e(V)."
				}
			else if "`mectok'" == "atmeans" {
				di as err "{opt marginsopt()} may not carry {opt atmeans}: give " /*
				*/ "{opt atmeans} or {opt covariates(atmeans)} to {cmd:mecompare}."
				}
			else {
				di as err "{opt marginsopt()} may not carry {opt `mectok'}: it " /*
				*/ "changes what margins posts and the table could not be read. " /*
				*/ "For pairwise contrasts of a nominal focal variable use the " /*
				*/ "{opt pwcompare} option of {cmd:mecompare}."
				}
			exit 198
			}
		}
	}

*v0.2.0: centered changes are the default. `uncentered' an option
if "`uncentered'" != "" {
	local centered ""
	}
else {
	local centered "centered"
	}

*Set the statistics displayed in final table	
if "`statistics'" == "" {
	local stats = "estimate se pvalue"
	}
else {
	local stats = "`statistics'"
	}
if "`statistics'" == "all" {	// helps with labeling table at end
	local stats = "estimate se z pvalue ll ul"
	}	

*Set display options for final table (# decimals, column widths, etc.)
if "`decimals'" == "" {
	local dec = 3
	}
	else {
	capture confirm integer number `decimals'
	if _rc | !inrange(real("`decimals'"), 0, 7) {
		di _newline(1)
		di as err "{opt decimals()} must be an integer between 0 and 7."
		exit 198
		}
	local dec = `decimals'
	}
if "`labwidth'" == "" {
	local twidth = 32
	}
	else {
*32 is the maximum width allowed
	capture confirm integer number `labwidth'
	if _rc | !inrange(real("`labwidth'"), 20, 32) {
		di _newline(1)
		di as err "{opt labwidth()} must be between 20 and 32. To fit longer " /*
		*/ "names, shorten them with {opt mod1name()} / {opt mod2name()} or " /*
		*/ "use shorter names in {opt models()}."
		exit 198
		}
	local twidth = `labwidth'
	}
if "`statwidth'" == "" {
	local width = 9
	}
	else {
	capture confirm integer number `statwidth'
	if _rc | !inrange(real("`statwidth'"), 9, 20) {
		di _newline(1)
		di as err "{opt statwidth()} must be an integer between 9 and 20."
		exit 198
		}
	local width = `statwidth'
	}

*Override default of adding row numbers if norownum is requested
if "`norownum'" != "" {
	local addnums = 0
	}
else {
	local addnums = 1
	}	
	
*if models() omitted: take the estimates from e()
if `"`models'"' == "" {

*Undocumented engine(gsem) REFITS both constituent commands (see mec_gsem)
	if lower(strtrim("`engine'")) == "gsem" {
		di as err "{opt engine(gsem)} requires {opt models( )}: it refits " /*
		*/ "the models rather than combining the stored estimates, so it " /*
		*/ "needs to be told which stores to refit."
		exit 198
		}

	local ecmdnow "`e(cmd)'"

*	TWO MODELS: only allowed in memory if from a suest2 system
	if "`ecmdnow'" == "suest2" {
		local models `"`e(names)'"'
		local nfound : word count `models'
		if `nfound' != 2 {
			di as err "The {cmd:suest2} system in memory names `nfound' " /*
			*/ "model(s); {cmd:mecompare} needs two. Name them in " /*
			*/ "{opt models( )}."
			exit 198
			}
		}

*	ONE MODEL: whatever is in e()
	else {
		capture confirm matrix e(b)
		if _rc {
			di as err "{opt models( )} was omitted and there are no " /*
			*/ "estimation results in memory to use instead. Fit a model, " /*
			*/ "or name stored estimates in {opt models( )}."
			exit 301
			}
		if "`ecmdnow'" == "mecompare" {
			capture qui estimates restore _mec_src
			if _rc {
				di as err "The estimation results in memory are a " /*
				*/ "previous {cmd:mecompare} table, not a model, and no " /*
				*/ "source model was stashed -- the last run compared TWO " /*
				*/ "models, or the stash has been cleared."
				di as err "Refit the model, or name stored estimates in " /*
				*/ "{opt models( )}. To redisplay the table you already " /*
				*/ "have, type {cmd:mecompare} with no arguments."
				exit 198
				}

			local srcdv "`e(depvar)'"
			local srccmd "`e(cmd)'"
			local stale = 0
			if "$MEC_SRC_N" == "" | "$MEC_SRC_DV" == ""  local stale = 1
			else if `=_N' != $MEC_SRC_N                  local stale = 1
			else {
				capture confirm variable `srcdv'
				if _rc  local stale = 1
				}
			if `stale' {
				capture estimates drop _mec_src
				di as err "The stashed source model no longer matches the " /*
				*/ "data in memory (observation count or dependent " /*
				*/ "variable changed since it was fit), so it has not " /*
				*/ "been reused."
				di as err "Refit the model, or name stored estimates in " /*
				*/ "{opt models( )}."
				exit 198
				}
			di as text "note: {opt models( )} omitted and {cmd:e()} holds a " /*
				*/ "previous {cmd:mecompare} table; reusing the " /*
				*/ "{cmd:`srccmd'} model from that run. Type " /*
				*/ "{cmd:mecompare} with no arguments to replay the table " /*
				*/ "instead."
			local ecmdnow "`srccmd'"
			}

		tempname mecsolo
		capture estimates store `mecsolo'
		if _rc {
			di as err "{opt models( )} was omitted and the estimation " /*
			*/ "results in memory could not be stored (rc `=_rc'). Store " /*
			*/ "them yourself and name them in {opt models( )}."
			exit 198
			}
		local models "`mecsolo'"
		if "`mod1name'" == ""  local mod1name "m1"
		}
	}
	
*Change model names in table if requested 	
if "`mod1name'" == "" {
		local mod1lab : word 1 of `models'
		}
	else {
		local mod1lab = substr("`mod1name'",1,10) // truncate name
		}
if "`mod2name'" == "" {
		local mod2lab : word 2 of `models'
		}	
	else {
		local mod2lab = substr("`mod2name'",1,10) // truncate name
		}

*v0.2.3: groupnames( ) labels the two groups (else labeled by model name)
if "`groupnames'" != "" & "`groups'" == "" {
	di as err "The {opt groupnames} option requires the {opt groups} option. " /*
	*/ "See {help mecompare##groups}."
	exit 198
	}
if "`groupme'" != "" & "`groups'" == "" {
	di as err "The {opt groupme} option requires the {opt groups} option. " /*
	*/ "See {help mecompare##groups}."
	exit 198
	}
if "`groupsd'" != "" & "`groups'" == "" {
	di as err "The {opt groupsd} option requires the {opt groups} option. " /*
	*/ "See {help mecompare##groups}."
	exit 198
	}
if "`groupnames'" != "" {
	local gn1 : word 1 of `groupnames'
	local gn2 : word 2 of `groupnames'
	local mod1lab = substr("`gn1'",1,10)
	local mod2lab = substr("`gn2'",1,10)
	}

*Estimate gsem and margins command noisily or quietly based on details option
if "`details'" != "" {
	local cmdqui ""
	}
else {
	local cmdqui "qui"
	}	
		
*Check whether there are 1 or 2 models
local nummods : word count `models'
if `nummods' != 1 {
	capture estimates drop _mec_src
	macro drop MEC_SRC_N MEC_SRC_DV
	}

*Error out if groups specified incorrectly
if "`groups'" != "" & `nummods' == 1 {
	di as err "The {opt groups} option requires two models be specified in " /*
	*/ "{opt models( )} option -- one per group. See " /*
	*/ "{help mecompare##groups}."
	exit 198
	}

*Create locals to refer to models by #
forvalues i = 1/`nummods' {
	local mod`i' : word `i' of `models'
	}

local rkey1 = strtoname(substr("`mod1'",1,28))
local rkey2 ""
if `nummods' == 2  local rkey2 = strtoname(substr("`mod2'",1,28))
local rkeyD "Difference"
if "`rkey1'" == "`rkeyD'"  local rkey1 "`rkey1'_1"
if "`rkey2'" == "`rkeyD'"  local rkey2 "`rkey2'_2"
if "`rkey2'" == "`rkey1'"  local rkey2 "`rkey2'_2"

*Error out if 0 or >= 3 models listed
if `nummods' == 0 | `nummods' >= 3 {
	di as err "Invalid number of models listed in {opt models( )} option. " /*
	*/ "{cmd:mecompare} can only be used with one or two models."
	exit 198
} 

*Set weight specification 
if "`weight'" != "" {
	local weightspec = "[`weight' `exp']"
	}
	
local list_ivs1 ""
local list_ivs2 ""

// Needed for one model path
if `nummods' == 1 {
	qui est restore `mod1'
	capture estimates drop _mec_src
	capture estimates store _mec_src
	if _rc == 0 {
		global MEC_SRC_N  = _N
		global MEC_SRC_DV "`e(depvar)'"
		}
	else {
		macro drop MEC_SRC_N MEC_SRC_DV
		}

	local mwtype1 = "`e(wtype)'"
	local mwexp1  = "`e(wexp)'"
	local mprefix1 = "`e(prefix)'"

*The weight belongs on the STORED model
	if "`weight'" != ""  mec_wcheck, gweight(`weight') gexp(`exp') /*
		*/ mwtype(`mwtype1') mwexp(`mwexp1') prefix(`mprefix1') cmd(mecompare)
	}

// Needed for two model path	
*engine() selects how two models are combined (undocumented): suest2 default, gsem fallback
local engine = lower(strtrim("`engine'"))
if "`engine'" == ""  local engine "suest2"
if !inlist("`engine'", "gsem", "suest2") {
	di _newline(1)
	di as err "{opt engine()} must be {opt gsem} or {opt suest2}."
	exit 198
	}
if "`engine'" == "suest2" {
	capture which suest2
	if _rc {
		di _newline(1)
		di as err "{opt engine(suest2)} needs the {cmd:suest2} command, which " /*
		*/ "ships with {cmd:mecompare}. It was not found on the adopath."
		exit 199
		}
	}

* the stored system is named for the ENGINE that built it
local mecsys "mec_suest2"
local mecalt "mec_gsem"
if "`engine'" == "gsem" {
	local mecsys "mec_gsem"
	local mecalt "mec_suest2"
	}

* mi estimate support -- defaults (overridden below when mi detected)
local marginscmd "margins"
local mimarginsspec ""
*information for mec_gsem
local ismi = 0
local s2spec1 = 0
local s2spec2 = 0
local issvy = 0

****************************************************************************
// If 1 model, restore the estimates and store information
****************************************************************************
if `nummods' == 1 {
	qui est restore `mod1'
	
	local 	N1 = e(N)
	local 	dv1name 	= "`e(depvar)'"
	tempvar mec_sample 
	if "`e(cmd)'" == "mi estimate"        local ismi = 1
	if "`e(prefix_mi)'" == "mi estimate"  local ismi = 1
	if "`e(mi)'" == "mi"                  local ismi = 1
	capture confirm scalar e(M_mi)
	if !_rc                               local ismi = 1
	*additional info for mi estimate as it does not set e(sample)
	if `ismi' == 1  qui gen `mec_sample' = 1 if `mectouse'
	else            qui gen `mec_sample' = 1 if e(sample) & `touse'
	*Levels and category counts are read from the estimation sample (all data if it is empty)
	local meclevif "if `mec_sample' == 1"
	qui count if `mec_sample' == 1
	if r(N) == 0  local meclevif ""
	if "`e(prefix)'" == "svy"  local issvy = 1
	*check for supported pweight[] model
	if inlist("`e(cmd)'", "mixed", "melogit", "meprobit", "mecloglog", "mepoisson") | /*
	*/ inlist("`e(cmd)'", "menbreg", "meologit", "meoprobit", "mestreg", "meglm") {
		if trim("`e(prefix)'") == "" & "`e(wtype)'" == "pweight" & /*
		*/ trim(`"`e(pweight1)'"') == "" {
			di _newline(1)
			di as err "model `mod1' was fit with a weight but without a stage " /*
			*/ "weight, so it carries no higher-level weight to build a design " /*
			*/ "from; a weighted multilevel model needs one, as in " /*
			*/ "[pw=w2] || group:, pweight(w1), or use the svy: prefix"
			exit 198
			}
		}

*mi with single model
	if `ismi' == 1 {
		local marginscmd "mimrgns"
		capture which mimrgns
		if _rc {
			di _newline(1)
			di as err "{cmd:mecompare} needs the user-written {cmd:mimrgns} " /*
			*/ "package to analyse {cmd:mi estimate} models. Install it " /*
			*/ "with {stata search mimrgns: search mimrgns}."
			exit 198
			}
		}

	if `ismi' == 1 {
		local s2under "`e(cmd_mi)'"
		if trim("`s2under'") == "" | "`s2under'" == "mi estimate" ///
			local s2under "`e(cmd)'"
		if trim("`s2under'") != "" & "`s2under'" != "mi estimate" ///
			local cmd1 "`s2under'"
		}

if trim("`cmd1'") == ""  local cmd1 "`e(cmd)'"
*The supported models details lives in _mec_canonical
local s2raw "`e(cmd)'"
if "`cmd1'" != "" & "`cmd1'" != "mi estimate"  local s2raw "`cmd1'"
_mec_canonical, cmd("`s2raw'") cmd2("`e(cmd2)'") model("`e(model)'") /*
	*/ distrib("`e(distrib)'") method("`e(method)'") estimator("`e(estimator)'")
local cmd1 "`r(canon)'"
local okmod = r(ok)
local s2only1 = r(suest2only)
local s2spec1 = r(spec)
if `okmod' == 0 {
	di as err "`mod1' is a {cmd:`cmd1'}. {cmd:mecompare} " /* 
	*/ "only supports the following estimation commands: `mecsupp'"
	exit 198	
	}
if `s2only1' == 1 & "`engine'" == "gsem" {
	di as err "{cmd:`cmd1'} is supported only by the default engine. " /*
	*/ "Remove {opt engine(gsem)}."
	exit 198
	}
	
// Set num of cats for predictions
if "`cmd1'" == "ologit" | "`cmd1'" == "oprobit" | "`cmd1'" == "gologit2" ///
	| "`cmd1'" == "meologit" | "`cmd1'" == "meoprobit" ///
	| "`cmd1'" == "xtologit" | "`cmd1'" == "xtoprobit" {
	local mod1cats = e(k_cat)
	}
else if "`cmd1'" == "mlogit" {
	local mod1cats = e(k_eq)
	}
else if "`cmd1'" == "xtmlogit" {
	local mod1cats = e(k_out)
	}
else {
	local mod1cats = 1
	}
		
*Extract the model's IVs from e(b) via mec_share's extractor
_mec_ebcheck, name("`mod1'")
mec_share ebvars
local clean_list1b `"`s(fvvars)'"'
local mecinmods    "`clean_list1b'"		

if "`varlist'" == "" { // If no vars listed, calculate MEs for all IVs
	local list_ivs : list uniq clean_list1b
	}
else { 	// annotate the specified plain/factor varlist
	_mec_annotate, uservars("`varlist'") modelivs("`clean_list1b'")
	local list_ivs "`r(annotated)'"
	}
}

****************************************************************************
// If 2 models, simultaneously estimate models with suest2 //
****************************************************************************
if `nummods' == 2 {
	forvalues i = 1/`nummods' {

	qui est restore  `mod`i''

*Store DVs, estimation commands, list of IVs, sample
tempvar mod`i'samp
qui gen `mod`i'samp' = e(sample)
local Nsav`i' 		= e(N)	// N of saved model; double-checked after gsem
local dv`i' 		= "`e(depvar)'"
local dv`i'name 	= "`e(depvar)'" // store original name if duplicating
local cmd`i' 		= "`e(cmd)'"
*weights per model
local mwtype`i'		= "`e(wtype)'"
local mprefix`i'	= "`e(prefix)'"
local mwexp`i'		= "`e(wexp)'"
local cmdline`i' 	= "`e(cmdline)'"
*Strip a multilevel `|| group:' part from the IV list
local dpipe`i' = strpos("`cmdline`i''", "||")
if `dpipe`i'' != 0 ///
	local cmdline`i' = substr("`cmdline`i''", 1, `dpipe`i'' - 1)
*Check the varlist
_mec_ebcheck, name("`mod`i''")
mec_share ebvars
local fvivs`i' `"`s(fvvars)'"'
local vcetype`i'	= "`e(vce)'" // Will produce warning below if not robust
*mi checks / info
local ismi`i' = 0
local s2mimark = 0
if "`e(cmd)'" == "mi estimate"           local s2mimark = 1
if "`e(prefix_mi)'" == "mi estimate"     local s2mimark = 1
if "`e(mi)'" == "mi"                     local s2mimark = 1
capture confirm scalar e(M_mi)
if !_rc                                  local s2mimark = 1
if `s2mimark' == 1 {
*mi info and checks
	local cmd`i' = "`e(cmd_mi)'"
	if trim("`cmd`i''") == "" | "`cmd`i''" == "mi estimate" ///
		local cmd`i' = "`e(cmd)'"
	local Nsav`i' = e(N_mi)
	if missing(`Nsav`i'') local Nsav`i' = e(N)
	local mc = strpos("`cmdline`i''", ":")
	if `mc' > 0 local cmdline`i' = trim(substr("`cmdline`i''", `mc'+1, .))
	local ismi`i' = 1
	capture which mimrgns
	if _rc {
		di _newline(1)
		di as err "{cmd:mecompare} needs the user-written {cmd:mimrgns} " /*
		*/ "package to compare {cmd:mi estimate} models. Install it with " /*
		*/ "{stata search mimrgns: search mimrgns}."
		exit 198
		}
	}
*detect svy: models (run the combine gsem under svy:)
local issvy`i' = 0
if "`e(prefix)'" == "svy" {
	local issvy`i' = 1
	local mc = strpos("`cmdline`i''", ":")
	if `mc' > 0 local cmdline`i' = trim(substr("`cmdline`i''", `mc'+1, .))
	}
	
*Canonical test in _mec_canonical; pass the already-resolved command for mi stores
local s2raw "`e(cmd)'"
if "`cmd`i''" != "" & "`cmd`i''" != "mi estimate"  local s2raw "`cmd`i''"
_mec_canonical, cmd("`s2raw'") cmd2("`e(cmd2)'") model("`e(model)'") /*
	*/ distrib("`e(distrib)'") method("`e(method)'") estimator("`e(estimator)'")
if "`r(canon)'" != ""  local cmd`i' "`r(canon)'"
local okmod = r(ok)
local s2only`i' = r(suest2only)
local s2spec`i' = r(spec)
if `okmod' == 0 {
	di as err "`mod`i'' is a {cmd:`cmd`i''}. {cmd:mecompare} only " /*
	*/ "supports the following estimation commands: `mecsupp'"
	exit 198
	}
if `s2only`i'' == 1 & "`engine'" == "gsem" {
	di as err "{cmd:`cmd`i''} is supported only by the default engine. " /*
	*/ "Remove {opt engine(gsem)}."
	exit 198
	}
*gologit2 with two models is supported under suest2 
if "`cmd`i''" == "gologit2" & "`engine'" == "gsem" {
	di as err "{cmd:gologit2} is not supported by {opt engine(gsem)} with two " /*
	*/ "models: {cmd:gsem} cannot replicate {cmd:gologit2}. Remove " /*
	*/ "{opt engine(gsem)} to use the default engine, which combines the " /*
	*/ "stored estimates without refitting them."
	exit 198
	}	
	
// Set num of cats for predictions	
if "`cmd`i''" == "ologit" | "`cmd`i''" == "oprobit" | "`cmd`i''" == "gologit2" ///
	| "`cmd`i''" == "meologit" | "`cmd`i''" == "meoprobit" ///
	| "`cmd`i''" == "xtologit" | "`cmd`i''" == "xtoprobit" {
	local mod`i'cats = e(k_cat)
	}
else if "`cmd`i''" == "mlogit" {
	local mod`i'cats = e(k_eq)
	}
else if "`cmd`i''" == "xtmlogit" {
	local mod`i'cats = e(k_out)
	}
else {
	local mod`i'cats = 1
	}
				
*Strip the model options after comma if present
local ifcomma = strpos("`cmdline`i''", ",")  
if `ifcomma' == 0 {
	local cmdline`i' = "`cmdline`i''"
	}
else {	
	local cmdline`i' = substr("`cmdline`i''", 1, strpos("`cmdline`i''", ",") - 1) 
	}

*Strip a [weight]; it precedes the options comma
local cmdline`i' = regexr("`cmdline`i''", "\[[^]]*\]", "")

*Strip any if/in clause
local hadifin`i' = 0
local ifpos = strpos("`cmdline`i''", " if ")
local inpos = strpos("`cmdline`i''", " in ")
if `ifpos' > 0 {
	local cmdline`i' = substr("`cmdline`i''", 1, `ifpos' - 1)
	local hadifin`i' = 1
	}
else if `inpos' > 0 {
	local cmdline`i' = substr("`cmdline`i''", 1, `inpos' - 1)
	local hadifin`i' = 1
	}



} // End of looping through each of the two models

*With two models and no weight given, inherit the models' weight (both must agree)
local wtinherit = 0
if `nummods' == 2 {
	if "`mwexp1'" != "`mwexp2'" | "`mwtype1'" != "`mwtype2'" {
		di _newline(1)
		di as err "The two models were fit with different weights, so they " /*
		*/ "cannot be combined. Refit them with the same weight."
		exit 198
		}
*An explicit weight may restate the models' weight but not contradict it
	if "`weight'" != "" {
		mec_wcheck, gweight(`weight') gexp(`exp') mwtype(`mwtype1') /*
			*/ mwexp(`mwexp1') prefix(`mprefix1') cmd(mecompare)
		mec_wcheck, gweight(`weight') gexp(`exp') mwtype(`mwtype2') /*
			*/ mwexp(`mwexp2') prefix(`mprefix2') cmd(mecompare)
		}
	else if "`mwexp1'" != "" {
		local weightspec "[`mwtype1' `mwexp1']"
		local wtinherit = 1
		}
	}

*mi estimate combine prefix + mimrgns; both models must match on mi
if `ismi1' == 1 | `ismi2' == 1 {
	if `ismi1' != `ismi2' {
		di _newline(1)
		di as err "One model uses {cmd:mi estimate} and the other does not; " /*
		*/ "both models must be {cmd:mi estimate} (or neither)."
		exit 198
		}
	local marginscmd "mimrgns"
	local mimarginsspec "predict(default) errorok esampvaryok"
	local ismi = 1
	}
*svy: combine (both models must be svy, and not mixed with mi)
if `issvy1' == 1 | `issvy2' == 1 {
	if `issvy1' != `issvy2' {
		di _newline(1)
		di as err "One model uses the {opt svy:} prefix and the other does " /*
		*/ "not; both models must be {opt svy:} (or neither)."
		exit 198
		}
*mi estimate: svy: is supported; mi is the outer prefix
	local weightspec ""
	local issvy = 1
	}




*Build the group sample tempvar from the two models' e(sample)s; samples must be distinct
tempvar mecgsamp
if "`groups'" != "" {
	qui gen `mecgsamp' = .
	qui replace `mecgsamp' = 1 if `mod1samp' == 1
	qui replace `mecgsamp' = 2 if `mod2samp' == 1
	qui count if `mecgsamp' == 1
	if `r(N)' != `Nsav1' {
		di _newline(1)
		di as err "The {opt groups} option requires distinct " /*
		*/ "(non-overlapping) samples across the two models, but the " /*
		*/ "samples overlap. See {help mecompare##groups}."
		exit 198
		}
	}

*Point to groups if the two samples do not overlap
if "`groups'" == "" & `ismi' != 1 {
	qui count if `mod1samp' == 1 & `mod2samp' == 1
	if `r(N)' == 0 {
		di _newline(1)
		di as err "The two models were fit on non-overlapping samples. If " /*
		*/ "you intend to compare marginal effects across groups, specify " /*
		*/ "the {opt groups} option. See {help mecompare##groups}."
		exit 198
		}
	}

*Any two models are comparable when they return the same number of predictions

*The number of predictions must agree across the two models
if `nummods' == 2 & `mod1cats' != `mod2cats' {
	di _newline(1)
	di as err "The models return different numbers of predictions: `mod1' " /*
	*/ "returns `mod1cats' and `mod2' returns `mod2cats'. {cmd:mecompare} " /*
	*/ "compares models that return the same number of predictions. See " /*
	*/ "{help mecompare##model_combos}"
	exit 198
	}
*Outcome values must also agree for multi-category pairs
if `nummods' == 2 & `mod1cats' >= 3 {	
*Outcomes are matched positionally, so equal counts are not enough
	qui levelsof `dv1name' if `mod1samp' == 1, local(mecoc1)
	qui levelsof `dv2name' if `mod2samp' == 1, local(mecoc2)
	if "`mecoc1'" != "`mecoc2'" {
		di _newline(1)
		di as err "The outcome categories differ across the models: " /*
		*/ "`mod1' has `mecoc1' and `mod2' has `mecoc2'. {cmd:mecompare} " /*
		*/ "matches outcomes in order, so the values must agree."
		exit 198
		}
*	Values agree; warn if the value labels do not (model 1's are shown).
	local meclb1 : value label `dv1name'
	local meclb2 : value label `dv2name'
	if "`meclb1'" != "`meclb2'" {
		di _newline(1)
		di in red "NOTE: the two outcome variables carry different value " /*
		*/ "labels (`meclb1' and `meclb2'). The outcome VALUES agree, so " /*
		*/ "the comparison is well defined; the table is labeled with the " /*
		*/ "labels from `mod1'."
		}
}	

*Warn if an if/in was stripped: the models are refit over mecompare's sample.
if "`groups'" == "" & (`hadifin1' == 1 | `hadifin2' == 1) {
	di _newline(1)
	if `wtinherit' == 1 & `issvy' != 1 {
	di _newline(1)
	di in red "NOTE: no weight was given to {cmd:mecompare}, so the weight " /*
	*/ "from the stored models ([`mwtype1' `mwexp1']) is applied to the " /*
	*/ "combined fit."
	}

*Note applies to the gsem engine only; suest2 preserves each model's if/in
if "`engine'" == "gsem" {
di in red "NOTE: a model given in {opt models( )} was fit with an " /*
	*/ "{help if} or {help in} qualifier. {cmd:mecompare} combines and " /*
	*/ "refits the models over its own sample, so results will not match " /*
	*/ "the stored models unless the same qualifier is given to " /*
	*/ "{cmd:mecompare}."
	}
	}	

*Warn if vce(robust) not used on stored models
if ("`vcetype1'" != "robust" | "`vcetype2'" != "robust") & `issvy' != 1 & `ismi' != 1 {
	di in red "{cmd:mecompare} uses vce(robust) for all models. " /*
	*/ "Standard errors from {cmd:mecompare} will differ from the " /*
	*/ "specified model(s) because vce(robust) was not used on at " /*
	*/ "least one of the models specified in the {it:models( )} " /*
	*/ "option. We strongly recommend refitting the first " /*
	*/ "({cmd:`cmd1'}) and second ({cmd:`cmd2'}) models with " /*
	*/ "vce(robust). See {help vce_option} for details on vce(robust)."
	}	
	
*ME lists come from the e(b)-sourced fvivs locals
local list_ivs1 `"`fvivs1'"'
local list_ivs2 `"`fvivs2'"'
local mecinmods    "`list_ivs1' `list_ivs2'"	// v0.2.45: for the check below
*Keep an unintersected copy of each model's IVs for the route guards
local mecfull1 "`list_ivs1'"
local mecfull2 "`list_ivs2'"

*Allow plain variable names in varlist; annotate against both models
if "`varlist'" != "" {
	_mec_annotate, uservars("`varlist'") modelivs("`list_ivs1' `list_ivs2'")
	local varlist "`r(annotated)'"
	}

if "`varlist'" == "" { // If empty, calculate MEs for all vars in either model
	local list_ivs1 	: list uniq list_ivs1
	local list_ivs2 	: list uniq list_ivs2
	local combo_list 	"`list_ivs1' `list_ivs2'"
	local list_ivs 		: list uniq combo_list
	}			

else {
	local list_ivs1 : list varlist & list_ivs1
	local list_ivs2 : list varlist & list_ivs2
	local list_ivs "`varlist'"	
	}

*DV cloning lives in mec_gsem (gsem only); clone names come back in r()
local mecdv1 ""
local mecdv2 ""
	
di 	
*Include model specs. in output
di 		_newline(1)
*Echo each model's own stored command line (display only)
local 	mec_cl1 = itrim(trim("`cmdline1'"))
local 	mec_cl2 = itrim(trim("`cmdline2'"))
local 	mod1specs "`mec_cl1'"
local 	mod2specs "`mec_cl2'"

	local 	mod1clean = itrim("`mod1specs'")
	local 	mod2clean = itrim("`mod2specs'")
	di 		as text "Model 1 (`mod1') is:"
	di 		as result "     `mod1clean'"
	di 		as text "Model 2 (`mod2') is:"
	di 		as result "     `mod2clean'"
	
*listwise moved to mec_gsem with the rest of the gsem call.
	
*Combine the two stored models with the chosen engine
if "`engine'" == "gsem" {
	local g_groups ""
	local g_samp ""
	if "`groups'" != "" {
		local g_groups "groups"
		local g_samp "sampvar(`mecgsamp')"
		}
	local g_cmds ""
	if "`commands'" != ""  local g_cmds "commands"
	local g_qui ""
	if "`cmdqui'" != ""  local g_qui "quietly"
	mec_gsem `mod1' `mod2' `weightspec', /*
		*/ `g_groups' `g_samp' `g_cmds' `g_qui'
	local mecdv1 "`mec_gsem_dv1'"
	local mecdv2 "`mec_gsem_dv2'"
	}
else {
	if "`commands'" != "" {
		di _newline(1)
		di as text "suest2 model is: "
		di as result "    suest2 `mod1' `mod2', nowarn"
		}
	`cmdqui' suest2 `mod1' `mod2', nowarn
	}

capture estimates drop `mecalt'
est 	store `mecsys'

*Capture suest2's private-copy names now; labelled at end of program
local mecholdn ""
local mecholdw ""
if "`engine'" != "gsem" {
	local mecholdn `"`e(suest2_holds)'"'
	local __nh : word count `mecholdn'
	forvalues __h = 1/`__nh' {
		local __mn "suest2_model`__h'"
		local mecholdw `"`mecholdw' `e(`__mn')'"'
		}
	}
tempvar mec_sample 
*Under mi, e(sample) is unset; if/in alone defines the analysis sample
if `ismi' == 1  qui gen `mec_sample' = 1 if `mectouse'
else            qui gen `mec_sample' = 1 if e(sample) & `touse'
*Levels and category counts are read from the estimation sample (all data if it is empty)
local meclevif "if `mec_sample' == 1"
qui count if `mec_sample' == 1
if r(N) == 0  local meclevif ""

matrix 	n_mods = e(_N)
local 	N1 = n_mods[1,1]
local 	N2 = n_mods[1,2]

*Note when the models' sample sizes differ
if "`groups'" == "" {
	if `Nsav1' != `Nsav2' {
	di _newline(1)
	if "`engine'" == "gsem" {
	di in red "Sample size varies across the models: N_`mod1'=`Nsav1' ; " /*
	*/ "N_`mod2'=`Nsav2'. The results from {cmd:mecompare} will not match " /*
	*/ "those from the specified models as {cmd:mecompare} uses listwise " /*
	*/ "deletion across the models resulting in N_mecompare = `N1'"
	}
	else {
	di in red "Sample size varies across the models: N_`mod1'=`Nsav1' ; " /*
	*/ "N_`mod2'=`Nsav2'. Each model keeps its own estimation sample, so the " /*
	*/ "marginal effects are the ones each stored model implies. Note this " /*
	*/ "differs from {cmd:engine(gsem)}, which restricts both models to the " /*
	*/ "observations present in both."
	}
	}
}

}	// End of two model-specific options

*Weight for SDs/shares: mecompare's if given, else the models' own (pweight maps to aweight)
local sdwtype ""
local sdwexp ""
if "`weight'" != "" {
	local sdwtype "`weight'"
	local sdwexp "`exp'"
	}
else if "`mwexp1'" != "" {
	local sdwtype "`mwtype1'"
	local sdwexp "`mwexp1'"
	}
if "`sdwtype'" == "pweight"  local sdwtype "aweight"
local sdwspec ""
if "`sdwtype'" != "" & "`sdwexp'" != ""  local sdwspec "[`sdwtype' `sdwexp']"

*marginsopt(expression()): one quantity, one model, in place of predict(); the count resets as for predict(outcome(#))
if `"`mecexpr'"' != "" {
	if `nummods' == 2 {
		di _newline(1)
		di as err "{opt expression()} in {opt marginsopt()} returns one quantity, " /*
		*/ "and the two-model table needs one prediction per model. Use " /*
		*/ "{opt predict()}."
		exit 198
		}
	if "`predict'" != "" {
		di _newline(1)
		di as err "{opt expression()} in {opt marginsopt()} replaces {opt predict()}; " /*
		*/ "margins accepts one or the other. Put the prediction inside the " /*
		*/ "expression, as in {opt expression(exp(predict(xb)))}."
		exit 198
		}
	local mod1cats = 1
	}

*predict(): xb/eta = linear predictor; ordered models then return one quantity, so reset the count
local predlin = 0
if "`predict'" != "" {
*	cmd`i' is built in the two-model loop only
	if `nummods' == 1 & "`cmd1'" == ""  local cmd1 = "`e(cmd)'"
	local plow = lower(strtrim("`predict'"))
	if inlist("`plow'","xb","eta")  local predlin = 1
*An outcome(#) selection is a single quantity
	local predoc = strpos("`plow'", "outcome(") > 0

*mlogit xb is one per outcome equation, not a single quantity; refuse (do not delete this block)
	if "`cmd1'" == "mlogit" | "`cmd2'" == "mlogit" {
		if !(`nummods' == 1 & `predoc') {
			di _newline(1)
			di as err "{opt predict()} with {cmd:mlogit} needs a single-" /*
			*/ "quantity selection: its predictions are one per outcome " /*
			*/ "category. With one model, select one, as in " /*
			*/ "{opt predict(pr outcome(2))}."
			exit 198
			}
		}
*Keyed on category counts: any one-per-category prediction is refused with two models
	local ordmod = 0
	if `mod1cats' > 1  local ordmod = 1
	if `nummods' == 2 & "`mod2cats'" != "" {
		if `mod2cats' > 1  local ordmod = 1
		}
	if `predlin' == 0 & `ordmod' == 1 {
		if !(`nummods' == 1 & `predoc') {
			di _newline(1)
			di as err "With a multi-category outcome model {opt predict()} " /*
			*/ "accepts {opt xb} or {opt eta} (the linear predictor); other " /*
			*/ "predictions are one per outcome category. With one model, " /*
			*/ "a single category may be selected, as in " /*
			*/ "{opt predict(pr outcome(2))}."
			exit 198
			}
		}

*	the linear predictor is a single quantity per equation
	if `predlin' == 1 {
		local mod1cats = 1
		local mod2cats = 1
		}
*so is an outcome(#) selection on the one-model path.
	if `nummods' == 1 & `predoc' {
		local mod1cats = 1
		}
	}

*Parse and validate by()/over()
if "`by'" != "" & "`over'" != "" {
	di _newline(1)
	di as err "{opt by()} and {opt over()} cannot be specified together."
	exit 198
	}
if "`by'`over'" != "" {
	if "`groups'" != "" {
		di _newline(1)
		di as err "{opt by()}/{opt over()} cannot be combined with {opt groups}."
		exit 198
		}
	local byvars ""
	if "`by'" != "" {
		local botype "by"
		local byvars = subinstr("`by'",   "i.", "", .)
		}
	else {
		local botype "over"
		local byvars = subinstr("`over'", "i.", "", .)
		}
	local byuniq : list uniq byvars
	if `: word count `byuniq'' != `: word count `byvars'' {
		di _newline(1)
		di as err "A variable is named twice in {opt `botype'()}."
		exit 198
		}
*Every by()/over() variable must be a nominal (i.) predictor in the model(s)
	local chkmods "`clean_list1b' `fvivs1' `fvivs2'"
*Test the factor term itself (ib2.var and ibn.var are categorical too)
	local chkmods : subinstr local chkmods "#" " ", all
	local nbyvars : word count `byvars'
	forvalues bk = 1/`nbyvars' {
		local byv_`bk' : word `bk' of `byvars'
		local bofound = 0
		foreach mectk of local chkmods {
			local mecbase = regexr("`mectk'","^i(b[0-9]+|bn)?\.","")
			if "`mecbase'" != "`mectk'" & "`mecbase'" == "`byv_`bk''"  local bofound = 1
			}
		if `bofound' == 0 {
			di _newline(1)
			di as err "Variable {bf:`byv_`bk''} was not found as a nominal (i.) " /*
			*/ "predictor in the model(s). {opt `botype'()} requires a nominal " /*
			*/ "variable entered with the i. prefix in the model(s)."
			exit 198
			}
		qui levelsof `byv_`bk'' `meclevif', local(bylev_`bk')
		local bylabn_`bk' : value label `byv_`bk''
		}
	}

*Value lists: refused with over() and groups; the listed covariate is neither focal nor the by() variable
if "`covlistvar'`stlistvar'" != "" {
	if "`over'" != "" {
		di _newline(1)
		di as err "A value list in {opt covariates()} or {opt start()} is a " /*
		*/ "counterfactual and cannot be combined with {opt over()}, which " /*
		*/ "splits the sample. Use {opt by()} or drop the list."
		exit 198
		}
	if "`groups'" != "" {
		di _newline(1)
		di as err "A value list in {opt covariates()} or {opt start()} cannot " /*
		*/ "be combined with {opt groups}."
		exit 198
		}
	}
if "`covlistvar'" != "" {
	local covinby : list posof "`covlistvar'" in byvars
	if `covinby' > 0 {
		di _newline(1)
		di as err "{bf:`covlistvar'} carries a value list in {opt covariates()} " /*
		*/ "and is also a {opt by()} variable. Use one or the other."
		exit 198
		}
	foreach mectk of local list_ivs {
		local mectkb = regexr("`mectk'", "^(c|i(b[0-9]+|bn)?)\.", "")
		if "`mectkb'" == "`covlistvar'" {
			di _newline(1)
			di as err "{bf:`covlistvar'} carries a value list in " /*
			*/ "{opt covariates()} but is a focal variable. A focal variable " /*
			*/ "takes its values from {opt start()}."
			exit 198
			}
		}
	}

*Cells: by() levels x covariates() list values; one cell with an empty assignment otherwise
local nbocells = 1
local boat_1 ""
local bolabc_1 ""
local boclnc_1 ""
if "`by'`covlistvar'" != "" {
*Dimensions in order: each by() variable, then the covariates() list; first outermost
	local ndim = 0
	if "`by'" != "" {
		forvalues bk = 1/`nbyvars' {
			local ++ndim
			local dimvar_`ndim' "`byv_`bk''"
			local dimlev_`ndim' "`bylev_`bk''"
			local dimlab_`ndim' "`bylabn_`bk''"
			local dimkind_`ndim' "by"
			}
		}
	if "`covlistvar'" != "" {
		local ++ndim
		local dimvar_`ndim' "`covlistvar'"
		local dimlev_`ndim' "`covlistvals'"
		local dimlab_`ndim' ""
		local dimkind_`ndim' "cov"
		}
*Grow the cell list one dimension at a time
	forvalues dk = 1/`ndim' {
		local newn = 0
		forvalues c = 1/`nbocells' {
			foreach lv of local dimlev_`dk' {
				local ++newn
				local boatN_`newn' = trim("`boat_`c'' `dimvar_`dk''=`lv'")
				if "`dimlab_`dk''" != "" {
					local tmplab : label `dimlab_`dk'' `lv'
					local tmplab = abbrev("`tmplab'", 13)
					}
				else if "`dimkind_`dk''" == "cov"  local tmplab = abbrev("`dimvar_`dk''=`lv'", 13)
				else  local tmplab "`dimvar_`dk''=`lv'"
				local bolabcN_`newn' = trim("`bolabc_`c'' `tmplab'")
				local lvtok = strtoname("`dimvar_`dk''_`lv'")
				if "`boclnc_`c''" == ""  local boclncN_`newn' "`lvtok'"
				else  local boclncN_`newn' "`boclnc_`c''_`lvtok'"
				}
			}
		local nbocells = `newn'
		forvalues c = 1/`nbocells' {
			local boat_`c' "`boatN_`c''"
			local bolabc_`c' "`bolabcN_`c''"
			local boclnc_`c' "`boclncN_`c''"
			}
		}
	}

****************************************************************************
// Set the margins specification and estimate predictions with margins 
*Set values of covariates if requested (atmeans set later on the margins call)
if "`covariates'" != "" {
	local covspec = subinword("`covariates'", "atmeans", " ", .)
	}
else {
	local covspec " "
	}

*Every focal variable must be a predictor in at least one model
local mecbadv ""
foreach mectk of local list_ivs {
	local mecfound = 0
	foreach mecm of local mecinmods {
		if "`mecm'" == "`mectk'"  local mecfound = 1
		}
	if `mecfound' == 0  local mecbadv "`mecbadv' `mectk'"
	}
if "`mecbadv'" != "" {
	di _newline(1)
	local mecinmods : list uniq mecinmods	// dedupe/clean for the message
	di as err "{bf:`mecbadv'} is not a predictor in the model(s) given in " /*
	*/ "{opt models( )}. {cmd:mecompare} calculates marginal effects only " /*
	*/ "for variables in the model(s); the predictors available are: " /*
	*/ "{it:`mecinmods'}."
	exit 111
	}

*Refuse only an at() mixing variables a model has and lacks, or a fixed/grouping variable absent from one model
if `s2spec1' == 1 | `s2spec2' == 1 {
	local mecnotboth ""
	foreach mectk of local list_ivs {
		local in1 = 0
		local in2 = 0
		foreach mecm of local mecfull1 {
			if "`mecm'" == "`mectk'"  local in1 = 1
			}
		foreach mecm of local mecfull2 {
			if "`mecm'" == "`mectk'"  local in2 = 1
			}
		if `nummods' == 2 & (`in1' == 0 | `in2' == 0) ///
			local mecnotboth "`mecnotboth' `mectk'"
		}
	*covariates()/by()/over() variables ride inside every at()
	local mecfixvars ""
	foreach mectk of local covspec {
		local meceq = strpos("`mectk'", "=")
		if `meceq' {
			local mecfx = substr("`mectk'", 1, `meceq' - 1)
			local mecfixvars "`mecfixvars' `mecfx'"
			}
		}
	if "`byvars'" != ""  local mecfixvars "`mecfixvars' `byvars'"
	if "`covlistvar'" != ""  local mecfixvars "`mecfixvars' `covlistvar'"
	local mecfixnotboth ""
	foreach mectk of local mecfixvars {
		*Compare base-stripped names on both sides
		local mectkb = subinstr("`mectk'", "i.", "", .)
		local mectkb = subinstr("`mectkb'", "c.", "", .)
		local in1 = 0
		local in2 = 0
		foreach mecm of local mecfull1 {
			local mecmb = regexr("`mecm'","^i(b[0-9]+|bn)?\.","")
			if "`mecmb'" == "`mectkb'"  local in1 = 1
			}
		foreach mecm of local mecfull2 {
			local mecmb = regexr("`mecm'","^i(b[0-9]+|bn)?\.","")
			if "`mecmb'" == "`mectkb'"  local in2 = 1
			}
		if `nummods' == 2 & (`in1' == 0 | `in2' == 0) ///
			local mecfixnotboth "`mecfixnotboth' `mectk'"
		}
	if "`mecfixnotboth'" != "" {
		di _newline(1)
		di as err "{bf:`mecfixnotboth'} is fixed by " /*
		*/ "{opt covariates()}/{opt by()}/{opt over()} but is not a " /*
		*/ "predictor in BOTH models. For {cmd:`cmd1'} models every " /*
		*/ "fixed or grouping variable must appear in both."
		exit 111
		}
	if "`mecnotboth'" != "" & trim("`mecfixvars'") != "" {
		di _newline(1)
		di as err "{bf:`mecnotboth'} is not a predictor in BOTH models. " /*
		*/ "For {cmd:`cmd1'} models this comparison is supported, but not " /*
		*/ "combined with {opt covariates()}, {opt by()}, or {opt over()}: " /*
		*/ "the fixed values cannot be applied inside the model that lacks " /*
		*/ "{bf:`mecnotboth'}."
		di as err "Drop those options, or refit the models with the same " /*
		*/ "predictors."
		exit 111
		}
	if "`mecnotboth'" != "" {
		local mecnb = trim("`mecnotboth'")
		if wordcount("`mecnb'") == wordcount("`list_ivs'") {
			di _newline(1)
			di as err "None of the requested variables ({bf:`mecnb'}) is a " /*
			*/ "predictor in BOTH models, so there is no cross-model " /*
			*/ "comparison to make. Run the model that contains them " /*
			*/ "alone instead."
			exit 111
			}
		di as text "Note: {bf:`mecnotboth'} is not a predictor in both " /*
		*/ "models; its marginal effect is shown only for the model " /*
		*/ "that contains it, and no cross-model difference is reported " /*
		*/ "for it."
		}
	}

foreach var in `list_ivs' {		
	fvexpand `var'
	local numcategs : word count `r(varlist)' 
		if `numcategs' == 1 {
			local 	contvars "`contvars' `var'"		
			}
		}
local cnum = 1 	
local numamounts : word count `amount'
local numcontvars : word count `contvars'
if `numamounts' > 1 & `numamounts' != `numcontvars' {
	di as err "Incorrect specification in {opt amount( )} option. Either " /*
	*/ "specify only one amount which is used for all of the continuous " /*
	*/ "independent variables or specify an equal number of amounts as " /*
	*/ "continuous variables. There are `numcontvars' continuous variables: " /*
	*/ "{it:`contvars'} -- but `numamounts' amounts specified in {opt amount( )}"
	exit 198
	}

local mrgspec " "	
local numvars : word count `list_ivs'

forvalues i = 1/`numvars' {

	local 	v : word `i' of `list_ivs'
*	The variable's position in its own list; keys the per-variable macros
	local 	vnum = `i'
	fvexpand `v' `meclevif'
	local 	numcats : word count `r(varlist)' 
	local 	vbase = regexr("`v'", "^(c|i(b[0-9]+|bn)?)\.", "")
	if "`stlistvar'" != "" & "`vbase'" == "`stlistvar'" & `numcats' != 1 {
		di _newline(1)
		di as err "{bf:`stlistvar'} carries a value list in {opt start()} but is " /*
		*/ "not a continuous focal variable. {opt start()} lists apply to " /*
		*/ "continuous variables; a nominal moderator takes {opt by()}."
		exit 198
		}

*A factor needs two levels in the estimation sample; count==0 means the sample could not be read, so proceed
	local mecfvbase = regexr("`v'", "^(i(b[0-9]+|bn)?|[0-9]+(b|bn|o))\.", "")
	if "`mecfvbase'" != "`v'" {
		capture qui levelsof `mecfvbase' if `mec_sample' == 1, local(meconelv)
		if _rc == 0 {
			local mecnlev : word count `meconelv'
			if `mecnlev' == 1 {
				di _newline(1)
				di as err "{bf:`mecfvbase'} has only one level in the " /*
				*/ "estimation sample, so it has no contrast to " /*
				*/ "compare. {cmd:mecompare} needs a factor variable " /*
				*/ "to have at least two levels. Check any {cmd:if} " /*
				*/ "condition and the samples of the models given in " /*
				*/ "{opt models( )}."
				exit 198
				}
			}
		}

// Continuous IVs //
if `numcats' == 1 {

	if `numamounts' == 0 {		// default to 1
		local amount`cnum' "one"
		}	
	if `numamounts' == 1 {
		local amount`cnum' : word 1 of `amount' 
		}
	if `numamounts' > 1 {
		local amount`cnum' : word `cnum' of `amount' 
		}
	
	*accept amount keywords case-insensitively (SD=sd; 2sd/2SD=twosd)
	local amount`cnum' = lower("`amount`cnum''")
	if "`amount`cnum''" == "2sd" local amount`cnum' = "twosd"
	
	*need to remove = so that, e.g. age=50 and age = 50 are treated same
	local start 		= subinstr("`start'", "=", " ", .) 
	*Exact token match when reading start() values
	local hasiv 		: list posof "`v'" in start
	local hasatmeans 	: list posof "atmeans" in start

	*rate/slope/dydx: tiny centered step h; ME divided by h below to approximate the derivative
	local israte`i' = 0
	local istwosd`i' = 0
	local istrim`i' = 0
	local preset`i' = 0
	local isgroupsd`i' = 0
	if inlist("`amount`cnum''", "rate", "slope", "dydx") {
		local israte`i' = 1
		local preset`i' = 1
		_mec_misum `v' if `mec_sample' == 1, mi(`ismi') wspec(`sdwspec')
		local rmax = r(max)
		local rmin = r(min)
		local rmean = r(mean)
		local rateh`i' = (`rmax' - `rmin') / 1000
		local rh2 = `rateh`i'' / 2
		if `hasiv' == 0 & `hasatmeans' == 0 {
			local startval "`v'=gen(`v' - `rh2')"
			local endval   "`v'=gen(`v' + `rh2')"
			}
		else if `hasiv' == 0 & `hasatmeans' != 0 {
			local rsa = `rmean' - `rh2'
			local rea = `rmean' + `rh2'
			local startval "`v'=`rsa'"
			local endval   "`v'=`rea'"
			}
		else {
			local wherevar : list posof "`v'" in start
			local whereval = `wherevar' + 1
			local startnum : word `whereval' of `start'
			local rsa = `startnum' - `rh2'
			local rea = `startnum' + `rh2'
			local startval "`v'=`rsa'"
			local endval   "`v'=`rea'"
			}
		}
	else if "`amount`cnum''" == "twosd" {
		local istwosd`i' = 1
		if "`centered'" == "" local warn_twosd = 1
		_mec_misum `v' if `mec_sample' == 1, mi(`ismi') wspec(`sdwspec')
		local amount`cnum' = 2 * r(sd)
		}
	else if "`amount`cnum''" == "trimrange" {
		local istrim`i' = 1
		local preset`i' = 1
		_mec_mipct `v' if `mec_sample' == 1, p(5 95) mi(`ismi') wspec(`sdwspec')
		local p5 = r(r1)
		local p95 = r(r2)
		local startval "`v'=`p5'"
		local endval   "`v'=`p95'"
		}
	else if "`groups'" != "" & "`groupsd'" != "" & "`amount`cnum''" == "sd" {
		*groupsd: each group uses its own SD and mean
		local isgroupsd`i' = 1
		local preset`i' = 1
		qui sum `v' if `mecgsamp' == 1
		local gsd1 = r(sd)
		local gmn1 = r(mean)
		qui sum `v' if `mecgsamp' == 2
		local gsd2 = r(sd)
		local gmn2 = r(mean)
		local gh1 = `gsd1' / 2
		local gh2 = `gsd2' / 2
		if `hasiv' == 0 & `hasatmeans' == 0 {
			if "`centered'" != "" {
				local gsda1 "`v'=gen(`v' - `gh1')"
				local gsda2 "`v'=gen(`v' + `gh1')"
				local gsda3 "`v'=gen(`v' - `gh2')"
				local gsda4 "`v'=gen(`v' + `gh2')"
				}
			else {
				local gsda1 "`v'=gen(`v')"
				local gsda2 "`v'=gen(`v' + `gsd1')"
				local gsda3 "`v'=gen(`v')"
				local gsda4 "`v'=gen(`v' + `gsd2')"
				}
			}
		else if `hasiv' == 0 & `hasatmeans' != 0 {
			if "`centered'" != "" {
				local s1 = `gmn1' - `gh1' 
				local e1 = `gmn1' + `gh1' 
				local s2 = `gmn2' - `gh2' 
				local e2 = `gmn2' + `gh2' 
				}
			else {
				local s1 = `gmn1' 
				local e1 = `gmn1' + `gsd1' 
				local s2 = `gmn2' 
				local e2 = `gmn2' + `gsd2' 
				}
			local gsda1 "`v'=`s1'"
			local gsda2 "`v'=`e1'"
			local gsda3 "`v'=`s2'"
			local gsda4 "`v'=`e2'"
			}
		else {
			local wherevar : list posof "`v'" in start
			local whereval = `wherevar' + 1
			local startnum : word `whereval' of `start'
			if "`centered'" != "" {
				local s1 = `startnum' - `gh1' 
				local e1 = `startnum' + `gh1' 
				local s2 = `startnum' - `gh2' 
				local e2 = `startnum' + `gh2' 
				}
			else {
				local s1 = `startnum' 
				local e1 = `startnum' + `gsd1' 
				local s2 = `startnum' 
				local e2 = `startnum' + `gsd2' 
				}
			local gsda1 "`v'=`s1'"
			local gsda2 "`v'=`e1'"
			local gsda3 "`v'=`s2'"
			local gsda4 "`v'=`e2'"
			}
		local gsd_atspec`i' "at(`covspec' `gsda1') at(`covspec' `gsda2')"
		local gsd_atspec`i' "`gsd_atspec`i'' at(`covspec' `gsda3') at(`covspec' `gsda4')"
		}
		
	if `hasiv' == 0  & `hasatmeans' == 0 & `preset`i'' == 0 {	// as observed
		if "`amount`cnum''" == "sd" {
			_mec_misum `v' if `mec_sample' == 1, mi(`ismi') wspec(`sdwspec')
			local sd = r(sd)
			local halfsd = `sd' / 2
			}
		_mec_atvals, var(`v') amount("`amount`cnum''") /*
			*/ sd("`sd'") halfsd("`halfsd'") `centered'
		local startval "`r(startval)'"
		local endval   "`r(endval)'"
		}
	
	if `hasiv' == 0 & `hasatmeans' != 0 & `preset`i'' == 0 {	// start at mean
		_mec_misum `v' if `mec_sample' == 1, mi(`ismi') wspec(`sdwspec')
		local meanv = r(mean)
		local sd = r(sd)
		local halfsd = `sd' / 2
		_mec_atvals, var(`v') amount("`amount`cnum''") base(`meanv') /*
			*/ sd("`sd'") halfsd("`halfsd'") `centered'
		local startval "`r(startval)'"
		local endval   "`r(endval)'"
		}
	
	if `hasiv'!= 0 & `preset`i'' == 0 {	// start at a specified value
		local wherevar : list posof "`v'" in start
		local whereval = `wherevar' + 1
		local startnum : word `whereval' of `start'
		_mec_misum `v' if `mec_sample' == 1, mi(`ismi') wspec(`sdwspec')
		local sd = r(sd)
		local halfsd = `sd' / 2
		_mec_atvals, var(`v') amount("`amount`cnum''") base(`startnum') /*
			*/ sd("`sd'") halfsd("`halfsd'") `centered'
		local startval "`r(startval)'"
		local endval   "`r(endval)'"
		}
	*start() value list: one (start, end) pair per base; every other variable has one pair
	local nsl`i' = 1
	local startval_1 "`startval'"
	local endval_1 "`endval'"
	if "`stlistvar'" != "" & "`vbase'" == "`stlistvar'" {
		if `istrim`i'' == 1 | `isgroupsd`i'' == 1 {
			di _newline(1)
			di as err "A value list in {opt start()} cannot be combined with " /*
			*/ "{opt amount(trimrange)} or {opt groupsd}."
			exit 198
			}
		local stlistseen = 1
		local nsl`i' = `nstlist'
		if `israte`i'' == 0 {
			_mec_misum `v' if `mec_sample' == 1, mi(`ismi') wspec(`sdwspec')
			local sd = r(sd)
			local halfsd = `sd' / 2
			}
		forvalues ks = 1/`nstlist' {
			local sbk : word `ks' of `stlistvals'
			if `israte`i'' == 1 {
				local rsa = `sbk' - `rh2'
				local rea = `sbk' + `rh2'
				local startval_`ks' "`v'=`rsa'"
				local endval_`ks'   "`v'=`rea'"
				}
			else {
				_mec_atvals, var(`v') amount("`amount`cnum''") base(`sbk') /*
					*/ sd("`sd'") halfsd("`halfsd'") `centered'
				local startval_`ks' "`r(startval)'"
				local endval_`ks'   "`r(endval)'"
				}
			}
		}
	*Set labels for table
	if "`centered'" != "" {
		local centerlab ""
		}
	if "`centered'" == "" {
		local centerlab " (uncentered)"
		}
	if `istrim`i'' == 1 {
		local change`vnum' "`v' (5-95%)"
		}
	else if `israte`i'' == 1 {
		local change`vnum' "`v' (rate)"
		}
	else if `istwosd`i'' == 1 {
		local change`vnum' "`v' + 2SD`centerlab'"
		}
	else if "`amount`cnum''" == "one" {
		local change`vnum' "`v' + 1`centerlab'"
		}
	else if "`amount`cnum''" == "sd" {
		local change`vnum' "`v' + SD`centerlab'"
		}
	else {
		local change`vnum' "`v' + `amount`cnum''`centerlab'"
		}	
	if `isgroupsd`i'' == 1 {
		local mspec`i' "`gsd_atspec`i''"
		}
	else {	// one (start, end) pair per cell and per start() base; cells outer
		local mspec`i' ""
		forvalues bc = 1/`nbocells' {
			forvalues ks = 1/`nsl`i'' {
				local mspec`i' "`mspec`i'' at(`covspec' `boat_`bc'' `startval_`ks'') at(`covspec' `boat_`bc'' `endval_`ks'')"
				}
			}
		}
	local 	++cnum	
	}	

*Binary vars use at() so predictions stay separate when continuous vars are also specified
if `numcats' == 2 {
	local 	fv = strpos("`v'", ".") + 1 	// find where . is
	local 	varname = substr("`v'",`fv',.) 	// strip fv prefix
	qui 	levelsof `varname' `meclevif', local(levels)
	local 	lbe : value label `varname'
	local 	numlbe = strlen("`lbe'")	// store whether value labels exist
	local 	catsnom = "`r(levels)'"
	local mspec`i' ""	// one at() per cell (by() level x covariates() value)
	forvalues bc = 1/`nbocells' {
		local mspec`i' "`mspec`i'' at(`covspec' `boat_`bc'' `varname'=(`catsnom'))"
		}
	
	local totcats : word count `levels'
	forvalues h = 1/`totcats' {
		local q : word `h' of `levels'
		local q`h' = `q'
		if `numlbe' == 0 {
			local c`h' = `q'	// store category # if no value label
			}
		else {
			local tempc`h' : label `lbe' `q'
			local numtempc`h' = strlen("`tempc`h''")
			local c`h' = substr("`tempc`h''",1,8) // truncate value label
		}
	}
	local change`vnum' "`c2' - `c1'"
}

*Nominal vars (3+ categories)
if `numcats' >= 3 {
	qui 	fvexpand `v' `meclevif'
*Read the base level from the #b. token
	local 	fvlist "`r(varlist)'"
	local 	basenum ""
	foreach mectk of local fvlist {
		if regexm("`mectk'","^([0-9]+)b\.")  local basenum = regexs(1)
		}
	if "`basenum'" == "" {		// ibn. (no base): use the first level
		local mectk : word 1 of `fvlist'
		local basenum = substr("`mectk'",1,strpos("`mectk'",".")-1)
		}
	local 	fv = strpos("`v'", ".") + 1 	// find where . is
	local 	varname = substr("`v'",`fv',.) 	// strip fv prefix
	qui 	levelsof `varname' `meclevif', local(levels)
	local 	lbe : value label `varname'
	local 	numlbe = strlen("`lbe'")	// store whether value labels exist	
	local 	catsnom = "`r(levels)'"
	local 	catsnob = subinstr("`catsnom'", "`basenum'", "", 1) // remove base	
	local 	catspred = "`basenum' `catsnob'" // make base 1st prediction
	local mspec`i' ""	// one at() per cell (by() level x covariates() value)
	forvalues bc = 1/`nbocells' {
		local mspec`i' "`mspec`i'' at(`covspec' `boat_`bc'' `varname'=(`catspred'))"
		}
	
	local totcats : word count `catspred'
	forvalues h = 1/`totcats' {
		local q : word `h' of `catspred'
		local q`h' = `q'
		if `numlbe' == 0 {
			local c`h' = `q'	// store category # if no value label
			}		
		else {
			local tempc`h' : label `lbe' `q'
			local numtempc`h' = strlen("`tempc`h''")
			local c`h' = substr("`tempc`h''",1,10) // truncate value label
			}
		local change`vnum'_`h' "`c`h'' - `c1'"	
		}

	*Contrast list for this nominal var: default = each level vs base; pwcompare = all pairs
	forvalues p = 1/`totcats' {			// value -> position + label lookups
		local vp : word `p' of `catspred'
		local atpos_`vp' = `p'
		local labof_`vp' "`c`p''"
		}
	if "`meinequality'" != "" | "`totalme'" != "" {	// store level positions + shares
		local mcineqL_`vnum' = `totcats'	// (weighted ME inequality needs all
		foreach vp of local levels {		// pairs + proportions, regardless of the pwcompare option).
			local mcineqpos_`vnum'_`vp' = `atpos_`vp''
			}
*Level shares from _mec_share over the analysis sample (each model's own sample under groups)
		local psamp1 "`mec_sample' == 1"
		local psamp2 "`mec_sample' == 1"
		if "`groups'" != "" {
			local psamp1 "`mec_sample' == 1 & `mecgsamp' == 1"
			local psamp2 "`mec_sample' == 1 & `mecgsamp' == 2"
			}
		*Shares = aweighted mean of a level indicator; same weight as the SDs
		forvalues mm = 1/2 {
			foreach vp of local levels {
				mec_share `varname' if `psamp`mm'', level(`vp') /*
					*/ mi(`ismi') wspec(`sdwspec')
				local mcineqn`mm'_`vnum'_`vp' = r(share)
				}
			local mcineqN`mm'_`vnum' = 1
			}
		}
	if "`pwcompare'" != "" {			// all pairs, ordered lower-then-higher
		local nc = 0
		local nlv : word count `levels'
		forvalues li = 1/`nlv' {
			local lov : word `li' of `levels'
			local hstart = `li' + 1
			forvalues hj = `hstart'/`nlv' {
				local hiv : word `hj' of `levels'
				local ++nc
				local mcctrlo_`vnum'_`nc' = `atpos_`lov''
				local mcctrhi_`vnum'_`nc' = `atpos_`hiv''
				local mcctrlab_`vnum'_`nc' "`labof_`hiv'' - `labof_`lov''"
				}
			}
		local mcncontr_`vnum' = `nc'
		}
	else {						// default: each non-base level vs the base
		local nc = `totcats' - 1
		forvalues cc = 1/`nc' {
			local hh = `cc' + 1
			local mcctrlo_`vnum'_`cc' = 1
			local mcctrhi_`vnum'_`cc' = `hh'
			local mcctrlab_`vnum'_`cc' "`change`vnum'_`hh''"
			}
		local mcncontr_`vnum' = `nc'
		}
	}
local mrgspec "`mrgspec' `mspec`i''" 	
}	
if "`stlistvar'" != "" & `stlistseen' == 0 {
	di _newline(1)
	di as err "{bf:`stlistvar'} carries a value list in {opt start()} but is not " /*
	*/ "in the {it:varlist}. {opt start()} sets where a focal variable starts."
	exit 198
	}

*Add atmeans for covariates if requested
local hasatmeans : list posof "atmeans" in covariates	// v0.2.46: exact
if "`covariates'" != "" & `hasatmeans' != 0 {
	local atmeans "atmeans"
	}
else {
	local atmeans " "
	}
	
*over the group sample variable when groups
if "`groups'" != "" {
	local overspec "over(`mecgsamp')"
	}
else if "`over'" != "" {
	local overspec "over(`byvars')"
	}
else {
	local overspec " "
	}
	
// Calculate the predictions with margins //
*One model: native xb; two models under gsem: eta with named equations
if "`predict'" != "" {
	if `nummods' == 1 {
		if `predlin' == 1  local predspec "predict(xb)"
		else               local predspec "predict(`predict')"
		}
	else if "`engine'" == "gsem" {
*Address the equation names mec_gsem returns (clones under a repeated DV)
		local gdv1 "`dv1'"
		local gdv2 "`dv2'"
		if "`mecdv1'" != ""  local gdv1 "`mecdv1'"
		if "`mecdv2'" != ""  local gdv2 "`mecdv2'"
		local predspec "predict(eta outcome(`gdv1')) predict(eta outcome(`gdv2'))"
		}
	else {
*Under suest2 each model keeps its own prediction names; two-selector form
		if `predlin' == 1 {
			local predspec "predict(model(`mod1') xb) predict(model(`mod2') xb)"
			}
		else {
			local predspec "predict(model(`mod1') `predict') predict(model(`mod2') `predict')"
			}
		}
	}

*predict() and mimarginsspec are alternatives; user's when given, predict(default) otherwise
if `ismi' == 1 {
	if `"`predict'`mecexpr'"' != "" {
		local mimarginsspec "errorok esampvaryok"
		}
	else {
		local mimarginsspec "predict(default) errorok esampvaryok"
		}
	}

if "`commands'" != "" {		// show command line if requested
	di _newline(1)
	di as text "margins command is: "
	di as result `"    `marginscmd' `if' `in', `mrgspec' `predspec' `mimarginsspec' `overspec' `atmeans' `marginsopt' post"'
	}

`cmdqui'	`marginscmd' `if' `in', `mrgspec' `predspec' `mimarginsspec' /*
		*/ `overspec' `atmeans' `marginsopt' post  


*What margins says it is predicting, for the table header
local plab1 "`r(predict1_label)'"
local plab2 "`r(predict2_label)'"
if "`plab1'" == ""  local plab1 "`r(predict_label)'"
if "`plab1'" == ""  local plab1 "`e(predict1_label)'"
if "`plab1'" == ""  local plab1 "`e(predict_label)'"
*Under expression() margins leaves every predict label empty and e(expression) holds the text
if "`plab1'" == "" & `"`e(expression)'"' != "" & `"`e(expression)'"' != "predict()"  local plab1 `"`e(expression)'"'

qui est 	store mec_margins	// For use with post-estimation metest

****************************************************************************
// Define the cross-walk from the models/predictions and how margins 
*Label the predictions: #_# = model_outcome; over() appends the group level

if "`groups'" != "" {
	local g1spec = "#1.`mecgsamp'"
	local g2spec = "#2.`mecgsamp'"
*Specialized route: no over() level in the names; the equation encodes the group
	if "`s2spec1'" != "" & `s2spec1' == 1 {
		local g1spec = ""
		local g2spec = ""
		}
	}
else {
	local g1spec = ""
	local g2spec = ""	
	}
if `nummods' == 1 & `mod1cats' == 1 {
	local prnum1_1 = ""
	}
if `nummods' == 2 & `mod1cats' == 1 {
	local prnum1_1 = "1._predict#"
	local prnum2_1 = "2._predict#"
*Specialized stripe labels each model by equation (_b[m1:1bn._at]) instead of N._predict#
	if `s2spec1' == 1 {
		local prnum1_1 = "`mod1':"
		local prnum2_1 = "`mod2':"
		}
	}
if `nummods' == 1 & `mod1cats' != 1 {
	forvalues outc = 1/`mod1cats' {
		local prnum1_`outc' = "`outc'._predict#"
		}
	}
if `nummods' == 2 & `mod1cats' != 1 {
	forvalues outc = 1/`mod1cats' {
		local prnum1_`outc' = "`outc'._predict#"
		local margnum = `outc' + `mod1cats'
		local prnum2_`outc' = "`margnum'._predict#"
		}
*Specialized multi-outcome: each model numbers predicts 1..k inside its own equation
	if `s2spec1' == 1 {
		forvalues outc = 1/`mod1cats' {
			local prnum1_`outc' = "`mod1':`outc'._predict#"
			local prnum2_`outc' = "`mod2':`outc'._predict#"
			}
		}
	*groups with a multi-outcome model on this route is not yet verified
	if `s2spec1' == 1 & "`groups'" != "" & `mod1cats' != 1 {
		di _newline(1)
		di as err "{opt groups} is not yet supported for multi-outcome " /*
		*/ "models on this route ({cmd:`cmd1'}). Compare the groups " /*
		*/ "separately for now."
		exit 198
		}
	}	

if `mod1cats' != 1 {	// label DV categories for m/ologit
*With two models every row is labeled from model 1's value labels
	forvalues modnum = 1/`nummods' {
		local lbsrc `dv`modnum'name'
		if `nummods' == 2  local lbsrc `dv1name'
		qui levelsof `lbsrc' if `mec_sample' == 1, local(levels_dv)	// v0.2.45
		qui ds `lbsrc', has(vallabel)
	local m = 1
	if "`r(varlist)'" !=  "" {	// if value labels exist
		local lbe : value label `lbsrc'
		
		foreach outnum of local levels_dv {
			local temp_out_`modnum'_`m' : label `lbe' `outnum'
			local out_`modnum'_`m' = abbrev("`temp_out_`modnum'_`m''",13) 
			local ++m
			}	
		}
	else {	// if no value labels
		foreach outnum of local levels_dv {
			local out_`modnum'_`m' "Outcome `outnum'"
			local ++m
			}
		}	
	}
}

****************************************************************************
// Calculate the Marginal Effects; Loop through each IV; parse type of IV //
*Level scaffolding: one 'level' unless single-model over()
if "`over'" != "" {		// single- or two-model over(): one row set per cell of the over() variables
*Cells grow one variable at a time, first variable slowest, as margins orders over() groups
	local novc = 1
	local ovg_1 ""
	local ovlab_1 ""
	local ovcln_1 ""
	local ovcond_1 ""
	forvalues bk = 1/`nbyvars' {
		local newn = 0
		forvalues c = 1/`novc' {
			foreach lv of local bylev_`bk' {
				local ++newn
				local ovgN_`newn' "`ovg_`c''#`lv'.`byv_`bk''"
				if "`bylabn_`bk''" != "" {
					local tmplab : label `bylabn_`bk'' `lv'
					local tmplab = abbrev("`tmplab'", 13)
					}
				else  local tmplab "`byv_`bk''=`lv'"
				local ovlabN_`newn' = trim("`ovlab_`c'' `tmplab'")
				local lvtok = strtoname("`byv_`bk''_`lv'")
				if "`ovcln_`c''" == ""  local ovclnN_`newn' "`lvtok'"
				else  local ovclnN_`newn' "`ovcln_`c''_`lvtok'"
				local ovcondN_`newn' "`ovcond_`c'' & `byv_`bk'' == `lv'"
				}
			}
		local novc = `newn'
		forvalues c = 1/`novc' {
			local ovg_`c' "`ovgN_`c''"
			local ovlab_`c' "`ovlabN_`c''"
			local ovcln_`c' "`ovclnN_`c''"
			local ovcond_`c' "`ovcondN_`c''"
			}
		}
*A combination with no observations in the sample has no margins group and no column: it is dropped
	local mecocond "`meclevif'"
	if "`mecocond'" == ""  local mecocond "if 1"
	local bo_j = 0
	forvalues c = 1/`novc' {
		local ovkeep = 1
		if `nbyvars' > 1 {
			qui count `mecocond' `ovcond_`c''
			if r(N) == 0  local ovkeep = 0
			}
		if `ovkeep' {
			local ++bo_j
			local bog1_`bo_j' "`ovg_`c''"
			local bog2_`bo_j' "`ovg_`c''"	// models split by _predict, not over
			local bymult_`bo_j' = 0			// over() reuses _at positions (no shift)
			local bolab_`bo_j' "`ovlab_`c''"
			local bocln_`bo_j' "`ovcln_`c''"
			}
		}
	local nlev_me = `bo_j'
	}
else if "`by'`covlistvar'" != "" {	// by()/covariates() cells: counterfactual via at(); the _at
	local nlev_me = `nbocells'	// positions repeat per cell, so the ME reads a shifted index
	forvalues bo_j = 1/`nbocells' {
		local bog1_`bo_j' ""
		local bog2_`bo_j' ""
		local bymult_`bo_j' = `bo_j' - 1	// shift = (cell-1) * (#at per cell)
		local bolab_`bo_j' "`bolabc_`bo_j''"
		local bocln_`bo_j' "`boclnc_`bo_j''"
		}
	}
else {
	local nlev_me = 1
	local bog1_1 "`g1spec'"
	local bog2_1 "`g2spec'"
	local bymult_1 = 0
	local bolab_1 "`mod1lab'"
	local bocln_1 "`mod1lab'"
	}
local 		atnum1 = 1 // determines where in table each pred is
local 		atnum2 = 2
local 		me_num = 1 	// ME numbering that metest reads

*v0.2.35 totalme scope guard (two-model and by/over are being added).

*capture variable + model-role for each ME (for eq:coef names)
local MEC_eqn ""
local MEC_rol ""
local MEC_lev ""
local MEC_ctr ""
qui mec_mlincom, clear
forvalues i = 1/`numvars' {
	local var : word `i' of `list_ivs'
*	The variable's position in its own list; keys the per-variable macros
	local vnum = `i'
*Exact membership test, not substring
	local inm1 = 0
	local inm2 = 0
	foreach mectok of local list_ivs1 {
		if "`mectok'" == "`var'"  local inm1 = 1
		}
	foreach mectok of local list_ivs2 {
		if "`mectok'" == "`var'"  local inm2 = 1
		}
	fvexpand `var' `meclevif'
	local numcats : word count `r(varlist)' 
	
	local rpre ""
	local rsuf ""
	*for groupsd continuous vars, model 2 reads its own group's SD
	local m2a1 = `atnum1'
	local m2a2 = `atnum2'
	if "`isgroupsd`i''" == "1" {
		local m2a1 = `atnum1' + 2
		local m2a2 = `atnum2' + 2
		}
	*Continuous IVs
	if `numcats' == 1 {
		local nc_at = 2		// by(): #at positions per level for a continuous var
		*start() value list: rows are cell x base, bases inner; each row is its own 2-at() block
		local nlev_me0 = `nlev_me'
		if `nsl`i'' > 1 {
			forvalues bo = 1/`nlev_me0' {
				local bog1s_`bo' "`bog1_`bo''"
				local bog2s_`bo' "`bog2_`bo''"
				local bymults_`bo' = `bymult_`bo''
				local bolabs_`bo' "`bolab_`bo''"
				local boclns_`bo' "`bocln_`bo''"
				}
			local xn = 0
			forvalues bo = 1/`nlev_me0' {
				forvalues ks = 1/`nsl`i'' {
					local ++xn
					local sbk : word `ks' of `stlistvals'
					local stok = strtoname("at`sbk'")
					local bog1x_`xn' "`bog1s_`bo''"
					local bog2x_`xn' "`bog2s_`bo''"
					if `nlev_me0' > 1 {
						local bolabx_`xn' "`bolabs_`bo'' at `sbk'"
						local boclnx_`xn' "`boclns_`bo''_`stok'"
						}
					else {
						local bolabx_`xn' "at `sbk'"
						local boclnx_`xn' "`stok'"
						}
					}
				}
			local nlev_me = `xn'
			forvalues c = 1/`xn' {
				local bog1_`c' "`bog1x_`c''"
				local bog2_`c' "`bog2x_`c''"
				local bymult_`c' = `c' - 1
				local bolab_`c' "`bolabx_`c''"
				local bocln_`c' "`boclnx_`c''"
				}
			}
	
		*for rate vars, wrap the ME and divide by the step h
		if `israte`i'' == 1 {
			local rpre "("
			local rsuf ")/`rateh`i''"
			}
	
		*Total ME summary row = sum over outcomes of |ME| / div
		if "`totalme'" != "" {
			qui est restore mec_margins
			local varname = "`var'"
			local sectitle "`change`vnum''"
			local totdiv = cond(`mod1cats' > 1, 2, 1)
			local totsub = 0
			if `nummods' == 2 | `nlev_me' > 1  local totsub = 1
			forvalues bo = 1/`nlev_me' {	// per by/over level
				local m1e_`bo' 0
				local m2e_`bo' 0
				local a1 = `atnum1' + `bymult_`bo''*`nc_at'
				local a2 = `atnum2' + `bymult_`bo''*`nc_at'
				local am1 = `m2a1' + `bymult_`bo''*`nc_at'
				local am2 = `m2a2' + `bymult_`bo''*`nc_at'
				forvalues oo = 1/`mod1cats' {
					local dh = _b[`prnum1_`oo''`a2'._at`bog1_`bo''] - _b[`prnum1_`oo''`a1'._at`bog1_`bo'']
					local sg = cond(`dh' < 0, -1, 1)
					local m1e_`bo' `m1e_`bo'' + `sg'* ///
						(_b[`prnum1_`oo''`a2'._at`bog1_`bo''] - _b[`prnum1_`oo''`a1'._at`bog1_`bo''])
					if `nummods' == 2 {
						local dh2 = _b[`prnum2_`oo''`am2'._at`bog2_`bo''] - _b[`prnum2_`oo''`am1'._at`bog2_`bo'']
						local sg2 = cond(`dh2' < 0, -1, 1)
						local m2e_`bo' `m2e_`bo'' + `sg2'* ///
							(_b[`prnum2_`oo''`am2'._at`bog2_`bo''] - _b[`prnum2_`oo''`am1'._at`bog2_`bo''])
						}
					}
				}
			if `totsub' == 1 {		// "Total ME" subheader
				if `i' == 1 & "`meineqinit'`totmeinit'" == "" {
					qui mlincom 1, stat(`stats')
					_mec_addz, matrix(_mlincom) rowname("`sectitle':{it}Total ME    ") top
					mat tempmat = _mlincom
					_mec_matselrc tempmat _mlincom, row(1)
					}
				else  _mec_addz, matrix(_mlincom) rowname("`sectitle':{it}Total ME    ")
				}
			if `nummods' == 1 {		// one model: one Total ME per level
				forvalues bo = 1/`nlev_me' {
					local mexp`me_num' `rpre'(`m1e_`bo'')`rsuf'/`totdiv'
					if `totsub' == 0  qui mec_mlincom `mexp`me_num'', add rowname(`sectitle':Total ME) stat(`stats')
					else              qui mec_mlincom `mexp`me_num'', add rowname(`sectitle':{sf}`=substr("`bolab_`bo''",1,28)') stat(`stats')
					local MEC_eqn "`MEC_eqn' `var'"
					local MEC_rol "`MEC_rol' `rkey1'"
					if `nlev_me' > 1  local MEC_lev "`MEC_lev' `bocln_`bo''"
					else              local MEC_lev "`MEC_lev' ."
					local MEC_ctr "`MEC_ctr' TotME"
					local ++me_num
					}
				}
			else {				// two models: m1, m2, Difference per level
				forvalues bo = 1/`nlev_me' {
					if `nlev_me' > 1  local Lt "`mod1lab' `bolab_`bo''"
					else              local Lt "`mod1lab'"
					local Lt = substr("`Lt'", 1, 28)
					local mexp`me_num' `rpre'(`m1e_`bo'')`rsuf'/`totdiv'
					qui mec_mlincom `mexp`me_num'', add rowname(`sectitle':{sf}`Lt') stat(`stats')
					local MEC_eqn "`MEC_eqn' `var'"
					local MEC_rol "`MEC_rol' `rkey1'"
					if `nlev_me' > 1  local MEC_lev "`MEC_lev' `bocln_`bo''"
					else              local MEC_lev "`MEC_lev' ."
					local MEC_ctr "`MEC_ctr' TotME"
					local ++me_num
					}
				forvalues bo = 1/`nlev_me' {
					if `nlev_me' > 1  local Lt "`mod2lab' `bolab_`bo''"
					else              local Lt "`mod2lab'"
					local Lt = substr("`Lt'", 1, 28)
					local mexp`me_num' `rpre'(`m2e_`bo'')`rsuf'/`totdiv'
					qui mec_mlincom `mexp`me_num'', add rowname(`sectitle':{sf}`Lt') stat(`stats')
					local MEC_eqn "`MEC_eqn' `var'"
					local MEC_rol "`MEC_rol' `rkey2'"
					if `nlev_me' > 1  local MEC_lev "`MEC_lev' `bocln_`bo''"
					else              local MEC_lev "`MEC_lev' ."
					local MEC_ctr "`MEC_ctr' TotME"
					local ++me_num
					}
				forvalues bo = 1/`nlev_me' {
					if `nlev_me' > 1  local Lt "Difference `bolab_`bo''"
					else              local Lt "Difference"
					local Lt = substr("`Lt'", 1, 28)
					local mexp`me_num' `rpre'(`m1e_`bo'')`rsuf'/`totdiv' - `rpre'(`m2e_`bo'')`rsuf'/`totdiv'
					qui mec_mlincom `mexp`me_num'', add rowname(`sectitle':{sf}`Lt') stat(`stats')
					local MEC_eqn "`MEC_eqn' `var'"
					local MEC_rol "`MEC_rol' `rkeyD'"
					if `nlev_me' > 1  local MEC_lev "`MEC_lev' `bocln_`bo''"
					else              local MEC_lev "`MEC_lev' ."
					local MEC_ctr "`MEC_ctr' TotME"
					local ++me_num
					}
				}
			if `i' == 1  local totmeinit = 1
			}
	
		forvalues o = 1/`mod1cats' {
	
	_mec_catlabs, ncats(`mod1cats') out1("`out_1_`o''") out2("`out_2_`o''")
	local cat1name "`r(cat1name)'"
	local cat2name "`r(cat2name)'"
	local catDname "`r(catDname)'"
	
	local varname = "`var'"
	local sectitle "`change`vnum''"	
	
	*---- model 1 marginal effect (looped over over() levels) ----
	forvalues bo = 1/`nlev_me' {
	if `nummods' == 2 & `nlev_me' > 1  local L1 "`mod1lab' `bolab_`bo''"
	else                               local L1 "`bolab_`bo''"
*Cap the display row name (Stata rejects an over-long one)
	local _lv ""
	if `nummods' == 2 & `nlev_me' > 1  local _lv "`bolab_`bo''"
	local _md "`mod1lab'"
	if `nummods' == 1  local _md "`bolab_`bo''"	// one model: the level labels the row
	_mec_rowlab, cat("`cat1name'") mod("`_md'") lev("`_lv'") /*
		*/ width(`=`twidth' - 2')
	local _rn1 "`r(lab)'"
	local R1 "`rkey1'"		// MEC_rol = pure model role; level -> MEC_lev
	if `inm1' > 0 | `nummods' == 1 {		// If var is in model 1
		local a1 = `atnum1' + `bymult_`bo''*`nc_at'	// by() shifts the _at index
		local a2 = `atnum2' + `bymult_`bo''*`nc_at'	//   per level; 0 for over/none
		local mexp`me_num' `rpre'(_b[`prnum1_`o''`a2'._at`bog1_`bo''] - ///
							 _b[`prnum1_`o''`a1'._at`bog1_`bo''])`rsuf'
		qui mec_mlincom `mexp`me_num'', ///
			add rowname(`sectitle':`_rn1') stat(`stats') 
		local MEC_eqn "`MEC_eqn' `var'"
		local MEC_rol "`MEC_rol' `R1'"
		if `nlev_me' > 1  local MEC_lev "`MEC_lev' `bocln_`bo''"
		else              local MEC_lev "`MEC_lev' ."
		local MEC_ctr "`MEC_ctr' ."
		local ++me_num
		}
	else if `nummods' == 2 {
		capture confirm matrix _mlincom
		if _rc {		// first table row: a faux mlincom gives the blank row its columns
			qui mlincom 1, stat(`stats')
			_mec_addz, matrix(_mlincom) rowname("`sectitle':`_rn1'") top
			mat tempmat = _mlincom
			_mec_matselrc tempmat _mlincom, row(1)
			}
		else  _mec_addz, matrix(_mlincom) rowname("`sectitle':`_rn1'")
		}
	}
	*---- model 2 marginal effect ----
	forvalues bo = 1/`nlev_me' {
	if `nlev_me' > 1  local L2 "`mod2lab' `bolab_`bo''"
	else              local L2 "`mod2lab'"
	local _lv ""
	if `nlev_me' > 1  local _lv "`bolab_`bo''"
	_mec_rowlab, cat("`cat2name'") mod("`mod2lab'") lev("`_lv'") /*
		*/ width(`=`twidth' - 2')
	local _rn2 "`r(lab)'"
	local R2 "`rkey2'"
	if `inm2' > 0 & `nummods' == 2 {		// If var is in model 2
		local am1 = `m2a1' + `bymult_`bo''*`nc_at'	// by() shifts model-2 _at index
		local am2 = `m2a2' + `bymult_`bo''*`nc_at'
		local mexp`me_num' `rpre'(_b[`prnum2_`o''`am2'._at`bog2_`bo''] - ///
							 _b[`prnum2_`o''`am1'._at`bog2_`bo''])`rsuf'
		qui mec_mlincom `mexp`me_num'', ///
				add rowname(`sectitle':`_rn2') stat(`stats')
		local MEC_eqn "`MEC_eqn' `var'"
		local MEC_rol "`MEC_rol' `R2'"
		if `nlev_me' > 1  local MEC_lev "`MEC_lev' `bocln_`bo''"
		else              local MEC_lev "`MEC_lev' ."
		local MEC_ctr "`MEC_ctr' ."
		local ++me_num
		}
	else if `nummods' == 2 {
		_mec_addz, matrix(_mlincom) rowname("`sectitle':`_rn2'")
		}
	}
	*---- cross-model Difference (var in both models) ----
	forvalues bo = 1/`nlev_me' {
	if `nlev_me' > 1  local LD "Difference `bolab_`bo''"
	else              local LD "Difference"
	local _lv ""
	if `nlev_me' > 1  local _lv "`bolab_`bo''"
	_mec_rowlab, cat("`catDname'") mod("Difference") lev("`_lv'") /*
		*/ width(`=`twidth' - 2')
	local _rnD "`r(lab)'"
	local RD "`rkeyD'"
	if `inm1' > 0 & `inm2' > 0 & `nummods' == 2 {
		local a1  = `atnum1' + `bymult_`bo''*`nc_at'	// by() shifts both models'
		local a2  = `atnum2' + `bymult_`bo''*`nc_at'	//   _at index per level
		local am1 = `m2a1'  + `bymult_`bo''*`nc_at'
		local am2 = `m2a2'  + `bymult_`bo''*`nc_at'
		local mexp`me_num' `rpre'(_b[`prnum1_`o''`a2'._at`bog1_`bo''] - ///
							 _b[`prnum1_`o''`a1'._at`bog1_`bo'']) - ///
							(_b[`prnum2_`o''`am2'._at`bog2_`bo''] - ///
							_b[`prnum2_`o''`am1'._at`bog2_`bo''])`rsuf'
		qui mec_mlincom `mexp`me_num'', ///
			add rowname(`sectitle':`_rnD') stat(`stats') 
		local MEC_eqn "`MEC_eqn' `var'"
		local MEC_rol "`MEC_rol' `RD'"
		if `nlev_me' > 1  local MEC_lev "`MEC_lev' `bocln_`bo''"
		else              local MEC_lev "`MEC_lev' ."
		local MEC_ctr "`MEC_ctr' ."
		local ++me_num	
		}
	else if `nummods' == 2 {
		_mec_addz, matrix(_mlincom) rowname("`sectitle':`_rnD'")
		}
	}
	}
	if "`isgroupsd`i''" == "1" {		// groupsd uses 4 at() per var
		local atnum1 = `atnum1' + 4
		local atnum2 = `atnum2' + 4
		}
	else {
		local bymul = `nbocells' * `nsl`i''	// the var's at() pairs repeat per cell and per base
		local atnum1 = `atnum1' + 2*`bymul'	// advance _at label # in margins table
		local atnum2 = `atnum2' + 2*`bymul'
		}
	if `nsl`i'' > 1 {	// put the cell scaffold back for the next variable
		forvalues bo = 1/`nlev_me0' {
			local bog1_`bo' "`bog1s_`bo''"
			local bog2_`bo' "`bog2s_`bo''"
			local bymult_`bo' = `bymults_`bo''
			local bolab_`bo' "`bolabs_`bo''"
			local bocln_`bo' "`boclns_`bo''"
			}
		local nlev_me = `nlev_me0'
		}
}
	
	*Binary IVs
	if `numcats' == 2 { 
		local nc_at = 2		// by(): #at positions per level for a binary var
			forvalues o = 1/`mod1cats' {
	
	_mec_catlabs, ncats(`mod1cats') out1("`out_1_`o''") out2("`out_2_`o''")
	local cat1name "`r(cat1name)'"
	local cat2name "`r(cat2name)'"
	local catDname "`r(catDname)'"
		
	local 	fv = strpos("`var'", ".") + 1 		// find where . is
	local 	varname = substr("`var'",`fv',.) 	// strip fv prefix
	local	sectitle "`change`vnum''"	

	if `i' == 1 & `o' == 1 {
		*Create a quick faux table to get category label row
		qui mlincom 1, stat(`stats') 
		_mec_addz, matrix(_mlincom) rowname("`varname':{it}`sectitle'    ") top
		mat tempmat = _mlincom
		_mec_matselrc tempmat _mlincom, row(1)
		}
		
	if `i' != 1 & `o' == 1 {
		_mec_addz, matrix(_mlincom) rowname("`varname':{it}`sectitle'    ")
		}
	
	*Total ME summary row (once per var, above the detail rows).
	if "`totalme'" != "" & `o' == 1 {
		qui est restore mec_margins
		local totdiv = cond(`mod1cats' > 1, 2, 1)
		local totsub = 0
		if `nummods' == 2 | `nlev_me' > 1  local totsub = 1
		forvalues bo = 1/`nlev_me' {	// per by/over level
			local m1e_`bo' 0
			local m2e_`bo' 0
			local a1 = `atnum1' + `bymult_`bo''*`nc_at'
			local a2 = `atnum2' + `bymult_`bo''*`nc_at'
			local am1 = `m2a1' + `bymult_`bo''*`nc_at'
			local am2 = `m2a2' + `bymult_`bo''*`nc_at'
			forvalues oo = 1/`mod1cats' {
				local dh = _b[`prnum1_`oo''`a2'._at`bog1_`bo''] - _b[`prnum1_`oo''`a1'._at`bog1_`bo'']
				local sg = cond(`dh' < 0, -1, 1)
				local m1e_`bo' `m1e_`bo'' + `sg'* ///
					(_b[`prnum1_`oo''`a2'._at`bog1_`bo''] - _b[`prnum1_`oo''`a1'._at`bog1_`bo''])
				if `nummods' == 2 {
					local dh2 = _b[`prnum2_`oo''`am2'._at`bog2_`bo''] - _b[`prnum2_`oo''`am1'._at`bog2_`bo'']
					local sg2 = cond(`dh2' < 0, -1, 1)
					local m2e_`bo' `m2e_`bo'' + `sg2'* ///
						(_b[`prnum2_`oo''`am2'._at`bog2_`bo''] - _b[`prnum2_`oo''`am1'._at`bog2_`bo''])
					}
				}
			}
		if `totsub' == 1  _mec_addz, matrix(_mlincom) rowname("`varname':{it}Total ME    ")
		if `nummods' == 1 {		// one model: one Total ME per level
			forvalues bo = 1/`nlev_me' {
				local mexp`me_num' (`m1e_`bo'')/`totdiv'
				if `totsub' == 0  qui mec_mlincom `mexp`me_num'', add rowname(`varname':{sf}Total ME) stat(`stats')
				else              qui mec_mlincom `mexp`me_num'', add rowname(`varname':{sf}`=substr("`bolab_`bo''",1,28)') stat(`stats')
				local MEC_eqn "`MEC_eqn' `varname'"
				local MEC_rol "`MEC_rol' `rkey1'"
				if `nlev_me' > 1  local MEC_lev "`MEC_lev' `bocln_`bo''"
				else              local MEC_lev "`MEC_lev' ."
				local MEC_ctr "`MEC_ctr' TotME"
				local ++me_num
				}
			}
		else {				// two models: m1, m2, Difference per level
			forvalues bo = 1/`nlev_me' {
				if `nlev_me' > 1  local Lt "`mod1lab' `bolab_`bo''"
				else              local Lt "`mod1lab'"
				local Lt = substr("`Lt'", 1, 28)
				local mexp`me_num' (`m1e_`bo'')/`totdiv'
				local _mcrn = substr("`Lt'", 1, 28)
				qui mec_mlincom `mexp`me_num'', add rowname(`varname':{sf}`_mcrn') stat(`stats')
				local MEC_eqn "`MEC_eqn' `varname'"
				local MEC_rol "`MEC_rol' `rkey1'"
				if `nlev_me' > 1  local MEC_lev "`MEC_lev' `bocln_`bo''"
				else              local MEC_lev "`MEC_lev' ."
				local MEC_ctr "`MEC_ctr' TotME"
				local ++me_num
				}
			forvalues bo = 1/`nlev_me' {
				if `nlev_me' > 1  local Lt "`mod2lab' `bolab_`bo''"
				else              local Lt "`mod2lab'"
				local Lt = substr("`Lt'", 1, 28)
				local mexp`me_num' (`m2e_`bo'')/`totdiv'
				local _mcrn = substr("`Lt'", 1, 28)
				qui mec_mlincom `mexp`me_num'', add rowname(`varname':{sf}`_mcrn') stat(`stats')
				local MEC_eqn "`MEC_eqn' `varname'"
				local MEC_rol "`MEC_rol' `rkey2'"
				if `nlev_me' > 1  local MEC_lev "`MEC_lev' `bocln_`bo''"
				else              local MEC_lev "`MEC_lev' ."
				local MEC_ctr "`MEC_ctr' TotME"
				local ++me_num
				}
			forvalues bo = 1/`nlev_me' {
				if `nlev_me' > 1  local Lt "Difference `bolab_`bo''"
				else              local Lt "Difference"
				local Lt = substr("`Lt'", 1, 28)
				local mexp`me_num' (`m1e_`bo'')/`totdiv' - (`m2e_`bo'')/`totdiv'
				local _mcrn = substr("`Lt'", 1, 28)
				qui mec_mlincom `mexp`me_num'', add rowname(`varname':{sf}`_mcrn') stat(`stats')
				local MEC_eqn "`MEC_eqn' `varname'"
				local MEC_rol "`MEC_rol' `rkeyD'"
				if `nlev_me' > 1  local MEC_lev "`MEC_lev' `bocln_`bo''"
				else              local MEC_lev "`MEC_lev' ."
				local MEC_ctr "`MEC_ctr' TotME"
				local ++me_num
				}
			}
		}
		
	*---- model 1 marginal effect (looped over over() levels) ----
	forvalues bo = 1/`nlev_me' {
	if `nummods' == 2 & `nlev_me' > 1  local L1 "`mod1lab' `bolab_`bo''"
	else                               local L1 "`bolab_`bo''"
*Cap the display row name (Stata rejects an over-long one)
	local _lv ""
	if `nummods' == 2 & `nlev_me' > 1  local _lv "`bolab_`bo''"
	_mec_rowlab, cat("`cat1name'") mod("`mod1lab'") lev("`_lv'") /*
		*/ width(`=`twidth' - 2')
	local _rn1 "`r(lab)'"
	local R1 "`rkey1'"		// MEC_rol = pure model role; level -> MEC_lev
	if `inm1' > 0 | `nummods' == 1 {		// If var is in model 1
		local a1 = `atnum1' + `bymult_`bo''*`nc_at'	// by() shifts the _at index
		local a2 = `atnum2' + `bymult_`bo''*`nc_at'	//   per level; 0 for over/none
		local mexp`me_num' `rpre'(_b[`prnum1_`o''`a2'._at`bog1_`bo''] - ///
							 _b[`prnum1_`o''`a1'._at`bog1_`bo''])`rsuf'
		local _mcrn = substr("`cat1name'`L1'", 1, 28)	// coef name <= 32 (with {sf})
		qui mec_mlincom `mexp`me_num'', ///
			add rowname(`varname':{sf}`_mcrn') stat(`stats') 
		local MEC_eqn "`MEC_eqn' `varname'"
		local MEC_rol "`MEC_rol' `R1'"
		if `nlev_me' > 1  local MEC_lev "`MEC_lev' `bocln_`bo''"
		else              local MEC_lev "`MEC_lev' ."
		local MEC_ctr "`MEC_ctr' ."
		local ++me_num
		}
	else if `nummods' == 2 { 
		local _mcrn = substr("`out_1_`o''`L1'", 1, 28)
		_mec_addz, matrix(_mlincom) rowname("`varname':{sf}`_mcrn'")
		}
	}
	*---- model 2 marginal effect ----
	forvalues bo = 1/`nlev_me' {
	if `nlev_me' > 1  local L2 "`mod2lab' `bolab_`bo''"
	else              local L2 "`mod2lab'"
	local _lv ""
	if `nlev_me' > 1  local _lv "`bolab_`bo''"
	_mec_rowlab, cat("`cat2name'") mod("`mod2lab'") lev("`_lv'") /*
		*/ width(`=`twidth' - 2')
	local _rn2 "`r(lab)'"
	local R2 "`rkey2'"
	if `inm2' > 0 & `nummods' == 2 {		// If var is in model 2
		local am1 = `m2a1' + `bymult_`bo''*`nc_at'	// by() shifts model-2 _at index
		local am2 = `m2a2' + `bymult_`bo''*`nc_at'
		local mexp`me_num' `rpre'(_b[`prnum2_`o''`am2'._at`bog2_`bo''] - ///
							 _b[`prnum2_`o''`am1'._at`bog2_`bo''])`rsuf'
		local _mcrn = substr("`cat2name'`L2'", 1, 28)	// coef name <= 32 (with {sf})
		qui mec_mlincom `mexp`me_num'', ///
			add rowname(`varname':{sf}`_mcrn') stat(`stats') 
		local MEC_eqn "`MEC_eqn' `varname'"
		local MEC_rol "`MEC_rol' `R2'"
		if `nlev_me' > 1  local MEC_lev "`MEC_lev' `bocln_`bo''"
		else              local MEC_lev "`MEC_lev' ."
		local MEC_ctr "`MEC_ctr' ."
		local ++me_num	
		}
	else if `nummods' == 2 {
		local _mcrn = substr("`out_2_`o''`L2'", 1, 28)
		_mec_addz, matrix(_mlincom) rowname("`varname':{sf}`_mcrn'")
		}
	}
	*---- cross-model Difference (var in both models) ----
	forvalues bo = 1/`nlev_me' {
	if `nlev_me' > 1  local LD "Difference `bolab_`bo''"
	else              local LD "Difference"
	local _lv ""
	if `nlev_me' > 1  local _lv "`bolab_`bo''"
	_mec_rowlab, cat("`catDname'") mod("Difference") lev("`_lv'") /*
		*/ width(`=`twidth' - 2')
	local _rnD "`r(lab)'"
	local RD "`rkeyD'"
	if `inm1' > 0 & `inm2' > 0 & `nummods' == 2 {
		local a1  = `atnum1' + `bymult_`bo''*`nc_at'	// by() shifts both models'
		local a2  = `atnum2' + `bymult_`bo''*`nc_at'	//   _at index per level
		local am1 = `m2a1'  + `bymult_`bo''*`nc_at'
		local am2 = `m2a2'  + `bymult_`bo''*`nc_at'
		local mexp`me_num' `rpre'(_b[`prnum1_`o''`a2'._at`bog1_`bo''] - ///
							 _b[`prnum1_`o''`a1'._at`bog1_`bo'']) - ///
							(_b[`prnum2_`o''`am2'._at`bog2_`bo''] - ///
							_b[`prnum2_`o''`am1'._at`bog2_`bo''])`rsuf'
		local _mcrn = substr("`catDname'`LD'", 1, 28)	// coef name <= 32 (with {sf})
		qui mec_mlincom `mexp`me_num'', ///
			add rowname(`varname':{sf}`_mcrn') stat(`stats') 
		local MEC_eqn "`MEC_eqn' `varname'"
		local MEC_rol "`MEC_rol' `RD'"
		if `nlev_me' > 1  local MEC_lev "`MEC_lev' `bocln_`bo''"
		else              local MEC_lev "`MEC_lev' ."
		local MEC_ctr "`MEC_ctr' ."
		local ++me_num	
		}
	else if `nummods' == 2 {
		local _mcrn = substr("`catDname'`LD'", 1, 28)
		_mec_addz, matrix(_mlincom) rowname("`varname':{sf}`_mcrn'")
		}
		}		// close forvalues bo (over levels) for Difference
		}		// close forvalues o (DV categories)
	local bymul = `nbocells'		// at() specs repeat per cell
	local atnum1 = `atnum1' + 2*`bymul'	// advance _at label # in margins table
	local atnum2 = `atnum2' + 2*`bymul'
}
	
	*Nominal IVs
	if `numcats' >= 3 {
	local nc_at = `numcats'	// by(): #at positions per level (all IV levels)
	local 	fv = strpos("`var'", ".") + 1 		// find where . is
	local 	varname = substr("`var'",`fv',.) 	// strip fv prefix
	qui 	levelsof `varname' `meclevif', local(levels)
	local 	totcats : word count `levels'
	
	*Weighted ME inequality summary row(s) above the variable's contrasts
	if "`meinequality'" != "" {
		qui est restore mec_margins		// activate predictions for the signs
		local Lc   = `mcineqL_`vnum''
		local Ntot1 = `mcineqN1_`vnum''
		local Ntot2 = `mcineqN2_`vnum''
		local mineqNC = `Lc' * (`Lc' - 1) / 2	// # pairwise comparisons
		if "`meineqtype'" == "all"          local wtypes "weighted unweighted"
		else if "`meineqtype'" == "unweighted"  local wtypes "unweighted"
		else                                local wtypes "weighted"
		foreach wt of local wtypes {		// weighted and/or unweighted
		if "`wt'" == "unweighted" {
			local mineqlab "Unwgt ME Ineq."
			local mtok "MEineqUnw"
			}
		else {
			local mineqlab "ME Inequality"
			local mtok "MEineq"
			}
		local mineqsub = 0			// subheader when >1 ME-inequality row
		if `mod1cats' > 1 | `nummods' == 2 | `nlev_me' > 1  local mineqsub = 1
		if `mineqsub' == 1 {			// add the subheader
			if `i' == 1 & "`meineqinit'`totmeinit'" == "" {	// first table row: faux init
				qui mlincom 1, stat(`stats')
				_mec_addz, matrix(_mlincom) ///
					rowname("`varname':{it}`mineqlab'    ") top
				mat tempmat = _mlincom
				_mec_matselrc tempmat _mlincom, row(1)
				}
			else {
				_mec_addz, matrix(_mlincom) ///
					rowname("`varname':{it}`mineqlab'    ")
				}
			}
		forvalues oo = 1/`mod1cats' {		// one ME inequality per outcome
			if `mod1cats' == 1 {
				local ocat1 ""
				local ocat2 ""
				}
			else {
				local ocat1 "`out_1_`oo'' - "
				local ocat2 "`out_2_`oo'' - "
				}
			*Collect each prediction's net coefficient (same quantity, compact expression)
			tempname MC1 MC2
			forvalues bo = 1/`nlev_me' {	// build per by/over level
				matrix `MC1' = J(1, `Lc', 0)
				matrix `MC2' = J(1, `Lc', 0)
				local si = 0
				foreach va of local levels {
					local ++si
					local pa = `atnum1' + `mcineqpos_`vnum'_`va'' - 1 + `bymult_`bo''*`nc_at'
					local sj = 0
					foreach vb of local levels {
						local ++sj
						if `si' < `sj' {
							local pb = `atnum1' + `mcineqpos_`vnum'_`vb'' - 1 + `bymult_`bo''*`nc_at'
							if "`wt'" == "unweighted" {	// mean of |contrasts|
								local wab1 = 1 / `mineqNC'
								local wab2 = `wab1'
								}
							else {				// (p_a+p_b)/(L-1), each model's own shares
								local wab1 = (`mcineqn1_`vnum'_`va'' + `mcineqn1_`vnum'_`vb'') ///
										/ `Ntot1' / (`Lc' - 1)
								local wab2 = (`mcineqn2_`vnum'_`va'' + `mcineqn2_`vnum'_`vb'') ///
										/ `Ntot2' / (`Lc' - 1)
								}
							local d1 = _b[`prnum1_`oo''`pa'._at`bog1_`bo''] - _b[`prnum1_`oo''`pb'._at`bog1_`bo'']
							local s1 = cond(`d1' < 0, -1, 1)
							matrix `MC1'[1,`si'] = `MC1'[1,`si'] + `wab1'*`s1'
							matrix `MC1'[1,`sj'] = `MC1'[1,`sj'] - `wab1'*`s1'
							if `nummods' == 2 {
								local d2 = _b[`prnum2_`oo''`pa'._at`bog2_`bo''] - _b[`prnum2_`oo''`pb'._at`bog2_`bo'']
								local s2 = cond(`d2' < 0, -1, 1)
								matrix `MC2'[1,`si'] = `MC2'[1,`si'] + `wab2'*`s2'
								matrix `MC2'[1,`sj'] = `MC2'[1,`sj'] - `wab2'*`s2'
								}
							}
						}
					}
				local m1e_`bo' 0
				local m2e_`bo' 0
				local si = 0
				foreach va of local levels {
					local ++si
					local pa = `atnum1' + `mcineqpos_`vnum'_`va'' - 1 + `bymult_`bo''*`nc_at'
					if `MC1'[1,`si'] != 0 {
						local cfm : display %21x (`MC1'[1,`si'])
						local m1e_`bo' `m1e_`bo'' + (`cfm')*_b[`prnum1_`oo''`pa'._at`bog1_`bo'']
						}
					if `nummods' == 2 & `MC2'[1,`si'] != 0 {
						local cfm2 : display %21x (`MC2'[1,`si'])
						local m2e_`bo' `m2e_`bo'' + (`cfm2')*_b[`prnum2_`oo''`pa'._at`bog2_`bo'']
						}
					}
				}
			if `nummods' == 1 {			// one model: m1 row(s), per level
				forvalues bo = 1/`nlev_me' {
					if `nlev_me' > 1  local Lm "`bolab_`bo''"
					else              local Lm "`mod1lab'"
					local mexp`me_num' (`m1e_`bo'')
					if `mineqsub' == 0 {	// one model/one outcome/no by-over
						qui mec_mlincom `mexp`me_num'', ///
							add rowname(`varname':`mineqlab') stat(`stats')
						}
					else {
						local _mcrn = substr("`ocat1'`Lm'", 1, 28)
						qui mec_mlincom `mexp`me_num'', ///
							add rowname(`varname':{sf}`_mcrn') stat(`stats')
						}
					local MEC_eqn "`MEC_eqn' `varname'"
					local MEC_rol "`MEC_rol' `rkey1'"
					if `nlev_me' > 1  local MEC_lev "`MEC_lev' `bocln_`bo''"
					else              local MEC_lev "`MEC_lev' ."
					local MEC_ctr "`MEC_ctr' `mtok'"
					local ++me_num
					}
				}
			else {					// two models: m1, m2, Difference per level
				forvalues bo = 1/`nlev_me' {	// model 1
					if `nlev_me' > 1  local Lm "`mod1lab' `bolab_`bo''"
					else              local Lm "`mod1lab'"
					local mexp`me_num' (`m1e_`bo'')
					local _mcrn = substr("`ocat1'`Lm'", 1, 28)
					qui mec_mlincom `mexp`me_num'', ///
						add rowname(`varname':{sf}`_mcrn') stat(`stats')
					local MEC_eqn "`MEC_eqn' `varname'"
					local MEC_rol "`MEC_rol' `rkey1'"
					if `nlev_me' > 1  local MEC_lev "`MEC_lev' `bocln_`bo''"
					else              local MEC_lev "`MEC_lev' ."
					local MEC_ctr "`MEC_ctr' `mtok'"
					local ++me_num
					}
				forvalues bo = 1/`nlev_me' {	// model 2
					if `nlev_me' > 1  local Lm "`mod2lab' `bolab_`bo''"
					else              local Lm "`mod2lab'"
					local mexp`me_num' (`m2e_`bo'')
					local _mcrn = substr("`ocat2'`Lm'", 1, 28)
					qui mec_mlincom `mexp`me_num'', ///
						add rowname(`varname':{sf}`_mcrn') stat(`stats')
					local MEC_eqn "`MEC_eqn' `varname'"
					local MEC_rol "`MEC_rol' `rkey2'"
					if `nlev_me' > 1  local MEC_lev "`MEC_lev' `bocln_`bo''"
					else              local MEC_lev "`MEC_lev' ."
					local MEC_ctr "`MEC_ctr' `mtok'"
					local ++me_num
					}
				forvalues bo = 1/`nlev_me' {	// cross-model Difference
					if `nlev_me' > 1  local Lm "Difference `bolab_`bo''"
					else              local Lm "Difference"
					local mexp`me_num' ((`m1e_`bo'') - (`m2e_`bo''))
					local _mcrn = substr("`ocat1'`Lm'", 1, 28)
					qui mec_mlincom `mexp`me_num'', ///
						add rowname(`varname':{sf}`_mcrn') stat(`stats')
					local MEC_eqn "`MEC_eqn' `varname'"
					local MEC_rol "`MEC_rol' `rkeyD'"
					if `nlev_me' > 1  local MEC_lev "`MEC_lev' `bocln_`bo''"
					else              local MEC_lev "`MEC_lev' ."
					local MEC_ctr "`MEC_ctr' `mtok'"
					local ++me_num
					}
				}
			}					// end outcome loop
		if `i' == 1  local meineqinit = 1	// after 1st type: skip contrast faux
		}					// end weighting-type loop
		}
	
	*Total ME inequality row = weighted/unweighted sum of |pairwise contrasts| / div
	if "`totalme'" != "" {
		qui est restore mec_margins
		local Lc   = `mcineqL_`vnum''
		local Ntot1 = `mcineqN1_`vnum''
		local Ntot2 = `mcineqN2_`vnum''
		local totdiv = cond(`mod1cats' > 1, 2, 1)
		if "`totmetype'" == "all"              local twtypes "weighted unweighted"
		else if "`totmetype'" == "unweighted"  local twtypes "unweighted"
		else                                   local twtypes "weighted"
		foreach wt of local twtypes {
			if "`wt'" == "unweighted" {
				local tmlab "Unwgt Total ME Ineq."
				local tmtok "TotMEIneqUnw"
				}
			else {
				local tmlab "Total ME Ineq."
				local tmtok "TotMEIneq"
				}
			tempname TC1 TC2
			forvalues bo = 1/`nlev_me' {	// per by/over level
				*Collect each prediction's net coefficient (same quantity, compact expression)
				matrix `TC1' = J(`mod1cats', `Lc', 0)
				matrix `TC2' = J(`mod1cats', `Lc', 0)
				forvalues oo = 1/`mod1cats' {
					local si = 0
					foreach va of local levels {
						local ++si
						local pa = `atnum1' + `mcineqpos_`vnum'_`va'' - 1 + `bymult_`bo''*`nc_at'
						local sj = 0
						foreach vb of local levels {
							local ++sj
							if `si' < `sj' {
								local pb = `atnum1' + `mcineqpos_`vnum'_`vb'' - 1 + `bymult_`bo''*`nc_at'
								if "`wt'" == "unweighted" {
*Divide by the number of pairs: the mean absolute pairwise ME
									local tmNC = `Lc' * (`Lc' - 1) / 2
									local wab1 = 1 / `tmNC'
									local wab2 = `wab1'
									}
								else {			// each model's own shares
									local wab1 = (`mcineqn1_`vnum'_`va'' + `mcineqn1_`vnum'_`vb'') ///
											/ `Ntot1' / (`Lc' - 1)
									local wab2 = (`mcineqn2_`vnum'_`va'' + `mcineqn2_`vnum'_`vb'') ///
											/ `Ntot2' / (`Lc' - 1)
									}
								local dh = _b[`prnum1_`oo''`pa'._at`bog1_`bo''] - _b[`prnum1_`oo''`pb'._at`bog1_`bo'']
								local sg = cond(`dh' < 0, -1, 1)
								matrix `TC1'[`oo',`si'] = `TC1'[`oo',`si'] + `wab1'*`sg'
								matrix `TC1'[`oo',`sj'] = `TC1'[`oo',`sj'] - `wab1'*`sg'
								if `nummods' == 2 {
									local dh2 = _b[`prnum2_`oo''`pa'._at`bog2_`bo''] - _b[`prnum2_`oo''`pb'._at`bog2_`bo'']
									local sg2 = cond(`dh2' < 0, -1, 1)
									matrix `TC2'[`oo',`si'] = `TC2'[`oo',`si'] + `wab2'*`sg2'
									matrix `TC2'[`oo',`sj'] = `TC2'[`oo',`sj'] - `wab2'*`sg2'
									}
								}
							}
						}
					}
				local m1e_`bo' 0
				local m2e_`bo' 0
				forvalues oo = 1/`mod1cats' {
					local si = 0
					foreach va of local levels {
						local ++si
						local pa = `atnum1' + `mcineqpos_`vnum'_`va'' - 1 + `bymult_`bo''*`nc_at'
						if `TC1'[`oo',`si'] != 0 {
							local cf : display %21x (`TC1'[`oo',`si'])
							local m1e_`bo' `m1e_`bo'' + (`cf')*_b[`prnum1_`oo''`pa'._at`bog1_`bo'']
							}
						if `nummods' == 2 & `TC2'[`oo',`si'] != 0 {
							local cf2 : display %21x (`TC2'[`oo',`si'])
							local m2e_`bo' `m2e_`bo'' + (`cf2')*_b[`prnum2_`oo''`pa'._at`bog2_`bo'']
							}
						}
					}
				}
			local totsub = 0
			if `nummods' == 2 | `nlev_me' > 1  local totsub = 1
			if `totsub' == 1 {
				if `i' == 1 & "`meineqinit'`totmeinit'" == "" {
					qui mlincom 1, stat(`stats')
					_mec_addz, matrix(_mlincom) rowname("`varname':{it}`tmlab'    ") top
					mat tempmat = _mlincom
					_mec_matselrc tempmat _mlincom, row(1)
					}
				else  _mec_addz, matrix(_mlincom) rowname("`varname':{it}`tmlab'    ")
				}
			if `nummods' == 1 {			// one model: one Total ME per level
				forvalues bo = 1/`nlev_me' {
					local mexp`me_num' (`m1e_`bo'')/`totdiv'
					if `totsub' == 0  qui mec_mlincom `mexp`me_num'', add rowname(`varname':`tmlab') stat(`stats')
					else              qui mec_mlincom `mexp`me_num'', add rowname(`varname':{sf}`=substr("`bolab_`bo''",1,28)') stat(`stats')
					local MEC_eqn "`MEC_eqn' `varname'"
					local MEC_rol "`MEC_rol' `rkey1'"
					if `nlev_me' > 1  local MEC_lev "`MEC_lev' `bocln_`bo''"
					else              local MEC_lev "`MEC_lev' ."
					local MEC_ctr "`MEC_ctr' `tmtok'"
					local ++me_num
					}
				}
			else {					// two models: m1, m2, Difference per level
				forvalues bo = 1/`nlev_me' {
					if `nlev_me' > 1  local Lt "`mod1lab' `bolab_`bo''"
					else              local Lt "`mod1lab'"
					local Lt = substr("`Lt'", 1, 28)
					local mexp`me_num' (`m1e_`bo'')/`totdiv'
					local _mcrn = substr("`Lt'", 1, 28)
					qui mec_mlincom `mexp`me_num'', add rowname(`varname':{sf}`_mcrn') stat(`stats')
					local MEC_eqn "`MEC_eqn' `varname'"
					local MEC_rol "`MEC_rol' `rkey1'"
					if `nlev_me' > 1  local MEC_lev "`MEC_lev' `bocln_`bo''"
					else              local MEC_lev "`MEC_lev' ."
					local MEC_ctr "`MEC_ctr' `tmtok'"
					local ++me_num
					}
				forvalues bo = 1/`nlev_me' {
					if `nlev_me' > 1  local Lt "`mod2lab' `bolab_`bo''"
					else              local Lt "`mod2lab'"
					local Lt = substr("`Lt'", 1, 28)
					local mexp`me_num' (`m2e_`bo'')/`totdiv'
					local _mcrn = substr("`Lt'", 1, 28)
					qui mec_mlincom `mexp`me_num'', add rowname(`varname':{sf}`_mcrn') stat(`stats')
					local MEC_eqn "`MEC_eqn' `varname'"
					local MEC_rol "`MEC_rol' `rkey2'"
					if `nlev_me' > 1  local MEC_lev "`MEC_lev' `bocln_`bo''"
					else              local MEC_lev "`MEC_lev' ."
					local MEC_ctr "`MEC_ctr' `tmtok'"
					local ++me_num
					}
				forvalues bo = 1/`nlev_me' {
					if `nlev_me' > 1  local Lt "Difference `bolab_`bo''"
					else              local Lt "Difference"
					local Lt = substr("`Lt'", 1, 28)
					local mexp`me_num' (`m1e_`bo'')/`totdiv' - (`m2e_`bo'')/`totdiv'
					local _mcrn = substr("`Lt'", 1, 28)
					qui mec_mlincom `mexp`me_num'', add rowname(`varname':{sf}`_mcrn') stat(`stats')
					local MEC_eqn "`MEC_eqn' `varname'"
					local MEC_rol "`MEC_rol' `rkeyD'"
					if `nlev_me' > 1  local MEC_lev "`MEC_lev' `bocln_`bo''"
					else              local MEC_lev "`MEC_lev' ."
					local MEC_ctr "`MEC_ctr' `tmtok'"
					local ++me_num
					}
			}
			if `i' == 1  local totmeinit = 1
			}
		}
	
	local ncontr = `mcncontr_`vnum''	// #contrasts (vs-base, or all pairs)
	forvalues h = 1/`ncontr' {		// Loop through the contrast list
		*Absolute _at positions for this contrast's lower/higher levels
		local pclo = `atnum1' + `mcctrlo_`vnum'_`h'' - 1
		local pchi = `atnum1' + `mcctrhi_`vnum'_`h'' - 1
		local m2a1 = `pclo'
		local m2a2 = `pchi'
		forvalues o = 1/`mod1cats' { // Loop through all categories of DV
	
	_mec_catlabs, ncats(`mod1cats') out1("`out_1_`o''") out2("`out_2_`o''")
	local cat1name "`r(cat1name)'"
	local cat2name "`r(cat2name)'"
	local catDname "`r(catDname)'"
		
	local sectitle "`mcctrlab_`vnum'_`h''"	

		*If first in table, create quick faux table to get category label row	
		if `i' == 1 & `h' == 1 & `mod1cats' == 1 & "`meineqinit'`totmeinit'" == "" {
			qui mlincom 1, stat(`stats') 
			_mec_addz, matrix(_mlincom) ///
				rowname("`varname':{it}`sectitle'    ") top
			mat tempmat = _mlincom
			_mec_matselrc tempmat _mlincom, row(1)
		}
		else if `i' == 1 & `h' == 1 & `mod1cats' != 1 & `o' == 1 & "`meineqinit'`totmeinit'" == "" {
			qui mlincom 1, stat(`stats') 
			_mec_addz, matrix(_mlincom) ///
				rowname("`varname':{it}`sectitle'    ") top
			mat tempmat = _mlincom
			_mec_matselrc tempmat _mlincom, row(1)
		}
		else if `o' == 1 {
			_mec_addz, matrix(_mlincom) ///
				rowname("`varname':{it}`sectitle'    ")
		}	
		
	*---- model 1 marginal effect (looped over over() levels) ----
	forvalues bo = 1/`nlev_me' {
	if `nummods' == 2 & `nlev_me' > 1  local L1 "`mod1lab' `bolab_`bo''"
	else                               local L1 "`bolab_`bo''"
*Cap the display row name (Stata rejects an over-long one)
	local _lv ""
	if `nummods' == 2 & `nlev_me' > 1  local _lv "`bolab_`bo''"
	_mec_rowlab, cat("`cat1name'") mod("`mod1lab'") lev("`_lv'") /*
		*/ width(`=`twidth' - 2')
	local _rn1 "`r(lab)'"
	local R1 "`rkey1'"		// MEC_rol = pure model role; level -> MEC_lev
	if `inm1' > 0 | `nummods' == 1 {		// If var is in model 1
		local a1 = `pclo' + `bymult_`bo''*`nc_at'	// by() shifts the _at index
		local a2 = `pchi' + `bymult_`bo''*`nc_at'	//   per level; 0 for over/none
		local mexp`me_num' `rpre'(_b[`prnum1_`o''`a2'._at`bog1_`bo''] - ///
							 _b[`prnum1_`o''`a1'._at`bog1_`bo''])`rsuf'
		local _mcrn = substr("`cat1name'`L1'", 1, 28)	// coef name <= 32 (with {sf})
		qui mec_mlincom `mexp`me_num'', ///
			add rowname(`varname':{sf}`_mcrn') stat(`stats') 
		local MEC_eqn "`MEC_eqn' `varname'"
		local __ctr : subinstr local sectitle " - " "v", all
		local __ctr : subinstr local __ctr " " "", all
		local MEC_rol "`MEC_rol' `R1'"
		if `nlev_me' > 1  local MEC_lev "`MEC_lev' `bocln_`bo''"
		else              local MEC_lev "`MEC_lev' ."
		local MEC_ctr "`MEC_ctr' `__ctr'"
		local ++me_num
		}
	else if `nummods' == 2 { 
		local _mcrn = substr("`out_1_`o''`L1'", 1, 28)
		_mec_addz, matrix(_mlincom) rowname("`varname':{sf}`_mcrn'")
		}
	}
	*---- model 2 marginal effect ----
	forvalues bo = 1/`nlev_me' {
	if `nlev_me' > 1  local L2 "`mod2lab' `bolab_`bo''"
	else              local L2 "`mod2lab'"
	local _lv ""
	if `nlev_me' > 1  local _lv "`bolab_`bo''"
	_mec_rowlab, cat("`cat2name'") mod("`mod2lab'") lev("`_lv'") /*
		*/ width(`=`twidth' - 2')
	local _rn2 "`r(lab)'"
	local R2 "`rkey2'"
	if `inm2' > 0 & `nummods' == 2 {		// If var is in model 2
		local am1 = `m2a1' + `bymult_`bo''*`nc_at'	// by() shifts model-2 _at index
		local am2 = `m2a2' + `bymult_`bo''*`nc_at'
		local mexp`me_num' `rpre'(_b[`prnum2_`o''`am2'._at`bog2_`bo''] - ///
							 _b[`prnum2_`o''`am1'._at`bog2_`bo''])`rsuf'
		local _mcrn = substr("`cat2name'`L2'", 1, 28)	// coef name <= 32 (with {sf})
		qui mec_mlincom `mexp`me_num'', ///
			add rowname(`varname':{sf}`_mcrn') stat(`stats') 
		local MEC_eqn "`MEC_eqn' `varname'"
		local __ctr : subinstr local sectitle " - " "v", all
		local __ctr : subinstr local __ctr " " "", all
		local MEC_rol "`MEC_rol' `R2'"
		if `nlev_me' > 1  local MEC_lev "`MEC_lev' `bocln_`bo''"
		else              local MEC_lev "`MEC_lev' ."
		local MEC_ctr "`MEC_ctr' `__ctr'"
		local ++me_num
		}
	else if `nummods' == 2 { 
		local _mcrn = substr("`out_2_`o''`L2'", 1, 28)
		_mec_addz, matrix(_mlincom) rowname("`varname':{sf}`_mcrn'")
		}
	}
	*---- cross-model Difference (var in both models) ----
	forvalues bo = 1/`nlev_me' {
	if `nlev_me' > 1  local LD "Difference `bolab_`bo''"
	else              local LD "Difference"
	local _lv ""
	if `nlev_me' > 1  local _lv "`bolab_`bo''"
	_mec_rowlab, cat("`catDname'") mod("Difference") lev("`_lv'") /*
		*/ width(`=`twidth' - 2')
	local _rnD "`r(lab)'"
	local RD "`rkeyD'"
	if `inm1' > 0 & `inm2' > 0 & `nummods' == 2 {
		local a1  = `pclo' + `bymult_`bo''*`nc_at'	// by() shifts both models'
		local a2  = `pchi' + `bymult_`bo''*`nc_at'	//   _at index per level
		local am1 = `m2a1'  + `bymult_`bo''*`nc_at'
		local am2 = `m2a2'  + `bymult_`bo''*`nc_at'
		local mexp`me_num' `rpre'(_b[`prnum1_`o''`a2'._at`bog1_`bo''] - ///
							 _b[`prnum1_`o''`a1'._at`bog1_`bo'']) - ///
							(_b[`prnum2_`o''`am2'._at`bog2_`bo''] - ///
							_b[`prnum2_`o''`am1'._at`bog2_`bo''])`rsuf'
		local _mcrn = substr("`catDname'`LD'", 1, 28)	// coef name <= 32 (with {sf})
		qui mec_mlincom `mexp`me_num'', ///
			add rowname(`varname':{sf}`_mcrn') stat(`stats') 
		local MEC_eqn "`MEC_eqn' `varname'"
		local __ctr : subinstr local sectitle " - " "v", all
		local __ctr : subinstr local __ctr " " "", all
		local MEC_rol "`MEC_rol' `RD'"
		if `nlev_me' > 1  local MEC_lev "`MEC_lev' `bocln_`bo''"
		else              local MEC_lev "`MEC_lev' ."
		local MEC_ctr "`MEC_ctr' `__ctr'"
		local ++me_num	
		}
	else if `nummods' == 2 { 
		local _mcrn = substr("`catDname'`LD'", 1, 28)
		_mec_addz, matrix(_mlincom) rowname("`varname':{sf}`_mcrn'")
		}

		}		// close forvalues bo (over levels) for Difference
		}		// close forvalues o (DV categories)
		}		// close forvalues h (IV contrasts)
		local bymul = `nbocells'		// the var's k at() positions repeat per cell
		local atnum1 = `atnum1' + `numcats'*`bymul'	// advance past this var's
		local atnum2 = `atnum2' + `numcats'*`bymul'	//   k*bylevels _at positions
		}		// close if numcats>=3
	
}	// End of ME calculation loop
	
*********************
// Build the table //
*********************

*Set title and sample size information for table based on # of models
if `nummods' == 1 {
	local N_title "Marginal effects (N_`mod1lab'=`N1')"
	}
if `nummods' == 2 {
	local N_title 	"Marginal effects and cross-model differences" /*
				*/	"(N_`mod1lab'=`N1') (N_`mod2lab'=`N2')"
	}
	
*Relabel columns with nicer labels
local estimate_col 	"Estimate"
local est_col 		"Estimate"
local se_col 		"Robust_SE"
if regexm(`"`mecmorest'"', "vce\( *unconditional *\)")  local se_col "Uncond_SE"
local pvalue_col 	"P>|z|"
local pval_col 		"P>|z|"
local p_col 		"P>|z|"
local ll_col 		"CI_LL"
local ul_col 		"CI_UL"
local z_col 		"z"

local statcols `stats'
foreach s in `stats' {
	local statcols : subinstr local statcols "`s'" "``s'_col'"
	}
matrix 	colnames _mlincom = `statcols'
local 	numcols : word count `statcols'	// for formatting table
	
qui mlincom, title("`N_title'") ///
			twidth(`twidth') width(`width') ///
			stat(`stats') decimals(`dec') 

mat _mecompare = _mlincom 	// Rename mlincom table

*Add extra column to table with ME # 
if `addnums' == 1 {
	_mec_number, matrix(_mecompare) label("ME_#")
	local 	mecolnum = `numcols' + 1
	local 	colorder "`mecolnum'"
	forvalues num = 1/`numcols' {
		local colorder "`colorder' `num'"
		}
	*Reorder columns with ME# column first
	_mec_matselrc _mecompare _mecompare, col("`colorder'") 

	}

*Column spec for final table
local numspec = "%`width'.`dec'f &"			
local colspec "& %`twidth's | "
if `addnums' == 0 {
	forvalues c = 1 / `numcols' {
		local colspec "`colspec' `numspec'"
	}
}
if `addnums' == 1 {
	local colspec "`colspec' %5.0f &"
	forvalues c = 1 / `numcols' {
		local colspec "`colspec' `numspec'"
	}
}

// per-outcome role-row span for two-model multi-outcome tables (3 roles x
// nlev_me levels); = "&&&" when no by()/over().
local mcoutamp ""
local mc3lev = 3 * `nlev_me'
// Set row spec for final table based on # models, # outcomes, var type //
if `nummods' == 1 & `mod1cats' == 1 {	
	local rowspec "&-" 
	*single-model over() adds (nlev_me-1) data rows per section
	local extra_amps ""
	forvalues c = 2/`nlev_me' {
		local extra_amps "`extra_amps'&"
		}
	local cvspec "`extra_amps'-"
	local bvspec "&`extra_amps'-"
	local nvspec "&&`extra_amps'"
	}

if `nummods' == 1 & `mod1cats' != 1 {
	local rowspec "&-" 
	*multi-outcome: mod1cats rows per section, multiplied by over()/by() levels
	local mcnout = `mod1cats' * `nlev_me'
	local extra_amps ""
	forvalues c = 2/`mcnout' {
		local extra_amps "`extra_amps'&"
		}
	local cvspec "`extra_amps'-"
	local bvspec "&`extra_amps'-"
	local nvspec "&&`extra_amps'"
	}
	
if `nummods' == 2 {
	local rowspec "&-" 
	*over() gives 3 role rows (m1/m2/diff) per level
	local nrole = 3 * `nlev_me'
	local extra ""
	forvalues c = 2/`nrole' {
		local extra "`extra'&"
		}
	local cvspec "`extra'-"
	local bvspec "&`extra'-"
	local nvspec "&`extra'&"
	forvalues c = 1/`mc3lev' {	// per-extra-outcome fill = 3 roles x nlev_me
		local mcoutamp "`mcoutamp'&"
		}
	}

forvalues i = 1/`numvars' {
	local var : word `i' of `list_ivs'
*	The variable's position in its own list; keys the per-variable macros
	local vnum = `i'
*Exact membership test, not substring
	local inm1 = 0
	local inm2 = 0
	foreach mectok of local list_ivs1 {
		if "`mectok'" == "`var'"  local inm1 = 1
		}
	foreach mectok of local list_ivs2 {
		if "`mectok'" == "`var'"  local inm2 = 1
		}
	fvexpand `var' `meclevif'
	local numcats : word count `r(varlist)' 

	
	if `numcats' == 1 { 	// continuous IVs
	*A start() list multiplies the rows of this variable by its number of bases
	local nlv_i = `nlev_me' * `nsl`i''
	local cvspec_i "`cvspec'"
	local mcoutamp_i "`mcoutamp'"
	if `nsl`i'' > 1 {
		local nrows_i = `nlv_i'
		if `nummods' == 1 & `mod1cats' != 1  local nrows_i = `mod1cats' * `nlv_i'
		if `nummods' == 2                     local nrows_i = 3 * `nlv_i'
		local cvspec_i ""
		forvalues c = 2/`nrows_i' {
			local cvspec_i "`cvspec_i'&"
			}
		local cvspec_i "`cvspec_i'-"
		local mcoutamp_i ""
		if `nummods' == 2 {
			forvalues c = 1/`=3 * `nlv_i'' {
				local mcoutamp_i "`mcoutamp_i'&"
				}
			}
		}
	if "`totalme'" != "" {	// Total ME row(s): (subhdr) + role x level
		local totsub = cond(`nummods' == 2 | `nlv_i' > 1, 1, 0)
		local trolef = cond(`nummods' == 2, 3, 1)
		local totrows = `totsub' + `trolef' * `nlv_i'
		forvalues tr = 1/`totrows' {
			local rowspec "`rowspec'&"
			}
		}
	if `mod1cats' != 1 & `nummods' == 2 {
			forvalues c = 2/`mod1cats' {
				local rowspec "`rowspec'`mcoutamp_i'"
				
					if `c' == `mod1cats' { 
						local rowspec "`rowspec'`cvspec_i'"				
					}
			}
		}	
	else { 	
		local rowspec "`rowspec'`cvspec_i'"
		}
	}
	
	if `numcats' == 2 {		// binary IVs
		if "`totalme'" != "" {	// Total ME row(s): (subhdr) + role x level
			local totsub = cond(`nummods' == 2 | `nlev_me' > 1, 1, 0)
			local trolef = cond(`nummods' == 2, 3, 1)
			local totrows = `totsub' + `trolef' * `nlev_me'
			forvalues tr = 1/`totrows' {
				local rowspec "`rowspec'&"
				}
			}
		if `mod1cats' != 1 & `nummods' == 2 {
			forvalues c = 2/`mod1cats' {
				local rowspec "`rowspec'`mcoutamp'"
				
					if `c' == `mod1cats' { 
						local rowspec "`rowspec'`bvspec'"				
					}
			}
		}	
		else {
			local rowspec "`rowspec'`bvspec'"
		}
	
	}
	
	if `numcats' >= 3 {		// nominal IVs
		local 	fv = strpos("`var'", ".") + 1 		// find where . is
		local 	varname = substr("`var'",`fv',.) 	// strip fv prefix
		qui 	levelsof `varname' `meclevif', local(levels)
		local 	totcats : word count `levels'
		local 	ncontr = `mcncontr_`vnum''	// vs-base (k-1) or all pairs
	
		if "`meinequality'" != "" {
			local mineqsub = 0			// subheader row?
			if `mod1cats' > 1 | `nummods' == 2 | `nlev_me' > 1  local mineqsub = 1
			local mrolef = 1			// rows per outcome per level (m1/m2/diff = 3)
			if `nummods' == 2  local mrolef = 3
			local mnwt = 1				// weighted+unweighted with all
			if "`meineqtype'" == "all"  local mnwt = 2
			local mineqrows = `mnwt' * (`mineqsub' + `mod1cats' * `mrolef' * `nlev_me')
			forvalues mr = 1/`mineqrows' {
				local rowspec "`rowspec'&"
				}
			}

		if "`totalme'" != "" {		// Total ME Ineq. row(s) (summed over outcomes)
			local totsub = 0
			if `nummods' == 2 | `nlev_me' > 1  local totsub = 1
			local trolef = 1
			if `nummods' == 2  local trolef = 3
			local tnwt = 1
			if "`totmetype'" == "all"  local tnwt = 2
			local totrows = `tnwt' * (`totsub' + `trolef' * `nlev_me')
			forvalues tr = 1/`totrows' {
				local rowspec "`rowspec'&"
				}
			}

		if `mod1cats' != 1 & `nummods' == 2 {
			forvalues h = 1/`ncontr' {		// Loop through the contrast list
			local rowspec "`rowspec'`nvspec'"
		
			forvalues c = 2/`mod1cats' {
				local rowspec "`rowspec'`mcoutamp'"
				}
			if `h' == `ncontr' {
				*Replace last & with - for line ending nominal var output
				local rowspec = substr("`rowspec'",1,length("`rowspec'")-1)
				local rowspec "`rowspec'-"
				}
			}		
		}
		
		else {
			forvalues h = 1/`ncontr' {		// Loop through the contrast list
			local rowspec "`rowspec'`nvspec'"
		
			if `h' == `ncontr' {
				*Replace last & with - for line ending nominal var output
				local rowspec = substr("`rowspec'",1,length("`rowspec'")-1)
				local rowspec "`rowspec'-"
				}
			}
		}
	}
}	

local 	rowspec = substr("`rowspec'",1,length("`rowspec'")-1)
local 	rowspec "`rowspec'&"		// so end of table does not have line

*What is being predicted
if "`plab1'" != "" {
	di _newline(1)
	if `nummods' == 1 | "`plab2'" == "" | "`plab1'" == "`plab2'" {
		di as text "Predicting: " as result "`plab1'"
		}
	else {
		di as text "Predicting: " as result "`plab1'" /*
		*/ as text " (`mod1lab'), " as result "`plab2'" /*
		*/ as text " (`mod2lab')"
		}
	}

*Display table
matlist _mecompare, title("`N_title'") 	///
		cspec("`colspec'") rspec("`rowspec'") nodotz underscore	

if "`groups'" != "" & "`amount'" == "sd" {
	di _newline(1)
	if "`groupsd'" != "" {
*		groupsd: each group's SD, from that group's own observations
		di as text "NOTE: SD's are group-specific: `mod1lab' uses its own " /*
		*/ "`N1' observations and `mod2lab' its own `N2'."
		}
	else {
		qui count if `mec_sample' == 1
		di as text "NOTE: SD's are based on all `r(N)' observations pooled " /*
		*/ "across both groups."
		}
	}

if "`warn_twosd'" != "" {
	di _newline(1)
	di as text "NOTE: for twosd we recommend a centered change (now the " /*
	*/ "default); you specified {opt uncentered}."
	}

*One difference per outcome; under groupme each model averages over its own group
if "`groupme'" != "" {
	qui est restore `mecsys'
	`cmdqui' `marginscmd' `if' `in', `mimarginsspec' /*
		*/ over(`mecgsamp') post
	di _newline(1)
	di as text "Average conditional difference in the outcome " /*
	*/ "(`mod2lab' - `mod1lab'),"
	di as text "each model averaged over its own sample:"
	forvalues gmo = 1/`mod1cats' {
		local gmo2 = `gmo' + `mod1cats'
*Specialized route: the same margins call returns one column per model
		if "`s2spec1'" != "" & `s2spec1' == 1 ///
			qui lincom _b[`mod2':_cons] - _b[`mod1':_cons]
		else ///
			qui lincom _b[`gmo2'._predict`g2spec'] - _b[`gmo'._predict`g1spec']
		local gme_est = r(estimate)
		local gme_se = r(se)
		local gme_z = `gme_est' / `gme_se'
		local gme_p = 2*normal(-abs(`gme_z'))
		if `mod1cats' == 1  local gmolab ""
		else                local gmolab "Pr(`out_1_`gmo'')"
		di as result "    `gmolab'" _col(26) "Estimate = " %9.`dec'f `gme_est' /*
		*/ "   SE = " %9.`dec'f `gme_se' "   p = " %6.3f `gme_p'
		}
	if `mod1cats' > 1 {
		di as text "    (differences across the outcome categories sum to 0)"
		}
	qui est restore mec_margins
	}

*Post e(b)/e(V) so coefplot, esttab and table work on the MEs; full table kept in e(table)
local K = `me_num' - 1

if `K' > 0 {

	*Coefficient names: two models -> eq=variable, coef=model; one model -> variable only
	local eqnames ""
	local conames ""
	forvalues j = 1/`K' {
		local vj : word `j' of `MEC_eqn'
		local rj : word `j' of `MEC_rol'
		local cj : word `j' of `MEC_ctr'
		local lvj : word `j' of `MEC_lev'
		if "`cj'" == "." local cj ""
		if "`lvj'" == "." local lvj ""
		if `nummods' == 1 {
			local rawe`j' ""
			if "`cj'" == "" local rawc`j' "`vj'"
			else            local rawc`j' "`vj'_`cj'"
			if "`lvj'" != "" local rawc`j' "`rawc`j''_`lvj'"
			}
		else {					// two models: eq = variable(_contrast),
			if "`cj'" == "" local rawe`j' "`vj'"	// coef = model(_level) so
			else            local rawe`j' "`vj'_`cj'"	// coefplot can select one
			if "`lvj'" == "" local rawc`j' "`rj'"		// model across all vars
			else             local rawc`j' "`rj'_`lvj'"
			}
		}
	*Force valid, unique names capped at 32 (equation names too)
	forvalues j = 1/`K' {
		local eqj ""
		if `nummods' != 1 {
			local eqj = strtoname("`rawe`j''")
			if length("`eqj'") > 32  local eqj = substr("`eqj'",1,32)
			local ek = 0
			local eclash = 1
			while `eclash' == 1 {
				local eclash = 0
				local jm1e = `j' - 1
				forvalues q = 1/`jm1e' {
					if "`fineq`q''" == "`eqj'" & "`raweq`q''" != "`rawe`j''" ///
						local eclash = 1
					}
				if `eclash' == 1 {
					local ++ek
					local esfx "_x`ek'"
					local ecut = 32 - length("`esfx'")
					local eqj = substr(strtoname("`rawe`j''"),1,`ecut') + "`esfx'"
					}
				}
			local raweq`j' "`rawe`j''"
			}
		local occ = 0
		local tot = 0
		forvalues q = 1/`K' {
			if "`rawe`q''"=="`rawe`j''" & "`rawc`q''"=="`rawc`j''" {
				local ++tot
				if `q' <= `j' local ++occ
				}
			}
		local base = strtoname("`rawc`j''")
		if `tot' > 1 {				// number every repeat: _1, _2, ...
			local sfx "_`occ'"
			local cut = 32 - length("`sfx'")
			if length("`base'") > `cut'  local base = substr("`base'",1,`cut')
			local base "`base'`sfx'"
			}
		if length("`base'") > 32  local base = substr("`base'",1,32)
		local coj "`base'"
		local kk = 0					// safety net: truncation can still collide
		local clash = 1
		while `clash' == 1 {
			local clash = 0
			local jm1 = `j' - 1
			forvalues q = 1/`jm1' {
				if "`fineq`q''" == "`eqj'" & "`fin`q''" == "`coj'"  local clash = 1
				}
			if `clash' == 1 {
				local ++kk
				local sfx2 "_x`kk'"
				local cut2 = 32 - length("`sfx2'")
				local coj = substr("`base'",1,`cut2') + "`sfx2'"
				}
			}
		local fin`j' "`coj'"
		local fineq`j' "`eqj'"
		local conames "`conames' `coj'"
		if `nummods' != 1  local eqnames "`eqnames' `eqj'"
		}

	*-- recover b and full V via one nlcom over all MEs -------------------
	qui est restore mec_margins
	tempname __b __V
	local nlspec ""
	forvalues j = 1/`K' {
		local nlspec `"`nlspec' (ME`j': `mexp`j'')"'
		}
	*Treat missing variances from nlcom as failure; prefer whichever attempt is clean
	tempname __bA __VA __bB __VB
	local gotA = 0
	local gotB = 0
	local missA = .
	local missB = .
	capture qui nlcom `nlspec'
	if _rc == 0 {
		matrix `__bA' = r(b)
		matrix `__VA' = r(V)
		local gotA = 1
		local missA = 0
		forvalues j = 1/`K' {
			forvalues q = 1/`K' {
				if missing(`__VA'[`j',`q'])  local ++missA
				}
			}
		}
	if `gotA' == 0 | `missA' > 0 {		// retry the system rescaled
		local nlspec2 ""
		forvalues j = 1/`K' {
			local nlspec2 `"`nlspec2' (ME`j': 1000*(`mexp`j''))"'
			}
		qui est restore mec_margins
		capture qui nlcom `nlspec2'
		if _rc == 0 {
			matrix `__bB' = r(b) / 1000
			matrix `__VB' = r(V) / 1000000
			local gotB = 1
			local missB = 0
			forvalues j = 1/`K' {
				forvalues q = 1/`K' {
					if missing(`__VB'[`j',`q'])  local ++missB
					}
				}
			}
		}
	if `gotA' == 1 & `missA' == 0 {		// unscaled, clean
		matrix `__b' = `__bA'
		matrix `__V' = `__VA'
		}
	else if `gotB' == 1 & `missB' == 0 {	// rescaled, clean
		matrix `__b' = `__bB'
		matrix `__V' = `__VB'
		}
	else if `gotA' == 1 {				// best available
		matrix `__b' = `__bA'
		matrix `__V' = `__VA'
		}
	else if `gotB' == 1 {
		matrix `__b' = `__bB'
		matrix `__V' = `__VB'
		}
	else {					// fallback: per-ME estimates, diagonal V
		matrix `__b' = J(1,`K',.)
		matrix `__V' = J(`K',`K',0)
		forvalues j = 1/`K' {
			qui est restore mec_margins
			capture qui nlcom (ME`j': `mexp`j'')
			if _rc != 0 {			// retry rescaled
				qui est restore mec_margins
				capture qui nlcom (ME`j': 1000*(`mexp`j''))
				if _rc == 0 {
					matrix `__b'[1,`j'] = r(b)[1,1] / 1000
					matrix `__V'[`j',`j'] = r(V)[1,1] / 1000000
					}
				}
			else {
				matrix `__b'[1,`j'] = r(b)[1,1]
				matrix `__V'[`j',`j'] = r(V)[1,1]
				}
			}
		}

	*-- relabel with the names and post ---------------------------------
	matrix colnames `__b' = `conames'
	matrix colnames `__V' = `conames'
	matrix rownames `__V' = `conames'
	if `nummods' != 1 {			// two models: group coefs by variable
		matrix coleq `__b' = `eqnames'
		matrix coleq `__V' = `eqnames'
		matrix roweq `__V' = `eqnames'
		}

	*store(): stash each model's MEs (and differences) as stored estimates keyed by variable
	if "`store'" != "" {
		forvalues j = 1/`K' {		// variable key + role per ME column
			local vj : word `j' of `MEC_eqn'
			local cj : word `j' of `MEC_ctr'
			local rj : word `j' of `MEC_rol'
			local lvj : word `j' of `MEC_lev'
			if "`cj'" == "." local cj ""
			if "`lvj'" == "." local lvj ""
			local vkraw "`vj'"			// coef = variable(_contrast)(_level);
			if "`cj'" != ""  local vkraw "`vkraw'_`cj'"	// role (model) is the
			if "`lvj'" != "" local vkraw "`vkraw'_`lvj'"	// stored estimate key
			local vkey`j' = strtoname("`vkraw'")
			local role`j' "`rj'"
			}
		*Roles keyed by internal tokens, never display labels
		if `nummods' == 1 local rolelist "`rkey1'"
		else              local rolelist "`rkey1' `rkey2' `rkeyD'"
		foreach R of local rolelist {
			if "`R'" == "`rkeyD'" local sfx "diff"
			else                  local sfx "`R'"
			local idx  ""
			forvalues j = 1/`K' {
				if "`role`j''" == "`R'" local idx `idx' `j'
				}
			*Number repeated keys within the role so stored matrices keep unique column names
			local keylist ""
			foreach jj of local idx {
				local keylist "`keylist' `vkey`jj''"
				}
			local nk : word count `keylist'
			local vars ""
			forvalues a = 1/`nk' {
				local ka : word `a' of `keylist'
				local occ = 0
				local tot = 0
				forvalues z = 1/`nk' {
					local kz : word `z' of `keylist'
					if "`kz'" == "`ka'" {
						local ++tot
						if `z' <= `a' local ++occ
						}
					}
				local nm "`ka'"
				if `tot' > 1 {				// number every repeat
					local nsfx "_`occ'"
					local ncut = 32 - length("`nsfx'")
					if length("`nm'") > `ncut'  local nm = substr("`nm'",1,`ncut')
					local nm "`nm'`nsfx'"
					}
				if length("`nm'") > 32  local nm = substr("`nm'",1,32)
				local vars `vars' `nm'
				}
			*Skip an empty role
			local nc : word count `idx'
			if `nc' == 0 {
				di _newline(1)
				di as txt "note: no estimates for `R'; `store'_`sfx' not saved."
				continue
				}
			tempname bpiece Vpiece
			matrix `bpiece' = J(1,`nc',0)
			matrix `Vpiece' = J(`nc',`nc',0)
			local a = 0
			foreach jj of local idx {
				local ++a
				matrix `bpiece'[1,`a'] = `__b'[1,`jj']
				local c = 0
				foreach kk of local idx {
					local ++c
					matrix `Vpiece'[`a',`c'] = `__V'[`jj',`kk']
					}
				}
			matrix colnames `bpiece' = `vars'
			matrix colnames `Vpiece' = `vars'
			matrix rownames `Vpiece' = `vars'
			*role-specific N (they differ under groups)
			local Nrole = `N1'
			if "`R'" == "`rkey2'" & "`groups'" != ""  local Nrole = `N2'
			ereturn post `bpiece' `Vpiece', obs(`Nrole')
			ereturn local cmd        "mecompare"
			ereturn local properties "b V"
			if "`dv1name'" != "" ereturn local depvar "`dv1name'"
			estimates store `store'_`sfx', title("ME (`R')")
			}
		}

*e(N) = final averaging sample (pooled N1+N2 under groups)
	local Nfinal = `N1'
	local __postopt "obs(`Nfinal')"
	if `ismi' != 1 {
		capture confirm variable `mec_sample'
		if _rc == 0 {
			tempvar __esamp
			qui gen byte `__esamp' = (`mec_sample' == 1)
			qui count if `__esamp' == 1
			local Nfinal = `r(N)'
			local __postopt "esample(`__esamp') obs(`Nfinal')"
			}
		}

	*Unformed quantities: warn and post zero variance so the table survives ereturn post
	local __nmiss = 0
	forvalues j = 1/`K' {
		if missing(`__b'[1,`j'])  local ++__nmiss
		}
	if `__nmiss' > 0 {
		di _newline(1)
		di in red "note: `__nmiss' of `K' quantities could not be recovered for " /*
		*/ "e(b); those coefficients are missing and metest cannot use them."
		forvalues j = 1/`K' {
			if missing(`__b'[1,`j']) {
				matrix `__b'[1,`j'] = 0
				forvalues q = 1/`K' {
					matrix `__V'[`j',`q'] = 0
					matrix `__V'[`q',`j'] = 0
					}
				}
			}
		}
	*Count missing variances after the zeroing above
	local __vmiss = 0
	forvalues j = 1/`K' {
		forvalues q = 1/`K' {
			if missing(`__V'[`j',`q'])  local ++__vmiss
			}
		}
	if `__vmiss' > 0 {			// missing variances/covariances
		di _newline(1)
		di in red "note: `__vmiss' element(s) of the covariance matrix could not " /*
		*/ "be recovered and were set to 0; treat SEs involving those " /*
		*/ "quantities, and any metest combination of them, with caution."
		forvalues j = 1/`K' {
			forvalues q = 1/`K' {
				if missing(`__V'[`j',`q'])  matrix `__V'[`j',`q'] = 0
				}
			}
		}

	ereturn post `__b' `__V', `__postopt'
	ereturn local cmd        "mecompare"
	ereturn local title      "Marginal-effect comparison"
	ereturn local properties "b V"
*Post the prediction label(s); two macros only when the models disagree
	if `"`plab1'"' != "" {
		ereturn local predict_label `"`plab1'"'
		if `"`plab2'"' != "" & `"`plab2'"' != `"`plab1'"' {
			ereturn local predict1_label `"`plab1'"'
			ereturn local predict2_label `"`plab2'"'
		}
	}
	if `"`marginsopt'"' != ""  ereturn local marginsopt `"`marginsopt'"'
	*Stash the matlist display specs for replay (strip embedded quotes)
	local __dt : subinstr local N_title `"""' "", all
	local __dt = stritrim("`__dt'")
	ereturn local dtitle `"`__dt'"'
	ereturn local dcspec `"`colspec'"'
	ereturn local drspec `"`rowspec'"'
*Copy: ereturn matrix would move the source
	ereturn matrix table = _mecompare, copy
	ereturn scalar n_vars = `numvars'
	ereturn scalar n_mods = `nummods'
	*Unrecoverable quantities post as 0; counts and a completeness flag are returned
	ereturn scalar k_failed = `__nmiss'
	ereturn scalar V_zeroed = `__vmiss'
	if `__nmiss' == 0 & `__vmiss' == 0  ereturn scalar V_complete = 1
	else                                ereturn scalar V_complete = 0
	*names of the persistent variables mecompare created, if any
	if "`mecdv1'" != ""  ereturn local mec_dv1 "`mecdv1'"
	if "`mecdv2'" != ""  ereturn local mec_dv2 "`mecdv2'"
	}

*Label the _est_ markers at return; any estimates housekeeping can reset them, and _rc is saved/restored so the block is invisible to the caller
local __rcsave = _rc
capture label variable _est_`mecsys' "mecompare: est. sample for stored system `mecsys'"
capture label variable _est_mec_margins "mecompare: est. sample for stored margins mec_margins"
capture label variable _est__mec_src "mecompare: est. sample for source-model stash _mec_src"
local __nh : word count `mecholdn'
forvalues __h = 1/`__nh' {
	local __hv : word `__h' of `mecholdn'
	local __hw : word `__h' of `mecholdw'
	capture label variable _est_`__hv' "suest2: est. sample for private copy of `__hw'"
	}
capture error `__rcsave'

end		
	
	
* version 0.1.1 2018-11-02 | mize - long
/*
Adds blank rows (via .z) to table for clearer formatting of the table 
matinsert, matrix(_mlincom) rownumber(1) rowname(`"nominalvar:cat2_vs_cat1     "') value(.z)
* if rownumber(b) then put new row at bottom; if rownumber(t) put at top
*/
capture program drop _mec_misum
program define _mec_misum, rclass
*summarize, pooling across imputations under mi (SD = root mean within-imputation variance)
	version 16.0
	syntax varname(numeric) [if] [in] , [ MI(integer 0) WSpec(string) ]
	marksample touse, novarlist

	if `mi' == 0 {
		qui summarize `varlist' if `touse' `wspec'
		return scalar mean = r(mean)
		return scalar sd   = r(sd)
		return scalar min  = r(min)
		return scalar max  = r(max)
		return scalar N    = r(N)
		exit
		}

	local mistyle "`_dta[_mi_style]'"
	local M       "`_dta[_mi_M]'"
	if "`M'" == "" | "`M'" == "0" {		// mi flagged but no imputations
		qui summarize `varlist' if `touse' `wspec'
		return scalar mean = r(mean)
		return scalar sd   = r(sd)
		return scalar min  = r(min)
		return scalar max  = r(max)
		return scalar N    = r(N)
		exit
		}

	tempname smean svar smin smax sn
	scalar `smean' = 0
	scalar `svar'  = 0
	scalar `smin'  = 0
	scalar `smax'  = 0
	scalar `sn'    = 0
	local nused = 0
	forvalues mm = 1/`M' {
		if "`mistyle'" == "wide" {
*Wide style holds an imputed variable as _<m>_<var>
			capture confirm variable _`mm'_`varlist'
			if _rc == 0  local vv "_`mm'_`varlist'"
			else         local vv "`varlist'"
			qui summarize `vv' if `touse' `wspec'
			}
		else {
			qui summarize `varlist' if _mi_m == `mm' & `touse' `wspec'
			}
		if r(N) > 0 {
			local ++nused
			scalar `smean' = `smean' + r(mean)
			scalar `svar'  = `svar'  + r(Var)
			scalar `smin'  = `smin'  + r(min)
			scalar `smax'  = `smax'  + r(max)
			scalar `sn'    = `sn'    + r(N)
			}
		}
	if `nused' == 0 {			// nothing usable: fall back
		qui summarize `varlist' if `touse' `wspec'
		return scalar mean = r(mean)
		return scalar sd   = r(sd)
		return scalar min  = r(min)
		return scalar max  = r(max)
		return scalar N    = r(N)
		exit
		}
	return scalar mean = `smean' / `nused'
	return scalar sd   = sqrt(`svar' / `nused')
	return scalar min  = `smin' / `nused'
	return scalar max  = `smax' / `nused'
	return scalar N    = `sn' / `nused'
end

capture program drop _mec_mipct
program define _mec_mipct, rclass
*_pctile, averaged across imputations under mi
	version 16.0
	syntax varname(numeric) [if] [in] , P(numlist min=2 max=2) /*
		*/ [ MI(integer 0) WSpec(string) ]
	marksample touse, novarlist
	local pa : word 1 of `p'
	local pb : word 2 of `p'

	if `mi' == 0 {
		qui _pctile `varlist' if `touse' `wspec', p(`pa' `pb')
		return scalar r1 = r(r1)
		return scalar r2 = r(r2)
		exit
		}

	local mistyle "`_dta[_mi_style]'"
	local M       "`_dta[_mi_M]'"
	if "`M'" == "" | "`M'" == "0" {
		qui _pctile `varlist' if `touse' `wspec', p(`pa' `pb')
		return scalar r1 = r(r1)
		return scalar r2 = r(r2)
		exit
		}

	tempname s1 s2
	scalar `s1' = 0
	scalar `s2' = 0
	local nused = 0
	forvalues mm = 1/`M' {
		if "`mistyle'" == "wide" {
			capture confirm variable _`mm'_`varlist'
			if _rc == 0  local vv "_`mm'_`varlist'"
			else         local vv "`varlist'"
			capture qui _pctile `vv' if `touse' `wspec', p(`pa' `pb')
			}
		else {
			capture qui _pctile `varlist' if _mi_m == `mm' & `touse' `wspec', p(`pa' `pb')
			}
		if _rc == 0 & !missing(r(r1)) {
			local ++nused
			scalar `s1' = `s1' + r(r1)
			scalar `s2' = `s2' + r(r2)
			}
		}
	if `nused' == 0 {
		qui _pctile `varlist' if `touse' `wspec', p(`pa' `pb')
		return scalar r1 = r(r1)
		return scalar r2 = r(r2)
		exit
		}
	return scalar r1 = `s1' / `nused'
	return scalar r2 = `s2' / `nused'
end

capture program drop _mec_catlabs
program define _mec_catlabs, rclass
	version 16
*Outcome labels, once for all numcats branches
	syntax , NCATS(integer) [OUT1(string) OUT2(string)]
	if `ncats' == 1 {
		return local cat1name ""
		return local cat2name ""
		return local catDname ""
		exit
		}
	return local cat1name "`out1' - "
	return local cat2name "`out2' - "
	if "`out1'" == "`out2'"  return local catDname "`out1' - "
	else                     return local catDname ""
end

capture program drop _mec_atvals
program define _mec_atvals, rclass
	version 16
*at() start/end values (rate/trimrange/groupsd preset earlier; twosd already 2*sd)
	syntax , VAR(string) AMount(string) [BASE(string) SD(string) /*
		*/ HALFsd(string) CENTered]
	if "`amount'" == "one" {
		local delta = 1
		local half  = 1 / 2
		}
	else if "`amount'" == "sd" {
		local delta "`sd'"
		local half  "`halfsd'"
		}
	else {
		local delta "`amount'"
		local half  = `amount' / 2
		}
	if "`base'" == "" {
		if "`centered'" == "" {
			return local startval "`var'=gen(`var')"
			return local endval   "`var'=gen(`var' + `delta')"
			}
		else {
			return local startval "`var'=gen(`var' - `half')"
			return local endval   "`var'=gen(`var' + `half')"
			}
		exit
		}
	if "`centered'" == "" {
		local endat = `base' + `delta'
		return local startval "`var'=`base'"
		return local endval   "`var'=`endat'"
		}
	else {
		local startat = `base' - `half'
		local endat   = `base' + `half'
		return local startval "`var'=`startat'"
		return local endval   "`var'=`endat'"
		}
end

capture program drop _mec_rowlab
program define _mec_rowlab, rclass
*Abbreviate model and level separately to fit the row label
	version 16.0
	syntax , [ CAT(string) MOD(string) LEV(string) WIDth(integer 30) ]

	local rem = `width' - length("`cat'")

*Give the level only the room it needs; remainder to the model name
	local lvout ""
	if "`lev'" == ""  local mw = `rem'
	else {
		local lw = length("`lev'")
		if `lw' > int((`rem' - 1)/2)  local lw = int((`rem' - 1)/2)
		local mw = `rem' - 1 - `lw'
		if length("`lev'") <= `lw'  local lvout "`lev'"
		else if `lw' >= 5           local lvout = abbrev("`lev'",`lw')
		else                        local lvout = substr("`lev'",1,max(`lw',0))
		}
	if length("`mod'") <= `mw'  local mdout "`mod'"
	else if `mw' >= 5           local mdout = abbrev("`mod'",`mw')
	else                        local mdout = substr("`mod'",1,max(`mw',0))

	if "`lvout'" == ""  local out "`cat'`mdout'"
	else                local out "`cat'`mdout' `lvout'"
	if length("`out'") > `width'  local out = substr("`out'",1,`width')
	return local lab "`out'"
end


capture program drop _mec_ebcheck
program define _mec_ebcheck
	*The model must carry e(b); an mi result pooled without post: has none
	version 16.0
	syntax, NAME(string)

	capture confirm matrix e(b)
	if _rc == 0  exit

	*The four mi markers; e(cmd) alone is not enough
	local ebmi = 0
	if "`e(cmd)'" == "mi estimate"        local ebmi = 1
	if "`e(prefix_mi)'" == "mi estimate"  local ebmi = 1
	if "`e(mi)'" == "mi"                  local ebmi = 1
	capture confirm scalar e(M_mi)
	if !_rc                               local ebmi = 1

	if `ebmi' == 1 {
		local ebcl `"`e(cmdline)'"'
		di as err "model {bf:`name'} was pooled without {bf:post}, so it " /*
		*/ "carries no pooled coefficient vector or covariance matrix"
		di as err "refit it as {bf:mi estimate, post:} followed by the same " /*
		*/ "estimation command, then store it again; {cmd:mecompare} reads " /*
		*/ "the predictors from e(b), on either engine"
		if trim(`"`ebcl'"') != "" {
			di as err `"for `name' that is: mi estimate, post: `ebcl'"'
			}
		di as err "note {bf:mi estimate, saving()} and a plain " /*
		*/ "{bf:mi estimate:} both leave e(b) empty, and the saved file " /*
		*/ "cannot be used to recover it"
		exit 322
		}

	*Not mi and no e(b): name what was looked for
	di as err "model {bf:`name'} carries no coefficient vector e(b), so " /*
	*/ "{cmd:mecompare} cannot read which predictors it holds"
	exit 111
end

capture program drop _mec_annotate
program define _mec_annotate, rclass
	*Annotate a plain varlist with the model's factor prefixes; user tokens pass through
	version 16.0
	syntax, USERvars(string) MODELivs(string)
	local out ""
	foreach uv of local uservars {
		local base = subinstr("`uv'", "i.", "", .)
		local base = subinstr("`base'", "c.", "", .)
		local slen = length(".`base'")
		local ftoken ""
		foreach t of local modelivs {
			if "`ftoken'" == "" {
				local tlen = length("`t'")
				if `tlen' > `slen' {
					if substr("`t'", `tlen'-`slen'+1, `slen') == ".`base'" ///
					   & substr("`t'",1,1) == "i" {
						local ftoken "`t'"
						}
					}
				}
			}
		if "`ftoken'" != "" {
			local out "`out' `ftoken'"
			}
		else {
			local out "`out' `base'"
			}
		}
	return local annotated = trim(itrim("`out'"))
end

capture program drop _mec_addz
program _mec_addz, sclass

    version 11.2
    
    syntax , MATrix(string) rowname(string) [ top ]
    tempname matinsert mattemp

    capture confirm matrix `matrix'
    if (_rc == 0) {
        * ok
    }
    else {
        display as error "matrix `matrix' does not exist"
        exit 198
    }
    local nrows = rowsof(`matrix')
    local ncols = colsof(`matrix')
    local colnms : colfullnames `matrix', // quoted

    mat `matinsert' = J(1,`ncols',.z)
    mat colnames `matinsert' = `colnms'    
    mat rownames `matinsert' = "`rowname'"

    if "`top'"=="top" {
        mat `mattemp' = `matinsert' \ `matrix'
    }
    else {
        mat `mattemp' = `matrix' \ `matinsert'
    }
    mat `matrix' = `mattemp'
end	
	
	
* version 0.1.1 2018-11-02 | mize long
//  add effect number to last column
capture program drop _mec_number
program define _mec_number

    version 11.2
    syntax , matrix(string) label(string)

//  get matrix information
    capture confirm matrix `matrix'
    if (_rc == 0) {
        * ok
    }
    else {
        display as error "matrix `matrix' does not exist"
        exit 198
    }
    local nrows = rowsof(`matrix')
    local ncols = colsof(`matrix')

//  create matnum filled with .z and col label `label'
    tempname matn
    matrix `matn' = J(`nrows',1,.z)
    matrix colname `matn' = `label'

//  loop through column 1 of matrix to check if not .z
    tempname val
    local counter = 0
    forvalues i = 1(1)`nrows' {

        scalar `val' = `matrix'[`i',1]
        if `val'!=.z {
            local ++counter
            matrix `matn'[`i',1] = `counter'
        }
    }
//  attach column to matrx
    matrix `matrix' = `matrix', `matn'

end


// Below is a private copy of Nick Cox's matselrc command //
// Putting here so that mecompare.ado can call it even if users do not 
// have matselrc installed. v0.2.45: renamed _mec_matselrc so that loading
// mecompare.ado cannot replace a user's own or installed matselrc 

* NJC 1.1.0 20 Apr 2000  (STB-56: dm79)
capture program drop _mec_matselrc
program def _mec_matselrc
* NJC 1.0.0 14 Oct 1999 
        version 6.0
        gettoken m1 0 : 0, parse(" ,")
        gettoken m2 0 : 0, parse(" ,") 
	
	if "`m1'" == "," | "`m2'" == "," | "`m1'" == "" | "`m2'" == "" { 
		di in r "must name two matrices" 
		exit 198
	} 
	
        syntax , [ Row(str) Col(str) Names ]
        if "`row'`col'" == "" {
                di in r "nothing to do"
                exit 198
        }

        tempname A B 
        mat `A' = `m1' /* this will fail if `matname' not a matrix */
	local cols = colsof(`A') 
	local rows = rowsof(`A') 

        if "`col'" != "" {
		if "`names'" != "" { local colnum 1 } 
		else { 
	                capture numlist "`col'", int r(>0 <=`cols')
			if _rc == 0 { local col "`r(numlist)'" } 
                	else if _rc != 121 { 
				local rc = _rc 
				error `rc' 
			} 	
			local colnum = _rc == 0 
		}	
		/* colnum = 1 for numbers, 0 for names */ 

		tokenize `col' 
		local ncols : word count `col' 
		if `colnum' { 
			mat `B' = `A'[1..., `1'] 
			local j = 2 
			while `j' <= `ncols' { 
                		mat `B' = `B' , `A'[1..., ``j'']
				local j = `j' + 1 
			} 	
		} 
		else {
			mat `B' = `A'[1..., "`1'"] 
			local j = 2 
			while `j' <= `ncols' { 
                		mat `B' = `B' , `A'[1..., "``j''"]
				local j = `j' + 1 
			} 	
		} 
		mat `A' = `B' 	
		local cols = colsof(`A')  		
        }
	
	if "`row'" != "" {
		if "`names'" != "" { local rownum 0 } 
		else { 
	                capture numlist "`row'", int r(>0 <=`rows')
			if _rc == 0 { local row "`r(numlist)'" } 
                	else if _rc != 121 { 
				local rc = _rc 
				error `rc' 
			} 	
			local rownum = _rc == 0   
		} 	
		/* rownum = 1 for numbers, 0 for names */ 

		tokenize `row' 
		local nrows : word count `row' 
		if `rownum' { 
			mat `B' = `A'[`1', 1...] 
			local j = 2 
			while `j' <= `nrows' { 
                		mat `B' = `B' \ `A'[``j'', 1...]
				local j = `j' + 1 
			} 	
		} 
		else {
			mat `B' = `A'["`1'", 1...] 
			local j = 2 
			while `j' <= `nrows'  { 
                		mat `B' = `B' \ `A'["``j''", 1...]
				local j = `j' + 1 
			} 	
		} 
		mat `A' = `B' 	
        }
	
        mat `m2' = `A'
end
	

exit
	
	
	