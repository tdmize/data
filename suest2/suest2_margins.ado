*! version 0.1.75  03aug2026  | history: CHANGELOG-suest2.md (repo)
* Candidate 21. LIVE METADATA ON LINE 2, NOT HISTORY -- do not move it to
* the changelog. run_suest2_v0175_full_regression.do:123,
* test_suest2_v0175_marginsdefault_pa.do:191 and
* test_suest2_v0175_marginsdefault.do:246 read THIS LINE as raw text,
* regex it for "candidate ([0-9]+)" and abort below their minimum. rev43
* extracted it with the banner history and the runner exited r(198) at its
* own preflight, so none of its 36 suites ran. Plain * keeps it off -which-.
program define suest2_margins, rclass
    version 16

    if "`e(cmd)'" != "suest2" {
        margins `0'
        return add
        exit
    }

    local raw `"`0'"'
    local names `"`e(names)'"'
    local nmodels = e(suest2_nmodels)

    // Extract every explicit model() selector from predict() options.
    local selected
    local scan `"`raw'"'
    while 1 {
        local p = strpos(lower(`"`scan'"'), "model(")
        if !`p' continue, break
        local rest = substr(`"`scan'"', `p' + 6, .)
        local q = strpos(`"`rest'"', ")")
        if !`q' {
            di as err "invalid model() specification in margins prediction"
            exit 198
        }
        local model = trim(substr(`"`rest'"', 1, `q' - 1))
        local selected `"`selected' `model'"'
        local scan = substr(`"`rest'"', `q' + 1, .)
    }
    local selected : list uniq selected

    // Resolve selected model names to constituent indices.  With no explicit
    // selector, official margins uses e(marginsdefault), which may include all
    // constituent models.
    local indices
    if trim(`"`selected'"') == "" {
        forvalues i = 1/`nmodels' {
            local indices `indices' `i'
        }
    }
    else {
        foreach model of local selected {
            local imodel 0
            capture confirm integer number `model'
            if !_rc {
                if `model' >= 1 & `model' <= `nmodels' local imodel = `model'
            }
            else {
                forvalues i = 1/`nmodels' {
                    local name : word `i' of `names'
                    if `"`model'"' == `"`name'"' local imodel = `i'
                }
            }
            if !`imodel' {
                di as err "model {bf:`model'} was not included in suest2"
                di as err "available models: `names'"
                exit 198
            }
            local indices `indices' `imodel'
        }
        local indices : list uniq indices
    }

    // Mixed-effects systems contain ancillary var()/cov() stripes. Official
    // margins parses those function-like coefficient names during dydx()
    // numerical differentiation and exits with r(133). For homogeneous
    // melogit/meprobit/mecloglog/mepoisson/menbreg/meologit/meoprobit selections use native constituent Jacobians,
    // embed each native Jacobian in the joint parameter vector, and calculate
    // the complete covariance with the suest2 system VCE.
    //
    // CANDIDATE 20. That protection was conditional for melogit and meprobit
    // alone: they reached it only through (`hasdydx' & `allme'), while
    // mecloglog, mepoisson, menbreg, meologit and meoprobit each carried an
    // UNCONDITIONAL flag. mecompare emits an at() unit shift and never the
    // literal "dydx(", so for those two the gate never opened and every
    // random-slope system exited r(133) -- "unknown function var()" --
    // through mecompare while nine sibling families ran.
    //
    // Measured, probe_reslope_v1_0 27aug2026: melogit and meprobit fail at
    // || id: x, at covariance(unstructured), at || id: x z, and at
    // || region: || id: x. The intercept-only control passes all four.
    // probe_meroute_v1_0 PART 2 isolated the switch on one system: dydx
    // alone rc 0, at() alone rc 133, dydx WITH at() rc 0, at() with an
    // explicit predict() rc 133.
    //
    // allmelogit and allmeprobit below give those two the same
    // unconditional flag their siblings already had. The blast radius is
    // exactly melogit and meprobit; `allme' is left inside its conjunction
    // because it also covers eight xt families that are not implicated.
    //
    // This does NOT change the quantity reported. probe_mecestimand_v1_0
    // measured mecompare's constituent against eleven candidates at
    // intpoints 3, 7 and 15: melogit (which falls through today) and
    // mecloglog and mepoisson (which take the native path today) ALL equal
    // the centered unit change under Stata's default prediction, at reldif
    // 0.000e+00, nearest rival 4.6e-04. Both routes compute the same thing.
    //
    // CANDIDATE 21. predict_label, posted at the two sites below, was the
    // hardcoded string "Predicted mean, fixed portion only". It was never
    // value-checked by any instrument, and it was FALSE.
    //
    // Measured: this path reports each constituent's own DEFAULT margins
    // prediction. probe_mecestimand_v1_0 separated the candidates by value
    // -- mepoisson at intpoints 15 returned 0.3894204848584 through
    // mecompare against 0.3641712595445 for the fixed-portion form and
    // 0.4380523857817 for the marginal form, matching the default and
    // neither of the others. probe_meroute_v1_0 then measured that for
    // every me family the default IS the marginal prediction: default and
    // predict(mu marginal) agreed to every printed digit in all eight
    // nonlinear cells. probe_reslope_v2_1 extended the same b-check to
    // mestreg and meglm gamma across twenty further cells.
    //
    // The replacement is deliberately family-agnostic. This path also
    // serves eight xt families and ivregress, where "random effects
    // integrated out" would be wrong or meaningless, and a second
    // hardcoded string that happens to fit the me families would be the
    // same defect wearing different words. What the code knows here is
    // that it asked each model for its default; that is what it now says.
    // What that default MEANS per family belongs in the help file, where
    // it can be stated per family, and mecompare.sthlp now states it.
    local hasdydx = (strpos(lower(`"`raw'"'), "dydx(") > 0)
    local allme 1
    local allmecount 1
    local allmeologit 1
    local allmeoprobit 1
    local allmecloglog 1
    local allmelogit 1
    local allmeprobit 1
    local allxtmlogit 1
    local allxtpa 1
    local allxtlogitfe 1
    local allxtpoissonfe 1
    local allxtpoissonregamma 1
    local allxtnbregrebeta 1
    local allxtnbregfe 1
    local allivregress 1
    local allordinarycat 1
    foreach i of local indices {
        local __s2_cmd `"`e(suest2_cmd`i')'"'
        if `"`__s2_cmd'"'!="xtmlogit" local allxtmlogit 0
        if `"`__s2_cmd'"'!="ivregress" local allivregress 0
        if !inlist(`"`__s2_cmd'"',"logit","logistic","ologit","oprobit","mlogit") local allordinarycat 0
        if !(`"`e(suest2_xtmodel`i')'"'=="pa" & ///
            inlist(`"`__s2_cmd'"',"xtreg","xtlogit","xtprobit","xtcloglog","xtpoisson","xtnbreg")) local allxtpa 0
        if !(`"`__s2_cmd'"'=="xtlogit" & `"`e(suest2_xtmodel`i')'"'=="fe") local allxtlogitfe 0
        if !(`"`__s2_cmd'"'=="xtpoisson" & `"`e(suest2_xtmodel`i')'"'=="fe") local allxtpoissonfe 0
        if !(`"`__s2_cmd'"'=="xtpoisson" & `"`e(suest2_xtmodel`i')'"'=="re" & ///
            lower(trim(`"`e(suest2_distribution`i')'"'))=="gamma") local allxtpoissonregamma 0
        if !(`"`__s2_cmd'"'=="xtnbreg" & `"`e(suest2_xtmodel`i')'"'=="re" & ///
            lower(trim(`"`e(suest2_distribution`i')'"'))=="beta") local allxtnbregrebeta 0
        if !(`"`__s2_cmd'"'=="xtnbreg" & `"`e(suest2_xtmodel`i')'"'=="fe") local allxtnbregfe 0
        if !inlist(`"`__s2_cmd'"', "melogit", "meprobit", "mecloglog", ///
            "mepoisson", "menbreg", "meologit", "meoprobit", "mestreg") & ///
            !inlist(`"`__s2_cmd'"', "xtlogit", "xtprobit", "xtpoisson", "xtnbreg", "xtologit", "xtoprobit", "xtcloglog", "xtmlogit") local allme 0
        if !inlist(`"`e(suest2_cmd`i')'"', "mepoisson", "menbreg") local allmecount 0
        if `"`e(suest2_cmd`i')'"'!="meologit" local allmeologit 0
        if `"`e(suest2_cmd`i')'"'!="meoprobit" local allmeoprobit 0
        if `"`e(suest2_cmd`i')'"'!="mecloglog" local allmecloglog 0
        if `"`e(suest2_cmd`i')'"'!="melogit" local allmelogit 0
        if `"`e(suest2_cmd`i')'"'!="meprobit" local allmeprobit 0
    }
    local ismehetero 0
    capture confirm scalar e(suest2_mehetero)
    if !_rc local ismehetero=e(suest2_mehetero)

    if `allxtnbregrebeta' & strpos(lower(`"`raw'"'),"pr0(") {
        di as err "margins after beta xtnbreg, re does not support pr0(); use predict for observation-level probabilities"
        exit 498
    }

    if `ismehetero' | `allxtmlogit' | `allxtpa' | `allxtlogitfe' | `allxtpoissonfe' | ///
        `allxtpoissonregamma' | ///
        `allxtnbregrebeta' | `allxtnbregfe' | `allivregress' | ///
        (`hasdydx' & `allme') | (`hasdydx' & `allordinarycat' & trim(`"`selected'"')!="") | ///
        `allmecount' | `allmeologit' | ///
        `allmeoprobit' | `allmecloglog' | ///
        `allmelogit' | `allmeprobit' {
        local __s2_postscan = lower(subinstr(`"`raw'"', ",", " ", .))
        local __s2_postscan = itrim(strtrim(`"`__s2_postscan'"'))
        local __s2_wantpost = (strpos(" `__s2_postscan' ", " post ") > 0)

        local __s2_rawarg
        if trim(`"`raw'"') != "" local __s2_rawarg `"raw(`"`raw'"')"'
        capture noisily suest2_margins_me_dydx, indices(`indices') `__s2_rawarg'
        local rc = _rc
        if `rc' exit `rc'

        if `__s2_wantpost' {
            tempname __s2_pb __s2_pV __s2_pJ __s2_rhold
            matrix `__s2_pb' = r(b)
            matrix `__s2_pV' = r(V)
            matrix `__s2_pJ' = r(Jacobian)
            local __s2_pN .
            capture confirm scalar r(N)
            if !_rc local __s2_pN = r(N)

            _return hold `__s2_rhold'
            quietly suest2_margins_me_post `__s2_pb' `__s2_pV' ///
                `__s2_pJ' `__s2_pN' `"`raw'"'
            _return restore `__s2_rhold'
        }

        return add
        exit
    }

    // Official margins can expose only one e(offset)/e(exposure) pair at a
    // time.  This is sufficient for an explicit model() prediction and for
    // multiple predictions that share the same offset/exposure specification.
    local specs
    local target 0
    foreach i of local indices {
        local off `"`e(suest2_offset`i')'"'
        local exp `"`e(suest2_exposure`i')'"'
        if trim(`"`exp'"') != "" {
            local spec `"E:`exp'"'
            if !`target' local target = `i'
            local specs `"`specs' `spec'"'
        }
        else if trim(`"`off'"') != "" {
            local spec `"O:`off'"'
            if !`target' local target = `i'
            local specs `"`specs' `spec'"'
        }
    }
    local specs : list uniq specs
    local nspec : word count `specs'

    if `nspec' > 1 {
        di as err "margins cannot simultaneously apply different constituent offset/exposure specifications"
        di as err "specify one prediction, for example {bf:predict(model(modelname))}"
        di as err "separate margins calls are required for models with different offsets or exposures"
        exit 198
    }

    if !`target' local target : word 1 of indices
    local targetoff `"`e(suest2_offset`target')'"'

    local oldcmd `"`e(margins_cmd)'"'
    local oldoff `"`e(offset)'"'
    local oldexp `"`e(exposure)'"'

    // Delegate a selected CRE prediction to Stata's native CRE margins
    // machinery. Restore the selected constituent estimate, replace only its
    // b and V with the corresponding suest2 block, remove model() from the
    // native predict() syntax, and let _cre_prolog/_xtrecre_p_marg/_cre_epilog
    // operate unchanged.
    local creindices
    foreach i of local indices {
        if `"`e(suest2_xtmodel`i')'"' == "cre" local creindices `creindices' `i'
    }
    local ncre : word count `creindices'

    if `ncre' {
        local nindices : word count `indices'
        if `ncre' != 1 | `nindices' != 1 | trim(`"`selected'"') == "" {
            di as err "CRE margins requires one explicit predict(model()) selection"
            exit 198
        }

        local crei : word 1 of `creindices'
        local source `"`e(suest2_hold`crei')'"'
        local start = e(suest2_start`crei')
        local korig = e(suest2_korig`crei')
        local end = `start' + `korig' - 1

        tempname systemsave bsys Vsys bwork Vwork
        quietly estimates store `systemsave'
        matrix `bsys' = e(b)
        matrix `Vsys' = e(V)
        matrix `bwork' = `bsys'[1,`start'..`end']
        matrix `Vwork' = `Vsys'[`start'..`end',`start'..`end']

        capture quietly estimates restore `source'
        local rcrestore = _rc
        if `rcrestore' {
            capture quietly estimates restore `systemsave'
            capture quietly estimates drop `systemsave'
            di as err "unable to restore the selected CRE constituent estimate"
            exit `rcrestore'
        }

        if colsof(e(b)) != `korig' {
            capture quietly estimates restore `systemsave'
            capture quietly estimates drop `systemsave'
            di as err "the selected CRE constituent has an unexpected coefficient count"
            exit 498
        }

        local nativecn : colnames e(b)
        local nativeeq : coleq e(b)
        matrix colnames `bwork' = `nativecn'
        matrix rownames `Vwork' = `nativecn'
        matrix colnames `Vwork' = `nativecn'
        matrix coleq `bwork' = `nativeeq'
        matrix roweq `Vwork' = `nativeeq'
        matrix coleq `Vwork' = `nativeeq'
        quietly suest2_margins_cre_native_repost `bwork' `Vwork'

        // Strip every model(...) selector before handing predict() to the
        // native xtreg, cre predictor.
        local creargs `"`raw'"'
        while 1 {
            local low = lower(`"`creargs'"')
            local p = strpos(`"`low'"', "model(")
            if !`p' continue, break
            local rest = substr(`"`creargs'"', `p' + 6, .)
            local q = strpos(`"`rest'"', ")")
            if !`q' {
                capture quietly estimates restore `systemsave'
                capture quietly estimates drop `systemsave'
                di as err "invalid model() specification in CRE margins prediction"
                exit 198
            }
            local before = substr(`"`creargs'"', 1, `p' - 1)
            local after = substr(`"`rest'"', `q' + 1, .)
            local creargs `"`before'`after'"'
        }

        capture noisily margins `creargs'
        local rc = _rc
        local posted = (`rc'==0 & "`e(cmd)'"=="margins")

        tempname rhold
        _return hold `rhold'

        local rcsystem 0
        if !`posted' {
            capture quietly estimates restore `systemsave'
            local rcsystem = _rc
        }
        capture quietly estimates drop `systemsave'

        _return restore `rhold'
        return add

        if `rcsystem' exit `rcsystem'
        exit `rc'
    }

    // The active-system predictor adds offsets from e(suest2_offset#).
    // Native margins, however, evaluates count-model means with the offset
    // set to zero (and exposure set to one). Temporarily suppress the stored
    // constituent offset for every selected prediction, then restore it.
    foreach i of local indices {
        local oldmodeloff`i' `"`e(suest2_offset`i')'"'
        if trim(`"`oldmodeloff`i''"') != "" {
            quietly suest2_margins_model_offset_set `i' ""
        }
    }

    quietly suest2_margins_set "margins" `"`targetoff'"' ""
    capture noisily margins `0'
    local rc = _rc

    tempname rhold
    _return hold `rhold'
    foreach i of local indices {
        quietly suest2_margins_model_offset_set `i' `"`oldmodeloff`i''"'
    }
    quietly suest2_margins_set `"`oldcmd'"' `"`oldoff'"' `"`oldexp'"'
    _return restore `rhold'
    return add

    exit `rc'
end


program define suest2_margins_cre_native_repost, eclass
    version 16
    args b V
    ereturn repost b=`b' V=`V', rename
end

program define suest2_margins_set, eclass
    version 16
    args marginscmd offset exposure
    ereturn local margins_cmd `"`marginscmd'"'
    ereturn local offset `"`offset'"'
    ereturn local exposure `"`exposure'"'
end

program define suest2_margins_model_offset_set, eclass
    version 16
    args index offset
    ereturn local suest2_offset`index' `"`offset'"'
end

program define suest2_margins_me_dydx, rclass
    version 16
    syntax, INDICES(numlist integer) [RAW(string)]

    // Nested native margins calls may clear or recycle caller tempname
    // matrices. Allocate explicit names for every matrix that must survive
    // those calls, and clean them manually on every exit path.
    capture confirm scalar __suest2_marg_counter
    if _rc scalar __suest2_marg_counter = 0
    scalar __suest2_marg_counter = scalar(__suest2_marg_counter) + 1
    local __s2_seq = scalar(__suest2_marg_counter)
    local __s2_prefix "__s2md`__s2_seq'"
    local bsys   "`__s2_prefix'b"
    local Vsys   "`__s2_prefix'V"
    local bpiece "`__s2_prefix'p"
    local Jpiece "`__s2_prefix'j"
    local Fpiece "`__s2_prefix'f"
    local bjoint "`__s2_prefix'B"
    local Jjoint "`__s2_prefix'J"
    local Vjoint "`__s2_prefix'W"
    local table  "`__s2_prefix't"
    local bpost  "`__s2_prefix'x"
    local Vpost  "`__s2_prefix'y"
    local Jpost  "`__s2_prefix'z"
    // at()-filter working matrices (candidate 18): the fill call's value and
    // Jacobian row, and the full-layout piece under assembly.  Managed only
    // by the filter block, which drops them on success and on every refusal
    // path it owns; they never survive into the pre-existing error paths.
    local bfill  "`__s2_prefix'q"
    local Jfill  "`__s2_prefix'r"
    local bnew   "`__s2_prefix'n"
    local Jnew   "`__s2_prefix'm"

    foreach M in `bsys' `Vsys' `bpiece' `Jpiece' `Fpiece' ///
        `bjoint' `Jjoint' `Vjoint' `table' `bpost' `Vpost' `Jpost' ///
        `bfill' `Jfill' `bnew' `Jnew' {
        capture matrix drop `M'
    }

    matrix `bsys' = e(b)
    matrix `Vsys' = e(V)
    local K = colsof(`bsys')
    local names `"`e(names)'"'
    local Nsys .
    capture confirm scalar e(N)
    if !_rc local Nsys = e(N)

    quietly estimates dir
    local __s2_allest `" `r(names)' "'
    local __s2_serial 1
    while strpos(`"`__s2_allest'"', " __s2marg`__s2_serial' ") {
        local ++__s2_serial
    }
    local systemsave "__s2marg`__s2_serial'"
    quietly estimates store `systemsave'

    local hasmeologit 0
    local hasmeoprobit 0
    local hasxtologit 0
    local hasxtoprobit 0
    local allmestreg 1
    local allxtgre 1
    local allxtmlogit 1
    local allivregress 1
    foreach i of numlist `indices' {
        if `"`e(suest2_cmd`i')'"'=="meologit" local hasmeologit 1
        if `"`e(suest2_cmd`i')'"'=="meoprobit" local hasmeoprobit 1
        if `"`e(suest2_cmd`i')'"'=="xtologit" local hasxtologit 1
        if `"`e(suest2_cmd`i')'"'=="xtoprobit" local hasxtoprobit 1
        if `"`e(suest2_cmd`i')'"'!="mestreg" local allmestreg 0
        if `"`e(suest2_cmd`i')'"'!="xtmlogit" local allxtmlogit 0
        if `"`e(suest2_cmd`i')'"'!="ivregress" local allivregress 0
        if !inlist(`"`e(suest2_cmd`i')'"',"xtreg","xtlogit","xtprobit","xtpoisson","xtnbreg","xtologit","xtoprobit","xtcloglog","xtmlogit") local allxtgre 0
    }

    // Reparse the margins option list with Stata's syntax command. predict()
    // and post are removed explicitly; every other margins option is retained
    // verbatim in local options by *. This avoids hand-parsing nested model().
    local 0 `"`raw'"'
    capture syntax [anything(name=before)] [, PREDICT(string asis) POST *]
    local rcsyntax = _rc
    if `rcsyntax' {
        capture quietly estimates restore `systemsave'
        capture quietly estimates drop `systemsave'
        foreach M in `bsys' `Vsys' `bpiece' `Jpiece' `Fpiece' ///
            `bjoint' `Jjoint' `Vjoint' `table' `bpost' `Vpost' `Jpost' {
            capture matrix drop `M'
        }
        exit `rcsyntax'
    }

    // A margins option list may carry more than one predict().  Stata's syntax
    // binds the first to PREDICT() and sweeps the remainder into options via *,
    // so without the split below those extra specifications reach native
    // margins with model() still attached and the native command rejects
    // model() as an unknown prediction option.  Split them out, key each to the
    // model it names, and leave the remaining option list free of predict().
    local s2nspec 0
    if trim(`"`predict'"') != "" {
        local ++s2nspec
        local s2spec`s2nspec' `"`predict'"'
    }
    local s2rest
    local s2scan `"`options'"'
    while 1 {
        local s2p = strpos(lower(`"`s2scan'"'), "predict(")
        if !`s2p' {
            local s2rest `"`s2rest' `s2scan'"'
            continue, break
        }
        local s2head = substr(`"`s2scan'"', 1, `s2p' - 1)
        local s2tail = substr(`"`s2scan'"', `s2p' + 8, .)
        local s2depth 1
        local s2j 0
        local s2len = length(`"`s2tail'"')
        while (`s2depth' > 0) & (`s2j' < `s2len') {
            local ++s2j
            local s2ch = substr(`"`s2tail'"', `s2j', 1)
            if `"`s2ch'"' == "(" local ++s2depth
            if `"`s2ch'"' == ")" local --s2depth
        }
        if `s2depth' > 0 {
            capture quietly estimates restore `systemsave'
            capture quietly estimates drop `systemsave'
            foreach M in `bsys' `Vsys' `bpiece' `Jpiece' `Fpiece' ///
                `bjoint' `Jjoint' `Vjoint' `table' `bpost' `Vpost' `Jpost' {
                capture matrix drop `M'
            }
            di as err "unbalanced parentheses in a margins predict() specification"
            exit 198
        }
        local ++s2nspec
        local s2spec`s2nspec' = trim(substr(`"`s2tail'"', 1, `s2j' - 1))
        local s2rest `"`s2rest' `s2head'"'
        local s2scan = substr(`"`s2tail'"', `s2j' + 1, .)
    }
    local s2allpred
    forvalues s2s = 1/`s2nspec' {
        local s2sp `"`s2spec`s2s''"'
        local s2allpred `"`s2allpred' `s2sp'"'
        local s2mi 0
        local s2mp = strpos(lower(`"`s2sp'"'), "model(")
        if `s2mp' {
            local s2mr = substr(`"`s2sp'"', `s2mp' + 6, .)
            local s2mq = strpos(`"`s2mr'"', ")")
            if `s2mq' {
                local s2mn = trim(substr(`"`s2mr'"', 1, `s2mq' - 1))
                foreach s2i of numlist `indices' {
                    local s2nm : word `s2i' of `names'
                    if `"`s2mn'"' == `"`s2nm'"' local s2mi = `s2i'
                    if `"`s2mn'"' == `"`s2i'"' local s2mi = `s2i'
                }
            }
        }
        if `s2mi' local s2predfor`s2mi' `"`s2sp'"'
    }
    local s2predbase `"`predict'"'

    // The checks below reject an unsupported request for the system as a
    // whole, so they inspect every specification rather than only the first.
    local lowpredict = lower(trim(`"`s2allpred'"'))
    if (`hasmeologit' | `hasmeoprobit' | `hasxtologit' | `hasxtoprobit') & strpos(`"`lowpredict'"',"nooffset") {
        capture quietly estimates restore `systemsave'
        capture quietly estimates drop `systemsave'
        foreach M in `bsys' `Vsys' `bpiece' `Jpiece' `Fpiece' ///
            `bjoint' `Jjoint' `Vjoint' `table' `bpost' `Vpost' `Jpost' {
            capture matrix drop `M'
        }
        local orderedcmd "meologit"
        if `hasmeoprobit' local orderedcmd "meoprobit"
        if `hasxtologit' local orderedcmd "xtologit"
        if `hasxtoprobit' local orderedcmd "xtoprobit"
        di as err "`orderedcmd' margins does not support nooffset"
        di as err "native `orderedcmd' nooffset probabilities are not internally coherent for offset models"
        exit 198
    }
    if strpos(`"`lowpredict'"', "conditional(") & !strpos(`"`lowpredict'"', "conditional(fixedonly)") {
        capture quietly estimates restore `systemsave'
        capture quietly estimates drop `systemsave'
        foreach M in `bsys' `Vsys' `bpiece' `Jpiece' `Fpiece' ///
            `bjoint' `Jjoint' `Vjoint' `table' `bpost' `Vpost' `Jpost' {
            capture matrix drop `M'
        }
        di as err "mixed-model margins does not support empirical-Bayes conditional predictions"
        di as err "use the native marginal prediction or conditional(fixedonly)"
        exit 198
    }
    if (strpos(`"`lowpredict'"', "xb") & !`allmestreg' & !`allxtgre' & !`allivregress') | ///
        strpos(`"`lowpredict'"', "legacy") {
        capture quietly estimates restore `systemsave'
        capture quietly estimates drop `systemsave'
        foreach M in `bsys' `Vsys' `bpiece' `Jpiece' `Fpiece' ///
            `bjoint' `Jjoint' `Vjoint' `table' `bpost' `Vpost' `Jpost' {
            capture matrix drop `M'
        }
        di as err "mixed-model dydx() supports validated native response definitions; mestreg and Gaussian nonlinear xt bridges also support xb"
        exit 198
    }
    local nativebefore `"`before'"'
    // s2rest is the option list with every predict() removed.  Passing
    // `options' here is what leaked a second predict(model()) into the
    // native call.
    local nativeopts `"`s2rest'"'
    local isdydx = (strpos(lower(`"`raw'"'), "dydx(") > 0)

    // at()-filter: parse the at() specs ONCE, before the model loop -- they
    // do not vary by model.  Classification against each model, and the
    // removal of DROP specs from its call, happen inside the loop.  s() is
    // copied to locals immediately after every helper call, and atvars
    // clobbers r() (it runs numlist), which is safe here: nothing reads r()
    // between this block and the next margins call.  On any helper failure
    // s2atn stays 0 and the filter is silently skipped, leaving the call
    // string nativeopts byte-for-byte -- the filter must never change an
    // outcome it cannot classify.
    local s2atn 0
    local s2atrest
    if trim(`"`nativeopts'"') != "" {
        capture suest2_margins_atsplit `"`nativeopts'"'
        if !_rc {
            local s2atn `s(n_at)'
            local s2atrest `"`s(rest)'"'
            forvalues s2k = 1/`s2atn' {
                local s2at`s2k' `"`s(at`s2k')'"'
            }
        }
    }
    forvalues s2k = 1/`s2atn' {
        capture suest2_margins_atvars `"`s2at`s2k''"'
        if _rc {
            local s2atv`s2k'
            local s2atc`s2k' .
        }
        else {
            local s2atv`s2k' `"`s(lhsvars)' `s(statvars)'"'
            local s2atv`s2k' = itrim(trim(`"`s2atv`s2k''"'))
            local s2atc`s2k' `"`s(count)'"'
        }
    }

    local first 1
    foreach i of numlist `indices' {
        capture quietly estimates restore `systemsave'
        local rcsystem = _rc
        if `rcsystem' {
            capture quietly estimates drop `systemsave'
            foreach M in `bsys' `Vsys' `bpiece' `Jpiece' `Fpiece' ///
                `bjoint' `Jjoint' `Vjoint' `table' `bpost' `Vpost' `Jpost' {
                capture matrix drop `M'
            }
            exit `rcsystem'
        }

        local source `"`e(suest2_hold`i')'"'
        local start = e(suest2_start`i')
        local korig = e(suest2_korig`i')
        local syscmd `"`e(suest2_cmd`i')'"'
        local sysoutcomes `"`e(suest2_outcomes`i')'"'
        local name : word `i' of `names'

        capture quietly estimates restore `source'
        local rcrest = _rc
        if `rcrest' {
            capture quietly estimates restore `systemsave'
            capture quietly estimates drop `systemsave'
            foreach M in `bsys' `Vsys' `bpiece' `Jpiece' `Fpiece' ///
                `bjoint' `Jjoint' `Vjoint' `table' `bpost' `Vpost' `Jpost' {
                capture matrix drop `M'
            }
            di as err "unable to restore constituent model {bf:`name'} for margins"
            exit `rcrest'
        }

        // Use the predict() specification that names THIS model when the
        // caller supplied one.  s2predbase is the fallback so that a single
        // specification, or none, reproduces the previous behaviour exactly
        // and no iteration inherits the value another iteration left behind.
        if trim(`"`s2predfor`i''"') != "" local predict `"`s2predfor`i''"'
        else local predict `"`s2predbase'"'
        local lowpredict = lower(trim(`"`predict'"'))

        local nativegeneric=(`"`e(cmd2)'"'=="meglm")
        local nativepred
        if `"`syscmd'"'=="mixed" local nativepred
        else if `nativegeneric' {
            local predinner `"`predict'"'
            while 1 {
                local predlower=lower(`"`predinner'"')
                local mp=strpos(`"`predlower'"',"model(")
                if !`mp' continue, break
                local mrest=substr(`"`predinner'"',`mp'+6,.)
                local mq=strpos(`"`mrest'"',")")
                if !`mq' {
                    capture quietly estimates restore `systemsave'
                    capture quietly estimates drop `systemsave'
                    di as err "invalid model() specification in meglm margins prediction"
                    exit 198
                }
                local mbefore=substr(`"`predinner'"',1,`mp'-1)
                local mafter=substr(`"`mrest'"',`mq'+1,.)
                local predinner `"`mbefore' `mafter'"'
            }
            local predinner=itrim(trim(`"`predinner'"'))
            if trim(`"`predinner'"')!="" local nativepred `"predict(`predinner')"'
        }
        else if inlist(`"`syscmd'"',"melogit","meprobit","mecloglog","mepoisson","menbreg","meologit","meoprobit") {
            local predinner `"`predict'"'
            while 1 {
                local predlower=lower(`"`predinner'"')
                local mp=strpos(`"`predlower'"',"model(")
                if !`mp' continue, break
                local mrest=substr(`"`predinner'"',`mp'+6,.)
                local mq=strpos(`"`mrest'"',")")
                if !`mq' {
                    capture quietly estimates restore `systemsave'
                    capture quietly estimates drop `systemsave'
                    di as err "invalid model() specification in `syscmd' margins prediction"
                    exit 198
                }
                local mbefore=substr(`"`predinner'"',1,`mp'-1)
                local mafter=substr(`"`mrest'"',`mq'+1,.)
                local predinner `"`mbefore' `mafter'"'
            }
            local predinner=itrim(trim(`"`predinner'"'))
            if trim(`"`predinner'"')!="" local nativepred `"predict(`predinner')"'
        }
        else if inlist(`"`syscmd'"',"logit","logistic","ologit","oprobit","mlogit") {
            local predinner `"`predict'"'
            while 1 {
                local predlower=lower(`"`predinner'"')
                local mp=strpos(`"`predlower'"',"model(")
                if !`mp' continue, break
                local mrest=substr(`"`predinner'"',`mp'+6,.)
                local mq=strpos(`"`mrest'"',")")
                if !`mq' {
                    capture quietly estimates restore `systemsave'
                    capture quietly estimates drop `systemsave'
                    di as err "invalid model() specification in `syscmd' margins prediction"
                    exit 198
                }
                local mbefore=substr(`"`predinner'"',1,`mp'-1)
                local mafter=substr(`"`mrest'"',`mq'+1,.)
                local predinner `"`mbefore' `mafter'"'
            }
            local predinner=itrim(trim(`"`predinner'"'))
            if trim(`"`predinner'"')=="" local nativepred
            else local nativepred `"predict(`predinner')"'
        }
        else if `"`syscmd'"'=="ivregress" {
            local predinner `"`predict'"'
            while 1 {
                local predlower=lower(`"`predinner'"')
                local mp=strpos(`"`predlower'"',"model(")
                if !`mp' continue, break
                local mrest=substr(`"`predinner'"',`mp'+6,.)
                local mq=strpos(`"`mrest'"',")")
                if !`mq' {
                    capture quietly estimates restore `systemsave'
                    capture quietly estimates drop `systemsave'
                    di as err "invalid model() specification in ivregress margins prediction"
                    exit 198
                }
                local mbefore=substr(`"`predinner'"',1,`mp'-1)
                local mafter=substr(`"`mrest'"',`mq'+1,.)
                local predinner `"`mbefore' `mafter'"'
            }
            local predinner=itrim(trim(`"`predinner'"'))
            if trim(`"`predinner'"')=="" local nativepred
            else if lower(`"`predinner'"')=="xb" local nativepred "predict(xb)"
            else {
                capture quietly estimates restore `systemsave'
                capture quietly estimates drop `systemsave'
                di as err "ivregress margins supports only the native default or xb prediction"
                exit 198
            }
        }
        else if `"`syscmd'"'=="xtmlogit" {
            local predinner `"`predict'"'
            while 1 {
                local predlower=lower(`"`predinner'"')
                local mp=strpos(`"`predlower'"',"model(")
                if !`mp' continue, break
                local mrest=substr(`"`predinner'"',`mp'+6,.)
                local mq=strpos(`"`mrest'"',")")
                if !`mq' {
                    capture quietly estimates restore `systemsave'
                    capture quietly estimates drop `systemsave'
                    di as err "invalid model() specification in xtmlogit margins prediction"
                    exit 198
                }
                local mbefore=substr(`"`predinner'"',1,`mp'-1)
                local mafter=substr(`"`mrest'"',`mq'+1,.)
                local predinner `"`mbefore' `mafter'"'
            }
            local predinner=itrim(trim(`"`predinner'"'))
            if trim(`"`predinner'"')=="" local nativepred
            else local nativepred `"predict(`predinner')"'
        }
        else if inlist(`"`syscmd'"',"xtreg","xtlogit","xtprobit","xtpoisson","xtnbreg","xtologit","xtoprobit","xtcloglog") {
            local predinner `"`predict'"'
            while 1 {
                local predlower=lower(`"`predinner'"')
                local mp=strpos(`"`predlower'"',"model(")
                if !`mp' continue, break
                local mrest=substr(`"`predinner'"',`mp'+6,.)
                local mq=strpos(`"`mrest'"',")")
                if !`mq' {
                    capture quietly estimates restore `systemsave'
                    capture quietly estimates drop `systemsave'
                    di as err "invalid model() specification in `syscmd' margins prediction"
                    exit 198
                }
                local mbefore=substr(`"`predinner'"',1,`mp'-1)
                local mafter=substr(`"`mrest'"',`mq'+1,.)
                local predinner `"`mbefore' `mafter'"'
            }
            local predinner=itrim(trim(`"`predinner'"'))
            if trim(`"`predinner'"')=="" {
                if `"`e(model)'"'=="pa" local nativepred
                else if `"`syscmd'"'=="xtlogit" & `"`e(model)'"'=="fe" local nativepred "predict(pu0)"
                else if inlist(`"`syscmd'"',"xtlogit","xtprobit") local nativepred "predict(pr)"
                else if `"`syscmd'"'=="xtpoisson" & `"`e(model)'"'=="fe" local nativepred
                else if `"`syscmd'"'=="xtpoisson" & `"`e(model)'"'=="re" & ///
                    lower(trim(`"`e(distrib)'"'))=="gamma" local nativepred
                else if `"`syscmd'"'=="xtnbreg" & `"`e(model)'"'=="fe" local nativepred
                else if `"`syscmd'"'=="xtpoisson" local nativepred "predict(n)"
                else if `"`syscmd'"'=="xtcloglog" local nativepred "predict(pr)"
                else local nativepred
            }
            else local nativepred `"predict(`predinner')"'
        }
        else if `"`syscmd'"'=="mestreg" {
            local predinner `"`predict'"'
            while 1 {
                local predlower=lower(`"`predinner'"')
                local mp=strpos(`"`predlower'"',"model(")
                if !`mp' continue, break
                local mrest=substr(`"`predinner'"',`mp'+6,.)
                local mq=strpos(`"`mrest'"',")")
                if !`mq' {
                    capture quietly estimates restore `systemsave'
                    capture quietly estimates drop `systemsave'
                    di as err "invalid model() specification in mestreg margins prediction"
                    exit 198
                }
                local mbefore=substr(`"`predinner'"',1,`mp'-1)
                local mafter=substr(`"`mrest'"',`mq'+1,.)
                local predinner `"`mbefore' `mafter'"'
            }
            local predinner=itrim(trim(`"`predinner'"'))
            if trim(`"`predinner'"')=="" local nativepred
            else {
                if strpos(lower(`"`predinner'"'),"fixedonly") & ///
                    !strpos(lower(`"`predinner'"'),"conditional(fixedonly)") {
                    capture quietly estimates restore `systemsave'
                    capture quietly estimates drop `systemsave'
                    di as err "mestreg uses conditional(fixedonly), not fixedonly"
                    exit 198
                }
                local nativepred `"predict(`predinner')"'
            }
        }
        else if `"`syscmd'"'=="mecloglog" & strpos(`"`lowpredict'"', "nooffset") {
            local nativepred "predict(mu fixedonly nooffset)"
        }
        else if inlist(`"`syscmd'"', "mepoisson", "menbreg") {
            local nativepred "predict(mu conditional(fixedonly))"
            if strpos(`"`lowpredict'"', "nooffset") local nativepred "predict(mu conditional(fixedonly) nooffset)"
        }
        else if inlist(`"`syscmd'"',"megaussian","megamma") & strpos(`"`lowpredict'"',"nooffset") {
            local nativepred "predict(mu fixedonly nooffset)"
        }
        else if inlist(`"`syscmd'"',"meologit","meoprobit") {
            if strpos(`"`lowpredict'"',"mu") {
                capture quietly estimates restore `systemsave'
                capture quietly estimates drop `systemsave'
                foreach M in `bsys' `Vsys' `bpiece' `Jpiece' `Fpiece' ///
                    `bjoint' `Jjoint' `Vjoint' `table' `bpost' `Vpost' `Jpost' {
                    capture matrix drop `M'
                }
                di as err "option mu is not allowed for `syscmd' margins; use pr"
                exit 198
            }

            local predinner `"`predict'"'
            while 1 {
                local predlower=lower(`"`predinner'"')
                local mp=strpos(`"`predlower'"',"model(")
                if !`mp' continue, break
                local mrest=substr(`"`predinner'"',`mp'+6,.)
                local mq=strpos(`"`mrest'"',")")
                if !`mq' {
                    capture quietly estimates restore `systemsave'
                    capture quietly estimates drop `systemsave'
                    di as err "invalid model() specification in `syscmd' margins prediction"
                    exit 198
                }
                local mbefore=substr(`"`predinner'"',1,`mp'-1)
                local mafter=substr(`"`mrest'"',`mq'+1,.)
                local predinner `"`mbefore' `mafter'"'
            }
            local predinner=itrim(trim(`"`predinner'"'))

            if trim(`"`predinner'"')=="" {
                local nativepred
                foreach out of local sysoutcomes {
                    if `nativegeneric' local nativepred `"`nativepred' predict(mu outcome(`out') fixedonly)"'
                    else local nativepred `"`nativepred' predict(pr outcome(`out') conditional(fixedonly))"'
                }
            }
            else {
                local predlower=lower(`"`predinner'"')
                if strpos(`"`predlower'"',"fixedonly") & !strpos(`"`predlower'"',"conditional(fixedonly)") {
                    capture quietly estimates restore `systemsave'
                    capture quietly estimates drop `systemsave'
                    di as err "`syscmd' uses conditional(fixedonly), not fixedonly"
                    exit 198
                }
                if `nativegeneric' {
                    local outspec
                    if regexm(`"`predinner'"',"outcome\(([^)]+)\)") {
                        local outspec `"`=regexs(1)'"'
                    }
                    if trim(`"`outspec'"')=="" local outspec "#1"
                    if substr(trim(`"`outspec'"'),1,1)=="#" {
                        local outpos=real(substr(trim(`"`outspec'"'),2,.))
                        local outspec : word `outpos' of `sysoutcomes'
                    }
                    local nativepred `"predict(mu outcome(`outspec') fixedonly)"'
                }
                else {
                    if !strpos(`"`predlower'"',"pr") local predinner `"pr `predinner'"'
                    if !strpos(lower(`"`predinner'"'),"conditional(") {
                        local predinner `"`predinner' conditional(fixedonly)"'
                    }
                    local nativepred `"predict(`predinner')"'
                }
            }
        }
        // at()-filter (candidate 18, increment (e)): classify this model's
        // at() specs, refuse what cannot be answered correctly, remove the
        // DROP specs from the native call, and (below, after the call)
        // rebuild the piece to the full layout.  When nothing is dropped,
        // s2useopts is nativeopts BYTE-FOR-BYTE.  A model whose covariates
        // cannot be read is left unfiltered for native margins to judge.
        // The display uses plain di, which a caller's quietly suppresses.
        local s2useopts `"`nativeopts'"'
        local s2dropn 0
        local s2keepn 0
        if `s2atn' > 0 {
            capture suest2_margins_ebvars
            local s2rcvars = _rc
            local s2mvars
            if !`s2rcvars' local s2mvars `"`s(vars)'"'
            local s2canclass = (!`s2rcvars' & trim(`"`s2mvars'"') != "")
            local s2mixn 0
            local s2unc 0
            local s2mixat
            local s2uncat
            forvalues s2k = 1/`s2atn' {
                local s2sv `"`s2atv`s2k''"'
                local s2cls`s2k' KEEP
                if `s2canclass' & trim(`"`s2sv'"') != "" {
                    local s2for : list s2sv - s2mvars
                    local s2nat : list s2sv & s2mvars
                    if `"`s2for'"' == "" local s2cls`s2k' KEEP
                    else if `"`s2nat'"' == "" local s2cls`s2k' DROP
                    else local s2cls`s2k' MIXED
                }
                if "`s2cls`s2k''" == "KEEP" local ++s2keepn
                if "`s2cls`s2k''" == "DROP" local ++s2dropn
                if "`s2cls`s2k''" == "MIXED" {
                    local ++s2mixn
                    local s2mixat `"`s2at`s2k''"'
                }
                if `"`s2atc`s2k''"' == "." {
                    local s2unc 1
                    local s2uncat `"`s2at`s2k''"'
                }
            }
            if `s2dropn' > 0 {
                di as text "at()-filter, model " as result "`name'" ///
                    as text " (dropped specs filled from the model's own margins)"
            }
            else {
                di as text "at()-filter, model " as result "`name'" ///
                    as text " (nothing dropped; call unchanged)"
            }
            di as text "    model covariates: " as result "`s2mvars'"
            forvalues s2k = 1/`s2atn' {
                di as text "    at " as result "`s2k'" as text ": " ///
                    as result `"`s2at`s2k''"' ///
                    as text "  ->  " as result "`s2cls`s2k''" ///
                    as text "  positions " as result `"`s2atc`s2k''"'
            }
            di as text "    summary: " as result "`s2keepn'" ///
                as text " keep, " as result "`s2dropn'" ///
                as text " drop, " as result "`s2mixn'" as text " mixed"
            if `s2mixn' > 0 {
                capture quietly estimates restore `systemsave'
                capture quietly estimates drop `systemsave'
                foreach M in `bsys' `Vsys' `bpiece' `Jpiece' `Fpiece' ///
                    `bjoint' `Jjoint' `Vjoint' `table' `bpost' `Vpost' `Jpost' ///
                    `bfill' `Jfill' `bnew' `Jnew' {
                    capture matrix drop `M'
                }
                di as err "the at() specification {bf:at(`s2mixat')} names both " ///
                    "variables model {bf:`name'} contains and variables it lacks"
                di as err "filtering inside one at() is not supported; use " ///
                    "covariate values every model contains, or compare the " ///
                    "models one at a time"
                exit 198
            }
            if `s2unc' & `s2dropn' > 0 {
                capture quietly estimates restore `systemsave'
                capture quietly estimates drop `systemsave'
                foreach M in `bsys' `Vsys' `bpiece' `Jpiece' `Fpiece' ///
                    `bjoint' `Jjoint' `Vjoint' `table' `bpost' `Vpost' `Jpost' ///
                    `bfill' `Jfill' `bnew' `Jnew' {
                    capture matrix drop `M'
                }
                di as err "cannot count the at() positions of " ///
                    `"{bf:at(`s2uncat')}"'
                di as err "with differing predictors every at() position " ///
                    "count is needed to map the results; refusing rather " ///
                    "than guess"
                exit 198
            }
            if `s2dropn' > 0 {
                local s2useopts
                forvalues s2k = 1/`s2atn' {
                    if "`s2cls`s2k''" != "DROP" ///
                        local s2useopts `"`s2useopts' at(`s2at`s2k'')"'
                }
                local s2useopts `"`s2useopts' `s2atrest'"'
                local s2useopts = itrim(trim(`"`s2useopts'"'))
            }
        }
        if trim(`"`nativebefore'"')=="" {
            if trim(`"`s2useopts' `nativepred'"')=="" capture quietly margins
            else capture quietly margins, `s2useopts' `nativepred'
        }
        else {
            if trim(`"`s2useopts' `nativepred'"')=="" capture quietly margins `nativebefore'
            else capture quietly margins `nativebefore', `s2useopts' `nativepred'
        }
        local rcmarg = _rc
        if `rcmarg' {
            // candidate 19: while the constituent is still the active
            // estimate, test the reload signature before cleaning up
            local esampn .
            capture quietly count if e(sample)
            if !_rc local esampn = r(N)
            capture quietly estimates restore `systemsave'
            capture quietly estimates drop `systemsave'
            foreach M in `bsys' `Vsys' `bpiece' `Jpiece' `Fpiece' ///
                `bjoint' `Jjoint' `Vjoint' `table' `bpost' `Vpost' `Jpost' {
                capture matrix drop `M'
            }
            if `esampn' == 0 {
                di as err "native margins failed for constituent model " ///
                    "{bf:`name'}: its e(sample) identifies no observations"
                di as err "the data in memory changed since the models " ///
                    "were stored -- any reload clears a stored estimate's " ///
                    "sample, even reloading the same file. Re-run " ///
                    "{cmd:suest2} with the estimation data in memory."
            }
            else di as err "native margins failed for constituent model {bf:`name'}"
            exit `rcmarg'
        }

        matrix `bpiece' = r(b)
        matrix `Jpiece' = r(Jacobian)
        local q = colsof(`bpiece')
        if rowsof(`Jpiece') != `q' | colsof(`Jpiece') != `korig' {
            capture quietly estimates restore `systemsave'
            capture quietly estimates drop `systemsave'
            foreach M in `bsys' `Vsys' `bpiece' `Jpiece' `Fpiece' ///
                `bjoint' `Jjoint' `Vjoint' `table' `bpost' `Vpost' `Jpost' {
                capture matrix drop `M'
            }
            di as err "constituent margins returned an unexpected Jacobian layout"
            exit 498
        }

        // at()-filter assembly (candidate 18): rebuild this model's piece to
        // the FULL at() layout.  Kept blocks are copied from the keeper run
        // in spec order (dropping a spec renumbers but never reorders the
        // survivors -- measured, diag_atfilter_design PART C); dropped
        // blocks replicate the fill call's single value and Jacobian row
        // (equal to the ordinary route's dropped positions at 0.0000e+00 --
        // measured, diag_atfilter_value PARTs B and D).  The fill call
        // carries the non-at() remainder plus nativepred.  Counted and
        // observed column totals are cross-checked and mismatches REFUSE:
        // a wrong label is worse than no answer.
        if `s2dropn' > 0 {
            local s2kexp 0
            local s2ntot 0
            forvalues s2k = 1/`s2atn' {
                local s2ntot = `s2ntot' + `s2atc`s2k''
                if "`s2cls`s2k''" == "KEEP" ///
                    local s2kexp = `s2kexp' + `s2atc`s2k''
            }
            capture matrix drop `bfill'
            capture matrix drop `Jfill'
            if `s2keepn' > 0 {
                if `q' != `s2kexp' {
                    capture quietly estimates restore `systemsave'
                    capture quietly estimates drop `systemsave'
                    foreach M in `bsys' `Vsys' `bpiece' `Jpiece' `Fpiece' ///
                        `bjoint' `Jjoint' `Vjoint' `table' `bpost' `Vpost' `Jpost' ///
                        `bfill' `Jfill' `bnew' `Jnew' {
                        capture matrix drop `M'
                    }
                    di as err "the at()-filter counted `s2kexp' kept at() " ///
                        "positions for model {bf:`name'} but native margins " ///
                        "returned `q' columns; refusing rather than mislabel"
                    exit 498
                }
                if trim(`"`nativebefore'"')=="" {
                    if trim(`"`s2atrest' `nativepred'"')=="" capture quietly margins
                    else capture quietly margins, `s2atrest' `nativepred'
                }
                else {
                    if trim(`"`s2atrest' `nativepred'"')=="" capture quietly margins `nativebefore'
                    else capture quietly margins `nativebefore', `s2atrest' `nativepred'
                }
                local rcfill = _rc
                if `rcfill' {
                    capture quietly estimates restore `systemsave'
                    capture quietly estimates drop `systemsave'
                    foreach M in `bsys' `Vsys' `bpiece' `Jpiece' `Fpiece' ///
                        `bjoint' `Jjoint' `Vjoint' `table' `bpost' `Vpost' `Jpost' ///
                        `bfill' `Jfill' `bnew' `Jnew' {
                        capture matrix drop `M'
                    }
                    di as err "the at()-filter's fill margins call failed " ///
                        "for constituent model {bf:`name'}"
                    exit `rcfill'
                }
                matrix `bfill' = r(b)
                matrix `Jfill' = r(Jacobian)
            }
            else {
                // every spec was dropped: the run above WAS the fill call
                matrix `bfill' = `bpiece'
                matrix `Jfill' = `Jpiece'
            }
            if colsof(`bfill') != 1 | rowsof(`Jfill') != 1 | ///
                colsof(`Jfill') != `korig' {
                capture quietly estimates restore `systemsave'
                capture quietly estimates drop `systemsave'
                foreach M in `bsys' `Vsys' `bpiece' `Jpiece' `Fpiece' ///
                    `bjoint' `Jjoint' `Vjoint' `table' `bpost' `Vpost' `Jpost' ///
                    `bfill' `Jfill' `bnew' `Jnew' {
                    capture matrix drop `M'
                }
                di as err "the at()-filter's fill margins call for model " ///
                    "{bf:`name'} did not return exactly one column; " ///
                    "over() and similar options are not supported with " ///
                    "differing predictors on this route"
                exit 498
            }
            capture matrix drop `bnew'
            capture matrix drop `Jnew'
            matrix `bnew' = J(1, `s2ntot', .)
            matrix `Jnew' = J(`s2ntot', `korig', .)
            local s2pos 1
            local s2c 1
            forvalues s2k = 1/`s2atn' {
                local s2cnt = `s2atc`s2k''
                if "`s2cls`s2k''" == "KEEP" {
                    local s2ce = `s2c' + `s2cnt' - 1
                    matrix `bnew'[1,`s2pos'] = `bpiece'[1,`s2c'..`s2ce']
                    matrix `Jnew'[`s2pos',1] = `Jpiece'[`s2c'..`s2ce',1..`korig']
                    local s2c = `s2ce' + 1
                }
                else {
                    matrix `bnew'[1,`s2pos'] = J(1,`s2cnt',1) * `bfill'[1,1]
                    matrix `Jnew'[`s2pos',1] = J(`s2cnt',1,1) * `Jfill'[1,1..`korig']
                }
                local s2pos = `s2pos' + `s2cnt'
            }
            local s2cn "1bn._at"
            forvalues s2p = 2/`s2ntot' {
                local s2cn "`s2cn' `s2p'._at"
            }
            matrix colnames `bnew' = `s2cn'
            matrix rownames `bnew' = y1
            matrix `bpiece' = `bnew'
            matrix `Jpiece' = `Jnew'
            local q = colsof(`bpiece')
            capture matrix drop `bfill'
            capture matrix drop `Jfill'
            capture matrix drop `bnew'
            capture matrix drop `Jnew'
        }

        matrix `Fpiece' = J(`q', `K', 0)
        matrix `Fpiece'[1,`start'] = `Jpiece'
        matrix coleq `bpiece' = `name'

        if `first' {
            matrix `bjoint' = `bpiece'
            matrix `Jjoint' = `Fpiece'
            local first 0
        }
        else {
            matrix `bjoint' = `bjoint', `bpiece'
            matrix `Jjoint' = (`Jjoint' \ `Fpiece')
        }
    }

    matrix `Vjoint' = `Jjoint'*`Vsys'*`Jjoint''
    mata: st_matrixcolstripe("`Vjoint'", st_matrixcolstripe("`bjoint'"))
    mata: st_matrixrowstripe("`Vjoint'", st_matrixcolstripe("`bjoint'"))
    mata: st_matrixrowstripe("`Jjoint'", st_matrixcolstripe("`bjoint'"))
    mata: st_matrixcolstripe("`Jjoint'", st_matrixcolstripe("`bsys'"))

    // Build every r() object before posting. ereturn post consumes the
    // matrices supplied to it, so disposable copies are used for e().
    local qjoint = colsof(`bjoint')
    matrix `table' = J(9, `qjoint', .)
    forvalues j = 1/`qjoint' {
        scalar __s2_b = `bjoint'[1,`j']
        scalar __s2_se = sqrt(max(0, `Vjoint'[`j',`j']))
        scalar __s2_z = cond(__s2_se>0, __s2_b/__s2_se, .)
        scalar __s2_p = cond(__s2_z<., 2*normal(-abs(__s2_z)), .)
        matrix `table'[1,`j'] = __s2_b
        matrix `table'[2,`j'] = __s2_se
        matrix `table'[3,`j'] = __s2_z
        matrix `table'[4,`j'] = __s2_p
        matrix `table'[5,`j'] = __s2_b-invnormal(.975)*__s2_se
        matrix `table'[6,`j'] = __s2_b+invnormal(.975)*__s2_se
        matrix `table'[8,`j'] = invnormal(.975)
        matrix `table'[9,`j'] = 0
    }
    matrix rownames `table' = b se z pvalue ll ul df crit eform
    mata: st_matrixcolstripe("`table'", st_matrixcolstripe("`bjoint'"))

    matrix `bpost' = `bjoint'
    matrix `Vpost' = `Vjoint'
    matrix `Jpost' = `Jjoint'
    quietly suest2_margins_me_post `bpost' `Vpost' `Jpost' `Nsys' `"`raw'"'
    noisily ereturn display

    capture quietly estimates restore `systemsave'
    local rcsystem = _rc
    capture quietly estimates drop `systemsave'
    if `rcsystem' {
        foreach M in `bsys' `Vsys' `bpiece' `Jpiece' `Fpiece' ///
            `bjoint' `Jjoint' `Vjoint' `table' `bpost' `Vpost' `Jpost' {
            capture matrix drop `M'
        }
        exit `rcsystem'
    }

    return matrix b = `bjoint'
    return matrix V = `Vjoint'
    return matrix Jacobian = `Jjoint'
    return matrix table = `table'
    if `Nsys' < . return scalar N = `Nsys'
    return scalar level = 95
    return local cmd "margins"
    return local predict_label "Default prediction for each model"
    if `isdydx' return local expression "Average marginal effects"
    else return local expression "Predictive margins"

    foreach M in `bsys' `Vsys' `bpiece' `Jpiece' `Fpiece' ///
        `bjoint' `Jjoint' `Vjoint' `table' `bpost' `Vpost' `Jpost' {
        capture matrix drop `M'
    }
