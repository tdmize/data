*! metest v0.3.1 Trenton Mize 2026-09-01  | history: CHANGELOG-mecompare.md (repo)
* Tests and combines estimates by their number in the table, or by name.
* A number is the n-th non-omitted column of e(b) -- the ME # after mecompare,
* but well defined after any e-class command. Expressions without "=" go to
* nlcom (+ - * / and nonlinear functions); with "=" they go to test (chained
* and multiple equalities). A literal number is written with a leading #.
* Number-to-coefficient mapping and the result table adapted from SPost13
* mlincom. Replaces melincom.

capture program drop metest
program define metest, rclass

	version 16
	tempname newmat b rb rV

*Gather the expression up to the first comma (= is kept in the expression)
*	bind keeps a parenthesised group whole, so a comma inside min(1,2) does
*	not read as the start of the options
	gettoken token 0 : 0, parse(",= ") bind
	while `"`token'"' != "" & `"`token'"' != "," {
		local expression `"`expression'`token'"'
		gettoken token 0 : 0, parse(",= ") bind
		}
*	bind returns a parenthesised group WITH its spaces, so (1 - 2) would
*	reach r(expression) spaced where it never was before. The decoder
*	re-spaces the operators itself and no coefficient name contains a
*	space, so stripping them keeps the macro exactly as it has always been
	local expression = subinstr(`"`expression'"'," ","",.)

	if `"`0'"' != "" {
		local 0 `",`0'"'
		syntax [, ///
			STATS(string asis) STATistics(string asis) ALLstats ///
			Details NOTABle ///
			clear add save ///
			ROWName(string) label(string) ///
			DECimals(integer 3) WIDth(integer 9) title(string) ///
			LABWidth(integer 0) TWIDth(integer 0) Level(cilevel) ///
			]
		}
	else {
		local decimals 3
		local width 9
		local level = c(level)
		}
*	With no options the syntax block never runs, so twidth is undefined --
*	and an empty macro is not "0". Normalise it here.
	if "`twidth'" == ""   local twidth 0
	if "`labwidth'" == "" local labwidth 0
	if `labwidth' > 0     local twidth = `labwidth'

	if "`label'" == ""  local label `"`rowname'"'		// synonyms
	if "`save'" == "save"  local add "add"				// synonyms
	if "`details'" == "details"  local quietly ""
	else                         local quietly "quietly"
	if "`notable'" == "notable"  local quietly ""
	if "`stats'" != "" & "`statistics'" == ""  local statistics `"`stats'"'
*labwidth() is the documented name; twidth() is kept as a synonym. 32 is the
*	maximum: Stata REJECTS a matrix row name longer than 32 characters, so a
*	wider column would add blank space rather than more text.
	if `labwidth' > 32 | `twidth' > 32 {
		display as error "{opt labwidth()} may be at most 32."
		exit 198
		}
	if `labwidth' > 0     local twidth = `labwidth'

	local matrix  _metest			// estimate rows (nlcom)
	local matrixt _metest_test		// equality-test rows (test)

*-----------------------------------------------------------------------------
* No expression: clear the saved table, or redisplay it
*-----------------------------------------------------------------------------
	if trim(`"`expression'"') == "" {
		if "`clear'" == "clear" {
			capture matrix drop `matrix'
			capture matrix drop `matrixt'
			exit
			}
		capture confirm matrix `matrix'
		local haveest = (_rc == 0)
		capture confirm matrix `matrixt'
		local havetst = (_rc == 0)
		if `haveest' == 0 & `havetst' == 0 {
			display as error "{cmd:metest} requires an expression. Refer " /*
			*/ "to an estimate by its number in the table or by its " /*
			*/ "coefficient name, e.g. {cmd:metest 1 - 2} or " /*
			*/ "{cmd:metest _b[age:m1] - _b[age:m2]}. There is no saved " /*
			*/ "table to redisplay; use {cmd:metest, clear} to clear one."
			exit 198
			}
		if "`notable'" == "" {
			_metest_show `matrix', decimals(`decimals') width(`width') /*
			*/ twidth(`twidth') title(`"`title'"')
			local ttitle `"`title'"'
			if `"`title'"' == ""  local ttitle "Tests of equality"
			_metest_show `matrixt', decimals(`decimals') width(`width') /*
			*/ twidth(`twidth') title(`"`ttitle'"')
			}
		exit
		}

