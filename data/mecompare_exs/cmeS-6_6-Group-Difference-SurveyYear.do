capture log close
log using cmeS-6_6-Group-Difference-SurveyYear, replace text

// CME: Comparing Marginal Effects Across Models
// Mize, Doan, and Long -- Sociological Methodology 2019
// Ex 6.6 - Group Differences: Comparing effects across surveys years

version     14.2 
clear       all
set 		linesize 80


****************************************************************        
//  #1 Data management
****************************************************************        
use 	"https://tdmize.github.io/data/data/gss_cme", clear

keep if year == 1986 | year == 2016

* Listwise deletion
drop if missing(helpsickB, polviews, faminc, employed, woman, age, ///
                college, married, parent)

codebook helpsickB polviews faminc employed woman age college ///
         married parent, compact

		 
****************************************************************        
//  #2 Simultaneous Estimation with GSEM 
****************************************************************        

*NOTE_1: Duplicate copies of the dependent variable are needed for each
*        model being fit

*NOTE_2A: vce(robust) is not needed for this application because the samples
*		across the two models do not overlap. gsem allows you not to use 
*		vce(robust)

*NOTE_2B: The suest command in Stata will use vce(robust)

*NOTE_3: Using cluster robust variance estimator (on region) just to 
*	demonstrate that cross-model covariances can often be non-zero even
*	when mutually exclusive observations used across models

clonevar helpsick86 = helpsickB
replace  helpsick86 = . if year != 1986
clonevar helpsick16 = helpsickB
replace  helpsick16 = . if year != 2016

gsem (helpsick86 <- i.conserv faminc i.employed i.woman age i.college ///
                    i.married i.parent i.race, logit) ///
     (helpsick16 <- i.conserv faminc i.employed i.woman age i.college ///
                    i.married i.parent i.race, logit), ///
					vce(cluster region)

est store gsemmodel


****************************************************************        
//  #4 Marginal Effects at the Mean (MEM)
****************************************************************        

*NOTE_4: The option over( ) specifies that only the sample-specific 
*		observations be used in the relevant calculations
*		(e.g. only 1986 obs used in calculation of 1986 pred. probs.)

//  #4a Averaged probabiltiies

est restore gsemmodel
margins, 	over(year) at(conserv=(0 1)) post  
      
qui mlincom 1,      rowname("PRatmean 1986: NotConserv") clear stat(est se p) 
qui mlincom 3,      rowname("PRatmean 1986: Conserv") add stat(est se p) 
qui mlincom 3 - 1,  rowname("PRatmean 1986: Difference") add stat(est se p) 
qui mlincom 6,      rowname("PRatmean 2016: NotConserv") add stat(est se p) 
qui mlincom 8,      rowname("PRatmean 2016: Conserv") add stat(est se p) 
qui mlincom 8 - 6,  rowname("PRatmean 2016: Difference") add stat(est se p) 
qui mlincom 6 - 1,  rowname("DiffYear: NotConserv") add stat(est se p) 
qui mlincom 8 - 3,  rowname("DiffYear: Conserv") add stat(est se p) 

mlincom,	title("Prob by Conservative by Survey Year") twidth(15)

		
//  #4b Average discrete changes

est restore gsemmodel
margins, 	over(year) dydx(conserv) post       
 
qui mlincom 1,      rowname("MEM: 1986") clear stat(est se p) 
qui mlincom 4,      rowname("MEM: 2016") add stat(est se p) 
qui mlincom 1 - 4,  rowname("MEM: Difference") add stat(est se p) 

mlincom,	title("MEM for Conservative by Survey Year")

		
log close
exit
