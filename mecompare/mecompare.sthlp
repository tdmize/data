{smcl}
{* 2018-10-06 Trenton D Mize}{...}
{title:Title}

{p2colset 5 16 16 1}{...}
{p2col:{cmdab:mecomp:are} {hline 2}}{cmdab:mecomp:are} 
({bf:M}arginal {bf:E}ffects {bf:Compar[e]}ison) calculates marginal effects 
from one or two models. When two models are specified, {cmdab:mecomp:are}
uses seemingly unrelated estimation to combine the model estimates, 
enabing tests of the equality of marginal effects across models.{p_end}
{p2colreset}{...}

{title:General syntax}

{p 4 18 2}
{cmdab:mecomp:are} {varlist} {ifin} {weight} {cmd:,}
{opt mod:els( )} [options]
{p_end}

{marker overview}
{title:Overview}

{pstd}
{cmdab:mecomp:are} calculates marginal effects from one or two saved models. 
When two models are specified, {cmdab:mecomp:are} combines the model estimates 
using seemingly unrelated estimation and then calculates marginal effects 
for each model, as well as the cross-model comparisons of the marginal effects.

{pstd}
Factor syntax is required for the {it:varlist}: binary and nominal variables 
must be entered into the variable list with the i. prefix. Variables without 
any prefix are assumed to be continuous. The stored model estimates passed to 
{cmdab:mecomp:are} must have also used the same factor syntax as indicated in 
the {cmdab:mecomp:are} {it:varlist}. See {help fvvarlist} for details on 
factor syntax. If you do not specify a variable list, marginal effects are 
calculated for all variables across the model(s).

