// A General Framework for Comparing Predictions & 
// Marginal Effects Across Models -- Sociological Methodology

// Trenton D. Mize, Long Doan, and J. Scott Long


* The do-files to recreate all examples in the article are 
* installed as part of the mecompare package available here:
* 	www.trentonmize.com/software/mecompare

* To recreate the examples shown in the article, run this do-file first
* in order to install the necessary user-written packages.


// Install Needed Packages //

ssc install fre, replace
ssc install coefplot, replace
net install spost13_ado, ///
	from("http://www.indiana.edu/~jslsoc/stata/") replace force
net install cleanplots, from("https://tdmize.github.io/data/cleanplots") ///
	replace force

// Two datasets are used for the example: ah4_cme gss_cme
*	These are sourced in via url in the example do-files. Alternatively, 
*	you can download them here: https://tdmize.github.io/data/data


// The following example do-files are downloaded by the mecompare package	

* cmeIS-6_1-Mediation-LRM-Curvillinear.do
* cmeIS-6_2-Mediation-Logit-Happy.do
* cmeIS-6_3-Variable-Choice-Predictors.do
* cmeIS-6_4-Variable-Choice-Outcomes.do
* cmeIS-6_5-Model-Choice-Ologit-vs-Mlogit.do
* cmeIS-6_6-Group-Difference-SurveyYear.do 



exit

NOTES:
