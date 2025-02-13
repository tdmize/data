*******************
// mecompare.ado //
*******************

capture program drop mecompare
*! mecompare v0.1.4 Trenton Mize 2025-02-13

*Revision notes
* - v0.1.4 adds support for gologit2 for one model case
* - version 2024-11-08 group specs now more flexible / error out if issue

program define mecompare, rclass 
	version 15.1

	syntax [varlist(default=none fv)] [if] [in] [fweight pweight iweight], ///
		MODels(string) 	/// <- this is a required option
						/// below are optional options
		[STATistics(string) amount(string) CENTERed COMMANDs DETAILs ///
		group(varlist max=1) start(string) COVariates(string) ///
		DECimals(string) MOD1name(string) MOD2name(string) NOROWnum ///
		LABWidth(numlist >19 integer) STATWidth(numlist >7 integer)]  

*Error out if if/in qualifiers specify no obs; store N
marksample touse
qui count if `touse'
	local N = `r(N)'
	
	if `r(N)' == 0 {
		error 2000
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
	local dec = `decimals'
	}
if "`labwidth'" == "" {
	local twidth = 32
	}
	else {
	local twidth = `labwidth'
	}
if "`statwidth'" == "" {
	local width = 9
	}
	else {
	local width = `statwidth'
	}

*Override default of adding row numbers if norownum is requested
if "`norownum'" != "" {
	local addnums = 0
	}
else {
	local addnums = 1
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
		
*Estimate gsem and margins command noisily or quietly based on details option
if "`details'" != "" {
	local cmdqui ""
	}
else {
	local cmdqui "qui"
	}	
		
*Check whether there are 1 or 2 models
local nummods : word count `models'

*Error out if group specified incorrectly
if "`group'" != "" & `nummods' == 1 {
	di as err "The {group( )} option requires two models be specified in " /*
	*/ "{opt models( )} option -- one for each group. See " /*
	*/ "{help mecompare##group}."
	}

*Create locals to refer to models by #
forvalues i = 1/`nummods' {
	local mod`i' : word `i' of `models'
	}

*Error out if 0 or >= 3 models listed
if `nummods' == 0 | `nummods' >= 3 {
	di as err "Invalid number of models listed in {opt models( )} option. " /*
	*/ "{cmd:mecompare} can only be used with one or two models."
	exit	
} 

*Set weight specification 
if "`weight'" != "" {
	local weightspec = "[`weight' `exp']"
	}
	
*List of supported models which is double-checked below
local supmods "regress logit probit mlogit ologit oprobit gologit2 poisson nbreg"
	
	
****************************************************************************
// If 1 model, restore the estimates and store information
****************************************************************************
if `nummods' == 1 {
	est restore `mod1'
	
	local 	N1 = e(N)
	local 	dv1name 	= "`e(depvar)'"
	tempvar mec_sample 
	qui gen `mec_sample' = 1 if e(sample) 	// to get correct SDs below

*Error out if or mi est: prefix used on model 
if "`e(prefix_mi)'" == "mi estimate" {
	di _newline(1)
	di as err "{cmd:mecompare} does not support mi estimate." 
	exit
	}	
	
if strpos("`supmods'","`e(cmd)'") { // check if a supported model
		}	
else {
	di as err "`mod1' is a {cmd:`e(cmd)'}. {cmd:mecompare} " /* 
	*/ "only supports the following estimation commands: " /*
	*/ "regress, logit, probit, mlogit, ologit, poisson, nbreg"
	exit
	}
	
// Set num of cats for preds
if "`e(cmd)'" == "ologit" | "`e(cmd)'" == "oprobit" | "`e(cmd)'" == "gologit2" {		
	local mod1cats = e(k_cat)
	}
else if "`e(cmd)'" == "mlogit" {
	local mod1cats = e(k_eq)
	}
else {
	local mod1cats = 1
	}
		
if "`varlist'" == "" { // If no vars listed, calculate MEs for all IVs
	
	*Strip the model options after comma if present
	local ifcomma = strpos("`e(cmdline)'", ",")  
	if `ifcomma' == 0 {
		local cmdline = "`e(cmdline)'"
		}
	else {	
		local cmdline = substr("`e(cmdline)'", 1, strpos("`e(cmdline)'", ",") - 1) 
		}

	*Strip prefix (e.g. svy: ) if present
	local 	colon = strpos("`cmdline`i''", ":")  
	if `colon' != 0 { 
		local cmdline`i' = substr("`cmdline`i''", `colon' + 1 , . ) 
		}	
	
	*Store just the IVs for later use
	local numivs1 : word count `cmdline'	
	local rhs1 " "
		forvalues b = 3/`numivs1' {
			local v : word `b' of `cmdline'
			local rhs1 "`rhs1' `v'"
			}

	*Parse constituent parts of interaction, polynomials	
	local clean_list1a  = subinstr("`rhs1'","#"," ",.)
	local clean_list1b  = subinstr("`clean_list1a'","c."," ",.)
	local list_ivs : list uniq clean_list1b
	}			

