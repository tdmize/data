*! mec_share v1.3.0 Trenton Mize 2026-08-20  | history: CHANGELOG-suest2.md (repo)

*Shared by mecompare, meinequality and totalme -- one implementation, so the
*	three cannot drift apart on how level shares are computed.

capture program drop mec_share
program define mec_share, rclass
*The share of one level of a nominal variable over the given sample.
*	Equivalent to -proportion-: the weighted proportion sum(w*I)/sum(w) is
*	exactly the aweighted mean of the level indicator, which is also the point
*	estimate -svy: proportion- reports. Unlike either, this works under mi --
*	where svy: proportion is REFUSED outright (r 119) and
*	mi estimate: svy: proportion returns a missing e(b) -- and it pools across
*	imputations. Only point estimates are needed: mecompare uses the shares as
*	constants in the nlcom weights, never as estimated quantities, so no
*	design-based variance is required.
	version 16.0
	*v1.1.0: -mec_share ebvars- routes to _mec_ebvars (below) and returns
	*	s(vars). This is the ONLY supported entry from outside this file:
	*	probe_msh110 run 1 (04aug2026) measured that a subsidiary of an
	*	autoloaded ado-file is NOT callable externally -- direct _mec_ebvars
	*	was r(199) one command after the dispatch ran it successfully.
	*	Being rclass, this entry clears r(); grab s(vars) immediately.
	if `"`1'"' == "ebvars" {
		_mec_ebvars
		exit
		}
	syntax varname [if] [in], Level(string) [ MI(integer 0) WSpec(string) ]
	marksample touse, novarlist
	tempvar ind

	if `mi' == 0 {
		qui gen byte `ind' = (`varlist' == `level') if `touse'
		qui summarize `ind' if `touse' `wspec'
		return scalar share = r(mean)
		return scalar N     = r(N)
		exit
		}

	local mistyle "`_dta[_mi_style]'"
	local M       "`_dta[_mi_M]'"
	if "`M'" == "" | "`M'" == "0" {
		qui gen byte `ind' = (`varlist' == `level') if `touse'
		qui summarize `ind' if `touse' `wspec'
		return scalar share = r(mean)
		return scalar N     = r(N)
		exit
		}

	tempname ssum nsum
	scalar `ssum' = 0
	scalar `nsum' = 0
	local nused = 0
	forvalues mm = 1/`M' {
		capture drop `ind'
		if "`mistyle'" == "wide" {
			capture confirm variable _`mm'_`varlist'
			if _rc == 0  local vv "_`mm'_`varlist'"
			else         local vv "`varlist'"
			qui gen byte `ind' = (`vv' == `level') if `touse'
			qui summarize `ind' if `touse' `wspec'
			}
		else {
			qui gen byte `ind' = (`varlist' == `level') /*
				*/ if _mi_m == `mm' & `touse'
			qui summarize `ind' if _mi_m == `mm' & `touse' `wspec'
			}
		if r(N) > 0 {
			local ++nused
			scalar `ssum' = `ssum' + r(mean)
			scalar `nsum' = `nsum' + r(N)
			}
		}
	if `nused' == 0 {
		return scalar share = .
		return scalar N     = 0
		exit
		}
	return scalar share = `ssum' / `nused'
	return scalar N     = `nsum' / `nused'
end

*****************
// _mec_ebvars //
*****************

