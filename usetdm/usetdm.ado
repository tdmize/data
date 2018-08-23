* Author: Trenton Mize

* usetdm - command to download class & workshop datasets from web
* DMV: Data & Model Visualization Workshop
* CDA: Categorical Data Analysis
		
capture 	program drop usetdm
program 	define usetdm, rclass
	version 12.0
	
	syntax namelist, [clear]

	qui count
	local N = `r(N)'	
	
	if "`clear'" == "" & `N' != 0 {
	di as err "Data in memory will be lost. Specify option clear to load anyway."
	exit	
	}
	
	else {
	di "Loading dataset..." 
	use "https://tdmize.github.io/data/data/`namelist'.dta", `clear'
	}
end
		
