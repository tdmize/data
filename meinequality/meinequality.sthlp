{smcl}
{* 2026-09-02 Bing Han, Trenton D. Mize -- matches meinequality v1.8.8}{...}
{title:Title}

{p2colset 5 16 16 1}{...}
{p2col:{cmdab:meineq:uality} {hline 2}}{cmdab:ME Inequality} 
({bf:M}arginal {bf:E}ffects {bf:Inequality}) calculates marginal effects (ME) 
inequality statistics for independent variables specified as nominal/factors by 
averaging the absolute values of all marginal effects for the nominal 
independent variable, which represent all pairwise comparisons of predictions 
for the variable. The command supports estimation for one or two models. In the 
two model case, the inequality of the meinequality statistics across models 
is automatically calculated. {cmdab:meineq:uality} can compute both weighted 
and unweighted ME Inequality statistics. {cmdab:meineq:uality} can be used 
after most regression models.
{p_end}
{p2colreset}{...}

{title:General syntax}

{p 4 18 2}
{cmdab:meineq:uality} {varlist} {ifin} {cmdab:,} [options]{p_end}

{marker overview}
{title:Overview}

{pstd}
{cmdab:meineq:uality} implements the {it:ME inequality} method of Mize and 
Han (2025) to compute a marginal effects inequality statistics for an 
independent variable specified as nominal/factor by summarizing the absolute 
differences in predictions across all pairwise combinations of levels of the 
independent variable. The command can calculate ME Inequality within a 
single model or compare ME Inequality across two models using seemingly 
unrelated estimation (SUEST) to combine model estimates via the {help suest2} 
command.
{p_end}

{pstd}
{cmdab:meineq:uality} supports the calculation of ME Inequality for one or 
more nominal and/or binary independent variables simultaneously.
{p_end}

{pstd}
{cmdab:meineq:uality} supports both weighted and unweighted estimations. 
Weighted ME Inequality accounts for the relative frequency of each level 
of the nominal variable in the sample. Unweighted ME Inequality computes 
the average pairwise absolute difference without considering the relative frequencies.
{p_end}

