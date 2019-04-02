capture program drop irt_me
*! irt_me v1.0.1 Trenton Mize 2019-03-27
program define irt_me, rclass
	version 14.1

	syntax [varlist(default=none)] [if] [in], ///
		[MODel(string) ///		* these are optional options
		LATent(string) DECimals(numlist >0 <9 integer) ///	
		title(string) start(string) end(string) range help]

if "`model'" != "" {	// restore model if irt/gsem not in memory
	qui est restore `model'	
	}
	
local 	N = e(N)	// Store sample size for table heading
tempvar me_sample 
qui gen `me_sample' = 1 if e(sample) 	// Store irt_me sample
		
*Check the model
if "`e(cmd2)'" == "irt" {
	local lvar "Theta"
	}
else if "`e(cmd)'" == "gsem" {
	local lvar = `" `latent' "'
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
		local lvar "Theta"
		}
	else {
		di as err "If {cmd:gsem} was used to fit the model `model', the " /*
		*/ "latent variable must be specified in the {opt latent( )} option."
		exit
		}
	}
	
else {
	if "`e(cmd2)'" == "irt" {
		local lvar "Theta"
		"Option {opt latent( )} ignored because model `model' " /*
		*/ " was fit using the {cmd:irt} command."
		}
	else {
		local lvar = `" `latent' "'
		}
	}
	
*For now, only allowing binary logit or probit	
local numitems : word count `items'
local suplinks "logit probit"
local supBfams "bernoulli binomial"
local nomfam   "multinomial"
local supCfams "poisson nbreg nbinomial"
local supClinks "log"
	
forvalues i = 1/`numitems' {
	local link`i' 		= "`e(link`i')'"
	local family`i' 	= "`e(family`i')'"
	local numcats`i'	= "`e(k_cat`i')'"
	local numouts`i'	= "`e(k_out`i')'"
	
	// check if a supported model
	if strpos("`suplinks'","`link`i''") & strpos("`supBfams'", "`family`i''") { 
		local exitprog 	= 0
		local model`i' 	= "binary"
		local rows`i' 	= 1
		}
	else if strpos("`suplinks'","`link`i''") & "`family`i''" == "ordinal" { 
		local exitprog 	= 0
		local model`i' 	= "ordinal"
		local rows`i' 	= `numcats`i''
		}		
	else if strpos("`suplinks'","`link`i''") & strpos("`family`i''","`nomfam'") { 
		local exitprog 	= 0
		local model`i' 	= "nominal"
		local rows`i' 	= `numouts`i''
		local base`i' 	= subinstr("`e(family`i')'","multinomial","",.)
		}		
	else if "`link`i''" == "log" & strpos("`family`i''", "poisson") {
		local exitprog 	= 0
		local model`i' 	= "count"
		local rows`i' 	= 1
		}	
	else if "`link`i''" == "log" & strpos("`family`i''", "nbinomial") {
		local exitprog 	= 0
		local model`i' 	= "count"
		local rows`i' 	= 1
		}	
	else {
		local exitprog = 1
		di as err "{cmd:irt_me} supports the following models: regress, logit, " /*
		*/ "probit, ologit, oprobit, poisson, and nbreg. Model `i' is a " /*
		*/ "{it:`link`i''} with family {it:`family`i''}"
		continue, break
		}
	}	
if `exitprog' == 1 {
	exit
	}
	
*Predict the latent variable if range option specified
if "`range'" != "" {
	if "`e(cmd2)'" == "irt" {
		tempvar 	latentpr 
		qui predict	`latentpr', latent	
		}
	else {
		tempvar 	latentpr 
		qui predict `latentpr', latent("`lvar'")	
		}
	}	
	
*Set the starting and ending values for predictions	
if "`range'" != "" {
	qui sum `latentpr', d
	local snum = "`r(p1)'"
	local enum = "`r(p99)'"
	}
