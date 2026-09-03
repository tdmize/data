*! version 1.0.0  30aug2026  | history: CHANGELOG-suest2.md (repo)
program define suest2, sortpreserve eclass
    version 16

    if replay() {
        if "`e(cmd)'" != "suest2" {
            di as err "estimation results for {bf:suest2} not found"
            exit 301
        }
        suest2_display `0'
        exit
    }

    // nowarn is suest2's own option and no route below knows it, so strip it
    local s2warn 1
    if regexm(`"`0'"', "(^|[ ,])nowarn([ ,]|$)") {
        local s2warn 0
        local 0 = regexr(`"`0'"', "(^|[ ,])nowarn([ ,]|$)", " ")
        // a trailing comma with nothing after it is not valid syntax
        local 0 = regexr(`"`0'"', ",[ ]*$", "")
    }

    // MI-pooled constituent results require a re-estimation within each imputation
    quietly suest2_miscan `0'
    if r(has_mi) {
        suest2_miestimate `0'
        exit
    }

    // Family presence: ivregress and the six specialized panel families are
    // scanned unconditionally because prediction metadata reads their flags
    // even when another route is dispatched.
    quietly suest2_routescan ivregress `0'
    local ivregress_path = r(has)
    local svyivregress_path = r(has_svyivregress)
    foreach r in xtmlogit xtnbregre xtpoissonregamma xtnbregfe xtpoissonfe xtfe {
        quietly suest2_routescan `r' `0'
        local `r'_path = r(has)
    }

    // The remaining families are probed only until one is found, and any
    // specialized-panel presence blocks all of them.
    local guarded xtbe xtcre xtre xtml xtpa mehetero mixed melogit meprobit ///
        mecloglog mepoisson menbreg meologit meoprobit
    foreach r of local guarded {
        local `r'_path 0
    }
    if !(`xtmlogit_path' | `xtnbregre_path' | `xtpoissonregamma_path' | ///
        `xtnbregfe_path' | `xtpoissonfe_path' | `xtfe_path') {
        foreach r of local guarded {
            if "`r'" == "mehetero" quietly suest2_meheteroscan `0'
            else quietly suest2_routescan `r' `0'
            local `r'_path = r(has)
            if r(has) continue, break
        }
    }

    // Dispatch: first present family wins, in this fixed precedence order;
    // systems matching none fall through to official suest below.
    local route ""
    foreach r in ivregress xtmlogit xtnbregre xtpoissonregamma xtnbregfe ///
        xtpoissonfe xtfe xtbe xtcre xtre xtml xtpa mehetero mixed melogit ///
        meprobit mecloglog mepoisson menbreg meologit meoprobit {
        if ``r'_path' {
            local route `r'
            continue, break
        }
    }

    local survey_path 0
    local pweight_path 0
    local routedisplay
    local pwdisplay
    local survey_subpop

    if "`route'" != "" {
        if "`route'" == "ivregress" & `svyivregress_path' ///
            suest2_ivregress_svyestimate `0'
        else suest2_`route'estimate `0'
        // Two bridges post display options under short historical e() names.
        local dispname `route'
        if "`route'" == "xtnbregre"             local dispname xnbr
        else if "`route'" == "xtpoissonregamma" local dispname xpgr
        local routedisplay `"`e(suest2_`dispname'_displayopts)'"'
        if "`route'" == "ivregress" {
            capture confirm scalar e(suest2_svy)
            if !_rc local survey_path = e(suest2_svy)
            capture local survey_subpop `"`e(subpop)'"'
        }
    }
    else {
        // Use official suest unchanged for ordinary systems
        quietly suest2_pwscan `0'
        local survey_path = r(has_svy) | r(requested_svy)
        local pweight_path = r(has_pweight) & !`survey_path'
        local pwdisplay `"`r(displayopts)'"'
        if `survey_path' {
            quietly suest2_svycheck `0'
            local survey_subpop `"`r(subpop)'"'
            suest `0'
        }
        else if `pweight_path' suest2_pwestimate `0'
        else {
            // suest refuses a constituent stored with a nonstandard vce even
            // though its own GetMat would use e(V_modelbased) -- the correct
            // bread -- so convert IN PLACE under the user's own estimate
            // names: suest derives its equation stripes from the names it is
            // given (suest.ado:629-638), and tempnames would break the
            // [m1_union]x crosswalks. The touched macros are restored on
            // every exit path below.
            local s2cm = strpos(`"`0'"', ",")
            if `s2cm' {
                local s2names = substr(`"`0'"', 1, `s2cm' - 1)
                local s2opt   = substr(`"`0'"', `s2cm' + 1, .)
            }
            else {
                local s2names `"`0'"'
                local s2opt ""
            }
            // nowarn was already removed from `0' at the entry point, so
            // `s2opt' cannot contain it. s2warn carries the decision.
            local s2nowarn = !`s2warn'

            quietly suest2_vcescan `s2names'
            local s2need  = r(needconv)
            local s2nonrb = r(nonrobust)
            local s2cvar  `"`r(clustvar)'"'
            local s2bad   `"`r(bad)'"'
            local s2why   `"`r(badwhy)'"'

            if `"`s2bad'"' != "" {
                di as err "{bf:suest2} cannot combine these results: `s2why'"
                if `"`s2bad'"' != "system" ///
                    di as err "first affected model: {bf:`s2bad'}"
                exit 322
            }

            if `s2need' {
                // Remember what each model carried, convert it, and put the
                // macros back below.  Only these three are touched.
                local s2k 0
                foreach nm of local s2names {
                    local ++s2k
                    quietly estimates restore `nm'
                    local s2ov`s2k' `"`e(vce)'"'
                    local s2ot`s2k' `"`e(vcetype)'"'
                    local s2oc`s2k' `"`e(clustvar)'"'
                    // 0.1.76: keep the model's own e(V_modelbased) so it can
                    // be put back below. suest2_vceconvert may rescale it,
                    // and the rescaled matrix must not survive this call.
                    capture matrix drop s2omb`s2k'
                    capture confirm matrix e(V_modelbased)
                    if !_rc  matrix s2omb`s2k' = e(V_modelbased)
                    local s2_mbscaled 0
                    if `"`s2cvar'"' != ""  quietly suest2_vceconvert, clearclust
                    else                   quietly suest2_vceconvert
                    local s2wasmb`s2k' = `s2_mbscaled'
                    capture quietly estimates drop `nm'
                    quietly estimates store `nm'
                }
                // A clustered system must carry its cluster() through or the
                // joint covariance comes back UNCLUSTERED; measured difference
                // when it is dropped: 1.2753.
                local s2addcl ""
                if `"`s2cvar'"' != "" & !regexm(`"`s2opt'"', "cluster[ ]*\(") ///
                    local s2addcl `"cluster(`s2cvar')"'
                if trim(`"`s2opt'`s2addcl'"') == ""  capture noisily suest `s2names'
                else capture noisily suest `s2names', `s2opt' `s2addcl'
                local s2rc = _rc

                // The restore loop below calls estimates restore on each
                // constituent, which REPLACES the active results.  suest's
                // joint output has to be parked first or it is destroyed --
                // and destroyed silently, leaving e(b) as the last
                // constituent's rather than the system's.
                tempname s2joint
                local s2held 0
                if !`s2rc' {
                    capture quietly estimates store `s2joint'
                    if !_rc  local s2held 1
                }

                // Put every model back exactly as the user stored it, whether
                // or not suest succeeded.
                local s2k 0
                foreach nm of local s2names {
                    local ++s2k
                    capture quietly estimates restore `nm'
                    local s2mbopt ""
                    if `s2wasmb`s2k'' == 1  local s2mbopt "mb(s2omb`s2k')"
                    capture quietly suest2_vcerestore, vce(`"`s2ov`s2k''"') ///
                        vcetype(`"`s2ot`s2k''"') clustvar(`"`s2oc`s2k''"') ///
                        `s2mbopt'
                    capture quietly estimates drop `nm'
                    capture quietly estimates store `nm'
                }

                if `s2held' {
                    capture quietly estimates restore `s2joint'
                    if _rc {
                        di as err "suest2 lost the combined result while restoring the stored models"
                        exit 498
                    }
                    capture quietly estimates drop `s2joint'
                }
                if `s2rc' exit `s2rc'
            }
            else {
                // Must NOT pass `0': it still carries nowarn, which is
                // suest2's own option and unknown to suest.  Use the
                // stripped names and options instead.  Passing `0' here
                // broke the commonest case of all -- two plain OIM
                // models needing no conversion -- with a bare r(198).
                if trim(`"`s2opt'"') == ""  suest `s2names'
                else                        suest `s2names', `s2opt'
            }

            if `s2nonrb' & !`s2nowarn' {
                di _newline(1)
                di in red "{bf:suest2} uses vce(robust) for all models. " /*
                */ "Standard errors from {bf:suest2} will differ from the " /*
                */ "specified model(s) because vce(robust) was not used on at " /*
                */ "least one of the models given. We strongly recommend " /*
                */ "refitting the models with vce(robust) so that each model's " /*
                */ "own standard errors match those {bf:suest2} reports. " /*
                */ "See {help vce_option} for details on vce(robust)."
            }
        }
    }

    local names `"`e(names)'"'
    local nmodels : word count `names'
    if `nmodels' == 0 {
        di as err "suest did not return constituent model names"
        exit 498
    }

    local hasdot : list posof "." in names
    if `hasdot' {
        di as err "suest2 prediction support currently requires named stored estimates"
        di as err "store the active model with {bf:estimates store} before running suest2"
        exit 198
    }

    tempname combined
    quietly estimates store `combined'

    capture confirm scalar __suest2_counter
    if _rc scalar __suest2_counter = 0
    scalar __suest2_counter = scalar(__suest2_counter) + 1
    local runseq = scalar(__suest2_counter)
    local stamp `"`c(current_date)'`c(current_time)'"'
    local stamp : subinstr local stamp " " "", all
    local stamp : subinstr local stamp ":" "", all
    local runid "`stamp'_`runseq'"

    local start 1
    local marginsdefault
    local marginsok model(passthru) suestxb(passthru) default Pr xb mu rate fixedonly conditional(passthru) nooffset outcome(passthru)
    local marginsnotok
    local asbalanced
    local asobserved
    local held
    local rc 0
    local allsystem 1
    local allxtlogitfe 1

    forvalues i = 1/`nmodels' {
        local name : word `i' of `names'

        capture quietly estimates restore `name'
        if _rc {
            local rc = _rc
            di as err "unable to restore constituent model {bf:`name'}"
            continue, break
        }

        capture confirm matrix e(b)
        if _rc {
            local rc = _rc
            di as err "constituent model {bf:`name'} does not contain e(b)"
            continue, break
        }

        local hold "__s2_`runid'_`i'"
        // Mark the private copy itself before storing it.  MI estimation can
        // leave private copies from several imputations in the global estimate
        // table, while the pooled result does not retain every hold name.
        // Ownership metadata lets suest2_cleanup find all such copies without
        // treating a user-chosen __s2_* name as package-owned.
        quietly suest2_private_mark `"`runid'"'
        capture quietly estimates store `hold'
        if _rc {
            local rc = _rc
            di as err "unable to preserve constituent model {bf:`name'}"
            continue, break
        }
        local hold`i' `"`hold'"'
        local held `"`held' `hold'"'

        local korig`i' = colsof(e(b))
        local kblock`i' = `korig`i''
        local cmd`i' `"`e(cmd)'"'
        local isxtlogitfe`i' = ("`e(cmd)'"=="clogit" & "`e(cmd2)'"=="xtlogit" & "`e(model)'"=="fe")
        if `isxtlogitfe`i'' local cmd`i' "xtlogit"
        else local allxtlogitfe 0
        if `xtmlogit_path' & ("`e(cmd)'"=="xtmlogit" | "`e(cmd2)'"=="xtmlogit") ///
            local cmd`i' "xtmlogit"
        if `xtpa_path' & "`e(cmd)'"=="xtgee" & "`e(model)'"=="pa" ///
            local cmd`i' `"`e(cmd2)'"'
        if `mehetero_path' {
            quietly suest2_mehetero_identify
            if r(supported) local cmd`i' `"`r(activecmd)'"'
        }
        if `melogit_path' & "`e(cmd2)'"=="melogit" local cmd`i' "melogit"
        if `meprobit_path' & "`e(cmd2)'"=="meprobit" local cmd`i' "meprobit"
        if `mecloglog_path' & "`e(cmd2)'"=="mecloglog" local cmd`i' "mecloglog"
        if `mepoisson_path' & "`e(cmd2)'"=="mepoisson" local cmd`i' "mepoisson"
        if `menbreg_path' & "`e(cmd2)'"=="menbreg" local cmd`i' "menbreg"
        if `meologit_path' & "`e(cmd2)'"=="meologit" local cmd`i' "meologit"
        if `meoprobit_path' & "`e(cmd2)'"=="meoprobit" local cmd`i' "meoprobit"
        if "`e(cmd2)'"=="streg" local cmd`i' "streg"
        local predict`i' `"`e(predict)'"'
        local depvar`i' `"`e(depvar)'"'
        local marginsdefault`i' `"`e(marginsdefault)'"'
        local marginsok`i' `"`e(marginsok)'"'
        local marginsnotok`i' `"`e(marginsnotok)'"'
        local marginsprop`i' `"`e(marginsprop)'"'
        local prefix`i' `"`e(prefix)'"'
        local vce`i' `"`e(vce)'"'
        local vcetype`i' `"`e(vcetype)'"'
        local subpop`i' `"`e(subpop)'"'
        local xtmodel`i' `"`e(model)'"'
        local xtivar`i' `"`e(ivar)'"'
        local xtvars`i' `"`e(vars)'"'
        local xtstripes`i' `"`e(stripes)'"'
        local distribution`i'=lower(trim(`"`e(distribution)'"'))
        if trim(`"`distribution`i''"')=="" local distribution`i'=lower(trim(`"`e(distrib)'"'))
        if "`e(cmd2)'"=="streg" local distribution`i'=lower(trim(`"`e(cmd)'"'))
        local frm2`i'=lower(trim(`"`e(frm2)'"'))

        // Preserve useful constituent-model metadata before official suest
        // returns us to the combined result.
        local N`i' .
        capture confirm scalar e(N)
        if !_rc local N`i' = e(N)
        local wtype`i' `"`e(wtype)'"'
        local wexp`i' `"`e(wexp)'"'
        local offset`i' `"`e(offset)'"'
        if trim(`"`offset`i''"') == "" local offset`i' `"`e(offset1)'"'
        local exposure`i' `"`e(exposure)'"'
        // poisson/nbreg translate exposure(varname) into the estimation
        // offset ln(varname) and may not retain e(exposure). Recover the
        // original variable from the constituent command line when needed.
        if `"`exposure`i''"' == "" {
            local constituent_cmdline `"`e(cmdline)'"'
            if regexm(`"`constituent_cmdline'"', "exp(osure)?\([ ]*([A-Za-z_][A-Za-z0-9_]*)[ ]*\)") {
                local exposure`i' `"`=regexs(2)'"'
            }
        }
        local dispersion`i' `"`e(dispers)'"'
        if trim(`"`dispersion`i''"') == "" local dispersion`i' `"`e(dispersion)'"'
        local clustvar`i' `"`e(clustvar)'"'
        local Nclust`i' .
        capture confirm scalar e(N_clust)
        if !_rc local Nclust`i' = e(N_clust)

        local family`i'
        local link`i'
        if "`e(cmd2)'"=="melogit" {
            local family`i' bernoulli
            local link`i' logit
        }
        else if "`e(cmd2)'"=="meprobit" {
            local family`i' bernoulli
            local link`i' probit
        }
        else if "`e(cmd2)'"=="mecloglog" {
            local family`i' bernoulli
            local link`i' cloglog
        }
        else if "`e(cmd2)'"=="mepoisson" {
            local family`i' poisson
            local link`i' log
        }
        else if "`e(cmd2)'"=="menbreg" {
            local family`i' negative_binomial
            local link`i' log
        }
        else if inlist("`e(cmd2)'","meologit","xtologit") {
            local family`i' ordinal
            local link`i' logit
        }
        else if inlist("`e(cmd2)'","meoprobit","xtoprobit") {
            local family`i' ordinal
            local link`i' probit
        }
        else if "`e(cmd2)'"=="mestreg" {
            local family`i' survival
            local link`i' `"`frm2`i''"'
        }
        else if "`e(cmd)'"=="glm" {
            local family`i'=lower(trim(`"`e(varfunct)'"'))
            local family`i'=subinstr(`"`family`i''"'," ","_",.)
            local link`i'=lower(trim(`"`e(linkt)'"'))
            local link`i'=subinstr(`"`link`i''"'," ","_",.)
        }
        else if "`cmd`i''"=="cloglog" {
            local family`i' bernoulli
            local link`i' cloglog
        }
        else if "`cmd`i''"=="tobit" {
            local family`i' censored_gaussian
            local link`i' identity
        }
        else if "`cmd`i''"=="intreg" {
            local family`i' interval_gaussian
            local link`i' identity
        }
        else if "`cmd`i''"=="heckman" {
            local family`i' selection_normal
            local link`i' identity_probit
        }
        else if "`cmd`i''"=="streg" {
            local family`i' survival
            local link`i' `"`frm2`i''"'
        }
        else if "`cmd`i''"=="fracreg" {
            // fracreg posts neither e(model) nor e(link); word 2 of
            // e(cmdline) is the estimator token by the command's own
            // grammar (measured 20aug2026).
            local fr2 : word 2 of `e(cmdline)'
            local family`i' fractional
            local link`i' `"`fr2'"'
        }
        else if "`cmd`i''"=="betareg" {
            // betareg posts e(linkt) in ITS OWN dialect: "Comp. log-log",
            // which the GLM branch's strpos(link,"complementary") test does
            // NOT match, while Stata's own glm posts "Complementary
            // log-log", which does. Measured probe_fam_forms_v1_1: reading
            // e(linkt) through unnormalized sent cloglog down the log-log
            // path and returned a plausible-looking column at reldif .19.
            // Normalize here to the vocabulary suest2_p already speaks.
            // "Comp." is tested BEFORE "log-log" because it contains it.
            local blk`i'=lower(trim(`"`e(linkt)'"'))
            local family`i' beta
            if strpos(`"`blk`i''"',"comp")           local link`i' complementary_log-log
            else if strpos(`"`blk`i''"',"probit")    local link`i' probit
            else if strpos(`"`blk`i''"',"log-log")   local link`i' log-log
            else                                     local link`i' logit
        }
        else if "`cmd`i''"=="truncreg" {
            local family`i' truncated_gaussian
            local link`i' identity
        }
        else if "`cmd`i''"=="hetprobit" {
            local family`i' heteroskedastic_bernoulli
            local link`i' probit
        }
        else if inlist("`cmd`i''","zip","zinb") {
            // the INFLATION link, logit or probit, posted by both commands
            // as e(inflate) (measured probe_fam_meta_v1_0).
            local family`i' zero_inflated
            local link`i'=lower(trim(`"`e(inflate)'"'))
            if !inlist("`link`i''","logit","probit") local link`i' logit
        }
        else if "`cmd`i''"=="biprobit" {
            local family`i' bivariate_bernoulli
            local link`i' probit
        }
        else if inlist("`cmd`i''","ivprobit","ivtobit") {
            // No link or boundary is read: the default prediction is the
            // structural linear index and needs neither. e(llopt)/e(ulopt)
            // would be required only for the E() and ystar() forms, which
            // are refused.
            local family`i' instrumental
            local link`i' identity
        }
        else if inlist("`e(cmd)'", "regress", "anova", "xtreg", "mixed", "ivregress") | "`cmd`i''"=="megaussian" {
            local family`i' gaussian
            local link`i' identity
        }
        else if "`cmd`i''"=="megamma" {
            local family`i' gamma
            local link`i' log
        }
        else if inlist("`cmd`i''", "logit", "logistic", "xtlogit") {
            local family`i' bernoulli
            local link`i' logit
        }
        else if inlist("`cmd`i''", "probit", "xtprobit") | ///
            inlist("`e(cmd)'", "probit", "xtprobit") {
            local family`i' bernoulli
            local link`i' probit
        }
        else if "`cmd`i''" == "xtcloglog" | "`e(cmd)'" == "xtcloglog" {
            local family`i' bernoulli
            local link`i' cloglog
        }
        else if inlist("`cmd`i''", "poisson", "xtpoisson") | ///
            inlist("`e(cmd)'", "poisson", "xtpoisson") {
            local family`i' poisson
            local link`i' log
        }
        else if inlist("`cmd`i''", "nbreg", "xtnbreg") | ///
            inlist("`e(cmd)'", "nbreg", "xtnbreg") {
            local family`i' negative_binomial
            local link`i' log
        }
        else if "`e(cmd)'" == "ologit" {
            local family`i' ordinal
            local link`i' logit
        }
        else if "`e(cmd)'" == "oprobit" {
            local family`i' ordinal
            local link`i' probit
        }
        else if "`e(cmd)'" == "mlogit" | "`cmd`i''" == "xtmlogit" {
            local family`i' multinomial
            local link`i' logit
        }
        else {
            local family`i' `"`e(family)'"'
            local link`i' `"`e(link)'"'
        }

        tempname nativeH
        capture quietly _get_hmat `nativeH'
        local nativeHrc`i' = _rc
        if !`nativeHrc`i'' local nativeHrc`i' = r(rc)
        if !`nativeHrc`i'' local nativeH`i' `nativeH'

        local marginsok `"`marginsok' `e(marginsok)'"'
        if inlist("`cmd`i''","tobit","intreg") {
            local marginsok `"`marginsok' PRRange(passthru) EXPECTed(passthru)"'
        }
        local marginsnotok `"`marginsnotok' `e(marginsnotok)'"'
        local asbalanced `"`asbalanced' `e(asbalanced)'"'
        local asobserved `"`asobserved' `e(asobserved)'"'

        local ibaseout`i' 0
        capture confirm scalar e(ibaseout)
        if !_rc local ibaseout`i' = e(ibaseout)
        local baseout`i'
        capture confirm scalar e(baseout)
        if !_rc local baseout`i' = e(baseout)

        // Original coefficient-equation structure.
        local ocoleq`i' : coleq e(b)
        local oeqnames`i' : list uniq ocoleq`i'
        local neq`i' : word count `oeqnames`i''
        if `neq`i'' < 1 local neq`i' 1
        local maineq`i' : word 1 of `oeqnames`i''
        local kmain`i' 0
        foreach eq of local ocoleq`i' {
            if `"`eq'"' == `"`maineq`i''"' local kmain`i' = `kmain`i'' + 1
        }

        local systempred`i' 0
        foreach supported in regress anova xtreg mixed ivregress logit logistic probit poisson nbreg ologit oprobit mlogit gologit2 glm cloglog tobit intreg heckman streg fracreg xtlogit xtprobit xtpoisson xtnbreg xtcloglog xtmlogit betareg truncreg hetprobit zip zinb biprobit ivprobit ivtobit {
            if "`e(cmd)'" == "`supported'" | "`cmd`i''" == "`supported'" local systempred`i' 1
        }
        if inlist("`cmd`i''","xtologit","xtoprobit") local systempred`i' 1
        if inlist("`e(cmd2)'","melogit","meprobit","mecloglog","mepoisson","menbreg","meologit","meoprobit","mestreg") local systempred`i' 1
        if inlist("`cmd`i''","melogit","meprobit","mecloglog","mepoisson","menbreg","meologit","meoprobit","megaussian","megamma") | ///
            "`cmd`i''"=="mestreg" local systempred`i' 1
        if "`e(cmd)'" == "xtgee" & "`e(model)'" == "pa" & ///
            inlist("`e(cmd2)'","xtreg","xtlogit","xtprobit","xtcloglog","xtpoisson","xtnbreg") ///
            local systempred`i' 1
        if !`systempred`i'' local allsystem 0

        // Official suest appends one lnvar parameter to non-svy regress/anova.
        if inlist("`e(cmd)'", "regress", "anova") & "`e(prefix)'" != "svy" {
            local kblock`i' = `kblock`i'' + 1
        }

        local start`i' = `start'
        local start = `start' + `kblock`i''

        // Add model() to each estimator-specific default prediction.
        local outcomes`i'

        // gologit2 stores the complete ordered response map directly in
        // e(cat).  Use that contract rather than relying exclusively on
        // parsing e(marginsdefault), whose nested predict() tokens may not
        // yield a portable outcome list across gologit2 versions.
        if "`e(cmd)'"=="gologit2" | "`cmd`i''"=="gologit2" {
            capture confirm matrix e(cat)
            if !_rc {
                local g2kcat=colsof(e(cat))
                forvalues g2j=1/`g2kcat' {
                    local g2out=e(cat)[1,`g2j']
                    local outcomes`i' `"`outcomes`i'' `g2out'"'
                }
                local outcomes`i' : list retokenize outcomes`i'
            }
        }

        // Preserve the native estimator's margins contract.  In particular,
        // nonlinear random-effects models must retain the integrated
        // prediction used by native bare margins rather than substituting a
        // fixed-only response definition.
        local md `"`e(marginsdefault)'"'
        local marginsdefault`i' `"`md'"'
        local mdparsed`i' 1
        if trim(`"`md'"') == "" {
            local marginsdefault `"`marginsdefault' predict(model(`name'))"'
        }
        else {
            local mdrest `"`md'"'
            while trim(`"`mdrest'"') != "" {
                gettoken mdtok mdrest : mdrest, bind
                if substr(`"`mdtok'"',1,8) == "predict(" & substr(`"`mdtok'"',strlen(`"`mdtok'"'),1) == ")" {
                    local mdinner = substr(`"`mdtok'"',9,strlen(`"`mdtok'"')-9)
                    local marginsdefault `"`marginsdefault' predict(model(`name') `mdinner')"'
                    if regexm(`"`mdinner'"', "outcome\(([^)]+)\)") {
                        local out = regexs(1)
                        local outpos : list posof `"`out'"' in outcomes`i'
                        if !`outpos' local outcomes`i' `"`outcomes`i'' `out'"'
                    }
                }
                else {
                    local mdparsed`i' 0
                    local marginsdefault `"`marginsdefault' predict(model(`name'))"'
                    local mdrest
                }
            }
        }
    }

    quietly estimates restore `combined'
    capture quietly estimates drop `combined'

    if `rc' {
        foreach h of local held {
            capture quietly estimates drop `h'
        }
        exit `rc'
    }

    local kcombined = colsof(e(b))
    if `start' - 1 != `kcombined' {
        foreach h of local held {
            capture quietly estimates drop `h'
        }
        di as err "suest2 could not map constituent-model parameters to the combined e(b)"
        di as err "combined parameters: `kcombined'; mapped parameters: `=`start'-1'"
        exit 498
    }

    // Official suest's e(eqnames#) gives the numeric equation() ordering used
    // by built-in _predict.  Ordered cutpoints and ancillary parameters each
    // count as separate equations even when they share an e(b) equation stripe.
    local eqcursor 1
    forvalues i = 1/`nmodels' {
        local sysnames `e(eqnames`i')'
        if "`sysnames'" == "" local sysnames `oeqnames`i''
        local syseqnames`i' `sysnames'
        local nsyseq`i' : word count `sysnames'
        if `nsyseq`i'' < 1 local nsyseq`i' 1
        local eqstart`i' = `eqcursor'
        local eqcursor = `eqcursor' + `nsyseq`i''
    }

    // Construct standard system-level metadata.  Model names identify
    // response-specific sample sizes even when dependent variables repeat.
    tempname Nmat
    matrix `Nmat' = J(1, `nmodels', .)
    local depvars
    local eqnames
    local nsyseqtotal 0
    forvalues i = 1/`nmodels' {
        matrix `Nmat'[1,`i'] = `N`i''
        local depvars `"`depvars' `depvar`i''"'
        local maineqsys : word 1 of `syseqnames`i''
        local eqnames `"`eqnames' `maineqsys'"'
        local nsyseqtotal = `nsyseqtotal' + `nsyseq`i''
    }
    matrix colnames `Nmat' = `names'
    matrix rownames `Nmat' = N

    local marginsok : list uniq marginsok
    local marginsnotok : list uniq marginsnotok
    local dropxb xb
    local marginsnotok : list marginsnotok - dropxb
    local asbalanced : list uniq asbalanced
    local asobserved : list uniq asobserved

    // Build factor-variable information for the complete active system.
    // The dedicated FE route already built structural factor-variable
    // information using a full-rank reference VCE.  Rebuilding it here from
    // the exact singular FE VCE would overwrite that valid H matrix and cause
    // margins to classify estimable factor-variable functions as omitted.
    if `xtmlogit_path' | `xtnbregre_path' | `xtpoissonregamma_path' | ///
        `xtnbregfe_path' | `xtpoissonfe_path' | `xtfe_path' local fvrc 0
    else {
        capture quietly ereturn repost, buildfvinfo
        local fvrc = _rc
    }

    forvalues i = 1/`nmodels' {
        local name : word `i' of `names'
        ereturn scalar suest2_start`i' = `start`i''
        ereturn scalar suest2_korig`i' = `korig`i''
        ereturn scalar suest2_kblock`i' = `kblock`i''
        ereturn scalar suest2_kmain`i' = `kmain`i''
        ereturn scalar suest2_eqstart`i' = `eqstart`i''
        ereturn scalar suest2_nsyseq`i' = `nsyseq`i''
        ereturn scalar suest2_mdparsed`i' = `mdparsed`i''
        ereturn scalar suest2_neq`i' = `neq`i''
        ereturn scalar suest2_systempred`i' = `systempred`i''
        ereturn scalar suest2_N`i' = `N`i''
        ereturn scalar suest2_N_clust`i' = `Nclust`i''
        ereturn scalar suest2_nativeHrc`i' = `nativeHrc`i''
        if !`nativeHrc`i'' ereturn matrix suest2_H`i' = `nativeH`i''
        ereturn scalar suest2_ibaseout`i' = `ibaseout`i''
        ereturn local suest2_baseout`i' `"`baseout`i''"'
        ereturn local suest2_model`i' `"`name'"'
        ereturn local suest2_hold`i' `"`hold`i''"'
        ereturn local suest2_cmd`i' `"`cmd`i''"'
        ereturn local suest2_predict`i' `"`predict`i''"'
        ereturn local suest2_depvar`i' `"`depvar`i''"'
        ereturn local suest2_family`i' `"`family`i''"'
        ereturn local suest2_link`i' `"`link`i''"'
        ereturn local suest2_wtype`i' `"`wtype`i''"'
        ereturn local suest2_wexp`i' `"`wexp`i''"'
        ereturn local suest2_offset`i' `"`offset`i''"'
        ereturn local suest2_exposure`i' `"`exposure`i''"'
        ereturn local suest2_dispersion`i' `"`dispersion`i''"'
        ereturn local suest2_clustvar`i' `"`clustvar`i''"'
        ereturn local suest2_oeqnames`i' `"`oeqnames`i''"'
        ereturn local suest2_syseqnames`i' `"`syseqnames`i''"'
        ereturn local suest2_outcomes`i' `"`outcomes`i''"'
        ereturn local suest2_marginsdefault`i' `"`marginsdefault`i''"'
        ereturn local suest2_marginsok`i' `"`marginsok`i''"'
        ereturn local suest2_marginsnotok`i' `"`marginsnotok`i''"'
        ereturn local suest2_marginsprop`i' `"`marginsprop`i''"'
        ereturn local suest2_prefix`i' `"`prefix`i''"'
        ereturn local suest2_vce`i' `"`vce`i''"'
        ereturn local suest2_vcetype`i' `"`vcetype`i''"'
        ereturn local suest2_subpop`i' `"`subpop`i''"'
        ereturn local suest2_xtmodel`i' `"`xtmodel`i''"'
        ereturn local suest2_xtivar`i' `"`xtivar`i''"'
        ereturn local suest2_xtvars`i' `"`xtvars`i''"'
        ereturn local suest2_xtstripes`i' `"`xtstripes`i''"'
        ereturn local suest2_distribution`i' `"`distribution`i''"'
        ereturn local suest2_frm2`i' `"`frm2`i''"'
    }

    ereturn scalar suest2_nmodels = `nmodels'
    ereturn scalar suest2_nresponses = `nmodels'
    ereturn scalar suest2_nsyseq_total = `nsyseqtotal'
    ereturn scalar suest2_allsystem = `allsystem'
    ereturn scalar suest2_fvinfo = (`fvrc' == 0)
    ereturn local suest2_id `"`runid'"'
    ereturn local suest2_holds `"`held'"'
    * KEEP IN STEP WITH THE BANNER ON LINE 1. Two separate claims about
    * the same thing. They disagreed for four versions, were fixed at
    * 0.1.83, and disagreed AGAIN at 0.1.84 because this comment was the
    * only thing holding them together and a comment is not a mechanism.
    * Enforced now in two places that can fail: stata_preflight.py E10 at
    * build time, gate 32 v1_1 PART 0 at run time.
    ereturn local suest2_version "1.0.0"
    ereturn scalar suest2_svy = (`survey_path' != 0)
    ereturn scalar suest2_ivregress = `ivregress_path'
    ereturn scalar suest2_xtlogit_fe = `allxtlogitfe'
    ereturn scalar suest2_xtmlogit = `xtmlogit_path'
    ereturn scalar suest2_xtpoisson_fe = `xtpoissonfe_path'
    ereturn scalar suest2_xtnbreg_fe = `xtnbregfe_path'
    ereturn scalar suest2_xtnbreg_re = `xtnbregre_path'
    ereturn scalar suest2_xtpoisson_re_gamma = `xtpoissonregamma_path'
    if `survey_path' ereturn local title "Simultaneous survey results"
    else if `ivregress_path' ereturn local title "Simultaneous instrumental-variables 2SLS results"
    else if `xtmlogit_path' ereturn local title "Simultaneous panel multinomial-logit results"
    else if `xtnbregre_path' ereturn local title "Simultaneous beta random-effects negative-binomial results"
    else if `xtpoissonregamma_path' ereturn local title "Simultaneous gamma random-effects Poisson results"
    else if `xtnbregfe_path' ereturn local title "Simultaneous conditional fixed-effects negative-binomial results"
    else if `xtpoissonfe_path' ereturn local title "Simultaneous conditional fixed-effects Poisson results"
    else if `allxtlogitfe' ereturn local title "Simultaneous conditional fixed-effects logistic results"
    else if `xtfe_path' ereturn local title "Simultaneous fixed-effects results"
    else if `xtbe_path' ereturn local title "Simultaneous between-effects results"
    else if `xtcre_path' ereturn local title "Simultaneous correlated random-effects results"
    else if `xtre_path' ereturn local title "Simultaneous random-effects results"
    else if `xtml_path' ereturn local title "Simultaneous random-effects ML results"
    else if `xtpa_path' ereturn local title "Simultaneous population-averaged results"
    else if `mehetero_path' {
        capture confirm scalar e(suest2_mehetero_all_mestreg)
        if !_rc & e(suest2_mehetero_all_mestreg) ereturn local title "Simultaneous mixed-effects parametric survival results"
        else {
            capture confirm scalar e(suest2_mehetero_all_xtgre)
            if !_rc & e(suest2_mehetero_all_xtgre) ereturn local title "Simultaneous nonlinear random-effects results"
            else ereturn local title "Simultaneous heterogeneous mixed-model results"
        }
    }
    else if `mixed_path' ereturn local title "Simultaneous mixed-effects ML results"
    else if `melogit_path' ereturn local title "Simultaneous mixed-effects logistic results"
    else if `meprobit_path' ereturn local title "Simultaneous mixed-effects probit results"
    else if `mecloglog_path' ereturn local title "Simultaneous mixed-effects complementary-log-log results"
    else if `mepoisson_path' ereturn local title "Simultaneous mixed-effects Poisson results"
    else if `menbreg_path' ereturn local title "Simultaneous mixed-effects negative-binomial results"
    else if `meologit_path' ereturn local title "Simultaneous mixed-effects ordered-logit results"
    else if `meoprobit_path' ereturn local title "Simultaneous mixed-effects ordered-probit results"
    else ereturn local title "Simultaneous estimation results"
    if `survey_path' & trim(`"`survey_subpop'"') != "" {
        ereturn local subpop `"`survey_subpop'"'
        ereturn local suest2_subpop_common `"`survey_subpop'"'
    }
    ereturn local depvar `"`depvars'"'
    ereturn local eqnames `"`eqnames'"'
    ereturn scalar k = colsof(e(b))
    ereturn matrix _N = `Nmat'
    ereturn local marginsdefault `"`marginsdefault'"'
    ereturn local marginsok `"`marginsok'"'
    if `"`marginsnotok'"' != "" ereturn local marginsnotok `"`marginsnotok'"'
    if `"`asbalanced'"' != "" ereturn local asbalanced `"`asbalanced'"'
    if `"`asobserved'"' != "" ereturn local asobserved `"`asobserved'"'
    // Multiequation active-system predictions can involve constants and
    // ancillary equations.  This matches gsem's stacked-system convention.
    ereturn local marginsprop "allcons"
    ereturn local margins_check_est suest2_marg_check
    ereturn local margins_cmd suest2_margins
    ereturn local predict suest2_p
    ereturn local cmdline `"suest2 `0'"'
    ereturn local cmd suest2

    // Official unweighted and survey paths already displayed results; the
    // specialized bridges run quietly so temporary names never appear, so
    // display here with the dispatched route's options.
    if "`route'" != "" {
        if trim(`"`routedisplay'"') == "" suest2_display
        else suest2_display, `routedisplay'
    }
    else if `pweight_path' {
        if trim(`"`pwdisplay'"') == "" suest2_display
        else suest2_display, `pwdisplay'
    }
end

program define suest2_private_mark, eclass
    version 16
    args owner
    ereturn scalar suest2_private = 1
    ereturn local suest2_owner `"`owner'"'
end

program define suest2_routescan, rclass
*   One scanner for every specialized route except mehetero, which has its
*   own class logic in suest2_meheteroscan. The route family is the first
*   token; the rest is the ordinary suest2 argument string. Replaced fourteen
*   structurally identical scanners at 0.1.79 (seven of them already unified
*   as suest2_mescan at 0.1.75 candidate 19). version 16 deliberately: the
*   xtmlogit scanner's version 17 statement made every suest2 call exit r(9)
*   on Stata 16; the predicate cannot match there anyway, and the version 17
*   requirement lives in the xtmlogit bridge.
    version 16
    gettoken fam 0 : 0
    syntax [anything] [, CLuster(passthru) VCE(passthru) MINUS(passthru) ///
        REGRESSML SVY Level(passthru) DIR EForm(passthru) Robust *]

    est_expand `"`anything'"', min(1) default(.)
    local names `"`r(names)'"'
    local names : list uniq names
    local n 0
    local nsvyiv 0
    local xtpasupported "xtreg xtlogit xtprobit xtcloglog xtpoisson xtnbreg"

    foreach name of local names {
        if "`name'" == "." continue
        capture quietly estimates restore `name'
        if _rc {
            local rc = _rc
            di as err "unable to restore constituent model {bf:`name'}"
            exit `rc'
        }
        local hit 0
        if "`fam'" == "ivregress" {
            if "`e(cmd)'" == "ivregress" {
                local hit 1
                if "`e(prefix)'" == "svy" local ++nsvyiv
            }
        }
        else if "`fam'" == "xtmlogit" {
            if ("`e(cmd)'" == "xtmlogit" | "`e(cmd2)'" == "xtmlogit") & ///
                inlist("`e(model)'", "fe", "re") local hit 1
        }
        else if "`fam'" == "xtnbregre" {
            if "`e(cmd)'" == "xtnbreg" & "`e(model)'" == "re" & ///
                lower(trim(`"`e(distrib)'"')) == "beta" local hit 1
        }
        else if "`fam'" == "xtpoissonregamma" {
            if "`e(cmd)'" == "xtpoisson" & "`e(model)'" == "re" & ///
                lower(trim(`"`e(distrib)'"')) == "gamma" local hit 1
        }
        else if "`fam'" == "xtnbregfe" {
            if "`e(cmd)'" == "xtnbreg" & "`e(model)'" == "fe" local hit 1
        }
        else if "`fam'" == "xtpoissonfe" {
            if "`e(cmd)'" == "xtpoisson" & "`e(model)'" == "fe" local hit 1
        }
        else if inlist("`fam'", "xtfe", "xtbe", "xtcre", "xtre", "xtml") {
            if "`e(cmd)'" == "xtreg" & ///
                "`e(model)'" == substr("`fam'", 3, .) local hit 1
        }
        else if "`fam'" == "xtpa" {
            if "`e(cmd)'" == "xtgee" & "`e(model)'" == "pa" {
                local cmd2 = lower(trim("`e(cmd2)'"))
                if `: list posof "`cmd2'" in xtpasupported' local hit 1
            }
        }
        else if "`fam'" == "mixed" {
            if "`e(cmd)'" == "mixed" local hit 1
        }
        else {
            // The seven single-family mixed-effects routes: melogit,
            // meprobit, mecloglog, mepoisson, menbreg, meologit, meoprobit.
            if "`e(cmd2)'" == "`fam'" local hit 1
        }
        if `hit' local ++n
    }

    return scalar has = (`n' > 0)
    return scalar n = `n'
    return scalar has_`fam' = (`n' > 0)
    return scalar n_`fam' = `n'
    if "`fam'" == "ivregress" {
        return scalar has_svyivregress = (`nsvyiv' > 0)
        return scalar n_svyivregress = `nsvyiv'
    }
    return local names `"`names'"'
end

// Clear ONLY the macros suest's guards read, inside a private copy of a
// stored estimate. e(V) is left alone: suest's GetMat prefers
// e(V_modelbased) whenever it exists (reposting e(V) measured as a no-op,
// diag_robust_vce_minimal).
//
// suest2_mbdetect: is this model's e(V_modelbased) SCALE-FREE?  After OLS,
// Stata stores it with the residual scale factored out (sigma^2 is a
// separate ML parameter -- the same reason suest appends lnvar to regress),
// and handing that matrix over as bread makes the joint variance sigma^4
// too small. Detection keys on the defect's SIGNATURE -- a scale-free
// matrix sits about sigma^2 below the robust e(V) element for element --
// rather than on a command-name list, which xtreg alone shows is the wrong
// key (fe needs the rescale, mle must not have it). Scored against sixteen
// families (probe_suest2_mbdetect_v1_0.log, 17aug2026): 0 false fires, 0
// misses; the ratio test, not the e(rmse) existence check, is what protects
// a family posting e(rmse) with a conventional matrix.
//   r(fires)  1 if e(V_modelbased) must be rescaled by r(sig2)
//   r(sig2)   e(rmse)^2, or missing
//   r(medr)   the median diagonal ratio, for diagnosis
program define suest2_mbdetect, rclass
    version 16
    tempname V VM
    return scalar fires = 0
    return scalar sig2  = .
    return scalar medr  = .

    capture confirm matrix e(V_modelbased)
    if _rc exit
    local s2 = e(rmse)^2
    if `s2' >= . | `s2' <= 0 exit
    return scalar sig2 = `s2'

    matrix `V'  = e(V)
    matrix `VM' = e(V_modelbased)
    local k = colsof(`VM')
    if colsof(`V') != `k' exit

    // estimable parameters only: a base level carries a zero on both
    // diagonals and would contribute a missing ratio
    local rl ""
    local n = 0
    forvalues j = 1/`k' {
        local d = `VM'[`j',`j']
        local e = `V'[`j',`j']
        if `d' > 0 & `e' < . {
            local ++n
            local rl "`rl' `=`e'/`d''"
        }
    }
    if `n' == 0 exit
    local rs : list sort rl
    local mid = ceil(`n'/2)
    local med : word `mid' of `rs'
    return scalar medr = `med'

    // fire only when the observed discrepancy IS sigma^2
    local rel = `med' / `s2'
    if `rel' > 0.5 & `rel' < 1.5 return scalar fires = 1
end
program define suest2_vceconvert, eclass
    version 16
    syntax [, CLEARClust]
    ereturn local vce "oim"
    ereturn local vcetype ""
    if "`clearclust'" != ""  ereturn local clustvar ""

    // Rescale a SCALE-FREE e(V_modelbased) to the conventional covariance
    // (without this, regress SEs came back 32.9x too small, ivregress
    // 1896x). suest2_mbdetect decides; r() read into locals at once (rule 9).
    quietly suest2_mbdetect
    local mbfire = r(fires)
    local mbsig2 = r(sig2)
    if `mbfire' == 1 {
        tempname mbV
        matrix `mbV' = e(V_modelbased) * `mbsig2'
        ereturn matrix V_modelbased = `mbV', copy
    }
    c_local s2_mbscaled = `mbfire'
end

// Put back exactly what a model carried before conversion.  Empty values are
// written as empty, which is what an OIM fit stores anyway.
program define suest2_vcerestore, eclass
    version 16
    syntax [, VCE(string) VCEType(string) CLUSTvar(string) MB(name)]
    ereturn local vce      `"`vce'"'
    ereturn local vcetype  `"`vcetype'"'
    ereturn local clustvar `"`clustvar'"'

    // ... and the ORIGINAL e(V_modelbased) when it was rescaled: a rescaled
    // matrix left behind would be rescaled AGAIN on the next suest2 call on
    // the same stored models, giving a variance sigma^4 too LARGE.
    if "`mb'" != "" {
        capture confirm matrix `mb'
        if !_rc  ereturn matrix V_modelbased = `mb', copy
    }
end

// Inspect the namelist and decide what, if anything, has to be converted.
// Returns:
//   r(needconv)   1 if any constituent carries a nonstandard vce
//   r(clustvar)   the common cluster variable, if every model shares one
//   r(nonrobust)  1 if any constituent was NOT fitted robust/cluster, which
//                 is the condition mecompare uses for its own warning
//   r(bad)        name of a model that cannot be converted, empty otherwise
//   r(badwhy)     why
program define suest2_vcescan, rclass
    version 16
    syntax [anything]

    local needconv 0
    local nonrobust 0
    local bad ""
    local badwhy ""
    local cvlist ""
    local nmod 0

    foreach nm of local anything {
        if "`nm'" == "." continue
        capture quietly estimates restore `nm'
        if _rc continue
        local ++nmod
        local v  `"`e(vce)'"'
        local vt `"`e(vcetype)'"'
        local cv `"`e(clustvar)'"'

        // mecompare warns whenever a model was not fitted robust, because the
        // joint sandwich then changes that model's own standard errors.
        if !inlist(`"`v'"', "robust", "cluster")  local nonrobust 1

        local isstd = inlist(`"`v'"', "", "oim", "ols", "standard") & ///
            inlist(`"`vt'"', "", "OIM") & trim(`"`cv'"') == ""
        if !`isstd' {
            local needconv 1
            capture confirm matrix e(V_modelbased)
            if _rc {
                local bad "`nm'"
                local badwhy "no e(V_modelbased) is stored, so the model-based covariance the joint sandwich needs as bread is not available"
            }
        }
        if trim(`"`cv'"') != ""  local cvlist `"`cvlist' `cv'"'
    }

    // Every model must name the SAME cluster variable, or none may.  Mixing
    // them would mean choosing one arbitrarily, and the joint sandwich can
    // cluster on only one thing.
    local cvuniq : list uniq cvlist
    local ncv : word count `cvuniq'
    local clustvar ""
    if `ncv' == 1 {
        local nclust : word count `cvlist'
        if `nclust' == `nmod'  local clustvar : word 1 of `cvuniq'
        else {
            local bad "system"
            local badwhy "some models are clustered and others are not; cluster every model on the same variable, or none"
        }
    }
    else if `ncv' > 1 {
        local bad "system"
        local badwhy "the models name different cluster variables (`cvuniq'); the combined system can cluster on only one"
    }

    return local needconv  `needconv'
    return local nonrobust `nonrobust'
    return local clustvar  `"`clustvar'"'
    return local bad       `"`bad'"'
    return local badwhy    `"`badwhy'"'
end

program define suest2_display
    version 16
    syntax [, Level(cilevel) *]
    local levelopt
    if "`level'" != "" local levelopt level(`level')
    local isxtmlogit 0
    local isxtfe 0
    local isxtbe 0
    local isxtcre 0
    local isxtre 0
    local isxtml 0
    local isxtpa 0
    local ismixed 0
    local ismelogit 0
    local ismeprobit 0
    local ismecloglog 0
    local ismepoisson 0
    local ismenbreg 0
    local ismeologit 0
    local ismeoprobit 0
    capture confirm scalar e(suest2_xtmlogit)
    if !_rc local isxtmlogit = e(suest2_xtmlogit)
    capture confirm scalar e(suest2_xtfe)
    if !_rc local isxtfe = e(suest2_xtfe)
    capture confirm scalar e(suest2_xtbe)
    if !_rc local isxtbe = e(suest2_xtbe)
    capture confirm scalar e(suest2_xtcre)
    if !_rc local isxtcre = e(suest2_xtcre)
    capture confirm scalar e(suest2_xtre)
    if !_rc local isxtre = e(suest2_xtre)
    capture confirm scalar e(suest2_xtml)
    if !_rc local isxtml = e(suest2_xtml)
    capture confirm scalar e(suest2_xtpa)
    if !_rc local isxtpa = e(suest2_xtpa)
    capture confirm scalar e(suest2_mixed)
    if !_rc local ismixed = e(suest2_mixed)
    capture confirm scalar e(suest2_melogit)
    if !_rc local ismelogit = e(suest2_melogit)
    capture confirm scalar e(suest2_meprobit)
    if !_rc local ismeprobit = e(suest2_meprobit)
    capture confirm scalar e(suest2_mecloglog)
    if !_rc local ismecloglog = e(suest2_mecloglog)
    capture confirm scalar e(suest2_mepoisson)
    if !_rc local ismepoisson = e(suest2_mepoisson)
    capture confirm scalar e(suest2_menbreg)
    if !_rc local ismenbreg = e(suest2_menbreg)
    capture confirm scalar e(suest2_meologit)
    if !_rc local ismeologit = e(suest2_meologit)
    capture confirm scalar e(suest2_meoprobit)
    if !_rc local ismeoprobit = e(suest2_meoprobit)
    if "`e(prefix)'" == "svy" di as txt "Simultaneous survey results for `e(names)'"
    else if `isxtmlogit' di as txt "Simultaneous panel multinomial-logit results for `e(names)'"
    else if `isxtfe' di as txt "Simultaneous fixed-effects results for `e(names)'"
    else if `isxtbe' di as txt "Simultaneous between-effects results for `e(names)'"
    else if `isxtcre' di as txt "Simultaneous correlated random-effects results for `e(names)'"
    else if `isxtre' di as txt "Simultaneous random-effects results for `e(names)'"
    else if `isxtml' di as txt "Simultaneous random-effects ML results for `e(names)'"
    else if `isxtpa' di as txt "Simultaneous population-averaged results for `e(names)'"
    else if `ismixed' di as txt "Simultaneous mixed-effects ML results for `e(names)'"
    else if `ismelogit' di as txt "Simultaneous mixed-effects logistic results for `e(names)'"
    else if `ismeprobit' di as txt "Simultaneous mixed-effects probit results for `e(names)'"
    else if `ismecloglog' di as txt "Simultaneous mixed-effects complementary-log-log results for `e(names)'"
    else if `ismepoisson' di as txt "Simultaneous mixed-effects Poisson results for `e(names)'"
    else if `ismenbreg' di as txt "Simultaneous mixed-effects negative-binomial results for `e(names)'"
    else if `ismeologit' di as txt "Simultaneous mixed-effects ordered-logit results for `e(names)'"
    else if `ismeoprobit' di as txt "Simultaneous mixed-effects ordered-probit results for `e(names)'"
    else di as txt "Simultaneous results for `e(names)'"
    ereturn display, `levelopt' `options'
end


// ============================================================================
// Multiple-imputation stored-estimates route
// ============================================================================

program define suest2_miscan, rclass
    version 16
    syntax [anything] [, CLuster(passthru) VCE(passthru) MINUS(passthru) ///
        REGRESSML SVY Level(passthru) DIR EForm(passthru) Robust *]

    est_expand `"`anything'"', min(1) default(.)
    local names `"`r(names)'"'
    local names : list uniq names
    local nmodels : word count `names'
    local nmi 0

    foreach name of local names {
        if "`name'" == "." continue
        capture quietly estimates restore `name'
        if _rc {
            local rc = _rc
            di as err "unable to restore constituent model {bf:`name'}"
            exit `rc'
        }
        local ismi 0
        if `"`e(mi)'"' == "mi" local ismi 1
        if `"`e(prefix_mi)'"' == "mi estimate" local ismi 1
        capture confirm scalar e(M_mi)
        if !_rc local ismi 1
        if `ismi' local ++nmi
    }

    return scalar has_mi = (`nmi' > 0)
    return scalar n_mi = `nmi'
    return scalar nmodels = `nmodels'
    return local names `"`names'"'
end

program define suest2_miestimate, sortpreserve eclass
    version 16
    syntax [anything] [, CLuster(passthru) VCE(passthru) MINUS(passthru) ///
        REGRESSML SVY Level(passthru) DIR EForm(passthru) Robust *]

    est_expand `"`anything'"', min(1) default(.)
    local names `"`r(names)'"'
    local names : list uniq names
    local nmodels : word count `names'
    local hasdot : list posof "." in names
    if `hasdot' {
        di as err "multiple-imputation support requires named stored estimates"
        di as err "store each pooled model with {bf:estimates store} before running {bf:suest2}"
        exit 198
    }

    local specs
    local Mref .
    local mref
    forvalues i = 1/`nmodels' {
        local name : word `i' of `names'
        capture quietly estimates restore `name'
        if _rc {
            local rc = _rc
            di as err "unable to restore constituent model {bf:`name'}"
            exit `rc'
        }

        local ismi 0
        if `"`e(mi)'"' == "mi" local ismi 1
        if `"`e(prefix_mi)'"' == "mi estimate" local ismi 1
        capture confirm scalar e(M_mi)
        if !_rc local ismi 1
        if !`ismi' {
            di as err "model {bf:`name'} is not a pooled {bf:mi estimate} result"
            di as err "all models in an MI {bf:suest2} system must be estimated separately with {bf:mi estimate, post:}"
            exit 322
        }

        capture confirm scalar e(suest2_nmodels)
        if !_rc {
            di as err "model {bf:`name'} is already a pooled {bf:suest2} system"
            di as err "supply the separately pooled constituent models instead"
            exit 322
        }

        // Without post:, mi estimate leaves NO pooled e(b)/e(V) behind
        // (measured; every other macro is present, so the store passes every
        // check above), and recovery is not available: `mi estimate using'
        // does not repopulate them. Refusing with the remedy named beats the
        // r(109) "type mismatch" that colsof(e(b)) otherwise produced.
        capture confirm matrix e(b)
        local s2nob = (_rc != 0)
        if !`s2nob' {
            capture confirm matrix e(V)
            local s2nob = (_rc != 0)
        }
        if `s2nob' {
            di as err "model {bf:`name'} was pooled without {bf:post}, so it "  ///
                "carries no pooled coefficient vector or covariance matrix"
            di as err "refit it as {bf:mi estimate, post:} followed by the "   ///
                "model's own command, then store it again; {bf:suest2} needs " ///
                "e(b) and e(V) to combine the models"
            if trim(`"`e(cmdline)'"') != "" ///
                di as err "for {bf:`name'} that is: mi estimate, post: `e(cmdline)'"
            di as err "note {bf:mi estimate, saving()} and a plain "            ///
                "{bf:mi estimate:} both leave e(b) empty, and the saved file "  ///
                "cannot be used to recover it"
            exit 322
        }

        local Mi .
        capture confirm scalar e(M_mi)
        if !_rc local Mi = e(M_mi)
        local miused `"`e(m_mi)'"'
        if `i' == 1 {
            local Mref = `Mi'
            local mref `"`miused'"'
        }
        else {
            if `Mi' < . & `Mref' < . & `Mi' != `Mref' {
                di as err "MI models use different numbers of imputations"
                di as err "model {bf:`name'} uses `Mi'; the first model uses `Mref'"
                exit 322
            }
            if trim(`"`miused'"') != "" & trim(`"`mref'"') != "" & `"`miused'"' != `"`mref'"' {
                di as err "MI models were pooled over different imputation sets"
                di as err "re-estimate them using the same imputations before running {bf:suest2}"
                exit 322
            }
        }

        // Prefer e(cmdline_mi), because parsing the portion after the mi
        // prefix preserves nested prefixes such as svy: and svy, subpop():.
        // Fall back to e(cmdline) for older or nonstandard mi results.
        local cmdline
        local micmdline `"`e(cmdline_mi)'"'
        if trim(`"`micmdline'"') != "" {
            local colon = strpos(`"`micmdline'"', ":")
            if `colon' local cmdline = trim(substr(`"`micmdline'"', `colon' + 1, .))
        }
        if trim(`"`cmdline'"') == "" local cmdline `"`e(cmdline)'"'
        if trim(`"`cmdline'"') == "" {
            di as err "model {bf:`name'} does not retain a reusable estimation command"
            di as err "re-estimate it with {bf:mi estimate, post:} and store the result again"
            exit 498
        }
        local cmdlower = ustrlower(trim(`"`cmdline'"'))
        if substr(`"`cmdlower'"',1,11) == "mi estimate" {
            di as err "suest2 could not isolate the underlying estimation command for model {bf:`name'}"
            di as err "stored MI command: `cmdline'"
            exit 498
        }
        // No family gate here: a ten-stem refusal regex documented an
        // incapacity that was never measured, and gate 22 value-verifies
        // all ten families (largest deviation 8.17e-13). suest2_mi refits
        // each command inside the imputation and calls suest2 recursively,
        // so the family dispatch runs per imputation exactly as without mi.
        // Any future mi refusal must carry its measurement.

        // Retain the separately pooled constituent result and reusable
        // command.  Before building the joint system, suest2 replays each
        // command separately on the current MI data over the stored
        // imputation set.  That standalone replay has the same covariance
        // definition as the stored source result; a diagonal block of the
        // joint suest sandwich generally does not.
        tempname sourceb`i' sourceV`i'
        matrix `sourceb`i'' = e(b)
        matrix `sourceV`i'' = e(V)
        local sourcek`i' = colsof(e(b))
        local sourcecmd`i' `"`cmdline'"'
    }

    capture mi describe
    if _rc {
        di as err "the current data are not mi set"
        di as err "restore the MI data used to estimate the stored constituent models"
        exit 119
    }
    local Mcurrent = r(M)

    // Pool over the same imputations used by the stored source estimates.
    // Extra imputations in the current data are ignored rather than silently
    // changing the estimand. Missing referenced imputations are rejected.
    local miimps
    if trim(`"`mref'"') != "" {
        foreach m of local mref {
            if real("`m'") == . | real("`m'") < 1 | real("`m'") > `Mcurrent' {
                di as err "the current MI data do not contain stored imputation `m'"
                di as err "restore the MI data used to estimate the stored constituent models"
                exit 322
            }
        }
        local miimps `"imputations(`mref')"'
    }
    else if `Mref' < . & `Mcurrent' != `Mref' {
        di as err "the current MI data contain `Mcurrent' imputations; the stored models used `Mref'"
        di as err "the stored results do not identify the exact imputation set, so reconstruction is unsafe"
        exit 322
    }

    // Standalone reconstruction preflight.  Re-estimating each source model
    // separately reproduces the covariance definition used by its original
    // mi estimate result.  This detects changed weights, survey declarations,
    // offsets/exposures, imputation contents, and other analysis-data drift
    // without incorrectly comparing a source VCE to a joint-system block.
    local maxbdiff 0
    local maxVdiff 0
    tempname replayb replayV
    forvalues i = 1/`nmodels' {
        local name : word `i' of `names'
        capture quietly mi estimate, cmdok post `miimps': `sourcecmd`i''
        local replayrc = _rc
        if `replayrc' {
            di as err "the current MI data cannot reproduce stored model {bf:`name'}"
            di as err "command: `sourcecmd`i''"
            di as err "restore the original MI data or re-estimate and store all constituent models again"
            exit `replayrc'
        }

        local replayk = colsof(e(b))
        if `replayk' != `sourcek`i'' | rowsof(e(V)) != `sourcek`i'' | colsof(e(V)) != `sourcek`i'' {
            di as err "the current MI data do not reproduce stored model {bf:`name'}"
            di as err "the separately reconstructed coefficient or VCE dimensions differ"
            di as err "restore the original MI data or re-estimate and store all constituent models again"
            exit 459
        }

        matrix `replayb' = e(b)
        matrix `replayV' = e(V)
        mata: st_numscalar("__s2bdiff", max(abs(st_matrix("`sourceb`i''") :- st_matrix("`replayb'"))))
        mata: st_numscalar("__s2bscale", 1 + max(abs(st_matrix("`sourceb`i''"))))
        mata: st_numscalar("__s2Vdiff", max(abs(st_matrix("`sourceV`i''") :- st_matrix("`replayV'"))))
        mata: st_numscalar("__s2Vscale", 1 + max(abs(st_matrix("`sourceV`i''"))))
        if scalar(__s2bdiff) > `maxbdiff' local maxbdiff = scalar(__s2bdiff)
        if scalar(__s2Vdiff) > `maxVdiff' local maxVdiff = scalar(__s2Vdiff)
        if scalar(__s2bdiff) > 1e-8*scalar(__s2bscale) | scalar(__s2Vdiff) > 1e-8*scalar(__s2Vscale) {
            local component coefficients
            if scalar(__s2bdiff) <= 1e-8*scalar(__s2bscale) local component VCE
            else if scalar(__s2Vdiff) > 1e-8*scalar(__s2Vscale) local component "coefficients and VCE"
            di as err "the current MI data do not reproduce stored model {bf:`name'}"
            di as err "separately reconstructed `component' differ from the stored source estimate"
            di as err "maximum coefficient difference: " %12.5g scalar(__s2bdiff)
            di as err "maximum VCE difference: " %12.5g scalar(__s2Vdiff)
            di as err "weights, survey settings, offsets/exposures, imputations, or analysis variables may have changed"
            di as err "restore the original MI data or re-estimate and store all constituent models again"
            exit 459
        }
    }

    di as txt "note: multiple-imputation results detected"
    di as txt "      separately pooled models do not retain their cross-model covariance"
    di as txt "      suest2 verified each stored model against the current MI data and is"
    di as txt "      re-estimating the commands jointly within each imputation, then pooling"
    di as txt "      the complete stacked system with Rubin's rules"

    local suestopts `"`cluster' `vce' `minus' `regressml' `svy' `level' `dir' `eform' `robust' `options'"'
    // Pass only stored-estimate names through the outer mi command line.
    // Weight expressions remain inside the stored commands and are recovered
    // by suest2_mi within each imputation. This avoids mi estimate's parser
    // rejecting systems that contain more than one weighted command.
    capture noisily mi estimate, cmdok post `miimps': suest2_mi, sourceestimates(`names') `suestopts'
    local rc = _rc
    if `rc' {
        di as err "suest2 could not re-estimate and pool the MI system"
        di as err "verify that the current MI data and variables still match the stored model commands"
        exit `rc'
    }

    // The joint system must preserve each constituent coefficient block.
    // Its diagonal VCE blocks are not expected to equal separately estimated
    // VCEs because suest uses a joint sandwich covariance definition.
    tempname pooledb
    matrix `pooledb' = e(b)
    local badmodel
    forvalues i = 1/`nmodels' {
        local start = e(suest2_start`i')
        local finish = `start' + `sourcek`i'' - 1
        mata: st_numscalar("__s2jointbdiff", max(abs(st_matrix("`sourceb`i''") :- st_matrix("`pooledb'")[.,`start'..`finish'])))
        mata: st_numscalar("__s2jointbscale", 1 + max(abs(st_matrix("`sourceb`i''"))))
        if scalar(__s2jointbdiff) > `maxbdiff' local maxbdiff = scalar(__s2jointbdiff)
        if scalar(__s2jointbdiff) > 1e-8*scalar(__s2jointbscale) & `"`badmodel'"' == "" {
            local badmodel : word `i' of `names'
        }
    }

    if `"`badmodel'"' != "" {
        capture quietly suest2_cleanup, force
        di as err "the jointly reconstructed MI system does not preserve stored model {bf:`badmodel'}"
        di as err "the constituent coefficient block differs from the separately pooled source estimate"
        di as err "restore the original MI data or re-estimate and store all constituent models again"
        exit 459
    }

    ereturn scalar suest2_mi_reconstruction_checked = 1
    ereturn scalar suest2_mi_reconstruction_bdiff = `maxbdiff'
    ereturn scalar suest2_mi_reconstruction_Vdiff = `maxVdiff'
    ereturn local suest2_mi_imputations `"`mref'"'
    ereturn local suest2_mi_source "stored_estimates"
    ereturn local suest2_mi_source_models `"`names'"'
    ereturn local suest2_mi_user_cmdline `"suest2 `0'"'
end

// ============================================================================
// Linearized survey path and pweight bridge
// ============================================================================

program define suest2_pwscan, rclass
    version 16
    syntax [anything] [, CLuster(passthru) VCE(passthru) MINUS(passthru) ///
        REGRESSML SVY Level(passthru) DIR EForm(passthru) Robust *]

    est_expand `"`anything'"', min(1) default(.)
    local names `"`r(names)'"'
    local names : list uniq names
    local hasdot : list posof "." in names
    if `hasdot' {
        di as err "suest2 prediction support requires named stored estimates"
        di as err "store the active model with {bf:estimates store} before running suest2"
        exit 198
    }

    local hasp 0
    local np 0
    local nsvy 0
    local nmodels : word count `names'
    foreach name of local names {
        if "`name'" == "." continue
        capture quietly estimates restore `name'
        if _rc {
            local rc = _rc
            di as err "unable to restore constituent model {bf:`name'}"
            exit `rc'
        }
        if "`e(wtype)'" == "pweight" {
            local hasp 1
            local ++np
        }
        if "`e(prefix)'" == "svy" local ++nsvy
    }

    return scalar has_pweight = `hasp'
    return scalar n_pweight = `np'
    return scalar has_svy = (`nsvy' > 0)
    return scalar n_svy = `nsvy'
    return scalar requested_svy = ("`svy'" != "")
    return scalar nmodels = `nmodels'
    return local names `"`names'"'
    return local displayopts `"`level' `eform' `options'"'
end

program define suest2_svycheck, rclass
    version 16
    syntax [anything] [, CLuster(passthru) VCE(passthru) MINUS(passthru) ///
        REGRESSML SVY Level(passthru) DIR EForm(passthru) Robust *]

    if `"`cluster'"' != "" {
        di as err "option {bf:cluster()} is not allowed with survey results"
        di as err "the PSU, strata, FPC, and survey weight are determined by {bf:svyset}"
        exit 198
    }
    if `"`vce'`robust'"' != "" {
        di as err "do not specify {bf:vce()} or {bf:robust} with survey results"
        di as err "the survey VCE is determined by {bf:svyset} and the stored {bf:svy:} estimates"
        exit 198
    }

    est_expand `"`anything'"', min(1) default(.)
    local names `"`r(names)'"'
    local names : list uniq names
    local nmodels : word count `names'
    local nsvy 0
    local firstplainpw
    local survey_subpop
    local survey_subpop_set 0

    forvalues i = 1/`nmodels' {
        local name : word `i' of `names'
        capture quietly estimates restore `name'
        if _rc {
            local rc = _rc
            di as err "unable to restore constituent model {bf:`name'}"
            exit `rc'
        }
        if "`e(prefix)'" == "svy" {
            local ++nsvy
            local thissubpop `"`e(subpop)'"'
            if !`survey_subpop_set' {
                local survey_subpop `"`thissubpop'"'
                local survey_subpop_set 1
            }
            else if `"`thissubpop'"' != `"`survey_subpop'"' {
                di as err "survey models use different subpopulation specifications"
                di as err "model {bf:`name'} uses subpop(`thissubpop'); the earlier survey model uses subpop(`survey_subpop')"
                di as err "model-specific survey subpopulations are not yet compatible with one active {bf:margins} system"
                exit 322
            }
            if `"`e(vce)'"' != "linearized" {
                di as err "survey model {bf:`name'} uses {bf:`e(vce)'} variance estimation"
                di as err "official {bf:suest} supports only linearized survey results"
                di as err "BRR, jackknife, bootstrap, and successive-difference replicate VCEs are not yet supported"
                exit 322
            }
        }
        else if "`e(wtype)'" == "pweight" & `"`firstplainpw'"' == "" {
            local firstplainpw `name'
        }
    }

    if `nsvy' == 0 & `"`firstplainpw'"' != "" {
        di as err "model {bf:`firstplainpw'} was estimated with plain pweights, not with the {bf:svy:} prefix"
        di as err "option {bf:svy} cannot retrofit a complex survey design onto stored pweight results"
        di as err "re-estimate each constituent model with {bf:svy:} before running {bf:suest2}"
        exit 322
    }

    capture svyset
    if _rc {
        di as err "survey settings are not available"
        di as err "restore the {bf:svyset} design used to estimate the constituent models"
        exit 119
    }

    return scalar n_svy = `nsvy'
    return scalar nmodels = `nmodels'
    return local subpop `"`survey_subpop'"'
end

program define suest2_pwestimate, eclass sortpreserve
    version 16
    syntax [anything] [, CLuster(passthru) VCE(passthru) MINUS(passthru) ///
        REGRESSML SVY Level(passthru) DIR EForm(passthru) Robust *]

    if "`svy'" != "" {
        di as err "option {bf:svy} cannot convert stored plain-pweight models into survey results"
        di as err "re-estimate each constituent model with the {bf:svy:} prefix first"
        exit 322
    }

    est_expand `"`anything'"', min(1) default(.)
    local names `"`r(names)'"'
    local names : list uniq names
    local nmodels : word count `names'
    local hasdot : list posof "." in names
    if `hasdot' {
        di as err "pweight support requires named stored estimates"
        di as err "store the active model with {bf:estimates store} before running suest2"
        exit 198
    }

    // A pweighted system must declare pweights for every constituent.  This
    // avoids silently interpreting an undeclared model as having unit weights.
    forvalues i = 1/`nmodels' {
        local name : word `i' of `names'
        capture quietly estimates restore `name'
        if _rc {
            local rc = _rc
            di as err "unable to restore constituent model {bf:`name'}"
            exit `rc'
        }
        if "`e(wtype)'" != "pweight" {
            di as err "model {bf:`name'} was not estimated with pweights"
            di as err "all models in a pweighted suest2 system must explicitly use {bf:[pweight=...]}"
            exit 322
        }
        if !inlist("`e(cmd)'", "regress", "logit", "logistic", "probit", "poisson", "nbreg", "ologit", "oprobit", "mlogit") {
            di as err "pweight support is not yet implemented for {bf:`e(cmd)'} results"
            di as err "the current pweight stage supports regress, binary logit/probit, poisson, nbreg,"
            di as err "ologit, oprobit, and mlogit"
            di as err "other model families remain later stages"
            exit 321
        }
        if "`e(clustvar)'" != "" {
            di as err "model {bf:`name'} was estimated with clustered standard errors"
            di as err "re-estimate without {bf:vce(cluster ...)} and specify {bf:cluster()} with {bf:suest2}"
            exit 322
        }
        if !inlist(`"`e(vce)'"', "", "robust", "ols", "standard") {
            di as err "model {bf:`name'} was estimated with unsupported VCE {bf:`e(vce)'}"
            exit 322
        }
    }

    // Use a persistent name only when heterogeneous expressions require a
    // composite union weight for later official margins calls.
    capture confirm scalar __suest2_pwcounter
    if _rc scalar __suest2_pwcounter = 0
    scalar __suest2_pwcounter = scalar(__suest2_pwcounter) + 1
    local pwseq = scalar(__suest2_pwcounter)
    local pwvar = "__s2pw" + string(`pwseq', "%06.0f")
    capture confirm new variable `pwvar'
    while _rc {
        scalar __suest2_pwcounter = scalar(__suest2_pwcounter) + 1
        local pwseq = scalar(__suest2_pwcounter)
        local pwvar = "__s2pw" + string(`pwseq', "%06.0f")
        capture confirm new variable `pwvar'
    }

    quietly generate double `pwvar' = .
    label variable `pwvar' "suest2 composite pweight"
    char `pwvar'[suest2_owned] "1"
    tempvar owner union obsno
    quietly generate int `owner' = .
    quietly generate byte `union' = 0
    quietly generate long `obsno' = _n

    local clones
    local rc 0
    local errstage

    // Reconstruct each model's exact stored sample and evaluated pweights.
    forvalues i = 1/`nmodels' {
        local name : word `i' of `names'
        quietly estimates restore `name'

        local cmd`i' `"`e(cmd)'"'
        local cmdline`i' `"`e(cmdline)'"'
        local wexp`i' `"`e(wexp)'"'
        tempname bp`i'
        matrix `bp`i'' = e(b)

        tempvar sample weight conflict
        quietly generate byte `sample' = e(sample)
        local sample`i' `sample'
        capture generate double `weight' `e(wexp)'
        if _rc {
            local rc = _rc
            local errstage "evaluate pweights for model `name'"
            continue, break
        }

        quietly count if `sample' & (missing(`weight') | `weight' <= 0)
        if r(N) {
            local rc 459
            di as err "model {bf:`name'} has " r(N) " missing or nonpositive pweights in its stored estimation sample"
            continue, break
        }

        quietly generate byte `conflict' = `sample' & !missing(`pwvar') & ///
            reldif(`weight', `pwvar') >= 1e-6
        quietly count if `conflict'
        if r(N) {
            local nconflict = r(N)
            quietly summarize `obsno' if `conflict', meanonly
            local first = r(min)
            quietly summarize `owner' if `obsno' == `first', meanonly
            local priorindex = r(mean)
            local prior : word `priorindex' of `names'
            quietly summarize `pwvar' if `obsno' == `first', meanonly
            local priorw = r(mean)
            quietly summarize `weight' if `obsno' == `first', meanonly
            local currentw = r(mean)
            di as err "pweights disagree on `nconflict' observation(s) shared by models {bf:`prior'} and {bf:`name'}"
            di as err "first conflict: observation `first' has weight " %12.8g `priorw' " in {bf:`prior'} and " %12.8g `currentw' " in {bf:`name'}"
            di as err "weights may differ outside overlapping estimation samples, but must agree on every shared observation"
            local rc 322
            continue, break
        }

        quietly replace `pwvar' = `weight' if `sample' & missing(`pwvar')
        quietly replace `owner' = `i' if `sample' & missing(`owner')
        quietly replace `union' = 1 if `sample'
    }

    if `rc' {
        capture drop `pwvar'
        if `"`errstage'"' != "" di as err "unable to `errstage'"
        exit `rc'
    }

    // Refit with iweights on the same evaluated union weight.  Preserve each
    // model's exact sample even when missing values in its original weight
    // expression acted as sample restrictions: before each refit, expose the
    // common weight variable only on that model's stored sample.
    tempvar fullpw
    quietly generate double `fullpw' = `pwvar'
    forvalues i = 1/`nmodels' {
        local name : word `i' of `names'
        local original `"`cmdline`i''"'
        local iwcmd = ustrregexra(`"`original'"', ///
            "(?i)\[[ ]*(pw(e(i(g(h(t)?)?)?)?)?)[ ]*=[^]]+\]", "[iweight=`pwvar']")
        local iwcmd = ustrregexra(`"`iwcmd'"', ///
            "(?i)vce[ ]*\([ ]*robust[ ]*\)", "")

        if `"`iwcmd'"' == `"`original'"' {
            local rc 198
            di as err "suest2 could not locate the pweight specification in the stored command for model {bf:`name'}"
            di as err "stored command: `original'"
            continue, break
        }
        if ustrregexm(`"`iwcmd'"', "(?i)(^|[ ,])robust([ ,]|$)") {
            local rc 198
            di as err "model {bf:`name'} uses the standalone {bf:robust} option"
            di as err "refit without explicitly specifying robust; pweights already imply robust inference"
            continue, break
        }

        quietly replace `pwvar' = .
        quietly replace `pwvar' = `fullpw' if `sample`i''
        capture quietly `iwcmd'
        if _rc {
            local rc = _rc
            di as err "unable to reconstruct the iweight reference model for {bf:`name'}"
            di as err "reconstructed command: `iwcmd'"
            continue, break
        }

        quietly count if e(sample) != `sample`i''
        if r(N) {
            local rc 459
            di as err "the reconstructed sample for model {bf:`name'} differs from its stored estimation sample on " r(N) " observation(s)"
            di as err "the data or variables used by the stored command may have changed since estimation"
            continue, break
        }

        tempname bi`i'
        matrix `bi`i'' = e(b)
        if mreldif(`bp`i'', `bi`i'') > 1e-8 {
            local rc 498
            di as err "the reconstructed iweight coefficients for model {bf:`name'} do not reproduce its pweight coefficients"
            di as err "maximum relative matrix difference: " %12.5g mreldif(`bp`i'', `bi`i'')
            continue, break
        }

        // No vce conversion here. Measured (diag_pweight_trace PART C):
        // the iweight refit stores e(vce)="oim" with no e(vcetype) and no
        // e(V_modelbased), so suest's guard never fires on these clones.
        tempname clone
        local clone`i' `clone'
        quietly estimates store `clone`i''
        local clones `"`clones' `clone`i''"'
    }

    if `rc' {
        foreach clone of local clones {
            capture quietly estimates drop `clone'
        }
        capture drop `pwvar'
        exit `rc'
    }

    // Official suest and later margins see the coherent union weight.
    quietly replace `pwvar' = `fullpw'

    local suestopts `"`cluster' `vce' `minus' `regressml' `robust' `level' `eform' `options'"'
    if trim(`"`suestopts'"') == "" capture quietly suest `clones'
    else capture quietly suest `clones', `suestopts'
    local rc = _rc
    if `rc' {
        foreach clone of local clones {
            capture quietly estimates drop `clone'
        }
        capture drop `pwvar'
        di as err "official suest could not combine the reconstructed pweight reference models"
        di as err "return code `rc'"
        exit `rc'
    }

    // Replace private clone prefixes in the official coefficient stripes with
    // the original user-facing stored-estimate names.
    tempname b V
    matrix `b' = e(b)
    matrix `V' = e(V)

    // Keep the original pweight point estimates exactly.  Official suest adds
    // one lnvar parameter after each regress block. Binary, Poisson, ordered,
    // and multinomial blocks use the constituent coefficient vector directly;
    // nbreg includes lnalpha there.
    local bcursor 1
    forvalues i = 1/`nmodels' {
        local kp = colsof(`bp`i'')
        matrix `b'[1,`bcursor'] = `bp`i''
        local kannc 0
        if "`cmd`i''" == "regress" local kannc 1
        local bcursor = `bcursor' + `kp' + `kannc'
    }
    if `bcursor' - 1 != colsof(`b') {
        foreach clone of local clones {
            capture quietly estimates drop `clone'
        }
        capture drop `pwvar'
        local ktotal = colsof(`b')
        local kmapped = `bcursor' - 1
        di as err "suest2 could not map the pweight coefficient blocks into the combined result"
        di as err "combined parameters: `ktotal'; mapped parameters: `kmapped'"
        exit 498
    }

    local oldeq : coleq `b'
    local neweq
    foreach eq of local oldeq {
        local eqnew `"`eq'"'
        forvalues i = 1/`nmodels' {
            local name : word `i' of `names'
            local eqnew : subinstr local eqnew "`clone`i''" "`name'", all
        }
        local neweq `"`neweq' `eqnew'"'
    }
    capture matrix coleq `b' = `neweq'
    local rc = _rc
    if !`rc' capture matrix coleq `V' = `neweq'
    if !`rc' local rc = _rc
    if !`rc' capture matrix roweq `V' = `neweq'
    if !`rc' local rc = _rc
    if !`rc' capture ereturn repost b=`b' V=`V', rename
    if !`rc' local rc = _rc
    if `rc' {
        foreach clone of local clones {
            capture quietly estimates drop `clone'
        }
        capture drop `pwvar'
        di as err "suest2 could not restore the original model names in the combined coefficient vector"
        exit `rc'
    }

    foreach clone of local clones {
        capture quietly estimates drop `clone'
    }

    // Reuse an existing constituent weight expression when it reproduces the
    // composite weight over the entire union.  Otherwise retain the hidden
    // composite variable so official margins has a valid system weight.
    local finalwexp
    forvalues i = 1/`nmodels' {
        if `"`finalwexp'"' != "" continue
        tempvar candidate
        capture generate double `candidate' `wexp`i''
        if !_rc {
            quietly count if `union' & (missing(`candidate') | ///
                reldif(`candidate', `pwvar') >= 1e-6)
            if r(N) == 0 local finalwexp `"`wexp`i''"'
        }
    }

    if `"`finalwexp'"' == "" {
        local finalwexp "= `pwvar'"
        ereturn local suest2_weightvar `"`pwvar'"'
        ereturn scalar suest2_composite_weight = 1
    }
    else {
        capture drop `pwvar'
        ereturn local suest2_weightvar
        ereturn scalar suest2_composite_weight = 0
    }

    quietly count if `union'
    ereturn scalar N = r(N)
    ereturn local names `"`names'"'
    ereturn local wtype "pweight"
    ereturn local wexp `"`finalwexp'"'
    ereturn scalar suest2_pweight = 1
    ereturn scalar suest2_weight_overlap_checked = 1
    ereturn local suest2_pweight_engine "iweight_reference"
end

// ============================================================================
// Fixed-effects stored-estimates route
// ============================================================================

// ============================================================================
// Stored ivregress 2sls route
// ============================================================================

program define suest2_ivregress_svyestimate, sortpreserve eclass
    version 16
    syntax [anything] [, CLuster(passthru) VCE(passthru) Robust MINUS ///
        REGRESSML SVY Level(cilevel) DIR EForm(passthru) *]

    if "`minus'"!="" | "`regressml'"!="" {
        di as err "options minus and regressml are not supported for survey ivregress 2sls systems"
        exit 198
    }

    quietly suest2_svycheck `0'
    local survey_subpop `"`r(subpop)'"'

    local displayopts
    if "`level'"!="" local displayopts `"`displayopts' level(`level')"'
    if "`dir'"!="" local displayopts `"`displayopts' dir"'
    if `"`eform'"'!="" local displayopts `"`displayopts' `eform'"'
    if trim(`"`options'"')!="" local displayopts `"`displayopts' `options'"'

    est_expand `"`anything'"', min(2) default(.)
    local names `"`r(names)'"'
    local names : list uniq names
    local nmodels : word count `names'
    local hasdot : list posof "." in names
    if `hasdot' {
        di as err "survey ivregress 2sls support requires named stored estimates"
        di as err "store each model with {bf:estimates store} before running {bf:suest2}"
        exit 198
    }

    local rc 0
    local errtext
    local cleanupvars
    local cleanupmats
    local allif
    local allcn
    local alleq

    forvalues i=1/`nmodels' {
        local name : word `i' of `names'
        capture quietly estimates restore `name'
        if _rc {
            local rc=_rc
            local errtext "unable to restore constituent model `name'"
            continue, break
        }

        if "`e(cmd)'"!="ivregress" | "`e(estimator)'"!="2sls" {
            local rc 322
            local errtext "every constituent model must be a survey ivregress 2sls estimate"
            continue, break
        }
        if "`e(prefix)'"!="svy" | "`e(vce)'"!="linearized" {
            local rc 322
            local errtext "every constituent model must be estimated with linearized svy: ivregress 2sls"
            continue, break
        }
        if "`e(wtype)'"!="pweight" {
            local rc 498
            local errtext "survey ivregress model `name' does not retain its pweight declaration"
            continue, break
        }
        foreach macro in depvar endog exog {
            if trim(`"`e(`macro')'"')=="" {
                local rc 498
                local errtext "model `name' does not retain e(`macro')"
                continue, break
            }
        }
        if `rc' continue, break
        foreach scalar in N rank {
            capture confirm scalar e(`scalar')
            if _rc {
                local rc 498
                local errtext "model `name' does not retain e(`scalar')"
                continue, break
            }
        }
        if `rc' continue, break
        foreach matrix in b V V_modelbased {
            capture confirm matrix e(`matrix')
            if _rc {
                local rc 498
                local errtext "model `name' does not retain e(`matrix')"
                continue, break
            }
        }
        if `rc' continue, break

        tempname pfx
        local pfx`i' `pfx'
        local bsrc `pfx'_b
        local Hsrc `pfx'_H
        local Vsrc `pfx'_V
        local Osrc `pfx'_O
        local bsrc`i' `bsrc'
        local Hsrc`i' `Hsrc'
        local Vsrc`i' `Vsrc'
        local cleanupmats `cleanupmats' `bsrc' `Hsrc' `Vsrc' `Osrc'
        matrix `bsrc'=e(b)
        matrix `Hsrc'=e(V_modelbased)
        matrix `Vsrc'=e(V)
        _ms_omit_info `bsrc'
        matrix `Osrc'=r(omit)

        local K`i'=colsof(`bsrc')
        local rank`i'=e(rank)
        local N`i'=e(N)
        local depvar`i' `"`e(depvar)'"'
        local endog`i' `"`e(endog)'"'
        local exog`i' `"`e(exog)'"'
        local wtype`i' `"`e(wtype)'"'
        local wexp`i' `"`e(wexp)'"'
        local nativecn`i' : colnames `bsrc'
        local nendog`i' : word count `endog`i''
        local nscore`i'=`nendog`i''+1

        tempvar sample
        local sample`i' `sample'
        local cleanupvars `cleanupvars' `sample'
        quietly generate byte `sample'=e(sample)
        quietly count if `sample'
        if r(N)!=`N`i'' {
            local rc 459
            local errtext "the current data no longer reproduce the stored estimation sample for model `name'"
            continue, break
        }

        local nativescores
        forvalues h=1/`nscore`i'' {
            tempvar ns
            local cleanupvars `cleanupvars' `ns'
            local nativescores `nativescores' `ns'
        }
        capture quietly predict double `nativescores' if `sample', scores
        if _rc {
            local rc=_rc
            local errtext "unable to generate native ivregress scores for survey model `name'"
            continue, break
        }
        local eqscore : word `nscore`i'' of `nativescores'

        local scorelist
        forvalues j=1/`K`i'' {
            local coef : word `j' of `nativecn`i''
            tempvar sc
            local cleanupvars `cleanupvars' `sc'
            quietly generate double `sc'=0
            local omitted=el(`Osrc',1,`j')
            if !`omitted' {
                local matched 0
                forvalues h=1/`nendog`i'' {
                    local ev : word `h' of `endog`i''
                    if `"`coef'"'==`"`ev'"' {
                        local es : word `h' of `nativescores'
                        quietly replace `sc'=`es' if `sample'
                        local matched 1
                    }
                }
                if !`matched' & "`coef'"=="_cons" {
                    quietly replace `sc'=`eqscore' if `sample'
                    local matched 1
                }
                if !`matched' {
                    capture quietly fvrevar `coef'
                    if _rc {
                        local rc=_rc
                        local errtext "unable to reconstruct design column `coef' for survey model `name'"
                        continue, break
                    }
                    local raw `"`r(varlist)'"'
                    local nraw : word count `raw'
                    if `nraw'!=1 {
                        local rc 498
                        local errtext "design column `coef' did not expand to exactly one variable for survey model `name'"
                        continue, break
                    }
                    quietly replace `sc'=`raw'*`eqscore' if `sample'
                }
            }
            local scorelist `scorelist' `sc'
        }
        if `rc' continue, break
        local scores`i' `scorelist'

        foreach sc of local scorelist {
            quietly summarize `sc' if `sample', meanonly
            if r(N)!=`N`i'' | r(min)>=. | r(max)>=. {
                local rc 498
                local errtext "native ivregress score expansion produced missing values for survey model `name'"
                continue, break
            }
        }
        if `rc' continue, break
    }

    if `rc' {
        foreach v of local cleanupvars {
            capture drop `v'
        }
        foreach m of local cleanupmats {
            capture matrix drop `m'
        }
        di as err "`errtext'"
        exit `rc'
    }

    tempvar union
    quietly generate byte `union'=0
    forvalues i=1/`nmodels' {
        quietly replace `union'=1 if `sample`i''
    }
    quietly count if `union'
    local Nsys=r(N)

    local Ktotal 0
    forvalues i=1/`nmodels' {
        local start`i'=`Ktotal'+1
        local Ktotal=`Ktotal'+`K`i''
        local end`i'=`Ktotal'

        local iflist
        forvalues j=1/`K`i'' {
            tempvar ivf
            quietly generate double `ivf'=0
            local cleanupvars `cleanupvars' `ivf'
            local iflist `iflist' `ivf'
            local allif `allif' `ivf'
        }
        local ifs`i' `iflist'
        mata: suest2_iv2sls_if_mata("`sample`i''","`scores`i''", ///
            "`Hsrc`i''","`iflist'")
        foreach v of local iflist {
            quietly replace `v'=0 if missing(`v')
        }
    }

    tempname bout Vout
    local eqused
    forvalues i=1/`nmodels' {
        local name : word `i' of `names'
        local eq=substr(strtoname("`name'_mean"),1,32)
        local duplicate : list posof "`eq'" in eqused
        if `duplicate' local eq=substr("s2iv`i'_mean",1,32)
        local duplicate : list posof "`eq'" in eqused
        if `duplicate' {
            foreach v of local cleanupvars {
                capture drop `v'
            }
            foreach m of local cleanupmats {
                capture matrix drop `m'
            }
            di as err "suest2 could not construct unique equation names for the survey ivregress 2sls system"
            exit 498
        }
        local eqused `"`eqused' `eq'"'
        local eqname`i' `"`eq'"'
        local eqlist
        forvalues j=1/`K`i'' {
            local eqlist `eqlist' `eq'
        }
        local allcn `allcn' `nativecn`i''
        local alleq `alleq' `eqlist'

        tempname bi
        matrix `bi'=`bsrc`i''
        matrix coleq `bi'=`eqlist'
        if `i'==1 matrix `bout'=`bi'
        else matrix `bout'=`bout',`bi'
    }

    if trim(`"`survey_subpop'"')=="" {
        capture quietly svy: total `allif'
    }
    else {
        capture quietly svy, subpop(`survey_subpop'): total `allif'
    }
    if _rc {
        local rc=_rc
        foreach v of local cleanupvars {
            capture drop `v'
        }
        foreach m of local cleanupmats {
            capture matrix drop `m'
        }
        di as err "unable to apply the active survey design to the stacked ivregress influence variables"
        exit `rc'
    }
    matrix `Vout'=e(V)
    local svydf=e(df_r)
    local svyNpsu=e(N_psu)
    local svyNstrata=e(N_strata)
    local svyNpop=e(N_pop)
    local svywtype `"`e(wtype)'"'
    local svywexp `"`e(wexp)'"'
    local svyNsub .
    capture local svyNsub=e(N_sub)

    if rowsof(`Vout')!=`Ktotal' | colsof(`Vout')!=`Ktotal' {
        foreach v of local cleanupvars {
            capture drop `v'
        }
        foreach m of local cleanupmats {
            capture matrix drop `m'
        }
        di as err "the survey linearization returned an unexpected covariance dimension"
        exit 498
    }

    matrix colnames `bout'=`allcn'
    matrix coleq `bout'=`alleq'
    matrix colnames `Vout'=`allcn'
    matrix rownames `Vout'=`allcn'
    matrix coleq `Vout'=`alleq'
    matrix roweq `Vout'=`alleq'

    forvalues i=1/`nmodels' {
        local name : word `i' of `names'
        tempname Vblock
        matrix `Vblock'=`Vout'[`start`i''..`end`i'',`start`i''..`end`i'']
        mata: st_numscalar("__s2iv_diagdiff",max(abs(st_matrix("`Vblock'"):-st_matrix("`Vsrc`i''"))))
        mata: st_numscalar("__s2iv_diagscale",1+max(abs(st_matrix("`Vsrc`i''"))))
        if scalar(__s2iv_diagdiff)>1e-9*scalar(__s2iv_diagscale) {
            foreach v of local cleanupvars {
                capture drop `v'
            }
            foreach m of local cleanupmats {
                capture matrix drop `m'
            }
            di as err "the stacked survey-IV covariance does not reproduce the native block for model {bf:`name'}"
            di as err "the active svyset declaration, weights, subpopulation, or analysis data may have changed"
            exit 459
        }
    }

    ereturn post `bout' `Vout', obs(`Nsys') esample(`union')
    mata: st_numscalar("__s2_ivrank",rank(st_matrix("`Vout'")))
    ereturn scalar rank=scalar(__s2_ivrank)
    ereturn scalar df_r=`svydf'
    ereturn scalar N_psu=`svyNpsu'
    ereturn scalar N_strata=`svyNstrata'
    ereturn scalar N_pop=`svyNpop'
    if `svyNsub'<. ereturn scalar N_sub=`svyNsub'
    ereturn local vce "linearized"
    ereturn local vcetype "Linearized"
    ereturn local prefix "svy"
    ereturn local wtype `"`svywtype'"'
    ereturn local wexp `"`svywexp'"'
    if trim(`"`survey_subpop'"')!="" ereturn local subpop `"`survey_subpop'"'
    ereturn local names `"`names'"'
    ereturn local properties "b V"
    ereturn scalar suest2_ivregress=1
    ereturn scalar suest2_svy=1
    ereturn local suest2_ivregress_engine "native_ivregress_scores_svy_total"
    ereturn local suest2_ivregress_displayopts `"`displayopts'"'
    ereturn local title "Simultaneous survey instrumental-variables 2SLS results"
    ereturn local cmd "suest2_ivregress_svy"

    forvalues i=1/`nmodels' {
        ereturn local eqnames`i' `"`eqname`i''"'
        ereturn scalar suest2_ivregress_N`i'=`N`i''
        ereturn scalar suest2_ivregress_K`i'=`K`i''
        ereturn scalar suest2_ivregress_rank`i'=`rank`i''
        ereturn scalar suest2_ivregress_nendog`i'=`nendog`i''
        ereturn local suest2_ivregress_endog`i' `"`endog`i''"'
        ereturn local suest2_ivregress_exog`i' `"`exog`i''"'
    }

    foreach v of local cleanupvars {
        capture drop `v'
    }
    foreach m of local cleanupmats {
        capture matrix drop `m'
    }
end

program define suest2_ivregressestimate, sortpreserve eclass
    version 16
    syntax [anything] [, CLuster(varname) VCE(string asis) Robust MINUS ///
        REGRESSML SVY Level(cilevel) DIR EForm(passthru) *]

    if "`minus'"!="" | "`regressml'"!="" | "`svy'"!="" {
        di as err "options minus, regressml, and svy are not supported for ivregress 2sls systems"
        exit 198
    }

    local displayopts
    if "`level'"!="" local displayopts `"`displayopts' level(`level')"'
    if "`dir'"!="" local displayopts `"`displayopts' dir"'
    if `"`eform'"'!="" local displayopts `"`displayopts' `eform'"'
    if trim(`"`options'"')!="" local displayopts `"`displayopts' `options'"'

    if "`cluster'"!="" & trim(`"`vce'"')!="" {
        di as err "specify only one of cluster() or vce()"
        exit 198
    }
    if "`cluster'"!="" & "`robust'"!="" {
        di as err "specify only one of cluster() or robust"
        exit 198
    }
    if trim(`"`vce'"')!="" & "`robust'"!="" {
        di as err "specify only one of vce() or robust"
        exit 198
    }

    local requested_cluster `"`cluster'"'
    if trim(`"`vce'"')!="" {
        local vcelower=ustrlower(itrim(trim(`"`vce'"')))
        if "`vcelower'"=="robust" local requested_cluster
        else if ustrregexm(`"`vcelower'"',"^cluster[ ]+([A-Za-z_][A-Za-z0-9_]*)$") {
            local requested_cluster `"`=ustrregexs(1)'"'
        }
        else if ustrregexm(`"`vcelower'"',"^cluster[ ]*\([ ]*([A-Za-z_][A-Za-z0-9_]*)[ ]*\)$") {
            local requested_cluster `"`=ustrregexs(1)'"'
        }
        else {
            di as err "the ivregress 2sls route supports only vce(robust) or vce(cluster varname)"
            exit 198
        }
    }

    est_expand `"`anything'"', min(2) default(.)
    local names `"`r(names)'"'
    local names : list uniq names
    local nmodels : word count `names'
    local hasdot : list posof "." in names
    if `hasdot' {
        di as err "ivregress 2sls support requires named stored estimates"
        di as err "store each model with {bf:estimates store} before running {bf:suest2}"
        exit 198
    }

    local rc 0
    local errtext
    local cleanupvars
    local cleanupmats
    local allif
    local allcn
    local alleq

    forvalues i=1/`nmodels' {
        local name : word `i' of `names'
        capture quietly estimates restore `name'
        if _rc {
            local rc=_rc
            local errtext "unable to restore constituent model `name'"
            continue, break
        }

        if "`e(cmd)'"!="ivregress" | "`e(estimator)'"!="2sls" {
            local rc 322
            local errtext "the first ivregress increment requires every constituent model to be ivregress 2sls"
            continue, break
        }
        if trim(`"`e(wtype)'"')!="" {
            local rc 198
            local errtext "weights are not yet supported for ivregress 2sls systems"
            continue, break
        }
        if !inlist(`"`e(vce)'"',"","unadjusted","conventional") {
            local rc 322
            local errtext "store conventional ivregress 2sls estimates and request robust or clustered VCE with suest2"
            continue, break
        }
        if trim(`"`e(prefix)'"')!="" {
            local rc 198
            local errtext "prefix-estimated ivregress 2sls results are not yet supported"
            continue, break
        }

        foreach macro in cmdline depvar endog exog exogr {
            if trim(`"`e(`macro')'"')=="" {
                local rc 498
                local errtext "model `name' does not retain e(`macro')"
                continue, break
            }
        }
        if `rc' continue, break
        foreach scalar in N rank {
            capture confirm scalar e(`scalar')
            if _rc {
                local rc 498
                local errtext "model `name' does not retain e(`scalar')"
                continue, break
            }
        }
        if `rc' continue, break
        capture confirm matrix e(b)
        if _rc {
            local rc=_rc
            local errtext "model `name' does not contain e(b)"
            continue, break
        }

        tempname pfx
        local pfx`i' `pfx'
        local bsrc `pfx'_b
        local Hsrc `pfx'_H
        local Vrob `pfx'_Vr
        local bref `pfx'_br
        local bsrc`i' `bsrc'
        local Hsrc`i' `Hsrc'
        local Vrob`i' `Vrob'
        local cleanupmats `cleanupmats' `bsrc' `Hsrc' `Vrob' `bref'
        matrix `bsrc'=e(b)
        local K`i'=colsof(`bsrc')
        local rank`i'=e(rank)
        local N`i'=e(N)
        local depvar`i' `"`e(depvar)'"'
        local endog`i' `"`e(endog)'"'
        local exog`i' `"`e(exog)'"'
        local exogr`i' `"`e(exogr)'"'
        local cmdline`i' `"`e(cmdline)'"'
        local nativecn`i' : colnames `bsrc'

        local conspos : list posof "_cons" in nativecn`i'
        if !`conspos' {
            local rc 198
            local errtext "noconstant ivregress 2sls models are not supported in the first increment"
            continue, break
        }

        tempvar sample sampleref resid
        local sample`i' `sample'
        local resid`i' `resid'
        local cleanupvars `cleanupvars' `sample' `sampleref' `resid'
        quietly generate byte `sample'=e(sample)
        quietly count if `sample'
        if r(N)!=`N`i'' {
            local rc 459
            local errtext "the current data no longer reproduce the stored estimation sample for model `name'"
            continue, break
        }

        local refit `"`cmdline`i''"'
        if strpos(`"`refit'"',",") local refit `"`refit' vce(robust)"'
        else local refit `"`refit', vce(robust)"'
        capture quietly `refit'
        if _rc {
            local rc=_rc
            local errtext "the current data cannot re-estimate stored ivregress 2sls model `name'"
            continue, break
        }
        matrix `bref'=e(b)
        matrix `Hsrc'=e(V_modelbased)
        matrix `Vrob'=e(V)
        quietly generate byte `sampleref'=e(sample)
        quietly count if `sample'!=`sampleref'
        if r(N) {
            local rc 459
            local errtext "the current data do not reproduce the stored estimation sample for model `name'"
            continue, break
        }
        mata: st_numscalar("__s2iv_bdiff",max(abs(st_matrix("`bsrc'"):-st_matrix("`bref'"))))
        mata: st_numscalar("__s2iv_bscale",1+max(abs(st_matrix("`bsrc'"))))
        if scalar(__s2iv_bdiff)>1e-10*scalar(__s2iv_bscale) {
            local rc 459
            local errtext "the current data do not reproduce the stored ivregress 2sls coefficients for model `name'"
            continue, break
        }

        capture quietly predict double `resid' if `sample', residuals
        if _rc {
            local rc=_rc
            local errtext "unable to generate structural residuals for model `name'"
            continue, break
        }

        local nhat 0
        foreach ev of local endog`i' {
            tempvar xhat
            local ++nhat
            local xhat`i'_`nhat' `xhat'
            local endogword`i'_`nhat' `"`ev'"'
            local cleanupvars `cleanupvars' `xhat'
            capture quietly regress `ev' `exog`i'' if `sample'
            if _rc {
                local rc=_rc
                local errtext "unable to reproduce the first-stage projection for endogenous variable `ev' in model `name'"
                continue, break
            }
            capture quietly predict double `xhat' if `sample', xb
            if _rc {
                local rc=_rc
                local errtext "unable to generate the first-stage fitted value for endogenous variable `ev' in model `name'"
                continue, break
            }
        }
        if `rc' continue, break
        local nendog`i'=`nhat'

        local scorelist
        forvalues j=1/`K`i'' {
            local coef : word `j' of `nativecn`i''
            tempvar sc
            local cleanupvars `cleanupvars' `sc'
            local matched 0

            forvalues h=1/`nendog`i'' {
                if `"`coef'"'==`"`endogword`i'_`h''"' {
                    quietly generate double `sc'=`xhat`i'_`h''*`resid' if `sample'
                    local matched 1
                }
            }
            if !`matched' & "`coef'"=="_cons" {
                quietly generate double `sc'=`resid' if `sample'
                local matched 1
            }
            if !`matched' {
                capture quietly fvrevar `coef'
                if _rc {
                    local rc=_rc
                    local errtext "unable to reconstruct design column `coef' for model `name'"
                    continue, break
                }
                local raw `"`r(varlist)'"'
                local nraw : word count `raw'
                if `nraw'!=1 {
                    local rc 498
                    local errtext "design column `coef' did not expand to exactly one variable for model `name'"
                    continue, break
                }
                quietly generate double `sc'=`raw'*`resid' if `sample'
            }
            local scorelist `scorelist' `sc'
        }
        if `rc' continue, break
        local scores`i' `scorelist'

        foreach sc of local scorelist {
            quietly summarize `sc' if `sample', meanonly
            if r(N)!=`N`i'' | r(min)>=. | r(max)>=. {
                local rc 498
                local errtext "the 2SLS score construction produced missing values for model `name'"
                continue, break
            }
        }
        if `rc' continue, break
    }

    if `rc' {
        foreach v of local cleanupvars {
            capture drop `v'
        }
        foreach m of local cleanupmats {
            capture matrix drop `m'
        }
        di as err "`errtext'"
        exit `rc'
    }

    local scorevar `"`requested_cluster'"'
    if trim(`"`scorevar'"')!="" {
        capture confirm numeric variable `scorevar'
        if _rc {
            local rc=_rc
            foreach v of local cleanupvars {
                capture drop `v'
            }
            foreach m of local cleanupmats {
                capture matrix drop `m'
            }
            di as err "cluster variable {bf:`scorevar'} must exist and be numeric"
            exit `rc'
        }
    }

    tempvar union
    quietly generate byte `union'=0
    forvalues i=1/`nmodels' {
        quietly replace `union'=1 if `sample`i''
        if trim(`"`scorevar'"')!="" {
            quietly count if `sample`i'' & missing(`scorevar')
            if r(N) {
                foreach v of local cleanupvars {
                    capture drop `v'
                }
                foreach m of local cleanupmats {
                    capture matrix drop `m'
                }
                local name : word `i' of `names'
                di as err "cluster variable {bf:`scorevar'} is missing in the estimation sample for model {bf:`name'}"
                exit 459
            }
        }
    }
    quietly count if `union'
    local Nsys=r(N)

    if trim(`"`scorevar'"')!="" {
        tempvar tagcluster
        quietly egen byte `tagcluster'=tag(`scorevar') if `union'
        quietly count if `tagcluster'
        local Gsys=r(N)
        if `Gsys'<2 {
            foreach v of local cleanupvars {
                capture drop `v'
            }
            foreach m of local cleanupmats {
                capture matrix drop `m'
            }
            di as err "the ivregress 2sls system contains fewer than two clusters in {bf:`scorevar'}"
            exit 459
        }
    }

    local Ktotal 0
    forvalues i=1/`nmodels' {
        local start`i'=`Ktotal'+1
        local Ktotal=`Ktotal'+`K`i''
        local end`i'=`Ktotal'

        local iflist
        forvalues j=1/`K`i'' {
            tempvar ivf
            quietly generate double `ivf'=0
            local cleanupvars `cleanupvars' `ivf'
            local iflist `iflist' `ivf'
            local allif `allif' `ivf'
        }
        local ifs`i' `iflist'
        mata: suest2_iv2sls_if_mata("`sample`i''","`scores`i''", ///
            "`Hsrc`i''","`iflist'")
    }

    tempname bout Vout
    local eqused
    forvalues i=1/`nmodels' {
        local name : word `i' of `names'
        local eq=substr(strtoname("`name'_mean"),1,32)
        local duplicate : list posof "`eq'" in eqused
        if `duplicate' local eq=substr("s2iv`i'_mean",1,32)
        local duplicate : list posof "`eq'" in eqused
        if `duplicate' {
            foreach v of local cleanupvars {
                capture drop `v'
            }
            foreach m of local cleanupmats {
                capture matrix drop `m'
            }
            di as err "suest2 could not construct unique equation names for the ivregress 2sls system"
            exit 498
        }
        local eqused `"`eqused' `eq'"'
        local eqname`i' `"`eq'"'
        local eqlist
        forvalues j=1/`K`i'' {
            local eqlist `eqlist' `eq'
        }
        local allcn `allcn' `nativecn`i''
        local alleq `alleq' `eqlist'

        tempname bi
        matrix `bi'=`bsrc`i''
        matrix coleq `bi'=`eqlist'
        if `i'==1 matrix `bout'=`bi'
        else matrix `bout'=`bout',`bi'
    }

    mata: suest2_iv2sls_vce_mata("`union'","`allif'", ///
        "`scorevar'","`Vout'")
    matrix colnames `bout'=`allcn'
    matrix coleq `bout'=`alleq'
    matrix colnames `Vout'=`allcn'
    matrix rownames `Vout'=`allcn'
    matrix coleq `Vout'=`alleq'
    matrix roweq `Vout'=`alleq'

    forvalues i=1/`nmodels' {
        local name : word `i' of `names'
        tempname Vblock Vtarget bref2
        matrix `Vblock'=`Vout'[`start`i''..`end`i'',`start`i''..`end`i'']

        if trim(`"`scorevar'"')=="" matrix `Vtarget'=`Vrob`i''
        else {
            local refit `"`cmdline`i''"'
            if strpos(`"`refit'"',",") local refit `"`refit' vce(cluster `scorevar')"'
            else local refit `"`refit', vce(cluster `scorevar')"'
            capture quietly `refit'
            if _rc {
                local rc=_rc
                foreach v of local cleanupvars {
                    capture drop `v'
                }
                foreach m of local cleanupmats {
                    capture matrix drop `m'
                }
                di as err "unable to reproduce native clustered 2SLS covariance for model {bf:`name'}"
                exit `rc'
            }
            matrix `bref2'=e(b)
            matrix `Vtarget'=e(V)
            mata: st_numscalar("__s2iv_bdiff2",max(abs(st_matrix("`bsrc`i''"):-st_matrix("`bref2'"))))
            mata: st_numscalar("__s2iv_bscale2",1+max(abs(st_matrix("`bsrc`i''"))))
            if scalar(__s2iv_bdiff2)>1e-10*scalar(__s2iv_bscale2) {
                foreach v of local cleanupvars {
                    capture drop `v'
                }
                foreach m of local cleanupmats {
                    capture matrix drop `m'
                }
                di as err "the clustered refit changed coefficients for model {bf:`name'}"
                exit 459
            }
        }
        mata: st_numscalar("__s2iv_diagdiff",max(abs(st_matrix("`Vblock'"):-st_matrix("`Vtarget'"))))
        mata: st_numscalar("__s2iv_diagscale",1+max(abs(st_matrix("`Vtarget'"))))
        if scalar(__s2iv_diagdiff)>1e-10*scalar(__s2iv_diagscale) {
            foreach v of local cleanupvars {
                capture drop `v'
            }
            foreach m of local cleanupmats {
                capture matrix drop `m'
            }
            di as err "the joint 2SLS covariance does not reproduce the native block for model {bf:`name'}"
            exit 498
        }
    }

    ereturn post `bout' `Vout', obs(`Nsys') esample(`union')
    mata: st_numscalar("__s2_ivrank",rank(st_matrix("`Vout'")))
    ereturn scalar rank=scalar(__s2_ivrank)
    if trim(`"`scorevar'"')=="" {
        ereturn local vce "robust"
        ereturn local vcetype "Robust"
    }
    else {
        ereturn scalar N_clust=`Gsys'
        ereturn local clustvar `"`scorevar'"'
        ereturn local vce "cluster"
        ereturn local vcetype "Robust"
    }
    ereturn local names `"`names'"'
    ereturn local properties "b V"
    ereturn scalar suest2_ivregress=1
    ereturn local suest2_ivregress_engine "raw_2sls_coefficient_influence_crossproducts"
    ereturn local suest2_ivregress_displayopts `"`displayopts'"'
    ereturn local title "Simultaneous instrumental-variables 2SLS results"
    ereturn local cmd "suest2_ivregress"

    forvalues i=1/`nmodels' {
        ereturn local eqnames`i' `"`eqname`i''"'
        ereturn scalar suest2_ivregress_N`i'=`N`i''
        ereturn scalar suest2_ivregress_K`i'=`K`i''
        ereturn scalar suest2_ivregress_rank`i'=`rank`i''
        ereturn scalar suest2_ivregress_nendog`i'=`nendog`i''
        ereturn local suest2_ivregress_endog`i' `"`endog`i''"'
        ereturn local suest2_ivregress_exog`i' `"`exog`i''"'
    }

    foreach v of local cleanupvars {
        capture drop `v'
    }
    foreach m of local cleanupmats {
        capture matrix drop `m'
    }
end

// ============================================================================
// Stored xtreg, be route
// ============================================================================

program define suest2_xtbeestimate, sortpreserve eclass
    version 16
    syntax [anything] [, CLuster(varname) VCE(string asis) Robust MINUS ///
        REGRESSML SVY Level(cilevel) DIR EForm(passthru) *]

    if "`minus'" != "" | "`regressml'" != "" | "`svy'" != "" {
        di as err "options minus, regressml, and svy are not supported for xtreg, be systems"
        exit 198
    }

    local displayopts
    if "`level'" != "" local displayopts `"`displayopts' level(`level')"'
    if "`dir'" != "" local displayopts `"`displayopts' dir"'
    if `"`eform'"' != "" local displayopts `"`displayopts' `eform'"'
    if trim(`"`options'"') != "" local displayopts `"`displayopts' `options'"'

    if "`cluster'" != "" & trim(`"`vce'"') != "" {
        di as err "specify only one of cluster() or vce()"
        exit 198
    }
    if "`cluster'" != "" & "`robust'" != "" {
        di as err "specify only one of cluster() or robust"
        exit 198
    }
    if trim(`"`vce'"') != "" & "`robust'" != "" {
        di as err "specify only one of vce() or robust"
        exit 198
    }

    local requested_cluster `"`cluster'"'
    if trim(`"`vce'"') != "" {
        local vcelower = ustrlower(itrim(trim(`"`vce'"')))
        if "`vcelower'" == "robust" local requested_cluster
        else if ustrregexm(`"`vcelower'"', "^cluster[ ]+([A-Za-z_][A-Za-z0-9_]*)$") {
            local requested_cluster `"`=ustrregexs(1)'"'
        }
        else if ustrregexm(`"`vcelower'"', "^cluster[ ]*\([ ]*([A-Za-z_][A-Za-z0-9_]*)[ ]*\)$") {
            local requested_cluster `"`=ustrregexs(1)'"'
        }
        else {
            di as err "the xtreg, be route supports only vce(robust) or vce(cluster varname)"
            exit 198
        }
    }

    est_expand `"`anything'"', min(2) default(.)
    local names `"`r(names)'"'
    local names : list uniq names
    local nmodels : word count `names'
    local hasdot : list posof "." in names
    if `hasdot' {
        di as err "xtreg, be support requires named stored estimates"
        di as err "store each model with {bf:estimates store} before running {bf:suest2}"
        exit 198
    }

    local bridges
    local rc 0
    local panelvar
    local scorevar
    local errtext

    forvalues i = 1/`nmodels' {
        local name : word `i' of `names'
        capture quietly estimates restore `name'
        if _rc {
            local rc = _rc
            local errtext "unable to restore constituent model `name'"
            continue, break
        }
        if "`e(cmd)'" != "xtreg" | "`e(model)'" != "be" {
            local rc 322
            local errtext "the first xtreg, be increment requires every constituent model to be xtreg, be"
            continue, break
        }
        local becmdline = ustrlower(`"`e(cmdline)'"')
        local haswls = ustrregexm(`"`becmdline'"', "(^|[, ]+)wls($|[, ]+)")
        if trim(`"`e(wtype)'"') != "" | trim(`"`e(typ)'"') != "" | `haswls' {
            local rc 198
            local errtext "weights and the undocumented wls option are not yet supported for xtreg, be systems"
            continue, break
        }

        local ivar `"`e(ivar)'"'
        if trim(`"`ivar'"') == "" {
            local rc 498
            local errtext "model `name' does not retain its panel identifier in e(ivar)"
            continue, break
        }
        if `i' == 1 local panelvar `"`ivar'"'
        else if `"`ivar'"' != `"`panelvar'"' {
            local rc 459
            local errtext "all xtreg, be constituent models must use the same panel variable"
            continue, break
        }

        capture confirm matrix e(b)
        if _rc {
            local rc = _rc
            local errtext "model `name' does not contain e(b)"
            continue, break
        }
        capture confirm scalar e(rank)
        if _rc {
            local rc 498
            local errtext "model `name' does not retain e(rank)"
            continue, break
        }

        tempname bsrc omit A At btarget bbridge bfull
        matrix `bsrc' = e(b)
        local bsrc`i' `bsrc'
        local korig`i' = colsof(`bsrc')
        local nativerank`i' = e(rank)
        local N`i' = e(N)
        local Ng_native`i' = e(N_g)
        local depvar`i' `"`e(depvar)'"'

        tempvar sample
        quietly generate byte `sample' = e(sample)
        local sample`i' `sample'
        quietly count if `sample'
        if r(N) != `N`i'' {
            local rc 459
            local errtext "the current data no longer reproduce the stored estimation sample for model `name'"
            continue, break
        }

        quietly _ms_omit_info `bsrc'
        matrix `omit' = r(omit)
        local cnames : colnames `bsrc'
        local conspos 0
        local p 0
        local xmeanlist

        forvalues j = 1/`korig`i'' {
            local coef : word `j' of `cnames'
            local omitted = `omit'[1,`j']
            if "`coef'" == "_cons" {
                local conspos = `j'
                continue
            }
            if `omitted' continue

            capture quietly fvrevar `coef'
            if _rc {
                local rc = _rc
                local errtext "unable to reconstruct design column `coef' for model `name'"
                continue, break
            }
            local raw `"`r(varlist)'"'
            local nraw : word count `raw'
            if `nraw' != 1 {
                local rc 498
                local errtext "design column `coef' did not expand to exactly one variable for model `name'"
                continue, break
            }
            capture confirm numeric variable `raw'
            if _rc {
                local rc = _rc
                local errtext "design column `coef' is not numeric for model `name'"
                continue, break
            }
            quietly count if `sample' & missing(`raw')
            if r(N) {
                local rc 459
                local errtext "design column `coef' is now missing inside the stored sample for model `name'"
                continue, break
            }

            local ++p
            local native`i'_`p' = `j'
            tempvar panelmean
            bysort `panelvar': egen double `panelmean' = mean(cond(`sample', `raw', .))
            local xmeanlist `xmeanlist' `panelmean'
        }
        if `rc' continue, break
        if !`conspos' {
            local rc 198
            local errtext "noconstant xtreg, be models are not supported"
            continue, break
        }

        local p`i' = `p'
        local kbe`i' = `p' + 1
        matrix `A' = J(`korig`i'', `kbe`i'', 0)
        matrix `btarget' = J(1, `kbe`i'', .)
        forvalues q = 1/`p' {
            local j = `native`i'_`q''
            matrix `A'[`j',`q'] = 1
            matrix `btarget'[1,`q'] = `bsrc'[1,`j']
        }
        matrix `A'[`conspos',`kbe`i''] = 1
        matrix `btarget'[1,`kbe`i''] = `bsrc'[1,`conspos']
        matrix `At' = `A''
        local A`i' `A'
        local At`i' `At'

        tempvar ybar tagpanel
        bysort `panelvar': egen double `ybar' = mean(cond(`sample', `depvar`i'', .))
        quietly egen byte `tagpanel' = tag(`panelvar') if `sample'
        local tagpanel`i' `tagpanel'

        capture quietly regress `ybar' `xmeanlist' if `tagpanel'
        if _rc {
            local rc = _rc
            local errtext "unable to fit the panel-mean regression bridge for model `name'"
            continue, break
        }
        local Npanel`i' = e(N)
        if `Npanel`i'' != `Ng_native`i'' {
            local rc 459
            local errtext "the panel-mean bridge changed the number of groups for model `name'"
            continue, break
        }
        if colsof(e(b)) != `kbe`i'' | e(rank) != `kbe`i'' {
            local rc 498
            local errtext "the panel-mean bridge has a different rank from model `name'"
            continue, break
        }
        matrix `bbridge' = e(b)
        local bridgecnames`i' : colnames `bbridge'
        if mreldif(`btarget', `bbridge') > 1e-8 {
            local rc 498
            local errtext "the current data do not reproduce the stored xtreg, be coefficients for model `name'"
            continue, break
        }
        matrix `bfull' = `bbridge'*`At'
        if mreldif(`bsrc', `bfull') > 1e-8 {
            local rc 498
            local errtext "the current data do not reproduce the stored xtreg, be coefficient vector for model `name'"
            continue, break
        }

        tempname bridge
        quietly estimates store `bridge'
        local bridge`i' `bridge'
        local bridges `"`bridges' `bridge'"'
    }

    if `rc' {
        foreach bridge of local bridges {
            capture quietly estimates drop `bridge'
        }
        di as err `"`errtext'"'
        exit `rc'
    }

    capture quietly xtset
    if _rc {
        local rc = _rc
        foreach bridge of local bridges {
            capture quietly estimates drop `bridge'
        }
        di as err "the current data must remain xtset for the stored xtreg, be models"
        exit `rc'
    }
    local currentpanel `"`r(panelvar)'"'
    if `"`currentpanel'"' != `"`panelvar'"' {
        foreach bridge of local bridges {
            capture quietly estimates drop `bridge'
        }
        di as err "the current xtset panel variable differs from stored e(ivar)={bf:`panelvar'}"
        exit 459
    }

    if trim(`"`requested_cluster'"') == "" local scorevar `"`panelvar'"'
    else local scorevar `"`requested_cluster'"'
    capture confirm numeric variable `scorevar'
    if _rc {
        local rc = _rc
        foreach bridge of local bridges {
            capture quietly estimates drop `bridge'
        }
        di as err "cluster variable {bf:`scorevar'} must be numeric"
        exit `rc'
    }

    tempvar union cmin cmax
    quietly generate byte `union' = 0
    forvalues i = 1/`nmodels' {
        quietly replace `union' = 1 if `sample`i''
    }
    quietly count if `union' & missing(`scorevar')
    if r(N) {
        foreach bridge of local bridges {
            capture quietly estimates drop `bridge'
        }
        di as err "cluster variable {bf:`scorevar'} is missing on " r(N) " observation(s) in the union sample"
        exit 459
    }
    bysort `panelvar': egen double `cmin' = min(cond(`union', `scorevar', .))
    bysort `panelvar': egen double `cmax' = max(cond(`union', `scorevar', .))
    quietly count if `union' & `cmin' != `cmax'
    if r(N) {
        foreach bridge of local bridges {
            capture quietly estimates drop `bridge'
        }
        di as err "panel variable {bf:`panelvar'} is not nested within cluster variable {bf:`scorevar'}"
        exit 459
    }

    forvalues i = 1/`nmodels' {
        tempvar tagcluster
        quietly egen byte `tagcluster' = tag(`scorevar') if `tagpanel`i''
        quietly count if `tagcluster'
        local G`i' = r(N)
        if `G`i'' < 2 {
            foreach bridge of local bridges {
                capture quietly estimates drop `bridge'
            }
            local name : word `i' of `names'
            di as err "model {bf:`name'} contains fewer than two clusters in {bf:`scorevar'}"
            exit 459
        }
    }

    capture quietly suest `bridges', cluster(`scorevar')
    local rc = _rc
    if `rc' {
        foreach bridge of local bridges {
            capture quietly estimates drop `bridge'
        }
        di as err "official suest could not combine the xtreg, be panel-mean regression bridges"
        exit `rc'
    }

    tempname bsys Vsys bout Vout
    matrix `bsys' = e(b)
    matrix `Vsys' = e(V)
    local Gsys = e(N_clust)
    local expected 0
    local syscolnames : colnames `bsys'
    local usedstarts
    forvalues i = 1/`nmodels' {
        local expected = `expected' + `kbe`i'' + 1
        local targetnames `"`bridgecnames`i''"'
        local nsys = colsof(`bsys')
        local laststart = `nsys' - `kbe`i'' + 1
        local bstart`i' 0
        local nmatches 0

        * Match the complete coefficient-name sequence from the temporary
        * panel-mean regression. Its generated regressor names are unique to
        * this model, so this does not depend on official suest's equation
        * prefixes or equation ordering.
        forvalues q = 1/`laststart' {
            local seqmatch 1
            forvalues r = 1/`kbe`i'' {
                local sysname : word `=`q'+`r'-1' of `syscolnames'
                local target : word `r' of `targetnames'
                if `"`sysname'"' != `"`target'"' local seqmatch 0
            }
            if `seqmatch' {
                local bstart`i' = `q'
                local ++nmatches
            }
        }
        local bend`i' = `bstart`i'' + `kbe`i'' - 1
        local duplicate : list posof "`bstart`i''" in usedstarts
        if `nmatches' != 1 | `duplicate' {
            foreach bridge of local bridges {
                capture quietly estimates drop `bridge'
            }
            local name : word `i' of `names'
            di as err "suest2 could not uniquely identify the coefficient sequence for the panel-mean bridge of model {bf:`name'}"
            exit 498
        }
        local usedstarts `"`usedstarts' `bstart`i''"'
    }
    if colsof(`bsys') != `expected' {
        foreach bridge of local bridges {
            capture quietly estimates drop `bridge'
        }
        di as err "suest2 could not map the official suest between-regression bridge parameter blocks"
        exit 498
    }

    forvalues i = 1/`nmodels' {
        local scale`i' = ((`G`i''/(`G`i''-1))*((`Npanel`i''-1)/(`Npanel`i''-`kbe`i''))) / ///
            (`Gsys'/(`Gsys'-1))
    }

    forvalues i = 1/`nmodels' {
        forvalues j = 1/`nmodels' {
            tempname rawblock block
            matrix `rawblock' = `Vsys'[`bstart`i''..`bend`i'', `bstart`j''..`bend`j'']
            matrix `block' = sqrt(`scale`i''*`scale`j'') * ///
                `A`i'' * `rawblock' * `At`j''
            local Vblock`i'_`j' `block'
        }
    }

    forvalues i = 1/`nmodels' {
        tempname vrow
        matrix `vrow' = `Vblock`i'_1'
        forvalues j = 2/`nmodels' {
            matrix `vrow' = `vrow', `Vblock`i'_`j''
        }
        if `i' == 1 matrix `Vout' = `vrow'
        else matrix `Vout' = `Vout' \ `vrow'
    }

    local eqused
    forvalues i = 1/`nmodels' {
        local name : word `i' of `names'
        local eq = substr(strtoname("`name'_mean"), 1, 32)
        local duplicate : list posof "`eq'" in eqused
        if `duplicate' {
            local suffix "_m`i'"
            local room = 32-strlen("`suffix'")
            local eq = substr(strtoname("`name'"), 1, `room')+"`suffix'"
            local duplicate : list posof "`eq'" in eqused
            if `duplicate' {
                foreach bridge of local bridges {
                    capture quietly estimates drop `bridge'
                }
                di as err "suest2 could not construct unique equation names for the xtreg, be system"
                exit 498
            }
        }
        local eqused `"`eqused' `eq'"'
        local eqname`i' `"`eq'"'
        tempname bi
        matrix `bi' = `bsrc`i''
        local eqlist
        forvalues q = 1/`korig`i'' {
            local eqlist `"`eqlist' `eq'"'
        }
        matrix coleq `bi' = `eqlist'
        if `i' == 1 matrix `bout' = `bi'
        else matrix `bout' = `bout', `bi'
    }

    tempname Vtranspose
    matrix `Vtranspose' = `Vout''
    matrix `Vout' = (`Vout' + `Vtranspose')/2

    local beq : coleq `bout'
    local bcn : colnames `bout'
    matrix colnames `Vout' = `bcn'
    matrix rownames `Vout' = `bcn'
    matrix coleq `Vout' = `beq'
    matrix roweq `Vout' = `beq'

    quietly count if `union'
    local Nunion = r(N)
    tempvar tagunionpanel
    quietly egen byte `tagunionpanel' = tag(`panelvar') if `union'
    quietly count if `tagunionpanel'
    local Ngsys = r(N)

    ereturn post `bout' `Vout', obs(`Nunion') esample(`union')
    mata: st_numscalar("__s2_xtberank", rank(st_matrix("`Vout'")))
    ereturn scalar rank = scalar(__s2_xtberank)
    ereturn scalar N_clust = `Gsys'
    ereturn scalar N_g = `Ngsys'
    ereturn local clustvar `"`scorevar'"'
    ereturn local vce "cluster"
    ereturn local vcetype "Robust"
    ereturn local names `"`names'"'
    ereturn local properties "b V"
    ereturn scalar suest2_xtbe = 1
    ereturn local suest2_xtbe_panelvar `"`panelvar'"'
    ereturn local suest2_xtbe_scorevar `"`scorevar'"'
    ereturn local suest2_xtbe_engine "panel_mean_suest_bridge"
    ereturn local suest2_xtbe_displayopts `"`displayopts'"'
    ereturn local title "Simultaneous between-effects results"
    ereturn local cmd "suest2_xtbe"

    forvalues i = 1/`nmodels' {
        ereturn local eqnames`i' `"`eqname`i''"'
        ereturn scalar suest2_xtbe_N`i' = `N`i''
        ereturn scalar suest2_xtbe_Npanel`i' = `Npanel`i''
        ereturn scalar suest2_xtbe_G`i' = `G`i''
        ereturn scalar suest2_xtbe_K`i' = `kbe`i''
        ereturn scalar suest2_xtbe_native_rank`i' = `nativerank`i''
        ereturn scalar suest2_xtbe_scale`i' = `scale`i''
    }

    foreach bridge of local bridges {
        capture quietly estimates drop `bridge'
    }
end

// ============================================================================
// Stored xtreg, re route
// ============================================================================

// ============================================================================
// Stored xtreg, cre route
// ============================================================================

program define suest2_xtcreestimate, sortpreserve eclass
    version 16
    syntax [anything] [, CLuster(varname) VCE(string asis) Robust MINUS ///
        REGRESSML SVY Level(cilevel) DIR EForm(passthru) *]

    if "`minus'" != "" | "`regressml'" != "" | "`svy'" != "" {
        di as err "options minus, regressml, and svy are not supported for xtreg, cre systems"
        exit 198
    }

    local displayopts
    if "`level'" != "" local displayopts `"`displayopts' level(`level')"'
    if "`dir'" != "" local displayopts `"`displayopts' dir"'
    if `"`eform'"' != "" local displayopts `"`displayopts' `eform'"'
    if trim(`"`options'"') != "" local displayopts `"`displayopts' `options'"'

    if "`cluster'" != "" & trim(`"`vce'"') != "" {
        di as err "specify only one of cluster() or vce()"
        exit 198
    }
    if "`cluster'" != "" & "`robust'" != "" {
        di as err "specify only one of cluster() or robust"
        exit 198
    }
    if trim(`"`vce'"') != "" & "`robust'" != "" {
        di as err "specify only one of vce() or robust"
        exit 198
    }

    local requested_cluster `"`cluster'"'
    if trim(`"`vce'"') != "" {
        local vcelower = ustrlower(itrim(trim(`"`vce'"')))
        if "`vcelower'" == "robust" local requested_cluster
        else if ustrregexm(`"`vcelower'"', "^cluster[ ]+([A-Za-z_][A-Za-z0-9_]*)$") {
            local requested_cluster `"`=ustrregexs(1)'"'
        }
        else if ustrregexm(`"`vcelower'"', "^cluster[ ]*\([ ]*([A-Za-z_][A-Za-z0-9_]*)[ ]*\)$") {
            local requested_cluster `"`=ustrregexs(1)'"'
        }
        else {
            di as err "the xtreg, cre route supports only vce(robust) or vce(cluster varname)"
            exit 198
        }
    }

    est_expand `"`anything'"', min(2) default(.)
    local names `"`r(names)'"'
    local names : list uniq names
    local nmodels : word count `names'
    local hasdot : list posof "." in names
    if `hasdot' {
        di as err "xtreg, cre support requires named stored estimates"
        di as err "store each model with {bf:estimates store} before running {bf:suest2}"
        exit 198
    }

    local bridges
    local rc 0
    local panelvar
    local scorevar
    local errtext

    forvalues i = 1/`nmodels' {
        local name : word `i' of `names'
        capture quietly estimates restore `name'
        if _rc {
            local rc = _rc
            local errtext "unable to restore constituent model `name'"
            continue, break
        }
        if "`e(cmd)'" != "xtreg" | "`e(model)'" != "cre" {
            local rc 322
            local errtext "the first xtreg, cre increment requires every constituent model to be xtreg, cre"
            continue, break
        }
        if trim(`"`e(wtype)'"') != "" {
            local rc 198
            local errtext "weights are not yet supported for xtreg, cre systems"
            continue, break
        }

        local ivar `"`e(ivar)'"'
        if trim(`"`ivar'"') == "" {
            local rc 498
            local errtext "model `name' does not retain its panel identifier in e(ivar)"
            continue, break
        }
        if `i' == 1 local panelvar `"`ivar'"'
        else if `"`ivar'"' != `"`panelvar'"' {
            local rc 459
            local errtext "all xtreg, cre constituent models must use the same panel variable"
            continue, break
        }

        foreach scalar in rank sigma_e sigma_u N N_g Tcon chi2_mundlak p_mundlak df_mundlak {
            capture confirm scalar e(`scalar')
            if _rc {
                local rc 498
                local errtext "model `name' does not retain e(`scalar')"
                continue, break
            }
        }
        if `rc' continue, break
        capture confirm matrix e(b)
        if _rc {
            local rc = _rc
            local errtext "model `name' does not contain e(b)"
            continue, break
        }
        if e(sigma_e) <= 0 | e(sigma_u) < 0 {
            local rc 498
            local errtext "model `name' retains invalid random-effects variance components"
            continue, break
        }

        local vars `"`e(vars)'"'
        local stripes `"`e(stripes)'"'
        local kbase : word count `vars'
        if `kbase' < 1 {
            local rc 198
            local errtext "intercept-only xtreg, cre models are not supported in the first increment"
            continue, break
        }

        tempname bsrc Vsrc omit A At btarget bbridge bfull Vfull
        matrix `bsrc' = e(b)
        matrix `Vsrc' = e(V)
        local bsrc`i' `bsrc'
        local korig`i' = colsof(`bsrc')
        if `korig`i'' != 2*`kbase'+1 {
            local rc 498
            local errtext "model `name' has an unexpected xtreg, cre coefficient layout"
            continue, break
        }

        local nativerank`i' = e(rank)
        local N`i' = e(N)
        local Ng_native`i' = e(N_g)
        local depvar`i' `"`e(depvar)'"'
        local sigmae`i' = e(sigma_e)
        local sigmau`i' = e(sigma_u)
        local Tcon`i' = e(Tcon)
        local chi2m`i' = e(chi2_mundlak)
        local pm`i' = e(p_mundlak)
        local dfm`i' = e(df_mundlak)
        local sourcevce`i' `"`e(vce)'"'
        local vars`i' `"`vars'"'
        local stripes`i' `"`stripes'"'
        local kbase`i' = `kbase'

        tempvar sample Ti theta
        quietly generate byte `sample' = e(sample)
        local sample`i' `sample'
        quietly count if `sample'
        if r(N) != `N`i'' {
            local rc 459
            local errtext "the current data no longer reproduce the stored estimation sample for model `name'"
            continue, break
        }
        bysort `panelvar': egen long `Ti' = total(`sample')
        quietly generate double `theta' = 1-`sigmae`i''/sqrt(`Ti'*`sigmau`i''^2+`sigmae`i''^2) if `sample'
        quietly summarize `theta' if `sample', meanonly
        local thmin`i' = r(min)
        local thmax`i' = r(max)

        quietly _ms_omit_info `bsrc'
        matrix `omit' = r(omit)

        local rawlist
        local meanlist
        forvalues j = 1/`kbase' {
            local term : word `j' of `vars'
            capture quietly fvrevar `term'
            if _rc {
                local rc = _rc
                local errtext "unable to reconstruct CRE design term `term' for model `name'"
                continue, break
            }
            local raw `"`r(varlist)'"'
            local nraw : word count `raw'
            if `nraw' != 1 {
                local rc 498
                local errtext "CRE design term `term' did not expand to one variable for model `name'"
                continue, break
            }
            tempvar rawcopy meanx
            quietly generate double `rawcopy' = `raw' if `sample'
            bysort `panelvar': egen double `meanx' = mean(`rawcopy') if `sample'
            local rawlist `rawlist' `rawcopy'
            local meanlist `meanlist' `meanx'
        }
        if `rc' continue, break

        tempvar ybar ys cs
        bysort `panelvar': egen double `ybar' = mean(cond(`sample', `depvar`i'', .))
        quietly generate double `ys' = `depvar`i''-`theta'*`ybar' if `sample'
        quietly generate double `cs' = 1-`theta' if `sample'

        local transformed_all
        forvalues j = 1/`kbase' {
            local raw : word `j' of `rawlist'
            local mx : word `j' of `meanlist'
            tempvar tx
            quietly generate double `tx' = `raw'-`theta'*`mx' if `sample'
            local transformed_all `transformed_all' `tx'
        }
        forvalues j = 1/`kbase' {
            local mx : word `j' of `meanlist'
            tempvar mm tm
            bysort `panelvar': egen double `mm' = mean(cond(`sample', `mx', .))
            quietly generate double `tm' = `mx'-`theta'*`mm' if `sample'
            local transformed_all `transformed_all' `tm'
        }
        local transformed_all `transformed_all' `cs'

        local Kfull = 2*`kbase'+1
        local Kest 0
        local transformed_est
        matrix `A' = J(`korig`i'', `Kfull', 0)
        local aug_to_q
        forvalues ap = 1/`Kfull' {
            if `ap' <= `kbase' local np = `ap'
            else if `ap' <= 2*`kbase' local np = `ap'+1
            else local np = `kbase'+1
            if `omit'[1,`np']==0 {
                local ++Kest
                local xap : word `ap' of `transformed_all'
                local transformed_est `transformed_est' `xap'
                matrix `A'[`np',`Kest'] = 1
            }
        }
        matrix `A' = `A'[1...,1..`Kest']
        matrix `At' = `A''
        local A`i' `A'
        local At`i' `At'
        local kre`i' = `Kest'
        if `Kest' != `nativerank`i'' {
            local rc 498
            local errtext "the reconstructed CRE omission map does not match native rank for model `name'"
            continue, break
        }

        matrix `btarget' = `bsrc'*`A'
        capture quietly regress `ys' `transformed_est' if `sample', nocons
        if _rc {
            local rc = _rc
            local errtext "unable to fit the omit-aware quasi-demeaned CRE bridge for model `name'"
            continue, break
        }
        tempvar bridgesample
        quietly generate byte `bridgesample' = e(sample)
        quietly count if `bridgesample' != `sample'
        if r(N) {
            local rc 459
            local errtext "the CRE bridge changed the stored sample for model `name'"
            continue, break
        }
        if colsof(e(b)) != `Kest' | e(rank) != `Kest' {
            local rc 498
            local errtext "the CRE bridge has a different estimable rank from model `name'"
            continue, break
        }

        matrix `bbridge' = e(b)
        local bridgecnames`i' : colnames `bbridge'
        if mreldif(`btarget', `bbridge') > 1e-8 {
            local rc 498
            local errtext "the current data do not reproduce the stored xtreg, cre coefficients for model `name'"
            continue, break
        }
        matrix `bfull' = `bbridge'*`At'
        if mreldif(`bsrc', `bfull') > 1e-8 {
            local rc 498
            local errtext "the current data do not reproduce the stored xtreg, cre coefficient vector for model `name'"
            continue, break
        }
        if `"`sourcevce`i''"' == "conventional" {
            matrix `Vfull' = `A'*e(V)*`At'
            if mreldif(`Vsrc', `Vfull') > 1e-8 {
                local rc 498
                local errtext "the CRE bridge does not reproduce the stored conventional VCE for model `name'"
                continue, break
            }
        }

        tempname bridge
        quietly estimates store `bridge'
        local bridge`i' `bridge'
        local bridges `"`bridges' `bridge'"'
    }

    if `rc' {
        foreach bridge of local bridges {
            capture quietly estimates drop `bridge'
        }
        di as err `"`errtext'"'
        exit `rc'
    }

    capture quietly xtset
    if _rc {
        local rc = _rc
        foreach bridge of local bridges {
            capture quietly estimates drop `bridge'
        }
        di as err "the current data must remain xtset for the stored xtreg, cre models"
        exit `rc'
    }
    local currentpanel `"`r(panelvar)'"'
    if `"`currentpanel'"' != `"`panelvar'"' {
        foreach bridge of local bridges {
            capture quietly estimates drop `bridge'
        }
        di as err "the current xtset panel variable differs from stored e(ivar)={bf:`panelvar'}"
        exit 459
    }

    if trim(`"`requested_cluster'"') == "" local scorevar `"`panelvar'"'
    else local scorevar `"`requested_cluster'"'
    capture confirm numeric variable `scorevar'
    if _rc {
        local rc = _rc
        foreach bridge of local bridges {
            capture quietly estimates drop `bridge'
        }
        di as err "cluster variable {bf:`scorevar'} must be numeric"
        exit `rc'
    }

    tempvar union cmin cmax
    quietly generate byte `union' = 0
    forvalues i = 1/`nmodels' {
        quietly replace `union' = 1 if `sample`i''
    }
    quietly count if `union' & missing(`scorevar')
    if r(N) {
        foreach bridge of local bridges {
            capture quietly estimates drop `bridge'
        }
        di as err "cluster variable {bf:`scorevar'} is missing on " r(N) " observation(s) in the union sample"
        exit 459
    }
    bysort `panelvar': egen double `cmin' = min(cond(`union', `scorevar', .))
    bysort `panelvar': egen double `cmax' = max(cond(`union', `scorevar', .))
    quietly count if `union' & `cmin' != `cmax'
    if r(N) {
        foreach bridge of local bridges {
            capture quietly estimates drop `bridge'
        }
        di as err "panel variable {bf:`panelvar'} is not nested within cluster variable {bf:`scorevar'}"
        exit 459
    }

    forvalues i = 1/`nmodels' {
        tempvar tagcluster
        quietly egen byte `tagcluster' = tag(`scorevar') if `sample`i''
        quietly count if `tagcluster'
        local G`i' = r(N)
        if `G`i'' < 2 {
            foreach bridge of local bridges {
                capture quietly estimates drop `bridge'
            }
            local name : word `i' of `names'
            di as err "model {bf:`name'} contains fewer than two clusters in {bf:`scorevar'}"
            exit 459
        }
    }

    capture quietly suest `bridges', cluster(`scorevar')
    local rc = _rc
    if `rc' {
        foreach bridge of local bridges {
            capture quietly estimates drop `bridge'
        }
        di as err "official suest could not combine the xtreg, cre quasi-demeaned bridges"
        exit `rc'
    }

    tempname bsys Vsys bout Vout
    matrix `bsys' = e(b)
    matrix `Vsys' = e(V)
    local Nsys = e(N)
    local Gsys = e(N_clust)
    local expected 0
    local syscolnames : colnames `bsys'
    local usedstarts

    forvalues i = 1/`nmodels' {
        local expected = `expected'+`kre`i''+1
        local targetnames `"`bridgecnames`i''"'
        local nsys = colsof(`bsys')
        local laststart = `nsys'-`kre`i''+1
        local bstart`i' 0
        local nmatches 0
        forvalues q = 1/`laststart' {
            local seqmatch 1
            forvalues r = 1/`kre`i'' {
                local sysname : word `=`q'+`r'-1' of `syscolnames'
                local target : word `r' of `targetnames'
                if `"`sysname'"' != `"`target'"' local seqmatch 0
            }
            if `seqmatch' {
                local bstart`i' = `q'
                local ++nmatches
            }
        }
        local bend`i' = `bstart`i''+`kre`i''-1
        local duplicate : list posof "`bstart`i''" in usedstarts
        if `nmatches' != 1 | `duplicate' {
            foreach bridge of local bridges {
                capture quietly estimates drop `bridge'
            }
            local name : word `i' of `names'
            di as err "suest2 could not uniquely identify the CRE bridge block for model {bf:`name'}"
            exit 498
        }
        local usedstarts `"`usedstarts' `bstart`i''"'
    }

    if colsof(`bsys') != `expected' {
        foreach bridge of local bridges {
            capture quietly estimates drop `bridge'
        }
        di as err "suest2 could not map the official suest CRE bridge parameter blocks"
        exit 498
    }

    forvalues i = 1/`nmodels' {
        local scale`i' = ((`G`i''/(`G`i''-1))*((`N`i''-1)/(`N`i''-`kre`i''))) / ///
            (`Gsys'/(`Gsys'-1))
    }

    forvalues i = 1/`nmodels' {
        forvalues j = 1/`nmodels' {
            tempname rawblock block
            matrix `rawblock' = `Vsys'[`bstart`i''..`bend`i'',`bstart`j''..`bend`j'']
            matrix `block' = sqrt(`scale`i''*`scale`j'')*`A`i''*`rawblock'*`At`j''
            local Vblock`i'_`j' `block'
        }
    }

    forvalues i = 1/`nmodels' {
        tempname vrow
        matrix `vrow' = `Vblock`i'_1'
        forvalues j = 2/`nmodels' {
            matrix `vrow' = `vrow',`Vblock`i'_`j''
        }
        if `i'==1 matrix `Vout' = `vrow'
        else matrix `Vout' = `Vout' \ `vrow'
    }

    local eqused
    forvalues i = 1/`nmodels' {
        local name : word `i' of `names'
        local eq1 = substr(strtoname("`name'_xit"),1,32)
        local eq2 = substr(strtoname("`name'_means"),1,32)
        local d1 : list posof "`eq1'" in eqused
        local d2 : list posof "`eq2'" in eqused
        if `d1' | `d2' | "`eq1'"=="`eq2'" {
            local eq1 = substr("s2cre`i'_xit",1,32)
            local eq2 = substr("s2cre`i'_means",1,32)
        }
        local eqused `"`eqused' `eq1' `eq2'"'
        local eqname1`i' `"`eq1'"'
        local eqname2`i' `"`eq2'"'

        tempname bi
        matrix `bi' = `bsrc`i''
        local eqlist
        forvalues q = 1/`korig`i'' {
            if `q' <= `kbase`i''+1 local eqlist `"`eqlist' `eq1'"'
            else local eqlist `"`eqlist' `eq2'"'
        }
        matrix coleq `bi' = `eqlist'
        if `i'==1 matrix `bout' = `bi'
        else matrix `bout' = `bout',`bi'
    }

    tempname Vtranspose
    matrix `Vtranspose' = `Vout''
    matrix `Vout' = (`Vout'+`Vtranspose')/2
    local beq : coleq `bout'
    local bcn : colnames `bout'
    matrix colnames `Vout' = `bcn'
    matrix rownames `Vout' = `bcn'
    matrix coleq `Vout' = `beq'
    matrix roweq `Vout' = `beq'

    tempvar tagpanel
    quietly egen byte `tagpanel' = tag(`panelvar') if `union'
    quietly count if `tagpanel'
    local Ngsys = r(N)

    ereturn post `bout' `Vout', obs(`Nsys') esample(`union')
    mata: st_numscalar("__s2_xtcrerank",rank(st_matrix("`Vout'")))
    ereturn scalar rank = scalar(__s2_xtcrerank)
    ereturn scalar N_clust = `Gsys'
    ereturn scalar N_g = `Ngsys'
    ereturn local clustvar `"`scorevar'"'
    ereturn local vce "cluster"
    ereturn local vcetype "Robust"
    ereturn local names `"`names'"'
    ereturn local properties "b V"
    ereturn scalar suest2_xtcre = 1
    ereturn local suest2_xtcre_panelvar `"`panelvar'"'
    ereturn local suest2_xtcre_scorevar `"`scorevar'"'
    ereturn local suest2_xtcre_engine "omit_aware_augmented_re_bridge"
    ereturn local suest2_xtcre_displayopts `"`displayopts'"'
    ereturn local title "Simultaneous correlated random-effects results"
    ereturn local cmd "suest2_xtcre"

    forvalues i = 1/`nmodels' {
        ereturn local eqnames`i' `"`eqname1`i'' `eqname2`i''"'
        ereturn local suest2_xtcre_vars`i' `"`vars`i''"'
        ereturn local suest2_xtcre_stripes`i' `"`stripes`i''"'
        ereturn scalar suest2_xtcre_kbase`i' = `kbase`i''
        ereturn scalar suest2_xtcre_N`i' = `N`i''
        ereturn scalar suest2_xtcre_Npanel`i' = `Ng_native`i''
        ereturn scalar suest2_xtcre_G`i' = `G`i''
        ereturn scalar suest2_xtcre_K`i' = `kre`i''
        ereturn scalar suest2_xtcre_native_rank`i' = `nativerank`i''
        ereturn scalar suest2_xtcre_sigma_e`i' = `sigmae`i''
        ereturn scalar suest2_xtcre_sigma_u`i' = `sigmau`i''
        ereturn scalar suest2_xtcre_Tcon`i' = `Tcon`i''
        ereturn scalar suest2_xtcre_theta_min`i' = `thmin`i''
        ereturn scalar suest2_xtcre_theta_max`i' = `thmax`i''
        ereturn scalar suest2_xtcre_scale`i' = `scale`i''
        ereturn scalar suest2_xtcre_chi2_mundlak`i' = `chi2m`i''
        ereturn scalar suest2_xtcre_p_mundlak`i' = `pm`i''
        ereturn scalar suest2_xtcre_df_mundlak`i' = `dfm`i''
    }

    foreach bridge of local bridges {
        capture quietly estimates drop `bridge'
    }
end

program define suest2_xtreestimate, sortpreserve eclass
    version 16
    syntax [anything] [, CLuster(varname) VCE(string asis) Robust MINUS ///
        REGRESSML SVY Level(cilevel) DIR EForm(passthru) *]

    if "`minus'" != "" | "`regressml'" != "" | "`svy'" != "" {
        di as err "options minus, regressml, and svy are not supported for xtreg, re systems"
        exit 198
    }

    local displayopts
    if "`level'" != "" local displayopts `"`displayopts' level(`level')"'
    if "`dir'" != "" local displayopts `"`displayopts' dir"'
    if `"`eform'"' != "" local displayopts `"`displayopts' `eform'"'
    if trim(`"`options'"') != "" local displayopts `"`displayopts' `options'"'

    if "`cluster'" != "" & trim(`"`vce'"') != "" {
        di as err "specify only one of cluster() or vce()"
        exit 198
    }
    if "`cluster'" != "" & "`robust'" != "" {
        di as err "specify only one of cluster() or robust"
        exit 198
    }
    if trim(`"`vce'"') != "" & "`robust'" != "" {
        di as err "specify only one of vce() or robust"
        exit 198
    }

    local requested_cluster `"`cluster'"'
    if trim(`"`vce'"') != "" {
        local vcelower = ustrlower(itrim(trim(`"`vce'"')))
        if "`vcelower'" == "robust" local requested_cluster
        else if ustrregexm(`"`vcelower'"', "^cluster[ ]+([A-Za-z_][A-Za-z0-9_]*)$") {
            local requested_cluster `"`=ustrregexs(1)'"'
        }
        else if ustrregexm(`"`vcelower'"', "^cluster[ ]*\([ ]*([A-Za-z_][A-Za-z0-9_]*)[ ]*\)$") {
            local requested_cluster `"`=ustrregexs(1)'"'
        }
        else {
            di as err "the xtreg, re route supports only vce(robust) or vce(cluster varname)"
            exit 198
        }
    }

    est_expand `"`anything'"', min(2) default(.)
    local names `"`r(names)'"'
    local names : list uniq names
    local nmodels : word count `names'
    local hasdot : list posof "." in names
    if `hasdot' {
        di as err "xtreg, re support requires named stored estimates"
        di as err "store each model with {bf:estimates store} before running {bf:suest2}"
        exit 198
    }

    local bridges
    local rc 0
    local panelvar
    local scorevar
    local errtext

    forvalues i = 1/`nmodels' {
        local name : word `i' of `names'
        capture quietly estimates restore `name'
        if _rc {
            local rc = _rc
            local errtext "unable to restore constituent model `name'"
            continue, break
        }
        if "`e(cmd)'" != "xtreg" | "`e(model)'" != "re" {
            local rc 322
            local errtext "the first xtreg, re increment requires every constituent model to be xtreg, re"
            continue, break
        }
        if trim(`"`e(wtype)'"') != "" {
            local rc 198
            local errtext "weights are not yet supported for xtreg, re systems"
            continue, break
        }

        local ivar `"`e(ivar)'"'
        if trim(`"`ivar'"') == "" {
            local rc 498
            local errtext "model `name' does not retain its panel identifier in e(ivar)"
            continue, break
        }
        if `i' == 1 local panelvar `"`ivar'"'
        else if `"`ivar'"' != `"`panelvar'"' {
            local rc 459
            local errtext "all xtreg, re constituent models must use the same panel variable"
            continue, break
        }

        capture confirm matrix e(b)
        if _rc {
            local rc = _rc
            local errtext "model `name' does not contain e(b)"
            continue, break
        }
        capture confirm scalar e(rank)
        if _rc {
            local rc 498
            local errtext "model `name' does not retain e(rank)"
            continue, break
        }
        capture confirm scalar e(sigma_e)
        if _rc {
            local rc 498
            local errtext "model `name' does not retain e(sigma_e)"
            continue, break
        }
        capture confirm scalar e(sigma_u)
        if _rc {
            local rc 498
            local errtext "model `name' does not retain e(sigma_u)"
            continue, break
        }
        if e(sigma_e) <= 0 | e(sigma_u) < 0 {
            local rc 498
            local errtext "model `name' retains invalid random-effects variance components"
            continue, break
        }

        tempname bsrc Vsrc omit A At btarget bbridge bfull Vfull
        matrix `bsrc' = e(b)
        matrix `Vsrc' = e(V)
        local bsrc`i' `bsrc'
        local korig`i' = colsof(`bsrc')
        local nativerank`i' = e(rank)
        local N`i' = e(N)
        local Ng_native`i' = e(N_g)
        local depvar`i' `"`e(depvar)'"'
        local sigmae`i' = e(sigma_e)
        local sigmau`i' = e(sigma_u)
        local Tcon`i' = e(Tcon)
        local sourcevce`i' `"`e(vce)'"'

        tempvar sample Ti theta
        quietly generate byte `sample' = e(sample)
        local sample`i' `sample'
        quietly count if `sample'
        if r(N) != `N`i'' {
            local rc 459
            local errtext "the current data no longer reproduce the stored estimation sample for model `name'"
            continue, break
        }
        bysort `panelvar': egen long `Ti' = total(`sample')
        quietly generate double `theta' = 1-`sigmae`i''/sqrt(`Ti'*`sigmau`i''^2+`sigmae`i''^2) if `sample'
        quietly summarize `theta' if `sample', meanonly
        local thmin`i' = r(min)
        local thmax`i' = r(max)

        quietly _ms_omit_info `bsrc'
        matrix `omit' = r(omit)
        local cnames : colnames `bsrc'
        local conspos 0
        local p 0
        local xslist

        forvalues j = 1/`korig`i'' {
            local coef : word `j' of `cnames'
            local omitted = `omit'[1,`j']
            if "`coef'" == "_cons" {
                local conspos = `j'
                continue
            }
            if `omitted' continue

            capture quietly fvrevar `coef'
            if _rc {
                local rc = _rc
                local errtext "unable to reconstruct design column `coef' for model `name'"
                continue, break
            }
            local raw `"`r(varlist)'"'
            local nraw : word count `raw'
            if `nraw' != 1 {
                local rc 498
                local errtext "design column `coef' did not expand to exactly one variable for model `name'"
                continue, break
            }
            capture confirm numeric variable `raw'
            if _rc {
                local rc = _rc
                local errtext "design column `coef' is not numeric for model `name'"
                continue, break
            }
            quietly count if `sample' & missing(`raw')
            if r(N) {
                local rc 459
                local errtext "design column `coef' is now missing inside the stored sample for model `name'"
                continue, break
            }

            local ++p
            local native`i'_`p' = `j'
            tempvar panelmean xs
            bysort `panelvar': egen double `panelmean' = mean(cond(`sample', `raw', .))
            quietly generate double `xs' = `raw' - `theta'*`panelmean' if `sample'
            local xslist `xslist' `xs'
        }
        if `rc' continue, break
        if !`conspos' {
            local rc 198
            local errtext "noconstant xtreg, re models are not supported"
            continue, break
        }

        local p`i' = `p'
        local kre`i' = `p' + 1
        matrix `A' = J(`korig`i'', `kre`i'', 0)
        matrix `btarget' = J(1, `kre`i'', .)
        forvalues q = 1/`p' {
            local j = `native`i'_`q''
            matrix `A'[`j',`q'] = 1
            matrix `btarget'[1,`q'] = `bsrc'[1,`j']
        }
        matrix `A'[`conspos',`kre`i''] = 1
        matrix `btarget'[1,`kre`i''] = `bsrc'[1,`conspos']
        matrix `At' = `A''
        local A`i' `A'
        local At`i' `At'

        tempvar ybar ys cs
        bysort `panelvar': egen double `ybar' = mean(cond(`sample', `depvar`i'', .))
        quietly generate double `ys' = `depvar`i'' - `theta'*`ybar' if `sample'
        quietly generate double `cs' = 1-`theta' if `sample'

        capture quietly regress `ys' `xslist' `cs' if `sample', nocons
        if _rc {
            local rc = _rc
            local errtext "unable to fit the quasi-demeaned regression bridge for model `name'"
            continue, break
        }
        tempvar bridgesample
        quietly generate byte `bridgesample' = e(sample)
        quietly count if `bridgesample' != `sample'
        if r(N) {
            local rc 459
            local errtext "the quasi-demeaned bridge changed the stored sample for model `name'"
            continue, break
        }
        if colsof(e(b)) != `kre`i'' | e(rank) != `kre`i'' {
            local rc 498
            local errtext "the quasi-demeaned bridge has a different rank from model `name'"
            continue, break
        }
        matrix `bbridge' = e(b)
        local bridgecnames`i' : colnames `bbridge'
        if mreldif(`btarget', `bbridge') > 1e-8 {
            local rc 498
            local errtext "the current data do not reproduce the stored xtreg, re coefficients for model `name'"
            continue, break
        }
        matrix `bfull' = `bbridge'*`At'
        if mreldif(`bsrc', `bfull') > 1e-8 {
            local rc 498
            local errtext "the current data do not reproduce the stored xtreg, re coefficient vector for model `name'"
            continue, break
        }
        if `"`sourcevce`i''"' == "conventional" {
            matrix `Vfull' = `A'*e(V)*`At'
            if mreldif(`Vsrc', `Vfull') > 1e-8 {
                local rc 498
                local errtext "the quasi-demeaned bridge does not reproduce the stored conventional VCE for model `name'"
                continue, break
            }
        }

        tempname bridge
        quietly estimates store `bridge'
        local bridge`i' `bridge'
        local bridges `"`bridges' `bridge'"'
    }

    if `rc' {
        foreach bridge of local bridges {
            capture quietly estimates drop `bridge'
        }
        di as err `"`errtext'"'
        exit `rc'
    }

    capture quietly xtset
    if _rc {
        local rc = _rc
        foreach bridge of local bridges {
            capture quietly estimates drop `bridge'
        }
        di as err "the current data must remain xtset for the stored xtreg, re models"
        exit `rc'
    }
    local currentpanel `"`r(panelvar)'"'
    if `"`currentpanel'"' != `"`panelvar'"' {
        foreach bridge of local bridges {
            capture quietly estimates drop `bridge'
        }
        di as err "the current xtset panel variable differs from stored e(ivar)={bf:`panelvar'}"
        exit 459
    }

    if trim(`"`requested_cluster'"') == "" local scorevar `"`panelvar'"'
    else local scorevar `"`requested_cluster'"'
    capture confirm numeric variable `scorevar'
    if _rc {
        local rc = _rc
        foreach bridge of local bridges {
            capture quietly estimates drop `bridge'
        }
        di as err "cluster variable {bf:`scorevar'} must be numeric"
        exit `rc'
    }

    tempvar union cmin cmax
    quietly generate byte `union' = 0
    forvalues i = 1/`nmodels' {
        quietly replace `union' = 1 if `sample`i''
    }
    quietly count if `union' & missing(`scorevar')
    if r(N) {
        foreach bridge of local bridges {
            capture quietly estimates drop `bridge'
        }
        di as err "cluster variable {bf:`scorevar'} is missing on " r(N) " observation(s) in the union sample"
        exit 459
    }
    bysort `panelvar': egen double `cmin' = min(cond(`union', `scorevar', .))
    bysort `panelvar': egen double `cmax' = max(cond(`union', `scorevar', .))
    quietly count if `union' & `cmin' != `cmax'
    if r(N) {
        foreach bridge of local bridges {
            capture quietly estimates drop `bridge'
        }
        di as err "panel variable {bf:`panelvar'} is not nested within cluster variable {bf:`scorevar'}"
        exit 459
    }

    forvalues i = 1/`nmodels' {
        tempvar tagcluster
        quietly egen byte `tagcluster' = tag(`scorevar') if `sample`i''
        quietly count if `tagcluster'
        local G`i' = r(N)
        if `G`i'' < 2 {
            foreach bridge of local bridges {
                capture quietly estimates drop `bridge'
            }
            local name : word `i' of `names'
            di as err "model {bf:`name'} contains fewer than two clusters in {bf:`scorevar'}"
            exit 459
        }
    }

    capture quietly suest `bridges', cluster(`scorevar')
    local rc = _rc
    if `rc' {
        foreach bridge of local bridges {
            capture quietly estimates drop `bridge'
        }
        di as err "official suest could not combine the xtreg, re quasi-demeaned regression bridges"
        exit `rc'
    }

    tempname bsys Vsys bout Vout
    matrix `bsys' = e(b)
    matrix `Vsys' = e(V)
    local Nsys = e(N)
    local Gsys = e(N_clust)
    local expected 0
    local syscolnames : colnames `bsys'
    local usedstarts

    forvalues i = 1/`nmodels' {
        local expected = `expected' + `kre`i'' + 1
        local targetnames `"`bridgecnames`i''"'
        local nsys = colsof(`bsys')
        local laststart = `nsys' - `kre`i'' + 1
        local bstart`i' 0
        local nmatches 0

        forvalues q = 1/`laststart' {
            local seqmatch 1
            forvalues r = 1/`kre`i'' {
                local sysname : word `=`q'+`r'-1' of `syscolnames'
                local target : word `r' of `targetnames'
                if `"`sysname'"' != `"`target'"' local seqmatch 0
            }
            if `seqmatch' {
                local bstart`i' = `q'
                local ++nmatches
            }
        }
        local bend`i' = `bstart`i'' + `kre`i'' - 1
        local duplicate : list posof "`bstart`i''" in usedstarts
        if `nmatches' != 1 | `duplicate' {
            foreach bridge of local bridges {
                capture quietly estimates drop `bridge'
            }
            local name : word `i' of `names'
            di as err "suest2 could not uniquely identify the quasi-demeaned bridge block for model {bf:`name'}"
            exit 498
        }
        local usedstarts `"`usedstarts' `bstart`i''"'
    }

    if colsof(`bsys') != `expected' {
        foreach bridge of local bridges {
            capture quietly estimates drop `bridge'
        }
        di as err "suest2 could not map the official suest random-effects bridge parameter blocks"
        exit 498
    }

    forvalues i = 1/`nmodels' {
        local scale`i' = ((`G`i''/(`G`i''-1))*((`N`i''-1)/(`N`i''-`kre`i''))) / ///
            (`Gsys'/(`Gsys'-1))
    }

    forvalues i = 1/`nmodels' {
        forvalues j = 1/`nmodels' {
            tempname rawblock block
            matrix `rawblock' = `Vsys'[`bstart`i''..`bend`i'', `bstart`j''..`bend`j'']
            matrix `block' = sqrt(`scale`i''*`scale`j'') * ///
                `A`i'' * `rawblock' * `At`j''
            local Vblock`i'_`j' `block'
        }
    }

    forvalues i = 1/`nmodels' {
        tempname vrow
        matrix `vrow' = `Vblock`i'_1'
        forvalues j = 2/`nmodels' {
            matrix `vrow' = `vrow', `Vblock`i'_`j''
        }
        if `i' == 1 matrix `Vout' = `vrow'
        else matrix `Vout' = `Vout' \ `vrow'
    }

    local eqused
    forvalues i = 1/`nmodels' {
        local name : word `i' of `names'
        local eq = substr(strtoname("`name'_mean"), 1, 32)
        local duplicate : list posof "`eq'" in eqused
        if `duplicate' {
            local suffix "_m`i'"
            local room = 32-strlen("`suffix'")
            local eq = substr(strtoname("`name'"), 1, `room')+"`suffix'"
            local duplicate : list posof "`eq'" in eqused
            if `duplicate' {
                foreach bridge of local bridges {
                    capture quietly estimates drop `bridge'
                }
                di as err "suest2 could not construct unique equation names for the xtreg, re system"
                exit 498
            }
        }
        local eqused `"`eqused' `eq'"'
        local eqname`i' `"`eq'"'
        tempname bi
        matrix `bi' = `bsrc`i''
        local eqlist
        forvalues q = 1/`korig`i'' {
            local eqlist `"`eqlist' `eq'"'
        }
        matrix coleq `bi' = `eqlist'
        if `i' == 1 matrix `bout' = `bi'
        else matrix `bout' = `bout', `bi'
    }

    tempname Vtranspose
    matrix `Vtranspose' = `Vout''
    matrix `Vout' = (`Vout' + `Vtranspose')/2

    local beq : coleq `bout'
    local bcn : colnames `bout'
    matrix colnames `Vout' = `bcn'
    matrix rownames `Vout' = `bcn'
    matrix coleq `Vout' = `beq'
    matrix roweq `Vout' = `beq'

    tempvar tagpanel
    quietly egen byte `tagpanel' = tag(`panelvar') if `union'
    quietly count if `tagpanel'
    local Ngsys = r(N)

    ereturn post `bout' `Vout', obs(`Nsys') esample(`union')
    mata: st_numscalar("__s2_xtrerank", rank(st_matrix("`Vout'")))
    ereturn scalar rank = scalar(__s2_xtrerank)
    ereturn scalar N_clust = `Gsys'
    ereturn scalar N_g = `Ngsys'
    ereturn local clustvar `"`scorevar'"'
    ereturn local vce "cluster"
    ereturn local vcetype "Robust"
    ereturn local names `"`names'"'
    ereturn local properties "b V"
    ereturn scalar suest2_xtre = 1
    ereturn local suest2_xtre_panelvar `"`panelvar'"'
    ereturn local suest2_xtre_scorevar `"`scorevar'"'
    ereturn local suest2_xtre_engine "quasi_demeaned_suest_bridge"
    ereturn local suest2_xtre_displayopts `"`displayopts'"'
    ereturn local title "Simultaneous random-effects results"
    ereturn local cmd "suest2_xtre"

    forvalues i = 1/`nmodels' {
        ereturn local eqnames`i' `"`eqname`i''"'
        ereturn scalar suest2_xtre_N`i' = `N`i''
        ereturn scalar suest2_xtre_Npanel`i' = `Ng_native`i''
        ereturn scalar suest2_xtre_G`i' = `G`i''
        ereturn scalar suest2_xtre_K`i' = `kre`i''
        ereturn scalar suest2_xtre_native_rank`i' = `nativerank`i''
        ereturn scalar suest2_xtre_sigma_e`i' = `sigmae`i''
        ereturn scalar suest2_xtre_sigma_u`i' = `sigmau`i''
        ereturn scalar suest2_xtre_Tcon`i' = `Tcon`i''
        ereturn scalar suest2_xtre_theta_min`i' = `thmin`i''
        ereturn scalar suest2_xtre_theta_max`i' = `thmax`i''
        ereturn scalar suest2_xtre_scale`i' = `scale`i''
    }

    foreach bridge of local bridges {
        capture quietly estimates drop `bridge'
    }
end



// ============================================================================
// Stored xtreg, pa route
// ============================================================================

program define suest2_xtpaestimate, sortpreserve eclass
    version 16
    syntax [anything] [, CLuster(varname) VCE(string asis) Robust MINUS ///
        REGRESSML SVY Level(cilevel) DIR EForm(passthru) *]

    if "`minus'" != "" | "`regressml'" != "" | "`svy'" != "" {
        di as err "options minus, regressml, and svy are not supported for population-averaged panel systems"
        exit 198
    }

    local displayopts
    if "`level'" != "" local displayopts `"`displayopts' level(`level')"'
    if "`dir'" != "" local displayopts `"`displayopts' dir"'
    if `"`eform'"' != "" local displayopts `"`displayopts' `eform'"'
    if trim(`"`options'"') != "" local displayopts `"`displayopts' `options'"'

    if "`cluster'" != "" & trim(`"`vce'"') != "" {
        di as err "specify only one of cluster() or vce()"
        exit 198
    }
    if "`cluster'" != "" & "`robust'" != "" {
        di as err "specify only one of cluster() or robust"
        exit 198
    }
    if trim(`"`vce'"') != "" & "`robust'" != "" {
        di as err "specify only one of vce() or robust"
        exit 198
    }

    local requested_cluster `"`cluster'"'
    if trim(`"`vce'"') != "" {
        local vcelower = ustrlower(itrim(trim(`"`vce'"')))
        if "`vcelower'" == "robust" local requested_cluster
        else if ustrregexm(`"`vcelower'"', "^cluster[ ]+([A-Za-z_][A-Za-z0-9_]*)$") {
            local requested_cluster `"`=ustrregexs(1)'"'
        }
        else if ustrregexm(`"`vcelower'"', "^cluster[ ]*\([ ]*([A-Za-z_][A-Za-z0-9_]*)[ ]*\)$") {
            local requested_cluster `"`=ustrregexs(1)'"'
        }
        else {
            di as err "the population-averaged route supports only vce(robust) or vce(cluster varname)"
            exit 198
        }
    }

    est_expand `"`anything'"', min(2) default(.)
    local names `"`r(names)'"'
    local names : list uniq names
    local nmodels : word count `names'
    local hasdot : list posof "." in names
    if `hasdot' {
        di as err "population-averaged panel support requires named stored estimates"
        di as err "store each model with {bf:estimates store} before running {bf:suest2}"
        exit 198
    }

    local panelvar
    local scorevar
    local rc 0
    local errtext
    local cleanupvars
    local cleanupmats
    local qscores
    local allcn
    local alleq

    capture quietly xtset
    if _rc {
        di as err "the current data must remain xtset for the stored population-averaged panel models"
        exit 459
    }
    local current_panel `"`r(panelvar)'"'

    forvalues i = 1/`nmodels' {
        local name : word `i' of `names'
        capture quietly estimates restore `name'
        if _rc {
            local rc = _rc
            local errtext "unable to restore constituent model `name'"
            continue, break
        }

        local activecmd = lower(trim("`e(cmd2)'"))
        local supported "xtreg xtlogit xtprobit xtcloglog xtpoisson xtnbreg"
        local issupported : list posof "`activecmd'" in supported
        if "`e(cmd)'" != "xtgee" | "`e(model)'" != "pa" | !`issupported' {
            local rc 322
            local errtext "the population-averaged increment requires every constituent model to be a supported xt..., pa estimate"
            continue, break
        }
        if trim(`"`e(wtype)'"') != "" {
            local rc 198
            local errtext "weights are not yet supported for population-averaged systems"
            continue, break
        }
        if !inlist(`"`e(vce)'"', "", "conventional") {
            local rc 322
            local errtext "store conventional population-averaged estimates and request robust or clustered VCE with suest2"
            continue, break
        }

        local familycheck=lower(trim("`e(family)'"))
        local linkcheck=lower(trim("`e(link)'"))
        local validfamily 0
        if "`activecmd'"=="xtreg" & "`familycheck'"=="gaussian" & "`linkcheck'"=="identity" local validfamily 1
        else if inlist("`activecmd'","xtlogit","xtprobit","xtcloglog") & ///
            "`familycheck'"=="binomial" local validfamily 1
        else if "`activecmd'"=="xtpoisson" & "`familycheck'"=="poisson" & ///
            "`linkcheck'"=="log" local validfamily 1
        else if "`activecmd'"=="xtnbreg" & strpos("`familycheck'","negative binomial")==1 & ///
            "`linkcheck'"=="log" local validfamily 1
        if !`validfamily' {
            local rc 498
            local errtext "model `name' does not retain the expected family and link for `activecmd', pa"
            continue, break
        }

        local ivar `"`e(ivar)'"'
        if trim(`"`ivar'"') == "" {
            local rc 498
            local errtext "model `name' does not retain its panel identifier in e(ivar)"
            continue, break
        }
        if `i' == 1 local panelvar `"`ivar'"'
        else if `"`ivar'"' != `"`panelvar'"' {
            local rc 459
            local errtext "all population-averaged constituent models must use the same panel variable"
            continue, break
        }
        if `"`current_panel'"' != `"`ivar'"' {
            local rc 459
            local errtext "the current data are xtset on a different panel variable than model `name'"
            continue, break
        }

        foreach scalar in rank phi N N_g {
            capture confirm scalar e(`scalar')
            if _rc {
                local rc 498
                local errtext "model `name' does not retain e(`scalar')"
                continue, break
            }
        }
        if `rc' continue, break
        capture confirm matrix e(b)
        if _rc {
            local rc = _rc
            local errtext "model `name' does not contain e(b)"
            continue, break
        }
        capture confirm matrix e(V)
        if _rc {
            local rc = _rc
            local errtext "model `name' does not contain e(V)"
            continue, break
        }
        capture confirm matrix e(R)
        if _rc {
            local rc = _rc
            local errtext "model `name' does not contain its working correlation matrix e(R)"
            continue, break
        }
        if e(phi) <= 0 {
            local rc 498
            local errtext "model `name' has an invalid nonpositive scale parameter"
            continue, break
        }

        tempname pfx
        local pfx`i' `pfx'
        local bsrc `pfx'_b
        local Vsrc `pfx'_V
        local Rsrc `pfx'_R
        local bref `pfx'_br
        local Vref `pfx'_Vr
        local Rref `pfx'_Rr
        local bsrc`i' `bsrc'
        local Vsrc`i' `Vsrc'
        local Rsrc`i' `Rsrc'
        local cleanupmats `cleanupmats' `bsrc' `Vsrc' `Rsrc' `bref' `Vref' `Rref'
        matrix `bsrc' = e(b)
        matrix `Vsrc' = e(V)
        matrix `Rsrc' = e(R)

        local K`i' = colsof(`bsrc')
        local rank`i' = e(rank)
        local N`i' = e(N)
        local Ng_native`i' = e(N_g)
        local phi`i' = e(phi)
        local corr`i' `"`e(corr)'"'
        local depvar`i' `"`e(depvar)'"'
        local tvar`i' `"`e(tvar)'"'
        local cmdline`i' `"`e(cmdline)'"'
        local activecmd`i' `"`activecmd'"'
        local family`i' `"`e(family)'"'
        local link`i' `"`e(link)'"'
        local nativecn`i' : colnames `bsrc'

        local sample `pfx'_s
        local sampleref `pfx'_sr
        local xb `pfx'_x
        local qscore `pfx'_q
        local qscaled `pfx'_z
        local sample`i' `sample'
        local qscore`i' `qscore'
        local qscaled`i' `qscaled'
        local cleanupvars `cleanupvars' `sample' `sampleref' `xb' `qscore' `qscaled'
        quietly generate byte `sample' = e(sample)
        quietly count if `sample'
        if r(N) != `N`i'' {
            local rc 459
            local errtext "the current data no longer reproduce the stored estimation sample for model `name'"
            continue, break
        }

        if trim(`"`cmdline`i''"') == "" {
            local rc 498
            local errtext "model `name' does not retain e(cmdline) for data-reproduction checks"
            continue, break
        }
        capture quietly `cmdline`i''
        if _rc {
            local rc = _rc
            local errtext "the current data cannot re-estimate stored population-averaged model `name'"
            continue, break
        }
        matrix `bref' = e(b)
        matrix `Vref' = e(V)
        matrix `Rref' = e(R)
        quietly generate byte `sampleref' = e(sample)
        quietly count if `sample' != `sampleref'
        if r(N) {
            local rc 459
            local errtext "the current data do not reproduce the stored estimation sample for model `name'"
            continue, break
        }
        mata: st_numscalar("__s2pa_bdiff",max(abs(st_matrix("`bsrc'"):-st_matrix("`bref'"))))
        mata: st_numscalar("__s2pa_Vdiff",max(abs(st_matrix("`Vsrc'"):-st_matrix("`Vref'"))))
        mata: st_numscalar("__s2pa_Rdiff",max(abs(st_matrix("`Rsrc'"):-st_matrix("`Rref'"))))
        mata: st_numscalar("__s2pa_bscale",1+max(abs(st_matrix("`bsrc'"))))
        mata: st_numscalar("__s2pa_Vscale",1+max(abs(st_matrix("`Vsrc'"))))
        mata: st_numscalar("__s2pa_Rscale",1+max(abs(st_matrix("`Rsrc'"))))
        if scalar(__s2pa_bdiff)>1e-8*scalar(__s2pa_bscale) | ///
            scalar(__s2pa_Vdiff)>1e-8*scalar(__s2pa_Vscale) | ///
            scalar(__s2pa_Rdiff)>1e-8*scalar(__s2pa_Rscale) | ///
            abs(e(phi)-`phi`i'')>1e-8*(1+abs(`phi`i'')) {
            local rc 459
            local errtext "the current data do not reproduce the stored population-averaged coefficients, bread, correlation, or scale for model `name'"
            continue, break
        }

        capture quietly estimates restore `name'
        if _rc {
            local rc = _rc
            local errtext "unable to restore constituent model `name' after reproduction checks"
            continue, break
        }

        if "`activecmd`i''"=="xtreg" {
            capture quietly predict double `xb' if `sample', xb
            if _rc {
                local rc = _rc
                local errtext "unable to reproduce native xb for model `name'"
                continue, break
            }
            quietly generate double `qscore' = .
            capture mata: suest2_xtpa_qscore_mata("`depvar`i''","`xb'","`sample'", ///
                "`panelvar'","`tvar`i''","`Rsrc'",`phi`i'',"`qscore'")
            if _rc {
                local rc = _rc
                local errtext "unable to construct the working-correlation-adjusted Gaussian PA score for model `name'"
                continue, break
            }
            local scoresource`i' "reconstructed_gaussian"
        }
        else {
            capture quietly predict double `qscore' if `sample', score
            if _rc {
                local rc = _rc
                local errtext "unable to obtain the native linear-predictor score for model `name'"
                continue, break
            }
            local scoresource`i' "native_predict_score"
        }

        quietly summarize `qscore' if `sample', meanonly
        if r(N) != `N`i'' | r(min) >= . | r(max) >= . {
            local rc 498
            local errtext "the PA score construction produced missing values for model `name'"
            continue, break
        }
    }

    if `rc' {
        foreach v of local cleanupvars {
            capture drop `v'
        }
        foreach m of local cleanupmats {
            capture matrix drop `m'
        }
        di as err "`errtext'"
        exit `rc'
    }

    local scorevar `"`requested_cluster'"'
    if trim(`"`scorevar'"') == "" local scorevar `"`panelvar'"'
    capture confirm numeric variable `scorevar'
    if _rc {
        local rc = _rc
        foreach v of local cleanupvars {
            capture drop `v'
        }
        foreach m of local cleanupmats {
            capture matrix drop `m'
        }
        di as err "cluster variable {bf:`scorevar'} must exist and be numeric"
        exit `rc'
    }

    tempvar union
    quietly generate byte `union' = 0
    forvalues i = 1/`nmodels' {
        quietly replace `union' = 1 if `sample`i''
        quietly count if `sample`i'' & missing(`scorevar')
        if r(N) {
            foreach v of local cleanupvars {
            capture drop `v'
        }
            foreach m of local cleanupmats {
                capture matrix drop `m'
            }
            local name : word `i' of `names'
            di as err "cluster variable {bf:`scorevar'} is missing in the estimation sample for model {bf:`name'}"
            exit 459
        }
    }

    if `"`scorevar'"' != `"`panelvar'"' {
        tempvar cmin cmax
        bysort `panelvar': egen double `cmin' = min(cond(`union',`scorevar',.))
        bysort `panelvar': egen double `cmax' = max(cond(`union',`scorevar',.))
        quietly count if `union' & `cmin' != `cmax'
        if r(N) {
            foreach v of local cleanupvars {
            capture drop `v'
        }
            foreach m of local cleanupmats {
                capture matrix drop `m'
            }
            di as err "panels in {bf:`panelvar'} are not nested within clusters in {bf:`scorevar'}"
            exit 459
        }
    }

    tempvar tagunion
    quietly egen byte `tagunion' = tag(`scorevar') if `union'
    quietly count if `tagunion'
    local Gsys = r(N)
    if `Gsys' < 2 {
        foreach v of local cleanupvars {
            capture drop `v'
        }
        foreach m of local cleanupmats {
            capture matrix drop `m'
        }
        di as err "the population-averaged system contains fewer than two clusters in {bf:`scorevar'}"
        exit 459
    }
    quietly count if `union'
    local Nsys = r(N)

    local Ktotal 0
    forvalues i = 1/`nmodels' {
        local start`i' = `Ktotal'+1
        local Ktotal = `Ktotal'+`K`i''
        local end`i' = `Ktotal'

        tempvar tagi
        quietly egen byte `tagi' = tag(`scorevar') if `sample`i''
        quietly count if `tagi'
        local G`i' = r(N)
        if `G`i'' < 2 {
            foreach v of local cleanupvars {
            capture drop `v'
        }
            foreach m of local cleanupmats {
                capture matrix drop `m'
            }
            local name : word `i' of `names'
            di as err "model {bf:`name'} contains fewer than two clusters in {bf:`scorevar'}"
            exit 459
        }
        local scale`i' = (`G`i''/(`G`i''-1))/(`Gsys'/(`Gsys'-1))
        quietly generate double `qscaled`i'' = `qscore`i''*sqrt(`scale`i'') if `sample`i''
        quietly replace `qscaled`i'' = 0 if `union' & missing(`qscaled`i'')
        local qscores `qscores' `qscaled`i''
    }

    tempname bout Vsys
    local eqused
    forvalues i = 1/`nmodels' {
        local name : word `i' of `names'
        local eq = substr(strtoname("`name'_mean"),1,32)
        local duplicate : list posof "`eq'" in eqused
        if `duplicate' local eq = substr("s2pa`i'_mean",1,32)
        local eqused `"`eqused' `eq'"'
        local eqname`i' `"`eq'"'

        tempname bi Vi
        matrix `bi' = `bsrc`i''
        matrix `Vi' = `Vsrc`i''
        local eqlist
        forvalues q = 1/`K`i'' {
            local eqlist `eqlist' `eq'
        }
        local allcn `allcn' `nativecn`i''
        local alleq `alleq' `eqlist'
        matrix coleq `bi' = `eqlist'
        matrix coleq `Vi' = `eqlist'
        matrix roweq `Vi' = `eqlist'
        if `i' == 1 {
            matrix `bout' = `bi'
            matrix `Vsys' = `Vi'
        }
        else {
            local oldK = colsof(`Vsys')
            matrix `Vsys' = (`Vsys',J(`oldK',`K`i'',0)\J(`K`i'',`oldK',0),`Vi')
            matrix `bout' = `bout',`bi'
        }
    }

    matrix colnames `bout' = `allcn'
    matrix coleq `bout' = `alleq'
    matrix colnames `Vsys' = `allcn'
    matrix rownames `Vsys' = `allcn'
    matrix coleq `Vsys' = `alleq'
    matrix roweq `Vsys' = `alleq'

    local stripe_cn : colnames `Vsys'
    local stripe_eq : coleq `Vsys'
    local stripe_uniq : list uniq stripe_eq
    local nstripe_cn : word count `stripe_cn'
    local nstripe_eq : word count `stripe_eq'
    local nstripe_uniq : word count `stripe_uniq'
    if `nstripe_cn' != `Ktotal' | `nstripe_eq' != `Ktotal' | `nstripe_uniq' != `nmodels' {
        foreach v of local cleanupvars {
            capture drop `v'
        }
        foreach m of local cleanupmats {
            capture matrix drop `m'
        }
        di as err "the joint population-averaged covariance stripe was not preserved"
        exit 498
    }
    capture quietly _ms_lf_info, matrix(`Vsys')
    local lfrc = _rc
    if `lfrc' {
        foreach v of local cleanupvars {
            capture drop `v'
        }
        foreach m of local cleanupmats {
            capture matrix drop `m'
        }
        di as err "the joint population-averaged covariance stripe is not valid likelihood-form information"
        exit `lfrc'
    }
    if r(k_lf) != `nmodels' {
        foreach v of local cleanupvars {
            capture drop `v'
        }
        foreach m of local cleanupmats {
            capture matrix drop `m'
        }
        di as err "the joint population-averaged covariance stripe does not identify one score equation per model"
        exit 498
    }

    foreach s of local qscores {
        capture confirm variable `s'
        if _rc {
            local rc = _rc
            foreach v of local cleanupvars {
                capture drop `v'
            }
            foreach m of local cleanupmats {
                capture matrix drop `m'
            }
            di as err "PA system score variable {bf:`s'} was not retained through covariance construction"
            exit `rc'
        }
    }
    capture noisily _robust2 `qscores' if `union', variance(`Vsys') cluster(`scorevar')
    if _rc {
        local rc = _rc
        foreach v of local cleanupvars {
            capture drop `v'
        }
        foreach m of local cleanupmats {
            capture matrix drop `m'
        }
        di as err "unable to construct the joint population-averaged covariance matrix"
        exit `rc'
    }

    forvalues i = 1/`nmodels' {
        tempname Vblock Vtarget
        matrix `Vblock' = `Vsys'[`start`i''..`end`i'',`start`i''..`end`i'']
        matrix `Vtarget' = `Vsrc`i''
        capture quietly _robust2 `qscore`i'' if `sample`i'', ///
            variance(`Vtarget') cluster(`scorevar')
        if _rc {
            local rc = _rc
            foreach v of local cleanupvars {
            capture drop `v'
        }
            foreach m of local cleanupmats {
                capture matrix drop `m'
            }
            di as err "unable to validate the model-specific PA covariance block"
            exit `rc'
        }
        mata: st_numscalar("__s2pa_diagdiff",max(abs(st_matrix("`Vblock'"):-st_matrix("`Vtarget'"))))
        mata: st_numscalar("__s2pa_diagscale",1+max(abs(st_matrix("`Vtarget'"))))
        if scalar(__s2pa_diagdiff)>1e-8*scalar(__s2pa_diagscale) {
            foreach v of local cleanupvars {
            capture drop `v'
        }
            foreach m of local cleanupmats {
                capture matrix drop `m'
            }
            local name : word `i' of `names'
            di as err "the joint PA covariance does not reproduce the model-specific block for model {bf:`name'}"
            exit 498
        }
    }

    tempvar tagpanel
    quietly egen byte `tagpanel' = tag(`panelvar') if `union'
    quietly count if `tagpanel'
    local Ngsys = r(N)

    ereturn post `bout' `Vsys', obs(`Nsys') esample(`union')
    mata: st_numscalar("__s2_xtparank",rank(st_matrix("`Vsys'")))
    ereturn scalar rank = scalar(__s2_xtparank)
    ereturn scalar N_clust = `Gsys'
    ereturn scalar N_g = `Ngsys'
    ereturn local clustvar `"`scorevar'"'
    ereturn local vce "cluster"
    ereturn local vcetype "Robust"
    ereturn local names `"`names'"'
    ereturn local properties "b V"
    ereturn scalar suest2_xtpa = 1
    local anynonlinear 0
    forvalues i = 1/`nmodels' {
        if "`activecmd`i''"!="xtreg" local anynonlinear 1
    }
    ereturn scalar suest2_xtpa_any_nonlinear = `anynonlinear'
    ereturn local suest2_xtpa_panelvar `"`panelvar'"'
    ereturn local suest2_xtpa_scorevar `"`scorevar'"'
    ereturn local suest2_xtpa_engine "gee_linear_predictor_scores"
    ereturn local suest2_xtpa_runtime_revision "v0170_candidate1"
    ereturn local suest2_xtpa_displayopts `"`displayopts'"'
    ereturn local title "Simultaneous population-averaged results"
    ereturn local cmd "suest2_xtpa"

    forvalues i = 1/`nmodels' {
        ereturn local eqnames`i' `"`eqname`i''"'
        ereturn scalar suest2_xtpa_N`i' = `N`i''
        ereturn scalar suest2_xtpa_Npanel`i' = `Ng_native`i''
        ereturn scalar suest2_xtpa_G`i' = `G`i''
        ereturn scalar suest2_xtpa_K`i' = `K`i''
        ereturn scalar suest2_xtpa_rank`i' = `rank`i''
        ereturn scalar suest2_xtpa_phi`i' = `phi`i''
        ereturn scalar suest2_xtpa_scale`i' = `scale`i''
        ereturn local suest2_xtpa_corr`i' `"`corr`i''"'
        ereturn local suest2_xtpa_tvar`i' `"`tvar`i''"'
        ereturn local suest2_xtpa_cmd`i' `"`activecmd`i''"'
        ereturn local suest2_xtpa_family`i' `"`family`i''"'
        ereturn local suest2_xtpa_link`i' `"`link`i''"'
        ereturn local suest2_xtpa_scoresource`i' `"`scoresource`i''"'
    }

    foreach v of local cleanupvars {
            capture drop `v'
        }
    foreach m of local cleanupmats {
        capture matrix drop `m'
    }
end




// ============================================================================
// Generic meglm and heterogeneous mixed-family score route
// ============================================================================

program define suest2_mehetero_identify, rclass
    version 16

    local cmd=lower(trim("`e(cmd)'"))
    local cmd2=lower(trim("`e(cmd2)'"))
    local model=lower(trim("`e(model)'"))
    local family=lower(trim("`e(family)'"))
    local link=lower(trim("`e(link)'"))
    local distribution=lower(trim("`e(distribution)'"))
    local frm2=lower(trim("`e(frm2)'"))
    local supported 0
    local generic 0
    local mestreg 0
    local xtgre 0
    local plain 0
    local bridgecmd
    local activecmd
    local class
    local scorelayout observation

    if "`cmd'"=="xtlogit" & "`model'"=="re" & lower(trim("`e(distrib)'"))=="gaussian" {
        local supported 1
        local xtgre 1
        local bridgecmd melogit
        local activecmd xtlogit
        local class bernoulli_logit
        local scorelayout group
    }
    else if "`cmd'"=="xtprobit" & "`model'"=="re" & lower(trim("`e(distrib)'"))=="gaussian" {
        local supported 1
        local xtgre 1
        local bridgecmd meprobit
        local activecmd xtprobit
        local class bernoulli_probit
        local scorelayout group
    }
    else if "`cmd'"=="xtpoisson" & "`model'"=="re" & lower(trim("`e(distrib)'"))=="gaussian" {
        local supported 1
        local xtgre 1
        local bridgecmd mepoisson
        local activecmd xtpoisson
        local class poisson_log
        local scorelayout group
    }
    else if ("`cmd'"=="xtologit" | "`cmd2'"=="xtologit") & ///
        "`model'"=="ologit" & "`family'"=="ordinal" & "`link'"=="logit" {
        local supported 1
        local xtgre 1
        local bridgecmd meologit
        local activecmd xtologit
        local class ordinal_logit
        local scorelayout group
    }
    else if ("`cmd'"=="xtoprobit" | "`cmd2'"=="xtoprobit") & ///
        "`model'"=="oprobit" & "`family'"=="ordinal" & "`link'"=="probit" {
        local supported 1
        local xtgre 1
        local bridgecmd meoprobit
        local activecmd xtoprobit
        local class ordinal_probit
        local scorelayout group
    }
    else if "`cmd'"=="xtcloglog" & "`model'"=="re" {
        local supported 1
        local xtgre 1
        local bridgecmd mecloglog
        local activecmd xtcloglog
        local class bernoulli_cloglog
        local scorelayout group
    }
    else if inlist("`cmd'","ologit","oprobit") & trim(`"`e(prefix)'"')=="" & ///
        trim(`"`e(wtype)'"')=="" {
        // 0.1.90: ordinary ordinal constituent for the heterogeneous
        // route -- admitted only unprefixed and unweighted; it inherits
        // the joint cluster from a mixed partner downstream.
        local supported 1
        local plain 1
        local activecmd `cmd'
        local class ordinal_logit
        if "`cmd'"=="oprobit" local class ordinal_probit
    }
    else if "`cmd'"=="mixed" {
        local supported 1
        local activecmd mixed
        local class gaussian_identity
        local scorelayout group
    }
    else if inlist("`cmd'","meglm","gsem") & ///
        inlist("`cmd2'","meglm","melogit","meprobit","mecloglog", ///
            "mepoisson","menbreg","meologit","meoprobit","mestreg") {
        local generic=("`cmd2'"=="meglm")
        local mestreg=("`cmd2'"=="mestreg")

        if `mestreg' {
            if "`distribution'"=="exponential" & inlist("`frm2'","hazard","time") {
                local supported 1
                local activecmd mestreg
                local class survival_exponential_`frm2'
            }
            else if "`distribution'"=="weibull" & inlist("`frm2'","hazard","time") {
                local supported 1
                local activecmd mestreg
                local class survival_weibull_`frm2'
            }
            else if "`distribution'"=="lognormal" & "`frm2'"=="time" {
                local supported 1
                local activecmd mestreg
                local class survival_lognormal_time
            }
            else if "`distribution'"=="loglogistic" & "`frm2'"=="time" {
                local supported 1
                local activecmd mestreg
                local class survival_loglogistic_time
            }
            else if "`distribution'"=="gamma" & "`frm2'"=="time" {
                local supported 1
                local activecmd mestreg
                local class survival_gamma_time
            }
        }
        else if "`family'"=="bernoulli" & "`link'"=="logit" & "`model'"=="logistic" {
            local supported 1
            local activecmd melogit
            local class bernoulli_logit
        }
        else if "`family'"=="bernoulli" & "`link'"=="probit" & "`model'"=="probit" {
            local supported 1
            local activecmd meprobit
            local class bernoulli_probit
        }
        else if "`family'"=="bernoulli" & "`link'"=="cloglog" & "`model'"=="cloglog" {
            local supported 1
            local activecmd mecloglog
            local class bernoulli_cloglog
        }
        else if "`family'"=="poisson" & "`link'"=="log" & "`model'"=="poisson" {
            local supported 1
            local activecmd mepoisson
            local class poisson_log
        }
        else if "`family'"=="nbinomial" & "`link'"=="log" & "`model'"=="nbinomial" {
            local supported 1
            local activecmd menbreg
            local class nbinomial_log
        }
        else if "`family'"=="ordinal" & "`link'"=="logit" & "`model'"=="ologit" {
            local supported 1
            local activecmd meologit
            local class ordinal_logit
        }
        else if "`family'"=="ordinal" & "`link'"=="probit" & "`model'"=="oprobit" {
            local supported 1
            local activecmd meoprobit
            local class ordinal_probit
        }
        else if "`family'"=="gaussian" & "`link'"=="identity" & "`model'"=="linear" & `generic' {
            local supported 1
            local activecmd megaussian
            local class gaussian_identity
        }
        else if "`family'"=="gamma" & "`link'"=="log" & "`model'"=="gamma" & `generic' {
            local supported 1
            local activecmd megamma
            local class gamma_log
        }
    }

    return scalar supported=`supported'
    return scalar generic=`generic'
    return scalar mestreg=`mestreg'
    return scalar xtgre=`xtgre'
    return scalar plain=`plain'
    return local bridgecmd `"`bridgecmd'"'
    return local activecmd `"`activecmd'"'
    return local class `"`class'"'
    return local scorelayout `"`scorelayout'"'
    return local distribution `"`distribution'"'
    return local frm2 `"`frm2'"'
end

program define suest2_meheteroscan, rclass
    version 16
    syntax [anything] [, CLuster(passthru) VCE(passthru) MINUS(passthru) ///
        REGRESSML SVY Level(passthru) DIR EForm(passthru) Robust *]

    est_expand `"`anything'"', min(1) default(.)
    local names `"`r(names)'"'
    local names : list uniq names
    local nmodels : word count `names'
    local allsupported=(`nmodels'>0)
    local hasgeneric 0
    local hasmestreg 0
    local hasxtgre 0
    local hasplain 0
    local allplain 1
    local classes

    foreach name of local names {
        if "`name'"=="." {
            local allsupported 0
            continue
        }
        capture quietly estimates restore `name'
        if _rc {
            local allsupported 0
            continue
        }
        quietly suest2_mehetero_identify
        if !r(supported) local allsupported 0
        else {
            local classes `classes' `r(class)'
            if r(generic) local hasgeneric 1
            if r(mestreg) local hasmestreg 1
            if r(xtgre) local hasxtgre 1
            if r(plain) local hasplain 1
            else local allplain 0
        }
    }
    local classes : list uniq classes
    local nclasses : word count `classes'
*   0.1.90/0.1.93: a plain ordinal constituent routes here only in MIXED
*   company. 0.1.93: the !allplain factor now guards EVERY arm -- an
*   all-ordinary pair of different classes (ologit+oprobit) satisfied
*   nclasses>1 once both were identifiable and was hijacked from the
*   working ordinary route (mec-final-gate O pair, measured 25aug2026).
    local has=(`allsupported' & !`allplain' & (`hasgeneric' | `hasmestreg' | `hasxtgre' | `nclasses'>1 | `hasplain'))
    return scalar has=`has'
    return scalar has_mehetero=`has'
    return scalar all_supported=`allsupported'
    return scalar has_generic=`hasgeneric'
    return scalar has_mestreg=`hasmestreg'
    return scalar has_xtgre=`hasxtgre'
    return scalar has_plain=`hasplain'
    return scalar nclasses=`nclasses'
    return local classes `"`classes'"'
    return local names `"`names'"'
end

program define suest2_mehetero_native_robust, eclass
    version 9
    syntax, CLuster(varname)
    local vv : display "version " string(_caller()) ":"
    tempname b
    matrix `b'=e(b)
    local K=colsof(`b')
    forvalues j=1/`K' {
        tempname sc`j'
        local scores `scores' `sc`j''
    }
    `vv' quietly predict double `scores' if e(sample), scores
    _robust2 `scores' if e(sample), cluster(`cluster') allcons
end

program define suest2_mehetero_plain_robust, eclass
    version 9
    // 0.1.90: block-reproduction variant for ordinary constituents. The
    // native variant asks predict for column-count scores, which
    // ordinary ordinal models refuse r(103); this one sandwiches the
    // already-expanded column scores over the restored result.
    syntax, SCores(varlist) SAMPLE(varname) CLuster(varname)
    _robust2 `scores' if `sample', cluster(`cluster') allcons
end

program define suest2_mehetero_repost, eclass
    version 16
    args b V
    if "`V'"=="" ereturn repost b=`b'
    else ereturn repost b=`b' V=`V'
end

program define suest2_mehetero_bridge_robust, eclass
    version 9
    syntax, B(name) V(name) SAMPLE(varname) SCORES(varlist) CLUSTER(varname)
    ereturn post `b' `v', esample(`sample')
    ereturn local cmd "suest2_mehetero_bridge"
    ereturn local properties "b V"
    _robust2 `scores' if e(sample), cluster(`cluster') allcons
end

program define suest2_mehetero_joint_robust, eclass
    version 9
    syntax, B(name) V(name) SAMPLE(varname) SCORES(varlist) ///
        [CLUSTER(varname) SVY]
    ereturn post `b' `v', esample(`sample')
    ereturn local cmd "suest2_mehetero_joint"
    ereturn local properties "b V"
    // Under svy: the design is read by _robust2 from the live svyset, which
    // is why the caller requires the stored design and the live one to agree.
    if "`svy'"!="" _robust2 `scores' if e(sample), svy allcons
    else _robust2 `scores' if e(sample), cluster(`cluster') allcons
end

program define suest2_meheteroestimate, sortpreserve eclass
    version 16
    syntax [anything] [, CLuster(varname) VCE(string asis) Robust MINUS ///
        REGRESSML SVY Level(cilevel) DIR EForm(passthru) *]

    if "`minus'"!="" | "`regressml'"!="" | "`svy'"!="" {
        di as err "options minus, regressml, and svy are not supported for heterogeneous mixed-model systems"
        exit 198
    }

    local displayopts
    if "`level'"!="" local displayopts `"`displayopts' level(`level')"'
    if "`dir'"!="" local displayopts `"`displayopts' dir"'
    if `"`eform'"'!="" local displayopts `"`displayopts' `eform'"'
    if trim(`"`options'"')!="" local displayopts `"`displayopts' `options'"'

    if "`cluster'"!="" & trim(`"`vce'"')!="" {
        di as err "specify only one of cluster() or vce()"
        exit 198
    }
    if "`cluster'"!="" & "`robust'"!="" {
        di as err "specify only one of cluster() or robust"
        exit 198
    }
    if trim(`"`vce'"')!="" & "`robust'"!="" {
        di as err "specify only one of vce() or robust"
        exit 198
    }

    local requested_cluster `"`cluster'"'
    if trim(`"`vce'"')!="" {
        local vcelower = ustrlower(itrim(trim(`"`vce'"')))
        if "`vcelower'" == "robust" local requested_cluster
        else if ustrregexm(`"`vcelower'"', "^cluster[ ]+([A-Za-z_][A-Za-z0-9_]*)$") {
            local requested_cluster `"`=ustrregexs(1)'"'
        }
        else if ustrregexm(`"`vcelower'"', "^cluster[ ]*\([ ]*([A-Za-z_][A-Za-z0-9_]*)[ ]*\)$") {
            local requested_cluster `"`=ustrregexs(1)'"'
        }
        else {
            di as err "the heterogeneous mixed-model route supports only vce(robust) or vce(cluster varname)"
            exit 198
        }
    }

    est_expand `"`anything'"', min(2) default(.)
    local names `"`r(names)'"'
    local names : list uniq names
    local nmodels : word count `names'
    local hasdot : list posof "." in names
    if `hasdot' {
        di as err "heterogeneous mixed-model support requires named stored estimates"
        exit 198
    }

    // DESIGN PRE-PASS, before the reproduction refits (see the melogit
    // bridge for why). Two bridge-specific facts, both measured: meglm and
    // mestreg store e(vce)=="robust" on a weighted fit while a weighted
    // mixed store reaching this route stores "cluster" (diag_wme_N4), and
    // both are admitted; and the meat here is built over GROUP rows while
    // the svy: recipe was measured for the OBSERVATION layout only
    // (diag_wme_N3b), so the svy path is refused rather than guessed -- no
    // group-layout family currently fits under svy: anyway.
    local dgrc 0
    local dgtext
    local dgskip 0
    local sysshape "plain"
    forvalues i=1/`nmodels' {
        local name : word `i' of `names'
        capture quietly estimates restore `name'
        if _rc {
            local dgskip 1
            continue
        }
        capture quietly suest2_mehetero_identify
        if _rc {
            local dgskip 1
            continue
        }
        if !r(supported) {
            local dgskip 1
            continue
        }
        local dglayout_`i' `"`r(scorelayout)'"'
        local wshape`i' "none"
        if trim(`"`e(wtype)'"')=="" & trim(`"`e(prefix)'"')=="" & ///
            inlist(`"`e(vce)'"',"","oim","conventional") {
            local wshape`i' "plain"
        }
        else if trim(`"`e(prefix)'"')=="svy" & ///
            `"`e(vce)'"'=="linearized" & `"`e(wtype)'"'=="pweight" {
            local wshape`i' "svy"
        }
        else if trim(`"`e(prefix)'"')=="" & `"`e(wtype)'"'=="pweight" & ///
            inlist(`"`e(vce)'"',"robust","cluster") {
            local wshape`i' "pweight"
        }
        if "`wshape`i''"=="none" {
            if trim(`"`e(prefix)'"')=="svy" {
                local dgrc 322
                local dgtext "survey model `name' uses `e(vce)' variance estimation; only linearized survey results are supported"
            }
            else if trim(`"`e(prefix)'"')!="" {
                local dgrc 322
                local dgtext "model `name' was estimated under the `e(prefix)' prefix, which is not supported"
            }
            else if !inlist(`"`e(wtype)'"',"","pweight") {
                local dgrc 198
                local dgtext "heterogeneous mixed-model systems accept pweights and the svy: prefix; model `name' carries `e(wtype)'s"
            }
            else {
                local dgrc 322
                local dgtext "store conventional estimates and request robust or clustered VCE with suest2, or fit the models with pweights or under svy:"
            }
            continue, break
        }
        if "`wshape`i''"!="plain" {
            local emacs
            capture local emacs : e(macros)
            if _rc | "`emacs'"=="" local emacs "`e(macros)'"
            local fpcfound
            foreach em of local emacs {
                if substr("`em'",1,3)=="fpc" local fpcfound "`em'"
            }
            if "`fpcfound'"!="" {
                local dgrc 322
                local dgtext "model `name' carries a finite population correction (e(`fpcfound')); FPC survey designs are not supported"
                continue, break
            }
            if trim(`"`e(subpop)'"')!="" {
                local dgrc 322
                local dgtext "model `name' was estimated with subpop(`e(subpop)'); subpopulation estimation is not supported"
                continue, break
            }
            capture confirm matrix e(V_modelbased)
            if _rc {
                local dgrc 498
                local dgtext "weighted model `name' does not retain e(V_modelbased), which the joint sandwich requires as its bread"
                continue, break
            }
            local lwexp`i'
            if "`wshape`i''"=="svy" {
                if `"`dglayout_`i''"'!="observation" {
                    local dgrc 322
                    local dgtext "model `name' returns one score per group rather than per observation, so there is no level-1 sampling weight to divide by; svy: is not supported for this family"
                    continue, break
                }
                local rawwexp=trim(`"`e(wexp)'"')
                if substr(`"`rawwexp'"',1,1)!="=" {
                    local dgrc 498
                    local dgtext "survey model `name' does not retain a level-1 sampling weight in e(wexp)"
                    continue, break
                }
                local lwexp`i'=trim(substr(`"`rawwexp'"',2,.))
                if trim("`lwexp`i''")=="" {
                    local dgrc 498
                    local dgtext "survey model `name' retains an empty level-1 sampling weight in e(wexp)"
                    continue, break
                }
            }
            else {
                if trim(`"`e(pweight1)'"')=="" {
                    local dgrc 198
                    local dgtext "model `name' was fit with a weight but without a stage weight, so it carries no higher-level weight to build a design from; a weighted multilevel system needs one, as in [pw=w2] || group:, pweight(w1), or use the svy: prefix"
                    continue, break
                }
                if trim(`"`e(clustvar)'"')=="" {
                    local dgrc 498
                    local dgtext "pweighted model `name' does not retain e(clustvar)"
                    continue, break
                }
            }
            local dgprefix_`i' `"`e(prefix)'"'
            local dgsu_`i' `"`e(su1)'"'
            local dgstrata_`i' `"`e(strata1)'"'
            local dgw1_`i' `"`e(weight1)'"'
            local dgw2_`i' `"`e(weight2)'"'
            local dgwexp_`i' `"`e(wexp)'"'
            local dgwtype_`i' `"`e(wtype)'"'
            local dgclust_`i' `"`e(clustvar)'"'
            local dgpw1_`i' `"`e(pweight1)'"'
            local dgsingle_`i' `"`e(singleunit)'"'
            local dgnstrata_`i' .
            capture local dgnstrata_`i'=e(N_strata)
        }
    }
    if `dgrc' {
        di as err "`dgtext'"
        exit `dgrc'
    }
    if !`dgskip' {
        local sysshape `"`wshape1'"'
        local name1 : word 1 of `names'
        forvalues i=2/`nmodels' {
            local name : word `i' of `names'
            if "`wshape`i''"!="`sysshape'" {
                di as err "constituents mix weighting schemes: model {bf:`name1'} is `sysshape' and model {bf:`name'} is `wshape`i''"
                exit 322
            }
        }
        if "`sysshape'"!="plain" {
            forvalues i=2/`nmodels' {
                local name : word `i' of `names'
                local mism
                if `"`dgprefix_`i''"'!=`"`dgprefix_1'"' local mism "e(prefix)"
                else if `"`dgsu_`i''"'!=`"`dgsu_1'"' local mism "e(su1)"
                else if `"`dgstrata_`i''"'!=`"`dgstrata_1'"' local mism "e(strata1)"
                else if `"`dgw1_`i''"'!=`"`dgw1_1'"' local mism "e(weight1)"
                else if `"`dgw2_`i''"'!=`"`dgw2_1'"' local mism "e(weight2)"
                else if `"`dgwexp_`i''"'!=`"`dgwexp_1'"' local mism "e(wexp)"
                else if `"`dgwtype_`i''"'!=`"`dgwtype_1'"' local mism "e(wtype)"
                else if `"`dgclust_`i''"'!=`"`dgclust_1'"' local mism "e(clustvar)"
                else if `"`dgpw1_`i''"'!=`"`dgpw1_1'"' local mism "e(pweight1)"
                else if `"`dgsingle_`i''"'!=`"`dgsingle_1'"' local mism "e(singleunit)"
                else if `"`dgnstrata_`i''"'!=`"`dgnstrata_1'"' local mism "e(N_strata)"
                if "`mism'"!="" {
                    di as err "constituents describe different survey designs: `mism' differs between models {bf:`name1'} and {bf:`name'}"
                    exit 322
                }
            }
        }
    }

    local highvar
    local rc 0
    local errtext
    local jointscores
    local allcn
    local alleq
    local classes
    local hasmestreg 0
    local allmestreg 1
    local hasxtgre 0
    local allxtgre 1

    forvalues i=1/`nmodels' {
        local name : word `i' of `names'
        capture quietly estimates restore `name'
        if _rc {
            local rc=_rc
            local errtext "unable to restore constituent model `name'"
            continue, break
        }

        quietly suest2_mehetero_identify
        if !r(supported) {
            local rc 322
            local errtext "model `name' is not a supported generic meglm, mestreg, or mixed-family constituent"
            continue, break
        }
        local activecmd`i' `"`r(activecmd)'"'
        local class`i' `"`r(class)'"'
        local generic`i'=r(generic)
        local mestreg`i'=r(mestreg)
        local xtgre`i'=r(xtgre)
        local bridgecmd`i' `"`r(bridgecmd)'"'
        local scorehint`i' `"`r(scorelayout)'"'
        local plain`i'=r(plain)
        if `mestreg`i'' local hasmestreg 1
        else local allmestreg 0
        if `xtgre`i'' local hasxtgre 1
        else local allxtgre 0
        local classes `classes' `class`i''

        if inlist("`activecmd`i''","megaussian","megamma") & trim(`"`e(offset)'"')!="" {
            local rc 322
            local errtext "offsets for generic Gaussian and Gamma models are not supported in the first increment"
            continue, break
        }

        if "`plain`i''"=="1" {
            // 0.1.90: ordinary constituent -- no integration settings to
            // validate; require a conventional store like every other
            // constituent on this route.
            if !inlist(`"`e(vce)'"',"","oim") {
                local rc 322
                local errtext "store conventional (non-robust) estimates for ordinary constituent `name'; suest2 supplies the robust or clustered VCE"
                continue, break
            }
            local nquad`i'=.
        }
        else if `xtgre`i'' {
            if "`wshape`i''"=="plain" & !inlist(`"`e(vce)'"',"","oim") {
                local rc 322
                local errtext "store conventional Gaussian random-effects xt estimates and request robust or clustered VCE with suest2"
                continue, break
            }
            if "`e(intmethod)'"!="mvaghermite" {
                local rc 322
                local errtext "model `name' requires adaptive Gaussian-Hermite quadrature"
                continue, break
            }
            local nquad`i'=real("`e(n_quad)'")
            local minquad`i'=12
            if "`activecmd`i''"=="xtcloglog" local minquad`i'=24
            if missing(`nquad`i'') | `nquad`i''<`minquad`i'' {
                local rc 322
                // Name the remedy: refitting with intpoints() is what
                // satisfies the requirement, and the count shown is one
                // Stata chose, not one the user typed.
                local errtext "model `name' was fit with `nquad`i'' quadrature points; the exact Gaussian-RE score bridge requires at least `minquad`i''. Refit it as: `activecmd`i'' ..., intpoints(`minquad`i'') -- then store it again"
                continue, break
            }
            if trim(`"`e(wtype)'"')!="" {
                local rc 198
                local errtext "weights are not yet supported for Gaussian nonlinear-panel random-effects bridges"
                continue, break
            }
            if "`activecmd`i''"=="xtcloglog" & ///
                ustrregexm(lower(`"`e(cmdline)'"'),"(^|[ ,])nocons(tant)?($|[ ,])") {
                local rc 322
                local errtext "noconstant xtcloglog, re models are not supported in this increment"
                continue, break
            }
            capture confirm matrix e(Cns)
            if !_rc {
                local __s2_kcns=rowsof(e(Cns))
                local __s2_kauto 0
                capture local __s2_kauto=e(k_autoCns)
                if _rc local __s2_kauto 0
                if `__s2_kcns'>`__s2_kauto' {
                    local rc 322
                    local errtext "user-specified constraints are not supported for Gaussian nonlinear-panel random-effects bridges"
                    continue, break
                }
            }
        }
        else if "`activecmd`i''"=="mixed" {
            if "`e(method)'"!="ML" {
                local rc 322
                local errtext "mixed model `name' must be fit by ML using option mle"
                continue, break
            }
            if "`wshape`i''"=="plain" & !inlist(`"`e(vce)'"',"","conventional") {
                local rc 322
                local errtext "store conventional mixed, mle estimates and request robust or clustered VCE with suest2"
                continue, break
            }
            if `"`e(rstructure)'"'!="independent" | e(k_res)!=0 {
                local rc 322
                local errtext "mixed model `name' must use the default independent residual structure"
                continue, break
            }
        }
        else {
            if "`wshape`i''"=="plain" & !inlist(`"`e(vce)'"',"","oim") {
                local rc 322
                local errtext "store conventional adaptive-quadrature estimates and request robust or clustered VCE with suest2"
                continue, break
            }
            if "`e(intmethod)'"!="mvaghermite" {
                local rc 322
                local errtext "model `name' requires adaptive Gaussian-Hermite quadrature; Laplace integration is not supported"
                continue, break
            }
            local nquad`i'=real("`e(n_quad)'")
            if missing(`nquad`i'') | `nquad`i''<2 {
                local rc 322
                local errtext "model `name' requires at least two quadrature points so native scores are available"
                continue, break
            }
        }

        foreach scalar in N k rank {
            capture confirm scalar e(`scalar')
            if _rc {
                local rc 498
                local errtext "model `name' does not retain e(`scalar')"
                continue, break
            }
        }
        if `rc' continue, break
        if "`plain`i''"=="1" {
            local ivars`i'
        }
        else if !`xtgre`i'' {
            foreach scalar in k_f k_r {
                capture confirm scalar e(`scalar')
                if _rc {
                    local rc 498
                    local errtext "model `name' does not retain e(`scalar')"
                    continue, break
                }
            }
            if `rc' continue, break
            if e(k_r)<1 {
                local rc 322
                local errtext "model `name' does not contain random effects"
                continue, break
            }
            local ivars`i' `"`e(ivars)'"'
        }
        else local ivars`i' `"`e(ivar)'"'
        if "`plain`i''"!="1" {
            local high`i' : word 1 of `ivars`i''
            if trim(`"`high`i''"')=="" {
                local rc 498
                local errtext "model `name' does not retain a highest-level grouping variable"
                continue, break
            }
            if trim(`"`highvar'"')=="" local highvar `"`high`i''"'
            else if `"`high`i''"'!=`"`highvar'"' {
                local rc 459
                local errtext "all heterogeneous constituents must use the same highest-level grouping variable"
                continue, break
            }
            capture confirm numeric variable `high`i''
            if _rc {
                local rc=_rc
                local errtext "highest-level grouping variable `high`i'' must exist and be numeric"
                continue, break
            }
        }

        capture confirm matrix e(b)
        if _rc {
            local rc=_rc
            local errtext "model `name' does not contain e(b)"
            continue, break
        }
        capture confirm matrix e(V)
        if _rc {
            local rc=_rc
            local errtext "model `name' does not contain e(V)"
            continue, break
        }

        tempname pfx
        local pfx`i' `pfx'
        local bsrc `pfx'_b
        local Vsrc `pfx'_V
        local bref `pfx'_br
        local Vref `pfx'_Vr
        local bsrc`i' `bsrc'
        local Vsrc`i' `Vsrc'
        local Vbsrc `pfx'_Vb
        local Vbsrc`i' `Vbsrc'
        matrix `bsrc'=e(b)
        matrix `Vsrc'=e(V)
        if "`wshape`i''"=="plain" matrix `Vbsrc'=`Vsrc'
        else matrix `Vbsrc'=e(V_modelbased)
        local K`i'=colsof(`bsrc')
        local rank`i'=e(rank)
        local N`i'=e(N)
        if `xtgre`i'' {
            local kf`i'=`K`i''-1
            local kr`i'=1
            local redim`i' "1"
            local vartypes`i' "identity"
            local revars`i' "_cons"
        }
        else if "`plain`i''"=="1" {
            local kf`i'=`K`i''
            local kr`i' 0
            local redim`i'
            local vartypes`i'
            local revars`i'
        }
        else {
            local kf`i'=e(k_f)
            local kr`i'=e(k_r)
            local redim`i' `"`e(redim)'"'
            local vartypes`i' `"`e(vartypes)'"'
            local revars`i' `"`e(revars)'"'
        }
        local depvar`i' `"`e(depvar)'"'
        local intmethod`i' `"`e(intmethod)'"'
        local cmdline`i' `"`e(cmdline)'"'
        local llsrc`i'=e(ll)
        local offsetsrc`i' `"`e(offset)'"'
        local rstructure`i' `"`e(rstructure)'"'
        local optmetric`i' `"`e(optmetric)'"'
        local distribution`i'=lower(trim(`"`e(distribution)'"'))
        local frm2`i'=lower(trim(`"`e(frm2)'"'))
        local nativecn`i' : colnames `bsrc'
        local nativeeq`i' : coleq `bsrc'
        local nativefull`i' : colfullnames `bsrc'
        local nativeequniq`i' : list uniq nativeeq`i'

        local ordered`i'=inlist("`activecmd`i''","meologit","meoprobit","xtologit","xtoprobit","ologit","oprobit")
        local cutstart`i' 0
        local kcat`i' 0
        if `ordered`i'' {
            capture confirm scalar e(k_cat)
            if _rc {
                local rc 498
                local errtext "ordered model `name' does not retain e(k_cat)"
                continue, break
            }
            capture confirm matrix e(cat)
            if _rc {
                local rc 498
                local errtext "ordered model `name' does not retain e(cat)"
                continue, break
            }
            local kcat`i'=e(k_cat)
            tempname catsrc
            local catsrc`i' `catsrc'
            matrix `catsrc'=e(cat)
            forvalues j=1/`K`i'' {
                local fullj : word `j' of `nativefull`i''
                if inlist("`activecmd`i''","xtologit","xtoprobit") {
                    if `"`fullj'"'=="cut1:_cons" local cutstart`i'=`j'
                }
                else if `"`fullj'"'=="/cut1" local cutstart`i'=`j'
            }
            if !`cutstart`i'' {
                local rc 498
                local errtext "ordered model `name' does not retain its first cutpoint stripe"
                continue, break
            }
            local ncuts=`kcat`i''-1
            forvalues c=1/`ncuts' {
                local j=`cutstart`i''+`c'-1
                local fullj : word `j' of `nativefull`i''
                local expected "/cut`c'"
                if inlist("`activecmd`i''","xtologit","xtoprobit") local expected "cut`c':_cons"
                if `"`fullj'"'!=`"`expected'"' {
                    local rc 498
                    local errtext "ordered model `name' does not retain a contiguous cutpoint block"
                    continue, break
                }
            }
            if `rc' continue, break
        }

        tempvar sample sampleref
        local sample`i' `sample'
        quietly generate byte `sample'=e(sample)
        quietly count if `sample'
        if r(N)!=`N`i'' {
            local rc 459
            local errtext "the current data no longer reproduce the stored sample for model `name'"
            continue, break
        }

        if trim(`"`cmdline`i''"')=="" {
            local rc 498
            local errtext "model `name' does not retain e(cmdline)"
            continue, break
        }
        capture quietly `cmdline`i''
        if _rc {
            local rc=_rc
            local errtext "the current data cannot re-estimate stored model `name'"
            continue, break
        }
        matrix `bref'=e(b)
        matrix `Vref'=e(V)
        quietly generate byte `sampleref'=e(sample)
        quietly count if `sample'!=`sampleref'
        if r(N) {
            local rc 459
            local errtext "the current data do not reproduce the stored sample for model `name'"
            continue, break
        }
        quietly suest2_mehetero_identify
        local reprook=(r(supported) & `"`r(class)'"'==`"`class`i''"')
        mata: st_numscalar("__s2het_bdiff",max(abs(st_matrix("`bsrc'"):-st_matrix("`bref'"))))
        mata: st_numscalar("__s2het_Vdiff",max(abs(st_matrix("`Vsrc'"):-st_matrix("`Vref'"))))
        mata: st_numscalar("__s2het_bscale",1+max(abs(st_matrix("`bsrc'"))))
        mata: st_numscalar("__s2het_Vscale",1+max(abs(st_matrix("`Vsrc'"))))
        local structureok 1
        if `xtgre`i'' {
            if `"`e(ivar)'"'!=`"`ivars`i''"' local structureok 0
        }
        else if `"`e(ivars)'"'!=`"`ivars`i''"' | `"`e(redim)'"'!=`"`redim`i''"' | ///
            `"`e(vartypes)'"'!=`"`vartypes`i''"' | `"`e(revars)'"'!=`"`revars`i''"' local structureok 0
        if scalar(__s2het_bdiff)>1e-7*scalar(__s2het_bscale) | ///
            scalar(__s2het_Vdiff)>1e-7*scalar(__s2het_Vscale) | !`reprook' | !`structureok' {
            local rc 459
            local errtext "the current data do not reproduce coefficients, bread, or random-effects structure for model `name'"
            continue, break
        }
        if "`activecmd`i''"=="mixed" & (`"`e(rstructure)'"'!=`"`rstructure`i''"' | `"`e(optmetric)'"'!=`"`optmetric`i''"') {
            local rc 459
            local errtext "the current data do not reproduce the mixed-model specification for model `name'"
            continue, break
        }
        if "`activecmd`i''"!="mixed" & "`plain`i''"!="1" {
            if `"`e(intmethod)'"'!=`"`intmethod`i''"' | real("`e(n_quad)'")!=`nquad`i'' {
                local rc 459
                local errtext "the current data do not reproduce quadrature settings for model `name'"
                continue, break
            }
        }
        if "`activecmd`i''"=="mestreg" {
            if lower(trim(`"`e(distribution)'"'))!=`"`distribution`i''"' | ///
                lower(trim(`"`e(frm2)'"'))!=`"`frm2`i''"' {
                local rc 459
                local errtext "the current data do not reproduce the mestreg distribution or metric for model `name'"
                continue, break
            }
        }
        if `ordered`i'' {
            if e(k_cat)!=`kcat`i'' {
                local rc 459
                local errtext "the current data do not reproduce outcome categories for model `name'"
                continue, break
            }
            tempname catref
            matrix `catref'=e(cat)
            mata: st_numscalar("__s2het_catdiff",max(abs(st_matrix("`catsrc`i''"):-st_matrix("`catref'"))))
            if scalar(__s2het_catdiff)>1e-12 {
                local rc 459
                local errtext "the current data do not reproduce outcome categories for model `name'"
                continue, break
            }
        }

        local scorelist
        forvalues j=1/`K`i'' {
            tempvar sc
            local scorelist `scorelist' `sc'
        }

        if `xtgre`i'' {
            // A stored command line with NO options has no comma and is
            // not invalid: a bare -xtologit y x- pair must combine
            // (measured 18aug2026, four families, totalme_baseline_v1.0
            // PART X3). nativeopts is read only for noconstant and
            // exposure()/offset(), both legitimately absent here, so an
            // empty nativeopts is correct.
            local comma=strpos(`"`cmdline`i''"',",")
            if !`comma' {
                local left=trim(`"`cmdline`i''"')
                local nativeopts ""
            }
            else {
                local left=trim(substr(`"`cmdline`i''"',1,`comma'-1))
                local nativeopts=lower(trim(substr(`"`cmdline`i''"',`comma'+1,.)))
            }
            gettoken nativecmd bridgebody : left
            local bridgefeopts
            local bridgenocons 0
            local bridgeopts "intmethod(mvaghermite) intpoints(`nquad`i'') nolog difficult"
            if ustrregexm(`"`nativeopts'"',"(^|[ ,])nocons(tant)?($|[ ,])") {
                local bridgenocons 1
                local bridgefeopts `"`bridgefeopts' noconstant"'
            }
            if "`activecmd`i''"=="xtpoisson" {
                local exposure
                if ustrregexm(`"`cmdline`i''"',"[Ee][Xx][Pp](osure)?\([ ]*([A-Za-z_][A-Za-z0-9_]*)[ ]*\)") {
                    local exposure `"`=ustrregexs(2)'"'
                }
                if trim(`"`exposure'"')!="" local bridgefeopts `"`bridgefeopts' exposure(`exposure')"'
                else if trim(`"`offsetsrc`i''"')!="" local bridgefeopts `"`bridgefeopts' offset(`offsetsrc`i'')"'
            }
            else if "`activecmd`i''"=="xtcloglog" & trim(`"`offsetsrc`i''"')!="" {
                local bridgefeopts `"`bridgefeopts' offset(`offsetsrc`i'')"'
            }
            local bridgefixed `"`bridgebody'"'
            if trim(`"`bridgefeopts'"')!="" local bridgefixed `"`bridgefixed', `bridgefeopts'"'
            local bridgecall `"`bridgecmd`i'' `bridgefixed' || `highvar':, `bridgeopts'"'
            capture quietly `bridgecall'
            if _rc {
                local rc=_rc
                local errtext "unable to fit the Gaussian random-effects score bridge for model `name'"
                continue, break
            }
            tempvar bridge_sample
            quietly generate byte `bridge_sample'=e(sample)
            quietly count if `sample'!=`bridge_sample'
            if r(N) {
                local rc 459
                local errtext "the Gaussian random-effects bridge does not reproduce the stored sample for model `name'"
                continue, break
            }
            tempname bbridge bmap Cbridge nativeomit
            matrix `bbridge'=e(b)
            local Kbridge=colsof(`bbridge')
            local bridgefull : colfullnames `bbridge'
            local bridgecn : colnames `bbridge'
            quietly _ms_omit_info `bsrc'
            matrix `nativeomit'=r(omit)
            if rowsof(`nativeomit')!=1 | colsof(`nativeomit')!=`K`i'' {
                local rc 498
                local errtext "unable to identify omitted native parameters for model `name'"
                continue, break
            }
            local extra_cons 0
            if `Kbridge'==`K`i''+1 & `bridgenocons' {
                forvalues q=1/`=`Kbridge'-1' {
                    local qfull : word `q' of `bridgefull'
                    local qmatched 0
                    forvalues j=1/`=`K`i''-1' {
                        local jfull : word `j' of `nativefull`i''
                        if `"`qfull'"'==`"`jfull'"' local qmatched 1
                    }
                    if !`qmatched' {
                        if `extra_cons' {
                            local rc 498
                            local errtext "the Gaussian random-effects bridge has multiple unmatched fixed parameters for model `name'"
                            continue, break
                        }
                        local qcn : word `q' of `bridgecn'
                        if "`qcn'"!="_cons" | abs(`bbridge'[1,`q'])>1e-12 {
                            local rc 498
                            local errtext "the Gaussian random-effects bridge has an unexpected extra parameter for model `name'"
                            continue, break
                        }
                        local extra_cons=`q'
                    }
                }
                if `rc' continue, break
                if !`extra_cons' {
                    local rc 498
                    local errtext "the Gaussian random-effects bridge does not retain the expected constrained intercept for model `name'"
                    continue, break
                }
                capture confirm matrix e(Cns)
                if _rc {
                    local rc 498
                    local errtext "the Gaussian random-effects bridge does not constrain its retained intercept for model `name'"
                    continue, break
                }
                matrix `Cbridge'=e(Cns)
                local Ccols=colsof(`Cbridge')
                local Crhs=`Kbridge'+1
                if `Ccols'!=`Crhs' {
                    local rc 498
                    local errtext "the Gaussian random-effects bridge has an unexpected constraint matrix for model `name'"
                    continue, break
                }
                local constrained_cons 0
                forvalues r=1/`=rowsof(`Cbridge')' {
                    local this_constraint 1
                    forvalues q=1/`Kbridge' {
                        if `q'==`extra_cons' {
                            if abs(`Cbridge'[`r',`q'])<1e-12 local this_constraint 0
                        }
                        else if abs(`Cbridge'[`r',`q'])>1e-12 local this_constraint 0
                    }
                    if abs(`Cbridge'[`r',`Crhs'])>1e-12 local this_constraint 0
                    if `this_constraint' local constrained_cons 1
                }
                if !`constrained_cons' {
                    local rc 498
                    local errtext "the Gaussian random-effects bridge does not fix its retained intercept at zero for model `name'"
                    continue, break
                }
            }
            else if `Kbridge'!=`K`i'' {
                local rc 498
                local errtext "the Gaussian random-effects bridge has an unexpected parameter count for model `name'"
                continue, break
            }
            matrix `bmap'=`bbridge'
            forvalues j=1/`=`K`i''-1' {
                local jfull : word `j' of `nativefull`i''
                local bridgepos`j' 0
                if inlist("`activecmd`i''","xtologit","xtoprobit") & `j'>=`cutstart`i'' {
                    local jeq : word `j' of `nativeeq`i''
                    local jcn : word `j' of `nativecn`i''
                    if "`jcn'"!="_cons" {
                        local rc 498
                        local errtext "the `activecmd`i'' cutpoint `jfull' has an unexpected native stripe"
                        continue, break
                    }
                    forvalues q=1/`=`Kbridge'-1' {
                        local qcn : word `q' of `bridgecn'
                        if `"`qcn'"'==`"`jeq'"' local bridgepos`j'=`q'
                    }
                }
                else {
                    forvalues q=1/`=`Kbridge'-1' {
                        local qfull : word `q' of `bridgefull'
                        if `"`qfull'"'==`"`jfull'"' local bridgepos`j'=`q'
                    }
                }
                if !`bridgepos`j'' {
                    local rc 498
                    local errtext "the Gaussian random-effects bridge cannot match parameter `jfull' for model `name'"
                    continue, break
                }
                matrix `bmap'[1,`bridgepos`j'']=`bsrc'[1,`j']
            }
            if `rc' continue, break
            local bridge_varpos=`Kbridge'
            local variance_transform 1
            if inlist("`activecmd`i''","xtologit","xtoprobit") {
                local lasteq : word `K`i'' of `nativeeq`i''
                local lastcn : word `K`i'' of `nativecn`i''
                if "`lasteq'"!="sigma2_u" | "`lastcn'"!="_cons" {
                    local rc 498
                    local errtext "model `name' does not retain sigma2_u:_cons as its final parameter"
                    continue, break
                }
                local naturalvar=`bsrc'[1,`K`i'']
            }
            else {
                local lastcn : word `K`i'' of `nativecn`i''
                if "`lastcn'"!="lnsig2u" {
                    local rc 498
                    local errtext "model `name' does not retain /lnsig2u as its final parameter"
                    continue, break
                }
                local naturalvar=exp(`bsrc'[1,`K`i''])
                local variance_transform=`naturalvar'
            }
            matrix `bmap'[1,`bridge_varpos']=`naturalvar'
            mata: st_numscalar("__s2het_bridge_bdiff",max(abs(st_matrix("`bmap'"):-st_matrix("`bbridge'"))))
            mata: st_numscalar("__s2het_bridge_bscale",1+max(abs(st_matrix("`bbridge'"))))
            if abs(e(ll)-`llsrc`i'')>1e-8 | ///
                scalar(__s2het_bridge_bdiff)>1e-5*scalar(__s2het_bridge_bscale) {
                local rc 322
                * Report the MEASURED margin, not the floor. The two
                * scalars are set immediately above, so they are
                * always present on this path.
                local __s2bdstr = string(scalar(__s2het_bridge_bdiff), "%9.3e")
                local __s2btstr = string(1e-5*scalar(__s2het_bridge_bscale), "%9.3e")
                local __s2trynq = 2*`nquad`i''
                local errtext "model `name' was fit with `nquad`i'' quadrature points and does not match its Gaussian mixed-model bridge closely enough: the largest coefficient difference is `__s2bdstr', above the `__s2btstr' tolerance. It needs MORE points than it has -- `minquad`i'' is the bridge floor, not a value that will clear this. Refit with more, for example: `activecmd`i'' ..., intpoints(`__s2trynq') -- then store it again"
                continue, break
            }
            capture quietly suest2_mehetero_repost `bmap'
            if _rc {
                local rc=_rc
                local errtext "unable to map model `name' to the Gaussian random-effects score bridge"
                continue, break
            }
            local bridge_scores
            forvalues q=1/`Kbridge' {
                tempvar bsc
                local bridge_scores `bridge_scores' `bsc'
            }
            capture quietly predict double `bridge_scores' if `sample', scores
            if _rc {
                local rc=_rc
                local errtext "unable to generate Gaussian random-effects bridge scores for model `name'"
                continue, break
            }
            if `extra_cons' {
                local cons_score : word `extra_cons' of `bridge_scores'
                quietly summarize `cons_score' if `sample', meanonly
                if max(abs(r(min)),abs(r(max)))>1e-10 {
                    local rc 498
                    local errtext "the constrained-intercept bridge score is nonzero for model `name'"
                    continue, break
                }
            }
            forvalues j=1/`=`K`i''-1' {
                local native_score : word `j' of `scorelist'
                local bridge_score : word `bridgepos`j'' of `bridge_scores'
                if `nativeomit'[1,`j'] quietly generate double `native_score'=0 if `sample'
                else quietly generate double `native_score'=`bridge_score' if `sample'
            }
            if `nativeomit'[1,`K`i''] {
                local rc 498
                local errtext "model `name' unexpectedly omits its random-intercept variance"
                continue, break
            }
            local lastscore : word `K`i'' of `scorelist'
            local variance_score : word `bridge_varpos' of `bridge_scores'
            quietly generate double `lastscore'=`variance_score'*`variance_transform' if `sample'
            local maxscoresum 0
            foreach sc of local scorelist {
                quietly summarize `sc' if `sample', meanonly
                local asum=abs(r(sum))
                if `asum'>`maxscoresum' local maxscoresum=`asum'
            }
            if `maxscoresum'>1e-5*(1+`N`i'') {
                local rc 322
                local errtext "Gaussian random-effects bridge scores are not centered for model `name'; increase quadrature points"
                continue, break
            }
            local bridgecall`i' `"`bridgecall'"'
            local bridgevar`i'=`naturalvar'
        }
        else if "`plain`i''"=="1" {
            // 0.1.90: ordinary ordinal constituent. Native scores come
            // one per EQUATION (measured: asking for column counts is
            // refused r(103)); expand them to one per COLUMN so the
            // joint meat can be built uniformly: slope columns are the
            // equation score times the covariate value, omitted columns
            // are zero, cutpoint columns map one to one.
            capture quietly estimates restore `name'
            if _rc {
                local rc=_rc
                local errtext "unable to restore model `name' after reproduction checks"
                continue, break
            }
            capture drop __s2hpsc*
            capture quietly predict double __s2hpsc* if `sample', scores
            if _rc {
                local rc=_rc
                local errtext "unable to generate native equation scores for ordinary model `name'"
                continue, break
            }
            quietly ds __s2hpsc*
            local pleqsc `r(varlist)'
            local nesc : word count `pleqsc'
            if `nesc'!=`kcat`i'' {
                capture drop __s2hpsc*
                local rc 498
                local errtext "ordinary model `name' returned `nesc' equation scores where `kcat`i'' were expected"
                continue, break
            }
            tempname plomit
            quietly _ms_omit_info `bsrc'
            matrix `plomit'=r(omit)
            local plrc 0
            forvalues j=1/`K`i'' {
                local scj : word `j' of `scorelist'
                if `j'>=`cutstart`i'' {
                    local c=`j'-`cutstart`i''+2
                    local esc : word `c' of `pleqsc'
                    quietly generate double `scj'=`esc' if `sample'
                }
                else if `plomit'[1,`j'] {
                    quietly generate double `scj'=0 if `sample'
                }
                else {
                    local cnj : word `j' of `nativecn`i''
                    local esc1 : word 1 of `pleqsc'
                    if "`cnj'"=="_cons" quietly generate double `scj'=`esc1' if `sample'
                    else {
                        capture fvrevar `cnj' if `sample'
                        if _rc {
                            local plrc=_rc
                            continue, break
                        }
                        quietly generate double `scj'=`esc1'*`r(varlist)' if `sample'
                    }
                }
            }
            capture drop __s2hpsc*
            if `plrc' {
                local rc=`plrc'
                local errtext "unable to evaluate the design column for a score of ordinary model `name'"
                continue, break
            }
        }
        else {
            capture quietly estimates restore `name'
            if _rc {
                local rc=_rc
                local errtext "unable to restore model `name' after reproduction checks"
                continue, break
            }
            capture quietly predict double `scorelist' if `sample', scores
            if _rc {
                local rc=_rc
                local errtext "unable to generate native parameter scores for model `name'"
                continue, break
            }
        }
        local nscore : word count `scorelist'
        if `nscore'!=`K`i'' {
            local rc 498
            local errtext "model `name' did not generate one score variable per parameter"
            continue, break
        }
        // Weighting is applied to the OBSERVATION scores here, before the
        // group totals are formed further down.  On the cluster path that is
        // a multiplication by the level-2 weight, constant within group; on
        // the svy path a division by the level-1 weight, which is what lets
        // _robust2 ..., svy apply the whole design weight itself.  Both
        // measured exact (diag_wme_N3, diag_wme_N3b).
        if "`wshape`i''"!="plain" {
            local swlist
            foreach sc of local scorelist {
                tempvar scw
                if "`wshape`i''"=="svy" {
                    quietly generate double `scw'=`sc'/(`lwexp`i'') if `sample'
                }
                else {
                    quietly generate double `scw'=`sc'*`dgpw1_`i'' if `sample'
                }
                local swlist `swlist' `scw'
            }
            local scorelist `swlist'
        }
        local scores`i' `scorelist'

        tempvar taghigh
        quietly egen byte `taghigh'=tag(`highvar') if `sample'
        quietly count if `taghigh'
        local Ghigh`i'=r(N)
        if `Ghigh`i''<2 {
            local rc 459
            local errtext "model `name' contains fewer than two highest-level groups"
            continue, break
        }

        local obslayout 1
        local grouplayout 1
        foreach sc of local scorelist {
            quietly count if !missing(`sc')
            if r(N)!=`N`i'' local obslayout 0
            if r(N)!=`Ghigh`i'' local grouplayout 0
        }
        if `obslayout' local scorelayout`i' observation
        else if `grouplayout' local scorelayout`i' group
        else {
            local rc 498
            local errtext "native score placement for model `name' is neither observation-level nor highest-group-level"
            continue, break
        }
    }

    if `rc' {
        di as err "`errtext'"
        exit `rc'
    }

    local classes : list uniq classes
    local nclasses : word count `classes'
    local hasgeneric 0
    forvalues i=1/`nmodels' {
        if `generic`i'' local hasgeneric 1
    }
*   0.1.90: a same-class system that mixes a plain ordinal constituent
*   with a mixed one has NO family-specific route -- it belongs here.
    local hasplainmix 0
    local allplainmix 1
    forvalues i=1/`nmodels' {
        if "`plain`i''"=="1" local hasplainmix 1
        else local allplainmix 0
    }
    if `hasplainmix' & `allplainmix' {
        local rc 322
        local errtext "a system of only ordinary models belongs to the ordinary suest2 route, not the heterogeneous one"
    }
    else if !`hasgeneric' & !`hasmestreg' & !`hasxtgre' & `nclasses'==1 & ///
        !(`hasplainmix' & !`allplainmix') {
        local rc 322
        local errtext "homogeneous shortcut systems should use the validated family-specific route"
    }
    if `rc' {
        di as err "`errtext'"
        exit `rc'
    }

    local scorevar `"`requested_cluster'"'
    if "`sysshape'"!="plain" & trim(`"`scorevar'"')!="" {
        di as err "cluster() and vce(cluster) are not allowed for weighted or {bf:svy:} systems"
        di as err "the clustering is determined by the stored design"
        exit 198
    }
    if trim(`"`scorevar'"')=="" local scorevar `"`highvar'"'
    capture confirm numeric variable `scorevar'
    if _rc {
        di as err "cluster variable {bf:`scorevar'} must exist and be numeric"
        exit _rc
    }

    tempvar union
    quietly generate byte `union'=0
    forvalues i=1/`nmodels' {
        quietly replace `union'=1 if `sample`i''
        quietly count if `sample`i'' & missing(`scorevar')
        if r(N) {
            local name : word `i' of `names'
            di as err "cluster variable {bf:`scorevar'} is missing for model {bf:`name'}"
            exit 459
        }
    }

    if `"`scorevar'"'!=`"`highvar'"' {
        tempvar cmin cmax
        bysort `highvar': egen double `cmin'=min(cond(`union',`scorevar',.))
        bysort `highvar': egen double `cmax'=max(cond(`union',`scorevar',.))
        quietly count if `union' & `cmin'!=`cmax'
        if r(N) {
            di as err "highest-level groups in {bf:`highvar'} are not nested within clusters in {bf:`scorevar'}"
            exit 459
        }
    }

    tempvar tagcluster taghighunion
    quietly egen byte `tagcluster'=tag(`scorevar') if `union'
    quietly count if `tagcluster'
    local Gsys=r(N)
    if `Gsys'<2 {
        di as err "the heterogeneous system contains fewer than two clusters"
        exit 459
    }
    quietly egen byte `taghighunion'=tag(`highvar') if `union'
    quietly count if `taghighunion'
    local Ngsys=r(N)
    quietly count if `union'
    local Nsys=r(N)

    local Ktotal 0
    forvalues i=1/`nmodels' {
        local start`i'=`Ktotal'+1
        local Ktotal=`Ktotal'+`K`i''
        local end`i'=`Ktotal'

        tempvar tagi
        quietly egen byte `tagi'=tag(`scorevar') if `sample`i''
        quietly count if `tagi'
        local G`i'=r(N)
        if `G`i''<2 {
            local name : word `i' of `names'
            di as err "model {bf:`name'} contains fewer than two clusters"
            exit 459
        }
        local scale`i'=(`G`i''/(`G`i''-1))/(`Gsys'/(`Gsys'-1))

        local aligned
        foreach sc of local scores`i' {
            tempvar groupscore alignedscore
            if "`scorelayout`i''"=="observation" {
                bysort `highvar': egen double `groupscore'=total(cond(`sample`i'',`sc',0))
            }
            else {
                bysort `highvar': egen double `groupscore'=max(`sc')
            }
            quietly replace `groupscore'=0 if missing(`groupscore') & `union'
            quietly generate double `alignedscore'=`groupscore'*sqrt(`scale`i'') if `taghighunion'
            local aligned `aligned' `alignedscore'
        }
        local jointscores `jointscores' `aligned'
    }

    tempname bout bfinal Vsys Vbread
    local eqused
    forvalues i=1/`nmodels' {
        local name : word `i' of `names'
        local sysuniq
        local q 0
        foreach neq of local nativeequniq`i' {
            local ++q
            local candidate=substr(strtoname("`name'_`neq'"),1,32)
            if trim("`candidate'")=="" local candidate=substr("s2h`i'_e`q'",1,32)
            local duplicate : list posof "`candidate'" in eqused
            if `duplicate' local candidate=substr("s2h`i'_e`q'",1,32)
            local duplicate : list posof "`candidate'" in eqused
            if `duplicate' {
                di as err "suest2 could not construct unique heterogeneous equation names"
                exit 498
            }
            local sysuniq `sysuniq' `candidate'
            local eqused `eqused' `candidate'
        }
        local syseqnames`i' `"`sysuniq'"'
        local eqlist
        foreach neq of local nativeeq`i' {
            local pos : list posof "`neq'" in nativeequniq`i'
            local seq : word `pos' of `sysuniq'
            local eqlist `eqlist' `seq'
        }
        local allcn `allcn' `nativecn`i''
        local alleq `alleq' `eqlist'

        tempname bi Vi
        matrix `bi'=`bsrc`i''
        matrix `Vi'=`Vbsrc`i''
        matrix coleq `bi'=`eqlist'
        matrix coleq `Vi'=`eqlist'
        matrix roweq `Vi'=`eqlist'
        if `i'==1 {
            matrix `bout'=`bi'
            matrix `Vsys'=`Vi'
        }
        else {
            local oldK=colsof(`Vsys')
            matrix `Vsys'=(`Vsys',J(`oldK',`K`i'',0)\J(`K`i'',`oldK',0),`Vi')
            matrix `bout'=`bout',`bi'
        }
    }
    matrix colnames `bout'=`allcn'
    matrix coleq `bout'=`alleq'
    matrix colnames `Vsys'=`allcn'
    matrix rownames `Vsys'=`allcn'
    matrix coleq `Vsys'=`alleq'
    matrix roweq `Vsys'=`alleq'
    matrix `bfinal'=`bout'
    matrix `Vbread'=`Vsys'

    tempvar helper
    quietly generate byte `helper'=`taghighunion'
    local jointsvy
    if "`sysshape'"=="svy" local jointsvy "svy"
    capture quietly suest2_mehetero_joint_robust, b(`bout') v(`Vsys') ///
        sample(`helper') scores(`jointscores') cluster(`scorevar') `jointsvy'
    if _rc {
        di as err "unable to construct the joint heterogeneous covariance matrix"
        exit _rc
    }
    tempname Vout Vmb
    matrix `Vout'=e(V)
    matrix `Vmb'=e(V_modelbased)
    mata: st_numscalar("__s2het_breaddiff",max(abs(st_matrix("`Vbread'"):-st_matrix("`Vmb'"))))
    if scalar(__s2het_breaddiff)>1e-12 {
        di as err "the heterogeneous model-based covariance was not preserved"
        exit 498
    }

    forvalues i=1/`nmodels' {
        tempname Vblock Vtarget
        matrix `Vblock'=`Vout'[`start`i''..`end`i'',`start`i''..`end`i'']
        local name : word `i' of `names'
        if "`sysshape'"!="plain" {
            // On a weighted or svy store the stored e(V) already IS the
            // design-based covariance, so it is the target directly.
            matrix `Vtarget'=`Vsrc`i''
        }
        else {
            if `xtgre`i'' {
                capture quietly suest2_mehetero_bridge_robust, b(`bsrc`i'') v(`Vsrc`i'') ///
                    sample(`sample`i'') scores(`scores`i'') cluster(`scorevar')
            }
            else if "`plain`i''"=="1" {
                quietly estimates restore `name'
                capture quietly suest2_mehetero_plain_robust, ///
                    scores(`scores`i'') sample(`sample`i'') cluster(`scorevar')
            }
            else {
                quietly estimates restore `name'
                capture quietly suest2_mehetero_native_robust, cluster(`scorevar')
            }
            if _rc {
                di as err "unable to reproduce the model-specific robust covariance for model {bf:`name'}"
                exit _rc
            }
            matrix `Vtarget'=e(V)
        }
        mata: st_numscalar("__s2het_diagdiff",max(abs(st_matrix("`Vblock'"):-st_matrix("`Vtarget'"))))
        mata: st_numscalar("__s2het_diagscale",1+max(abs(st_matrix("`Vtarget'"))))
        if scalar(__s2het_diagdiff)>1e-7*scalar(__s2het_diagscale) {
            di as err "the heterogeneous covariance does not reproduce the model-specific block for model {bf:`name'}"
            exit 498
        }
    }

    mata: st_numscalar("__s2_heterorank",rank(st_matrix("`Vout'")))
    ereturn post `bfinal' `Vout', obs(`Nsys') esample(`union')
    ereturn scalar rank=scalar(__s2_heterorank)
    ereturn scalar N_clust=`Gsys'
    ereturn scalar N_g=`Ngsys'
    ereturn local clustvar `"`scorevar'"'
    ereturn local vce "cluster"
    if "`sysshape'"!="plain" {
        ereturn local wtype `"`dgwtype_1'"'
        ereturn local wexp `"`dgwexp_1'"'
    }
    if "`sysshape'"=="svy" {
        ereturn local prefix "svy"
        ereturn local vce "linearized"
        ereturn local vcetype "Linearized"
        ereturn scalar N_psu=`Gsys'
        if `dgnstrata_1'<. {
            ereturn scalar N_strata=`dgnstrata_1'
            ereturn scalar df_r=`Gsys'-`dgnstrata_1'
        }
        ereturn scalar suest2_svy=1
    }
    ereturn local vcetype "Robust"
    ereturn local method "ML"
    ereturn local names `"`names'"'
    ereturn local properties "b V"
    ereturn scalar suest2_mehetero=1
    ereturn scalar suest2_mehetero_has_mestreg=`hasmestreg'
    ereturn scalar suest2_mehetero_all_mestreg=`allmestreg'
    ereturn scalar suest2_mehetero_has_xtgre=`hasxtgre'
    ereturn scalar suest2_mehetero_all_xtgre=`allxtgre'
    ereturn local suest2_mehetero_highvar `"`highvar'"'
    ereturn local suest2_mehetero_scorevar `"`scorevar'"'
    ereturn local suest2_mehetero_classes `"`classes'"'
    ereturn local suest2_mehetero_engine "native_highest_group_scores_allcons"
    ereturn local suest2_mehetero_revision "stable"
    ereturn local suest2_mehetero_displayopts `"`displayopts'"'
    if `allmestreg' ereturn local title "Simultaneous mixed-effects parametric survival results"
    else if `allxtgre' ereturn local title "Simultaneous nonlinear random-effects results"
    else ereturn local title "Simultaneous heterogeneous mixed-model results"
    ereturn local cmd "suest2_mehetero"

    forvalues i=1/`nmodels' {
        ereturn local eqnames`i' `"`syseqnames`i''"'
        ereturn scalar suest2_mehetero_N`i'=`N`i''
        ereturn scalar suest2_mehetero_Ghigh`i'=`Ghigh`i''
        ereturn scalar suest2_mehetero_G`i'=`G`i''
        ereturn scalar suest2_mehetero_K`i'=`K`i''
        ereturn scalar suest2_mehetero_rank`i'=`rank`i''
        ereturn scalar suest2_mehetero_kf`i'=`kf`i''
        ereturn scalar suest2_mehetero_kr`i'=`kr`i''
        ereturn scalar suest2_mehetero_generic`i'=`generic`i''
        ereturn scalar suest2_mehetero_mestreg`i'=`mestreg`i''
        ereturn scalar suest2_mehetero_xtgre`i'=`xtgre`i''
        ereturn scalar suest2_mehetero_scale`i'=`scale`i''
        ereturn local suest2_mehetero_class`i' `"`class`i''"'
        ereturn local suest2_mehetero_activecmd`i' `"`activecmd`i''"'
        ereturn local suest2_mehetero_scorelayout`i' `"`scorelayout`i''"'
        ereturn local suest2_mehetero_ivars`i' `"`ivars`i''"'
        ereturn local suest2_mehetero_redim`i' `"`redim`i''"'
        ereturn local suest2_mehetero_vartypes`i' `"`vartypes`i''"'
        ereturn local suest2_mehetero_revars`i' `"`revars`i''"'
        if `xtgre`i'' {
            ereturn local suest2_mehetero_bridgecmd`i' `"`bridgecmd`i''"'
            ereturn local suest2_mehetero_bridgecall`i' `"`bridgecall`i''"'
            ereturn scalar suest2_mehetero_bridgevar`i'=`bridgevar`i''
        }
        if "`activecmd`i''"=="mestreg" {
            ereturn local suest2_mehetero_distribution`i' `"`distribution`i''"'
            ereturn local suest2_mehetero_frm2`i' `"`frm2`i''"'
        }
        if "`activecmd`i''"!="mixed" {
            ereturn scalar suest2_mehetero_nquad`i'=`nquad`i''
            ereturn local suest2_mehetero_intmethod`i' `"`intmethod`i''"'
        }
        if "`activecmd`i''"=="meologit" {
            ereturn scalar suest2_meologit_cutstart`i'=`cutstart`i''
            ereturn scalar suest2_meologit_kcat`i'=`kcat`i''
            ereturn matrix suest2_meologit_cat`i'=`catsrc`i''
        }
        if "`activecmd`i''"=="meoprobit" {
            ereturn scalar suest2_meoprobit_cutstart`i'=`cutstart`i''
            ereturn scalar suest2_meoprobit_kcat`i'=`kcat`i''
            ereturn matrix suest2_meoprobit_cat`i'=`catsrc`i''
        }
    }
end

// ============================================================================
// Stored melogit adaptive-quadrature route
// ============================================================================

program define suest2_me_native_robust, eclass
*   Replaced eight byte-identical copies at candidate 19.
    version 9
    syntax, CLuster(varname)
    local vv : display "version " string(_caller()) ":"
    tempname b
    matrix `b' = e(b)
    local K = colsof(`b')
    forvalues j = 1/`K' {
        tempname sc`j'
        local scores `scores' `sc`j''
    }
    `vv' quietly predict double `scores' if e(sample), scores
    _robust2 `scores' if e(sample), cluster(`cluster') allcons
end

program define suest2_me_joint_robust, eclass
*   Replaced seven byte-identical copies at candidate 19. stem() carries the
*   family so e(cmd) is posted exactly as before: suest2_<family>_joint.
    version 9
    syntax, STEM(string) B(name) V(name) SAMPLE(varname) SCORES(varlist) ///
        [CLUSTER(varname) SVY]
    ereturn post `b' `v', esample(`sample')
    ereturn local cmd "`stem'_joint"
    ereturn local properties "b V"
    // Under svy: the design -- weights, sampling units, strata -- is read by
    // _robust2 from the svyset currently in effect, which is why the caller
    // requires the stored design and the live one to agree.
    if "`svy'" != "" _robust2 `scores' if e(sample), svy allcons
    else _robust2 `scores' if e(sample), cluster(`cluster') allcons
end



program define suest2_meestimate, sortpreserve eclass
*   The single mixed-effects estimator. Seven families rode identical copies
*   of this program until 0.1.75 candidate 19; 117 lines of 5,660 differed,
*   and four of those differences were unintended drift. The family table
*   below is the whole of what varies. Called only through the seven wrappers
*   at the end of this block, which is what the dispatch still names.
    gettoken __s2c_fam 0 : 0
    local __s2c_fam = trim(`"`__s2c_fam'"')
    if "`__s2c_fam'" == "melogit" {
        local __s2c_cmodel  ""
        local __s2c_cfamily "bernoulli"
        local __s2c_clink   "logit"
        local __s2c_single  "logit"
        local __s2c_lbl     "Bernoulli logit"
        local __s2c_title   "Simultaneous mixed-effects logistic results"
        local __s2c_isord   0
        local __s2c_hasdisp 0
        local __s2c_pfx     "mel"
        local __s2c_stem    "s2l"
        local __s2c_revname "_runtime_revision"
        local __s2c_revval  "candidate1_rev2"
    }
    else if "`__s2c_fam'" == "meprobit" {
        local __s2c_cmodel  ""
        local __s2c_cfamily "bernoulli"
        local __s2c_clink   "probit"
        local __s2c_single  "probit"
        local __s2c_lbl     "Bernoulli probit"
        local __s2c_title   "Simultaneous mixed-effects probit results"
        local __s2c_isord   0
        local __s2c_hasdisp 0
        local __s2c_pfx     "mep"
        local __s2c_stem    "s2p"
        local __s2c_revname "_runtime_revision"
        local __s2c_revval  "candidate1_rev1"
    }
    else if "`__s2c_fam'" == "mecloglog" {
        local __s2c_cmodel  "cloglog"
        local __s2c_cfamily "bernoulli"
        local __s2c_clink   "cloglog"
        local __s2c_single  "cloglog"
        local __s2c_lbl     "Bernoulli complementary-log-log"
        local __s2c_title   "Simultaneous mixed-effects complementary-log-log results"
        local __s2c_isord   0
        local __s2c_hasdisp 0
        local __s2c_pfx     "mec"
        local __s2c_stem    "s2c"
        local __s2c_revname "_revision"
        local __s2c_revval  "stable"
    }
    else if "`__s2c_fam'" == "mepoisson" {
        local __s2c_cmodel  ""
        local __s2c_cfamily "poisson"
        local __s2c_clink   "log"
        local __s2c_single  "poisson"
        local __s2c_lbl     "Poisson log"
        local __s2c_title   "Simultaneous mixed-effects Poisson results"
        local __s2c_isord   0
        local __s2c_hasdisp 0
        local __s2c_pfx     "mpo"
        local __s2c_stem    "s2o"
        local __s2c_revname "_revision"
        local __s2c_revval  "stable"
    }
    else if "`__s2c_fam'" == "menbreg" {
        local __s2c_cmodel  "nbinomial"
        local __s2c_cfamily "nbinomial"
        local __s2c_clink   "log"
        local __s2c_single  "nbreg"
        local __s2c_lbl     "negative-binomial log"
        local __s2c_title   "Simultaneous mixed-effects negative-binomial results"
        local __s2c_isord   0
        local __s2c_hasdisp 1
        local __s2c_pfx     "mnb"
        local __s2c_stem    "s2n"
        local __s2c_revname "_revision"
        local __s2c_revval  "stable"
    }
    else if "`__s2c_fam'" == "meologit" {
        local __s2c_cmodel  "ologit"
        local __s2c_cfamily "ordinal"
        local __s2c_clink   "logit"
        local __s2c_single  "ologit"
        local __s2c_lbl     "ordered-logit"
        local __s2c_title   "Simultaneous mixed-effects ordered-logit results"
        local __s2c_isord   1
        local __s2c_hasdisp 0
        local __s2c_pfx     "mol"
        local __s2c_stem    "s2t"
        local __s2c_revname "_revision"
        local __s2c_revval  "stable"
    }
    else if "`__s2c_fam'" == "meoprobit" {
        local __s2c_cmodel  "oprobit"
        local __s2c_cfamily "ordinal"
        local __s2c_clink   "probit"
        local __s2c_single  "oprobit"
        local __s2c_lbl     "ordered-probit"
        local __s2c_title   "Simultaneous mixed-effects ordered-probit results"
        local __s2c_isord   1
        local __s2c_hasdisp 0
        local __s2c_pfx     "mop"
        local __s2c_stem    "s2r"
        local __s2c_revname "_revision"
        local __s2c_revval  "stable"
    }
    else {
        di as err "{bf:suest2}: suest2_meestimate called for unknown family `__s2c_fam'"
        exit 198
    }
    version 16
    syntax [anything] [, CLuster(varname) VCE(string asis) Robust MINUS ///
        REGRESSML SVY Level(cilevel) DIR EForm(passthru) *]

    if "`minus'" != "" | "`regressml'" != "" | "`svy'" != "" {
        di as err "options minus, regressml, and svy are not supported for `__s2c_fam' systems"
        exit 198
    }

    local displayopts
    if "`level'" != "" local displayopts `"`displayopts' level(`level')"'
    if "`dir'" != "" local displayopts `"`displayopts' dir"'
    if `"`eform'"' != "" local displayopts `"`displayopts' `eform'"'
    if trim(`"`options'"') != "" local displayopts `"`displayopts' `options'"'

    if "`cluster'" != "" & trim(`"`vce'"') != "" {
        di as err "specify only one of cluster() or vce()"
        exit 198
    }
    if "`cluster'" != "" & "`robust'" != "" {
        di as err "specify only one of cluster() or robust"
        exit 198
    }
    if trim(`"`vce'"') != "" & "`robust'" != "" {
        di as err "specify only one of vce() or robust"
        exit 198
    }

    local requested_cluster `"`cluster'"'
    if trim(`"`vce'"') != "" {
        local vcelower = ustrlower(itrim(trim(`"`vce'"')))
        if "`vcelower'" == "robust" local requested_cluster
        else if ustrregexm(`"`vcelower'"', "^cluster[ ]+([A-Za-z_][A-Za-z0-9_]*)$") {
            local requested_cluster `"`=ustrregexs(1)'"'
        }
        else if ustrregexm(`"`vcelower'"', "^cluster[ ]*\([ ]*([A-Za-z_][A-Za-z0-9_]*)[ ]*\)$") {
            local requested_cluster `"`=ustrregexs(1)'"'
        }
        else {
            di as err "the `__s2c_fam' route supports only vce(robust) or vce(cluster varname)"
            exit 198
        }
    }

    est_expand `"`anything'"', min(2) default(.)
    local names `"`r(names)'"'
    local names : list uniq names
    local nmodels : word count `names'
    local hasdot : list posof "." in names
    if `hasdot' {
        di as err "`__s2c_fam' support requires named stored estimates"
        di as err "store each model with {bf:estimates store} before running {bf:suest2}"
        exit 198
    }

    // DESIGN PRE-PASS, and it must run BEFORE the per-model reproduction
    // checks: those re-estimate under the svyset CURRENTLY in effect, so a
    // system whose stores carry DIFFERENT designs would fail reproduction
    // first and be refused r(459) blaming the data. Classifying first
    // refuses 322 naming the field that differs (diag_wme_MELW1 block 5).
    // Stores that are not the family are SKIPPED so the family check in the
    // main loop keeps its own message.
    local dgrc 0
    local dgtext
    local dgskip 0
    local sysshape "plain"
    forvalues i = 1/`nmodels' {
        local name : word `i' of `names'
        capture quietly estimates restore `name'
        if _rc {
            local dgskip 1
            continue
        }
        if "`e(cmd)'" != "meglm" | "`e(cmd2)'" != "`__s2c_fam'" {
            local dgskip 1
            continue
        }
        // Design classification: three admissible store shapes, and the
        // fall-through is a REFUSAL, never the unweighted path.
        //   plain    unweighted OIM store    bread e(V), scores as predicted
        //   pweight  [pw=] + pweight()       bread e(V_modelbased), scores
        //                                    scaled by e(pweight1), cluster()
        //   svy      svy: + linearized VCE   bread e(V_modelbased), scores
        //                                    divided by the level-1 weight,
        //                                    _robust2 ..., svy
        // Measured in diag_wme_N1 and diag_wme_N2.
        local wshape`i' "none"
        if trim(`"`e(wtype)'"') == "" & trim(`"`e(prefix)'"') == "" & ///
            inlist(`"`e(vce)'"', "", "oim") {
            local wshape`i' "plain"
        }
        else if trim(`"`e(prefix)'"') == "svy" & ///
            `"`e(vce)'"' == "linearized" & `"`e(wtype)'"' == "pweight" {
            local wshape`i' "svy"
        }
        else if trim(`"`e(prefix)'"') == "" & ///
            `"`e(wtype)'"' == "pweight" & `"`e(vce)'"' == "robust" {
            local wshape`i' "pweight"
        }
        if "`wshape`i''" == "none" {
            if trim(`"`e(prefix)'"') == "svy" {
                local dgrc 322
                local dgtext "survey `__s2c_fam' model `name' uses `e(vce)' variance estimation; only linearized survey results are supported (BRR, jackknife, bootstrap and successive-difference replicate VCEs are not)"
            }
            else if trim(`"`e(prefix)'"') != "" {
                local dgrc 322
                local dgtext "`__s2c_fam' model `name' was estimated under the `e(prefix)' prefix, which is not supported"
            }
            else if !inlist(`"`e(wtype)'"', "", "pweight") {
                local dgrc 198
                local dgtext "`__s2c_fam' systems accept pweights and the svy: prefix; model `name' carries `e(wtype)'s"
            }
            else {
                local dgrc 322
                local dgtext "store conventional `__s2c_fam' estimates and request robust or clustered VCE with suest2, or fit the models with pweights or under svy:"
            }
            continue, break
        }

        if "`wshape`i''" != "plain" {
            // FPC.  Measured (diag_wme_N1 part 5): under a stage-1 FPC
            // neither _robust2 ..., svy nor an influence-function total
            // reproduces the family's own e(V), and the two miss by the SAME
            // 1.592154e-02 -- so this is not a matter of choosing a better
            // route.  Scan for ANY fpc macro rather than testing e(fpc1)
            // alone: a stage-2 FPC would walk straight through a guard
            // written for stage 1, and a guard on the wrong macro fails
            // open.
            local emacs
            capture local emacs : e(macros)
            if _rc | "`emacs'" == "" local emacs "`e(macros)'"
            local fpcfound
            foreach em of local emacs {
                if substr("`em'", 1, 3) == "fpc" local fpcfound "`em'"
            }
            if "`fpcfound'" != "" {
                local dgrc 322
                local dgtext "model `name' carries a finite population correction (e(`fpcfound')); FPC survey designs are not supported for `__s2c_fam' systems"
                continue, break
            }
            // subpop.  Measured (diag_wme_N1 part 6): the fit succeeds, but
            // no candidate reproduces its e(V) -- 2.29 and 0.907 through
            // _robust2 with and without subpop(), 0.666 through influence
            // functions -- and e(sample) covers the whole sample rather
            // than the subpopulation.
            if trim(`"`e(subpop)'"') != "" {
                local dgrc 322
                local dgtext "model `name' was estimated with subpop(`e(subpop)'); subpopulation estimation is not supported for `__s2c_fam' systems"
                continue, break
            }
            capture confirm matrix e(V_modelbased)
            if _rc {
                local dgrc 498
                local dgtext "weighted `__s2c_fam' model `name' does not retain e(V_modelbased), which the joint sandwich requires as its bread"
                continue, break
            }
            // The level-1 weight.  e(wexp) holds it under BOTH shapes and is
            // an EXPRESSION of the form "= expr", not necessarily a bare
            // variable name (measured, diag_wme_N1 parts 2 and 3).
            local lwexp`i'
            if "`wshape`i''" == "svy" {
                local rawwexp = trim(`"`e(wexp)'"')
                if substr(`"`rawwexp'"', 1, 1) != "=" {
                    local dgrc 498
                    local dgtext "survey `__s2c_fam' model `name' does not retain a level-1 sampling weight in e(wexp)"
                    continue, break
                }
                local lwexp`i' = trim(substr(`"`rawwexp'"', 2, .))
                if trim("`lwexp`i''") == "" {
                    local dgrc 498
                    local dgtext "survey `__s2c_fam' model `name' retains an empty level-1 sampling weight in e(wexp)"
                    continue, break
                }
            }
            else {
                if trim(`"`e(pweight1)'"') == "" {
                    local dgrc 198
                    local dgtext "`__s2c_fam' model `name' was fit with a weight but without a stage weight, so it carries no higher-level weight to build a design from; a weighted multilevel system needs one, as in [pw=w2] || group:, pweight(w1), or use the svy: prefix"
                    continue, break
                }
                if trim(`"`e(clustvar)'"') == "" {
                    local dgrc 498
                    local dgtext "pweighted `__s2c_fam' model `name' does not retain e(clustvar)"
                    continue, break
                }
            }
            // Carried for the cross-model design agreement check below.  The
            // trailing _`i' keeps dgsu_1 from colliding with dgsu1.
            local dgprefix_`i' `"`e(prefix)'"'
            local dgsu_`i' `"`e(su1)'"'
            local dgstrata_`i' `"`e(strata1)'"'
            local dgw1_`i' `"`e(weight1)'"'
            local dgw2_`i' `"`e(weight2)'"'
            local dgwexp_`i' `"`e(wexp)'"'
            local dgwtype_`i' `"`e(wtype)'"'
            local dgclust_`i' `"`e(clustvar)'"'
            local dgpw1_`i' `"`e(pweight1)'"'
            local dgsingle_`i' `"`e(singleunit)'"'
            local dgstages_`i' .
            capture local dgstages_`i' = e(stages)
            local dgnstrata_`i' .
            capture local dgnstrata_`i' = e(N_strata)
        }
    }
    if `dgrc' {
        di as err "`dgtext'"
        exit `dgrc'
    }
    if !`dgskip' {
        // ----------------------------------------------------------------------
        // System-level design agreement.  The joint sandwich is built once from
        // one design and cannot represent two, so a system mixing svy: with
        // [pw=], or carrying two different svysets, is refused naming the field
        // that differs rather than being given one model's design.
        // ----------------------------------------------------------------------
        local sysshape `"`wshape1'"'
        local name1 : word 1 of `names'
        forvalues i = 2/`nmodels' {
            local name : word `i' of `names'
            if "`wshape`i''" != "`sysshape'" {
                di as err "`__s2c_fam' constituents mix weighting schemes: model {bf:`name1'} is `sysshape' and model {bf:`name'} is `wshape`i''"
                exit 322
            }
        }
        if "`sysshape'" != "plain" {
            forvalues i = 2/`nmodels' {
                local name : word `i' of `names'
                local mism
                if `"`dgprefix_`i''"' != `"`dgprefix_1'"' local mism "e(prefix)"
                else if `"`dgsu_`i''"' != `"`dgsu_1'"' local mism "e(su1)"
                else if `"`dgstrata_`i''"' != `"`dgstrata_1'"' local mism "e(strata1)"
                else if `"`dgw1_`i''"' != `"`dgw1_1'"' local mism "e(weight1)"
                else if `"`dgw2_`i''"' != `"`dgw2_1'"' local mism "e(weight2)"
                else if `"`dgwexp_`i''"' != `"`dgwexp_1'"' local mism "e(wexp)"
                else if `"`dgwtype_`i''"' != `"`dgwtype_1'"' local mism "e(wtype)"
                else if `"`dgclust_`i''"' != `"`dgclust_1'"' local mism "e(clustvar)"
                else if `"`dgpw1_`i''"' != `"`dgpw1_1'"' local mism "e(pweight1)"
                else if `"`dgsingle_`i''"' != `"`dgsingle_1'"' local mism "e(singleunit)"
                else if `"`dgstages_`i''"' != `"`dgstages_1'"' local mism "e(stages)"
                else if `"`dgnstrata_`i''"' != `"`dgnstrata_1'"' local mism "e(N_strata)"
                if "`mism'" != "" {
                    di as err "`__s2c_fam' constituents describe different survey designs: `mism' differs between models {bf:`name1'} and {bf:`name'}"
                    exit 322
                }
            }
        }
    }

    local highvar
    local scorevar
    local rc 0
    local errtext
    local allcn
    local alleq
    local jointscores

    forvalues i = 1/`nmodels' {
        local name : word `i' of `names'
        capture quietly estimates restore `name'
        if _rc {
            local rc = _rc
            local errtext "unable to restore constituent model `name'"
            continue, break
        }

        if "`e(cmd)'" != "meglm" | "`e(cmd2)'" != "`__s2c_fam'" {
            local rc 322
            local errtext "the first `__s2c_fam' increment requires every constituent model to be `__s2c_fam'"
            continue, break
        }
        local __s2bad 0
        if "`__s2c_cmodel'"  != "" & "`e(model)'"  != "`__s2c_cmodel'"   local __s2bad 1
        if "`__s2c_cfamily'" != "" & "`e(family)'" != "`__s2c_cfamily'"  local __s2bad 1
        if "`__s2c_clink'"   != "" & "`e(link)'"   != "`__s2c_clink'"    local __s2bad 1
        if `__s2bad' {
            local rc 322
            local errtext "the first `__s2c_fam' increment supports `__s2c_lbl' models only"
            continue, break
        }
        if `__s2c_hasdisp' {
            local dispersion`i' `"`e(dispersion)'"'
            if !inlist(`"`dispersion`i''"', "mean", "constant") {
                local rc 322
                local errtext "`__s2c_fam' model `name' uses an unsupported dispersion parameterization"
                continue, break
            }
        }
        if "`e(intmethod)'" != "mvaghermite" {
            local rc 322
            local errtext "`__s2c_fam' support currently requires adaptive Gaussian-Hermite quadrature; refit model `name' without intmethod(laplace)"
            continue, break
        }
        local nquad`i' = real("`e(n_quad)'")
        if missing(`nquad`i'') | `nquad`i'' < 2 {
            local rc 322
            local errtext "`__s2c_fam' support requires at least two quadrature points so native scores are available"
            continue, break
        }

        foreach scalar in N k rank k_f k_r {
            capture confirm scalar e(`scalar')
            if _rc {
                local rc 498
                local errtext "model `name' does not retain e(`scalar')"
                continue, break
            }
        }
        if `rc' continue, break
        if e(k_r) < 1 {
            local rc 322
            local errtext "model `name' does not contain random effects; use `__s2c_single' for a single-level model"
            continue, break
        }

        local ivars`i' `"`e(ivars)'"'
        local high`i' : word 1 of `ivars`i''
        if trim(`"`high`i''"') == "" {
            local rc 498
            local errtext "model `name' does not retain a highest-level grouping variable in e(ivars)"
            continue, break
        }
        if `i' == 1 local highvar `"`high`i''"'
        else if `"`high`i''"' != `"`highvar'"' {
            local rc 459
            local errtext "all `__s2c_fam' constituent models must use the same highest-level grouping variable"
            continue, break
        }
        // On a weighted store the design's clustering must BE the model's own
        // grouping variable; otherwise the joint sandwich is not the variance
        // Stata computed for the constituent, and the per-model block check
        // below would be comparing two different estimators.
        if "`wshape`i''" == "pweight" & `"`dgclust_`i''"' != `"`high`i''"' {
            local rc 459
            local errtext "pweighted `__s2c_fam' model `name' is clustered on `dgclust_`i'' but grouped on `high`i''; the joint covariance requires them to agree"
            continue, break
        }
        if "`wshape`i''" == "svy" & `"`dgsu_`i''"' != `"`high`i''"' {
            local rc 459
            local errtext "survey `__s2c_fam' model `name' has sampling unit `dgsu_`i'' but is grouped on `high`i''; the joint covariance requires them to agree"
            continue, break
        }
        capture confirm numeric variable `high`i''
        if _rc {
            local rc = _rc
            local errtext "highest-level grouping variable `high`i'' must exist and be numeric"
            continue, break
        }

        capture confirm numeric variable `high`i''
        if _rc {
            local rc = _rc
            local errtext "highest-level grouping variable `high`i'' must exist and be numeric"
            continue, break
        }

        capture confirm matrix e(b)
        if _rc {
            local rc = _rc
            local errtext "model `name' does not contain e(b)"
            continue, break
        }
        capture confirm matrix e(V)
        if _rc {
            local rc = _rc
            local errtext "model `name' does not contain e(V)"
            continue, break
        }

        tempname pfx
        local pfx`i' `pfx'
        local bsrc `pfx'_b
        local Vsrc `pfx'_V
        local bref `pfx'_br
        local Vref `pfx'_Vr
        local Vbsrc `pfx'_Vb
        local bsrc`i' `bsrc'
        local Vsrc`i' `Vsrc'
        local Vbsrc`i' `Vbsrc'
        matrix `bsrc' = e(b)
        matrix `Vsrc' = e(V)
        // The bread.  For an unweighted OIM store e(V) IS the model-based
        // covariance; for a weighted or svy store e(V) is already the
        // design-based sandwich and e(V_modelbased) is the bread.  e(V) is
        // retained either way: the e(cmdline) reproduction check below
        // compares e(V) against e(V), and on a weighted system the stored
        // e(V) is the target of the per-model block check.
        if "`wshape`i''" == "plain" matrix `Vbsrc' = `Vsrc'
        else matrix `Vbsrc' = e(V_modelbased)
        local K`i' = colsof(`bsrc')
        local rank`i' = e(rank)
        local N`i' = e(N)
        local kf`i' = e(k_f)
        local kr`i' = e(k_r)
        if `__s2c_isord' {
            local kcat`i' = e(k_cat)
            local cutstart`i' 0
            tempname catsrc
            local catsrc`i' `catsrc'
            matrix `catsrc' = e(cat)
            local native_marginsdefault`i' `"`e(marginsdefault)'"'
        }
        local depvar`i' `"`e(depvar)'"'
        local redim`i' `"`e(redim)'"'
        local vartypes`i' `"`e(vartypes)'"'
        local revars`i' `"`e(revars)'"'
        local intmethod`i' `"`e(intmethod)'"'
        local cmdline`i' `"`e(cmdline)'"'
        local nativecn`i' : colnames `bsrc'
        local nativeeq`i' : coleq `bsrc'
        if `__s2c_isord' {
            local nativefull`i' : colfullnames `bsrc'
        }
        local nativeequniq`i' : list uniq nativeeq`i'
        if `__s2c_isord' {
    
            forvalues j = 1/`K`i'' {
                local fullj : word `j' of `nativefull`i''
                if `"`fullj'"' == "/cut1" local cutstart`i' = `j'
            }
            if !`cutstart`i'' {
                local rc 498
                local errtext "model `name' does not retain a /cut1 coefficient stripe"
                continue, break
            }
            local ncuts`i' = `kcat`i'' - 1
            forvalues c = 1/`ncuts`i'' {
                local j = `cutstart`i'' + `c' - 1
                local fullj : word `j' of `nativefull`i''
                if `"`fullj'"' != "/cut`c'" {
                    local rc 498
                    local errtext "model `name' does not retain a contiguous ordered cutpoint block"
                    continue, break
                }
            }
            if `rc' continue, break
        }

        tempvar sample sampleref
        local sample`i' `sample'
        quietly generate byte `sample' = e(sample)
        quietly count if `sample'
        if r(N) != `N`i'' {
            local rc 459
            local errtext "the current data no longer reproduce the stored estimation sample for model `name'"
            if "`wshape`i''" == "svy" {
                local errtext "`errtext'. A zero level-1 sampling weight produces exactly this refusal under svy:; the data themselves need not have changed"
            }
            continue, break
        }

        if trim(`"`cmdline`i''"') == "" {
            local rc 498
            local errtext "model `name' does not retain e(cmdline) for data-reproduction checks"
            continue, break
        }
        capture quietly `cmdline`i''
        if _rc {
            local rc = _rc
            local errtext "the current data cannot re-estimate stored `__s2c_fam' model `name'"
            continue, break
        }
        matrix `bref' = e(b)
        matrix `Vref' = e(V)
        quietly generate byte `sampleref' = e(sample)
        quietly count if `sample' != `sampleref'
        if r(N) {
            local rc 459
            local errtext "the current data do not reproduce the stored estimation sample for model `name'"
            continue, break
        }
        mata: st_numscalar("__s2`__s2c_pfx'_bdiff",max(abs(st_matrix("`bsrc'"):-st_matrix("`bref'"))))
        mata: st_numscalar("__s2`__s2c_pfx'_Vdiff",max(abs(st_matrix("`Vsrc'"):-st_matrix("`Vref'"))))
        mata: st_numscalar("__s2`__s2c_pfx'_bscale",1+max(abs(st_matrix("`bsrc'"))))
        mata: st_numscalar("__s2`__s2c_pfx'_Vscale",1+max(abs(st_matrix("`Vsrc'"))))
        local __s2bad 0
        if scalar(__s2`__s2c_pfx'_bdiff)>1e-7*scalar(__s2`__s2c_pfx'_bscale)  local __s2bad 1
        if scalar(__s2`__s2c_pfx'_Vdiff)>1e-7*scalar(__s2`__s2c_pfx'_Vscale)  local __s2bad 1
        if "`e(cmd2)'" != "`__s2c_fam'"                                 local __s2bad 1
        if "`__s2c_cmodel'"  != "" & "`e(model)'"  != "`__s2c_cmodel'"        local __s2bad 1
        if "`__s2c_cfamily'" != "" & "`e(family)'" != "`__s2c_cfamily'"       local __s2bad 1
        if "`__s2c_clink'"   != "" & "`e(link)'"   != "`__s2c_clink'"         local __s2bad 1
        if `__s2c_hasdisp' & `"`e(dispersion)'"' != `"`dispersion`i''"'  local __s2bad 1
        if "`e(intmethod)'" != "`intmethod`i''"                   local __s2bad 1
        if real("`e(n_quad)'") != `nquad`i''                      local __s2bad 1
        if `"`e(ivars)'"'    != `"`ivars`i''"'                    local __s2bad 1
        if `"`e(redim)'"'    != `"`redim`i''"'                    local __s2bad 1
        if `"`e(vartypes)'"' != `"`vartypes`i''"'                 local __s2bad 1
        if `"`e(revars)'"'   != `"`revars`i''"'                   local __s2bad 1
        if `__s2bad' {
            local rc 459
            local errtext "the current data do not reproduce the stored `__s2c_fam' coefficients, bread, integration, or random-effects specification for model `name'"
            if "`wshape`i''" == "svy" {
                local errtext "`errtext'. Under svy: the active svyset is part of what has to reproduce, so a design respecified since the model was fitted lands here even though the data are unchanged"
            }
            continue, break
        }
        if `__s2c_isord' {
            if e(k_cat) != `kcat`i'' {
                local rc 459
                local errtext "the current data do not reproduce the stored `__s2c_fam' outcome categories for model `name'"
                continue, break
            }
            tempname catref
            matrix `catref' = e(cat)
            mata: st_numscalar("__s2`__s2c_pfx'_catdiff",max(abs(st_matrix("`catsrc`i''"):-st_matrix("`catref'"))))
            if scalar(__s2`__s2c_pfx'_catdiff)>1e-12 {
                local rc 459
                local errtext "the current data do not reproduce the stored `__s2c_fam' outcome categories for model `name'"
                continue, break
            }
        }

        capture quietly estimates restore `name'
        if _rc {
            local rc = _rc
            local errtext "unable to restore constituent model `name' after reproduction checks"
            continue, break
        }

        local scorelist
        forvalues j = 1/`K`i'' {
            tempvar sc
            local scorelist `scorelist' `sc'
        }
        capture quietly predict double `scorelist' if `sample', scores
        if _rc {
            local rc = _rc
            local errtext "unable to generate native adaptive-quadrature scores for model `name'"
            if "`wshape`i''" == "svy" {
                local errtext "`errtext'. A zero level-1 sampling weight produces exactly this failure under svy:; Stata reports r(459) and the message data have changed since estimation, which does not describe the cause"
            }
            continue, break
        }
        local nscore : word count `scorelist'
        if `nscore' != `K`i'' {
            local rc 498
            local errtext "model `name' did not generate one score variable per parameter"
            continue, break
        }
        // Weighted scores.  predict, scores already carries the LEVEL-1
        // weight after a weighted fit, which is why the svy path divides it
        // back out and lets _robust2 apply the whole design weight itself,
        // while the cluster path multiplies by the higher-level weight.
        // Both exact: diag_svymi_L8, re-measured in diag_wme_N2.
        if "`wshape`i''" != "plain" {
            local swlist
            foreach sc of local scorelist {
                tempvar scw
                if "`wshape`i''" == "svy" {
                    quietly generate double `scw' = ///
                        `sc' / (`lwexp`i'') if `sample'
                }
                else {
                    quietly generate double `scw' = ///
                        `sc' * `dgpw1_`i'' if `sample'
                }
                local swlist `swlist' `scw'
            }
            local scorelist `swlist'
        }
        local scores`i' `scorelist'

        // Runs on the SCALED scores, so a weight that divides to missing is
        // caught here rather than silently zeroing a meat contribution.
        foreach sc of local scorelist {
            quietly count if !missing(`sc')
            if r(N) != `N`i'' {
                local rc 498
                local errtext "native `__s2c_fam' scores for model `name' are not available on every estimation observation"
                continue, break
            }
        }
        if `rc' continue, break

        tempvar taghigh
        quietly egen byte `taghigh' = tag(`highvar') if `sample'
        quietly count if `taghigh'
        local Ghigh`i' = r(N)
        if `Ghigh`i'' < 2 {
            local rc 459
            local errtext "model `name' contains fewer than two highest-level groups"
            continue, break
        }
    }

    if `rc' {
        di as err "`errtext'"
        exit `rc'
    }

    local scorevar `"`requested_cluster'"'
    // On a weighted system the clustering is fixed by the stored design; a
    // user cluster() would produce a joint covariance whose diagonal blocks
    // are not the variances Stata computed for the constituents.
    if "`sysshape'" != "plain" & trim(`"`scorevar'"') != "" {
        di as err "cluster() and vce(cluster) are not allowed for weighted or {bf:svy:} `__s2c_fam' systems"
        di as err "the clustering is determined by the stored design: e(clustvar) for pweighted models, the {bf:svyset} sampling unit under {bf:svy:}"
        exit 198
    }
    if trim(`"`scorevar'"') == "" local scorevar `"`highvar'"'
    capture confirm numeric variable `scorevar'
    if _rc {
        local rc = _rc
        di as err "cluster variable {bf:`scorevar'} must exist and be numeric"
        exit `rc'
    }

    tempvar union
    quietly generate byte `union' = 0
    forvalues i = 1/`nmodels' {
        quietly replace `union' = 1 if `sample`i''
        quietly count if `sample`i'' & missing(`scorevar')
        if r(N) {
            local name : word `i' of `names'
            di as err "cluster variable {bf:`scorevar'} is missing in the estimation sample for model {bf:`name'}"
            exit 459
        }
    }

    if `"`scorevar'"' != `"`highvar'"' {
        tempvar cmin cmax
        bysort `highvar': egen double `cmin' = min(cond(`union',`scorevar',.))
        bysort `highvar': egen double `cmax' = max(cond(`union',`scorevar',.))
        quietly count if `union' & `cmin' != `cmax'
        if r(N) {
            di as err "highest-level groups in {bf:`highvar'} are not nested within clusters in {bf:`scorevar'}"
            exit 459
        }
    }

    tempvar tagcluster taghighunion
    quietly egen byte `tagcluster' = tag(`scorevar') if `union'
    quietly count if `tagcluster'
    local Gsys = r(N)
    if `Gsys' < 2 {
        di as err "the `__s2c_fam' system contains fewer than two clusters in {bf:`scorevar'}"
        exit 459
    }
    quietly egen byte `taghighunion' = tag(`highvar') if `union'
    quietly count if `taghighunion'
    local Ngsys = r(N)
    quietly count if `union'
    local Nsys = r(N)

    local Ktotal 0
    forvalues i = 1/`nmodels' {
        local start`i' = `Ktotal'+1
        local Ktotal = `Ktotal'+`K`i''
        local end`i' = `Ktotal'

        tempvar tagi
        quietly egen byte `tagi' = tag(`scorevar') if `sample`i''
        quietly count if `tagi'
        local G`i' = r(N)
        if `G`i'' < 2 {
            local name : word `i' of `names'
            di as err "model {bf:`name'} contains fewer than two clusters in {bf:`scorevar'}"
            exit 459
        }
        local scale`i' = (`G`i''/(`G`i''-1))/(`Gsys'/(`Gsys'-1))

        local aligned
        foreach sc of local scores`i' {
            tempvar alignedscore
            quietly generate double `alignedscore' = cond(`sample`i'',`sc',0)*sqrt(`scale`i'') if `union'
            local aligned `aligned' `alignedscore'
        }
        local aligned`i' `aligned'
        local jointscores `jointscores' `aligned'
    }

    tempname bout bfinal Vsys Vbread
    local eqused
    forvalues i = 1/`nmodels' {
        local name : word `i' of `names'
        local sysuniq
        local q 0
        foreach neq of local nativeequniq`i' {
            local ++q
            local candidate = substr(strtoname("`name'_`neq'"),1,32)
            if trim("`candidate'") == "" local candidate = substr("`__s2c_stem'`i'_e`q'",1,32)
            local duplicate : list posof "`candidate'" in eqused
            if `duplicate' local candidate = substr("`__s2c_stem'`i'_e`q'",1,32)
            local duplicate : list posof "`candidate'" in eqused
            if `duplicate' {
                di as err "suest2 could not construct unique equation names for the `__s2c_fam' system"
                exit 498
            }
            local sysuniq `sysuniq' `candidate'
            local eqused `eqused' `candidate'
        }
        local syseqnames`i' `"`sysuniq'"'
        local eqlist
        foreach neq of local nativeeq`i' {
            local pos : list posof "`neq'" in nativeequniq`i'
            local seq : word `pos' of `sysuniq'
            local eqlist `eqlist' `seq'
        }
        local allcn `allcn' `nativecn`i''
        local alleq `alleq' `eqlist'

        tempname bi Vi
        matrix `bi' = `bsrc`i''
        matrix `Vi' = `Vbsrc`i''
        matrix coleq `bi' = `eqlist'
        matrix coleq `Vi' = `eqlist'
        matrix roweq `Vi' = `eqlist'
        if `i' == 1 {
            matrix `bout' = `bi'
            matrix `Vsys' = `Vi'
        }
        else {
            local oldK = colsof(`Vsys')
            matrix `Vsys' = (`Vsys',J(`oldK',`K`i'',0)\J(`K`i'',`oldK',0),`Vi')
            matrix `bout' = `bout',`bi'
        }
    }

    matrix colnames `bout' = `allcn'
    matrix coleq `bout' = `alleq'
    matrix colnames `Vsys' = `allcn'
    matrix rownames `Vsys' = `allcn'
    matrix coleq `Vsys' = `alleq'
    matrix roweq `Vsys' = `alleq'
    matrix `bfinal' = `bout'
    matrix `Vbread' = `Vsys'

    * ereturn post, esample() consumes its temporary sample marker.
    * Give the helper a disposable copy and preserve `union' for the final post.
    tempvar helperunion
    quietly generate byte `helperunion' = `union'
    local jointsvy
    if "`sysshape'" == "svy" local jointsvy "svy"
    capture quietly suest2_me_joint_robust, stem(suest2_`__s2c_fam') ///
        b(`bout') v(`Vsys') ///
        sample(`helperunion') scores(`jointscores') cluster(`scorevar') ///
        `jointsvy'
    if _rc {
        local rc = _rc
        di as err "unable to construct the joint `__s2c_fam' covariance matrix"
        exit `rc'
    }
    tempname Vout Vmb
    matrix `Vout' = e(V)
    matrix `Vmb' = e(V_modelbased)
    mata: st_numscalar("__s2`__s2c_pfx'_breaddiff",max(abs(st_matrix("`Vbread'"):-st_matrix("`Vmb'"))))
    if scalar(__s2`__s2c_pfx'_breaddiff)>1e-12 {
        di as err "the joint `__s2c_fam' model-based covariance was not preserved"
        exit 498
    }

    forvalues i = 1/`nmodels' {
        tempname Vblock Vtarget
        matrix `Vblock' = `Vout'[`start`i''..`end`i'',`start`i''..`end`i'']
        local name : word `i' of `names'
        if "`sysshape'" == "plain" {
            capture quietly estimates restore `name'
            if _rc {
                local rc = _rc
                di as err "unable to restore model {bf:`name'} for covariance validation"
                exit `rc'
            }
            capture quietly suest2_me_native_robust, cluster(`scorevar')
            if _rc {
                local rc = _rc
                di as err "unable to reproduce the native robust `__s2c_fam' covariance for model {bf:`name'}"
                exit `rc'
            }
            matrix `Vtarget' = e(V)
        }
        else {
            // On a weighted or svy store the stored e(V) already IS the
            // design-based covariance, so it is the target directly.  That is
            // a stronger check than recomputing -- it validates against what
            // Stata itself reported -- and it is measured exact: 9.86e-18 and
            // 2.60e-17 on the cluster path, 0.00e+00 and 6.79e-18 under svy:,
            // including where the two models use different samples
            // (diag_wme_N2 parts 1-4).
            matrix `Vtarget' = `Vsrc`i''
        }
        mata: st_numscalar("__s2`__s2c_pfx'_diagdiff",max(abs(st_matrix("`Vblock'"):-st_matrix("`Vtarget'"))))
        mata: st_numscalar("__s2`__s2c_pfx'_diagscale",1+max(abs(st_matrix("`Vtarget'"))))
        if scalar(__s2`__s2c_pfx'_diagdiff)>1e-7*scalar(__s2`__s2c_pfx'_diagscale) {
            di as err "the joint `__s2c_fam' covariance does not reproduce the model-specific block for model {bf:`name'}"
            exit 498
        }
    }

    mata: st_numscalar("__s2_`__s2c_fam'rank",rank(st_matrix("`Vout'")))
    ereturn post `bfinal' `Vout', obs(`Nsys') esample(`union')
    ereturn scalar rank = scalar(__s2_`__s2c_fam'rank)
    ereturn scalar N_clust = `Gsys'
    ereturn scalar N_g = `Ngsys'
    ereturn local clustvar `"`scorevar'"'
    ereturn local vce "cluster"
    ereturn local vcetype "Robust"
    ereturn local method "ML"
    // Design fields, so a weighted or survey system is described the way the
    // single-model results are.  Without these the standard errors would be
    // right but the confidence intervals would use z and residual df rather
    // than the design df, and a mecompare table would differ from the
    // single-model svy answer in a column whose value is not in dispute.
    if "`sysshape'" != "plain" {
        ereturn local wtype `"`dgwtype_1'"'
        ereturn local wexp `"`dgwexp_1'"'
    }
    if "`sysshape'" == "svy" {
        ereturn local prefix "svy"
        ereturn local vce "linearized"
        ereturn local vcetype "Linearized"
        ereturn scalar N_psu = `Gsys'
        // df_r is computed over the SYSTEM, not copied from a constituent:
        // where the two models use different samples their own df_r differ
        // (59 and 49, diag_wme_N2 part 4) while the joint sandwich is built
        // over the union, whose sampling units number Gsys.
        if `dgnstrata_1' < . {
            ereturn scalar N_strata = `dgnstrata_1'
            ereturn scalar df_r = `Gsys' - `dgnstrata_1'
        }
        ereturn scalar suest2_svy = 1
    }
    ereturn local names `"`names'"'
    ereturn local properties "b V"
    ereturn scalar suest2_`__s2c_fam' = 1
    ereturn local suest2_`__s2c_fam'_highvar `"`highvar'"'
    ereturn local suest2_`__s2c_fam'_scorevar `"`scorevar'"'
    ereturn local suest2_`__s2c_fam'_engine "native_observation_scores_allcons"
    ereturn local suest2_`__s2c_fam'`__s2c_revname' "`__s2c_revval'"
    ereturn local suest2_`__s2c_fam'_displayopts `"`displayopts'"'
    ereturn local title "`__s2c_title'"
    ereturn local cmd "suest2_`__s2c_fam'"

    forvalues i = 1/`nmodels' {
        ereturn local eqnames`i' `"`syseqnames`i''"'
        ereturn scalar suest2_`__s2c_fam'_N`i' = `N`i''
        ereturn scalar suest2_`__s2c_fam'_Ghigh`i' = `Ghigh`i''
        ereturn scalar suest2_`__s2c_fam'_G`i' = `G`i''
        ereturn scalar suest2_`__s2c_fam'_K`i' = `K`i''
        ereturn scalar suest2_`__s2c_fam'_rank`i' = `rank`i''
        ereturn scalar suest2_`__s2c_fam'_kf`i' = `kf`i''
        ereturn scalar suest2_`__s2c_fam'_kr`i' = `kr`i''
        if `__s2c_isord' {
            ereturn scalar suest2_`__s2c_fam'_kcat`i' = `kcat`i''
            ereturn scalar suest2_`__s2c_fam'_cutstart`i' = `cutstart`i''
        }
        ereturn scalar suest2_`__s2c_fam'_nquad`i' = `nquad`i''
        ereturn scalar suest2_`__s2c_fam'_scale`i' = `scale`i''
        ereturn local suest2_`__s2c_fam'_ivars`i' `"`ivars`i''"'
        ereturn local suest2_`__s2c_fam'_redim`i' `"`redim`i''"'
        ereturn local suest2_`__s2c_fam'_vartypes`i' `"`vartypes`i''"'
        ereturn local suest2_`__s2c_fam'_revars`i' `"`revars`i''"'
        ereturn local suest2_`__s2c_fam'_intmethod`i' `"`intmethod`i''"'
        if `__s2c_hasdisp' {
            ereturn local suest2_`__s2c_fam'_dispersion`i' `"`dispersion`i''"'
        }
        if `__s2c_isord' {
            ereturn local suest2_`__s2c_fam'_marginsdefault`i' `"`native_marginsdefault`i''"'
            ereturn matrix suest2_`__s2c_fam'_cat`i' = `catsrc`i''
        }
    }
end

program define suest2_melogitestimate, sortpreserve eclass
    version 16
    suest2_meestimate melogit `0'
end

program define suest2_meprobitestimate, sortpreserve eclass
    version 16
    suest2_meestimate meprobit `0'
end

program define suest2_mecloglogestimate, sortpreserve eclass
    version 16
    suest2_meestimate mecloglog `0'
end

program define suest2_mepoissonestimate, sortpreserve eclass
    version 16
    suest2_meestimate mepoisson `0'
end

program define suest2_menbregestimate, sortpreserve eclass
    version 16
    suest2_meestimate menbreg `0'
end

program define suest2_meologitestimate, sortpreserve eclass
    version 16
    suest2_meestimate meologit `0'
end

program define suest2_meoprobitestimate, sortpreserve eclass
    version 16
    suest2_meestimate meoprobit `0'
end

// ============================================================================
// Stored mecloglog adaptive-quadrature route
// ============================================================================





// ============================================================================
// Stored meprobit adaptive-quadrature route
// ============================================================================





// ============================================================================
// Stored meologit adaptive-quadrature route
// ============================================================================





// ============================================================================
// Stored meoprobit adaptive-quadrature route
// ============================================================================





// ============================================================================
// Stored mepoisson adaptive-quadrature route
// ============================================================================





// ============================================================================
// Stored menbreg adaptive-quadrature route
// ============================================================================





// ============================================================================
// Stored mixed, mle route
// ============================================================================


program define suest2_mixed_joint_robust, eclass
    version 9
    syntax, B(name) V(name) SAMPLE(varname) SCORES(varlist) CLUSTER(varname)
    ereturn post `b' `v', esample(`sample')
    ereturn local cmd "suest2_mixed_joint"
    ereturn local properties "b V"
    _robust2 `scores' if e(sample), cluster(`cluster') allcons
end

program define suest2_mixedestimate, sortpreserve eclass
    version 16
    syntax [anything] [, CLuster(varname) VCE(string asis) Robust MINUS ///
        REGRESSML SVY Level(cilevel) DIR EForm(passthru) *]

    if "`minus'" != "" | "`regressml'" != "" | "`svy'" != "" {
        di as err "options minus, regressml, and svy are not supported for mixed systems"
        exit 198
    }

    local displayopts
    if "`level'" != "" local displayopts `"`displayopts' level(`level')"'
    if "`dir'" != "" local displayopts `"`displayopts' dir"'
    if `"`eform'"' != "" local displayopts `"`displayopts' `eform'"'
    if trim(`"`options'"') != "" local displayopts `"`displayopts' `options'"'

    if "`cluster'" != "" & trim(`"`vce'"') != "" {
        di as err "specify only one of cluster() or vce()"
        exit 198
    }
    if "`cluster'" != "" & "`robust'" != "" {
        di as err "specify only one of cluster() or robust"
        exit 198
    }
    if trim(`"`vce'"') != "" & "`robust'" != "" {
        di as err "specify only one of vce() or robust"
        exit 198
    }

    local requested_cluster `"`cluster'"'
    if trim(`"`vce'"') != "" {
        local vcelower = ustrlower(itrim(trim(`"`vce'"')))
        if "`vcelower'" == "robust" local requested_cluster
        else if ustrregexm(`"`vcelower'"', "^cluster[ ]+([A-Za-z_][A-Za-z0-9_]*)$") {
            local requested_cluster `"`=ustrregexs(1)'"'
        }
        else if ustrregexm(`"`vcelower'"', "^cluster[ ]*\([ ]*([A-Za-z_][A-Za-z0-9_]*)[ ]*\)$") {
            local requested_cluster `"`=ustrregexs(1)'"'
        }
        else {
            di as err "the mixed route supports only vce(robust) or vce(cluster varname)"
            exit 198
        }
    }

    est_expand `"`anything'"', min(2) default(.)
    local names `"`r(names)'"'
    local names : list uniq names
    local nmodels : word count `names'
    local hasdot : list posof "." in names
    if `hasdot' {
        di as err "mixed support requires named stored estimates"
        di as err "store each model with {bf:estimates store} before running {bf:suest2}"
        exit 198
    }

    // DESIGN PRE-PASS (see the melogit bridge). mixed differs in two
    // measured ways: svy: does not exist for this family, so the refusal
    // below fails closed against a state Stata itself refuses to produce
    // (diag_wme_N3 part 2); and predict, scores returns a GROUP-level
    // score, one per highest-level group, so scaling by the within-group-
    // constant level-2 weight e(pweight1) reproduces mixed's own e(V) at
    // 1.412e-09 (diag_wme_N3 part 1). Two tokens differ from the other
    // bridges, both measured (diag_wme_N4): the plain shape tests e(vce)
    // against "conventional" rather than "oim", and the pweight shape
    // accepts "cluster" as well as "robust", because a weighted mixed fit
    // clusters on its grouping variable by construction.
    local dgrc 0
    local dgtext
    local dgskip 0
    local sysshape "plain"
    forvalues i = 1/`nmodels' {
        local name : word `i' of `names'
        capture quietly estimates restore `name'
        if _rc {
            local dgskip 1
            continue
        }
        if "`e(cmd)'" != "mixed" {
            local dgskip 1
            continue
        }
        local wshape`i' "none"
        if trim(`"`e(wtype)'"') == "" & trim(`"`e(prefix)'"') == "" & ///
            inlist(`"`e(vce)'"', "", "conventional") {
            local wshape`i' "plain"
        }
        else if trim(`"`e(prefix)'"') == "" & ///
            `"`e(wtype)'"' == "pweight" & ///
            inlist(`"`e(vce)'"', "robust", "cluster") {
            local wshape`i' "pweight"
        }
        if "`wshape`i''" == "none" {
            if trim(`"`e(prefix)'"') == "svy" {
                local dgrc 322
                local dgtext "survey mixed estimates are not supported: Stata itself does not support mixed under svy: with a linearized VCE, so model `name' cannot carry a design this bridge could reproduce"
            }
            else if trim(`"`e(prefix)'"') != "" {
                local dgrc 322
                local dgtext "mixed model `name' was estimated under the `e(prefix)' prefix, which is not supported"
            }
            else if !inlist(`"`e(wtype)'"', "", "pweight") {
                local dgrc 198
                local dgtext "mixed systems accept pweights; model `name' carries `e(wtype)'s"
            }
            else {
                local dgrc 322
                local dgtext "store conventional mixed, mle estimates and request robust or clustered VCE with suest2, or fit the models with pweights"
            }
            continue, break
        }
        if "`wshape`i''" != "plain" {
            local emacs
            capture local emacs : e(macros)
            if _rc | "`emacs'" == "" local emacs "`e(macros)'"
            local fpcfound
            foreach em of local emacs {
                if substr("`em'", 1, 3) == "fpc" local fpcfound "`em'"
            }
            if "`fpcfound'" != "" {
                local dgrc 322
                local dgtext "model `name' carries a finite population correction (e(`fpcfound')); FPC survey designs are not supported for mixed systems"
                continue, break
            }
            if trim(`"`e(subpop)'"') != "" {
                local dgrc 322
                local dgtext "model `name' was estimated with subpop(`e(subpop)'); subpopulation estimation is not supported for mixed systems"
                continue, break
            }
            capture confirm matrix e(V_modelbased)
            if _rc {
                local dgrc 498
                local dgtext "weighted mixed model `name' does not retain e(V_modelbased), which the joint sandwich requires as its bread"
                continue, break
            }
            if trim(`"`e(pweight1)'"') == "" {
                local dgrc 198
                local dgtext "mixed model `name' was fit with a weight but without a stage weight, so it carries no higher-level weight to build a design from; a weighted multilevel system needs one, as in [pw=w2] || group:, pweight(w1), or use the svy: prefix"
                continue, break
            }
            if trim(`"`e(clustvar)'"') == "" {
                local dgrc 498
                local dgtext "pweighted mixed model `name' does not retain e(clustvar)"
                continue, break
            }
            local dgwexp_`i' `"`e(wexp)'"'
            local dgwtype_`i' `"`e(wtype)'"'
            local dgclust_`i' `"`e(clustvar)'"'
            local dgpw1_`i' `"`e(pweight1)'"'
        }
    }
    if `dgrc' {
        di as err "`dgtext'"
        exit `dgrc'
    }
    if !`dgskip' {
        local sysshape `"`wshape1'"'
        local name1 : word 1 of `names'
        forvalues i = 2/`nmodels' {
            local name : word `i' of `names'
            if "`wshape`i''" != "`sysshape'" {
                di as err "mixed constituents mix weighting schemes: model {bf:`name1'} is `sysshape' and model {bf:`name'} is `wshape`i''"
                exit 322
            }
        }
        if "`sysshape'" != "plain" {
            forvalues i = 2/`nmodels' {
                local name : word `i' of `names'
                local mism
                if `"`dgwexp_`i''"' != `"`dgwexp_1'"' local mism "e(wexp)"
                else if `"`dgwtype_`i''"' != `"`dgwtype_1'"' local mism "e(wtype)"
                else if `"`dgclust_`i''"' != `"`dgclust_1'"' local mism "e(clustvar)"
                else if `"`dgpw1_`i''"' != `"`dgpw1_1'"' local mism "e(pweight1)"
                if "`mism'" != "" {
                    di as err "mixed constituents describe different weighting: `mism' differs between models {bf:`name1'} and {bf:`name'}"
                    exit 322
                }
            }
        }
    }

    local highvar
    local scorevar
    local rc 0
    local errtext
    local allcn
    local alleq
    local jointscores

    forvalues i = 1/`nmodels' {
        local name : word `i' of `names'
        capture quietly estimates restore `name'
        if _rc {
            local rc = _rc
            local errtext "unable to restore constituent model `name'"
            continue, break
        }

        if "`e(cmd)'" != "mixed" {
            local rc 322
            local errtext "the first mixed increment requires every constituent model to be mixed"
            continue, break
        }
        if "`e(method)'" != "ML" {
            local rc 322
            local errtext "the first mixed increment supports ML estimation only; refit model `name' with option mle"
            continue, break
        }
        if `"`e(rstructure)'"' != "independent" | e(k_res) != 0 {
            local rc 322
            local errtext "the first mixed increment supports the default independent residual structure only"
            continue, break
        }

        local ivars`i' `"`e(ivars)'"'
        local high`i' : word 1 of `ivars`i''
        if trim(`"`high`i''"') == "" {
            local rc 498
            local errtext "model `name' does not retain a highest-level grouping variable in e(ivars)"
            continue, break
        }
        if `i' == 1 local highvar `"`high`i''"'
        else if `"`high`i''"' != `"`highvar'"' {
            local rc 459
            local errtext "all mixed constituent models must use the same highest-level grouping variable"
            continue, break
        }
        if "`wshape`i''" == "pweight" & `"`dgclust_`i''"' != `"`high`i''"' {
            local rc 459
            local errtext "pweighted mixed model `name' is clustered on `dgclust_`i'' but grouped on `high`i''; the joint covariance requires them to agree"
            continue, break
        }
        capture confirm numeric variable `high`i''
        if _rc {
            local rc = _rc
            local errtext "highest-level grouping variable `high`i'' must exist and be numeric"
            continue, break
        }

        foreach scalar in N k rank k_f k_r k_res {
            capture confirm scalar e(`scalar')
            if _rc {
                local rc 498
                local errtext "model `name' does not retain e(`scalar')"
                continue, break
            }
        }
        if `rc' continue, break
        capture confirm matrix e(b)
        if _rc {
            local rc = _rc
            local errtext "model `name' does not contain e(b)"
            continue, break
        }
        capture confirm matrix e(V)
        if _rc {
            local rc = _rc
            local errtext "model `name' does not contain e(V)"
            continue, break
        }

        tempname pfx
        local pfx`i' `pfx'
        local bsrc `pfx'_b
        local Vsrc `pfx'_V
        local bref `pfx'_br
        local Vref `pfx'_Vr
        local Vbsrc `pfx'_Vb
        local bsrc`i' `bsrc'
        local Vsrc`i' `Vsrc'
        local Vbsrc`i' `Vbsrc'
        matrix `bsrc' = e(b)
        matrix `Vsrc' = e(V)
        // Unweighted: e(V) IS the model-based covariance. Weighted: e(V) is
        // already the clustered sandwich and e(V_modelbased) is the bread.
        if "`wshape`i''" == "plain" matrix `Vbsrc' = `Vsrc'
        else matrix `Vbsrc' = e(V_modelbased)
        local K`i' = colsof(`bsrc')
        local rank`i' = e(rank)
        local N`i' = e(N)
        local kf`i' = e(k_f)
        local kr`i' = e(k_r)
        local depvar`i' `"`e(depvar)'"'
        local redim`i' `"`e(redim)'"'
        local vartypes`i' `"`e(vartypes)'"'
        local revars`i' `"`e(revars)'"'
        local rstructure`i' `"`e(rstructure)'"'
        local optmetric`i' `"`e(optmetric)'"'
        local cmdline`i' `"`e(cmdline)'"'
        local nativecn`i' : colnames `bsrc'
        local nativeeq`i' : coleq `bsrc'
        local nativeequniq`i' : list uniq nativeeq`i'

        tempvar sample sampleref
        local sample`i' `sample'
        quietly generate byte `sample' = e(sample)
        quietly count if `sample'
        if r(N) != `N`i'' {
            local rc 459
            local errtext "the current data no longer reproduce the stored estimation sample for model `name'"
            continue, break
        }

        if trim(`"`cmdline`i''"') == "" {
            local rc 498
            local errtext "model `name' does not retain e(cmdline) for data-reproduction checks"
            continue, break
        }
        capture quietly `cmdline`i''
        if _rc {
            local rc = _rc
            local errtext "the current data cannot re-estimate stored mixed model `name'"
            continue, break
        }
        matrix `bref' = e(b)
        matrix `Vref' = e(V)
        quietly generate byte `sampleref' = e(sample)
        quietly count if `sample' != `sampleref'
        if r(N) {
            local rc 459
            local errtext "the current data do not reproduce the stored estimation sample for model `name'"
            continue, break
        }
        mata: st_numscalar("__s2mix_bdiff",max(abs(st_matrix("`bsrc'"):-st_matrix("`bref'"))))
        mata: st_numscalar("__s2mix_Vdiff",max(abs(st_matrix("`Vsrc'"):-st_matrix("`Vref'"))))
        mata: st_numscalar("__s2mix_bscale",1+max(abs(st_matrix("`bsrc'"))))
        mata: st_numscalar("__s2mix_Vscale",1+max(abs(st_matrix("`Vsrc'"))))
        if scalar(__s2mix_bdiff)>1e-8*scalar(__s2mix_bscale) | ///
            scalar(__s2mix_Vdiff)>1e-8*scalar(__s2mix_Vscale) | ///
            `"`e(method)'"' != "ML" | `"`e(ivars)'"' != `"`ivars`i''"' | ///
            `"`e(redim)'"' != `"`redim`i''"' | `"`e(vartypes)'"' != `"`vartypes`i''"' | ///
            `"`e(revars)'"' != `"`revars`i''"' | `"`e(rstructure)'"' != `"`rstructure`i''"' {
            local rc 459
            local errtext "the current data do not reproduce the stored mixed coefficients, bread, or random-effects specification for model `name'"
            continue, break
        }

        capture quietly estimates restore `name'
        if _rc {
            local rc = _rc
            local errtext "unable to restore constituent model `name' after reproduction checks"
            continue, break
        }

        local scorelist
        forvalues j = 1/`K`i'' {
            tempvar sc
            local scorelist `scorelist' `sc'
        }
        capture quietly predict double `scorelist' if `sample', scores
        if _rc {
            local rc = _rc
            local errtext "unable to generate native ML scores for model `name'"
            continue, break
        }
        local nscore : word count `scorelist'
        if `nscore' != `K`i'' {
            local rc 498
            local errtext "model `name' did not generate one score variable per parameter"
            continue, break
        }
        // The score is a GROUP-level quantity here, present on one
        // observation per group and missing elsewhere, and e(pweight1) is
        // constant within group -- so scaling it observation by observation
        // is the same as scaling the group score, which is what was measured
        // (diag_wme_N3 part 1, 1.412e-09).
        if "`wshape`i''" != "plain" {
            local swlist
            foreach sc of local scorelist {
                tempvar scw
                quietly generate double `scw' = `sc' * `dgpw1_`i'' if `sample'
                local swlist `swlist' `scw'
            }
            local scorelist `swlist'
        }
        local scores`i' `scorelist'

        tempvar taghigh
        quietly egen byte `taghigh' = tag(`highvar') if `sample'
        quietly count if `taghigh'
        local Ghigh`i' = r(N)
        if `Ghigh`i'' < 2 {
            local rc 459
            local errtext "model `name' contains fewer than two highest-level groups"
            continue, break
        }
        foreach sc of local scorelist {
            quietly count if !missing(`sc')
            if r(N) != `Ghigh`i'' {
                local rc 498
                local errtext "native mixed scores for model `name' are not stored once per highest-level group"
                continue, break
            }
        }
        if `rc' continue, break
    }

    if `rc' {
        di as err "`errtext'"
        exit `rc'
    }

    local scorevar `"`requested_cluster'"'
    if "`sysshape'" != "plain" & trim(`"`scorevar'"') != "" {
        di as err "cluster() and vce(cluster) are not allowed for weighted mixed systems"
        di as err "the clustering is determined by the stored design: e(clustvar)"
        exit 198
    }
    if trim(`"`scorevar'"') == "" local scorevar `"`highvar'"'
    capture confirm numeric variable `scorevar'
    if _rc {
        local rc = _rc
        di as err "cluster variable {bf:`scorevar'} must exist and be numeric"
        exit `rc'
    }

    tempvar union
    quietly generate byte `union' = 0
    forvalues i = 1/`nmodels' {
        quietly replace `union' = 1 if `sample`i''
        quietly count if `sample`i'' & missing(`scorevar')
        if r(N) {
            local name : word `i' of `names'
            di as err "cluster variable {bf:`scorevar'} is missing in the estimation sample for model {bf:`name'}"
            exit 459
        }
    }

    if `"`scorevar'"' != `"`highvar'"' {
        tempvar cmin cmax
        bysort `highvar': egen double `cmin' = min(cond(`union',`scorevar',.))
        bysort `highvar': egen double `cmax' = max(cond(`union',`scorevar',.))
        quietly count if `union' & `cmin' != `cmax'
        if r(N) {
            di as err "highest-level groups in {bf:`highvar'} are not nested within clusters in {bf:`scorevar'}"
            exit 459
        }
    }

    tempvar tagcluster taghighunion
    quietly egen byte `tagcluster' = tag(`scorevar') if `union'
    quietly count if `tagcluster'
    local Gsys = r(N)
    if `Gsys' < 2 {
        di as err "the mixed system contains fewer than two clusters in {bf:`scorevar'}"
        exit 459
    }
    quietly egen byte `taghighunion' = tag(`highvar') if `union'
    quietly count if `taghighunion'
    local Ngsys = r(N)
    quietly count if `union'
    local Nsys = r(N)

    local Ktotal 0
    forvalues i = 1/`nmodels' {
        local start`i' = `Ktotal'+1
        local Ktotal = `Ktotal'+`K`i''
        local end`i' = `Ktotal'

        tempvar tagi
        quietly egen byte `tagi' = tag(`scorevar') if `sample`i''
        quietly count if `tagi'
        local G`i' = r(N)
        if `G`i'' < 2 {
            local name : word `i' of `names'
            di as err "model {bf:`name'} contains fewer than two clusters in {bf:`scorevar'}"
            exit 459
        }
        local scale`i' = (`G`i''/(`G`i''-1))/(`Gsys'/(`Gsys'-1))

        local aligned
        foreach sc of local scores`i' {
            tempvar groupscore alignedscore
            bysort `highvar': egen double `groupscore' = max(`sc')
            quietly replace `groupscore' = 0 if missing(`groupscore') & `union'
            quietly generate double `alignedscore' = `groupscore'*sqrt(`scale`i'') if `taghighunion'
            local aligned `aligned' `alignedscore'
        }
        local aligned`i' `aligned'
        local jointscores `jointscores' `aligned'
    }

    tempname bout bfinal Vsys Vbread
    local eqused
    forvalues i = 1/`nmodels' {
        local name : word `i' of `names'
        local sysuniq
        local q 0
        foreach neq of local nativeequniq`i' {
            local ++q
            local candidate = substr(strtoname("`name'_`neq'"),1,32)
            if trim("`candidate'") == "" local candidate = substr("s2m`i'_e`q'",1,32)
            local duplicate : list posof "`candidate'" in eqused
            if `duplicate' local candidate = substr("s2m`i'_e`q'",1,32)
            local duplicate : list posof "`candidate'" in eqused
            if `duplicate' {
                di as err "suest2 could not construct unique equation names for the mixed system"
                exit 498
            }
            local sysuniq `sysuniq' `candidate'
            local eqused `eqused' `candidate'
        }
        local syseqnames`i' `"`sysuniq'"'
        local eqlist
        foreach neq of local nativeeq`i' {
            local pos : list posof "`neq'" in nativeequniq`i'
            local seq : word `pos' of `sysuniq'
            local eqlist `eqlist' `seq'
        }
        local allcn `allcn' `nativecn`i''
        local alleq `alleq' `eqlist'

        tempname bi Vi
        matrix `bi' = `bsrc`i''
        matrix `Vi' = `Vbsrc`i''
        matrix coleq `bi' = `eqlist'
        matrix coleq `Vi' = `eqlist'
        matrix roweq `Vi' = `eqlist'
        if `i' == 1 {
            matrix `bout' = `bi'
            matrix `Vsys' = `Vi'
        }
        else {
            local oldK = colsof(`Vsys')
            matrix `Vsys' = (`Vsys',J(`oldK',`K`i'',0)\J(`K`i'',`oldK',0),`Vi')
            matrix `bout' = `bout',`bi'
        }
    }

    matrix colnames `bout' = `allcn'
    matrix coleq `bout' = `alleq'
    matrix colnames `Vsys' = `allcn'
    matrix rownames `Vsys' = `allcn'
    matrix coleq `Vsys' = `alleq'
    matrix roweq `Vsys' = `alleq'
    matrix `bfinal' = `bout'
    matrix `Vbread' = `Vsys'

    capture quietly suest2_mixed_joint_robust, b(`bout') v(`Vsys') ///
        sample(`taghighunion') scores(`jointscores') cluster(`scorevar')
    if _rc {
        local rc = _rc
        di as err "unable to construct the joint mixed covariance matrix"
        exit `rc'
    }
    tempname Vout Vmb
    matrix `Vout' = e(V)
    matrix `Vmb' = e(V_modelbased)
    mata: st_numscalar("__s2mix_breaddiff",max(abs(st_matrix("`Vbread'"):-st_matrix("`Vmb'"))))
    if scalar(__s2mix_breaddiff)>1e-12 {
        di as err "the joint mixed model-based covariance was not preserved"
        exit 498
    }

    forvalues i = 1/`nmodels' {
        tempname Vblock Vtarget
        matrix `Vblock' = `Vout'[`start`i''..`end`i'',`start`i''..`end`i'']
        local name : word `i' of `names'
        if "`sysshape'" == "plain" {
            capture quietly estimates restore `name'
            if _rc {
                local rc = _rc
                di as err "unable to restore model {bf:`name'} for covariance validation"
                exit `rc'
            }
            capture quietly suest2_me_native_robust, cluster(`scorevar')
            if _rc {
                local rc = _rc
                di as err "unable to reproduce the native robust mixed covariance for model {bf:`name'}"
                exit `rc'
            }
            matrix `Vtarget' = e(V)
        }
        else {
            // On a weighted store the stored e(V) already IS the clustered
            // covariance, so it is the target directly -- validating against
            // what Stata reported rather than against a recipe of ours.
            matrix `Vtarget' = `Vsrc`i''
        }
        mata: st_numscalar("__s2mix_diagdiff",max(abs(st_matrix("`Vblock'"):-st_matrix("`Vtarget'"))))
        mata: st_numscalar("__s2mix_diagscale",1+max(abs(st_matrix("`Vtarget'"))))
        if scalar(__s2mix_diagdiff)>1e-7*scalar(__s2mix_diagscale) {
            di as err "the joint mixed covariance does not reproduce the model-specific block for model {bf:`name'}"
            exit 498
        }
    }

    mata: st_numscalar("__s2_mixedrank",rank(st_matrix("`Vout'")))
    ereturn post `bfinal' `Vout', obs(`Nsys') esample(`union')
    ereturn scalar rank = scalar(__s2_mixedrank)
    ereturn scalar N_clust = `Gsys'
    ereturn scalar N_g = `Ngsys'
    ereturn local clustvar `"`scorevar'"'
    ereturn local vce "cluster"
    ereturn local vcetype "Robust"
    ereturn local method "ML"
    if "`sysshape'" != "plain" {
        ereturn local wtype `"`dgwtype_1'"'
        ereturn local wexp `"`dgwexp_1'"'
    }
    ereturn local names `"`names'"'
    ereturn local properties "b V"
    ereturn scalar suest2_mixed = 1
    ereturn local suest2_mixed_highvar `"`highvar'"'
    ereturn local suest2_mixed_scorevar `"`scorevar'"'
    ereturn local suest2_mixed_engine "native_parameter_scores_allcons"
    ereturn local suest2_mixed_runtime_revision "candidate1_rev3"
    ereturn local suest2_mixed_displayopts `"`displayopts'"'
    ereturn local title "Simultaneous mixed-effects ML results"
    ereturn local cmd "suest2_mixed"

    forvalues i = 1/`nmodels' {
        ereturn local eqnames`i' `"`syseqnames`i''"'
        ereturn scalar suest2_mixed_N`i' = `N`i''
        ereturn scalar suest2_mixed_Ghigh`i' = `Ghigh`i''
        ereturn scalar suest2_mixed_G`i' = `G`i''
        ereturn scalar suest2_mixed_K`i' = `K`i''
        ereturn scalar suest2_mixed_rank`i' = `rank`i''
        ereturn scalar suest2_mixed_kf`i' = `kf`i''
        ereturn scalar suest2_mixed_kr`i' = `kr`i''
        ereturn scalar suest2_mixed_scale`i' = `scale`i''
        ereturn local suest2_mixed_ivars`i' `"`ivars`i''"'
        ereturn local suest2_mixed_redim`i' `"`redim`i''"'
        ereturn local suest2_mixed_vartypes`i' `"`vartypes`i''"'
        ereturn local suest2_mixed_revars`i' `"`revars`i''"'
        ereturn local suest2_mixed_rstructure`i' `"`rstructure`i''"'
        ereturn local suest2_mixed_optmetric`i' `"`optmetric`i''"'
    }
end

// ============================================================================
// Stored xtreg, mle route
// ============================================================================

program define suest2_xtmlestimate, sortpreserve eclass
    version 16
    syntax [anything] [, CLuster(varname) VCE(string asis) Robust MINUS ///
        REGRESSML SVY Level(cilevel) DIR EForm(passthru) *]

    if "`minus'" != "" | "`regressml'" != "" | "`svy'" != "" {
        di as err "options minus, regressml, and svy are not supported for xtreg, mle systems"
        exit 198
    }

    local displayopts
    if "`level'" != "" local displayopts `"`displayopts' level(`level')"'
    if "`dir'" != "" local displayopts `"`displayopts' dir"'
    if `"`eform'"' != "" local displayopts `"`displayopts' `eform'"'
    if trim(`"`options'"') != "" local displayopts `"`displayopts' `options'"'

    if "`cluster'" != "" & trim(`"`vce'"') != "" {
        di as err "specify only one of cluster() or vce()"
        exit 198
    }
    if "`cluster'" != "" & "`robust'" != "" {
        di as err "specify only one of cluster() or robust"
        exit 198
    }
    if trim(`"`vce'"') != "" & "`robust'" != "" {
        di as err "specify only one of vce() or robust"
        exit 198
    }

    local requested_cluster `"`cluster'"'
    if trim(`"`vce'"') != "" {
        local vcelower = ustrlower(itrim(trim(`"`vce'"')))
        if "`vcelower'" == "robust" local requested_cluster
        else if ustrregexm(`"`vcelower'"', "^cluster[ ]+([A-Za-z_][A-Za-z0-9_]*)$") {
            local requested_cluster `"`=ustrregexs(1)'"'
        }
        else if ustrregexm(`"`vcelower'"', "^cluster[ ]*\([ ]*([A-Za-z_][A-Za-z0-9_]*)[ ]*\)$") {
            local requested_cluster `"`=ustrregexs(1)'"'
        }
        else {
            di as err "the xtreg, mle route supports only vce(robust) or vce(cluster varname)"
            exit 198
        }
    }

    est_expand `"`anything'"', min(2) default(.)
    local names `"`r(names)'"'
    local names : list uniq names
    local nmodels : word count `names'
    local hasdot : list posof "." in names
    if `hasdot' {
        di as err "xtreg, mle support requires named stored estimates"
        di as err "store each model with {bf:estimates store} before running {bf:suest2}"
        exit 198
    }

    local bridges
    local rc 0
    local panelvar
    local scorevar
    local errtext
    local cleanupvars
    local cleanupmats

    forvalues i = 1/`nmodels' {
        local name : word `i' of `names'
        capture quietly estimates restore `name'
        if _rc {
            local rc = _rc
            local errtext "unable to restore constituent model `name'"
            continue, break
        }

        if "`e(cmd)'" != "xtreg" | "`e(model)'" != "ml" {
            local rc 322
            local errtext "the first xtreg, mle increment requires every constituent model to be xtreg, mle"
            continue, break
        }
        if trim(`"`e(wtype)'"') != "" {
            local rc 198
            local errtext "weights are not yet supported for xtreg, mle systems"
            continue, break
        }
        if !inlist(`"`e(vce)'"', "", "oim") {
            local rc 322
            local errtext "store ordinary xtreg, mle estimates and request robust or clustered VCE with suest2"
            continue, break
        }
        capture confirm scalar e(converged)
        if !_rc & !e(converged) {
            local rc 430
            local errtext "model `name' did not converge"
            continue, break
        }

        local ivar `"`e(ivar)'"'
        if trim(`"`ivar'"') == "" {
            local rc 498
            local errtext "model `name' does not retain its panel identifier in e(ivar)"
            continue, break
        }
        if `i' == 1 local panelvar `"`ivar'"'
        else if `"`ivar'"' != `"`panelvar'"' {
            local rc 459
            local errtext "all xtreg, mle constituent models must use the same panel variable"
            continue, break
        }

        foreach scalar in rank sigma_u sigma_e N N_g {
            capture confirm scalar e(`scalar')
            if _rc {
                local rc 498
                local errtext "model `name' does not retain e(`scalar')"
                continue, break
            }
        }
        if `rc' continue, break
        capture confirm matrix e(b)
        if _rc {
            local rc = _rc
            local errtext "model `name' does not contain e(b)"
            continue, break
        }
        capture confirm matrix e(V)
        if _rc {
            local rc = _rc
            local errtext "model `name' does not contain e(V)"
            continue, break
        }
        if e(sigma_u) <= 0 | e(sigma_e) <= 0 {
            local rc 498
            local errtext "model `name' is on an unsupported zero-variance boundary"
            continue, break
        }

        tempname pfx
        local pfx`i' `pfx'
        local bsrc `pfx'_b
        local Vsrc `pfx'_V
        local omit `pfx'_o
        local A `pfx'_A
        local At `pfx'_At
        local bbridge `pfx'_bb
        local Vbridge `pfx'_VV
        local bsrc`i' `bsrc'
        local Vsrc`i' `Vsrc'
        local A`i' `A'
        local At`i' `At'
        local cleanupmats `cleanupmats' `bsrc' `Vsrc' `omit' `A' `At' `bbridge' `Vbridge'
        matrix `bsrc' = e(b)
        matrix `Vsrc' = e(V)
        local Kfull`i' = colsof(`bsrc')
        if `Kfull`i'' < 3 {
            local rc 498
            local errtext "model `name' has an invalid xtreg, mle coefficient layout"
            continue, break
        }

        local nativecn`i' : colnames `bsrc'
        local nativeeq`i' : coleq `bsrc'
        local Kmain`i' = `Kfull`i'' - 2
        local equ`i' : word `=`Kfull`i''-1' of `nativeeq`i''
        local eqe`i' : word `Kfull`i'' of `nativeeq`i''
        if `"`equ`i''"' != "sigma_u" | `"`eqe`i''"' != "sigma_e" {
            local rc 498
            local errtext "model `name' does not have native sigma_u and sigma_e equations in the expected positions"
            continue, break
        }

        local N`i' = e(N)
        local Ng_native`i' = e(N_g)
        local nativerank`i' = e(rank)
        local sigmau`i' = e(sigma_u)
        local sigmae`i' = e(sigma_e)
        local rho`i' = e(rho)
        local depvar`i' `"`e(depvar)'"'
        local offset`i' `"`e(offset)'"'
        if trim(`"`offset`i''"') == "" local offset`i' `"`e(offset1)'"'

        local sample `pfx'_s
        local xb `pfx'_x
        local resid `pfx'_r
        local Ti `pfx'_T
        local rsum `pfx'_R
        local den `pfx'_d
        local qscore `pfx'_q
        local ord `pfx'_n
        local last `pfx'_l
        local qsq `pfx'_Q
        local sample`i' `sample'
        local cleanupvars `cleanupvars' `sample' `xb' `resid' `Ti' `rsum' `den' `qscore' `ord' `last' `qsq'
        quietly generate byte `sample' = e(sample)
        quietly count if `sample'
        if r(N) != `N`i'' {
            local rc 459
            local errtext "the current data no longer reproduce the stored estimation sample for model `name'"
            continue, break
        }

        capture quietly predict double `xb' if `sample', xb
        if _rc {
            local rc = _rc
            local errtext "unable to reproduce native xb for model `name'"
            continue, break
        }
        quietly generate double `resid' = `depvar`i'' - `xb' if `sample'
        bysort `panelvar': egen long `Ti' = total(`sample')
        bysort `panelvar': egen double `rsum' = total(cond(`sample', `resid', 0))
        quietly generate double `den' = `sigmae`i''^2 + `Ti'*`sigmau`i''^2 if `sample'
        quietly generate double `qscore' = `resid'/`sigmae`i''^2 - ///
            `sigmau`i''^2*`rsum'/(`sigmae`i''^2*`den') if `sample'
        bysort `panelvar': generate long `ord' = sum(`sample')
        quietly generate byte `last' = `sample' & `ord' == `Ti'
        bysort `panelvar': egen double `qsq' = total(cond(`sample', `qscore'^2, 0))

        quietly _ms_omit_info `bsrc'
        matrix `omit' = r(omit)
        local Kest 0
        forvalues q = 1/`Kfull`i'' {
            if `omit'[1,`q'] == 0 local ++Kest
        }
        if `Kest' != `nativerank`i'' {
            local rc 498
            local errtext "the native omission map does not match e(rank) for model `name'"
            continue, break
        }
        matrix `A' = J(`Kfull`i'', `Kest', 0)

        local scores
        local kestpos 0
        forvalues q = 1/`Kmain`i'' {
            if `omit'[1,`q'] == 0 {
                local ++kestpos
                local term : word `q' of `nativecn`i''
                local sc `pfx'_c`kestpos'
                local cleanupvars `cleanupvars' `sc'
                if `"`term'"' == "_cons" {
                    quietly generate double `sc' = `qscore' if `sample'
                }
                else {
                    capture quietly fvrevar `term'
                    if _rc {
                        local rc = _rc
                        local errtext "unable to reconstruct ML design term `term' for model `name'"
                        continue, break
                    }
                    local raw `"`r(varlist)'"'
                    local nraw : word count `raw'
                    if `nraw' != 1 {
                        local rc 498
                        local errtext "ML design term `term' did not expand to one variable for model `name'"
                        continue, break
                    }
                    quietly generate double `sc' = `raw'*`qscore' if `sample'
                }
                local scores `scores' `sc'
                matrix `A'[`q',`kestpos'] = 1
            }
        }
        if `rc' continue, break

        if `omit'[1,`=`Kfull`i''-1'] != 0 | `omit'[1,`Kfull`i''] != 0 {
            local rc 498
            local errtext "sigma_u or sigma_e is unexpectedly omitted for model `name'"
            continue, break
        }

        local ++kestpos
        local scu `pfx'_c`kestpos'
        local cleanupvars `cleanupvars' `scu'
        quietly generate double `scu' = 0 if `sample'
        quietly replace `scu' = `sigmau`i''*(`rsum'^2/`den'^2 - `Ti'/`den') if `last'
        local scores `scores' `scu'
        matrix `A'[`=`Kfull`i''-1',`kestpos'] = 1

        local ++kestpos
        local sce `pfx'_c`kestpos'
        local cleanupvars `cleanupvars' `sce'
        quietly generate double `sce' = 0 if `sample'
        quietly replace `sce' = `sigmae`i''*(`qsq' - ///
            ((`Ti'-1)/`sigmae`i''^2 + 1/`den')) if `last'
        local scores `scores' `sce'
        matrix `A'[`Kfull`i'',`kestpos'] = 1

        if `kestpos' != `Kest' {
            local rc 498
            local errtext "suest2 could not construct every estimable ML score for model `name'"
            continue, break
        }

        local maxscore 0
        foreach sc of local scores {
            quietly summarize `sc' if `sample', meanonly
            local asum = abs(r(sum))
            if `asum' > `maxscore' local maxscore = `asum'
        }
        if `maxscore' > 1e-4 {
            local rc 498
            local errtext "the current data do not reproduce the stored xtreg, mle score equations for model `name'"
            continue, break
        }

        capture mata: st_matrix("`At'", st_matrix("`A'")')
        if _rc {
            local rc = _rc
            local errtext "unable to transpose the ML estimable-parameter map for model `name'"
            continue, break
        }
        capture mata: st_matrix("`bbridge'", st_matrix("`bsrc'")*st_matrix("`A'"))
        if _rc {
            local rc = _rc
            local errtext "unable to project the native ML coefficient vector for model `name'"
            continue, break
        }
        capture mata: st_matrix("`Vbridge'", ///
            st_matrix("`At'")*st_matrix("`Vsrc'")*st_matrix("`A'"))
        if _rc {
            local rc = _rc
            local errtext "unable to project the native ML covariance into the estimable score space for model `name'"
            continue, break
        }
        local Kest`i' = `Kest'
        local scores`i' `"`scores'"'
        local maxscore`i' = `maxscore'

        local bridgeeq
        local bridgecn
        forvalues q = 1/`Kest' {
            local bridgeeq `bridgeeq' p`q'
            local bridgecn `bridgecn' _cons
        }
        matrix colnames `bbridge' = `bridgecn'
        matrix rownames `Vbridge' = `bridgecn'
        matrix colnames `Vbridge' = `bridgecn'
        matrix coleq `bbridge' = `bridgeeq'
        matrix roweq `Vbridge' = `bridgeeq'
        matrix coleq `Vbridge' = `bridgeeq'

        * Keep `sample' as an ordinary persistent copy for union and cluster
        * calculations.  The variable passed to ereturn post becomes the active
        * e(sample) and is disposable when the next estimate is restored.
        tempvar postsample
        quietly generate byte `postsample' = `sample'
        quietly suest2_xtregmle_post, b(`bbridge') v(`Vbridge') ///
            sample(`postsample') scores(`scores') n(`N`i'') depvar(`depvar`i'')
        local bridge `pfx'_est
        quietly estimates store `bridge'
        local bridges `"`bridges' `bridge'"'
    }

    if `rc' {
        foreach bridge of local bridges {
            capture quietly estimates drop `bridge'
        }
        capture drop `cleanupvars'
        foreach m of local cleanupmats {
            capture matrix drop `m'
        }
        di as err `"`errtext'"'
        exit `rc'
    }

    capture quietly xtset
    if _rc {
        local rc = _rc
        foreach bridge of local bridges {
            capture quietly estimates drop `bridge'
        }
        capture drop `cleanupvars'
        foreach m of local cleanupmats {
            capture matrix drop `m'
        }
        di as err "the current data must remain xtset for the stored xtreg, mle models"
        exit `rc'
    }
    local currentpanel `"`r(panelvar)'"'
    if `"`currentpanel'"' != `"`panelvar'"' {
        foreach bridge of local bridges {
            capture quietly estimates drop `bridge'
        }
        capture drop `cleanupvars'
        foreach m of local cleanupmats {
            capture matrix drop `m'
        }
        di as err "the current xtset panel variable differs from stored e(ivar)={bf:`panelvar'}"
        exit 459
    }

    if trim(`"`requested_cluster'"') == "" local scorevar `"`panelvar'"'
    else local scorevar `"`requested_cluster'"'
    capture confirm numeric variable `scorevar'
    if _rc {
        local rc = _rc
        foreach bridge of local bridges {
            capture quietly estimates drop `bridge'
        }
        capture drop `cleanupvars'
        foreach m of local cleanupmats {
            capture matrix drop `m'
        }
        di as err "cluster variable {bf:`scorevar'} must be numeric"
        exit `rc'
    }

    tempvar union cmin cmax
    quietly generate byte `union' = 0
    forvalues i = 1/`nmodels' {
        quietly replace `union' = 1 if `sample`i''
    }
    quietly count if `union' & missing(`scorevar')
    if r(N) {
        foreach bridge of local bridges {
            capture quietly estimates drop `bridge'
        }
        capture drop `cleanupvars'
        foreach m of local cleanupmats {
            capture matrix drop `m'
        }
        di as err "cluster variable {bf:`scorevar'} is missing on " r(N) " observation(s) in the union sample"
        exit 459
    }
    bysort `panelvar': egen double `cmin' = min(cond(`union', `scorevar', .))
    bysort `panelvar': egen double `cmax' = max(cond(`union', `scorevar', .))
    quietly count if `union' & `cmin' != `cmax'
    if r(N) {
        foreach bridge of local bridges {
            capture quietly estimates drop `bridge'
        }
        capture drop `cleanupvars'
        foreach m of local cleanupmats {
            capture matrix drop `m'
        }
        di as err "panel variable {bf:`panelvar'} is not nested within cluster variable {bf:`scorevar'}"
        exit 459
    }

    forvalues i = 1/`nmodels' {
        tempvar tagcluster
        quietly egen byte `tagcluster' = tag(`scorevar') if `sample`i''
        quietly count if `tagcluster'
        local G`i' = r(N)
        if `G`i'' < 2 {
            foreach bridge of local bridges {
                capture quietly estimates drop `bridge'
            }
            local name : word `i' of `names'
            di as err "model {bf:`name'} contains fewer than two clusters in {bf:`scorevar'}"
            exit 459
        }
    }

    * The retained samples and analytic score variables must survive all
    * constituent estimate restores.  Stored bridge e(sample) is maintained
    * separately by Stata's estimates machinery.
    forvalues i = 1/`nmodels' {
        capture confirm variable `sample`i''
        if _rc {
            foreach bridge of local bridges {
                capture quietly estimates drop `bridge'
            }
            capture drop `cleanupvars'
            foreach m of local cleanupmats {
                capture matrix drop `m'
            }
            local name : word `i' of `names'
            di as err "retained ML sample disappeared before system assembly for model {bf:`name'}"
            exit 498
        }
        foreach sc of local scores`i' {
            capture confirm variable `sc'
            if _rc {
                foreach bridge of local bridges {
                    capture quietly estimates drop `bridge'
                }
                capture drop `cleanupvars'
                foreach m of local cleanupmats {
                    capture matrix drop `m'
                }
                local name : word `i' of `names'
                di as err "analytic ML score variable disappeared before system assembly for model {bf:`name'}"
                exit 498
            }
        }
    }

    capture quietly suest `bridges', cluster(`scorevar')
    local rc = _rc
    if `rc' {
        foreach bridge of local bridges {
            capture quietly estimates drop `bridge'
        }
        capture drop `cleanupvars'
        foreach m of local cleanupmats {
            capture matrix drop `m'
        }
        di as err "official suest could not combine the xtreg, mle analytic-score bridges"
        exit `rc'
    }

    tempname bsys Vsys bout Vout
    matrix `bsys' = e(b)
    matrix `Vsys' = e(V)
    local Nsys = e(N)
    local Gsys = e(N_clust)
    local expected 0
    forvalues i = 1/`nmodels' {
        local bstart`i' = `expected' + 1
        local expected = `expected' + `Kest`i''
        local bend`i' = `expected'
    }
    if colsof(`bsys') != `expected' {
        foreach bridge of local bridges {
            capture quietly estimates drop `bridge'
        }
        capture drop `cleanupvars'
        foreach m of local cleanupmats {
            capture matrix drop `m'
        }
        di as err "suest2 could not map the official suest ML bridge parameter blocks"
        exit 498
    }

    forvalues i = 1/`nmodels' {
        tempname bcheck
        matrix `bcheck' = `bsys'[1,`bstart`i''..`bend`i'']
        tempname btarget
        capture mata: st_matrix("`btarget'", ///
            st_matrix("`bsrc`i''")*st_matrix("`A`i''"))
        if _rc {
            foreach bridge of local bridges {
                capture quietly estimates drop `bridge'
            }
            local name : word `i' of `names'
            di as err "unable to reconstruct the estimable ML coefficient block for model {bf:`name'}"
            exit _rc
        }
        if mreldif(`bcheck', `btarget') > 1e-10 {
            foreach bridge of local bridges {
                capture quietly estimates drop `bridge'
            }
            local name : word `i' of `names'
            di as err "official suest changed the ML bridge coefficients for model {bf:`name'}"
            exit 498
        }
        local scale`i' = (`G`i''/(`G`i''-1)) / (`Gsys'/(`Gsys'-1))
    }

    local Kfulltotal 0
    forvalues i = 1/`nmodels' {
        local fullstart`i' = `Kfulltotal' + 1
        local Kfulltotal = `Kfulltotal' + `Kfull`i''
        local fullend`i' = `Kfulltotal'
    }

    capture mata: st_matrix("`Vout'", J(`Kfulltotal',`Kfulltotal',0))
    if _rc {
        foreach bridge of local bridges {
            capture quietly estimates drop `bridge'
        }
        capture drop `cleanupvars'
        foreach m of local cleanupmats {
            capture matrix drop `m'
        }
        di as err "unable to initialize the full native ML covariance matrix"
        exit _rc
    }

    forvalues i = 1/`nmodels' {
        forvalues j = 1/`nmodels' {
            capture mata: __s2ml_Vout=st_matrix("`Vout'"); ///
                __s2ml_raw=st_matrix("`Vsys'")[|`bstart`i'',`bstart`j'' \ `bend`i'',`bend`j''|]; ///
                __s2ml_block=sqrt(`scale`i''*`scale`j'')* ///
                    st_matrix("`A`i''")*__s2ml_raw*st_matrix("`At`j''"); ///
                __s2ml_Vout[|`fullstart`i'',`fullstart`j'' \ `fullend`i'',`fullend`j''|]=__s2ml_block; ///
                st_matrix("`Vout'",__s2ml_Vout)
            if _rc {
                local maprc = _rc
                foreach bridge of local bridges {
                    capture quietly estimates drop `bridge'
                }
                di as err "unable to write ML covariance block (`i',`j') into the full native parameter matrix"
                exit `maprc'
            }
        }
    }

    local eqused
    forvalues i = 1/`nmodels' {
        local name : word `i' of `names'
        local eqmain = substr(strtoname("`name'_mean"),1,32)
        local equ = substr(strtoname("`name'_sigma_u"),1,32)
        local eqe = substr(strtoname("`name'_sigma_e"),1,32)
        foreach candidate in eqmain equ eqe {
            local eqval ``candidate''
            local duplicate : list posof "`eqval'" in eqused
            if `duplicate' {
                local eqval = substr("s2ml`i'_`candidate'",1,32)
                local `candidate' `"`eqval'"'
            }
            local eqused `"`eqused' `eqval'"'
        }
        local eqmain`i' `"`eqmain'"'
        local equ`i' `"`equ'"'
        local eqe`i' `"`eqe'"'

        tempname bi
        matrix `bi' = `bsrc`i''
        local eqlist
        forvalues q = 1/`Kmain`i'' {
            local eqlist `eqlist' `eqmain'
        }
        local eqlist `eqlist' `equ' `eqe'
        matrix coleq `bi' = `eqlist'
        if `i' == 1 matrix `bout' = `bi'
        else matrix `bout' = `bout',`bi'
    }

    capture mata: __s2ml_Vout=st_matrix("`Vout'"); ///
        st_matrix("`Vout'",(__s2ml_Vout+__s2ml_Vout')/2)
    if _rc {
        local symrc = _rc
        foreach bridge of local bridges {
            capture quietly estimates drop `bridge'
        }
        capture drop `cleanupvars'
        foreach m of local cleanupmats {
            capture matrix drop `m'
        }
        di as err "unable to symmetrize the full native ML covariance matrix"
        exit `symrc'
    }
    local bcn : colnames `bout'
    local beq : coleq `bout'
    matrix colnames `Vout' = `bcn'
    matrix rownames `Vout' = `bcn'
    matrix coleq `Vout' = `beq'
    matrix roweq `Vout' = `beq'

    tempvar tagpanel
    quietly egen byte `tagpanel' = tag(`panelvar') if `union'
    quietly count if `tagpanel'
    local Ngsys = r(N)

    ereturn post `bout' `Vout', obs(`Nsys') esample(`union')
    mata: st_numscalar("__s2_xtmlrank",rank(st_matrix("`Vout'")))
    ereturn scalar rank = scalar(__s2_xtmlrank)
    ereturn scalar N_clust = `Gsys'
    ereturn scalar N_g = `Ngsys'
    ereturn local clustvar `"`scorevar'"'
    ereturn local vce "cluster"
    ereturn local vcetype "Robust"
    ereturn local names `"`names'"'
    ereturn local properties "b V"
    ereturn scalar suest2_xtml = 1
    ereturn local suest2_xtml_panelvar `"`panelvar'"'
    ereturn local suest2_xtml_scorevar `"`scorevar'"'
    ereturn local suest2_xtml_engine "analytic_ml_score_suest_bridge"
    ereturn local suest2_xtml_runtime_revision "candidate1_rev9"
    ereturn local suest2_xtml_displayopts `"`displayopts'"'
    ereturn local title "Simultaneous random-effects ML results"
    ereturn local cmd "suest2_xtml"

    forvalues i = 1/`nmodels' {
        ereturn local eqnames`i' `"`eqmain`i'' `equ`i'' `eqe`i''"'
        ereturn scalar suest2_xtml_N`i' = `N`i''
        ereturn scalar suest2_xtml_Npanel`i' = `Ng_native`i''
        ereturn scalar suest2_xtml_G`i' = `G`i''
        ereturn scalar suest2_xtml_K`i' = `Kest`i''
        ereturn scalar suest2_xtml_Kfull`i' = `Kfull`i''
        ereturn scalar suest2_xtml_Kmain`i' = `Kmain`i''
        ereturn scalar suest2_xtml_native_rank`i' = `nativerank`i''
        ereturn scalar suest2_xtml_sigma_u`i' = `sigmau`i''
        ereturn scalar suest2_xtml_sigma_e`i' = `sigmae`i''
        ereturn scalar suest2_xtml_rho`i' = `rho`i''
        ereturn scalar suest2_xtml_scale`i' = `scale`i''
        ereturn scalar suest2_xtml_score_maxabs`i' = `maxscore`i''
        ereturn local suest2_xtml_offset`i' `"`offset`i''"'
    }

    foreach bridge of local bridges {
        capture quietly estimates drop `bridge'
    }
    capture drop `cleanupvars'
    foreach m of local cleanupmats {
        capture matrix drop `m'
    }
end

program define suest2_xtregmle_post, eclass
    version 16
    syntax, B(name) V(name) SAMPLE(varname) SCORES(varlist) N(integer) DEPVAR(name)
    ereturn post `b' `v', esample(`sample') obs(`n')
    ereturn local cmd "suest2_xtregmle"
    ereturn local predict "suest2_xtregmle_p"
    ereturn local properties "b V"
    ereturn local vce "oim"
    ereturn local vcetype "OIM"
    ereturn local depvar "`depvar'"
    ereturn local suest2_xtml_scores "`scores'"
    ereturn scalar k_eq = colsof(e(b))
end





// ============================================================================
// xtmlogit complete native-score route
// ============================================================================

program define suest2_xtmlogit_joint_robust, eclass
    version 17
    syntax, B(name) V(name) SAMPLE(varname) SCORES(varlist) CLUSTER(varname)
    tempname bcopy vcopy
    matrix `bcopy'=`b'
    matrix `vcopy'=`v'
    ereturn post `bcopy' `vcopy', esample(`sample')
    ereturn local cmd "suest2_xtmlogit_joint"
    ereturn local properties "b V"
    _robust2 `scores' if e(sample), cluster(`cluster') allcons
end

program define suest2_xtmlogit_native_robust, eclass
    version 17
    syntax, CLUSTER(varname)
    tempname b V
    tempvar sample
    matrix `b'=e(b)
    matrix `V'=e(V)
    quietly generate byte `sample'=e(sample)
    local K=colsof(`b')
    local scores
    forvalues j=1/`K' {
        tempvar sc
        local scores `scores' `sc'
    }
    quietly predict double `scores' if `sample', scores
    suest2_xtmlogit_joint_robust, b(`b') v(`V') sample(`sample') ///
        scores(`scores') cluster(`cluster')
end

program define suest2_xtmlogitestimate, sortpreserve eclass
    version 17
    syntax [anything] [, CLuster(varname) VCE(string asis) Robust MINUS ///
        REGRESSML SVY Level(cilevel) DIR EForm(passthru) *]

    if "`minus'`regressml'`svy'"!="" {
        di as err "options minus, regressml, and svy are not supported for xtmlogit systems"
        exit 198
    }

    local displayopts
    if "`level'"!="" local displayopts `"`displayopts' level(`level')"'
    if "`dir'"!="" local displayopts `"`displayopts' dir"'
    if `"`eform'"'!="" local displayopts `"`displayopts' `eform'"'
    if trim(`"`options'"')!="" local displayopts `"`displayopts' `options'"'

    if "`cluster'"!="" & trim(`"`vce'"')!="" {
        di as err "specify only one of cluster() or vce()"
        exit 198
    }
    if "`cluster'"!="" & "`robust'"!="" {
        di as err "specify only one of cluster() or robust"
        exit 198
    }
    if trim(`"`vce'"')!="" & "`robust'"!="" {
        di as err "specify only one of vce() or robust"
        exit 198
    }

    local requested_cluster `"`cluster'"'
    if trim(`"`vce'"')!="" {
        local vcelower=ustrlower(itrim(trim(`"`vce'"')))
        if "`vcelower'"=="robust" local requested_cluster
        else if ustrregexm(`"`vcelower'"',"^cluster[ ]+([A-Za-z_][A-Za-z0-9_]*)$") {
            local requested_cluster `"`=ustrregexs(1)'"'
        }
        else if ustrregexm(`"`vcelower'"',"^cluster[ ]*\([ ]*([A-Za-z_][A-Za-z0-9_]*)[ ]*\)$") {
            local requested_cluster `"`=ustrregexs(1)'"'
        }
        else {
            di as err "the xtmlogit route supports only vce(robust) or vce(cluster varname)"
            exit 198
        }
    }

    est_expand `"`anything'"', min(2) default(.)
    local names `"`r(names)'"'
    local names : list uniq names
    local nmodels : word count `names'
    local hasdot : list posof "." in names
    if `hasdot' {
        di as err "xtmlogit support requires named stored estimates"
        di as err "store each model with {bf:estimates store} before running {bf:suest2}"
        exit 198
    }

    local panelvar
    local rc 0
    local errtext
    local anyfe 0
    local anyre 0
    local jointscores

    forvalues i=1/`nmodels' {
        local name : word `i' of `names'
        capture quietly estimates restore `name'
        if _rc {
            local rc=_rc
            local errtext "unable to restore constituent model `name'"
            continue, break
        }

        local isfe=("`e(cmd)'"=="xtmlogit" & "`e(model)'"=="fe")
        local isre=("`e(cmd)'"=="gsem" & "`e(cmd2)'"=="xtmlogit" & "`e(model)'"=="re")
        if !`isfe' & !`isre' {
            local rc 322
            local errtext "the first xtmlogit increment requires every constituent model to be xtmlogit, fe or xtmlogit, re"
            continue, break
        }
        if `isfe' local anyfe 1
        if `isre' local anyre 1

        if trim(`"`e(wtype)'"')!="" {
            local rc 198
            local errtext "weights are not yet supported for xtmlogit systems"
            continue, break
        }
        if trim(`"`e(prefix)'"')!="" {
            local rc 198
            local errtext "prefixed xtmlogit estimates are not yet supported"
            continue, break
        }
        if "`e(vce)'"!="oim" {
            local rc 198
            local errtext "store conventional OIM xtmlogit estimates and request robust or clustered VCE with suest2"
            continue, break
        }
        if `isfe' {
            capture confirm scalar e(rsample)
            if !_rc & e(rsample) {
                local rc 198
                local errtext "xtmlogit, fe estimates using rsample() are not yet supported"
                continue, break
            }
        }
        capture confirm scalar e(converged)
        if !_rc & !e(converged) {
            local rc 430
            local errtext "model `name' did not converge"
            continue, break
        }

        local ivar `"`e(ivar)'"'
        if trim(`"`ivar'"')=="" {
            local rc 498
            local errtext "model `name' does not retain its panel identifier in e(ivar)"
            continue, break
        }
        if `i'==1 local panelvar `"`ivar'"'
        else if `"`ivar'"'!=`"`panelvar'"' {
            local rc 459
            local errtext "all xtmlogit constituent models must use the same panel variable"
            continue, break
        }

        foreach object in b V out {
            capture confirm matrix e(`object')
            if _rc {
                local rc 498
                local errtext "model `name' does not retain e(`object')"
                continue, break
            }
        }
        if `rc' continue, break
        foreach scalar in N N_g rank k_out ibaseout {
            capture confirm scalar e(`scalar')
            if _rc {
                local rc 498
                local errtext "model `name' does not retain e(`scalar')"
                continue, break
            }
        }
        if `rc' continue, break

        tempname bsrc Vsrc omit
        matrix `bsrc'=e(b)
        matrix `Vsrc'=e(V)
        local bsrc`i' `bsrc'
        local Vsrc`i' `Vsrc'
        local K`i'=colsof(`bsrc')
        local rank`i'=e(rank)
        local N`i'=e(N)
        local Ng`i'=e(N_g)
        local model`i' `"`e(model)'"'
        local covariance`i' `"`e(covariance)'"'
        if `isfe' local covariance`i' "conditional"
        local baseout`i'=e(baseout)
        local ibaseout`i'=e(ibaseout)
        local k_out`i'=e(k_out)
        local depvar`i' `"`e(depvar)'"'
        local nativecn`i' : colnames `bsrc'
        local nativeeq`i' : coleq `bsrc'
        local nativeequniq`i' : list uniq nativeeq`i'

        tempvar sample
        quietly generate byte `sample'=e(sample)
        local sample`i' `sample'
        quietly count if `sample'
        if r(N)!=`N`i'' {
            local rc 459
            local errtext "the current data no longer reproduce the stored estimation sample for model `name'"
            continue, break
        }

        local scorelist
        forvalues j=1/`K`i'' {
            tempvar sc
            local scorelist `scorelist' `sc'
        }
        capture quietly predict double `scorelist' if `sample', scores
        if _rc {
            local rc=_rc
            local errtext "unable to generate complete native xtmlogit scores for model `name'"
            continue, break
        }
        local nscore : word count `scorelist'
        if `nscore'!=`K`i'' {
            local rc 498
            local errtext "model `name' did not generate one score variable per e(b) column"
            continue, break
        }

        local maxscore 0
        foreach sc of local scorelist {
            quietly summarize `sc' if `sample', meanonly
            local asum=abs(r(sum))
            if `asum'>`maxscore' local maxscore=`asum'
        }
        /*
        Do not reject constrained covariance parameterizations based on
        columnwise score sums. Identity and exchangeable structures retain
        duplicated/constrained variance columns whose raw individual sums
        need not be zero. The later model-specific native robust-block
        reproduction is the binding score-validity check.
        */
        local maxscore`i'=`maxscore'
        local scores`i' `"`scorelist'"'
    }

    if `rc' {
        di as err `"`errtext'"'
        exit `rc'
    }

    capture quietly xtset
    if _rc {
        local rc=_rc
        di as err "the current data must remain xtset for the stored xtmlogit models"
        exit `rc'
    }
    if `"`r(panelvar)'"'!=`"`panelvar'"' {
        di as err "the current xtset panel variable differs from stored e(ivar)={bf:`panelvar'}"
        exit 459
    }

    local scorevar `"`requested_cluster'"'
    if trim(`"`scorevar'"')=="" local scorevar `"`panelvar'"'
    capture confirm numeric variable `scorevar'
    if _rc {
        local rc=_rc
        di as err "cluster variable {bf:`scorevar'} must exist and be numeric"
        exit `rc'
    }

    tempvar union cmin cmax
    quietly generate byte `union'=0
    forvalues i=1/`nmodels' {
        quietly replace `union'=1 if `sample`i''
    }
    quietly count if `union' & missing(`scorevar')
    if r(N) {
        di as err "cluster variable {bf:`scorevar'} is missing in the union sample"
        exit 459
    }
    bysort `panelvar': egen double `cmin'=min(cond(`union',`scorevar',.))
    bysort `panelvar': egen double `cmax'=max(cond(`union',`scorevar',.))
    quietly count if `union' & `cmin'!=`cmax'
    if r(N) {
        di as err "panel variable {bf:`panelvar'} is not nested within cluster variable {bf:`scorevar'}"
        exit 459
    }

    tempvar tagcluster tagpanel
    quietly egen byte `tagcluster'=tag(`scorevar') if `union'
    quietly count if `tagcluster'
    local Gsys=r(N)
    if `Gsys'<2 {
        di as err "the xtmlogit system contains fewer than two clusters"
        exit 459
    }
    quietly egen byte `tagpanel'=tag(`panelvar') if `union'
    quietly count if `tagpanel'
    local Ngsys=r(N)
    quietly count if `union'
    local Nsys=r(N)

    tempname bout Vsys
    local eqused
    local expected 0
    local alleq
    local allcn

    forvalues i=1/`nmodels' {
        local name : word `i' of `names'
        local sysuniq
        local q 0
        foreach neq of local nativeequniq`i' {
            local ++q
            if `"`neq'"'=="/" local candidate=substr(strtoname("`name'_aux"),1,32)
            else local candidate=substr(strtoname("`name'_`neq'"),1,32)
            if trim(`"`candidate'"')=="" local candidate=substr("s2xm`i'_e`q'",1,32)
            local duplicate : list posof "`candidate'" in eqused
            if `duplicate' local candidate=substr("s2xm`i'_e`q'",1,32)
            local duplicate : list posof "`candidate'" in eqused
            if `duplicate' {
                di as err "suest2 could not construct unique xtmlogit equation names"
                exit 498
            }
            local sysuniq `sysuniq' `candidate'
            local eqused `eqused' `candidate'
        }
        local syseqnames`i' `"`sysuniq'"'

        local eqlist
        foreach neq of local nativeeq`i' {
            local pos : list posof "`neq'" in nativeequniq`i'
            local seq : word `pos' of `sysuniq'
            local eqlist `eqlist' `seq'
        }
        local allcn `allcn' `nativecn`i''
        local alleq `alleq' `eqlist'

        tempname bi Vi
        matrix `bi'=`bsrc`i''
        matrix `Vi'=`Vsrc`i''
        matrix coleq `bi'=`eqlist'
        matrix coleq `Vi'=`eqlist'
        matrix roweq `Vi'=`eqlist'
        if `i'==1 {
            matrix `bout'=`bi'
            matrix `Vsys'=`Vi'
        }
        else {
            local oldK=colsof(`Vsys')
            matrix `Vsys'=(`Vsys',J(`oldK',`K`i'',0)\J(`K`i'',`oldK',0),`Vi')
            matrix `bout'=`bout',`bi'
        }

        tempvar tagi
        quietly egen byte `tagi'=tag(`scorevar') if `sample`i''
        quietly count if `tagi'
        local G`i'=r(N)
        if `G`i''<2 {
            di as err "model {bf:`name'} contains fewer than two clusters"
            exit 459
        }
        local scale`i'=(`G`i''/(`G`i''-1))/(`Gsys'/(`Gsys'-1))

        foreach sc of local scores`i' {
            tempvar aligned
            quietly generate double `aligned'=`sc'*sqrt(`scale`i'') if `sample`i''
            quietly replace `aligned'=0 if `union' & missing(`aligned')
            local jointscores `jointscores' `aligned'
        }

        local expected=`expected'+`K`i''
    }

    matrix colnames `bout'=`allcn'
    matrix coleq `bout'=`alleq'
    matrix colnames `Vsys'=`allcn'
    matrix rownames `Vsys'=`allcn'
    matrix coleq `Vsys'=`alleq'
    matrix roweq `Vsys'=`alleq'

    if colsof(`bout')!=`expected' | colsof(`Vsys')!=`expected' {
        di as err "suest2 could not assemble the xtmlogit joint score system"
        exit 498
    }

    tempname bhelper Vhelper
    matrix `bhelper'=`bout'
    matrix `Vhelper'=`Vsys'
    tempvar helper
    quietly generate byte `helper'=`union'
    capture quietly suest2_xtmlogit_joint_robust, ///
        b(`bhelper') v(`Vhelper') sample(`helper') ///
        scores(`jointscores') cluster(`scorevar')
    if _rc {
        local rc=_rc
        di as err "unable to construct the xtmlogit joint covariance matrix"
        exit `rc'
    }

    tempname Vout Vmb Vt
    matrix `Vout'=e(V)
    matrix `Vmb'=e(V_modelbased)
    mata: st_numscalar("__s2_xtmlogit_breaddiff", ///
        max(abs(st_matrix("`Vsys'"):-st_matrix("`Vmb'"))))
    if scalar(__s2_xtmlogit_breaddiff)>1e-12 {
        di as err "the xtmlogit model-based covariance was not preserved"
        exit 498
    }
    matrix `Vt'=`Vout''
    matrix `Vout'=(`Vout'+`Vt')/2
    matrix colnames `Vout'=`allcn'
    matrix rownames `Vout'=`allcn'
    matrix coleq `Vout'=`alleq'
    matrix roweq `Vout'=`alleq'

    forvalues i=1/`nmodels' {
        local name : word `i' of `names'
        tempname Vblock Vtarget
        local start`i' 1
        if `i'>1 {
            local start`i' 1
            forvalues h=1/`=`i'-1' {
                local start`i'=`start`i''+`K`h''
            }
        }
        local end`i'=`start`i''+`K`i''-1
        matrix `Vblock'=`Vout'[`start`i''..`end`i'',`start`i''..`end`i'']

        quietly estimates restore `name'
        capture quietly suest2_xtmlogit_native_robust, cluster(`scorevar')
        if _rc {
            local rc=_rc
            di as err "unable to reproduce the model-specific xtmlogit covariance for model {bf:`name'}"
            exit `rc'
        }
        matrix `Vtarget'=e(V)
        mata: st_numscalar("__s2_xtmlogit_diagdiff", ///
            max(abs(st_matrix("`Vblock'"):-st_matrix("`Vtarget'"))))
        mata: st_numscalar("__s2_xtmlogit_diagscale", ///
            1+max(abs(st_matrix("`Vtarget'"))))
        if scalar(__s2_xtmlogit_diagdiff)>1e-7*scalar(__s2_xtmlogit_diagscale) {
            di as err "the joint xtmlogit covariance does not reproduce the model-specific block for model {bf:`name'}"
            exit 498
        }
    }

    tempname omitall Vfv Vrestore Hxm
    quietly _ms_omit_info `bout'
    matrix `omitall'=r(omit)
    local Kout=colsof(`bout')
    matrix `Vfv'=I(`Kout')
    matrix colnames `Vfv'=`allcn'
    matrix rownames `Vfv'=`allcn'
    matrix coleq `Vfv'=`alleq'
    matrix roweq `Vfv'=`alleq'
    forvalues j=1/`Kout' {
        if `omitall'[1,`j'] matrix `Vfv'[`j',`j']=0
    }

    tempname bfinal
    matrix `bfinal'=`bout'
    matrix `Vrestore'=`Vout'
    ereturn post `bfinal' `Vout', obs(`Nsys') esample(`union')
    capture quietly ereturn repost V=`Vfv', buildfvinfo
    local hrc=_rc
    if !`hrc' {
        capture quietly _get_hmat `Hxm'
        local hrc=_rc
        if !`hrc' local hrc=r(rc)
    }
    capture quietly ereturn repost V=`Vrestore'
    if `hrc' {
        di as err "suest2 could not construct xtmlogit factor-variable information"
        exit 498
    }

    ereturn matrix suest2_xtmlogit_H=`Hxm', copy
    mata: st_numscalar("__s2_xtmlogit_rank",rank(st_matrix("`Vrestore'")))
    ereturn scalar rank=scalar(__s2_xtmlogit_rank)
    ereturn scalar N_clust=`Gsys'
    ereturn scalar N_g=`Ngsys'
    ereturn local clustvar `"`scorevar'"'
    ereturn local vce "cluster"
    ereturn local vcetype "Robust"
    ereturn local method "ML"
    ereturn local names `"`names'"'
    ereturn local properties "b V"
    ereturn scalar suest2_xtmlogit=1
    ereturn scalar suest2_xtmlogit_any_fe=`anyfe'
    ereturn scalar suest2_xtmlogit_any_re=`anyre'
    ereturn local suest2_xtmlogit_panelvar `"`panelvar'"'
    ereturn local suest2_xtmlogit_scorevar `"`scorevar'"'
    ereturn local suest2_xtmlogit_engine "native_complete_parameter_scores_allcons"
    ereturn local suest2_xtmlogit_displayopts `"`displayopts'"'
    ereturn local title "Simultaneous panel multinomial-logit results"
    ereturn local cmd "suest2_xtmlogit"

    forvalues i=1/`nmodels' {
        ereturn local eqnames`i' `"`syseqnames`i''"'
        ereturn scalar suest2_xtmlogit_N`i'=`N`i''
        ereturn scalar suest2_xtmlogit_Npanel`i'=`Ng`i''
        ereturn scalar suest2_xtmlogit_G`i'=`G`i''
        ereturn scalar suest2_xtmlogit_K`i'=`K`i''
        ereturn scalar suest2_xtmlogit_rank`i'=`rank`i''
        ereturn scalar suest2_xtmlogit_baseout`i'=`baseout`i''
        ereturn scalar suest2_xtmlogit_ibaseout`i'=`ibaseout`i''
        ereturn scalar suest2_xtmlogit_k_out`i'=`k_out`i''
        ereturn scalar suest2_xtmlogit_score_maxabs`i'=`maxscore`i''
        ereturn scalar suest2_xtmlogit_scale`i'=`scale`i''
        ereturn local suest2_xtmlogit_model`i' `"`model`i''"'
        ereturn local suest2_xtmlogit_covariance`i' `"`covariance`i''"'
    }
end

program define suest2_xnbr_joint_robust, eclass
    version 9
    syntax, B(name) V(name) SAMPLE(varname) SCORES(varlist) CLUSTER(varname)
    ereturn post `b' `v', esample(`sample')
    ereturn local cmd "suest2_xtnbregre_joint"
    ereturn local properties "b V"
    _robust2 `scores' if e(sample), cluster(`cluster') allcons
end

program define suest2_xtnbregreestimate, sortpreserve eclass
    version 16
    syntax [anything] [, CLuster(varname) VCE(string asis) Robust MINUS ///
        REGRESSML SVY Level(cilevel) DIR EForm(passthru) *]

    if "`minus'`regressml'`svy'"!="" {
        di as err "options minus, regressml, and svy are not supported for beta xtnbreg, re systems"
        exit 198
    }

    local displayopts
    if "`level'"!="" local displayopts `"`displayopts' level(`level')"'
    if "`dir'"!="" local displayopts `"`displayopts' dir"'
    if `"`eform'"'!="" local displayopts `"`displayopts' `eform'"'
    if trim(`"`options'"')!="" local displayopts `"`displayopts' `options'"'

    if "`cluster'"!="" & trim(`"`vce'"')!="" {
        di as err "specify only one of cluster() or vce()"
        exit 198
    }
    if "`cluster'"!="" & "`robust'"!="" {
        di as err "specify only one of cluster() or robust"
        exit 198
    }
    if trim(`"`vce'"')!="" & "`robust'"!="" {
        di as err "specify only one of vce() or robust"
        exit 198
    }

    local requested_cluster `"`cluster'"'
    if trim(`"`vce'"')!="" {
        local vcelower=ustrlower(itrim(trim(`"`vce'"')))
        if "`vcelower'"=="robust" local requested_cluster
        else if ustrregexm(`"`vcelower'"',"^cluster[ ]+([A-Za-z_][A-Za-z0-9_]*)$") {
            local requested_cluster `"`=ustrregexs(1)'"'
        }
        else if ustrregexm(`"`vcelower'"',"^cluster[ ]*\([ ]*([A-Za-z_][A-Za-z0-9_]*)[ ]*\)$") {
            local requested_cluster `"`=ustrregexs(1)'"'
        }
        else {
            di as err "the beta xtnbreg, re route supports only vce(robust) or vce(cluster varname)"
            exit 198
        }
    }

    est_expand `"`anything'"', min(2) default(.)
    local names `"`r(names)'"'
    local names : list uniq names
    local nmodels : word count `names'
    local hasdot : list posof "." in names
    if `hasdot' {
        di as err "beta xtnbreg, re support requires named stored estimates"
        di as err "store each model with {bf:estimates store} before running {bf:suest2}"
        exit 198
    }

    local panelvar
    local scorevar
    local rc 0
    local errtext

    forvalues i=1/`nmodels' {
        local name : word `i' of `names'
        capture quietly estimates restore `name'
        if _rc {
            local rc=_rc
            local errtext "unable to restore constituent model `name'"
            continue, break
        }
        if "`e(cmd)'"!="xtnbreg" | "`e(model)'"!="re" | ///
            lower(trim(`"`e(distrib)'"'))!="beta" {
            local rc 322
            local errtext "the first beta xtnbreg, re increment requires every constituent model to be beta xtnbreg, re"
            continue, break
        }
        if trim(`"`e(wtype)'"')!="" {
            local rc 198
            local errtext "weights are not yet supported for beta xtnbreg, re systems"
            continue, break
        }
        if trim(`"`e(prefix)'"')!="" {
            local rc 198
            local errtext "prefixed beta xtnbreg, re estimates are not yet supported"
            continue, break
        }
        if "`e(vce)'"!="oim" {
            local rc 198
            local errtext "store conventional beta xtnbreg, re estimates and request robust or clustered VCE with suest2"
            continue, break
        }

        local ivar `"`e(ivar)'"'
        if trim(`"`ivar'"')=="" {
            local rc 498
            local errtext "model `name' does not retain its panel identifier in e(ivar)"
            continue, break
        }
        if `i'==1 local panelvar `"`ivar'"'
        else if `"`ivar'"'!=`"`panelvar'"' {
            local rc 459
            local errtext "all beta xtnbreg, re constituent models must use the same panel variable"
            continue, break
        }

        capture confirm matrix e(b)
        if _rc {
            local rc=_rc
            local errtext "model `name' does not contain e(b)"
            continue, break
        }
        capture confirm matrix e(V)
        if _rc {
            local rc=_rc
            local errtext "model `name' does not contain e(V)"
            continue, break
        }
        capture confirm scalar e(rank)
        if _rc {
            local rc 498
            local errtext "model `name' does not retain e(rank)"
            continue, break
        }
        if e(rank)<3 {
            local rc 498
            local errtext "model `name' has no estimable beta random-effects negative-binomial coefficients"
            continue, break
        }

        tempname bsrc Vsrc omit
        matrix `bsrc'=e(b)
        matrix `Vsrc'=e(V)
        local bsrc`i' `bsrc'
        local Vsrc`i' `Vsrc'
        local korig`i'=colsof(`bsrc')
        local rank`i'=e(rank)
        local N`i'=e(N)
        local depvar`i' `"`e(depvar)'"'

        tempvar sample samplekeep xb
        quietly generate byte `sample'=e(sample)
        quietly generate byte `samplekeep'=`sample'
        local sample`i' `samplekeep'
        quietly count if `sample'
        if r(N)!=`N`i'' {
            local rc 459
            local errtext "the current data no longer reproduce the stored estimation sample for model `name'"
            continue, break
        }

        capture quietly predict double `xb' if `sample', xb
        if _rc {
            local rc=_rc
            local errtext "unable to reproduce the native linear prediction for model `name'"
            continue, break
        }
        local xb`i' `xb'

        quietly _ms_omit_info `bsrc'
        matrix `omit'=r(omit)
        local cnames : colnames `bsrc'
        local ceqs : coleq `bsrc'
        local xvars
        local scores
        local p 0
        local ancr 0
        local ancs 0

        forvalues j=1/`korig`i'' {
            local coef : word `j' of `cnames'
            tempvar xj sj
            quietly generate double `xj'=0 if `sample'
            quietly generate double `sj'=.

            if `"`coef'"'=="ln_r" {
                if `ancr' {
                    local rc 498
                    local errtext "model `name' contains more than one /ln_r parameter"
                    continue, break
                }
                local ancr=`j'
            }
            else if `"`coef'"'=="ln_s" {
                if `ancs' {
                    local rc 498
                    local errtext "model `name' contains more than one /ln_s parameter"
                    continue, break
                }
                local ancs=`j'
            }
            else if !`omit'[1,`j'] {
                if `"`coef'"'=="_cons" {
                    quietly replace `xj'=1 if `sample'
                }
                else {
                    capture quietly fvrevar `coef'
                    if _rc {
                        local rc=_rc
                        local errtext "unable to reconstruct design column `coef' for model `name'"
                        continue, break
                    }
                    local raw `"`r(varlist)'"'
                    local nraw : word count `raw'
                    if `nraw'!=1 {
                        local rc 498
                        local errtext "design column `coef' did not expand to exactly one variable for model `name'"
                        continue, break
                    }
                    quietly count if `sample' & missing(`raw')
                    if r(N) {
                        local rc 459
                        local errtext "design column `coef' is missing inside the stored sample for model `name'"
                        continue, break
                    }
                    quietly replace `xj'=`raw' if `sample'
                }
                local ++p
            }

            local xvars `xvars' `xj'
            local scores `scores' `sj'
        }
        if `rc' continue, break
        if !`ancr' | !`ancs' {
            local rc 498
            local errtext "model `name' does not retain both /ln_r and /ln_s in e(b)"
            continue, break
        }
        if `ancr'==`ancs' {
            local rc 498
            local errtext "model `name' retains an invalid beta ancillary layout"
            continue, break
        }
        if `p'+2!=`rank`i'' {
            local rc 498
            local errtext "the reconstructed beta xtnbreg, re design rank differs from model `name'"
            continue, break
        }

        local ancr`i'=`ancr'
        local ancs`i'=`ancs'
        local lnr`i'=`bsrc'[1,`ancr']
        local lns`i'=`bsrc'[1,`ancs']
        local xvars`i' `"`xvars'"'
        local scores`i' `"`scores'"'
    }

    if `rc' {
        di as err `"`errtext'"'
        exit `rc'
    }

    capture quietly xtset
    if _rc {
        local rc=_rc
        di as err "the current data must remain xtset for the stored beta xtnbreg, re models"
        exit `rc'
    }
    if `"`r(panelvar)'"'!=`"`panelvar'"' {
        di as err "the current xtset panel variable differs from stored e(ivar)={bf:`panelvar'}"
        exit 459
    }

    if trim(`"`requested_cluster'"')=="" local scorevar `"`panelvar'"'
    else local scorevar `"`requested_cluster'"'
    capture confirm numeric variable `scorevar'
    if _rc {
        local rc=_rc
        di as err "cluster variable {bf:`scorevar'} must be numeric"
        exit `rc'
    }

    tempvar union cmin cmax
    quietly generate byte `union'=0
    forvalues i=1/`nmodels' {
        quietly replace `union'=1 if `sample`i''
    }
    quietly count if `union' & missing(`scorevar')
    if r(N) {
        di as err "cluster variable {bf:`scorevar'} is missing in the union sample"
        exit 459
    }
    bysort `panelvar': egen double `cmin'=min(cond(`union',`scorevar',.))
    bysort `panelvar': egen double `cmax'=max(cond(`union',`scorevar',.))
    quietly count if `union' & `cmin'!=`cmax'
    if r(N) {
        di as err "panel variable {bf:`panelvar'} is not nested within cluster variable {bf:`scorevar'}"
        exit 459
    }

    forvalues i=1/`nmodels' {
        capture noisily mata: suest2_xnbr_scores_mata( ///
            "`depvar`i''","`xb`i''","`panelvar'","`sample`i''", ///
            "`xvars`i''","`scores`i''",`lnr`i'',`lns`i'', ///
            `ancr`i'',`ancs`i'')
        if _rc {
            local rc=_rc
            local name : word `i' of `names'
            local errtext "unable to reconstruct beta-integrated panel scores for model `name'"
            continue, break
        }

        local maxscore 0
        foreach sj of local scores`i' {
            quietly summarize `sj' if `sample`i'', meanonly
            local sabs=abs(r(sum))
            if `sabs'>`maxscore' local maxscore=`sabs'
        }
        local maxscore`i'=`maxscore'

        tempvar tagcluster
        quietly egen byte `tagcluster'=tag(`scorevar') if `sample`i''
        quietly count if `tagcluster'
        local G`i'=r(N)
        if `G`i''<2 {
            local name : word `i' of `names'
            local rc 459
            local errtext "model `name' contains fewer than two clusters in {bf:`scorevar'}"
            continue, break
        }
    }

    if `rc' {
        di as err `"`errtext'"'
        exit `rc'
    }

    tempname bout Vsys
    local eqused
    local jointscores
    local expected 0

    forvalues i=1/`nmodels' {
        local name : word `i' of `names'
        local eq=substr(strtoname("`name'_`depvar`i''"),1,32)
        local duplicate : list posof "`eq'" in eqused
        if `duplicate' {
            local suffix="_p`i'"
            local room=32-strlen("`suffix'")
            local eq=substr(strtoname("`name'"),1,`room')+"`suffix'"
        }
        local eqused `"`eqused' `eq'"'
        local eqname`i' `"`eq'"'

        tempname bi Vi
        matrix `bi'=`bsrc`i''
        matrix `Vi'=`Vsrc`i''
        local eqlist
        forvalues j=1/`korig`i'' {
            local eqlist `"`eqlist' `eq'"'
        }
        matrix coleq `bi'=`eqlist'
        matrix coleq `Vi'=`eqlist'
        matrix roweq `Vi'=`eqlist'

        if `i'==1 {
            matrix `bout'=`bi'
            matrix `Vsys'=`Vi'
        }
        else {
            local oldK=colsof(`Vsys')
            matrix `Vsys'=(`Vsys',J(`oldK',`korig`i'',0)\J(`korig`i'',`oldK',0),`Vi')
            matrix `bout'=`bout',`bi'
        }

        foreach s of local scores`i' {
            quietly replace `s'=0 if `union' & missing(`s')
            local jointscores `jointscores' `s'
        }
        local expected=`expected'+`korig`i''
    }

    if colsof(`bout')!=`expected' | colsof(`Vsys')!=`expected' {
        di as err "suest2 could not assemble the beta xtnbreg, re joint score system"
        exit 498
    }

    local bcn : colnames `bout'
    local beq : coleq `bout'
    matrix colnames `Vsys'=`bcn'
    matrix rownames `Vsys'=`bcn'
    matrix coleq `Vsys'=`beq'
    matrix roweq `Vsys'=`beq'

    local vcn : colnames `Vsys'
    local vrn : rownames `Vsys'
    local veq : coleq `Vsys'
    local vreq : roweq `Vsys'
    if `"`vcn'"'!=`"`bcn'"' | `"`vrn'"'!=`"`bcn'"' | ///
        `"`veq'"'!=`"`beq'"' | `"`vreq'"'!=`"`beq'"' {
        di as err "the beta xtnbreg, re joint covariance stripe does not match the coefficient stripe"
        exit 498
    }

    tempname bhelper Vhelper
    matrix `bhelper'=`bout'
    matrix `Vhelper'=`Vsys'

    tempvar helper
    quietly generate byte `helper'=`union'
    capture quietly suest2_xnbr_joint_robust, ///
        b(`bhelper') v(`Vhelper') sample(`helper') ///
        scores(`jointscores') cluster(`scorevar')
    local rc=_rc
    if `rc' {
        di as err "unable to construct the beta xtnbreg, re joint covariance matrix"
        exit `rc'
    }

    tempname Vout Vmb
    matrix `Vout'=e(V)
    matrix `Vmb'=e(V_modelbased)
    local Nsys=e(N)
    local Gsys=e(N_clust)

    mata: st_numscalar("__s2_xnbr_breaddiff",max(abs(st_matrix("`Vsys'"):-st_matrix("`Vmb'"))))
    if scalar(__s2_xnbr_breaddiff)>1e-12 {
        di as err "the beta xtnbreg, re model-based covariance was not preserved"
        exit 498
    }

    tempname Vt
    matrix `Vt'=`Vout''
    matrix `Vout'=(`Vout'+`Vt')/2
    matrix colnames `Vout'=`bcn'
    matrix rownames `Vout'=`bcn'
    matrix coleq `Vout'=`beq'
    matrix roweq `Vout'=`beq'

    tempname omitall Vfv Vrestore Hxnbr
    quietly _ms_omit_info `bout'
    matrix `omitall'=r(omit)
    local Kout=colsof(`bout')
    matrix `Vfv'=I(`Kout')
    matrix colnames `Vfv'=`bcn'
    matrix rownames `Vfv'=`bcn'
    matrix coleq `Vfv'=`beq'
    matrix roweq `Vfv'=`beq'
    forvalues j=1/`Kout' {
        if `omitall'[1,`j'] matrix `Vfv'[`j',`j']=0
    }

    tempvar tagpanel
    quietly egen byte `tagpanel'=tag(`panelvar') if `union'
    quietly count if `tagpanel'
    local Ngsys=r(N)

    matrix `Vrestore'=`Vout'
    ereturn post `bout' `Vout', obs(`Nsys') esample(`union')
    ereturn local cmd "suest"
    ereturn local names `"`names'"'
    forvalues i=1/`nmodels' {
        ereturn local eqnames`i' `"`eqname`i''"'
    }

    capture quietly ereturn repost V=`Vfv', buildfvinfo
    local hrc=_rc
    if !`hrc' {
        capture quietly _get_hmat `Hxnbr'
        local hrc=_rc
        if !`hrc' local hrc=r(rc)
    }
    capture quietly ereturn repost V=`Vrestore'
    if `hrc' {
        di as err "suest2 could not construct factor-variable estimability information for the beta xtnbreg, re system"
        exit 498
    }

    ereturn matrix suest2_xnbr_H=`Hxnbr', copy
    mata: st_numscalar("__s2_xnbr_rank",rank(st_matrix("`Vout'")))
    ereturn scalar rank=scalar(__s2_xnbr_rank)
    ereturn scalar N_clust=`Gsys'
    ereturn scalar N_g=`Ngsys'
    ereturn local clustvar `"`scorevar'"'
    ereturn local vce "cluster"
    ereturn local vcetype "Robust"
    ereturn local names `"`names'"'
    ereturn local properties "b V"
    ereturn scalar suest2_xtnbregre=1
    ereturn scalar suest2_xtnbreg_re=1
    ereturn local suest2_xnbr_panelvar `"`panelvar'"'
    ereturn local suest2_xnbr_scorevar `"`scorevar'"'
    ereturn local suest2_xnbr_engine ///
        "analytic_beta_integrated_panel_scores_robust2"
    ereturn local suest2_xnbr_displayopts `"`displayopts'"'
    ereturn local title "Simultaneous beta random-effects negative-binomial results"
    ereturn local cmd "suest2_xtnbregre"

    forvalues i=1/`nmodels' {
        ereturn local eqnames`i' `"`eqname`i''"'
        ereturn scalar suest2_xnbr_N`i'=`N`i''
        ereturn scalar suest2_xnbr_G`i'=`G`i''
        ereturn scalar suest2_xnbr_K`i'=`korig`i''
        ereturn scalar suest2_xnbr_rank`i'=`rank`i''
        ereturn scalar suest2_xnbr_ancr`i'=`ancr`i''
        ereturn scalar suest2_xnbr_ancs`i'=`ancs`i''
        ereturn scalar suest2_xnbr_summax`i'=`maxscore`i''
    }
end

program define suest2_xpgr_joint_robust, eclass
    version 9
    syntax, B(name) V(name) SAMPLE(varname) SCORES(varlist) CLUSTER(varname)
    ereturn post `b' `v', esample(`sample')
    ereturn local cmd "suest2_xtpoissonregamma_joint"
    ereturn local properties "b V"
    _robust2 `scores' if e(sample), cluster(`cluster') allcons
end

program define suest2_xtpoissonregammaestimate, sortpreserve eclass
    version 16
    syntax [anything] [, CLuster(varname) VCE(string asis) Robust MINUS ///
        REGRESSML SVY Level(cilevel) DIR EForm(passthru) *]

    if "`minus'`regressml'`svy'"!="" {
        di as err "options minus, regressml, and svy are not supported for gamma xtpoisson, re systems"
        exit 198
    }

    local displayopts
    if "`level'"!="" local displayopts `"`displayopts' level(`level')"'
    if "`dir'"!="" local displayopts `"`displayopts' dir"'
    if `"`eform'"'!="" local displayopts `"`displayopts' `eform'"'
    if trim(`"`options'"')!="" local displayopts `"`displayopts' `options'"'

    if "`cluster'"!="" & trim(`"`vce'"')!="" {
        di as err "specify only one of cluster() or vce()"
        exit 198
    }
    if "`cluster'"!="" & "`robust'"!="" {
        di as err "specify only one of cluster() or robust"
        exit 198
    }
    if trim(`"`vce'"')!="" & "`robust'"!="" {
        di as err "specify only one of vce() or robust"
        exit 198
    }

    local requested_cluster `"`cluster'"'
    if trim(`"`vce'"')!="" {
        local vcelower=ustrlower(itrim(trim(`"`vce'"')))
        if "`vcelower'"=="robust" local requested_cluster
        else if ustrregexm(`"`vcelower'"',"^cluster[ ]+([A-Za-z_][A-Za-z0-9_]*)$") {
            local requested_cluster `"`=ustrregexs(1)'"'
        }
        else if ustrregexm(`"`vcelower'"',"^cluster[ ]*\([ ]*([A-Za-z_][A-Za-z0-9_]*)[ ]*\)$") {
            local requested_cluster `"`=ustrregexs(1)'"'
        }
        else {
            di as err "the gamma xtpoisson, re route supports only vce(robust) or vce(cluster varname)"
            exit 198
        }
    }

    est_expand `"`anything'"', min(2) default(.)
    local names `"`r(names)'"'
    local names : list uniq names
    local nmodels : word count `names'
    local hasdot : list posof "." in names
    if `hasdot' {
        di as err "gamma xtpoisson, re support requires named stored estimates"
        di as err "store each model with {bf:estimates store} before running {bf:suest2}"
        exit 198
    }

    local panelvar
    local scorevar
    local rc 0
    local errtext

    forvalues i=1/`nmodels' {
        local name : word `i' of `names'
        capture quietly estimates restore `name'
        if _rc {
            local rc=_rc
            local errtext "unable to restore constituent model `name'"
            continue, break
        }
        if "`e(cmd)'"!="xtpoisson" | "`e(model)'"!="re" | ///
            lower(trim(`"`e(distrib)'"'))!="gamma" {
            local rc 322
            local errtext "the first gamma xtpoisson, re increment requires every constituent model to be gamma xtpoisson, re"
            continue, break
        }
        if trim(`"`e(wtype)'"')!="" {
            local rc 198
            local errtext "weights are not yet supported for gamma xtpoisson, re systems"
            continue, break
        }
        if trim(`"`e(prefix)'"')!="" {
            local rc 198
            local errtext "prefixed gamma xtpoisson, re estimates are not yet supported"
            continue, break
        }
        if "`e(vce)'"!="oim" {
            local rc 198
            local errtext "store conventional gamma xtpoisson, re estimates and request robust or clustered VCE with suest2"
            continue, break
        }

        local ivar `"`e(ivar)'"'
        if trim(`"`ivar'"')=="" {
            local rc 498
            local errtext "model `name' does not retain its panel identifier in e(ivar)"
            continue, break
        }
        if `i'==1 local panelvar `"`ivar'"'
        else if `"`ivar'"'!=`"`panelvar'"' {
            local rc 459
            local errtext "all gamma xtpoisson, re constituent models must use the same panel variable"
            continue, break
        }

        capture confirm matrix e(b)
        if _rc {
            local rc=_rc
            local errtext "model `name' does not contain e(b)"
            continue, break
        }
        capture confirm matrix e(V)
        if _rc {
            local rc=_rc
            local errtext "model `name' does not contain e(V)"
            continue, break
        }
        capture confirm scalar e(rank)
        if _rc {
            local rc 498
            local errtext "model `name' does not retain e(rank)"
            continue, break
        }
        if e(rank)<2 {
            local rc 498
            local errtext "model `name' has no estimable gamma random-effects Poisson coefficients"
            continue, break
        }

        tempname bsrc Vsrc omit
        matrix `bsrc'=e(b)
        matrix `Vsrc'=e(V)
        local bsrc`i' `bsrc'
        local Vsrc`i' `Vsrc'
        local korig`i'=colsof(`bsrc')
        local rank`i'=e(rank)
        local N`i'=e(N)
        local depvar`i' `"`e(depvar)'"'

        tempvar sample samplekeep xb
        quietly generate byte `sample'=e(sample)
        quietly generate byte `samplekeep'=`sample'
        local sample`i' `samplekeep'
        quietly count if `sample'
        if r(N)!=`N`i'' {
            local rc 459
            local errtext "the current data no longer reproduce the stored estimation sample for model `name'"
            continue, break
        }

        capture quietly predict double `xb' if `sample', xb
        if _rc {
            local rc=_rc
            local errtext "unable to reproduce the native linear prediction for model `name'"
            continue, break
        }
        local xb`i' `xb'

        quietly _ms_omit_info `bsrc'
        matrix `omit'=r(omit)
        local cnames : colnames `bsrc'
        local ceqs : coleq `bsrc'
        local xvars
        local scores
        local p 0
        local anc 0

        forvalues j=1/`korig`i'' {
            local coef : word `j' of `cnames'
            local ceq : word `j' of `ceqs'
            tempvar xj sj
            quietly generate double `xj'=0 if `sample'
            quietly generate double `sj'=.

            if `"`coef'"'=="lnalpha" | `"`ceq'"'=="/" {
                if `anc' {
                    local rc 498
                    local errtext "model `name' contains more than one ancillary gamma parameter"
                    continue, break
                }
                local anc=`j'
            }
            else if !`omit'[1,`j'] {
                if `"`coef'"'=="_cons" {
                    quietly replace `xj'=1 if `sample'
                }
                else {
                    capture quietly fvrevar `coef'
                    if _rc {
                        local rc=_rc
                        local errtext "unable to reconstruct design column `coef' for model `name'"
                        continue, break
                    }
                    local raw `"`r(varlist)'"'
                    local nraw : word count `raw'
                    if `nraw'!=1 {
                        local rc 498
                        local errtext "design column `coef' did not expand to exactly one variable for model `name'"
                        continue, break
                    }
                    quietly count if `sample' & missing(`raw')
                    if r(N) {
                        local rc 459
                        local errtext "design column `coef' is missing inside the stored sample for model `name'"
                        continue, break
                    }
                    quietly replace `xj'=`raw' if `sample'
                }
                local ++p
            }

            local xvars `xvars' `xj'
            local scores `scores' `sj'
        }
        if `rc' continue, break
        if !`anc' {
            local rc 498
            local errtext "model `name' does not retain /lnalpha in e(b)"
            continue, break
        }
        if `p'+1!=`rank`i'' {
            local rc 498
            local errtext "the reconstructed gamma xtpoisson, re design rank differs from model `name'"
            continue, break
        }

        local anc`i'=`anc'
        local lnalpha`i'=`bsrc'[1,`anc']
        local xvars`i' `"`xvars'"'
        local scores`i' `"`scores'"'
    }

    if `rc' {
        di as err `"`errtext'"'
        exit `rc'
    }

    capture quietly xtset
    if _rc {
        local rc=_rc
        di as err "the current data must remain xtset for the stored gamma xtpoisson, re models"
        exit `rc'
    }
    if `"`r(panelvar)'"'!=`"`panelvar'"' {
        di as err "the current xtset panel variable differs from stored e(ivar)={bf:`panelvar'}"
        exit 459
    }

    if trim(`"`requested_cluster'"')=="" local scorevar `"`panelvar'"'
    else local scorevar `"`requested_cluster'"'
    capture confirm numeric variable `scorevar'
    if _rc {
        local rc=_rc
        di as err "cluster variable {bf:`scorevar'} must be numeric"
        exit `rc'
    }

    tempvar union cmin cmax
    quietly generate byte `union'=0
    forvalues i=1/`nmodels' {
        quietly replace `union'=1 if `sample`i''
    }
    quietly count if `union' & missing(`scorevar')
    if r(N) {
        di as err "cluster variable {bf:`scorevar'} is missing in the union sample"
        exit 459
    }
    bysort `panelvar': egen double `cmin'=min(cond(`union',`scorevar',.))
    bysort `panelvar': egen double `cmax'=max(cond(`union',`scorevar',.))
    quietly count if `union' & `cmin'!=`cmax'
    if r(N) {
        di as err "panel variable {bf:`panelvar'} is not nested within cluster variable {bf:`scorevar'}"
        exit 459
    }

    forvalues i=1/`nmodels' {
        capture noisily mata: suest2_xpgr_scores_mata( ///
            "`depvar`i''","`xb`i''","`scorevar'","`sample`i''", ///
            "`xvars`i''","`scores`i''",`lnalpha`i'',`anc`i'')
        if _rc {
            local rc=_rc
            local name : word `i' of `names'
            local errtext "unable to reconstruct gamma-integrated cluster scores for model `name'"
            continue, break
        }

        local maxscore 0
        foreach sj of local scores`i' {
            quietly summarize `sj' if `sample`i'', meanonly
            local sabs=abs(r(sum))
            if `sabs'>`maxscore' local maxscore=`sabs'
        }
        local maxscore`i'=`maxscore'

        tempvar tagcluster
        quietly egen byte `tagcluster'=tag(`scorevar') if `sample`i''
        quietly count if `tagcluster'
        local G`i'=r(N)
        if `G`i''<2 {
            local name : word `i' of `names'
            local rc 459
            local errtext "model `name' contains fewer than two clusters in {bf:`scorevar'}"
            continue, break
        }
    }

    if `rc' {
        di as err `"`errtext'"'
        exit `rc'
    }

    tempname bout Vsys
    local eqused
    local jointscores
    local expected 0

    forvalues i=1/`nmodels' {
        local name : word `i' of `names'
        local eq=substr(strtoname("`name'_`depvar`i''"),1,32)
        local duplicate : list posof "`eq'" in eqused
        if `duplicate' {
            local suffix="_p`i'"
            local room=32-strlen("`suffix'")
            local eq=substr(strtoname("`name'"),1,`room')+"`suffix'"
        }
        local eqused `"`eqused' `eq'"'
        local eqname`i' `"`eq'"'

        tempname bi Vi
        matrix `bi'=`bsrc`i''
        matrix `Vi'=`Vsrc`i''
        local eqlist
        forvalues j=1/`korig`i'' {
            local eqlist `"`eqlist' `eq'"'
        }
        matrix coleq `bi'=`eqlist'
        matrix coleq `Vi'=`eqlist'
        matrix roweq `Vi'=`eqlist'

        if `i'==1 {
            matrix `bout'=`bi'
            matrix `Vsys'=`Vi'
        }
        else {
            local oldK=colsof(`Vsys')
            matrix `Vsys'=(`Vsys',J(`oldK',`korig`i'',0)\J(`korig`i'',`oldK',0),`Vi')
            matrix `bout'=`bout',`bi'
        }

        foreach s of local scores`i' {
            quietly replace `s'=0 if `union' & missing(`s')
            local jointscores `jointscores' `s'
        }
        local expected=`expected'+`korig`i''
    }

    if colsof(`bout')!=`expected' | colsof(`Vsys')!=`expected' {
        di as err "suest2 could not assemble the gamma xtpoisson, re joint score system"
        exit 498
    }

    local bcn : colnames `bout'
    local beq : coleq `bout'
    matrix colnames `Vsys'=`bcn'
    matrix rownames `Vsys'=`bcn'
    matrix coleq `Vsys'=`beq'
    matrix roweq `Vsys'=`beq'

    local vcn : colnames `Vsys'
    local vrn : rownames `Vsys'
    local veq : coleq `Vsys'
    local vreq : roweq `Vsys'
    if `"`vcn'"'!=`"`bcn'"' | `"`vrn'"'!=`"`bcn'"' | ///
        `"`veq'"'!=`"`beq'"' | `"`vreq'"'!=`"`beq'"' {
        di as err "the gamma xtpoisson, re joint covariance stripe does not match the coefficient stripe"
        exit 498
    }

    tempname bhelper Vhelper
    matrix `bhelper'=`bout'
    matrix `Vhelper'=`Vsys'

    tempvar helper
    quietly generate byte `helper'=`union'
    capture quietly suest2_xpgr_joint_robust, ///
        b(`bhelper') v(`Vhelper') sample(`helper') ///
        scores(`jointscores') cluster(`scorevar')
    local rc=_rc
    if `rc' {
        di as err "unable to construct the gamma xtpoisson, re joint covariance matrix"
        exit `rc'
    }

    tempname Vout Vmb
    matrix `Vout'=e(V)
    matrix `Vmb'=e(V_modelbased)
    local Nsys=e(N)
    local Gsys=e(N_clust)
    matrix `Vout'=((`Gsys'-1)/`Gsys')*`Vout'

    mata: st_numscalar("__s2_xpgr_breaddiff",max(abs(st_matrix("`Vsys'"):-st_matrix("`Vmb'"))))
    if scalar(__s2_xpgr_breaddiff)>1e-12 {
        di as err "the gamma xtpoisson, re model-based covariance was not preserved"
        exit 498
    }

    tempname Vt
    matrix `Vt'=`Vout''
    matrix `Vout'=(`Vout'+`Vt')/2
    matrix colnames `Vout'=`bcn'
    matrix rownames `Vout'=`bcn'
    matrix coleq `Vout'=`beq'
    matrix roweq `Vout'=`beq'

    tempname omitall Vfv Vrestore Hxpgr
    quietly _ms_omit_info `bout'
    matrix `omitall'=r(omit)
    local Kout=colsof(`bout')
    matrix `Vfv'=I(`Kout')
    matrix colnames `Vfv'=`bcn'
    matrix rownames `Vfv'=`bcn'
    matrix coleq `Vfv'=`beq'
    matrix roweq `Vfv'=`beq'
    forvalues j=1/`Kout' {
        if `omitall'[1,`j'] matrix `Vfv'[`j',`j']=0
    }

    tempvar tagpanel
    quietly egen byte `tagpanel'=tag(`panelvar') if `union'
    quietly count if `tagpanel'
    local Ngsys=r(N)

    matrix `Vrestore'=`Vout'
    ereturn post `bout' `Vout', obs(`Nsys') esample(`union')
    ereturn local cmd "suest"
    ereturn local names `"`names'"'
    forvalues i=1/`nmodels' {
        ereturn local eqnames`i' `"`eqname`i''"'
    }

    capture quietly ereturn repost V=`Vfv', buildfvinfo
    local hrc=_rc
    if !`hrc' {
        capture quietly _get_hmat `Hxpgr'
        local hrc=_rc
        if !`hrc' local hrc=r(rc)
    }
    capture quietly ereturn repost V=`Vrestore'
    if `hrc' {
        di as err "suest2 could not construct factor-variable estimability information for the gamma xtpoisson, re system"
        exit 498
    }

    ereturn matrix suest2_xpgr_H=`Hxpgr', copy
    mata: st_numscalar("__s2_xpgr_rank",rank(st_matrix("`Vout'")))
    ereturn scalar rank=scalar(__s2_xpgr_rank)
    ereturn scalar N_clust=`Gsys'
    ereturn scalar N_g=`Ngsys'
    ereturn local clustvar `"`scorevar'"'
    ereturn local vce "cluster"
    ereturn local vcetype "Robust"
    ereturn local names `"`names'"'
    ereturn local properties "b V"
    ereturn scalar suest2_xtpoissonregamma=1
    ereturn scalar suest2_xtpoisson_re_gamma=1
    ereturn local suest2_xpgr_panelvar `"`panelvar'"'
    ereturn local suest2_xpgr_scorevar `"`scorevar'"'
    ereturn local suest2_xpgr_engine ///
        "analytic_gamma_integrated_requested_cluster_scores_raw_sandwich"
    ereturn local suest2_xpgr_displayopts `"`displayopts'"'
    ereturn local title "Simultaneous gamma random-effects Poisson results"
    ereturn local cmd "suest2_xtpoissonregamma"

    forvalues i=1/`nmodels' {
        ereturn local eqnames`i' `"`eqname`i''"'
        ereturn scalar suest2_xpgr_N`i'=`N`i''
        ereturn scalar suest2_xpgr_G`i'=`G`i''
        ereturn scalar suest2_xpgr_K`i'=`korig`i''
        ereturn scalar suest2_xpgr_rank`i'=`rank`i''
        ereturn scalar suest2_xpgr_anc`i'=`anc`i''
        ereturn scalar suest2_xpgr_summax`i'=`maxscore`i''
    }
end

program define suest2_xtnbregfe_joint_robust, eclass
    version 9
    syntax, B(name) V(name) SAMPLE(varname) SCORES(varlist) CLUSTER(varname)
    ereturn post `b' `v', esample(`sample')
    ereturn local cmd "suest2_xtnbregfe_joint"
    ereturn local properties "b V"
    _robust2 `scores' if e(sample), cluster(`cluster') allcons
end

program define suest2_xtnbregfeestimate, sortpreserve eclass
    version 16
    syntax [anything] [, CLuster(varname) VCE(string asis) Robust MINUS ///
        REGRESSML SVY Level(cilevel) DIR EForm(passthru) *]

    if "`minus'`regressml'`svy'"!="" {
        di as err "options minus, regressml, and svy are not supported for xtnbreg, fe systems"
        exit 198
    }

    local displayopts
    if "`level'"!="" local displayopts `"`displayopts' level(`level')"'
    if "`dir'"!="" local displayopts `"`displayopts' dir"'
    if `"`eform'"'!="" local displayopts `"`displayopts' `eform'"'
    if trim(`"`options'"')!="" local displayopts `"`displayopts' `options'"'

    if "`cluster'"!="" & trim(`"`vce'"')!="" {
        di as err "specify only one of cluster() or vce()"
        exit 198
    }
    if "`cluster'"!="" & "`robust'"!="" {
        di as err "specify only one of cluster() or robust"
        exit 198
    }
    if trim(`"`vce'"')!="" & "`robust'"!="" {
        di as err "specify only one of vce() or robust"
        exit 198
    }

    local requested_cluster `"`cluster'"'
    if trim(`"`vce'"')!="" {
        local vcelower=ustrlower(itrim(trim(`"`vce'"')))
        if "`vcelower'"=="robust" local requested_cluster
        else if ustrregexm(`"`vcelower'"',"^cluster[ ]+([A-Za-z_][A-Za-z0-9_]*)$") {
            local requested_cluster `"`=ustrregexs(1)'"'
        }
        else if ustrregexm(`"`vcelower'"',"^cluster[ ]*\([ ]*([A-Za-z_][A-Za-z0-9_]*)[ ]*\)$") {
            local requested_cluster `"`=ustrregexs(1)'"'
        }
        else {
            di as err "the xtnbreg, fe route supports only vce(robust) or vce(cluster varname)"
            exit 198
        }
    }

    est_expand `"`anything'"', min(2) default(.)
    local names `"`r(names)'"'
    local names : list uniq names
    local nmodels : word count `names'
    local hasdot : list posof "." in names
    if `hasdot' {
        di as err "xtnbreg, fe support requires named stored estimates"
        di as err "store each model with {bf:estimates store} before running {bf:suest2}"
        exit 198
    }

    local panelvar
    local scorevar
    local rc 0
    local errtext

    forvalues i=1/`nmodels' {
        local name : word `i' of `names'
        capture quietly estimates restore `name'
        if _rc {
            local rc=_rc
            local errtext "unable to restore constituent model `name'"
            continue, break
        }
        if "`e(cmd)'"!="xtnbreg" | "`e(model)'"!="fe" {
            local rc 322
            local errtext "the first xtnbreg, fe increment requires every constituent model to be xtnbreg, fe"
            continue, break
        }
        if trim(`"`e(wtype)'"')!="" {
            local rc 198
            local errtext "weights are not yet supported for xtnbreg, fe systems"
            continue, break
        }
        if trim(`"`e(prefix)'"')!="" {
            local rc 198
            local errtext "prefixed xtnbreg, fe estimates are not yet supported"
            continue, break
        }
        if "`e(vce)'"!="oim" {
            local rc 198
            local errtext "store conventional xtnbreg, fe estimates and request robust or clustered VCE with suest2"
            continue, break
        }

        local ivar `"`e(ivar)'"'
        if trim(`"`ivar'"')=="" {
            local rc 498
            local errtext "model `name' does not retain its panel identifier in e(ivar)"
            continue, break
        }
        if `i'==1 local panelvar `"`ivar'"'
        else if `"`ivar'"'!=`"`panelvar'"' {
            local rc 459
            local errtext "all xtnbreg, fe constituent models must use the same panel variable"
            continue, break
        }

        capture confirm matrix e(b)
        if _rc {
            local rc=_rc
            local errtext "model `name' does not contain e(b)"
            continue, break
        }
        capture confirm scalar e(rank)
        if _rc {
            local rc 498
            local errtext "model `name' does not retain e(rank)"
            continue, break
        }
        if e(rank)<1 {
            local rc 498
            local errtext "model `name' has no estimable conditional-negative-binomial coefficients"
            continue, break
        }

        tempname bsrc Vsrc omit Csrc
        matrix `bsrc'=e(b)
        matrix `Vsrc'=e(V)
        local bsrc`i' `bsrc'
        local Vsrc`i' `Vsrc'
        local korig`i'=colsof(`bsrc')
        local rank`i'=e(rank)
        local N`i'=e(N)
        local depvar`i' `"`e(depvar)'"'

        local hascns`i' 0
        capture confirm matrix e(Cns)
        if !_rc {
            matrix `Csrc'=e(Cns)
            local Csrc`i' `Csrc'
            local hascns`i' 1
        }

        tempvar sample samplekeep xb
        quietly generate byte `sample'=e(sample)
        quietly generate byte `samplekeep'=`sample'
        local sample`i' `samplekeep'
        quietly count if `sample'
        if r(N)!=`N`i'' {
            local rc 459
            local errtext "the current data no longer reproduce the stored estimation sample for model `name'"
            continue, break
        }

        capture quietly predict double `xb' if `sample', xb
        if _rc {
            local rc=_rc
            local errtext "unable to reproduce the native linear prediction for model `name'"
            continue, break
        }

        quietly _ms_omit_info `bsrc'
        matrix `omit'=r(omit)
        local cnames : colnames `bsrc'
        local xvars
        local scores
        local p 0

        forvalues j=1/`korig`i'' {
            local coef : word `j' of `cnames'
            tempvar xj sj
            quietly generate double `xj'=0 if `sample'
            quietly generate double `sj'=.
            if !`omit'[1,`j'] {
                if `"`coef'"'=="_cons" {
                    quietly replace `xj'=1 if `sample'
                }
                else {
                    capture quietly fvrevar `coef'
                    if _rc {
                        local rc=_rc
                        local errtext "unable to reconstruct design column `coef' for model `name'"
                        continue, break
                    }
                    local raw `"`r(varlist)'"'
                    local nraw : word count `raw'
                    if `nraw'!=1 {
                        local rc 498
                        local errtext "design column `coef' did not expand to exactly one variable for model `name'"
                        continue, break
                    }
                    quietly count if `sample' & missing(`raw')
                    if r(N) {
                        local rc 459
                        local errtext "design column `coef' is missing inside the stored sample for model `name'"
                        continue, break
                    }
                    quietly replace `xj'=`raw' if `sample'
                }
                local ++p
            }
            local xvars `xvars' `xj'
            local scores `scores' `sj'
        }
        if `rc' continue, break
        if `p'!=`rank`i'' {
            local rc 498
            local errtext "the reconstructed conditional-negative-binomial design rank differs from model `name'"
            continue, break
        }

        capture noisily mata: suest2_xtnbregfe_scores_mata( ///
            "`depvar`i''","`xb'","`panelvar'","`sample'", ///
            "`xvars'","`scores'")
        if _rc {
            local rc=_rc
            local errtext "unable to reconstruct conditional-negative-binomial parameter scores for model `name'"
            continue, break
        }

        local maxscore 0
        foreach sj of local scores {
            quietly summarize `sj' if `sample', meanonly
            local sabs=abs(r(sum))
            if `sabs'>`maxscore' local maxscore=`sabs'
        }
        if `maxscore'>1e-5 {
            local rc 498
            local errtext "conditional-negative-binomial parameter scores are not centered for model `name'"
            continue, break
        }
        local maxscore`i'=`maxscore'
        local scores`i' `"`scores'"'

    }

    if `rc' {
        di as err `"`errtext'"'
        exit `rc'
    }

    capture quietly xtset
    if _rc {
        local rc=_rc
        di as err "the current data must remain xtset for the stored xtnbreg, fe models"
        exit `rc'
    }
    if `"`r(panelvar)'"'!=`"`panelvar'"' {
        di as err "the current xtset panel variable differs from stored e(ivar)={bf:`panelvar'}"
        exit 459
    }

    if trim(`"`requested_cluster'"')=="" local scorevar `"`panelvar'"'
    else local scorevar `"`requested_cluster'"'
    capture confirm numeric variable `scorevar'
    if _rc {
        local rc=_rc
        di as err "cluster variable {bf:`scorevar'} must be numeric"
        exit `rc'
    }

    tempvar union cmin cmax
    quietly generate byte `union'=0
    forvalues i=1/`nmodels' {
        quietly replace `union'=1 if `sample`i''
    }
    quietly count if `union' & missing(`scorevar')
    if r(N) {
        di as err "cluster variable {bf:`scorevar'} is missing in the union sample"
        exit 459
    }
    bysort `panelvar': egen double `cmin'=min(cond(`union',`scorevar',.))
    bysort `panelvar': egen double `cmax'=max(cond(`union',`scorevar',.))
    quietly count if `union' & `cmin'!=`cmax'
    if r(N) {
        di as err "panel variable {bf:`panelvar'} is not nested within cluster variable {bf:`scorevar'}"
        exit 459
    }

    forvalues i=1/`nmodels' {
        tempvar tagcluster
        quietly egen byte `tagcluster'=tag(`scorevar') if `sample`i''
        quietly count if `tagcluster'
        local G`i'=r(N)
        if `G`i''<2 {
            local name : word `i' of `names'
            di as err "model {bf:`name'} contains fewer than two clusters in {bf:`scorevar'}"
            exit 459
        }
    }

    tempname bout Vsys
    local eqused
    local jointscores
    local expected 0

    forvalues i=1/`nmodels' {
        local name : word `i' of `names'
        local eq=substr(strtoname("`name'_`depvar`i''"),1,32)
        local duplicate : list posof "`eq'" in eqused
        if `duplicate' {
            local suffix="_p`i'"
            local room=32-strlen("`suffix'")
            local eq=substr(strtoname("`name'"),1,`room')+"`suffix'"
        }
        local eqused `"`eqused' `eq'"'
        local eqname`i' `"`eq'"'

        tempname bi Vi
        matrix `bi'=`bsrc`i''
        matrix `Vi'=`Vsrc`i''
        local eqlist
        forvalues j=1/`korig`i'' {
            local eqlist `"`eqlist' `eq'"'
        }
        matrix coleq `bi'=`eqlist'
        matrix coleq `Vi'=`eqlist'
        matrix roweq `Vi'=`eqlist'

        if `i'==1 {
            matrix `bout'=`bi'
            matrix `Vsys'=`Vi'
        }
        else {
            local oldK=colsof(`Vsys')
            matrix `Vsys'=(`Vsys',J(`oldK',`korig`i'',0)\J(`korig`i'',`oldK',0),`Vi')
            matrix `bout'=`bout',`bi'
        }

        foreach s of local scores`i' {
            quietly replace `s'=0 if `union' & missing(`s')
            local jointscores `jointscores' `s'
        }
        local expected=`expected'+`korig`i''
    }

    if colsof(`bout')!=`expected' | colsof(`Vsys')!=`expected' {
        di as err "suest2 could not assemble the xtnbreg, fe joint score system"
        exit 498
    }

    local bcn : colnames `bout'
    local beq : coleq `bout'
    matrix colnames `Vsys'=`bcn'
    matrix rownames `Vsys'=`bcn'
    matrix coleq `Vsys'=`beq'
    matrix roweq `Vsys'=`beq'

    local vcn : colnames `Vsys'
    local vrn : rownames `Vsys'
    local veq : coleq `Vsys'
    local vreq : roweq `Vsys'
    if `"`vcn'"'!=`"`bcn'"' | `"`vrn'"'!=`"`bcn'"' | ///
        `"`veq'"'!=`"`beq'"' | `"`vreq'"'!=`"`beq'"' {
        di as err "the xtnbreg, fe joint covariance stripe does not match the coefficient stripe"
        exit 498
    }

    tempname bhelper Vhelper
    matrix `bhelper'=`bout'
    matrix `Vhelper'=`Vsys'

    tempvar helper
    quietly generate byte `helper'=`union'
    capture quietly suest2_xtnbregfe_joint_robust, b(`bhelper') v(`Vhelper') ///
        sample(`helper') scores(`jointscores') cluster(`scorevar')
    local rc=_rc
    if `rc' {
        di as err "unable to construct the xtnbreg, fe joint covariance matrix"
        exit `rc'
    }

    tempname Vout Vmb
    matrix `Vout'=e(V)
    matrix `Vmb'=e(V_modelbased)
    local Nsys=e(N)
    local Gsys=e(N_clust)
    mata: st_numscalar("__s2_xtnf_breaddiff",max(abs(st_matrix("`Vsys'"):-st_matrix("`Vmb'"))))
    if scalar(__s2_xtnf_breaddiff)>1e-12 {
        di as err "the xtnbreg, fe model-based covariance was not preserved"
        exit 498
    }

    tempname Vt
    matrix `Vt'=`Vout''
    matrix `Vout'=(`Vout'+`Vt')/2
    matrix colnames `Vout'=`bcn'
    matrix rownames `Vout'=`bcn'
    matrix coleq `Vout'=`beq'
    matrix roweq `Vout'=`beq'

    tempname omitall Vfv Vrestore Hnbfe
    quietly _ms_omit_info `bout'
    matrix `omitall'=r(omit)
    local Kout=colsof(`bout')
    matrix `Vfv'=I(`Kout')
    matrix colnames `Vfv'=`bcn'
    matrix rownames `Vfv'=`bcn'
    matrix coleq `Vfv'=`beq'
    matrix roweq `Vfv'=`beq'
    forvalues j=1/`Kout' {
        if `omitall'[1,`j'] matrix `Vfv'[`j',`j']=0
    }

    tempvar tagpanel
    quietly egen byte `tagpanel'=tag(`panelvar') if `union'
    quietly count if `tagpanel'
    local Ngsys=r(N)

    matrix `Vrestore'=`Vout'
    ereturn post `bout' `Vout', obs(`Nsys') esample(`union')
    ereturn local cmd "suest"
    ereturn local names `"`names'"'
    forvalues i=1/`nmodels' {
        ereturn local eqnames`i' `"`eqname`i''"'
    }
    capture quietly ereturn repost V=`Vfv', buildfvinfo
    local hrc=_rc
    if !`hrc' {
        capture quietly _get_hmat `Hnbfe'
        local hrc=_rc
        if !`hrc' local hrc=r(rc)
    }
    capture quietly ereturn repost V=`Vrestore'
    if `hrc' {
        di as err "suest2 could not construct factor-variable estimability information for the xtnbreg, fe system"
        exit 498
    }

    ereturn matrix suest2_xtnbregfe_H=`Hnbfe', copy
    mata: st_numscalar("__s2_xtnferank",rank(st_matrix("`Vout'")))
    ereturn scalar rank=scalar(__s2_xtnferank)
    ereturn scalar N_clust=`Gsys'
    ereturn scalar N_g=`Ngsys'
    ereturn local clustvar `"`scorevar'"'
    ereturn local vce "cluster"
    ereturn local vcetype "Robust"
    ereturn local names `"`names'"'
    ereturn local properties "b V"
    ereturn scalar suest2_xtnbregfe=1
    ereturn local suest2_xtnbregfe_panelvar `"`panelvar'"'
    ereturn local suest2_xtnbregfe_scorevar `"`scorevar'"'
    ereturn local suest2_xtnbregfe_engine "analytic_conditional_negative_binomial_scores_robust2"
    ereturn local suest2_xtnbregfe_displayopts `"`displayopts'"'
    ereturn local title "Simultaneous conditional fixed-effects negative-binomial results"
    ereturn local cmd "suest2_xtnbregfe"

    forvalues i=1/`nmodels' {
        ereturn local eqnames`i' `"`eqname`i''"'
        ereturn scalar suest2_xtnbregfe_N`i'=`N`i''
        ereturn scalar suest2_xtnbregfe_G`i'=`G`i''
        ereturn scalar suest2_xtnbregfe_K`i'=`korig`i''
        ereturn scalar suest2_xtnbregfe_rank`i'=`rank`i''
        ereturn scalar suest2_xtnbregfe_score_maxabs`i'=`maxscore`i''
    }

end


program define suest2_xtpoissonfe_joint_robust, eclass
    version 9
    syntax, B(name) V(name) SAMPLE(varname) SCORES(varlist) CLUSTER(varname)
    ereturn post `b' `v', esample(`sample')
    ereturn local cmd "suest2_xtpoissonfe_joint"
    ereturn local properties "b V"
    _robust2 `scores' if e(sample), cluster(`cluster') allcons
end

program define suest2_xtpoissonfeestimate, sortpreserve eclass
    version 16
    syntax [anything] [, CLuster(varname) VCE(string asis) Robust MINUS ///
        REGRESSML SVY Level(cilevel) DIR EForm(passthru) *]

    if "`minus'`regressml'`svy'"!="" {
        di as err "options minus, regressml, and svy are not supported for xtpoisson, fe systems"
        exit 198
    }

    local displayopts
    if "`level'"!="" local displayopts `"`displayopts' level(`level')"'
    if "`dir'"!="" local displayopts `"`displayopts' dir"'
    if `"`eform'"'!="" local displayopts `"`displayopts' `eform'"'
    if trim(`"`options'"')!="" local displayopts `"`displayopts' `options'"'

    if "`cluster'"!="" & trim(`"`vce'"')!="" {
        di as err "specify only one of cluster() or vce()"
        exit 198
    }
    if "`cluster'"!="" & "`robust'"!="" {
        di as err "specify only one of cluster() or robust"
        exit 198
    }
    if trim(`"`vce'"')!="" & "`robust'"!="" {
        di as err "specify only one of vce() or robust"
        exit 198
    }

    local requested_cluster `"`cluster'"'
    if trim(`"`vce'"')!="" {
        local vcelower=ustrlower(itrim(trim(`"`vce'"')))
        if "`vcelower'"=="robust" local requested_cluster
        else if ustrregexm(`"`vcelower'"',"^cluster[ ]+([A-Za-z_][A-Za-z0-9_]*)$") {
            local requested_cluster `"`=ustrregexs(1)'"'
        }
        else if ustrregexm(`"`vcelower'"',"^cluster[ ]*\([ ]*([A-Za-z_][A-Za-z0-9_]*)[ ]*\)$") {
            local requested_cluster `"`=ustrregexs(1)'"'
        }
        else {
            di as err "the xtpoisson, fe route supports only vce(robust) or vce(cluster varname)"
            exit 198
        }
    }

    est_expand `"`anything'"', min(2) default(.)
    local names `"`r(names)'"'
    local names : list uniq names
    local nmodels : word count `names'
    local hasdot : list posof "." in names
    if `hasdot' {
        di as err "xtpoisson, fe support requires named stored estimates"
        di as err "store each model with {bf:estimates store} before running {bf:suest2}"
        exit 198
    }

    local panelvar
    local scorevar
    local rc 0
    local errtext

    forvalues i=1/`nmodels' {
        local name : word `i' of `names'
        capture quietly estimates restore `name'
        if _rc {
            local rc=_rc
            local errtext "unable to restore constituent model `name'"
            continue, break
        }
        if "`e(cmd)'"!="xtpoisson" | "`e(model)'"!="fe" {
            local rc 322
            local errtext "the first xtpoisson, fe increment requires every constituent model to be xtpoisson, fe"
            continue, break
        }
        if trim(`"`e(wtype)'"')!="" {
            local rc 198
            local errtext "weights are not yet supported for xtpoisson, fe systems"
            continue, break
        }
        if trim(`"`e(prefix)'"')!="" {
            local rc 198
            local errtext "prefixed xtpoisson, fe estimates are not yet supported"
            continue, break
        }
        if "`e(vce)'"!="oim" {
            local rc 198
            local errtext "store conventional xtpoisson, fe estimates and request robust or clustered VCE with suest2"
            continue, break
        }

        local ivar `"`e(ivar)'"'
        if trim(`"`ivar'"')=="" {
            local rc 498
            local errtext "model `name' does not retain its panel identifier in e(ivar)"
            continue, break
        }
        if `i'==1 local panelvar `"`ivar'"'
        else if `"`ivar'"'!=`"`panelvar'"' {
            local rc 459
            local errtext "all xtpoisson, fe constituent models must use the same panel variable"
            continue, break
        }

        capture confirm matrix e(b)
        if _rc {
            local rc=_rc
            local errtext "model `name' does not contain e(b)"
            continue, break
        }
        capture confirm scalar e(rank)
        if _rc {
            local rc 498
            local errtext "model `name' does not retain e(rank)"
            continue, break
        }
        if e(rank)<1 {
            local rc 498
            local errtext "model `name' has no estimable conditional-Poisson slope coefficients"
            continue, break
        }

        tempname bsrc Vsrc omit Csrc
        matrix `bsrc'=e(b)
        matrix `Vsrc'=e(V)
        local bsrc`i' `bsrc'
        local Vsrc`i' `Vsrc'
        local korig`i'=colsof(`bsrc')
        local rank`i'=e(rank)
        local N`i'=e(N)
        local depvar`i' `"`e(depvar)'"'

        local hascns`i' 0
        capture confirm matrix e(Cns)
        if !_rc {
            matrix `Csrc'=e(Cns)
            local Csrc`i' `Csrc'
            local hascns`i' 1
        }

        tempvar sample samplekeep xb exb ytotal exbtotal cres
        quietly generate byte `sample'=e(sample)
        quietly generate byte `samplekeep'=`sample'
        local sample`i' `samplekeep'
        quietly count if `sample'
        if r(N)!=`N`i'' {
            local rc 459
            local errtext "the current data no longer reproduce the stored estimation sample for model `name'"
            continue, break
        }

        capture quietly predict double `xb' if `sample', xb
        if _rc {
            local rc=_rc
            local errtext "unable to reproduce the native linear prediction for model `name'"
            continue, break
        }
        quietly generate double `exb'=exp(`xb') if `sample'
        bysort `panelvar': egen double `ytotal'=total(`depvar`i'') if `sample'
        bysort `panelvar': egen double `exbtotal'=total(`exb') if `sample'
        quietly count if `sample' & (`exbtotal'<=0 | missing(`exbtotal'))
        if r(N) {
            local rc 498
            local errtext "conditional-Poisson denominator is invalid for model `name'"
            continue, break
        }
        quietly generate double `cres'=`depvar`i''-`ytotal'*`exb'/`exbtotal' if `sample'

        quietly _ms_omit_info `bsrc'
        matrix `omit'=r(omit)
        local cnames : colnames `bsrc'
        local scores
        local p 0
        local maxscore 0

        forvalues j=1/`korig`i'' {
            local coef : word `j' of `cnames'
            tempvar sj
            if `omit'[1,`j'] {
                quietly generate double `sj'=0 if `sample'
            }
            else {
                capture quietly fvrevar `coef'
                if _rc {
                    local rc=_rc
                    local errtext "unable to reconstruct design column `coef' for model `name'"
                    continue, break
                }
                local raw `"`r(varlist)'"'
                local nraw : word count `raw'
                if `nraw'!=1 {
                    local rc 498
                    local errtext "design column `coef' did not expand to exactly one variable for model `name'"
                    continue, break
                }
                quietly count if `sample' & missing(`raw')
                if r(N) {
                    local rc 459
                    local errtext "design column `coef' is missing inside the stored sample for model `name'"
                    continue, break
                }
                quietly generate double `sj'=`cres'*`raw' if `sample'
                local ++p
                quietly summarize `sj' if `sample', meanonly
                local sabs=abs(r(sum))
                if `sabs'>`maxscore' local maxscore=`sabs'
            }
            local scores `scores' `sj'
        }
        if `rc' continue, break
        if `p'!=`rank`i'' {
            local rc 498
            local errtext "the reconstructed conditional-Poisson design rank differs from model `name'"
            continue, break
        }
        if `maxscore'>1e-5 {
            local rc 498
            local errtext "conditional-Poisson parameter scores are not centered for model `name'"
            continue, break
        }
        local maxscore`i'=`maxscore'

        local scores`i' `"`scores'"'
    }

    if `rc' {
        di as err `"`errtext'"'
        exit `rc'
    }

    capture quietly xtset
    if _rc {
        local rc=_rc
        di as err "the current data must remain xtset for the stored xtpoisson, fe models"
        exit `rc'
    }
    if `"`r(panelvar)'"'!=`"`panelvar'"' {
        di as err "the current xtset panel variable differs from stored e(ivar)={bf:`panelvar'}"
        exit 459
    }

    if trim(`"`requested_cluster'"')=="" local scorevar `"`panelvar'"'
    else local scorevar `"`requested_cluster'"'
    capture confirm numeric variable `scorevar'
    if _rc {
        local rc=_rc
        di as err "cluster variable {bf:`scorevar'} must be numeric"
        exit `rc'
    }

    tempvar union cmin cmax
    quietly generate byte `union'=0
    forvalues i=1/`nmodels' {
        quietly replace `union'=1 if `sample`i''
    }
    quietly count if `union' & missing(`scorevar')
    if r(N) {
        di as err "cluster variable {bf:`scorevar'} is missing in the union sample"
        exit 459
    }
    bysort `panelvar': egen double `cmin'=min(cond(`union',`scorevar',.))
    bysort `panelvar': egen double `cmax'=max(cond(`union',`scorevar',.))
    quietly count if `union' & `cmin'!=`cmax'
    if r(N) {
        di as err "panel variable {bf:`panelvar'} is not nested within cluster variable {bf:`scorevar'}"
        exit 459
    }

    forvalues i=1/`nmodels' {
        tempvar tagcluster
        quietly egen byte `tagcluster'=tag(`scorevar') if `sample`i''
        quietly count if `tagcluster'
        local G`i'=r(N)
        if `G`i''<2 {
            local name : word `i' of `names'
            di as err "model {bf:`name'} contains fewer than two clusters in {bf:`scorevar'}"
            exit 459
        }
    }

    tempname bout Vsys
    local eqused
    local jointscores
    local expected 0

    forvalues i=1/`nmodels' {
        local name : word `i' of `names'
        local eq=substr(strtoname("`name'_`depvar`i''"),1,32)
        local duplicate : list posof "`eq'" in eqused
        if `duplicate' {
            local suffix="_p`i'"
            local room=32-strlen("`suffix'")
            local eq=substr(strtoname("`name'"),1,`room')+"`suffix'"
        }
        local eqused `"`eqused' `eq'"'
        local eqname`i' `"`eq'"'

        tempname bi Vi
        matrix `bi'=`bsrc`i''
        matrix `Vi'=`Vsrc`i''
        local eqlist
        forvalues j=1/`korig`i'' {
            local eqlist `"`eqlist' `eq'"'
        }
        matrix coleq `bi'=`eqlist'
        matrix coleq `Vi'=`eqlist'
        matrix roweq `Vi'=`eqlist'

        if `i'==1 {
            matrix `bout'=`bi'
            matrix `Vsys'=`Vi'
        }
        else {
            local oldK=colsof(`Vsys')
            matrix `Vsys'=(`Vsys',J(`oldK',`korig`i'',0)\J(`korig`i'',`oldK',0),`Vi')
            matrix `bout'=`bout',`bi'
        }

        foreach s of local scores`i' {
            quietly replace `s'=0 if `union' & missing(`s')
            local jointscores `jointscores' `s'
        }
        local expected=`expected'+`korig`i''
    }

    if colsof(`bout')!=`expected' | colsof(`Vsys')!=`expected' {
        di as err "suest2 could not assemble the xtpoisson, fe joint score system"
        exit 498
    }

    local bcn : colnames `bout'
    local beq : coleq `bout'
    matrix colnames `Vsys'=`bcn'
    matrix rownames `Vsys'=`bcn'
    matrix coleq `Vsys'=`beq'
    matrix roweq `Vsys'=`beq'

    local vcn : colnames `Vsys'
    local vrn : rownames `Vsys'
    local veq : coleq `Vsys'
    local vreq : roweq `Vsys'
    if `"`vcn'"'!=`"`bcn'"' | `"`vrn'"'!=`"`bcn'"' | ///
        `"`veq'"'!=`"`beq'"' | `"`vreq'"'!=`"`beq'"' {
        di as err "the xtpoisson, fe joint covariance stripe does not match the coefficient stripe"
        exit 498
    }

    tempname bhelper Vhelper
    matrix `bhelper'=`bout'
    matrix `Vhelper'=`Vsys'

    tempvar helper
    quietly generate byte `helper'=`union'
    capture quietly suest2_xtpoissonfe_joint_robust, b(`bhelper') v(`Vhelper') ///
        sample(`helper') scores(`jointscores') cluster(`scorevar')
    local rc=_rc
    if `rc' {
        di as err "unable to construct the xtpoisson, fe joint covariance matrix"
        exit `rc'
    }

    tempname Vout Vmb
    matrix `Vout'=e(V)
    matrix `Vmb'=e(V_modelbased)
    local Nsys=e(N)
    local Gsys=e(N_clust)
    mata: st_numscalar("__s2_xtpf_breaddiff",max(abs(st_matrix("`Vsys'"):-st_matrix("`Vmb'"))))
    if scalar(__s2_xtpf_breaddiff)>1e-12 {
        di as err "the xtpoisson, fe model-based covariance was not preserved"
        exit 498
    }

    tempname Vt
    matrix `Vt'=`Vout''
    matrix `Vout'=(`Vout'+`Vt')/2
    matrix colnames `Vout'=`bcn'
    matrix rownames `Vout'=`bcn'
    matrix coleq `Vout'=`beq'
    matrix roweq `Vout'=`beq'

    tempname omitall Vfv Vrestore Hfe
    quietly _ms_omit_info `bout'
    matrix `omitall'=r(omit)
    local Kout=colsof(`bout')
    matrix `Vfv'=I(`Kout')
    matrix colnames `Vfv'=`bcn'
    matrix rownames `Vfv'=`bcn'
    matrix coleq `Vfv'=`beq'
    matrix roweq `Vfv'=`beq'
    forvalues j=1/`Kout' {
        if `omitall'[1,`j'] matrix `Vfv'[`j',`j']=0
    }

    tempvar tagpanel
    quietly egen byte `tagpanel'=tag(`panelvar') if `union'
    quietly count if `tagpanel'
    local Ngsys=r(N)

    matrix `Vrestore'=`Vout'
    ereturn post `bout' `Vout', obs(`Nsys') esample(`union')
    ereturn local cmd "suest"
    ereturn local names `"`names'"'
    forvalues i=1/`nmodels' {
        ereturn local eqnames`i' `"`eqname`i''"'
    }
    capture quietly ereturn repost V=`Vfv', buildfvinfo
    local hrc=_rc
    if !`hrc' {
        capture quietly _get_hmat `Hfe'
        local hrc=_rc
        if !`hrc' local hrc=r(rc)
    }
    capture quietly ereturn repost V=`Vrestore'
    if `hrc' {
        di as err "suest2 could not construct factor-variable estimability information for the xtpoisson, fe system"
        exit 498
    }

    ereturn matrix suest2_xtpoissonfe_H=`Hfe', copy
    mata: st_numscalar("__s2_xtpferank",rank(st_matrix("`Vout'")))
    ereturn scalar rank=scalar(__s2_xtpferank)
    ereturn scalar N_clust=`Gsys'
    ereturn scalar N_g=`Ngsys'
    ereturn local clustvar `"`scorevar'"'
    ereturn local vce "cluster"
    ereturn local vcetype "Robust"
    ereturn local names `"`names'"'
    ereturn local properties "b V"
    ereturn scalar suest2_xtpoissonfe=1
    ereturn local suest2_xtpoissonfe_panelvar `"`panelvar'"'
    ereturn local suest2_xtpoissonfe_scorevar `"`scorevar'"'
    ereturn local suest2_xtpoissonfe_engine "analytic_conditional_poisson_scores_robust2"
    ereturn local suest2_xtpoissonfe_displayopts `"`displayopts'"'
    ereturn local title "Simultaneous conditional fixed-effects Poisson results"
    ereturn local cmd "suest2_xtpoissonfe"

    forvalues i=1/`nmodels' {
        ereturn local eqnames`i' `"`eqname`i''"'
        ereturn scalar suest2_xtpoissonfe_N`i'=`N`i''
        ereturn scalar suest2_xtpoissonfe_G`i'=`G`i''
        ereturn scalar suest2_xtpoissonfe_K`i'=`korig`i''
        ereturn scalar suest2_xtpoissonfe_rank`i'=`rank`i''
        ereturn scalar suest2_xtpoissonfe_score_maxabs`i'=`maxscore`i''
    }

end

program define suest2_xtfeestimate, sortpreserve eclass
    version 16
    syntax [anything] [, CLuster(varname) VCE(string asis) Robust MINUS ///
        REGRESSML SVY Level(cilevel) DIR EForm(passthru) *]

    if "`minus'" != "" | "`regressml'" != "" | "`svy'" != "" {
        di as err "options minus, regressml, and svy are not supported for xtreg, fe systems"
        exit 198
    }

    local displayopts
    if "`level'" != "" local displayopts `"`displayopts' level(`level')"'
    if "`dir'" != "" local displayopts `"`displayopts' dir"'
    if `"`eform'"' != "" local displayopts `"`displayopts' `eform'"'
    if trim(`"`options'"') != "" local displayopts `"`displayopts' `options'"'

    if "`cluster'" != "" & trim(`"`vce'"') != "" {
        di as err "specify only one of cluster() or vce()"
        exit 198
    }
    if "`cluster'" != "" & "`robust'" != "" {
        di as err "specify only one of cluster() or robust"
        exit 198
    }
    if trim(`"`vce'"') != "" & "`robust'" != "" {
        di as err "specify only one of vce() or robust"
        exit 198
    }

    local requested_cluster `"`cluster'"'
    if trim(`"`vce'"') != "" {
        local vcelower = ustrlower(itrim(trim(`"`vce'"')))
        if "`vcelower'" == "robust" local requested_cluster
        else if ustrregexm(`"`vcelower'"', "^cluster[ ]+([A-Za-z_][A-Za-z0-9_]*)$") {
            local requested_cluster `"`=ustrregexs(1)'"'
        }
        else if ustrregexm(`"`vcelower'"', "^cluster[ ]*\([ ]*([A-Za-z_][A-Za-z0-9_]*)[ ]*\)$") {
            local requested_cluster `"`=ustrregexs(1)'"'
        }
        else {
            di as err "the xtreg, fe route supports only vce(robust) or vce(cluster varname)"
            exit 198
        }
    }

    est_expand `"`anything'"', min(2) default(.)
    local names `"`r(names)'"'
    local names : list uniq names
    local nmodels : word count `names'
    local hasdot : list posof "." in names
    if `hasdot' {
        di as err "xtreg, fe support requires named stored estimates"
        di as err "store each model with {bf:estimates store} before running {bf:suest2}"
        exit 198
    }

    local bridges
    local rc 0
    local panelvar
    local scorevar
    local errtext

    forvalues i = 1/`nmodels' {
        local name : word `i' of `names'
        capture quietly estimates restore `name'
        if _rc {
            local rc = _rc
            local errtext "unable to restore constituent model `name'"
            continue, break
        }
        if "`e(cmd)'" != "xtreg" | "`e(model)'" != "fe" {
            local rc 322
            local errtext "the first xtreg, fe increment requires every constituent model to be xtreg, fe"
            continue, break
        }
        if trim(`"`e(wtype)'"') != "" {
            local rc 198
            local errtext "weights are not yet supported for xtreg, fe systems"
            continue, break
        }

        local ivar `"`e(ivar)'"'
        if trim(`"`ivar'"') == "" {
            local rc 498
            local errtext "model `name' does not retain its panel identifier in e(ivar)"
            continue, break
        }
        if `i' == 1 local panelvar `"`ivar'"'
        else if `"`ivar'"' != `"`panelvar'"' {
            local rc 459
            local errtext "all xtreg, fe constituent models must use the same panel variable"
            continue, break
        }

        local absvars `"`e(absvar)'"'
        local extraabs : list absvars - panelvar
        if trim(`"`extraabs'"') != "" {
            local rc 198
            local errtext "additional absorb() variables are not yet supported by the xtreg, fe route"
            continue, break
        }

        capture confirm matrix e(b)
        if _rc {
            local rc = _rc
            local errtext "model `name' does not contain e(b)"
            continue, break
        }
        capture confirm scalar e(rank)
        if _rc {
            local rc 498
            local errtext "model `name' does not retain e(rank)"
            continue, break
        }
        if e(rank) < 1 {
            local rc 498
            local errtext "model `name' has no estimable within-panel slope coefficients"
            continue, break
        }

        tempname bsrc omit A At h ht btarget bbridge bfull
        matrix `bsrc' = e(b)
        local bsrc`i' `bsrc'
        local korig`i' = colsof(`bsrc')
        local nativerank`i' = e(rank)
        local N`i' = e(N)
        local depvar`i' `"`e(depvar)'"'

        tempvar sample
        quietly generate byte `sample' = e(sample)
        local sample`i' `sample'
        quietly count if `sample'
        if r(N) != `N`i'' {
            local rc 459
            local errtext "the current data no longer reproduce the stored estimation sample for model `name'"
            continue, break
        }

        quietly _ms_omit_info `bsrc'
        matrix `omit' = r(omit)
        local cnames : colnames `bsrc'
        local conspos 0
        local p 0
        local xwlist

        forvalues j = 1/`korig`i'' {
            local coef : word `j' of `cnames'
            local omitted = `omit'[1,`j']
            if "`coef'" == "_cons" {
                local conspos = `j'
                continue
            }
            if `omitted' continue

            capture quietly fvrevar `coef'
            if _rc {
                local rc = _rc
                local errtext "unable to reconstruct design column `coef' for model `name'"
                continue, break
            }
            local raw `"`r(varlist)'"'
            local nraw : word count `raw'
            if `nraw' != 1 {
                local rc 498
                local errtext "design column `coef' did not expand to exactly one variable for model `name'"
                continue, break
            }
            capture confirm numeric variable `raw'
            if _rc {
                local rc = _rc
                local errtext "design column `coef' is not numeric for model `name'"
                continue, break
            }
            quietly count if `sample' & missing(`raw')
            if r(N) {
                local rc 459
                local errtext "design column `coef' is now missing inside the stored sample for model `name'"
                continue, break
            }

            local ++p
            local native`i'_`p' = `j'
            quietly summarize `raw' if `sample', meanonly
            local mean`i'_`p' = r(mean)
            tempvar panelmean xw
            bysort `panelvar': egen double `panelmean' = mean(cond(`sample', `raw', .))
            quietly generate double `xw' = `raw' - `panelmean' if `sample'
            local xwlist `xwlist' `xw'
        }
        if `rc' continue, break
        if !`conspos' {
            local rc 198
            local errtext "noconstant xtreg, fe models are not yet supported"
            continue, break
        }
        // xtreg, fe uses different e(rank) conventions across VCE types:
        // conventional VCEs can count the normalized intercept, whereas
        // robust/clustered VCEs report the rank of the within-slope block.
        // The bridge therefore derives its effective parameter count from the
        // reconstructed nonomitted within design, not from stored e(rank).
        local p`i' = `p'
        local kfe`i' = `p' + 1
        matrix `A' = J(`korig`i'', `p', 0)
        matrix `h' = J(`korig`i'', 1, 0)
        matrix `btarget' = J(1, `p', .)
        matrix `h'[`conspos',1] = 1
        forvalues q = 1/`p' {
            local j = `native`i'_`q''
            matrix `A'[`j',`q'] = 1
            matrix `A'[`conspos',`q'] = -`mean`i'_`q''
            matrix `btarget'[1,`q'] = `bsrc'[1,`j']
        }
        matrix `At' = `A''
        matrix `ht' = `h''
        local A`i' `A'
        local At`i' `At'
        local h`i' `h'

        tempvar ybar yw
        bysort `panelvar': egen double `ybar' = mean(cond(`sample', `depvar`i'', .))
        quietly generate double `yw' = `depvar`i'' - `ybar' if `sample'
        quietly summarize `depvar`i'' if `sample', meanonly
        local ymean`i' = r(mean)

        capture quietly regress `yw' `xwlist' if `sample', nocons
        if _rc {
            local rc = _rc
            local errtext "unable to fit the within-regression bridge for model `name'"
            continue, break
        }
        tempvar bridgesample
        quietly generate byte `bridgesample' = e(sample)
        quietly count if `bridgesample' != `sample'
        if r(N) {
            local rc 459
            local errtext "the within-regression bridge changed the stored sample for model `name'"
            continue, break
        }
        if colsof(e(b)) != `p' | e(rank) != `p' {
            local rc 498
            local errtext "the within-regression bridge has a different rank from model `name'"
            continue, break
        }
        matrix `bbridge' = e(b)
        if mreldif(`btarget', `bbridge') > 1e-8 {
            local rc 498
            local errtext "the current data do not reproduce the stored xtreg, fe slope coefficients for model `name'"
            continue, break
        }
        matrix `bfull' = `bbridge'*`At' + `ymean`i''*`ht'
        if mreldif(`bsrc', `bfull') > 1e-8 {
            local rc 498
            local errtext "the current data do not reproduce the stored xtreg, fe coefficient vector for model `name'"
            continue, break
        }

        tempname bridge
        quietly estimates store `bridge'
        local bridge`i' `bridge'
        local bridges `"`bridges' `bridge'"'
    }

    if `rc' {
        foreach bridge of local bridges {
            capture quietly estimates drop `bridge'
        }
        di as err `"`errtext'"'
        exit `rc'
    }

    capture quietly xtset
    if _rc {
        local rc = _rc
        foreach bridge of local bridges {
            capture quietly estimates drop `bridge'
        }
        di as err "the current data must remain xtset for the stored xtreg, fe models"
        exit `rc'
    }
    local currentpanel `"`r(panelvar)'"'
    if `"`currentpanel'"' != `"`panelvar'"' {
        foreach bridge of local bridges {
            capture quietly estimates drop `bridge'
        }
        di as err "the current xtset panel variable differs from stored e(ivar)={bf:`panelvar'}"
        exit 459
    }

    if trim(`"`requested_cluster'"') == "" local scorevar `"`panelvar'"'
    else local scorevar `"`requested_cluster'"'
    capture confirm numeric variable `scorevar'
    if _rc {
        local rc = _rc
        foreach bridge of local bridges {
            capture quietly estimates drop `bridge'
        }
        di as err "cluster variable {bf:`scorevar'} must be numeric"
        exit `rc'
    }

    tempvar union cmin cmax
    quietly generate byte `union' = 0
    forvalues i = 1/`nmodels' {
        quietly replace `union' = 1 if `sample`i''
    }
    quietly count if `union' & missing(`scorevar')
    if r(N) {
        foreach bridge of local bridges {
            capture quietly estimates drop `bridge'
        }
        di as err "cluster variable {bf:`scorevar'} is missing on " r(N) " observation(s) in the union sample"
        exit 459
    }
    bysort `panelvar': egen double `cmin' = min(cond(`union', `scorevar', .))
    bysort `panelvar': egen double `cmax' = max(cond(`union', `scorevar', .))
    quietly count if `union' & `cmin' != `cmax'
    if r(N) {
        foreach bridge of local bridges {
            capture quietly estimates drop `bridge'
        }
        di as err "panel variable {bf:`panelvar'} is not nested within cluster variable {bf:`scorevar'}"
        exit 459
    }

    forvalues i = 1/`nmodels' {
        tempvar tagcluster
        quietly egen byte `tagcluster' = tag(`scorevar') if `sample`i''
        quietly count if `tagcluster'
        local G`i' = r(N)
        if `G`i'' < 2 {
            foreach bridge of local bridges {
                capture quietly estimates drop `bridge'
            }
            local name : word `i' of `names'
            di as err "model {bf:`name'} contains fewer than two clusters in {bf:`scorevar'}"
            exit 459
        }
    }

    capture quietly suest `bridges', cluster(`scorevar')
    local rc = _rc
    if `rc' {
        foreach bridge of local bridges {
            capture quietly estimates drop `bridge'
        }
        di as err "official suest could not combine the xtreg, fe within-regression bridges"
        exit `rc'
    }

    tempname bsys Vsys bout Vout
    matrix `bsys' = e(b)
    matrix `Vsys' = e(V)
    local Nsys = e(N)
    local Gsys = e(N_clust)
    local expected 0
    local cursor 1
    forvalues i = 1/`nmodels' {
        local bstart`i' = `cursor'
        local bend`i' = `cursor' + `p`i'' - 1
        local cursor = `cursor' + `p`i'' + 1
        local expected = `expected' + `p`i'' + 1
    }
    if colsof(`bsys') != `expected' {
        foreach bridge of local bridges {
            capture quietly estimates drop `bridge'
        }
        di as err "suest2 could not map the official suest bridge parameter blocks"
        exit 498
    }

    forvalues i = 1/`nmodels' {
        local scale`i' = ((`G`i''/(`G`i''-1))*((`N`i''-1)/(`N`i''-`kfe`i''))) / ///
            (`Gsys'/(`Gsys'-1))
    }

    forvalues i = 1/`nmodels' {
        forvalues j = 1/`nmodels' {
            tempname rawblock block
            matrix `rawblock' = `Vsys'[`bstart`i''..`bend`i'', `bstart`j''..`bend`j'']
            matrix `block' = sqrt(`scale`i''*`scale`j'') * ///
                `A`i'' * `rawblock' * `At`j''
            local Vblock`i'_`j' `block'
        }
    }

    forvalues i = 1/`nmodels' {
        tempname vrow
        matrix `vrow' = `Vblock`i'_1'
        forvalues j = 2/`nmodels' {
            matrix `vrow' = `vrow', `Vblock`i'_`j''
        }
        if `i' == 1 matrix `Vout' = `vrow'
        else matrix `Vout' = `Vout' \ `vrow'
    }

    local eqused
    forvalues i = 1/`nmodels' {
        local name : word `i' of `names'
        local eq = substr(strtoname("`name'_mean"), 1, 32)
        local duplicate : list posof "`eq'" in eqused
        if `duplicate' {
            local suffix "_m`i'"
            local room = 32-strlen("`suffix'")
            local eq = substr(strtoname("`name'"), 1, `room')+"`suffix'"
            local duplicate : list posof "`eq'" in eqused
            if `duplicate' {
                foreach bridge of local bridges {
                    capture quietly estimates drop `bridge'
                }
                di as err "suest2 could not construct unique equation names for the xtreg, fe system"
                exit 498
            }
        }
        local eqused `"`eqused' `eq'"'
        local eqname`i' `"`eq'"'
        tempname bi
        matrix `bi' = `bsrc`i''
        local eqlist
        forvalues q = 1/`korig`i'' {
            local eqlist `"`eqlist' `eq'"'
        }
        matrix coleq `bi' = `eqlist'
        if `i' == 1 matrix `bout' = `bi'
        else matrix `bout' = `bout', `bi'
    }

    tempname Vtranspose
    matrix `Vtranspose' = `Vout''
    matrix `Vout' = (`Vout' + `Vtranspose')/2

    local beq : coleq `bout'
    local bcn : colnames `bout'
    matrix colnames `Vout' = `bcn'
    matrix rownames `Vout' = `bcn'
    matrix coleq `Vout' = `beq'
    matrix roweq `Vout' = `beq'

    // Prepare a structural factor-variable reference VCE over every
    // nonomitted coefficient.  The exact FE covariance is singular because
    // the displayed intercept is a normalized affine function of the within
    // slopes.  buildfvinfo must therefore see this structural VCE rather than
    // the exact FE VCE when it constructs the estimability matrix H.
    tempname omitall Vfv Vrestore Hxtfe
    quietly _ms_omit_info `bout'
    matrix `omitall' = r(omit)
    local Kout = colsof(`bout')
    matrix `Vfv' = I(`Kout')
    matrix colnames `Vfv' = `bcn'
    matrix rownames `Vfv' = `bcn'
    matrix coleq `Vfv' = `beq'
    matrix roweq `Vfv' = `beq'
    forvalues q = 1/`Kout' {
        if `omitall'[1,`q'] matrix `Vfv'[`q',`q'] = 0
    }

    tempvar tagpanel
    quietly egen byte `tagpanel' = tag(`panelvar') if `union'
    quietly count if `tagpanel'
    local Ngsys = r(N)

    // Post the real result first so buildfvinfo has the same multiple-equation
    // metadata it would see after official suest.  Temporarily substitute the
    // structural VCE, obtain H, and then restore the exact FE covariance.
    matrix `Vrestore' = `Vout'
    ereturn post `bout' `Vout', obs(`Nsys') esample(`union')
    ereturn local cmd "suest"
    ereturn local names `"`names'"'
    forvalues i = 1/`nmodels' {
        ereturn local eqnames`i' `"`eqname`i''"'
    }
    capture quietly ereturn repost V = `Vfv', buildfvinfo
    local hrc = _rc
    if !`hrc' {
        capture quietly _get_hmat `Hxtfe'
        local hrc = _rc
        if !`hrc' local hrc = r(rc)
    }
    capture quietly ereturn repost V = `Vrestore'
    if `hrc' {
        foreach bridge of local bridges {
            capture quietly estimates drop `bridge'
        }
        di as err "suest2 could not construct stable factor-variable estimability information for the xtreg, fe system"
        exit 498
    }
    ereturn matrix suest2_xtfe_H = `Hxtfe', copy
    mata: st_numscalar("__s2_xtferank", rank(st_matrix("`Vout'")))
    ereturn scalar rank = scalar(__s2_xtferank)
    ereturn scalar N_clust = `Gsys'
    ereturn local clustvar `"`scorevar'"'
    ereturn local vce "cluster"
    ereturn local vcetype "Robust"
    ereturn local names `"`names'"'
    ereturn local properties "b V"
    ereturn scalar suest2_xtfe = 1
    ereturn local suest2_xtfe_panelvar `"`panelvar'"'
    ereturn local suest2_xtfe_scorevar `"`scorevar'"'
    ereturn local suest2_xtfe_engine "within_suest_bridge"
    ereturn local suest2_xtfe_displayopts `"`displayopts'"'
    ereturn local title "Simultaneous fixed-effects results"
    ereturn local cmd "suest2_xtfe"

    ereturn scalar N_g = `Ngsys'

    forvalues i = 1/`nmodels' {
        ereturn local eqnames`i' `"`eqname`i''"'
        ereturn scalar suest2_xtfe_N`i' = `N`i''
        ereturn scalar suest2_xtfe_G`i' = `G`i''
        ereturn scalar suest2_xtfe_K`i' = `kfe`i''
        ereturn scalar suest2_xtfe_p`i' = `p`i''
        ereturn scalar suest2_xtfe_native_rank`i' = `nativerank`i''
        ereturn scalar suest2_xtfe_scale`i' = `scale`i''
    }

    foreach bridge of local bridges {
        capture quietly estimates drop `bridge'
    }
end

mata:
void suest2_xtpa_qscore_mata(string scalar yvar, string scalar xbvar,
    string scalar svar, string scalar ivar, string scalar tvar,
    string scalar Rname, real scalar phi, string scalar outvar)
{
    real colvector s, idx, y, xb, id, tt, ord, ids, res, ress, qs, q
    real matrix R, P, Ri
    real scalar i, a, b, n

    s = st_data(., svar)
    idx = selectindex(s :== 1)
    y = st_data(idx, yvar)
    xb = st_data(idx, xbvar)
    id = st_data(idx, ivar)
    R = st_matrix(Rname)

    if (tvar != "") {
        tt = st_data(idx, tvar)
        ord = order((id,tt),(1,2))
    }
    else ord = order(id,1)

    ids = id[ord]
    res = y-xb
    ress = res[ord]
    qs = J(rows(idx),1,.)
    P = panelsetup(ids,1)

    for (i=1; i<=rows(P); i++) {
        a = P[i,1]
        b = P[i,2]
        n = b-a+1
        Ri = R[|1,1\n,n|]
        qs[|a\b|] = invsym(Ri)*ress[|a\b|]/phi
    }

    q = J(rows(idx),1,.)
    q[ord] = qs
    st_store(idx,outvar,q)
}



void suest2_xnbr_scores_mata(
    string scalar yvar,
    string scalar xbvar,
    string scalar panelvar,
    string scalar svar,
    string scalar xvars,
    string scalar scorevars,
    real scalar lnr,
    real scalar lns,
    real scalar ancr,
    real scalar ancs)
{
    real colvector s0, idx, y, xb, id, ord, ids, ys, lambdas, yi, li, qi
    real matrix X, Xs, Ssorted, S, P
    real scalar r, ss, i, a, b, n, Y, A, T, Fr, Fs
    string rowvector vnames

    s0=st_data(.,svar)
    idx=selectindex(s0:==1)
    y=st_data(idx,yvar)
    xb=st_data(idx,xbvar)
    id=st_data(idx,panelvar)
    X=st_data(idx,tokens(xvars))
    r=exp(lnr)
    ss=exp(lns)

    ord=order(id,1)
    ids=id[ord]
    ys=y[ord]
    lambdas=exp(xb[ord])
    Xs=X[ord,.]
    Ssorted=J(rows(idx),cols(X),0)
    P=panelsetup(ids,1)

    for (i=1; i<=rows(P); i++) {
        a=P[i,1]
        b=P[i,2]
        n=b-a+1
        yi=ys[|a\b|]
        li=lambdas[|a\b|]
        Y=quadsum(yi)
        A=quadsum(li)
        T=r+ss+A+Y

        qi=li:*(digamma(r+A)-digamma(T) :+ ///
            digamma(li:+yi) :- digamma(li))
        Ssorted[|a,1\b,cols(X)|]=diag(qi)*Xs[|a,1\b,cols(X)|]

        Fr=digamma(r+ss)+digamma(r+A)-digamma(r)-digamma(T)
        Fs=digamma(r+ss)+digamma(ss+Y)-digamma(ss)-digamma(T)

        /*
        The beta-integrated likelihood factorizes by panel.  Regression
        scores retain their observation contributions.  Each full ancillary
        panel score is divided evenly over the panel observations so that
        panel and valid higher-level cluster sums reproduce the exact panel
        likelihood score without creating an arbitrary first-observation
        dependence.
        */
        Ssorted[|a,ancr\b,ancr|]=J(n,1,r*Fr/n)
        Ssorted[|a,ancs\b,ancs|]=J(n,1,ss*Fs/n)
    }

    S=J(rows(idx),cols(X),.)
    S[ord,.]=Ssorted
    vnames=tokens(scorevars)
    st_store(idx,vnames,S)
}

void suest2_xpgr_scores_mata(
    string scalar yvar,
    string scalar xbvar,
    string scalar groupvar,
    string scalar svar,
    string scalar xvars,
    string scalar scorevars,
    real scalar lnalpha,
    real scalar anc)
{
    real colvector s, idx, y, xb, group, ord, groups, ys, lambdas, yi, li, qi
    real matrix X, Xs, Ssorted, S, P
    real scalar theta, i, a, b, n, Y, Lam, c, f, sa
    string rowvector vnames

    s=st_data(.,svar)
    idx=selectindex(s:==1)
    y=st_data(idx,yvar)
    xb=st_data(idx,xbvar)
    group=st_data(idx,groupvar)
    X=st_data(idx,tokens(xvars))
    theta=exp(-lnalpha)

    ord=order(group,1)
    groups=group[ord]
    ys=y[ord]
    lambdas=exp(xb[ord])
    Xs=X[ord,.]
    Ssorted=J(rows(idx),cols(X),0)
    P=panelsetup(groups,1)

    for (i=1; i<=rows(P); i++) {
        a=P[i,1]
        b=P[i,2]
        n=b-a+1
        yi=ys[|a\b|]
        li=lambdas[|a\b|]
        Y=quadsum(yi)
        Lam=quadsum(li)

        c=(theta+Y)/(theta+Lam)
        qi=yi:-c*li
        Ssorted[|a,1\b,cols(X)|]=diag(qi)*Xs[|a,1\b,cols(X)|]

        f=digamma(theta+Y)-digamma(theta)+log(theta)+1 -
            log(theta+Lam)-(theta+Y)/(theta+Lam)
        sa=-theta*f

        /*
        Native xtpoisson, re robust convention:
        recompute the integrated gamma score at the requested cluster level
        and place the full cluster ancillary score on every observation.
        */
        Ssorted[|a,anc\b,anc|]=J(n,1,sa)
    }

    S=J(rows(idx),cols(X),.)
    S[ord,.]=Ssorted
    vnames=tokens(scorevars)
    st_store(idx,vnames,S)
}

void suest2_xtnbregfe_scores_mata(
    string scalar yvar,
    string scalar xbvar,
    string scalar ivar,
    string scalar svar,
    string scalar xvars,
    string scalar scorevars)
{
    real colvector s, idx, y, xb, id, ord, ids, ys, lambdas, qsorted, yi, li
    real matrix X, Xs, Ssorted, S, P
    real scalar i, a, b, A, Y, c1
    string rowvector vnames

    s=st_data(.,svar)
    idx=selectindex(s:==1)
    y=st_data(idx,yvar)
    xb=st_data(idx,xbvar)
    id=st_data(idx,ivar)
    X=st_data(idx,tokens(xvars))

    ord=order(id,1)
    ids=id[ord]
    ys=y[ord]
    lambdas=exp(xb[ord])
    Xs=X[ord,.]
    qsorted=J(rows(idx),1,.)
    P=panelsetup(ids,1)

    for (i=1; i<=rows(P); i++) {
        a=P[i,1]
        b=P[i,2]
        yi=ys[|a\b|]
        li=lambdas[|a\b|]
        A=quadsum(li)
        Y=quadsum(yi)
        c1=digamma(A)-digamma(A+Y)
        qsorted[|a\b|]=li:*(J(rows(li),1,c1)+digamma(li:+yi)-digamma(li))
    }

    Ssorted=diag(qsorted)*Xs
    S=J(rows(idx),cols(X),.)
    S[ord,.]=Ssorted
    vnames=tokens(scorevars)
    st_store(idx,vnames,S)
}

void suest2_iv2sls_if_mata(
    string scalar samplevar,
    string scalar scorevars,
    string scalar breadname,
    string scalar outvars)
{
    real colvector s, idx
    real matrix S, H, IF
    string rowvector outs

    s=st_data(.,samplevar)
    idx=selectindex(s:==1)
    S=st_data(idx,tokens(scorevars))
    H=st_matrix(breadname)
    IF=S*H
    outs=tokens(outvars)
    st_store(idx,outs,IF)
}

void suest2_iv2sls_vce_mata(
    string scalar unionvar,
    string scalar ifvars,
    string scalar clustvar,
    string scalar outname)
{
    real colvector u, idx, cl, ord
    real matrix IF, IFs, C, info, V

    u=st_data(.,unionvar)
    idx=selectindex(u:==1)
    IF=st_data(idx,tokens(ifvars))

    if (clustvar=="") V=quadcross(IF,IF)
    else {
        cl=st_data(idx,clustvar)
        ord=order(cl,1)
        IFs=IF[ord,.]
        info=panelsetup(cl[ord],1)
        C=panelsum(IFs,info)
        V=quadcross(C,C)
    }
    st_matrix(outname,(V+V')/2)
}


end
