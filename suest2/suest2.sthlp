{smcl}
{* *! version 1.0.0  31aug2026}{...}
{vieweralsosee "suest" "help suest"}{...}
{vieweralsosee "margins" "help margins"}{...}
{vieweralsosee "predict" "help predict"}{...}
{vieweralsosee "suest2_cleanup" "help suest2_cleanup"}{...}
{vieweralsosee "suest2_mi" "help suest2_mi"}{...}
{vieweralsosee "ivregress" "help ivregress"}{...}
{vieweralsosee "gologit2" "help gologit2"}{...}
{vieweralsosee "xtreg" "help xtreg"}{...}
{vieweralsosee "xtmlogit" "help xtmlogit"}{...}
{vieweralsosee "meglm" "help meglm"}{...}
{vieweralsosee "mestreg" "help mestreg"}{...}


{title:Title}

{phang}
{bf:suest2} {hline 2} Seemingly unrelated estimation for most models in Stata 
with margins support


{title:Table of contents}

	{help suest2##syntax:Syntax}
	{help suest2##description:Description}
	{help suest2##estimators:Supported estimators}
	{help suest2##weights:Weights, survey data, and multiple imputation}
	{help suest2##margins:margins and mecompare}
	{help suest2##options:Options for suest2}
	{help suest2##stored:Stored results}
	{help suest2##cre:Correlated random effects specifications}
	{help suest2##examples:Examples}
	{help suest2##companions:Companion commands}
	{help suest2##authorship:Authorship}


{marker syntax}{...}
{title:Syntax}

{p 8 16 2}
{cmd:suest2} {it:model1name} {it:model2name} [{cmd:,} {it:options}]

{pstd}
{it:model#name} contains named stored estimates. Store each model with
{help estimates store} before running {cmd:suest2}.


{marker description}{...}
{title:Description}

{pstd}
{cmd:suest2} combines stored estimation results and estimates their joint
sandwich covariance matrix, including cross-model covariances, using 
seemingly-unrelated estimation. It extends {help suest} to additional panel, 
multilevel, weighted, survey, MI, generalized ordered, and 
instrumental-variable models. It also allows {cmd:predict} and
{cmd:margins} to select a constituent model from the combined system, which 
allows for most any post-estimation work. For example, graphs of predictions 
or marginal effect estimates within and across models. The {help mecompare} 
command is written to work seemlessly after {cmd:suest2} to automate 
marginal effect calculations and comparisons. 


{pstd}
The usual workflow is

{phang2}{cmd:. logit y1 c.x##i.group}{p_end}
{phang2}{cmd:. estimates store m1}{p_end}
{phang2}{cmd:. logit y1 c.x##i.group z}{p_end}
{phang2}{cmd:. estimates store m2}{p_end}
{phang2}{cmd:. suest2 m1 m2}{p_end}
{phang2}{cmd:. mecompare x, amount(sd)}{p_end}


{marker estimators}{...}
{title:Supported estimators}

{pstd}
The following model families are supported.

{dlgtab:Ordinary single-level models}

{p 8 12 2}
{cmd:regress}; {cmd:logit} and {cmd:logistic}; {cmd:probit}; {cmd:ologit}; 
{cmd:oprobit}; {cmd:mlogit}; {cmd:poisson}; {cmd:nbreg}; {cmd:zip};
and {cmd:zinb} with either inflation link.

{p 8 12 2}
{cmd:glm}; {cmd:cloglog}; {cmd:tobit}; {cmd:intreg}; maximum-likelihood
{cmd:heckman}; and parametric {cmd:streg}. Active-system {cmd:glm}
prediction supports identity, log, logit, probit, cloglog, and loglog
links.

{p 8 12 2}
{cmd:gologit2}, including proportional-odds, partial proportional-odds,
unrestricted, alternative-link, and {cmd:autofit()} results.

{p 8 12 2}
{cmd:ivregress 2sls}. {cmd:fracreg} with estimators: logit, probit. 
Every constituent model in the system must use the same estimation mode: 
either unweighted conventional estimates, or linearized
{cmd:svy: ivregress 2sls} estimates under one active survey design. 

{p 8 12 2}
{cmd:betareg} with links: logit, probit, cloglog, loglog. {cmd:truncreg}.
{cmd:hetprobit}. {cmd:biprobit}. {cmd:ivprobit}. {cmd:ivtobit}.


{dlgtab:Panel models}

{p 8 12 2}
{cmd:xtreg} with estimators: re, fe, be, mle, pa.

{p 8 12 2}
{cmd:xtlogit} with estimators: re, fe, pa. {cmd:xtprobit} with estimators: re, pa.

{p 8 12 2}
{cmd:xtologit} and {cmd:xtoprobit}

{p 8 12 2}
{cmd:xtmlogit} with estimators: re, fe.

{p 8 12 2}
{cmd:xtpoisson} with estimators: re, fe, pa. {cmd:xtnbreg} with estimators: re, pa.

{p 8 12 2}
{cmd:xtcloglog} with estimators: re, pa.

{pstd}
Panel systems are unweighted and ordinarily require a common panel identifier.
Store conventional constituent results; request robust or higher-level
clustered covariance with {cmd:suest2}. 

{pstd}
Correlated random effects models should be specified as detailed 
in the {help suest2##cre:CRE specification section below}.
 

{dlgtab:Multilevel models}

{p 8 12 2}
{cmd:mixed, mle}; {cmd:melogit}; {cmd:meprobit}; {cmd:mecloglog};
{cmd:mepoisson}; {cmd:menbreg}; {cmd:meologit}; {cmd:meoprobit}; and
{cmd:mestreg}.

{p 8 12 2}
Supported {cmd:meglm} families and links are Gaussian-identity,
Bernoulli-logit, Bernoulli-probit, Bernoulli-cloglog, Poisson-log,
negative-binomial-log, Gamma-log, ordinal-logit, and ordinal-probit.

{p 8 12 2}
Mixed heterogeneous systems may also include ordinary {cmd:ologit} or
{cmd:oprobit} constituents beside {cmd:xtologit}, {cmd:xtoprobit},
{cmd:meologit}, or {cmd:meoprobit} ones. An ordinary constituent must be
stored unprefixed, unweighted, and with conventional (non-robust)
standard errors; it inherits the system's cluster variable from its
mixed partner.

{pstd}
Supported {cmd:mestreg} distributions are exponential, Weibull, lognormal,
loglogistic, and gamma, including the applicable proportional-hazards and
accelerated-failure-time forms.

{pstd}
Supported multilevel families may be combined in one system. Every model must
use the same highest-level grouping variable. 


{marker weights}{...}
{title:Weights, survey data, and multiple imputation}

{dlgtab:Survey data}

{pstd}
For weighted analyses and for complex samples, using {help svyset} and 
{cmd:svy:} on the individual models is recommended. Estimate and store 
each model with the {cmd:svy:} prefix, then pass the stored names to 
{cmd:suest2} without a prefix:

{phang2}{cmd:. svy: regress y1 x z}{p_end}
{phang2}{cmd:. estimates store s1}{p_end}
{phang2}{cmd:. svy: logit y2 x z}{p_end}
{phang2}{cmd:. estimates store s2}{p_end}
{phang2}{cmd:. suest2 s1 s2}{p_end}

{pstd}
The survey route supports linearized VCEs. Survey design information is taken
from {cmd:svyset}; do not specify {cmd:cluster()}, {cmd:vce()}, or
{cmd:robust} on {cmd:suest2}. All models must use the same survey
subpopulation specification. Replicate-weight VCEs are not supported.

{dlgtab:Pweights}

{pstd}
Pweighted systems support {cmd:regress}, {cmd:logit}/{cmd:logistic},
{cmd:probit}, {cmd:poisson}, {cmd:nbreg}, {cmd:ologit}, {cmd:oprobit}, and
{cmd:mlogit}. These families may be combined. Evaluated pweights must agree on
observations shared by constituent estimation samples; they may differ outside
the overlap. Request system clustering with {cmd:cluster()} on {cmd:suest2}.

{dlgtab:Multiple imputation}

{pstd}
MI support is provided for {cmd:regress}, {cmd:logit}/{cmd:logistic},
{cmd:probit}, {cmd:poisson}, {cmd:nbreg}, {cmd:ologit}, {cmd:oprobit}, and
{cmd:mlogit}, {cmd:xtreg} (mle), {cmd:mixed}, {cmd:melogit}, {cmd:meprobit}, 
{cmd:mecloglog}, {cmd:mepoisson}, {cmd:menbreg}, {cmd:meologit}, {cmd:meoprobit},
{cmd:meglm} and {cmd:mestreg}. Estimate and store each model with 
{cmd:mi estimate, post:}, then pass their stored names to {cmd:suest2}:

{phang2}{cmd:. mi estimate, post: regress y1 x z}{p_end}
{phang2}{cmd:. estimates store mi1}{p_end}
{phang2}{cmd:. mi estimate, post: logit y2 x z}{p_end}
{phang2}{cmd:. estimates store mi2}{p_end}
{phang2}{cmd:. suest2 mi1 mi2}{p_end}

{pstd}
{cmd:suest2} re-estimates the constituent commands jointly within each
imputation and pools the system with Rubin's rules. The current MI data and all
variables used by the stored commands must remain available and unchanged. Use 
{cmd:mimrgns} or {cmd:mecompare} for postestimation; ordinary {cmd:predict} 
and {cmd:margins} are not available after MI pooling.


{marker margins}{...}
{title:margins and mecompare}

{pstd}
A bare {cmd:margins} or {cmd:mecompare} call evaluates the default 
response for every constituent model. Select one model and prediction 
statistic with {cmd:predict()}:

{phang2}{cmd:. margins}{p_end}
{phang2}{cmd:. margins, dydx(x)}{p_end}
{phang2}{cmd:. margins, dydx(x) predict(pr)}{p_end}
{phang2}{cmd:. margins, dydx(x) predict(model(m2) pr)}{p_end}
{phang2}{cmd:. margins, predict(model(o1) pr outcome(3))}{p_end}
{phang2}{cmd:. margins, dydx(x) predict(model(me1) mu fixedonly)}{p_end}

{pstd}
Options {cmd:at()}, {cmd:dydx()}, {cmd:over()}, {cmd:post}, and other standard
{cmd:margins} options are supported when the constituent command supports the
requested prediction. Inference uses the complete joint {cmd:suest2}
covariance matrix, including the cross-model covariance.


{marker options}{...}
{title:Options for suest2}

{pstd}
For most applications, {cmd:vce(robust)} or {cmd:vce(cluster {it:varname})} 
should be used on the individual models so that the {cmd:suest2} standard 
errors match exactly. However, these options and some others can be 
requested directly on {cmd:suest2}:

{synoptset 28 tabbed}{...}
{synopthdr}
{synoptline}
{synopt:{opt cl:uster(varname)}}cluster the joint covariance on {it:varname}{p_end}
{synopt:{cmd:vce(robust)}}request the route's robust covariance{p_end}
{synopt:{cmd:vce(cluster }{it:varname}{cmd:)}}same as {cmd:cluster(}{it:varname}{cmd:)}{p_end}
{synopt:{opt r:obust}}same as {cmd:vce(robust)}{p_end}
{synopt:{opt l:evel(#)}}set the confidence level; the default is 95{p_end}
{synopt:{opt dir}}pass through the official {cmd:suest} display option{p_end}
{synopt:{opt ef:orm(string)}}request exponentiated coefficients where applicable, labelling the column with {it:string}, e.g. {cmd:eform("Odds ratio")}. As with official {cmd:suest}, the argument is required{p_end}
{synopt:{opt minus(string)}}use the official {cmd:suest} minus convention when supported. Like {opt eform()} it is passed to {cmd:suest} verbatim, so the argument is required and the accepted values are {cmd:suest}'s{p_end}
{synopt:{opt regressml}}use the official {cmd:suest} ML-regression convention when supported{p_end}
{synopt:{opt svy}}pass through the official {cmd:suest} survey option when supported{p_end}
{synopt:{opt nowarn}}suppress the note printed when a model was not fit with {cmd:vce(robust)}{p_end}
{synoptline}

{pstd}
Specify only one of {cmd:cluster()}, {cmd:vce()}, and {cmd:robust}.
Options {cmd:minus}, {cmd:regressml}, and {cmd:svy} apply only to routes that
use official {cmd:suest}; specialized panel, multilevel, and IV routes reject
them when they are not meaningful. Option {cmd:svy} does not replace
estimating each survey constituent with the {cmd:svy:} prefix.

{pstd}
Panel models cluster at the panel identifier by default. Multilevel models
cluster at the common highest-level grouping variable by default. A larger
cluster may be requested only when the lower-level panels or groups are nested
within it.


{marker stored}{...}
{title:Stored results}

{pstd}
{cmd:suest2} stores the standard results returned by {cmd:suest}, including
{cmd:e(b)}, {cmd:e(V)}, {cmd:e(N)}, {cmd:e(sample)}, {cmd:e(names)}, and,
when applicable, {cmd:e(clustvar)} and {cmd:e(N_clust)}. It also stores:

{synoptset 28 tabbed}{...}
{synopthdr}
{synoptline}
{synopt:{cmd:e(suest2_version)}}installed {cmd:suest2} version{p_end}
{synopt:{cmd:e(suest2_nmodels)}}number of constituent models{p_end}
{synopt:{cmd:e(suest2_model#)}}user-facing name of constituent model #{p_end}
{synopt:{cmd:e(suest2_hold#)}}private stored-estimate name for model #{p_end}
{synopt:{cmd:e(suest2_start#)}}first column of model # in {cmd:e(b)}{p_end}
{synopt:{cmd:e(suest2_korig#)}}number of original parameters in model #{p_end}
{synopt:{cmd:e(suest2_cmd#)}}constituent estimation command{p_end}
{synopt:{cmd:e(suest2_family#)}}constituent response family, when defined{p_end}
{synopt:{cmd:e(suest2_link#)}}constituent link, when defined{p_end}
{synopt:{cmd:e(suest2_systempred#)}}whether active-system prediction is available{p_end}
{synopt:{cmd:e(suest2_pweight)}}whether the pweight route was used{p_end}
{synopt:{cmd:e(suest2_svy)}}whether the linearized survey route was used{p_end}
{synopt:{cmd:e(suest2_mi_reconstruction_checked)}}whether MI source results were successfully reconstructed{p_end}
{synopt:{cmd:e(predict)}}{cmd:suest2_p}{p_end}
{synopt:{cmd:e(margins_cmd)}}{cmd:suest2_margins}{p_end}
{synoptline}

{pstd}
Estimator-specific routes store additional {cmd:e(suest2_*)} metadata for
diagnostics and postestimation.


{marker cre}{...}
{title:Fixed effects models and correlated random effects (Mundlak) specifications}

{pstd}
Fixed effects models ({it:fe} estimator for {it:xt} commands) have known issues 
in calculating marginal effects, especially for categorical outcome models. 
One common recommendation is to use the correlated random effects (Mundlak) 
specification, which estimates both within-person ("fixed effects") estimates 
and between-person estimates, and has no issue in calculating marginal effects 
(Mize and Han 2026).

{pstd}
{cmd:xtreg, cre} is not supported, but an identical correlated-random-effects
(Mundlak) specification can be estimated and used with {cmdab:mecomp:are} by 
including each time-varying predictor's panel mean alongside the predictor 
when fit with the {cmd:re} estimator.{p_end}

{phang2}{cmd:. bysort id: egen mean_x = mean(x)}{p_end}
{phang2}{cmd:. xtreg y x mean_x i.d, re}{p_end}

{pstd}
Where the {it:x} coefficient represents the within-person ("fixed effect") 
estimate and the {it:x_mean} coefficient represents the between-person 
estimate. The same recipe extends to any supported panel or multilevel family, e.g. 
{cmd:xtlogit} or {cmd:xtpoisson}, etc.
{p_end}


{marker examples}{...}
{title:Examples}

{dlgtab:Ordinary single-level models}

{phang2}{stata "sysuse nlsw88, clear":sysuse nlsw88, clear}{p_end}
{phang2}{stata "logit union c.age i.married, vce(robust)":logit union c.age i.married, vce(robust)}{p_end}
{phang2}{stata "estimates store mod1":estimates store mod1}{p_end}
{phang2}{stata "logit union c.age i.married i.collgrad, vce(robust)":logit union c.age i.married i.collgrad, vce(robust)}{p_end}
{phang2}{stata "estimates store mod2":estimates store mod2}{p_end}
{phang2}{stata "suest2 mod1 mod2":suest2 mod1 mod2}{p_end}
{phang2}{stata "margins, dydx(age married)":margins, dydx(age married)}{p_end}

{dlgtab:Panel models}

{phang2}{stata "webuse nlswork, clear":webuse nlswork, clear}{p_end}
{phang2}{stata "xtset idcode year":xtset idcode year}{p_end}
{phang2}{stata "xtreg ln_wage c.ttl_exp##i.union i.year, fe":xtreg ln_wage c.ttl_exp##i.union i.year, fe}{p_end}
{phang2}{stata "estimates store fe1":estimates store fe1}{p_end}
{phang2}{stata "xtreg hours c.ttl_exp##i.union i.year, fe":xtreg hours c.ttl_exp##i.union i.year, fe}{p_end}
{phang2}{stata "estimates store fe2":estimates store fe2}{p_end}
{phang2}{stata "suest2 fe1 fe2, cluster(idcode)":suest2 fe1 fe2, cluster(idcode)}{p_end}
{phang2}{stata "margins, dydx(ttl_exp)":margins, dydx(ttl_exp)}{p_end}

{dlgtab:Mixed models}

{phang2}{stata "webuse bangladesh, clear":webuse bangladesh, clear}{p_end}
{phang2}{stata "melogit c_use urban age || district:, intpoints(5)":melogit c_use urban age || district:, intpoints(5)}{p_end}
{phang2}{stata "estimates store me1":estimates store me1}{p_end}
{phang2}{stata "meprobit c_use urban age || district:, intpoints(5)":meprobit c_use urban age || district:, intpoints(5)}{p_end}
{phang2}{stata "estimates store me2":estimates store me2}{p_end}
{phang2}{stata "suest2 me1 me2":suest2 me1 me2}{p_end}
{phang2}{stata "margins, dydx(age) predict(model(me1) mu fixedonly)":margins, dydx(age) predict(model(me1) mu fixedonly)}{p_end}
{phang2}{stata "margins, dydx(age) predict(model(me2) mu conditional(fixedonly))":margins, dydx(age) predict(model(me2) mu conditional(fixedonly))}{p_end}

{dlgtab:Instrumental variables}

{phang2}{stata "webuse hsng2, clear":webuse hsng2, clear}{p_end}
{phang2}{stata "ivregress 2sls rent pcturban (hsngval = faminc)":ivregress 2sls rent pcturban (hsngval = faminc)}{p_end}
{phang2}{stata "estimates store iv1":estimates store iv1}{p_end}
{phang2}{stata "ivregress 2sls rent pcturban (hsngval = faminc i.region)":ivregress 2sls rent pcturban (hsngval = faminc i.region)}{p_end}
{phang2}{stata "estimates store iv2":estimates store iv2}{p_end}
{phang2}{stata "suest2 iv1 iv2":suest2 iv1 iv2}{p_end}
{phang2}{stata "margins, dydx(pcturban)":margins, dydx(pcturban)}{p_end}


{marker companions}{...}
{title:Companion Comamnds}

{pstd} The {help mecompare} command is a companion command to {cmd:suest2} 
that automates calculation of marginal effects within and across models. 
{cmd:mecompare} with the {opt models()} option uses {cmd:suest2} to combine 
the model estimates before estimating marginal effects.
{p_end}


{marker authorship}{...}
{title:Authorship}

{pstd} {cmd:suest2} is written by Trenton D Mize, 
Departments of Sociology & Statistics (by courtesy) and The Methodology 
Center, Purdue University. uestions can be sent to tmize@purdue.edu {p_end}