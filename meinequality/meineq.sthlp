{smcl}
{* 2025-01-13 Bing Han, Trenton D. Mize}{...}
{title:Title}

{p2colset 5 16 16 1}{...}
{p2col:{cmdab:meineq:uality} {hline 2}}{cmdab:ME Inequality} 
({bf:M}arginal {bf:E}ffects {bf:Inequality}) calculates marginal effects (ME) 
inequality statistics for nominal independent variables by 
averaging the absolute values of all marginal effects for the nominal 
independent variable, which represent all pairwise comparisons of predictions 
for the variable. The command supports estimation for one or two models. In the 
two model case, the equality of the meinequality statistics across models 
is automatically calculated. {cmdab:meineq:uality} can compute both weighted 
and unweighted ME Inequality statistics. {cmdab:meineq:uality} can be used with  
models for continuous, count, binary, ordinal, and nominal dependent variables.
{p_end}
{p2colreset}{...}

{title:General syntax}

{p 4 18 2}
{cmdab:meineq:uality} {varlist} {cmdab:,} [options]{p_end}

{marker overview}
{title:Overview}

{pstd}
{cmdab:meineq:uality} implements the {it:ME inequality} method of Mize and Han (2025) 
to compute inequality in marginal effects for a nominal 
independent variable by summarizing the absolute differences in marginal 
effects across all pairwise combinations of levels. The command can calculate 
ME Inequality within a single model or compare ME Inequality across two models 
using seemingly unrelated estimation (SUEST) to combine model estimates.
{p_end}

{pstd}
{cmdab:meineq:uality} supports the calculation of ME Inequality for one or 
more nominal independent variables simultaneously.
{p_end}

{pstd}
{cmdab:meineq:uality} supports both weighted and unweighted estimations. 
Weighted ME Inequality accounts for the relative frequency of each level 
of the nominal variable in the sample. Unweighted ME Inequality computes 
the average pairwise absolute difference without considering the relative frequencies.
{p_end}

{pstd}
{cmdab:meineq:uality} supports the following estimation commands: 
{cmdab:regress}, {cmdab:logit}, {cmdab:probit}, {cmdab:mlogit}, 
{cmdab:ologit}, {cmdab:oprobit}, {cmdab:poisson}, and {cmdab:nbreg}. 
The same estimation method must be used for both models when performing 
cross-model comparisons via the {bf:models( )} option.
{p_end}