else {
	if "`start'" == "" {
		local snum = "-0.5"
		}
	else {
		local snum = `" `start' "'
		}

	if "`end'" == "" {
		local enum = "0.5"
		}
	else {
		local enum = `" `end' "'
		}
	}

local num_rows = 0	
forvalues r = 1/`numitems' {
	local num_rows = `num_rows' + `rows`r''
	}
matrix  MEMs = J(`num_rows',5,-999)			// Create empty matrix
matrix 	colnames MEMs = PrStart PrEnd "ME Est." "Std. Err." P>|z|
local   i = 1
local 	mod = 1
foreach v in `items' {
	
if "`model`mod''" == "binary" {
	
	*Calculate 1st prediction
	qui nlcom 	exp(_b[`v':_cons] + _b[`v':`lvar']*`snum') ///
			/ (1 + exp(_b[`v':_cons] + _b[`v':`lvar']*`snum'))
	mat 	pred0 = r(b)
	local 	pr0 = pred0[1,1]
	mat 	MEMs[`i',1] = `pr0' 
	
	*Calculate 2nd prediction
	qui nlcom 	exp(_b[`v':_cons] + _b[`v':`lvar']*`enum') ///
			/ (1 + exp(_b[`v':_cons] + _b[`v':`lvar']*`enum'))
	mat 	pred1 = r(b)
	local	pr1 = pred1[1,1]
	mat 	MEMs[`i',2] = `pr1'
	
	*Calculate difference in predictions (MEM)
	qui nlcom 	[exp(_b[`v':_cons] + _b[`v':`lvar']*`enum') ///
				/ (1 + exp(_b[`v':_cons] + _b[`v':`lvar']*`enum'))] ///
				- ///
				[exp(_b[`v':_cons] + _b[`v':`lvar']*`snum') ///
				/ (1 + exp(_b[`v':_cons] + _b[`v':`lvar']*`snum'))] 
	
	mat 	predD = r(b)
	local 	mem = predD[1,1]
	mat 	MEMs[`i',3] = `mem'
	
	*Calculate SE and p-value for MEM
	mat 	varD = r(V)
	local 	varMEM = varD[1,1]
	local 	seMEM = sqrt(`varMEM')
	local 	zMEM = `mem' / `seMEM'
	local 	pMEM 2*(1 - normal(abs(`zMEM')))
	
	mat 	MEMs[`i',4] = `seMEM'
	mat 	MEMs[`i',5] = `pMEM'

	local 	row`i' = "`v'"	
	local 	++i
	local 	++mod
	}

else if "`model`mod''" == "ordinal" {
	fvexpand i.`v' 
	local numcats : word count `r(varlist)' 

	*Grab labels for each outcome category
	qui levelsof `v', local(levels)
	qui ds `v', has(vallabel)
	local labnum = 1
	if "`r(varlist)'" !=  "" {
		local lbe : value label `v'
	
		foreach lev of local levels {
			local outc`labnum' : label `lbe' `lev'	
			local outc`labnum' = substr("`outc`labnum''",1,12) // truncate name
			local ++ labnum	
		}
	}
	else {
		foreach lev of local levels {
			local outc`labnum' "Outcome `lev'"
			local ++ labnum	
		}	
	}
	
	*Pr(Category 1) : PrStart
	qui nlcom 	1 - [exp(_b[`v':`lvar']*`snum' - _b[/`v':cut1]) 	/ 	///
				(1 + exp(_b[`v':`lvar']*`snum' - _b[/`v':cut1]))]	
	mat 	pred0 = r(b)
	local 	pr0 = pred0[1,1]
	mat 	MEMs[`i',1] = `pr0' 
	
	*Pr(Category 1) : PrEnd
	qui nlcom 	1 - [exp(_b[`v':`lvar']*`enum' - _b[/`v':cut1]) 	/ 	///
				(1 + exp(_b[`v':`lvar']*`enum' - _b[/`v':cut1]))]	
	mat 	pred1 = r(b)
	local	pr1 = pred1[1,1]
	mat 	MEMs[`i',2] = `pr1'
	
	*ME(Category 1)
	qui nlcom 	[1 - [exp(_b[`v':`lvar']*`enum' - _b[/`v':cut1]) 	/ 	///
				(1 + exp(_b[`v':`lvar']*`enum' - _b[/`v':cut1]))]]	- ///	
				[1 - [exp(_b[`v':`lvar']*`snum' - _b[/`v':cut1]) 	/ 	///
				(1 + exp(_b[`v':`lvar']*`snum' - _b[/`v':cut1]))]]	
	mat 	predD = r(b)
	local 	mem = predD[1,1]
	mat 	MEMs[`i',3] = `mem'

	*Calculate SE and p-value for MEM
	mat 	varD = r(V)
	local 	varMEM = varD[1,1]
	local 	seMEM = sqrt(`varMEM')
	local 	zMEM = `mem' / `seMEM'
	local 	pMEM 2*(1 - normal(abs(`zMEM')))
	
	mat 	MEMs[`i',4] = `seMEM'
	mat 	MEMs[`i',5] = `pMEM'
	
	local 	row`i' = `""`v':`outc1'""'
	local 	++i
	
	local penultimate = `numcats' - 1
	forvalues p = 2/`penultimate' {
		local q = `p' - 1
	
	*Pr(For Categories 2 through M-1) : PrStart
	qui nlcom 	[exp(_b[`v':`lvar']*`snum' - _b[/`v':cut`q']) / 	///
				(1 + exp(_b[`v':`lvar']*`snum' - _b[/`v':cut`q']))] - 	///
				[exp(_b[`v':`lvar']*`snum' - _b[/`v':cut`p']) / 	///
				(1 + exp(_b[`v':`lvar']*`snum' - _b[/`v':cut`p']))]	
	mat 	pred0 = r(b)
	local 	pr0 = pred0[1,1]
	mat 	MEMs[`i',1] = `pr0' 
	
	*Pr(For Categories 2 through M-1) : PrEnd
	qui nlcom 	[exp(_b[`v':`lvar']*`enum' - _b[/`v':cut`q']) / 	///
				(1 + exp(_b[`v':`lvar']*`enum' - _b[/`v':cut`q']))] - 	///
				[exp(_b[`v':`lvar']*`enum' - _b[/`v':cut`p']) / 	///
				(1 + exp(_b[`v':`lvar']*`enum' - _b[/`v':cut`p']))]	
	mat 	pred1 = r(b)
	local	pr1 = pred1[1,1]
	mat 	MEMs[`i',2] = `pr1'
	
	*ME(For Categories 2 through M-1)
	qui nlcom 	[[exp(_b[`v':`lvar']*`enum' - _b[/`v':cut`q']) / 	///
				(1 + exp(_b[`v':`lvar']*`enum' - _b[/`v':cut`q']))] - 	///
				[exp(_b[`v':`lvar']*`enum' - _b[/`v':cut`p']) / 	///
				(1 + exp(_b[`v':`lvar']*`enum' - _b[/`v':cut`p']))]] - 	///
				[[exp(_b[`v':`lvar']*`snum' - _b[/`v':cut`q']) / 	///
				(1 + exp(_b[`v':`lvar']*`snum' - _b[/`v':cut`q']))] - 	///
				[exp(_b[`v':`lvar']*`snum' - _b[/`v':cut`p']) / 	///
				(1 + exp(_b[`v':`lvar']*`snum' - _b[/`v':cut`p']))]]				
	mat 	predD = r(b)
	local 	mem = predD[1,1]
	mat 	MEMs[`i',3] = `mem'

	*Calculate SE and p-value for MEM
	mat 	varD = r(V)
	local 	varMEM = varD[1,1]
	local 	seMEM = sqrt(`varMEM')
	local 	zMEM = `mem' / `seMEM'
	local 	pMEM 2*(1 - normal(abs(`zMEM')))
	
	mat 	MEMs[`i',4] = `seMEM'
	mat 	MEMs[`i',5] = `pMEM'

	local 	row`i' = `""`v':`outc`p''""'	
	local 	++i	
	}
	
	local m = `numcats' - 1
	*Pr(Category M) : PrStart
	qui nlcom 	[exp(_b[`v':`lvar']*`snum' - _b[/`v':cut`m']) / 	///
				(1 + exp(_b[`v':`lvar']*`snum' - _b[/`v':cut`m']))]  
	mat 	pred0 = r(b)
	local 	pr0 = pred0[1,1]
	mat 	MEMs[`i',1] = `pr0' 
	
	*Pr(Category M) : PrEnd
	qui nlcom 	[exp(_b[`v':`lvar']*`enum' - _b[/`v':cut`m']) / 	///
				(1 + exp(_b[`v':`lvar']*`enum' - _b[/`v':cut`m']))]  
	mat 	pred1 = r(b)
	local	pr1 = pred1[1,1]
	mat 	MEMs[`i',2] = `pr1'
	
	*ME(Category M)
	qui nlcom 	[[exp(_b[`v':`lvar']*`enum' - _b[/`v':cut`m']) / 	///
				(1 + exp(_b[`v':`lvar']*`enum' - _b[/`v':cut`m']))]] - 	///
				[[exp(_b[`v':`lvar']*`snum' - _b[/`v':cut`m']) / 	///
				(1 + exp(_b[`v':`lvar']*`snum' - _b[/`v':cut`m']))]]  
	mat 	predD = r(b)
	local 	mem = predD[1,1]
	mat 	MEMs[`i',3] = `mem'

	*Calculate SE and p-value for MEM
	mat 	varD = r(V)
	local 	varMEM = varD[1,1]
	local 	seMEM = sqrt(`varMEM')
	local 	zMEM = `mem' / `seMEM'
	local 	pMEM 2*(1 - normal(abs(`zMEM')))
	
	mat 	MEMs[`i',4] = `seMEM'
	mat 	MEMs[`i',5] = `pMEM'

	local 	++m
	local 	row`i' = `""`v':`outc`m''""'	
	local 	++i
	local 	++mod
	}
	
else if "`model`mod''" == "nominal" {
	fvexpand i.`v' 
	local numcats : word count `r(varlist)' 

	*Grab labels for each outcome category
	qui levelsof `v', local(levels)
	qui ds `v', has(vallabel)
	local labnum = 1
	if "`r(varlist)'" !=  "" {
		local lbe : value label `v'
	
		foreach lev of local levels {
			local outc`labnum' : label `lbe' `lev'	
			local outc`labnum' = substr("`outc`labnum''",1,12) // truncate name
			local ++ labnum	
		}
	}
	else {
		foreach lev of local levels {
			local outc`labnum' "Outcome `lev'"
			local ++ labnum	
		}	
	}
	local catsnobase : list levels - base`mod'	// remove base category
	local Snumerator0 "1"						// for base categeory
	local Enumerator0 "1"
	local numother : word count `catsnobase'
	forvalues cat = 1/`numother' {
		local num : word `cat' of `catsnobase'
		local Snumerator`cat' "exp(_b[`num'.`v':_cons] + _b[`num'.`v':`lvar']*`snum')"
		local Enumerator`cat' "exp(_b[`num'.`v':_cons] + _b[`num'.`v':`lvar']*`enum')"
		}
	local Sdenominator ""
	local Edenominator ""
	forvalues cat = 1/`numother' {
		local num : word `cat' of `catsnobase'
		local Sdenominator ///
			"`Sdenominator' exp(_b[`num'.`v':_cons] + _b[`num'.`v':`lvar']*`snum') + "
		local Edenominator ///
			"`Edenominator' exp(_b[`num'.`v':_cons] + _b[`num'.`v':`lvar']*`enum') + "
		}	
	// remove final + sign
	local 	Sdenominator = substr("`Sdenominator'",1,length("`Sdenominator'")-2)
	local 	Edenominator = substr("`Edenominator'",1,length("`Edenominator'")-2)
	
	local labnum = 1
	forvalues cat = 0/`numother' {
		*Pr(Outcome Category cat) : PrStart
		qui nlcom 	[`Snumerator`cat''] / [1 + `Sdenominator']
		mat 	pred1 = r(b)
		local	pr1 = pred1[1,1]
		mat 	MEMs[`i',1] = `pr1'
		
		*Pr(Outcome Category cat) : PrEnd
		qui nlcom 	[`Enumerator`cat''] / [1 + `Edenominator']
		mat 	pred1 = r(b)
		local	pr1 = pred1[1,1]
		mat 	MEMs[`i',2] = `pr1'
	
		*ME(Outcome Category cat)
		qui nlcom 	([`Enumerator`cat''] / [1 + `Edenominator']) - ///
					([`Snumerator`cat''] / [1 + `Sdenominator'])
		mat 	predD = r(b)
		local 	mem = predD[1,1]
		mat 	MEMs[`i',3] = `mem'
	
		*Calculate SE and p-value for MEM
		mat 	varD = r(V)
		local 	varMEM = varD[1,1]
		local 	seMEM = sqrt(`varMEM')
		local 	zMEM = `mem' / `seMEM'
		local 	pMEM 2*(1 - normal(abs(`zMEM')))
	
		mat 	MEMs[`i',4] = `seMEM'
		mat 	MEMs[`i',5] = `pMEM'
	
		local 	row`i' = `""`v':`outc`labnum''""'
		local 	++labnum
		local 	++i
		}
	local 	++mod
	}	
	
if "`model`mod''" == "count" {
	
	*Calculate 1st prediction
	qui nlcom 	exp(_b[`v':_cons] + _b[`v':`lvar']*`snum') 
	mat 	pred0 = r(b)
	local 	pr0 = pred0[1,1]
	mat 	MEMs[`i',1] = `pr0' 
	
	*Calculate 2nd prediction
	qui nlcom 	exp(_b[`v':_cons] + _b[`v':`lvar']*`enum') 
	mat 	pred1 = r(b)
	local	pr1 = pred1[1,1]
	mat 	MEMs[`i',2] = `pr1'
	
	*Calculate difference in predictions (MEM)
	qui nlcom 	[exp(_b[`v':_cons] + _b[`v':`lvar']*`enum')] - 	///
				[exp(_b[`v':_cons] + _b[`v':`lvar']*`snum')] 
	
	mat 	predD = r(b)
	local 	mem = predD[1,1]
	mat 	MEMs[`i',3] = `mem'
	
	*Calculate SE and p-value for MEM
	mat 	varD = r(V)
	local 	varMEM = varD[1,1]
	local 	seMEM = sqrt(`varMEM')
	local 	zMEM = `mem' / `seMEM'
	local 	pMEM 2*(1 - normal(abs(`zMEM')))
	
	mat 	MEMs[`i',4] = `seMEM'
	mat 	MEMs[`i',5] = `pMEM'

	local 	row`i' = "`v'"	
	local 	++i
	local 	++mod
	}
	
}	// End of ME loop

	
local 	numrows = `i'
local 	rownames ""
forvalues x = 1/`numrows' {
	local rownames "`rownames' `row`x''"
	}

matrix 	rownames MEMs = `rownames'		// Label rows with var names
local 	sizeME 	= `enum' - `snum'	
local 	sizeME 	: di %5.3f `sizeME'
local 	snum 	: di %5.3f `snum'
local 	enum 	: di %5.3f `enum'

if "`title'" == "" {	
	local title "Marginal Effects of + `sizeME' Increase in Latent Variable (theta) N=`N'"	
	}
else {
	local title "`title'"
	}
	
matlist MEMs, format(%10.`dec'f) title("`title'") 	

if "`help'" != "" {
	di _newline
	di "PrStart : Pr(y=1) at theta = `snum'"
	di "PrEnd   : Pr(y=1) at theta = `enum'"
	di "ME 	    : PrEnd - PrStart"	
	}
else {
	}

end	