end


program define suest2_margins_me_post, eclass
    version 16
    args b V J N raw

    if `N' < . ereturn post `b' `V', obs(`N')
    else ereturn post `b' `V'
    ereturn matrix Jacobian = `J'
    ereturn local title "Average marginal effects"
    ereturn local predict_label "Default prediction for each model"
    ereturn local expression "Average marginal effects"
    ereturn local vcetype "Delta-method"
    ereturn local vce "delta"
    ereturn local properties "b V"
    ereturn local cmdline `"margins `raw'"'
    ereturn local cmd "margins"
end


// ---------------------------------------------------------------------------
// at()-filter helpers, added in candidate 15 and probe-verified in
// isolation.  Candidate 16 wired in classification (display only) and
// candidate 17 removes DROP specs from each constituent's call; see
// at-filter-PROPOSAL.md.
// All three are sclass so that the native margins calls inside me_dydx,
// which are rclass, cannot clobber their results.  Callers must still copy
// s() to locals IMMEDIATELY: syntax and other sclass commands clear s(), and
// suest2_margins_atvars itself runs numlist, which replaces r() at its call
// site.
// ---------------------------------------------------------------------------

// Split a margins option list into its at() specifications and the
// remainder.  Returns s(n_at), s(at1)..s(atN) (the inner text of each at(),
// trimmed, original spacing kept), and s(rest) (the option list with every
// at() removed, itrimmed).  Matching is depth-aware and word-boundary aware:
// "at(" inside another option's parentheses is not an at() spec, and neither
// is the tail of cformat( / pformat( / sformat( -- the substring trap this
// project has already been bitten by.  Balanced-parenthesis scanning admits
// nested parentheses, which mecompare's own specs contain (v=gen(v + .5),
// v=(2(1)5)).  Exits 198 on unbalanced parentheses, mirroring the predict()
// splitter above.  Not aware of double-quoted strings inside options; see
// the proposal's known-limits list.
program define suest2_margins_atsplit, sclass
    version 16
    args opts

    sreturn clear
    local nat 0
    local rest
    local cur
    local depth 0
    local len = length(`"`opts'"')
    local j 1
    while `j' <= `len' {
        local ch = substr(`"`opts'"', `j', 1)
        local istrigger 0
        if `depth' == 0 & lower(`"`ch'"') == "a" {
            local nxt2 = lower(substr(`"`opts'"', `j' + 1, 2))
            if `"`nxt2'"' == "t(" {
                local ok 1
                if `j' > 1 {
                    local prev = lower(substr(`"`opts'"', `j' - 1, 1))
                    if strpos("abcdefghijklmnopqrstuvwxyz0123456789_.", ///
                        `"`prev'"') local ok 0
                }
                local istrigger = `ok'
            }
        }
        if `istrigger' {
            local k = `j' + 3
            local d 1
            local body
            while `d' > 0 & `k' <= `len' {
                local c2 = substr(`"`opts'"', `k', 1)
                if `"`c2'"' == "(" local ++d
                if `"`c2'"' == ")" local --d
                if `d' > 0 local body `"`body'`c2'"'
                local ++k
            }
            if `d' > 0 {
                di as err "unbalanced parentheses in a margins at() specification"
                exit 198
            }
            local ++nat
            local at`nat' = trim(`"`body'"')
            local rest `"`rest'`cur'"'
            local cur
            local j = `k'
        }
        else {
            if `"`ch'"' == "(" local ++depth
            if `"`ch'"' == ")" local --depth
            local cur `"`cur'`ch'"'
            local ++j
        }
    }
    local rest `"`rest'`cur'"'

    sreturn local n_at = `nat'
    forvalues q = 1/`nat' {
        sreturn local at`q' `"`at`q''"'
    }
    sreturn local rest = itrim(trim(`"`rest'"'))
