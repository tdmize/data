// Inequality stats for nominal independent variable's effects
capture program drop meinequality
*! meinequality v1.8.8 Bing Han & Trenton Mize 2026-09-02  | history: CHANGELOG-meinequality.md (repo)

program define meinequality, rclass
	
version 16

syntax 	varlist(fv) [if] [in] [fweight pweight iweight] , ///
		[MODels(string) ///
		WEIghted ///
		UNWeighted ///
		all /// 
		ATMEANs ///
		GROUPs ///
		GROUPNames(string) /// 
		DECimals(string) /// 
		title(string) /// 
		ci /// 
		LABWidth(numlist integer) /// 
		DETAILs /// 
		COMMANDs /// 
		level(integer 95) /// 
		by(string) ///
		over(string) ///
		ENGine(string) ///
		] 	

marksample touse

*The suest2 package is a PREREQUISITE and must be installed
local meimissing ""
foreach meireq in suest2 _mec_canonical mec_share mec_wcheck mec_gsem _mec_omitchk _mec_prefix {
	capture which `meireq'
	if _rc  local meimissing "`meimissing' `meireq'"
	}
if "`meimissing'" != "" {
	di _newline(1)
	di as err "{cmd:meinequality} requires the {cmd:suest2} package, which "  /*
	*/ "is missing or incomplete. Not found:`meimissing'. Install or "  /*
	*/ "update {cmd:suest2} and try again."
	exit 199
	}

*Engine: suest2 (default) combines the stored estimates; gsem is undocumented and refits
local engine = lower(trim("`engine'"))
if "`engine'" == ""  local engine "suest2"
if "`engine'" != "suest2" & "`engine'" != "gsem" {
	di _newline(1)
	di as err "{opt engine()} must be {opt suest2} or {opt gsem}."
	exit 198
	}

*Store the system under the engine's name; drop the other engine's name
local meisys "meineq_suest2"
local meisysalt "meineq_gsem"
if "`engine'" == "gsem" {
	local meisys "meineq_gsem"
	local meisysalt "meineq_suest2"
	}

*Second marker: if/in only (under mi the varlist's missings are the imputed obs)
tempvar mecshsamp
marksample mecshsamp, novarlist
		
****************************************************************************
// Set overall options
****************************************************************************	

*Show estimation details; meishow prefixes the combine call, which runs under capture and is silent unless noisily
if "`details'"!=""{
	local quietly ""
	local meishow "noisily"
}
else {
	local quietly "quietly"
	local meishow "quietly"
}

*Display options; labwidth 20-32 refused with a message
if "`labwidth'" == "" {
	local twidth = 24
}
else {
	capture confirm integer number `labwidth'
	if _rc | !inrange(real("`labwidth'"), 20, 32) {
		di _newline(1)
		di as err "{opt labwidth()} must be an integer between 20 and 32. " /*
		*/ "To fit longer names, use shorter names in {opt models()} or " /*
		*/ "{opt groupnames()}."
		exit 198
	}
	local twidth = `labwidth'
}

if "`title'"==""{
	local title "ME Inequality Estimates"
}
else {
	local title "`title'"
}  	

*decimals must be an integer 0-7
if "`decimals'" == "" {
	local decimals = 3
}
else {
	capture confirm integer number `decimals'
	if _rc | !inrange(real("`decimals'"), 0, 7) {
		di _newline(1)
		di as err "{opt decimals()} must be an integer between 0 and 7."
		exit 198
	}
}

if "`level'" == "" {
	local level = 95
	local ll_spec "95% LL" 
	local ul_spec "95% UL"		
}
else {
	local level = `level'
	local ll_spec "`level'% LL" 
	local ul_spec "`level'% UL"
}
	
if "`atmeans'" == "" {
	local atmeans ""
}
else {
	local atmeans "atmeans"
}

	
****************************************************************************
// Set options for different # of models
****************************************************************************

*Supported models resolved by _mec_canonical
			
*Check # of models
local nummods: word count `models'

*Error out if 3 or more models are specified
if `nummods' > 2 {
	di _newline(1)
	di as err "Invalid number of models specified in {opt models()} option. " /*
	*/ "{cmd:meinequality} can only be used with one or two models."
	exit 198	
} 

*Error out if group specified incorrectly
if "`groups'" != "" & `nummods' == 1 {
	di _newline(1)
	di as err "The {opt groups} option requires two models to be specified in " /*
	*/ "the {opt models()} option -- one for each group. See " /*
	*/ "{help meinequality##groups}."
*groups needs two models; refuse
	exit 198
}		

*Set model names in the table
if "`groupnames'" != "" & "`groups'" == "" {
	di _newline(1)
	di as err "The {opt groupnames} option requires two different models " /*
	*/ "to be specified using the {opt groups()} option. " /*
	*/ "See {help meinequality##groupnames}."
	exit 198	
}

if "`groupnames'" == "" {
	local mod1name : word 1 of `models'
	local mod2name : word 2 of `models'
}
else {
	local mod1name : word 1 of `groupnames'
	local mod2name : word 2 of `groupnames'
}

local mod1lab = substr("`mod1name'",1,10)
local mod2lab = substr("`mod2name'",1,10)

*Set weight specification 
if "`weight'" != "" {
	if `nummods' == 2 {
		local weightspec = "[`weight' `exp']"
	}
	*A weight may restate the model's weight but not contradict it
	else if `nummods' == 1 {
		local weightspec = "[`weight' `exp']"
	}
} 

*Only one weighting may be requested
local nwopt = ("`weighted'" != "") + ("`unweighted'" != "") + ("`all'" != "")
if `nwopt' > 1 {
	di _newline(1)
	di as err "Specify only one of {opt weighted}, {opt unweighted}, or " /*
	*/ "{opt all}."
	exit 198
}

*Save models
if `nummods' == 1 | `nummods' == 2 {
	forvalues i = 1/`nummods' {
		local mod`i': word `i' of `models'
	}
}
else if `nummods' == 0 {
	quietly est store meineq_mod1
	local mod1 meineq_mod1
	local nummods = 1
}

*Restore mod1
quietly est restore `mod1'

local cmd_m1 "`e(cmd)'"
local cmdline_m1 "`e(cmdline)'"
local vcetype1	= "`e(vce)'"
qui tempvar mod1samp
*Under mi, e(sample) is unset; if/in alone is the sample
_mei_ismi
local mei_ismi1 = r(ismi)
local mei_under1 "`r(under)'"
if `mei_ismi1' == 1  qui gen `mod1samp' = 1
else                             qui gen `mod1samp' = e(sample)

*Sample the level proportions are taken over
local psamp1 "`mod1samp'"
local psamp2 "`mod1samp'"
*Levels are read from the estimation sample (all data if it is empty)
local levsamp "`mod1samp' == 1 & `mecshsamp'"
qui count if `levsamp'
if r(N) == 0  local levsamp "1"
local Nsav1 = e(N)
local mod1dv = 	"`e(depvar)'"
local ifweight1 = "`e(wexp)'"
local ifwtype1 = "`e(wtype)'"
local prefix1 = "`e(prefix)'"

*A pweighted multilevel model needs the higher-level pweight(); same gate as suest2's
if `nummods' == 1 {
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
	}

*One model with its own weight: inherit it for the level proportions
if `nummods' == 1 & "`weight'" == "" & "`ifweight1'" != "" & "`prefix1'" != "svy" {
	local weightspec "[`ifwtype1' `ifweight1']"
}
if `nummods' == 1 & "`weight'" != "" {
	mec_wcheck, gweight(`weight') gexp(`exp') mwtype(`ifwtype1') /*
		*/ mwexp(`ifweight1') prefix(`prefix1') cmd(meinequality)
}

*Level shares from mec_share (works under mi; pweight maps to aweight)
local mecwspec ""
if "`weightspec'" != ""      local mecwspec = /*
	*/ subinstr("`weightspec'", "pweight", "aweight", 1)