else {
	local list_ivs "`varlist'"
	}
	
}

****************************************************************************
// If 2 models, simultaneously estimate models with gsem and apply SUEST //
****************************************************************************
if `nummods' == 2 {
	forvalues i = 1/`nummods' {

	qui est restore  `mod`i''

*Store DVs, estimation commands, list of IVs, sample
local mod`i'samp 	= e(sample)
local Nsav`i' 		= e(N)	// N of saved model; double-checked after gsem
local dv`i' 		= "`e(depvar)'"
local dv`i'name 	= "`e(depvar)'" // store original name if duplicating
local cmd`i' 		= "`e(cmd)'"
local cmdline`i' 	= "`e(cmdline)'"
local vcetype`i'	= "`e(vce)'" // Will produce warning below if not robust

*Error out if svy: or mi est: prefix used on model 
if "`e(prefix)'" == "svy" | "`e(prefix_mi)'" == "mi estimate" {
	di _newline(1)
	di as err "{cmd:mecompare} does not support svy or mi estimate " /*
	*/ "when two models are specified." 
	exit
	}	
	
if strpos("`supmods'","`e(cmd`i')'") { // check if a supported model
	}	
else {
	di as err "`mod`i'' is a {cmd:`cmd`i''}. {cmd:mecompare} only " /*
	*/ "supports the following estimation commands: " /*
	*/ "regress, logit, probit, mlogit, ologit, oporbit, gologit2, poisson, nbreg"
	exit
	}

// Set num of cats for preds	
if "`e(cmd)'" == "ologit" | "`e(cmd)'" == "oprobit" | "`e(cmd)'" == "gologit2" {		
	local mod`i'cats = e(k_cat)
	}
else if "`e(cmd)'" == "mlogit" {
	local mod`i'cats = e(k_eq)
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

*if group( ); store if statement; strip the if statement for cmdline local 
if "`group'" != "" {
	local group`i'if = substr("`cmdline`i''", strpos("`cmdline`i''", "if") + 2, .) 
	local cmdline`i' = substr("`cmdline`i''", 1, strpos("`cmdline`i''", "if") - 1) 
	qui levelsof `group' if `group`i'if'
	local group`i' = `r(levels)'
	}


*Store just the IVs for later use
local 	numivs`i' : word count `cmdline`i''	
local 	ivs`i' " "
forvalues b = 3/`numivs`i'' {
	local v : word `b' of `cmdline`i''
	local ivs`i' "`ivs`i'' `v'"
	}

} // End of looping through each of the two models


* Set group specs 
if "`group'" != "" & "`mod1name'" == "" & "`mod2name'" == "" {
	local fv = strpos("`group'", ".") + 1 		// find where . is if factor
	if `fv' != 0 {								// syntax was used, if so
		local group = substr("`group'",`fv',.) 	// strip fv prefix
		}
	local grouplevs "`group1' `group2'"
	qui ds `group', has(vallabel)	// Label models by value label
		if "`r(varlist)'" !=  "" {
			local lbe 		: value label `group'
			local num = 1
				foreach lev in `grouplevs' {
					local c`lev' : label `lbe' `lev'
					local mod`num'lab = "`c`lev''"
					local ++num
					}
				}
		else {						// Label by # if no value label
			local num = 1
				foreach lev in `grouplevels' {
					local mod`num'lab = "Group #`lev'"
					local ++num
					}		
			}
	local mod1lab = substr("`mod1lab'",1,10) // truncate name
	local mod2lab = substr("`mod2lab'",1,10) // truncate name
}

*Error out if model combination is not allowed
if "`cmd1'" != "`cmd2'" {
	if 	"`cmd1'" == "logit" & "`cmd2'" == "probit" | ///
		"`cmd1'" == "probit" & "`cmd2'" == "logit" | ///
		"`cmd1'" == "logit" & "`cmd2'" == "regress" | ///
		"`cmd1'" == "regress" & "`cmd2'" == "logit" | ///
		"`cmd1'" == "probit" & "`cmd2'" == "regress" | ///
		"`cmd1'" == "regress" & "`cmd2'" == "probit" | ///
		"`cmd1'" == "poisson" & "`cmd2'" == "nbreg" | ///
		"`cmd1'" == "nbreg" & "`cmd2'" == "poisson" | ///
		"`cmd1'" == "mlogit" & "`cmd2'" == "ologit" | ///
		"`cmd1'" == "mlogit" & "`cmd2'" == "oprobit" | ///
		"`cmd1'" == "ologit" & "`cmd2'" == "oprobit" | ///		
		"`cmd1'" == "gologit2" & "`cmd2'" == "oprobit" | ///		
		"`cmd1'" == "gologit2" & "`cmd2'" == "ologit" | ///		
		"`cmd1'" == "gologit2" & "`cmd2'" == "mlogit" | ///		
		"`cmd1'" == "ologit" & "`cmd2'" == "mlogit" {
		local combo_ok = 1	
		}			
	else {
		local combo_ok = 0
		}
	if `combo_ok' == 0 {
		di as err "`mod1' is a {cmd:`cmd1'} and `mod2' is a {cmd:`cmd2'}. " /*
		*/ "{cmd:mecompare} can only be used for comparing certain model " /*
		*/ "combinations. See {help mecompare##model_combos}"
		exit	
		}
} 

