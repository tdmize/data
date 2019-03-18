*! irt_me v1.0.1 Trenton Mize 2019-03-18
program define irt_me, rclass
	version 14.1

	syntax [varlist(default=none)] [if] [in], ///
		[MODel(string) ///		* these are optional options
		LATent(string) DECimals(numlist >0 <9 integer) ///	
		title(string) start(string) end(string) range help]

*Check the model
if "`model'" == "" {
	if "`e(cmd2)'" == "irt" {
		local lvar "Theta"
		}
	else if "`e(cmd)'" == "gsem" {
		local lvar = `" `latent' "'
		}
	else {
		di as err "Model estimates in memory are not {cmd:irt} or {cmd:gsem}."
		di as err "Either re-estimate the {cmd:irt} or {cmd:gsem} model of interest or"
		di as err "specify the saved model estimates in the {opt models( )} option."
		}
	}		
		
*Set the options
if "`decimals'" == "" {
	local dec = "3"
	}
else {
	local dec = `"`decimals'"'
	}
	
if "`model'" != "" {	// restore model if irt/gsem not in memory
	qui est restore `model'	
	}
	
local N = e(N)	// Store sample size for table heading

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
		di as err "If {cmd:gsem} was used to fit the model `model', the name of the"
		di as err "latent variable must be specified in the {opt latent( )} option."
		exit
		}
	}
	
else {
	if "`e(cmd2)'" == "irt" {
		local lvar "Theta"
		di in red "Option {opt latent( )} ignored because model `model' was fit using "
		di in red "the {cmd:irt} command."
		}
	else {
		local lvar = `" `latent' "'
		}
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
	
local 	num_rows : word count `items'	
matrix  MEMs = J(`num_rows',5,-999)		// Create empty matrix
matrix 	rownames MEMs = `items'		// Label rows with var names
matrix 	colnames MEMs = PrStart PrEnd "ME Est." "Std. Err." P>|z|
local   mat_row = 1

foreach v in `items' {
	
	*Calculate 1st prediction
	qui nlcom 	exp(_b[`v':_cons] + _b[`v':`lvar']*`snum') ///
			/ (1 + exp(_b[`v':_cons] + _b[`v':`lvar']*`snum'))
	mat 	pred0 = r(b)
	local 	pr0 = pred0[1,1]
	mat 	MEMs[`mat_row',1] = `pr0' 
	
	*Calculate 2nd prediction
	qui nlcom 	exp(_b[`v':_cons] + _b[`v':`lvar']*`enum') ///
			/ (1 + exp(_b[`v':_cons] + _b[`v':`lvar']*`enum'))
	mat 	pred1 = r(b)
	local	pr1 = pred1[1,1]
	mat 	MEMs[`mat_row',2] = `pr1'
	
	*Calculate difference in predictions (MEM)
	qui nlcom 	[exp(_b[`v':_cons] + _b[`v':`lvar']*`enum') ///
				/ (1 + exp(_b[`v':_cons] + _b[`v':`lvar']*`enum'))] ///
				- ///
				[exp(_b[`v':_cons] + _b[`v':`lvar']*`snum') ///
				/ (1 + exp(_b[`v':_cons] + _b[`v':`lvar']*`snum'))] 
	
	mat 	predD = r(b)
	local 	mem = predD[1,1]
	mat 	MEMs[`mat_row',3] = `mem'
	
	*Calculate SE and p-value for MEM
	mat 	varD = r(V)
	local 	varMEM = varD[1,1]
	local 	seMEM = sqrt(`varMEM')
	local 	zMEM = `mem' / `seMEM'
	local 	pMEM 2*(1 - normal(abs(`zMEM')))
	
	mat 	MEMs[`mat_row',4] = `seMEM'
	mat 	MEMs[`mat_row',5] = `pMEM'
	
	local 	++mat_row
	}

local 	sizeME 	= `enum' - `snum'	
local 	sizeME 	: di %5.3f `sizeME'
local 	snum 	: di %5.3f `snum'
local 	enum 	: di %5.3f `enum'

matlist MEMs, format(%10.`dec'f) ///
	title("Marginal Effects of + `sizeME' Increase in Latent Variable (theta) N=`N'") 	

if "`help'" != "" {
	di _newline
	di "PrStart : Pr(y=1) at theta = `snum'"
	di "PrEnd   : Pr(y=1) at theta = `enum'"
	di "ME 	    : PrEnd - PrStart"	
	}
else {
	}

end	