else if "`ifweight1'" != ""  local mecwspec "[aweight `ifweight1']"
local mecismi = `mei_ismi1'
local margins "margins"
*Name of the r() result that holds the margins command line
local marginscmdline "cmdline"

if `mei_ismi1' == 1 {

	capture which mimrgns
		if (_rc) {
		di _newline(1)
		di as err "{cmd:meinequality} requires the user-written package " /*
		*/ "{cmd:mimrgns}. Click the link below to search for " /*
		*/ "and install {cmd:mimrgns}: {stata search mimrgns: {bf:mimrgns}}."
		exit 198
		}

	capture confirm scalar e(N_mi)
	if !_rc  local Nsav1 = e(N_mi)
	local cmd_m1 "`mei_under1'"
	if "`e(prefix_mi)'" != ""  local prefix1 = "`e(prefix_mi)'"
	local margins "mimrgns"
	local mimarginsspec "predict(default) errorok esampvaryok"
	local marginscmdline "est_cmdline_margins"
}	

	
*Resolve model 1 through _mec_canonical; r(spec) = margins stripe
local mei_raw "`e(cmd)'"
if "`cmd_m1'" != "" & "`cmd_m1'" != "mi estimate"  local mei_raw "`cmd_m1'"
_mec_canonical, cmd("`mei_raw'") cmd2("`e(cmd2)'") model("`e(model)'") /*
	*/ distrib("`e(distrib)'") method("`e(method)'") estimator("`e(estimator)'")
local mei_canon "`r(canon)'"
local mei_ok    = r(ok)
local mei_spec  = r(spec)
if "`mei_canon'" != ""  local cmd_m1 "`mei_canon'"

if `mei_ok' == 0 {
	di _newline(1)
	di as err "`mod1' is a {cmd:`mei_raw'}, which {cmd:meinequality} does " /*
	*/ "not support."
	exit 198
	}
	
*Outcome categories keyed on the command name (e(k_eq) cannot say)
if "`cmd_m1'" == "ologit" | "`cmd_m1'" == "oprobit" | "`cmd_m1'" == "gologit2" /*
	*/ | "`cmd_m1'" == "meologit" | "`cmd_m1'" == "meoprobit" /*
	*/ | "`cmd_m1'" == "xtologit" | "`cmd_m1'" == "xtoprobit" {
	local mod1cats = e(k_cat)
	}
else if "`cmd_m1'" == "mlogit" {
	local mod1cats = e(k_eq)
	}
else if "`cmd_m1'" == "xtmlogit" {
*xtmlogit reads e(k_out)
	local mod1cats = e(k_out)
	}
else {
	local mod1cats = 1
	}

*Restore mod2
if `nummods' == 2 {
	qui est restore `mod2'
	local cmd_m2 "`e(cmd)'"
*Resolve model 2 through _mec_canonical too
	_mec_canonical, cmd("`cmd_m2'") cmd2("`e(cmd2)'") model("`e(model)'") /*
		*/ distrib("`e(distrib)'") method("`e(method)'") estimator("`e(estimator)'")
	local mei_canon2 "`r(canon)'"
	local mei_ok2    = r(ok)
	local mei_spec2  = r(spec)
	if "`mei_canon2'" != ""  local cmd_m2 "`mei_canon2'"
	if `mei_ok2' == 0 {
		di _newline(1)
		di as err "`mod2' is a {cmd:`e(cmd)'}, which {cmd:meinequality} does " /*
		*/ "not support."
		exit 198
		}
*The two models must agree about the stripe
	if "`mei_spec'" != "" & `mei_spec' != `mei_spec2' {
		di _newline(1)
		di as err "`mod1' and `mod2' produce marginal predictions labelled " /*
		*/ "differently, so they cannot be combined by {cmd:meinequality}."
		exit 198
		}
	local cmdline_m2 "`e(cmdline)'"
	local vcetype2	= "`e(vce)'"
	qui tempvar mod2samp
	*Under mi, e(sample) is unset; if/in alone is the sample
_mei_ismi
local mei_ismi2 = r(ismi)
local mei_under2 "`r(under)'"
if `mei_ismi2' == 1  qui gen `mod2samp' = 1
else                             qui gen `mod2samp' = e(sample)
	local Nsav2 = e(N)	
	local ifweight2 = "`e(wexp)'"
	local ifwtype2 = "`e(wtype)'"
	local prefix2 = "`e(prefix)'"
	
	if `mei_ismi2' == 1 {
		local cmd_m2 "`mei_under2'"
		if "`e(prefix_mi)'" != ""  local prefix2 = "`e(prefix_mi)'"
		capture confirm scalar e(N_mi)
		if !_rc  local Nsav2 = e(N_mi)
	}	
	
*Which model's sample each observation belongs to (a tempvar)
	tempvar meisamp
	quietly gen `meisamp' = .
	quietly replace `meisamp' = 1 if `mod1samp' == 1
	quietly replace `meisamp' = 2 if `mod2samp' == 1
	local levsamp "`meisamp' < . & `mecshsamp'"
	qui count if `levsamp'
	if r(N) == 0  local levsamp "1"
			
	quietly count if `meisamp' == 1
	local Nsav1_ovlp = `r(N)'
	
	*Error out if group number is not consistent with the e(sample)
	if "`groups'" != "" & (`Nsav1_ovlp'!=`Nsav1') {
		di _newline(1)
		di as err "{opt groups} option does not support partially overlapping " /*
		*/ "samples. With the {opt groups} option, samples must be entirely " /*
		*/ "distinct across models. See {help meinequality##groups} for details."
		exit 198		
	}
		
	*Error out if command1 != command2
	if "`cmd_m1'" != "`cmd_m2'" {
		di _newline(1)
		di as err "`mod1' is a {cmd:`cmd_m1'}; `mod2' is a {cmd:`cmd_m2'}. " /*
		*/ "{cmd:meinequality} doesn't support different models."
	exit 198
	}
	
	*gologit2 pair refused under engine(gsem) only
	if ("`cmd_m1'" == "gologit2" | "`cmd_m2'" == "gologit2") /*
		*/ & "`engine'" == "gsem" {
		di _newline(1)
		di as err "{cmd:gologit2} is not supported for comparing across two " /*
		*/ "models with {opt engine(gsem)}. That engine uses {cmd:gsem} to " /*
		*/ "combine model estimates and {cmd:gologit2} estimates cannot be " /*
		*/ "replicated with {cmd:gsem}. The default engine does not refit and " /*
		*/ "supports this pair."
		exit 198		
	}
	
*Same branch as model 1, keyed on the canonical name
	if "`cmd_m2'" == "ologit" | "`cmd_m2'" == "oprobit" | "`cmd_m2'" == "gologit2" /*
		*/ | "`cmd_m2'" == "meologit" | "`cmd_m2'" == "meoprobit" /*
		*/ | "`cmd_m2'" == "xtologit" | "`cmd_m2'" == "xtoprobit" {
		local mod2cats = e(k_cat)
	}
	else if "`cmd_m2'" == "mlogit" {
		local mod2cats = e(k_eq)
		}
	else if "`cmd_m2'" == "xtmlogit" {
		local mod2cats = e(k_out)
		}
	else {
		local mod2cats = 1
		}
	
	*Refuse differing outcome counts across the models
	if `mod1cats' > 1 | `mod2cats' > 1 {
		if `mod1cats' != `mod2cats' {
		di _newline(1)
		di as err "Numbers of outcome categories differ across models `mod1' " /*
		*/ "and `mod2'. {cmd:meinequality} can only be used with `cmd_m1' when the " /*
		*/ "number of outcome categories is the same across both models."
		exit 198
		}	
	}	
	

