// Total ME for nominal/ordinal outcome variables
capture program drop totalme
*! totalme v1.6.9 Bing Han & Trenton Mize 2026-09-02  | history: CHANGELOG-totalme.md (repo)

program define totalme, rclass
	
version 16

syntax 	varlist(fv) [if] [in] [fweight pweight iweight] , ///
		[MODels(string) ///
		GROUPs /// 
		GROUPNames(string) /// 
		amount(string) ///
		CENTERed ///
		UNCENTered ///
		ATMEANs ///
		start(string) ///
		WEIghted ///
		UNWeighted /// 
		all /// 
		DETAILs /// 
		COMMANDs ///
		DECimals(string) /// 
		title(string) /// 
		ci /// 
		LABWidth(numlist integer) /// 
		LEVEL(integer 95) ///
		by(string) ///
		over(string) ///
		ENGine(string) ///
		] 

marksample touse

*Second marker: if/in only (under mi the varlist's missings are the imputed obs)
tempvar mecshsamp
marksample mecshsamp, novarlist

*The suest2 package is a PREREQUISITE and must be installed
local tmmissing ""
foreach tmreq in suest2 _mec_canonical mec_share mec_wcheck mec_gsem /*
	*/ _mec_omitchk _mec_prefix {
	capture which `tmreq'
	if _rc  local tmmissing "`tmmissing' `tmreq'"
	}
if "`tmmissing'" != "" {
	di _newline(1)
	di as err "{cmd:totalme} requires the {cmd:suest2} package, which "  /*
	*/ "is missing or incomplete. Not found:`tmmissing'. Install or "  /*
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
local tmsys "totalme_suest2"
local tmsysalt "totalme_gsem"
if "`engine'" == "gsem" {
	local tmsys "totalme_gsem"
	local tmsysalt "totalme_suest2"
	}
		
****************************************************************************
// Set overall options
****************************************************************************	

*Show estimation details; tmshow prefixes the combine call, which runs under capture and is silent unless noisily
if "`details'"!=""{
	local quietly ""
	local tmshow "noisily"
}
else {
	local quietly "quietly"
	local tmshow "quietly"
}

*Display options; labwidth 20-32 refused with a message
if "`uncentered'" != "" {
	local centered ""
}
else {
	local centered "centered"
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

if "`title'"==""{
	local title "Total ME Estimates"
}
else {
	local title "`title'"
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
	
			
*Check # of models
local nummods: word count `models'

*Error out if 3 or more models are specified
if `nummods' > 2 {
	di as err "Invalid number of models in the {opt models()} option. " /*
	*/ "{cmd:totalme} can only be used with one or two models."
	exit 198	
} 

*Error out if group specified incorrectly.
if "`groups'" != "" & `nummods' == 1 {
	di _newline(1)
	di as err "The {opt groups} option requires two models to be specified in " /*
	*/ "the {opt models()} option -- one for each group. See " /*
	*/ "{help totalme##groups}."
	exit 198
}		

*Set model names in the table
if "`groupnames'" != "" & "`groups'" == "" {
	di as err "The {opt groupnames} option requires two different models to be specified " /*
	*/ "using the {opt groups()} option. " /*
	*/ "See {help totalme##groupnames}."
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
	quietly est store totalme_mod1
	local mod1 totalme_mod1
	local nummods = 1
}

*Restore mod1
quietly est restore `mod1'

local cmd_m1 "`e(cmd)'"
local cmdline_m1 "`e(cmdline)'"
local vcetype1	= "`e(vce)'"
tempvar mod1samp
*Under mi, e(sample) is unset; if/in alone is the sample
_tm_ismi
local tm_ismi1 = r(ismi)
local tm_under1 "`r(under)'"
if `tm_ismi1' == 1  qui gen `mod1samp' = 1
else                qui gen `mod1samp' = e(sample)

*Sample the level proportions are taken over
local psamp1 "`mod1samp'"
local psamp2 "`mod1samp'"
*Levels are read from the estimation sample (all data if it is empty)
local levsamp "`mod1samp' == 1 & `mecshsamp'"
qui count if `levsamp'
if r(N) == 0  local levsamp "1"
local Nsav1 = e(N)
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
		*/ mwexp(`ifweight1') prefix(`prefix1') cmd(totalme)
}

*Level shares from mec_share (works under mi; pweight maps to aweight)
local mecwspec ""
if "`weightspec'" != ""      local mecwspec = /*
	*/ subinstr("`weightspec'", "pweight", "aweight", 1)
else if "`ifweight1'" != ""  local mecwspec "[aweight `ifweight1']"
local mecismi = `tm_ismi1'
local margins "margins"
*Name of the r() result that holds the margins command line
local marginscmdline "cmdline"

if `tm_ismi1' == 1 {

	capture which mimrgns
		if (_rc) {
		di _newline(1)
		di as err "{cmd:totalme} requires the user-written package " /*
		*/ "{cmd:mimrgns}. Click on the link below to search for " /*
		*/ "and install {cmd:mimrgns}: {stata search mimrgns: {bf:mimrgns}}"
		exit 198
		}
		
	capture confirm scalar e(N_mi)
	if !_rc  local Nsav1 = e(N_mi)
	local cmd_m1 "`tm_under1'"
	if "`e(prefix_mi)'" != ""  local prefix1 = "`e(prefix_mi)'"
	local margins "mimrgns"
	local mimarginsspec "predict(default) errorok esampvaryok"
	local marginscmdline "est_cmdline_margins"
}	
	
*Supported models resolved by _mec_canonical
local tm_raw "`cmd_m1'"
_mec_canonical, cmd("`tm_raw'") cmd2("`e(cmd2)'") model("`e(model)'") /*
	*/ distrib("`e(distrib)'") method("`e(method)'") estimator("`e(estimator)'")
local cmd_m1 "`r(canon)'"
local tm_ok1 = r(ok)

if `tm_ok1' == 0 {
	di _newline(1)
	di as err "`mod1' is a {cmd:`tm_raw'}. {cmd:totalme} does not support " /*
	*/ "this estimation command. See {help totalme##models}."
	exit 198
}

*	Categorical-outcome requirement is totalme's own
local tm_catmods "logit probit logistic mlogit ologit oprobit gologit2"
local tm_catmods "`tm_catmods' cloglog melogit meprobit mecloglog"
local tm_catmods "`tm_catmods' meologit meoprobit xtologit xtoprobit"
local tm_catmods "`tm_catmods' xtlogit xtprobit xtcloglog xtmlogit"
*hetprobit is a plain binary outcome
local tm_catmods "`tm_catmods' hetprobit"
local tm_incat : list posof "`cmd_m1'" in tm_catmods
if `tm_incat' == 0 {
	di _newline(1)
	_tm_norefuse "`mod1'" "`cmd_m1'"
	exit 198
}
	
*The outcome-category count is read from the right e() name per family
_tm_cats "`cmd_m1'" 1
local mod1cats = r(ncat)
local div1 = r(div)
if `mod1cats' >= . | `mod1cats' < 1 {
	di _newline(1)
	di as err "{cmd:totalme} could not read the number of outcome " /*
	*/ "categories for `mod1' (a {cmd:`cmd_m1'}). Without it the " /*
	*/ "statistic cannot be formed."
	exit 198
	}