*Error out if different # of categories across m/ologit models	
if "`cmd1'" == "ologit" | "`cmd1'" == "mlogit" | "`cmd1'" == "oprobit" | "`cmd1'" == "gologit2" {
	if `mod1cats' != `mod2cats' {
	di _newline(1)
	di as err "Number of outcome categories differs across models `mod1' " /*
	*/ "and `mod2'. {cmd:mecompare} can only be used with `cmd1' when the " /*
	*/  "number of outcome categories is the same across both models."
	exit
	}	
}	

*Warn if vce(robust) not used on stored models
if "`vcetype1'" != "robust" | "`vcetype2'" != "robust" {
	di in red "{cmd:mecompare} uses vce(robust) for all models. " /*
	*/ "Standard errors from {cmd:mecompare} will differ from the " /*
	*/ "specified model(s) because vce(robust) was not used on at " /*
	*/ "least one of the models specified in the {it:models( )} " /*
	*/ "option. We strongly recommend refitting the models with " /*
	*/ "vce(robust) to ensure the {cmd:mecompare} results match " /*
	*/ "those from the first ({cmd:`cmd1'}) and second ({cmd:`cmd2'}) " /*
	*/ "models exactly. See {help vce_option} for details on vce(robust)."
	}	
	
*Store IV varlist for use with margins
*	Parse constituent parts of interaction, polynomials	
local clean_list1a  = subinstr("`ivs1'","#"," ",.)
local list_ivs1     = subinstr("`clean_list1a'","c."," ",.)
local clean_list2a  = subinstr("`ivs2'","#"," ",.)
local list_ivs2     = subinstr("`clean_list2a'","c."," ",.)	

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

*Check to see if same DV across models; if yes, create copy 
if "`group'" == "" {
	if `dv1' == `dv2' {
		tempvar 		`dv2'COPY
		qui clonevar 	``dv2'COPY' = `dv2'
		local dv2  		``dv2'COPY'
		}
}
 
*if group() is specified, create DV that selects on group's obs.
if "`group'" != "" {
		capture drop 	`dv1'_grp`group1'
		qui clonevar 	`dv1'_grp`group1' = `dv1'
		qui replace 	`dv1'_grp`group1' = . if `group' != `group1'
		capture drop 	`dv2'_grp`group2'
		qui clonevar 	`dv2'_grp`group2' = `dv2'
		qui replace 	`dv2'_grp`group2' = . if `group' != `group2'
		local dv1		`dv1'_grp`group1'
		local dv2		`dv2'_grp`group2'
	}
	
di 	
*Include model specs. in output
di 		_newline(1)
if "`group'" != "" {
	local 	mod1specs "`cmd1' `dv1name' `ivs1' if `group' == `group1', vce(robust)"
	local 	mod2specs "`cmd2' `dv2name' `ivs2' if `group' == `group2', vce(robust)"
	}
else {
	local 	mod1specs "`cmd1' `dv1name' `ivs1', vce(robust)"
	local 	mod2specs "`cmd2' `dv2name' `ivs2', vce(robust)"
	}

	local 	mod1clean = itrim("`mod1specs'")
	local 	mod2clean = itrim("`mod2specs'")
	di 		in white "Model 1 (`mod1') is:"
	di 		in yellow "     `mod1clean'"
	di 		in white "Model 2 (`mod2') is:"
	di 		in yellow "     `mod2clean'"
	
*Listwise delete if not a groups model; have to do this b/c even though gsem
*	will equation-wise delete -- margins will not
if "`group'" == "" {
	local listwise "listwise"
	}
if "`group'" != "" {
	local listwise " "
	}
	
*Estimate the gsem/suest model
if "`commands'" != "" {		// show command line if requested
	di _newline(1)
	di in white "gsem model is: "
	di in yellow "    gsem (`dv1' <- `ivs1', `cmd1') (`dv2' <- `ivs2', `cmd2') " /*
	*/ " `weightspec', nocapslatent vce(robust) `listwise'"
	}
	
