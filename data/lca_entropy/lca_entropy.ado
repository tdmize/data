capture program drop lca_entropy
*! lca_entropy v1.0.2 Trenton Mize 2025-03-31

*v1.0.2 adds a r return for the stat

program define lca_entropy, rclass
	version 14.1

	syntax , ///
		[MODel(string) ///		* these are optional options
		DECimals(numlist >0 <9 integer)]

if "`model'" != "" {	// restore model if irt/gsem not in memory
	qui est restore `model'	
	}
	
local 	classnm = "`e(lclass)'"
local 	cmdnm 	= "`e(cmd)'" 
if "`classnm'" == "" | "`cmdnm'" != "gsem" {	// check if LCA model
	di as err "Model is not a latent class model estimated with {cmd:gsem}. " /*
	*/ "lca_entropy only works after {cmd:gsem} when the option " /*
	*/ "{opt:lclass( )} was used."
	exit
	}
	
*Set the options
if "`decimals'" == "" {
	local dec = "3"
	}
else {
	local dec = `"`decimals'"'
	}	

/*
tempvar 	lca_sample 
qui gen 	`lca_sample' = 1 if e(sample) 	// Store lca sample
*/

local 		N = e(N)						// Store lca sample size 
matrix 		classmat = e(lclass_k_levels)	// save matrix with class #
local 		numclass 	= classmat[1,1]

predict 	__prpprob* if e(sample), classposteriorpr
forvalues c = 1/`numclass' {
	gen __sumpprob`c' = -__prpprob`c' * ln(__prpprob`c')
	}
egen 		__sumpostprALL = rowtotal(__sumpprob*) 
qui sum 	__sumpostprALL, meanonly	
scalar 		LCA_Entropy = 1 - (`r(sum)') / (`N'*ln(`numclass'))

drop 		__prpprob* __sumpprob* __sumpostprALL

di 		"Entropy = " %6.`dec'f LCA_Entropy

return scalar entropy = LCA_Entropy


end