*Restore mod2
if `nummods' == 2 {
	qui est restore `mod2'
	local cmd_m2 "`e(cmd)'"
	local cmdline_m2 "`e(cmdline)'"
	local vcetype2	= "`e(vce)'"
	tempvar mod2samp
	*Under mi, e(sample) is unset; if/in alone is the sample
_tm_ismi
local tm_ismi2 = r(ismi)
local tm_under2 "`r(under)'"
if `tm_ismi2' == 1  qui gen `mod2samp' = 1
else                qui gen `mod2samp' = e(sample)
	local Nsav2 = e(N)	
	local ifweight2 = "`e(wexp)'"
	local ifwtype2 = "`e(wtype)'"
	local prefix2 = "`e(prefix)'"
	
	if `tm_ismi2' == 1 {
		capture confirm scalar e(N_mi)
		if !_rc  local Nsav2 = e(N_mi)
		local cmd_m2 "`tm_under2'"
		if "`e(prefix_mi)'" != ""  local prefix2 = "`e(prefix_mi)'"
	}
	
*Which model's sample each observation belongs to (a tempvar)
	tempvar tmsamp
	quietly gen `tmsamp' = .
	quietly replace `tmsamp' = 1 if `mod1samp' == 1
	quietly replace `tmsamp' = 2 if `mod2samp' == 1
	local levsamp "`tmsamp' < . & `mecshsamp'"
	qui count if `levsamp'
	if r(N) == 0  local levsamp "1"
	
	quietly count if `tmsamp' == 1
	local Nsav1_ovlp = `r(N)'
	
	*Error out if group number is not consistent with the e(sample)
	if "`groups'" != "" & (`Nsav1_ovlp'!=`Nsav1') {
		di _newline(1)
		di as err "{opt groups} option does not support overlapped samples across groups. " /*
		*/ "See {help totalme##groups} for details."
		exit 198		
	}
	
	*A gologit2 pair is allowed on the default engine; refused under engine(gsem) only
	if ("`cmd_m1'" == "gologit2" | "`cmd_m2'" == "gologit2") /*
		*/ & "`engine'" == "gsem" { 	
		di _newline(1)
		di as err "{cmd:gologit2} cannot be compared across two models with " /*
		*/ "{opt engine(gsem)}. That engine uses {cmd:gsem} to combine " /*
		*/ "model estimates and {cmd:gologit2} estimates cannot be " /*
		*/ "replicated with {cmd:gsem}. The default engine does not refit " /*
		*/ "and supports this pair."
		exit 198		
	}
	
	*Model 2 through the same resolver and reader
	local tm_raw2 "`cmd_m2'"
	_mec_canonical, cmd("`tm_raw2'") cmd2("`e(cmd2)'") model("`e(model)'") /*
		*/ distrib("`e(distrib)'") method("`e(method)'") estimator("`e(estimator)'")
	local cmd_m2 "`r(canon)'"
	local tm_ok2 = r(ok)
	if `tm_ok2' == 0 {
		di _newline(1)
		di as err "`mod2' is a {cmd:`tm_raw2'}. {cmd:totalme} does not " /*
		*/ "support this estimation command."
		exit 198
		}
	local tm_incat2 : list posof "`cmd_m2'" in tm_catmods
	if `tm_incat2' == 0 {
		di _newline(1)
		_tm_norefuse "`mod2'" "`cmd_m2'"
		exit 198
		}
	_tm_cats "`cmd_m2'" 2
	local mod2cats = r(ncat)
	local div2 = r(div)
	if `mod2cats' >= . | `mod2cats' < 1 {
		di _newline(1)
		di as err "{cmd:totalme} could not read the number of outcome " /*
		*/ "categories for `mod2' (a {cmd:`cmd_m2'})."
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
			di in red "{cmd:totalme} shows each model's command line without " /*
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
			di in red "{cmd:totalme} shows each model's command line without " /*
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
			*/ mwexp(`ifweight1') prefix(`prefix1') cmd(totalme)
		mec_wcheck, gweight(`weight') gexp(`exp') mwtype(`ifwtype2') /*
			*/ mwexp(`ifweight2') prefix(`prefix2') cmd(totalme)
		}

	if ("`ifweight1'" != "" & "`prefix1'" != "svy") | ///
	   ("`ifweight2'" != "" & "`prefix2'" != "svy") {
		if "`weight'" == "" {
			if "`ifweight1'" != "`ifweight2'" | "`ifwtype1'" != "`ifwtype2'" {
				di _newline(1)
				di as err "The two models were fit with different weights, " /*
				*/ "so they cannot be combined. Refit them with the same " /*
				*/ "weight, or give the weight to {cmd:totalme} directly."
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
		
	*Error out if mi estimate prefix specified
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
		di as err "{cmd:totalme} does not support `prefix1' prefix " /*
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
		di in red "{cmd:totalme} uses vce(robust) for both models. " /*
		*/ "Standard errors from {cmd:totalme} will differ from the " /*
		*/ "specified model(s) because vce(robust) was not used on at " /*
		*/ "least one of the models specified in the {it:models( )} " /*
		*/ "option. We strongly recommend refitting the models with " /*
		*/ "vce(robust) to ensure the {cmd:totalme} results match " /*
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
// Model specification
****************************************************************************

if `nummods' == 1 {
	local samp1_size = e(N)

	di 		as text "Model (`mod1') is:"
	di 		as result "     `cmdline_m1'"
	
	tempvar totalme_sample 
	qui gen `totalme_sample' = 1 if e(sample) 	// to get correct SDs below
}

else if `nummods' == 2 {
	
	*Include model specs. in output
	di 		_newline(1)

	local 	mod1specs "`cmdline_m1_show'"
	local 	mod2specs "`cmdline_m2_show'"
	
	if `wtinherit' == 1 {
		di _newline(1)
		di in red "NOTE: no weight was given to {cmd:totalme}, so the " /*
		*/ "weight from the stored models ([`ifwtype1' `ifweight1']) is " /*
		*/ "applied to the combined fit."
		}
	di 		as text "Model 1 (`mod1') is:"
	di 		as result "     `mod1specs'"
	di 		as text "Model 2 (`mod2') is:"
	di 		as result "     `mod2specs'"

	*The stored estimates are combined, not refitted; each model keeps its own sample
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
		*/ "{cmd:totalme} cannot combine a model with no observations."
		exit 2000
		}
	
	*Combine the stored estimates; nothing is refit
	if "`engine'" == "suest2" {
*details shows the suest2 output: capture noisily under details, capture quietly otherwise
		capture `tmshow' suest2 `mod1' `mod2', nowarn
		if _rc {
			local tmrc = _rc
			di _newline(1)
			di as err "{cmd:suest2} could not combine `mod1' and `mod2' "  /*
			*/ "(rc `tmrc'). Its message follows."
			capture noisily suest2 `mod1' `mod2', nowarn
			exit `tmrc'
			}
		}
	else {
		local g_groups ""
		local g_samp ""
		if "`groups'" != "" {
			local g_groups "groups"
			local g_samp "sampvar(`tmsamp')"
			}
		capture `tmshow' mec_gsem `mod1' `mod2' `weightspec', /*
			*/ `g_groups' `g_samp' `quietly'
		if _rc {
			local tmrc = _rc
			di _newline(1)
			di as err "{cmd:engine(gsem)} could not combine `mod1' and "  /*
			*/ "`mod2' (rc `tmrc'). Its message follows."
			capture noisily mec_gsem `mod1' `mod2' `weightspec', /*
				*/ `g_groups' `g_samp'
			exit `tmrc'
			}
		}

	*Under gsem the MEs average over its listwise sample; level shares follow
	tempvar anlsamp
	*Same as above: the combined fit under mi leaves no e(sample).
if `mecismi' == 1  qui gen `anlsamp' = 1
else               qui gen `anlsamp' = e(sample)
	if "`groups'" == "" {
		local psamp1 "`anlsamp'"
		local psamp2 "`anlsamp'"
		}
	else {
		local psamp1 "`mod1samp'"
		local psamp2 "`mod2samp'"
		}
	
	capture estimates drop `tmsysalt'
	quietly est store `tmsys'

*Capture suest2's private-copy names now; labelled at end of program
local tmholdn ""
local tmholdw ""
if "`engine'" != "gsem" {
	local tmholdn `"`e(suest2_holds)'"'
	local __nh : word count `tmholdn'
	forvalues __h = 1/`__nh' {
		local __mn "suest2_model`__h'"
		local tmholdw `"`tmholdw' `e(`__mn')'"'
		}
	}
