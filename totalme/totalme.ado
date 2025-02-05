// Total ME for nominal/ordinal outcome variables
capture program drop totalme
*! totalme v1.0.2 Bing Han & Trenton Mize 2025-02-04

program define totalme, rclass
	
version 15

syntax 	varlist(fv) [fweight pweight iweight] , ///
		[MODels(string) ///
		GROUPs /// 
		GROUPNames(string) /// 
		amount(string) ///
		CENTERed ///
		ATMEANs ///
		start(string) ///
		WEIghted ///
		UNWEIghted /// 
		all /// 
		Details /// 
		COMMANDs ///
		DECimals(integer 3) /// 
		title(string) /// 
		ci /// 
		LABWidth(numlist >19 integer) /// 
		LEVEL(integer 3) ///				doesn't do anything yet
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
	local title "Total ME Estimates"
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

if "`levels'" == "" {
	local cilevel = 95
	local ll_spec "95% LL" 
	local ul_spec "95% UL"		
}
else {
	local cilevels = `levels'
	local ll_spec "`levels'% LL" 
	local ul_spec "`levels'% UL"
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
local supmods 	"logit probit mlogit ologit oprobit gologit2"
			
*Check # of models
local nummods: word count `models'

*Error out if 3 or more models are specified
if `nummods' > 2 {
	di as err "Invalid number of models in the {opt models()} option. " /*
	*/ "{cmd:totalme} can only be used with one or two models."
	exit	
} 

*Error out if group specified incorrectly
if "`groups'" != "" & `nummods' == 1 {
	di as err "The {opt groups} option requires two models to be specified in " /*
	*/ "the {opt models()} option—one for each group. See " /*
	*/ "{help totalme##groups}."
}		

*Set model names in the table
if "`groupnames'" != "" & "`groups'" == "" {
	di as err "The {opt groupnames} option requires two different models to be specified " /*
	*/ "using the {opt groups()} option. " /*
	*/ "See {help totalme##groupnames}."
	exit	
}

if "`groupnames'" != "" {
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
		di as err "The {opt weight} option requires two models to be specified in " /*
		*/ "the {opt models()} option—one for each group. " /*
		*/ "For a one-model situation, directly use weight in your model. " /*
		*/ "See {help totalme##weight}."
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
	quietly est store mod1
	local mod1 mod1
	local nummods = 1
}

*Restore mod1
quietly est restore `mod1'

local cmd_m1 "`e(cmd)'"
local cmdline_m1 "`e(cmdline)'"
local vcetype1	= "`e(vce)'"
tempvar mod1samp
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
		di as err "{cmd:totalme} requires the user-written package " /*
		*/ "{cmd:mimrgns}. Click on the link below to search for " /*
		*/ "and install {cmd:mimrgns}: {stata search mimrgns: {bf:mimrgns}}"
		exit
		}
		
	local Nsav1 = e(N_mi)
	local cmd_m1 "`e(cmd_mi)'"
	local prefix1 = "`e(prefix_mi)'"	
	local margins "mimrgns"
	local mimarginsspec `e(marginsdefault)'
	
	if "`cmd_m1'" == "logit" | "`cmd_m1'" == "probit" {
		local mimarginsspec ""
	}	
}	
	
*Check if model 1 is supported
if strpos("`supmods'","`cmd_m1'") == 0 {
	di as err "`mod1' is a {cmd:`cmd_m1'}. {cmd:totalme} " /* 
	*/ "only supports the following estimation commands: " /*
	*/ "logit, probit, mlogit, ologit, oprobit, and gologit2."
	exit
}
	
*Save the number of categories for ologit and mlogit
if "`cmd_m1'" == "ologit" | "`cmd_m1'" == "oprobit" {	
	local mod1cats = e(k_cat)
	local div1 = 2
	}
else if "`cmd_m1'" == "mlogit" {
	local mod1cats = e(k_eq)
	local div1 = 2
	}
else if "`cmd_m1'" == "logit" | "`cmd_m1'" == "probit" {
	local mod1cats = e(k_eq)
	local div1 = 1
	}

