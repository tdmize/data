capture log close
log using cmeIS-6_1-Mediation-LRM-Curvillinear, replace text

// CME: Comparing Marginal Effects Across Models
// Mize, Doan, and Long -- Sociological Methodology
// Example 6.1: Mediation with curvilinear relationship

version     14.2 
clear       all
set 		linesize 80

****************************************************************
// #1: Data management and descriptive statistics
****************************************************************
use 	"https://tdmize.github.io/data/data/ah4_cme", clear

*listwise deletion 
drop if missing(depsympB, income, inc10, age, woman, race, ///
                college, jobsat)

sum depsympB income inc10 age woman ibn.race college ibn.jobsat


****************************************************************
// #2: Simultaneous model estimation with gsem
****************************************************************

*NOTE_1: vce(robust) is required for cross-model covariances when both
*        models use same observations; this replicates what the suest
*		 command in Stata does 

*NOTE_2: Duplicate copies of the dependent variable are needed for each
*        model being fit

clonevar depsympM1 = depsympB
lab var  depsympM1 "Depressive symptoms - M1 base model"
clonevar depsympM2 = depsympB
lab var  depsympM2 "Depressive symptoms - M2 add jobsat"

gsem (depsympM1 <- c.income##c.income c.age i.woman ///
                        i.race, regress) ///
     (depsympM2 <- c.income##c.income c.age i.woman ///
                        i.race i.jobsat, regress), vce(robust)

est store gsemmodel
             
			 
****************************************************************        
// #3: Marginal effects for income
****************************************************************

// Instantaneous change in income

*NOTE_3: the dydx() option on margins computes the effect for 
*        an instantaneous change for a continuous IV (income)

est restore gsemmodel
margins, dydx(income) post
qui mlincom 1, rowname("ME_income: Model 1") stat(est se p) clear
qui mlincom 2, rowname("ME_income: Model 2") stat(est se p) add
mlincom 2 - 1, rowname("ME_income: Difference") stat(est se p) add ///
    twidth(15) title("Cross model difference for marginal effect of income")

	
// Discrete change: +SD change in income //

*NOTE_4: to obtain a discrete change for a continuous IV, must make 
*        predictions at starting and ending values and calculate difference

est     restore gsemmodel
sum     income
local   sdinc = r(sd) // store SD of income
margins, at(income=gen(income)) at(income=gen(income + `sdinc')) post 

qui mlincom 2-1, rowname("DC_income: Model 1") stat(est se p) clear
qui mlincom 4-3, rowname("DC_income: Model 2") stat(est se p) add
mlincom (4-3)-(2-1), rowname("DC_income: Difference") stat(est se p) add ///
    twidth(15) ///
    title("Cross model difference for discrete change of +SD of income")

    
****************************************************************        
// #4: Graphs of predictions from both models
****************************************************************
*NOTE_5: Graphs in the paper use the cleanplots graphics scheme
*		available at: www.trentonmize.com/software/cleanplots

*NOTE_6: Option predict(outcome( )) allows for predictions from a specific
*        model after gsem. Models are named based on dependent variable

    
// Figure 1: left panel (base model) //    

est restore gsemmodel
margins, predict(outcome(depsympM1)) at(income=(0(5)150)) atmeans

*basic plot
marginsplot

*plot with advanced options, labels, titles
marginsplot, plotopts(msym(i)) title("Model 1: Base") ///
    recastci(rline) ciopts(lpat(dash) color(gs12)) ///
    xlab(0(25)150) xtitle("Income in $1,000s") ///
    ylab(2(1)8) ytitle("Depressive Symptoms") 
 
*save graph
graph export "cmeS-6_1-model_1.png", replace


 
// Figure 2: right panel (model with job satisfaction) //    
    
est restore gsemmodel
margins, predict(outcome(depsympM2)) at(income=(0(5)150)) atmeans

*basic plot
marginsplot

*plot with advanced options, labels, titles
marginsplot, plotopts(msym(i)) title("Model 2: With Job Satisfaction") ///
    recastci(rline) ciopts(lpat(dash) color(gs12)) ///
    xlab(0(25)150) xtitle("Income in $1,000s") ///
    ylab(2(1)8) ytitle("Depressive Symptoms") 

*save graph
graph export "cmeS-6_1-model_2.png", replace

	
log close
exit

