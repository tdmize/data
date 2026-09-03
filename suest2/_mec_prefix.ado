*! _mec_prefix v1.0.0 Trenton Mize 2026-08-18  | history: CHANGELOG-suest2.md (repo)

*v1.3.4: read the coefficient prefixes off the margins object.
*
*	meinequality addressed coefficients through a rule: ordinary families get
*	N._predict#, specialized ones get <store>:. The rule came from mecompare,
*	where it is correct -- and mecompare calls -margins, at(...)- bare.
*	This command passes suest2 e(marginsdefault), which is predict(model())
*	per model, and that changes the layout. Measured 17aug2026: the same
*	term resolves after a bare margins call and not after this one.
*
*	So the prefixes are taken from e(b) itself. Nothing is inferred:
*	  r(eq1), r(eq2)   the two equation names, empty when margins posts none
*	  r(npre)          how many distinct N._predict values there are
*	  r(restart)       1 if model 2 numbers its outcomes from 1 again
*
*	A rule can be wrong about a layout. A read cannot.
capture program drop _mec_prefix
program define _mec_prefix, rclass
	version 16
	syntax , FOCal(name) NCat(integer)
	return local eq1 ""
	return local eq2 ""
	return scalar npre = 0
	return scalar restart = 0
	capture confirm matrix e(b)
	if _rc  exit
	local cn : colnames e(b)
	local eq : coleq   e(b)
	local k  : word count `cn'

*	distinct equation names, in order of appearance. margins posts "_" when
*		there is no equation, which is not a name.
	local eqs ""
	forvalues j = 1/`k' {
		local e : word `j' of `eq'
		if "`e'" == "_" | "`e'" == ""  continue
		local seen : list e in eqs
		if !`seen'  local eqs "`eqs' `e'"
		}
	local neq : word count `eqs'
	if `neq' >= 1  return local eq1 : word 1 of `eqs'
	if `neq' >= 2  return local eq2 : word 2 of `eqs'

*	distinct N._predict prefixes, counted over the whole object
	local pres ""
	forvalues j = 1/`k' {
		local c : word `j' of `cn'
		local p = strpos("`c'", "._predict")
		if `p' == 0  continue
		local head = substr("`c'", 1, `p' - 1)
		local seen : list head in pres
		if !`seen'  local pres "`pres' `head'"
		}
	local npre : word count `pres'
	return scalar npre = `npre'

*	model 2 restarts when the outcome numbering does not run to 2k. With two
*		equations it always restarts; with one equation and 2k prefixes it
*		continues. Both are read, not assumed.
	if `neq' >= 2                       return scalar restart = 1
	else if `npre' > 0 & `npre' <= `ncat'  return scalar restart = 1
end