*Restore mod2
if `nummods' == 2 {
	qui est restore `mod2'
	local cmd_m2 "`e(cmd)'"
	local cmdline_m2 "`e(cmdline)'"
	local vcetype2	= "`e(vce)'"
	tempvar mod2samp
	qui gen `mod2samp' = e(sample)
	local Nsav2 = e(N)	
	local mod2dv = 	"`e(depvar)'"
	local ifweight2 = "`e(wexp)'"
	local prefix2 = "`e(prefix)'"
	
	if "`cmd_m2'" == "mi estimate" {
		local Nsav2 = e(N_mi)
		local cmd_m2 "`e(cmd_mi)'"
		local prefix2 = "`e(prefix_mi)'"	
	}
	
	capture drop total_me_mod_samp // use unique name to avoid being taken
	quietly gen total_me_mod_samp  = .
	quietly replace total_me_mod_samp  = 1 if `mod1samp' == 1
	quietly replace total_me_mod_samp  = 2 if `mod2samp' == 1
	
	quietly count if total_me_mod_samp == 1
	local Nsav1_ovlp = `r(N)'
	
	*Error out if group number is not consistent with the e(sample)
	if "`groups'" != "" & (`Nsav1_ovlp'!=`Nsav1') {
		di _newline(1)
		di as err "{opt groups} option does not support overlapped samples across groups. " /*
		*/ "See {help totalme##groups} for details."
		exit		
	}
	
	*Save the number of categories for model2
	if "`cmd_m2'" == "ologit" | "`cmd_m2'" == "oprobit" {	
		local mod2cats = e(k_cat)
		local div2 = 2
		}
	else if "`cmd_m2'" == "mlogit" {
		local mod2cats = e(k_eq)
		local div2 = 2
		}
	else if "`cmd_m2'" == "logit" | "`cmd_m2'" == "probit" {
		local mod2cats = e(k_eq)
		local div2 = 1
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
			di in red "{cmd:totalme} does not support options except vce(robust) " /*
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
			di in red "{cmd:totalme} does not support options except vce(robust) " /*
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
			di as err "{cmd:totalme} does not support individual weight options " /*
			*/ "for two-model cases. " /*
			*/ "Specify weight options globally using the weight specification. " /*
			*/ "See {help totalme} for details."
			exit
	}
	
	*Error out if svy prefix specified
	if "`prefix1'" == "svy" | "`prefix2'" == "svy" {
		di _newline(1)
		di as err "{cmd:totalme} does not support the {opt svy:} prefix " /*
		*/ "when two models are specified. " /*
		*/ "Consider using weight options instead of {opt svy:}. " /*
		*/ "See {help totalme} for details."
		exit
	}	
		
	*Error out if mi estimate prefix specified
	if "`prefix1'" == "mi estimate" | "`prefix2'" == "mi estimate" {
		
		if "`prefix1'" != "`prefix2'" {
			di _newline(1)
			di as err "The prefixes do not match in the two models. " /*
			*/ "The prefix for `mod1' is `prefix1', and the prefix for `mod2' is `prefix2'."
			exit
		}
		
		local gsemprefix "mi estimate, cmdok: "
		local predictspec ""	
		
	}
	
	if "`prefix1'" != "mi estimate" & "`prefix1'" != "" {
		di _newline(1)
		di as err "{cmd:totalme} does not support `prefix1' prefix " /*
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
// Model specification
****************************************************************************

if `nummods' == 1 {
	local samp1_size = e(N)
	local mod1varnum : 	word count `cmdline_m1'

	di 		in white "Model (`mod1') is:"
	di 		in yellow "     `cmdline_m1'"
	
	tempvar totalme_sample 
	qui gen `totalme_sample' = 1 if e(sample) 	// to get correct SDs below
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
		qui replace `mod1dv'_COPY1 = . if total_me_mod_samp != 1
		local mod1dv_use = "`mod1dv'_COPY1"
		qui clonevar `mod2dv'_COPY2 = `mod2dv'
		qui replace `mod2dv'_COPY2 = . if total_me_mod_samp != 2
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
		*/ "The results from {cmd:totalme} will not match " /*
		*/ "those from the specified models as {cmd:totalme} uses listwise " /*
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
	
	quietly est store totalme_gsem
	local mimarginsspec `e(marginsdefault)'
	
	local samp1_size = e(_N)[1,1]
	local samp2_size = e(_N)[1,2]
	
	tempvar totalme_sample 
	qui gen `totalme_sample' = 1 if e(sample) 	// to get correct SDs below
	
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
	exit	
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
			exit
		}
	}
	else if `nummods' == 2 {
		if strpos("`cmdline_m1'", "`ivar'") == 0 | ///
		strpos("`cmdline_m2'","`ivar'") == 0 { 
			di _newline(1)
			di as err "Variable `ivar' not found in both models."
			exit
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
		qui levelsof `ivar'
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
	di 		in white "Continuous/Binary IV(s): "
	di 		in yellow "     `conivs'"
}
if "`nomivs'" != ""  {	
	di 		in white "Nominal IV(s):"
	di 		in yellow "     `nomivs'"
}

*Check continuous variables only

local numamounts : word count `amount'
local numpconvars : word count `pconivs'

if "`amounts'" != "" & `numpconvars' == 0 {
	di _newline(1)
	di as err "Incorrect specification in {opt amount( )} option. " /*
	*/ "This option is only for continuous variables. "
	exit
}
	