capture program drop _mec_ebvars
program define _mec_ebvars, sclass
*The predictor list of the model in e(), read from the e(b) stripe rather
*	than positionally from e(cmdline). Ported 04aug2026 from
*	suest2_margins_ebvars (suest2_margins.ado candidate 19, which stays
*	untouched) with ONE addition, the equation rule marked below. Measured
*	basis: diag_ebvars_parityB4.log; probes MSH110 (v1.1.0 bare list)
*	and MSH120 (v1.2.0, adds s(fvvars), the factor-dialect list).
*	External callers must use -mec_share ebvars-; direct calls are only
*	valid from inside this file (measured, probe_msh110 run 1).
	version 16.0

	sreturn clear
	local cn : colnames e(b)
	local ce : coleq e(b)
	local k : word count `cn'
	*v1.3.0: the outcome-equation limit. Empty for every family except the
	*	two that carry a reduced form, so nothing else changes. The first
	*	SUBSTANTIVE equation is the structural one for both (measured:
	*	ivprobit d d d xe xe xe / / ; ivtobit y_t y_t y_t xe xe xe / / /).
	*	The endogenous regressor stays -- it IS in the structural
	*	equation. Only the instrument goes.
	local eqlim
	if inlist("`e(cmd)'","ivprobit","ivtobit") {
		forvalues i = 1/`k' {
			local eqx : word `i' of `ce'
			if substr(`"`eqx'"', 1, 1) == "/" continue
			if strpos(`"`eqx'"', "(") | strpos(`"`eqx'"', "[") continue
			local eqlim `"`eqx'"'
			continue, break
			}
		}
	local vars
	forvalues i = 1/`k' {
		*The v1.1.0 addition: skip ancillary and variance EQUATIONS. Bare "/"
		*	carries bare-word colnames (streg ln_p, heckman athrho lnsigma)
		*	that the token rules below cannot catch; "/name" and paren or
		*	bracket equation names are the same species elsewhere.
		local eq : word `i' of `ce'
		if substr(`"`eq'"', 1, 1) == "/" continue
		if strpos(`"`eq'"', "(") | strpos(`"`eq'"', "[") continue
		if `"`eqlim'"' != "" & `"`eq'"' != `"`eqlim'"' continue
		*From here identical to suest2_margins_ebvars.
		local tk : word `i' of `cn'
		if strpos(`"`tk'"', "(") | strpos(`"`tk'"', "[") continue
		local parts = subinstr(`"`tk'"', "#", " ", .)
		foreach pt of local parts {
			local nm `"`pt'"'
			local d = strpos(`"`nm'"', ".")
			while `d' {
				local nm = substr(`"`nm'"', `d' + 1, .)
				local d = strpos(`"`nm'"', ".")
			}
			if `"`nm'"' != "_cons" & `"`nm'"' != "" local vars `vars' `nm'
		}
	}
	local vars : list uniq vars

	*v1.2.0 second pass: s(fvvars), the token dialect mecompare's downstream
	*	expects -- _mec_annotate finds factor variables by an i-prefixed
	*	token in the model-IV list, and the ME code reads factor-ness off
	*	the token itself, so bare names would silently demote factors to
	*	continuous. For each bare name, scan the kept columns for numeric
	*	level parts (1b.x, 2.x, 3o.x): any hit makes it a factor; a
	*	b-marked level fixes the base -> ib<base>.name; levels but no b
	*	marker -> ibn.name; no hit -> the bare (continuous) name.
	local fvvars
	foreach vname of local vars {
		local isfac 0
		local vbase
		forvalues i = 1/`k' {
			local eq : word `i' of `ce'
			if substr(`"`eq'"', 1, 1) == "/" continue
			if strpos(`"`eq'"', "(") | strpos(`"`eq'"', "[") continue
			if `"`eqlim'"' != "" & `"`eq'"' != `"`eqlim'"' continue
			local tk : word `i' of `cn'
			if strpos(`"`tk'"', "(") | strpos(`"`tk'"', "[") continue
			local parts = subinstr(`"`tk'"', "#", " ", .)
			foreach pt of local parts {
				local d = strpos(`"`pt'"', ".")
				if `d' == 0 continue
				local head = substr(`"`pt'"', 1, `d' - 1)
				local tail = substr(`"`pt'"', `d' + 1, .)
				if `"`tail'"' == `"`vname'"' & regexm(`"`head'"', "^[0-9]+[bo]*$") {
					local isfac 1
					if strpos(`"`head'"', "b") local vbase = regexr(`"`head'"', "[bo]+$", "")
				}
			}
		}
		if `isfac' & `"`vbase'"' != "" local fvvars `fvvars' ib`vbase'.`vname'
		else if `isfac' local fvvars `fvvars' ibn.`vname'
		else local fvvars `fvvars' `vname'
	}
	sreturn local vars `"`vars'"'
	sreturn local fvvars `"`fvvars'"'
end
