*! version 0.1.93  01sep2026  | history: CHANGELOG-suest2.md (repo)
program define suest2_p
    version 16
    syntax newvarname [if] [in] [, MODEL(string) XB XB0 SUESTXB PR PCR PU0 N NU0 IRU0 PR0(string) PRRange(string asis) MU RATE MEAN MEDIAN SURV HAZARD DENSITY DISTRIBUTION ETA MARGINAL FIXEDonly CONDITIONAL(string) NOOFFset OUTcome(string) YStar(string asis) EXPECTed(string asis) XBSEL PSEL YCOND YEXPECTED MILLS NSHAZARD DEFAULT LEGACY *]

    if "`e(cmd)'" != "suest2" {
        di as err "suest2 estimation results not found"
        exit 301
    }

    local names `"`e(names)'"'
    local nmodels = e(suest2_nmodels)
    if `"`model'"' == "" local model : word 1 of `names'

    capture confirm integer number `model'
    if !_rc {
        if `model' < 1 | `model' > `nmodels' {
            di as err "model() index must be between 1 and `nmodels'"
            exit 198
        }
        local imodel = `model'
        local model : word `imodel' of `names'
    }
    else {
        local imodel 0
        forvalues i = 1/`nmodels' {
            local name : word `i' of `names'
            if `"`model'"' == `"`name'"' local imodel `i'
        }
        if `imodel' == 0 {
            di as err "model {bf:`model'} was not included in suest2"
            di as err "available models: `names'"
            exit 198
        }
    }

    if "`legacy'" != "" {
        local pass
        if "`xb'`suestxb'" != "" local pass "xb"
        if "`pr'" != "" local pass "`pass' pr"
        if "`pcr'" != "" local pass "`pass' pcr"
        if "`xb0'" != "" local pass "`pass' xb0"
        if "`pu0'" != "" local pass "`pass' pu0"
        if "`n'" != "" local pass "`pass' n"
        if "`nu0'" != "" local pass "`pass' nu0"
        if "`iru0'" != "" local pass "`pass' iru0"
        if `"`pr0'"' != "" local pass `"`pass' pr0(`pr0')"'
        if `"`prrange'"' != "" local pass `"`pass' pr(`prrange')"'
        if "`mu'" != "" local pass "`pass' mu"
        if `"`ystar'"' != "" local pass `"`pass' ystar(`ystar')"'
        if `"`expected'"' != "" local pass `"`pass' e(`expected')"'
        if "`xbsel'" != "" local pass "`pass' xbsel"
        if "`psel'" != "" local pass "`pass' psel"
        if "`ycond'" != "" local pass "`pass' ycond"
        if "`yexpected'" != "" local pass "`pass' yexpected"
        if "`mills'" != "" local pass "`pass' mills"
        if "`nshazard'" != "" local pass "`pass' nshazard"
        if "`rate'" != "" local pass "`pass' rate"
        if "`fixedonly'" != "" local pass "`pass' fixedonly"
        if trim(`"`conditional'"') != "" local pass `"`pass' conditional(`conditional')"'
        if "`nooffset'" != "" local pass "`pass' nooffset"
        if `"`outcome'"' != "" local pass `"`pass' outcome(`outcome')"'
        if trim(`"`options'"') != "" local pass `"`pass' `options'"'
        suest2_p_legacy `typlist' `varlist' `if' `in', model(`model') `pass'
        exit
    }

    if trim(`"`options'"') != "" {
        di as err "prediction option(s) {bf:`options'} are not supported by the active-system suest2 predictor"
        di as err "for a direct prediction only, add option {bf:legacy}"
        exit 198
    }

    local cmd `"`e(suest2_cmd`imodel')'"'
    local depvar `"`e(suest2_depvar`imodel')'"'
    local eqstart = e(suest2_eqstart`imodel')
    local nsyseq = e(suest2_nsyseq`imodel')
    local outcomes `"`e(suest2_outcomes`imodel')'"'

    if !e(suest2_systempred`imodel') {
        di as err "margins-safe prediction is not yet implemented for {bf:`cmd'} models"
        di as err "for a direct prediction only, add option {bf:legacy}"
        exit 321
    }

    if "`suestxb'" != "" local xb xb
    local wantxb = ("`xb'" != "")

    // GLM. Native glim_p is not stable after temporary coefficient reposting,
    // so evaluate the selected system equation directly and invert its stored
    // link. This keeps margins tied to the complete joint covariance matrix.
    if inlist("`cmd'","glm","fracreg") {
        local badopt 0
        foreach opt in pcr pu0 n nu0 iru0 pr rate mean median surv hazard density distribution eta marginal fixedonly conditional outcome ystar expected prrange xbsel psel ycond yexpected mills nshazard {
            if `"``opt''"'!="" local badopt 1
        }
        if trim(`"`pr0'"')!="" local badopt 1
        if `badopt' {
            di as err "`cmd' active-system prediction supports the native default, mu, or xb"
            exit 198
        }
        local nstat=("`xb'"!="")+("`mu'"!="")
        if `nstat'>1 {
            di as err "specify only one of mu or xb"
            exit 198
        }

        tempvar glmeta
        quietly _predict double `glmeta' `if' `in', xb equation(#`eqstart')
        local offset `"`e(suest2_offset`imodel')'"'
        if trim(`"`offset'"')!="" & "`nooffset'"=="" {
            tempvar offsetvalue
            capture quietly generate double `offsetvalue'=`offset' `if' `in'
            local offsetrc=_rc
            if `offsetrc' {
                di as err "unable to evaluate offset {bf:`offset'} for model {bf:`model'}"
                di as err "the offset variable may have changed since estimation"
                exit `offsetrc'
            }
            quietly replace `glmeta'=`glmeta'+`offsetvalue' `if' `in'
        }

        if "`xb'"!="" {
            quietly generate `typlist' `varlist'=`glmeta' `if' `in'
            label variable `varlist' "Linear prediction"
            exit
        }

        local glink=lower(itrim(trim(`"`e(suest2_link`imodel')'"')))
        if "`glink'"=="identity" {
            quietly generate `typlist' `varlist'=`glmeta' `if' `in'
        }
        else if "`glink'"=="log" {
            quietly generate `typlist' `varlist'=exp(`glmeta') `if' `in'
        }
        else if "`glink'"=="logit" {
            quietly generate `typlist' `varlist'=invlogit(`glmeta') `if' `in'
        }
        else if "`glink'"=="probit" {
            quietly generate `typlist' `varlist'=normal(`glmeta') `if' `in'
        }
        else if strpos("`glink'","complementary") {
            quietly generate `typlist' `varlist'=1-exp(-exp(`glmeta')) `if' `in'
        }
        else if inlist("`glink'","log-log","log–log","log_log") {
            quietly generate `typlist' `varlist'=exp(-exp(-`glmeta')) `if' `in'
        }
        else {
            di as err "active-system `cmd' prediction is not implemented for link {bf:`glink'}"
            di as err "for a direct native prediction only, add option {bf:legacy}"
            exit 321
        }
        label variable `varlist' "Predicted mean"
        exit
    }

    // Beta regression. cmean is the native default -- betareg has no mu;
    // e(marginsok) is "default CMean CVARiance xb XBSCAle". The mean is one
    // link inversion of the FIRST system equation and the scale equation
    // plays no part in it. The link arrives ALREADY NORMALIZED from
    // suest2's capture branch: betareg posts e(linkt) "Comp. log-log",
    // which the glm branch's "complementary" test does not match, and
    // reading it raw sent cloglog down the log-log path at reldif .19
    // (probe_fam_forms_v1_1). "complementary" is tested before "log-log"
    // because "complementary_log-log" contains it.
    if "`cmd'"=="betareg" {
        local badopt 0
        foreach opt in pcr pu0 n nu0 iru0 pr mu rate mean median surv hazard density distribution eta marginal fixedonly conditional outcome ystar expected prrange xbsel psel ycond yexpected mills nshazard {
            if `"``opt''"'!="" local badopt 1
        }
        if trim(`"`pr0'"')!="" local badopt 1
        if `badopt' {
            di as err "betareg active-system prediction supports the native default (the conditional mean) or xb"
            di as err "for a direct native prediction only, add option {bf:legacy}"
            exit 198
        }
        tempvar betaeta
        quietly _predict double `betaeta' `if' `in', xb equation(#`eqstart')
        if "`xb'"!="" {
            quietly generate `typlist' `varlist'=`betaeta' `if' `in'
            label variable `varlist' "Linear prediction"
            exit
        }
        local blink=lower(trim(`"`e(suest2_link`imodel')'"'))
        if "`blink'"=="logit" {
            quietly generate `typlist' `varlist'=invlogit(`betaeta') `if' `in'
        }
        else if "`blink'"=="probit" {
            quietly generate `typlist' `varlist'=normal(`betaeta') `if' `in'
        }
        else if strpos("`blink'","complementary") {
            quietly generate `typlist' `varlist'=1-exp(-exp(`betaeta')) `if' `in'
        }
        else if strpos("`blink'","log-log") {
            quietly generate `typlist' `varlist'=exp(-exp(-`betaeta')) `if' `in'
        }
        else {
            di as err "active-system betareg prediction is not implemented for link {bf:`blink'}"
            di as err "for a direct native prediction only, add option {bf:legacy}"
            exit 321
        }
        label variable `varlist' "Conditional mean of `depvar'"
        exit
    }

    // Truncated regression. The native default IS the linear prediction
    // (e(marginsok) "default XB Pr() E() YStar()"), so default and xb are
    // one quantity here. The truncated mean E(y|y>ll) needs the boundary
    // and /sigma; its closed form is measured exact (1.3e-16) but it is
    // deliberately NOT offered yet.
    if "`cmd'"=="truncreg" {
        local badopt 0
        foreach opt in pcr pu0 n nu0 iru0 pr mu rate mean median surv hazard density distribution eta marginal fixedonly conditional outcome ystar expected prrange xbsel psel ycond yexpected mills nshazard {
            if `"``opt''"'!="" local badopt 1
        }
        if trim(`"`pr0'"')!="" local badopt 1
        if `badopt' {
            di as err "truncreg active-system prediction supports the native default (the linear prediction) or xb"
            di as err "for a direct native prediction only, add option {bf:legacy}"
            exit 198
        }
        quietly _predict double `varlist' `if' `in', xb equation(#`eqstart')
        label variable `varlist' "Linear prediction"
        exit
    }

    // Heteroskedastic probit. pr is the native default. The variance index
    // is this model's SECOND system equation; it carries no constant,
    // holding only the het() terms (measured, probe_fam_forms_v1_0).
    if "`cmd'"=="hetprobit" {
        local badopt 0
        foreach opt in pcr pu0 n nu0 iru0 mu rate mean median surv hazard density distribution eta marginal fixedonly conditional outcome ystar expected prrange xbsel psel ycond yexpected mills nshazard {
            if `"``opt''"'!="" local badopt 1
        }
        if trim(`"`pr0'"')!="" local badopt 1
        if `badopt' {
            di as err "hetprobit active-system prediction supports the native default, pr, or xb"
            di as err "for a direct native prediction only, add option {bf:legacy}"
            exit 198
        }
        local nstat=("`xb'"!="")+("`pr'"!="")
        if `nstat'>1 {
            di as err "specify only one of pr or xb"
            exit 198
        }
        tempvar heteta
        quietly _predict double `heteta' `if' `in', xb equation(#`eqstart')
        if "`xb'"!="" {
            quietly generate `typlist' `varlist'=`heteta' `if' `in'
            label variable `varlist' "Linear prediction"
            exit
        }
        local heq2 = `eqstart' + 1
        tempvar hetlns
        quietly _predict double `hetlns' `if' `in', xb equation(#`heq2')
        quietly generate `typlist' `varlist'=normal(`heteta'/exp(`hetlns')) `if' `in'
        label variable `varlist' "Pr(`depvar')"
        exit
    }

    // Zero-inflated Poisson and negative binomial. n, the predicted number
    // of events, is the native default for both. The inflation index is the
    // SECOND system equation and its link is whichever e(inflate) named,
    // carried here in suest2_link. zinb's /lnalpha plays no part in the
    // mean. Exposure is refused rather than silently dropped.
    if inlist("`cmd'","zip","zinb") {
        local badopt 0
        foreach opt in pcr pu0 nu0 iru0 pr mu rate mean median surv hazard density distribution eta marginal fixedonly conditional outcome ystar expected prrange xbsel psel ycond yexpected mills nshazard {
            if `"``opt''"'!="" local badopt 1
        }
        if trim(`"`pr0'"')!="" local badopt 1
        if `badopt' {
            di as err "`cmd' active-system prediction supports the native default, n, or xb"
            di as err "for a direct native prediction only, add option {bf:legacy}"
            exit 198
        }
        local nstat=("`xb'"!="")+("`n'"!="")
        if `nstat'>1 {
            di as err "specify only one of n or xb"
            exit 198
        }
        if trim(`"`e(suest2_exposure`imodel')'"')!="" {
            di as err "active-system `cmd' prediction does not yet support exposure()"
            di as err "for a direct native prediction only, add option {bf:legacy}"
            exit 321
        }
        tempvar zieta
        quietly _predict double `zieta' `if' `in', xb equation(#`eqstart')
        local offset `"`e(suest2_offset`imodel')'"'
        if trim(`"`offset'"')!="" & "`nooffset'"=="" {
            tempvar zioff
            capture quietly generate double `zioff'=`offset' `if' `in'
            local offsetrc=_rc
            if `offsetrc' {
                di as err "unable to evaluate offset {bf:`offset'} for model {bf:`model'}"
                di as err "the offset variable may have changed since estimation"
                exit `offsetrc'
            }
            quietly replace `zieta'=`zieta'+`zioff' `if' `in'
        }
        if "`xb'"!="" {
            quietly generate `typlist' `varlist'=`zieta' `if' `in'
            label variable `varlist' "Linear prediction"
            exit
        }
        local zeq2 = `eqstart' + 1
        tempvar ziinf
        quietly _predict double `ziinf' `if' `in', xb equation(#`zeq2')
        local zilink=lower(trim(`"`e(suest2_link`imodel')'"'))
        if "`zilink'"=="probit" {
            quietly generate `typlist' `varlist'=(1-normal(`ziinf'))*exp(`zieta') `if' `in'
        }
        else {
            quietly generate `typlist' `varlist'=(1-invlogit(`ziinf'))*exp(`zieta') `if' `in'
        }
        label variable `varlist' "Predicted number of events"
        exit
    }

    // Bivariate probit. p11, the joint success probability, is the native
    // default. It needs both index equations and /athrho, which are system
    // equations one, two and three of this model's block. xb is NOT offered
    // because it would be ambiguous between the two index equations.
    if "`cmd'"=="biprobit" {
        local badopt 0
        foreach opt in pcr pu0 n nu0 iru0 pr mu xb rate mean median surv hazard density distribution eta marginal fixedonly conditional outcome ystar expected prrange xbsel psel ycond yexpected mills nshazard {
            if `"``opt''"'!="" local badopt 1
        }
        if trim(`"`pr0'"')!="" local badopt 1
        if `badopt' {
            di as err "biprobit active-system prediction supports only the native default, the joint probability"
            di as err "for a direct native prediction only, add option {bf:legacy}"
            exit 198
        }
        local beq2 = `eqstart' + 1
        local beq3 = `eqstart' + 2
        tempvar bpx1 bpx2 bpath
        quietly _predict double `bpx1'  `if' `in', xb equation(#`eqstart')
        quietly _predict double `bpx2'  `if' `in', xb equation(#`beq2')
        quietly _predict double `bpath' `if' `in', xb equation(#`beq3')
        quietly generate `typlist' `varlist'=binormal(`bpx1',`bpx2',tanh(`bpath')) `if' `in'
        label variable `varlist' "Pr(both outcomes = 1)"
        exit
    }

    // Instrumental-variables probit and tobit. The native DEFAULT of each is
    // the linear prediction of the structural equation, which is this
    // model's first system equation -- the same shape as truncreg. The
    // average structural function (ivprobit pr; ivtobit e(), ystar()) is a
    // different quantity that integrates over the reduced-form residual, and
    // the plain closed forms do NOT reproduce it (measured .0056, .031,
    // .047), so those statistics are refused here rather than approximated.
    if inlist("`cmd'","ivprobit","ivtobit") {
        local badopt 0
        foreach opt in pcr pu0 n nu0 iru0 pr mu rate mean median surv hazard density distribution eta marginal fixedonly conditional outcome ystar expected prrange xbsel psel ycond yexpected mills nshazard {
            if `"``opt''"'!="" local badopt 1
        }
        if trim(`"`pr0'"')!="" local badopt 1
        if `badopt' {
            di as err "`cmd' active-system prediction supports the native default (the linear prediction) or xb"
            di as err "the average structural function is not available on the active system"
            di as err "for a direct native prediction only, add option {bf:legacy}"
            exit 198
        }
        quietly _predict double `varlist' `if' `in', xb equation(#`eqstart')
        label variable `varlist' "Linear prediction"
        exit
    }

    // Ordinary complementary log-log. Evaluate directly from the selected
    // joint-system equation for the same reason as the GLM branch above.
    if "`cmd'"=="cloglog" {
        local badopt 0
        foreach opt in pcr pu0 n nu0 iru0 mu rate mean median surv hazard density distribution eta marginal fixedonly conditional outcome ystar expected prrange xbsel psel ycond yexpected mills nshazard {
            if `"``opt''"'!="" local badopt 1
        }
        if trim(`"`pr0'"')!="" local badopt 1
        if `badopt' {
            di as err "cloglog active-system prediction supports the native default, pr, or xb"
            exit 198
        }
        local nstat=("`xb'"!="")+("`pr'"!="")
        if `nstat'>1 {
            di as err "specify only one of pr or xb"
            exit 198
        }

        tempvar cleta
        quietly _predict double `cleta' `if' `in', xb equation(#`eqstart')
        local offset `"`e(suest2_offset`imodel')'"'
        if trim(`"`offset'"')!="" & "`nooffset'"=="" {
            tempvar offsetvalue
            capture quietly generate double `offsetvalue'=`offset' `if' `in'
            local offsetrc=_rc
            if `offsetrc' {
                di as err "unable to evaluate offset {bf:`offset'} for model {bf:`model'}"
                di as err "the offset variable may have changed since estimation"
                exit `offsetrc'
            }
            quietly replace `cleta'=`cleta'+`offsetvalue' `if' `in'
        }

        if "`xb'"!="" {
            quietly generate `typlist' `varlist'=`cleta' `if' `in'
            label variable `varlist' "Linear prediction"
        }
        else {
            quietly generate `typlist' `varlist'=1-exp(-exp(`cleta')) `if' `in'
            label variable `varlist' "Pr(`depvar')"
        }
        exit
    }

    // Censored and interval regression. prrange() is the active-system
    // spelling of native pr(a,b); expected() maps to native e(a,b).
    if inlist("`cmd'","tobit","intreg") {
        local badopt 0
        foreach opt in pcr pu0 n nu0 iru0 mu rate mean median surv hazard density distribution eta marginal fixedonly conditional nooffset outcome xbsel psel ycond yexpected mills nshazard {
            if `"``opt''"'!="" local badopt 1
        }
        if trim(`"`pr0'"')!="" local badopt 1
        if `badopt' {
            di as err "`cmd' active-system prediction supports xb, ystar(), expected(), or prrange()"
            exit 198
        }
        if "`pr'"!="" {
            di as err "use prrange(lower,upper) after `cmd'"
            exit 198
        }
        local nstat=("`xb'"!="")+(trim(`"`ystar'"')!="")+(trim(`"`expected'"')!="")+(trim(`"`prrange'"')!="")
        if `nstat'>1 {
            di as err "specify only one `cmd' prediction statistic"
            exit 198
        }
        local pass
        if "`xb'"!="" local pass "xb"
        else if trim(`"`ystar'"')!="" local pass `"ystar(`ystar')"'
        else if trim(`"`expected'"')!="" local pass `"e(`expected')"'
        else if trim(`"`prrange'"')!="" local pass `"pr(`prrange')"'
        suest2_p_legacy `typlist' `varlist' `if' `in', model(`model') `pass'
        exit
    }

    // Maximum-likelihood Heckman selection models.
    if "`cmd'"=="heckman" {
        local badopt 0
        foreach opt in pcr pu0 n nu0 iru0 pr mu rate mean median surv hazard density distribution eta marginal fixedonly conditional nooffset outcome ystar expected prrange {
            if `"``opt''"'!="" local badopt 1
        }
        if trim(`"`pr0'"')!="" local badopt 1
        if `badopt' {
            di as err "heckman active-system prediction supports xb, xbsel, psel, ycond, yexpected, mills, or nshazard"
            exit 198
        }
        local nstat=("`xb'"!="")+("`xbsel'"!="")+("`psel'"!="")+("`ycond'"!="")+("`yexpected'"!="")+("`mills'"!="")+("`nshazard'"!="")
        if `nstat'>1 {
            di as err "specify only one heckman prediction statistic"
            exit 198
        }
        local pass
        if "`xb'"!="" local pass "xb"
        else if "`xbsel'"!="" local pass "xbsel"
        else if "`psel'"!="" local pass "psel"
        else if "`ycond'"!="" local pass "ycond"
        else if "`yexpected'"!="" local pass "yexpected"
        else if "`mills'"!="" local pass "mills"
        else if "`nshazard'"!="" local pass "nshazard"
        suest2_p_legacy `typlist' `varlist' `if' `in', model(`model') `pass'
        exit
    }

    // Parametric survival models estimated by streg.
    if "`cmd'"=="streg" {
        local badopt 0
        foreach opt in pcr pu0 n nu0 iru0 pr mu rate distribution eta marginal fixedonly conditional nooffset outcome ystar expected prrange xbsel psel ycond yexpected mills nshazard {
            if `"``opt''"'!="" local badopt 1
        }
        if trim(`"`pr0'"')!="" local badopt 1
        if `badopt' {
            di as err "streg active-system prediction supports the native default, xb, mean, median, surv, hazard, or density"
            exit 198
        }
        local nstat=("`xb'"!="")+("`mean'"!="")+("`median'"!="")+("`surv'"!="")+("`hazard'"!="")+("`density'"!="")
        if `nstat'>1 {
            di as err "specify only one streg prediction statistic"
            exit 198
        }
        local pass
        if "`xb'"!="" local pass "xb"
        else if "`mean'"!="" local pass "mean"
        else if "`median'"!="" local pass "median"
        else if "`surv'"!="" local pass "surv"
        else if "`hazard'"!="" local pass "hazard"
        else if "`density'"!="" local pass "density"
        suest2_p_legacy `typlist' `varlist' `if' `in', model(`model') `pass'
        exit
    }

    local xtmodel `"`e(suest2_xtmodel`imodel')'"'
    if "`rate'"!="" & !("`xtmodel'"=="pa" & ///
        inlist("`cmd'","xtlogit","xtprobit","xtcloglog")) {
        di as err "option rate is supported only for binary population-averaged models"
        exit 198
    }
    if !inlist("`cmd'","melogit","meprobit","mecloglog","mepoisson","menbreg","meologit","meoprobit","megaussian","megamma") & ///
        "`cmd'"!="mestreg" & !inlist("`cmd'","xtpoisson","xtnbreg","xtcloglog") & ///
        !("`xtmodel'"=="pa" & inlist("`cmd'","xtlogit","xtprobit","xtcloglog","xtpoisson","xtnbreg")) & ///
        "`mu'`fixedonly'`conditional'`nooffset'"!="" {
        di as err "options mu, fixedonly, conditional(), and nooffset are not supported for this active-system prediction"
        exit 198
    }

    if "`cmd'"=="xtmlogit" {
        if "`mu'`n'`nu0'`iru0'`pr0'`mean'`median'`surv'`hazard'`density'`distribution'`eta'`marginal'`fixedonly'`conditional'`nooffset'"!="" {
            di as err "xtmlogit prediction supports outcome-specific pr, pcr, pu0, xb, or xb0"
            exit 198
        }

        if "`xtmodel'"=="fe" {
            if "`pr'`pcr'`xb0'"!="" {
                di as err "xtmlogit, fe active-system prediction supports pu0 or xb"
                exit 198
            }
            local nstat=("`xb'"!="")+("`pu0'"!="")
            if `nstat'>1 {
                di as err "specify only one of pu0 or xb"
                exit 198
            }
            local pass "pu0"
            if "`xb'"!="" local pass "xb"
            if trim(`"`outcome'"')!="" local pass `"`pass' outcome(`outcome')"'
            suest2_p_legacy `typlist' `varlist' `if' `in', model(`model') `pass'
            exit
        }

        if "`xtmodel'"=="re" {
            local nstat=("`xb'"!="")+("`xb0'"!="")+("`pr'"!="")+("`pcr'"!="")+("`pu0'"!="")
            if `nstat'>1 {
                di as err "specify only one xtmlogit, re prediction statistic"
                exit 198
            }
            local pass "pr"
            if "`xb'"!="" local pass "xb"
            else if "`xb0'"!="" local pass "xb0"
            else if "`pcr'"!="" local pass "pcr"
            else if "`pu0'"!="" local pass "pu0"
            if trim(`"`outcome'"')!="" local pass `"`pass' outcome(`outcome')"'
            suest2_p_legacy `typlist' `varlist' `if' `in', model(`model') `pass'
            exit
        }

        di as err "unrecognized xtmlogit model type"
        exit 498
    }

    if "`xtmodel'"=="pa" & ///
        inlist("`cmd'","xtlogit","xtprobit","xtcloglog","xtpoisson","xtnbreg") {
        if "`pcr'`pu0'`n'`nu0'`iru0'`mean'`median'`surv'`hazard'`density'`distribution'`eta'`marginal'`fixedonly'`conditional'"!="" | ///
            trim(`"`outcome'"')!="" {
            di as err "`cmd', pa active-system prediction supports the native default, mu, xb, and selected family-specific statistics"
            exit 198
        }
        if "`pr'"!="" {
            di as err "`cmd', pa uses mu rather than pr"
            exit 198
        }
        if "`rate'"!="" & !inlist("`cmd'","xtlogit","xtprobit","xtcloglog") {
            di as err "rate is supported only for binary population-averaged models"
            exit 198
        }
        if trim(`"`pr0'"')!="" & "`cmd'"!="xtpoisson" {
            di as err "pr0() is supported only for xtpoisson, pa"
            exit 198
        }

        local nstat=("`xb'"!="")+("`mu'"!="")+("`rate'"!="")+(trim(`"`pr0'"')!="")
        if `nstat'>1 {
            di as err "specify only one population-averaged prediction statistic"
            exit 198
        }

        local pass
        if "`xb'"!="" local pass "xb"
        else if "`mu'"!="" local pass "mu"
        else if "`rate'"!="" local pass "rate"
        else if trim(`"`pr0'"')!="" local pass `"pr(`pr0')"'
        if "`nooffset'"!="" local pass `"`pass' nooffset"'
        suest2_p_legacy `typlist' `varlist' `if' `in', model(`model') `pass'
        exit
    }

    if inlist("`cmd'","xtlogit","xtprobit") {
        if "`cmd'"=="xtlogit" & "`xtmodel'"=="fe" {
            if "`mu'`n'`nu0'`iru0'`pr'`mean'`median'`surv'`hazard'`density'`distribution'`eta'`marginal'`fixedonly'`conditional'`nooffset'"!="" | ///
                `"`pr0'`outcome'"'!="" {
                di as err "xtlogit, fe active-system prediction supports pu0 or xb"
                exit 198
            }
            local nstat=("`xb'"!="")+("`pu0'"!="")
            if `nstat'>1 {
                di as err "specify only one of pu0 or xb"
                exit 198
            }
            local pass "pu0"
            if "`xb'"!="" local pass "xb"
            suest2_p_legacy `typlist' `varlist' `if' `in', model(`model') `pass'
            exit
        }

        if "`mu'`n'`nu0'`iru0'`mean'`median'`surv'`hazard'`density'`distribution'`eta'`marginal'`fixedonly'`conditional'`nooffset'"!="" | ///
            `"`pr0'`outcome'"'!="" {
            di as err "`cmd' active-system prediction supports pr, pu0, or xb"
            exit 198
        }
        local nstat=("`xb'"!="")+("`pr'"!="")+("`pu0'"!="")
        if `nstat'>1 {
            di as err "specify only one of pr, pu0, or xb"
            exit 198
        }
        local pass "pr"
        if "`xb'"!="" local pass "xb"
        else if "`pu0'"!="" local pass "pu0"
        suest2_p_legacy `typlist' `varlist' `if' `in', model(`model') `pass'
        exit
    }


    if inlist("`cmd'","xtologit","xtoprobit") {
        if "`mu'`n'`nu0'`iru0'`mean'`median'`surv'`hazard'`density'`distribution'`eta'`marginal'`fixedonly'`conditional'`nooffset'"!="" | ///
            `"`pr0'"'!="" {
            di as err "`cmd' active-system prediction supports xb, pr, or pu0, with optional outcome()"
            exit 198
        }
        local nstat=("`xb'"!="")+("`pr'"!="")+("`pu0'"!="")
        if `nstat'>1 {
            di as err "specify only one of xb, pr, or pu0"
            exit 198
        }
        if trim(`"`outcome'"')!="" & "`pr'`pu0'"=="" {
            di as err "option outcome() requires pr or pu0 for `cmd'"
            exit 198
        }
        local pass "pr"
        if "`xb'"!="" local pass "xb"
        else if "`pu0'"!="" local pass "pu0"
        if trim(`"`outcome'"')!="" local pass `"`pass' outcome(`outcome')"'
        else if `nstat'==0 {
            local __s2_defaultout : word 1 of `outcomes'
            if trim(`"`__s2_defaultout'"')!="" local pass `"pr outcome(`__s2_defaultout')"'
        }
        suest2_p_legacy `typlist' `varlist' `if' `in', model(`model') `pass'
        exit
    }

    if "`cmd'"=="xtcloglog" {
        if "`mu'`n'`nu0'`iru0'`mean'`median'`surv'`hazard'`density'`distribution'`eta'`marginal'`fixedonly'`conditional'"!="" | ///
            `"`pr0'`outcome'"'!="" {
            di as err "xtcloglog active-system prediction supports xb, pr, or pu0, with optional nooffset"
            exit 198
        }
        local nstat=("`xb'"!="")+("`pr'"!="")+("`pu0'"!="")
        if `nstat'>1 {
            di as err "specify only one of xb, pr, or pu0"
            exit 198
        }
        local pass "pr"
        if "`xb'"!="" local pass "xb"
        else if "`pu0'"!="" local pass "pu0"
        if "`nooffset'"!="" local pass `"`pass' nooffset"'
        suest2_p_legacy `typlist' `varlist' `if' `in', model(`model') `pass'
        exit
    }

    if "`cmd'"=="xtnbreg" {
        if "`xtmodel'"=="fe" {
            if "`mu'`pr'`pu0'`n'`iru0'`mean'`median'`surv'`hazard'`density'`distribution'`eta'`marginal'`fixedonly'`conditional'"!="" | ///
                trim(`"`pr0'`outcome'"')!="" {
                di as err "xtnbreg, fe active-system prediction supports nu0 or xb"
                exit 198
            }
            local nstat=("`xb'"!="")+("`nu0'"!="")
            if `nstat'>1 {
                di as err "specify only one of nu0 or xb"
                exit 198
            }
            local pass "xb"
            if "`nu0'"!="" local pass "nu0"
            if "`nooffset'"!="" local pass `"`pass' nooffset"'
            suest2_p_legacy `typlist' `varlist' `if' `in', model(`model') `pass'
            exit
        }

        local xtdistribution=lower(trim(`"`e(suest2_distribution`imodel')'"'))
        if "`xtmodel'"=="re" & "`xtdistribution'"=="beta" {
            if "`mu'`pr'`pu0'`n'`mean'`median'`surv'`hazard'`density'`distribution'`eta'`marginal'`fixedonly'`conditional'"!="" | ///
                `"`outcome'"'!="" {
                di as err "beta xtnbreg, re active-system prediction supports nu0, iru0, pr0(), or xb"
                exit 198
            }
            local nstat=("`xb'"!="")+("`nu0'"!="")+("`iru0'"!="")+(trim(`"`pr0'"')!="")
            if `nstat'>1 {
                di as err "specify only one beta xtnbreg, re prediction statistic"
                exit 198
            }
            local pass "xb"
            if "`nu0'"!="" local pass "nu0"
            else if "`iru0'"!="" local pass "iru0"
            else if trim(`"`pr0'"')!="" local pass `"pr0(`pr0')"'
            if "`nooffset'"!="" local pass `"`pass' nooffset"'
            suest2_p_legacy `typlist' `varlist' `if' `in', model(`model') `pass'
            exit
        }

        di as err "xtnbreg active-system prediction is implemented for fe and beta re models"
        exit 321
    }

    if "`cmd'"=="xtpoisson" {
        if "`xtmodel'"=="fe" {
            if "`mu'`pr'`pu0'`n'`iru0'`mean'`median'`surv'`hazard'`density'`distribution'`eta'`marginal'`fixedonly'`conditional'"!="" | ///
                trim(`"`pr0'`outcome'"')!="" {
                di as err "xtpoisson, fe active-system prediction supports nu0 or xb"
                exit 198
            }
            local nstat=("`xb'"!="")+("`nu0'"!="")
            if `nstat'>1 {
                di as err "specify only one of nu0 or xb"
                exit 198
            }
            local pass "xb"
            if "`nu0'"!="" local pass "nu0"
            if "`nooffset'"!="" local pass `"`pass' nooffset"'
            suest2_p_legacy `typlist' `varlist' `if' `in', model(`model') `pass'
            exit
        }

        local xtdistribution=lower(trim(`"`e(suest2_distribution`imodel')'"'))
        if "`xtmodel'"=="re" & "`xtdistribution'"=="gamma" {
            if "`mu'`pr'`pu0'`n'`mean'`median'`surv'`hazard'`density'`distribution'`eta'`marginal'`fixedonly'`conditional'"!="" | ///
                `"`outcome'"'!="" {
                di as err "gamma xtpoisson, re active-system prediction supports nu0, iru0, pr0(), or xb"
                exit 198
            }
            local nstat=("`xb'"!="")+("`nu0'"!="")+("`iru0'"!="")+(trim(`"`pr0'"')!="")
            if `nstat'>1 {
                di as err "specify only one gamma xtpoisson, re prediction statistic"
                exit 198
            }
            local pass "xb"
            if "`nu0'"!="" local pass "nu0"
            else if "`iru0'"!="" local pass "iru0"
            else if trim(`"`pr0'"')!="" local pass `"pr0(`pr0')"'
            if "`nooffset'"!="" local pass `"`pass' nooffset"'
            suest2_p_legacy `typlist' `varlist' `if' `in', model(`model') `pass'
            exit
        }

        if "`mu'`pr'`pu0'`mean'`median'`surv'`hazard'`density'`distribution'`eta'`marginal'`fixedonly'`conditional'"!="" | ///
            `"`outcome'"'!="" {
            di as err "xtpoisson active-system prediction supports n, nu0, iru0, pr0(), or xb"
            exit 198
        }
        local nstat=("`xb'"!="")+("`n'"!="")+("`nu0'"!="")+("`iru0'"!="")+(trim(`"`pr0'"')!="")
        if `nstat'>1 {
            di as err "specify only one xtpoisson prediction statistic"
            exit 198
        }
        local pass "n"
        if "`xb'"!="" local pass "xb"
        else if "`nu0'"!="" local pass "nu0"
        else if "`iru0'"!="" local pass "iru0"
        else if trim(`"`pr0'"')!="" local pass `"pr0(`pr0')"'
        if "`nooffset'"!="" local pass `"`pass' nooffset"'
        suest2_p_legacy `typlist' `varlist' `if' `in', model(`model') `pass'
        exit
    }

    if "`cmd'"=="xtreg" & "`xtmodel'"=="ml" {
        if `"`outcome'"'!="" | "`pr'"!="" {
            di as err "xtreg, mle active-system prediction supports only xb"
            exit 198
        }
        tempvar eta
        quietly _predict double `eta' `if' `in', xb equation(#`eqstart')
        local offset `"`e(suest2_offset`imodel')'"'
        if trim(`"`offset'"') == "" {
            quietly generate `typlist' `varlist' = `eta' `if' `in'
        }
        else {
            tempvar offsetvalue
            capture quietly generate double `offsetvalue' = `offset' `if' `in'
            local offsetrc = _rc
            if `offsetrc' {
                di as err "unable to evaluate offset {bf:`offset'} for model {bf:`model'}"
                exit `offsetrc'
            }
            quietly generate `typlist' `varlist' = `eta'+`offsetvalue' `if' `in'
        }
        label variable `varlist' "Linear prediction"
        exit
    }
    if "`cmd'"=="xtreg" & "`xtmodel'"=="cre" {
        if `"`outcome'"'!="" | "`pr'"!="" {
            di as err "xtreg, cre active-system prediction supports only xb"
            exit 198
        }
        suest2_p_cre `typlist' `varlist' `if' `in', imodel(`imodel') model(`model')
        exit
    }



    // Native nonlinear multilevel predictions.
    //
    // IMPORTANT: this code is intentionally inline.  Do not route these
    // predictions through another wrapper and do not build a macro containing
    // the native option list.  Nested prediction wrappers caused r(920)
    // ("macro substitution results in line that is too long").  Instead, this
    // branch restores the private constituent result, reposts the selected
    // coefficient block, and calls the native predictor explicitly.
    if "`cmd'"=="mestreg" | ///
        inlist("`cmd'","melogit","meprobit","mecloglog","mepoisson","menbreg","meologit","meoprobit","megaussian","megamma") {

        local pstat
        local pintegration
        local poutcome `"`outcome'"'

        if "`cmd'"=="mestreg" {
            if "`fixedonly'"!="" {
                di as err "mestreg uses conditional(fixedonly), not fixedonly"
                exit 198
            }
            if "`mu'`pr'"!="" | `"`outcome'"'!="" {
                di as err "mestreg prediction does not allow mu, pr, or outcome()"
                exit 198
            }
            if "`suestxb'"!="" local xb xb
            local nstat=("`xb'"!="")+("`mean'"!="")+("`median'"!="")+ ///
                ("`surv'"!="")+("`hazard'"!="")+("`density'"!="")+ ///
                ("`distribution'"!="")+("`eta'"!="")
            if `nstat'>1 {
                di as err "specify only one mestreg prediction statistic"
                exit 198
            }

            local cond=lower(itrim(trim(`"`conditional'"')))
            if trim(`"`cond'"')!="" & `"`cond'"'!="fixedonly" {
                di as err "active-system mestreg prediction supports only conditional(fixedonly)"
                exit 198
            }
            if trim(`"`cond'"')!="" & "`marginal'"!="" {
                di as err "specify either conditional(fixedonly) or marginal, not both"
                exit 198
            }
            if "`xb'"!="" & (trim(`"`cond'"')!="" | "`marginal'`nooffset'"!="") {
                di as err "xb may not be combined with conditional(), marginal, or nooffset"
                exit 198
            }
            if "`eta'`median'"!="" & trim(`"`cond'"')=="" {
                di as err "eta and median require conditional(fixedonly)"
                exit 198
            }
            if "`eta'`median'"!="" & "`marginal'"!="" {
                di as err "eta and median do not support marginal"
                exit 198
            }
            if "`surv'`hazard'`density'`distribution'"!="" & ///
                trim(`"`cond'"')=="" & "`marginal'"=="" {
                di as err "surv, hazard, density, and distribution require conditional(fixedonly) or marginal"
                exit 198
            }

            local pstat mean
            if "`xb'"!="" local pstat xb
            else if "`mean'"!="" local pstat mean
            else if "`median'"!="" local pstat median
            else if "`surv'"!="" local pstat surv
            else if "`hazard'"!="" local pstat hazard
            else if "`density'"!="" local pstat density
            else if "`distribution'"!="" local pstat distribution
            else if "`eta'"!="" local pstat eta

            local pintegration marginal
            if trim(`"`cond'"')!="" local pintegration fixed
            else if inlist("`pstat'","eta","median") local pintegration fixed
        }
        else {
            local isordered=inlist("`cmd'","meologit","meoprobit")
            local iscount=inlist("`cmd'","mepoisson","menbreg")
            local isbinary=inlist("`cmd'","melogit","meprobit","mecloglog")
            local cond=lower(itrim(trim(`"`conditional'"')))

            // Do not concatenate all option locals into one expression.  In
            // this branch, that expression can trigger r(920) even when every
            // local reports length zero.  Inspect lengths one local at a time.
            local __s2_badopt 0
            foreach __s2_opt in pcr pu0 n nu0 iru0 rate mean median surv hazard density distribution eta ystar expected prrange xbsel psel ycond yexpected mills nshazard pr0 {
                local __s2_oplen : length local `__s2_opt'
                if `__s2_oplen'>0 local __s2_badopt 1
            }
            if `__s2_badopt' {
                di as err "the requested prediction statistic is not supported for `cmd'"
                exit 198
            }
            if "`fixedonly'"!="" & (trim(`"`cond'"')!="" | "`marginal'"!="") {
                di as err "specify only one of fixedonly, conditional(), or marginal"
                exit 198
            }
            if trim(`"`cond'"')!="" & "`marginal'"!="" {
                di as err "specify either conditional() or marginal, not both"
                exit 198
            }
            if trim(`"`cond'"')!="" & `"`cond'"'!="fixedonly" {
                di as err "active-system `cmd' prediction supports only conditional(fixedonly)"
                exit 198
            }

            if `isordered' {
                if "`mu'`fixedonly'`nooffset'"!="" {
                    di as err "`cmd' active-system prediction supports pr or xb; use conditional(fixedonly) or marginal with pr"
                    exit 198
                }
                local nstat=("`xb'"!="")+("`pr'"!="")
                if `nstat'>1 {
                    di as err "specify only one of pr or xb"
                    exit 198
                }
                if "`xb'"!="" local pstat xb
                else {
                    local pstat pr
                    if trim(`"`poutcome'"')=="" local poutcome : word 1 of `outcomes'
                    local pintegration marginal
                    if trim(`"`cond'"')!="" local pintegration fixed
                }
            }
            else {
                if `"`outcome'"'!="" {
                    di as err "option outcome() is not allowed for `cmd'"
                    exit 198
                }
                if "`pr'"!="" & !`isbinary' {
                    di as err "option pr is allowed only for binary-response multilevel models"
                    exit 198
                }
                local nstat=("`xb'"!="")+("`mu'"!="")+("`pr'"!="")
                if `nstat'>1 {
                    di as err "specify only one of xb, mu, or pr"
                    exit 198
                }
                if "`xb'"!="" local pstat xb
                else {
                    local pstat mu
                    local pintegration marginal
                    if "`fixedonly'"!="" | trim(`"`cond'"')!="" local pintegration fixed
                }
            }
        }

        local pstart=e(suest2_start`imodel')
        local pkorig=e(suest2_korig`imodel')
        local pend=`pstart'+`pkorig'-1
        local psource `"`e(suest2_hold`imodel')'"'

        tempname pbsystem pbwork pborig pcurrent
        matrix `pbsystem'=e(b)
        matrix `pbwork'=`pbsystem'[1,`pstart'..`pend']
        quietly estimates store `pcurrent'

        local prc 0
        capture quietly estimates restore `psource'
        local prc=_rc
        if !`prc' {
            matrix `pborig'=e(b)
            mata: _s2p_mergestripe("`pbwork'","`pborig'")
            capture quietly suest2_p_repost `pbwork'
            local prc=_rc
        }

        if !`prc' {
            // The constituent estimate is now active, so call Stata's official
            // predict dispatcher.  Do not invoke melogit_p/meglm_p/etc.
            // directly from inside suest2_p; nesting _p programs triggers
            // recursive macro expansion and r(920).
            if "`cmd'"=="melogit" {
                if "`pstat'"=="xb" {
                    if "`nooffset'"!="" capture noisily predict `typlist' `varlist' `if' `in', xb nooffset
                    else capture noisily predict `typlist' `varlist' `if' `in', xb
                }
                else if "`pintegration'"=="fixed" {
                    if "`nooffset'"!="" capture noisily predict `typlist' `varlist' `if' `in', mu fixedonly nooffset
                    else capture noisily predict `typlist' `varlist' `if' `in', mu fixedonly
                }
                else {
                    if "`nooffset'"!="" capture noisily predict `typlist' `varlist' `if' `in', mu marginal nooffset
                    else capture noisily predict `typlist' `varlist' `if' `in', mu marginal
                }
            }
            else if "`cmd'"=="meprobit" {
                if "`pstat'"=="xb" {
                    if "`nooffset'"!="" capture noisily predict `typlist' `varlist' `if' `in', xb nooffset
                    else capture noisily predict `typlist' `varlist' `if' `in', xb
                }
                else if "`pintegration'"=="fixed" {
                    if "`nooffset'"!="" capture noisily predict `typlist' `varlist' `if' `in', mu fixedonly nooffset
                    else capture noisily predict `typlist' `varlist' `if' `in', mu fixedonly
                }
                else {
                    if "`nooffset'"!="" capture noisily predict `typlist' `varlist' `if' `in', mu marginal nooffset
                    else capture noisily predict `typlist' `varlist' `if' `in', mu marginal
                }
            }
            else if "`cmd'"=="mecloglog" {
                if "`pstat'"=="xb" {
                    if "`nooffset'"!="" capture noisily predict `typlist' `varlist' `if' `in', xb nooffset
                    else capture noisily predict `typlist' `varlist' `if' `in', xb
                }
                else if "`pintegration'"=="fixed" {
                    if "`nooffset'"!="" capture noisily predict `typlist' `varlist' `if' `in', mu fixedonly nooffset
                    else capture noisily predict `typlist' `varlist' `if' `in', mu fixedonly
                }
                else {
                    if "`nooffset'"!="" capture noisily predict `typlist' `varlist' `if' `in', mu marginal nooffset
                    else capture noisily predict `typlist' `varlist' `if' `in', mu marginal
                }
            }
            else if "`cmd'"=="mepoisson" {
                if "`pstat'"=="xb" {
                    if "`nooffset'"!="" capture noisily predict `typlist' `varlist' `if' `in', xb nooffset
                    else capture noisily predict `typlist' `varlist' `if' `in', xb
                }
                else if "`pintegration'"=="fixed" {
                    if "`nooffset'"!="" capture noisily predict `typlist' `varlist' `if' `in', mu conditional(fixedonly) nooffset
                    else capture noisily predict `typlist' `varlist' `if' `in', mu conditional(fixedonly)
                }
                else {
                    if "`nooffset'"!="" capture noisily predict `typlist' `varlist' `if' `in', mu marginal nooffset
                    else capture noisily predict `typlist' `varlist' `if' `in', mu marginal
                }
            }
            else if "`cmd'"=="menbreg" {
                if "`pstat'"=="xb" {
                    if "`nooffset'"!="" capture noisily predict `typlist' `varlist' `if' `in', xb nooffset
                    else capture noisily predict `typlist' `varlist' `if' `in', xb
                }
                else if "`pintegration'"=="fixed" {
                    if "`nooffset'"!="" capture noisily predict `typlist' `varlist' `if' `in', mu conditional(fixedonly) nooffset
                    else capture noisily predict `typlist' `varlist' `if' `in', mu conditional(fixedonly)
                }
                else {
                    if "`nooffset'"!="" capture noisily predict `typlist' `varlist' `if' `in', mu marginal nooffset
                    else capture noisily predict `typlist' `varlist' `if' `in', mu marginal
                }
            }
            else if "`cmd'"=="meologit" {
                if "`pstat'"=="xb" capture noisily predict `typlist' `varlist' `if' `in', xb
                else if "`pintegration'"=="fixed" capture noisily predict `typlist' `varlist' `if' `in', pr outcome(`poutcome') conditional(fixedonly)
                else capture noisily predict `typlist' `varlist' `if' `in', pr outcome(`poutcome') marginal
            }
            else if "`cmd'"=="meoprobit" {
                if "`pstat'"=="xb" capture noisily predict `typlist' `varlist' `if' `in', xb
                else if "`pintegration'"=="fixed" capture noisily predict `typlist' `varlist' `if' `in', pr outcome(`poutcome') conditional(fixedonly)
                else capture noisily predict `typlist' `varlist' `if' `in', pr outcome(`poutcome') marginal
            }
            else if inlist("`cmd'","megaussian","megamma") {
                if "`pstat'"=="xb" {
                    if "`nooffset'"!="" capture noisily predict `typlist' `varlist' `if' `in', xb nooffset
                    else capture noisily predict `typlist' `varlist' `if' `in', xb
                }
                else if "`pintegration'"=="fixed" {
                    if "`nooffset'"!="" capture noisily predict `typlist' `varlist' `if' `in', mu conditional(fixedonly) nooffset
                    else capture noisily predict `typlist' `varlist' `if' `in', mu conditional(fixedonly)
                }
                else {
                    if "`nooffset'"!="" capture noisily predict `typlist' `varlist' `if' `in', mu marginal nooffset
                    else capture noisily predict `typlist' `varlist' `if' `in', mu marginal
                }
            }
            else if "`cmd'"=="mestreg" {
                if "`pstat'"=="xb" capture noisily predict `typlist' `varlist' `if' `in', xb
                else if "`pstat'"=="mean" {
                    if "`pintegration'"=="fixed" {
                        if "`nooffset'"!="" capture noisily predict `typlist' `varlist' `if' `in', mean conditional(fixedonly) nooffset
                        else capture noisily predict `typlist' `varlist' `if' `in', mean conditional(fixedonly)
                    }
                    else {
                        if "`nooffset'"!="" capture noisily predict `typlist' `varlist' `if' `in', mean marginal nooffset
                        else capture noisily predict `typlist' `varlist' `if' `in', mean marginal
                    }
                }
                else if "`pstat'"=="median" {
                    if "`nooffset'"!="" capture noisily predict `typlist' `varlist' `if' `in', median conditional(fixedonly) nooffset
                    else capture noisily predict `typlist' `varlist' `if' `in', median conditional(fixedonly)
                }
                else if "`pstat'"=="eta" {
                    if "`nooffset'"!="" capture noisily predict `typlist' `varlist' `if' `in', eta conditional(fixedonly) nooffset
                    else capture noisily predict `typlist' `varlist' `if' `in', eta conditional(fixedonly)
                }
                else if "`pstat'"=="surv" {
                    if "`pintegration'"=="fixed" {
                        if "`nooffset'"!="" capture noisily predict `typlist' `varlist' `if' `in', surv conditional(fixedonly) nooffset
                        else capture noisily predict `typlist' `varlist' `if' `in', surv conditional(fixedonly)
                    }
                    else {
                        if "`nooffset'"!="" capture noisily predict `typlist' `varlist' `if' `in', surv marginal nooffset
                        else capture noisily predict `typlist' `varlist' `if' `in', surv marginal
                    }
                }
                else if "`pstat'"=="hazard" {
                    if "`pintegration'"=="fixed" {
                        if "`nooffset'"!="" capture noisily predict `typlist' `varlist' `if' `in', hazard conditional(fixedonly) nooffset
                        else capture noisily predict `typlist' `varlist' `if' `in', hazard conditional(fixedonly)
                    }
                    else {
                        if "`nooffset'"!="" capture noisily predict `typlist' `varlist' `if' `in', hazard marginal nooffset
                        else capture noisily predict `typlist' `varlist' `if' `in', hazard marginal
                    }
                }
                else if "`pstat'"=="density" {
                    if "`pintegration'"=="fixed" {
                        if "`nooffset'"!="" capture noisily predict `typlist' `varlist' `if' `in', density conditional(fixedonly) nooffset
                        else capture noisily predict `typlist' `varlist' `if' `in', density conditional(fixedonly)
                    }
                    else {
                        if "`nooffset'"!="" capture noisily predict `typlist' `varlist' `if' `in', density marginal nooffset
                        else capture noisily predict `typlist' `varlist' `if' `in', density marginal
                    }
                }
                else if "`pstat'"=="distribution" {
                    if "`pintegration'"=="fixed" {
                        if "`nooffset'"!="" capture noisily predict `typlist' `varlist' `if' `in', distribution conditional(fixedonly) nooffset
                        else capture noisily predict `typlist' `varlist' `if' `in', distribution conditional(fixedonly)
                    }
                    else {
                        if "`nooffset'"!="" capture noisily predict `typlist' `varlist' `if' `in', distribution marginal nooffset
                        else capture noisily predict `typlist' `varlist' `if' `in', distribution marginal
                    }
                }
            }
            local prc=_rc
        }

        capture quietly estimates restore `pcurrent'
        local prc_restore=_rc
        capture quietly estimates drop `pcurrent'
        if `prc_restore' exit `prc_restore'
        if `prc' exit `prc'
        exit
    }

    // Families handled by the shared me branch above (opens line 622): melogit,
    // meprobit, mecloglog, mepoisson, menbreg, meologit, meoprobit,
    // megaussian, megamma and mestreg.  That branch is at brace depth 0,
    // its condition names all ten, and it always exits -- so per-family
    // blocks for them here could never run.  Six such blocks (about 445
    // lines) were removed at candidate 9; measured dead 03aug2026 for seven
    // of the nine families, each of the six blocks confirmed by at least one
    // of its own families (diag_p_deadbranch.log).  mixed is NOT in the 614
    // list, which is why its block below is live.

    if "`cmd'"=="mixed" {
        if `"`outcome'"'!="" | "`pr'"!="" {
            di as err "mixed active-system prediction supports only the fixed-effects linear prediction"
            exit 198
        }
        quietly _predict `typlist' `varlist' `if' `in', xb equation(#`eqstart')
        label variable `varlist' "Linear prediction, fixed portion"
        exit
    }


    if "`cmd'"=="xtgee" & "`xtmodel'"=="pa" {
        if `"`outcome'"'!="" | "`pr'"!="" {
            di as err "xtreg, pa active-system prediction supports only the linear mean"
            exit 198
        }
        quietly _predict `typlist' `varlist' `if' `in', xb equation(#`eqstart')
        label variable `varlist' "Population-averaged linear prediction"
        exit
    }

    // Linear, binary-response, and count-response models.
    if inlist("`cmd'", "regress", "anova", "xtreg", "ivregress", "logit", "logistic", "probit", "poisson", "nbreg") {
        if `"`outcome'"' != "" {
            di as err "option outcome() is not allowed for a {bf:`cmd'} model"
            exit 198
        }

        // 0.1.89: family statistic gate (PRED-ORD-1). Refuse recognized
        // tokens this branch does not implement instead of silently
        // dispatching the family default.
        local badopt 0
        foreach opt in pcr pu0 nu0 iru0 mu rate mean median surv hazard density distribution eta marginal fixedonly conditional nooffset ystar expected prrange xbsel psel ycond yexpected mills nshazard xb0 {
            if `"``opt''"' != "" local badopt 1
        }
        if trim(`"`pr0'"') != "" local badopt 1
        if inlist("`cmd'", "regress", "anova", "xtreg", "ivregress") {
            if "`pr'`n'" != "" local badopt 1
            if `badopt' {
                di as err "`cmd' active-system prediction supports only the linear prediction, xb"
                exit 198
            }
        }
        else if inlist("`cmd'", "logit", "logistic", "probit") {
            if "`n'" != "" local badopt 1
            if `badopt' {
                di as err "`cmd' active-system prediction supports the native default, pr, or xb"
                exit 198
            }
            local nstat = ("`xb'" != "") + ("`pr'" != "")
            if `nstat' > 1 {
                di as err "specify only one of pr or xb"
                exit 198
            }
        }
        else {
            if "`pr'" != "" local badopt 1
            if `badopt' {
                di as err "`cmd' active-system prediction supports the native default, n, or xb"
                exit 198
            }
            local nstat = ("`xb'" != "") + ("`n'" != "")
            if `nstat' > 1 {
                di as err "specify only one of n or xb"
                exit 198
            }
        }

        if `wantxb' | inlist("`cmd'", "regress", "anova", "xtreg", "ivregress") {
            quietly _predict `typlist' `varlist' `if' `in', xb equation(#`eqstart')
            if inlist("`cmd'", "regress", "anova", "xtreg", "ivregress") label variable `varlist' "Linear prediction"
            else label variable `varlist' "Linear prediction for `depvar'"
            exit
        }

        tempvar eta
        quietly _predict double `eta' `if' `in', xb equation(#`eqstart')
        if inlist("`cmd'", "logit", "logistic") {
            quietly generate `typlist' `varlist' = invlogit(`eta') `if' `in'
            label variable `varlist' "Pr(`depvar')"
        }
        else if "`cmd'" == "probit" {
            quietly generate `typlist' `varlist' = normal(`eta') `if' `in'
            label variable `varlist' "Pr(`depvar')"
        }
        else {
            // Count-model defaults are response-scale means.  The stacked
            // equation contains coefficient xb only, so add the constituent
            // offset/exposure expression explicitly when one was used.
            local offset `"`e(suest2_offset`imodel')'"'
            if `"`offset'"' == "" {
                quietly generate `typlist' `varlist' = exp(`eta') `if' `in'
            }
            else {
                tempvar offsetvalue
                capture quietly generate double `offsetvalue' = `offset' `if' `in'
                local offsetrc = _rc
                if `offsetrc' {
                    di as err "unable to evaluate offset {bf:`offset'} for model {bf:`model'}"
                    di as err "the offset/exposure variable may have changed since estimation"
                    exit `offsetrc'
                }
                quietly generate `typlist' `varlist' = exp(`eta' + `offsetvalue') `if' `in'
            }
            label variable `varlist' "Predicted mean of `depvar'"
        }
        exit
    }

    // Generalized ordered-response models. The generic suest route already
    // retains the complete native gologit2 coefficient block, constraints,
    // link, category metadata, and private constituent result. Repost the
    // active joint-system coefficient block into that private result and use
    // gologit2_p so prediction and margins retain the native response map.
    if "`cmd'"=="gologit2" {
        if "`pcr'`pu0'`n'`nu0'`iru0'`pr0'`mu'`rate'`mean'`median'`surv'`hazard'`density'`distribution'`eta'`marginal'`fixedonly'`conditional'`nooffset'"!="" {
            di as err "gologit2 active-system prediction supports pr or xb with outcome()"
            exit 198
        }

        local nstat=("`xb'"!="")+("`pr'"!="")
        if `nstat'>1 {
            di as err "specify only one of pr or xb for gologit2"
            exit 198
        }

        local gout=trim(`"`outcome'"')
        if `"`gout'"'=="" local gout : word 1 of `outcomes'
        if `"`gout'"'=="" {
            di as err "gologit2 outcome metadata are unavailable for model {bf:`model'}"
            exit 498
        }

        local pass "pr"
        if "`xb'"!="" local pass "xb"
        local pass `"`pass' outcome(`gout')"'
        suest2_p_legacy `typlist' `varlist' `if' `in', model(`model') `pass'
        exit
    }

    // Ordered logit/probit.  Numeric equation() positions after the primary xb
    // are the cutpoint equations posted by official suest.
    if inlist("`cmd'", "ologit", "oprobit") {
        if `wantxb' {
            quietly _predict `typlist' `varlist' `if' `in', xb equation(#`eqstart')
            label variable `varlist' "Linear prediction (cutpoints excluded)"
            exit
        }
        if `"`outcome'"' == "" {
            di as err "option outcome() is required for response-scale prediction after {bf:`cmd'}"
            exit 198
        }

        local nout : word count `outcomes'
        local pos 0
        forvalues j = 1/`nout' {
            local outj : word `j' of `outcomes'
            if `"`outcome'"' == `"`outj'"' local pos = `j'
        }
        if !`pos' {
            di as err "outcome {bf:`outcome'} was not found; available outcomes: `outcomes'"
            exit 198
        }

        tempvar eta cutlo cuthi
        quietly _predict double `eta' `if' `in', xb equation(#`eqstart')

        if `pos' == 1 {
            local qhi = `eqstart' + 1
            quietly _predict double `cuthi' `if' `in', xb equation(#`qhi')
            if "`cmd'" == "ologit" quietly generate `typlist' `varlist' = invlogit(`cuthi' - `eta') `if' `in'
            else quietly generate `typlist' `varlist' = normal(`cuthi' - `eta') `if' `in'
        }
        else if `pos' == `nout' {
            local qlo = `eqstart' + `nout' - 1
            quietly _predict double `cutlo' `if' `in', xb equation(#`qlo')
            if "`cmd'" == "ologit" quietly generate `typlist' `varlist' = 1 - invlogit(`cutlo' - `eta') `if' `in'
            else quietly generate `typlist' `varlist' = 1 - normal(`cutlo' - `eta') `if' `in'
        }
        else {
            local qlo = `eqstart' + `pos' - 1
            local qhi = `eqstart' + `pos'
            quietly _predict double `cutlo' `if' `in', xb equation(#`qlo')
            quietly _predict double `cuthi' `if' `in', xb equation(#`qhi')
            if "`cmd'" == "ologit" quietly generate `typlist' `varlist' = ///
                invlogit(`cuthi' - `eta') - invlogit(`cutlo' - `eta') `if' `in'
            else quietly generate `typlist' `varlist' = ///
                normal(`cuthi' - `eta') - normal(`cutlo' - `eta') `if' `in'
        }
        label variable `varlist' "Pr(`depvar'==`outcome')"
        exit
    }

    // Multinomial logit.  Official suest posts an explicit omitted base
    // equation.  Its linear predictor is fixed at zero and must not be treated
    // as a freely varying parameter equation during numerical differentiation.
    if "`cmd'" == "mlogit" {
        if `"`outcome'"' == "" {
            di as err "option outcome() is required after {bf:mlogit}"
            exit 198
        }

        local nout : word count `outcomes'
        local targetpos 0
        forvalues q = 1/`nout' {
            local outq : word `q' of `outcomes'
            if `"`outcome'"' == `"`outq'"' local targetpos = `q'
        }
        if !`targetpos' {
            di as err "outcome {bf:`outcome'} was not found; available outcomes: `outcomes'"
            exit 198
        }

        local basepos = e(suest2_ibaseout`imodel')
        if !`basepos' {
            local baseout `"`e(suest2_baseout`imodel')'"'
            forvalues q = 1/`nout' {
                local outq : word `q' of `outcomes'
                if `"`baseout'"' == `"`outq'"' local basepos = `q'
            }
        }
        if !`basepos' {
            di as err "suest2 could not identify the multinomial base outcome"
            exit 498
        }

        if `wantxb' {
            if `targetpos' == `basepos' quietly generate `typlist' `varlist' = 0 `if' `in'
            else {
                local qeq = `eqstart' + `targetpos' - 1
                quietly _predict `typlist' `varlist' `if' `in', xb equation(#`qeq')
            }
            label variable `varlist' "Linear prediction for outcome `outcome'"
            exit
        }

        tempvar denom numer
        quietly generate double `denom' = 0 `if' `in'
        forvalues q = 1/`nout' {
            if `q' == `basepos' {
                quietly replace `denom' = `denom' + 1 `if' `in'
                if `q' == `targetpos' quietly generate double `numer' = 1 `if' `in'
            }
            else {
                tempvar eta`q'
                local qeq = `eqstart' + `q' - 1
                quietly _predict double `eta`q'' `if' `in', xb equation(#`qeq')
                quietly replace `denom' = `denom' + exp(`eta`q'') `if' `in'
                if `q' == `targetpos' quietly generate double `numer' = exp(`eta`q'') `if' `in'
            }
        }
        quietly generate `typlist' `varlist' = `numer'/`denom' `if' `in'
        label variable `varlist' "Pr(`depvar'==`outcome')"
        exit
    }

    di as err "prediction is not implemented for {bf:`cmd'}"
    exit 321