*No predict spec is passed; a bare margins posts every model x outcome x level cell
	if `mecismi' == 0  local mimarginsspec ""
	
	local samp1_size = e(_N)[1,1]
	local samp2_size = e(_N)[1,2]
	
	tempvar totalme_sample 
	qui gen `totalme_sample' = 1 if e(sample) 	// to get correct SDs below

	*commands option prints the engine's combined-model syntax
	if "`commands'" != "" {
		di as text "`engine' model is: "
		di as result "     `e(cmdline)'"
	}	
	
}	// End of model specification


****************************************************************************
// Check independent variables
****************************************************************************

*Check the number for the focal ivs
local numvars : word count 	`varlist'

if `numvars' == 0 {
	di _newline(1)
	di as err "Specify at least one independent nominal variable. " /*
	*/ "{cmd:totalme} can be used with at least one independent variable."
	exit 198	
} 

local conivs
local nomivs
local pconivs

*Check if variable is included in the model
forvalues ithvar=1/`numvars' {
		
	local ivar: 	word `ithvar' of `varlist'
	
	if `nummods' == 1 {
		if strpos("`cmdline_m1'","`ivar'") == 0 { 
			di _newline(1)
			di as err "Variable `ivar' not found in the model." 
			exit 198
		}
	}
	else if `nummods' == 2 {
		if strpos("`cmdline_m1'", "`ivar'") == 0 | ///
		strpos("`cmdline_m2'","`ivar'") == 0 { 
			di _newline(1)
			di as err "Variable `ivar' not found in both models."
			exit 198
		}
	}

	if strpos("`ivar'", "i.") == 0 {
		local i_ivar i.`ivar'
	}
	else {
		local i_ivar `ivar'
	}
	
	if strpos("`cmdline_m1'", "`i_ivar'") != 0 {
		local ivar = subinstr("`i_ivar'", "i.", "", .)
		qui levelsof `ivar' if `levsamp'
		local numlevels	`r(r)'	
		if `numlevels' > 2 {
			local nomivs `nomivs' `ivar'
		}
		else {
			local conivs `conivs' `ivar'
		}
	}
	else {
		local ivar = subinstr("`i_ivar'", "i.", "", .)
		local conivs `conivs' `ivar'
		local pconivs `pconivs' `ivar'
	}
	
		
}

if "`conivs'" != "" {
	di 		as text "Continuous/Binary IV(s): "
	di 		as result "     `conivs'"
}
if "`nomivs'" != ""  {	
	di 		as text "Nominal IV(s):"
	di 		as result "     `nomivs'"
}

*Check continuous variables only

local numamounts : word count `amount'
local numpconvars : word count `pconivs'

if "`amount'" != "" & `numpconvars' == 0 {
	di _newline(1)
	di as err "Incorrect specification in {opt amount( )} option. " /*
	*/ "This option is only for continuous variables. "
	exit 198
}
	
if `numamounts' > 1 & `numamounts' != `numpconvars' {
	di _newline(1)
	di as err "Incorrect specification in {opt amount( )} option. Either " /*
	*/ "specify only one amount which is used for all of the continuous " /*
	*/ "independent variables or specify an equal number of amounts as " /*
	*/ "continuous variables. There are `numcontvars' continuous variables: " /*
	*/ "{it:`contvars'} -- but `numamounts' amounts specified in {opt amount( )}"
	exit 198
	}
	
** return scalars

return scalar n_mods = `nummods'
return scalar n_vars = `numvars'	

****************************************************************************
// Calculation of total ME: prep
****************************************************************************

** temp list for matrix and estimations
tempname rt rb rV	
tempname newmatconivs newmatconivs_temp newmatcontrast

local newmatconivs "matrix_con_ivs"

** generate null mat
matrix `newmatconivs' = J(1, 6, .)

** temp list for matrix and estimations
tempname newmatmean newmatwgt newmatall newmatall_m newmatall_uw rtable

local newmatall "full_matrix"
local newmatall_w "weighted_null_matrix"
local newmatall_uw "unweighted_null_matrix"
local rtable "rtable"

** generate a nullmat for all 
matrix `newmatall' = J(1, 6, .)
matrix `newmatall_w' = J(1, 6, .)
matrix `newmatall_uw' = J(1, 6, .)
matrix `rtable' = J(1, 6, .)

****************************************************************************
// Calculation of total ME: continuous / binary IVs
****************************************************************************

** number of continuous/binary variables
local numcontvars : word count `conivs'

if `numcontvars' != 0 {
	
	local cnum = 1 	
	
	****************************************************************************
	// Set options for continuous/binary IVs
	****************************************************************************		

	forvalues i = 1/ `numcontvars' {
				
		local v : word `i' of `conivs'
