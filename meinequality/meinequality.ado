// Inequality stats for nominal independent variable's effects
capture program drop meinequality
*! meinequality v1.0.3 Bing Han & Trenton Mize 2026-02-10

*TM: v1.0.3 adds by and over options
*TM: v1.0.2 adds support for gologit2 for one model case
*BH: makes level option work
*    return scalar and tables 
* 	 add by and over options	


program define meinequality, rclass
	
version 15

syntax 	varlist(fv) [fweight pweight iweight] , ///
		[MODels(string) ///
		WEIghted ///
		UNWeighted ///
		all /// 
		ATMEANs ///
		GROUPs ///
		GROUPNames(string) /// 
		DECimals(integer 3) /// 
		title(string) /// 
		ci /// 
		LABWidth(numlist >19 integer) /// 
		DETAILs /// 
		COMMANDs /// 
		level(integer 95) /// 
		by(string) ///
		over(string) ///
		] 	
		
****************************************************************************
// Set overall options
****************************************************************************	

*Show estimation details
if "`details'"!=""{
	local quietly ""
} 
else {
	local quietly "quietly"
}

*Set display options for final table (label width, title, decimal)
if "`labwidth'" == "" {
	local twidth = 24
}
else {
	local twidth = `labwidth'
}

if "`title'"==""{
	local title "ME Inequality Estimates"
}
else {
	local title "`title'"
}  	

