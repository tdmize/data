*! version 0.1.59  26jul2026  | history: CHANGELOG-suest2.md (repo)
program define suest2_mi, sortpreserve eclass
    version 16

    local raw `"`0'"'
    syntax [anything(name=models id="parenthesized model specifications")] [, SOURCEESTIMATES(string asis) *]

    local names
    local nspec 0

    if trim(`"`sourceestimates'"') != "" {
        if trim(`"`models'"') != "" {
            di as err "do not combine parenthesized specifications with sourceestimates()"
            exit 198
        }
        local sourcenames : list uniq sourceestimates
        local nsource : word count `sourcenames'
        if !`nsource' {
            di as err "sourceestimates() contains no stored-estimate names"
            exit 198
        }
        foreach name of local sourcenames {
            capture confirm name `name'
            if _rc {
                di as err "{bf:`name'} is not a valid stored-estimate name"
                exit 198
            }
            capture quietly estimates restore `name'
            if _rc {
                di as err "unable to restore MI source estimate {bf:`name'}"
                exit _rc
            }

            local cmdline
            local micmdline `"`e(cmdline_mi)'"'
            if trim(`"`micmdline'"') != "" {
                local colon = strpos(`"`micmdline'"', ":")
                if `colon' local cmdline = trim(substr(`"`micmdline'"', `colon' + 1, .))
            }
            if trim(`"`cmdline'"') == "" local cmdline `"`e(cmdline)'"'
            if trim(`"`cmdline'"') == "" {
                di as err "model {bf:`name'} does not retain a reusable estimation command"
                exit 498
            }

            local ++nspec
            local name`nspec' `"`name'"'
            local cmdline`nspec' `"`cmdline'"'
            local names `"`names' `name'"'
        }
    }
    else {
        local rest `"`models'"'
        while trim(`"`rest'"') != "" {
            local paren
            gettoken spec rest : rest, match(paren)
            if `"`paren'"' != "(" {
                di as err "invalid suest2_mi model specification"
                di as err "enclose each labeled command in parentheses"
                di as err "example: {bf:(m1: regress y x1 x2) (m2: logit y2 x1 x2)}"
                exit 198
            }

            local spec = trim(`"`spec'"')
            local colon = strpos(`"`spec'"', ":")
            if !`colon' {
                di as err "model specification {bf:(`spec')} has no model label"
                di as err "use {bf:(name: estimation command)}"
                exit 198
            }

            local name = trim(substr(`"`spec'"', 1, `colon' - 1))
            local cmdline = trim(substr(`"`spec'"', `colon' + 1, .))
            capture confirm name `name'
            if _rc {
                di as err "{bf:`name'} is not a valid stored-estimate name"
                exit 198
            }
            if `"`cmdline'"' == "" {
                di as err "model {bf:`name'} has no estimation command"
                exit 198
            }
            local duplicate : list posof "`name'" in names
            if `duplicate' {
                di as err "model label {bf:`name'} is repeated"
                exit 198
            }

            local ++nspec
            local name`nspec' `"`name'"'
            local cmdline`nspec' `"`cmdline'"'
            local names `"`names' `name'"'
        }
    }

    if !`nspec' {
        di as err "no constituent models specified"
        exit 198
    }

    // Preserve user estimates that happen to use the requested model labels.
    // The labeled estimates created below are temporary inputs to suest2; the
    // active system uses its own private constituent copies afterward.
    forvalues i = 1/`nspec' {
        local name `"`name`i''"'
        local had`i' 0
        capture quietly estimates restore `name'
        if !_rc {
            tempname backup`i'
            quietly estimates store `backup`i''
            local had`i' 1
        }
        capture quietly estimates drop `name'
    }

    local rc 0
    forvalues i = 1/`nspec' {
        local name `"`name`i''"'
        local cmdline `"`cmdline`i''"'
        capture quietly `cmdline'
        local rc = _rc
        if `rc' {
            di as err "estimation failed for model {bf:`name'}"
            di as err "command: {bf:`cmdline'}"
            continue, break
        }
        capture confirm matrix e(b)
        if _rc {
            local rc = 301
            di as err "command for model {bf:`name'} did not return e(b)"
            continue, break
        }
        capture quietly estimates store `name'
        local rc = _rc
        if `rc' {
            di as err "unable to store temporary model {bf:`name'}"
            continue, break
        }
    }

    tempname result
    local hasresult 0
    if !`rc' {
        local comma
        if trim(`"`options'"') != "" local comma ","
        capture quietly suest2 `names' `comma' `options'
        local rc = _rc
        if !`rc' {
            ereturn local suest2_mi_models `"`names'"'
            ereturn local suest2_mi_cmdline `"suest2_mi `raw'"'
            quietly estimates store `result'
            local hasresult 1
        }
    }

    // Remove temporary constituent labels and restore any preexisting user
    // estimates with those names before returning the stacked result.
    forvalues i = 1/`nspec' {
        local name `"`name`i''"'
        capture quietly estimates drop `name'
        if `had`i'' {
            capture quietly estimates restore `backup`i''
            if !_rc {
                capture quietly estimates store `name'
            }
            capture quietly estimates drop `backup`i''
        }
    }

    if `hasresult' {
        quietly estimates restore `result'
        capture quietly estimates drop `result'
    }

    if `rc' exit `rc'
end