*	clear is an option, not an expression
	if trim(`"`expression'"') == "clear" {
		display as error "{cmd:clear} is an option, not an expression. " /*
		*/ "Type {cmd:metest, clear} to clear the saved table."
		exit 198
		}

	if "`clear'" == "clear" {
		capture matrix drop `matrix'
		capture matrix drop `matrixt'
		}

*-----------------------------------------------------------------------------
* Estimates in memory + the ME # -> coefficient map
*-----------------------------------------------------------------------------
	capture confirm matrix e(b)
	if _rc > 0 {
		display as error "{cmd:metest} must be run after an estimation " /*
		*/ "command that leaves {cmd:e(b)} -- normally {cmd:mecompare}. " /*
		*/ "There are no estimation results in memory."
		exit 301
		}
*	A number is the n-th non-omitted column of e(b); only the wording of the
*	messages depends on which command produced the estimates.
	local ismec = ("`e(cmd)'" == "mecompare")
	if `ismec' {
		local whatnum "marginal effect"
		local whatsrc "the last {cmd:mecompare} table"
		local whatcol "the {it:ME #} column"
		local whatleg "{cmd:mecompare, coeflegend}"
		}
	else {
		local whatnum "coefficient"
		local whatsrc "the estimates in memory (from {bf:`e(cmd)'})"
		local whatcol "the coefficient list"
		local whatleg "{cmd:matrix list e(b)}"
		}

	matrix `b' = e(b)
	local orignms : colfullnames `b'
	local menames ""				// ME # n  ->  word n of menames
	foreach var of local orignms {
		_ms_parse_parts `var'
		if (!`r(omit)')  local menames `menames' `var'
		}
	local nme : word count `menames'

*-----------------------------------------------------------------------------
* Decode the expression
*-----------------------------------------------------------------------------
	local lc `"`expression'"'
	foreach c in ( ) + - * / = {
		local lc = subinstr(`"`lc'"',"`c'"," `c' ",.)
		}
*	Separately: a comma cannot go in a foreach list
	local lc = subinstr(`"`lc'"',","," , ",.)

	local lcstr ""			// expression handed to nlcom / test
	local lbltoks ""		// tokens (operators + names) for the row label
	local iseq = 0			// does it contain an equality?
	local neq = 0			// number of ME terms
	local eqlist ""			// equation part of each term, to compact the label
	local colist ""			// coefficient part of each term
	local ncolon = 0		// terms that carry an equation

	local nfn = 0			// function names seen
	local ntok : word count `lc'
	forvalues t = 1/`ntok' {
		local e : word `t' of `lc'
		local tn = `t' + 1
		local nxt ""
		if `tn' <= `ntok'  local nxt : word `tn' of `lc'

		if inlist(`"`e'"',"(",")","+","-","*","/",",") {
			local lcstr  `"`lcstr'`e'"'
			local lbltoks `"`lbltoks' `e'"'
			}
		else if `"`e'"' == "=" {
			local iseq = 1
			local lcstr   `"`lcstr' = "'
			local lbltoks `"`lbltoks' ="'
			}
*		A name followed by ( is a function; nlcom decides whether it exists
		else if `"`nxt'"' == "(" {
			local lcstr  `"`lcstr'`e'"'
			local lbltoks `"`lbltoks' `e'"'
			local ++nfn
			}
		else {
*			#2 is the literal two; a bare integer is the ME #; a number that is
*			not whole cannot be an ME # so it is always a literal.
			local isconst = 0
			local ctok `"`e'"'
			if substr(`"`e'"',1,1) == "#" {
				local ctok = substr(`"`e'"',2,.)
				capture confirm number `ctok'
				if _rc != 0 {
					display as error "{bf:`e'} is not a number. The " /*
					*/ "{bf:#} prefix marks a literal value, e.g. " /*
					*/ "{cmd:#2} for the number two."
					exit 198
					}
				local isconst = 1
				}
			else {
				capture confirm number `e'
				if _rc == 0 & real(`"`e'"') != int(real(`"`e'"'))  local isconst = 1
				}

			if `isconst' == 1 {
				local lcstr   `"`lcstr'`ctok'"'
				local lbltoks `"`lbltoks' `ctok'"'
				continue
				}

			capture confirm number `e'
			if _rc == 0 {
				local i = int(real("`e'"))
				if `i' < 1 | `i' > `nme' {
					display as error "There is no `whatnum' numbered " /*
					*/ "{bf:`e'} in `whatsrc', which has `nme'. Use a " /*
					*/ "number from `whatcol', a coefficient name, or " /*
					*/ "{bf:#`e'} for the literal number `e'."
					exit 198
					}
				local bnm : word `i' of `menames'
				}
			else {
*				Otherwise a coefficient name, with or without _b[ ]
				local bnm = subinstr(`"`e'"',"_b[","",.)
				local bnm = subinstr(`"`bnm'"',"]","",.)
				local okname = 0
				foreach mn of local menames {
					if "`mn'" == "`bnm'"  local okname = 1
					}
				if `okname' == 0 {
					display as error "{bf:`e'} is neither a `whatnum' " /*
					*/ "number nor a coefficient name in `whatsrc'. Type " /*
					*/ "`whatleg' to list the names."
					exit 198
					}
				}
			local lcstr   `"`lcstr'_b[`bnm']"'
			local lbltoks `"`lbltoks' `bnm'"'
			local ++neq
			local eqp = ""
			local cop = "`bnm'"
			if strpos("`bnm'",":") > 0 {
				local eqp = substr("`bnm'",1,strpos("`bnm'",":")-1)
				local cop = substr("`bnm'",strpos("`bnm'",":")+1,.)
				local ++ncolon
				}
			local eqlist `"`eqlist' `eqp'"'
			local colist `"`colist' `cop'"'
			}
		}

