capture log close
log using cmeS-6_2-Mediation-Logit-Happy, replace text

//  CME: Comparing Marginal Effects Across Models
//  Mize, Doan, and Long -- Sociological Methodology 2019
//  Ex 6.2 - Mediation: binary logit, DV: being happy

version     14.2 
clear       all
set 		linesize 80


***********************************************************************
//  #1 Data management
***********************************************************************
use 	"https://tdmize.github.io/data/data/gss_cme", clear

drop if year < 2000
drop if employed != 1

* Listwise deletion
drop if missing(vhappy, college, wages, occprest, age, married, ///
                parent, woman, conserv, reltrad)

sum i.vhappy wages occprest i.married i.parent i.woman ///
    i.conserv i.reltrad i.year c.age##c.age i.married 

	
***********************************************************************
//  #2 -Simultaneous estimation with GSEM
***********************************************************************

*NOTE_1: vce(robust) is required for cross-model covariances when both
*        models use same observations; this replicates what the suest
*		 command in Stata does 

*NOTE_2: Duplicate copies of the dependent variable are needed for each
*        model being fit

clonevar    vhappyM1 = vhappy
lab var     vhappyM1 "M1 vhapppy college only"
clonevar    vhappyM2 = vhappy
lab var     vhappyM2 "M2 vhapppy college + controls"
clonevar    vhappyM3 = vhappy
lab var     vhappyM3 "M3 vhapppy college + controls + wages"
clonevar    vhappyM4 = vhappy
lab var     vhappyM4 "M4 vhapppy college + controls + wages + occprest"

codebook vhappy*, compact

gsem (vhappyM1 <- i.college, logit) ///
     (vhappyM2 <- i.college i.married i.parent ///
            i.woman i.conserv i.reltrad i.year c.age##c.age, logit) ///
     (vhappyM3 <- i.college c.wages i.married i.parent ///
            i.woman i.conserv i.reltrad i.year c.age##c.age, logit) ///
     (vhappyM4 <- i.college c.wages c.occprest i.married i.parent ///
            i.woman i.conserv i.reltrad i.year c.age##c.age, logit) ///
     , vce(robust)

est store gsemmodel



***********************************************************************
//  #3 Average discrete changes for effect of college
***********************************************************************

*NOTE_3: for nominal and binary IVs, dydx( ) option on margins 
*        computes discrete change

margins, dydx(college) post  

*Build table of ADCs and differences across models
qui mlincom 1,   rowname(ADC college: Model 1) stat(est se p) clear
qui mlincom 2,   rowname(ADC college: Model 2) stat(est se p) add
qui mlincom 3,   rowname(ADC college: Model 3) stat(est se p) add
qui mlincom 4,   rowname(ADC college: Model 4) stat(est se p) add
qui mlincom 1-2, rowname(Diff in ADCs: M1 - M2) stat(est se p) add
qui mlincom 2-3, rowname(Diff in ADCs: M2 - M3) stat(est se p) add
qui mlincom 3-4, rowname(Diff in ADCs: M3 - M4) stat(est se p) add twidth(15)

mlincom, title("ADCs for college and cross-model differences")



log close
exit
