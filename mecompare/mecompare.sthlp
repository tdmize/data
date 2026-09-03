{smcl}
{* 2026-09-02 Trenton D Mize -- matches mecompare v1.4.0}{...}
{title:Title}

{p2colset 5 16 16 1}{...}
{p2col:{cmdab:mecomp:are} {hline 2}}{cmdab:mecomp:are} 
({bf:M}arginal {bf:E}ffects {bf:Compar[e]}ison) calculates marginal effects 
from one or two models for easy comparisons of effects within and across models. 
When two models are specified, {cmdab:mecomp:are}
uses seemingly unrelated estimation to combine the model estimates, 
and provides tests of the equality of marginal effects across models.{p_end}
{p2colreset}{...}

{title:General syntax}

{p 4 18 2}
{cmdab:mecomp:are} {varlist} {ifin} {weight} [{cmd:,} {opt mod:els( )} options]
{p_end}

{marker overview}
{title:Overview}

{pstd}
{cmdab:mecomp:are} calculates marginal effects from one or two models. 
When two models are specified, {cmdab:mecomp:are} combines the model estimates 
using seemingly unrelated estimation via the {help suest2} command and then calculates 
marginal effects for each model, as well as the cross-model comparisons of 
the marginal effects.

{pstd}
Factor syntax should have been used on the stored model estimates to ensure 
{cmdab:mecomp:are} calculates the correct statistics (i.e., binary and nominal 
variables must be entered into the variable list with the {bf:i.} prefix; continuous 
predictor variables with the {bf:c.} prefix). Factor syntax is allowed 
but not required for the {cmdab:mecomp:are} command itself: each variable is 
treated as the stored models specified it. See {help fvvarlist} for details on 
factor syntax. If you do not specify a variable list, marginal effects are 
calculated for all variables across the model(s).

