{smcl}
{* 2025-01-13 Bing Han, Trenton D. Mize}{...}
{title:Title}

{p2colset 5 16 16 1}{...}
{p2col:{cmdab:totalme} {hline 2}}{cmdab:Total ME} 
({bf:Total} {bf:M}arginal {bf:E}ffects) calculates a summary of the total effects 
of an independent variable on an ordinal or nominal outcome. {cmdab:totalme} supports 
any independent variable but makes different calculations for continuous, binary, 
and nominal independent variables. The total marginal effects statistic is the sum of 
the absolute values of all marginal effects for an independent on all levels of 
the dependent variable, divided by two. For nominal independent variables, 
Total ME inequality ({bf:Total} {bf:M}arginal {bf:E}ffects {bf:Inequality}) 
is calculated , with both weighted and unweighted estimates supported 
(see {cmdab:meineq:uality} for more details). The command supports estimation for one or two models. 
For two models, the command performs cross-model comparisons of the {it:totalMEs}. {p_end}
{p2colreset}{...}

{title:General Syntax}

{p 4 18 2}
{cmdab:totalme} {varlist} {cmdab:,} [options]{p_end}

{marker overview}
{title:Overview}

{pstd}
{cmdab:totalme} computes the Total Marginal Effect (ME) for independent variables 
in nominal and ordinal outcome models. The total ME is a summary measure 
for the overall effect of an indepenent varaible by summing the absolute values of 
all marginal effects for that independent variable across all outcome levels, divided by two. 
The command calculates the Total ME for a single model or performs cross-model 
comparisons of the {it:total MEs} using Seemingly Unrelated Estimation (SUEST) 
to combine the estimates from two models.
{p_end}

{pstd}
{cmdab:totalme} supports continuous, binary, and nominal independent variables. 
For continuous and binary independent variables, a single marginal effect 
summarizes the total effect on each level of the dependent variable. 
The Total ME statistic is then calculated as the sum of all marginal effects 
for that independent variable (using absolute values) divided by two. 
For nominal independent variables, Marginal Effects Inequality 
({bf:M}arginal {bf:E}ffects {bf:Inequality}) is first calculated to 
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
{cmdab:totalme} supports the following estimation commands: 
{cmd:logit}, {cmd:probit}, {cmd:mlogit}, {cmd:ologit}, {cmd:oprobit}, and {cmd:gologit2}. 
When two models are specified, cross-model comparisons of the equality of the 
{it:total MEs} are automatically calculated. In the two-model case, the models can 
be the same or different types of modelse. That is, any two combinations of the supported 
model estimations are supported. 
{p_end}


