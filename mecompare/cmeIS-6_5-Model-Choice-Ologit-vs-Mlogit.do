capture log close
log using cmeIS-6_5-Model-Choice-Ologit-vs-Mlogit, replace text

// CME: Comparing Marginal Effects Across Models
// Mize, Doan, and Long -- Sociological Methodology
// Model Selection: Ex 6.5 Ordinal logit and multinomial logit

version     14.2 
clear       all
set 		linesize 80

// NOTE_0: This entire do-file can take 5 or more minutes to run


****************************************************************        
//  #1 Data management
****************************************************************        

use gss_cme, clear

drop if year < 2010

*listwise deletion
drop if missing(partyid5, woman, edyrs, age, parent, married, faminc, ///
                employed, region4, year)
    
sum ibn.partyid5 woman edyrs age parent married faminc employed ///
    ibn.region4 ibn.year
    
	
****************************************************************        
//  #2 GSEM for Simultaneous Model Estimation 
****************************************************************        

*NOTE_1: vce(robust) is required for cross-model covariances when both
*        models use same observations; this replicates what the suest
*		 command in Stata does 

*NOTE_2: Duplicate copies of the dependent variable are needed for each
*        model being fit
   
clonevar    partyOLM = partyid5
lab var     partyOLM "partyid5 for ordinal model"
clonevar    partyMNL = partyid5
lab var     partyMNL "partyid5 for multinomial model"
 
gsem (partyOLM <- c.age##c.age i.woman c.edyrs i.parent i.married ///
                  i.race c.faminc i.employed i.region4 i.year, ologit) /// 
     (partyMNL <- c.age##c.age i.woman c.edyrs i.parent i.married ///
                  i.race c.faminc i.employed i.region4 i.year, mlogit), ///
     vce(robust)

est store gsemmodel


****************************************************************        
//  #3 Discrete changes for effect of age
****************************************************************        

*NOTE_3: to obtain a discrete change for a continuous IV, must make 
*        predictions at starting and ending values and calculate difference


//  discrete change for age 20 to 30 across models

margins, at(age=(20 30)) atmeans post
mlincom, clear  // starts an empty table to be filled with results
qui mlincom 2-1,            rowname("StrDem:OLM") stat(est se p) clear 
qui mlincom 12-11,          rowname("StrDem:MNL") stat(est se p) add   
qui mlincom (2-1)-(12-11),  rowname("StrDem:Difference") stat(est se p) add 
qui mlincom 4-3,            rowname("Dem:OLM") stat(est se p) add 
qui mlincom 14-13,          rowname("Dem:MNL") stat(est se p) add 
qui mlincom (4-3)-(14-13),  rowname("Dem:Difference") stat(est se p) add 
qui mlincom 6-5,            rowname("Indep:OLM") stat(est se p) add 
qui mlincom 16-15,          rowname("Indep:MNL") stat(est se p) add 
qui mlincom (6-5)-(16-15),  rowname("Indep:Difference") stat(est se p) add 
qui mlincom 8-7,            rowname("Repub:OLM") stat(est se p) add 
qui mlincom 18-17,          rowname("Repub:MNL") stat(est se p) add 
qui mlincom (8-7)-(18-17),  rowname("Repub:Difference") stat(est se p) add 
qui mlincom 10-9,           rowname("StrRep:OLM") stat(est se p) add 
qui mlincom 20-19,          rowname("StrRep:MNL") stat(est se p) add 
qui mlincom (10-9)-(20-19), rowname("StrRep:Difference") stat(est se p) add 

mlincom, stat(est se p) twidth(15) dec(3) ///
        title("DCR for age 20 to 30 Across OLM and MNL")

		
//  discrete change for age 60 to 70 across models    

est restore gsemmodel
margins, at(age=(60 70)) atmeans post    
mlincom, clear
qui mlincom 2-1,            rowname("StrDem:OLM") stat(est se p) clear 
qui mlincom 12-11,          rowname("StrDem:MNL") stat(est se p) add   
qui mlincom (2-1)-(12-11),  rowname("StrDem:Difference") stat(est se p) add 
qui mlincom 4-3,            rowname("Dem:OLM") stat(est se p) add 
qui mlincom 14-13,          rowname("Dem:MNL") stat(est se p) add 
qui mlincom (4-3)-(14-13),  rowname("Dem:Difference") stat(est se p) add 
qui mlincom 6-5,            rowname("Indep:OLM") stat(est se p) add 
qui mlincom 16-15,          rowname("Indep:MNL") stat(est se p) add 
qui mlincom (6-5)-(16-15),  rowname("Indep:Difference") stat(est se p) add 
qui mlincom 8-7,            rowname("Repub:OLM") stat(est se p) add 
qui mlincom 18-17,          rowname("Repub:MNL") stat(est se p) add 
qui mlincom (8-7)-(18-17),  rowname("Repub:Difference") stat(est se p) add 
qui mlincom 10-9,           rowname("StrRep:OLM") stat(est se p) add 
qui mlincom 20-19,          rowname("StrRep:MNL") stat(est se p) add 
qui mlincom (10-9)-(20-19), rowname("StrRep:Difference") stat(est se p) add 

mlincom, stat(est se p) dec(3) twidth(15) ///
        title("DCR for age 60 to 70 Across OLM and MNL")

		
		
****************************************************************        
// #4 Plots of predicted probabilities
****************************************************************        
*NOTE_4: Graphs in the paper use the cleanplots graphics scheme
*		available at: www.trentonmize.com/software/cleanplots

*NOTE_5A: Option predict(outcome( )) allows for predictions from a specific
*        model after gsem. Models are named based on dependent variable

*NOTE_5B: Within option predict(outcome( )) is where to specify which 
*		dependent variable category predictions are made by specifying the 
*		category #

//  ologit

est restore gsemmodel
qui margins, at(age=(20(5)80)) atmeans ///
    predict(outcome(partyOLM 0)) predict(outcome(partyOLM 1)) ///
    predict(outcome(partyOLM 2)) predict(outcome(partyOLM 3)) ///
    predict(outcome(partyOLM 4))

*basic plot
marginsplot
                 
*plot with nicer options & labels    
marginsplot, ///
    legend(order(1 "Strong Dem" 2 "Democrat" 3 "Independent" ///
                 4 "Republican" 5 "Strong Repub")) ///
    xtitle("Age in Years") ytitle("Pr(Party Affiliation)") ///
    title("Ordinal Logit") ///
    noci ylab(0(.1).4) xlab(20(10)80) 

*save graph	
graph export "cmeS-6_5-A-ologit.png", replace

	
//  mlogit

est restore gsemmodel
qui margins, at(age=(20(5)80)) atmeans ///
    predict(outcome(partyMNL 0)) predict(outcome(partyMNL 1)) ///
    predict(outcome(partyMNL 2)) predict(outcome(partyMNL 3)) ///
    predict(outcome(partyMNL 4))

marginsplot
                 
marginsplot, ///
    legend(order(1 "Strong Dem" 2 "Democrat" 3 "Independent" ///
                 4 "Republican" 5 "Strong Repub")) ///
    xtitle("Age in Years") ytitle("Pr(Party Affiliation)") ///
    title("Multinomial Logit") ///
    noci ylab(0(.1).4) xlab(20(10)80)
    
*save graph	
graph export "cmeS-6_5-B-mlogit.png", replace

	
	
log close
exit