{pstd}
For a nominal independent variable, to specify a reference category other 
than the default first category you must use the ib#. syntax on both the 
stored models passed to {cmdab:mecomp:are} and in the {cmdab:mecomp:are} 
varlist. See {help fvvarlist##bases} for details on specifying base levels 
with factor syntax.

{pstd}
{cmdab:mecomp:are} supports the following estimation commands: regress, logit, 
probit, mlogit, ologit, poisson, nbreg.

{pstd}
For non-standard tests of the marginal effects, {help melincom} can be 
used to compute other linear combinations of the marginal effects calculated 
after a {cmdab:mecomp:are} command has been run.

{title:Table of contents}

	{help mecompare##required:Required option to specify models}
	{help mecompare##group:Required option if fitting models over groups}
	{help mecompare##stats:Which statistics to include in table}
	{help mecompare##amount:Amount of change to compute for continuous variables}
	{help mecompare##start:Setting starting values of variables in varlist}
	{help mecompare##covariates:Setting values of covariates}	
	{help mecompare##options:Optional options for formatting, reporting, missing data, etc.}
	{help mecompare##model_combos:Model combinations that can be compared}
	{help mecompare##matrices:Saved estimates and matrices}
	{help mecompare##examples:Examples}
	
{title:Options}

{marker required}
{dlgtab:Required Option}

{p2colset 5 18 19 0}
{synopt:{opt mod:els(list)}} is required with a list of stored model estimates 
to use. {cmdab:mecomp:are} is limited to one 
or two models. The model(s) must have been estimated and saved using 
{help estimates store} before running {cmd:mecompare}. 
{p_end}

{marker group}
{dlgtab:Group options}

{p2colset 5 18 19 0}
{synopt:{opt group(groupvar)}} specifies that models be fit separately over  
groups of {it: groupvar}. The grouping variable can contain more than two 
groups, but only two groups can be compared at a time with {cmdab:mecomp:are}. 
When the {opt group( )} option is specified, the models specified in the 
{opt models( )} option must have been fit separately across groups using an 
{cmd:if} statement. {cmdab:mecomp:are} uses the {cmd:if} statement to determine 
which groups to calculate marginal effects over. E.g. The following would 
compare marginal effects for models fit separately for racial category #1 and #3:

{pstd}logit employed age i.college if race == 1 {p_end}
{pstd}est store white_mod {p_end}

{pstd}logit employed age i.college if race == 3 {p_end}
{pstd}est store black_mod {p_end}

{pstd}mecompare age i.college, models(white_mod black_mod) group(race) {p_end}

{marker stats}
{dlgtab:Statistics to include in the table}
{p2colset 8 25 25 0}
{synopt:{opt stat:istics(list)}}selects statistics to display. The default 
is to include the estimate, se, and pvalue. The following statistics can be 
included in {it:list}.
{p_end}

{p2colset 10 23 22 12}{...}
{p2col :Name}Description{p_end}
{p2line}
{p2col :{ul:{bf:est}}{bf:imate}}Estimate of the marginal effect{p_end}
{p2col :{ul:{bf:se}}}Standard error of estimate{p_end}
{p2col :{ul:{bf:p}}{bf:value}}p-value for test that estimate = 0{p_end}
{p2col :{ul:{bf:ll}}}Lower level bound of confidence interval{p_end}
{p2col :{ul:{bf:ul}}}Upper level bound of confidence interval{p_end}
{p2col :{bf:z}}Value of z-statistic{p_end}
{p2col :{bf:all}}Display all statistics{p_end}

{p2line}

{marker amount}
{dlgtab:Amount of change and related options for continuous independent variables}
{p2colset 8 25 25 0}
{synopt:{opt amount(list)}}specifies the amount of change to be computed for 
the continuous independent variables. If only one value is specified in 
{opt amount( )}, this amount of change is applied to all of the continuous 
independent variables. To specify different amounts for each continuous 
independent variable, amounts in {it: list} are applied in the order of the 
continuous independent variables. E.g. In a {it:varlist} of 
{it: age i.woman income i.race polviews} there are three continuous 
variables, of which changes of (1) age + sd, (2) income + 5, and (3) polviews 
+ one can be specified with {opt amount(sd 5 one)}
{p_end}

{p2colset 10 23 22 12}{...}
{p2col :Name}Description{p_end}
{p2line}
{p2col :{ul:{bf:one}}}A one unit change; the default{p_end}
{p2col :{ul:{bf:sd}}}A standard deviation change{p_end}
{p2col :{ul:{bf:#}}}A change of {it: #}, which can be any amount. E.g. A 
10 unit increase can be specified with {opt amount(10)}{p_end}

{p2line}

{synopt:{opt center:ed}}By default, changes for continuous independent variables 
are for an increase of these amounts from the value of the independent variable. 
That is, they are {bf:uncentered} changes. Centered changes are computed by 
calculating changes from half the value below to half the value above;
e.g., [mean - SD/2] to [mean + SD/2].
{p_end}

{marker start}
{dlgtab:Setting starting values of variables in varlist}
{p2colset 8 25 25 0}
{synopt:{opt start(list)}}By default, the observed values of the focal independent 
variables specified in the {it:varlist} are used as the starting points for 
calculating the marginal effects (i.e. the margins default of {it:asobserved} is 
used; see {help margins}). The means of the focal independent variables 
can instead be used by specifying {opt start(atmeans)}. Other starting values 
can be specified within the {opt start( )} option, e.g. start(age=20). Multiple 
focal independent variables can be listed in {opt start( )}, 
e.g. start(age=20 income=100)
{p_end}

{marker covariates}
{dlgtab:Setting values of covariates}
{p2colset 8 25 25 0}
{synopt:{opt cov:ariates(list)}}Covariates are other independent variables in 
the model other than the focal independent variable the marginal effect is 
calculated for. By default, covariates are held at their observed values (i.e. 
the margins default of {it:asobserved} is used; see {help margins}). The 
covariates can instead be held at their sample means by specifying 
{opt covariates(atmeans)}. Other covariate values can be specified within the 
{opt covariates( )} option, e.g. {opt covariates(woman=1)} would calculate all 
marginal effects holding the value of woman at 1. Multiple covariates 
can be listed in {opt covariates( )}, e.g. covariates(woman=1 polviews=5). Only 
one value of each covariate may be specified.
{p_end}

{marker options}
{dlgtab:Additional Optional Options}

{p2colset 5 18 19 0}
{synopt:{opt dec:imals(#)}} changes the number of decimal places reported 
in the table. The default is 3. Any integer between 0 - 7 is allowed.
{p_end}

{p2colset 5 18 19 0}
{synopt:{opt mod1:name(string)}} names the rows in the table corresponding to 
the marginal effects for model 1. The default is to name the rows based on the 
name of the first stored estimates specified in the {opt models( )} option or 
based on the first group when the {opt groups( )} option is used. Note that 
names over 10 characters will be truncated in the output.
{p_end}

{p2colset 5 18 19 0}
{synopt:{opt mod2:name(string)}} names the rows in the table corresponding to 
the marginal effects for model 2. The default is to name the rows based on the 
name of the second stored estimates specified in the {opt models( )} option or 
based on the second group when the {opt groups( )} option is used. Note 
that names over 10 characters will be truncated in the output.
{p_end}

{p2colset 5 18 19 0}
{synopt:{opt labw:idth(#)}} changes the width of the leftmost column of the 
table that provides the labels for the variables and associated marginal 
effects. The default is 32. Any integer between 20 - 32 is allowed.
{p_end}

{p2colset 5 18 19 0}
{synopt:{opt statw:idth(#)}} changes the width of the columns of the 
table that report the statistics (e.g. estimate, SE, pvalue, etc.). The 
default is 9. Any integer between 9 - 20 is allowed.
{p_end}

{p2colset 5 18 19 0}
{synopt:{opt norow:num}} removes the column from the table with a number 
designation for each estimate in the table. 
{p_end}

{p2colset 5 18 19 0}
{synopt:{opt command:s}} displays the commands used for the {cmd:margins} 
estimates and (if two models are specified) for the {cmd:gsem} estimates. When 
the same dependent variable is used across models, a tempvar which is a clone 
of the dependent variable is used for the second model.
{p_end}

{p2colset 5 18 19 0}
{synopt:{opt detail:s}} displays the output of the {cmd:margins} estimates and 
(if two models are specified) the {cmd:gsem} estimates.
{p_end}

{marker model_combos}
{dlgtab:Models that can be compared}

{pstd} {cmdab:mecomp:are} is usually used when the same estimation command was 
used across both saved models (e.g. two binary logits). However, 
{cmdab:mecomp:are} can also compare select other model combinations listed below. 
{p_end}


{p2colset 10 23 22 12}{...}
{p2col :Models}Predictions that can be compared{p_end}
{p2line}
{p2col :{bf:logit vs probit}}Predicted probabilities{p_end}
{p2col :{bf:logit vs regress}}The predicted probabilities from logit and 
	the xb predictions from regress{p_end}
{p2col :{bf:probit vs regress}}The predicted probabilities from probit and 
	the xb predictions from regress{p_end}
{p2col :{bf:poisson vs nbreg}}The predicted number of events{p_end}	
{p2col :{bf:mlogit vs ologit}}The predicted probabilities{p_end}	
{p2line}

{marker matrices}
{dlgtab:Saved estimates and matrices}

{pstd} {cmdab:mecomp:are} uses {cmd:gsem} and {cmd:margins} to estimate the 
models and to calculate the marginal effects. These results are stored and 
can be restored after {cmdab:mecomp:are} has been run. 
See {help estimates restore} to learn about restoring saved results. 
The {cmd:gsem} model results are stored as {it:mec_gsem}. The {cmd:margins} 
results which contain the predictions that are the constituent pieces of the 
marginal effects {cmdab:mecomp:are} calculates are stored as {it:mec_margins}; 
those results will be more or less inscrutable to most users.
{p_end}

{pstd} {cmdab:mecomp:are} saves the current table to the matrix {opt _mecompare}. 
The matrix has columns corresponding to the displayed results. Rows that 
only contain labels (no statistics) have values of {bf:.z}
{p_end}


{marker examples}
{title:Examples}

{phang} {stata sysuse nlsw88: sysuse nlsw88}

{phang} {stata logit union i.married age i.race hours i.collgrad, vce(robust): logit union i.married age i.race hours i.collgrad, vce(robust)} {p_end}

{phang}	{stata est store basemod: est store basemod} {p_end}

{phang} {stata logit union i.married age i.race hours i.collgrad wage, vce(robust): logit union i.married age i.race hours i.collgrad wage, vce(robust)} {p_end}

{phang}	{stata est store medmod: est store medmod} {p_end}

{phang} {stata mecompare age i.collgrad i.race hours, models(basemod medmod): mecompare age i.collgrad i.race hours, models(basemod medmod)} {p_end}

{phang} {stata mecompare age i.collgrad i.race hours, models(basemod medmod) amount(sd): mecompare age i.collgrad i.race hours, models(basemod medmod) amount(sd)} {p_end}

{phang} {stata mecompare age i.collgrad i.race hours, models(basemod medmod) amount(sd 10): mecompare age i.collgrad i.race hours, models(basemod medmod) amount(sd 10)} {p_end}

{phang} {stata mecompare age i.collgrad i.race hours, models(basemod medmod) mod1name(Base Model) mod2name(Mediation Model): mecompare age i.collgrad i.race hours, models(basemod medmod) mod1name(Base Model) mod2name(Mediation Model)} {p_end}
	

{title:Comments}

{pstd} {cmdab:mecomp:are} implements the methods described in Mize, Doan, 
and Long's 2019 article "A General Framework for Comparing Predictions and Marginal 
Effects Across Models".

{pstd} {cmdab:mecomp:are} uses seemingly unrelated estimation to combine the 
model estimates. See {help suest} and Weesie (1999) for details on the method.

{pstd} Many of the features of {cmdab:mecomp:are} intentionally mimic and 
borrow from Long and Freese's (2014) SPost13 command {help mchange}. 
{p_end}

{title:Authorship}

{pstd} {cmd:mecompare} and {cmd:melincom} are written by Trenton D Mize 
(Departments of Sociology & Statistics [by courtesy], Purdue University). 
Questions can be sent to tmize@purdue.edu {p_end}

{title:References}

{pstd} Mize, Trenton D., Long Doan, and J. Scott Long. "A General Framework 
for Comparing Predictions and Marginal Effects Across Models." {p_end}

{pstd} Weesie, Jeroen. 1999. sg121: Seemingly Unrelated Estimation and the 
Cluster-Adjusted Sandwich Estimator. {it:Stata Technical Bulletin}. 52:34-47.

{pstd} Long, J. Scott and Jeremy Freese. 2014. 
{it:Regression Models for Categorical Dependent Variables Using Stata.} 
Third Edition. Stata Press.
{p_end}
