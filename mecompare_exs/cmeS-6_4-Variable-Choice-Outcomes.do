capture log close
log using cmeS-6_4-Variable-Choice-Outcomes, replace text

// CME: Comparing Marginal Effects Across Models
// Mize, Doan, and Long -- Sociological Methodology 2019
// Ex 6.4 - Variable choice: Comparing effects on different outcomes

version     14.2 
clear       all
set 		linesize 80


****************************************************************        
//  #1 Data management
****************************************************************        
use 	"https://tdmize.github.io/data/data/gss_cme", clear

*listwise deletion
drop if missing(mntlhlth, physhlth, woman, married, age, faminc, ///
                race, college, parent, reltrad)

codebook mntlhlth physhlth woman married age faminc ///
           race college parent reltrad, compact

		   
****************************************************************        
//  #2 Simultaneous Estimation with GSEM
****************************************************************        
 
*NOTE_1: vce(robust) is required for cross-model covariances when both
*        models use same observations; this replicates what the suest
*		 command in Stata does 

gsem (mntlhlth <- i.woman i.married c.age faminc ///
                  i.race i.college i.parent i.year, nbreg) ///
     (physhlth <- i.woman i.married c.age faminc ///
                  i.race i.college i.parent i.year, nbreg), ///
     vce(robust)
  
est store gsemmodel


****************************************************************        
//  #3a Compute and compare marginal effects for binary IVs
****************************************************************        

*NOTE_2: for binary IVs, dydx( ) option on margins will 
*        provide discrete change

est restore gsemmodel
margins, 	dydx(woman) post        
mlincom, 	clear    // starts an empty table to be filled with results
qui mlincom 1,   rowname("woman:Mental Health") stat(est se p) add
qui mlincom 2,   rowname("woman:Physical Health") stat(est se p) add
qui mlincom 1-2, rowname("woman:Difference") stat(est se p) add

est restore gsemmodel
margins, 	dydx(married) post        
qui mlincom 1,   rowname("married:Mental Health") stat(est se p) add
qui mlincom 2,   rowname("married:Physical Health") stat(est se p) add
qui mlincom 1-2, rowname("married:Difference") stat(est se p) add

est restore gsemmodel
margins, 	dydx(parent) post        
qui mlincom 1,   rowname("parent:Mental Health") stat(est se p) add
qui mlincom 2,   rowname("parent:Physical Health") stat(est se p) add
qui mlincom 1-2, rowname("parent:Difference") stat(est se p) add
   
est restore gsemmodel
margins, 	dydx(college) post        
qui mlincom 1,   rowname("college:Mental Health") stat(est se p) add
qui mlincom 2,   rowname("college:Physical Health") stat(est se p) add
qui mlincom 1-2, rowname("college:Difference") stat(est se p) add

mlincom, 	twidth(20) title("ADCs for binary IVs")



****************************************************************        
//  #3b Compute and compare marginal effects for continuous IVs
****************************************************************        
 
*NOTE_3: to obtain a discrete change for a continuous IV, must make 
*        predictions at starting and ending values and calculate difference

est 	restore gsemmodel
qui 	sum age
local 	sdage = r(sd) // store SD of income
margins, at(age=gen(age)) at(age=gen(age + `sdage')) post   
 
qui mlincom 2-1, rowname("age + SD:Mental Health") stat(est se p) add
qui mlincom 4-3, rowname("age + SD:Physical Health") stat(est se p) add
qui mlincom (2-1)-(4-3), rowname("age + SD:Difference") stat(est se p) add 

est 	restore gsemmodel
qui 	sum faminc
local 	sdinc = r(sd)
margins, at(faminc=gen(faminc)) at(faminc=gen(faminc + `sdinc')) post   
 
qui mlincom 2-1, rowname("faminc + SD:Mental Health") stat(est se p) add
qui mlincom 4-3, rowname("faminc + SD:Physical Health") stat(est se p) add
qui mlincom (2-1)-(4-3), rowname("faminc + SD:Difference") stat(est se p) add 

mlincom, 	twidth(20) title("ADCs for continuous IVs")


****************************************************************        
//  #3c Compare marginal effects for multi-category nominal IVs
****************************************************************        

*NOTE_4: make predictions for each racial category and then calculate 
*        differences between categories for average discrete change

est restore gsemmodel
margins 	i.race, post 

qui mlincom 2-1, rowname("black - white:Mental Health") stat(est se p) add
qui mlincom 5-4, rowname("black - white:Physical Health") stat(est se p) add
qui mlincom (2-1)-(5-4), rowname("black - white:Difference") stat(est se p) add

qui mlincom 3-1, rowname("other - white:Mental Health") stat(est se p) add
qui mlincom 6-4, rowname("other - white:Physical Health") stat(est se p) add
qui mlincom (3-1)-(6-4), rowname("other - white:Difference") stat(est se p) add

qui mlincom 3-2, rowname("other - black:Mental Health") stat(est se p) add
qui mlincom 6-5, rowname("other - black:Physical Health") stat(est se p) add
qui mlincom (3-2)-(6-5), rowname("other - black:Difference") stat(est se p) add

mlincom, 	twidth(20) title("ADCs for multi-category nominal IVs")    



log close
exit