*		The variable's position in its own list; reused by the inner loops
		local vnum = `i'
		local ifinteger = mod(`v', 1)

		if `ifinteger' != 0 {
			local numcats = 3 
		}
		else {
			fvexpand i.`v' if `levsamp'
			local numcats : word count `r(varlist)' 	
		}
			
		**set for by/over options
		forvalues m = 1/`numbyoverlvl' {
		
		if `numbyoverlvl' > 1 {
			local bolvl: word `m' of `byoverlvl'
			local bolvlspec "_`bolvl'"
			local temp_bolvlname: label `labname' `bolvl'
			local bolvlname = abbrev("`temp_bolvlname'",13) 
			local bolvlnamespec "(`bolvlname')"
			local bospec "#`bolvl'.`byovervar'"
		} 

		// Continuous IVs //
		if `numcats' > 2 {
			
			if `numamounts' == 0 {		// default to 1
				local amount`cnum' "one"
				}	
			if `numamounts' == 1 {
				local amount`cnum' : word 1 of `amount' 
				}
			if `numamounts' > 1 {
				local amount`cnum' : word `cnum' of `amount' 
				}
			
			*need to remove = so that, e.g. age=50 and age = 50 are treated same
			local start 		= subinstr("`start'", "=", " ", .) 
			local hasiv 		= strpos("`start'", "`v'")
				
			if `hasiv' == 0  {	// asoberved
			
				if "`amount`cnum''" == "one" {	
					if "`centered'" == "" {
						local startval 	"`v'=gen(`v')"	
						local endval	"`v'=gen(`v' + 1)"				
						}
					if "`centered'" != "" {
						local startval 	"`v'=gen(`v' - .5)"	
						local endval 	"`v'=gen(`v' + .5)"				
						}
					}
				else if "`amount`cnum''" == "sd" {	
					qui sum `v' if `totalme_sample' == 1			
					local sd = r(sd)	
					local halfsd = `sd' / 2
					
					if "`centered'" == "" {
						local startval 	"`v'=gen(`v')"	
						local endval 	"`v'=gen(`v' + `sd')"				
						}
					if "`centered'" != "" {
						local startval 	"`v'=gen(`v' - `halfsd')"	
						local endval 	"`v'=gen(`v' + `halfsd')"				
						}
					}
				else {	
					local halfamt = `amount`cnum'' / 2
					
					if "`centered'" == "" {
						local startval 	"`v'=gen(`v')"	
						local endval 	"`v'=gen(`v' + `amount`cnum'')"				
						}
					if "`centered'" != "" {
						local startval 	"`v'=gen(`v' - `halfamt')"	
						local endval 	"`v'=gen(`v' + `halfamt')"				
						}
					}
				local startlab ""
			}
				
			if `hasiv'!= 0 {	// start change at specified value
				local 	wherevar : list posof "`v'" in start
				di 		`wherevar'
				local 	whereval = `wherevar' + 1
				local 	startnum : word `whereval' of `start'
				qui sum `v' if `totalme_sample' == 1
				local 	sd = r(sd)	
				local 	halfsd = `sd' / 2	
				
				if "`amount`cnum''" == "one" {	
					if "`centered'" == "" {
						local endat 	= `startnum' + 1
						local startval 	"`v'=`startnum'"	
						local endval 	"`v'=`endat'"				
						}
					if "`centered'" != "" {
						local startat	= `startnum' - .5
						local endat 	= `startnum' + .5
						local startval 	"`v'=`startat'"	
						local endval 	"`v'=`endat'"				
						}
					}
				else if "`amount`cnum''" == "sd" {	
					if "`centered'" == "" {
						local endat 	= `startnum' + `sd'
						local startval 	"`v'=`startnum'"
						local endval 	"`v'=`endat'"				
						}
					if "`centered'" != "" {
						local startat 	= `startnum' - `halfsd'
						local endat 	= `startnum' + `halfsd'
						local startval 	"`v'=`startat'"
						local endval 	"`v'=`endat'"					
						}
					}			
				else {	
					local halfamt = `amount`cnum'' / 2
					
					if "`centered'" == "" {
						local endat 	= `startnum' + `amount`cnum''
						local startval 	"`v'=`startnum'"	
						local endval 	"`v'=`endat'"				
						}
					if "`centered'" != "" {
						local startat 	= `startnum' - `halfamt'
						local endat 	= `startnum' + `halfamt'		
						local startval 	"`v'=`startat'"	
						local endval 	"`v'=`endat'"				
						}
					}	
					local startlab "start (`startnum')"
				}
			*Set labels for table	
			if "`centered'" == "" {
				local centerlab ""
				}
			if "`centered'" != "" {
				local centerlab " (centered)"
				}
			if "`amount`cnum''" == "one" {
				local change`vnum' "`startlab' + 1`centerlab'"
				}
			else if "`amount`cnum''" == "sd" {
				local change`vnum' "`startlab' + SD`centerlab'"
				}
			else {
				local change`vnum' "`startlab' + `amount`cnum''`centerlab'"
				}	
			local 	mspec`i' at(`startval') at(`endval')
			local 	++cnum	
		
		} // end: continuous variable 
		
		*Binary vars use at() so predictions stay separate when continuous vars are also specified
		
		if `numcats' == 2 {
			qui levelsof 	`v' if `levsamp'
			local catsnom 	`r(levels)'
		
			forvalues vi=1/2 {
				local vlevel: word `vi' of `catsnom'
				qui levelsof `v' if `levsamp', local(levels_v)
				qui ds `v', has(vallabel)
				if "`r(varlist)'" !=  "" {	
					local lbe : value label `v'
					local temp_out_`vlevel' : label `lbe' `vlevel'
					local out_`vlevel' = abbrev("`temp_out_`vlevel''",13) 
				}
				else {
					local out_`vlevel' "Outcome `vlevel'"
				}
				
				local changelbl`vi' "`out_`vlevel''"
			}
						
			local 	mspec`i'  at(`v'=(`catsnom'))
			local  	change`vnum' "`changelbl2' vs `changelbl1'" //don't use "vs."
		}
		
		local mrgspec "`mspec`i''" 	

		************************************************************************
		// Specification of total ME: 1 Model
		************************************************************************
		
		if `nummods' == 1 {
			
			`quietly' `margins' `byvar' `if' `in', `mrgspec' `mimarginsspec' `overvarspec' `atmeans' post  
*Read the margins command line now; the rclass helpers below clear r()
			local tmmargcmd `"`r(`marginscmdline')'"'
			if `"`tmmargcmd'"' == ""  local tmmargcmd `"`e(cmdline)'"'
			qui est store totalme_margins
			
			local 	term_base 0

			*commands option prints margins syntax 
			if "`commands'" != "" {
				di as text "margins specification is: "
				di as result _skip(5) `"`tmmargcmd'"'
			}
	
			if `mod1cats' == 1 { 
				local term_base abs(_b[2._at`bospec'] - _b[1._at`bospec'])
			}
			
			else {
				forvalues i = 1/`mod1cats' {			
					local part1 ///
					+ abs(_b[`i'._predict#2._at`bospec'] - _b[`i'._predict#1._at`bospec'])	
					local term_base `term_base' `part1'	
				}	
			}
			**save terms for comparison
			local contrast`vnum' (`term_base')/`div1' 
			
			**test if nlcom could be calculated; if not *1000
			capture `quietly' nlcom conivs_nlcom: (`term_base')/`div1', level(`level')
			if _rc!=0 {
				`quietly' nlcom conivs_nlcom_1000: ((`term_base')/`div1')*1000, level(`level') post
				`quietly' nlcom conivs_nlcom: _b[conivs_nlcom_1000] / 1000, level(`level')	
			}
			
			return scalar tmcm1`vnum'`bolvlspec' = r(table)[1,1]
			
			matrix `rt' = r(table)[1,1], r(table)[2,1], r(table)[3,1], ///
			r(table)[4,1], r(table)[5,1], r(table)[6,1]
			matrix `newmatconivs_temp' = nullmat(`newmatconivs_temp') \ `rt'
			matrix rownames `newmatconivs_temp' = "`v'`bolvlnamespec':`change`vnum''" 
			matrix `newmatconivs' = `newmatconivs' \ `newmatconivs_temp'
			matrix drop `newmatconivs_temp'
			quietly est restore `mod1' // restore the mod for next estimation
						
		} // end: continuous or binary IVs for 1 model
	
		************************************************************************
		// Calculation of total ME: 2 Model
		************************************************************************
		
		else if `nummods' == 2 {
					
			** Calculate the margins for the nominal variables
			if "`groups'" != "" {
				`quietly' `margins' `byvar' `if' `in', `mrgspec' `mimarginsspec' ///
				over(`tmsamp' `overvar') `atmeans' post	
				
				local mod_samp_spec1 "#1.`tmsamp'"
				local mod_samp_spec2 "#2.`tmsamp'"
			}
			else {
				`quietly' `margins' `byvar' `if' `in', `mrgspec' `mimarginsspec' ///
				`overvarspec' `atmeans' post	
				
				local mod_samp_spec1 ""
				local mod_samp_spec2 ""
			}
			
