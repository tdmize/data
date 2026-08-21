* Author: Trenton Mize

* Internal eclass helper used by store().
capture program drop _balanceplot_eststore
program define _balanceplot_eststore, eclass
	version 13.0
	syntax anything(name=bmat), ESTNAME(name) RESULT(string) N(real) ///
		[VMAT(name) DFR(real -1) GROUPVAR(name) GROUPVALUE(string) BASEVALUE(string) ///
		CONTREAT(name) STATUS(string)]

	capture confirm matrix `bmat'
	if _rc {
		di as err "Internal store() error: coefficient matrix `bmat' was not found."
		exit 498
	}
	if "`vmat'" != "" {
		capture confirm matrix `vmat'
		if _rc {
			di as err "Internal store() error: variance matrix `vmat' was not found."
			exit 498
		}
		ereturn post `bmat' `vmat'
	}
	else ereturn post `bmat'

	ereturn scalar N = `n'
	if `dfr' >= 0 ereturn scalar df_r = `dfr'
	ereturn local cmd "balanceplot"
	ereturn local balanceplot_result "`result'"
	ereturn local groupvar "`groupvar'"
	ereturn local contreat "`contreat'"
	ereturn local balanceplot_status "`status'"
	if "`groupvalue'" != "" ereturn scalar group_value = real("`groupvalue'")
	if "`basevalue'" != "" ereturn scalar base = real("`basevalue'")
	ereturn local estimates_title "`estname'"
	estimates store `estname'
end

* balanceplot - calculates and plots standardized imbalance statistics
// v4.0.1 - fixes compact table display in continuous-treatment mode
// v4.0.0 - adds continuous treatment correlation support and direct 
// support for teffects and psmatch2

capture program drop balanceplot
*! balanceplot v4.0.1 Trenton Mize 2026-08-21
program define balanceplot, rclass
	version 13.0

	* Accept the requested mixed-case alias cohensH without altering the varlist.
	* Only option tokens after the command comma are normalized.
	local raw0 `"`0'"'
	local comma = strpos(`"`raw0'"', ",")
	local balance_lhs `"`raw0'"'
	if `comma' local balance_lhs = substr(`"`raw0'"', 1, `comma' - 1)
	if `comma' {
		local lhs = substr(`"`raw0'"', 1, `comma')
		local opts = substr(`"`raw0'"', `comma' + 1, .)
		local normopts
		while `"`opts'"' != "" {
			gettoken opt opts : opts, bind
			if `"`opt'"' == "cohensH" local opt "cohensh"
			local normopts `"`normopts' `opt'"'
		}
		local 0 `"`lhs' `normopts'"'
	}

	syntax [varlist(fv)] [if] [in], [TEBALANCE GROUP(varname) ///
		CONTREAT(varname) OUTcome(varname) BASE(string) ///
		REF(string) REF2(string) REF3(string) SORT Graphop(string asis) ///
		leg1(string) leg2(string) Plotcommand Table TABLEFULL NOCI Level(cilevel) ///
		FADENS FADE COHENSH MATCHWEIGHT(varname) THRESHold(real -1) ABSolute ///
		STORE(string asis) ///
		LEFTmargin(integer 0) DECimals(integer 3) WIDth(integer 10) LABWidth(integer 24)]
	local conflevel = `level'
	local dotebalance = ("`tebalance'" != "")
	local docontreat = ("`contreat'" != "")
	local dothreshold = (`threshold' >= 0)
	local doabsolute = ("`absolute'" != "")

	* Parse store(stubname [, replace]) as an option with its own suboption.
	* A second syntax call clears the original varlist local, so preserve and restore it.
	local balancevars `"`varlist'"'
	local storestub ""
	local storereplace ""
	if `"`store'"' != "" {
		local 0 `"`store'"'
		capture syntax name(name=storestub) [, REPLACE]
		if _rc {
			di as err "store() must specify a valid stubname, optionally followed by , replace."
			exit 198
		}
		local store "`storestub'"
		local storereplace "`replace'"
	}
	local varlist `"`balancevars'"'
	local dostore = ("`store'" != "")
	if `threshold' == 0 {
		di as err "threshold() must be greater than 0."
		exit 198
	}
	if `threshold' < 0 & `threshold' != -1 {
		di as err "threshold() must be greater than 0."
		exit 198
	}
	if `dotebalance' {
		if "`group'" != "" | "`contreat'" != "" {
			di as err "tebalance may not be combined with group() or contreat()."
			exit 198
		}
	}
	else {
		if ("`group'" == "") == ("`contreat'" == "") {
			di as err "Specify exactly one of group() or contreat()."
			exit 198
		}
		if `"`varlist'"' == "" {
			di as err "Specify at least one covariate in varlist."
			exit 102
		}
	}
	if `width' < 8 {
		di as err "width() must be at least 8."
		exit 198
	}
	if `labwidth' < 8 {
		di as err "labwidth() must be at least 8."
		exit 198
	}
	if "`table'" != "" & "`tablefull'" != "" {
		di as err "table and tablefull may not be combined."
		exit 198
	}
	local tablemode "none"
	if "`table'" != "" local tablemode "compact"
	if "`tablefull'" != "" local tablemode "full"
	local dofade = ("`fadens'" != "" | "`fade'" != "")
	local docohensh = ("`cohensh'" != "")
	* Do not name this local "weight": marksample treats local weight as a Stata weight type.
	local matchwtvar "`matchweight'"
	local doweight = ("`matchwtvar'" != "")

	* Postestimation mode for official teffects/stteffects balance statistics.
	* tebalance summarize supplies raw and matched/weighted standardized differences
	* but no standard errors, so this mode plots points without confidence intervals.
	if `dotebalance' {
		if `"`if'"' != "" | `"`in'"' != "" {
			di as err "if and in restrictions are not allowed with tebalance."
			di as err "The active teffects or stteffects estimation sample determines the analysis sample."
			exit 198
		}
		if "`outcome'" != "" {
			di as err "outcome() may not be combined with tebalance."
			exit 198
		}
		if "`base'" != "" | `"`ref'"' != "" | `"`ref2'"' != "" | `"`ref3'"' != "" {
			di as err "base(), ref(), ref2(), and ref3() may not be combined with tebalance."
			exit 198
		}
		if `docohensh' {
			di as err "cohensh may not be combined with tebalance."
			exit 198
		}
		if `doweight' {
			di as err "matchweight() may not be combined with tebalance."
			exit 198
		}
		if `dofade' {
			di as err "fadens and fade may not be combined with tebalance because tebalance summarize does not return standard errors."
			exit 198
		}
		if "`table'" != "" | "`tablefull'" != "" {
			di as err "table and tablefull may not be combined with tebalance."
			di as err "Use tebalance summarize to display the underlying balance table."
			exit 198
		}
		if `dostore' {
			di as err "store() is not yet supported with tebalance."
			exit 198
		}
		if "`leg1'" != "" | "`leg2'" != "" {
			di as err "leg1() and leg2() may not be combined with tebalance."
			exit 198
		}

		capture which coefplot
		if _rc {
			di _newline
			di as err "balanceplot requires the user-written command coefplot."
			di as err "Click below to search for coefplot:"
			di as err "{stata search coefplot:  {bf:coefplot}}"
			exit 499
		}
		capture which tebalance
		if _rc {
			di as err "tebalance is not available in this version of Stata."
			exit 499
		}

		tempname tbfull tbsize tbbalance tbplot
		* syntax [varlist] may expand an omitted varlist to _all.  Use the
		* command text before the comma to distinguish no selection from an
		* explicitly requested tebalance covariate list.
		local tebalancevars `"`balance_lhs'"'
		if `"`tebalancevars'"' == "" capture quietly tebalance summarize
		else capture quietly tebalance summarize `tebalancevars'
		local tbrc = _rc
		if `tbrc' {
			di as err "tebalance mode requires active results from a supported teffects or stteffects estimator."
			exit `tbrc'
		}
		matrix `tbfull' = r(table)
		matrix `tbsize' = r(size)
		if rowsof(`tbfull') == 0 | colsof(`tbfull') < 2 {
			di as err "tebalance summarize did not return usable standardized differences."
			exit 498
		}
		local tbeq : coleq `tbfull'
		local tbeq1 : word 1 of `tbeq'
		local tbeq2 : word 2 of `tbeq'
		if "`tbeq1'" != "std_diff" | "`tbeq2'" != "std_diff" {
			di as err "Unexpected tebalance summarize return structure."
			di as err "The first two columns of r(table) were not standardized differences."
			exit 498
		}

		local tbnrows = rowsof(`tbfull')
		matrix `tbbalance' = `tbfull'[1..`tbnrows',1..2]
		matrix `tbplot' = `tbbalance'
		if `doabsolute' {
			forvalues row = 1/`tbnrows' {
				matrix `tbplot'[`row',1] = abs(`tbplot'[`row',1])
				matrix `tbplot'[`row',2] = abs(`tbplot'[`row',2])
			}
		}

		* Multivalued treatments store repeated covariate names in separate
		* matrix equations. coefplot otherwise overlays those equations on the
		* same covariate rows. Give the plot-only matrix unique row names and
		* reconstruct labels and treatment-category headings.
		local tbmultiblock = 0
		local tbfirsteq ""
		forvalues row = 1/`tbnrows' {
			mata: st_local("tbthiseq", st_matrixrowstripe("`tbbalance'")[`row',1])
			if "`tbthiseq'" != "" & "`tbthiseq'" != "_" {
				if "`tbfirsteq'" == "" local tbfirsteq `"`tbthiseq'"'
				else if `"`tbthiseq'"' != `"`tbfirsteq'"' local tbmultiblock = 1
			}
		}

		local tbcoeflabels
		local tbheadings
		local tbreturnedheadings
		if `tbmultiblock' {
			local tbplotnames
			local tbploteqs
			local tbpreveq ""
			forvalues row = 1/`tbnrows' {
				mata: st_local("tbthiseq", st_matrixrowstripe("`tbbalance'")[`row',1])
				mata: st_local("tbthiscoef", st_matrixrowstripe("`tbbalance'")[`row',2])
				local tbplotname "tb`row'"
				local tbplotnames "`tbplotnames' `tbplotname'"
				local tbploteqs "`tbploteqs' _"

				local tbrowlabel `"`tbthiscoef'"'
				capture confirm variable `tbthiscoef'
				if !_rc {
					local tbvarlabel : variable label `tbthiscoef'
					if `"`tbvarlabel'"' != "" local tbrowlabel `"`tbvarlabel'"'
				}
				local tbrowlabel = subinstr(`"`tbrowlabel'"', `"""', "'", .)
				local tbcoeflabels `"`tbcoeflabels' `tbplotname' = `"`tbrowlabel'"'"'

				if `"`tbthiseq'"' != `"`tbpreveq'"' {
					local tbeqlabel = subinstr(`"`tbthiseq'"', `"""', "'", .)
					local tbheadings `"`tbheadings' `tbplotname' = `"{bf:`tbeqlabel'}"'"'
					local tbpreveq `"`tbthiseq'"'
				}
			}
			matrix rownames `tbplot' = `tbplotnames'
			matrix roweq `tbplot' = `tbploteqs'
			local tbreturnedheadings `"`tbheadings'"'
		}

		local tbcols : colnames `tbbalance'
		local rawlabel : word 1 of `tbcols'
		local adjlabel : word 2 of `tbcols'
		local rawlegend "`rawlabel'"
		if "`rawlegend'" == "Raw" local rawlegend "Unweighted"
		local adjlegend "`adjlabel'"
		local graphtitle "Imbalance in Covariates Before and After Adjustment"
		if "`adjlabel'" == "Matched" local graphtitle "Imbalance in Covariates Before and After Matching"
		if "`adjlabel'" == "Weighted" local graphtitle "Imbalance in Covariates Before and After Weighting"

		local sortopt
		local sortmode "original"
		if "`sort'" != "" {
			local sortopt "sort(2)"
			if `doabsolute' local sortmode "absolute"
			else local sortmode "signed"
		}
		local xtitle "Standardized Imbalance"
		if `doabsolute' local xtitle "Absolute Standardized Imbalance"
		local thresholdopt
		if `dothreshold' {
			if `doabsolute' local thresholdopt "xline(`threshold', lpattern(dash) lcolor(gs12))"
			else local thresholdopt "xline(-`threshold' `threshold', lpattern(dash) lcolor(gs12))"
		}
		local tbcoeflabelsopt
		if `"`tbcoeflabels'"' != "" local tbcoeflabelsopt `"coeflabels(`tbcoeflabels')"'
		local tbheadingsopt
		if "`sort'" == "" & `"`tbheadings'"' != "" local tbheadingsopt `"headings(`tbheadings')"'
		if "`sort'" != "" local tbreturnedheadings ""
		local plots `"(matrix(`tbplot'[,1]), pstyle(p1) msymbol(Oh) offset(-.07) label(`"`rawlegend'"')) (matrix(`tbplot'[,2]), pstyle(p2) msymbol(O) offset(.07) label(`"`adjlegend'"'))"'
		local plotcommand_text `"`plots', noci `sortopt' xline(0) `thresholdopt' `tbcoeflabelsopt' `tbheadingsopt' xtitle(`"`xtitle'"') title(`"`graphtitle'"')"'
		if "`plotcommand'" != "" {
			di _newline
			di as txt "Matrix used for the plot:  `tbplot'"
			di as txt "Basic plot command:"
			di as result `"coefplot `plotcommand_text'"'
		}
		quietly coefplot `plots', noci `sortopt' xline(0) `thresholdopt' ///
			`tbcoeflabelsopt' `tbheadingsopt' ///
			xtitle("`xtitle'") title("`graphtitle'") ///
			graphregion(margin(l+`leftmargin')) `graphop'

		local tbrownames : rowfullnames `tbbalance'
		return clear
		return matrix table = `tbfull'
		return matrix balance = `tbbalance'
		return matrix size = `tbsize'
		return scalar nrows = `tbnrows'
		return scalar fadens = 0
		return scalar cohensh = 0
		return scalar weighted = 0
		return scalar absolute = `doabsolute'
		return scalar stored = 0
		return scalar width = `width'
		return scalar labwidth = `labwidth'
		if `dothreshold' return scalar threshold = `threshold'
		else return scalar threshold = .
		return local mode "tebalance"
		return local adjustment "`adjlabel'"
		return local rownames `"`tbrownames'"'
		return local plotcommand `"`plotcommand_text'"'
		return local measure "standardized_difference"
		return local xtitle "`xtitle'"
		return local sortmode "`sortmode'"
		return local tablemode "none"
		return local headings `"`tbreturnedheadings'"'
		return local coeflabels `"`tbcoeflabels'"'
		return local storestub ""
		return local stored_estimates ""
		return local contreat ""
		return local outcome ""
		return local weightvar ""
		exit
	}

	if `docontreat' {
		if `dothreshold' & `threshold' > 1 {
			di as err "With contreat(), threshold() must be greater than 0 and no greater than 1."
			exit 198
		}
		if "`base'" != "" {
			di as err "base() may be used only with group()."
			exit 198
		}
		if `docohensh' {
			di as err "cohensh may be used only with group()."
			exit 198
		}
		if `doweight' {
			di as err "matchweight() may not be combined with contreat()."
			exit 198
		}
		if "`leg1'" != "" | "`leg2'" != "" {
			di as err "leg1() and leg2() may be used only with group()."
			exit 198
		}
	}

	local analysisvar "`group'"
	if `docontreat' local analysisvar "`contreat'"
	capture confirm numeric variable `analysisvar'
	if _rc {
		if `docontreat' di as err "contreat() must specify a numeric variable."
		else di as err "group() must specify a numeric variable."
		exit 109
	}

	if "`outcome'" != "" {
		capture confirm numeric variable `outcome'
		if _rc {
			di as err "outcome() must specify one numeric variable."
			exit 109
		}
	}

	if `doweight' {
		capture confirm numeric variable `matchwtvar'
		if _rc {
			di as err "matchweight() must specify one numeric variable."
			exit 109
		}
	}

	if (`"`ref'"' != "") | (`"`ref2'"' != "") | (`"`ref3'"' != "") {
		di as err "ref(), ref2(), and ref3() are not allowed in balanceplot version 2."
		if !`docontreat' {
			di as err "All observed categories of group() are included automatically."
			di as err "Use an if or in restriction to exclude group categories from the analysis."
		}
		exit 198
	}

	* Mark the initial if/in sample and the complete-case analysis sample.
	tempvar touse0
	mark `touse0' `if' `in'
	markout `touse0' `analysisvar'
	marksample touse
	markout `touse' `analysisvar' `outcome'

	quietly count if `touse0'
	if r(N) == 0 error 2000
	quietly count if `touse'
	if r(N) == 0 {
		di as err "No complete observations remain after applying if/in and listwise deletion."
		exit 2000
	}

	* Preserve the original complete-case sample. matchweight() uses this sample
	* for the unweighted series and a restricted copy for weighted calculations.
	tempvar touse_unweighted
	quietly generate byte `touse_unweighted' = `touse'

	if !`docontreat' {
		quietly levelsof `group' if `touse', local(grouplevels)
		local ngroups : word count `grouplevels'
		if `ngroups' < 2 {
			di as err "group() must have at least two observed categories in the complete-case sample."
			exit 198
		}

		foreach g of local grouplevels {
			if `g' != floor(`g') {
				di as err "group() must contain integer-coded categories."
				di as err "Observed noninteger category: `g'"
				exit 459
			}
			quietly count if `touse' & `group' == `g'
			if r(N) < 2 {
				di as err "Group category `g' has fewer than two complete observations."
				di as err "At least two observations per included group are required."
				exit 2001
			}
		}

		* Select the group() base category.
		local basespecified = 0
		if "`base'" != "" local basespecified = 1
		if `basespecified' {
			local baseval = real("`base'")
			if missing(`baseval') | (`baseval' != floor(`baseval')) {
				di as err "base() must specify an integer category of `group'."
				exit 198
			}
			local basefound = 0
			foreach g of local grouplevels {
				if `g' == `baseval' local basefound = 1
			}
			if !`basefound' {
				di as err "Base category `baseval' is not observed in the complete-case sample."
				exit 2000
			}
		}
		else if `ngroups' == 2 {
			local g1 : word 1 of `grouplevels'
			local g2 : word 2 of `grouplevels'
			if (`g1' == 0) & (`g2' == 1) local baseval = 0
			else local baseval = `g1'
		}
		else {
			local maxn = -1
			foreach g of local grouplevels {
				quietly count if `touse' & `group' == `g'
				if r(N) > `maxn' {
					local maxn = r(N)
					local baseval = `g'
				}
			}
		}

		* Matching-weight semantics: always retain the original complete-case
		* sample for unweighted results. For weighted results, weight the base
		* group by matchweight() and assign weight 1 to every nonbase group.
		quietly count if `touse_unweighted' & `group' == `baseval'
		local base_n_unweighted = r(N)
		local base_sumw_unweighted = `base_n_unweighted'
		tempvar analysiswt
		quietly generate double `analysiswt' = 1 if `touse_unweighted'
		if `doweight' {
			quietly count if `touse_unweighted' & `group' == `baseval' & `matchwtvar' < 0
			if r(N) > 0 {
				di as err "matchweight() contains negative values in the base group."
				exit 402
			}
			quietly replace `touse' = 0 if `touse_unweighted' & `group' == `baseval' & ///
				(missing(`matchwtvar') | `matchwtvar' == 0)
			quietly replace `analysiswt' = `matchwtvar' if `touse' & `group' == `baseval'
			quietly replace `analysiswt' = 1 if `touse' & `group' != `baseval'
		}

		* Revalidate the weighted analysis sample after matching-weight exclusions.
		foreach g of local grouplevels {
			quietly count if `touse' & `group' == `g'
			if r(N) < 2 {
				di as err "Group category `g' has fewer than two usable observations."
				if `doweight' & (`g' == `baseval') {
					di as err "Check positive, nonmissing base-group values of matchweight(`matchwtvar')."
				}
				exit 2001
			}
		}
		quietly summarize `analysiswt' if `touse' & `group' == `baseval', meanonly
		local base_sumw = r(sum)
		quietly count if `touse' & `group' == `baseval'
		local base_n = r(N)
		if `base_sumw' <= 1 {
			di as err "The base group has insufficient positive matching weight."
			exit 2000
		}
	}

	capture which coefplot
	if _rc {
		di _newline
		di as err "balanceplot requires the user-written command coefplot."
		di as err "Click below to search for coefplot:"
		di as err "{stata search coefplot:  {bf:coefplot}}"
		exit 499
	}
	if `docontreat' {
		capture which polychoric
		if _rc {
			di _newline
			di as err "contreat() requires the user-written command polychoric."
			di as err "Click below to search for polychoric:"
			di as err "{stata search polychoric:  {bf:polychoric}}"
			exit 499
		}
	}

	quietly count if `touse0'
	local startn = r(N)
	quietly count if `touse_unweighted'
	local complete_n = r(N)
	quietly count if `touse'
	local weighted_n = r(N)
	local diffn = `startn' - `complete_n'
	local matchdiffn = `complete_n' - `weighted_n'

	* Parse covariates into explicit continuous variables and factor indicators.
	* Bare variables and c.var are continuous. i.var and ib#.var are categorical.
	local nrows = 0
	local rownames
	local workvars
	local coeflabels
	local parents

	foreach term of local varlist {
		if strpos("`term'", "#") {
			di as err "Factor-variable interactions are not yet supported by balanceplot version 2."
			di as err "Problematic term: `term'"
			exit 198
		}

		local dot = strpos("`term'", ".")
		if `dot' == 0 {
			local v "`term'"
			capture confirm numeric variable `v'
			if _rc {
				di as err "Covariate `v' must be numeric."
				exit 109
			}
			local ++nrows
			local rowtag "`v'"
			local duplicate : list posof "`rowtag'" in rownames
			if `duplicate' {
				di as err "Covariate `v' is specified more than once."
				exit 198
			}
			local rownames "`rownames' `rowtag'"
			local workvars "`workvars' `v'"
			local work_`nrows' "`v'"
			local placeholder_`nrows' = 0
			local categorical_`nrows' = 0
			local nominal_`nrows' = 0
			local parent_`nrows' "`v'"
			local display_`nrows' "`v'"
			local plotname_`nrows' "`rowtag'"
			local parents "`parents' `v'"
			continue
		}

		local prefix = substr("`term'", 1, `dot' - 1)
		local v = substr("`term'", `dot' + 1, .)
		if "`prefix'" == "c" {
			capture confirm numeric variable `v'
			if _rc {
				di as err "Covariate `v' must be numeric."
				exit 109
			}
			local ++nrows
			local rowtag "`v'"
			local duplicate : list posof "`rowtag'" in rownames
			if `duplicate' {
				di as err "Covariate `v' is specified more than once."
				exit 198
			}
			local rownames "`rownames' `rowtag'"
			local workvars "`workvars' `v'"
			local work_`nrows' "`v'"
			local placeholder_`nrows' = 0
			local categorical_`nrows' = 0
			local nominal_`nrows' = 0
			local parent_`nrows' "`v'"
			local display_`nrows' "`v'"
			local plotname_`nrows' "`rowtag'"
			local parents "`parents' `v'"
			continue
		}

		if ("`prefix'" != "i") & (substr("`prefix'",1,2) != "ib") {
			di as err "Unsupported factor-variable specification: `term'"
			di as err "Use a bare variable or c.var for continuous covariates and i.var or ib#.var for categorical covariates."
			exit 198
		}
		capture confirm numeric variable `v'
		if _rc {
			di as err "Categorical covariate `v' must be numeric."
			exit 109
		}

		capture quietly fvexpand `term' if `touse_unweighted'
		local rc = _rc
		if `rc' {
			di as err "Unable to expand categorical covariate `term'."
			exit `rc'
		}
		local expanded "`r(varlist)'"
		local nlevels : word count `expanded'
		if `nlevels' < 2 {
			di as err "Categorical covariate `v' has fewer than two observed categories in the complete-case sample."
			exit 198
		}

		local baselevel
		local baselabel
		foreach eterm of local expanded {
			local edot = strpos("`eterm'", ".")
			local left = substr("`eterm'", 1, `edot' - 1)
			if strpos("`left'", "b") {
				local leveltxt = subinstr("`left'", "b", "", .)
				local leveltxt = subinstr("`leveltxt'", "n", "", .)
				local baselevel = real("`leveltxt'")
				local baselabel : label (`v') `baselevel'
				if `"`baselabel'"' == "" local baselabel "`baselevel'"
			}
		}
		if "`baselevel'" == "" {
			local firstterm : word 1 of `expanded'
			local edot = strpos("`firstterm'", ".")
			local left = substr("`firstterm'", 1, `edot' - 1)
			local leveltxt = subinstr("`left'", "b", "", .)
			local leveltxt = subinstr("`leveltxt'", "n", "", .)
			local baselevel = real("`leveltxt'")
			local baselabel : label (`v') `baselevel'
			if `"`baselabel'"' == "" local baselabel "`baselevel'"
		}

		foreach eterm of local expanded {
			local edot = strpos("`eterm'", ".")
			local left = substr("`eterm'", 1, `edot' - 1)
			local leveltxt = subinstr("`left'", "b", "", .)
			local leveltxt = subinstr("`leveltxt'", "n", "", .)
			local catlevel = real("`leveltxt'")
			local isbase = (`catlevel' == `baselevel')

			* Binary factors contribute only the nonreference category.
			if (`nlevels' == 2) & `isbase' continue

			local ++nrows
			local rowtag "`eterm'"
			local duplicate : list posof "`rowtag'" in rownames
			if `duplicate' {
				di as err "Categorical covariate row `rowtag' is specified more than once."
				exit 198
			}

			tempvar indicator
			quietly generate byte `indicator' = (`v' == `catlevel') if `touse_unweighted'
			local catlabel : label (`v') `catlevel'
			if `"`catlabel'"' == "" local catlabel "`catlevel'"
			if `isbase' local display `"`catlabel' (ref)"'
			else local display `"`catlabel' (ref = `baselabel')"'

			local plotname = subinstr("`rowtag'", "bn.", ".", .)
			local plotname = subinstr("`plotname'", "b.", ".", .)
			local rownames "`rownames' `rowtag'"
			local workvars "`workvars' `indicator'"
			local work_`nrows' "`indicator'"
			local placeholder_`nrows' = (`nlevels' > 2) & `isbase' & !`docontreat'
			local categorical_`nrows' = 1
			local nominal_`nrows' = (`nlevels' > 2)
			local parent_`nrows' "`v'"
			local display_`nrows' `"`display'"'
			local plotname_`nrows' "`plotname'"
			local catlevel_`nrows' = `catlevel'
			local baselevel_`nrows' = `baselevel'
			local parents "`parents' `v'"
			local coeflabels `"`coeflabels' `plotname' = `"`display'"'"'
		}
	}

	if `nrows' == 0 {
		di as err "No covariates were available after parsing the varlist."
		exit 102
	}

	* Keep the original parser order available when fadens splits one comparison
	* into significant and nonsignificant coefplot layers.
	local plotorder
	forvalues row = 1/`nrows' {
		local plotorder "`plotorder' `plotname_`row''"
	}
	local plotorder : list retok plotorder

	* Add headings only for nominal covariates with three or more categories.
	local headingspec
	local headingparents
	forvalues row = 1/`nrows' {
		if !`nominal_`row'' continue
		local parent "`parent_`row''"
		local already : list posof "`parent'" in headingparents
		if !`already' {
			local anchor "`plotname_`row''"
			local varlabel : variable label `parent'
			if `"`varlabel'"' == "" local varlabel "`parent'"
			local varlabel = subinstr(`"`varlabel'"', `"""', "'", .)
			local headingspec `"`headingspec' `anchor' = `"{bf:`varlabel'}"'"'
			local headingparents "`headingparents' `parent'"
		}
	}

	* When store() is requested, preserve any estimation results that were active
	* before balanceplot posts temporary or final eclass results.
	local had_active_estimates = 0
	tempname held_active_estimates
	if `dostore' {
		capture confirm matrix e(b)
		if !_rc {
			quietly estimates store `held_active_estimates'
			local had_active_estimates = 1
		}
	}

	if `docontreat' {
		local alpha = (100 - `conflevel') / 100
		local tail = `alpha' / 2
		local crit = invnormal(1 - `tail')
		tempname corrmat corrplot
		matrix `corrmat' = J(`nrows',5,.)
		matrix rownames `corrmat' = `rownames'
		matrix colnames `corrmat' = correlation std_err ci_low ci_high p_value
		local corrN = `complete_n'

		forvalues row = 1/`nrows' {
			local w "`work_`row''"
			capture quietly polychoric `contreat' `w' if `touse'
			local rc = _rc
			if `rc' {
				local rowname : word `row' of `rownames'
				di as err "polychoric failed for continuous treatment `contreat' and covariate row `rowname'."
				exit `rc'
			}
			local rho = r(rho)
			local stderr = r(se_rho)
			if missing(`rho') | missing(`stderr') {
				local rowname : word `row' of `rownames'
				di as err "polychoric did not return a correlation and standard error for covariate row `rowname'."
				exit 498
			}
			if `stderr' <= 0 {
				if `rho' == 0 local pval = 1
				else local pval = 0
			}
			else {
				local zstat = `rho' / `stderr'
				local pval = 2 * normal(-abs(`zstat'))
			}
			matrix `corrmat'[`row',1] = `rho'
			matrix `corrmat'[`row',2] = `stderr'
			matrix `corrmat'[`row',3] = `rho' - `crit' * `stderr'
			matrix `corrmat'[`row',4] = `rho' + `crit' * `stderr'
			matrix `corrmat'[`row',5] = `pval'
		}

		matrix `corrplot' = `corrmat'
		if `doabsolute' {
			forvalues row = 1/`nrows' {
				local b = `corrmat'[`row',1]
				local ll = `corrmat'[`row',3]
				local ul = `corrmat'[`row',4]
				matrix `corrplot'[`row',1] = abs(`b')
				if (`ll' <= 0) & (`ul' >= 0) {
					matrix `corrplot'[`row',3] = 0
					matrix `corrplot'[`row',4] = max(abs(`ll'), abs(`ul'))
				}
				else if `ul' < 0 {
					matrix `corrplot'[`row',3] = abs(`ul')
					matrix `corrplot'[`row',4] = abs(`ll')
				}
			}
		}
		matrix rownames `corrplot' = `plotorder'

		local plots
		local plotcommand_text
		if !`dofade' {
			if "`noci'" == "" {
				local plots "(matrix(`corrplot'[,1]), ci((`corrplot'[,3] `corrplot'[,4])))"
				local plotcommand_text "(matrix(`corrplot'[,1]), ci((`corrplot'[,3] `corrplot'[,4])))"
			}
			else {
				local plots "(matrix(`corrplot'[,1]))"
				local plotcommand_text "(matrix(`corrplot'[,1]))"
			}
		}
		else {
			local sigrows
			local nsrows
			forvalues row = 1/`nrows' {
				local plotrow "`plotname_`row''"
				if `corrmat'[`row',5] < `alpha' local sigrows "`sigrows' `plotrow'"
				else local nsrows "`nsrows' `plotrow'"
			}
			if "`sigrows'" != "" {
				if "`noci'" == "" local layer "(matrix(`corrplot'[,1]), ci((`corrplot'[,3] `corrplot'[,4])) keep(`sigrows') pstyle(p1) ciopts(pstyle(p1)))"
				else local layer "(matrix(`corrplot'[,1]), keep(`sigrows') pstyle(p1))"
				local plots "`plots' `layer'"
				local plotcommand_text "`plotcommand_text' `layer'"
			}
			if "`nsrows'" != "" {
				if "`noci'" == "" local layer "(matrix(`corrplot'[,1]), ci((`corrplot'[,3] `corrplot'[,4])) keep(`nsrows') pstyle(p1) mcolor(*.3) ciopts(pstyle(p1) lcolor(*.3)) nokey)"
				else local layer "(matrix(`corrplot'[,1]), keep(`nsrows') pstyle(p1) mcolor(*.3) nokey)"
				local plots "`plots' `layer'"
				local plotcommand_text "`plotcommand_text' `layer'"
			}
		}

		if `diffn' > 0 {
			di _newline
			di as err "NOTE: `diffn' observations were excluded due to missing data on"
			di as err "a covariate, contreat(), or outcome() variable."
		}
		local treatlabel : variable label `contreat'
		if `"`treatlabel'"' == "" local treatlabel "`contreat'"
		local treatlabel = subinstr(`"`treatlabel'"', `"""', "'", .)
		di _newline
		if `"`treatlabel'"' == "`contreat'" {
			di as txt "Continuous treatment = `contreat'"
		}
		else {
			di as txt `"Continuous treatment = `contreat' (`treatlabel')"'
		}
		di as txt "N used in correlation calculations = " as result %12.0fc `corrN'
		if "`outcome'" != "" di as txt "Complete-case sample additionally restricted by outcome(`outcome')."

		if "`plotcommand'" != "" {
			di _newline
			di as txt "Matrix used for the plot: correlation"
			di as txt "Basic plot command:"
			di as result `"coefplot `plotcommand_text'"'
		}

		if "`tablemode'" != "none" {
			local displayrownames
			local displayroweq
			forvalues row = 1/`nrows' {
				local parent "`parent_`row''"
				if `categorical_`row'' local rowlabel `"`display_`row''"'
				else {
					local rowlabel : variable label `parent'
					if `"`rowlabel'"' == "" local rowlabel "`parent'"
				}
				if `nominal_`row'' {
					local eqlabel : variable label `parent'
					if `"`eqlabel'"' == "" local eqlabel "`parent'"
				}
				else local eqlabel "_"
				local rowlabel = subinstr(`"`rowlabel'"', `"""', "'", .)
				local rowlabel = subinstr(`"`rowlabel'"', ":", "-", .)
				if strlen(`"`rowlabel'"') > `labwidth' local rowlabel = substr(`"`rowlabel'"', 1, `labwidth' - 1) + "~"
				local displayrownames `"`displayrownames' `"`rowlabel'"'"'
				if "`eqlabel'" == "_" local displayroweq "`displayroweq' _"
				else {
					local eqlabel = subinstr(`"`eqlabel'"', `"""', "'", .)
					local eqlabel = subinstr(`"`eqlabel'"', ":", "-", .)
					if strlen(`"`eqlabel'"') > `labwidth' local eqlabel = substr(`"`eqlabel'"', 1, `labwidth' - 1) + "~"
					local displayroweq `"`displayroweq' `"`eqlabel'"'"'
				}
			}

			tempname displaymat
			if "`tablemode'" == "compact" {
				matrix `displaymat' = J(`nrows',2,.)
				forvalues row = 1/`nrows' {
					matrix `displaymat'[`row',1] = `corrmat'[`row',1]
					matrix `displaymat'[`row',2] = `corrmat'[`row',5]
				}
				matrix colnames `displaymat' = Correlation `"p-value"'
				matrix coleq `displaymat' = _ _
			}
			else {
				matrix `displaymat' = `corrmat'
				matrix colnames `displaymat' = Correlation SE Lower Upper `"p-value"'
				matrix coleq `displaymat' = _ _ `"`conflevel'% CI"' `"`conflevel'% CI"' _
			}
			matrix rownames `displaymat' = `displayrownames'
			matrix roweq `displaymat' = `displayroweq'
			if "`tablemode'" == "compact" {
				matlist `displaymat', format(%`width'.`decimals'f) twidth(`labwidth') ///
					rowtitle("Covariate") title(`"Treatment-covariate correlations: `treatlabel'"') ///
					nohalf underscore
			}
			else {
				matlist `displaymat', format(%`width'.`decimals'f) twidth(`labwidth') ///
					rowtitle("Covariate") title(`"Treatment-covariate correlations: `treatlabel'"') ///
					showcoleq(combined) keepcoleq nohalf underscore
			}
		}

		local sortopt
		local orderopt
		local sortmode "original"
		local returnedheadings `"`headingspec'"'
		local headingsopt
		if `"`headingspec'"' != "" local headingsopt `"headings(`headingspec')"'
		if `dofade' {
			if "`sort'" == "" local orderopt "order(`plotorder')"
			else {
				local sortedrows
				forvalues row = 1/`nrows' {
					local inserted = 0
					local newrows
					foreach oldrow of local sortedrows {
						if !`inserted' & (`corrplot'[`row',1] < `corrplot'[`oldrow',1]) {
							local newrows "`newrows' `row'"
							local inserted = 1
						}
						local newrows "`newrows' `oldrow'"
					}
					if !`inserted' local newrows "`newrows' `row'"
					local sortedrows : list retok newrows
				}
				local fadedorder
				foreach row of local sortedrows {
					local fadedorder "`fadedorder' `plotname_`row''"
				}
				local fadedorder : list retok fadedorder
				local orderopt "order(`fadedorder')"
			}
		}
		if "`sort'" != "" {
			if !`dofade' local sortopt "sort"
			if `doabsolute' local sortmode "absolute"
			else local sortmode "signed"
			local returnedheadings
			local headingsopt
		}
		local xtitle "Treatment-Covariate Correlation"
		if `doabsolute' local xtitle "Absolute Treatment-Covariate Correlation"
		local thresholdopt
		if `dothreshold' {
			if `doabsolute' local thresholdopt "xline(`threshold', lpattern(dash) lcolor(gs12))"
			else local thresholdopt "xline(-`threshold' `threshold', lpattern(dash) lcolor(gs12))"
		}
		local coeflabelopt
		if `"`coeflabels'"' != "" local coeflabelopt `"coeflabels(`coeflabels')"'
		quietly coefplot `plots', `sortopt' `orderopt' `coeflabelopt' `headingsopt' ///
			xline(0) `thresholdopt' xtitle("`xtitle'") ///
			title("Correlation Between Continuous Treatment and Covariates") ///
			subtitle("Continuous treatment: `treatlabel'", size(small)) ///
			legend(off) graphregion(margin(l+`leftmargin')) `graphop'

		* Store the signed correlations and polychoric standard errors. The
		* graph-only absolute transformation does not alter stored results.
		local stored_estimates
		if `dostore' {
			local estname "`store'_correlation"
			capture confirm name `estname'
			if _rc {
				if `had_active_estimates' {
					quietly estimates restore `held_active_estimates'
					quietly estimates drop `held_active_estimates'
				}
				else ereturn clear
				di as err "store() stub is too long for generated estimate name `estname'."
				exit 198
			}

			quietly estimates dir
			local existing_estimates "`r(names)'"
			local exists : list posof "`estname'" in existing_estimates
			if `exists' {
				if "`storereplace'" == "" {
					if `had_active_estimates' {
						quietly estimates restore `held_active_estimates'
						quietly estimates drop `held_active_estimates'
					}
					else ereturn clear
					di as err "The following stored estimate already exists: `estname'"
					di as err "Specify store(`store', replace) to replace it."
					exit 110
				}
				quietly estimates drop `estname'
			}

			tempname storeb storev
			matrix `storeb' = J(1,`nrows',.)
			matrix `storev' = J(`nrows',`nrows',0)
			forvalues row = 1/`nrows' {
				matrix `storeb'[1,`row'] = `corrmat'[`row',1]
				matrix `storev'[`row',`row'] = `corrmat'[`row',2]^2
			}
			matname `storeb' `plotorder', columns(1..`nrows') explicit
			matname `storev' `plotorder', columns(1..`nrows') explicit
			matname `storev' `plotorder', rows(1..`nrows') explicit
			quietly _balanceplot_eststore `storeb', vmat(`storev') estname(`estname') ///
				result(correlation) n(`corrN') contreat(`contreat')
			local stored_estimates "`estname'"

			if `had_active_estimates' {
				quietly estimates restore `held_active_estimates'
				quietly estimates drop `held_active_estimates'
			}
			else ereturn clear
		}

		return clear
		return matrix correlation = `corrmat'
		return scalar N = `corrN'
		return scalar nrows = `nrows'
		return scalar level = `conflevel'
		return scalar fadens = `dofade'
		return scalar cohensh = 0
		return scalar weighted = 0
		return scalar fadealpha = `alpha'
		return scalar width = `width'
		return scalar labwidth = `labwidth'
		return scalar absolute = `doabsolute'
		return scalar stored = `dostore'
		if `dothreshold' return scalar threshold = `threshold'
		else return scalar threshold = .
		local returnedrownames : list retok rownames
		return local mode "continuous_treatment"
		return local contreat "`contreat'"
		return local groups ""
		return local matrices "correlation"
		return local tablematrices ""
		return local tablefullmatrices ""
		return local storestub "`store'"
		return local stored_estimates "`stored_estimates'"
		return local outcome "`outcome'"
		return local weightvar ""
		return local rownames "`returnedrownames'"
		return local coeflabels `"`coeflabels'"'
		return local plotcommand `"`plotcommand_text'"'
		return local measure "correlation"
		return local xtitle "`xtitle'"
		return local graphnote ""
		return local sortmode "`sortmode'"
		return local tablemode "`tablemode'"
		return local headings `"`returnedheadings'"'
		exit
	}

	* Preserve the established internal-DV/regress structure, but calculate each
	* requested row explicitly so omitted or absent factor levels cannot disappear.
	tempvar depvar
	quietly generate double `depvar' = _n if `touse'
	foreach g of local grouplevels {
		if `doweight' {
			capture quietly regress `depvar' `workvars' [aw=`analysiswt'] if `group' == `g' & `touse', noconstant
		}
		else {
			capture quietly regress `depvar' `workvars' if `group' == `g' & `touse', noconstant
		}
		local rc = _rc
		if `rc' {
			di as err "The descriptive regression failed for group category `g'."
			exit `rc'
		}
		capture quietly estat summarize
		local rc = _rc
		if `rc' {
			di as err "estat summarize failed for group category `g'."
			exit `rc'
		}
	}

	local catbase : label (`group') `baseval'
	if `"`catbase'"' == "" local catbase "`baseval'"
	local basetag "`baseval'"
	if `baseval' < 0 local basetag "m`=abs(`baseval')'"

	local comparison = 0
	local matrixnames
	local unweightedmatrixnames
	local tablematrixnames
	local tablefullmatrixnames
	local unweightedtablematrixnames
	local unweightedtablefullmatrixnames
	local plots
	local plotcommand_text
	local firstmatrix
	local firstplotmatrix
	local firstunweightedmatrix
	local secondmatrix
	local secondunweightedmatrix
	local ncomparisons = `ngroups' - 1
	local alpha = (100 - `conflevel') / 100
	local tail = `alpha' / 2
	tempname denom

	foreach g of local grouplevels {
		if `g' != `baseval' {
			local ++comparison
			local gtag "`g'"
			if `g' < 0 local gtag "m`=abs(`g')'"
			local mname "bias_`basetag'_`gtag'"
			matrix `mname' = J(`nrows',7,.)
			matrix rownames `mname' = `rownames'
			matrix colnames `mname' = mean_base mean_ref ttest_pval std_diff std_err ci_low ci_high
			if `doweight' {
				local muname "bias_unweighted_`basetag'_`gtag'"
				matrix `muname' = J(`nrows',7,.)
				matrix rownames `muname' = `rownames'
				matrix colnames `muname' = mean_base mean_ref ttest_pval std_diff std_err ci_low ci_high
			}

			local statsets "primary"
			if `doweight' local statsets "unweighted weighted"
			foreach statset of local statsets {
				if "`statset'" == "unweighted" {
					local targetmatrix "`muname'"
					local samplevar "`touse_unweighted'"
					local usematchingweight = 0
				}
				else {
					local targetmatrix "`mname'"
					if `doweight' {
						local samplevar "`touse'"
						local usematchingweight = 1
					}
					else {
						local samplevar "`touse_unweighted'"
						local usematchingweight = 0
					}
				}

				forvalues row = 1/`nrows' {
					local w "`work_`row''"
					if `usematchingweight' {
						tempvar wxbase sqbase
						quietly generate double `wxbase' = `analysiswt' * `w' if `samplevar' & `group' == `baseval'
						quietly summarize `wxbase', meanonly
						local meanbase = r(sum) / `base_sumw'
						quietly generate double `sqbase' = `analysiswt' * (`w' - `meanbase')^2 if `samplevar' & `group' == `baseval'
						quietly summarize `sqbase', meanonly
						local varbase = r(sum) / (`base_sumw' - 1)
						local sdbase = sqrt(max(0, `varbase'))
						local nbase = `base_sumw'
						drop `wxbase' `sqbase'
					}
					else {
						quietly summarize `w' if `samplevar' & `group' == `baseval'
						local nbase = r(N)
						local meanbase = r(mean)
						local sdbase = r(sd)
					}
					quietly summarize `w' if `samplevar' & `group' == `g'
					local nref = r(N)
					local meanref = r(mean)
					local sdref = r(sd)
					matrix `targetmatrix'[`row',1] = `meanbase'
					matrix `targetmatrix'[`row',2] = `meanref'

					if `placeholder_`row'' {
						matrix `targetmatrix'[`row',3] = 1
						matrix `targetmatrix'[`row',4] = 0
						matrix `targetmatrix'[`row',5] = 0
						matrix `targetmatrix'[`row',6] = 0
						matrix `targetmatrix'[`row',7] = 0
					}
					else if `docohensh' & `categorical_`row'' {
						* Cohen's h for factor-indicator proportions.
						* Retain the established equal-variance p-value; use the
						* variance-stabilizing large-sample SE for h.
						local df = `nbase' + `nref' - 2
						local poolvar = ((`nbase' - 1) * `sdbase'^2 + (`nref' - 1) * `sdref'^2) / `df'
						local sediff = sqrt(`poolvar' * (1/`nbase' + 1/`nref'))
						if missing(`sediff') | (`sediff' <= 0) {
							if (`meanref' == `meanbase') local pval = 1
							else local pval = 0
						}
						else {
							local tstat = (`meanref' - `meanbase') / `sediff'
							local pval = 2 * ttail(`df', abs(`tstat'))
						}
						local stddiff = 2 * asin(sqrt(`meanref')) - 2 * asin(sqrt(`meanbase'))
						local stderr = sqrt(1/`nbase' + 1/`nref')
						local crit = invnormal(1 - `tail')
						matrix `targetmatrix'[`row',3] = `pval'
						matrix `targetmatrix'[`row',4] = `stddiff'
						matrix `targetmatrix'[`row',5] = `stderr'
						matrix `targetmatrix'[`row',6] = `stddiff' - `crit' * `stderr'
						matrix `targetmatrix'[`row',7] = `stddiff' + `crit' * `stderr'
					}
					else {
						scalar `denom' = sqrt((`sdref'^2 + `sdbase'^2) / 2)
						if missing(`denom') | (`denom' <= 0) {
							if (`meanref' == `meanbase') {
								matrix `targetmatrix'[`row',3] = 1
								matrix `targetmatrix'[`row',4] = 0
								matrix `targetmatrix'[`row',5] = 0
								matrix `targetmatrix'[`row',6] = 0
								matrix `targetmatrix'[`row',7] = 0
							}
							else {
								local rowname : word `row' of `rownames'
								di as err "Standardized imbalance is undefined for `rowname' in the comparison `baseval' versus `g'."
								di as err "The pooled standard deviation is zero while the group means differ."
								exit 498
							}
						}
						else {
							local df = `nbase' + `nref' - 2
							local poolvar = ((`nbase' - 1) * `sdbase'^2 + (`nref' - 1) * `sdref'^2) / `df'
							local sediff = sqrt(`poolvar' * (1/`nbase' + 1/`nref'))
							local stddiff = (`meanref' - `meanbase') / `denom'
							local stderr = `sediff' / `denom'
							local tstat = (`meanref' - `meanbase') / `sediff'
							local pval = 2 * ttail(`df', abs(`tstat'))
							local crit = invttail(`df', `tail')
							matrix `targetmatrix'[`row',3] = `pval'
							matrix `targetmatrix'[`row',4] = `stddiff'
							matrix `targetmatrix'[`row',5] = `stderr'
							matrix `targetmatrix'[`row',6] = `stddiff' - `crit' * `stderr'
							matrix `targetmatrix'[`row',7] = `stddiff' + `crit' * `stderr'
						}
					}
				}
			}

			* Build export-ready compact and detailed table matrices. Existing
			* table# returns remain the weighted results when matchweight() is used.
			local exportsets "primary"
			if `doweight' local exportsets "primary unweighted"
			foreach exportset of local exportsets {
				if "`exportset'" == "unweighted" {
					local sourcematrix "`muname'"
					local tname "table_unweighted_`basetag'_`gtag'"
					local tfname "tablefull_unweighted_`basetag'_`gtag'"
				}
				else {
					local sourcematrix "`mname'"
					local tname "table_`basetag'_`gtag'"
					local tfname "tablefull_`basetag'_`gtag'"
				}
				matrix `tname' = J(`nrows',4,.)
				matrix `tfname' = J(`nrows',7,.)
				matrix rownames `tname' = `rownames'
				matrix rownames `tfname' = `rownames'
				matrix colnames `tname' = mean_g`basetag' mean_g`gtag' std_imbalance p_value
				matrix colnames `tfname' = mean_g`basetag' mean_g`gtag' std_imbalance std_err ci_low ci_high p_value
				forvalues row = 1/`nrows' {
					matrix `tname'[`row',1] = `sourcematrix'[`row',1]
					matrix `tname'[`row',2] = `sourcematrix'[`row',2]
					matrix `tname'[`row',3] = `sourcematrix'[`row',4]
					matrix `tname'[`row',4] = `sourcematrix'[`row',3]
					matrix `tfname'[`row',1] = `sourcematrix'[`row',1]
					matrix `tfname'[`row',2] = `sourcematrix'[`row',2]
					matrix `tfname'[`row',3] = `sourcematrix'[`row',4]
					matrix `tfname'[`row',4] = `sourcematrix'[`row',5]
					matrix `tfname'[`row',5] = `sourcematrix'[`row',6]
					matrix `tfname'[`row',6] = `sourcematrix'[`row',7]
					matrix `tfname'[`row',7] = `sourcematrix'[`row',3]
				}
				if "`exportset'" == "unweighted" {
					local unweightedtablematrixnames "`unweightedtablematrixnames' `tname'"
					local unweightedtablefullmatrixnames "`unweightedtablefullmatrixnames' `tfname'"
					local table_unweightedmatrix_`comparison' "`tname'"
					local tablefull_unweightedmatrix_`comparison' "`tfname'"
				}
				else {
					local tablematrixnames "`tablematrixnames' `tname'"
					local tablefullmatrixnames "`tablefullmatrixnames' `tfname'"
					local tablematrix_`comparison' "`tname'"
					local tablefullmatrix_`comparison' "`tfname'"
				}
			}

			local cat : label (`group') `g'
			if `"`cat'"' == "" local cat "`g'"
			quietly count if `touse' & `group' == `g'
			local group_n_`comparison' = r(N)
			quietly count if `touse_unweighted' & `group' == `g'
			local group_n_unweighted_`comparison' = r(N)
			local group_value_`comparison' = `g'
			local group_label_`comparison' `"`cat'"'
			local plotlabel `"`catbase' vs `cat'"'
			if (`comparison' == 1) & (`"`leg1'"' != "") local plotlabel `"`leg1'"'
			if (`comparison' == 2) & (`"`leg2'"' != "") local plotlabel `"`leg2'"'

			local plotsets "primary"
			if `doweight' local plotsets "unweighted weighted"
			foreach plotset of local plotsets {
				if "`plotset'" == "unweighted" {
					local sourcematrix "`muname'"
					local statuslabel "Unweighted"
					local msymbolopt "msymbol(Oh)"
					local seriesindex = 2 * `comparison' - 1
				}
				else if "`plotset'" == "weighted" {
					local sourcematrix "`mname'"
					local statuslabel "Weighted"
					local msymbolopt "msymbol(O)"
					local seriesindex = 2 * `comparison'
				}
				else {
					local sourcematrix "`mname'"
					local statuslabel ""
					local msymbolopt ""
					local seriesindex = `comparison'
				}

				* absolute affects the graph only; returned matrices and tables remain signed.
				local plotmatrix "`sourcematrix'"
				if `doabsolute' {
					if "`plotset'" == "unweighted" local pmname "plotabs_unweighted_`basetag'_`gtag'"
					else local pmname "plotabs_`basetag'_`gtag'"
					matrix `pmname' = `sourcematrix'
					forvalues row = 1/`nrows' {
						local b = `sourcematrix'[`row',4]
						local ll = `sourcematrix'[`row',6]
						local ul = `sourcematrix'[`row',7]
						matrix `pmname'[`row',4] = abs(`b')
						if (`ll' <= 0) & (`ul' >= 0) {
							matrix `pmname'[`row',6] = 0
							matrix `pmname'[`row',7] = max(abs(`ll'), abs(`ul'))
						}
						else if `ul' < 0 {
							matrix `pmname'[`row',6] = abs(`ul')
							matrix `pmname'[`row',7] = abs(`ll')
						}
					}
					local plotmatrix "`pmname'"
				}

				if `doweight' {
					if "`plotset'" == "unweighted" local style = 1
					else local style = 2
				}
				else local style = mod(`comparison' - 1, 15) + 1
				local offset = 0
				local serieslabel `"`plotlabel'"'
				local styleopts
				if `doweight' {
					local nseries = 2 * `ncomparisons'
					if `nseries' == 2 local totalspread = .14
					else local totalspread = .36
					local offsetstep = `totalspread' / (`nseries' - 1)
					local offset = (`seriesindex' - (`nseries' + 1) / 2) * `offsetstep'
					if `ncomparisons' == 1 local serieslabel `"`statuslabel'"'
					else local serieslabel `"`plotlabel': `statuslabel'"'
					local styleopts "pstyle(p`style') `msymbolopt' offset(`offset')"
				}
				else if `dofade' & (`ncomparisons' > 1) {
					local offsetstep = .3 / (`ncomparisons' - 1)
					local offset = (`comparison' - (`ncomparisons' + 1) / 2) * `offsetstep'
					local styleopts "pstyle(p`style') offset(`offset')"
				}

				if !`dofade' {
					if "`noci'" == "" {
						local ciopts
						if `doweight' local ciopts "ciopts(pstyle(p`style'))"
						local layer `"(matrix(`plotmatrix'[,4]), ci((`plotmatrix'[,6] `plotmatrix'[,7])) `styleopts' `ciopts' label(`"`serieslabel'"'))"'
					}
					else local layer `"(matrix(`plotmatrix'[,4]), `styleopts' label(`"`serieslabel'"'))"'
					local plots `"`plots' `layer'"'
					local plotcommand_text `"`plotcommand_text' `layer'"'
				}
				else {
					local sigrows
					local nsrows
					forvalues row = 1/`nrows' {
						local plotrow "`plotname_`row''"
						if `sourcematrix'[`row',3] < `alpha' local sigrows "`sigrows' `plotrow'"
						else local nsrows "`nsrows' `plotrow'"
					}
					if "`sigrows'" != "" {
						if "`noci'" == "" local layer `"(matrix(`plotmatrix'[,4]), ci((`plotmatrix'[,6] `plotmatrix'[,7])) keep(`sigrows') pstyle(p`style') `msymbolopt' ciopts(pstyle(p`style')) offset(`offset') label(`"`serieslabel'"'))"'
						else local layer `"(matrix(`plotmatrix'[,4]), keep(`sigrows') pstyle(p`style') `msymbolopt' offset(`offset') label(`"`serieslabel'"'))"'
						local plots `"`plots' `layer'"'
						local plotcommand_text `"`plotcommand_text' `layer'"'
					}
					if "`nsrows'" != "" {
						local keyopt
						if "`sigrows'" != "" local keyopt "nokey"
						else local keyopt `"label(`"`serieslabel'"')"'
						if "`noci'" == "" local layer `"(matrix(`plotmatrix'[,4]), ci((`plotmatrix'[,6] `plotmatrix'[,7])) keep(`nsrows') pstyle(p`style') `msymbolopt' mcolor(*.3) ciopts(pstyle(p`style') lcolor(*.3)) offset(`offset') `keyopt')"'
						else local layer `"(matrix(`plotmatrix'[,4]), keep(`nsrows') pstyle(p`style') `msymbolopt' mcolor(*.3) offset(`offset') `keyopt')"'
						local plots `"`plots' `layer'"'
						local plotcommand_text `"`plotcommand_text' `layer'"'
					}
				}
			}

			local matrixnames "`matrixnames' `mname'"
			local matrix_`comparison' "`mname'"
			if `doweight' {
				local unweightedmatrixnames "`unweightedmatrixnames' `muname'"
				local unweightedmatrix_`comparison' "`muname'"
			}
			if `comparison' == 1 {
				local firstmatrix "`mname'"
				if `doweight' {
					local firstunweightedmatrix "`muname'"
					if `doabsolute' local firstplotmatrix "plotabs_`basetag'_`gtag'"
					else local firstplotmatrix "`mname'"
				}
				else {
					if `doabsolute' local firstplotmatrix "plotabs_`basetag'_`gtag'"
					else local firstplotmatrix "`mname'"
				}
			}
			if `comparison' == 2 {
				local secondmatrix "`mname'"
				if `doweight' local secondunweightedmatrix "`muname'"
			}
		}
	}
	if `diffn' > 0 {
		di _newline
		di as err "NOTE: `diffn' observations were excluded due to missing data on"
		di as err "at least one covariate, group(), or outcome() variable."
	}
	if `doweight' & (`matchdiffn' > 0) {
		di as err "NOTE: `matchdiffn' additional base-group observations were excluded from"
		di as err "weighted calculations due to a zero or missing matchweight()."
	}
	di _newline
	di as txt "Base category = `baseval'_`catbase'"
	if !`basespecified' {
		if (`ngroups' == 2) & (`baseval' == 0) di as txt "Base selected by the 0/1 two-group default."
		else if `ngroups' == 2 di as txt "Base selected as the lowest observed two-group category."
		else di as txt "Base selected as the largest complete-case group."
	}
	di _newline
	if `doweight' {
		di as txt "N used in unweighted balance calculations"
		foreach g of local grouplevels {
			local cat : label (`group') `g'
			if `"`cat'"' == "" local cat "`g'"
			quietly count if `touse_unweighted' & `group' == `g'
			di as result "- N for `group' = `g'_`cat': " r(N)
		}
		di as txt "N used in weighted balance calculations"
		di as txt "matchweight(`matchwtvar') applies to the base group only; all nonbase groups have weight 1."
		foreach g of local grouplevels {
			local cat : label (`group') `g'
			if `"`cat'"' == "" local cat "`g'"
			quietly count if `touse' & `group' == `g'
			local gn = r(N)
			if `g' == `baseval' di as result "- N for `group' = `g'_`cat': `gn'; sum of matching weights = " %12.4g `base_sumw'
			else di as result "- N for `group' = `g'_`cat': `gn'"
		}
	}
	else {
		di as txt "N used in balance calculations"
		foreach g of local grouplevels {
			local cat : label (`group') `g'
			if `"`cat'"' == "" local cat "`g'"
			quietly count if `touse' & `group' == `g'
			di as result "- N for `group' = `g'_`cat': " r(N)
		}
	}
	if "`outcome'" != "" di as txt "Complete-case sample additionally restricted by outcome(`outcome')."
	if "`plotcommand'" != "" {
		di _newline
		if `doweight' di as txt "Matrices used for the plot: `unweightedmatrixnames' `matrixnames'"
		else di as txt "Matrices used for the plot: `matrixnames'"
		di as txt "Basic plot command:"
		di as result `"coefplot `plotcommand_text'"'
	}

	if "`tablemode'" != "none" {
		* Use matlist so Stata moves columns into additional panels when the
		* table is wider than the active linesize. Default matlist borders
		* match the layout used by mlincom.
		local base_n_text : display %12.0fc `base_n'
		local base_n_text = strtrim("`base_n_text'")
		local base_title `"`catbase' (N=`base_n_text')"'
		local base_n_unweighted_text : display %12.0fc `base_n_unweighted'
		local base_n_unweighted_text = strtrim("`base_n_unweighted_text'")
		local base_title_unweighted `"`catbase' (N=`base_n_unweighted_text')"'
		if `doweight' {
			local base_sumw_text : display %12.4g `base_sumw'
			local base_sumw_text = strtrim("`base_sumw_text'")
			local base_title `"`catbase' (N=`base_n_text'; sum w=`base_sumw_text')"'
		}

		* Continuous rows use variable labels; factor rows use category labels.
		* Only nominal covariates receive row-equation headings.
		local displayrownames
		local displayroweq
		forvalues row = 1/`nrows' {
			local parent "`parent_`row''"
			if `categorical_`row'' local rowlabel `"`display_`row''"'
			else {
				local rowlabel : variable label `parent'
				if `"`rowlabel'"' == "" local rowlabel "`parent'"
			}
			if `nominal_`row'' {
				local eqlabel : variable label `parent'
				if `"`eqlabel'"' == "" local eqlabel "`parent'"
			}
			else local eqlabel "_"
			local rowlabel = subinstr(`"`rowlabel'"', `"""', "'", .)
			local rowlabel = subinstr(`"`rowlabel'"', ":", "-", .)
			if strlen(`"`rowlabel'"') > `labwidth' local rowlabel = substr(`"`rowlabel'"', 1, `labwidth' - 1) + "~"
			local displayrownames `"`displayrownames' `"`rowlabel'"'"'
			if "`eqlabel'" == "_" local displayroweq "`displayroweq' _"
			else {
				local eqlabel = subinstr(`"`eqlabel'"', `"""', "'", .)
				local eqlabel = subinstr(`"`eqlabel'"', ":", "-", .)
				if strlen(`"`eqlabel'"') > `labwidth' local eqlabel = substr(`"`eqlabel'"', 1, `labwidth' - 1) + "~"
				local displayroweq `"`displayroweq' `"`eqlabel'"'"'
			}
		}

		forvalues j = 1/`comparison' {
			local g = `group_value_`j''
			local cat `"`group_label_`j''"'
			local tabletypes "primary"
			if `doweight' local tabletypes "unweighted weighted"
			foreach tabletype of local tabletypes {
				if "`tabletype'" == "unweighted" {
					local gn = `group_n_unweighted_`j''
					local thisbase `"`base_title_unweighted'"'
					local titleprefix "Unweighted balance results"
					local tname "`table_unweightedmatrix_`j''"
					local tfname "`tablefull_unweightedmatrix_`j''"
				}
				else {
					local gn = `group_n_`j''
					local thisbase `"`base_title'"'
					if "`tabletype'" == "weighted" local titleprefix "Weighted balance results"
					else local titleprefix "Balance results"
					local tname "`tablematrix_`j''"
					local tfname "`tablefullmatrix_`j''"
				}
				local gn_text : display %12.0fc `gn'
				local gn_text = strtrim("`gn_text'")
				local title `"`titleprefix': `thisbase' vs `cat' (N=`gn_text')"'

				tempname displaymat
				if "`tablemode'" == "compact" matrix `displaymat' = `tname'
				else matrix `displaymat' = `tfname'
				matrix rownames `displaymat' = `displayrownames'
				matrix roweq `displaymat' = `displayroweq'

				if "`tablemode'" == "compact" {
					matrix colnames `displaymat' = Mean Mean Imbalance `"p-value"'
					matrix coleq `displaymat' = `"`group'=`baseval'"' `"`group'=`g'"' Standardized _
				}
				else {
					matrix colnames `displaymat' = Mean Mean Imbalance SE Lower Upper `"p-value"'
					matrix coleq `displaymat' = `"`group'=`baseval'"' `"`group'=`g'"' Standardized _ `"`conflevel'% CI"' `"`conflevel'% CI"' _
				}

				matlist `displaymat', format(%`width'.`decimals'f) twidth(`labwidth') ///
					rowtitle("Covariate") title(`"`title'"') showcoleq(combined) ///
					keepcoleq nohalf underscore

				if `docohensh' {
					di as txt "Note: Standardized imbalance is calculated as Cohen's h for"
					di as txt "      binary and nominal variables."
				}
			}
		}
	}
	local sortopt
	local orderopt
	local legendopt
	local sortmode "original"
	local returnedheadings `"`headingspec'"'
	local headingsopt
	if `"`headingspec'"' != "" local headingsopt `"headings(`headingspec')"'

	* fadens and combined weighted/unweighted plots use multiple layers. Supply
	* an explicit row order so layers cannot reorder covariates. With sort and
	* matchweight(), order rows by the weighted first comparison.
	if `dofade' | `doweight' {
		if "`sort'" == "" local orderopt "order(`plotorder')"
		else {
			local sortedrows
			forvalues row = 1/`nrows' {
				local inserted = 0
				local newrows
				foreach oldrow of local sortedrows {
					if !`inserted' & (`firstplotmatrix'[`row',4] < `firstplotmatrix'[`oldrow',4]) {
						local newrows "`newrows' `row'"
						local inserted = 1
					}
					local newrows "`newrows' `oldrow'"
				}
				if !`inserted' local newrows "`newrows' `row'"
				local sortedrows : list retok newrows
			}
			local explicitorder
			foreach row of local sortedrows {
				local explicitorder "`explicitorder' `plotname_`row''"
			}
			local explicitorder : list retok explicitorder
			local orderopt "order(`explicitorder')"
		}
		if `dofade' & (`ncomparisons' == 1) & !`doweight' local legendopt "legend(off)"
	}

	if "`sort'" != "" {
		if !`dofade' & !`doweight' local sortopt "sort"
		if `doabsolute' local sortmode "absolute"
		else local sortmode "signed"
		local returnedheadings
		local headingsopt
	}
	local xtitle "Standardized Imbalance"
	if `doabsolute' local xtitle "Absolute Standardized Imbalance"
	local graphnote
	local noteopt
	local measure "standardized_difference"
	if `docohensh' {
		local graphnote "Standardized imbalance is calculated as Cohen's h for binary and nominal variables."
		local noteopt `"note(`"`graphnote'"', span)"'
		local measure "cohens_h_for_categorical"
	}
	local thresholdopt
	if `dothreshold' {
		if `doabsolute' local thresholdopt "xline(`threshold', lpattern(dash) lcolor(gs12))"
		else local thresholdopt "xline(-`threshold' `threshold', lpattern(dash) lcolor(gs12))"
	}
	local coeflabelopt
	if `"`coeflabels'"' != "" local coeflabelopt `"coeflabels(`coeflabels')"'
	quietly coefplot `plots', baselevels `sortopt' `orderopt' `coeflabelopt' `headingsopt' xline(0) `thresholdopt' ///
		xtitle("`xtitle'") ///
		title("Imbalance in Covariates Across Groups of `group'") ///
		subtitle("Reference category: `catbase'", size(small)) ///
		`legendopt' `noteopt' graphregion(margin(l+`leftmargin')) `graphop'

	* Post group means and imbalance statistics as separate estimation results.
	* Without matchweight(), retain the established names. With matchweight(),
	* post complete unweighted (unw) and weighted (w) sets.
	local stored_estimates
	if `dostore' {
		local storestatuses "primary"
		if `doweight' local storestatuses "unw w"
		local storenames

		* Validate every generated name before replacing or posting anything.
		foreach storestatus of local storestatuses {
			local prefix
			if "`storestatus'" != "primary" local prefix "_`storestatus'"
			foreach g of local grouplevels {
				local gtag "`g'"
				if `g' < 0 local gtag "m`=abs(`g')'"
				local estname "`store'`prefix'_mean_g`gtag'"
				capture confirm name `estname'
				if _rc {
					if `had_active_estimates' {
						quietly estimates restore `held_active_estimates'
						quietly estimates drop `held_active_estimates'
					}
					else ereturn clear
					di as err "store() stub is too long for generated estimate name `estname'."
					exit 198
				}
				local storenames "`storenames' `estname'"
			}
			forvalues j = 1/`comparison' {
				local g = `group_value_`j''
				local gtag "`g'"
				if `g' < 0 local gtag "m`=abs(`g')'"
				if `comparison' == 1 local estname "`store'`prefix'_imbalance"
				else local estname "`store'`prefix'_imb_g`gtag'"
				capture confirm name `estname'
				if _rc {
					if `had_active_estimates' {
						quietly estimates restore `held_active_estimates'
						quietly estimates drop `held_active_estimates'
					}
					else ereturn clear
					di as err "store() stub is too long for generated estimate name `estname'."
					exit 198
				}
				local storenames "`storenames' `estname'"
			}
		}
		local storenames : list retok storenames

		quietly estimates dir
		local existing_estimates "`r(names)'"
		local collisions
		foreach estname of local storenames {
			local exists : list posof "`estname'" in existing_estimates
			if `exists' local collisions "`collisions' `estname'"
		}
		local collisions : list retok collisions
		if "`collisions'" != "" {
			if "`storereplace'" == "" {
				if `had_active_estimates' {
					quietly estimates restore `held_active_estimates'
					quietly estimates drop `held_active_estimates'
				}
				else ereturn clear
				di as err "The following stored estimates already exist: `collisions'"
				di as err "Specify store(`store', replace) to replace them."
				exit 110
			}
			quietly estimates drop `collisions'
		}

		tempname storeb storev
		foreach storestatus of local storestatuses {
			local prefix
			local statusopt
			if "`storestatus'" == "unw" {
				local prefix "_unw"
				local statusopt "status(unweighted)"
			}
			else if "`storestatus'" == "w" {
				local prefix "_w"
				local statusopt "status(weighted)"
			}

			* Group-specific means.
			foreach g of local grouplevels {
				local gtag "`g'"
				if `g' < 0 local gtag "m`=abs(`g')'"
				local estname "`store'`prefix'_mean_g`gtag'"
				matrix `storeb' = J(1,`nrows',.)
				if `g' == `baseval' {
					if "`storestatus'" == "unw" {
						local sourcematrix "`firstunweightedmatrix'"
						local gn = `base_n_unweighted'
					}
					else {
						local sourcematrix "`firstmatrix'"
						local gn = `base_n'
					}
					forvalues row = 1/`nrows' {
						matrix `storeb'[1,`row'] = `sourcematrix'[`row',1]
					}
				}
				else {
					local sourcej
					forvalues j = 1/`comparison' {
						if `group_value_`j'' == `g' local sourcej = `j'
					}
					if "`storestatus'" == "unw" {
						local sourcematrix "`unweightedmatrix_`sourcej''"
						local gn = `group_n_unweighted_`sourcej''
					}
					else {
						local sourcematrix "`matrix_`sourcej''"
						local gn = `group_n_`sourcej''
					}
					forvalues row = 1/`nrows' {
						matrix `storeb'[1,`row'] = `sourcematrix'[`row',2]
					}
				}
				matname `storeb' `plotorder', columns(1..`nrows') explicit
				quietly _balanceplot_eststore `storeb', estname(`estname') ///
					result(mean) n(`gn') `statusopt' groupvar(`group') ///
					groupvalue("`g'") basevalue("`baseval'")
				local stored_estimates "`stored_estimates' `estname'"
			}

			* Imbalance estimates and their standard errors.
			forvalues j = 1/`comparison' {
				local g = `group_value_`j''
				local gtag "`g'"
				if `g' < 0 local gtag "m`=abs(`g')'"
				if `comparison' == 1 local estname "`store'`prefix'_imbalance"
				else local estname "`store'`prefix'_imb_g`gtag'"
				if "`storestatus'" == "unw" {
					local sourcematrix "`unweightedmatrix_`j''"
					local gn = `group_n_unweighted_`j''
					local basen_store = `base_n_unweighted'
					local dfr_nbase = `base_n_unweighted'
				}
				else {
					local sourcematrix "`matrix_`j''"
					local gn = `group_n_`j''
					local basen_store = `base_n'
					if `doweight' local dfr_nbase = `base_sumw'
					else local dfr_nbase = `base_n'
				}
				matrix `storeb' = J(1,`nrows',.)
				matrix `storev' = J(`nrows',`nrows',0)
				forvalues row = 1/`nrows' {
					matrix `storeb'[1,`row'] = `sourcematrix'[`row',4]
					matrix `storev'[`row',`row'] = `sourcematrix'[`row',5]^2
				}
				matname `storeb' `plotorder', columns(1..`nrows') explicit
				matname `storev' `plotorder', columns(1..`nrows') explicit
				matname `storev' `plotorder', rows(1..`nrows') explicit
				local totaln = `basen_store' + `gn'
				local dfopt
				if !`docohensh' {
					local dfr = `dfr_nbase' + `gn' - 2
					local dfopt "dfr(`dfr')"
				}
				quietly _balanceplot_eststore `storeb', vmat(`storev') estname(`estname') ///
					result(imbalance) n(`totaln') `dfopt' `statusopt' groupvar(`group') ///
					groupvalue("`g'") basevalue("`baseval'")
				local stored_estimates "`stored_estimates' `estname'"
			}
		}
		local stored_estimates : list retok stored_estimates

		if `had_active_estimates' {
			quietly estimates restore `held_active_estimates'
			quietly estimates drop `held_active_estimates'
		}
		else ereturn clear
	}

	return clear

	if `comparison' >= 1 return matrix bias1 = `firstmatrix'
	if `comparison' >= 1 return matrix table1 = `tablematrix_1'
	if `comparison' >= 1 return matrix tablefull1 = `tablefullmatrix_1'
	if `comparison' >= 2 return matrix bias2 = `secondmatrix'
	if `comparison' >= 2 return matrix table2 = `tablematrix_2'
	if `comparison' >= 2 return matrix tablefull2 = `tablefullmatrix_2'
	if `comparison' >= 3 {
		forvalues j = 3/`comparison' {
			return matrix bias`j' = `matrix_`j''
			return matrix table`j' = `tablematrix_`j''
			return matrix tablefull`j' = `tablefullmatrix_`j''
		}
	}
	if `doweight' {
		forvalues j = 1/`comparison' {
			return matrix bias_unweighted`j' = `unweightedmatrix_`j''
			return matrix table_unweighted`j' = `table_unweightedmatrix_`j''
			return matrix tablefull_unweighted`j' = `tablefull_unweightedmatrix_`j''
		}
	}
	return scalar base = `baseval'
	return scalar ngroups = `ngroups'
	return scalar nrows = `nrows'
	return scalar level = `conflevel'
	return scalar fadens = `dofade'
	return scalar cohensh = `docohensh'
	return scalar weighted = `doweight'
	return scalar base_n = `base_n'
	return scalar base_n_unweighted = `base_n_unweighted'
	return scalar base_sumw = `base_sumw'
	return scalar fadealpha = `alpha'
	return scalar width = `width'
	return scalar labwidth = `labwidth'
	return scalar absolute = `doabsolute'
	return scalar stored = `dostore'
	if `dothreshold' return scalar threshold = `threshold'
	else return scalar threshold = .
	local returnedrownames : list retok rownames
	return local mode "group"
	return local contreat ""
	return local groups "`grouplevels'"
	local returnedmatrices : list retok matrixnames
	local returnedtablematrices : list retok tablematrixnames
	local returnedtablefullmatrices : list retok tablefullmatrixnames
	local returnedunweightedmatrices : list retok unweightedmatrixnames
	local returnedunweightedtablematrices : list retok unweightedtablematrixnames
	local returneduwtfmats : list retok unweightedtablefullmatrixnames
	return local matrices "`returnedmatrices'"
	return local tablematrices "`returnedtablematrices'"
	return local tablefullmatrices "`returnedtablefullmatrices'"
	return local unweighted_matrices "`returnedunweightedmatrices'"
	return local table_unweighted_matrices "`returnedunweightedtablematrices'"
	return local tablefull_unweighted_matrices "`returneduwtfmats'"
	return local storestub "`store'"
	return local stored_estimates "`stored_estimates'"
	return local outcome "`outcome'"
	return local weightvar "`matchwtvar'"
	return local rownames "`returnedrownames'"
	return local coeflabels `"`coeflabels'"'
	return local plotcommand `"`plotcommand_text'"'
	return local measure "`measure'"
	return local xtitle "`xtitle'"
	return local graphnote `"`graphnote'"'
	return local sortmode "`sortmode'"
	return local tablemode "`tablemode'"
	return local headings `"`returnedheadings'"'
end