{title:Table of contents}

	{help meinequality##weighted:Setting weighted/unweighted calculations}
	{help meinequality##covariates:Setting values of the covariates}
	{help meinequality##models:Required option for two model comparison}
	{help meinequality##groups:Required option if fitting models over two distinct samples}
	{help meinequality##sampleweights:Setting sample weights and multiple imputation estimates}
	{help meinequality##options:Optional options for formatting, reporting, missing data, etc.}
	{help meinequality##matrices:Saved estimates and matrices}
	{help meinequality##examples:Examples}
	
{title:Options}

{marker Weighted}
{dlgtab:Weighted options}

{p2colset 5 18 19 0}

{synopt:{opt wei:ghted}} is the default. A weighted {it:ME inequality} 
accounts for the relative frequency of each level of the nominal variable 
in the sample. The weight assigned to each pairwise comparison is the 
sum of the proportions of the two levels used in the comparison, with a 
correction for each group being used in multiple comparisons: 
w_ab = (prop_a + prob_b)/(L - 1). Here, prop_a and prop_b 
refer to the proportions of the sample in Levels A and B, respectively. 
The term L−1 serves as a correction for the fact that each group is 
represented in multiple contrasts, ensuring the total sums to 1. 
{p_end}

{synopt:{opt unw:eighted}} gives all groups equal weight in the calculation 
by ignoring the relative frequency of each level of the 
nominal variable in the sample. 
{p_end}

{synopt:{opt all}} reports both the {opt wei:ghted} and {opt unw:eighted} 
inequality measures.
{p_end}

{marker covariates}
{dlgtab:Setting values of covariates}
{p2colset 5 18 19 0}
{synopt:{opt atmeans}}By default, the observed values of the other variables 
in the model are used for calculating the marginal effects (i.e., the margins 
default of {it:asobserved} is used; see {help margins}). Alternatively, the 
covariates can be set to their sample means with the {opt atmeans} option.
{p_end}

{marker Models}
{dlgtab:Models Option}

{p2colset 5 18 19 0}

{synopt:{opt mod:els(list)}} is required to compare {it:ME inequalities} across two models. 
The models must have been estimated and saved using {help estimates store} 
before running {cmdab:meineq:uality}. {opt mod:els(list)} is optional 
for one model estimation; if no {opt mod:els(list)} option is included the default 
is to use the model estimates in memory. {cmdab:meineq:uality} is limited to one or two models. 
The {opt vce(robust)} option is strongly recommended when conducting two-model comparisons 
because SUEST is used to combine the model estimates which uses robust variance 
estimation.
{p_end}

{marker groups}
{dlgtab:Groups options}

{p2colset 5 18 19 0}
{synopt:{opt group:s}} specifies that the two models used for comparison 
are fit on distinct samples. When the {opt groups} option is specified, 
the models listed in the {opt models(list)} option must have been fit 
separately across distinct samples (e.g., distinct groups in data).

{marker sampleweights}
{dlgtab:Sample weights and multiple imputation estimation options}

{p2colset 5 18 19 0}  
{synopt:{opt mi and svy}} For single model application, the {command: mi} and 
{command: svy} prefixes are supported for ME Inequality calculations. 
Specify these options on your model itself, not with {cmdab:meineq:uality}.
When {command: mi} is specified, the user-written package {it: mimrgns} 
is used to estimate the marginal effects (users need to install {it: mimrgns} separately).

{p2colset 5 18 19 0}
{synopt:{opt [weight]}} specifies weights to use when two models are compared. 
Because {bf:gsem} is used for the estimation, the {bf:svy} prefix cannot be 
applied. The {opt models(list)} option must be specified when using 
{bf: [weight]}. {command: fweight}, {command: pweight}, and {command: iweight} 
are supported. 

{marker options}
{dlgtab:Additional Optional Options}

{p2colset 5 18 19 0}
{synopt:{opt dec:imals(#)}} changes the number of decimal places reported 
in the table. The default is 3. Any integer between 0 - 7 is allowed.
{p_end}

{p2colset 5 18 19 0}
{synopt:{opt ci}} adds the lower and upper bounds of the 95% confidence 
intervals (CIs) for all estimates. By default, confidence intervals are 
omitted from the table output.
{p_end}

{p2colset 5 18 19 0}
{synopt:{opt labw:idth(#)}} changes the width of the leftmost column of the 
table that provides the labels for the variables and associated marginal 
effects. The default is 24. Any integer between 20 - 32 is allowed.
{p_end}

{p2colset 5 18 19 0}
{synopt:{opt title(sting)}} changes title of the output table. 
The default is "ME Inequality Estimates".
{p_end}

{p2colset 5 18 19 0}
{synopt:{opt groupn:ames(string)}} specifies the row names in the table 
corresponding to the ME Inequality for Model 1 and Model 2. Two group names 
must be provided; there can be no spaces in each group name. 
The {opt groups} option is required when using 
{opt groupn:ames(string)}. By default, the rows are named based on the 
stored estimate names specified in the {opt models(list)} option. 
Note that names longer than 10 characters will be truncated in the output.
{p_end}

{p2colset 5 18 19 0}
{synopt:{opt command:s}} displays the commands used for the {cmdab:gsem} 
estimates when two models are specified. If the same dependent variable 
is used across models, a temporary variable, which is a clone of the 
dependent variable, is used for the second model. 
{p_end}

{p2colset 5 18 19 0}
{synopt:{opt detail:s}} displays the output of the {cmdab:margins} 
estimates which are used as the basis of the {it:ME inequality} calculations.
{p_end}

{marker matrices}
{dlgtab:Saved estimates and matrices}

{pstd} {cmdab:meineq:uality} uses {cmdab:margins} to estimate the predictions 
for the {it:ME inequality} estimate and {cmdab:gsem} in the two-model case to 
combine model estimates. These results are stored and 
can be restored after {cmdab:meineq:uality} (via {help estimates restore}).
The {cmdab:margins} results which contain the predictions that are the constituent pieces of the 
marginal effects {cmdab:meineq:uality} calculates are stored as {it:meineq_margins}.
The {cmdab:gsem} model results are stored as {it:meineq_gsem}. 
{p_end}

{pstd} {cmdab:meineq:uality} saves the current table to the matrix {opt _meinequality}. 
The matrix has columns corresponding to the displayed results.
{p_end}


{marker examples}
{title:Examples}

{phang} {stata sysuse 			nlsw88, clear} {p_end}

*Single model
{phang} {stata reg 				wage i.race c.age i.married} {p_end}

{phang} {stata meinequality 	race} {p_end}
{phang} {stata meinequality 	race, unweighted} {p_end}

*Compare across two models on same sample
{phang} {stata logit 			union i.race, vce(robust)} {p_end}
{phang} {stata est store 		basemod} {p_end}
{phang} {stata logit 			union i.race c.age i.married, vce(robust)} {p_end}
{phang} {stata est store 		medmod} {p_end}

{phang} {stata meinequality 	race, models(basemod medmod)} {p_end}

*Compare across distinct samples/groups for two models
{phang} {stata logit 			union i.race c.age if married == 0, vce(robust)} {p_end}
{phang} {stata est store 		notmar} {p_end}
{phang} {stata logit 			union i.race c.age if married == 1, vce(robust)} {p_end}
{phang} {stata est store 		marry} {p_end}

{phang} {stata meinequality 	race, models(notmar marry) group} {p_end}	

*Nominal or ordinal outcome models
{phang} {stata mlogit 			industry i.race c.age} {p_end}

{phang} {stata meinequality 	race} {p_end}
	
	
{title:Comments}

{pstd} {cmdab:meineq:uality} implements the methods described in Mize and Han's 
2025 article "Inequality and Total Effect Summary Measures for Nominal and Ordinal Variables".

{pstd} {cmdab:meineq:uality} uses seemingly unrelated estimation to combine the 
model estimates in the two model case. See {help suest} and Weesie (1999) 
for details on the method.
{p_end}

{title:Authorship}

{pstd} {cmdab:meineq:uality} and its sister command, {cmdab:totalme}, are written by Bing Han 
(Department of Sociology, Purdue University) and Trenton D Mize 
(Departments of Sociology & Statistics and The Methodology Center at Purdue University). 
Questions can be sent to han644@purdue.edu or tmize@purdue.edu. {p_end}

{title:References}

{pstd} Mize, Trenton D. and Bing Han. 2025. Inequality and total effect 
summary measures for nominal and ordinal variables. {it:Sociological Science}. {p_end}

{pstd} Weesie, Jeroen. 1999. sg121: Seemingly Unrelated Estimation and the 
Cluster-Adjusted Sandwich Estimator. {it:Stata Technical Bulletin}. 52:34-47.
{p_end}