*Read the margins command line now; the rclass helpers below clear r()
			local tmmargcmd `"`r(`marginscmdline')'"'
			if `"`tmmargcmd'"' == ""  local tmmargcmd `"`e(cmdline)'"'
			qui est store totalme_margins	// For use with post-estimation melincom
			

*Same read for the continuous branch
			_mec_prefix, focal(`v') ncat(`mod1cats')
			local tmeq1 "`r(eq1)'"
			local tmeq2 "`r(eq2)'"
			local tmrst = r(restart)
*The over() suffix is not cleared here
			_tm_prefixes `mod1cats' "`tmeq1'" "`tmeq2'" `tmrst' `mod2cats'
			local 	term_base 0
			local 	term_com 0

			*commands option prints margins syntax 
			if "`commands'" != "" {
				di as text "margins specification is: "
				di as result _skip(5) `"`tmmargcmd'"'
			}
			
			forvalues i = 1/`mod1cats' {	
				local part1 ///
				+ abs(_b[`tmpre1_`i''2._at`mod_samp_spec1'`bospec'] ///
				- _b[`tmpre1_`i''1._at`mod_samp_spec1'`bospec'])	
				local term_base `term_base' `part1'	
			}

			forvalues i = 1/`mod2cats' {				
				local part2 ///
				+ abs(_b[`tmpre2_`i''2._at`mod_samp_spec2'`bospec'] ///
				- _b[`tmpre2_`i''1._at`mod_samp_spec2'`bospec'])	
				local term_com `term_com' `part2'	
			}
			
			** total me in base model
			_tm_nlcom (`term_base')/`div1', name(conivs_nlcom_base) level(`level') quietly(`quietly')
			
			return scalar tmcm1`vnum'`bolvlspec' = r(table)[1,1]
			
			matrix `rt' = r(table)[1,1], r(table)[2,1], r(table)[3,1], ///
			r(table)[4,1], r(table)[5,1], r(table)[6,1]
			matrix `newmatconivs_temp' = nullmat(`newmatconivs_temp') \ `rt'
			
			** total me in comparison model
			_tm_nlcom (`term_com')/`div2', name(conivs_nlcom_com) level(`level') quietly(`quietly')
	
			return scalar tmcm2`vnum'`bolvlspec' = r(table)[1,1]
			
			matrix `rt' = r(table)[1,1], r(table)[2,1], r(table)[3,1], ///
			r(table)[4,1], r(table)[5,1], r(table)[6,1]
			matrix `newmatconivs_temp' = `newmatconivs_temp' \ `rt'
			
			*test total me in two models
			_tm_nlcom ((`term_base')/`div1')  - ((`term_com')/`div2'), name(conivs_nlcom_change) level(`level') quietly(`quietly')
			
			return scalar tmcd`vnum'`bolvlspec' = r(table)[1,1]
			
			matrix `rt' = r(table)[1,1], r(table)[2,1], r(table)[3,1], ///
			r(table)[4,1], r(table)[5,1], r(table)[6,1]
			matrix `newmatconivs_temp' = `newmatconivs_temp' \ `rt'
		
			matrix rownames `newmatconivs_temp' = ///
				"`v',`change`vnum'' `bolvlnamespec':Model 1 (`mod1lab')" ///
				"`v',`change`vnum'' `bolvlnamespec':Model 2 (`mod2lab')" ///
				"`v',`change`vnum'' `bolvlnamespec':Cross-Model Diff."
							
			matrix `newmatconivs' = `newmatconivs' \ `newmatconivs_temp'
			matrix drop `newmatconivs_temp'
			
			quietly est restore `tmsys' // restore the mod for next estimation
			
		} // end: continuous or binary IVs for 2 model

	
		}	// end by/over option
	} // end: continuous vars
	
} // end: if continuous variables


****************************************************************************
// Calculation of total ME: nominal IVs
****************************************************************************

** number of continuous/binary variables
local numnomvars : word count `nomivs'

if 	`numnomvars' == 0 & ///
("`weighted'"!="" | "`unweighted'"!="" | "`all'"!=""){
	di _newline(1)
	di as err "Incorrect specification in {opt weighted/unweighted/all} option." /*
	*/ " The options are only for nominal independent variables. "
	exit 198
}

if `numnomvars' != 0 {
	
	forvalues i = 1/`numnomvars'{
				
		local nomvar : 	word `i' of `nomivs'	
*		The variable's position in its own list; reused by the inner loops
		local vnum = `i'
				
		** # of n for variable
		
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
						
		************************************************************************
		// Calculation of total ME: 1 Model
		************************************************************************
		
		if `nummods' == 1 {
				
			`quietly' `margins' `byvarspec'`nomvar' `if' `in', `mimarginsspec' `overvarspec' ///
			`atmeans' post	
*Read the margins command line now; the rclass helpers below clear r()
			local tmmargcmd `"`r(`marginscmdline')'"'
			if `"`tmmargcmd'"' == ""  local tmmargcmd `"`e(cmdline)'"'
			qui est store totalme_margins