*Coefficient crosswalk: spec 0 = N._predict#, spec 1 = <store>: equation labels
	local meispec = 0
	if "`mei_spec'" != "" & `mei_spec' == 1  local meispec = 1

	if `mod1cats' == 1 {
		local prnum1 "1._predict#"
		local prnum2 "2._predict#"
		if `meispec' == 1 {
			local prnum1 "`mod1':"
			local prnum2 "`mod2':"
			}
		}
	else {
		forvalues meiout = 1/`mod1cats' {
			local prnum1_`meiout' "`meiout'._predict#"
			local meimarg = `meiout' + `mod1cats'
			local prnum2_`meiout' "`meimarg'._predict#"
			if `meispec' == 1 {
				local prnum1_`meiout' "`mod1':`meiout'._predict#"
				local prnum2_`meiout' "`mod2':`meiout'._predict#"
				}
			}
		}

*The over() level suffix is cleared where it is set, inside the calculation blocks

*Two-model prefixes: equation = store name; model 2 restarts outcome numbering; no predict spec passed

*groups with a multi-outcome specialized model is refused
	if `meispec' == 1 & "`groups'" != "" & `mod1cats' != 1 {
		di _newline(1)
		di as err "{opt groups} is not yet supported for multi-outcome " /*
		*/ "models of this type ({cmd:`cmd_m1'}). Compare the groups " /*
		*/ "separately for now."
		exit 198
		}

	*Remove model options
	local ifcomma = strpos("`cmdline_m1'", ",") 
	local cmdline_m1_vce = "`cmdline_m1'"
	
	if `ifcomma' == 0 {
		local cmdline_m1 = "`cmdline_m1'"
	}
	else {	
		local cmdline_m1 = substr("`cmdline_m1'", 1, `ifcomma' - 1) 
		local cmdline_m1_vce = substr("`cmdline_m1_vce'", `ifcomma' + 1, `ifcomma' + 7)		
		local cmdline_m1_vce = strtrim("`cmdline_m1_vce'")
		if "`cmdline_m1_vce'" != "vce(robust)" {
			di in red "{cmd:meinequality} shows each model's command line without " /*
			*/ "its options. Estimation uses `mod1' exactly as it was stored; " /*
			*/ "nothing is refitted and no option is discarded."			
		}
	}		
	
	local ifcomma = strpos("`cmdline_m2'", ",")  
	local cmdline_m2_vce = "`cmdline_m2'"
	if `ifcomma' == 0 {
		local cmdline_m2 = "`cmdline_m2'"
	}
	else {	
		local cmdline_m2 = substr("`cmdline_m2'", 1, `ifcomma' - 1) 
		local cmdline_m2_vce = substr("`cmdline_m2_vce'", `ifcomma' + 1, .)
		local cmdline_m2_vce = strtrim("`cmdline_m2_vce'")
		if "`cmdline_m2_vce'" != "vce(robust)" {
			di in red "{cmd:meinequality} shows each model's command line without " /*
			*/ "its options. Estimation uses `mod2' exactly as it was stored; " /*
			*/ "nothing is refitted and no option is discarded."			
		}		
	}
	
	local cmdline_m1_show = "`cmdline_m1'"
	local cmdline_m2_show = "`cmdline_m2'"

*Strip the || part first; its colon is not a prefix
	local mpipe = strpos("`cmdline_m1'", "||")
	if `mpipe' != 0  local cmdline_m1 = substr("`cmdline_m1'", 1, `mpipe' - 1)
	local mpipe = strpos("`cmdline_m2'", "||")
	if `mpipe' != 0  local cmdline_m2 = substr("`cmdline_m2'", 1, `mpipe' - 1)

	*Strip any prefix before reading DV/IVs by position (after _show is set)
	local mcolon = strpos("`cmdline_m1'", ":")
	if `mcolon' != 0  local cmdline_m1 = substr("`cmdline_m1'", `mcolon' + 1, .)
	local mcolon = strpos("`cmdline_m2'", ":")
	if `mcolon' != 0  local cmdline_m2 = substr("`cmdline_m2'", `mcolon' + 1, .)

	*Strip a [weight]; it precedes the options comma
	local cmdline_m1 = regexr("`cmdline_m1'", "\[[^]]*\]", "")
	local cmdline_m2 = regexr("`cmdline_m2'", "\[[^]]*\]", "")

	*Remove if option
	local ifif = strpos("`cmdline_m1'", " if ") 
	if `ifif' == 0 {
		local cmdline_m1 = "`cmdline_m1'"
	}
	else {	
		local cmdline_m1 = substr("`cmdline_m1'", 1, `ifif') 
	}	
	
	local ifif = strpos("`cmdline_m2'", " if ") 
	if `ifif' == 0 {
		local cmdline_m2 = "`cmdline_m2'"
	}
	else {	
		local cmdline_m2 = substr("`cmdline_m2'", 1, `ifif') 
	}	
	
	*Remove in option	
	local ifin = strpos("`cmdline_m1'", " in ") 
	
	if `ifin' == 0 {
		local cmdline_m1 = "`cmdline_m1'"
	}
	else {	
		local cmdline_m1 = substr("`cmdline_m1'", 1, `ifin') 
	}	
	
	local ifif = strpos("`cmdline_m2'", " in ") 
	
	if `ifin' == 0 {
		local cmdline_m2 = "`cmdline_m2'"
	}
	else {	
		local cmdline_m2 = substr("`cmdline_m2'", 1, `ifin') 
	}
	
	*Two models with the same weight combine under it; differing weights are refused (svy exempt)
	local wtinherit = 0
	*A weight here may restate the models' weight but not contradict it
	if "`weight'" != "" {
		mec_wcheck, gweight(`weight') gexp(`exp') mwtype(`ifwtype1') /*
			*/ mwexp(`ifweight1') prefix(`prefix1') cmd(meinequality)
		mec_wcheck, gweight(`weight') gexp(`exp') mwtype(`ifwtype2') /*
			*/ mwexp(`ifweight2') prefix(`prefix2') cmd(meinequality)
		}

	if ("`ifweight1'" != "" & "`prefix1'" != "svy") | ///
	   ("`ifweight2'" != "" & "`prefix2'" != "svy") {
		if "`weight'" == "" {
			if "`ifweight1'" != "`ifweight2'" | "`ifwtype1'" != "`ifwtype2'" {
				di _newline(1)
				di as err "The two models were fit with different weights, " /*
				*/ "so they cannot be combined. Refit them with the same " /*
				*/ "weight, or give the weight to {cmd:meinequality} directly."
				exit 198
			}
			local weightspec "[`ifwtype1' `ifweight1']"
			local wtinherit = 1
		}
	}
	
	*Two-model svy: both models must be svy:
	if "`prefix1'" == "svy" | "`prefix2'" == "svy" {
		if "`prefix1'" != "`prefix2'" {
			di _newline(1)
			di as err "One model uses the {opt svy:} prefix and the other " /*
			*/ "does not; both models must be {opt svy:} (or neither)."
			exit 198
		}
		local weightspec ""
	}
	
	if "`prefix1'" == "mi estimate" | "`prefix2'" == "mi estimate" {
		
		if "`prefix1'" != "`prefix2'" {
			di _newline(1)
			di as err "The prefixes do not match in the two models. " /*
			*/ "The prefix for `mod1' is `prefix1', and the prefix for `mod2' is `prefix2'."
			exit 198
		}
	}
	
	*Any other prefix is refused with two models
	if "`prefix1'" != "mi estimate" & "`prefix1'" != "svy" & "`prefix1'" != "" {
		di _newline(1)
		di as err "{cmd:meinequality} does not support the `prefix1' prefix " /*
		*/ "when two models are specified."
		exit 198		
	}
	
	*Strip the model options after comma
	forvalues ifnum = 1/2 {
	local ifcomma = strpos("`cmdline_m`ifnum''", ",")  
	if `ifcomma' == 0 {
		local cmdline_m`ifnum' = "`cmdline_m`ifnum''"
	}
	else {	
		local cmdline_m`ifnum' = substr("`cmdline_m`ifnum''", 1, strpos("`cmdline_m`ifnum''", ",") - 1) 
	}		
	}
	
	*Warn if vce(robust) was not used on the stored models
	if "`vcetype1'" != "robust" | "`vcetype2'" != "robust" {
		di in red "{cmd:meinequality} uses vce(robust) for both models. " /*
		*/ "Standard errors from {cmd:meinequality} will differ from the " /*
		*/ "specified models because vce(robust) was not used on at " /*
		*/ "least one of the models specified in the {it:models( )} " /*
		*/ "option. We strongly recommend refitting the models with " /*
		*/ "vce(robust) to ensure the {cmd:meinequality} results match " /*
		*/ "those from the first ({cmd:`cmd_m1'}) and second ({cmd:`cmd_m2'}) " /*
		*/ "models exactly. See {help vce_option} for details on vce(robust)."
		}	
	
} // end: check for two-model situation

****************************************************************************
// Check by over varaibles
****************************************************************************

** check the by/over options
if "`by'" != "" & "`over'" != "" {
	di _newline(1)
	di as err "{opt by()} and {opt over()} option cannot be specified at the same time."
	exit 198	
}

if "`by'" != "" | "`over'" != "" {

	** check numbers of by/over var
	local numbyvar : word count `by'
	local numovervar : word count `over'

	if `numbyvar' > 1 {
		di _newline(1)
		di as err "Invalid number of variables specified in {opt by()} option. " /*
		*/ "{opt by()} can only be used with one variable."
		exit 198	
	}

	if `numovervar' > 1 {
		di _newline(1)
		di as err "Invalid number of variables specified in {opt over()} option. " /*
		*/ "{opt over()} can only be used with one variable."
		exit 198	
	}

	** check if by/over var is nominal variable
	if "`by'" != "" {
		local byvar "`by'"
		local byovervar "`by'"
		if strpos("`byvar'", "i.") == 0 {
			local i_byvar i.`byvar'
		}
		else {
			local i_byvar `byvar'
		}		
		if strpos("`cmdline_m1'","`i_byvar'") == 0 { 
			di _newline(1)
			di as err "Variable `byvar' not found in the model. " /*
			*/ "Only nominal variable can be specified in {opt by()} option." /*	
			*/ "Check if i. prefix is used for the nominal variable in the model." 
			exit 198
		}
		
		local byvarspec "`byvar'#"
	}

	if "`over'" != "" {
		local overvar "`over'"	
		local byovervar "`over'"
		if strpos("`overvar'", "i.") == 0 {
			local i_overvar i.`overvar'
		}
		else {
			local i_overvar `overvar'
			local overvar = subinstr("`overvar'", "i.","",.)
		}	
		if strpos("`cmdline_m1'","`i_overvar'") == 0 { 
			di _newline(1)
			di as err "Variable `overvar' not found in the model. " /*
			*/ "Only nominal variable can be specified in {opt over()} option." /*	
			*/ "Check if i. prefix is used for the nominal variable in the model." 
			exit 198
		}
		local overvarspec "over(`overvar')"
	}

	** all levels of the by/over variable

	qui 	levelsof 		`byovervar' if `levsamp'
	local 	byoverlvl 		`r(levels)'
	local 	numbyoverlvl	`r(r)'	
	local  	labname : value label `byovervar'	
	
}

else{
	
	local numbyoverlvl = 1
	
}
	
****************************************************************************
// Check nominal independent variables to be estimated
****************************************************************************

*Check the number for the focal ivs
local numvars : word count 	`varlist'

if `numvars' == 0 {
	di _newline(1)
	di as err "Specify independent nominal variable. " /*
	*/ "{cmd:meinequality} can be used with at least one independent nominal variable."
	exit 198	
} 

forvalues ithvar=1/`numvars' {
		
	local nomvar : 	word `ithvar' of `varlist'
	
	if strpos("`nomvar'", "i.") == 0 {
		local i_nomvar i.`nomvar'
	}
	else {
		local i_nomvar `nomvar'
	}
			
	if `nummods' == 1 {
		if strpos("`cmdline_m1'","`i_nomvar'") == 0 { 
			di _newline(1)
			di as err "Variable `nomvar' not found in the model. " ///
			"See if i. prefix is used for the nominal variable in the model."
			exit 198
		}
	}
	else if `nummods' == 2 {
		if strpos("`cmdline_m1'","`i_nomvar'") == 0 | ///
		strpos("`cmdline_m2'","`i_nomvar'") == 0 { 
			di _newline(1)
			di as err "Variable `nomvar' not found in the model. " ///
			"See if i. prefix is used for the nominal variable in the model."
			exit 198
		}		
	}
}

** return scalars

return scalar n_mods = `nummods'
return scalar n_vars = `numvars'
	
****************************************************************************
// Model specification
****************************************************************************

if `nummods' == 1 {
	local samp1_size = e(N)

	di 		as text "Model (`mod1') is:"
	di 		as result "     `cmdline_m1'"
}