end


// Read one at() specification (the inner text, as returned by atsplit).
// Returns
//   s(lhsvars)    variables set by var=value, var=(numlist), var=gen(exp)
//   s(statvars)   bare variables following a (stat) group, _all excluded
//   s(n_numlist)  how many var=(numlist) items the spec carries
//   s(count)      the number of _at positions the spec contributes: the
//                 product of the numlist lengths, every other item
//                 contributing one.  Stata's own numlist command does the
//                 expansion, so 2(1)5 and decimals count correctly.  If any
//                 numlist fails to expand, s(count) is "." -- the caller
//                 must treat the spec as uncountable and refuse rather than
//                 guess.
// gen() interiors are NOT parsed for variable references; mecompare only
// ever writes v=gen(v +/- constant).  A foreign variable inside gen() will
// surface as native margins' own error, not as a silent wrong answer.
program define suest2_margins_atvars, sclass
    version 16
    args spec

    sreturn clear

    // Tokenize on whitespace at parenthesis depth 0, so that (2 3), gen(v +
    // .5) and (mean) survive as single tokens or token parts.
    local ntok 0
    local cur
    local depth 0
    local len = length(`"`spec'"')
    forvalues j = 1/`len' {
        local ch = substr(`"`spec'"', `j', 1)
        if `"`ch'"' == "(" local ++depth
        if `"`ch'"' == ")" local --depth
        if `depth' == 0 & (`"`ch'"' == " " | `"`ch'"' == char(9)) {
            if `"`cur'"' != "" {
                local ++ntok
                local tok`ntok' `"`cur'"'
                local cur
            }
        }
        else local cur `"`cur'`ch'"'
    }
    if `"`cur'"' != "" {
        local ++ntok
        local tok`ntok' `"`cur'"'
    }

    // Rejoin var = value written with spaces around the equals sign.
    local nitm 0
    local k 1
    while `k' <= `ntok' {
        local t `"`tok`k''"'
        local more 1
        while `more' {
            local more 0
            local kp1 = `k' + 1
            if `kp1' <= `ntok' {
                local nx `"`tok`kp1''"'
                if substr(`"`t'"', -1, 1) == "=" | ///
                    substr(`"`nx'"', 1, 1) == "=" {
                    local t `"`t'`nx'"'
                    local k = `kp1'
                    local more 1
                }
            }
        }
        local ++nitm
        local itm`nitm' `"`t'"'
        local ++k
    }

    local lhsvars
    local statvars
    local count 1
    local nnum 0
    local bad 0
    forvalues q = 1/`nitm' {
        local t `"`itm`q''"'
        local eq = strpos(`"`t'"', "=")
        if `eq' {
            local lhs = trim(substr(`"`t'"', 1, `eq' - 1))
            local rhs = trim(substr(`"`t'"', `eq' + 1, .))
            if `"`lhs'"' != "" local lhsvars `lhsvars' `lhs'
            if substr(`"`rhs'"', 1, 1) == "(" {
                local inner = substr(`"`rhs'"', 2, length(`"`rhs'"') - 2)
                local ++nnum
                capture numlist `"`inner'"'
                if _rc local bad 1
                else {
                    local nv : word count `r(numlist)'
                    local count = `count' * `nv'
                }
            }
            // var=gen(exp) and var=value contribute one position each
        }
        else if substr(`"`t'"', 1, 1) == "(" {
            // a (stat) marker: contributes no variables and no positions
        }
        else if `"`t'"' != "_all" {
            local statvars `statvars' `t'
        }
    }
    local lhsvars : list uniq lhsvars
    local statvars : list uniq statvars

    sreturn local lhsvars `"`lhsvars'"'
    sreturn local statvars `"`statvars'"'
    sreturn local n_numlist = `nnum'
    if `bad' sreturn local count .
    else sreturn local count = `count'
end


// The covariates of the ACTIVE estimate, from e(b)'s column stripe.
// Returns s(vars): deduplicated variable names with every factor operator
// stripped (1., 0b., o., c., ib#.-style bases) and interactions split on #.
// Columns whose names carry ( or [ are ancillary parameters -- var(), cov(),
// random-effects stripes -- and are skipped, as is _cons.  Omitted (o.)
// terms ARE reported: they are formally covariates and native margins
// accepts them in at().  This is the exact-match replacement for the
// substring tests that caused mecompare's earlier membership bugs.
program define suest2_margins_ebvars, sclass
    version 16

    sreturn clear
    local cn : colnames e(b)
    local vars
    foreach tk of local cn {
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
    sreturn local vars `"`vars'"'
end