*Read the object before addressing it (r(npre) 0 = no margins object)
			_mec_omitchk, focal("`nomvar'") cmdname(totalme)
			_mec_prefix, focal(`nomvar') ncat(`mod1cats')
			local tm1npre = r(npre)

			*commands option prints margins syntax 
			if "`commands'" != "" {
				di as text "margins specification is: "
				di as result _skip(5) `"`tmmargcmd'"'
			}
	
			
			** Weighted inequality: By default
			if ("`unweighted'"=="") {		
			
				local term_base_all 0
 				
				forvalues dvnum = 1/`mod1cats'{
					
					** separate single-outcome models
					if `tm1npre' == 0 {
						local predictspec ""
					}
					else {
						local predictspec `dvnum'._predict#	
					}

					local 	term_base 0
								
					forvalues i = 1/`numlevels' {
						local ilevel: word `i' of `nlevel'
						mec_share `nomvar' if `psamp1' == 1 & `mecshsamp', level(`ilevel') /*
							*/ mi(`mecismi') wspec(`mecwspec')
						local p_i = r(share)
						forvalues j = 1/`numlevels' {
							if `i' < `j' {
								local jlevel: word `j' of `nlevel'
								mec_share `nomvar' if `psamp1' == 1 & `mecshsamp', level(`jlevel') /*
									*/ mi(`mecismi') wspec(`mecwspec')
								local p_j = r(share)
								local multiplier = (`p_i'+`p_j') / (`numlevels' - 1)
								local part1 ///
								+ ( `multiplier' * ///
								abs(_b[`predictspec'`bospec'`ilevel'.`nomvar'] ///
								- _b[`predictspec'`bospec'`jlevel'.`nomvar']))		
								local term_base `term_base' `part1'	
							}
						}			
					}

					local term_base_all `term_base_all' + (`term_base')
				}
				
				_tm_nlcom (`term_base_all')/`div1', name(wgt_base_all) level(`level') quietly(`quietly')
				
				return scalar tmwm1`vnum'`bolvlspec' = r(table)[1,1]
				
				matrix `rt' = r(table)[1,1], r(table)[2,1], r(table)[3,1], ///
				r(table)[4,1], r(table)[5,1], r(table)[6,1]
				matrix `newmatwgt' = nullmat(`newmatwgt') \ `rt'
				
				**set the row names 
				matrix rownames `newmatwgt' = "`nomvar'`bolvlnamespec': total ME Ineq." 
				matrix `newmatall' = `newmatall' \ `newmatwgt'
				matrix drop `newmatwgt'
				
			} // end: weighted meinequality
			
			if "`all'"!="" | "`unweighted'"!="" {
				
				local term_base_all 0
				forvalues dvnum = 1/`mod1cats'{
					
					** separate single-outcome models
					if `tm1npre' == 0 {
						local predictspec ""
					}
					else {
						local predictspec `dvnum'._predict#	
					}
					
					local 	term_base 0
					forvalues i = 1/`numlevels' {
						local ilevel: word `i' of `nlevel'
						forvalues j = 1/`numlevels' {
							if `i' < `j' {
								local jlevel: word `j' of `nlevel'
								local part1 ///
								+ abs(_b[`predictspec'`bospec'`ilevel'.`nomvar'] ///
								- _b[`predictspec'`bospec'`jlevel'.`nomvar'])
								local term_base `term_base' `part1'
							}
						}	
					}
					
					local term_base_all `term_base_all' + (`term_base')
				}
				** ssave terms for comparison
				local contrast`vnum' (`term_base')/(`div1'*`nc')
				
				_tm_nlcom (`term_base_all')/(`div1'*`nc'), name(mean_base_all) level(`level') quietly(`quietly')
				
				return scalar tmuwm1`vnum'`bolvlspec' = r(table)[1,1]
				
				matrix `rt' = r(table)[1,1], r(table)[2,1], r(table)[3,1], ///
				r(table)[4,1], r(table)[5,1], r(table)[6,1]
				matrix `newmatmean' = nullmat(`newmatmean') \ `rt'
				**set the row names	
				matrix rownames `newmatmean' = "`nomvar'`bolvlnamespec': Unwgt total ME Ineq." 		
				matrix `newmatall' = `newmatall' \ `newmatmean'
				matrix drop `newmatmean'
			
			} // end: unweighted meinequality
			quietly est restore `mod1' 
		} // end: 1 mod situation
		
		************************************************************************
		// Calculation of total ME: 2 Model
		************************************************************************
		
		else if `nummods' == 2 {