else if `nummods' == 2 {
	
	*Include model specs. in output
	di 		_newline(1)

	local 	mod1specs "`cmdline_m1_show'"
	local 	mod2specs "`cmdline_m2_show'"

	if `wtinherit' == 1 {
		di _newline(1)
		di in red "NOTE: no weight was given to {cmd:meinequality}, so the " /*
		*/ "weight from the stored models ([`ifwtype1' `ifweight1']) is " /*
		*/ "applied to the combined fit."
		}
	di 		as text "Model 1 (`mod1') is:"
	di 		as result "     `mod1specs'"
	di 		as text "Model 2 (`mod2') is:"
	di 		as result "     `mod2specs'"

	*Combine the stored estimates; nothing is refitted
	if "`groups'" == "" & `Nsav1' != `Nsav2' {
		di _newline(1)
		di as text "NOTE: the models were fit on different numbers of "  /*
		*/ "observations (N_`mod1'=`Nsav1'; N_`mod2'=`Nsav2'). Each model "  /*
		*/ "keeps its own sample; the estimates match the models as fit."
		}

	*Error out if either model has no observations
	if `Nsav1' == 0 | `Nsav2' == 0 {
		di _newline(1)
		di as err "`mod1' has `Nsav1' observations and `mod2' has `Nsav2'. "  /*
		*/ "{cmd:meinequality} cannot combine a model with no observations."
		exit 2000
		}

	if "`engine'" == "suest2" {
*details shows the suest2 output: capture noisily under details, capture quietly otherwise
		capture `meishow' suest2 `mod1' `mod2', nowarn
		local combrc = _rc
		if `combrc' != 0 {
			di _newline(1)
			di as err "{cmd:suest2} could not combine `mod1' and `mod2' "  /*
			*/ "(rc `combrc'). Its own message follows."
*Repeat the failing call noisily, then pass the code up
			capture noisily suest2 `mod1' `mod2', nowarn
			exit `combrc'
			}
		}
	else {
		local g_groups ""
		local g_samp ""
		if "`groups'" != "" {
			local g_groups "groups"
			local g_samp "sampvar(`meisamp')"
			}
		capture `meishow' mec_gsem `mod1' `mod2' `weightspec', /*
			*/ `g_groups' `g_samp' `quietly'
		local combrc = _rc
		if `combrc' != 0 {
			di _newline(1)
			di as err "{cmd:engine(gsem)} could not combine `mod1' and "  /*
			*/ "`mod2' (rc `combrc'). Its own message follows."
			capture noisily mec_gsem `mod1' `mod2' `weightspec', /*
				*/ `g_groups' `g_samp'
			exit `combrc'
			}
		}

	*Level proportions from each model's own sample
	local psamp1 "`mod1samp'"
	local psamp2 "`mod2samp'"
	
	capture estimates drop `meisysalt'
	quietly est store `meisys'

*Capture suest2's private-copy names now; labelled at end of program
local meiholdn ""
local meiholdw ""
if "`engine'" != "gsem" {
	local meiholdn `"`e(suest2_holds)'"'
	local __nh : word count `meiholdn'
	forvalues __h = 1/`__nh' {
		local __mn "suest2_model`__h'"
		local meiholdw `"`meiholdw' `e(`__mn')'"'
		}
	}
*No predict spec on the non-mi path; mi keeps its own (mimrgns needs it)
	if `mecismi' == 0  local mimarginsspec ""
	
*Ns from the stored models
	local samp1_size = `Nsav1'
	local samp2_size = `Nsav2'

	*commands option prints the engine's combined-model syntax
	if "`commands'" != "" {
		di as text "`engine' model is: "
		di as result "     `e(cmdline)'"
	}
	
}	// End of model specification


	
****************************************************************************
// Calculation of ME inequality stats: prep
****************************************************************************

** temp list for matrix and estimations
tempname newmatmean newmatwgt newmatall newmatall_m newmatall_uw rtable
tempname rt rb rV	

local newmatall "full_matrix"
local newmatall_w "weighted_null_matrix"
local newmatall_uw "unweighted_null_matrix"
local rtable "rtable"

** generate a nullmat for all 
matrix `newmatall' = J(1, 6, .)
matrix `newmatall_w' = J(1, 6, .)
matrix `newmatall_uw' = J(1, 6, .)
matrix `rtable' = J(1, 6, .)
		
