*! version 0.1.75  06aug2026  | history: CHANGELOG-suest2.md (repo)
program define suest2_cleanup, rclass
    version 16
    syntax [, FORCE]

    // Discover private estimates only through suest2 ownership metadata.
    // A name prefix alone is never evidence of ownership.
    local private
    local hadactive 0
    // hadentry records whether e() held anything AT ALL on entry, which is
    // not the same question as whether the active result could be stored.
    // Without the distinction, a failed store on a populated e() would be
    // indistinguishable from an empty e() and the exit path would clear
    // results the caller still had.
    local hadentry 0
    capture confirm matrix e(b)
    if !_rc {
        local hadentry 1
        local private `"`e(suest2_holds)'"'
        tempname active
        capture quietly estimates store `active'
        if !_rc local hadactive 1
    }

    quietly estimates dir
    local all `"`r(names)'"'
    foreach result of local all {
        capture quietly estimates restore `result'
        if !_rc {
            local owned 0
            capture confirm scalar e(suest2_private)
            if !_rc & e(suest2_private) == 1 local owned 1
            if `owned' local private `"`private' `result'"'
            if "`e(cmd)'" == "suest2" {
                local private `"`private' `e(suest2_holds)'"'
            }
        }
    }
    if `hadactive' {
        capture quietly estimates restore `active'
        capture quietly estimates drop `active'
    }
    else if !`hadentry' {
        // e() was EMPTY on entry and the loop above has since restored one
        // stored result after another. Put the entry state back rather than
        // leaving the last of them active.
        ereturn clear
    }
    local private : list uniq private
    local nest : word count `private'

    // Only variables explicitly marked as suest2-owned may be removed.
    // A name prefix alone is never evidence of ownership.
    local weightvars
    capture unab allvars : _all
    if !_rc {
        foreach var of local allvars {
            local owned : char `var'[suest2_owned]
            if `"`owned'"' == "1" local weightvars `"`weightvars' `var'"'
        }
    }
    local weightvars : list uniq weightvars
    local nvars : word count `weightvars'

    return scalar N = `nest' + `nvars'
    return scalar N_estimates = `nest'
    return scalar N_weightvars = `nvars'
    return local names `"`private'"'
    return local weightvars `"`weightvars'"'
    return scalar dropped = 0
    return scalar dropped_estimates = 0
    return scalar dropped_weightvars = 0

    if `nest' + `nvars' == 0 {
        di as txt "no private suest2 resources found"
        exit
    }

    if "`force'" == "" {
        if `nest' {
            di as txt "private suest2 estimates (`nest'):"
            foreach name of local private {
                di as txt "  `name'"
            }
        }
        if `nvars' {
            if `nest' di as txt ""
            di as txt "private suest2 composite-weight variables (`nvars'):"
            foreach var of local weightvars {
                di as txt "  `var'"
            }
        }
        di as txt ""
        di as txt "These resources support prediction and margins from active or stored suest2 results."
        di as txt "Specify {bf:suest2_cleanup, force} only when those results are no longer needed."
        exit
    }

    local dropped_est 0
    foreach name of local private {
        capture quietly estimates drop `name'
        if !_rc local ++dropped_est
    }

    local dropped_vars 0
    foreach var of local weightvars {
        capture drop `var'
        if !_rc local ++dropped_vars
    }

    return scalar dropped = `dropped_est' + `dropped_vars'
    return scalar dropped_estimates = `dropped_est'
    return scalar dropped_weightvars = `dropped_vars'
    di as txt "dropped `dropped_est' private estimate(s) and `dropped_vars' composite-weight variable(s)"
end