{title:Table of contents}

	{help totalme##models:Required option for two model comparison}
	{help totalme##groups:Required option if fitting models over two distinct samples}
	{help totalme##amount:Amount of change to compute for continuous variables}
	{help totalme##start:Setting starting values of variables in varlist}
	{help totalme##weighted:Weighting options for ME inequality for nominal IVs}
	{help totalme##sample weights:Setting sample weights}
	{help totalme##options:Optional options for formatting, reporting, missing data, etc.}
	{help totalme##matrices:Saved estimates and matrices}
	{help totalme##examples:Examples}
	
{title:Options}

{marker Models}
{dlgtab:Models Option}

{p2colset 5 18 19 0}

{synopt:{opt mod:els(list)}} is required for cross-model comparisons. 
The models must be estimated and saved using {help estimates store} before 
running {cmdab:totalme}. The {opt mod:els(list)} option is optional for 
single-model estimation; by default, {cmdab:totalme} will use the model estimates 
in memory. {cmdab:totalme} is limited to one or two models. 
The {opt vce(robust)} option is strongly recommended for the two-model case because 
SUEST is used to combine the model estimates which uses robust variance estimation. 
The two models specified can be the same or different estmation commands. 
{p_end}

{marker groups}
{dlgtab:Groups options}

{p2colset 5 18 19 0}
{synopt:{opt group:s}} specifies that the two models used for comparison 
are fit on distinct samples. When the {opt groups} option is specified, 
the models listed in the {opt models(list)} option must have been fit 
separately across distinct samples (e.g., distinct groups in the data). 
{p_end}

{marker amount}
{dlgtab:Amount of change and related options for continuous independent variables}
{p2colset 8 25 25 0}
{synopt:{opt amount(list)}}specifies the amount of change to be computed for 
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

{synopt:{opt center:ed}}By default changes for continuous independent variables 
are for an increase of these amounts from the value of the independent variable. 
That is, they are {bf:uncentered} changes. Centered changes are computed by 
calculating changes from half the value below to half the value above;
e.g. [mean - SD/2] to [mean + SD/2].
{p_end}

{marker start}
{dlgtab:Setting starting values of variables in varlist}
{p2colset 8 25 25 0}
{synopt:{opt start(list)}}By default, the observed values of the focal independent 
variables specified in the {it:varlist} are used as the starting points for 
calculating the marginal effects (i.e., the margins default of {it:asobserved} is 
used; see {help margins}). The means of the focal independent variables 
can instead be used by specifying {opt start(atmeans)}. Other starting values 
can be specified within the {opt start( )} option, e.g. start(age=20). Multiple 
focal independent variables can be listed in {opt start( )}, 
e.g. start(age=20 income=100)
{p_end}

{marker Weighted}
{dlgtab:Weighting options for total ME inequality}

{p2colset 5 18 19 0}

{pstd} For nominal independent variables, total {it:ME inequalities} are calculated. 
{opt wei:ghted}, {opt unwei:ghted}, and {opt all} options can be specified. {p_end}

{synopt:{opt wei:ghted}} is the default. Weighting accounts for the relative 
frequency of each level of 
the nominal variable in the sample. The weight assigned to each pairwise 
comparison is the corrected sum of the proportions of the two levels used 
in the comparison within the sample: w_ab = (prop_a + prob_b)/(L - 1). 
Here, prop_a and prop_b refer to the proportions of the sample in Levels 
A and B, respectively. The term L−1 serves as a correction for the fact 
that each group is represented in multiple contrasts, ensuring the total 
sums to 1. 
{p_end}

{synopt:{opt unwei:ghted}} ignores the relative frequency of each level 
of the nominal variable in the sample. Instead, {opt unwei:ghted} assigns 
equal weights to each comparison: 1/ (L(L-1)/2), where L(L-1)/2 presents 
the total number of pairwise comparisons. 
{p_end}

{synopt:{opt all}} reports both {opt wei:ghted} and {opt unwei:ghted} 
total {it:ME inequalities}.
{p_end}

{marker sampleweights}
{dlgtab:Sample weight options}

{p2colset 5 18 19 0}
{synopt:{opt [weight]}} specifies weights for the two-model comparison. 
The {opt models(list)} option must be specified when using {command: weight} 
and {command: fweight}, {command: pweight}, and {command: iweight} are supported. 
For single-model estimation, include the weight specification directly in your model. 
The {command: mi} and {command: svy} prefixes are also supported for single-model 
total ME calculations but not for two-model comparisons. When {command: mi} is 
specified, the user-written package {it: mimrgns} will be used to calculate 
mean inequality (users need to install {it: mimrgns} separately).

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
{synopt:{opt title(sting)}} changes title of the output table. The default is "Total ME Estimates".
{p_end}

{p2colset 5 18 19 0}
{synopt:{opt groupn:ames(string)}} specifies the row names in the table corresponding to the total ME for Model 1 and Model 2. Two group names must be provided. The {opt groups} option is required when using {opt groupn:ames(string)}. By default, the rows are named based on the stored estimate names specified in the {opt models(list)} option. Note that names longer than 10 characters will be truncated in the output.
{p_end}

{p2colset 5 18 19 0}
{synopt:{opt command:s}} displays the commands used for the {cmdab:gsem} estimates when two models are specified. If the same dependent variable is used across models, a temporary variable, which is a clone of the dependent variable, is used for the second model. 
{p_end}

{p2colset 5 18 19 0}
{synopt:{opt detail:s}} displays the output of the {cmdab:margins} estimates 
which are the constituent parts of the {it:total ME} calculation.
{p_end}

{marker matrices}
{dlgtab:Saved estimates and matrices}

{pstd} {cmdab:totalme} uses {cmdab:margins} to estimate the marginal effects 
which make up the Total ME. In the two-model case, {cmdab:gsem} is used to 
combine the model estimates. These results are stored and 
can be restored after {cmdab:totalme} ({help estimates restore}).  
The {cmdab:gsem} model results are stored as {it:totalme_gsem}. The {cmdab:margins} 
results which contain the predictions that are the constituent pieces of the 
marginal effects {cmdab:totalme} calculates are stored as {it:totalme_margins}.
{p_end}

{pstd} {cmdab:totalme} saves the current table to the matrix {opt _totalme}. 
The matrix has columns corresponding to the displayed results.
{p_end}


{marker examples}
{title:Examples}

{pstd} use	"https://tdmize.github.io/data/data/cda_gss", clear {p_end}
{phang} {stata drop if missing(healthR, race4, age, woman, parent, married, faminc, degree)} {p_end}
{phang} {stata drop if year < 2000  | year > 2021} {p_end}
{phang} {stata mlogit healthR i.race4 c.age i.woman i.parent i.married i.degree} {p_end}
{phang} {stata est store mod52c} {p_end}

{phang} {stata totalme married, models(mod52c)} {p_end}
{phang} {stata totalme age, models(mod52c) amount(34) centered} {p_end}
{phang} {stata totalme married age, amount(34) centered models(mod52c)} {p_end}
{phang} {stata totalme married parent, models(mod52c)} {p_end}

{phang} {stata mlogit healthR i.race4 c.age i.woman i.parent i.married c.faminc i.degree} {p_end}
{phang} {stata est store mod52d} {p_end}
{phang} {stata totalme college, models(mod52e_base mod52e_com)} {p_end} 

{title:Comments}

{pstd} {cmdab:totalme} implements the methods described in Mize and Han's 
2025 article "Inequality and Total Effect Summary Measures for Nominal and Ordinal Variables".

{pstd} In the two-model case {cmdab:totalme}, uses seemingly unrelated estimation 
to combine the model estimates. See {help suest} and Weesie (1999) for details on 
the method.
{p_end}

{title:Authorship}

{pstd} {cmdab:totalme} and {cmdab:meineq:uality} are written by Bing Han 
(Department of Sociology, Purdue University) and Trenton D Mize 
(Departments of Sociology & Statistics and The Methodology Center at Purdue University). 
Questions can be sent to han644@purdue.edu or tmize@purdue.edu. {p_end}

{title:References}

{pstd} Mize, Trenton D. and Bing Han. 2025. Inequality and total effect summary 
measures for nominal and ordinal variables. {it:Sociological Science}. {p_end}

{pstd} Weesie, Jeroen. 1999. sg121: Seemingly Unrelated Estimation and the 
Cluster-Adjusted Sandwich Estimator. {it:Stata Technical Bulletin}. 52:34-47.
{p_end}