** calculate the meinequality for each nominal variable separately 
forvalues ithvar=1/`numvars' {

	local nomvar : 	word `ithvar' of `varlist'	
	local nomvar = subinstr("`nomvar'", "i.", "", .) 
	
	** all levels of the nominal variable
	qui levelsof 	`nomvar' if `levsamp'
	local nlevel 	`r(levels)'
	local numlevels	`r(r)'	
	
	** # of comparison groups
	local nc = ((`r(r)')*(`r(r)'-1)/2)
	
	**set for by/over options
	forvalues m = 1/`numbyoverlvl' {
	
	if `numbyoverlvl' > 1 {
		local bolvl: word `m' of `byoverlvl'
		local bolvlspec "_`bolvl'"
		local temp_bolvlname: label `labname' `bolvl'
		local bolvlname = abbrev("`temp_bolvlname'",13) 
		local bolvlnamespec "(`bolvlname')"
		local bospec "`bolvl'.`byovervar'#"
	}
	
	****************************************************************************
	// Calculation of ME inequality stats: Single level DV: 1 model
	****************************************************************************	
	
	if `nummods' == 1 & `mod1cats' < 3 {
		
		`quietly' `margins' `byvarspec'`nomvar' `if' `in', `mimarginsspec' `overvarspec' ///
		`atmeans' post	
*Read the margins command line now; the rclass helpers below clear r()
		local meimargcmd `"`r(`marginscmdline')'"'
		if `"`meimargcmd'"' == ""  local meimargcmd `"`e(cmdline)'"'
		qui est store meineq_margins
*before any nlcom is built from these coefficients.
		_mec_omitchk, focal("`nomvar'") cmdname(meinequality)
*Rebuild the prefixes from what margins actually posted
	
	*commands option prints margins syntax 
	if "`commands'" != "" {
		di as text "margins specification is: "
		di as result _skip(5) `"`meimargcmd'"'
	}
	
		*Weighted inequality by default
	
		if ("`unweighted'"==""){		
			_mei_terms, nomvar(`nomvar') nlevel("`nlevel'") numlevels(`numlevels') ///
				bospec("`bospec'") prefix("") weighted ///
				psamp(`psamp1') shsamp(`mecshsamp') mi(`mecismi') wspec(`mecwspec')
			local term_base `"`r(term)'"'
			_mei_nlcom `term_base', name(wgt_base) level(`level') quietly(`quietly')
			return scalar wem1`ithvar'`bolvlspec' = r(table)[1,1]
			
			matrix `rt' = r(table)[1,1], r(table)[2,1], r(table)[3,1], ///
			r(table)[4,1], r(table)[5,1], r(table)[6,1]
			
			matrix `newmatwgt' = nullmat(`newmatwgt') \ `rt'
			matrix rownames `newmatwgt' = "ME Inequality:`nomvar'`bolvlnamespec'" 
			if "`all'"=="" {
				matrix `newmatall' = `newmatall' \ `newmatwgt'
			}
			else if "`all'"!="" {
				matrix `newmatall_w' = `newmatall_w' \ `newmatwgt'
			}
			matrix drop `newmatwgt'
		}
		
		if "`all'"!="" | "`unweighted'"!="" {
			** Set up for lincom calculation
			_mei_terms, nomvar(`nomvar') nlevel("`nlevel'") numlevels(`numlevels') ///
				bospec("`bospec'") prefix("")
			local term_base `"`r(term)'"'
			
			** Unweighted (mean) amount of inequality in base model
			_mei_nlcom (`term_base')/(`nc'), name(mean_base) level(`level') quietly(`quietly')
			return scalar uwem1`ithvar'`bolvlspec' = r(table)[1,1]
			
			matrix `rt' = r(table)[1,1], r(table)[2,1], r(table)[3,1], ///
			r(table)[4,1], r(table)[5,1], r(table)[6,1]
			matrix `newmatmean' = nullmat(`newmatmean') \ `rt'
			matrix rownames `newmatmean' = "Unwgt. ME Inequality:`nomvar'`bolvlnamespec'" 
			if "`all'"=="" {
				matrix `newmatall' = `newmatall' \ `newmatmean'
			}
			else if "`all'"!="" {
				matrix `newmatall_uw' = `newmatall_uw' \ `newmatmean'
			}
			matrix drop `newmatmean'
			
		} // end: weighted/all options
		
		quietly est restore `mod1' // restore the mod for next estimation
		
	} // end: continuous or binary DVs for 1 model
	
	****************************************************************************
	// Calculation of ME inequality stats: Single level DV: 2 model
	****************************************************************************
	
	else if `nummods' == 2 & `mod1cats' < 3 {
		
		** Calculate the margins for the nominal variables in the gsem model
		if "`groups'" != "" {
			`quietly' `margins' `byvarspec'`nomvar' `if' `in', `mimarginsspec' `atmeans' ///
								over(`meisamp' `overvar') post					
			local mod_samp_spec1 "1.`meisamp'#"
			local mod_samp_spec2 "2.`meisamp'#"
*Specialized route: the equation encodes the group; no over() level in the names
			if `meispec' == 1 {
				local mod_samp_spec1 ""
				local mod_samp_spec2 ""
				}
		}
		else {
			`quietly' `margins' `byvarspec'`nomvar' `if' `in', `mimarginsspec' `overvarspec' `atmeans' post
			local mod_samp_spec1 ""
			local mod_samp_spec2 ""
		}
*Read the margins command line now; the rclass helpers below clear r()
		local meimargcmd `"`r(`marginscmdline')'"'
		if `"`meimargcmd'"' == ""  local meimargcmd `"`e(cmdline)'"'
		qui est store meineq_margins
*before any nlcom is built from these coefficients.
		_mec_omitchk, focal("`nomvar'") cmdname(meinequality)
*Rebuild the prefixes from what margins actually posted
		if `nummods' == 2 {
			_mec_prefix, focal("`nomvar'") ncat(`mod1cats')
			local meieq1 "`r(eq1)'"
			local meieq2 "`r(eq2)'"
			local meirst = r(restart)
			if "`meieq1'" != "" & "`meieq2'" != "" {
				if `mod1cats' == 1 {
					local prnum1 "`meieq1':"
					local prnum2 "`meieq2':"
					}
				else {
					forvalues meiout = 1/`mod1cats' {
						local prnum1_`meiout' "`meieq1':`meiout'._predict#"
						if `meirst' == 1 ///
							local prnum2_`meiout' "`meieq2':`meiout'._predict#"
						else {
							local meimarg = `meiout' + `mod1cats'
							local prnum2_`meiout' "`meieq2':`meimarg'._predict#"
							}
						}
					}