*-----------------------------------------------------------------------------
* Default row label: the expression with names substituted for ME #s. Whatever
*	every term shares -- the variable if they come from one variable, else the
*	model -- is factored out and heads its own row. Fall back to the expression
*	as typed when the result will not fit a matrix row name.
*-----------------------------------------------------------------------------
	if `"`label'"' == "" {
*		Every term must carry an equation before either side can be factored.
		local sameeq = (`ncolon' == `neq' & `neq' > 0)
		local eq1 : word 1 of `eqlist'
		foreach eqp of local eqlist {
			if "`eqp'" != "`eq1'"  local sameeq = 0
			}
		if "`eq1'" == ""  local sameeq = 0
		local sameco = (`ncolon' == `neq' & `neq' > 0 & `sameeq' == 0)
		local co1 : word 1 of `colist'
		foreach cop of local colist {
			if "`cop'" != "`co1'"  local sameco = 0
			}
		if "`co1'" == ""  local sameco = 0
		local head ""
		if `sameeq'       local head `"`eq1'"'
		else if `sameco'  local head `"`co1'"'

*		Build the label at abbreviation level `k' and shorten the NAMES until
*		it fits, so the shape of the test always survives.
		local k = 0
		local fits = 0
		while `fits' == 0 {
			local body ""
			local nlb : word count `lbltoks'
			forvalues q = 1/`nlb' {
				local t : word `q' of `lbltoks'
				local qn = `q' + 1
				local tnx ""
				if `qn' <= `nlb'  local tnx : word `qn' of `lbltoks'
*				Parentheses and commas bind tight: abs(x), min(a,b), (a - b)
				if inlist(`"`t'"',"(",")",",") {
					local body `"`body'`t'"'
					}
				else if inlist(`"`t'"',"+","-","*","/","=") {
					local body `"`body' `t' "'
					}
*				A function name is not a coefficient: no abbrev, no eq strip
				else if `"`tnx'"' == "(" {
					local body `"`body'`t'"'
					}
				else {
					local nm `"`t'"'
					if `sameeq'       local nm = subinstr(`"`nm'"',"`eq1':","",1)
					else if `sameco'  local nm = subinstr(`"`nm'"',":`co1'","",1)
					else              local nm = subinstr(`"`nm'"',":","_",.)
					if `k' > 0        local nm = abbrev(`"`nm'"',`k')
					local body `"`body'`nm'"'
					}
				}
			local body = trim(itrim(`"`body'"'))
			if length(`"`body'"') <= 32 | `k' == 4   local fits = 1
			else if `k' == 0                         local k = 16
			else                                     local k = `k' - 2
			}
*		Still too long: the expression as typed, which is short and exact.
		if length(`"`body'"') > 32  local body = trim(itrim(`"`expression'"'))
		if length(`"`body'"') > 32  local body ""
		if `"`head'"' != "" & `"`body'"' != ""  local label `"`head':`body'"'
		else                                   local label `"`body'"'
		}