`cmdqui' 	gsem 	(`dv1' <- `ivs1', `cmd1') 	///
					(`dv2' <- `ivs2', `cmd2') 	///
					`weightspec'				///	
					, nocapslatent vce(robust) `listwise'

est 	store mec_gsem
tempvar mec_sample 
qui gen `mec_sample' = 1 if e(sample) 	// to get correct SDs below

matrix 	n_mods = e(_N)
local 	N1 = n_mods[1,1]
local 	N2 = n_mods[1,2]

*Warn if different sample size used across models
if "`group'" == "" {
	if `Nsav1' != `Nsav2' {
	di _newline(1)
	di in red "Sample size varies across the models: N_`mod1'=`Nsav1' ; " /*
	*/ "N_`mod2'=`Nsav2'. The results from {cmd:mecompare} will not match " /*
	*/ "those from the specified models as {cmd:mecompare} uses listwise " /*
	*/ "deletion across the models resulting in N_mecompare = `N1'"
	}
}
*Error out if group selection resulted in different sample than original models
if "`group'" != "" {
	if `Nsav1' != `N1' | `Nsav2' != `N2' {
	di _newline(1)
	di in red "Sample size varies across original models and the model fit " /*
	*/ "by {cmd:mecompare}. The groups selected by {cmd:mecompare} are " /*
	*/" {it:`group' == `group1'} and {it:`group' == `group2'} but the original models " /*
	*/ "use {it:`group1if'} and {it:`group2if'} to select observations. A single grouping " /*
	*/ "variable that selects observations is required for {cmd:mecompare}. " /*
	*/ "See {help mecompare##group} for details on specifying groups."
	exit
	}
}

}	// End of two model-specific options

****************************************************************************
// Set the margins specification and estimate predictions with margins 
****************************************************************************
*Set values of covariates if requested (NOTE: atmeans set below as it can 
*	be done with a single atmeans option on the margins command)
if "`covariates'" != "" {
	local covspec = subinword("`covariates'", "atmeans", " ", .)
	}
else {
	local covspec " "
	}

*Set amount specs for continuous IVs	
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
	exit
	}

local mrgspec " "	
local numvars : word count `list_ivs'

forvalues i = 1/`numvars' {

	local 	v : word `i' of `list_ivs'
	fvexpand `v'
	local 	numcats : word count `r(varlist)' 

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
	
	*need to remove = so that, e.g. age=50 and age = 50 are treated same
	local start 		= subinstr("`start'", "=", " ", .) 
	local hasiv 		= strpos("`start'", "`v'")
	local hasatmeans 	= strpos("`start'", "atmeans")
		
	if `hasiv' == 0  & `hasatmeans' == 0 {	// asoberved
	
		if "`amount`cnum''" == "one" {	
			if "`centered'" == "" {
				local startval 	"`v'=gen(`v')"	
				local endval 	"`v'=gen(`v' + 1)"				
				}
			if "`centered'" != "" {
				local startval 	"`v'=gen(`v' - .5)"	
				local endval 	"`v'=gen(`v' + .5)"				
				}
			}
		else if "`amount`cnum''" == "sd" {	
			qui sum `v' if `mec_sample' == 1			
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
	}
	
	if `hasiv' == 0 & `hasatmeans' != 0 {	// start change at mean
		qui sum `v' if `mec_sample' == 1
		local meanv = r(mean)
		local sd = r(sd)	
		local halfsd = `sd' / 2		
		
		if "`amount`cnum''" == "one" {	
			if "`centered'" == "" {
				local startval 	"`v'=`meanv'"	
				local endval 	"`v'=`meanv' + 1"				
				}
			if "`centered'" != "" {
				local startval 	"`v'=`meanv' - .5"	
				local endval 	"`v'=`meanv' + .5"				
				}
			}
		else if "`amount`cnum''" == "sd" {	
			if "`centered'" == "" {
				local endat 	= `meanv' + `sd'
				local startval 	"`v'=`meanv'"
				local endval 	"`v'=`endat'"				
				}
			if "`centered'" != "" {
				local startat 	= `meanv' - `halfsd'
				local endat 	= `meanv' + `halfsd'
				local startval 	"`v'=`startat'"
				local endval 	"`v'=`endat'"					
				}
			}
		else {	
			local halfamt = `amount`cnum'' / 2
			
			if "`centered'" == "" {
				local endamt 	= `meanv' + `amount`cnum''
				local startval 	"`v'=`meanv'"	
				local endval 	"`v'=`endamt'"				
				}
			if "`centered'" != "" {
				local startat 	= `meanv' - `halfamt'
				local endat 	= `meanv' + `halfamt'		
				local startval 	"`v'=`startat'"	
				local endval 	"`v'=`endat'"				
				}
			}
	}
		
	if `hasiv'!= 0 {	// start change at specified value
		local 	wherevar : list posof "`v'" in start
		di 		`wherevar'
		local 	whereval = `wherevar' + 1
		local 	startnum : word `whereval' of `start'
		qui sum `v' if `mec_sample' == 1
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
		}
	*Set labels for table
	if "`centered'" == "" {
		local centerlab ""
		}
	if "`centered'" != "" {
		local centerlab " (centered)"
		}
	if "`amount`cnum''" == "one" {
		local change`v' "`v' + 1`centerlab'"
		}
	else if "`amount`cnum''" == "sd" {
		local change`v' "`v' + SD`centerlab'"
		}
	else {
		local change`v' "`v' + `amount`cnum''`centerlab'"
		}	
	local 	mspec`i' at(`covspec' `startval') at(`covspec' `endval')
	local 	++cnum	
	}	

