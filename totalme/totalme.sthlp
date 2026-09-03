{smcl}
{* 2026-09-02 Bing Han, Trenton D. Mize -- matches totalme v1.6.9}{...}
{title:Title}

{p2colset 5 16 16 1}{...}
{p2col:{cmdab:totalme} {hline 2}}{cmdab:Total ME} 
({bf:Total} {bf:M}arginal {bf:E}ffects) calculates a summary of the total 
effects of an independent variable on a, usually multi-category outcome, such 
as from an ordinal or nominal model. {cmdab:totalme} supports 
any independent variable but makes different calculations for continuous, 
binary, and nominal independent variables. The total marginal effect
statistic is the sum of the absolute values of all marginal effects for an 
independent variable across all levels of the dependent variable, divided by 
two. For nominal independent variables, Total ME inequality 
({bf:Total} {bf:M}arginal {bf:E}ffects {bf:Inequality}) is calculated, with 
both weighted and unweighted estimates supported 
(see {cmdab:meineq:uality} for more details). The command supports 
estimation for one or two models. For two models, the command performs 
cross-model comparisons of the {it:totalMEs}. {p_end}
{p2colreset}{...}

{title:General Syntax}

{p 4 18 2}
{cmdab:totalme} {varlist} {ifin} {cmdab:,} [options]{p_end}

{marker overview}
{title:Overview}

{pstd}
{cmdab:totalme} computes the Total Marginal Effect (ME) for independent 
variables, which is most often used with multi-outcome models like a 
nominal or ordinal model. The total ME is a summary measure for the overall 
effect of an independent variable across all outcome categories. It is 
calculated by summing the absolute values of all marginal effects for that 
independent variable across all outcome levels, and divided by two. The 
{cmd:totalme} command implements the methods described in Mize and Han (2025).
{p_end}

{pstd}
{cmdab:totalme} supports continuous, binary, and nominal independent variables. 
For continuous and binary independent variables, a single marginal effect 
summarizes the total effect on each level of the dependent variable. 
The Total ME statistic is then calculated as the sum of all marginal effects 
for that independent variable (using absolute values) divided by two. 
For nominal independent variables, Marginal Effects Inequality 
(see {cmdab:meineq:uality}) is first calculated to 
summarize the total effect on each level of the dependent variable. 
ME Inequality represents the (weighted/unweighted) sum of all marginal effects, 
which are pairwise comparisons of predictions for categories of the nominal 
independent variable. The Total ME Inequality is then computed by summing 
the ME Inequality across all levels of the dependent variable, divided by two.
{p_end}

{pstd}
{cmdab:totalme} supports the calculation of Total ME for one or more independent 
variables simultaneously.
{p_end}

{pstd}
The command calculates the Total ME for a single model or performs cross-model 
comparisons of the {it:total MEs} using Seemingly Unrelated Estimation (SUEST) 
to combine the estimates from two models via the {help suest2} command, 
which is a required package.
{p_end}