*-----------------------------------------------------------------------------
* Run it: test for equalities, nlcom otherwise
*-----------------------------------------------------------------------------
	if `iseq' == 1 & `nfn' > 0 {
		display as error "an expression with {cmd:=} is passed to " /*
		*/ "{help test}, which tests linear combinations and cannot " /*
		*/ "evaluate a function. Drop the {cmd:=} to have {help nlcom} " /*
		*/ "estimate the quantity instead."
		exit 198
		}

	if `iseq' == 1 {
		`quietly' test `lcstr'
		if "`r(chi2)'" != "" {
			local tstat = r(chi2)
			local teststat "chi2"
			}
		else {
			local tstat = r(F)
			local teststat "F"
			}
		local tdf = r(df)
		local tp  = r(p)

		return scalar `teststat' = `tstat'
		return scalar df    = `tdf'
		return scalar pvalue = `tp'

		matrix `newmat' = (`tstat', `tdf', `tp')
		matrix colnames `newmat' = `teststat' df pvalue
		local usematrix "`matrixt'"
		}
	else {
		`quietly' nlcom (`lcstr')
		matrix `rb' = r(b)
		matrix `rV' = r(V)
		local est = `rb'[1,1]
		local se  = sqrt(`rV'[1,1])
		local z   = `est' / `se'
		local p   = 2*normal(-abs(`z'))
		local cv  = invnormal(1 - (1 - `level'/100)/2)
		local ll  = `est' - `cv'*`se'
		local ul  = `est' + `cv'*`se'

		return scalar estimate = `est'
		return scalar se       = `se'
		return scalar zvalue   = `z'
		return scalar pvalue   = `p'
		return scalar ll       = `ll'
		return scalar ul       = `ul'

*		Which statistics to show. Resolve synonyms and "all" in ONE pass,
*		then build the row, so the requested order is preserved.
		local want `"`statistics'"'
		if "`allstats'" == "allstats"  local want "all"
		if `"`want'"' == ""            local want "estimate se pvalue"
		local slist ""
		foreach s of local want {
			local s = lower("`s'")
			if      inlist("`s'","est","estimate","coef","b")  local slist "`slist' estimate"
			else if inlist("`s'","se","stderr")                local slist "`slist' se"
			else if inlist("`s'","z","zvalue")                 local slist "`slist' zvalue"
			else if inlist("`s'","p","pvalue")                 local slist "`slist' pvalue"
			else if inlist("`s'","ll","lb")                    local slist "`slist' ll"
			else if inlist("`s'","ul","ub")                    local slist "`slist' ul"
			else if "`s'" == "all"  local slist "estimate se zvalue pvalue ll ul"
			else {
				display as error "invalid statistic specified: {bf:`s'}. " /*
				*/ "Valid statistics are {opt estimate}, {opt se}, " /*
				*/ "{opt zvalue}, {opt pvalue}, {opt ll}, {opt ul}, or " /*
				*/ "{opt all}."
				exit 198
				}
			}
		local colnms ""
		foreach s of local slist {
			if      "`s'" == "estimate"  local sv = `est'
			else if "`s'" == "se"        local sv = `se'
			else if "`s'" == "zvalue"    local sv = `z'
			else if "`s'" == "pvalue"    local sv = `p'
			else if "`s'" == "ll"        local sv = `ll'
			else if "`s'" == "ul"        local sv = `ul'
			matrix `newmat' = nullmat(`newmat'), `sv'
			local colnms "`colnms' `s'"
			}
		local colnms = trim(itrim(`"`colnms'"'))
		matrix colnames `newmat' = `colnms'
		local usematrix "`matrix'"
		}

*-----------------------------------------------------------------------------
* Row number: continuous across BOTH tables, so row 3 is always row 3
*-----------------------------------------------------------------------------
	local nrows = 0
	capture confirm matrix `matrix'
	if _rc == 0  local nrows = `nrows' + rowsof(`matrix')
	capture confirm matrix `matrixt'
	if _rc == 0  local nrows = `nrows' + rowsof(`matrixt')
	local n = `nrows' + 1
	if `"`label'"' == ""  local label "`n'"