*For binary vars
*NOTE: Need to do this in at( ) statement so get separate predictions
*	if continuous vars also specified; i.e. can't use dydx( )
if `numcats' == 2 {
	local 	fv = strpos("`v'", ".") + 1 	// find where . is
	local 	varname = substr("`v'",`fv',.) 	// strip fv prefix
	qui 	levelsof `varname', local(levels)
	local 	lbe : value label `varname'
	local 	numlbe = strlen("`lbe'")	// store whether value labels exist
	local 	catsnom = "`r(levels)'"
	local 	mspec`i'  at(`covspec' `varname'=(`catsnom'))
	
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
	local change`varname' "`c2' - `c1'"
}

*Nominal vars (3+ categories)
if `numcats' >= 3 {
	qui 	fvexpand `v'
	local 	templist = subinstr("`r(varlist)'", "b", " b ", 1)
	local 	base : list posof "b" in templist
	local 	wherebase = `base' - 1
	local 	basenum : word `wherebase' of `templist' // store base #
	local 	fv = strpos("`v'", ".") + 1 	// find where . is
	local 	varname = substr("`v'",`fv',.) 	// strip fv prefix
	qui 	levelsof `varname', local(levels)
	local 	lbe : value label `varname'
	local 	numlbe = strlen("`lbe'")	// store whether value labels exist	
	local 	catsnom = "`r(levels)'"
	local 	catsnob = subinstr("`catsnom'", "`basenum'", "", 1) // remove base	
	local 	catspred = "`basenum' `catsnob'" // make base 1st prediction
	local 	mspec`i'  at(`covspec' `varname'=(`catspred')) 
	
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
		local change`varname'`h' "`c`h'' - `c1'"	
		}
	}
local mrgspec "`mrgspec' `mspec`i''" 	
}	

*Add atmeans for covariates if requested
local hasatmeans = strpos("`covariates'", "atmeans")
if "`covariates'" != "" & `hasatmeans' != 0 {
	local atmeans "atmeans"
	}
else {
	local atmeans " "
	}
	
*Add over(`group') option if group( )
if "`group'" != "" {
	local overspec "over(`group')"
	}
else {
	local overspec " "
	}
	
// Calculate the predictions with margins //
if "`commands'" != "" {		// show command line if requested
	di _newline(1)
	di in white "margins command is: "
	di in yellow "    margins, `mrgspec' `overspec' `atmeans' post"
	}

`cmdqui'	margins, `mrgspec' `overspec' `atmeans' post  
qui est 	store mec_margins	// For use with post-estimation melincom

****************************************************************************
// Define the cross-walk from the models/predictions and how margins 
*	labels the predictions in the table
****************************************************************************
*	With one equation, no equation info in coeflabel
*	With multi-equations, margins labels each equation as #._predict
*	In my notation below, #_# : 1st # = model ; 2nd # = outcome category.
*	With over( ), group is tacked onto the end as #.group

if "`group'" != "" {
	local g1spec = "#`group1'.`group'"
	local g2spec = "#`group2'.`group'"
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
	}	

