*********************
// mec_mlincom.ado //
*********************

*Trenton Mize 2019-03-18
*	mec_mlincom is an adaptation of mlincom for use inside of mecompare.ado
*	Specifies the lincom expression rather than the row number

*! version 1.0.3 2015-01-09 | long freese | tweak row margin
* version 1.0.2 2014-10-01 | long freese | always allow non margins
* version 1.0.1 2014-09-28 | long freese | force if not margins
* version 1.0.0 2014-02-18 | long freese | spost13 release

//  generate lincom expression and sent it to lincom

*   DO: trap errors from lincom
capture program drop mec_mlincom
*! mec_mlincom v0.1.1 Trenton Mize 2019-03-18
program define mec_mlincom

    version 11.2
    tempname newmat newmatall

    syntax [anything] [, ///
        /// results to display
        /// force
            STATS(string asis) STATistics(string asis) ///
            ALLstats /// all stats (p, z, se, level)
            Details /// show lincom output
            NOTABle /// only show lincom
        /// save results to matrix
            clear /// clear matrix before saving
            add save /// add results to matrix
        /// label matrix
            ROWName(string) label(string) /// row name for current estimate
            ROWEQnm(string) /// row eq name for current estimate
            ESTName(string asis) /// allow override margin name for estimate
        /// displaying matrix
            DECimals(integer 3) /// Digits when list matrix
            WIDth(integer 8) /// Column width when listing matrix
            title(string) /// Title when listing
            TWIDth(integer 0) /// 2015-01-09
        ]
    
    else {
        local decimals 3
        local width 8
    }

    if ("`twidth'"=="0") local twopt ""
    else local twopt "twidth(`twidth')" // 2015-01-09

    if ("`label'"=="") local label `"`rowname'"' // synonyms
    if ("`save'"=="save") local add "add" // synonyms
    if ("`details'"=="details") local quietly ""
    else local quietly "quietly"
    * if no table, show lincom output
    if ("`notable'"=="notable") local quietly ""

    local matrix _mlincom
    capture confirm matrix `matrix'
    if (_rc == 0) local matrixexists = 1
    else local matrixexists = 0
    local matrixall _mlincom_allstats
    capture confirm matrix `matrixall'
    if (_rc == 0) local matrixallexists = 1
    else local matrixallexists = 0

    if "`anything'"=="" {
        if `matrixexists' == 1 {
            if "`clear'"=="clear" {
                capture matrix drop `matrix'
                capture matrix drop `matrixall'
                exit
            }
            * if no expression, list table
            matlist `matrix', format(%`width'.`decimals'f) title("`title'") ///
                `twopt'
            exit
        }
        else if ("`clear'"=="clear") exit
        else {
            display as error "you must specify the lincom expression"
            exit
        }
    }

    capture confirm matrix e(b)
    if _rc>0 {
        display as error ///
"mlincom requires e(b) in memory; with margins or mtable, use the post option"
        exit
    }

/*  dropped in 1.0.2 to allow mlincom to work with all estimation commands
    if "`e(cmd)'"!="margins" & "`force'"=="" {
        display as error ///
            "mlincom must be run immediately following margins, post"
        exit
    }
    capture confirm matrix e(b)
    if _rc>0 {
        display as error ///
            "mlincom requires margins or mtable with the post option"
        exit
    }
*/

//  decode expression
*NOTE: What makes mec_mlincom different than mlincom is that it requires a 
*	lincom expression instead of row numbers

/*
    local lc "`expression'"
    foreach c in ( ) + - {
        local lc = subinstr("`lc'","`c'"," `c' ",.)
    }

    * remove o. names from column names
    tempname b
    matrix `b' = e(b)
    local orignms : colfullnames `b'
    local noomitnms "" // without o. names
    foreach var of local orignms {
        _ms_parse_parts `var'
        if (!`r(omit)') local noomitnms `noomitnms' `var'
    }
    local lcstr ""
    foreach e in `lc' {
        if ("`e'"=="(") local lcstr "`lcstr'("
        else if ("`e'"==")") local lcstr "`lcstr')"
        else if ("`e'"=="+") local lcstr "`lcstr'+"
        else if ("`e'"=="-") local lcstr "`lcstr'-"
        else {
            local i = int(real("`e'"))
            if `i' == . {
                display as error "unexpected missing value found"
                exit
            }
            else {
                local bnm : word `i' of `noomitnms'
                local lcstr "`lcstr'_b[`bnm']"
            }
        }
    }
*/

//  run lincom and compute stats

    `quietly' lincom "`anything'"
    _rm_lincom_stats
    scalar estimate = r(est)
    scalar se = r(se)
    scalar zvalue = r(z)
    scalar pvalue = r(p)
    scalar ll = r(lb)
    scalar ul = r(ub)
    scalar lvl = r(level)