*				an equation-labelled object carries no over() level
				local mod_samp_spec1 ""
				local mod_samp_spec2 ""
				}
			}
		
		*commands option prints margins syntax 
		if "`commands'" != "" {
			di as text "margins specification is: "
			di as result _skip(5) `"`meimargcmd'"'
		}
	
		** Wieghted inequality: By default
		if ("`unweighted'"=="") {		
			
			_mei_terms, nomvar(`nomvar') nlevel("`nlevel'") numlevels(`numlevels') ///
				bospec("`bospec'") prefix("`prnum1'`mod_samp_spec1'") weighted ///
				psamp(`psamp1') shsamp(`mecshsamp') mi(`mecismi') wspec(`mecwspec')
			local term_base `"`r(term)'"'
			 
			local wgt_term_base `term_base'
			
			_mei_terms, nomvar(`nomvar') nlevel("`nlevel'") numlevels(`numlevels') ///
				bospec("`bospec'") prefix("`prnum2'`mod_samp_spec2'") weighted ///
				psamp(`psamp2') shsamp(`mecshsamp') mi(`mecismi') wspec(`mecwspec')
			local term_com `"`r(term)'"'
			
			local wgt_term_com `term_com'
			 
			_mei_nlcom `wgt_term_base', name(wgt_base) level(`level') quietly(`quietly')
			return scalar wem1`ithvar'`bolvlspec' = r(table)[1,1]
			
			matrix `rt' = r(table)[1,1], r(table)[2,1], r(table)[3,1], ///
			r(table)[4,1], r(table)[5,1], r(table)[6,1]
			matrix `newmatwgt' = nullmat(`newmatwgt') \ `rt'
			
			** Weighted amount of inequality in comparison model
			_mei_nlcom `wgt_term_com', name(wgt_compare) level(`level') quietly(`quietly')
			return scalar wem2`ithvar'`bolvlspec' = r(table)[1,1]
						
			matrix `rt' = r(table)[1,1], r(table)[2,1], r(table)[3,1], ///
			r(table)[4,1], r(table)[5,1], r(table)[6,1]
			matrix `newmatwgt' = `newmatwgt' \ `rt'
			
			*test of Weighted amount of inequality in two models
			_mei_nlcom (`wgt_term_base') - (`wgt_term_com'), name(wgt_change) level(`level') quietly(`quietly')
			return scalar wed`ithvar'`bolvlspec' = r(table)[1,1]
			
			matrix `rt' = r(table)[1,1], r(table)[2,1], r(table)[3,1], ///
			r(table)[4,1], r(table)[5,1], r(table)[6,1]
			matrix `newmatwgt' = `newmatwgt' \ `rt'	
		
			matrix rownames `newmatwgt' = ///
				"`nomvar'`bolvlnamespec' ME Ineq.:Model 1 (`mod1lab')" ///
				"`nomvar'`bolvlnamespec' ME Ineq.:Model 2 (`mod2lab')" ///
				"`nomvar'`bolvlnamespec' ME Ineq.:Cross-Model Diff."
			matrix `newmatall' = `newmatall' \ `newmatwgt'
			matrix drop `newmatwgt'

		} // end: weighted meinequality
		
		** unweighted calculation
		if "`all'"!="" | "`unweighted'"!="" {
						
			*Load terms for calculation
			_mei_terms, nomvar(`nomvar') nlevel("`nlevel'") numlevels(`numlevels') ///
				bospec("`bospec'") prefix("`prnum1'`mod_samp_spec1'")
			local term_base `"`r(term)'"'
			
			local abs_term_base `term_base'
			
			** Set up for the comparison model
			qui est restore meineq_margins
			_mei_terms, nomvar(`nomvar') nlevel("`nlevel'") numlevels(`numlevels') ///
				bospec("`bospec'") prefix("`prnum2'`mod_samp_spec2'")
			local term_com `"`r(term)'"'
			
			local abs_term_com `term_com'		
			
			*Unweighted (mean) amount of inequality in base model
			_mei_nlcom (`abs_term_base')/(`nc'), name(mean_base) level(`level') quietly(`quietly')
			return scalar uwem1`ithvar'`bolvlspec' = r(table)[1,1]
			
			matrix `rt' = r(table)[1,1], r(table)[2,1], r(table)[3,1], ///
			r(table)[4,1], r(table)[5,1], r(table)[6,1]
			matrix `newmatmean' = nullmat(`newmatmean') \ `rt'
			
			** Mean amount of inequality in comparison model
			_mei_nlcom (`abs_term_com')/(`nc'), name(mean_compare) level(`level') quietly(`quietly')
			return scalar uwem2`ithvar'`bolvlspec' = r(table)[1,1]
			
			matrix `rt' = r(table)[1,1], r(table)[2,1], r(table)[3,1], ///
			r(table)[4,1], r(table)[5,1], r(table)[6,1]
			matrix `newmatmean' = `newmatmean' \ `rt'
			
			*Test of Mean amount of inequality in two models
			_mei_nlcom ((`abs_term_base') - (`abs_term_com'))/(`nc'), name(mean_change) level(`level') quietly(`quietly')
			return scalar uwed`ithvar'`bolvlspec' = r(table)[1,1]
			
			matrix `rt' = r(table)[1,1], r(table)[2,1], r(table)[3,1], ///
			r(table)[4,1], r(table)[5,1], r(table)[6,1]
			matrix `newmatmean' = `newmatmean' \ `rt'

			matrix rownames `newmatmean' = ///
				"`nomvar'`bolvlnamespec' Unwgt ME Ineq.:Model 1 (`mod1lab')" ///
				"`nomvar'`bolvlnamespec' Unwgt ME Ineq.:Model 2 (`mod2lab')" ///
				"`nomvar'`bolvlnamespec' Unwgt ME Ineq.:Cross-Model Diff."
			
			matrix `newmatall' = `newmatall' \ `newmatmean'
			matrix drop `newmatmean'	
			
		} // end: unweighted meinequality
	
		quietly est restore `meisys'
		
	} // end: continuous or binary DVs for 2 model

	****************************************************************************
	// Calculation of ME inequality stats: multi-level DV: 1 model
	****************************************************************************

	else if `nummods' == 1 & `mod1cats' >= 3 {

		`quietly' `margins' `byvarspec'`nomvar' `if' `in', `mimarginsspec' `overvarspec' `atmeans' post	
