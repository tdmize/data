*! version 1.0.0  19nov2026  | history: CHANGELOG-suest2.md (repo)
* svy runs this for suest2 on replicate-weight survey models: every model refit with the weight svy gives
program define suest2_svyrep, eclass properties(svyb svyj)
    version 16
    syntax [varlist(default=none)] [if] [in] [pweight iweight] [, *]
    marksample touse, novarlist zeroweight
    local wgt
    if `"`exp'"' != ""  local wgt `"[iw`exp']"'
    tempname b
    tempvar uu
    quietly generate byte `uu' = 0
    forvalues i = 1/$S2REP_N {
        local c `"${S2REP_CMD`i'}"'
        local o `"${S2REP_OPT`i'}"'
        if `"`o'"' != ""  local o `", `o'"'
        capture quietly `c' `wgt' if `touse' & ${S2REP_SMK`i'} `o'
        local rc = _rc
        if !`rc'  local rc = colsof(e(b)) != ${S2REP_K`i'}
        if `rc'  exit 498
        matrix `b' = nullmat(`b'), e(b)
        quietly replace `uu' = 1 if e(sample)
    }
    local st
    forvalues j = 1/`=colsof(`b')' {
        local st `st' p`j':_cons
    }
    matrix colnames `b' = `st'
    quietly replace `uu' = 0 if !`touse'
    quietly count if `uu'
    local N = r(N)
    ereturn post `b', esample(`uu') obs(`N')
    ereturn local cmd "suest2_svyrep"
end