{pstd}
{cmdab:meineq:uality} accepts one or two models from every estimation
command the suite supports; see
{help meinequality##estimators:Supported estimators} below for the list and
for the rules that apply when two models are compared.
{p_end}

{title:Table of contents}

	{help meinequality##estimators:Which models and estimators are supported}
	{help meinequality##Weighted:Setting weighted/unweighted calculations}
	{help meinequality##covariates:Setting values of the covariates}
	{help meinequality##Models:Required option for two model comparison}
	{help meinequality##groups:Required option if fitting models over two distinct samples}
	{help meinequality##by/over:Estimations for subpopulations}
	{help meinequality##sampleweights:Setting sample weights and multiple imputation estimates}	
	{help meinequality##options:Optional options for formatting, reporting, missing data, etc.}
	{help meinequality##matrices:Saved estimates and matrices}
	{help meinequality##bootstrap:Bootstrap standard errors}
	{help meinequality##examples:Examples}
	
{marker estimators}{...}
{title:Supported estimators}

{pstd}
{cmdab:meineq:uality} accepts one or two models from the following
families. When two are given they must be the same estimation command; see
{help meinequality##pairs:Pairing two models} below.

{dlgtab:Ordinary single-level models}

{p 8 12 2}
{cmd:regress}; {cmd:logit} and {cmd:logistic}; {cmd:probit}; {cmd:poisson};
{cmd:nbreg}; {cmd:ologit}; {cmd:oprobit}; and {cmd:mlogit}.

{p 8 12 2}
{cmd:glm}; {cmd:cloglog}; {cmd:tobit}; {cmd:intreg}; maximum-likelihood
{cmd:heckman}; and parametric {cmd:streg}, all parametric distributions.

{p 8 12 2}
{cmd:gologit2}, all forms.

{p 8 12 2}
{cmd:ivregress 2sls}.

{p 8 12 2}
{cmd:fracreg} with estimators: logit, probit.

{p 8 12 2}
{cmd:betareg}, all four links; {cmd:truncreg}; {cmd:hetprobit};
{cmd:zip} and {cmd:zinb}, both inflation links; and {cmd:biprobit}.

{p 8 12 2}
{cmd:ivprobit} and {cmd:ivtobit}.

{dlgtab:Panel models}

{p 8 12 2}
{cmd:xtreg} with estimators: mle, fe, be, re, pa. {cmd:xtreg, cre} is not
supported.

{p 8 12 2}
{cmd:xtlogit} with estimators: re, fe, pa. {cmd:xtprobit} with estimators:
re, pa. {cmd:xtcloglog} with estimators: re, pa; the re estimator combines
when fit with {opt intpoints(24)} (or >24).

{p 8 12 2}
{cmd:xtologit} and {cmd:xtoprobit}.

{p 8 12 2}
{cmd:xtmlogit} with estimators: re, fe.

{p 8 12 2}
{cmd:xtpoisson} with estimators: re (normal or gamma random effects), fe,
pa. {cmd:xtnbreg} with estimators: re, pa. {cmd:xtnbreg, fe} is not
supported: Stata exposes no {cmd:predict, scores} for it in any form.

{dlgtab:Multilevel models}

{p 8 12 2}
{cmd:mixed, mle}; {cmd:melogit}; {cmd:meprobit}; {cmd:mecloglog};
{cmd:mepoisson}; {cmd:menbreg}; {cmd:meologit}; {cmd:meoprobit}; and
{cmd:mestreg}, all parametric distributions.

{p 8 12 2}
Supported {cmd:meglm} family-link pairs are Gaussian-identity and Gamma-log.

{marker pairs}{...}
{dlgtab:Pairing two models}

{pstd}
Both models must be the {bf:same} estimation command. A pair of two
different commands is refused, naming both. ({helpb mecompare} allows a pair 
of different commands and is recommended for non-standard applications of 
ME inequality statistics.)
{p_end}

{pstd}
The outcome may have {bf:any} number of categories, for a single model and
for a two-model comparison alike. When it has more than two, one set of
statistics is returned {it:per outcome category}.
{p_end}

{marker scale}{...}
{dlgtab:Families whose statistic is not a probability}

{pstd}
For a few families the statistic {help suest2} supplies is not on a
probability scale, and the ME Inequality inherits whatever scale it is on.
{cmd:ivprobit} and {cmd:ivtobit} return the structural linear index, and
{cmd:truncreg} its own linear prediction, so for these the statistic is in
the units of the index rather than of a probability. It is still the ME
Inequality of that quantity and is compared across models in the usual way,
but it should not be read beside a statistic from, say, {cmd:probit} as
though the two were on one scale.
{p_end}


{title:Options}

{marker Weighted}
{dlgtab:Weighted options}

{p2colset 5 18 19 0}

{p2col:{opt wei:ghted}} is the default if no option is specified. 
A weighted {it:ME inequality} 
accounts for the relative frequency of each level of the nominal variable 
in the sample. The weight assigned to each pairwise comparison is the 
sum of the proportions of the two levels used in the comparison, with a 
correction for each group being used in multiple comparisons: 
w_ab = (prop_a + prob_b)/(L - 1). Here, prop_a and prop_b 
refer to the proportions of the sample in Levels A and B, respectively. 
The term L-1 serves as a correction for the fact that each group is 
represented in multiple contrasts, ensuring the total sums to 1. 
{p_end}

{pmore}The proportions are taken over the model's estimation sample. When 
two models are fit on separate samples ({opt groups}), each model's 
contrasts are weighted by the proportions in {bf:its own} sample. 
The two ME inequality statistics can then differ both because 
the marginal effects differ and because the composition of the nominal 
variable differs across the samples; specify {opt unweighted} if the 
comparison should reflect differences in the marginal effects alone.
{p_end}

{p2col:{opt unw:eighted}} gives all groups equal weight in the calculation 
by ignoring the relative frequency of each level of the 
nominal variable in the sample. 
{p_end}

{p2col:{opt all}} reports both the {opt wei:ghted} and {opt unw:eighted} 
inequality measures.
{p_end}

{marker covariates}
{dlgtab:Setting values of covariates}
{p2colset 5 18 19 0}
{p2col:{opt atmean:s}} By default, the observed values of the other variables 
in the model are used for calculating the marginal effects (i.e., the margins 
default of {it:asobserved} is used; see {help margins}). Alternatively, the 
covariates can be set to their sample means with the {opt atmeans} option.
{p_end}

{marker Models}
{dlgtab:Models Option}

{p2colset 5 18 19 0}

{p2col:{opt mod:els(list)}} is required to compare {it:ME inequalities} across two models. 
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
{p2col:{opt group:s}} specifies that the two models used for comparison 
are fit on distinct samples. When the {opt groups} option is specified, 
the models listed in the {opt models(list)} option must have been fit 
separately across distinct samples (e.g., distinct groups in data).
{p_end}

{pmore}With {opt groups}, a weighted ME inequality weights each model by the 
level proportions of {bf:its own} sample. The comparison therefore reflects 
differences in the marginal effects {it:and} differences in composition 
between the samples. Use {opt unweighted} to compare the marginal effects 
alone.
{p_end}

{marker by/over}
{dlgtab:Subpopulation estimation options}

{p2colset 5 18 19 0}
{p2col:{opt by(varname)}} estimates ME inequality separately for each level 
of the specified binary or nominal variable, using the full sample. 
For each level, the estimation is based on the entire sample with the 
subpopulation variable counterfactually set to that level. The subpopulation 
variable must be binary or nominal and must also be included as a covariate 
in the model. This option uses the {opt at()} option of {help margins}.
{p_end}

{p2colset 5 18 19 0}
{p2col:{opt over(varname)}} estimates ME inequality separately for each 
level of the specified binary or nominal variable, using only the subsample 
of observations that have that specific value. This option uses 
the {opt over()} option from the {help margins} command to compute marginal 
effects within each group-specific subsample; see 
{help margins##over:[margins] over} option. 
{p_end}

{marker sampleweights}
{dlgtab:Sample weights and multiple imputation estimation options}

{p2colset 5 18 19 0}  
{p2col:{opt mi and svy}} Models fit with {cmd:mi}, {cmd:svy}, and 
{cmd:mi estimate: svy:} prefixes are supported. Specify the prefixes on the models 
themselves, not with {cmd:meinequality}; with two models both must use the 
same prefixes. Under {cmd:mi}, fit with {cmd:mi estimate:} or 
{cmd:mi estimate, post:} -- both are accepted here and return the same 
pooled statistic -- and store with {cmd:estimates store}; declare a survey 
design with {help mi svyset} rather than {help svyset}. The user-written 
{it:mimrgns} is used for the marginal effects and must be installed 
separately.
{p_end}

{pstd}{it:Multilevel models need a stage weight.} For the multilevel
({cmd:me}...) families, a weight alone is not enough: the model must
carry a higher-level weight too, as in
{cmd:melogit y x [pw=w2] || group:, pweight(w1)}. A model fit with a
weight but no {opt pweight()} has no design to build from and is
refused. The better alternative is the {cmd:svy:} prefix, which carries
the whole design from {help svyset} and is the recommended way to
specify one.
{p_end}

{p2colset 5 18 19 0}
{p2col:{opt [weight]}} When possible, use {help svyset} and the {cmd:svy:} 
prefix to apply weights to a model. However, you may instead specify a 
weight directly on the {bf:stored models} -- e.g. {cmd:logit y x [pw=w]}. 
{cmd:meinequality} takes the weighting from the models, so the results 
reported are the ones the stored models themselves imply. With two models, 
both must carry the same weight.
{p_end}

{marker options}
{dlgtab:Additional Optional Options}

{p2colset 5 18 19 0}
{p2col:{opt level(#)}} sets the confidence level for reported confidence 
intervals. The default is {cmd:level(95)}. Values from 10 to 99 are allowed.
{p_end}

{p2colset 5 18 19 0}
{p2col:{opt dec:imals(#)}} changes the number of decimal places reported 
in the table. The default is 3. Any integer between 0 - 7 is allowed.
{p_end}

{p2colset 5 18 19 0}
{p2col:{opt ci}} adds the lower and upper bounds of the confidence 
intervals (CIs) for all estimates, at the level set by {opt level(#)} (95% by 
default). 
{p_end}

{p2colset 5 18 19 0}
{p2col:{opt labw:idth(#)}} changes the width of the leftmost column of the 
table that provides the labels for the variables and associated marginal 
effects. The default is 24. Any integer between 20 - 32 is allowed.
{p_end}

{p2colset 5 18 19 0}
{p2col:{opt title(string)}} changes title of the output table. 
The default is "ME Inequality Estimates".
{p_end}

{p2colset 5 18 19 0}
{p2col:{opt groupn:ames(string)}} specifies the row names in the table 
corresponding to the ME Inequality for Model 1 and Model 2. Two group names 
must be provided; there can be no spaces in each group name. 
The {opt groups} option is required when using 
{opt groupn:ames(string)}. By default, the rows are named based on the 
stored estimate names specified in the {opt models(list)} option. 
Note that names longer than 10 characters will be truncated in the output.
{p_end}

{p2colset 5 18 19 0}
{p2col:{opt command:s}} displays the {cmd:margins} command used to calculate 
the predictions that make up the ME inequality estimate, and when two models 
are used, the {cmd:suest2} command used to combine the two models. 
{p_end}

{p2colset 5 18 19 0}
{p2col:{opt detail:s}} displays the output of the {cmdab:margins} 
command and, when two models are used, the {cmd:suest2} output.
{p_end}

{marker matrices}
{dlgtab:Saved estimates and matrices}

{pstd} {cmdab:meineq:uality} uses {cmdab:margins} to estimate the predictions 
for the {it:ME inequality} estimate. In the two-model case it combines the 
two {bf:stored} models with {help suest2}. These 
results are stored and can be restored after {cmdab:meineq:uality} (via 
{help estimates restore}). 
The {cmdab:margins} results which contain the predictions that are the constituent pieces of the 
marginal effects {cmdab:meineq:uality} calculates are stored as {it:meineq_margins}.
The combined model estimates are stored as {it:meineq_suest2}. 
{p_end}

{pstd} The command saves estimation results that can be retrieved using {cmd:return list}, 
including scalars for each estimated inequality score and a matrix containing all results. 
{p_end}

{pstd} When the outcome has more than two categories the scalars carry an 
outcome suffix: {cmd:r(wem1}{it:#}{cmd:_o}{it:#}{cmd:)} is the weighted 
statistic for model 1, variable {it:#}, outcome {it:#}. The unsuffixed 
names are used when the outcome is binary or continuous. 
{p_end}

{pstd} In the scalar names below, {it:#} is the variable's number within the 
{it:varlist} (the first nominal variable is 1). With a multi-category outcome 
the outcome is appended as {cmd:_o}{it:#} -- one scalar per outcome, matching 
the rows displayed -- and with a binary outcome nothing is appended, since 
there is only one. {opt by()} and {opt over()} then append 
{cmd:_}{it:level}. With one model only the {cmd:m1} names are returned.
{p_end}

{synoptset 26 tabbed}{...}
{synopthdr:scalar}
{synoptline}
{syntab:Weighted ME inequality}
{synopt:{cmd:r(wem1}{it:#}{cmd:)}}model 1{p_end}
{synopt:{cmd:r(wem2}{it:#}{cmd:)}}model 2{p_end}
{synopt:{cmd:r(wed}{it:#}{cmd:)}}cross-model difference{p_end}
{syntab:Unweighted ME inequality}
{synopt:{cmd:r(uwem1}{it:#}{cmd:)}}model 1{p_end}
{synopt:{cmd:r(uwem2}{it:#}{cmd:)}}model 2{p_end}
{synopt:{cmd:r(uwed}{it:#}{cmd:)}}cross-model difference{p_end}
{syntab:Other}
{synopt:{cmd:r(n_mods)}}number of models{p_end}
{synopt:{cmd:r(n_vars)}}number of variables{p_end}
{synoptline}

{pstd} {cmdab:meineq:uality} saves the current table to the matrix {opt r(table)}, 
one row per displayed quantity by six columns: estimate, standard error, 
{it:z}, {it:p}, and the two confidence limits. All six columns are returned 
whether or not {opt ci} is displayed. 
{p_end}

{pstd} {cmd:r(se_missing)} counts the quantities in that table whose standard 
error could not be computed. It is normally 0. When it is not, the point 
estimates are still reported but their standard error, {it:z}, {it:p} and 
confidence limits come back missing, and a note to that effect is printed 
beneath the table. This usually happens when a predicted quantity is near zero.
{p_end}


{marker bootstrap}
{dlgtab:Bootstrap standard errors}

{p2colset 5 18 19 0}
{pstd} {cmdab:meineq:uality} uses {help nlcom} to calculate standard errors 
via the delta method. Users can instead use the {helpb bootstrap} command to 
estimate standard errors for {cmd:meinequality}. This can be particularly 
useful when the model encounters convergence issues or when standard errors 
are otherwise unavailable or unreliable. When using {cmd:bootstrap}, 
you should wrap the {cmd:meinequality} command inside the {cmd:bootstrap} 
prefix to obtain bootstrap-based standard errors for the inequality measures. 
See {help bootstrap} for more information on syntax and options. 
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

*Bootstrap example
{phang} capture program drop boot_mei {p_end}

{phang} program define boot_mei, rclass {p_end}
{phang2} 		reg wage i.race c.age i.married {p_end}
{phang2} 		meinequality race {p_end}
{phang2} 		return scalar w_mei = r(wem11) {p_end}
{phang} end {p_end}

{phang} bootstrap w_mei=r(w_mei), reps(1000): boot_mei {p_end}	

	
{marker prereq}
{title:Required packages}

{pstd}
{cmdab:meineq:uality} requires the {help suest2} package, which supplies 
{cmd:suest2} itself and the shared helpers the command calls. 
{p_end}

{title:Comments}

{pstd} {cmdab:meineq:uality} implements the methods described in Mize and Han's 
2025 article "Inequality and Total Effect Summary Measures for Nominal and Ordinal Variables".

{pstd} {cmdab:meineq:uality} uses seemingly unrelated estimation to combine the 
model estimates in the two model case. See {help suest} and Weesie (1999) 
for details on the method.
{p_end}

{title:Authorship}

{pstd} {cmdab:meineq:uality} and its sister command, {cmdab:totalme}, are 
written by Bing Han (Population Research Institute, Penn State University) and 
Trenton D Mize (Departments of Sociology & Statistics and The Methodology 
Center at Purdue University). Questions can be sent to han644@purdue.edu 
or tmize@purdue.edu. {p_end}

{title:References}

{pstd} Mize, Trenton D. and Bing Han. 2025. Inequality and total effect 
summary measures for nominal and ordinal variables. {it:Sociological Science}. {p_end}

{pstd} Weesie, Jeroen. 1999. sg121: Seemingly Unrelated Estimation and the 
Cluster-Adjusted Sandwich Estimator. {it:Stata Technical Bulletin}. 52:34-47.
{p_end}
