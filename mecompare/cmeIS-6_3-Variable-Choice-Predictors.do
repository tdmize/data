capture log close
log using cmeIS-6_3-Variable-Choice-Predictors, replace text

// CME: Comparing Marginal Effects Across Models
// Mize, Doan, and Long -- Sociological Methodology
// Variable choice: Ex 6.3 Comparing effets of alterantive predictors

version     14.2 
clear       all
set 		linesize 80


***********************************************************************
//  #1 Data management
***********************************************************************
use gss_cme, clear

*listwise deletion
drop if missing(samesexB, sexident, sexbehav, college, woman, race, age, year) 

*Compare two sexual orientation measures    
tab sexident sexbehav, miss


***********************************************************************
//  #2 Simultaneous Estimation with GSEM
***********************************************************************

*NOTE_1: vce(robust) is required for cross-model covariances when both
*        models use same observations; this replicates what the suest
*		 command in Stata does 

*NOTE_2: Duplicate copies of the dependent variable are needed for each
*        model being fit

clonevar samesexBEHAV = samesexB
clonevar samesexIDENT = samesexB

gsem (samesexBEHAV <- i.sexbehav i.woman i.college c.age ///
                      i.race i.year, logit) ///
     (samesexIDENT <- i.sexident i.woman i.college c.age ///
                      i.race i.year, logit), ///
     vce(robust)
 
est store gsemmodel


***********************************************************************
//  #3 Probabilities and Discrete Changes by Predictor
***********************************************************************

//  #3a Predicted probabilities and differences for each measure

*NOTE_3: important to make sure only use predictions for _at sexident (1, 2, 3)
*	for the model with samesexIDENT as dependent variable (2_predict).
*	And to match up sexbehav with samesexBEHAV

est restore gsemmodel    
margins, at(sexident=(1 2 3)) at(sexbehav=(1 2 3)) post
qui mlincom 7,   rowname("Heterosexual: Identity") stat(est se p) clear 
qui mlincom 4,   rowname("Heterosexual: Behavior") stat(est se p) add
qui mlincom 4-7, rowname("Heterosexual: Difference") stat(est se p) add
qui mlincom 8,   rowname("Bisexual: Identity") stat(est se p) add
qui mlincom 5,   rowname("Bisexual: Behavior") stat(est se p) add
qui mlincom 5-8, rowname("Bisexual: Difference") stat(est se p) add
qui mlincom 9,   rowname("Gay/Lesbian: Identity") stat(est se p) add
qui mlincom 6,   rowname("Gay/Lesbian: Behavior") stat(est se p) add
qui mlincom 6-9, rowname("Gay/Lesbian: Difference") stat(est se p) add

mlincom, twidth(20) title("Differences in Probabilities Across Models")


//  #3b Pairwise comparison of average discrete changes (ADCs)

*NOTE_4: for nominal and binary IVs, dydx( ) option on margins will
*        provide discrete change

est restore gsemmodel    
margins, dydx(sexident sexbehav) post        
qui mlincom -3,     rowname("Het - Bi: Identity") stat(est se p) clear
qui mlincom -1,     rowname("Het - Bi: Behavior") stat(est se p) add
qui mlincom 1-3,    rowname("Het - Bi: Difference") stat(est se p) add
qui mlincom -4,     rowname("Het - Gay: Identity") stat(est se p) add
qui mlincom -2,     rowname("Het - Gay: Behavior") stat(est se p) add
qui mlincom 2-4,    rowname("Het - Gay: Difference") stat(est se p) add
qui mlincom -(4-3), rowname("Bi - Gay: Identity") stat(est se p) add
qui mlincom -(2-1), rowname("Bi - Gay: Behavior") stat(est se p) add
qui mlincom (2-1)-(4-3), rowname("Bi - Gay: Difference") stat(est se p) add
        
mlincom, twidth(20) ///
    title("ADCs for Sexual Orientation Within and Across Models")
    
	
	
***********************************************************************
//  #4 Plot Pr(Wrong) by sexual orientation for both measures
***********************************************************************
*NOTE_5: Graphs in the paper use the cleanplots graphics scheme
*		available at: www.trentonmize.com/software/cleanplots

*NOTE_6: Option predict(outcome( )) allows for predictions from a specific
*        model after gsem. Models are named based on dependent variable

est restore gsemmodel
margins, predict(outcome(samesexBEHAV)) at(sexbehav=(1 2 3)) post
est store prbehav

est restore gsemmodel
margins, predict(outcome(samesexIDENT)) at(sexident=(1 2 3)) post
est store prident

*basic plot
coefplot (prident) (prbehav), vertical recast(bar) barw(0.3)

*plot with nicer options and labels
coefplot (prident) (prbehav), ///
    vertical recast(bar) barw(0.3) ///
    ciopts(recast(rcap) color(gs8)) citop ylab(0(.1).6) ///
    xlab(1 "Heterosexual" 2 "Bisexual" 3 "Gay/Lesbian") ///
    ytitle("Pr(Same-Sex Relationships Wrong)") ///
    legend(order(1 "Identity" 3 "Behavior"))

*save graph	
graph export "cmeS-6_3-pr_prob.png", replace
	
	
	
log close
exit

NOTES:
    