{pstd}
By default, marginal effects for a nominal independent variable are shown in 
reference to a base category. To specify a reference  category other than the 
default first category you can use the ib#. syntax on the stored models 
passed to {cmdab:mecomp:are}. See {help fvvarlist##bases} for details on 
specifying base levels with factor syntax. Alternatively, the {opt pwcompare} 
option will calculate all pairwise contrasts; the {opt meinequality} option 
will calculate a single summary marginal effect inequality statistic.

{pstd}
For additional tests of the marginal effects beyond those given by default, 
use {help metest}, which combines and tests the estimates by the {it:ME #} 
shown in the {cmdab:mecomp:are} table. See 
{help mecompare##posttest:Testing and combining the marginal effects}.

{title:Table of contents}

	{help mecompare##overview:Overview}
	{help mecompare##estimators:Which models and estimators are supported}
	{help mecompare##required:Specifying the models}
	{help mecompare##stats:Which statistics to include in table}
	{help mecompare##amount:Amount of change to compute for continuous variables}
	{help mecompare##start:Setting starting values of variables in varlist}
	{help mecompare##covariates:Setting values of covariates}	
	{help mecompare##byover:Marginal effects within levels of a variable (by, over)}
	{help mecompare##nominal:Summary measures for nominal and ordinal variables}
	{help mecompare##groups:Options for comparing models fit over distinct groups}
	{help mecompare##options:Optional options for formatting, reporting, missing data, etc.}
	{help mecompare##predictopt:Specifying the prediction}
	{help mecompare##model_combos:Model combinations that can be compared}
	{help mecompare##svy_mi:svy and mi est support}
	{help mecompare##weights:Weights}
	{help mecompare##posttest:Testing and combining the marginal effects}
	{help mecompare##matrices:Saved estimates and matrices}
	{help mecompare##plotting:Plotting and tabulating results (coefplot, esttab)}
	{help mecompare##cre:Fixed effects via hybrid specifications}
	{help mecompare##examples:Examples}
	
	
{marker estimators}{...}
{title:Supported estimators}

{pstd}
{cmdab:mecomp:are} accepts one or two models from the following families.

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
{cmd:xtreg} with estimators: mle, fe, be, re, pa.

{p 8 12 2}
{cmd:xtreg, cre} is not supported; see
{help mecompare##cre:Correlated random effects (Mundlak) specifications}
below for the supported way to fit these models.

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
pa. {cmd:xtnbreg} with estimators: re, pa.

{p 8 12 2}
{cmd:xtnbreg, fe} is not supported.

{pstd}
When using the fixed effects {it:fe} estimator, marginal effects estimates 
can have issues. See the 
{help mecompare##cre:fixed effects and correlated random effects} section 
below for alternatives.
{p_end}

{dlgtab:Multilevel models}

{p 8 12 2}
{cmd:mixed, mle}; {cmd:melogit}; {cmd:meprobit}; {cmd:mecloglog};
{cmd:mepoisson}; {cmd:menbreg}; {cmd:meologit}; {cmd:meoprobit}; and
{cmd:mestreg}, all parametric distributions.

{p 8 12 2}
Supported {cmd:meglm} family-link pairs are Gaussian-identity and Gamma-log.

{pstd}
See {help mecompare##model_combos:Models that can be compared} below for the
cross-family combinations that are supported.
{p_end}
	
{title:Options}

{marker required}
{dlgtab:Specifying the models}

{p2colset 5 18 19 0}
{p2col:{opt mod:els(list)}} names the stored model estimates to use. 
{cmdab:mecomp:are} is limited to one or two models; with two models, each model 
must have been estimated and saved using {help estimates store} before running 
{cmd:mecompare}. 
{p_end}

{pstd}
{opt mod:els( )} may be omitted, in which case the estimates are taken from 
{help ereturn:e()}: 
{p_end}

{phang2}
o If {help suest2} was just run, the two models of that system are used, and 
the results are identical to naming them in {opt mod:els( )}. 
{p_end}

{phang2}
o Otherwise the single model in {help ereturn:e()} is used, and it is 
labelled {cmd:m1} in the table. It does not need to have been stored. 
{p_end}

{marker stats}
{dlgtab:Statistics to include in the table}
{p2colset 8 25 25 0}
{p2col:{opt stat:istics(list)}}selects statistics to display. The default 
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
{p2col:{opt amount(list)}}specifies the amount of change to be computed for 
the continuous independent variables. If only one value is specified in 
{opt amount( )}, this amount of change is applied to all of the continuous 
independent variables. To specify different amounts for each continuous 
independent variable, amounts in {it: list} are applied in the order of the 
continuous independent variables. E.g. In a {it:varlist} of 
{it: c.age i.woman c.income i.race c.polviews} there are three continuous 
variables, of which changes of (1) age + sd, (2) income + 5, and (3) polviews 
+ one can be specified with {opt amount(sd 5 one)}
{p_end}

{p2colset 10 23 22 12}{...}
{p2col :Name}Description{p_end}
{p2line}
{p2col :{ul:{bf:one}}}A one unit change; the default. 1 is a synonym{p_end}
{p2col :{ul:{bf:sd}}}A standard deviation change{p_end}
{p2col :{ul:{bf:#}}}A change of {it: #}, which can be any amount. E.g. A 
10 unit increase can be specified with {opt amount(10)}{p_end}
{p2col :{ul:{bf:twosd}}}A two standard deviation change (Gelman 2008), 
useful for comparing continuous effects to categorical effects. 
{bf:2sd} is a synonym{p_end}
{p2col :{ul:{bf:trimrange}}}A change across the trimmed range of the 
variable, from its 5th to its 95th percentile. Suggested by Mize and Han (2025) 
as a more robust alternative to 2sd for comparing effects across variables. {p_end}
{p2col :{ul:{bf:rate}}}An instantaneous rate of change, i.e. the 
derivative, approximated with a small centered change; {bf:slope} and 
{bf:dydx} are synonyms{p_end}

{p2line}

{p2col:{opt center:ed}}Changes for continuous independent variables are 
{bf:centered} by default: computed from half the amount below to half the amount 
above, e.g., [mean - SD/2] to [mean + SD/2]. The default if no option is specified.
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
calculating the marginal effects (i.e. the margins default of {it:asobserved} is 
used; see {help margins}). The means of the focal independent variables 
can instead be used for all observations by specifying {opt start(atmeans)}. 
Other starting values 
can be specified within the {opt start( )} option, e.g. start(age=20). Multiple 
focal independent variables can be listed in {opt start( )}, 
e.g. start(age=20 income=100).
{p_end}

{pmore}One continuous focal variable may be given a {it:numlist} of starting
values, e.g. {opt start(age=(20 30 60))}: the marginal effect is reported once
per value, in rows labelled {it:at 20}, {it:at 30}, {it:at 60}, numbered so
that {cmd:metest} can compare them.
{p_end}

{marker covariates}
{dlgtab:Setting values of covariates}
{p2colset 8 25 25 0}
{p2col:{opt cov:ariates(list)}}Covariates are other independent variables in 
the model other than the focal independent variables the marginal effects are 
calculated for. By default, covariates are held at their observed values (i.e. 
the margins default of {it:asobserved} is used; see {help margins}). The 
covariates can instead be held at their sample means by specifying 
{opt covariates(atmeans)}, or simply {opt atmeans}. 
Other covariate values can be specified within the 
{opt covariates( )} option, e.g. {opt covariates(woman=1)} would calculate all 
marginal effects holding the value of woman at 1. Multiple covariates 
can be listed in {opt covariates( )}, e.g. covariates(woman=1 polviews=5).
{p_end}

{pmore}One covariate may be given a {it:numlist} of values, e.g.
{opt covariates(age=(25 44 72))}: every marginal effect is reported once per
value, in rows labelled {it:age=25}, {it:age=44}, {it:age=72}, numbered so that
{cmd:metest} can test whether the effect differs across them. Each value is a
counterfactual in the sense of {opt by()}: the whole sample is set to that value
and the effect is averaged over the sample.
{p_end}

{marker byover}
{dlgtab:Marginal effects within levels of a variable (by, over)}
{p2colset 5 18 19 0}
{p2col:{opt by(varlist)}} reports the marginal effect of each focal variable 
{it:as a counterfactual} at each level of {it:varname} -- the effect computed 
with the whole sample set to {it:varname} = level, one level at a time, and 
averaged over the sample (via the {cmd:at()} option of {help margins}). One set 
of rows is reported per level of {it:varname}. With two or more variables, e.g.
{opt by(woman college)}, one set of rows is reported per combination of their
levels.
{p_end}

{p2col:{opt over(varlist)}} reports the marginal effect of each focal variable 
{it:within each subpopulation} defined by {it:varname} -- the effect computed 
using only the observations for which {it:varname} equals a given level (via the 
{cmd:over()} option of {help margins}). One set of rows is reported per level of 
{it:varname}. With two or more variables, e.g. {opt over(woman college)}, one 
set of rows is reported per combination of levels.
{p_end}

{pstd}
The difference between the two is a subpopulation-versus-counterfactual 
distinction. {opt over()} describes the effect {it:as it is} in each observed 
group; {opt by()} describes the effect that {it:would} obtain if the entire 
sample were placed at each level. The two can differ due to nonlinearities, 
distributional differences, and/or interactive effects. See Mize and Han (2026).
For most applications, {opt by()} is recommended. For a {it:continuous}
moderator, {opt covariates(varname=(numlist))} does what {opt by()} does at the
listed values; see {help mecompare##covariates:covariates()}.
{p_end}

{pstd}
For the {opt by()} or {opt over()} options, each variable must be a 
binary or nominal variable entered with a factor 
prefix in the model(s) ({cmd:i.} or {cmd:ib#.}). Both may name multiple
variables. The two may not be specified together, and neither may be 
combined with {opt groups}. 
{p_end}

{marker nominal}
{title:Summary measures for nominal and ordinal variables}

{p2colset 5 18 19 0}
{p2col:{opt pwc:ompare}} for focal variables specified as nominal (i.), 
the {opt pwc:ompare} option reports {it:all} pairwise contrasts between 
levels instead of the default of each non-base level versus the base level. 
Continuous and binary focal variables are unaffected.
{p_end}

{p2col:{opt meineq:uality}[{cmd:(}{it:type}{cmd:)}]} for focal variables 
specified as nominal (i.), the {opt meineq:uality} option reports a 
{it:marginal effect inequality} summary statistic immediately above that variable's 
contrasts. The ME inequality captures how much the outcome differs across the 
levels of the focal variable overall, as a weighted average of the absolute 
pairwise level contrasts (see Mize and Han 2025). {it:type} selects the weighting:
{p_end}

{phang2}{opt weighted} (the default) weights each pairwise contrast by the 
share of the sample in the two levels being contrasted.{p_end}

{phang2}{opt unweighted} gives the simple mean of the absolute pairwise 
contrasts, ignoring the sizes of the levels.{p_end}

{phang2}{opt all} shows both, weighted first (labeled {res}ME Inequality{txt}) then 
unweighted (labeled {res}Unwgt ME Ineq.{txt}).{p_end}

{pmore}With {opt groups}, each model's contrasts are weighted by its own 
sample's shares; specify {opt unweighted} to compare the marginal effects 
alone.{p_end}

{p2colset 5 18 19 0}
{p2col:{opt total:me}[{cmd:(}{it:type}{cmd:)}]} adds a {it:Total ME} summary 
above every focal variable's rows. The Total ME aggregates a variable's effect 
on a (usually multi-category) outcome into a single number: the total 
probability mass the variable shifts across the outcome categories (see Mize 
and Han 2025). For a continuous or binary focal variable the row is labeled 
{res}Total ME{txt}; for a nominal (i.) focal variable it is a 
{it:Total ME inequality} -- the same aggregation applied to the pairwise 
level contrasts -- labeled {res}Total ME Ineq.{txt} {it:type} selects the 
weighting and applies to nominal focal variables only:
{p_end}

{phang2}{opt weighted} (the default) weights each pairwise contrast by the 
share of the sample in the two levels being contrasted.{p_end}

{phang2}{opt unweighted} averages the absolute pairwise contrasts without 
weights; labeled {res}Unwgt Total ME Ineq.{txt}.{p_end}

{phang2}{opt all} shows both, weighted first then unweighted.{p_end}

{marker groups}
{dlgtab:Group options}

{p2colset 5 18 19 0}
{p2col:{opt group:s}} specifies that the two models in {opt models( )} were fit 
on distinct (non-overlapping) samples -- for example, one model per group -- and 
that {cmdab:mecomp:are} should compare marginal effects across the two groups. 
Each model's estimation sample defines its group; the two samples must not 
overlap.
{p_end}

{p2col:{opt groupn:ames(name1 name2)}} labels the two groups in the output 
({it:name1} for the first model, {it:name2} for the second); by default the groups 
are labeled by their model names. Requires the {opt groups} option. Each name is 
truncated to 10 characters.
{p_end}

{p2col:{opt groupm:e}} reports the average conditional difference in the 
outcome across the two groups, shown beneath the table. With a multi-category 
outcome one difference is reported for each outcome category, labeled 
Pr(category). Requires the {opt groups} option.
{p_end}

{p2col:{opt groupsd}} with {opt groups} and {opt amount(sd)}, each +SD change 
is calculated using that group's own standard deviation rather than the 
pooled SD used by default. Not recommended for most applications: effects 
can differ only because the groups' SDs differ.
{p_end}


{marker options}
{dlgtab:Additional Optional Options}

{p2colset 5 18 19 0}
{p2col:{opt pred:ict(pred)}}the prediction {cmd:margins} should compute if 
you want something other than the default for that model type; 
see {help mecompare##predictopt:specifying the prediction} below.
{p_end}

{p2colset 5 18 19 0}
{p2col:{opt marginsopt(string)}} passes {it:string} to {cmd:margins} exactly 
as typed. Options {cmdab:mecomp:are} sets itself ({cmd:at()}, {cmd:over()}, 
{cmd:predict()}, {cmd:post}, {cmd:atmeans}, and the derivative and contrast 
options) are refused. {cmd:expression()} is allowed with one model and no 
{opt predict()}: the marginal effects are then changes in the expression, 
e.g. {cmd:marginsopt(expression(100*predict(pr)))} for effects in percentage 
points. {cmd:marginsopt(vce(unconditional))} requests standard errors that 
treat the covariates as sampled. Use with caution; the result is not checked 
so the user should verify results; use {opt commands} to see the {cmd:margins} 
line and {opt details} to see the {cmd:margins} output.
{p_end}

{p2colset 5 18 19 0}
{p2col:{opt dec:imals(#)}} changes the number of decimal places reported 
in the table. The default is 3. Any integer between 0 - 7 is allowed.
{p_end}

{p2colset 5 18 19 0}
{p2col:{opt mod1:name(string)}} and {opt mod2:name(string)} name the rows in 
the table corresponding to the marginal effects for model 1 and model 2. The 
default is the name of the stored estimates given in {opt models( )}, or the 
group when the {opt groups} option is used. Names over 10 characters will be 
truncated in the output.
{p_end}

{p2colset 5 18 19 0}
{p2col:{opt labw:idth(#)}} changes the width of the leftmost column of the 
table that provides the labels for the variables and associated marginal 
effects. The default is 32. Any integer from 20 to 32 is allowed.
{p_end}

{p2colset 5 18 19 0}
{p2col:{opt statw:idth(#)}} changes the width of the columns of the 
table that report the statistics (e.g. estimate, SE, pvalue, etc.). The 
default is 9. Any integer between 9 - 20 is allowed.
{p_end}

{p2colset 5 18 19 0}
{p2col:{opt norow:num}} removes the column from the table with a number 
designation for each estimate in the table. 
{p_end}

{p2colset 5 18 19 0}
{p2col:{opt store(stub)}} saves the calculated marginal effects as separate 
stored estimates so they can be plotted with {help coefplot} or tabulated with 
{help esttab}, {help estimates table}, or {help etable}. With two models, three 
estimates are saved -- {it:stub}{cmd:_}{it:model1}, {it:stub}{cmd:_}{it:model2}, 
and {it:stub}{cmd:_diff} (the cross-model differences) -- where {it:model1} and 
{it:model2} are the names given in {opt models( )}. With one model, a single 
estimate {it:stub}{cmd:_}{it:model1} is saved. Each stored estimate is keyed by 
variable, so {help coefplot} and {help esttab} arrange results by variable 
automatically. With {opt by()} or {opt over()}, each stored estimate carries 
one coefficient per cell (e.g. {cmd:age_collgrad_0} and {cmd:age_collgrad_1}). 
See {help mecompare##plotting:Plotting and tabulating results} for examples.
{p_end}

{p2colset 5 18 19 0}
{p2col:{opt command:s}} displays the commands used for the {cmd:margins} 
estimates and, if two models are used, the {cmd:suest2} command.
{p_end}

{p2colset 5 18 19 0}
{p2col:{opt detail:s}} displays the output of the {cmd:margins} estimates 
and, if two models are used, the {cmd:suest2} output.
{p_end}

{marker predictopt}
{dlgtab:Specifying the prediction}

{pstd}
With a {bf:single} model any prediction {help margins} accepts after that 
command may be given. For multi-category models, the default reports a 
prediction per outcome; a single outcome may be selected, as in 
{cmd:predict(pr outcome(2))}.
{p_end}

{pstd}
With {bf:two} models, a non-default prediction can be requested if 
it returns a single quantity per model.
{p_end}

{pstd}
{bf:Mixed-effects and panel models.} When no {opt predict()} is given each 
model contributes its own {cmd:margins} default. For the {cmd:me} family and 
for {cmd:mixed}, that default {bf:averages over the random effects} rather 
than holding them at zero, and that is the recommended quantity. Random 
intercepts, random slopes, unstructured covariance and multi-level fits are 
supported.
{p_end}

{marker model_combos}
{dlgtab:Models that can be compared}

{pstd}Two models are comparable when they return the 
{bf:same number of predictions}. Same-family pairs (e.g., two logits, two glms, 
two mestregs) always qualify. Cross-family pairs qualify on the same rule: 
{cmd:logit} vs {cmd:regress}, {cmd:xtlogit} vs {cmd:mixed}, or any pair of 
binary-, count-, or continuous-outcome models; and any pair of ordinal or 
nominal models with the same number of outcome categories ({cmd:ologit} vs 
{cmd:oprobit}, {cmd:mlogit} vs {cmd:ologit}, and so on). Each model 
contributes its own default prediction, or the one given in 
{opt predict()}, so a cross-family comparison contrasts, e.g., logit's 
predicted probabilities with regress's linear predictions. Models that 
return different numbers of predictions (e.g. a 3-category {cmd:ologit} vs 
a {cmd:logit}) cannot be compared.
{p_end}

{pstd} When both models have a multi-category outcome, the outcome categories 
are matched {it:in order}, so the two dependent variables must have the same 
number of categories {it:and the same values}. {cmdab:mecomp:are} errors if 
they differ (e.g. one outcome coded 0/1/2 and the other 1/2/3). If the values 
agree but the value labels differ, the comparison proceeds and the table is 
labeled with the first model's labels.
{p_end}


{marker svy_mi}
{dlgtab:svy and mi est support}

{pstd}Models can be fit using the {cmd:svy:}, {cmd:mi est:}, or 
{cmd:mi est: svy:} prefixes. The prefix should be specified on the stored 
models, not on {cmdab:mecomp:are}. 
{p_end}

{pstd}
For most cases, survey weights and complex sample designs should be 
specified using {help svyset} and the {cmd:svy:} prefix should be used 
on the individual models before {cmdab:mecomp:are}. For {cmd:svy:}, all 
models must be {cmd:svy:} and the relevant {help svyset} design must be 
active when {cmdab:mecomp:are} is run. 
{p_end}

{pstd}Weights carry through to every quantity {cmdab:mecomp:are} computes 
from the data (standard deviations, means, trimmed ranges, level shares); 
under {cmd:mi estimate} these quantities are pooled across the imputations.
{p_end}

{marker cmdok}{...}
{pstd}{cmdab:mecomp:are} also supports models fit with the {cmd:mi estimate} 
prefix (multiply-imputed data). All models must be {cmd:mi estimate} and 
pooled with {cmd:post} ({cmd:mi estimate, post:} {it:command}), and the 
user-written {cmd:mimrgns} package must be installed 
({stata search mimrgns:search mimrgns}). Families not on Stata's list of 
commands {cmd:mi estimate} officially supports can often be estimated with 
{cmd:mi estimate, post cmdok:} {it:command}; whether to override Stata's 
list is the user's judgement.
{p_end}

{pstd}The two prefixes may also be combined: models fit with 
{cmd:mi estimate: svy:} are supported. Declare the design with 
{help mi svyset} rather than {help svyset}. All models must carry the same 
prefixes.
{p_end}

{marker weights}
{dlgtab:Weights}

{pstd}When possible, use {help svyset} and {cmd:svy:} to specify weights. 
However, weights can instead be applied on the {bf:stored models} -- e.g. 
{cmd:logit y x [pw=w]}. With two models, both must carry the same weight.
{p_end}

{pstd}{it:Multilevel models need a stage weight.} For the {cmd:me} families 
and {cmd:mixed}, the model must carry a higher-level weight too, as in 
{cmd:melogit y x [pw=w2] || group:, pweight(w1)}. The {cmd:svy:} prefix, 
which carries the whole design from {help svyset}, is the recommended way 
to specify one.
{p_end}

{marker posttest}
{title:Testing and combining the marginal effects}

{pstd}
Every estimate shown in the table is posted to {cmd:e(b)} and {cmd:e(V)}, in the 
same order as the {it:ME #} column. {help metest} automates non-standard tests 
of the marginal effects that {cmd:mecompare} calculates.
{p_end}

{pstd}
{bf:{help metest}} takes either an {it:ME #} or a coefficient name. An 
expression without {cmd:=} is evaluated with {help nlcom}, so sums, 
differences, ratios, products and nonlinear functions are all allowed; an 
expression containing 
{cmd:=} is passed to {help test}, including chained and multiple equalities. 
To refer to a number for a mathematical expression, use a leading {cmd:#}, 
as in {bf:/ #2} which will divide by 2, rather than referring to the 2nd ME.
{p_end}

{phang2}{cmd:metest 1}{space 20}the marginal effect numbered 1{p_end}
{phang2}{cmd:metest 1 - 2}{space 16}the difference between MEs 1 and 2{p_end}
{phang2}{cmd:metest (1 + 2) / #2}{space 9}their average; division by 2{p_end}
{phang2}{cmd:metest 1 / 2}{space 16}the ratio of MEs 1 and 2{p_end}
{phang2}{cmd:metest 1 = 2 = 3}{space 12}a joint test that all three are equal{p_end}

{pstd}
The estimates are ordinary {cmd:e(b)}/{cmd:e(V)} results, so {help lincom}, 
{help nlcom}, {help test} and {help mlincom} can also be used directly. Type 
{cmd:mecompare, coeflegend} to list the coefficient names. 
{p_end}

{phang2}{cmd:lincom _b[college:mental] - _b[college:physical]}{p_end}
{phang2}{cmd:test _b[college:mental] = _b[age:mental]}{p_end}
{phang2}{cmd:mlincom 11 - 10}{p_end}


{marker matrices}
{dlgtab:Saved estimates and matrices}

{pstd} With two models, {cmdab:mecomp:are} combines the stored estimates into a 
single system using {help suest2}. It then uses {cmd:margins} to 
calculate the marginal effects. These results are stored and 
can be restored after {cmdab:mecomp:are} has been run. 
See {help estimates restore}. The combined model estimates are stored as 
{it:mec_suest2}. The {cmd:margins} estimates which contain the constituent 
pieces that are used to calculate the marginal effects are stored as 
{it:mec_margins}.

{pstd} {cmdab:mecomp:are} saves the current table of estimates to the 
matrix {opt _mecompare}. The matrix has columns corresponding to the 
displayed results. Rows that only contain labels (no statistics) have 
values of {bf:.z}
{p_end}

{pstd}
{cmdab:mecomp:are} is an e-class command. It posts the marginal effects -- and, 
with two models, the cross-model differences -- to {cmd:e(b)} and {cmd:e(V)} 
(with the full covariance among the estimates), so they can be used directly by 
post-estimation commands such as {help coefplot} and {help esttab}. 
{p_end}

{pstd}
The following are stored in e():
{p_end}

{synoptset 22 tabbed}{...}
{p2col 5 22 26 2: Scalars}{p_end}
{synopt:{cmd:e(N)}}number of observations in the marginal-effects sample; equal 
to the number of observations marked by {cmd:e(sample)}{p_end}
{synopt:{cmd:e(n_mods)}}number of models compared (1 or 2){p_end}
{synopt:{cmd:e(n_vars)}}number of focal variables (all model predictors when no 
{it:varlist} is given){p_end}
{synopt:{cmd:e(V_complete)}}1 if every estimate and its covariances were 
recovered; 0 otherwise{p_end}
{synopt:{cmd:e(k_failed)}}number of quantities that could not be computed (posted 
as 0 with a warning){p_end}
{synopt:{cmd:e(V_zeroed)}}number of covariance elements set to 0 for the same 
reason{p_end}

{p2col 5 22 26 2: Macros}{p_end}
{synopt:{cmd:e(cmd)}}{cmd:mecompare}{p_end}
{synopt:{cmd:e(properties)}}{cmd:b V}{p_end}
{synopt:{cmd:e(predict_label)}}the prediction the effects were computed from, 
as shown on the {cmd:Predicting:} line{p_end}
{synopt:{cmd:e(predict1_label)}}{space 1}{p_end}
{synopt:{cmd:e(predict2_label)}}posted only when the two models use different 
predictions{p_end}
{synopt:{cmd:e(marginsopt)}}the string given in {opt marginsopt()}, when used{p_end}

{p2col 5 22 26 2: Matrices}{p_end}
{synopt:{cmd:e(b)}}marginal effects (and, with two models, cross-model differences){p_end}
{synopt:{cmd:e(V)}}variance-covariance matrix of the estimates. In the rare case 
that a quantity cannot be computed, its estimate is posted as 0 and its row and 
column of {cmd:e(V)} are zeroed, with a warning; {cmd:e(V_complete)} reports 
whether this happened{p_end}
{synopt:{cmd:e(table)}}the displayed table; label-only rows have value {bf:.z}{p_end}

{p2col 5 22 26 2: Functions}{p_end}
{synopt:{cmd:e(sample)}}marks the estimation sample (not set after {cmd:mi estimate}){p_end}
{p2colreset}{...}


{marker plotting}
{title:Plotting and tabulating results}

{pstd}
The {opt store(stub)} option saves the marginal effects as separate stored 
estimates keyed by variable, which makes plotting with {help coefplot} and 
tabulating with {help esttab} straightforward. If needed, install these 
user-written packages first: {stata ssc install coefplot} and 
{stata ssc install estout}.
{p_end}

{pstd}Fit and store two models:{p_end}
{phang2}{stata sysuse nlsw88, clear: sysuse nlsw88, clear}{p_end}
{phang2}{stata drop if missing(union, married, age, race, hours, collgrad, ttl_exp, grade, wage): drop if missing(union, married, age, race, hours, collgrad, ttl_exp, grade, wage)}{p_end}
{phang2}{stata logit union i.married age i.race hours i.collgrad ttl_exp, vce(robust): logit union i.married age i.race hours i.collgrad ttl_exp, vce(robust)}{p_end}
{phang2}{stata est store m1: est store m1}{p_end}
{phang2}{stata logit union i.married age i.race hours i.collgrad ttl_exp grade wage, vce(robust): logit union i.married age i.race hours i.collgrad ttl_exp grade wage, vce(robust)}{p_end}
{phang2}{stata est store m2: est store m2}{p_end}

{pstd}Calculate the marginal effects and save the pieces with {opt store()}. 
This saves {cmd:mec_m1}, {cmd:mec_m2}, and {cmd:mec_diff}:{p_end}
{phang2}{stata mecompare i.married age i.race hours i.collgrad ttl_exp, models(m1 m2) store(mec): mecompare i.married age i.race hours i.collgrad ttl_exp, models(m1 m2) store(mec)}{p_end}

{pstd}{bf:coefplot} -- both models' marginal effects, arranged by variable:{p_end}
{phang2}{stata coefplot mec_m1 mec_m2, xline(0) xtitle("Average marginal effect"): coefplot mec_m1 mec_m2, xline(0) xtitle("Average marginal effect")}{p_end}

{pstd}{bf:coefplot} -- just the cross-model differences:{p_end}
{phang2}{stata coefplot mec_diff, xline(0) xtitle("Difference in AME (model 1 - model 2)"): coefplot mec_diff, xline(0) xtitle("Difference in AME (model 1 - model 2)")}{p_end}

{pstd}{bf:esttab} -- a three-column table (model 1, model 2, difference):{p_end}
{phang2}{stata esttab mec_m1 mec_m2 mec_diff, se mtitles("Model 1" "Model 2" "Difference"): esttab mec_m1 mec_m2 mec_diff, se mtitles("Model 1" "Model 2" "Difference")}{p_end}

{pstd}For a {bf:single model}, {opt store()} saves one estimate 
({it:stub}{cmd:_}{it:model1}) that plots and tabulates the same way:{p_end}
{phang2}{stata mecompare i.married age i.race hours i.collgrad ttl_exp, models(m1) store(me1): mecompare i.married age i.race hours i.collgrad ttl_exp, models(m1) store(me1)}{p_end}
{phang2}{stata coefplot me1_m1, xline(0) xtitle("Average marginal effect"): coefplot me1_m1, xline(0) xtitle("Average marginal effect")}{p_end}

{marker cre}{...}
{title:Fixed effects models via hybrid correlated random effects (Mundlak) specifications}

{pstd}
Fixed effects models ({it:fe} estimator for {it:xt} commands) have known issues 
in calculating marginal effects, especially for categorical outcome models. 
One common recommendation is to use a hybrid model specification such as the 
correlated random effects (Mundlak) model, which estimates both within-person 
("fixed effects") estimates and between-person estimates, and has no issue 
in calculating marginal effects (Mize and Han 2026).

{pstd}
{cmd:xtreg, cre} is not supported, but an identical hybrid correlated-random-effects
(Mundlak) specification can be estimated and used with {cmdab:mecomp:are} by 
including each time-varying predictor's panel mean alongside the predictor 
when fit with the {cmd:re} estimator.{p_end}

{phang2}{cmd:. bysort id: egen mean_x = mean(x)}{p_end}
{phang2}{cmd:. xtreg y x mean_x i.d, re}{p_end}

{pstd}
Where the {it:x} coefficient represents the within-person ("fixed effect") 
estimate and the {it:mean_x} coefficient represents the between-person 
estimate. The same recipe extends to any supported panel or multilevel family, e.g. 
{cmd:xtlogit} or {cmd:xtpoisson}, etc.
{p_end}


{marker examples}
{title:Examples}

{phang} {stata sysuse nlsw88, clear: sysuse nlsw88, clear} {p_end}

{pstd}{it:Fit and store the models, then compare marginal effects.} Factor
syntax required for the regression model; optional for {cmdab:mecomp:are}.
{p_end}

{phang} {stata logit union i.married age i.race hours i.collgrad, vce(robust): logit union i.married age i.race hours i.collgrad, vce(robust)} {p_end}

{phang}	{stata est store basemod: est store basemod} {p_end}

{phang} {stata logit union i.married age i.race hours i.collgrad wage, vce(robust): logit union i.married age i.race hours i.collgrad wage, vce(robust)} {p_end}

{phang}	{stata est store medmod: est store medmod} {p_end}

{phang} {stata mecompare age collgrad race hours, models(basemod medmod): mecompare age collgrad race hours, models(basemod medmod)} {p_end}

{pstd}{it:Amount of change for continuous variables:}

{phang} {stata mecompare age collgrad race hours, models(basemod medmod) amount(sd): mecompare age collgrad race hours, models(basemod medmod) amount(sd)} {p_end}

{phang} {stata mecompare age collgrad race hours, models(basemod medmod) amount(sd 10): mecompare age collgrad race hours, models(basemod medmod) amount(sd 10)} {p_end}

{pstd}{it:amount(rate)} gives the instantaneous rate of change; {it:amount(dydx)} and {it:amount(slope)} are synonyms:
{p_end}

{phang} {stata mecompare age hours, models(basemod medmod) amount(rate): mecompare age hours, models(basemod medmod) amount(rate)} {p_end}

{pstd}{it:Labeling the models:}

{phang} {stata mecompare age collgrad race hours, models(basemod medmod) mod1name(Base Model) mod2name(Mediation Model): mecompare age collgrad race hours, models(basemod medmod) mod1name(Base Model) mod2name(Mediation Model)} {p_end}

{pstd}{it:Effects within levels of a variable (by, over):}

{phang} {stata mecompare age race, models(basemod medmod) over(collgrad): mecompare age race, models(basemod medmod) over(collgrad)} {p_end}

{phang} {stata mecompare age race, models(basemod medmod) by(collgrad): mecompare age race, models(basemod medmod) by(collgrad)} {p_end}

{phang} {stata mecompare age race, models(basemod medmod) by(collgrad married): mecompare age race, models(basemod medmod) by(collgrad married)} {p_end}

{pstd}{it:Values of the focal variables and covariates, including lists of values:}

{phang} {stata mecompare age race, models(basemod medmod) atmeans: mecompare age race, models(basemod medmod) atmeans} {p_end}

{phang} {stata mecompare age, models(basemod) start(age=(30 40 50)): mecompare age, models(basemod) start(age=(30 40 50))} {p_end}

{phang} {stata mecompare age race, models(basemod medmod) covariates(hours=(20 40 60)): mecompare age race, models(basemod medmod) covariates(hours=(20 40 60))} {p_end}

{pstd}{it:Summary measures for nominal variables:}

{phang} {stata mecompare race, models(basemod medmod) pwcompare: mecompare race, models(basemod medmod) pwcompare} {p_end}

{phang} {stata mecompare race, models(basemod) meineq(weighted): mecompare race, models(basemod) meineq(weighted)} {p_end}

{phang} {stata mecompare race, models(basemod medmod) meineq(all): mecompare race, models(basemod medmod) meineq(all)} {p_end}

{pstd}
{it:Total ME, which sums effects across outcome categories.} 
{it:E.g., with an ordinal outcome:}
{p_end}

{phang} {stata egen hours_ord = cut(hours), at(0 30 40 50 81): egen hours_ord = cut(hours), at(0 30 40 50 81)} {p_end}

{phang} {stata ologit hours_ord c.age i.married i.race, vce(robust): ologit hours_ord c.age i.married i.race, vce(robust)} {p_end}

{phang} {stata mecompare age married race, totalme: mecompare age married race, totalme} {p_end}

{pstd}{it:Comparing models fit over distinct groups:}
{p_end}

{phang} {stata logit union age hours i.collgrad if south==1, vce(robust): logit union age hours i.collgrad if south==1, vce(robust)} {p_end}

{phang}	{stata est store msouth: est store msouth} {p_end}

{phang} {stata logit union age hours i.collgrad if south==0, vce(robust): logit union age hours i.collgrad if south==0, vce(robust)} {p_end}

{phang}	{stata est store mnonsouth: est store mnonsouth} {p_end}

{phang} {stata mecompare age hours collgrad, models(msouth mnonsouth) groups groupnames(South NonSouth): mecompare age hours collgrad, models(msouth mnonsouth) groups groupnames(South NonSouth)} {p_end}

{pstd}{it:Cross-family comparison (same number of predictions):}
{p_end}

{phang} {stata logit union i.married age i.race hours i.collgrad, vce(robust): logit union i.married age i.race hours i.collgrad, vce(robust)} {p_end}

{phang}	{stata est store logitmod: est store logitmod} {p_end}

{phang} {stata regress union i.married age i.race hours i.collgrad, vce(robust): regress union i.married age i.race hours i.collgrad, vce(robust)} {p_end}

{phang}	{stata est store lpmmod: est store lpmmod} {p_end}

{phang} {stata mecompare age race, models(logitmod lpmmod): mecompare age race, models(logitmod lpmmod)} {p_end}

{pstd}{it:Choosing the prediction. With one model, any prediction}
{help margins} {it:allows; a count model offers several:}
{p_end}

{phang} {stata nbreg hours c.age i.collgrad i.race, vce(robust): nbreg hours c.age i.collgrad i.race, vce(robust)} {p_end}

{phang}	{stata est store cntbase: est store cntbase} {p_end}

{phang} {stata mecompare age collgrad race, models(cntbase): mecompare age collgrad race, models(cntbase)} {p_end}

{phang} {stata mecompare age collgrad race, models(cntbase) predict(n): mecompare age collgrad race, models(cntbase) predict(n)} {p_end}

{phang} {stata mecompare age collgrad race, models(cntbase) predict(ir): mecompare age collgrad race, models(cntbase) predict(ir)} {p_end}

{phang} {stata mecompare age collgrad race, models(cntbase) predict(pr(0)): mecompare age collgrad race, models(cntbase) predict(pr(0))} {p_end}

{pstd}{it:With two models, any prediction returning one quantity per model:}
{p_end}

{phang} {stata nbreg hours c.age i.collgrad i.race i.married, vce(robust): nbreg hours c.age i.collgrad i.race i.married, vce(robust)} {p_end}

{phang}	{stata est store cntmed: est store cntmed} {p_end}

{phang} {stata mecompare age collgrad race, models(cntbase cntmed) predict(n): mecompare age collgrad race, models(cntbase cntmed) predict(n)} {p_end}

{pstd}{it:Passing an option to margins, e.g. effects in percentage points:}
{p_end}

{phang} {stata mecompare age race, models(basemod) marginsopt(expression(100*predict(pr))): mecompare age race, models(basemod) marginsopt(expression(100*predict(pr)))} {p_end}

	
{title:Comments}

{pstd} {cmdab:mecomp:are} implements the methods described in Mize, Doan, 
and Long's 2019 article "A General Framework for Comparing Predictions and Marginal 
Effects Across Models".

{pstd} {cmdab:mecomp:are} uses seemingly unrelated estimation via the 
{help suest2} command to combine the model estimates. See {help suest} and 
Weesie (1999) for details on the method.

{pstd} Many of the features of {cmdab:mecomp:are} intentionally mimic and 
borrow from Long and Freese's (2014) SPost13 command {help mchange}. 
{p_end}

{title:Authorship}

{pstd} {cmd:mecompare} and {cmd:metest} are written by Trenton D Mize 
(Departments of Sociology & Statistics [by courtesy] and the Methodology Center,
Purdue University). Questions can be sent to tmize@purdue.edu {p_end}

{title:References}

{pstd} Mize, Trenton D., Long Doan, and J. Scott Long. 2019. A General Framework 
for Comparing Predictions and Marginal Effects Across Models. 
{it:Sociological Methodology}. 49:152-189. {p_end}

{pstd} Mize, T. D., & Han, B. (2025). Inequality and Total Effect Summary 
Measures for Nominal and Ordinal Variables. {it:Sociological Science}. 12, 115-157.

{pstd} Mize, T. D., & Han, B. (2026). Marginal effects: flexible methods for 
interpretation across linear and nonlinear models. 
In {it:Handbook on Data Modeling and Data Analysis}, 
edited by David Weakliem. Edward Elgar Publishing.

{pstd} Long, J. Scott and Jeremy Freese. 2014. 
{it:Regression Models for Categorical Dependent Variables Using Stata.} 
Third Edition. Stata Press.

{pstd}Gelman, A. (2008). Scaling regression inputs by dividing by two standard 
deviations. {it:Statistics in medicine}, 27(15). 2865-2873.
{p_end}

{pstd} Weesie, Jeroen. 1999. sg121: Seemingly Unrelated Estimation and the 
Cluster-Adjusted Sandwich Estimator. {it:Stata Technical Bulletin}. 52:34-47.
