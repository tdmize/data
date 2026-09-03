*! version 0.1.73  30jul2026  | history: CHANGELOG-suest2.md (repo)
program define suest2_xtregmle_p
    version 16
    syntax anything(name=spec) [if] [in], SCORE
    marksample touse, novarlist

    gettoken first rest : spec
    if inlist("`first'","byte","int","long","float","double") {
        local type "`first'"
        local target `"`rest'"'
    }
    else {
        local type "double"
        local target `"`spec'"'
    }

    local sources `"`e(suest2_xtml_scores)'"'
    local k : word count `sources'
    if substr(`"`target'"',-1,1)=="*" {
        local stub=substr(`"`target'"',1,strlen(`"`target'"')-1)
        forvalues j=1/`k' {
            local src : word `j' of `sources'
            quietly generate `type' `stub'`j'=`src' if `touse'
        }
    }
    else {
        local ntarget : word count `target'
        if `ntarget'!=`k' {
            di as err "score prediction requires `k' new variables"
            exit 102
        }
        forvalues j=1/`k' {
            local src : word `j' of `sources'
            local dst : word `j' of `target'
            quietly generate `type' `dst'=`src' if `touse'
        }
    }
end
