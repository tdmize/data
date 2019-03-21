capture log close
log using cme-6_3-Variable-Choice-Predictors, replace text

// CME: Comparing Marginal Effects Across Models
// Ex 6.3 - Variable choice: Comparing effets of alternative predictors

version     14.2 // allow non-15 users
clear       all
set more    off
set         linesize 80
set         scheme cleanplots
graph       set eps fontface Times
graph       set window fontface Times

local pgm "cme-6_3-Variable-Choice-Predictors"
local dte "2019-03-20"
local who "TDM JSL TDM JSL TDM" // add last person making change
local tag "`pgm'.do `who' `dte'"

//  ===============================================================
//  #1 Data management

use gss_cme, clear

//  drop all missing cases
drop if missing(samesexB, sexident, sexbehav, college, woman, race, age, year) 

tab samesexop samesexB, missing

//  Compare two sexual orientation measures    

tab sexident sexbehav, miss

//  ===============================================================
//  #2 Simultaneous Estimation with GSEM

//  Clone DV to allow gsem to estimate multiple models on same outcome

clonevar samesexBEHAV = samesexB
clonevar samesexIDENT = samesexB

gsem (samesexBEHAV <- i.sexbehav i.woman i.college c.age ///
                      i.race i.year, logit) ///
     (samesexIDENT <- i.sexident i.woman i.college c.age ///
                      i.race i.year, logit), ///
     vce(robust)
 
est store gsemmodel

//  ===============================================================
//  #3 Plot Pr(Wrong) by sexual orientation for both measures

est restore gsemmodel
margins, predict(outcome(samesexBEHAV)) at(sexbehav=(1 2 3)) post
est store prbehav

est restore gsemmodel
margins, predict(outcome(samesexIDENT)) at(sexident=(1 2 3)) post
est store prident

local labopt "labsize(*1.1)"

coefplot (prident, color(red*1.3)) (prbehav, color(eltblue*.9)), ///
    vertical recast(bar) barw(0.3) ///
    ciopts(recast(rcap) color(gs8)) citop ///
    legend(order(1 "Identity" 3 "Behavior")) ///
    xlab(1 "Heterosexual" 2 "Bisexual" 3 "Gay/Lesbian", noticks) ///
    ytitle("Pr(Same-Sex Relationships Wrong)", size(*.85)) ///
    ylab(0(0.1).6, `labopt') ///
    scale(1.4) /// larger text
    xscale(noline) plotregion(style(none)) // turn off x axis line

graph export "- Graphs/`pgm'.eps", replace
graph export "- Graphs/`pgm'.emf", replace

//  ===============================================================
//  #4 Probabilities and Marginal Effects by Predictor

//  #4a predicted probabilities and differences for each measure

est restore gsemmodel    
margins, at(sexident=(1 2 3)) at(sexbehav=(1 2 3)) post
qui {
mlincom 7,   rowname("Heterosexual: Identity") stat(est se p) clear 
mlincom 4,   rowname("Heterosexual: Behavior") stat(est se p) add
mlincom 4-7, rowname("Heterosexual: Difference") stat(est se p) add
mlincom 8,   rowname("Bisexual: Identity") stat(est se p) add
mlincom 5,   rowname("Bisexual: Behavior") stat(est se p) add
mlincom 5-8, rowname("Bisexual: Difference") stat(est se p) add
mlincom 9,   rowname("Gay/Lesbian: Identity") stat(est se p) add
mlincom 6,   rowname("Gay/Lesbian: Behavior") stat(est se p) add
mlincom 6-9, rowname("Gay/Lesbian: Difference") stat(est se p) add
}
mlincom, twidth(20) title("Differences in Probabilities Across Models")

//  #4b Pairwise comparison AMEs

est restore gsemmodel    
margins, dydx(sexident sexbehav) post        
qui {
mlincom -3,   rowname("Het - Bi: Identity") stat(est se p) clear
mlincom -1,   rowname("Het - Bi: Behavior") stat(est se p) add
mlincom 1-3, rowname("Het - Bi: Difference") stat(est se p) add
mlincom -4,   rowname("Het - Gay: Identity") stat(est se p) add
mlincom -2,   rowname("Het - Gay: Behavior") stat(est se p) add
mlincom 2-4, rowname("Het - Gay: Difference") stat(est se p) add
mlincom -(4-3), rowname("Bi - Gay: Identity") stat(est se p) add
mlincom -(2-1), rowname("Bi - Gay: Behavior") stat(est se p) add
mlincom (2-1)-(4-3), rowname("Bi - Gay: Difference") stat(est se p) add
}        
mlincom, twidth(20) ///
    title("AMEs for Sexual Orientation Within and Across Models")

log close
exit

