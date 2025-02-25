* Author: Trenton Mize

* balanceplot - calculates and plots standardized imbalance statistics

capture program drop balanceplot
*! balanceplot v1.0.2 Trenton Mize 2018-04-03
program define balanceplot, rclass
	version 13.0
	
	syntax varlist(fv) [if] [in], ///
		group(varlist max=1) [ref(integer 1) ref2(integer -999) ///
		ref3(integer -999) NOSort Base(integer 0) Graphop(string asis) ///
		NODropdv leg1(string) leg2(string) Plotcommand Table ///
		LEFTmargin(integer 0) DECimals(integer 3) WIDth(integer 10)]

	marksample touse
	_fv_check_depvar `depvar'
	local nvar : word count `varlist'
	
	*Error out if if/in qualifiers specify no obs
	qui count if `touse'
	if `r(N)' == 0 {
		error 2000
		}
	
	*Check base and ref values are valid for groupvar
	qui sum `group' if `group' == `base'
	local checknbase = `r(N)'
	if `checknbase' == 0 {
	di _newline 
	di as err "No observations in base group category `base'."
	di as err "Specify base category of group variable with option base( )"
	exit
	}
	else {
	}
	
	qui sum `group' if `group' == `ref'
	local checknref1 = `r(N)'
	if `checknref1' == 0 {
	di _newline 
	di as err "No observations in reference group category `ref'."
	di as err "Specify reference category of group variable with option ref( )"
	exit
	}
	else {
	}
	
	*If extra reference groups are requested, check are valid
	qui sum `group' if `group' == `ref2'
	local checknref2 = `r(N)'
	if `checknref2' == 0 & `ref2' != -999 {
	di _newline 
	di as err "No observations in 2nd reference group category `ref2'."
	di as err "Specify 2nd reference category of group variable with option ref2( )"
	exit
	}
	else {
	}
	
	qui sum `group' if `group' == `ref3'
	local checknref3 = `r(N)'
	if `checknref3' == 0 & `ref3' != -999 {
	di _newline 
	di as err "No observations in 3rd reference group category `ref3'."
	di as err "Specify 3rd reference category of group variable with option ref3( )"
	exit
	}
	else {
	}
	
	*Check if coefplot is installed
    capture which coefplot
    if (_rc) {
    di _newline(1)
	di as err "balanceplot requires the user-written command coefplot be installed." 
	di as err "Click on the link below to search for coefplot:"
	di as err "{stata search coefplot:  {bf:coefplot}}"
    }
	else {
	}

	*Store the value labels of groupvar to label plot
	local catbase : label (`group') `base'
	local catref  : label (`group') `ref'
	local catref2 : label (`group') `ref2'
	
	*Store total N to determine if any cases are listwise deleted
	qui sum `varlist' ibn.`group' if `touse'
	local startn = `r(N)'
	
	*Parse the legend options	
	if "`leg1'" == "" {
	local leg1_1ops = `" `catbase' vs "'
	local leg1_2ops = `" `catref' "'
	}
	else {
	local leg1_1ops = `" `leg1' "'
	local leg1_2ops = `" "'	
	}
	
	if "`leg2'" == "" {
	local leg2_1ops = `" `catbase' vs "'
	local leg2_2ops = `" `catref2' "'
	}
	else {
	local leg2_1ops = `" `leg2' "'
	local leg2_2ops = `" "'	
	}
	
	** Calculate and store descriptives when groupvar == base
	qui 	reg `varlist' if `group' == `base' & `touse', nocon
	*Save info on # of vars and DV name
	local 	numvars = `e(rank)' + 1
	local 	dv = e(depvar)
	local 	nbase = e(N)
	qui 	estat sum 
	mat 	statsbase = r(stats)

	*Store info about dependent variable
	if "`nodropdv'" == "" {
	local dropdv = e(depvar)
	}
	else {
	local dropdv = ""
	}
	
	*Nosort option
	if "`nosort'" == "" {
	local nosort = "sort"
	}
	else {
	local nosort = ""
	}

	** Calculate and store descriptives when groupvar == ref
	qui 	reg `varlist' if `group' == `ref' & `touse', nocon
	local 	nref1 = e(N)
	qui 	estat sum 
	mat 	statsref = r(stats)
	*Create matrix to store bias results to plot
	mat 	bias_`base'_`ref' = statsbase

	** If ref2( ): Calculate and store descriptives when groupvar == ref2
	if `ref2' != -999 {
	qui 	reg `varlist' if `group' == `ref2' & `touse', nocon
	local 	nref2 = e(N)
	qui 	estat sum 
	mat 	statsref2 = r(stats)
	*Create matrix to store bias results to plot
	mat 	bias_`base'_`ref2' = statsbase
	}
	
	*Calculate bias statistics for base vs ref (default)
	foreach row of numlist 1(1)`numvars' {
		mat bias_`base'_`ref'[`row',4] = ///
		100 * (statsref[`row',1] - statsbase[`row',1]) / ///
		sqrt((statsref[`row',2]^2 + statsbase[`row',2]^2)/2)
	}
	foreach row of numlist 1(1)`numvars' {
		mat bias_`base'_`ref'[`row',2] = ///
		statsref[`row',1]
	}

	*t-tests for imbalance 
	local rownms: rown bias_`base'_`ref'
	local rowname: word 1 of `rownms'
	local row = 1

	foreach r in `rownms' {
		qui reg `group' `r' if `touse' & `group' == `base' | `group' == `ref'
		mat est = r(table)
		mat bias_`base'_`ref'[`row',3] = est[4,1]
		
		local ++row
	}
	mat colnames bias_`base'_`ref' = mean_base mean_ref ttest_pval std_diff
	
	
	*Calculate bias statistics for base vs ref2 (if requested)
	if `ref2' != -999 {
	foreach row of numlist 1(1)`numvars' {
		mat bias_`base'_`ref2' [`row',4] = ///
		100 * (statsref2[`row',1] - statsbase[`row',1]) / ///
		sqrt((statsref2[`row',2]^2 + statsbase[`row',2]^2)/2)
	}
	foreach row of numlist 1(1)`numvars' {
		mat bias_`base'_`ref2'[`row',2] = ///
		statsref2[`row',1]
	}
	
	*t-tests for imbalance 
	local rownms2: rown bias_`base'_`ref2'
	local rowname2: word 1 of `rownms2'
	local row2 = 1

	foreach r2 in `rownms2' {
		qui reg `group' `r2' if `touse' & `group' == `base' | `group' == `ref2'
		mat est2 = r(table)
		mat bias_`base'_`ref2'[`row2',3] = est2[4,1]
		
		local ++row2
	}
	mat colnames bias_`base'_`ref2' = mean_base mean_ref ttest_pval std_diff
	}
	
	*This method uses listwise deletion on all model vars so show Ns
	if `ref2' != - 999 {
	local endn = `nbase' + `nref1' + `nref2'
	local diffn = `startn' - `endn'
	if `diffn' != 0 {
	di _newline(1)
	di in red "NOTE: `diffn' observations were excluded from calculation due to"
	di in red "missing data on at least one of the included variables"
	}
	di _newline(1)
	di in yellow "Base category = `base'_`catbase'" 
	di in yellow "Reference category = `ref'_`catref'"
	di in yellow "2nd Reference category = `ref2'_`catref2'"
	di _newline(1)
	di in yellow "N Used In Balance Calculations"
	di in white "- N for `group' = `base'_`catbase' : `nbase'"
	di in white "- N for `group' = `ref'_`catref' : `nref1'"
	di in white "- N for `group' = `ref2'_`catref2' : `nref2'"
	}
	
	else {
	local endn = `nbase' + `nref1'
	local diffn = `startn' - `endn'
	if `diffn' != 0 {
	di _newline(1)
	di in red "NOTE: `diffn' observations were excluded from calculations due to"
	di in red "missing data on at least one of the included variables"
	}
	di _newline(1)
	di in yellow "Base category = `base'_`catbase'" 
	di in yellow "Reference category = `ref'_`catref'"
	di _newline(1)
	di in yellow "N Used In Balance Calculations"
	di in white "- N for `group' = `base'_`catbase' : `nbase'"
	di in white "- N for `group' = `ref'_`catref' : `nref1'"
	}
	
	*Option plotcommand displays syntax to pass to coefplot
    if `ref2' != -999 {
	if "`plotcommand'" == "" {
	di ""
	}
	else{
	di _newline(1)
	di in yellow "NOTE: Matrices used for plot are named: bias_`base'_`ref' bias_`base'_`ref2'"
	di in yellow "- To recreate basic plot, click on the following command:"
	di "{stata coefplot (matrix(bias_`base'_`ref'[,4])) (matrix(bias_`base'_`ref2'[,4])):  {bf:coefplot (matrix(bias_`base'_`ref'[,4])) (matrix(bias_`base'_`ref2'[,4]))}}"
	} 
	}
	
	if `ref2' == -999 {
	if "`plotcommand'" == "" {
	di ""
	}
	else{
	di _newline(1)
	di in yellow "NOTE: Matrix used for plot is named: bias_`base'_`ref'"
	di in yellow "- To recreate basic plot, click on the following command:"
	di "{stata coefplot (matrix(bias_`base'_`ref'[,4])):  {bf:coefplot (matrix(bias_`base'_`ref'[,4]))}}"
	}
	}
	
	*Display table of means and bias if requested
	if `ref2' != -999 {
	if "`table'" == "" {
	di ""
	}
	else {
	di _newline(1)
	di in yellow "Results stored in matrices: bias_`base'_`ref' bias_`base'_`ref2'"
	di _newline(1)
	di in white 
	matlist bias_`base'_`ref', format(%`width'.`decimals'f) ///
		title("Difference in Means Across Groups of `group': base(`base'_`catbase') vs ref(`ref'_`catref')")
	di _newline(1)
	di in white 
	matlist bias_`base'_`ref2', format(%`width'.`decimals'f) ///
		title("Difference in Means Across Groups of `group': base(`base'_`catbase') vs ref2(`ref2'_`catref2')")
	}	
	}
	
	if `ref2' == -999 {
	if "`table'" == "" {
	di ""
	}
	else {
	di _newline(1)
	di in yellow "Results stored in matrix: bias_`base'_`ref'"
	di _newline(1)
	matlist bias_`base'_`ref', format(%`width'.`decimals'f) ///
		title("Difference in Means Across Groups of `group': base(`base'_`catbase') vs ref(`ref'_`catref')")
	}
	}
	
	*If ref2 exists - Plot overlaid balance plots of base vs (ref & ref2)
	if `ref2' != -999 {
	qui coefplot (matrix(bias_`base'_`ref'[,4])) (matrix(bias_`base'_`ref2'[,4])), ///
	`nosort' xline(0) drop(`dv') xtitle("% Standardized Difference") ///
	title("Imbalance in Covariates Across Groups of `group'") ///
	subtitle("`catbase' vs [`catref' & `catref2']", size(small)) ///
	legend(order(2 "`leg1_1ops'" "`leg1_2ops'" 4 "`leg2_1ops'" "`leg2_2ops'")) ///
	graphregion(margin(l+`leftmargin')) `graphop'
    }
	if `ref2' != -999 {
		return matrix bias1 = bias_`base'_`ref'
		return matrix bias2 = bias_`base'_`ref2'
		exit
		}
		
	*Default: Plot balance as a dot plot of base vs ref 
	qui coefplot (matrix(bias_`base'_`ref'[,4])), ///
	`nosort' xline(0) drop(`dropdv') xtitle("% Standardized Difference") ///
	title("Imbalance in Covariates Across Groups of `group'") ///
	subtitle("`catbase' vs `catref'", size(small)) ///
	graphregion(margin(l+`leftmargin')) `graphop' 

	return matrix bias1 = bias_`base'_`ref'
end