if `numamounts' > 1 & `numamounts' != `numpconvars' {
	di _newline(1)
	di as err "Incorrect specification in {opt amount( )} option. Either " /*
	*/ "specify only one amount which is used for all of the continuous " /*
	*/ "independent variables or specify an equal number of amounts as " /*
	*/ "continuous variables. There are `numcontvars' continuous variables: " /*
	*/ "{it:`contvars'} -- but `numamounts' amounts specified in {opt amount( )}"
	exit
	}

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
tempname newmatmean newmatwgt newmatall newmatall_m newmatall_uw 

local newmatall "full_matrix"
local newmatall_w "weighted_null_matrix"
local newmatall_uw "unweighted_null_matrix"

** generate a nullmat for all 
matrix `newmatall' = J(1, 6, .)
matrix `newmatall_w' = J(1, 6, .)
matrix `newmatall_uw' = J(1, 6, .)

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
				
		local 	v : word `i' of `conivs'
		fvexpand i.`v'
		local 	numcats : word count `r(varlist)' 

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
				local change`v' "`startlab' + 1`centerlab'"
				}
			else if "`amount`cnum''" == "sd" {
				local change`v' "`startlab' + SD`centerlab'"
				}
			else {
				local change`v' "`startlab' + `amount`cnum''`centerlab'"
				}	
			local 	mspec`i' at(`startval') at(`endval')
			local 	++cnum	
		
		} // end: continuous variable 
		
		*For binary vars
		*NOTE: Need to do this in at( ) statement so get separate predictions
		*	if continuous vars also specified; i.e. can't use dydx( )
		
		if `numcats' == 2 {
			qui levelsof 	`v'
			local catsnom 	`r(levels)'
		
			local changelbl ""
			
			forvalues vi=1/2 {
				local vlevel: word `vi' of `catsnom'
				qui levelsof `v', local(levels_v)
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
			local  	change`v' "`changelbl2' vs `changelbl1'" //don't use "vs."
		}
		
		local mrgspec "`mspec`i''" 	

		************************************************************************
		// Specification of total ME: 1 Model
		************************************************************************
		
		if `nummods' == 1 {
			
			`quietly' `margins', `mrgspec' `atmeans' post  
			qui est store totalme_margins
			
			local 	term_base 0

			if `mod1cats' == 1 { 
				local term_base abs(_b[2._at] - _b[1._at])
			}
			
			else {
				forvalues i = 1/`mod1cats' {			
					local part1 ///
					+ abs(_b[`i'._predict#2._at] - _b[`i'._predict#1._at])	
					local term_base `term_base' `part1'	
				}	
			}
			**save terms for comparison
			local contrast`v' (`term_base')/`div1' 
			
			**test if wgt_base could be calculated; if not *1000
			capture `quietly' nlcom conivs_nlcom: (`term_base')/`div1' 
			if _rc!=0 {
				`quietly' nlcom conivs_nlcom_1000: ((`term_base')/`div1')*1000, post
				`quietly' nlcom conivs_nlcom: _b[conivs_nlcom_1000] / 1000	
			}
			
			matrix `rt' = r(table)[1,1], r(table)[2,1], r(table)[3,1], ///
			r(table)[4,1], r(table)[5,1], r(table)[6,1]
			matrix `newmatconivs_temp' = nullmat(`newmatconivs_temp') \ `rt'
			matrix rownames `newmatconivs_temp' = "`v':`change`v''" 
			matrix `newmatconivs' = `newmatconivs' \ `newmatconivs_temp'
			matrix drop `newmatconivs_temp'
			quietly est restore `mod1' // restore the mod for next estimation
			
		} // end: continuous or binary IVs for 1 model
	
		************************************************************************
		// Calculation of total ME: 2 Model
		************************************************************************
		
		else if `nummods' == 2 {
					
			** Calculate the margins for the nominal variables in the gsem model
			if "`groups'" != "" {
				`quietly' `margins', `mrgspec' `mimarginsspec' `atmeans' over(total_me_mod_samp) post	
				local mod_samp_spec1 "#1.total_me_mod_samp"
				local mod_samp_spec2 "#2.total_me_mod_samp"
			}
			else {
				`quietly' `margins', `mrgspec' `mimarginsspec' `atmeans' post	
				local mod_samp_spec1 ""
				local mod_samp_spec2 ""
			}
			
			qui est store totalme_margins	// For use with post-estimation melincom
			
			local 	term_base 0
			local 	term_com 0

			forvalues i = 1/`mod1cats' {	
				local part1 ///
				+ abs(_b[`i'._predict#2._at`mod_samp_spec1'] ///
				- _b[`i'._predict#1._at`mod_samp_spec1'])	
				local term_base `term_base' `part1'	
			}

			forvalues i = 1/`mod2cats' {				
				local i2 = `i' + `mod1cats'
				local part2 ///
				+ abs(_b[`i2'._predict#2._at`mod_samp_spec2'] ///
				- _b[`i2'._predict#1._at`mod_samp_spec2'])	
				local term_com `term_com' `part2'	
			}
			
			** total me in base model
			qui est restore totalme_margins
			capture `quietly' nlcom conivs_nlcom_base: (`term_base')/`div1' 
			if _rc!=0 {
				`quietly' nlcom conivs_nlcom_base_1000: ((`term_base')/`div1')*1000, post
				`quietly' nlcom conivs_nlcom_base: _b[conivs_nlcom_base_1000] / 1000	
			}
			
			matrix `rt' = r(table)[1,1], r(table)[2,1], r(table)[3,1], ///
			r(table)[4,1], r(table)[5,1], r(table)[6,1]
			matrix `newmatconivs_temp' = nullmat(`newmatconivs_temp') \ `rt'
			
			** total me in comparison model
			qui est restore totalme_margins
			capture `quietly' nlcom conivs_nlcom_com: (`term_com')/`div2' 
			if _rc!=0 {
				`quietly' nlcom conivs_nlcom_com_1000: ((`term_com')/`div2')*1000, post
				`quietly' nlcom conivs_nlcom_com: _b[conivs_nlcom_com_1000] / 1000	
			}
			
			matrix `rt' = r(table)[1,1], r(table)[2,1], r(table)[3,1], ///
			r(table)[4,1], r(table)[5,1], r(table)[6,1]
			matrix `newmatconivs_temp' = `newmatconivs_temp' \ `rt'
			
			*test total me in two models
			qui est restore totalme_margins
			capture `quietly' nlcom conivs_nlcom_change: [((`term_base')/`div1') - ((`term_com')/`div2')]
			if _rc!=0 {
				`quietly' nlcom conivs_nlcom_change_1000: [((`term_base')/`div1')*1000 - ((`term_com'/`div2'))*1000], post
				`quietly' nlcom conivs_nlcom_change: _b[conivs_nlcom_change_1000]/1000	
			}
			
			matrix `rt' = r(table)[1,1], r(table)[2,1], r(table)[3,1], ///
			r(table)[4,1], r(table)[5,1], r(table)[6,1]
			matrix `newmatconivs_temp' = `newmatconivs_temp' \ `rt'
		
			matrix rownames `newmatconivs_temp' = ///
				"`v':Model 1 (`mod1lab')" ///
				"`v':Model 2 (`mod2lab')" ///
				"`v':Cross-Model Diff."
			
			matrix `newmatconivs' = `newmatconivs' \ `newmatconivs_temp'
			matrix drop `newmatconivs_temp'
			
			quietly est restore totalme_gsem // restore the mod for next estimation
			
		} // end: continuous or binary IVs for 2 model

	}
	
}


****************************************************************************
// Calculation of total ME: nominal IVs
****************************************************************************

** number of continuous/binary variables
local numnomvars : word count `nomivs'

if 	`numnomvars' == 0 & ///
("`weighted'"!="" | "`unweighted'"!="" | "`all'"!=""){
	di _newline(1)
	di as err "Incorrect specification in {opt weighted/unweighted/all} option." /*
	*/ "The options are only for nominal independent variables. "
	exit
}

if `numnomvars' != 0 {
	
	forvalues i = 1/`numnomvars'{
				
		local nomvar : 	word `i' of `nomivs'	
				
		** # of n for variable
		qui count if !missing(`nomvar')
		local tot_n = `r(N)'	
		
		** all levels of the nominal variable
		qui levelsof 	`nomvar'
		local nlevel 	`r(levels)'
		local numlevels	`r(r)'	
		
		** # of comparison groups
		local nc = ((`r(r)')*(`r(r)'-1)/2)
						
		************************************************************************
		// Calculation of total ME: 1 Model
		************************************************************************
		
		if `nummods' == 1 {
				
			`quietly' `margins' `nomvar', `mimarginsspec' `atmeans' post	
			qui est store totalme_margins
			
			qui levelsof 	`mod1dv'
			local dvlevels 	`r(levels)'
			
			** Wieghted inequality: By default
			if ("`unweighted'"=="") {		
			
				local term_base_all 0
 				
				forvalues dvnum = 1/`mod1cats'{
					
					** seperate logit/probit models
					if "`cmd_m1'" == "logit" | "`cmd_m1'" == "probit" {
						local predictspec ""
					}
					else {
						local predictspec `dvnum'._predict#	
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
								local multiplier = (`p_i'+`p_j') / (`numlevels' - 1)
								local part1 ///
								+ ( `multiplier' * ///
								abs(_b[`predictspec'`ilevel'.`nomvar'] ///
								- _b[`predictspec'`jlevel'.`nomvar']))		
								local term_base `term_base' `part1'	
							}
						}			
					}

					local term_base_all `term_base_all' + (`term_base')
				}
				
				qui est restore totalme_margins
				capture `quietly' nlcom wgt_base_all: (`term_base_all')/`div1' 
				if _rc!=0 {
					`quietly' nlcom wgt_base_all_1000: ((`term_base_all')/`div1')*1000, post
					`quietly' nlcom wgt_base_all: _b[wgt_base_all_1000] / 1000
				}				
				
				matrix `rt' = r(table)[1,1], r(table)[2,1], r(table)[3,1], ///
				r(table)[4,1], r(table)[5,1], r(table)[6,1]
				matrix `newmatwgt' = nullmat(`newmatwgt') \ `rt'
				
				**set the row names 
				matrix rownames `newmatwgt' = "`nomvar': total ME Ineq." 
				matrix `newmatall' = `newmatall' \ `newmatwgt'
				matrix drop `newmatwgt'
				
			} // end: weighted meinequality
			
			if "`all'"!="" | "`unweighted'"!="" {
				
				local term_base_all 0
				forvalues dvnum = 1/`mod1cats'{
					
					** seperate logit/probit models
					if "`cmd_m1'" == "logit" | "`cmd_m1'" == "probit" {
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
								+ abs(_b[`predictspec'`ilevel'.`nomvar'] ///
								- _b[`predictspec'`jlevel'.`nomvar'])
								local term_base `term_base' `part1'
							}
						}	
					}
					
					local term_base_all `term_base_all' + (`term_base')
				}
				** ssave terms for comparison
				local contrast`nomvar' (`term_base')/`div1'
				
				qui est restore totalme_margins
				capture `quietly' nlcom mean_base_all: (`term_base_all')/`div1'
				if _rc!=0 {
					`quietly' nlcom mean_base_all_1000: ((`term_base_all')/`div1')*1000, post
					`quietly' nlcom mean_base_all: _b[mean_base_all_1000] / 1000
				}	
				
				matrix `rt' = r(table)[1,1], r(table)[2,1], r(table)[3,1], ///
				r(table)[4,1], r(table)[5,1], r(table)[6,1]
				matrix `newmatmean' = nullmat(`newmatmean') \ `rt'
				**set the row names	
				matrix rownames `newmatmean' = "`nomvar': Unwgt total ME Ineq." 		
				matrix `newmatall' = `newmatall' \ `newmatmean'
				matrix drop `newmatmean'
			
			} // end: unweighted meinequality
			quietly est restore `mod1' 
		} // end: 1 mod situation
		
		************************************************************************
		// Calculation of total ME: 2 Model
		************************************************************************
		
		else if `nummods' == 2 {

			if "`groups'" != "" {
				`quietly' `margins' `nomvar', `mimarginsspec' `atmeans' ///
							over(total_me_mod_samp) post	
				local mod_samp_spec1 "1.total_me_mod_samp#"
				local mod_samp_spec2 "2.total_me_mod_samp#"
			}
			else {
				`quietly' `margins' `nomvar', `mimarginsspec' `atmeans' post	
				local mod_samp_spec1 ""
				local mod_samp_spec2 ""
			}
			qui est store totalme_margins
			
			** Wieghted inequality: By default
			if ("`unweighted'"=="") {		
				
				local term_base_all 0
				local term_com_all 0
				
				forvalues dvnum = 1/`mod1cats'{			 

					** 1st model				
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
									abs(_b[`dvnum'._predict#`mod_samp_spec1'`ilevel'.`nomvar'] ///
									- _b[`dvnum'._predict#`mod_samp_spec1'`jlevel'.`nomvar']))
								local term_base `term_base' `part1'
							}
						}	
					}
		
					local term_base_all `term_base_all' + (`term_base')
				}
				
				forvalues dvnum = 1/`mod2cats'{			 
					** 2nd model				
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
									abs(_b[`dvnum2'._predict#`mod_samp_spec2'`ilevel'.`nomvar'] ///
									- _b[`dvnum2'._predict#`mod_samp_spec2'`jlevel'.`nomvar']))
								local term_com `term_com' `part2'
							}		
						}	
					}
					local term_com_all `term_com_all' + (`term_com')
				}
				
				qui est restore totalme_margins
				capture `quietly' nlcom wgt_base_all: (`term_base_all')/`div1'
				if _rc!=0 {
					`quietly' nlcom wgt_base_all_1000: ((`term_base_all')/`div1')*1000, post
					`quietly' nlcom wgt_base_all: _b[wgt_base_all_1000] / 1000
				}
				
				matrix `rt' = r(table)[1,1], r(table)[2,1], r(table)[3,1], ///
				r(table)[4,1], r(table)[5,1], r(table)[6,1]
				matrix `newmatwgt' = nullmat(`newmatwgt') \ `rt'					
				
				qui est restore totalme_margins
				capture `quietly' nlcom wgt_com_all: (`term_com_all')/`div2'
				if _rc!=0 {
					`quietly' nlcom wgt_com_all_1000: ((`term_com_all')/`div2')*1000, post
					`quietly' nlcom wgt_com_all: _b[wgt_com_all_1000] / 1000	
				}
				
				matrix `rt' = r(table)[1,1], r(table)[2,1], r(table)[3,1], ///
				r(table)[4,1], r(table)[5,1], r(table)[6,1]
				matrix `newmatwgt' = `newmatwgt' \ `rt'
				
				*test of Weighted amount of inequality in two models
				qui est restore totalme_margins
				capture `quietly' nlcom wgt_change_all: [((`term_base_all')/`div1') - ((`term_com_all')/`div2')]
				if _rc!=0 {
					`quietly' nlcom wgt_change_all_1000: [((`term_base_all')/`div1') - ((`term_com_all')/`div2')]*1000, post
					`quietly' nlcom wgt_change_all: _b[wgt_change_all_1000] / 1000	
				}
				
				matrix `rt' = r(table)[1,1], r(table)[2,1], r(table)[3,1], ///
				r(table)[4,1], r(table)[5,1], r(table)[6,1]
				matrix `newmatwgt' = `newmatwgt' \ `rt'	
			
				matrix rownames `newmatwgt' = ///
					"`nomvar' total ME Ineq.:Model 1 (`mod1lab')" ///
					"`nomvar' total ME Ineq.:Model 2 (`mod2lab')" ///
					"`nomvar' total ME Ineq.:Cross-Model Diff."
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
								+ abs(_b[`dvnum'._predict#`mod_samp_spec1'`ilevel'.`nomvar'] ///
								- _b[`dvnum'._predict#`mod_samp_spec1'`jlevel'.`nomvar'])
								local term_base `term_base' `part1'
							}
						}	
					}
					local term_base_all `term_base_all' + (`term_base')
				}	 
				** Set up for the comparison model
				forvalues dvnum = 1/`mod2cats'{			 
					local 	term_com 0
					local  	dvnum2 = `dvnum' + `mod1cats'
					
					forvalues i = 1/`numlevels' {	
						local ilevel: word `i' of `nlevel'
						forvalues j = 1/`numlevels' {
							if `i' < `j' {
								local jlevel: word `j' of `nlevel'
								local part2 ///
								+ abs(_b[`dvnum2'._predict#`mod_samp_spec1'`ilevel'.`nomvar'] ///
								- _b[`dvnum2'._predict#`mod_samp_spec1'`jlevel'.`nomvar'])
								local term_com `term_com' `part2'						
							}
						}	
					}	
					local term_com_all `term_com_all' + (`term_com')					
				}
				
				qui est restore totalme_margins
				capture `quietly' nlcom mean_base_all: (`term_base_all')/`div1'
				if _rc!=0 {
					`quietly' nlcom mean_base_all_1000: ((`term_base_all')/`div1')*1000, post
					`quietly' nlcom mean_base_all: _b[mean_base_all_1000] / 1000
				}
				
				matrix `rt' = r(table)[1,1], r(table)[2,1], r(table)[3,1], ///
				r(table)[4,1], r(table)[5,1], r(table)[6,1]
				matrix `newmatmean' = nullmat(`newmatmean') \ `rt'					
				
				qui est restore totalme_margins
				capture `quietly' nlcom wgt_com_all: (`term_com_all')/`div2'
				if _rc!=0 {
					`quietly' nlcom wgt_com_all_1000: ((`term_com_all')/`div2')*1000, post
					`quietly' nlcom wgt_com_all: _b[wgt_com_all_1000] / 1000	
				}
				
				matrix `rt' = r(table)[1,1], r(table)[2,1], r(table)[3,1], ///
				r(table)[4,1], r(table)[5,1], r(table)[6,1]
				matrix `newmatmean' = `newmatmean' \ `rt'
				
				*test of Weighted amount of inequality in two models
				qui est restore totalme_margins
				capture `quietly' nlcom wgt_change_all: [((`term_base_all')/`div1') - ((`term_com_all')/`div2')]
				if _rc!=0 {
					`quietly' nlcom wgt_change_all_1000: [((`term_base_all')/`div1') - ((`term_com_all')/`div2')]*1000, post
					`quietly' nlcom wgt_change_all: _b[wgt_change_all_1000] / 1000	
				}
				
				matrix `rt' = r(table)[1,1], r(table)[2,1], r(table)[3,1], ///
				r(table)[4,1], r(table)[5,1], r(table)[6,1]
				matrix `newmatmean' = `newmatmean' \ `rt'	

				matrix rownames `newmatmean' = ///
					"`nomvar' toal Unwgt MEIneq:Model 1 (`mod1lab')" ///
					"`nomvar' toal Unwgt MEIneq:Model 2 (`mod2lab')" ///
					"`nomvar' toal Unwgt MEIneq:Cross-Model Diff."
				matrix `newmatall' = `newmatall' \ `newmatmean'
				matrix drop `newmatmean'	
				
			} // end: unweighted estimation
			
			quietly est restore totalme_gsem // restore the mod for next estimation

		} // end: nominal DVs for 2 models				
	}	
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

mat _totalme = `newmatall'		

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

