// A General Framework for Comparing Predictions & 
// Marginal Effects Across Models

// Trenton D. Mize, Long Doan, and J. Scott Long

* The datasets and do-files to recreate all examples in the article are 
* installed as part of the mecompare package available here:
* 	www.trentonmize.com/software/mecompare

* To recreate the examples shown in the article, run this do-file first
* in order to install the necessary user-written packages.


// Install Needed Packages //

ssc install fre, replace
ssc install coefplot, replace
net from "http://www.indiana.edu/~jslsoc/stata/"
net install spost13_ado, replace force
net install cleanplots, from("https://tdmize.github.io/data/cleanplots") ///
	replace force

// The following files are downloaded by the mecompare package	

// Example datasets //
* ah4_cme.dta
* gss_cme.dta

// Example do-files //

* cmeGS-4_1-Mediation-LRM-Curvillinear.do
* cmeGS-4_2-Mediation-Logit-Happy.do
* cmeGS-4_3-Variable-Choice-Predictors.do
* cmeGS-4_4-Variable-Choice-Outcomes.do
* cmeGS-4_5-Model-Choice-Ologit-vs-Mlogit.do
* cmeGS-4_6-Group-Difference-SurveyYear.do 



exit

NOTES:
