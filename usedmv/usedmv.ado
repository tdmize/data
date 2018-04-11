* Author: Trenton Mize

* usedmv - command to download DMV Worksop datasets from web
* DMV: Data & Model Visualization Workshop
		
capture 	program drop usedmv
program 	define usedmv, rclass
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
		
