capture program drop irt_coef
*! irt_coef v1.0.1 Trenton Mize 2019-03-22
program define irt_coef, rclass
	version 14.1

	syntax [varlist(default=none)] [if] [in], ///
		[MODel(string) ///		* these are optional options
		LATent(string) DECimals(numlist >0 <9 integer) ///	
		title(string) help]
	
*Check the model
if "`model'" != "" {	// restore model if irt/gsem not in memory
	qui est restore `model'	
	matrix 	ests = r(table)	// Save table of estimates	
	}

local 	N = e(N)			// Store sample size for table heading

if "`e(cmd2)'" == "irt" {
	local 	lvar "Theta"
	qui 	irt
	matrix 	ests = r(table)	// Save table of estimates	
	}
else if "`e(cmd)'" == "gsem" {
	local 	lvar = `" `latent' "'
	qui 	gsem
	matrix 	ests = r(table)	// Save table of estimates	
	}
else {
	di as err "Model estimates in memory are not {cmd:irt} or {cmd:gsem}. " /*
	*/ "Either re-estimate the {cmd:irt} or {cmd:gsem} model of interest " /*
	*/ "or specify the saved {cmd:irt} or {cmd:gsem} model estimates in " /*
	*/ "the {opt models( )} option."
	}
					
*Set the options
if "`decimals'" == "" {
	local dec = "3"
	}
else {
	local dec = `"`decimals'"'
	}
if "`title'" == "" {	
	local title "y* standardized coefficients (and raw coefficient) from IRT model N=`N'"	
	}
else {
	local title "`title'"
	}	
	
*If no varlist, calculate for all items (DVs)
if "`varlist'" == "" {
	local items = "`e(depvar)'"
	}
else {
	local items "`varlist'"
	}
	
*Latent variable name
if "`latent'" == "" {
	if "`e(cmd2)'" == "irt" {
		local lvar "Discrim"
		}
	else {
		di as err "If {cmd:gsem} was used to fit the model `model', the name " /*
		*/ "of the latent variable must be specified in the {opt latent( )} option."
		exit
		}
	}
	
else {
	if "`e(cmd2)'" == "irt" {
		local lvar "Discrim"
		di in red "Option {opt latent( )} ignored because model `model' was " /*
		*/ "fit using the {cmd:irt} command."
		}
	else {
		local lvar = `"`latent'"'
		}
	}
	
*For now, only allowing binary/ordinal logit/probit	
local numitems : word count `items'
local suplinks "logit probit"
local supfams "bernoulli binomial ordinal"
forvalues i = 1/`numitems' {
	local link`i' = "`e(link`i')'"
	local family`i' = "`e(family`i')'"
	// check if a supported model
	if strpos("`suplinks'","`link`i''") & strpos("`supfams'", "`family`i''") { 
		local exitprog = 0
		}
	else {
		local exitprog = 1
		di as err "{cmd:irt_me} currently only supports binary and ordinal " /*
		*/ "logit/probit models for IRT. Model `i' is a {it:`link`i''} " /*
		*/ "with family {it:`family`i''}"
		continue, break
		}
	}	
if `exitprog' == 1 {
	exit
	}

local 	num_rows : word count `items'					
matrix 	irttab = J(`num_rows',4,-999)	// Create empty matrix
matrix 	rownames irttab = `items'		// Label rows with var names
matrix 	colnames irttab = "Std Coef" Coef "Std. Err." P>|z|
local   i = 1							// Matrix row start point

foreach v in `items' {
	if "`link`i''" == "logit" {
		local vare = (_pi*_pi / 3)
		}
	if "`link`i''" == "probit" {
		local vare = 1
		}
	
	matrix 	irttab[`i', 2] 	= ests["b","`v':`lvar'"]
	local 	coef`i' 		= irttab[`i', 2]
	local 	varystar 		= `coef`i'' * `coef`i'' + `vare' 
	local 	stdcoef`i' 		= `coef`i'' / sqrt(`varystar')
	matrix 	irttab[`i', 1]	= `stdcoef`i''
	matrix 	irttab[`i', 3]  = ests["se","`v':`lvar'"]
	matrix 	irttab[`i', 4]  = ests["pvalue","`v':`lvar'"]

	local ++i
	}

matlist irttab, format(%10.`dec'f) title("`title'") 		

if "`help'" != "" {
	di _newline
	di "Std Coef : y* standardized IRT regression coefficient"
	di "Coef     : IRT raw regression coefficient"
	di "NOTE     : SE and p-value based on raw regression coefficient"
	}
else {
	}
	
end	