*groups keeps over(`tmsamp') here too
			if "`groups'" != "" {
				`quietly' `margins' `byvarspec'`nomvar' `if' `in', `mimarginsspec' `atmeans' ///
							over(`tmsamp' `overvar') post	
				local mod_samp_spec1 "1.`tmsamp'#"
				local mod_samp_spec2 "2.`tmsamp'#"
			}
			else {
				`quietly' `margins' `byvarspec'`nomvar' `if' `in', `mimarginsspec' `overvarspec' ///
				`atmeans' post	
				local mod_samp_spec1 ""
				local mod_samp_spec2 ""
			}
*Read the margins command line now; the rclass helpers below clear r()
			local tmmargcmd `"`r(`marginscmdline')'"'
			if `"`tmmargcmd'"' == ""  local tmmargcmd `"`e(cmdline)'"'
			qui est store totalme_margins

*refuse before any nlcom is built from omitted coefficients
			_mec_omitchk, focal("`nomvar'") cmdname(totalme)
			_mec_prefix, focal(`nomvar') ncat(`mod1cats')
			local tmeq1 "`r(eq1)'"
			local tmeq2 "`r(eq2)'"
			local tmrst = r(restart)
*The over() suffix is not cleared here
			_tm_prefixes `mod1cats' "`tmeq1'" "`tmeq2'" `tmrst' `mod2cats'

			*commands option prints margins syntax 
			if "`commands'" != "" {
				di as text "margins specification is: "
				di as result _skip(5) `"`tmmargcmd'"'
			}
			
			** Weighted inequality: By default
			if ("`unweighted'"=="") {		
				
				local term_base_all 0
				local term_com_all 0
				
				forvalues dvnum = 1/`mod1cats'{			 

					** 1st model				
					local term_base 0
					
					forvalues i = 1/`numlevels' {	
						local ilevel: word `i' of `nlevel'
						mec_share `nomvar' if `psamp1' == 1 & `mecshsamp', level(`ilevel') /*
							*/ mi(`mecismi') wspec(`mecwspec')
						local p_i = r(share)
						forvalues j =1/`numlevels' {
							if `i' < `j' {
								local jlevel: word `j' of `nlevel'
								mec_share `nomvar' if `psamp1' == 1 & `mecshsamp', level(`jlevel') /*
									*/ mi(`mecismi') wspec(`mecwspec')
								local p_j = r(share)
								*Calculate weight, corrected for redundant comparisons
								local multiplier = [(`p_i'+`p_j') / (`numlevels' - 1)]
								local part1 ///
								+ ( `multiplier' * ///
									abs(_b[`tmpre1_`dvnum''`mod_samp_spec1'`bospec'`ilevel'.`nomvar'] ///
									- _b[`tmpre1_`dvnum''`mod_samp_spec1'`bospec'`jlevel'.`nomvar']))
								local term_base `term_base' `part1'
							}
						}	
					}
		
					local term_base_all `term_base_all' + (`term_base')
				}
				
				forvalues dvnum = 1/`mod2cats'{			 
					** 2nd model				
					local 	term_com 0
					forvalues i = 1/`numlevels' {	
						local ilevel: word `i' of `nlevel'
						mec_share `nomvar' if `psamp2' == 1 & `mecshsamp', level(`ilevel') /*
							*/ mi(`mecismi') wspec(`mecwspec')
						local p_i = r(share)
						forvalues j = 1/`numlevels' {
							if `i' < `j' {
								local jlevel: word `j' of `nlevel'
								mec_share `nomvar' if `psamp2' == 1 & `mecshsamp', level(`jlevel') /*
									*/ mi(`mecismi') wspec(`mecwspec')
								local p_j = r(share)
								*Calculate weight, corrected for redundant comparisons
								local multiplier = [(`p_i'+`p_j') / (`numlevels' - 1)]
								local part2 ///
								+ ( `multiplier' * ///
									abs(_b[`tmpre2_`dvnum''`mod_samp_spec2'`bospec'`ilevel'.`nomvar'] ///
									- _b[`tmpre2_`dvnum''`mod_samp_spec2'`bospec'`jlevel'.`nomvar']))
								local term_com `term_com' `part2'
							}		
						}	
					}
					local term_com_all `term_com_all' + (`term_com')
				}
				
				_tm_nlcom (`term_base_all')/`div1', name(wgt_base_all) level(`level') quietly(`quietly')
				
				return scalar tmwm1`vnum'`bolvlspec' = r(table)[1,1]
				
				matrix `rt' = r(table)[1,1], r(table)[2,1], r(table)[3,1], ///
				r(table)[4,1], r(table)[5,1], r(table)[6,1]
				matrix `newmatwgt' = nullmat(`newmatwgt') \ `rt'					
				
				_tm_nlcom (`term_com_all')/`div2', name(wgt_com_all) level(`level') quietly(`quietly')
				
				return scalar tmwm2`vnum'`bolvlspec' = r(table)[1,1]
								
				matrix `rt' = r(table)[1,1], r(table)[2,1], r(table)[3,1], ///
				r(table)[4,1], r(table)[5,1], r(table)[6,1]
				matrix `newmatwgt' = `newmatwgt' \ `rt'
				
				*test of Weighted amount of inequality in two models
				_tm_nlcom ((`term_base_all')/`div1')  - ((`term_com_all')/`div2'), name(wgt_change_all) level(`level') quietly(`quietly')
				
				return scalar tmwd`vnum'`bolvlspec' = r(table)[1,1]				
			
				matrix `rt' = r(table)[1,1], r(table)[2,1], r(table)[3,1], ///
				r(table)[4,1], r(table)[5,1], r(table)[6,1]
				matrix `newmatwgt' = `newmatwgt' \ `rt'	
			
				matrix rownames `newmatwgt' = ///
					"`nomvar'`bolvlnamespec' total ME Ineq.:Model 1 (`mod1lab')" ///
					"`nomvar'`bolvlnamespec' total ME Ineq.:Model 2 (`mod2lab')" ///
					"`nomvar'`bolvlnamespec' total ME Ineq.:Cross-Model Diff."
				matrix `newmatall' = `newmatall' \ `newmatwgt'
				matrix drop `newmatwgt'				
										
			} // end: weighted meinequality
					
			** unweighted calculation
			if "`all'"!="" | "`unweighted'"!="" {

				local term_base_all 0
				local term_com_all 0
				
				forvalues dvnum = 1/`mod1cats'{			 
						
					local term_base 0
					
					forvalues i = 1/`numlevels' {	
						local ilevel: word `i' of `nlevel'
						forvalues j = 1/`numlevels' {
							if `i' < `j' {
								local jlevel: word `j' of `nlevel'
								local part1 ///
								+ abs(_b[`tmpre1_`dvnum''`mod_samp_spec1'`bospec'`ilevel'.`nomvar'] ///
								- _b[`tmpre1_`dvnum''`mod_samp_spec1'`bospec'`jlevel'.`nomvar'])
								local term_base `term_base' `part1'
							}
						}	
					}
					local term_base_all `term_base_all' + (`term_base')
				}	 
				** Set up for the comparison model
				forvalues dvnum = 1/`mod2cats'{			 
					local 	term_com 0
					
					forvalues i = 1/`numlevels' {	
						local ilevel: word `i' of `nlevel'
						forvalues j = 1/`numlevels' {
							if `i' < `j' {
								local jlevel: word `j' of `nlevel'
								local part2 ///
								+ abs(_b[`tmpre2_`dvnum''`mod_samp_spec2'`bospec'`ilevel'.`nomvar'] ///
								- _b[`tmpre2_`dvnum''`mod_samp_spec2'`bospec'`jlevel'.`nomvar'])
								local term_com `term_com' `part2'						
							}
						}	
					}	
					local term_com_all `term_com_all' + (`term_com')					
				}
				
				_tm_nlcom (`term_base_all')/(`div1'*`nc'), name(mean_base_all) level(`level') quietly(`quietly')
				
				return scalar tmuwm1`vnum'`bolvlspec' = r(table)[1,1]
				
				matrix `rt' = r(table)[1,1], r(table)[2,1], r(table)[3,1], ///
				r(table)[4,1], r(table)[5,1], r(table)[6,1]
				matrix `newmatmean' = nullmat(`newmatmean') \ `rt'					
				
				_tm_nlcom (`term_com_all')/(`div2'*`nc'), name(wgt_com_all) level(`level') quietly(`quietly')
				
				return scalar tmuwm2`vnum'`bolvlspec' = r(table)[1,1]				

				matrix `rt' = r(table)[1,1], r(table)[2,1], r(table)[3,1], ///
				r(table)[4,1], r(table)[5,1], r(table)[6,1]
				matrix `newmatmean' = `newmatmean' \ `rt'
				
				*test of Weighted amount of inequality in two models
				_tm_nlcom ((`term_base_all')/(`div1'*`nc'))  - ((`term_com_all')/(`div2'*`nc')), name(wgt_change_all) level(`level') quietly(`quietly')
				
				return scalar tmuwd`vnum'`bolvlspec' = r(table)[1,1]				

				matrix `rt' = r(table)[1,1], r(table)[2,1], r(table)[3,1], ///
				r(table)[4,1], r(table)[5,1], r(table)[6,1]
				matrix `newmatmean' = `newmatmean' \ `rt'	

				matrix rownames `newmatmean' = ///
					"`nomvar'`bolvlnamespec' toal Unwgt MEIneq:Model 1 (`mod1lab')" ///
					"`nomvar'`bolvlnamespec' toal Unwgt MEIneq:Model 2 (`mod2lab')" ///
					"`nomvar'`bolvlnamespec' toal Unwgt MEIneq:Cross-Model Diff."
				matrix `newmatall' = `newmatall' \ `newmatmean'
				matrix drop `newmatmean'	
				
			} // end: unweighted estimation
			
			quietly est restore `tmsys' // restore the mod for next estimation

		} // end: nominal DVs for 2 models				
		}	// end by/over option
	}	// end nominal vars
}		

*********************************************************
// format final table of stats 
*********************************************************