end


program define suest2_p_cre
    version 16
    syntax newvarname [if] [in], IMODEL(integer) MODEL(string)

    local start = e(suest2_start`imodel')
    local korig = e(suest2_korig`imodel')
    local kbase = e(suest2_xtcre_kbase`imodel')
    local vars `"`e(suest2_xtcre_vars`imodel')'"'
    local ivar `"`e(suest2_xtcre_panelvar)'"'
    local source `"`e(suest2_hold`imodel')'"'

    if `korig' != 2*`kbase'+1 {
        di as err "suest2 retained an invalid CRE coefficient layout for model {bf:`model'}"
        exit 498
    }

    tempname bsys bmodel current
    matrix `bsys' = e(b)
    local end = `start'+`korig'-1
    matrix `bmodel' = `bsys'[1,`start'..`end']

    tempvar modelsample
    quietly estimates store `current'
    capture quietly estimates restore `source'
    local rc = _rc
    if !`rc' generate byte `modelsample' = e(sample)
    capture quietly estimates restore `current'
    local rcr = _rc
    capture quietly estimates drop `current'
    if `rcr' exit `rcr'
    if `rc' exit `rc'

    marksample touse, novarlist
    quietly replace `touse' = 0 if !`modelsample'

    local rawlist
    local meanlist
    forvalues j = 1/`kbase' {
        local term : word `j' of `vars'
        capture quietly fvrevar `term'
        if _rc {
            di as err "unable to evaluate CRE term {bf:`term'} for model {bf:`model'}"
            exit _rc
        }
        local raw `"`r(varlist)'"'
        local nraw : word count `raw'
        if `nraw' != 1 {
            di as err "CRE term {bf:`term'} did not expand to one variable"
            exit 498
        }
        tempvar rawcopy meanx
        quietly generate double `rawcopy' = `raw' if `touse'
        quietly bysort `ivar': egen double `meanx' = mean(`rawcopy') if `touse'
        local rawlist `rawlist' `rawcopy'
        local meanlist `meanlist' `meanx'
    }

    local conspos = `kbase'+1
    quietly generate `typlist' `varlist' = el(`bmodel',1,`conspos') if `touse'
    forvalues j = 1/`kbase' {
        local raw : word `j' of `rawlist'
        local mx : word `j' of `meanlist'
        local meanpos = `kbase'+1+`j'
        quietly replace `varlist' = `varlist' + ///
            el(`bmodel',1,`j')*`raw' + el(`bmodel',1,`meanpos')*`mx' if `touse'
    }
    label variable `varlist' "Linear prediction"
end

program define suest2_p_legacy
    version 16
    syntax newvarname [if] [in] [, MODEL(string) *]

    local names `"`e(names)'"'
    local nmodels = e(suest2_nmodels)
    local imodel 0
    forvalues i = 1/`nmodels' {
        local name : word `i' of `names'
        if `"`model'"' == `"`name'"' local imodel `i'
    }
    if !`imodel' {
        di as err "model {bf:`model'} was not included in suest2"
        exit 198
    }

    local start = e(suest2_start`imodel')
    local korig = e(suest2_korig`imodel')
    local end = `start' + `korig' - 1
    local source `"`e(suest2_hold`imodel')'"'

    tempname bsuest bwork borig current
    matrix `bsuest' = e(b)
    matrix `bwork' = `bsuest'[1, `start'..`end']

    quietly estimates store `current'
    local rc 0
    capture quietly estimates restore `source'
    local rc = _rc
    if !`rc' {
        matrix `borig' = e(b)
        mata: _s2p_mergestripe("`bwork'", "`borig'")
        capture quietly suest2_p_repost `bwork'
        local rc = _rc
        if !`rc' {
            local predictor `"`e(predict)'"'
            if `"`predictor'"' == "" local predictor _predict
            local comma
            if trim(`"`options'"') != "" local comma ","
            capture noisily `predictor' `typlist' `varlist' `if' `in' `comma' `options'
            local rc = _rc
        }
    }

    capture quietly estimates restore `current'
    local rc_restore = _rc
    capture quietly estimates drop `current'
    if `rc_restore' exit `rc_restore'
    if `rc' exit `rc'
end

program define suest2_p_repost, eclass
    version 16
    args b
    ereturn repost b=`b', rename
end

* Stripe merge for the restore/repost bridges (0.1.87). MEASURED
* (probe_legacy_bridge_mech_v1, 25aug2026): margins implements scalar-list
* factor at() counterfactuals by REBINDING the factor columns of the ACTIVE
* e(b) column stripe to counterfactual tempvars (e.g. 0b.b -> __00000J);
* the data are never rewritten. The old bridges took the entire stripe from
* the restored ORIGINAL result, discarding those rebinds, so the native
* predictor evaluated the real variables and every factor counterfactual
* was invariant (S2-PRED-1, M1-PRED-1). The merge keeps the ORIGINAL
* equation names, which the native predictor requires, and adopts a column
* NAME from the active sub-block only where it differs from the original
* AND carries the margins tempvar signature -- any other name difference
* keeps the original name, i.e. exactly the old behavior. On a row-count
* mismatch the whole merge falls back to the original stripe.
version 16
mata:
void _s2p_mergestripe(string scalar work, string scalar orig)
{
    string matrix so, sw
    real scalar i
    so = st_matrixcolstripe(orig)
    sw = st_matrixcolstripe(work)
    if (rows(so) == rows(sw)) {
        for (i = 1; i <= rows(so); i++) {
            if (sw[i,2] != so[i,2] & strpos(sw[i,2], "__0")) so[i,2] = sw[i,2]
        }
    }
    st_matrixcolstripe(work, so)
}
end