if `mod1cats' != 1 {	// label DV categories for m/ologit
	forvalues modnum = 1/`nummods' {
		qui levelsof `dv`modnum'name', local(levels_dv)
		qui ds `dv`modnum'name', has(vallabel)
	local m = 1
	if "`r(varlist)'" !=  "" {	// if value labels exist
		local lbe : value label `dv`modnum'name'
		
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
****************************************************************************
local 		atnum1 = 1 // determines where in table each pred is
local 		atnum2 = 2
macro drop 	me__* 		// drop globals from previous mecompare commands
local 		me_num = 1 	// To label globals for melincom

qui mec_mlincom, clear
forvalues i = 1/`numvars' {
	local var : word `i' of `list_ivs'
	fvexpand `var'
	local numcats : word count `r(varlist)' 
	
	*Continuous IVs
	if `numcats' == 1 {
	
		forvalues o = 1/`mod1cats' {
	
	if `mod1cats' == 1 {	// set labels for m/ologit models
		local cat1name ""
		local cat2name ""		
		}
	else {
		local cat1name = "`out_1_`o'' - "	
		local cat2name = "`out_2_`o'' - "
			if "`cat1name'" == "`cat2name'" {
				local catDname = "`out_1_`o'' - "
				}
			else {
				local catDname = ""
				}
		}
	
	local varname = "`var'"
	local sectitle "`change`varname''"	
	
	if strpos("`list_ivs1'","`var'") | `nummods' == 1 {	// If var is in model 1
		global me__`me_num' (_b[`prnum1_`o''`atnum2'._at`g1spec'] - ///
							 _b[`prnum1_`o''`atnum1'._at`g1spec'])
		qui mec_mlincom ${me__`me_num'}, ///
			add rowname(`sectitle':`cat1name'`mod1lab') stat(`stats') 
		local ++me_num
		}
	else if `nummods' == 2 {
		_mec_addz, matrix(_mlincom) rowname("`sectitle':`cat1name'`mod1lab'")
		}
	
	if strpos("`list_ivs2'","`var'") & `nummods' == 2 {	// If var is in model 2
		global me__`me_num' (_b[`prnum2_`o''`atnum2'._at`g2spec'] - ///
							 _b[`prnum2_`o''`atnum1'._at`g2spec'])
		qui mec_mlincom ${me__`me_num'}, ///
				add rowname(`sectitle':`cat2name'`mod2lab') stat(`stats')
		local ++me_num
		}
	else if `nummods' == 2 {
		_mec_addz, matrix(_mlincom) rowname("`sectitle':`cat2name'`mod2lab'")
		}
		
	// Cross-model diff if var is in model 1 and model 2
	if strpos("`list_ivs1'","`var'") & strpos("`list_ivs2'","`var'") & `nummods' == 2 {
		global me__`me_num' (_b[`prnum1_`o''`atnum2'._at`g1spec'] - ///
							 _b[`prnum1_`o''`atnum1'._at`g1spec']) - ///
							(_b[`prnum2_`o''`atnum2'._at`g2spec'] - ///
							_b[`prnum2_`o''`atnum1'._at`g2spec'])
		qui mec_mlincom ${me__`me_num'}, ///
			add rowname(`sectitle':`catDname'Difference) stat(`stats') 
		local ++me_num	
		}
	else if `nummods' == 2 {
		_mec_addz, matrix(_mlincom) rowname("`sectitle':`catDname'Difference")
		}		
	}	
	local atnum1 = `atnum1' + 2		// advance _at label # in margins table
	local atnum2 = `atnum2' + 2
}
	
	*Binary IVs
	if `numcats' == 2 { 
			
			forvalues o = 1/`mod1cats' {
	
	if `mod1cats' == 1 {	// set labels for m/ologit models
		local cat1name ""
		local cat2name ""		
		}
	else {
		local cat1name = "`out_1_`o'' - "	
		local cat2name = "`out_2_`o'' - "
			if "`cat1name'" == "`cat2name'" {
				local catDname = "`out_1_`o'' - "
				}
			else {
				local catDname = ""
				}
		}
		
	local 	fv = strpos("`var'", ".") + 1 		// find where . is
	local 	varname = substr("`var'",`fv',.) 	// strip fv prefix
	local	sectitle "`change`varname''"	

	if `i' == 1 & `o' == 1 {
		*Create a quick faux table to get category label row
		qui mlincom 1, stat(`stats') 
		_mec_addz, matrix(_mlincom) rowname("`varname':{it}`sectitle'    ") top
		mat tempmat = _mlincom
		matselrc tempmat _mlincom, row(1)
		}
		
	if `i' != 1 & `o' == 1 {
		_mec_addz, matrix(_mlincom) rowname("`varname':{it}`sectitle'    ")
		}
		
	if strpos("`list_ivs1'","`var'") | `nummods' == 1 {	// If var is in model 1
		global me__`me_num' (_b[`prnum1_`o''`atnum2'._at`g1spec'] - ///
							 _b[`prnum1_`o''`atnum1'._at`g1spec'])
		qui mec_mlincom ${me__`me_num'}, ///
			add rowname(`varname':{sf}`cat1name'`mod1lab') stat(`stats') 
		local ++me_num
		}
	else if `nummods' == 2 { 
		_mec_addz, matrix(_mlincom) rowname("`varname':{sf}`out_1_`o''`mod1lab'")
		}
		
	if strpos("`list_ivs2'","`var'") & `nummods' == 2 {	// If var is in model 2
		global me__`me_num' (_b[`prnum2_`o''`atnum2'._at`g2spec'] - ///
							 _b[`prnum2_`o''`atnum1'._at`g2spec'])
		qui mec_mlincom ${me__`me_num'}, ///
			add rowname(`varname':{sf}`cat2name'`mod2lab') stat(`stats') 
		local ++me_num	
		}
	else if `nummods' == 2 {
		_mec_addz, matrix(_mlincom) rowname("`varname':{sf}`out_2_`o''`mod1lab'")
		}		
		
	// If var is in model 1 and model 2 calculate cross-model diff
	if strpos("`list_ivs1'","`var'") & strpos("`list_ivs2'","`var'") & `nummods' == 2 {
		global me__`me_num' (_b[`prnum1_`o''`atnum2'._at`g1spec'] - ///
							 _b[`prnum1_`o''`atnum1'._at`g1spec']) - ///
							(_b[`prnum2_`o''`atnum2'._at`g2spec'] - ///
							_b[`prnum2_`o''`atnum1'._at`g2spec'])
		qui mec_mlincom ${me__`me_num'}, ///
			add rowname(`varname':{sf}`catDname'Difference) stat(`stats') 
		local ++me_num	
		}
	else if `nummods' == 2 {
		_mec_addz, matrix(_mlincom) rowname("`varname':{sf}`catDname'Difference")
		}		
	}
	local atnum1 = `atnum1' + 2		// advance _at label # in margins table
	local atnum2 = `atnum2' + 2
}
	
	*Nominal IVs
	if `numcats' >= 3 {
	
	local 	fv = strpos("`var'", ".") + 1 		// find where . is
	local 	varname = substr("`var'",`fv',.) 	// strip fv prefix
	qui 	levelsof `varname', local(levels)
	local 	totcats : word count `levels'
	
	forvalues h = 2/`totcats' {		// Loop through all categories of IV
		forvalues o = 1/`mod1cats' { // Loop through all categories of DV
	
	if `mod1cats' == 1 {	// set labels for m/ologit models
		local cat1name ""
		local cat2name ""		
		}
	else {
		local cat1name = "`out_1_`o'' - "	
		local cat2name = "`out_2_`o'' - "
			if "`cat1name'" == "`cat2name'" {
				local catDname = "`out_1_`o'' - "
				}
			else {
				local catDname = ""
				}
		}
		
	local sectitle "`change`varname'`h''"	

		*If first in table, create quick faux table to get category label row	
		if `i' == 1 & `h' == 2 & `mod1cats' == 1 {
			qui mlincom 1, stat(`stats') 
			_mec_addz, matrix(_mlincom) ///
				rowname("`varname':{it}`sectitle'    ") top
			mat tempmat = _mlincom
			matselrc tempmat _mlincom, row(1)
		}
		else if `i' == 1 & `h' == 2 & `mod1cats' != 1 & `o' == 1 {
			qui mlincom 1, stat(`stats') 
			_mec_addz, matrix(_mlincom) ///
				rowname("`varname':{it}`sectitle'    ") top
			mat tempmat = _mlincom
			matselrc tempmat _mlincom, row(1)
		}
		else if `o' == 1 {
			_mec_addz, matrix(_mlincom) ///
				rowname("`varname':{it}`sectitle'    ")
		}	
		
	if strpos("`list_ivs1'","`var'") | `nummods' == 1 {	// If var is in model 1
		global me__`me_num' (_b[`prnum1_`o''`atnum2'._at`g1spec'] - ///
							 _b[`prnum1_`o''`atnum1'._at`g1spec'])
		qui mec_mlincom ${me__`me_num'}, ///
			add rowname(`varname':{sf}`cat1name'`mod1lab') stat(`stats') 
		local ++me_num
		}
	else if `nummods' == 2 { 
		_mec_addz, matrix(_mlincom) rowname("`varname':{sf}`out_1_`o''`mod1lab'")
		}
	
	if strpos("`list_ivs2'","`var'") & `nummods' == 2 {	// If var is in model 2
		global me__`me_num' (_b[`prnum2_`o''`atnum2'._at`g2spec'] - ///
							 _b[`prnum2_`o''`atnum1'._at`g2spec'])
		qui mec_mlincom ${me__`me_num'}, ///
			add rowname(`varname':{sf}`cat2name'`mod2lab') stat(`stats') 
		local ++me_num
		}
	else if `nummods' == 2 { 
		_mec_addz, matrix(_mlincom) rowname("`varname':{sf}`out_2_`o''`mod2lab'")
		}
		
	// If var is in model 1 and model 2 calculate cross-model diff
	if strpos("`list_ivs1'","`var'") & strpos("`list_ivs2'","`var'") & `nummods' == 2 {
		global me__`me_num' (_b[`prnum1_`o''`atnum2'._at`g1spec'] - ///
							 _b[`prnum1_`o''`atnum1'._at`g1spec']) - ///
							(_b[`prnum2_`o''`atnum2'._at`g2spec'] - ///
							_b[`prnum2_`o''`atnum1'._at`g2spec'])
		qui mec_mlincom ${me__`me_num'}, ///
			add rowname(`varname':{sf}`catDname'Difference) stat(`stats') 
		local ++me_num	
		}
	else if `nummods' == 2 { 
		_mec_addz, matrix(_mlincom) rowname("`varname':{sf}`catDname'Difference")
		}

	}
		if `h' != `totcats' {		// advance _at label # in margins table
			local atnum2 = `atnum2' + 1	// each time except last time through
		}
	}
		local atnum1 = `atnum1' + `numcats'	
		local atnum2 = `atnum2' + 2		// advance _at label #s in margins table
	}	
	
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
	matselrc _mecompare _mecompare, col("`colorder'") 

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

// Set row spec for final table based on # models, # outcomes, var type //
if `nummods' == 1 & `mod1cats' == 1 {	
	local rowspec "&-" 
	local cvspec "-"
	local bvspec "&-"
	local nvspec "&&"
	local nvendspec "&-"
	}

if `nummods' == 1 & `mod1cats' != 1 {
	local rowspec "&-" 
	local extra_amps ""
	forvalues c = 2/`mod1cats' {
		local extra_amps "`extra_amps'&"
		}
	local cvspec "`extra_amps'-"
	local bvspec "&`extra_amps'-"
	local nvspec "&&`extra_amps'"
	local nvendspec "&`extra_amps'-"
	}
	
