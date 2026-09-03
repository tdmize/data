*! version 0.1.59  26jul2026  | history: CHANGELOG-suest2.md (repo)
program define suest2_marg_check, rclass
    version 16
    syntax [if] [in] [fw aw iw pw] [, MODEL(string) OUTcome(string) TOLerance(real 1e-7) *]

    if "`e(cmd)'" != "suest2" exit

    local names `"`e(names)'"'
    local nmodels = e(suest2_nmodels)
    if `"`model'"' == "" local model : word 1 of `names'

    capture confirm integer number `model'
    if !_rc local imodel = `model'
    else {
        local imodel 0
        forvalues i = 1/`nmodels' {
            local name : word `i' of `names'
            if `"`model'"' == `"`name'"' local imodel = `i'
        }
    }

    if !`imodel' {
        return scalar not_estimable = 1
        exit
    }

    local start = e(suest2_start`imodel')
    local korig = e(suest2_korig`imodel')
    local kblock = e(suest2_kblock`imodel')
    local kmain = e(suest2_kmain`imodel')
    local end = `start' + `kblock' - 1
    local cmd `"`e(suest2_cmd`imodel')'"'
    local outcomes `"`e(suest2_outcomes`imodel')'"'

    local alleq : coleq e(b)
    local blockeq
    forvalues j = `start'/`end' {
        local eqj : word `j' of `alleq'
        local blockeq `blockeq' `eqj'
    }
    local blockeq : list uniq blockeq
    local primary : word 1 of `blockeq'

    local bad 0
    local opts eclass fill0 ignoreomit allownotfound
    tempname H Lfull L LH

    // Ordered models use buildfvinfo ADDCONS natively.  Its H matrix contains
    // one synthetic implicit-constant column after the covariate equation and
    // before the cutpoints.  Preserve and use that constituent-native H.
    if inlist("`cmd'", "ologit", "oprobit") {
        if e(suest2_nativeHrc`imodel') {
            return scalar not_estimable = 1
            exit
        }

        capture quietly _ms_means b `if' `in' [`weight'`exp'], `opts' eq(`primary')
        if _rc {
            return scalar not_estimable = 1
            exit
        }

        matrix `Lfull' = r(means)
        matrix `L' = `Lfull'[1, `start'..`=`start'+`korig'-1']
        matrix `H' = e(suest2_H`imodel')

        if colsof(`H') == colsof(`L') + 1 {
            if `kmain' <= 0 {
                matrix `L' = 1, `L'
            }
            else if `kmain' >= colsof(`L') {
                matrix `L' = `L', 1
            }
            else {
                matrix `L' = `L'[1,1..`kmain'], 1, ///
                    `L'[1,`=`kmain'+1'..`=colsof(`L')']
            }
        }

        if colsof(`L') != colsof(`H') {
            return scalar not_estimable = 1
            exit
        }

        matrix `LH' = `L'*`H'
        return scalar not_estimable = (mreldif(`L', `LH') > `tolerance')
        exit
    }

    // The FE route already installs structural factor-variable information
    // using a full-rank reference VCE before restoring the exact singular FE
    // covariance.  Let that active H matrix handle genuine base and omitted
    // terms.  A second global _ms_means check is inappropriate here because a
    // correctly omitted time-invariant covariate appears in the full prediction
    // design and would falsely classify every otherwise estimable margin as
    // nonestimable.  Returning zero bypasses only that redundant global check.
    capture confirm scalar e(suest2_xtfe)
    if !_rc {
        if e(suest2_xtfe) {
            return scalar not_estimable = 0
            exit
        }
    }

    quietly _get_hmat `H'
    if r(rc) exit

    // Multinomial probabilities depend on every nonbase outcome equation.
    if "`cmd'" == "mlogit" {
        local nout : word count `outcomes'
        local basepos = e(suest2_ibaseout`imodel')

        forvalues q = 1/`nout' {
            if `q' == `basepos' continue
            local eqq : word `q' of `blockeq'

            capture quietly _ms_means b `if' `in' [`weight'`exp'], `opts' eq(`eqq')
            if _rc {
                local bad 1
                continue
            }

            matrix `L' = r(means)
            matrix `LH' = `L'*`H'
            if mreldif(`L', `LH') > `tolerance' local bad 1
        }
    }
    else {
        capture quietly _ms_means b `if' `in' [`weight'`exp'], `opts' eq(`primary')
        if _rc local bad 1
        else {
            matrix `L' = r(means)
            matrix `LH' = `L'*`H'
            if mreldif(`L', `LH') > `tolerance' local bad 1
        }
    }

    return scalar not_estimable = `bad'
end