if `numcontvars' != 0 {
	** remove the first row (dots as place holder)
	local numcols = colsof(`newmatconivs')
	local numrows = rowsof(`newmatconivs')
	mat `newmatconivs' = `newmatconivs'[2..`numrows', 1..`numcols']
}

if `numnomvars' != 0 {
	** remove the first row (dots as place holder)
	local numcols = colsof(`newmatall')
	local numrows = rowsof(`newmatall')
	mat `newmatall' = `newmatall'[2..`numrows', 1..`numcols']
}

if `numcontvars' != 0 & `numnomvars' == 0 {
	mat `newmatall' = `newmatconivs'	
} 

if `numcontvars' != 0 & `numnomvars' != 0 {
	mat `newmatall' = `newmatconivs' \ `newmatall'
} 

**set the column names
matrix colnames `newmatall' = "Estimate" "Std. err." "z" ///
"P>|z|" "`ll_spec'" "`ul_spec'"

mat `rtable' = `newmatall'

*Count empty cells whose SE is missing; returned as r(se_missing) and noted under the table
local tmsemiss = 0
forvalues tmi = 1/`=rowsof(`newmatall')' {
	if missing(`newmatall'[`tmi',2])  local tmsemiss = `tmsemiss' + 1
	}
return scalar se_missing = `tmsemiss'

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

if `tmsemiss' > 0 {
	di _newline(1)
	di as err "NOTE: standard errors are missing for `tmsemiss' " /*
	*/ "of the quantities above. {cmd:nlcom} could not compute them, " /*
	*/ "which " /*
	*/ "usually means a predicted quantity sits at or near zero -- " /*
	*/ "check for sparse outcome categories. The point estimate is " /*
	*/ "reported; the absent inference is not a display artefact. " /*
	*/ "{cmd:r(se_missing)} = `tmsemiss'."
	}

*Label the _est_ markers at return; any estimates housekeeping can reset them, and _rc is saved/restored so the block is invisible to the caller
local __rcsave = _rc
capture label variable _est_`tmsys' "totalme: est. sample for stored system `tmsys'"
capture label variable _est_totalme_margins "totalme: est. sample for stored margins totalme_margins"
capture label variable _est_totalme_mod1 "totalme: est. sample for the models()-omitted store totalme_mod1"
local __nh : word count `tmholdn'
forvalues __h = 1/`__nh' {
	local __hv : word `__h' of `tmholdn'
	local __hw : word `__h' of `tmholdw'
	capture label variable _est_`__hv' "suest2: est. sample for private copy of `__hw'"
	}
capture error `__rcsave'

end 		


*Turn what _mec_prefix read into the per-model, per-outcome prefixes
capture program drop _tm_nlcom
program define _tm_nlcom, rclass
*	Restore the margins object and form one nlcom quantity, retrying rescaled
	version 16
	syntax anything(name=expr everything), name(string) level(string) [quietly(string)]
	qui est restore totalme_margins
	capture `quietly' nlcom `name': (`expr'), level(`level')
	if _rc != 0 {
		local tmrc1 = _rc
*Capture the 1000x retry; a failed retry must not abort
		capture `quietly' nlcom `name'_1000: (`expr')*1000, level(`level') post
		local tmrc2 = _rc
		if `tmrc2' == 0 {
			capture `quietly' nlcom `name': _b[`name'_1000]/1000, level(`level')
			local tmrc2 = _rc
			}
		if `tmrc2' != 0 {
			capture qui est restore totalme_mod1
			di as err "{cmd:totalme} could not compute {bf:`name'}: " /*
			*/ "{cmd:nlcom} returned r(`tmrc1'), and r(`tmrc2') on " /*
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

capture program drop _tm_prefixes
program define _tm_prefixes
	args ncat eq1 eq2 restart ncat2
*model 2 may have a different number of outcomes from model 1.
	if "`ncat2'" == ""  local ncat2 `ncat'
	if "`eq1'" != "" & "`eq2'" != "" {
		if `ncat' == 1 {
			c_local tmpre1_1 "`eq1':"
			c_local tmpre2_1 "`eq2':"
			}
		else {
			forvalues o = 1/`ncat' {
				c_local tmpre1_`o' "`eq1':`o'._predict#"
				}
			forvalues o = 1/`ncat2' {
				if `restart' == 1  c_local tmpre2_`o' "`eq2':`o'._predict#"
				else {
					local oo = `o' + `ncat'
					c_local tmpre2_`o' "`eq2':`oo'._predict#"
					}
				}
			}
		}
	else {
		forvalues o = 1/`ncat' {
			c_local tmpre1_`o' "`o'._predict#"
			}
		forvalues o = 1/`ncat2' {
			local oo = `o' + `ncat'
			c_local tmpre2_`o' "`oo'._predict#"
			}
		}
end

*The outcome-category count and divisor, per family, read from the e()
capture program drop _tm_norefuse
program define _tm_norefuse
	version 16
	args stname cmdname
	if "`cmdname'" == "biprobit" {
		di as err "`stname' is a {cmd:biprobit}. Its default statistic " /*
		*/ "is the JOINT probability of both outcomes (p11), so there " /*
		*/ "is no single outcome whose categories {cmd:totalme} could " /*
		*/ "sum over. See {help mecompare}, which compares the joint " /*
		*/ "probability directly."
		exit
		}
	if "`cmdname'" == "ivprobit" {
		di as err "`stname' is an {cmd:ivprobit}. The statistic " /*
		*/ "{cmd:suest2} supplies for it is the structural linear " /*
		*/ "index, not a probability, so there are no outcome-category " /*
		*/ "probabilities for {cmd:totalme} to sum. See " /*
		*/ "{help mecompare}, which compares the index directly."
		exit
		}
	di as err "`stname' is a {cmd:`cmdname'}, whose outcome is not " /*
		*/ "nominal or ordinal. {cmd:totalme} sums marginal effects " /*
		*/ "over the categories of the outcome, so it needs a " /*
		*/ "categorical dependent variable. See {help mecompare} for a " /*
		*/ "command that does not."
end

*	The divisor is 2 for a multi-category outcome, 1 for a binary one.
capture program drop _tm_cats
program define _tm_cats, rclass
	args canon which
	return scalar ncat = .
	return scalar div  = .
	local ord "ologit oprobit gologit2 meologit meoprobit xtologit xtoprobit"
	local bin "logit probit logistic cloglog melogit meprobit mecloglog"
	local bin "`bin' xtlogit xtprobit xtcloglog"
*hetprobit is single-quantity like the rest of bin
	local bin "`bin' hetprobit"
	local isord : list posof "`canon'" in ord
	local isbin : list posof "`canon'" in bin
	if `isord' {
		capture confirm scalar e(k_cat)
		if !_rc  return scalar ncat = e(k_cat)
		return scalar div = 2
		exit
		}
	if "`canon'" == "mlogit" {
		capture confirm scalar e(k_eq)
		if !_rc  return scalar ncat = e(k_eq)
		return scalar div = 2
		exit
		}
	if "`canon'" == "xtmlogit" {
		capture confirm scalar e(k_out)
		if !_rc  return scalar ncat = e(k_out)
		return scalar div = 2
		exit
		}
	if `isbin' {
		return scalar ncat = 1
		return scalar div = 1
		exit
		}
end

*Is the restored model an mi-pooled fit, and what command underlies it?
capture program drop _tm_ismi
program define _tm_ismi, rclass
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