if `nummods' == 2 {
	local rowspec "&-" 
	local cvspec "&&-"
	local bvspec "&&&-"
	local nvspec "&&&&"
	local nvendspec "&&&-"
	}

forvalues i = 1/`numvars' {
	local var : word `i' of `list_ivs'
	fvexpand `var'
	local numcats : word count `r(varlist)' 

	
	if `numcats' == 1 { 	// continuous IVs
	if `mod1cats' != 1 & `nummods' == 2 {
			forvalues c = 2/`mod1cats' {
				local rowspec "`rowspec'&&&"
				
					if `c' == `mod1cats' { 
						local rowspec "`rowspec'`cvspec'"				
					}
			}
		}	
	else { 	
		local rowspec "`rowspec'`cvspec'"
		}
	}
	
	if `numcats' == 2 {		// binary IVs
		if `mod1cats' != 1 & `nummods' == 2 {
			forvalues c = 2/`mod1cats' {
				local rowspec "`rowspec'&&&"
				
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
		qui 	levelsof `varname', local(levels)
		local 	totcats : word count `levels'
	
		if `mod1cats' != 1 & `nummods' == 2 {
			forvalues h = 2/`totcats' {		// Loop through all categories
			local rowspec "`rowspec'`nvspec'"
		
			forvalues c = 2/`mod1cats' {
				local rowspec "`rowspec'&&&"
				}
			if `h' == `totcats' {
				*Replace last & with - for line ending nominal var output
				local rowspec = substr("`rowspec'",1,length("`rowspec'")-1)
				local rowspec "`rowspec'-"
				}
			}		
		}
		
		else {
			forvalues h = 2/`totcats' {		// Loop through all categories
			local rowspec "`rowspec'`nvspec'"
		
			if `h' == `totcats' {
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

*Display table
matlist _mecompare, title("`N_title'") 	///
		cspec("`colspec'") rspec("`rowspec'") nodotz underscore	

if "`group'" != "" & "`amount'" == "sd" {
	di _newline(1)
	di in white "NOTE: SD's are based on all `N' observations across both groups."
	}				

if `nummods' == 1 {
	qui est restore `mod1'
	}

end		
	
	
* version 0.1.1 2018-11-02 | mize - long
/*
Adds blank rows (via .z) to table for clearer formatting of the table 
matinsert, matrix(_mlincom) rownumber(1) rowname(`"nominalvar:cat2_vs_cat1     "') value(.z)
* if rownumber(b) then put new row at bottom; if rownumber(t) put at top
*/
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
        exit
    }
    local nrows = rowsof(`matrix')
    local ncols = colsof(`matrix')
    local colnms : colfullnames `matrix', // quoted
    local rownms : rowfullnames `matrix', // quoted

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
        exit
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


// Below is Nick Cox's matselrc command //
// Putting here so that mecompare.ado can call it even if users do not 
// have matselrc installed 

* NJC 1.1.0 20 Apr 2000  (STB-56: dm79)
capture program drop matselrc
program def matselrc
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
	
	
	