*	Stata parses matrix row names, and a label built from factor-variable
*	names (1.collgrad) is rejected once other tokens are present. Try the
*	descriptive label, then a sanitised form, then the row number.
	capture matrix rowname `newmat' = `"`label'"'
	if _rc != 0 {
		local labsafe = subinstr(`"`label'"',".","_",.)
		capture matrix rowname `newmat' = `"`labsafe'"'
		if _rc == 0  local label `"`labsafe'"'
		else {
			matrix rowname `newmat' = "`n'"
			local label "`n'"
			}
		}

*	chi2 and F results cannot share one accumulated table.
	if `iseq' == 1 & "`add'" == "add" {
		capture confirm matrix `matrixt'
		if _rc == 0 {
			local prevc : colnames `matrixt'
			local prev1 : word 1 of `prevc'
			if "`prev1'" != "`teststat'" {
				display as error "the saved test table reports " /*
				*/ "{bf:`prev1'} but this test reports {bf:`teststat'}. " /*
				*/ "Run {cmd:metest, clear} first."
				exit 198
				}
			}
		}

*	Column sets that differ cannot be stacked.
	if `iseq' == 0 & "`add'" == "add" {
		capture confirm matrix `matrix'
		if _rc == 0 {
			local prevs : colnames `matrix'
			if "`prevs'" != "`colnms'" {
				display as error "the saved table reports {bf:`prevs'} but " /*
				*/ "this call reports {bf:`colnms'}. Ask for the same " /*
				*/ "{opt statistics()}, or run {cmd:metest, clear} first."
				exit 198
				}
			}
		}

	capture confirm matrix `usematrix'
	if _rc == 0 & "`add'" == "add"  matrix `usematrix' = `usematrix' \ `newmat'
	else {
		if "`add'" != "add" {
			capture matrix drop `matrix'
			capture matrix drop `matrixt'
			}
		matrix `usematrix' = `newmat'
		}

	if "`notable'" == "" {
		_metest_show `matrix', decimals(`decimals') width(`width') /*
		*/ twidth(`twidth') title(`"`title'"')
		local ttitle `"`title'"'
		if `"`title'"' == ""  local ttitle "Tests of equality"
		_metest_show `matrixt', decimals(`decimals') width(`width') /*
		*/ twidth(`twidth') title(`"`ttitle'"')
		}

*	Do not leak the last capture's return code to the caller.
	capture error 0

	return local expression `"`expression'"'
	return local label      `"`label'"'

end

* Displays one saved table, sized so it stays inside an 80-column line.
capture program drop _metest_show
program define _metest_show

	version 16
	syntax anything(name=mat) [, DECimals(integer 3) WIDth(integer 9) /*
		*/ TWidth(integer 0) title(string) ]

	capture confirm matrix `mat'
	local ok = (_rc == 0)
	capture error 0
	if `ok' == 0  exit

*	A user-supplied width always wins and may be any width.
	local tw = `twidth'
	if `tw' == 0 {
		local tw = 70 - colsof(`mat')*(`width'+1)
		if `tw' > 32  local tw = 32
		if `tw' < 12  local tw = 12
		}

	matlist `mat', format(%`width'.`decimals'f) title(`"`title'"') twidth(`tw')

end

exit