*Read the margins command line now; the rclass helpers below clear r()
		local meimargcmd `"`r(`marginscmdline')'"'
		if `"`meimargcmd'"' == ""  local meimargcmd `"`e(cmdline)'"'
		qui est store meineq_margins
*before any nlcom is built from these coefficients.
		_mec_omitchk, focal("`nomvar'") cmdname(meinequality)
*Rebuild the prefixes from what margins actually posted

		*commands option prints margins syntax 
		if "`commands'" != "" {
			di as text "margins specification is: "
			di as result _skip(5) `"`meimargcmd'"'
		}
	
		qui levelsof 	`mod1dv'
		local dvlevels 	`r(levels)'
		
		** Wieghted inequality: By default
		if ("`unweighted'"=="") {		
		
			forvalues dvnum = 1/`mod1cats'{
				local dvlevel: word `dvnum' of `dvlevels'
				_mei_dvlab, dv(`mod1dv') dvlevel(`dvlevel')
				local out_`dvlevel' `"`r(lab)'"'
			
							
				_mei_terms, nomvar(`nomvar') nlevel("`nlevel'") numlevels(`numlevels') ///
					bospec("`bospec'") prefix("`dvnum'._predict#") weighted ///
					psamp(`psamp1') shsamp(`mecshsamp') mi(`mecismi') wspec(`mecwspec')
				local term_base `"`r(term)'"'
							
			_mei_nlcom `term_base', name(wgt_base) level(`level') quietly(`quietly')
			return scalar wem1`ithvar'_o`dvnum'`bolvlspec' = r(table)[1,1]
			
			matrix `rt' = r(table)[1,1], r(table)[2,1], r(table)[3,1], ///
			r(table)[4,1], r(table)[5,1], r(table)[6,1]
			matrix `newmatwgt' = nullmat(`newmatwgt') \ `rt'
			
			**set the row names 
			matrix rownames `newmatwgt' = "`nomvar'`bolvlnamespec' ME Ineq.:Pr(`out_`dvlevel'')" 
			matrix `newmatall' = `newmatall' \ `newmatwgt'
			matrix drop `newmatwgt'

			}	
		} // end: weighted meinequality

		if "`all'"!="" | "`unweighted'"!="" {

			forvalues dvnum = 1/`mod1cats'{

				local dvlevel: word `dvnum' of `dvlevels'
				_mei_dvlab, dv(`mod1dv') dvlevel(`dvlevel')
				local out_`dvlevel' `"`r(lab)'"'
					
				** Set up for lincom calculation
				_mei_terms, nomvar(`nomvar') nlevel("`nlevel'") numlevels(`numlevels') ///
					bospec("`bospec'") prefix("`dvnum'._predict#")
				local term_base `"`r(term)'"'
				
				** Unweighted (mean) amount of inequality in base model
				_mei_nlcom (`term_base')/(`nc'), name(mean_base) level(`level') quietly(`quietly')
				return scalar uwem1`ithvar'_o`dvnum'`bolvlspec' = r(table)[1,1]
				
				matrix `rt' = r(table)[1,1], r(table)[2,1], r(table)[3,1], ///
				r(table)[4,1], r(table)[5,1], r(table)[6,1]
				matrix `newmatmean' = nullmat(`newmatmean') \ `rt'
				**set the row names	
				matrix rownames `newmatmean' = "`nomvar'`bolvlnamespec' Unwgt ME Ineq.:Pr(`out_`dvlevel'')" 		
				matrix `newmatall' = `newmatall' \ `newmatmean'
				matrix drop `newmatmean'
			}
		
		} // end: unweighted meinequality
		
		quietly est restore `mod1'

	} // end: nominal DVs for 1 model
	
	****************************************************************************
	// Calculation of ME inequality stats: multi-level DV: 2 model
	****************************************************************************

	else if `nummods' == 2 & `mod1cats' >= 3 {

		if "`groups'" != "" {
			`quietly' `margins' `byvarspec'`nomvar' `if' `in', `mimarginsspec' `atmeans' ///
								over(`meisamp' `overvar') post					
			local mod_samp_spec1 "1.`meisamp'#"
			local mod_samp_spec2 "2.`meisamp'#"
*Specialized route: the equation encodes the group; no over() level in the names
			if `meispec' == 1 {
				local mod_samp_spec1 ""
				local mod_samp_spec2 ""
				}
		}
		else {
			`quietly' `margins' `byvarspec'`nomvar' `if' `in', `mimarginsspec' `overvarspec' `atmeans' post	
			local mod_samp_spec1 ""
			local mod_samp_spec2 ""
		}
*Read the margins command line now; the rclass helpers below clear r()
		local meimargcmd `"`r(`marginscmdline')'"'
		if `"`meimargcmd'"' == ""  local meimargcmd `"`e(cmdline)'"'
		qui est store meineq_margins
*before any nlcom is built from these coefficients.
		_mec_omitchk, focal("`nomvar'") cmdname(meinequality)
*Rebuild the prefixes from what margins actually posted
		if `nummods' == 2 {
			_mec_prefix, focal("`nomvar'") ncat(`mod1cats')
			local meieq1 "`r(eq1)'"
			local meieq2 "`r(eq2)'"
			local meirst = r(restart)
			if "`meieq1'" != "" & "`meieq2'" != "" {
				if `mod1cats' == 1 {
					local prnum1 "`meieq1':"
					local prnum2 "`meieq2':"
					}
				else {
					forvalues meiout = 1/`mod1cats' {
						local prnum1_`meiout' "`meieq1':`meiout'._predict#"
						if `meirst' == 1 ///
							local prnum2_`meiout' "`meieq2':`meiout'._predict#"
						else {
							local meimarg = `meiout' + `mod1cats'
							local prnum2_`meiout' "`meieq2':`meimarg'._predict#"
							}
						}
					}
*				an equation-labelled object carries no over() level
				local mod_samp_spec1 ""
				local mod_samp_spec2 ""
				}
			}

		*commands option prints margins syntax 
		if "`commands'" != "" {
			di as text "margins specification is: "
			di as result _skip(5) `"`meimargcmd'"'
		}
	
		qui levelsof 	`mod1dv'
		local dvlevels 	`r(levels)'
		
		** Wieghted inequality: By default
		if ("`unweighted'"=="") {		
			
			forvalues dvnum = 1/`mod1cats'{			 
			*Load terms for calculation
			local dvlevel: word `dvnum' of `dvlevels'
			_mei_dvlab, dv(`mod1dv') dvlevel(`dvlevel')
			local out_`dvlevel' `"`r(lab)'"'
			
				
			_mei_terms, nomvar(`nomvar') nlevel("`nlevel'") numlevels(`numlevels') ///
				bospec("`bospec'") prefix("`prnum1_`dvnum''`mod_samp_spec1'") weighted ///
				psamp(`psamp1') shsamp(`mecshsamp') mi(`mecismi') wspec(`mecwspec')
			local term_base `"`r(term)'"'
				 
				local wgt_term_base `term_base'
				
				_mei_terms, nomvar(`nomvar') nlevel("`nlevel'") numlevels(`numlevels') ///
					bospec("`bospec'") prefix("`prnum2_`dvnum''`mod_samp_spec2'") weighted ///
					psamp(`psamp2') shsamp(`mecshsamp') mi(`mecismi') wspec(`mecwspec')
				local term_com `"`r(term)'"'
				
				local wgt_term_com `term_com'
				 
				_mei_nlcom `wgt_term_base', name(wgt_base) level(`level') quietly(`quietly')
				return scalar wem1`ithvar'_o`dvnum'`bolvlspec' = r(table)[1,1]
			
				matrix `rt' = r(table)[1,1], r(table)[2,1], r(table)[3,1], ///
				r(table)[4,1], r(table)[5,1], r(table)[6,1]
				matrix `newmatwgt' = nullmat(`newmatwgt') \ `rt'

				
				** Weighted amount of heterogeneity in comparison model
				_mei_nlcom `wgt_term_com', name(wgt_compare) level(`level') quietly(`quietly')
				return scalar wem2`ithvar'_o`dvnum'`bolvlspec' = r(table)[1,1]
									
				matrix `rt' = r(table)[1,1], r(table)[2,1], r(table)[3,1], ///
				r(table)[4,1], r(table)[5,1], r(table)[6,1]
				matrix `newmatwgt' = `newmatwgt' \ `rt'
				
				*test of Weighted amount of inequality in two models
				_mei_nlcom (`wgt_term_base') - (`wgt_term_com'), name(wgt_change) level(`level') quietly(`quietly')
				return scalar wed`ithvar'_o`dvnum'`bolvlspec' = r(table)[1,1]
				
				matrix `rt' = r(table)[1,1], r(table)[2,1], r(table)[3,1], ///
				r(table)[4,1], r(table)[5,1], r(table)[6,1]
				matrix `newmatwgt' = `newmatwgt' \ `rt'	
			
				matrix rownames `newmatwgt' = ///
					"`nomvar'`bolvlnamespec' ME Ineq.:`mod1lab' Pr(`out_`dvlevel'')" ///
					"`nomvar'`bolvlnamespec' ME Ineq.:`mod2lab' Pr(`out_`dvlevel'')" ///
					"`nomvar'`bolvlnamespec' ME Ineq.:Diff. Pr(`out_`dvlevel'')"
				matrix `newmatall' = `newmatall' \ `newmatwgt'
				matrix drop `newmatwgt'
				
				}
				
		} // end: weighted meinequality
				
		** unweighted calculation
		if "`all'"!="" | "`unweighted'"!="" {
						
			forvalues dvnum = 1/`mod1cats'{			 
			
			local dvlevel: word `dvnum' of `dvlevels'
			_mei_dvlab, dv(`mod1dv') dvlevel(`dvlevel')
			local out_`dvlevel' `"`r(lab)'"'
				
			
			_mei_terms, nomvar(`nomvar') nlevel("`nlevel'") numlevels(`numlevels') ///
				bospec("`bospec'") prefix("`prnum1_`dvnum''`mod_samp_spec1'")
			local term_base `"`r(term)'"'
				
				local abs_term_base `term_base'
				
				** Set up for the comparison model
				
				_mei_terms, nomvar(`nomvar') nlevel("`nlevel'") numlevels(`numlevels') ///
					bospec("`bospec'") prefix("`prnum2_`dvnum''`mod_samp_spec2'")
				local term_com `"`r(term)'"'
				
				local abs_term_com `term_com'		
				
				*Unweighted (mean) amount of inequality in base model
				_mei_nlcom (`abs_term_base')/(`nc'), name(mean_base) level(`level') quietly(`quietly')
				return scalar uwem1`ithvar'_o`dvnum'`bolvlspec' = r(table)[1,1]
				
				matrix `rt' = r(table)[1,1], r(table)[2,1], r(table)[3,1], ///
				r(table)[4,1], r(table)[5,1], r(table)[6,1]
				matrix `newmatmean' = nullmat(`newmatmean') \ `rt'
				
				** Mean amount of inequality in comparison model
				_mei_nlcom (`abs_term_com')/(`nc'), name(mean_compare) level(`level') quietly(`quietly')
				return scalar uwem2`ithvar'_o`dvnum'`bolvlspec' = r(table)[1,1]
				
				matrix `rt' = r(table)[1,1], r(table)[2,1], r(table)[3,1], ///
				r(table)[4,1], r(table)[5,1], r(table)[6,1]
				matrix `newmatmean' = `newmatmean' \ `rt'
				
				*Test of Mean amount of inequality in two models
				_mei_nlcom ((`abs_term_base') - (`abs_term_com'))/(`nc'), name(mean_change) level(`level') quietly(`quietly')
				return scalar uwed`ithvar'_o`dvnum'`bolvlspec' = r(table)[1,1]
				
				matrix `rt' = r(table)[1,1], r(table)[2,1], r(table)[3,1], ///
				r(table)[4,1], r(table)[5,1], r(table)[6,1]
				matrix `newmatmean' = `newmatmean' \ `rt'

				matrix rownames `newmatmean' = ///
					"`nomvar'`bolvlnamespec' Unwgt ME Ineq.:`mod1lab' Pr(`out_`dvlevel'')" ///
					"`nomvar'`bolvlnamespec' Unwgt ME Ineq.:`mod2lab' Pr(`out_`dvlevel'')" ///
					"`nomvar'`bolvlnamespec' Unwgt ME Ineq.:Diff. Pr(`out_`dvlevel'')"
				matrix `newmatall' = `newmatall' \ `newmatmean'
				matrix drop `newmatmean'	
			}
			
		} // end: unweighted estimation
		
		quietly est restore `meisys' // restore the mod for next estimation

	} // end: nominal DVs for 2 models
	
	} // end: levels of by/over variables
	
} // end: variables in varlist