if "`decimals'" == "" {
	local dec = 3
}
else {
	local dec = `decimals'
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

*List of supported models
local supmods 	"regress logit probit poisson nbreg mlogit ologit oprobit gologit2"
local onmods 	"mlogit ologit oprobit gologit2"
			
*Check # of models
local nummods: word count `models'

*Error out if 3 or more models are specified
if `nummods' > 2 {
	di _newline(1)
	di as err "Invalid number of models specified in {opt models()} option. " /*
	*/ "{cmd:meinequality} can only be used with one or two models."
	exit	
} 

*Error out if group specified incorrectly
if "`groups'" != "" & `nummods' == 1 {
	di _newline(1)
	di as err "The {opt groups} option requires two models to be specified in " /*
	*/ "the {opt models()} option—one for each group. See " /*
	*/ "{help meinequality##groups}."
}		

*Set model names in the table
if "`groupnames'" != "" & "`groups'" == "" {
	di _newline(1)
	di as err "The {opt groupnames} option requires two different models " /*
	*/ "to be specified using the {opt groups()} option. " /*
	*/ "See {help meinequality##groupnames}."
	exit	
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
	else if `nummods' == 1 {
		di _newline(1)
		di as err "The {opt weight} option requires two models to be specified in " /*
		*/ "the {opt models()} option—one for each group. " /*
		*/ "For a one-model situation, directly use weight in your model. " /*
		*/ "See {help meinequality##weight}."
		exit
	}
} 

if "`prefix1'" == "svy" {
	local svyspec "svy:" 
}
else {
	local svyspec ""
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
qui gen `mod1samp' = e(sample)
local Nsav1 = e(N)
local mod1dv = 	"`e(depvar)'"
local ifweight1 = "`e(wexp)'"
local prefix1 = "`e(prefix)'"
local margins "margins"

if "`cmd_m1'" == "mi estimate" {

	capture which mimrgns
		if (_rc) {
		di _newline(1)
		di as err "{cmd:meinequality} requires the user-written package " /*
		*/ "{cmd:mimrgns}. Click the link below to search for " /*
		*/ "and install {cmd:mimrgns}: {stata search mimrgns: {bf:mimrgns}}."
		exit
		}

	local Nsav1 = e(N_mi)
	local cmd_m1 "`e(cmd_mi)'"
	local prefix1 = "`e(prefix_mi)'"	
	local margins "mimrgns"
	local mimarginsspec "predict(default)"
}	

	
*Check if model 1 is supported
if strpos("`supmods'","`cmd_m1'") == 0 {
	di _newline(1)
	di as err "`mod1' is a {cmd:`cmd_m1'}. {cmd:meinequality} " /* 
	*/ "only supports the following estimation commands: " /*
	*/ "regress, logit, probit, mlogit, ologit, oprobit, gologit2, poisson, nbreg."
	exit
}
	
*Save the number of categories for ologit and mlogit
if "`cmd_m1'" == "ologit" | "`cmd_m1'" == "oprobit" | "`cmd_m1'" == "gologit2" {	
	local mod1cats = e(k_cat)
	}
else if "`cmd_m1'" == "mlogit" {
	local mod1cats = e(k_eq)
	}
else {
	local mod1cats = 1
	}

*Restore mod2
if `nummods' == 2 {
	qui est restore `mod2'
	local cmd_m2 "`e(cmd)'"
	local cmdline_m2 "`e(cmdline)'"
	local vcetype2	= "`e(vce)'"
	qui tempvar mod2samp
	qui gen `mod2samp' = e(sample)
	local Nsav2 = e(N)	
	local mod2dv = 	"`e(depvar)'"
	local ifweight2 = "`e(wexp)'"
	local prefix2 = "`e(prefix)'"
	
	if "`cmd_m2'" == "mi estimate" {
		local cmd_m2 "`e(cmd_mi)'"
		local prefix2 = "`e(prefix_mi)'"	
		local Nsav2 = e(N_mi)
	}	
	
	capture drop me_inequality_mod_samp // use unique name to avoid being taken
	quietly gen me_inequality_mod_samp  = .
	quietly replace me_inequality_mod_samp  = 1 if `mod1samp' == 1
	quietly replace me_inequality_mod_samp  = 2 if `mod2samp' == 1
			
	quietly count if me_inequality_mod_samp == 1
	local Nsav1_ovlp = `r(N)'
	
	*Error out if group number is not consistent with the e(sample)
	if "`groups'" != "" & (`Nsav1_ovlp'!=`Nsav1') {
		di _newline(1)
		di as err "{opt groups} option does not support partially overlapping " /*
		*/ "samples. With the {opt groups} option, samples must be entirely " /*
		*/ "distinct across models. See {help meinequality##groups} for details."
		exit		
	}
		
	*Error out if command1 != command2
	if "`cmd_m1'" != "`cmd_m2'" {
		di _newline(1)
		di as err "`mod1' is a {cmd:`cmd_m1'}; `mod2' is a {cmd:`cmd_m2'}. " /*
		*/ "{cmd:meinequality} doesn't support different models."
	exit
	}
	
	*Can't use gsem for gologit2
	if "`cmd_m1'" == "gologit2" | "`cmd_m2'" == "gologit2" { 	
		di _newline(1)
		di as err "{cmd:gologit2} is not supported for comparing across two " /*
		*/ "models. {cmd:meinequality} uses {cmd:gsem} to combine model " /*
		*/ "estimates and {cmd:gologit2} estimates cannot be replicated with {cmd:gsem}."
		exit		
	}
	
	if "`e(cmd)'" == "ologit" | "`e(cmd)'" == "oprobit" {	
		local mod2cats = e(k_cat)
	}
	else if "`e(cmd)'" == "mlogit" {
		local mod2cats = e(k_eq)
		}
	else {
		local mod2cats = 1
		}
	
	*Error out if different # of categories across m/ologit models	
	if "`cmd_m1'" == "ologit" | "`cmd_m1'" == "oprobit" | ///
	   "`cmd_m1'" == "mlogit" | "`cmd_m1'" == "oprobit" {
		if `mod1cats' != `mod2cats' {
		di _newline(1)
		di as err "Numbers of outcome categories differ across models `mod1' " /*
		*/ "and `mod2'. {cmd:meinequality} can only be used with `cmd_m1' when the " /*
		*/ "number of outcome categories is the same across both models."
		exit
		}	
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
			di in red "{cmd:meinequality} does not support options except vce(robust) " /*
			*/ "for two-model cases. Options for `mod1' are removed for estimation."			
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
			di in red "{cmd:meinequality} does not support options except vce(robust) " /*
			*/ "for two-model cases. Options for `mod2' are removed for estimation."			
		}		
	}
	
	local cmdline_m1_show = "`cmdline_m1'"
	local cmdline_m2_show = "`cmdline_m2'"

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
	
	*Error out if individual weight options are included
	if "`ifweight1'" != "" | "`ifweight2'" != "" {
			di _newline(1)
			di as err "{cmd:meinequality} does not support individual weight options " /*
			*/ "for two-model cases. " /*
			*/ "Specify weight options globally using the weight specification. " /*
			*/ "See {help meinequality} for details."
			exit
	}
	
	*Error out if svy prefix specified
	if "`prefix1'" == "svy" | "`prefix2'" == "svy" {
		di _newline(1)
		di as err "{cmd:meinequality} does not support the {opt svy:} prefix " /*
		*/ "when two models are specified." /*
		*/ "Consider using weight options instead of {opt svy:}. " /*
		*/ "See {help meinequality} for details."
		exit
	}	
	
	if "`prefix1'" == "mi estimate" | "`prefix2'" == "mi estimate" {
		
		if "`prefix1'" != "`prefix2'" {
			di _newline(1)
			di as err "The prefixes do not match in the two models. " /*
			*/ "The prefix for `mod1' is `prefix1', and the prefix for `mod2' is `prefix2'."
			exit
		}
		
		local gsemprefix "mi estimate, cmdok: "
		local predictspec 	
		
	}
	
	if "`prefix1'" != "mi estimate" & "`prefix1'" != "" {
		di _newline(1)
		di as err "{cmd:meinequality} does not support the `prefix1' prefix " /*
		*/ "when two models are specified."
		exit		
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
	
	*Check if vce is used for two models
	*Warn if vce(robust) not used on stored models
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
	exit	
}