//  add results to matrix

    * if not adding, clear matrix
    if "`clear'" == "clear" | "`add'"=="" {
        capture matrix drop `matrix'
        capture matrix drop `matrixall'
        local matrixexists = 0
    }

    local estimatenm "lincom"
    if ("`estname'"!="") local estimatenm "`estname'"

    * what stats go in table
    if ("`stats'"!="" & "`statistics'"=="") local statistics "`stats'"
    local statlist "estimate pvalue ll ul" // default statistics
    local statsall "estimate se zvalue pvalue ll ul"
    if ("`allstats'"=="allstats") local statlist "`statsall'"
    if ("`statistics'"=="noci") local statistics "est"
    if "`statistics'"=="all" {
        local statlist "`statsall'"
    }
    else if "`statistics'"!="" {
        local newstatlist ""
        foreach opt in `statistics' {
            _parse_stat `opt'
            local newopt
            local stat "`s(stat)'"
            local newstatlist "`newstatlist'`stat' "
            if "`s(isbad)'"=="1" {
                display as error ///
                    "invalid statistic specified: `opt'"
                exit
            }
        }
        local statlist "`newstatlist'"
    }
    if ("`s(isbad)'"=="1") exit
    local statlist : list uniq statlist

    * column names for matrix
    foreach stat in `statlist' {
        if "`stat'"=="estimate" { // use option estimatenm
            local `stat' "estimate"
            local colnms "`colnms'`estimatenm' "
        }
        else {
                local `stat' "`stat'"
            local colnms "`colnms'`stat' "
        }
    }
    local colnms = trim("`colnms'")

    * if add, make sure column names match
    if "`add'"=="add" {
        if `matrixexists' == 1 {
            local priorcolnms : colnames `matrix'
        }
        if `matrixexists'==1 & "`colnms'"!="`priorcolnms'" {
            display as error ///
                "statistics in matrix `matrix' do not match those being added"
            exit
        }
    }

    * get ALL statistics to be saved
    foreach s in `statsall' {
        local colnmsall "`colnmsall'`s' "
        matrix `newmatall' = nullmat(`newmatall') , `s'
    }
    * list of selected statistics s084
    foreach s in `statlist' {
        matrix `newmat' = nullmat(`newmat') , `s'
    }

    matrix colname `newmat' = `colnms'
    matrix colname `newmatall' = `colnmsall'
    if  "`roweqnm'" != "" {
        matrix roweq `newmat' = `roweqnm'
        matrix roweq `newmatall' = `roweqnm'
    }

    if "`label'"!="" { // nolabel
        matrix rowname `newmat' = `"`label'"'
        matrix rowname `newmatall' = `"`label'"'
    }
    else { // label
        local n = 1
        if (`matrixexists'==1) local n = rowsof(`matrix') + 1
        matrix rowname `newmat' = "`n'"
        matrix rowname `newmatall' = "`n'"
    }
    if `matrixexists'==1 { // it has been deleted if add not specified
        matrix `matrix' = `matrix' \ `newmat'
        matrix `matrixall' = `matrixall' \ `newmatall'
    }
    else {
        matrix `matrix' = `newmat'
        matrix `matrixall' = `newmatall'
    }

    if "`notable'"=="" {
        matlist `matrix', format(%`width'.`decimals'f) title("`title'") ///
            `twopt'
    }

end

capture program drop _parse_stat
program define _parse_stat, sclass
    local isbad = 1
    local stat "`1'"
    local is = inlist("`stat'","e","es","est","esti","estim","estima")
    if `is'==1 {
        local stat "estimate"
        local isbad = 0
    }
    local is = inlist("`stat'","estimat","estimate","coef")
    if `is'==1 {
        local stat "estimate"
        local isbad = 0
    }
    local is = inlist("`stat'","s","se","stderr")
    if `is'==1 {
        local stat "se"
        local isbad = 0
    }
    local is = inlist("`stat'","p","pv","pva","pval","pvalu","pvalue")
    if `is'==1 {
        local stat "pvalue"
        local isbad = 0
    }
    local is = inlist("`stat'","z","zv","zva","zval","zvalu","zvalue")
    if `is'==1 {
        local stat "zvalue  "
        local isbad = 0
    }
    local is = inlist("`stat'","upper","ub","u","ul")
    if `is'==1 {
        local stat "ul"
        local isbad = 0
    }
    local is = inlist("`stat'","lower","lb","l","ll")
    if `is'==1 {
        local stat "ll"
        local isbad = 0
    }
    sreturn local stat "`stat'"
    sreturn local isbad "`isbad'"
end
exit