*********************************************************
// organize final table of stats 
*********************************************************


** special situation: change the order of the rows
if `nummods' == 1 & `mod1cats' < 3 & "`all'"!="" {
	local numcols = colsof(`newmatall_w')
	local numrows = rowsof(`newmatall_w')
	mat `newmatall_w' = `newmatall_w'[2..`numrows', 1..`numcols']

	local numcols = colsof(`newmatall_uw')
	local numrows = rowsof(`newmatall_uw')
	mat `newmatall_uw' = `newmatall_uw'[2..`numrows', 1..`numcols']
	
	matrix `newmatall' = `newmatall_w' \ `newmatall_uw'

}

else {
	** remove the first row (dots as place holder)
	local numcols = colsof(`newmatall')
	local numrows = rowsof(`newmatall')
	mat `newmatall' = `newmatall'[2..`numrows', 1..`numcols']
}

**set the column names
matrix colnames `newmatall' = "Estimate" "Std. err." "z" ///
"P>|z|" "`ll_spec'" "`ul_spec'"

mat `rtable' = `newmatall'

*Count empty cells whose SE is missing; returned as r(se_missing) and noted under the table
local meisemiss = 0
forvalues meii = 1/`=rowsof(`newmatall')' {
	if missing(`newmatall'[`meii',2])  local meisemiss = `meisemiss' + 1
	}
return scalar se_missing = `meisemiss'

return mat table = `rtable'			

**display the results based on users' choise
if ("`ci'"=="") {
	local numcols = colsof(`newmatall')
	local numrows = rowsof(`newmatall')
	mat `newmatall' = `newmatall'[1..`numrows',1..`numcols'-2]
}

**display sample size details
if `nummods' == 1 {
	local samp_info = "N = `samp1_size'"
	}
if `nummods' == 2 {
	local samp_info = "N_`mod1' = `samp1_size' , N_`mod2' = `samp2_size'"
	}	
	
*Final table	
matlist `newmatall', format(%10.`decimals'f) ///
	title("`title' (`samp_info')") twidth(`twidth')

if `meisemiss' > 0 {
	di _newline(1)
	di as err "NOTE: standard errors are missing for `meisemiss' " /*
	*/ "of the quantities above. {cmd:nlcom} could not compute them, " /*
	*/ "which " /*
	*/ "usually means a predicted quantity sits at or near zero -- " /*
	*/ "check for sparse outcome categories. The point estimate is " /*
	*/ "reported; the absent inference is not a display artefact. " /*
	*/ "{cmd:r(se_missing)} = `meisemiss'."
	}

*Label the _est_ markers at return; any estimates housekeeping can reset them, and _rc is saved/restored so the block is invisible to the caller
local __rcsave = _rc
capture label variable _est_`meisys' "meinequality: est. sample for stored system `meisys'"
capture label variable _est_meineq_margins "meinequality: est. sample for stored margins meineq_margins"
capture label variable _est_meineq_mod1 "meinequality: est. sample for the models()-omitted store meineq_mod1"
local __nh : word count `meiholdn'
forvalues __h = 1/`__nh' {
	local __hv : word `__h' of `meiholdn'
	local __hw : word `__h' of `meiholdw'
	capture label variable _est_`__hv' "suest2: est. sample for private copy of `__hw'"
	}
capture error `__rcsave'

end 


*Is the restored model an mi-pooled fit, and what command underlies it?
capture program drop _mei_terms
program define _mei_terms, rclass
*	Build the nlcom expression for one model's (or one outcome's) ME
	version 16
	syntax, nomvar(string) nlevel(string) numlevels(integer) ///
		[bospec(string) prefix(string) weighted psamp(string) ///
		shsamp(string) mi(integer 0) wspec(string asis)]
	local term 0
	forvalues i = 1/`numlevels' {
		local ilevel: word `i' of `nlevel'
		if "`weighted'" != "" {
			mec_share `nomvar' if `psamp' == 1 & `shsamp', level(`ilevel') ///
				mi(`mi') wspec(`wspec')
			local p_i = r(share)
		}
		forvalues j = 1/`numlevels' {
			if `i' < `j' {
				local jlevel: word `j' of `nlevel'
				if "`weighted'" != "" {
					mec_share `nomvar' if `psamp' == 1 & `shsamp', level(`jlevel') ///
						mi(`mi') wspec(`wspec')
					local p_j = r(share)
*					the pair weight, corrected for redundant comparisons
					local multiplier = (`p_i'+`p_j') / (`numlevels' - 1)
					local term `term' + ( `multiplier' * ///
						abs(_b[`prefix'`bospec'`ilevel'.`nomvar'] ///
						- _b[`prefix'`bospec'`jlevel'.`nomvar']))
				}
				else {
					local term `term' ///
						+ abs(_b[`prefix'`bospec'`ilevel'.`nomvar'] ///
						- _b[`prefix'`bospec'`jlevel'.`nomvar'])
				}
			}
		}
	}
	return local term `"`term'"'
end

capture program drop _mei_nlcom
program define _mei_nlcom, rclass
*	Restore the margins object and form one nlcom quantity, retrying rescaled
	version 16
	syntax anything(name=expr everything), name(string) level(string) [quietly(string)]
	qui est restore meineq_margins
	capture `quietly' nlcom `name': (`expr'), level(`level')
	if _rc != 0 {
		local meirc1 = _rc
*Capture the 1000x retry; a failed retry must not abort
		capture `quietly' nlcom `name'_1000: (`expr')*1000, level(`level') post
		local meirc2 = _rc
		if `meirc2' == 0 {
			capture `quietly' nlcom `name': _b[`name'_1000]/1000, level(`level')
			local meirc2 = _rc
			}
		if `meirc2' != 0 {
			capture qui est restore meineq_mod1
			di as err "{cmd:meinequality} could not compute {bf:`name'}: " /*
			*/ "{cmd:nlcom} returned r(`meirc1'), and r(`meirc2') on " /*
			*/ "the rescaled retry."
			di as err "This happens when a quantity the summary averages " /*
			*/ "over sits at or near zero -- most often when an outcome " /*
			*/ "category holds very few observations. {cmd:tabulate} the " /*
			*/ "dependent variable; combining sparse categories usually " /*
			*/ "resolves it."
			di as err "Your model has been restored to {cmd:e()}."
			exit 498
			}
		}
	return add
end

capture program drop _mei_dvlab
program define _mei_dvlab, rclass
*	The display label for one outcome level, abbreviated to fit
	version 16
	syntax, dv(string) dvlevel(string)
	qui ds `dv', has(vallabel)
	if "`r(varlist)'" != "" {
		local lbe : value label `dv'
		local lab : label `lbe' `dvlevel'
		return local lab = abbrev(`"`lab'"', 13)
	}
	else return local lab "Outcome `dvlevel'"
end

capture program drop _mei_ismi
program define _mei_ismi, rclass
	local ismi = 0
	if "`e(cmd)'" == "mi estimate"        local ismi = 1
	if "`e(prefix_mi)'" == "mi estimate"  local ismi = 1
	if "`e(mi)'" == "mi"                  local ismi = 1
	capture confirm scalar e(M_mi)
	if !_rc                               local ismi = 1
	local under "`e(cmd_mi)'"
	if trim("`under'") == "" | "`under'" == "mi estimate"  local under "`e(cmd)'"
	if "`under'" == "mi estimate"  local under ""
	return scalar ismi = `ismi'
	return local under "`under'"
end