if "`by'" != "" | "`over'" != "" {

	** check numbers of by/over var
	local numbyvar : word count `by'
	local numovervar : word count `over'

	if `numbyvar' > 1 {
		di _newline(1)
		di as err "Invalid number of variables specified in {opt by()} option. " /*
		*/ "{opt by()} can only be used with one variable."
		exit	
	}

	if `numovervar' > 1 {
		di _newline(1)
		di as err "Invalid number of variables specified in {opt over()} option. " /*
		*/ "{opt over()} can only be used with one variable."
		exit	
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
			exit
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
			exit
		}
		local overvarspec "over(`overvar')"
	}

	** all levels of the by/over variable

	qui 	levelsof 		`byovervar'
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
	exit	
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
			exit
		}
	}
	else if `nummods' == 2 {
		if strpos("`cmdline_m1'","`i_nomvar'") == 0 | ///
		strpos("`cmdline_m2'","`i_nomvar'") == 0 { 
			di _newline(1)
			di as err "Variable `nomvar' not found in the model. " ///
			"See if i. prefix is used for the nominal variable in the model."
			exit
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
	local mod1varnum : 	word count `cmdline_m1'

	di 		in white "Model (`mod1') is:"
	di 		in yellow "     `cmdline_m1'"
}

else if `nummods' == 2 {
	
	*Store model variables
	local mod1varnum : 	word count `cmdline_m1'
	local mod2varnum : 	word count `cmdline_m2'

	forvalues i=3/`mod1varnum' {
		local mod1iv`i': word `i' of `cmdline_m1'
		local mod1ivs `mod1ivs' `mod1iv`i'' 
	}	
	forvalues i=3/`mod2varnum' {
		local mod2iv`i': word `i' of `cmdline_m2'
		local mod2ivs `mod2ivs' `mod2iv`i'' 
	}	
	
	*Rename DV if the same
	if "`mod1dv'" == "`mod2dv'" & "`groups'" != ""{
		
		capture drop `mod1dv'_COPY1
		capture drop `mod2dv'_COPY2

		qui clonevar `mod1dv'_COPY1 = `mod1dv' 
		qui replace `mod1dv'_COPY1 = . if me_inequality_mod_samp != 1
		local mod1dv_use = "`mod1dv'_COPY1"
		qui clonevar `mod2dv'_COPY2 = `mod2dv'
		qui replace `mod2dv'_COPY2 = . if me_inequality_mod_samp != 2
		local mod2dv_use = "`mod2dv'_COPY2"
		
	}
	else if "`mod1dv'" == "`mod2dv'" & "`groups'" == "" {
		
		capture drop `mod2dv'_COPY2
		qui clonevar `mod2dv'_COPY2 = `mod2dv'
		
		local mod1dv_use = "`mod1dv'"
		local mod2dv_use = "`mod2dv'_COPY2"

	}
	else {
		local mod1dv_use = "`mod1dv'"
		local mod2dv_use = "`mod2dv'"
	}
		
	*Include model specs. in output
	di 		_newline(1)

	local 	mod1specs "`cmdline_m1_show', vce(robust)"
	local 	mod2specs "`cmdline_m2_show', vce(robust)"

	di 		in white "Model 1 (`mod1') is:"
	di 		in yellow "     `mod1specs'"
	di 		in white "Model 2 (`mod2') is:"
	di 		in yellow "     `mod2specs'"

	*Listwise delete if not a groups model
	if "`groups'" == "" {
		local listwise "listwise"
		}
	else {
		local listwise ""
		}
	
	*Estimate the gsem model
	if "`commands'" != "" {
		di _newline(1)
		di in white "gsem model is: "
		di in yellow "  `gsemprefix'gsem (`mod1dv' <- `mod1ivs', `cmd_m1')" /*
		*/ "(`mod2dv' <- `mod2ivs', `cmd_m2') `weightspec', vce(robust) `listwise'"
	}
	
	*Warn if different sample size used across models
	if "`groups'" == "" & `Nsav1' != `Nsav2' {
		di _newline(1)
		di in red "Sample size varies across the models: " /*
		*/ "N_`mod1'=`Nsav1'; N_`mod2'=`Nsav2'. " /*
		*/ "The results from {cmd:meinequality} will not match " /*
		*/ "those from the specified models as {cmd:meinequality} uses listwise " /*
		*/ "deletion across the models."
	}
	
	*Error out if no observations
	if "`groups'" == "" & (`Nsav1' == 0 | `Nsav2' == 0) {
		di _newline(1)
		di in red "`mod1' and `mod2' are supposed to have the same sample. " /*
		*/ "No observation detected. " /*
		*/ "Consider if {opt groups} is needed. " /*
		*/ "See {help groups} for details."
	}
	
	*Run gsem for two-model situation
	quietly `gsemprefix' gsem 	(`mod1dv_use' <- `mod1ivs', `cmd_m1') ///
					(`mod2dv_use' <- `mod2ivs', `cmd_m2') ///
					`weightspec' ///
					, vce(robust) `listwise'
	
	quietly est store meineq_gsem
	local mimarginsspec `e(marginsdefault)'
	
	local samp1_size = e(_N)[1,1]
	local samp2_size = e(_N)[1,2]

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
	
	** # of n for variable
	qui count if !missing(`nomvar')
	local tot_n = `r(N)'	
	
	** all levels of the nominal variable
	qui levelsof 	`nomvar'
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
		
		`quietly' `margins' `byvarspec'`nomvar', `mimarginsspec' `overvarspec' ///
		`atmeans' post	
		qui est store meineq_margins
	
		** Different Calculations
		** Wieghted inequality: By default
	
		if ("`unweighted'"==""){		
			local 	term_base 0
			forvalues i = 1/`numlevels' {
				local ilevel: word `i' of `nlevel'
				qui `svyspec' prop `nomvar' `weightspec'
				local p_i = e(b)[1,`i'] 
				forvalues j = 1/`numlevels' {
					if `i' < `j' {
						local jlevel: word `j' of `nlevel'
						local p_j = e(b)[1,`j'] 
						*Calculate weight, corrected for redundant comparisons
						local multiplier = (`p_i'+`p_j') / (`numlevels' - 1)
						local part1 ///
						+ ( `multiplier' * ///
								abs(_b[`bospec'`ilevel'.`nomvar'] - _b[`bospec'`jlevel'.`nomvar']))		
						local term_base `term_base' `part1'	
					}
				}			
			}	
			qui est restore meineq_margins
			
			**test if wgt_base could be calculated; if not *1000
			capture `quietly' nlcom wgt_base: (`term_base'), level(`level')
			if _rc!=0 {
				`quietly' nlcom wgt_base_1000: (`term_base')*1000, level(`level') post
				`quietly' nlcom wgt_base: _b[wgt_base_1000] / 1000, level(`level')
			}
			
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
			local 	term_base 0
			forvalues i = 1/`numlevels' {
				local ilevel: word `i' of `nlevel'
				forvalues j = 1/`numlevels' {
					if `i' < `j' {
						local jlevel: word `j' of `nlevel'
						local part1 ///
						+ abs(_b[`bospec'`ilevel'.`nomvar'] - _b[`bospec'`jlevel'.`nomvar'])
						local term_base `term_base' `part1'
					}
				}	
			}
			
			** Unweighted (mean) amount of inequality in base model
			qui est restore meineq_margins
			capture `quietly' nlcom mean_base: (`term_base')/(`nc'), level(`level')
			if _rc != 0 {
				`quietly' nlcom mean_base_1000: (`term_base')*1000/(`nc'), level(`level') post
				`quietly' nlcom mean_base: _b[mean_base_1000]/1000, level(`level')			
			}
			
			return scalar uwm1`ithvar'`bolvlspec' = r(table)[1,1]
			
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
			`quietly' `margins' `byvarspec'`nomvar', `mimarginsspec' `atmeans' ///
								over(me_inequality_mod_samp `overvar') post					
			local mod_samp_spec1 "1.me_inequality_mod_samp#"
			local mod_samp_spec2 "2.me_inequality_mod_samp#"
		}
		else {
			`quietly' `margins' `byvarspec'`nomvar', `mimarginsspec' `overvarspec' `atmeans' post
			local mod_samp_spec1 ""
			local mod_samp_spec2 ""
		}
		qui est store meineq_margins
		
		** Wieghted inequality: By default
		if ("`unweighted'"=="") {		
			
			local 	term_base 0
			forvalues i = 1/`numlevels' {	
				local ilevel: word `i' of `nlevel'
				qui `svyspec' prop `nomvar' `weightspec'
				local p_i = e(b)[1,`i'] 
				forvalues j =1/`numlevels' {
					if `i' < `j' {
						local jlevel: word `j' of `nlevel'
						local p_j = e(b)[1,`j'] 
						*Calculate weight, corrected for redundant comparisons
						local multiplier = [(`p_i'+`p_j') / (`numlevels' - 1)]
						local part1 ///
						+ ( `multiplier' * ///
							abs(_b[1._predict#`mod_samp_spec1'`bospec'`ilevel'.`nomvar'] ///
							- _b[1._predict#`mod_samp_spec1'`bospec'`jlevel'.`nomvar']))
						local term_base `term_base' `part1'
					}
				}	
			}
			 
			local wgt_term_base `term_base'
			
			local 	term_com 0
			forvalues i = 1/`numlevels' {	
				local ilevel: word `i' of `nlevel'
				qui `svyspec' prop `nomvar' `weightspec'
				local p_i = e(b)[1,`i'] 
				forvalues j = 1/`numlevels' {
					if `i' < `j' {
						local jlevel: word `j' of `nlevel'
						local p_j = e(b)[1,`j'] 
						*Calculate weight, corrected for redundant comparisons
						local multiplier = [(`p_i'+`p_j') / (`numlevels' - 1)]
						local part2 ///
						+ ( `multiplier' * ///
							abs(_b[2._predict#`mod_samp_spec2'`bospec'`ilevel'.`nomvar'] ///
							- _b[2._predict#`mod_samp_spec2'`bospec'`jlevel'.`nomvar']))
						local term_com `term_com' `part2'
					}		
				}	
			}
			
			local wgt_term_com `term_com'
			 
			qui est restore meineq_margins
			capture `quietly' nlcom wgt_base: (`wgt_term_base'), level(`level')
			if _rc!=0{
				`quietly' nlcom wgt_base_1000: (`wgt_term_base')*1000, level(`level') post
				`quietly' nlcom wgt_base: _b[wgt_base_1000] / 1000, level(`level')		
			}
			
			return scalar wem1`ithvar'`bolvlspec' = r(table)[1,1]
			
			matrix `rt' = r(table)[1,1], r(table)[2,1], r(table)[3,1], ///
			r(table)[4,1], r(table)[5,1], r(table)[6,1]
			matrix `newmatwgt' = nullmat(`newmatwgt') \ `rt'
			
			** Weighted amount of inequality in comparison model
			qui est restore meineq_margins 
			capture `quietly' nlcom wgt_compare: (`wgt_term_com'), level(`level')
			if _rc!=0 {
				`quietly' nlcom wgt_compare_1000: (`wgt_term_com')*1000, level(`level') post
				`quietly' nlcom wgt_compare: _b[wgt_compare_1000]/1000, level(`level')		
			}

			return scalar wem2`ithvar'`bolvlspec' = r(table)[1,1]
						
			matrix `rt' = r(table)[1,1], r(table)[2,1], r(table)[3,1], ///
			r(table)[4,1], r(table)[5,1], r(table)[6,1]
			matrix `newmatwgt' = `newmatwgt' \ `rt'
			
			*test of Weighted amount of inequality in two models
			qui est restore meineq_margins
			capture `quietly' nlcom wgt_change: [(`wgt_term_base') - (`wgt_term_com')], level(`level')
			if _rc!=0 {
				`quietly' nlcom wgt_change_1000: [(`wgt_term_base') - (`wgt_term_com')]*1000, level(`level') post
				`quietly' nlcom wgt_change: _b[wgt_change_1000]/1000, level(`level')				
			}
			
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
						
			** load terms for calculation first
			** weighted terms 
			** Set up for the base model: mean
			local 	term_base 0
			qui levelsof `nomvar'
			forvalues i = 1/`numlevels' {	
				local ilevel: word `i' of `nlevel'
				forvalues j = 1/`numlevels' {
					if `i' < `j' {
						local jlevel: word `j' of `nlevel'
						local part1 ///
						+ abs(_b[1._predict#`mod_samp_spec1'`bospec'`ilevel'.`nomvar'] ///
						- _b[1._predict#`mod_samp_spec1'`bospec'`jlevel'.`nomvar'])
						local term_base `term_base' `part1'
					}
				}	
			}
			
			local abs_term_base `term_base'
			
			** Set up for the comparison model
			qui est restore meineq_margins
			qui levelsof `nomvar'
			local 	term_com 0
			forvalues i = 1/`numlevels' {	
				local ilevel: word `i' of `nlevel'
				forvalues j = 1/`numlevels' {
					if `i' < `j' {
						local jlevel: word `j' of `nlevel'
						local part2 ///
						+ abs(_b[2._predict#`mod_samp_spec2'`bospec'`ilevel'.`nomvar'] ///
						- _b[2._predict#`mod_samp_spec2'`bospec'`jlevel'.`nomvar'])
						local term_com `term_com' `part2'						
					}
				}	
			}	
			
			local abs_term_com `term_com'		
			
			** Unweighted (mean) amount of inequality in base model
			** Mean amount of inequality in base model
			qui est restore meineq_margins
			capture `quietly' nlcom mean_base: (`abs_term_base')/(`nc'), level(`level')
			if _rc!=0 {
				`quietly' nlcom mean_base_1000: (`abs_term_base')*1000/(`nc'), level(`level') post 
				`quietly' nlcom mean_base: _b[mean_base_1000] / 1000, level(`level')					
			}
			
			return scalar uwem1`ithvar'`bolvlspec' = r(table)[1,1]
			
			matrix `rt' = r(table)[1,1], r(table)[2,1], r(table)[3,1], ///
			r(table)[4,1], r(table)[5,1], r(table)[6,1]
			matrix `newmatmean' = nullmat(`newmatmean') \ `rt'
			
			** Mean amount of inequality in comparison model
			qui est restore meineq_margins
			capture `quietly' nlcom mean_compare: (`abs_term_com')/(`nc'), level(`level')
			if _rc!=0 {
				`quietly' nlcom mean_compare_1000: (`abs_term_com')*1000/(`nc'), level(`level') post
				`quietly' nlcom mean_compare: _b[mean_compare_1000] / 1000, level(`level')					
			}
			
			return scalar uwem2`ithvar'`bolvlspec' = r(table)[1,1]
			
			matrix `rt' = r(table)[1,1], r(table)[2,1], r(table)[3,1], ///
			r(table)[4,1], r(table)[5,1], r(table)[6,1]
			matrix `newmatmean' = `newmatmean' \ `rt'
			
			*Test of Mean amount of inequality in two models
			qui est restore meineq_margins
			capture `quietly' nlcom mean_change: [(`abs_term_base') ///
			- (`abs_term_com')]/(`nc'), level(`level')
			if _rc!=0 {
				`quietly' nlcom mean_change_1000: [(`abs_term_base') ///
				- (`abs_term_com')]*1000/(`nc'), level(`level') post
				`quietly' nlcom mean_change: _b[mean_change_1000] / 1000, level(`level')					
			}
			
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
	
		quietly est restore meineq_gsem
		
	} // end: continuous or binary DVs for 2 model

	****************************************************************************
	// Calculation of ME inequality stats: multi-level DV: 1 model
	****************************************************************************

	else if `nummods' == 1 & `mod1cats' >= 3 {

		`quietly' `margins' `byvarspec'`nomvar', `mimarginsspec' `overvarspec' `atmeans' post	
		qui est store meineq_margins
		
		qui levelsof 	`mod1dv'
		local dvlevels 	`r(levels)'
		
		** Wieghted inequality: By default
		if ("`unweighted'"=="") {		
		
			forvalues dvnum = 1/`mod1cats'{
				local dvlevel: word `dvnum' of `dvlevels'
				*store DV label (if it exists) to label table
				qui levelsof `mod1dv', local(levels_dv)
				qui ds `mod1dv', has(vallabel)
				if "`r(varlist)'" !=  "" {	// if value labels exist
					local lbe : value label `mod1dv'
					local temp_out_`dvlevel' : label `lbe' `dvlevel'
					local out_`dvlevel' = abbrev("`temp_out_`dvlevel''",13) 
					}
				else {	// if no value labels
						local out_`dvlevel' "Outcome `dvlevel'"
						}
			
				local 	term_base 0
							
				forvalues i = 1/`numlevels' {
					local ilevel: word `i' of `nlevel'
					qui `svyspec' prop `nomvar' `weightspec'
					local p_i = e(b)[1,`i'] 
					forvalues j = 1/`numlevels' {
						if `i' < `j' {
							local jlevel: word `j' of `nlevel'
							local p_j = e(b)[1,`j'] 
							*Calculate weight, corrected for redundant comparisons
							local multiplier = (`p_i'+`p_j') / (`numlevels' - 1)
							local part1 ///
							+ ( `multiplier' * ///
							abs(_b[`dvnum'._predict#`bospec'`ilevel'.`nomvar'] ///
							- _b[`dvnum'._predict#`bospec'`jlevel'.`nomvar']))		
							local term_base `term_base' `part1'	
							// note it is the #ith for DV (_predict); it is the levels of IV.
						}
					}			
				}
							
			**test if wgt_base could be calculated; if not *1000
			qui est restore meineq_margins
			capture `quietly' nlcom wgt_base: (`term_base'), level(`level')
			if _rc!=0 {
				`quietly' nlcom wgt_base_1000: (`term_base')*1000, level(`level') post
				`quietly' nlcom wgt_base: _b[wgt_base_1000] / 1000, level(`level')	
			}
			
			return scalar wem1`ithvar'`bolvlspec' = r(table)[1,1]
			
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
				*store DV label (if it exists) to label table
				qui levelsof `mod1dv', local(levels_dv)
				qui ds `mod1dv', has(vallabel)
				if "`r(varlist)'" !=  "" {	// if value labels exist
					local lbe : value label `mod1dv'
					local temp_out_`dvlevel' : label `lbe' `dvlevel'
					local out_`dvlevel' = abbrev("`temp_out_`dvlevel''",13) 
				}
				else {	// if no value labels
						local out_`dvlevel' "Outcome `dvlevel'"
				}
					
				** Set up for lincom calculation
				local 	term_base 0
				forvalues i = 1/`numlevels' {
					local ilevel: word `i' of `nlevel'
					forvalues j = 1/`numlevels' {
						if `i' < `j' {
							local jlevel: word `j' of `nlevel'
							local part1 ///
							+ abs(_b[`dvnum'._predict#`bospec'`ilevel'.`nomvar'] ///
							- _b[`dvnum'._predict#`bospec'`jlevel'.`nomvar'])
							local term_base `term_base' `part1'
						}
					}	
				}
				
				** Unweighted (mean) amount of inequality in base model
				qui est restore meineq_margins
				capture `quietly' nlcom mean_base: (`term_base')/(`nc'), level(`level')
				if _rc != 0 {
					`quietly' nlcom mean_base_1000: (`term_base')*1000/(`nc'), level(`level') post
					`quietly' nlcom mean_base: _b[mean_base_1000]/1000, level(`level')			
				}
				
				return scalar uwem1`ithvar'`bolvlspec' = r(table)[1,1]
				
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
			`quietly' `margins' `byvarspec'`nomvar', `mimarginsspec' `atmeans' ///
								over(me_inequality_mod_samp `overvar') post					
			local mod_samp_spec1 "1.me_inequality_mod_samp#"
			local mod_samp_spec2 "2.me_inequality_mod_samp#"
		}
		else {
			`quietly' `margins' `byvarspec'`nomvar', `mimarginsspec' `overvarspec' `atmeans' post	
			local mod_samp_spec1 ""
			local mod_samp_spec2 ""
		}
		qui est store meineq_margins
		
		qui levelsof 	`mod1dv'
		local dvlevels 	`r(levels)'
		
		** Wieghted inequality: By default
		if ("`unweighted'"=="") {		
			
			forvalues dvnum = 1/`mod1cats'{			 
			** load terms for calculation first
			** weighted terms 
			local dvlevel: word `dvnum' of `dvlevels'
			*store DV label (if it exists) to label table
			qui levelsof `mod1dv', local(levels_dv)
			qui ds `mod1dv', has(vallabel)
			if "`r(varlist)'" !=  "" {	// if value labels exist
				local lbe : value label `mod1dv'
				local temp_out_`dvlevel' : label `lbe' `dvlevel'
				local out_`dvlevel' = abbrev("`temp_out_`dvlevel''",13) 
			}
			else {	// if no value labels
					local out_`dvlevel' "Outcome `dvlevel'"
			}
			
			local term_base 0
				
				forvalues i = 1/`numlevels' {	
					local ilevel: word `i' of `nlevel'
					qui `svyspec' prop `nomvar' `weightspec'
					local p_i = e(b)[1,`i'] 
					forvalues j =1/`numlevels' {
						if `i' < `j' {
							local jlevel: word `j' of `nlevel'
							local p_j = e(b)[1,`j'] 
							*Calculate weight, corrected for redundant comparisons
							local multiplier = [(`p_i'+`p_j') / (`numlevels' - 1)]
							local part1 ///
							+ ( `multiplier' * ///
								abs(_b[`dvnum'._predict#`mod_samp_spec1'`bospec'`ilevel'.`nomvar'] ///
								- _b[`dvnum'._predict#`mod_samp_spec1'`bospec'`jlevel'.`nomvar']))
							local term_base `term_base' `part1'
						}
					}	
				}
				 
				local wgt_term_base `term_base'
				
				local 	term_com 0
				local  	dvnum2 = `dvnum' + `mod1cats'
				qui levelsof `nomvar'
				forvalues i = 1/`numlevels' {	
					local ilevel: word `i' of `nlevel'
					qui `svyspec' prop `nomvar' `weightspec'
					local p_i = e(b)[1,`i'] 
					forvalues j = 1/`numlevels' {
						if `i' < `j' {
							local jlevel: word `j' of `nlevel'
							local p_j = e(b)[1,`j'] 
							*Calculate weight, corrected for redundant comparisons
							local multiplier = [(`p_i'+`p_j') / (`numlevels' - 1)]
							local part2 ///
							+ ( `multiplier' * ///
								abs(_b[`dvnum2'._predict#`mod_samp_spec2'`bospec'`ilevel'.`nomvar'] ///
								- _b[`dvnum2'._predict#`mod_samp_spec2'`bospec'`jlevel'.`nomvar']))
							local term_com `term_com' `part2'
						}		
					}	
				}
				
				local wgt_term_com `term_com'
				 
				qui est restore meineq_margins
				capture `quietly' nlcom wgt_base: (`wgt_term_base'), level(`level')
				if _rc!=0{
					`quietly' nlcom wgt_base_1000: (`wgt_term_base')*1000, level(`level') post
					`quietly' nlcom wgt_base: _b[wgt_base_1000] / 1000, level(`level')				
				}
				
				return scalar wem1`ithvar'`bolvlspec' = r(table)[1,1]
			
				matrix `rt' = r(table)[1,1], r(table)[2,1], r(table)[3,1], ///
				r(table)[4,1], r(table)[5,1], r(table)[6,1]
				matrix `newmatwgt' = nullmat(`newmatwgt') \ `rt'

				
				** Weighted amount of heterogeneity in comparison model
				qui est restore meineq_margins 
				capture `quietly' nlcom wgt_compare: (`wgt_term_com'), level(`level')
				if _rc!=0 {
					`quietly' nlcom wgt_compare_1000: (`wgt_term_com')*1000, level(`level') post
					`quietly' nlcom wgt_compare: _b[wgt_compare_1000]/1000, level(`level')				
				}
				
				return scalar wem2`ithvar'`bolvlspec' = r(table)[1,1]
									
				matrix `rt' = r(table)[1,1], r(table)[2,1], r(table)[3,1], ///
				r(table)[4,1], r(table)[5,1], r(table)[6,1]
				matrix `newmatwgt' = `newmatwgt' \ `rt'
				
				*test of Weighted amount of inequality in two models
				qui est restore meineq_margins
				capture `quietly' nlcom wgt_change: [(`wgt_term_base') - (`wgt_term_com')], level(`level')
				if _rc!=0 {
					`quietly' nlcom wgt_change_1000: [(`wgt_term_base') - (`wgt_term_com')]*1000, level(`level') post
					`quietly' nlcom wgt_change: _b[wgt_change_1000]/1000, level(`level')				
				}
				
				return scalar wed`ithvar'`bolvlspec' = r(table)[1,1]
				
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
			*store DV label (if it exists) to label table
			qui levelsof `mod1dv', local(levels_dv)
			qui ds `mod1dv', has(vallabel)
			if "`r(varlist)'" !=  "" {	// if value labels exist
				local lbe : value label `mod1dv'
				local temp_out_`dvlevel' : label `lbe' `dvlevel'
				local out_`dvlevel' = abbrev("`temp_out_`dvlevel''",13) 
				}
			else {	// if no value labels
					local out_`dvlevel' "Outcome `dvlevel'"
					}
				
			local term_base 0
			
				forvalues i = 1/`numlevels' {	
					local ilevel: word `i' of `nlevel'
					forvalues j = 1/`numlevels' {
						if `i' < `j' {
							local jlevel: word `j' of `nlevel'
							local part1 ///
							+ abs(_b[`dvnum'._predict#`mod_samp_spec1'`bospec'`ilevel'.`nomvar'] ///
							- _b[`dvnum'._predict#`mod_samp_spec1'`bospec'`jlevel'.`nomvar'])
							local term_base `term_base' `part1'
						}
					}	
				}
				
				local abs_term_base `term_base'
				
				** Set up for the comparison model
				local 	term_com 0
				local  	dvnum2 = `dvnum' + `mod1cats'
				
				forvalues i = 1/`numlevels' {	
					local ilevel: word `i' of `nlevel'
					forvalues j = 1/`numlevels' {
						if `i' < `j' {
							local jlevel: word `j' of `nlevel'
							local part2 ///
							+ abs(_b[`dvnum2'._predict#`mod_samp_spec1'`bospec'`ilevel'.`nomvar'] ///
							- _b[`dvnum2'._predict#`mod_samp_spec1'`bospec'`jlevel'.`nomvar'])
							local term_com `term_com' `part2'						
						}
					}	
				}	
				
				local abs_term_com `term_com'		
				
				** Unweighted (mean) amount of inequality in base model
				** Mean amount of inequality in base model
				qui est restore meineq_margins
				capture `quietly' nlcom mean_base: (`abs_term_base')/(`nc'), level(`level')
				if _rc!=0 {
					`quietly' nlcom mean_base_1000: (`abs_term_base')*1000/(`nc'), level(`level') post 
					`quietly' nlcom mean_base: _b[mean_base_1000] / 1000, level(`level')					
				}
				
				return scalar uwem1`ithvar'`bolvlspec' = r(table)[1,1]
				
				matrix `rt' = r(table)[1,1], r(table)[2,1], r(table)[3,1], ///
				r(table)[4,1], r(table)[5,1], r(table)[6,1]
				matrix `newmatmean' = nullmat(`newmatmean') \ `rt'
				
				** Mean amount of inequality in comparison model
				qui est restore meineq_margins
				capture `quietly' nlcom mean_compare: (`abs_term_com')/(`nc'), level(`level')
				if _rc!=0 {
					`quietly' nlcom mean_compare_1000: (`abs_term_com')*1000/(`nc'), level(`level') post
					`quietly' nlcom mean_compare: _b[mean_compare_1000] / 1000, level(`level')					
				}
				
				return scalar uwem2`ithvar' = r(table)[1,1]
				
				matrix `rt' = r(table)[1,1], r(table)[2,1], r(table)[3,1], ///
				r(table)[4,1], r(table)[5,1], r(table)[6,1]
				matrix `newmatmean' = `newmatmean' \ `rt'
				
				*Test of Mean amount of inequality in two models
				qui est restore meineq_margins
				capture `quietly' nlcom mean_change: [(`abs_term_base') - (`abs_term_com')]/(`nc'), level(`level')
				if _rc!=0 {
					`quietly' nlcom mean_change_1000: [(`abs_term_base') - (`abs_term_com')]*1000/(`nc'), level(`level') post
					`quietly' nlcom mean_change: _b[mean_change_1000] / 1000, level(`level')					
				}
				
				return scalar uwed`ithvar'`bolvlspec' = r(table)[1,1]
				
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
		
		quietly est restore meineq_gsem // restore the mod for next estimation

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
	
end 