{title:Table of contents}

	{help totalme##models:Supported estimation commands}
	{help totalme##Models:Required option for two model comparison}
	{help totalme##groups:Required option if fitting models over two distinct samples}
	{help totalme##amount:Amount of change to compute for continuous variables}
	{help totalme##start:Setting starting values of variables in varlist}
	{help totalme##covariates:Setting values of the covariates}
	{help totalme##Weighted:Weighting options for ME inequality for nominal IVs}
	{help totalme##byover:Estimations for subpopulations}
	{help totalme##sampleweights:Setting sample weights and multiple imputation estimates}
	{help totalme##options:Optional options for formatting, reporting, missing data, etc.}
	{help totalme##matrices:Saved estimates and matrices}
	{help totalme##bootstrap:Bootstrap standard errors}
	{help totalme##examples:Examples}
	
{marker models}{...}
{title:Supported estimators}

{pstd}
{cmdab:totalme} accepts one or two models from the following families. 
When two models are specified, cross-model comparisons of the equality of the 
{it:total MEs} are automatically calculated. In the two-model case, the models can 
be the same or different types of models. That is, any two combinations of the 
supported model estimations are possible. 
{p_end}

{dlgtab:Ordinary single-level models}

{p 8 12 2}
{cmd:logit} and {cmd:logistic}; {cmd:probit}; {cmd:cloglog};
{cmd:hetprobit}; {cmd:ologit}; {cmd:oprobit}; {cmd:mlogit}; and
{cmd:gologit2}, all forms, including with two models.

{dlgtab:Panel models}

{p 8 12 2}
{cmd:xtlogit} with estimators: re, fe, pa. {cmd:xtprobit} with estimators:
re, pa. {cmd:xtcloglog} with estimators: re, pa.

{p 8 12 2}
{cmd:xtologit}; {cmd:xtoprobit}; and {cmd:xtmlogit} with estimators: re, fe.

{dlgtab:Multilevel models}

{p 8 12 2}
{cmd:melogit}; {cmd:meprobit}; {cmd:mecloglog}; {cmd:meologit}; and
{cmd:meoprobit}.

{marker quadrature}{...}
{dlgtab:Quadrature for xtcloglog}

{pstd}
Comparing two {cmd:xtcloglog} models requires each to be fitted with
{cmd:intpoints(24)} or more; a single model needs no such option.
{p_end}

{title:Options}

{marker Models}
{dlgtab:Models Option}

{p2colset 5 18 19 0}

{p2col:{opt mod:els(list)}} is required for cross-model comparisons. 
The models must be estimated and saved using {help estimates store} before 
running {cmdab:totalme}. The {opt mod:els(list)} option is optional for 
single-model estimation; by default, {cmdab:totalme} will use the model estimates 
in memory. {cmdab:totalme} is limited to one or two models. 
The {opt vce(robust)} option is strongly recommended for the two-model case because 
the estimates are combined by seemingly unrelated estimation, which uses robust 
variance estimation. 
The two models specified can be the same or different estimation commands. 
{p_end}

{marker groups}
{dlgtab:Groups options}

{p2colset 5 18 19 0}
{p2col:{opt group:s}} specifies that the two models used for comparison 
are fit on distinct samples. Under {opt groups} each model's marginal effects are 
averaged over its own sample. When the {opt groups} option is specified, 
the models listed in the {opt models(list)} option must have been fit 
separately across distinct samples (e.g., distinct groups in the data). 
{p_end}

{marker amount}
{dlgtab:Amount of change and related options for continuous independent variables}
{p2colset 8 25 25 0}
{p2col:{opt amount(list)}}specifies the amount of change to be computed for 
the continuous independent variables. If only one value is specified in 
{opt amount( )}, this amount of change is applied to all of the continuous 
independent variables. To specify different amounts for each continuous 
independent variable, amounts in {it: list} are applied in the order of the 
continuous independent variables. E.g., In a {it:varlist} of 
{it: age i.woman income i.race polviews} there are three continuous 
variables, of which changes of (a) age + sd, (b) income + 5, and (c) polviews 
+ one can be specified with {opt amount(sd 5 one)}
{p_end}

{p2colset 10 23 22 12}{...}
{p2col :Name}Description{p_end}
{p2line}
{p2col :{ul:{bf:one}}}A one unit change; the default{p_end}
{p2col :{ul:{bf:sd}}}A standard deviation change{p_end}
{p2col :{ul:{bf:#}}}A change of {it: #}, which can be any amount. E.g., A 
10 unit increase can be specified with {opt amount(10)}{p_end}

{p2line}

{p2col:{opt center:ed}}Changes for continuous independent variables are 
{bf:centered} by default: computed from half the amount below to half the 
amount above, e.g. [mean - SD/2] to [mean + SD/2]. The default.
{p_end}

{p2col:{opt uncent:ered}}Requests {bf:uncentered} changes: an increase of the 
amount from the value of the independent variable, e.g., [mean] to [mean + SD], 
rather than the default centered change.
{p_end}


{marker start}
{dlgtab:Setting starting values of variables in varlist}
{p2colset 8 25 25 0}
{p2col:{opt start(list)}}By default, the observed values of the focal independent 
variables specified in the {it:varlist} are used as the starting points for 
calculating the marginal effects (i.e., the margins default of {it:asobserved} is 
used; see {help margins}). Other starting values can be specified within the 
{opt start( )} option, e.g. start(age=20). Multiple focal independent variables 
can be listed in {opt start( )}, e.g. start(age=20 income=100). Only one value 
per variable is allowed.
{p_end}

{marker covariates}
{dlgtab:Setting values of covariates}
{p2colset 8 25 25 0}
{p2col:{opt atmean:s}}By default, the observed values of the other variables 
in the model are used for calculating the marginal effects (i.e., the margins 
default of {it:asobserved} is used; see {help margins}). Alternatively, the 
covariates can be set to their sample means with the {opt atmeans} option.
{p_end}

{marker Weighted}
{dlgtab:Weighting options for total ME inequality}

{p2colset 5 18 19 0}

{pstd} For nominal independent variables, total {it:ME inequalities} are 
calculated; see {help meinequality}. {opt wei:ghted}, {opt unw:eighted}, 
and {opt all} options can be specified. {p_end}

{p2col:{opt wei:ghted}} is the default. Weighting accounts for the relative 
frequency of each level of 
the nominal variable in the sample. The weight assigned to each pairwise 
comparison is the corrected sum of the proportions of the two levels used 
in the comparison within the sample: w_ab = (prop_a + prob_b)/(L - 1). 
Here, prop_a and prop_b refer to the proportions of the sample in Levels 
A and B, respectively. The term L-1 serves as a correction for the fact 
that each group is represented in multiple contrasts, ensuring the total 
sums to 1. 
{p_end}

{p2col:{opt unw:eighted}} ignores the relative frequency of each level 
of the nominal variable in the sample. Instead, {opt unw:eighted} assigns 
equal weights to each comparison: 1/ (L(L-1)/2), where L(L-1)/2 presents 
the total number of pairwise comparisons. 
{p_end}

{p2col:{opt all}} reports both {opt wei:ghted} and {opt unw:eighted} 
total {it:ME inequalities}.
{p_end}


{marker byover}
{dlgtab:Subpopulation estimation options}

{p2colset 5 18 19 0}
{p2col:{opt by(varname)}} estimates total ME for each level of the specified 
binary or nominal variable, using the full sample. This is equivalent 
to the {help margins} option at( ). For each level, the estimation is based 
on the entire sample with the subpopulation variable counterfactually set to 
that level. The subpopulation variable must be binary or nominal 
and must also be included as a covariate in the model.
{p_end}

{p2colset 5 18 19 0}
{p2col:{opt over(varname)}} estimates total ME separately for each level 
of the specified binary or nominal variable, using only the subsample of 
observations that have that specific value. This option uses the 
{opt over()} option from the {help margins} command to compute marginal 
effects within each group-specific subsample; see 
{help margins##over:[margins] over} option.
{p_end}

{marker sampleweights}
{dlgtab:Sample weights and multiple imputation estimation options}

{p2colset 5 18 19 0}  
{p2col:{opt mi and svy}} Models fit with the {cmd:mi}, {cmd:svy}, and 
{cmd:mi estimate: svy:} prefixes are supported. Specify the prefixes on the 
models themselves, not with {cmd:totalme}; with two models both must use the 
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
{p2col:{opt [weight]}} When possible, using {help svyset} and the {cmd:svy:} 
prefix is the preferred way to specify weights. However, you can instead 
specify the weight on the {bf:stored models} -- e.g. 
{cmd:logit y x [pw=w]} -- or fit them with {cmd:svy:}. With two models, 
both must carry the same weight.
{p_end}


{marker options}
{dlgtab:Additional Optional Options}

{p2colset 5 18 19 0}
{p2col:{opt level(#)}} sets the confidence level for reported confidence 
intervals. The default is {cmd:level(95)}. Values can range from 10 to 99.
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
The default is "Total ME Estimates".
{p_end}

{p2colset 5 18 19 0}
{p2col:{opt groupn:ames(string)}} specifies the row names in the table 
corresponding to the total ME for Model 1 and Model 2. Two group names must 
be provided. The {opt groups} option is required when using 
{opt groupn:ames(string)}. By default, the rows are named based on the 
stored estimate names specified in the {opt models(list)} option. 
Note that names longer than 10 characters will be truncated in the output.
{p_end}

{p2colset 5 18 19 0}
{p2col:{opt command:s}} displays the {cmd:margins} command used to estimate 
the marginal effects, and when two models are specified, the {cmd:suest2} 
command used to combine the model estimates.
{p_end}

{p2colset 5 18 19 0}
{p2col:{opt detail:s}} displays the output of the {cmdab:margins} estimates 
which are the constituent parts of the {it:total ME} calculation, and when two 
models are specified, the {cmd:suest2} output with the combined model estimates.
{p_end}

{marker matrices}
{dlgtab:Saved estimates and matrices}

{pstd} {cmdab:totalme} uses {cmdab:margins} to estimate the marginal effects 
which make up the Total ME. In the two-model case the stored estimates are 
{it:combined} by {cmd:suest2}. These results are stored and 
can be restored after {cmdab:totalme} (see {help estimates restore}).  
The combined-system results are stored as {it:totalme_suest2}. The {cmdab:margins} 
results which contain the predictions that are the constituent pieces of the 
marginal effects {cmdab:totalme} calculates are stored as {it:totalme_margins}.
{p_end}

{pstd} The command saves estimation results that can be retrieved using {cmd:return list}, 
including scalars for each estimated inequality score and a matrix containing all results. 
{p_end}

{pstd} The scalars follow one naming scheme whether one or two models are 
given. In each name {it:#} is the variable's number within its type (the first 
continuous/binary variable is 1, the first nominal variable is 1). With 
{opt by()} or {opt over()}, {cmd:_}{it:level} is appended to every name, 
including the cross-model differences.
{p_end}

{synoptset 26 tabbed}{...}
{synopthdr:scalar}
{synoptline}
{syntab:Continuous or binary focal variable}
{synopt:{cmd:r(tmcm1}{it:#}{cmd:)}}Total ME, model 1{p_end}
{synopt:{cmd:r(tmcm2}{it:#}{cmd:)}}Total ME, model 2{p_end}
{synopt:{cmd:r(tmcd}{it:#}{cmd:)}}cross-model difference{p_end}
{syntab:Nominal focal variable, weighted}
{synopt:{cmd:r(tmwm1}{it:#}{cmd:)}}Total ME inequality, model 1{p_end}
{synopt:{cmd:r(tmwm2}{it:#}{cmd:)}}Total ME inequality, model 2{p_end}
{synopt:{cmd:r(tmwd}{it:#}{cmd:)}}cross-model difference{p_end}
{syntab:Nominal focal variable, unweighted}
{synopt:{cmd:r(tmuwm1}{it:#}{cmd:)}}unweighted Total ME inequality, model 1{p_end}
{synopt:{cmd:r(tmuwm2}{it:#}{cmd:)}}unweighted Total ME inequality, model 2{p_end}
{synopt:{cmd:r(tmuwd}{it:#}{cmd:)}}cross-model difference{p_end}
{synoptline}

{pstd} With one model only the {cmd:m1} names are returned. 
{cmdab:totalme} saves the displayed table to the matrix {cmd:r(table)}, one 
row per displayed quantity by six columns: estimate, standard error, {it:z}, 
{it:p}, and the two confidence limits. This replaces the {cmd:r(table)} any 
preceding estimation command left behind. 
{p_end}

{pstd} {cmd:r(se_missing)} counts the quantities in that table whose standard 
error could not be computed. It is normally 0. When it is not, the point 
estimates are still reported but their standard error, {it:z}, {it:p} and 
confidence limits come back missing, and a note to that effect is printed 
beneath the table.
{p_end}


{marker bootstrap}
{dlgtab:Bootstrap standard errors}

{p2colset 5 18 19 0}
{pstd} Users can use the {helpb bootstrap} command to estimate standard 
errors for {cmd:totalme}. This can be particularly useful when the model 
encounters convergence issues or when standard errors are otherwise 
unavailable or unreliable. When using {cmd:bootstrap}, 
you should wrap the {cmd:totalme} command inside the {cmd:bootstrap} 
prefix to obtain bootstrap-based standard errors. See {help bootstrap} for 
more information on syntax and options. 
{p_end}


{marker examples}
{title:Examples}

{phang} {stata "use https://tdmize.github.io/data/data/cda_gss, clear":use https://tdmize.github.io/data/data/cda_gss, clear} {p_end}
	
** Single model **
{phang} {stata mlogit 		healthR i.race4 c.age i.woman} {p_end}
	
*Continuous and Binary IVs
{phang} {stata totalme 		age woman} {p_end}
{phang} {stata totalme 		age woman, amount(sd)} {p_end}
{phang} {stata totalme 		age woman, start(age=20) amount(10)} {p_end}

*Nominal IV (ME inequalities calculated)
{phang} {stata totalme 		race4} {p_end}
{phang} {stata totalme 		race4, unweighted} {p_end}
	
	
** Compare across two models on same sample **
{phang} {stata mlogit 		healthR i.college if faminc < ., vce(robust)} {p_end}
{phang} {stata est store 	basemod} {p_end}
{phang} {stata mlogit 		healthR i.college c.faminc, vce(robust)} {p_end}
{phang} {stata est store 	medmod} {p_end}
	
{phang} {stata totalme 		college, models(basemod medmod)} {p_end}
	
	
** Compare across distinct samples/groups for two models **
{phang} {stata ologit 		class i.college if woman == 0, vce(robust)} {p_end}
{phang} {stata est store 	menmod} {p_end}
{phang} {stata ologit 		class i.college if woman == 1, vce(robust)} {p_end}
{phang} {stata est store 	wommod} {p_end}
	
{phang} {stata totalme 		college, models(menmod wommod) group} {p_end}

** Bootstrap example **
{phang} capture program drop boot_tot {p_end}

{phang} program define boot_tot, rclass {p_end}
{phang2} mlogit healthR i.race4 c.age i.woman, base(1) {p_end}
{phang2} totalme race4 {p_end}
{phang2} return scalar w_tot = r(tmwm11) {p_end}
{phang} end {p_end}

{pstd} bootstrap w_tot=r(w_tot), reps(1000): boot_tot {p_end}	

{title:Comments}

{pstd} {cmdab:totalme} implements the methods described in Mize and Han's 
2025 article "Inequality and Total Effect Summary Measures for Nominal and Ordinal Variables".

{pstd} In the two-model case {cmdab:totalme}, uses seemingly unrelated estimation 
to combine the model estimates. See {help suest} and Weesie (1999) for details on 
the method.
{p_end}

{title:Authorship}

{pstd} {cmdab:totalme} and {cmdab:meineq:uality} are written by Bing Han 
(Population Research Institute, Penn State University) and Trenton D Mize 
(Departments of Sociology & Statistics and The Methodology Center at Purdue University). 
Questions can be sent to han644@purdue.edu or tmize@purdue.edu. {p_end}

{title:References}

{pstd} Mize, Trenton D. and Bing Han. 2025. Inequality and total effect summary 
measures for nominal and ordinal variables. {it:Sociological Science}. {p_end}

{pstd} Weesie, Jeroen. 1999. sg121: Seemingly Unrelated Estimation and the 
Cluster-Adjusted Sandwich Estimator. {it:Stata Technical Bulletin}. 52:34-47.
{p_end}
